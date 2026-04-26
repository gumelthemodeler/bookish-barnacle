-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local CombatUI = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = ReplicatedStorage:WaitForChild("Network")
local RunService = game:GetService("RunService")

local SharedUI = script.Parent.Parent:WaitForChild("SharedUI")
local UIHelpers = require(SharedUI:WaitForChild("UIHelpers"))
local SkillData = require(ReplicatedStorage:WaitForChild("SkillData"))
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))
local EnemyData = require(ReplicatedStorage:WaitForChild("EnemyData")) 
local CombatBuilder = require(SharedUI:WaitForChild("CombatBuilder"))
local VFXManager = require(script.Parent.Parent:WaitForChild("VFXManager"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local GUI = nil 
local MasterGuiRef = nil 

local currentBattleState = nil
local pendingSkillName = nil
local inputLocked = false
local isTypewriting = false
local skipTypewriting = false
local ClickSignal = Instance.new("BindableEvent")

local currentPvPMatch = nil
local isSpectating = false
local amIPlayer1 = true
local is3v3Match = false
local myPvPState = nil

local InstantSkills = {
	["Maneuver"] = true, ["Recover"] = true, ["Fall Back"] = true, ["Close In"] = true,
	["Retreat"] = true, ["Transform"] = true, ["Eject"] = true, ["Titan Recover"] = true,
	["Charge"] = true, ["Advance"] = true
}

local doomsdayBoard = nil
local inDoomsdayLoop = false
local ddScroll = nil

local function CreateMinimalButton(parent, text, size, baseColorHex)
	local btn = Instance.new("TextButton", parent)
	btn.Size = size
	btn.BackgroundColor3 = Color3.fromRGB(28, 28, 34) 
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Font = Enum.Font.GothamBlack
	btn.Text = text
	btn.TextScaled = true

	local tsc = Instance.new("UITextSizeConstraint", btn)
	tsc.MaxTextSize = 14
	tsc.MinTextSize = 9

	local cColor = Color3.fromHex(baseColorHex:gsub("#", ""))
	btn.TextColor3 = cColor

	local stroke = Instance.new("UIStroke", btn)
	stroke.Color = Color3.fromRGB(70, 70, 80)
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	btn.MouseEnter:Connect(function() 
		if btn.Active then 
			TweenService:Create(stroke, TweenInfo.new(0.2), {Color = cColor}):Play() 
		end 
	end)
	btn.MouseLeave:Connect(function() 
		if btn.Active then 
			TweenService:Create(stroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(70, 70, 80)}):Play() 
		end 
	end)
	return btn
end

local function ShowWaitingForOpponent()
	if GUI.ActionGrid then GUI.ActionGrid.Visible = false end
	if GUI.TargetMenu then GUI.TargetMenu.Visible = false end

	if GUI.ActionContainer then
		local existing = GUI.ActionContainer:FindFirstChild("WaitContainer")
		if existing then existing:Destroy() end

		local waitContainer = Instance.new("Frame", GUI.ActionContainer)
		waitContainer.Name = "WaitContainer"
		waitContainer.Size = UDim2.new(1, 0, 1, 0)
		waitContainer.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
		waitContainer.BackgroundTransparency = 0.5
		waitContainer.BorderSizePixel = 0

		local waitMsg = UIHelpers.CreateLabel(waitContainer, "WAITING FOR OPPONENT", UDim2.new(1, 0, 1, -20), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 28)
		local dots = UIHelpers.CreateLabel(waitContainer, "X X X", UDim2.new(1, 0, 1, 30), Enum.Font.GothamBlack, Color3.fromRGB(150, 50, 50), 36)

		task.spawn(function()
			local trans = 0; local up = true
			while inputLocked and waitContainer.Parent do
				if up then trans += 0.05 else trans -= 0.05 end
				if trans >= 0.8 then up = false elseif trans <= 0 then up = true end
				waitMsg.TextTransparency = trans
				dots.TextTransparency = trans
				task.wait(0.05)
			end
		end)
	end
end

local function DestroyWaitContainer()
	if GUI.ActionContainer then
		local wc = GUI.ActionContainer:FindFirstChild("WaitContainer")
		if wc then wc:Destroy() end
	end
end

local function OpenTargetMenu()
	if not GUI or not GUI.ActionGrid or not GUI.TargetMenu then return end
	GUI.TargetMenu.Visible = true

	TweenService:Create(GUI.ActionGrid, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = UDim2.new(0.4, -5, 1, 0)}):Play()
	TweenService:Create(GUI.TargetMenu, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Position = UDim2.new(0.4, 5, 0, 0)}):Play()

	if GUI.UpdateLayout then GUI.UpdateLayout() end
end

local function CloseTargetMenu()
	if not GUI or not GUI.ActionGrid or not GUI.TargetMenu then return end

	TweenService:Create(GUI.ActionGrid, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 1, 0)}):Play()
	local t = TweenService:Create(GUI.TargetMenu, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Position = UDim2.new(1, 0, 0, 0)})
	t:Play()

	t.Completed:Connect(function()
		GUI.TargetMenu.Visible = false
		if GUI.UpdateLayout then GUI.UpdateLayout() end
	end)
end

local function SnapTargetMenuClosed()
	if not GUI or not GUI.ActionGrid or not GUI.TargetMenu then return end
	GUI.ActionGrid.Size = UDim2.new(1, 0, 1, 0)
	GUI.TargetMenu.Position = UDim2.new(1, 0, 0, 0)
	GUI.TargetMenu.Visible = false
	if GUI.UpdateLayout then GUI.UpdateLayout() end
end

local function AbbreviateNumber(n)
	local Suffixes = {"", "K", "M", "B", "T", "Qa"}
	if not n then return "0" end; n = tonumber(n) or 0
	if n < 1000 then return tostring(math.floor(n)) end
	local suffixIndex = math.floor(math.log10(n) / 3); local value = n / (10 ^ (suffixIndex * 3))
	local str = string.format("%.1f", value); str = str:gsub("%.0$", "")
	return str .. (Suffixes[suffixIndex + 1] or "")
end

local function BuildDoomsdayBoard()
	if doomsdayBoard then return end
	doomsdayBoard = Instance.new("Frame", MasterGuiRef)
	doomsdayBoard.Size = UDim2.new(0, 200, 0, 150)
	doomsdayBoard.Position = UDim2.new(1, -20, 0, 20)
	doomsdayBoard.AnchorPoint = Vector2.new(1, 0)
	doomsdayBoard.BackgroundTransparency = 1 
	doomsdayBoard.Visible = false
	doomsdayBoard.ZIndex = 50 

	ddScroll = Instance.new("Frame", doomsdayBoard)
	ddScroll.Size = UDim2.new(1, 0, 1, 0)
	ddScroll.BackgroundTransparency = 1

	local layout = Instance.new("UIListLayout", ddScroll)
	layout.Padding = UDim.new(0, 5)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
end

local function UpdateDoomsdayBoard(data)
	if not data or not ddScroll then return end

	for _, c in ipairs(ddScroll:GetChildren()) do
		if c:IsA("TextLabel") then c:Destroy() end
	end

	local titleLbl = Instance.new("TextLabel", ddScroll)
	titleLbl.Size = UDim2.new(0, 200, 0, 20); titleLbl.BackgroundTransparency = 1
	titleLbl.Font = Enum.Font.GothamBlack; titleLbl.TextSize = 14; titleLbl.TextColor3 = Color3.fromRGB(255, 100, 100)
	titleLbl.TextXAlignment = Enum.TextXAlignment.Right; titleLbl.Text = "TOP CONTRIBUTORS"
	local ts1 = Instance.new("UIStroke", titleLbl); ts1.Thickness = 2

	local myRank = nil
	local myDamage = 0

	for i, pData in ipairs(data.Leaderboard or {}) do
		if pData.Name == player.Name then
			myRank = i
			myDamage = pData.Damage
		end

		if i <= 3 then
			local cColor = (i==1) and Color3.fromRGB(255,215,0) or ((i==2) and Color3.fromRGB(200,200,200) or Color3.fromRGB(180,120,60))
			if pData.Name == player.Name then cColor = Color3.fromRGB(100, 255, 100) end

			local entryLbl = Instance.new("TextLabel", ddScroll)
			entryLbl.Size = UDim2.new(0, 200, 0, 16); entryLbl.BackgroundTransparency = 1
			entryLbl.Font = Enum.Font.GothamBold; entryLbl.TextSize = 12; entryLbl.TextColor3 = cColor
			entryLbl.TextXAlignment = Enum.TextXAlignment.Right
			entryLbl.Text = "#" .. i .. " " .. pData.Name .. " - " .. AbbreviateNumber(pData.Damage)
			local ts = Instance.new("UIStroke", entryLbl); ts.Thickness = 2
		end
	end

	local sepLbl = Instance.new("TextLabel", ddScroll)
	sepLbl.Size = UDim2.new(0, 200, 0, 10); sepLbl.BackgroundTransparency = 1
	sepLbl.Font = Enum.Font.GothamMedium; sepLbl.TextSize = 12; sepLbl.TextColor3 = Color3.fromRGB(150, 150, 150)
	sepLbl.TextXAlignment = Enum.TextXAlignment.Right; sepLbl.Text = "..."
	local ts2 = Instance.new("UIStroke", sepLbl); ts2.Thickness = 2

	local meLbl = Instance.new("TextLabel", ddScroll)
	meLbl.Size = UDim2.new(0, 200, 0, 16); meLbl.BackgroundTransparency = 1
	meLbl.Font = Enum.Font.GothamBlack; meLbl.TextSize = 12; meLbl.TextColor3 = Color3.fromRGB(100, 255, 100)
	meLbl.TextXAlignment = Enum.TextXAlignment.Right
	meLbl.Text = (myRank and "#" .. myRank or "UNRANKED") .. " YOU - " .. AbbreviateNumber(myDamage)
	local ts3 = Instance.new("UIStroke", meLbl); ts3.Thickness = 2
end

local function RenderStatuses(container, combatant)
	if not container then return end
	for _, child in ipairs(container:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
	local function addIcon(iconTxt, bgColor, strokeColor)
		local f = Instance.new("Frame", container); f.Size = UDim2.new(0, 24, 0, 18); f.BackgroundColor3 = bgColor; f.BorderSizePixel = 0
		local s = Instance.new("UIStroke", f); s.Color = strokeColor; s.Thickness = 1; s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		local t = Instance.new("TextLabel", f); t.Size = UDim2.new(1, 0, 1, 0); t.BackgroundTransparency = 1; t.Font = Enum.Font.GothamBlack; t.Text = iconTxt; t.TextColor3 = Color3.fromRGB(255,255,255); t.TextScaled = true
	end
	if combatant and combatant.Statuses then
		if combatant.Statuses.Dodge and combatant.Statuses.Dodge > 0 then addIcon("DGE", Color3.fromRGB(30, 60, 120), Color3.fromRGB(60, 100, 200)) end
		if combatant.Statuses.Block and combatant.Statuses.Block > 0 then addIcon("DEF", Color3.fromRGB(80, 80, 150), Color3.fromRGB(150, 150, 255)) end
		if combatant.Statuses.Transformed and combatant.Statuses.Transformed > 0 then addIcon("TTN", Color3.fromRGB(150, 40, 40), Color3.fromRGB(200, 60, 60)) end
		if combatant.Statuses.Enraged and combatant.Statuses.Enraged > 0 then addIcon("RGE", Color3.fromRGB(200, 0, 0), Color3.fromRGB(255, 50, 50)) end
		for sName, duration in pairs(combatant.Statuses) do
			if sName == "Telegraphing" and type(duration) == "string" then addIcon("WRN", Color3.fromRGB(200, 100, 0), Color3.fromRGB(255, 150, 0))
			elseif type(duration) == "number" and duration > 0 and sName ~= "Enraged" and sName ~= "Block" then
				if sName == "Bleed" then addIcon("BLD", Color3.fromRGB(150, 20, 20), Color3.fromRGB(255, 50, 50))
				elseif sName == "Burn" then addIcon("BRN", Color3.fromRGB(200, 80, 20), Color3.fromRGB(255, 120, 50))
				elseif sName == "Stun" then addIcon("STN", Color3.fromRGB(200, 200, 80), Color3.fromRGB(255, 255, 150))
				elseif sName == "Crippled" then addIcon("CRP", Color3.fromRGB(120, 120, 120), Color3.fromRGB(180, 180, 180))
				elseif sName == "Weakened" then addIcon("WEK", Color3.fromRGB(150, 150, 50), Color3.fromRGB(200, 200, 100))
				elseif sName == "Lacerate" then addIcon("LAC", Color3.fromRGB(150, 0, 0), Color3.fromRGB(255, 0, 0))
				elseif sName == "Confusion" then addIcon("CNF", Color3.fromRGB(150, 150, 0), Color3.fromRGB(255, 255, 0))
				elseif sName == "Terror" then addIcon("TRR", Color3.fromRGB(50, 0, 50), Color3.fromRGB(100, 0, 100))
				elseif sName == "CounterStance" then addIcon("CNT", Color3.fromRGB(0, 0, 150), Color3.fromRGB(50, 50, 255))
				end
			end
		end
	end
end

local GlobalLogCounter = 0
local function AppendLog(message, colorHex)
	if not GUI or not GUI.LogScroll or not message or message == "" then return end
	GlobalLogCounter = GlobalLogCounter + 1

	-- [[ THE FIX: SELF-HEALING REGEX ]]
	-- Automatically repairs single-quotes and missing quotes inside <font> tags!
	message = string.gsub(message, "color='(#[%w]+)'", "color=\"%1\"")
	message = string.gsub(message, "color=(#[%w]+)>", "color=\"%1\">")

	local logColor = colorHex and Color3.fromHex(colorHex:gsub("#", "")) or UIHelpers.Colors.TextWhite

	local panel = Instance.new("Frame", GUI.LogScroll)
	panel.LayoutOrder = GlobalLogCounter
	panel.Size = UDim2.new(1, 0, 0, 0); panel.BackgroundColor3 = Color3.fromRGB(18, 18, 22); panel.BackgroundTransparency = 0.3; panel.BorderSizePixel = 0; panel.AutomaticSize = Enum.AutomaticSize.Y
	local pStroke = Instance.new("UIStroke", panel); pStroke.Color = Color3.fromRGB(70, 70, 80); pStroke.Thickness = 2
	local pad = Instance.new("UIPadding", panel); pad.PaddingLeft = UDim.new(0, 10); pad.PaddingRight = UDim.new(0, 10); pad.PaddingTop = UDim.new(0, 8); pad.PaddingBottom = UDim.new(0, 8)

	local lbl = UIHelpers.CreateLabel(panel, message, UDim2.new(1, 0, 0, 0), Enum.Font.GothamMedium, logColor, 12)
	lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.RichText = true; lbl.TextWrapped = true; lbl.AutomaticSize = Enum.AutomaticSize.Y

	local children = GUI.LogScroll:GetChildren()
	local frames = {}
	for _, c in ipairs(children) do if c:IsA("Frame") then table.insert(frames, c) end end

	if #frames > 30 then 
		table.sort(frames, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
		frames[1]:Destroy() 
	end

	task.delay(0.05, function() if GUI.LogScroll then GUI.LogScroll.CanvasPosition = Vector2.new(0, 999999) end end)
end

local function PlayLootAnimation(rewards)
	if not GUI or not GUI.CombatWindow then return end
	task.spawn(function()
		for i, reward in ipairs(rewards) do
			local popup = Instance.new("Frame", GUI.CombatWindow)
			popup.Size = UDim2.new(0, 260, 0, 42)
			local startX = math.random(35, 65) / 100
			local startY = math.random(30, 50) / 100
			popup.Position = UDim2.new(startX, 0, startY, 0)
			popup.AnchorPoint = Vector2.new(0.5, 0.5)
			popup.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
			popup.BackgroundTransparency = 0.1
			popup.ZIndex = 250
			popup.BorderSizePixel = 0
			local stroke = Instance.new("UIStroke", popup); stroke.Color = Color3.fromHex(reward.Color:gsub("#", "")); stroke.Thickness = 2; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

			local lbl = UIHelpers.CreateLabel(popup, reward.Text, UDim2.new(1, 0, 1, 0), Enum.Font.GothamBlack, Color3.fromHex(reward.Color:gsub("#", "")), 16)
			lbl.ZIndex = 251
			local scale = Instance.new("UIScale", popup); scale.Scale = 0

			if VFXManager and type(VFXManager.PlaySFX) == "function" then VFXManager.PlaySFX("Reveal", 1.0 + (i * 0.05)) end
			TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
			local floatTween = TweenService:Create(popup, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Position = UDim2.new(startX + math.random(-10, 10)/100, 0, startY - 0.15, 0)})
			floatTween:Play()

			task.delay(0.8, function()
				local suckTween = TweenService:Create(popup, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0.1, 0, 0.45, 0)})
				local scaleDown = TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0})
				suckTween:Play(); scaleDown:Play(); suckTween.Completed:Wait()
				AppendLog("<font color=\"" .. reward.Color .. "\">Looted: " .. reward.Text .. "</font>")
				popup:Destroy()
			end)
			task.wait(0.15) 
		end
	end)
end

local function HideAlly()
	if GUI and GUI.AllyPanel and GUI.PlayerPanel then
		TweenService:Create(GUI.AllyPanel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(-0.5, 0, 0, 0)}):Play()
		TweenService:Create(GUI.PlayerPanel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play()
	end
end

local function GetTitanSkills(titanName)
	if not titanName or titanName == "None" then return {} end
	local movesets = {
		["Attack Titan"] = {"Berserk Rush", "Future Memories"},
		["Jaw Titan"] = {"Frenzied Thrash", "Agile Leap", "Crushing Bite"},
		["Cart Titan"] = {"Titan Bite", "Endurance Run", "Panzer Artillery"},
		["Armored Titan"] = {"Hardened Punch", "Armored Tackle", "Shattering Charge"},
		["Female Titan"] = {"Crystal Kick", "Nape Guard", "Attraction Scream"}, 
		["War Hammer Titan"] = {"Hardened Punch", "Crossbow Construct", "War Hammer Spike"},
		["Beast Titan"] = {"Crushed Boulders", "Pitching Ace", "Titan Roar"},
		["Colossal Titan"] = {"Brutal Swipe", "Devastating Kick", "Colossal Steam"},
		["Founding Titan"] = {"Titan Roar", "Coordinate Command"}, 
		["Founding Female Titan"] = {"Crystal Kick", "Attraction Scream", "Nape Guard", "Coordinate Command"},
		["Armored Attack Titan"] = {"Berserk Rush", "Armored Tackle", "Shattering Charge"},
		["War Hammer Attack Titan"] = {"Berserk Rush", "Crossbow Construct", "War Hammer Spike"},
		["Colossal Jaw Titan"] = {"Crushing Bite", "Devastating Kick", "Colossal Steam"},
		["Founding Attack Titan"] = {"Berserk Rush", "Future Memories", "Coordinate Command"}
	}
	return movesets[titanName] or {}
end

local function IsSkillValid(player, skillName, isTransformedCheck)
	local sData = SkillData.Skills[skillName]
	if not sData then return false end

	local req = tostring(sData.Requirement or "None")

	local universalMoves = { 
		["Maneuver"]=true, ["Evasive Maneuver"]=true, ["Block"]=true, 
		["Close In"]=true, ["Fall Back"]=true, ["Advance"]=true, ["Charge"]=true, 
		["Recover"]=true, ["Retreat"]=true, ["Flee"]=true, ["Transform"]=true,
		["Basic Slash"]=true, ["Heavy Slash"]=true, ["Flare Gun"]=true, ["Anti-Titan Rifle"]=true
	}

	if isTransformedCheck then
		local titanMoves = { ["Eject"]=true, ["Titan Recover"]=true, ["Titan Rest"]=true, ["Cannibalize"]=true, ["Titan Punch"]=true, ["Titan Kick"]=true }
		local myTitan = player:GetAttribute("Titan") or "None"

		if titanMoves[skillName] then return true end

		local validHybridMoves = GetTitanSkills(myTitan)
		for _, m in ipairs(validHybridMoves) do
			if m == skillName then return true end
		end

		local humanWeapons = {["Basic Slash"]=true, ["Heavy Slash"]=true, ["Flare Gun"]=true, ["Anti-Titan Rifle"]=true}
		if universalMoves[skillName] and not humanWeapons[skillName] then
			return true
		end

		if req == "Transformed" or req == "AnyTitan" or req == myTitan or string.find(myTitan, req, 1, true) then
			return true
		end

		return false
	end

	if universalMoves[skillName] then return true end
	if req == "None" or req == "ODM" then return true end

	local myClan = player:GetAttribute("Clan") or "None"
	if myClan ~= "None" then
		if string.find(myClan, req, 1, true) then return true end
		if string.find(req, "Awakened", 1, true) then
			local baseReq = string.gsub(req, "Awakened ", "")
			if string.find(myClan, "Abyssal " .. baseReq, 1, true) then return true end
		end
	end

	if type(ItemData) == "table" and ItemData.Equipment then
		for iName, iData in pairs(ItemData.Equipment) do
			if iData.Style == req then
				local safeNameBase = iName:gsub("[^%w]", "")
				local count = tonumber(player:GetAttribute(safeNameBase .. "Count")) or tonumber(player:GetAttribute(iName)) or 0
				if count > 0 then return true end
			end
		end
	end

	return false
end

local function UpdatePvESkills()
	inputLocked = false
	SnapTargetMenuClosed()
	DestroyWaitContainer()

	if GUI.ActionGrid then 
		GUI.ActionGrid.Visible = true
		for _, c in ipairs(GUI.ActionGrid:GetChildren()) do if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end end 
	end

	local currentRange = "Close"
	local pState = currentBattleState and currentBattleState.Player or nil
	if currentBattleState and currentBattleState.Context and currentBattleState.Context.Range then currentRange = currentBattleState.Context.Range end

	local enemyTelegraph = currentBattleState and currentBattleState.Enemy and currentBattleState.Enemy.Statuses and currentBattleState.Enemy.Statuses["Telegraphing"]
	local isTransformed = pState and pState.Statuses and pState.Statuses["Transformed"]

	local defaultClose = {"Basic Slash", "Heavy Slash", "None", "None"}
	local defaultLong = {"Flare Gun", "Anti-Titan Rifle", "None", "None"}
	local titanFallbacks = {"None", "None", "None", "None"}

	local fallbacks = isTransformed and titanFallbacks or ((currentRange == "Close") and defaultClose or defaultLong)
	local createdSkills = {}

	local function CreateSkillButton(skillName, customLabel, baseColor)
		if skillName == "None" or not GUI.ActionGrid then return end
		if createdSkills[skillName] then return end
		createdSkills[skillName] = true

		local sData = SkillData.Skills[skillName]
		local cd = (pState and pState.Cooldowns and tonumber(pState.Cooldowns[skillName])) or 0
		local hasGas, hasHeat, isWrongRange, isClashable = true, true, false, false

		if sData then
			local actualCost = tonumber(sData.GasCost)
			if actualCost then
				local terrain = "City"
				if currentBattleState and currentBattleState.Context and currentBattleState.Context.Terrain then terrain = currentBattleState.Context.Terrain end
				if terrain == "Forest" then actualCost = math.ceil(actualCost * 0.5)
				elseif terrain == "Plains" then actualCost = math.ceil(actualCost * 1.5) end
			end

			local currentGas = tonumber(pState and pState.Gas) or 0
			if not isTransformed and actualCost and currentGas < actualCost then hasGas = false end

			local energyCost = tonumber(sData.EnergyCost)
			if energyCost and (tonumber(pState and pState.TitanEnergy) or 0) < energyCost then hasHeat = false end

			if sData.Range and sData.Range ~= "Any" and sData.Range ~= currentRange then isWrongRange = true end

			if enemyTelegraph and (tonumber(sData.Mult) or 0) >= 3.0 and sData.Effect ~= "Block" and sData.Effect ~= "Dodge" then
				isClashable = true
			end
		end

		if skillName == "Retreat" or skillName == "Flee" then
			hasGas = true
			isWrongRange = false
		elseif skillName == "Close In" or skillName == "Charge" or skillName == "Advance" then
			if currentRange == "Close" then isWrongRange = true else isWrongRange = false end
		elseif skillName == "Fall Back" then
			if currentRange == "Long" then isWrongRange = true else isWrongRange = false end
		end

		local btnText = customLabel or string.upper(skillName)
		local btnColor = baseColor or "#DDDDDD"
		local isActive = true
		local errorReason = ""

		if cd > 0 then isActive = false; errorReason = " [CD: " .. cd .. "]"
		elseif not hasGas then isActive = false; errorReason = " [NO GAS]"
		elseif not hasHeat then isActive = false; errorReason = " [NO HEAT]"
		elseif isWrongRange then isActive = false; btnColor = "#555555"; errorReason = " [OUT OF RANGE]" end

		btnText = btnText .. errorReason
		if not isActive then btnColor = "#555555" end

		if isClashable and isActive then
			btnText = "⚔️ " .. btnText
			btnColor = "#FF3333"
		end

		local btn = CreateMinimalButton(GUI.ActionGrid, btnText, UDim2.new(0, 0, 0, 0), btnColor)

		if not isActive then
			btn.TextColor3 = Color3.fromRGB(100, 100, 100)
			local stroke = btn:FindFirstChild("UIStroke"); if stroke then stroke.Color = Color3.fromRGB(50, 50, 50) end

			btn.MouseButton1Click:Connect(function()
				if inputLocked then return end
				if string.find(errorReason, "NO GAS") then
					if VFXManager and type(VFXManager.PlaySFX) == "function" then VFXManager.PlaySFX("GasHiss", 1.0) end
				end
			end)
		else
			if isWrongRange then btn.TextColor3 = Color3.fromRGB(255, 170, 85) end

			local isInstant = false
			if InstantSkills[skillName] or skillName == "Flee" or skillName == "Retreat" or isClashable then
				isInstant = true
			end

			if sData then
				local e = sData.Effect
				if e == "Block" or e == "Dodge" or e == "Rest" or e == "TitanRest" or e == "RestoreHeat" or e == "NapeGuard" or (e and string.find(e, "Buff_")) then
					isInstant = true
				end
				if skillName == "Titan Roar" or skillName == "Coordinate Command" or skillName == "Attraction Scream" then
					isInstant = true
				end
			end

			btn.MouseButton1Click:Connect(function()
				if inputLocked then return end
				inputLocked = true 
				HideAlly()

				if isInstant then
					local wasPaths = (skillName == "Retreat" or skillName == "Flee") and currentBattleState and currentBattleState.Context and currentBattleState.Context.IsPaths

					for _, c in ipairs(GUI.ActionGrid:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
					local waitContainer = Instance.new("Frame", GUI.ActionContainer)
					waitContainer.Name = "WaitContainer"
					waitContainer.Size = UDim2.new(1, 0, 1, 0)
					waitContainer.BackgroundTransparency = 1
					UIHelpers.CreateLabel(waitContainer, "EXECUTING...", UDim2.new(1, 0, 1, 0), Enum.Font.GothamBlack, UIHelpers.Colors.TextMuted, 22)

					Network:WaitForChild("CombatAction"):FireServer("Attack", {SkillName = skillName})

					if wasPaths then
						task.delay(1.5, function()
							local pathsModule = player.PlayerScripts:WaitForChild("UIModules"):FindFirstChild("PathsShopUI")
							if pathsModule and pathsModule:IsA("ModuleScript") then require(pathsModule).OpenShop() end
						end)
					end
				else
					pendingSkillName = skillName
					OpenTargetMenu()
					inputLocked = false 
				end
			end)
		end
	end

	if isTransformed then
		CreateSkillButton("Titan Punch", "TITAN PUNCH", "#FF5555")
		CreateSkillButton("Titan Kick", "TITAN KICK", "#FF5555")
	end

	for i = 1, 4 do
		local skillName = player:GetAttribute("EquippedSkill_" .. i)
		if not skillName or skillName == "" or skillName == "None" or not IsSkillValid(player, skillName, isTransformed) then 
			skillName = fallbacks[i] 
		end
		if isTransformed and (skillName == "Titan Punch" or skillName == "Titan Kick") then continue end
		CreateSkillButton(skillName)
	end

	if isTransformed then
		local myTitan = player:GetAttribute("Titan")
		if myTitan and myTitan ~= "None" then
			local titanSkills = GetTitanSkills(myTitan)
			for _, tSkill in ipairs(titanSkills) do
				CreateSkillButton(tSkill, "[" .. string.upper(myTitan) .. "] " .. string.upper(tSkill), "#FFD700")
			end
		end
	else
		local myClan = player:GetAttribute("Clan") or "None"
		if myClan ~= "None" then
			local clanSkills = {}
			for sName, sData in pairs(SkillData.Skills) do
				if sData.Type == "Style" and sData.Requirement and not string.find(sData.Requirement, "ODM") then
					local req = tostring(sData.Requirement)
					if string.find(myClan, req, 1, true) then 
						table.insert(clanSkills, {Name = sName, Data = sData}) 
					elseif string.find(req, "Awakened", 1, true) then
						local baseReq = string.gsub(req, "Awakened ", "")
						if string.find(myClan, "Abyssal " .. baseReq, 1, true) then
							table.insert(clanSkills, {Name = sName, Data = sData}) 
						end
					end
				end
			end
			table.sort(clanSkills, function(a, b) return (a.Data.Order or 99) < (b.Data.Order or 99) end)
			for _, cSkill in ipairs(clanSkills) do CreateSkillButton(cSkill.Name, "[" .. string.upper(myClan) .. "] " .. string.upper(cSkill.Name), "#CC44FF") end
		end
	end

	CreateSkillButton("Maneuver", "MANEUVER", "#55AAFF")

	if isTransformed then
		CreateSkillButton("Titan Recover", "TITAN RECOVER", "#55FF55")
		CreateSkillButton("Cannibalize", "CANNIBALIZE", "#FF5555")
		CreateSkillButton("Eject", "EJECT", "#FFD700")
	else
		CreateSkillButton("Recover", "RECOVER", "#55FF55")
		local myCurrentClan = player:GetAttribute("Clan") or "None"
		local isAckerman = string.find(myCurrentClan, "Ackerman", 1, true) ~= nil
		local hasTitan = player:GetAttribute("Titan") and player:GetAttribute("Titan") ~= "None"
		if hasTitan and not isAckerman then 
			CreateSkillButton("Transform", "TRANSFORM", "#FFD700")
		end
	end

	if currentRange == "Close" then CreateSkillButton("Fall Back", "FALL BACK", "#FFAA55")
	else CreateSkillButton("Close In", isTransformed and "CHARGE" or "CLOSE IN", "#FFAA55") end

	CreateSkillButton("Retreat", "FLEE", "#FF5555")
end

local function UpdateState(data)
	if not data or not data.Battle or not GUI then return end
	currentBattleState = data.Battle; local battle = data.Battle
	local tInfo = TweenInfo.new(0.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)

	local ctx = battle.Context
	if ctx and GUI.MissionInfoLbl then
		local modeStr = "UNKNOWN ENGAGEMENT"
		if ctx.IsStoryMission then modeStr = "STORY CAMPAIGN | PART " .. (ctx.TargetPart or 1) .. " - WAVE " .. (ctx.CurrentWave or 1)
		elseif ctx.IsEndless then modeStr = "ENDLESS FRONTIER | WAVE " .. (ctx.CurrentWave or 1)
		elseif ctx.IsNightmare then modeStr = "NIGHTMARE HUNT"
		elseif ctx.IsWorldBoss then modeStr = "WORLD BOSS RAID" end

		if battle.Enemy.IsDoomsdayBoss then modeStr = "DOOMSDAY BOUNTY: THE PRIMORDIAL THREAT" end

		GUI.MissionInfoLbl.Text = modeStr .. "  [" .. (ctx.Range and ctx.Range:upper() or "CLOSE") .. " RANGE]"
	end

	if battle.Enemy.IsDoomsdayBoss then
		BuildDoomsdayBoard()
		doomsdayBoard.Visible = true
		if not inDoomsdayLoop then
			inDoomsdayLoop = true
			task.spawn(function()
				while inDoomsdayLoop do
					local remote = Network:WaitForChild("GetDoomsdayData", 3)
					if remote then
						local dData = remote:InvokeServer()
						UpdateDoomsdayBoard(dData)

						if dData and dData.MaxHP and dData.BossHP then
							if GUI.eHPText then GUI.eHPText.Text = "GLOBAL HP: " .. AbbreviateNumber(dData.BossHP) end
							if GUI.eHPBar then TweenService:Create(GUI.eHPBar, tInfo, {Size = UDim2.new(dData.MaxHP > 0 and math.clamp(dData.BossHP / dData.MaxHP, 0, 1) or 0, 0, 1, 0)}):Play() end
						end
					end
					task.wait(3)
				end
			end)
		end
	else
		if doomsdayBoard then doomsdayBoard.Visible = false end
		inDoomsdayLoop = false
	end

	if battle.Player then
		local safeHP = math.max(0, battle.Player.HP or 0); local maxHP = battle.Player.MaxHP or 100
		if GUI.pHPText then GUI.pHPText.Text = "HP " .. math.floor(safeHP) .. "/" .. math.floor(maxHP) end
		if GUI.pHPBar then TweenService:Create(GUI.pHPBar, tInfo, {Size = UDim2.new(maxHP > 0 and math.clamp(safeHP / maxHP, 0, 1) or 0, 0, 1, 0)}):Play() end

		local gas = battle.Player.Gas or 0; local maxGas = battle.Player.MaxGas or 50
		if GUI.pGasText then GUI.pGasText.Text = "GAS " .. math.floor(gas) .. "/" .. math.floor(maxGas) end
		if GUI.pGasBar then TweenService:Create(GUI.pGasBar, tInfo, {Size = UDim2.new(maxGas > 0 and math.clamp(gas / maxGas, 0, 1) or 0, 0, 1, 0)}):Play() end

		local heat = battle.Player.TitanEnergy or 0; local maxHeat = battle.Player.MaxTitanEnergy or 100
		if GUI.pHeatText then GUI.pHeatText.Text = "HEAT " .. math.floor(heat) .. "/" .. math.floor(maxHeat) end
		if GUI.pHeatBar then TweenService:Create(GUI.pHeatBar, tInfo, {Size = UDim2.new(maxHeat > 0 and math.clamp(heat / maxHeat, 0, 1) or 0, 0, 1, 0)}):Play() end

		local hpRatio = safeHP / maxHP
		if VFXManager and type(VFXManager.ToggleHeartbeat) == "function" then
			VFXManager.ToggleHeartbeat(hpRatio <= 0.25 and safeHP > 0)
		end
	end

	if battle.Enemy then 
		if GUI.eNameLbl then GUI.eNameLbl.Text = (battle.Enemy.Name or "UNKNOWN"):upper() end
		if EnemyData and EnemyData.BossIcons and EnemyData.BossIcons[battle.Enemy.Name] then
			if GUI.eAvatar then GUI.eAvatar.Image = EnemyData.BossIcons[battle.Enemy.Name] end
		else
			if GUI.eAvatar then GUI.eAvatar.Image = "rbxassetid://90132878979603" end
		end

		if battle.Enemy.IsDialogue then
			if GUI.eHPText and GUI.eHPText.Parent then GUI.eHPText.Parent.Visible = false end
			if GUI.eGateContainer then GUI.eGateContainer.Visible = false end
		else
			if GUI.eHPText and GUI.eHPText.Parent then GUI.eHPText.Parent.Visible = true end

			if not battle.Enemy.IsDoomsdayBoss then
				local safeHP = math.max(0, battle.Enemy.HP or 0); local maxHP = battle.Enemy.MaxHP or 100
				if GUI.eHPText then GUI.eHPText.Text = "HP " .. math.floor(safeHP) .. "/" .. math.floor(maxHP) end
				if GUI.eHPBar then TweenService:Create(GUI.eHPBar, tInfo, {Size = UDim2.new(maxHP > 0 and math.clamp(safeHP / maxHP, 0, 1) or 0, 0, 1, 0)}):Play() end
			end

			local maxGate = battle.Enemy.MaxGateHP or 0
			local safeGate = math.max(0, battle.Enemy.GateHP or 0)
			if safeGate > maxGate then maxGate = safeGate end 

			if maxGate > 0 and safeGate > 0 then
				if GUI.eGateContainer then GUI.eGateContainer.Visible = true end
				local gateLabel = (battle.Enemy.GateType == "Steam") and "STEAM " or "ARMOR "
				if GUI.eGateText then GUI.eGateText.Text = gateLabel .. math.floor(safeGate) .. "/" .. math.floor(maxGate) end
				local fillRatio = math.clamp(safeGate / maxGate, 0, 1)
				if GUI.eGateBar then TweenService:Create(GUI.eGateBar, tInfo, {Size = UDim2.new(fillRatio, 0, 1, 0)}):Play() end
				if GUI.eHPText then GUI.eHPText.Visible = false end
			else
				if GUI.eGateContainer then GUI.eGateContainer.Visible = false end
				if GUI.eHPText then GUI.eHPText.Visible = true end
			end
		end

		if GUI.eAvatar then
			local stroke = GUI.eAvatar:FindFirstChild("UIStroke")
			if stroke then
				if battle.Enemy.Statuses and battle.Enemy.Statuses["Enraged"] then
					TweenService:Create(stroke, TweenInfo.new(0.3), {Color = Color3.fromRGB(255, 0, 0), Thickness = 3}):Play()
				else
					TweenService:Create(stroke, TweenInfo.new(0.3), {Color = Color3.fromRGB(255, 85, 85), Thickness = 2}):Play()
				end
			end
		end
	end

	RenderStatuses(GUI.PlayerStatusBox, battle.Player)
	RenderStatuses(GUI.EnemyStatusBox, battle.Enemy)
end

local function ShowPvEUI(data)
	pendingSkillName = nil
	inputLocked = false
	HideAlly()

	if GUI.ExecuteOverlay then GUI.ExecuteOverlay.Visible = false end

	if GUI.CombatBackdrop then
		GUI.CombatBackdrop.BackgroundColor3 = Color3.new(0, 0, 0)
		GUI.CombatBackdrop.Visible = true
		TweenService:Create(GUI.CombatBackdrop, TweenInfo.new(0.4), {BackgroundTransparency = 0.4}):Play()
	end

	if GUI.CombatWindow then 
		GUI.CombatWindow.Visible = true 
		if GUI.WindowScale then TweenService:Create(GUI.WindowScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play() end
	end

	if GUI.PlayerPanel then GUI.PlayerPanel.Position = UDim2.new(0, 0, 0, 0) end
	if GUI.AllyPanel then GUI.AllyPanel.Position = UDim2.new(-0.5, 0, 0, 0) end

	if GUI.CombatantsFrame then GUI.CombatantsFrame.Visible = true end
	if GUI.LogContainer then GUI.LogContainer.Visible = true end
	if GUI.ActionContainer then GUI.ActionContainer.Visible = true end
	if GUI.DialogueBox then GUI.DialogueBox.Visible = false end
	if GUI.ClickOverlay then GUI.ClickOverlay.Visible = false end

	if GUI.LogScroll then
		for _, c in ipairs(GUI.LogScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
	end

	AppendLog("<b>[SYSTEM] Tactical Engagement Initiated.</b>", "#FFD700")

	if data and data.LogMsg then AppendLog(data.LogMsg) end

	if data and data.Battle then
		if data.Battle.Enemy and data.Battle.Enemy.IsDialogue and GUI.CombatantsFrame then
			GUI.CombatantsFrame.Visible = false
		end
		UpdateState(data)
	else
		UpdateState({
			Battle = {
				Context = {IsStoryMission = true, TargetPart = 1, CurrentWave = 1, Range = "Close"},
				Player = {HP = player:GetAttribute("Health") or 100, MaxHP = player:GetAttribute("MaxHealth") or 100, Gas = player:GetAttribute("Gas") or 50, MaxGas = 50, TitanEnergy = 0, MaxTitanEnergy = 100},
				Enemy = {Name = "Wandering Titan", HP = 500, MaxHP = 500}
			}
		})
	end
	UpdatePvESkills()
end

local function CloseUI(forcePathsOpen)
	currentPvPMatch = nil
	currentBattleState = nil
	pendingSkillName = nil
	inputLocked = true
	HideAlly()

	if doomsdayBoard then doomsdayBoard.Visible = false end
	inDoomsdayLoop = false

	SnapTargetMenuClosed()
	DestroyWaitContainer()

	if GUI.ExecuteOverlay then GUI.ExecuteOverlay.Visible = false end

	if VFXManager and type(VFXManager.ToggleHeartbeat) == "function" then 
		VFXManager.ToggleHeartbeat(false) 
	end

	if GUI.WindowScale then
		local t1 = TweenService:Create(GUI.WindowScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Scale = 0})
		t1:Play(); t1.Completed:Wait()
	end

	if GUI.CombatBackdrop then
		local t2 = TweenService:Create(GUI.CombatBackdrop, TweenInfo.new(0.2), {BackgroundTransparency = 1})
		t2:Play(); GUI.CombatBackdrop.Visible = false
	end

	if GUI.CombatWindow then GUI.CombatWindow.Visible = false end

	local hasMusic, MusicManager = pcall(function() return require(player.PlayerScripts:WaitForChild("MusicManager")) end)
	if hasMusic and MusicManager then MusicManager.SetCategory("Lobby") end

	if forcePathsOpen then
		task.delay(0.2, function()
			local pathsModule = player.PlayerScripts:WaitForChild("UIModules"):FindFirstChild("PathsShopUI")
			if pathsModule and pathsModule:IsA("ModuleScript") then require(pathsModule).OpenShop() end
		end)
	end
end

-- ==========================================
-- INITIALIZATION
-- ==========================================

function CombatUI.Initialize(masterScreenGui)
	MasterGuiRef = masterScreenGui
	GUI = CombatBuilder.Build(masterScreenGui, player)

	GUI.ClickOverlay.MouseButton1Click:Connect(function()
		if isTypewriting then skipTypewriting = true else ClickSignal:Fire() end
	end)

	for targetId, limbBtn in pairs(GUI.Limbs) do
		limbBtn.MouseButton1Click:Connect(function()
			if pendingSkillName and not inputLocked then
				local trueTarget = targetId
				if targetId == "LArm" or targetId == "RArm" then trueTarget = "Arms" end
				if targetId == "LLeg" or targetId == "RLeg" then trueTarget = "Legs" end

				if currentPvPMatch then
					inputLocked = true
					HideAlly()
					CloseTargetMenu()
					ShowWaitingForOpponent()
					Network:WaitForChild("PvPAction"):FireServer("SubmitMoveSequence", currentPvPMatch, {{Move = pendingSkillName, Limb = trueTarget}})
					pendingSkillName = nil
				else
					inputLocked = true
					HideAlly()
					CloseTargetMenu()

					if GUI.ActionGrid then GUI.ActionGrid.Visible = false end
					local waitContainer = Instance.new("Frame", GUI.ActionContainer)
					waitContainer.Name = "WaitContainer"
					waitContainer.Size = UDim2.new(1, 0, 1, 0)
					waitContainer.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
					waitContainer.BackgroundTransparency = 0.5
					waitContainer.BorderSizePixel = 0
					UIHelpers.CreateLabel(waitContainer, "EXECUTING...", UDim2.new(1, 0, 1, 0), Enum.Font.GothamBlack, UIHelpers.Colors.TextMuted, 22)

					Network:WaitForChild("CombatAction"):FireServer("Attack", {SkillName = pendingSkillName, TargetLimb = trueTarget})
					pendingSkillName = nil
				end
			end
		end)
	end

	GUI.CancelBtn.MouseButton1Click:Connect(function()
		CloseTargetMenu()
		pendingSkillName = nil 
	end)

	Network:WaitForChild("PvPUpdate").OnClientEvent:Connect(function(action, matchId, d1, d2, d3, d4, d5, d6, d7, d8, d9)
		if action == "MatchStarted" then
			local p1Name, p2Name, p1Id, p2Id, turnEndTime, is3v3, t1Ids, t2Ids = d1, d2, d3, d4, d5, d6, d7, d8

			local amIInvolved = false
			if is3v3 and t1Ids and t2Ids then
				if table.find(t1Ids, player.UserId) then amIInvolved = true; amIPlayer1 = true
				elseif table.find(t2Ids, player.UserId) then amIInvolved = true; amIPlayer1 = false end
			else
				if p1Id == player.UserId then amIInvolved = true; amIPlayer1 = true
				elseif p2Id == player.UserId then amIInvolved = true; amIPlayer1 = false end
			end

			if amIInvolved then
				currentPvPMatch = matchId
				isSpectating = false
				ShowPvPUI(p1Name, p2Name, p1Id, p2Id, turnEndTime, is3v3)
			end
		elseif action == "SpectateStarted" then
			local p1Name, p2Name, p1Id, p2Id, turnEndTime, p1Hp, p1Max, p2Hp, p2Max = d1, d2, d3, d4, d5, d6, d7, d8, d9
			currentPvPMatch = matchId
			isSpectating = true
			amIPlayer1 = true
			ShowPvPUI(p1Name, p2Name, p1Id, p2Id, turnEndTime, false)
		elseif action == "TurnStrike" and currentPvPMatch == matchId then
			local data = d1
			UpdatePvPState(data)
			if data and data.LogMsg then AppendLog(data.LogMsg) end 
		elseif action == "NextTurnStarted" and currentPvPMatch == matchId then
			local turnNum, turnEndTime = d1, d2
			inputLocked = false
			UpdatePvPSkills()
		elseif action == "MatchEnded" and currentPvPMatch == matchId then
			local winnerTeam = d1
			if winnerTeam == "Draw" then
				AppendLog("<b>MATCH ENDED IN A DRAW!</b>", "#AAAAAA")
			elseif (winnerTeam == "Team1" and amIPlayer1) or (winnerTeam == "Team2" and not amIPlayer1) then
				AppendLog("<b><font color=\"#55FF55\">YOU WON THE MATCH!</font></b>", "#55FF55")
			else
				if isSpectating then
					AppendLog("<b><font color=\"#FFAA00\">MATCH HAS CONCLUDED.</font></b>", "#FFAA00")
				else
					AppendLog("<b><font color=\"#FF5555\">YOU WERE DEFEATED.</font></b>", "#FF5555")
				end
			end
			inputLocked = true
			task.delay(3, CloseUI)
		end
	end)

	Network:WaitForChild("CombatUpdate").OnClientEvent:Connect(function(action, data)
		local success, err = pcall(function()
			if action == "Start" or action == "StartMinigame" then
				ShowPvEUI(data)

			elseif action == "Update" then
				if GUI.CombatantsFrame then GUI.CombatantsFrame.Visible = true end
				if GUI.LogContainer then GUI.LogContainer.Visible = true end
				if GUI.ActionContainer then GUI.ActionContainer.Visible = true end
				if GUI.DialogueBox then GUI.DialogueBox.Visible = false end
				if GUI.ClickOverlay then GUI.ClickOverlay.Visible = false end
				UpdateState(data)
				UpdatePvESkills()

			elseif action == "Dialogue" then
				if GUI.CombatWindow and not GUI.CombatWindow.Visible then
					if GUI.CombatBackdrop then GUI.CombatBackdrop.Visible = true; TweenService:Create(GUI.CombatBackdrop, TweenInfo.new(0.4), {BackgroundTransparency = 0.4}):Play() end
					GUI.CombatWindow.Visible = true
					if GUI.WindowScale then TweenService:Create(GUI.WindowScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play() end
				end

				if GUI.CombatantsFrame then GUI.CombatantsFrame.Visible = true end
				UpdateState(data)

				inputLocked = true
				if GUI.LogContainer then GUI.LogContainer.Visible = false end
				if GUI.ActionContainer then GUI.ActionContainer.Visible = false end
				if GUI.DialogueBox then GUI.DialogueBox.Visible = true end

				task.spawn(function()
					GUI.ClickOverlay.Visible = true
					GUI.ChoicesContainer.Visible = false

					local dialoguesArray = data.Dialogues or { { Speaker = data.Speaker or "Unknown", Text = data.Text or "..." } }

					for _, line in ipairs(dialoguesArray) do
						GUI.SpeakerLbl.Text = line.Speaker or "Unknown"
						GUI.SpeakerLbl.TextColor3 = (line.Speaker == "System") and UIHelpers.Colors.TextMuted or UIHelpers.Colors.Gold

						if EnemyData and EnemyData.BossIcons and EnemyData.BossIcons[line.Speaker] then
							if GUI.eAvatar then GUI.eAvatar.Image = EnemyData.BossIcons[line.Speaker] end
						else
							if GUI.eAvatar then GUI.eAvatar.Image = "rbxassetid://90132878979603" end
						end
						if GUI.eNameLbl then GUI.eNameLbl.Text = string.upper(line.Speaker or "Unknown") end

						GUI.DialogueText.Text = ""
						GUI.DialogueText.Visible = true
						isTypewriting = true; skipTypewriting = false

						for charIdx = 1, #(line.Text or "") do
							if skipTypewriting then GUI.DialogueText.Text = line.Text; break end
							GUI.DialogueText.Text = string.sub(line.Text, 1, charIdx)
							if charIdx % 2 == 0 then
								if VFXManager and type(VFXManager.PlaySFX) == "function" then VFXManager.PlaySFX("Click", 1.8, 0.1) end
							end
							task.wait(0.008)
						end
						isTypewriting = false
						if GUI.ContinueHint then GUI.ContinueHint.Visible = true end
						ClickSignal.Event:Wait()
						if GUI.ContinueHint then GUI.ContinueHint.Visible = false end
					end

					GUI.ClickOverlay.Visible = false
					GUI.DialogueText.Visible = false
					GUI.ChoicesContainer.Visible = true

					for _, c in ipairs(GUI.ChoicesContainer:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end

					local choicesArray = data.Choices or {"CONTINUE STORY"}
					for idx, choiceText in ipairs(choicesArray) do
						local btn = CreateMinimalButton(GUI.ChoicesContainer, choiceText, UDim2.new(0, 300, 0, 40), "#55FF55")
						btn.MouseButton1Click:Connect(function()
							GUI.DialogueBox.Visible = false
							if GUI.LogContainer then GUI.LogContainer.Visible = true end
							if GUI.ActionContainer then GUI.ActionContainer.Visible = true end

							local rewards = data.Battle and data.Battle.Enemy and data.Battle.Enemy.Rewards
							local animRewards = {}
							if rewards then
								if rewards.ItemName then table.insert(animRewards, {Text = "+" .. (rewards.Amount or 1) .. " " .. rewards.ItemName, Color = "#FFD700"}) end
								if rewards.Dews then table.insert(animRewards, {Text = "+" .. rewards.Dews .. " Dews", Color = "#55FFFF"}) end
								if rewards.XP then table.insert(animRewards, {Text = "+" .. rewards.XP .. " XP", Color = "#55FF55"}) end
							end
							if #animRewards > 0 then PlayLootAnimation(animRewards) end
							Network:WaitForChild("CombatAction"):FireServer("MinigameResult", { Success = true, MinigameType = "Dialogue", Choice = idx }) 
						end)
					end
				end)

			elseif action == "ExecutionPhase" then
				UpdateState(data)
				inputLocked = true

				SnapTargetMenuClosed()
				if GUI.ExecuteOverlay then GUI.ExecuteOverlay.Visible = true end

				if GUI.CombatBackdrop then
					TweenService:Create(GUI.CombatBackdrop, TweenInfo.new(0.5), {BackgroundColor3 = Color3.new(0.1, 0, 0), BackgroundTransparency = 0.2}):Play()
				end

				local scale = GUI.ExecuteBanner:FindFirstChild("Pulsator")
				if scale then
					task.spawn(function()
						while GUI.ExecuteOverlay.Visible do
							TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Sine), {Scale = 1.05}):Play()
							task.wait(0.4)
							TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Sine), {Scale = 0.95}):Play()
							task.wait(0.4)
						end
					end)
				end

				local c
				c = GUI.ExecuteBanner.MouseButton1Click:Connect(function()
					c:Disconnect()

					if VFXManager and type(VFXManager.PlaySFX) == "function" then 
						VFXManager.PlaySFX("HeavySlash", 0.7) 
						if type(VFXManager.ScreenShake) == "function" then VFXManager.ScreenShake(1.5, 0.5) end
					end

					if player:GetAttribute("Setting_ScreenFlash") ~= false then
						GUI.ExecuteFlash.BackgroundTransparency = 0
						TweenService:Create(GUI.ExecuteFlash, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()
					end

					GUI.ExecuteBanner.Visible = false

					if VFXManager and type(VFXManager.PlayVFX) == "function" and GUI.eAvatar then 
						VFXManager.PlayVFX("Blood", GUI.eAvatar, Color3.fromRGB(180, 0, 0), true) 
					end

					task.wait(1.0)
					if GUI.ExecuteOverlay then GUI.ExecuteOverlay.Visible = false end
					if GUI.ExecuteBanner then GUI.ExecuteBanner.Visible = true end
					Network:WaitForChild("CombatAction"):FireServer("ExecutionComplete")
				end)

			elseif action == "TurnStrike" then
				if GUI.CombatantsFrame then GUI.CombatantsFrame.Visible = true end
				UpdateState(data)

				if data.EnrageTrigger then
					if VFXManager and type(VFXManager.PlaySFX) == "function" then
						VFXManager.PlaySFX("Roar", 0.8)
						if type(VFXManager.ScreenShake) == "function" then VFXManager.ScreenShake(1.2, 1.5) end
						if type(VFXManager.SpawnFloatingText) == "function" then VFXManager.SpawnFloatingText(GUI.eAvatar, "ENRAGED!", Color3.fromRGB(255, 0, 0), 1.5) end
					end
				end

				if data.AllyIntervention then
					if GUI.AllyPanel and GUI.PlayerPanel then
						if GUI.AllyNameLbl then GUI.AllyNameLbl.Text = string.upper(data.AllyIntervention) end
						if GUI.AllyQuoteLbl then GUI.AllyQuoteLbl.Text = '"' .. (data.AllyQuote or "I've got your back!") .. '"' end

						if data.AllyUserId then
							GUI.AllyAvatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. data.AllyUserId .. "&w=150&h=150"
						else
							if EnemyData and EnemyData.BossIcons and EnemyData.BossIcons[data.AllyIntervention] then
								GUI.AllyAvatar.Image = EnemyData.BossIcons[data.AllyIntervention]
							else
								GUI.AllyAvatar.Image = "rbxassetid://90132878979603"
							end
						end

						TweenService:Create(GUI.PlayerPanel, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Position = UDim2.new(-0.5, 0, 0, 0)}):Play()
						task.wait(0.1)
						TweenService:Create(GUI.AllyPanel, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play()

						if VFXManager and type(VFXManager.PlaySFX) == "function" then VFXManager.PlaySFX("Dash", 1.2) end
						task.wait(1.0)

						if VFXManager and type(VFXManager.PlaySFX) == "function" and data then 
							VFXManager.PlaySFX("HeavySlash", 1.0)
							if type(VFXManager.PlayCombatEffect) == "function" then VFXManager.PlayCombatEffect(data.SkillUsed, true, GUI.AllyAvatar, GUI.eAvatar, data.DidHit) end
						end

						if data and data.ShakeType == "Heavy" then if VFXManager and type(VFXManager.ScreenShake) == "function" then VFXManager.ScreenShake(0.8, 0.3) end
						elseif data and data.ShakeType == "Light" then if VFXManager and type(VFXManager.ScreenShake) == "function" then VFXManager.ScreenShake(0.2, 0.15) end end

						task.wait(0.8) 
						TweenService:Create(GUI.AllyPanel, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Position = UDim2.new(-0.5, 0, 0, 0)}):Play()
						task.wait(0.1)
						TweenService:Create(GUI.PlayerPanel, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play()
					end
				else
					if VFXManager and type(VFXManager.PlayCombatEffect) == "function" and data then VFXManager.PlayCombatEffect(data.SkillUsed, data.IsPlayerAttacking, GUI.pAvatar, GUI.eAvatar, data.DidHit) end
					if data and data.ShakeType == "Heavy" then if VFXManager and type(VFXManager.ScreenShake) == "function" then VFXManager.ScreenShake(0.5, 0.25) end
					elseif data and data.ShakeType == "Light" then if VFXManager and type(VFXManager.ScreenShake) == "function" then VFXManager.ScreenShake(0.2, 0.15) end end
				end

				if type(data.LogMsg) == "string" and data.LogMsg ~= "" then
					AppendLog(data.LogMsg) 

					local targetBox = data.IsPlayerAttacking and GUI.eAvatar or GUI.pAvatar
					if data.AllyIntervention then targetBox = GUI.eAvatar end

					local singleDmg = data.LogMsg:match("for (%d+) dmg!")
					if singleDmg then
						local isCrit = data.LogMsg:find("CRIT!") ~= nil
						local color = isCrit and Color3.fromRGB(255, 170, 0) or Color3.fromRGB(255, 85, 85)
						if VFXManager and type(VFXManager.SpawnFloatingText) == "function" then VFXManager.SpawnFloatingText(targetBox, "-"..singleDmg, color, isCrit and 1.5 or 1.0) end
					else
						local hitDelays = 0
						for multiDmg in data.LogMsg:gmatch("dealt (%d+) damage") do
							task.delay(hitDelays, function()
								if VFXManager and type(VFXManager.SpawnFloatingText) == "function" then VFXManager.SpawnFloatingText(targetBox, "-"..multiDmg, Color3.fromRGB(255, 85, 85), 1.0) end
							end)
							hitDelays += 0.2
						end
					end

					local healDmg = data.LogMsg:match("Healed (%d+) HP!")
					if healDmg and VFXManager and type(VFXManager.SpawnFloatingText) == "function" then VFXManager.SpawnFloatingText(data.IsPlayerAttacking and GUI.pAvatar or GUI.eAvatar, "+"..healDmg, Color3.fromRGB(85, 255, 85), 1.2) end

					local titanHeal = data.LogMsg:match("regenerate (%d+) HP")
					if titanHeal and VFXManager and type(VFXManager.SpawnFloatingText) == "function" then VFXManager.SpawnFloatingText(GUI.pAvatar, "+"..titanHeal, Color3.fromRGB(85, 255, 85), 1.2) end

					local recoilDmg = data.LogMsg:match("took (%d+) recoil damage")
					if recoilDmg and VFXManager and type(VFXManager.SpawnFloatingText) == "function" then VFXManager.SpawnFloatingText(GUI.pAvatar, "-"..recoilDmg, Color3.fromRGB(200, 50, 50), 1.0) end
				end

			elseif action == "WaveComplete" then
				HideAlly()
				if GUI.CombatantsFrame then GUI.CombatantsFrame.Visible = true end
				if GUI.LogContainer then GUI.LogContainer.Visible = true end
				if GUI.ActionContainer then GUI.ActionContainer.Visible = true end
				if GUI.DialogueBox then GUI.DialogueBox.Visible = false end

				if VFXManager and type(VFXManager.ToggleHeartbeat) == "function" then VFXManager.ToggleHeartbeat(false) end

				UpdateState(data)
				AppendLog("<b><font color=\"#55FF55\">WAVE CLEARED!</font></b>", "#55FF55")
				if data and type(data.LogMsg) == "string" and data.LogMsg ~= "" then AppendLog(data.LogMsg) end

				local animRewards = {}
				if data and data.XP and data.XP > 0 then table.insert(animRewards, {Text = "+" .. data.XP .. " XP", Color = "#55FF55"}) end
				if data and data.Dews and data.Dews > 0 then table.insert(animRewards, {Text = "+" .. data.Dews .. " Dews", Color = "#55FFFF"}) end
				if data and data.Items and #data.Items > 0 then
					for _, item in ipairs(data.Items) do
						if type(item) == "table" then table.insert(animRewards, {Text = "+" .. (item.Amount or 1) .. " " .. (item.Name or "Unknown"), Color = "#FFD700"})
						elseif type(item) == "string" then table.insert(animRewards, {Text = "+1 " .. item, Color = "#FFD700"}) end
					end
				end

				if #animRewards > 0 then PlayLootAnimation(animRewards) end

				if data and data.Battle and data.Battle.Enemy and data.Battle.Enemy.IsRumblingBoss then
					inputLocked = false
					DestroyWaitContainer()
					UpdatePvESkills()
				else
					inputLocked = true
					SnapTargetMenuClosed()
					DestroyWaitContainer()

					if GUI.ActionGrid then
						for _, c in ipairs(GUI.ActionGrid:GetChildren()) do if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end end
						local continueBtn = CreateMinimalButton(GUI.ActionGrid, "CONTINUE EXPEDITION", UDim2.new(0, 0, 0, 0), "#55FF55")
						continueBtn.MouseButton1Click:Connect(function() UpdatePvESkills() end)

						local retreatBtn = CreateMinimalButton(GUI.ActionGrid, "RETREAT TO COMMAND", UDim2.new(0, 0, 0, 0), "#FF5555")
						retreatBtn.MouseButton1Click:Connect(function() Network:WaitForChild("CombatAction"):FireServer("Attack", {SkillName = "Retreat"}) end)
					end
				end

			elseif action == "Victory" then
				HideAlly()
				if GUI.CombatantsFrame then GUI.CombatantsFrame.Visible = true end
				if GUI.LogContainer then GUI.LogContainer.Visible = true end
				if GUI.ActionContainer then GUI.ActionContainer.Visible = true end
				if GUI.DialogueBox then GUI.DialogueBox.Visible = false end

				if VFXManager and type(VFXManager.ToggleHeartbeat) == "function" then VFXManager.ToggleHeartbeat(false) end

				UpdateState(data)
				AppendLog("<b><font color=\"#55FF55\">VICTORY!</font></b>", "#55FF55")

				local animRewards = {}
				if data and data.XP and data.XP > 0 then table.insert(animRewards, {Text = "+" .. data.XP .. " XP", Color = "#55FF55"}) end
				if data and data.Dews and data.Dews > 0 then table.insert(animRewards, {Text = "+" .. data.Dews .. " Dews", Color = "#55FFFF"}) end
				if data and data.Items and #data.Items > 0 then
					for _, item in ipairs(data.Items) do
						if type(item) == "table" then table.insert(animRewards, {Text = "+" .. (item.Amount or 1) .. " " .. (item.Name or "Unknown"), Color = "#FFD700"})
						elseif type(item) == "string" then table.insert(animRewards, {Text = "+1 " .. item, Color = "#FFD700"}) end
					end
				end

				if #animRewards > 0 then PlayLootAnimation(animRewards) end
				if data and type(data.ExtraLog) == "string" and data.ExtraLog ~= "" then AppendLog(data.ExtraLog) end
				if VFXManager and type(VFXManager.PlaySFX) == "function" then VFXManager.PlaySFX("Victory", 1.0) end

				inputLocked = true
				SnapTargetMenuClosed()
				DestroyWaitContainer()

				if GUI.ActionGrid then
					for _, c in ipairs(GUI.ActionGrid:GetChildren()) do if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end end
					if data and data.Battle and data.Battle.Context and data.Battle.Context.IsStoryMission then
						local continueCampBtn = CreateMinimalButton(GUI.ActionGrid, "CONTINUE CAMPAIGN", UDim2.new(0, 0, 0, 0), "#FFD700")
						continueCampBtn.MouseButton1Click:Connect(function() Network:WaitForChild("CombatAction"):FireServer("EngageStory") end)
					end
					local closeBtn = CreateMinimalButton(GUI.ActionGrid, "RETURN TO COMMAND", UDim2.new(0, 0, 0, 0), "#55FF55")
					closeBtn.MouseButton1Click:Connect(function() CloseUI() end)
				end

			elseif action == "Defeat" or action == "PathsDeath" then
				if not GUI.CombatWindow or not GUI.CombatWindow.Visible then return end
				local wasPaths = data.Battle and data.Battle.Context and data.Battle.Context.IsPaths

				HideAlly()
				if GUI.CombatantsFrame then GUI.CombatantsFrame.Visible = true end
				if GUI.LogContainer then GUI.LogContainer.Visible = true end
				if GUI.ActionContainer then GUI.ActionContainer.Visible = true end
				if GUI.DialogueBox then GUI.DialogueBox.Visible = false end

				if VFXManager and type(VFXManager.ToggleHeartbeat) == "function" then VFXManager.ToggleHeartbeat(false) end

				UpdateState(data)
				AppendLog("<b><font color=\"#FF5555\">DEFEAT...</font></b> Your forces were wiped out.", "#FF5555")

				if VFXManager and type(VFXManager.PlaySFX) == "function" then VFXManager.PlaySFX("Defeat", 1.0) end

				inputLocked = true
				SnapTargetMenuClosed()
				DestroyWaitContainer()

				if GUI.ActionGrid then
					for _, c in ipairs(GUI.ActionGrid:GetChildren()) do if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end end
					local closeBtn = CreateMinimalButton(GUI.ActionGrid, "RETURN TO COMMAND", UDim2.new(0, 0, 0, 0), "#FF5555")
					closeBtn.MouseButton1Click:Connect(function() CloseUI(wasPaths) end)
				end

			elseif action == "Fled" then
				if not GUI.CombatWindow or not GUI.CombatWindow.Visible then return end
				local wasPaths = data.Battle and data.Battle.Context and data.Battle.Context.IsPaths
				HideAlly()
				if GUI.CombatantsFrame then GUI.CombatantsFrame.Visible = true end
				if VFXManager and type(VFXManager.ToggleHeartbeat) == "function" then VFXManager.ToggleHeartbeat(false) end
				AppendLog("<b><font color=\"#AAAAAA\">YOU FLED THE BATTLE.</font></b>", "#AAAAAA")
				task.wait(1.5)
				CloseUI(wasPaths)
			end
		end)

		if not success then
			warn("[AoT UI Combat Engine Error]: " .. tostring(err))
			if action == "Victory" or action == "Defeat" or action == "PathsDeath" then
				inputLocked = true
				DestroyWaitContainer()
				if GUI and GUI.ActionGrid then
					for _, c in ipairs(GUI.ActionGrid:GetChildren()) do if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end end
					GUI.ActionGrid.Position = UDim2.new(0, 0, 0, 0)
					local closeBtn = CreateMinimalButton(GUI.ActionGrid, "FORCE RETURN", UDim2.new(0, 0, 0, 0), "#FF5555")
					closeBtn.MouseButton1Click:Connect(function() CloseUI() end)
				end
			end
		end
	end)
end

CombatUI.UpdateSkills = UpdatePvESkills 
CombatUI.UpdateState = UpdateState
CombatUI.AppendLog = AppendLog
CombatUI.Show = ShowPvEUI
CombatUI.Close = CloseUI

return CombatUI