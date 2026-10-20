extends SceneTree
## Opens the way to Silkhollow's cave mouth in the Thornfield Wilds: clears a glade of trees around
## the stairway and cuts a dirt trail west through the forest to the coast road, so the dungeon
## can be found and reached on foot. Only trees and grass are repainted; rocks, water, walls, and
## markers are left alone, so running it again changes nothing.
##
##   godot --headless --path . --script res://tools/generators/silkhollow.gd

## Must match World.TERRAINS (the rules check verifies it).
const TERRAINS: String = ".,~#T:=bdoODcCv^KRLWmUsPFY"
const MapIO = preload("res://game/maps/map_io.gd")
const SCENE_PATH: String = "res://game/maps/overworld.tscn"
const DUNGEON: String = "silkhollow"
## Trees within this many tiles of the stairway are cleared; up to GLADE_EDGE every other one.
const GLADE: int = 4
const GLADE_EDGE: int = 6
## The trail leaves the glade this many rows below the stairway and runs west to the road.
const TRAIL_ROW: int = 2
const TILE: int = 32


func _initialize() -> void:
	var scene_root: Node = MapIO.load_scene()
	var changed: int = apply(scene_root)
	var error: Error = MapIO.save_scene(scene_root)
	print("Opened the way to Silkhollow in %s: %d tiles repainted (%s)" % [SCENE_PATH, changed, error_string(error)])
	MapIO.free_scene(scene_root)
	quit(0 if error == OK and changed >= 0 else 1)


## Repaints the glade and trail; returns how many tiles changed, or -1 without the entrance.
static func apply(scene_root: Node) -> int:
	var layer: TileMapLayer = scene_root.get_node("Terrain")
	var mouth := Vector2i(-1, -1)
	for marker: Node2D in scene_root.get_node("DungeonEntrances").get_children():
		if String(marker.get("dungeon")) == DUNGEON:
			mouth = Vector2i((marker.position / TILE).floor())
	if mouth.x < 0:
		push_error("No %s entrance" % DUNGEON)
		return -1
	var tree: int = TERRAINS.find("T")
	var grass: int = TERRAINS.find(".")
	var dirt: int = TERRAINS.find(",")
	var road: int = TERRAINS.find("=")
	var changed: int = 0
	# The glade: no trees near the mouth, a thinned ring around it.
	for y: int in range(-GLADE_EDGE, GLADE_EDGE + 1):
		for x: int in range(-GLADE_EDGE, GLADE_EDGE + 1):
			var cell: Vector2i = mouth + Vector2i(x, y)
			var ring: int = maxi(absi(x), absi(y))
			if layer.get_cell_atlas_coords(cell).x == tree and (ring <= GLADE or (cell.x + cell.y) % 2 == 0):
				layer.set_cell(cell, 0, Vector2i(grass, 0))
				changed += 1
	# The trail: two tiles of dirt with a cleared shoulder either side, gently winding west
	# until it meets the road.
	var x: int = mouth.x - 1
	while x > 0:
		var row: int = mouth.y + TRAIL_ROW + roundi(sin(float(x) / 7.0))
		if layer.get_cell_atlas_coords(Vector2i(x, row)).x == road:
			break
		for dy: int in range(-1, 3):
			var cell := Vector2i(x, row + dy)
			var code: int = layer.get_cell_atlas_coords(cell).x
			var target: int = dirt if dy == 0 or dy == 1 else grass
			if (code == tree or code == grass) and code != target:
				layer.set_cell(cell, 0, Vector2i(target, 0))
				changed += 1
		x -= 1
	return changed
