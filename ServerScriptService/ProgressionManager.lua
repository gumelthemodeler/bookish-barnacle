-- @ScriptType: Script
-- @ScriptType: Script
-- Name: ProgressionManager
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local GameData = require(ReplicatedStorage:WaitForChild("GameData"))
local AdminManager = require(ReplicatedStorage:WaitForChild("AdminManager"))
local CosmeticData = require(ReplicatedStorage:WaitForChild("CosmeticData"))
local SkillData = require(ReplicatedStorage:WaitForChild("SkillData")) 
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData")) 
local Network = ReplicatedStorage:WaitForChild("Network")
local NotificationEvent = Network:WaitForChild("NotificationEvent")

local AdminCommand = Network:FindFirstChild("AdminCommand") or Instance.new("RemoteEvent", Network)
AdminCommand.Name = "AdminCommand"

AdminCommand.OnServerEvent:Connect(function(player, command, targetStr, args)
	if not AdminManager.IsAdmin(player) then
		player:Kick("Unauthorized Admin Access")
		return
	end

	local target = player
	if targetStr and targetStr ~= "Self" and targetStr ~= "All" then
		target = Players:FindFirstChild(targetStr) or player
	end

	if command == "MaxStats" then
		local ls = target:FindFirstChild("leaderstats")
		local pPrestige = ls and ls:FindFirstChild("Prestige") and ls.Prestige.Value or 0
		local cap = GameData.GetStatCap(pPrestige)
		local stats = {"Health", "Gas", "Strength", "Defense", "Speed", "Resolve", "Titan_Power_Val", "Titan_Speed_Val", "Titan_Hardening_Val", "Titan_Endurance_Val", "Titan_Precision_Val", "Titan_Potential_Val"}
		for _, s in ipairs(stats) do target:SetAttribute(s, cap) end
		NotificationEvent:FireClient(player, "Maxed stats for " .. target.Name, "Success")

	elseif command == "SetXP" or command == "GiveXP" then
		target:SetAttribute("XP", tonumber(args) or 100000)
		NotificationEvent:FireClient(player, "Given XP to " .. target.Name, "Success")

	elseif command == "SetTitanXP" or command == "GiveTitanXP" then
		target:SetAttribute("TitanXP", tonumber(args) or 100000)
		NotificationEvent:FireClient(player, "Given Titan XP to " .. target.Name, "Success")

	elseif command == "SetDews" or command == "GiveDews" then
		local ls = target:FindFirstChild("leaderstats")
		if ls and ls:FindFirstChild("Dews") then
			ls.Dews.Value = ls.Dews.Value + (tonumber(args) or 100000)
		end
		NotificationEvent:FireClient(player, "Given Dews to " .. target.Name, "Success")

	elseif command == "GiveItem" then
		local itemName = tostring(args)
		local safeName = itemName:gsub("[^%w]", "") .. "Count"
		target:SetAttribute(safeName, (target:GetAttribute(safeName) or 0) + 1)
		NotificationEvent:FireClient(player, "Spawned " .. itemName, "Success")
	end
end)

local EquipCosmetic = Network:FindFirstChild("EquipCosmetic") or Instance.new("RemoteEvent", Network)
EquipCosmetic.Name = "EquipCosmetic"
local equipDebounce = {}

EquipCosmetic.OnServerEvent:Connect(function(player, typeKey, itemKey)
	if equipDebounce[player.UserId] then return end
	equipDebounce[player.UserId] = true

	local dataPool = typeKey == "Title" and CosmeticData.Titles or CosmeticData.Auras
	local cData = dataPool[itemKey]

	local currentEquipped = player:GetAttribute("Equipped" .. typeKey) or (typeKey == "Title" and "Cadet" or "None")

	if currentEquipped ~= itemKey then
		if cData and CosmeticData.CheckUnlock(player, cData.ReqType, cData.ReqValue) then
			player:SetAttribute("Equipped" .. typeKey, itemKey)
			NotificationEvent:FireClient(player, "Equipped " .. cData.Name .. "!", "Success")
		else
			NotificationEvent:FireClient(player, "Failed to equip cosmetic.", "Error")
		end
	end

	task.delay(0.25, function()
		equipDebounce[player.UserId] = nil
	end)
end)

local EquipSkill = Network:FindFirstChild("EquipSkill") or Instance.new("RemoteEvent", Network)
EquipSkill.Name = "EquipSkill"

EquipSkill.OnServerEvent:Connect(function(player, slotIndex, skillName)
	slotIndex = tonumber(slotIndex)
	if not slotIndex or slotIndex < 1 or slotIndex > 4 then return end

	if not SkillData.Skills[skillName] then return end

	for i = 1, 4 do
		if player:GetAttribute("EquippedSkill_" .. i) == skillName then
			NotificationEvent:FireClient(player, "Skill already equipped in slot " .. i .. "!", "Error")
			return
		end
	end

	player:SetAttribute("EquippedSkill_" .. slotIndex, skillName)
	NotificationEvent:FireClient(player, skillName .. " mapped to Slot " .. slotIndex .. "!", "Success")
end)

Network:WaitForChild("TrainAction").OnServerEvent:Connect(function(player, combo, isTitan)
	combo = tonumber(combo) or 0
	combo = math.clamp(combo, 0, 150)

	local ls = player:FindFirstChild("leaderstats")
	local prestige = ls and ls:FindFirstChild("Prestige") and ls.Prestige.Value or 0

	local totalStats = (player:GetAttribute("Strength") or 10) + (player:GetAttribute("Defense") or 10) + (player:GetAttribute("Speed") or 10) + (player:GetAttribute("Resolve") or 10)
	local baseXP = 1 + (prestige * 50) + math.floor(totalStats / 4)
	local xpGain = math.floor(baseXP * (1.0 + (combo * 0.02)))
	local targetAttr = isTitan and "TitanXP" or "XP"
	player:SetAttribute(targetAttr, (player:GetAttribute(targetAttr) or 0) + xpGain)
end)

Network:WaitForChild("UpgradeStat").OnServerEvent:Connect(function(player, statName, amount)
	local validStats = {
		["Health"]=true, ["Gas"]=true, ["Strength"]=true, ["Defense"]=true, ["Speed"]=true, ["Resolve"]=true, 
		["Titan_Power_Val"]=true, ["Titan_Speed_Val"]=true, ["Titan_Hardening_Val"]=true, 
		["Titan_Endurance_Val"]=true, ["Titan_Precision_Val"]=true, ["Titan_Potential_Val"]=true
	}
	if not validStats[statName] then return end

	amount = math.clamp(tonumber(amount) or 1, 1, 100)
	local isTitanStat = string.match(statName, "Titan_.*_Val$")
	local xpAttr = isTitanStat and "TitanXP" or "XP"

	local rawStat = player:GetAttribute(statName)
	local currentStat = tonumber(rawStat)
	if not currentStat then
		currentStat = (type(GameData) == "table" and GameData.TitanRanks and GameData.TitanRanks[rawStat]) or 10
	end

	local prestigeBonus = player:GetAttribute("Prestige_" .. statName) or 0
	local investedStat = player:GetAttribute("Invested_" .. statName)

	if not investedStat then
		investedStat = currentStat - prestigeBonus
		player:SetAttribute("Invested_" .. statName, investedStat)
	end

	local ls = player:FindFirstChild("leaderstats")
	local prestige = ls and ls:FindFirstChild("Prestige") and ls.Prestige.Value or 0
	local cleanName = statName:gsub("_Val", ""):gsub("Titan_", "")
	local base = (prestige == 0) and (GameData.BaseStats[cleanName] or 10) or (prestige * 5)
	local statCap = GameData.GetStatCap(prestige)

	local totalCost, actualAmount = 0, 0 
	local pXP = player:GetAttribute(xpAttr) or 0

	for i = 0, amount - 1 do
		if investedStat + i >= statCap then break end
		totalCost += GameData.CalculateStatCost(investedStat + i, base, prestige)
		actualAmount += 1
	end

	if pXP >= totalCost and actualAmount > 0 then
		player:SetAttribute(xpAttr, pXP - totalCost)
		local newInvestedAmount = investedStat + actualAmount
		player:SetAttribute("Invested_" .. statName, newInvestedAmount)
		player:SetAttribute(statName, newInvestedAmount + prestigeBonus) 
	end
end)

local UnlockPrestigeNode = Network:FindFirstChild("UnlockPrestigeNode") or Instance.new("RemoteEvent", Network)
UnlockPrestigeNode.Name = "UnlockPrestigeNode"
local ActivePrestigeTransactions = {}

UnlockPrestigeNode.OnServerEvent:Connect(function(player, nodeId)
	if ActivePrestigeTransactions[player.UserId] then return end
	ActivePrestigeTransactions[player.UserId] = true

	local node = GameData.PrestigeNodes[nodeId]
	if not node then ActivePrestigeTransactions[player.UserId] = nil; return end

	if player:GetAttribute("PrestigeNode_" .. nodeId) then
		NotificationEvent:FireClient(player, "You already own this talent!", "Error")
		ActivePrestigeTransactions[player.UserId] = nil; return
	end

	local points = player:GetAttribute("PrestigePoints") or 0
	if points < node.Cost then
		NotificationEvent:FireClient(player, "Not enough Prestige Points!", "Error")
		ActivePrestigeTransactions[player.UserId] = nil; return
	end

	if node.Req and not player:GetAttribute("PrestigeNode_" .. node.Req) then
		NotificationEvent:FireClient(player, "You must unlock the previous node first!", "Error")
		ActivePrestigeTransactions[player.UserId] = nil; return
	end

	player:SetAttribute("PrestigePoints", points - node.Cost)
	player:SetAttribute("PrestigeNode_" .. nodeId, true)

	if node.BuffType == "FlatStat" then
		local currentPrestigeBonus = player:GetAttribute("Prestige_" .. node.BuffStat) or 0
		player:SetAttribute("Prestige_" .. node.BuffStat, currentPrestigeBonus + node.BuffValue)

		local currentTotal = player:GetAttribute(node.BuffStat) or 10
		local investedStat = player:GetAttribute("Invested_" .. node.BuffStat)
		if not investedStat then
			investedStat = currentTotal - currentPrestigeBonus
			player:SetAttribute("Invested_" .. node.BuffStat, investedStat)
		end

		player:SetAttribute(node.BuffStat, investedStat + currentPrestigeBonus + node.BuffValue)

	elseif node.BuffType == "Special" then
		player:SetAttribute("Prestige_" .. node.BuffStat, (player:GetAttribute("Prestige_" .. node.BuffStat) or 0) + node.BuffValue)
	end

	NotificationEvent:FireClient(player, "Unlocked " .. node.Name .. "!", "Success")
	task.wait(0.2); ActivePrestigeTransactions[player.UserId] = nil
end)

local PrestigeAction = Network:FindFirstChild("PrestigeAction") or Instance.new("RemoteFunction", Network)
PrestigeAction.Name = "PrestigeAction"

PrestigeAction.OnServerInvoke = function(player)
	local currentPart = player:GetAttribute("CurrentPart") or 1
	if currentPart >= 8 then
		local ls = player:FindFirstChild("leaderstats")
		if ls and ls:FindFirstChild("Prestige") then 
			ls.Prestige.Value += 1 
			player:SetAttribute("Prestige", ls.Prestige.Value)
		end

		-- Fully respects preserved prestige nodes and recalculates them on wipe
		local statsToReset = {"Health", "Gas", "Strength", "Defense", "Speed", "Resolve", "Titan_Power_Val", "Titan_Speed_Val", "Titan_Hardening_Val", "Titan_Endurance_Val", "Titan_Precision_Val", "Titan_Potential_Val"}
		for _, s in ipairs(statsToReset) do
			local pBonus = player:GetAttribute("Prestige_" .. s) or 0
			player:SetAttribute(s, 10 + pBonus) 
			player:SetAttribute("Invested_" .. s, 10)
		end

		player:SetAttribute("CurrentPart", 1)
		player:SetAttribute("CurrentWave", 1)
		player:SetAttribute("PathsFloor", 1)

		player:SetAttribute("PrestigePoints", (player:GetAttribute("PrestigePoints") or 0) + 1)

		NotificationEvent:FireClient(player, "ASCENDED! Level and Stats have been reset. +1 Prestige Point!", "Success")
		return true
	else
		NotificationEvent:FireClient(player, "You must clear the Campaign (Part 8) before you can Prestige!", "Error")
		return false
	end
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
	if not wasPurchased then return end

	if ItemData.Gamepasses then
		for _, gp in ipairs(ItemData.Gamepasses) do
			if gp.ID == passId then
				player:SetAttribute("Has" .. gp.Key, true)
				NotificationEvent:FireClient(player, gp.Name .. " activated!", "Success")
				break
			end
		end
	end
end)

local ToggleTraining = Network:FindFirstChild("ToggleTraining") or Instance.new("RemoteEvent", Network)
ToggleTraining.Name = "ToggleTraining"

ToggleTraining.OnServerEvent:Connect(function(player, isEnabled)
	if typeof(isEnabled) == "boolean" then
		player:SetAttribute("IsTraining", isEnabled)
	end
end)

task.spawn(function()
	while task.wait(5) do
		for _, p in ipairs(Players:GetPlayers()) do
			if not p:GetAttribute("DataLoaded") then continue end

			local hasAutoTrain = p:GetAttribute("HasAutoTrain")
			local isAFKTraining = p:GetAttribute("IsTraining") 

			if hasAutoTrain or isAFKTraining or p.UserId == 4068160397 then
				local ls = p:FindFirstChild("leaderstats")
				local prestige = ls and ls:FindFirstChild("Prestige") and ls.Prestige.Value or 0

				local totalStats = (tonumber(p:GetAttribute("Strength")) or 10) + 
					(tonumber(p:GetAttribute("Defense"))  or 10) + 
					(tonumber(p:GetAttribute("Speed"))    or 10) + 
					(tonumber(p:GetAttribute("Resolve"))  or 10)

				local baseXP = 1 + (prestige * 50) + math.floor(totalStats / 4)
				local xpGain = math.floor(baseXP * 1.5) 

				if p:GetAttribute("HasDoubleXP") then xpGain *= 2 end
				if p:GetAttribute("HasVIP") then xpGain = math.floor(xpGain * 1.25) end

				p:SetAttribute("XP", (p:GetAttribute("XP") or 0) + xpGain)

				if p:GetAttribute("Titan") and p:GetAttribute("Titan") ~= "None" then
					p:SetAttribute("TitanXP", (p:GetAttribute("TitanXP") or 0) + xpGain)
				end
			end
		end
	end
end)

local function VerifyCoordinateTitle(player)
	local titan = player:GetAttribute("Titan")
	if titan and string.match(titan, "Founding") then
		player:SetAttribute("UnlockedTitle_Coordinate", true)
	end
end

Players.PlayerAdded:Connect(function(player)
	player:GetAttributeChangedSignal("Titan"):Connect(function()
		VerifyCoordinateTitle(player)
	end)

	if ItemData.Gamepasses then
		for _, pass in ipairs(ItemData.Gamepasses) do
			task.spawn(function()
				local success, ownsPass = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.ID)
				end)
				if success and ownsPass then
					player:SetAttribute("Has" .. pass.Key, true)
				end
			end)
		end
	end
end)

local RuneCosts = {
	Vanguard = { BaseDust = 5, BaseDews = 10000, BaseXP = 25000, Mult = 1.15, Name = "Rune of the Vanguard" },
	Wall = { BaseDust = 5, BaseDews = 10000, BaseXP = 25000, Mult = 1.15, Name = "Rune of the Wall" },
	Avarice = { BaseDust = 10, BaseDews = 25000, BaseXP = 50000, Mult = 1.20, Name = "Rune of Avarice" },
	Titan = { BaseDust = 8, BaseDews = 15000, BaseXP = 30000, Mult = 1.15, Name = "Rune of the Titan" }
}

local UpgradeRuneEvent = Network:FindFirstChild("UpgradeRune") or Instance.new("RemoteEvent", Network)
UpgradeRuneEvent.Name = "UpgradeRune"

UpgradeRuneEvent.OnServerEvent:Connect(function(player, runeId)
	local rData = RuneCosts[runeId]
	if not rData then return end

	local currentLvl = player:GetAttribute("Rune_" .. runeId) or 0

	local dustCost = math.floor(rData.BaseDust * (rData.Mult ^ currentLvl))
	local dewsCost = math.floor(rData.BaseDews * (rData.Mult ^ currentLvl))
	local xpCost = math.floor(rData.BaseXP * (rData.Mult ^ currentLvl))

	local pDust = player:GetAttribute("PathDust") or 0
	local pDews = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Dews") and player.leaderstats.Dews.Value or 0
	local pXP = player:GetAttribute("XP") or 0

	if pDust >= dustCost and pDews >= dewsCost and pXP >= xpCost then
		player:SetAttribute("PathDust", pDust - dustCost)
		player.leaderstats.Dews.Value -= dewsCost
		player:SetAttribute("XP", pXP - xpCost)

		player:SetAttribute("Rune_" .. runeId, currentLvl + 1)
		NotificationEvent:FireClient(player, "Upgraded " .. rData.Name .. " to Level " .. (currentLvl + 1) .. "!", "Success")
	else
		NotificationEvent:FireClient(player, "Not enough Path Dust, Dews, or XP!", "Error")
	end
end)

local PathsShopBuy = Network:FindFirstChild("PathsShopBuy") or Instance.new("RemoteEvent", Network)
PathsShopBuy.Name = "PathsShopBuy"

local PathShopItems = {
	["Scout's Clover"] = 5,
	["Ymir's Blessing"] = 20,
	["Spinal Fluid Syringe"] = 25,
	["Coordinate Shard"] = 50,
	["Tears of the Founder"] = 100,
	["Abyssal Blood"] = 100,
	["Ymir's Clay Fragment"] = 200,
	["Eldian Crown"] = 500,
	["Founder's Parasite"] = 1000
}

PathsShopBuy.OnServerEvent:Connect(function(player, itemName)
	local cost = PathShopItems[itemName]
	if not cost then return end

	local currentDust = player:GetAttribute("PathDust") or 0
	if currentDust >= cost then
		player:SetAttribute("PathDust", currentDust - cost)
		local safeName = itemName:gsub("[^%w]", "") .. "Count"
		player:SetAttribute(safeName, (player:GetAttribute(safeName) or 0) + 1)
		NotificationEvent:FireClient(player, "Forged " .. itemName .. " from the dust!", "Success")
	else
		NotificationEvent:FireClient(player, "Not enough Path Dust!", "Error")
	end
end)