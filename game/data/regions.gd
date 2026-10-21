extends RefCounted
## Named overworld regions. Each tile belongs to the region whose anchor is nearest (the Dunmere
## desert, game/data/biomes.gd, is always the Sunscar Dunes, and the frost isles only ever take
## the isles' regions, the mainland only the mainland's); towns, Blackreed Isle, and the
## Hollow Reach keep their own zones on top. A region's level range is not set here: World
## derives it from the monster spawns inside it, so moving spawns in the editor updates it.

const Biomes = preload("res://game/data/biomes.gd")

## [name, anchor tile, one-line flavour shown on the world map's hover and the region banner].
const REGIONS: Array = [
	["Cinder Meadows", Vector2i(28, 28), "Toad ponds and vole burrows outside Cinder Crossing"],
	["Westwind Coast", Vector2i(18, 112), "Bandit camps along the western cliffs"],
	["Greywood", Vector2i(104, 64), "Old forest where wolves and highwaymen hunt"],
	["Lurkmoor", Vector2i(166, 74), "Sunken bog pools north of the lake"],
	["Outlaw Ridge", Vector2i(214, 30), "Archers watch the Ashford road from the ridge"],
	["Golemback Hills", Vector2i(262, 84), "Stone hills that sometimes stand up"],
	["Smoulder Fells", Vector2i(310, 34), "Ash-grey fells haunted by cinder wraiths"],
	["Hollow March", Vector2i(356, 116), "The hollow legion's eastern marches"],
	["Thornfield Wilds", Vector2i(64, 182), "Brambled hunting grounds west of the lake"],
	["Stillwater Shore", Vector2i(222, 150), "Reed beds and mire along the great lake"],
	["Stonevale", Vector2i(156, 242), "A broken valley of quarries and golems"],
	["Emberwaste", Vector2i(236, 262), "Scorched heath where the dead still march"],
	["Mirewood Fen", Vector2i(304, 232), "Drowned forest of stalkers and reedfangs"],
	["Gloamwood", Vector2i(196, 344), "A dusk-dark wood on the southern edge"],
	["Lastlight Downs", Vector2i(42, 346), "Windswept downs above the southern port"],
	# The new land east and south of the heartland, levels 1-30 (tools/generators/mainland.gd).
	["Bracken Leas", Vector2i(560, 560), "Open leas and vole burrows round Brackenford"],
	["Hazel Downs", Vector2i(560, 420), "Rolling downs where boars root and bandits lie in wait"],
	["Wolfholt", Vector2i(530, 300), "A deep holt where the grey wolves den"],
	["Grimtusk Hold", Vector2i(552, 247), "Orc country round the warlord's stone hold"],
	["Kestrel Heights", Vector2i(520, 180), "Windy heights of outlaws, bears, and harpies"],
	["Greycrag Peaks", Vector2i(520, 60), "Bare peaks where the stone itself walks"],
	["Fernmere", Vector2i(330, 560), "A country of reedy meres and bog lurkers"],
	["Barrowmoor", Vector2i(200, 540), "Old barrows on the heath, watched by archers"],
	["Saltreed Marsh", Vector2i(90, 470), "Salt marsh on the bay where lizardfolk hunt"],
	# The frost isles (Biomes.ISLES): their tiles only ever belong to these.
	["Hrimfold Tundra", Vector2i(52, 756), "Snowfields and fir woods round the port of Hrimvik"],
	["Wolfskerry", Vector2i(128, 732), "A wind-scoured skerry where wolves and walruses hunt"],
	["Rimewater Floes", Vector2i(104, 808), "Broken sea ice over the Rimewater Trench"],
	# The archipelago (docs/plan/40-archipelago.md, tools/generators/islands.gd).
	["Silverwood", Vector2i(900, 170), "Old elven woods and still lakes round the castle of Aldmoor"],
	["Sunreach", Vector2i(520, 860), "Dunes, mesas, and palm oases round the sandstone castle of Qasrun"],
]
## Shown for desert tiles, whatever the nearest anchor.
const DESERT: String = "Sunscar Dunes"
const DESERT_TEXT: String = "Sand, cactus, and the glare of the south-western desert"


## The region name at a tile of the overworld.
static func name_at(cell: Vector2i) -> String:
	if Biomes.in_desert(cell):
		return DESERT
	var best: String = ""
	var nearest: int = 1 << 30
	var isles: bool = Biomes.in_isles(cell)
	for region: Array in REGIONS:
		if Biomes.in_isles(region[1]) != isles:
			continue
		var offset: Vector2i = cell - region[1]
		var distance: int = offset.x * offset.x + offset.y * offset.y
		if distance < nearest:
			nearest = distance
			best = region[0]
	return best


## Every region name, the desert included.
static func names() -> Array[String]:
	var result: Array[String] = [DESERT]
	for region: Array in REGIONS:
		result.append(region[0])
	return result


static func description(name: String) -> String:
	if name == DESERT:
		return DESERT_TEXT
	for region: Array in REGIONS:
		if region[0] == name:
			return region[2]
	return ""
