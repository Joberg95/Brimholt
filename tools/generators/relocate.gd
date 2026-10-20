extends SceneTree
## One-time pass for the doubled mainland (docs/plan/43): moves the frost isles RELOCATE rows south
## and Silverwood columns east, out of the way of the mainland growing to 640 x 640. Every terrain
## cell and marker (spawns, ferrymen, quest givers, townsfolk, zones, camps, cave mouths, dungeon
## entrances, decor) inside each area moves together. The scene remembers it ran (metadata
## relocated), so running again changes nothing. Saves from before are moved by CharacterStore
## (save version 4).
##
##   godot --headless --path . --script res://tools/generators/relocate.gd

const MapIO = preload("res://game/maps/map_io.gd")
const TILE: int = 32
## [area before, offset].
const RELOCATE: Array = [
	[Rect2i(0, 424, 160, 128), Vector2i(0, 280)],
	[Rect2i(500, 60, 240, 220), Vector2i(260, 0)],
]


func _initialize() -> void:
	var scene_root: Node = MapIO.load_scene()
	var moved: Vector2i = apply(scene_root)
	var error: Error = OK
	if moved != Vector2i.ZERO:
		error = MapIO.save_scene(scene_root)
	print("Relocated %d terrain cells and %d markers (%s)" % [moved.x, moved.y, error_string(error)])
	MapIO.free_scene(scene_root)
	quit(0 if error == OK else 1)


static func apply(scene_root: Node) -> Vector2i:
	if scene_root.has_meta("relocated"):
		return Vector2i.ZERO
	var layer: TileMapLayer = scene_root.get_node(MapIO.TERRAIN)
	var cells: int = 0
	var markers: int = 0
	for move: Array in RELOCATE:
		var area: Rect2i = move[0]
		var offset: Vector2i = move[1]
		var inside: Array[Vector2i] = []
		for cell: Vector2i in layer.get_used_cells():
			if area.has_point(cell):
				inside.append(cell)
		var saved: Array = []
		for cell: Vector2i in inside:
			saved.append([cell, layer.get_cell_source_id(cell), layer.get_cell_atlas_coords(cell), layer.get_cell_alternative_tile(cell)])
			layer.erase_cell(cell)
		for entry: Array in saved:
			layer.set_cell(entry[0] + offset, entry[1], entry[2], entry[3])
		cells += saved.size()
		for group: Node in scene_root.get_children():
			if group == layer:
				continue
			for marker: Node in group.get_children():
				if marker is Node2D and area.has_point(Vector2i(((marker as Node2D).position / TILE).floor())):
					(marker as Node2D).position += Vector2(offset * TILE)
					markers += 1
	scene_root.set_meta("relocated", true)
	return Vector2i(cells, markers)
