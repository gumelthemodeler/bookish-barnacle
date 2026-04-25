-- @ScriptType: ModuleScript
local PvPSeasonManager = {}
local DataStoreService = game:GetService("DataStoreService")
local EloDataStore = DataStoreService:GetOrderedDataStore("PvPEloRankings_Season1")
local Players = game:GetService("Players")

-- 14 days in seconds (14 * 24 * 60 * 60)
local SEASON_DURATION = 1209600 
local lastResetTime = os.time() -- In a full release, fetch this from a global DataStore

function PvPSeasonManager.UpdatePlayerElo(player, newElo)
	-- Called by PVPManager.lua when a match ends to keep the leaderboard updated
	pcall(function()
		EloDataStore:SetAsync(tostring(player.UserId), newElo)
	end)
end

function PvPSeasonManager.ExecuteSeasonReset()
	print("[PvPSeason] Executing Bi-Weekly Reset & Payouts...")

	local success, pages = pcall(function()
		-- Fetch the Top 100 players
		return EloDataStore:GetSortedAsync(false, 100)
	end)

	if success and pages then
		local topPlayers = pages:GetCurrentPage()

		for rank, data in ipairs(topPlayers) do
			local userId = data.key
			local finalElo = data.value

			-- Prepare offline payout data (DataStore) or award immediately if online
			local rewardDew = 0
			local rewardItem = nil

			if rank <= 3 then
				rewardDew = 500000
				rewardItem = "Ascended Champion's Cape" -- Rarity: Ascended (Bypasses Mythical Autosell)
			elseif rank <= 10 then
				rewardDew = 250000
				rewardItem = "Ascended Gladiator's Crest"
			elseif rank <= 50 then
				rewardDew = 100000
			else
				rewardDew = 50000
			end

			PvPSeasonManager.DistributeReward(userId, rewardDew, rewardItem)

			-- Soft Reset: Compress ELO toward the 1000 baseline
			local compressedElo = math.floor((finalElo + 1000) / 2)
			EloDataStore:SetAsync(userId, compressedElo)

			local player = Players:GetPlayerByUserId(tonumber(userId))
			if player then
				if player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Elo") then
					player.leaderstats.Elo.Value = compressedElo
				end
				-- Send a dark, gritty notification frame (no rounded corners)
				game.ReplicatedStorage.Network.NotificationEvent:FireClient(player, "PvP Season Ended. You placed Rank " .. rank .. "!", "Success")
			end
		end
	end

	-- Reset the global timer
	lastResetTime = os.time()
end

function PvPSeasonManager.DistributeReward(userId, dewAmount, itemName)
	-- Locate the player's saved data block and inject the Dew/Item.
	-- If they are currently in the server, apply it to their attributes/inventory immediately.
	local player = Players:GetPlayerByUserId(tonumber(userId))
	if player then
		player.leaderstats.Dews.Value += dewAmount
		if itemName then
			local safeName = itemName:gsub("[^%w]", "") .. "Count"
			player:SetAttribute(safeName, (player:GetAttribute(safeName) or 0) + 1)
		end
	else
		-- Add to an offline payout queue DataStore here
	end
end

-- Polling loop to check if the 2 weeks have passed
task.spawn(function()
	while task.wait(60) do
		if os.time() - lastResetTime >= SEASON_DURATION then
			PvPSeasonManager.ExecuteSeasonReset()
		end
	end
end)

return PvPSeasonManager