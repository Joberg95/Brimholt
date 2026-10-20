extends SceneTree
## One-time pass for the Tibia-sized overworld (Atlas.OVERWORLD_SIZE): moves everything painted
## right of the old 384-column overworld (the instanced dungeon copies, the Void Throne arena, and
## the elite caves) SHIFT columns east, into the bands past the new overworld edge. The bands keep
## their order and gaps, so one shift lands them on Dungeons.BAND_X and Caves.BAND_X. Terrain cells
## and every marker in those columns (spawns, items, gates, zones, monster spawns, cave mouths) move
## together. Nothing is left between the old edge and the new one, so running again changes
## nothing.
##
##   godot --headless --path . --script res://tools/generators/move_bands.gd

const Atlas = preload("res://game/data/atlas.gd")
const Dungeons = preload("res://game/data/dungeons.gd")
const MapIO = preload("res://game/maps/map_io.gd")
const SCENE_PATH: String = "res://game/maps/overworld.tscn"
const TILE_SIZE: int = 32
## The old overworld's width and the old first column of the dungeon band.
const OLD_EDGE: int = 384
const OLD_BAND_X: int = 388
const SHIFT: int = Dungeons.BAND_X - OLD_BAND_X
## Columns whose contents move: right of the old overworld, short of the new one's edge.
const FROM: int = OLD_EDGE
const TO: int = Atlas.OVERWORLD_SIZE.x


func _initialize() -> void:
	var scene_root: Node = MapIO.load_scene()
	var moved: Vector2i = apply(scene_root)
	var error: Error = OK
	if moved != Vector2i.ZERO:
		error = MapIO.save_scene(scene_root)
	print("Moved %d terrain cells and %d markers %d columns east in %s (%s)"
		% [moved.x, moved.y, SHIFT, SCENE_PATH, error_string(error)])
	MapIO.free_scene(scene_root)
	quit(0 if error == OK else 1)


static func _moves(cell: Vector2i) -> bool:
	return cell.x >= FROM and cell.x < TO


## Moves the cells and markers; returns (terrain cells, markers) moved.
static func apply(scene_root: Node) -> Vector2i:
	var layer: TileMapLayer = scene_root.get_node("Terrain")
	var cells: Array[Vector2i] = []
	for cell: Vector2i in layer.get_used_cells():
		if _moves(cell):
			cells.append(cell)
	# Copy first, then erase what nothing landed on: the shift is wider than the bands, so no
	# target overlaps a source, but erasing separately keeps that from mattering.
	var targets: Dictionary = {}
	for cell: Vector2i in cells:
		var target: Vector2i = cell + Vector2i(SHIFT, 0)
		layer.set_cell(target, layer.get_cell_source_id(cell), layer.get_cell_atlas_coords(cell),
			layer.get_cell_alternative_tile(cell))
		targets[target] = true
	for cell: Vector2i in cells:
		if not targets.has(cell):
			layer.erase_cell(cell)
	var markers: int = 0
	for group: Node in scene_root.get_children():
		if group == layer:
			continue
		for marker: Node in group.get_children():
			if marker is Node2D and _moves(Vector2i(((marker as Node2D).position / TILE_SIZE).floor())):
				(marker as Node2D).position += Vector2(SHIFT * TILE_SIZE, 0)
				markers += 1
	return Vector2i(cells.size(), markers)
