extends SceneTree
## Paves every town inside its walls, as Tibia's cities are: the grass, sand, dirt, snow, and trees
## of a town zone become cobblestone (snowy cobbles on the frost isles), and the shore beside a
## town's piers becomes a plank quay. Walls, buildings, water, piers, and waystones stay. Running
## again changes nothing.
##
##   godot --headless --path . --script res://tools/generators/cobble_towns.gd

const World = preload("res://game/core/world.gd")
const MapIO = preload("res://game/maps/map_io.gd")
const SCENE_PATH: String = "res://game/maps/overworld.tscn"
## Ground a town paves over, and how near a pier the shore becomes a quay instead.
const PAVED: String = ".,:msTKU"
const QUAY_REACH: int = 8
const SIDES: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


func _initialize() -> void:
	var scene_root: Node = MapIO.load_scene()
	var layer: TileMapLayer = scene_root.get_node("Terrain")
	var changes: Dictionary = paving()
	for cell: Vector2i in changes:
		layer.set_cell(cell, 0, Vector2i(World.TERRAINS.find(changes[cell]), 0))
	var error: Error = OK
	if not changes.is_empty():
		error = MapIO.save_scene(scene_root)
	var quay: int = changes.values().count("b")
	print("Paved %d town tiles with cobbles and %d with quay planks in %s (%s)" % [changes.size() - quay, quay, SCENE_PATH,
		error_string(error)])
	MapIO.free_scene(scene_root)
	quit(0 if error == OK else 1)


## {cell: new terrain} for every town tile still unpaved, read from the baked map or from
## terrain_of (cell -> terrain letter; a region rebuild reads its scene).
static func paving(terrain_of: Callable = Callable()) -> Dictionary:
	var terrain: Callable = terrain_of if terrain_of.is_valid() else func(cell: Vector2i) -> String: return World.terrain(cell)
	var changes: Dictionary = {}
	for zone: Dictionary in World.ZONES:
		if not zone["town"]:
			continue
		var rect: Rect2i = zone["rect"]
		var piers: Array[Vector2i] = []
		for y: int in range(rect.position.y, rect.end.y):
			for x: int in range(rect.position.x, rect.end.x):
				if terrain.call(Vector2i(x, y)) == "b":
					piers.append(Vector2i(x, y))
		for y: int in range(rect.position.y, rect.end.y):
			for x: int in range(rect.position.x, rect.end.x):
				var cell := Vector2i(x, y)
				var tile: String = terrain.call(cell)
				if tile.is_empty() or not tile in PAVED:
					continue
				changes[cell] = "b" if _quay(cell, piers, terrain) else "="
	return changes


## Whether a cell lies in a town zone (the ground this paves).
static func in_town(cell: Vector2i) -> bool:
	return World.zone_at(cell).get("town", false)


## Whether a town tile is shore beside water within QUAY_REACH of one of the town's piers.
static func _quay(cell: Vector2i, piers: Array[Vector2i], terrain: Callable) -> bool:
	if not SIDES.any(func(side: Vector2i) -> bool: return terrain.call(cell + side) == "~"):
		return false
	return piers.any(func(pier: Vector2i) -> bool: return World.chebyshev(pier, cell) <= QUAY_REACH)
