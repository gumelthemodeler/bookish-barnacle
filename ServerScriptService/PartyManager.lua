-- @ScriptType: Script
-- @ScriptType: Script
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = ReplicatedStorage:WaitForChild("Network")

-- Create RemoteEvents
local PartyAction = Network:FindFirstChild("PartyAction") or Instance.new("RemoteEvent", Network)
PartyAction.Name = "PartyAction"
local PartyUpdate = Network:FindFirstChild("PartyUpdate") or Instance.new("RemoteEvent", Network)
PartyUpdate.Name = "PartyUpdate"

-- Data Structures
local Parties = {} -- Dictionary of [LeaderUserId] = { Leader = Player, Members = {Player1, Player2, ...} }
local PlayerToParty = {} -- Dictionary of [PlayerUserId] = LeaderUserId
local Invites = {} -- Dictionary of [InviteeUserId] = { [LeaderUserId] = true }

local MAX_PARTY_SIZE = 3

local function BroadcastPartyUpdate(leaderId)
	local party = Parties[leaderId]
	if not party then return end

	-- Build the data packet for the UI
	local uiData = {}
	for _, member in ipairs(party.Members) do
		table.insert(uiData, {
			Name = member.Name,
			UserId = member.UserId,
			IsLeader = (member.UserId == leaderId)
		})
	end

	-- Send the updated list to everyone in the party
	for _, member in ipairs(party.Members) do
		PartyUpdate:FireClient(member, "UpdateList", uiData)
	end
end

local function LeaveParty(player)
	local leaderId = PlayerToParty[player.UserId]
	if not leaderId then return end

	local party = Parties[leaderId]
	if not party then return end

	if player.UserId == leaderId then
		-- Disband the party if the leader leaves
		for _, member in ipairs(party.Members) do
			PlayerToParty[member.UserId] = nil
			PartyUpdate:FireClient(member, "Disbanded")
			Network.NotificationEvent:FireClient(member, "The Raid Party was disbanded.", "Error")
		end
		Parties[leaderId] = nil
	else
		-- Remove standard member
		for i, member in ipairs(party.Members) do
			if member.UserId == player.UserId then
				table.remove(party.Members, i)
				break
			end
		end
		PlayerToParty[player.UserId] = nil
		PartyUpdate:FireClient(player, "Disbanded")
		BroadcastPartyUpdate(leaderId)
	end
end

PartyAction.OnServerEvent:Connect(function(player, action, targetName)
	if action == "Create" then
		if PlayerToParty[player.UserId] then return end
		Parties[player.UserId] = { Leader = player, Members = {player} }
		PlayerToParty[player.UserId] = player.UserId
		BroadcastPartyUpdate(player.UserId)

	elseif action == "Invite" then
		local leaderId = PlayerToParty[player.UserId]
		if not leaderId or leaderId ~= player.UserId then 
			Network.NotificationEvent:FireClient(player, "Only the party leader can invite players.", "Error")
			return 
		end

		local party = Parties[leaderId]
		if #party.Members >= MAX_PARTY_SIZE then
			Network.NotificationEvent:FireClient(player, "Your party is full (Max " .. MAX_PARTY_SIZE .. ").", "Error")
			return
		end

		-- Find target player
		local targetPlayer = nil
		for _, p in ipairs(Players:GetPlayers()) do
			if string.lower(p.Name) == string.lower(targetName) then
				targetPlayer = p; break
			end
		end

		if not targetPlayer then
			Network.NotificationEvent:FireClient(player, "Player not found.", "Error")
			return
		end
		if PlayerToParty[targetPlayer.UserId] then
			Network.NotificationEvent:FireClient(player, targetPlayer.Name .. " is already in a party.", "Error")
			return
		end

		-- Send Invite
		if not Invites[targetPlayer.UserId] then Invites[targetPlayer.UserId] = {} end
		Invites[targetPlayer.UserId][leaderId] = true

		PartyUpdate:FireClient(targetPlayer, "IncomingInvite", player.Name)
		Network.NotificationEvent:FireClient(player, "Invited " .. targetPlayer.Name .. " to the party.", "Success")

	elseif action == "AcceptInvite" then
		local leaderPlayer = nil
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Name == targetName then leaderPlayer = p; break end
		end

		if not leaderPlayer or not Invites[player.UserId] or not Invites[player.UserId][leaderPlayer.UserId] then
			Network.NotificationEvent:FireClient(player, "Invite expired or invalid.", "Error")
			return
		end

		local leaderId = leaderPlayer.UserId
		local party = Parties[leaderId]

		if not party or #party.Members >= MAX_PARTY_SIZE then
			Network.NotificationEvent:FireClient(player, "That party is full or no longer exists.", "Error")
			Invites[player.UserId][leaderId] = nil
			return
		end

		if PlayerToParty[player.UserId] then LeaveParty(player) end

		table.insert(party.Members, player)
		PlayerToParty[player.UserId] = leaderId
		Invites[player.UserId][leaderId] = nil

		BroadcastPartyUpdate(leaderId)
		Network.NotificationEvent:FireClient(leaderPlayer, player.Name .. " joined the party!", "Success")

	elseif action == "Leave" then
		LeaveParty(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	LeaveParty(player)
	Invites[player.UserId] = nil
end)

-- [[ THE FIX: Added a ghost-state cleanup to prevent broken party leaders causing deployment soft-locks ]]
local GetPartyBindable = Instance.new("BindableFunction")
GetPartyBindable.Name = "GetPlayerParty"
GetPartyBindable.Parent = Network

GetPartyBindable.OnInvoke = function(player)
	local leaderId = PlayerToParty[player.UserId]
	if leaderId and not Parties[leaderId] then
		PlayerToParty[player.UserId] = nil
		leaderId = nil
	end

	return leaderId and Parties[leaderId] or {Leader = player, Members = {player}}
end