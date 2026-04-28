-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
-- @ScriptType: Script
-- Name: DoomsdayManager
local DoomsdayManager = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BadgeService = game:GetService("BadgeService")
local Network = ReplicatedStorage:WaitForChild("Network")
local EnemyData = require(ReplicatedStorage:WaitForChild("EnemyData"))
local NotificationEvent = Network:WaitForChild("NotificationEvent")

local EVENT_BADGE_ID = 1866183828416372

local TriggerRumbling = Network:WaitForChild("TriggerRumbling")
local GetDoomsdayData = Network:WaitForChild("GetDoomsdayData")
local GetRumblingData = Network:WaitForChild("GetRumblingData")
local SyncRumbling = Network:WaitForChild("SyncRumbling")

local EVENT_EXPIRATION_DATE = os.time({year = 2026, month = 5, day = 5, hour = 3, min = 20, sec = 0})
local EVENT_ACTIVE = (os.time() < EVENT_EXPIRATION_DATE) 

local EVENT_STAT_REQUIREMENT = 250 
local EVENT_BOSS_DATA = {
	Name = "The World Titan",
	IsBoss = true,
	IsDoomsdayBoss = false,
	Health = 4500, 
	GateType = "Stand Aura",
	GateHP = 1000,
	Strength = 400,
	Defense = 300,
	Speed = 250,
	Resolve = 800,
	TitanStats = {Power="S", Speed="S", Hardening="C", Endurance="B", Precision="S", Potential="S"},
	Skills = {"Muda Barrage", "Time Stop", "Road Roller Crush", "Vampiric Strike"},
	Drops = { XP = 15000, Dews = 3500, ItemChance = { ["Vampire Titan Blood"] = 100, ["Stone Mask Fragment"] = 5 } },
	DropItem = "The World's Stopwatch"
}

local ddActive = false
local ddBoss = nil
local ddMaxHP = 0
local ddCurrentHP = 0
local ddLeaderboard = {}
local ddTimeUntilNext = 10 

local rumblingActive = false
local rumblingKills = 0
local RUMBLING_TARGET = 1000 
local rumblingLeaderboard = {} 
local rumblingTimeLeft = 600

local function SortLeaderboard(lb)
	table.sort(lb, function(a, b) return a.Damage > b.Damage end)
end

local function PayoutRumbling()
	if not rumblingActive then return end 

	rumblingActive = false
	ReplicatedStorage:SetAttribute("RumblingActive", false)
	SyncRumbling:FireAllClients(false)

	if #rumblingLeaderboard == 0 then 
		NotificationEvent:FireAllClients("THE RUMBLING SURVIVED... No heroes deployed in time.", "Error")
		return 
	end

	SortLeaderboard(rumblingLeaderboard)

	if rumblingKills >= RUMBLING_TARGET then
		NotificationEvent:FireAllClients("THE RUMBLING HAS BEEN HALTED! Top fighters have been rewarded.", "Success")
	else
		NotificationEvent:FireAllClients("TIME EXPIRED! The Wall Titans trampled the continent. Partial rewards distributed.", "Error")
	end

	for i, data in ipairs(rumblingLeaderboard) do
		local plr = Players:GetPlayerByUserId(data.UserId)
		if plr then
			if i == 1 then
				plr.leaderstats.Dews.Value += 250000
				plr:SetAttribute("CoordinatesSandCount", (plr:GetAttribute("CoordinatesSandCount") or 0) + 1)
				plr:SetAttribute("AbyssalBloodCount", (plr:GetAttribute("AbyssalBloodCount") or 0) + 5)
				NotificationEvent:FireClient(plr, "Rank 1 Reward: 250K Dews, 1x Coordinate's Sand, 5x Abyssal Blood!", "Loot")
			elseif i <= 5 then
				plr.leaderstats.Dews.Value += 100000
				plr:SetAttribute("YmirsClayFragmentCount", (plr:GetAttribute("YmirsClayFragmentCount") or 0) + 2)
				plr:SetAttribute("SpinalFluidSyringeCount", (plr:GetAttribute("SpinalFluidSyringeCount") or 0) + 1)
				NotificationEvent:FireClient(plr, "Top 5 Reward: 100K Dews, 2x Ymir's Clay Fragment, 1x Spinal Fluid Syringe!", "Loot")
			elseif i <= 20 then
				plr.leaderstats.Dews.Value += 50000
				plr:SetAttribute("SpinalFluidSyringeCount", (plr:GetAttribute("SpinalFluidSyringeCount") or 0) + 1)
				NotificationEvent:FireClient(plr, "Top 20 Reward: 50K Dews, 1x Spinal Fluid Syringe!", "Loot")
			else
				plr.leaderstats.Dews.Value += 25000
				NotificationEvent:FireClient(plr, "Participant Reward: 25,000 Dews!", "Loot")
			end
		end
	end
end

local function PayoutDoomsday()
	if #ddLeaderboard == 0 then return end
	SortLeaderboard(ddLeaderboard)

	local isEventBoss = ddBoss and ddBoss.Name == EVENT_BOSS_DATA.Name

	for i, data in ipairs(ddLeaderboard) do
		local plr = Players:GetPlayerByUserId(data.UserId)
		if plr then
			local rewardDews = math.floor(data.Damage * 0.5) 
			plr.leaderstats.Dews.Value += rewardDews

			if not isEventBoss and i == 1 and ddBoss and ddBoss.DropItem then
				local attr = ddBoss.DropItem:gsub("[^%w]", "") .. "Count"
				plr:SetAttribute(attr, (plr:GetAttribute(attr) or 0) + 1)
				NotificationEvent:FireClient(plr, "You dealt the most damage and received the " .. ddBoss.DropItem .. "!", "Loot")
			end

			if isEventBoss then
				task.spawn(function()
					pcall(function()
						if not BadgeService:UserHasBadgeAsync(plr.UserId, EVENT_BADGE_ID) then
							BadgeService:AwardBadgeAsync(plr.UserId, EVENT_BADGE_ID)
						end
					end)
				end)

				if not plr:GetAttribute("Ach_Defeat_WorldTitan") then
					plr:SetAttribute("Ach_Defeat_WorldTitan", true)
					NotificationEvent:FireClient(plr, "Event Reward: 'Stardust Crusader' Title Unlocked!", "Success")
				end

				plr:SetAttribute("VampireTitanBloodCount", (plr:GetAttribute("VampireTitanBloodCount") or 0) + 3)
				NotificationEvent:FireClient(plr, "Global Event Reward: 3x Vampire Titan Blood!", "Success")

				if i <= 3 then
					plr:SetAttribute("StoneMaskFragmentCount", (plr:GetAttribute("StoneMaskFragmentCount") or 0) + 1)
					NotificationEvent:FireClient(plr, "Global Top 3 Event Reward: 1x Stone Mask Fragment!", "Loot")
				end

				if i == 1 then
					local hasStopwatch = (plr:GetAttribute("TheWorldsStopwatchCount") or 0) > 0
					if not hasStopwatch then
						plr:SetAttribute("TheWorldsStopwatchCount", 1)
						NotificationEvent:FireClient(plr, "Global Rank 1 Reward: The World's Stopwatch obtained!", "Loot")
					end

					plr:SetAttribute("StandArrowHeadCount", (plr:GetAttribute("StandArrowHeadCount") or 0) + 1)
					NotificationEvent:FireClient(plr, "Global Rank 1 Reward: 1x Stand Arrow Head!", "Loot")
				end
			end
		end
	end
end

function DoomsdayManager.RegisterDamage(player, amount)
	if not ddActive then return end

	if ddBoss and ddBoss.Name == EVENT_BOSS_DATA.Name then
		local pStr = tonumber(player:GetAttribute("Strength")) or 10
		local pDef = tonumber(player:GetAttribute("Defense")) or 10
		local pSpd = tonumber(player:GetAttribute("Speed")) or 10
		local pRes = tonumber(player:GetAttribute("Resolve")) or 10
		local totalStats = pStr + pDef + pSpd + pRes

		if totalStats < EVENT_STAT_REQUIREMENT then
			NotificationEvent:FireClient(player, "You lack the strength to pierce The World Titan's armor! (Total Stats required: " .. EVENT_STAT_REQUIREMENT .. ")", "Error")
			return
		end
	end

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

		if EVENT_ACTIVE then
			ddCurrentHP = ddMaxHP
			ddLeaderboard = {}
			NotificationEvent:FireAllClients("THE WORLD TITAN HAS REGENERATED! THE TIME STOP CONTINUES!", "Error")
		else
			ddActive = false
			ddTimeUntilNext = 3600
		end
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
	EVENT_ACTIVE = (os.time() < EVENT_EXPIRATION_DATE) 

	return {
		IsActive = ddActive,
		BossName = ddBoss and ddBoss.Name or "None",
		BossHP = ddCurrentHP,
		MaxHP = ddMaxHP,
		Leaderboard = ddLeaderboard,
		TimeUntilNext = ddTimeUntilNext,
		EventActive = EVENT_ACTIVE,
		EventEndTime = EVENT_EXPIRATION_DATE
	}
end

GetRumblingData.OnServerInvoke = function()
	SortLeaderboard(rumblingLeaderboard)
	return {
		IsActive = rumblingActive,
		Kills = rumblingKills,
		Target = RUMBLING_TARGET,
		TimeLeft = rumblingTimeLeft,
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
		rumblingTimeLeft = 600
		rumblingLeaderboard = {}
		ReplicatedStorage:SetAttribute("RumblingActive", true)

		SyncRumbling:FireAllClients(true)

		NotificationEvent:FireAllClients(string.upper(player.Name) .. " HAS TRIGGERED THE RUMBLING! RACE TO STOP THE WALL TITANS!", "Error")
	else
		NotificationEvent:FireClient(player, "You need a Founder's Bone to trigger this event.", "Error")
	end
end)

function DoomsdayManager.GetActiveBoss()
	if not ddActive then return nil end
	return ddBoss
end

task.spawn(function()
	while true do
		task.wait(1)

		EVENT_ACTIVE = (os.time() < EVENT_EXPIRATION_DATE)

		if rumblingActive then
			rumblingTimeLeft -= 1
			if rumblingTimeLeft <= 0 or rumblingKills >= RUMBLING_TARGET then
				PayoutRumbling()
			end
		end

		if EVENT_ACTIVE then
			if not ddActive or (ddBoss and ddBoss.Name ~= EVENT_BOSS_DATA.Name) then
				ddBoss = EVENT_BOSS_DATA
				ddMaxHP = ddBoss.Health * 50
				ddCurrentHP = ddMaxHP
				ddLeaderboard = {}
				ddActive = true
				NotificationEvent:FireAllClients("ZA WARUDO! THE WORLD TITAN HAS STOPPED TIME! (Lv. Requirement: " .. EVENT_STAT_REQUIREMENT .. " Stats)", "Error")
			end
		else
			if ddBoss and ddBoss.Name == EVENT_BOSS_DATA.Name then
				ddActive = false
				ddBoss = nil
				ddTimeUntilNext = 3600
				NotificationEvent:FireAllClients("Time has resumed... The World Titan vanished.", "Success")
			end

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
	end
end)

return DoomsdayManager