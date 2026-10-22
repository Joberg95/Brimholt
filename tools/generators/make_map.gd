extends SceneTree
## Generates the 384x384 overworld for the Godot map editor: a western coast with one ferry
## from Cinder Landing (top) to Lastlight (bottom), one great central lake with Reedmere and
## Blackreed Isle (a high-level PvP island reached by ferry), safe towns ringing the lake and
## linked by coaches for fast travel, rock ridges in the north-east, a south-western desert, final-boss lairs, and the Hollow Reach endgame zone
## (tools/generators/endgame_zone.gd) in the south-east corner.
##   godot --headless --path . --script res://tools/generators/make_map.gd [-- --force]
## Writes game/maps/terrain.tres (the editor tile set) and game/maps/overworld.tscn.
## It refuses to overwrite an existing overworld unless --force is given: once the map has
## been edited in Godot, that scene is the source of truth. Run the sprite import first.

const SIZE: Vector2i = Vector2i(384, 384)
const TILE: int = 32
const MapIO = preload("res://game/maps/map_io.gd")
const SCENE_PATH: String = "res://game/maps/overworld.tscn"
const TILESET_PATH: String = "res://game/maps/terrain.tres"
const PALETTE: String = "res://assets/sprites/terrain_palette.png"
const FERRYMAN_SCRIPT: Script = preload("res://game/maps/markers/ferryman.gd")
const ITEM_SCRIPT: Script = preload("res://game/maps/markers/item_spawn.gd")
const ZONE_SCRIPT: Script = preload("res://game/maps/markers/zone.gd")
const MONSTER_SCRIPT: Script = preload("res://game/maps/markers/monster_spawn.gd")
const QUEST_SCRIPT: Script = preload("res://game/maps/markers/quest_giver.gd")
const TOWNSFOLK_SCRIPT: Script = preload("res://game/maps/markers/townsfolk.gd")
## Paints the Hollow Reach endgame zone over the generated south-east corner.
const EndgameZone = preload("res://tools/generators/endgame_zone.gd")
## Paints the instanced dungeon copies right of the overworld and their stairways.
const DungeonPainter = preload("res://tools/generators/dungeons.gd")
## Turns trees and grass inside the desert into cacti, scrub, and sand.
const DesertPainter = preload("res://tools/generators/desert.gd")
const TownPainter = preload("res://tools/generators/towns.gd")
const IslandPainter = preload("res://tools/generators/island.gd")
## Quest NPCs: node name, display name, place, cell. The Relic keeper trades boss trophies.
## Quest givers: id, name, place, cell, task (game/data/quests.gd; "" for the Relic keeper).
## Town task givers are added on their town plaza (TASK_GIVERS).
const QUEST_GIVERS: Array = [
	["relic_keeper", "Ysolde", "Cinder Crossing", Vector2i(20, 12), ""],
	["warden_brask", "Warden Brask", "Cinder Crossing", Vector2i(21, 5), "boar_cull"],
]
## Hunting-task givers on a coach town plaza: dock id, id, name, task.
const TASK_GIVERS: Array = [
	["ashford", "captain_ardo", "Captain Ardo", "outlaw_bounty"],
	["emberfall", "marshal_venn", "Marshal Venn", "hollow_purge"],
]
## Every town has a vendor; only Reedmere, the coach and ferry hub, has a banker (the one bank
## and depot in the world): dock id ("cinder" for Cinder Crossing) -> [vendor, (banker)].
const TOWNSFOLK: Dictionary = {
	"cinder": ["Merchant Tobin"], "cinder_landing": ["Merchant Coll"],
	"lastlight": ["Merchant Esra"], "reedmere": ["Merchant Lise", "Banker Orrin"],
	"ashford": ["Merchant Garrow"], "emberfall": ["Merchant Kesh"],
	"dunmere": ["Merchant Saba"], "highmoor": ["Merchant Rook"],
}
## Stairways down into the instanced dungeons, inside a house of their town: Cinder Crossing's
## north-east house, an Ashford house (the chapel), and a Highmoor house.
const DUNGEON_ENTRANCES: Dictionary = {"cinder_cellar": Vector2i(17, 5)}
## Coach-town dungeons: dungeon id -> [town dock id, offset from the plaza centre].
const TOWN_DUNGEONS: Dictionary = {"ashford_crypt": ["ashford", Vector2i(-9, 10)], "highmoor_mine": ["highmoor", Vector2i(9, -10)]}
## Cinder Crossing's vendor (and a spare spot) flank the south road.
const CINDER_TOWNSFOLK: Array[Vector2i] = [Vector2i(9, 13), Vector2i(14, 16)]
## Palette order in terrain_palette.png; the tile set stores each as custom data "terrain".
const TERRAINS: Array[String] = [".", ",", "~", "#", "T", ":", "=", "b", "d", "o", "O", "D", "c", "C", "v", "^", "K", "R", "L", "W", "m", "U", "s", "P", "F", "Y"]
const WALKABLE: String = ".,:=b"
## The great lake is the old one scaled by LAKE_SCALE around LAKE_CENTER.
const LAKE_SCALE: float = 0.8
const LAKE_CENTER: Vector2 = Vector2(200, 190)
const ISLAND_CENTER: Vector2 = Vector2(208, 194)
const ISLAND_RADIUS: float = 15.0
## The original starting town, now with east and south gates.
const CINDER: Array[String] = [
	"########################",
	"#...........#..........#",
	"#..~~~......#..........#",
	"#..~~~......#...####...#",
	"#..~~~..........#..#...#",
	"#...............#..#...#",
	"#...,,,,,,,,,,,,,,,....#",
	"#...,...#...#.....,....#",
	"#...,...#...#.....,,,,,,",
	"#...,...#.........,,,,,,",
	"#...,,,,,,,,,,,,,,,....#",
	"#.......#..,,..........#",
	"#.......#..,,.~~~......#",
	"#..........,,.~~~......#",
	"#..####....,,.~~~......#",
	"#..........,,..........#",
	"#..........,,..........#",
	"###########,,###########",
]
const SPAWNS: Array[Vector2i] = [
	Vector2i(5, 6), Vector2i(7, 6), Vector2i(9, 6), Vector2i(11, 6), Vector2i(13, 6), Vector2i(15, 6),
	Vector2i(17, 6), Vector2i(5, 10), Vector2i(7, 10), Vector2i(9, 10), Vector2i(11, 10), Vector2i(13, 10),
]
const STARTER_ITEMS: Array = [
	[Vector2i(14, 9), "iron_coif"], [Vector2i(20, 15), "ash_tunic"],
	[Vector2i(2, 12), "flint_hatchet"], [Vector2i(10, 1), "glowcap"], [Vector2i(10, 1), "glowcap"],
	[Vector2i(3, 15), "yew_hunting_bow"], [Vector2i(17, 4), "spark_wand"], [Vector2i(21, 1), "thornwood_rod"],
]
## Coastal ports on the western sea: id, ferryman, town, row.
## The coast has one ferry, top to bottom: id, ferryman, town, row.
const PORTS: Array = [
	["cinder_landing", "Ferryman Ostrel", "Cinder Landing", 46],
	["lastlight", "Ferryman Odo", "Lastlight", 350],
]
## Inland towns with a coach station: id, coachman, town, plaza centre. They ring the central
## lake (Reedmere is on its west shore), far from the Hollow Reach; Highmoor is an outpost.
const COACH_TOWNS: Array = [
	["ashford", "Coachman Merrit", "Ashford", Vector2i(200, 116)],
	["emberfall", "Coachman Rusk", "Emberfall", Vector2i(290, 196)],
	["dunmere", "Coachwoman Fenna", "Dunmere", Vector2i(196, 268)],
	["highmoor", "Coachwoman Dalla", "Highmoor", Vector2i(330, 86)],
]
## Towns are safe zones: no PvP, and monsters (which never cross zone borders) stay out.
## Cinder Crossing's zone reaches east over its coach stop.
const CINDER_TOWN: Rect2i = Rect2i(0, 0, 40, 22)
## Coach stations outside Cinder Crossing's east gate and on Reedmere's plaza.
const CINDER_COACH: Vector2i = Vector2i(34, 9)
## Ferries sail between every port (and Reedmere to the island); coaches run between every station.
const COACHES: Array[String] = ["cinder_coach", "ashford", "highmoor", "emberfall", "dunmere", "reedmere_coach"]
var ROUTES: Dictionary = {}
const ISLAND_FARE: int = 40
## Mainland monsters by level band (upper level, monster id). Level rises gently with
## distance from Cinder Crossing (STARTER_RADIUS tiles of levels 1-4, then about one level
## per LEVEL_TILES), reaching 35 in the far east and south.
const MAINLAND_MONSTERS: Array = [
	[2, "black_cat"], [4, "mud_grub"], [7, "wild_hog"], [10, "brigand"], [14, "giant_wasp"],
	[18, "bog_grub"], [23, "star_mage"], [28, "stone_gargoyle"], [32, "fire_mage"], [35, "skeleton_warrior"],
	[39, "mire_ghost"], [42, "fen_dragon"], [45, "fen_dragon"],
]
## Spawns are dense on the compact overworld and at least SPAWN_SPACING tiles
## apart (STARTER_SPACING near Cinder Crossing).
const MAINLAND_SPAWNS: int = 280
const STARTER_SPAWNS: int = 14
const SPAWN_SPACING: float = 10.0
const STARTER_SPACING: float = 6.0
const STARTER_RADIUS: float = 48.0
const LEVEL_TILES: float = 10.0
const MAINLAND_MAX_LEVEL: int = 45
## Spawns keep this many tiles from roads so travel between towns stays safe.
const ROAD_CLEARANCE: int = 5
const ISLAND_ZONE: Dictionary = {"name": "Blackreed Isle", "pvp": true, "min_level": 40, "max_level": 50}
## Placeholder high-level monsters for the island: id, level.
const ISLAND_MONSTERS: Array = [
	["mire_ghost", 40], ["fen_dragon", 42], ["fen_dragon", 45], ["mire_ghost", 44],
	["fen_dragon", 47], ["fen_dragon", 48], ["blackreed_warden", 50],
]

## Vendors (and Reedmere's banker) and the hunting-task givers, on open plaza tiles: in a
## coach town either side of the coachman, in a shore town on the landward side of the plaza.
func _people() -> void:
	for giver: Array in QUEST_GIVERS:
		people.append([giver[0], giver[1], giver[2], giver[3], giver[4], "quest"])
	for town: String in TOWNSFOLK:
		var cells: Array[Vector2i] = CINDER_TOWNSFOLK
		var place: String = "Cinder Crossing"
		if town != "cinder":
			var dock: Dictionary = docks[town]
			place = dock["place"]
			if town in COACHES or dock["facing"] == Vector2i.DOWN:
				cells = [dock["plaza"] + Vector2i(-4, 2), dock["plaza"] + Vector2i(4, 2)]
			else:
				var back: Vector2i = dock["plaza"] - dock["facing"] * 3
				cells = [back + Vector2i(0, -4), back + Vector2i(0, 4)]
		for index: int in TOWNSFOLK[town].size():
			var role: String = ["vendor", "banker"][index]
			people.append(["%s_%s" % [town, role], TOWNSFOLK[town][index], place, cells[index], role, "townsfolk"])
	for giver: Array in TASK_GIVERS:
		people.append([giver[1], giver[2], docks[giver[0]]["place"], docks[giver[0]]["plaza"] + Vector2i(0, 4), giver[3], "quest"])
	for person: Array in people:
		if at(person[3]) not in [".", ",", "=", ":"]:
			printerr("%s stands on blocked terrain at %s" % [person[1], person[3]])


## Final-boss lairs near these targets (moved to the nearest open, off-road tile): monster id,
## target. Morvain's lair is found at the far east end of Blackreed Isle.
const BOSS_TARGETS: Array = [["kharzul", Vector2i(352, 48)], ["sylvaine", Vector2i(296, 352)]]

var grid: PackedByteArray
var rng := RandomNumberGenerator.new()
var docks: Dictionary = {}
## Tiles of the sea and the lake (not the town ponds), used for beaches.
var big_water: Dictionary = {}
var monster_spawns: Array = []
## Blackreed Isle's land and pier, grown by a tile: its PvP zone.
var island_rect: Rect2i
## Placed NPCs: [id, name, place, cell, role or task, kind ("townsfolk" or "quest")].
var people: Array = []


func _initialize() -> void:
	if FileAccess.file_exists(SCENE_PATH) and "--force" not in OS.get_cmdline_user_args():
		printerr("%s already exists; pass -- --force to replace it and lose map edits." % SCENE_PATH)
		quit(1)
		return
	rng.seed = 5
	grid.resize(SIZE.x * SIZE.y)
	grid.fill(".".unicode_at(0))
	_terrain()
	_border()
	_ocean()
	_lake()
	_beaches()
	_cinder()
	for port: Array in PORTS:
		_shore_town(port[0], port[1], port[2], Vector2i(0, port[3]), Vector2i.RIGHT)
	var lake_start := Vector2i(roundi(ISLAND_CENTER.x - ISLAND_RADIUS * 1.25 - 8.0), roundi(ISLAND_CENTER.y))
	_shore_town("reedmere", "Boatwright Ilse", "Reedmere", lake_start, Vector2i.LEFT)
	_island()
	_ridges()
	_desert()
	for town: Array in COACH_TOWNS:
		_coach_town(town[0], town[1], town[2], town[3])
	_coach_stop("cinder_coach", "Coachman Pell", "Cinder Crossing", CINDER_COACH)
	_coach_stop("reedmere_coach", "Coachwoman Ilse", "Reedmere", docks["reedmere"]["plaza"] + Vector2i(0, 4))
	_routes()
	_roads()
	_people()
	var items: Array = _items()
	_mainland_spawns(items)
	_boss_lairs()
	if not _validate(items):
		quit(1)
		return
	_save(items)
	quit()


func at(cell: Vector2i) -> String:
	if cell.x < 0 or cell.y < 0 or cell.x >= SIZE.x or cell.y >= SIZE.y:
		return ""
	return char(grid[cell.y * SIZE.x + cell.x])


func put(cell: Vector2i, terrain: String) -> void:
	if cell.x >= 0 and cell.y >= 0 and cell.x < SIZE.x and cell.y < SIZE.y:
		grid[cell.y * SIZE.x + cell.x] = terrain.unicode_at(0)


func _noise(seed_value: int, frequency: float) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency
	return noise


func _terrain() -> void:
	var forest: FastNoiseLite = _noise(11, 0.07)
	for y: int in SIZE.y:
		for x: int in SIZE.x:
			var n: float = forest.get_noise_2d(x, y)
			if n > 0.28 or (n > 0.1 and rng.randf() < 0.3) or rng.randf() < 0.012:
				put(Vector2i(x, y), "T")
	for ruin: int in 12:
		var corner := Vector2i(rng.randi_range(30, SIZE.x - 40), rng.randi_range(30, SIZE.y - 40))
		if Vector2(corner).distance_to(LAKE_CENTER) < 60.0 or corner.x < 40:
			continue
		for x: int in 7:
			for y: int in 6:
				var edge: bool = x == 0 or y == 0 or x == 6 or y == 5
				put(corner + Vector2i(x, y), "#" if edge and rng.randf() < 0.75 else ".")


func _water(cell: Vector2i) -> void:
	put(cell, "~")
	big_water[cell] = true


## The western sea: an irregular coast that starts below Cinder Crossing.
func _ocean() -> void:
	var shape: FastNoiseLite = _noise(31, 0.06)
	for y: int in SIZE.y:
		var ramp: float = clampf((y - 26) / 14.0, 0.0, 1.0)
		var width: float = ramp * (20.0 + 8.0 * shape.get_noise_1d(y) + 4.0 * shape.get_noise_1d(y * 3.0 + 500.0))
		for x: int in ceili(width):
			_water(Vector2i(x, y))


## One irregular lake: a stretched, noisy main body plus a north-east lobe and a southern bay.
func _lake() -> void:
	var shape: FastNoiseLite = _noise(37, 0.05)
	for y: int in SIZE.y:
		for x: int in SIZE.x:
			var point := Vector2(x, y)
			var edge: float = 14.0 * shape.get_noise_2d(x, y)
			if ((point - LAKE_CENTER) / Vector2(1.45, 1.0)).length() < (38.0 + edge) * LAKE_SCALE \
					or point.distance_to(LAKE_CENTER + Vector2(38, -34) * LAKE_SCALE) < (20.0 + edge * 0.7) * LAKE_SCALE \
					or point.distance_to(LAKE_CENTER + Vector2(-30, 38) * LAKE_SCALE) < (16.0 + edge * 0.6) * LAKE_SCALE:
				_water(Vector2i(x, y))


func _beaches() -> void:
	for water: Vector2i in big_water:
		var reach: int = 3 if water.x < 60 else 2
		if water.x >= 60 and Vector2(water).distance_to(LAKE_CENTER) > 110.0:
			continue
		for dy: int in range(-reach, reach + 1):
			for dx: int in range(-reach, reach + 1):
				var cell: Vector2i = water + Vector2i(dx, dy)
				if at(cell) in [".", "T"] and (water.x < 60 or rng.randf() < 0.8):
					put(cell, ":")


func _border() -> void:
	for y: int in SIZE.y:
		for x: int in SIZE.x:
			var edge: int = mini(mini(x, y), mini(SIZE.x - 1 - x, SIZE.y - 1 - y))
			if edge < 3 or (edge < 5 and rng.randf() < 0.6):
				put(Vector2i(x, y), "T")


func _cinder() -> void:
	for y: int in 22:
		for x: int in 28:
			put(Vector2i(x, y), ".")
	for y: int in CINDER.size():
		for x: int in CINDER[y].length():
			put(Vector2i(x, y), CINDER[y][x])


func _fill(center: Vector2i, axis: Vector2i, along: Array, across: Array, terrain: String) -> void:
	var perp := Vector2i(absi(axis.y), absi(axis.x))
	for a: int in range(along[0], along[1] + 1):
		for p: int in range(across[0], across[1] + 1):
			put(center + axis * a + perp * p, terrain)


func _pier(shore: Vector2i, outward: Vector2i, length: int) -> Vector2i:
	var perp := Vector2i(absi(outward.y), absi(outward.x))
	for k: int in range(0, length + 1):
		for w: int in range(-1, 2):
			var cell: Vector2i = shore + outward * k + perp * w
			put(cell, "b" if at(cell) == "~" else "=")
	return shore + outward * length


## A town on a shore: march from start along outward (from water toward land) to the
## shore, then build a pier with the ferryman, a plaza with two houses, and a gate inland.
func _shore_town(id: String, npc_name: String, place: String, start: Vector2i, outward: Vector2i) -> void:
	var axis: Vector2i = outward
	var cell: Vector2i = start
	while at(cell) == "~":
		cell += axis
	var shore: Vector2i = cell
	var ferryman: Vector2i = _pier(shore - axis, -axis, 6)
	_fill(shore, axis, [0, 4], [-1, 1], "=")
	_fill(shore + axis * 10, axis, [-5, 5], [-7, 7], "=")
	for side: int in [-1, 1]:
		_fill(shore + axis * 12, axis, [-2, 2], [3 * side if side > 0 else -7, 7 if side > 0 else -3], "#")
		_fill(shore + axis * 12, axis, [-1, 1], [4 * side if side > 0 else -6, 6 if side > 0 else -4], "=")
		put(shore + axis * 12 + Vector2i(absi(axis.y), absi(axis.x)) * 3 * side, "=")
	var gate: Vector2i = shore + axis * 16
	_fill(gate, axis, [0, 1], [-1, 1], ",")
	var land_side: int = shore.x - 7 if axis == Vector2i.RIGHT else shore.x - 17
	docks[id] = {"name": npc_name, "place": place, "cell": ferryman, "facing": axis, "gate": gate + axis,
		"plaza": shore + axis * 10, "town": Rect2i(land_side, shore.y - 8, 25, 17)}


## Blackreed Isle: dense forest, ruins, crossing trails, and a pier facing Reedmere.
func _island() -> void:
	var shape: FastNoiseLite = _noise(41, 0.2)
	var center := Vector2i(ISLAND_CENTER)
	var reach: int = ceili(ISLAND_RADIUS * 1.25) + 5
	for y: int in range(center.y - reach, center.y + reach + 1):
		for x: int in range(center.x - reach, center.x + reach + 1):
			var distance: float = ((Vector2(x, y) - ISLAND_CENTER) / Vector2(1.25, 1.0)).length()
			if distance < ISLAND_RADIUS + 3.5 * shape.get_noise_2d(x, y):
				var inner: bool = distance < ISLAND_RADIUS - 2.5
				big_water.erase(Vector2i(x, y))
				put(Vector2i(x, y), ("T" if rng.randf() < 0.4 else ".") if inner else ":")
	for ruin: Vector2i in [center + Vector2i(-7, -6), center + Vector2i(4, 3)]:
		for x: int in 5:
			for y: int in 4:
				if (x == 0 or y == 0 or x == 4 or y == 3) and rng.randf() < 0.7:
					put(ruin + Vector2i(x, y), "#")
	for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var trail: Vector2i = center
		while at(trail) != "~" and at(trail) != "":
			put(trail, ",")
			trail += step
	var shore: Vector2i = center
	while at(shore + Vector2i.LEFT) != "~":
		shore += Vector2i.LEFT
	var ferryman: Vector2i = _pier(shore + Vector2i.LEFT, Vector2i.LEFT, 5)
	island_rect = Rect2i(ferryman, Vector2i.ONE)
	for y: int in range(center.y - reach, center.y + reach + 1):
		for x: int in range(center.x - reach, center.x + reach + 1):
			if at(Vector2i(x, y)) not in ["~", ""] and Vector2(x, y).distance_to(ISLAND_CENTER) <= reach:
				island_rect = island_rect.expand(Vector2i(x, y))
	island_rect = island_rect.grow(1)
	docks["blackreed_isle"] = {"name": "Old Marra", "place": "Blackreed Isle", "cell": ferryman, "facing": Vector2i.RIGHT}
	var cells: Array = _flood(center, _blocked()).keys()
	cells.sort()
	var placed: int = 0
	while placed < ISLAND_MONSTERS.size():
		var cell: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		if at(cell) in [".", ","] and Vector2(cell).distance_to(Vector2(ferryman)) > 6.0:
			monster_spawns.append([cell] + ISLAND_MONSTERS[placed])
			placed += 1


func _roads() -> void:
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(Vector2i.ZERO, SIZE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()
	var weights: Dictionary = {".": 1.5, ",": 0.6, ":": 2.0, "=": 1.0, "T": 6.0}
	for y: int in SIZE.y:
		for x: int in SIZE.x:
			var cell := Vector2i(x, y)
			var terrain: String = at(cell)
			if not weights.has(terrain) or (x < 24 and y < 18):
				astar.set_point_solid(cell)
			else:
				astar.set_point_weight_scale(cell, weights[terrain])
	for id: String in docks:
		astar.set_point_solid(docks[id]["cell"])
	var legs: Array = [[Vector2i(11, 18), docks["cinder_landing"]["gate"]], [Vector2i(24, 8), docks["cinder_coach"]["gate"]]]
	for index: int in PORTS.size() - 1:
		legs.append([docks[PORTS[index][0]]["gate"], docks[PORTS[index + 1][0]]["gate"]])
	for pair: Array in [["cinder_coach", "ashford"], ["ashford", "highmoor"], ["highmoor", "emberfall"],
			["ashford", "reedmere"], ["ashford", "emberfall"], ["emberfall", "dunmere"], ["reedmere", "dunmere"],
			["dunmere", "lastlight"]]:
		legs.append([docks[pair[0]].get("gate", docks[pair[0]]["cell"]), docks[pair[1]].get("gate", docks[pair[1]]["cell"])])
	for leg: Array in legs:
		for cell: Vector2i in astar.get_id_path(leg[0], leg[1]):
			if at(cell) in [".", "T", ":"]:
				put(cell, ",")
				astar.set_point_weight_scale(cell, weights[","])


## Ferries between every coastal port and Reedmere to the island; coaches between every station.
func _routes() -> void:
	for port: Array in PORTS:
		ROUTES[port[0]] = PORTS.map(func(other: Array) -> String: return other[0]).filter(func(id: String) -> bool: return id != port[0])
	ROUTES["reedmere"] = ["blackreed_isle"]
	ROUTES["blackreed_isle"] = ["reedmere"]
	for coach: String in COACHES:
		ROUTES[coach] = COACHES.filter(func(id: String) -> bool: return id != coach)


## Grey rock ridges across the north-east: thin walls with passes, read as cliffs.
func _ridges() -> void:
	var ridge: FastNoiseLite = _noise(53, 0.036)
	ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	for y: int in range(10, 170):
		for x: int in range(235, SIZE.x - 6):
			var value: float = ridge.get_noise_2d(x, y)
			if value > 0.72 and at(Vector2i(x, y)) in [".", "T"] and rng.randf() < 0.92:
				put(Vector2i(x, y), "#")


## The Dunmere desert: sand instead of most trees, with scattered survivors.
func _desert() -> void:
	var shape: FastNoiseLite = _noise(59, 0.04)
	var centre := Vector2(118, 300)
	for y: int in range(int(centre.y) - 60, int(centre.y) + 60):
		for x: int in range(maxi(35, int(centre.x) - 80), int(centre.x) + 80):
			var cell := Vector2i(x, y)
			var inside: float = ((Vector2(x, y) - centre) / Vector2(75.0, 52.0)).length() + 0.25 * shape.get_noise_2d(x, y)
			if inside < 1.0 and at(cell) in [".", "T"]:
				put(cell, "T" if at(cell) == "T" and rng.randf() < 0.08 else ":")


## An inland town: a cobbled plaza with four houses, a coachman, and road gates on all sides.
func _coach_town(id: String, npc_name: String, place: String, centre: Vector2i) -> void:
	for y: int in range(-14, 15):
		for x: int in range(-14, 15):
			put(centre + Vector2i(x, y), ".")
	for y: int in range(-7, 8):
		for x: int in range(-7, 8):
			put(centre + Vector2i(x, y), "=")
	for corner: Vector2i in [Vector2i(-12, -12), Vector2i(6, -12), Vector2i(-12, 7), Vector2i(6, 7)]:
		for y: int in 6:
			for x: int in 7:
				var edge: bool = x == 0 or y == 0 or x == 6 or y == 5
				put(centre + corner + Vector2i(x, y), "#" if edge else "=")
		put(centre + corner + Vector2i(3, 5 if corner.y < 0 else 0), "=")
	for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		for k: int in range(8, 16):
			for w: int in range(-1, 2):
				put(centre + step * k + Vector2i(absi(step.y), absi(step.x)) * w, ",")
	var coachman: Vector2i = centre + Vector2i(0, -3)
	docks[id] = {"name": npc_name, "place": place, "cell": coachman, "facing": Vector2i.DOWN, "gate": centre + Vector2i(0, 16),
		"plaza": centre, "town": Rect2i(centre - Vector2i(15, 15), Vector2i(31, 31))}


## A coach stop: a small cobbled square with a coachman.
func _coach_stop(id: String, npc_name: String, place: String, cell: Vector2i) -> void:
	for y: int in range(-3, 4):
		for x: int in range(-3, 4):
			put(cell + Vector2i(x, y), "=")
	docks[id] = {"name": npc_name, "place": place, "cell": cell, "facing": Vector2i.DOWN, "gate": cell + Vector2i(0, 4),
		"stop": true}


## Final-boss lairs: Morvain at the far east of Blackreed Isle, the others near BOSS_TARGETS,
## each on the nearest open tile away from roads.
func _boss_lairs() -> void:
	var island: Array = _flood(Vector2i(ISLAND_CENTER), _blocked()).keys()
	island.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x > b.x)
	for cell: Vector2i in island:
		if at(cell) in [".", ","] and _open_around(cell):
			monster_spawns.append([cell, "morvain", 50, 1, 1])
			break
	var near_roads: Dictionary = _near_roads()
	for target: Array in BOSS_TARGETS:
		var best: Vector2i = Vector2i(-1, -1)
		for radius: int in range(0, 30):
			for dy: int in range(-radius, radius + 1):
				for dx: int in range(-radius, radius + 1):
					var cell: Vector2i = target[1] + Vector2i(dx, dy)
					if best.x < 0 and maxi(absi(dx), absi(dy)) == radius and at(cell) in [".", ":"] \
							and not near_roads.has(cell) and _open_around(cell):
						best = cell
			if best.x >= 0:
				break
		for dy: int in range(-3, 4):
			for dx: int in range(-3, 4):
				if at(best + Vector2i(dx, dy)) in ["T", "#"]:
					put(best + Vector2i(dx, dy), ".")
		monster_spawns.append([best, target[0], 50, 1, 1])


func _open_around(cell: Vector2i) -> bool:
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if at(cell + Vector2i(dx, dy)) not in [".", ",", ":"]:
				return false
	return true


func _flood(start: Vector2i, blocked: Dictionary) -> Dictionary:
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + step
			if not seen.has(next) and not blocked.has(next) and at(next) != "" and at(next) in WALKABLE:
				seen[next] = true
				queue.append(next)
	return seen


func _blocked() -> Dictionary:
	var blocked: Dictionary = {}
	for id: String in docks:
		blocked[docks[id]["cell"]] = true
	return blocked


func _items() -> Array:
	var items: Array = STARTER_ITEMS.duplicate()
	for spawn: Array in monster_spawns:
		var beside: Vector2i = spawn[0] + Vector2i.RIGHT
		items.append([beside if at(beside) in [".", ","] else spawn[0], "gold_coins"])
	var land: Dictionary = _flood(SPAWNS[0], _blocked())
	var cells: Array = land.keys()
	cells.sort()
	var placed: int = 0
	while placed < 80:
		var cell: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		if (cell.x < 30 and cell.y < 24) or at(cell) not in [".", ",", ":"] or EndgameZone.AREA.grow(6).has_point(cell):
			continue
		var near_town: bool = false
		for id: String in docks:
			near_town = near_town or Vector2(cell).distance_to(Vector2(docks[id]["cell"])) < 18.0
		if near_town:
			continue
		var forest: bool = at(cell + Vector2i.UP) == "T" or at(cell + Vector2i.LEFT) == "T"
		items.append([cell, "glowcap" if forest and placed % 3 == 0 else "gold_coins"])
		placed += 1
	return items


func _level_at(cell: Vector2i) -> int:
	var distance: float = Vector2(cell).distance_to(Vector2(12, 9))
	if distance <= STARTER_RADIUS:
		return clampi(1 + floori((distance - 14.0) / 8.0), 1, 4)
	return clampi(5 + floori((distance - STARTER_RADIUS - 12.0) / LEVEL_TILES), 5, MAINLAND_MAX_LEVEL)


## Tiles within ROAD_CLEARANCE steps of a dirt road (town gates included).
func _near_roads() -> Dictionary:
	var near: Dictionary = {}
	var frontier: Array[Vector2i] = []
	for y: int in SIZE.y:
		for x: int in SIZE.x:
			if at(Vector2i(x, y)) == ",":
				near[Vector2i(x, y)] = 0
				frontier.append(Vector2i(x, y))
	for depth: int in ROAD_CLEARANCE:
		var next: Array[Vector2i] = []
		for cell: Vector2i in frontier:
			for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if not near.has(cell + step):
					near[cell + step] = depth + 1
					next.append(cell + step)
		frontier = next
	return near


func _mainland_spawns(items: Array) -> void:
	var land: Dictionary = _flood(SPAWNS[0], _blocked())
	var near_roads: Dictionary = _near_roads()
	var cells: Array = land.keys()
	cells.sort()
	var taken: Array[Vector2i] = []
	var starters: int = 0
	var placed: int = 0
	var attempts: int = 0
	while placed < MAINLAND_SPAWNS and attempts < 200000:
		attempts += 1
		var cell: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		var starter: bool = Vector2(cell).distance_to(Vector2(12, 9)) <= STARTER_RADIUS
		if at(cell) not in [".", ",", ":"] or near_roads.has(cell) or (cell.x < 30 and cell.y < 24) \
				or EndgameZone.AREA.grow(8).has_point(cell) or CINDER_TOWN.grow(3).has_point(cell):
			continue
		if starter == (starters >= STARTER_SPAWNS):
			continue
		var clear: bool = true
		for id: String in docks:
			var clearance: float = 8.0 if docks[id].get("stop", false) else 19.0
			clear = clear and Vector2(cell).distance_to(Vector2(docks[id]["cell"])) > clearance
		for other: Vector2i in taken:
			clear = clear and Vector2(cell).distance_to(Vector2(other)) > (STARTER_SPACING if starter else SPAWN_SPACING)
		for item: Array in items:
			clear = clear and item[0] != cell
		if not clear:
			continue
		var level: int = _level_at(cell)
		var monster: String = MAINLAND_MONSTERS[-1][1]
		for band: Array in MAINLAND_MONSTERS:
			if level <= band[0]:
				monster = band[1]
				break
		monster_spawns.append([cell, monster, level, 3 if level <= 10 else 2])
		# A small clearing so monsters can roam and players can reach and see them.
		for dy: int in range(-3, 4):
			for dx: int in range(-3, 4):
				if dx * dx + dy * dy <= 10 and at(cell + Vector2i(dx, dy)) == "T":
					put(cell + Vector2i(dx, dy), ".")
		taken.append(cell)
		placed += 1
		if starter:
			starters += 1
	if starters < STARTER_SPAWNS:
		printerr("Only %d starter spawns fit near Cinder Crossing" % starters)


func _validate(items: Array) -> bool:
	var blocked: Dictionary = _blocked()
	var land: Dictionary = _flood(SPAWNS[0], blocked)
	var ok: bool = true
	for id: String in docks:
		var reachable: bool = false
		var component: Dictionary = land if id != "blackreed_isle" else _flood(Vector2i(ISLAND_CENTER), blocked)
		for dy: int in range(-2, 3):
			for dx: int in range(-2, 3):
				reachable = reachable or component.has(docks[id]["cell"] + Vector2i(dx, dy))
		if not reachable:
			printerr("Dock %s is not reachable" % id)
			ok = false
	var island: Dictionary = _flood(Vector2i(ISLAND_CENTER), blocked)
	for spawn: Array in monster_spawns:
		if not island.has(spawn[0]) and not land.has(spawn[0]):
			printerr("Monster spawn at %s is not reachable" % spawn[0])
			ok = false
	for item: Array in items:
		if not land.has(item[0]) and not island.has(item[0]):
			printerr("Item at %s is not reachable" % item[0])
			ok = false
	var entrances: Dictionary = dungeon_entrances()
	for id: String in entrances:
		if not land.has(entrances[id]) or at(entrances[id]) not in ["=", "."]:
			printerr("The %s stairway at %s is not on a reachable floor" % [id, entrances[id]])
			ok = false
	for person: Array in people:
		var reachable: bool = false
		for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			reachable = reachable or land.has(person[3] + step)
		if not reachable:
			printerr("%s at %s is not reachable" % [person[1], person[3]])
			ok = false
	print("Walkable tiles reachable on foot from Cinder Crossing: %d" % land.size())
	return ok


func _save(items: Array) -> void:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	tileset.add_custom_data_layer()
	tileset.set_custom_data_layer_name(0, "terrain")
	tileset.set_custom_data_layer_type(0, TYPE_STRING)
	var source := TileSetAtlasSource.new()
	source.texture = load(PALETTE)
	source.texture_region_size = Vector2i(TILE, TILE)
	tileset.add_source(source, 0)
	for index: int in TERRAINS.size():
		source.create_tile(Vector2i(index, 0))
		source.get_tile_data(Vector2i(index, 0), 0).set_custom_data("terrain", TERRAINS[index])
	ResourceSaver.save(tileset, TILESET_PATH)
	tileset.take_over_path(TILESET_PATH)
	var scene_root := Node2D.new()
	scene_root.name = "Overworld"
	var layer := TileMapLayer.new()
	layer.name = "Terrain"
	layer.tile_set = tileset
	_add(scene_root, layer)
	for y: int in SIZE.y:
		for x: int in SIZE.x:
			layer.set_cell(Vector2i(x, y), 0, Vector2i(TERRAINS.find(at(Vector2i(x, y))), 0))
	var spawns: Node2D = _add(scene_root, _named(Node2D.new(), "Spawns"))
	for index: int in SPAWNS.size():
		var marker: Marker2D = _named(Marker2D.new(), "Spawn%d" % (index + 1))
		marker.position = _centre(SPAWNS[index])
		_add(spawns, marker, scene_root)
	var ferrymen: Node2D = _add(scene_root, _named(Node2D.new(), "Ferrymen"))
	for id: String in ROUTES:
		var dock: Dictionary = docks[id]
		var marker: Marker2D = _named(Marker2D.new(), id)
		marker.set_script(FERRYMAN_SCRIPT)
		marker.position = _centre(dock["cell"])
		marker.set("npc_name", dock["name"])
		marker.set("place", dock["place"])
		marker.set("facing", dock["facing"])
		marker.set("vehicle", "waystone" if id in COACHES else "ferry")
		if id in COACHES:
			marker.set("npc_name", "Waystone")
		var fares: Dictionary[String, int] = {}
		for destination: String in ROUTES[id]:
			var distance: float = Vector2(dock["cell"]).distance_to(Vector2(docks[destination]["cell"]))
			# Fast travel stays affordable for new characters (100 gold): the long coastal ferry is 65.
			fares[destination] = ISLAND_FARE if "blackreed_isle" in [id, destination] \
				else (5 + 5 * roundi(distance / 60.0) if id in COACHES else 10 + 5 * roundi(distance / 60.0))
		marker.set("routes", fares)
		_add(ferrymen, marker, scene_root)
	var item_root: Node2D = _add(scene_root, _named(Node2D.new(), "Items"))
	for index: int in items.size():
		var marker: Marker2D = _named(Marker2D.new(), "%s%d" % [String(items[index][1]).to_pascal_case(), index + 1])
		marker.set_script(ITEM_SCRIPT)
		marker.position = _centre(items[index][0])
		marker.set("item", items[index][1])
		_add(item_root, marker, scene_root)
	var zones: Node2D = _add(scene_root, _named(Node2D.new(), "Zones"))
	var zone: Node2D = _named(Node2D.new(), "BlackreedIsle")
	zone.set_script(ZONE_SCRIPT)
	zone.position = Vector2(island_rect.position * TILE)
	zone.set("size_tiles", island_rect.size + Vector2i.ONE)
	for key: String in ["min_level", "max_level", "pvp"]:
		zone.set(key, ISLAND_ZONE[key])
	zone.set("zone_name", ISLAND_ZONE["name"])
	_add(zones, zone, scene_root)
	var towns: Array = [["Cinder Crossing", CINDER_TOWN]]
	for id: String in docks:
		if docks[id].has("town"):
			towns.append([docks[id]["place"], docks[id]["town"]])
	for town: Array in towns:
		var safe: Node2D = _named(Node2D.new(), String(town[0]).to_pascal_case())
		safe.set_script(ZONE_SCRIPT)
		safe.position = Vector2(town[1].position * TILE)
		safe.set("size_tiles", town[1].size)
		safe.set("zone_name", town[0])
		safe.set("town", true)
		_add(zones, safe, scene_root)
	var monster_root: Node2D = _add(scene_root, _named(Node2D.new(), "MonsterSpawns"))
	for index: int in monster_spawns.size():
		var marker: Marker2D = _named(Marker2D.new(), "%s%d" % [String(monster_spawns[index][1]).to_pascal_case(), index + 1])
		marker.set_script(MONSTER_SCRIPT)
		marker.position = _centre(monster_spawns[index][0])
		marker.set("monster", monster_spawns[index][1])
		marker.set("level", monster_spawns[index][2])
		marker.set("count", monster_spawns[index][3] if monster_spawns[index].size() > 3
			else (3 if monster_spawns[index][2] < 50 else 1))
		if monster_spawns[index].size() > 4:
			marker.set("radius", monster_spawns[index][4])
		_add(monster_root, marker, scene_root)
	EndgameZone.apply(scene_root)
	DesertPainter.apply(scene_root)
	DungeonPainter.apply(scene_root, dungeon_entrances())
	var quest_root: Node2D = _add(scene_root, _named(Node2D.new(), "QuestGivers"))
	var folk_root: Node2D = _add(scene_root, _named(Node2D.new(), "Townsfolk"))
	for person: Array in people:
		var marker: Marker2D = _named(Marker2D.new(), person[0])
		marker.set_script(QUEST_SCRIPT if person[5] == "quest" else TOWNSFOLK_SCRIPT)
		marker.position = _centre(person[3])
		marker.set("npc_name", person[1])
		marker.set("place", person[2])
		marker.set("task" if person[5] == "quest" else "role", person[4])
		_add(quest_root if person[5] == "quest" else folk_root, marker, scene_root)
	TownPainter.apply(scene_root)
	IslandPainter.apply(scene_root)
	var error: Error = MapIO.save_scene(scene_root)
	print("Saved %s (%s)" % [SCENE_PATH, error_string(error)])
	MapIO.free_scene(scene_root)


func dungeon_entrances() -> Dictionary:
	var entrances: Dictionary = DUNGEON_ENTRANCES.duplicate()
	for id: String in DungeonPainter.Dungeons.DUNGEONS:
		if DungeonPainter.Dungeons.DUNGEONS[id].has("entrance"):
			entrances[id] = DungeonPainter.Dungeons.DUNGEONS[id]["entrance"]
	for id: String in TOWN_DUNGEONS:
		entrances[id] = docks[TOWN_DUNGEONS[id][0]]["plaza"] + TOWN_DUNGEONS[id][1]
	return entrances


func _named(node: Node, node_name: String) -> Node:
	node.name = node_name
	return node


func _add(parent: Node, child: Node, owner: Node = null) -> Node:
	parent.add_child(child)
	child.owner = owner if owner != null else parent
	return child


func _centre(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE
