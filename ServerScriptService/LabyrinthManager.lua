-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
-- Name: LabyrinthManager
local LabyrinthManager = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = ReplicatedStorage:WaitForChild("Network")

local labEvent = game:GetService("ServerStorage"):FindFirstChild("LabyrinthEncounter")
if not labEvent then
	labEvent = Instance.new("BindableEvent")
	labEvent.Name = "LabyrinthEncounter"
	labEvent.Parent = game:GetService("ServerStorage")
end

-- GRID LEGEND
-- -1 = Void/Wall, 0 = Empty Path, 1 = Enemy (Red), 2 = Loot Cache (Green), 3 = Exit (White), 4 = Visited (Faded), 5 = Player (Blue)

local ActiveSessions = {}

local function GenerateCaverns(floorLevel)
	local size = math.clamp(14 + math.floor(floorLevel), 15, 30) 
	local grid = {}
	for y = 1, size do
		grid[y] = {}
		for x = 1, size do grid[y][x] = -1 end
	end

	local startX, startY = math.floor(size/2), math.floor(size/2)
	local rooms = {}
	local pathHistory = {}
	local pathSet = {}

	local function Carve(x, y, val)
		if grid[y][x] == -1 then
			grid[y][x] = val
			if not pathSet[y.."_"..x] then
				table.insert(pathHistory, {x=x, y=y})
				pathSet[y.."_"..x] = true
			end
		end
	end

	local function CarveCluster(cx, cy)
		for dy = -1, 1 do
			for dx = -1, 1 do
				local nx, ny = cx + dx, cy + dy
				if nx > 1 and nx < size and ny > 1 and ny < size then
					if math.abs(dx) == 1 and math.abs(dy) == 1 and math.random(1, 100) > 70 then continue end
					Carve(nx, ny, 0)
				end
			end
		end
	end

	CarveCluster(startX, startY)
	table.insert(rooms, {x=startX, y=startY})

	local numBranches = math.clamp(8 + (floorLevel * 2), 10, 35)
	local directions = {{0,-1}, {0,1}, {-1,0}, {1,0}}

	for i = 1, numBranches do
		local startRoom = rooms[math.random(1, #rooms)]
		local dir = directions[math.random(1, 4)]
		local tunnelLen = math.random(4, 8) 

		local cx, cy = startRoom.x, startRoom.y
		local hitWall = false
		local tunnelPoints = {}

		for step = 1, tunnelLen do
			cx, cy = cx + dir[1], cy + dir[2]
			if cx > 2 and cx < size-1 and cy > 2 and cy < size-1 then
				table.insert(tunnelPoints, {x=cx, y=cy})
			else
				hitWall = true
				break
			end
		end

		if not hitWall or #tunnelPoints > 2 then
			for _, pt in ipairs(tunnelPoints) do Carve(pt.x, pt.y, 0) end
			CarveCluster(cx, cy)
			table.insert(rooms, {x=cx, y=cy})
		end
	end

	local exitRoom = rooms[1]
	local maxDist = 0
	for _, r in ipairs(rooms) do
		local d = math.abs(r.x - startX) + math.abs(r.y - startY)
		if d > maxDist then maxDist = d; exitRoom = r end
	end
	grid[exitRoom.y][exitRoom.x] = 3 
	grid[startY][startX] = 5 

	local baseEnemyChance = math.clamp(12 + (floorLevel * 3), 12, 60)

	for _, pt in ipairs(pathHistory) do
		if grid[pt.y][pt.x] == 0 then
			if pt.x == startX and pt.y == startY then continue end
			if pt.x == exitRoom.x and pt.y == exitRoom.y then continue end

			local isRoomCenter = false
			for _, r in ipairs(rooms) do
				if r.x == pt.x and r.y == pt.y then isRoomCenter = true; break end
			end

			if isRoomCenter then
				if math.random(1, 100) <= 40 then grid[pt.y][pt.x] = 2
				elseif math.random(1, 100) <= 50 then grid[pt.y][pt.x] = 1 end
			else
				if math.random(1, 100) <= baseEnemyChance then grid[pt.y][pt.x] = 1 
				elseif math.random(1, 100) <= 4 then grid[pt.y][pt.x] = 2 end
			end
		end
	end

	return grid, size, startX, startY
end

function LabyrinthManager.StartSession(player, carriedLoot)
	local currentFloor = player:GetAttribute("LabyrinthFloor") or 1
	local grid, size, sX, sY = GenerateCaverns(currentFloor)

	ActiveSessions[player.UserId] = {
		Grid = grid,
		Size = size,
		Floor = currentFloor,
		PlayerX = sX,
		PlayerY = sY,
		InCombat = false,
		AccumulatedLoot = carriedLoot or { Dews = 0, XP = 0, Items = {} } -- [[ THE FIX: Carries loot over ]]
	}

	-- [[ THE FIX: Forces the UI to rebuild the grid to prevent invisible enemies ]]
	Network.LabyrinthUpdate:FireClient(player, "InitSync", ActiveSessions[player.UserId])
end

function LabyrinthManager.OnCombatWin(player)
	local session = ActiveSessions[player.UserId]
	if not session then return end

	session.InCombat = false
	session.Grid[session.PlayerY][session.PlayerX] = 5 

	Network.LabyrinthUpdate:FireClient(player, "Sync", session)
end

function LabyrinthManager.OnCombatLoss(player)
	ActiveSessions[player.UserId] = nil
	player:SetAttribute("LabyrinthFloor", 1) 
	Network.LabyrinthUpdate:FireClient(player, "Death")
end

Network:WaitForChild("LabyrinthAction").OnServerEvent:Connect(function(player, action, tX, tY)
	local session = ActiveSessions[player.UserId]

	if action == "Init" then
		LabyrinthManager.StartSession(player)
		return
	end

	if not session or session.InCombat then return end

	if action == "Move" then
		local px, py = session.PlayerX, session.PlayerY

		if ((math.abs(px - tX) == 1 and py == tY) or (math.abs(py - tY) == 1 and px == tX)) and session.Grid[tY][tX] ~= -1 then
			local nextCell = session.Grid[tY][tX]

			session.Grid[py][px] = 4 
			session.PlayerX = tX
			session.PlayerY = tY

			if nextCell == 1 then
				session.InCombat = true
				session.Grid[tY][tX] = 5

				Network.LabyrinthUpdate:FireClient(player, "CombatStart")
				task.wait(0.8)
				labEvent:Fire(player, session.Floor) 
				return 

			elseif nextCell == 2 then
				session.Grid[tY][tX] = 5
				local dewGain = math.random(5000, 15000) * session.Floor
				local xpGain = math.random(1500, 4500) * session.Floor
				session.AccumulatedLoot.Dews += dewGain
				session.AccumulatedLoot.XP += xpGain

				local possibleLoot = {"Iron Bamboo Heart", "Glowing Titan Crystal", "Titan Hardening Extract", "Standard Titan Serum", "Clan Blood Vial"}
				local foundItem = nil
				if math.random(1, 100) <= 40 + (session.Floor * 2) then
					foundItem = possibleLoot[math.random(1, #possibleLoot)]
					session.AccumulatedLoot.Items[foundItem] = (session.AccumulatedLoot.Items[foundItem] or 0) + 1
				end

				local msg = "Pouch Updated! +" .. dewGain .. " Dews"
				if foundItem then msg = msg .. ", +1 " .. foundItem end

				Network.NotificationEvent:FireClient(player, msg, "Success")

			elseif nextCell == 3 then
				session.Grid[tY][tX] = 5
				Network.LabyrinthUpdate:FireClient(player, "ReachedExit", session)
				return
			else
				session.Grid[tY][tX] = 5
			end

			Network.LabyrinthUpdate:FireClient(player, "Sync", session)
		end

	elseif action == "Extract" then
		player.leaderstats.Dews.Value += session.AccumulatedLoot.Dews
		player:SetAttribute("XP", (player:GetAttribute("XP") or 0) + session.AccumulatedLoot.XP)

		for itemName, amount in pairs(session.AccumulatedLoot.Items) do
			local safeName = itemName:gsub("[^%w]", "") .. "Count"
			player:SetAttribute(safeName, (player:GetAttribute(safeName) or 0) + amount)
		end

		Network.NotificationEvent:FireClient(player, "Escaped! Secured your Labyrinth Pouch.", "Success")
		ActiveSessions[player.UserId] = nil
		player:SetAttribute("LabyrinthFloor", 1)

	elseif action == "NextFloor" then
		player:SetAttribute("LabyrinthFloor", session.Floor + 1)
		-- [[ THE FIX: Passes the current pouch to the next floor ]]
		LabyrinthManager.StartSession(player, session.AccumulatedLoot)

	elseif action == "Abandon" then
		ActiveSessions[player.UserId] = nil
		player:SetAttribute("LabyrinthFloor", 1)
	end
end)

return LabyrinthManager