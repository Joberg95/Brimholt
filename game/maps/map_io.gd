extends RefCounted
## The world's terrain is stored in sectors: one scene per Atlas.SECTOR-sized square that holds
## any painted cell (game/maps/sectors/<sx>_<sy>.tscn, a TileMapLayer on game/maps/terrain.tres,
## cells in world coordinates). overworld.tscn keeps the markers and instances every sector under
## its "Sectors" node, so the editor still shows one world; open a sector (right-click it, Open
## in Editor) to paint it.
##
## Each sector has two layers. Its child "Base" (locked, drawn behind) holds what generators
## paint; the sector root holds hand edits, the override, which always wins over the base. Paint in
## the root and a region rebuild (make region NAME=<id>) never wipes the work.
##
## Generators load the map with load_scene(), which merges the sectors into one TileMapLayer named
## "Terrain" (not saved; overrides over base, or the base alone with base_only), edit that layer
## and the markers, and write it back with save_scene(): the cells the generator changed go into
## the base, overrides stay as they were, cells painted into the wrong sector move to their own,
## and the files of sectors left empty are removed.
##
## The game itself reads a bake (read_map): the terrain as one byte per cell and every marker as a
## plain record {name, cell, and the marker's own properties}, written to BAKE_PATH by
## write_bake() (make bake-map, and every save_scene). Loading it takes a fraction of instancing
## the scene. A bake older than the scene (painted in Godot since) is not used: the map is read
## from the scene with a warning, and the rules check asks for make bake-map. Exported builds,
## whose scenes Godot converts, always use the bake.

const Atlas = preload("res://game/data/atlas.gd")

const SCENE_PATH: String = "res://game/maps/overworld.tscn"
const SECTOR_DIR: String = "res://game/maps/sectors"
const TILESET_PATH: String = "res://game/maps/terrain.tres"
const SECTORS: String = "Sectors"
const TERRAIN: String = "Terrain"
## A sector's generated layer, the child drawn under its root (the hand-painted override).
const BASE: String = "Base"
## No tile (a cell missing from a layer), for comparing cells.
const NONE: Vector4i = Vector4i(-1, -1, -1, -1)
const BAKE_PATH: String = "res://game/maps/world.bake"
const BAKE_VERSION: int = 2
## Marker groups the bake keeps, as World reads them.
const MARKER_GROUPS: Array[String] = ["Spawns", "Items", "Ferrymen", "QuestGivers", "Townsfolk", "Zones", "DungeonEntrances",
	"CaveMouths", "MonsterSpawns", "Decor"]
## Character of unpainted overworld cells (deep sea) and of unpainted cells beyond it (void).
const SEA: int = 126
const VOID: int = 32


## The map as plain data: {grid: PackedByteArray (one terrain character per cell, row-major),
## size, painted (the painted part of the overworld), floors: {z: the painted part of each floor
## other than the surface (Atlas.FLOOR_X)}, markers: {group: [records]}}, from the bake
## when it is current, else from the scene.
static func read_map() -> Dictionary:
	if FileAccess.file_exists(BAKE_PATH):
		var file: FileAccess = FileAccess.open_compressed(BAKE_PATH, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
		var baked: Variant = file.get_var() if file != null else null
		if typeof(baked) == TYPE_DICTIONARY and int(baked.get("version", 0)) == BAKE_VERSION \
				and (OS.has_feature("template") or String(baked.get("fingerprint", "")) == fingerprint()):
			return baked
		push_warning("The baked map is older than the map; run make bake-map. Reading the scene instead.")
	var scene_root: Node = (load(SCENE_PATH) as PackedScene).instantiate()
	var data: Dictionary = extract(scene_root)
	scene_root.free()
	return data


## Whether the bake matches the map scene, its sectors, and the tile set.
static func bake_current() -> bool:
	if not FileAccess.file_exists(BAKE_PATH):
		return false
	var file: FileAccess = FileAccess.open_compressed(BAKE_PATH, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	var data: Variant = file.get_var() if file != null else null
	return typeof(data) == TYPE_DICTIONARY and String(data.get("fingerprint", "")) == fingerprint()


## The sources' fingerprint: a hash of overworld.tscn, terrain.tres, and every sector scene.
static func fingerprint() -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	var files: Array[String] = [SCENE_PATH, TILESET_PATH]
	var files_in: PackedStringArray = DirAccess.get_files_at(SECTOR_DIR)
	files_in.sort()
	for file: String in files_in:
		if file.get_extension() == "tscn":
			files.append(SECTOR_DIR.path_join(file))
	for path: String in files:
		hashing.update(FileAccess.get_file_as_bytes(path))
	return hashing.finish().hex_encode()


## Writes the bake from the scene on disk.
static func write_bake() -> Error:
	var scene_root: Node = (ResourceLoader.load(SCENE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP) as PackedScene).instantiate()
	var data: Dictionary = extract(scene_root)
	scene_root.free()
	data["version"] = BAKE_VERSION
	data["fingerprint"] = fingerprint()
	var file: FileAccess = FileAccess.open_compressed(BAKE_PATH, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return FileAccess.get_open_error()
	file.store_var(data)
	file.close()
	return OK


## The map data of an instantiated overworld scene (see read_map).
static func extract(scene_root: Node) -> Dictionary:
	var found: Array[TileMapLayer] = layers(scene_root)
	var tile_set: TileSet = found[0].tile_set
	var lookup: Dictionary = {}
	for index: int in tile_set.get_source_count():
		var source_id: int = tile_set.get_source_id(index)
		var source: TileSetAtlasSource = tile_set.get_source(source_id) as TileSetAtlasSource
		if source == null:
			continue
		for tile: int in source.get_tiles_count():
			var coords: Vector2i = source.get_tile_id(tile)
			var kind: Variant = source.get_tile_data(coords, 0).get_custom_data("terrain")
			if typeof(kind) == TYPE_STRING and String(kind).length() == 1:
				lookup[Vector3i(source_id, coords.x, coords.y)] = String(kind).unicode_at(0)
	var size: Vector2i = Atlas.OVERWORLD_SIZE
	for layer: TileMapLayer in found:
		size = size.max(layer.get_used_rect().end)
	var sea_row := PackedByteArray()
	sea_row.resize(size.x)
	sea_row.fill(VOID)
	for x: int in Atlas.OVERWORLD_SIZE.x:
		sea_row[x] = SEA
	var void_row := PackedByteArray()
	void_row.resize(size.x)
	void_row.fill(VOID)
	var grid := PackedByteArray()
	for y: int in size.y:
		grid.append_array(sea_row if y < Atlas.OVERWORLD_SIZE.y else void_row)
	var painted := Rect2i()
	var floors: Dictionary = {}
	for layer: TileMapLayer in found:
		for cell: Vector2i in layer.get_used_cells():
			if cell.x < 0 or cell.y < 0:
				continue
			var coords: Vector2i = layer.get_cell_atlas_coords(cell)
			var code: int = lookup.get(Vector3i(layer.get_cell_source_id(cell), coords.x, coords.y), VOID)
			grid[cell.y * size.x + cell.x] = code
			if cell.x < Atlas.OVERWORLD_SIZE.x and cell.y < Atlas.OVERWORLD_SIZE.y:
				painted = Rect2i(cell, Vector2i.ONE) if painted.size == Vector2i.ZERO else painted.expand(cell)
			elif code != VOID:
				var z: int = Atlas.floor_of(cell)
				if z != Atlas.NO_FLOOR:
					# Rect2i.expand reaches the cell's corner, so each floor grows by one at the end.
					floors[z] = Rect2i(cell, Vector2i.ONE) if not floors.has(z) else (floors[z] as Rect2i).expand(cell)
	for z: int in floors:
		floors[z] = Rect2i(floors[z].position, floors[z].size + Vector2i.ONE)
	var markers: Dictionary = {}
	for group: String in MARKER_GROUPS:
		var records: Array = []
		if scene_root.has_node(group):
			for marker: Node in scene_root.get_node(group).get_children():
				if marker is Node2D:
					records.append(_record(marker as Node2D))
		markers[group] = records
	return {"grid": grid, "size": size, "painted": Rect2i(painted.position, painted.size + Vector2i.ONE), "floors": floors,
		"markers": markers}


## A marker as a plain record: its name, its cell, and its script's exported properties.
static func _record(marker: Node2D) -> Dictionary:
	var record: Dictionary = {"name": String(marker.name), "cell": Vector2i((marker.position / 32.0).floor())}
	for property: Dictionary in marker.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = marker.get(property["name"])
			record[String(property["name"])] = Dictionary(value) if value is Dictionary else value
	return record


static func sector_path(sector: Vector2i) -> String:
	return "%s/%d_%d.tscn" % [SECTOR_DIR, sector.x, sector.y]


## Every terrain layer of an instantiated overworld scene in the order they cover each other: the
## single "Terrain" layer of a scene from before the split, then each sector's base and its
## override on top (a sector from before the layers is one base layer).
static func layers(scene_root: Node) -> Array[TileMapLayer]:
	var found: Array[TileMapLayer] = []
	if scene_root.has_node(TERRAIN) and scene_root.get_node(TERRAIN) is TileMapLayer:
		found.append(scene_root.get_node(TERRAIN))
	for sector: TileMapLayer in sectors(scene_root):
		var base: TileMapLayer = sector.get_node_or_null(BASE) as TileMapLayer
		if base != null:
			found.append(base)
		found.append(sector)
	return found


## The sector scenes instanced in an overworld scene (their roots: the override layers).
static func sectors(scene_root: Node) -> Array[TileMapLayer]:
	var found: Array[TileMapLayer] = []
	if scene_root.has_node(SECTORS):
		for child: Node in scene_root.get_node(SECTORS).get_children():
			if child is TileMapLayer:
				found.append(child)
	return found


## A sector's generated layer (its Base child), or the sector itself before the layers.
static func base_of(sector: TileMapLayer) -> TileMapLayer:
	var base: TileMapLayer = sector.get_node_or_null(BASE) as TileMapLayer
	return sector if base == null else base


## A sector's hand layer (the root), or null for a sector from before the layers.
static func override_of(sector: TileMapLayer) -> TileMapLayer:
	return sector if sector.has_node(BASE) else null


## The overworld scene with its sectors merged into one "Terrain" layer, ready for a generator:
## the map as it shows (each override over its base), or only the generated base with
## base_only (a region rebuilding its base, tools/generators/region.gd). Either way save_scene
## writes the generator's changes into the base; overrides(scene_root) holds the hand layer.
static func load_scene(base_only: bool = false) -> Node:
	# Edit state, so saving compares each sector instance with its file instead of copying its tiles.
	var scene_root: Node = (ResourceLoader.load(SCENE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene).instantiate(
		PackedScene.GEN_EDIT_STATE_MAIN)
	merge(scene_root, base_only)
	return scene_root


## Replaces an instantiated scene's sectors with one merged "Terrain" layer (does nothing to a
## scene that already has one and no sectors). The sectors are kept aside for save_scene, which
## leaves the unchanged ones (and their files) exactly as they were.
static func merge(scene_root: Node, base_only: bool = false) -> void:
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
	var hand := TileMapLayer.new()
	hand.tile_set = merged.tile_set
	var found: Array[TileMapLayer] = sectors(scene_root)
	for sector: TileMapLayer in found:
		_copy(base_of(sector), merged)
		var override: TileMapLayer = override_of(sector)
		if override != null:
			_copy(override, hand)
	if not base_only:
		_copy(hand, merged)
	var holder: Node = scene_root.get_node(SECTORS)
	scene_root.move_child(merged, holder.get_index())
	holder.owner = null
	scene_root.remove_child(holder)
	_set_aside[scene_root.get_instance_id()] = {"sectors": holder, "overrides": hand, "base_only": base_only}


## The hand layer of a scene from load_scene: every override cell, editable (save_scene writes it).
static func overrides(scene_root: Node) -> TileMapLayer:
	var aside: Dictionary = _set_aside.get(scene_root.get_instance_id(), {})
	return aside.get("overrides", null)


## Sectors and overrides merge() took out, by scene root.
static var _set_aside: Dictionary = {}


## Writes a scene from load_scene() (or a freshly built one with a "Terrain" layer): every cell
## the generator changed in the merged layer into its sector's base, the hand layer into the
## overrides (both into sector files, only the ones whose cells changed), and the markers into
## overworld.tscn. The scene keeps its merged layer after.
static func save_scene(scene_root: Node, path: String = SCENE_PATH) -> Error:
	var merged: TileMapLayer = scene_root.get_node(TERRAIN)
	var aside: Dictionary = _set_aside.get(scene_root.get_instance_id(), {})
	var holder: Node = aside.get("sectors", null)
	var hand: TileMapLayer = aside.get("overrides", null)
	if holder == null:
		holder = Node2D.new()
		holder.name = SECTORS
	# The base as it was, and what the generator saw: the base, or the overrides over it.
	var base: Dictionary = {}
	var old_hand: Dictionary = {}
	for sector: TileMapLayer in holder.get_children().filter(func(node: Node) -> bool: return node is TileMapLayer):
		_read(base_of(sector), base)
		var override: TileMapLayer = override_of(sector)
		if override != null:
			_read(override, old_hand)
	var seen: Dictionary = base.duplicate()
	if not bool(aside.get("base_only", false)):
		seen.merge(old_hand, true)
	var now: Dictionary = {}
	_read(merged, now)
	for cell: Vector2i in seen:
		if not now.has(cell):
			base.erase(cell)
	for cell: Vector2i in now:
		if seen.get(cell, NONE) != now[cell]:
			base[cell] = now[cell]
	var hand_cells: Dictionary = {}
	if hand != null:
		_read(hand, hand_cells)
	var buckets: Dictionary = {}
	for cell: Vector2i in base:
		(buckets.get_or_add(Atlas.sector_of(cell), [{}, {}]) as Array)[0][cell] = base[cell]
	for cell: Vector2i in hand_cells:
		(buckets.get_or_add(Atlas.sector_of(cell), [{}, {}]) as Array)[1][cell] = hand_cells[cell]
	DirAccess.make_dir_recursive_absolute(SECTOR_DIR)
	var keys: Array = buckets.keys()
	keys.sort()
	for sector: Vector2i in keys:
		var layer := TileMapLayer.new()
		layer.name = "Sector_%d_%d" % [sector.x, sector.y]
		layer.tile_set = merged.tile_set
		var base_layer := TileMapLayer.new()
		base_layer.name = BASE
		base_layer.tile_set = merged.tile_set
		# Drawn under the hand layer and locked, so painting a sector in Godot paints the override.
		base_layer.show_behind_parent = true
		base_layer.set_meta("_edit_lock_", true)
		layer.add_child(base_layer)
		base_layer.owner = layer
		_write(buckets[sector][0], base_layer)
		_write(buckets[sector][1], layer)
		var old: TileMapLayer = holder.get_node_or_null(NodePath(layer.name)) as TileMapLayer
		if old != null and override_of(old) != null and _same_cells(base_of(old), base_layer) and _same_cells(old, layer):
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
			holder.remove_child(old)
			old.free()
		holder.add_child(instance)
	for child: Node in holder.get_children():
		var parts: PackedStringArray = String(child.name).split("_")
		if parts.size() != 3 or not buckets.has(Vector2i(int(parts[1]), int(parts[2]))):
			holder.remove_child(child)
			child.free()
	for file: String in DirAccess.get_files_at(SECTOR_DIR):
		var parts: PackedStringArray = file.get_basename().split("_")
		if file.get_extension() == "tscn" and parts.size() == 2 and not buckets.has(Vector2i(int(parts[0]), int(parts[1]))):
			DirAccess.remove_absolute(SECTOR_DIR.path_join(file))
	# Sectors in order, so the scene file lists them the same way every time.
	var order: Array = holder.get_children()
	order.sort_custom(func(a: Node, b: Node) -> bool: return String(a.name).naturalnocasecmp_to(String(b.name)) < 0)
	for at: int in order.size():
		holder.move_child(order[at], at)
	# What the generator sees from now on is the map as saved.
	aside = {"sectors": holder, "overrides": hand, "base_only": bool(aside.get("base_only", false))}
	_set_aside[scene_root.get_instance_id()] = aside
	var index: int = merged.get_index()
	merged.owner = null
	scene_root.remove_child(merged)
	scene_root.add_child(holder)
	scene_root.move_child(holder, index)
	holder.owner = scene_root
	for instance: Node in holder.get_children():
		instance.owner = scene_root
	var packed := PackedScene.new()
	var result: Error = packed.pack(scene_root)
	if result == OK:
		result = ResourceSaver.save(packed, path)
	holder.owner = null
	scene_root.remove_child(holder)
	scene_root.add_child(merged)
	scene_root.move_child(merged, index)
	if result == OK and path == SCENE_PATH:
		result = write_bake()
	return result


## Frees a scene from load_scene() and the sectors merge() set aside for it.
static func free_scene(scene_root: Node) -> void:
	var aside: Dictionary = _set_aside.get(scene_root.get_instance_id(), {})
	_set_aside.erase(scene_root.get_instance_id())
	var holder: Node = aside.get("sectors", null)
	if holder != null and holder.get_parent() == null:
		holder.free()
	var hand: Node = aside.get("overrides", null)
	if hand != null:
		hand.free()
	scene_root.free()


static func _same_cells(a: TileMapLayer, b: TileMapLayer) -> bool:
	var first: Dictionary = {}
	var second: Dictionary = {}
	_read(a, first)
	_read(b, second)
	return first == second


## A layer's cells into cells: {cell: Vector4i(source, atlas x, atlas y, alternative)}.
static func _read(layer: TileMapLayer, cells: Dictionary) -> void:
	for cell: Vector2i in layer.get_used_cells():
		var coords: Vector2i = layer.get_cell_atlas_coords(cell)
		cells[cell] = Vector4i(layer.get_cell_source_id(cell), coords.x, coords.y, layer.get_cell_alternative_tile(cell))


static func _write(cells: Dictionary, layer: TileMapLayer) -> void:
	for cell: Vector2i in cells:
		var tile: Vector4i = cells[cell]
		layer.set_cell(cell, tile.x, Vector2i(tile.y, tile.z), tile.w)


static func _copy(from: TileMapLayer, to: TileMapLayer) -> void:
	for cell: Vector2i in from.get_used_cells():
		to.set_cell(cell, from.get_cell_source_id(cell), from.get_cell_atlas_coords(cell), from.get_cell_alternative_tile(cell))
