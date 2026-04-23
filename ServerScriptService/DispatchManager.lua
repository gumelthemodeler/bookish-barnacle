-- @ScriptType: Script
-- @ScriptType: Script
-- @ScriptType: Script
-- Name: DispatchManager
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LootManager = require(script.Parent:WaitForChild("LootManager"))

local RemotesFolder = ReplicatedStorage:WaitForChild("Network")

local function GetDispatchData(player)
	local raw = player:GetAttribute("DispatchData")
	if not raw or raw == "" then return {} end
	local success, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
	return success and decoded or {}
end

local function SaveDispatchData(player, dataTable)
	local success, encoded = pcall(function() return HttpService:JSONEncode(dataTable) end)
	if success then player:SetAttribute("DispatchData", encoded) end
end

local function GetAllyLevels(player)
	local raw = player:GetAttribute("AllyLevels")
	if not raw or raw == "" then return {} end
	local success, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
	return success and decoded or {}
end

local function SaveAllyLevels(player, dataTable)
	local success, encoded = pcall(function() return HttpService:JSONEncode(dataTable) end)
	if success then player:SetAttribute("AllyLevels", encoded) end
end

local function UpdateBountyProgress(plr, taskType, amt)
	for i = 1, 3 do
		if plr:GetAttribute("D"..i.."_Task") == taskType and not plr:GetAttribute("D"..i.."_Claimed") then
			local p = plr:GetAttribute("D"..i.."_Prog") or 0; local m = plr:GetAttribute("D"..i.."_Max") or 1
			plr:SetAttribute("D"..i.."_Prog", math.min(p + amt, m))
		end
	end
	if plr:GetAttribute("W1_Task") == taskType and not plr:GetAttribute("W1_Claimed") then
		local p = plr:GetAttribute("W1_Prog") or 0; local m = plr:GetAttribute("W1_Max") or 1
		plr:SetAttribute("W1_Prog", math.min(p + amt, m))
	end
end

-- [[ Dynamic Ally Events ]]
local DispatchEvents = {
	{ Chance = 10, Name = "Aberrant Encounter", DewMod = 0.5, XPMod = 1.5, LootBonus = 0, Msg = "<font color='#FF5555'>Fought off an Aberrant! Lost some supplies but gained massive combat experience.</font>" },
	{ Chance = 15, Name = "Hidden Cache", DewMod = 2.0, XPMod = 1.0, LootBonus = 2, Msg = "<font color='#55FF55'>Found an abandoned supply cache! Loot significantly increased.</font>" },
	{ Chance = 10, Name = "Harsh Weather", DewMod = 0.8, XPMod = 0.8, LootBonus = -1, Msg = "<font color='#AAAAAA'>Caught in a severe rainstorm. Progress was painfully slow.</font>" },
	{ Chance = 65, Name = "Routine", DewMod = 1.0, XPMod = 1.0, LootBonus = 0, Msg = "The expedition went smoothly." }
}

RemotesFolder:WaitForChild("DispatchAction").OnServerEvent:Connect(function(player, action, allyName)
	local dData = GetDispatchData(player)
	local allyLevels = GetAllyLevels(player)
	local maxDeployments = player:GetAttribute("MaxDeployments") or 2

	if action == "UnlockAlly" then
		local AllyCosts = {
			["Armin Arlert"] = 1000, ["Sasha Braus"] = 2500, ["Connie Springer"] = 2500,
			["Jean Kirstein"] = 5000, ["Hange Zoe"] = 10000, ["Erwin Smith"] = 20000,
			["Mikasa Ackerman"] = 50000, ["Levi Ackerman"] = 100000
		}

		local cost = AllyCosts[allyName]
		if not cost then return end

		local unlocked = player:GetAttribute("UnlockedAllies") or ""
		if string.find(unlocked, "%[" .. allyName .. "%]") then return end

		if player.leaderstats.Dews.Value >= cost then
			player.leaderstats.Dews.Value -= cost
			player:SetAttribute("UnlockedAllies", unlocked .. "[" .. allyName .. "]")
			RemotesFolder.NotificationEvent:FireClient(player, "Successfully recruited " .. allyName .. "!", "Success")
		else
			RemotesFolder.NotificationEvent:FireClient(player, "Not enough Dews to recruit!", "Error")
		end

	elseif action == "Deploy" then
		if dData[allyName] then return end

		local currentActive = 0
		for _, _ in pairs(dData) do currentActive += 1 end
		if currentActive >= maxDeployments then
			RemotesFolder.NotificationEvent:FireClient(player, "Deployment capacity reached! Upgrade slots to send more.", "Error")
			return
		end

		dData[allyName] = { StartTime = os.time(), Type = "Ally" }
		SaveDispatchData(player, dData)
		RemotesFolder.NotificationEvent:FireClient(player, allyName .. " dispatched for expedition!", "Success")

	elseif action == "Recall" then
		local info = dData[allyName]
		if not info then return end

		-- [[ THE FIX: Safely handles older dispatches from before the Regiment Update ]]
		if info.Type ~= nil and info.Type ~= "Ally" then return end

		local elapsedMins = math.floor((os.time() - info.StartTime) / 60)
		elapsedMins = math.min(elapsedMins, 720)

		if elapsedMins < 1 then
			RemotesFolder.NotificationEvent:FireClient(player, allyName .. " returned early and empty-handed.", "Error")
			dData[allyName] = nil; SaveDispatchData(player, dData); return
		end

		local lvl = allyLevels[allyName] or 1
		local lvlMultiplier = 1 + ((lvl - 1) * 0.20) 

		local randEvent = nil
		local roll = math.random(1, 100)
		local cum = 0
		for _, e in ipairs(DispatchEvents) do
			cum += e.Chance
			if roll <= cum then randEvent = e break end
		end

		local dewsGained = math.floor((elapsedMins * 12) * lvlMultiplier * randEvent.DewMod)
		local xpGained = math.floor((elapsedMins * 5) * lvlMultiplier * randEvent.XPMod)

		local winReg = RemotesFolder:FindFirstChild("WinningRegiment")
		if winReg and winReg.Value ~= "None" and player:GetAttribute("Regiment") == winReg.Value then
			dewsGained = math.floor(dewsGained * 1.15)
			xpGained = math.floor(xpGained * 1.15)
		end

		local rolls = math.max(0, math.floor(elapsedMins / 30) + randEvent.LootBonus)
		local itemsFound = {}

		for i = 1, rolls do
			local rng = math.random(1, 100)
			if rng <= 10 then table.insert(itemsFound, "Standard Titan Serum")
			elseif rng <= 30 then table.insert(itemsFound, "Garrison Supply Crate")
			elseif rng <= 50 then table.insert(itemsFound, "Worn Trainee Badge")
			end
		end

		player.leaderstats.Dews.Value += dewsGained
		player:SetAttribute("XP", (player:GetAttribute("XP") or 0) + xpGained)
		UpdateBountyProgress(player, "Dispatch", 1)

		local dropLog = randEvent.Msg .. "\nCollected: " .. dewsGained .. " Dews, " .. xpGained .. " XP."
		for _, item in ipairs(itemsFound) do
			LootManager.GiveOrAutoSellItem(player, item, 1)
			dropLog = dropLog .. "\nFound: " .. item
		end

		dData[allyName] = nil; SaveDispatchData(player, dData)
		RemotesFolder.NotificationEvent:FireClient(player, allyName .. " returned!\n" .. dropLog, "Success")

	elseif action == "RegimentDeploy" then
		local regName = player:GetAttribute("Regiment") or "Cadet Corps"
		if dData["RegimentSquad"] then return end

		local cost = 25000 
		if player.leaderstats.Dews.Value < cost then
			RemotesFolder.NotificationEvent:FireClient(player, "Requires 25,000 Dews to fund a Regiment Expedition!", "Error")
			return
		end

		player.leaderstats.Dews.Value -= cost
		dData["RegimentSquad"] = { StartTime = os.time(), Type = "Regiment", Regiment = regName }
		SaveDispatchData(player, dData)
		RemotesFolder.NotificationEvent:FireClient(player, regName .. " Squad deployed! Supplies secured.", "Success")

	elseif action == "RegimentRecall" then
		local info = dData["RegimentSquad"]
		if not info or info.Type ~= "Regiment" then return end

		local elapsedMins = math.floor((os.time() - info.StartTime) / 60)
		elapsedMins = math.min(elapsedMins, 1440) -- Cap to 24 Hours

		if elapsedMins < 60 then
			RemotesFolder.NotificationEvent:FireClient(player, "Squad recalled too early. Only partial funds recovered.", "Error")
			player.leaderstats.Dews.Value += 10000 -- Give back a partial refund for recalling early
			dData["RegimentSquad"] = nil; SaveDispatchData(player, dData); return
		end

		local regName = info.Regiment
		local dewsGained = 0
		local itemsFound = {}
		local log = ""

		local rolls = math.floor(elapsedMins / 60) -- 1 item roll per hour

		if regName == "Scout Regiment" then
			dewsGained = elapsedMins * 15
			for i = 1, rolls do
				local rng = math.random(1, 100)
				if rng <= 10 then table.insert(itemsFound, "Abyssal Blood")
				elseif rng <= 25 then table.insert(itemsFound, "Glowing Titan Crystal")
				elseif rng <= 60 then table.insert(itemsFound, "Iron Bamboo Heart")
				end
			end
			log = "<font color='#55AAFF'>Scouts successfully extracted core materials.</font>"

		elseif regName == "Garrison" then
			dewsGained = elapsedMins * 45
			for i = 1, rolls do
				local rng = math.random(1, 100)
				if rng <= 15 then table.insert(itemsFound, "Titan Hardening Extract")
				elseif rng <= 50 then table.insert(itemsFound, "Garrison Supply Crate")
				end
			end
			log = "<font color='#FF5555'>Garrison successfully secured the perimeter.</font>"

		elseif regName == "Military Police" then
			dewsGained = elapsedMins * 75
			for i = 1, rolls do
				local rng = math.random(1, 100)
				if rng <= 5 then table.insert(itemsFound, "Spinal Fluid Syringe")
				elseif rng <= 15 then table.insert(itemsFound, "Clan Blood Vial")
				elseif rng <= 40 then table.insert(itemsFound, "Standard Titan Serum")
				end
			end
			log = "<font color='#55FF55'>Military Police secured inner-wall taxes.</font>"

		else
			dewsGained = elapsedMins * 10
			log = "<font color='#AAAAAA'>Cadets finished their training march.</font>"
		end

		player.leaderstats.Dews.Value += dewsGained
		local dropLog = log .. "\nSecured: " .. dewsGained .. " Dews."
		for _, item in ipairs(itemsFound) do
			LootManager.GiveOrAutoSellItem(player, item, 1)
			dropLog = dropLog .. "\nFound: " .. item
		end

		dData["RegimentSquad"] = nil; SaveDispatchData(player, dData)
		RemotesFolder.NotificationEvent:FireClient(player, "Regiment Squad returned safely!\n" .. dropLog, "Success")

	elseif action == "UpgradeAlly" then
		local lvl = allyLevels[allyName] or 1
		if lvl >= 10 then
			RemotesFolder.NotificationEvent:FireClient(player, allyName .. " is already MAX Level!", "Error")
			return
		end

		local cost = 5000 * lvl
		if player.leaderstats.Dews.Value >= cost then
			player.leaderstats.Dews.Value -= cost
			allyLevels[allyName] = lvl + 1
			SaveAllyLevels(player, allyLevels)
			RemotesFolder.NotificationEvent:FireClient(player, allyName .. " upgraded to Level " .. (lvl + 1) .. "!", "Success")
		else
			RemotesFolder.NotificationEvent:FireClient(player, "Not enough Dews to upgrade ally! (" .. cost .. " required)", "Error")
		end

	elseif action == "UpgradeCapacity" then
		if maxDeployments >= 8 then
			RemotesFolder.NotificationEvent:FireClient(player, "You have reached the maximum deployment capacity!", "Error")
			return
		end

		local cost = 100000
		if player.leaderstats.Dews.Value >= cost then
			player.leaderstats.Dews.Value -= cost
			player:SetAttribute("MaxDeployments", maxDeployments + 1)
			RemotesFolder.NotificationEvent:FireClient(player, "Deployment capacity increased to " .. (maxDeployments + 1) .. "!", "Success")
		else
			RemotesFolder.NotificationEvent:FireClient(player, "Not enough Dews! Needs 100,000.", "Error")
		end
	end
end)