extends SceneTree
## Bakes the painted world map (assets/sprites/world_map.png, SCALE pixels per map tile, laid out
## by game/data/atlas.gd: the frost isles west of the mainland)
## from the map scene, in the art direction's map look: deep blue sea with lighter shallows and a
## pale line of surf, green land with soft painted variation, forests as clumps of canopy lit from
## the top-left, grey ridges with a lit and a shaded side, sandy plains and desert, dusky purple
## for the Hollow Reach, and towns as terracotta roofs on paved streets inside their walls. The
## game tints PvP zones and draws the markers on top (game/ui/world_maps.gd). The terrain's hash
## goes to world_map.json, so the rules check notices a map edited since the last bake.
##
##   godot --headless --path . --script res://tools/generators/world_map.gd

const World = preload("res://game/core/world.gd")
const Atlas = preload("res://game/data/atlas.gd")
const Biomes = preload("res://game/data/biomes.gd")
const SCALE: int = 4
const PNG: String = "res://assets/sprites/world_map.png"
const META: String = "res://assets/sprites/world_map.json"

const SEA_DEEP: Color = Color("#2a5680")
const SEA_SHALLOW: Color = Color("#4a86b0")
const SURF: Color = Color("#c8dce4")
const GRASS: Color = Color("#5c7a40")
const FOREST: Array[Color] = [Color("#7a9a52"), Color("#3e6030"), Color("#2a4422"), Color("#1c3018")]
## The Hollow Reach's dead trees.
const DEAD_FOREST: Array[Color] = [Color("#6a5a7a"), Color("#3e3050"), Color("#2a2038"), Color("#1a1424")]
const DIRT: Color = Color("#9a8460")
const SAND: Color = Color("#d8c48a")
const DUSK: Color = Color("#4a3a5a")
const BOG: Color = Color("#4a4632")
const MUSHROOM_CAPS: Array[Color] = [Color("#8ab0a0"), Color("#5e8a7a"), Color("#3e6a5c"), Color("#22403a")]
const OBSIDIAN: Color = Color("#2e2638")
const ROCK: Array[Color] = [Color("#aaa292"), Color("#7c7668"), Color("#4e4a42")]
const STREET: Color = Color("#bab4a6")
const WALL: Color = Color("#5c5a58")
const ROOF: Array[Color] = [Color("#c8724a"), Color("#a85a3a"), Color("#6e3424")]
const TOWN_GROUND: Color = Color("#a89a7a")
const BRIDGE: Color = Color("#8a5a34")
const STAIRS: Color = Color("#20180e")
## The frost isles: snowfields, snow-laden fir woods, log walls, and snowed roofs.
const SNOW: Color = Color("#e2e9f0")
const FIRS: Array[Color] = [Color("#f2f6fa"), Color("#4a6a58"), Color("#2c4636"), Color("#1a2c22")]
const LOG_WALL: Color = Color("#6a4a2c")
const SNOW_ROOF: Array[Color] = [Color("#f4f8fc"), Color("#d4dee8"), Color("#8a9aaa")]


func _initialize() -> void:
	# The sheets of the atlas (game/data/atlas.gd): the isles west of the mainland, open sea between.
	var image := Image.create(Atlas.SIZE.x * SCALE, Atlas.SIZE.y * SCALE, false, Image.FORMAT_RGB8)
	image.fill(SEA_DEEP)
	for sheet: Dictionary in Atlas.SHEETS:
		var cells: Rect2i = sheet["cells"]
		for y: int in range(cells.position.y, cells.end.y):
			for x: int in range(cells.position.x, cells.end.x):
				var cell := Vector2i(x, y)
				_paint_tile(image, cell, (cell - cells.position + sheet["at"]) * SCALE)
	var error: Error = image.save_png(ProjectSettings.globalize_path(PNG))
	var meta := FileAccess.open(META, FileAccess.WRITE)
	meta.store_string(JSON.stringify({"scale": SCALE, "terrain": World.overworld_hash()}, "  ") + "\n")
	meta.close()
	print("Baked %s (%dx%d, %s)" % [PNG, image.get_width(), image.get_height(), error_string(error)])
	quit(0 if error == OK else 1)


func _paint_tile(image: Image, cell: Vector2i, corner: Vector2i) -> void:
	var tile: String = World.terrain(cell)
	match tile:
		"~":
			var shore: int = _distance_to_land(cell, 3)
			var water: Color = SEA_DEEP.lerp(SEA_SHALLOW, clampf(1.0 - (shore - 1) / 2.5, 0.0, 1.0)) if shore > 0 else SEA_DEEP
			_fill(image, corner, _vary(water, cell, 0.03))
			if shore == 1:
				# Surf along the shore, on the side facing the land.
				for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					if World.terrain(cell + side) not in ["~", "b", ""]:
						_edge(image, corner, side, SURF)
		"T", "D":
			_fill(image, corner, _vary(FOREST[2] if tile == "T" else DEAD_FOREST[2], cell, 0.05))
			_canopy(image, corner, cell, FOREST if tile == "T" else DEAD_FOREST)
		"C", "L", "R":
			_ridge(image, corner, cell)
		"#", "W":
			_fill(image, corner, LOG_WALL if Biomes.in_isles(cell) else WALL)
		"s":
			_fill(image, corner, _vary(SNOW, cell, 0.04))
		"P":
			_fill(image, corner, _vary(SNOW, cell, 0.04))
			_canopy(image, corner, cell, FIRS)
		"=":
			_fill(image, corner, _vary(STREET, cell, 0.04))
		",":
			_fill(image, corner, _vary(DIRT, cell, 0.05))
		":", "K":
			_fill(image, corner, _vary(SAND, cell, 0.04))
			if tile == "K":
				image.set_pixelv(corner + Vector2i(1, 1), Color("#6a7a40"))
		"d":
			_fill(image, corner, _vary(DUSK, cell, 0.05))
		"m":
			_fill(image, corner, _vary(BOG, cell, 0.05))
		"U":
			_fill(image, corner, _vary(BOG, cell, 0.05))
			_canopy(image, corner, cell, MUSHROOM_CAPS)
		"o", "O":
			_fill(image, corner, _vary(OBSIDIAN, cell, 0.05))
		"b":
			_fill(image, corner, BRIDGE)
		"v", "^":
			_fill(image, corner, _vary(GRASS, cell, 0.06))
			image.fill_rect(Rect2i(corner + Vector2i(1, 1), Vector2i(2, 2)), STAIRS)
		_:
			var ground: Color = TOWN_GROUND if World.zone_at(cell).get("town", false) else GRASS
			_fill(image, corner, _vary(ground, cell, 0.06))
	if World.ROOF_AT.has(cell):
		_roof(image, corner, cell)


## A flat tile with a little texture: each pixel a shade lighter or darker by a fixed hash.
func _fill(image: Image, corner: Vector2i, color: Color) -> void:
	for y: int in SCALE:
		for x: int in SCALE:
			var jitter: float = float(posmod((corner.x + x) * 73 + (corner.y + y) * 151, 17)) / 17.0 - 0.5
			image.set_pixelv(corner + Vector2i(x, y), color.lightened(jitter * 0.05) if jitter > 0.0 else color.darkened(-jitter * 0.05))


## Soft large-scale variation, so open land reads as painted rather than flat.
static func _vary(color: Color, cell: Vector2i, strength: float) -> Color:
	var wave: float = sin(cell.x * 0.21 + cell.y * 0.13) * 0.5 + sin(cell.x * 0.07 - cell.y * 0.17) * 0.5
	return color.lightened(wave * strength) if wave > 0.0 else color.darkened(-wave * strength)


## A clump of canopy filling the tile: lit on the top-left, shaded on the bottom-right.
func _canopy(image: Image, corner: Vector2i, cell: Vector2i, tones: Array[Color]) -> void:
	var shift: int = posmod(cell.x * 7 + cell.y * 3, 2)
	for y: int in SCALE:
		for x: int in SCALE:
			var dx: float = x + 0.5 - 2.0 - shift * 0.5
			var dy: float = y + 0.5 - 2.0
			if dx * dx + dy * dy > 4.2:
				continue
			var tone: Color = tones[1]
			if dx + dy < -1.2:
				tone = tones[0]
			elif dx + dy > 1.2:
				tone = tones[2]
			image.set_pixelv(corner + Vector2i(x, y), tone)
	if World.terrain(cell + Vector2i.DOWN) not in ["T", "D", "P"]:
		image.set_pixelv(corner + Vector2i(2, SCALE - 1), tones[3])


## Rock and mountain: grey, lit where open ground lies to the north or west, shaded to the south or east.
func _ridge(image: Image, corner: Vector2i, cell: Vector2i) -> void:
	_fill(image, corner, _vary(ROCK[1], cell, 0.05))
	var rocky: Callable = func(side: Vector2i) -> bool: return World.terrain(cell + side) in ["C", "L", "R"]
	if not rocky.call(Vector2i.UP):
		_edge(image, corner, Vector2i.UP, ROCK[0])
	if not rocky.call(Vector2i.LEFT):
		_edge(image, corner, Vector2i.LEFT, ROCK[0])
	if not rocky.call(Vector2i.DOWN):
		_edge(image, corner, Vector2i.DOWN, ROCK[2])
	if not rocky.call(Vector2i.RIGHT):
		_edge(image, corner, Vector2i.RIGHT, ROCK[2])


## A roof: terracotta, with a lit ridge row and a dark edge where the building ends.
func _roof(image: Image, corner: Vector2i, cell: Vector2i) -> void:
	var index: int = World.ROOF_AT[cell]
	var tones: Array[Color] = SNOW_ROOF if Biomes.in_isles(cell) else ROOF
	for y: int in SCALE:
		for x: int in SCALE:
			image.set_pixelv(corner + Vector2i(x, y), tones[1] if (y + corner.y) % 3 else tones[0])
	for side: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
		if World.ROOF_AT.get(cell + side, -1) != index:
			_edge(image, corner, side, tones[2])


## One pixel row or column along a tile's side.
func _edge(image: Image, corner: Vector2i, side: Vector2i, color: Color) -> void:
	for step: int in SCALE:
		var at: Vector2i = Vector2i(step, 0 if side == Vector2i.UP else SCALE - 1) if side.y != 0 \
			else Vector2i(0 if side == Vector2i.LEFT else SCALE - 1, step)
		image.set_pixelv(corner + at, color)


## Tiles to the nearest land within `limit` (0 when there is none that close).
static func _distance_to_land(cell: Vector2i, limit: int) -> int:
	for radius: int in range(1, limit + 1):
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) == radius and World.terrain(cell + Vector2i(dx, dy)) not in ["~", "", " "]:
					return radius
	return 0
