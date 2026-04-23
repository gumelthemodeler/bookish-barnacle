-- @ScriptType: Script

-- @ScriptType: Script
-- @ScriptType: Script
-- ServerScriptService/PrestigeAuditor.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameData = require(ReplicatedStorage:WaitForChild("GameData"))

local function AuditPrestigePoints(player)
	-- Wait for leaderstats to load
	local ls = player:WaitForChild("leaderstats", 10)
	if not ls then return end

	local prestigeObj = ls:FindFirstChild("Prestige")
	if not prestigeObj then return end

	local totalPrestige = prestigeObj.Value
	if totalPrestige <= 0 then return end

	-- Calculate how many points the player has already spent
	local spentPoints = 0
	for id, nodeData in pairs(GameData.PrestigeNodes) do
		if player:GetAttribute("PrestigeNode_" .. id) then
			spentPoints += nodeData.Cost
		end
	end

	-- Calculate what their available points SHOULD be
	local expectedPoints = totalPrestige - spentPoints
	local currentPoints = player:GetAttribute("PrestigePoints") or 0

	-- If they have fewer points than they should (because the system is new), refund them.
	if currentPoints < expectedPoints then
		player:SetAttribute("PrestigePoints", expectedPoints)
		print("[PrestigeAuditor] Refunded " .. (expectedPoints - currentPoints) .. " missing points to " .. player.Name)
	end
end

Players.PlayerAdded:Connect(AuditPrestigePoints)

-- Also audit players currently in the game in case you run this mid-session
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(AuditPrestigePoints, player)
end