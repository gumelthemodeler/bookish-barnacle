-- @ScriptType: ModuleScript

-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local BountyData = {}

BountyData.Dailies = {
	{Task = "Kill", Desc = "Slay %d Enemies", Min = 10, Max = 25, Reward = 500},
	{Task = "Clear", Desc = "Clear %d Encounters", Min = 5, Max = 15, Reward = 600},
	{Task = "Maneuver", Desc = "Use Maneuver %d times", Min = 10, Max = 20, Reward = 300},
	{Task = "Transform", Desc = "Transform into a Titan %d times", Min = 2, Max = 5, Reward = 400}
}

BountyData.Weeklies = {
	{Task = "Kill", Desc = "Slay %d Enemies", Min = 150, Max = 250, RewardType = "Standard Titan Serum", RewardAmt = 1},
	{Task = "Clear", Desc = "Clear %d Encounters", Min = 75, Max = 150, RewardType = "Clan Blood Vial", RewardAmt = 1}
}

BountyData.Dailies = {
	{Task = "Kill", Desc = "Slay %d Enemies", Min = 10, Max = 25, Reward = 500},
	{Task = "Clear", Desc = "Clear %d Encounters", Min = 5, Max = 15, Reward = 600},
	{Task = "Maneuver", Desc = "Use Maneuver %d times", Min = 10, Max = 20, Reward = 300},
	{Task = "Transform", Desc = "Transform into a Titan %d times", Min = 2, Max = 5, Reward = 400},

	-- Add these two so the server scripts actually have something to update!
	{Task = "Roll", Desc = "Perform %d Gacha Rolls", Min = 5, Max = 15, Reward = 400},
	{Task = "Dispatch", Desc = "Complete %d Expeditions", Min = 2, Max = 5, Reward = 800}
}

return BountyData