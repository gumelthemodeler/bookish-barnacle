-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
-- Name: UIAuraManager
local UIAuraManager = {}

local RunService = game:GetService("RunService")

local activeConnection = nil
local activeParticles = {}
local ambientGlow = nil
local activeStroke = nil
local originalStrokeColor = nil

local PARTICLE_TEXTURES = {
	{ Image = "rbxassetid://101919176010049", Type = "Static" }, 
	{ Image = "rbxassetid://116532017229569", Type = "Static" }, 
	{ Image = "rbxassetid://91391658964497", Type = "Static" },  
	{ Image = "rbxassetid://14364658838", Type = "Static" },     
	{ Image = "rbxassetid://893043860", Type = "Static" },       
	{ 
		Image = "rbxassetid://17863940342", 
		Type = "Animated", 
		Cols = 8, 
		Rows = 8, 
		Frames = 64, 
		FPS = 45, 
		ImgSize = 1024 
	}
}

function UIAuraManager.ApplyAura(container, auraData, strokeContainer)
	UIAuraManager.ClearAura()
	if not auraData or auraData.Name == "None" then return end

	local c1 = Color3.fromHex((auraData.Color1 or "#FFFFFF"):gsub("#", ""))
	local c2 = Color3.fromHex((auraData.Color2 or "#FFFFFF"):gsub("#", ""))

	local target = strokeContainer or container
	activeStroke = target:FindFirstChildOfClass("UIStroke")
	if activeStroke then
		originalStrokeColor = activeStroke.Color
		activeStroke.Color = c1
	end

	ambientGlow = Instance.new("ImageLabel", container)
	ambientGlow.Size = UDim2.new(1.2, 0, 1.2, 0)
	ambientGlow.Position = UDim2.new(0.5, 0, 0.5, 0)
	ambientGlow.AnchorPoint = Vector2.new(0.5, 0.5)
	ambientGlow.BackgroundTransparency = 1
	ambientGlow.Image = "rbxassetid://2001828033" -- Soft radial gradient
	ambientGlow.ImageColor3 = c1
	ambientGlow.ImageTransparency = 0.2
	ambientGlow.ZIndex = 1
	local corner = Instance.new("UICorner", ambientGlow)
	corner.CornerRadius = UDim.new(1, 0)

	local rot = 0
	local lastSpawn = 0
	local timeElapsed = 0

	activeConnection = RunService.RenderStepped:Connect(function(dt)
		timeElapsed = timeElapsed + dt
		rot = (rot + dt * 45) % 360
		if ambientGlow then ambientGlow.Rotation = rot end

		if activeStroke then
			local pulse = (math.sin(timeElapsed * 3) + 1) / 2
			activeStroke.Color = c1:Lerp(c2, pulse)
		end

		local now = tick()
		if now - lastSpawn > 0.05 then
			lastSpawn = now

			local p = Instance.new("ImageLabel", container)
			p.BackgroundTransparency = 1
			p.ImageColor3 = math.random() > 0.5 and c1 or c2
			p.ZIndex = 2

			local texData = PARTICLE_TEXTURES[math.random(1, #PARTICLE_TEXTURES)]
			p.Image = texData.Image

			if texData.Type == "Animated" then
				local fw = texData.ImgSize / texData.Cols
				local fh = texData.ImgSize / texData.Rows
				p.ImageRectSize = Vector2.new(fw, fh)
				p.ImageRectOffset = Vector2.new(0, 0)
			end

			-- Spawn particles around the circular edge using trigonometry
			local angle = math.rad(math.random(0, 360))
			local radius = 0.5 -- 50% of parent container size
			local px = 0.5 + (math.cos(angle) * radius)
			local py = 0.5 + (math.sin(angle) * radius)

			p.Position = UDim2.new(px, 0, py, 0)
			p.AnchorPoint = Vector2.new(0.5, 0.5)

			local size = math.random(15, 35)
			p.Size = UDim2.new(0, size, 0, size)

			table.insert(activeParticles, {
				el = p,
				life = 1.2,
				maxLife = 1.2,
				vx = (math.cos(angle) * 0.05) + ((math.random() - 0.5) * 0.05), -- Drift outward
				vy = (math.sin(angle) * 0.05) + ((math.random() - 0.5) * 0.05),
				rot = math.random(-60, 60),
				isAnimated = texData.Type == "Animated",
				texData = texData,
				currentFrame = 0,
				timeAccumulator = 0
			})
		end

		for i = #activeParticles, 1, -1 do
			local pd = activeParticles[i]
			pd.life = pd.life - dt

			if pd.life <= 0 then
				if pd.el then pd.el:Destroy() end
				table.remove(activeParticles, i)
			else
				local prog = 1 - (pd.life / pd.maxLife)
				pd.el.Position = pd.el.Position + UDim2.new(pd.vx * dt, 0, pd.vy * dt, 0)
				pd.el.Rotation = pd.el.Rotation + (pd.rot * dt)
				pd.el.ImageTransparency = prog

				if pd.isAnimated then
					pd.timeAccumulator = pd.timeAccumulator + dt
					local frameTime = 1 / pd.texData.FPS

					if pd.timeAccumulator >= frameTime then
						pd.timeAccumulator = pd.timeAccumulator % frameTime
						pd.currentFrame = (pd.currentFrame + 1) % pd.texData.Frames

						local col = pd.currentFrame % pd.texData.Cols
						local row = math.floor(pd.currentFrame / pd.texData.Cols)
						local fw = pd.texData.ImgSize / pd.texData.Cols
						local fh = pd.texData.ImgSize / pd.texData.Rows

						pd.el.ImageRectOffset = Vector2.new(col * fw, row * fh)
					end
				end
			end
		end
	end)
end

function UIAuraManager.ClearAura()
	if activeConnection then activeConnection:Disconnect(); activeConnection = nil end
	if ambientGlow then ambientGlow:Destroy(); ambientGlow = nil end

	if activeStroke and originalStrokeColor then
		activeStroke.Color = originalStrokeColor
		activeStroke = nil
		originalStrokeColor = nil
	end

	for _, p in ipairs(activeParticles) do if p.el then p.el:Destroy() end end
	activeParticles = {}
end

return UIAuraManager