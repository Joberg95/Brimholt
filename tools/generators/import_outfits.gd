extends SceneTree
## Imports painted outfit art (art/outfits/manifest.json) into game sprite sheets:
## assets/sprites/outfits/<id>.png (64x64 frames, POSE_COLUMNS poses by down/up/left/right, feet
## at y=53 like the generated layers) and assets/sprites/icons/<item>.png (32x32 icons).
##
## A source is a sheet of figures on a flat or textured background; figures are found by separating
## them from the region's border colour, so loose layouts work. Each outfit names a "figures"
## region and the facings in it ("order"):
## - "layout": "strip" (default): one standing figure per facing, left to right. Steps bob the
##   figure a pixel and attacks lean it toward its facing.
## - "layout": "grid": one row per facing (top to bottom), each with the five poses left to right:
##   stand, step A, step B, wind-up, strike.
## A missing left or right facing is mirrored from the other. One scale fits the whole outfit: the
## first figure is scaled to "figure_height". An optional "icons" region holds item icons left to
## right, mapped to "icon_items" (null skips one).
## godot --headless --path . --script res://tools/generators/import_outfits.gd [-- --debug=path.png]

const MANIFEST: String = "res://art/outfits/manifest.json"
const FRAME: int = 64
const ICON: int = 32
const DIRECTIONS: Array[String] = ["down", "up", "left", "right"]
## stand, step A, step B, wind-up, strike: (bob up, lean toward the facing) in pixels.
const POSES: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 2)]
const FEET_Y: int = 53
const OUTLINE: Color = Color("#1c1612")
## A pixel is background when its colour is this close (RGB distance) to the region's border.
const BACKGROUND_TOLERANCE: float = 0.13
## Components smaller than this many source pixels are specks.
const MIN_AREA: int = 150

var _debug: Image


func _initialize() -> void:
	var debug_path: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--debug="):
			debug_path = argument.trim_prefix("--debug=")
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if typeof(manifest) != TYPE_DICTIONARY:
		push_error("%s did not parse" % MANIFEST)
		quit(1)
		return
	var height: int = int(manifest.get("figure_height", 40))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sprites/outfits"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sprites/icons"))
	var outfits: Array = manifest["outfits"]
	_debug = Image.create(FRAME * 4 + ICON * 6, FRAME * outfits.size(), false, Image.FORMAT_RGBA8)
	_debug.fill(Color("#3a4a2e"))
	var sources: Dictionary = {}
	var failed: int = 0
	for index: int in outfits.size():
		var outfit: Dictionary = outfits[index]
		var file: String = "res://art/outfits/" + String(outfit["file"])
		if not sources.has(file):
			var loaded := Image.load_from_file(file)
			if loaded == null:
				push_error("Cannot read %s" % file)
				quit(1)
				return
			loaded.convert(Image.FORMAT_RGBA8)
			sources[file] = loaded
		var source: Image = sources[file]
		var order: Array = outfit["order"]
		var grid: bool = outfit.get("layout", "strip") == "grid"
		var region: Rect2i = _rect(outfit["figures"])
		# facing -> its pose frames (one standing frame for strips, POSES.size() for grids).
		var found: Dictionary = {}
		var scale: float = 0.0
		var complete: bool = true
		for row: int in order.size() if grid else 1:
			var band: Rect2i = region
			if grid:
				band = Rect2i(region.position.x, region.position.y + region.size.y * row / order.size(), region.size.x,
					region.size.y / order.size())
			var wanted: int = POSES.size() if grid else order.size()
			var figures: Array[Image] = _figures(source, band, wanted)
			if figures.size() != wanted:
				push_error("%s: found %d figures, expected %d" % [outfit["id"], figures.size(), wanted])
				complete = false
				break
			if scale == 0.0:
				scale = float(height) / figures[0].get_used_rect().size.y
			if grid:
				found[order[row]] = figures.map(func(figure: Image) -> Image: return _fit(figure, scale, FRAME))
			else:
				for facing: int in figures.size():
					found[order[facing]] = [_fit(figures[facing], scale, FRAME)]
		if not complete:
			failed += 1
			continue
		for pair: Array in [["right", "left"], ["left", "right"]]:
			if not found.has(pair[0]) and found.has(pair[1]):
				found[pair[0]] = found[pair[1]].map(_mirrored)
		var sheet := Image.create(FRAME * POSES.size(), FRAME * DIRECTIONS.size(), false, Image.FORMAT_RGBA8)
		for row: int in DIRECTIONS.size():
			var direction: String = DIRECTIONS[row]
			var frames: Array = found[direction]
			var lean: Vector2i = {"down": Vector2i(0, 1), "up": Vector2i(0, -1), "left": Vector2i(-1, 0),
				"right": Vector2i(1, 0)}[direction]
			for column: int in POSES.size():
				var offset: Vector2i = Vector2i.ZERO
				if frames.size() == 1:
					offset = Vector2i(0, -POSES[column].x) + lean * POSES[column].y
				sheet.blit_rect(frames[mini(column, frames.size() - 1)], Rect2i(Vector2i.ZERO, Vector2i(FRAME, FRAME)),
					Vector2i(column * FRAME, row * FRAME) + offset)
			_debug.blit_rect(frames[0], Rect2i(0, 0, FRAME, FRAME), Vector2i(row * FRAME, index * FRAME))
		var path: String = "res://assets/sprites/outfits/%s.png" % outfit["id"]
		sheet.save_png(path)
		print("wrote %s" % path)
		if outfit.has("icons"):
			var items: Array = outfit["icon_items"]
			var icons: Array[Image] = _figures(source, _rect(outfit["icons"]), items.size(), true)
			if icons.size() != items.size():
				push_error("%s: found %d icons, expected %d" % [outfit["id"], icons.size(), items.size()])
				failed += 1
				continue
			for slot: int in items.size():
				var used: Vector2i = icons[slot].get_used_rect().size
				var icon: Image = _fit(icons[slot], float(ICON - 4) / maxi(used.x, used.y), ICON, true)
				_debug.blit_rect(icon, Rect2i(0, 0, ICON, ICON), Vector2i(FRAME * 4 + slot * ICON, index * FRAME + 16))
				if items[slot] != null:
					icon.save_png("res://assets/sprites/icons/%s.png" % items[slot])
	if not debug_path.is_empty():
		_debug.save_png(debug_path)
		print("wrote %s" % debug_path)
	quit(1 if failed > 0 else 0)


func _rect(values: Array) -> Rect2i:
	return Rect2i(int(values[0]), int(values[1]), int(values[2]), int(values[3]))


## The `count` largest figures in `region`, left to right, each cropped with the background
## made transparent. Icons sit in framed boxes: their frames are cut away first.
func _figures(source: Image, region: Rect2i, count: int, framed: bool = false) -> Array[Image]:
	var image: Image = source.get_region(region)
	var mask: PackedByteArray = _foreground(image)
	var w: int = image.get_width()
	var h: int = image.get_height()
	var label := PackedInt32Array()
	label.resize(w * h)
	var boxes: Array[Rect2i] = []
	var areas: Array[int] = []
	for start: int in w * h:
		if mask[start] == 0 or label[start] != 0:
			continue
		var stack: Array[int] = [start]
		label[start] = boxes.size() + 1
		var lo := Vector2i(start % w, start / w)
		var hi := lo
		var area: int = 0
		while not stack.is_empty():
			var at: int = stack.pop_back()
			var p := Vector2i(at % w, at / w)
			lo = lo.min(p)
			hi = hi.max(p)
			area += 1
			# Joined across small gaps so a figure's loose parts (horns, cape tips) stay one.
			for dy: int in range(-3, 4):
				for dx: int in range(-3, 4):
					var q := p + Vector2i(dx, dy)
					if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and mask[q.y * w + q.x] == 1 and label[q.y * w + q.x] == 0:
						label[q.y * w + q.x] = boxes.size() + 1
						stack.append(q.y * w + q.x)
		boxes.append(Rect2i(lo, hi - lo + Vector2i.ONE))
		areas.append(area)
	var order: Array = range(boxes.size()).filter(func(i: int) -> bool: return areas[i] >= MIN_AREA)
	order.sort_custom(func(a: int, b: int) -> bool: return areas[a] > areas[b])
	order = order.slice(0, count)
	order.sort_custom(func(a: int, b: int) -> bool: return boxes[a].position.x < boxes[b].position.x)
	var result: Array[Image] = []
	for i: int in order:
		var box: Rect2i = boxes[i]
		if framed:
			# Inside the drawn frame the icon sits on its own background: separate it again.
			var inner: Image = image.get_region(box.grow(-5))
			var inner_mask: PackedByteArray = _foreground(inner)
			for at: int in inner_mask.size():
				if inner_mask[at] == 0:
					inner.set_pixel(at % inner.get_width(), at / inner.get_width(), Color(0, 0, 0, 0))
			result.append(inner)
			continue
		var cut := Image.create(box.size.x, box.size.y, false, Image.FORMAT_RGBA8)
		for y: int in box.size.y:
			for x: int in box.size.x:
				if label[(box.position.y + y) * w + box.position.x + x] == i + 1:
					cut.set_pixel(x, y, image.get_pixel(box.position.x + x, box.position.y + y))
		result.append(cut)
	return result


## 1 where a pixel differs from the region's border colour; holes inside a figure are filled.
func _foreground(image: Image) -> PackedByteArray:
	var w: int = image.get_width()
	var h: int = image.get_height()
	var border: Array[Color] = []
	for x: int in w:
		border.append(image.get_pixel(x, 0))
		border.append(image.get_pixel(x, h - 1))
	for y: int in h:
		border.append(image.get_pixel(0, y))
		border.append(image.get_pixel(w - 1, y))
	# The most common border colour (coarsely binned), so a figure touching the edge does not skew it.
	var bins: Dictionary = {}
	for color: Color in border:
		var key: int = int(color.r * 8.0) * 100 + int(color.g * 8.0) * 10 + int(color.b * 8.0)
		var bin: Array = bins.get(key, [Color(0, 0, 0, 0), 0])
		bins[key] = [bin[0] + color, bin[1] + 1]
	var best: Array = [Color(0, 0, 0, 0), 0]
	for bin: Array in bins.values():
		if bin[1] > best[1]:
			best = bin
	var background: Color = best[0] / float(best[1])
	var mask := PackedByteArray()
	mask.resize(w * h)
	for y: int in h:
		for x: int in w:
			var c: Color = image.get_pixel(x, y)
			var d: float = Vector3(c.r - background.r, c.g - background.g, c.b - background.b).length()
			mask[y * w + x] = 1 if d > BACKGROUND_TOLERANCE else 0
	# Background is what the border reaches through non-figure pixels; everything else is figure.
	var outside := PackedByteArray()
	outside.resize(w * h)
	var stack: Array[int] = []
	for x: int in w:
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y: int in h:
		stack.append(y * w)
		stack.append(y * w + w - 1)
	while not stack.is_empty():
		var at: int = stack.pop_back()
		if outside[at] == 1 or mask[at] == 1:
			continue
		outside[at] = 1
		var x: int = at % w
		var y: int = at / w
		if x > 0: stack.append(at - 1)
		if x < w - 1: stack.append(at + 1)
		if y > 0: stack.append(at - w)
		if y < h - 1: stack.append(at + w)
	for at: int in w * h:
		mask[at] = 0 if outside[at] == 1 else 1
	return mask


## Scales a figure by `factor`, sharpens its edge with an outline, and places it in a size x size
## frame: feet on FEET_Y for figures, centred for icons.
func _fit(figure: Image, factor: float, size: int, centred: bool = false) -> Image:
	var used: Rect2i = figure.get_used_rect()
	var part: Image = figure.get_region(used)
	var w: int = clampi(roundi(part.get_width() * factor), 1, size)
	var h: int = clampi(roundi(part.get_height() * factor), 1, FEET_Y + 1)
	# Transparent pixels take the outline colour so downscaling darkens edges instead of fading them.
	for y: int in part.get_height():
		for x: int in part.get_width():
			if part.get_pixel(x, y).a < 0.5:
				part.set_pixel(x, y, Color(OUTLINE, 0.0))
	part.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var frame := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var origin := Vector2i((size - w) / 2, (size - h) / 2) if centred else Vector2i(size / 2 - w / 2, FEET_Y + 1 - h)
	for y: int in h:
		for x: int in w:
			var c: Color = part.get_pixel(x, y)
			if c.a >= 0.45:
				frame.set_pixel(origin.x + x, origin.y + y, Color(_crisp(c), 1.0))
	var outlined: Image = frame.duplicate()
	for y: int in size:
		for x: int in size:
			if frame.get_pixel(x, y).a > 0.0:
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q := Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < size and q.y < size and frame.get_pixel(q.x, q.y).a > 0.0:
					outlined.set_pixel(x, y, OUTLINE)
					break
	return outlined


## A little more contrast and saturation: downscaled paintings read flat at sprite size.
func _crisp(c: Color) -> Color:
	var result := Color.from_hsv(c.h, clampf(c.s * 1.12, 0.0, 1.0), clampf((c.v - 0.5) * 1.1 + 0.5, 0.0, 1.0))
	return result


func _mirrored(frame: Image) -> Image:
	var result: Image = frame.duplicate()
	result.flip_x()
	return result
