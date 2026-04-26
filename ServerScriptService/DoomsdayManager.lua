-- @ScriptType: ModuleScript
-- @ScriptType: Script
-- Name: DoomsdayManager
local DoomsdayManager = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = ReplicatedStorage:WaitForChild("Network")
local EnemyData = require(ReplicatedStorage:WaitForChild("EnemyData"))
local NotificationEvent = Network:WaitForChild("NotificationEvent")

-- Remotes created by DataManager
local TriggerRumbling = Network:WaitForChild("TriggerRumbling")
local GetDoomsdayData = Network:WaitForChild("GetDoomsdayData")
local GetRumblingData = Network:WaitForChild("GetRumblingData")
local SyncRumbling = Network:WaitForChild("SyncRumbling")

-- [[ DOOMSDAY STATE ]]
local ddActive = false
local ddBoss = nil
local ddMaxHP = 0
local ddCurrentHP = 0
local ddLeaderboard = {}
local ddTimeUntilNext = 3600 

-- [[ RUMBLING STATE ]]
local rumblingActive = false
local rumblingKills = 0
local RUMBLING_TARGET = 1000 
local rumblingLeaderboard = {} 

local function SortLeaderboard(lb)
	table.sort(lb, function(a, b) return a.Damage > b.Damage end)
end

local function PayoutRumbling()
	if #rumblingLeaderboard == 0 then return end
	SortLeaderboard(rumblingLeaderboard)

	NotificationEvent:FireAllClients("THE RUMBLING HAS BEEN HALTED! Top fighters have been rewarded.", "Success")
	for i, data in ipairs(rumblingLeaderboard) do
		local plr = Players:GetPlayerByUserId(data.UserId)
		if plr then
			if i == 1 then
				plr.leaderstats.Dews.Value += 250000
				local attr = "FoundersSandCount"
				plr:SetAttribute(attr, (plr:GetAttribute(attr) or 0) + 3)
				NotificationEvent:FireClient(plr, "Rank 1 Reward: 250K Dews + 3x Founder's Sand!", "Loot")
			elseif i <= 5 then
				plr.leaderstats.Dews.Value += 100000
				local attr = "FoundersSandCount"
				plr:SetAttribute(attr, (plr:GetAttribute(attr) or 0) + 1)
				NotificationEvent:FireClient(plr, "Top 5 Reward: 100K Dews + 1x Founder's Sand!", "Loot")
			else
				plr.leaderstats.Dews.Value += 25000
			end
		end
	end

	rumblingActive = false
	ReplicatedStorage:SetAttribute("RumblingActive", false)
	SyncRumbling:FireAllClients(false)
end

local function PayoutDoomsday()
	if #ddLeaderboard == 0 then return end
	SortLeaderboard(ddLeaderboard)

	for i, data in ipairs(ddLeaderboard) do
		local plr = Players:GetPlayerByUserId(data.UserId)
		if plr then
			local rewardDews = math.floor(data.Damage * 0.5) 
			plr.leaderstats.Dews.Value += rewardDews

			if i == 1 and ddBoss and ddBoss.DropItem then
				local attr = ddBoss.DropItem:gsub("[^%w]", "") .. "Count"
				plr:SetAttribute(attr, (plr:GetAttribute(attr) or 0) + 1)
				NotificationEvent:FireClient(plr, "You dealt the most damage and received the " .. ddBoss.DropItem .. "!", "Loot")
			end
		end
	end
end

function DoomsdayManager.RegisterDamage(player, amount)
	if not ddActive then return end

	ddCurrentHP = math.max(0, ddCurrentHP - amount)

	local found = false
	for _, entry in ipairs(ddLeaderboard) do
		if entry.UserId == player.UserId then
			entry.Damage += amount
			found = true; break
		end
	end
	if not found then
		table.insert(ddLeaderboard, {UserId = player.UserId, Name = player.Name, Damage = amount})
	end

	if ddCurrentHP <= 0 then
		PayoutDoomsday()
		ddActive = false
		ddTimeUntilNext = 3600
	end
end

function DoomsdayManager.RegisterRumblingDamage(player, amount)
	if not rumblingActive then return end

	rumblingKills += 1

	local found = false
	for _, entry in ipairs(rumblingLeaderboard) do
		if entry.UserId == player.UserId then
			entry.Damage += 1 
			found = true; break
		end
	end
	if not found then
		table.insert(rumblingLeaderboard, {UserId = player.UserId, Name = player.Name, Damage = 1})
	end

	if rumblingKills >= RUMBLING_TARGET then
		PayoutRumbling()
	end
end

GetDoomsdayData.OnServerInvoke = function()
	SortLeaderboard(ddLeaderboard)
	return {
		IsActive = ddActive,
		BossName = ddBoss and ddBoss.Name or "None",
		BossHP = ddCurrentHP,
		MaxHP = ddMaxHP,
		Leaderboard = ddLeaderboard,
		TimeUntilNext = ddTimeUntilNext
	}
end

GetRumblingData.OnServerInvoke = function()
	SortLeaderboard(rumblingLeaderboard)
	return {
		IsActive = rumblingActive,
		Kills = rumblingKills,
		Target = RUMBLING_TARGET,
		Leaderboard = rumblingLeaderboard
	}
end

TriggerRumbling.OnServerEvent:Connect(function(player)
	if rumblingActive then
		NotificationEvent:FireClient(player, "The Rumbling is already active!", "Error")
		return
	end

	local safeBone = "FoundersBoneCount"
	local count = tonumber(player:GetAttribute(safeBone)) or 0

	if count >= 1 then
		player:SetAttribute(safeBone, count - 1)

		rumblingActive = true
		rumblingKills = 0
		rumblingLeaderboard = {}
		ReplicatedStorage:SetAttribute("RumblingActive", true)

		-- BROADCAST TO ALL CLIENTS
		SyncRumbling:FireAllClients(true)

		NotificationEvent:FireAllClients(player.Name .. " HAS TRIGGERED THE RUMBLING! RACE TO STOP THE WALL TITANS!", "Error")
	else
		NotificationEvent:FireClient(player, "You need a Founder's Bone to trigger this event.", "Error")
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		if not ddActive then
			ddTimeUntilNext -= 1
			if ddTimeUntilNext <= 0 then
				local bList = {}
				for _, b in pairs(EnemyData.WorldBosses or {}) do 
					if not b.IsRumblingBoss then table.insert(bList, b) end
				end
				if #bList > 0 then
					ddBoss = bList[math.random(1, #bList)]
					ddMaxHP = ddBoss.Health * 50
					ddCurrentHP = ddMaxHP
					ddLeaderboard = {}
					ddActive = true
					NotificationEvent:FireAllClients("DOOMSDAY THREAT DETECTED: " .. string.upper(ddBoss.Name) .. " HAS APPEARED!", "Error")
				end
			end
		end
	end
end)

return DoomsdayManager