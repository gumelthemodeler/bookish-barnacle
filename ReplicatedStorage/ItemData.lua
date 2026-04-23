-- @ScriptType: ModuleScript
-- @ScriptType: ModuleScript
local ItemData = {}

ItemData.Equipment = {
	-- [[ STANDARD EQUIPMENT ]]
	["Training Dummy Sword"] = { Type = "Weapon", Style = "None", Rarity = "Common", Cost = 250, Bonus = { Strength = 1 }, Desc = "A blunt wooden sword. Practically useless." },
	["Cadet Training Blade"] = { Type = "Weapon", Style = "None", Rarity = "Common", Cost = 500, Bonus = { Strength = 2, Speed = 2 }, Desc = "Standard issue cadet blade." },
	["Garrison Standard Blades"] = { Type = "Weapon", Style = "Ultrahard Steel Blades", Rarity = "Uncommon", Cost = 1200, Bonus = { Strength = 6, Speed = 4 }, Desc = "Standard blades used by the Garrison Regiment." },
	["Marleyan Rifle"] = { Type = "Weapon", Style = "Anti-Personnel", Rarity = "Uncommon", Cost = 1500, Bonus = { Strength = 25, Defense = 5 }, Desc = "Standard Marleyan military rifle." },
	["Ultrahard Steel Blades"] = { Type = "Weapon", Style = "Ultrahard Steel Blades", Rarity = "Rare", Cost = 2500, Bonus = { Strength = 15, Speed = 10 }, Desc = "The staple weapon of the Scout Regiment." },
	["Advanced ODM Gear"] = { Type = "Weapon", Style = "Ultrahard Steel Blades", Rarity = "Epic", Cost = 5000, Bonus = { Strength = 20, Speed = 25, Gas = 10 }, Desc = "A highly maneuverable rig designed for elite Scouts." },
	["Anti-Personnel Pistols"] = { Type = "Weapon", Style = "Anti-Personnel", Rarity = "Rare", Cost = 3000, Bonus = { Speed = 20, Strength = 10 }, Desc = "Designed to kill humans, not titans." },
	["Prototype Thunder Spear"] = { Type = "Weapon", Style = "Thunder Spears", Rarity = "Rare", Cost = 3500, Bonus = { Strength = 20, Speed = -2 }, Desc = "An early, unstable version of the Thunder Spear." },
	["Veteran Scout Blades"] = { Type = "Weapon", Style = "Ultrahard Steel Blades", Rarity = "Epic", Cost = 7500, Bonus = { Strength = 25, Speed = 15, Resolve = 10 }, Desc = "Perfectly honed blades used by surviving veterans." },
	["Thunder Spear"] = { Type = "Weapon", Style = "Thunder Spears", Rarity = "Epic", Cost = 8000, Bonus = { Strength = 35, Speed = -5 }, Desc = "High-explosive anti-armor weaponry." },
	["Iceburst Steel Blades"] = { Type = "Weapon", Style = "Ultrahard Steel Blades", Rarity = "Legendary", Cost = 30000, Bonus = { Strength = 50, Speed = 35, Gas = 20 }, Desc = "Forged from rare Iceburst stone. Never dulls." },
	["Titan-Killer Artillery"] = { Type = "Weapon", Style = "Anti-Personnel", Rarity = "Legendary", Cost = 35000, Bonus = { Strength = 65, Defense = 10, Speed = -10 }, Desc = "A portable anti-titan cannon. Devastating power." },
	["Kenny's Custom Pistols"] = { Type = "Weapon", Style = "Anti-Personnel", Rarity = "Legendary", Cost = 45000, Bonus = { Speed = 50, Strength = 40 }, Desc = "The legendary weapons of Kenny the Ripper." },

	["Worn Trainee Badge"] = { Type = "Accessory", Rarity = "Common", Cost = 300, Bonus = { Resolve = 2, Health = 2 }, Desc = "A badge worn by new recruits." },
	["Scout Training Manual"] = { Type = "Accessory", Rarity = "Common", Cost = 500, Bonus = { Resolve = 5 }, Desc = "Basic training guidelines." },
	["Garrison Hip Flask"] = { Type = "Accessory", Rarity = "Uncommon", Cost = 1200, Bonus = { Health = 30, Resolve = 5 }, Desc = "Liquid courage for the wall guards." },
	["Marleyan Armband"] = { Type = "Accessory", Rarity = "Uncommon", Cost = 1500, Bonus = { Defense = 5, Strength = 5 }, Desc = "An armband worn by Marleyan forces." },
	["Scout Regiment Cloak"] = { Type = "Accessory", Rarity = "Rare", Cost = 2500, Bonus = { Defense = 20, Resolve = 15 }, Desc = "The Wings of Freedom." },
	["Marleyan Combat Manual"] = { Type = "Accessory", Rarity = "Rare", Cost = 3000, Bonus = { Strength = 15, Resolve = 10 }, Desc = "Advanced military tactics." },
	["Commander's Bolo Tie"] = { Type = "Accessory", Rarity = "Epic", Cost = 8000, Bonus = { Resolve = 30, Defense = 30 }, Desc = "Worn by the commander of the Scouts." },
	["Hardened Titan Crystal"] = { Type = "Accessory", Rarity = "Epic", Cost = 12000, Bonus = { Defense = 60, Health = 50 }, Desc = "A chunk of dense Titan hardening." },
	["Hange's Goggles"] = { Type = "Accessory", Rarity = "Epic", Cost = 15000, Bonus = { Speed = 25, Gas = 20 }, Desc = "Protects the eyes during high-speed maneuvers." },
	["Mikasa's Scarf"] = { Type = "Accessory", Rarity = "Legendary", Cost = 40000, Bonus = { Strength = 50, Speed = 30, Resolve = 25 }, Desc = "A warm, red scarf. Fills you with a burning resolve." },
	["Erwin's Pendant"] = { Type = "Accessory", Rarity = "Legendary", Cost = 45000, Bonus = { Resolve = 60, Defense = 30, Health = 80 }, Desc = "A symbol of absolute, unwavering leadership." },
	["Coordinate's Sand"] = { Type = "Accessory", Rarity = "Mythical", Cost = 250000, Bonus = { Strength = 50, Defense = 50, Speed = 50, Resolve = 50, Gas = 50, Health = 50 }, Desc = "A handful of sand from the Paths. Godlike power." },

	["Blade of the Frenzied"] = { Type = "Weapon", Style = "Ultrahard Steel Blades", Rarity = "Transcendent", Cost = 1000000, Bonus = { Strength = 400, Speed = 100, Defense = -100 }, Cursed = true, SelfDamage = 0.05, Desc = "<font color='#FF3333'>[CURSED]</font> Insane damage, but you take 5% Max HP damage every time you attack. Halves your Defense." },
	["Abyssal Thunder Spear"] = { Type = "Weapon", Style = "Thunder Spears", Rarity = "Transcendent", Cost = 1000000, Bonus = { Strength = 800, Speed = -50 }, Cursed = true, SelfDamage = 0.10, Desc = "<font color='#FF3333'>[CURSED]</font> A nuclear payload. You take 10% Max HP damage on launch. Sluggish speed." },
	["Shroud of the Doomed"] = { Type = "Accessory", Rarity = "Transcendent", Cost = 1000000, Bonus = { Resolve = 500, Health = 500, Defense = 200 }, Cursed = true, NoDodge = true, Desc = "<font color='#FF3333'>[CURSED]</font> Makes you incredibly tanky and immune to stun, but permanently drops your Dodge chance to 0%." },

	["Eldian Crown"] = { Type = "Accessory", Rarity = "Transcendent", Cost = 0, Bonus = { Strength = 300, Defense = 300, Resolve = 1000 }, Desc = "<font color='#FFD700'>[EXCLUSIVE PATHS RELIC]</font> The crown of the ancient Eldian Empire. Grants massive vitality and damage scaling." },
	["Founder's Parasite"] = { Type = "Accessory", Rarity = "Transcendent", Cost = 0, Bonus = { Health = 2000, Speed = 150, Gas = 150 }, Desc = "<font color='#55FF55'>[MYTHIC PATHS RELIC]</font> The origin of all organic matter. Grants godlike health, extreme agility, and boundless stamina." }
}

ItemData.Consumables = {
	["Standard Titan Serum"] = { Rarity = "Rare", Cost = 5000, Desc = "Used in the Inherit tab to roll for a Titan." },
	["Spinal Fluid Syringe"] = { Rarity = "Legendary", Cost = 25000, Desc = "Premium item. Guarantees a Legendary or Mythical Titan." },
	["Clan Blood Vial"] = { Rarity = "Epic", Cost = 10000, Desc = "Used to roll for Clan Lineages." },

	-- [[ THE FIX: Added Legendary Clan Vial ]]
	["Legendary Clan Vial"] = { Rarity = "Legendary", Cost = 25000, Desc = "Premium item. Guarantees a Legendary or Mythical Clan Lineage." },

	["Ancestral Awakening Serum"] = { Rarity = "Mythical", Cost = 150000, Action = "AwakenClan", Desc = "Awakens the true power of your current lineage. Only works on major clans." },
	["Ymir's Clay Fragment"] = { Rarity = "Mythical", Cost = 150000, Action = "AwakenTitan", Desc = "Allows the Attack Titan to reach the Coordinate." },
	["Titan Hardening Extract"] = { Rarity = "Legendary", Cost = 75000, IsMaterial = true, Desc = "(Obtained in the Supply Shop) Used in the Forge to Awaken max-tier weapons with random Substats." },

	["Iron Bamboo Heart"] = { Rarity = "Epic", Cost = 3000, IsMaterial = true, Desc = "A rare material extracted from the Titan Forest via Expeditions. Used for complex forging." },
	["Glowing Titan Crystal"] = { Rarity = "Legendary", Cost = 10000, IsMaterial = true, Desc = "A dense energy crystal found deep in Expeditions. Highly sought after by Hange." },
	["Abyssal Blood"] = { Rarity = "Mythical", Cost = 50000, IsMaterial = true, Desc = "A terrifying black liquid dropped only by Nightmare Bosses. Used to forge Cursed gear." },

	["Coordinate Shard"] = { Rarity = "Mythical", Cost = 250000, IsMaterial = true, Desc = "A literal fragment of the Paths. One of the rarest materials in existence." },

	["Iron Bamboo Extract"] = { Rarity = "Epic", Cost = 8000, Action = "Consume", Buff = "Damage", Duration = 900, Desc = "Increases all damage dealt by 50% for 15 minutes." },
	["Titan Research Notes"] = { Rarity = "Rare", Cost = 5000, Action = "Consume", Buff = "XP", Duration = 900, Desc = "Doubles all XP gained from combat and training for 15 minutes." },
	["Garrison Supply Crate"] = { Rarity = "Uncommon", Cost = 15000, Action = "Consume", Buff = "Dews", MinAmount = 5000, MaxAmount = 20000, Desc = "Instantly grants between 5,000 and 20,000 Dews when opened." },

	["Scout's Clover"] = { Rarity = "Rare", Cost = 5000, Action = "Consume", Buff = "Luck", Duration = 900, LuckBoost = 1.25, Desc = "A lucky clover. Increases item drop rates by 25% for 15 minutes." },
	["Ymir's Blessing"] = { Rarity = "Epic", Cost = 15000, Action = "Consume", Buff = "Luck", Duration = 900, LuckBoost = 1.50, Desc = "A strange resonance from the Paths. Increases item drop rates by 50% for 15 minutes." },
	["Tears of the Founder"] = { Rarity = "Legendary", Cost = 50000, Action = "Consume", Buff = "Luck", Duration = 1800, LuckBoost = 2.0, Desc = "A crystallized tear from the Paths. Doubles all item drop rates for 30 minutes." },

	["Itemized Attack Titan"] = { Rarity = "Epic", Cost = 25000, Action = "EquipTitan", TitanName = "Attack Titan", Desc = "An extracted spinal fluid syringe of the Attack Titan. Consume to inherit." },
	["Itemized Jaw Titan"] = { Rarity = "Epic", Cost = 25000, Action = "EquipTitan", TitanName = "Jaw Titan", Desc = "An extracted spinal fluid syringe of the Jaw Titan. Consume to inherit." },
	["Itemized Cart Titan"] = { Rarity = "Rare", Cost = 25000, Action = "EquipTitan", TitanName = "Cart Titan", Desc = "An extracted spinal fluid syringe of the Cart Titan. Consume to inherit." },
	["Itemized Armored Titan"] = { Rarity = "Legendary", Cost = 25000, Action = "EquipTitan", TitanName = "Armored Titan", Desc = "An extracted spinal fluid syringe of the Armored Titan. Consume to inherit." },
	["Itemized Female Titan"] = { Rarity = "Legendary", Cost = 25000, Action = "EquipTitan", TitanName = "Female Titan", Desc = "An extracted spinal fluid syringe of the Female Titan. Consume to inherit." },
	["Itemized War Hammer Titan"] = { Rarity = "Legendary", Cost = 25000, Action = "EquipTitan", TitanName = "War Hammer Titan", Desc = "An extracted spinal fluid syringe of the War Hammer Titan. Consume to inherit." },
	["Itemized Beast Titan"] = { Rarity = "Mythical", Cost = 25000, Action = "EquipTitan", TitanName = "Beast Titan", Desc = "An extracted spinal fluid syringe of the Beast Titan. Consume to inherit." },
	["Itemized Colossal Titan"] = { Rarity = "Mythical", Cost = 25000, Action = "EquipTitan", TitanName = "Colossal Titan", Desc = "An extracted spinal fluid syringe of the Colossal Titan. Consume to inherit." },
	["Itemized Founding Titan"] = { Rarity = "Transcendent", Cost = 25000, Action = "EquipTitan", TitanName = "Founding Titan", Desc = "An extracted spinal fluid syringe of the Founding Titan. Consume to inherit." },

	["Itemized Founding Female Titan"] = { Rarity = "Transcendent", Cost = 50000, Action = "EquipTitan", TitanName = "Founding Female Titan", Desc = "An extracted spinal fluid syringe of the Founding Female Titan. Consume to inherit." },
	["Itemized Armored Attack Titan"] = { Rarity = "Transcendent", Cost = 50000, Action = "EquipTitan", TitanName = "Armored Attack Titan", Desc = "An extracted spinal fluid syringe of the Armored Attack Titan. Consume to inherit." },
	["Itemized War Hammer Attack Titan"] = { Rarity = "Transcendent", Cost = 50000, Action = "EquipTitan", TitanName = "War Hammer Attack Titan", Desc = "An extracted spinal fluid syringe of the War Hammer Attack Titan. Consume to inherit." },
	["Itemized Colossal Jaw Titan"] = { Rarity = "Transcendent", Cost = 50000, Action = "EquipTitan", TitanName = "Colossal Jaw Titan", Desc = "An extracted spinal fluid syringe of the Colossal Jaw Titan. Consume to inherit." },
	["Itemized Founding Attack Titan"] = { Rarity = "Transcendent", Cost = 50000, Action = "EquipTitan", TitanName = "Founding Attack Titan", Desc = "An extracted spinal fluid syringe of the Founding Attack Titan. Consume to inherit." },

	["Itemized Yeager"] = { Rarity = "Legendary", Cost = 25000, Action = "EquipClan", ClanName = "Yeager", Desc = "An extracted blood vial of the Yeager lineage. Consume to inherit." },
	["Itemized Tybur"] = { Rarity = "Legendary", Cost = 25000, Action = "EquipClan", ClanName = "Tybur", Desc = "An extracted blood vial of the Tybur lineage. Consume to inherit." },
	["Itemized Ackerman"] = { Rarity = "Mythical", Cost = 25000, Action = "EquipClan", ClanName = "Ackerman", Desc = "An extracted blood vial of the Ackerman lineage. Consume to inherit." },
	["Itemized Galliard"] = { Rarity = "Epic", Cost = 25000, Action = "EquipClan", ClanName = "Galliard", Desc = "An extracted blood vial of the Galliard lineage. Consume to inherit." },
	["Itemized Braun"] = { Rarity = "Epic", Cost = 25000, Action = "EquipClan", ClanName = "Braun", Desc = "An extracted blood vial of the Braun lineage. Consume to inherit." },
	["Itemized Arlert"] = { Rarity = "Epic", Cost = 25000, Action = "EquipClan", ClanName = "Arlert", Desc = "An extracted blood vial of the Arlert lineage. Consume to inherit." },
	["Itemized Braus"] = { Rarity = "Rare", Cost = 25000, Action = "EquipClan", ClanName = "Braus", Desc = "An extracted blood vial of the Braus lineage. Consume to inherit." },
	["Itemized Springer"] = { Rarity = "Rare", Cost = 25000, Action = "EquipClan", ClanName = "Springer", Desc = "An extracted blood vial of the Springer lineage. Consume to inherit." },
	["Itemized Reiss"] = { Rarity = "Mythical", Cost = 25000, Action = "EquipClan", ClanName = "Reiss", Desc = "An extracted blood vial of the Reiss lineage. Consume to inherit." },

	["Itemized Awakened Yeager"] = { Rarity = "Mythical", Cost = 75000, Action = "EquipClan", ClanName = "Awakened Yeager", Desc = "An extracted blood vial of the Awakened Yeager lineage." },
	["Itemized Awakened Tybur"] = { Rarity = "Mythical", Cost = 75000, Action = "EquipClan", ClanName = "Awakened Tybur", Desc = "An extracted blood vial of the Awakened Tybur lineage." },
	["Itemized Awakened Ackerman"] = { Rarity = "Transcendent", Cost = 125000, Action = "EquipClan", ClanName = "Awakened Ackerman", Desc = "An extracted blood vial of the Awakened Ackerman lineage." },
	["Itemized Awakened Galliard"] = { Rarity = "Legendary", Cost = 75000, Action = "EquipClan", ClanName = "Awakened Galliard", Desc = "An extracted blood vial of the Awakened Galliard lineage." },
	["Itemized Awakened Braun"] = { Rarity = "Legendary", Cost = 75000, Action = "EquipClan", ClanName = "Awakened Braun", Desc = "An extracted blood vial of the Awakened Braun lineage." },
	["Itemized Awakened Reiss"] = { Rarity = "Transcendent", Cost = 125000, Action = "EquipClan", ClanName = "Awakened Reiss", Desc = "An extracted blood vial of the Awakened Reiss lineage." },

	["Itemized Abyssal Yeager"] = { Rarity = "Transcendent", Cost = 300000, Action = "EquipClan", ClanName = "Abyssal Yeager", Desc = "An extracted blood vial of the Abyssal Yeager lineage." },
	["Itemized Abyssal Tybur"] = { Rarity = "Transcendent", Cost = 300000, Action = "EquipClan", ClanName = "Abyssal Tybur", Desc = "An extracted blood vial of the Abyssal Tybur lineage." },
	["Itemized Abyssal Ackerman"] = { Rarity = "Transcendent", Cost = 500000, Action = "EquipClan", ClanName = "Abyssal Ackerman", Desc = "An extracted blood vial of the Abyssal Ackerman lineage." },
	["Itemized Abyssal Galliard"] = { Rarity = "Transcendent", Cost = 300000, Action = "EquipClan", ClanName = "Abyssal Galliard", Desc = "An extracted blood vial of the Abyssal Galliard lineage." },
	["Itemized Abyssal Braun"] = { Rarity = "Transcendent", Cost = 300000, Action = "EquipClan", ClanName = "Abyssal Braun", Desc = "An extracted blood vial of the Abyssal Braun lineage." },
	["Itemized Abyssal Reiss"] = { Rarity = "Transcendent", Cost = 500000, Action = "EquipClan", ClanName = "Abyssal Reiss", Desc = "An extracted blood vial of the Abyssal Reiss lineage." },

	["Fritz Clan Serum"] = { Rarity = "Transcendent", Cost = 0, Action = "EquipClan", ClanName = "Fritz", Desc = "The absolute royal bloodline. Forged from the purest coordinate shards." },

	["Auto Train (Gift)"] = { Rarity = "Transcendent", Cost = 0, IsGift = true, Action = "Consume", Buff = "Gamepass", Unlock = "AutoTrain", Desc = "Permanently unlocks Auto Train. Cannot be sold." },
	["2x XP & Funds (Gift)"] = { Rarity = "Transcendent", Cost = 0, IsGift = true, Action = "Consume", Buff = "Gamepass", Unlock = "DoubleXP", Desc = "Permanently unlocks 2x XP & Dews. Cannot be sold." },
	["Titan Vault Expansion (Gift)"] = { Rarity = "Transcendent", Cost = 0, IsGift = true, Action = "Consume", Buff = "Gamepass", Unlock = "TitanVault", Desc = "Unlocks Titan Vault slots 4-6. Cannot be sold." },
	["Clan Vault Expansion (Gift)"] = { Rarity = "Transcendent", Cost = 0, IsGift = true, Action = "Consume", Buff = "Gamepass", Unlock = "ClanVault", Desc = "Unlocks Clan Vault slots 4-6. Cannot be sold." },
	["VIP Pass (Gift)"] = { Rarity = "Transcendent", Cost = 0, IsGift = true, Action = "Consume", Buff = "Gamepass", Unlock = "VIP", Desc = "Permanently unlocks VIP status. Cannot be sold." },
	["2x Item Drops (Gift)"] = { Rarity = "Transcendent", Cost = 0, IsGift = true, Action = "Consume", Buff = "Gamepass", Unlock = "DoubleDrops", Desc = "Permanently unlocks 2x Item Drops from combat. Cannot be sold." },
	["2x Battle Speed (Gift)"] = { Rarity = "Transcendent", Cost = 0, IsGift = true, Action = "Consume", Buff = "Gamepass", Unlock = "DoubleSpeed", Desc = "Permanently doubles the speed of combat turns. Cannot be sold." },
	["Backpack Expansion (Gift)"] = { Rarity = "Transcendent", Cost = 0, IsGift = true, Action = "Consume", Buff = "Gamepass", Unlock = "BackpackExpansion", Desc = "Permanently adds +50 slots to your Max Inventory capacity. Cannot be sold." }
}

ItemData.ForgeRecipes = {
	["Garrison Standard Blades"] = { Result = "Garrison Standard Blades", ReqItems = {["Cadet Training Blade"] = 3}, DewCost = 1500 },
	["Ultrahard Steel Blades"] = { Result = "Ultrahard Steel Blades", ReqItems = {["Garrison Standard Blades"] = 3, ["Iron Bamboo Heart"] = 1}, DewCost = 4500 },
	["Veteran Scout Blades"] = { Result = "Veteran Scout Blades", ReqItems = {["Ultrahard Steel Blades"] = 3, ["Glowing Titan Crystal"] = 1}, DewCost = 25000 },
	["Iceburst Steel Blades"] = { Result = "Iceburst Steel Blades", ReqItems = {["Veteran Scout Blades"] = 3, ["Glowing Titan Crystal"] = 5}, DewCost = 100000 },

	["Anti-Personnel Pistols"] = { Result = "Anti-Personnel Pistols", ReqItems = {["Marleyan Rifle"] = 3}, DewCost = 5000 },
	["Titan-Killer Artillery"] = { Result = "Titan-Killer Artillery", ReqItems = {["Anti-Personnel Pistols"] = 4, ["Glowing Titan Crystal"] = 2}, DewCost = 35000 },
	["Kenny's Custom Pistols"] = { Result = "Kenny's Custom Pistols", ReqItems = {["Titan-Killer Artillery"] = 2, ["Coordinate Shard"] = 1}, DewCost = 150000 },

	["Spinal Fluid Syringe"] = { Result = "Spinal Fluid Syringe", ReqItems = {["Standard Titan Serum"] = 10, ["Glowing Titan Crystal"] = 3}, DewCost = 500000 },
	["Ymir's Clay Fragment"] = { Result = "Ymir's Clay Fragment", ReqItems = {["Spinal Fluid Syringe"] = 10, ["Coordinate Shard"] = 3}, DewCost = 2500000 },
	["Ancestral Awakening Serum"] = { Result = "Ancestral Awakening Serum", ReqItems = {["Titan Hardening Extract"] = 5, ["Coordinate Shard"] = 1}, DewCost = 1000000 },

	["Scout's Clover"] = { Result = "Scout's Clover", ReqItems = {["Iron Bamboo Heart"] = 2}, DewCost = 5000 },
	["Ymir's Blessing"] = { Result = "Ymir's Blessing", ReqItems = {["Glowing Titan Crystal"] = 2, ["Standard Titan Serum"] = 1}, DewCost = 25000 },
	["Tears of the Founder"] = { Result = "Tears of the Founder", ReqItems = {["Coordinate Shard"] = 1, ["Spinal Fluid Syringe"] = 1}, DewCost = 100000 },

	["Blade of the Frenzied"] = { Result = "Blade of the Frenzied", ReqItems = {["Iceburst Steel Blades"] = 1, ["Abyssal Blood"] = 3}, DewCost = 5000000 },
	["Abyssal Thunder Spear"] = { Result = "Abyssal Thunder Spear", ReqItems = {["Thunder Spear"] = 5, ["Abyssal Blood"] = 3}, DewCost = 5000000 },
	["Shroud of the Doomed"] = { Result = "Shroud of the Doomed", ReqItems = {["Commander's Bolo Tie"] = 5, ["Abyssal Blood"] = 3}, DewCost = 5000000 },

	["Itemized Abyssal Yeager"] = { Result = "Itemized Abyssal Yeager", ReqItems = {["Itemized Awakened Yeager"] = 1, ["Abyssal Blood"] = 5, ["Coordinate Shard"] = 1}, DewCost = 5000000 },
	["Itemized Abyssal Tybur"] = { Result = "Itemized Abyssal Tybur", ReqItems = {["Itemized Awakened Tybur"] = 1, ["Abyssal Blood"] = 5, ["Coordinate Shard"] = 1}, DewCost = 5000000 },
	["Itemized Abyssal Ackerman"] = { Result = "Itemized Abyssal Ackerman", ReqItems = {["Itemized Awakened Ackerman"] = 1, ["Abyssal Blood"] = 5, ["Coordinate Shard"] = 1}, DewCost = 5000000 },
	["Itemized Abyssal Galliard"] = { Result = "Itemized Abyssal Galliard", ReqItems = {["Itemized Awakened Galliard"] = 1, ["Abyssal Blood"] = 5, ["Coordinate Shard"] = 1}, DewCost = 5000000 },
	["Itemized Abyssal Braun"] = { Result = "Itemized Abyssal Braun", ReqItems = {["Itemized Awakened Braun"] = 1, ["Abyssal Blood"] = 5, ["Coordinate Shard"] = 1}, DewCost = 5000000 },
	["Itemized Abyssal Reiss"] = { Result = "Itemized Abyssal Reiss", ReqItems = {["Itemized Awakened Reiss"] = 1, ["Abyssal Blood"] = 5, ["Coordinate Shard"] = 1}, DewCost = 5000000 },

	["Fritz Clan Serum"] = { Result = "Fritz Clan Serum", ReqItems = {["Ymir's Clay Fragment"] = 1}, SpecialType = "AbyssalClanRequirement", AbyssalClanCount = 2, DewCost = 2500000 }
}

ItemData.Sets = {
	["Scout Veteran"] = {
		Pieces = {Weapon = "Veteran Scout Blades", Accessory = "Scout Regiment Cloak"},
		Bonus = { DodgeBonus = 15, Speed = 10 },
		Desc = "Scout Veteran Set: +15% Dodge Chance, +10 Speed"
	},
	["Marleyan Warrior"] = {
		Pieces = {Weapon = "Marleyan Rifle", Accessory = "Marleyan Armband"},
		Bonus = { IgnoreArmor = 0.20, Strength = 15 },
		Desc = "Marleyan Warrior Set: 20% Armor Penetration, +15 Strength"
	},
	["Commander's Resolve"] = {
		Pieces = {Weapon = "Iceburst Steel Blades", Accessory = "Erwin's Pendant"},
		Bonus = { DmgMult = 1.25, MaxHP = 50 },
		Desc = "Commander's Resolve Set: +25% Total Damage, +50 Max HP"
	},
	["Ackerman Blood"] = {
		Pieces = {Weapon = "Kenny's Custom Pistols", Accessory = "Mikasa's Scarf"},
		Bonus = { CritBonus = 20, Speed = 30 },
		Desc = "Ackerman Set: +20% Crit Chance, +30 Speed"
	}
}

ItemData.Gamepasses = {
	{ ID = 1749846514, GiftID = 3562817556, Name = "Auto Train", Desc = "Passively generates Training XP in the background.", Key = "AutoTrain" },
	{ ID = 1748534838, GiftID = 3562817710, Name = "2x XP & Funds", Desc = "Doubles all XP and Dews gained from combat and training.", Key = "DoubleXP" },
	{ ID = 1748263337, GiftID = 3562817821, Name = "Titan Vault Expansion", Desc = "Unlocks slots 4, 5, and 6 in the Titan vault.", Key = "TitanVault" },
	{ ID = 1760797262, GiftID = 3562817914, Name = "Clan Vault Expansion", Desc = "Unlocks slots 4, 5, and 6 in the Clan vault.", Key = "ClanVault" },
	{ ID = 1747847881, GiftID = 3562817987, Name = "VIP Pass", Desc = "Exclusive Golden Chat Tag, 1 Free Shop Reroll, +25% Auto-Train Synergy!", Key = "VIP" },
	{ ID = 1772364456, GiftID = 3564165877, Name = "2x Item Drops", Desc = "Doubles the amount of items dropped from bosses and enemies.", Key = "DoubleDrops" },
	{ ID = 1772394444, GiftID = 3564165946, Name = "2x Battle Speed", Desc = "Doubles the animation speed and turn resolution in combat.", Key = "DoubleSpeed" },
	{ ID = 1772982444, GiftID = 3564166063, Name = "Backpack Expansion", Desc = "Permanently adds +50 slots to your Max Inventory capacity.", Key = "BackpackExpansion" }
}

ItemData.Products = {
	{ ID = 3557925572, Name = "Shop Reroll", Desc = "Instantly restocks the Military Supply with new items.", IsReroll = true },
	{ ID = 3557909080, Name = "5,000 Dews", Desc = "A small injection of military funds.", Reward = "Dews", Amount = 5000 },
	{ ID = 3557908989, Name = "15,000 Dews", Desc = "A healthy supply of military funds.", Reward = "Dews", Amount = 15000 },
	{ ID = 3557908863, Name = "50,000 Dews", Desc = "A massive vault of military funds.", Reward = "Dews", Amount = 50000 },
	{ ID = 3557909565, Name = "1x Titan Serum", Desc = "Grants one Standard Titan Serum.", Reward = "Item", ItemName = "Standard Titan Serum", Amount = 1 },
	{ ID = 3557909698, Name = "5x Titan Serums", Desc = "Grants five Standard Titan Serums.", Reward = "Item", ItemName = "Standard Titan Serum", Amount = 5 },
	{ ID = 3557938597, Name = "1x Clan Vial", Desc = "Grants one Clan Blood Vial.", Reward = "Item", ItemName = "Clan Blood Vial", Amount = 1 },
	{ ID = 3557938636, Name = "5x Clan Vials", Desc = "Grants five Clan Blood Vials.", Reward = "Item", ItemName = "Clan Blood Vial", Amount = 5 },

	-- [[ THE FIX: Added Legendary Clan Vial ]]
	{ ID = 3557938637, Name = "1x Leg. Clan Vial", Desc = "Grants one Legendary Clan Vial.", Reward = "Item", ItemName = "Legendary Clan Vial", Amount = 1 },

	{ ID = 3562817556, Name = "Gift: Auto Train", Desc = "Grants a tradable Auto Train pass.", Reward = "Item", ItemName = "Auto Train (Gift)", Amount = 1 },
	{ ID = 3562817710, Name = "Gift: 2x XP & Funds", Desc = "Grants a tradable 2x XP pass.", Reward = "Item", ItemName = "2x XP & Funds (Gift)", Amount = 1 },
	{ ID = 3562817821, Name = "Gift: Titan Vault", Desc = "Grants a tradable Titan Vault Expansion.", Reward = "Item", ItemName = "Titan Vault Expansion (Gift)", Amount = 1 },
	{ ID = 3562817914, Name = "Gift: Clan Vault", Desc = "Grants a tradable Clan Vault Expansion.", Reward = "Item", ItemName = "Clan Vault Expansion (Gift)", Amount = 1 },
	{ ID = 3562817987, Name = "Gift: VIP Pass", Desc = "Grants a tradable VIP Pass.", Reward = "Item", ItemName = "VIP Pass (Gift)", Amount = 1 },

	{ ID = 3564165877, Name = "Gift: 2x Item Drops", Desc = "Grants a tradable 2x Drops pass.", Reward = "Item", ItemName = "2x Item Drops (Gift)", Amount = 1 },
	{ ID = 3564165946, Name = "Gift: 2x Battle Speed", Desc = "Grants a tradable 2x Battle Speed pass.", Reward = "Item", ItemName = "2x Battle Speed (Gift)", Amount = 1 },
	{ ID = 3564166063, Name = "Gift: Backpack Expansion", Desc = "Grants a tradable Backpack Expansion pass.", Reward = "Item", ItemName = "Backpack Expansion (Gift)", Amount = 1 }
}

return ItemData