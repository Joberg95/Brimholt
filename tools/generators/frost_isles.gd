extends "res://tools/generators/landscape.gd"
## Paints the frost isles (Biomes.ISLES) into free grid space south of the mainland: the open sea
## round them (and along the mainland's south coast), three snowbound isles with fir woods and
## crags joined by plank bridges, and Hrimvik, a palisaded port town of long blockhouses for the
## wealthy in the north and fishers' and furriers' huts in a quarter to the south, its harbour pier
## and boat on the east side. It adds the town zone, the vendor (towns.gd then seats the keepers
## and adds the artisan), the boat with routes to the mainland ports (and theirs back), and the
## tundra camps. The isles are reached only by boat.
##
## Terrain is repainted the same way every run, and markers that exist are kept, so running
## again changes nothing. Afterwards run towns.gd, town_paths.gd, and the world map bake.
##
##   godot --headless --path . --script res://tools/generators/frost_isles.gd

const Biomes = preload("res://game/data/biomes.gd")
const ZONE_SCRIPT: Script = preload("res://game/maps/markers/zone.gd")
const FERRY_SCRIPT: Script = preload("res://game/maps/markers/ferryman.gd")
const TOWNSFOLK_SCRIPT: Script = preload("res://game/maps/markers/townsfolk.gd")
const SPAWN_SCRIPT: Script = preload("res://game/maps/markers/monster_spawn.gd")
const TOWN_NAME: String = "Hrimvik"
## Open sea painted round the isles and below the mainland (beyond them the grid stays unpainted).
const SEA: Array[Rect2i] = [Rect2i(0, 640, 640, Biomes.ISLES_SEA), Rect2i(0, 704, 200, 136)]
## Isles: centre, radii, and noise salt; a tile is land when its scaled distance (ragged by noise)
## is under one.
const ISLANDS: Array = [
	[Vector2(58, 762), Vector2(46, 36), 101],
	[Vector2(138, 750), Vector2(15, 17), 102],
	[Vector2(112, 812), Vector2(30, 11), 103],
]
## Plank bridges: corners of an L-shaped walk two tiles wide, painted over water only.
const BRIDGES: Array = [
	[Vector2i(94, 780), Vector2i(132, 780), Vector2i(132, 762)],
	[Vector2i(80, 792), Vector2i(80, 806), Vector2i(94, 806)],
]
## The town, its harbour water, and the pier with the boat at its end. Walls never stand one
## tile apart (Buildings would read the gap as a doorway): two tiles or more, or shared.
const TOWN: Rect2i = Rect2i(60, 732, 46, 36)
const HARBOUR: Rect2i = Rect2i(108, 724, 16, 52)
const PIER: Rect2i = Rect2i(106, 748, 12, 2)
const BOAT: Vector2i = Vector2i(117, 748)
## [walls rect (relative to TOWN), door (relative)]: wealthy longhouses and the shop to the
## north, the bank, the artisan's hall, and a longhouse round the square, and the huts of the
## fishers and furriers in the south quarter.
const HOUSES: Array = [
	[Rect2i(3, 3, 11, 6), Vector2i(8, 8)], [Rect2i(16, 3, 11, 6), Vector2i(21, 8)], [Rect2i(29, 3, 8, 6), Vector2i(32, 8)],
	[Rect2i(3, 11, 8, 5), Vector2i(6, 11)], [Rect2i(26, 11, 7, 5), Vector2i(29, 11)], [Rect2i(35, 11, 8, 5), Vector2i(38, 11)],
	[Rect2i(3, 18, 6, 5), Vector2i(5, 18)], [Rect2i(11, 18, 6, 5), Vector2i(13, 18)],
	[Rect2i(26, 18, 6, 5), Vector2i(28, 18)], [Rect2i(34, 18, 6, 5), Vector2i(36, 18)],
	[Rect2i(3, 25, 6, 5), Vector2i(5, 25)], [Rect2i(11, 25, 6, 5), Vector2i(13, 25)],
	[Rect2i(26, 25, 6, 5), Vector2i(28, 25)], [Rect2i(34, 25, 6, 5), Vector2i(36, 25)],
]
## Streets and the square (relative to TOWN), and the gates through the palisade.
const STREETS: Array[Rect2i] = [Rect2i(1, 9, 44, 2), Rect2i(13, 11, 9, 5), Rect2i(1, 16, 44, 2), Rect2i(22, 9, 2, 26),
	Rect2i(1, 23, 44, 2)]
const GATES: Array[Vector2i] = [Vector2i(0, 16), Vector2i(0, 17), Vector2i(45, 16), Vector2i(45, 17), Vector2i(22, 35),
	Vector2i(23, 35)]
## The boat's routes (Ferrymen node -> fare) and the mainland ports' routes back.
const ROUTES: Dictionary = {"lastlight": 45, "cinder_landing": 60}
## Tundra camps: [monster, level, count, wander radius, cell].
const CAMPS: Array = [
	["frost_ghost", 28, 5, 3, Vector2i(30, 750)], ["frost_ghost", 29, 5, 3, Vector2i(22, 772)],
	["frost_ghost", 30, 5, 3, Vector2i(44, 786)], ["rust_grub", 30, 5, 2, Vector2i(132, 742)],
	["rust_grub", 32, 5, 2, Vector2i(142, 758)], ["rust_grub", 31, 5, 2, Vector2i(30, 792)],
	["brigand", 31, 5, 2, Vector2i(18, 754)], ["brigand", 33, 5, 2, Vector2i(52, 770)],
	["brigand", 34, 5, 2, Vector2i(136, 748)],
]


func _initialize() -> void:
	var scene_root: Node = MapIO.load_scene()
	_prepare(scene_root)
	var changed: int = _paint_isles()
	changed += _paint_town()
	changed += _place_markers(scene_root)
	var error: Error = MapIO.save_scene(scene_root)
	print("Painted the frost isles and %s into %s: %d tiles and markers (%s)" % [TOWN_NAME, SCENE_PATH, changed, error_string(error)])
	MapIO.free_scene(scene_root)
	quit(0 if error == OK else 1)


func _paint_isles() -> int:
	var painted: int = 0
	for area: Rect2i in SEA:
		for y: int in range(area.position.y, area.end.y):
			for x: int in range(area.position.x, area.end.x):
				_paint(Vector2i(x, y), "~")
				painted += 1
	var area: Rect2i = Biomes.ISLES
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var cell := Vector2i(x, y)
			if not _land(cell):
				continue
			var tile: String = "s"
			var wood: float = _noise(cell, 7.0, 91)
			if wood > 0.6 and _land_round(cell, 2):
				tile = "P"
			elif _noise(cell, 9.0, 92) > 0.8 and _land_round(cell, 3) and cell.x < 60:
				tile = "L"
			_paint(cell, tile)
	for bridge: Array in BRIDGES:
		for leg: int in bridge.size() - 1:
			var from: Vector2i = bridge[leg]
			var to: Vector2i = bridge[leg + 1]
			var step := Vector2i(signi(to.x - from.x), signi(to.y - from.y))
			var at: Vector2i = from
			while true:
				for extra: Vector2i in [Vector2i.ZERO, Vector2i(absi(step.y), absi(step.x))]:
					if _tile(at + extra) == "~":
						_paint(at + extra, "b")
				if at == to:
					break
				at += step
	return painted


## The nearest tile to `cell` with open snow all round within `radius`, clear of the town.
func _open_spot(cell: Vector2i, radius: int) -> Vector2i:
	for reach: int in 12:
		for dy: int in range(-reach, reach + 1):
			for dx: int in range(-reach, reach + 1):
				var at: Vector2i = cell + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) != reach or TOWN.grow(4).has_point(at):
					continue
				var open: bool = true
				for oy: int in range(-radius, radius + 1):
					for ox: int in range(-radius, radius + 1):
						open = open and _tile(at + Vector2i(ox, oy)) == "s"
				if open:
					return at
	return cell


## Whether a tile of the isles is land.
func _land(cell: Vector2i) -> bool:
	for island: Array in ISLANDS:
		var offset: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5) - island[0]) / island[1]
		if offset.length() < 0.82 + 0.36 * _noise(cell, 6.0, island[2]):
			return true
	return TOWN.grow(3).has_point(cell)


## Land all round within `radius` (woods and crags keep off the shore).
func _land_round(cell: Vector2i, radius: int) -> bool:
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			if not _land(cell + Vector2i(dx, dy)):
				return false
	return true


func _paint_town() -> int:
	var painted: int = 0
	for y: int in range(HARBOUR.position.y, HARBOUR.end.y):
		for x: int in range(HARBOUR.position.x, HARBOUR.end.x):
			_paint(Vector2i(x, y), "~")
	for y: int in range(TOWN.position.y - 1, TOWN.end.y + 1):
		for x: int in range(TOWN.position.x - 1, TOWN.end.x + 2):
			_paint(Vector2i(x, y), "s")
	for y: int in TOWN.size.y:
		for x: int in TOWN.size.x:
			if x == 0 or y == 0 or x == TOWN.size.x - 1 or y == TOWN.size.y - 1:
				_paint(TOWN.position + Vector2i(x, y), "#")
				painted += 1
	for street: Rect2i in STREETS:
		for y: int in range(street.position.y, street.end.y):
			for x: int in range(street.position.x, street.end.x):
				_paint(TOWN.position + Vector2i(x, y), "=")
	for gate: Vector2i in GATES:
		_paint(TOWN.position + gate, "=")
	for house: Array in HOUSES:
		var walls: Rect2i = house[0]
		for y: int in range(walls.position.y, walls.end.y):
			for x: int in range(walls.position.x, walls.end.x):
				var edge: bool = x == walls.position.x or y == walls.position.y or x == walls.end.x - 1 or y == walls.end.y - 1
				_paint(TOWN.position + Vector2i(x, y), "#" if edge else "=")
		_paint(TOWN.position + house[1], "=")
		painted += 1
	for y: int in range(PIER.position.y, PIER.end.y):
		for x: int in range(PIER.position.x, PIER.end.x):
			_paint(Vector2i(x, y), "b")
	return painted


func _place_markers(scene_root: Node) -> int:
	var changed: int = 0
	var zones: Node = scene_root.get_node("Zones")
	var zone: Node2D = zones.get_node_or_null(TOWN_NAME)
	if zone == null:
		zone = Node2D.new()
		zone.name = TOWN_NAME
		zone.set_script(ZONE_SCRIPT)
		zones.add_child(zone)
		zone.owner = scene_root
		changed += 1
	zone.position = Vector2(TOWN.position * TILE)
	zone.set("zone_name", TOWN_NAME)
	zone.set("size_tiles", TOWN.size)
	zone.set("town", true)
	var ferrymen: Node = scene_root.get_node("Ferrymen")
	var boat: Node2D = ferrymen.get_node_or_null("hrimvik")
	if boat == null:
		boat = Marker2D.new()
		boat.name = "hrimvik"
		boat.set_script(FERRY_SCRIPT)
		ferrymen.add_child(boat)
		boat.owner = scene_root
		changed += 1
	boat.position = (Vector2(BOAT) + Vector2(0.5, 0.5)) * TILE
	boat.set("npc_name", "Captain Torgrim")
	boat.set("place", TOWN_NAME)
	boat.set("facing", Vector2i.LEFT)
	boat.set("vehicle", "ferry")
	var routes: Dictionary[String, int] = {}
	for port: String in ROUTES:
		routes[port] = ROUTES[port]
		var other: Node = ferrymen.get_node(port)
		var back: Dictionary[String, int] = other.get("routes")
		if back.get("hrimvik", -1) != ROUTES[port]:
			back["hrimvik"] = ROUTES[port]
			other.set("routes", back)
			changed += 1
	boat.set("routes", routes)
	var townsfolk: Node = scene_root.get_node("Townsfolk")
	if not townsfolk.has_node("hrimvik_vendor"):
		var vendor := Marker2D.new()
		vendor.name = "hrimvik_vendor"
		vendor.set_script(TOWNSFOLK_SCRIPT)
		townsfolk.add_child(vendor)
		vendor.owner = scene_root
		vendor.position = (Vector2(TOWN.get_center()) + Vector2(0.5, 0.5)) * TILE
		vendor.set("npc_name", "Furrier Solvei")
		vendor.set("place", TOWN_NAME)
		vendor.set("role", "vendor")
		changed += 1
	var spawns: Node = scene_root.get_node("MonsterSpawns")
	for index: int in CAMPS.size():
		var camp: Array = CAMPS[index]
		var name: String = "Isles_%s_%d" % [camp[0], index + 1]
		var marker: Node2D = spawns.get_node_or_null(name)
		if marker == null:
			marker = Marker2D.new()
			marker.name = name
			marker.set_script(SPAWN_SCRIPT)
			spawns.add_child(marker)
			marker.owner = scene_root
			marker.position = (Vector2(_open_spot(camp[4], camp[3])) + Vector2(0.5, 0.5)) * TILE
			changed += 1
		# An existing camp keeps its place but follows the table.
		marker.set("monster", camp[0])
		marker.set("level", camp[1])
		marker.set("count", camp[2])
		marker.set("radius", camp[3])
	return changed
