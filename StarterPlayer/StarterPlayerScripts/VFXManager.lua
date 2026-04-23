-- @ScriptType: ModuleScript
-- Name: VFXManager
-- @ScriptType: ModuleScript
local VFXManager = {}
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SkillData = require(ReplicatedStorage:WaitForChild("SkillData"))

local player = Players.LocalPlayer

local SFX_Folder = Instance.new("Folder")
SFX_Folder.Name = "CombatSFX"
SFX_Folder.Parent = SoundService

local Sounds = {
	["Click"] = "rbxassetid://140014208317483",
	["Hover"] = "rbxassetid://139719503904449",
	["Spin"] = "rbxassetid://127540863015179",
	["Reveal"] = "rbxassetid://104876050679091",

	["Victory"] = "rbxassetid://138958112968012",
	["Defeat"] = "rbxassetid://124891595124000",

	["LightSlash"] = "rbxassetid://139784419320747",
	["HeavySlash"] = "rbxassetid://70533036001783",
	["DualSlash"] = "rbxassetid://76261209962997",
	["SpinSlash"] = "rbxassetid://140492871204586",
	["Dash"] = "rbxassetid://139994035606058",
	["Grapple"] = "rbxassetid://133133322043256",

	["Gun"] = "rbxassetid://133090030932031",
	["Sniper"] = "rbxassetid://138854039966754",
	["Explosion"] = "rbxassetid://139651066813230",
	["BigExplosion"] = "rbxassetid://122442809872053",

	["Punch"] = "rbxassetid://139897497838184",
	["HeavyPunch"] = "rbxassetid://132950051811085",
	["Kick"] = "rbxassetid://139119371910120",
	["Stomp"] = "rbxassetid://90835276918763",
	["Bite"] = "rbxassetid://133560890939895",

	["Roar"] = "rbxassetid://7182253058",
	["Steam"] = "rbxassetid://7768888198",
	["Transform"] = "rbxassetid://18563476365",
	["Spike"] = "rbxassetid://138724252311982",

	["Block"] = "rbxassetid://136811265205147",
	["Heal"] = "rbxassetid://140272163846580",
	["Flee"] = "rbxassetid://140650484582271"
}

local Images = {
	["SlashMark"] = "rbxassetid://132110695428038",
	["ClawMark"] = "rbxassetid://8175147837",
	["ExplosionMark"] = "rbxassetid://11271602299",
	["HealMark"] = "rbxassetid://95346239470518",
	["BlockMark"] = "rbxassetid://71309430456016",
	["Blood"] = "rbxassetid://16910627138"
}

function VFXManager.Initialize()
	for name, id in pairs(Sounds) do
		local s = Instance.new("Sound")
		s.Name = name; s.SoundId = id
		s.Volume = (name == "Hover") and 0.15 or 0.5 
		s.Parent = SFX_Folder
	end

	local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local function hookButton(btn)
		if btn:IsA("TextButton") or btn:IsA("ImageButton") then
			if not btn:GetAttribute("HasAudioHook") then
				btn:SetAttribute("HasAudioHook", true)
				btn.MouseEnter:Connect(function() VFXManager.PlaySFX("Hover", 1.0) end)
				btn.MouseButton1Click:Connect(function() VFXManager.PlaySFX("Click", 1.0) end)
			end
		end
	end

	for _, child in ipairs(PlayerGui:GetDescendants()) do hookButton(child) end
	PlayerGui.DescendantAdded:Connect(hookButton)

	local Network = ReplicatedStorage:WaitForChild("Network")
	local PlayVFX = Network:FindFirstChild("PlayVFX") or Instance.new("RemoteEvent", Network)
	PlayVFX.OnClientEvent:Connect(function(vfxType, targetType)
		if vfxType == "TitanRoar" then
			VFXManager.PlaySFX("Roar", math.random(80, 100)/100)
			VFXManager.ScreenShake(0.8, 1.0)
		elseif vfxType == "Heal" then
			VFXManager.PlaySFX("Heal", 1.0)
		end
	end)
end

function VFXManager.PlaySFX(sfxName, pitchMod)
	local s = SFX_Folder:FindFirstChild(sfxName)
	if s then
		local clone = s:Clone()
		local actualPitch = pitchMod or (1 + math.random(-10, 10)/100)
		clone.PlaybackSpeed = actualPitch
		clone.Parent = SFX_Folder

		if sfxName == "Victory" or sfxName == "Defeat" then
			local pausedTracks = {}

			for _, audio in ipairs(SoundService:GetDescendants()) do
				if audio:IsA("Sound") and audio.IsPlaying and audio.Parent ~= SFX_Folder then
					table.insert(pausedTracks, {Track = audio, OrigVol = audio.Volume})
					audio:Pause()
				end
			end

			for _, audio in ipairs(workspace:GetDescendants()) do
				if audio:IsA("Sound") and audio.IsPlaying then
					table.insert(pausedTracks, {Track = audio, OrigVol = audio.Volume})
					audio:Pause()
				end
			end

			clone.Ended:Connect(function()
				for _, data in ipairs(pausedTracks) do
					local audio = data.Track
					if audio and audio.Parent then 
						if not audio.IsPlaying and audio.TimePosition > 0 then
							audio.Volume = 0
							audio:Resume()

							-- Respect the settings volume when resuming tracks
							local restoreVol = data.OrigVol
							if player:GetAttribute("Setting_Music") == false then restoreVol = 0 end

							TweenService:Create(audio, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Volume = restoreVol}):Play()
						end
					end
				end
			end)

			game.Debris:AddItem(clone, 10)
		else
			game.Debris:AddItem(clone, 3)
		end

		clone:Play()

		local baseLength = (s.TimeLength and s.TimeLength > 0.05) and s.TimeLength or 0.2
		return baseLength / actualPitch
	end

	return 0.15 
end

function VFXManager.PlayVFX(vfxName, targetFrame, customColor, isBlood)
	local imgId = Images[vfxName]
	if not imgId or not targetFrame then return end

	local vfx = Instance.new("ImageLabel")
	vfx.BackgroundTransparency = 1; vfx.Image = imgId; vfx.ImageColor3 = customColor or Color3.fromRGB(255, 255, 255)

	local randX = math.random(20, 80) / 100
	local randY = math.random(20, 80) / 100
	vfx.Position = UDim2.new(randX, 0, randY, 0); vfx.AnchorPoint = Vector2.new(0.5, 0.5)
	vfx.Parent = targetFrame

	if isBlood then
		vfx.Size = UDim2.new(0, 0, 0, 0); vfx.Rotation = math.random(-180, 180); vfx.ZIndex = 49
		local tweenIn = TweenService:Create(vfx, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1.2, 0, 1.2, 0)})
		tweenIn:Play()

		task.delay(0.15, function()
			local tweenOut = TweenService:Create(vfx, TweenInfo.new(0.2, Enum.EasingStyle.Linear), {ImageTransparency = 1})
			tweenOut:Play()
			game.Debris:AddItem(vfx, 0.25)
		end)
	else
		vfx.Size = UDim2.new(1.8, 0, 1.8, 0); vfx.Rotation = math.random(-60, 60); vfx.ZIndex = 50; vfx.ImageTransparency = 0.3
		local tweenIn = TweenService:Create(vfx, TweenInfo.new(0.05, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = UDim2.new(1.0, 0, 1.0, 0), ImageTransparency = 0})
		tweenIn:Play()

		task.delay(0.08, function()
			local tweenOut = TweenService:Create(vfx, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0.5, 0, 0.5, 0), ImageTransparency = 1})
			tweenOut:Play()
			game.Debris:AddItem(vfx, 0.15)
		end)
	end
end

function VFXManager.ScreenShake(intensity, duration)
	-- Disable shake entirely if player has screen flashes turned off
	if player:GetAttribute("Setting_ScreenFlash") == false then return end

	local Camera = workspace.CurrentCamera
	local startTime = os.clock()
	local originalCFrame = Camera.CFrame
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - startTime
		if elapsed < duration then
			local dampen = 1 - (elapsed / duration)
			local offset = Vector3.new(
				(math.random() - 0.5) * intensity * dampen,
				(math.random() - 0.5) * intensity * dampen,
				(math.random() - 0.5) * intensity * dampen
			)
			Camera.CFrame = originalCFrame * CFrame.new(offset)
		else
			Camera.CFrame = originalCFrame
			connection:Disconnect()
		end
	end)
end

function VFXManager.PlayCombatEffect(skillName, isPlayerAttacking, pAvatarBox, eAvatarBox, didHit)
	local skillInfo = SkillData.Skills[skillName]
	if not skillInfo then return end

	local targetBox = isPlayerAttacking and eAvatarBox or pAvatarBox
	local userBox = isPlayerAttacking and pAvatarBox or eAvatarBox

	if skillInfo.Effect == "Rest" or skillInfo.Effect == "TitanRest" or skillInfo.Effect == "Block" or skillInfo.Effect == "Transform" then
		targetBox = userBox
	end

	if not didHit and skillInfo.Type ~= "Basic" and skillInfo.Effect == "None" then
		VFXManager.PlaySFX("Dash", 1.2)
		VFXManager.PlayVFX("BlockMark", targetBox, Color3.fromRGB(200, 200, 200), false)
		return
	end

	local sName = skillInfo.SFX or "Punch"
	local vName = skillInfo.VFX or "SlashMark"

	local hitsToPlay = 1
	if didHit and skillInfo.Hits and skillInfo.Hits > 1 then
		hitsToPlay = skillInfo.Hits
	end

	task.spawn(function()
		for i = 1, hitsToPlay do
			local pitch = 1 + (math.random(-15, 15)/100)
			local audioDuration = VFXManager.PlaySFX(sName, pitch)

			VFXManager.PlayVFX(vName, targetBox, nil, false)

			if didHit and skillInfo.Effect ~= "Rest" and skillInfo.Effect ~= "Block" and skillInfo.Effect ~= "Transform" then
				VFXManager.PlayVFX("Blood", targetBox, Color3.fromRGB(150, 0, 0), true)
			end

			if i < hitsToPlay then
				local waitDelay = math.clamp(audioDuration * 0.9, 0.05, 0.4)
				task.wait(waitDelay) 
			end
		end
	end)
end

return VFXManager