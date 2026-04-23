-- @ScriptType: ModuleScript

-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local TitanData = {}

-- [[ TITAN DEFINITIONS & RARITIES ]]
TitanData.Titans = {
	["Attack Titan"] = { 
		Name = "Attack Titan", Rarity = "Common",
		Stats = {Power="C", Speed="B", Hardening="D", Endurance="B", Precision="B", Potential="B"}
	},
	["Jaw Titan"] = { 
		Name = "Jaw Titan", Rarity = "Rare",
		Stats = {Power="B", Speed="S", Hardening="C", Endurance="D", Precision="A", Potential="C"}
	},
	["Cart Titan"] = { 
		Name = "Cart Titan", Rarity = "Rare",
		Stats = {Power="D", Speed="A", Hardening="D", Endurance="S", Precision="B", Potential="A"}
	},
	["Armored Titan"] = { 
		Name = "Armored Titan", Rarity = "Legendary",
		Stats = {Power="B", Speed="C", Hardening="S", Endurance="A", Precision="D", Potential="C"}
	},
	["Female Titan"] = { 
		Name = "Female Titan", Rarity = "Legendary",
		Stats = {Power="A", Speed="A", Hardening="A", Endurance="B", Precision="B", Potential="B"}
	},
	["War Hammer Titan"] = { 
		Name = "War Hammer Titan", Rarity = "Legendary",
		Stats = {Power="A", Speed="B", Hardening="S", Endurance="C", Precision="A", Potential="B"}
	},
	["Beast Titan"] = { 
		Name = "Beast Titan", Rarity = "Legendary",
		Stats = {Power="S", Speed="C", Hardening="B", Endurance="A", Precision="A", Potential="A"}
	},
	["Colossal Titan"] = { 
		Name = "Colossal Titan", Rarity = "Legendary",
		Stats = {Power="S", Speed="E", Hardening="C", Endurance="S", Precision="E", Potential="S"}
	},
	["Founding Titan"] = { 
		Name = "Founding Titan", Rarity = "Mythical",
		Stats = {Power="S", Speed="D", Hardening="S", Endurance="S", Precision="S", Potential="S"}
	},

	-- [[ TRANSCENDENT FUSIONS ]]
	["Founding Female Titan"] = { Name = "Founding Female Titan", Rarity = "Transcendent", Stats = {Power="S", Speed="S", Hardening="S", Endurance="S", Precision="S", Potential="S"} },
	["Armored Attack Titan"] = { Name = "Armored Attack Titan", Rarity = "Transcendent", Stats = {Power="S", Speed="A", Hardening="S", Endurance="S", Precision="A", Potential="S"} },
	["War Hammer Attack Titan"] = { Name = "War Hammer Attack Titan", Rarity = "Transcendent", Stats = {Power="S", Speed="S", Hardening="S", Endurance="S", Precision="A", Potential="S"} },
	["Colossal Jaw Titan"] = { Name = "Colossal Jaw Titan", Rarity = "Transcendent", Stats = {Power="S", Speed="S", Hardening="B", Endurance="A", Precision="A", Potential="S"} },

	-- [[ FIX: ADDED FOUNDING ATTACK TITAN ]]
	["Founding Attack Titan"] = { Name = "Founding Attack Titan", Rarity = "Transcendent", Stats = {Power="S", Speed="S", Hardening="S", Endurance="S", Precision="S", Potential="S"} }
}

-- [[ GACHA WEIGHTS ]]
TitanData.Rarities = {
	["Common"] = 81.5,
	["Rare"] = 15.0,
	["Legendary"] = 3.0,
	["Mythical"] = 0.5
}

TitanData.TraitWeights = {
	["None"] = 50.0,
	["Tough"] = 10.0,
	["Fierce"] = 10.0,
	["Focused"] = 8.0,
	["Swift"] = 5.0,
	["Evasive"] = 5.0,
	["Relentless"] = 3.0,
	["Bloodthirsty"] = 3.0, 
	["Concussive"] = 2.0, 
	["Crystalline"] = 2.0, 
	["Incendiary"] = 2.0, 
	["Perseverance"] = 1.0,
	["Awakened"] = 0.5, 
	["Transcendent"] = 0.1 
}

TitanData.ClanWeights = {
	["None"] = 40.0,
	["Braus"] = 15.0,
	["Springer"] = 15.0,
	["Galliard"] = 8.0,
	["Braun"] = 8.0,
	["Arlert"] = 5.0,
	["Tybur"] = 4.0,
	["Yeager"] = 3.0,
	["Reiss"] = 1.5,
	["Ackerman"] = 0.5
}

-- [[ ROLLING LOGIC ]]
local function RollFromWeights(weightTable)
	local totalWeight = 0
	for _, weight in pairs(weightTable) do
		totalWeight += weight
	end

	local randomRoll = math.random() * totalWeight
	local currentWeight = 0

	for item, weight in pairs(weightTable) do
		currentWeight += weight
		if randomRoll <= currentWeight then
			return item
		end
	end
end

function TitanData.RollTitan(legendaryPity, mythicalPity)
	local rarityRoll = RollFromWeights(TitanData.Rarities)

	-- Hard Pity: 250 rolls guarantees a Mythical
	if mythicalPity and mythicalPity >= 250 then
		rarityRoll = "Mythical"
		-- Soft Pity: 100 rolls guarantees a Legendary (unless they naturally rolled a Mythical)
	elseif legendaryPity and legendaryPity >= 100 then
		if rarityRoll ~= "Mythical" then
			rarityRoll = "Legendary"
		end
	end

	local possibleTitans = {}
	for name, data in pairs(TitanData.Titans) do
		if data.Rarity == rarityRoll then
			table.insert(possibleTitans, name)
		end
	end

	return possibleTitans[math.random(1, #possibleTitans)], rarityRoll
end

function TitanData.RollTrait()
	return RollFromWeights(TitanData.TraitWeights)
end

function TitanData.RollClan()
	return RollFromWeights(TitanData.ClanWeights)
end

return TitanData