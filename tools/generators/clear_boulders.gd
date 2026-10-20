extends "res://tools/generators/landscape.gd"
## Clears the overworld's boulders ("R"): every one becomes the open ground most common around it
## (grass, sand, dirt, dusk soil), so walking never snags on a lone stone. Mountains ("L") and rock
## outcrops ("C") stay. Running again changes nothing.
##
##   godot --headless --path . --script res://tools/generators/clear_boulders.gd

const GROUND: String = ".,:d"


func _initialize() -> void:
	var scene_root: Node = MapIO.load_scene()
	var changed: int = clear(scene_root)
	var error: Error = OK
	if changed > 0:
		error = MapIO.save_scene(scene_root)
	print("Cleared %d boulders from %s (%s)" % [changed, SCENE_PATH, error_string(error)])
	MapIO.free_scene(scene_root)
	quit(0 if error == OK else 1)


## Turns every overworld boulder into its neighbours' ground; returns how many it changed.
static func clear(scene_root: Node) -> int:
	var layer: TileMapLayer = scene_root.get_node("Terrain")
	var boulder: int = TERRAINS.find("R")
	var changed: int = 0
	for cell: Vector2i in layer.get_used_cells():
		if not WORLD.has_point(cell) or layer.get_cell_atlas_coords(cell).x != boulder:
			continue
		var counts: Dictionary = {}
		for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
				Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var index: int = layer.get_cell_atlas_coords(cell + side).x
			if index >= 0 and index < TERRAINS.length() and TERRAINS[index] in GROUND:
				counts[TERRAINS[index]] = counts.get(TERRAINS[index], 0) + 1
		var ground: String = "."
		for tile: String in counts:
			if counts[tile] > counts.get(ground, 0):
				ground = tile
		layer.set_cell(cell, 0, Vector2i(TERRAINS.find(ground), 0))
		changed += 1
	return changed
