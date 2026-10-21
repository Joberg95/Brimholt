extends RefCounted
## Pitched roofs for town buildings (World.BUILDINGS), rasterized once per building from the
## material swatches in roofs.png (make_sprites.py roof_swatches: near slope, far slope, timber
## gable, trim). The eaves sit on the thin walls' masonry bands; the ridge runs east-west and
## rises with the same up-left lean as the walls (less steep), so the lit south slope, a sliver
## of the shaded north slope, and the east gable show. The eave throws a soft shadow below.

const World = preload("res://game/core/world.gd")
const Biomes = preload("res://game/data/biomes.gd")
const TILE: int = 32
## The castle town: its houses all wear slate (material 1), like its castle wall.
const SLATE_TOWN: String = "Reedmere"
const SWATCH: int = 32
## Roof materials in roofs.png: clay, slate, and shingle are spread over the towns; the fourth,
## snow over shingle, roofs every building in the frost isles (Biomes.ISLES); the fifth, sand
## plaster, roofs Sunreach's (Biomes.SUNREACH) almost flat (FLAT_PITCH) and without chimneys.
const MATERIALS: int = 5
const TOWN_MATERIALS: int = 3
const SNOW_MATERIAL: int = 3
const PLASTER_MATERIAL: int = 4
const FLAT_PITCH: float = 0.07
## A house wall's band top face, relative to its cell corner: centre +-5, raised RAISE px up-left
## (SpriteArt.HOUSE_RAISE, a full tile). The band's centre is half a tile in, so the roof is drawn
## RAISE - TILE / 2 px up and left of the band's place on the ground.
const BAND_HALF: int = 5
const RAISE: int = 32
const OVERHANG: int = 2
## Ridge height as a share of the roof's depth, and how far height leans left (walls lean 1:1).
const PITCH: float = 0.26
const LEAN: float = 0.5
const STRIP_WIDTH: int = 512
## The near slope is lit toward the ridge and shaded toward the eave: SHADES bands, brightest first.
const SHADES: Array[float] = [1.1, 1.03, 0.96, 0.88]
const SHADOW_ROWS: int = 5

static var _strips: Array = []


## {texture, origin (map pixels)} for a building {rect, ...}.
static func build(building: Dictionary, sheet: Texture2D) -> Dictionary:
	if _strips.is_empty():
		_load_strips(sheet)
	var rect: Rect2i = building["rect"]
	var material: int = posmod(rect.position.x * 7 + rect.position.y * 13, TOWN_MATERIALS)
	if World.zone_at(rect.position).get("name", "") == SLATE_TOWN:
		material = 1
	elif Biomes.in_isles(rect.position):
		material = SNOW_MATERIAL
	elif Biomes.in_sunreach(rect.position):
		material = PLASTER_MATERIAL
	var far: Image = _strips[material][1]
	var gable: Image = _strips[material][2]
	var trim: Image = _strips[material][3]
	var x0: int = rect.position.x * TILE - BAND_HALF - OVERHANG
	var x1: int = (rect.end.x - 1) * TILE + BAND_HALF + OVERHANG
	var y_n: int = rect.position.y * TILE - BAND_HALF - OVERHANG
	var y_s: int = (rect.end.y - 1) * TILE + BAND_HALF + OVERHANG + 1
	var depth: int = y_s - y_n
	var height: int = roundi(depth * (FLAT_PITCH if material == PLASTER_MATERIAL else PITCH))
	var y_r: int = roundi((y_n + y_s) / 2.0) - height
	var lean: int = roundi(height * LEAN)
	var origin := Vector2i(x0 - lean - 1, mini(y_n, y_r) - 3)
	var image := Image.create(x1 - origin.x + 2, y_s + SHADOW_ROWS + 1 - origin.y, false, Image.FORMAT_RGBA8)
	var outline: Color = trim.get_pixel(0, 12)
	var deep: Color = trim.get_pixel(1, 0)
	# Rows from the ridge down: the near slope; rows from the north eave to the ridge: the far slope.
	for y: int in range(mini(y_n, y_r), y_s + 1):
		var on_near: bool = y >= y_r
		var t: float = float(y_s - y) / float(y_s - y_r) if on_near else float(y - y_n) / float(maxi(1, y_r - y_n))
		if not on_near and y_r <= y_n:
			continue
		var shift: int = -roundi(lean * clampf(t, 0.0, 1.0))
		var left: int = x0 + shift
		var right: int = x1 + shift
		var row: int = y - origin.y
		var source: Image = _strips[material][4 + mini(SHADES.size() - 1, floori((1.0 - t) * SHADES.size()))] if on_near else far
		var v: int = posmod(y - (y_s if on_near else y_n), SWATCH)
		image.blit_rect(source, Rect2i(0, v, right - left, 1), Vector2i(left - origin.x, row))
		# The east gable fills from the slope's edge out to the east eave line.
		if right < x1:
			image.blit_rect(gable, Rect2i(posmod(right, SWATCH), posmod(y, SWATCH), x1 - right, 1), Vector2i(right - origin.x, row))
			image.set_pixel(right - origin.x, row, deep)
			image.set_pixel(right + 1 - origin.x, row, deep)
		image.set_pixel(left - origin.x, row, outline)
		image.set_pixel(x1 - origin.x, row, outline)
	# Ridge cap along the top of the near slope, eave board along its foot, a dark north eave.
	for offset: int in 6:
		image.blit_rect(trim, Rect2i(0, offset, x1 - x0, 1), Vector2i(x0 - lean - origin.x, y_r - 2 + offset - origin.y))
	for offset: int in 5:
		image.blit_rect(trim, Rect2i(0, 8 + offset, x1 - x0, 1), Vector2i(x0 - origin.x, y_s - 4 + offset - origin.y))
	if y_r > y_n:
		for x: int in range(x0, x1 + 1):
			image.set_pixel(x - origin.x, y_n - origin.y, outline)
	# The gable's barge boards meet under the ridge's east end.
	for y: int in range(y_r, y_s + 1):
		var t: float = float(y_s - y) / float(y_s - y_r)
		image.set_pixel(x1 - roundi(lean * t) - origin.x, y - origin.y, outline)
	if hash(rect.position) % 2 == 0 and material != PLASTER_MATERIAL:
		_chimney(image, trim, Vector2i(x0 + roundi((x1 - x0) * 0.68) - roundi(lean * 0.8) - origin.x, y_r + 4 - origin.y), outline)
	for row: int in SHADOW_ROWS:
		image.fill_rect(Rect2i(x0 + 1 - origin.x, y_s + 1 + row - origin.y, x1 - x0 - 1, 1),
			Color(0, 0, 0, 0.32 * (1.0 - float(row) / SHADOW_ROWS)))
	return {"texture": ImageTexture.create_from_image(image), "origin": Vector2(origin) - Vector2.ONE * (RAISE - TILE / 2)}


## A stone chimney standing on the near slope just below the ridge: a lit front, a shaded
## east side, and a dark capped flue.
static func _chimney(image: Image, trim: Image, foot: Vector2i, outline: Color) -> void:
	var top := Vector2i(foot.x, foot.y - 20)
	image.blit_rect(trim, Rect2i(0, 16, 9, 16), top + Vector2i(0, 4))
	image.blit_rect(trim, Rect2i(9, 16, 3, 16), top + Vector2i(9, 4))
	image.fill_rect(Rect2i(top + Vector2i(9, 4), Vector2i(3, 16)), image.get_pixelv(top + Vector2i(9, 6)).darkened(0.35))
	image.fill_rect(Rect2i(top + Vector2i(-1, 0), Vector2i(14, 4)), trim.get_pixel(0, 20).darkened(0.1))
	image.fill_rect(Rect2i(top + Vector2i(2, 1), Vector2i(8, 2)), Color("#1c1a18"))
	for y: int in range(top.y - 1, foot.y + 1):
		image.set_pixel(top.x - 2, y, outline)
		image.set_pixel(top.x + 13, y, outline)
	for x: int in range(top.x - 2, top.x + 14):
		image.set_pixel(x, top.y - 1, outline)


## Each swatch tiled into a wide strip, so a roof row is one blit starting at column 0; the
## near slope also in SHADES (strips 4.. by brightness).
static func _load_strips(sheet: Texture2D) -> void:
	var source: Image = sheet.get_image()
	source.convert(Image.FORMAT_RGBA8)
	for material: int in MATERIALS:
		var strips: Array = []
		for swatch: int in 4:
			var strip := Image.create(STRIP_WIDTH, SWATCH, false, Image.FORMAT_RGBA8)
			for x: int in range(0, STRIP_WIDTH, SWATCH):
				strip.blit_rect(source, Rect2i(swatch * SWATCH, material * SWATCH, SWATCH, SWATCH), Vector2i(x, 0))
			strips.append(strip)
		for shade: float in SHADES:
			var tinted := Image.create(SWATCH, SWATCH, false, Image.FORMAT_RGBA8)
			for y: int in SWATCH:
				for x: int in SWATCH:
					var color: Color = source.get_pixel(x, material * SWATCH + y)
					tinted.set_pixel(x, y, Color(color.r * shade, color.g * shade, color.b * shade, color.a))
			var strip := Image.create(STRIP_WIDTH, SWATCH, false, Image.FORMAT_RGBA8)
			for x: int in range(0, STRIP_WIDTH, SWATCH):
				strip.blit_rect(tinted, Rect2i(0, 0, SWATCH, SWATCH), Vector2i(x, 0))
			strips.append(strip)
		_strips.append(strips)
