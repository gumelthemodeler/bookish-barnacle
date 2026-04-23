-- @ScriptType: ModuleScript
-- Name: SkillData
-- @ScriptType: ModuleScript
local SkillData = {}

SkillData.Skills = {
	-- [[ BASIC & UNIVERSAL MOVES ]]
	["Basic Slash"] = { Requirement = "None", Range = "Close", Type = "Basic", Mult = 1.0, EnergyCost = 0, GasCost = 0, Order = 1, SFX = "LightSlash", VFX = "SlashMark", Description = "A standard strike to the target." },

	["Maneuver"] = { Requirement = "None", Range = "Any", Type = "Basic", Mult = 0, EnergyCost = 0, GasCost = 15, Effect = "Dodge", Cooldown = 2, Order = 2, SFX = "Dash", VFX = "BlockMark", Description = "Burn gas to evade. Grants a 100% chance to evade the next attack." },
	["Fall Back"] = { Requirement = "None", Range = "Close", Type = "Basic", Mult = 0, EnergyCost = 0, GasCost = 15, Effect = "FallBack", Cooldown = 0, Order = 3, SFX = "Dash", VFX = "BlockMark", Description = "Burn gas to retreat to Long Range, evading all close-range melee attacks." },
	["Close In"] = { Requirement = "None", Range = "Long", Type = "Basic", Mult = 0, EnergyCost = 0, GasCost = 15, Effect = "CloseGap", Cooldown = 0, Order = 3, SFX = "Dash", VFX = "BlockMark", Description = "Burn gas to fire your ODM gear and rush into Melee Range." },
	["Recover"] = { Requirement = "None", Range = "Any", Type = "Basic", Mult = 0, EnergyCost = 0, GasCost = 0, Effect = "Rest", Cooldown = 3, Order = 4, SFX = "Heal", VFX = "HealMark", Description = "Skip your turn to recover HP and replenish Gas." },
	["Retreat"] = { Requirement = "None", Range = "Any", Type = "Basic", Mult = 0, EnergyCost = 0, GasCost = 50, Effect = "Flee", Order = 5, SFX = "Flee", VFX = "BlockMark", Description = "Fire a smoke signal and escape the battle completely." },

	-- [[ GUN & SUPPORT SKILLS ]]
	["Flare Gun"] = { Requirement = "None", Range = "Any", Type = "Basic", Mult = 0.5, Effect = "Blinded", Duration = 1, EnergyCost = 0, GasCost = 0, Cooldown = 3, Order = 2, SFX = "Gun", VFX = "ExplosionMark", Description = "Fire a flare to temporarily blind the enemy from afar." },
	["Anti-Titan Rifle"] = { Requirement = "None", Range = "Any", Type = "Basic", Mult = 1.5, Effect = "Bleed", Duration = 2, EnergyCost = 0, GasCost = 0, Cooldown = 2, Order = 3, SFX = "Sniper", VFX = "ExplosionMark", Description = "Take a steady shot with an anti-titan rifle." },

	-- [[ TITAN SHIFTER UNIVERSAL MOVES ]]
	["Transform"] = { Requirement = "AnyTitan", Range = "Any", Type = "Transform", Mult = 0, EnergyCost = 0, GasCost = 0, Effect = "Transform", Cooldown = 10, Order = 6, SFX = "Transform", VFX = "ExplosionMark", Description = "Bite your hand and trigger a Titan transformation." },
	["Eject"] = { Requirement = "Transformed", Range = "Any", Type = "Transform", Mult = 0, EnergyCost = 0, GasCost = 0, Effect = "Eject", Cooldown = 0, Order = 1, SFX = "Dash", VFX = "SlashMark", Description = "Cut yourself out of the nape, returning to human form." },
	["Titan Recover"] = { Requirement = "Transformed", Range = "Any", Type = "Basic", Mult = 0, EnergyCost = 0, GasCost = 0, Effect = "TitanRest", Cooldown = 3, Order = 2, SFX = "Steam", VFX = "HealMark", Description = "Channel your Titan regeneration to massively recover HP." },
	["Titan Punch"] = { Requirement = "Transformed", Range = "Close", Type = "Basic", Mult = 2.0, EnergyCost = 0, GasCost = 0, Cooldown = 0, Order = 3, SFX = "Punch", VFX = "ExplosionMark", Description = "A heavy punch that consumes no steam." },
	["Titan Kick"] = { Requirement = "Transformed", Range = "Close", Type = "Basic", Mult = 2.5, EnergyCost = 0, GasCost = 0, Cooldown = 2, Order = 4, SFX = "Kick", VFX = "ExplosionMark", Description = "A sweeping kick that knocks the enemy back." },
	["Cannibalize"] = { Requirement = "Transformed", Range = "Close", Type = "Titan", Mult = 1.5, EnergyCost = 0, Cooldown = 4, Order = 5, Effect = "RestoreHeat", SFX = "Bite", VFX = "ClawMark", Description = "Viciously bite the enemy, restoring 40 Heat and 15% HP." },

	-- [[ BASE ODM SYNERGY CHAIN ]]
	["Spinning Slash"] = { Requirement = "ODM", Range = "Close", Type = "Style", Mult = 0.45, Hits = 3, GasCost = 20, Order = 7, ComboReq = "Basic Slash", ComboMult = 1.3, SFX = "SpinSlash", VFX = "SlashMark", Description = "Burn gas to rapidly spin and slash the target 3 times." },
	["Nape Strike"] = { Requirement = "ODM", Range = "Close", Type = "Style", Mult = 2.5, Effect = "Bleed", Duration = 3, GasCost = 25, Cooldown = 4, Order = 8, ComboReq = "Spinning Slash", ComboMult = 1.5, SFX = "HeavySlash", VFX = "SlashMark", Description = "A precise, lethal strike to the vital point. Causes Bleed." },

	-- [[ ULTRAHARD STEEL BLADES CHAIN ]]
	["Dual Slash"] = { Requirement = "Ultrahard Steel Blades", Range = "Close", Type = "Style", Mult = 0.8, Hits = 2, GasCost = 10, Cooldown = 0, Order = 9, SFX = "DualSlash", VFX = "SlashMark", Description = "A rapid double strike using both blades." },
	["Momentum Strike"] = { Requirement = "Ultrahard Steel Blades", Range = "Close", Type = "Style", Mult = 1.8, GasCost = 15, Cooldown = 2, Order = 10, ComboReq = "Dual Slash", ComboMult = 1.4, SFX = "HeavySlash", VFX = "SlashMark", Description = "Use the momentum of your previous slash for a heavy blow." },
	["Vortex Slash"] = { Requirement = "Ultrahard Steel Blades", Range = "Close", Type = "Style", Mult = 0.7, Hits = 5, Effect = "Bleed", Duration = 2, GasCost = 35, Cooldown = 5, Order = 11, ComboReq = "Momentum Strike", ComboMult = 1.6, SFX = "SpinSlash", VFX = "ExplosionMark", Description = "A devastating whirlwind of blades that shreds the target." },
	["Blade Toss"] = { Requirement = "Ultrahard Steel Blades", Range = "Any", Type = "Style", Mult = 1.8, Effect = "Bleed", Duration = 2, GasCost = 15, Cooldown = 3, Order = 12, SFX = "Dash", VFX = "SlashMark", Description = "Throw your blades like projectiles into the target's eyes." },

	-- [[ THUNDER SPEARS CHAIN ]]
	["Armor Piercer"] = { Requirement = "Thunder Spears", Range = "Any", Type = "Style", Mult = 1.8, Effect = "Debuff_Defense", Duration = 4, GasCost = 10, Cooldown = 5, Order = 9, SFX = "Gun", VFX = "ExplosionMark", Description = "A shaped charge that shreds the enemy's Defense for 4 turns." },
	["Spear Volley"] = { Requirement = "Thunder Spears", Range = "Any", Type = "Style", Mult = 2.5, Effect = "Burn", Duration = 2, GasCost = 20, Cooldown = 4, Order = 10, ComboReq = "Armor Piercer", ComboMult = 1.5, SFX = "Explosion", VFX = "ExplosionMark", Description = "Fire a highly explosive payload that burns the enemy." },
	["Reckless Barrage"] = { Requirement = "Thunder Spears", Range = "Any", Type = "Style", Mult = 0.6, Hits = 4, GasCost = 30, Cooldown = 6, Order = 11, ComboReq = "Spear Volley", ComboMult = 1.4, SFX = "BigExplosion", VFX = "ExplosionMark", Description = "Unleash a barrage of spears at once." },
	["Detonator Dive"] = { Requirement = "Thunder Spears", Range = "Close", Type = "Style", Mult = 4.5, Effect = "Stun", Duration = 1, GasCost = 45, Cooldown = 8, Order = 12, ComboReq = "Reckless Barrage", ComboMult = 1.8, Unavoidable = true, SFX = "BigExplosion", VFX = "ExplosionMark", Description = "A suicidal dive-bomb explosion. Unavoidable." },

	-- [[ ANTI-PERSONNEL ODM CHAIN ]]
	["Buckshot Spread"] = { Requirement = "Anti-Personnel", Range = "Any", Type = "Style", Mult = 0.4, Hits = 3, GasCost = 10, Cooldown = 0, Order = 9, SFX = "Gun", VFX = "ExplosionMark", Description = "Fires a wide spread of buckshot from your ODM guns." },
	["Grapple Shot"] = { Requirement = "Anti-Personnel", Range = "Any", Type = "Style", Mult = 1.4, Effect = "Stun", Duration = 1, GasCost = 15, Cooldown = 3, Order = 10, ComboReq = "Buckshot Spread", ComboMult = 1.4, SFX = "Grapple", VFX = "SlashMark", Description = "Fires a grappling hook into the target, staggering them." },
	["Executioner's Shot"] = { Requirement = "Anti-Personnel", Range = "Close", Type = "Style", Mult = 3.5, Effect = "Bleed", Duration = 2, GasCost = 30, Cooldown = 5, Order = 11, ComboReq = "Grapple Shot", ComboMult = 1.6, SFX = "Sniper", VFX = "ExplosionMark", Description = "A point-blank, lethal shot to a grappled target." },
	["Knee Capper"] = { Requirement = "Anti-Personnel", Range = "Any", Type = "Style", Mult = 1.5, Effect = "Crippled", Duration = 3, GasCost = 10, Cooldown = 4, Order = 12, SFX = "Gun", VFX = "SlashMark", Description = "Shoots the target's leg to cripple their speed." },

	-- [[ ACKERMAN CHAIN ]]
	["Ackerman Flurry"] = { Requirement = "Ackerman", Range = "Close", Type = "Style", Mult = 0.4, Hits = 5, GasCost = 35, Cooldown = 4, Order = 15, SFX = "DualSlash", VFX = "SlashMark", Description = "A blindingly fast sequence of lethal strikes." },
	["Swift Execution"] = { Requirement = "Ackerman", Range = "Close", Type = "Style", Mult = 3.0, Effect = "Bleed", Duration = 3, GasCost = 45, Cooldown = 5, Order = 16, ComboReq = "Ackerman Flurry", ComboMult = 1.5, SFX = "HeavySlash", VFX = "SlashMark", Description = "A hyper-lethal strike to the nape." },
	["God Speed"] = { Requirement = "Awakened Ackerman", Range = "Close", Type = "Style", Mult = 0.5, Hits = 8, GasCost = 60, Effect = "Stun", Duration = 2, Cooldown = 6, Order = 17, ComboReq = "Swift Execution", ComboMult = 1.8, SFX = "SpinSlash", VFX = "ClawMark", Description = "Move faster than the eye can see, shredding the target completely." },

	-- [[ SHIFTER SPECIFIC MOVES ]]
	["Titan Roar"] = { Requirement = "AnyTitan", Range = "Any", Type = "Titan", Mult = 0, Effect = "Confusion", Duration = 2, EnergyCost = 20, Cooldown = 6, Order = 10, Telegraphed = true, Unavoidable = true, SFX = "Roar", VFX = "BlockMark", Description = "A terrifying roar that confuses and disorients the enemy. Cannot be dodged." },
	["Hardened Punch"] = { Requirement = "AnyTitan", Range = "Close", Type = "Titan", Mult = 3.5, Effect = "Debuff_Defense", Duration = 2, EnergyCost = 30, Cooldown = 6, Order = 11, Telegraphed = true, SFX = "HeavyPunch", VFX = "ExplosionMark", Description = "Focus crystal hardening into your knuckles to shatter enemy armor." },
	["Nape Guard"] = { Requirement = "AnyTitan", Range = "Any", Type = "Titan", Mult = 0, Effect = "NapeGuard", Duration = 2, EnergyCost = 40, Cooldown = 6, Order = 12, SFX = "Block", VFX = "BlockMark", Description = "Harden the nape of your neck, reducing incoming Nape damage to 1." },

	-- Attack Titan
	["Berserk Rush"] = { Requirement = "Attack Titan", Range = "Close", Type = "Titan", Mult = 0.8, Hits = 4, Effect = "Bleed", Duration = 2, EnergyCost = 25, Cooldown = 6, Order = 13, Telegraphed = true, SFX = "Punch", VFX = "SlashMark", Description = "A flurry of enraged attacks." },
	["Future Memories"] = { Requirement = "Attack Titan", Range = "Any", Type = "Titan", Mult = 0, Effect = "Dodge", EnergyCost = 15, Cooldown = 4, Order = 14, SFX = "Heal", VFX = "BlockMark", Description = "See the future, granting 100% evasion for the next attack." },

	-- Jaw Titan
	["Crushing Bite"] = { Requirement = "Jaw Titan", Range = "Close", Type = "Titan", Mult = 3.5, Effect = "Debuff_Defense", Duration = 3, EnergyCost = 30, Cooldown = 6, Order = 13, Telegraphed = true, SFX = "Bite", VFX = "ClawMark", Description = "A devastating bite that easily shatters hardening and armor." },
	["Agile Leap"] = { Requirement = "Jaw Titan", Range = "Any", Type = "Titan", Mult = 2.0, Effect = "CloseGap", EnergyCost = 20, Cooldown = 4, Order = 14, Telegraphed = true, SFX = "Dash", VFX = "SlashMark", Description = "Leap incredible distances to close the gap instantly and strike." },

	-- Cart Titan
	["Panzer Artillery"] = { Requirement = "Cart Titan", Range = "Long", Type = "Titan", Mult = 1.2, Hits = 3, Effect = "Burn", Duration = 2, EnergyCost = 35, Cooldown = 6, Order = 13, Telegraphed = true, SFX = "Explosion", VFX = "ExplosionMark", Description = "Fire the Panzer Unit cannons strapped to your back." },
	["Endurance Run"] = { Requirement = "Cart Titan", Range = "Any", Type = "Titan", Mult = 0, Effect = "RestoreHeat", EnergyCost = 0, Cooldown = 5, Order = 14, SFX = "Dash", VFX = "HealMark", Description = "Run laps to rapidly regenerate 40 Heat and 15% HP." },

	-- Female Titan
	["Crystal Kick"] = { Requirement = "Female Titan", Range = "Close", Type = "Titan", Mult = 4.0, Effect = "Stun", Duration = 1, EnergyCost = 30, Cooldown = 7, Order = 13, Telegraphed = true, SFX = "Kick", VFX = "ExplosionMark", Description = "Harden your shin and deliver a devastating roundhouse." },
	["Attraction Scream"] = { Requirement = "Female Titan", Range = "Any", Type = "Titan", Mult = 2.0, Effect = "Confusion", Duration = 3, EnergyCost = 40, Cooldown = 8, Order = 14, Telegraphed = true, Unavoidable = true, SFX = "Roar", VFX = "BlockMark", Description = "Scream to summon pure titans that swarm the target. Cannot be dodged." },

	-- Armored Titan
	["Armored Tackle"] = { Requirement = "Armored Titan", Range = "Any", Effect = "CloseGap", Type = "Titan", Mult = 4.0, Duration = 1, EnergyCost = 40, Cooldown = 8, Order = 13, Telegraphed = true, SFX = "HeavyPunch", VFX = "ExplosionMark", Description = "A devastating, unstoppable charge that closes the gap and stuns." },
	["Shattering Charge"] = { Requirement = "Armored Titan", Range = "Close", Type = "Titan", Mult = 5.0, Effect = "Debuff_Defense", Duration = 3, EnergyCost = 50, Cooldown = 9, Order = 14, ComboReq = "Armored Tackle", ComboMult = 1.5, Telegraphed = true, SFX = "HeavyPunch", VFX = "ExplosionMark", Description = "Follow up a tackle with a massive armor-breaking blow." },

	-- War Hammer Titan
	["War Hammer Spike"] = { Requirement = "War Hammer Titan", Range = "Any", Type = "Titan", Mult = 4.5, Effect = "Bleed", Duration = 4, EnergyCost = 45, Cooldown = 8, Order = 13, ComboReq = "Hardened Punch", ComboMult = 1.4, Telegraphed = true, Unavoidable = true, SFX = "Spike", VFX = "SlashMark", Description = "Manifest a massive crystal spike to impale the enemy. Cannot be dodged." },
	["Crossbow Construct"] = { Requirement = "War Hammer Titan", Range = "Long", Type = "Titan", Mult = 3.5, Effect = "Crippled", Duration = 2, EnergyCost = 30, Cooldown = 7, Order = 14, Telegraphed = true, SFX = "Sniper", VFX = "SlashMark", Description = "Construct a crystal crossbow and pin the target from afar." },

	-- Beast Titan
	["Pitching Ace"] = { Requirement = "Beast Titan", Range = "Long", Type = "Titan", Mult = 5.0, Effect = "Crippled", Duration = 3, EnergyCost = 50, Cooldown = 9, Order = 14, ComboReq = "Crushed Boulders", ComboMult = 1.5, Telegraphed = true, SFX = "Explosion", VFX = "ExplosionMark", Description = "A perfectly aimed, hyper-lethal fastball." },

	-- Colossal Titan
	["Colossal Steam"] = { Requirement = "Colossal Titan", Range = "Close", Type = "Titan", Mult = 1.5, Hits = 2, Effect = "Burn", Duration = 3, EnergyCost = 50, Cooldown = 9, Order = 13, Telegraphed = true, Unavoidable = true, SFX = "Steam", VFX = "ExplosionMark", Description = "Emit waves of scorching steam. Cannot be dodged, must Fall Back." },
	["Devastating Kick"] = { Requirement = "Colossal Titan", Range = "Close", Type = "Titan", Mult = 6.0, Effect = "Stun", Duration = 1, EnergyCost = 60, Cooldown = 10, Order = 14, Telegraphed = true, Unavoidable = true, SFX = "Stomp", VFX = "ExplosionMark", Description = "A slow, earth-shattering kick that obliterates defenses. Cannot be dodged." },

	-- Founding Titan
	["Coordinate Command"] = { Requirement = "Founding Titan", Range = "Any", Type = "Titan", Mult = 6.0, Effect = "Stun", Duration = 1, EnergyCost = 80, Cooldown = 12, Order = 13, Telegraphed = true, Unavoidable = true, SFX = "Roar", VFX = "ClawMark", Description = "Command pure titans to swarm and crush the enemy. Cannot be dodged." },

	-- [[ ENEMY EXCLUSIVE MOVES ]]
	["Titan Grab"] = { Requirement = "Enemy", Range = "Close", Type = "Titan", Mult = 1.2, Effect = "Stun", Duration = 1, Cooldown = 3, SFX = "Dash", VFX = "ClawMark", Description = "The Titan attempts to grab the target." },
	["Titan Bite"] = { Requirement = "Enemy", Range = "Close", Type = "Titan", Mult = 1.6, Effect = "Bleed", Duration = 2, Cooldown = 2, ComboReq = "Titan Grab", ComboMult = 1.5, SFX = "Bite", VFX = "ClawMark", Description = "A lethal bite targeting the head or torso." },
	["Brutal Swipe"] = { Requirement = "Enemy", Range = "Close", Type = "Titan", Mult = 1.0, SFX = "HeavyPunch", VFX = "SlashMark", Description = "A heavy, sweeping arm strike." },
	["Frenzied Thrash"] = { Requirement = "Enemy", Range = "Close", Type = "Titan", Mult = 0.5, Hits = 3, Cooldown = 3, SFX = "Punch", VFX = "ExplosionMark", Description = "An unpredictable, flailing attack." },

	["Stomp"] = { Requirement = "Enemy", Range = "Close", Type = "Titan", Mult = 2.0, Effect = "Stun", Duration = 1, Cooldown = 6, Telegraphed = true, SFX = "Stomp", VFX = "ExplosionMark", Description = "A devastating stomp that crushes the target." },
	["Crushed Boulders"] = { Requirement = "Enemy", Range = "Any", Type = "Titan", Mult = 1.8, Effect = "GasDrain", Duration = 0, Cooldown = 5, Telegraphed = true, Unavoidable = true, SFX = "Explosion", VFX = "ExplosionMark", Description = "Throws a massive spread of crushed rocks. Cannot be dodged." },
	["Anti-Titan Round"] = { Requirement = "Enemy", Range = "Any", Type = "Basic", Mult = 2.5, Effect = "Bleed", Duration = 3, Cooldown = 6, Telegraphed = true, SFX = "Sniper", VFX = "ExplosionMark", Description = "Fires a massive armor-piercing shell." },

	["Heavy Slash"] = { Requirement = "Enemy", Range = "Close", Type = "Basic", Mult = 1.3, Cooldown = 2, SFX = "HeavySlash", VFX = "SlashMark", Description = "A powerful, slow swing." },

	["Block"] = { Requirement = "None", Range = "Any", Type = "Basic", Mult = 0, Effect = "Block", Cooldown = 2, SFX = "Block", VFX = "BlockMark", Description = "Defends against incoming damage." },
	["Evasive Maneuver"] = { Requirement = "Enemy", Range = "Any", Type = "Basic", Mult = 0, Effect = "Dodge", Cooldown = 5, SFX = "Dash", VFX = "BlockMark", Description = "Dodges incoming attacks." },
	["Smoke Screen"] = { Requirement = "Enemy", Range = "Any", Type = "Basic", Mult = 0, Effect = "Dodge", Cooldown = 5, SFX = "Steam", VFX = "BlockMark", Description = "Creates a smoke screen to evade attacks." },
	["Regroup"] = { Requirement = "Enemy", Range = "Any", Type = "Basic", Mult = 0, Effect = "Rest", Cooldown = 4, SFX = "Heal", VFX = "HealMark", Description = "Steps back to heal." },
	["Idle"] = { Requirement = "Enemy", Range = "Any", Type = "Basic", Mult = 0, Effect = "None", Cooldown = 0, SFX = "None", VFX = "None", Description = "Stands perfectly still." }
}

return SkillData