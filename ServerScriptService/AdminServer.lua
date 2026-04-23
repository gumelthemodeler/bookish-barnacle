-- @ScriptType: Script
-- @ScriptType: Script
-- Name: AdminServer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Network = ReplicatedStorage:WaitForChild("Network")

local AdminCommand = Network:FindFirstChild("AdminCommand") or Instance.new("RemoteEvent", Network)
AdminCommand.Name = "AdminCommand"
local NotificationEvent = Network:WaitForChild("NotificationEvent")

local AdminManager = require(ReplicatedStorage:WaitForChild("AdminManager"))

AdminCommand.OnServerEvent:Connect(function(player, command, targetName, ...)
	if not AdminManager.IsAdmin(player) then
		warn("[SECURITY] Unauthorized AdminCommand attempt by " .. player.Name)
		return 
	end

	local target = nil
	for _, p in ipairs(Players:GetPlayers()) do
		if string.lower(p.Name) == string.lower(targetName) then
			target = p
			break
		end
	end

	if not target then
		NotificationEvent:FireClient(player, "Target player not found in server.", "Error")
		return 
	end

	local args = {...}

	if command == "SetDews" then
		target.leaderstats.Dews.Value = tonumber(args[1]) or 0
	elseif command == "SetXP" then
		target:SetAttribute("XP", tonumber(args[1]) or 0)
	elseif command == "SetTitanXP" then
		target:SetAttribute("TitanXP", tonumber(args[1]) or 0)
	elseif command == "SetPrestige" then
		target.leaderstats.Prestige.Value = tonumber(args[1]) or 0
	elseif command == "SetElo" then
		target.leaderstats.Elo.Value = tonumber(args[1]) or 1000
	elseif command == "SetHealth" then
		target:SetAttribute("MaxHealth", tonumber(args[1]) or 100)
		target:SetAttribute("Health", tonumber(args[1]) or 100)
	elseif command == "SetGas" then
		target:SetAttribute("Gas", tonumber(args[1]) or 50)
	elseif command == "SetStrength" then
		target:SetAttribute("Strength", tonumber(args[1]) or 10)
	elseif command == "SetDefense" then
		target:SetAttribute("Defense", tonumber(args[1]) or 10)
	elseif command == "SetSpeed" then
		target:SetAttribute("Speed", tonumber(args[1]) or 10)
	elseif command == "SetResolve" then
		target:SetAttribute("Resolve", tonumber(args[1]) or 10)
	elseif command == "GiveItem" then
		local itemName = args[1]
		local amount = tonumber(args[2]) or 1
		local safeName = itemName:gsub("[^%w]", "") .. "Count"
		target:SetAttribute(safeName, (target:GetAttribute(safeName) or 0) + amount)
	elseif command == "EquipWeapon" then
		target:SetAttribute("EquippedWeapon", args[1])
	elseif command == "EquipAccessory" then
		target:SetAttribute("EquippedAccessory", args[1])
	elseif command == "EquipSkill" then
		local slot = tonumber(args[1]) or 1
		target:SetAttribute("EquippedSkill_" .. slot, args[2])
	elseif command == "SetStoryPart" then
		target:SetAttribute("CurrentPart", tonumber(args[1]) or 1)
	elseif command == "SetMission" then
		target:SetAttribute("CurrentMission", tonumber(args[1]) or 1)
	elseif command == "GiveTitle" then
		local title = args[1]
		local current = target:GetAttribute("UnlockedTitles") or ""
		if not string.find(current, "%[" .. title .. "%]") then
			target:SetAttribute("UnlockedTitles", current .. "[" .. title .. "]")
			-- Auto-equip it for them
			target:SetAttribute("EquippedTitle", title)
		end
	elseif command == "SetClan" then
		target:SetAttribute("Clan", args[1])
	elseif command == "SetTitan" then
		target:SetAttribute("Titan", args[1])
	elseif command == "SetVIP" then
		local isVip = (string.lower(tostring(args[1])) == "true")
		target:SetAttribute("HasVIP", isVip)
	elseif command == "WipePlayer" then
		-- Hard reset stats
		target:SetAttribute("XP", 0)
		target:SetAttribute("TitanXP", 0)
		target.leaderstats.Dews.Value = 0
		target.leaderstats.Prestige.Value = 0
		target.leaderstats.Elo.Value = 1000
		target:SetAttribute("Clan", "None")
		target:SetAttribute("Titan", "None")
		target:SetAttribute("EquippedWeapon", "None")
		target:SetAttribute("EquippedAccessory", "None")
		target:SetAttribute("UnlockedTitles", "")
		target:SetAttribute("EquippedTitle", "None")
	end

	NotificationEvent:FireClient(player, "Executed '"..command.."' on " .. target.Name, "Success")
end)