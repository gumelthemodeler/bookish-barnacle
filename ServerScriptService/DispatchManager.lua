-- @ScriptType: Script
-- @ScriptType: Script
-- Name: DispatchManager
local DispatchManager = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Network = ReplicatedStorage:WaitForChild("Network")
local NotificationEvent = Network:WaitForChild("NotificationEvent")

-- Heavily squashed yields to fit the 15k economy reset
local ALLIES = {
	["Armin Arlert"] = { Cost = 1000, BaseYield = 2 },
	["Sasha Braus"] = { Cost = 2500, BaseYield = 3 },
	["Connie Springer"] = { Cost = 2500, BaseYield = 3 },
	["Jean Kirstein"] = { Cost = 5000, BaseYield = 4 },
	["Hange Zoe"] = { Cost = 10000, BaseYield = 6 },
	["Erwin Smith"] = { Cost = 20000, BaseYield = 8 },
	["Mikasa Ackerman"] = { Cost = 50000, BaseYield = 12 },
	["Levi Ackerman"] = { Cost = 100000, BaseYield = 20 }
}

local HORSE_RARITIES = {
	{Name = "Old Mare", Rarity = "Common", Weight = 50, BaseEff = 0.05},
	{Name = "Sturdy Stallion", Rarity = "Uncommon", Weight = 30, BaseEff = 0.10},
	{Name = "Garrison Steed", Rarity = "Rare", Weight = 12, BaseEff = 0.20},
	{Name = "Scout's Thoroughbred", Rarity = "Epic", Weight = 6, BaseEff = 0.35},
	{Name = "Commander's Warhorse", Rarity = "Legendary", Weight = 1.5, BaseEff = 0.60},
	{Name = "Phantom Destrier", Rarity = "Mythical", Weight = 0.5, BaseEff = 1.0}
}

local function DecodeJSON(attr)
	if not attr or attr == "" then return {} end
	local success, res = pcall(function() return HttpService:JSONDecode(attr) end)
	return success and res or {}
end

local function EncodeJSON(data)
	return HttpService:JSONEncode(data)
end

local function CalculateGlobalHorseEfficiency(player)
	local hData = DecodeJSON(player:GetAttribute("HorseData"))
	local totalBoost = 0
	for _, h in ipairs(hData) do
		totalBoost += (h.Efficiency + (h.Level * 0.02))
	end
	-- Hard cap to prevent infinite economy scaling
	return math.min(2.0, totalBoost) 
end

Network:WaitForChild("DispatchAction").OnServerEvent:Connect(function(player, action, payload)
	local dData = DecodeJSON(player:GetAttribute("DispatchData"))
	local unlocked = player:GetAttribute("UnlockedAllies") or ""
	local aLevels = DecodeJSON(player:GetAttribute("AllyLevels"))
	local maxCap = player:GetAttribute("MaxDeployments") or 2
	local dews = player.leaderstats and player.leaderstats:FindFirstChild("Dews")

	if action == "UnlockAlly" then
		if not ALLIES[payload] or string.find(unlocked, "%[" .. payload .. "%]") then return end
		if dews and dews.Value >= ALLIES[payload].Cost then
			dews.Value -= ALLIES[payload].Cost
			player:SetAttribute("UnlockedAllies", unlocked .. "[" .. payload .. "]")
			NotificationEvent:FireClient(player, "Recruited " .. payload .. "!", "Success")
		else
			NotificationEvent:FireClient(player, "Not enough Dews to recruit " .. payload .. ".", "Error")
		end

	elseif action == "UpgradeAlly" then
		if not ALLIES[payload] or not string.find(unlocked, "%[" .. payload .. "%]") then return end
		local curLvl = aLevels[payload] or 1
		if curLvl >= 10 then NotificationEvent:FireClient(player, "Ally is already Max Level.", "Error"); return end

		local cost = curLvl * 5000
		if dews and dews.Value >= cost then
			dews.Value -= cost
			aLevels[payload] = curLvl + 1
			player:SetAttribute("AllyLevels", EncodeJSON(aLevels))
			NotificationEvent:FireClient(player, "Upgraded " .. payload .. " to Level " .. (curLvl + 1) .. "!", "Success")
		else
			NotificationEvent:FireClient(player, "Not enough Dews to upgrade.", "Error")
		end

	elseif action == "Deploy" then
		if not ALLIES[payload] or not string.find(unlocked, "%[" .. payload .. "%]") then return end
		if dData[payload] then return end

		local currentDeploys = 0
		for _, _ in pairs(dData) do currentDeploys += 1 end
		if currentDeploys >= maxCap then
			NotificationEvent:FireClient(player, "Maximum deployment capacity reached.", "Error")
			return
		end

		dData[payload] = { StartTime = os.time() }
		player:SetAttribute("DispatchData", EncodeJSON(dData))

	elseif action == "Recall" then
		if not dData[payload] then return end

		local elapsed = os.time() - dData[payload].StartTime
		if elapsed >= 43200 then elapsed = 43200 end -- Cap at 12 hours

		local mins = math.floor(elapsed / 60)

		if mins < 1 then
			dData[payload] = nil
			player:SetAttribute("DispatchData", EncodeJSON(dData))
			NotificationEvent:FireClient(player, payload .. " was recalled early. No rewards gathered.", "System")
			return
		end

		local lvl = aLevels[payload] or 1
		local baseYield = ALLIES[payload].BaseYield
		local horseBonus = CalculateGlobalHorseEfficiency(player)

		-- Final formula respects levels and stable buffs
		local gatheredDews = math.floor((mins * baseYield * (1 + (lvl * 0.1))) * (1 + horseBonus))

		-- HARD CAP: Limits the absolute maximum an ally can bring back to prevent economy destruction
		local maxAllowed = baseYield * 1000
		gatheredDews = math.min(gatheredDews, maxAllowed)

		dData[payload] = nil
		player:SetAttribute("DispatchData", EncodeJSON(dData))

		if dews then dews.Value += gatheredDews end
		NotificationEvent:FireClient(player, payload .. " returned! Gathered " .. FormatNumber(gatheredDews) .. " Dews.", "Loot")

	elseif action == "UpgradeCapacity" then
		local cost = maxCap * 25000
		if dews and dews.Value >= cost then
			dews.Value -= cost
			player:SetAttribute("MaxDeployments", maxCap + 1)
			NotificationEvent:FireClient(player, "Deployment Capacity increased!", "Success")
		else
			NotificationEvent:FireClient(player, "Not enough Dews. Need " .. FormatNumber(cost) .. ".", "Error")
		end

	elseif action == "RollHorse" then
		local hData = DecodeJSON(player:GetAttribute("HorseData"))
		if #hData >= 5 then
			NotificationEvent:FireClient(player, "Your stables are full! (Max 5)", "Error")
			return
		end

		if dews and dews.Value >= 25000 then
			dews.Value -= 25000

			local roll = math.random(1, 100)
			local cumulative = 0
			local chosenRarity = HORSE_RARITIES[1]

			for _, r in ipairs(HORSE_RARITIES) do
				cumulative += r.Weight
				if roll <= cumulative then
					chosenRarity = r
					break
				end
			end

			table.insert(hData, {
				Id = HttpService:GenerateGUID(false),
				Name = chosenRarity.Name,
				Rarity = chosenRarity.Rarity,
				Efficiency = chosenRarity.BaseEff,
				Level = 1
			})
			player:SetAttribute("HorseData", EncodeJSON(hData))

			if chosenRarity.Rarity == "Mythical" or chosenRarity.Rarity == "Legendary" then
				NotificationEvent:FireAllClients(player.Name .. " tamed a " .. string.upper(chosenRarity.Rarity) .. " " .. chosenRarity.Name .. "!", "Loot")
			else
				NotificationEvent:FireClient(player, "You acquired a " .. chosenRarity.Name .. "!", "Success")
			end
		else
			NotificationEvent:FireClient(player, "Not enough Dews to roll a horse.", "Error")
		end

	elseif action == "UpgradeHorse" then
		local hData = DecodeJSON(player:GetAttribute("HorseData"))
		local horseIndex = nil
		for i, h in ipairs(hData) do
			if h.Id == payload then horseIndex = i; break end
		end

		if horseIndex then
			local h = hData[horseIndex]
			if h.Level >= 10 then NotificationEvent:FireClient(player, "Horse is at max level.", "Error"); return end

			local cost = h.Level * 10000
			if dews and dews.Value >= cost then
				dews.Value -= cost
				h.Level += 1
				player:SetAttribute("HorseData", EncodeJSON(hData))
				NotificationEvent:FireClient(player, h.Name .. " leveled up to " .. h.Level .. "!", "Success")
			else
				NotificationEvent:FireClient(player, "Not enough Dews to upgrade horse. Need " .. FormatNumber(cost) .. " Dews.", "Error")
			end
		end

	elseif action == "SellHorse" then
		local hData = DecodeJSON(player:GetAttribute("HorseData"))
		local horseIndex = nil
		for i, h in ipairs(hData) do
			if h.Id == payload then horseIndex = i; break end
		end

		if horseIndex then
			table.remove(hData, horseIndex)
			player:SetAttribute("HorseData", EncodeJSON(hData))
			if dews then dews.Value += 5000 end
			NotificationEvent:FireClient(player, "Horse sold for 5,000 Dews.", "System")
		end
	end
end)

return DispatchManager