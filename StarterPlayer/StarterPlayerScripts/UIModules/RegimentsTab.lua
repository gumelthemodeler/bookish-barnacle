-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local RegimentsTab = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = ReplicatedStorage:WaitForChild("Network")
local RegimentData = require(ReplicatedStorage:WaitForChild("RegimentData"))

local SharedUI = script.Parent.Parent:WaitForChild("SharedUI")
local UIHelpers = require(SharedUI:WaitForChild("UIHelpers"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CONFIG = {
	RegColors = {
		["Garrison"] = "#FF5555",
		["Military Police"] = "#55FF55",
		["Scout Regiment"] = "#55AAFF"
	},
	SwapCost = 50000
}

local function FormatNumber(n)
	if not n then return "0" end
	return tostring(n):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
end

local function CreateGrimPanel(parent)
	local frame = Instance.new("Frame", parent)
	frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	frame.BorderSizePixel = 0
	local stroke = Instance.new("UIStroke", frame)
	stroke.Color = Color3.fromRGB(70, 70, 80)
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return frame, stroke
end

local function CreateSharpButton(parent, text, size, font, textSize)
	local btn = Instance.new("TextButton", parent)
	btn.Size = size
	btn.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Font = font
	btn.TextColor3 = Color3.fromRGB(245, 245, 245)
	btn.TextSize = textSize
	btn.Text = text

	local stroke = Instance.new("UIStroke", btn)
	stroke.Color = Color3.fromRGB(70, 70, 80)
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	btn.MouseEnter:Connect(function() 
		if btn.Active then
			stroke.Color = Color3.fromRGB(225, 185, 60)
			btn.TextColor3 = Color3.fromRGB(225, 185, 60) 
		end
	end)
	btn.MouseLeave:Connect(function() 
		if btn.Active then
			stroke.Color = btn:GetAttribute("OrigStroke") or Color3.fromRGB(70, 70, 80)
			btn.TextColor3 = btn:GetAttribute("OrigColor") or Color3.fromRGB(245, 245, 245)
		end
	end)
	return btn, stroke
end

local LayoutRefs = {}

local function UpdateLayoutForScreen()
	local vp = camera.ViewportSize
	if vp.X == 0 or vp.Y == 0 or not LayoutRefs.listLayout then return end

	local isMobile = (vp.X <= 850) or (vp.Y > vp.X)

	if isMobile then
		LayoutRefs.listLayout.FillDirection = Enum.FillDirection.Vertical
		for _, card in ipairs(LayoutRefs.Cards) do
			card.Size = UDim2.new(0.95, 0, 0, 140)

			local icon = card:FindFirstChildOfClass("ImageLabel")
			if icon then
				icon.Size = UDim2.new(0, 100, 0, 100)
				icon.Position = UDim2.new(0, 15, 0.5, 0)
				icon.AnchorPoint = Vector2.new(0, 0.5)
			end

			local nameLbl = card:FindFirstChild("NameLbl")
			if nameLbl then
				nameLbl.Size = UDim2.new(1, -140, 0, 30)
				nameLbl.Position = UDim2.new(0, 130, 0, 15)
				nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			end

			local descLbl = card:FindFirstChild("DescLbl")
			if descLbl then
				descLbl.Size = UDim2.new(1, -140, 0, 50)
				descLbl.Position = UDim2.new(0, 130, 0, 45)
				descLbl.TextXAlignment = Enum.TextXAlignment.Left
			end

			local pldBtn = card:FindFirstChild("PldBtn")
			if pldBtn then
				pldBtn.Size = UDim2.new(0, 150, 0, 35)
				pldBtn.Position = UDim2.new(1, -15, 1, -15)
				pldBtn.AnchorPoint = Vector2.new(1, 1)
			end

			local buffBox = card:FindFirstChild("BuffBox")
			if buffBox then buffBox.Visible = false end
		end
	else
		LayoutRefs.listLayout.FillDirection = Enum.FillDirection.Horizontal
		for _, card in ipairs(LayoutRefs.Cards) do
			card.Size = UDim2.new(0.3, 0, 0, 420)

			local icon = card:FindFirstChildOfClass("ImageLabel")
			if icon then
				icon.Size = UDim2.new(0, 150, 0, 150)
				icon.Position = UDim2.new(0.5, 0, 0, 30)
				icon.AnchorPoint = Vector2.new(0.5, 0)
			end

			local nameLbl = card:FindFirstChild("NameLbl")
			if nameLbl then
				nameLbl.Size = UDim2.new(1, 0, 0, 30)
				nameLbl.Position = UDim2.new(0, 0, 0, 190)
				nameLbl.TextXAlignment = Enum.TextXAlignment.Center
			end

			local descLbl = card:FindFirstChild("DescLbl")
			if descLbl then
				descLbl.Size = UDim2.new(1, -30, 0, 50)
				descLbl.Position = UDim2.new(0, 15, 0, 230)
				descLbl.TextXAlignment = Enum.TextXAlignment.Center
			end

			local pldBtn = card:FindFirstChild("PldBtn")
			if pldBtn then
				pldBtn.Size = UDim2.new(0.8, 0, 0, 45)
				pldBtn.Position = UDim2.new(0.5, 0, 1, -25)
				pldBtn.AnchorPoint = Vector2.new(0.5, 1)
			end

			local buffBox = card:FindFirstChild("BuffBox")
			if buffBox then buffBox.Visible = true end
		end
	end
end

function RegimentsTab.Initialize(parentFrame)
	for _, child in ipairs(parentFrame:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end

	local MainScroll = Instance.new("ScrollingFrame", parentFrame)
	MainScroll.Size = UDim2.new(1, 0, 1, 0)
	MainScroll.BackgroundTransparency = 1
	MainScroll.ScrollBarThickness = 6
	MainScroll.BorderSizePixel = 0

	local mLayout = Instance.new("UIListLayout", MainScroll)
	mLayout.SortOrder = Enum.SortOrder.LayoutOrder
	mLayout.Padding = UDim.new(0, 15)

	mLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		MainScroll.CanvasSize = UDim2.new(0, 0, 0, mLayout.AbsoluteContentSize.Y + 20)
	end)

	local HeaderFrame = Instance.new("Frame", MainScroll)
	HeaderFrame.Size = UDim2.new(1, 0, 0, 60)
	HeaderFrame.BackgroundTransparency = 1
	HeaderFrame.LayoutOrder = 1

	local Title = UIHelpers.CreateLabel(HeaderFrame, "REGIMENT HEADQUARTERS", UDim2.new(1, 0, 0, 30), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 24)
	Title.Position = UDim2.new(0, 0, 0, 0)
	Title.TextXAlignment = Enum.TextXAlignment.Center

	local Subtitle = UIHelpers.CreateLabel(HeaderFrame, "Pledge your allegiance to a military branch for global passive buffs.", UDim2.new(1, 0, 0, 20), Enum.Font.GothamMedium, UIHelpers.Colors.TextMuted, 14)
	Subtitle.Position = UDim2.new(0, 0, 0, 35)
	Subtitle.TextXAlignment = Enum.TextXAlignment.Center

	local CardContainer = Instance.new("Frame", MainScroll)
	CardContainer.Size = UDim2.new(1, 0, 0, 0)
	CardContainer.BackgroundTransparency = 1
	CardContainer.LayoutOrder = 2

	local listLayout = Instance.new("UIListLayout", CardContainer)
	listLayout.FillDirection = Enum.FillDirection.Horizontal
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	listLayout.Padding = UDim.new(0, 30)

	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		CardContainer.Size = UDim2.new(1, 0, 0, listLayout.AbsoluteContentSize.Y)
	end)

	LayoutRefs.listLayout = listLayout
	LayoutRefs.Cards = {}

	local function CreateRegimentCard(name, desc)
		local dataReg = RegimentData.Regiments[name]
		if not dataReg then return end

		local colorHex = CONFIG.RegColors[name] or "#FFFFFF"
		local regColor = Color3.fromHex(colorHex:gsub("#",""))

		local card, cardStroke = CreateGrimPanel(CardContainer)

		local icon = Instance.new("ImageLabel", card)
		icon.BackgroundTransparency = 1
		icon.Image = dataReg.Icon
		icon.ScaleType = Enum.ScaleType.Fit

		local nameLbl = UIHelpers.CreateLabel(card, string.upper(name), UDim2.new(1, 0, 0, 30), Enum.Font.GothamBlack, regColor, 20)
		nameLbl.Name = "NameLbl"

		local descLbl = UIHelpers.CreateLabel(card, desc, UDim2.new(1, -30, 0, 50), Enum.Font.GothamMedium, UIHelpers.Colors.TextWhite, 13)
		descLbl.Name = "DescLbl"
		descLbl.TextWrapped = true
		descLbl.TextYAlignment = Enum.TextYAlignment.Top

		local buffBox = Instance.new("Frame", card)
		buffBox.Name = "BuffBox"
		buffBox.Size = UDim2.new(0.8, 0, 0, 40)
		buffBox.Position = UDim2.new(0.5, 0, 0, 290)
		buffBox.AnchorPoint = Vector2.new(0.5, 0)
		buffBox.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
		local bbStroke = Instance.new("UIStroke", buffBox); bbStroke.Color = Color3.fromRGB(50, 50, 60)
		local buffLbl = UIHelpers.CreateLabel(buffBox, dataReg.Buff, UDim2.new(1, 0, 1, 0), Enum.Font.GothamBold, Color3.fromRGB(100, 255, 100), 12)

		local PldBtn, pStrk = CreateSharpButton(card, "", UDim2.new(0.8, 0, 0, 45), Enum.Font.GothamBlack, 14)
		PldBtn.Name = "PldBtn"

		local function UpdateBtn()
			local currentReg = player:GetAttribute("Regiment") or "Cadet Corps"

			if currentReg == name then
				PldBtn.Text = "PLEDGED"
				PldBtn.TextColor3 = regColor
				pStrk.Color = regColor
				PldBtn:SetAttribute("OrigColor", regColor)
				PldBtn:SetAttribute("OrigStroke", regColor)
				PldBtn.Active = false
			elseif currentReg == "Cadet Corps" then
				PldBtn.Text = "JOIN (FREE)"
				PldBtn.TextColor3 = UIHelpers.Colors.TextWhite
				pStrk.Color = Color3.fromRGB(70, 70, 80)
				PldBtn:SetAttribute("OrigColor", UIHelpers.Colors.TextWhite)
				PldBtn:SetAttribute("OrigStroke", Color3.fromRGB(70, 70, 80))
				PldBtn.Active = true
			else
				PldBtn.Text = "SWAP (" .. FormatNumber(CONFIG.SwapCost) .. " DEWS)"
				PldBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
				pStrk.Color = Color3.fromRGB(100, 50, 50)
				PldBtn:SetAttribute("OrigColor", Color3.fromRGB(255, 100, 100))
				PldBtn:SetAttribute("OrigStroke", Color3.fromRGB(100, 50, 50))
				PldBtn.Active = true
			end
		end

		player.AttributeChanged:Connect(function(attr) if attr == "Regiment" then UpdateBtn() end end)
		UpdateBtn()

		PldBtn.MouseButton1Click:Connect(function()
			if not PldBtn.Active then return end
			Network:WaitForChild("JoinRegiment"):FireServer(name)
		end)

		table.insert(LayoutRefs.Cards, card)
	end

	CreateRegimentCard("Garrison", "The defenders of the walls, maintaining order and fortifying humanity's last stronghold.")
	CreateRegimentCard("Scout Regiment", "The vanguard of humanity's expansion, seeking freedom outside the walls.")
	CreateRegimentCard("Military Police", "The royal guard maintaining inner peace and protecting the king.")

	camera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateLayoutForScreen)
	UpdateLayoutForScreen()
end

return RegimentsTab