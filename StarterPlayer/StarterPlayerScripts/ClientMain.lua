-- @ScriptType: LocalScript
-- @ScriptType: LocalScript
-- Name: ClientMain
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local playerScripts = player:WaitForChild("PlayerScripts")

-- Disable default Roblox UI except Chat
task.spawn(function()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
	end)
end)

local MasterGui = Instance.new("ScreenGui")
MasterGui.Name = "AoTMasterGui"
MasterGui.ResetOnSpawn = false
MasterGui.IgnoreGuiInset = true
MasterGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling 
MasterGui.Parent = playerGui

-- ==========================================
-- LOADING SCREEN SEQUENCER
-- ==========================================
local LoadScreen = Instance.new("Frame", MasterGui)
LoadScreen.Size = UDim2.new(1, 0, 1, 0)
LoadScreen.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
LoadScreen.ZIndex = 9999 

local Background = Instance.new("ImageLabel", LoadScreen)
Background.Size = UDim2.new(1, 0, 1, 0)
Background.BackgroundTransparency = 1
Background.Image = "rbxassetid://125800917140688" 
Background.ScaleType = Enum.ScaleType.Crop
Background.ImageTransparency = 0.3
Background.ZIndex = 10000

local FloatingTitleImage = Instance.new("ImageLabel", LoadScreen)
FloatingTitleImage.Size = UDim2.new(0, 800, 0, 240)
FloatingTitleImage.Position = UDim2.new(0.5, 0, 0.5, 0)
FloatingTitleImage.AnchorPoint = Vector2.new(0.5, 0.5)
FloatingTitleImage.BackgroundTransparency = 1
FloatingTitleImage.Image = "rbxassetid://121131619457251" 
FloatingTitleImage.ScaleType = Enum.ScaleType.Fit
FloatingTitleImage.ZIndex = 10001

local isLoaded = false
task.spawn(function()
	local t = 0
	while not isLoaded do
		local dt = RunService.RenderStepped:Wait()
		t = t + dt
		local hoverOffset = math.sin(t * 1.5) * 0.01
		FloatingTitleImage.Position = UDim2.new(0.5, 0, 0.5 + hoverOffset, 0)
	end
end)

print("[AoT UI] Booting Unified Responsive Interface...")

task.spawn(function()
	local VFXManager = require(playerScripts:WaitForChild("VFXManager"))
	local MusicManager = require(playerScripts:WaitForChild("MusicManager"))
	VFXManager.Initialize()
	MusicManager.Initialize()
end)

-- ==========================================
-- UNIFIED UI BOOT
-- ==========================================
local UIModules = playerScripts:WaitForChild("UIModules")

require(UIModules:WaitForChild("MainUI")).Initialize(MasterGui)
require(UIModules:WaitForChild("TradingUI")).Initialize(MasterGui)

local PathsShop = UIModules:WaitForChild("PathsShopUI", 10)
if PathsShop then 
	require(PathsShop).Initialize(MasterGui) 
end

-- ==========================================
-- DATASTORE SYNCHRONIZATION
-- ==========================================
task.spawn(function()
	if not player:GetAttribute("DataLoaded") then
		local loadedBindable = Instance.new("BindableEvent")
		local conn = player:GetAttributeChangedSignal("DataLoaded"):Connect(function()
			if player:GetAttribute("DataLoaded") then
				loadedBindable:Fire(true)
			end
		end)

		task.delay(15, function()
			loadedBindable:Fire(false) 
		end)

		local success = loadedBindable.Event:Wait()
		if conn then conn:Disconnect() end

		if not success then
			FloatingTitleImage.Visible = false
			local ErrorText = Instance.new("TextLabel", LoadScreen)
			ErrorText.Size = UDim2.new(1, 0, 0, 50)
			ErrorText.Position = UDim2.new(0, 0, 0.45, 0)
			ErrorText.BackgroundTransparency = 1
			ErrorText.Font = Enum.Font.GothamBlack
			ErrorText.TextSize = 24
			ErrorText.TextColor3 = Color3.fromRGB(255, 85, 85)
			ErrorText.Text = "DATASTORE TIMEOUT. SOME FEATURES MAY BE BROKEN."
			ErrorText.ZIndex = 10002
			task.wait(3) 
		end
	end

	isLoaded = true
	task.wait(1.0) 

	local fadeTime = 1.0

	TweenService:Create(LoadScreen, TweenInfo.new(fadeTime), {BackgroundTransparency = 1}):Play()

	for _, child in ipairs(LoadScreen:GetChildren()) do
		local tweenGoals = {}

		if child.BackgroundTransparency < 1 then 
			tweenGoals.BackgroundTransparency = 1 
		end

		if child:IsA("ImageLabel") or child:IsA("ImageButton") then
			tweenGoals.ImageTransparency = 1
		elseif child:IsA("TextLabel") or child:IsA("TextButton") then
			tweenGoals.TextTransparency = 1
			if child.TextStrokeTransparency < 1 then
				tweenGoals.TextStrokeTransparency = 1
			end
		end

		if next(tweenGoals) ~= nil then
			TweenService:Create(child, TweenInfo.new(fadeTime), tweenGoals):Play()
		end
	end

	task.wait(fadeTime)
	LoadScreen:Destroy()
end)