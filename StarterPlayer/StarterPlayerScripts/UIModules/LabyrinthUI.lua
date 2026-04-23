-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
-- Name: LabyrinthUI
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

local function GetFloorTheme(floor)
	local cycle = floor % 3
	if cycle == 1 then
		return Color3.fromRGB(150, 180, 255), Color3.fromRGB(30, 45, 65), Color3.fromRGB(20, 25, 30) 
	elseif cycle == 2 then
		return Color3.fromRGB(150, 255, 150), Color3.fromRGB(40, 60, 40), Color3.fromRGB(20, 25, 20) 
	else
		return Color3.fromRGB(255, 120, 120), Color3.fromRGB(60, 25, 25), Color3.fromRGB(25, 20, 20) 
	end
end

local function ToggleAtmosphere(state, floorLevel)
	local cc = Lighting:FindFirstChild("LabyrinthCC")
	local blur = Lighting:FindFirstChild("LabyrinthBlur")

	if state then
		if not cc then cc = Instance.new("ColorCorrectionEffect", Lighting); cc.Name = "LabyrinthCC" end
		if not blur then blur = Instance.new("BlurEffect", Lighting); blur.Name = "LabyrinthBlur" end

		local tint, _, _ = GetFloorTheme(floorLevel or 1)
		TweenService:Create(cc, TweenInfo.new(1.5, Enum.EasingStyle.Sine), {Brightness = -0.3, Contrast = 0.4, Saturation = -0.4, TintColor = tint}):Play()
		TweenService:Create(blur, TweenInfo.new(1.5, Enum.EasingStyle.Sine), {Size = 24}):Play()
	else
		if cc then TweenService:Create(cc, TweenInfo.new(1, Enum.EasingStyle.Sine), {Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.fromRGB(255, 255, 255)}):Play() end
		if blur then TweenService:Create(blur, TweenInfo.new(1, Enum.EasingStyle.Sine), {Size = 0}):Play() end
	end
end

-- [[ THE FIX: dynamically pulls floor level so we don't spawn duplicate loops ]]
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
			btn.BackgroundTransparency = 1
			btn.BorderSizePixel = 0
			btn.Size = UDim2.new(0, cellSize, 0, cellSize)
			btn.Position = UDim2.new(0, (x - 1) * cellSize, 0, (y - 1) * cellSize)
			btn.AutoButtonColor = false

			local strk = Instance.new("UIStroke", btn)
			strk.Thickness = 1
			strk.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			strk.Color = Color3.fromRGB(50, 50, 60)
			strk.Transparency = 1

			local iconFrame = Instance.new("Frame", btn)
			iconFrame.AnchorPoint = Vector2.new(0.5, 0.5)
			iconFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
			iconFrame.BackgroundTransparency = 1
			iconFrame.BorderSizePixel = 0
			iconFrame.Visible = false

			if cellVal == 1 then 
				iconFrame.Size = UDim2.new(0.45, 0, 0.45, 0)
				iconFrame.BackgroundColor3 = Color3.fromRGB(220, 40, 40)
				iconFrame.Rotation = 45

				local inner = Instance.new("Frame", iconFrame)
				inner.Size = UDim2.new(0.5, 0, 0.5, 0)
				inner.AnchorPoint = Vector2.new(0.5, 0.5)
				inner.Position = UDim2.new(0.5, 0, 0.5, 0)
				inner.BackgroundColor3 = Color3.fromRGB(255, 120, 120)
				inner.BorderSizePixel = 0

				task.spawn(function()
					while iconFrame.Parent do
						local t = TweenService:Create(iconFrame, TweenInfo.new(2, Enum.EasingStyle.Linear), {Rotation = iconFrame.Rotation + 90})
						t:Play(); t.Completed:Wait()
					end
				end)

			elseif cellVal == 2 then 
				iconFrame.Size = UDim2.new(0.4, 0, 0.4, 0)
				iconFrame.BackgroundColor3 = Color3.fromRGB(40, 200, 40)

				local inner = Instance.new("Frame", iconFrame)
				inner.Size = UDim2.new(0.5, 0, 0.5, 0)
				inner.AnchorPoint = Vector2.new(0.5, 0.5)
				inner.Position = UDim2.new(0.5, 0, 0.5, 0)
				inner.BackgroundColor3 = UIHelpers.Colors.Gold
				inner.BorderSizePixel = 0

			elseif cellVal == 3 then 
				iconFrame.Size = UDim2.new(0.55, 0, 0.55, 0)
				iconFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)

				local inner = Instance.new("Frame", iconFrame)
				inner.Size = UDim2.new(0.6, 0, 0.8, 0)
				inner.AnchorPoint = Vector2.new(0.5, 1)
				inner.Position = UDim2.new(0.5, 0, 1, 0)
				inner.BackgroundColor3 = tileColor
				inner.BorderSizePixel = 0
			end

			btn.MouseButton1Click:Connect(function()
				if btn.Active and not isMoving then
					local px, py = CurrentSession.PlayerX, CurrentSession.PlayerY
					if (math.abs(px - x) == 1 and py == y) or (math.abs(py - y) == 1 and px == x) then
						isMoving = true

						local ripple = Instance.new("Frame", btn)
						ripple.AnchorPoint = Vector2.new(0.5, 0.5); ripple.Position = UDim2.new(0.5, 0, 0.5, 0); ripple.Size = UDim2.new(0, 0, 0, 0)
						ripple.BackgroundColor3 = Color3.fromRGB(200, 200, 255); ripple.BackgroundTransparency = 0.5; ripple.ZIndex = 15; ripple.BorderSizePixel = 0
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

	PlayerAvatar.BackgroundColor3 = playerColor
	local paStroke = PlayerAvatar:FindFirstChild("UIStroke") or Instance.new("UIStroke", PlayerAvatar)
	paStroke.Color = Color3.fromRGB(255, 255, 255)
	paStroke.Thickness = 2

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
	TweenService:Create(MapContainer, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
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

			local targetTrans = 1
			if dist <= 1.5 then targetTrans = 0.05
			elseif dist <= 2.5 then targetTrans = 0.25
			elseif dist <= 3.5 then targetTrans = 0.55
			elseif dist <= 4.5 then targetTrans = 0.85
			else targetTrans = 1.0 end

			cellData.Icon.Visible = false
			cellData.Btn.BackgroundColor3 = tileColor

			if val == 5 then 
				cellData.Btn.BackgroundColor3 = playerColor
			elseif val == 1 then 
				cellData.Icon.Visible = true
				cellData.Stroke.Color = isAdj and Color3.fromRGB(220, 50, 50) or Color3.fromRGB(80, 40, 40)
			elseif val == 2 then 
				cellData.Icon.Visible = true
				cellData.Stroke.Color = isAdj and Color3.fromRGB(50, 220, 50) or Color3.fromRGB(40, 80, 40)
			elseif val == 3 then 
				cellData.Icon.Visible = true
				cellData.Stroke.Color = isAdj and Color3.fromRGB(200, 200, 200) or Color3.fromRGB(100, 100, 100)
			elseif val == 4 then 
				cellData.Btn.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
				cellData.Stroke.Color = Color3.fromRGB(30, 30, 40)
			else 
				cellData.Stroke.Color = isAdj and mapTint or Color3.fromRGB(40, 40, 50)
			end

			if isAdj then cellData.Btn.Active = true else cellData.Btn.Active = false end

			TweenService:Create(cellData.Btn, TweenInfo.new(0.4, Enum.EasingStyle.Sine), {BackgroundTransparency = targetTrans}):Play()
			TweenService:Create(cellData.Stroke, TweenInfo.new(0.4, Enum.EasingStyle.Sine), {Transparency = targetTrans}):Play()

			if cellData.Icon.Visible then
				cellData.Icon.BackgroundTransparency = targetTrans
				for _, descendant in ipairs(cellData.Icon:GetDescendants()) do
					if descendant:IsA("Frame") then descendant.BackgroundTransparency = targetTrans end
				end
			end
		end
	end
end

function LabyrinthUI.Initialize(masterScreenGui)
	GUI = Instance.new("Frame", masterScreenGui)
	GUI.Name = "LabyrinthUI"
	GUI.Size = UDim2.new(1, 0, 1, 0)
	GUI.BackgroundColor3 = Color3.fromRGB(5, 5, 8)
	GUI.BackgroundTransparency = 0.15
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
	TopBar.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
	TopBar.BorderSizePixel = 0
	TopBar.ZIndex = 2
	Instance.new("UIStroke", TopBar).Color = Color3.fromRGB(40, 40, 45)

	local TitleLbl = CreateSharpLabel(TopBar, "THE LABYRINTH", UDim2.new(1, 0, 0, 40), Enum.Font.Garamond, Color3.fromRGB(200, 220, 255), 32)
	TitleLbl.Position = UDim2.new(0, 0, 0, 10)
	TitleLbl.ZIndex = 3

	local SubTitleLbl = CreateSharpLabel(TopBar, "DESCENDING...", UDim2.new(1, 0, 0, 20), Enum.Font.GothamBold, Color3.fromRGB(150, 150, 180), 16)
	SubTitleLbl.Position = UDim2.new(0, 0, 0, 50)
	SubTitleLbl.ZIndex = 3

	GridContainer = Instance.new("Frame", GUI)
	GridContainer.Size = UDim2.new(0, 520, 0, 520)
	GridContainer.Position = UDim2.new(0.4, 0, 0.5, -20)
	GridContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	GridContainer.BackgroundColor3 = Color3.fromRGB(8, 8, 10) 
	GridContainer.BorderSizePixel = 0
	GridContainer.ZIndex = 2
	GridContainer.ClipsDescendants = true 

	local mapStroke = Instance.new("UIStroke", GridContainer)
	mapStroke.Color = Color3.fromRGB(30, 30, 35)
	mapStroke.Thickness = 4

	MapContainer = Instance.new("Frame", GridContainer)
	MapContainer.BackgroundTransparency = 1
	MapContainer.Position = UDim2.new(0.5, 0, 0.5, 0)

	PlayerAvatar = Instance.new("Frame", GridContainer)
	PlayerAvatar.Size = UDim2.new(0, 65, 0, 65)
	PlayerAvatar.AnchorPoint = Vector2.new(0.5, 0.5)
	PlayerAvatar.Position = UDim2.new(0.5, 0, 0.5, 0)
	PlayerAvatar.BackgroundColor3 = Color3.fromRGB(30, 45, 65)
	PlayerAvatar.ZIndex = 10
	PlayerAvatar.BorderSizePixel = 0

	local avatarGlow = Instance.new("Frame", PlayerAvatar)
	avatarGlow.Size = UDim2.new(0.6, 0, 0.6, 0)
	avatarGlow.AnchorPoint = Vector2.new(0.5, 0.5)
	avatarGlow.Position = UDim2.new(0.5, 0, 0.5, 0)
	avatarGlow.BackgroundColor3 = Color3.fromRGB(150, 200, 255)
	avatarGlow.BorderSizePixel = 0

	task.spawn(function()
		while GUI do
			local tIn = TweenService:Create(avatarGlow, TweenInfo.new(1.5, Enum.EasingStyle.Sine), {Size = UDim2.new(0.4, 0, 0.4, 0), BackgroundTransparency = 0.5})
			tIn:Play(); tIn.Completed:Wait()
			local tOut = TweenService:Create(avatarGlow, TweenInfo.new(1.5, Enum.EasingStyle.Sine), {Size = UDim2.new(0.6, 0, 0.6, 0), BackgroundTransparency = 0})
			tOut:Play(); tOut.Completed:Wait()
		end
	end)

	PouchContainer = Instance.new("Frame", GUI)
	PouchContainer.Size = UDim2.new(0, 250, 0, 350)
	PouchContainer.Position = UDim2.new(0.85, 0, 0.5, -20)
	PouchContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	PouchContainer.BackgroundColor3 = Color3.fromRGB(20, 15, 12) 
	PouchContainer.BorderSizePixel = 0
	PouchContainer.ZIndex = 2

	local pouchStroke = Instance.new("UIStroke", PouchContainer)
	pouchStroke.Color = Color3.fromRGB(180, 120, 60)
	pouchStroke.Thickness = 2

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
	Divider.BackgroundColor3 = Color3.fromRGB(180, 120, 60)
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

			-- [[ THE FIX: Extracted so atmosphere is forced to change no matter what ]]
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