-- @ScriptType: Script
-- @ScriptType: Script
-- Name: PVPManager
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Network = ReplicatedStorage:WaitForChild("Network")

local PvPAction = Network:FindFirstChild("PvPAction") or Instance.new("RemoteEvent", Network); PvPAction.Name = "PvPAction"
local PvPUpdate = Network:FindFirstChild("PvPUpdate") or Instance.new("RemoteEvent", Network); PvPUpdate.Name = "PvPUpdate"
local PvPTaunt = Network:FindFirstChild("PvPTaunt") or Instance.new("RemoteEvent", Network); PvPTaunt.Name = "PvPTaunt"
local GetLiveMatches = Network:FindFirstChild("GetLiveMatches") or Instance.new("RemoteFunction", Network); GetLiveMatches.Name = "GetLiveMatches"

local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))
local SkillData = require(ReplicatedStorage:WaitForChild("SkillData"))
local CombatCore = require(script.Parent:WaitForChild("CombatCore"))

local hasPartyMgr, PartyManager = pcall(function() return require(script.Parent:WaitForChild("PartyManager")) end)

local ActiveMatches = {}
local PvPQueue = {} 
local MatchCounter = 0
local TURN_DURATION = 15 

local function CreatePvPCombatant(player)
	local wpnName = player:GetAttribute("EquippedWeapon") or "None"
	local accName = player:GetAttribute("EquippedAccessory") or "None"

	local wpnBonus = (ItemData.Equipment and ItemData.Equipment[wpnName] and ItemData.Equipment[wpnName].Bonus) or {}
	local accBonus = (ItemData.Equipment and ItemData.Equipment[accName] and ItemData.Equipment[accName].Bonus) or {}
	local wpnStyle = (ItemData.Equipment and ItemData.Equipment[wpnName] and ItemData.Equipment[wpnName].Style) or "None"

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

	local pMaxHP = ((player:GetAttribute("Health") or 10) + (wpnBonus.Health or 0) + (accBonus.Health or 0)) * 10
	pMaxHP = pMaxHP + awakenedStats.HpBonus

	local pMaxGas = ((player:GetAttribute("Gas") or 10) + (wpnBonus.Gas or 0) + (accBonus.Gas or 0)) * 10
	pMaxGas = pMaxGas + awakenedStats.GasBonus

	return {
		IsPlayer = true, Name = player.Name, PlayerObj = player,
		Clan = player:GetAttribute("Clan") or "None", Titan = player:GetAttribute("Titan") or "None",
		Style = wpnStyle,
		HP = pMaxHP, MaxHP = pMaxHP, Gas = pMaxGas, MaxGas = pMaxGas,
		TitanEnergy = 100, MaxTitanEnergy = 100,
		TotalStrength = (player:GetAttribute("Strength") or 10) + (wpnBonus.Strength or 0) + (accBonus.Strength or 0),
		TotalDefense = (player:GetAttribute("Defense") or 10) + (wpnBonus.Defense or 0) + (accBonus.Defense or 0),
		TotalSpeed = (player:GetAttribute("Speed") or 10) + (wpnBonus.Speed or 0) + (accBonus.Speed or 0) + awakenedStats.SpdBonus,
		TotalResolve = (player:GetAttribute("Resolve") or 10) + (wpnBonus.Resolve or 0) + (accBonus.Resolve or 0),
		Statuses = {}, Cooldowns = {}, LastSkill = "None", AwakenedStats = awakenedStats, ResolveSurvivals = 0,
		Moves = {}, TargetLimbs = {}, TargetPlayers = {},
		LimbDamage = { Legs = 0, Arms = 0, Gear = 0, Head = 0 }
	}
end

local function EndMatch(matchId, winnerTeam)
	local match = ActiveMatches[matchId]
	if not match then return end

	local winningPlayers = (winnerTeam == "Team1") and match.Team1 or match.Team2
	local losingPlayers = (winnerTeam == "Team1") and match.Team2 or match.Team1

	if winnerTeam ~= "Draw" then
		for _, combatant in ipairs(winningPlayers) do
			if combatant.IsPlayer then
				local p = combatant.PlayerObj
				if p and p.Parent and p:FindFirstChild("leaderstats") then
					local elo = p.leaderstats:FindFirstChild("Elo")
					if elo then elo.Value = elo.Value + (match.Is3v3 and 35 or 25) end

					p.leaderstats.Dews.Value += (match.Is3v3 and 1000 or 500)
					p:SetAttribute("XP", (p:GetAttribute("XP") or 0) + (match.Is3v3 and 1000 or 500))

					Network.NotificationEvent:FireClient(p, "Victory! Rank increased.", "Success")
				end
			end
		end

		for _, combatant in ipairs(losingPlayers) do
			if combatant.IsPlayer then
				local p = combatant.PlayerObj
				if p and p.Parent and p:FindFirstChild("leaderstats") then
					local elo = p.leaderstats:FindFirstChild("Elo")
					if elo then elo.Value = math.max(100, elo.Value - (match.Is3v3 and 20 or 15)) end
					Network.NotificationEvent:FireClient(p, "Defeat. Rank decreased.", "Error")
				end
			end
		end

		local t1LeaderId = match.Team1[1].PlayerObj.UserId
		local t2LeaderId = match.Team2[1].PlayerObj.UserId

		local winnerPot = 0; local loserPot = 0
		local winningBets = (winnerTeam == "Team1") and (match.Bets[t1LeaderId] or {}) or (match.Bets[t2LeaderId] or {})
		local losingBets = (winnerTeam == "Team1") and (match.Bets[t2LeaderId] or {}) or (match.Bets[t1LeaderId] or {})

		for _, b in pairs(winningBets) do winnerPot += b.Amount end
		for _, b in pairs(losingBets) do loserPot += b.Amount end

		for _, betData in pairs(winningBets) do
			local spectator = betData.Spectator
			if spectator and spectator.Parent then
				local share = betData.Amount / winnerPot
				local profit = math.floor(loserPot * share)
				local payout = betData.Amount + profit
				spectator.leaderstats.Dews.Value += payout
				Network.NotificationEvent:FireClient(spectator, "You won " .. payout .. " Dews! (Profit: +" .. profit .. ")", "Success")
			end
		end
	else
		for _, team in ipairs({match.Team1, match.Team2}) do
			for _, c in ipairs(team) do
				if c.IsPlayer and c.PlayerObj and c.PlayerObj.Parent then Network.NotificationEvent:FireClient(c.PlayerObj, "Draw! No Elo lost.", "Info") end
			end
		end
	end

	ActiveMatches[matchId] = nil
	PvPUpdate:FireAllClients("MatchEnded", matchId, winnerTeam)
end

local function StartMatch(team1Players, team2Players, is3v3)
	MatchCounter += 1
	local matchId = "Match_" .. MatchCounter

	local team1Combatants = {}
	local team2Combatants = {}
	local t1Ids = {}
	local t2Ids = {}

	for _, p in ipairs(team1Players) do table.insert(team1Combatants, CreatePvPCombatant(p)); table.insert(t1Ids, p.UserId) end
	for _, p in ipairs(team2Players) do table.insert(team2Combatants, CreatePvPCombatant(p)); table.insert(t2Ids, p.UserId) end

	print("[PvPManager] MATCH STARTED: T1 VS T2 | ID: " .. matchId .. " | 3v3: " .. tostring(is3v3))

	ActiveMatches[matchId] = {
		Is3v3 = is3v3,
		Team1 = team1Combatants,
		Team2 = team2Combatants,
		Turn = 1, State = "WaitingForMoves",
		TurnEndTime = os.time() + TURN_DURATION, 
		Bets = { [team1Players[1].UserId] = {}, [team2Players[1].UserId] = {} }
	}

	local p1 = team1Players[1]; local p2 = team2Players[1]
	PvPUpdate:FireAllClients("MatchStarted", matchId, p1.Name, p2.Name, p1.UserId, p2.UserId, ActiveMatches[matchId].TurnEndTime, is3v3, t1Ids, t2Ids)
end

task.spawn(function()
	while task.wait(2) do
		local i = 1
		while i <= #PvPQueue do
			local q1 = PvPQueue[i]
			local matched = false
			local waitTime1 = os.time() - q1.JoinTime
			local eloRange = 150 + (math.floor(waitTime1 / 3) * 100) 

			for j = i + 1, #PvPQueue do
				local q2 = PvPQueue[j]
				if math.abs(q1.Elo - q2.Elo) <= eloRange and q1.IsParty == q2.IsParty then
					if q1.IsParty then
						table.remove(PvPQueue, j); table.remove(PvPQueue, i)
						StartMatch(q1.Players, q2.Players, true)
					else
						table.remove(PvPQueue, j); table.remove(PvPQueue, i)
						StartMatch({q1.Player}, {q2.Player}, false)
					end
					matched = true
					break
				end
			end
			if not matched then i += 1 end
		end
	end
end)

local function GetCombatantByName(match, name)
	for _, c in ipairs(match.Team1) do if c.Name == name then return c end end
	for _, c in ipairs(match.Team2) do if c.Name == name then return c end end
	return nil
end

local function ResolveTurn(matchId)
	local match = ActiveMatches[matchId]
	if not match then return end
	if match.State == "Resolving" then return end 
	match.State = "Resolving"

	local function TickStatuses(combatant)
		if not combatant.Statuses then return end
		if combatant.Statuses["Bleed"] then combatant.HP -= math.min(combatant.MaxHP * 0.05, 500) end
		if combatant.Statuses["Burn"] then combatant.HP -= math.min(combatant.MaxHP * 0.05, 600) end
		for sName, dur in pairs(combatant.Statuses) do
			if type(dur) == "number" and sName ~= "Transformed" then
				combatant.Statuses[sName] = dur - 1
				if combatant.Statuses[sName] <= 0 then combatant.Statuses[sName] = nil end
			end
		end
	end

	local function EvaluateLimbDamage(defender, targetLimb, damage)
		if targetLimb == "Body" then return end
		defender.LimbDamage[targetLimb] = (defender.LimbDamage[targetLimb] or 0) + damage
		local maxHp = defender.MaxHP

		if targetLimb == "Legs" and defender.LimbDamage.Legs >= maxHp * 0.20 then
			defender.Statuses["Crippled"] = 1
			defender.LimbDamage.Legs = 0
		elseif targetLimb == "Arms" and defender.LimbDamage.Arms >= maxHp * 0.20 then
			defender.Statuses["Weakened"] = 1
			defender.LimbDamage.Arms = 0
		elseif targetLimb == "Gear" and defender.LimbDamage.Gear >= maxHp * 0.15 then
			defender.Gas = math.max(0, defender.Gas - (defender.MaxGas * 0.20))
			defender.LimbDamage.Gear = 0
		end
	end

	local function ProcessStrike(attacker, defender, skillName, targetLimb)
		if attacker.HP <= 0 or defender.HP <= 0 then return end

		local skill = SkillData.Skills[skillName]
		if skill then
			if skill.GasCost then attacker.Gas = math.max(0, attacker.Gas - skill.GasCost) end
			if skill.EnergyCost then attacker.TitanEnergy = math.max(0, attacker.TitanEnergy - skill.EnergyCost) end
			if skill.Effect == "Rest" or skillName == "Recover" then attacker.Gas = math.min(attacker.MaxGas, attacker.Gas + (attacker.MaxGas * 0.40)) end
		end

		local logMsg, didHit, shakeType, rawDamage
		if type(CombatCore.ExecutePvPStrike) == "function" then
			logMsg, didHit, shakeType, rawDamage = CombatCore.ExecutePvPStrike(attacker, defender, skillName, targetLimb, 1.0)
		else
			logMsg, didHit, shakeType = CombatCore.ExecuteStrike(attacker, defender, skillName, targetLimb, attacker.Name, defender.Name, "#55FF55", "#FF5555")
			rawDamage = 100 
		end

		if didHit and rawDamage and rawDamage > 0 then
			EvaluateLimbDamage(defender, targetLimb, rawDamage)
		end

		local cData = {
			LogMsg = logMsg, DidHit = didHit, ShakeType = shakeType, SkillUsed = skillName, 
			Attacker = attacker.Name, Defender = defender.Name, TargetLimb = targetLimb,
			T1_States = {}, T2_States = {}
		}

		for _, c in ipairs(match.Team1) do table.insert(cData.T1_States, {Name = c.Name, HP = c.HP, MaxHP = c.MaxHP, Gas = c.Gas, MaxGas = c.MaxGas, Statuses = c.Statuses}) end
		for _, c in ipairs(match.Team2) do table.insert(cData.T2_States, {Name = c.Name, HP = c.HP, MaxHP = c.MaxHP, Gas = c.Gas, MaxGas = c.MaxGas, Statuses = c.Statuses}) end

		PvPUpdate:FireAllClients("TurnStrike", matchId, cData)
		task.wait(0.5) 
	end

	local activeT1 = {}; for _, c in ipairs(match.Team1) do if c.HP > 0 then table.insert(activeT1, c) end end
	local activeT2 = {}; for _, c in ipairs(match.Team2) do if c.HP > 0 then table.insert(activeT2, c) end end

	if #activeT1 > 0 and #activeT2 > 0 then
		local clashActions = {}
		for _, c in ipairs(activeT1) do
			local cSpd = c.TotalSpeed + math.random(1, 15); if c.Statuses and c.Statuses["Crippled"] then cSpd *= 0.5 end
			table.insert(clashActions, {Attacker = c, Spd = cSpd, Move = c.Moves[1] or "Basic Slash", Limb = c.TargetLimbs[1] or "Body", Target = c.TargetPlayers[1] or activeT2[1].Name})
		end
		for _, c in ipairs(activeT2) do
			local cSpd = c.TotalSpeed + math.random(1, 15); if c.Statuses and c.Statuses["Crippled"] then cSpd *= 0.5 end
			table.insert(clashActions, {Attacker = c, Spd = cSpd, Move = c.Moves[1] or "Basic Slash", Limb = c.TargetLimbs[1] or "Body", Target = c.TargetPlayers[1] or activeT1[1].Name})
		end

		table.sort(clashActions, function(a, b) return a.Spd > b.Spd end)

		for _, action in ipairs(clashActions) do
			if action.Attacker.HP > 0 then
				local defender = GetCombatantByName(match, action.Target)

				local sData = SkillData.Skills[action.Move]
				if sData and sData.PvPSupport then
					if sData.PvPSupport == "Supply Drop" and defender then
						defender.Gas = math.min(defender.MaxGas, defender.Gas + 30)
						PvPUpdate:FireAllClients("TurnStrike", matchId, {LogMsg = action.Attacker.Name .. " supplied " .. defender.Name .. " with Gas!", ShakeType = "None"})
						task.wait(0.5)
						continue
					end
				end

				if defender and defender.HP > 0 then
					ProcessStrike(action.Attacker, defender, action.Move, action.Limb)
				end
			end
		end
	end

	local finalT1 = 0; for _, c in ipairs(match.Team1) do TickStatuses(c); if c.HP > 0 then finalT1 += 1 end end
	local finalT2 = 0; for _, c in ipairs(match.Team2) do TickStatuses(c); if c.HP > 0 then finalT2 += 1 end end

	if finalT1 == 0 and finalT2 == 0 then EndMatch(matchId, "Draw"); return
	elseif finalT1 == 0 then EndMatch(matchId, "Team2"); return
	elseif finalT2 == 0 then EndMatch(matchId, "Team1"); return end

	match.Turn += 1
	for _, c in ipairs(match.Team1) do c.Moves = {}; c.TargetLimbs = {}; c.TargetPlayers = {} end
	for _, c in ipairs(match.Team2) do c.Moves = {}; c.TargetLimbs = {}; c.TargetPlayers = {} end

	match.State = "WaitingForMoves"
	match.TurnEndTime = os.time() + TURN_DURATION 
	PvPUpdate:FireAllClients("NextTurnStarted", matchId, match.Turn, match.TurnEndTime)
end

task.spawn(function()
	while task.wait(1) do
		local now = os.time()
		for matchId, match in pairs(ActiveMatches) do
			if match.State == "WaitingForMoves" and now >= match.TurnEndTime then
				local function GetFallbackMove(combatant)
					if combatant.Statuses and combatant.Statuses["Transformed"] then return "Titan Punch" end
					return "Basic Slash"
				end

				local function GetRandomEnemy(teamArray)
					local alive = {}
					for _, c in ipairs(teamArray) do if c.HP > 0 then table.insert(alive, c.Name) end end
					return #alive > 0 and alive[math.random(1, #alive)] or teamArray[1].Name
				end

				for _, c in ipairs(match.Team1) do
					if not c.Moves[1] then c.Moves[1] = GetFallbackMove(c); c.TargetLimbs[1] = "Body"; c.TargetPlayers[1] = GetRandomEnemy(match.Team2) end
				end
				for _, c in ipairs(match.Team2) do
					if not c.Moves[1] then c.Moves[1] = GetFallbackMove(c); c.TargetLimbs[1] = "Body"; c.TargetPlayers[1] = GetRandomEnemy(match.Team1) end
				end

				ResolveTurn(matchId)
			end
		end
	end
end)

-- The missing server hook to let players view live matches!
GetLiveMatches.OnServerInvoke = function(player)
	local activeList = {}
	for mId, mData in pairs(ActiveMatches) do
		table.insert(activeList, {
			MatchId = mId,
			Player1 = mData.Team1[1] and mData.Team1[1].Name or "Unknown",
			Player2 = mData.Team2[1] and mData.Team2[1].Name or "Unknown"
		})
	end
	return activeList
end

PvPAction.OnServerEvent:Connect(function(player, actionType, matchId, data1, data2)
	if actionType == "JoinQueue" then
		local myParty = nil
		if hasPartyMgr and PartyManager then myParty = PartyManager.GetParty(player) end

		if myParty and #myParty.Members > 1 then
			if myParty.Leader ~= player then return end 

			local partyElo = 0
			local validPlayers = {}
			for _, member in ipairs(myParty.Members) do
				local pObj = Players:GetPlayerByUserId(member.UserId)
				if pObj then
					table.insert(validPlayers, pObj)
					partyElo += pObj:FindFirstChild("leaderstats") and pObj.leaderstats:FindFirstChild("Elo") and pObj.leaderstats.Elo.Value or 1000
				end
			end
			partyElo = math.floor(partyElo / #validPlayers)
			table.insert(PvPQueue, {IsParty = true, Players = validPlayers, Elo = partyElo, JoinTime = os.time()})
			Network.NotificationEvent:FireClient(player, "Party entered Ranked Matchmaking...", "System")
		else
			local pElo = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Elo") and player.leaderstats.Elo.Value or 1000
			table.insert(PvPQueue, {IsParty = false, Player = player, Elo = pElo, JoinTime = os.time()})
			Network.NotificationEvent:FireClient(player, "Entered Ranked Matchmaking...", "System")
		end
		return
	elseif actionType == "LeaveQueue" then
		for i, qp in ipairs(PvPQueue) do 
			if (qp.IsParty and qp.Players[1] == player) or (not qp.IsParty and qp.Player == player) then 
				table.remove(PvPQueue, i); break 
			end 
		end
		Network.NotificationEvent:FireClient(player, "Left Matchmaking Queue.", "System")
		return
	end

	if actionType == "SpectateMatch" then
		local mId = matchId 
		local match = ActiveMatches[mId]
		if match then
			PvPUpdate:FireClient(player, "SpectateStarted", mId, match.Team1[1].Name, match.Team2[1].Name, match.Team1[1].PlayerObj.UserId, match.Team2[1].PlayerObj.UserId, match.TurnEndTime, match.Team1[1].HP, match.Team1[1].MaxHP, match.Team2[1].HP, match.Team2[1].MaxHP)
		end
		return
	end

	local match = ActiveMatches[matchId]
	if not match then return end

	if actionType == "Surrender" then
		local surrenderer = GetCombatantByName(match, player.Name)
		if surrenderer then
			surrenderer.HP = 0

			local cData = {LogMsg = "<font color='#FFAA00'><b>" .. player.Name .. " surrendered!</b></font>", ShakeType = "None", T1_States = {}, T2_States = {}}
			for _, c in ipairs(match.Team1) do table.insert(cData.T1_States, {Name = c.Name, HP = c.HP, MaxHP = c.MaxHP, Gas = c.Gas, MaxGas = c.MaxGas, Statuses = c.Statuses}) end
			for _, c in ipairs(match.Team2) do table.insert(cData.T2_States, {Name = c.Name, HP = c.HP, MaxHP = c.MaxHP, Gas = c.Gas, MaxGas = c.MaxGas, Statuses = c.Statuses}) end

			PvPUpdate:FireAllClients("TurnStrike", matchId, cData)

			if not match.Is3v3 then
				local winner = (surrenderer == match.Team1[1]) and "Team2" or "Team1"
				EndMatch(matchId, winner)
			else
				ResolveTurn(matchId)
			end
		end
		return
	end

	if actionType == "SubmitMoveSequence" and match.State == "WaitingForMoves" then
		local moveData = data1 
		local c = GetCombatantByName(match, player.Name)

		if c and type(moveData) == "table" then
			c.Moves = {}; c.TargetLimbs = {}; c.TargetPlayers = {}

			local isTeam1 = false
			for _, tc in ipairs(match.Team1) do if tc == c then isTeam1 = true break end end

			local function GetRandomEnemy()
				local enemies = isTeam1 and match.Team2 or match.Team1
				local alive = {}
				for _, ec in ipairs(enemies) do if ec.HP > 0 then table.insert(alive, ec.Name) end end
				return #alive > 0 and alive[math.random(1, #alive)] or enemies[1].Name
			end

			local md = moveData[1]
			if md and (SkillData.Skills[md.Move] or md.Move == "Recover" or md.Move == "Transform" or md.Move == "Maneuver" or md.Move == "Advance" or md.Move == "Close In" or md.Move == "Fall Back" or md.Move == "Eject" or md.Move == "Titan Recover") then
				table.insert(c.Moves, md.Move)
				table.insert(c.TargetLimbs, md.Limb or "Body")
				table.insert(c.TargetPlayers, md.Target or GetRandomEnemy())
			else
				table.insert(c.Moves, "Basic Slash")
				table.insert(c.TargetLimbs, "Body")
				table.insert(c.TargetPlayers, GetRandomEnemy())
			end

			local allReady = true
			for _, tc in ipairs(match.Team1) do if tc.HP > 0 and #tc.Moves < 1 then allReady = false break end end
			for _, tc in ipairs(match.Team2) do if tc.HP > 0 and #tc.Moves < 1 then allReady = false break end end

			if allReady then ResolveTurn(matchId) end
		end
	elseif actionType == "PlaceBet" and match.State == "WaitingForMoves" then
		local targetUserId = data1
		local betAmount = data2
		if player.leaderstats.Dews.Value >= betAmount and betAmount > 0 then
			player.leaderstats.Dews.Value -= betAmount
			table.insert(match.Bets[targetUserId], { Spectator = player, Amount = betAmount })
			Network.NotificationEvent:FireClient(player, "Wager locked in!", "Success")
		else
			Network.NotificationEvent:FireClient(player, "Not enough Dews!", "Error")
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	for i, qp in ipairs(PvPQueue) do
		if (qp.IsParty and qp.Players[1] == player) or (not qp.IsParty and qp.Player == player) then 
			table.remove(PvPQueue, i); break 
		end
	end

	for matchId, match in pairs(ActiveMatches) do
		local c = GetCombatantByName(match, player.Name)
		if c then
			c.HP = 0
			if not match.Is3v3 then
				local winner = (c == match.Team1[1]) and "Team2" or "Team1"
				EndMatch(matchId, winner)
			else
				ResolveTurn(matchId)
			end
		end
	end
end)