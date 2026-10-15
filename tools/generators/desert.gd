extends SceneTree
## Paints the Dunmere desert (game/data/biomes.gd) into the existing overworld scene: inside
## the sand-dominated area, leafy trees become desert plants (cacti and thorn scrub, terrain
## "K") or open sand, and leftover grass (monster-camp clearings) becomes sand. Cells outside
## the desert, roads, walls, water, and every marker are left alone, so map edits are kept.
##
##   godot --headless --path . --script res://tools/generators/desert.gd
##
## tools/generators/make_map.gd applies the same painter to a freshly generated map. Running
## it again changes nothing.

const Biomes = preload("res://game/data/biomes.gd")
## Must match World.TERRAINS (the rules check verifies it). World itself is not loaded here
## because its static map loading needs the scene this tool is editing.
const TERRAINS: String = ".,~#T:=bdoODcCv^KRLWmU"
const SCENE_PATH: String = "res://game/maps/overworld.tscn"
## A cell is desert when at least this share of the 7x7 cells around it is sand or plants.
const SAND_SHARE: float = 0.5
## Of the former trees, about this many in 100 become plants; the rest open into sand.
const PLANTS_PER_HUNDRED: int = 55


func _initialize() -> void:
	var scene_root: Node = (load(SCENE_PATH) as PackedScene).instantiate()
	var changed: int = apply(scene_root)
	var packed := PackedScene.new()
	packed.pack(scene_root)
	var error: Error = ResourceSaver.save(packed, SCENE_PATH)
	print("Painted the desert into %s: %d cells (%s)" % [SCENE_PATH, changed, error_string(error)])
	scene_root.free()
	quit(0 if error == OK else 1)


## Repaints the desert in an overworld scene root; returns the number of changed cells.
static func apply(scene_root: Node) -> int:
	var layer: TileMapLayer = scene_root.get_node("Terrain")
	var source: TileSetAtlasSource = layer.tile_set.get_source(0)
	for index: int in TERRAINS.length():
		if not source.has_tile(Vector2i(index, 0)):
			source.create_tile(Vector2i(index, 0))
			source.get_tile_data(Vector2i(index, 0), 0).set_custom_data("terrain", TERRAINS[index])
	ResourceSaver.save(layer.tile_set, layer.tile_set.resource_path)
	var area: Rect2i = Biomes.DESERT_AREA
	var grid: Dictionary = {}
	for y: int in range(area.position.y - 3, area.end.y + 3):
		for x: int in range(area.position.x - 3, area.end.x + 3):
			grid[Vector2i(x, y)] = _terrain(layer, Vector2i(x, y))
	# Converted grass raises its neighbours' sand share, so repeat until the desert is stable;
	# a second run of the tool then changes nothing.
	var changed: int = 0
	for pass_index: int in 64:
		var changes: Dictionary = {}
		for y: int in range(area.position.y, area.end.y):
			for x: int in range(area.position.x, area.end.x):
				var cell := Vector2i(x, y)
				var tile: String = grid[cell]
				if (tile != "T" and tile != ".") or Biomes.desert_distance(cell) > 1.25 or _sand_share(grid, cell) < SAND_SHARE:
					continue
				changes[cell] = ":" if tile == "." or _hash(cell) % 100 >= PLANTS_PER_HUNDRED else "K"
		if changes.is_empty():
			break
		for cell: Vector2i in changes:
			grid[cell] = changes[cell]
			layer.set_cell(cell, 0, Vector2i(TERRAINS.find(changes[cell]), 0))
		changed += changes.size()
	return changed


static func _terrain(layer: TileMapLayer, cell: Vector2i) -> String:
	var coords: Vector2i = layer.get_cell_atlas_coords(cell)
	return TERRAINS[coords.x] if coords.x >= 0 and coords.x < TERRAINS.length() else ""


static func _sand_share(grid: Dictionary, cell: Vector2i) -> float:
	var sand: int = 0
	var total: int = 0
	for dy: int in range(-3, 4):
		for dx: int in range(-3, 4):
			var tile: String = grid.get(cell + Vector2i(dx, dy), "")
			if tile.is_empty():
				continue
			total += 1
			if tile == ":" or tile == "K":
				sand += 1
	return float(sand) / maxf(1.0, total)


static func _hash(cell: Vector2i) -> int:
	return absi((cell.x * 73856093) ^ (cell.y * 19349663) ^ 0x5f3759df)
