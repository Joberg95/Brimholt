extends SceneTree
## Bakes the painted world map in pages (game/data/atlas.gd: one PNG per sector near painted land,
## Atlas.MAP_SCALE pixels per cell, map tile = world cell) from the map, in the art direction's
## map look, in the OpenTibia pack's colours (plan 49): blue sea with lighter shallows and a pale line
## of surf, green land with soft painted variation, forests as clumps of canopy lit from the top-left,
## grey ridges with a lit and a shaded side, sandy plains and desert, dark brown for the Hollow Reach,
## and towns as red roofs on paved streets inside their walls. The game tints PvP zones and draws the
## markers on top (game/ui/world_maps.gd). Each page's terrain hash (WorldMap.page_hash) goes to
## pages.json: only pages whose terrain changed are painted again (FORCE=1 paints them all), and
## the rules check notices a page edited since the last bake. overview.png, the whole overworld
## at one pixel per cell for zooming far out, is shrunk from the pages.
##
##   godot --headless --path . --script res://tools/generators/world_map.gd [-- --force]

const World = preload("res://game/core/world.gd")
const WorldMap = preload("res://game/world_map/world_map.gd")
const Atlas = preload("res://game/data/atlas.gd")
const Biomes = preload("res://game/data/biomes.gd")
const SCALE: int = Atlas.MAP_SCALE

const SEA_DEEP: Color = Color("#1468b8")
const SEA_SHALLOW: Color = Color("#1f8fe0")
const SURF: Color = Color("#c8dce4")
const GRASS: Color = Color("#3d7a1c")
const FOREST: Array[Color] = [Color("#6a8a2c"), Color("#3d5a19"), Color("#2a3a12"), Color("#1a240a")]
## The Hollow Reach's dead trees.
const DEAD_FOREST: Array[Color] = [Color("#6a4a3a"), Color("#4a2e26"), Color("#36201c"), Color("#1e1210")]
const DIRT: Color = Color("#6a4a30")
const SAND: Color = Color("#c9a25a")
const DUSK: Color = Color("#4f5e18")
const BOG: Color = Color("#5c5420")
const MUSHROOM_CAPS: Array[Color] = [Color("#9a7a3a"), Color("#71561d"), Color("#5a4214"), Color("#302208")]
const OBSIDIAN: Color = Color("#392c22")
const ROCK: Array[Color] = [Color("#a9aa9f"), Color("#919287"), Color("#5e5f57")]
const STREET: Color = Color("#7a7684")
const WALL: Color = Color("#575454")
const ROOF: Array[Color] = [Color("#c04a2c"), Color("#a4381b"), Color("#6e2414")]
const TOWN_GROUND: Color = Color("#a89a7a")
const BRIDGE: Color = Color("#875d3d")
const STAIRS: Color = Color("#20180e")
## The frost isles: snowfields, snow-laden fir woods, log walls, and snowed roofs.
const SNOW: Color = Color("#dbe2ec")
const FIRS: Array[Color] = [Color("#f7fcff"), Color("#2f6743"), Color("#1b4333"), Color("#0b211e")]
const LOG_WALL: Color = Color("#6f472f")
const SNOW_ROOF: Array[Color] = [Color("#f7fcff"), Color("#dbe2ec"), Color("#96a0bc")]
## Sunreach's (Biomes.SUNREACH) sandstone walls and flat sand-plaster roofs.
const SAND_WALL: Color = Color("#a0825e")
const SAND_ROOF: Array[Color] = [Color("#edd8a6"), Color("#d0b88a"), Color("#896a4c")]

## The page being painted's first pixel on the whole map: pixel patterns run on across pages.
var _page_pixel: Vector2i = Vector2i.ZERO


func _initialize() -> void:
	var force: bool = "--force" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(Atlas.MAP_DIR)
	var old: Dictionary = {}
	if FileAccess.file_exists(Atlas.MAP_META):
		var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(Atlas.MAP_META))
		if typeof(meta) == TYPE_DICTIONARY and int(meta.get("scale", 0)) == SCALE and typeof(meta.get("pages")) == TYPE_DICTIONARY:
			old = meta["pages"]
	var pages: Dictionary = {}
	var painted: int = 0
	var error: Error = OK
	for sector: Vector2i in WorldMap.map_pages():
		var key: String = "%d_%d" % [sector.x, sector.y]
		var digest: String = WorldMap.page_hash(sector)
		pages[key] = digest
		if not force and old.get(key, "") == digest and FileAccess.file_exists(Atlas.page_path(sector)):
			continue
		var image := Image.create(Atlas.SECTOR * SCALE, Atlas.SECTOR * SCALE, false, Image.FORMAT_RGB8)
		var origin: Vector2i = Atlas.sector_rect(sector).position
		_page_pixel = origin * SCALE
		for y: int in Atlas.SECTOR:
			for x: int in Atlas.SECTOR:
				_paint_tile(image, origin + Vector2i(x, y), Vector2i(x, y) * SCALE)
		var saved: Error = image.save_png(ProjectSettings.globalize_path(Atlas.page_path(sector)))
		error = saved if saved != OK else error
		painted += 1
	# Pages no longer near any land go.
	for file: String in DirAccess.get_files_at(Atlas.MAP_DIR):
		var parts: PackedStringArray = file.get_slice(".", 0).split("_")
		if parts.size() == 2 and file.get_extension() in ["png", "import"] and not pages.has("%s_%s" % [parts[0], parts[1]]):
			DirAccess.remove_absolute(Atlas.MAP_DIR.path_join(file))
	if painted > 0 or force or not FileAccess.file_exists(Atlas.MAP_OVERVIEW) or old.size() != pages.size():
		var saved: Error = _overview(pages.keys()).save_png(ProjectSettings.globalize_path(Atlas.MAP_OVERVIEW))
		error = saved if saved != OK else error
	var meta_file := FileAccess.open(Atlas.MAP_META, FileAccess.WRITE)
	meta_file.store_string(JSON.stringify({"scale": SCALE, "pages": pages}, "  ", true) + "
")
	meta_file.close()
	print("Baked the world map: painted %d of %d pages into %s (%s)" % [painted, pages.size(), Atlas.MAP_DIR, error_string(error)])
	quit(0 if error == OK else 1)


## The whole overworld at one pixel per cell: open sea, with every page shrunk onto it.
static func _overview(keys: Array) -> Image:
	var image := Image.create(Atlas.OVERWORLD_SIZE.x, Atlas.OVERWORLD_SIZE.y, false, Image.FORMAT_RGB8)
	image.fill(SEA_DEEP)
	for key: String in keys:
		var sector := Vector2i(int(key.get_slice("_", 0)), int(key.get_slice("_", 1)))
		var page: Image = Image.load_from_file(ProjectSettings.globalize_path(Atlas.page_path(sector)))
		page.convert(Image.FORMAT_RGB8)
		page.resize(Atlas.SECTOR, Atlas.SECTOR, Image.INTERPOLATE_CUBIC)
		image.blit_rect(page, Rect2i(Vector2i.ZERO, page.get_size()), Atlas.sector_rect(sector).position)
	return image


func _paint_tile(image: Image, cell: Vector2i, corner: Vector2i) -> void:
	var tile: String = WorldMap.terrain(cell)
	match tile:
		"~":
			var shore: int = _distance_to_land(cell, 3)
			# Open sea is one flat blue, the same the map draws where no page is needed, so the
			# pages end without a seam; shallows near land get the soft variation.
			var water: Color = SEA_DEEP.lerp(SEA_SHALLOW, clampf(1.0 - (shore - 1) / 2.5, 0.0, 1.0)) if shore > 0 else SEA_DEEP
			_fill(image, corner, _vary(water, cell, 0.03) if shore > 0 else water)
			if shore == 1:
				# Surf along the shore, on the side facing the land.
				for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					if WorldMap.terrain(cell + side) not in ["~", "b", ""]:
						_edge(image, corner, side, SURF)
		"T", "D":
			_fill(image, corner, _vary(FOREST[2] if tile == "T" else DEAD_FOREST[2], cell, 0.05))
			_canopy(image, corner, cell, FOREST if tile == "T" else DEAD_FOREST)
		"C", "L", "R":
			_ridge(image, corner, cell)
		"#", "W":
			_fill(image, corner, LOG_WALL if Biomes.in_isles(cell) else SAND_WALL if Biomes.in_sunreach(cell) else WALL)
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
			var ground: Color = TOWN_GROUND if WorldMap.zone_at(cell).get("town", false) else GRASS
			_fill(image, corner, _vary(ground, cell, 0.06))
	if WorldMap.ROOF_AT.has(cell):
		_roof(image, corner, cell)


## A flat tile with a little texture: each pixel a shade lighter or darker by a fixed hash.
func _fill(image: Image, corner: Vector2i, color: Color) -> void:
	for y: int in SCALE:
		for x: int in SCALE:
			var jitter: float = float(posmod((_page_pixel.x + corner.x + x) * 73 + (_page_pixel.y + corner.y + y) * 151, 17)) / 17.0 - 0.5
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
	if WorldMap.terrain(cell + Vector2i.DOWN) not in ["T", "D", "P"]:
		image.set_pixelv(corner + Vector2i(2, SCALE - 1), tones[3])


## Rock and mountain: grey, lit where open ground lies to the north or west, shaded to the south or east.
func _ridge(image: Image, corner: Vector2i, cell: Vector2i) -> void:
	_fill(image, corner, _vary(ROCK[1], cell, 0.05))
	var rocky: Callable = func(side: Vector2i) -> bool: return WorldMap.terrain(cell + side) in ["C", "L", "R"]
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
	var index: int = WorldMap.ROOF_AT[cell]
	var tones: Array[Color] = SNOW_ROOF if Biomes.in_isles(cell) else SAND_ROOF if Biomes.in_sunreach(cell) else ROOF
	for y: int in SCALE:
		for x: int in SCALE:
			image.set_pixelv(corner + Vector2i(x, y), tones[1] if (y + corner.y + _page_pixel.y) % 3 else tones[0])
	for side: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
		if WorldMap.ROOF_AT.get(cell + side, -1) != index:
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
				if maxi(absi(dx), absi(dy)) == radius and WorldMap.terrain(cell + Vector2i(dx, dy)) not in ["~", "", " "]:
					return radius
	return 0
