-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
-- Name: SettingsTab
local SettingsTab = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Network = ReplicatedStorage:WaitForChild("Network")

local player = Players.LocalPlayer
local playerScripts = player:WaitForChild("PlayerScripts")
local SharedUI = playerScripts:WaitForChild("SharedUI")
local UIHelpers = require(SharedUI:WaitForChild("UIHelpers"))

-- Establish defaults on boot if they don't exist
if player:GetAttribute("Setting_ScreenFlash") == nil then player:SetAttribute("Setting_ScreenFlash", true) end
if player:GetAttribute("Setting_Music") == nil then player:SetAttribute("Setting_Music", true) end
if player:GetAttribute("Setting_AutoTrain") == nil then player:SetAttribute("Setting_AutoTrain", false) end

local function CreateGrimPanel(parent)
	local frame = Instance.new("Frame", parent)
	frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	frame.BorderSizePixel = 0
	local stroke = Instance.new("UIStroke", frame)
	stroke.Color = Color3.fromRGB(70, 70, 80); stroke.Thickness = 2; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return frame, stroke
end

local function CreateToggleCard(parent, title, desc, attributeName)
	local card, strk = CreateGrimPanel(parent)
	card.Size = UDim2.new(0.95, 0, 0, 70)

	local titleLbl = UIHelpers.CreateLabel(card, title, UDim2.new(0.7, 0, 0, 25), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 18)
	titleLbl.Position = UDim2.new(0, 15, 0, 10); titleLbl.TextXAlignment = Enum.TextXAlignment.Left

	local descLbl = UIHelpers.CreateLabel(card, desc, UDim2.new(0.7, 0, 0, 20), Enum.Font.GothamBold, UIHelpers.Colors.TextMuted, 12)
	descLbl.Position = UDim2.new(0, 15, 0, 35); descLbl.TextXAlignment = Enum.TextXAlignment.Left

	local ToggleBtn = Instance.new("TextButton", card)
	ToggleBtn.Size = UDim2.new(0, 100, 0, 40)
	ToggleBtn.Position = UDim2.new(1, -15, 0.5, 0)
	ToggleBtn.AnchorPoint = Vector2.new(1, 0.5)
	ToggleBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	ToggleBtn.BorderSizePixel = 0
	ToggleBtn.Font = Enum.Font.GothamBlack
	ToggleBtn.TextSize = 14
	ToggleBtn.AutoButtonColor = false

	local btnStroke = Instance.new("UIStroke", ToggleBtn)
	btnStroke.Thickness = 2; btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	local function UpdateVisuals()
		local isOn = player:GetAttribute(attributeName)
		if isOn then
			ToggleBtn.Text = "ON"
			ToggleBtn.TextColor3 = Color3.fromRGB(85, 255, 85)
			btnStroke.Color = Color3.fromRGB(85, 255, 85)
		else
			ToggleBtn.Text = "OFF"
			ToggleBtn.TextColor3 = Color3.fromRGB(255, 85, 85)
			btnStroke.Color = Color3.fromRGB(255, 85, 85)
		end
	end

	ToggleBtn.MouseButton1Click:Connect(function()
		local currentState = player:GetAttribute(attributeName)
		player:SetAttribute(attributeName, not currentState)
		UpdateVisuals()
	end)

	UpdateVisuals()
	return card
end

function SettingsTab.Initialize(parentFrame)
	for _, child in ipairs(parentFrame:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end

	local Header = UIHelpers.CreateLabel(parentFrame, "SYSTEM CONFIGURATION", UDim2.new(1, 0, 0, 50), Enum.Font.GothamBlack, UIHelpers.Colors.TextWhite, 24)
	Header.Position = UDim2.new(0, 20, 0, 10); Header.TextXAlignment = Enum.TextXAlignment.Left

	local ScrollList = Instance.new("ScrollingFrame", parentFrame)
	ScrollList.Size = UDim2.new(1, -20, 1, -80)
	ScrollList.Position = UDim2.new(0, 10, 0, 70)
	ScrollList.BackgroundTransparency = 1
	ScrollList.ScrollBarThickness = 4
	ScrollList.BorderSizePixel = 0
	ScrollList.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local layout = Instance.new("UIListLayout", ScrollList)
	layout.Padding = UDim.new(0, 10)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	CreateToggleCard(ScrollList, "SCREEN FLASH EFFECTS", "Toggles intense visual flashes and screen shakes during combat.", "Setting_ScreenFlash")
	CreateToggleCard(ScrollList, "BACKGROUND MUSIC", "Toggles region and combat background music.", "Setting_Music")
	CreateToggleCard(ScrollList, "AUTO TRAIN", "Automatically performs your base training action while AFK.", "Setting_AutoTrain")

	-- [[ AUTO TRAIN BACKGROUND LOOP ]]
	if not _G.AutoTrainLoopActive then
		_G.AutoTrainLoopActive = true
		task.spawn(function()
			-- Note: Update "TrainAction" to your exact training remote if named differently
			local trainRemote = Network:FindFirstChild("TrainAction") or Network:FindFirstChild("CombatAction") 
			while true do
				task.wait(1.0) -- Adjust to your game's intended auto-train speed
				if player:GetAttribute("Setting_AutoTrain") and trainRemote then
					trainRemote:FireServer("Train") 
				end
			end
		end)
	end
end

return SettingsTab