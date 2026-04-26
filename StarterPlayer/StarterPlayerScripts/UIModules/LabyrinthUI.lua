-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local LabyrinthUI = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Network = ReplicatedStorage:WaitForChild("Network")

local player = Players.LocalPlayer
local playerScripts = player:WaitForChild("PlayerScripts")
local SharedUI = playerScripts:WaitForChild("SharedUI")
local UIHelpers = require(SharedUI:WaitForChild("UIHelpers"))

local GUI = nil
local GridContainer = nil
local MapContainer = nil
local PlayerAvatar = nil
local PouchContainer = nil
local LootDisplay = nil
local CurrentSession = nil
local ExitMenu = nil

local GridCells = {}
local RevealedTiles = {}
local isMoving = false

local Suffixes = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx"}
local function AbbreviateNumber(n)
	if not n then return "0" end; n = tonumber(n) or 0
	if n < 1000 then return tostring(math.floor(n)) end
	local suffixIndex = math.floor(math.log10(n) / 3); local value = n / (10 ^ (suffixIndex * 3))
	local str = string.format("%.1f", value); str = str:gsub("%.0$", "")
	return str .. (Suffixes[suffixIndex + 1] or "")
end

-- DUNGEON THEMES
local function GetFloorTheme(floor)
	local cycle = floor % 3
	if cycle == 1 then
		-- The Dungeon (Cold, Bleak)
		return Color3.fromRGB(120, 140, 180), Color3.fromRGB(20, 25, 35), Color3.fromRGB(15, 18, 22) 
	elseif cycle == 2 then
		-- The Overgrown Ruins (Rotting Green)
		return Color3.fromRGB(120, 170, 120), Color3.fromRGB(25, 35, 25), Color3.fromRGB(18, 22, 18) 
	else
		-- The Blood Crypts (Deep Crimson)
		return Color3.fromRGB(190, 80, 80), Color3.fromRGB(40, 15, 15), Color3.fromRGB(22, 12, 12) 
	end
end

-- HEAVY DUNGEON ATMOSPHERE
local function ToggleAtmosphere(state, floorLevel)
	local cc = Lighting:FindFirstChild("LabyrinthCC")
	local blur = Lighting:FindFirstChild("LabyrinthBlur")

	if state then
		if not cc then cc = Instance.new("ColorCorrectionEffect", Lighting); cc.Name = "LabyrinthCC" end
		if not blur then blur = Instance.new("BlurEffect", Lighting); blur.Name = "LabyrinthBlur" end

		local tint, _, _ = GetFloorTheme(floorLevel or 1)
		-- Much harsher contrast and darkness for that claustrophobic dungeon feel
		TweenService:Create(cc, TweenInfo.new(1.5, Enum.EasingStyle.Sine), {Brightness = -0.45, Contrast = 0.5, Saturation = -0.5, TintColor = tint}):Play()
		TweenService:Create(blur, TweenInfo.new(1.5, Enum.EasingStyle.Sine), {Size = 28}):Play()
	else
		if cc then TweenService:Create(cc, TweenInfo.new(1, Enum.EasingStyle.Sine), {Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.fromRGB(255, 255, 255)}):Play() end
		if blur then TweenService:Create(blur, TweenInfo.new(1, Enum.EasingStyle.Sine), {Size = 0}):Play() end
	end
end

local function SpawnPathDust()
	task.spawn(function()
		while GUI and GUI.Visible do
			local floorLvl = CurrentSession and CurrentSession.Floor or 1
			local tint, _, _ = GetFloorTheme(floorLvl)

			local dust = Instance.new("Frame", GUI)
			dust.BackgroundColor3 = tint
			dust.Size = UDim2.new(0, math.random(2, 4), 0, math.random(2, 4))
			dust.Position = UDim2.new(math.random(), 0, 1.1, 0)
			dust.ZIndex = 1
			dust.BorderSizePixel = 0

			local speed = math.random(8, 15)
			local t1 = TweenService:Create(dust, TweenInfo.new(speed, Enum.EasingStyle.Linear), {
				Position = UDim2.new(dust.Position.X.Scale + (math.random(-10, 10)/100), 0, -0.1, 0),
				BackgroundTransparency = 1
			})
			t1:Play()
			t1.Completed:Connect(function() dust:Destroy() end)

			task.wait(math.random(2, 5) / 10)
		end
	end)
end

local function CreateSharpLabel(parent, text, size, font, color, textSize)
	local lbl = Instance.new("TextLabel", parent)
	lbl.Size = size; lbl.BackgroundTransparency = 1; lbl.Font = font; lbl.TextColor3 = color; lbl.TextSize = textSize; lbl.Text = text
	lbl.TextXAlignment = Enum.TextXAlignment.Center; lbl.TextYAlignment = Enum.TextYAlignment.Center
	return lbl
end

local function CreateSharpButton(parent, text, size, font, textSize)
	local btn = Instance.new("TextButton", parent)
	btn.Size = size; btn.BackgroundColor3 = Color3.fromRGB(22, 22, 26); btn.BorderSizePixel = 0; btn.AutoButtonColor = false
	btn.Font = font; btn.TextColor3 = Color3.fromRGB(245, 245, 245); btn.TextSize = textSize; btn.Text = text
	local stroke = Instance.new("UIStroke", btn)
	stroke.Color = Color3.fromRGB(70, 70, 80); stroke.Thickness = 2; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	btn.MouseEnter:Connect(function() stroke.Color = Color3.fromRGB(255, 85, 85); btn.TextColor3 = Color3.fromRGB(255, 85, 85) end)
	btn.MouseLeave:Connect(function() stroke.Color = Color3.fromRGB(70, 70, 80); btn.TextColor3 = Color3.fromRGB(245, 245, 245) end)
	return btn, stroke
end

local function BuildGrid()
	for _, child in ipairs(MapContainer:GetChildren()) do child:Destroy() end
	GridCells = {}

	local size = CurrentSession.Size
	local cellSize = 65 

	MapContainer.Size = UDim2.new(0, size * cellSize, 0, size * cellSize)

	local _, playerColor, tileColor = GetFloorTheme(CurrentSession.Floor)

	for y = 1, size do
		GridCells[y] = {}
		for x = 1, size do
			local cellVal = CurrentSession.Grid[y][x]
			if cellVal == -1 then continue end 

			local btn = Instance.new("TextButton", MapContainer)
			btn.Text = ""
			btn.BackgroundColor3 = tileColor
			-- Creates a 4px gap between tiles so it looks like distinct stone blocks
			btn.Size = UDim2.new(0, cellSize - 4, 0, cellSize - 4)
			btn.Position = UDim2.new(0, ((x - 1) * cellSize) + 2, 0, ((y - 1) * cellSize) + 2)
			btn.AutoButtonColor = false

			-- 3D Bevel effect for the stone tiles
			local grad = Instance.new("UIGradient", btn)
			grad.Rotation = 90
			grad.Color = ColorSequence.new{
				ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(1, Color3.new(0.5, 0.5, 0.5))
			}

			local strk = Instance.new("UIStroke", btn)
			strk.Thickness = 2
			strk.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			strk.Color = Color3.fromRGB(20, 20, 25)

			local iconFrame = Instance.new("Frame", btn)
			iconFrame.AnchorPoint = Vector2.new(0.5, 0.5)
			iconFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
			iconFrame.BackgroundTransparency = 1
			iconFrame.BorderSizePixel = 0
			iconFrame.Visible = false

			if cellVal == 1 then -- ENEMY (Menacing Red Pulse)
				iconFrame.Size = UDim2.new(0.45, 0, 0.45, 0)
				iconFrame.BackgroundColor3 = Color3.fromRGB(220, 30, 30)
				iconFrame.Rotation = 45

				local inner = Instance.new("Frame", iconFrame)
				inner.Size = UDim2.new(0.6, 0, 0.6, 0)
				inner.AnchorPoint = Vector2.new(0.5, 0.5)
				inner.Position = UDim2.new(0.5, 0, 0.5, 0)
				inner.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
				inner.BorderSizePixel = 0

				-- Heartbeat animation for enemies
				task.spawn(function()
					while iconFrame.Parent do
						local t1 = TweenService:Create(iconFrame, TweenInfo.new(0.3, Enum.EasingStyle.Sine), {Size = UDim2.new(0.55, 0, 0.55, 0)})
						local t2 = TweenService:Create(iconFrame, TweenInfo.new(0.6, Enum.EasingStyle.Sine), {Size = UDim2.new(0.45, 0, 0.45, 0)})
						t1:Play(); t1.Completed:Wait(); t2:Play(); t2.Completed:Wait()
						task.wait(0.5)
					end
				end)

			elseif cellVal == 2 then -- LOOT / REST (Green Glow)
				iconFrame.Size = UDim2.new(0.4, 0, 0.4, 0)
				iconFrame.BackgroundColor3 = Color3.fromRGB(40, 200, 80)

				local inner = Instance.new("Frame", iconFrame)
				inner.Size = UDim2.new(0.6, 0, 0.6, 0)
				inner.AnchorPoint = Vector2.new(0.5, 0.5)
				inner.Position = UDim2.new(0.5, 0, 0.5, 0)
				inner.BackgroundColor3 = UIHelpers.Colors.Gold
				inner.BorderSizePixel = 0

			elseif cellVal == 3 then -- EXIT (Glowing White Gateway)
				iconFrame.Size = UDim2.new(0.5, 0, 0.6, 0)
				iconFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)

				local inner = Instance.new("Frame", iconFrame)
				inner.Size = UDim2.new(0.7, 0, 0.8, 0)
				inner.AnchorPoint = Vector2.new(0.5, 1)
				inner.Position = UDim2.new(0.5, 0, 1, 0)
				inner.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
				inner.BorderSizePixel = 0
			end

			btn.MouseButton1Click:Connect(function()
				if btn.Active and not isMoving then
					local px, py = CurrentSession.PlayerX, CurrentSession.PlayerY
					if (math.abs(px - x) == 1 and py == y) or (math.abs(py - y) == 1 and px == x) then
						isMoving = true

						-- Sharp Footstep Ripple
						local ripple = Instance.new("Frame", btn)
						ripple.AnchorPoint = Vector2.new(0.5, 0.5); ripple.Position = UDim2.new(0.5, 0, 0.5, 0); ripple.Size = UDim2.new(0, 0, 0, 0)
						ripple.BackgroundColor3 = Color3.fromRGB(255, 220, 150); ripple.BackgroundTransparency = 0.2; ripple.ZIndex = 15; ripple.BorderSizePixel = 0
						local t = TweenService:Create(ripple, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(2.5, 0, 2.5, 0), BackgroundTransparency = 1})
						t:Play(); t.Completed:Connect(function() ripple:Destroy() end)

						Network:WaitForChild("LabyrinthAction"):FireServer("Move", x, y)
						task.wait(0.3)
						isMoving = false
					end
				end
			end)

			GridCells[y][x] = { Btn = btn, Stroke = strk, Icon = iconFrame, Val = cellVal }
		end
	end

	-- Player Torch Avatar (Sharp Block)
	PlayerAvatar.BackgroundColor3 = Color3.fromRGB(255, 200, 100)
	PlayerAvatar.Size = UDim2.new(0, 45, 0, 45) -- Fits inside the tiles

	local paStroke = PlayerAvatar:FindFirstChild("UIStroke") or Instance.new("UIStroke", PlayerAvatar)
	paStroke.Color = Color3.fromRGB(255, 255, 255)
	paStroke.Thickness = 2

	local avatarGlow = PlayerAvatar:FindFirstChild("TorchGlow")
	if not avatarGlow then
		avatarGlow = Instance.new("ImageLabel", PlayerAvatar)
		avatarGlow.Name = "TorchGlow"
		avatarGlow.Size = UDim2.new(5, 0, 5, 0)
		avatarGlow.AnchorPoint = Vector2.new(0.5, 0.5)
		avatarGlow.Position = UDim2.new(0.5, 0, 0.5, 0)
		avatarGlow.BackgroundTransparency = 1
		avatarGlow.Image = "rbxassetid://2001828033" -- Radial glow image
		avatarGlow.ImageColor3 = Color3.fromRGB(255, 180, 50)
		avatarGlow.ZIndex = 0

		-- Flickering torch effect
		task.spawn(function()
			while GUI do
				local tIn = TweenService:Create(avatarGlow, TweenInfo.new(math.random(8,15)/10, Enum.EasingStyle.Sine), {Size = UDim2.new(4.5, 0, 4.5, 0), ImageTransparency = 0.6})
				tIn:Play(); tIn.Completed:Wait()
				local tOut = TweenService:Create(avatarGlow, TweenInfo.new(math.random(8,15)/10, Enum.EasingStyle.Sine), {Size = UDim2.new(5.5, 0, 5.5, 0), ImageTransparency = 0.3})
				tOut:Play(); tOut.Completed:Wait()
			end
		end)
	end

	local targetX = -((CurrentSession.PlayerX - 0.5) * cellSize)
	local targetY = -((CurrentSession.PlayerY - 0.5) * cellSize)
	MapContainer.Position = UDim2.new(0.5, targetX, 0.5, targetY)
end

local function UpdateGridVisibility()
	if not MapContainer or not CurrentSession then return end

	local px, py = CurrentSession.PlayerX, CurrentSession.PlayerY
	local mapTint, playerColor, tileColor = GetFloorTheme(CurrentSession.Floor)
	local cellSize = 65

	local targetX = -((px - 0.5) * cellSize)
	local targetY = -((py - 0.5) * cellSize)
	TweenService:Create(MapContainer, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, targetX, 0.5, targetY)
	}):Play()

	for dy = -4, 4 do
		for dx = -4, 4 do
			local ax, ay = px + dx, py + dy
			if ax >= 1 and ax <= CurrentSession.Size and ay >= 1 and ay <= CurrentSession.Size then
				RevealedTiles[ay .. "_" .. ax] = true
			end
		end
	end

	for y = 1, CurrentSession.Size do
		for x = 1, CurrentSession.Size do
			local cellData = GridCells[y][x]
			if not cellData then continue end

			local val = CurrentSession.Grid[y][x]
			local isAdj = (math.abs(px - x) == 1 and py == y) or (math.abs(py - y) == 1 and px == x)
			local dist = math.sqrt(math.pow(px - x, 2) + math.pow(py - y, 2))

			if not RevealedTiles[y .. "_" .. x] then continue end

			-- The Torchlight "Fog of War"
			local targetColor = tileColor
			local targetStrkColor = Color3.fromRGB(20, 20, 25)

			if dist <= 1.5 then 
				-- Direct light (Adjacent)
				targetColor = tileColor
			elseif dist <= 2.5 then 
				-- Dim light
				targetColor = Color3.new(tileColor.R * 0.4, tileColor.G * 0.4, tileColor.B * 0.4)
				targetStrkColor = Color3.fromRGB(10, 10, 12)
			else 
				-- Pitch Black (Outside torch radius)
				targetColor = Color3.new(0, 0, 0)
				targetStrkColor = Color3.new(0, 0, 0)
			end

			cellData.Icon.Visible = false

			if val == 5 then 
				-- The tile the player is standing on should just be lit tile color, the Avatar is separate
				cellData.Btn.BackgroundColor3 = tileColor
			elseif val == 1 then 
				cellData.Icon.Visible = true
				cellData.Stroke.Color = isAdj and Color3.fromRGB(255, 80, 80) or targetStrkColor
			elseif val == 2 then 
				cellData.Icon.Visible = true
				cellData.Stroke.Color = isAdj and Color3.fromRGB(80, 255, 80) or targetStrkColor
			elseif val == 3 then 
				cellData.Icon.Visible = true
				cellData.Stroke.Color = isAdj and Color3.fromRGB(255, 255, 255) or targetStrkColor
			elseif val == 4 then 
				-- Solid Walls
				targetColor = Color3.fromRGB(8, 8, 10)
				cellData.Stroke.Color = Color3.new(0,0,0)
			else 
				cellData.Stroke.Color = isAdj and Color3.fromRGB(255, 200, 100) or targetStrkColor
			end

			if isAdj then cellData.Btn.Active = true else cellData.Btn.Active = false end

			-- Tween into the light/darkness smoothly
			TweenService:Create(cellData.Btn, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {BackgroundColor3 = targetColor}):Play()

			if cellData.Icon.Visible then
				local iconTrans = (dist <= 2.5) and 0 or 1
				TweenService:Create(cellData.Icon, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {BackgroundTransparency = iconTrans}):Play()
				for _, descendant in ipairs(cellData.Icon:GetDescendants()) do
					if descendant:IsA("Frame") then 
						TweenService:Create(descendant, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {BackgroundTransparency = iconTrans}):Play()
					end
				end
			end
		end
	end
end

function LabyrinthUI.Initialize(masterScreenGui)
	GUI = Instance.new("Frame", masterScreenGui)
	GUI.Name = "LabyrinthUI"
	GUI.Size = UDim2.new(1, 0, 1, 0)
	GUI.BackgroundColor3 = Color3.fromRGB(2, 2, 3) -- Pitch black overlay
	GUI.BackgroundTransparency = 0.1
	GUI.Visible = false
	GUI.ZIndex = 50 

	local ClickBlocker = Instance.new("TextButton", GUI)
	ClickBlocker.Size = UDim2.new(1, 0, 1, 0)
	ClickBlocker.BackgroundTransparency = 1
	ClickBlocker.Text = ""
	ClickBlocker.ZIndex = 1 
	ClickBlocker.AutoButtonColor = false

	local TopBar = Instance.new("Frame", GUI)
	TopBar.Size = UDim2.new(1, 0, 0, 80)
	TopBar.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
	TopBar.BorderSizePixel = 0
	TopBar.ZIndex = 2
	Instance.new("UIStroke", TopBar).Color = Color3.fromRGB(30, 30, 35)

	-- Dark gradient for the top bar
	local tbGrad = Instance.new("UIGradient", TopBar)
	tbGrad.Rotation = 90
	tbGrad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.new(1,1,1)), ColorSequenceKeypoint.new(1, Color3.new(0.5,0.5,0.5))}

	local TitleLbl = CreateSharpLabel(TopBar, "THE LABYRINTH", UDim2.new(1, 0, 0, 40), Enum.Font.Garamond, Color3.fromRGB(200, 220, 255), 36)
	TitleLbl.Position = UDim2.new(0, 0, 0, 10)
	TitleLbl.ZIndex = 3

	local SubTitleLbl = CreateSharpLabel(TopBar, "DESCENDING...", UDim2.new(1, 0, 0, 20), Enum.Font.GothamBold, Color3.fromRGB(150, 150, 180), 16)
	SubTitleLbl.Position = UDim2.new(0, 0, 0, 50)
	SubTitleLbl.ZIndex = 3

	GridContainer = Instance.new("Frame", GUI)
	GridContainer.Size = UDim2.new(0, 520, 0, 520)
	GridContainer.Position = UDim2.new(0.4, 0, 0.5, -20)
	GridContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	GridContainer.BackgroundColor3 = Color3.fromRGB(5, 5, 6) 
	GridContainer.BorderSizePixel = 0
	GridContainer.ZIndex = 2
	GridContainer.ClipsDescendants = true 

	local mapStroke = Instance.new("UIStroke", GridContainer)
	mapStroke.Color = Color3.fromRGB(20, 20, 25)
	mapStroke.Thickness = 6

	MapContainer = Instance.new("Frame", GridContainer)
	MapContainer.BackgroundTransparency = 1
	MapContainer.Position = UDim2.new(0.5, 0, 0.5, 0)

	PlayerAvatar = Instance.new("Frame", GridContainer)
	PlayerAvatar.Size = UDim2.new(0, 45, 0, 45)
	PlayerAvatar.AnchorPoint = Vector2.new(0.5, 0.5)
	PlayerAvatar.Position = UDim2.new(0.5, 0, 0.5, 0)
	PlayerAvatar.BackgroundColor3 = Color3.fromRGB(255, 200, 100)
	PlayerAvatar.ZIndex = 10
	PlayerAvatar.BorderSizePixel = 0

	-- Leather-themed Labyrinth Pouch (Sharp edges)
	PouchContainer = Instance.new("Frame", GUI)
	PouchContainer.Size = UDim2.new(0, 250, 0, 350)
	PouchContainer.Position = UDim2.new(0.85, 0, 0.5, -20)
	PouchContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	PouchContainer.BackgroundColor3 = Color3.fromRGB(35, 25, 20) 
	PouchContainer.BorderSizePixel = 0
	PouchContainer.ZIndex = 2

	local pGrad = Instance.new("UIGradient", PouchContainer)
	pGrad.Rotation = 45
	pGrad.Color = ColorSequence.new{ColorSequenceKeypoint.new(0, Color3.new(1,1,1)), ColorSequenceKeypoint.new(1, Color3.new(0.6,0.6,0.6))}

	local pouchStroke = Instance.new("UIStroke", PouchContainer)
	pouchStroke.Color = Color3.fromRGB(80, 50, 30)
	pouchStroke.Thickness = 4

	local spLayout = Instance.new("UIListLayout", PouchContainer)
	spLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	spLayout.Padding = UDim.new(0, 15)
	local spPad = Instance.new("UIPadding", PouchContainer)
	spPad.PaddingTop = UDim.new(0, 20)

	local pouchTitle = CreateSharpLabel(PouchContainer, "🎒 LABYRINTH POUCH", UDim2.new(0.9, 0, 0, 20), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 18)
	pouchTitle.ZIndex = 3

	local warningLbl = CreateSharpLabel(PouchContainer, "Lost upon death or abandonment.", UDim2.new(0.9, 0, 0, 15), Enum.Font.GothamMedium, Color3.fromRGB(255, 100, 100), 11)
	warningLbl.ZIndex = 3

	local Divider = Instance.new("Frame", PouchContainer)
	Divider.Size = UDim2.new(0.8, 0, 0, 2)
	Divider.BackgroundColor3 = Color3.fromRGB(80, 50, 30)
	Divider.BorderSizePixel = 0
	Divider.ZIndex = 3

	LootDisplay = CreateSharpLabel(PouchContainer, "0 Dews\n0 XP", UDim2.new(0.9, 0, 0, 150), Enum.Font.GothamBold, Color3.fromRGB(230, 230, 230), 14)
	LootDisplay.TextYAlignment = Enum.TextYAlignment.Top
	LootDisplay.RichText = true
	LootDisplay.ZIndex = 3

	local LeaveBtn, _ = CreateSharpButton(GUI, "ABANDON RUN", UDim2.new(0, 150, 0, 40), Enum.Font.GothamBlack, 16)
	LeaveBtn.Position = UDim2.new(0, 20, 1, -20)
	LeaveBtn.AnchorPoint = Vector2.new(0, 1)
	LeaveBtn.TextColor3 = Color3.fromRGB(255, 85, 85)
	LeaveBtn.ZIndex = 3

	LeaveBtn.MouseButton1Click:Connect(function()
		GUI.Visible = false
		ToggleAtmosphere(false)
		Network:WaitForChild("LabyrinthAction"):FireServer("Abandon")
	end)

	ExitMenu = Instance.new("Frame", GUI)
	ExitMenu.Size = UDim2.new(1, 0, 1, 0)
	ExitMenu.BackgroundColor3 = Color3.new(0,0,0)
	ExitMenu.BackgroundTransparency = 0.2
	ExitMenu.Visible = false
	ExitMenu.ZIndex = 200
	ExitMenu.Active = true

	local emPanel = Instance.new("Frame", ExitMenu)
	emPanel.Size = UDim2.new(0, 400, 0, 200)
	emPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
	emPanel.AnchorPoint = Vector2.new(0.5, 0.5)
	emPanel.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
	Instance.new("UIStroke", emPanel).Color = Color3.fromRGB(255, 255, 255)

	CreateSharpLabel(emPanel, "EXIT FOUND", UDim2.new(1, 0, 0, 40), Enum.Font.GothamBlack, Color3.fromRGB(255, 255, 255), 24).Position = UDim2.new(0, 0, 0, 20)
	CreateSharpLabel(emPanel, "Secure your Pouch, or delve deeper?", UDim2.new(1, 0, 0, 20), Enum.Font.GothamMedium, Color3.fromRGB(180, 180, 180), 14).Position = UDim2.new(0, 0, 0, 70)

	local ExtractBtn, _ = CreateSharpButton(emPanel, "EXTRACT", UDim2.new(0.4, 0, 0, 40), Enum.Font.GothamBlack, 16)
	ExtractBtn.Position = UDim2.new(0.05, 0, 1, -20); ExtractBtn.AnchorPoint = Vector2.new(0, 1)
	ExtractBtn.TextColor3 = Color3.fromRGB(85, 255, 85)

	local DescendBtn, _ = CreateSharpButton(emPanel, "DESCEND", UDim2.new(0.4, 0, 0, 40), Enum.Font.GothamBlack, 16)
	DescendBtn.Position = UDim2.new(0.95, 0, 1, -20); DescendBtn.AnchorPoint = Vector2.new(1, 1)
	DescendBtn.TextColor3 = Color3.fromRGB(255, 85, 85)

	ExtractBtn.MouseButton1Click:Connect(function()
		ExitMenu.Visible = false
		GUI.Visible = false
		ToggleAtmosphere(false)
		Network:WaitForChild("LabyrinthAction"):FireServer("Extract")
	end)

	DescendBtn.MouseButton1Click:Connect(function()
		ExitMenu.Visible = false
		RevealedTiles = {}
		Network:WaitForChild("LabyrinthAction"):FireServer("NextFloor")
	end)

	Network:WaitForChild("LabyrinthUpdate").OnClientEvent:Connect(function(action, data)
		if action == "InitSync" then
			CurrentSession = data
			BuildGrid() 

			local tint, _, _ = GetFloorTheme(data.Floor)
			TitleLbl.TextColor3 = tint
			SubTitleLbl.Text = "FLOOR " .. data.Floor

			local lootStr = "<font color='#FFD700'>+" .. AbbreviateNumber(data.AccumulatedLoot.Dews) .. " Dews</font>\n<font color='#55FF55'>+" .. AbbreviateNumber(data.AccumulatedLoot.XP) .. " XP</font>\n\n"
			for itemName, amt in pairs(data.AccumulatedLoot.Items or {}) do
				lootStr = lootStr .. "<font color='#DDDDDD'>" .. amt .. "x " .. itemName .. "</font>\n"
			end
			LootDisplay.Text = lootStr

			UpdateGridVisibility()
			ToggleAtmosphere(true, data.Floor)

			if not GUI.Visible then 
				GUI.Visible = true 
				SpawnPathDust()
			end

		elseif action == "Sync" then
			CurrentSession = data

			local tint, _, _ = GetFloorTheme(data.Floor)
			TitleLbl.TextColor3 = tint
			SubTitleLbl.Text = "FLOOR " .. data.Floor

			local lootStr = "<font color='#FFD700'>+" .. AbbreviateNumber(data.AccumulatedLoot.Dews) .. " Dews</font>\n<font color='#55FF55'>+" .. AbbreviateNumber(data.AccumulatedLoot.XP) .. " XP</font>\n\n"
			for itemName, amt in pairs(data.AccumulatedLoot.Items or {}) do
				lootStr = lootStr .. "<font color='#DDDDDD'>" .. amt .. "x " .. itemName .. "</font>\n"
			end
			LootDisplay.Text = lootStr

			UpdateGridVisibility()

			if not GUI.Visible then 
				GUI.Visible = true 
				ToggleAtmosphere(true, data.Floor)
				SpawnPathDust()
			end

		elseif action == "ReachedExit" then
			CurrentSession = data
			UpdateGridVisibility()
			ExitMenu.Visible = true

		elseif action == "CombatStart" then
			local shadow = Instance.new("Frame", masterScreenGui)
			shadow.Size = UDim2.new(1, 0, 1, 0)
			shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			shadow.BackgroundTransparency = 1
			shadow.ZIndex = 999

			TweenService:Create(shadow, TweenInfo.new(0.4, Enum.EasingStyle.Sine), {BackgroundTransparency = 0}):Play()
			task.wait(0.5)

			GUI.Visible = false 
			ToggleAtmosphere(false) 

			TweenService:Create(shadow, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {BackgroundTransparency = 1}):Play()
			game.Debris:AddItem(shadow, 1)

		elseif action == "Death" then
			GUI.Visible = false
			ExitMenu.Visible = false
			RevealedTiles = {}
			ToggleAtmosphere(false)
		end
	end)
end

function LabyrinthUI.Open(masterScreenGui)
	if not GUI and masterScreenGui then LabyrinthUI.Initialize(masterScreenGui) end
	if GUI then 
		RevealedTiles = {}
		isMoving = false
		Network:WaitForChild("LabyrinthAction"):FireServer("Init") 
	end
end

return LabyrinthUI