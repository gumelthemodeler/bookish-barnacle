-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
-- Name: CombatBuilder
local CombatBuilder = {}

local Players = game:GetService("Players")
local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))
local camera = workspace.CurrentCamera

local function CreateFlatPanel(parent)
	local frame = Instance.new("Frame", parent)
	frame.BackgroundColor3 = Color3.fromRGB(15, 12, 12)
	frame.BorderSizePixel = 0
	local stroke = Instance.new("UIStroke", frame)
	stroke.Color = Color3.fromRGB(45, 25, 25)
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return frame, stroke
end

local function CreateFlatBar(parent, title, colorHex, pos, size, alignRight, baseZ, isOverlay)
	baseZ = baseZ or 1
	local cColor = Color3.fromHex(colorHex:gsub("#", ""))
	local shadowColor = Color3.new(cColor.R * 0.2, cColor.G * 0.2, cColor.B * 0.2)

	local container = Instance.new("Frame", parent)
	container.Size = size
	container.Position = pos
	container.BackgroundColor3 = Color3.fromRGB(10, 8, 8)
	container.BorderSizePixel = 0
	container.ZIndex = baseZ

	if isOverlay then container.BackgroundTransparency = 1 end

	local strk = Instance.new("UIStroke", container)
	strk.Color = Color3.fromRGB(30, 20, 20)
	strk.Thickness = 1
	strk.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	if isOverlay then strk.Enabled = false end

	local fill = Instance.new("Frame", container)
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	fill.BorderSizePixel = 0
	fill.ZIndex = baseZ + 1

	if alignRight then
		fill.AnchorPoint = Vector2.new(1, 0)
		fill.Position = UDim2.new(1, 0, 0, 0)
	end

	local grad = Instance.new("UIGradient", fill)
	grad.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, cColor),
		ColorSequenceKeypoint.new(1, shadowColor)
	}
	grad.Rotation = 90

	local txt = UIHelpers.CreateLabel(container, title .. " 100/100", UDim2.new(1, -8, 1, 0), Enum.Font.GothamBold, Color3.fromRGB(240, 230, 220), 11)
	if alignRight then
		txt.TextXAlignment = Enum.TextXAlignment.Right
	else
		txt.TextXAlignment = Enum.TextXAlignment.Left
		txt.Position = UDim2.new(0, 8, 0, 0)
	end
	txt.ZIndex = baseZ + 2

	return fill, txt, container
end

function CombatBuilder.Build(masterScreenGui, player)
	local GUI = {}

	GUI.CombatBackdrop = Instance.new("TextButton", masterScreenGui)
	GUI.CombatBackdrop.Name = "CombatBackdrop"
	GUI.CombatBackdrop.Size = UDim2.new(1, 0, 1, 0)
	GUI.CombatBackdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	GUI.CombatBackdrop.BackgroundTransparency = 1
	GUI.CombatBackdrop.Text = ""
	GUI.CombatBackdrop.AutoButtonColor = false
	GUI.CombatBackdrop.Visible = false
	GUI.CombatBackdrop.ZIndex = 98
	GUI.CombatBackdrop.Active = true

	GUI.CombatWindow = Instance.new("Frame", masterScreenGui)
	GUI.CombatWindow.Name = "CombatWindow"
	GUI.CombatWindow.Size = UDim2.new(0, 1000, 0, 580)
	GUI.CombatWindow.Position = UDim2.new(0.5, 0, 0.5, 0)
	GUI.CombatWindow.AnchorPoint = Vector2.new(0.5, 0.5)
	GUI.CombatWindow.BackgroundColor3 = Color3.fromRGB(15, 12, 12)
	GUI.CombatWindow.Visible = false
	GUI.CombatWindow.ZIndex = 100
	local cwStroke = Instance.new("UIStroke", GUI.CombatWindow)
	cwStroke.Color = Color3.fromRGB(60, 30, 30)
	cwStroke.Thickness = 2

	GUI.WindowScale = Instance.new("UIScale", GUI.CombatWindow)
	GUI.WindowScale.Scale = 0

	GUI.VFXOverlay = Instance.new("Frame", GUI.CombatWindow)
	GUI.VFXOverlay.Size = UDim2.new(1, 0, 1, 0)
	GUI.VFXOverlay.BackgroundTransparency = 1
	GUI.VFXOverlay.ZIndex = 105

	local Header = Instance.new("Frame", GUI.CombatWindow)
	Header.Size = UDim2.new(1, 0, 0, 40)
	Header.BackgroundColor3 = Color3.fromRGB(10, 8, 8)
	Header.BorderSizePixel = 0
	local hStroke = Instance.new("UIStroke", Header)
	hStroke.Color = Color3.fromRGB(40, 20, 20)
	hStroke.Thickness = 1
	hStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	GUI.MissionInfoLbl = UIHelpers.CreateLabel(Header, "COMBAT DEPLOYMENT", UDim2.new(1, -20, 1, 0), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 14)
	GUI.MissionInfoLbl.Position = UDim2.new(0, 15, 0, 0)
	GUI.MissionInfoLbl.TextXAlignment = Enum.TextXAlignment.Left

	-- COMBATANTS FRAME
	GUI.CombatantsFrame = Instance.new("Frame", GUI.CombatWindow)
	GUI.CombatantsFrame.Size = UDim2.new(1, -40, 0, 135)
	GUI.CombatantsFrame.Position = UDim2.new(0, 20, 0, 55)
	GUI.CombatantsFrame.BackgroundTransparency = 1
	GUI.CombatantsFrame.ClipsDescendants = true

	GUI.PlayerPanel, _ = CreateFlatPanel(GUI.CombatantsFrame)
	GUI.PlayerPanel.Size = UDim2.new(0.46, 0, 1, 0)
	GUI.PlayerPanel.Position = UDim2.new(0, 0, 0, 0)

	GUI.pAvatar = Instance.new("ImageLabel", GUI.PlayerPanel)
	GUI.pAvatar.Size = UDim2.new(0, 90, 0, 90)
	GUI.pAvatar.Position = UDim2.new(0, 15, 0, 15)
	GUI.pAvatar.BackgroundColor3 = Color3.fromRGB(10, 8, 8)
	GUI.pAvatar.ZIndex = 2
	GUI.pAvatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
	GUI.pAvatar.ScaleType = Enum.ScaleType.Crop
	local pAvatarStroke = Instance.new("UIStroke", GUI.pAvatar)
	pAvatarStroke.Color = Color3.fromRGB(85, 170, 255)
	pAvatarStroke.Thickness = 2
	pAvatarStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	GUI.AllyPanel, _ = CreateFlatPanel(GUI.CombatantsFrame)
	GUI.AllyPanel.Size = UDim2.new(0.46, 0, 1, 0)
	GUI.AllyPanel.Position = UDim2.new(-0.5, 0, 0, 0)
	GUI.AllyPanel.ZIndex = 5

	GUI.AllyAvatar = Instance.new("ImageLabel", GUI.AllyPanel)
	GUI.AllyAvatar.Size = UDim2.new(0, 90, 0, 90)
	GUI.AllyAvatar.Position = UDim2.new(0, 15, 0, 15)
	GUI.AllyAvatar.BackgroundColor3 = Color3.fromRGB(10, 8, 8)
	GUI.AllyAvatar.ScaleType = Enum.ScaleType.Crop
	GUI.AllyAvatar.ZIndex = 6
	local allyAvatarStrk = Instance.new("UIStroke", GUI.AllyAvatar)
	allyAvatarStrk.Color = Color3.fromRGB(85, 255, 255)
	allyAvatarStrk.Thickness = 2
	allyAvatarStrk.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	GUI.AllyNameLbl = UIHelpers.CreateLabel(GUI.AllyPanel, "ALLY NAME", UDim2.new(1, -130, 0, 20), Enum.Font.GothamBlack, Color3.fromRGB(85, 255, 255), 15)
	GUI.AllyNameLbl.Position = UDim2.new(0, 120, 0, 10)
	GUI.AllyNameLbl.TextXAlignment = Enum.TextXAlignment.Left
	GUI.AllyNameLbl.ZIndex = 6

	GUI.AllyQuoteLbl = UIHelpers.CreateLabel(GUI.AllyPanel, '"I\'ve got your back!"', UDim2.new(1, -130, 1, -40), Enum.Font.GothamMedium, Color3.fromRGB(220, 220, 220), 13)
	GUI.AllyQuoteLbl.Position = UDim2.new(0, 120, 0, 35)
	GUI.AllyQuoteLbl.TextXAlignment = Enum.TextXAlignment.Left
	GUI.AllyQuoteLbl.TextYAlignment = Enum.TextYAlignment.Top
	GUI.AllyQuoteLbl.TextWrapped = true
	GUI.AllyQuoteLbl.ZIndex = 6

	GUI.pNameLbl = UIHelpers.CreateLabel(GUI.PlayerPanel, player.Name, UDim2.new(1, -130, 0, 20), Enum.Font.GothamBlack, UIHelpers.Colors.TextWhite, 15)
	GUI.pNameLbl.Position = UDim2.new(0, 120, 0, 10)
	GUI.pNameLbl.TextXAlignment = Enum.TextXAlignment.Left

	GUI.pHPBar, GUI.pHPText = CreateFlatBar(GUI.PlayerPanel, "HP", "#44DD44", UDim2.new(0, 120, 0, 35), UDim2.new(1, -135, 0, 20), false, 1)
	GUI.pGasBar, GUI.pGasText = CreateFlatBar(GUI.PlayerPanel, "GAS", "#AADDDD", UDim2.new(0, 120, 0, 60), UDim2.new(1, -135, 0, 20), false, 1)
	GUI.pHeatBar, GUI.pHeatText, GUI.pHeatContainer = CreateFlatBar(GUI.PlayerPanel, "HEAT", "#FF8800", UDim2.new(0, 120, 0, 85), UDim2.new(1, -135, 0, 20), false, 1)
	GUI.pHeatContainer.Visible = false

	GUI.PlayerStatusBox = Instance.new("Frame", GUI.PlayerPanel)
	GUI.PlayerStatusBox.Size = UDim2.new(1, -135, 0, 20)
	GUI.PlayerStatusBox.Position = UDim2.new(0, 120, 0, 110)
	GUI.PlayerStatusBox.BackgroundTransparency = 1
	local pStatLayout = Instance.new("UIListLayout", GUI.PlayerStatusBox)
	pStatLayout.FillDirection = Enum.FillDirection.Horizontal
	pStatLayout.Padding = UDim.new(0, 4)

	local vsLbl = UIHelpers.CreateLabel(GUI.CombatantsFrame, "VS", UDim2.new(0.08, 0, 1, 0), Enum.Font.GothamBlack, Color3.fromRGB(150, 50, 50), 24)
	vsLbl.Position = UDim2.new(0.46, 0, 0, 0)

	local EnemyPanel, _ = CreateFlatPanel(GUI.CombatantsFrame)
	EnemyPanel.Size = UDim2.new(0.46, 0, 1, 0)
	EnemyPanel.Position = UDim2.new(0.54, 0, 0, 0)

	GUI.eAvatar = Instance.new("ImageLabel", EnemyPanel)
	GUI.eAvatar.Size = UDim2.new(0, 90, 0, 90)
	GUI.eAvatar.Position = UDim2.new(1, -15, 0, 15)
	GUI.eAvatar.AnchorPoint = Vector2.new(1, 0)
	GUI.eAvatar.BackgroundColor3 = Color3.fromRGB(10, 8, 8)
	GUI.eAvatar.Image = "rbxassetid://90132878979603" 
	GUI.eAvatar.ScaleType = Enum.ScaleType.Crop
	local eAvatarStroke = Instance.new("UIStroke", GUI.eAvatar)
	eAvatarStroke.Color = Color3.fromRGB(255, 85, 85)
	eAvatarStroke.Thickness = 2
	eAvatarStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	GUI.eNameLbl = UIHelpers.CreateLabel(EnemyPanel, "UNKNOWN ABNORMAL", UDim2.new(1, -130, 0, 20), Enum.Font.GothamBlack, Color3.fromRGB(255, 100, 100), 15)
	GUI.eNameLbl.Position = UDim2.new(0, 15, 0, 10)
	GUI.eNameLbl.TextXAlignment = Enum.TextXAlignment.Right

	GUI.eHPBar, GUI.eHPText, GUI.eHPContainer = CreateFlatBar(EnemyPanel, "HP", "#DD4444", UDim2.new(0, 15, 0, 35), UDim2.new(1, -135, 0, 20), true, 1)
	GUI.eGateBar, GUI.eGateText, GUI.eGateContainer = CreateFlatBar(EnemyPanel, "ARMOR", "#AAAAAA", UDim2.new(0, 15, 0, 35), UDim2.new(1, -135, 0, 20), true, 10, true)
	GUI.eGateContainer.Visible = false

	GUI.EnemyStatusBox = Instance.new("Frame", EnemyPanel)
	GUI.EnemyStatusBox.Size = UDim2.new(1, -135, 0, 20)
	GUI.EnemyStatusBox.Position = UDim2.new(0, 15, 0, 110)
	GUI.EnemyStatusBox.BackgroundTransparency = 1
	local eStatLayout = Instance.new("UIListLayout", GUI.EnemyStatusBox)
	eStatLayout.FillDirection = Enum.FillDirection.Horizontal
	eStatLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	eStatLayout.Padding = UDim.new(0, 4)

	GUI.ExecuteOverlay = Instance.new("Frame", GUI.CombatWindow)
	GUI.ExecuteOverlay.Size = UDim2.new(1, 0, 1, 0)
	GUI.ExecuteOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
	GUI.ExecuteOverlay.BackgroundTransparency = 0.3
	GUI.ExecuteOverlay.ZIndex = 150
	GUI.ExecuteOverlay.Visible = false

	GUI.ExecuteBanner = Instance.new("TextButton", GUI.ExecuteOverlay)
	GUI.ExecuteBanner.Size = UDim2.new(1, 0, 0, 100)
	GUI.ExecuteBanner.Position = UDim2.new(0.5, 0, 0.5, 0)
	GUI.ExecuteBanner.AnchorPoint = Vector2.new(0.5, 0.5)
	GUI.ExecuteBanner.BackgroundColor3 = Color3.fromRGB(15, 10, 10)
	GUI.ExecuteBanner.BorderSizePixel = 0
	GUI.ExecuteBanner.AutoButtonColor = false
	GUI.ExecuteBanner.Text = ""
	GUI.ExecuteBanner.ZIndex = 151

	local ebStroke = Instance.new("UIStroke", GUI.ExecuteBanner)
	ebStroke.Color = Color3.fromRGB(150, 0, 0)
	ebStroke.Thickness = 2
	ebStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	local exGrad = Instance.new("UIGradient", GUI.ExecuteBanner)
	exGrad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.new(0,0,0)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(60, 5, 5)), ColorSequenceKeypoint.new(1, Color3.new(0,0,0))}
	exGrad.Transparency = NumberSequence.new{NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.2), NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 1)}

	GUI.ExecuteText = UIHelpers.CreateLabel(GUI.ExecuteBanner, "SEVER", UDim2.new(1, 0, 1, 0), Enum.Font.GothamBlack, Color3.fromRGB(200, 200, 200), 52)
	GUI.ExecuteText.ZIndex = 152
	local exStroke = Instance.new("UIStroke", GUI.ExecuteText)
	exStroke.Color = Color3.fromRGB(40, 0, 0)
	exStroke.Thickness = 2

	local pulsator = Instance.new("UIScale", GUI.ExecuteBanner)
	pulsator.Name = "Pulsator"

	GUI.ExecuteFlash = Instance.new("Frame", GUI.ExecuteOverlay)
	GUI.ExecuteFlash.Size = UDim2.new(1, 0, 1, 0)
	GUI.ExecuteFlash.BackgroundColor3 = Color3.new(1, 1, 1)
	GUI.ExecuteFlash.BackgroundTransparency = 1
	GUI.ExecuteFlash.ZIndex = 155

	-- LOG AREA
	GUI.LogContainer, _ = CreateFlatPanel(GUI.CombatWindow)
	GUI.LogContainer.Size = UDim2.new(0.4, 0, 1, -230)
	GUI.LogContainer.Position = UDim2.new(0, 20, 0, 210)

	GUI.LogScroll = Instance.new("ScrollingFrame", GUI.LogContainer)
	GUI.LogScroll.Size = UDim2.new(1, -20, 1, -20)
	GUI.LogScroll.Position = UDim2.new(0, 10, 0, 10)
	GUI.LogScroll.BackgroundTransparency = 1
	GUI.LogScroll.ScrollBarThickness = 4
	GUI.LogScroll.BorderSizePixel = 0

	local logLayout = Instance.new("UIListLayout", GUI.LogScroll)
	logLayout.Padding = UDim.new(0, 6)
	logLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	logLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() 
		GUI.LogScroll.CanvasSize = UDim2.new(0, 0, 0, logLayout.AbsoluteContentSize.Y + 10)
		GUI.LogScroll.CanvasPosition = Vector2.new(0, GUI.LogScroll.CanvasSize.Y.Offset)
	end)

	-- ACTION AREA
	GUI.ActionContainer = Instance.new("Frame", GUI.CombatWindow)
	GUI.ActionContainer.Size = UDim2.new(0.6, -30, 1, -230)
	GUI.ActionContainer.Position = UDim2.new(0.4, 10, 0, 210)
	GUI.ActionContainer.BackgroundTransparency = 1
	GUI.ActionContainer.ClipsDescendants = true

	GUI.ActionGrid = Instance.new("ScrollingFrame", GUI.ActionContainer)
	GUI.ActionGrid.Size = UDim2.new(1, 0, 1, 0)
	GUI.ActionGrid.Position = UDim2.new(0, 0, 0, 0)
	GUI.ActionGrid.BackgroundTransparency = 1
	GUI.ActionGrid.ScrollBarThickness = 0
	local acLayout = Instance.new("UIGridLayout", GUI.ActionGrid)
	acLayout.CellSize = UDim2.new(0, 195, 0, 45)
	acLayout.CellPadding = UDim2.new(0, 15, 0, 15)
	acLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	acLayout.VerticalAlignment = Enum.VerticalAlignment.Top

	acLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		GUI.ActionGrid.CanvasSize = UDim2.new(0, 0, 0, acLayout.AbsoluteContentSize.Y + 10)
	end)

	-- TARGET MENU
	GUI.TargetMenu = Instance.new("Frame", GUI.ActionContainer)
	GUI.TargetMenu.Size = UDim2.new(1, 0, 1, -10)
	GUI.TargetMenu.Position = UDim2.new(1, 20, 0, 0) 
	GUI.TargetMenu.BackgroundColor3 = Color3.fromRGB(15, 12, 12)
	GUI.TargetMenu.Visible = false
	local tmStroke = Instance.new("UIStroke", GUI.TargetMenu)
	tmStroke.Color = Color3.fromRGB(40, 20, 20)
	tmStroke.Thickness = 2
	tmStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	local InfoPanel = Instance.new("Frame", GUI.TargetMenu)
	InfoPanel.BackgroundTransparency = 1

	GUI.tHoverTitle = UIHelpers.CreateLabel(InfoPanel, "SELECT TARGET", UDim2.new(1, 0, 0, 30), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 20)
	GUI.tHoverDesc = UIHelpers.CreateLabel(InfoPanel, "Hover over a limb to view its tactical effect.", UDim2.new(1, 0, 0, 60), Enum.Font.GothamMedium, Color3.fromRGB(180, 180, 180), 13)
	GUI.tHoverDesc.TextWrapped = true

	GUI.CancelBtn = Instance.new("TextButton", InfoPanel)
	GUI.CancelBtn.BackgroundColor3 = Color3.fromRGB(22, 15, 15)
	GUI.CancelBtn.BorderSizePixel = 0
	GUI.CancelBtn.Font = Enum.Font.GothamBlack
	GUI.CancelBtn.TextSize = 14
	GUI.CancelBtn.Text = "CANCEL"
	GUI.CancelBtn.TextColor3 = Color3.fromRGB(255, 85, 85)
	local cbStroke = Instance.new("UIStroke", GUI.CancelBtn)
	cbStroke.Color = Color3.fromRGB(100, 30, 30)
	cbStroke.Thickness = 2
	cbStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	local BodyContainer = Instance.new("Frame", GUI.TargetMenu)
	BodyContainer.BackgroundTransparency = 1
	local aspect = Instance.new("UIAspectRatioConstraint", BodyContainer); aspect.AspectRatio = 0.8

	local function UpdateLayoutForScreen()
		local vp = camera.ViewportSize
		if vp.X == 0 or vp.Y == 0 or not GUI then return end
		local isMobile = (vp.X <= 850) or (vp.Y > vp.X)

		if isMobile then
			GUI.CombatWindow.Size = UDim2.new(1, 0, 1, 0)
			GUI.CombatWindow.Position = UDim2.new(0.5, 0, 0.5, 0)

			if GUI.CombatantsFrame then
				GUI.CombatantsFrame.Size = UDim2.new(1, -20, 0, 110)
				GUI.CombatantsFrame.Position = UDim2.new(0, 10, 0, 45)
			end
			if GUI.LogContainer then
				GUI.LogContainer.Size = UDim2.new(0.38, 0, 1, -165)
				GUI.LogContainer.Position = UDim2.new(0, 10, 0, 160)
			end
			if GUI.ActionContainer then
				GUI.ActionContainer.Size = UDim2.new(0.6, -20, 1, -165)
				GUI.ActionContainer.Position = UDim2.new(0.4, 10, 0, 160)
			end

			if GUI.ActionGrid:FindFirstChildOfClass("UIGridLayout") then
				GUI.ActionGrid:FindFirstChildOfClass("UIGridLayout").CellSize = UDim2.new(0.48, 0, 0, 40)
				GUI.ActionGrid:FindFirstChildOfClass("UIGridLayout").CellPadding = UDim2.new(0.02, 0, 0, 8)
			end

			InfoPanel.Size = UDim2.new(0.45, 0, 1, 0)
			InfoPanel.Position = UDim2.new(0, 0, 0, 0)

			GUI.tHoverTitle.Size = UDim2.new(1, 0, 0, 20)
			GUI.tHoverTitle.Position = UDim2.new(0, 0, 0, 10)
			GUI.tHoverTitle.TextSize = 14
			GUI.tHoverTitle.TextXAlignment = Enum.TextXAlignment.Center

			GUI.tHoverDesc.Size = UDim2.new(1, 0, 0, 40)
			GUI.tHoverDesc.Position = UDim2.new(0, 0, 0, 35)
			GUI.tHoverDesc.TextSize = 11
			GUI.tHoverDesc.TextXAlignment = Enum.TextXAlignment.Center

			GUI.CancelBtn.Size = UDim2.new(0.8, 0, 0, 30)
			GUI.CancelBtn.Position = UDim2.new(0.5, 0, 1, -40)
			GUI.CancelBtn.AnchorPoint = Vector2.new(0.5, 0)

			BodyContainer.Size = UDim2.new(0, 140, 0, 175)
			BodyContainer.Position = UDim2.new(0.75, 0, 0.5, 0)
			BodyContainer.AnchorPoint = Vector2.new(0.5, 0.5)
		else
			GUI.CombatWindow.Size = UDim2.new(0, 900, 0, 650)
			GUI.CombatWindow.Position = UDim2.new(0.5, 0, 0.5, 0)

			if GUI.CombatantsFrame then
				GUI.CombatantsFrame.Size = UDim2.new(1, -40, 0, 180)
				GUI.CombatantsFrame.Position = UDim2.new(0, 20, 0, 20)
			end
			if GUI.LogContainer then
				GUI.LogContainer.Size = UDim2.new(0.4, 0, 1, -230)
				GUI.LogContainer.Position = UDim2.new(0, 20, 0, 210)
			end
			if GUI.ActionContainer then
				GUI.ActionContainer.Size = UDim2.new(0.6, -30, 1, -230)
				GUI.ActionContainer.Position = UDim2.new(0.4, 10, 0, 210)
			end

			if GUI.ActionGrid:FindFirstChildOfClass("UIGridLayout") then
				GUI.ActionGrid:FindFirstChildOfClass("UIGridLayout").CellSize = UDim2.new(0, 195, 0, 45)
				GUI.ActionGrid:FindFirstChildOfClass("UIGridLayout").CellPadding = UDim2.new(0, 15, 0, 15)
			end

			InfoPanel.Size = UDim2.new(0.5, 0, 1, 0)
			InfoPanel.Position = UDim2.new(0, 0, 0, 0)

			GUI.tHoverTitle.Size = UDim2.new(1, -20, 0, 30)
			GUI.tHoverTitle.Position = UDim2.new(0, 30, 0, 20)
			GUI.tHoverTitle.TextSize = 20
			GUI.tHoverTitle.TextXAlignment = Enum.TextXAlignment.Left

			GUI.tHoverDesc.Size = UDim2.new(1, -20, 0, 60)
			GUI.tHoverDesc.Position = UDim2.new(0, 30, 0, 60)
			GUI.tHoverDesc.TextSize = 13
			GUI.tHoverDesc.TextXAlignment = Enum.TextXAlignment.Left

			GUI.CancelBtn.Size = UDim2.new(0, 150, 0, 40)
			GUI.CancelBtn.Position = UDim2.new(0, 30, 1, -60)
			GUI.CancelBtn.AnchorPoint = Vector2.new(0, 0)

			BodyContainer.Size = UDim2.new(0, 160, 0, 200) 
			BodyContainer.Position = UDim2.new(0.8, 0, 0.5, 0)
			BodyContainer.AnchorPoint = Vector2.new(0.5, 0.5)
		end
	end

	camera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateLayoutForScreen)
	UpdateLayoutForScreen()

	GUI.Limbs = {}
	local function BuildLimb(name, targetId, size, pos, hoverText, baseColor)
		local limb = Instance.new("TextButton", BodyContainer)
		limb.Size = size; limb.Position = pos
		limb.BackgroundColor3 = Color3.fromRGB(22, 18, 18) 
		limb.Text = name:upper()
		limb.Font = Enum.Font.GothamBlack
		limb.TextColor3 = Color3.fromRGB(255, 255, 255) 
		limb.TextSize = 10
		limb.AutoButtonColor = false
		limb.AnchorPoint = Vector2.new(0.5, 0.5)

		local strk = Instance.new("UIStroke", limb)
		strk.Color = baseColor 
		strk.Thickness = 2 
		strk.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

		limb.MouseEnter:Connect(function()
			strk.Color = UIHelpers.Colors.Gold
			strk.Thickness = 3
			GUI.tHoverTitle.Text = "TARGET: " .. string.upper(targetId)
			GUI.tHoverTitle.TextColor3 = baseColor
			GUI.tHoverDesc.Text = hoverText
		end)

		limb.MouseLeave:Connect(function()
			strk.Color = baseColor
			strk.Thickness = 2
			GUI.tHoverTitle.Text = "SELECT TARGET"
			GUI.tHoverTitle.TextColor3 = UIHelpers.Colors.Gold
			GUI.tHoverDesc.Text = "Hover over a limb to view its tactical effect."
		end)
		GUI.Limbs[targetId] = limb
	end

	BuildLimb("Eyes", "Eyes", UDim2.new(0.24, 0, 0.18, 0), UDim2.new(0.5, 0, 0.08, 0), "Deals 20% Damage. Inflicts Blinded.", Color3.fromRGB(120, 120, 180))
	BuildLimb("Nape", "Nape", UDim2.new(0.24, 0, 0.06, 0), UDim2.new(0.5, 0, 0.22, 0), "Deals 150% Damage. Low accuracy.", Color3.fromRGB(220, 80, 80))
	BuildLimb("Body", "Body", UDim2.new(0.48, 0, 0.38, 0), UDim2.new(0.5, 0, 0.45, 0), "Deals 100% Damage. Standard accuracy.", Color3.fromRGB(80, 160, 80))
	BuildLimb("L.Arm", "LArm", UDim2.new(0.22, 0, 0.38, 0), UDim2.new(0.14, 0, 0.45, 0), "Deals 50% Damage. Inflicts Weakened.", Color3.fromRGB(180, 140, 60))
	BuildLimb("R.Arm", "RArm", UDim2.new(0.22, 0, 0.38, 0), UDim2.new(0.86, 0, 0.45, 0), "Deals 50% Damage. Inflicts Weakened.", Color3.fromRGB(180, 140, 60))
	BuildLimb("L.Leg", "LLeg", UDim2.new(0.23, 0, 0.32, 0), UDim2.new(0.37, 0, 0.81, 0), "Deals 50% Damage. Inflicts Crippled.", Color3.fromRGB(80, 140, 180))
	BuildLimb("R.Leg", "RLeg", UDim2.new(0.23, 0, 0.32, 0), UDim2.new(0.63, 0, 0.81, 0), "Deals 50% Damage. Inflicts Crippled.", Color3.fromRGB(80, 140, 180))

	GUI.DialogueBox = Instance.new("Frame", GUI.CombatWindow)
	GUI.DialogueBox.Size = UDim2.new(1, -40, 0, 200)
	GUI.DialogueBox.Position = UDim2.new(0, 20, 1, -215)
	GUI.DialogueBox.BackgroundColor3 = Color3.fromRGB(15, 12, 12)
	GUI.DialogueBox.Visible = false
	local dbStroke = Instance.new("UIStroke", GUI.DialogueBox)
	dbStroke.Color = Color3.fromRGB(60, 30, 30)
	dbStroke.Thickness = 2

	GUI.SpeakerLbl = UIHelpers.CreateLabel(GUI.DialogueBox, "SPEAKER", UDim2.new(1, -20, 0, 30), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 18)
	GUI.SpeakerLbl.Position = UDim2.new(0, 15, 0, 10)
	GUI.SpeakerLbl.TextXAlignment = Enum.TextXAlignment.Left

	GUI.DialogueText = UIHelpers.CreateLabel(GUI.DialogueBox, "", UDim2.new(1, -30, 1, -60), Enum.Font.GothamMedium, Color3.fromRGB(240, 240, 240), 16)
	GUI.DialogueText.Position = UDim2.new(0, 15, 0, 45)
	GUI.DialogueText.TextXAlignment = Enum.TextXAlignment.Left
	GUI.DialogueText.TextYAlignment = Enum.TextYAlignment.Top
	GUI.DialogueText.TextWrapped = true

	GUI.ContinueHint = UIHelpers.CreateLabel(GUI.DialogueBox, "Click anywhere to continue ▼", UDim2.new(1, -20, 0, 20), Enum.Font.GothamBold, Color3.fromRGB(150, 150, 150), 12)
	GUI.ContinueHint.Position = UDim2.new(0, 0, 1, -25)
	GUI.ContinueHint.Visible = false

	GUI.ClickOverlay = Instance.new("TextButton", GUI.CombatWindow)
	GUI.ClickOverlay.Size = UDim2.new(1, 0, 1, 0)
	GUI.ClickOverlay.BackgroundTransparency = 1
	GUI.ClickOverlay.Text = ""
	GUI.ClickOverlay.ZIndex = 110
	GUI.ClickOverlay.Visible = false

	GUI.ChoicesContainer = Instance.new("Frame", GUI.DialogueBox)
	GUI.ChoicesContainer.Size = UDim2.new(1, 0, 1, -40)
	GUI.ChoicesContainer.Position = UDim2.new(0, 0, 0, 40)
	GUI.ChoicesContainer.BackgroundTransparency = 1
	GUI.ChoicesContainer.Visible = false
	local ccLayout = Instance.new("UIListLayout", GUI.ChoicesContainer)
	ccLayout.Padding = UDim.new(0, 10)
	ccLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	return GUI
end

return CombatBuilder