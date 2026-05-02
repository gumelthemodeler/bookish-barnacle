-- @ScriptType: Script
-- @ScriptType: Script
-- Name: ForgeManager
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))
local TitanData = require(ReplicatedStorage:WaitForChild("TitanData"))
local Network = ReplicatedStorage:WaitForChild("Network")
local NotificationEvent = Network:WaitForChild("NotificationEvent")

local FusionComplete = Network:FindFirstChild("FusionComplete") or Instance.new("RemoteEvent", Network)
FusionComplete.Name = "FusionComplete"

local MutateTitan = Network:FindFirstChild("MutateTitan") or Instance.new("RemoteFunction", Network)
MutateTitan.Name = "MutateTitan"

local FusionRecipes = { 
	["Female Titan"] = { ["Founding Titan"] = "Founding Female Titan" }, 
	["Founding Titan"] = { ["Female Titan"] = "Founding Female Titan", ["Attack Titan"] = "Founding Attack Titan" }, 
	["Attack Titan"] = { ["Armored Titan"] = "Armored Attack Titan", ["War Hammer Titan"] = "War Hammer Attack Titan", ["Founding Titan"] = "Founding Attack Titan" }, 
	["Armored Titan"] = { ["Attack Titan"] = "Armored Attack Titan" }, 
	["War Hammer Titan"] = { ["Attack Titan"] = "War Hammer Attack Titan" }, 
	["Colossal Titan"] = { ["Jaw Titan"] = "Colossal Jaw Titan" }, 
	["Jaw Titan"] = { ["Colossal Titan"] = "Colossal Jaw Titan" } 
}

local function GetItemCount(plr, matName)
	local safe1 = matName:gsub("[^%w]", "") .. "Count"
	local safe2 = matName:gsub("[^%w]", "")
	local safe3 = matName .. "Count"
	local safe4 = matName
	return tonumber(plr:GetAttribute(safe1)) or 
		tonumber(plr:GetAttribute(safe2)) or 
		tonumber(plr:GetAttribute(safe3)) or 
		tonumber(plr:GetAttribute(safe4)) or 0
end

local function DeductItem(plr, matName, amt)
	local safe1 = matName:gsub("[^%w]", "") .. "Count"
	local safe2 = matName:gsub("[^%w]", "")
	local safe3 = matName .. "Count"
	local safe4 = matName

	local targetAttr = safe1
	if plr:GetAttribute(safe2) then targetAttr = safe2
	elseif plr:GetAttribute(safe3) then targetAttr = safe3
	elseif plr:GetAttribute(safe4) then targetAttr = safe4 end

	local current = tonumber(plr:GetAttribute(targetAttr)) or 0
	plr:SetAttribute(targetAttr, math.max(0, current - amt))
end

Network:WaitForChild("ForgeItem").OnServerEvent:Connect(function(player, recipeName, quality)
	if recipeName == "RepairWeapon" then
		local eqWpn = player:GetAttribute("EquippedWeapon")
		if not eqWpn or eqWpn == "None" then return end

		local currentDurability = tonumber(player:GetAttribute("WeaponDurability")) or 100
		local maxDurability = 100

		if currentDurability >= maxDurability then
			NotificationEvent:FireClient(player, "Weapon is already pristine.", "Error")
			return
		end

		local repairAmount = maxDurability - currentDurability
		local cost = math.floor(repairAmount * 150)
		local dews = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Dews")

		if dews and dews.Value >= cost then
			dews.Value -= cost
			player:SetAttribute("WeaponDurability", maxDurability)
			NotificationEvent:FireClient(player, "Weapon successfully resharpened!", "Success")
		else
			NotificationEvent:FireClient(player, "Not enough Dews to repair!", "Error")
		end
		return
	end

	local recipe = ItemData.ForgeRecipes[recipeName]
	if not recipe then return end

	local dews = player.leaderstats.Dews.Value
	if dews < recipe.DewCost then NotificationEvent:FireClient(player, "Not enough Dews to forge this!", "Error"); return end

	local canForge = true
	for reqItemName, reqAmt in pairs(recipe.ReqItems) do
		local current = GetItemCount(player, reqItemName)
		if current < reqAmt then canForge = false; break end
	end

	local clansToConsume = {}
	if recipe.SpecialType == "AbyssalClanRequirement" then
		local abyssalClans = {
			"ItemizedAbyssalYeagerCount", "ItemizedAbyssalTyburCount", "ItemizedAbyssalAckermanCount", 
			"ItemizedAbyssalGalliardCount", "ItemizedAbyssalBraunCount", "ItemizedAbyssalReissCount"
		}
		local foundCount = 0

		for _, mClanAttr in ipairs(abyssalClans) do
			local count = player:GetAttribute(mClanAttr) or 0
			if count > 0 then
				for i = 1, count do
					table.insert(clansToConsume, mClanAttr)
					foundCount += 1
					if foundCount >= recipe.AbyssalClanCount then break end
				end
			end
			if foundCount >= recipe.AbyssalClanCount then break end
		end

		if foundCount < recipe.AbyssalClanCount then canForge = false end
	end

	if not canForge then NotificationEvent:FireClient(player, "Missing required materials or Itemized Abyssal lineages!", "Error"); return end

	player.leaderstats.Dews.Value -= recipe.DewCost

	for reqItemName, reqAmt in pairs(recipe.ReqItems) do
		DeductItem(player, reqItemName, reqAmt)

		local newCount = GetItemCount(player, reqItemName)
		if newCount <= 0 then
			if player:GetAttribute("EquippedWeapon") == reqItemName then
				player:SetAttribute("EquippedWeapon", "None")
				player:SetAttribute("FightingStyle", "None")
			elseif player:GetAttribute("EquippedAccessory") == reqItemName then
				player:SetAttribute("EquippedAccessory", "None")
			end
		end
	end

	if #clansToConsume > 0 then
		for _, attr in ipairs(clansToConsume) do
			player:SetAttribute(attr, (player:GetAttribute(attr) or 1) - 1)
		end
	end

	local resSafeName = recipe.Result:gsub("[^%w]", "")
	player:SetAttribute(resSafeName .. "Count", (player:GetAttribute(resSafeName .. "Count") or 0) + 1)

	local resData = ItemData.Equipment[recipe.Result] or ItemData.Consumables[recipe.Result]

	if resData and (resData.Type == "Weapon" or resData.Type == "Accessory") then
		if quality == "Masterwork" or quality == "Flawless" then
			local possibleStats = { "DMG", "DODGE", "CRIT", "MAX HP", "SPEED", "GAS CAP", "IGNORE ARMOR" }
			local stat1 = possibleStats[math.random(1, #possibleStats)]
			local stat2 = possibleStats[math.random(1, #possibleStats)]

			local mult = (quality == "Flawless") and 2 or 1
			local v1 = math.random(5, 15) * mult
			local v2 = math.random(5, 15) * mult

			local statStr = "+" .. v1 .. (stat1 == "MAX HP" and "" or "%") .. " " .. stat1 .. " | +" .. v2 .. (stat2 == "MAX HP" and "" or "%") .. " " .. stat2
			player:SetAttribute(resSafeName .. "_Awakened", statStr)
			player:SetAttribute(resSafeName .. "_AwakenLevel", 1)

			-- Store raw stats for combat calculation
			player:SetAttribute(resSafeName .. "_AwakenedStat1_Type", stat1)
			player:SetAttribute(resSafeName .. "_AwakenedStat1_Value", v1)
			player:SetAttribute(resSafeName .. "_AwakenedStat2_Type", stat2)
			player:SetAttribute(resSafeName .. "_AwakenedStat2_Value", v2)
		end
	end

	if quality == "Flawless" then
		NotificationEvent:FireAllClients(player.Name .. " forged a FLAWLESS " .. recipe.Result .. "!", "Loot")
	elseif resData and resData.Rarity == "Transcendent" then 
		NotificationEvent:FireAllClients(player.Name .. " has forged the " .. recipe.Result .. "!", "Success")
	end
end)

local RefineGear = Network:FindFirstChild("RefineGear") or Instance.new("RemoteEvent", Network)
RefineGear.Name = "RefineGear"

-- Set the maximum refinement level here
local MAX_AWAKEN_LEVEL = 100 

RefineGear.OnServerEvent:Connect(function(player, weaponName)
	local iData = ItemData.Equipment[weaponName]
	if not iData or string.find(weaponName, "Abyssal") or iData.Rarity == "Transcendent" then return end

	local safeWpn = weaponName:gsub("[^%w]", "")
	if GetItemCount(player, weaponName) <= 0 then return end

	local currentLevel = player:GetAttribute(safeWpn .. "_AwakenLevel") or 0

	-- NEW: Cap verification check
	if currentLevel >= MAX_AWAKEN_LEVEL then
		NotificationEvent:FireClient(player, weaponName .. " has reached its absolute limits!", "Error")
		return
	end

	local dewsNeeded = 10000 + (currentLevel * 5000)
	local extractsNeeded = 1 + currentLevel

	local dews = player.leaderstats.Dews.Value
	local extracts = GetItemCount(player, "Titan Hardening Extract")

	if dews >= dewsNeeded and extracts >= extractsNeeded then
		player.leaderstats.Dews.Value -= dewsNeeded
		DeductItem(player, "Titan Hardening Extract", extractsNeeded)

		local newLevel = currentLevel + 1
		player:SetAttribute(safeWpn .. "_AwakenLevel", newLevel)

		local possibleStats = { "DMG", "DODGE", "CRIT", "MAX HP", "SPEED", "GAS CAP", "IGNORE ARMOR" }
		local stat1, stat2 = possibleStats[math.random(1, #possibleStats)], possibleStats[math.random(1, #possibleStats)]

		local v1 = math.random(5, 25) + (newLevel * 5)
		local v2 = math.random(5, 25) + (newLevel * 5)

		local statStr = "+" .. v1 .. (stat1 == "MAX HP" and "" or "%") .. " " .. stat1 .. " | +" .. v2 .. (stat2 == "MAX HP" and "" or "%") .. " " .. stat2
		player:SetAttribute(safeWpn .. "_Awakened", statStr)

		-- Store raw stats for combat calculation
		player:SetAttribute(safeWpn .. "_AwakenedStat1_Type", stat1)
		player:SetAttribute(safeWpn .. "_AwakenedStat1_Value", v1)
		player:SetAttribute(safeWpn .. "_AwakenedStat2_Type", stat2)
		player:SetAttribute(safeWpn .. "_AwakenedStat2_Value", v2)

		NotificationEvent:FireClient(player, weaponName .. " awakened to Level " .. newLevel .. "!", "Success")
	else
		NotificationEvent:FireClient(player, "Not enough Dews or Titan Hardening Extracts!", "Error")
	end
end)

MutateTitan.OnServerInvoke = function(player)
	local dews = player.leaderstats.Dews.Value
	local abyssalBlood = GetItemCount(player, "Abyssal Blood")

	if dews >= 25000 and abyssalBlood >= 1 then
		local currentTitan = player:GetAttribute("Titan") or "None"
		if currentTitan == "None" then
			return false, "You must inherit a Titan first to awaken a variant!"
		end

		player.leaderstats.Dews.Value -= 25000
		DeductItem(player, "Abyssal Blood", 1)

		local variants = {"Titan Hardening", "Crimson Steam", "Abyssal Eyes", "Beast Fur", "Crystalline Nape"}
		local chosen = variants[math.random(1, #variants)]

		player:SetAttribute("TitanVariant", chosen)
		return true, chosen
	else
		return false, "Not enough Dews or Abyssal Blood to awaken a variant!"
	end
end

Network:WaitForChild("AwakenAction").OnServerEvent:Connect(function(player, actionType)
	if actionType == "Clan" then
		local count = GetItemCount(player, "Ancestral Awakening Serum")
		local currentClan = player:GetAttribute("Clan") or "None"
		local validClans = {["Ackerman"] = true, ["Yeager"] = true, ["Tybur"] = true, ["Braun"] = true, ["Galliard"] = true, ["Reiss"] = true}
		if count >= 1 and validClans[currentClan] then
			DeductItem(player, "Ancestral Awakening Serum", 1)
			player:SetAttribute("Clan", "Awakened " .. currentClan)
			NotificationEvent:FireAllClients(player.Name .. " has Awakened their " .. currentClan .. " bloodline!", "Success")
		elseif count >= 1 then NotificationEvent:FireClient(player, "Your bloodline is too weak to awaken.", "Error") end
	elseif actionType == "Titan" then
		local count = GetItemCount(player, "Ymir's Clay Fragment")
		if count >= 1 and player:GetAttribute("Titan") == "Attack Titan" then
			DeductItem(player, "Ymir's Clay Fragment", 1)
			player:SetAttribute("Titan", "Founding Attack Titan")
			NotificationEvent:FireAllClients(player.Name .. " has reached the Coordinate!", "Success")
		end
	end
end)

local FuseTitan = Network:FindFirstChild("FuseTitan") or Instance.new("RemoteEvent", Network)
FuseTitan.Name = "FuseTitan"
FuseTitan.OnServerEvent:Connect(function(player, baseSlot, sacSlot)
	if not baseSlot or not sacSlot or baseSlot == sacSlot then return end
	local validSlots = {["Equipped"] = true, ["1"] = true, ["2"] = true, ["3"] = true, ["4"] = true, ["5"] = true, ["6"] = true}
	if not validSlots[tostring(baseSlot)] or not validSlots[tostring(sacSlot)] then return end

	local dews = player.leaderstats.Dews.Value
	if dews >= 15000 then
		local baseAttr = (baseSlot == "Equipped") and "Titan" or ("Titan_Slot" .. baseSlot)
		local sacAttr = (sacSlot == "Equipped") and "Titan" or ("Titan_Slot" .. sacSlot)

		local baseTitan = player:GetAttribute(baseAttr) or "None"
		local sacTitan = player:GetAttribute(sacAttr) or "None"
		local result = FusionRecipes[baseTitan] and FusionRecipes[baseTitan][sacTitan]

		if result then
			player.leaderstats.Dews.Value -= 15000
			player:SetAttribute(baseAttr, result)
			player:SetAttribute(sacAttr, "None")

			FusionComplete:FireClient(player, result)
			NotificationEvent:FireAllClients(player.Name .. " has hybridized the " .. result .. "!", "Success")
		else
			NotificationEvent:FireClient(player, "Invalid Fusion combination.", "Error")
		end
	else
		NotificationEvent:FireClient(player, "Not enough Dews to fuse! Requires 15,000.", "Error")
	end
end)