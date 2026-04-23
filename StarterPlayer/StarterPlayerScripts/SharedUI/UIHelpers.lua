-- @ScriptType: ModuleScript
-- Name: UIHelpers
-- @ScriptType: ModuleScript
local UIHelpers = {}
local TweenService = game:GetService("TweenService")

UIHelpers.Colors = {
	Background = Color3.fromRGB(18, 18, 22),     
	Surface = Color3.fromRGB(28, 28, 34),        
	SurfaceLight = Color3.fromRGB(40, 40, 48),   
	Border = Color3.fromRGB(180, 30, 30),        
	BorderMuted = Color3.fromRGB(70, 70, 80),    
	TextWhite = Color3.fromRGB(245, 245, 245),
	TextMuted = Color3.fromRGB(160, 160, 175),
	Gold = Color3.fromRGB(225, 185, 60)
}

function UIHelpers.ApplyGrimPanel(frame, useBloodBorder)
	frame.BackgroundColor3 = UIHelpers.Colors.Background
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0

	local stroke = Instance.new("UIStroke", frame)
	stroke.Color = useBloodBorder and UIHelpers.Colors.Border or UIHelpers.Colors.BorderMuted
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
end

function UIHelpers.CreateButton(parent, text, size, font, textSize)
	local btn = Instance.new("TextButton", parent)
	btn.Size = size
	btn.BackgroundColor3 = UIHelpers.Colors.Surface
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Font = font or Enum.Font.GothamBlack
	btn.TextColor3 = UIHelpers.Colors.TextWhite
	btn.TextSize = textSize or 16
	btn.Text = text

	local stroke = Instance.new("UIStroke", btn)
	stroke.Color = UIHelpers.Colors.BorderMuted
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	btn.MouseEnter:Connect(function()
		stroke.Color = UIHelpers.Colors.Gold
		btn.TextColor3 = UIHelpers.Colors.Gold
	end)
	btn.MouseLeave:Connect(function()
		stroke.Color = UIHelpers.Colors.BorderMuted
		btn.TextColor3 = UIHelpers.Colors.TextWhite
	end)

	return btn, stroke
end

function UIHelpers.CreateIconButton(parent, iconId, size)
	local btn = Instance.new("ImageButton", parent)
	btn.Size = size
	btn.BackgroundColor3 = UIHelpers.Colors.Surface
	btn.BorderSizePixel = 0
	btn.Image = iconId
	btn.ScaleType = Enum.ScaleType.Fit

	local pad = Instance.new("UIPadding", btn)
	pad.PaddingTop = UDim.new(0, 8); pad.PaddingBottom = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8)

	local stroke = Instance.new("UIStroke", btn)
	stroke.Color = UIHelpers.Colors.BorderMuted
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	btn.MouseEnter:Connect(function() stroke.Color = UIHelpers.Colors.Gold end)
	btn.MouseLeave:Connect(function() stroke.Color = UIHelpers.Colors.BorderMuted end)

	return btn
end

function UIHelpers.CreateLabel(parent, text, size, font, textColor, textSize)
	local lbl = Instance.new("TextLabel", parent)
	lbl.Size = size
	lbl.BackgroundTransparency = 1
	lbl.Font = font or Enum.Font.GothamBold
	lbl.TextColor3 = textColor or UIHelpers.Colors.TextWhite
	lbl.TextSize = textSize or 14
	lbl.Text = text
	lbl.TextXAlignment = Enum.TextXAlignment.Center
	lbl.TextYAlignment = Enum.TextYAlignment.Center
	return lbl
end

function UIHelpers.CreateTallCard(parent, titleText, descText, imageId, onClick)
	local card = Instance.new("TextButton", parent)
	card.Size = UDim2.new(0, 280, 0, 420)
	card.Text = ""
	card.AutoButtonColor = false
	card.BackgroundColor3 = UIHelpers.Colors.Surface
	card.ClipsDescendants = true
	card.BorderSizePixel = 0

	local stroke = Instance.new("UIStroke", card)
	stroke.Color = UIHelpers.Colors.BorderMuted
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	local uiScale = Instance.new("UIScale", card) 

	local bgImg = Instance.new("ImageLabel", card)
	bgImg.Size = UDim2.new(1, 0, 1, 0)
	bgImg.BackgroundTransparency = 1
	bgImg.Image = imageId
	bgImg.ScaleType = Enum.ScaleType.Crop
	bgImg.ZIndex = 1

	local gradFrame = Instance.new("Frame", card)
	gradFrame.Size = UDim2.new(1, 0, 1, 0)
	gradFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	gradFrame.BorderSizePixel = 0
	gradFrame.ZIndex = 2
	local grad = Instance.new("UIGradient", gradFrame)
	grad.Rotation = 90
	grad.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.4, 0.8),
		NumberSequenceKeypoint.new(0.7, 0.2),
		NumberSequenceKeypoint.new(1, 0)
	}

	local title = UIHelpers.CreateLabel(card, titleText, UDim2.new(1, -20, 0, 30), Enum.Font.GothamBlack, UIHelpers.Colors.TextWhite, 22)
	title.Position = UDim2.new(0, 10, 1, -90)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextScaled = true
	title.ZIndex = 3

	local desc = UIHelpers.CreateLabel(card, descText, UDim2.new(1, -20, 0, 40), Enum.Font.GothamBold, UIHelpers.Colors.TextMuted, 13)
	desc.Position = UDim2.new(0, 10, 1, -55)
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.TextWrapped = true
	desc.ZIndex = 3

	card.MouseEnter:Connect(function()
		TweenService:Create(uiScale, TweenInfo.new(0.15), {Scale = 1.03}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.15), {Color = UIHelpers.Colors.Gold}):Play()
	end)
	card.MouseLeave:Connect(function()
		TweenService:Create(uiScale, TweenInfo.new(0.15), {Scale = 1.0}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.15), {Color = UIHelpers.Colors.BorderMuted}):Play()
	end)

	card.MouseButton1Click:Connect(onClick)
	return card
end

return UIHelpers