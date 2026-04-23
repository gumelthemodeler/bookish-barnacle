-- @ScriptType: ModuleScript
-- @ScriptType: Script
-- Name: DoomsdayManager
local DoomsdayManager = {}

local MessagingService = game:GetService("MessagingService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = ReplicatedStorage:WaitForChild("Network")
local GetDoomsdayData = Network:FindFirstChild("GetDoomsdayData") or Instance.new("RemoteFunction", Network)
GetDoomsdayData.Name = "GetDoomsdayData"
local NotificationEvent = Network:WaitForChild("NotificationEvent")

local BOSS_MAX_HP = 500000000 -- 500 Million HP
local currentBossHP = BOSS_MAX_HP
local damageLeaderboard = {} 

local IsBossActive = false
local BossDuration = 900 -- Active for 15 minutes (900 seconds)
local JobId = game.JobId

-- Batching variables to prevent MessagingService limits
local pendingBroadcastDamage = 0
local pendingLeaderboardUpdates = {}

local function DistributeRewards()
	local sorted = {}
	for uid, data in pairs(damageLeaderboard) do table.insert(sorted, {UserId = uid, Name = data.Name, Damage = data.Damage}) end
	table.sort(sorted, function(a, b) return a.Damage > b.Damage end)

	for rank, data in ipairs(sorted) do
		local p = Players:GetPlayerByUserId(data.UserId)
		if p then
			if rank <= 3 then
				p:SetAttribute("AbyssalBloodCount", (p:GetAttribute("AbyssalBloodCount") or 0) + 3)
				p:SetAttribute("SpinalFluidSyringeCount", (p:GetAttribute("SpinalFluidSyringeCount") or 0) + 5)
				local ls = p:FindFirstChild("leaderstats")
				if ls and ls:FindFirstChild("Dews") then ls.Dews.Value += 5000000 end
				NotificationEvent:FireClient(p, "Doomsday Defeated! Rank " .. rank .. " Rewards: 3x Abyssal Blood, 5x Premium Syringes, 5M Dews!", "Success")
			elseif rank <= 10 then
				p:SetAttribute("AbyssalBloodCount", (p:GetAttribute("AbyssalBloodCount") or 0) + 1)
				p:SetAttribute("SpinalFluidSyringeCount", (p:GetAttribute("SpinalFluidSyringeCount") or 0) + 2)
				local ls = p:FindFirstChild("leaderstats")
				if ls and ls:FindFirstChild("Dews") then ls.Dews.Value += 2000000 end
				NotificationEvent:FireClient(p, "Doomsday Defeated! Rank " .. rank .. " Rewards: 1x Abyssal Blood, 2x Premium Syringes, 2M Dews!", "Success")
			else
				p:SetAttribute("StandardTitanSerumCount", (p:GetAttribute("StandardTitanSerumCount") or 0) + 3)
				local ls = p:FindFirstChild("leaderstats")
				if ls and ls:FindFirstChild("Dews") then ls.Dews.Value += 500000 end
				NotificationEvent:FireClient(p, "Doomsday Defeated! Participation Reward: 3x Titan Serums, 500k Dews!", "Info")
			end
		end
	end
end

local function CheckSchedule()
	local currentTime = os.time()
	local currentHourStart = math.floor(currentTime / 3600) * 3600
	local secondsIntoHour = currentTime - currentHourStart

	if secondsIntoHour < BossDuration then
		if not IsBossActive then
			IsBossActive = true
			currentBossHP = BOSS_MAX_HP
			damageLeaderboard = {}
			pendingBroadcastDamage = 0
			pendingLeaderboardUpdates = {}
			NotificationEvent:FireAllClients("The Primordial Threat has appeared! Deploy via Combat Deployment!", "Error")
		end
	else
		if IsBossActive then
			IsBossActive = false
			NotificationEvent:FireAllClients("The Doomsday Titan has retreated into the steam.", "Info")
		end
	end

	if IsBossActive and currentBossHP <= 0 then
		IsBossActive = false
		DistributeRewards()
		NotificationEvent:FireAllClients("THE DOOMSDAY TITAN HAS BEEN DEFEATED GLOBALLY!", "Success")
	end
end

pcall(function()
	MessagingService:SubscribeAsync("DoomsdaySync", function(message)
		local payload = message.Data
		if payload.ServerId == JobId then return end -- Ignore our own broadcast
		if not IsBossActive then return end

		currentBossHP = math.max(0, currentBossHP - payload.TotalDamage)

		for uidStr, pData in pairs(payload.Players) do
			local uid = tonumber(uidStr)
			if not damageLeaderboard[uid] then damageLeaderboard[uid] = {Name = pData.Name, Damage = 0} end
			damageLeaderboard[uid].Damage += pData.Damage
		end
	end)
end)

function DoomsdayManager.RegisterDamage(player, damage)
	if not IsBossActive or currentBossHP <= 0 then return end

	-- Apply instantly locally
	currentBossHP = math.max(0, currentBossHP - damage)
	if not damageLeaderboard[player.UserId] then
		damageLeaderboard[player.UserId] = {Name = player.Name, Damage = 0}
	end
	damageLeaderboard[player.UserId].Damage += damage

	-- Queue for batch broadcast
	pendingBroadcastDamage += damage
	local uidStr = tostring(player.UserId)
	if not pendingLeaderboardUpdates[uidStr] then pendingLeaderboardUpdates[uidStr] = {Name = player.Name, Damage = 0} end
	pendingLeaderboardUpdates[uidStr].Damage += damage
end

function DoomsdayManager.GetServerData()
	return { IsActive = IsBossActive, BossHP = currentBossHP, MaxHP = BOSS_MAX_HP }
end

GetDoomsdayData.OnServerInvoke = function(player)
	local sortedLeaderboard = {}
	for userId, data in pairs(damageLeaderboard) do
		table.insert(sortedLeaderboard, {Name = data.Name, Damage = data.Damage, UserId = userId})
	end
	table.sort(sortedLeaderboard, function(a, b) return a.Damage > b.Damage end)

	local top100 = {}
	for i = 1, math.min(100, #sortedLeaderboard) do table.insert(top100, sortedLeaderboard[i]) end

	return {
		IsActive = IsBossActive,
		BossHP = currentBossHP,
		MaxHP = BOSS_MAX_HP,
		Leaderboard = top100,
		TimeUntilNext = 3600 - (os.time() % 3600),
		TimeRemaining = BossDuration - (os.time() % 3600)
	}
end

task.spawn(function()
	while task.wait(1) do CheckSchedule() end
end)

task.spawn(function()
	while task.wait(3) do
		if pendingBroadcastDamage > 0 and IsBossActive then
			local payload = {
				ServerId = JobId,
				TotalDamage = pendingBroadcastDamage,
				Players = pendingLeaderboardUpdates
			}
			pendingBroadcastDamage = 0
			pendingLeaderboardUpdates = {}
			pcall(function() MessagingService:PublishAsync("DoomsdaySync", payload) end)
		end
	end
end)

return DoomsdayManager