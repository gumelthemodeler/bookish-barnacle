-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local PvPSeasonManager = {}
local DataStoreService = game:GetService("DataStoreService")
local EloDataStore = DataStoreService:GetOrderedDataStore("PvPEloRankings_Season1")
local Players = game:GetService("Players")

-- 14 days in seconds (14 * 24 * 60 * 60)
local SEASON_DURATION = 1209600 
local lastResetTime = os.time() 

function PvPSeasonManager.UpdatePlayerElo(player, newElo)
	pcall(function()
		EloDataStore:SetAsync(tostring(player.UserId), newElo)
	end)
end

function PvPSeasonManager.ExecuteSeasonReset()
	print("[PvPSeason] Executing Bi-Weekly Reset & Payouts...")

	local NotificationEvent = game.ReplicatedStorage:WaitForChild("Network"):FindFirstChild("NotificationEvent")
	if NotificationEvent then
		NotificationEvent:FireAllClients("The PvP Season has concluded! Top players have been rewarded.", "System")
	end

	local success, pages = pcall(function()
		return EloDataStore:GetSortedAsync(false, 100)
	end)

	if success and pages then
		local topPlayers = pages:GetCurrentPage()

		for rank, data in ipairs(topPlayers) do
			local userId = data.key
			local finalElo = data.value

			local rewardDew = 0
			local rewardItem = nil

			-- Rebalanced rewards for the squashed economy
			if rank <= 3 then
				rewardDew = 50000
				rewardItem = "Ascended Champion's Cape" 
			elseif rank <= 10 then
				rewardDew = 25000
				rewardItem = "Ascended Gladiator's Crest"
			elseif rank <= 50 then
				rewardDew = 10000
			else
				rewardDew = 5000
			end

			PvPSeasonManager.DistributeReward(userId, rewardDew, rewardItem)

			local compressedElo = math.floor((finalElo + 1000) / 2)
			EloDataStore:SetAsync(userId, compressedElo)

			local player = Players:GetPlayerByUserId(tonumber(userId))
			if player then
				if player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Elo") then
					player.leaderstats.Elo.Value = compressedElo
				end
				if NotificationEvent then
					NotificationEvent:FireClient(player, "PvP Season Ended. You placed Rank " .. rank .. "!", "Success")
				end
			end
		end
	end

	lastResetTime = os.time()
end

function PvPSeasonManager.DistributeReward(userId, dewAmount, itemName)
	local player = Players:GetPlayerByUserId(tonumber(userId))
	if player then
		player.leaderstats.Dews.Value += dewAmount
		if itemName then
			local safeName = itemName:gsub("[^%w]", "") .. "Count"
			player:SetAttribute(safeName, (player:GetAttribute(safeName) or 0) + 1)
		end
	else
		-- Offline queue logic goes here
	end
end

task.spawn(function()
	while task.wait(60) do
		if os.time() - lastResetTime >= SEASON_DURATION then
			PvPSeasonManager.ExecuteSeasonReset()
		end
	end
end)

return PvPSeasonManager