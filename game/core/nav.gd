extends RefCounted
## Long-range navigation for bots: Godot's AStarGrid2D over the walkable overworld (stairways
## and dungeon copies excluded), built once on first use. Bots follow a planned route and step
## around whoever stands on it with Combat.path_step; the route is re-planned when they stray.

const World = preload("res://game/core/world.gd")

static var _grid: AStarGrid2D = null


static func grid() -> AStarGrid2D:
	if _grid != null:
		return _grid
	_grid = AStarGrid2D.new()
	_grid.region = World.OVERWORLD
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_grid.update()
	var rect: Rect2i = World.OVERWORLD
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			if not World.walkable(cell) or World.terrain(cell) in ["v", "^"]:
				_grid.set_point_solid(cell, true)
	return _grid


## Cells from `from` (exclusive) to `to` (inclusive), or [] when there is no way. A goal that
## blocks (an NPC's tile) is replaced by the nearest walkable cell beside it.
static func route(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var map: AStarGrid2D = grid()
	var result: Array[Vector2i] = []
	if not map.is_in_boundsv(from) or not map.is_in_boundsv(to):
		return result
	var goal: Vector2i = to
	if map.is_point_solid(goal):
		goal = open_beside(to)
		if goal.x < 0:
			return result
	var solid_start: bool = map.is_point_solid(from)
	if solid_start:
		map.set_point_solid(from, false)
	var path: Array[Vector2i] = map.get_id_path(from, goal)
	if solid_start:
		map.set_point_solid(from, true)
	for index: int in range(1, path.size()):
		result.append(path[index])
	return result


## The nearest walkable overworld cell within three tiles of `cell`, or (-1, -1).
static func open_beside(cell: Vector2i) -> Vector2i:
	var map: AStarGrid2D = grid()
	for radius: int in range(1, 4):
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				var spot: Vector2i = cell + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) == radius and map.is_in_boundsv(spot) and not map.is_point_solid(spot):
					return spot
	return Vector2i(-1, -1)
