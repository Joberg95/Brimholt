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
		"rank": "normal", "range": 5, "step": 0.45, "gear": {"helmet": "ember_cap", "armor": "moss_coat"}},
	"stone_golem": {"name": "Stone golem", "look": "golem", "color": Color("#a29f97"), "size": 1.15,
		"rank": "normal", "range": 1, "step": 0.65},
	"cinder_wraith": {"name": "Cinder wraith", "look": "wraith", "color": Color("#d0784e"), "size": 1.0,
		"rank": "normal", "range": 4, "step": 0.4},
	"hollow_knight": {"name": "Hollow knight", "look": "humanoid", "color": Color("#3d4048"), "size": 1.05,
		"rank": "normal", "range": 1, "step": 0.45,
		"gear": {"helmet": "iron_coif", "armor": "ash_tunic", "main_hand": "flint_hatchet", "off_hand": "oak_buckler"}},
	"mire_stalker": {"name": "Mire stalker", "look": "wraith", "color": Color("#6f8f62"), "size": 1.05,
		"rank": "normal", "range": 1, "step": 0.3},
	"reedfang": {"name": "Reedfang", "look": "quadruped", "color": Color("#5d7346"), "size": 1.15,
		"rank": "normal", "range": 1, "step": 0.3},
	"bog_hulk": {"name": "Bog hulk", "look": "golem", "color": Color("#5f7d58"), "size": 1.3,
		"rank": "normal", "range": 1, "step": 0.6},
	"blackreed_warden": {"name": "Blackreed warden", "look": "humanoid", "color": Color("#2c3b33"), "size": 1.15,
		"rank": "elite", "range": 1, "step": 0.4,
		"gear": {"helmet": "iron_coif", "armor": "moss_coat", "main_hand": "flint_hatchet", "off_hand": "oak_buckler"}},
}
## Loot tables: each [item, chance] entry rolls independently when the monster dies. Gold is
## added on top by Combat (piles scale with level). Materials sell to shops (World "value");
## equipment entries are rare finds. Add new rows here; Combat validates nothing else.
const LOOT: Dictionary = {
	"field_vole": [["vole_tail", 0.5], ["glowcap", 0.08], ["copper_band", 0.01]],
	"marsh_toad": [["toad_slime", 0.45], ["glowcap", 0.1], ["river_pendant", 0.01]],
	"thornback_boar": [["boar_tusk", 0.4], ["ash_tunic", 0.02]],
	"road_bandit": [["bandit_badge", 0.35], ["iron_coif", 0.04], ["copper_blade", 0.03], ["garnet_ring", 0.01]],
	"grey_wolf": [["wolf_pelt", 0.35], ["hearth_charm", 0.01]],
	"bog_lurker": [["lurker_eye", 0.3], ["glowcap", 0.15], ["river_pendant", 0.02]],
	"outlaw_archer": [["waxed_bowstring", 0.3], ["ember_cap", 0.04], ["moss_coat", 0.03]],
	"stone_golem": [["golem_core", 0.25], ["oak_buckler", 0.03]],
	"cinder_wraith": [["wraith_ash", 0.3], ["hearth_charm", 0.02]],
	"hollow_knight": [["hollow_sigil", 0.25], ["iron_coif", 0.04], ["flint_hatchet", 0.03], ["oak_buckler", 0.03]],
	"mire_stalker": [["stalker_fang", 0.25], ["garnet_ring", 0.02]],
	"reedfang": [["reedfang_scale", 0.25], ["copper_band", 0.02]],
	"bog_hulk": [["bog_heart", 0.2], ["ash_tunic", 0.03], ["river_pendant", 0.02]],
	"blackreed_warden": [["warden_crest", 0.5], ["flint_hatchet", 0.08], ["garnet_ring", 0.06], ["hearth_charm", 0.05]],
}
## Monsters notice players within this many tiles and never chase beyond LEASH from home.
const AGGRO_RANGE: int = 6
const LEASH: int = 12
const RESPAWN_SECONDS: float = 45.0
