extends SceneTree
## Generates the first-draft 256x256 overworld for the Godot map editor: a western coast with
## four ferry ports, one irregular inland lake with a lakeside town, and Blackreed Isle, a
## high-level PvP hunting island reached by ferry from the lake.
##   godot --headless --path . --script res://tools/make_map.gd [-- --force]
## Writes game/maps/terrain.tres (the editor tile set) and game/maps/overworld.tscn.
## It refuses to overwrite an existing overworld unless --force is given: once the map has
## been edited in Godot, that scene is the source of truth. Run the sprite import first.

const SIZE: Vector2i = Vector2i(256, 256)
const TILE: int = 32
const SCENE_PATH: String = "res://game/maps/overworld.tscn"
const TILESET_PATH: String = "res://game/maps/terrain.tres"
const PALETTE: String = "res://assets/sprites/terrain_palette.png"
const FERRYMAN_SCRIPT: Script = preload("res://game/maps/ferryman.gd")
const ITEM_SCRIPT: Script = preload("res://game/maps/item_spawn.gd")
const ZONE_SCRIPT: Script = preload("res://game/maps/zone.gd")
const MONSTER_SCRIPT: Script = preload("res://game/maps/monster_spawn.gd")
## Palette order in terrain_palette.png; the tile set stores each as custom data "terrain".
const TERRAINS: Array[String] = [".", ",", "~", "#", "T", ":", "=", "b"]
const WALKABLE: String = ".,:=b"
const LAKE_CENTER: Vector2 = Vector2(168, 128)
const ISLAND_CENTER: Vector2 = Vector2(178, 133)
const ISLAND_RADIUS: float = 18.0
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
	[Vector2i(3, 15), "garnet_ring"], [Vector2i(17, 4), "river_pendant"], [Vector2i(21, 1), "hearth_charm"],
]
## Coastal ports on the western sea: id, ferryman, town, row.
const PORTS: Array = [
	["cinder_landing", "Ferryman Ostrel", "Cinder Landing", 46],
	["mossford", "Ferrywoman Brenna", "Mossford", 106],
	["saltmere", "Captain Hollis", "Saltmere", 168],
	["wrenhollow", "Ferryman Tobin", "Wrenhollow", 226],
]
const ROUTES: Dictionary = {
	"cinder_landing": ["mossford", "saltmere", "wrenhollow"],
	"mossford": ["cinder_landing", "saltmere", "wrenhollow"],
	"saltmere": ["cinder_landing", "mossford", "wrenhollow"],
	"wrenhollow": ["cinder_landing", "mossford", "saltmere"],
	"reedmere": ["blackreed_isle"],
	"blackreed_isle": ["reedmere"],
}
const ISLAND_FARE: int = 40
## Mainland monsters by level band (upper level, monster id). Level rises gently with
## distance from Cinder Crossing (STARTER_RADIUS tiles of levels 1-4, then about one level
## per LEVEL_TILES), reaching 35 in the far east and south.
const MAINLAND_MONSTERS: Array = [
	[2, "field_vole"], [4, "marsh_toad"], [7, "thornback_boar"], [10, "road_bandit"], [14, "grey_wolf"],
	[18, "bog_lurker"], [23, "outlaw_archer"], [28, "stone_golem"], [32, "cinder_wraith"], [35, "hollow_knight"],
]
const MAINLAND_SPAWNS: int = 72
const STARTER_SPAWNS: int = 12
const STARTER_RADIUS: float = 45.0
const LEVEL_TILES: float = 8.5
## Spawns keep this many tiles from roads so travel between towns stays safe.
const ROAD_CLEARANCE: int = 7
const ISLAND_ZONE: Dictionary = {"name": "Blackreed Isle", "pvp": true, "min_level": 40, "max_level": 50}
## Placeholder high-level monsters for the island: id, level.
const ISLAND_MONSTERS: Array = [
	["mire_stalker", 40], ["reedfang", 42], ["bog_hulk", 45], ["mire_stalker", 44],
	["reedfang", 47], ["bog_hulk", 48], ["blackreed_warden", 50],
]

var grid: PackedByteArray
var rng := RandomNumberGenerator.new()
var docks: Dictionary = {}
## Tiles of the sea and the lake (not the town ponds), used for beaches.
var big_water: Dictionary = {}
var monster_spawns: Array = []


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
	_roads()
	var items: Array = _items()
	_mainland_spawns(items)
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
	var forest: FastNoiseLite = _noise(11, 0.035)
	for y: int in SIZE.y:
		for x: int in SIZE.x:
			var n: float = forest.get_noise_2d(x, y)
			if n > 0.28 or (n > 0.1 and rng.randf() < 0.3) or rng.randf() < 0.012:
				put(Vector2i(x, y), "T")
	for ruin: int in 5:
		var corner := Vector2i(rng.randi_range(30, 225), rng.randi_range(30, 225))
		if Vector2(corner).distance_to(LAKE_CENTER) < 75.0 or corner.x < 50:
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
	var shape: FastNoiseLite = _noise(31, 0.03)
	for y: int in SIZE.y:
		var ramp: float = clampf((y - 26) / 14.0, 0.0, 1.0)
		var width: float = ramp * (20.0 + 8.0 * shape.get_noise_1d(y) + 4.0 * shape.get_noise_1d(y * 3.0 + 500.0))
		for x: int in ceili(width):
			_water(Vector2i(x, y))


## One irregular lake: a stretched, noisy main body plus a north-east lobe and a southern bay.
func _lake() -> void:
	var shape: FastNoiseLite = _noise(37, 0.025)
	for y: int in SIZE.y:
		for x: int in SIZE.x:
			var point := Vector2(x, y)
			var edge: float = 14.0 * shape.get_noise_2d(x, y)
			if ((point - LAKE_CENTER) / Vector2(1.45, 1.0)).length() < 38.0 + edge \
					or point.distance_to(Vector2(206, 94)) < 20.0 + edge * 0.7 \
					or point.distance_to(Vector2(138, 166)) < 16.0 + edge * 0.6:
				_water(Vector2i(x, y))


func _beaches() -> void:
	for water: Vector2i in big_water:
		var reach: int = 3 if water.x < 60 else 2
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
	docks[id] = {"name": npc_name, "place": place, "cell": ferryman, "facing": axis, "gate": gate + axis}


## Blackreed Isle: dense forest, ruins, crossing trails, and a pier facing Reedmere.
func _island() -> void:
	var shape: FastNoiseLite = _noise(41, 0.12)
	var center := Vector2i(ISLAND_CENTER)
	var reach: int = ceili(ISLAND_RADIUS * 1.25) + 5
	for y: int in range(center.y - reach, center.y + reach + 1):
		for x: int in range(center.x - reach, center.x + reach + 1):
			var distance: float = ((Vector2(x, y) - ISLAND_CENTER) / Vector2(1.25, 1.0)).length()
			if distance < ISLAND_RADIUS + 3.5 * shape.get_noise_2d(x, y):
				var inner: bool = distance < ISLAND_RADIUS - 2.5
				big_water.erase(Vector2i(x, y))
				put(Vector2i(x, y), ("T" if rng.randf() < 0.4 else ".") if inner else ":")
	for ruin: Vector2i in [center + Vector2i(-9, -7), center + Vector2i(6, 4)]:
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
	docks["blackreed_isle"] = {"name": "Old Marra", "place": "Blackreed Isle", "cell": ferryman, "facing": Vector2i.RIGHT}
	var cells: Array = _flood(center, _blocked()).keys()
	cells.sort()
	var placed: int = 0
	while placed < ISLAND_MONSTERS.size():
		var cell: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		if at(cell) in [".", ","] and Vector2(cell).distance_to(Vector2(ferryman)) > 8.0:
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
	var legs: Array = [
		[Vector2i(11, 18), docks["cinder_landing"]["gate"]],
		[docks["cinder_landing"]["gate"], docks["mossford"]["gate"]],
		[docks["mossford"]["gate"], docks["saltmere"]["gate"]],
		[docks["saltmere"]["gate"], docks["wrenhollow"]["gate"]],
		[Vector2i(24, 8), docks["reedmere"]["gate"]],
		[docks["saltmere"]["gate"], docks["reedmere"]["gate"]],
	]
	for leg: Array in legs:
		for cell: Vector2i in astar.get_id_path(leg[0], leg[1]):
			if at(cell) in [".", "T", ":"]:
				put(cell, ",")
				astar.set_point_weight_scale(cell, weights[","])


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
	while placed < 30:
		var cell: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		if (cell.x < 30 and cell.y < 24) or at(cell) not in [".", ","]:
			continue
		var near_town: bool = false
		for id: String in docks:
			near_town = near_town or Vector2(cell).distance_to(Vector2(docks[id]["cell"])) < 22.0
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
	return clampi(5 + floori((distance - STARTER_RADIUS - 12.0) / LEVEL_TILES), 5, 35)


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
	while placed < MAINLAND_SPAWNS and attempts < 40000:
		attempts += 1
		var cell: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		var starter: bool = Vector2(cell).distance_to(Vector2(12, 9)) <= STARTER_RADIUS
		if at(cell) not in [".", ","] or near_roads.has(cell) or (cell.x < 30 and cell.y < 24):
			continue
		if starter == (starters >= STARTER_SPAWNS):
			continue
		var clear: bool = true
		for id: String in docks:
			clear = clear and Vector2(cell).distance_to(Vector2(docks[id]["cell"])) > 22.0
		for other: Vector2i in taken:
			clear = clear and Vector2(cell).distance_to(Vector2(other)) > (8.0 if starter else 12.0)
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
	var root := Node2D.new()
	root.name = "Overworld"
	var layer := TileMapLayer.new()
	layer.name = "Terrain"
	layer.tile_set = tileset
	_add(root, layer)
	for y: int in SIZE.y:
		for x: int in SIZE.x:
			layer.set_cell(Vector2i(x, y), 0, Vector2i(TERRAINS.find(at(Vector2i(x, y))), 0))
	var spawns: Node2D = _add(root, _named(Node2D.new(), "Spawns"))
	for index: int in SPAWNS.size():
		var marker: Marker2D = _named(Marker2D.new(), "Spawn%d" % (index + 1))
		marker.position = _centre(SPAWNS[index])
		_add(spawns, marker, root)
	var ferrymen: Node2D = _add(root, _named(Node2D.new(), "Ferrymen"))
	for id: String in ROUTES:
		var dock: Dictionary = docks[id]
		var marker: Marker2D = _named(Marker2D.new(), id)
		marker.set_script(FERRYMAN_SCRIPT)
		marker.position = _centre(dock["cell"])
		marker.set("npc_name", dock["name"])
		marker.set("place", dock["place"])
		marker.set("facing", dock["facing"])
		var fares: Dictionary[String, int] = {}
		for destination: String in ROUTES[id]:
			var distance: float = Vector2(dock["cell"]).distance_to(Vector2(docks[destination]["cell"]))
			fares[destination] = ISLAND_FARE if "blackreed_isle" in [id, destination] \
				else 10 + 5 * roundi(distance / 30.0)
		marker.set("routes", fares)
		_add(ferrymen, marker, root)
	var item_root: Node2D = _add(root, _named(Node2D.new(), "Items"))
	for index: int in items.size():
		var marker: Marker2D = _named(Marker2D.new(), "%s%d" % [String(items[index][1]).to_pascal_case(), index + 1])
		marker.set_script(ITEM_SCRIPT)
		marker.position = _centre(items[index][0])
		marker.set("item", items[index][1])
		_add(item_root, marker, root)
	var zones: Node2D = _add(root, _named(Node2D.new(), "Zones"))
	var zone: Node2D = _named(Node2D.new(), "BlackreedIsle")
	zone.set_script(ZONE_SCRIPT)
	var half := Vector2i(ceili(ISLAND_RADIUS * 1.25) + 5, ceili(ISLAND_RADIUS) + 5)
	zone.position = Vector2((Vector2i(ISLAND_CENTER) - half) * TILE)
	zone.set("size_tiles", half * 2 + Vector2i.ONE)
	for key: String in ["min_level", "max_level", "pvp"]:
		zone.set(key, ISLAND_ZONE[key])
	zone.set("zone_name", ISLAND_ZONE["name"])
	_add(zones, zone, root)
	var monster_root: Node2D = _add(root, _named(Node2D.new(), "MonsterSpawns"))
	for index: int in monster_spawns.size():
		var marker: Marker2D = _named(Marker2D.new(), "%s%d" % [String(monster_spawns[index][1]).to_pascal_case(), index + 1])
		marker.set_script(MONSTER_SCRIPT)
		marker.position = _centre(monster_spawns[index][0])
		marker.set("monster", monster_spawns[index][1])
		marker.set("level", monster_spawns[index][2])
		marker.set("count", monster_spawns[index][3] if monster_spawns[index].size() > 3
			else (3 if monster_spawns[index][2] < 50 else 1))
		_add(monster_root, marker, root)
	var packed := PackedScene.new()
	packed.pack(root)
	var error: Error = ResourceSaver.save(packed, SCENE_PATH)
	print("Saved %s (%s)" % [SCENE_PATH, error_string(error)])
	root.free()


func _named(node: Node, node_name: String) -> Node:
	node.name = node_name
	return node


func _add(parent: Node, child: Node, owner: Node = null) -> Node:
	parent.add_child(child)
	child.owner = owner if owner != null else parent
	return child


func _centre(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE
