extends RefCounted
## Long-range navigation for bots: Godot's AStarGrid2D per space (each continent, Atlas.CONTINENTS;
## the rest of the painted overworld as one more; each floor off the surface), stairways and dungeon copies excluded, each
## built the first time a bot routes there, so startup and memory do not grow with the world.
## Bots follow a planned route and step around whoever stands on it with Combat.path_step; the
## route is re-planned when they stray. There is no way between spaces on foot (boats cross).

const World = preload("res://game/core/world.gd")
const WorldMap = preload("res://game/world_map/world_map.gd")
const Atlas = preload("res://game/data/atlas.gd")

static var _grids: Dictionary = {}


## The space a cell lies in: [name, cells] of its continent, ["", the painted overworld], or
## ["floor <z>", the painted part of that floor] off the surface (Atlas.floor_of).
static func space_of(cell: Vector2i) -> Array:
	var z: int = Atlas.floor_of(cell)
	if z != 0 and z != Atlas.NO_FLOOR:
		return ["floor %d" % z, WorldMap.floor_bounds(z)]
	for continent: Dictionary in Atlas.CONTINENTS:
		if (continent["cells"] as Rect2i).has_point(cell):
			return [continent["name"], continent["cells"]]
	return ["", WorldMap.PAINTED]


## The navigation grid of the space holding `cell`.
static func grid(cell: Vector2i) -> AStarGrid2D:
	var space: Array = space_of(cell)
	if _grids.has(space[0]):
		return _grids[space[0]]
	var rect: Rect2i = space[1]
	var made := AStarGrid2D.new()
	made.region = rect
	made.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	made.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	made.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	made.update()
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var at := Vector2i(x, y)
			if not WorldMap.walkable(at) or WorldMap.terrain(at) in ["v", "^"]:
				made.set_point_solid(at, true)
			elif World.GROUND_STEP.has(WorldMap.terrain(at)):
				# Roads are quicker to walk, so routes follow them (World.GROUND_STEP).
				made.set_point_weight_scale(at, World.GROUND_STEP[WorldMap.terrain(at)])
	_grids[space[0]] = made
	return made


## Cells from `from` (exclusive) to `to` (inclusive), or [] when there is no way. A goal that
## blocks (an NPC's tile) is replaced by the nearest walkable cell beside it.
static func route(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if space_of(from)[0] != space_of(to)[0]:
		return result
	var map: AStarGrid2D = grid(from)
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
	var map: AStarGrid2D = grid(cell)
	for radius: int in range(1, 4):
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				var spot: Vector2i = cell + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) == radius and map.is_in_boundsv(spot) and not map.is_point_solid(spot):
					return spot
	return Vector2i(-1, -1)
