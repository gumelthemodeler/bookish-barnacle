-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
-- Name: PathsShopUI
local PathsShopUI = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Network = ReplicatedStorage:WaitForChild("Network")
local SharedUI = player:WaitForChild("PlayerScripts"):WaitForChild("SharedUI")
local UIHelpers = require(SharedUI:WaitForChild("UIHelpers"))

-- Ethereal Colors
local C_VOID = Color3.fromRGB(10, 10, 15)
local C_GLOW = Color3.fromRGB(85, 255, 255)
local C_GOLD = Color3.fromRGB(252, 228, 141)
local C_MUTED = Color3.fromRGB(140, 150, 170)

PathsShopUI.IsOpen = false
PathsShopUI.ScreenGui = nil
PathsShopUI.Overlay = nil
PathsShopUI.MainContainer = nil
PathsShopUI.DustLbl = nil
PathsShopUI.Cards = {}

local function CreateSharpButton(parent, text, size, font, textSize, baseColor, glowColor)
	local btn = Instance.new("TextButton", parent)
	btn.Size = size; btn.BackgroundColor3 = Color3.fromRGB(20, 20, 25); btn.BorderSizePixel = 0
	btn.AutoButtonColor = false; btn.Font = font; btn.TextColor3 = baseColor or Color3.fromRGB(245, 245, 245)
	btn.TextSize = textSize; btn.Text = text
	local stroke = Instance.new("UIStroke", btn)
	stroke.Color = Color3.fromRGB(50, 50, 65); stroke.Thickness = 1; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	local gColor = glowColor or C_GLOW

	-- [[ THE FIX: Smooth Mobile Touch Interactions ]]
	btn.InputBegan:Connect(function(input) 
		if btn.Active and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then 
			TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(30, 30, 35)}):Play()
			TweenService:Create(stroke, TweenInfo.new(0.2), {Color = gColor}):Play()
		end
	end)
	btn.InputEnded:Connect(function(input) 
		if btn.Active and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then 
			TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(20, 20, 25)}):Play()
			TweenService:Create(stroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(50, 50, 65)}):Play()
		end
	end)
	return btn, stroke
end

local function AbbreviateNumber(n)
	local Suffixes = {"", "K", "M", "B"}
	if not n then return "0" end; n = tonumber(n) or 0
	if n < 1000 then return tostring(math.floor(n)) end
	local suffixIndex = math.floor(math.log10(n) / 3); local value = n / (10 ^ (suffixIndex * 3))
	local str = string.format("%.1f", value); str = str:gsub("%.0$", "")
	return str .. (Suffixes[suffixIndex + 1] or "")
end

function PathsShopUI.UpdateShop()
	if not PathsShopUI.ScreenGui or not PathsShopUI.ScreenGui.Enabled then return end
	local pDust = player:GetAttribute("PathDust") or 0
	local pXP = player:GetAttribute("XP") or 0
	local ls = player:FindFirstChild("leaderstats"); local pDews = ls and ls:FindFirstChild("Dews") and ls.Dews.Value or 0

	if PathsShopUI.DustLbl then
		PathsShopUI.DustLbl.Text = "PATH DUST: " .. pDust
	end

	for id, data in pairs(PathsShopUI.Cards) do
		if data.Type == "Rune" then
			local rDef = data.Def
			local currentLvl = player:GetAttribute("Rune_" .. id) or 0
			data.Title.Text = rDef.Name .. " <font color='#FFFFFF'>[LVL " .. currentLvl .. "]</font>"

			local dustCost = math.floor(rDef.BaseDust * (rDef.Mult ^ currentLvl))
			local dewsCost = math.floor(rDef.BaseDews * (rDef.Mult ^ currentLvl))
			local xpCost = math.floor(rDef.BaseXP * (rDef.Mult ^ currentLvl))

			data.CostLbl.Text = "Req: " .. dustCost .. " Dust | " .. AbbreviateNumber(dewsCost) .. " Dews | " .. AbbreviateNumber(xpCost) .. " XP"

			if pDust >= dustCost and pDews >= dewsCost and pXP >= xpCost then
				data.Btn.TextColor3 = Color3.fromHex(rDef.Color); data.Stroke.Color = Color3.fromHex(rDef.Color)
				data.CanAfford = true
			else
				data.Btn.TextColor3 = Color3.fromRGB(100, 100, 100); data.Stroke.Color = Color3.fromRGB(50, 50, 65)
				data.CanAfford = false
			end
		elseif data.Type == "Item" then
			local iDef = data.Def
			if pDust >= iDef.Cost then
				data.Btn.TextColor3 = Color3.fromHex(iDef.Color); data.Stroke.Color = Color3.fromHex(iDef.Color)
				data.CanAfford = true
			else
				data.Btn.TextColor3 = Color3.fromRGB(100, 100, 100); data.Stroke.Color = Color3.fromRGB(50, 50, 65)
				data.CanAfford = false
			end
		end
	end
end

function PathsShopUI.OpenShop()
	if PathsShopUI.ScreenGui and not PathsShopUI.IsOpen then
		PathsShopUI.IsOpen = true
		PathsShopUI.ScreenGui.Enabled = true
		PathsShopUI.ScreenGui.DisplayOrder = 5000 -- FIX: Forces Coordinate over all other UIs

		PathsShopUI.UpdateShop()

		local VFXManager = require(player:WaitForChild("PlayerScripts"):WaitForChild("VFXManager"))
		if VFXManager then VFXManager.PlaySFX("Reveal", 1) end

		PathsShopUI.Overlay.BackgroundTransparency = 1
		PathsShopUI.MainContainer.Position = UDim2.new(0.5, 0, 0.55, 0)
		PathsShopUI.MainContainer.GroupTransparency = 1

		TweenService:Create(PathsShopUI.Overlay, TweenInfo.new(0.6, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {BackgroundTransparency = 0.4}):Play()
		TweenService:Create(PathsShopUI.MainContainer, TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, 0, 0.5, 0), GroupTransparency = 0}):Play()
	end
end

function PathsShopUI.Initialize(masterScreenGui)
	local PlayerGui = masterScreenGui.Parent 

	local ScreenGui = Instance.new("ScreenGui", PlayerGui)
	ScreenGui.Name = "PathsShopGUI"
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ScreenGui.DisplayOrder = 5000 -- FIX: Ultimate Top Layer
	ScreenGui.Enabled = false
	PathsShopUI.ScreenGui = ScreenGui

	local Overlay = Instance.new("Frame", ScreenGui)
	Overlay.Size = UDim2.new(1, 0, 1, 0)
	Overlay.BackgroundColor3 = C_VOID
	Overlay.BackgroundTransparency = 1 
	Overlay.Active = true 
	PathsShopUI.Overlay = Overlay

	local MainContainer = Instance.new("CanvasGroup", Overlay)
	MainContainer.Size = UDim2.new(0.9, 0, 0.9, 0)
	MainContainer.Position = UDim2.new(0.5, 0, 0.55, 0)
	MainContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	MainContainer.BackgroundColor3 = C_VOID
	MainContainer.BorderSizePixel = 0
	MainContainer.GroupTransparency = 1 
	MainContainer.ZIndex = 5000
	PathsShopUI.MainContainer = MainContainer

	local sizeConstraint = Instance.new("UISizeConstraint", MainContainer)
	sizeConstraint.MaxSize = Vector2.new(850, 600)

	local mStroke = Instance.new("UIStroke", MainContainer)
	mStroke.Color = C_GLOW; mStroke.Thickness = 2; mStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	local Header = UIHelpers.CreateLabel(MainContainer, "THE COORDINATE", UDim2.new(1, 0, 0, 40), Enum.Font.GothamBlack, C_GLOW, 24)
	Header.Position = UDim2.new(0, 0, 0, 15)

	local SubHeader = UIHelpers.CreateLabel(MainContainer, "Your physical form has perished or retreated. Spend your gathered dust before your connection severs.", UDim2.new(0.9, 0, 0, 35), Enum.Font.GothamMedium, C_MUTED, 14)
	SubHeader.Position = UDim2.new(0.5, 0, 0, 50); SubHeader.AnchorPoint = Vector2.new(0.5, 0); SubHeader.TextWrapped = true; SubHeader.TextScaled = true
	local subTc = Instance.new("UITextSizeConstraint", SubHeader); subTc.MaxTextSize = 14; subTc.MinTextSize = 8

	local DustLbl = UIHelpers.CreateLabel(MainContainer, "PATH DUST: 0", UDim2.new(1, 0, 0, 30), Enum.Font.GothamBlack, C_GOLD, 20)
	DustLbl.Position = UDim2.new(0, 0, 0, 85)
	PathsShopUI.DustLbl = DustLbl

	local ShopScroll = Instance.new("ScrollingFrame", MainContainer)
	ShopScroll.Size = UDim2.new(0.95, 0, 1, -190)
	ShopScroll.Position = UDim2.new(0.5, 0, 0, 125)
	ShopScroll.AnchorPoint = Vector2.new(0.5, 0)
	ShopScroll.BackgroundTransparency = 1
	ShopScroll.ScrollBarThickness = 4
	ShopScroll.BorderSizePixel = 0

	local ssLayout = Instance.new("UIListLayout", ShopScroll)
	ssLayout.SortOrder = Enum.SortOrder.LayoutOrder
	ssLayout.Padding = UDim.new(0, 15)
	ssLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		ShopScroll.CanvasSize = UDim2.new(0, 0, 0, ssLayout.AbsoluteContentSize.Y + 20)
	end)

	local function CreateGridSection(titleStr, layoutOrder)
		local header = UIHelpers.CreateLabel(ShopScroll, titleStr, UDim2.new(1, 0, 0, 20), Enum.Font.GothamBlack, C_GLOW, 16)
		header.LayoutOrder = layoutOrder

		local gridBox = Instance.new("Frame", ShopScroll)
		gridBox.Size = UDim2.new(1, 0, 0, 0)
		gridBox.AutomaticSize = Enum.AutomaticSize.Y
		gridBox.BackgroundTransparency = 1
		gridBox.LayoutOrder = layoutOrder + 1

		local layout = Instance.new("UIGridLayout", gridBox)
		layout.CellSize = UDim2.new(0.48, 0, 0, 100)
		layout.CellPadding = UDim2.new(0.04, 0, 0, 10)

		return gridBox
	end

	local RunesGrid = CreateGridSection("- MEMORY RUNES -", 1)
	local RelicsGrid = CreateGridSection("- ANCIENT RELICS -", 3)

	local LeaveBtn, lStroke = CreateSharpButton(MainContainer, "SEVER CONNECTION (LEAVE)", UDim2.new(0.5, 0, 0, 40), Enum.Font.GothamBlack, 14, Color3.fromRGB(255, 100, 100), Color3.fromRGB(255, 50, 50))
	LeaveBtn.Position = UDim2.new(0.5, 0, 1, -15)
	LeaveBtn.AnchorPoint = Vector2.new(0.5, 1)
	LeaveBtn.BackgroundColor3 = Color3.fromRGB(40, 15, 15)

	local RuneDefs = {
		{ Id = "Vanguard", Name = "Rune of the Vanguard", Desc = "+0.2% Total Damage per level.", BaseDust = 5, BaseDews = 10000, BaseXP = 25000, Mult = 1.15, Color = "#FF5555" },
		{ Id = "Wall", Name = "Rune of the Wall", Desc = "+0.25% Damage Reduction per level.", BaseDust = 5, BaseDews = 10000, BaseXP = 25000, Mult = 1.15, Color = "#55AAFF" },
		{ Id = "Avarice", Name = "Rune of Avarice", Desc = "+0.1% Global Drop Rate per level.", BaseDust = 10, BaseDews = 25000, BaseXP = 50000, Mult = 1.20, Color = "#FFD700" },
		{ Id = "Titan", Name = "Rune of the Titan", Desc = "+25 Max Titan Heat per level.", BaseDust = 8, BaseDews = 15000, BaseXP = 30000, Mult = 1.15, Color = "#AA55FF" }
	}

	local ItemDefs = {
		{ Id = "Spinal Fluid Syringe", Name = "Spinal Fluid Syringe", Desc = "Premium Titan Gacha roll.", Cost = 25, Color = "#FF55FF" },
		{ Id = "Coordinate Shard", Name = "Coordinate Shard", Desc = "Extremely rare crafting material.", Cost = 50, Color = "#55FFFF" },
		{ Id = "Abyssal Blood", Name = "Abyssal Blood", Desc = "Required for Nightmare awakening.", Cost = 100, Color = "#FF3333" },
		{ Id = "Ymir's Clay Fragment", Name = "Ymir's Clay Fragment", Desc = "The ultimate primordial relic.", Cost = 200, Color = "#FCE48D" },
		{ Id = "Eldian Crown", Name = "Relic: Eldian Crown", Desc = "[EXCLUSIVE] +300 STR & DEF, +1000 RES.", Cost = 500, Color = "#FFD700" },
		{ Id = "Founder's Parasite", Name = "Founder's Parasite", Desc = "[MYTHIC] +2000 Max HP, +150 SPD & GAS.", Cost = 1000, Color = "#55FF55" }
	}

	local function BuildCard(parentGrid, def, isRune)
		local card = Instance.new("Frame", parentGrid)
		card.BackgroundColor3 = Color3.fromRGB(20, 20, 25); card.BorderSizePixel = 0
		local stroke = Instance.new("UIStroke", card); stroke.Color = Color3.fromHex(def.Color); stroke.Thickness = 1

		local title = UIHelpers.CreateLabel(card, def.Name, UDim2.new(0.65, 0, 0, 25), Enum.Font.GothamBlack, Color3.fromHex(def.Color), 14)
		title.Position = UDim2.new(0, 10, 0, 5); title.TextXAlignment = Enum.TextXAlignment.Left; title.TextScaled = true; title.RichText = true
		local tc = Instance.new("UITextSizeConstraint", title); tc.MaxTextSize = 14; tc.MinTextSize = 9

		local desc = UIHelpers.CreateLabel(card, def.Desc, UDim2.new(0.65, 0, 0, 35), Enum.Font.GothamMedium, C_MUTED, 11)
		desc.Position = UDim2.new(0, 10, 0, 30); desc.TextXAlignment = Enum.TextXAlignment.Left; desc.TextWrapped = true; desc.TextYAlignment = Enum.TextYAlignment.Top; desc.TextScaled = true; desc.RichText = true
		local dTc = Instance.new("UITextSizeConstraint", desc); dTc.MaxTextSize = 12; dTc.MinTextSize = 8

		local costLbl = UIHelpers.CreateLabel(card, "", UDim2.new(0.65, 0, 0, 18), Enum.Font.GothamBold, Color3.fromHex("#AAAAAA"), 11)
		costLbl.Position = UDim2.new(0, 10, 1, -22); costLbl.TextXAlignment = Enum.TextXAlignment.Left; costLbl.TextScaled = true; costLbl.TextWrapped = true; costLbl.RichText = true
		local costTc = Instance.new("UITextSizeConstraint", costLbl); costTc.MaxTextSize = 11; costTc.MinTextSize = 8

		local actionText = isRune and "UPGRADE" or "FORGE"
		local btn, bStroke = CreateSharpButton(card, actionText, UDim2.new(0.3, 0, 0, 35), Enum.Font.GothamBlack, 11, Color3.fromHex(def.Color), Color3.fromHex(def.Color))
		btn.Position = UDim2.new(1, -10, 0.5, 0); btn.AnchorPoint = Vector2.new(1, 0.5)

		return title, costLbl, btn, bStroke
	end

	for _, rDef in ipairs(RuneDefs) do
		local title, costLbl, btn, bStroke = BuildCard(RunesGrid, rDef, true)
		btn.Activated:Connect(function() 
			if PathsShopUI.Cards[rDef.Id] and not PathsShopUI.Cards[rDef.Id].CanAfford then
				local VFXManager = require(player:WaitForChild("PlayerScripts"):WaitForChild("VFXManager"))
				if VFXManager then VFXManager.PlaySFX("Error", 1) end
				return
			end
			Network:WaitForChild("UpgradeRune"):FireServer(rDef.Id) 
		end)
		PathsShopUI.Cards[rDef.Id] = { Type = "Rune", Title = title, CostLbl = costLbl, Btn = btn, Stroke = bStroke, Def = rDef, CanAfford = false }
	end

	for _, iDef in ipairs(ItemDefs) do
		local title, costLbl, btn, bStroke = BuildCard(RelicsGrid, iDef, false)
		costLbl.Text = "Req: " .. iDef.Cost .. " Dust"
		btn.Activated:Connect(function() 
			if PathsShopUI.Cards[iDef.Id] and not PathsShopUI.Cards[iDef.Id].CanAfford then
				local VFXManager = require(player:WaitForChild("PlayerScripts"):WaitForChild("VFXManager"))
				if VFXManager then VFXManager.PlaySFX("Error", 1) end
				return
			end
			Network:WaitForChild("PathsShopBuy"):FireServer(iDef.Id) 
		end)
		PathsShopUI.Cards[iDef.Id] = { Type = "Item", CostLbl = costLbl, Btn = btn, Stroke = bStroke, Def = iDef, CanAfford = false }
	end

	player.AttributeChanged:Connect(function(attr) if string.find(attr, "Rune_") or attr == "PathDust" or attr == "XP" then PathsShopUI.UpdateShop() end end)

	local PathsShopEvent = Network:WaitForChild("PathsShopEvent", 10)
	if PathsShopEvent then
		PathsShopEvent.OnClientEvent:Connect(function(action)
			if action == "Open" then PathsShopUI.OpenShop() end
		end)
	end

	LeaveBtn.Activated:Connect(function()
		if not PathsShopUI.IsOpen then return end
		PathsShopUI.IsOpen = false

		local VFXManager = require(player:WaitForChild("PlayerScripts"):WaitForChild("VFXManager"))
		if VFXManager then VFXManager.PlaySFX("Click", 1) end

		TweenService:Create(PathsShopUI.Overlay, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {BackgroundTransparency = 1}):Play()
		local exitTween = TweenService:Create(PathsShopUI.MainContainer, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Position = UDim2.new(0.5, 0, 0.55, 0), GroupTransparency = 1})
		exitTween:Play()

		exitTween.Completed:Wait()
		PathsShopUI.ScreenGui.Enabled = false
		if PathsShopEvent then PathsShopEvent:FireServer("Close") end
	end)
end

return PathsShopUI