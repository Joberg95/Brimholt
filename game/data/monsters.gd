extends RefCounted
## Original monster catalog. Health, damage, and experience come from game/data/balance.gd using
## the level on each map spawn marker and the monster's rank. "look" picks the sprite: a
## tinted creature sheet (quadruped, blob, golem, wraith) or a humanoid wearing "gear".

const MONSTERS: Dictionary = {
	"field_vole": {"name": "Field vole", "look": "quadruped", "color": Color("#a08566"), "size": 0.6,
		"rank": "normal", "range": 1, "step": 0.6},
	"marsh_toad": {"name": "Marsh toad", "look": "blob", "color": Color("#7d9a52"), "size": 0.7,
		"rank": "normal", "range": 1, "step": 0.7},
	"thornback_boar": {"name": "Thornback boar", "look": "quadruped", "color": Color("#8a6248"), "size": 0.95,
		"rank": "normal", "range": 1, "step": 0.45},
	"road_bandit": {"name": "Road bandit", "look": "humanoid", "color": Color("#5d5348"), "size": 1.0,
		"rank": "normal", "range": 1, "step": 0.4, "gear": {"helmet": "iron_coif", "main_hand": "copper_blade"}},
	"grey_wolf": {"name": "Grey wolf", "look": "quadruped", "color": Color("#9aa0a6"), "size": 1.0,
		"rank": "normal", "range": 1, "step": 0.35},
	"bog_lurker": {"name": "Bog lurker", "look": "blob", "color": Color("#5c7d6a"), "size": 1.05,
		"rank": "normal", "range": 3, "step": 0.6},
	"outlaw_archer": {"name": "Outlaw archer", "look": "humanoid", "color": Color("#4f5a3a"), "size": 1.0,
		"rank": "normal", "range": 5, "step": 0.45, "gear": {"helmet": "ember_cap", "armor": "moss_coat", "main_hand": "yew_hunting_bow"}},
	"stone_golem": {"name": "Stone golem", "look": "golem", "color": Color("#a29f97"), "size": 1.15,
		"rank": "normal", "range": 1, "step": 0.65},
	"cinder_wraith": {"name": "Cinder wraith", "look": "wraith", "color": Color("#d0784e"), "size": 1.0,
		"rank": "normal", "range": 4, "step": 0.4},
	"hollow_knight": {"name": "Hollow knight", "look": "humanoid", "color": Color("#3d4048"), "size": 1.05,
		"rank": "normal", "range": 1, "step": 0.45,
		"gear": {"helmet": "steel_kettle_hat", "armor": "steel_hauberk", "main_hand": "steel_longsword", "off_hand": "steel_kite_shield"}},
	"mire_stalker": {"name": "Mire stalker", "look": "wraith", "color": Color("#6f8f62"), "size": 1.05,
		"rank": "normal", "range": 1, "step": 0.3},
	"reedfang": {"name": "Reedfang", "look": "quadruped", "color": Color("#5d7346"), "size": 1.15,
		"rank": "normal", "range": 1, "step": 0.3},
	"bog_hulk": {"name": "Bog hulk", "look": "golem", "color": Color("#5f7d58"), "size": 1.3,
		"rank": "normal", "range": 1, "step": 0.6},
	"blackreed_warden": {"name": "Blackreed warden", "look": "humanoid", "color": Color("#2c3b33"), "size": 1.15,
		"rank": "elite", "range": 1, "step": 0.4,
		"gear": {"helmet": "duskiron_visor", "armor": "duskiron_plate", "cape": "dusk_cape", "main_hand": "duskiron_cleaver",
			"off_hand": "duskiron_bulwark"}},
	# Final bosses: level 50 "boss" rank (Balance: a ten-player raid), slow respawn. Each kill
	# gives every participant a trophy, traded at the Relic keeper for one of the boss's four
	# glowing "relics". Raid mechanics (enrage, raid-wide damage, tank swaps) come later.
	# The Hollow Reach (level 45-50 PvP, south-east): blight creatures guarding the Sanctum.
	"void_wraith": {"name": "Void wraith", "look": "wraith", "color": Color("#7a4aaa"), "size": 1.1,
		"rank": "normal", "range": 4, "step": 0.4, "glow": Color("#9a5aff")},
	"obsidian_golem": {"name": "Obsidian golem", "look": "golem", "color": Color("#3a3050"), "size": 1.3,
		"rank": "elite", "range": 1, "step": 0.65},
	"vaelith": {"relics": ["voidrend", "eclipse_bow", "starless_wand", "nightbloom_rod", "sovereign_mantle"],
		"name": "Vaelith, Sovereign of the Hollow", "look": "humanoid", "color": Color("#2a1e3a"), "size": 2.0,
		"rank": "boss", "range": 1, "step": 0.45, "respawn": 3600.0,
		"gear": {"helmet": "duskiron_visor", "armor": "duskiron_plate", "cape": "sovereign_mantle", "main_hand": "voidrend"}},
	"morvain": {"relics": ["abyssal_greathelm", "abyssal_plate", "tidebreaker", "abyssal_ward"], "name": "Morvain the Drowned", "look": "humanoid", "color": Color("#2f5a5a"), "size": 1.6,
		"rank": "boss", "range": 1, "step": 0.45, "respawn": 1800.0,
		"gear": {"helmet": "abyssal_greathelm", "armor": "abyssal_plate", "main_hand": "tidebreaker", "off_hand": "abyssal_ward"}},
	"kharzul": {"relics": ["cinderheart_bow", "cinderheart_wand", "molten_heart", "cinderheart_charm"], "name": "Kharzul the Cinder Colossus", "look": "golem", "color": Color("#6a3a2a"), "size": 2.0,
		"rank": "boss", "range": 1, "step": 0.7, "respawn": 1800.0, "glow": Color("#ff8a3a")},
	"sylvaine": {"relics": ["bloomheart_rod", "verdant_codex", "hollowbloom_cape", "bloomsoul_ring"], "name": "Sylvaine the Hollow Bloom", "look": "wraith", "color": Color("#7a5aa8"), "size": 1.8,
		"rank": "boss", "range": 4, "step": 0.5, "respawn": 1800.0, "glow": Color("#c890ff")},
}
## Loot tables: each [item, chance] entry rolls independently when the monster dies. Gold piles
## and tiered equipment (Combat.GEAR_DROP_CHANCE, from the monster's level tier) are added on
## top by Combat. Materials sell to shops (World "value"). Add new rows here.
const LOOT: Dictionary = {
	"field_vole": [["vole_tail", 0.5], ["glowcap", 0.08]],
	"marsh_toad": [["toad_slime", 0.45], ["glowcap", 0.1]],
	"thornback_boar": [["boar_tusk", 0.4]],
	"road_bandit": [["bandit_badge", 0.35]],
	"grey_wolf": [["wolf_pelt", 0.35]],
	"bog_lurker": [["lurker_eye", 0.3], ["glowcap", 0.15]],
	"outlaw_archer": [["waxed_bowstring", 0.3]],
	"stone_golem": [["golem_core", 0.25]],
	"cinder_wraith": [["wraith_ash", 0.3]],
	"hollow_knight": [["hollow_sigil", 0.25]],
	"mire_stalker": [["stalker_fang", 0.25]],
	"reedfang": [["reedfang_scale", 0.25]],
	"bog_hulk": [["bog_heart", 0.2]],
	"blackreed_warden": [["warden_crest", 0.5]],
	# Bosses drop gold; their relics are quest rewards (Combat.claim_relic, the Relic keeper).
	"morvain": [],
	"kharzul": [],
	"sylvaine": [],
	"void_wraith": [["void_shard", 0.3]],
	"obsidian_golem": [["obsidian_chunk", 0.4]],
	"vaelith": [],
}
## Monsters notice players within this many tiles and never chase beyond LEASH from home.
const AGGRO_RANGE: int = 6
const LEASH: int = 12
const RESPAWN_SECONDS: float = 45.0
