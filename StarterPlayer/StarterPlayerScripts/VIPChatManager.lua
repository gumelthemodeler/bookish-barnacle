-- @ScriptType: LocalScript
-- @ScriptType: LocalScript
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")

TextChatService.OnIncomingMessage = function(message: TextChatMessage)
	local properties = Instance.new("TextChatMessageProperties")

	if message.TextSource then
		local player = Players:GetPlayerByUserId(message.TextSource.UserId)
		if player then
			-- [[ THE FIX: Check for an Admin Custom Title First! ]]
			local customTitle = player:GetAttribute("CustomTitle")

			if customTitle and customTitle ~= "" then
				properties.PrefixText = "<font color='#AA55FF'><b>[" .. customTitle .. "]</b></font> <font color='#AA55FF'>" .. (message.PrefixText or player.Name) .. "</font>"
			elseif player:GetAttribute("HasVIP") then
				-- Fallback to standard Golden VIP Tag if no custom title is set
				properties.PrefixText = "<font color='#FFD700'><b>[VIP]</b></font> <font color='#FFD700'>" .. (message.PrefixText or player.Name) .. "</font>"
			end
		end
	end

	return properties
end