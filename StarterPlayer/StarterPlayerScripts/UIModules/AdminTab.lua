-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
-- Name: AdminTab
local AdminTab = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = ReplicatedStorage:WaitForChild("Network")

local SharedUI = script.Parent.Parent:WaitForChild("SharedUI")
local UIHelpers = require(SharedUI:WaitForChild("UIHelpers"))

local player = Players.LocalPlayer
local selectedPlayerName = nil
local playerBtns = {}

local AdminCommand = Network:WaitForChild("AdminCommand")

local CONFIG = {
	Categories = {
		{
			Title = "CURRENCIES", Color = "#FFD700",
			Actions = {
				{Name = "Set Dews", Placeholders = {"Amount"}, BtnText = "SET", Cmd = "SetDews"},
				{Name = "Set Player XP", Placeholders = {"Amount"}, BtnText = "SET", Cmd = "SetXP"},
				{Name = "Set Titan XP", Placeholders = {"Amount"}, BtnText = "SET", Cmd = "SetTitanXP"},
				{Name = "Set Prestige", Placeholders = {"Amount"}, BtnText = "SET", Cmd = "SetPrestige"},
				{Name = "Set Elo Rating", Placeholders = {"Amount"}, BtnText = "SET", Cmd = "SetElo"}
			}
		},
		{
			Title = "BASE STATS", Color = "#55FF55",
			Actions = {
				{Name = "Set Health", Placeholders = {"Value"}, BtnText = "SET", Cmd = "SetHealth"},
				{Name = "Set Gas Cap", Placeholders = {"Value"}, BtnText = "SET", Cmd = "SetGas"},
				{Name = "Set Strength", Placeholders = {"Value"}, BtnText = "SET", Cmd = "SetStrength"},
				{Name = "Set Defense", Placeholders = {"Value"}, BtnText = "SET", Cmd = "SetDefense"},
				{Name = "Set Speed", Placeholders = {"Value"}, BtnText = "SET", Cmd = "SetSpeed"},
				{Name = "Set Resolve", Placeholders = {"Value"}, BtnText = "SET", Cmd = "SetResolve"}
			}
		},
		{
			Title = "LOADOUT & INVENTORY", Color = "#55AAFF",
			Actions = {
				{Name = "Give Item/Material", Placeholders = {"Item Name", "Amount"}, BtnText = "GIVE", Cmd = "GiveItem"},
				{Name = "Force Equip Weapon", Placeholders = {"Weapon Name"}, BtnText = "EQUIP", Cmd = "EquipWeapon"},
				{Name = "Force Equip Accessory", Placeholders = {"Accessory Name"}, BtnText = "EQUIP", Cmd = "EquipAccessory"},
				{Name = "Force Equip Skill", Placeholders = {"Slot (1-4)", "Skill Name"}, BtnText = "EQUIP", Cmd = "EquipSkill"}
			}
		},
		{
			Title = "PROGRESSION", Color = "#FF88FF",
			Actions = {
				{Name = "Set Story Part", Placeholders = {"Part #"}, BtnText = "SET", Cmd = "SetStoryPart"},
				{Name = "Set Mission", Placeholders = {"Mission #"}, BtnText = "SET", Cmd = "SetMission"},
			}
		},
		{
			Title = "IDENTITY & BUFFS", Color = "#FF5555",
			Actions = {
				{Name = "Unlock Title", Placeholders = {"Title Name"}, BtnText = "UNLOCK", Cmd = "GiveTitle"},
				{Name = "Set Lineage (Clan)", Placeholders = {"Clan Name"}, BtnText = "SET", Cmd = "SetClan"},
				{Name = "Set Titan Shifter", Placeholders = {"Titan Name"}, BtnText = "SET", Cmd = "SetTitan"},
				{Name = "Grant VIP Status", Placeholders = {"True/False"}, BtnText = "SET", Cmd = "SetVIP"},
			}
		},
		{
			Title = "DANGER ZONE", Color = "#FF0000",
			Actions = {
				{Name = "Wipe Data", Placeholders = {}, BtnText = "WIPE PROFILE", Cmd = "WipePlayer"}
			}
		}
	}
}

local function CreateInputBox(parent, placeholder, size)
	local box = Instance.new("TextBox", parent)
	box.Size = size
	box.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
	box.BorderSizePixel = 0
	box.Font = Enum.Font.GothamMedium
	box.TextSize = 13
	box.TextColor3 = Color3.fromRGB(255, 255, 255)
	box.PlaceholderText = placeholder
	box.PlaceholderColor3 = Color3.fromRGB(100, 100, 110)
	box.Text = ""
	box.ClearTextOnFocus = false

	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
	local stroke = Instance.new("UIStroke", box)
	stroke.Color = Color3.fromRGB(45, 45, 50)
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	box.Focused:Connect(function() stroke.Color = UIHelpers.Colors.Gold end)
	box.FocusLost:Connect(function() stroke.Color = Color3.fromRGB(45, 45, 50) end)

	return box
end

function AdminTab.Initialize(parentFrame)
	local MainFrame = Instance.new("Frame", parentFrame)
	MainFrame.Name = "AdminFrame"
	MainFrame.Size = UDim2.new(1, 0, 1, 0)
	MainFrame.BackgroundTransparency = 1

	local Header = UIHelpers.CreateLabel(MainFrame, "DEVELOPER OVERRIDE PANEL", UDim2.new(1, 0, 0, 40), Enum.Font.GothamBlack, Color3.fromRGB(255, 85, 85), 24)
	Header.Position = UDim2.new(0, 0, 0, 10)

	local SplitFrame = Instance.new("Frame", MainFrame)
	SplitFrame.Size = UDim2.new(1, -40, 1, -70)
	SplitFrame.Position = UDim2.new(0, 20, 0, 50)
	SplitFrame.BackgroundTransparency = 1
	local splitLayout = Instance.new("UIListLayout", SplitFrame); splitLayout.FillDirection = Enum.FillDirection.Horizontal; splitLayout.Padding = UDim.new(0, 20)

	-- ==========================================
	-- LEFT SIDE: PLAYER LIST
	-- ==========================================
	local LeftPanel = Instance.new("Frame", SplitFrame)
	LeftPanel.Size = UDim2.new(0.25, 0, 1, 0)
	LeftPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	Instance.new("UIStroke", LeftPanel).Color = Color3.fromRGB(45, 45, 50)
	Instance.new("UICorner", LeftPanel).CornerRadius = UDim.new(0, 6)

	local ListTitle = UIHelpers.CreateLabel(LeftPanel, "SERVER PLAYERS", UDim2.new(1, 0, 0, 30), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 16)
	ListTitle.Position = UDim2.new(0, 0, 0, 10)

	local PlayerScroll = Instance.new("ScrollingFrame", LeftPanel)
	PlayerScroll.Size = UDim2.new(1, -10, 1, -50)
	PlayerScroll.Position = UDim2.new(0, 5, 0, 45)
	PlayerScroll.BackgroundTransparency = 1
	PlayerScroll.ScrollBarThickness = 4
	PlayerScroll.BorderSizePixel = 0

	local plLayout = Instance.new("UIListLayout", PlayerScroll)
	plLayout.Padding = UDim.new(0, 5)
	plLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	-- ==========================================
	-- RIGHT SIDE: ACTIONS
	-- ==========================================
	local RightPanel = Instance.new("Frame", SplitFrame)
	RightPanel.Size = UDim2.new(0.75, -20, 1, 0)
	RightPanel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	Instance.new("UIStroke", RightPanel).Color = Color3.fromRGB(45, 45, 50)
	Instance.new("UICorner", RightPanel).CornerRadius = UDim.new(0, 6)

	local ActionTitle = UIHelpers.CreateLabel(RightPanel, "SELECT A PLAYER", UDim2.new(1, -40, 0, 30), Enum.Font.GothamBlack, Color3.fromRGB(255, 255, 255), 20)
	ActionTitle.Position = UDim2.new(0, 20, 0, 10)
	ActionTitle.TextXAlignment = Enum.TextXAlignment.Left

	local ActionScroll = Instance.new("ScrollingFrame", RightPanel)
	ActionScroll.Size = UDim2.new(1, -20, 1, -50)
	ActionScroll.Position = UDim2.new(0, 10, 0, 45)
	ActionScroll.BackgroundTransparency = 1
	ActionScroll.ScrollBarThickness = 6
	ActionScroll.BorderSizePixel = 0

	local acLayout = Instance.new("UIListLayout", ActionScroll)
	acLayout.Padding = UDim.new(0, 15)
	acLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local function CreateActionRow(actionData, hexColor)
		local row = Instance.new("Frame", ActionScroll)
		row.Size = UDim2.new(1, -20, 0, 40)
		row.BackgroundTransparency = 1

		local lbl = UIHelpers.CreateLabel(row, actionData.Name, UDim2.new(0, 160, 1, 0), Enum.Font.GothamBold, UIHelpers.Colors.TextWhite, 14)
		lbl.TextXAlignment = Enum.TextXAlignment.Left

		local layout = Instance.new("UIListLayout", row)
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0, 10)

		local inputBoxes = {}
		for _, placeholder in ipairs(actionData.Placeholders) do
			local box = CreateInputBox(row, placeholder, UDim2.new(0, 150, 0, 30))
			table.insert(inputBoxes, box)
		end

		local btnColor = hexColor
		if actionData.Color then btnColor = actionData.Color end

		local btn, stroke = UIHelpers.CreateButton(row, actionData.BtnText, UDim2.new(0, 120, 0, 30), Enum.Font.GothamBlack, 12)
		btn.TextColor3 = Color3.fromHex(btnColor:gsub("#", ""))
		stroke.Color = Color3.fromHex(btnColor:gsub("#", ""))

		btn.MouseButton1Click:Connect(function()
			if not selectedPlayerName then return end
			local args = {}
			for _, box in ipairs(inputBoxes) do table.insert(args, box.Text) end
			AdminCommand:FireServer(actionData.Cmd, selectedPlayerName, unpack(args))
		end)
	end

	for _, category in ipairs(CONFIG.Categories) do
		local catTitle = UIHelpers.CreateLabel(ActionScroll, category.Title, UDim2.new(1, -20, 0, 30), Enum.Font.GothamBlack, Color3.fromHex(category.Color:gsub("#","")), 18)
		catTitle.TextXAlignment = Enum.TextXAlignment.Left

		for _, act in ipairs(category.Actions) do
			CreateActionRow(act, category.Color)
		end

		local spacer = Instance.new("Frame", ActionScroll)
		spacer.Size = UDim2.new(1, -20, 0, 5)
		spacer.BackgroundTransparency = 1
	end

	acLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() ActionScroll.CanvasSize = UDim2.new(0, 0, 0, acLayout.AbsoluteContentSize.Y + 10) end)

	local function RefreshPlayerList()
		for _, btn in pairs(playerBtns) do btn:Destroy() end
		playerBtns = {}

		for _, p in ipairs(Players:GetPlayers()) do
			local pBtn, pStroke = UIHelpers.CreateButton(PlayerScroll, p.Name, UDim2.new(1, -10, 0, 35), Enum.Font.GothamBold, 14)

			if selectedPlayerName == p.Name then
				pBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
				pStroke.Color = UIHelpers.Colors.Gold
			end

			pBtn.MouseButton1Click:Connect(function()
				selectedPlayerName = p.Name
				ActionTitle.Text = "TARGET: " .. p.Name:upper()
				RefreshPlayerList() 
			end)
			table.insert(playerBtns, pBtn)
		end
		PlayerScroll.CanvasSize = UDim2.new(0, 0, 0, plLayout.AbsoluteContentSize.Y + 10)
	end

	Players.PlayerAdded:Connect(RefreshPlayerList)
	Players.PlayerRemoving:Connect(function(p)
		if selectedPlayerName == p.Name then
			selectedPlayerName = nil
			ActionTitle.Text = "SELECT A PLAYER"
		end
		RefreshPlayerList()
	end)

	RefreshPlayerList()
end

return AdminTab