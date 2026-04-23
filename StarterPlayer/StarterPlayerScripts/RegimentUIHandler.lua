-- @ScriptType: LocalScript
-- @ScriptType: LocalScript
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Network = ReplicatedStorage:WaitForChild("Network")
local RegimentData = require(ReplicatedStorage:WaitForChild("RegimentData"))
local CombatAction = Network:WaitForChild("CombatAction")

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")

Network:WaitForChild("CombatUpdate").OnClientEvent:Connect(function(action, data)
	if action == "StartMinigame" and data.MinigameType == "RegimentChoice" then

		-- [[ THE FIX: Auto-skip the minigame if the player already has a regiment! ]]
		local currentReg = player:GetAttribute("Regiment") or "Cadet Corps"
		if currentReg ~= "Cadet Corps" then
			-- Instantly complete the wave for them
			CombatAction:FireServer("MinigameResult", { Success = true })
			return
		end

		if PlayerGui:FindFirstChild("RegimentSelectionGUI") then return end

		local ScreenGui = Instance.new("ScreenGui", PlayerGui)
		ScreenGui.Name = "RegimentSelectionGUI"
		ScreenGui.DisplayOrder = 99999 
		ScreenGui.ResetOnSpawn = false

		-- Darken the background completely
		local Overlay = Instance.new("Frame", ScreenGui)
		Overlay.Size = UDim2.new(1, 0, 1, 0)
		Overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		Overlay.BackgroundTransparency = 0.1
		Overlay.Active = true 

		-- Main Popup Container
		local MainFrame = Instance.new("Frame", Overlay)
		MainFrame.Size = UDim2.new(0, 700, 0, 450)
		MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
		MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
		Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)
		Instance.new("UIStroke", MainFrame).Color = Color3.fromRGB(120, 100, 60)

		local Title = Instance.new("TextLabel", MainFrame)
		Title.Size = UDim2.new(1, 0, 0, 60)
		Title.BackgroundTransparency = 1
		Title.Font = Enum.Font.GothamBlack
		Title.TextColor3 = Color3.fromRGB(255, 215, 100)
		Title.TextSize = 28
		Title.Text = "CHOOSE YOUR REGIMENT"

		local Subtitle = Instance.new("TextLabel", MainFrame)
		Subtitle.Size = UDim2.new(1, 0, 0, 30)
		Subtitle.Position = UDim2.new(0, 0, 0, 50)
		Subtitle.BackgroundTransparency = 1
		Subtitle.Font = Enum.Font.GothamBold
		Subtitle.TextColor3 = Color3.fromRGB(200, 200, 200)
		Subtitle.TextSize = 16
		Subtitle.Text = "Your training is complete. Where will you serve?"

		local OptionsFrame = Instance.new("Frame", MainFrame)
		OptionsFrame.Size = UDim2.new(1, 0, 0, 300)
		OptionsFrame.Position = UDim2.new(0, 0, 0, 100)
		OptionsFrame.BackgroundTransparency = 1

		local listLayout = Instance.new("UIListLayout", OptionsFrame)
		listLayout.FillDirection = Enum.FillDirection.Horizontal
		listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		listLayout.Padding = UDim.new(0, 20)

		local RegimentsToPick = {"Garrison", "Military Police", "Scout Regiment"}

		for _, regName in ipairs(RegimentsToPick) do
			local dataReg = RegimentData.Regiments[regName]
			if not dataReg then continue end

			local Card = Instance.new("Frame", OptionsFrame)
			Card.Size = UDim2.new(0, 200, 0, 280)
			Card.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
			Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 8)
			local stroke = Instance.new("UIStroke", Card)
			stroke.Color = Color3.fromRGB(60, 60, 70)

			local Icon = Instance.new("ImageLabel", Card)
			Icon.Size = UDim2.new(0, 100, 0, 100)
			Icon.Position = UDim2.new(0.5, 0, 0.05, 0)
			Icon.AnchorPoint = Vector2.new(0.5, 0)
			Icon.BackgroundTransparency = 1
			Icon.Image = dataReg.Icon

			local NameLbl = Instance.new("TextLabel", Card)
			NameLbl.Size = UDim2.new(1, 0, 0, 30)
			NameLbl.Position = UDim2.new(0, 0, 0.45, 0)
			NameLbl.BackgroundTransparency = 1
			NameLbl.Font = Enum.Font.GothamBlack
			NameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
			NameLbl.TextSize = 18
			NameLbl.Text = regName

			local BuffLbl = Instance.new("TextLabel", Card)
			BuffLbl.Size = UDim2.new(0.9, 0, 0, 40)
			BuffLbl.Position = UDim2.new(0.05, 0, 0.6, 0)
			BuffLbl.BackgroundTransparency = 1
			BuffLbl.Font = Enum.Font.GothamBold
			BuffLbl.TextColor3 = Color3.fromRGB(100, 255, 100)
			BuffLbl.TextSize = 14
			BuffLbl.TextWrapped = true
			BuffLbl.Text = "Bonus:\n" .. dataReg.Buff

			local JoinBtn = Instance.new("TextButton", Card)
			JoinBtn.Size = UDim2.new(0.8, 0, 0, 40)
			JoinBtn.Position = UDim2.new(0.1, 0, 0.8, 0)
			JoinBtn.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
			JoinBtn.Font = Enum.Font.GothamBlack
			JoinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			JoinBtn.TextSize = 16
			JoinBtn.Text = "JOIN"
			Instance.new("UICorner", JoinBtn).CornerRadius = UDim.new(0, 4)

			JoinBtn.MouseEnter:Connect(function() stroke.Color = Color3.fromRGB(120, 100, 60); stroke.Thickness = 2 end)
			JoinBtn.MouseLeave:Connect(function() stroke.Color = Color3.fromRGB(60, 60, 70); stroke.Thickness = 1 end)

			JoinBtn.MouseButton1Click:Connect(function()
				Network.JoinRegiment:FireServer(regName)
				ScreenGui:Destroy()

				-- Tell the server we completed the "Minigame" (Regiment Choice) successfully!
				CombatAction:FireServer("MinigameResult", { Success = true })

				local notif = Network:FindFirstChild("NotificationEvent")
				if notif then notif:FireClient(player, "You have joined the " .. regName .. "!", "Success") end
			end)
		end

		MainFrame.Scale = UDim2.new(0,0,0,0)
		TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = UDim2.new(1,0,1,0)}):Play()
	end
end)