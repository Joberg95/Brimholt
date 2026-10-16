extends RefCounted
## Elite caves: shared underground hunting grounds for levels 32-45. Unlike the instanced
## dungeons (game/data/dungeons.gd), everyone hunts the same cave, and its camps respawn like the
## overworld's. Each cave is painted (tools/generators/caves.gd) in a band beyond the Void Throne,
## never reachable on foot; a cave mouth (a CaveMouths marker, a hole in the ground) in its region
## leads down to the stairs up, and the stairs up lead back out beside the mouth. Caves hold elites
## (Balance "elite": more health and damage, five times the experience) and a champion in the
## deepest hall: harder than the hunts above ground, and better paid.

## First column of the cave band: past the Void Throne arena (tools/generators/void_throne.gd).
const BAND_X: int = 624
## Rows between caves, stacked top to bottom in ORDER.
const GAP: int = 4
const ORDER: Array[String] = ["ogre_warrens", "drowned_grotto", "ember_deep", "frostvault", "rimewater_trench",
	"cyclops_hollow"]
## name, region (where the mouth opens), near (the mouth is placed as close to this as fits),
## size, levels, ambient light, hall count, and the camps: [monster, lowest level, highest level,
## monsters per camp (two: an elite takes a solo player the time of four or five normal kills, so
## a pull is at most two; a party clears them faster)], shallow to deep (deeper halls hold the
## later rows), then the champion [monster, level] alone in the deepest hall.
const CAVES: Dictionary = {
	"ogre_warrens": {"name": "Ogre Warrens", "region": "Smoulder Fells", "near": Vector2i(318, 50),
		"size": Vector2i(58, 42), "min_level": 32, "max_level": 37, "ambient": Color(0.62, 0.52, 0.42), "halls": 10,
		"camps": [["ogre_brute", 32, 34, 2], ["ogre_shaman", 33, 35, 2], ["ogre_smasher", 35, 37, 2]],
		"champion": ["gorvak", 37]},
	"drowned_grotto": {"name": "Drowned Grotto", "region": "Mirewood Fen", "near": Vector2i(296, 226),
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
	"rimewater_trench": {"name": "Rimewater Trench", "region": "Rimewater Floes", "near": Vector2i(112, 532), "elite": false,
		"size": Vector2i(58, 42), "min_level": 34, "max_level": 37, "ambient": Color(0.5, 0.64, 0.78), "halls": 11,
		"camps": [["trench_crab", 34, 35, 5], ["icetide_raider", 35, 36, 5], ["icetide_shaman", 36, 37, 5]],
		"champion": ["grimclaw", 37]},
	# Not an elite cave either: the Cyclops Hollow under the Smoulder Fells, cyclopes and their
	# smiths in dense camps for the 75-kill hunt "The Hundred-Eyed Hollow" (game/data/quests.gd).
	"cyclops_hollow": {"name": "Cyclops Hollow", "region": "Smoulder Fells", "near": Vector2i(296, 26), "elite": false,
		"size": Vector2i(58, 42), "min_level": 30, "max_level": 36, "ambient": Color(0.7, 0.58, 0.46), "halls": 11,
		"camps": [["cyclops", 30, 33, 5], ["cyclops_smith", 33, 36, 5]]},
}


## The cave's area, walls included.
static func rect(id: String) -> Rect2i:
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
