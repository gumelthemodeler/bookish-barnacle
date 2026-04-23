-- @ScriptType: Script
-- @ScriptType: Script
-- Name: CombatManager
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EnemyData = require(ReplicatedStorage:WaitForChild("EnemyData"))
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))
local SkillData = require(ReplicatedStorage:WaitForChild("SkillData"))
local ClanData = require(ReplicatedStorage:WaitForChild("ClanData"))
local GameData = require(ReplicatedStorage:WaitForChild("GameData"))
local CombatCore = require(script.Parent:WaitForChild("CombatCore"))
local LootManager = require(script.Parent:WaitForChild("LootManager")) 
local LabyrinthManager = require(script.Parent:WaitForChild("LabyrinthManager"))

local Network = ReplicatedStorage:FindFirstChild("Network") or Instance.new("Folder", ReplicatedStorage)
Network.Name = "Network"

local labEvent = game:GetService("ServerStorage"):FindFirstChild("LabyrinthEncounter")
if not labEvent then
	labEvent = Instance.new("BindableEvent")
	labEvent.Name = "LabyrinthEncounter"
	labEvent.Parent = game:GetService("ServerStorage")
end

local function GetRemote(name)
	local r = Network:FindFirstChild(name)
	if not r then r = Instance.new("RemoteEvent"); r.Name = name; r.Parent = Network end
	return r
end

local CombatAction = GetRemote("CombatAction")
local CombatUpdate = GetRemote("CombatUpdate")
local PlayVFX = GetRemote("PlayVFX") 

local ActiveBattles = {}

local function UpdateBountyProgress(plr, taskType, amt)
	for i = 1, 3 do
		if plr:GetAttribute("D"..i.."_Task") == taskType and not plr:GetAttribute("D"..i.."_Claimed") then
			local p = plr:GetAttribute("D"..i.."_Prog") or 0
			local m = plr:GetAttribute("D"..i.."_Max") or 1
			plr:SetAttribute("D"..i.."_Prog", math.min(p + amt, m))
		end
	end
	if plr:GetAttribute("W1_Task") == taskType and not plr:GetAttribute("W1_Claimed") then
		local p = plr:GetAttribute("W1_Prog") or 0
		local m = plr:GetAttribute("W1_Max") or 1
		plr:SetAttribute("W1_Prog", math.min(p + amt, m))
	end
end

local function GetTemplate(partData, templateName)
	if partData.Templates and partData.Templates[templateName] then return partData.Templates[templateName] end
	for _, mob in ipairs(partData.Mobs) do if mob.Name == templateName then return mob end end
	return partData.Mobs[1] 
end

local function GetValidEndlessMob(partData)
	local valid = {}
	for _, mob in ipairs(partData.Mobs) do
		if not string.find(mob.Name, "Dummy") and not string.find(mob.Name, "Wall Titan") then
			table.insert(valid, mob)
		end
	end
	if #valid > 0 then return valid[math.random(1, #valid)] end
	return partData.Mobs[1]
end

local function GetHPScale(targetPart, isEndless, wave)
	local base = 1.0 + ((targetPart - 1) * 0.4) 
	if isEndless then base = base + ((wave or 1) * 0.15) end
	return base
end

local function GetDmgScale(targetPart, isEndless, wave)
	local base = 1.0 + ((targetPart - 1) * 0.25) 
	if isEndless then base = base + ((wave or 1) * 0.1) end
	return base
end

local function GetDefScale(targetPart, isEndless, wave)
	local base = 1.0 + ((targetPart - 1) * 0.15) 
	if isEndless then base = base + ((wave or 1) * 0.05) end
	return base
end

local function GetSpdScale(targetPart, isEndless, wave)
	local base = 1.0 + (math.pow(targetPart, 0.6) * 0.1) 
	if isEndless then base = base + (math.pow(wave or 1, 0.5) * 0.05) end
	return base
end

local function GetTitanSkills(titanName)
	if not titanName or titanName == "None" then return {} end
	local movesets = {
		["Attack Titan"] = {"Berserk Rush", "Future Memories"},
		["Jaw Titan"] = {"Frenzied Thrash", "Agile Leap", "Crushing Bite"},
		["Cart Titan"] = {"Titan Bite", "Endurance Run", "Panzer Artillery"},
		["Armored Titan"] = {"Hardened Punch", "Armored Tackle", "Shattering Charge"},
		["Female Titan"] = {"Crystal Kick", "Nape Guard", "Attraction Scream"}, 
		["War Hammer Titan"] = {"Hardened Punch", "Crossbow Construct", "War Hammer Spike"},
		["Beast Titan"] = {"Crushed Boulders", "Pitching Ace", "Titan Roar"},
		["Colossal Titan"] = {"Brutal Swipe", "Devastating Kick", "Colossal Steam"},
		["Founding Titan"] = {"Titan Roar", "Coordinate Command"}, 
		["Founding Female Titan"] = {"Crystal Kick", "Attraction Scream", "Nape Guard", "Coordinate Command"},
		["Armored Attack Titan"] = {"Berserk Rush", "Armored Tackle", "Shattering Charge"},
		["War Hammer Attack Titan"] = {"Berserk Rush", "Crossbow Construct", "War Hammer Spike"},
		["Colossal Jaw Titan"] = {"Crushing Bite", "Devastating Kick", "Colossal Steam"},
		["Founding Attack Titan"] = {"Berserk Rush", "Future Memories", "Coordinate Command"}
	}
	return movesets[titanName] or {}
end

local function GetActualStyle(plr)
	local eqWpn = plr:GetAttribute("EquippedWeapon") or "None"
	if ItemData.Equipment[eqWpn] and ItemData.Equipment[eqWpn].Style then return ItemData.Equipment[eqWpn].Style end
	return "None"
end

local function ParseAwakenedStats(statString)
	local stats = { DmgMult = 1.0, DodgeBonus = 0, CritBonus = 0, HpBonus = 0, SpdBonus = 0, GasBonus = 0, HealOnKill = 0, IgnoreArmor = 0 }
	if not statString or statString == "" then return stats end
	for stat in string.gmatch(statString, "[^|]+") do
		stat = stat:match("^%s*(.-)%s*$")
		if stat:find("DMG") then stats.DmgMult += tonumber(stat:match("%d+")) / 100
		elseif stat:find("DODGE") then stats.DodgeBonus += tonumber(stat:match("%d+"))
		elseif stat:find("CRIT") then stats.CritBonus += tonumber(stat:match("%d+"))
		elseif stat:find("MAX HP") then stats.HpBonus += tonumber(stat:match("%d+"))
		elseif stat:find("SPEED") then stats.SpdBonus += tonumber(stat:match("%d+"))
		elseif stat:find("GAS CAP") then stats.GasBonus += tonumber(stat:match("%d+"))
		elseif stat:find("IGNORE") then stats.IgnoreArmor += tonumber(stat:match("%d+")) / 100
		end
	end
	return stats
end

local function StartBattle(player, encounterType, requestedPartId)
	if ActiveBattles[player.UserId] then return end 

	if player:GetAttribute("InMenu") == true or player:GetAttribute("AFK") == true then return end

	player:SetAttribute("InCombat", true)

	local currentPart = player:GetAttribute("CurrentPart") or 1
	local eTemplate, logFlavor
	local isStory, isEndless, isPaths, isWorldBoss, isNightmare, isLabyrinth = false, false, false, false, false, false
	local activeMissionData = nil
	local totalWaves, startingWave = 1, 1
	local targetPart = currentPart
	local prestige = player:FindFirstChild("leaderstats") and player.leaderstats.Prestige.Value or 0

	local cTerrain = "City"
	local cWeather = "Clear"

	if encounterType == "EngageStory" then
		isStory = true
		targetPart = requestedPartId or currentPart
		if type(targetPart) == "number" and targetPart > currentPart then targetPart = currentPart end
		local partData = EnemyData.Parts[targetPart]
		if not partData then return end

		if partData.DefaultEnv then
			cTerrain = partData.DefaultEnv.Terrain or "City"
			cWeather = partData.DefaultEnv.Weather or "Clear"
		end

		if targetPart == currentPart then startingWave = player:GetAttribute("CurrentWave") or 1 else startingWave = 1 end
		local missionTable = (prestige > 0 and partData.PrestigeMissions) and partData.PrestigeMissions or partData.Missions
		activeMissionData = missionTable[1]
		totalWaves = #activeMissionData.Waves
		if startingWave > totalWaves then startingWave = totalWaves end

		local waveData = activeMissionData.Waves[startingWave]
		eTemplate = GetTemplate(partData, waveData.Template)

		local flavorText = waveData.Flavor
		if not flavorText or flavorText == "" then flavorText = "Prepare to engage " .. (eTemplate.Name or "the enemy") .. "!" end
		logFlavor = "<font color='#FFD700'>[Mission: " .. (activeMissionData.Name or "Unknown") .. "]</font>\n" .. flavorText

	elseif encounterType == "EngageDoomsday" then
		isWorldBoss = true
		eTemplate = EnemyData.WorldBosses["Doomsday Titan"]
		if not eTemplate then return end
		logFlavor = "<font color='#FF3333'>[GLOBAL BOUNTY: THE PRIMORDIAL THREAT]</font>\nYou drop directly into the Doomsday frontline!"
		targetPart = 1 

	elseif encounterType == "EngageWorldBoss" then
		isWorldBoss = true
		eTemplate = EnemyData.WorldBosses[requestedPartId]
		if not eTemplate then return end
		logFlavor = "<font color='#FFAA00'>[WORLD EVENT]</font>\n" .. eTemplate.Name .. " has appeared!"
		targetPart = 1 

	elseif encounterType == "EngageNightmare" then
		isNightmare = true
		eTemplate = EnemyData.NightmareHunts[requestedPartId]
		if not eTemplate then return end
		logFlavor = "<font color='#FF5555'>[NIGHTMARE HUNT]</font>\n" .. eTemplate.Name .. " approaches!"
		targetPart = 1 

	elseif encounterType == "EngageRaid" then
		eTemplate = EnemyData.RaidBosses[requestedPartId]
		if not eTemplate then return end
		logFlavor = "<font color='#FF5555'>[RAID BOSS]</font>\n" .. eTemplate.Name .. " blocks your path!"
		targetPart = 1

	elseif encounterType == "EngageEndless" then
		isEndless = true
		local maxPart = math.min(8, currentPart)
		targetPart = math.random(1, maxPart)
		local partData = EnemyData.Parts[targetPart]
		eTemplate = GetValidEndlessMob(partData)
		logFlavor = "<font color='#AA55FF'>[ENDLESS EXPEDITION]</font>\nYou have encountered a " .. eTemplate.Name .. "!"

		local terrains = {"City", "Forest", "Plains", "Caverns"}
		local weathers = {"Clear", "Rain", "Night"}
		cTerrain = terrains[math.random(1, #terrains)]
		cWeather = weathers[math.random(1, #weathers)]

	elseif encounterType == "EngagePaths" then
		isPaths = true
		local floor = player:GetAttribute("PathsFloor") or 1
		targetPart = 1 
		local maxMemoryIndex = math.min(#EnemyData.PathsMemories, math.max(1, math.ceil(floor / 3)))
		eTemplate = EnemyData.PathsMemories[math.random(1, maxMemoryIndex)]
		logFlavor = "<font color='#55FFFF'>[THE PATHS - MEMORY " .. floor .. "]</font>\nA manifestation of " .. eTemplate.Name .. " emerges from the sand..."
		cTerrain = "Plains"
		cWeather = "Night"

	elseif encounterType == "EngageLabyrinth" then
		isLabyrinth = true
		local targetFloor = requestedPartId or 1
		targetPart = math.min(8, math.ceil(targetFloor / 2))
		local partData = EnemyData.Parts[targetPart]
		eTemplate = GetValidEndlessMob(partData)
		logFlavor = "<font color='#FF5555'>[LABYRINTH FLOOR " .. targetFloor .. "]</font>\nA monstrous " .. eTemplate.Name .. " stalks the corridors!"
		cTerrain = "Caverns"
		cWeather = "Night"
	else
		targetPart = math.min(8, currentPart)
		local partData = EnemyData.Parts[targetPart]
		eTemplate = partData.Mobs[math.random(1, #partData.Mobs)]
		local flavors = partData.RandomFlavor or {"You encounter a %s!"}
		logFlavor = string.format(flavors[math.random(1, #flavors)], eTemplate.Name)
	end

	if not eTemplate.IsDialogue then
		local envFlavors = {
			["City"] = "The tight alleyways offer standard ODM mobility.",
			["Forest"] = "The giant trees provide perfect anchors. Maneuvering costs 50% less gas and boosts evasion.",
			["Plains"] = "The open terrain is a death trap. Maneuvers cost 50% more gas and evasion plummets.",
			["Caverns"] = "The glowing crystals amplify Titan Hardening defensive capabilities."
		}
		local weatherFlavors = {
			["Clear"] = "",
			["Rain"] = "Heavy rain obscures vision. Both sides lose Accuracy. Fire extinguishes faster.",
			["Night"] = "The lack of sunlight drastically reduces Pure Titan speed."
		}
		logFlavor = logFlavor .. "\n<font color='#AAAAAA'>[" .. string.upper(cTerrain) .. "] " .. envFlavors[cTerrain] .. "</font>"
		if cWeather ~= "Clear" then
			logFlavor = logFlavor .. "\n<font color='#5588FF'>[" .. string.upper(cWeather) .. "] " .. weatherFlavors[cWeather] .. "</font>"
		end
	end

	local wpnName = player:GetAttribute("EquippedWeapon") or "None"
	local accName = player:GetAttribute("EquippedAccessory") or "None"
	local wpnBonus = (ItemData.Equipment[wpnName] and ItemData.Equipment[wpnName].Bonus) or {}
	local accBonus = (ItemData.Equipment[accName] and ItemData.Equipment[accName].Bonus) or {}

	local safeWpnName = wpnName:gsub("[^%w]", "")
	local combinedAwakenedString = (player:GetAttribute(safeWpnName .. "_Awakened") or "") .. " | " .. (player:GetAttribute("PathsAwakened") or "")
	local awakenedStats = ParseAwakenedStats(combinedAwakenedString)

	local clanName = player:GetAttribute("Clan") or "None"
	local isAwakenedClan = string.find(tostring(clanName or ""), "Awakened") ~= nil or string.find(tostring(clanName or ""), "Abyssal") ~= nil
	local cStats = ClanData.GetClanStats(clanName, isAwakenedClan, player:GetAttribute("Titan"), false)

	local baseHpStat = math.max(10, tonumber(player:GetAttribute("Health")) or 10)
	local baseGasStat = math.max(10, tonumber(player:GetAttribute("Gas")) or 10)
	local baseStrStat = math.max(10, tonumber(player:GetAttribute("Strength")) or 10)
	local baseDefStat = math.max(10, tonumber(player:GetAttribute("Defense")) or 10)
	local baseSpdStat = math.max(10, tonumber(player:GetAttribute("Speed")) or 10)
	local baseResStat = math.max(10, tonumber(player:GetAttribute("Resolve")) or 10)

	local pMaxHP = ((baseHpStat) + (wpnBonus.Health or 0) + (accBonus.Health or 0)) * 10
	pMaxHP = math.floor((pMaxHP + awakenedStats.HpBonus) * cStats.HpMult)
	local pMaxGas = (((baseGasStat) + (wpnBonus.Gas or 0) + (accBonus.Gas or 0)) * 10) + awakenedStats.GasBonus
	pMaxGas = math.max(100, pMaxGas)

	local pTotalStr = (baseStrStat) + (wpnBonus.Strength or 0) + (accBonus.Strength or 0)
	local pTotalDef = (baseDefStat) + (wpnBonus.Defense or 0) + (accBonus.Defense or 0)
	local pTotalSpd = (baseSpdStat) + (wpnBonus.Speed or 0) + (accBonus.Speed or 0) + awakenedStats.SpdBonus
	local pTotalRes = (baseResStat) + (wpnBonus.Resolve or 0) + (accBonus.Resolve or 0)

	local titanRuneLvl = tonumber(player:GetAttribute("Rune_Titan")) or 0
	local pMaxTitanEnergy = 100 + (titanRuneLvl * 25)

	local hpMult = GetHPScale(targetPart, isEndless, startingWave)
	local dmgMult = GetDmgScale(targetPart, isEndless, startingWave)
	local defMult = GetDefScale(targetPart, isEndless, startingWave)
	local spdMult = GetSpdScale(targetPart, isEndless, startingWave)
	local dropMult = 1.0 + (targetPart * 0.1) + (prestige * 0.25)

	if isEndless then dropMult *= 1.5 end

	if isPaths then
		local floor = player:GetAttribute("PathsFloor") or 1
		local pathScale = math.pow(1.10, floor - 1) 
		hpMult = hpMult * (0.60 * pathScale) 
		dmgMult = dmgMult * (1.10 * pathScale)
		defMult = GetDefScale(1, false, 1) * (1.05 * pathScale)
		dropMult = 1.0 + (prestige * 0.25) + (floor * 0.1)
	end

	if isLabyrinth then
		local floor = requestedPartId or 1
		local playerPowerRating = (pTotalStr * 2.5) + (pMaxHP / 12) + (pTotalDef * 1.5)
		local difficultyCurve = 1.0 + (floor * 0.15) 

		local targetHP = math.max(100, math.floor((playerPowerRating * 12) * difficultyCurve))
		local targetStr = math.max(10, math.floor((playerPowerRating * 0.35) * difficultyCurve))
		local targetDef = math.max(10, math.floor((playerPowerRating * 0.25) * difficultyCurve))
		local targetSpd = math.max(10, math.floor((pTotalSpd * 0.9) * (1.0 + (floor * 0.05))))

		hpMult = targetHP / (eTemplate.Health or 100)
		dmgMult = targetStr / (eTemplate.Strength or 10)
		defMult = targetDef / (eTemplate.Defense or 10)
		spdMult = targetSpd / (eTemplate.Speed or 10)

		dropMult = 1.0 + (prestige * 0.25) + (floor * 0.20)
	end

	if eTemplate.IsDialogue then
		ActiveBattles[player.UserId] = {
			IsProcessing = false,
			Context = { IsStoryMission = isStory, TargetPart = targetPart, CurrentWave = startingWave, TotalWaves = totalWaves, MissionData = activeMissionData, TurnCount = 0, Range = "Close" },
			Player = { IsPlayer = true, Name = player.Name, PlayerObj = player, Titan = player:GetAttribute("Titan") or "None", Style = GetActualStyle(player), Clan = clanName, HP = pMaxHP, MaxHP = pMaxHP, TitanEnergy = pMaxTitanEnergy, MaxTitanEnergy = pMaxTitanEnergy, Gas = pMaxGas, MaxGas = pMaxGas, TotalStrength = pTotalStr, TotalDefense = pTotalDef, TotalSpeed = pTotalSpd, TotalResolve = pTotalRes, Statuses = {}, Cooldowns = {}, LastSkill = "None", AwakenedStats = awakenedStats },
			Enemy = { IsMinigame = false, IsDialogue = true, Name = "Story", Dialogues = eTemplate.Dialogues, Choices = eTemplate.Choices, Rewards = eTemplate.Rewards, HP = 1, MaxHP = 1, GateType = nil, GateHP = 0, MaxGateHP = 0, TotalStrength = 0, TotalDefense = 0, TotalSpeed = 0, Statuses = {}, Cooldowns = {}, Skills = {}, Drops = { XP = 0, Dews = 0, ItemChance = {} }, LastSkill = "None" }
		}
		CombatUpdate:FireClient(player, "Dialogue", { Dialogues = eTemplate.Dialogues, Choices = eTemplate.Choices, Battle = ActiveBattles[player.UserId] })
		return
	end

	local ctxRange = "Close"
	if eTemplate.Name:find("Beast Titan") or eTemplate.IsLongRange then ctxRange = "Long"; logFlavor = logFlavor .. "\n<font color='#FF5555'>" .. eTemplate.Name .. " is at LONG RANGE.</font>" end

	local eHP = math.floor((eTemplate.Health or 100) * hpMult)
	local eGateType = eTemplate.GateType
	local eGateHP = math.floor((eTemplate.GateHP or 0) * (eGateType == "Steam" and 1 or hpMult))
	local eStr = math.floor((eTemplate.Strength or 10) * dmgMult)
	local eDef = math.floor((eTemplate.Defense or 10) * defMult)
	local eSpd = math.floor((eTemplate.Speed or 10) * spdMult)
	local enemyAwakenedStats = nil

	local isDynamicBoss = (encounterType == "EngageWorldBoss" or encounterType == "EngageNightmare" or encounterType == "EngageRaid" or encounterType == "EngageDoomsday")
	if isDynamicBoss then
		local groupMult = 1
		if encounterType == "EngageWorldBoss" or encounterType == "EngageDoomsday" then 
			groupMult = math.clamp(#Players:GetPlayers(), 1, 15)
		elseif encounterType == "EngageRaid" then
			local getPartyFunc = Network:FindFirstChild("GetPlayerParty")
			if getPartyFunc then
				local partyData = getPartyFunc:Invoke(player)
				if partyData and partyData.Members then groupMult = #partyData.Members end
			end
		end

		local baseDifficulty = 1.0
		local expectedTurnsToKill = 20
		local expectedHitsToDie = 8 

		if encounterType == "EngageWorldBoss" then 
			baseDifficulty = 6.0; expectedTurnsToKill = 35; expectedHitsToDie = 3 
		elseif encounterType == "EngageNightmare" then 
			baseDifficulty = 3.5; expectedTurnsToKill = 20; expectedHitsToDie = 4
		elseif encounterType == "EngageRaid" then 
			baseDifficulty = 2.0; expectedTurnsToKill = 25; expectedHitsToDie = 5 
		elseif encounterType == "EngageDoomsday" then
			baseDifficulty = 15.0; expectedTurnsToKill = 9999; expectedHitsToDie = 3
		end

		local statCap = 100 + (prestige * 10)
		if type(GameData) == "table" and type(GameData.GetStatCap) == "function" then statCap = GameData.GetStatCap(prestige) end
		local expectedBaseStr = statCap + 50 
		local expectedBaseHP = (statCap * 10) + 200

		local totalPartyDps = expectedBaseStr * groupMult * 4
		eHP = math.floor(totalPartyDps * expectedTurnsToKill * baseDifficulty)
		eStr = math.floor((expectedBaseHP / expectedHitsToDie) / 2 * baseDifficulty) 
		eDef = math.floor(expectedBaseStr * 0.8 * math.pow(baseDifficulty, 0.5)) 
		eSpd = math.floor(pTotalSpd * 1.1) 

		if encounterType == "EngageDoomsday" then eHP = 500000000 end

		if eGateType == "Steam" then eGateHP = eTemplate.GateHP 
		elseif eGateType then
			local gateRatio = (eTemplate.GateHP or 0) / (eTemplate.Health or 100)
			if gateRatio == 0 then gateRatio = 0.2 end
			eGateHP = math.floor(eHP * gateRatio)
		end

		logFlavor = logFlavor .. "\n<font color='#AAAAAA'>[Dynamic Encounter: Attuned to Group Size " .. groupMult .. "x]</font>"
	end

	if isPaths or isLabyrinth then
		local mutators = {"Armored", "Frenzied", "Elusive", "Colossal"}
		local selectedMutator = mutators[math.random(1, #mutators)]
		if selectedMutator == "Armored" then
			eGateType = "Reinforced Skin"; eGateHP = math.floor(eHP * 0.3)
			logFlavor = logFlavor .. "\n<font color='#AAAAAA'>[MUTATOR: ARMORED] Target has extreme hardening!</font>"
		elseif selectedMutator == "Frenzied" then
			eSpd = eSpd * 1.5; eStr = eStr * 1.2
			logFlavor = logFlavor .. "\n<font color='#FF5555'>[MUTATOR: FRENZIED] Target is moving at terrifying speeds!</font>"
		elseif selectedMutator == "Elusive" then
			enemyAwakenedStats = { DodgeBonus = 15 }
			logFlavor = logFlavor .. "\n<font color='#55FF55'>[MUTATOR: ELUSIVE] Target is incredibly hard to hit!</font>"
		elseif selectedMutator == "Colossal" then
			eHP = eHP * 1.5; eStr = eStr * 1.5; eSpd = math.floor(eSpd * 0.5)
			logFlavor = logFlavor .. "\n<font color='#FFAA00'>[MUTATOR: COLOSSAL] Target is massive and deals lethal damage!</font>"
		end
	end

	local eSkills = eTemplate.Skills or {"Brutal Swipe"}
	local initCooldowns = {}
	for _, s in ipairs(eSkills) do
		local sd = SkillData.Skills[s]
		if sd and sd.Telegraphed then initCooldowns[s] = math.random(2, 4) end
	end

	ActiveBattles[player.UserId] = {
		IsProcessing = false,
		Context = { IsStoryMission = isStory, IsEndless = isEndless, IsPaths = isPaths, IsWorldBoss = isWorldBoss, IsNightmare = isNightmare, IsLabyrinth = isLabyrinth, TargetPart = targetPart, CurrentWave = startingWave, TotalWaves = totalWaves, MissionData = activeMissionData, TurnCount = 0, Range = ctxRange, Terrain = cTerrain, Weather = cWeather },
		Player = { 
			IsPlayer = true, Name = player.Name, PlayerObj = player, Titan = player:GetAttribute("Titan") or "None", 
			Style = GetActualStyle(player), Clan = clanName, 
			HP = pMaxHP, MaxHP = pMaxHP, TitanEnergy = pMaxTitanEnergy, MaxTitanEnergy = pMaxTitanEnergy, Gas = pMaxGas, MaxGas = pMaxGas, 
			TotalStrength = pTotalStr, TotalDefense = pTotalDef, TotalSpeed = pTotalSpd, TotalResolve = pTotalRes, 
			BaseStrength = baseStrStat, BaseDefense = baseDefStat, BaseSpeed = baseSpdStat, BaseResolve = baseResStat,
			MomentumStacks = 0,
			Statuses = {}, Cooldowns = {}, LastSkill = "None", AwakenedStats = awakenedStats 
		},
		Enemy = { IsMinigame = eTemplate.IsMinigame, IsPlayer = false, Name = eTemplate.Name, IsHuman = isPaths and false or (eTemplate.IsHuman or false), IsNightmare = isNightmare, IsBoss = eTemplate.IsBoss or false, IsDoomsdayBoss = (encounterType == "EngageDoomsday"), HP = eHP, MaxHP = eHP, GateType = eGateType, GateHP = eGateHP, MaxGateHP = eGateHP, TotalStrength = eStr, TotalDefense = eDef, TotalSpeed = eSpd, Statuses = {}, Cooldowns = initCooldowns, Skills = eSkills, Drops = { XP = math.floor((eTemplate.Drops and eTemplate.Drops.XP or 15) * dropMult), Dews = math.floor((eTemplate.Drops and eTemplate.Drops.Dews or 10) * dropMult), ItemChance = eTemplate.Drops and eTemplate.Drops.ItemChance or {} }, AwakenedStats = enemyAwakenedStats, LastSkill = "None", AIPoints = 0 }
	}

	if eTemplate.IsMinigame then CombatUpdate:FireClient(player, "StartMinigame", { Battle = ActiveBattles[player.UserId], LogMsg = logFlavor, MinigameType = eTemplate.IsMinigame })
	else CombatUpdate:FireClient(player, "Start", { Battle = ActiveBattles[player.UserId], LogMsg = logFlavor }) end

	if encounterType == "EngageDoomsday" then
		task.spawn(function()
			local success, DoomsdayManager = pcall(function() return require(game:GetService("ServerScriptService"):WaitForChild("DoomsdayManager")) end)
			if not success or type(DoomsdayManager.GetServerData) ~= "function" then return end

			while ActiveBattles[player.UserId] and ActiveBattles[player.UserId].Enemy.IsDoomsdayBoss do
				local ddData = DoomsdayManager.GetServerData()

				if not ddData.IsActive or ddData.BossHP <= 0 then
					local b = ActiveBattles[player.UserId]
					if ddData.BossHP <= 0 then
						CombatUpdate:FireClient(player, "Victory", {Battle = b, LogMsg = "<font color='#55FF55'>The Doomsday Titan has fallen globally!</font>", XP = 50000, Dews = 500000, Items = {}})
					else
						CombatUpdate:FireClient(player, "Fled", {Battle = b, LogMsg = "<font color='#AAAAAA'>The Doomsday Titan vanished into the steam...</font>"})
					end
					ActiveBattles[player.UserId] = nil
					player:SetAttribute("InCombat", false)
					break
				end

				ActiveBattles[player.UserId].Enemy.HP = ddData.BossHP
				ActiveBattles[player.UserId].Enemy.MaxHP = ddData.MaxHP or 500000000
				task.wait(2) 
			end
		end)
	end
end

local function ProcessEnemyDeath(player, battle, dialogueRewards)
	if not player or not player:FindFirstChild("leaderstats") then return end
	local turnDelay = player:GetAttribute("HasDoubleSpeed") and 0.35 or 0.7
	local wasDialogue = battle.Enemy.IsDialogue

	if battle.Context.StoredBoss then
		local b = battle.Context.StoredBoss
		battle.Enemy.Name = b.Name; battle.Enemy.HP = b.HP; battle.Enemy.MaxHP = b.MaxHP
		battle.Enemy.GateType = b.GateType; battle.Enemy.GateHP = b.GateHP; battle.Enemy.MaxGateHP = b.MaxGateHP
		battle.Enemy.TotalStrength = b.TotalStrength; battle.Enemy.TotalDefense = b.TotalDefense; battle.Enemy.TotalSpeed = b.TotalSpeed
		battle.Enemy.Drops = b.Drops; battle.Enemy.Skills = b.Skills; battle.Enemy.Statuses = b.Statuses; battle.Enemy.Cooldowns = b.Cooldowns; battle.Enemy.LastSkill = b.LastSkill

		battle.Context.StoredBoss = nil; battle.Context.TurnCount = 0 
		CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = "<font color='#55FF55'>The Summoned Titan falls! The Founder is exposed!</font>", DidHit = false, ShakeType = "Heavy"})
		PlayVFX:FireClient(player, "TitanRoar", "Enemy")
		task.wait(turnDelay)
		battle.IsProcessing = false
		CombatUpdate:FireClient(player, "Update", {Battle = battle})
		return
	end

	if battle.Enemy.IsBoss and not battle.Context.ExecutionTriggered then
		battle.Context.ExecutionTriggered = true
		CombatUpdate:FireClient(player, "ExecutionPhase", {Battle = battle})
		battle.IsProcessing = false
		return
	end

	UpdateBountyProgress(player, "Kill", 1); UpdateBountyProgress(player, "Clear", 1)

	if battle.Enemy.IsNightmare then
		if battle.Enemy.Name == "Frenzied Beast Titan" then
			player:SetAttribute("Ach_Defeat_Frenzied", true)
		elseif battle.Enemy.Name == "Abyssal Armored Titan" then
			player:SetAttribute("Ach_Defeat_Abyssal", true)
		end
	end

	local sqName = player:GetAttribute("SquadName")
	if sqName and sqName ~= "None" then
		local squadEvent = Network:FindFirstChild("AddSquadSP")
		if squadEvent then
			local spAward = battle.Enemy.IsBoss and 5 or 1 

			local getPartyFunc = Network:FindFirstChild("GetPlayerParty")
			if getPartyFunc then
				pcall(function()
					local partyData = getPartyFunc:Invoke(player)
					if partyData and partyData.Members then
						local squadmatesPresent = 0
						for _, mem in ipairs(partyData.Members) do
							if mem.UserId ~= player.UserId then
								local memPlayer = Players:GetPlayerByUserId(mem.UserId)
								if memPlayer and memPlayer:GetAttribute("SquadName") == sqName then
									squadmatesPresent += 1
								end
							end
						end

						if squadmatesPresent > 0 then
							spAward = spAward + (squadmatesPresent * (battle.Enemy.IsBoss and 5 or 2))
						end
					end
				end)
			end

			squadEvent:Fire(sqName, spAward, player.UserId)
		end
	end

	local xpGain = (battle.Enemy.Drops and battle.Enemy.Drops.XP or 0) + (dialogueRewards and dialogueRewards.XP or 0)
	local dewsGain = (battle.Enemy.Drops and battle.Enemy.Drops.Dews or 0) + (dialogueRewards and dialogueRewards.Dews or 0)

	if player:GetAttribute("HasDoubleXP") then xpGain *= 2; dewsGain *= 2 end

	local winReg = Network:FindFirstChild("WinningRegiment")
	if winReg and winReg.Value ~= "None" and player:GetAttribute("Regiment") == winReg.Value then
		xpGain = math.floor(xpGain * 1.15)
		dewsGain = math.floor(dewsGain * 1.15)
	end

	local squadUpgradesRaw = player:GetAttribute("SquadUpgrades")
	if squadUpgradesRaw and squadUpgradesRaw ~= "" then
		local succ, sqUp = pcall(function() return game:GetService("HttpService"):JSONDecode(squadUpgradesRaw) end)
		if succ and sqUp then
			if sqUp.Training and sqUp.Training > 0 then xpGain = math.floor(xpGain * (1.0 + (sqUp.Training * 0.05))) end
			if sqUp.Wealth and sqUp.Wealth > 0 then dewsGain = math.floor(dewsGain * (1.0 + (sqUp.Wealth * 0.05))) end
		end
	end

	player:SetAttribute("XP", (player:GetAttribute("XP") or 0) + xpGain)
	player:SetAttribute("TitanXP", (player:GetAttribute("TitanXP") or 0) + xpGain)
	player.leaderstats.Dews.Value += dewsGain

	local killMsg = ""
	local droppedItems, autoSoldDews = LootManager.ProcessDrops(player, battle.Enemy.Drops or {}, battle.Context.IsEndless, battle.Context.CurrentWave)

	if dialogueRewards and dialogueRewards.ItemName then
		local amountGiven = dialogueRewards.Amount or 1
		LootManager.GiveOrAutoSellItem(player, dialogueRewards.ItemName, amountGiven)
		table.insert(droppedItems, {Name = dialogueRewards.ItemName, Amount = amountGiven})
	end

	if autoSoldDews > 0 then killMsg = killMsg .. "<br/><font color='#FFD700'>[Inventory Full: Auto-sold new drops for " .. autoSoldDews .. " Dews]</font>" end

	if battle.Player.AwakenedStats and battle.Player.AwakenedStats.HealOnKill > 0 then
		local pMax = tonumber(battle.Player.MaxHP) or 100
		local pCur = tonumber(battle.Player.HP) or 100
		local healAmt = math.floor(pMax * battle.Player.AwakenedStats.HealOnKill)
		battle.Player.HP = math.min(pMax, pCur + healAmt)
		killMsg = killMsg .. "<br/><font color='#55FF55'>[Awakened: Healed " .. healAmt .. " HP!]</font>"
		PlayVFX:FireClient(player, "Heal", "Self")
	end

	if battle.Context.IsPaths then
		local floor = player:GetAttribute("PathsFloor") or 1
		local dustGain = math.floor(1 + (floor * 0.2)) 
		player:SetAttribute("PathDust", (player:GetAttribute("PathDust") or 0) + dustGain)
		player:SetAttribute("PathsFloor", floor + 1)

		local rewardStr = "<font color='#55FFFF'>Memory Cleared! +" .. dustGain .. " Path Dust</font>"
		local prestige = player.leaderstats.Prestige.Value

		local maxMemoryIndex = math.min(#EnemyData.PathsMemories, math.max(1, math.ceil((floor + 1) / 3)))
		local nextEnemyTemplate = EnemyData.PathsMemories[math.random(1, maxMemoryIndex)]

		local pathScale = math.pow(1.10, floor)
		local hpMult = GetHPScale(1, false, 1) * (0.60 * pathScale)
		local dmgMult = GetDmgScale(1, false, 1) * (1.10 * pathScale)
		local defMult = GetDefScale(1, false, 1) * (1.05 * pathScale)
		local spdMult = GetSpdScale(1, false, 1)
		local dropMult = 1.0 + (prestige * 0.25) + ((floor + 1) * 0.1)

		local eHP = math.floor(nextEnemyTemplate.Health * hpMult)
		local eGateType = nextEnemyTemplate.GateType
		local eGateHP = math.floor((nextEnemyTemplate.GateHP or 0) * (eGateType == "Steam" and 1 or hpMult))
		local eStr = math.floor(nextEnemyTemplate.Strength * dmgMult)
		local eDef = math.floor(nextEnemyTemplate.Defense * defMult)
		local eSpd = math.floor(nextEnemyTemplate.Speed * spdMult)

		local enemyAwakenedStats = nil
		local mutators = {"Armored", "Frenzied", "Elusive", "Colossal"}
		local selectedMutator = mutators[math.random(1, #mutators)]
		local flavorText = "<font color='#55FFFF'>[THE PATHS - MEMORY " .. (floor + 1) .. "]</font>\nA manifestation of " .. nextEnemyTemplate.Name .. " emerges from the sand..."

		if selectedMutator == "Armored" then
			eGateType = "Reinforced Skin"; eGateHP = math.floor(eHP * 0.3)
			flavorText = flavorText .. "\n<font color='#AAAAAA'>[MUTATOR: ARMORED] Target has extreme hardening!</font>"
		elseif selectedMutator == "Frenzied" then
			eSpd = eSpd * 1.5; eStr = eStr * 1.2
			flavorText = flavorText .. "\n<font color='#FF5555'>[MUTATOR: FRENZIED] Target is moving at terrifying speeds!</font>"
		elseif selectedMutator == "Elusive" then
			enemyAwakenedStats = { DodgeBonus = 15 }
			flavorText = flavorText .. "\n<font color='#55FF55'>[MUTATOR: ELUSIVE] Target is incredibly hard to hit!</font>"
		elseif selectedMutator == "Colossal" then
			eHP = eHP * 1.5; eStr = eStr * 1.5; eSpd = math.floor(eSpd * 0.5)
			flavorText = flavorText .. "\n<font color='#FFAA00'>[MUTATOR: COLOSSAL] Target is massive and deals lethal damage!</font>"
		end

		if nextEnemyTemplate.Name:find("Beast Titan") or nextEnemyTemplate.IsLongRange then
			battle.Context.Range = "Long"
			flavorText = flavorText .. "\n<font color='#FF5555'>" .. nextEnemyTemplate.Name .. " is at LONG RANGE.</font>"
		else battle.Context.Range = "Close" end

		local eSkills = nextEnemyTemplate.Skills or {"Brutal Swipe"}
		local initCooldowns = {}
		for _, s in ipairs(eSkills) do
			local sd = SkillData.Skills[s]
			if sd and sd.Telegraphed then initCooldowns[s] = math.random(2, 4) end
		end

		battle.Enemy = {
			IsMinigame = nextEnemyTemplate.IsMinigame, IsPlayer = false, Name = nextEnemyTemplate.Name, IsHuman = false, IsNightmare = false, IsBoss = nextEnemyTemplate.IsBoss or false,
			HP = eHP, MaxHP = eHP, GateType = eGateType, GateHP = eGateHP, MaxGateHP = eGateHP, TotalStrength = eStr, TotalDefense = eDef, TotalSpeed = eSpd,
			Statuses = {}, Cooldowns = initCooldowns, Skills = eSkills,
			Drops = { XP = math.floor((nextEnemyTemplate.Drops and nextEnemyTemplate.Drops.XP or 15) * dropMult), Dews = math.floor((nextEnemyTemplate.Drops and nextEnemyTemplate.Drops.Dews or 10) * dropMult), ItemChance = nextEnemyTemplate.Drops and nextEnemyTemplate.Drops.ItemChance or {} },
			LastSkill = "None", AwakenedStats = enemyAwakenedStats, AIPoints = 0
		}
		battle.Player.Cooldowns = {}; battle.Player.Statuses = {} 
		local titanRuneLvl = tonumber(player:GetAttribute("Rune_Titan")) or 0
		local pMaxTitanEnergy = 100 + (titanRuneLvl * 25)
		battle.Player.HP = battle.Player.MaxHP; battle.Player.Gas = battle.Player.MaxGas; battle.Player.TitanEnergy = math.min(pMaxTitanEnergy, (battle.Player.TitanEnergy or 0) + 30); battle.Player.LastSkill = "None"

		if nextEnemyTemplate.IsMinigame then CombatUpdate:FireClient(player, "StartMinigame", {Battle = battle, LogMsg = flavorText .. "\n" .. rewardStr .. killMsg, MinigameType = nextEnemyTemplate.IsMinigame})
		else CombatUpdate:FireClient(player, "WaveComplete", {Battle = battle, LogMsg = flavorText .. "\n" .. rewardStr .. killMsg, XP = xpGain, Dews = dewsGain, Items = droppedItems}) end
		battle.IsProcessing = false
		return
	end

	if battle.Context.IsEndless then
		battle.Context.CurrentWave += 1
		local nextWave = battle.Context.CurrentWave
		local prestige = player.leaderstats.Prestige.Value
		local maxPart = math.min(8, player:GetAttribute("CurrentPart") or 1)
		local targetPart = math.random(1, maxPart)
		local partData = EnemyData.Parts[targetPart]
		local nextEnemyTemplate = GetValidEndlessMob(partData)

		local hpMult = GetHPScale(targetPart, true, nextWave) * 1.3
		local dmgMult = GetDmgScale(targetPart, true, nextWave) * 1.25
		local defMult = GetDefScale(targetPart, true, nextWave) * 1.15
		local spdMult = GetSpdScale(targetPart, true, nextWave)
		local dropMult = (1.0 + (targetPart * 0.1) + (prestige * 0.25)) * 1.5

		local eHP = math.floor(nextEnemyTemplate.Health * hpMult)
		local eGateType = nextEnemyTemplate.GateType
		local eGateHP = math.floor((nextEnemyTemplate.GateHP or 0) * (eGateType == "Steam" and 1 or hpMult))
		local eStr = math.floor(nextEnemyTemplate.Strength * dmgMult)
		local eDef = math.floor(nextEnemyTemplate.Defense * defMult)
		local eSpd = math.floor(nextEnemyTemplate.Speed * spdMult)

		local flavorText = "<font color='#AA55FF'>[ENDLESS EXPEDITION - WAVE " .. nextWave .. "]</font>\nYou encounter a " .. nextEnemyTemplate.Name .. "!"

		battle.Context.Range = "Close"
		if nextEnemyTemplate.Name:find("Beast Titan") or nextEnemyTemplate.IsLongRange then
			battle.Context.Range = "Long"
			flavorText = flavorText .. "\n<font color='#FF5555'>" .. nextEnemyTemplate.Name .. " is at LONG RANGE.</font>"
		end

		local eSkills = nextEnemyTemplate.Skills or {"Brutal Swipe"}
		local initCooldowns = {}
		for _, s in ipairs(eSkills) do
			local sd = SkillData.Skills[s]
			if sd and sd.Telegraphed then initCooldowns[s] = math.random(2, 4) end
		end

		battle.Context.TurnCount = 0; battle.Context.StoredBoss = nil
		battle.Enemy = {
			IsMinigame = nextEnemyTemplate.IsMinigame, IsPlayer = false, Name = nextEnemyTemplate.Name, IsHuman = nextEnemyTemplate.IsHuman or false, IsNightmare = false, IsBoss = nextEnemyTemplate.IsBoss or false,
			HP = eHP, MaxHP = eHP, GateType = eGateType, GateHP = eGateHP, MaxGateHP = eGateHP, TotalStrength = eStr, TotalDefense = eDef, TotalSpeed = eSpd,
			Statuses = {}, Cooldowns = initCooldowns, Skills = eSkills,
			Drops = { XP = math.floor((nextEnemyTemplate.Drops and nextEnemyTemplate.Drops.XP or 15) * dropMult), Dews = math.floor((nextEnemyTemplate.Drops and nextEnemyTemplate.Drops.Dews or 10) * dropMult), ItemChance = nextEnemyTemplate.Drops and nextEnemyTemplate.Drops.ItemChance or {} },
			LastSkill = "None", AIPoints = 0
		}
		battle.Player.Cooldowns = {}; battle.Player.Statuses = {} 
		battle.Player.HP = battle.Player.MaxHP; battle.Player.Gas = battle.Player.MaxGas; battle.Player.TitanEnergy = math.min(battle.Player.MaxTitanEnergy or 100, (battle.Player.TitanEnergy or 0) + 30); battle.Player.LastSkill = "None"

		if nextEnemyTemplate.IsMinigame then CombatUpdate:FireClient(player, "StartMinigame", {Battle = battle, LogMsg = flavorText .. "\n" .. killMsg, MinigameType = nextEnemyTemplate.IsMinigame})
		else CombatUpdate:FireClient(player, "WaveComplete", {Battle = battle, LogMsg = flavorText .. "\n" .. killMsg, XP = xpGain, Dews = dewsGain, Items = droppedItems}) end
		battle.IsProcessing = false
		return
	end

	if battle.Context.IsStoryMission and battle.Context.CurrentWave < battle.Context.TotalWaves then
		battle.Context.CurrentWave += 1
		if battle.Context.TargetPart == (player:GetAttribute("CurrentPart") or 1) then player:SetAttribute("CurrentWave", battle.Context.CurrentWave) end

		local prestige = player.leaderstats.Prestige.Value
		local targetPart = battle.Context.TargetPart
		local currentWave = battle.Context.CurrentWave

		local hpMult = GetHPScale(targetPart, false, currentWave)
		local dmgMult = GetDmgScale(targetPart, false, currentWave)
		local defMult = GetDefScale(targetPart, false, currentWave)
		local spdMult = GetSpdScale(targetPart, false, currentWave)

		local partData = EnemyData.Parts[targetPart]
		local waveData = battle.Context.MissionData.Waves[battle.Context.CurrentWave]
		local nextEnemyTemplate = GetTemplate(partData, waveData.Template)

		if nextEnemyTemplate.IsDialogue then
			battle.Context.TurnCount = 0; battle.Context.StoredBoss = nil
			battle.Enemy = {
				IsMinigame = false, IsDialogue = true, Name = "Story", Dialogues = nextEnemyTemplate.Dialogues, Choices = nextEnemyTemplate.Choices, Rewards = nextEnemyTemplate.Rewards,
				HP = 1, MaxHP = 1, GateType = nil, GateHP = 0, MaxGateHP = 0, TotalStrength = 0, TotalDefense = 0, TotalSpeed = 0,
				Statuses = {}, Cooldowns = {}, Skills = {}, Drops = { XP = 0, Dews = 0, ItemChance = {} }, LastSkill = "None"
			}
			battle.Player.Cooldowns = {}; battle.Player.Statuses = {} 
			battle.Player.LastSkill = "None"

			CombatUpdate:FireClient(player, "Dialogue", { Dialogues = nextEnemyTemplate.Dialogues, Choices = nextEnemyTemplate.Choices, Battle = battle })
			battle.IsProcessing = false
			return
		end

		local dropMult = 1.0 + (targetPart * 0.1) + (prestige * 0.25)
		local nextFinalDropXP = math.floor((nextEnemyTemplate.Drops and nextEnemyTemplate.Drops.XP or 15) * dropMult)
		local nextFinalDropDews = math.floor((nextEnemyTemplate.Drops and nextEnemyTemplate.Drops.Dews or 10) * dropMult)

		local flavorText = waveData.Flavor
		if not flavorText or flavorText == "" then flavorText = "Prepare to engage " .. (nextEnemyTemplate.Name or "the enemy") .. "!" end

		if nextEnemyTemplate.Name:find("Beast Titan") or nextEnemyTemplate.IsLongRange then
			battle.Context.Range = "Long"
			flavorText = flavorText .. "\n<font color='#FF5555'>" .. nextEnemyTemplate.Name .. " is at LONG RANGE.</font>"
		else
			battle.Context.Range = "Close"
		end

		local eSkills = nextEnemyTemplate.Skills or {"Brutal Swipe"}
		local initCooldowns = {}
		for _, s in ipairs(eSkills) do
			local sd = SkillData.Skills[s]
			if sd and sd.Telegraphed then initCooldowns[s] = math.random(2, 4) end
		end

		battle.Context.TurnCount = 0; battle.Context.StoredBoss = nil
		battle.Enemy = {
			IsMinigame = nextEnemyTemplate.IsMinigame, IsPlayer = false, Name = nextEnemyTemplate.Name, IsHuman = nextEnemyTemplate.IsHuman or false, IsNightmare = false, IsBoss = nextEnemyTemplate.IsBoss or false,
			HP = math.floor((nextEnemyTemplate.Health or 100) * hpMult), MaxHP = math.floor((nextEnemyTemplate.Health or 100) * hpMult),
			GateType = nextEnemyTemplate.GateType, GateHP = math.floor((nextEnemyTemplate.GateHP or 0) * (nextEnemyTemplate.GateType == "Steam" and 1 or hpMult)), MaxGateHP = math.floor((nextEnemyTemplate.GateHP or 0) * (nextEnemyTemplate.GateType == "Steam" and 1 or hpMult)),
			TotalStrength = math.floor((nextEnemyTemplate.Strength or 10) * dmgMult), TotalDefense = math.floor((nextEnemyTemplate.Defense or 10) * defMult), TotalSpeed = math.floor((nextEnemyTemplate.Speed or 10) * spdMult),
			Statuses = {}, Cooldowns = initCooldowns, Skills = eSkills,
			Drops = { XP = nextFinalDropXP, Dews = nextFinalDropDews, ItemChance = nextEnemyTemplate.Drops and nextEnemyTemplate.Drops.ItemChance or {} },
			LastSkill = "None", AIPoints = 0
		}
		battle.Player.Cooldowns = {}; battle.Player.Statuses = {} 
		local titanRuneLvl = tonumber(player:GetAttribute("Rune_Titan")) or 0
		local pMaxTitanEnergy = 100 + (titanRuneLvl * 25)
		battle.Player.Gas = battle.Player.MaxGas; battle.Player.TitanEnergy = math.min(pMaxTitanEnergy, (battle.Player.TitanEnergy or 0) + 30); battle.Player.LastSkill = "None"

		if nextEnemyTemplate.IsMinigame then 
			CombatUpdate:FireClient(player, "StartMinigame", {Battle = battle, LogMsg = "<font color='#FFD700'>[WAVE " .. battle.Context.CurrentWave .. "]</font>\n" .. flavorText, MinigameType = nextEnemyTemplate.IsMinigame})
		else 
			if wasDialogue then
				CombatUpdate:FireClient(player, "Start", {Battle = battle, LogMsg = "<font color='#FFD700'>[WAVE " .. battle.Context.CurrentWave .. "]</font>\n" .. flavorText .. killMsg})
			else
				CombatUpdate:FireClient(player, "WaveComplete", {Battle = battle, LogMsg = "<font color='#FFD700'>[WAVE " .. battle.Context.CurrentWave .. "]</font>\n" .. flavorText .. killMsg, XP = xpGain, Dews = dewsGain, Items = droppedItems}) 
			end
		end
		battle.IsProcessing = false
	else
		if battle.Context.IsStoryMission then
			player:SetAttribute("CampaignClear_Part" .. battle.Context.TargetPart, true)
			local playerCurrentPart = player:GetAttribute("CurrentPart") or 1
			if battle.Context.TargetPart == playerCurrentPart then
				local nextPart = playerCurrentPart + 1
				if EnemyData.Parts[nextPart] or nextPart == 9 then
					player:SetAttribute("CurrentPart", nextPart); player:SetAttribute("CurrentWave", 1) 
				end
			end
		end

		if battle.Context.IsLabyrinth then
			LabyrinthManager.OnCombatWin(player)
		end

		CombatUpdate:FireClient(player, "Victory", {Battle = battle, XP = xpGain, Dews = dewsGain, Items = droppedItems, ExtraLog = killMsg})
		ActiveBattles[player.UserId] = nil
		player:SetAttribute("InCombat", false)
	end
end

local function SafeTriggerPathsShop(player, ctx)
	if ctx and ctx.IsPaths then
		player:SetAttribute("PathsFloor", 1) 
		local pEvent = Network:FindFirstChild("PathsShopEvent")
		if pEvent then pEvent:FireClient(player, "Open") end
	end
end

local function IsSkillValid(player, skillName, isTransformedCheck)
	local sData = SkillData.Skills[skillName]
	if not sData then return false end

	local req = tostring(sData.Requirement or "None")

	local universalMoves = { 
		["Maneuver"]=true, ["Evasive Maneuver"]=true, ["Block"]=true, 
		["Close In"]=true, ["Fall Back"]=true, ["Advance"]=true, ["Charge"]=true, 
		["Recover"]=true, ["Retreat"]=true, ["Flee"]=true, ["Transform"]=true,
		["Basic Slash"]=true, ["Heavy Slash"]=true, ["Flare Gun"]=true, ["Anti-Titan Rifle"]=true
	}
	if universalMoves[skillName] then return true end

	if isTransformedCheck then
		local myTitan = player:GetAttribute("Titan") or "None"
		local titanMoves = { ["Eject"]=true, ["Titan Recover"]=true, ["Titan Rest"]=true, ["Cannibalize"]=true, ["Titan Punch"]=true, ["Titan Kick"]=true }

		if req == "Transformed" or req == "AnyTitan" or req == myTitan or string.find(myTitan, req, 1, true) or titanMoves[skillName] then
			return true
		end

		local validHybridMoves = GetTitanSkills(myTitan)
		for _, m in ipairs(validHybridMoves) do
			if m == skillName then return true end
		end

		return false
	end

	if req == "None" or req == "ODM" then return true end

	local myClan = player:GetAttribute("Clan") or "None"
	if myClan ~= "None" then
		if string.find(myClan, req, 1, true) then return true end
		if string.find(req, "Awakened", 1, true) then
			local baseReq = string.gsub(req, "Awakened ", "")
			if string.find(myClan, "Abyssal " .. baseReq, 1, true) then return true end
		end
	end

	if type(ItemData) == "table" and ItemData.Equipment then
		for iName, iData in pairs(ItemData.Equipment) do
			if iData.Style == req then
				local safeNameBase = iName:gsub("[^%w]", "")
				local count = tonumber(player:GetAttribute(safeNameBase .. "Count")) or tonumber(player:GetAttribute(iName)) or 0
				if count > 0 then return true end
			end
		end
	end

	return false
end

CombatAction.OnServerEvent:Connect(function(player, actionType, actionData)
	if actionType == "EngageStory" or actionType == "EngageWorldBoss" or actionType == "EngageNightmare" or actionType == "EngageRaid" or actionType == "EngageEndless" or actionType == "EngagePaths" or actionType == "EngageDoomsday" then 
		local pId = actionData and (actionData.PartId or actionData.BossId) or nil; StartBattle(player, actionType, pId); return 
	end

	local battle = ActiveBattles[player.UserId]

	if not battle then 
		if actionType == "Attack" and not player:GetAttribute("InMultiplayerRaid") then
			CombatUpdate:FireClient(player, "Fled", {Battle = nil, LogMsg = "<font color='#FF5555'>Battle synchronization lost. Force closing.</font>"})
		end
		return 
	end

	if actionType == "ExecutionComplete" then
		if not battle.Context.ExecutionTriggered then return end
		ProcessEnemyDeath(player, battle, battle.Enemy.Rewards)
		return
	end

	if actionType == "MinigameResult" then
		if actionData.MinigameType == "Dialogue" then
			ProcessEnemyDeath(player, battle, battle.Enemy.Rewards)
			return
		end

		if actionData.MinigameType == "Clash" then
			local clashSkill = actionData.ClashSkill or "Attack"
			local enemySkill = actionData.EnemySkill or "Ultimate"
			local turnDelay = player:GetAttribute("HasDoubleSpeed") and 0.4 or 0.8

			if actionData.Success then
				battle.Enemy.Statuses["Telegraphing"] = nil
				battle.Enemy.Statuses["Stun"] = 1
				if battle.Enemy.GateHP and battle.Enemy.GateHP > 0 then
					battle.Enemy.GateHP = 0 
				end

				local dmg = math.floor(battle.Enemy.MaxHP * 0.15) 
				battle.Enemy.HP = math.max(1, battle.Enemy.HP - dmg)

				local winMsg = "<font color='#FFD700'><b>[PERFECT CLASH!]</b></font>\nYou overpowered " .. battle.Enemy.Name .. "'s " .. enemySkill .. " with " .. clashSkill .. "!\nDealt " .. dmg .. " damage and shattered their stance!"
				CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = winMsg, DidHit = true, ShakeType = "Heavy"})
			else
				battle.Enemy.Statuses["Telegraphing"] = nil
				local eSkillMult = (SkillData.Skills[enemySkill] and SkillData.Skills[enemySkill].Mult or 3.0) * 1.5
				local baseDmg = CombatCore.CalculateDamage(battle.Enemy, battle.Player, eSkillMult, "Body", battle.Context)
				CombatCore.TakeDamage(battle.Player, baseDmg, "Enemy")

				local loseMsg = "<font color='#FF0000'><b>[OVERPOWERED!]</b></font>\nYou were crushed by " .. enemySkill .. "!\nTook " .. baseDmg .. " massive damage!"
				CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = loseMsg, DidHit = true, ShakeType = "Heavy"})
			end

			task.wait(turnDelay)
			if battle.Player.HP < 1 then
				CombatUpdate:FireClient(player, "Defeat", {Battle = battle})
				SafeTriggerPathsShop(player, battle.Context)
				if battle.Context.IsLabyrinth then LabyrinthManager.OnCombatLoss(player) end
				ActiveBattles[player.UserId] = nil
				player:SetAttribute("InCombat", false)
			elseif battle.Enemy.HP < 1 then
				ProcessEnemyDeath(player, battle)
			else
				battle.IsProcessing = false
				CombatUpdate:FireClient(player, "Update", {Battle = battle})
			end
			return
		end

		if battle.Enemy.IsMinigame then
			if actionData.Success then ProcessEnemyDeath(player, battle)
			else 
				CombatUpdate:FireClient(player, "Defeat", {Battle = battle})
				SafeTriggerPathsShop(player, battle.Context)
				if battle.Context.IsLabyrinth then LabyrinthManager.OnCombatLoss(player) end
				ActiveBattles[player.UserId] = nil 
				player:SetAttribute("InCombat", false)
			end
		end
		return
	end

	-- [[ THE FIX: Relocated Retreat Check beneath 'not battle' check to prevent it from hijacking Multiplayer Raids ]]
	if actionType == "Attack" then
		local skillName = actionData.SkillName
		if skillName == "Retreat" or skillName == "Flee" then
			CombatUpdate:FireClient(player, "Fled", {Battle = battle})
			SafeTriggerPathsShop(player, battle.Context)
			if battle.Context.IsLabyrinth then LabyrinthManager.OnCombatLoss(player) end
			ActiveBattles[player.UserId] = nil
			player:SetAttribute("InCombat", false)
			return
		end
	end

	if actionType ~= "Attack" or battle.IsProcessing then 
		if actionType == "Attack" and battle.IsProcessing then
			CombatUpdate:FireClient(player, "Update", {Battle = battle})
		end
		return 
	end

	local skillName = actionData.SkillName
	local targetLimb = actionData.TargetLimb or "Body" 
	local skill = SkillData.Skills[skillName]
	local hasGas, hasHeat = true, true

	if skill then
		local isTransformed = battle.Player.Statuses and battle.Player.Statuses["Transformed"]

		if not IsSkillValid(player, skillName, isTransformed) then
			CombatUpdate:FireClient(player, "Update", {Battle = battle})
			return
		end

		if not isTransformed then
			local actualGasCost = tonumber(skill.GasCost) or 0
			if battle.Context.Terrain == "Forest" then actualGasCost = math.ceil(actualGasCost * 0.5)
			elseif battle.Context.Terrain == "Plains" then actualGasCost = math.ceil(actualGasCost * 1.5) end

			if (tonumber(battle.Player.Gas) or 0) < actualGasCost then hasGas = false end
		else
			local actualHeatCost = tonumber(skill.EnergyCost) or tonumber(skill.HeatCost) or 0 
			if (tonumber(battle.Player.TitanEnergy) or 0) < actualHeatCost then hasHeat = false end
		end
	end

	if not skill or (battle.Player.Cooldowns[skillName] and battle.Player.Cooldowns[skillName] > 0) or not hasGas or not hasHeat then 
		CombatUpdate:FireClient(player, "Update", {Battle = battle}); return 
	end

	local enemyTelegraph = battle.Enemy.Statuses and battle.Enemy.Statuses["Telegraphing"]
	local isHeavyAttack = skill and (tonumber(skill.Mult) or 0) >= 3.0

	if enemyTelegraph and isHeavyAttack and not (skill.Effect == "Block" or skill.Effect == "Dodge") then
		battle.IsProcessing = true
		battle.Player.LastSkill = skillName

		if skill then
			if not (battle.Player.Statuses and battle.Player.Statuses["Transformed"]) then
				local actualGasCost = tonumber(skill.GasCost) or 0
				if battle.Context.Terrain == "Forest" then actualGasCost = math.ceil(actualGasCost * 0.5)
				elseif battle.Context.Terrain == "Plains" then actualGasCost = math.ceil(actualGasCost * 1.5) end
				battle.Player.Gas = math.max(0, (tonumber(battle.Player.Gas) or 0) - actualGasCost) 
			else
				local actualHeatCost = tonumber(skill.EnergyCost) or tonumber(skill.HeatCost) or 0
				battle.Player.TitanEnergy = math.max(0, (tonumber(battle.Player.TitanEnergy) or 0) - actualHeatCost)
			end
		end

		CombatUpdate:FireClient(player, "StartMinigame", {
			Battle = battle,
			MinigameType = "Clash",
			LogMsg = "<font color='#FF0000'><b>[CLASH INITIATED!]</b></font>\nOverpower the enemy's attack!",
			ClashSkill = skillName,
			EnemySkill = enemyTelegraph
		})
		return
	end

	battle.IsProcessing = true
	local turnDelay = player:GetAttribute("HasDoubleSpeed") and 0.35 or 0.8

	if skillName == "Maneuver" or skillName == "Evasive Maneuver" or skillName == "Smoke Screen" then 
		PlayVFX:FireClient(player, "Maneuver", "Self")
	elseif skillName == "Close In" or skillName == "Advance" or skillName == "Charge" then
		if not (battle.Player.Statuses and battle.Player.Statuses["Transformed"]) then
			PlayVFX:FireClient(player, "Maneuver", "Self")
		end
	end

	local function DispatchStrike(attacker, defender, strikeSkill, aimLimb)
		if attacker.HP <= 0 or defender.HP <= 0 then return end

		local skillObj = SkillData.Skills[strikeSkill]
		if skillObj then
			if skillObj.Effect == "CloseGap" or strikeSkill == "Close In" or strikeSkill == "Advance" or strikeSkill == "Charge" then
				battle.Context.Range = "Close"
				if attacker.IsPlayer then UpdateBountyProgress(attacker.PlayerObj, "Maneuver", 1) end
			elseif skillObj.Effect == "FallBack" or strikeSkill == "Fall Back" then
				battle.Context.Range = "Long"
				if attacker.IsPlayer then UpdateBountyProgress(attacker.PlayerObj, "Maneuver", 1) end
			elseif skillObj.Effect == "Dodge" or strikeSkill == "Maneuver" or strikeSkill == "Evasive Maneuver" then
				if attacker.IsPlayer then UpdateBountyProgress(attacker.PlayerObj, "Maneuver", 1) end
			elseif skillObj.Effect == "Transform" or strikeSkill == "Transform" then
				if attacker.IsPlayer then UpdateBountyProgress(attacker.PlayerObj, "Transform", 1) end
			end
		end

		local success, msg, didHit, shakeType = pcall(function() 
			return CombatCore.ExecuteStrike(attacker, defender, strikeSkill, aimLimb, attacker.IsPlayer and "You" or attacker.Name, defender.IsPlayer and "you" or defender.Name, attacker.IsPlayer and "#FFFFFF" or "#FF5555", defender.IsPlayer and "#FFFFFF" or "#FF5555", battle.Context) 
		end)

		if success then 
			CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = msg, DidHit = didHit, ShakeType = shakeType, SkillUsed = strikeSkill, IsPlayerAttacking = attacker.IsPlayer})

			if didHit then
				if attacker.IsPlayer then
					if shakeType == "Heavy" then PlayVFX:FireClient(player, "PlayerCritical", "Enemy") else PlayVFX:FireClient(player, "PlayerSlash", "Enemy") end
				else
					if string.find(strikeSkill:lower(), "bite") then PlayVFX:FireClient(player, "TitanBite", "Self")
					elseif shakeType == "Heavy" then PlayVFX:FireClient(player, "PlayerCritical", "Self") else PlayVFX:FireClient(player, "PlayerSlash", "Self") end
				end
			else
				PlayVFX:FireClient(player, "Block", "Self")
			end
			task.wait(turnDelay) 
		else 
			CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = "<font color='#FF0000'>SERVER LOGIC ERROR: " .. tostring(msg) .. "</font>", DidHit = false, ShakeType = "None"}) 
		end
	end

	local pRoll = (battle.Player.TotalSpeed or 10) + math.random(1, 15)
	local eRoll = (battle.Enemy.TotalSpeed or 10) + math.random(1, 15)

	if skill.Effect == "Block" or skill.Effect == "FallBack" or skill.Effect == "CloseGap" or skillName == "Maneuver" or skillName == "Evasive Maneuver" then
		pRoll += 10000 
	end

	if battle.Enemy.Statuses and battle.Enemy.Statuses["Telegraphing"] then
		eRoll -= 10000 
	end

	if battle.Enemy.Statuses and battle.Enemy.Statuses["Enraged"] then
		eRoll += 50 
	end

	local combatants = { battle.Player, battle.Enemy }
	table.sort(combatants, function(a, b) return (a.IsPlayer and pRoll or eRoll) > (b.IsPlayer and pRoll or eRoll) end)

	local success, loopErr = pcall(function()
		for _, combatant in ipairs(combatants) do

			if battle.Enemy.IsBoss and not battle.Enemy.EnragedOnce then
				local hpRatio = battle.Enemy.HP / battle.Enemy.MaxHP
				if hpRatio <= 0.30 and battle.Enemy.HP > 0 then
					battle.Enemy.EnragedOnce = true
					if not battle.Enemy.Statuses then battle.Enemy.Statuses = {} end
					battle.Enemy.Statuses["Enraged"] = 999
					battle.Enemy.Statuses["Stun"] = nil
					battle.Enemy.Statuses["Bleed"] = nil
					battle.Enemy.Statuses["Burn"] = nil
					battle.Enemy.Statuses["Blinded"] = nil
					battle.Enemy.Statuses["TrueBlind"] = nil
					battle.Enemy.Statuses["Crippled"] = nil
					battle.Enemy.Statuses["Weakened"] = nil
					battle.Enemy.Statuses["Debuff_Defense"] = nil
					battle.Enemy.Statuses["Telegraphing"] = nil

					battle.Enemy.HP = math.floor(battle.Enemy.MaxHP * 0.5)
					if battle.Enemy.MaxGateHP and battle.Enemy.MaxGateHP > 0 then
						battle.Enemy.GateHP = battle.Enemy.MaxGateHP
					end

					local enrageMsg = "<font color='#FF0000'><b>[CRITICAL WARNING]</b></font>\n<font color='#FFAA00'>" .. battle.Enemy.Name .. " roars in absolute fury! All debuffs cleansed! HP Restored to 50%! Armor Regenerated! Damage & Speed massively increased!</font>"

					CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = enrageMsg, DidHit = false, ShakeType = "Heavy", EnrageTrigger = true})
					task.wait(turnDelay)
				end
			end

			if battle.Player.HP < 1 or battle.Enemy.HP < 1 then break end
			if combatant.HP < 1 then continue end

			local wasIncapacitated = false
			if combatant.Statuses and (combatant.Statuses["Blinded"] or combatant.Statuses["TrueBlind"] or combatant.Statuses["Stun"]) then
				wasIncapacitated = true
			end

			local dotDamage, dotLog = CombatCore.TickStatuses(combatant)

			if dotDamage > 0 then
				local targetName = combatant.IsPlayer and "You" or combatant.Name
				CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = targetName .. " took damage from status effects!" .. dotLog, DidHit = false, ShakeType = "None"})
				task.wait(0.2)
				if combatant.HP < 1 then continue end 
			end

			if combatant.IsDoomsdayBoss then
				battle.Context.DoomsdayTurn = (battle.Context.DoomsdayTurn or 0) + 1
				local turn = battle.Context.DoomsdayTurn
				local msg = "<font color='#FF5555'>The Doomsday Titan continues its apocalyptic march... DEAL AS MUCH DAMAGE AS POSSIBLE!</font>"

				if turn % 8 == 0 then
					combatant.GateType = "Steam"
					combatant.MaxGateHP = 5
					combatant.GateHP = 5
					msg = "<font color='#FFAA00'><b>[PHASE SHIFT: STEAM]</b> The Doomsday Titan vents Colossal Steam to repel your attacks!</font>"
				elseif turn % 8 == 4 then
					combatant.GateType = "Reinforced Skin"
					local newGate = math.floor(battle.Player.TotalStrength * 12) 
					combatant.MaxGateHP = newGate
					combatant.GateHP = newGate
					msg = "<font color='#AAAAAA'><b>[PHASE SHIFT: ARMOR]</b> The Doomsday Titan hardens its skeletal structure! Break it!</font>"
				elseif turn % 8 == 1 and turn > 1 then
					combatant.GateType = nil
					combatant.MaxGateHP = 0
					combatant.GateHP = 0
					msg = "<font color='#55FF55'><b>[PHASE SHIFT: EXPOSED]</b> The Doomsday Titan's defenses drop! Unleash everything!</font>"
				end

				CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = msg, DidHit = false, ShakeType = "Light"})
				task.wait(turnDelay)
				continue 
			end

			if wasIncapacitated then
				if combatant.IsBoss and combatant.Statuses and combatant.Statuses["Telegraphing"] then
					CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = "<font color='#FF0000'><b>" .. combatant.Name .. " shrugs off the crowd control and continues charging!</b></font>", DidHit = false, ShakeType = "None"})
					task.wait(0.4)
				else
					if combatant.Statuses and combatant.Statuses["Telegraphing"] then
						combatant.Statuses["Telegraphing"] = nil 
						CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = "<font color='#55FF55'><b>" .. combatant.Name .. "'s charge up was INTERRUPTED!</b></font>", DidHit = false, ShakeType = "Heavy"})
						task.wait(0.4)
					end

					local denyMsg = combatant.IsPlayer and "<font color='#555555'>You are INCAPACITATED and lost your turn!</font>" or "<font color='#555555'>" .. combatant.Name .. " is INCAPACITATED and lost their turn!</font>"
					CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = denyMsg, DidHit = false, ShakeType = "None"})
					task.wait(0.4)

					if not combatant.IsPlayer and not combatant.IsHuman then
						if not (combatant.Statuses and combatant.Statuses["Burn"]) then
							local regenAmt = math.min(math.floor(combatant.MaxHP * 0.05), 100)
							combatant.HP = math.min(combatant.MaxHP, combatant.HP + regenAmt)
						end
					end
					continue
				end
			end

			if combatant.IsPlayer then
				DispatchStrike(battle.Player, battle.Enemy, skillName, targetLimb)
			else
				local pRatio = (battle.Player.HP or 0) / (battle.Player.MaxHP or 100)
				if pRatio <= 0.30 and not battle.Context.AllyIntervened then
					local intChance = 35
					if string.find(battle.Enemy.Name, "Founding Titan") or string.find(battle.Enemy.Name, "Ymir") or string.find(battle.Enemy.Name, "Doomsday") then
						intChance = 75 
					end

					if math.random(1, 100) <= intChance then
						battle.Context.AllyIntervened = true
						local getPartyFunc = Network:FindFirstChild("GetPlayerParty")
						local partyData = getPartyFunc and getPartyFunc:Invoke(player) or {Members = {}}

						local friends = {}
						for _, mem in ipairs(partyData.Members) do
							if mem.UserId ~= player.UserId then table.insert(friends, mem) end
						end

						local allyName, allyQuote, allySkill, allyUserId, chunkDmg

						if #friends > 0 then
							local savior = friends[math.random(1, #friends)]
							allyName = savior.Name
							allyUserId = savior.UserId
							allyQuote = "I've got your back, " .. player.Name .. "!"
							allySkill = "Team Takedown"

							local fStr = (savior:GetAttribute("Strength") or 10)
							chunkDmg = math.max(fStr * 15, math.floor((battle.Enemy.MaxHP or 1000) * 0.15))
						else
							local allyKeys = {}
							for k, _ in pairs(EnemyData.Allies) do table.insert(allyKeys, k) end
							local allyKey = allyKeys[math.random(1, #allyKeys)]
							local allyData = EnemyData.Allies[allyKey]

							allyName = allyData.Name

							local validAllySkills = {}
							if allyData.Skills then
								for _, s in ipairs(allyData.Skills) do
									local lowerSkill = s:lower()
									local sd = SkillData.Skills[s]
									if (not sd or (sd.Effect ~= "Heal" and sd.Effect ~= "Buff" and sd.Effect ~= "Block")) and 
										not string.match(lowerSkill, "recover") and not string.match(lowerSkill, "heal") and not string.match(lowerSkill, "fortify") then
										table.insert(validAllySkills, s)
									end
								end
							end
							allySkill = #validAllySkills > 0 and validAllySkills[math.random(1, #validAllySkills)] or "Basic Slash"
							chunkDmg = math.max(allyData.Strength * 10, math.floor((battle.Enemy.MaxHP or 1000) * 0.15))

							local allyQuotes = {
								["Levi Ackerman"] = "Tch. Try not to die on me, brat.",
								["Mikasa Ackerman"] = "I won't let you die. Not here.",
								["Erwin Smith"] = "Advance! Dedicate your heart!",
								["Hange Zoe"] = "Ooh, a new test subject! Leave it to me!",
								["Armin Arlert"] = "I'll cover you! Strike now!"
							}
							allyQuote = allyQuotes[allyData.Name] or "I've got your back!"
						end

						local _, hitGate, gateBroken, actualDmg, gateName = CombatCore.TakeDamage(battle.Enemy, chunkDmg, "Ultrahard Steel Blades")

						local hitMsg = "<font color='#55FFFF'><b>[ALLY INTERVENTION!]</b></font>\n<font color='#55FFFF'>" .. allyName .. "</font> swooped in to assist you!\n<font color='#55FFFF'>" .. allyName .. "</font> used <b>" .. allySkill .. "</b> on " .. battle.Enemy.Name .. " for " .. actualDmg .. " dmg!"
						if hitGate then hitMsg = hitMsg .. " <font color='#DDDDDD'>[Hit " .. tostring(gateName) .. "!]</font>" end
						if gateBroken then hitMsg = hitMsg .. " <font color='#FFFFFF'><b>[" .. tostring(gateName):upper() .. " SHATTERED!]</b></font>" end

						CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = hitMsg, DidHit = true, ShakeType = "Heavy", SkillUsed = allySkill, IsPlayerAttacking = true, AllyIntervention = allyName, AllyQuote = allyQuote, AllyUserId = allyUserId})
						task.wait(turnDelay)

						if battle.Enemy.HP < 1 then break end 

						if battle.Enemy.Statuses and battle.Enemy.Statuses["Telegraphing"] then
							battle.Enemy.Statuses["Telegraphing"] = nil 
							CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = "<font color='#55FF55'><b>" .. battle.Enemy.Name .. "'s charge up was INTERRUPTED!</b></font>", DidHit = false, ShakeType = "Heavy"})
							task.wait(0.4)
						end

						CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = "<font color='#AAAAAA'>" .. battle.Enemy.Name .. " is reeling from the surprise attack and loses their turn!</font>", DidHit = false, ShakeType = "None"})
						task.wait(0.4)
						continue
					end
				end

				if not combatant.AIPoints then combatant.AIPoints = 0 end
				combatant.AIPoints += 1 

				local validAiSkills = {}
				local hasTelegraphed = false

				for _, s in ipairs(combatant.Skills) do
					local sd = SkillData.Skills[s]
					local isReady = not combatant.Cooldowns or not combatant.Cooldowns[s] or combatant.Cooldowns[s] <= 0
					local inRange = true
					if sd and sd.Range and sd.Range ~= "Any" then
						inRange = (sd.Range == battle.Context.Range)
					end

					if isReady and inRange then
						if sd and sd.Telegraphed then
							if combatant.AIPoints >= 3 then 
								table.insert(validAiSkills, s)
								hasTelegraphed = true
							end
						elseif sd and (sd.Mult or 1) >= 1.8 then
							if combatant.AIPoints >= 2 then table.insert(validAiSkills, s) end
						else
							table.insert(validAiSkills, s)
						end
					end
				end

				battle.Context.TurnCount = (battle.Context.TurnCount or 0) + 1
				local aiSkill = "Brutal Swipe"

				if combatant.Statuses and combatant.Statuses["Telegraphing"] then
					aiSkill = combatant.Statuses["Telegraphing"]; combatant.Statuses["Telegraphing"] = nil
					local sd = SkillData.Skills[aiSkill]
					if sd and sd.Range and sd.Range ~= "Any" and sd.Range ~= battle.Context.Range then
						CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = "<font color='#AAAAAA'>" .. combatant.Name .. " attempted to use <b>" .. aiSkill .. "</b>, but you changed range! The attack missed entirely!</font>", DidHit = false, ShakeType = "None"})
						task.wait(0.4)
						continue
					end
				else
					if hasTelegraphed then
						for _, s in ipairs(validAiSkills) do
							if SkillData.Skills[s].Telegraphed then aiSkill = s break end
						end
						combatant.AIPoints = 0 
					else
						if #validAiSkills > 0 then aiSkill = validAiSkills[math.random(1, #validAiSkills)] end
						if SkillData.Skills[aiSkill] and (SkillData.Skills[aiSkill].Mult or 1) >= 1.8 then
							combatant.AIPoints = math.max(0, combatant.AIPoints - 2) 
						end
					end

					if SkillData.Skills[aiSkill] and SkillData.Skills[aiSkill].Telegraphed then
						if not combatant.Statuses then combatant.Statuses = {} end
						combatant.Statuses["Telegraphing"] = aiSkill

						local hintStr = ""
						if SkillData.Skills[aiSkill].Unavoidable then
							if SkillData.Skills[aiSkill].Range == "Any" then
								hintStr = "\n<font color='#FF3333'><b>⚠️ MASSIVE AREA ATTACK! USE A HEAVY SKILL TO CLASH OR 'BLOCK'! ⚠️</b></font>"
							else
								hintStr = "\n<font color='#FF3333'><b>⚠️ UNAVOIDABLE CLOSE ATTACK! CLASH, 'FALL BACK', OR 'BLOCK'! ⚠️</b></font>"
							end
						else
							hintStr = "\n<font color='#55FF55'>[HINT: USE EVASIVE MANEUVER OR BLOCK!]</font>"
						end

						CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = "<b><font color='#FFAA00'>WARNING: " .. combatant.Name .. " is charging up " .. aiSkill:upper() .. "!</font></b>" .. hintStr, DidHit = false, ShakeType = "Heavy"})
						PlayVFX:FireClient(player, "TitanRoar", "Enemy")
						task.wait(0.6)
						continue
					end
				end

				if aiSkill == "Idle" then
					CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = "<font color='#AAAAAA'>" .. combatant.Name .. " stands completely still.</font>", DidHit = false, ShakeType = "None"})
					task.wait(0.4)
				else
					local aiTargets = {"Body", "Body", "Arms", "Legs", "Nape"}
					DispatchStrike(battle.Enemy, battle.Player, aiSkill, aiTargets[math.random(1, #aiTargets)])
				end
			end

			if battle.Player.Statuses and battle.Player.Statuses["Transformed"] and (tonumber(battle.Player.TitanEnergy) or 0) <= 0 then
				battle.Player.Statuses["Transformed"] = nil
				CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = "<font color='#FF5555'><b>[HEAT DEPLETED]</b> Your Titan body evaporates into steam! You are forced back into human form!</font>", DidHit = false, ShakeType = "None"})
				task.wait(turnDelay)
			end
		end
	end)

	if not success then
		warn("[Combat Server Error]: " .. tostring(loopErr))
		CombatUpdate:FireClient(player, "TurnStrike", {Battle = battle, LogMsg = "<font color='#FF0000'>SERVER LOGIC ERROR. State safely recovered.</font>", DidHit = false, ShakeType = "None"})
		task.wait(1.0)
	end

	if battle.Player.HP < 1 then
		CombatUpdate:FireClient(player, "Defeat", {Battle = battle})
		SafeTriggerPathsShop(player, battle.Context)

		if battle.Context.IsLabyrinth then
			LabyrinthManager.OnCombatLoss(player)
		end

		ActiveBattles[player.UserId] = nil
		player:SetAttribute("InCombat", false)
	elseif battle.Enemy.HP < 1 then
		ProcessEnemyDeath(player, battle)
	else
		battle.IsProcessing = false
		CombatUpdate:FireClient(player, "Update", {Battle = battle})
	end
end)

labEvent.Event:Connect(function(player, floor)
	StartBattle(player, "EngageLabyrinth", floor)
end)

Players.PlayerRemoving:Connect(function(player) 
	ActiveBattles[player.UserId] = nil 
end)