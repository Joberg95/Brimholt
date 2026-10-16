extends SceneTree
## Clears the stone walls ("#") that belong to nothing. A wall stays when it is part of a
## building (a run touching one: World.ROOF_AT) or a town's own wall: the cells within EDGE of
## its town zone's border, in a run with at least TOWN_WALL of them. Everything else goes: stubs
## inside towns, the arms a town wall pushes inward, the dry-stone pens and loose wall bits of the
## countryside, and the bits on Blackreed Isle. A cleared cell takes the ground most common round it
## (grass, dirt, sand, snow, or street). Running again changes nothing.
##
##   godot --headless --path . --script res://tools/generators/clear_walls.gd

const World = preload("res://game/core/world.gd")
const SCENE_PATH: String = "res://game/maps/overworld.tscn"
const EDGE: int = 1
const TOWN_WALL: int = 8
const GROUND: String = ".,:=ms"
const SIDES: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


func _initialize() -> void:
	var scene_root: Node = (load(SCENE_PATH) as PackedScene).instantiate()
	var cleared: Array[Vector2i] = stray_walls()
	var layer: TileMapLayer = scene_root.get_node("Terrain")
	for cell: Vector2i in cleared:
		layer.set_cell(cell, 0, Vector2i(World.TERRAINS.find(ground_for(cell, cleared)), 0))
	var error: Error = OK
	if not cleared.is_empty():
		var packed := PackedScene.new()
		packed.pack(scene_root)
		error = ResourceSaver.save(packed, SCENE_PATH)
	print("Cleared %d wall tiles that belonged to nothing in %s (%s)" % [cleared.size(), SCENE_PATH, error_string(error)])
	scene_root.free()
	quit(0 if error == OK else 1)


## Every overworld wall tile that is neither a building's nor a town wall's.
static func stray_walls() -> Array[Vector2i]:
	var stray: Array[Vector2i] = []
	var seen: Dictionary = {}
	for y: int in World.OVERWORLD.size.y:
		for x: int in World.OVERWORLD.size.x:
			var start := Vector2i(x, y)
			if seen.has(start) or World.terrain(start) != "#":
				continue
			var run: Array[Vector2i] = [start]
			seen[start] = true
			var index: int = 0
			while index < run.size():
				for side: Vector2i in SIDES:
					var next: Vector2i = run[index] + side
					if not seen.has(next) and World.terrain(next) == "#":
						seen[next] = true
						run.append(next)
				index += 1
			if run.any(func(cell: Vector2i) -> bool: return World.ROOF_AT.has(cell)):
				continue
			var edge: Array[Vector2i] = run.filter(func(cell: Vector2i) -> bool: return on_town_edge(cell))
			var keep: bool = edge.size() >= TOWN_WALL
			for cell: Vector2i in run:
				if not keep or not edge.has(cell):
					stray.append(cell)
	return stray


## Whether a cell lies within EDGE of its town zone's border.
static func on_town_edge(cell: Vector2i) -> bool:
	var zone: Dictionary = World.zone_at(cell)
	if not zone.get("town", false):
		return false
	var rect: Rect2i = zone["rect"]
	return cell.x - rect.position.x <= EDGE or cell.y - rect.position.y <= EDGE or rect.end.x - 1 - cell.x <= EDGE \
		or rect.end.y - 1 - cell.y <= EDGE


## The ground most common among a cleared cell's eight neighbours (grass when there is none).
static func ground_for(cell: Vector2i, cleared: Array[Vector2i]) -> String:
	var counts: Dictionary = {}
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var near: Vector2i = cell + Vector2i(dx, dy)
			var tile: String = World.terrain(near)
			if near != cell and not tile.is_empty() and tile in GROUND and not cleared.has(near):
				counts[tile] = counts.get(tile, 0) + 1
	var best: String = "."
	for tile: String in counts:
		if counts[tile] > counts.get(best, 0):
			best = tile
	return best
