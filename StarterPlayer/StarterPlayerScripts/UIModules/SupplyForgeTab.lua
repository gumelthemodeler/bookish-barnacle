-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local SupplyForgeTab = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Network = ReplicatedStorage:WaitForChild("Network")

local SharedUI = script.Parent.Parent:WaitForChild("SharedUI")
local UIHelpers = require(SharedUI:WaitForChild("UIHelpers"))
local notifModule = SharedUI:WaitForChild("NotificationManager", 2)
local NotificationManager = notifModule and require(notifModule) or nil
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))
local TitanData = require(ReplicatedStorage:WaitForChild("TitanData")) 
local ClanData = require(ReplicatedStorage:WaitForChild("ClanData"))
local hasSkillData, SkillData = pcall(function() return require(ReplicatedStorage:WaitForChild("SkillData")) end)
local VFXManager = require(script.Parent.Parent:WaitForChild("VFXManager"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CONFIG = {
	RarityColors = {
		Common = Color3.fromRGB(200, 200, 200), Uncommon = Color3.fromRGB(85, 255, 85),
		Rare = Color3.fromRGB(85, 85, 255), Epic = Color3.fromRGB(170, 85, 255),
		Legendary = Color3.fromRGB(255, 215, 0), Mythical = Color3.fromRGB(255, 85, 85),
		Transcendent = Color3.fromRGB(255, 85, 255)
	},
	RarityOrder = { Transcendent = 1, Mythical = 2, Legendary = 3, Epic = 4, Rare = 5, Uncommon = 6, Common = 7 },
	TitanVariants = {
		["Standard"] = { Color = "#FFFFFF", Desc = "Standard shifting properties." },
		["Titan Hardening"] = { Color = "#E6E6FA", Desc = "Calcified white plating. +10% Armor." },
		["Crimson Steam"] = { Color = "#FF3333", Desc = "Boiling blood-red steam. +10% Fire Damage." },
		["Abyssal Eyes"] = { Color = "#AA55FF", Desc = "Pitch black eyes. +10% Precision." },
		["Beast Fur"] = { Color = "#8B4513", Desc = "Thick localized fur. +10% Cold Resist." },
		["Crystalline Nape"] = { Color = "#55FFFF", Desc = "Naturally hardened nape. +15% Nape Defense." }
	}
}

local function NotifySafe(msg, typeStr)
	if NotificationManager and type(NotificationManager.Show) == "function" then
		NotificationManager.Show(msg, typeStr)
	else
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = typeStr == "Error" and "ERROR" or "SYSTEM",
			Text = msg,
			Duration = 4
		})
	end
end

local function ColorToHex(c3)
	return string.format("#%02X%02X%02X", math.floor(c3.R * 255), math.floor(c3.G * 255), math.floor(c3.B * 255))
end

local function GetItemCount(matName)
	local safe1 = matName:gsub("[^%w]", "") .. "Count"
	local safe2 = matName:gsub("[^%w]", "")
	local safe3 = matName .. "Count"
	local safe4 = matName
	return tonumber(player:GetAttribute(safe1)) or 
		tonumber(player:GetAttribute(safe2)) or 
		tonumber(player:GetAttribute(safe3)) or 
		tonumber(player:GetAttribute(safe4)) or 0
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
			btn:SetAttribute("OrigColor", btn.TextColor3)
			btn:SetAttribute("OrigStroke", stroke.Color)
			stroke.Color = UIHelpers.Colors.Gold
			btn.TextColor3 = UIHelpers.Colors.Gold 
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
	if vp.X == 0 or vp.Y == 0 then return end
	local isMobile = (vp.X <= 850) or (vp.Y > vp.X)

	-- [[ FIX: Added strict dynamic size assignments to handle wrapping properly ]]
	if LayoutRefs.MarketLayout then LayoutRefs.MarketLayout.FillDirection = isMobile and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal end
	if LayoutRefs.MarketLeft then LayoutRefs.MarketLeft.Size = isMobile and UDim2.new(0.95, 0, 0, 360) or UDim2.new(0.48, 0, 0, 400) end
	if LayoutRefs.MarketRight then LayoutRefs.MarketRight.Size = isMobile and UDim2.new(0.95, 0, 0, 320) or UDim2.new(0.48, 0, 0, 400) end

	if LayoutRefs.TradeLayout then LayoutRefs.TradeLayout.FillDirection = isMobile and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal end
	if LayoutRefs.TradeLeft then LayoutRefs.TradeLeft.Size = isMobile and UDim2.new(0.95, 0, 0, 260) or UDim2.new(0.48, 0, 0, 280) end
	if LayoutRefs.TradeRight then LayoutRefs.TradeRight.Size = isMobile and UDim2.new(0.95, 0, 0, 220) or UDim2.new(0.48, 0, 0, 280) end

	if LayoutRefs.ForgeLayout then LayoutRefs.ForgeLayout.FillDirection = isMobile and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal end
	if LayoutRefs.ForgeLeft then LayoutRefs.ForgeLeft.Size = isMobile and UDim2.new(0.95, 0, 0, 350) or UDim2.new(0.35, 0, 0, 500) end
	if LayoutRefs.ForgeRight then LayoutRefs.ForgeRight.Size = isMobile and UDim2.new(0.95, 0, 0, 400) or UDim2.new(0.63, 0, 0, 500) end

	if LayoutRefs.TitanLayout then LayoutRefs.TitanLayout.FillDirection = isMobile and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal end
	if LayoutRefs.TitanLeft then LayoutRefs.TitanLeft.Size = isMobile and UDim2.new(0.95, 0, 0, 420) or UDim2.new(0.5, 0, 0, 450) end
	if LayoutRefs.TitanRight then LayoutRefs.TitanRight.Size = isMobile and UDim2.new(0.95, 0, 0, 260) or UDim2.new(0.48, 0, 0, 450) end
end

function SupplyForgeTab.Initialize(parentFrame)
	for _, child in ipairs(parentFrame:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end

	local MainFrame = Instance.new("ScrollingFrame", parentFrame)
	MainFrame.Size = UDim2.new(1, 0, 1, 0)
	MainFrame.BackgroundTransparency = 1
	MainFrame.ScrollBarThickness = 6
	MainFrame.BorderSizePixel = 0

	local mLayout = Instance.new("UIListLayout", MainFrame)
	mLayout.SortOrder = Enum.SortOrder.LayoutOrder
	mLayout.Padding = UDim.new(0, 15)
	mLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local mPad = Instance.new("UIPadding", MainFrame)
	mPad.PaddingTop = UDim.new(0, 15)
	mPad.PaddingBottom = UDim.new(0, 25)

	mLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		MainFrame.CanvasSize = UDim2.new(0, 0, 0, mLayout.AbsoluteContentSize.Y + 20)
	end)

	local SubNav = Instance.new("Frame", MainFrame)
	SubNav.Size = UDim2.new(0.95, 0, 0, 45)
	SubNav.BackgroundTransparency = 1
	SubNav.LayoutOrder = 1

	local navLayout = Instance.new("UIListLayout", SubNav)
	navLayout.FillDirection = Enum.FillDirection.Horizontal
	navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	navLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	navLayout.Padding = UDim.new(0, 10)

	local ContentArea = Instance.new("Frame", MainFrame)
	ContentArea.Size = UDim2.new(0.95, 0, 0, 0)
	ContentArea.BackgroundTransparency = 1
	ContentArea.LayoutOrder = 2
	ContentArea.AutomaticSize = Enum.AutomaticSize.Y -- [[ FIX: Added AutomaticSize so content stretches vertically ]]

	local contentLayout = Instance.new("UIListLayout", ContentArea)

	local subTabs = { "MARKET & TRADE", "THE FORGE", "TITAN LAB" }
	local activeSubFrames = {}
	local subBtns = {}

	for i, tabName in ipairs(subTabs) do
		local btn, stroke = UIHelpers.CreateButton(SubNav, tabName, UDim2.new(0, 140, 0, 30), Enum.Font.GothamBold, 12)
		btn.TextColor3 = UIHelpers.Colors.TextMuted
		stroke.Color = UIHelpers.Colors.BorderMuted

		local subFrame = Instance.new("Frame", ContentArea)
		subFrame.Name = tabName
		subFrame.Size = UDim2.new(1, 0, 0, 0) -- [[ FIX: Stripped fixed height ]]
		subFrame.BackgroundTransparency = 1
		subFrame.AutomaticSize = Enum.AutomaticSize.Y -- [[ FIX: Lets sub-tab dictate scroll height dynamically ]]
		subFrame.Visible = (i == 1)

		activeSubFrames[tabName] = subFrame
		subBtns[tabName] = {Btn = btn, Stroke = stroke}

		btn.MouseButton1Click:Connect(function()
			for name, frame in pairs(activeSubFrames) do frame.Visible = (name == tabName) end
			for name, bData in pairs(subBtns) do
				bData.Btn.TextColor3 = (name == tabName) and UIHelpers.Colors.Gold or UIHelpers.Colors.TextMuted
				bData.Stroke.Color = (name == tabName) and UIHelpers.Colors.Gold or UIHelpers.Colors.BorderMuted
			end
		end)
	end

	subBtns["MARKET & TRADE"].Btn.TextColor3 = UIHelpers.Colors.Gold
	subBtns["MARKET & TRADE"].Stroke.Color = UIHelpers.Colors.Gold

	-- ==========================================
	-- 1. MARKET & TRADE 
	-- ==========================================
	local MTTab = activeSubFrames["MARKET & TRADE"]
	local mtLayout = Instance.new("UIListLayout", MTTab)
	mtLayout.SortOrder = Enum.SortOrder.LayoutOrder
	mtLayout.Padding = UDim.new(0, 10)

	local ShopRow = Instance.new("Frame", MTTab)
	ShopRow.Size = UDim2.new(1, 0, 0, 0)
	ShopRow.AutomaticSize = Enum.AutomaticSize.Y
	ShopRow.BackgroundTransparency = 1
	ShopRow.LayoutOrder = 1
	local srLayout = Instance.new("UIListLayout", ShopRow)
	srLayout.FillDirection = Enum.FillDirection.Horizontal
	srLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	srLayout.Padding = UDim.new(0, 20)

	local MTLeftPanel = Instance.new("Frame", ShopRow); MTLeftPanel.Size = UDim2.new(0.48, 0, 0, 400); MTLeftPanel.BackgroundTransparency = 1
	local shopHeader = UIHelpers.CreateLabel(MTLeftPanel, "MILITARY SUPPLY", UDim2.new(1, 0, 0, 25), Enum.Font.GothamBlack, Color3.fromRGB(85, 255, 85), 16)

	local rrContainer = Instance.new("Frame", MTLeftPanel); rrContainer.Size = UDim2.new(1, 0, 0, 40); rrContainer.Position = UDim2.new(0, 0, 0, 30); rrContainer.BackgroundTransparency = 1
	local rrLayout = Instance.new("UIListLayout", rrContainer); rrLayout.FillDirection = Enum.FillDirection.Horizontal; rrLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; rrLayout.Padding = UDim.new(0, 10)

	local rrDews, rrDewsStroke = CreateSharpButton(rrContainer, "RESTOCK (15K Dews)", UDim2.new(0.48, 0, 1, 0), Enum.Font.GothamBlack, 11); rrDews.TextColor3 = Color3.fromRGB(85, 170, 255); rrDewsStroke.Color = Color3.fromRGB(85, 170, 255)
	local rrPremium, rrPremStroke = CreateSharpButton(rrContainer, "RESTOCK (15 R$)", UDim2.new(0.48, 0, 1, 0), Enum.Font.GothamBlack, 11)

	local restockTimer = UIHelpers.CreateLabel(MTLeftPanel, "RESTOCKS IN: 00:00", UDim2.new(1, 0, 0, 20), Enum.Font.GothamBlack, Color3.fromRGB(255, 150, 100), 12); restockTimer.Position = UDim2.new(0, 0, 0, 75); restockTimer.TextXAlignment = Enum.TextXAlignment.Left

	local SupplyScroll = Instance.new("ScrollingFrame", MTLeftPanel); SupplyScroll.Size = UDim2.new(1, 0, 1, -100); SupplyScroll.Position = UDim2.new(0, 0, 0, 100); SupplyScroll.BackgroundTransparency = 1; SupplyScroll.ScrollBarThickness = 6; SupplyScroll.BorderSizePixel = 0
	local ssLayout = Instance.new("UIListLayout", SupplyScroll); ssLayout.Padding = UDim.new(0, 8)
	ssLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() SupplyScroll.CanvasSize = UDim2.new(0,0,0, ssLayout.AbsoluteContentSize.Y + 10) end)

	local function AddSupplyItem(itemName, itemData, cost, isSoldOut)
		local rarityColor = CONFIG.RarityColors[itemData.Rarity or "Common"] or Color3.fromRGB(200, 200, 200)
		local c = Instance.new("Frame", SupplyScroll); c.Size = UDim2.new(1, -10, 0, 60); c.BackgroundTransparency = 1
		local bgGlow = Instance.new("Frame", c); bgGlow.Size = UDim2.new(1, 0, 1, 0); bgGlow.BackgroundColor3 = rarityColor; bgGlow.BorderSizePixel = 0; bgGlow.ZIndex = 1; local grad = Instance.new("UIGradient", bgGlow); grad.Rotation = 90; grad.Transparency = NumberSequence.new{ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.95), NumberSequenceKeypoint.new(1, 0.7) }
		local cStroke = Instance.new("UIStroke", c); cStroke.Color = rarityColor; cStroke.Thickness = 2; cStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

		local nameLbl = UIHelpers.CreateLabel(c, itemName, UDim2.new(0.6, 0, 0, 20), Enum.Font.GothamBlack, rarityColor, 14); nameLbl.Position = UDim2.new(0, 10, 0, 5); nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.ZIndex = 2
		local costLbl = UIHelpers.CreateLabel(c, "Cost: " .. tostring(cost) .. " Dews", UDim2.new(0.6, 0, 0, 20), Enum.Font.GothamBold, UIHelpers.Colors.TextMuted, 11); costLbl.Position = UDim2.new(0, 10, 1, -25); costLbl.TextXAlignment = Enum.TextXAlignment.Left; costLbl.ZIndex = 2

		local actionText = isSoldOut and "SOLD" or "BUY"
		local buyBtn, buyStroke = CreateSharpButton(c, actionText, UDim2.new(0, 80, 0, 30), Enum.Font.GothamBlack, 12); buyBtn.Position = UDim2.new(1, -10, 0.5, 0); buyBtn.AnchorPoint = Vector2.new(1, 0.5); buyBtn.ZIndex = 3

		if isSoldOut then
			buyBtn.TextColor3 = Color3.fromRGB(100, 100, 100); buyStroke.Color = Color3.fromRGB(70, 70, 80); buyBtn.Active = false
		else
			buyBtn.TextColor3 = Color3.fromRGB(85, 255, 85); buyStroke.Color = Color3.fromRGB(85, 255, 85)
			buyBtn.MouseButton1Click:Connect(function() Network:WaitForChild("ShopAction"):FireServer("BuyItem", itemName) end)
		end
	end

	local isFreeRestock = false
	local function UpdateRerollButton()
		local hasVIP = player:GetAttribute("HasVIP")
		local lastRoll = player:GetAttribute("LastFreeReroll") or 0
		if hasVIP and (os.time() - lastRoll) >= 86400 then
			rrPremium.Text = "FREE RESTOCK"
			rrPremium.TextColor3 = Color3.fromRGB(200, 100, 255); rrPremStroke.Color = Color3.fromRGB(200, 100, 255); isFreeRestock = true
		else
			rrPremium.Text = "RESTOCK (15 R$)"; rrPremium.TextColor3 = Color3.fromRGB(85, 255, 85); rrPremStroke.Color = Color3.fromRGB(85, 255, 85); isFreeRestock = false
		end
	end
	UpdateRerollButton()
	rrDews.MouseButton1Click:Connect(function() Network:WaitForChild("VIPFreeReroll"):FireServer(true) end)
	rrPremium.MouseButton1Click:Connect(function()
		if isFreeRestock then Network:WaitForChild("VIPFreeReroll"):FireServer(false) else
			local rerollId = nil
			if ItemData.Products then for _, prod in ipairs(ItemData.Products) do if prod.IsReroll then rerollId = prod.ID break end end end
			if rerollId then MarketplaceService:PromptProductPurchase(player, rerollId) end
		end
	end)

	local isShopTimerActive = false
	local function RefreshShop()
		local shopData = Network:WaitForChild("GetShopData"):InvokeServer()
		if not shopData or not shopData.Items then return end
		for _, c in ipairs(SupplyScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
		for _, item in ipairs(shopData.Items) do
			local itemDef = ItemData.Equipment[item.Name] or ItemData.Consumables[item.Name]
			if itemDef then AddSupplyItem(item.Name, itemDef, item.Cost, item.SoldOut) end
		end
		local timeLeft = shopData.TimeLeft or 600
		isShopTimerActive = false 
		task.wait(1.1)
		isShopTimerActive = true
		task.spawn(function()
			while timeLeft > 0 and isShopTimerActive do
				local m = math.floor(timeLeft / 60); local s = timeLeft % 60
				restockTimer.Text = string.format("RESTOCKS IN: %02d:%02d", m, s)
				task.wait(1); timeLeft -= 1
			end
			if isShopTimerActive then RefreshShop() end
		end)
	end
	player.AttributeChanged:Connect(function(attr) if attr == "ShopPurchases_Data" or attr == "PersonalShopSeed" then RefreshShop() end; if attr == "LastFreeReroll" or attr == "HasVIP" then UpdateRerollButton() end end)
	RefreshShop()

	-- Premium Store
	local MTRightPanel = Instance.new("Frame", ShopRow); MTRightPanel.Size = UDim2.new(0.48, 0, 0, 400); MTRightPanel.BackgroundTransparency = 1
	local pTitle = UIHelpers.CreateLabel(MTRightPanel, "PREMIUM STORE", UDim2.new(1, 0, 0, 25), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 16)
	local PremScroll = Instance.new("ScrollingFrame", MTRightPanel); PremScroll.Size = UDim2.new(1, 0, 1, -30); PremScroll.Position = UDim2.new(0, 0, 0, 30); PremScroll.BackgroundTransparency = 1; PremScroll.ScrollBarThickness = 6; PremScroll.BorderSizePixel = 0
	local pslayout = Instance.new("UIListLayout", PremScroll); pslayout.Padding = UDim.new(0, 8)
	pslayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() PremScroll.CanvasSize = UDim2.new(0,0,0, pslayout.AbsoluteContentSize.Y + 10) end)

	local function CreatePremiumCard(titleText, descText, buyAction, giftAction)
		local pCard = Instance.new("Frame", PremScroll); pCard.Size = UDim2.new(1, -10, 0, 70); pCard.BackgroundTransparency = 1
		local bgGlow = Instance.new("Frame", pCard); bgGlow.Size = UDim2.new(1, 0, 1, 0); bgGlow.BackgroundColor3 = UIHelpers.Colors.Gold; bgGlow.BorderSizePixel = 0; bgGlow.ZIndex = 1; local grad = Instance.new("UIGradient", bgGlow); grad.Rotation = 90; grad.Transparency = NumberSequence.new{ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.95), NumberSequenceKeypoint.new(1, 0.7) }
		local cStroke = Instance.new("UIStroke", pCard); cStroke.Color = UIHelpers.Colors.Gold; cStroke.Thickness = 2; cStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

		local pName = UIHelpers.CreateLabel(pCard, string.upper(titleText), UDim2.new(1, -20, 0, 20), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 14); pName.Position = UDim2.new(0, 10, 0, 5); pName.TextXAlignment = Enum.TextXAlignment.Left; pName.ZIndex = 2
		local pDesc = UIHelpers.CreateLabel(pCard, descText or "A premium item.", UDim2.new(1, -20, 0, 20), Enum.Font.GothamMedium, UIHelpers.Colors.TextWhite, 11); pDesc.Position = UDim2.new(0, 10, 0, 20); pDesc.TextXAlignment = Enum.TextXAlignment.Left; pDesc.ZIndex = 2

		local btnContainer = Instance.new("Frame", pCard); btnContainer.Size = UDim2.new(1, -20, 0, 25); btnContainer.Position = UDim2.new(0, 10, 1, -30); btnContainer.BackgroundTransparency = 1; btnContainer.ZIndex = 3
		local bcLayout = Instance.new("UIListLayout", btnContainer); bcLayout.FillDirection = Enum.FillDirection.Horizontal; bcLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right; bcLayout.Padding = UDim.new(0, 5)

		if giftAction then
			local buyBtn, buyStroke = CreateSharpButton(btnContainer, "BUY", UDim2.new(0, 60, 1, 0), Enum.Font.GothamBlack, 11); buyBtn.TextColor3 = Color3.fromRGB(85, 255, 85); buyStroke.Color = Color3.fromRGB(85, 255, 85); buyBtn.MouseButton1Click:Connect(buyAction)
			local giftBtn, giftStroke = CreateSharpButton(btnContainer, "GIFT", UDim2.new(0, 60, 1, 0), Enum.Font.GothamBlack, 11); giftBtn.TextColor3 = Color3.fromRGB(200, 100, 255); giftStroke.Color = Color3.fromRGB(200, 100, 255); giftBtn.MouseButton1Click:Connect(giftAction)
		else
			local buyBtn, buyStroke = CreateSharpButton(btnContainer, "BUY", UDim2.new(0, 80, 1, 0), Enum.Font.GothamBlack, 11); buyBtn.TextColor3 = Color3.fromRGB(85, 255, 85); buyStroke.Color = Color3.fromRGB(85, 255, 85); buyBtn.MouseButton1Click:Connect(buyAction)
		end
	end
	if ItemData.Gamepasses then for _, gp in ipairs(ItemData.Gamepasses) do CreatePremiumCard(gp.Name, gp.Desc, function() MarketplaceService:PromptGamePassPurchase(player, gp.ID) end, gp.GiftID and function() MarketplaceService:PromptProductPurchase(player, gp.GiftID) end or nil) end end
	if ItemData.Products then for _, prod in ipairs(ItemData.Products) do if not prod.IsReroll and not string.find(prod.Name, "Gift:") then CreatePremiumCard(prod.Name, prod.Desc, function() MarketplaceService:PromptProductPurchase(player, prod.ID) end, nil) end end end

	-- Trade Section Divider
	local TradeIndicator = Instance.new("Frame", MTTab)
	TradeIndicator.Size = UDim2.new(1, 0, 0, 30)
	TradeIndicator.BackgroundTransparency = 1
	TradeIndicator.LayoutOrder = 2
	local tIndLbl = UIHelpers.CreateLabel(TradeIndicator, "▼  SECURE PLAYER TRADING  ▼", UDim2.new(1, 0, 1, 0), Enum.Font.GothamBlack, Color3.fromRGB(85, 170, 255), 18)
	TweenService:Create(tIndLbl, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {TextTransparency = 0.5}):Play()

	local TradeRow = Instance.new("Frame", MTTab)
	TradeRow.Size = UDim2.new(1, 0, 0, 0)
	TradeRow.AutomaticSize = Enum.AutomaticSize.Y
	TradeRow.BackgroundTransparency = 1
	TradeRow.LayoutOrder = 3
	local trLayout = Instance.new("UIListLayout", TradeRow)
	trLayout.FillDirection = Enum.FillDirection.Horizontal
	trLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	trLayout.Padding = UDim.new(0, 20)

	local TradeLeftPanel = Instance.new("Frame", TradeRow); TradeLeftPanel.Size = UDim2.new(0.48, 0, 0, 280); TradeLeftPanel.BackgroundTransparency = 1
	local tlLayout = Instance.new("UIListLayout", TradeLeftPanel); tlLayout.Padding = UDim.new(0, 15); tlLayout.SortOrder = Enum.SortOrder.LayoutOrder

	-- [[ FIX: Compacted Trade Send UI for Mobile Screen ]]
	local SendContainer, _ = CreateGrimPanel(TradeLeftPanel); SendContainer.Size = UDim2.new(1, 0, 0, 150); SendContainer.LayoutOrder = 1
	local scTitle = UIHelpers.CreateLabel(SendContainer, "OUTGOING REQUEST", UDim2.new(1, 0, 0, 20), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 15); scTitle.Position = UDim2.new(0, 0, 0, 10)
	local pInput = Instance.new("TextBox", SendContainer); pInput.Size = UDim2.new(0.8, 0, 0, 35); pInput.Position = UDim2.new(0.5, 0, 0, 40); pInput.AnchorPoint = Vector2.new(0.5, 0); pInput.BackgroundColor3 = Color3.fromRGB(15, 15, 18); pInput.TextColor3 = UIHelpers.Colors.TextWhite; pInput.Font = Enum.Font.GothamMedium; pInput.TextSize = 14; pInput.PlaceholderText = "Target Username..."; pInput.Text = ""; Instance.new("UIStroke", pInput).Color = UIHelpers.Colors.BorderMuted
	local SendBtn, sendStroke = CreateSharpButton(SendContainer, "SEND REQUEST", UDim2.new(0.8, 0, 0, 40), Enum.Font.GothamBlack, 15); SendBtn.Position = UDim2.new(0.5, 0, 0, 90); SendBtn.AnchorPoint = Vector2.new(0.5, 0); SendBtn.TextColor3 = Color3.fromRGB(85, 170, 255); sendStroke.Color = Color3.fromRGB(85, 170, 255)

	-- [[ FIX: Compacted Promo Code UI for Mobile Screen ]]
	local CodeContainer = Instance.new("Frame", TradeLeftPanel)
	CodeContainer.Size = UDim2.new(1, 0, 0, 90)
	CodeContainer.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	CodeContainer.BorderSizePixel = 0
	CodeContainer.LayoutOrder = 2
	local cStroke = Instance.new("UIStroke", CodeContainer)
	cStroke.Color = Color3.fromRGB(70, 70, 80)
	cStroke.Thickness = 2

	local codeTitle = UIHelpers.CreateLabel(CodeContainer, "REDEEM PROMO CODE", UDim2.new(1, 0, 0, 20), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 15)
	codeTitle.Position = UDim2.new(0, 0, 0, 5)

	local cInput = Instance.new("TextBox", CodeContainer)
	cInput.Size = UDim2.new(0.65, 0, 0, 35)
	cInput.Position = UDim2.new(0.05, 0, 0, 35)
	cInput.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
	cInput.TextColor3 = UIHelpers.Colors.TextWhite
	cInput.Font = Enum.Font.GothamMedium
	cInput.TextSize = 14
	cInput.PlaceholderText = "Enter Code..."
	cInput.Text = ""
	Instance.new("UIStroke", cInput).Color = UIHelpers.Colors.BorderMuted

	local RedeemBtn, redeemStroke = CreateSharpButton(CodeContainer, "REDEEM", UDim2.new(0.25, 0, 0, 35), Enum.Font.GothamBlack, 13)
	RedeemBtn.Position = UDim2.new(0.72, 0, 0, 35)
	RedeemBtn.TextColor3 = Color3.fromRGB(85, 255, 85)
	redeemStroke.Color = Color3.fromRGB(85, 255, 85)

	RedeemBtn.MouseButton1Click:Connect(function()
		if cInput.Text ~= "" then
			Network:WaitForChild("RedeemCode"):FireServer(cInput.Text)
			cInput.Text = ""
		end
	end)

	local TradeRightPanel = Instance.new("Frame", TradeRow); TradeRightPanel.Size = UDim2.new(0.48, 0, 0, 280); TradeRightPanel.BackgroundTransparency = 1
	local IncContainer, _ = CreateGrimPanel(TradeRightPanel); IncContainer.Size = UDim2.new(1, 0, 1, 0)
	local incTitle = UIHelpers.CreateLabel(IncContainer, "INCOMING REQUESTS", UDim2.new(1, 0, 0, 30), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 16); incTitle.Position = UDim2.new(0, 0, 0, 10)
	local ReqScroll = Instance.new("ScrollingFrame", IncContainer); ReqScroll.Size = UDim2.new(1, -20, 1, -50); ReqScroll.Position = UDim2.new(0, 10, 0, 40); ReqScroll.BackgroundTransparency = 1; ReqScroll.ScrollBarThickness = 6; ReqScroll.BorderSizePixel = 0
	local reqLayout = Instance.new("UIListLayout", ReqScroll); reqLayout.Padding = UDim.new(0, 8); reqLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() ReqScroll.CanvasSize = UDim2.new(0, 0, 0, reqLayout.AbsoluteContentSize.Y + 10) end)

	local PendingTrades = {}
	local function UpdateTradeRequests()
		for _, c in ipairs(ReqScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
		for reqName, _ in pairs(PendingTrades) do
			local rCard, _ = CreateGrimPanel(ReqScroll); rCard.Size = UDim2.new(1, -10, 0, 40)
			local nameLbl = UIHelpers.CreateLabel(rCard, reqName, UDim2.new(0.5, 0, 1, 0), Enum.Font.GothamBold, UIHelpers.Colors.TextWhite, 14); nameLbl.Position = UDim2.new(0, 15, 0, 0); nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			local accBtn, accStrk = CreateSharpButton(rCard, "ACCEPT", UDim2.new(0, 70, 0, 28), Enum.Font.GothamBlack, 11); accBtn.Position = UDim2.new(1, -50, 0.5, 0); accBtn.AnchorPoint = Vector2.new(1, 0.5); accBtn.TextColor3 = Color3.fromRGB(85, 255, 85); accStrk.Color = Color3.fromRGB(85, 255, 85)
			local decBtn, decStrk = CreateSharpButton(rCard, "X", UDim2.new(0, 28, 0, 28), Enum.Font.GothamBlack, 14); decBtn.Position = UDim2.new(1, -10, 0.5, 0); decBtn.AnchorPoint = Vector2.new(1, 0.5); decBtn.TextColor3 = Color3.fromRGB(255, 85, 85); decStrk.Color = Color3.fromRGB(255, 85, 85)
			accBtn.MouseButton1Click:Connect(function() Network:WaitForChild("TradeAction"):FireServer("AcceptRequest", reqName) end)
			decBtn.MouseButton1Click:Connect(function() PendingTrades[reqName] = nil; UpdateTradeRequests(); Network:WaitForChild("TradeAction"):FireServer("DeclineRequest", reqName) end)
		end
	end
	SendBtn.MouseButton1Click:Connect(function() if pInput.Text ~= "" then Network:WaitForChild("TradeAction"):FireServer("SendRequest", pInput.Text); pInput.Text = "" end end)
	Network:WaitForChild("TradeUpdate").OnClientEvent:Connect(function(action, data)
		if action == "IncomingRequest" then PendingTrades[data.Sender] = true; UpdateTradeRequests()
		elseif action == "CancelRequest" then PendingTrades[data.Sender] = nil; UpdateTradeRequests() end
	end)

	LayoutRefs.TradeLayout = trLayout
	LayoutRefs.TradeLeft = TradeLeftPanel
	LayoutRefs.TradeRight = TradeRightPanel

	-- ==========================================
	-- 2. THE FORGE (Crafting + Rituals + Refinery + Maintenance)
	-- ==========================================
	local ForgeTab = activeSubFrames["THE FORGE"]
	local fgTitle = UIHelpers.CreateLabel(ForgeTab, "WEAPONSMITH & RITUALS", UDim2.new(1, 0, 0, 30), Enum.Font.GothamBlack, UIHelpers.Colors.TextWhite, 20)
	fgTitle.Position = UDim2.new(0, 0, 0, 0)

	local fgSplitContainer = Instance.new("Frame", ForgeTab)
	fgSplitContainer.Size = UDim2.new(1, 0, 0, 0)
	fgSplitContainer.Position = UDim2.new(0, 0, 0, 40)
	fgSplitContainer.AutomaticSize = Enum.AutomaticSize.Y
	fgSplitContainer.BackgroundTransparency = 1
	local fgLayout = Instance.new("UIListLayout", fgSplitContainer); fgLayout.FillDirection = Enum.FillDirection.Horizontal; fgLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; fgLayout.Padding = UDim.new(0, 15)

	local FLeftPanel = Instance.new("Frame", fgSplitContainer); FLeftPanel.Size = UDim2.new(0.35, 0, 0, 500); FLeftPanel.BackgroundTransparency = 1

	-- Mode Toggles
	local fModeNav = Instance.new("Frame", FLeftPanel); fModeNav.Size = UDim2.new(1, 0, 0, 35); fModeNav.BackgroundTransparency = 1
	local fmLayout = Instance.new("UIListLayout", fModeNav); fmLayout.FillDirection = Enum.FillDirection.Horizontal; fmLayout.Padding = UDim.new(0, 5)

	local modeForgeBtn, mfStroke = CreateSharpButton(fModeNav, "CRAFTING", UDim2.new(0.23, 0, 1, 0), Enum.Font.GothamBlack, 11)
	local modeRitualBtn, mrtStroke = CreateSharpButton(fModeNav, "RITUALS", UDim2.new(0.23, 0, 1, 0), Enum.Font.GothamBlack, 11)
	local modeRefineBtn, mrStroke = CreateSharpButton(fModeNav, "REFINERY", UDim2.new(0.23, 0, 1, 0), Enum.Font.GothamBlack, 11)
	local modeMaintBtn, mntStroke = CreateSharpButton(fModeNav, "MAINTENANCE", UDim2.new(0.26, 0, 1, 0), Enum.Font.GothamBlack, 11)

	local RecipeList = Instance.new("ScrollingFrame", FLeftPanel); RecipeList.Size = UDim2.new(1, 0, 1, -45); RecipeList.Position = UDim2.new(0, 0, 0, 45); RecipeList.BackgroundTransparency = 1; RecipeList.ScrollBarThickness = 4; RecipeList.BorderSizePixel = 0
	local rlLayout = Instance.new("UIListLayout", RecipeList); rlLayout.Padding = UDim.new(0, 10); rlLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() RecipeList.CanvasSize = UDim2.new(0, 0, 0, rlLayout.AbsoluteContentSize.Y + 20) end)

	local RitualList = Instance.new("ScrollingFrame", FLeftPanel); RitualList.Size = UDim2.new(1, 0, 1, -45); RitualList.Position = UDim2.new(0, 0, 0, 45); RitualList.BackgroundTransparency = 1; RitualList.ScrollBarThickness = 4; RitualList.BorderSizePixel = 0; RitualList.Visible = false
	local rtlLayout = Instance.new("UIListLayout", RitualList); rtlLayout.Padding = UDim.new(0, 10); rtlLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() RitualList.CanvasSize = UDim2.new(0, 0, 0, rtlLayout.AbsoluteContentSize.Y + 10) end)

	local RefineList = Instance.new("ScrollingFrame", FLeftPanel); RefineList.Size = UDim2.new(1, 0, 1, -45); RefineList.Position = UDim2.new(0, 0, 0, 45); RefineList.BackgroundTransparency = 1; RefineList.ScrollBarThickness = 4; RefineList.BorderSizePixel = 0; RefineList.Visible = false
	local rflLayout = Instance.new("UIListLayout", RefineList); rflLayout.Padding = UDim.new(0, 10); rflLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() RefineList.CanvasSize = UDim2.new(0, 0, 0, rflLayout.AbsoluteContentSize.Y + 10) end)

	local FRightPanel = Instance.new("Frame", fgSplitContainer); FRightPanel.Size = UDim2.new(0.63, 0, 0, 500); FRightPanel.BackgroundTransparency = 1 

	-- Blueprint View
	local BlueprintView = Instance.new("ScrollingFrame", FRightPanel); BlueprintView.Size = UDim2.new(1, 0, 1, 0); BlueprintView.BackgroundTransparency = 1; BlueprintView.ScrollBarThickness = 0; BlueprintView.BorderSizePixel = 0
	local bpLayout = Instance.new("UIListLayout", BlueprintView); bpLayout.Padding = UDim.new(0, 15); bpLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bpLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() BlueprintView.CanvasSize = UDim2.new(0, 0, 0, bpLayout.AbsoluteContentSize.Y + 20) end)

	local RefineView = Instance.new("Frame", FRightPanel); RefineView.Size = UDim2.new(1, 0, 1, 0); RefineView.BackgroundTransparency = 1; RefineView.Visible = false
	local MaintView = Instance.new("Frame", FRightPanel); MaintView.Size = UDim2.new(1, 0, 1, 0); MaintView.BackgroundTransparency = 1; MaintView.Visible = false

	modeForgeBtn.TextColor3 = UIHelpers.Colors.Gold; mfStroke.Color = UIHelpers.Colors.Gold
	modeRitualBtn.TextColor3 = UIHelpers.Colors.TextMuted; mrtStroke.Color = UIHelpers.Colors.BorderMuted
	modeRefineBtn.TextColor3 = UIHelpers.Colors.TextMuted; mrStroke.Color = UIHelpers.Colors.BorderMuted
	modeMaintBtn.TextColor3 = UIHelpers.Colors.TextMuted; mntStroke.Color = UIHelpers.Colors.BorderMuted

	local selectedRecipeName = nil; local selectedRefineItem = nil; local currentMode = "Crafting"

	local function SwitchMode(mode)
		currentMode = mode
		modeForgeBtn.TextColor3 = (mode == "Crafting") and UIHelpers.Colors.Gold or UIHelpers.Colors.TextMuted; mfStroke.Color = (mode == "Crafting") and UIHelpers.Colors.Gold or UIHelpers.Colors.BorderMuted
		modeRitualBtn.TextColor3 = (mode == "Rituals") and UIHelpers.Colors.Gold or UIHelpers.Colors.TextMuted; mrtStroke.Color = (mode == "Rituals") and UIHelpers.Colors.Gold or UIHelpers.Colors.BorderMuted
		modeRefineBtn.TextColor3 = (mode == "Refinery") and UIHelpers.Colors.Gold or UIHelpers.Colors.TextMuted; mrStroke.Color = (mode == "Refinery") and UIHelpers.Colors.Gold or UIHelpers.Colors.BorderMuted
		modeMaintBtn.TextColor3 = (mode == "Maintenance") and UIHelpers.Colors.Gold or UIHelpers.Colors.TextMuted; mntStroke.Color = (mode == "Maintenance") and UIHelpers.Colors.Gold or UIHelpers.Colors.BorderMuted

		RecipeList.Visible = (mode == "Crafting"); RitualList.Visible = (mode == "Rituals"); RefineList.Visible = (mode == "Refinery")
		BlueprintView.Visible = (mode == "Crafting" or mode == "Rituals"); RefineView.Visible = (mode == "Refinery"); MaintView.Visible = (mode == "Maintenance")

		if mode == "Maintenance" then
			player:SetAttribute("_ForceUIRefresh", math.random())
		end
	end
	modeForgeBtn.MouseButton1Click:Connect(function() SwitchMode("Crafting") end)
	modeRitualBtn.MouseButton1Click:Connect(function() SwitchMode("Rituals") end)
	modeRefineBtn.MouseButton1Click:Connect(function() SwitchMode("Refinery") end)
	modeMaintBtn.MouseButton1Click:Connect(function() SwitchMode("Maintenance") end)

	-- BLUEPRINT UI 
	local bpTitle = UIHelpers.CreateLabel(BlueprintView, "SELECT A BLUEPRINT", UDim2.new(1, -20, 0, 30), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 20); bpTitle.LayoutOrder = 1; bpTitle.TextXAlignment = Enum.TextXAlignment.Left
	local bpDesc = UIHelpers.CreateLabel(BlueprintView, "Select an item from the registry to view its crafting requirements.", UDim2.new(1, -20, 0, 40), Enum.Font.GothamMedium, UIHelpers.Colors.TextMuted, 13); bpDesc.LayoutOrder = 2; bpDesc.TextXAlignment = Enum.TextXAlignment.Left; bpDesc.TextWrapped = true; bpDesc.TextYAlignment = Enum.TextYAlignment.Top; bpDesc.RichText = true
	local ReqTitle = UIHelpers.CreateLabel(BlueprintView, "REQUIRED MATERIALS", UDim2.new(1, -20, 0, 20), Enum.Font.GothamBlack, UIHelpers.Colors.TextWhite, 14); ReqTitle.LayoutOrder = 3; ReqTitle.TextXAlignment = Enum.TextXAlignment.Left; ReqTitle.Visible = false
	local ReqList = Instance.new("Frame", BlueprintView); ReqList.Size = UDim2.new(1, -20, 0, 0); ReqList.LayoutOrder = 4; ReqList.BackgroundTransparency = 1
	local reqLayout = Instance.new("UIListLayout", ReqList); reqLayout.Padding = UDim.new(0, 8); reqLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() ReqList.Size = UDim2.new(1, -20, 0, reqLayout.AbsoluteContentSize.Y) end)

	local CraftBtnBox = Instance.new("Frame", BlueprintView); CraftBtnBox.Size = UDim2.new(1, -20, 0, 60); CraftBtnBox.BackgroundTransparency = 1; CraftBtnBox.LayoutOrder = 5
	local CraftBtn, CraftStroke = CreateSharpButton(CraftBtnBox, "FORGE", UDim2.new(0.8, 0, 0, 45), Enum.Font.GothamBlack, 16); CraftBtn.Position = UDim2.new(0.5, 0, 0, 10); CraftBtn.AnchorPoint = Vector2.new(0.5, 0); CraftBtn.Visible = false

	local sortedCrafts, sortedRituals = {}, {}
	for rec, data in pairs(ItemData.ForgeRecipes or {}) do
		local isRitual = (data.SpecialType == "AbyssalClanRequirement" or string.find(rec, "Serum") or string.find(rec, "Abyssal"))
		if isRitual then table.insert(sortedRituals, {Name = rec, Data = data}) else table.insert(sortedCrafts, {Name = rec, Data = data}) end
	end
	local sortFunc = function(a, b)
		local rA = ItemData.Equipment[a.Data.Result] and ItemData.Equipment[a.Data.Result].Rarity or "Common"
		local rB = ItemData.Equipment[b.Data.Result] and ItemData.Equipment[b.Data.Result].Rarity or "Common"
		return (CONFIG.RarityOrder[rA] or 7) < (CONFIG.RarityOrder[rB] or 7)
	end
	table.sort(sortedCrafts, sortFunc); table.sort(sortedRituals, sortFunc)

	local function PopulateList(listData, parentScroll, isRitualList)
		for _, item in ipairs(listData) do
			local rec = item.Name; local recipeData = item.Data
			local resItem = recipeData.Result; local resData = ItemData.Equipment[resItem] or ItemData.Consumables[resItem]
			local rarity = resData and resData.Rarity or "Common"; local rColor = CONFIG.RarityColors[rarity] or Color3.fromRGB(200,200,200)

			local rBtn = Instance.new("TextButton", parentScroll); rBtn.Size = UDim2.new(1, -10, 0, 50); rBtn.BackgroundTransparency = 1; rBtn.AutoButtonColor = false; rBtn.Text = ""
			local rStrk = Instance.new("UIStroke", rBtn); rStrk.Color = rColor; rStrk.Thickness = 2; rStrk.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			local bgGlow = Instance.new("Frame", rBtn); bgGlow.Size = UDim2.new(1, 0, 1, 0); bgGlow.BackgroundColor3 = rColor; bgGlow.BorderSizePixel = 0; bgGlow.ZIndex = 1; local grad = Instance.new("UIGradient", bgGlow); grad.Rotation = 90; grad.Transparency = NumberSequence.new{ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.95), NumberSequenceKeypoint.new(1, 0.8) }

			local rTitleLbl = UIHelpers.CreateLabel(rBtn, string.upper(rec), UDim2.new(1, -15, 0, 18), Enum.Font.GothamBlack, rColor, 12); rTitleLbl.Position = UDim2.new(0, 10, 0, 6); rTitleLbl.TextXAlignment = Enum.TextXAlignment.Left; rTitleLbl.ZIndex = 2
			local tagStr = isRitualList and "[ BLOODLINE RITUAL ]" or ("[" .. string.upper(rarity) .. "]")
			local rTagLbl = UIHelpers.CreateLabel(rBtn, tagStr, UDim2.new(1, -15, 0, 15), Enum.Font.GothamBold, Color3.fromRGB(200, 200, 200), 10); rTagLbl.Position = UDim2.new(0, 10, 1, -22); rTagLbl.TextXAlignment = Enum.TextXAlignment.Left; rTagLbl.ZIndex = 2

			rBtn.MouseEnter:Connect(function() rTitleLbl.TextColor3 = UIHelpers.Colors.Gold; rTagLbl.TextColor3 = UIHelpers.Colors.Gold; rStrk.Color = UIHelpers.Colors.Gold end)
			rBtn.MouseLeave:Connect(function() rTitleLbl.TextColor3 = rColor; rTagLbl.TextColor3 = Color3.fromRGB(200, 200, 200); rStrk.Color = rColor end)

			rBtn.MouseButton1Click:Connect(function()
				selectedRecipeName = rec
				player:SetAttribute("_ForceUIRefresh", math.random()) 
			end)
		end
	end

	local function RefreshBlueprint()
		if not selectedRecipeName then return end
		local recipeData = ItemData.ForgeRecipes[selectedRecipeName]
		if not recipeData then return end

		local resItem = recipeData.Result
		local resData = ItemData.Equipment[resItem] or ItemData.Consumables[resItem]
		local rarity = resData and resData.Rarity or "Common"
		local rColor = CONFIG.RarityColors[rarity] or Color3.fromRGB(200,200,200)
		local isRitualList = (recipeData.SpecialType == "AbyssalClanRequirement" or string.find(selectedRecipeName, "Serum") or string.find(selectedRecipeName, "Abyssal"))

		bpTitle.Text = string.upper(selectedRecipeName); bpTitle.TextColor3 = rColor
		bpDesc.Text = "<font color=\"" .. ColorToHex(rColor) .. "\">[" .. rarity:upper() .. "]</font> " .. (resData and resData.Desc or "A piece of forged equipment.")
		ReqTitle.Visible = true; CraftBtn.Visible = true; CraftStroke.Color = rColor; CraftBtn.TextColor3 = rColor
		for _, c in ipairs(ReqList:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end

		local function MakeReq(matName, amt, hasAmt)
			local rf = Instance.new("Frame", ReqList); rf.Size = UDim2.new(1, 0, 0, 25); rf.BackgroundTransparency = 1; rf.ZIndex = 103
			local reqBg = Instance.new("Frame", rf); reqBg.Size = UDim2.new(1, 0, 1, 0); reqBg.BackgroundColor3 = hasAmt and UIHelpers.Colors.BorderMuted or Color3.fromRGB(150, 40, 40); reqBg.BackgroundTransparency = hasAmt and 0.5 or 0; reqBg.BorderSizePixel = 0
			local rGrad = Instance.new("UIGradient", reqBg); rGrad.Rotation = 90; rGrad.Transparency = NumberSequence.new{ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.95), NumberSequenceKeypoint.new(1, 0.7) }
			local l = UIHelpers.CreateLabel(rf, amt .. "x " .. matName, UDim2.new(1, -10, 1, 0), Enum.Font.GothamBold, hasAmt and UIHelpers.Colors.TextWhite or Color3.fromRGB(255, 100, 100), 11); l.Position = UDim2.new(0, 10, 0, 0); l.TextXAlignment = Enum.TextXAlignment.Left; l.ZIndex = 104
		end

		local hasAllMats = true
		for mat, amt in pairs(recipeData.ReqItems) do 
			local count = GetItemCount(mat)
			local hasEnough = count >= amt; if not hasEnough then hasAllMats = false end
			MakeReq(mat, amt, hasEnough) 
		end

		if recipeData.SpecialType == "AbyssalClanRequirement" then
			local requiredCount = recipeData.AbyssalClanCount or 2; local abyssalFound = 0
			local abyssalClans = { "ItemizedAbyssalYeagerCount", "ItemizedAbyssalTyburCount", "ItemizedAbyssalAckermanCount", "ItemizedAbyssalGalliardCount", "ItemizedAbyssalBraunCount", "ItemizedAbyssalReissCount" }
			for _, attr in ipairs(abyssalClans) do local count = player:GetAttribute(attr) or 0; if count > 0 then abyssalFound += count end end
			local hasEnough = abyssalFound >= requiredCount; if not hasEnough then hasAllMats = false end
			MakeReq("Any Abyssal Lineage", requiredCount, hasEnough)
		end

		local dCount = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Dews") and player.leaderstats.Dews.Value or 0
		local hasDews = dCount >= recipeData.DewCost; if not hasDews then hasAllMats = false end
		MakeReq("Dews", recipeData.DewCost, hasDews)

		if hasAllMats then
			CraftBtn.Active = true; CraftBtn.Text = isRitualList and "COMMENCE RITUAL" or "FORGE EQUIPMENT"; CraftBtn.TextColor3 = rColor; CraftStroke.Color = rColor
		else
			CraftBtn.Active = false; CraftBtn.Text = "INSUFFICIENT MATERIALS"; CraftBtn.TextColor3 = Color3.fromRGB(100, 100, 100); CraftStroke.Color = Color3.fromRGB(50, 50, 60)
		end
	end

	PopulateList(sortedCrafts, RecipeList, false)
	PopulateList(sortedRituals, RitualList, true)

	CraftBtn.MouseButton1Click:Connect(function()
		if not selectedRecipeName then return end
		local recipe = ItemData.ForgeRecipes[selectedRecipeName]
		if not recipe then return end

		local dews = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Dews") and player.leaderstats.Dews.Value or 0
		if dews < recipe.DewCost then NotifySafe("Not enough Dews!", "Error"); return end

		local hasMats = true
		for req, amt in pairs(recipe.ReqItems) do 
			local count = GetItemCount(req)
			if count < amt then hasMats = false; break end
		end

		if recipe.SpecialType == "AbyssalClanRequirement" then
			local requiredCount = recipe.AbyssalClanCount or 2
			local abyssalFound = 0
			local abyssalClans = { "ItemizedAbyssalYeagerCount", "ItemizedAbyssalTyburCount", "ItemizedAbyssalAckermanCount", "ItemizedAbyssalGalliardCount", "ItemizedAbyssalBraunCount", "ItemizedAbyssalReissCount" }
			for _, attr in ipairs(abyssalClans) do 
				local count = player:GetAttribute(attr) or 0; 
				if count > 0 then abyssalFound += count end 
			end
			if abyssalFound < requiredCount then hasMats = false end
		end

		if not hasMats then NotifySafe("Missing materials!", "Error"); return end

		local isRitual = (currentMode == "Rituals")
		if isRitual then
			Network:WaitForChild("ForgeItem"):FireServer(selectedRecipeName, "Standard")
			NotifySafe("Successfully forged " .. selectedRecipeName .. "!", "Success")
		else
			Network:WaitForChild("ForgeItem"):FireServer(selectedRecipeName, "Standard")
			NotifySafe("Successfully forged " .. selectedRecipeName .. "!", "Success")
		end
	end)

	-- REFINERY UI
	local rfTitle = UIHelpers.CreateLabel(RefineView, "GEAR REFINERY", UDim2.new(1, -20, 0, 30), Enum.Font.GothamBlack, Color3.fromRGB(255, 150, 50), 20); rfTitle.Position = UDim2.new(0, 10, 0, 10); rfTitle.TextXAlignment = Enum.TextXAlignment.Left
	local rfDesc = UIHelpers.CreateLabel(RefineView, "Enhance a piece of equipment to increase its base stats permanently.", UDim2.new(1, -20, 0, 40), Enum.Font.GothamMedium, UIHelpers.Colors.TextMuted, 13); rfDesc.Position = UDim2.new(0, 10, 0, 40); rfDesc.TextXAlignment = Enum.TextXAlignment.Left; rfDesc.TextWrapped = true; rfDesc.TextYAlignment = Enum.TextYAlignment.Top
	local rfTargetLbl = UIHelpers.CreateLabel(RefineView, "TARGET: NONE", UDim2.new(1, -20, 0, 25), Enum.Font.GothamBlack, Color3.fromRGB(200, 200, 200), 16); rfTargetLbl.Position = UDim2.new(0, 10, 0, 90); rfTargetLbl.TextXAlignment = Enum.TextXAlignment.Left
	local rfCostLbl = UIHelpers.CreateLabel(RefineView, "COST: 50,000 Dews + 5 Titan Hardening Extract", UDim2.new(1, -20, 0, 25), Enum.Font.GothamBold, Color3.fromRGB(255, 100, 100), 12); rfCostLbl.Position = UDim2.new(0, 10, 0, 115); rfCostLbl.TextXAlignment = Enum.TextXAlignment.Left
	local RefineBtn, RefineStroke = CreateSharpButton(RefineView, "AWAKEN GEAR", UDim2.new(0.8, 0, 0, 45), Enum.Font.GothamBlack, 16); RefineBtn.Position = UDim2.new(0.5, 0, 1, -15); RefineBtn.AnchorPoint = Vector2.new(0.5, 1); RefineBtn.Visible = false; RefineBtn.TextColor3 = Color3.fromRGB(255, 150, 50); RefineStroke.Color = Color3.fromRGB(255, 150, 50)

	local function UpdateRefineList()
		for _, c in ipairs(RefineList:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
		if type(ItemData) == "table" and ItemData.Equipment then
			local sortedRefinables = {}
			for iName, iData in pairs(ItemData.Equipment) do
				local count = tonumber(player:GetAttribute(iName:gsub("[^%w]", "") .. "Count")) or tonumber(player:GetAttribute(iName)) or 0
				if count > 0 and iData.Rarity ~= "Transcendent" then table.insert(sortedRefinables, {Name = iName, Data = iData}) end
			end
			table.sort(sortedRefinables, function(a, b) return (CONFIG.RarityOrder[a.Data.Rarity or "Common"] or 7) < (CONFIG.RarityOrder[b.Data.Rarity or "Common"] or 7) end)

			for _, item in ipairs(sortedRefinables) do
				local iName = item.Name; local iData = item.Data
				local rColor = CONFIG.RarityColors[iData.Rarity or "Common"] or Color3.fromRGB(200,200,200)
				local safeName = iName:gsub("[^%w]", "")

				local isAbyssalItem = string.find(iName, "Abyssal") or iData.Rarity == "Transcendent"
				local currentLevel = player:GetAttribute(safeName .. "_AwakenLevel") or 0

				local rBtn = Instance.new("TextButton", RefineList); rBtn.Size = UDim2.new(1, -10, 0, 45); rBtn.BackgroundTransparency = 1; rBtn.AutoButtonColor = false; rBtn.Text = ""
				local rStrk = Instance.new("UIStroke", rBtn); rStrk.Color = rColor; rStrk.Thickness = 2; rStrk.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

				local titleText = currentLevel > 0 and (string.upper(iName) .. " [+" .. currentLevel .. "]") or string.upper(iName)
				local rTitleLbl = UIHelpers.CreateLabel(rBtn, titleText, UDim2.new(1, -15, 0, 18), Enum.Font.GothamBlack, currentLevel > 0 and Color3.fromRGB(255, 150, 50) or rColor, 12); rTitleLbl.Position = UDim2.new(0, 10, 0.5, 0); rTitleLbl.AnchorPoint = Vector2.new(0, 0.5); rTitleLbl.TextXAlignment = Enum.TextXAlignment.Left; rTitleLbl.ZIndex = 2

				rBtn.MouseButton1Click:Connect(function()
					selectedRefineItem = iName; rfTargetLbl.Text = "TARGET: " .. string.upper(iName)

					if isAbyssalItem then
						rfCostLbl.Text = "Abyssal & Transcendent items cannot be awakened."
						rfCostLbl.TextColor3 = UIHelpers.Colors.TextMuted
						RefineBtn.Visible = false
					else
						local costDews = 10000 + (currentLevel * 5000)
						local costExtracts = 1 + currentLevel
						rfCostLbl.Text = "COST: " .. costDews .. " Dews + " .. costExtracts .. " Titan Hardening Extract"
						rfCostLbl.TextColor3 = Color3.fromRGB(255, 100, 100)
						RefineBtn.Text = "AWAKEN TO +" .. (currentLevel + 1)
						RefineBtn.Visible = true
					end
				end)
			end
		end
	end
	RefineBtn.MouseButton1Click:Connect(function() if not selectedRefineItem then return end Network:WaitForChild("RefineGear"):FireServer(selectedRefineItem); task.wait(0.5); UpdateRefineList(); selectedRefineItem = nil; rfTargetLbl.Text = "TARGET: NONE"; RefineBtn.Visible = false end)

	-- MAINTENANCE UI
	local mnTitle = UIHelpers.CreateLabel(MaintView, "WEAPON MAINTENANCE", UDim2.new(1, -20, 0, 30), Enum.Font.GothamBlack, Color3.fromRGB(255, 100, 100), 20); mnTitle.Position = UDim2.new(0, 10, 0, 10); mnTitle.TextXAlignment = Enum.TextXAlignment.Left
	local mnDesc = UIHelpers.CreateLabel(MaintView, "Resharpen your equipped weapon to restore its durability and damage output.", UDim2.new(1, -20, 0, 40), Enum.Font.GothamMedium, UIHelpers.Colors.TextMuted, 13); mnDesc.Position = UDim2.new(0, 10, 0, 40); mnDesc.TextXAlignment = Enum.TextXAlignment.Left; mnDesc.TextWrapped = true; mnDesc.TextYAlignment = Enum.TextYAlignment.Top

	local mnEqLbl = UIHelpers.CreateLabel(MaintView, "EQUIPPED: NONE", UDim2.new(1, -20, 0, 25), Enum.Font.GothamBlack, UIHelpers.Colors.TextWhite, 18); mnEqLbl.Position = UDim2.new(0, 10, 0, 90); mnEqLbl.TextXAlignment = Enum.TextXAlignment.Left
	local mnDurLbl = UIHelpers.CreateLabel(MaintView, "DURABILITY: 100/100", UDim2.new(1, -20, 0, 25), Enum.Font.GothamBold, Color3.fromRGB(150, 255, 150), 14); mnDurLbl.Position = UDim2.new(0, 10, 0, 115); mnDurLbl.TextXAlignment = Enum.TextXAlignment.Left

	local mnCostLbl = UIHelpers.CreateLabel(MaintView, "COST: 0 Dews", UDim2.new(1, -20, 0, 25), Enum.Font.GothamBold, UIHelpers.Colors.Gold, 12); mnCostLbl.Position = UDim2.new(0, 10, 0, 140); mnCostLbl.TextXAlignment = Enum.TextXAlignment.Left

	local RepairBtn, RepairStroke = CreateSharpButton(MaintView, "RESHARPEN", UDim2.new(0.8, 0, 0, 45), Enum.Font.GothamBlack, 16); RepairBtn.Position = UDim2.new(0.5, 0, 1, -15); RepairBtn.AnchorPoint = Vector2.new(0.5, 1); RepairBtn.Visible = false; RepairBtn.TextColor3 = Color3.fromRGB(255, 100, 100); RepairStroke.Color = Color3.fromRGB(255, 100, 100)

	local function UpdateMaintenanceUI()
		local eqWpn = player:GetAttribute("EquippedWeapon")
		if not eqWpn or eqWpn == "None" then
			mnEqLbl.Text = "EQUIPPED: NONE"
			mnEqLbl.TextColor3 = UIHelpers.Colors.TextMuted
			mnDurLbl.Text = "Equip a weapon to maintain it."
			mnDurLbl.TextColor3 = UIHelpers.Colors.TextMuted
			mnCostLbl.Text = ""
			RepairBtn.Visible = false
			return
		end

		local wData = ItemData.Equipment[eqWpn]
		local rColor = CONFIG.RarityColors[wData and wData.Rarity or "Common"] or UIHelpers.Colors.TextWhite

		mnEqLbl.Text = "EQUIPPED: " .. string.upper(eqWpn)
		mnEqLbl.TextColor3 = rColor

		local dur = tonumber(player:GetAttribute("WeaponDurability")) or 100
		local maxDur = 100

		if dur >= maxDur then
			mnDurLbl.Text = "DURABILITY: " .. math.floor(dur) .. " / " .. maxDur .. " (PRISTINE)"
			mnDurLbl.TextColor3 = Color3.fromRGB(150, 255, 150)
			mnCostLbl.Text = "Weapon is fully maintained."
			mnCostLbl.TextColor3 = UIHelpers.Colors.TextMuted
			RepairBtn.Visible = false
		else
			mnDurLbl.Text = "DURABILITY: " .. math.floor(dur) .. " / " .. maxDur
			mnDurLbl.TextColor3 = Color3.fromRGB(255, 150, 150)
			local cost = math.floor((maxDur - dur) * 150)
			mnCostLbl.Text = "COST: " .. UIHelpers.FormatNumber(cost) .. " Dews"
			mnCostLbl.TextColor3 = UIHelpers.Colors.Gold
			RepairBtn.Visible = true
		end
	end

	RepairBtn.MouseButton1Click:Connect(function() 
		Network:WaitForChild("ForgeItem"):FireServer("RepairWeapon")
		if VFXManager and type(VFXManager.PlaySFX) == "function" then VFXManager.PlaySFX("HeavySlash", 1.5) end
		task.wait(0.2)
		UpdateMaintenanceUI()
	end)

	player.AttributeChanged:Connect(function(attr) 
		if string.match(attr, "Count$") or attr == "_ForceUIRefresh" then 
			RefreshBlueprint()
			UpdateRefineList() 
		end 
		if attr == "EquippedWeapon" or attr == "WeaponDurability" or attr == "_ForceUIRefresh" then
			UpdateMaintenanceUI()
		end
	end)

	task.spawn(function()
		local ls = player:WaitForChild("leaderstats", 10)
		if ls and ls:FindFirstChild("Dews") then
			ls.Dews.Changed:Connect(function()
				RefreshBlueprint()
			end)
		end
	end)

	UpdateRefineList()
	UpdateMaintenanceUI()

	LayoutRefs.ForgeLayout = fgLayout
	LayoutRefs.ForgeLeft = FLeftPanel
	LayoutRefs.ForgeRight = FRightPanel

	-- ==========================================
	-- 3. TITAN LAB (Fusion & Variant Awakening)
	-- ==========================================
	local TitanLabTab = activeSubFrames["TITAN LAB"]
	local tlSplitContainer = Instance.new("Frame", TitanLabTab); tlSplitContainer.Size = UDim2.new(1, 0, 0, 0); tlSplitContainer.Position = UDim2.new(0, 0, 0, 20); tlSplitContainer.BackgroundTransparency = 1; tlSplitContainer.AutomaticSize = Enum.AutomaticSize.Y
	local tlLayout = Instance.new("UIListLayout", tlSplitContainer); tlLayout.FillDirection = Enum.FillDirection.Horizontal; tlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; tlLayout.Padding = UDim.new(0, 15)

	-- Left: Titan Hybridization (Fusion)
	local TLLeftPanel = Instance.new("Frame", tlSplitContainer); TLLeftPanel.Size = UDim2.new(0.48, 0, 0, 450); TLLeftPanel.BackgroundTransparency = 1
	local fTitle = UIHelpers.CreateLabel(TLLeftPanel, "TITAN HYBRIDIZATION", UDim2.new(1, 0, 0, 30), Enum.Font.GothamBlack, Color3.fromRGB(170, 85, 255), 20); fTitle.Position = UDim2.new(0, 0, 0, 0); fTitle.TextXAlignment = Enum.TextXAlignment.Left
	local fDesc = UIHelpers.CreateLabel(TLLeftPanel, "Fuse two Pure Titans with Abyssal Blood to create a horrific Hybrid.", UDim2.new(1, -20, 0, 40), Enum.Font.GothamMedium, UIHelpers.Colors.TextMuted, 13); fDesc.Position = UDim2.new(0, 0, 0, 30); fDesc.TextXAlignment = Enum.TextXAlignment.Left; fDesc.TextWrapped = true

	local AltarContainer = Instance.new("Frame", TLLeftPanel)
	AltarContainer.Size = UDim2.new(1, 0, 0, 220)
	AltarContainer.Position = UDim2.new(0, 0, 0, 80)
	AltarContainer.BackgroundTransparency = 1

	local l1 = Instance.new("Frame", AltarContainer); l1.Size = UDim2.new(0, 120, 0, 6); l1.Position = UDim2.new(0.35, 0, 0.45, 0); l1.Rotation = 50; l1.AnchorPoint = Vector2.new(0.5, 0.5); l1.BackgroundColor3 = Color3.fromRGB(40, 30, 50); l1.BorderSizePixel = 0
	local l2 = Instance.new("Frame", AltarContainer); l2.Size = UDim2.new(0, 120, 0, 6); l2.Position = UDim2.new(0.65, 0, 0.45, 0); l2.Rotation = -50; l2.AnchorPoint = Vector2.new(0.5, 0.5); l2.BackgroundColor3 = Color3.fromRGB(40, 30, 50); l2.BorderSizePixel = 0

	local function CreateFusionSlot(pos, titleText, isResult)
		local f, fStroke = CreateGrimPanel(AltarContainer); f.Size = UDim2.new(0, 90, 0, 90); f.Position = pos; f.AnchorPoint = Vector2.new(0.5, 0.5); fStroke.Color = Color3.fromRGB(70, 70, 80); f.ZIndex = 5

		local bgGlow = Instance.new("Frame", f); bgGlow.Size = UDim2.new(1, 0, 1, 0); bgGlow.BackgroundColor3 = Color3.fromRGB(170, 85, 255); bgGlow.BackgroundTransparency = 1; bgGlow.BorderSizePixel = 0; bgGlow.ZIndex = 4

		local t = UIHelpers.CreateLabel(f, titleText, UDim2.new(1, -10, 0, 30), Enum.Font.GothamBlack, UIHelpers.Colors.TextMuted, 10); t.Position = UDim2.new(0, 5, 0, 5); t.TextScaled = true; t.ZIndex = 6
		Instance.new("UITextSizeConstraint", t).MaxTextSize = 11

		if isResult then
			f.Size = UDim2.new(0, 110, 0, 110)
			local qLbl = UIHelpers.CreateLabel(f, "?", UDim2.new(1, 0, 1, -30), Enum.Font.GothamBlack, Color3.fromRGB(80, 70, 90), 40); qLbl.Position = UDim2.new(0, 0, 0, 30); qLbl.ZIndex = 6
			return f, t, qLbl, nil, bgGlow
		end

		local addBtn, addStroke = CreateSharpButton(f, "+", UDim2.new(0, 35, 0, 35), Enum.Font.GothamBlack, 20); addBtn.Position = UDim2.new(0.5, 0, 0.5, 10); addBtn.AnchorPoint = Vector2.new(0.5, 0.5); addBtn.ZIndex = 6
		local overBtn = Instance.new("TextButton", f); overBtn.Size = UDim2.new(1, 0, 1, 0); overBtn.BackgroundTransparency = 1; overBtn.Text = ""; overBtn.ZIndex = 10
		overBtn.MouseEnter:Connect(function() fStroke.Color = UIHelpers.Colors.Gold; if addBtn.Visible then addStroke.Color = UIHelpers.Colors.Gold; addBtn.TextColor3 = UIHelpers.Colors.Gold end end)
		overBtn.MouseLeave:Connect(function() if t.TextColor3 ~= UIHelpers.Colors.TextMuted then fStroke.Color = t.TextColor3 else fStroke.Color = Color3.fromRGB(70, 70, 80) end; if addBtn.Visible then addStroke.Color = Color3.fromRGB(70, 70, 80); addBtn.TextColor3 = Color3.fromRGB(245, 245, 245) end end)
		return f, t, addBtn, overBtn, bgGlow
	end

	local Slot1, Slot1Title, Slot1AddBtn, Slot1OverBtn, S1Glow = CreateFusionSlot(UDim2.new(0.2, 0, 0.25, 0), "SUBJECT ALPHA", false)
	local PlusLbl = UIHelpers.CreateLabel(AltarContainer, "+", UDim2.new(0, 20, 0, 100), Enum.Font.GothamBlack, UIHelpers.Colors.TextMuted, 24)
	local Slot2, Slot2Title, Slot2AddBtn, Slot2OverBtn, S2Glow = CreateFusionSlot(UDim2.new(0.8, 0, 0.25, 0), "SUBJECT OMEGA", false)
	local EqLbl = UIHelpers.CreateLabel(AltarContainer, "=", UDim2.new(0, 20, 0, 100), Enum.Font.GothamBlack, UIHelpers.Colors.TextMuted, 24)
	local ResultSlot, ResultTitle, ResultLbl, _, ResGlow = CreateFusionSlot(UDim2.new(0.5, 0, 0.75, 0), "HYBRIDIZATION", true)

	local FuseBtn, FuseStroke = CreateSharpButton(TLLeftPanel, "INITIATE FUSION (15K Dews)", UDim2.new(0.8, 0, 0, 45), Enum.Font.GothamBlack, 14); FuseBtn.Position = UDim2.new(0.5, 0, 0, 320); FuseBtn.AnchorPoint = Vector2.new(0.5, 0); FuseBtn.TextColor3 = Color3.fromRGB(170, 85, 255); FuseStroke.Color = Color3.fromRGB(170, 85, 255)

	-- [[ FIX: Refactored Titan Selection Panel to smoothly overlap instead of breaking scroll height ]]
	local SelectionPanel = Instance.new("Frame", TLLeftPanel)
	SelectionPanel.Size = UDim2.new(1, 0, 0, 240)
	SelectionPanel.Position = UDim2.new(0, 0, 0, 80)
	SelectionPanel.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
	SelectionPanel.ZIndex = 50
	SelectionPanel.Visible = false
	local spStroke = Instance.new("UIStroke", SelectionPanel); spStroke.Color = Color3.fromRGB(70, 70, 80); spStroke.Thickness = 2

	local spTitle = UIHelpers.CreateLabel(SelectionPanel, "SELECT A TITAN", UDim2.new(0.5, 0, 0, 20), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 14); spTitle.Position = UDim2.new(0, 10, 0, 5); spTitle.TextXAlignment = Enum.TextXAlignment.Left; spTitle.ZIndex = 51
	local spClose = CreateSharpButton(SelectionPanel, "CANCEL", UDim2.new(0, 80, 0, 20), Enum.Font.GothamBlack, 11)
	spClose.Position = UDim2.new(1, -10, 0, 5); spClose.AnchorPoint = Vector2.new(1,0); spClose.TextColor3 = Color3.fromRGB(255,100,100); spClose:FindFirstChild("UIStroke").Color = Color3.fromRGB(255,100,100); spClose.ZIndex = 51
	spClose.MouseButton1Click:Connect(function() SelectionPanel.Visible = false; AltarContainer.Visible = true; FuseBtn.Visible = true end)

	local TitanScroll = Instance.new("ScrollingFrame", SelectionPanel); TitanScroll.Size = UDim2.new(1, 0, 1, -25); TitanScroll.Position = UDim2.new(0, 0, 0, 25); TitanScroll.BackgroundTransparency = 1; TitanScroll.ScrollBarThickness = 6; TitanScroll.BorderSizePixel = 0; TitanScroll.ZIndex = 52
	local tsLayout = Instance.new("UIListLayout", TitanScroll); tsLayout.Padding = UDim.new(0, 8); tsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() TitanScroll.CanvasSize = UDim2.new(0,0,0, tsLayout.AbsoluteContentSize.Y + 10) end)
	local noTitansLbl = UIHelpers.CreateLabel(TitanScroll, "No valid Titans found in Vault.", UDim2.new(1, 0, 0, 50), Enum.Font.GothamMedium, UIHelpers.Colors.TextMuted, 14); noTitansLbl.Visible = false; noTitansLbl.ZIndex = 53

	local glowTweenInfo = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local l1Glow = TweenService:Create(l1, glowTweenInfo, {BackgroundColor3 = Color3.fromRGB(200, 100, 255)})
	local l2Glow = TweenService:Create(l2, glowTweenInfo, {BackgroundColor3 = Color3.fromRGB(200, 100, 255)})

	local selectedAlpha = nil; local selectedOmega = nil; local activeSlotIndex = 1

	local function UpdateFusionUI()
		local function updateSlot(slotData, titleLbl, addBtn, strk, defaultTitle)
			if slotData then
				local tData = (type(TitanData) == "table" and TitanData.Titans) and TitanData.Titans[slotData.Name] or nil
				local rColor = CONFIG.RarityColors[tData and tData.Rarity or "Common"] or Color3.fromRGB(200,200,200)
				titleLbl.Text = string.upper(slotData.Name); titleLbl.TextColor3 = rColor; addBtn.Visible = false; strk.Color = rColor
			else
				titleLbl.Text = defaultTitle; titleLbl.TextColor3 = UIHelpers.Colors.TextMuted; addBtn.Visible = true; strk.Color = Color3.fromRGB(70, 70, 80)
			end
		end
		updateSlot(selectedAlpha, Slot1Title, Slot1AddBtn, Slot1:FindFirstChild("UIStroke"), "SUBJECT ALPHA")
		updateSlot(selectedOmega, Slot2Title, Slot2AddBtn, Slot2:FindFirstChild("UIStroke"), "SUBJECT OMEGA")

		if selectedAlpha and selectedOmega then
			ResultLbl.TextColor3 = Color3.fromRGB(200, 100, 255); ResultSlot:FindFirstChild("UIStroke").Color = Color3.fromRGB(200, 100, 255)
			S1Glow.BackgroundTransparency = 0.8; S2Glow.BackgroundTransparency = 0.8; ResGlow.BackgroundTransparency = 0.6
			l1Glow:Play(); l2Glow:Play()
		else
			ResultLbl.TextColor3 = Color3.fromRGB(80, 70, 90); ResultSlot:FindFirstChild("UIStroke").Color = Color3.fromRGB(70, 70, 80)
			S1Glow.BackgroundTransparency = 1; S2Glow.BackgroundTransparency = 1; ResGlow.BackgroundTransparency = 1
			l1Glow:Cancel(); l2Glow:Cancel()
			l1.BackgroundColor3 = Color3.fromRGB(40, 30, 50); l2.BackgroundColor3 = Color3.fromRGB(40, 30, 50)
		end
	end

	local function OpenTitanSelection(slotId)
		activeSlotIndex = slotId
		AltarContainer.Visible = false
		FuseBtn.Visible = false
		SelectionPanel.Visible = true
		for _, c in ipairs(TitanScroll:GetChildren()) do if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end end
		local foundAny = false; local titanSlots = {"Equipped", "1", "2", "3", "4", "5", "6"}
		for _, slotKey in ipairs(titanSlots) do
			local tName = (slotKey == "Equipped") and player:GetAttribute("Titan") or player:GetAttribute("Titan_Slot" .. slotKey)
			if tName and tName ~= "" and tName ~= "None" then
				if (activeSlotIndex == 1 and selectedOmega and selectedOmega.Slot == slotKey) or (activeSlotIndex == 2 and selectedAlpha and selectedAlpha.Slot == slotKey) then continue end
				foundAny = true
				local rarityColor = Color3.fromRGB(200, 200, 200)
				if type(TitanData) == "table" and TitanData.Titans and TitanData.Titans[tName] then rarityColor = CONFIG.RarityColors[TitanData.Titans[tName].Rarity] or rarityColor end
				local labelText = (slotKey == "Equipped" and "EQUIPPED" or "SLOT " .. slotKey) .. ": " .. string.upper(tName)
				local tBtn, tBtnStroke = CreateSharpButton(TitanScroll, labelText, UDim2.new(1, -10, 0, 50), Enum.Font.GothamBlack, 14); tBtn.ZIndex = 53; tBtn.TextColor3 = rarityColor; tBtnStroke.Color = rarityColor
				tBtn.MouseButton1Click:Connect(function()
					if activeSlotIndex == 1 then selectedAlpha = {Slot = slotKey, Name = tName} else selectedOmega = {Slot = slotKey, Name = tName} end
					SelectionPanel.Visible = false
					AltarContainer.Visible = true
					FuseBtn.Visible = true
					UpdateFusionUI()
				end)
			end
		end
		noTitansLbl.Visible = not foundAny
	end
	Slot1OverBtn.MouseButton1Click:Connect(function() OpenTitanSelection(1) end)
	Slot2OverBtn.MouseButton1Click:Connect(function() OpenTitanSelection(2) end)
	FuseBtn.MouseButton1Click:Connect(function()
		if not selectedAlpha or not selectedOmega then NotifySafe("Requires two Subjects.", "Error"); return end
		Network:WaitForChild("FuseTitan"):FireServer(selectedAlpha.Slot, selectedOmega.Slot)
		selectedAlpha = nil; selectedOmega = nil; UpdateFusionUI()
	end)

	Network:WaitForChild("FusionComplete").OnClientEvent:Connect(function(result)
		local cinGui = Instance.new("ScreenGui", player.PlayerGui)
		cinGui.Name = "FusionCinematicGui"
		cinGui.DisplayOrder = 1000

		local bg = Instance.new("Frame", cinGui)
		bg.Size = UDim2.new(1,0,1,0); bg.BackgroundColor3 = Color3.new(0,0,0); bg.BackgroundTransparency = 1
		TweenService:Create(bg, TweenInfo.new(0.3), {BackgroundTransparency = 0.5}):Play()

		local title = UIHelpers.CreateLabel(bg, "NEW HYBRID DISCOVERED", UDim2.new(1,0,0,50), Enum.Font.GothamBlack, Color3.fromRGB(170, 85, 255), 40)
		title.Position = UDim2.new(0,0,0.4,0); title.TextTransparency = 1

		local itemName = UIHelpers.CreateLabel(bg, string.upper(result), UDim2.new(1,0,0,50), Enum.Font.GothamBlack, Color3.fromRGB(255, 85, 255), 60)
		itemName.Position = UDim2.new(0,0,0.5,0); itemName.TextTransparency = 1

		TweenService:Create(title, TweenInfo.new(0.4), {TextTransparency = 0, Position = UDim2.new(0,0,0.35,0)}):Play()
		task.wait(0.2)
		TweenService:Create(itemName, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {TextTransparency = 0, TextSize = 70}):Play()
		if VFXManager and type(VFXManager.PlaySFX) == "function" then VFXManager.PlaySFX("Reveal", 1) end

		NotifySafe("Successfully hybridized into " .. result .. "!", "Success")

		task.wait(3)
		local fade = TweenService:Create(bg, TweenInfo.new(0.5), {BackgroundTransparency = 1})
		TweenService:Create(title, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
		TweenService:Create(itemName, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
		fade:Play(); fade.Completed:Wait()
		cinGui:Destroy()
	end)

	-- Right: Variant Awakening
	local TLRightPanel = Instance.new("Frame", tlSplitContainer); TLRightPanel.Size = UDim2.new(0.48, 0, 0, 450); TLRightPanel.BackgroundTransparency = 1
	local mTitle = UIHelpers.CreateLabel(TLRightPanel, "VARIANT AWAKENING", UDim2.new(1, 0, 0, 30), Enum.Font.GothamBlack, Color3.fromRGB(255, 85, 85), 20); mTitle.Position = UDim2.new(0, 0, 0, 0); mTitle.TextXAlignment = Enum.TextXAlignment.Left
	local mDesc = UIHelpers.CreateLabel(TLRightPanel, "Expose your equipped Titan to anomalous compounds to mutate its biology, granting permanent cosmetic variants and trait buffs.", UDim2.new(1, -20, 0, 40), Enum.Font.GothamMedium, UIHelpers.Colors.TextMuted, 13); mDesc.Position = UDim2.new(0, 0, 0, 30); mDesc.TextXAlignment = Enum.TextXAlignment.Left; mDesc.TextWrapped = true

	local currentVariantCard, cvStroke = CreateGrimPanel(TLRightPanel); currentVariantCard.Size = UDim2.new(0.9, 0, 0, 90); currentVariantCard.Position = UDim2.new(0.05, 0, 0, 90)
	local cvTag = UIHelpers.CreateLabel(currentVariantCard, "CURRENT VARIANT:", UDim2.new(1, -20, 0, 20), Enum.Font.GothamBold, UIHelpers.Colors.TextMuted, 11); cvTag.Position = UDim2.new(0, 10, 0, 10); cvTag.TextXAlignment = Enum.TextXAlignment.Left
	local cvName = UIHelpers.CreateLabel(currentVariantCard, "STANDARD", UDim2.new(1, -20, 0, 30), Enum.Font.GothamBlack, Color3.fromRGB(255, 255, 255), 20); cvName.Position = UDim2.new(0, 10, 0, 30); cvName.TextXAlignment = Enum.TextXAlignment.Left
	local cvBuff = UIHelpers.CreateLabel(currentVariantCard, "Standard shifting properties.", UDim2.new(1, -20, 0, 20), Enum.Font.GothamMedium, Color3.fromRGB(200, 255, 200), 12); cvBuff.Position = UDim2.new(0, 10, 0, 60); cvBuff.TextXAlignment = Enum.TextXAlignment.Left

	local MutateBtn, MutateStroke = CreateSharpButton(TLRightPanel, "AWAKEN VARIANT (25K Dews + 1 Abyssal Blood)", UDim2.new(0.9, 0, 0, 45), Enum.Font.GothamBlack, 12)
	MutateBtn.Position = UDim2.new(0.5, 0, 0, 195); MutateBtn.AnchorPoint = Vector2.new(0.5, 0); MutateBtn.TextColor3 = Color3.fromRGB(255, 85, 85); MutateStroke.Color = Color3.fromRGB(255, 85, 85)

	local function UpdateVariantUI()
		local myTitan = player:GetAttribute("Titan") or "None"
		if myTitan == "None" then
			cvName.Text = "NO TITAN EQUIPPED"; cvName.TextColor3 = UIHelpers.Colors.TextMuted; cvBuff.Text = "You must inherit a Titan to mutate it."; cvStroke.Color = Color3.fromRGB(70, 70, 80)
			MutateBtn.Active = false; MutateBtn.TextColor3 = Color3.fromRGB(100, 100, 100); MutateStroke.Color = Color3.fromRGB(50, 50, 60)
			return
		end

		MutateBtn.Active = true; MutateBtn.TextColor3 = Color3.fromRGB(255, 85, 85); MutateStroke.Color = Color3.fromRGB(255, 85, 85)
		local variantKey = player:GetAttribute("TitanVariant") or "Standard"
		local vData = CONFIG.TitanVariants[variantKey]
		if vData then
			cvName.Text = string.upper(variantKey); cvName.TextColor3 = Color3.fromHex(vData.Color:gsub("#", "")); cvStroke.Color = Color3.fromHex(vData.Color:gsub("#", ""))
			cvBuff.Text = vData.Desc
		end
	end

	MutateBtn.MouseButton1Click:Connect(function()
		if not MutateBtn.Active then return end
		local dews = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Dews") and player.leaderstats.Dews.Value or 0
		local abyssalBlood = GetItemCount("Abyssal Blood")
		if dews < 25000 or abyssalBlood < 1 then NotifySafe("Requires 25K Dews and 1 Abyssal Blood!", "Error"); return end

		MutateBtn.Active = false
		local success, result = Network:WaitForChild("MutateTitan"):InvokeServer()
		if success then
			local variants = {"Titan Hardening", "Crimson Steam", "Abyssal Eyes", "Beast Fur", "Crystalline Nape"}
			for i = 1, 15 do
				if VFXManager and type(VFXManager.PlaySFX) == "function" then VFXManager.PlaySFX("Click", 1 + (i/15)) end
				cvName.Text = string.upper(variants[math.random(1, #variants)])
				cvName.TextColor3 = Color3.fromRGB(150, 150, 150)
				task.wait(0.05)
			end
			if VFXManager and type(VFXManager.PlaySFX) == "function" then VFXManager.PlaySFX("Reveal", 1) end
			NotifySafe("Variant Awakened! Your Titan gained: " .. result, "Success")
		else
			NotifySafe(result, "Error")
		end
		UpdateVariantUI()
	end)

	player.AttributeChanged:Connect(function(attr) if attr == "TitanVariant" or attr == "Titan" then UpdateVariantUI() end end)
	UpdateVariantUI()

	LayoutRefs.TitanLayout = tlLayout
	LayoutRefs.TitanLeft = TLLeftPanel
	LayoutRefs.TitanRight = TLRightPanel

	camera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateLayoutForScreen)
	UpdateLayoutForScreen()
end

return SupplyForgeTab