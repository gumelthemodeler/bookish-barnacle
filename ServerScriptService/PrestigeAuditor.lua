-- @ScriptType: Script
-- @ScriptType: Script
-- ServerScriptService/PrestigeAuditor.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SkillData = require(ReplicatedStorage:WaitForChild("SkillData"))
local GameData = require(ReplicatedStorage:WaitForChild("GameData"))

local function AuditPrestigePoints(player)
	local ls = player:WaitForChild("leaderstats", 10)
	if not ls then return end

	local prestigeObj = ls:FindFirstChild("Prestige")
	if not prestigeObj then return end

	local totalPrestige = prestigeObj.Value
	if totalPrestige <= 0 then return end

	local spentPoints = 0

	-- [[ THE FIX: Recalculate ALL attributes from owned nodes so players who bought them before the bug fix actually get their stats ]]
	local recalculateStats = {}
	local pNodes = GameData.PrestigeNodes or SkillData.PrestigeNodes or {}

	for id, nodeData in pairs(pNodes) do
		if player:GetAttribute("PrestigeNode_" .. id) then
			spentPoints += nodeData.Cost

			-- Rebuild their stats naturally
			if nodeData.Attr and nodeData.Value then
				recalculateStats[nodeData.Attr] = (recalculateStats[nodeData.Attr] or 0) + nodeData.Value
			end
		end
	end

	-- Apply the retroactively calculated buffs
	for attr, totalVal in pairs(recalculateStats) do
		player:SetAttribute(attr, totalVal)
	end

	-- Calculate what their available points SHOULD be
	local expectedPoints = totalPrestige - spentPoints
	local currentPoints = player:GetAttribute("PrestigePoints") or 0

	-- If they have fewer points than they should, refund them.
	if currentPoints < expectedPoints then
		player:SetAttribute("PrestigePoints", expectedPoints)
		print("[PrestigeAuditor] Refunded " .. (expectedPoints - currentPoints) .. " missing points to " .. player.Name)
	end
end

Players.PlayerAdded:Connect(AuditPrestigePoints)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(AuditPrestigePoints, player)
end