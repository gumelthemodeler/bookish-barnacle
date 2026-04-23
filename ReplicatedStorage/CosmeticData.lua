-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
-- Name: CosmeticData
local CosmeticData = {}

CosmeticData.Titles = {
	["Cadet"] = { Name = "104th Cadet", Desc = "The starting title.", Color = "#FFFFFF", ReqType = "None", ReqValue = 0, Order = 1 },
	["Veteran"] = { Name = "Veteran Elite", Desc = "Reach Prestige 1.", Color = "#55FF55", ReqType = "Prestige", ReqValue = 1, Order = 2 },
	["Vanguard"] = { Name = "Humanity's Vanguard", Desc = "Reach Prestige 5.", Color = "#FFD700", ReqType = "Prestige", ReqValue = 5, Order = 3 },
	["Frenzied"] = { Name = "The Frenzied", Desc = "Defeat the Frenzied Beast Titan in Nightmare Hunts.", Color = "#FF3333", ReqType = "Achievement", ReqValue = "Defeat_Frenzied", Order = 4 },
	["Abyssal"] = { Name = "Abyssal Survivor", Desc = "Defeat the Abyssal Armored Titan in Nightmare Hunts.", Color = "#AA00AA", ReqType = "Achievement", ReqValue = "Defeat_Abyssal", Order = 5 },
	["Coordinate"] = { Name = "The Coordinate", Desc = "Awaken the Founding Attack Titan.", Color = "#55FFFF", ReqType = "Titan", ReqValue = "Founding Attack Titan", Order = 6 },
	["Champion"] = { Name = "Arena Champion", Desc = "Reach 2000 Elo in PVP.", Color = "#55AAFF", ReqType = "Elo", ReqValue = 2000, Order = 7 },
	["Warlord"] = { Name = "Warlord", Desc = "Reach 4000 Elo in PVP.", Color = "#FF55FF", ReqType = "Elo", ReqValue = 4000, Order = 8 },

	-- [[ THE FIX: Added exclusive Top 5 Leaderboard Titles ]]
	["Prestige Apex"] = { Name = "Prestige Apex", Desc = "Hold a Top 5 spot on the Global Prestige Leaderboard.", Color = "#FFD700", ReqType = "Leaderboard", ReqValue = "Top5_Prestige", Order = 9 },
	["Arena Apex"] = { Name = "Arena Apex", Desc = "Hold a Top 5 spot on the Global Elo Leaderboard.", Color = "#55AAFF", ReqType = "Leaderboard", ReqValue = "Top5_Elo", Order = 10 },
	["Squad Apex"] = { Name = "Squad Apex", Desc = "Be in a Top 5 Strike Squad.", Color = "#FF5555", ReqType = "Leaderboard", ReqValue = "Top5_Squad", Order = 11 }
}

CosmeticData.Auras = {
	["None"] = { Name = "None", Desc = "No aura equipped.", ReqType = "None", ReqValue = 0, Order = 1 },
	["Blood Mist"] = { Name = "Blood Mist", Desc = "A terrifying crimson UI glow. (Defeat Frenzied Beast)", ReqType = "Achievement", ReqValue = "Defeat_Frenzied", Color1 = "#FF0000", Color2 = "#440000", Order = 2 },
	["Shadow Step"] = { Name = "Shadow Step", Desc = "A dark, trailing UI aura. (Reach 2000 Elo)", ReqType = "Elo", ReqValue = 2000, Color1 = "#333333", Color2 = "#000000", Order = 3 },
	["Golden Sparks"] = { Name = "Golden Sparks", Desc = "Crackling golden UI energy. (Prestige 5)", ReqType = "Prestige", ReqValue = 5, Color1 = "#FFFF66", Color2 = "#FFCC00", Order = 4 },
	["Paths Aura"] = { Name = "Paths Resonance", Desc = "Glowing cyan UI border. (Prestige 10)", ReqType = "Prestige", ReqValue = 10, Color1 = "#66FFFF", Color2 = "#0099FF", Order = 5 }
}

function CosmeticData.CheckUnlock(player, reqType, reqValue)
	if reqType == "None" then return true end

	if reqType == "Prestige" then
		local prestige = player:GetAttribute("Prestige") or 0
		return prestige >= reqValue
	elseif reqType == "Elo" then
		local elo = player:GetAttribute("Elo") or 1000
		return elo >= reqValue
	elseif reqType == "Achievement" then
		return player:GetAttribute("Ach_" .. reqValue) == true
	elseif reqType == "Titan" then
		local t1 = player:GetAttribute("Titan") or "None"
		if t1 == reqValue then return true end
		for i=1, 6 do if player:GetAttribute("Titan_Slot"..i) == reqValue then return true end end
		return false
	elseif reqType == "Leaderboard" then
		-- [[ THE FIX: Read the globally synced player attributes ]]
		return player:GetAttribute(reqValue) == true
	end
	return false
end

return CosmeticData