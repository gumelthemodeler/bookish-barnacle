-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
-- Name: LootManager
local LootManager = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))
local Network = ReplicatedStorage:WaitForChild("Network")

local SellValues = { Common = 10, Uncommon = 25, Rare = 75, Epic = 200, Legendary = 500, Mythical = 1500, Transcendent = 0 }

local function GetUniqueSlotCount(plr)
	local count = 0
	-- Consumables no longer trigger the Inventory Full logic
	for iName, _ in pairs(ItemData.Equipment) do
		if (plr:GetAttribute(iName:gsub("[^%w]", "") .. "Count") or 0) > 0 then count += 1 end
	end
	return count
end

function LootManager.GiveOrAutoSellItem(player, itemName, amount)
	local iData = ItemData.Equipment[itemName] or ItemData.Consumables[itemName]
	if not iData then return end

	local rarity = iData.Rarity or "Common"
	local isAutoSellEnabled = player:GetAttribute("AutoSell_" .. rarity)
	local isProtected = (rarity == "Legendary" or rarity == "Mythical" or rarity == "Transcendent")
	local isEquipment = ItemData.Equipment[itemName] ~= nil

	-- Applies Double Drops consistently to manual grants to sync with UI notifications
	local dropMultiplier = player:GetAttribute("HasDoubleDrops") and 2 or 1
	local finalAmount = amount * dropMultiplier

	if isAutoSellEnabled and isEquipment and not isProtected then
		local sellValue = (SellValues[rarity] or 10) * finalAmount
		player.leaderstats.Dews.Value += sellValue
		local NotificationEvent = Network:FindFirstChild("NotificationEvent")
		if NotificationEvent then
			NotificationEvent:FireClient(player, "Auto-Sold " .. itemName .. " for " .. sellValue .. " Dews!", "Success")
		end
	else
		local safeName = itemName:gsub("[^%w]", "") .. "Count"
		local currentAmt = player:GetAttribute(safeName) or 0
		player:SetAttribute(safeName, currentAmt + finalAmount)
	end
end

function LootManager.ProcessDrops(player, enemyDrops, isEndless, currentWave)
	local droppedItems = {}
	local autoSoldDewsCapacity = 0
	local autoSoldDewsSettings = 0
	local currentSlots = GetUniqueSlotCount(player)

	local MAX_INVENTORY_CAPACITY = player:GetAttribute("HasBackpackExpansion") and 75 or 25
	local dropMultiplier = player:GetAttribute("HasDoubleDrops") and 2 or 1
	local isYmirFavored = player:GetAttribute("YmirFavored")
	local favoredMultiplier = isYmirFavored and 1.5 or 1.0 

	local luckBoost = 1.0
	local luckExpiry = player:GetAttribute("Buff_Luck_Expiry") or 0
	if os.time() <= luckExpiry then luckBoost = player:GetAttribute("LuckBoost") or 1.0 end

	if player:GetAttribute("Top5_Prestige") or player:GetAttribute("Top5_Elo") or player:GetAttribute("Top5_Squad") then
		luckBoost = luckBoost * 1.15
	end

	local squadUpgradesRaw = player:GetAttribute("SquadUpgrades")
	if squadUpgradesRaw and squadUpgradesRaw ~= "" then
		local succ, sqUp = pcall(function() return game:GetService("HttpService"):JSONDecode(squadUpgradesRaw) end)
		if succ and sqUp and sqUp.Luck and sqUp.Luck > 0 then
			luckBoost = luckBoost + (sqUp.Luck * 0.05)
		end
	end

	if enemyDrops and enemyDrops.ItemChance then
		for itemName, baseChance in pairs(enemyDrops.ItemChance) do
			local iData = ItemData.Equipment[itemName] or ItemData.Consumables[itemName]
			local rarity = iData and iData.Rarity or "Common"

			local finalChance = baseChance

			if isEndless then
				if rarity == "Mythical" then finalChance += (currentWave * 0.1)
				elseif rarity == "Legendary" then finalChance += (currentWave * 0.3)
				elseif rarity == "Epic" then finalChance += (currentWave * 1.0)
				else finalChance += (currentWave * 2.0) end
				finalChance = finalChance * 1.5
			end

			finalChance = finalChance * favoredMultiplier * luckBoost
			finalChance = math.clamp(finalChance, 0.01, 100)

			local roll = math.random() * 100
			if roll <= finalChance then
				local attrName = itemName:gsub("[^%w]", "") .. "Count"
				local currentAmt = player:GetAttribute(attrName) or 0

				local isAutoSellEnabled = player:GetAttribute("AutoSell_" .. rarity)
				local isEquipment = ItemData.Equipment[itemName] ~= nil

				local isProtected = (rarity == "Legendary" or rarity == "Mythical" or rarity == "Transcendent")

				if isAutoSellEnabled and isEquipment and not isProtected then
					autoSoldDewsSettings += (SellValues[rarity] or 10) * dropMultiplier
				elseif isEquipment and not isProtected and currentAmt == 0 and currentSlots >= MAX_INVENTORY_CAPACITY then
					autoSoldDewsCapacity += (SellValues[rarity] or 10) * dropMultiplier
				else
					local nameTag = (dropMultiplier > 1) and (itemName .. " (x" .. dropMultiplier .. ")") or itemName
					table.insert(droppedItems, nameTag)
					player:SetAttribute(attrName, currentAmt + dropMultiplier)
					if isEquipment and currentAmt == 0 then currentSlots += 1 end
				end
			end
		end
	end

	if autoSoldDewsSettings > 0 then
		player.leaderstats.Dews.Value += autoSoldDewsSettings
	end

	if autoSoldDewsCapacity > 0 then
		player.leaderstats.Dews.Value += autoSoldDewsCapacity
	end

	return droppedItems, autoSoldDewsCapacity
end

return LootManager