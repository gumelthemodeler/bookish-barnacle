-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local HeroMenu = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Network = ReplicatedStorage:WaitForChild("Network")

local SharedUI = script.Parent.Parent:WaitForChild("SharedUI")
local UIHelpers = require(SharedUI:WaitForChild("UIHelpers"))
local notifModule = SharedUI:WaitForChild("NotificationManager", 2)
local NotificationManager = notifModule and require(notifModule) or nil
local auraModule = SharedUI:WaitForChild("UIAuraManager", 2)
local UIAuraManager = auraModule and require(auraModule) or nil

-- [[ FIX: Directly require TooltipManager ]]
local tooltipModule = SharedUI:WaitForChild("TooltipManager", 2)
local TooltipManager = tooltipModule and require(tooltipModule) or nil

local VFXManager = require(script.Parent.Parent:WaitForChild("VFXManager"))
local cinModule = script.Parent:WaitForChild("CinematicManager", 2)
local CinematicManager = cinModule and require(cinModule) or nil

local GameData = require(ReplicatedStorage:WaitForChild("GameData"))
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))
local CosmeticData = require(ReplicatedStorage:WaitForChild("CosmeticData"))
local TitanData = require(ReplicatedStorage:WaitForChild("TitanData"))
local hasSkillData, SkillData = pcall(function() return require(ReplicatedStorage:WaitForChild("SkillData")) end)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local RarityColors = { ["Common"] = "#AAAAAA", ["Uncommon"] = "#55FF55", ["Rare"] = "#5588FF", ["Epic"] = "#CC44FF", ["Legendary"] = "#FFD700", ["Mythical"] = "#FF3333", ["Transcendent"] = "#FF55FF" }
local RarityOrder = { Transcendent = 0, Mythical = 1, Legendary = 2, Epic = 3, Rare = 4, Uncommon = 5, Common = 6 }
local TEXT_COLORS = { PrestigeYellow = "#FFD700", EloBlue = "#55AAFF", DefaultGreen = "#55FF55", DewsPink = "#FF88FF" }
local REG_COLORS = { ["Garrison"] = "#FF5555", ["Military Police"] = "#55FF55", ["Scout Regiment"] = "#55AAFF" }

local UnlockedCosmeticsCache = { Titles = {}, Auras = {} }
local CosmeticUIUpdaters = {}
local InitialCachePopulated = false

local LayoutRefs = {}

local function EvaluateCosmetics()
	if type(CosmeticData.CheckUnlock) ~= "function" then return end
	local isFullyLoaded = player:GetAttribute("DataLoaded") == true

	for key, data in pairs(CosmeticData.Titles or {}) do
		if CosmeticData.CheckUnlock(player, data.ReqType, data.ReqValue) and not UnlockedCosmeticsCache.Titles[key] then
			UnlockedCosmeticsCache.Titles[key] = true
			if InitialCachePopulated and NotificationManager and type(NotificationManager.Show) == "function" then 
				NotificationManager.Show("New Title Unlocked: " .. data.Name, "Success") 
			end
		end
	end

	for key, data in pairs(CosmeticData.Auras or {}) do
		if CosmeticData.CheckUnlock(player, data.ReqType, data.ReqValue) and not UnlockedCosmeticsCache.Auras[key] then
			UnlockedCosmeticsCache.Auras[key] = true
			if InitialCachePopulated and NotificationManager and type(NotificationManager.Show) == "function" then 
				NotificationManager.Show("New Aura Unlocked: " .. data.Name, "Success") 
			end
		end
	end

	if isFullyLoaded then InitialCachePopulated = true end
	for _, updater in ipairs(CosmeticUIUpdaters) do if type(updater) == "function" then updater() end end
end
EvaluateCosmetics()

local function CreateGrimPanel(parent)
	local frame = Instance.new("Frame", parent)
	frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22); frame.BorderSizePixel = 0
	local stroke = Instance.new("UIStroke", frame)
	stroke.Color = Color3.fromRGB(70, 70, 80); stroke.Thickness = 2; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return frame, stroke
end

local function CreateSharpLabel(parent, text, size, font, color, textSize)
	local lbl = Instance.new("TextLabel", parent)
	lbl.Size = size; lbl.BackgroundTransparency = 1; lbl.Font = font; lbl.TextColor3 = color; lbl.TextSize = textSize; lbl.Text = text
	lbl.TextXAlignment = Enum.TextXAlignment.Center; lbl.TextYAlignment = Enum.TextYAlignment.Center
	return lbl
end

local function CreateSharpButton(parent, text, size, font, textSize)
	local btn = Instance.new("TextButton", parent)
	btn.Size = size; btn.BackgroundColor3 = Color3.fromRGB(28, 28, 34); btn.BorderSizePixel = 0; btn.AutoButtonColor = false
	btn.Font = font; btn.TextColor3 = Color3.fromRGB(245, 245, 245); btn.TextSize = textSize; btn.Text = text
	local stroke = Instance.new("UIStroke", btn)
	stroke.Color = Color3.fromRGB(70, 70, 80); stroke.Thickness = 2; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	btn.MouseEnter:Connect(function() stroke.Color = Color3.fromRGB(225, 185, 60); btn.TextColor3 = Color3.fromRGB(225, 185, 60) end)
	btn.MouseLeave:Connect(function() stroke.Color = Color3.fromRGB(70, 70, 80); btn.TextColor3 = Color3.fromRGB(245, 245, 245) end)
	return btn, stroke
end

local function DrawLine(parent, p1, p2)
	local distance = (p2 - p1).Magnitude
	local center = (p1 + p2) / 2
	local angle = math.deg(math.atan2(p2.Y - p1.Y, p2.X - p1.X))

	local line = Instance.new("Frame")
	line.Size = UDim2.new(0, distance, 0, 6)
	line.Position = UDim2.new(0, center.X, 0, center.Y)
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Rotation = angle
	line.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	line.BorderSizePixel = 0
	line.ZIndex = 1
	line.Parent = parent
	return line
end

local Suffixes = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx"}
local function AbbreviateNumber(n)
	if not n then return "0" end; n = tonumber(n) or 0
	if n < 1000 then return tostring(math.floor(n)) end
	local suffixIndex = math.floor(math.log10(n) / 3); local value = n / (10 ^ (suffixIndex * 3))
	local str = string.format("%.1f", value); str = str:gsub("%.0$", "")
	return str .. (Suffixes[suffixIndex + 1] or "")
end

local function GetRankColor(rank)
	if rank == "S" then return Color3.fromRGB(255, 215, 0)
	elseif rank == "A" then return Color3.fromRGB(85, 255, 85)
	elseif rank == "B" then return Color3.fromRGB(85, 150, 255)
	elseif rank == "C" then return Color3.fromRGB(170, 85, 255)
	else return Color3.fromRGB(170, 170, 170) end
end

-- ==========================================
-- IDENTITY TAB
-- ==========================================
local function BuildIdentityTab(parentFrame)
	local function DrawLineScale(parent, p1x, p1y, p2x, p2y, color, thickness, zindex)
		local dx = p2x - p1x; local dy = p2y - p1y; local dist = math.sqrt(dx*dx + dy*dy)
		local frame = Instance.new("Frame", parent)
		frame.Size = UDim2.new(0, dist, 0, thickness); frame.Position = UDim2.new(0, (p1x + p2x)/2, 0, (p1y + p2y)/2)
		frame.AnchorPoint = Vector2.new(0.5, 0.5); frame.Rotation = math.deg(math.atan2(dy, dx))
		frame.BackgroundColor3 = color; frame.BorderSizePixel = 0; frame.ZIndex = zindex or 1
		return frame
	end

	local function DrawUITriangle(parent, p1, p2, p3, color, transp, zIndex)
		local edges = { {p1, p2}, {p2, p3}, {p3, p1} }
		table.sort(edges, function(a, b) return (a[1]-a[2]).Magnitude > (b[1]-b[2]).Magnitude end)
		local a, b = edges[1][1], edges[1][2]; local c = edges[2][1] == a and edges[2][2] or edges[2][1]
		if c == b then c = edges[3][1] == a and edges[3][2] or edges[3][1] end
		local ab = b - a; local ac = c - a; local dir = ab.Unit; local projLen = ac:Dot(dir); local proj = dir * projLen; local h = (ac - proj).Magnitude
		local w1 = projLen; local w2 = ab.Magnitude - projLen
		local t1 = Instance.new("ImageLabel")
		t1.BackgroundTransparency = 1; t1.Image = "rbxassetid://319692171"; t1.ImageColor3 = color; t1.ImageTransparency = transp; t1.ZIndex = zIndex; t1.BorderSizePixel = 0; t1.AnchorPoint = Vector2.new(0.5, 0.5)
		local t2 = t1:Clone(); t1.Size = UDim2.new(0, w1, 0, h); t2.Size = UDim2.new(0, w2, 0, h)
		t1.Position = UDim2.new(0, a.X + proj.X/2, 0, a.Y + proj.Y/2); t2.Position = UDim2.new(0, b.X + (proj.X - ab.X)/2, 0, b.Y + (proj.Y - ab.Y)/2)
		t1.Rotation = math.deg(math.atan2(dir.Y, dir.X)); t2.Rotation = math.deg(math.atan2(-dir.Y, -dir.X))
		t1.Parent = parent; t2.Parent = parent
	end

	local MainScroll = Instance.new("ScrollingFrame", parentFrame)
	MainScroll.Size = UDim2.new(1, 0, 1, 0)
	MainScroll.BackgroundTransparency = 1
	MainScroll.ScrollBarThickness = 6
	MainScroll.BorderSizePixel = 0
	MainScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local mLayout = Instance.new("UIListLayout", MainScroll)
	mLayout.SortOrder = Enum.SortOrder.LayoutOrder
	mLayout.Padding = UDim.new(0, 15)
	mLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	mLayout.FillDirection = Enum.FillDirection.Vertical 

	local mPad = Instance.new("UIPadding", MainScroll)
	mPad.PaddingTop = UDim.new(0, 10)
	mPad.PaddingBottom = UDim.new(0, 30)

	local ColumnsWrapper = Instance.new("Frame", MainScroll)
	ColumnsWrapper.Size = UDim2.new(1, 0, 0, 0)
	ColumnsWrapper.AutomaticSize = Enum.AutomaticSize.Y
	ColumnsWrapper.BackgroundTransparency = 1
	ColumnsWrapper.LayoutOrder = 1
	local cwLayout = Instance.new("UIListLayout", ColumnsWrapper)
	cwLayout.FillDirection = Enum.FillDirection.Horizontal 
	cwLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	cwLayout.Padding = UDim.new(0, 15)

	cwLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		ColumnsWrapper.Size = UDim2.new(1, 0, 0, cwLayout.AbsoluteContentSize.Y)
	end)

	local ShowcaseCard = CreateGrimPanel(ColumnsWrapper)
	ShowcaseCard.Size = UDim2.new(0.31, 0, 0, 430)
	ShowcaseCard.LayoutOrder = 1

	local AvatarTitle = CreateSharpLabel(ShowcaseCard, "HUMANITY'S VANGUARD", UDim2.new(1, 0, 0, 25), Enum.Font.GothamBlack, Color3.fromRGB(225, 185, 60), 20)
	AvatarTitle.Position = UDim2.new(0, 0, 0, 15)

	local AvatarContainer = Instance.new("Frame", ShowcaseCard)
	AvatarContainer.Size = UDim2.new(0, 150, 0, 150)
	AvatarContainer.Position = UDim2.new(0.5, 0, 0, 50)
	AvatarContainer.AnchorPoint = Vector2.new(0.5, 0)
	AvatarContainer.BackgroundTransparency = 1

	local AvatarAuraGlow = Instance.new("Frame", AvatarContainer)
	AvatarAuraGlow.Size = UDim2.new(1, 0, 1, 0)
	AvatarAuraGlow.Position = UDim2.new(0.5, 0, 0.5, 0)
	AvatarAuraGlow.AnchorPoint = Vector2.new(0.5, 0.5)
	AvatarAuraGlow.BackgroundTransparency = 1
	Instance.new("UICorner", AvatarAuraGlow).CornerRadius = UDim.new(1, 0)

	local AvatarBox = Instance.new("ImageLabel", AvatarContainer)
	AvatarBox.Size = UDim2.new(1, 0, 1, 0)
	AvatarBox.Position = UDim2.new(0.5, 0, 0.5, 0)
	AvatarBox.AnchorPoint = Vector2.new(0.5, 0.5)
	AvatarBox.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
	AvatarBox.Image = "rbxthumb://type=AvatarBust&id="..player.UserId.."&w=420&h=420"
	AvatarBox.BorderSizePixel = 0
	AvatarBox.ZIndex = 5
	Instance.new("UICorner", AvatarBox).CornerRadius = UDim.new(1, 0)
	local boxStroke = Instance.new("UIStroke", AvatarBox); boxStroke.Color = Color3.fromRGB(70, 70, 80); boxStroke.Thickness = 2

	local PlayerNameLbl = CreateSharpLabel(ShowcaseCard, string.upper(player.Name), UDim2.new(1, 0, 0, 30), Enum.Font.GothamBlack, Color3.fromRGB(245, 245, 245), 24)
	PlayerNameLbl.Position = UDim2.new(0, 0, 0, 210)

	local regIcon = Instance.new("ImageLabel", ShowcaseCard)
	regIcon.Size = UDim2.new(0, 80, 0, 80)
	regIcon.Position = UDim2.new(0, 15, 0, 15)
	regIcon.BackgroundTransparency = 1
	regIcon.ZIndex = 6

	local MidCol = CreateGrimPanel(ColumnsWrapper)
	MidCol.Size = UDim2.new(0.31, 0, 0, 430)
	MidCol.LayoutOrder = 2

	local RadarContainer = Instance.new("Frame", MidCol)
	RadarContainer.Size = UDim2.new(0, 200, 0, 200)
	RadarContainer.Position = UDim2.new(0.5, 0, 0, 20)
	RadarContainer.AnchorPoint = Vector2.new(0.5, 0)
	RadarContainer.BackgroundTransparency = 1

	local StatsRect = CreateGrimPanel(MidCol)
	StatsRect.Size = UDim2.new(0.9, 0, 0, 0)
	StatsRect.Position = UDim2.new(0.5, 0, 0, 240)
	StatsRect.AnchorPoint = Vector2.new(0.5, 0)
	StatsRect.AutomaticSize = Enum.AutomaticSize.Y
	local srLayout = Instance.new("UIListLayout", StatsRect); srLayout.Padding = UDim.new(0, 6)
	local statPad = Instance.new("UIPadding", StatsRect); statPad.PaddingTop = UDim.new(0, 12); statPad.PaddingBottom = UDim.new(0, 12); statPad.PaddingLeft = UDim.new(0, 15)

	local function CreateInfoLabel(parent)
		local l = CreateSharpLabel(parent, "", UDim2.new(1, -15, 0, 24), Enum.Font.GothamBold, Color3.fromRGB(245, 245, 245), 14)
		l.TextXAlignment = Enum.TextXAlignment.Left; l.TextWrapped = true; return l
	end

	local titanLabel = CreateInfoLabel(StatsRect); titanLabel.RichText = true
	local clanLabel = CreateInfoLabel(StatsRect); clanLabel.RichText = true
	local regimentLabel = CreateInfoLabel(StatsRect); regimentLabel.RichText = true
	local wpnLabel = CreateInfoLabel(StatsRect); wpnLabel.RichText = true
	local accLabel = CreateInfoLabel(StatsRect); accLabel.RichText = true

	local ActionRow = Instance.new("Frame", MidCol)
	ActionRow.Size = UDim2.new(0.9, 0, 0, 40)
	ActionRow.Position = UDim2.new(0.5, 0, 1, -15)
	ActionRow.AnchorPoint = Vector2.new(0.5, 1)
	ActionRow.BackgroundTransparency = 1

	local toggleStatsBtn, _ = CreateSharpButton(ActionRow, "VIEW TITAN STATS", UDim2.new(1, 0, 1, 0), Enum.Font.GothamBlack, 14)

	local TabsWrapper = Instance.new("Frame", ColumnsWrapper)
	TabsWrapper.Size = UDim2.new(0.32, 0, 0, 430)
	TabsWrapper.BackgroundTransparency = 1
	TabsWrapper.LayoutOrder = 3
	local twLayout = Instance.new("UIListLayout", TabsWrapper); twLayout.SortOrder = Enum.SortOrder.LayoutOrder; twLayout.Padding = UDim.new(0, 10)
	twLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		TabsWrapper.Size = UDim2.new(TabsWrapper.Size.X.Scale, TabsWrapper.Size.X.Offset, 0, twLayout.AbsoluteContentSize.Y)
	end)

	local TopNav = CreateGrimPanel(TabsWrapper)
	TopNav.Size = UDim2.new(1, 0, 0, 45)
	TopNav.LayoutOrder = 1

	local NavScroll = Instance.new("ScrollingFrame", TopNav)
	NavScroll.Size = UDim2.new(1, 0, 1, 0)
	NavScroll.BackgroundTransparency = 1
	NavScroll.ScrollBarThickness = 0
	NavScroll.ScrollingDirection = Enum.ScrollingDirection.X

	local navLayout = Instance.new("UIListLayout", NavScroll)
	navLayout.FillDirection = Enum.FillDirection.Horizontal
	navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	navLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	navLayout.Padding = UDim.new(0, 8)
	navLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() NavScroll.CanvasSize = UDim2.new(0, navLayout.AbsoluteContentSize.X + 20, 0, 0) end)

	local ContentArea = Instance.new("Frame", TabsWrapper)
	ContentArea.Size = UDim2.new(1, 0, 0, 375)
	ContentArea.BackgroundTransparency = 1
	ContentArea.LayoutOrder = 2

	local SubTabs = {}; local SubBtns = {}
	local function CreateSubNavBtn(name, text)
		local btn, subStroke = CreateSharpButton(NavScroll, text, UDim2.new(0, 100, 0, 30), Enum.Font.GothamBold, 12)
		btn.TextColor3 = Color3.fromRGB(160, 160, 175); subStroke.Color = Color3.fromRGB(70, 70, 80)
		btn.MouseButton1Click:Connect(function()
			for k, v in pairs(SubBtns) do v.TextColor3 = Color3.fromRGB(160, 160, 175); v:FindFirstChild("UIStroke").Color = Color3.fromRGB(70, 70, 80) end
			btn.TextColor3 = Color3.fromRGB(245, 245, 245); subStroke.Color = Color3.fromRGB(225, 185, 60)
			for k, frame in pairs(SubTabs) do frame.Visible = (k == name) end
		end)
		SubBtns[name] = btn; return btn
	end

	CreateSubNavBtn("Inventory", "INVENTORY"); CreateSubNavBtn("Titles", "TITLES"); CreateSubNavBtn("Auras", "AURAS")
	SubBtns["Inventory"].TextColor3 = Color3.fromRGB(245, 245, 245); SubBtns["Inventory"]:FindFirstChild("UIStroke").Color = Color3.fromRGB(225, 185, 60)

	SubTabs["Inventory"] = CreateGrimPanel(ContentArea); SubTabs["Inventory"].Size = UDim2.new(1, 0, 1, 0); SubTabs["Inventory"].Visible = true
	local InvTitle = CreateSharpLabel(SubTabs["Inventory"], "INVENTORY (0/25)", UDim2.new(1, 0, 0, 30), Enum.Font.GothamBlack, Color3.fromRGB(225, 185, 60), 16)

	local FilterFrame = Instance.new("Frame", SubTabs["Inventory"])
	FilterFrame.Size = UDim2.new(1, -20, 0, 35)
	FilterFrame.Position = UDim2.new(0, 10, 0, 35)
	FilterFrame.BackgroundTransparency = 1
	local ffLayout = Instance.new("UIListLayout", FilterFrame); ffLayout.FillDirection = Enum.FillDirection.Horizontal; ffLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left; ffLayout.Padding = UDim.new(0, 10)

	local currentInvFilter = "Gear"; local FilterBtns = {}; local RefreshProfile 
	local function MakeFilterBtn(id, text)
		local btn, stroke = CreateSharpButton(FilterFrame, text, UDim2.new(0, 60, 1, 0), Enum.Font.GothamBlack, 11)
		btn.TextColor3 = Color3.fromRGB(160, 160, 175)
		btn.MouseButton1Click:Connect(function()
			currentInvFilter = id
			for k, v in pairs(FilterBtns) do v.TextColor3 = Color3.fromRGB(160, 160, 175); v:FindFirstChild("UIStroke").Color = Color3.fromRGB(70, 70, 80) end
			btn.TextColor3 = Color3.fromRGB(245, 245, 245); stroke.Color = Color3.fromRGB(225, 185, 60)
			if RefreshProfile then RefreshProfile() end
		end)
		FilterBtns[id] = btn; return btn
	end
	MakeFilterBtn("Gear", "GEAR"); MakeFilterBtn("Items", "POUCH")
	FilterBtns["Gear"].TextColor3 = Color3.fromRGB(245, 245, 245); FilterBtns["Gear"]:FindFirstChild("UIStroke").Color = Color3.fromRGB(225, 185, 60)

	local AutoSellBtn, asStroke = CreateSharpButton(FilterFrame, "AUTO-SELL", UDim2.new(0, 90, 1, 0), Enum.Font.GothamBlack, 11)
	AutoSellBtn.TextColor3 = UIHelpers.Colors.TextMuted

	local AutoSellMenu = Instance.new("Frame", SubTabs["Inventory"])
	AutoSellMenu.Size = UDim2.new(1, -20, 0, 180)
	AutoSellMenu.Position = UDim2.new(0, 10, 0, 75)
	AutoSellMenu.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	AutoSellMenu.Visible = false
	AutoSellMenu.ZIndex = 20
	Instance.new("UIStroke", AutoSellMenu).Color = UIHelpers.Colors.Gold

	local asTitle = UIHelpers.CreateLabel(AutoSellMenu, "AUTO-SELL SETTINGS", UDim2.new(1, 0, 0, 30), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 14)
	local asList = Instance.new("Frame", AutoSellMenu); asList.Size = UDim2.new(1, 0, 1, -40); asList.Position = UDim2.new(0, 0, 0, 35); asList.BackgroundTransparency = 1; local asLayout = Instance.new("UIListLayout", asList); asLayout.Padding = UDim.new(0, 6); asLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local function CreateASRow(rarityName, hexColor)
		local row = Instance.new("Frame", asList); row.Size = UDim2.new(0.9, 0, 0, 30); row.BackgroundTransparency = 1
		local lbl = UIHelpers.CreateLabel(row, rarityName:upper(), UDim2.new(0.6, 0, 1, 0), Enum.Font.GothamBold, Color3.fromHex(hexColor:gsub("#","")), 14); lbl.TextXAlignment = Enum.TextXAlignment.Left
		local tBtn, tStrk = CreateSharpButton(row, "OFF", UDim2.new(0.35, 0, 1, 0), Enum.Font.GothamBlack, 12); tBtn.Position = UDim2.new(1, 0, 0, 0); tBtn.AnchorPoint = Vector2.new(1, 0)
		local function updateBtn()
			if player:GetAttribute("AutoSell_" .. rarityName) then tBtn.Text = "ON"; tBtn.TextColor3 = Color3.fromRGB(100, 255, 100); tStrk.Color = Color3.fromRGB(100, 255, 100)
			else tBtn.Text = "OFF"; tBtn.TextColor3 = UIHelpers.Colors.TextMuted; tStrk.Color = Color3.fromRGB(70, 70, 80) end
		end
		updateBtn()
		tBtn.MouseButton1Click:Connect(function() Network:WaitForChild("AutoSell"):FireServer(rarityName) end)
		player.AttributeChanged:Connect(function(attr) if attr == "AutoSell_" .. rarityName then updateBtn() end end)
	end
	CreateASRow("Common", RarityColors["Common"]); CreateASRow("Uncommon", RarityColors["Uncommon"]); CreateASRow("Rare", RarityColors["Rare"]); CreateASRow("Epic", RarityColors["Epic"])
	AutoSellBtn.MouseButton1Click:Connect(function() AutoSellMenu.Visible = not AutoSellMenu.Visible end)

	local InvGrid = Instance.new("ScrollingFrame", SubTabs["Inventory"])
	InvGrid.Size = UDim2.new(1, -10, 1, -85)
	InvGrid.Position = UDim2.new(0, 5, 0, 80)
	InvGrid.BackgroundTransparency = 1
	InvGrid.BorderSizePixel = 0
	InvGrid.ScrollBarThickness = 6
	local gl = Instance.new("UIGridLayout", InvGrid)
	gl.CellSize = UDim2.new(0, 85, 0, 85)
	gl.CellPadding = UDim2.new(0, 12, 0, 15)
	gl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() InvGrid.CanvasSize = UDim2.new(0, 0, 0, gl.AbsoluteContentSize.Y + 20) end)

	SubTabs["Titles"] = Instance.new("ScrollingFrame", ContentArea); SubTabs["Titles"].Size = UDim2.new(1, 0, 1, 0); SubTabs["Titles"].BackgroundTransparency = 1; SubTabs["Titles"].Visible = false; SubTabs["Titles"].ScrollBarThickness = 6; SubTabs["Titles"].BorderSizePixel = 0
	local tLayout = Instance.new("UIListLayout", SubTabs["Titles"]); tLayout.Padding = UDim.new(0, 10); tLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; local tPad = Instance.new("UIPadding", SubTabs["Titles"]); tPad.PaddingTop = UDim.new(0, 10); tPad.PaddingBottom = UDim.new(0, 20)

	SubTabs["Auras"] = Instance.new("ScrollingFrame", ContentArea); SubTabs["Auras"].Size = UDim2.new(1, 0, 1, 0); SubTabs["Auras"].BackgroundTransparency = 1; SubTabs["Auras"].Visible = false; SubTabs["Auras"].ScrollBarThickness = 6; SubTabs["Auras"].BorderSizePixel = 0
	local aLayout = Instance.new("UIListLayout", SubTabs["Auras"]); aLayout.Padding = UDim.new(0, 10); aLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; local aPad = Instance.new("UIPadding", SubTabs["Auras"]); aPad.PaddingTop = UDim.new(0, 10); aPad.PaddingBottom = UDim.new(0, 20)

	local function BuildCosmeticList(tab, typeKey, dataPool)
		local sorted = {}; for key, data in pairs(dataPool or {}) do table.insert(sorted, {Key = key, Data = data}) end
		table.sort(sorted, function(a, b) return a.Data.Order < b.Data.Order end)

		for _, item in ipairs(sorted) do
			local card = CreateGrimPanel(tab); card.Size = UDim2.new(0.95, 0, 0, 85); card.LayoutOrder = item.Data.Order
			local cColor = Color3.fromRGB(255,255,255)
			if typeKey == "Title" then cColor = Color3.fromHex((item.Data.Color or "#FFFFFF"):gsub("#", "")) else cColor = Color3.fromHex((item.Data.Color1 or "#FFFFFF"):gsub("#", "")) end

			local title = CreateSharpLabel(card, item.Data.Name, UDim2.new(1, -100, 0, 30), Enum.Font.GothamBlack, cColor, 16); title.Position = UDim2.new(0, 15, 0, 5); title.TextXAlignment = Enum.TextXAlignment.Left
			local desc = CreateSharpLabel(card, item.Data.Desc, UDim2.new(1, -100, 0, 40), Enum.Font.GothamMedium, Color3.fromRGB(160, 160, 175), 12); desc.Position = UDim2.new(0, 15, 0, 35); desc.TextWrapped = true; desc.TextXAlignment = Enum.TextXAlignment.Left; desc.TextYAlignment = Enum.TextYAlignment.Top
			local btn, btnStroke = CreateSharpButton(card, "", UDim2.new(0, 80, 0, 40), Enum.Font.GothamBlack, 12); btn.Position = UDim2.new(1, -15, 0.5, 0); btn.AnchorPoint = Vector2.new(1, 0.5)

			local function UpdateState()
				local isUnlocked = false
				if type(CosmeticData.CheckUnlock) == "function" then isUnlocked = CosmeticData.CheckUnlock(player, item.Data.ReqType, item.Data.ReqValue) end
				local isEquipped = (player:GetAttribute("Equipped" .. typeKey) or (typeKey == "Title" and "Cadet" or "None")) == item.Key

				if isEquipped then btn.Text = "EQUIPPED"; btn.TextColor3 = Color3.fromRGB(225, 185, 60); btnStroke.Color = Color3.fromRGB(225, 185, 60)
				elseif isUnlocked then btn.Text = "EQUIP"; btn.TextColor3 = Color3.fromRGB(245, 245, 245); btnStroke.Color = Color3.fromRGB(70, 70, 80)
				else btn.Text = "LOCKED"; btn.TextColor3 = Color3.fromRGB(70, 70, 80); btnStroke.Color = Color3.fromRGB(70, 70, 80) end
			end
			table.insert(CosmeticUIUpdaters, UpdateState)
			btn.MouseButton1Click:Connect(function() 
				if type(CosmeticData.CheckUnlock) ~= "function" or CosmeticData.CheckUnlock(player, item.Data.ReqType, item.Data.ReqValue) then 
					Network:WaitForChild("EquipCosmetic"):FireServer(typeKey, item.Key) 
				end 
			end)
			UpdateState()
		end
	end

	BuildCosmeticList(SubTabs["Titles"], "Title", CosmeticData.Titles)
	tLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() SubTabs["Titles"].CanvasSize = UDim2.new(0, 0, 0, tLayout.AbsoluteContentSize.Y + 30) end)
	BuildCosmeticList(SubTabs["Auras"], "Aura", CosmeticData.Auras)
	aLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() SubTabs["Auras"].CanvasSize = UDim2.new(0, 0, 0, aLayout.AbsoluteContentSize.Y + 30) end)

	local isShowingTitanStats = false
	local function RenderRadarChart()
		if not RadarContainer or RadarContainer.Parent == nil then return end
		local w = RadarContainer.AbsoluteSize.X; local h = RadarContainer.AbsoluteSize.Y
		if w == 0 then return end 
		for _, child in ipairs(RadarContainer:GetChildren()) do if not child:IsA("UIAspectRatioConstraint") then child:Destroy() end end
		local ls = player:FindFirstChild("leaderstats"); local p = ls and ls:FindFirstChild("Prestige")
		local maxVal = 100
		if type(GameData) == "table" and type(GameData.GetStatCap) == "function" then maxVal = GameData.GetStatCap(p and p.Value or 0) else maxVal = 100 + ((p and p.Value or 0) * 10) end

		local stats = isShowingTitanStats and { {Name = "POW", Val = player:GetAttribute("Titan_Power_Val") or 1}, {Name = "SPD", Val = player:GetAttribute("Titan_Speed_Val") or 1}, {Name = "HRD", Val = player:GetAttribute("Titan_Hardening_Val") or 1}, {Name = "END", Val = player:GetAttribute("Titan_Endurance_Val") or 1}, {Name = "STM", Val = player:GetAttribute("Titan_Precision_Val") or 1}, {Name = "POT", Val = player:GetAttribute("Titan_Potential_Val") or 1} } or { {Name = "HP", Val = player:GetAttribute("Health") or 1}, {Name = "STR", Val = player:GetAttribute("Defense") or 1}, {Name = "DEF", Val = player:GetAttribute("Defense") or 1}, {Name = "SPD", Val = player:GetAttribute("Speed") or 1}, {Name = "GAS", Val = player:GetAttribute("Gas") or 1}, {Name = "RES", Val = player:GetAttribute("Resolve") or 1} }

		local angles = {-90, -30, 30, 90, 150, 210}; local centerX, centerY = w/2, h/2; local maxRadius = math.min(w, h) * 0.35
		for ring = 1, 3 do local r = maxRadius * (ring / 3) for i = 1, 6 do local nextI = i % 6 + 1; DrawLineScale(RadarContainer, centerX + r*math.cos(math.rad(angles[i])), centerY + r*math.sin(math.rad(angles[i])), centerX + r*math.cos(math.rad(angles[nextI])), centerY + r*math.sin(math.rad(angles[nextI])), Color3.fromRGB(60, 60, 70), 1, 1) end end
		for i = 1, 6 do 
			local rad = math.rad(angles[i]); local px = centerX + maxRadius * math.cos(rad); local py = centerY + maxRadius * math.sin(rad)
			DrawLineScale(RadarContainer, centerX, centerY, px, py, Color3.fromRGB(60, 60, 70), 1, 1)
			local lbl = CreateSharpLabel(RadarContainer, stats[i].Name .. "\n" .. stats[i].Val, UDim2.new(0, 30, 0, 15), Enum.Font.GothamBold, Color3.fromRGB(160, 160, 175), 10)
			lbl.Position = UDim2.new(0, centerX + (maxRadius + 20) * math.cos(rad), 0, centerY + (maxRadius + 20) * math.sin(rad)); lbl.AnchorPoint = Vector2.new(0.5, 0.5)
		end
		local statColor = isShowingTitanStats and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(100, 255, 100)
		local pts = {}
		for i = 1, 6 do local r1 = maxRadius * math.clamp(stats[i].Val / maxVal, 0.05, 1); table.insert(pts, Vector2.new(centerX + r1 * math.cos(math.rad(angles[i])), centerY + r1 * math.sin(math.rad(angles[i])))) end
		for i = 1, 6 do local nextI = i % 6 + 1; DrawLineScale(RadarContainer, pts[i].X, pts[i].Y, pts[nextI].X, pts[nextI].Y, statColor, 2, 5); DrawUITriangle(RadarContainer, Vector2.new(centerX, centerY), pts[i], pts[nextI], statColor, 0.5, 3) end
	end
	RadarContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(RenderRadarChart)
	toggleStatsBtn.MouseButton1Click:Connect(function() isShowingTitanStats = not isShowingTitanStats; toggleStatsBtn.Text = isShowingTitanStats and "VIEW HUMAN STATS" or "VIEW TITAN STATS"; RenderRadarChart() end)

	RefreshProfile = function()
		local tName = player:GetAttribute("Titan") or "None"; local cName = player:GetAttribute("Clan") or "None"; local regName = player:GetAttribute("Regiment") or "Cadet Corps"
		local hasRegData, regDataModule = pcall(function() return require(game.ReplicatedStorage:WaitForChild("RegimentData")) end)
		if hasRegData and regDataModule and regDataModule.Regiments[regName] then regIcon.Image = regDataModule.Regiments[regName].Icon else regIcon.Image = "" end

		if cName == "Ackerman" or string.find(cName, "Ackerman") then titanLabel.Text = "Titan: <font color='#FF5555'>(Titan Disabled)</font>" else titanLabel.Text = "Titan: <font color='#FF5555'>" .. tName .. "</font>" end
		clanLabel.Text = "Clan: <font color='#55FF55'>" .. cName .. "</font>"
		regimentLabel.Text = "Regiment: <font color='"..(REG_COLORS[regName] or TEXT_COLORS.DefaultGreen).."'>" .. regName .. "</font>"

		local wpnName = player:GetAttribute("EquippedWeapon") or "None"; local accName = player:GetAttribute("EquippedAccessory") or "None"
		local wpnRarity = "Common"; local accRarity = "Common"
		if type(ItemData) == "table" and ItemData.Equipment then
			wpnRarity = (wpnName ~= "None" and ItemData.Equipment[wpnName]) and ItemData.Equipment[wpnName].Rarity or "Common"
			accRarity = (accName ~= "None" and ItemData.Equipment[accName]) and ItemData.Equipment[accName].Rarity or "Common"
		end
		wpnLabel.Text = "Weapon: <font color='"..(RarityColors[wpnRarity] or "#FFFFFF").."'>" .. wpnName .. "</font>"
		accLabel.Text = "Accessory: <font color='"..(RarityColors[accRarity] or "#FFFFFF").."'>" .. accName .. "</font>"

		RenderRadarChart()

		local pTitle = player:GetAttribute("EquippedTitle") or "Cadet"; local pAura = player:GetAttribute("EquippedAura") or "None"
		local resolvedTitleData = nil
		if type(CosmeticData) == "table" and CosmeticData.Titles then
			resolvedTitleData = CosmeticData.Titles[pTitle]
			if not resolvedTitleData then for k, v in pairs(CosmeticData.Titles) do if v.Name == pTitle then resolvedTitleData = v break end end end
		end
		if resolvedTitleData then AvatarTitle.Text = string.upper(resolvedTitleData.Name); AvatarTitle.TextColor3 = Color3.fromHex((resolvedTitleData.Color or "#FFFFFF"):gsub("#", "")) end

		local resolvedAuraData = nil
		if type(CosmeticData) == "table" and CosmeticData.Auras then
			resolvedAuraData = CosmeticData.Auras[pAura]
			if not resolvedAuraData then for k, v in pairs(CosmeticData.Auras) do if v.Name == pAura then resolvedAuraData = v break end end end
		end
		if UIAuraManager and type(UIAuraManager.ApplyAura) == "function" and resolvedAuraData then UIAuraManager.ApplyAura(AvatarAuraGlow, resolvedAuraData, AvatarBox) end

		for _, child in ipairs(InvGrid:GetChildren()) do if child.Name == "ItemCard" then child:Destroy() end end

		local inventoryItems = {}; local currentSlotsUsed = 0

		if type(ItemData) == "table" then
			if type(ItemData.Equipment) == "table" then
				for iName, iData in pairs(ItemData.Equipment) do 
					local safeNameBase = iName:gsub("[^%w]", "")
					local count = tonumber(player:GetAttribute(safeNameBase .. "Count")) or tonumber(player:GetAttribute(iName)) or 0
					if count > 0 then 
						currentSlotsUsed += 1 
						if currentInvFilter == "Gear" then table.insert(inventoryItems, {Name = iName, Data = iData, Count = count}) end
					end
				end
			end
			if type(ItemData.Consumables) == "table" then
				for iName, iData in pairs(ItemData.Consumables) do 
					local safeNameBase = iName:gsub("[^%w]", "")
					local count = tonumber(player:GetAttribute(safeNameBase .. "Count")) or tonumber(player:GetAttribute(iName)) or 0
					if count > 0 then 
						if currentInvFilter == "Items" then table.insert(inventoryItems, {Name = iName, Data = iData, Count = count}) end
					end
				end
			end
		end

		table.sort(inventoryItems, function(a, b) local rA = RarityOrder[a.Data.Rarity or "Common"] or 7; local rB = RarityOrder[b.Data.Rarity or "Common"] or 7; if rA == rB then return a.Name < b.Name else return rA < rB end end)

		local layoutOrderCounter = 1
		for _, item in ipairs(inventoryItems) do
			local card = CreateGrimPanel(InvGrid); card.Name = "ItemCard"; card.LayoutOrder = layoutOrderCounter; layoutOrderCounter += 1

			local rarityKey = item.Data.Rarity or "Common"
			local safeNameBase = item.Name:gsub("[^%w]", "")

			if player:GetAttribute(safeNameBase .. "_Awakened") then rarityKey = "Transcendent" end
			local rarityRGB = Color3.fromHex((RarityColors[rarityKey] or "#FFFFFF"):gsub("#", ""))
			local isLocked = player:GetAttribute(safeNameBase .. "_Locked")

			card:FindFirstChild("UIStroke").Color = isLocked and UIHelpers.Colors.Gold or rarityRGB

			local bgGlow = Instance.new("Frame", card); bgGlow.Size = UDim2.new(1, 0, 0.5, 0); bgGlow.Position = UDim2.new(0, 0, 0.5, 0); bgGlow.BackgroundColor3 = rarityRGB; bgGlow.BackgroundTransparency = 0.92; bgGlow.BorderSizePixel = 0; bgGlow.ZIndex = 1
			local countBadge = Instance.new("Frame", card); countBadge.Size = UDim2.new(0, 24, 0, 16); countBadge.AnchorPoint = Vector2.new(1, 0); countBadge.Position = UDim2.new(1, -6, 0, 6); countBadge.BackgroundColor3 = Color3.fromRGB(18, 18, 22); countBadge.BorderSizePixel = 1; countBadge.BorderColor3 = rarityRGB; countBadge.ZIndex = 3
			local countTag = CreateSharpLabel(countBadge, "x" .. item.Count, UDim2.new(1, 0, 1, 0), Enum.Font.GothamBlack, Color3.fromRGB(245, 245, 245), 11); countTag.ZIndex = 4

			if isLocked then
				local lockIcon = UIHelpers.CreateLabel(card, "🔒", UDim2.new(0, 15, 0, 15), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 14)
				lockIcon.Position = UDim2.new(0, 5, 0, 5); lockIcon.ZIndex = 4
			end

			local nameLbl = CreateSharpLabel(card, item.Name, UDim2.new(0.88, 0, 0.5, 0), Enum.Font.GothamBold, Color3.fromRGB(245, 245, 245), 12); nameLbl.Position = UDim2.new(0.5, 0, 0.5, 2); nameLbl.AnchorPoint = Vector2.new(0.5, 0.5); nameLbl.TextScaled = true; nameLbl.TextWrapped = true; nameLbl.ZIndex = 3
			local tCon2 = Instance.new("UITextSizeConstraint", nameLbl); tCon2.MaxTextSize = 11; tCon2.MinTextSize = 8
			local rarityTag = CreateSharpLabel(card, string.sub(rarityKey, 1, 1), UDim2.new(0, 16, 0, 16), Enum.Font.GothamBlack, rarityRGB, 12); rarityTag.Position = UDim2.new(0, 6, 1, -22); rarityTag.TextTransparency = 0.3; rarityTag.ZIndex = 3
			local btnCover = Instance.new("TextButton", card); btnCover.Size = UDim2.new(1,0,1,0); btnCover.BackgroundTransparency = 1; btnCover.Text = ""; btnCover.ZIndex = 5

			-- [[ FIX: Dynamic Tooltip Data string parsing added ]]
			local tTipStr = "<font color='" .. (RarityColors[rarityKey] or "#FFFFFF") .. "'>[" .. rarityKey .. "]</font> <b>" .. item.Name .. "</b>"

			if item.Data.Desc then
				tTipStr = tTipStr .. "\n<font color='#AAAAAA'>" .. item.Data.Desc .. "</font>"
			end

			if item.Data.Bonus then
				tTipStr = tTipStr .. "\n\n<font color='#55FF55'><b>[ Stat Bonuses ]</b></font>"
				for stat, val in pairs(item.Data.Bonus) do
					local prefix = val >= 0 and "+" or ""
					tTipStr = tTipStr .. "\n<font color='#FFFFFF'>" .. prefix .. val .. " " .. stat .. "</font>"
				end
			end

			if item.Data.Style then
				tTipStr = tTipStr .. "\n\n<font color='#FFD700'><b>[ Requires: " .. item.Data.Style .. " ]</b></font>"
			end

			btnCover.MouseEnter:Connect(function() if TooltipManager and type(TooltipManager.Show) == "function" then TooltipManager.Show(tTipStr) end end)
			btnCover.MouseLeave:Connect(function() if TooltipManager and type(TooltipManager.Hide) == "function" then TooltipManager.Hide() end end)

			local ActionsOverlay = Instance.new("Frame", card); ActionsOverlay.Name = "ActionsOverlay"; ActionsOverlay.Size = UDim2.new(1, 0, 1, 0); ActionsOverlay.BackgroundColor3 = Color3.fromRGB(18, 18, 22); ActionsOverlay.BackgroundTransparency = 0.05; ActionsOverlay.Visible = false; ActionsOverlay.ZIndex = 10; ActionsOverlay.Active = true; ActionsOverlay.BorderSizePixel = 0
			local actLayout = Instance.new("UIListLayout", ActionsOverlay); actLayout.Padding = UDim.new(0, 4); actLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; actLayout.VerticalAlignment = Enum.VerticalAlignment.Center

			local buttonConsumed = false
			local function MakeOverlayBtn(text)
				local obtn, _ = CreateSharpButton(ActionsOverlay, text, UDim2.new(0.9, 0, 0, 16), Enum.Font.GothamBlack, 9); obtn.ZIndex = 11; return obtn
			end

			local equipBtn = MakeOverlayBtn("EQUIP")
			local sellBtn = MakeOverlayBtn("SELL 1x")
			local sellAllBtn = MakeOverlayBtn("SELL ALL")
			local lockBtn = MakeOverlayBtn(isLocked and "UNLOCK" or "LOCK")

			if isLocked then 
				lockBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
				sellBtn.Visible = false 
				sellAllBtn.Visible = false
			else 
				lockBtn.TextColor3 = Color3.fromRGB(100, 255, 100) 
				if item.Count <= 1 then
					sellAllBtn.Visible = false
				end
			end

			if item.Data.IsGift then
				sellBtn.Visible = false
				sellAllBtn.Visible = false
			end

			if item.Data.Type ~= nil then 
				local isEq = (player:GetAttribute("EquippedWeapon") == item.Name) or (player:GetAttribute("EquippedAccessory") == item.Name)
				if isEq then equipBtn.Text = "UNEQUIP"; equipBtn.TextColor3 = Color3.fromRGB(255, 100, 100) else equipBtn.Text = "EQUIP"; equipBtn.TextColor3 = Color3.fromRGB(245, 245, 245) end
				equipBtn.MouseButton1Click:Connect(function() buttonConsumed = true; if isEq then Network:WaitForChild("EquipItem"):FireServer("Unequip_" .. item.Data.Type) else Network:WaitForChild("EquipItem"):FireServer(item.Name) end; ActionsOverlay.Visible = false end)
			elseif item.Data.Action ~= nil then 
				equipBtn.Text = "USE"; equipBtn.TextColor3 = Color3.fromRGB(200, 150, 255)
				equipBtn.MouseButton1Click:Connect(function() buttonConsumed = true; Network:WaitForChild("ConsumeItem"):FireServer(item.Name); ActionsOverlay.Visible = false end)
			else 
				equipBtn.Visible = false 
			end

			sellBtn.MouseButton1Click:Connect(function() buttonConsumed = true; Network:WaitForChild("SellItem"):FireServer(item.Name, false); ActionsOverlay.Visible = false end)
			sellAllBtn.MouseButton1Click:Connect(function() buttonConsumed = true; Network:WaitForChild("SellItem"):FireServer(item.Name, true); ActionsOverlay.Visible = false end)
			lockBtn.MouseButton1Click:Connect(function() buttonConsumed = true; Network:WaitForChild("ToggleLock"):FireServer(item.Name); ActionsOverlay.Visible = false end)

			local function CloseAllOverlays() for _, c in ipairs(InvGrid:GetChildren()) do if c.Name == "ItemCard" then local ov = c:FindFirstChild("ActionsOverlay"); if ov then ov.Visible = false end end end end

			btnCover.MouseButton1Click:Connect(function()
				if buttonConsumed then buttonConsumed = false; return end
				if ActionsOverlay.Visible then ActionsOverlay.Visible = false else CloseAllOverlays(); ActionsOverlay.Visible = true end
			end)
		end

		local MAX_INVENTORY_CAPACITY = player:GetAttribute("HasBackpackExpansion") and 75 or 25
		if currentInvFilter == "Items" then
			InvTitle.Text = "SCOUT'S POUCH (∞)"
			InvTitle.TextColor3 = Color3.fromRGB(150, 255, 150)
		else
			InvTitle.Text = "INVENTORY (" .. currentSlotsUsed .. "/" .. MAX_INVENTORY_CAPACITY .. ")"
			if currentSlotsUsed >= MAX_INVENTORY_CAPACITY then InvTitle.TextColor3 = Color3.fromRGB(255, 100, 100) else InvTitle.TextColor3 = Color3.fromRGB(225, 185, 60) end
		end
	end

	player.AttributeChanged:Connect(function(attr)
		if string.match(attr, "Count$") or string.match(attr, "^Equipped") or attr == "Clan" or attr == "Titan" or attr == "Regiment" or string.match(attr, "_Awakened$") or string.match(attr, "_Locked$") then
			EvaluateCosmetics()
			RefreshProfile()
		end
	end)

	LayoutRefs.Identity = { 
		cwLayout = cwLayout, 
		ShowcaseCard = ShowcaseCard, 
		MidCol = MidCol, 
		TabsWrapper = TabsWrapper,
		RegIcon = regIcon,
		PlayerNameLbl = PlayerNameLbl
	}
	RefreshProfile()
end

-- ==========================================
-- ATTRIBUTES TAB
-- ==========================================
local function BuildAttributesTab(parentFrame)
	local MainScroll = Instance.new("ScrollingFrame", parentFrame)
	MainScroll.Size = UDim2.new(1, 0, 1, 0)
	MainScroll.BackgroundTransparency = 1
	MainScroll.ScrollBarThickness = 6
	MainScroll.BorderSizePixel = 0

	local mainLayout = Instance.new("UIListLayout", MainScroll)
	mainLayout.Padding = UDim.new(0, 15)
	mainLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	mainLayout.SortOrder = Enum.SortOrder.LayoutOrder
	mainLayout.FillDirection = Enum.FillDirection.Vertical 

	mainLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() 
		MainScroll.CanvasSize = UDim2.new(0, 0, 0, mainLayout.AbsoluteContentSize.Y + 40) 
	end)

	local padding = Instance.new("UIPadding", MainScroll)
	padding.PaddingTop = UDim.new(0, 10); padding.PaddingBottom = UDim.new(0, 20)

	local ColumnsContainer = Instance.new("Frame", MainScroll)
	ColumnsContainer.Size = UDim2.new(0.95, 0, 0, 0)
	ColumnsContainer.BackgroundTransparency = 1
	ColumnsContainer.LayoutOrder = 1
	local ccLayout = Instance.new("UIListLayout", ColumnsContainer)
	ccLayout.FillDirection = Enum.FillDirection.Horizontal
	ccLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	ccLayout.Padding = UDim.new(0.04, 0)

	ccLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() 
		ColumnsContainer.Size = UDim2.new(0.95, 0, 0, ccLayout.AbsoluteContentSize.Y)
	end)

	local statRowRefs = {}
	local humanCombo = 0
	local titanCombo = 0

	local function SafeGetStatCap(prestige) if type(GameData) == "table" and type(GameData.GetStatCap) == "function" then return GameData.GetStatCap(prestige) end; return 100 + ((prestige or 0) * 10) end
	local function SafeCalculateStatCost(currentStat, baseStat, prestige) if type(GameData) == "table" and type(GameData.CalculateStatCost) == "function" then return GameData.CalculateStatCost(currentStat, baseStat, prestige) end; local baseCost = 10; local growthFactor = 1.05; local prestigeMultiplier = math.max(0.1, 1 - ((prestige or 0) * 0.03)); local statDifference = math.max(0, (currentStat or 10) - (baseStat or 10)); return math.floor(baseCost * (growthFactor ^ statDifference) * prestigeMultiplier) end
	local function ParseStat(rawStat) local val = tonumber(rawStat); if val then return val end; if type(rawStat) == "string" and type(GameData) == "table" and GameData.TitanRanks and GameData.TitanRanks[rawStat] then return GameData.TitanRanks[rawStat] end; return 10 end
	local function GetCombinedBonus(statName)
		local wpn = player:GetAttribute("EquippedWeapon") or "None"; local acc = player:GetAttribute("EquippedAccessory") or "None"; local style = player:GetAttribute("FightingStyle") or "None"; local bonus = 0
		if type(ItemData) == "table" and ItemData.Equipment then
			if ItemData.Equipment[wpn] and ItemData.Equipment[wpn].Bonus and ItemData.Equipment[wpn].Bonus[statName] then bonus += ItemData.Equipment[wpn].Bonus[statName] end
			if ItemData.Equipment[acc] and ItemData.Equipment[acc].Bonus and ItemData.Equipment[acc].Bonus[statName] then bonus += ItemData.Equipment[acc].Bonus[statName] end
		end
		if type(GameData) == "table" and GameData.WeaponBonuses and GameData.WeaponBonuses[style] and GameData.WeaponBonuses[style][statName] then bonus += GameData.WeaponBonuses[style][statName] end
		return bonus
	end
	local function GetUpgradeCosts(currentStat, cleanName, prestige)
		local base = 10; if prestige == 0 then if type(GameData) == "table" and type(GameData.BaseStats) == "table" and GameData.BaseStats[cleanName] then base = GameData.BaseStats[cleanName] end else base = prestige * 5 end
		return SafeCalculateStatCost(currentStat, base, prestige)
	end

	local function CreateStatRow(statName, parent, isTitan, layoutOrder, amtInput)
		local row = Instance.new("Frame", parent); row.Size = UDim2.new(1, 0, 0, 35); row.BackgroundTransparency = 1; row.LayoutOrder = layoutOrder
		local statLabel = UIHelpers.CreateLabel(row, "", UDim2.new(0.38, 0, 1, 0), Enum.Font.GothamBold, isTitan and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(220, 220, 220), 13); statLabel.TextXAlignment = Enum.TextXAlignment.Left; statLabel.RichText = true; statLabel.TextScaled = true; Instance.new("UITextSizeConstraint", statLabel).MaxTextSize = 13

		local btnContainer = Instance.new("Frame", row); btnContainer.Size = UDim2.new(0.62, 0, 1, 0); btnContainer.Position = UDim2.new(1, 0, 0, 0); btnContainer.AnchorPoint = Vector2.new(1, 0); btnContainer.BackgroundTransparency = 1; local blL = Instance.new("UIListLayout", btnContainer); blL.FillDirection = Enum.FillDirection.Horizontal; blL.HorizontalAlignment = Enum.HorizontalAlignment.Right; blL.VerticalAlignment = Enum.VerticalAlignment.Center; blL.Padding = UDim.new(0.04, 0)
		local bAdd, addStroke = CreateSharpButton(btnContainer, "+", UDim2.new(0.35, 0, 0.85, 0), Enum.Font.GothamBlack, 12)
		local bMax, maxStroke = CreateSharpButton(btnContainer, "MAX", UDim2.new(0.55, 0, 0.85, 0), Enum.Font.GothamBlack, 12)

		local isUpgrading = false
		local function TryUpgrade(amt)
			if isUpgrading then return end; isUpgrading = true
			local prestige = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Prestige") and player.leaderstats.Prestige.Value or 0
			local statCap = SafeGetStatCap(prestige)
			local currentStat = ParseStat(player:GetAttribute(statName))
			local currentXP = isTitan and (tonumber(player:GetAttribute("TitanXP")) or 0) or (tonumber(player:GetAttribute("XP")) or 0)
			local cleanName = statName:gsub("_Val", ""):gsub("Titan_", "")
			local base = 10; if prestige == 0 then if type(GameData) == "table" and type(GameData.BaseStats) == "table" and GameData.BaseStats[cleanName] then base = GameData.BaseStats[cleanName] end else base = prestige * 5 end
			if currentStat >= statCap then isUpgrading = false; return end
			local cost, added, simulatedXP = 0, 0, currentXP
			local target = (amt == "MAX") and 9999 or tonumber(amt) or 1
			for i = 0, target - 1 do
				if currentStat + added >= statCap then break end
				local stepCost = SafeCalculateStatCost(currentStat + added, base, prestige)
				if simulatedXP >= stepCost then simulatedXP -= stepCost; cost += stepCost; added += 1 else break end
			end
			if added > 0 then
				task.spawn(function()
					local remaining = added
					while remaining > 0 do
						local chunk = math.min(remaining, 50); Network:WaitForChild("UpgradeStat"):FireServer(statName, chunk); remaining -= chunk; if remaining > 0 then task.wait(0.05) end
					end
					if NotificationManager and type(NotificationManager.Show) == "function" then NotificationManager.Show(cleanName:upper() .. " upgraded by +" .. added .. "!", "Success") end
					task.wait(0.15); isUpgrading = false
				end)
			else if NotificationManager and type(NotificationManager.Show) == "function" then NotificationManager.Show("Not enough XP!", "Error") end; isUpgrading = false end
		end
		bAdd.MouseButton1Click:Connect(function() local customAmt = tonumber(amtInput.Text) or 1; if customAmt < 1 then customAmt = 1 end; TryUpgrade(math.floor(customAmt)) end)
		bMax.MouseButton1Click:Connect(function() TryUpgrade("MAX") end)
		statRowRefs[statName] = { Label = statLabel, BtnContainer = btnContainer, BtnAdd = bAdd, AddStroke = addStroke, BtnMax = bMax, MaxStroke = maxStroke }
	end

	local function SetupPanel(titleTxt, statList, isTitan, parent)
		local panel, _ = CreateGrimPanel(parent); panel.Size = UDim2.new(0.48, 0, 0, 0); panel.AutomaticSize = Enum.AutomaticSize.Y
		local pLayout = Instance.new("UIListLayout", panel); pLayout.SortOrder = Enum.SortOrder.LayoutOrder; pLayout.Padding = UDim.new(0, 5); pLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		local pPad = Instance.new("UIPadding", panel); pPad.PaddingTop = UDim.new(0, 10); pPad.PaddingBottom = UDim.new(0, 15)

		local header = Instance.new("Frame", panel); header.Size = UDim2.new(1, -10, 0, 30); header.BackgroundTransparency = 1; header.LayoutOrder = 1
		local title = UIHelpers.CreateLabel(header, titleTxt, UDim2.new(0.5, 0, 1, 0), Enum.Font.GothamBlack, isTitan and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(200, 200, 220), 16); title.TextXAlignment = Enum.TextXAlignment.Left
		local controls = Instance.new("Frame", header); controls.Size = UDim2.new(0.5, 0, 1, 0); controls.Position = UDim2.new(0.5, 0, 0, 0); controls.BackgroundTransparency = 1; local cLayout = Instance.new("UIListLayout", controls); cLayout.FillDirection = Enum.FillDirection.Horizontal; cLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right; cLayout.VerticalAlignment = Enum.VerticalAlignment.Center; cLayout.Padding = UDim.new(0, 5)

		local allBtn, _ = CreateSharpButton(controls, "ALL", UDim2.new(0.4, 0, 0.8, 0), Enum.Font.GothamBold, 11)
		local amtInput = Instance.new("TextBox", controls); amtInput.Size = UDim2.new(0.3, 0, 0.8, 0); amtInput.Text = "1"; amtInput.Font = Enum.Font.GothamBold; amtInput.TextColor3 = Color3.new(1,1,1); amtInput.TextSize = 11; CreateGrimPanel(amtInput)
		local ptsLbl = UIHelpers.CreateLabel(controls, "0 XP", UDim2.new(0.4, 0, 0.8, 0), Enum.Font.GothamMedium, isTitan and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(100, 255, 100), 11); ptsLbl.TextXAlignment = Enum.TextXAlignment.Right

		local list = Instance.new("Frame", panel); list.Size = UDim2.new(1, -20, 0, 0); list.AutomaticSize = Enum.AutomaticSize.Y; list.BackgroundTransparency = 1; list.LayoutOrder = 2
		local lLayout = Instance.new("UIListLayout", list); lLayout.SortOrder = Enum.SortOrder.LayoutOrder; lLayout.Padding = UDim.new(0, 8)

		for i, s in ipairs(statList) do CreateStatRow(s, list, isTitan, i, amtInput) end

		local isSpammingAll = false
		allBtn.MouseButton1Click:Connect(function()
			if isSpammingAll then return end; isSpammingAll = true
			local prestige = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Prestige") and player.leaderstats.Prestige.Value or 0
			local statCap = SafeGetStatCap(prestige); local currentXP = isTitan and (tonumber(player:GetAttribute("TitanXP")) or 0) or (tonumber(player:GetAttribute("XP")) or 0); local simXP = currentXP
			local tallies = {}; local simStats = {}; for _, s in ipairs(statList) do tallies[s] = 0; simStats[s] = ParseStat(player:GetAttribute(s)) end
			local totalUpgrades = 0
			while true do
				local upgradedAny = false
				for _, s in ipairs(statList) do
					local cleanName = s:gsub("_Val", ""):gsub("Titan_", ""); local base = 10
					if prestige == 0 then if type(GameData) == "table" and type(GameData.BaseStats) == "table" and GameData.BaseStats[cleanName] then base = GameData.BaseStats[cleanName] end else base = prestige * 5 end
					if simStats[s] < statCap then
						local cost = SafeCalculateStatCost(simStats[s], base, prestige)
						if simXP >= cost then simXP -= cost; simStats[s] += 1; tallies[s] += 1; upgradedAny = true; totalUpgrades += 1 end
					end
				end
				if not upgradedAny then break end
			end
			if totalUpgrades > 0 then
				task.spawn(function()
					for s, amt in pairs(tallies) do 
						if amt > 0 then local remaining = amt; while remaining > 0 do local chunk = math.min(remaining, 50); Network:WaitForChild("UpgradeStat"):FireServer(s, chunk); remaining -= chunk; if remaining > 0 then task.wait(0.05) end end end 
					end
					if NotificationManager and type(NotificationManager.Show) == "function" then NotificationManager.Show("Distributed " .. totalUpgrades .. " points evenly!", "Success") end
					task.wait(0.25); isSpammingAll = false
				end)
			else if NotificationManager and type(NotificationManager.Show) == "function" then NotificationManager.Show("Not enough XP to upgrade anything!", "Error") end; isSpammingAll = false end
		end)

		return { Panel = panel, PtsLbl = ptsLbl }
	end

	local playerStatsList = {"Health", "Strength", "Defense", "Speed", "Gas", "Resolve"}
	local titanStatsList = {"Titan_Power_Val", "Titan_Speed_Val", "Titan_Hardening_Val", "Titan_Endurance_Val", "Titan_Precision_Val", "Titan_Potential_Val"}
	local soldierData = SetupPanel("SOLDIER VITALITY", playerStatsList, false, ColumnsContainer)
	local titanData = SetupPanel("TITAN POTENTIAL", titanStatsList, true, ColumnsContainer)

	local TrainContainer = Instance.new("Frame", MainScroll); TrainContainer.Size = UDim2.new(0.95, 0, 0, 120); TrainContainer.BackgroundTransparency = 1; TrainContainer.LayoutOrder = 2
	local tcLayout = Instance.new("UIListLayout", TrainContainer); tcLayout.FillDirection = Enum.FillDirection.Horizontal; tcLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; tcLayout.Padding = UDim.new(0.04, 0)

	local function CreateTrainBox(isTitan)
		local box, _ = CreateGrimPanel(TrainContainer); box.Size = UDim2.new(0.48, 0, 1, 0); box.ClipsDescendants = true
		local title = UIHelpers.CreateLabel(box, isTitan and "TITAN TRAINING" or "SOLDIER TRAINING", UDim2.new(1, -20, 0, 30), Enum.Font.GothamBlack, isTitan and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(200, 200, 220), 16); title.Position = UDim2.new(0, 10, 0, 10); title.TextXAlignment = Enum.TextXAlignment.Left; title.ZIndex = 2
		local comboLbl = UIHelpers.CreateLabel(box, "", UDim2.new(1, -20, 0, 30), Enum.Font.GothamBlack, isTitan and Color3.fromRGB(255, 150, 100) or Color3.fromRGB(150, 255, 100), 18); comboLbl.Position = UDim2.new(0, 10, 0, 40); comboLbl.TextXAlignment = Enum.TextXAlignment.Left; comboLbl.Visible = false; comboLbl.RichText = true; comboLbl.ZIndex = 2
		local missBtn = Instance.new("TextButton", box); missBtn.Size = UDim2.new(1, 0, 1, 0); missBtn.BackgroundTransparency = 1; missBtn.Text = ""; missBtn.ZIndex = 1
		local tBtn, _ = CreateSharpButton(box, isTitan and "TRAIN TITAN" or "TRAIN SOLDIER", UDim2.new(0.4, 0, 0, 50), Enum.Font.GothamBlack, 14); tBtn.AnchorPoint = Vector2.new(0.5, 0.5); tBtn.Position = UDim2.new(0.5, 0, 0.6, 0); tBtn.TextScaled = true; tBtn.ZIndex = 3; Instance.new("UITextSizeConstraint", tBtn).MaxTextSize = 14
		if isTitan then tBtn.TextColor3 = Color3.fromRGB(255, 100, 100) else tBtn.TextColor3 = Color3.fromRGB(100, 255, 100) end

		local function CreateFloatingText(textStr, color, startPos)
			local fTxt = UIHelpers.CreateLabel(box, textStr, UDim2.new(0, 100, 0, 30), Enum.Font.GothamBlack, color, 24); fTxt.Position = startPos; fTxt.AnchorPoint = Vector2.new(0.5, 0.5); fTxt.ZIndex = 4
			TweenService:Create(fTxt, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = fTxt.Position - UDim2.new(0, 0, 0.3, 0), TextTransparency = 1}):Play(); game.Debris:AddItem(fTxt, 0.6)
		end

		local function TriggerTrain()
			local currentPos = tBtn.Position
			if isTitan then titanCombo += 1 else humanCombo += 1 end
			local activeCombo = isTitan and titanCombo or humanCombo

			if activeCombo > 1 then comboLbl.TextColor3 = isTitan and Color3.fromRGB(255, 150, 100) or Color3.fromRGB(150, 255, 100); comboLbl.Visible = true; comboLbl.Text = "x" .. activeCombo .. " COMBO!" end

			local prestige = player:WaitForChild("leaderstats") and player.leaderstats:FindFirstChild("Prestige") and player.leaderstats.Prestige.Value or 0
			local totalStats = (player:GetAttribute("Strength") or 10) + (player:GetAttribute("Defense") or 10) + (player:GetAttribute("Speed") or 10) + (player:GetAttribute("Resolve") or 10)
			local baseXP = 1 + (prestige * 50) + math.floor(totalStats / 4)
			local xpGain = math.floor(baseXP * (1.0 + (activeCombo * 0.02)))
			local targetAttr = isTitan and "TitanXP" or "XP"
			player:SetAttribute(targetAttr, (player:GetAttribute(targetAttr) or 0) + xpGain)

			CreateFloatingText("+" .. xpGain .. (isTitan and " T-XP" or " XP"), Color3.fromRGB(100, 255, 100), currentPos)
			tBtn.Position = UDim2.new(math.random(25, 75)/100, 0, math.random(30, 80)/100, 0)
			Network:WaitForChild("TrainAction"):FireServer(activeCombo, isTitan)
		end

		tBtn.MouseButton1Click:Connect(TriggerTrain)
		missBtn.MouseButton1Click:Connect(function()
			if isTitan and titanCombo > 0 then titanCombo = 0; comboLbl.Visible = true; comboLbl.Text = "<font color='#FF5555'>COMBO DROPPED!</font>"; task.delay(1.5, function() if titanCombo == 0 then comboLbl.Visible = false end end)
			elseif not isTitan and humanCombo > 0 then humanCombo = 0; comboLbl.Visible = true; comboLbl.Text = "<font color='#FF5555'>COMBO DROPPED!</font>"; task.delay(1.5, function() if humanCombo == 0 then comboLbl.Visible = false end end) end
		end)

		if player:GetAttribute("HasAutoTrain") or player.UserId == 4068160397 then
			local autoBtn, _ = CreateSharpButton(box, "AUTO: OFF", UDim2.new(0, 90, 0, 25), Enum.Font.GothamBold, 11)
			autoBtn.Position = UDim2.new(1, -100, 0, 12)
			autoBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
			autoBtn.ZIndex = 5

			autoBtn.Visible = player:GetAttribute("HasAutoTrain") == true or player.UserId == 4068160397
			player:GetAttributeChangedSignal("HasAutoTrain"):Connect(function()
				autoBtn.Visible = player:GetAttribute("HasAutoTrain") == true or player.UserId == 4068160397
			end)

			local isAutoTraining = false
			autoBtn.MouseButton1Click:Connect(function()
				isAutoTraining = not isAutoTraining
				autoBtn.Text = isAutoTraining and "AUTO: ON" or "AUTO: OFF"
				autoBtn.TextColor3 = isAutoTraining and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 255, 255)
				if isAutoTraining then
					task.spawn(function()
						while isAutoTraining and (player:GetAttribute("HasAutoTrain") or player.UserId == 4068160397) do
							if tBtn and tBtn.Parent then TriggerTrain() else isAutoTraining = false end
							task.wait(0.6)
						end
					end)
				end
			end)
		end
		return box
	end
	local soldierBox = CreateTrainBox(false); local titanBox = CreateTrainBox(true)

	local function UpdateStats()
		local prestigeObj = player:WaitForChild("leaderstats", 5) and player.leaderstats:FindFirstChild("Prestige"); local prestige = prestigeObj and prestigeObj.Value or 0
		local hXP = tonumber(player:GetAttribute("XP")) or 0; local tXP = tonumber(player:GetAttribute("TitanXP")) or 0; local statCap = SafeGetStatCap(prestige)
		if soldierData.PtsLbl then soldierData.PtsLbl.Text = AbbreviateNumber(hXP) .. " XP" end
		if titanData.PtsLbl then titanData.PtsLbl.Text = AbbreviateNumber(tXP) .. " T-XP" end
		local allStats = {}; for _, s in ipairs(playerStatsList) do table.insert(allStats, s) end; for _, s in ipairs(titanStatsList) do table.insert(allStats, s) end
		for _, statName in ipairs(allStats) do
			local cleanName = statName:gsub("_Val", ""):gsub("Titan_", ""); local data = statRowRefs[statName]
			if data then
				local isTitanStat = table.find(titanStatsList, statName) ~= nil; local val = ParseStat(player:GetAttribute(statName)) 
				local cost1 = GetUpgradeCosts(val, cleanName, prestige); local bonusAmount = GetCombinedBonus(cleanName); local bonusText = bonusAmount > 0 and " <font color='#55FF55'>(+" .. bonusAmount .. ")</font>" or ""
				if val >= statCap then
					data.Label.Text = cleanName .. ": <font color='" .. (isTitanStat and "#FF5555" or "#FFFFFF") .. "'>" .. val .. "</font>" .. bonusText .. " <font color='#FF5555'>[MAX]</font>"; data.BtnAdd.TextColor3 = UIHelpers.Colors.BorderMuted; data.AddStroke.Color = UIHelpers.Colors.BorderMuted; data.BtnMax.TextColor3 = UIHelpers.Colors.BorderMuted; data.MaxStroke.Color = UIHelpers.Colors.BorderMuted
				else
					data.Label.Text = cleanName .. ": <font color='" .. (isTitanStat and "#FF5555" or "#FFFFFF") .. "'>" .. val .. "</font>" .. bonusText
					local function toggle(btn, stroke, canAfford) if canAfford then btn.TextColor3 = UIHelpers.Colors.TextWhite; stroke.Color = UIHelpers.Colors.BorderMuted else btn.TextColor3 = UIHelpers.Colors.BorderMuted; stroke.Color = Color3.fromRGB(40, 40, 50) end end
					toggle(data.BtnAdd, data.AddStroke, (isTitanStat and tXP or hXP) >= cost1); toggle(data.BtnMax, data.MaxStroke, (isTitanStat and tXP or hXP) >= cost1)
				end
			end
		end
	end

	player.AttributeChanged:Connect(function(attr) if table.find(playerStatsList, attr) or table.find(titanStatsList, attr) or attr == "XP" or attr == "TitanXP" or attr == "Titan" then UpdateStats() end end)
	task.spawn(function() local ls = player:WaitForChild("leaderstats", 10); if ls and ls:FindFirstChild("Prestige") then ls.Prestige.Changed:Connect(UpdateStats) end end)

	LayoutRefs.Attributes = {
		ccLayout = ccLayout,
		SoldierPanel = soldierData.Panel,
		TitanPanel = titanData.Panel
	}
	UpdateStats()
end

-- ==========================================
-- SKILLS TAB
-- ==========================================
local function BuildSkillsTab(parentFrame)
	local MainScroll = Instance.new("ScrollingFrame", parentFrame)
	MainScroll.Size = UDim2.new(1, 0, 1, 0)
	MainScroll.BackgroundTransparency = 1
	MainScroll.ScrollBarThickness = 6
	MainScroll.BorderSizePixel = 0

	local mLayout = Instance.new("UIListLayout", MainScroll)
	mLayout.SortOrder = Enum.SortOrder.LayoutOrder
	mLayout.Padding = UDim.new(0, 15)
	mLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	mLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() 
		MainScroll.CanvasSize = UDim2.new(0, 0, 0, mLayout.AbsoluteContentSize.Y + 40) 
	end)

	local mPad = Instance.new("UIPadding", MainScroll)
	mPad.PaddingTop = UDim.new(0, 15); mPad.PaddingBottom = UDim.new(0, 20)

	local HeaderContainer = Instance.new("Frame", MainScroll)
	HeaderContainer.Size = UDim2.new(0.95, 0, 0, 150)
	HeaderContainer.BackgroundTransparency = 1
	HeaderContainer.LayoutOrder = 1

	local HeaderLabel = CreateSharpLabel(HeaderContainer, "ACTIVE LOADOUT", UDim2.new(1, 0, 0, 25), Enum.Font.GothamBlack, Color3.fromRGB(225, 185, 60), 18)
	HeaderLabel.TextXAlignment = Enum.TextXAlignment.Left

	local ResetBtn, rStroke = CreateSharpButton(HeaderContainer, "RESET DEFAULTS", UDim2.new(0, 130, 0, 25), Enum.Font.GothamBlack, 11)
	ResetBtn.Position = UDim2.new(1, -15, 0, 15)
	ResetBtn.AnchorPoint = Vector2.new(1, 0)
	ResetBtn.BackgroundColor3 = Color3.fromRGB(100, 30, 30)
	rStroke.Color = Color3.fromRGB(200, 50, 50)

	local TopLoadoutGrid = Instance.new("Frame", HeaderContainer)
	TopLoadoutGrid.Size = UDim2.new(1, 0, 0, 110)
	TopLoadoutGrid.Position = UDim2.new(0, 0, 0, 40)
	TopLoadoutGrid.BackgroundTransparency = 1
	local lgLayout = Instance.new("UIGridLayout", TopLoadoutGrid)
	lgLayout.CellSize = UDim2.new(0.23, 0, 0, 50)
	lgLayout.CellPadding = UDim2.new(0.02, 0, 0, 10)
	lgLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local SkillSlotLabels = {}
	for i = 1, 4 do
		local slotFrame = CreateGrimPanel(TopLoadoutGrid)
		slotFrame.ClipsDescendants = true

		local numLbl = CreateSharpLabel(slotFrame, "SLOT " .. i, UDim2.new(0, 40, 0, 15), Enum.Font.GothamBlack, Color3.fromRGB(160, 160, 175), 11)
		numLbl.Position = UDim2.new(0, 5, 0, 5); numLbl.TextXAlignment = Enum.TextXAlignment.Left

		local nameLbl = CreateSharpLabel(slotFrame, "EMPTY", UDim2.new(1, -6, 0.6, 0), Enum.Font.GothamBold, Color3.fromRGB(245, 245, 245), 14)
		nameLbl.Position = UDim2.new(0.5, 0, 0.5, 8); nameLbl.AnchorPoint = Vector2.new(0.5, 0.5); nameLbl.TextWrapped = true; nameLbl.TextScaled = true
		local tCon = Instance.new("UITextSizeConstraint", nameLbl); tCon.MaxTextSize = 14; tCon.MinTextSize = 8
		table.insert(SkillSlotLabels, nameLbl)
	end

	local sep = Instance.new("Frame", MainScroll)
	sep.Size = UDim2.new(0.95, 0, 0, 2)
	sep.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
	sep.BorderSizePixel = 0
	sep.LayoutOrder = 2

	local LibHeader = CreateSharpLabel(MainScroll, "SKILL LIBRARY", UDim2.new(0.95, 0, 0, 35), Enum.Font.GothamBlack, Color3.fromRGB(245, 245, 245), 20)
	LibHeader.LayoutOrder = 3
	LibHeader.TextXAlignment = Enum.TextXAlignment.Left

	local SkillLibraryContainer = Instance.new("Frame", MainScroll)
	SkillLibraryContainer.Size = UDim2.new(0.95, 0, 0, 0)
	SkillLibraryContainer.AutomaticSize = Enum.AutomaticSize.Y
	SkillLibraryContainer.BackgroundTransparency = 1
	SkillLibraryContainer.LayoutOrder = 4

	local libLayout = Instance.new("UIListLayout", SkillLibraryContainer)
	libLayout.Padding = UDim.new(0, 15)
	libLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	libLayout.SortOrder = Enum.SortOrder.LayoutOrder

	LayoutRefs.Skills = {
		HeaderContainer = HeaderContainer,
		TopLoadoutGrid = TopLoadoutGrid,
		TopLoadoutLayout = lgLayout,
		LibraryGrids = {}
	}

	local function IsSkillValid(skillName, isTransformedCheck)
		local sData = SkillData.Skills[skillName]
		if not sData then return false end
		local req = tostring(sData.Requirement or "None")
		if isTransformedCheck then
			local myTitan = player:GetAttribute("Titan") or "None"
			local universalTitanMoves = { ["Eject"]=true, ["Titan Recover"]=true, ["Titan Rest"]=true, ["Cannibalize"]=true, ["Maneuver"]=true, ["Evasive Maneuver"]=true, ["Block"]=true, ["Close In"]=true, ["Fall Back"]=true, ["Advance"]=true, ["Charge"]=true, ["Transform"]=true, ["Titan Punch"]=true, ["Titan Kick"]=true }
			if req == "Transformed" or req == "AnyTitan" or req == myTitan or string.find(myTitan, req, 1, true) or universalTitanMoves[skillName] then return true end
			return false
		end
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
					local wCount = tonumber(player:GetAttribute(safeNameBase .. "Count")) or 0
					if wCount > 0 then return true end
				end
			end
		end
		return false
	end

	local function RefreshSkills()
		for _, c in ipairs(SkillLibraryContainer:GetChildren()) do if c:IsA("Frame") or c:IsA("TextLabel") then c:Destroy() end end
		LayoutRefs.Skills.LibraryGrids = {}

		if not hasSkillData or type(SkillData) ~= "table" then return end
		local tData = SkillData.Skills or SkillData; local categorizedSkills = {}; local defaultMoves = {}; local allowedRequirements = { ["ODM"] = "BASE ODM", ["Ultrahard Steel Blades"] = "ULTRAHARD BLADES", ["Thunder Spears"] = "THUNDER SPEARS", ["Anti-Personnel"] = "ANTI-PERSONNEL" }

		for sName, sData in pairs(tData) do
			if type(sData) == "table" and sData.Type == "Style" then
				local req = tostring(sData.Requirement or "None")
				local reqGroup = allowedRequirements[req]
				local hasWeapon = false
				local isClanSkill = false

				if reqGroup then
					if req == "ODM" then 
						hasWeapon = true
						table.insert(defaultMoves, sName)
					else 
						if type(ItemData) == "table" and ItemData.Equipment then
							for iName, iData in pairs(ItemData.Equipment) do 
								if iData.Style == req then 
									local safeNameBase = iName:gsub("[^%w]", "")
									local wCount = tonumber(player:GetAttribute(safeNameBase .. "Count")) or tonumber(player:GetAttribute(iName)) or 0
									if wCount > 0 then hasWeapon = true; break end 
								end 
							end 
						end
					end
				else 
					local myClan = player:GetAttribute("Clan") or "None"
					if myClan ~= "None" then
						if string.find(myClan, req, 1, true) then 
							hasWeapon = true 
						elseif string.find(req, "Awakened", 1, true) then
							local baseReq = string.gsub(req, "Awakened ", "")
							if string.find(myClan, "Abyssal " .. baseReq, 1, true) then
								hasWeapon = true
							end
						end
						if hasWeapon then reqGroup = "CLAN LINEAGE"; isClanSkill = true end
					end 
				end

				if reqGroup then 
					local cat = reqGroup .. " SKILLS"
					if not categorizedSkills[cat] then categorizedSkills[cat] = { HasUnlocked = false, Skills = {} } end
					if hasWeapon then categorizedSkills[cat].HasUnlocked = true end
					table.insert(categorizedSkills[cat].Skills, {Name = sName, Data = sData, HasWep = hasWeapon}) 
				end
			end
		end
		table.sort(defaultMoves)

		for i, lbl in ipairs(SkillSlotLabels) do 
			local rawName = player:GetAttribute("EquippedSkill_" .. i)
			if not rawName or rawName == "" or rawName == "None" or not IsSkillValid(rawName, false) then 
				rawName = defaultMoves[i] or "EMPTY" 
			end
			lbl.Text = string.upper(rawName) 
		end

		local sortedCats = {}; for k, _ in pairs(categorizedSkills) do table.insert(sortedCats, k) end
		table.sort(sortedCats, function(a, b) local aUnlocked = categorizedSkills[a].HasUnlocked; local bUnlocked = categorizedSkills[b].HasUnlocked; if aUnlocked ~= bUnlocked then return aUnlocked and not bUnlocked end; return a < b end)

		local sOrderCount = 1
		for _, catName in ipairs(sortedCats) do
			local skills = categorizedSkills[catName].Skills
			if #skills > 0 then
				local catHeader = CreateSharpLabel(SkillLibraryContainer, "- " .. catName .. " -", UDim2.new(1, 0, 0, 35), Enum.Font.GothamBlack, Color3.fromRGB(225, 185, 60), 16)
				catHeader.LayoutOrder = sOrderCount; sOrderCount += 1; catHeader.TextXAlignment = Enum.TextXAlignment.Left

				local GridContainer = Instance.new("Frame", SkillLibraryContainer)
				GridContainer.Size = UDim2.new(1, 0, 0, 0)
				GridContainer.AutomaticSize = Enum.AutomaticSize.Y
				GridContainer.BackgroundTransparency = 1
				GridContainer.LayoutOrder = sOrderCount; sOrderCount += 1 

				local uigrid = Instance.new("UIGridLayout", GridContainer)
				uigrid.CellSize = UDim2.new(0.31, 0, 0, 180)
				uigrid.CellPadding = UDim2.new(0.02, 0, 0, 15)
				uigrid.SortOrder = Enum.SortOrder.LayoutOrder
				uigrid.HorizontalAlignment = Enum.HorizontalAlignment.Center 

				table.insert(LayoutRefs.Skills.LibraryGrids, uigrid)
				table.sort(skills, function(a, b) return (a.Data.Order or 99) < (b.Data.Order or 99) end)

				for i, item in ipairs(skills) do
					local sName = item.Name; local sData = item.Data; local hasWep = item.HasWep
					local sCard, _ = CreateGrimPanel(GridContainer); sCard.LayoutOrder = i
					local wepText = ""; if sData.Requirement == "ODM" then wepText = "[ BASE SKILL ]" else wepText = "[ REQ: " .. string.upper(sData.Requirement) .. " ]" end

					local sTitle = CreateSharpLabel(sCard, string.upper(sName), UDim2.new(1, -10, 0, 35), Enum.Font.GothamBlack, Color3.fromRGB(245, 245, 245), 14)
					sTitle.Position = UDim2.new(0.5, 0, 0, 5); sTitle.AnchorPoint = Vector2.new(0.5, 0); sTitle.TextWrapped = true; sTitle.TextScaled = true
					local tc = Instance.new("UITextSizeConstraint", sTitle); tc.MaxTextSize = 14; tc.MinTextSize = 10

					local sReq = CreateSharpLabel(sCard, wepText, UDim2.new(1, -10, 0, 20), Enum.Font.GothamBold, (hasWep and Color3.fromRGB(85, 255, 85) or Color3.fromRGB(255, 85, 85)), 10)
					sReq.Position = UDim2.new(0.5, 0, 0, 45); sReq.AnchorPoint = Vector2.new(0.5, 0)

					local desc = CreateSharpLabel(sCard, sData.Desc or "A powerful technique.", UDim2.new(1, -10, 0, 50), Enum.Font.GothamMedium, Color3.fromRGB(160, 160, 175), 11)
					desc.Position = UDim2.new(0.5, 0, 0, 70); desc.AnchorPoint = Vector2.new(0.5, 0); desc.TextWrapped = true; desc.TextYAlignment = Enum.TextYAlignment.Top

					local eqBtn, eqStroke = CreateSharpButton(sCard, "EQUIP", UDim2.new(1, -20, 0, 30), Enum.Font.GothamBlack, 12)
					eqBtn.Position = UDim2.new(0.5, 0, 1, -10); eqBtn.AnchorPoint = Vector2.new(0.5, 1)

					if sData.ComboReq then 
						local syn = CreateSharpLabel(sCard, "Synergy: After " .. string.upper(sData.ComboReq), UDim2.new(1, -10, 0, 20), Enum.Font.GothamBold, Color3.fromRGB(225, 185, 60), 10)
						syn.Position = UDim2.new(0.5, 0, 1, -45); syn.AnchorPoint = Vector2.new(0.5, 1); syn.TextWrapped = true 
					end

					local isEquipped = false
					for j=1,4 do 
						local slotWep = player:GetAttribute("EquippedSkill_"..j)
						if not slotWep or slotWep == "" or slotWep == "EMPTY" then slotWep = defaultMoves[j] end
						if slotWep == sName then isEquipped = true break end 
					end

					if isEquipped then eqBtn.Text = "EQUIPPED"; eqBtn.TextColor3 = Color3.fromRGB(225, 185, 60); eqStroke.Color = Color3.fromRGB(225, 185, 60) 
					elseif not hasWep then eqBtn.Text = "LOCKED"; eqBtn.TextColor3 = Color3.fromRGB(100, 100, 100); eqStroke.Color = Color3.fromRGB(70, 70, 80) 
					else eqBtn.Text = "EQUIP"; eqBtn.TextColor3 = Color3.fromRGB(245, 245, 245); eqStroke.Color = Color3.fromRGB(70, 70, 80) end

					if hasWep then
						local ActionsOverlay = Instance.new("Frame", sCard); ActionsOverlay.Name = "ActionsOverlay"; ActionsOverlay.Size = UDim2.new(1, 0, 1, 0); ActionsOverlay.BackgroundColor3 = Color3.fromRGB(18, 18, 22); ActionsOverlay.BackgroundTransparency = 0.1; ActionsOverlay.Visible = false; ActionsOverlay.ZIndex = 10; ActionsOverlay.Active = true; ActionsOverlay.BorderSizePixel = 0
						local actLayout = Instance.new("UIListLayout", ActionsOverlay); actLayout.FillDirection = Enum.FillDirection.Vertical; actLayout.Padding = UDim.new(0, 6); actLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; actLayout.VerticalAlignment = Enum.VerticalAlignment.Center

						for sIndex = 1, 4 do 
							local slotBtn, _ = CreateSharpButton(ActionsOverlay, "SLOT " .. sIndex, UDim2.new(0.8, 0, 0, 26), Enum.Font.GothamBlack, 11); 
							slotBtn.ZIndex = 11; 
							slotBtn.MouseButton1Click:Connect(function() 
								Network:WaitForChild("EquipSkill"):FireServer(sIndex, sName); 
								player:SetAttribute("EquippedSkill_"..sIndex, sName)
								ActionsOverlay.Visible = false; 
								RefreshSkills() 
							end) 
						end
						local closeBtn, _ = CreateSharpButton(ActionsOverlay, "CANCEL", UDim2.new(0.8, 0, 0, 26), Enum.Font.GothamBlack, 11); closeBtn.ZIndex = 11; closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100); closeBtn.MouseButton1Click:Connect(function() ActionsOverlay.Visible = false end)
						eqBtn.MouseButton1Click:Connect(function() if ActionsOverlay.Visible then ActionsOverlay.Visible = false else for _, sc in ipairs(SkillLibraryContainer:GetDescendants()) do if sc.Name == "ActionsOverlay" then sc.Visible = false end end; ActionsOverlay.Visible = true end end) 
					end
				end
			end
		end

		local vp = camera.ViewportSize
		local isMobile = (vp.X <= 850) or (vp.Y > vp.X)
		if LayoutRefs.Skills and LayoutRefs.Skills.LibraryGrids then
			for _, grid in ipairs(LayoutRefs.Skills.LibraryGrids) do
				grid.CellSize = isMobile and UDim2.new(0.95, 0, 0, 180) or UDim2.new(0.31, 0, 0, 180)
				grid.CellPadding = isMobile and UDim2.new(0, 0, 0, 15) or UDim2.new(0.02, 0, 0, 15)
			end
		end
	end

	ResetBtn.MouseButton1Click:Connect(function()
		for i = 1, 4 do
			Network:WaitForChild("EquipSkill"):FireServer(i, "None")
			player:SetAttribute("EquippedSkill_"..i, "None")
		end
		RefreshSkills()
	end)

	player.AttributeChanged:Connect(function(attr) if string.match(attr, "^EquippedSkill") then RefreshSkills() end end); RefreshSkills()
end

-- ==========================================
-- PRESTIGE TAB (Fully Native Web Integration)
-- ==========================================
local function BuildPrestigeTab(parentFrame)
	local MainContainer = Instance.new("Frame", parentFrame)
	MainContainer.Size = UDim2.new(1, 0, 1, 0)
	MainContainer.BackgroundTransparency = 1

	local LeftPanel = CreateGrimPanel(MainContainer)
	LeftPanel.AnchorPoint = Vector2.new(0, 0)
	LeftPanel.Position = UDim2.new(0, 15, 0, 15)

	local ATitle = CreateSharpLabel(LeftPanel, "PRESTIGE ASCENSION", UDim2.new(1, 0, 0, 30), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 20)
	ATitle.Position = UDim2.new(0, 0, 0, 15)
	local ASub = CreateSharpLabel(LeftPanel, "TIER 0 ➔ TIER 1", UDim2.new(1, 0, 0, 20), Enum.Font.GothamBold, Color3.fromRGB(150, 255, 150), 16)
	ASub.Position = UDim2.new(0, 0, 0, 45)

	local RBox = Instance.new("Frame", LeftPanel); RBox.Size = UDim2.new(0.9, 0, 0, 120); RBox.Position = UDim2.new(0.5, 0, 0, 80); RBox.AnchorPoint = Vector2.new(0.5, 0); RBox.BackgroundColor3 = Color3.fromRGB(22, 22, 26); local rStroke = Instance.new("UIStroke", RBox); rStroke.Color = Color3.fromRGB(70, 70, 80); rStroke.Thickness = 2
	local rTitle = CreateSharpLabel(RBox, "NEXT TIER REWARDS:", UDim2.new(1, -10, 0, 25), Enum.Font.GothamBold, UIHelpers.Colors.TextWhite, 14); rTitle.Position = UDim2.new(0, 10, 0, 5); rTitle.TextXAlignment = Enum.TextXAlignment.Left
	local r1 = CreateSharpLabel(RBox, "• +1 Prestige Point", UDim2.new(1, -10, 0, 25), Enum.Font.GothamMedium, UIHelpers.Colors.Gold, 13); r1.Position = UDim2.new(0, 10, 0, 35); r1.TextXAlignment = Enum.TextXAlignment.Left
	local r2 = CreateSharpLabel(RBox, "• Increased Maximum Stat Caps", UDim2.new(1, -10, 0, 25), Enum.Font.GothamMedium, Color3.fromRGB(100, 255, 100), 13); r2.Position = UDim2.new(0, 10, 0, 60); r2.TextXAlignment = Enum.TextXAlignment.Left
	local r3 = CreateSharpLabel(RBox, "• +20% HP & Damage Multiplier", UDim2.new(1, -10, 0, 25), Enum.Font.GothamMedium, Color3.fromRGB(255, 100, 100), 13); r3.Position = UDim2.new(0, 10, 0, 85); r3.TextXAlignment = Enum.TextXAlignment.Left

	local WBox = Instance.new("Frame", LeftPanel); WBox.Size = UDim2.new(0.9, 0, 0, 40); WBox.Position = UDim2.new(0.5, 0, 0, 210); WBox.AnchorPoint = Vector2.new(0.5, 0); WBox.BackgroundColor3 = Color3.fromRGB(30, 10, 10); local wStroke = Instance.new("UIStroke", WBox); wStroke.Color = Color3.fromRGB(150, 50, 50); wStroke.Thickness = 2
	local wText = CreateSharpLabel(WBox, "WARNING: Ascending resets Level, Stats, Titan Power, and Campaign.", UDim2.new(1, -10, 1, 0), Enum.Font.GothamBold, Color3.fromRGB(255, 150, 150), 11); wText.Position = UDim2.new(0, 5, 0, 0); wText.TextWrapped = true

	local AscendBtn, aStroke = CreateSharpButton(LeftPanel, "ASCEND", UDim2.new(0.8, 0, 0, 45), Enum.Font.GothamBlack, 16)
	AscendBtn.Position = UDim2.new(0.5, 0, 1, -15); AscendBtn.AnchorPoint = Vector2.new(0.5, 1); AscendBtn.BackgroundColor3 = Color3.fromRGB(100, 20, 20); AscendBtn.TextColor3 = Color3.fromRGB(255, 200, 200); aStroke.Color = Color3.fromRGB(255, 50, 50)

	local function UpdateLeftPanelUI()
		local ls = player:FindFirstChild("leaderstats")
		local pLevel = ls and ls:FindFirstChild("Prestige") and ls.Prestige.Value or 0
		local nextLevel = pLevel + 1
		ASub.Text = "TIER " .. pLevel .. " ➔ TIER " .. nextLevel
		AscendBtn.Text = "ASCEND TO TIER " .. nextLevel
	end

	AscendBtn.MouseButton1Click:Connect(function()
		local ls = player:FindFirstChild("leaderstats")
		local currentTier = ls and ls:FindFirstChild("Prestige") and ls.Prestige.Value or 0

		local confirm = Network:WaitForChild("PrestigeAction"):InvokeServer()
		if confirm then 
			if NotificationManager and type(NotificationManager.Show) == "function" then NotificationManager.Show("ASCENDED TO PRESTIGE TIER " .. (currentTier + 1) .. "!", "Success") end
			task.wait(1); UpdateLeftPanelUI()
		else
			if NotificationManager and type(NotificationManager.Show) == "function" then NotificationManager.Show("You must clear Chapter 8 with maxed stats to Ascend!", "Error") end
		end
	end)

	player.AttributeChanged:Connect(function(attr) if string.find(attr, "Prestige") then UpdateLeftPanelUI() end end)
	task.spawn(function() local ls = player:WaitForChild("leaderstats", 10); if ls and ls:FindFirstChild("Prestige") then ls.Prestige.Changed:Connect(UpdateLeftPanelUI) end end)
	UpdateLeftPanelUI()

	local RightPanel = Instance.new("Frame", MainContainer)
	RightPanel.AnchorPoint = Vector2.new(1, 0)
	RightPanel.Position = UDim2.new(1, -15, 0, 15)
	RightPanel.BackgroundTransparency = 1

	local TopHeader = Instance.new("Frame", RightPanel)
	TopHeader.Size = UDim2.new(1, 0, 0, 35)
	TopHeader.BackgroundTransparency = 1

	local PointsLabel = CreateSharpLabel(TopHeader, "AVAILABLE POINTS: 0", UDim2.new(1, 0, 1, 0), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 20)
	PointsLabel.TextXAlignment = Enum.TextXAlignment.Left
	PointsLabel.Position = UDim2.new(0, 10, 0, 0)

	local CanvasContainer = Instance.new("CanvasGroup", RightPanel)
	CanvasContainer.Size = UDim2.new(1, 0, 1, -185)
	CanvasContainer.Position = UDim2.new(0, 0, 0, 40)
	CanvasContainer.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
	CanvasContainer.BorderSizePixel = 0
	local cgStroke = Instance.new("UIStroke", CanvasContainer)
	cgStroke.Color = UIHelpers.Colors.BorderMuted
	cgStroke.Thickness = 2

	local Canvas = Instance.new("Frame", CanvasContainer)
	Canvas.Size = UDim2.new(3, 0, 3, 0) 
	Canvas.Position = UDim2.new(-1, 0, -1, 0) 
	Canvas.BackgroundTransparency = 1

	local CanvasScale = Instance.new("UIScale", Canvas)
	CanvasScale.Scale = 1

	local gridTexture = Instance.new("ImageLabel", Canvas)
	gridTexture.Size = UDim2.new(1, 0, 1, 0)
	gridTexture.BackgroundTransparency = 1
	gridTexture.Image = "rbxassetid://6078235439"
	gridTexture.ImageTransparency = 0.95
	gridTexture.ScaleType = Enum.ScaleType.Tile
	gridTexture.TileSize = UDim2.new(0, 150, 0, 150)
	gridTexture.ZIndex = 0

	local linesContainer = Instance.new("Folder", Canvas)
	linesContainer.Name = "Lines"

	local DetailPanel = Instance.new("Frame", RightPanel)
	DetailPanel.Size = UDim2.new(1, 0, 0, 135)
	DetailPanel.Position = UDim2.new(0, 0, 1, -135)
	DetailPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	DetailPanel.BorderSizePixel = 0
	DetailPanel.Visible = false
	local dpStroke = Instance.new("UIStroke", DetailPanel)
	dpStroke.Color = Color3.fromRGB(70, 70, 80)
	dpStroke.Thickness = 2

	local DTitle = CreateSharpLabel(DetailPanel, "", UDim2.new(1, -20, 0, 35), Enum.Font.GothamBlack, UIHelpers.Colors.TextWhite, 20)
	DTitle.Position = UDim2.new(0, 15, 0, 10); DTitle.TextXAlignment = Enum.TextXAlignment.Left

	local DDesc = CreateSharpLabel(DetailPanel, "", UDim2.new(0.6, 0, 0, 50), Enum.Font.GothamMedium, UIHelpers.Colors.TextMuted, 12)
	DDesc.Position = UDim2.new(0, 15, 0, 45); DDesc.TextWrapped = true; DDesc.TextXAlignment = Enum.TextXAlignment.Left; DDesc.TextYAlignment = Enum.TextYAlignment.Top

	local DCost = CreateSharpLabel(DetailPanel, "", UDim2.new(0.3, 0, 0, 30), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 16)
	DCost.Position = UDim2.new(1, -15, 1, -35); DCost.AnchorPoint = Vector2.new(1, 0); DCost.TextXAlignment = Enum.TextXAlignment.Right

	local DReq = CreateSharpLabel(DetailPanel, "", UDim2.new(0.5, 0, 0, 20), Enum.Font.GothamBold, UIHelpers.Colors.Border, 12)
	DReq.Position = UDim2.new(0, 15, 1, -30); DReq.TextXAlignment = Enum.TextXAlignment.Left

	local UnlockBtn, UBtnStroke = CreateSharpButton(DetailPanel, "UNLOCK", UDim2.new(0.3, 0, 0, 40), Enum.Font.GothamBlack, 14)
	UnlockBtn.Position = UDim2.new(1, -15, 1, -45); UnlockBtn.AnchorPoint = Vector2.new(1, 1)

	local selectedNode = nil
	local generatedNodes = {}
	local nodeLines = {}

	for id, nodeData in pairs(type(GameData) == "table" and GameData.PrestigeNodes or {}) do
		local nodeBase = Instance.new("TextButton", Canvas)
		nodeBase.Name = id
		nodeBase.Size = UDim2.new(0, 44, 0, 44)
		nodeBase.Position = nodeData.Pos
		nodeBase.AnchorPoint = Vector2.new(0.5, 0.5)
		nodeBase.Rotation = 45 
		nodeBase.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
		nodeBase.BorderColor3 = Color3.fromRGB(50, 50, 60)
		nodeBase.BorderSizePixel = 3
		nodeBase.ZIndex = 3
		nodeBase.Text = "" 

		local nodeText = CreateSharpLabel(nodeBase, tostring(nodeData.Cost or 1), UDim2.new(2, 0, 2, 0), Enum.Font.GothamBlack, Color3.fromRGB(160, 160, 160), 14)
		nodeText.AnchorPoint = Vector2.new(0.5, 0.5)
		nodeText.Position = UDim2.new(0.5, 0, 0.5, 0)
		nodeText.Rotation = -45
		nodeText.ZIndex = 4

		if (nodeData.Cost or 0) == 0 then
			nodeText.Text = "★"
			nodeText.TextColor3 = UIHelpers.Colors.Gold
		end

		local glow = Instance.new("ImageLabel", nodeBase)
		glow.Size = UDim2.new(3.5, 0, 3.5, 0)
		glow.Position = UDim2.new(0.5, 0, 0.5, 0)
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.BackgroundTransparency = 1
		glow.Image = "rbxassetid://2001828033" 
		glow.ImageColor3 = Color3.fromRGB(150, 50, 50)
		glow.ImageTransparency = 0.8
		glow.Rotation = -45 
		glow.ZIndex = 2

		generatedNodes[id] = { Base = nodeBase, Glow = glow, Text = nodeText, NodeColor = nodeData.Color or "#FFFFFF" }

		nodeBase.MouseButton1Click:Connect(function()
			selectedNode = id
			DetailPanel.Visible = true
			DTitle.Text = nodeData.Name
			DTitle.TextColor3 = Color3.fromHex((nodeData.Color or "#FFFFFF"):gsub("#", ""))
			DDesc.Text = nodeData.Desc or ""
			DCost.Text = "COST: " .. (nodeData.Cost or 1) .. " PTS"

			local isOwned = player:GetAttribute("PrestigeNode_" .. id)
			local hasReq = (not nodeData.Req) or player:GetAttribute("PrestigeNode_" .. nodeData.Req)

			if isOwned then 
				DReq.Text = "OWNED"
				DReq.TextColor3 = Color3.fromRGB(100, 255, 100)
				UnlockBtn.Text = "OWNED"
				UnlockBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
				UBtnStroke.Color = UIHelpers.Colors.BorderMuted
			elseif not hasReq then 
				DReq.Text = "REQUIRES: " .. (GameData.PrestigeNodes[nodeData.Req] and GameData.PrestigeNodes[nodeData.Req].Name or nodeData.Req)
				DReq.TextColor3 = UIHelpers.Colors.Border
				UnlockBtn.Text = "LOCKED"
				UnlockBtn.TextColor3 = UIHelpers.Colors.Border
				UBtnStroke.Color = UIHelpers.Colors.Border
			else 
				DReq.Text = "AVAILABLE TO UNLOCK"
				DReq.TextColor3 = UIHelpers.Colors.TextWhite
				UnlockBtn.Text = "UNLOCK"
				UnlockBtn.TextColor3 = Color3.fromHex((nodeData.Color or "#FFFFFF"):gsub("#", ""))
				UBtnStroke.Color = Color3.fromHex((nodeData.Color or "#FFFFFF"):gsub("#", ""))
			end
		end)
	end

	UnlockBtn.MouseButton1Click:Connect(function()
		if selectedNode and UnlockBtn.Text == "UNLOCK" then 
			Network:WaitForChild("UnlockPrestigeNode"):FireServer(selectedNode)
		end
	end)

	local dragging = false
	local dragStart = Vector3.new()
	local startPos = UDim2.new()

	CanvasContainer.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = Canvas.Position
		end
	end)

	CanvasContainer.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			if dragging then
				local delta = input.Position - dragStart
				Canvas.Position = UDim2.new(
					startPos.X.Scale, startPos.X.Offset + (delta.X / CanvasScale.Scale),
					startPos.Y.Scale, startPos.Y.Offset + (delta.Y / CanvasScale.Scale)
				)
			end
		elseif input.UserInputType == Enum.UserInputType.MouseWheel then
			local newScale = math.clamp(CanvasScale.Scale + (input.Position.Z * 0.15), 0.3, 2.5)
			CanvasScale.Scale = newScale
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	local initialPinchScale = 1
	UserInputService.TouchPinch:Connect(function(touchPositions, scale, velocity, state, gameProcessed)
		if state == Enum.UserInputState.Begin then
			initialPinchScale = CanvasScale.Scale
		elseif state == Enum.UserInputState.Change then
			CanvasScale.Scale = math.clamp(initialPinchScale * scale, 0.3, 2.5)
		end
	end)

	task.defer(function()
		local canvasSize = Canvas.AbsoluteSize
		if canvasSize.X == 0 then canvasSize = Vector2.new(2000, 2000) end 

		for id, nodeData in pairs(type(GameData) == "table" and GameData.PrestigeNodes or {}) do
			local targetData = generatedNodes[id]
			if nodeData.Req and targetData then
				local sourceData = generatedNodes[nodeData.Req]
				if sourceData then
					local targetNode = targetData.Base
					local sourceNode = sourceData.Base
					local tPos = targetNode.Position
					local sPos = sourceNode.Position

					local p1X = (sPos.X.Scale * canvasSize.X) + sPos.X.Offset
					local p1Y = (sPos.Y.Scale * canvasSize.Y) + sPos.Y.Offset
					local p2X = (tPos.X.Scale * canvasSize.X) + tPos.X.Offset
					local p2Y = (tPos.Y.Scale * canvasSize.Y) + tPos.Y.Offset

					local line = DrawLine(linesContainer, Vector2.new(p1X, p1Y), Vector2.new(p2X, p2Y))
					table.insert(nodeLines, { Line = line, Target = id, Source = nodeData.Req })
				end
			end
		end

		player:SetAttribute("_ForceWebUpdate", math.random())
	end)

	local function UpdateWebState()
		local pts = player:GetAttribute("PrestigePoints") or 0
		PointsLabel.Text = "AVAILABLE POINTS: " .. pts

		for id, nodeObj in pairs(generatedNodes) do
			local nodeData = GameData.PrestigeNodes[id]
			local isOwned = player:GetAttribute("PrestigeNode_" .. id)
			local hasReq = (not nodeData.Req) or player:GetAttribute("PrestigeNode_" .. nodeData.Req)
			local customColor = Color3.fromHex((nodeObj.NodeColor or "#FFFFFF"):gsub("#", ""))

			if isOwned then
				nodeObj.Base.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
				nodeObj.Base.BorderColor3 = customColor
				nodeObj.Text.TextColor3 = Color3.fromRGB(255, 255, 255)
				nodeObj.Glow.ImageColor3 = customColor
				nodeObj.Glow.ImageTransparency = 0.4
			elseif hasReq then
				nodeObj.Base.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
				nodeObj.Base.BorderColor3 = Color3.fromRGB(100, 150, 255)
				nodeObj.Text.TextColor3 = Color3.fromRGB(200, 220, 255)
				nodeObj.Glow.ImageColor3 = Color3.fromRGB(100, 150, 255)
				nodeObj.Glow.ImageTransparency = 0.6
			else
				nodeObj.Base.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
				nodeObj.Base.BorderColor3 = Color3.fromRGB(50, 50, 60)
				nodeObj.Text.TextColor3 = Color3.fromRGB(160, 160, 160)
				nodeObj.Glow.ImageColor3 = Color3.fromRGB(150, 50, 50)
				nodeObj.Glow.ImageTransparency = 0.8
			end
		end

		for _, lineData in ipairs(nodeLines) do
			local isTargetOwned = player:GetAttribute("PrestigeNode_" .. lineData.Target)
			local isSourceOwned = player:GetAttribute("PrestigeNode_" .. lineData.Source)

			if isTargetOwned then
				lineData.Line.BackgroundColor3 = Color3.fromRGB(225, 185, 60)
				lineData.Line.ZIndex = 2
			elseif isSourceOwned then
				lineData.Line.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
				lineData.Line.ZIndex = 1
			else
				lineData.Line.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
				lineData.Line.ZIndex = 1
			end
		end

		if selectedNode and DetailPanel.Visible then
			local nodeData = GameData.PrestigeNodes[selectedNode]
			local isOwned = player:GetAttribute("PrestigeNode_" .. selectedNode)
			local hasReq = (not nodeData.Req) or player:GetAttribute("PrestigeNode_" .. nodeData.Req)

			if isOwned then 
				DReq.Text = "OWNED"
				DReq.TextColor3 = Color3.fromRGB(100, 255, 100)
				UnlockBtn.Text = "OWNED"
				UnlockBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
				UBtnStroke.Color = UIHelpers.Colors.BorderMuted
			elseif not hasReq then 
				DReq.Text = "REQUIRES: " .. (GameData.PrestigeNodes[nodeData.Req] and GameData.PrestigeNodes[nodeData.Req].Name or nodeData.Req)
				DReq.TextColor3 = UIHelpers.Colors.Border
				UnlockBtn.Text = "LOCKED"
				UnlockBtn.TextColor3 = UIHelpers.Colors.Border
				UBtnStroke.Color = UIHelpers.Colors.Border
			else 
				DReq.Text = "AVAILABLE TO UNLOCK"
				DReq.TextColor3 = UIHelpers.Colors.TextWhite
				UnlockBtn.Text = "UNLOCK"
				UnlockBtn.TextColor3 = Color3.fromHex((nodeData.Color or "#FFFFFF"):gsub("#", ""))
				UBtnStroke.Color = Color3.fromHex((nodeData.Color or "#FFFFFF"):gsub("#", ""))
			end
		end
	end

	player.AttributeChanged:Connect(function(attr)
		if string.find(attr, "Prestige") or attr == "_ForceWebUpdate" then 
			UpdateWebState() 
		end
	end)

	UpdateWebState()

	LayoutRefs.Prestige = {
		LeftPanel = LeftPanel,
		RightPanel = RightPanel
	}
end

-- ==========================================
-- INHERITANCE TAB
-- ==========================================
local function BuildInheritanceTab(parentFrame)
	local MainScroll = Instance.new("ScrollingFrame", parentFrame)
	MainScroll.Size = UDim2.new(1, 0, 1, 0)
	MainScroll.BackgroundTransparency = 1
	MainScroll.ScrollBarThickness = 6
	MainScroll.BorderSizePixel = 0
	MainScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local isRolling = { Titan = false, Clan = false }; local isAutoRolling = { Titan = false, Clan = false }; local currentRollSeq = { Titan = 0, Clan = 0 }
	local autoRollBtns = {}

	MainScroll:GetPropertyChangedSignal("Visible"):Connect(function() if not MainScroll.Visible then isAutoRolling.Titan = false; isAutoRolling.Clan = false end end)
	local titleLayout = Instance.new("UIListLayout", MainScroll); titleLayout.SortOrder = Enum.SortOrder.LayoutOrder; titleLayout.Padding = UDim.new(0, 15); titleLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local pad = Instance.new("UIPadding", MainScroll); pad.PaddingTop = UDim.new(0, 10); pad.PaddingBottom = UDim.new(0, 30)

	local Title = CreateSharpLabel(MainScroll, "THE PATHS (INHERITANCE)", UDim2.new(1, 0, 0, 40), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 26); Title.LayoutOrder = 1
	local PanelsContainer = Instance.new("Frame", MainScroll)
	PanelsContainer.Size = UDim2.new(0.95, 0, 0, 0)
	PanelsContainer.AutomaticSize = Enum.AutomaticSize.Y
	PanelsContainer.BackgroundTransparency = 1
	PanelsContainer.LayoutOrder = 2
	local pcLayout = Instance.new("UIListLayout", PanelsContainer); pcLayout.FillDirection = Enum.FillDirection.Horizontal; pcLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; pcLayout.Padding = UDim.new(0, 20)

	local ClanVisualBuffs = {
		["None"] = "No inherent abilities.", ["Braus"] = "+10% Speed", ["Springer"] = "+15% Evasion",
		["Galliard"] = "+15% Speed, +5% Power\n<font color='#FFD700'>[Jaw Titan Synergy]: +25% Spd & Crit</font>", 
		["Braun"] = "+20% Defense\n<font color='#FFD700'>[Armored Titan Synergy]: +50% Armor</font>", 
		["Arlert"] = "+15% Resolve\n<font color='#FFD700'>[Colossal Titan Synergy]: +50% Max HP</font>",
		["Tybur"] = "+20% Titan Power\n<font color='#FFD700'>[War Hammer Synergy]: +30% Dmg</font>", 
		["Yeager"] = "+25% Titan Damage\n<font color='#FFD700'>[Attack Titan Synergy]: +30% Dmg</font>", 
		["Reiss"] = "+50% Base Health", ["Ackerman"] = "+25% Weapon Damage, Immune to Memory Wipes"
	}

	local function ResetAutoRollVisuals(gType)
		if autoRollBtns[gType] then
			autoRollBtns[gType].Text = "ROLL TILL LEGENDARY+"
			autoRollBtns[gType].BackgroundColor3 = Color3.fromRGB(28, 28, 34)
		end
	end

	local function IsHighTier(gType)
		local current = player:GetAttribute(gType)
		if not current or current == "None" then return false end
		if gType == "Titan" and type(TitanData) == "table" and TitanData.Titans and TitanData.Titans[current] then
			local rarity = TitanData.Titans[current].Rarity
			return rarity == "Legendary" or rarity == "Mythical" or rarity == "Transcendent"
		elseif gType == "Clan" then
			if string.find(current, "Awakened") then return true end
			if type(TitanData) == "table" and TitanData.ClanWeights and TitanData.ClanWeights[current] then
				return TitanData.ClanWeights[current] <= 4.0
			end
		end
		return false
	end

	local function PromptConfirmation(message, callback)
		local overlay = Instance.new("Frame", parentFrame.Parent)
		overlay.Size = UDim2.new(1, 0, 1, 0); overlay.BackgroundColor3 = Color3.new(0, 0, 0); overlay.BackgroundTransparency = 0.5; overlay.Active = true; overlay.ZIndex = 100

		local popup, _ = CreateGrimPanel(overlay)
		popup.Size = UDim2.new(0, 400, 0, 200); popup.Position = UDim2.new(0.5, 0, 0.5, 0); popup.AnchorPoint = Vector2.new(0.5, 0.5); popup.BackgroundColor3 = Color3.fromRGB(20, 20, 25); popup.ZIndex = 101
		Instance.new("UICorner", popup).CornerRadius = UDim.new(0, 8)

		local textLabel = CreateSharpLabel(popup, message, UDim2.new(0.9, 0, 0.6, 0), Enum.Font.GothamBold, Color3.new(1, 1, 1), 16); textLabel.Position = UDim2.new(0.05, 0, 0, 10); textLabel.TextWrapped = true; textLabel.ZIndex = 102

		local confirmBtn, cStroke = CreateSharpButton(popup, "YES", UDim2.new(0.4, 0, 0, 45), Enum.Font.GothamBlack, 14); confirmBtn.Position = UDim2.new(0.05, 0, 1, -60); confirmBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40); confirmBtn.ZIndex = 102; cStroke.Color = Color3.fromRGB(255, 100, 100)
		local cancelBtn, caStroke = CreateSharpButton(popup, "CANCEL", UDim2.new(0.4, 0, 0, 45), Enum.Font.GothamBlack, 14); cancelBtn.Position = UDim2.new(0.55, 0, 1, -60); cancelBtn.BackgroundColor3 = Color3.fromRGB(40, 150, 40); cancelBtn.ZIndex = 102; caStroke.Color = Color3.fromRGB(100, 255, 100)

		confirmBtn.MouseButton1Click:Connect(function() overlay:Destroy(); callback(true) end)
		cancelBtn.MouseButton1Click:Connect(function() overlay:Destroy(); callback(false) end)
	end

	local function CreateGachaPanel(gType, order)
		local Panel, _ = CreateGrimPanel(PanelsContainer)
		Panel.Size = UDim2.new(0.48, 0, 0, 520)
		Panel.LayoutOrder = order

		local PTitle = CreateSharpLabel(Panel, (gType == "Titan") and "TITAN INHERITANCE" or "CLAN LINEAGE", UDim2.new(1, 0, 0, 40), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 22)
		local ListContainer = Instance.new("ScrollingFrame", Panel)
		ListContainer.Size = UDim2.new(1, -20, 0, 290)
		ListContainer.Position = UDim2.new(0, 10, 0, 45)
		ListContainer.BackgroundTransparency = 1
		ListContainer.ScrollBarThickness = 6
		ListContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
		ListContainer.BorderSizePixel = 0
		local SList = Instance.new("UIListLayout", ListContainer); SList.Padding = UDim.new(0, 8)

		if gType == "Titan" and type(TitanData) == "table" and TitanData.Titans then
			local sortedTitans = {}
			for tName, tData in pairs(TitanData.Titans) do 
				if tData.Rarity ~= "Transcendent" then table.insert(sortedTitans, tData) end 
			end
			table.sort(sortedTitans, function(a, b) return RarityOrder[a.Rarity] < RarityOrder[b.Rarity] end)
			for _, drop in ipairs(sortedTitans) do
				local cColor = RarityColors[drop.Rarity] or "#FFFFFF"; local rarityRGB = Color3.fromHex(cColor:gsub("#", ""))
				local card = Instance.new("Frame", ListContainer); card.Size = UDim2.new(1, -10, 0, 80); card.BackgroundColor3 = UIHelpers.Colors.Surface; card.BorderSizePixel = 1; card.BorderColor3 = rarityRGB
				local bgGlow = Instance.new("Frame", card); bgGlow.Size = UDim2.new(1, 0, 0.5, 0); bgGlow.Position = UDim2.new(0, 0, 0.5, 0); bgGlow.BackgroundColor3 = rarityRGB; bgGlow.BackgroundTransparency = 0.92; bgGlow.BorderSizePixel = 0; bgGlow.ZIndex = 1
				local countInRarity = 0; for _, t in pairs(TitanData.Titans) do if t.Rarity == drop.Rarity then countInRarity += 1 end end
				local pct = (TitanData.Rarities[drop.Rarity] and (TitanData.Rarities[drop.Rarity] / countInRarity)) or 0; local pctStr = pct > 0 and (" (" .. string.format("%.1f", pct) .. "%)") or " (Fusion Exclusive)"
				local titleLbl = CreateSharpLabel(card, "<b><font color='" .. cColor .. "'>[" .. drop.Rarity .. "] " .. drop.Name .. "</font></b><font color='#888888'>" .. pctStr .. "</font>", UDim2.new(1, -20, 0, 20), Enum.Font.GothamBold, Color3.fromRGB(230, 230, 230), 15); titleLbl.Position = UDim2.new(0, 10, 0, 10); titleLbl.TextXAlignment = Enum.TextXAlignment.Left; titleLbl.RichText = true
				local statsArea = Instance.new("Frame", card); statsArea.Size = UDim2.new(1, -20, 0, 35); statsArea.Position = UDim2.new(0, 10, 0, 35); statsArea.BackgroundTransparency = 1; local saLayout = Instance.new("UIListLayout", statsArea); saLayout.FillDirection = Enum.FillDirection.Horizontal; saLayout.Padding = UDim.new(0, 8)
				local s = drop.Stats; local statsOrder = { {Name="POW", Val=s.Power}, {Name="SPD", Val=s.Speed}, {Name="HRD", Val=s.Hardening}, {Name="END", Val=s.Endurance}, {Name="PRE", Val=s.Precision}, {Name="POT", Val=s.Potential} }
				for _, st in ipairs(statsOrder) do
					local sBox = Instance.new("Frame", statsArea); sBox.Size = UDim2.new(0, 50, 1, 0); sBox.BackgroundColor3 = UIHelpers.Colors.Background; sBox.BorderSizePixel = 1; sBox.BorderColor3 = UIHelpers.Colors.BorderMuted
					local sName = CreateSharpLabel(sBox, st.Name, UDim2.new(1, 0, 0.5, 0), Enum.Font.GothamMedium, UIHelpers.Colors.TextMuted, 9)
					local sVal = CreateSharpLabel(sBox, st.Val, UDim2.new(1, 0, 0.5, 0), Enum.Font.GothamBlack, GetRankColor(st.Val), 14); sVal.Position = UDim2.new(0, 0, 0.5, 0)
				end
			end
			local noticeCard = Instance.new("Frame", ListContainer); noticeCard.Size = UDim2.new(1, -10, 0, 40); noticeCard.BackgroundTransparency = 1
			local noticeLbl = UIHelpers.CreateLabel(noticeCard, "Fusion Variants listed in the Fusion section of the Supply/Forge menu!", UDim2.new(1, 0, 1, 0), Enum.Font.GothamBold, UIHelpers.Colors.Gold, 12); noticeLbl.TextWrapped = true

		elseif type(TitanData) == "table" and TitanData.ClanWeights then
			local sortedClans = {}; for cName, weight in pairs(TitanData.ClanWeights) do table.insert(sortedClans, {Name = cName, Weight = weight}) end
			table.sort(sortedClans, function(a, b) return a.Weight < b.Weight end)
			for _, drop in ipairs(sortedClans) do
				local rarityTag = "Common"; if drop.Weight <= 1.5 then rarityTag = "Mythical" elseif drop.Weight <= 4.0 then rarityTag = "Legendary" elseif drop.Weight <= 8.0 then rarityTag = "Epic" elseif drop.Weight <= 15.0 then rarityTag = "Rare" end
				local cColor = RarityColors[rarityTag] or "#FFFFFF"; local rarityRGB = Color3.fromHex(cColor:gsub("#", "")); local buffText = ClanVisualBuffs[drop.Name] or "Unknown"
				local card = Instance.new("Frame", ListContainer); card.Size = UDim2.new(1, -10, 0, 70); card.BackgroundColor3 = UIHelpers.Colors.Surface; card.BorderSizePixel = 1; card.BorderColor3 = rarityRGB
				local bgGlow = Instance.new("Frame", card); bgGlow.Size = UDim2.new(1, 0, 0.5, 0); bgGlow.Position = UDim2.new(0, 0, 0.5, 0); bgGlow.BackgroundColor3 = rarityRGB; bgGlow.BackgroundTransparency = 0.92; bgGlow.BorderSizePixel = 0; bgGlow.ZIndex = 1
				local pctStr = drop.Weight > 0 and (" (" .. string.format("%.1f", drop.Weight) .. "%)") or " (Awakened Exclusive)"
				local titleLbl = CreateSharpLabel(card, "<b><font color='" .. cColor .. "'>[" .. rarityTag .. "] " .. drop.Name .. "</font></b><font color='#888888'>" .. pctStr .. "</font>", UDim2.new(1, -20, 0, 20), Enum.Font.GothamBold, Color3.fromRGB(230, 230, 230), 15); titleLbl.Position = UDim2.new(0, 10, 0, 10); titleLbl.TextXAlignment = Enum.TextXAlignment.Left; titleLbl.RichText = true
				local descLbl = CreateSharpLabel(card, buffText, UDim2.new(1, -20, 0, 30), Enum.Font.GothamMedium, Color3.fromRGB(150, 255, 150), 12); descLbl.Position = UDim2.new(0, 10, 0, 35); descLbl.TextXAlignment = Enum.TextXAlignment.Left; descLbl.RichText = true
			end
			local noticeCard = Instance.new("Frame", ListContainer); noticeCard.Size = UDim2.new(1, -10, 0, 40); noticeCard.BackgroundTransparency = 1
			local noticeLbl = UIHelpers.CreateLabel(noticeCard, "Abyssal Variants require an Awakened sacrifice at the Altar.", UDim2.new(1, 0, 1, 0), Enum.Font.GothamBold, Color3.fromRGB(255, 100, 100), 12); noticeLbl.TextWrapped = true
		end

		local BottomArea = Instance.new("Frame", Panel)
		BottomArea.Size = UDim2.new(1, 0, 0, 170)
		BottomArea.Position = UDim2.new(0, 0, 1, -180)
		BottomArea.BackgroundTransparency = 1

		local ResultLbl = CreateSharpLabel(BottomArea, "Current: None", UDim2.new(0.6, 0, 0, 30), Enum.Font.GothamBlack, UIHelpers.Colors.TextWhite, 20); ResultLbl.RichText = true; ResultLbl.TextXAlignment = Enum.TextXAlignment.Left; ResultLbl.Position = UDim2.new(0.05, 0, 0, 0)

		if gType == "Titan" or gType == "Clan" then
			local ItemizeBtn, iStroke = CreateSharpButton(BottomArea, "ITEMIZE (100K)", UDim2.new(0.3, 0, 0, 24), Enum.Font.GothamBold, 11)
			ItemizeBtn.Position = UDim2.new(0.95, 0, 0, 3); ItemizeBtn.AnchorPoint = Vector2.new(1, 0); ItemizeBtn.TextColor3 = Color3.fromRGB(255, 100, 100); iStroke.Color = Color3.fromRGB(150, 50, 50)

			ItemizeBtn.MouseButton1Click:Connect(function()
				if isRolling[gType] or isAutoRolling[gType] then return end
				local tName = player:GetAttribute(gType)
				if not tName or tName == "None" then
					if NotificationManager and type(NotificationManager.Show) == "function" then NotificationManager.Show("No " .. gType .. " equipped to itemize!", "Error") end
					return
				end
				Network:WaitForChild("Itemize" .. gType):FireServer("Equipped")
			end)
		end

		local StorageArea = Instance.new("Frame", BottomArea); StorageArea.Size = UDim2.new(0.9, 0, 0, 45); StorageArea.Position = UDim2.new(0.05, 0, 0, 40); StorageArea.BackgroundTransparency = 1
		local sg = Instance.new("UIGridLayout", StorageArea); sg.CellSize = UDim2.new(0.15, 0, 1, 0); sg.CellPadding = UDim2.new(0.02, 0, 0, 0); sg.HorizontalAlignment = Enum.HorizontalAlignment.Center

		local storageBtns = {}
		for i = 1, 6 do
			local sBtn, stroke = CreateSharpButton(StorageArea, "Empty", UDim2.new(1, 0, 1, 0), Enum.Font.GothamBold, 10); sBtn.TextWrapped = true
			sBtn.MouseButton1Click:Connect(function()
				if i > 3 and not player:GetAttribute("Has" .. gType .. "Vault") then
					if NotificationManager and type(NotificationManager.Show) == "function" then NotificationManager.Show("Locked. Requires Vault Expansion Gamepass!", "Error") end
					return
				end
				Network:WaitForChild("ManageStorage"):FireServer(gType, i)
			end)
			storageBtns[i] = { Btn = sBtn, Stroke = stroke }
		end

		local PityLbl = CreateSharpLabel(BottomArea, "PITY: 0 / 100", UDim2.new(1, 0, 0, 20), Enum.Font.GothamBold, Color3.fromRGB(200, 150, 255), 15); PityLbl.Position = UDim2.new(0, 0, 0, 95)
		local RollActions = Instance.new("Frame", BottomArea); RollActions.Size = UDim2.new(0.9, 0, 0, 45); RollActions.Position = UDim2.new(0.05, 0, 0, 120); RollActions.BackgroundTransparency = 1; local raLayout = Instance.new("UIListLayout", RollActions); raLayout.FillDirection = Enum.FillDirection.Horizontal; raLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; raLayout.Padding = UDim.new(0.03, 0)

		local labelPrefix = (gType == "Titan") and "Serum" or "Vial"
		local RollBtn, rStroke = CreateSharpButton(RollActions, "ROLL (1x " .. labelPrefix .. ")", UDim2.new(0.3, 0, 1, 0), Enum.Font.GothamBlack, 11)

		local PremiumRollBtn, pStroke = CreateSharpButton(RollActions, "N/A", UDim2.new(0.3, 0, 1, 0), Enum.Font.GothamBlack, 11)
		PremiumRollBtn.Visible = true
		if gType == "Titan" then 
			PremiumRollBtn.Text = "PREMIUM (1x Syringe)" 
		else 
			PremiumRollBtn.Text = "PREMIUM (1x Leg. Vial)"
		end

		local AutoRollBtn, aStroke = CreateSharpButton(RollActions, "ROLL TILL LEGENDARY+", UDim2.new(0.3, 0, 1, 0), Enum.Font.GothamBlack, 11)

		local attrReq = (gType == "Titan") and "StandardTitanSerumCount" or "ClanBloodVialCount"
		autoRollBtns[gType] = AutoRollBtn

		local function DoRoll(isPremium)
			local countAttr = attrReq
			if isPremium then
				countAttr = (gType == "Titan") and "SpinalFluidSyringeCount" or "LegendaryClanVialCount"
			end

			local count = player:GetAttribute(countAttr) or 0
			if count > 0 then
				isRolling[gType] = true; currentRollSeq[gType] = currentRollSeq[gType] + 1; local seq = currentRollSeq[gType]
				Network:WaitForChild("GachaRoll"):FireServer(gType, isPremium)
				task.delay(5, function() if isRolling[gType] and currentRollSeq[gType] == seq then isRolling[gType] = false; isAutoRolling[gType] = false; ResetAutoRollVisuals(gType) end end) 
			else
				ResultLbl.Text = "<font color='#FF5555'>Not enough items!</font>"; if VFXManager and type(VFXManager.PlaySFX) == "function" then VFXManager.PlaySFX("Error", 1) end
				task.delay(1.5, function() if not isRolling[gType] then ResultLbl.Text = "Current: " .. (player:GetAttribute(gType) or "None") end end)
			end
		end

		RollBtn.MouseButton1Click:Connect(function()
			if isRolling[gType] or isAutoRolling[gType] then return end
			if IsHighTier(gType) then
				PromptConfirmation("You currently have a Legendary+ " .. gType .. ". Are you sure you want to spin it away?", function(confirmed)
					if confirmed then DoRoll(false) end
				end)
			else
				DoRoll(false)
			end
		end)

		PremiumRollBtn.MouseButton1Click:Connect(function()
			if isRolling[gType] or isAutoRolling[gType] then return end
			if IsHighTier(gType) then
				PromptConfirmation("You currently have a Legendary+ " .. gType .. ". Are you sure you want to spin it away?", function(confirmed)
					if confirmed then DoRoll(true) end
				end)
			else
				DoRoll(true)
			end
		end)

		AutoRollBtn.MouseButton1Click:Connect(function()
			if isAutoRolling[gType] then
				isAutoRolling[gType] = false
				ResetAutoRollVisuals(gType)
				return
			end
			if isRolling[gType] then return end

			local function StartAuto()
				local count = player:GetAttribute(attrReq) or 0
				if count > 0 then
					isAutoRolling[gType] = true; isRolling[gType] = true; ResultLbl.Text = "<i>Auto-Rolling...</i>"
					AutoRollBtn.Text = "STOP"
					AutoRollBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
					currentRollSeq[gType] = currentRollSeq[gType] + 1; local seq = currentRollSeq[gType]
					Network:WaitForChild("GachaRoll"):FireServer(gType, false)
					task.delay(5, function() if isRolling[gType] and currentRollSeq[gType] == seq then isRolling[gType] = false; isAutoRolling[gType] = false; ResetAutoRollVisuals(gType) end end)
				else
					ResultLbl.Text = "<font color='#FF5555'>Not enough items!</font>"; if VFXManager and type(VFXManager.PlaySFX) == "function" then VFXManager.PlaySFX("Error", 1) end
					task.delay(1.5, function() if not isRolling[gType] then ResultLbl.Text = "Current: " .. (player:GetAttribute(gType) or "None") end end)
				end
			end

			if IsHighTier(gType) then
				PromptConfirmation("You currently have a Legendary+ " .. gType .. ". Are you sure you want to spin it away?", function(confirmed)
					if confirmed then StartAuto() end
				end)
			else
				StartAuto()
			end
		end)

		return { Panel = Panel, ResultLbl = ResultLbl, PityLbl = PityLbl, RollBtn = RollBtn, PremiumRollBtn = PremiumRollBtn, AutoRollBtn = AutoRollBtn, storageBtns = storageBtns }
	end

	local titanGacha = CreateGachaPanel("Titan", 1)
	local clanGacha = CreateGachaPanel("Clan", 2)

	local function UpdateUI()
		if not isRolling.Titan and not isAutoRolling.Titan then titanGacha.ResultLbl.Text = "Current: " .. (player:GetAttribute("Titan") or "None") end
		if not isRolling.Clan and not isAutoRolling.Clan then clanGacha.ResultLbl.Text = "Current: " .. (player:GetAttribute("Clan") or "None") end

		for i = 1, 6 do
			local tStoreName = player:GetAttribute("Titan_Slot"..i); if not tStoreName or tStoreName == "" then tStoreName = "None" end
			local cStoreName = player:GetAttribute("Clan_Slot"..i); if not cStoreName or cStoreName == "" then cStoreName = "None" end

			local function styleVaultSlot(storeObj, storedName, hasVault, isTitanType, slotIndex)
				local btn = storeObj.Btn
				if slotIndex > 3 and not hasVault then 
					btn.Text = "🔒"; storeObj.Stroke.Color = Color3.fromRGB(80, 40, 40); btn.TextColor3 = Color3.fromRGB(200, 100, 100)
				else 
					btn.Text = (storedName == "None" and "Empty" or storedName)
					if storedName ~= "None" then
						local rarity = "Common"
						if isTitanType then
							local tData = type(TitanData) == "table" and TitanData.Titans and TitanData.Titans[storedName]; if tData then rarity = tData.Rarity end
						else
							if string.find(storedName, "Abyssal") or string.find(storedName, "Awakened") then rarity = "Transcendent"
							else
								local weight = type(TitanData) == "table" and TitanData.ClanWeights and TitanData.ClanWeights[storedName] or 40
								if weight <= 1.5 then rarity = "Mythical" elseif weight <= 4.0 then rarity = "Legendary" elseif weight <= 8.0 then rarity = "Epic" elseif weight <= 15.0 then rarity = "Rare" end
							end
						end
						local cColor = Color3.fromHex((RarityColors[rarity] or "#FFFFFF"):gsub("#","")); storeObj.Stroke.Color = cColor; btn.TextColor3 = Color3.fromRGB(230, 230, 230)
					else storeObj.Stroke.Color = UIHelpers.Colors.BorderMuted; btn.TextColor3 = UIHelpers.Colors.TextMuted end
				end
			end

			styleVaultSlot(titanGacha.storageBtns[i], tStoreName, player:GetAttribute("HasTitanVault"), true, i)
			styleVaultSlot(clanGacha.storageBtns[i], cStoreName, player:GetAttribute("HasClanVault"), false, i)
		end

		titanGacha.PityLbl.Text = "PITY: " .. (player:GetAttribute("TitanPity") or 0) .. " / 100"
		clanGacha.PityLbl.Text = "PITY: " .. (player:GetAttribute("ClanPity") or 0) .. " / 100"
		titanGacha.RollBtn.Text = "ROLL (x" .. (player:GetAttribute("StandardTitanSerumCount") or 0) .. ")"
		clanGacha.RollBtn.Text = "ROLL (x" .. (player:GetAttribute("ClanBloodVialCount") or 0) .. ")"

		if titanGacha.PremiumRollBtn.Visible and titanGacha.PremiumRollBtn.Text:find("PREMIUM") then 
			if titanGacha.PremiumRollBtn.Text:find("Syringe") then
				titanGacha.PremiumRollBtn.Text = "PREMIUM (x" .. (player:GetAttribute("SpinalFluidSyringeCount") or 0) .. ")" 
			else
				clanGacha.PremiumRollBtn.Text = "PREMIUM (x" .. (player:GetAttribute("LegendaryClanVialCount") or 0) .. ")"
			end
		end
	end
	player.AttributeChanged:Connect(UpdateUI); UpdateUI()

	Network:WaitForChild("GachaResult").OnClientEvent:Connect(function(gType, resultName, resultRarity)
		if resultName == "Error" then isRolling[gType] = false; isAutoRolling[gType] = false; ResetAutoRollVisuals(gType); UpdateUI(); if VFXManager and type(VFXManager.PlaySFX) == "function" then VFXManager.PlaySFX("Error", 1) end return end

		local targetLbl = (gType == "Titan") and titanGacha.ResultLbl or clanGacha.ResultLbl
		local names = {}
		if gType == "Titan" and type(TitanData) == "table" and TitanData.Titans then for tName, _ in pairs(TitanData.Titans) do table.insert(names, tName) end 
		elseif type(TitanData) == "table" and TitanData.ClanWeights then for cName, _ in pairs(TitanData.ClanWeights) do table.insert(names, cName) end end

		for i = 1, 20 do 
			if not MainScroll.Visible then break end
			if VFXManager and type(VFXManager.PlaySFX) == "function" then VFXManager.PlaySFX("Click", 1 + (i/20)) end
			if #names > 0 then targetLbl.Text = names[math.random(1, #names)] end
			task.wait(0.05) 
		end

		local cColor = RarityColors[resultRarity] or "#FFFFFF"
		targetLbl.Text = "<b><font color='" .. cColor .. "'>" .. resultName:upper() .. "!</font></b>"
		if MainScroll.Visible and VFXManager and type(VFXManager.PlaySFX) == "function" then VFXManager.PlaySFX("Reveal", 1) end

		if resultRarity == "Mythical" or resultRarity == "Transcendent" then
			local cinemColor = (resultRarity == "Mythical") and "#FF3333" or "#FF55FF"
			local titleText = (gType == "Titan") and "A PRIMORDIAL POWER AWAKENS" or "AN ANCIENT BLOODLINE"
			if CinematicManager and type(CinematicManager.Show) == "function" then CinematicManager.Show(titleText, resultName, cinemColor) end
		end

		task.wait(1.5)

		if isAutoRolling[gType] and MainScroll.Visible then
			if resultRarity == "Legendary" or resultRarity == "Mythical" or resultRarity == "Transcendent" then
				isAutoRolling[gType] = false; isRolling[gType] = false; ResetAutoRollVisuals(gType); UpdateUI()
			else
				local attrReq = (gType == "Titan") and "StandardTitanSerumCount" or "ClanBloodVialCount"
				if (player:GetAttribute(attrReq) or 0) > 0 then
					targetLbl.Text = "<i>Auto-Rolling...</i>"
					currentRollSeq[gType] = currentRollSeq[gType] + 1; local seq = currentRollSeq[gType]
					Network:WaitForChild("GachaRoll"):FireServer(gType, false)
					task.delay(5, function() if isRolling[gType] and currentRollSeq[gType] == seq then isRolling[gType] = false; isAutoRolling[gType] = false; ResetAutoRollVisuals(gType); UpdateUI() end end)
				else
					isAutoRolling[gType] = false; isRolling[gType] = false; ResetAutoRollVisuals(gType); targetLbl.Text = "<font color='#FF5555'>Out of items!</font>"; task.delay(1.5, function() if not isRolling[gType] then UpdateUI() end end)
				end
			end
		else
			isRolling[gType] = false; ResetAutoRollVisuals(gType); UpdateUI()
		end
	end)

	LayoutRefs.Inheritance = {
		pcLayout = pcLayout,
		TitanPanel = titanGacha.Panel,
		ClanPanel = clanGacha.Panel
	}
end

-- ==========================================
-- BOUNTIES TAB
-- ==========================================
local function FormatBountyName(taskType, count)
	if taskType == "Kill" then return "Eliminate " .. count .. " enemies"
	elseif taskType == "Clear" then return "Clear " .. count .. " waves"
	elseif taskType == "Maneuver" then return "Perform " .. count .. " maneuvers"
	elseif taskType == "Transform" then return "Transform into a Titan " .. count .. " times"
	elseif taskType == "Dispatch" then return "Complete " .. count .. " AFK dispatches" end
	return "Complete objective"
end

local function BuildBountiesTab(parentFrame)
	local ScrollContainer = Instance.new("ScrollingFrame", parentFrame)
	ScrollContainer.Size = UDim2.new(1, 0, 1, 0)
	ScrollContainer.BackgroundTransparency = 1
	ScrollContainer.ScrollBarThickness = 6
	ScrollContainer.BorderSizePixel = 0

	local slLayout = Instance.new("UIListLayout", ScrollContainer)
	slLayout.Padding = UDim.new(0, 15)
	slLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local sPad = Instance.new("UIPadding", ScrollContainer)
	sPad.PaddingTop = UDim.new(0, 15)
	sPad.PaddingBottom = UDim.new(0, 20)

	local function CreateBountyCard(bountyId, titlePrefix)
		local card, strk = CreateGrimPanel(ScrollContainer)
		card.Size = UDim2.new(0.95, 0, 0, 80)

		local titleLbl = CreateSharpLabel(card, titlePrefix, UDim2.new(0.6, 0, 0, 25), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 14)
		titleLbl.Position = UDim2.new(0, 15, 0, 10)
		titleLbl.TextXAlignment = Enum.TextXAlignment.Left

		local progBarBG = Instance.new("Frame", card)
		progBarBG.Size = UDim2.new(0.6, 0, 0, 12)
		progBarBG.Position = UDim2.new(0, 15, 0, 45)
		progBarBG.BackgroundColor3 = Color3.fromRGB(10, 10, 12)

		local pbStroke = Instance.new("UIStroke", progBarBG)
		pbStroke.Color = Color3.fromRGB(50, 50, 60)

		local progFill = Instance.new("Frame", progBarBG)
		progFill.Size = UDim2.new(0, 0, 1, 0)
		progFill.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
		progFill.BorderSizePixel = 0

		local progText = CreateSharpLabel(card, "0 / 1", UDim2.new(0.6, 0, 0, 20), Enum.Font.GothamBold, UIHelpers.Colors.TextWhite, 12)
		progText.Position = UDim2.new(0, 15, 0, 60)
		progText.TextXAlignment = Enum.TextXAlignment.Left

		local actionBtn, actStroke = CreateSharpButton(card, "IN PROGRESS", UDim2.new(0, 120, 0, 36), Enum.Font.GothamBlack, 12)
		actionBtn.Position = UDim2.new(1, -15, 0.5, 0)
		actionBtn.AnchorPoint = Vector2.new(1, 0.5)

		local function UpdateCard()
			local task = player:GetAttribute(bountyId .. "_Task") or "Unknown"
			local prog = player:GetAttribute(bountyId .. "_Prog") or 0
			local max = player:GetAttribute(bountyId .. "_Max") or 1
			local claimed = player:GetAttribute(bountyId .. "_Claimed")

			titleLbl.Text = titlePrefix .. ": " .. FormatBountyName(task, max)
			progText.Text = prog .. " / " .. max
			progFill.Size = UDim2.new(math.clamp(prog/max, 0, 1), 0, 1, 0)

			if claimed then 
				actionBtn.Text = "CLAIMED"
				actionBtn.TextColor3 = Color3.fromRGB(100, 100, 100)
				actStroke.Color = Color3.fromRGB(50, 50, 60)
				actionBtn.Active = false
				progFill.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
			elseif prog >= max then 
				actionBtn.Text = "CLAIM"
				actionBtn.TextColor3 = UIHelpers.Colors.Gold
				actStroke.Color = UIHelpers.Colors.Gold
				actionBtn.Active = true
			else 
				actionBtn.Text = "IN PROGRESS"
				actionBtn.TextColor3 = UIHelpers.Colors.TextMuted
				actStroke.Color = Color3.fromRGB(70, 70, 80)
				actionBtn.Active = false 
			end
		end

		actionBtn.MouseButton1Click:Connect(function() 
			if actionBtn.Active and actionBtn.Text == "CLAIM" then 
				Network:WaitForChild("ClaimBounty"):FireServer(bountyId) 
			end 
		end)
		player.AttributeChanged:Connect(function(attr) 
			if string.match(attr, "^" .. bountyId) then UpdateCard() end 
		end)
		UpdateCard()
	end

	CreateBountyCard("D1", "DAILY 1")
	CreateBountyCard("D2", "DAILY 2")
	CreateBountyCard("D3", "DAILY 3")
	CreateBountyCard("W1", "WEEKLY CHALLENGE")
end

-- ==========================================
-- DYNAMIC LAYOUT LISTENER
-- ==========================================
local function UpdateLayoutForScreen()
	local vp = camera.ViewportSize
	if vp.X == 0 or vp.Y == 0 then return end

	local isMobile = (vp.X <= 850) or (vp.Y > vp.X)

	-- Identity Tab
	if LayoutRefs.Identity then
		local ir = LayoutRefs.Identity
		if ir.cwLayout then ir.cwLayout.FillDirection = isMobile and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal end
		if ir.ShowcaseCard then ir.ShowcaseCard.Size = isMobile and UDim2.new(0.95, 0, 0, 380) or UDim2.new(0.31, 0, 0, 430) end
		if ir.MidCol then ir.MidCol.Size = isMobile and UDim2.new(0.95, 0, 0, 430) or UDim2.new(0.31, 0, 0, 430) end
		if ir.TabsWrapper then ir.TabsWrapper.Size = isMobile and UDim2.new(0.95, 0, 0, 400) or UDim2.new(0.32, 0, 0, 430) end

		if ir.RegIcon then
			if isMobile then
				ir.RegIcon.Size = UDim2.new(0, 80, 0, 80)
				ir.RegIcon.Position = UDim2.new(0.5, 0, 0, 210)
				ir.RegIcon.AnchorPoint = Vector2.new(0.5, 0)
				if ir.PlayerNameLbl then ir.PlayerNameLbl.Position = UDim2.new(0, 0, 0, 310) end
			else
				ir.RegIcon.Size = UDim2.new(0, 80, 0, 80)
				ir.RegIcon.Position = UDim2.new(0, 15, 0, 15)
				ir.RegIcon.AnchorPoint = Vector2.new(0, 0)
				if ir.PlayerNameLbl then ir.PlayerNameLbl.Position = UDim2.new(0, 0, 0, 210) end
			end
		end
	end

	-- Attributes Tab
	if LayoutRefs.Attributes then
		local ar = LayoutRefs.Attributes
		if ar.ccLayout then ar.ccLayout.FillDirection = isMobile and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal end
		if ar.SoldierPanel then ar.SoldierPanel.Size = isMobile and UDim2.new(0.95, 0, 0, 0) or UDim2.new(0.48, 0, 0, 0) end
		if ar.TitanPanel then ar.TitanPanel.Size = isMobile and UDim2.new(0.95, 0, 0, 0) or UDim2.new(0.48, 0, 0, 0) end
	end

	-- Skills Tab
	if LayoutRefs.Skills then
		local sr = LayoutRefs.Skills
		if sr.HeaderContainer then sr.HeaderContainer.Size = isMobile and UDim2.new(0.95, 0, 0, 150) or UDim2.new(0.95, 0, 0, 100) end
		if sr.TopLoadoutGrid then sr.TopLoadoutGrid.Size = isMobile and UDim2.new(1, 0, 0, 110) or UDim2.new(1, 0, 0, 55) end
		if sr.TopLoadoutLayout then sr.TopLoadoutLayout.CellSize = isMobile and UDim2.new(0.48, 0, 0, 50) or UDim2.new(0.23, 0, 0, 50) end

		if sr.LibraryGrids then
			for _, grid in ipairs(sr.LibraryGrids) do
				grid.CellSize = isMobile and UDim2.new(0.95, 0, 0, 180) or UDim2.new(0.31, 0, 0, 180)
				grid.CellPadding = isMobile and UDim2.new(0, 0, 0, 15) or UDim2.new(0.02, 0, 0, 15)
			end
		end
	end

	-- Prestige Tab explicitly decoupled from UIListLayout so it side-by-sides properly on PC
	if LayoutRefs.Prestige then
		local pr = LayoutRefs.Prestige
		if pr.LeftPanel then 
			pr.LeftPanel.Size = isMobile and UDim2.new(1, -30, 0, 320) or UDim2.new(0.32, 0, 1, -30)
			pr.LeftPanel.Position = isMobile and UDim2.new(0, 15, 0, 15) or UDim2.new(0, 15, 0, 15)
		end
		if pr.RightPanel then 
			pr.RightPanel.Size = isMobile and UDim2.new(1, -30, 0, 500) or UDim2.new(0.66, 0, 1, -30) 
			pr.RightPanel.Position = isMobile and UDim2.new(0, 15, 0, 350) or UDim2.new(1, -15, 0, 15)
		end
	end

	-- Inheritance Tab
	if LayoutRefs.Inheritance then
		local hr = LayoutRefs.Inheritance
		if hr.pcLayout then hr.pcLayout.FillDirection = isMobile and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal end
		if hr.TitanPanel then hr.TitanPanel.Size = isMobile and UDim2.new(0.95, 0, 0, 520) or UDim2.new(0.48, 0, 0, 520) end
		if hr.ClanPanel then hr.ClanPanel.Size = isMobile and UDim2.new(0.95, 0, 0, 520) or UDim2.new(0.48, 0, 0, 520) end
	end
end

-- ==========================================
-- INITIALIZATION / ROUTER
-- ==========================================
function HeroMenu.Initialize(parentFrame)
	local pSubNav = Instance.new("ScrollingFrame", parentFrame)
	pSubNav.Size = UDim2.new(1, 0, 0, 45)
	pSubNav.BackgroundTransparency = 1
	pSubNav.ScrollBarThickness = 0
	pSubNav.ScrollingDirection = Enum.ScrollingDirection.X

	local pNavLayout = Instance.new("UIListLayout", pSubNav)
	pNavLayout.FillDirection = Enum.FillDirection.Horizontal
	pNavLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	pNavLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	pNavLayout.Padding = UDim.new(0, 10)

	pNavLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() 
		pSubNav.CanvasSize = UDim2.new(0, pNavLayout.AbsoluteContentSize.X + 20, 0, 0) 
	end)

	local pContent = Instance.new("Frame", parentFrame)
	pContent.Size = UDim2.new(1, 0, 1, -45)
	pContent.Position = UDim2.new(0, 0, 0, 45)
	pContent.BackgroundTransparency = 1

	local subTabs = {"IDENTITY", "ATTRIBUTES", "SKILLS", "PRESTIGE", "INHERITANCE", "BOUNTIES"}
	local activeSubFrames = {}
	local subBtns = {}

	for i, tabName in ipairs(subTabs) do
		local btn = Instance.new("TextButton", pSubNav)
		btn.Size = UDim2.new(0, 105, 0, 30)
		btn.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
		btn.Font = Enum.Font.GothamBold
		btn.Text = tabName
		btn.TextSize = 11
		btn.TextColor3 = UIHelpers.Colors.TextMuted

		local stroke = Instance.new("UIStroke", btn)
		stroke.Color = UIHelpers.Colors.BorderMuted
		stroke.Thickness = 2

		local subFrame = Instance.new("Frame", pContent)
		subFrame.Size = UDim2.new(1, 0, 1, 0)
		subFrame.BackgroundTransparency = 1
		subFrame.Visible = (i == 1)

		activeSubFrames[tabName] = subFrame
		subBtns[tabName] = {Btn = btn, Stroke = stroke}

		btn.MouseButton1Click:Connect(function()
			for name, frame in pairs(activeSubFrames) do frame.Visible = (name == tabName) end
			for name, bData in pairs(subBtns) do
				bData.Btn.TextColor3 = (name == tabName) and UIHelpers.Colors.Gold or UIHelpers.Colors.TextMuted
				bData.Stroke.Color = (name == tabName) and UIHelpers.Colors.Gold or UIHelpers.Colors.BorderMuted
			end
		end)
	end

	subBtns["IDENTITY"].Btn.TextColor3 = UIHelpers.Colors.Gold
	subBtns["IDENTITY"].Stroke.Color = UIHelpers.Colors.Gold

	BuildIdentityTab(activeSubFrames["IDENTITY"])
	BuildAttributesTab(activeSubFrames["ATTRIBUTES"])
	BuildSkillsTab(activeSubFrames["SKILLS"])
	BuildPrestigeTab(activeSubFrames["PRESTIGE"])
	BuildInheritanceTab(activeSubFrames["INHERITANCE"])
	BuildBountiesTab(activeSubFrames["BOUNTIES"])

	camera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateLayoutForScreen)
	UpdateLayoutForScreen()
end

return HeroMenu