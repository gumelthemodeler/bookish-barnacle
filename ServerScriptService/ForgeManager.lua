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

local FusionRecipes = { 
	["Female Titan"] = { ["Founding Titan"] = "Founding Female Titan" }, 
	["Founding Titan"] = { ["Female Titan"] = "Founding Female Titan", ["Attack Titan"] = "Founding Attack Titan" }, 
	["Attack Titan"] = { ["Armored Titan"] = "Armored Attack Titan", ["War Hammer Titan"] = "War Hammer Attack Titan", ["Founding Titan"] = "Founding Attack Titan" }, 
	["Armored Titan"] = { ["Attack Titan"] = "Armored Attack Titan" }, 
	["War Hammer Titan"] = { ["Attack Titan"] = "War Hammer Attack Titan" }, 
	["Colossal Titan"] = { ["Jaw Titan"] = "Colossal Jaw Titan" }, 
	["Jaw Titan"] = { ["Colossal Titan"] = "Colossal Jaw Titan" } 
}

Network:WaitForChild("ForgeItem").OnServerEvent:Connect(function(player, recipeName, quality)
	local recipe = ItemData.ForgeRecipes[recipeName]
	if not recipe then return end

	local dews = player.leaderstats.Dews.Value
	if dews < recipe.DewCost then NotificationEvent:FireClient(player, "Not enough Dews to forge this!", "Error"); return end

	local canForge = true
	for reqItemName, reqAmt in pairs(recipe.ReqItems) do
		local safeReq = reqItemName:gsub("[^%w]", "") .. "Count"
		if (player:GetAttribute(safeReq) or 0) < reqAmt then canForge = false; break end
	end

	-- [[ THE FIX: Updated to burn Itemized Abyssal Variants instead of Vaulted Slots ]]
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
		local safeReq = reqItemName:gsub("[^%w]", "") .. "Count"
		local newCount = (player:GetAttribute(safeReq) or 0) - reqAmt
		player:SetAttribute(safeReq, newCount)

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

	local resSafeName = recipe.Result:gsub("[^%w]", "") .. "Count"
	player:SetAttribute(resSafeName, (player:GetAttribute(resSafeName) or 0) + 1)

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
			player:SetAttribute(recipe.Result:gsub("[^%w]", "") .. "_Awakened", statStr)
		end
	end

	if quality == "Flawless" then
		NotificationEvent:FireAllClients("<font color='#FFD700'><b>" .. player.Name .. " forged a FLAWLESS " .. recipe.Result .. "!</b></font>", "Loot")
	elseif resData and resData.Rarity == "Transcendent" then 
		NotificationEvent:FireAllClients("<font color='#FF55FF'><b>" .. player.Name .. " has forged the " .. recipe.Result .. "!</b></font>", "Success")
	else 
		NotificationEvent:FireClient(player, "Forged " .. recipe.Result .. " (" .. (quality or "Standard") .. ")!", "Success") 
	end
end)

Network:WaitForChild("AwakenWeapon").OnServerEvent:Connect(function(player, weaponName)
	local extracts = player:GetAttribute("TitanHardeningExtractCount") or 0
	if extracts >= 1 then
		local safeWpn = weaponName:gsub("[^%w]", "")
		if (player:GetAttribute(safeWpn .. "Count") or 0) > 0 then
			player:SetAttribute("TitanHardeningExtractCount", extracts - 1)
			local possibleStats = { "DMG", "DODGE", "CRIT", "MAX HP", "SPEED", "GAS CAP", "IGNORE ARMOR" }
			local stat1, stat2 = possibleStats[math.random(1, #possibleStats)], possibleStats[math.random(1, #possibleStats)]
			local statStr = "+" .. math.random(5, 25) .. (stat1 == "MAX HP" and "" or "%") .. " " .. stat1 .. " | +" .. math.random(5, 25) .. (stat2 == "MAX HP" and "" or "%") .. " " .. stat2
			player:SetAttribute(safeWpn .. "_Awakened", statStr)
			NotificationEvent:FireClient(player, weaponName .. " Awakened!", "Success")
		end
	end
end)

Network:WaitForChild("AwakenAction").OnServerEvent:Connect(function(player, actionType)
	if actionType == "Clan" then
		local count = player:GetAttribute("AncestralAwakeningSerumCount") or 0
		local currentClan = player:GetAttribute("Clan") or "None"
		local validClans = {["Ackerman"] = true, ["Yeager"] = true, ["Tybur"] = true, ["Braun"] = true, ["Galliard"] = true, ["Reiss"] = true}
		if count >= 1 and validClans[currentClan] then
			player:SetAttribute("AncestralAwakeningSerumCount", count - 1); player:SetAttribute("Clan", "Awakened " .. currentClan)
			NotificationEvent:FireClient(player, currentClan .. " Bloodline Awakened!", "Success")
		elseif count >= 1 then NotificationEvent:FireClient(player, "Your bloodline is too weak to awaken.", "Error") end
	elseif actionType == "Titan" then
		local count = player:GetAttribute("YmirsClayFragmentCount") or 0
		if count >= 1 and player:GetAttribute("Titan") == "Attack Titan" then
			player:SetAttribute("YmirsClayFragmentCount", count - 1); player:SetAttribute("Titan", "Founding Attack Titan")
			NotificationEvent:FireClient(player, "You have reached the Coordinate!", "Success")
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
	if dews >= 300000 then
		local baseAttr = (baseSlot == "Equipped") and "Titan" or ("Titan_Slot" .. baseSlot)
		local sacAttr = (sacSlot == "Equipped") and "Titan" or ("Titan_Slot" .. sacSlot)

		local baseTitan = player:GetAttribute(baseAttr) or "None"
		local sacTitan = player:GetAttribute(sacAttr) or "None"
		local result = FusionRecipes[baseTitan] and FusionRecipes[baseTitan][sacTitan]

		if result then
			player.leaderstats.Dews.Value -= 300000
			player:SetAttribute(baseAttr, result)
			player:SetAttribute(sacAttr, "None")

			FusionComplete:FireClient(player, result)
		else
			NotificationEvent:FireClient(player, "Invalid Fusion combination.", "Error")
		end
	else
		NotificationEvent:FireClient(player, "Not enough Dews to fuse! Requires 300,000.", "Error")
	end
end)

local ItemizeTitan = Network:FindFirstChild("ItemizeTitan") or Instance.new("RemoteEvent", Network)
ItemizeTitan.Name = "ItemizeTitan"
ItemizeTitan.OnServerEvent:Connect(function(player, slotId)
	if not slotId then return end
	local dews = player.leaderstats.Dews.Value
	if dews >= 100000 then
		local attrName = (slotId == "Equipped") and "Titan" or ("Titan_Slot" .. slotId)
		local titanName = player:GetAttribute(attrName) or "None"
		if titanName ~= "None" then
			player.leaderstats.Dews.Value -= 100000
			player:SetAttribute(attrName, "None")
			local safeItemName = ("Itemized " .. titanName):gsub("[^%w]", "") .. "Count"
			player:SetAttribute(safeItemName, (player:GetAttribute(safeItemName) or 0) + 1)
			NotificationEvent:FireClient(player, "Titan extracted to your inventory!", "Success")
		end
	else
		NotificationEvent:FireClient(player, "Not enough Dews to itemize!", "Error")
	end
end)

local ItemizeClan = Network:FindFirstChild("ItemizeClan") or Instance.new("RemoteEvent", Network)
ItemizeClan.Name = "ItemizeClan"
ItemizeClan.OnServerEvent:Connect(function(player, slotId)
	if not slotId then return end
	local dews = player.leaderstats.Dews.Value
	if dews >= 100000 then
		local attrName = (slotId == "Equipped") and "Clan" or ("Clan_Slot" .. slotId)
		local clanName = player:GetAttribute(attrName) or "None"
		if clanName ~= "None" then
			player.leaderstats.Dews.Value -= 100000
			player:SetAttribute(attrName, "None")

			local safeItemName = ("Itemized " .. clanName):gsub("[^%w]", "") .. "Count"
			player:SetAttribute(safeItemName, (player:GetAttribute(safeItemName) or 0) + 1)
			NotificationEvent:FireClient(player, "Clan bloodline extracted to your inventory!", "Success")
		end
	else
		NotificationEvent:FireClient(player, "Not enough Dews to itemize!", "Error")
	end
end)