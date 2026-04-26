-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local AdminManager = {}
local RunService = game:GetService("RunService")

-- Store all Admin UserIDs here for easy management
AdminManager.AdminList = {
	[4068160397] = true, -- girthbender1209
	[4608697584] = true, -- Dev 2
	-- Add more UserIds here as needed:
	-- [123456789] = true,
}

function AdminManager.IsAdmin(player)
	if not player then return false end

	-- Automatically grant Admin access to all test clients while in Roblox Studio
	if RunService:IsStudio() then
		return true
	end

	-- Live Game Checks
	if AdminManager.AdminList[player.UserId] then 
		return true 
	end

	if player.Name == "girthbender1209" then
		return true
	end

	return false
end

return AdminManager