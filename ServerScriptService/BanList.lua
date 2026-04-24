-- @ScriptType: Script
-- @ScriptType: Script
-- Name: BanList
-- Parent: ServerScriptService

local Players = game:GetService("Players")

-- Format: [UserId] = "Ban Reason"
local BannedUsers = {
	[10813846660] = "Exploiting",
	[8086779562] = "Exploiting",
}

Players.PlayerAdded:Connect(function(player)
	-- Check if the player's UserId exists in the table
	local banReason = BannedUsers[player.UserId]

	if banReason then
		-- Instantly boot them from the server
		player:Kick("You have been permanently banned.\nReason: " .. banReason)
	end
end)