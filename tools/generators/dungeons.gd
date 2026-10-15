extends SceneTree
## Paints every copy of every instanced dungeon (game/data/dungeons.gd) into the band right of
## the overworld, and the stairway down at each entrance (a DungeonEntrances marker).
##
##   godot --headless --path . --script res://tools/generators/dungeons.gd
##
## Standalone it repaints the copies of the existing game/maps/overworld.tscn and keeps its
## entrance markers (move them in the editor to move a stairway). tools/generators/make_map.gd
## calls apply() with the default entrances for a freshly generated map. After changing a
## layout, run this and the rules check.

## Must match World.TERRAINS (the rules check verifies it); World itself is not loaded here
## because its static map loading needs the scene this tool is editing.
const TERRAINS: String = ".,~#T:=bdoODcCv^KRLW"
const TILE_SIZE: int = 32
const Dungeons = preload("res://game/data/dungeons.gd")
const ENTRANCE_SCRIPT: Script = preload("res://game/maps/markers/dungeon_entrance.gd")
const SCENE_PATH: String = "res://game/maps/overworld.tscn"


func _initialize() -> void:
	var scene_root: Node = (load(SCENE_PATH) as PackedScene).instantiate()
	var entrances: Dictionary = {}
	if scene_root.has_node("DungeonEntrances"):
		for marker: Node2D in scene_root.get_node("DungeonEntrances").get_children():
			entrances[String(marker.get("dungeon"))] = Vector2i((marker.position / TILE_SIZE).floor())
	for id: String in Dungeons.DUNGEONS:
		if not entrances.has(id) and Dungeons.DUNGEONS[id].has("entrance"):
			entrances[id] = Dungeons.DUNGEONS[id]["entrance"]
	if entrances.size() != Dungeons.DUNGEONS.size():
		printerr("Every dungeon needs a DungeonEntrances marker (found %s)." % entrances.keys())
		scene_root.free()
		quit(1)
		return
	apply(scene_root, entrances)
	var packed := PackedScene.new()
	packed.pack(scene_root)
	var error: Error = ResourceSaver.save(packed, SCENE_PATH)
	print("Painted %d dungeons into %s (%s)" % [Dungeons.DUNGEONS.size(), SCENE_PATH, error_string(error)])
	scene_root.free()
	quit(0 if error == OK else 1)


## Paints the copies and stairways; entrances maps dungeon id -> overworld cell.
static func apply(scene_root: Node, entrances: Dictionary) -> void:
	var layer: TileMapLayer = scene_root.get_node("Terrain")
	var source: TileSetAtlasSource = layer.tile_set.get_source(0)
	for index: int in TERRAINS.length():
		if not source.has_tile(Vector2i(index, 0)):
			source.create_tile(Vector2i(index, 0))
			source.get_tile_data(Vector2i(index, 0), 0).set_custom_data("terrain", TERRAINS[index])
	ResourceSaver.save(layer.tile_set, layer.tile_set.resource_path)
	for id: String in Dungeons.DUNGEONS:
		var size: Vector2i = Dungeons.size(id)
		for copy: int in Dungeons.DUNGEONS[id]["copies"]:
			var origin: Vector2i = Dungeons.origin(id, copy)
			for y: int in size.y:
				for x: int in size.x:
					var terrain: String = Dungeons.terrain(id, Vector2i(x, y))
					layer.set_cell(origin + Vector2i(x, y), 0, Vector2i(TERRAINS.find(terrain), 0))
	var index: int = -1
	if scene_root.has_node("DungeonEntrances"):
		var old: Node = scene_root.get_node("DungeonEntrances")
		index = old.get_index()
		scene_root.remove_child(old)
		old.free()
	var markers := Node2D.new()
	markers.name = "DungeonEntrances"
	scene_root.add_child(markers)
	markers.owner = scene_root
	if index >= 0:
		scene_root.move_child(markers, index)
	for id: String in entrances:
		var cell: Vector2i = entrances[id]
		layer.set_cell(cell, 0, Vector2i(TERRAINS.find("v"), 0))
		var marker := Marker2D.new()
		marker.name = String(id).to_pascal_case()
		marker.set_script(ENTRANCE_SCRIPT)
		marker.position = (Vector2(cell) + Vector2(0.5, 0.5)) * TILE_SIZE
		marker.set("dungeon", id)
		markers.add_child(marker)
		marker.owner = scene_root
