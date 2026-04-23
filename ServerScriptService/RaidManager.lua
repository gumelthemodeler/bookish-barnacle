-- @ScriptType: Script
-- @ScriptType: Script
-- Name: RaidManager
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = ReplicatedStorage:WaitForChild("Network")

local RaidAction = Network:FindFirstChild("RaidAction") or Instance.new("RemoteEvent", Network)
RaidAction.Name = "RaidAction"
local CombatUpdate = Network:FindFirstChild("CombatUpdate") or Instance.new("RemoteEvent", Network)
CombatUpdate.Name = "CombatUpdate"

local EnemyData = require(ReplicatedStorage:WaitForChild("EnemyData"))
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))
local SkillData = require(ReplicatedStorage:WaitForChild("SkillData"))
local CombatCore = require(script.Parent:WaitForChild("CombatCore"))

local ActiveRaids = {}
-- [[ THE FIX: Lengthened turn duration so players don't feel like the game is playing itself ]]
local TURN_DURATION = 30
local AoESkills = { ["Colossal Steam"] = 0.40, ["Titan Roar"] = 0.30, ["Stomp"] = 0.25, ["Crushed Boulders"] = 0.35 }

local function CreateCombatant(player)
	local wpnName = player:GetAttribute("EquippedWeapon") or "None"
	local accName = player:GetAttribute("EquippedAccessory") or "None"
	local wpnBonus = (ItemData.Equipment[wpnName] and ItemData.Equipment[wpnName].Bonus) or {}
	local accBonus = (ItemData.Equipment[accName] and ItemData.Equipment[accName].Bonus) or {}

	local safeWpnName = wpnName:gsub("[^%w]", "")
	local awakenedString = player:GetAttribute(safeWpnName .. "_Awakened")
	local awakenedStats = { DmgMult = 1.0, DodgeBonus = 0, CritBonus = 0, HpBonus = 0, SpdBonus = 0, GasBonus = 0, HealOnKill = 0, IgnoreArmor = 0 }

	if awakenedString then
		for stat in string.gmatch(awakenedString, "[^|]+") do
			stat = stat:match("^%s*(.-)%s*$")
			if stat:find("DMG") then awakenedStats.DmgMult += tonumber(stat:match("%d+")) / 100
			elseif stat:find("DODGE") then awakenedStats.DodgeBonus += tonumber(stat:match("%d+"))
			elseif stat:find("CRIT") then awakenedStats.CritBonus += tonumber(stat:match("%d+"))
			elseif stat:find("MAX HP") then awakenedStats.HpBonus += tonumber(stat:match("%d+"))
			elseif stat:find("SPEED") then awakenedStats.SpdBonus += tonumber(stat:match("%d+"))
			elseif stat:find("GAS CAP") then awakenedStats.GasBonus += tonumber(stat:match("%d+"))
			elseif stat:find("IGNORE") then awakenedStats.IgnoreArmor += tonumber(stat:match("%d+")) / 100
			end
		end
	end

	local pMaxHP = ((player:GetAttribute("Health") or 10) + (wpnBonus.Health or 0) + (accBonus.Health or 0)) * 10 + awakenedStats.HpBonus
	local pMaxGas = ((player:GetAttribute("Gas") or 10) + (wpnBonus.Gas or 0) + (accBonus.Gas or 0)) * 10 + awakenedStats.GasBonus

	return {
		IsPlayer = true, Name = player.Name, PlayerObj = player, UserId = player.UserId,
		Clan = player:GetAttribute("Clan") or "None", Titan = player:GetAttribute("Titan") or "None",
		Style = ItemData.Equipment[wpnName] and ItemData.Equipment[wpnName].Style or "None",
		HP = pMaxHP, MaxHP = pMaxHP, Gas = pMaxGas, MaxGas = pMaxGas, TitanEnergy = 100, MaxTitanEnergy = 100,
		TotalStrength = (player:GetAttribute("Strength") or 10) + (wpnBonus.Strength or 0) + (accBonus.Strength or 0),
		TotalDefense = (player:GetAttribute("Defense") or 10) + (wpnBonus.Defense or 0) + (accBonus.Defense or 0),
		TotalSpeed = (player:GetAttribute("Speed") or 10) + (wpnBonus.Speed or 0) + (accBonus.Speed or 0),
		TotalResolve = (player:GetAttribute("Resolve") or 10) + (wpnBonus.Resolve or 0) + (accBonus.Resolve or 0),
		Statuses = {}, Cooldowns = {}, Move = nil, TargetLimb = "Body", Aggro = 0
	}
end

local function BroadcastRaidUpdate(raid, action, extraData)
	for _, pData in ipairs(raid.Party) do
		if pData.PlayerObj and pData.PlayerObj.Parent then
			local fakeBattle = {
				Context = raid.Context,
				Player = pData,
				Enemy = raid.Boss
			}
			local payload = { Battle = fakeBattle }
			if extraData then
				for k, v in pairs(extraData) do payload[k] = v end
			end
			CombatUpdate:FireClient(pData.PlayerObj, action, payload)
		end
	end
end

local function EndRaid(raidId, isVictory)
	local raid = ActiveRaids[raidId]
	if not raid then return end

	local bData = EnemyData.RaidBosses[raid.BossId]

	for _, pData in ipairs(raid.Party) do
		local player = pData.PlayerObj
		if player and player.Parent then
			player:SetAttribute("InMultiplayerRaid", false)
			local fakeBattle = { Context = raid.Context, Player = pData, Enemy = raid.Boss }

			if isVictory then
				local drops = bData.Drops
				local dews = drops.Dews
				local xp = drops.XP
				local droppedItems = {}

				local isDead = (pData.HP <= 0)
				if isDead then
					dews = math.floor(dews * 0.5)
					xp = math.floor(xp * 0.5)
				end

				player.leaderstats.Dews.Value += dews
				player:SetAttribute("XP", (player:GetAttribute("XP") or 0) + xp)

				local extraLog = ""
				if isDead then extraLog = extraLog .. "<br/><font color='#FF5555'>[Penalty: Died in Combat (Half Rewards)]</font>" end

				if not isDead and drops.ItemChance then
					for iName, chance in pairs(drops.ItemChance) do
						if math.random(1, 100) <= chance then
							local safeName = iName:gsub("[^%w]", "") .. "Count"
							player:SetAttribute(safeName, (player:GetAttribute(safeName) or 0) + 1)
							table.insert(droppedItems, {Name = iName, Amount = 1})
						end
					end
				end

				CombatUpdate:FireClient(player, "Victory", { Battle = fakeBattle, XP = xp, Dews = dews, Items = droppedItems, ExtraLog = extraLog })
			else
				CombatUpdate:FireClient(player, "Defeat", { Battle = fakeBattle })
			end
		end
	end
	ActiveRaids[raidId] = nil
end

local function ResolveRaidTurn(raidId)
	local raid = ActiveRaids[raidId]
	if not raid or raid.State == "Resolving" then return end
	raid.State = "Resolving"

	local turnDelay = 0.8

	for _, actor in ipairs(raid.Party) do
		if actor.HP > 0 and raid.Boss.HP > 0 then
			if actor.Statuses and (actor.Statuses["Blinded"] or actor.Statuses["TrueBlind"] or actor.Statuses["Stun"]) then
				local logMsg = "<font color='#555555'>" .. actor.Name .. " is INCAPACITATED and lost their turn!</font>"
				BroadcastRaidUpdate(raid, "TurnStrike", { LogMsg = logMsg, ShakeType = "None" })
				task.wait(0.4)
				continue
			end

			-- [[ THE FIX: Extracted "Retreat" and "Flee" OUTSIDE the skill block. It was being bypassed because Flee isn't a combat skill, causing players to just basic-attack instead of fleeing. ]]
			local skill = SkillData.Skills[actor.Move]

			if actor.Move == "Retreat" or actor.Move == "Flee" or (skill and skill.Effect == "Flee") then
				actor.HP = 0 
				local fakeBattle = { Context = raid.Context, Player = actor, Enemy = raid.Boss }
				actor.PlayerObj:SetAttribute("InMultiplayerRaid", false)
				CombatUpdate:FireClient(actor.PlayerObj, "Fled", { Battle = fakeBattle })

				local logMsg = "<font color='#AAAAAA'>" .. actor.Name .. " fired a smoke signal and retreated from the Raid!</font>"
				BroadcastRaidUpdate(raid, "TurnStrike", { LogMsg = logMsg, ShakeType = "None" })
				task.wait(0.4)
				continue
			end

			if skill then
				if skill.GasCost then actor.Gas = math.max(0, actor.Gas - skill.GasCost) end
				if skill.EnergyCost then actor.TitanEnergy = math.max(0, actor.TitanEnergy - skill.EnergyCost) end
				if skill.Effect == "Rest" or actor.Move == "Recover" then actor.Gas = math.min(actor.MaxGas, actor.Gas + (actor.MaxGas * 0.40)) end

				if actor.Move == "Fall Back" then
					raid.Context.Range = "Long"
					local logMsg = "<font color='#55FFFF'>" .. actor.Name .. " fell back! The party is now at LONG RANGE!</font>"
					BroadcastRaidUpdate(raid, "TurnStrike", { LogMsg = logMsg, ShakeType = "None" })
					task.wait(turnDelay)
					continue
				end

				if actor.Move == "Close In" then
					raid.Context.Range = "Close"
					local logMsg = "<font color='#55FF55'>" .. actor.Name .. " fired ODM gear! The party closed the gap to MELEE RANGE!</font>"
					BroadcastRaidUpdate(raid, "TurnStrike", { LogMsg = logMsg, ShakeType = "None" })
					task.wait(turnDelay)
					continue
				end

				local sRange = skill.Range or "Close"
				if sRange ~= "Any" and sRange ~= raid.Context.Range then
					local logMsg = "<font color='#AAAAAA'>" .. actor.Name .. " used " .. actor.Move:upper() .. ", but the boss is at " .. string.upper(raid.Context.Range) .. " RANGE! The attack missed completely!</font>"
					BroadcastRaidUpdate(raid, "TurnStrike", { LogMsg = logMsg, ShakeType = "None" })
					task.wait(0.4)
					continue
				end
			end

			local startingBossHP = raid.Boss.HP
			local logMsg, didHit, shakeType = CombatCore.ExecuteStrike(actor, raid.Boss, actor.Move, actor.TargetLimb, actor.Name, raid.Boss.Name, "#55FFFF", "#FF5555", raid.Context)

			local damageDealt = startingBossHP - raid.Boss.HP
			if damageDealt > 0 then actor.Aggro += damageDealt end

			BroadcastRaidUpdate(raid, "TurnStrike", { LogMsg = logMsg, ShakeType = shakeType, SkillUsed = actor.Move, Attacker = actor.Name, DidHit = didHit, IsPlayerAttacking = true })
			task.wait(turnDelay)
		end
	end

	local target = nil
	for _, p in ipairs(raid.Party) do
		if p.HP > 0 then
			if not target or p.Aggro > target.Aggro then target = p end
		end
	end

	if raid.Boss.HP > 0 and target then

		if not raid.Boss.EnragedOnce then
			local hpRatio = raid.Boss.HP / raid.Boss.MaxHP
			if hpRatio <= 0.30 then
				raid.Boss.EnragedOnce = true
				if not raid.Boss.Statuses then raid.Boss.Statuses = {} end
				raid.Boss.Statuses["Enraged"] = 999
				raid.Boss.Statuses["Stun"] = nil
				raid.Boss.Statuses["Bleed"] = nil
				raid.Boss.Statuses["Burn"] = nil
				raid.Boss.Statuses["Blinded"] = nil
				raid.Boss.Statuses["TrueBlind"] = nil
				raid.Boss.Statuses["Crippled"] = nil
				raid.Boss.Statuses["Telegraphing"] = nil

				raid.Boss.HP = math.floor(raid.Boss.MaxHP * 0.5)
				if raid.Boss.MaxGateHP and raid.Boss.MaxGateHP > 0 then raid.Boss.GateHP = raid.Boss.MaxGateHP end

				local enrageMsg = "<font color='#FF0000'><b>[CRITICAL WARNING]</b></font>\n<font color='#FFAA00'>" .. raid.Boss.Name .. " roars in absolute fury! All debuffs cleansed! HP & Armor Restored! Damage increased!</font>"
				BroadcastRaidUpdate(raid, "TurnStrike", { LogMsg = enrageMsg, ShakeType = "Heavy", EnrageTrigger = true })
				task.wait(turnDelay)
			end
		end

		if raid.Boss.Statuses and (raid.Boss.Statuses["Stun"] or raid.Boss.Statuses["Blinded"] or raid.Boss.Statuses["TrueBlind"]) then
			if raid.Boss.Statuses["Telegraphing"] then
				BroadcastRaidUpdate(raid, "TurnStrike", { LogMsg = "<font color='#FF0000'><b>" .. raid.Boss.Name .. " shrugs off the crowd control and continues charging!</b></font>", ShakeType = "None" })
				task.wait(0.4)
			else
				local denyMsg = "<font color='#555555'>" .. raid.Boss.Name .. " is INCAPACITATED and lost their turn!</font>"
				BroadcastRaidUpdate(raid, "TurnStrike", { LogMsg = denyMsg, ShakeType = "None" })
				task.wait(0.4)
			end
		else
			local bSkills = raid.Boss.Skills
			local chosenSkill = bSkills[math.random(1, #bSkills)]

			if raid.Boss.Statuses["Telegraphing"] then
				chosenSkill = raid.Boss.Statuses["Telegraphing"]; raid.Boss.Statuses["Telegraphing"] = nil
			else
				local checkSkill = SkillData.Skills[chosenSkill]
				if checkSkill and checkSkill.Telegraphed then
					raid.Boss.Statuses["Telegraphing"] = chosenSkill
					local hintStr = " <font color='#55FF55'>[HINT: BLOCK OR EVADE!]</font>"
					BroadcastRaidUpdate(raid, "TurnStrike", { LogMsg = "<b><font color='#FFAA00'>WARNING: " .. raid.Boss.Name .. " is charging up " .. chosenSkill:upper() .. "!</font></b>" .. hintStr, ShakeType = "Heavy" })
					task.wait(0.6)
					chosenSkill = nil
				end
			end

			if chosenSkill then
				if AoESkills[chosenSkill] then
					local aoePct = AoESkills[chosenSkill]
					local logMsg = "<font color='#FFAA00'><b>" .. raid.Boss.Name .. " unleashes " .. chosenSkill:upper() .. "! It hits the entire party!</b></font>\n"

					for _, p in ipairs(raid.Party) do
						if p.HP > 0 then
							if p.Statuses and (tonumber(p.Statuses["Dodge"]) or 0) > 0 then
								logMsg = logMsg .. "- " .. p.Name .. " maneuvered out of the way!\n"
							else
								local rawDmg = math.floor(p.MaxHP * aoePct)
								local survived, hitGate, gateBroken, finalDmg, gateName = CombatCore.TakeDamage(p, rawDmg, "AoE")

								logMsg = logMsg .. "- " .. p.Name .. " takes " .. finalDmg .. " damage!"
								if hitGate then logMsg = logMsg .. " (Mitigated by " .. gateName .. ")" end
								if survived then logMsg = logMsg .. " <font color='#FF55FF'>...TATAKAE!</font>" end
								logMsg = logMsg .. "\n"
							end
						end
					end
					BroadcastRaidUpdate(raid, "TurnStrike", { LogMsg = logMsg, ShakeType = "Heavy", SkillUsed = chosenSkill, Attacker = raid.Boss.Name, IsPlayerAttacking = false })
					task.wait(turnDelay)
				else
					local sData = SkillData.Skills[chosenSkill]
					local sRange = sData and sData.Range or "Close"

					if raid.Context.Range == "Long" and sRange == "Close" then
						local logMsg = "<font color='#AAAAAA'>" .. raid.Boss.Name .. " used " .. chosenSkill:upper() .. ", but the party is at LONG RANGE! The attack missed completely!</font>"
						BroadcastRaidUpdate(raid, "TurnStrike", { LogMsg = logMsg, ShakeType = "None" })
						task.wait(0.4)
					else
						local logMsg, didHit, shakeType = CombatCore.ExecuteStrike(raid.Boss, target, chosenSkill, "Body", raid.Boss.Name, target.Name, "#FF5555", "#FFFFFF", raid.Context)
						BroadcastRaidUpdate(raid, "TurnStrike", { LogMsg = logMsg, ShakeType = shakeType, SkillUsed = chosenSkill, Attacker = raid.Boss.Name, DidHit = didHit, IsPlayerAttacking = false })
						task.wait(turnDelay)
					end
				end
			end
		end
	end

	for _, p in ipairs(raid.Party) do 
		if p.HP > 0 then 
			local dotDmg, dotLog = CombatCore.TickStatuses(p) 
			if dotDmg > 0 then p.HP -= dotDmg end
			if dotLog ~= "" then 
				BroadcastRaidUpdate(raid, "TurnStrike", { LogMsg = p.Name .. " took damage from status effects!" .. dotLog, ShakeType = "None" }) 
				task.wait(0.2)
			end
		end 
	end

	if raid.Boss.HP > 0 then
		local bDotDmg, bDotLog = CombatCore.TickStatuses(raid.Boss)
		if bDotDmg > 0 then raid.Boss.HP -= bDotDmg end
		if bDotLog ~= "" then 
			BroadcastRaidUpdate(raid, "TurnStrike", { LogMsg = raid.Boss.Name .. " took damage from status effects!" .. bDotLog, ShakeType = "None" }) 
			task.wait(0.2)
		end
	end

	if raid.Boss.GateType == "Steam" and raid.Boss.GateHP <= 0 and not raid.Boss.GateBrokenFlag then
		raid.Boss.GateBrokenFlag = true 
		BroadcastRaidUpdate(raid, "TurnStrike", { LogMsg = "<font color='#55FFFF'><b>The intense steam surrounding " .. raid.Boss.Name .. " has completely dissipated! The nape is exposed!</b></font>", ShakeType = "None" })
		task.wait(1.5)
	end

	if raid.Boss.HP <= 0 then EndRaid(raidId, true); return end

	local aliveCount = 0
	for _, p in ipairs(raid.Party) do if p.HP > 0 then aliveCount += 1 end end
	if aliveCount == 0 then EndRaid(raidId, false); return end

	for _, p in ipairs(raid.Party) do p.Move = nil end
	raid.Context.Turn += 1
	raid.TurnEndTime = os.time() + TURN_DURATION
	raid.State = "WaitingForMoves"

	BroadcastRaidUpdate(raid, "Update", { LogMsg = "<font color='#FFFF55'>--- TURN " .. raid.Context.Turn .. " STARTED (" .. TURN_DURATION .. "s) ---</font>" })
end

task.spawn(function()
	while task.wait(1) do
		local now = os.time()
		for raidId, raid in pairs(ActiveRaids) do
			if raid.State == "WaitingForMoves" and now >= raid.TurnEndTime then
				for _, p in ipairs(raid.Party) do
					if p.HP > 0 and not p.Move then
						p.Move = (p.Statuses and p.Statuses["Transformed"]) and "Titan Punch" or "Basic Slash"
						p.TargetLimb = "Body"
					end
				end
				ResolveRaidTurn(raidId)
			end
		end
	end
end)

local CombatAction = Network:FindFirstChild("CombatAction")
if CombatAction then
	CombatAction.OnServerEvent:Connect(function(player, action, data)
		if action == "Attack" then
			for raidId, raid in pairs(ActiveRaids) do
				if raid.State == "WaitingForMoves" then
					for _, p in ipairs(raid.Party) do
						if p.UserId == player.UserId then
							p.Move = data.SkillName
							p.TargetLimb = data.TargetLimb or "Body"

							local allReady = true
							for _, p2 in ipairs(raid.Party) do
								if p2.HP > 0 and not p2.Move then allReady = false end
							end
							if allReady then ResolveRaidTurn(raidId) end
							return 
						end
					end
				end
			end
		end
	end)
end

RaidAction.OnServerEvent:Connect(function(player, action, data)
	if action == "DeployParty" then
		local getPartyFunc = Network:FindFirstChild("GetPlayerParty")
		local partyData = nil
		if getPartyFunc then pcall(function() partyData = getPartyFunc:Invoke(player) end) end

		if not partyData or not partyData.Members or #partyData.Members == 0 then
			partyData = { Leader = player, Members = {player} }
		end

		if partyData.Leader.UserId ~= player.UserId then 
			Network.NotificationEvent:FireClient(player, "Only the Party Leader can start the Raid.", "Error")
			return 
		end

		local bossData = EnemyData.RaidBosses[data.RaidId]
		if not bossData then 
			Network.NotificationEvent:FireClient(player, "Raid Boss data could not be loaded.", "Error")
			return 
		end

		local raidId = "Raid_" .. player.UserId .. "_" .. os.time()
		local memberCount = #partyData.Members
		local scale = 1 + ((memberCount - 1) * 0.3)
		local bMaxHP = math.floor(bossData.Health * scale)

		local ctxRange = "Close"
		if bossData.Name:find("Beast Titan") then ctxRange = "Long" end

		ActiveRaids[raidId] = {
			BossId = data.RaidId, State = "WaitingForMoves", TurnEndTime = os.time() + TURN_DURATION, Party = {},
			Context = { IsRaid = true, Turn = 1, Range = ctxRange, Terrain = "City", Weather = "Clear" },
			Boss = { 
				IsPlayer = false, IsBoss = true, Name = bossData.Name, HP = bMaxHP, MaxHP = bMaxHP, 
				GateHP = bossData.GateHP, MaxGateHP = bossData.GateHP, GateType = bossData.GateType,
				TotalStrength = bossData.Strength, TotalDefense = bossData.Defense, TotalSpeed = bossData.Speed, 
				Skills = bossData.Skills, Statuses = {}, Cooldowns = {} 
			}
		}

		for _, member in ipairs(partyData.Members) do
			member:SetAttribute("InMultiplayerRaid", true)
			table.insert(ActiveRaids[raidId].Party, CreateCombatant(member))
		end
		BroadcastRaidUpdate(ActiveRaids[raidId], "Start", { LogMsg = "<font color='#FF5555'>[MULTIPLAYER RAID: Turn Timer Active]</font>\n" .. bossData.Name .. " blocks your path!" })
	end
end)

Players.PlayerRemoving:Connect(function(player)
	for raidId, raid in pairs(ActiveRaids) do
		for _, p in ipairs(raid.Party) do
			if p.UserId == player.UserId then
				p.HP = 0 
			end
		end
	end
end)