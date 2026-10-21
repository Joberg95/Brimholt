extends "res://tools/generators/islands.gd"
## Rebuilds one region of the world plan (docs/plan/47-world-plan.md) from its spec, as often as
## you like: make region NAME=<id>. A region is an island spec in tools/generators/islands.gd
## (ISLANDS); more kinds of region join here as the plan is built.
##
## The map has two layers per sector (game/maps/map_io.gd): the generated base and the
## hand-painted override that always wins. A rebuild loads the base only, clears the region's
## rect, paints it again (coast, landscape, castle, village, roads, harbour, camps), furnishes and
## paves its towns (towns.gd, town_paths.gd, cobble_towns.gd), and saves: hand edits in the override are never touched, so
## paint in Godot freely and rebuild after changing the spec.
##
## Markers the rebuild makes carry the region's id (metadata "region") and are replaced by the
## next rebuild; markers without it are hand-placed or another pass's and stay. Cave mouths and
## dungeon stairways inside the rect keep their cell and tile (the painter keeps land and open
## ground round them), since the floors below are joined to them. The first rebuild of a region
## painted before regions existed also replaces the painter's untagged markers inside the rect.
## Afterwards run make world-map (make region does).
##
##   godot --headless --path . --script res://tools/generators/region.gd -- <id>

const Towns = preload("res://tools/generators/towns.gd")
const TownPaths = preload("res://tools/generators/town_paths.gd")
const Cobble = preload("res://tools/generators/cobble_towns.gd")
## Markers of other passes whose cells must keep their tile.
const KEPT_GROUPS: Array[String] = ["CaveMouths", "DungeonEntrances"]
## Groups the island painter fills (replaced on a region's first rebuild).
const PAINTED_GROUPS: Array[String] = ["Zones", "Ferrymen", "Townsfolk", "Decor", "MonsterSpawns"]
const REGION_META: String = "region"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var id: String = args[0] if args.size() > 0 else ""
	if not ISLANDS.has(id):
		printerr("Name a region: make region NAME=<id> (one of %s)." % ", ".join(PackedStringArray(ISLANDS.keys())))
		quit(1)
		return
	var scene_root: Node = MapIO.load_scene(true)
	var result: Dictionary = rebuild(scene_root, id)
	var error: Error = FAILED if result.is_empty() else MapIO.save_scene(scene_root)
	if not result.is_empty():
		print("Rebuilt the region %s: %d cells painted, %d markers replaced by %d (%s)" % [id, result["cells"], result["removed"],
			result["added"], error_string(error)])
	MapIO.free_scene(scene_root)
	quit(0 if error == OK else 1)


## Rebuilds the region's base in a scene from MapIO.load_scene(true): {cells, removed, added}, or
## empty (with an error) when a town cannot be furnished.
func rebuild(scene_root: Node, id: String) -> Dictionary:
	_root = scene_root
	_layer = scene_root.get_node(MapIO.TERRAIN)
	_ensure_tiles()
	var spec: Dictionary = (ISLANDS[id] as Dictionary).duplicate()
	var rect: Rect2i = spec["rect"]
	var first: bool = not scene_root.has_meta("region_" + id)
	var removed: int = 0
	# Replaced markers by group/name, freed at the end unless the rebuild makes them again unchanged.
	var old: Dictionary = {}
	var keep: Dictionary = {}
	for group: Node in scene_root.get_children():
		if group is TileMapLayer:
			continue
		for marker: Node in group.get_children():
			if not marker is Node2D:
				continue
			var cell: Vector2i = _cell_of(marker as Node2D)
			if String(group.name) in KEPT_GROUPS and rect.has_point(cell):
				keep[cell] = _tile(cell)
			elif String(marker.get_meta(REGION_META, "")) == id \
					or (first and String(group.name) in PAINTED_GROUPS and rect.has_point(cell) and not marker.has_meta(REGION_META)):
				group.remove_child(marker)
				old[String(group.name) + "/" + String(marker.name)] = marker
				removed += 1
	spec["keep"] = keep
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			_layer.erase_cell(Vector2i(x, y))
	var before: Dictionary = _marker_ids()
	var cells: int = _island(id, spec)
	if Towns.apply(scene_root) < 0:
		for marker: Node in old.values():
			marker.free()
		return {}
	cells += int(TownPaths.apply(scene_root)["painted"])
	var paving: Dictionary = Cobble.paving(_tile)
	for cell: Vector2i in paving:
		if rect.has_point(cell):
			_paint(cell, paving[cell])
			cells += 1
	# Roads and paths never cover a mouth or a stairway.
	for cell: Vector2i in keep:
		_paint(cell, keep[cell])
	var added: int = 0
	for group: Node in scene_root.get_children():
		for marker: Node in group.get_children():
			if marker is Node2D and not before.has(marker.get_instance_id()):
				marker.set_meta(REGION_META, id)
				added += 1
				# An unchanged marker keeps its old node, so a re-run leaves the scene file as it was.
				var twin: Node2D = old.get(String(group.name) + "/" + String(marker.name), null)
				if twin != null and _same_marker(twin, marker as Node2D):
					old.erase(String(group.name) + "/" + String(marker.name))
					var at: int = marker.get_index()
					group.remove_child(marker)
					marker.free()
					group.add_child(twin)
					group.move_child(twin, at)
					twin.owner = scene_root
	for marker: Node in old.values():
		marker.free()
	scene_root.set_meta("island_" + id, true)
	scene_root.set_meta("region_" + id, true)
	return {"cells": cells, "removed": removed, "added": added}


func _marker_ids() -> Dictionary:
	var ids: Dictionary = {}
	for group: Node in _root.get_children():
		for marker: Node in group.get_children():
			ids[marker.get_instance_id()] = true
	return ids


static func _same_marker(a: Node2D, b: Node2D) -> bool:
	return a.get_script() == b.get_script() and a.get_meta(REGION_META, "") == b.get_meta(REGION_META, "") \
		and str(MapIO._record(a)) == str(MapIO._record(b))


static func _cell_of(marker: Node2D) -> Vector2i:
	return Vector2i((marker.position / TILE).floor())
