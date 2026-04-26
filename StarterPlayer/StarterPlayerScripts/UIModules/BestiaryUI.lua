-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local BestiaryUI = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EnemyData = require(ReplicatedStorage:WaitForChild("EnemyData"))
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local C_VOID = Color3.fromRGB(12, 12, 15)
local C_STEEL = Color3.fromRGB(80, 85, 90)
local C_RUST = Color3.fromRGB(140, 50, 40)
local C_TEXT_MUTED = Color3.fromRGB(180, 180, 180)
local C_TEXT_BRIGHT = Color3.fromRGB(240, 240, 240)
local C_GOLD = Color3.fromRGB(252, 228, 141)

local GUI = {}

local function GenerateTactics(enemy)
	if enemy.Desc then return enemy.Desc end

	local t = "Standard combat protocols apply. Target the nape."
	if enemy.GateType == "Reinforced Skin" then 
		t = "Heavily armored. Use Thunder Spears or high Armor Penetration to break the gate before striking."
	elseif enemy.GateType == "Hardening" then 
		t = "Crystal hardening present. Massive damage required to shatter the gate."
	elseif enemy.GateType == "Steam" then 
		t = "Emits colossal steam. Melee attacks are repelled. Maneuver and evade to outlast the heat."
	elseif enemy.IsLongRange then 
		t = "Attacks from a distance. Use 'Close In' or 'Advance' maneuvers to reach striking range." 
	end
	return t
end

local function ParseDrops(dropsTable)
	local parsed = {}
	if dropsTable.XP then 
		table.insert(parsed, {ItemName = "Experience (XP)", Rate = "100", Color = Color3.fromRGB(85, 255, 85)}) 
	end
	if dropsTable.Dews then 
		table.insert(parsed, {ItemName = "Dews", Rate = "100", Color = Color3.fromRGB(255, 136, 255)}) 
	end

	if dropsTable.ItemChance then
		for itemName, baseChance in pairs(dropsTable.ItemChance) do
			local finalChance = math.clamp(baseChance, 0.01, 100)
			local displayRate = math.floor(finalChance * 100) / 100

			local color = C_TEXT_MUTED 
			if itemName:find("Serum") or itemName:find("Syringe") then color = Color3.fromRGB(255, 85, 255)
			elseif itemName:find("Fragment") or itemName:find("Crown") then color = C_GOLD
			elseif itemName:find("Blood") then color = Color3.fromRGB(255, 85, 85)
			elseif itemName:find("Crystal") or itemName:find("Shard") then color = Color3.fromRGB(85, 255, 255)
			elseif itemName:find("Steel") or itemName:find("Gear") then color = Color3.fromRGB(150, 150, 200) end

			table.insert(parsed, {ItemName = itemName, Rate = tostring(displayRate), Color = color})
		end
	end

	table.sort(parsed, function(a, b) return tonumber(a.Rate) > tonumber(b.Rate) end)
	return parsed
end

local function UpdateLayoutForScreen()
	local vp = camera.ViewportSize
	if vp.X == 0 or vp.Y == 0 or not GUI.ContentFrame then return end
	local isMobile = (vp.X <= 850) or (vp.Y > vp.X)

	if isMobile then
		GUI.ContentFrame.Size = UDim2.new(1, -10, 1, -10)
		GUI.ContentFrame.Position = UDim2.new(0, 5, 0, 5)

		GUI.cfLayout.FillDirection = Enum.FillDirection.Vertical

		GUI.ListPanel.Size = UDim2.new(1, 0, 0, 350)
		GUI.DisplayPanel.Size = UDim2.new(1, 0, 0, 500)

		if GUI.EnemyName then
			GUI.EnemyName.TextSize = 20
			GUI.EnemyName.Size = UDim2.new(1, -90, 1, 0)
		end
		if GUI.EnemyImage then
			GUI.EnemyImage.Size = UDim2.new(0, 70, 0, 70)
		end
	else
		GUI.ContentFrame.Size = UDim2.new(1, -40, 1, -40)
		GUI.ContentFrame.Position = UDim2.new(0, 20, 0, 20)

		GUI.cfLayout.FillDirection = Enum.FillDirection.Horizontal

		GUI.ListPanel.Size = UDim2.new(0.35, -15, 1, 0)
		GUI.DisplayPanel.Size = UDim2.new(0.65, 0, 1, 0)

		if GUI.EnemyName then
			GUI.EnemyName.TextSize = 28
			GUI.EnemyName.Size = UDim2.new(1, -110, 1, 0)
		end
		if GUI.EnemyImage then
			GUI.EnemyImage.Size = UDim2.new(0, 100, 0, 100)
		end
	end
end

function BestiaryUI.Initialize(masterScreenGui)
	GUI.Container = Instance.new("Frame", masterScreenGui)
	GUI.Container.Name = "BestiaryWindow"
	GUI.Container.Size = UDim2.new(1, 0, 1, 0)
	GUI.Container.BackgroundTransparency = 1
	GUI.Container.Visible = true 
	GUI.Container.ZIndex = 100

	GUI.ContentFrame = Instance.new("Frame", GUI.Container)
	GUI.ContentFrame.Size = UDim2.new(1, -40, 1, -40)
	GUI.ContentFrame.Position = UDim2.new(0, 20, 0, 20)
	GUI.ContentFrame.BackgroundColor3 = C_VOID
	GUI.ContentFrame.BorderSizePixel = 0

	local mainStroke = Instance.new("UIStroke", GUI.ContentFrame)
	mainStroke.Color = C_RUST
	mainStroke.Thickness = 2
	mainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	mainStroke.LineJoinMode = Enum.LineJoinMode.Miter

	local innerStrokeFrame = Instance.new("Frame", GUI.ContentFrame)
	innerStrokeFrame.Size = UDim2.new(1, -12, 1, -12)
	innerStrokeFrame.Position = UDim2.new(0, 6, 0, 6)
	innerStrokeFrame.BackgroundTransparency = 1

	local innerStroke = Instance.new("UIStroke", innerStrokeFrame)
	innerStroke.Color = Color3.fromRGB(30, 30, 35)
	innerStroke.Thickness = 1
	innerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	innerStroke.LineJoinMode = Enum.LineJoinMode.Miter

	GUI.ScrollContainer = Instance.new("ScrollingFrame", GUI.ContentFrame)
	GUI.ScrollContainer.Size = UDim2.new(1, 0, 1, 0)
	GUI.ScrollContainer.BackgroundTransparency = 1
	GUI.ScrollContainer.ScrollBarThickness = 0
	GUI.ScrollContainer.BorderSizePixel = 0

	GUI.cfLayout = Instance.new("UIListLayout", GUI.ScrollContainer)
	GUI.cfLayout.Padding = UDim.new(0, 15)
	GUI.cfLayout.SortOrder = Enum.SortOrder.LayoutOrder

	GUI.cfLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		if GUI.cfLayout.FillDirection == Enum.FillDirection.Vertical then
			GUI.ScrollContainer.CanvasSize = UDim2.new(0, 0, 0, GUI.cfLayout.AbsoluteContentSize.Y + 30)
		else
			GUI.ScrollContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
		end
	end)

	local cPad = Instance.new("UIPadding", GUI.ScrollContainer)
	cPad.PaddingTop = UDim.new(0, 15); cPad.PaddingBottom = UDim.new(0, 15); cPad.PaddingLeft = UDim.new(0, 15); cPad.PaddingRight = UDim.new(0, 15)

	-- ===================================
	-- LEFT PANEL: ENEMY LIST
	-- ===================================
	GUI.ListPanel = Instance.new("ScrollingFrame", GUI.ScrollContainer)
	GUI.ListPanel.LayoutOrder = 1
	GUI.ListPanel.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
	GUI.ListPanel.BorderSizePixel = 0
	GUI.ListPanel.ScrollBarThickness = 4
	GUI.ListPanel.ScrollBarImageColor3 = C_RUST

	local lpStroke = Instance.new("UIStroke", GUI.ListPanel)
	lpStroke.Color = C_STEEL
	lpStroke.Thickness = 1
	lpStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	lpStroke.LineJoinMode = Enum.LineJoinMode.Miter

	local listLayout = Instance.new("UIListLayout", GUI.ListPanel)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 0)
	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		GUI.ListPanel.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
	end)

	-- ===================================
	-- RIGHT PANEL: CLEAN OVERHAUL
	-- ===================================
	GUI.DisplayPanel = Instance.new("ScrollingFrame", GUI.ScrollContainer)
	GUI.DisplayPanel.BackgroundTransparency = 1
	GUI.DisplayPanel.LayoutOrder = 2
	GUI.DisplayPanel.ScrollBarThickness = 4
	GUI.DisplayPanel.BorderSizePixel = 0

	local dpLayout = Instance.new("UIListLayout", GUI.DisplayPanel)
	dpLayout.SortOrder = Enum.SortOrder.LayoutOrder
	dpLayout.Padding = UDim.new(0, 15)
	dpLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		GUI.DisplayPanel.CanvasSize = UDim2.new(0, 0, 0, dpLayout.AbsoluteContentSize.Y + 20)
	end)

	-- 1. Header (Name + Image)
	local dHeader = Instance.new("Frame", GUI.DisplayPanel)
	dHeader.Size = UDim2.new(1, 0, 0, 100)
	dHeader.BackgroundTransparency = 1
	dHeader.LayoutOrder = 1

	GUI.EnemyName = Instance.new("TextLabel", dHeader)
	GUI.EnemyName.Size = UDim2.new(1, -110, 1, 0)
	GUI.EnemyName.BackgroundTransparency = 1
	GUI.EnemyName.Text = "SELECT TARGET"
	GUI.EnemyName.Font = Enum.Font.GothamBlack
	GUI.EnemyName.TextColor3 = C_TEXT_BRIGHT
	GUI.EnemyName.TextSize = 28
	GUI.EnemyName.TextXAlignment = Enum.TextXAlignment.Left
	GUI.EnemyName.TextYAlignment = Enum.TextYAlignment.Center
	GUI.EnemyName.TextWrapped = true

	GUI.EnemyImage = Instance.new("ImageLabel", dHeader)
	GUI.EnemyImage.Size = UDim2.new(0, 100, 0, 100)
	GUI.EnemyImage.Position = UDim2.new(1, 0, 0, 0)
	GUI.EnemyImage.AnchorPoint = Vector2.new(1, 0)
	GUI.EnemyImage.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
	GUI.EnemyImage.ScaleType = Enum.ScaleType.Crop
	GUI.EnemyImage.Image = EnemyData.BossIcons["System"] or ""

	local imgStroke = Instance.new("UIStroke", GUI.EnemyImage)
	imgStroke.Color = C_STEEL
	imgStroke.Thickness = 2
	imgStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	-- 2. Divider
	local div1 = Instance.new("Frame", GUI.DisplayPanel)
	div1.Size = UDim2.new(1, 0, 0, 2)
	div1.BackgroundColor3 = C_RUST
	div1.BorderSizePixel = 0
	div1.LayoutOrder = 2

	-- 3. Tactics Header
	local tacHeader = Instance.new("TextLabel", GUI.DisplayPanel)
	tacHeader.Size = UDim2.new(1, 0, 0, 20)
	tacHeader.BackgroundTransparency = 1
	tacHeader.LayoutOrder = 3
	tacHeader.Text = "TACTICAL REPORT"
	tacHeader.Font = Enum.Font.GothamBlack
	tacHeader.TextColor3 = C_GOLD
	tacHeader.TextSize = 16
	tacHeader.TextXAlignment = Enum.TextXAlignment.Left

	-- 4. Tactics Description
	GUI.WeaknessText = Instance.new("TextLabel", GUI.DisplayPanel)
	GUI.WeaknessText.Size = UDim2.new(1, 0, 0, 0)
	GUI.WeaknessText.AutomaticSize = Enum.AutomaticSize.Y
	GUI.WeaknessText.BackgroundTransparency = 1
	GUI.WeaknessText.LayoutOrder = 4
	GUI.WeaknessText.Text = "Awaiting cross-reference..."
	GUI.WeaknessText.Font = Enum.Font.GothamMedium
	GUI.WeaknessText.TextColor3 = C_TEXT_MUTED
	GUI.WeaknessText.TextSize = 14
	GUI.WeaknessText.TextWrapped = true
	GUI.WeaknessText.TextYAlignment = Enum.TextYAlignment.Top
	GUI.WeaknessText.TextXAlignment = Enum.TextXAlignment.Left

	-- 5. Loot Header Box
	local LootHeaderFrame = Instance.new("Frame", GUI.DisplayPanel)
	LootHeaderFrame.Size = UDim2.new(1, 0, 0, 30)
	LootHeaderFrame.BackgroundColor3 = Color3.fromRGB(20, 15, 15)
	LootHeaderFrame.BorderSizePixel = 0
	LootHeaderFrame.LayoutOrder = 5

	local lootHeaderStroke = Instance.new("UIStroke", LootHeaderFrame)
	lootHeaderStroke.Color = C_STEEL
	lootHeaderStroke.Thickness = 1
	lootHeaderStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	local LootHeader = Instance.new("TextLabel", LootHeaderFrame)
	LootHeader.Size = UDim2.new(1, -15, 1, 0)
	LootHeader.Position = UDim2.new(0, 15, 0, 0)
	LootHeader.BackgroundTransparency = 1
	LootHeader.Text = "GLOBAL DROP RATES"
	LootHeader.Font = Enum.Font.GothamBlack
	LootHeader.TextColor3 = C_RUST
	LootHeader.TextSize = 14
	LootHeader.TextXAlignment = Enum.TextXAlignment.Left

	-- 6. Loot Container
	GUI.LootScroll = Instance.new("Frame", GUI.DisplayPanel)
	GUI.LootScroll.Size = UDim2.new(1, 0, 0, 0)
	GUI.LootScroll.AutomaticSize = Enum.AutomaticSize.Y
	GUI.LootScroll.BackgroundTransparency = 1
	GUI.LootScroll.LayoutOrder = 6

	local lootInnerLayout = Instance.new("UIListLayout", GUI.LootScroll)
	lootInnerLayout.Padding = UDim.new(0, 4)

	local currentLayoutOrder = 1 

	local function AddEnemyButton(enemyKey, enemyTable)
		local btn = Instance.new("TextButton")
		btn.Name = "EnemyBtn_" .. enemyKey
		btn.Size = UDim2.new(1, 0, 0, 35)
		btn.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
		btn.BorderSizePixel = 0
		btn.Text = "             " .. string.upper(enemyTable.Name or enemyKey)
		btn.Font = Enum.Font.GothamBold
		btn.TextColor3 = C_TEXT_MUTED
		btn.TextSize = 12
		btn.TextXAlignment = Enum.TextXAlignment.Left

		local stroke = Instance.new("UIStroke", btn)
		stroke.Color = Color3.fromRGB(35, 35, 40)
		stroke.Thickness = 1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.LineJoinMode = Enum.LineJoinMode.Miter

		local icon = Instance.new("ImageLabel", btn)
		icon.Size = UDim2.new(0, 25, 0, 25)
		icon.Position = UDim2.new(0, 5, 0.5, -12.5)
		icon.BackgroundTransparency = 1
		icon.ScaleType = Enum.ScaleType.Crop
		icon.Image = EnemyData.BossIcons[enemyKey] or EnemyData.BossIcons[enemyTable.Name] or EnemyData.BossIcons["System"] or ""

		local iconStroke = Instance.new("UIStroke", icon)
		iconStroke.Color = C_STEEL
		iconStroke.Thickness = 1
		iconStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

		btn.MouseButton1Click:Connect(function()
			local formattedData = {
				Key = enemyKey,
				Name = enemyTable.Name or enemyKey,
				Tactics = GenerateTactics(enemyTable),
				Drops = ParseDrops(enemyTable.Drops or {})
			}
			BestiaryUI.LoadEnemyData(GUI, formattedData)

			for _, child in ipairs(GUI.ListPanel:GetChildren()) do
				if child:IsA("TextButton") and string.find(child.Name, "EnemyBtn_") then
					child.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
					child.TextColor3 = C_TEXT_MUTED
				end
			end
			btn.BackgroundColor3 = Color3.fromRGB(30, 25, 25)
			btn.TextColor3 = C_GOLD
		end)

		return btn
	end

	local function AddCategory(title, sortedEnemyArray)
		local headerBtn = Instance.new("TextButton", GUI.ListPanel)
		headerBtn.Name = "Header_" .. title
		headerBtn.LayoutOrder = currentLayoutOrder
		currentLayoutOrder = currentLayoutOrder + 1

		headerBtn.Size = UDim2.new(1, 0, 0, 35)
		headerBtn.BackgroundColor3 = Color3.fromRGB(25, 18, 18)
		headerBtn.BorderSizePixel = 0
		headerBtn.Text = "  [ ▼ ]  " .. title
		headerBtn.Font = Enum.Font.GothamBlack
		headerBtn.TextColor3 = C_RUST
		headerBtn.TextSize = 13
		headerBtn.TextXAlignment = Enum.TextXAlignment.Left
		headerBtn.AutoButtonColor = false

		local s = Instance.new("UIStroke", headerBtn)
		s.Color = Color3.fromRGB(60, 30, 30)
		s.Thickness = 1
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.LineJoinMode = Enum.LineJoinMode.Miter

		local isOpen = true
		local itemBtns = {}

		for _, entry in ipairs(sortedEnemyArray) do
			local btn = AddEnemyButton(entry.Key, entry.Data)
			btn.LayoutOrder = currentLayoutOrder
			currentLayoutOrder = currentLayoutOrder + 1
			btn.Parent = GUI.ListPanel
			table.insert(itemBtns, btn)
		end

		headerBtn.MouseButton1Click:Connect(function()
			isOpen = not isOpen
			headerBtn.Text = (isOpen and "  [ ▼ ]  " or "  [ ▶ ]  ") .. title
			for _, b in ipairs(itemBtns) do
				b.Visible = isOpen
			end
		end)
	end

	local function DictToSortedArray(dict)
		local arr = {}
		for k, v in pairs(dict or {}) do
			table.insert(arr, {Key = type(k) == "number" and v.Name or k, Data = v})
		end
		table.sort(arr, function(a, b) return string.upper(a.Data.Name or a.Key) < string.upper(b.Data.Name or b.Key) end)
		return arr
	end

	local CampaignArray = {}
	local seenCampaign = {}
	if EnemyData.Parts then
		for i = 1, 20 do 
			local part = EnemyData.Parts[i]
			if part then
				for key, temp in pairs(part.Templates or {}) do
					if temp.Health and not temp.IsDialogue and not temp.IsMinigame then
						local eKey = temp.Name or key
						if not seenCampaign[eKey] then
							seenCampaign[eKey] = true
							table.insert(CampaignArray, {Key = key, Data = temp})
						end
					end
				end
				for _, mob in ipairs(part.Mobs or {}) do
					local eKey = mob.Name
					if not seenCampaign[eKey] then
						seenCampaign[eKey] = true
						table.insert(CampaignArray, {Key = mob.Name, Data = mob})
					end
				end
			end
		end
	end

	local EndlessArray = {}
	local seenEndless = {}
	local function InsertIntoEndless(key, data)
		local eKey = data.Name or key
		if not seenEndless[eKey] then
			seenEndless[eKey] = true
			table.insert(EndlessArray, {Key = key, Data = data})
		end
	end

	for _, entry in ipairs(CampaignArray) do InsertIntoEndless(entry.Key, entry.Data) end
	for k, v in pairs(EnemyData.RaidBosses or {}) do InsertIntoEndless(k, v) end
	for k, v in pairs(EnemyData.WorldBosses or {}) do InsertIntoEndless(k, v) end
	for k, v in pairs(EnemyData.NightmareHunts or {}) do InsertIntoEndless(k, v) end
	for k, v in pairs(EnemyData.PathsMemories or {}) do InsertIntoEndless(k, v) end

	table.sort(EndlessArray, function(a, b) return string.upper(a.Data.Name or a.Key) < string.upper(b.Data.Name or b.Key) end)

	local displayCategories = {
		{ Title = "ENDLESS EXPEDITION", Data = EndlessArray },
		{ Title = "CAMPAIGN MISSIONS", Data = CampaignArray },
		{ Title = "RAID DEPLOYMENTS", Data = DictToSortedArray(EnemyData.RaidBosses) },
		{ Title = "WORLD BOSSES", Data = DictToSortedArray(EnemyData.WorldBosses) },
		{ Title = "NIGHTMARE HUNTS", Data = DictToSortedArray(EnemyData.NightmareHunts) },
		{ Title = "PATHS MEMORIES", Data = DictToSortedArray(EnemyData.PathsMemories) }
	}

	for _, cat in ipairs(displayCategories) do
		if #cat.Data > 0 then
			AddCategory(cat.Title, cat.Data)
		end
	end

	camera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateLayoutForScreen)
	UpdateLayoutForScreen()

	return GUI
end

function BestiaryUI.LoadEnemyData(GUI, formattedData)
	GUI.EnemyName.Text = string.upper(formattedData.Name)
	GUI.WeaknessText.Text = formattedData.Tactics

	local fallbackIcon = EnemyData.BossIcons["System"] or ""
	GUI.EnemyImage.Image = EnemyData.BossIcons[formattedData.Key] or EnemyData.BossIcons[formattedData.Name] or fallbackIcon

	for _, child in ipairs(GUI.LootScroll:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
	end

	if #formattedData.Drops == 0 then
		local dText = Instance.new("TextLabel", GUI.LootScroll)
		dText.Size = UDim2.new(1, 0, 0, 30)
		dText.BackgroundTransparency = 1
		dText.Text = "No known remains recorded."
		dText.Font = Enum.Font.GothamMedium
		dText.TextColor3 = C_STEEL
		dText.TextSize = 13
		dText.TextXAlignment = Enum.TextXAlignment.Left
		return
	end

	for _, drop in ipairs(formattedData.Drops) do
		local dropFrame = Instance.new("Frame", GUI.LootScroll)
		dropFrame.Size = UDim2.new(1, 0, 0, 35)
		dropFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
		dropFrame.BorderSizePixel = 0

		local rarityColor = drop.Color or C_TEXT_MUTED
		local dStroke = Instance.new("UIStroke", dropFrame)
		dStroke.Color = Color3.new(rarityColor.R * 0.4, rarityColor.G * 0.4, rarityColor.B * 0.4)
		dStroke.Thickness = 1
		dStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		dStroke.LineJoinMode = Enum.LineJoinMode.Miter

		local nameLbl = Instance.new("TextLabel", dropFrame)
		nameLbl.Size = UDim2.new(0.7, 0, 1, 0)
		nameLbl.Position = UDim2.new(0, 15, 0, 0)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = drop.ItemName
		nameLbl.Font = Enum.Font.GothamBold
		nameLbl.TextColor3 = rarityColor
		nameLbl.TextSize = 13
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left

		local rateLbl = Instance.new("TextLabel", dropFrame)
		rateLbl.Size = UDim2.new(0.3, -15, 1, 0)
		rateLbl.Position = UDim2.new(0.7, 0, 0, 0)
		rateLbl.BackgroundTransparency = 1
		rateLbl.Text = drop.Rate .. "%"
		rateLbl.Font = Enum.Font.GothamBlack
		rateLbl.TextColor3 = C_TEXT_BRIGHT
		rateLbl.TextSize = 14
		rateLbl.TextXAlignment = Enum.TextXAlignment.Right
	end
end

return BestiaryUI