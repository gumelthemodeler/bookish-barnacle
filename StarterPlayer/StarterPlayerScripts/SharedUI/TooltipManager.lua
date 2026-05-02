-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local TooltipManager = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local tooltipGui
local tooltipFrame
local tooltipText
local renderConnection

function TooltipManager.Initialize()
	if tooltipGui then return end

	tooltipGui = Instance.new("ScreenGui")
	tooltipGui.Name = "TooltipGui"
	tooltipGui.DisplayOrder = 1000 -- Ensures it overlays everything
	tooltipGui.IgnoreGuiInset = true
	tooltipGui.Parent = player:WaitForChild("PlayerGui")

	tooltipFrame = Instance.new("Frame", tooltipGui)
	tooltipFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
	tooltipFrame.BackgroundTransparency = 0.05
	tooltipFrame.BorderSizePixel = 0
	tooltipFrame.Visible = false
	tooltipFrame.ZIndex = 1000

	local uiCorner = Instance.new("UICorner", tooltipFrame)
	uiCorner.CornerRadius = UDim.new(0, 6)

	local uiStroke = Instance.new("UIStroke", tooltipFrame)
	uiStroke.Color = Color3.fromRGB(70, 70, 80)
	uiStroke.Thickness = 1.5

	local uiPadding = Instance.new("UIPadding", tooltipFrame)
	uiPadding.PaddingTop = UDim.new(0, 8)
	uiPadding.PaddingBottom = UDim.new(0, 8)
	uiPadding.PaddingLeft = UDim.new(0, 10)
	uiPadding.PaddingRight = UDim.new(0, 10)

	tooltipText = Instance.new("TextLabel", tooltipFrame)
	tooltipText.Size = UDim2.new(1, 0, 1, 0)
	tooltipText.BackgroundTransparency = 1
	tooltipText.Font = Enum.Font.GothamMedium
	tooltipText.TextColor3 = Color3.fromRGB(230, 230, 230)
	tooltipText.TextSize = 12
	tooltipText.TextXAlignment = Enum.TextXAlignment.Left
	tooltipText.TextYAlignment = Enum.TextYAlignment.Top
	tooltipText.RichText = true
	tooltipText.TextWrapped = true
	tooltipText.ZIndex = 1001

	tooltipText.AutomaticSize = Enum.AutomaticSize.XY
	tooltipFrame.AutomaticSize = Enum.AutomaticSize.XY
end

local function UpdateTooltipPosition()
	if not tooltipFrame.Visible then return end

	local mousePos = UserInputService:GetMouseLocation()
	local screenX = mousePos.X
	local screenY = mousePos.Y
	local camera = workspace.CurrentCamera

	local xOffset = 15
	local yOffset = 15

	if screenX + tooltipFrame.AbsoluteSize.X + 20 > camera.ViewportSize.X then
		xOffset = -(tooltipFrame.AbsoluteSize.X + 15)
	end
	if screenY + tooltipFrame.AbsoluteSize.Y + 20 > camera.ViewportSize.Y then
		yOffset = -(tooltipFrame.AbsoluteSize.Y + 15)
	end

	tooltipFrame.Position = UDim2.new(0, screenX + xOffset, 0, screenY + yOffset)
end

function TooltipManager.Show(text)
	if not tooltipGui then TooltipManager.Initialize() end

	tooltipText.Text = text
	tooltipFrame.Visible = true

	if renderConnection then renderConnection:Disconnect() end
	renderConnection = RunService.RenderStepped:Connect(UpdateTooltipPosition)
	UpdateTooltipPosition()
end

function TooltipManager.Hide()
	if not tooltipGui then return end
	tooltipFrame.Visible = false
	tooltipText.Text = ""
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
end

return TooltipManager