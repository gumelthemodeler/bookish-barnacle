-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local ExpeditionsTab = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Network = ReplicatedStorage:WaitForChild("Network")

local SharedUI = script.Parent.Parent:WaitForChild("SharedUI")
local UIHelpers = require(SharedUI:WaitForChild("UIHelpers"))
local EnemyData = require(ReplicatedStorage:WaitForChild("EnemyData"))
local AFKTab = require(script.Parent:WaitForChild("AFKTab"))
local NotificationManager = require(SharedUI:WaitForChild("NotificationManager"))
local LabyrinthUI = require(script.Parent:WaitForChild("LabyrinthUI"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CONFIG = {
	Decals = {
		Campaign = "rbxassetid://80153476985849",
		AFK = "rbxassetid://114506098039778",
		Raid = "rbxassetid://119392967268687",
		PvP = "rbxassetid://100826303284945", 
		Nightmare = "rbxassetid://90132878979603",
		WorldBoss = "rbxassetid://129655150803684",
		Endless = "rbxassetid://81075056647024",
		Paths = "rbxassetid://90938848776194",
		Labyrinth = "rbxassetid://90132878979603"
	},
	Colors = {
		Story = Color3.fromRGB(85, 255, 127),      
		Endgame = Color3.fromRGB(170, 85, 255),    
		Multiplayer = Color3.fromRGB(255, 85, 85), 
		Competitive = Color3.fromRGB(85, 170, 255),
		Event = Color3.fromRGB(255, 215, 0)        
	}
}

local CurrentParty = {}
local IsInParty = false
local IsPartyLeader = false
local PendingInvites = {}
local isListening = false

local LayoutRefs = {}

local function AbbreviateNumber(n)
	local Suffixes = {"", "K", "M", "B", "T", "Qa"}
	if not n then return "0" end; n = tonumber(n) or 0
	if n < 1000 then return tostring(math.floor(n)) end
	local suffixIndex = math.floor(math.log10(n) / 3); local value = n / (10 ^ (suffixIndex * 3))
	local str = string.format("%.1f", value); str = str:gsub("%.0$", "")
	return str .. (Suffixes[suffixIndex + 1] or "")
end

local function FormatTime(seconds)
	local mins = math.floor(seconds / 60)
	local secs = seconds % 60
	return string.format("%02d:%02d", mins, secs)
end

local function CreateSharpButton(parent, text, size, font, textSize)
	local btn = Instance.new("TextButton", parent); btn.Size = size; btn.BackgroundColor3 = Color3.fromRGB(28, 28, 34); btn.BorderSizePixel = 0; btn.AutoButtonColor = false; btn.Font = font; btn.TextColor3 = Color3.fromRGB(245, 245, 245); btn.TextSize = textSize; btn.Text = text
	local stroke = Instance.new("UIStroke", btn); stroke.Color = Color3.fromRGB(70, 70, 80); stroke.Thickness = 2; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	btn.MouseEnter:Connect(function() stroke.Color = Color3.fromRGB(225, 185, 60); btn.TextColor3 = Color3.fromRGB(225, 185, 60) end)
	btn.MouseLeave:Connect(function() stroke.Color = Color3.fromRGB(70, 70, 80); btn.TextColor3 = Color3.fromRGB(245, 245, 245) end)
	return btn, stroke
end

local function UpdateLayoutForScreen()
	local vp = camera.ViewportSize
	if vp.X == 0 or vp.Y == 0 or not LayoutRefs.MasterLayout then return end
	local isMobile = (vp.X <= 650) or (vp.Y > vp.X * 1.1)

	if isMobile then
		LayoutRefs.MasterLayout.FillDirection = Enum.FillDirection.Vertical
		LayoutRefs.MissionsPanel.Size = UDim2.new(0.95, 0, 0, 650)
		LayoutRefs.PartyPanel.Size = UDim2.new(0.95, 0, 0, 0)
		LayoutRefs.PartyPanel.AutomaticSize = Enum.AutomaticSize.Y
		if LayoutRefs.PartyContent then
			LayoutRefs.PartyContent.Size = UDim2.new(1, -30, 0, 0)
			LayoutRefs.PartyContent.AutomaticSize = Enum.AutomaticSize.Y
		end
		LayoutRefs.PartyPanel.Position = UDim2.new(0, 0, 0, 0)
	else
		LayoutRefs.MasterLayout.FillDirection = Enum.FillDirection.Horizontal
		LayoutRefs.MissionsPanel.Size = UDim2.new(0.68, 0, 1, 0)
		LayoutRefs.PartyPanel.Size = UDim2.new(0.28, 0, 1, -20)
		LayoutRefs.PartyPanel.AutomaticSize = Enum.AutomaticSize.None
		if LayoutRefs.PartyContent then
			LayoutRefs.PartyContent.Size = UDim2.new(1, -30, 1, -30)
			LayoutRefs.PartyContent.AutomaticSize = Enum.AutomaticSize.None
		end
		LayoutRefs.PartyPanel.Position = UDim2.new(0, 0, 0, 10)
	end
end

function ExpeditionsTab.Initialize(parentFrame)
	for _, child in ipairs(parentFrame:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end

	local MasterScroll = Instance.new("ScrollingFrame", parentFrame)
	MasterScroll.Size = UDim2.new(1, 0, 1, 0)
	MasterScroll.BackgroundTransparency = 1
	MasterScroll.ScrollBarThickness = 0
	MasterScroll.BorderSizePixel = 0

	local MasterLayout = Instance.new("UIListLayout", MasterScroll)
	MasterLayout.SortOrder = Enum.SortOrder.LayoutOrder; MasterLayout.Padding = UDim.new(0, 20); MasterLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	MasterLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		if MasterLayout.FillDirection == Enum.FillDirection.Vertical then
			MasterScroll.CanvasSize = UDim2.new(0, 0, 0, MasterLayout.AbsoluteContentSize.Y + 40)
		else
			MasterScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		end
	end)

	local MissionsPanel = Instance.new("Frame", MasterScroll)
	MissionsPanel.BackgroundTransparency = 1; MissionsPanel.LayoutOrder = 1

	local HeaderFrame = Instance.new("Frame", MissionsPanel)
	HeaderFrame.Size = UDim2.new(1, 0, 0, 50); HeaderFrame.BackgroundTransparency = 1

	local Title = UIHelpers.CreateLabel(HeaderFrame, "COMBAT DEPLOYMENT", UDim2.new(1, -60, 1, 0), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 22)
	Title.Position = UDim2.new(0, 0, 0, 0); Title.TextXAlignment = Enum.TextXAlignment.Left

	local BackBtn, BackStroke = CreateSharpButton(HeaderFrame, "< BACK", UDim2.new(0, 80, 0, 30), Enum.Font.GothamBlack, 12)
	BackBtn.Position = UDim2.new(1, 0, 0.5, 0); BackBtn.AnchorPoint = Vector2.new(1, 0.5); BackBtn.Visible = false

	local Pages = {}
	local FetchLiveMatches
	local FetchDoomsdayData 
	local doomsdayLoopActive = false
	local currentDoomsdayData = nil

	local function ShowPage(pageName, titleText)
		for name, frame in pairs(Pages) do frame.Visible = (name == pageName) end
		Title.Text = titleText
		BackBtn.Visible = (pageName ~= "Main")
		if pageName == "PvP" and FetchLiveMatches then FetchLiveMatches() end

		if pageName == "Doomsday" and FetchDoomsdayData then 
			FetchDoomsdayData(false) 

			if not doomsdayLoopActive then
				doomsdayLoopActive = true
				task.spawn(function()
					local syncTick = 0
					while Pages["Doomsday"] and Pages["Doomsday"].Visible do
						if currentDoomsdayData then
							local passed = os.time() - currentDoomsdayData.LocalSyncTime

							local ddHpLbl = Pages["Doomsday"]:FindFirstChild("DDContainer") and Pages["Doomsday"].DDContainer:FindFirstChild("GlobalHpLbl")
							local EngageBtn = Pages["Doomsday"]:FindFirstChild("DDContainer") and Pages["Doomsday"].DDContainer:FindFirstChild("EngageBtn")

							if currentDoomsdayData.IsActive then
								if ddHpLbl then
									ddHpLbl.Text = "GLOBAL HP: " .. AbbreviateNumber(currentDoomsdayData.BossHP)
									ddHpLbl.TextColor3 = Color3.fromRGB(255, 100, 100)
								end
								if EngageBtn then
									EngageBtn.Text = "DEPLOY TO FRONTLINE"
									EngageBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
									EngageBtn:FindFirstChild("UIStroke").Color = Color3.fromRGB(200, 50, 50)
								end
							else
								local displayTime = math.max(0, currentDoomsdayData.TimeUntilNext - passed)
								if ddHpLbl then
									ddHpLbl.Text = "STATUS: INACTIVE (APPEARS IN " .. FormatTime(displayTime) .. ")"
									ddHpLbl.TextColor3 = UIHelpers.Colors.TextMuted
								end
								if EngageBtn then
									EngageBtn.Text = "AWAITING APPEARANCE"
									EngageBtn.TextColor3 = UIHelpers.Colors.TextMuted
									EngageBtn:FindFirstChild("UIStroke").Color = UIHelpers.Colors.BorderMuted
								end
							end
						end

						task.wait(1)
						syncTick += 1
						if syncTick >= 5 then 
							syncTick = 0
							FetchDoomsdayData(true)
						end
					end
					doomsdayLoopActive = false
				end)
			end
		end
	end

	BackBtn.MouseButton1Click:Connect(function() ShowPage("Main", "COMBAT DEPLOYMENT") end)

	local DeployOverlay = Instance.new("Frame", parentFrame.Parent) 
	DeployOverlay.Name = "DeploymentTransition"; DeployOverlay.Size = UDim2.new(1, 0, 1, 0); DeployOverlay.BackgroundColor3 = Color3.fromRGB(12, 12, 15); DeployOverlay.BackgroundTransparency = 1; DeployOverlay.ZIndex = 90; DeployOverlay.Visible = false
	local dStatus = UIHelpers.CreateLabel(DeployOverlay, "ESTABLISHING CONNECTION...", UDim2.new(1, 0, 0, 40), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 24)
	dStatus.Position = UDim2.new(0, 0, 0.5, -20); dStatus.TextTransparency = 1; dStatus.ZIndex = 91

	local function InitiateDeployment(remoteName, action, payload)
		DeployOverlay.Visible = true
		TweenService:Create(DeployOverlay, TweenInfo.new(0.4), {BackgroundTransparency = 0.1}):Play()
		TweenService:Create(dStatus, TweenInfo.new(0.4), {TextTransparency = 0}):Play()

		dStatus.Text = "PREPARING STRIKE TEAM..."; task.wait(0.6)
		dStatus.Text = "DEPLOYING TO COMBAT ZONE..."; dStatus.TextColor3 = Color3.fromRGB(255, 100, 100)

		task.wait(0.8)
		if payload then Network:WaitForChild(remoteName):FireServer(action, payload) else Network:WaitForChild(remoteName):FireServer(action) end

		local t1 = TweenService:Create(DeployOverlay, TweenInfo.new(0.5), {BackgroundTransparency = 1})
		local t2 = TweenService:Create(dStatus, TweenInfo.new(0.5), {TextTransparency = 1})
		t1:Play(); t2:Play(); t1.Completed:Wait()
		DeployOverlay.Visible = false; dStatus.TextColor3 = UIHelpers.Colors.Gold
	end

	local function CreateModeCard(parent, title, desc, imageId, layoutOrder, onClick, categoryColor)
		local cardBtn = Instance.new("TextButton", parent)
		cardBtn.LayoutOrder = layoutOrder; cardBtn.Text = ""; cardBtn.AutoButtonColor = false; cardBtn.ClipsDescendants = true
		cardBtn.Size = UDim2.new(1, -10, 0, 80)
		cardBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 18)

		local stroke = Instance.new("UIStroke", cardBtn)
		stroke.Color = UIHelpers.Colors.BorderMuted; stroke.Thickness = 2

		local leftAccent = Instance.new("Frame", cardBtn)
		leftAccent.Size = UDim2.new(0, 6, 1, 0); leftAccent.BackgroundColor3 = categoryColor; leftAccent.BorderSizePixel = 0; leftAccent.ZIndex = 5

		local bgImage = Instance.new("ImageLabel", cardBtn)
		bgImage.Size = UDim2.new(1, 0, 1, 0); bgImage.BackgroundTransparency = 1; bgImage.Image = imageId; bgImage.ScaleType = Enum.ScaleType.Crop; bgImage.ZIndex = 1
		bgImage.ImageColor3 = categoryColor; bgImage.ImageTransparency = 0.5 

		local gradFrame = Instance.new("Frame", cardBtn); gradFrame.Size = UDim2.new(1, 0, 1, 0); gradFrame.BackgroundColor3 = Color3.new(0,0,0); gradFrame.BorderSizePixel = 0; gradFrame.ZIndex = 2
		local grad = Instance.new("UIGradient", gradFrame); grad.Rotation = 0
		grad.Transparency = NumberSequence.new{
			NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.6, 0.4), NumberSequenceKeypoint.new(1, 0.95)
		}

		local lblTitle = UIHelpers.CreateLabel(cardBtn, title, UDim2.new(1, -150, 0, 25), Enum.Font.GothamBlack, UIHelpers.Colors.TextWhite, 18)
		lblTitle.Position = UDim2.new(0, 20, 0, 12); lblTitle.TextXAlignment = Enum.TextXAlignment.Left; lblTitle.ZIndex = 4

		local lblDesc = UIHelpers.CreateLabel(cardBtn, desc, UDim2.new(1, -150, 0, 30), Enum.Font.GothamMedium, UIHelpers.Colors.TextWhite, 13)
		lblDesc.TextTransparency = 0.2; lblDesc.Position = UDim2.new(0, 20, 0, 38); lblDesc.TextXAlignment = Enum.TextXAlignment.Left; lblDesc.TextWrapped = true; lblDesc.TextYAlignment = Enum.TextYAlignment.Top; lblDesc.ZIndex = 4

		local actionBtn, actStroke = CreateSharpButton(cardBtn, "DEPLOY", UDim2.new(0, 110, 0, 45), Enum.Font.GothamBlack, 14)
		actionBtn.Position = UDim2.new(1, -15, 0.5, 0); actionBtn.AnchorPoint = Vector2.new(1, 0.5); actionBtn.ZIndex = 5

		cardBtn.MouseEnter:Connect(function() 
			stroke.Color = categoryColor; actStroke.Color = categoryColor; actionBtn.TextColor3 = categoryColor 
			TweenService:Create(bgImage, TweenInfo.new(0.35, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {ImageTransparency = 0.25, Size = UDim2.new(1.05, 0, 1.05, 0), Position = UDim2.new(-0.025, 0, -0.025, 0)}):Play()
		end)
		cardBtn.MouseLeave:Connect(function() 
			stroke.Color = UIHelpers.Colors.BorderMuted; actStroke.Color = Color3.fromRGB(70, 70, 80); actionBtn.TextColor3 = Color3.fromRGB(245, 245, 245) 
			TweenService:Create(bgImage, TweenInfo.new(0.35, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {ImageTransparency = 0.5, Size = UDim2.new(1, 0, 1, 0), Position = UDim2.new(0, 0, 0, 0)}):Play()
		end)

		actionBtn.MouseButton1Click:Connect(onClick)
		return cardBtn
	end

	local GridContainer = Instance.new("ScrollingFrame", MissionsPanel)
	GridContainer.Size = UDim2.new(1, 0, 1, -60); GridContainer.Position = UDim2.new(0, 0, 0, 50); GridContainer.BackgroundTransparency = 1; GridContainer.ScrollBarThickness = 6; GridContainer.BorderSizePixel = 0
	Pages["Main"] = GridContainer

	local mainGridPad = Instance.new("UIPadding", GridContainer)
	mainGridPad.PaddingTop = UDim.new(0, 5); mainGridPad.PaddingBottom = UDim.new(0, 10)

	local listLayout = Instance.new("UIListLayout", GridContainer)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder; listLayout.Padding = UDim.new(0, 12); listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() GridContainer.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 20) end)

	local function RefreshMainGrid()
		for _, c in ipairs(GridContainer:GetChildren()) do
			if c.Name == "RumblingCard_Active" or c.Name == "RumblingCard_Trigger" then c:Destroy() end
		end

		local isRumblingActive = ReplicatedStorage:GetAttribute("RumblingActive")
		local bones = tonumber(player:GetAttribute("FoundersBoneCount")) or 0

		if isRumblingActive then
			local rumblingCard = CreateModeCard(GridContainer, "THE RUMBLING (ACTIVE)", "The world is being trampled. Deploy to the frontline to stop the Wall Titans!", CONFIG.Decals.WorldBoss, -1, function() 
				InitiateDeployment("CombatAction", "EngageWorldBoss", {BossId = "Rumbling Horde"})
			end, Color3.fromRGB(255, 0, 0))
			rumblingCard.Name = "RumblingCard_Active"
		elseif bones > 0 then
			local triggerCard = CreateModeCard(GridContainer, "INITIATE RUMBLING", "Consume your Founder's Bone to summon a global Wall Titan invasion.", CONFIG.Decals.WorldBoss, 0, function() 
				Network:WaitForChild("TriggerRumbling"):FireServer()
				if NotificationManager and type(NotificationManager.Show) == "function" then NotificationManager.Show("Initiating the Rumbling...", "Success") end
			end, Color3.fromRGB(255, 85, 255))
			triggerCard.Name = "RumblingCard_Trigger"
		end
	end

	ReplicatedStorage:GetAttributeChangedSignal("RumblingActive"):Connect(RefreshMainGrid)
	player.AttributeChanged:Connect(function(attr) if attr == "FoundersBoneCount" then RefreshMainGrid() end end)
	RefreshMainGrid()

	local cPart = player:GetAttribute("CurrentPart") or 1
	local cMiss = player:GetAttribute("CurrentMission") or 1
	local campaignDescLbl = CreateModeCard(GridContainer, "STORY CAMPAIGN", string.format("Part %d - Mission %d\nProgress through the main storyline.", cPart, cMiss), CONFIG.Decals.Campaign, 1, function() InitiateDeployment("CombatAction", "EngageStory") end, CONFIG.Colors.Story)

	player.AttributeChanged:Connect(function(attr)
		if attr == "CurrentPart" or attr == "CurrentMission" then
			local desc = campaignDescLbl:FindFirstChildOfClass("TextLabel")
			if desc then desc.Text = string.format("Part %d - Mission %d\nProgress through the main storyline.", player:GetAttribute("CurrentPart") or 1, player:GetAttribute("CurrentMission") or 1) end
		end
	end)

	local wday = os.date("!*t").wday
	local isPathsOpen = (wday == 7 or wday == 1 or wday == 2)
	local pathsDesc = isPathsOpen and "Venture into the coordinate to farm Path Dust for Memory Runes." or "[EVENT CLOSED] Opens on Sat, Sun, and Mon."
	local pathsCardLbl = CreateModeCard(GridContainer, "THE PATHS (EVENT)", pathsDesc, CONFIG.Decals.Paths, 2, function() 
		if isPathsOpen then InitiateDeployment("CombatAction", "EngagePaths") else
			if NotificationManager and type(NotificationManager.Show) == "function" then NotificationManager.Show("The Paths are currently closed. Returns Sat, Sun & Mon.", "Error") end
		end
	end, CONFIG.Colors.Event)
	if not isPathsOpen then pathsCardLbl:FindFirstChildOfClass("TextLabel").TextColor3 = Color3.fromRGB(255, 100, 100) end

	CreateModeCard(GridContainer, "ENDLESS FRONTIER", "Fight infinite waves to continually harvest Dews, XP, and materials.", CONFIG.Decals.Endless, 3, function() InitiateDeployment("CombatAction", "EngageEndless") end, CONFIG.Colors.Event)

	CreateModeCard(GridContainer, "THE LABYRINTH", "Navigate a dark, shifting maze. Secure loot caches and escape, or die and lose everything.", CONFIG.Decals.Labyrinth, 4, function() 
		local masterScreenGui = parentFrame:FindFirstAncestorOfClass("ScreenGui")
		LabyrinthUI.Open(masterScreenGui) 
	end, CONFIG.Colors.Endgame)

	CreateModeCard(GridContainer, "MULTIPLAYER RAIDS", "Deploy your party to take down Colossal threats.", CONFIG.Decals.Raid, 5, function() ShowPage("Raids", "MULTIPLAYER RAIDS") end, CONFIG.Colors.Multiplayer)
	CreateModeCard(GridContainer, "DOOMSDAY BOUNTIES", "Server-wide raid bosses. Fight for the top of the global leaderboard.", CONFIG.Decals.WorldBoss, 6, function() ShowPage("Doomsday", "DOOMSDAY BOUNTIES") end, CONFIG.Colors.Multiplayer)
	CreateModeCard(GridContainer, "WORLD BOSSES", "A catastrophic threat has appeared. Intercept immediately.", CONFIG.Decals.WorldBoss, 7, function() ShowPage("WorldBoss", "WORLD BOSSES") end, CONFIG.Colors.Multiplayer)
	CreateModeCard(GridContainer, "NIGHTMARE HUNTS", "Face corrupted Titans to obtain legendary Cursed Weapons.", CONFIG.Decals.Nightmare, 8, function() ShowPage("Nightmare", "NIGHTMARE HUNTS") end, CONFIG.Colors.Endgame)
	CreateModeCard(GridContainer, "PVP ARENA", "Test your ODM combat skills against other players.", CONFIG.Decals.PvP, 9, function() ShowPage("PvP", "PVP ARENA") end, CONFIG.Colors.Competitive)
	CreateModeCard(GridContainer, "AFK EXPEDITIONS", "Send out scout regiments to gather resources over long periods.", CONFIG.Decals.AFK, 10, function() ShowPage("AFK", "AFK EXPEDITIONS") end, CONFIG.Colors.Event)

	local function CreateSubPage(name)
		local page = Instance.new("ScrollingFrame", MissionsPanel); page.Size = UDim2.new(1, 0, 1, -60); page.Position = UDim2.new(0, 0, 0, 50); page.BackgroundTransparency = 1; page.ScrollBarThickness = 6; page.BorderSizePixel = 0; page.Visible = false
		Pages[name] = page; local lay = Instance.new("UIListLayout", page); lay.Padding = UDim.new(0, 10); lay.HorizontalAlignment = Enum.HorizontalAlignment.Center
		lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() page.CanvasSize = UDim2.new(0, 0, 0, lay.AbsoluteContentSize.Y + 20) end)
		return page
	end

	local AFKPage = Instance.new("Frame", MissionsPanel); AFKPage.Size = UDim2.new(1, 0, 1, -60); AFKPage.Position = UDim2.new(0, 0, 0, 50); AFKPage.BackgroundTransparency = 1; AFKPage.Visible = false
	Pages["AFK"] = AFKPage; AFKTab.Initialize(AFKPage, InitiateDeployment)

	local DoomsdayPage = CreateSubPage("Doomsday")

	local DDContainer = Instance.new("Frame", DoomsdayPage)
	DDContainer.Name = "DDContainer"
	DDContainer.Size = UDim2.new(1, -20, 0, 160)
	DDContainer.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	local ddStroke = Instance.new("UIStroke", DDContainer); ddStroke.Color = Color3.fromRGB(70, 70, 80); ddStroke.Thickness = 2

	local ddTitle = UIHelpers.CreateLabel(DDContainer, "THE PRIMORDIAL THREAT", UDim2.new(1, 0, 0, 30), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 22)
	ddTitle.Position = UDim2.new(0, 0, 0, 15)

	local ddHpLbl = UIHelpers.CreateLabel(DDContainer, "GLOBAL HP: FETCHING...", UDim2.new(1, 0, 0, 20), Enum.Font.GothamBold, Color3.fromRGB(255, 100, 100), 16)
	ddHpLbl.Name = "GlobalHpLbl"
	ddHpLbl.Position = UDim2.new(0, 0, 0, 55)

	local EngageBtn, _ = CreateSharpButton(DDContainer, "DEPLOY TO FRONTLINE", UDim2.new(0, 250, 0, 45), Enum.Font.GothamBlack, 16)
	EngageBtn.Name = "EngageBtn"
	EngageBtn.Position = UDim2.new(0.5, 0, 0, 95); EngageBtn.AnchorPoint = Vector2.new(0.5, 0)

	EngageBtn.MouseButton1Click:Connect(function() 
		if EngageBtn.Text == "DEPLOY TO FRONTLINE" then 
			InitiateDeployment("CombatAction", "EngageDoomsday") 
		end
	end)

	local DDHeaderRow = Instance.new("Frame", DoomsdayPage)
	DDHeaderRow.Size = UDim2.new(1, -20, 0, 30)
	DDHeaderRow.BackgroundTransparency = 1

	local DDLeaderboardTitle = UIHelpers.CreateLabel(DDHeaderRow, "TOP DAMAGE CONTRIBUTORS", UDim2.new(0.7, 0, 1, 0), Enum.Font.GothamBlack, UIHelpers.Colors.TextWhite, 18)
	DDLeaderboardTitle.TextXAlignment = Enum.TextXAlignment.Left

	local DDRefreshBtn, _ = CreateSharpButton(DDHeaderRow, "REFRESH DATA", UDim2.new(0, 120, 1, 0), Enum.Font.GothamBold, 11)
	DDRefreshBtn.Position = UDim2.new(1, 0, 0, 0); DDRefreshBtn.AnchorPoint = Vector2.new(1, 0)

	FetchDoomsdayData = function(isBackgroundSync)
		task.spawn(function()
			local remote = Network:WaitForChild("GetDoomsdayData", 3)
			if not remote then return end

			local data = remote:InvokeServer()
			if data then
				data.LocalSyncTime = os.time()
				currentDoomsdayData = data

				if not isBackgroundSync then
					for _, c in ipairs(DoomsdayPage:GetChildren()) do if c.Name == "DDPlayerCard" then c:Destroy() end end
					for i, pData in ipairs(data.Leaderboard or {}) do
						local card = Instance.new("Frame", DoomsdayPage)
						card.Name = "DDPlayerCard"
						card.Size = UDim2.new(1, -20, 0, 40); card.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
						Instance.new("UIStroke", card).Color = UIHelpers.Colors.BorderMuted

						local cColor = (i==1) and UIHelpers.Colors.Gold or ((i==2) and Color3.fromRGB(200, 200, 200) or UIHelpers.Colors.TextWhite)

						local rLbl = UIHelpers.CreateLabel(card, "#" .. i, UDim2.new(0, 40, 1, 0), Enum.Font.GothamBlack, cColor, 16)
						local nLbl = UIHelpers.CreateLabel(card, pData.Name, UDim2.new(0.5, 0, 1, 0), Enum.Font.GothamBold, cColor, 14)
						nLbl.Position = UDim2.new(0, 50, 0, 0); nLbl.TextXAlignment = Enum.TextXAlignment.Left

						local dmgLbl = UIHelpers.CreateLabel(card, AbbreviateNumber(pData.Damage) .. " DMG", UDim2.new(0.4, 0, 1, 0), Enum.Font.GothamBlack, UIHelpers.Colors.TextMuted, 14)
						dmgLbl.Position = UDim2.new(1, -10, 0, 0); dmgLbl.AnchorPoint = Vector2.new(1, 0); dmgLbl.TextXAlignment = Enum.TextXAlignment.Right
					end
				end
			end
		end)
	end
	DDRefreshBtn.MouseButton1Click:Connect(function() FetchDoomsdayData(false) end)

	local NightmarePage = CreateSubPage("Nightmare")
	local nIndex = 1
	for id, boss in pairs(EnemyData.NightmareHunts or {}) do
		local icon = EnemyData.BossIcons and EnemyData.BossIcons[id] or CONFIG.Decals.Nightmare
		CreateModeCard(NightmarePage, string.upper(boss.Name), boss.Desc or "Eliminate the corrupted Titan.", icon, nIndex, function() InitiateDeployment("CombatAction", "EngageNightmare", {BossId = id}) end, CONFIG.Colors.Endgame)
		nIndex = nIndex + 1
	end

	local WorldBossPage = CreateSubPage("WorldBoss")
	local wIndex = 1
	for id, boss in pairs(EnemyData.WorldBosses or {}) do
		if not boss.IsRumblingBoss then
			local icon = EnemyData.BossIcons and EnemyData.BossIcons[id] or CONFIG.Decals.WorldBoss
			CreateModeCard(WorldBossPage, string.upper(boss.Name), boss.Desc or "A massive threat approaches.", icon, wIndex, function() InitiateDeployment("CombatAction", "EngageWorldBoss", {BossId = id}) end, CONFIG.Colors.Multiplayer)
			wIndex = wIndex + 1
		end
	end

	local RaidPage = CreateSubPage("Raids")
	local raidList = {}
	for id, boss in pairs(EnemyData.RaidBosses or {}) do table.insert(raidList, {Id = id, Data = boss}) end
	table.sort(raidList, function(a, b) return a.Id < b.Id end)

	for i, rInfo in ipairs(raidList) do
		local id = rInfo.Id; local boss = rInfo.Data
		local icon = EnemyData.BossIcons and EnemyData.BossIcons[id] or CONFIG.Decals.Raid
		CreateModeCard(RaidPage, string.upper(boss.Name), "Multiplayer Raid. Coordinate strikes and manage aggro to survive.", icon, i, function() InitiateDeployment("RaidAction", "DeployParty", {RaidId = id}) end, CONFIG.Colors.Multiplayer)
	end

	local PvPPage = CreateSubPage("PvP")

	local PvPQueuePanel = Instance.new("Frame", PvPPage)
	PvPQueuePanel.Size = UDim2.new(1, -20, 0, 150)
	PvPQueuePanel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
	local pvpQStroke = Instance.new("UIStroke", PvPQueuePanel); pvpQStroke.Color = Color3.fromRGB(70, 70, 80); pvpQStroke.Thickness = 2

	local pqTitle = UIHelpers.CreateLabel(PvPQueuePanel, "RANKED MATCHMAKING", UDim2.new(1, 0, 0, 30), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 20)
	pqTitle.Position = UDim2.new(0, 0, 0, 15)

	local pqDesc = UIHelpers.CreateLabel(PvPQueuePanel, "Battle other players to increase your Elo Rating. Higher Elo grants better seasonal rewards.", UDim2.new(1, -20, 0, 20), Enum.Font.GothamBold, UIHelpers.Colors.TextMuted, 14)
	pqDesc.Position = UDim2.new(0.5, 0, 0, 50); pqDesc.AnchorPoint = Vector2.new(0.5, 0); pqDesc.TextWrapped = true

	local QueueBtn = CreateSharpButton(PvPQueuePanel, "ENTER QUEUE", UDim2.new(0, 200, 0, 40), Enum.Font.GothamBlack, 16)
	QueueBtn.Position = UDim2.new(0.5, 0, 0, 90); QueueBtn.AnchorPoint = Vector2.new(0.5, 0)
	local inQueue = false

	QueueBtn.MouseButton1Click:Connect(function()
		inQueue = not inQueue
		if inQueue then
			QueueBtn.Text = "LEAVE QUEUE"; QueueBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
			Network:WaitForChild("PvPAction"):FireServer("JoinQueue")
		else
			QueueBtn.Text = "ENTER QUEUE"; QueueBtn.TextColor3 = UIHelpers.Colors.TextWhite
			Network:WaitForChild("PvPAction"):FireServer("LeaveQueue")
		end
	end)

	Network:WaitForChild("PvPUpdate").OnClientEvent:Connect(function(action, matchId, p1Name, p2Name, p1Id, p2Id, turnEndTime, is3v3, t1Ids, t2Ids)
		if action == "MatchStarted" then
			local amIInvolved = false
			if is3v3 and t1Ids and t2Ids then
				if table.find(t1Ids, player.UserId) or table.find(t2Ids, player.UserId) then amIInvolved = true end
			else
				if p1Id == player.UserId or p2Id == player.UserId then amIInvolved = true end
			end

			if amIInvolved then
				inQueue = false
				QueueBtn.Text = "ENTER QUEUE"
				QueueBtn.TextColor3 = UIHelpers.Colors.TextWhite
			end
		end
	end)

	local SpecHeaderContainer = Instance.new("Frame", PvPPage)
	SpecHeaderContainer.Size = UDim2.new(1, -20, 0, 30)
	SpecHeaderContainer.BackgroundTransparency = 1

	local PvPMatchesTitle = UIHelpers.CreateLabel(SpecHeaderContainer, "ACTIVE SPECTATOR MATCHES", UDim2.new(0.7, 0, 1, 0), Enum.Font.GothamBlack, UIHelpers.Colors.TextWhite, 18)
	PvPMatchesTitle.TextXAlignment = Enum.TextXAlignment.Left

	local RefreshBtn = CreateSharpButton(SpecHeaderContainer, "REFRESH", UDim2.new(0, 80, 0, 24), Enum.Font.GothamBold, 11)
	RefreshBtn.Position = UDim2.new(1, 0, 0.5, 0); RefreshBtn.AnchorPoint = Vector2.new(1, 0.5)

	FetchLiveMatches = function()
		for _, c in ipairs(PvPPage:GetChildren()) do if c.Name == "LiveMatchCard" or c.Name == "LiveMatchMsg" then c:Destroy() end end

		local loadingLbl = UIHelpers.CreateLabel(PvPPage, "Scanning for live matches...", UDim2.new(1, 0, 0, 50), Enum.Font.GothamBold, UIHelpers.Colors.Gold, 14)
		loadingLbl.Name = "LiveMatchMsg"

		task.spawn(function()
			local matches = Network:WaitForChild("GetLiveMatches"):InvokeServer()
			if loadingLbl and loadingLbl.Parent then loadingLbl:Destroy() end

			if type(matches) ~= "table" or #matches == 0 then
				local msg = UIHelpers.CreateLabel(PvPPage, "No active ranked matches at this time.", UDim2.new(1, 0, 0, 50), Enum.Font.GothamBold, UIHelpers.Colors.TextMuted, 14)
				msg.Name = "LiveMatchMsg"
				return
			end

			for _, matchData in ipairs(matches) do
				local mCard = Instance.new("Frame", PvPPage)
				mCard.Name = "LiveMatchCard"
				mCard.Size = UDim2.new(1, -20, 0, 60); mCard.BackgroundColor3 = Color3.fromRGB(25, 25, 30); Instance.new("UIStroke", mCard).Color = UIHelpers.Colors.BorderMuted

				local vsLbl = UIHelpers.CreateLabel(mCard, (matchData.Player1 or "Fighter") .. "  VS  " .. (matchData.Player2 or "Fighter"), UDim2.new(0.6, 0, 1, 0), Enum.Font.GothamBlack, UIHelpers.Colors.TextWhite, 16)
				vsLbl.Position = UDim2.new(0, 15, 0, 0); vsLbl.TextXAlignment = Enum.TextXAlignment.Left

				local specBtn = CreateSharpButton(mCard, "SPECTATE", UDim2.new(0, 120, 0, 36), Enum.Font.GothamBlack, 12)
				specBtn.Position = UDim2.new(1, -15, 0.5, 0); specBtn.AnchorPoint = Vector2.new(1, 0.5); specBtn.TextColor3 = UIHelpers.Colors.Gold

				specBtn.MouseButton1Click:Connect(function() Network:WaitForChild("PvPAction"):FireServer("SpectateMatch", matchData.MatchId) end)
			end
		end)
	end
	RefreshBtn.MouseButton1Click:Connect(FetchLiveMatches)

	-- ==========================================
	-- RIGHT PANEL: PARTY SYSTEM 
	-- ==========================================
	local PartyPanel = Instance.new("Frame", MasterScroll)
	PartyPanel.BackgroundColor3 = Color3.fromRGB(15, 15, 18); PartyPanel.LayoutOrder = 2
	local pStroke = Instance.new("UIStroke", PartyPanel); pStroke.Color = UIHelpers.Colors.BorderMuted; pStroke.Thickness = 2

	local PartyContent = Instance.new("Frame", PartyPanel)
	PartyContent.Size = UDim2.new(1, -30, 1, -30); PartyContent.Position = UDim2.new(0, 15, 0, 15); PartyContent.BackgroundTransparency = 1

	LayoutRefs.MasterScroll = MasterScroll
	LayoutRefs.MasterLayout = MasterLayout
	LayoutRefs.MissionsPanel = MissionsPanel
	LayoutRefs.PartyPanel = PartyPanel
	LayoutRefs.PartyContent = PartyContent

	camera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateLayoutForScreen)
	UpdateLayoutForScreen()

	local function RenderPartyUI()
		for _, child in ipairs(PartyContent:GetChildren()) do child:Destroy() end

		local pLayout = Instance.new("UIListLayout", PartyContent); pLayout.SortOrder = Enum.SortOrder.LayoutOrder; pLayout.Padding = UDim.new(0, 15); pLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		pLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			PartyContent.Size = UDim2.new(1, -30, 0, pLayout.AbsoluteContentSize.Y)
			if LayoutRefs.MasterLayout.FillDirection == Enum.FillDirection.Vertical then
				LayoutRefs.MasterScroll.CanvasSize = UDim2.new(0, 0, 0, LayoutRefs.MasterLayout.AbsoluteContentSize.Y + 40)
			end
		end)

		if IsInParty then
			local Header = UIHelpers.CreateLabel(PartyContent, "STRIKE TEAM (" .. #CurrentParty .. "/3)", UDim2.new(1, 0, 0, 30), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 18)
			Header.LayoutOrder = 1; Header.TextXAlignment = Enum.TextXAlignment.Left

			local RosterFrame = Instance.new("Frame", PartyContent); RosterFrame.Size = UDim2.new(1, 0, 0, #CurrentParty * 50); RosterFrame.BackgroundTransparency = 1; RosterFrame.LayoutOrder = 2
			local rLayout = Instance.new("UIListLayout", RosterFrame); rLayout.Padding = UDim.new(0, 8)

			for _, member in ipairs(CurrentParty) do
				local mCard = Instance.new("Frame", RosterFrame); mCard.Size = UDim2.new(1, 0, 0, 42); mCard.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
				local mStroke = Instance.new("UIStroke", mCard); mStroke.Color = UIHelpers.Colors.BorderMuted
				local mName = UIHelpers.CreateLabel(mCard, member.Name, UDim2.new(1, -45, 1, 0), Enum.Font.GothamBold, UIHelpers.Colors.TextWhite, 14)
				mName.Position = UDim2.new(0, 15, 0, 0); mName.TextXAlignment = Enum.TextXAlignment.Left

				if member.IsLeader then
					local crown = UIHelpers.CreateLabel(mCard, "👑", UDim2.new(0, 30, 1, 0), Enum.Font.GothamBlack, UIHelpers.Colors.Gold, 16); crown.Position = UDim2.new(1, -35, 0, 0)
				end
			end

			if IsPartyLeader then
				local InviteContainer = Instance.new("Frame", PartyContent); InviteContainer.Size = UDim2.new(1, 0, 0, 80); InviteContainer.BackgroundTransparency = 1; InviteContainer.LayoutOrder = 3
				local invHeader = UIHelpers.CreateLabel(InviteContainer, "INVITE PLAYER", UDim2.new(1, 0, 0, 20), Enum.Font.GothamBold, UIHelpers.Colors.TextMuted, 12); invHeader.TextXAlignment = Enum.TextXAlignment.Left
				local NameInput = Instance.new("TextBox", InviteContainer); NameInput.Size = UDim2.new(1, 0, 0, 35); NameInput.Position = UDim2.new(0, 0, 0, 25); NameInput.BackgroundColor3 = Color3.fromRGB(20, 20, 25); NameInput.TextColor3 = UIHelpers.Colors.TextWhite; NameInput.Font = Enum.Font.GothamMedium; NameInput.TextSize = 14; NameInput.PlaceholderText = "Enter Username..."; NameInput.Text = ""
				Instance.new("UIStroke", NameInput).Color = UIHelpers.Colors.BorderMuted

				local InvBtn = CreateSharpButton(InviteContainer, "SEND", UDim2.new(1, 0, 0, 30), Enum.Font.GothamBlack, 12); InvBtn.Position = UDim2.new(0, 0, 0, 65)
				InvBtn.MouseButton1Click:Connect(function() if NameInput.Text ~= "" then Network:WaitForChild("PartyAction"):FireServer("Invite", NameInput.Text); NameInput.Text = "" end end)
			end

			local LeaveBtn = CreateSharpButton(PartyContent, "LEAVE TEAM", UDim2.new(1, 0, 0, 35), Enum.Font.GothamBlack, 14); LeaveBtn.LayoutOrder = 4; LeaveBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
			LeaveBtn.MouseButton1Click:Connect(function() Network:WaitForChild("PartyAction"):FireServer("Leave") end)

		else
			local Header = UIHelpers.CreateLabel(PartyContent, "SOLO DEPLOYMENT", UDim2.new(1, 0, 0, 30), Enum.Font.GothamBlack, UIHelpers.Colors.TextMuted, 18); Header.LayoutOrder = 1; Header.TextXAlignment = Enum.TextXAlignment.Left
			local CreateBtn = CreateSharpButton(PartyContent, "CREATE STRIKE TEAM", UDim2.new(1, 0, 0, 40), Enum.Font.GothamBlack, 14); CreateBtn.LayoutOrder = 2
			CreateBtn.MouseButton1Click:Connect(function() Network:WaitForChild("PartyAction"):FireServer("Create") end)

			local inviteCount = 0; for k, v in pairs(PendingInvites) do inviteCount = inviteCount + 1 end
			if inviteCount > 0 then
				local invHeader = UIHelpers.CreateLabel(PartyContent, "INCOMING INVITES", UDim2.new(1, 0, 0, 30), Enum.Font.GothamBold, UIHelpers.Colors.Gold, 12); invHeader.LayoutOrder = 3; invHeader.TextXAlignment = Enum.TextXAlignment.Left
				local InvList = Instance.new("ScrollingFrame", PartyContent); InvList.Size = UDim2.new(1, 0, 1, -130); InvList.BackgroundTransparency = 1; InvList.ScrollBarThickness = 4; InvList.BorderSizePixel = 0; InvList.LayoutOrder = 4
				local ilLayout = Instance.new("UIListLayout", InvList); ilLayout.Padding = UDim.new(0, 8)

				for inviterName, _ in pairs(PendingInvites) do
					local iCard = Instance.new("Frame", InvList); iCard.Size = UDim2.new(1, 0, 0, 40); iCard.BackgroundColor3 = Color3.fromRGB(25, 25, 30); Instance.new("UIStroke", iCard).Color = UIHelpers.Colors.BorderMuted
					local iName = UIHelpers.CreateLabel(iCard, inviterName, UDim2.new(0.6, 0, 1, 0), Enum.Font.GothamBold, UIHelpers.Colors.TextWhite, 12); iName.Position = UDim2.new(0, 10, 0, 0); iName.TextXAlignment = Enum.TextXAlignment.Left

					local accBtn = CreateSharpButton(iCard, "JOIN", UDim2.new(0.35, 0, 0, 26), Enum.Font.GothamBlack, 10); accBtn.Position = UDim2.new(1, -5, 0.5, 0); accBtn.AnchorPoint = Vector2.new(1, 0.5); accBtn.TextColor3 = UIHelpers.Colors.Gold
					accBtn.MouseButton1Click:Connect(function() Network:WaitForChild("PartyAction"):FireServer("AcceptInvite", inviterName); PendingInvites[inviterName] = nil; RenderPartyUI() end)
				end
			end
		end
	end

	if not isListening then
		isListening = true
		local PartyUpdate = Network:WaitForChild("PartyUpdate")
		PartyUpdate.OnClientEvent:Connect(function(action, data)
			if action == "UpdateList" then
				IsInParty = true; CurrentParty = data; IsPartyLeader = false
				for _, mem in ipairs(CurrentParty) do if mem.UserId == player.UserId and mem.IsLeader then IsPartyLeader = true end end
				PendingInvites = {}; RenderPartyUI()
			elseif action == "IncomingInvite" then PendingInvites[data] = true; RenderPartyUI()
			elseif action == "Disbanded" then IsInParty = false; CurrentParty = {}; IsPartyLeader = false; RenderPartyUI() end
		end)
	end
	RenderPartyUI()
end

return ExpeditionsTab