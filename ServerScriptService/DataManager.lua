-- @ScriptType: Script
-- @ScriptType: Script
-- Name: DataManager
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local MessagingService = game:GetService("MessagingService") 

local BountyData = require(ReplicatedStorage:WaitForChild("BountyData"))
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))
local GameData = require(ReplicatedStorage:WaitForChild("GameData"))

local GameDataStore = DataStoreService:GetDataStore("AoT_Data_V6")
local BackupDataStore = DataStoreService:GetDataStore("AoT_Backups_V3")
local RegimentStore = DataStoreService:GetDataStore("RegimentWars_V4") 

local PrestigeLB = DataStoreService:GetOrderedDataStore("Global_Prestige_LB_V3")
local EloLB = DataStoreService:GetOrderedDataStore("Global_Elo_LB_V3")
local LBCache = { Prestige = {}, Elo = {} }

local Top5PrestigeCache = {}
local Top5EloCache = {}

local RemotesFolder = ReplicatedStorage:FindFirstChild("Network") or Instance.new("Folder", ReplicatedStorage)
RemotesFolder.Name = "Network"

local requiredRemotes = {
	"ToggleMute", "CombatAction", "CombatUpdate", "PrestigeEvent", "NotificationEvent", "DungeonUpdate", "WorldBossUpdate", "WorldBossAction", 
	"RaidAction", "RaidUpdate", "ToggleTraining", "ShopAction", "ShopUpdate", "UpgradeStat", "TrainAction", "EquipItem", "SellItem", "AutoSell", "AdminCommand",
	"GachaRoll", "GachaRollAuto", "GachaResult", "AwakenAction", "ManageStorage", "VIPFreeReroll", "RedeemCode", "ClaimBounty", "ForgeItem", "ConsumeItem", "JoinRegiment", "ShowRegimentUI",
	"FuseTitan", "PathsShopBuy", "AwakenWeapon", "DispatchAction", "TradeAction", "TradeUpdate", "TradeRequest", "DeployToDistrict", "EquipSkill",
	"PathsShopEvent", "UpgradeRune", "LabyrinthAction", "LabyrinthUpdate"
}

for _, remoteName in ipairs(requiredRemotes) do
	if not RemotesFolder:FindFirstChild(remoteName) then
		local re = Instance.new("RemoteEvent"); re.Name = remoteName; re.Parent = RemotesFolder
	end
end

if not RemotesFolder:FindFirstChild("GetShopData") then
	local rf = Instance.new("RemoteFunction"); rf.Name = "GetShopData"; rf.Parent = RemotesFolder
end

local lbRf = RemotesFolder:FindFirstChild("GetLeaderboardData")
if not lbRf then
	lbRf = Instance.new("RemoteFunction"); lbRf.Name = "GetLeaderboardData"; lbRf.Parent = RemotesFolder
end

local prestigeRf = RemotesFolder:FindFirstChild("PrestigeAction")
if not prestigeRf then
	prestigeRf = Instance.new("RemoteFunction"); prestigeRf.Name = "PrestigeAction"; prestigeRf.Parent = RemotesFolder
end

lbRf.OnServerInvoke = function(player, lbType)
	local cache = LBCache[lbType] or {}
	local dynamicList = {}

	for _, entry in ipairs(cache) do table.insert(dynamicList, {Name = entry.Name, Value = entry.Value}) end

	for _, p in ipairs(Players:GetPlayers()) do
		local ls = p:FindFirstChild("leaderstats")
		if ls then
			local liveVal = 0
			if lbType == "Prestige" and ls:FindFirstChild("Prestige") then liveVal = ls.Prestige.Value
			elseif lbType == "Elo" and ls:FindFirstChild("Elo") then liveVal = ls.Elo.Value end

			local found = false
			for _, entry in ipairs(dynamicList) do
				if entry.Name == p.Name then entry.Value = liveVal; found = true; break end
			end
			if not found and (lbType == "Elo" or liveVal > 0) then table.insert(dynamicList, {Name = p.Name, Value = liveVal}) end
		end
	end
	table.sort(dynamicList, function(a, b) return a.Value > b.Value end)
	local finalList = {}
	for i = 1, math.min(50, #dynamicList) do
		if lbType == "Elo" or dynamicList[i].Value > 0 then table.insert(finalList, {Rank = i, Name = dynamicList[i].Name, Value = dynamicList[i].Value}) end
	end
	return finalList
end

local DefaultData = { 
	Prestige = 0, CurrentPart = 1, CurrentMission = 1, CurrentWave = 1, XP = 0, TitanXP = 0, Dews = 0, Elo = 1000, 
	Titan = "None", FightingStyle = "None", Clan = "None", Regiment = "Cadet Corps", DeployedDistrict = "Trost District",
	TitanPity = 0, TitanMythicalPity = 0, ClanPity = 0, ClanMythicalPity = 0, 
	EquippedWeapon = "None", EquippedAccessory = "None", PathDust = 0, PathsFloor = 1, 
	EquippedSkill_1 = "Basic Slash", EquippedSkill_2 = "Heavy Slash", EquippedSkill_3 = "Maneuver", EquippedSkill_4 = "Recover",
	DispatchData = "{}", AllyLevels = "{}", UnlockedAllies = "", MaxDeployments = 2, 
	Health = GameData.BaseStats.Health or 10, Strength = GameData.BaseStats.Strength or 10, 
	Defense = GameData.BaseStats.Defense or 10, Speed = GameData.BaseStats.Speed or 10, 
	Gas = GameData.BaseStats.Stamina or 10, Resolve = GameData.BaseStats.Willpower or 10,
	MaxGas = GameData.BaseStats.Stamina or 10, MaxHealth = GameData.BaseStats.Health or 10,
	Titan_Power_Val = 10, Titan_Speed_Val = 10, Titan_Hardening_Val = 10, 
	Titan_Endurance_Val = 10, Titan_Precision_Val = 10, Titan_Potential_Val = 10,
	Setting_ScreenFlash = true, Setting_Music = true, Setting_AutoTrain = false, 
	LastFreeReroll = 0, RedeemedCodes = "", LoginStreak = 0, LastLoginDate = "", AutoTrainSessionTime = 0 
}

local CurrentVP = {
	Week = math.floor(os.time() / 604800),
	Districts = {
		["Trost District"] = { ["Scout Regiment"] = 0, ["Garrison"] = 0, ["Military Police"] = 0, Winner = "None" },
		["Stohess District"] = { ["Scout Regiment"] = 0, ["Garrison"] = 0, ["Military Police"] = 0, Winner = "None" },
		["Shiganshina"] = { ["Scout Regiment"] = 0, ["Garrison"] = 0, ["Military Police"] = 0, Winner = "None" },
		["Karanes District"] = { ["Scout Regiment"] = 0, ["Garrison"] = 0, ["Military Police"] = 0, Winner = "None" }
	}
}

local GetVpRf = Instance.new("RemoteFunction", RemotesFolder); GetVpRf.Name = "GetRegimentVP"
GetVpRf.OnServerInvoke = function() return CurrentVP end

pcall(function() 
	local data = RegimentStore:GetAsync("GlobalWarData_V4") 
	if data and data.Districts then CurrentVP = data end 
end)

local vpEvent = Instance.new("BindableEvent", game:GetService("ServerStorage")); vpEvent.Name = "AddRegimentVP"
vpEvent.Event:Connect(function(player, amount)
	local reg = player:GetAttribute("Regiment")
	local deployedTo = player:GetAttribute("DeployedDistrict") or "Trost District"
	if CurrentVP.Districts[deployedTo] and CurrentVP.Districts[deployedTo][reg] then 
		CurrentVP.Districts[deployedTo][reg] += amount 
	end
end)

RemotesFolder.DeployToDistrict.OnServerEvent:Connect(function(player, districtName)
	if CurrentVP.Districts[districtName] then
		player:SetAttribute("DeployedDistrict", districtName)
		RemotesFolder.NotificationEvent:FireClient(player, "Forces deployed to " .. districtName .. "!", "Success")
	end
end)

task.spawn(function()
	while true do
		local currentWeek = math.floor(os.time() / 604800)
		if currentWeek > CurrentVP.Week then
			for dName, dData in pairs(CurrentVP.Districts) do
				local winner = "None"; local highest = -1
				for reg, vp in pairs(dData) do 
					if reg ~= "Winner" and type(vp) == "number" and vp > highest then 
						highest = vp; winner = reg 
					end 
				end
				dData.Winner = winner
				dData["Scout Regiment"] = 0; dData["Garrison"] = 0; dData["Military Police"] = 0
			end
			CurrentVP.Week = currentWeek
			pcall(function() RegimentStore:SetAsync("GlobalWarData_V4", CurrentVP) end)
		end

		pcall(function()
			local pages = PrestigeLB:GetSortedAsync(false, 50)
			local data = pages:GetCurrentPage()
			local newCache = {}
			local top5Users = {}
			for rank, entry in ipairs(data) do
				local pName = "Unknown"
				pcall(function() pName = Players:GetNameFromUserIdAsync(tonumber(entry.key)) end)
				table.insert(newCache, {Rank = rank, Name = pName, Value = entry.value})
				if rank <= 5 then top5Users[tonumber(entry.key)] = true end
			end
			LBCache.Prestige = newCache
			Top5PrestigeCache = top5Users

			for _, p in ipairs(Players:GetPlayers()) do
				p:SetAttribute("Top5_Prestige", top5Users[p.UserId] or false)
			end
		end)
		task.wait(2)

		pcall(function()
			local pages = EloLB:GetSortedAsync(false, 50)
			local data = pages:GetCurrentPage()
			local newCache = {}
			local top5Users = {}
			for rank, entry in ipairs(data) do
				local pName = "Unknown"
				pcall(function() pName = Players:GetNameFromUserIdAsync(tonumber(entry.key)) end)
				table.insert(newCache, {Rank = rank, Name = pName, Value = entry.value})
				if rank <= 5 then top5Users[tonumber(entry.key)] = true end
			end
			LBCache.Elo = newCache
			Top5EloCache = top5Users

			for _, p in ipairs(Players:GetPlayers()) do
				p:SetAttribute("Top5_Elo", top5Users[p.UserId] or false)
			end
		end)
		task.wait(60)
	end
end)

RemotesFolder.ClaimBounty.OnServerEvent:Connect(function(player, bType)
	local claimedAttr = bType .. "_Claimed"
	if player:GetAttribute(claimedAttr) then return end
	if (player:GetAttribute(bType .. "_Prog") or 0) >= (player:GetAttribute(bType .. "_Max") or 1) then
		player:SetAttribute(claimedAttr, true)
		vpEvent:Fire(player, 25)

		if string.sub(bType, 1, 1) == "D" then
			local reward = player:GetAttribute(bType .. "_Reward") or 500
			player.leaderstats.Dews.Value += reward
		else
			local rType = player:GetAttribute(bType .. "_RewardType")
			local safeName = rType:gsub("[^%w]", "") .. "Count"
			player:SetAttribute(safeName, (player:GetAttribute(safeName) or 0) + (player:GetAttribute(bType .. "_RewardAmt") or 1))
		end
	end
end)

RemotesFolder.JoinRegiment.OnServerEvent:Connect(function(player, regName)
	local currentReg = player:GetAttribute("Regiment") or "Cadet Corps"
	if currentReg ~= "Cadet Corps" and currentReg ~= regName then
		if player.leaderstats.Dews.Value >= 50000 then
			player.leaderstats.Dews.Value -= 50000
		else
			RemotesFolder.NotificationEvent:FireClient(player, "Not enough Dews! Need 50,000 to swap.", "Error")
			return
		end
	end

	player:SetAttribute("Regiment", regName)
	RemotesFolder.NotificationEvent:FireClient(player, "You have pledged your life to the " .. regName .. "!", "Success")
end)

pcall(function()
	MessagingService:SubscribeAsync("GlobalDataRollback", function(message)
		for _, p in ipairs(Players:GetPlayers()) do
			local success, backup = pcall(function() return BackupDataStore:GetAsync("Backup_" .. p.UserId) end)
			if success and backup then
				pcall(function() GameDataStore:SetAsync(p.UserId, backup) end)
				p:Kick("SYSTEM ALARM: A Global Data Rollback has been initiated by Administrators. Your previous safe save has been restored. Please rejoin.")
			end
		end
	end)
end)

local SavePlayer 
local AdminManager = require(ReplicatedStorage:WaitForChild("AdminManager"))

RemotesFolder.AdminCommand.OnServerEvent:Connect(function(player, command, targetName, args)
	if not AdminManager.IsAdmin(player) then
		player:Kick("Unauthorized Admin Access")
		return
	end

	if command == "GlobalRollback" then
		pcall(function() MessagingService:PublishAsync("GlobalDataRollback", "Initiate") end)
		RemotesFolder.NotificationEvent:FireClient(player, "GLOBAL ROLLBACK INITIATED ACROSS ALL SERVERS.", "Success")
		return
	end

	if command == "GenerateRecovery" then
		local targetId = tonumber(targetName)
		if not targetId then for _, p in ipairs(Players:GetPlayers()) do if string.find(p.Name:lower(), "^" .. targetName:lower()) then targetId = p.UserId; break end end end
		if targetId then
			local success, backupData = pcall(function() return BackupDataStore:GetAsync("Backup_" .. targetId) end)
			if success and backupData then
				local code = "AOT-" .. string.upper(string.sub(HttpService:GenerateGUID(false), 1, 6)); pcall(function() BackupDataStore:SetAsync(code, backupData) end)
				RemotesFolder.NotificationEvent:FireClient(player, "Code for " .. targetId .. ": " .. code, "Success")
			else RemotesFolder.NotificationEvent:FireClient(player, "No auto-backup found for ID: " .. targetId, "Error") end
		else RemotesFolder.NotificationEvent:FireClient(player, "Player not found. Type their exact UserID.", "Error") end
		return
	end

	local targetPlayer = player
	if targetName and targetName ~= "" and targetName:lower() ~= "me" then targetPlayer = nil; for _, p in ipairs(Players:GetPlayers()) do if string.find(p.Name:lower(), "^" .. targetName:lower()) then targetPlayer = p; break end end end
	if not targetPlayer then return end

	if command == "SetXP" then targetPlayer:SetAttribute("XP", tonumber(args) or 0)
	elseif command == "SetDews" then targetPlayer.leaderstats.Dews.Value = tonumber(args) or 0
	elseif command == "UnlockAllParts" then targetPlayer:SetAttribute("CurrentPart", 8); targetPlayer:SetAttribute("CurrentWave", 1)
	elseif command == "GiveItem" then 
		local itemName = type(args) == "table" and tostring(args.Item) or tostring(args)
		local itemAmount = type(args) == "table" and tonumber(args.Amount) or 1
		if itemName and itemName ~= "nil" and itemName ~= "" then
			local safeName = itemName:gsub("[^%w]", "") .. "Count"
			targetPlayer:SetAttribute(safeName, (targetPlayer:GetAttribute(safeName) or 0) + itemAmount)
			RemotesFolder.NotificationEvent:FireClient(player, "Gave " .. targetPlayer.Name .. " " .. itemAmount .. "x " .. itemName, "Success")
		end
	elseif command == "MaxPrestige" then 
		targetPlayer.leaderstats.Prestige.Value = 10
		task.spawn(function() PrestigeLB:SetAsync(tostring(targetPlayer.UserId), 10) end) 
	elseif command == "SetTitan" then targetPlayer:SetAttribute("Titan", tostring(args))
	elseif command == "SetClan" then targetPlayer:SetAttribute("Clan", tostring(args))
	elseif command == "SetTitle" then targetPlayer:SetAttribute("CustomTitle", tostring(args))
	elseif command == "WipePlayer" then
		targetPlayer.leaderstats.Prestige.Value = 0; targetPlayer.leaderstats.Dews.Value = 0; targetPlayer.leaderstats.Elo.Value = 1000

		local savedGamepasses = {}
		for k, v in pairs(targetPlayer:GetAttributes()) do
			if string.match(k, "^Has") or k == "PathDust" or k == "PathsFloor" then
				savedGamepasses[k] = v
			end
		end

		for k, _ in pairs(targetPlayer:GetAttributes()) do targetPlayer:SetAttribute(k, nil) end
		for k, v in pairs(DefaultData) do if k ~= "Prestige" and k ~= "Dews" and k ~= "Elo" then targetPlayer:SetAttribute(k, v) end end
		for k, v in pairs(savedGamepasses) do targetPlayer:SetAttribute(k, v) end

		targetPlayer:SetAttribute("DataLoaded", true)

		task.spawn(function() 
			PrestigeLB:SetAsync(tostring(targetPlayer.UserId), 0)
			EloLB:SetAsync(tostring(targetPlayer.UserId), 1000)
			if SavePlayer then SavePlayer(targetPlayer, false) end
		end)

		RemotesFolder.NotificationEvent:FireClient(player, "Player data successfully wiped.", "Success")
	end
end)

local function RollBounties(player)
	local now = os.time(); local currentDay = math.floor(now / 86400); local currentWeek = math.floor(now / 604800)

	if player:GetAttribute("LastDailyReset") ~= currentDay or player:GetAttribute("D1_Desc") == nil then
		player:SetAttribute("LastDailyReset", currentDay)
		local available = {}
		for _, v in ipairs(BountyData.Dailies) do table.insert(available, v) end
		for i = 1, 3 do 
			if #available == 0 then break end 
			local idx = math.random(1, #available); local b = available[idx]; table.remove(available, idx)
			local target = math.random(b.Min, b.Max)
			player:SetAttribute("D"..i.."_Task", b.Task)
			player:SetAttribute("D"..i.."_Desc", string.format(b.Desc, target))
			player:SetAttribute("D"..i.."_Prog", 0)
			player:SetAttribute("D"..i.."_Max", target)
			player:SetAttribute("D"..i.."_Reward", b.Reward)
			player:SetAttribute("D"..i.."_Claimed", false) 
		end
	end

	if player:GetAttribute("LastWeeklyReset") ~= currentWeek or player:GetAttribute("W1_Desc") == nil then
		player:SetAttribute("LastWeeklyReset", currentWeek)
		local b = BountyData.Weeklies[math.random(1, #BountyData.Weeklies)]
		local target = math.random(b.Min, b.Max)
		player:SetAttribute("W1_Task", b.Task)
		player:SetAttribute("W1_Desc", string.format(b.Desc, target))
		player:SetAttribute("W1_Prog", 0)
		player:SetAttribute("W1_Max", target)
		player:SetAttribute("W1_RewardType", b.RewardType)
		player:SetAttribute("W1_RewardAmt", b.RewardAmt)
		player:SetAttribute("W1_Claimed", false)
	end
end

local function VerifyGamepasses(player)
	for _, gp in ipairs(ItemData.Gamepasses) do 
		local hasPass = false
		local success, err = pcall(function() 
			hasPass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, gp.ID) 
		end)

		if player.UserId == 4068160397 or player.Name == "girthbender1209" then 
			hasPass = true 
		end

		if success and hasPass then
			player:SetAttribute("Has" .. gp.Key, true)
		else
			if player:GetAttribute("Has" .. gp.Key) == nil then
				player:SetAttribute("Has" .. gp.Key, false)
			end
		end
	end
end

local function LoadPlayer(player)
	task.wait(3.0) 
	if not player or not player.Parent then return end

	local userIdStr = tostring(player.UserId)
	local success, savedData
	local retries = 0

	repeat
		success, savedData = pcall(function() return GameDataStore:GetAsync(userIdStr) end)
		retries += 1
		if not success then task.wait(1.5) end
	until success or retries >= 3

	if not success then
		player:Kick("Roblox DataStores are currently experiencing issues. Please rejoin to protect your save data.")
		return
	end

	if savedData then
		pcall(function() BackupDataStore:SetAsync("Backup_" .. userIdStr, savedData) end)
	end

	local data = savedData or DefaultData

	VerifyGamepasses(player)

	local leaderstats = Instance.new("Folder"); leaderstats.Name = "leaderstats"; leaderstats.Parent = player

	local pVal = Instance.new("IntValue"); pVal.Name = "Prestige"; pVal.Value = data.Prestige or 0; pVal.Parent = leaderstats
	pVal.Changed:Connect(function(val) player:SetAttribute("Prestige", val) end)
	player:SetAttribute("Prestige", pVal.Value)

	local dVal = Instance.new("IntValue"); dVal.Name = "Dews"; dVal.Value = data.Dews or 0; dVal.Parent = leaderstats
	dVal.Changed:Connect(function(val) player:SetAttribute("Dews", val) end)
	player:SetAttribute("Dews", dVal.Value)

	local eVal = Instance.new("IntValue"); eVal.Name = "Elo"; eVal.Value = data.Elo or 1000; eVal.Parent = leaderstats
	eVal.Changed:Connect(function(val) player:SetAttribute("Elo", val) end)
	player:SetAttribute("Elo", eVal.Value)

	player:SetAttribute("Top5_Prestige", Top5PrestigeCache[player.UserId] or false)
	player:SetAttribute("Top5_Elo", Top5EloCache[player.UserId] or false)

	-- [[ THE FIX: Dynamically write and map Attributes to the Player object. Everything saved will persist. ]]
	for k, v in pairs(DefaultData) do if k ~= "Prestige" and k ~= "Dews" and k ~= "Elo" then player:SetAttribute(k, data[k] or v) end end
	for k, v in pairs(data) do if DefaultData[k] == nil and k ~= "Prestige" and k ~= "Dews" and k ~= "Elo" then player:SetAttribute(k, v) end end

	local myReg = player:GetAttribute("Regiment")
	if myReg then
		for dName, dData in pairs(CurrentVP.Districts) do
			local safeDistrictName = dName:gsub("[^%w]", "")
			if dData.Winner == myReg and player:GetAttribute("RewardClaimedWeek_" .. safeDistrictName) ~= CurrentVP.Week then
				player:SetAttribute("RewardClaimedWeek_" .. safeDistrictName, CurrentVP.Week)

				player.leaderstats.Dews.Value += 25000
				player:SetAttribute("TitanHardeningExtractCount", (player:GetAttribute("TitanHardeningExtractCount") or 0) + 1)
				task.delay(3, function() RemotesFolder.NotificationEvent:FireClient(player, "Your Regiment secured " .. dName .. " this week! (+25k Dews, +1 Extract)", "Success") end)
			end
		end
	end

	local LoginData = require(ReplicatedStorage:WaitForChild("LoginData"))

	local now = os.time()
	local dateDict = os.date("!*t", now)
	local todayStr = dateDict.year .. "-" .. dateDict.month .. "-" .. dateDict.day
	local lastLogin = player:GetAttribute("LastLoginDate") or ""

	if lastLogin ~= todayStr then
		local streak = player:GetAttribute("LoginStreak") or 0
		local yesterdayTime = now - 86400
		local yDict = os.date("!*t", yesterdayTime)
		local yesterdayStr = yDict.year .. "-" .. yDict.month .. "-" .. yDict.day

		if lastLogin == yesterdayStr then
			streak += 1
		else
			streak = 1 
		end
		if streak > 7 then streak = 1 end

		player:SetAttribute("LoginStreak", streak)
		player:SetAttribute("LastLoginDate", todayStr)

		local rewardData = LoginData[streak]
		if rewardData then
			if rewardData.Type == "Dews" then
				dVal.Value += rewardData.Amount
			elseif rewardData.Type == "Item" then
				local safeName = rewardData.Name:gsub("[^%w]", "") .. "Count"
				player:SetAttribute(safeName, (player:GetAttribute(safeName) or 0) + rewardData.Amount)
			end

			task.delay(5, function()
				local rewardName = rewardData.Name or "Dews"
				RemotesFolder.NotificationEvent:FireClient(player, "Day " .. streak .. " Login Reward: " .. rewardData.Amount .. "x " .. rewardName, "Success")
			end)
		end
	end

	RollBounties(player)
	player:SetAttribute("DataLoaded", true)

	pcall(function() PrestigeLB:SetAsync(userIdStr, pVal.Value) end)
	pcall(function() EloLB:SetAsync(userIdStr, eVal.Value) end)

	task.spawn(function()
		SavePlayer(player, false)
	end)
end

Players.PlayerAdded:Connect(LoadPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(function() LoadPlayer(p) end) end

local lastSaveTimes = {}
local savingPlayers = {}

SavePlayer = function(p, isLeaving)
	if not p then return end
	if not p:GetAttribute("DataLoaded") then return end

	local userIdStr = tostring(p.UserId)
	if savingPlayers[userIdStr] then return end 

	if isLeaving then
		savingPlayers[userIdStr] = true
	end

	local pName = p.Name
	local dataToSave = {}

	local prestigeVal = p:GetAttribute("Prestige") or 0
	local dewsVal = p:GetAttribute("Dews") or 0
	local eloVal = p:GetAttribute("Elo") or 1000

	local ls = p:FindFirstChild("leaderstats")
	if ls then
		if ls:FindFirstChild("Prestige") then prestigeVal = ls.Prestige.Value end
		if ls:FindFirstChild("Dews") then dewsVal = ls.Dews.Value end
		if ls:FindFirstChild("Elo") then eloVal = ls.Elo.Value end
	end

	dataToSave.Prestige = prestigeVal
	dataToSave.Dews = dewsVal
	dataToSave.Elo = eloVal

	for k, v in pairs(p:GetAttributes()) do 
		if k ~= "DataLoaded" and k ~= "InTrade" then 
			dataToSave[k] = v 
		end 
	end

	local now = os.clock()
	local lastSave = lastSaveTimes[userIdStr] or 0

	if lastSave ~= 0 and (now - lastSave) < 6.5 then
		if isLeaving then
			task.wait(6.5 - (now - lastSave))
		else
			return 
		end
	end

	lastSaveTimes[userIdStr] = os.clock()

	local success, err
	local retries = 0
	repeat
		success, err = pcall(function() GameDataStore:SetAsync(userIdStr, dataToSave) end)
		retries += 1
		if not success then task.wait(1.5) end
	until success or retries >= 3

	if not success then
		warn("[DataManager] CRITICAL: Failed to save " .. pName .. " Data after 3 retries! Error: " .. tostring(err))
	end

	pcall(function() PrestigeLB:SetAsync(userIdStr, dataToSave.Prestige or 0) end)
	pcall(function() EloLB:SetAsync(userIdStr, dataToSave.Elo or 1000) end)

	if isLeaving then
		savingPlayers[userIdStr] = nil
	end
end

Players.PlayerRemoving:Connect(function(p)
	SavePlayer(p, true)
end)

task.spawn(function() 
	while true do 
		task.wait(120) 
		for _, p in ipairs(Players:GetPlayers()) do 
			task.spawn(function() SavePlayer(p, false) end) 
		end 
	end 
end)

game:BindToClose(function() 
	for _, p in ipairs(Players:GetPlayers()) do 
		task.spawn(function() SavePlayer(p, true) end) 
	end 

	local waitTime = 0
	while next(savingPlayers) and waitTime < 25 do
		task.wait(1)
		waitTime += 1
	end
end)