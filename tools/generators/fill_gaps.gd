extends "res://tools/generators/landscape.gd"
## Fills the empty stretches of the countryside with camps. Every open, walkable spot of the
## mainland and the frost isles that players reach (by foot or by boat) and that lies more than
## GAP tiles from every camp gets a camp, in a fixed order, until no such spot is left. A new camp
## copies the nearest normal camp of its own region (monster and level), so the region's levels and
## hunting tasks stay the same; it is a tight pack of COUNT within RADIUS. Markers are named
## "Gap_<monster>_<n>"; existing ones are kept, so running again changes nothing.
##
##   godot --headless --path . --script res://tools/generators/fill_gaps.gd

const Monsters = preload("res://game/data/monsters.gd")
const SPAWN_SCRIPT: Script = preload("res://game/maps/markers/monster_spawn.gd")
const WALKABLE: String = ".,:=bdocv^msFY"
## A camp goes wherever the nearest camp is further than GAP: past that, the game window (15 tiles
## across) can show nothing to hunt.
const GAP: int = 10
const COUNT: int = 5
const RADIUS: int = 2
const ROAD_GAP: int = 2
const OPEN_SHARE: float = 0.6
const TOWN_GAP: int = 6


func _initialize() -> void:
	var scene_root: Node = MapIO.load_scene()
	_prepare(scene_root)
	var spawns: Node = scene_root.get_node("MonsterSpawns")
	var reached: Dictionary = {}
	var starts: Array[Vector2i] = []
	for group: String in ["Spawns", "Ferrymen"]:
		for marker: Node2D in scene_root.get_node(group).get_children():
			starts.append(_cell_of(marker))
	_flood(starts, WALKABLE, reached)
	var candidates: Array[Vector2i] = []
	for cell: Vector2i in reached:
		if _countryside(cell) and _tile(cell) in ".:ms" and _open(cell) and not _near(cell, ROAD_GAP, ",=b~v") \
				and not _near_town(cell):
			candidates.append(cell)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _hash(a, 97) < _hash(b, 97))
	var placed: int = 0
	var counts: Dictionary = {}
	for marker: Node in spawns.get_children():
		if String(marker.name).begins_with("Gap_"):
			counts[String(marker.get("monster"))] = counts.get(String(marker.get("monster")), 0) + 1
	for cell: Vector2i in candidates:
		if _near_camp(cell, GAP):
			continue
		var model: Node2D = _model_camp(cell)
		if model == null:
			continue
		var monster: String = String(model.get("monster"))
		counts[monster] = counts.get(monster, 0) + 1
		var marker := Marker2D.new()
		marker.name = "Gap_%s_%d" % [monster, counts[monster]]
		marker.set_script(SPAWN_SCRIPT)
		spawns.add_child(marker)
		marker.owner = scene_root
		marker.position = Vector2(cell * TILE) + Vector2.ONE * TILE / 2.0
		marker.set("monster", monster)
		marker.set("level", int(model.get("level")))
		marker.set("count", COUNT)
		marker.set("radius", RADIUS)
		_camps.append([cell, RADIUS, marker])
		placed += 1
	var error: Error = OK
	if placed > 0:
		error = MapIO.save_scene(scene_root)
	print("Filled %d empty stretches with camps in %s (%s)" % [placed, SCENE_PATH, error_string(error)])
	MapIO.free_scene(scene_root)
	quit(0 if error == OK else 1)


## At least OPEN_SHARE of the ground within RADIUS + 1 is walkable, so the pack has room (camps
## may stand in clearings of a wood).
func _open(cell: Vector2i) -> bool:
	var open: int = 0
	var total: int = 0
	for dy: int in range(-RADIUS - 1, RADIUS + 2):
		for dx: int in range(-RADIUS - 1, RADIUS + 2):
			var tile: String = _tile(cell + Vector2i(dx, dy))
			total += 1
			open += 1 if not tile.is_empty() and tile in WALKABLE else 0
	return open >= total * OPEN_SHARE


func _near_town(cell: Vector2i) -> bool:
	for zone: Array in _zones:
		if zone[2] and (zone[1] as Rect2i).grow(TOWN_GAP).has_point(cell):
			return true
	return false


## The nearest normal, overworld camp of the cell's region (not an elite ground, a champion, or a
## zone's camp), or null when the region has none.
func _model_camp(cell: Vector2i) -> Node2D:
	var region: String = _region(cell)
	var best: Node2D = null
	var nearest: int = 1 << 30
	for camp: Array in _camps:
		var marker: Node2D = camp[2]
		var at: Vector2i = camp[0]
		var kind: String = String(marker.get("monster"))
		if not Monsters.MONSTERS.has(kind) or Monsters.MONSTERS[kind]["rank"] != "normal" or not _countryside(at) \
				or _region(at) != region:
			continue
		var gap: int = maxi(absi(at.x - cell.x), absi(at.y - cell.y))
		if gap < nearest:
			nearest = gap
			best = marker
	return best
