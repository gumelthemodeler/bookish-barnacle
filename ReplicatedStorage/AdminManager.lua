-- @ScriptType: ModuleScript

-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local AdminManager = {}

-- Store all Admin UserIDs here for easy management
AdminManager.AdminList = {
	[4068160397] = true, -- girthbender1209
	[4608697584] = true, -- Dev 2
	-- Add more UserIds here as needed:
	-- [123456789] = true,
}

function AdminManager.IsAdmin(player)
	if not player then return false end

	-- Highly recommended to check purely by UserId as Usernames can change,
	-- but we've included a fallback for "girthbender1209" just in case.
	if AdminManager.AdminList[player.UserId] then 
		return true 
	end

	if player.Name == "girthbender1209" then
		return true
	end

	return false
end

return AdminManager