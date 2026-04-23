-- @ScriptType: Script
-- @ScriptType: Script
-- Name: SquadManager
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")

local SquadStore = DataStoreService:GetDataStore("StrikeSquads_V2")

local SECONDS_IN_WEEK = 604800
local SUNDAY_OFFSET = 259200 
local currentSeasonWeek = math.floor((os.time() + SUNDAY_OFFSET) / SECONDS_IN_WEEK)
local SquadLeaderboard = DataStoreService:GetOrderedDataStore("Global_Squad_SP_Season_" .. currentSeasonWeek)

local Network = ReplicatedStorage:WaitForChild("Network")
local SquadAction = Network:FindFirstChild("SquadAction") or Instance.new("RemoteEvent", Network)
SquadAction.Name = "SquadAction"
local NotificationEvent = Network:WaitForChild("NotificationEvent")

local AddSquadSP = Network:FindFirstChild("AddSquadSP") or Instance.new("BindableEvent", Network)
AddSquadSP.Name = "AddSquadSP"

local GetPublicSquads = Instance.new("RemoteFunction", Network); GetPublicSquads.Name = "GetPublicSquads"
local GetSquadRoster = Instance.new("RemoteFunction", Network); GetSquadRoster.Name = "GetSquadRoster"
local GetSquadLeaderboard = Instance.new("RemoteFunction", Network); GetSquadLeaderboard.Name = "GetSquadLeaderboard"
local GetSquadRequests = Instance.new("RemoteFunction", Network); GetSquadRequests.Name = "GetSquadRequests"

local ActiveSquads = {}
local GlobalSquadCache = {}
local isFetchingCache = false

local currentTopSquadName = nil 
local Top5SquadsCache = {}

local function SaveSquadData(squadName, data)
	data.Season = currentSeasonWeek
	pcall(function() SquadStore:SetAsync(squadName, data); SquadLeaderboard:SetAsync(squadName, data.SP or 0) end)
end

local function UpdateOnlineMembers(sqName)
	local sqData = ActiveSquads[sqName]
	if not sqData then return end
	local vaultStr = HttpService:JSONEncode(sqData.Vault or {"None","None","None","None","None","None","None","None","None"})
	local isFavored = (sqName == currentTopSquadName)
	local isTop5 = Top5SquadsCache[sqName] or false

	local upgradesStr = HttpService:JSONEncode(sqData.Upgrades or {Capacity=0, Wealth=0, Training=0, Luck=0, Prestige=0})

	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("SquadName") == sqName then
			p:SetAttribute("SquadLevel", sqData.Level or 1)
			p:SetAttribute("SquadSP", sqData.SP)
			p:SetAttribute("SquadVault", vaultStr)
			p:SetAttribute("SquadUpgrades", upgradesStr)
			p:SetAttribute("SquadVisuals", sqData.Upgrades and sqData.Upgrades.Prestige or 0)

			local myRole = sqData.Members[tostring(p.UserId)] and sqData.Members[tostring(p.UserId)].Role or "Member"
			p:SetAttribute("SquadIsLeader", myRole == "Leader")
			p:SetAttribute("SquadRole", myRole)

			p:SetAttribute("YmirFavored", isFavored)
			p:SetAttribute("Top5_Squad", isTop5)
		end
	end
end

local function LoadPlayerSquad(player)
	local mySquad = player:GetAttribute("SquadName")
	if mySquad and mySquad ~= "None" and mySquad ~= "" then
		local sqData = ActiveSquads[mySquad]

		if not sqData then
			local success, data = pcall(function() return SquadStore:GetAsync(mySquad) end)
			if success then
				if data then
					sqData = data
					ActiveSquads[mySquad] = sqData
				else
					player:SetAttribute("SquadName", "None")
					return
				end
			else
				warn("[SquadManager] Failed to load squad data for: " .. mySquad)
				return 
			end
		end

		if sqData then
			if not sqData.Members[tostring(player.UserId)] then
				local success, freshData = pcall(function() return SquadStore:GetAsync(mySquad) end)
				if success and freshData and freshData.Members[tostring(player.UserId)] then
					sqData = freshData
					ActiveSquads[mySquad] = sqData 
				else
					player:SetAttribute("SquadName", "None")
					player:SetAttribute("SquadLevel", 1)
					player:SetAttribute("SquadIsLeader", false)
					player:SetAttribute("SquadRole", "None")
					player:SetAttribute("YmirFavored", false)
					player:SetAttribute("Top5_Squad", false)
					return
				end
			end

			local needsSeasonReset = false
			if not sqData.Season or sqData.Season < currentSeasonWeek then
				needsSeasonReset = true
			end

			if needsSeasonReset then
				local alreadySavedThisServer = ActiveSquads[mySquad] and ActiveSquads[mySquad].Season == currentSeasonWeek

				sqData.SP = 0
				for _, mem in pairs(sqData.Members) do mem.SP = 0 end 
				sqData.Season = currentSeasonWeek
				ActiveSquads[mySquad] = sqData

				if not alreadySavedThisServer then
					SaveSquadData(mySquad, sqData)
				end
			end

			player:SetAttribute("SquadDesc", sqData.Desc)
			player:SetAttribute("SquadLogo", sqData.Logo)
			player:SetAttribute("SquadLevel", sqData.Level or 1)
			player:SetAttribute("SquadSP", sqData.SP)

			local myRole = sqData.Members[tostring(player.UserId)].Role or "Member"
			player:SetAttribute("SquadIsLeader", myRole == "Leader")
			player:SetAttribute("SquadRole", myRole)

			player:SetAttribute("YmirFavored", mySquad == currentTopSquadName)
			player:SetAttribute("Top5_Squad", Top5SquadsCache[mySquad] or false)
			local vaultStr = HttpService:JSONEncode(sqData.Vault or {"None", "None", "None", "None", "None", "None", "None", "None", "None"})
			player:SetAttribute("SquadVault", vaultStr)

			local upgradesStr = HttpService:JSONEncode(sqData.Upgrades or {Capacity=0, Wealth=0, Training=0, Luck=0, Prestige=0})
			player:SetAttribute("SquadUpgrades", upgradesStr)
			player:SetAttribute("SquadVisuals", sqData.Upgrades and sqData.Upgrades.Prestige or 0)
		end
	end
end

-- Subscribe to Cross-Server Squad Updates
pcall(function()
	MessagingService:SubscribeAsync("SquadUpdate", function(message)
		local data = message.Data
		local sqName = data.SquadName
		local targetId = data.TargetId
		local actionType = data.ActionType

		-- Refresh local cache if this server has the squad loaded
		if ActiveSquads[sqName] then
			local success, freshData = pcall(function() return SquadStore:GetAsync(sqName) end)
			if success and freshData then
				ActiveSquads[sqName] = freshData
			end
		end

		if data.OriginServer == game.JobId then return end -- Avoid duplicate processing for the server that fired this

		-- [[ THE FIX: Handle cross-server Disband events to strip tags from players in other servers ]]
		if actionType == "Disbanded" then
			if ActiveSquads[sqName] then ActiveSquads[sqName] = nil end
			for _, p in ipairs(Players:GetPlayers()) do
				if p:GetAttribute("SquadName") == sqName then
					p:SetAttribute("SquadName", "None")
					p:SetAttribute("SquadLevel", 1)
					p:SetAttribute("SquadIsLeader", false)
					p:SetAttribute("SquadRole", "None")
					p:SetAttribute("YmirFavored", false)
					p:SetAttribute("Top5_Squad", false)
					p:SetAttribute("SquadSP", 0)
					p:SetAttribute("SquadVisuals", 0)
					p:SetAttribute("SquadVault", '{"1":"None","2":"None","3":"None","4":"None","5":"None","6":"None","7":"None","8":"None","9":"None"}')
					p:SetAttribute("SquadUpgrades", '{"Capacity":0,"Wealth":0,"Training":0,"Luck":0,"Prestige":0}')
					NotificationEvent:FireClient(p, "Your Squad was disbanded by the Leader.", "Error")
				end
			end
			return
		end

		for _, p in ipairs(Players:GetPlayers()) do
			if actionType == "Requested" then
				if p:GetAttribute("SquadName") == sqName then
					local pRole = p:GetAttribute("SquadRole")
					if pRole == "Leader" or pRole == "Officer" then
						NotificationEvent:FireClient(p, (data.TargetName or "Someone") .. " has requested to join your Squad!", "Info")
					end
				end
			elseif actionType == "Accepted" and tostring(p.UserId) == targetId then
				if p:GetAttribute("SquadName") ~= sqName then
					p:SetAttribute("SquadName", sqName) -- [[ THE FIX: Inject the squad name BEFORE pulling data ]]
					LoadPlayerSquad(p)
					NotificationEvent:FireClient(p, "Your request to join " .. sqName .. " was accepted!", "Success")
				end
			elseif actionType == "Kicked" and tostring(p.UserId) == targetId then
				if p:GetAttribute("SquadName") == sqName then
					p:SetAttribute("SquadName", "None")
					p:SetAttribute("SquadLevel", 1)
					p:SetAttribute("SquadIsLeader", false)
					p:SetAttribute("SquadRole", "None")
					p:SetAttribute("YmirFavored", false)
					p:SetAttribute("Top5_Squad", false)
					p:SetAttribute("SquadSP", 0)
					p:SetAttribute("SquadVisuals", 0)
					p:SetAttribute("SquadVault", '{"1":"None","2":"None","3":"None","4":"None","5":"None","6":"None","7":"None","8":"None","9":"None"}')
					p:SetAttribute("SquadUpgrades", '{"Capacity":0,"Wealth":0,"Training":0,"Luck":0,"Prestige":0}')
					NotificationEvent:FireClient(p, "You have been kicked from the Squad.", "Error")
				end
			end
		end
	end)
end)

AddSquadSP.Event:Connect(function(sqName, amount, userId)
	local sqData = ActiveSquads[sqName]
	if sqData then
		sqData.SP = (sqData.SP or 0) + amount
		if userId then
			local uStr = tostring(userId)
			if sqData.Members[uStr] then
				sqData.Members[uStr].SP = (sqData.Members[uStr].SP or 0) + amount
			end
		end
		SaveSquadData(sqName, sqData)
		UpdateOnlineMembers(sqName)
	end
end)

local function RefreshGlobalCache()
	if isFetchingCache then return end
	isFetchingCache = true
	pcall(function()
		local pages = SquadLeaderboard:GetSortedAsync(false, 50)
		local newCache = {}
		for _, entry in ipairs(pages:GetCurrentPage()) do
			local sqName = entry.key
			local sqData = ActiveSquads[sqName] or SquadStore:GetAsync(sqName)
			if sqData then
				local memCount = 0; for _, _ in pairs(sqData.Members or {}) do memCount += 1 end
				table.insert(newCache, {
					Name = sqData.Name, Desc = sqData.Desc, Logo = sqData.Logo ~= "" and sqData.Logo or "rbxassetid://100826303284945",
					Level = sqData.Level or 1, MemberCount = memCount, SP = sqData.SP or 0
				})
			end
		end
		GlobalSquadCache = newCache
	end)
	isFetchingCache = false
end

local function FetchTopSquad()
	pcall(function()
		local pages = SquadLeaderboard:GetSortedAsync(false, 5)
		local topSquads = {}
		local topEntry = nil

		for rank, entry in ipairs(pages:GetCurrentPage()) do
			-- [[ THE FIX: Squads MUST have > 0 SP to earn the Top 5 / Ymir's Favored leaderboard titles ]]
			if (tonumber(entry.value) or 0) > 0 then
				if rank <= 5 then topSquads[entry.key] = true end
				if rank == 1 then topEntry = entry end
			end
		end
		Top5SquadsCache = topSquads

		if topEntry then
			local newTopName = topEntry.key
			if newTopName ~= currentTopSquadName then
				currentTopSquadName = newTopName
				for _, p in ipairs(Players:GetPlayers()) do
					if p:GetAttribute("SquadName") == newTopName then
						NotificationEvent:FireClient(p, "Your Squad is now Ymir's Favored! (+3 Vault Slots, +50% Drop Rates)", "Success")
					end
				end
			end
		else
			currentTopSquadName = nil -- Ensures the old favored squad gets dethroned on a reset
		end

		for _, p in ipairs(Players:GetPlayers()) do
			local pSquad = p:GetAttribute("SquadName")
			if pSquad and pSquad ~= "None" and pSquad ~= "" then
				p:SetAttribute("YmirFavored", pSquad == currentTopSquadName)
				p:SetAttribute("Top5_Squad", topSquads[pSquad] or false)
			else
				p:SetAttribute("YmirFavored", false)
				p:SetAttribute("Top5_Squad", false)
			end
		end
	end)
end

local function RewardTopSquads()
	pcall(function()
		local pages = SquadLeaderboard:GetSortedAsync(false, 5)
		for rank, entry in ipairs(pages:GetCurrentPage()) do
			if (tonumber(entry.value) or 0) > 0 then
				if rank == 1 then
					for _, p in ipairs(Players:GetPlayers()) do
						if p:GetAttribute("SquadName") == entry.key and p:FindFirstChild("leaderstats") then
							p.leaderstats.Dews.Value += 500000
							NotificationEvent:FireClient(p, "SEASON END: Your Squad placed #1 Globally! (+500,000 Dews)", "Success")
						end
					end
				elseif rank <= 5 then
					for _, p in ipairs(Players:GetPlayers()) do
						if p:GetAttribute("SquadName") == entry.key and p:FindFirstChild("leaderstats") then
							p.leaderstats.Dews.Value += 100000
							NotificationEvent:FireClient(p, "SEASON END: Your Squad placed Top 5! (+100,000 Dews)", "Success")
						end
					end
				end
			end
		end
	end)
end

task.spawn(function()
	RefreshGlobalCache()
	FetchTopSquad()
	while task.wait(30) do 
		local realWeek = math.floor((os.time() + SUNDAY_OFFSET) / SECONDS_IN_WEEK)
		if realWeek > currentSeasonWeek then
			RewardTopSquads()

			currentSeasonWeek = realWeek
			SquadLeaderboard = DataStoreService:GetOrderedDataStore("Global_Squad_SP_Season_" .. currentSeasonWeek)

			for sqName, sqData in pairs(ActiveSquads) do
				sqData.SP = 0
				for _, mem in pairs(sqData.Members) do mem.SP = 0 end 
				sqData.Season = currentSeasonWeek
				SaveSquadData(sqName, sqData)
				UpdateOnlineMembers(sqName)
				task.wait(1.5)
			end

			Top5SquadsCache = {}
			currentTopSquadName = nil
			GlobalSquadCache = {}
		end

		RefreshGlobalCache() 
		FetchTopSquad()
	end
end)

SquadAction.OnServerEvent:Connect(function(player, action, data)
	if action == "Create" then
		if not data.Name or string.len(data.Name) < 3 or string.len(data.Name) > 20 then NotificationEvent:FireClient(player, "Squad Name must be between 3 and 20 characters.", "Error") return end
		if player:GetAttribute("SquadName") and player:GetAttribute("SquadName") ~= "None" then NotificationEvent:FireClient(player, "You are already in a Squad!", "Error") return end

		local dews = player.leaderstats and player.leaderstats:FindFirstChild("Dews")
		if not dews or dews.Value < 100000 then NotificationEvent:FireClient(player, "Requires 100,000 Dews.", "Error") return end
		if pcall(function() return SquadStore:GetAsync(data.Name) end) and SquadStore:GetAsync(data.Name) then NotificationEvent:FireClient(player, "Squad name taken!", "Error") return end

		dews.Value -= 100000
		local safeLogo = data.Logo or ""; local numId = safeLogo:match("%d+"); if numId then safeLogo = "rbxassetid://" .. numId else safeLogo = "" end

		local newSquadData = {
			Name = data.Name, Desc = data.Desc or "A newly founded Strike Squad.", Logo = safeLogo,
			Leader = player.UserId, Members = { [tostring(player.UserId)] = {Role = "Leader", Name = player.Name, SP = 0} },
			Requests = {}, SP = 0, Level = 1,
			Vault = {"None", "None", "None", "None", "None", "None", "None", "None", "None"},
			Upgrades = {Capacity = 0, Wealth = 0, Training = 0, Luck = 0, Prestige = 0},
			Season = currentSeasonWeek
		}

		ActiveSquads[data.Name] = newSquadData
		SaveSquadData(data.Name, newSquadData)

		player:SetAttribute("SquadName", data.Name)
		player:SetAttribute("SquadDesc", newSquadData.Desc)
		player:SetAttribute("SquadLogo", newSquadData.Logo)
		player:SetAttribute("SquadLevel", 1)
		player:SetAttribute("SquadSP", 0)
		player:SetAttribute("SquadIsLeader", true)
		player:SetAttribute("SquadRole", "Leader")
		player:SetAttribute("YmirFavored", false)
		player:SetAttribute("Top5_Squad", false)
		player:SetAttribute("SquadVault", HttpService:JSONEncode(newSquadData.Vault))
		player:SetAttribute("SquadUpgrades", HttpService:JSONEncode(newSquadData.Upgrades))
		player:SetAttribute("SquadVisuals", 0)
		NotificationEvent:FireClient(player, "Squad '" .. data.Name .. "' officially founded!", "Success")

	elseif action == "LevelUp" then
		local sqName = player:GetAttribute("SquadName")
		local sqData = ActiveSquads[sqName]
		if not sqData then return end

		local myRole = sqData.Members[tostring(player.UserId)] and sqData.Members[tostring(player.UserId)].Role
		if myRole ~= "Leader" and myRole ~= "Officer" then
			NotificationEvent:FireClient(player, "Only Leaders and Officers can level up the Squad.", "Error")
			return
		end

		if sqData.Level >= 50 then
			NotificationEvent:FireClient(player, "Squad is at Maximum Level!", "Error")
			return
		end

		local cost = math.floor(math.pow(sqData.Level, 2.3) * 500000)
		if player.leaderstats.Dews.Value < cost then
			NotificationEvent:FireClient(player, "Not enough Dews! (Requires " .. cost .. ")", "Error")
			return
		end

		player.leaderstats.Dews.Value -= cost
		sqData.Level += 1
		SaveSquadData(sqName, sqData)
		UpdateOnlineMembers(sqName)
		NotificationEvent:FireClient(player, "Squad Leveled Up to Level " .. sqData.Level .. "!", "Success")

	elseif action == "SetRole" then
		local sqName = player:GetAttribute("SquadName")
		local targetId = tostring(data.TargetId)
		local newRole = data.Role

		local sqData = ActiveSquads[sqName]
		if not sqData or tonumber(sqData.Leader) ~= player.UserId then return end
		if targetId == tostring(player.UserId) then return end

		if sqData.Members[targetId] then
			sqData.Members[targetId].Role = newRole
			SaveSquadData(sqName, sqData)
			UpdateOnlineMembers(sqName)
			NotificationEvent:FireClient(player, "Updated member role to " .. newRole .. ".", "Success")
		end

	elseif action == "UpgradePerk" then
		local perk = data.Perk
		local sqName = player:GetAttribute("SquadName")
		local sqData = ActiveSquads[sqName]
		if not sqData then return end

		local myRole = sqData.Members[tostring(player.UserId)] and sqData.Members[tostring(player.UserId)].Role
		if myRole ~= "Leader" and myRole ~= "Officer" then
			NotificationEvent:FireClient(player, "Only the Leader and Officers can purchase Squad Upgrades.", "Error")
			return
		end

		local Costs = { Capacity = 250000, Wealth = 100000, Training = 100000, Luck = 150000, Prestige = 500000 }
		local MaxLevels = { Capacity = 5, Wealth = 10, Training = 10, Luck = 10, Prestige = 5 }
		local ReqScales = { Capacity = 5, Wealth = 5, Training = 5, Luck = 5, Prestige = 10 }

		if not sqData.Upgrades then sqData.Upgrades = {Capacity = 0, Wealth = 0, Training = 0, Luck = 0, Prestige = 0} end

		local currentLevel = sqData.Upgrades[perk] or 0
		if currentLevel >= MaxLevels[perk] then
			NotificationEvent:FireClient(player, "This perk is already Max Level!", "Error")
			return
		end

		local reqLevel = (currentLevel + 1) * ReqScales[perk]
		if sqData.Level < reqLevel then
			NotificationEvent:FireClient(player, "Your Squad must be Level " .. reqLevel .. " to unlock this tier!", "Error")
			return
		end

		local cost = Costs[perk] * (currentLevel + 1)
		if player.leaderstats.Dews.Value < cost then
			NotificationEvent:FireClient(player, "You do not have enough Dews to fund this upgrade.", "Error")
			return
		end

		player.leaderstats.Dews.Value -= cost
		sqData.Upgrades[perk] = currentLevel + 1
		SaveSquadData(sqName, sqData)
		UpdateOnlineMembers(sqName)
		NotificationEvent:FireClient(player, perk .. " upgraded to Level " .. (currentLevel + 1) .. "!", "Success")

	elseif action == "RequestJoin" then
		local sqName = data
		if player:GetAttribute("SquadName") and player:GetAttribute("SquadName") ~= "None" then NotificationEvent:FireClient(player, "You must leave your current Squad first.", "Error") return end

		local success, sqData = pcall(function() return SquadStore:GetAsync(sqName) end)
		if not success or not sqData then sqData = ActiveSquads[sqName] end
		if not sqData then NotificationEvent:FireClient(player, "Squad not found.", "Error") return end

		local sqUpgrades = sqData.Upgrades or {Capacity=0}
		local maxMembers = 15 + (sqUpgrades.Capacity * 5)

		local memCount = 0; for _, _ in pairs(sqData.Members) do memCount += 1 end
		if memCount >= maxMembers then NotificationEvent:FireClient(player, "That Squad is currently full!", "Error") return end

		if not sqData.Requests then sqData.Requests = {} end
		if sqData.Requests[tostring(player.UserId)] then NotificationEvent:FireClient(player, "You already have a pending request for this Squad.", "Error") return end

		sqData.Requests[tostring(player.UserId)] = player.Name
		SaveSquadData(sqName, sqData)

		if ActiveSquads[sqName] then
			ActiveSquads[sqName].Requests = sqData.Requests
		end

		-- Alert officers globally
		pcall(function()
			MessagingService:PublishAsync("SquadUpdate", {
				SquadName = sqName,
				TargetId = tostring(player.UserId),
				ActionType = "Requested",
				TargetName = player.Name,
				OriginServer = game.JobId
			})
		end)

		-- Alert officers locally
		for _, p in ipairs(Players:GetPlayers()) do
			if p:GetAttribute("SquadName") == sqName then
				local pRole = p:GetAttribute("SquadRole")
				if pRole == "Leader" or pRole == "Officer" then 
					NotificationEvent:FireClient(p, player.Name .. " has requested to join your Squad!", "Info") 
				end
			end
		end
		NotificationEvent:FireClient(player, "Join Request sent to the Squad Officers.", "Success")

	elseif action == "ManageRequest" then
		local sqName = player:GetAttribute("SquadName")
		local targetId = tostring(data.TargetId)
		local decision = data.Decision

		local sqData = ActiveSquads[sqName]
		if not sqData then return end
		local myRole = sqData.Members[tostring(player.UserId)] and sqData.Members[tostring(player.UserId)].Role
		if myRole ~= "Leader" and myRole ~= "Officer" then return end

		local freshData = SquadStore:GetAsync(sqName)
		if freshData then 
			sqData.Members = freshData.Members 
			sqData.Requests = freshData.Requests or {}
		end

		if not sqData.Requests or not sqData.Requests[targetId] then 
			NotificationEvent:FireClient(player, "This request no longer exists.", "Error")
			return 
		end

		local targetName = sqData.Requests[targetId]
		sqData.Requests[targetId] = nil 

		if decision == "Accept" then
			local alreadyInSquad = false
			for _, otherSq in pairs(ActiveSquads) do
				if otherSq.Members[targetId] then alreadyInSquad = true break end
			end
			if alreadyInSquad then
				NotificationEvent:FireClient(player, targetName .. " is already in another Squad and cannot be accepted.", "Error")
				return
			end

			local sqUpgrades = sqData.Upgrades or {Capacity=0}
			local maxMembers = 15 + (sqUpgrades.Capacity * 5)
			local memCount = 0; for _, _ in pairs(sqData.Members) do memCount += 1 end
			if memCount >= maxMembers then NotificationEvent:FireClient(player, "Squad is full!", "Error"); return end

			sqData.Members[targetId] = {Role = "Member", Name = targetName, SP = 0}
			SaveSquadData(sqName, sqData)

			pcall(function()
				MessagingService:PublishAsync("SquadUpdate", {
					SquadName = sqName,
					TargetId = targetId,
					ActionType = "Accepted",
					OriginServer = game.JobId
				})
			end)

			for _, p in ipairs(Players:GetPlayers()) do
				if tostring(p.UserId) == targetId then
					p:SetAttribute("SquadName", sqName) -- [[ THE FIX: Inject the squad name BEFORE pulling data ]]
					LoadPlayerSquad(p)
					NotificationEvent:FireClient(p, "Your request to join " .. sqName .. " was accepted!", "Success")
				end
			end
			NotificationEvent:FireClient(player, "Accepted " .. targetName .. " into the Squad.", "Success")
		else
			SaveSquadData(sqName, sqData)
			NotificationEvent:FireClient(player, "Denied request from " .. targetName .. ".", "Info")
		end

	elseif action == "KickMember" then
		local sqName = player:GetAttribute("SquadName")
		local targetId = tostring(data)
		if not sqName or sqName == "None" or sqName == "" then return end

		local sqData = ActiveSquads[sqName]
		if not sqData then return end

		local myRole = sqData.Members[tostring(player.UserId)] and sqData.Members[tostring(player.UserId)].Role
		if myRole ~= "Leader" and myRole ~= "Officer" then 
			NotificationEvent:FireClient(player, "Error: Only Leaders and Officers can kick.", "Error")
			return 
		end

		if targetId == tostring(player.UserId) then
			NotificationEvent:FireClient(player, "You cannot kick yourself.", "Error")
			return
		end

		local freshData = SquadStore:GetAsync(sqName)
		if freshData then sqData.Members = freshData.Members end

		if sqData.Members[targetId] then
			local targetRole = sqData.Members[targetId].Role
			if myRole == "Officer" and (targetRole == "Leader" or targetRole == "Officer") then
				NotificationEvent:FireClient(player, "Officers cannot kick other Officers or the Leader.", "Error")
				return
			end

			local targetName = sqData.Members[targetId].Name
			sqData.Members[targetId] = nil
			SaveSquadData(sqName, sqData)

			pcall(function()
				MessagingService:PublishAsync("SquadUpdate", {
					SquadName = sqName,
					TargetId = targetId,
					ActionType = "Kicked",
					OriginServer = game.JobId
				})
			end)

			for _, p in ipairs(Players:GetPlayers()) do
				if tostring(p.UserId) == targetId and p:GetAttribute("SquadName") == sqName then
					p:SetAttribute("SquadName", "None")
					p:SetAttribute("SquadLevel", 1)
					p:SetAttribute("SquadIsLeader", false)
					p:SetAttribute("SquadRole", "None")
					p:SetAttribute("YmirFavored", false)
					p:SetAttribute("Top5_Squad", false)
					p:SetAttribute("SquadSP", 0)
					p:SetAttribute("SquadVisuals", 0)
					p:SetAttribute("SquadVault", '{"1":"None","2":"None","3":"None","4":"None","5":"None","6":"None","7":"None","8":"None","9":"None"}')
					p:SetAttribute("SquadUpgrades", '{"Capacity":0,"Wealth":0,"Training":0,"Luck":0,"Prestige":0}')
					NotificationEvent:FireClient(p, "You have been kicked from the Squad.", "Error")
				end
			end
			NotificationEvent:FireClient(player, "Kicked " .. targetName .. " from the Squad.", "Success")
			UpdateOnlineMembers(sqName)
		end

	elseif action == "DepositItem" then
		local slot = tonumber(data.Slot)
		local itemName = tostring(data.ItemName)
		local sqName = player:GetAttribute("SquadName")
		if not sqName or sqName == "None" then return end

		local sqData = ActiveSquads[sqName]
		if not sqData then return end

		if player:GetAttribute(itemName:gsub("[^%w]", "") .. "_Locked") then
			NotificationEvent:FireClient(player, "You cannot deposit Locked items!", "Error")
			return
		end

		if slot > 6 and sqName ~= currentTopSquadName then
			NotificationEvent:FireClient(player, "Bonus Vault slots are locked! Reach #1 Globally to unlock.", "Error")
			return
		end

		if not sqData.Vault then sqData.Vault = {"None", "None", "None", "None", "None", "None", "None", "None", "None"} end
		if sqData.Vault[slot] and sqData.Vault[slot] ~= "None" then
			NotificationEvent:FireClient(player, "That slot is already full!", "Error")
			return
		end

		local attrName = itemName:gsub("[^%w]", "") .. "Count"
		local pCount = player:GetAttribute(attrName) or 0
		if pCount <= 0 then
			NotificationEvent:FireClient(player, "You do not own this item.", "Error")
			return
		end

		player:SetAttribute(attrName, pCount - 1)
		sqData.Vault[slot] = itemName

		if (pCount - 1) <= 0 then
			if player:GetAttribute("EquippedWeapon") == itemName then
				player:SetAttribute("EquippedWeapon", "None")
				player:SetAttribute("FightingStyle", "None")
			elseif player:GetAttribute("EquippedAccessory") == itemName then
				player:SetAttribute("EquippedAccessory", "None")
			end
		end

		SaveSquadData(sqName, sqData)
		UpdateOnlineMembers(sqName)
		NotificationEvent:FireClient(player, "Deposited " .. itemName .. " into Vault.", "Success")

	elseif action == "WithdrawItem" then
		local slot = tonumber(data.Slot)
		local sqName = player:GetAttribute("SquadName")
		if not sqName or sqName == "None" then return end

		if slot > 6 and sqName ~= currentTopSquadName then
			NotificationEvent:FireClient(player, "Ymir has sealed this slot! Reclaim the #1 Global Rank to access this item.", "Error")
			return
		end

		local sqData = ActiveSquads[sqName]
		if not sqData then return end

		if not sqData.Vault then sqData.Vault = {"None", "None", "None", "None", "None", "None", "None", "None", "None"} end
		local itemName = sqData.Vault[slot]
		if not itemName or itemName == "None" then return end

		local attrName = itemName:gsub("[^%w]", "") .. "Count"
		player:SetAttribute(attrName, (player:GetAttribute(attrName) or 0) + 1)
		sqData.Vault[slot] = "None"
		SaveSquadData(sqName, sqData)
		UpdateOnlineMembers(sqName)
		NotificationEvent:FireClient(player, "Withdrew " .. itemName .. " from Vault.", "Success")

	elseif action == "Leave" then
		local sqName = player:GetAttribute("SquadName")
		if not sqName or sqName == "None" then return end
		local sqData = ActiveSquads[sqName]
		if not sqData then return end

		if tonumber(sqData.Leader) == player.UserId then
			NotificationEvent:FireClient(player, "You are the Leader! You must Disband the Squad.", "Error")
			return
		end

		sqData.Members[tostring(player.UserId)] = nil
		SaveSquadData(sqName, sqData)

		player:SetAttribute("SquadName", "None")
		player:SetAttribute("SquadLevel", 1)
		player:SetAttribute("SquadIsLeader", false)
		player:SetAttribute("SquadRole", "None")
		player:SetAttribute("YmirFavored", false)
		player:SetAttribute("Top5_Squad", false)
		player:SetAttribute("SquadVisuals", 0)
		player:SetAttribute("SquadVault", '{"1":"None","2":"None","3":"None","4":"None","5":"None","6":"None","7":"None","8":"None","9":"None"}')
		player:SetAttribute("SquadUpgrades", '{"Capacity":0,"Wealth":0,"Training":0,"Luck":0,"Prestige":0}')
		NotificationEvent:FireClient(player, "You left the Squad.", "Info")
		UpdateOnlineMembers(sqName)

	elseif action == "Disband" then
		local sqName = player:GetAttribute("SquadName")
		if not sqName or sqName == "None" or sqName == "" then return end

		local sqData = ActiveSquads[sqName]
		if not sqData or tonumber(sqData.Leader) ~= player.UserId then 
			NotificationEvent:FireClient(player, "Error: Only the Leader can disband.", "Error")
			return 
		end

		for _, p in ipairs(Players:GetPlayers()) do
			if p:GetAttribute("SquadName") == sqName then
				p:SetAttribute("SquadName", "None")
				p:SetAttribute("SquadLevel", 1)
				p:SetAttribute("SquadIsLeader", false)
				p:SetAttribute("SquadRole", "None")
				p:SetAttribute("YmirFavored", false)
				p:SetAttribute("Top5_Squad", false)
				p:SetAttribute("SquadSP", 0)
				p:SetAttribute("SquadVisuals", 0)
				p:SetAttribute("SquadVault", '{"1":"None","2":"None","3":"None","4":"None","5":"None","6":"None","7":"None","8":"None","9":"None"}')
				p:SetAttribute("SquadUpgrades", '{"Capacity":0,"Wealth":0,"Training":0,"Luck":0,"Prestige":0}')
				NotificationEvent:FireClient(p, "Your Squad was disbanded by the Leader.", "Error")
			end
		end

		-- [[ THE FIX: Broadcast disband event so ALL servers clear their players of this squad's attributes ]]
		pcall(function()
			MessagingService:PublishAsync("SquadUpdate", {
				SquadName = sqName,
				ActionType = "Disbanded",
				OriginServer = game.JobId
			})
		end)

		ActiveSquads[sqName] = nil

		task.spawn(function()
			pcall(function()
				SquadStore:RemoveAsync(sqName)
				SquadLeaderboard:RemoveAsync(sqName)
			end)
		end)

		NotificationEvent:FireClient(player, "Squad successfully disbanded.", "Success")
	end
end)

GetPublicSquads.OnServerInvoke = function()
	local returned = {}; local seen = {}
	for _, sq in ipairs(GlobalSquadCache) do table.insert(returned, sq); seen[sq.Name] = true end
	for name, data in pairs(ActiveSquads) do
		if not seen[name] then
			local mCount = 0; for _, _ in pairs(data.Members or {}) do mCount += 1 end
			local maxMems = 15 + ((data.Upgrades and data.Upgrades.Capacity or 0) * 5)
			table.insert(returned, {Name = data.Name, Desc = data.Desc, Logo = data.Logo, Level = data.Level, MemberCount = mCount .. "/" .. maxMems, SP = data.SP})
			seen[name] = true
		end
	end
	table.sort(returned, function(a, b) return (tonumber(a.SP) or 0) > (tonumber(b.SP) or 0) end)
	return returned
end

GetSquadRequests.OnServerInvoke = function(player)
	local sqName = player:GetAttribute("SquadName")
	if not sqName or sqName == "None" then return {} end
	local sqData = ActiveSquads[sqName]
	if not sqData then return {} end

	local myRole = sqData.Members[tostring(player.UserId)] and sqData.Members[tostring(player.UserId)].Role
	if myRole ~= "Leader" and myRole ~= "Officer" then return {} end

	-- Always fetch fresh data to sync cross-server requests when UI is opened
	local success, freshData = pcall(function() return SquadStore:GetAsync(sqName) end)
	if success and freshData then
		sqData.Requests = freshData.Requests or {}
		ActiveSquads[sqName].Requests = sqData.Requests
	end

	local reqs = {}
	for uid, uname in pairs(sqData.Requests or {}) do table.insert(reqs, {UserId = uid, Name = uname}) end
	return reqs
end

GetSquadRoster.OnServerInvoke = function(player)
	local sqName = player:GetAttribute("SquadName")
	if not sqName or sqName == "None" or sqName == "" then return {} end

	local sqData = ActiveSquads[sqName]
	if not sqData then return {} end

	local roster = {}
	for userId, memData in pairs(sqData.Members) do
		table.insert(roster, { UserId = tonumber(userId), Name = memData.Name, Role = memData.Role, SP = memData.SP or 0 })
	end
	table.sort(roster, function(a, b) 
		if a.Role == "Leader" and b.Role ~= "Leader" then return true end
		if b.Role == "Leader" and a.Role ~= "Leader" then return false end
		if a.Role == "Officer" and b.Role ~= "Officer" then return true end
		if b.Role == "Officer" and a.Role ~= "Officer" then return false end
		return a.Name < b.Name
	end)
	return roster
end

GetSquadLeaderboard.OnServerInvoke = function(player)
	local sorted = {}
	local seen = {}

	for name, data in pairs(ActiveSquads) do
		table.insert(sorted, {Name = data.Name, SP = tonumber(data.SP) or 0})
		seen[name] = true
	end

	for _, sq in ipairs(GlobalSquadCache) do
		if not seen[sq.Name] then
			table.insert(sorted, {Name = sq.Name, SP = tonumber(sq.SP) or 0})
			seen[sq.Name] = true
		end
	end

	table.sort(sorted, function(a, b) return a.SP > b.SP end)

	local top10 = {}
	for i = 1, math.min(10, #sorted) do
		table.insert(top10, {Rank = i, Name = sorted[i].Name, SP = sorted[i].SP})
	end

	return top10
end

Players.PlayerAdded:Connect(function(player)
	if player:GetAttribute("DataLoaded") then LoadPlayerSquad(player) end
	player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
		if player:GetAttribute("DataLoaded") then LoadPlayerSquad(player) end
	end)
end)