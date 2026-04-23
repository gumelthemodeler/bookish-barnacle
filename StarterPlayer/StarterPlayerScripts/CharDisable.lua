-- @ScriptType: LocalScript
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

task.spawn(function()
	local success = false
	while not success do
		success = pcall(function()
			StarterGui:SetCore("ResetButtonCallback", false)
		end)
		task.wait(0.1)
	end
end)

local function OnCharacterAdded(character)
end

if player.Character then
	OnCharacterAdded(player.Character)
end
player.CharacterAdded:Connect(OnCharacterAdded)