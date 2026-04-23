-- @ScriptType: Script
-- @ScriptType: Script
-- @ScriptType: Script
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local GameDataStore = DataStoreService:GetDataStore("AoT_Data_V3") 
local BackupDataStore = DataStoreService:GetDataStore("AoT_Backups_V1") 

local RemotesFolder = ReplicatedStorage:WaitForChild("Network")

local ActiveCodes = { 
	["HAVECLANS"] = { 
		Items = {
			["Clan Blood Vial"] = 5,
		}
	},
	["PATHS"] = { 
		Items = {
			["Clan Blood Vial"] = 5,
			["Spinal Fluid Syringe"] = 1
		}
	},
	["1KMEMBERS"] = {
		Items = {
			["Standard Titan Serum"] = 15,
		}
	},
	["BESTIARY"] = {
		Items = {
			["Clan Blood Vial"] = 15,
		}
	},
	["LABYRINTH"] = {
		Items = { 
			["Legendary Clan Vial"] = 3,
		}
	},
	["GOJOHNNYGO"] = {
		Items = {
			["Standard Titan Serum"] = 15,
		}
	},
	["LUCKY"] = {
		Items = { 
			["Legendary Clan Blood Vial"] = 3,
			["Spinal Fluid Syringe"] = 3
		}
	},
	["LABYRINTH2"] = {
		Items = { 
			["Legendary Clan Vial"] = 3,
		}
	},
	["BUGS"] = {
		Items = { 
			["Clan Blood Vial"] = 5,
		}
	},
	["FATPATCH"] = {
		Items = { 
			["Legendary Clan Vial"] = 5,
		}
	},

}

RemotesFolder:WaitForChild("RedeemCode").OnServerEvent:Connect(function(player, codeStr)
	local codeKey = string.upper(codeStr)

	-- 1. Check if it's an Admin Data Recovery Code
	if string.sub(codeKey, 1, 4) == "AOT-" then
		local success, backupData = pcall(function() return BackupDataStore:GetAsync(codeKey) end)
		if success and backupData then 
			pcall(function() GameDataStore:SetAsync(player.UserId, backupData) end)
			player:Kick("Data Backup Restored! Please reconnect to the game.") 
		else 
			RemotesFolder.NotificationEvent:FireClient(player, "Invalid or Expired Backup Code.", "Error") 
		end
		return
	end

	-- 2. Standard Promo Code Validation
	local codeData = ActiveCodes[codeKey]
	if not codeData then 
		RemotesFolder.NotificationEvent:FireClient(player, "Invalid Code.", "Error")
		return 
	end

	local redeemedStr = player:GetAttribute("RedeemedCodes") or ""
	if string.find(redeemedStr, "%[" .. codeKey .. "%]") then 
		RemotesFolder.NotificationEvent:FireClient(player, "Code already redeemed.", "Error")
		return 
	end 

	-- [[ THE FIX: Detailed Notification Building ]]
	player:SetAttribute("RedeemedCodes", redeemedStr .. "[" .. codeKey .. "]")

	local rewardsStr = ""

	if codeData.Dews then 
		player.leaderstats.Dews.Value += codeData.Dews
		rewardsStr = rewardsStr .. codeData.Dews .. " Dews, " 
	end
	if codeData.XP then 
		player:SetAttribute("XP", (player:GetAttribute("XP") or 0) + codeData.XP)
		rewardsStr = rewardsStr .. codeData.XP .. " XP, " 
	end
	if codeData.TitanXP then 
		player:SetAttribute("TitanXP", (player:GetAttribute("TitanXP") or 0) + codeData.TitanXP)
		rewardsStr = rewardsStr .. codeData.TitanXP .. " Titan XP, " 
	end

	if codeData.Items then
		for itemName, amount in pairs(codeData.Items) do
			local safeName = itemName:gsub("[^%w]", "") .. "Count"
			player:SetAttribute(safeName, (player:GetAttribute(safeName) or 0) + amount) 
			rewardsStr = rewardsStr .. amount .. "x " .. itemName .. ", "
		end
	end

	if rewardsStr ~= "" then rewardsStr = string.sub(rewardsStr, 1, -3) end -- Strip the trailing comma and space
	RemotesFolder.NotificationEvent:FireClient(player, "Redeemed: " .. rewardsStr, "Success")
end)

