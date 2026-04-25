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
local NotificationManager = require(SharedUI:WaitForChild("NotificationManager"))
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
	}
}

local function ColorToHex(c3)
	return string.format("#%02X%02X%02X", math.floor(c3.R * 255), math.floor(c3.G * 255), math.floor(c3.B * 255))
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

local function GetClanBuffStrings(clanKey, isAbyssal)
	local buffs = {}
	if not ClanData.Clans or not ClanData.Clans[clanKey] then return buffs end
	local cData = ClanData.Clans[clanKey]

	if clanKey == "Fritz" then
		table.insert(buffs, "6.0x MAX HP | 5.0x DMG | 5.0x ARMOR | 3.5x SPEED")
		table.insert(buffs, "8x Guaranteed Death Defiance")
		table.insert(buffs, "Founding Titan Synergy: +0.50x DMG, HP, ARMOR")
		return buffs
	end

	if isAbyssal then
		local statLine = ""
		if cData.AbyssalDmgMult then statLine = statLine .. cData.AbyssalDmgMult .. "x DMG | " end
		if cData.AbyssalHpMult then statLine = statLine .. cData.AbyssalHpMult .. "x HP | " end
		if cData.AbyssalArmorMult then statLine = statLine .. cData.AbyssalArmorMult .. "x ARMOR | " end
		if cData.AbyssalSpdMult then statLine = statLine .. cData.AbyssalSpdMult .. "x SPD | " end
		if statLine ~= "" then table.insert(buffs, statLine:sub(1, -3)) end

		if cData.AbyssalSurvivals then
			table.insert(buffs, cData.AbyssalSurvivals .. "x Death Defiance (" .. (cData.SurvivalChance or 100) .. "%)")
		end
		if cData.AbyssalNapeCritMultiplier then
			table.insert(buffs, cData.AbyssalNapeCritMultiplier .. "x Nape Crit DMG")
		end
		if cData.AbyssalDodgeBonus then
			table.insert(buffs, "+" .. cData.AbyssalDodgeBonus .. "% Dodge Chance")
		end
		if cData.AbyssalMomentumDamagePerHit then
			table.insert(buffs, "+" .. (cData.AbyssalMomentumDamagePerHit*100) .. "% DMG per Momentum Stack")
		end
	end
	return buffs
end

local LayoutRefs = {}

local function UpdateLayoutForScreen()
	local vp = camera.ViewportSize
	if vp.X == 0 or vp.Y == 0 then return end
	local isMobile = (vp.X <= 850) or (vp.Y > vp.X)

	if LayoutRefs.MarketLayout then LayoutRefs.MarketLayout.FillDirection = isMobile and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal end
	if LayoutRefs.MarketLeft then LayoutRefs.MarketLeft.Size = isMobile and UDim2.new(0.95, 0, 0, 250) or UDim2.new(0.48, 0, 1, 0) end
	if LayoutRefs.MarketRight then LayoutRefs.MarketRight.Size = isMobile and UDim2.new(0.95, 0, 0, 500) or UDim2.new(0.5, 0, 1, 0) end

	if LayoutRefs.ForgeLayout then LayoutRefs.ForgeLayout.FillDirection = isMobile and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal end
	if LayoutRefs.ForgeLeft then LayoutRefs.ForgeLeft.Size = isMobile and UDim2.new(0.95, 0, 0, 400) or UDim2.new(0.3, 0, 1, 0) end
	if LayoutRefs.ForgeRight then LayoutRefs.ForgeRight.Size = isMobile and UDim2.new(0.95, 0, 0, 500) or UDim2.new(0.68, 0, 1, 0) end

	if LayoutRefs.RitualLayout then LayoutRefs.RitualLayout.FillDirection = isMobile and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal end
	if LayoutRefs.RitualLeft then LayoutRefs.RitualLeft.Size = isMobile and UDim2.new(0.95, 0, 0, 250) or UDim2.new(0.28, 0, 1, 0) end
	if LayoutRefs.RitualRight then 
		LayoutRefs.RitualRight.Size = isMobile and UDim2.new(0.95, 0, 0, 500) or UDim2.new(0.7, 0, 1, 0) 
		if not isMobile then LayoutRefs.RitualRight.Position = UDim2.new(1, 0, 0, 0) else LayoutRefs.RitualRight.Position = UDim2.new(0, 0, 0, 0) end
	end

	if LayoutRefs.FusionLayout then LayoutRefs.FusionLayout.FillDirection = isMobile and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal end
	if LayoutRefs.FusionLeft then LayoutRefs.FusionLeft.Size = isMobile and UDim2.new(0.95, 0, 0, 450) or UDim2.new(0.55, 0, 1, 0) end
	if LayoutRefs.FusionRight then LayoutRefs.FusionRight.Size = isMobile and UDim2.new(0.95, 0, 0, 500) or UDim2.new(0.45, -10, 1, -20) end

	if LayoutRefs.TradeLayout then LayoutRefs.TradeLayout.FillDirection = isMobile and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal end
	if LayoutRefs.TradeLeft then LayoutRefs.TradeLeft.Size = isMobile and UDim2.new(0.95, 0, 0, 250) or UDim2.new(0.48, 0, 1, 0) end
	if LayoutRefs.TradeRight then LayoutRefs.TradeRight.Size = isMobile and UDim2.new(0.95, 0, 0, 450) or UDim2.new(0.5, 0, 1, 0) end
end

function SupplyForgeTab.Initialize(parentFrame)
	for _, child in ipairs(parentFrame:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end

	local MainFrame = Instance.new("ScrollingFrame", parentFrame)
	MainFrame.Size = UDim2.new(1, 0, 1, 0)
	MainFrame.BackgroundTransparency = 1
	MainFrame.ScrollBarThickness = 0
	MainFrame.BorderSizePixel = 0

	local mLayout = Instance.new("UIListLayout", MainFrame)
	mLayout.SortOrder = Enum.SortOrder.LayoutOrder
	mLayout.Padding = UDim.new(0, 15)
	mLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local mPad = Instance.new("UIPadding", MainFrame)
	mPad.PaddingTop = UDim.new(0, 15)

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

	local contentLayout = Instance.new("UIListLayout", ContentArea)
	contentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		ContentArea.Size = UDim2.new(0.95, 0, 0, contentLayout.AbsoluteContentSize.Y)
	end)

	local subTabs = { "MARKETPLACE", "THE FORGE", "BLOODLINE RITUAL", "TITAN FUSION", "PLAYER TRADE" }
	local activeSubFrames = {}
	local subBtns = {}

	for i, tabName in ipairs(subTabs) do
		local btn, stroke = UIHelpers.CreateButton(SubNav, tabName, UDim2.new(0, 115, 0, 30), Enum.Font.GothamBold, 11)
		btn.TextColor3 = UIHelpers.Colors.TextMuted
		stroke.Color = UIHelpers.Colors.BorderMuted

		local subFrame = Instance.new("Frame", ContentArea)
		subFrame.Name = tabName
		subFrame.Size = UDim2.new(1, 0, 0, 800)
		subFrame.BackgroundTransparency = 1
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

	subBtns["MARKETPLACE"].Btn.TextColor3 = UIHelpers.Colors.Gold
	subBtns["MARKETPLACE"].Stroke.Color = UIHelpers.Colors.Gold

	-- ==========================================
	-- 1. MARKETPLACE
	-- ==========================================
	local MarketTab = activeSubFrames["MARKETPLACE"]

	local marketTitle = UIHelpers.CreateLabel(MarketTab, "MARKETPLACE & SUPPLY", UDim2.new(1, 0, 0, 30), Enum.Font.GothamBlack, UIHelpers.Colors.TextWhite, 20)
	marketTitle.Position = UDim2.new(0, 0, 0, 0)

	local SplitContainer = Instance.new("Frame", MarketTab)
	SplitContainer.Size = UDim2.new(1, 0, 1, -40)
	SplitContainer.Position = UDim2.new(0, 0, 0, 40)
	SplitContainer.BackgroundTransparency = 1

	local scLayout = Instance.new("UIListLayout", SplitContainer)
	scLayout.FillDirection = Enum.FillDirection.Horizontal
	scLayout.Padding = UDim.new(0, 20)

	local LeftPanel = Instance.new("Frame", SplitContainer)
	LeftPanel.Size = UDim2.new(0.48, 0, 1, 0)
	LeftPanel.BackgroundTransparency = 1

	local PremContainer = Instance.new("Frame", LeftPanel)
	PremContainer.Size = UDim2.new(1, 0, 0.65, 0)
	PremContainer.BackgroundTransparency = 1 

	local pTitle = UIHelpers.CreateLabel(PremContainer, "PREMIUM STORE", UDim2.new(1, 0, 0, 30), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 16)

	local PremScroll = Instance.new("ScrollingFrame", PremContainer)
	PremScroll.Size = UDim2.new(1, -20, 1, -40)
	PremScroll.Position = UDim2.new(0, 10, 0, 30)
	PremScroll.BackgroundTransparency = 1
	PremScroll.ScrollBarThickness = 4
	PremScroll.BorderSizePixel = 0

	local pslayout = Instance.new("UIListLayout", PremScroll)
	pslayout.Padding = UDim.new(0, 10)
	pslayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() PremScroll.CanvasSize = UDim2.new(0,0,0, pslayout.AbsoluteContentSize.Y + 10) end)

	local function CreatePremiumCard(titleText, descText, buyAction, giftAction)
		local pCard = Instance.new("Frame", PremScroll)
		pCard.Size = UDim2.new(1, -10, 0, 80)
		pCard.BackgroundTransparency = 1

		local bgGlow = Instance.new("Frame", pCard)
		bgGlow.Size = UDim2.new(1, 0, 1, 0)
		bgGlow.BackgroundColor3 = UIHelpers.Colors.Gold
		bgGlow.BorderSizePixel = 0
		bgGlow.ZIndex = 1
		local grad = Instance.new("UIGradient", bgGlow)
		grad.Rotation = 90
		grad.Transparency = NumberSequence.new{ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.95), NumberSequenceKeypoint.new(1, 0.7) }

		local pName = UIHelpers.CreateLabel(pCard, string.upper(titleText), UDim2.new(1, -20, 0, 20), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 14)
		pName.Position = UDim2.new(0, 10, 0, 5); pName.TextXAlignment = Enum.TextXAlignment.Left; pName.ZIndex = 2

		local pDesc = UIHelpers.CreateLabel(pCard, descText or "A premium item.", UDim2.new(1, -20, 0, 20), Enum.Font.GothamMedium, UIHelpers.Colors.TextWhite, 11)
		pDesc.Position = UDim2.new(0, 10, 0, 25); pDesc.TextXAlignment = Enum.TextXAlignment.Left; pDesc.ZIndex = 2

		local btnContainer = Instance.new("Frame", pCard)
		btnContainer.Size = UDim2.new(1, -20, 0, 30)
		btnContainer.Position = UDim2.new(0, 10, 1, -35)
		btnContainer.BackgroundTransparency = 1
		btnContainer.ZIndex = 3
		local bcLayout = Instance.new("UIListLayout", btnContainer); bcLayout.FillDirection = Enum.FillDirection.Horizontal; bcLayout.Padding = UDim.new(0, 10)

		if giftAction then
			local buyBtn, buyStroke = CreateSharpButton(btnContainer, "BUY", UDim2.new(0.48, 0, 1, 0), Enum.Font.GothamBlack, 12)
			buyBtn.TextColor3 = Color3.fromRGB(85, 255, 85); buyStroke.Color = Color3.fromRGB(85, 255, 85); buyBtn.MouseButton1Click:Connect(buyAction)

			local giftBtn, giftStroke = CreateSharpButton(btnContainer, "GIFT", UDim2.new(0.48, 0, 1, 0), Enum.Font.GothamBlack, 12)
			giftBtn.TextColor3 = Color3.fromRGB(200, 100, 255); giftStroke.Color = Color3.fromRGB(200, 100, 255); giftBtn.MouseButton1Click:Connect(giftAction)
		else
			local buyBtn, buyStroke = CreateSharpButton(btnContainer, "BUY", UDim2.new(1, 0, 1, 0), Enum.Font.GothamBlack, 12)
			buyBtn.TextColor3 = Color3.fromRGB(85, 255, 85); buyStroke.Color = Color3.fromRGB(85, 255, 85); buyBtn.MouseButton1Click:Connect(buyAction)
		end
	end

	if ItemData.Gamepasses then
		for _, gp in ipairs(ItemData.Gamepasses) do
			CreatePremiumCard(gp.Name, gp.Desc, 
				function() MarketplaceService:PromptGamePassPurchase(player, gp.ID) end,
				gp.GiftID and function() MarketplaceService:PromptProductPurchase(player, gp.GiftID) end or nil
			)
		end
	end

	if ItemData.Products then
		for _, prod in ipairs(ItemData.Products) do
			if not prod.IsReroll and not string.find(prod.Name, "Gift:") then
				CreatePremiumCard(prod.Name, prod.Desc, 
					function() MarketplaceService:PromptProductPurchase(player, prod.ID) end, nil
				)
			end
		end
	end

	local CodeContainer = Instance.new("Frame", LeftPanel)
	CodeContainer.Size = UDim2.new(1, 0, 0.3, 0)
	CodeContainer.Position = UDim2.new(0, 0, 0.7, 0)
	CodeContainer.BackgroundTransparency = 1 

	local cInput = Instance.new("TextBox", CodeContainer)
	cInput.Size = UDim2.new(0.8, 0, 0, 40)
	cInput.Position = UDim2.new(0.5, 0, 0.3, 0)
	cInput.AnchorPoint = Vector2.new(0.5, 0.5)
	cInput.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
	cInput.TextColor3 = UIHelpers.Colors.Gold
	cInput.Font = Enum.Font.GothamBlack
	cInput.TextSize = 14
	cInput.PlaceholderText = "Redeem Code Here"
	cInput.Text = ""
	Instance.new("UIStroke", cInput).Color = UIHelpers.Colors.BorderMuted

	local RedeemBtn, redeemStroke = CreateSharpButton(CodeContainer, "REDEEM", UDim2.new(0.8, 0, 0, 40), Enum.Font.GothamBlack, 16)
	RedeemBtn.Position = UDim2.new(0.5, 0, 0.7, 0)
	RedeemBtn.AnchorPoint = Vector2.new(0.5, 0.5)
	RedeemBtn.TextColor3 = Color3.fromRGB(85, 170, 255)
	redeemStroke.Color = Color3.fromRGB(85, 170, 255)

	local cHint = UIHelpers.CreateLabel(CodeContainer, "ENTER PROMO CODE:", UDim2.new(1, 0, 0, 20), Enum.Font.GothamBlack, UIHelpers.Colors.TextWhite, 12)
	cHint.Position = UDim2.new(0, 0, 1, -25)

	RedeemBtn.MouseButton1Click:Connect(function()
		if cInput.Text ~= "" then
			Network:WaitForChild("RedeemCode"):FireServer(cInput.Text)
			cInput.Text = ""
		end
	end)

	local RightPanel = Instance.new("Frame", SplitContainer)
	RightPanel.Size = UDim2.new(0.5, 0, 1, 0)
	RightPanel.BackgroundTransparency = 1

	local rrContainer = Instance.new("Frame", RightPanel)
	rrContainer.Size = UDim2.new(1, 0, 0, 45)
	rrContainer.BackgroundTransparency = 1
	local rrLayout = Instance.new("UIListLayout", rrContainer); rrLayout.FillDirection = Enum.FillDirection.Horizontal; rrLayout.Padding = UDim.new(0, 10)

	local rrDews, rrDewsStroke = CreateSharpButton(rrContainer, "RESTOCK (300K Dews)", UDim2.new(0.48, 0, 1, 0), Enum.Font.GothamBlack, 12)
	rrDews.TextColor3 = Color3.fromRGB(85, 170, 255)
	rrDewsStroke.Color = Color3.fromRGB(85, 170, 255)

	local rrPremium, rrPremStroke = CreateSharpButton(rrContainer, "RESTOCK (15 R$)", UDim2.new(0.48, 0, 1, 0), Enum.Font.GothamBlack, 12)

	local isFreeRestock = false
	local function UpdateRerollButton()
		local hasVIP = player:GetAttribute("HasVIP")
		local lastRoll = player:GetAttribute("LastFreeReroll") or 0

		if hasVIP and (os.time() - lastRoll) >= 86400 then
			rrPremium.Text = "FREE RESTOCK (VIP)"
			rrPremium.TextColor3 = Color3.fromRGB(200, 100, 255)
			rrPremStroke.Color = Color3.fromRGB(200, 100, 255)
			isFreeRestock = true
		else
			rrPremium.Text = "RESTOCK (50 R$)"
			rrPremium.TextColor3 = Color3.fromRGB(85, 255, 85)
			rrPremStroke.Color = Color3.fromRGB(85, 255, 85)
			isFreeRestock = false
		end
	end
	UpdateRerollButton()

	rrDews.MouseButton1Click:Connect(function() Network:WaitForChild("VIPFreeReroll"):FireServer(true) end)

	rrPremium.MouseButton1Click:Connect(function()
		if isFreeRestock then
			Network:WaitForChild("VIPFreeReroll"):FireServer(false)
		else
			local rerollId = nil
			if ItemData.Products then
				for _, prod in ipairs(ItemData.Products) do
					if prod.IsReroll then rerollId = prod.ID break end
				end
			end
			if rerollId then MarketplaceService:PromptProductPurchase(player, rerollId) end
		end
	end)

	local restockTimer = UIHelpers.CreateLabel(RightPanel, "RESTOCKS IN: 00:00", UDim2.new(1, 0, 0, 20), Enum.Font.GothamBlack, Color3.fromRGB(255, 150, 100), 12)
	restockTimer.Position = UDim2.new(0, 0, 0, 50)

	local SupplyScroll = Instance.new("ScrollingFrame", RightPanel)
	SupplyScroll.Size = UDim2.new(1, 0, 1, -80)
	SupplyScroll.Position = UDim2.new(0, 0, 0, 80)
	SupplyScroll.BackgroundTransparency = 1
	SupplyScroll.ScrollBarThickness = 6
	SupplyScroll.BorderSizePixel = 0

	local ssLayout = Instance.new("UIListLayout", SupplyScroll)
	ssLayout.Padding = UDim.new(0, 8)
	ssLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() SupplyScroll.CanvasSize = UDim2.new(0,0,0, ssLayout.AbsoluteContentSize.Y + 10) end)

	local function AddSupplyItem(itemName, itemData, cost, isSoldOut)
		local rarityColor = CONFIG.RarityColors[itemData.Rarity or "Common"] or Color3.fromRGB(200, 200, 200)

		local c = Instance.new("Frame", SupplyScroll)
		c.Size = UDim2.new(1, -10, 0, 70)
		c.BackgroundTransparency = 1

		local bgGlow = Instance.new("Frame", c)
		bgGlow.Size = UDim2.new(1, 0, 1, 0)
		bgGlow.BackgroundColor3 = rarityColor
		bgGlow.BorderSizePixel = 0
		bgGlow.ZIndex = 1
		local grad = Instance.new("UIGradient", bgGlow)
		grad.Rotation = 90
		grad.Transparency = NumberSequence.new{ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.95), NumberSequenceKeypoint.new(1, 0.7) }

		local cStroke = Instance.new("UIStroke", c)
		cStroke.Color = rarityColor
		cStroke.Thickness = 2
		cStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

		local nameLbl = UIHelpers.CreateLabel(c, itemName, UDim2.new(0.6, 0, 0, 20), Enum.Font.GothamBlack, rarityColor, 16)
		nameLbl.Position = UDim2.new(0, 15, 0, 10); nameLbl.TextXAlignment = Enum.TextXAlignment.Left; nameLbl.ZIndex = 2

		local statsTxt = ""
		if itemData.Bonus then
			for k, v in pairs(itemData.Bonus) do
				local s = tostring(k):sub(1,3):upper()
				statsTxt = statsTxt .. (v > 0 and "+" or "") .. v .. " " .. s .. " | "
			end
			statsTxt = statsTxt:sub(1, -3)
		else statsTxt = itemData.Desc or "A useful item." end

		local statsLbl = UIHelpers.CreateLabel(c, statsTxt, UDim2.new(0.6, 0, 0, 15), Enum.Font.GothamMedium, UIHelpers.Colors.TextWhite, 12)
		statsLbl.Position = UDim2.new(0, 15, 0, 30); statsLbl.TextXAlignment = Enum.TextXAlignment.Left; statsLbl.ZIndex = 2

		local costLbl = UIHelpers.CreateLabel(c, "Cost: " .. tostring(cost) .. " Dews", UDim2.new(0.6, 0, 0, 20), Enum.Font.GothamBold, UIHelpers.Colors.TextMuted, 11)
		costLbl.Position = UDim2.new(0, 15, 1, -25); costLbl.TextXAlignment = Enum.TextXAlignment.Left; costLbl.ZIndex = 2

		local actionText = isSoldOut and "SOLD" or "BUY"
		local buyBtn, buyStroke = CreateSharpButton(c, actionText, UDim2.new(0, 100, 0, 34), Enum.Font.GothamBlack, 12)
		buyBtn.Position = UDim2.new(1, -15, 0.5, 0); buyBtn.AnchorPoint = Vector2.new(1, 0.5); buyBtn.ZIndex = 3

		if isSoldOut then
			buyBtn.TextColor3 = Color3.fromRGB(100, 100, 100); buyStroke.Color = Color3.fromRGB(70, 70, 80); buyBtn.Active = false
		else
			buyBtn.TextColor3 = Color3.fromRGB(85, 255, 85); buyStroke.Color = Color3.fromRGB(85, 255, 85)
			buyBtn.MouseButton1Click:Connect(function() Network:WaitForChild("ShopAction"):FireServer("BuyItem", itemName) end)
		end
	end

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
				local m = math.floor(timeLeft / 60)
				local s = timeLeft % 60
				restockTimer.Text = string.format("RESTOCKS IN: %02d:%02d", m, s)
				task.wait(1); timeLeft -= 1
			end
			if isShopTimerActive then RefreshShop() end
		end)
	end

	player.AttributeChanged:Connect(function(attr)
		if attr == "ShopPurchases_Data" or attr == "PersonalShopSeed" then RefreshShop() end
		if attr == "LastFreeReroll" or attr == "HasVIP" then UpdateRerollButton() end
	end)
	RefreshShop()

	LayoutRefs.MarketLayout = scLayout
	LayoutRefs.MarketLeft = LeftPanel
	LayoutRefs.MarketRight = RightPanel

	-- ==========================================
	-- 2. THE FORGE 
	-- ==========================================
	local ForgeTab = activeSubFrames["THE FORGE"]

	local fSplitContainer = Instance.new("Frame", ForgeTab)
	fSplitContainer.Size = UDim2.new(1, 0, 1, 0)
	fSplitContainer.BackgroundTransparency = 1
	local ftLayout = Instance.new("UIListLayout", fSplitContainer)
	ftLayout.FillDirection = Enum.FillDirection.Horizontal
	ftLayout.Padding = UDim.new(0, 15)

	local selectedRecipeName = nil 

	local RecipeList = Instance.new("ScrollingFrame", fSplitContainer)
	RecipeList.Size = UDim2.new(0.3, 0, 1, 0)
	RecipeList.BackgroundTransparency = 1
	RecipeList.ScrollBarThickness = 4
	RecipeList.BorderSizePixel = 0

	local rlLayout = Instance.new("UIListLayout", RecipeList)
	rlLayout.Padding = UDim.new(0, 10)
	rlLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() RecipeList.CanvasSize = UDim2.new(0, 0, 0, rlLayout.AbsoluteContentSize.Y + 20) end)

	local BlueprintPanel = Instance.new("Frame", fSplitContainer)
	BlueprintPanel.Size = UDim2.new(0.68, 0, 1, 0)
	BlueprintPanel.BackgroundTransparency = 1 

	local InfoView = Instance.new("Frame", BlueprintPanel)
	InfoView.Size = UDim2.new(1, 0, 1, 0)
	InfoView.BackgroundTransparency = 1

	local bpTitle = UIHelpers.CreateLabel(InfoView, "SELECT A BLUEPRINT", UDim2.new(1, -40, 0, 40), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 24)
	bpTitle.Position = UDim2.new(0, 20, 0, 10); bpTitle.TextXAlignment = Enum.TextXAlignment.Left

	local bpDesc = UIHelpers.CreateLabel(InfoView, "Select an item from the registry to view its crafting requirements.", UDim2.new(1, -40, 0, 40), Enum.Font.GothamMedium, UIHelpers.Colors.TextMuted, 14)
	bpDesc.Position = UDim2.new(0, 20, 0, 50); bpDesc.TextXAlignment = Enum.TextXAlignment.Left; bpDesc.TextWrapped = true; bpDesc.TextYAlignment = Enum.TextYAlignment.Top

	local ReqTitle = UIHelpers.CreateLabel(InfoView, "REQUIRED MATERIALS", UDim2.new(1, -40, 0, 30), Enum.Font.GothamBlack, UIHelpers.Colors.TextWhite, 16)
	ReqTitle.Position = UDim2.new(0, 20, 0, 95); ReqTitle.TextXAlignment = Enum.TextXAlignment.Left; ReqTitle.Visible = false

	local ReqList = Instance.new("Frame", InfoView)
	ReqList.Size = UDim2.new(1, -40, 0, 150)
	ReqList.Position = UDim2.new(0, 20, 0, 125)
	ReqList.BackgroundTransparency = 1
	local reqLayout = Instance.new("UIListLayout", ReqList); reqLayout.Padding = UDim.new(0, 8)

	reqLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		ReqList.Size = UDim2.new(1, -40, 0, reqLayout.AbsoluteContentSize.Y)
	end)

	local CraftBtn, CraftStroke = CreateSharpButton(InfoView, "FORGE EQUIPMENT", UDim2.new(0.8, 0, 0, 50), Enum.Font.GothamBlack, 18)
	CraftBtn.Position = UDim2.new(0.5, 0, 1, -10); CraftBtn.AnchorPoint = Vector2.new(0.5, 1); CraftBtn.Visible = false
	CraftBtn.TextColor3 = Color3.fromRGB(225, 185, 60)
	CraftStroke.Color = Color3.fromRGB(225, 185, 60)

	local MinigameView = Instance.new("Frame", BlueprintPanel)
	MinigameView.Size = UDim2.new(1, 0, 1, 0)
	MinigameView.BackgroundTransparency = 1
	MinigameView.Visible = false

	local mgTitle = UIHelpers.CreateLabel(MinigameView, "ACTIVE FORGE", UDim2.new(1, 0, 0, 40), Enum.Font.GothamBlack, Color3.fromRGB(255, 100, 100), 24)
	mgTitle.Position = UDim2.new(0, 0, 0, 20)

	local mgInst = UIHelpers.CreateLabel(MinigameView, "Strike when the heat aligns perfectly. (0/3)", UDim2.new(1, 0, 0, 20), Enum.Font.GothamMedium, UIHelpers.Colors.TextWhite, 14)
	mgInst.Position = UDim2.new(0, 0, 0, 60)

	local BarContainer, bcStroke = CreateGrimPanel(MinigameView)
	BarContainer.Size = UDim2.new(0.8, 0, 0, 40)
	BarContainer.Position = UDim2.new(0.5, 0, 0.4, 0)
	BarContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	BarContainer.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	bcStroke.Color = UIHelpers.Colors.BorderMuted; bcStroke.Thickness = 2

	local SweetSpot = Instance.new("Frame", BarContainer)
	SweetSpot.Size = UDim2.new(0.25, 0, 1, 0) 
	SweetSpot.Position = UDim2.new(0.375, 0, 0, 0)
	SweetSpot.BackgroundColor3 = Color3.fromRGB(85, 255, 85)
	SweetSpot.BorderSizePixel = 0

	local Cursor = Instance.new("Frame", BarContainer)
	Cursor.Size = UDim2.new(0.02, 0, 1.4, 0)
	Cursor.Position = UDim2.new(0, 0, 0.5, 0)
	Cursor.AnchorPoint = Vector2.new(0.5, 0.5)
	Cursor.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	Cursor.BorderSizePixel = 0

	local StrikeBtn, StrikeStroke = CreateSharpButton(MinigameView, "STRIKE", UDim2.new(0.5, 0, 0, 60), Enum.Font.GothamBlack, 22)
	StrikeBtn.Position = UDim2.new(0.5, 0, 0.8, 0)
	StrikeBtn.AnchorPoint = Vector2.new(0.5, 0.5)
	StrikeBtn.TextColor3 = Color3.fromRGB(255, 85, 85)
	StrikeStroke.Color = Color3.fromRGB(255, 85, 85)

	local mgActive = false
	local mgConn = nil
	local strikes = 0
	local totalAccuracy = 0
	local currentTargetCenter = 0.5

	local function ResetSweetSpot()
		local w = 0.25 
		local p = math.random(10, 65) / 100 
		SweetSpot.Position = UDim2.new(p, 0, 0, 0)
		currentTargetCenter = p + (w / 2)
		SweetSpot.BackgroundColor3 = Color3.fromRGB(85, 255, 85)
	end

	local function EndMinigame()
		mgActive = false
		if mgConn then mgConn:Disconnect() mgConn = nil end

		local finalQuality = "Standard"
		local avg = totalAccuracy / 3
		if avg >= 0.80 then finalQuality = "Flawless"
		elseif avg >= 0.40 then finalQuality = "Masterwork" end

		mgInst.Text = "Forge Complete! Quality: <font color='#FFD700'>" .. string.upper(finalQuality) .. "</font>"
		task.wait(1.5)
		MinigameView.Visible = false
		InfoView.Visible = true

		if selectedRecipeName then
			Network:WaitForChild("ForgeItem"):FireServer(selectedRecipeName, finalQuality)
		end
	end

	StrikeBtn.MouseButton1Click:Connect(function()
		if not mgActive then return end
		local cursorPos = Cursor.Position.X.Scale
		local dist = math.abs(cursorPos - currentTargetCenter)
		local accuracy = 0

		if dist <= 0.125 then
			accuracy = 1 - (dist / 0.125) 
			SweetSpot.BackgroundColor3 = Color3.fromRGB(255, 215, 0) 
		else
			accuracy = 0
			SweetSpot.BackgroundColor3 = Color3.fromRGB(255, 85, 85) 
		end

		totalAccuracy += accuracy
		strikes += 1
		mgInst.Text = "Strike when the heat aligns perfectly. (" .. strikes .. "/3)"

		if strikes >= 3 then
			EndMinigame()
		else
			mgActive = false
			task.wait(0.4)
			ResetSweetSpot()
			mgActive = true
		end
	end)

	CraftBtn.MouseButton1Click:Connect(function()
		if not selectedRecipeName then return end
		local recipe = ItemData.ForgeRecipes[selectedRecipeName]
		if not recipe then return end

		local dews = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Dews") and player.leaderstats.Dews.Value or 0
		if dews < recipe.DewCost then
			NotificationManager.Show("Not enough Dews to forge this!", "Error")
			return
		end

		local hasMats = true
		for req, amt in pairs(recipe.ReqItems) do
			local count = player:GetAttribute(req:gsub("[^%w]", "") .. "Count") or 0
			if count < amt then hasMats = false; break end
		end

		if not hasMats then
			NotificationManager.Show("Missing required materials!", "Error")
			return
		end

		InfoView.Visible = false
		MinigameView.Visible = true
		strikes = 0
		totalAccuracy = 0
		mgInst.Text = "Strike when the heat aligns perfectly. (0/3)"
		ResetSweetSpot()
		mgActive = true

		local t = 0
		if mgConn then mgConn:Disconnect() end
		mgConn = RunService.RenderStepped:Connect(function(dt)
			if mgActive then
				local speed = 1.8 + (strikes * 0.6) 
				t += dt * speed
				local pos = (math.sin(t) + 1) / 2
				Cursor.Position = UDim2.new(pos, 0, 0.5, 0)
			end
		end)
	end)

	for rec, recipeData in pairs(ItemData.ForgeRecipes or {}) do
		if rec == "Fritz Clan Serum" or rec == "Ancestral Awakening Serum" or string.find(rec, "Itemized Abyssal") then continue end

		local resItem = recipeData.Result
		local resData = ItemData.Equipment[resItem] or ItemData.Consumables[resItem]
		local rarity = resData and resData.Rarity or "Common"
		local rColor = CONFIG.RarityColors[rarity] or Color3.fromRGB(200,200,200)

		local rBtn = Instance.new("TextButton", RecipeList)
		rBtn.Size = UDim2.new(1, -10, 0, 55)
		rBtn.BackgroundTransparency = 1
		rBtn.AutoButtonColor = false
		rBtn.Text = ""

		local rStrk = Instance.new("UIStroke", rBtn)
		rStrk.Color = rColor
		rStrk.Thickness = 2
		rStrk.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

		local bgGlow = Instance.new("Frame", rBtn)
		bgGlow.Size = UDim2.new(1, 0, 1, 0)
		bgGlow.BackgroundColor3 = rColor
		bgGlow.BorderSizePixel = 0
		bgGlow.ZIndex = 1
		local grad = Instance.new("UIGradient", bgGlow); grad.Rotation = 90; grad.Transparency = NumberSequence.new{ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.95), NumberSequenceKeypoint.new(1, 0.8) }

		local rTitleLbl = UIHelpers.CreateLabel(rBtn, string.upper(rec), UDim2.new(1, -15, 0, 20), Enum.Font.GothamBlack, rColor, 13)
		rTitleLbl.Position = UDim2.new(0, 10, 0, 8)
		rTitleLbl.TextXAlignment = Enum.TextXAlignment.Left; rTitleLbl.ZIndex = 2

		local rTagLbl = UIHelpers.CreateLabel(rBtn, "[" .. string.upper(rarity) .. "]", UDim2.new(1, -15, 0, 15), Enum.Font.GothamBold, Color3.fromRGB(200, 200, 200), 10)
		rTagLbl.Position = UDim2.new(0, 10, 1, -22)
		rTagLbl.TextXAlignment = Enum.TextXAlignment.Left; rTagLbl.ZIndex = 2

		rBtn.MouseEnter:Connect(function() rTitleLbl.TextColor3 = UIHelpers.Colors.Gold; rTagLbl.TextColor3 = UIHelpers.Colors.Gold; rStrk.Color = UIHelpers.Colors.Gold end)
		rBtn.MouseLeave:Connect(function() rTitleLbl.TextColor3 = rColor; rTagLbl.TextColor3 = Color3.fromRGB(200, 200, 200); rStrk.Color = rColor end)

		rBtn.MouseButton1Click:Connect(function()
			selectedRecipeName = rec 
			bpTitle.Text = string.upper(rec)
			bpTitle.TextColor3 = rColor
			bpDesc.Text = "<font color='" .. ColorToHex(rColor) .. "'>[" .. rarity:upper() .. "]</font> " .. (resData and resData.Desc or "A high-tier piece of equipment forged from rare materials.")
			bpDesc.RichText = true
			ReqTitle.Visible = true
			CraftBtn.Visible = true
			CraftStroke.Color = rColor
			CraftBtn.TextColor3 = rColor

			for _, c in ipairs(ReqList:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end

			local function MakeReq(matName, amt, hasAmt)
				local rf = Instance.new("Frame", ReqList)
				rf.Size = UDim2.new(1, 0, 0, 25)
				rf.BackgroundTransparency = 1
				rf.ZIndex = 103

				local reqBg = Instance.new("Frame", rf)
				reqBg.Size = UDim2.new(1, 0, 1, 0)
				reqBg.BackgroundColor3 = hasAmt and UIHelpers.Colors.BorderMuted or Color3.fromRGB(150, 40, 40)
				reqBg.BackgroundTransparency = hasAmt and 0.5 or 0 
				reqBg.BorderSizePixel = 0
				local rGrad = Instance.new("UIGradient", reqBg); rGrad.Rotation = 90; rGrad.Transparency = NumberSequence.new{ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.95), NumberSequenceKeypoint.new(1, 0.7) }

				local l = UIHelpers.CreateLabel(rf, amt .. "x " .. matName, UDim2.new(1, -10, 1, 0), Enum.Font.GothamBold, hasAmt and UIHelpers.Colors.TextWhite or Color3.fromRGB(255, 100, 100), 11)
				l.Position = UDim2.new(0, 10, 0, 0); l.TextXAlignment = Enum.TextXAlignment.Left; l.ZIndex = 104
			end

			local hasAllMats = true
			if ItemData.ForgeRecipes[rec] then
				for mat, amt in pairs(ItemData.ForgeRecipes[rec].ReqItems) do 
					local count = tonumber(player:GetAttribute(mat:gsub("[^%w]", "") .. "Count")) or 0
					local hasEnough = count >= amt; if not hasEnough then hasAllMats = false end
					MakeReq(mat, amt, hasEnough) 
				end

				local dCount = tonumber(player:GetAttribute("Dews")) or 0
				local hasDews = dCount >= ItemData.ForgeRecipes[rec].DewCost; if not hasDews then hasAllMats = false end
				MakeReq("Dews", ItemData.ForgeRecipes[rec].DewCost, hasDews)
			end

			if hasAllMats then
				CraftBtn.Active = true; CraftBtn.Text = "START FORGE"; CraftBtn.TextColor3 = rColor; CraftStroke.Color = rColor
			else
				CraftBtn.Active = false; CraftBtn.Text = "INSUFFICIENT MATERIALS"; CraftBtn.TextColor3 = Color3.fromRGB(100, 100, 100); CraftStroke.Color = Color3.fromRGB(50, 50, 60)
			end
		end)
	end

	LayoutRefs.ForgeLayout = ftLayout
	LayoutRefs.ForgeLeft = RecipeList
	LayoutRefs.ForgeRight = BlueprintPanel

	-- ==========================================
	-- 2.5 BLOODLINE RITUAL
	-- ==========================================
	local RitualTab = activeSubFrames["BLOODLINE RITUAL"]
	local selectedRitualName = nil 

	local rtSplitContainer = Instance.new("Frame", RitualTab)
	rtSplitContainer.Size = UDim2.new(1, 0, 1, 0)
	rtSplitContainer.BackgroundTransparency = 1
	local rtLayout = Instance.new("UIListLayout", rtSplitContainer)
	rtLayout.FillDirection = Enum.FillDirection.Horizontal
	rtLayout.Padding = UDim.new(0, 15)

	local RitualList = Instance.new("ScrollingFrame", rtSplitContainer)
	RitualList.Size = UDim2.new(0.28, 0, 1, 0)
	RitualList.BackgroundTransparency = 1
	RitualList.ScrollBarThickness = 4
	RitualList.BorderSizePixel = 0

	local rillLayout = Instance.new("UIListLayout", RitualList)
	rillLayout.Padding = UDim.new(0, 10)
	rillLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() RitualList.CanvasSize = UDim2.new(0, 0, 0, rillLayout.AbsoluteContentSize.Y + 20) end)

	local RitualPanel = Instance.new("Frame", rtSplitContainer)
	RitualPanel.Size = UDim2.new(0.7, 0, 1, 0)
	RitualPanel.BackgroundTransparency = 1 

	local rBg = Instance.new("ImageLabel", RitualPanel)
	rBg.Size = UDim2.new(1.2, 0, 1.2, 0)
	rBg.Position = UDim2.new(0.5, 0, 0.5, 0)
	rBg.AnchorPoint = Vector2.new(0.5, 0.5)
	rBg.BackgroundTransparency = 1
	rBg.Image = "rbxassetid://13112895696" 
	rBg.ImageColor3 = Color3.fromRGB(100, 150, 255)
	rBg.ImageTransparency = 0.8
	rBg.ZIndex = 0
	local rotTween = TweenService:Create(rBg, TweenInfo.new(60, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {Rotation = 360})
	rotTween:Play()

	local RInfoView = Instance.new("Frame", RitualPanel)
	RInfoView.Size = UDim2.new(1, 0, 1, 0)
	RInfoView.BackgroundTransparency = 1

	local rbpTitle = UIHelpers.CreateLabel(RInfoView, "AWAITING TRIBUTE", UDim2.new(1, 0, 0, 40), Enum.Font.GothamBlack, Color3.fromRGB(150, 200, 255), 28)
	rbpTitle.Position = UDim2.new(0, 0, 0, 40); rbpTitle.TextXAlignment = Enum.TextXAlignment.Center

	local rbpDesc = UIHelpers.CreateLabel(RInfoView, "Select a rite from the tomes to rewrite your lineage.", UDim2.new(1, -100, 0, 60), Enum.Font.GothamMedium, UIHelpers.Colors.TextWhite, 14)
	rbpDesc.Position = UDim2.new(0.5, 0, 0, 80); rbpDesc.AnchorPoint = Vector2.new(0.5, 0); rbpDesc.TextXAlignment = Enum.TextXAlignment.Center; rbpDesc.TextWrapped = true

	local RReqList = Instance.new("Frame", RInfoView)
	RReqList.Size = UDim2.new(1, 0, 0, 140)
	RReqList.Position = UDim2.new(0.5, 0, 0.4, 0)
	RReqList.AnchorPoint = Vector2.new(0.5, 0.5)
	RReqList.BackgroundTransparency = 1
	local rreqLayout = Instance.new("UIListLayout", RReqList)
	rreqLayout.FillDirection = Enum.FillDirection.Horizontal
	rreqLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rreqLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rreqLayout.Padding = UDim.new(0, 15)

	local RBuffList = Instance.new("Frame", RInfoView)
	RBuffList.Size = UDim2.new(1, -60, 0, 100)
	RBuffList.Position = UDim2.new(0.5, 0, 0.65, 0)
	RBuffList.AnchorPoint = Vector2.new(0.5, 0.5)
	RBuffList.BackgroundTransparency = 1
	local rbuffLayout = Instance.new("UIListLayout", RBuffList)
	rbuffLayout.FillDirection = Enum.FillDirection.Vertical
	rbuffLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rbuffLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rbuffLayout.Padding = UDim.new(0, 5)

	local RCraftBtn, RCraftStroke = CreateSharpButton(RInfoView, "COMMENCE RITUAL", UDim2.new(0.5, 0, 0, 50), Enum.Font.GothamBlack, 18)
	RCraftBtn.Position = UDim2.new(0.5, 0, 1, -40); RCraftBtn.AnchorPoint = Vector2.new(0.5, 1); RCraftBtn.Visible = false
	RCraftBtn.TextColor3 = Color3.fromRGB(150, 200, 255)
	RCraftStroke.Color = Color3.fromRGB(150, 200, 255)

	TweenService:Create(RCraftStroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Transparency = 0.5}):Play()

	local RMiniView = Instance.new("Frame", RitualPanel)
	RMiniView.Size = UDim2.new(1, 0, 1, 0)
	RMiniView.BackgroundTransparency = 1
	RMiniView.Visible = false

	local rChannelLbl = UIHelpers.CreateLabel(RMiniView, "SYNCHRONIZING WITH THE COORDINATE...", UDim2.new(1, 0, 0, 40), Enum.Font.GothamBlack, Color3.fromRGB(150, 200, 255), 20)
	rChannelLbl.Position = UDim2.new(0, 0, 0, 150)

	local rBarContainer, rBcStroke = CreateGrimPanel(RMiniView)
	rBarContainer.Size = UDim2.new(0.8, 0, 0, 20)
	rBarContainer.Position = UDim2.new(0.5, 0, 0, 220)
	rBarContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	rBarContainer.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
	rBcStroke.Color = Color3.fromRGB(50, 50, 70); rBcStroke.Thickness = 2

	local rProgressFill = Instance.new("Frame", rBarContainer)
	rProgressFill.Size = UDim2.new(0, 0, 1, 0)
	rProgressFill.BackgroundColor3 = Color3.fromRGB(150, 200, 255)
	rProgressFill.BorderSizePixel = 0

	RCraftBtn.MouseButton1Click:Connect(function()
		if not selectedRitualName then return end
		local recipe = ItemData.ForgeRecipes[selectedRitualName]
		if not recipe then return end

		local dews = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Dews") and player.leaderstats.Dews.Value or 0
		if dews < recipe.DewCost then
			NotificationManager.Show("Not enough Dews for this Ritual!", "Error")
			return
		end

		local hasMats = true
		for req, amt in pairs(recipe.ReqItems) do
			local count = player:GetAttribute(req:gsub("[^%w]", "") .. "Count") or 0
			if count < amt then hasMats = false; break end
		end

		if recipe.SpecialType == "AbyssalClanRequirement" then
			local abyssalFound = 0
			local abyssalClans = {
				"ItemizedAbyssalYeagerCount", "ItemizedAbyssalTyburCount", "ItemizedAbyssalAckermanCount", 
				"ItemizedAbyssalGalliardCount", "ItemizedAbyssalBraunCount", "ItemizedAbyssalReissCount"
			}

			for _, attr in ipairs(abyssalClans) do
				local count = player:GetAttribute(attr) or 0
				if count > 0 then
					abyssalFound += count
				end
			end

			if abyssalFound < (recipe.AbyssalClanCount or 2) then hasMats = false end
		end

		if not hasMats then
			NotificationManager.Show("Missing required sacrifices!", "Error")
			return
		end

		RInfoView.Visible = false
		RMiniView.Visible = true
		rChannelLbl.Text = "SYNCHRONIZING WITH THE COORDINATE..."
		rProgressFill.Size = UDim2.new(0, 0, 1, 0)

		if VFXManager and type(VFXManager.PlaySFX) == "function" then VFXManager.PlaySFX("Steam", 0.5) end

		local t = TweenService:Create(rProgressFill, TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Size = UDim2.new(1, 0, 1, 0)})
		t:Play()

		task.delay(1.5, function() if RMiniView.Visible then rChannelLbl.Text = "REWRITING LINEAGE..." end end)

		t.Completed:Connect(function()
			rChannelLbl.Text = "RITUAL COMPLETE."
			task.wait(1)
			RMiniView.Visible = false
			RInfoView.Visible = true
			if selectedRitualName then
				Network:WaitForChild("ForgeItem"):FireServer(selectedRitualName, "Standard")
			end
		end)
	end)

	for rec, recipeData in pairs(ItemData.ForgeRecipes or {}) do
		if rec ~= "Fritz Clan Serum" and rec ~= "Ancestral Awakening Serum" and not string.find(rec, "Itemized Abyssal") then continue end

		local resItem = recipeData.Result
		local resData = ItemData.Equipment[resItem] or ItemData.Consumables[resItem]
		local rarity = resData and resData.Rarity or "Mythical"
		local rColor = CONFIG.RarityColors[rarity] or Color3.fromRGB(200,200,200)

		local rBtn = Instance.new("TextButton", RitualList)
		rBtn.Size = UDim2.new(1, -10, 0, 65)
		rBtn.BackgroundTransparency = 1
		rBtn.AutoButtonColor = false
		rBtn.Text = ""

		local rStrk = Instance.new("UIStroke", rBtn)
		rStrk.Color = rColor
		rStrk.Thickness = 2
		rStrk.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

		local bgGlow = Instance.new("Frame", rBtn)
		bgGlow.Size = UDim2.new(1, 0, 1, 0)
		bgGlow.BackgroundColor3 = rColor
		bgGlow.BorderSizePixel = 0
		bgGlow.ZIndex = 1
		local grad = Instance.new("UIGradient", bgGlow); grad.Rotation = 90; grad.Transparency = NumberSequence.new{ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.95), NumberSequenceKeypoint.new(1, 0.8) }

		local rTitleLbl = UIHelpers.CreateLabel(rBtn, string.upper(rec), UDim2.new(1, -15, 0, 20), Enum.Font.GothamBlack, rColor, 13)
		rTitleLbl.Position = UDim2.new(0, 10, 0, 12)
		rTitleLbl.TextXAlignment = Enum.TextXAlignment.Left; rTitleLbl.ZIndex = 2

		local rTagLbl = UIHelpers.CreateLabel(rBtn, "[ FORBIDDEN RITE ]", UDim2.new(1, -15, 0, 15), Enum.Font.GothamBold, Color3.fromRGB(200, 200, 200), 10)
		rTagLbl.Position = UDim2.new(0, 10, 1, -26)
		rTagLbl.TextXAlignment = Enum.TextXAlignment.Left; rTagLbl.ZIndex = 2

		rBtn.MouseEnter:Connect(function() rTitleLbl.TextColor3 = UIHelpers.Colors.Gold; rTagLbl.TextColor3 = UIHelpers.Colors.Gold; rStrk.Color = UIHelpers.Colors.Gold end)
		rBtn.MouseLeave:Connect(function() rTitleLbl.TextColor3 = rColor; rTagLbl.TextColor3 = Color3.fromRGB(200, 200, 200); rStrk.Color = rColor end)

		rBtn.MouseButton1Click:Connect(function()
			selectedRitualName = rec 
			rbpTitle.Text = string.upper(rec)
			rbpTitle.TextColor3 = rColor
			rbpDesc.Text = "<font color='" .. ColorToHex(rColor) .. "'>[" .. rarity:upper() .. "]</font> " .. (resData and resData.Desc or "A forbidden rite.")
			rbpDesc.RichText = true
			RCraftBtn.Visible = true
			RCraftStroke.Color = rColor
			RCraftBtn.TextColor3 = rColor
			rBg.ImageColor3 = rColor

			for _, c in ipairs(RReqList:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
			for _, c in ipairs(RBuffList:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end

			local function MakeReq(matName, amt, hasAmt)
				local rf, rfStrk = CreateGrimPanel(RReqList)
				rf.Size = UDim2.new(0, 110, 0, 140)
				rf.ZIndex = 103

				local color = hasAmt and Color3.fromRGB(150, 200, 255) or Color3.fromRGB(150, 40, 40)
				rfStrk.Color = color

				local glow = Instance.new("Frame", rf)
				glow.Size = UDim2.new(1,0,1,0)
				glow.BackgroundColor3 = color
				glow.BackgroundTransparency = hasAmt and 0.8 or 0.95
				glow.BorderSizePixel = 0
				glow.ZIndex = 102

				local countLbl = UIHelpers.CreateLabel(rf, amt .. "x", UDim2.new(1,0,0,30), Enum.Font.GothamBlack, color, 20)
				countLbl.Position = UDim2.new(0,0,0,10)
				countLbl.ZIndex = 104

				local nameLbl = UIHelpers.CreateLabel(rf, matName:upper(), UDim2.new(1,-10,0,60), Enum.Font.GothamBold, UIHelpers.Colors.TextWhite, 12)
				nameLbl.Position = UDim2.new(0,5,0,50)
				nameLbl.TextWrapped = true
				nameLbl.ZIndex = 104

				local statusLbl = UIHelpers.CreateLabel(rf, hasAmt and "FULFILLED" or "MISSING", UDim2.new(1,0,0,20), Enum.Font.GothamBlack, color, 10)
				statusLbl.Position = UDim2.new(0,0,1,-25)
				statusLbl.ZIndex = 104
			end

			local hasAllMats = true
			if ItemData.ForgeRecipes[rec] then
				for mat, amt in pairs(ItemData.ForgeRecipes[rec].ReqItems) do 
					local count = tonumber(player:GetAttribute(mat:gsub("[^%w]", "") .. "Count")) or 0
					local hasEnough = count >= amt; if not hasEnough then hasAllMats = false end
					MakeReq(mat, amt, hasEnough) 
				end

				if ItemData.ForgeRecipes[rec].SpecialType == "AbyssalClanRequirement" then
					local requiredCount = ItemData.ForgeRecipes[rec].AbyssalClanCount or 2
					local abyssalFound = 0
					local abyssalClans = {
						"ItemizedAbyssalYeagerCount", "ItemizedAbyssalTyburCount", "ItemizedAbyssalAckermanCount", 
						"ItemizedAbyssalGalliardCount", "ItemizedAbyssalBraunCount", "ItemizedAbyssalReissCount"
					}

					for _, attr in ipairs(abyssalClans) do
						local count = player:GetAttribute(attr) or 0
						if count > 0 then
							abyssalFound += count
						end
					end

					local hasEnough = abyssalFound >= requiredCount
					if not hasEnough then hasAllMats = false end
					MakeReq("Any Abyssal Lineage", requiredCount, hasEnough)
				end

				local dCount = tonumber(player:GetAttribute("Dews")) or 0
				local hasDews = dCount >= ItemData.ForgeRecipes[rec].DewCost; if not hasDews then hasAllMats = false end
				MakeReq("Dews", ItemData.ForgeRecipes[rec].DewCost, hasDews)
			end

			local cKey = nil
			local isAbyssal = false
			if rec == "Fritz Clan Serum" then
				cKey = "Fritz"
				isAbyssal = true
			elseif string.find(rec, "Itemized Abyssal") then
				local baseClan = string.gsub(rec, "Itemized Abyssal ", "")
				cKey = baseClan
				isAbyssal = true
			end

			if cKey then
				local buffs = GetClanBuffStrings(cKey, isAbyssal)
				if #buffs > 0 then
					local bTitle = UIHelpers.CreateLabel(RBuffList, "RITUAL EMPOWERMENTS:", UDim2.new(1, 0, 0, 20), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 14)
					bTitle.LayoutOrder = 0
					for i, txt in ipairs(buffs) do
						local bLbl = UIHelpers.CreateLabel(RBuffList, "• " .. txt, UDim2.new(1, 0, 0, 18), Enum.Font.GothamBold, Color3.fromRGB(200, 220, 255), 12)
						bLbl.LayoutOrder = i
					end
				end
			end

			if hasAllMats then
				RCraftBtn.Active = true; RCraftBtn.Text = "COMMENCE RITUAL"; RCraftBtn.TextColor3 = rColor; RCraftStroke.Color = rColor
			else
				RCraftBtn.Active = false; RCraftBtn.Text = "INSUFFICIENT SACRIFICES"; RCraftBtn.TextColor3 = Color3.fromRGB(100, 100, 100); RCraftStroke.Color = Color3.fromRGB(50, 50, 60)
			end
		end)
	end

	LayoutRefs.RitualLayout = rtLayout
	LayoutRefs.RitualLeft = RitualList
	LayoutRefs.RitualRight = RitualPanel

	-- ==========================================
	-- 3. TITAN FUSION
	-- ==========================================
	local FusionTab = activeSubFrames["TITAN FUSION"]

	local fSplitContainer = Instance.new("Frame", FusionTab)
	fSplitContainer.Size = UDim2.new(1, 0, 1, 0)
	fSplitContainer.BackgroundTransparency = 1
	local fscLayout = Instance.new("UIListLayout", fSplitContainer)
	fscLayout.FillDirection = Enum.FillDirection.Horizontal
	fscLayout.Padding = UDim.new(0, 10)

	local fLeftPanel = Instance.new("Frame", fSplitContainer)
	fLeftPanel.Size = UDim2.new(0.55, 0, 1, 0)
	fLeftPanel.BackgroundTransparency = 1

	local fTitle = UIHelpers.CreateLabel(fLeftPanel, "TITAN HYBRIDIZATION", UDim2.new(1, 0, 0, 40), Enum.Font.GothamBlack, Color3.fromRGB(170, 85, 255), 26)
	fTitle.Position = UDim2.new(0, 0, 0, 10)
	fTitle.TextXAlignment = Enum.TextXAlignment.Left

	local fDesc = UIHelpers.CreateLabel(fLeftPanel, "Fuse two Pure Titans with Abyssal Blood to create a horrific Hybrid. This action is irreversible.", UDim2.new(1, -20, 0, 40), Enum.Font.GothamMedium, UIHelpers.Colors.TextMuted, 14)
	fDesc.Position = UDim2.new(0, 0, 0, 50)
	fDesc.TextXAlignment = Enum.TextXAlignment.Left
	fDesc.TextWrapped = true

	local SlotContainer = Instance.new("Frame", fLeftPanel)
	SlotContainer.Size = UDim2.new(1, 0, 0, 300)
	SlotContainer.Position = UDim2.new(0.5, 0, 0.5, -20)
	SlotContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	SlotContainer.BackgroundTransparency = 1

	local function CreateFusionSlot(pos, titleText, isResult)
		local f, fStroke = CreateGrimPanel(SlotContainer)
		f.Size = UDim2.new(0, 140, 0, 140)
		f.Position = pos
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		fStroke.Color = Color3.fromRGB(70, 70, 80)

		local t = UIHelpers.CreateLabel(f, titleText, UDim2.new(1, -10, 0, 30), Enum.Font.GothamBlack, UIHelpers.Colors.TextMuted, 12)
		t.Position = UDim2.new(0, 5, 0, 5)
		t.TextScaled = true
		local tCon = Instance.new("UITextSizeConstraint", t)
		tCon.MaxTextSize = 12
		tCon.MinTextSize = 8
		t.ZIndex = 2

		if isResult then
			local qLbl = UIHelpers.CreateLabel(f, "?", UDim2.new(1, 0, 1, -30), Enum.Font.GothamBlack, Color3.fromRGB(80, 70, 90), 50)
			qLbl.Position = UDim2.new(0, 0, 0, 30)
			qLbl.ZIndex = 2
			return f, t, qLbl, nil
		end

		local addBtn, addStroke = CreateSharpButton(f, "+", UDim2.new(0, 50, 0, 50), Enum.Font.GothamBlack, 24)
		addBtn.Position = UDim2.new(0.5, 0, 0.5, 10)
		addBtn.AnchorPoint = Vector2.new(0.5, 0.5)
		addBtn.ZIndex = 2

		local overBtn = Instance.new("TextButton", f)
		overBtn.Size = UDim2.new(1, 0, 1, 0)
		overBtn.BackgroundTransparency = 1
		overBtn.Text = ""
		overBtn.ZIndex = 10

		overBtn.MouseEnter:Connect(function()
			fStroke.Color = UIHelpers.Colors.Gold
			if addBtn.Visible then
				addStroke.Color = UIHelpers.Colors.Gold
				addBtn.TextColor3 = UIHelpers.Colors.Gold
			end
		end)

		overBtn.MouseLeave:Connect(function()
			if t.TextColor3 ~= UIHelpers.Colors.TextMuted then 
				fStroke.Color = t.TextColor3 
			else 
				fStroke.Color = Color3.fromRGB(70, 70, 80) 
			end
			if addBtn.Visible then
				addStroke.Color = Color3.fromRGB(70, 70, 80)
				addBtn.TextColor3 = Color3.fromRGB(245, 245, 245)
			end
		end)

		return f, t, addBtn, overBtn
	end

	local Slot1, Slot1Title, Slot1AddBtn, Slot1OverBtn = CreateFusionSlot(UDim2.new(0.25, 0, 0.3, 0), "SUBJECT ALPHA", false)
	local Slot2, Slot2Title, Slot2AddBtn, Slot2OverBtn = CreateFusionSlot(UDim2.new(0.75, 0, 0.3, 0), "SUBJECT OMEGA", false)
	local ResultSlot, ResultTitle, ResultLbl = CreateFusionSlot(UDim2.new(0.5, 0, 0.75, 0), "HYBRIDIZATION", true)

	local l1 = Instance.new("Frame", SlotContainer)
	l1.Size = UDim2.new(0, 120, 0, 4)
	l1.Position = UDim2.new(0.35, 0, 0.55, 0)
	l1.Rotation = 60
	l1.AnchorPoint = Vector2.new(0.5, 0.5)
	l1.BackgroundColor3 = Color3.fromRGB(50, 40, 60)
	l1.BorderSizePixel = 0

	local l2 = Instance.new("Frame", SlotContainer)
	l2.Size = UDim2.new(0, 120, 0, 4)
	l2.Position = UDim2.new(0.65, 0, 0.55, 0)
	l2.Rotation = -60
	l2.AnchorPoint = Vector2.new(0.5, 0.5)
	l2.BackgroundColor3 = Color3.fromRGB(50, 40, 60)
	l2.BorderSizePixel = 0

	local FuseBtn, FuseStroke = CreateSharpButton(fLeftPanel, "INITIATE FUSION (300,000 DEWS)", UDim2.new(0.85, 0, 0, 55), Enum.Font.GothamBlack, 16)
	FuseBtn.Position = UDim2.new(0.5, 0, 1, -10)
	FuseBtn.AnchorPoint = Vector2.new(0.5, 1)
	FuseBtn.TextColor3 = Color3.fromRGB(170, 85, 255)
	FuseStroke.Color = Color3.fromRGB(170, 85, 255)

	local fRightPanel, _ = CreateGrimPanel(fSplitContainer)
	fRightPanel.Size = UDim2.new(0.45, -10, 1, -20)
	fRightPanel.Position = UDim2.new(0, 0, 0, 10)

	local regTitle = UIHelpers.CreateLabel(fRightPanel, "FUSION REGISTRY", UDim2.new(1, 0, 0, 30), Enum.Font.GothamBlack, Color3.fromRGB(170, 85, 255), 18)
	regTitle.Position = UDim2.new(0, 0, 0, 10)

	local regScroll = Instance.new("ScrollingFrame", fRightPanel)
	regScroll.Size = UDim2.new(1, -20, 1, -50)
	regScroll.Position = UDim2.new(0, 10, 0, 40)
	regScroll.BackgroundTransparency = 1
	regScroll.ScrollBarThickness = 4
	regScroll.BorderSizePixel = 0

	local rsLayout = Instance.new("UIListLayout", regScroll)
	rsLayout.Padding = UDim.new(0, 10)
	rsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() regScroll.CanvasSize = UDim2.new(0,0,0, rsLayout.AbsoluteContentSize.Y + 10) end)

	local FusionRecipes = { 
		["Female Titan"] = { ["Founding Titan"] = "Founding Female Titan" }, 
		["Founding Titan"] = { ["Female Titan"] = "Founding Female Titan", ["Attack Titan"] = "Founding Attack Titan" }, 
		["Attack Titan"] = { ["Armored Titan"] = "Armored Attack Titan", ["War Hammer Titan"] = "War Hammer Attack Titan", ["Founding Titan"] = "Founding Attack Titan" }, 
		["Armored Titan"] = { ["Attack Titan"] = "Armored Attack Titan" }, 
		["War Hammer Titan"] = { ["Attack Titan"] = "War Hammer Attack Titan" }, 
		["Colossal Titan"] = { ["Jaw Titan"] = "Colossal Jaw Titan" }, 
		["Jaw Titan"] = { ["Colossal Titan"] = "Colossal Jaw Titan" } 
	}

	local addedFusions = {}
	for alpha, omegas in pairs(FusionRecipes) do
		for omega, res in pairs(omegas) do
			if not addedFusions[res] then
				addedFusions[res] = { Alpha = alpha, Omega = omega }

				local fCard, fStroke = CreateGrimPanel(regScroll)
				fCard.Size = UDim2.new(1, -10, 0, 120)
				fStroke.Color = Color3.fromRGB(170, 85, 255)

				local resLbl = UIHelpers.CreateLabel(fCard, string.upper(res), UDim2.new(1, -20, 0, 20), Enum.Font.GothamBlack, Color3.fromRGB(170, 85, 255), 14)
				resLbl.Position = UDim2.new(0, 10, 0, 10); resLbl.TextXAlignment = Enum.TextXAlignment.Left

				local reqLbl = UIHelpers.CreateLabel(fCard, "Recipe: " .. alpha .. " + " .. omega, UDim2.new(1, -20, 0, 15), Enum.Font.GothamBold, UIHelpers.Colors.TextWhite, 11)
				reqLbl.Position = UDim2.new(0, 10, 0, 30); reqLbl.TextXAlignment = Enum.TextXAlignment.Left

				local tData = type(TitanData) == "table" and TitanData.Titans and TitanData.Titans[res]
				if tData and tData.Stats then
					local s = tData.Stats
					local statStr = string.format("POW: %s | SPD: %s | HRD: %s | END: %s | PRE: %s | POT: %s", s.Power, s.Speed, s.Hardening, s.Endurance, s.Precision, s.Potential)
					local statLbl = UIHelpers.CreateLabel(fCard, statStr, UDim2.new(1, -20, 0, 15), Enum.Font.GothamBold, UIHelpers.Colors.Gold, 11)
					statLbl.Position = UDim2.new(0, 10, 0, 50); statLbl.TextXAlignment = Enum.TextXAlignment.Left
				end

				local uniqueSkills = {}
				if hasSkillData and type(SkillData) == "table" then
					local sPool = SkillData.Skills or SkillData
					for sName, sData in pairs(sPool) do
						if sData.Requirement and sData.Requirement ~= "AnyTitan" and sData.Requirement ~= "Transformed" and sData.Requirement ~= "Enemy" and sData.Requirement ~= "None" then
							if string.find(res, sData.Requirement) then table.insert(uniqueSkills, sName) end
						end
					end
				end
				local skillsStr = #uniqueSkills > 0 and table.concat(uniqueSkills, ", ") or "Unknown Abilities"

				local skLbl = UIHelpers.CreateLabel(fCard, "Inherits: " .. skillsStr, UDim2.new(1, -20, 0, 30), Enum.Font.GothamMedium, UIHelpers.Colors.TextMuted, 10)
				skLbl.Position = UDim2.new(0, 10, 0, 70); skLbl.TextXAlignment = Enum.TextXAlignment.Left; skLbl.TextWrapped = true; skLbl.TextYAlignment = Enum.TextYAlignment.Top
			end
		end
	end

	local PopupOverlay = Instance.new("Frame", MainFrame)
	PopupOverlay.Size = UDim2.new(1, 0, 1, 0)
	PopupOverlay.BackgroundColor3 = Color3.new(0,0,0)
	PopupOverlay.BackgroundTransparency = 0.6
	PopupOverlay.ZIndex = 50
	PopupOverlay.Visible = false
	PopupOverlay.Active = true

	local PopupPanel, _ = CreateGrimPanel(PopupOverlay)
	PopupPanel.Size = UDim2.new(0, 400, 0, 500)
	PopupPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
	PopupPanel.AnchorPoint = Vector2.new(0.5, 0.5)
	PopupPanel.ZIndex = 51

	local popTitle = UIHelpers.CreateLabel(PopupPanel, "SELECT A TITAN", UDim2.new(1, 0, 0, 50), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 20)
	popTitle.ZIndex = 52

	local closeBtn, _ = CreateSharpButton(PopupPanel, "X", UDim2.new(0, 40, 0, 40), Enum.Font.GothamBlack, 18)
	closeBtn.Position = UDim2.new(1, -10, 0, 10)
	closeBtn.AnchorPoint = Vector2.new(1, 0)
	closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
	closeBtn.ZIndex = 52
	closeBtn.MouseButton1Click:Connect(function() PopupOverlay.Visible = false end)

	local TitanScroll = Instance.new("ScrollingFrame", PopupPanel)
	TitanScroll.Size = UDim2.new(1, -20, 1, -70)
	TitanScroll.Position = UDim2.new(0, 10, 0, 60)
	TitanScroll.BackgroundTransparency = 1
	TitanScroll.ScrollBarThickness = 6
	TitanScroll.BorderSizePixel = 0
	TitanScroll.ZIndex = 52

	local tsLayout = Instance.new("UIListLayout", TitanScroll)
	tsLayout.Padding = UDim.new(0, 10)
	tsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() TitanScroll.CanvasSize = UDim2.new(0,0,0, tsLayout.AbsoluteContentSize.Y + 10) end)

	local noTitansLbl = UIHelpers.CreateLabel(PopupPanel, "No Titans found in Vault.", UDim2.new(1, 0, 0, 50), Enum.Font.GothamMedium, UIHelpers.Colors.TextMuted, 14)
	noTitansLbl.Position = UDim2.new(0, 0, 0.5, 0)
	noTitansLbl.AnchorPoint = Vector2.new(0, 0.5)
	noTitansLbl.ZIndex = 52

	local selectedAlpha = nil
	local selectedOmega = nil
	local activeSlotIndex = 1

	local function UpdateFusionUI()
		local function updateSlot(slotData, titleLbl, addBtn, strk, defaultTitle)
			if slotData then
				local tName = slotData.Name
				local tData = (type(TitanData) == "table" and TitanData.Titans) and TitanData.Titans[tName] or nil
				local rarity = tData and tData.Rarity or "Common"
				local rColor = CONFIG.RarityColors[rarity] or Color3.fromRGB(200,200,200)

				titleLbl.Text = string.upper(tName)
				titleLbl.TextColor3 = rColor
				addBtn.Visible = false
				strk.Color = rColor
			else
				titleLbl.Text = defaultTitle
				titleLbl.TextColor3 = UIHelpers.Colors.TextMuted
				addBtn.Visible = true
				strk.Color = Color3.fromRGB(70, 70, 80)
			end
		end

		updateSlot(selectedAlpha, Slot1Title, Slot1AddBtn, Slot1:FindFirstChild("UIStroke"), "SUBJECT ALPHA")
		updateSlot(selectedOmega, Slot2Title, Slot2AddBtn, Slot2:FindFirstChild("UIStroke"), "SUBJECT OMEGA")

		if selectedAlpha and selectedOmega then
			l1.BackgroundColor3 = Color3.fromRGB(170, 85, 255)
			l2.BackgroundColor3 = Color3.fromRGB(170, 85, 255)
			ResultLbl.TextColor3 = Color3.fromRGB(170, 85, 255)
			ResultSlot:FindFirstChild("UIStroke").Color = Color3.fromRGB(170, 85, 255)
		else
			l1.BackgroundColor3 = Color3.fromRGB(50, 40, 60)
			l2.BackgroundColor3 = Color3.fromRGB(50, 40, 60)
			ResultLbl.TextColor3 = Color3.fromRGB(80, 70, 90)
			ResultSlot:FindFirstChild("UIStroke").Color = Color3.fromRGB(70, 70, 80)
		end
	end

	local function OpenTitanSelection(slotId)
		activeSlotIndex = slotId
		PopupOverlay.Visible = true
		for _, c in ipairs(TitanScroll:GetChildren()) do if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end end

		local foundAny = false
		local titanSlots = {"Equipped", "1", "2", "3", "4", "5", "6"}

		for _, slotKey in ipairs(titanSlots) do
			local tName = (slotKey == "Equipped") and player:GetAttribute("Titan") or player:GetAttribute("Titan_Slot" .. slotKey)
			if tName and tName ~= "" and tName ~= "None" then
				if (activeSlotIndex == 1 and selectedOmega and selectedOmega.Slot == slotKey) or (activeSlotIndex == 2 and selectedAlpha and selectedAlpha.Slot == slotKey) then
					continue 
				end

				foundAny = true

				local rarityColor = Color3.fromRGB(200, 200, 200)
				if type(TitanData) == "table" and TitanData.Titans and TitanData.Titans[tName] then
					local tRarity = TitanData.Titans[tName].Rarity
					rarityColor = CONFIG.RarityColors[tRarity] or rarityColor
				end

				local labelText = (slotKey == "Equipped" and "EQUIPPED" or "SLOT " .. slotKey) .. ": " .. string.upper(tName)
				local tBtn, tBtnStroke = CreateSharpButton(TitanScroll, labelText, UDim2.new(1, -10, 0, 50), Enum.Font.GothamBlack, 14)
				tBtn.ZIndex = 53
				tBtn.TextColor3 = rarityColor
				tBtnStroke.Color = rarityColor

				tBtn.MouseButton1Click:Connect(function()
					if activeSlotIndex == 1 then
						selectedAlpha = {Slot = slotKey, Name = tName}
					else
						selectedOmega = {Slot = slotKey, Name = tName}
					end
					PopupOverlay.Visible = false
					UpdateFusionUI()
				end)
			end
		end

		noTitansLbl.Visible = not foundAny
	end

	Slot1OverBtn.MouseButton1Click:Connect(function() OpenTitanSelection(1) end)
	Slot2OverBtn.MouseButton1Click:Connect(function() OpenTitanSelection(2) end)

	FuseBtn.MouseButton1Click:Connect(function()
		if not selectedAlpha or not selectedOmega then
			NotificationManager.Show("Requires two Subjects to initiate Fusion.", "Error")
			return
		end

		Network:WaitForChild("FuseTitan"):FireServer(selectedAlpha.Slot, selectedOmega.Slot)

		selectedAlpha = nil
		selectedOmega = nil
		UpdateFusionUI()
	end)

	local FusionComplete = Network:FindFirstChild("FusionComplete")
	if FusionComplete then
		FusionComplete.OnClientEvent:Connect(function(resultName)
			local tData = TitanData.Titans[resultName]
			if not tData then return end

			local cinGui = Instance.new("ScreenGui", player.PlayerGui)
			cinGui.Name = "FusionCinematicGui"
			cinGui.DisplayOrder = 1000
			cinGui.IgnoreGuiInset = true

			local bg = Instance.new("Frame", cinGui)
			bg.Size = UDim2.new(1, 0, 1, 0)
			bg.BackgroundColor3 = Color3.new(0, 0, 0)
			bg.BackgroundTransparency = 1

			TweenService:Create(bg, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.1}):Play()

			if VFXManager and type(VFXManager.PlaySFX) == "function" then VFXManager.PlaySFX("Steam", 0.5) end
			task.wait(1.5)

			local mergingLbl = UIHelpers.CreateLabel(bg, "FUSING BLOODLINES...", UDim2.new(1, 0, 1, 0), Enum.Font.Garamond, Color3.fromRGB(150, 0, 0), 36)
			mergingLbl.TextTransparency = 1

			local tIn = TweenService:Create(mergingLbl, TweenInfo.new(1.5, Enum.EasingStyle.Sine), {TextTransparency = 0})
			tIn:Play(); tIn.Completed:Wait()

			if VFXManager and type(VFXManager.PlaySFX) == "function" then VFXManager.PlaySFX("TitanRoar", 0.8) end
			task.wait(1)

			local tOut = TweenService:Create(mergingLbl, TweenInfo.new(1, Enum.EasingStyle.Sine), {TextTransparency = 1})
			tOut:Play(); tOut.Completed:Wait()

			local flash = Instance.new("Frame", cinGui)
			flash.Size = UDim2.new(1, 0, 1, 0)
			flash.BackgroundColor3 = Color3.fromRGB(150, 10, 10) 
			flash.ZIndex = 10
			mergingLbl:Destroy()

			if VFXManager and type(VFXManager.PlaySFX) == "function" then VFXManager.PlaySFX("HeavySlash", 0.6) end
			if VFXManager and type(VFXManager.ScreenShake) == "function" then VFXManager.ScreenShake(1.5, 0.5) end

			TweenService:Create(flash, TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1}):Play()

			local nameLbl = UIHelpers.CreateLabel(bg, string.upper(resultName), UDim2.new(1, 0, 0, 100), Enum.Font.Garamond, Color3.fromRGB(220, 220, 220), 64)
			nameLbl.Position = UDim2.new(0, 0, 0.25, 0)
			nameLbl.TextTransparency = 1
			local stroke = Instance.new("UIStroke", nameLbl)
			stroke.Color = Color3.fromRGB(100, 0, 0)
			stroke.Thickness = 2
			stroke.Transparency = 1

			TweenService:Create(nameLbl, TweenInfo.new(1.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {TextTransparency = 0, Position = UDim2.new(0, 0, 0.2, 0)}):Play()
			TweenService:Create(stroke, TweenInfo.new(1.5), {Transparency = 0}):Play()

			task.wait(1)

			local statsBox = Instance.new("Frame", bg)
			statsBox.Size = UDim2.new(0, 600, 0, 100)
			statsBox.Position = UDim2.new(0.5, 0, 0.45, 0)
			statsBox.AnchorPoint = Vector2.new(0.5, 0.5)
			statsBox.BackgroundTransparency = 1
			local sLayout = Instance.new("UIListLayout", statsBox)
			sLayout.FillDirection = Enum.FillDirection.Horizontal; sLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; sLayout.Padding = UDim.new(0, 15)

			local statsArray = {
				{Name = "POW", Val = tData.Stats.Power}, {Name = "SPD", Val = tData.Stats.Speed},
				{Name = "HRD", Val = tData.Stats.Hardening}, {Name = "END", Val = tData.Stats.Endurance},
				{Name = "PRE", Val = tData.Stats.Precision}, {Name = "POT", Val = tData.Stats.Potential},
			}

			for i, s in ipairs(statsArray) do
				local sFrame = Instance.new("Frame", statsBox)
				sFrame.Size = UDim2.new(0, 80, 0, 80)
				sFrame.BackgroundColor3 = Color3.fromRGB(15, 10, 10)
				sFrame.BackgroundTransparency = 1

				local sfStrk = Instance.new("UIStroke", sFrame); sfStrk.Color = Color3.fromRGB(100, 30, 30); sfStrk.Thickness = 2; sfStrk.Transparency = 1

				local sName = UIHelpers.CreateLabel(sFrame, s.Name, UDim2.new(1, 0, 0, 30), Enum.Font.GothamBlack, Color3.fromRGB(150, 100, 100), 14)
				sName.Position = UDim2.new(0, 0, 0, 5); sName.TextTransparency = 1

				local sVal = UIHelpers.CreateLabel(sFrame, s.Val, UDim2.new(1, 0, 0, 40), Enum.Font.Garamond, Color3.fromRGB(220, 200, 200), 36)
				sVal.Position = UDim2.new(0, 0, 0, 35); sVal.TextTransparency = 1

				TweenService:Create(sFrame, TweenInfo.new(0.3), {BackgroundTransparency = 0.2}):Play()
				TweenService:Create(sfStrk, TweenInfo.new(0.3), {Transparency = 0}):Play()
				TweenService:Create(sName, TweenInfo.new(0.3), {TextTransparency = 0}):Play()
				TweenService:Create(sVal, TweenInfo.new(0.3), {TextTransparency = 0}):Play()

				if VFXManager and type(VFXManager.PlaySFX) == "function" then VFXManager.PlaySFX("Click", 1.5 - (i * 0.1)) end
				task.wait(0.15)
			end

			task.wait(0.5)

			local uniqueSkills = {}
			if hasSkillData and type(SkillData) == "table" then
				local sPool = SkillData.Skills or SkillData
				for sName, sData in pairs(sPool) do
					if sData.Requirement and sData.Requirement ~= "AnyTitan" and sData.Requirement ~= "Transformed" and sData.Requirement ~= "Enemy" then
						if string.find(resultName, sData.Requirement) then table.insert(uniqueSkills, sName) end
					end
				end
			end

			if #uniqueSkills > 0 then
				local skTitle = UIHelpers.CreateLabel(bg, "INHERITED ABILITIES:", UDim2.new(1, 0, 0, 30), Enum.Font.Garamond, Color3.fromRGB(150, 150, 150), 20)
				skTitle.Position = UDim2.new(0, 0, 0.6, 0)
				skTitle.TextTransparency = 1
				TweenService:Create(skTitle, TweenInfo.new(0.5), {TextTransparency = 0}):Play()

				local skBox = Instance.new("Frame", bg)
				skBox.Size = UDim2.new(0, 600, 0, 50); skBox.Position = UDim2.new(0.5, 0, 0.65, 0); skBox.AnchorPoint = Vector2.new(0.5, 0); skBox.BackgroundTransparency = 1
				local skLayout = Instance.new("UIListLayout", skBox); skLayout.FillDirection = Enum.FillDirection.Horizontal; skLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; skLayout.Padding = UDim.new(0, 15)

				for _, sk in ipairs(uniqueSkills) do
					local skLbl = UIHelpers.CreateLabel(skBox, "[" .. sk:upper() .. "]", UDim2.new(0, 0, 1, 0), Enum.Font.GothamBold, Color3.fromRGB(200, 200, 200), 14); skLbl.AutomaticSize = Enum.AutomaticSize.X
					skLbl.TextTransparency = 1
					TweenService:Create(skLbl, TweenInfo.new(0.5), {TextTransparency = 0}):Play()
					if VFXManager and type(VFXManager.PlaySFX) == "function" then VFXManager.PlaySFX("Reveal", 1.2) end
					task.wait(0.2)
				end
			end

			task.wait(1.5)

			local closeBtn = Instance.new("TextButton", bg); closeBtn.Size = UDim2.new(1, 0, 1, 0); closeBtn.BackgroundTransparency = 1; closeBtn.Text = ""
			local clickLbl = UIHelpers.CreateLabel(bg, "CLICK ANYWHERE TO CONCLUDE", UDim2.new(1, 0, 0, 30), Enum.Font.Garamond, Color3.fromRGB(100, 100, 100), 16)
			clickLbl.Position = UDim2.new(0, 0, 0.9, 0)
			clickLbl.TextTransparency = 1
			TweenService:Create(clickLbl, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {TextTransparency = 0.5}):Play()

			closeBtn.MouseButton1Click:Connect(function()
				local fadeOut = TweenService:Create(bg, TweenInfo.new(1), {BackgroundTransparency = 1})

				for _, c in ipairs(bg:GetDescendants()) do
					if c:IsA("TextLabel") then
						TweenService:Create(c, TweenInfo.new(1), {TextTransparency = 1}):Play()
					elseif c:IsA("ImageLabel") then
						TweenService:Create(c, TweenInfo.new(1), {ImageTransparency = 1}):Play()
					elseif c:IsA("Frame") then
						TweenService:Create(c, TweenInfo.new(1), {BackgroundTransparency = 1}):Play()
					elseif c:IsA("UIStroke") then
						TweenService:Create(c, TweenInfo.new(1), {Transparency = 1}):Play()
					end
				end

				fadeOut:Play(); fadeOut.Completed:Wait(); cinGui:Destroy()
			end)
		end)
	end

	LayoutRefs.FusionLayout = fscLayout
	LayoutRefs.FusionLeft = fLeftPanel
	LayoutRefs.FusionRight = fRightPanel

	-- ==========================================
	-- 4. PLAYER TRADE
	-- ==========================================
	local TradeTab = activeSubFrames["PLAYER TRADE"]

	local tTitle = UIHelpers.CreateLabel(TradeTab, "SECURE TRADING", UDim2.new(1, 0, 0, 30), Enum.Font.GothamBlack, Color3.fromRGB(85, 170, 255), 20)
	tTitle.Position = UDim2.new(0, 0, 0, 0)

	local tDesc = UIHelpers.CreateLabel(TradeTab, "Initiate a secure item exchange with another operative.", UDim2.new(1, 0, 0, 20), Enum.Font.GothamMedium, UIHelpers.Colors.TextMuted, 14)
	tDesc.Position = UDim2.new(0, 0, 0, 30)

	local tSplitContainer = Instance.new("Frame", TradeTab)
	tSplitContainer.Size = UDim2.new(1, 0, 1, -60)
	tSplitContainer.Position = UDim2.new(0, 0, 0, 60)
	tSplitContainer.BackgroundTransparency = 1

	local tscLayout = Instance.new("UIListLayout", tSplitContainer)
	tscLayout.FillDirection = Enum.FillDirection.Horizontal
	tscLayout.Padding = UDim.new(0, 20)

	-- LEFT: SEND REQUEST
	local tLeftPanel = Instance.new("Frame", tSplitContainer)
	tLeftPanel.Size = UDim2.new(0.48, 0, 1, 0)
	tLeftPanel.BackgroundTransparency = 1

	local SendContainer, _ = CreateGrimPanel(tLeftPanel)
	SendContainer.Size = UDim2.new(1, 0, 0, 200)

	local scTitle = UIHelpers.CreateLabel(SendContainer, "OUTGOING REQUEST", UDim2.new(1, 0, 0, 30), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 16)
	scTitle.Position = UDim2.new(0, 0, 0, 10)

	local pInput = Instance.new("TextBox", SendContainer)
	pInput.Size = UDim2.new(0.8, 0, 0, 40)
	pInput.Position = UDim2.new(0.5, 0, 0, 60)
	pInput.AnchorPoint = Vector2.new(0.5, 0)
	pInput.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
	pInput.TextColor3 = UIHelpers.Colors.TextWhite
	pInput.Font = Enum.Font.GothamMedium
	pInput.TextSize = 16
	pInput.PlaceholderText = "Target Username..."
	pInput.Text = ""
	Instance.new("UIStroke", pInput).Color = UIHelpers.Colors.BorderMuted

	local SendBtn, sendStroke = CreateSharpButton(SendContainer, "SEND REQUEST", UDim2.new(0.8, 0, 0, 45), Enum.Font.GothamBlack, 16)
	SendBtn.Position = UDim2.new(0.5, 0, 0, 120)
	SendBtn.AnchorPoint = Vector2.new(0.5, 0)
	SendBtn.TextColor3 = Color3.fromRGB(85, 170, 255)
	sendStroke.Color = Color3.fromRGB(85, 170, 255)

	SendBtn.MouseButton1Click:Connect(function()
		if pInput.Text ~= "" then
			Network:WaitForChild("TradeAction"):FireServer("SendRequest", pInput.Text)
			pInput.Text = ""
		end
	end)

	-- RIGHT: INCOMING REQUESTS
	local tRightPanel = Instance.new("Frame", tSplitContainer)
	tRightPanel.Size = UDim2.new(0.5, 0, 1, 0)
	tRightPanel.BackgroundTransparency = 1

	local IncContainer, _ = CreateGrimPanel(tRightPanel)
	IncContainer.Size = UDim2.new(1, 0, 1, -20)

	local incTitle = UIHelpers.CreateLabel(IncContainer, "INCOMING REQUESTS", UDim2.new(1, 0, 0, 30), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 16)
	incTitle.Position = UDim2.new(0, 0, 0, 10)

	local ReqScroll = Instance.new("ScrollingFrame", IncContainer)
	ReqScroll.Size = UDim2.new(1, -20, 1, -60)
	ReqScroll.Position = UDim2.new(0, 10, 0, 50)
	ReqScroll.BackgroundTransparency = 1
	ReqScroll.ScrollBarThickness = 6
	ReqScroll.BorderSizePixel = 0

	local reqLayout = Instance.new("UIListLayout", ReqScroll)
	reqLayout.Padding = UDim.new(0, 10)
	reqLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		ReqScroll.CanvasSize = UDim2.new(0, 0, 0, reqLayout.AbsoluteContentSize.Y + 10)
	end)

	local PendingTrades = {}
	local function UpdateTradeRequests()
		for _, c in ipairs(ReqScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
		for reqName, _ in pairs(PendingTrades) do
			local rCard, _ = CreateGrimPanel(ReqScroll)
			rCard.Size = UDim2.new(1, -10, 0, 60)

			local nameLbl = UIHelpers.CreateLabel(rCard, reqName, UDim2.new(0.5, 0, 1, 0), Enum.Font.GothamBold, UIHelpers.Colors.TextWhite, 16)
			nameLbl.Position = UDim2.new(0, 15, 0, 0); nameLbl.TextXAlignment = Enum.TextXAlignment.Left

			local accBtn, accStrk = CreateSharpButton(rCard, "ACCEPT", UDim2.new(0, 90, 0, 34), Enum.Font.GothamBlack, 12)
			accBtn.Position = UDim2.new(1, -65, 0.5, 0); accBtn.AnchorPoint = Vector2.new(1, 0.5)
			accBtn.TextColor3 = Color3.fromRGB(85, 255, 85); accStrk.Color = Color3.fromRGB(85, 255, 85)

			local decBtn, decStrk = CreateSharpButton(rCard, "X", UDim2.new(0, 34, 0, 34), Enum.Font.GothamBlack, 16)
			decBtn.Position = UDim2.new(1, -15, 0.5, 0); decBtn.AnchorPoint = Vector2.new(1, 0.5)
			decBtn.TextColor3 = Color3.fromRGB(255, 85, 85); decStrk.Color = Color3.fromRGB(255, 85, 85)

			accBtn.MouseButton1Click:Connect(function() Network:WaitForChild("TradeAction"):FireServer("AcceptRequest", reqName) end)
			decBtn.MouseButton1Click:Connect(function() PendingTrades[reqName] = nil; UpdateTradeRequests(); Network:WaitForChild("TradeAction"):FireServer("DeclineRequest", reqName) end)
		end
	end

	Network:WaitForChild("TradeUpdate").OnClientEvent:Connect(function(action, data)
		if action == "IncomingRequest" then
			PendingTrades[data.Sender] = true
			UpdateTradeRequests()
		elseif action == "CancelRequest" then
			PendingTrades[data.Sender] = nil
			UpdateTradeRequests()
		end
	end)

	LayoutRefs.TradeLayout = tscLayout
	LayoutRefs.TradeLeft = tLeftPanel
	LayoutRefs.TradeRight = tRightPanel

	camera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateLayoutForScreen)
	UpdateLayoutForScreen()
end

return SupplyForgeTab