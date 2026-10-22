extends SceneTree
## The Hollow Reach: the endgame zone in the south-east, a high-risk level 45-50 PvP zone
## (dying drops everything but bound relics) of blighted
## dusk soil and dead trees inside an obsidian wall, with the Hollow Sanctum at its east end.
## A corridor of halls leads to the throne room where Vaelith, Sovereign of the Hollow, sits.
##
##   godot --headless --path . --script res://tools/generators/endgame_zone.gd
##
## Paints the zone into the existing game/maps/overworld.tscn (keeping every other edit),
## replaces the monster spawns inside it, and adds the zone and its spawns. Re-running repaints
## the same layout. tools/generators/make_map.gd calls apply() for a freshly generated map.

const World = preload("res://game/core/world.gd")
const ZONE_SCRIPT: Script = preload("res://game/maps/markers/zone.gd")
const MONSTER_SCRIPT: Script = preload("res://game/maps/markers/monster_spawn.gd")
const MapIO = preload("res://game/maps/map_io.gd")
const SCENE_PATH: String = "res://game/maps/overworld.tscn"
const ZONE_NAME: String = "The Hollow Reach"
## Perpetual violet gloom: the zone's light multiplies the time of day.
const AMBIENT: Color = Color(0.58, 0.48, 0.78)
## Zone rectangle (tiles), including its outer wall, in the south-east corner of the map.
const ORIGIN: Vector2i = Vector2i(318, 312)
const AREA: Rect2i = Rect2i(ORIGIN, Vector2i(58, 64))
const GATE_Y: int = ORIGIN.y + 32
## The Hollow Sanctum: outer box, then three rooms along the corridor row GATE_Y.
const SANCTUM: Rect2i = Rect2i(ORIGIN + Vector2i(24, 8), Vector2i(34, 49))
const ANTECHAMBER: Rect2i = Rect2i(ORIGIN + Vector2i(25, 9), Vector2i(11, 47))
const GALLERY: Rect2i = Rect2i(ORIGIN + Vector2i(37, 18), Vector2i(7, 29))
const THRONE: Rect2i = Rect2i(ORIGIN + Vector2i(45, 20), Vector2i(12, 25))
const THRONE_SEAT: Vector2i = ORIGIN + Vector2i(53, 32)
## Spawns: monster, level, count, radius, cell.
const SPAWNS: Array = [
	["void_mage", 45, 3, 3, ORIGIN + Vector2i(8, 10)],
	["void_mage", 46, 3, 3, ORIGIN + Vector2i(9, 54)],
	["obsidian_golem", 46, 2, 2, ORIGIN + Vector2i(16, 22)],
	["obsidian_golem", 47, 2, 2, ORIGIN + Vector2i(16, 43)],
	["void_mage", 47, 3, 2, ORIGIN + Vector2i(21, 13)],
	["skeleton_warrior", 47, 2, 2, ORIGIN + Vector2i(21, 52)],
	["skeleton_warrior", 48, 2, 2, ORIGIN + Vector2i(30, 18)],
	["skeleton_warrior", 48, 2, 2, ORIGIN + Vector2i(30, 46)],
	["obsidian_golem", 49, 2, 1, ORIGIN + Vector2i(40, 26)],
	["obsidian_golem", 49, 2, 1, ORIGIN + Vector2i(40, 38)],
	# Vaelith sits on the Void Throne past the gateway stone in the throne room (void_throne.gd).
]


func _initialize() -> void:
	var scene_root: Node = MapIO.load_scene()
	apply(scene_root)
	var error: Error = MapIO.save_scene(scene_root)
	print("Painted %s into %s (%s)" % [ZONE_NAME, SCENE_PATH, error_string(error)])
	MapIO.free_scene(scene_root)
	quit(0 if error == OK else 1)


static func layout() -> Dictionary:
	var cells: Dictionary = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 4545
	for y: int in range(AREA.position.y, AREA.end.y):
		for x: int in range(AREA.position.x, AREA.end.x):
			var edge: bool = x == AREA.position.x or y == AREA.position.y or x == AREA.end.x - 1 or y == AREA.end.y - 1
			cells[Vector2i(x, y)] = "O" if edge else ("D" if rng.randf() < 0.09 else "d")
	# Gate in the west wall, an obsidian road to the Sanctum, and clearings around spawns.
	for y: int in range(GATE_Y - 2, GATE_Y + 3):
		cells[Vector2i(AREA.position.x, y)] = "d"
	for x: int in range(AREA.position.x, SANCTUM.position.x):
		for y: int in range(GATE_Y - 1, GATE_Y + 2):
			cells[Vector2i(x, y)] = "o"
	for spawn: Array in SPAWNS:
		for dy: int in range(-2, 3):
			for dx: int in range(-2, 3):
				var cell: Vector2i = spawn[4] + Vector2i(dx, dy)
				if cells.get(cell, "") == "D":
					cells[cell] = "d"
	# The Sanctum: obsidian walls, then floors carved for each room and the doorways.
	for y: int in range(SANCTUM.position.y, SANCTUM.end.y):
		for x: int in range(SANCTUM.position.x, SANCTUM.end.x):
			cells[Vector2i(x, y)] = "O"
	for room: Rect2i in [ANTECHAMBER, GALLERY, THRONE]:
		for y: int in range(room.position.y, room.end.y):
			for x: int in range(room.position.x, room.end.x):
				cells[Vector2i(x, y)] = "o"
	for x: int in [SANCTUM.position.x, ANTECHAMBER.end.x, GALLERY.end.x]:
		for y: int in range(GATE_Y - 1, GATE_Y + 2):
			cells[Vector2i(x, y)] = "o"
	# Pillars in the antechamber and the gallery, clear of the corridor row.
	for y: int in range(ANTECHAMBER.position.y + 4, ANTECHAMBER.end.y - 2, 6):
		for x: int in [ANTECHAMBER.position.x + 2, ANTECHAMBER.end.x - 3]:
			if absi(y - GATE_Y) > 2:
				cells[Vector2i(x, y)] = "O"
	for y: int in range(GALLERY.position.y + 3, GALLERY.end.y - 2, 5):
		if absi(y - GATE_Y) > 2:
			cells[Vector2i(GALLERY.position.x + 1, y)] = "O"
			cells[Vector2i(GALLERY.end.x - 2, y)] = "O"
	# A dais of pillars framing the throne.
	for offset: Vector2i in [Vector2i(-2, -3), Vector2i(2, -3), Vector2i(-2, 3), Vector2i(2, 3)]:
		cells[THRONE_SEAT + offset] = "O"
	return cells


## Paints the zone into an overworld scene root (TileMapLayer "Terrain" plus marker nodes).
static func apply(scene_root: Node) -> void:
	var layer: TileMapLayer = scene_root.get_node("Terrain")
	var source: TileSetAtlasSource = layer.tile_set.get_source(0)
	for index: int in World.TERRAINS.length():
		if not source.has_tile(Vector2i(index, 0)):
			source.create_tile(Vector2i(index, 0))
			source.get_tile_data(Vector2i(index, 0), 0).set_custom_data("terrain", World.TERRAINS[index])
	ResourceSaver.save(layer.tile_set, layer.tile_set.resource_path)
	var cells: Dictionary = layout()
	for cell: Vector2i in cells:
		layer.set_cell(cell, 0, Vector2i(World.TERRAINS.find(cells[cell]), 0))
	# An approach clearing outside the gate, so the forest path reaches it.
	for y: int in range(GATE_Y - 4, GATE_Y + 5):
		for x: int in range(AREA.position.x - 8, AREA.position.x):
			var coords: Vector2i = layer.get_cell_atlas_coords(Vector2i(x, y))
			if coords.x >= 0 and World.TERRAINS[coords.x] in World.TREES:
				layer.set_cell(Vector2i(x, y), 0, Vector2i(World.TERRAINS.find("."), 0))
	var spawns: Node = scene_root.get_node("MonsterSpawns")
	for marker: Node in spawns.get_children():
		if AREA.has_point(Vector2i((marker as Node2D).position / World.TILE_SIZE)):
			spawns.remove_child(marker)
			marker.free()
	for index: int in SPAWNS.size():
		var spawn: Array = SPAWNS[index]
		var marker := Marker2D.new()
		marker.name = "Hollow%s%d" % [String(spawn[0]).to_pascal_case(), index + 1]
		marker.set_script(MONSTER_SCRIPT)
		marker.position = (Vector2(spawn[4]) + Vector2(0.5, 0.5)) * World.TILE_SIZE
		marker.set("monster", spawn[0])
		marker.set("level", spawn[1])
		marker.set("count", spawn[2])
		marker.set("radius", spawn[3])
		spawns.add_child(marker)
		marker.owner = scene_root
	var zones: Node = scene_root.get_node("Zones")
	if zones.has_node("HollowReach"):
		var old: Node = zones.get_node("HollowReach")
		zones.remove_child(old)
		old.free()
	var zone := Node2D.new()
	zone.name = "HollowReach"
	zone.set_script(ZONE_SCRIPT)
	zone.position = Vector2(AREA.position) * World.TILE_SIZE
	zone.set("zone_name", ZONE_NAME)
	zone.set("size_tiles", AREA.size)
	zone.set("pvp", true)
	zone.set("full_loot", true)
	zone.set("ambient", AMBIENT)
	zone.set("min_level", 45)
	zone.set("max_level", 50)
	zones.add_child(zone)
	zone.owner = scene_root
