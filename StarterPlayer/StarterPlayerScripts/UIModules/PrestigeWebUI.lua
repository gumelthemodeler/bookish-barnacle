-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local PrestigeWebUI = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local SkillData = require(ReplicatedStorage:WaitForChild("SkillData"))
local Network = ReplicatedStorage:WaitForChild("Network")

local SharedUI = script.Parent.Parent:WaitForChild("SharedUI")
local UIHelpers = require(SharedUI:WaitForChild("UIHelpers"))

local PurchaseNodeEvent = Network:FindFirstChild("PurchasePrestigeNode") or Instance.new("RemoteEvent", Network)
PurchaseNodeEvent.Name = "PurchasePrestigeNode"

local player = Players.LocalPlayer
local generatedNodes = {}
local nodeLines = {}

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

function PrestigeWebUI.Build(parentPanel)
	for _, c in ipairs(parentPanel:GetChildren()) do c:Destroy() end

	local TopHeader = Instance.new("Frame", parentPanel)
	TopHeader.Size = UDim2.new(1, 0, 0, 35)
	TopHeader.BackgroundTransparency = 1

	local PointsLabel = CreateSharpLabel(TopHeader, "AVAILABLE POINTS: 0", UDim2.new(1, 0, 1, 0), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 20)
	PointsLabel.TextXAlignment = Enum.TextXAlignment.Left
	PointsLabel.Position = UDim2.new(0, 10, 0, 0)

	local CanvasContainer = Instance.new("CanvasGroup", parentPanel)
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

	local DetailPanel = Instance.new("Frame", parentPanel)
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
	generatedNodes = {}
	nodeLines = {}

	for id, nodeData in pairs(SkillData.PrestigeNodes or {}) do
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
				DReq.Text = "REQUIRES: " .. (SkillData.PrestigeNodes[nodeData.Req] and SkillData.PrestigeNodes[nodeData.Req].Name or nodeData.Req)
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
	local dragInput
	local dragStart
	local startPos

	CanvasContainer.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = Canvas.Position

			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	CanvasContainer.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		elseif input.UserInputType == Enum.UserInputType.MouseWheel then
			local newScale = math.clamp(CanvasScale.Scale + (input.Position.Z * 0.15), 0.3, 2.5)
			CanvasScale.Scale = newScale
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			Canvas.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + (delta.X / CanvasScale.Scale),
				startPos.Y.Scale, startPos.Y.Offset + (delta.Y / CanvasScale.Scale)
			)
		end
	end)

	task.defer(function()
		local canvasSize = Canvas.AbsoluteSize
		if canvasSize.X == 0 then canvasSize = Vector2.new(2000, 2000) end 

		for id, nodeData in pairs(SkillData.PrestigeNodes or {}) do
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
			local nodeData = SkillData.PrestigeNodes[id]
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
			local nodeData = SkillData.PrestigeNodes[selectedNode]
			local isOwned = player:GetAttribute("PrestigeNode_" .. selectedNode)
			local hasReq = (not nodeData.Req) or player:GetAttribute("PrestigeNode_" .. nodeData.Req)

			if isOwned then 
				DReq.Text = "OWNED"
				DReq.TextColor3 = Color3.fromRGB(100, 255, 100)
				UnlockBtn.Text = "OWNED"
				UnlockBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
				UBtnStroke.Color = UIHelpers.Colors.BorderMuted
			elseif not hasReq then 
				DReq.Text = "REQUIRES: " .. (SkillData.PrestigeNodes[nodeData.Req] and SkillData.PrestigeNodes[nodeData.Req].Name or nodeData.Req)
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
end

return PrestigeWebUI