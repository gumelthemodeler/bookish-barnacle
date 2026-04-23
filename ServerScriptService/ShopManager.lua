-- @ScriptType: Script
-- @ScriptType: Script
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))
local GameData = require(ReplicatedStorage:WaitForChild("GameData")) 
local TitanData = require(ReplicatedStorage:WaitForChild("TitanData")) 
local GameDataStore = DataStoreService:GetDataStore("AoT_Data_V5") 

local Network = ReplicatedStorage:WaitForChild("Network")
local GetShopData = Network:WaitForChild("GetShopData")
local BuyAction = Network:FindFirstChild("ShopAction") or Instance.new("RemoteEvent", Network)
BuyAction.Name = "ShopAction"
local NotificationEvent = Network:WaitForChild("NotificationEvent")

-- [[ THE NEW HOOK: Transcendent / Abyssal Altar Roll ]]
local AbyssalRollEvent = Network:FindFirstChild("AbyssalRoll") or Instance.new("RemoteEvent", Network)
AbyssalRollEvent.Name = "AbyssalRoll"

AbyssalRollEvent.OnServerEvent:Connect(function(player)
	local currentClan = player:GetAttribute("Clan") or "None"
	if not string.find(currentClan, "Awakened") then
		NotificationEvent:FireClient(player, "You must be Awakened to step into the Abyss.", "Error")
		return
	end

	local ls = player:FindFirstChild("leaderstats")
	local dews = ls and ls:FindFirstChild("Dews")
	local abyssalBlood = player:GetAttribute("AbyssalBloodCount") or 0

	if dews and dews.Value >= 5000000 and abyssalBlood >= 1 then
		dews.Value -= 5000000
		player:SetAttribute("AbyssalBloodCount", abyssalBlood - 1)

		local baseClan = string.gsub(currentClan, "Awakened ", "")
		player:SetAttribute("Clan", "Abyssal " .. baseClan)

		NotificationEvent:FireClient(player, "Your bloodline has transcended.", "Success")

		task.spawn(function()
			pcall(function()
				local d = { 
					Prestige = ls:FindFirstChild("Prestige") and ls.Prestige.Value or 0, 
					Dews = dews.Value, 
					Elo = ls:FindFirstChild("Elo") and ls.Elo.Value or 1000 
				}
				for k, v in pairs(player:GetAttributes()) do if k ~= "DataLoaded" then d[k] = v end end
				GameDataStore:SetAsync(player.UserId, d)
			end)
		end)
	else
		NotificationEvent:FireClient(player, "Insufficient tribute for the Altar.", "Error")
	end
end)

local MAX_INVENTORY_CAPACITY = 50
local function GetUniqueSlotCount(plr)
	local count = 0
	if ItemData.Equipment then
		for iName, _ in pairs(ItemData.Equipment) do
			if (plr:GetAttribute(iName:gsub("[^%w]", "") .. "Count") or 0) > 0 then count += 1 end
		end
	end
	if ItemData.Consumables then
		for iName, _ in pairs(ItemData.Consumables) do
			if (plr:GetAttribute(iName:gsub("[^%w]", "") .. "Count") or 0) > 0 then count += 1 end
		end
	end
	return count
end

local PathNodes = {
	["Path of the Striker"] = { Stat = "DMG", Cost = 5, Increment = 5, MaxLevel = 10, Desc = "+5% Base Damage" },
	["Path of the Phantom"] = { Stat = "DODGE", Cost = 8, Increment = 2, MaxLevel = 10, Desc = "+2% Dodge Chance" },
	["Path of the Juggernaut"] = { Stat = "MAX HP", Cost = 5, Increment = 50, MaxLevel = 10, Desc = "+50 Max HP" },
	["Path of the Executioner"] = { Stat = "CRIT", Cost = 10, Increment = 2, MaxLevel = 10, Desc = "+2% Crit Chance" },
	["Path of the Breaker"] = { Stat = "IGNORE", Cost = 15, Increment = 5, MaxLevel = 5, Desc = "+5% Armor Penetration" }
}

local RarePathsItems = {
	{ Name = "Coordinate's Sand", Cost = 100, Desc = "Godlike power. The rarest relic in the Paths." },
	{ Name = "Ymir's Clay Fragment", Cost = 200, Desc = "Awakens the Attack Titan into the Founding Attack Titan." },
	{ Name = "Titan Hardening Extract", Cost = 25, Desc = "Used in the Forge to Awaken max-tier weapons." }
}

local itemPool = {}

for name, data in pairs(ItemData.Equipment or {}) do 
	if not data.IsGift and not data.Cursed and data.Rarity ~= "Transcendent" then 
		table.insert(itemPool, {Name = name, Data = data}) 
	end
end

for name, data in pairs(ItemData.Consumables or {}) do 
	local lowerName = string.lower(name)
	local isBannedFromShop = string.find(lowerName, "serum") 
		or string.find(lowerName, "vial") 
		or string.find(lowerName, "syringe")
		or string.find(lowerName, "itemized") 
		or name == "Ymir's Clay Fragment"
		or name == "Titan Hardening Extract"
		or data.Rarity == "Transcendent"

	if not data.IsGift and not isBannedFromShop then table.insert(itemPool, {Name = name, Data = data}) end
end

local function GenerateShopItems(seed)
	local rng = Random.new(seed)
	local shopItems = {}
	local selectedNames = {}

	for i = 1, 6 do
		local roll = rng:NextNumber(0, 100)
		local targetRarity = "Common"

		if roll <= 0.2 then targetRarity = "Mythical"
		elseif roll <= 2.0 then targetRarity = "Legendary"
		elseif roll <= 10.0 then targetRarity = "Epic"
		elseif roll <= 30.0 then targetRarity = "Rare"
		elseif roll <= 60.0 then targetRarity = "Uncommon" end

		local validItems = {}
		for _, item in ipairs(itemPool) do
			if (item.Data.Rarity or "Common") == targetRarity and not selectedNames[item.Name] then
				table.insert(validItems, item)
			end
		end

		if #validItems == 0 then
			for _, item in ipairs(itemPool) do
				if not selectedNames[item.Name] then table.insert(validItems, item) end
			end
		end

		if #validItems > 0 then
			local picked = validItems[rng:NextInteger(1, #validItems)]
			selectedNames[picked.Name] = true
			table.insert(shopItems, {Name = picked.Name, Cost = picked.Data.Cost or 1000})
		else
			break
		end
	end
	return shopItems
end

GetShopData.OnServerInvoke = function(player, requestType)
	if requestType == "PathsShop" then
		local pData = {}
		for nodeName, nodeData in pairs(PathNodes) do
			local safeNodeName = string.gsub(nodeName, "[^%w]", "")
			local currentLvl = player:GetAttribute("PathNode_" .. safeNodeName) or 0

			table.insert(pData, {
				Name = nodeName, Desc = nodeData.Desc, 
				CurrentLevel = currentLvl, MaxLevel = nodeData.MaxLevel, 
				Cost = currentLvl < nodeData.MaxLevel and nodeData.Cost or "MAX"
			})
		end
		return { Nodes = pData, Items = RarePathsItems, Dust = player:GetAttribute("PathDust") or 0 }
	end

	local timeCycle = math.floor(os.time() / 600)
	local savedCycle = player:GetAttribute("ShopSeedTime")

	if savedCycle ~= timeCycle then
		player:SetAttribute("ShopSeedTime", timeCycle)
		local newSeed = timeCycle + player.UserId + math.random(1, 99999)
		player:SetAttribute("PersonalShopSeed", newSeed)
		player:SetAttribute("ShopPurchases_Seed", newSeed)
		player:SetAttribute("ShopPurchases_Data", "")
	end

	local activeSeed = player:GetAttribute("PersonalShopSeed")
	local timeRemaining = 600 - (os.time() % 600)
	local items = GenerateShopItems(activeSeed)

	local boughtStr = player:GetAttribute("ShopPurchases_Data") or ""
	for _, item in ipairs(items) do
		if string.find(boughtStr, "%[" .. item.Name .. "%]") then item.SoldOut = true end
	end

	return { Items = items, TimeLeft = timeRemaining }
end

BuyAction.OnServerEvent:Connect(function(player, actionType, itemName)
	local targetPurchase = itemName
	if not itemName and actionType ~= "BuyPathNode" and actionType ~= "ClosePathsShop" and actionType ~= "BuyPathsItem" and actionType ~= "PromptPremium" and actionType ~= "PromptGift" then
		targetPurchase = actionType
	end

	if actionType == "PromptPremium" then
		local targetName = itemName
		local targetId = nil
		local isGamepass = false

		if ItemData.Gamepasses then
			for _, gp in ipairs(ItemData.Gamepasses) do
				if string.upper(gp.Name) == string.upper(targetName) then
					targetId = gp.ID
					isGamepass = true
					break
				end
			end
		end

		if not targetId and ItemData.Products then
			for _, prod in ipairs(ItemData.Products) do
				if string.upper(prod.Name or prod.ItemName or "") == string.upper(targetName) then
					targetId = prod.ID
					break
				end
			end
		end

		if targetId then
			if isGamepass then
				MarketplaceService:PromptGamePassPurchase(player, targetId)
			else
				MarketplaceService:PromptProductPurchase(player, targetId)
			end
		else
			NotificationEvent:FireClient(player, "Premium Item ID not configured yet.", "Error")
		end
		return

	elseif actionType == "PromptGift" then
		local targetName = itemName
		local targetId = nil

		if ItemData.Products then
			for _, prod in ipairs(ItemData.Products) do
				if prod.IsGift and string.upper(prod.TargetPass or "") == string.upper(targetName) then
					targetId = prod.ID
					break
				end
			end
		end

		if targetId then
			MarketplaceService:PromptProductPurchase(player, targetId)
		else
			NotificationEvent:FireClient(player, "Gift version not configured yet.", "Error")
		end
		return

	elseif actionType == "BuyPathNode" then
		local nodeData = PathNodes[targetPurchase]
		if not nodeData then return end

		local safeTarget = string.gsub(targetPurchase, "[^%w]", "")
		local currentLvl = player:GetAttribute("PathNode_" .. safeTarget) or 0

		if currentLvl >= nodeData.MaxLevel then return end

		local dust = player:GetAttribute("PathDust") or 0
		if dust >= nodeData.Cost then
			player:SetAttribute("PathDust", dust - nodeData.Cost)
			player:SetAttribute("PathNode_" .. safeTarget, currentLvl + 1)

			local currentString = player:GetAttribute("PathsAwakened") or ""
			local newString = ""
			for stat in string.gmatch(currentString, "[^|]+") do
				if not string.find(stat, nodeData.Stat) then newString = newString .. stat .. "|" end
			end
			local totalStatValue = (currentLvl + 1) * nodeData.Increment
			newString = newString .. " +" .. totalStatValue .. " " .. nodeData.Stat .. "|"
			player:SetAttribute("PathsAwakened", newString)

			NotificationEvent:FireClient(player, "Coordinate Memory Unlocked!", "Success")
		else
			NotificationEvent:FireClient(player, "Not enough Path Dust!", "Error")
		end
		return

	elseif actionType == "BuyPathsItem" then
		local itemDef = nil
		for _, it in ipairs(RarePathsItems) do if it.Name == targetPurchase then itemDef = it; break end end
		if not itemDef then return end

		local dust = player:GetAttribute("PathDust") or 0
		if dust >= itemDef.Cost then
			player:SetAttribute("PathDust", dust - itemDef.Cost)
			local safeName = targetPurchase:gsub("[^%w]", "") .. "Count"
			player:SetAttribute(safeName, (player:GetAttribute(safeName) or 0) + 1)
			NotificationEvent:FireClient(player, "Obtained " .. targetPurchase .. " from the Paths!", "Success")
		else
			NotificationEvent:FireClient(player, "Not enough Path Dust!", "Error")
		end
		return

	elseif actionType == "ClosePathsShop" then
		player:SetAttribute("PathDust", 0)
		NotificationEvent:FireClient(player, "Path Dust scattered. Returning to reality.", "Info")
		return
	end

	local timeCycle = math.floor(os.time() / 600)
	local savedCycle = player:GetAttribute("ShopSeedTime")

	if savedCycle ~= timeCycle then
		NotificationEvent:FireClient(player, "The shop just restocked! Please wait.", "Error")
		return
	end

	local activeSeed = player:GetAttribute("PersonalShopSeed")
	if not activeSeed then return end

	local availableItems = GenerateShopItems(activeSeed)

	local targetItem = nil
	for _, item in ipairs(availableItems) do
		if item.Name == targetPurchase then targetItem = item; break end
	end

	if targetItem then
		local boughtStr = player:GetAttribute("ShopPurchases_Data") or ""
		if string.find(boughtStr, "%[" .. targetItem.Name .. "%]") then return end 

		local attrName = targetItem.Name:gsub("[^%w]", "") .. "Count"
		local currentCount = player:GetAttribute(attrName) or 0

		if currentCount == 0 then
			local maxInv = player:GetAttribute("HasBackpackExpansion") and 100 or MAX_INVENTORY_CAPACITY
			if GetUniqueSlotCount(player) >= maxInv then
				NotificationEvent:FireClient(player, "Your inventory is full! Sell items at the Forge.", "Error")
				return
			end
		end

		if player.leaderstats.Dews.Value >= targetItem.Cost then
			player.leaderstats.Dews.Value -= targetItem.Cost
			player:SetAttribute(attrName, currentCount + 1)
			player:SetAttribute("ShopPurchases_Data", boughtStr .. "[" .. targetItem.Name .. "]")
			NotificationEvent:FireClient(player, "Purchased " .. targetItem.Name .. "!", "Success")
		else
			NotificationEvent:FireClient(player, "Not enough Dews!", "Error")
		end
	end
end)

local VIPFreeReroll = Network:FindFirstChild("VIPFreeReroll") or Instance.new("RemoteEvent", Network)
VIPFreeReroll.Name = "VIPFreeReroll"

VIPFreeReroll.OnServerEvent:Connect(function(player, isDews)
	local canReroll = false

	if isDews then
		local dews = player.leaderstats and player.leaderstats:FindFirstChild("Dews")
		if dews and dews.Value >= 300000 then
			dews.Value -= 300000
			canReroll = true
		end
	else
		local hasVIP = player:GetAttribute("HasVIP")
		local lastRoll = player:GetAttribute("LastFreeReroll") or 0
		if hasVIP and (os.time() - lastRoll) >= 86400 then
			player:SetAttribute("LastFreeReroll", os.time())
			canReroll = true
		end
	end

	if canReroll then
		local newSeed = os.time() + math.random(1, 9999999)
		player:SetAttribute("PersonalShopSeed", newSeed)
		player:SetAttribute("ShopSeedTime", math.floor(os.time() / 600))
		player:SetAttribute("ShopPurchases_Seed", newSeed)
		player:SetAttribute("ShopPurchases_Data", "")
		NotificationEvent:FireClient(player, "Shop Successfully Rerolled!", "Success")
	else
		NotificationEvent:FireClient(player, "Reroll failed. Missing requirements.", "Error")
	end
end)

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end

	local handled = false
	if ItemData.Products then
		for _, prod in ipairs(ItemData.Products) do
			if prod.ID == receiptInfo.ProductId then
				if prod.IsReroll then
					local newSeed = os.time() + math.random(1, 9999999)
					player:SetAttribute("PersonalShopSeed", newSeed)
					player:SetAttribute("ShopSeedTime", math.floor(os.time() / 600))
					player:SetAttribute("ShopPurchases_Seed", newSeed)
					player:SetAttribute("ShopPurchases_Data", "")
					NotificationEvent:FireClient(player, "Shop Successfully Rerolled!", "Success")
				elseif prod.Reward == "Dews" then
					local ls = player:FindFirstChild("leaderstats")
					if ls and ls:FindFirstChild("Dews") then
						ls.Dews.Value += prod.Amount
					end
					NotificationEvent:FireClient(player, "Purchased " .. prod.Amount .. " Dews!", "Success")
				elseif prod.Reward == "Item" then
					local attrName = prod.ItemName:gsub("[^%w]", "") .. "Count"
					player:SetAttribute(attrName, (player:GetAttribute(attrName) or 0) + prod.Amount)
					NotificationEvent:FireClient(player, "Purchased " .. prod.ItemName .. "!", "Success")
				elseif prod.IsGift then
					local giftName = (prod.TargetPass or "Premium") .. " Gift"
					local attrName = giftName:gsub("[^%w]", "") .. "Count"
					player:SetAttribute(attrName, (player:GetAttribute(attrName) or 0) + 1)
					NotificationEvent:FireClient(player, "You received a " .. giftName .. " item!", "Success")
				end
				handled = true
				break
			end
		end
	end

	if handled then
		task.spawn(function()
			pcall(function()
				local ls = player:FindFirstChild("leaderstats")
				local d = { 
					Prestige = ls and ls:FindFirstChild("Prestige") and ls.Prestige.Value or 0, 
					Dews = ls and ls:FindFirstChild("Dews") and ls.Dews.Value or 0, 
					Elo = ls and ls:FindFirstChild("Elo") and ls.Elo.Value or 1000 
				}
				for k, v in pairs(player:GetAttributes()) do if k ~= "DataLoaded" then d[k] = v end end
				GameDataStore:SetAsync(player.UserId, d)
			end)
		end)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if wasPurchased then
		if ItemData.Gamepasses then
			for _, gp in ipairs(ItemData.Gamepasses) do
				if gp.ID == gamePassId then
					if string.find(string.upper(gp.Name), "VIP") then
						player:SetAttribute("HasVIP", true)
					elseif string.find(string.upper(gp.Name), "2X EXP") then
						player:SetAttribute("Has2xEXP", true)
					elseif string.find(string.upper(gp.Name), "EXPANSION") then
						player:SetAttribute("HasBackpackExpansion", true)
					end

					NotificationEvent:FireClient(player, "Successfully purchased " .. gp.Name .. "!", "Success")

					task.spawn(function()
						pcall(function()
							local ls = player:FindFirstChild("leaderstats")
							local d = { 
								Prestige = ls and ls:FindFirstChild("Prestige") and ls.Prestige.Value or 0, 
								Dews = ls and ls:FindFirstChild("Dews") and ls.Dews.Value or 0, 
								Elo = ls and ls:FindFirstChild("Elo") and ls.Elo.Value or 1000 
							}
							for k, v in pairs(player:GetAttributes()) do if k ~= "DataLoaded" then d[k] = v end end
							GameDataStore:SetAsync(player.UserId, d)
						end)
					end)
					break
				end
			end
		end
	end
end)