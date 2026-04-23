-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local AFKTab = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Network = ReplicatedStorage:WaitForChild("Network")

local SharedUI = script.Parent.Parent:WaitForChild("SharedUI")
local UIHelpers = require(SharedUI:WaitForChild("UIHelpers"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CONFIG = {
	Allies = {
		{Name = "Armin Arlert", Cost = 1000, Icon = "rbxassetid://99009166931575"},
		{Name = "Sasha Braus", Cost = 2500, Icon = "rbxassetid://74069077964164"},
		{Name = "Connie Springer", Cost = 2500, Icon = "rbxassetid://80661189472482"},
		{Name = "Jean Kirstein", Cost = 5000, Icon = "rbxassetid://107359332104986"},
		{Name = "Hange Zoe", Cost = 10000, Icon = "rbxassetid://71066662959593"},
		{Name = "Erwin Smith", Cost = 20000, Icon = "rbxassetid://116122082480103"},
		{Name = "Mikasa Ackerman", Cost = 50000, Icon = "rbxassetid://113777388050871"},
		{Name = "Levi Ackerman", Cost = 100000, Icon = "rbxassetid://120198409378661"}
	},
	Nodes = {
		UDim2.new(0.5, 0, 0.15, 0),   UDim2.new(0.8, 0, 0.5, 0),
		UDim2.new(0.5, 0, 0.85, 0),   UDim2.new(0.2, 0, 0.5, 0),
		UDim2.new(0.35, 0, 0.35, 0),  UDim2.new(0.65, 0, 0.35, 0),
		UDim2.new(0.65, 0, 0.65, 0),  UDim2.new(0.35, 0, 0.65, 0),
	}
}

local function DecodeJSON(attr)
	local raw = player:GetAttribute(attr)
	if not raw or raw == "" then return {} end
	local success, res = pcall(function() return HttpService:JSONDecode(raw) end)
	return success and res or {}
end

local function FormatNumber(n)
	if not n then return "0" end
	return tostring(n):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
end

local function GetAllyConfig(name)
	for _, cfg in ipairs(CONFIG.Allies) do if cfg.Name == name then return cfg end end
	return CONFIG.Allies[1]
end

local function CreateSharpButton(parent, text, size, font, textSize)
	local btn = Instance.new("TextButton", parent)
	btn.Size = size; btn.BackgroundColor3 = Color3.fromRGB(28, 28, 34); btn.BorderSizePixel = 0; btn.AutoButtonColor = false; btn.Font = font; btn.TextColor3 = Color3.fromRGB(245, 245, 245); btn.TextSize = textSize; btn.Text = text
	local stroke = Instance.new("UIStroke", btn); stroke.Color = Color3.fromRGB(70, 70, 80); stroke.Thickness = 2; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	btn.MouseEnter:Connect(function() stroke.Color = Color3.fromRGB(225, 185, 60); btn.TextColor3 = Color3.fromRGB(225, 185, 60) end)
	btn.MouseLeave:Connect(function() stroke.Color = Color3.fromRGB(70, 70, 80); btn.TextColor3 = Color3.fromRGB(245, 245, 245) end)
	return btn, stroke
end

local LayoutRefs = {}

local function UpdateLayoutForScreen()
	local vp = camera.ViewportSize
	if vp.X == 0 or vp.Y == 0 or not LayoutRefs.MainLayout then return end
	local isMobile = (vp.X <= 850) or (vp.Y > vp.X)

	if isMobile then
		LayoutRefs.MainLayout.FillDirection = Enum.FillDirection.Vertical

		LayoutRefs.LeftPanel.Size = UDim2.new(0.95, 0, 0, 500)
		LayoutRefs.MapContainer.Size = UDim2.new(1, 0, 0, 300)
		LayoutRefs.LogContainer.Size = UDim2.new(1, 0, 0, 185)

		LayoutRefs.RosterContainer.Size = UDim2.new(0.95, 0, 0, 600)
	else
		LayoutRefs.MainLayout.FillDirection = Enum.FillDirection.Horizontal

		LayoutRefs.LeftPanel.Size = UDim2.new(0.5, 0, 0, 500)
		LayoutRefs.MapContainer.Size = UDim2.new(1, 0, 0, 300)
		LayoutRefs.LogContainer.Size = UDim2.new(1, 0, 0, 185)

		LayoutRefs.RosterContainer.Size = UDim2.new(0.45, 0, 0, 500)
	end
end

function AFKTab.Initialize(parentFrame, InitiateDeploymentCallback)
	for _, child in ipairs(parentFrame:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end

	local MainContainer = Instance.new("Frame", parentFrame)
	MainContainer.Size = UDim2.new(1, 0, 1, 0)
	MainContainer.BackgroundTransparency = 1
	MainContainer.AutomaticSize = Enum.AutomaticSize.Y

	local mainLayout = Instance.new("UIListLayout", MainContainer)
	mainLayout.SortOrder = Enum.SortOrder.LayoutOrder
	mainLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	mainLayout.Padding = UDim.new(0, 20)

	local mainPad = Instance.new("UIPadding", MainContainer)
	mainPad.PaddingTop = UDim.new(0, 10)
	mainPad.PaddingBottom = UDim.new(0, 20)

	local LeftPanel = Instance.new("Frame", MainContainer)
	LeftPanel.BackgroundTransparency = 1
	LeftPanel.LayoutOrder = 1
	local lpLayout = Instance.new("UIListLayout", LeftPanel)
	lpLayout.FillDirection = Enum.FillDirection.Vertical
	lpLayout.Padding = UDim.new(0, 15)

	local MapContainer = Instance.new("Frame", LeftPanel)
	MapContainer.BackgroundColor3 = Color3.fromRGB(15, 18, 15)
	MapContainer.BorderSizePixel = 0
	local mapStroke = Instance.new("UIStroke", MapContainer)
	mapStroke.Color = Color3.fromRGB(50, 60, 50)
	mapStroke.Thickness = 2

	local LogContainer = Instance.new("Frame", LeftPanel)
	LogContainer.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	LogContainer.BorderSizePixel = 0
	local logStroke = Instance.new("UIStroke", LogContainer)
	logStroke.Color = Color3.fromRGB(70, 70, 80)
	logStroke.Thickness = 2

	local RosterContainer = Instance.new("Frame", MainContainer)
	RosterContainer.BackgroundTransparency = 1
	RosterContainer.LayoutOrder = 2

	LayoutRefs.MainLayout = mainLayout
	LayoutRefs.LeftPanel = LeftPanel
	LayoutRefs.MapContainer = MapContainer
	LayoutRefs.LogContainer = LogContainer
	LayoutRefs.RosterContainer = RosterContainer

	local MapSquare = Instance.new("Frame", MapContainer)
	MapSquare.Size = UDim2.new(1, 0, 1, 0)
	MapSquare.Position = UDim2.new(0.5, 0, 0.5, 0)
	MapSquare.AnchorPoint = Vector2.new(0.5, 0.5)
	MapSquare.BackgroundTransparency = 1

	local mapAsp = Instance.new("UIAspectRatioConstraint", MapSquare)
	mapAsp.AspectRatio = 1.0
	mapAsp.AspectType = Enum.AspectType.FitWithinMaxSize 

	local crossV = Instance.new("Frame", MapSquare); crossV.Size = UDim2.new(0, 2, 0.85, 0); crossV.Position = UDim2.new(0.5, 0, 0.5, 0); crossV.AnchorPoint = Vector2.new(0.5, 0.5); crossV.BackgroundColor3 = Color3.fromRGB(60, 80, 60); crossV.BorderSizePixel = 0
	local crossH = Instance.new("Frame", MapSquare); crossH.Size = UDim2.new(0.85, 0, 0, 2); crossH.Position = UDim2.new(0.5, 0, 0.5, 0); crossH.AnchorPoint = Vector2.new(0.5, 0.5); crossH.BackgroundColor3 = Color3.fromRGB(60, 80, 60); crossH.BorderSizePixel = 0

	local function CreateWall(sizeScale, color, name)
		local wall = Instance.new("Frame", MapSquare); wall.Size = UDim2.new(sizeScale, 0, sizeScale, 0); wall.Position = UDim2.new(0.5, 0, 0.5, 0); wall.AnchorPoint = Vector2.new(0.5, 0.5); wall.BackgroundTransparency = 1; wall.BorderSizePixel = 0
		local s = Instance.new("UIStroke", wall); s.Color = color; s.Thickness = 3
		local lbl = UIHelpers.CreateLabel(wall, name, UDim2.new(0, 100, 0, 20), Enum.Font.GothamBlack, color, 12); lbl.Position = UDim2.new(0.5, 0, 0, -10); lbl.AnchorPoint = Vector2.new(0.5, 0.5)
	end
	CreateWall(0.85, Color3.fromRGB(100, 120, 100), "WALL MARIA")
	CreateWall(0.55, Color3.fromRGB(120, 140, 120), "WALL ROSE")
	CreateWall(0.25, Color3.fromRGB(140, 160, 140), "WALL SINA")

	local NodeVisuals = {}
	for i, pos in ipairs(CONFIG.Nodes) do
		local node = Instance.new("Frame", MapSquare); node.Size = UDim2.new(0, 45, 0, 45); node.Position = pos; node.AnchorPoint = Vector2.new(0.5, 0.5); node.BackgroundColor3 = Color3.fromRGB(20, 20, 25); node.BorderSizePixel = 0
		local nStrk = Instance.new("UIStroke", node); nStrk.Color = Color3.fromRGB(100, 100, 110); nStrk.Thickness = 2
		local nIcon = Instance.new("ImageLabel", node); nIcon.Size = UDim2.new(1, -6, 1, -6); nIcon.Position = UDim2.new(0.5, 0, 0.5, 0); nIcon.AnchorPoint = Vector2.new(0.5, 0.5); nIcon.BackgroundTransparency = 1; nIcon.ScaleType = Enum.ScaleType.Crop; nIcon.Visible = false
		NodeVisuals[i] = {Frame = node, Icon = nIcon, Stroke = nStrk}
	end

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for _, nVis in ipairs(NodeVisuals) do if nVis.Icon.Visible then nVis.Icon.Position = UDim2.new(0.5, 0, 0.5, math.sin(t * 2) * 3) end end
	end)

	local LogTitle = UIHelpers.CreateLabel(LogContainer, "EXPEDITION LOG", UDim2.new(1, -20, 0, 25), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 14); LogTitle.Position = UDim2.new(0, 10, 0, 5); LogTitle.TextXAlignment = Enum.TextXAlignment.Left
	local LogScroll = Instance.new("ScrollingFrame", LogContainer); LogScroll.Size = UDim2.new(1, -20, 1, -40); LogScroll.Position = UDim2.new(0, 10, 0, 35); LogScroll.BackgroundTransparency = 1; LogScroll.ScrollBarThickness = 4; LogScroll.BorderSizePixel = 0
	local llLayout = Instance.new("UIListLayout", LogScroll); llLayout.Padding = UDim.new(0, 5)

	local function AppendLog(msg)
		local lbl = UIHelpers.CreateLabel(LogScroll, msg, UDim2.new(1, 0, 0, 0), Enum.Font.GothamMedium, UIHelpers.Colors.TextWhite, 12); lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.TextWrapped = true; lbl.RichText = true; lbl.AutomaticSize = Enum.AutomaticSize.Y
		task.delay(0.05, function() LogScroll.CanvasSize = UDim2.new(0, 0, 0, llLayout.AbsoluteContentSize.Y + 10); LogScroll.CanvasPosition = Vector2.new(0, LogScroll.CanvasSize.Y.Offset) end)
	end

	Network:WaitForChild("NotificationEvent").OnClientEvent:Connect(function(msg, typeStr)
		if string.find(msg, "returned!") then AppendLog("<font color='#55FF55'>[" .. os.date("%X") .. "]</font> " .. string.gsub(msg, "\n", " | ")) end
	end)

	local RosterHeader = Instance.new("Frame", RosterContainer); RosterHeader.Size = UDim2.new(1, 0, 0, 45); RosterHeader.BackgroundColor3 = Color3.fromRGB(18, 18, 22); RosterHeader.BorderSizePixel = 0
	Instance.new("UIStroke", RosterHeader).Color = Color3.fromRGB(70, 70, 80)

	local lblCap = UIHelpers.CreateLabel(RosterHeader, "DEPLOYED: 0 / 2", UDim2.new(0.5, 0, 1, 0), Enum.Font.GothamBlack, UIHelpers.Colors.TextWhite, 12); lblCap.Position = UDim2.new(0, 10, 0, 0); lblCap.TextXAlignment = Enum.TextXAlignment.Left
	local CapBtn, _ = CreateSharpButton(RosterHeader, "EXPAND SLOT", UDim2.new(0, 110, 0, 28), Enum.Font.GothamBlack, 10); CapBtn.Position = UDim2.new(1, -10, 0.5, 0); CapBtn.AnchorPoint = Vector2.new(1, 0.5); CapBtn.TextColor3 = UIHelpers.Colors.Gold
	CapBtn.MouseButton1Click:Connect(function() Network:WaitForChild("DispatchAction"):FireServer("UpgradeCapacity") end)

	local RecallAllBtn, _ = CreateSharpButton(RosterContainer, "RECALL ALL DEPLOYED", UDim2.new(1, 0, 0, 35), Enum.Font.GothamBlack, 14); RecallAllBtn.Position = UDim2.new(0, 0, 1, 0); RecallAllBtn.AnchorPoint = Vector2.new(0, 1); RecallAllBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
	RecallAllBtn.MouseButton1Click:Connect(function() local dData = DecodeJSON("DispatchData"); for aName, _ in pairs(dData) do Network:WaitForChild("DispatchAction"):FireServer("Recall", aName) end end)

	local RosterScroll = Instance.new("ScrollingFrame", RosterContainer)
	RosterScroll.Size = UDim2.new(1, 0, 1, -95) 
	RosterScroll.Position = UDim2.new(0, 0, 0, 50)
	RosterScroll.BackgroundTransparency = 1
	RosterScroll.ScrollBarThickness = 4
	RosterScroll.BorderSizePixel = 0

	local rsLayout = Instance.new("UIListLayout", RosterScroll)
	rsLayout.Padding = UDim.new(0, 8)
	rsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() RosterScroll.CanvasSize = UDim2.new(0, 0, 0, rsLayout.AbsoluteContentSize.Y + 10) end)

	local ActiveTimers = {}; local DeployedAlliesCache = {}; local AllyToNode = {}

	local function UpdateAFKUI()
		for _, c in ipairs(RosterScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
		ActiveTimers = {}

		local dData = DecodeJSON("DispatchData")
		local aLevels = DecodeJSON("AllyLevels")
		local unlocked = player:GetAttribute("UnlockedAllies") or ""
		local maxCap = player:GetAttribute("MaxDeployments") or 2
		local deployedCount = 0; for _, _ in pairs(dData) do deployedCount += 1 end
		lblCap.Text = string.format("DEPLOYED: %d / %d", deployedCount, maxCap)

		for aName, idx in pairs(AllyToNode) do
			if not dData[aName] then
				AllyToNode[aName] = nil
				local nVis = NodeVisuals[idx]
				if nVis then
					nVis.Icon.Visible = false; nVis.Stroke.Color = Color3.fromRGB(100, 100, 110)
					local dummy = Instance.new("ImageLabel", MapSquare); dummy.Size = UDim2.new(0, 40, 0, 40); dummy.Position = CONFIG.Nodes[idx]; dummy.AnchorPoint = Vector2.new(0.5, 0.5); dummy.BackgroundTransparency = 1; dummy.Image = GetAllyConfig(aName).Icon; dummy.ScaleType = Enum.ScaleType.Crop; dummy.ZIndex = 5
					local t1 = TweenService:Create(dummy, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 0, 0, 0)}); t1:Play(); game.Debris:AddItem(dummy, 0.55)
				end
			end
		end

		for aName, _ in pairs(dData) do
			local nodeIdx = AllyToNode[aName]
			if not nodeIdx then
				local used = {}; for _, idx in pairs(AllyToNode) do used[idx] = true end
				for i=1, 8 do if not used[i] then nodeIdx = i; AllyToNode[aName] = i; break end end
			end

			local config = GetAllyConfig(aName); local nVis = NodeVisuals[nodeIdx]
			if nVis then
				if not DeployedAlliesCache[aName] then
					nVis.Stroke.Color = UIHelpers.Colors.Gold
					local dummy = Instance.new("ImageLabel", MapSquare); dummy.Size = UDim2.new(0, 0, 0, 0); dummy.Position = UDim2.new(0.5, 0, 0.5, 0); dummy.AnchorPoint = Vector2.new(0.5, 0.5); dummy.BackgroundTransparency = 1; dummy.Image = config.Icon; dummy.ScaleType = Enum.ScaleType.Crop; dummy.ZIndex = 5
					local popTween = TweenService:Create(dummy, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 40, 0, 40)}); popTween:Play(); popTween.Completed:Wait()
					local moveTween = TweenService:Create(dummy, TweenInfo.new(0.6, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut), {Position = CONFIG.Nodes[nodeIdx]}); moveTween:Play()
					task.spawn(function() moveTween.Completed:Wait(); if dummy.Parent then nVis.Icon.Image = config.Icon; nVis.Icon.Visible = true; dummy:Destroy() end end)
				else
					nVis.Icon.Image = config.Icon; nVis.Icon.Visible = true; nVis.Stroke.Color = UIHelpers.Colors.Gold
				end
			end
		end

		DeployedAlliesCache = {}; for k, v in pairs(dData) do DeployedAlliesCache[k] = v end

		for i, config in ipairs(CONFIG.Allies) do
			local isUnlocked = string.find(unlocked, "%[" .. config.Name .. "%]")
			local isDeployed = dData[config.Name] ~= nil
			local lvl = aLevels[config.Name] or 1

			local card = Instance.new("Frame", RosterScroll); card.Size = UDim2.new(1, -10, 0, 65); card.BackgroundColor3 = Color3.fromRGB(22, 22, 26); card.LayoutOrder = i; card.BorderSizePixel = 0
			local cStrk = Instance.new("UIStroke", card); cStrk.Color = UIHelpers.Colors.BorderMuted
			local iconBg = Instance.new("Frame", card); iconBg.Size = UDim2.new(0, 45, 0, 45); iconBg.Position = UDim2.new(0, 10, 0.5, 0); iconBg.AnchorPoint = Vector2.new(0, 0.5); iconBg.BackgroundColor3 = Color3.fromRGB(15, 15, 18); iconBg.BorderSizePixel = 0
			local iIcon = Instance.new("ImageLabel", iconBg); iIcon.Size = UDim2.new(1, 0, 1, 0); iIcon.BackgroundTransparency = 1; iIcon.ScaleType = Enum.ScaleType.Crop; iIcon.Image = config.Icon
			local cName = UIHelpers.CreateLabel(card, config.Name, UDim2.new(0.5, 0, 0, 20), Enum.Font.GothamBlack, UIHelpers.Colors.TextWhite, 14); cName.Position = UDim2.new(0, 65, 0, 10); cName.TextXAlignment = Enum.TextXAlignment.Left

			if not isUnlocked then
				cName.TextColor3 = UIHelpers.Colors.TextMuted
				local lockLbl = UIHelpers.CreateLabel(card, "LOCKED - COST: " .. FormatNumber(config.Cost), UDim2.new(0.6, 0, 0, 20), Enum.Font.GothamMedium, UIHelpers.Colors.TextMuted, 11); lockLbl.Position = UDim2.new(0, 65, 0, 30); lockLbl.TextXAlignment = Enum.TextXAlignment.Left
				local unlBtn = CreateSharpButton(card, "RECRUIT", UDim2.new(0, 75, 0, 30), Enum.Font.GothamBlack, 11); unlBtn.Position = UDim2.new(1, -10, 0.5, 0); unlBtn.AnchorPoint = Vector2.new(1, 0.5)
				unlBtn.MouseButton1Click:Connect(function() Network:WaitForChild("DispatchAction"):FireServer("UnlockAlly", config.Name) end)
			else
				local lvlLbl = UIHelpers.CreateLabel(card, "LEVEL " .. lvl, UDim2.new(0.5, 0, 0, 20), Enum.Font.GothamBold, UIHelpers.Colors.Gold, 12); lvlLbl.Position = UDim2.new(0, 65, 0, 30); lvlLbl.TextXAlignment = Enum.TextXAlignment.Left
				if isDeployed then
					card.BackgroundColor3 = Color3.fromRGB(20, 35, 20); cStrk.Color = Color3.fromRGB(50, 150, 50)
					lvlLbl.Text = "GATHERING... 00:00"; lvlLbl.TextColor3 = Color3.fromRGB(100, 255, 100)
					ActiveTimers[config.Name] = {Label = lvlLbl, StartTime = dData[config.Name].StartTime}
					local recBtn = CreateSharpButton(card, "RECALL", UDim2.new(0, 75, 0, 30), Enum.Font.GothamBlack, 11); recBtn.Position = UDim2.new(1, -10, 0.5, 0); recBtn.AnchorPoint = Vector2.new(1, 0.5); recBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
					recBtn.MouseButton1Click:Connect(function() Network:WaitForChild("DispatchAction"):FireServer("Recall", config.Name) end)
				else
					local depBtn = CreateSharpButton(card, "DEPLOY", UDim2.new(0, 65, 0, 26), Enum.Font.GothamBlack, 11); depBtn.Position = UDim2.new(1, -10, 0.5, 0); depBtn.AnchorPoint = Vector2.new(1, 0.5)
					depBtn.MouseButton1Click:Connect(function() Network:WaitForChild("DispatchAction"):FireServer("Deploy", config.Name) end)

					if lvl < 10 then
						local upgCost = 5000 * lvl
						local upgBtn = CreateSharpButton(card, "UPG (" .. FormatNumber(upgCost) .. ")", UDim2.new(0, 85, 0, 26), Enum.Font.GothamBold, 10); upgBtn.Position = UDim2.new(1, -85, 0.5, 0); upgBtn.AnchorPoint = Vector2.new(1, 0.5); upgBtn.TextColor3 = UIHelpers.Colors.Gold
						upgBtn.MouseButton1Click:Connect(function() Network:WaitForChild("DispatchAction"):FireServer("UpgradeAlly", config.Name) end)
					else
						local maxLbl = UIHelpers.CreateLabel(card, "MAX LEVEL", UDim2.new(0, 85, 0, 26), Enum.Font.GothamBold, UIHelpers.Colors.Gold, 10); maxLbl.Position = UDim2.new(1, -85, 0.5, 0); maxLbl.AnchorPoint = Vector2.new(1, 0.5)
					end
				end
			end
		end
	end

	task.spawn(function()
		while true do
			task.wait(1)
			if parentFrame.Visible then
				local now = os.time()
				for _, tData in pairs(ActiveTimers) do
					local elapsed = now - tData.StartTime
					local isCapped = false
					if elapsed >= 43200 then
						elapsed = 43200
						isCapped = true
					end
					local mins = math.floor(elapsed / 60)
					local secs = elapsed % 60
					if isCapped then
						tData.Label.Text = string.format("MAX CAPACITY! %02d:%02d", mins, secs)
						tData.Label.TextColor3 = Color3.fromRGB(255, 200, 50)
					else
						tData.Label.Text = string.format("GATHERING... %02d:%02d", mins, secs)
					end
				end
			end
		end
	end)

	player.AttributeChanged:Connect(function(attr)
		if attr == "DispatchData" or attr == "UnlockedAllies" or attr == "AllyLevels" or attr == "MaxDeployments" then
			if parentFrame.Visible then UpdateAFKUI() end
		end
	end)

	parentFrame:GetPropertyChangedSignal("Visible"):Connect(function() if parentFrame.Visible then UpdateAFKUI() end end)

	camera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateLayoutForScreen)
	UpdateLayoutForScreen()
end

return AFKTab