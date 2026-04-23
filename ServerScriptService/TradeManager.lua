-- @ScriptType: Script
-- @ScriptType: Script
-- Name: TradingManager
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = ReplicatedStorage:WaitForChild("Network")

local TradeAction = Network:FindFirstChild("TradeAction") or Instance.new("RemoteEvent", Network)
TradeAction.Name = "TradeAction"
local NotificationEvent = Network:WaitForChild("NotificationEvent")

local ActiveTrades = {} 
local PendingRequests = {} 

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("ActiveTradeId", "None")

	player.Chatted:Connect(function(msg)
		local lowerMsg = msg:lower()
		if string.sub(lowerMsg, 1, 7) == "/trade " then
			local targetName = string.sub(msg, 8)
			TradeAction:FireServer("SendRequest", targetName)
		elseif lowerMsg == "/fixstrade" then
			player:SetAttribute("ActiveTradeId", "None")
			NotificationEvent:FireClient(player, "Trade state forcefully reset.", "Success")
			TradeAction:FireClient(player, "TradeClosed")
		end
	end)
end)

local function CancelTrade(tradeId)
	local trade = ActiveTrades[tradeId]
	if not trade then return end

	trade.IsCountingDown = false

	local p1 = Players:GetPlayerByUserId(trade.P1)
	local p2 = Players:GetPlayerByUserId(trade.P2)

	if p1 then TradeAction:FireClient(p1, "TradeClosed") end
	if p2 then TradeAction:FireClient(p2, "TradeClosed") end

	if p1 then p1:SetAttribute("ActiveTradeId", "None") end
	if p2 then p2:SetAttribute("ActiveTradeId", "None") end

	ActiveTrades[tradeId] = nil

	if trade.CountdownTask and trade.CountdownTask ~= coroutine.running() then 
		task.cancel(trade.CountdownTask) 
	end
end

local function AbortCountdown(tradeId)
	local trade = ActiveTrades[tradeId]
	if not trade or not trade.IsCountingDown then return end

	trade.IsCountingDown = false
	if trade.CountdownTask and trade.CountdownTask ~= coroutine.running() then 
		task.cancel(trade.CountdownTask) 
	end
	trade.P1_Ready = false
	trade.P2_Ready = false

	local p1 = Players:GetPlayerByUserId(trade.P1)
	local p2 = Players:GetPlayerByUserId(trade.P2)

	if p1 then TradeAction:FireClient(p1, "CountdownAborted") end
	if p2 then TradeAction:FireClient(p2, "CountdownAborted") end

	if p1 then TradeAction:FireClient(p1, "UpdateStatus", false, false) end
	if p2 then TradeAction:FireClient(p2, "UpdateStatus", false, false) end
end

local function ExecuteTrade(tradeId)
	local trade = ActiveTrades[tradeId]
	if not trade then return end

	local p1 = Players:GetPlayerByUserId(trade.P1)
	local p2 = Players:GetPlayerByUserId(trade.P2)
	if not p1 or not p2 then CancelTrade(tradeId); return end

	local function VerifyOffer(plr, offer)
		if plr.leaderstats.Dews.Value < offer.Dews then return false end
		for iName, count in pairs(offer.Items) do
			local attr = iName:gsub("[^%w]", "") .. "Count"
			if (plr:GetAttribute(attr) or 0) < count then return false end
		end
		return true
	end

	if not VerifyOffer(p1, trade.P1_Offer) or not VerifyOffer(p2, trade.P2_Offer) then
		NotificationEvent:FireClient(p1, "Trade failed. Someone didn't have the required items.", "Error")
		NotificationEvent:FireClient(p2, "Trade failed. Someone didn't have the required items.", "Error")
		CancelTrade(tradeId)
		return
	end

	-- [[ SECURITY FIX: Force unequip if item is completely traded away ]]
	local function Deduct(plr, offer)
		plr.leaderstats.Dews.Value -= offer.Dews
		for iName, count in pairs(offer.Items) do
			local attr = iName:gsub("[^%w]", "") .. "Count"
			local newCount = (plr:GetAttribute(attr) or 0) - count
			plr:SetAttribute(attr, newCount)

			if newCount <= 0 then
				if plr:GetAttribute("EquippedWeapon") == iName then
					plr:SetAttribute("EquippedWeapon", "None")
					plr:SetAttribute("FightingStyle", "None")
				elseif plr:GetAttribute("EquippedAccessory") == iName then
					plr:SetAttribute("EquippedAccessory", "None")
				end
			end
		end
	end

	local function Give(plr, offer)
		plr.leaderstats.Dews.Value += offer.Dews
		for iName, count in pairs(offer.Items) do
			local attr = iName:gsub("[^%w]", "") .. "Count"
			plr:SetAttribute(attr, (plr:GetAttribute(attr) or 0) + count)
		end
	end

	Deduct(p1, trade.P1_Offer); Deduct(p2, trade.P2_Offer)
	Give(p1, trade.P2_Offer); Give(p2, trade.P1_Offer)

	NotificationEvent:FireClient(p1, "Trade Successful!", "Success")
	NotificationEvent:FireClient(p2, "Trade Successful!", "Success")
	CancelTrade(tradeId)
end

local function CheckStartCountdown(tradeId)
	local trade = ActiveTrades[tradeId]
	if not trade then return end

	if trade.P1_Ready and trade.P2_Ready then
		trade.IsCountingDown = true

		local p1 = Players:GetPlayerByUserId(trade.P1)
		local p2 = Players:GetPlayerByUserId(trade.P2)
		if p1 then TradeAction:FireClient(p1, "StartCountdown") end
		if p2 then TradeAction:FireClient(p2, "StartCountdown") end

		trade.CountdownTask = task.spawn(function()
			for i = 10, 1, -1 do
				if not ActiveTrades[tradeId] or not ActiveTrades[tradeId].IsCountingDown then return end
				if p1 then TradeAction:FireClient(p1, "UpdateTimer", i) end
				if p2 then TradeAction:FireClient(p2, "UpdateTimer", i) end
				task.wait(1)
			end
			if ActiveTrades[tradeId] and ActiveTrades[tradeId].IsCountingDown then
				ExecuteTrade(tradeId)
			end
		end)
	end
end

TradeAction.OnServerEvent:Connect(function(player, action, data)
	local uid = player.UserId

	if action == "SendRequest" then
		if player:GetAttribute("ActiveTradeId") and player:GetAttribute("ActiveTradeId") ~= "None" then
			NotificationEvent:FireClient(player, "You are currently in a trade! (Type /fixstrade if stuck)", "Error") return
		end

		local targetName = tostring(data)
		local target = nil
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Name:lower() == targetName:lower() then target = p; break end
		end

		if not target or target == player then 
			NotificationEvent:FireClient(player, "Invalid trade target.", "Error") return 
		end

		if target:GetAttribute("ActiveTradeId") and target:GetAttribute("ActiveTradeId") ~= "None" then
			NotificationEvent:FireClient(player, target.Name .. " is currently in a trade.", "Error") return
		end

		if not PendingRequests[target.UserId] then PendingRequests[target.UserId] = {} end

		PendingRequests[target.UserId][uid] = player.Name
		task.delay(30, function()
			if PendingRequests[target.UserId] then PendingRequests[target.UserId][uid] = nil end
		end)

		NotificationEvent:FireClient(player, "Trade request sent to " .. target.Name, "Success")
		TradeAction:FireClient(target, "IncomingRequest", uid, player.Name)

	elseif action == "ManageRequest" then
		if type(data) ~= "table" then return end
		local senderId = tonumber(data.SenderId)
		local decision = tostring(data.Decision) 

		if not senderId or not PendingRequests[uid] or not PendingRequests[uid][senderId] then return end
		PendingRequests[uid][senderId] = nil

		if decision == "Accept" then
			local sender = Players:GetPlayerByUserId(senderId)
			if not sender then NotificationEvent:FireClient(player, "Player is no longer online.", "Error") return end

			if sender:GetAttribute("ActiveTradeId") and sender:GetAttribute("ActiveTradeId") ~= "None" then
				NotificationEvent:FireClient(player, sender.Name .. " is already in another trade.", "Error") return
			end

			local tradeId = "Trade_" .. tostring(os.time()) .. "_" .. tostring(uid)
			ActiveTrades[tradeId] = {
				P1 = senderId, P2 = uid,
				P1_Offer = {Dews = 0, Items = {}},
				P2_Offer = {Dews = 0, Items = {}},
				P1_Ready = false, P2_Ready = false,
				IsCountingDown = false
			}

			player:SetAttribute("ActiveTradeId", tradeId)
			sender:SetAttribute("ActiveTradeId", tradeId)

			TradeAction:FireClient(sender, "TradeOpened", {TradeId = tradeId, Opponent = player.Name})
			TradeAction:FireClient(player, "TradeOpened", {TradeId = tradeId, Opponent = sender.Name})
		else
			NotificationEvent:FireClient(player, "Trade request denied.", "Info")
		end

	elseif action == "UpdateOffer" then
		if type(data) ~= "table" then return end
		local tradeId = player:GetAttribute("ActiveTradeId")
		local trade = ActiveTrades[tradeId]
		if not trade then return end

		if trade.IsCountingDown then AbortCountdown(tradeId) end

		local isP1 = (trade.P1 == uid)
		local myOffer = isP1 and trade.P1_Offer or trade.P2_Offer

		if data.Dews ~= nil then
			local newDews = math.floor(tonumber(data.Dews) or 0)
			if newDews ~= newDews then newDews = 0 end 
			if newDews < 0 then newDews = 0 end
			if newDews > player.leaderstats.Dews.Value then newDews = player.leaderstats.Dews.Value end
			myOffer.Dews = newDews
		end

		if data.ItemName then
			local itemName = tostring(data.ItemName)

			-- [[ SECURITY FIX: Do not allow Locked items to be traded ]]
			local isLocked = player:GetAttribute(itemName:gsub("[^%w]", "") .. "_Locked")
			if isLocked then
				NotificationEvent:FireClient(player, "You cannot trade Locked items!", "Error")
				return
			end

			local amount = math.floor(tonumber(data.Amount) or 1)
			if amount ~= amount then return end 

			local attrName = itemName:gsub("[^%w]", "") .. "Count"
			local amountOwned = player:GetAttribute(attrName) or 0

			local currentOffered = myOffer.Items[itemName] or 0
			local newAmount = currentOffered + amount

			if newAmount <= 0 then
				myOffer.Items[itemName] = nil
			elseif newAmount > amountOwned then
				return 
			else
				myOffer.Items[itemName] = newAmount
			end
		end

		trade.P1_Ready = false; trade.P2_Ready = false 

		local p1 = Players:GetPlayerByUserId(trade.P1); local p2 = Players:GetPlayerByUserId(trade.P2)
		if p1 then TradeAction:FireClient(p1, "UpdateOffers", trade.P1_Offer, trade.P2_Offer) end
		if p2 then TradeAction:FireClient(p2, "UpdateOffers", trade.P2_Offer, trade.P1_Offer) end
		if p1 then TradeAction:FireClient(p1, "UpdateStatus", false, false) end
		if p2 then TradeAction:FireClient(p2, "UpdateStatus", false, false) end

	elseif action == "ToggleReady" then
		local tradeId = player:GetAttribute("ActiveTradeId")
		local trade = ActiveTrades[tradeId]
		if not trade then return end

		if trade.IsCountingDown then 
			AbortCountdown(tradeId)
			return
		end

		if trade.P1 == uid then trade.P1_Ready = not trade.P1_Ready
		else trade.P2_Ready = not trade.P2_Ready end

		local p1 = Players:GetPlayerByUserId(trade.P1); local p2 = Players:GetPlayerByUserId(trade.P2)

		if p1 then TradeAction:FireClient(p1, "UpdateStatus", trade.P1_Ready, trade.P2_Ready) end
		if p2 then TradeAction:FireClient(p2, "UpdateStatus", trade.P2_Ready, trade.P1_Ready) end

		CheckStartCountdown(tradeId)

	elseif action == "Cancel" then
		local tradeId = player:GetAttribute("ActiveTradeId")
		if tradeId and tradeId ~= "None" then
			CancelTrade(tradeId)
		end
		player:SetAttribute("ActiveTradeId", "None")
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local tradeId = player:GetAttribute("ActiveTradeId")
	if tradeId and tradeId ~= "None" then CancelTrade(tradeId) end
	PendingRequests[player.UserId] = nil
end)