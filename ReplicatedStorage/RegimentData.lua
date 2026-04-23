-- @ScriptType: ModuleScript

-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local RegimentData = {}

RegimentData.Regiments = {
	["Cadet Corps"] = {
		Icon = "rbxassetid://132795247",
		Description = "New recruits in training. Gaining basic experience.",
		Buff = "No specific buff."
	},
	["Garrison"] = {
		Icon = "rbxassetid://133062844",
		Description = "Protectors of the Walls. Increased defense in missions.",
		Buff = "+10% Defense"
	},
	["Military Police"] = {
		Icon = "rbxassetid://132793466",
		Description = "The inner guard. Increased Dews from all sources.",
		Buff = "+15% Dews"
	},
	["Scout Regiment"] = {
		Icon = "rbxassetid://132793532",
		Description = "The humanity's vanguard. Faster speed in combat.",
		Buff = "+10% Speed"
	}
}

RegimentData.Districts = {
	["Trost District"] = {
		Name = "Trost District",
		Description = "A vital chokepoint. Holding this district grants your Regiment a massive economic advantage.",
		Buff = "+15% Dews from all sources",
		MapPos = UDim2.new(0.5, 0, 0.75, 0),
		LabelPos = UDim2.new(0.5, 0, 1, 8), -- Casts DOWN
		LabelAnchor = Vector2.new(0.5, 0),
		TextAlign = Enum.TextXAlignment.Center
	},
	["Stohess District"] = {
		Name = "Stohess District",
		Description = "The inner wealthy district. Holding this grants enhanced combat training.",
		Buff = "+15% XP Gain",
		MapPos = UDim2.new(0.625, 0, 0.5, 0), 
		LabelPos = UDim2.new(0.5, 0, 0, -8), -- [[ FIX: Casts UP to avoid hitting Karanes ]]
		LabelAnchor = Vector2.new(0.5, 1),
		TextAlign = Enum.TextXAlignment.Center
	},
	["Shiganshina"] = {
		Name = "Shiganshina",
		Description = "The fallen hometown. Reclaiming it inspires your troops in combat.",
		Buff = "+10% Overall Damage",
		MapPos = UDim2.new(0.5, 0, 0.9, 0), 
		LabelPos = UDim2.new(0.5, 0, 1, 8), -- Casts DOWN
		LabelAnchor = Vector2.new(0.5, 0),
		TextAlign = Enum.TextXAlignment.Center
	},
	["Karanes District"] = {
		Name = "Karanes District",
		Description = "A staging ground for expeditions. Grants immense Titan mastery.",
		Buff = "+15% Titan XP",
		MapPos = UDim2.new(0.75, 0, 0.5, 0), 
		LabelPos = UDim2.new(1, 8, 0.5, 0), -- [[ FIX: Casts RIGHT away from the wall ]]
		LabelAnchor = Vector2.new(0, 0.5),
		TextAlign = Enum.TextXAlignment.Left
	}
}

return RegimentData