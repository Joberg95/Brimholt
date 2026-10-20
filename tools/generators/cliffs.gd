extends "res://tools/generators/landscape.gd"
## Cliffs and a lighter forest, in the existing overworld scene:
## - about FOREST_CUT of every hundred countryside trees become meadow (a fixed hash of the tile);
## - mountains ("L", masses of boulders over grey grit) fill the high ground of a smooth height
##   field, more in the north-eastern highlands, broken by passes and kept away from roads,
##   water, towns, markers, and monster camps;
## - any ground a cliff closes off gets a way in (the shortest cut through cliff, rock, or trees),
##   and every marker stays reachable.
## Towns, Blackreed Isle, the Hollow Reach, the desert, and dungeons are left alone. The scene
## remembers that it ran (metadata "cliffs"); running again changes nothing.
##
##   godot --headless --path . --script res://tools/generators/cliffs.gd

const FOREST_CUT: int = 30
## Smooth height field: cliffs ring ground above the level (lower, so more cliffs, in the highlands).
const HEIGHT_PERIOD: float = 30.0
const CLIFF_LEVEL: float = 0.66
const HIGHLAND_CLIFF_LEVEL: float = 0.58
## Passes: cliff cells where this noise is low stay open.
const PASS_LEVEL: float = 0.28
## Cliff pieces shorter than this are dropped.
const MIN_CLIFF: int = 6
const KEEP_CLEAR: String = "=,~b:#"


func _initialize() -> void:
	var scene_root: Node = MapIO.load_scene()
	if scene_root.has_meta("cliffs"):
		print("The cliffs are already painted into %s: nothing to do" % SCENE_PATH)
		MapIO.free_scene(scene_root)
		quit(0)
		return
	_prepare(scene_root)
	var report: Dictionary = {"trees removed": _fewer_trees(), "cliffs": _cliffs()}
	report["passes opened"] = _open_closed_ground(scene_root)
	report["paths carved"] = _reconnect(scene_root)
	scene_root.set_meta("cliffs", true)
	var error: Error = MapIO.save_scene(scene_root)
	print("Painted cliffs into %s: %s (%s)" % [SCENE_PATH, report, error_string(error)])
	MapIO.free_scene(scene_root)
	quit(0 if error == OK else 1)


func _fewer_trees() -> int:
	var removed: int = 0
	for cell: Vector2i in _layer.get_used_cells():
		if _tile(cell) == "T" and _countryside(cell) and _hash(cell, 61) % 100 < FOREST_CUT:
			_paint(cell, ".")
			removed += 1
	return removed


func _height(cell: Vector2i) -> float:
	return _noise(cell, HEIGHT_PERIOD, 51) * 0.8 + _noise(cell, 9.0, 52) * 0.2


func _near_zone(cell: Vector2i, distance: int) -> bool:
	return _zones.any(func(zone: Array) -> bool: return (zone[1] as Rect2i).grow(distance).has_point(cell))


func _cliffs() -> int:
	var cliff: Dictionary = {}
	for cell: Vector2i in _layer.get_used_cells():
		if not WORLD.has_point(cell) or not _tile(cell) in [".", "T", "R", "C"] or not _countryside(cell) or _near_zone(cell, 3) \
				or _near(cell, 2, KEEP_CLEAR) or _near_camp(cell, 2):
			continue
		var level: float = HIGHLAND_CLIFF_LEVEL if HIGHLANDS.has_point(cell) else CLIFF_LEVEL
		if _height(cell) < level or _noise(cell, 7.0, 53) < PASS_LEVEL:
			continue
		cliff[cell] = true
	# Drop short pieces (counted with diagonal neighbours, which still read as one cliff line).
	var seen: Dictionary = {}
	var painted: int = 0
	for start: Vector2i in cliff:
		if seen.has(start):
			continue
		var piece: Array[Vector2i] = [start]
		seen[start] = true
		var at: int = 0
		while at < piece.size():
			for y: int in range(-1, 2):
				for x: int in range(-1, 2):
					var next: Vector2i = piece[at] + Vector2i(x, y)
					if cliff.has(next) and not seen.has(next):
						seen[next] = true
						piece.append(next)
			at += 1
		if piece.size() < MIN_CLIFF:
			continue
		for cell: Vector2i in piece:
			_paint(cell, "L")
			painted += 1
	# Bare rock: no trees inside a mountain or touching its foot.
	for cell: Vector2i in _layer.get_used_cells():
		if _tile(cell) == "T" and _countryside(cell) and _near(cell, 1, "L"):
			_paint(cell, ".")
	return painted


## Ground beside a cliff that cannot be walked to from the spawns gets the shortest cut to
## reachable ground through cliff, rock, or trees. Returns the tiles opened.
func _open_closed_ground(scene_root: Node) -> int:
	var walkable: String = ".,:=bdocv^"
	var reached: Dictionary = {}
	var starts: Array[Vector2i] = []
	for group: String in ["Spawns", "Ferrymen"]:
		for marker: Node2D in scene_root.get_node(group).get_children():
			starts.append(_cell_of(marker))
	_flood(starts, walkable, reached)
	var opened: int = 0
	for cell: Vector2i in _layer.get_used_cells():
		if _tile(cell) != "L":
			continue
		for side: Vector2i in SIDES:
			var inside: Vector2i = cell + side
			var tile: String = _tile(inside)
			if reached.has(inside) or tile.is_empty() or not tile in walkable or not _countryside(inside):
				continue
			var came: Dictionary = {inside: inside}
			var queue: Array[Vector2i] = [inside]
			var found := Vector2i(-1, -1)
			var head: int = 0
			while head < queue.size() and found.x < 0:
				var here: Vector2i = queue[head]
				head += 1
				for step: Vector2i in SIDES:
					var next: Vector2i = here + step
					var kind: String = _tile(next)
					if came.has(next) or not WORLD.has_point(next) or kind.is_empty() or not (kind in walkable or kind in "TRCL"):
						continue
					came[next] = here
					if reached.has(next):
						found = next
						break
					queue.append(next)
			if found.x < 0:
				continue
			var path: Array[Vector2i] = []
			var walk: Vector2i = came[found]
			while true:
				path.append(walk)
				if _tile(walk) in "TRCL":
					_paint(walk, ".")
					opened += 1
				if walk == inside:
					break
				walk = came[walk]
			_flood(path, walkable, reached)
	return opened
