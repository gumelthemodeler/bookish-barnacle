-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
-- Name: NotificationManager
local NotificationManager = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local UIHelpers = require(script.Parent:WaitForChild("UIHelpers"))

local NotifGui = PlayerGui:FindFirstChild("NotificationGui")
if not NotifGui then
	NotifGui = Instance.new("ScreenGui")
	NotifGui.Name = "NotificationGui"
	NotifGui.ResetOnSpawn = false
	NotifGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	NotifGui.Parent = PlayerGui
end

local Container = NotifGui:FindFirstChild("NotifContainer")
if not Container then
	Container = Instance.new("Frame")
	Container.Name = "NotifContainer"
	Container.Size = UDim2.new(0, 300, 0.6, 0)
	Container.Position = UDim2.new(1, -20, 0.5, 0)
	Container.AnchorPoint = Vector2.new(1, 0.5)
	Container.BackgroundTransparency = 1
	Container.Parent = NotifGui

	local layout = Instance.new("UIListLayout", Container)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, 10)
end

local Colors = {
	Success = Color3.fromRGB(85, 255, 85),
	Error = Color3.fromRGB(255, 85, 85),
	Warning = Color3.fromRGB(255, 170, 0),
	Info = Color3.fromRGB(85, 170, 255),
	Loot = Color3.fromRGB(255, 215, 0),
	System = Color3.fromRGB(200, 200, 200)
}

function NotificationManager.Show(message, notifType, duration)
	notifType = notifType or "Info"
	duration = duration or 4.0

	local baseColor = Colors[notifType] or Colors.Info

	local notifFrame = Instance.new("Frame")
	notifFrame.Size = UDim2.new(1, 0, 0, 0)
	notifFrame.AutomaticSize = Enum.AutomaticSize.Y
	notifFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	notifFrame.BackgroundTransparency = 1
	notifFrame.BorderSizePixel = 0
	notifFrame.Parent = Container

	local stroke = Instance.new("UIStroke", notifFrame)
	stroke.Color = baseColor
	stroke.Thickness = 2
	stroke.Transparency = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	local pad = Instance.new("UIPadding", notifFrame)
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 15)
	pad.PaddingRight = UDim.new(0, 15)

	local titleLbl = UIHelpers.CreateLabel(notifFrame, string.upper(notifType), UDim2.new(1, 0, 0, 16), Enum.Font.GothamBlack, baseColor, 14)
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.TextTransparency = 1

	local msgLbl = UIHelpers.CreateLabel(notifFrame, message, UDim2.new(1, 0, 0, 0), Enum.Font.GothamMedium, Color3.fromRGB(240, 240, 240), 13)
	msgLbl.Position = UDim2.new(0, 0, 0, 20)
	msgLbl.TextXAlignment = Enum.TextXAlignment.Left
	msgLbl.TextWrapped = true
	msgLbl.AutomaticSize = Enum.AutomaticSize.Y
	msgLbl.TextTransparency = 1

	TweenService:Create(notifFrame, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {BackgroundTransparency = 0.1}):Play()
	TweenService:Create(stroke, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Transparency = 0}):Play()
	TweenService:Create(titleLbl, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
	TweenService:Create(msgLbl, TweenInfo.new(0.3), {TextTransparency = 0}):Play()

	task.delay(duration, function()
		TweenService:Create(notifFrame, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
		TweenService:Create(titleLbl, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
		local t = TweenService:Create(msgLbl, TweenInfo.new(0.3), {TextTransparency = 1})
		t:Play()
		t.Completed:Wait()
		notifFrame:Destroy()
	end)
end

task.spawn(function()
	local Network = ReplicatedStorage:WaitForChild("Network", 10)
	if Network then
		local NotifEvent = Network:WaitForChild("NotificationEvent", 10)
		if NotifEvent then
			NotifEvent.OnClientEvent:Connect(function(msg, nType)
				NotificationManager.Show(msg, nType)
			end)
		end
	end
end)

return NotificationManager