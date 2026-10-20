extends SceneTree
## Moves the caves that game/data/caves.gd marks "below" from the band to the floor below
## (docs/plan/45-floors-follow-up.md): every cell of the cave's band rect and every marker in it
## (its camps) shifts to Caves.rect, so the stairs up lie right under the cave's mouth. The scene
## remembers each cave it moved (metadata cave_below_<id>), so running again changes nothing; a
## cave newly marked "below" moves on the next run. Saves inside a moved cave follow it
## (CharacterStore). Then make world-map.
##
##   godot --headless --path . --script res://tools/generators/caves_below.gd

const MapIO = preload("res://game/maps/map_io.gd")
const Caves = preload("res://game/data/caves.gd")
const TILE: int = 32


func _initialize() -> void:
	var scene_root: Node = MapIO.load_scene()
	var moved: Vector2i = apply(scene_root)
	var error: Error = OK
	if moved != Vector2i.ZERO:
		error = MapIO.save_scene(scene_root)
	print("Moved caves below: %d cells and %d markers (%s)" % [moved.x, moved.y, error_string(error)])
	MapIO.free_scene(scene_root)
	quit(0 if error == OK else 1)


static func apply(scene_root: Node) -> Vector2i:
	var layer: TileMapLayer = scene_root.get_node(MapIO.TERRAIN)
	var cells: int = 0
	var markers: int = 0
	for cave: String in Caves.ORDER:
		if not Caves.CAVES[cave].has("below") or scene_root.has_meta("cave_below_" + cave):
			continue
		var from: Rect2i = Caves.band_rect(cave)
		var offset: Vector2i = Caves.rect(cave).position - from.position
		var saved: Array = []
		for y: int in range(from.position.y, from.end.y):
			for x: int in range(from.position.x, from.end.x):
				var cell := Vector2i(x, y)
				if layer.get_cell_source_id(cell) < 0:
					continue
				saved.append([cell, layer.get_cell_source_id(cell), layer.get_cell_atlas_coords(cell), layer.get_cell_alternative_tile(cell)])
				layer.erase_cell(cell)
		for entry: Array in saved:
			layer.set_cell(entry[0] + offset, entry[1], entry[2], entry[3])
		cells += saved.size()
		for group: Node in scene_root.get_children():
			if group == layer:
				continue
			for marker: Node in group.get_children():
				if marker is Node2D and from.has_point(Vector2i(((marker as Node2D).position / TILE).floor())):
					(marker as Node2D).position += Vector2(offset * TILE)
					markers += 1
		scene_root.set_meta("cave_below_" + cave, true)
	return Vector2i(cells, markers)
