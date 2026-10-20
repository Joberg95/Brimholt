extends "res://tools/generators/landscape.gd"
## Tightens the overworld's hunting camps: every camp of a normal monster from level MIN_LEVEL up
## keeps 5-7 monsters (by a fixed hash of its place) within CAMP_RADIUS tiles, so a 25-kill task
## is two or three camp clears instead of a walk across the region. The starter camps (voles,
## toads, boars, bandits) stay small for new characters, and elites, champions, and bosses keep
## their numbers. A camp whose ground is too closed for its count keeps a wider radius. The scene
## remembers that it ran (metadata "camp_density"); running again changes nothing.
##
##   godot --headless --path . --script res://tools/generators/camp_density.gd

const Monsters = preload("res://game/data/monsters.gd")
const MIN_LEVEL: int = 11
const COUNTS: Array[int] = [5, 6, 7]
const CAMP_RADIUS: int = 2
## Walkable cells a camp needs per monster within its radius before it may tighten.
const ROOM_PER_MONSTER: float = 2.0


func _initialize() -> void:
	var scene_root: Node = MapIO.load_scene()
	if scene_root.has_meta("camp_density"):
		print("Camp density already applied to %s" % SCENE_PATH)
		MapIO.free_scene(scene_root)
		quit(0)
		return
	_prepare(scene_root)
	var walkable: String = ".,:=bdocv^"
	var changed: int = 0
	var wide: int = 0
	for marker: Node2D in scene_root.get_node("MonsterSpawns").get_children():
		var monster: String = marker.get("monster")
		if not Monsters.MONSTERS.has(monster) or Monsters.MONSTERS[monster]["rank"] != "normal" \
				or int(marker.get("level")) < MIN_LEVEL or int(marker.get("count")) >= COUNTS[0]:
			continue
		var cell: Vector2i = _cell_of(marker)
		var count: int = COUNTS[_hash(cell, 13) % COUNTS.size()]
		var radius: int = CAMP_RADIUS
		while radius < int(marker.get("radius")) and _room(cell, radius, walkable) < count * ROOM_PER_MONSTER:
			radius += 1
		wide += 1 if radius > CAMP_RADIUS else 0
		marker.set("count", count)
		marker.set("radius", radius)
		changed += 1
	scene_root.set_meta("camp_density", true)
	var error: Error = MapIO.save_scene(scene_root)
	print("Tightened %d camps to 5-7 monsters (%d kept a wider radius) in %s (%s)" % [changed, wide, SCENE_PATH,
		error_string(error)])
	MapIO.free_scene(scene_root)
	quit(0 if error == OK else 1)


## Walkable cells within `radius` of `cell`.
func _room(cell: Vector2i, radius: int, walkable: String) -> int:
	var open: int = 0
	for y: int in range(-radius, radius + 1):
		for x: int in range(-radius, radius + 1):
			var tile: String = _tile(cell + Vector2i(x, y))
			if not tile.is_empty() and tile in walkable:
				open += 1
	return open
