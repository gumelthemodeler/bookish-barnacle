-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local CombatCore = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SkillData = require(ReplicatedStorage:WaitForChild("SkillData"))
local ItemData = require(ReplicatedStorage:WaitForChild("ItemData"))
local TitanData = require(ReplicatedStorage:WaitForChild("TitanData"))
local ClanData = require(ReplicatedStorage:WaitForChild("ClanData"))

local function GetSetBonus(playerObj)
	if not playerObj then return nil end
	local wpn = playerObj:GetAttribute("EquippedWeapon")
	local acc = playerObj:GetAttribute("EquippedAccessory")
	if not wpn or not acc then return nil end

	for _, setData in pairs(ItemData.Sets or {}) do
		if setData.Pieces.Weapon == wpn and setData.Pieces.Accessory == acc then
			return setData.Bonus
		end
	end
	return nil
end

function CombatCore.TickStatuses(combatant)
	local dotDamage = 0
	local dotLog = ""

	if combatant.Cooldowns then
		for sName, cd in pairs(combatant.Cooldowns) do
			if type(cd) == "number" and cd > 0 then
				combatant.Cooldowns[sName] = cd - 1
			end
		end
	end

	if combatant.GateType == "Steam" and combatant.GateHP and combatant.GateHP > 0 then 
		combatant.GateHP = math.max(0, combatant.GateHP - 1) 
	end

	if combatant.Statuses then
		if combatant.Statuses["Bleed"] and combatant.Statuses["Bleed"] > 0 then
			local dmg = combatant.IsPlayer and math.floor(combatant.MaxHP * 0.05) or math.min(math.floor(combatant.MaxHP * 0.02), 5000)
			dotDamage += dmg
			dotLog = dotLog .. " <font color=\"#FF5555\">[BLEED: -" .. dmg .. "]</font>"
		end
		if combatant.Statuses["Burn"] and combatant.Statuses["Burn"] > 0 then
			local dmg = combatant.IsPlayer and math.floor(combatant.MaxHP * 0.05) or math.min(math.floor(combatant.MaxHP * 0.02), 6500)
			dotDamage += dmg
			dotLog = dotLog .. " <font color=\"#FFAA00\">[BURN: -" .. dmg .. "]</font>"
		end
		if combatant.Statuses["Lacerate"] and combatant.Statuses["Lacerate"] > 0 then
			local stacks = tonumber(combatant.Statuses["Lacerate"]) or 1
			local dmg = combatant.IsPlayer and math.floor(combatant.MaxHP * (0.05 * stacks)) or math.min(math.floor(combatant.MaxHP * (0.03 * stacks)), 15000)
			dotDamage += dmg
			dotLog = dotLog .. " <font color=\"#AA0000\">[LACERATE x" .. stacks .. ": -" .. dmg .. "]</font>"
		end

		local toRemove = {}
		local immunitiesToAdd = {}

		for sName, duration in pairs(combatant.Statuses) do
			if sName == "Transformed" or sName == "Telegraphing" or sName == "Enraged" or sName == "Lacerate" then
				continue
			end

			if type(duration) == "number" then
				combatant.Statuses[sName] = duration - 1
				if combatant.Statuses[sName] <= 0 then
					table.insert(toRemove, sName)
				end
			end
		end

		for _, rem in ipairs(toRemove) do
			combatant.Statuses[rem] = nil
			if not string.find(rem, "Immunity") and not string.find(rem, "SynergyMark_") then
				if rem == "Stun" or rem == "Immobilized" or rem == "TrueBlind" or rem == "Confusion" or rem == "Terror" then
					local immDuration = 3
					if combatant.IsBoss then immDuration = 5 end 
					immunitiesToAdd[rem .. "Immunity"] = immDuration
				elseif rem == "Bleed" or rem == "Burn" or rem == "Crippled" or rem == "Weakened" or rem == "Blinded" or rem == "Debuff_Defense" then
					local immDuration = 2
					if combatant.IsBoss then immDuration = 4 end 
					immunitiesToAdd[rem .. "Immunity"] = immDuration
				end
			end
		end

		for immName, dur in pairs(immunitiesToAdd) do
			combatant.Statuses[immName] = dur
		end
	end

	return dotDamage, dotLog
end

function CombatCore.CalculateDamage(attacker, defender, skillMult, targetLimb, battleContext)
	local atkStrength = math.max(1, tonumber(attacker.TotalStrength) or 10)
	local defArmor = math.max(1, tonumber(defender.TotalDefense) or 10)
	local terrain = (battleContext and type(battleContext) == "table") and battleContext.Terrain or "City"

	local atkBuff = 1.0
	local defBuff = 1.0
	local armorPen = 0

	local momentum = tonumber(attacker.MomentumStacks) or 0
	atkBuff = atkBuff * (1.0 + (momentum * 0.05))

	if attacker.Statuses then
		if (tonumber(attacker.Statuses.Buff_Strength) or 0) > 0 then atkBuff = atkBuff * 1.5 end
		if (tonumber(attacker.Statuses.Weakened) or 0) > 0 then atkBuff = atkBuff * 0.5 end
		if (tonumber(attacker.Statuses.Enraged) or 0) > 0 then atkBuff = atkBuff * 2.0; armorPen = armorPen + 0.5 end
	end

	if defender.Statuses then
		if (tonumber(defender.Statuses.Buff_Defense) or 0) > 0 then defBuff = defBuff * 1.5 end
		if (tonumber(defender.Statuses.Crippled) or 0) > 0 then defBuff = defBuff * 0.5 end
		if (tonumber(defender.Statuses.Debuff_Defense) or 0) > 0 then defBuff = defBuff * 0.5 end
		if (tonumber(defender.Statuses.Block) or 0) > 0 then defBuff = defBuff * 3.0 end
	end

	local isAttackerTransformed = attacker.Statuses and (tonumber(attacker.Statuses.Transformed) or 0) > 0
	local isDefenderTransformed = defender.Statuses and (tonumber(defender.Statuses.Transformed) or 0) > 0

	if attacker.IsPlayer and isAttackerTransformed and attacker.PlayerObj then
		atkStrength = math.max(1, tonumber(attacker.PlayerObj:GetAttribute("Titan_Power_Val")) or 10)
		atkBuff = atkBuff * 4.0 
	end
	if defender.IsPlayer and isDefenderTransformed and defender.PlayerObj then
		defArmor = math.max(1, tonumber(defender.PlayerObj:GetAttribute("Titan_Hardening_Val")) or 10)
		defBuff = defBuff * 4.0 
	end

	if terrain == "Caverns" then
		if (defender.IsPlayer and isDefenderTransformed) or (not defender.IsPlayer and defender.GateType) then
			defBuff = defBuff * 1.3
		end
	end

	if attacker.IsPlayer and attacker.PlayerObj then
		local isAwakened = string.find(tostring(attacker.Clan or ""), "Awakened") ~= nil or string.find(tostring(attacker.Clan or ""), "Abyssal") ~= nil
		local aStats = ClanData.GetClanStats(attacker.Clan, isAwakened, attacker.Titan, isAttackerTransformed)
		atkBuff = atkBuff * aStats.DmgMult

		if (aStats.MomentumDamagePerHit or 0) > 0 and not isAttackerTransformed then
			atkBuff = atkBuff * (1.0 + (momentum * aStats.MomentumDamagePerHit))
		end

		if not isAttackerTransformed then
			local setBonus = GetSetBonus(attacker.PlayerObj)
			if setBonus then
				if setBonus.DmgMult then atkBuff = atkBuff * setBonus.DmgMult end
				if setBonus.IgnoreArmor then armorPen = armorPen + setBonus.IgnoreArmor end
			end

			local expiry = tonumber(attacker.PlayerObj:GetAttribute("Buff_Damage_Expiry")) or 0
			if expiry > os.time() then atkBuff = atkBuff * 1.5 end
		end

		local prestigeDmg = tonumber(attacker.PlayerObj:GetAttribute("Prestige_DmgMult")) or 0
		atkBuff = atkBuff * (1.0 + prestigeDmg)
		armorPen = armorPen + (tonumber(attacker.PlayerObj:GetAttribute("Prestige_IgnoreArmor")) or 0)
	end

	if defender.IsPlayer and defender.PlayerObj then
		local isAwakened = string.find(tostring(defender.Clan or ""), "Awakened") ~= nil or string.find(tostring(defender.Clan or ""), "Abyssal") ~= nil
		local dStats = ClanData.GetClanStats(defender.Clan, isAwakened, defender.Titan, isDefenderTransformed)
		defBuff = defBuff * dStats.ArmorMult
	end

	if attacker.AwakenedStats then
		if (tonumber(attacker.AwakenedStats.DmgMult) or 1.0) > 1.0 then atkBuff = atkBuff * tonumber(attacker.AwakenedStats.DmgMult) end
		if (tonumber(attacker.AwakenedStats.IgnoreArmor) or 0) > 0 then armorPen = armorPen + tonumber(attacker.AwakenedStats.IgnoreArmor) end
	end

	local effectiveAttack = atkStrength * atkBuff
	local effectiveDefense = defArmor * defBuff

	if armorPen > 0 then effectiveDefense = effectiveDefense * math.max(0.1, 1.0 - armorPen) end

	local baseDmg = (effectiveAttack * effectiveAttack) / (effectiveAttack + effectiveDefense)

	skillMult = tonumber(skillMult) or 1.0
	baseDmg = baseDmg * skillMult

	if attacker.IsPlayer then baseDmg = baseDmg * 1.5 end

	targetLimb = tostring(targetLimb or "Body")
	if targetLimb == "Nape" or targetLimb == "Head" then
		local napeMult = 1.5
		if attacker.IsPlayer and not isAttackerTransformed then
			local isAwakened = string.find(tostring(attacker.Clan or ""), "Awakened") ~= nil or string.find(tostring(attacker.Clan or ""), "Abyssal") ~= nil
			local aStats = ClanData.GetClanStats(attacker.Clan, isAwakened, attacker.Titan, isAttackerTransformed)
			napeMult = aStats.NapeCritMultiplier or 1.5
		end

		if defender.Statuses and (tonumber(defender.Statuses.NapeGuard) or 0) > 0 then return 1 else baseDmg = baseDmg * napeMult end
	elseif targetLimb == "Legs" or targetLimb == "Arms" then baseDmg = baseDmg * 0.5
	elseif targetLimb == "Eyes" then baseDmg = baseDmg * 0.2 end

	local synergyOwner = defender.SynergyOwners and defender.SynergyOwners[targetLimb]
	if defender.Statuses and defender.Statuses["SynergyMark_" .. targetLimb] then
		if attacker.IsPlayer and attacker.PlayerObj and synergyOwner ~= attacker.PlayerObj.UserId then
			baseDmg = baseDmg * 2.5
		end
	end

	if defender.IsPlayer and not attacker.IsPlayer then
		local pMaxHP = tonumber(defender.MaxHP) or 100
		local dmgCeiling = attacker.IsBoss and (pMaxHP * 0.45) or (pMaxHP * 0.25)
		if baseDmg > dmgCeiling then
			baseDmg = dmgCeiling + ((baseDmg - dmgCeiling) * 0.1)
		end
	end

	baseDmg = baseDmg * (math.random(90, 110) / 100)
	return math.max(1, math.floor(baseDmg))
end

function CombatCore.TakeDamage(combatant, damage, attackerStyle)
	local actualDmg = tonumber(damage) or 0
	local hitGate = false; local gateBroken = false; local gateName = tostring(combatant.GateType or "Shield")
	local gateHP = tonumber(combatant.GateHP) or 0

	if gateHP > 0 then
		hitGate = true
		if combatant.GateType == "Steam" then actualDmg = 0 
		else
			if combatant.GateType == "Reinforced Skin" and tostring(attackerStyle) == "Thunder Spears" then actualDmg = actualDmg * 5.0 end
			if actualDmg >= gateHP then
				actualDmg = actualDmg - gateHP; combatant.GateHP = 0; gateBroken = true
			else combatant.GateHP = gateHP - actualDmg; actualDmg = 0 end
		end
	end

	local survivalTriggered = false
	if actualDmg > 0 then
		local currentHP = tonumber(combatant.HP) or 0
		if (currentHP - actualDmg) < 1 then
			local resolveStat = tonumber(combatant.TotalResolve) or 10

			if combatant.IsPlayer and combatant.Statuses and combatant.Statuses["Transformed"] and combatant.PlayerObj then
				resolveStat = tonumber(combatant.PlayerObj:GetAttribute("Titan_Endurance_Val")) or 10
			end

			local survivalChance = math.clamp(resolveStat * 0.7, 0, 45)
			local maxSurvivals = 1

			if combatant.IsPlayer and combatant.PlayerObj then
				local isAwakened = string.find(tostring(combatant.Clan or ""), "Awakened") ~= nil or string.find(tostring(combatant.Clan or ""), "Abyssal") ~= nil
				local cStats = ClanData.GetClanStats(combatant.Clan, isAwakened, combatant.Titan, combatant.Statuses and combatant.Statuses["Transformed"])
				if cStats.SurvivalChance > 0 then survivalChance = cStats.SurvivalChance end
				if cStats.Survivals > 0 then maxSurvivals = cStats.Survivals end
				maxSurvivals = maxSurvivals + (tonumber(combatant.PlayerObj:GetAttribute("Prestige_Survivals")) or 0)
			end

			local usedSurvivals = tonumber(combatant.ResolveSurvivals) or 0
			if usedSurvivals < maxSurvivals and math.random(1, 100) <= survivalChance then
				combatant.HP = 1; combatant.ResolveSurvivals = usedSurvivals + 1; survivalTriggered = true 
			else combatant.HP = currentHP - actualDmg end
		else combatant.HP = currentHP - actualDmg end
	end
	return survivalTriggered, hitGate, gateBroken, actualDmg, gateName
end

function CombatCore.ExecutePvPStrike(attacker, defender, skillName, targetLimb, qteMultiplier)
	skillName = tostring(skillName or "Basic Slash")
	targetLimb = tostring(targetLimb or "Body")
	local skill = SkillData.Skills[skillName] or { Mult = 1.0, Cooldown = 0, Hits = 1, Effect = "None", Description = "A basic attack." }

	local aName = tostring(attacker.Name or "Attacker")
	local dName = tostring(defender.Name or "Defender")
	local fLogName = "<font color=\"#55AAFF\">" .. aName .. "</font>"
	local fDefName = "<font color=\"#FF5555\">" .. dName .. "</font>"

	if attacker.Cooldowns then attacker.Cooldowns[skillName] = tonumber(skill.Cooldown) or 0 end
	if not attacker.BaseMaxHP then attacker.BaseMaxHP = tonumber(attacker.MaxHP) or 100 end
	if not defender.BaseMaxHP then defender.BaseMaxHP = tonumber(defender.MaxHP) or 100 end

	local mult = tonumber(skill.Mult) or 1.0

	if mult == 0 then
		if skill.Effect == "CloseGap" or skillName == "Close In" or skillName == "Advance" or skillName == "Charge" then
			attacker.LastSkill = skillName
			if attacker.Statuses and attacker.Statuses["Transformed"] then return fLogName .. " used <b>" .. skillName .. "</b>!\n<font color=\"#FFAA00\">" .. aName .. " charges forward with immense speed!</font>", false, "Heavy", 0
			else return fLogName .. " used <b>" .. skillName .. "</b>!\n<font color=\"#55AAFF\">" .. aName .. " uses their ODM gear to close the distance!</font>", false, "None", 0 end
		elseif skill.Effect == "FallBack" or skillName == "Fall Back" then
			attacker.LastSkill = skillName
			return fLogName .. " used <b>" .. skillName .. "</b>!\n<font color=\"#FFAA55\">" .. aName .. " falls back to Long Range!</font>", false, "None", 0
		elseif skill.Effect == "Dodge" then
			if not attacker.Statuses then attacker.Statuses = {} end
			attacker.Statuses["Dodge"] = 1; attacker.LastSkill = skillName 
			return fLogName .. " used <b>" .. skillName .. "</b>!\n" .. aName .. " engaged evasive maneuvers.", false, "None", 0
		elseif skill.Effect == "Block" then
			if not attacker.Statuses then attacker.Statuses = {} end
			attacker.Statuses["Block"] = 1; attacker.LastSkill = skillName 
			return fLogName .. " used <b>" .. skillName .. "</b>!\n" .. aName .. " takes a defensive stance.", false, "None", 0
		elseif skill.Effect == "Rest" or skillName == "Recover" or skillName == "Regroup" then
			local healAmount = (tonumber(attacker.MaxHP) or 100) * 0.30
			attacker.HP = math.min(tonumber(attacker.MaxHP) or 100, (tonumber(attacker.HP) or 0) + healAmount); 
			attacker.Gas = tonumber(attacker.MaxGas) or 100; attacker.LastSkill = skillName
			return fLogName .. " used <b>" .. skillName .. "</b>!\n<font color=\"#55FF55\">" .. aName .. " recovered HP and Gas.</font>", false, "None", 0
		elseif skill.Effect == "Transform" then
			if not attacker.Statuses then attacker.Statuses = {} end
			attacker.Statuses["Transformed"] = 999; attacker.LastSkill = skillName;

			local tEnd = tonumber(attacker.PlayerObj:GetAttribute("Titan_Endurance_Val")) or 10
			local tPot = tonumber(attacker.PlayerObj:GetAttribute("Titan_Potential_Val")) or 10
			attacker.MaxHP = attacker.BaseMaxHP + ((tEnd + tPot) * 40) 
			attacker.HP = attacker.MaxHP
			attacker.TitanEnergy = tonumber(attacker.MaxTitanEnergy) or 100

			return fLogName .. " used <b>" .. skillName .. "</b>!\nLightning strikes as " .. aName .. " shifts into a Titan! <font color=\"#55FF55\">[MAX HP BOOSTED & HEAT Restored]</font>", false, "Heavy", 0
		elseif skill.Effect == "Eject" then
			if attacker.Statuses then attacker.Statuses["Transformed"] = nil end
			attacker.LastSkill = skillName
			attacker.MaxHP = attacker.BaseMaxHP
			attacker.HP = math.min(attacker.HP, attacker.MaxHP)
			return fLogName .. " used <b>" .. skillName .. "</b>!\n" .. aName .. " cuts themselves out of the nape, returning to human form.", false, "None", 0
		elseif skill.Effect == "TitanRest" or skillName == "Titan Recover" then
			local healAmount = (tonumber(attacker.MaxHP) or 100) * 0.60
			attacker.HP = math.min(tonumber(attacker.MaxHP) or 100, (tonumber(attacker.HP) or 0) + healAmount); attacker.LastSkill = skillName
			return fLogName .. " used <b>" .. skillName .. "</b>!\n<font color=\"#55FF55\">" .. aName .. " uses immense steam to regenerate " .. math.floor(healAmount) .. " HP.</font>", false, "None", 0
		end
	end

	local hitsToDo = tonumber(skill.Hits) or 1
	local hitLogs = {}
	local didHitAtAll = false
	local overallShake = "None"
	local totalDmgDealt = 0

	local isAttackerTransformed = attacker.Statuses and (tonumber(attacker.Statuses.Transformed) or 0) > 0
	local isDefenderTransformed = defender.Statuses and (tonumber(defender.Statuses.Transformed) or 0) > 0

	local momentum = tonumber(attacker.MomentumStacks) or 0

	local atkSpd = tonumber(attacker.TotalSpeed) or 10
	local defSpd = tonumber(defender.TotalSpeed) or 10
	local atkRes = tonumber(attacker.TotalResolve) or 10
	local defRes = tonumber(defender.TotalResolve) or 10

	atkSpd = atkSpd * (1.0 + (momentum * 0.05))

	if attacker.Statuses and attacker.Statuses["Terror"] then
		atkSpd = atkSpd * 0.75
		atkRes = atkRes * 0.75
	end
	if defender.Statuses and defender.Statuses["Terror"] then
		defSpd = defSpd * 0.75
		defRes = defRes * 0.75
	end

	if attacker.IsPlayer and isAttackerTransformed and attacker.PlayerObj then
		atkSpd = (tonumber(attacker.PlayerObj:GetAttribute("Titan_Speed_Val")) or 10) * 3.0
		atkRes = tonumber(attacker.PlayerObj:GetAttribute("Titan_Endurance_Val")) or 10
	end
	if defender.IsPlayer and isDefenderTransformed and defender.PlayerObj then
		defSpd = (tonumber(defender.PlayerObj:GetAttribute("Titan_Speed_Val")) or 10) * 3.0
		defRes = tonumber(defender.PlayerObj:GetAttribute("Titan_Endurance_Val")) or 10
	end

	for i = 1, hitsToDo do
		local currentDefHP = tonumber(defender.HP) or 0
		if currentDefHP < 1 and i > 1 then break end 

		if defender.Statuses and defender.Statuses["CounterStance"] and (skill.Range ~= "Long" and not skill.Unavoidable) then
			local counterDmg = math.floor((defender.TotalStrength or 10) * 1.5)
			attacker.HP = math.max(1, (tonumber(attacker.HP) or 10) - counterDmg)
			table.insert(hitLogs, fLogName .. " attacked, but " .. fDefName .. " was in a <font color=\"#FF3333\"><b>COUNTER STANCE</b></font>! " .. aName .. " was instantly interrupted and took " .. counterDmg .. " counter-damage!")
			didHitAtAll = false
			break
		end

		local isDodging = false
		if defender.Statuses then
			if (tonumber(defender.Statuses.Dodge) or 0) > 0 then isDodging = true end
			if (tonumber(defender.Statuses.Crippled) or 0) > 0 then defSpd = defSpd * 0.5 end
			if (tonumber(defender.Statuses.Immobilized) or 0) > 0 then defSpd = 0 end
		end

		local dodgeChance = 5 + ((defSpd - atkSpd) * 0.08) 
		if isDodging then dodgeChance = 100 end
		if defender.Statuses and (tonumber(defender.Statuses.Immobilized) or 0) > 0 then dodgeChance = 0; isDodging = false end

		local tPotential = defender.IsPlayer and isDefenderTransformed and (tonumber(defender.PlayerObj:GetAttribute("Titan_Potential_Val")) or 10) or 0
		dodgeChance = dodgeChance + (tPotential * 0.25)

		dodgeChance = math.clamp(dodgeChance, 0, 75)
		if targetLimb == "Nape" or targetLimb == "Head" then dodgeChance += 15 end

		if math.random(1, 100) <= dodgeChance then
			local dodgeMsg = isDodging and " (Maneuvered)" or ""
			table.insert(hitLogs, fLogName .. " aimed for the <b>" .. targetLimb .. "</b>, but " .. fDefName .. " dodged!" .. dodgeMsg)
			continue
		end

		didHitAtAll = true

		local critChance = 5 + ((atkRes - defRes) * 0.10)
		if attacker.AwakenedStats and (tonumber(attacker.AwakenedStats.CritBonus) or 0) > 0 then critChance = critChance + tonumber(attacker.AwakenedStats.CritBonus) end

		local tPrecision = attacker.IsPlayer and isAttackerTransformed and (tonumber(attacker.PlayerObj:GetAttribute("Titan_Precision_Val")) or 10) or 0
		critChance = critChance + (tPrecision * 0.25)

		if targetLimb == "Nape" or targetLimb == "Head" then critChance += 25 end
		critChance = math.clamp(critChance, 5, 75)

		local isCrit = math.random(1, 100) <= critChance
		local dmgMultValue = (tonumber(skill.Mult) or 1.0) * (isCrit and 1.5 or 1.0)

		local effectLog = ""

		if skillName == "Titan Kick" and defender.Statuses and defender.Statuses["Lacerate"] then
			local stacks = tonumber(defender.Statuses["Lacerate"]) or 1
			dmgMultValue = dmgMultValue + (0.5 * stacks)
			defender.Statuses["Lacerate"] = nil
			effectLog = effectLog .. " <font color=\"#FF0000\"><b>[LACERATE DETONATED!]</b></font>"
		end
		if skillName == "Titan Punch" and defender.Statuses and defender.Statuses["Confusion"] then
			if not defender.Statuses then defender.Statuses = {} end
			defender.Statuses["Stun"] = 2
			defender.Statuses["Confusion"] = nil
			effectLog = effectLog .. " <font color=\"#FFFF00\"><b>[CONFUSION EXPLOITED -> STUNNED!]</b></font>"
		end

		local baseDmg = CombatCore.CalculateDamage(attacker, defender, dmgMultValue, targetLimb, nil)
		baseDmg = math.max(1, math.floor(baseDmg * (qteMultiplier or 1.0)))

		local survivalTriggered, hitGate, gateBroken, hpDmg, gateName = CombatCore.TakeDamage(defender, baseDmg, attacker.Style)
		totalDmgDealt += hpDmg

		if qteMultiplier == 0.2 then effectLog = effectLog .. " <font color=\"#FFD700\"><b>[PARRIED!]</b></font>"
		elseif qteMultiplier == 0.6 then effectLog = effectLog .. " <font color=\"#AAAAAA\"><b>[BLOCKED!]</b></font>" end

		if skill.Effect and skill.Effect ~= "None" and skill.Effect ~= "Block" and skill.Effect ~= "Dodge" and skill.Effect ~= "Rest" then
			local safeEffect = tostring(skill.Effect)
			if not defender.Statuses then defender.Statuses = {} end
			local currentEffect = tonumber(defender.Statuses[safeEffect]) or 0

			if safeEffect == "Bleed" then
				local curLac = tonumber(defender.Statuses["Lacerate"]) or 0
				if curLac > 0 then
					defender.Statuses["Lacerate"] = math.min(3, curLac + 1)
					effectLog = effectLog .. " <font color=\"#AA0000\">[LACERATE x" .. defender.Statuses["Lacerate"] .. "]</font>"
				elseif currentEffect > 0 then
					defender.Statuses["Bleed"] = nil
					defender.Statuses["Lacerate"] = 1
					effectLog = effectLog .. " <font color=\"#AA0000\">[DEEP WOUND: LACERATE!]</font>"
				else
					defender.Statuses["Bleed"] = (tonumber(skill.Duration) or 2) + 1
					effectLog = effectLog .. " <font color=\"#FF5555\">[BLEED]</font>"
				end
			elseif currentEffect == 0 then
				local appliedDur = tonumber(skill.Duration) or 2
				if safeEffect == "Stun" or safeEffect == "Immobilized" or safeEffect == "TrueBlind" or safeEffect == "Confusion" or safeEffect == "Terror" then
					appliedDur = 1 
				end
				defender.Statuses[safeEffect] = appliedDur + 1
				effectLog = effectLog .. " <font color=\"#AA55FF\">[" .. safeEffect:upper() .. "]</font>"
			end
		end

		if isCrit or survivalTriggered then overallShake = "Heavy" elseif overallShake == "None" then overallShake = "Normal" end

		local hitMsg = fLogName .. " struck the <b>" .. targetLimb .. "</b> for " .. math.floor(baseDmg) .. " dmg!" .. effectLog
		if isCrit then hitMsg = hitMsg .. " <font color=\"#FFAA00\">(CRIT!)</font>" end
		if survivalTriggered then hitMsg = hitMsg .. " <font color=\"#FF55FF\">...TATAKAE! (Refused to yield!)</font>" end

		table.insert(hitLogs, hitMsg)
	end

	if didHitAtAll then
		attacker.MomentumStacks = math.min(10, (tonumber(attacker.MomentumStacks) or 0) + hitsToDo)
	else
		attacker.MomentumStacks = 0
	end

	local finalMsg = ""
	if hitsToDo > 1 then
		if not didHitAtAll then finalMsg = fLogName .. " unleashed <b>" .. skillName .. "</b>, but " .. fDefName .. " dodged completely!"
		else finalMsg = fLogName .. " used <b>" .. skillName .. "</b>!\n" .. table.concat(hitLogs, "\n") end
	else finalMsg = hitLogs[1] or (fLogName .. " used <b>" .. skillName .. "</b>!") end

	attacker.LastSkill = skillName
	return finalMsg, didHitAtAll, overallShake, totalDmgDealt
end

function CombatCore.ExecuteStrike(attacker, defender, skillName, targetLimb, logName, defName, logColor, defColor, battleContext)
	skillName = tostring(skillName or "Brutal Swipe")
	targetLimb = tostring(targetLimb or "Body")

	-- [[ FIX: INTERCEPT SHIFTED ARGUMENTS TO PREVENT TABLE ADDRESS LOGGING ]]
	if type(defColor) == "table" and battleContext == nil then
		battleContext = defColor
		defColor = defender.IsPlayer and "#FFFFFF" or "#FF5555"
	end

	-- Extract colors safely so strings are guaranteed to be proper hex formats
	local safeLogColor = (type(logColor) == "string" and string.match(logColor, "^#%w+")) and logColor or "#FFFFFF"
	local safeDefColor = (type(defColor) == "string" and string.match(defColor, "^#%w+")) and defColor or "#FF5555"

	local terrain = (battleContext and type(battleContext) == "table") and battleContext.Terrain or "City"
	local weather = (battleContext and type(battleContext) == "table") and battleContext.Weather or "Clear"

	local fallbackSkill = { Mult = 1.0, Cooldown = 0, Hits = 1, Effect = "None", Description = "A basic attack." }
	local skill = SkillData.Skills[skillName] or SkillData.Skills["Brutal Swipe"] or fallbackSkill

	-- Pre-build the base strings
	local aName = tostring(logName or "Attacker")
	local dName = tostring(defName or "Defender")
	local fLogName = "<font color=\"" .. safeLogColor .. "\">" .. aName .. "</font>"
	local fDefName = "<font color=\"" .. safeDefColor .. "\">" .. dName .. "</font>"

	if attacker.Cooldowns then attacker.Cooldowns[skillName] = tonumber(skill.Cooldown) or 0 end
	if not attacker.BaseMaxHP then attacker.BaseMaxHP = tonumber(attacker.MaxHP) or 100 end
	if not defender.BaseMaxHP then defender.BaseMaxHP = tonumber(defender.MaxHP) or 100 end

	local defGateHP = tonumber(defender.GateHP) or 0
	if (skill.Effect == "Dodge" or skill.Effect == "Block" or skillName == "Maneuver" or skillName == "Evasive Maneuver") and defender.GateType == "Steam" and defGateHP > 0 then 
		if attacker.Cooldowns then attacker.Cooldowns[skillName] = 0 end 
	end

	local isSequenceCombo = false; local comboMult = 1.0
	local lastAtkSkill = tostring(attacker.LastSkill or "None")
	if skill.ComboReq and lastAtkSkill == skill.ComboReq then 
		isSequenceCombo = true; comboMult = tonumber(skill.ComboMult) or 1.5 
	end

	local mult = tonumber(skill.Mult) or 1.0

	-- [[ FIX: REPLACED FLOGNAME WITH ANAME INSIDE FONT TAGS TO PREVENT NESTING CRASHES ]]
	if mult == 0 then
		if skill.Effect == "CloseGap" or skillName == "Close In" or skillName == "Advance" or skillName == "Charge" then
			attacker.LastSkill = skillName
			local moveWord = attacker.IsPlayer and "close" or "closes"
			if attacker.Statuses and attacker.Statuses["Transformed"] then
				return fLogName .. " used <b>" .. skillName .. "</b>!\n<font color=\"#FFAA00\">" .. aName .. " charges forward with immense speed!</font>", false, "Heavy"
			else
				return fLogName .. " used <b>" .. skillName .. "</b>!\n<font color=\"#55AAFF\">" .. aName .. " uses their ODM gear to " .. moveWord .. " the distance!</font>", false, "None"
			end

		elseif skill.Effect == "FallBack" or skillName == "Fall Back" then
			attacker.LastSkill = skillName
			local moveWord = attacker.IsPlayer and "fall" or "falls"
			return fLogName .. " used <b>" .. skillName .. "</b>!\n<font color=\"#FFAA55\">" .. aName .. " " .. moveWord .. " back to Long Range!</font>", false, "None"

		elseif skill.Effect == "Dodge" then
			if not attacker.Statuses then attacker.Statuses = {} end
			local blind = tonumber(attacker.Statuses.Blinded) or 0
			local trueBlind = tonumber(attacker.Statuses.TrueBlind) or 0
			if blind > 0 or trueBlind > 0 then return fLogName .. " attempted to use <b>" .. skillName .. "</b>, but stumbled due to blindness!", false, "None" end
			attacker.Statuses["Dodge"] = 1; attacker.LastSkill = skillName 
			return fLogName .. " used <b>" .. skillName .. "</b>!\n" .. aName .. " maneuvers rapidly, preparing to evade the next attack.", false, "None"

		elseif skill.Effect == "Block" then
			if not attacker.Statuses then attacker.Statuses = {} end
			attacker.Statuses["Block"] = 1; attacker.LastSkill = skillName 
			return fLogName .. " used <b>" .. skillName .. "</b>!\n" .. aName .. " braces for impact, massively increasing defense.", false, "None"

		elseif skill.Effect == "NapeGuard" then
			if not attacker.Statuses then attacker.Statuses = {} end
			attacker.Statuses["NapeGuard"] = (tonumber(skill.Duration) or 2) + 1
			attacker.LastSkill = skillName
			return fLogName .. " used <b>" .. skillName .. "</b>!\n<font color=\"#AA55FF\">[NAPE GUARDED]</font>", false, "None"

		elseif string.find(tostring(skill.Effect), "Buff_") then
			if not attacker.Statuses then attacker.Statuses = {} end
			attacker.Statuses[skill.Effect] = (tonumber(skill.Duration) or 2) + 1
			attacker.LastSkill = skillName
			return fLogName .. " used <b>" .. skillName .. "</b>!\n<font color=\"#AA55FF\">[" .. string.gsub(skill.Effect:upper(), "_", " ") .. " ACTIVATED]</font>", false, "None"

		elseif skill.Effect == "Rest" or skillName == "Recover" or skillName == "Regroup" then
			local healAmount = (tonumber(attacker.MaxHP) or 100) * 0.30
			attacker.HP = math.min(tonumber(attacker.MaxHP) or 100, (tonumber(attacker.HP) or 0) + healAmount); 

			if attacker.IsPlayer then
				attacker.Gas = tonumber(attacker.MaxGas) or 100
			end

			attacker.LastSkill = skillName
			local regroupWord = attacker.IsPlayer and "regroup" or "regroups"
			return fLogName .. " used <b>" .. skillName .. "</b>!\n<font color=\"#55FF55\">" .. aName .. " " .. regroupWord .. ", recovering HP and Gas.</font>", false, "None"

		elseif skill.Effect == "Transform" then
			local cName = attacker.Clan or "None"
			if attacker.IsPlayer and (string.find(cName, "Ackerman") or attacker.Titan == "None") then
				return fLogName .. " attempted to use <b>" .. skillName .. "</b>, but their lineage prevents Titan transformation!", false, "None"
			end
			if not attacker.Statuses then attacker.Statuses = {} end
			attacker.Statuses["Transformed"] = 999; attacker.LastSkill = skillName; 

			local tEnd = tonumber(attacker.PlayerObj:GetAttribute("Titan_Endurance_Val")) or 10
			local tPot = tonumber(attacker.PlayerObj:GetAttribute("Titan_Potential_Val")) or 10
			attacker.MaxHP = attacker.BaseMaxHP + ((tEnd + tPot) * 40) 
			attacker.HP = attacker.MaxHP
			attacker.TitanEnergy = tonumber(attacker.MaxTitanEnergy) or 100

			return fLogName .. " used <b>" .. skillName .. "</b>!\nLightning strikes as " .. aName .. " shifts into a Titan! <font color=\"#55FF55\">[MAX HP BOOSTED & HEAT Restored]</font>", false, "Heavy"

		elseif skill.Effect == "Eject" then
			if attacker.Statuses then attacker.Statuses["Transformed"] = nil end
			attacker.LastSkill = skillName
			attacker.MaxHP = attacker.BaseMaxHP
			attacker.HP = math.min(attacker.HP, attacker.MaxHP)
			return fLogName .. " used <b>" .. skillName .. "</b>!\n" .. aName .. " cuts themselves out of the nape, returning to human form.", false, "None"

		elseif skill.Effect == "TitanRest" or skillName == "Titan Recover" then
			local healAmount = (tonumber(attacker.MaxHP) or 100) * 0.60
			attacker.HP = math.min(tonumber(attacker.MaxHP) or 100, (tonumber(attacker.HP) or 0) + healAmount); attacker.LastSkill = skillName
			return fLogName .. " used <b>" .. skillName .. "</b>!\n<font color=\"#55FF55\">" .. aName .. " uses immense steam to regenerate " .. math.floor(healAmount) .. " HP.</font>", false, "None"
		end
	end

	local hitsToDo = tonumber(skill.Hits) or 1; local hitLogs = {}; local didHitAtAll = false; local overallShake = "None"

	local synergyTag = isSequenceCombo and " <font color=\"#FFD700\">[SYNERGY: " .. lastAtkSkill .. " -> " .. skillName .. "]</font>" or ""
	local synergyOwner = defender.SynergyOwners and defender.SynergyOwners[targetLimb]
	if defender.Statuses and defender.Statuses["SynergyMark_" .. targetLimb] and attacker.IsPlayer and attacker.PlayerObj and synergyOwner ~= attacker.PlayerObj.UserId then
		synergyTag = synergyTag .. " <font color=\"#55FFFF\"><b>[CO-OP TAKEDOWN!]</b></font>"
		defender.Statuses["SynergyMark_" .. targetLimb] = nil
	end

	local isAttackerTransformed = attacker.Statuses and (tonumber(attacker.Statuses.Transformed) or 0) > 0
	local isDefenderTransformed = defender.Statuses and (tonumber(defender.Statuses.Transformed) or 0) > 0

	local momentum = tonumber(attacker.MomentumStacks) or 0

	local atkSpd = tonumber(attacker.TotalSpeed) or 10
	local defSpd = tonumber(defender.TotalSpeed) or 10
	local atkRes = tonumber(attacker.TotalResolve) or 10
	local defRes = tonumber(defender.TotalResolve) or 10

	atkSpd = atkSpd * (1.0 + (momentum * 0.05))

	if attacker.Statuses and attacker.Statuses["Terror"] then
		atkSpd = atkSpd * 0.75
		atkRes = atkRes * 0.75
	end
	if defender.Statuses and defender.Statuses["Terror"] then
		defSpd = defSpd * 0.75
		defRes = defRes * 0.75
	end

	if attacker.IsPlayer and isAttackerTransformed and attacker.PlayerObj then
		atkSpd = (tonumber(attacker.PlayerObj:GetAttribute("Titan_Speed_Val")) or 10) * 3.0
		atkRes = tonumber(attacker.PlayerObj:GetAttribute("Titan_Endurance_Val")) or 10
	end
	if defender.IsPlayer and isDefenderTransformed and defender.PlayerObj then
		defSpd = (tonumber(defender.PlayerObj:GetAttribute("Titan_Speed_Val")) or 10) * 3.0
		defRes = tonumber(defender.PlayerObj:GetAttribute("Titan_Endurance_Val")) or 10
	end

	local aAwk = string.find(tostring(attacker.Clan or ""), "Awakened") ~= nil or string.find(tostring(attacker.Clan or ""), "Abyssal") ~= nil
	local dAwk = string.find(tostring(defender.Clan or ""), "Awakened") ~= nil or string.find(tostring(defender.Clan or ""), "Abyssal") ~= nil

	local aStats = attacker.IsPlayer and ClanData.GetClanStats(attacker.Clan, aAwk, attacker.Titan, isAttackerTransformed) or ClanData.GetClanStats()
	local dStats = defender.IsPlayer and ClanData.GetClanStats(defender.Clan, dAwk, defender.Titan, isDefenderTransformed) or ClanData.GetClanStats()

	atkSpd = atkSpd * aStats.SpdMult; atkRes = atkRes * aStats.ResolveMult
	defSpd = defSpd * dStats.SpdMult; defRes = defRes * dStats.ResolveMult

	if weather == "Night" and not defender.IsPlayer and not isDefenderTransformed then
		if not defender.Name:find("Titan") or defender.Name == "Field Titan" or defender.Name == "3-Meter Pure Titan" then
			defSpd = defSpd * 0.5
		end
	end

	local appliedThisStrike = {}

	for i = 1, hitsToDo do
		local currentDefHP = tonumber(defender.HP) or 0
		if currentDefHP < 1 and i > 1 then break end 

		if defender.Statuses and defender.Statuses["CounterStance"] and (skill.Range ~= "Long" and not skill.Unavoidable) then
			local counterDmg = math.floor((defender.TotalStrength or 10) * 1.5)
			attacker.HP = math.max(1, (tonumber(attacker.HP) or 10) - counterDmg)
			table.insert(hitLogs, fLogName .. " attacked, but " .. fDefName .. " was in a <font color=\"#FF3333\"><b>COUNTER STANCE</b></font>! " .. aName .. " was instantly interrupted and took " .. counterDmg .. " counter-damage!")
			didHitAtAll = false
			break
		end

		local isDodging = false
		if defender.Statuses then
			if (tonumber(defender.Statuses.Dodge) or 0) > 0 then isDodging = true end
			if (tonumber(defender.Statuses.Crippled) or 0) > 0 then defSpd = defSpd * 0.5 end
			if (tonumber(defender.Statuses.Immobilized) or 0) > 0 then defSpd = 0 end
		end

		local dodgeChance = 5 + ((defSpd - atkSpd) * 0.08) 
		local targetCrip = defender.Statuses and (tonumber(defender.Statuses.Crippled) or 0) > 0
		if targetLimb == "Nape" and not targetCrip then dodgeChance = dodgeChance + 15 end

		dodgeChance += dStats.DodgeBonus
		if weather == "Rain" then dodgeChance += 15 end
		if terrain == "Forest" and defender.IsPlayer and not isDefenderTransformed then dodgeChance += 20 end
		if terrain == "Plains" and defender.IsPlayer and not isDefenderTransformed then dodgeChance -= 20 end

		if defender.AwakenedStats and (tonumber(defender.AwakenedStats.DodgeBonus) or 0) > 0 then dodgeChance = dodgeChance + tonumber(defender.AwakenedStats.DodgeBonus) end

		if defender.IsPlayer and defender.PlayerObj then
			if isDefenderTransformed then
				local tPotential = tonumber(defender.PlayerObj:GetAttribute("Titan_Potential_Val")) or 10
				dodgeChance = dodgeChance + (tPotential * 0.25)
			else
				dodgeChance = dodgeChance + (tonumber(defender.PlayerObj:GetAttribute("Prestige_DodgeBonus")) or 0)
				local accName = defender.PlayerObj:GetAttribute("EquippedAccessory")
				local accData = accName and ItemData.Equipment[accName]
				if accData and accData.NoDodge then dodgeChance = 0; isDodging = false end

				local setBonus = GetSetBonus(defender.PlayerObj)
				if setBonus and setBonus.DodgeBonus then dodgeChance = dodgeChance + setBonus.DodgeBonus end
			end
		end

		local titanNameCheck = ""
		if not defender.IsPlayer then titanNameCheck = defender.Name or ""
		elseif defender.Statuses and (tonumber(defender.Statuses.Transformed) or 0) > 0 then titanNameCheck = tostring(defender.Titan or "None") end

		if titanNameCheck ~= "" then
			if string.find(titanNameCheck, "Founding Titan") or string.find(titanNameCheck, "Colossal") then dodgeChance = dodgeChance - 40 
			elseif string.find(titanNameCheck, "Beast Titan") then dodgeChance = dodgeChance - 20 
			elseif string.find(titanNameCheck, "Armored Titan") then dodgeChance = dodgeChance - 15 
			elseif string.find(titanNameCheck, "Female Titan") then dodgeChance = dodgeChance - 10 end
		end

		local effectLog = ""

		if skill.Unavoidable then 
			dodgeChance = 0
			if isDodging then 
				isDodging = false
				if skill.Range == "Any" then
					effectLog = effectLog .. "\n<font color=\"#FF3333\"><b>[DODGE FAILED: AREA ATTACK IS UNAVOIDABLE! YOU MUST BLOCK!]</b></font>"
				else
					effectLog = effectLog .. "\n<font color=\"#FF3333\"><b>[DODGE FAILED: ATTACK IS UNAVOIDABLE! YOU MUST FALL BACK OR BLOCK!]</b></font>"
				end
			end
		elseif isDodging then 
			dodgeChance = 100 
		elseif not defender.IsPlayer then 
			dodgeChance = math.clamp(dodgeChance, 0, 20)
		else 
			dodgeChance = math.clamp(dodgeChance, 0, 75) 
		end

		if isDodging and defender.Statuses and (tonumber(defender.Statuses.Immobilized) or 0) > 0 then
			dodgeChance = 0; isDodging = false
			effectLog = effectLog .. " <font color=\"#FF5555\">[IMMOBILIZED: Dodge Failed!]</font>"
		end

		if defender.Statuses and (tonumber(defender.Statuses.Immobilized) or 0) > 0 then dodgeChance = 0 end

		if math.random(1, 100) <= (dodgeChance or 0) then
			if hitsToDo == 1 then 
				local dodgeMsg = isDodging and " (Maneuvered)" or ""
				if attacker.IsPlayer then table.insert(hitLogs, fLogName .. " aimed for the <b>" .. targetLimb .. "</b>, but " .. fDefName .. " dodged!" .. dodgeMsg)
				else table.insert(hitLogs, fLogName .. " attacked, but " .. fDefName .. " dodged!" .. dodgeMsg) end
			else table.insert(hitLogs, "<font color=\"#AAAAAA\">- Hit " .. i .. " missed!</font>") end
			continue
		end

		didHitAtAll = true

		local critChance = 5 + ((atkRes - defRes) * 0.10)
		if attacker.AwakenedStats and (tonumber(attacker.AwakenedStats.CritBonus) or 0) > 0 then critChance = critChance + tonumber(attacker.AwakenedStats.CritBonus) end

		if attacker.IsPlayer and attacker.PlayerObj then
			if isAttackerTransformed then
				local tPrecision = tonumber(attacker.PlayerObj:GetAttribute("Titan_Precision_Val")) or 10
				critChance = critChance + (tPrecision * 0.25)
			else
				critChance += aStats.CritBonus
				critChance = critChance + (tonumber(attacker.PlayerObj:GetAttribute("Prestige_CritBonus")) or 0)
				local setBonus = GetSetBonus(attacker.PlayerObj)
				if setBonus and setBonus.CritBonus then critChance = critChance + setBonus.CritBonus end
			end
			critChance = math.clamp(critChance, 5, 75)
		else critChance = math.clamp(critChance, 5, 25) end

		local isCrit = math.random(1, 100) <= (critChance or 0)
		local dmgMultValue = (tonumber(skill.Mult) or 1.0) * (isCrit and 1.5 or 1.0) * comboMult

		if skillName == "Titan Kick" and defender.Statuses and defender.Statuses["Lacerate"] then
			local stacks = tonumber(defender.Statuses["Lacerate"]) or 1
			dmgMultValue = dmgMultValue + (0.5 * stacks)
			defender.Statuses["Lacerate"] = nil
			effectLog = effectLog .. " <font color=\"#FF0000\"><b>[LACERATE DETONATED!]</b></font>"
		end
		if skillName == "Titan Punch" and defender.Statuses and defender.Statuses["Confusion"] then
			if not defender.Statuses then defender.Statuses = {} end
			defender.Statuses["Stun"] = 2
			defender.Statuses["Confusion"] = nil
			effectLog = effectLog .. " <font color=\"#FFFF00\"><b>[CONFUSION EXPLOITED -> STUNNED!]</b></font>"
		end

		local baseDmg = CombatCore.CalculateDamage(attacker, defender, dmgMultValue, targetLimb, battleContext)
		local survivalTriggered, hitGate, gateBroken, hpDmg, gateName = CombatCore.TakeDamage(defender, baseDmg, attacker.Style)

		local isArmored = defender.GateType == "Reinforced Skin" and (tonumber(defender.GateHP) or 0) > 0

		if skill.Effect == "CloseGap" then effectLog = effectLog .. " <font color=\"#55AAFF\">[CLOSED DISTANCE]</font>"
		elseif skill.Effect == "FallBack" then effectLog = effectLog .. " <font color=\"#FFAA55\">[RETREATED]</font>" end

		if skill.Effect and skill.Effect ~= "None" and skill.Effect ~= "Block" and skill.Effect ~= "Dodge" and skill.Effect ~= "Rest" and skill.Effect ~= "Flee" and skill.Effect ~= "Transform" and skill.Effect ~= "Eject" and skill.Effect ~= "TitanRest" and skill.Effect ~= "FallBack" and skill.Effect ~= "CloseGap" then
			if not defender.Statuses then defender.Statuses = {} end
			local safeEffect = tostring(skill.Effect)

			if safeEffect == "RestoreHeat" then
				if attacker.IsPlayer then
					local pNrg = tonumber(attacker.TitanEnergy) or 0; local maxNrg = tonumber(attacker.MaxTitanEnergy) or 100
					attacker.TitanEnergy = math.min(maxNrg, pNrg + 40)
					local pHP = tonumber(attacker.HP) or 0; local maxHP = tonumber(attacker.MaxHP) or 100
					attacker.HP = math.min(maxHP, pHP + (maxHP * 0.15))
					effectLog = effectLog .. " <font color=\"#55FF55\">[+40 HEAT | +15% HP]</font>"
				end
			else
				local currentEffect = tonumber(defender.Statuses[safeEffect]) or 0
				local currentImmunity = tonumber(defender.Statuses[safeEffect .. "Immunity"]) or 0

				local isBossImmune = (defender.IsBoss and defender.Statuses and defender.Statuses["Telegraphing"]) or (defender.Statuses and defender.Statuses["Enraged"])
				local isShroudImmune = false
				if safeEffect == "Stun" and defender.IsPlayer and defender.PlayerObj then
					local acc = defender.PlayerObj:GetAttribute("EquippedAccessory")
					if acc and string.find(acc, "Shroud") then isShroudImmune = true end
				end

				if isShroudImmune then
					effectLog = effectLog .. " <font color=\"#888888\">[SHROUD: STUN IMMUNE]</font>"
					appliedThisStrike[safeEffect] = true
				elseif isBossImmune and (safeEffect == "Stun" or safeEffect == "Bleed" or safeEffect == "Blinded" or safeEffect == "TrueBlind" or safeEffect == "Crippled" or safeEffect == "Weakened" or safeEffect == "Confusion" or safeEffect == "Terror") then
					effectLog = effectLog .. " <font color=\"#FF0000\">[BOSS IMMUNE]</font>"
					appliedThisStrike[safeEffect] = true
				elseif isArmored and (safeEffect == "Stun" or safeEffect == "Bleed" or safeEffect == "Blinded" or safeEffect == "TrueBlind" or safeEffect == "Crippled" or safeEffect == "Weakened" or safeEffect == "Confusion" or safeEffect == "Terror") then
					effectLog = effectLog .. " <font color=\"#888888\">[ARMOR RESISTS EFFECT]</font>"
				elseif currentImmunity > 0 then effectLog = effectLog .. " <font color=\"#888888\">[IMMUNITY ACTIVE]</font>"
				elseif safeEffect == "GasDrain" then
					if defender.IsPlayer then
						defender.Gas = math.max(0, (tonumber(defender.Gas) or 0) - 40)
						effectLog = effectLog .. " <font color=\"#FF5555\">[-40 GAS]</font>"
					end
				elseif string.find(safeEffect, "Buff_") then
					if not attacker.Statuses then attacker.Statuses = {} end
					if not appliedThisStrike[safeEffect] then
						attacker.Statuses[safeEffect] = (tonumber(skill.Duration) or 2) + 1
						effectLog = effectLog .. " <font color=\"#55FF55\">[" .. string.gsub(safeEffect:upper(), "_", " ") .. "]</font>"
						appliedThisStrike[safeEffect] = true
					end
				else
					if safeEffect == "Bleed" then
						local curLac = tonumber(defender.Statuses["Lacerate"]) or 0
						if curLac > 0 then
							defender.Statuses["Lacerate"] = math.min(3, curLac + 1)
							effectLog = effectLog .. " <font color=\"#AA0000\">[LACERATE x" .. defender.Statuses["Lacerate"] .. "]</font>"
						elseif currentEffect > 0 then
							defender.Statuses["Bleed"] = nil
							defender.Statuses["Lacerate"] = 1
							effectLog = effectLog .. " <font color=\"#AA0000\">[DEEP WOUND: LACERATE!]</font>"
						else
							defender.Statuses["Bleed"] = (tonumber(skill.Duration) or 2) + 1
							effectLog = effectLog .. " <font color=\"#FF5555\">[BLEED]</font>"
						end
						appliedThisStrike["Bleed"] = true
					elseif not appliedThisStrike[safeEffect] then
						local appliedDur = tonumber(skill.Duration) or 2

						if safeEffect == "Stun" or safeEffect == "Immobilized" or safeEffect == "TrueBlind" or safeEffect == "Confusion" or safeEffect == "Terror" then
							appliedDur = 1 
						elseif weather == "Rain" and safeEffect == "Burn" then 
							appliedDur = math.ceil(appliedDur / 2) 
						end

						if defender.IsBoss and (safeEffect == "Blinded" or safeEffect == "Crippled") then
							appliedDur = 1
						elseif safeEffect ~= "Bleed" and safeEffect ~= "Burn" then 
							appliedDur = appliedDur + 1 
						end

						defender.Statuses[safeEffect] = appliedDur
						effectLog = effectLog .. " <font color=\"#AA55FF\">[" .. safeEffect:upper() .. "]</font>"
						appliedThisStrike[safeEffect] = true
					end
				end
			end
		end

		if isArmored and (targetLimb == "Legs" or targetLimb == "Arms" or targetLimb == "Eyes") then effectLog = effectLog .. " <font color=\"#888888\">[ARMOR DEFLECTS DEBUFF]</font>"
		else
			if targetLimb == "Legs" and attacker.IsPlayer and not defender.IsHuman then
				if not defender.Statuses then defender.Statuses = {} end
				local cripStatus = tonumber(defender.Statuses["Crippled"]) or 0
				local immobStatus = tonumber(defender.Statuses["Immobilized"]) or 0
				local cripImm = tonumber(defender.Statuses["CrippledImmunity"]) or 0
				local immobImm = tonumber(defender.Statuses["ImmobilizedImmunity"]) or 0

				if defender.Statuses["Enraged"] then
					effectLog = effectLog .. " <font color=\"#FF0000\">[ENRAGE: IMMUNE]</font>"
					appliedThisStrike["Crippled"] = true
					appliedThisStrike["Immobilized"] = true
				elseif cripStatus > 0 or immobStatus > 0 then
					if cripStatus > 0 and immobStatus == 0 and not appliedThisStrike["Crippled"] then 
						defender.Statuses["Immobilized"] = defender.IsBoss and 1 or 2
						defender.Statuses["Crippled"] = nil
						effectLog = effectLog .. " <font color=\"#00FF00\">[IMMOBILIZED]</font>"
						appliedThisStrike["Immobilized"] = true
					else effectLog = effectLog .. " <font color=\"#888888\">[ALREADY ACTIVE]</font>" end
				elseif cripImm > 0 or immobImm > 0 then effectLog = effectLog .. " <font color=\"#888888\">[IMMUNITY ACTIVE]</font>"
				else 
					defender.Statuses["Crippled"] = defender.IsBoss and 1 or 2
					effectLog = effectLog .. " <font color=\"#55FF55\">[CRIPPLED]</font>" 
					appliedThisStrike["Crippled"] = true
				end

			elseif targetLimb == "Arms" and attacker.IsPlayer and not defender.IsHuman then
				if not defender.Statuses then defender.Statuses = {} end
				local weakStatus = tonumber(defender.Statuses["Weakened"]) or 0
				local weakImm = tonumber(defender.Statuses["WeakenedImmunity"]) or 0

				if defender.Statuses["Enraged"] then
					effectLog = effectLog .. " <font color=\"#FF0000\">[ENRAGE: IMMUNE]</font>"
					appliedThisStrike["Weakened"] = true
				elseif weakStatus > 0 then effectLog = effectLog .. " <font color=\"#888888\">[ALREADY ACTIVE]</font>"
				elseif weakImm > 0 then effectLog = effectLog .. " <font color=\"#888888\">[IMMUNITY ACTIVE]</font>"
				else 
					if not appliedThisStrike["Weakened"] then
						defender.Statuses["Weakened"] = 2; effectLog = effectLog .. " <font color=\"#FFDD55\">[WEAKENED]</font>" 
						appliedThisStrike["Weakened"] = true
					end
				end

			elseif targetLimb == "Eyes" and attacker.IsPlayer and not defender.IsHuman then
				if not defender.Statuses then defender.Statuses = {} end
				local tblBlind = tonumber(defender.Statuses["TrueBlind"]) or 0
				local blStatus = tonumber(defender.Statuses["Blinded"]) or 0
				local blImm = tonumber(defender.Statuses["BlindedImmunity"]) or 0
				local tblImm = tonumber(defender.Statuses["TrueBlindImmunity"]) or 0

				if defender.Statuses["Enraged"] then
					effectLog = effectLog .. " <font color=\"#FF0000\">[ENRAGE: IMMUNE]</font>"
					appliedThisStrike["Blinded"] = true
					appliedThisStrike["TrueBlind"] = true
				elseif tblBlind > 0 then effectLog = effectLog .. " <font color=\"#888888\">[ALREADY ACTIVE]</font>"
				elseif blImm > 0 or tblImm > 0 then effectLog = effectLog .. " <font color=\"#888888\">[IMMUNITY ACTIVE]</font>"
				else
					if blStatus > 0 and not appliedThisStrike["Blinded"] then 
						defender.Statuses["TrueBlind"] = defender.IsBoss and 1 or 2
						defender.Statuses["Blinded"] = nil
						effectLog = effectLog .. " <font color=\"#555555\">[TRUE BLINDNESS]</font>" 
						appliedThisStrike["TrueBlind"] = true
					elseif blStatus == 0 then 
						if not appliedThisStrike["Blinded"] then
							defender.Statuses["Blinded"] = defender.IsBoss and 1 or 2
							effectLog = effectLog .. " <font color=\"#DDDDDD\">[BLINDED]</font>" 
							appliedThisStrike["Blinded"] = true
						end
					else
						effectLog = effectLog .. " <font color=\"#888888\">[ALREADY ACTIVE]</font>"
					end
				end
			end
		end

		if targetLimb == "Nape" and defender.Statuses and (tonumber(defender.Statuses["NapeGuard"]) or 0) > 0 then effectLog = effectLog .. " <font color=\"#AAAAAA\">[BLOCKED BY NAPE GUARD]</font>" end
		if isCrit or survivalTriggered then overallShake = "Heavy" elseif overallShake == "None" then overallShake = "Normal" end

		local hitMsg = ""
		if attacker.IsPlayer then hitMsg = hitsToDo == 1 and (fLogName .. " struck the <b>" .. targetLimb .. "</b>" .. synergyTag .. " for " .. math.floor(baseDmg) .. " dmg!" .. effectLog) or ("- Hit " .. i .. " dealt " .. math.floor(baseDmg) .. " damage" .. effectLog)
		else hitMsg = hitsToDo == 1 and (fLogName .. " struck you" .. synergyTag .. " for " .. math.floor(baseDmg) .. " dmg!" .. effectLog) or ("- Hit " .. i .. " dealt " .. math.floor(baseDmg) .. " damage" .. effectLog) end

		if skill.Unavoidable and not attacker.IsPlayer then hitMsg = hitMsg .. " <font color=\"#FF5555\">[UNAVOIDABLE]</font>" end
		if isCrit then hitMsg = hitMsg .. " <font color=\"#FFAA00\">(CRIT!)</font>" end
		if defender.GateType == "Steam" and hitGate then hitMsg = hitMsg .. " <font color=\"#FFAAAA\">(Repelled by Steam!)</font>"
		elseif hitGate then hitMsg = hitMsg .. " <font color=\"#DDDDDD\">[Hit " .. tostring(gateName) .. "!]</font>" end
		if gateBroken then hitMsg = hitMsg .. " <font color=\"#FFFFFF\"><b>[" .. tostring(gateName):upper() .. " SHATTERED!]</b></font>" end
		if survivalTriggered then hitMsg = hitMsg .. " <font color=\"#FF55FF\">...TATAKAE! (Refused to yield!)</font>" end

		table.insert(hitLogs, hitMsg)
	end

	if attacker.IsPlayer and didHitAtAll and attacker.PlayerObj then
		if not defender.Statuses then defender.Statuses = {} end
		if not defender.SynergyOwners then defender.SynergyOwners = {} end
		defender.Statuses["SynergyMark_" .. targetLimb] = 2 
		defender.SynergyOwners[targetLimb] = attacker.PlayerObj.UserId
	end

	if didHitAtAll then
		attacker.MomentumStacks = math.min(10, (tonumber(attacker.MomentumStacks) or 0) + hitsToDo)
	elseif attacker.IsPlayer then
		attacker.MomentumStacks = 0
	end

	local finalMsg = ""
	if hitsToDo > 1 then
		if not didHitAtAll then finalMsg = fLogName .. " unleashed <b>" .. skillName .. "</b>, but " .. fDefName .. " dodged completely!"
		else finalMsg = fLogName .. " used <b>" .. skillName .. "</b>!" .. synergyTag .. "\n" .. table.concat(hitLogs, "\n") end
	else finalMsg = hitLogs[1] or "" end

	if attacker.IsPlayer and didHitAtAll and attacker.PlayerObj then
		local wpnName = attacker.PlayerObj:GetAttribute("EquippedWeapon")
		local wpnData = wpnName and ItemData.Equipment[wpnName]
		if wpnData and wpnData.SelfDamage then
			local recoil = math.floor((tonumber(attacker.MaxHP) or 100) * wpnData.SelfDamage)
			attacker.HP = math.max(1, (tonumber(attacker.HP) or 100) - recoil)
			finalMsg = finalMsg .. "\n<font color=\"#FF3333\">[" .. aName .. " took " .. recoil .. " recoil damage from their Cursed Weapon!]</font>"
		end
	end

	attacker.LastSkill = skillName
	return finalMsg, didHitAtAll, overallShake
end

return CombatCore