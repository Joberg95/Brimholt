extends RefCounted
## Elite caves: shared underground hunting grounds for levels 32-45. Unlike the instanced
## dungeons (game/data/dungeons.gd), everyone hunts the same cave, and its camps respawn like the
## overworld's. Each cave is painted (tools/generators/caves.gd) in a band beyond the Void Throne,
## never reachable on foot; a cave mouth (a CaveMouths marker, a hole in the ground) in its region
## leads down to the stairs up, and the stairs up lead back out beside the mouth. Caves hold elites
## (Balance "elite": more health and damage, five times the experience) and a champion in the
## deepest hall: harder than the hunts above ground, and better paid.
##
## Caves with "below" have moved (tools/generators/caves_below.gd, docs/plan/45) from the band to the
## floor below (Atlas.UNDERGROUND), their top-left corner at that cell, so their stairs up lie
## right under their mouth: the same shared cave, now under the land it belongs to.

const Dungeons = preload("res://game/data/dungeons.gd")

## First column of the cave band: past the Void Throne arena (tools/generators/void_throne.gd,
## 36 columns with a gap of four on either side).
const BAND_X: int = Dungeons.BAND_END + 44
## Rows between caves, stacked top to bottom in ORDER.
const GAP: int = 4
const ORDER: Array[String] = ["ogre_warrens", "drowned_grotto", "ember_deep", "frostvault", "rimewater_trench",
	"cyclops_hollow", "thornroot_hollows", "moonwell_deeps"]
## name, region (where the mouth opens), near (the mouth is placed as close to this as fits),
## size, levels, ambient light, hall count, and the camps: [monster, lowest level, highest level,
## monsters per camp (two: an elite takes a solo player the time of four or five normal kills, so
## a pull is at most two; a party clears them faster)], shallow to deep (deeper halls hold the
## later rows), then the champion [monster, level] alone in the deepest hall.
const CAVES: Dictionary = {
	"ogre_warrens": {"name": "Ogre Warrens", "region": "Smoulder Fells", "near": Vector2i(318, 50), "below": Vector2i(2879, 22),
		"size": Vector2i(58, 42), "min_level": 32, "max_level": 37, "ambient": Color(0.62, 0.52, 0.42), "halls": 10,
		"camps": [["ogre_brute", 32, 34, 2], ["ogre_shaman", 33, 35, 2], ["ogre_smasher", 35, 37, 2]],
		"champion": ["gorvak", 37]},
	"drowned_grotto": {"name": "Drowned Grotto", "region": "Mirewood Fen", "near": Vector2i(296, 226), "below": Vector2i(2847, 193),
		"size": Vector2i(58, 42), "min_level": 35, "max_level": 40, "ambient": Color(0.42, 0.56, 0.5), "halls": 10,
		"camps": [["bog_troll", 35, 37, 2], ["grotto_leech", 36, 38, 2], ["drowned_priest", 38, 40, 2]],
		"champion": ["drowned_abbess", 40]},
	"ember_deep": {"name": "Ember Deep", "region": "Emberwaste", "near": Vector2i(226, 262),
		"size": Vector2i(58, 42), "min_level": 38, "max_level": 43, "ambient": Color(0.66, 0.44, 0.36), "halls": 10,
		"camps": [["magma_hound", 38, 40, 2], ["cinder_brute", 40, 42, 2], ["ember_witch", 41, 43, 2]]},
	"frostvault": {"name": "Frostvault", "region": "Hollow March", "near": Vector2i(352, 112),
		"size": Vector2i(58, 42), "min_level": 41, "max_level": 45, "ambient": Color(0.5, 0.58, 0.7), "halls": 11,
		"camps": [["frost_ogre", 41, 43, 2], ["rime_stalker", 42, 44, 2], ["glacial_golem", 43, 45, 2]],
		"champion": ["hoarfrost_jarl", 45]},
	# Not an elite cave: the Rimewater Trench under the frost isles' sea ice holds normal monsters
	# in dense camps of five, a fast level-35 farm (about 270 experience a kill) with rare
	# level-35 gear among the fishfolk and crabs.
	"rimewater_trench": {"name": "Rimewater Trench", "region": "Rimewater Floes", "near": Vector2i(112, 812), "elite": false, "below": Vector2i(2665, 788),
		"size": Vector2i(58, 42), "min_level": 34, "max_level": 37, "ambient": Color(0.5, 0.64, 0.78), "halls": 11,
		"camps": [["giant_centipede", 34, 35, 5], ["brigand", 35, 36, 5], ["tide_mage", 36, 37, 5]],
		"champion": ["grimclaw", 37]},
	# Not an elite cave either: the Cyclops Hollow under the Smoulder Fells, cyclopes and their
	# smiths in dense camps for the 75-kill hunt "The Hundred-Eyed Hollow" (game/data/quests.gd).
	"cyclops_hollow": {"name": "Cyclops Hollow", "region": "Smoulder Fells", "near": Vector2i(296, 26), "elite": false,
		"size": Vector2i(58, 42), "min_level": 30, "max_level": 36, "ambient": Color(0.7, 0.58, 0.46), "halls": 11,
		"camps": [["stone_gargoyle", 30, 33, 5], ["stone_gargoyle", 33, 36, 5]]},
	# Silverwood's two great farming caves (docs/plan/40-archipelago.md): far bigger than the elite
	# caves, dense camps of normal monsters hall after hall for experience and loot. Placeholder
	# monsters of levels 45-50 until the island's own band (50-60) is added, with a boss each.
	"thornroot_hollows": {"name": "Thornroot Hollows", "region": "Silverwood", "near": Vector2i(950, 215), "elite": false, "below": Vector2i(3507, 132),
		"size": Vector2i(300, 220), "min_level": 45, "max_level": 50, "ambient": Color(0.8, 0.76, 0.68), "halls": 200,
		"camps": [["giant_bat", 45, 47, 5], ["skeleton_warrior", 46, 48, 5], ["sand_lion", 48, 50, 5]]},
	"moonwell_deeps": {"name": "Moonwell Deeps", "region": "Silverwood", "near": Vector2i(860, 95), "elite": false,
		"size": Vector2i(300, 220), "min_level": 45, "max_level": 50, "ambient": Color(0.72, 0.76, 0.84), "halls": 200,
		"camps": [["skeleton_warrior", 45, 47, 5], ["fen_dragon", 46, 48, 5], ["mire_ghost", 47, 50, 5]]},
}


## The cave's area, walls included: on the floor below for a moved cave, else in the band.
static func rect(id: String) -> Rect2i:
	if CAVES[id].has("below"):
		return Rect2i(CAVES[id]["below"], CAVES[id]["size"])
	return band_rect(id)


## Where the cave lies (or lay, before it moved below) in the band, stacked in ORDER.
static func band_rect(id: String) -> Rect2i:
	var y: int = 0
	for other: String in ORDER:
		if other == id:
			break
		y += CAVES[other]["size"].y + GAP
	return Rect2i(Vector2i(BAND_X, y), CAVES[id]["size"])


## The cave containing `cell`, or "".
static func at(cell: Vector2i) -> String:
	if cell.x < BAND_X:
		return ""
	for id: String in ORDER:
		if rect(id).has_point(cell):
			return id
	return ""


## The cave whose camps hold `monster`, or "".
static func of_monster(monster: String) -> String:
	for id: String in ORDER:
		for camp: Array in CAVES[id]["camps"]:
			if camp[0] == monster:
				return id
		if CAVES[id].has("champion") and CAVES[id]["champion"][0] == monster:
			return id
	return ""
