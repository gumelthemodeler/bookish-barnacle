-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local GameData = {}

GameData.TitanRanks = { ["E"] = 5, ["D"] = 10, ["C"] = 15, ["B"] = 20, ["A"] = 25, ["S"] = 30, ["None"] = 0 }

-- [[ Raised starting defaults to 10 so players start with 100 HP and 100 Gas ]]
GameData.BaseStats = { Health = 10, Gas = 10, Strength = 10, Defense = 10, Speed = 10, Resolve = 10 }

GameData.TitanStats = { "Titan_Power_Val", "Titan_Speed_Val", "Titan_Hardening_Val", "Titan_Endurance_Val", "Titan_Precision_Val", "Titan_Potential_Val" }

GameData.WeaponBonuses = {
	["Unarmed"] = { Stamina = 15, Speed = 5 },
	["Ultrahard Steel Blades"] = { Strength = 25, Speed = 15 },
	["Thunder Spears"] = { Strength = 60, Defense = -15 },
	["Anti-Personnel Firearms"] = { Precision = 40, Speed = 20 },
	["Titan Martial Arts"] = { Health = 35, Strength = 30 },
	["Marleyan Rifle"] = { Precision = 25, Willpower = 10 },
	["Heavy Artillery"] = { Strength = 75, Speed = -25 },
}

GameData.StatDescriptions = {
	Health = "Increases your Maximum HP. Essential for surviving Titan attacks.",
	Strength = "Increases the base damage of your blades and physical strikes.",
	Defense = "Reduces the amount of damage you take from all incoming attacks.",
	Speed = "Determines turn order and increases your chance to dodge incoming grabs.",
	Stamina = "Required to use ODM gear and perform physical skills. Regenerates slowly.",
	Willpower = "Increases critical hit chance and reduces cooldowns on heavy abilities.",
	Titan_Power = "Increases the overall damage dealt while transformed into a Titan.",
	Titan_Speed = "Boosts your overall combat speed and dodge chance when transformed.",
	Titan_Hardening = "Provides a protective barrier and massive damage reduction.",
	Titan_Endurance = "Increases the maximum health pool of your Titan form.",
	Titan_Precision = "Vastly increases your critical hit chance to strike enemy napes.",
	Titan_Potential = "Increases your Maximum Titan Energy, allowing for more frequent abilities."
}

GameData.BattleConditions = {
	["Clear Weather"] = { Description = "Conditions are standard. No advantages or disadvantages.", Color = "#FFFFFF" },
	["Night Operation"] = { Description = "Pure Titans lack sunlight and become sluggish. Enemies suffer -25% Speed.", Color = "#00008B" },
	["Rainstorm"] = { Description = "Visibility is poor and ODM grips slip. Player suffers -15% Speed and -15% Precision.", Color = "#5555FF" },
	["Forest of Giant Trees"] = { Description = "Perfect terrain for ODM Gear. Player gains +30% Speed and +15% Strength.", Color = "#228B22" },
	["Open Plains"] = { Description = "Nowhere to grapple. Player suffers -25% Speed and -10% Defense.", Color = "#DAA520" },
	["The Rumbling"] = { Description = "Absolute chaos. Everyone (Player and Enemies) deals +50% damage.", Color = "#FF0000" }
}

-- [[ THE MERGED PRESTIGE WEB ]]
GameData.PrestigeNodes = {
	-- CORE (Start at bottom center)
	["Core_1"] = { Name = "Awakened Potential", Cost = 1, Req = nil, BuffType = "FlatStat", BuffStat = "Health", BuffValue = 50, Desc = "Increases Base Health by 50.", Pos = UDim2.new(0.5, 0, 0.85, 0), Color = "#FFFFFF" },

	-- COMMANDER PATH (Goes straight up)
	["Cmdr_1"] = { Name = "Iron Resolve", Cost = 1, Req = "Core_1", BuffType = "FlatStat", BuffStat = "Resolve", BuffValue = 15, Desc = "Increases Base Resolve by 15.", Pos = UDim2.new(0.5, 0, 0.65, 0), Color = "#FFD700" },
	["Cmdr_2"] = { Name = "Unflinching", Cost = 2, Req = "Cmdr_1", BuffType = "FlatStat", BuffStat = "Defense", BuffValue = 20, Desc = "Increases Base Defense by 20.", Pos = UDim2.new(0.5, 0, 0.45, 0), Color = "#FFD700" },
	["Cmdr_3"] = { Name = "Vanguard Leader", Cost = 2, Req = "Cmdr_2", BuffType = "FlatStat", BuffStat = "Strength", BuffValue = 20, Desc = "Increases Base Strength by 20.", Pos = UDim2.new(0.5, 0, 0.25, 0), Color = "#FFD700" },
	["Cmdr_4"] = { Name = "Shinzo wo Sasageyo!", Cost = 3, Req = "Cmdr_3", BuffType = "Special", BuffStat = "Survivals", BuffValue = 1, Desc = "Survive lethal blows at 1 HP one additional time.", Pos = UDim2.new(0.5, 0, 0.05, 0), Color = "#FFD700" },

	-- SCOUT PATH (Branches to the Left)
	["Scout_1"] = { Name = "ODM Mastery", Cost = 1, Req = "Core_1", BuffType = "FlatStat", BuffStat = "Speed", BuffValue = 15, Desc = "Increases Base Speed by 15.", Pos = UDim2.new(0.35, 0, 0.75, 0), Color = "#55AAFF" },
	["Scout_2"] = { Name = "Acrobatic Evasion", Cost = 2, Req = "Scout_1", BuffType = "Special", BuffStat = "DodgeBonus", BuffValue = 5, Desc = "Increases Base Dodge Chance by 5%.", Pos = UDim2.new(0.2, 0, 0.65, 0), Color = "#55AAFF" },
	["Scout_3"] = { Name = "Lethal Momentum", Cost = 2, Req = "Scout_2", BuffType = "Special", BuffStat = "DmgMult", BuffValue = 0.10, Desc = "Multiplies all Weapon Damage by +10%.", Pos = UDim2.new(0.1, 0, 0.45, 0), Color = "#55AAFF" },
	["Scout_4"] = { Name = "Ackerman Reflexes", Cost = 3, Req = "Scout_3", BuffType = "Special", BuffStat = "CritBonus", BuffValue = 10, Desc = "Increases Critical Hit Chance by 10%.", Pos = UDim2.new(0.2, 0, 0.25, 0), Color = "#FF5555" },

	-- SCOUT SUB-BRANCH (Gas & Resolve)
	["Scout_Sub1"] = { Name = "Extended Cylinders", Cost = 1, Req = "Scout_1", BuffType = "FlatStat", BuffStat = "Gas", BuffValue = 30, Desc = "Increases Base Gas Capacity by 30.", Pos = UDim2.new(0.25, 0, 0.85, 0), Color = "#55FFFF" },
	["Scout_Sub2"] = { Name = "Unshaken", Cost = 2, Req = "Scout_2", BuffType = "FlatStat", BuffStat = "Resolve", BuffValue = 20, Desc = "Increases Base Resolve by 20.", Pos = UDim2.new(0.3, 0, 0.55, 0), Color = "#55FFFF" },

	-- TITAN PATH (Branches to the Right)
	["Titan_1"] = { Name = "Shifter Endurance", Cost = 1, Req = "Core_1", BuffType = "FlatStat", BuffStat = "Titan_Endurance_Val", BuffValue = 15, Desc = "Increases Base Titan Endurance by 15.", Pos = UDim2.new(0.65, 0, 0.75, 0), Color = "#AA55FF" },
	["Titan_2"] = { Name = "Hardened Carapace", Cost = 2, Req = "Titan_1", BuffType = "FlatStat", BuffStat = "Titan_Hardening_Val", BuffValue = 20, Desc = "Increases Base Titan Hardening by 20.", Pos = UDim2.new(0.8, 0, 0.65, 0), Color = "#AA55FF" },
	["Titan_3"] = { Name = "Primordial Roar", Cost = 2, Req = "Titan_2", BuffType = "FlatStat", BuffStat = "Titan_Power_Val", BuffValue = 25, Desc = "Increases Base Titan Power by 25.", Pos = UDim2.new(0.9, 0, 0.45, 0), Color = "#AA55FF" },
	["Titan_4"] = { Name = "Coordinate Resonance", Cost = 3, Req = "Titan_3", BuffType = "Special", BuffStat = "IgnoreArmor", BuffValue = 0.20, Desc = "All attacks ignore 20% of the enemy's Armor.", Pos = UDim2.new(0.8, 0, 0.25, 0), Color = "#AA55FF" },

	-- TITAN SUB-BRANCH (Energy & Precision)
	["Titan_Sub1"] = { Name = "Boiling Blood", Cost = 1, Req = "Titan_1", BuffType = "FlatStat", BuffStat = "Titan_Potential_Val", BuffValue = 20, Desc = "Increases Max Titan Energy by 20.", Pos = UDim2.new(0.75, 0, 0.85, 0), Color = "#FF55FF" },
	["Titan_Sub2"] = { Name = "Nape Targeting", Cost = 2, Req = "Titan_2", BuffType = "FlatStat", BuffStat = "Titan_Precision_Val", BuffValue = 15, Desc = "Increases Base Titan Precision by 15.", Pos = UDim2.new(0.7, 0, 0.55, 0), Color = "#FF55FF" },

	-- NEW EXTENSION: ECONOMY BRANCH (Far Left)
	["DewGain1"] = { Name = "Flesh Harvesting I", Cost = 1, Req = "Core_1", BuffType = "Special", BuffStat = "DewBonus", BuffValue = 0.05, Desc = "+5% Dew Gain", Pos = UDim2.new(0.15, 0, 0.95, 0), Color = "#55FF55" },
	["DewGain2"] = { Name = "Flesh Harvesting II", Cost = 1, Req = "DewGain1", BuffType = "Special", BuffStat = "DewBonus", BuffValue = 0.10, Desc = "+10% Dew Gain", Pos = UDim2.new(0.05, 0, 0.85, 0), Color = "#55FF55" },
	["DewGain3"] = { Name = "Flesh Harvesting III", Cost = 2, Req = "DewGain2", BuffType = "Special", BuffStat = "DewBonus", BuffValue = 0.15, Desc = "+15% Dew Gain", Pos = UDim2.new(0.05, 0, 0.70, 0), Color = "#55FF55" },
	["MaterialYield"] = { Name = "Scavenger's Eye", Cost = 2, Req = "DewGain2", BuffType = "Special", BuffStat = "MaterialYield", BuffValue = 0.05, Desc = "+5% Chance for double material drops.", Pos = UDim2.new(0.05, 0, 0.55, 0), Color = "#55AAFF" },

	-- NEW EXTENSION: TITAN COMBAT BRANCH (Far Right)
	["TitanPunchBleed"] = { Name = "Jagged Knuckles", Cost = 1, Req = "Core_1", BuffType = "Special", BuffStat = "TitanPunchBleed", BuffValue = 1, Desc = "Titan Punch permanently applies Bleed.", Pos = UDim2.new(0.85, 0, 0.95, 0), Color = "#FF5555" },
	["ArmorPiercingKick"] = { Name = "Shattering Impact", Cost = 1, Req = "TitanPunchBleed", BuffType = "Special", BuffStat = "IgnoreArmor", BuffValue = 0.10, Desc = "Titan Kick ignores 10% of enemy armor.", Pos = UDim2.new(0.95, 0, 0.85, 0), Color = "#FF5555" },
	["TitanPunchCrush"] = { Name = "Heavy Hands", Cost = 2, Req = "ArmorPiercingKick", BuffType = "Special", BuffStat = "TitanDmg", BuffValue = 0.15, Desc = "Titan Punch deals +15% base damage.", Pos = UDim2.new(0.95, 0, 0.70, 0), Color = "#FF3333" },
	["TitanKickShockwave"] = { Name = "Tremor Kick", Cost = 3, Req = "TitanPunchCrush", BuffType = "Special", BuffStat = "TitanKickAoE", BuffValue = 1, Desc = "Titan Kick gains a small AoE shockwave.", Pos = UDim2.new(0.95, 0, 0.55, 0), Color = "#FF3333" },

	-- NEW EXTENSION: ODM / HUMAN BRANCH
	["GasEfficiency1"] = { Name = "Pressurized Canisters I", Cost = 1, Req = "Scout_Sub1", BuffType = "Special", BuffStat = "GasEfficiency", BuffValue = 0.05, Desc = "-5% Gas consumption on Maneuver.", Pos = UDim2.new(0.15, 0, 0.75, 0), Color = "#AAAAAA" },
	["GasEfficiency2"] = { Name = "Pressurized Canisters II", Cost = 1, Req = "GasEfficiency1", BuffType = "Special", BuffStat = "GasEfficiency", BuffValue = 0.10, Desc = "-10% Gas consumption on all ODM moves.", Pos = UDim2.new(0.15, 0, 0.60, 0), Color = "#AAAAAA" },
	["BladeDurability"] = { Name = "Tempered Steel", Cost = 2, Req = "GasEfficiency2", BuffType = "Special", BuffStat = "BladeDmg", BuffValue = 0.10, Desc = "Ultrahard Steel Blades deal +10% flat damage.", Pos = UDim2.new(0.15, 0, 0.45, 0), Color = "#AAAAAA" },
	["ODMSpeed"] = { Name = "Wind Rider", Cost = 2, Req = "GasEfficiency2", BuffType = "Special", BuffStat = "ODMSpeed", BuffValue = 1, Desc = "Increases 'Close In' rush speed.", Pos = UDim2.new(0.25, 0, 0.45, 0), Color = "#55AAFF" },

	-- NEW EXTENSION: TITAN SHIFTER UTILITY BRANCH
	["HeatManagement1"] = { Name = "Venting Pores I", Cost = 1, Req = "Titan_Sub1", BuffType = "Special", BuffStat = "HeatReduction", BuffValue = 0.05, Desc = "Generate 5% less heat per Titan action.", Pos = UDim2.new(0.85, 0, 0.75, 0), Color = "#FF88FF" },
	["HeatManagement2"] = { Name = "Venting Pores II", Cost = 1, Req = "HeatManagement1", BuffType = "Special", BuffStat = "HeatReduction", BuffValue = 0.10, Desc = "Generate 10% less heat per Titan action.", Pos = UDim2.new(0.85, 0, 0.60, 0), Color = "#FF88FF" },
	["RapidTransform"] = { Name = "Flash Shift", Cost = 2, Req = "HeatManagement2", BuffType = "Special", BuffStat = "TransformCD", BuffValue = 2, Desc = "Reduces 'Transform' cooldown by 2 seconds.", Pos = UDim2.new(0.85, 0, 0.45, 0), Color = "#CC44FF" },
	["NapeHardening"] = { Name = "Subconscious Guard", Cost = 2, Req = "HeatManagement2", BuffType = "Special", BuffStat = "NapeDefense", BuffValue = 0.10, Desc = "Permanently reduces incoming Nape damage by 10%.", Pos = UDim2.new(0.75, 0, 0.45, 0), Color = "#FFD700" },

	-- NEW EXTENSION: THE CROSSROADS (Mid-Late Game Convergence)
	["FleshAndSteel"] = { Name = "Hybrid Warrior", Cost = 3, Req = "Titan_4", BuffType = "Special", BuffStat = "HybridDmg", BuffValue = 0.15, Desc = "Gain +15% damage for 2 turns after using Eject.", Pos = UDim2.new(0.70, 0, 0.15, 0), Color = "#FF3333" },
	["RelentlessAssault"] = { Name = "Relentless", Cost = 3, Req = "Scout_4", BuffType = "Special", BuffStat = "HumanHeatRegen", BuffValue = 1, Desc = "Using 'Recover' as a human slightly restores Titan Heat.", Pos = UDim2.new(0.30, 0, 0.15, 0), Color = "#CC44FF" },
	["ScavengerKing"] = { Name = "Scavenger King", Cost = 3, Req = "DewGain3", BuffType = "Special", BuffStat = "DewBonus", BuffValue = 0.25, Desc = "+25% total Dew Gain multiplier.", Pos = UDim2.new(0.15, 0, 0.15, 0), Color = "#55FF55" },
	["WindGod"] = { Name = "Wind God", Cost = 3, Req = "ODMSpeed", BuffType = "Special", BuffStat = "DodgeBonus", BuffValue = 10, Desc = "+10% Base Dodge Chance.", Pos = UDim2.new(0.25, 0, 0.25, 0), Color = "#55AAFF" },

	-- NEW EXTENSION: THE PINNACLE
	["PathConvergence"] = { Name = "The Founding's Call", Cost = 5, Req = "Cmdr_4", BuffType = "Special", BuffStat = "TruePrestige", BuffValue = 1, Desc = "Caps the tree. Unlocks the True Prestige.", Pos = UDim2.new(0.5, 0, -0.15, 0), Color = "#FF55FF" }
}

function GameData.GetStatCap(prestige) return 100 + ((prestige or 0) * 10) end

function GameData.CalculateStatCost(currentStat, baseStat, prestige)
	local baseCost = 10
	local prestigeMultiplier = math.max(0.1, 1 - ((prestige or 0) * 0.05))
	local statDifference = math.max(0, currentStat - baseStat)
	local cost = baseCost + (statDifference * 25) + math.floor(statDifference ^ 1.8)
	return math.floor(cost * prestigeMultiplier)
end

function GameData.GetMaxInventory(player)
	if not player then return 15 end
	local totalCapacity = 15 + (player:GetAttribute("ClanInvBoost") or 0)
	local ls = player:FindFirstChild("leaderstats")
	local elo = ls and ls:FindFirstChild("Elo") and ls.Elo.Value or 1000
	if elo >= 4000 then totalCapacity = totalCapacity + 5 end
	if player:GetAttribute("HasBackpackExpansion") then totalCapacity = totalCapacity + 50 end
	if player:GetAttribute("Has2xInventory") then totalCapacity = totalCapacity * 2 end
	return totalCapacity
end

function GameData.GetInventoryCount(player)
	if not player then return 0 end
	local count = 0
	local ItemData = require(game:GetService("ReplicatedStorage"):WaitForChild("ItemData"))
	local ignoredKeys = {}
	for itemName, data in pairs(ItemData.Consumables) do ignoredKeys[itemName:gsub("[^%w]", "") .. "Count"] = true end
	for itemName, data in pairs(ItemData.Equipment) do if data.Rarity == "Unique" then ignoredKeys[itemName:gsub("[^%w]", "") .. "Count"] = true end end

	local attrs = player:GetAttributes()
	for key, val in pairs(attrs) do
		if type(val) == "number" and val > 0 and string.sub(key, -5) == "Count" then
			if not ignoredKeys[key] then count += val end
		end
	end
	return count
end

return GameData