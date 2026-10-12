extends RefCounted
## Original procedural terrain in map pixels. Walls are oblique: their top face is raised
## up and to the left by WALL_HEIGHT, exposing south and east faces.

const World = preload("res://game/world.gd")
const WALL_HEIGHT: float = 16.0
const OUTLINE: Color = Color("#15181d")
const GRASS: Array[Color] = [
	Color("#4f6a3c"), Color("#4b6539"), Color("#5b7845"), Color("#41592f"), Color("#6d8b4f"),
]
const DIRT: Array[Color] = [Color("#8a7458"), Color("#7d6950"), Color("#a08a6a"), Color("#655440")]
const WATER: Array[Color] = [Color("#2d5a78"), Color("#3f7394"), Color("#9fd0de"), Color("#234860")]
const WALL_TOP: Array[Color] = [Color("#7b8087"), Color("#9196a0"), Color("#62676f")]
const WALL_SOUTH: Array[Color] = [Color("#4e535c"), Color("#393d45")]
const WALL_EAST: Color = Color("#3c4048")


static func tile_at(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= World.ROWS.size() or cell.x < 0 or cell.x >= World.ROWS[0].length():
		return ""
	return World.ROWS[cell.y][cell.x]


static func noise(cell: Vector2i, salt: int) -> int:
	return absi((cell.x * 73856093) ^ (cell.y * 19349663) ^ (salt * 83492791)) % 1000003


static func draw_floor(canvas: CanvasItem, cell: Vector2i, time: float) -> void:
	var origin: Vector2 = Vector2(cell) * World.TILE_SIZE
	match tile_at(cell):
		",":
			_draw_dirt(canvas, cell, origin)
		"~":
			_draw_water(canvas, cell, origin, time)
		_:
			_draw_grass(canvas, cell, origin)


static func _draw_grass(canvas: CanvasItem, cell: Vector2i, origin: Vector2) -> void:
	canvas.draw_rect(Rect2(origin, Vector2.ONE * World.TILE_SIZE), GRASS[(cell.x + cell.y) % 2])
	for index: int in 9:
		var value: int = noise(cell, index)
		var at: Vector2 = origin + Vector2(value % 30 + 1, (value / 31) % 30 + 1)
		canvas.draw_rect(Rect2(at, Vector2(1, 1 + value % 2)), GRASS[2 + value % 3])
	for index: int in 2:
		var value: int = noise(cell, 20 + index)
		var at: Vector2 = origin + Vector2(4 + value % 22, 6 + (value / 23) % 20)
		canvas.draw_rect(Rect2(at, Vector2(1, 3)), GRASS[4])
		canvas.draw_rect(Rect2(at + Vector2(2, -1), Vector2(1, 4)), GRASS[2])
		canvas.draw_rect(Rect2(at + Vector2(4, 0), Vector2(1, 3)), GRASS[4])


static func _draw_dirt(canvas: CanvasItem, cell: Vector2i, origin: Vector2) -> void:
	canvas.draw_rect(Rect2(origin, Vector2.ONE * World.TILE_SIZE), DIRT[0])
	for index: int in 7:
		var value: int = noise(cell, 40 + index)
		var at: Vector2 = origin + Vector2(value % 28 + 2, (value / 29) % 28 + 2)
		canvas.draw_rect(Rect2(at, Vector2(2, 2)), DIRT[2] if value % 3 else DIRT[1])
		canvas.draw_rect(Rect2(at + Vector2(1, 2), Vector2(2, 1)), DIRT[3])
	for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if tile_at(cell + direction) == ".":
			_draw_edge(canvas, origin, direction, 2.0, Color(DIRT[3], 0.55))


static func _draw_water(canvas: CanvasItem, cell: Vector2i, origin: Vector2, time: float) -> void:
	canvas.draw_rect(Rect2(origin, Vector2.ONE * World.TILE_SIZE), WATER[0])
	for index: int in 3:
		var value: int = noise(cell, 60 + index)
		var drift: int = int(time * 5.0 + value) % 26
		var at: Vector2 = origin + Vector2(drift + 1, 5 + index * 10 + value % 4)
		canvas.draw_rect(Rect2(at, Vector2(5, 1)), WATER[1])
		if value % 3 == 0:
			canvas.draw_rect(Rect2(at + Vector2(1, -1), Vector2(2, 1)), WATER[2])
	for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var neighbor: String = tile_at(cell + direction)
		if neighbor != "~" and neighbor != "#" and neighbor != "":
			_draw_edge(canvas, origin, direction, 3.0, WATER[3])
			_draw_edge(canvas, origin, direction, 1.0, Color(WATER[2], 0.8))


static func _draw_edge(canvas: CanvasItem, origin: Vector2, direction: Vector2i, width: float, color: Color) -> void:
	var size: float = World.TILE_SIZE
	if direction == Vector2i.UP:
		canvas.draw_rect(Rect2(origin, Vector2(size, width)), color)
	elif direction == Vector2i.DOWN:
		canvas.draw_rect(Rect2(origin + Vector2(0, size - width), Vector2(size, width)), color)
	elif direction == Vector2i.LEFT:
		canvas.draw_rect(Rect2(origin, Vector2(width, size)), color)
	else:
		canvas.draw_rect(Rect2(origin + Vector2(size - width, 0), Vector2(width, size)), color)


## Draw in row-major order so nearer (south/east) walls cover what stands behind them.
static func draw_wall(canvas: CanvasItem, cell: Vector2i) -> void:
	var size: float = World.TILE_SIZE
	var height: float = WALL_HEIGHT
	var x0: float = cell.x * size
	var y0: float = cell.y * size
	var x1: float = x0 + size
	var y1: float = y0 + size
	var open_north: bool = tile_at(cell + Vector2i.UP) != "#"
	var open_south: bool = tile_at(cell + Vector2i.DOWN) != "#"
	var open_west: bool = tile_at(cell + Vector2i.LEFT) != "#"
	var open_east: bool = tile_at(cell + Vector2i.RIGHT) != "#"
	if open_east:
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(x1, y0), Vector2(x1, y1), Vector2(x1 - height, y1 - height), Vector2(x1 - height, y0 - height),
		]), WALL_EAST)
		canvas.draw_line(Vector2(x1 - 0.5, y0), Vector2(x1 - 0.5, y1), OUTLINE)
	if open_south:
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(x0, y1), Vector2(x1, y1), Vector2(x1 - height, y1 - height), Vector2(x0 - height, y1 - height),
		]), WALL_SOUTH[0])
		for course: int in [1, 2]:
			var rise: float = course * height / 3.0
			canvas.draw_line(Vector2(x0 - rise, y1 - rise), Vector2(x1 - rise, y1 - rise), WALL_SOUTH[1])
		for course: int in 3:
			var low: float = course * height / 3.0
			var high: float = low + height / 3.0
			var shift: float = 8.0 if course % 2 == 0 else 0.0
			for joint: float in [8.0 + shift, 24.0 + shift]:
				if joint < size:
					canvas.draw_line(Vector2(x0 + joint - low, y1 - low), Vector2(x0 + joint - high, y1 - high), WALL_SOUTH[1])
		canvas.draw_line(Vector2(x0, y1 - 0.5), Vector2(x1, y1 - 0.5), OUTLINE)
	var top: Rect2 = Rect2(x0 - height, y0 - height, size, size)
	canvas.draw_rect(top, WALL_TOP[0])
	canvas.draw_line(top.position + Vector2(0, 16), top.position + Vector2(size, 16), WALL_TOP[2])
	var seam: float = 10.0 + float(noise(cell, 80) % 12)
	canvas.draw_line(top.position + Vector2(seam, 0), top.position + Vector2(seam, 16), WALL_TOP[2])
	canvas.draw_line(top.position + Vector2(seam + 8, 16), top.position + Vector2(seam + 8, size), WALL_TOP[2])
	canvas.draw_rect(Rect2(top.position + Vector2(2, 2), Vector2(4, 1)), WALL_TOP[1])
	canvas.draw_rect(Rect2(top.position + Vector2(18, 19), Vector2(3, 1)), WALL_TOP[1])
	if open_north:
		canvas.draw_rect(Rect2(top.position, Vector2(size, 1)), OUTLINE)
		canvas.draw_rect(Rect2(top.position + Vector2(0, 1), Vector2(size, 1)), WALL_TOP[1])
	if open_west:
		canvas.draw_rect(Rect2(top.position, Vector2(1, size)), OUTLINE)
	if open_south:
		canvas.draw_rect(Rect2(top.position + Vector2(0, size - 1), Vector2(size, 1)), OUTLINE)
	if open_east:
		canvas.draw_rect(Rect2(top.position + Vector2(size - 1, 0), Vector2(1, size)), OUTLINE)
