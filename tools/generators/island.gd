extends SceneTree
## Thins the forest on Blackreed Isle, the central PvP island, so fights there have room to move:
## only about KEEP_PER_HUNDRED of every hundred trees inside the island's zone stay; the rest become
## grass. Which trees stay is a fixed hash of the tile, so running it again changes nothing.
##
##   godot --headless --path . --script res://tools/generators/island.gd
##
## tools/generators/make_map.gd applies the same painter to a freshly generated map.

## Must match World.TERRAINS (the rules check verifies it).
const TERRAINS: String = ".,~#T:=bdoODcCv^KRLW"
const SCENE_PATH: String = "res://game/maps/overworld.tscn"
const ZONE_NAME: String = "Blackreed Isle"
const KEEP_PER_HUNDRED: int = 25
const TILE: int = 32


func _initialize() -> void:
	var scene_root: Node = (load(SCENE_PATH) as PackedScene).instantiate()
	var changed: int = apply(scene_root)
	var packed := PackedScene.new()
	packed.pack(scene_root)
	var error: Error = ResourceSaver.save(packed, SCENE_PATH)
	print("Thinned Blackreed Isle in %s: %d trees cleared (%s)" % [SCENE_PATH, changed, error_string(error)])
	scene_root.free()
	quit(0 if error == OK and changed >= 0 else 1)


## Clears trees on the island; returns how many, or -1 if the island zone is missing.
static func apply(scene_root: Node) -> int:
	var layer: TileMapLayer = scene_root.get_node("Terrain")
	var area := Rect2i()
	for zone: Node2D in scene_root.get_node("Zones").get_children():
		if String(zone.get("zone_name")) == ZONE_NAME:
			area = Rect2i(Vector2i((zone.position / TILE).round()), zone.get("size_tiles"))
	if area.size == Vector2i.ZERO:
		push_error("No %s zone to thin" % ZONE_NAME)
		return -1
	var tree: int = TERRAINS.find("T")
	var grass: int = TERRAINS.find(".")
	var changed: int = 0
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var cell := Vector2i(x, y)
			if layer.get_cell_atlas_coords(cell).x == tree and not keeps(cell):
				layer.set_cell(cell, 0, Vector2i(grass, 0))
				changed += 1
	return changed


## Whether the tree at `cell` stays.
static func keeps(cell: Vector2i) -> bool:
	return absi((cell.x * 73856093) ^ (cell.y * 19349663) ^ 0x2545F491) % 100 < KEEP_PER_HUNDRED
