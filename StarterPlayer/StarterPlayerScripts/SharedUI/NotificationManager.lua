-- @ScriptType: ModuleScript
-- Name: NotificationManager
-- @ScriptType: ModuleScript
local NotificationManager = {}

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NotifGui = nil
local Container = nil

local CONFIG = {
	Colors = {
		Success = Color3.fromRGB(85, 255, 85),
		Error = Color3.fromRGB(255, 85, 85),
		Info = Color3.fromRGB(85, 170, 255),
		Loot = Color3.fromRGB(255, 215, 0),
		System = Color3.fromRGB(200, 150, 255),
		Warning = Color3.fromRGB(255, 170, 0)
	},
	Icons = {
		Success = "✅",
		Error = "❌",
		Info = "ℹ️",
		Loot = "📦",
		System = "⚙️",
		Warning = "⚠️"
	}
}

function NotificationManager.Initialize()
	if NotifGui then return end

	local player = Players.LocalPlayer
	if not player then return end

	NotifGui = Instance.new("ScreenGui")
	NotifGui.Name = "NotificationFeed"
	NotifGui.DisplayOrder = 1000 
	NotifGui.Parent = player:WaitForChild("PlayerGui")

	Container = Instance.new("Frame", NotifGui)
	Container.Size = UDim2.new(0, 300, 1, -40)
	Container.Position = UDim2.new(1, -320, 0, 20)
	Container.BackgroundTransparency = 1

	local layout = Instance.new("UIListLayout", Container)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, 10)

	-- Automatically hook to the server's notification event
	task.spawn(function()
		local Network = ReplicatedStorage:WaitForChild("Network")
		local notifEvent = Network:WaitForChild("NotificationEvent")
		notifEvent.OnClientEvent:Connect(function(msg, msgType)
			NotificationManager.Show(msg, msgType)
		end)
	end)
end

function NotificationManager.Show(message, msgType)
	if not Container then NotificationManager.Initialize() end
	if not Container then return end 

	local color = CONFIG.Colors[msgType] or CONFIG.Colors.Info
	local icon = CONFIG.Icons[msgType] or CONFIG.Icons.Info

	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 50)
	card.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	card.Position = UDim2.new(1, 50, 0, 0) 
	card.BackgroundTransparency = 0.1

	local stroke = Instance.new("UIStroke", card)
	stroke.Color = color
	stroke.Thickness = 2

	local corner = Instance.new("UICorner", card)
	corner.CornerRadius = UDim.new(0, 4)

	local iconLbl = Instance.new("TextLabel", card)
	iconLbl.Size = UDim2.new(0, 40, 1, 0)
	iconLbl.BackgroundTransparency = 1
	iconLbl.Font = Enum.Font.GothamBlack
	iconLbl.Text = icon
	iconLbl.TextSize = 18
	iconLbl.TextColor3 = color

	local txtLbl = Instance.new("TextLabel", card)
	txtLbl.Size = UDim2.new(1, -50, 1, 0)
	txtLbl.Position = UDim2.new(0, 40, 0, 0)
	txtLbl.BackgroundTransparency = 1
	txtLbl.Font = Enum.Font.GothamBold
	txtLbl.Text = message
	txtLbl.TextSize = 12
	txtLbl.TextColor3 = Color3.fromRGB(245, 245, 245)
	txtLbl.TextXAlignment = Enum.TextXAlignment.Left
	txtLbl.TextWrapped = true
	txtLbl.RichText = true

	-- Dynamically scale height based on text length
	local textBounds = game:GetService("TextService"):GetTextSize(message, 12, Enum.Font.GothamBold, Vector2.new(250, 999))
	card.Size = UDim2.new(1, 0, 0, math.max(50, textBounds.Y + 20))

	card.Parent = Container

	-- Slide In Animation
	TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play()

	-- Wait 4.5s, Slide Out, and Destroy
	task.delay(4.5, function()
		if not card.Parent then return end
		local t = TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(1, 50, 0, 0), BackgroundTransparency = 1})
		TweenService:Create(txtLbl, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
		TweenService:Create(iconLbl, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.4), {Transparency = 1}):Play()

		t:Play()
		t.Completed:Wait()
		card:Destroy()
	end)
end

-- Auto-initialize if running on the client
if RunService:IsClient() then
	task.spawn(NotificationManager.Initialize)
end

return NotificationManager