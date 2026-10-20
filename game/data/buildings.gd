extends RefCounted
## Finds town buildings in a terrain grid: small rooms enclosed by walls and doors. A door is
## an open tile between two walls in a wall line (west and east, or north and south). Rooms are
## filled between walls without crossing doors; a room that stays inside the search area and
## holds at most MAX_ROOM tiles is a building. Rooms floored with a castle keep's sandstone or
## carpet ("F", "Y") are not: a keep stands open to the sky, its halls seen from above as in Tibia.
## Shared by the world (roofs, signs) and the town
## painter, so it depends on nothing: terrain comes from a Callable(cell) -> String.

const WALLS: String = "#OCW"
const MAX_ROOM: int = 48
const SIDES: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


## Buildings in `area`: [{rect (walls included), interior: Array[Vector2i], doors: Array[Vector2i],
## footprint: Array[Vector2i] (interior, doors, and the wall ring), and outward: {door: direction}}].
static func find(terrain: Callable, area: Rect2i) -> Array:
	var seen: Dictionary = {}
	var found: Array = []
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var start := Vector2i(x, y)
			if seen.has(start) or _wall(terrain, start) or is_door(terrain, start):
				continue
			var room: Array[Vector2i] = []
			var doors: Dictionary = {}
			var open: bool = false
			var queue: Array[Vector2i] = [start]
			seen[start] = true
			while not queue.is_empty():
				var cell: Vector2i = queue.pop_back()
				room.append(cell)
				for side: Vector2i in SIDES:
					var next: Vector2i = cell + side
					if not area.has_point(next):
						open = true
						continue
					if _wall(terrain, next) or seen.has(next):
						continue
					if is_door(terrain, next):
						doors[next] = side
						continue
					seen[next] = true
					queue.append(next)
			if open or room.size() > MAX_ROOM or doors.is_empty() or room.any(_keep_floor.bind(terrain)):
				continue
			found.append(_building(terrain, room, doors))
	return found


static func _keep_floor(cell: Vector2i, terrain: Callable) -> bool:
	return terrain.call(cell) in ["F", "Y"]


## An open tile between two walls in a wall line.
static func is_door(terrain: Callable, cell: Vector2i) -> bool:
	if _wall(terrain, cell):
		return false
	var across: bool = _wall(terrain, cell + Vector2i.LEFT) and _wall(terrain, cell + Vector2i.RIGHT)
	var along: bool = _wall(terrain, cell + Vector2i.UP) and _wall(terrain, cell + Vector2i.DOWN)
	return across != along


static func _wall(terrain: Callable, cell: Vector2i) -> bool:
	var tile: String = terrain.call(cell)
	return not tile.is_empty() and tile in WALLS


static func _building(terrain: Callable, room: Array[Vector2i], doors: Dictionary) -> Dictionary:
	var footprint: Dictionary = {}
	for cell: Vector2i in room:
		for y: int in range(-1, 2):
			for x: int in range(-1, 2):
				var near: Vector2i = cell + Vector2i(x, y)
				if near == cell or _wall(terrain, near) or doors.has(near):
					footprint[near] = true
	var rect := Rect2i(room[0], Vector2i.ONE)
	for cell: Vector2i in footprint:
		rect = rect.expand(cell).merge(Rect2i(cell, Vector2i.ONE))
	var interior: Array[Vector2i] = room.duplicate()
	interior.sort()
	var cells: Array[Vector2i] = []
	cells.assign(footprint.keys())
	cells.sort()
	var door_cells: Array[Vector2i] = []
	door_cells.assign(doors.keys())
	door_cells.sort()
	return {"rect": rect, "interior": interior, "doors": door_cells, "footprint": cells, "outward": doors}
