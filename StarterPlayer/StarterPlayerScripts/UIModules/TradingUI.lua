-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local TradingUI = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = ReplicatedStorage:WaitForChild("Network")
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))

local VFXManager = require(script.Parent.Parent:WaitForChild("VFXManager"))

local SharedUI = script.Parent.Parent:WaitForChild("SharedUI")
local UIHelpers = require(SharedUI:WaitForChild("UIHelpers"))

-- [[ FIX: Directly require TooltipManager ]]
local tooltipModule = SharedUI:WaitForChild("TooltipManager", 2)
local TooltipManager = tooltipModule and require(tooltipModule) or nil

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local TradeAction = Network:WaitForChild("TradeAction")

local MasterGui = nil
local RequestContainer = nil
local TradeOverlay = nil
local TradePanel = nil

local SplitFrame, spLayout, LeftPanel, RightPanel
local MyOfferGrid, TheirOfferGrid
local MyDewsInput, TheirDewsLbl
local MyStatusLbl, TheirStatusLbl
local ReadyBtn, CancelBtn
local InventoryGrid
local OpponentNameLbl

local CountdownOverlay, CountdownText

local isReady = false

local RARITY_COLORS = {
	Common = "#A0A0A0",
	Uncommon = "#55FF55",
	Rare = "#55AAFF",
	Epic = "#AA55FF",
	Legendary = "#FFD700",
	Mythical = "#FF5555"
}

local function GetItemRarity(itemName)
	local data = ItemData.Equipment[itemName] or ItemData.Consumables[itemName]
	if data and data.Rarity then return data.Rarity end
	return "Common"
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

local function CreateSharpButton(parent, text, size, font, textSize, hexColor)
	local btn = Instance.new("TextButton", parent)
	btn.Size = size; btn.BackgroundColor3 = Color3.fromRGB(28, 28, 34); btn.BorderSizePixel = 0; btn.AutoButtonColor = false; btn.Font = font; btn.TextColor3 = Color3.fromHex(hexColor:gsub("#","")); btn.TextSize = textSize; btn.Text = text
	local stroke = Instance.new("UIStroke", btn); stroke.Color = Color3.fromHex(hexColor:gsub("#","")); stroke.Thickness = 2; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	btn.InputBegan:Connect(function() if btn.Active then stroke.Color = UIHelpers.Colors.TextWhite; btn.TextColor3 = UIHelpers.Colors.TextWhite end end)
	btn.InputEnded:Connect(function() if btn.Active then stroke.Color = Color3.fromHex(hexColor:gsub("#","")); btn.TextColor3 = Color3.fromHex(hexColor:gsub("#","")) end end)
	return btn, stroke
end

local function CreateItemCard(parent, itemName, amount, isInventory)
	local rarity = GetItemRarity(itemName)
	local rColor = RARITY_COLORS[rarity] or "#FFFFFF"
	local itemDataInfo = (ItemData.Equipment and ItemData.Equipment[itemName]) or (ItemData.Consumables and ItemData.Consumables[itemName]) or {}

	local card, stroke = CreateSharpButton(parent, "", UDim2.new(0, 0, 0, 0), Enum.Font.GothamBold, 12, rColor)
	card.BackgroundColor3 = Color3.fromRGB(25, 25, 30)

	local nameLbl = UIHelpers.CreateLabel(card, itemName, UDim2.new(1, -10, 0.6, 0), Enum.Font.GothamBold, Color3.fromHex(rColor:gsub("#","")), 12)
	nameLbl.Position = UDim2.new(0.5, 0, 0.1, 0); nameLbl.AnchorPoint = Vector2.new(0.5, 0); nameLbl.TextWrapped = true; nameLbl.TextScaled = true
	local nCon = Instance.new("UITextSizeConstraint", nameLbl); nCon.MaxTextSize = 14; nCon.MinTextSize = 9

	local amtLbl = UIHelpers.CreateLabel(card, "x" .. amount, UDim2.new(1, 0, 0.3, 0), Enum.Font.GothamBlack, UIHelpers.Colors.TextWhite, 14)
	amtLbl.Position = UDim2.new(0.5, 0, 0.95, 0); amtLbl.AnchorPoint = Vector2.new(0.5, 1)

	local tTipStr = "<font color='" .. rColor .. "'>[" .. rarity .. "]</font> <b>" .. itemName .. "</b>"
	if itemDataInfo.Desc then
		tTipStr = tTipStr .. "\n<font color='#AAAAAA'>" .. itemDataInfo.Desc .. "</font>"
	end
	if itemDataInfo.Bonus then
		tTipStr = tTipStr .. "\n\n<font color='#55FF55'><b>[ Stat Bonuses ]</b></font>"
		for stat, val in pairs(itemDataInfo.Bonus) do
			local prefix = val >= 0 and "+" or ""
			tTipStr = tTipStr .. "\n<font color='#FFFFFF'>" .. prefix .. val .. " " .. stat .. "</font>"
		end
	end

	card.MouseEnter:Connect(function() 
		if TooltipManager and type(TooltipManager.Show) == "function" then TooltipManager.Show(tTipStr) end 
	end)
	card.MouseLeave:Connect(function() 
		if TooltipManager and type(TooltipManager.Hide) == "function" then TooltipManager.Hide() end 
	end)

	if isInventory then
		card.MouseButton1Click:Connect(function()
			if not isReady then TradeAction:FireServer("UpdateOffer", {ItemName = itemName, Amount = 1}) end
		end)
	else
		card.MouseButton1Click:Connect(function()
			if not isReady then TradeAction:FireServer("UpdateOffer", {ItemName = itemName, Amount = -1}) end
		end)
	end

	return card
end

local function RefreshInventory()
	for _, c in ipairs(InventoryGrid:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end

	local function ScanItems(dictionary)
		for itemName, _ in pairs(dictionary) do
			local safeName = itemName:gsub("[^%w]", "") .. "Count"
			local count = player:GetAttribute(safeName) or 0
			if count > 0 then
				CreateItemCard(InventoryGrid, itemName, count, true)
			end
		end
	end

	if type(ItemData) == "table" then
		ScanItems(ItemData.Equipment or {})
		ScanItems(ItemData.Consumables or {})
	end
end

local function RenderOfferGrid(gridFrame, offerData, isMine)
	for _, c in ipairs(gridFrame:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
	for itemName, amount in pairs(offerData.Items or {}) do
		CreateItemCard(gridFrame, itemName, amount, not isMine) 
	end
end

local function UpdateLayoutForScreen()
	local vp = camera.ViewportSize
	if vp.X == 0 or vp.Y == 0 or not TradePanel then return end
	local isMobile = (vp.X <= 850) or (vp.Y > vp.X)

	if isMobile then
		TradePanel.Size = UDim2.new(0.98, 0, 0.95, 0)
		if spLayout then spLayout.FillDirection = Enum.FillDirection.Horizontal end
		if LeftPanel then LeftPanel.Size = UDim2.new(0.5, -2, 1, 0) end
		if RightPanel then RightPanel.Size = UDim2.new(0.5, -2, 1, 0) end

		local mGrid = MyOfferGrid and MyOfferGrid:FindFirstChildOfClass("UIGridLayout")
		if mGrid then mGrid.CellSize = UDim2.new(0, 50, 0, 50) end
		local tGrid = TheirOfferGrid and TheirOfferGrid:FindFirstChildOfClass("UIGridLayout")
		if tGrid then tGrid.CellSize = UDim2.new(0, 50, 0, 50) end
		local iGrid = InventoryGrid and InventoryGrid:FindFirstChildOfClass("UIGridLayout")
		if iGrid then iGrid.CellSize = UDim2.new(0, 50, 0, 50) end
	else
		TradePanel.Size = UDim2.new(0.85, 0, 0.85, 0)
		if spLayout then spLayout.FillDirection = Enum.FillDirection.Horizontal end
		if LeftPanel then LeftPanel.Size = UDim2.new(0.5, -5, 1, 0) end
		if RightPanel then RightPanel.Size = UDim2.new(0.5, -5, 1, 0) end

		local mGrid = MyOfferGrid and MyOfferGrid:FindFirstChildOfClass("UIGridLayout")
		if mGrid then mGrid.CellSize = UDim2.new(0, 80, 0, 80) end
		local tGrid = TheirOfferGrid and TheirOfferGrid:FindFirstChildOfClass("UIGridLayout")
		if tGrid then tGrid.CellSize = UDim2.new(0, 80, 0, 80) end
		local iGrid = InventoryGrid and InventoryGrid:FindFirstChildOfClass("UIGridLayout")
		if iGrid then iGrid.CellSize = UDim2.new(0, 80, 0, 80) end
	end
end

local function BuildTradingUI()
	RequestContainer = Instance.new("Frame", MasterGui)
	RequestContainer.Size = UDim2.new(0, 300, 0, 400); RequestContainer.Position = UDim2.new(1, -20, 0, 80); RequestContainer.AnchorPoint = Vector2.new(1, 0); RequestContainer.BackgroundTransparency = 1; RequestContainer.ZIndex = 200
	local reqLayout = Instance.new("UIListLayout", RequestContainer); reqLayout.Padding = UDim.new(0, 10); reqLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right

	TradeOverlay = Instance.new("Frame", MasterGui)
	TradeOverlay.Size = UDim2.new(1, 0, 1, 0); TradeOverlay.BackgroundColor3 = Color3.new(0,0,0); TradeOverlay.BackgroundTransparency = 0.5; TradeOverlay.ZIndex = 250; TradeOverlay.Visible = false; TradeOverlay.Active = true

	TradePanel, _ = CreateGrimPanel(TradeOverlay)
	TradePanel.Size = UDim2.new(0.85, 0, 0.85, 0); TradePanel.Position = UDim2.new(0.5, 0, 0.5, 0); TradePanel.AnchorPoint = Vector2.new(0.5, 0.5); TradePanel.ZIndex = 251

	local uiSize = Instance.new("UISizeConstraint", TradePanel)
	uiSize.MaxSize = Vector2.new(1000, 700)
	uiSize.MinSize = Vector2.new(350, 450)

	local Header = UIHelpers.CreateLabel(TradePanel, "SECURE TRADE", UDim2.new(1, 0, 0, 40), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 22); Header.ZIndex = 252

	local HeaderCancelBtn = CreateSharpButton(TradePanel, "X", UDim2.new(0, 40, 0, 40), Enum.Font.GothamBlack, 18, "#FF5555")
	HeaderCancelBtn.Position = UDim2.new(1, -10, 0, 10); HeaderCancelBtn.AnchorPoint = Vector2.new(1, 0); HeaderCancelBtn.ZIndex = 252
	HeaderCancelBtn.MouseButton1Click:Connect(function() TradeAction:FireServer("Cancel") end)

	SplitFrame = Instance.new("Frame", TradePanel)
	SplitFrame.Size = UDim2.new(1, -20, 1, -120); SplitFrame.Position = UDim2.new(0, 10, 0, 50); SplitFrame.BackgroundTransparency = 1; SplitFrame.ZIndex = 252
	spLayout = Instance.new("UIListLayout", SplitFrame); spLayout.FillDirection = Enum.FillDirection.Horizontal; spLayout.Padding = UDim.new(0, 10)

	LeftPanel, _ = CreateGrimPanel(SplitFrame)
	LeftPanel.Size = UDim2.new(0.5, -5, 1, 0); LeftPanel.BackgroundColor3 = Color3.fromRGB(22, 22, 26); LeftPanel.ZIndex = 253

	local lTitle = UIHelpers.CreateLabel(LeftPanel, "YOUR OFFER", UDim2.new(1, 0, 0, 30), Enum.Font.GothamBlack, UIHelpers.Colors.TextWhite, 16); lTitle.ZIndex = 254

	MyDewsInput = Instance.new("TextBox", LeftPanel)
	MyDewsInput.Size = UDim2.new(0.9, 0, 0, 35); MyDewsInput.Position = UDim2.new(0.5, 0, 0, 35); MyDewsInput.AnchorPoint = Vector2.new(0.5, 0); MyDewsInput.BackgroundColor3 = Color3.fromRGB(15, 15, 18); MyDewsInput.TextColor3 = Color3.fromRGB(255, 136, 255); MyDewsInput.Font = Enum.Font.GothamBlack; MyDewsInput.TextSize = 14; MyDewsInput.PlaceholderText = "Add Dews..."; MyDewsInput.Text = ""; MyDewsInput.ZIndex = 254
	Instance.new("UICorner", MyDewsInput).CornerRadius = UDim.new(0, 4)
	Instance.new("UIStroke", MyDewsInput).Color = Color3.fromRGB(45, 45, 50)
	MyDewsInput.FocusLost:Connect(function()
		local amount = tonumber(MyDewsInput.Text) or 0
		TradeAction:FireServer("UpdateOffer", {Dews = amount})
	end)

	local OffTitle = UIHelpers.CreateLabel(LeftPanel, "Offered Items (Tap to Remove)", UDim2.new(1, 0, 0, 20), Enum.Font.GothamBold, UIHelpers.Colors.TextMuted, 12); OffTitle.Position = UDim2.new(0, 0, 0, 75); OffTitle.ZIndex = 254

	MyOfferGrid = Instance.new("ScrollingFrame", LeftPanel)
	MyOfferGrid.Size = UDim2.new(0.95, 0, 0.4, 0); MyOfferGrid.Position = UDim2.new(0.5, 0, 0, 95); MyOfferGrid.AnchorPoint = Vector2.new(0.5, 0); MyOfferGrid.BackgroundTransparency = 1; MyOfferGrid.ScrollBarThickness = 4; MyOfferGrid.BorderSizePixel = 0; MyOfferGrid.ZIndex = 254
	local moLayout = Instance.new("UIGridLayout", MyOfferGrid); moLayout.CellSize = UDim2.new(0, 80, 0, 80); moLayout.CellPadding = UDim2.new(0, 8, 0, 8); moLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	moLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() MyOfferGrid.CanvasSize = UDim2.new(0,0,0, moLayout.AbsoluteContentSize.Y + 10) end)

	local InvTitle = UIHelpers.CreateLabel(LeftPanel, "Your Inventory (Tap to Offer)", UDim2.new(1, 0, 0, 20), Enum.Font.GothamBold, UIHelpers.Colors.TextMuted, 12); InvTitle.Position = UDim2.new(0, 0, 0.4, 100); InvTitle.ZIndex = 254

	InventoryGrid = Instance.new("ScrollingFrame", LeftPanel)
	InventoryGrid.Size = UDim2.new(0.95, 0, 0.6, -165); InventoryGrid.Position = UDim2.new(0.5, 0, 0.4, 120); InventoryGrid.AnchorPoint = Vector2.new(0.5, 0); InventoryGrid.BackgroundTransparency = 1; InventoryGrid.ScrollBarThickness = 4; InventoryGrid.BorderSizePixel = 0; InventoryGrid.ZIndex = 254
	local igLayout = Instance.new("UIGridLayout", InventoryGrid); igLayout.CellSize = UDim2.new(0, 80, 0, 80); igLayout.CellPadding = UDim2.new(0, 8, 0, 8); igLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	igLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() InventoryGrid.CanvasSize = UDim2.new(0,0,0, igLayout.AbsoluteContentSize.Y + 10) end)

	MyStatusLbl = UIHelpers.CreateLabel(LeftPanel, "NOT READY", UDim2.new(1, 0, 0, 30), Enum.Font.GothamBlack, Color3.fromRGB(255, 85, 85), 18); MyStatusLbl.Position = UDim2.new(0, 0, 1, -35); MyStatusLbl.ZIndex = 254

	RightPanel, _ = CreateGrimPanel(SplitFrame)
	RightPanel.Size = UDim2.new(0.5, -5, 1, 0); RightPanel.BackgroundColor3 = Color3.fromRGB(22, 22, 26); RightPanel.ZIndex = 253

	OpponentNameLbl = UIHelpers.CreateLabel(RightPanel, "OPPONENT'S OFFER", UDim2.new(1, 0, 0, 30), Enum.Font.GothamBlack, UIHelpers.Colors.TextWhite, 16); OpponentNameLbl.ZIndex = 254

	TheirDewsLbl = UIHelpers.CreateLabel(RightPanel, "0 Dews", UDim2.new(0.9, 0, 0, 35), Enum.Font.GothamBlack, Color3.fromRGB(255, 136, 255), 20); TheirDewsLbl.Position = UDim2.new(0.5, 0, 0, 35); TheirDewsLbl.AnchorPoint = Vector2.new(0.5, 0); TheirDewsLbl.ZIndex = 254

	TheirOfferGrid = Instance.new("ScrollingFrame", RightPanel)
	TheirOfferGrid.Size = UDim2.new(0.95, 0, 1, -120); TheirOfferGrid.Position = UDim2.new(0.5, 0, 0, 80); TheirOfferGrid.AnchorPoint = Vector2.new(0.5, 0); TheirOfferGrid.BackgroundTransparency = 1; TheirOfferGrid.ScrollBarThickness = 4; TheirOfferGrid.BorderSizePixel = 0; TheirOfferGrid.ZIndex = 254
	local toLayout = Instance.new("UIGridLayout", TheirOfferGrid); toLayout.CellSize = UDim2.new(0, 80, 0, 80); toLayout.CellPadding = UDim2.new(0, 8, 0, 8); toLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	toLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() TheirOfferGrid.CanvasSize = UDim2.new(0,0,0, toLayout.AbsoluteContentSize.Y + 10) end)

	TheirStatusLbl = UIHelpers.CreateLabel(RightPanel, "NOT READY", UDim2.new(1, 0, 0, 30), Enum.Font.GothamBlack, Color3.fromRGB(255, 85, 85), 18); TheirStatusLbl.Position = UDim2.new(0, 0, 1, -35); TheirStatusLbl.ZIndex = 254

	ReadyBtn = CreateSharpButton(TradePanel, "READY UP", UDim2.new(0, 200, 0, 50), Enum.Font.GothamBlack, 16, "#FFD700")
	ReadyBtn.Position = UDim2.new(0.5, 0, 1, -35); ReadyBtn.AnchorPoint = Vector2.new(0.5, 0.5); ReadyBtn.ZIndex = 252
	ReadyBtn.MouseButton1Click:Connect(function() TradeAction:FireServer("ToggleReady") end)

	CountdownOverlay = Instance.new("Frame", TradePanel)
	CountdownOverlay.Size = UDim2.new(1, 0, 1, 0); CountdownOverlay.BackgroundColor3 = Color3.new(0,0,0); CountdownOverlay.BackgroundTransparency = 0.4; CountdownOverlay.ZIndex = 260; CountdownOverlay.Visible = false; CountdownOverlay.Active = true

	CountdownText = UIHelpers.CreateLabel(CountdownOverlay, "TRADING IN 10...", UDim2.new(1, 0, 0, 100), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 48); CountdownText.Position = UDim2.new(0.5, 0, 0.4, 0); CountdownText.AnchorPoint = Vector2.new(0.5, 0.5); CountdownText.ZIndex = 261

	CancelBtn = CreateSharpButton(CountdownOverlay, "ABORT TRADE", UDim2.new(0, 300, 0, 60), Enum.Font.GothamBlack, 22, "#FF5555")
	CancelBtn.Position = UDim2.new(0.5, 0, 0.7, 0); CancelBtn.AnchorPoint = Vector2.new(0.5, 0.5); CancelBtn.ZIndex = 261
	CancelBtn.MouseButton1Click:Connect(function() TradeAction:FireServer("ToggleReady") end)

	camera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateLayoutForScreen)
	UpdateLayoutForScreen()
end

function TradingUI.Initialize(masterScreenGui)
	MasterGui = masterScreenGui
	BuildTradingUI()

	TradeAction.OnClientEvent:Connect(function(action, d1, d2, d3)
		if action == "IncomingRequest" then
			local senderId, senderName = d1, d2
			local reqCard, _ = CreateGrimPanel(RequestContainer)
			reqCard.Size = UDim2.new(1, 0, 0, 80)

			local rLbl = UIHelpers.CreateLabel(reqCard, senderName .. " wants to trade!", UDim2.new(1, -10, 0, 30), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 14)
			rLbl.Position = UDim2.new(0, 5, 0, 5)

			local accBtn = CreateSharpButton(reqCard, "ACCEPT", UDim2.new(0.4, 0, 0, 30), Enum.Font.GothamBlack, 12, "#55FF55")
			accBtn.Position = UDim2.new(0.1, 0, 1, -10); accBtn.AnchorPoint = Vector2.new(0, 1)

			local denBtn = CreateSharpButton(reqCard, "DENY", UDim2.new(0.4, 0, 0, 30), Enum.Font.GothamBlack, 12, "#FF5555")
			denBtn.Position = UDim2.new(0.9, 0, 1, -10); denBtn.AnchorPoint = Vector2.new(1, 1)

			accBtn.MouseButton1Click:Connect(function() reqCard:Destroy(); TradeAction:FireServer("ManageRequest", {SenderId = senderId, Decision = "Accept"}) end)
			denBtn.MouseButton1Click:Connect(function() reqCard:Destroy(); TradeAction:FireServer("ManageRequest", {SenderId = senderId, Decision = "Deny"}) end)

			task.delay(15, function() if reqCard and reqCard.Parent then reqCard:Destroy() end end)

		elseif action == "TradeOpened" then
			local tradeData = d1
			isReady = false
			MyDewsInput.Text = ""
			TheirDewsLbl.Text = "0 Dews"
			OpponentNameLbl.Text = string.upper(tradeData.Opponent) .. "'S OFFER"

			MyStatusLbl.Text = "NOT READY"; MyStatusLbl.TextColor3 = Color3.fromRGB(255, 85, 85)
			TheirStatusLbl.Text = "NOT READY"; TheirStatusLbl.TextColor3 = Color3.fromRGB(255, 85, 85)

			ReadyBtn.Text = "READY UP"
			ReadyBtn.TextColor3 = UIHelpers.Colors.Gold
			ReadyBtn:FindFirstChild("UIStroke").Color = UIHelpers.Colors.Gold

			CountdownOverlay.Visible = false

			RenderOfferGrid(MyOfferGrid, {Items={}}, true)
			RenderOfferGrid(TheirOfferGrid, {Items={}}, false)
			RefreshInventory()
			TradeOverlay.Visible = true

		elseif action == "UpdateOffers" then
			local myOffer, theirOffer = d1, d2
			MyDewsInput.Text = tostring(myOffer.Dews)
			TheirDewsLbl.Text = tostring(theirOffer.Dews) .. " Dews"
			RenderOfferGrid(MyOfferGrid, myOffer, true)
			RenderOfferGrid(TheirOfferGrid, theirOffer, false)
			RefreshInventory()

		elseif action == "UpdateStatus" then
			local myReady, theirReady = d1, d2
			isReady = myReady

			if myReady then MyStatusLbl.Text = "READY"; MyStatusLbl.TextColor3 = Color3.fromRGB(85, 255, 85)
			else MyStatusLbl.Text = "NOT READY"; MyStatusLbl.TextColor3 = Color3.fromRGB(255, 85, 85) end

			if theirReady then TheirStatusLbl.Text = "READY"; TheirStatusLbl.TextColor3 = Color3.fromRGB(85, 255, 85)
			else TheirStatusLbl.Text = "NOT READY"; TheirStatusLbl.TextColor3 = Color3.fromRGB(255, 85, 85) end

			if myReady then
				ReadyBtn.Text = "UN-READY"
				ReadyBtn.TextColor3 = Color3.fromRGB(255, 85, 85)
				ReadyBtn:FindFirstChild("UIStroke").Color = Color3.fromRGB(255, 85, 85)
			else
				ReadyBtn.Text = "READY UP"
				ReadyBtn.TextColor3 = UIHelpers.Colors.Gold
				ReadyBtn:FindFirstChild("UIStroke").Color = UIHelpers.Colors.Gold
			end

		elseif action == "StartCountdown" then
			CountdownText.Text = "TRADING IN 10..."
			CountdownOverlay.Visible = true
			if VFXManager and type(VFXManager.PlaySFX) == "function" then VFXManager.PlaySFX("Click", 1.5) end

		elseif action == "UpdateTimer" then
			local timeLeft = d1
			CountdownText.Text = "TRADING IN " .. timeLeft .. "..."
			if VFXManager and type(VFXManager.PlaySFX) == "function" then VFXManager.PlaySFX("Click", 1.5 + (0.05 * (10-timeLeft))) end

		elseif action == "CountdownAborted" then
			CountdownOverlay.Visible = false
			if VFXManager and type(VFXManager.PlaySFX) == "function" then VFXManager.PlaySFX("Error", 1.0) end

		elseif action == "TradeClosed" then
			TradeOverlay.Visible = false
			CountdownOverlay.Visible = false
		end
	end)
end

return TradingUI