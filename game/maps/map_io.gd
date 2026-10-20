extends RefCounted
## The world's terrain is stored in sectors: one scene per Atlas.SECTOR-sized square that holds
## any painted cell (game/maps/sectors/<sx>_<sy>.tscn, a TileMapLayer on game/maps/terrain.tres,
## cells in world coordinates). overworld.tscn keeps the markers and instances every sector under
## its "Sectors" node, so the editor still shows one world; open a sector (right-click it, Open
## in Editor) to paint it.
##
## Generators load the map with load_scene(), which merges the sectors into one TileMapLayer named
## "Terrain" (not saved), edit that layer and the markers, and write it back with save_scene(),
## which splits the terrain into sectors again (a cell painted into the wrong sector moves to its
## own) and removes the files of sectors left empty. World reads the sectors directly (cells()).

const Atlas = preload("res://game/data/atlas.gd")

const SCENE_PATH: String = "res://game/maps/overworld.tscn"
const SECTOR_DIR: String = "res://game/maps/sectors"
const TILESET_PATH: String = "res://game/maps/terrain.tres"
const SECTORS: String = "Sectors"
const TERRAIN: String = "Terrain"


static func sector_path(sector: Vector2i) -> String:
	return "%s/%d_%d.tscn" % [SECTOR_DIR, sector.x, sector.y]


## Every terrain layer of an instantiated overworld scene: its sectors, or the single "Terrain"
## layer of a scene from before the split.
static func layers(scene_root: Node) -> Array[TileMapLayer]:
	var found: Array[TileMapLayer] = []
	if scene_root.has_node(TERRAIN) and scene_root.get_node(TERRAIN) is TileMapLayer:
		found.append(scene_root.get_node(TERRAIN))
	if scene_root.has_node(SECTORS):
		for child: Node in scene_root.get_node(SECTORS).get_children():
			if child is TileMapLayer:
				found.append(child)
	return found


## The overworld scene with its sectors merged into one "Terrain" layer, ready for a generator.
static func load_scene() -> Node:
	# Edit state, so saving compares each sector instance with its file instead of copying its tiles.
	var scene_root: Node = (ResourceLoader.load(SCENE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene).instantiate(
		PackedScene.GEN_EDIT_STATE_MAIN)
	merge(scene_root)
	return scene_root


## Replaces an instantiated scene's sectors with one merged "Terrain" layer (does nothing to a
## scene that already has one and no sectors). The sectors are kept aside for save_scene, which
## leaves the unchanged ones (and their files) exactly as they were.
static func merge(scene_root: Node) -> void:
	if not scene_root.has_node(SECTORS):
		return
	var merged: TileMapLayer
	if scene_root.has_node(TERRAIN):
		merged = scene_root.get_node(TERRAIN)
	else:
		merged = TileMapLayer.new()
		merged.name = TERRAIN
		merged.tile_set = load(TILESET_PATH)
		scene_root.add_child(merged)
	var sectors: Node = scene_root.get_node(SECTORS)
	scene_root.move_child(merged, sectors.get_index())
	for layer: Node in sectors.get_children():
		if layer is TileMapLayer:
			for cell: Vector2i in (layer as TileMapLayer).get_used_cells():
				merged.set_cell(cell, layer.get_cell_source_id(cell), layer.get_cell_atlas_coords(cell),
					layer.get_cell_alternative_tile(cell))
	sectors.owner = null
	scene_root.remove_child(sectors)
	_set_aside[scene_root.get_instance_id()] = sectors


## Sectors merge() took out, by scene root.
static var _set_aside: Dictionary = {}


## Writes a scene from load_scene() (or a freshly built one with a "Terrain" layer): the terrain
## into sector files (only the ones whose cells changed), the markers into overworld.tscn. The
## scene keeps its merged layer after.
static func save_scene(scene_root: Node, path: String = SCENE_PATH) -> Error:
	var merged: TileMapLayer = scene_root.get_node(TERRAIN)
	var buckets: Dictionary = {}
	for cell: Vector2i in merged.get_used_cells():
		var cells: Array = buckets.get_or_add(Atlas.sector_of(cell), [])
		cells.append(cell)
	DirAccess.make_dir_recursive_absolute(SECTOR_DIR)
	var sectors: Node = _set_aside.get(scene_root.get_instance_id(), null)
	if sectors == null:
		sectors = Node2D.new()
		sectors.name = SECTORS
		_set_aside[scene_root.get_instance_id()] = sectors
	var keys: Array = buckets.keys()
	keys.sort()
	for sector: Vector2i in keys:
		var layer := TileMapLayer.new()
		layer.name = "Sector_%d_%d" % [sector.x, sector.y]
		layer.tile_set = merged.tile_set
		for cell: Vector2i in buckets[sector]:
			layer.set_cell(cell, merged.get_cell_source_id(cell), merged.get_cell_atlas_coords(cell),
				merged.get_cell_alternative_tile(cell))
		var old: TileMapLayer = sectors.get_node_or_null(NodePath(layer.name)) as TileMapLayer
		if old != null and _same_cells(old, layer):
			layer.free()
			continue
		var packed_sector := PackedScene.new()
		packed_sector.pack(layer)
		layer.free()
		var error: Error = ResourceSaver.save(packed_sector, sector_path(sector))
		if error != OK:
			return error
		var instance: Node = (ResourceLoader.load(sector_path(sector), "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene).instantiate(
			PackedScene.GEN_EDIT_STATE_INSTANCE)
		if old != null:
			sectors.remove_child(old)
			old.free()
		sectors.add_child(instance)
	for child: Node in sectors.get_children():
		var parts: PackedStringArray = String(child.name).split("_")
		if parts.size() != 3 or not buckets.has(Vector2i(int(parts[1]), int(parts[2]))):
			sectors.remove_child(child)
			child.free()
	for file: String in DirAccess.get_files_at(SECTOR_DIR):
		var parts: PackedStringArray = file.get_basename().split("_")
		if file.get_extension() == "tscn" and parts.size() == 2 and not buckets.has(Vector2i(int(parts[0]), int(parts[1]))):
			DirAccess.remove_absolute(SECTOR_DIR.path_join(file))
	# Sectors in order, so the scene file lists them the same way every time.
	var order: Array = sectors.get_children()
	order.sort_custom(func(a: Node, b: Node) -> bool: return String(a.name).naturalnocasecmp_to(String(b.name)) < 0)
	for at: int in order.size():
		sectors.move_child(order[at], at)
	var index: int = merged.get_index()
	merged.owner = null
	scene_root.remove_child(merged)
	scene_root.add_child(sectors)
	scene_root.move_child(sectors, index)
	sectors.owner = scene_root
	for instance: Node in sectors.get_children():
		instance.owner = scene_root
	var packed := PackedScene.new()
	var result: Error = packed.pack(scene_root)
	if result == OK:
		result = ResourceSaver.save(packed, path)
	sectors.owner = null
	scene_root.remove_child(sectors)
	scene_root.add_child(merged)
	scene_root.move_child(merged, index)
	return result


## Frees a scene from load_scene() and the sectors merge() set aside for it.
static func free_scene(scene_root: Node) -> void:
	var sectors: Node = _set_aside.get(scene_root.get_instance_id(), null)
	_set_aside.erase(scene_root.get_instance_id())
	if sectors != null and sectors.get_parent() == null:
		sectors.free()
	scene_root.free()


static func _same_cells(a: TileMapLayer, b: TileMapLayer) -> bool:
	var cells: Array[Vector2i] = a.get_used_cells()
	if cells.size() != b.get_used_cells().size():
		return false
	for cell: Vector2i in cells:
		if a.get_cell_source_id(cell) != b.get_cell_source_id(cell) or a.get_cell_atlas_coords(cell) != b.get_cell_atlas_coords(cell) 				or a.get_cell_alternative_tile(cell) != b.get_cell_alternative_tile(cell):
			return false
	return true
