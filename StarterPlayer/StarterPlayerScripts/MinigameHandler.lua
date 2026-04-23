-- @ScriptType: LocalScript
-- @ScriptType: LocalScript
-- Name: MinigameHandler
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Network = ReplicatedStorage:WaitForChild("Network")
local CombatUpdate = Network:WaitForChild("CombatUpdate")
local CombatAction = Network:WaitForChild("CombatAction")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

local ScreenGui = Instance.new("ScreenGui", PlayerGui)
ScreenGui.Name = "MinigameGUI"
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999 
ScreenGui.Enabled = false

local Overlay = Instance.new("Frame", ScreenGui)
Overlay.Size = UDim2.new(1, 0, 1, 0)
Overlay.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
Overlay.BackgroundTransparency = 0.05
Overlay.ZIndex = 100 
Overlay.Active = true 

local Title = Instance.new("TextLabel", Overlay)
Title.Size = UDim2.new(1, 0, 0, 60)
Title.Position = UDim2.new(0, 0, 0.1, 0)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBlack
Title.TextColor3 = Color3.fromRGB(255, 215, 100)
Title.TextSize = 28
Title.ZIndex = 101

local Subtitle = Instance.new("TextLabel", Overlay)
Subtitle.Size = UDim2.new(1, 0, 0, 30)
Subtitle.Position = UDim2.new(0, 0, 0.1, 60)
Subtitle.BackgroundTransparency = 1
Subtitle.Font = Enum.Font.GothamBold
Subtitle.TextColor3 = Color3.fromRGB(200, 200, 200)
Subtitle.TextSize = 16
Subtitle.ZIndex = 101

local ClickCatcher = Instance.new("TextButton", Overlay)
ClickCatcher.Size = UDim2.new(1, 0, 1, 0)
ClickCatcher.BackgroundTransparency = 1
ClickCatcher.Text = ""
ClickCatcher.ZIndex = 150
ClickCatcher.Active = true 

local isActive = false
local loopConnection = nil
local isPressing = false

-- Used specifically for mashing minigames
local clickCount = 0
local function RegisterMash()
	if isActive then clickCount += 1 end
end

ClickCatcher.MouseButton1Down:Connect(function()
	if isActive then isPressing = true; RegisterMash() end
end)
ClickCatcher.MouseButton1Up:Connect(function()
	if isActive then isPressing = false end
end)

-- Mobile Touch Support
ClickCatcher.InputBegan:Connect(function(input)
	if isActive and input.UserInputType == Enum.UserInputType.Touch then
		isPressing = true; RegisterMash()
	end
end)
ClickCatcher.InputEnded:Connect(function(input)
	if isActive and input.UserInputType == Enum.UserInputType.Touch then
		isPressing = false
	end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
	if isActive and not gpe then if input.KeyCode == Enum.KeyCode.Space then isPressing = true; RegisterMash() end end
end)
UserInputService.InputEnded:Connect(function(input, gpe)
	if input.KeyCode == Enum.KeyCode.Space then isPressing = false end
end)

local function StopMinigame(success, minigameType, extraData)
	isActive = false
	if loopConnection then loopConnection:Disconnect() end
	ScreenGui.Enabled = false

	local payload = { Success = success, MinigameType = minigameType }
	if extraData then
		for k, v in pairs(extraData) do payload[k] = v end
	end

	CombatAction:FireServer("MinigameResult", payload)
end

CombatUpdate.OnClientEvent:Connect(function(action, data)
	if action == "StartMinigame" then

		-- [[ THE FIX: FLAWLESS PERFECT CLASH MINIGAME ]]
		if data.MinigameType == "Clash" then
			ScreenGui.Enabled = true
			isActive = true
			clickCount = 0
			ClickCatcher.Visible = true

			if Overlay:FindFirstChild("ClashContainer") then Overlay.ClashContainer:Destroy() end

			local clashContainer = Instance.new("Frame", Overlay)
			clashContainer.Name = "ClashContainer"
			clashContainer.Size = UDim2.new(1, 0, 1, 0)
			clashContainer.BackgroundTransparency = 1
			clashContainer.ZIndex = 500

			Title.Text = "PERFECT CLASH!"
			Title.TextColor3 = Color3.fromRGB(255, 100, 100)
			Subtitle.Text = "Overpower the enemy! Rapidly tap or mash [SPACE]!"

			-- Tug of War Bar
			local BarBG = Instance.new("Frame", clashContainer)
			BarBG.Size = UDim2.new(0.6, 0, 0, 40)
			BarBG.Position = UDim2.new(0.5, 0, 0.5, 0)
			BarBG.AnchorPoint = Vector2.new(0.5, 0.5)
			BarBG.BackgroundColor3 = Color3.fromRGB(40, 10, 10)
			Instance.new("UICorner", BarBG).CornerRadius = UDim.new(0, 8)
			local bStroke = Instance.new("UIStroke", BarBG)
			bStroke.Color = Color3.fromRGB(150, 40, 40)
			bStroke.Thickness = 2

			local PlayerPower = Instance.new("Frame", BarBG)
			PlayerPower.Size = UDim2.new(0.5, 0, 1, 0)
			PlayerPower.BackgroundColor3 = Color3.fromRGB(85, 170, 255)
			Instance.new("UICorner", PlayerPower).CornerRadius = UDim.new(0, 8)

			local Indicator = Instance.new("Frame", PlayerPower)
			Indicator.Size = UDim2.new(0, 10, 1.5, 0)
			Indicator.Position = UDim2.new(1, 0, 0.5, 0)
			Indicator.AnchorPoint = Vector2.new(0.5, 0.5)
			Indicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)

			local VFXManager = require(script.Parent:WaitForChild("VFXManager"))
			if VFXManager then VFXManager.PlaySFX("Hover", 1.0) end

			local powerLevel = 0.4 -- Start slightly at a disadvantage
			local timeElapsed = 0
			local TIME_LIMIT = 5.0 -- Increased to 5 seconds
			local clickPower = 0.12 -- Tripled tap strength (12% per tap!)

			loopConnection = RunService.RenderStepped:Connect(function(dt)
				if not isActive then return end
				timeElapsed += dt

				-- Boss constantly pushes back
				powerLevel -= (0.15 * dt)

				-- Player pushes forward with mashing
				if clickCount > 0 then
					powerLevel += (clickCount * clickPower)
					clickCount = 0
					if VFXManager then VFXManager.PlaySFX("Click", 1.5) end
				end

				powerLevel = math.clamp(powerLevel, 0, 1)
				PlayerPower.Size = UDim2.new(powerLevel, 0, 1, 0)

				-- Aggressive Screen Shake effect on the UI bar
				local shakeX = math.random(-4, 4)
				local shakeY = math.random(-4, 4)
				BarBG.Position = UDim2.new(0.5, shakeX/800, 0.5, shakeY/600)

				-- [[ THE FIX: Check Victory FIRST to prevent timer tie bugs ]]
				if powerLevel >= 1 then
					isActive = false
					Title.Text = "ATTACK SHATTERED!"
					Title.TextColor3 = Color3.fromRGB(255, 215, 0)
					if VFXManager then 
						VFXManager.PlaySFX("HeavySlash", 1.2) 
						VFXManager.ScreenShake(1.5, 0.3)
					end
					task.wait(1.5)
					clashContainer:Destroy()
					StopMinigame(true, "Clash", { ClashSkill = data.ClashSkill, EnemySkill = data.EnemySkill })
					return
				end

				-- Defeat (Pushed to 0 or Time Ran Out)
				if powerLevel <= 0 or timeElapsed >= TIME_LIMIT then
					isActive = false
					Title.Text = "OVERPOWERED!"
					Title.TextColor3 = Color3.fromRGB(255, 50, 50)
					if VFXManager then VFXManager.ScreenShake(1.0, 0.5) end
					task.wait(1.5)
					clashContainer:Destroy()
					StopMinigame(false, "Clash", { ClashSkill = data.ClashSkill, EnemySkill = data.EnemySkill })
					return
				end
			end)

		elseif data.MinigameType == "Balance" then
			ScreenGui.Enabled = true
			isActive = true
			isPressing = false
			ClickCatcher.Visible = true

			if Overlay:FindFirstChild("BalanceContainer") then Overlay.BalanceContainer:Destroy() end

			local balContainer = Instance.new("Frame", Overlay)
			balContainer.Name = "BalanceContainer"
			balContainer.Size = UDim2.new(1, 0, 1, 0)
			balContainer.BackgroundTransparency = 1
			balContainer.ZIndex = 500

			Title.Text = "ODM APTITUDE TEST"
			Title.TextColor3 = Color3.fromRGB(85, 170, 255)
			Subtitle.Text = "Balance your center of gravity! Hold [SPACE] or Tap to apply wire tension."

			local GaugeBG = Instance.new("Frame", balContainer)
			GaugeBG.Size = UDim2.new(0, 60, 0, 300)
			GaugeBG.Position = UDim2.new(0.5, -40, 0.5, 0)
			GaugeBG.AnchorPoint = Vector2.new(0.5, 0.5)
			GaugeBG.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
			Instance.new("UICorner", GaugeBG).CornerRadius = UDim.new(0, 10)
			local gStroke = Instance.new("UIStroke", GaugeBG)
			gStroke.Color = Color3.fromRGB(60, 60, 70)
			gStroke.Thickness = 2

			local SZ = Instance.new("Frame", GaugeBG)
			SZ.Size = UDim2.new(1, 0, 0.25, 0)
			SZ.Position = UDim2.new(0, 0, 0.375, 0)
			SZ.BackgroundColor3 = Color3.fromRGB(85, 170, 255)
			SZ.BackgroundTransparency = 0.6
			Instance.new("UICorner", SZ).CornerRadius = UDim.new(0, 8)
			local szStroke = Instance.new("UIStroke", SZ)
			szStroke.Color = Color3.fromRGB(85, 170, 255)
			szStroke.Thickness = 2

			local Reticle = Instance.new("Frame", GaugeBG)
			Reticle.Size = UDim2.new(1.4, 0, 0.05, 0)
			Reticle.AnchorPoint = Vector2.new(0.5, 0.5)
			Reticle.Position = UDim2.new(0.5, 0, 0.5, 0)
			Reticle.BackgroundColor3 = Color3.fromRGB(255, 85, 85)
			Instance.new("UICorner", Reticle).CornerRadius = UDim.new(0, 4)

			local ProgBG = Instance.new("Frame", balContainer)
			ProgBG.Size = UDim2.new(0, 30, 0, 300)
			ProgBG.Position = UDim2.new(0.5, 40, 0.5, 0)
			ProgBG.AnchorPoint = Vector2.new(0.5, 0.5)
			ProgBG.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
			Instance.new("UICorner", ProgBG).CornerRadius = UDim.new(0, 10)
			local pStroke = Instance.new("UIStroke", ProgBG)
			pStroke.Color = Color3.fromRGB(60, 60, 70)

			local ProgFill = Instance.new("Frame", ProgBG)
			ProgFill.Size = UDim2.new(1, 0, 0, 0)
			ProgFill.Position = UDim2.new(0, 0, 1, 0)
			ProgFill.AnchorPoint = Vector2.new(0, 1)
			ProgFill.BackgroundColor3 = Color3.fromRGB(85, 255, 85)
			Instance.new("UICorner", ProgFill).CornerRadius = UDim.new(0, 10)

			local position = 0.5
			local velocity = 0
			local progress = 0
			local timeElapsed = 0

			local PULL_DOWN = 3.5
			local PUSH_UP = -7.0
			local DAMPING = 0.90

			local VFXManager = require(script.Parent:WaitForChild("VFXManager"))
			if VFXManager then VFXManager.PlaySFX("Hover", 1.0) end

			loopConnection = RunService.RenderStepped:Connect(function(dt)
				if not isActive then return end
				timeElapsed += dt

				if timeElapsed >= 25 then 
					Title.Text = "APTITUDE FAILED!"
					Title.TextColor3 = Color3.fromRGB(255, 85, 85)
					isActive = false
					task.wait(1.5)
					balContainer:Destroy()
					StopMinigame(false, "Balance")
					return 
				end

				local szCenterOffset = math.sin(timeElapsed * 2.0) * 0.25 + math.sin(timeElapsed * 1.3) * 0.12
				local szPos = 0.375 + szCenterOffset
				SZ.Position = UDim2.new(0, 0, szPos, 0)

				if isPressing then velocity += PUSH_UP * dt else velocity += PULL_DOWN * dt end
				velocity *= DAMPING
				position = math.clamp(position + velocity * dt, 0, 1)
				if position <= 0 or position >= 1 then velocity = 0 end

				Reticle.Position = UDim2.new(0.5, 0, position, 0)

				local safeTop = szPos
				local safeBottom = szPos + 0.25

				if position >= safeTop and position <= safeBottom then
					Reticle.BackgroundColor3 = Color3.fromRGB(85, 255, 85)
					szStroke.Color = Color3.fromRGB(85, 255, 85)
					SZ.BackgroundColor3 = Color3.fromRGB(85, 255, 85)
					progress = math.clamp(progress + (dt / 3), 0, 1) 
				else
					Reticle.BackgroundColor3 = Color3.fromRGB(255, 85, 85)
					szStroke.Color = Color3.fromRGB(255, 85, 85)
					SZ.BackgroundColor3 = Color3.fromRGB(255, 85, 85)
					progress = math.clamp(progress - (dt / 4), 0, 1) 
				end

				ProgFill.Size = UDim2.new(1, 0, progress, 0)

				if progress >= 1 then
					if VFXManager then VFXManager.PlaySFX("Reveal", 1.0) end
					Title.Text = "APTITUDE PASSED!"
					Title.TextColor3 = Color3.fromRGB(85, 255, 85)
					isActive = false
					task.wait(1.5)
					balContainer:Destroy()
					StopMinigame(true, "Balance")
				end
			end)

		elseif data.MinigameType == "GapClose" then
			ScreenGui.Enabled = true
			isActive = true

			if Overlay:FindFirstChild("GapCloseContainer") then Overlay.GapCloseContainer:Destroy() end

			local gcContainer = Instance.new("Frame", Overlay)
			gcContainer.Name = "GapCloseContainer"
			gcContainer.Size = UDim2.new(1,0,1,0)
			gcContainer.BackgroundTransparency = 1
			gcContainer.ZIndex = 500

			Title.Text = "EVASIVE MANEUVER REQUIRED"
			Title.TextColor3 = Color3.fromRGB(255, 85, 85)
			Subtitle.Text = "Intercept the strike zones before they collapse!"

			ClickCatcher.Visible = false

			local targetsToHit = 3
			local hits = 0

			local VFXManager = require(script.Parent:WaitForChild("VFXManager"))

			local function SpawnTarget()
				if not isActive then return end

				local target = Instance.new("TextButton", gcContainer)
				target.Size = UDim2.new(0, 60, 0, 60)
				target.Position = UDim2.new(math.random(30, 70)/100, 0, math.random(30, 70)/100, 0)
				target.AnchorPoint = Vector2.new(0.5, 0.5)
				target.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
				target.Rotation = 45
				target.Text = ""
				target.ZIndex = 505
				target.AutoButtonColor = false

				local targetStroke = Instance.new("UIStroke", target)
				targetStroke.Color = Color3.fromRGB(255, 60, 60)
				targetStroke.Thickness = 2

				if VFXManager then VFXManager.PlaySFX("Hover", 1.2) end

				local icon = Instance.new("TextLabel", target)
				icon.Size = UDim2.new(1, 0, 1, 0)
				icon.BackgroundTransparency = 1
				icon.Rotation = -45 
				icon.Text = "!"
				icon.Font = Enum.Font.GothamBlack
				icon.TextColor3 = Color3.fromRGB(255, 60, 60)
				icon.TextSize = 28
				icon.ZIndex = 506

				local shrinker = Instance.new("Frame", target)
				shrinker.AnchorPoint = Vector2.new(0.5, 0.5)
				shrinker.Position = UDim2.new(0.5, 0, 0.5, 0)
				shrinker.Size = UDim2.new(2.5, 0, 2.5, 0)
				shrinker.BackgroundTransparency = 1
				shrinker.ZIndex = 506
				local shStroke = Instance.new("UIStroke", shrinker)
				shStroke.Color = Color3.fromRGB(255, 60, 60)
				shStroke.Thickness = 2

				local tInfo = TweenInfo.new(1.0, Enum.EasingStyle.Linear)
				local t = TweenService:Create(shrinker, tInfo, {Size = UDim2.new(1, 0, 1, 0)})
				t:Play()

				local clicked = false

				local function OnHit()
					if clicked or not isActive then return end
					clicked = true; hits += 1

					if VFXManager then VFXManager.PlaySFX("LightSlash", 1.2) end

					targetStroke.Color = Color3.fromRGB(255, 215, 0)
					icon.TextColor3 = Color3.fromRGB(255, 215, 0)
					icon.Text = "✓"
					shStroke.Transparency = 1

					local shatter = TweenService:Create(target, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 90, 0, 90), BackgroundTransparency = 1})
					local iconFade = TweenService:Create(icon, TweenInfo.new(0.2), {TextTransparency = 1})
					local strokeFade = TweenService:Create(targetStroke, TweenInfo.new(0.2), {Transparency = 1})

					shatter:Play(); iconFade:Play(); strokeFade:Play()

					task.wait(0.2); target:Destroy()

					if hits >= targetsToHit then
						Title.Text = "EVASION SUCCESSFUL!"
						Title.TextColor3 = Color3.fromRGB(50, 255, 50)
						task.wait(1)
						gcContainer:Destroy()
						Title.TextColor3 = Color3.fromRGB(255, 215, 100)
						isActive = false
						ScreenGui.Enabled = false
						CombatAction:FireServer("MinigameResult", { Success = true, MinigameType = "GapClose" })
					else
						SpawnTarget()
					end
				end

				target.MouseButton1Down:Connect(OnHit)
				target.TouchTap:Connect(OnHit)

				t.Completed:Connect(function()
					if not clicked and isActive then
						isActive = false
						if VFXManager then 
							VFXManager.PlaySFX("HeavySlash", 1.0) 
							VFXManager.ScreenShake(0.5, 0.2)
						end

						targetStroke.Color = Color3.fromRGB(100, 100, 100)
						icon.TextColor3 = Color3.fromRGB(100, 100, 100)
						icon.Text = "X"

						Title.Text = "EVASION FAILED!"
						Title.TextColor3 = Color3.fromRGB(255, 50, 50)
						task.wait(1)
						gcContainer:Destroy()
						Title.TextColor3 = Color3.fromRGB(255, 215, 100)
						ScreenGui.Enabled = false
						CombatAction:FireServer("MinigameResult", { Success = false, MinigameType = "GapClose" })
					end
				end)
			end

			SpawnTarget()

		elseif data.MinigameType == "RegimentChoice" then
			StopMinigame(true)
		end
	end
end)