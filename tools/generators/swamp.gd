extends "res://tools/generators/landscape.gd"
## Turns Mirewood Fen (Biomes.SWAMP_REGION, levels 30-50) into a swamp: open grass becomes dark
## bog mud ("m") but for scattered grassy hummocks, most trees become giant mushrooms ("U"), and
## small murky pools, well apart, open in the mud, each crossed both ways by a plank walkway so no
## pool cuts a path. Towns, zones, roads, markers, and camps (with a margin) are left alone. The
## scene remembers that it ran (metadata "swamp"); running again changes nothing.
##
##   godot --headless --path . --script res://tools/generators/swamp.gd

const Biomes = preload("res://game/data/biomes.gd")
## Share of a fen tree that becomes a mushroom; noise level under which grass stays grass.
const MUSHROOM_SHARE: int = 75
const HUMMOCK: float = 0.3
## Pools: radius, the gap between their centres, and the clearance kept from camps and roads.
const POOL_RADIUS: int = 2
const POOL_GAP: int = 9
const POOL_CLEARANCE: int = 5


func _initialize() -> void:
	var scene_root: Node = MapIO.load_scene()
	if scene_root.has_meta("swamp"):
		print("The swamp is already painted into %s" % SCENE_PATH)
		MapIO.free_scene(scene_root)
		quit(0)
		return
	_prepare(scene_root)
	var changed: int = 0
	var fen: Array[Vector2i] = []
	for y: int in WORLD.size.y:
		for x: int in WORLD.size.x:
			var cell := Vector2i(x, y)
			if _region(cell) == Biomes.SWAMP_REGION and _countryside(cell):
				fen.append(cell)
	for cell: Vector2i in fen:
		var tile: String = _tile(cell)
		if tile == "." and _noise(cell, 6.0, 61) > HUMMOCK:
			_paint(cell, "m")
			changed += 1
		elif tile == "T" and _hash(cell, 62) % 100 < MUSHROOM_SHARE:
			_paint(cell, "U")
			changed += 1
	# Pools in open mud, away from camps, roads, and each other.
	var pools: Array[Vector2i] = []
	for cell: Vector2i in fen:
		if _hash(cell, 63) % 37 != 0 or not _open_mud(cell) or _near(cell, POOL_CLEARANCE, ",=b~") \
				or _near_camp(cell, POOL_CLEARANCE) or pools.any(func(other: Vector2i) -> bool:
					return maxi(absi(other.x - cell.x), absi(other.y - cell.y)) < POOL_GAP):
			continue
		pools.append(cell)
		for dy: int in range(-POOL_RADIUS, POOL_RADIUS + 1):
			for dx: int in range(-POOL_RADIUS, POOL_RADIUS + 1):
				if dx * dx + dy * dy <= POOL_RADIUS * POOL_RADIUS + 1:
					var at: Vector2i = cell + Vector2i(dx, dy)
					_paint(at, "b" if dx == 0 or dy == 0 else "~")
					changed += 1
	scene_root.set_meta("swamp", true)
	var error: Error = MapIO.save_scene(scene_root)
	print("Painted the swamp: %d tiles, %d pools, in %s (%s)" % [changed, pools.size(), SCENE_PATH, error_string(error)])
	MapIO.free_scene(scene_root)
	quit(0 if error == OK else 1)


## Mud all round, wide enough for a pool and the walk around it.
func _open_mud(cell: Vector2i) -> bool:
	for dy: int in range(-POOL_RADIUS - 1, POOL_RADIUS + 2):
		for dx: int in range(-POOL_RADIUS - 1, POOL_RADIUS + 2):
			var at: Vector2i = cell + Vector2i(dx, dy)
			if _tile(at) not in ["m", "."] or _reserved.has(at) or not _zone(at).is_empty():
				return false
	return true
