extends "res://tools/generators/landscape.gd"
## Places the Hunters' Lodge hunting grounds (game/data/quests.gd "hunters_lodge") and the level-50
## elite grounds (Monsters "ashmaw_drake" and kin: mythic gear farms) in the existing overworld scene: monster spawn markers for each new prey, in the region whose level band suits
## it, on open meadow that can be walked to from the player spawns, clear of zones and of every
## other camp. Markers are named "Hunt_<monster>_<n>"; a camp that already exists is kept, so
## running again changes nothing. Move them in Godot like any other spawn.
##
##   godot --headless --path . --script res://tools/generators/hunts.gd

const SPAWN_SCRIPT: Script = preload("res://game/maps/markers/monster_spawn.gd")
## [monster, region, lowest level, highest level, camps, monsters per camp, wander radius,
## optional tiles kept from roads (elites, so travellers are not caught)].
const HUNTS: Array = [
	["frostfang_wolf", "Outlaw Ridge", 19, 21, 5, 4, 3],
	["greymaw", "Golemback Hills", 24, 24, 1, 1, 2],
	["cyclops", "Smoulder Fells", 29, 31, 5, 3, 3],
	["cyclops_smith", "Hollow March", 36, 38, 5, 3, 3],
	["behemoth", "Gloamwood", 43, 45, 5, 2, 3],
	["ashmaw_drake", "Emberwaste", 48, 50, 4, 2, 3, 7],
	["rime_titan", "Hollow March", 48, 50, 4, 2, 3, 7],
	["barrow_lich", "Mirewood Fen", 48, 50, 4, 2, 3, 7],
	["thornscale_basilisk", "Gloamwood", 48, 50, 4, 2, 3, 7],
]
## Chebyshev distance kept from every other camp, and between new camps.
const CAMP_GAP: int = 9
## Open share of a camp's ground (its radius around the marker) that must be walkable.
const OPEN_SHARE: float = 0.7


func _initialize() -> void:
	var scene_root: Node = (load(SCENE_PATH) as PackedScene).instantiate()
	_prepare(scene_root)
	var group: Node = scene_root.get_node("MonsterSpawns")
	var walkable: String = ".,:=bdocv^"
	var reached: Dictionary = {}
	var starts: Array[Vector2i] = []
	for marker: Node2D in scene_root.get_node("Spawns").get_children():
		starts.append(_cell_of(marker))
	_flood(starts, walkable, reached)
	var placed: int = 0
	var missing: PackedStringArray = []
	for hunt: Array in HUNTS:
		var monster: String = hunt[0]
		var camps: int = hunt[4]
		var radius: int = hunt[6]
		var road_gap: int = hunt[7] if hunt.size() > 7 else 0
		var candidates: Array[Vector2i] = []
		for cell: Vector2i in reached:
			if WORLD.has_point(cell) and _tile(cell) == "." and _region(cell) == hunt[1] and _zone(cell).is_empty() \
					and _open(cell, radius, walkable) and (road_gap == 0 or not _near(cell, road_gap, ",=")):
				candidates.append(cell)
		# A fixed shuffle so the camps spread over the region instead of bunching in one corner.
		candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _hash(a, 71) < _hash(b, 71))
		for index: int in camps:
			var name: String = "Hunt_%s_%d" % [monster, index + 1]
			if group.has_node(name):
				continue
			var spot := Vector2i(-1, -1)
			for cell: Vector2i in candidates:
				if not _near_camp(cell, CAMP_GAP - 3):
					spot = cell
					break
			if spot.x < 0:
				missing.append(name)
				continue
			var marker := Marker2D.new()
			marker.name = name
			marker.set_script(SPAWN_SCRIPT)
			group.add_child(marker)
			marker.owner = scene_root
			marker.position = Vector2(spot * TILE) + Vector2.ONE * TILE / 2.0
			marker.set("monster", monster)
			marker.set("level", hunt[2] + (index * (hunt[3] - hunt[2] + 1) / camps))
			marker.set("count", hunt[5])
			marker.set("radius", radius)
			_camps.append([spot, radius, marker])
			placed += 1
	var error: Error = OK
	if placed > 0:
		var packed := PackedScene.new()
		packed.pack(scene_root)
		error = ResourceSaver.save(packed, SCENE_PATH)
	print("Placed %d hunting camps into %s (%s)%s" % [placed, SCENE_PATH, error_string(error),
		"" if missing.is_empty() else "; no room for " + ", ".join(missing)])
	scene_root.free()
	quit(0 if error == OK and missing.is_empty() else 1)


## Whether at least OPEN_SHARE of the ground within `radius` of `cell` is walkable.
func _open(cell: Vector2i, radius: int, walkable: String) -> bool:
	var open: int = 0
	var total: int = 0
	for y: int in range(-radius, radius + 1):
		for x: int in range(-radius, radius + 1):
			total += 1
			var tile: String = _tile(cell + Vector2i(x, y))
			if not tile.is_empty() and tile in walkable:
				open += 1
	return open >= total * OPEN_SHARE
