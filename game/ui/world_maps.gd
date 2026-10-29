extends Node
## The minimap under the stat sheet and the full world map over the game window, drawn from
## the painted map pages (game/data/atlas.gd, baked by tools/generators/world_map.gd: one page per
## sector near land, loaded as you look around; a flat one-pixel-per-tile page where the bake is
## older than the map) with PvP zones tinted red. Far out, the world map draws the small overview
## instead. Map tile = world cell. You are an arrow pointing the way you face; gold rings mark
## where your tasks send you (World.task_targets), and the minimap's edge points toward your first
## task when it lies off the minimap. The world map opens centred on you at OPEN_ZOOM pixels per
## tile; the mouse wheel (or + and −) zooms around the cursor, dragging pans (over the painted
## land and a margin of sea), and its key, Esc, or Close closes it. Quest givers show their
## "!"/"?" marks. The floor buttons (or Page Up and Page Down) step through the floors that have
## anything painted (Atlas.FLOOR_X, WorldMap.floor_bounds), each drawn in the same tiles as the
## surface over or under it: one pixel per tile, the zones' names, and the ways up and down. It
## opens on the floor you stand on, and the minimap names your floor off the surface. Right-click the world map to place your own marker (an icon and a
## label) or remove one; markers are kept on this computer (marker_file), as Tibia keeps its
## minimap markers, and show on the world map and the minimap on their own floor.

const World = preload("res://game/core/world.gd")
const WorldMap = preload("res://game/world_map/world_map.gd")
const Layout = preload("res://game/ui/layout.gd")
const Dungeons = preload("res://game/data/dungeons.gd")
const Atlas = preload("res://game/data/atlas.gd")
const SELF_COLOR: Color = Color("#ffd04a")
const GUIDE_COLOR: Color = Color("#ffd84a")
const MINIMAP_SCALE: float = 2.0
## World map zoom in pixels per tile: it opens at OPEN_ZOOM; each wheel step multiplies by
## ZOOM_STEP, between the whole painted world fitting the window and MAX_ZOOM. Below
## OVERVIEW_ZOOM it draws the overview (one pixel per tile) instead of the pages.
const OPEN_ZOOM: float = 3.0
const MAX_ZOOM: float = 10.0
const ZOOM_STEP: float = 1.25
const OVERVIEW_ZOOM: float = 2.0
## Open sea shown round the painted land, in tiles.
const SEA_MARGIN: int = 32
## Pages kept loaded; the ones looked at longest ago go first.
const MAX_PAGES: int = 40
## Space above the map for the help line and buttons.
const HEADER: float = 34.0
## Region names on the world map: muted parchment, under the brighter town and zone labels.
const REGION_TINT: Color = Color("#d8c89a")
const PVP_TINT: Color = Color("#c43c32")
## The baked map's open sea (tools/generators/world_map.gd), drawn where no page is needed.
const SEA: Color = Color("#2a5680")
## Map markers: ferrymen teal, quest givers gold, vendors green, bankers pale blue, artisans amber, wardens red.
const TOWNSFOLK_COLORS: Dictionary = {"vendor": Color("#9fe07a"), "banker": Color("#a8c8ff"), "artisan": Color("#e8a85a"),
	"warden": Color("#e0605a")}
const MAP_COLORS: Dictionary = {
	".": Color("#4e693b"), ",": Color("#a08a6a"), "~": Color("#2d5a78"), "#": Color("#9196a0"),
	"T": Color("#26401f"), ":": Color("#d8c48a"), "=": Color("#b0aca4"), "b": Color("#8a5a34"),
	"d": Color("#3a2c4a"), "o": Color("#2c2438"), "O": Color("#6a5a88"), "D": Color("#1e1626"),
	"c": Color("#5a534c"), "C": Color("#85766a"), "W": Color("#b3aa98"), "v": Color("#f0d070"), "^": Color("#f0d070"),
	"K": Color("#7c8450"),
	"R": Color("#8a8478"),
	"L": Color("#6a6250"),
	"m": Color("#4a4632"), "U": Color("#4e7a6c"),
	"s": Color("#e2e9f0"), "P": Color("#3e5e48"),
}

var game: Node
var minimap: Control
var world_map: Control
## Loaded pages: sector -> {image, texture, texel (pixels per tile)}, and the order they were
## last drawn in (oldest first).
var _pages: Dictionary = {}
var _page_order: Array[Vector2i] = []
## Sectors that need a page (WorldMap.map_pages), and each baked page's hash (pages.json).
var _needed: Dictionary = {}
var _baked: Dictionary = {}
var _overview: ImageTexture
## Off the overworld (dungeons, caves, the Void Throne): a flat map of the area you are in.
var _flat_area: Rect2i = Rect2i()
var _flat_texture: ImageTexture
## The floor the world map shows (0 the surface, -1 the floor below, 1 the one above), and the
## map of each floor off the surface, made the first time it is shown.
var shown_floor: int = 0
var _floor_textures: Dictionary = {}
var _floor_label: Label
## Your markers: {cell (a world cell, either floor), icon (MARKER_ICONS), label}, saved to
## marker_file; and the menu that places or removes one.
var markers: Array = []
var marker_file: String = "user://map_markers.json"
var _marker_menu: PopupPanel
var _marker_name: LineEdit
var _marker_remove: Button
var _marker_cell: Vector2i
const MARKER_ICONS: Dictionary = {"star": Color("#ffd84a"), "flag": Color("#e0503a"), "cross": Color("#f2f0e6"),
	"skull": Color("#c8c0b0"), "coin": Color("#e8b040"), "heart": Color("#e06a8a")}
const MARKER_LABEL_LENGTH: int = 40
## Pixels per tile, and the tile at the centre of the map area.
var zoom: float = OPEN_ZOOM
var center: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _warned: bool = false


func build(game_node: Node, layer: CanvasLayer) -> void:
	game = game_node
	for sector: Vector2i in WorldMap.map_pages():
		_needed[sector] = true
	if FileAccess.file_exists(Atlas.MAP_META):
		var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(Atlas.MAP_META))
		if typeof(meta) == TYPE_DICTIONARY and typeof(meta.get("pages")) == TYPE_DICTIONARY:
			_baked = meta["pages"]
	_build_controls(layer)
	load_markers()


## Reads your markers from marker_file (none if it is missing or unreadable).
func load_markers() -> void:
	markers.clear()
	if not FileAccess.file_exists(marker_file):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(marker_file))
	if typeof(parsed) != TYPE_ARRAY:
		return
	for entry: Variant in parsed:
		if typeof(entry) == TYPE_DICTIONARY and typeof(entry.get("cell")) == TYPE_ARRAY and (entry["cell"] as Array).size() == 2 \
				and MARKER_ICONS.has(entry.get("icon", "")):
			markers.append({"cell": Vector2i(int(entry["cell"][0]), int(entry["cell"][1])), "icon": String(entry["icon"]),
				"label": String(entry.get("label", "")).left(MARKER_LABEL_LENGTH)})


func _save_markers() -> void:
	var file: FileAccess = FileAccess.open(marker_file, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save map markers to %s" % marker_file)
		return
	file.store_string(JSON.stringify(markers.map(func(marker: Dictionary) -> Dictionary:
		return {"cell": [marker["cell"].x, marker["cell"].y], "icon": marker["icon"], "label": marker["label"]})))


## Places a marker at a world cell (replacing one already there) and saves.
func add_marker(cell: Vector2i, icon: String, label: String) -> void:
	if not MARKER_ICONS.has(icon):
		return
	remove_marker(cell, false)
	markers.append({"cell": cell, "icon": icon, "label": label.strip_edges().left(MARKER_LABEL_LENGTH)})
	_save_markers()
	redraw()


## Removes the marker at a world cell, if any (and saves unless told not to).
func remove_marker(cell: Vector2i, save: bool = true) -> void:
	var before: int = markers.size()
	markers = markers.filter(func(marker: Dictionary) -> bool: return marker["cell"] != cell)
	if save and markers.size() != before:
		_save_markers()
		redraw()


## The world cell under a point of the world map window, on the floor it shows.
func cell_at(point: Vector2) -> Vector2i:
	var tile: Vector2 = center + (point - _map_area().get_center()) / zoom
	return Vector2i(tile.floor()) + Vector2i(Atlas.FLOOR_X[shown_floor], 0)


## Right-click on the world map: the marker menu for the cell there (or the marker within a few
## pixels of it, to rename or remove).
func _open_marker_menu(point: Vector2) -> void:
	_marker_cell = cell_at(point)
	var reach: float = maxf(1.0, 6.0 / zoom)
	for marker: Dictionary in markers:
		var at: Vector2 = _marker_at(Vector2(marker["cell"]), Vector2.ZERO, 1.0, true)
		var tile: Vector2 = center + (point - _map_area().get_center()) / zoom
		if at.distance_to(tile) <= reach + 0.5:
			_marker_cell = marker["cell"]
	var existing: Array = markers.filter(func(marker: Dictionary) -> bool: return marker["cell"] == _marker_cell)
	_marker_name.text = existing[0]["label"] if not existing.is_empty() else ""
	_marker_remove.visible = not existing.is_empty()
	_marker_menu.popup(Rect2i(Vector2i(world_map.get_screen_position() + point), Vector2i.ZERO))
	_marker_name.grab_focus()


func _build_marker_menu() -> void:
	_marker_menu = PopupPanel.new()
	var column := VBoxContainer.new()
	_marker_menu.add_child(column)
	var title := Label.new()
	title.text = "Map marker"
	column.add_child(title)
	_marker_name = LineEdit.new()
	_marker_name.placeholder_text = "Label (optional)"
	_marker_name.max_length = MARKER_LABEL_LENGTH
	_marker_name.custom_minimum_size = Vector2(200, 0)
	column.add_child(_marker_name)
	var icons := HBoxContainer.new()
	column.add_child(icons)
	for icon: String in MARKER_ICONS:
		var button := Button.new()
		button.tooltip_text = icon.capitalize()
		button.custom_minimum_size = Vector2(30, 30)
		button.focus_mode = Control.FOCUS_NONE
		button.draw.connect(func() -> void: _draw_marker_icon(button, button.size / 2.0, icon, 7.0))
		button.pressed.connect(func() -> void:
			add_marker(_marker_cell, icon, _marker_name.text)
			_marker_menu.hide())
		icons.add_child(button)
	_marker_remove = Button.new()
	_marker_remove.text = "Remove marker"
	_marker_remove.focus_mode = Control.FOCUS_NONE
	_marker_remove.pressed.connect(func() -> void:
		remove_marker(_marker_cell)
		_marker_menu.hide())
	column.add_child(_marker_remove)
	world_map.add_child(_marker_menu)


## A marker's icon, `size` pixels from its centre to its tips, with a dark outline.
func _draw_marker_icon(canvas: CanvasItem, at: Vector2, icon: String, size: float) -> void:
	var color: Color = MARKER_ICONS[icon]
	var dark := Color("#1a140a")
	match icon:
		"star":
			var points := PackedVector2Array()
			for k: int in 10:
				var angle: float = -PI / 2.0 + k * PI / 5.0
				points.append(at + Vector2(cos(angle), sin(angle)) * (size if k % 2 == 0 else size * 0.45))
			canvas.draw_colored_polygon(points, color)
			points.append(points[0])
			canvas.draw_polyline(points, dark, 1.0)
		"flag":
			canvas.draw_line(at + Vector2(-size * 0.5, size), at + Vector2(-size * 0.5, -size), dark, 2.0)
			var cloth := PackedVector2Array([at + Vector2(-size * 0.4, -size), at + Vector2(size, -size * 0.5), at + Vector2(-size * 0.4, 0)])
			canvas.draw_colored_polygon(cloth, color)
			cloth.append(cloth[0])
			canvas.draw_polyline(cloth, dark, 1.0)
		"cross":
			for ends: Array in [[Vector2(-1, -1), Vector2(1, 1)], [Vector2(1, -1), Vector2(-1, 1)]]:
				canvas.draw_line(at + ends[0] * size * 0.8, at + ends[1] * size * 0.8, dark, 4.0)
				canvas.draw_line(at + ends[0] * size * 0.8, at + ends[1] * size * 0.8, color, 2.0)
		"skull":
			canvas.draw_circle(at + Vector2(0, -size * 0.15), size * 0.8, dark)
			canvas.draw_circle(at + Vector2(0, -size * 0.15), size * 0.65, color)
			canvas.draw_rect(Rect2(at + Vector2(-size * 0.4, size * 0.3), Vector2(size * 0.8, size * 0.5)), color)
			for side: float in [-1.0, 1.0]:
				canvas.draw_circle(at + Vector2(side * size * 0.28, -size * 0.2), size * 0.18, dark)
		"heart":
			for side: float in [-1.0, 1.0]:
				canvas.draw_circle(at + Vector2(side * size * 0.4, -size * 0.25), size * 0.5, color)
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-size * 0.88, -size * 0.1),
				at + Vector2(size * 0.88, -size * 0.1), at + Vector2(0, size * 0.9)]), color)
		_:
			canvas.draw_circle(at, size * 0.85, dark)
			canvas.draw_circle(at, size * 0.7, color)
			canvas.draw_circle(at, size * 0.35, color.darkened(0.25))


## Your markers on a canvas (on the world map, those on the floor it shows, with their labels).
func _draw_player_markers(canvas: Control, origin: Vector2, scale: float, area: Rect2, folded: bool) -> void:
	var font: Font = ThemeDB.fallback_font
	for marker: Dictionary in markers:
		var at: Vector2 = _marker_at(Vector2(marker["cell"]), origin, scale, folded)
		if not area.grow(8.0).has_point(at):
			continue
		_draw_marker_icon(canvas, at, marker["icon"], 6.0 if canvas == world_map else 4.0)
		if canvas == world_map and not String(marker["label"]).is_empty():
			_draw_label(font, at, marker["label"], 12, Color("#f4ecd8"), Vector2(0, 18), true)


## A page: the bake if it matches the map (WorldMap.page_hash), else a flat one; PvP zones tinted.
## {} for sectors that are open sea.
func _page(sector: Vector2i) -> Dictionary:
	if not _needed.has(sector):
		return {}
	if _pages.has(sector):
		_page_order.erase(sector)
		_page_order.append(sector)
		return _pages[sector]
	var area: Rect2i = Atlas.sector_rect(sector)
	var image: Image = null
	if _baked.get("%d_%d" % [sector.x, sector.y], "") == WorldMap.page_hash(sector):
		image = _load_image(Atlas.page_path(sector))
	if image == null:
		_warn_stale()
		image = _flat(area)
	var texel: int = image.get_width() / Atlas.SECTOR
	_tint_pvp(image, area, texel)
	var page: Dictionary = {"image": image, "texture": ImageTexture.create_from_image(image), "texel": texel}
	_pages[sector] = page
	_page_order.append(sector)
	while _page_order.size() > MAX_PAGES:
		_pages.erase(_page_order.pop_front())
	return page


func _warn_stale() -> void:
	if not _warned:
		_warned = true
		push_warning("The painted world map is older than the map; run make world-map. Showing flat pages.")


## The overview: the whole overworld at one pixel per tile, from the bake (flat where it is stale).
func _overview_texture() -> ImageTexture:
	if _overview != null:
		return _overview
	var image: Image = _load_image(Atlas.MAP_OVERVIEW)
	var stale: bool = image == null or image.get_size() != Atlas.OVERWORLD_SIZE
	for sector: Vector2i in _needed:
		if stale:
			break
		stale = _baked.get("%d_%d" % [sector.x, sector.y], "") != WorldMap.page_hash(sector)
	if stale:
		_warn_stale()
		image = Image.create(Atlas.OVERWORLD_SIZE.x, Atlas.OVERWORLD_SIZE.y, false, Image.FORMAT_RGB8)
		image.fill(SEA)
		image.blit_rect(_flat(WorldMap.PAINTED), Rect2i(Vector2i.ZERO, WorldMap.PAINTED.size), WorldMap.PAINTED.position)
	_tint_pvp(image, WorldMap.OVERWORLD, 1)
	_overview = ImageTexture.create_from_image(image)
	return _overview


## An imported (or, before the editor imported it, raw) PNG as RGB8, or null.
static func _load_image(path: String) -> Image:
	var image: Image = null
	if ResourceLoader.exists(path):
		image = (load(path) as Texture2D).get_image()
	elif FileAccess.file_exists(path):
		image = Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null:
		return null
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGB8)
	return image


## Reddens the land of PvP zones inside `area` on an image of it (`texel` pixels per tile).
static func _tint_pvp(image: Image, area: Rect2i, texel: int) -> void:
	for zone: Dictionary in WorldMap.ZONES:
		if not zone["pvp"]:
			continue
		var tinted: Rect2i = zone["rect"].intersection(area).intersection(WorldMap.OVERWORLD)
		for y: int in range(tinted.position.y, tinted.end.y):
			for x: int in range(tinted.position.x, tinted.end.x):
				if WorldMap.terrain(Vector2i(x, y)) in ["~", " "]:
					continue
				var corner := (Vector2i(x, y) - area.position) * texel
				for py: int in texel:
					for px: int in texel:
						var at := corner + Vector2i(px, py)
						image.set_pixelv(at, image.get_pixelv(at).lerp(PVP_TINT, 0.45))


## One pixel per tile in MAP_COLORS: the fallback for stale pages, and the map off the overworld.
static func _flat(area: Rect2i) -> Image:
	# Terrain byte -> RGB, then one pass over raw bytes (far faster than set_pixel per tile).
	var lookup := PackedByteArray()
	lookup.resize(128 * 3)
	for terrain: String in MAP_COLORS:
		var color: Color = MAP_COLORS[terrain]
		var at: int = terrain.unicode_at(0) * 3
		lookup[at] = color.r8
		lookup[at + 1] = color.g8
		lookup[at + 2] = color.b8
	var inside: Rect2i = area.intersection(Rect2i(Vector2i.ZERO, WorldMap.GRID_SIZE))
	var pixels := PackedByteArray()
	pixels.resize(area.size.x * area.size.y * 3)
	for y: int in range(inside.position.y, inside.end.y):
		var row: int = y * WorldMap.GRID_SIZE.x
		var base: int = ((y - area.position.y) * area.size.x - area.position.x) * 3
		for x: int in range(inside.position.x, inside.end.x):
			var source: int = (WorldMap.GRID[row + x] & 127) * 3
			pixels[base + x * 3] = lookup[source]
			pixels[base + x * 3 + 1] = lookup[source + 1]
			pixels[base + x * 3 + 2] = lookup[source + 2]
	return Image.create_from_data(area.size.x, area.size.y, false, Image.FORMAT_RGB8, pixels)


## The map's colour at a (fractional) tile, as the pages draw it (the visual test reads it).
func color_at(tile: Vector2) -> Color:
	var sector: Vector2i = Atlas.sector_of(Vector2i(tile.floor()))
	var page: Dictionary = _page(sector)
	if page.is_empty():
		return SEA
	var local: Vector2 = tile - Vector2(Atlas.sector_rect(sector).position)
	return (page["image"] as Image).get_pixelv(Vector2i(local * float(page["texel"])))


## Draws the overworld's terrain inside `tiles` onto `canvas`, `origin` being where tile (0, 0)
## lands and `scale` pixels per tile: the pages, or the overview when `far`.
func _draw_terrain(canvas: Control, origin: Vector2, scale: float, tiles: Rect2, far: bool) -> void:
	tiles = tiles.intersection(Rect2(WorldMap.OVERWORLD))
	if not tiles.has_area():
		return
	if far:
		canvas.draw_texture_rect_region(_overview_texture(), Rect2(origin + tiles.position * scale, tiles.size * scale), tiles)
		return
	var cells := Rect2i(Vector2i(tiles.position.floor()), Vector2i(tiles.end.ceil()) - Vector2i(tiles.position.floor()))
	for sector: Vector2i in Atlas.sectors_in(cells):
		var whole := Rect2(Atlas.sector_rect(sector))
		var part: Rect2 = whole.intersection(tiles)
		if not part.has_area():
			continue
		var target := Rect2(origin + part.position * scale, part.size * scale)
		var page: Dictionary = _page(sector)
		if page.is_empty():
			canvas.draw_rect(target, SEA)
			continue
		var texel: float = page["texel"]
		canvas.draw_texture_rect_region(page["texture"], target, Rect2((part.position - whole.position) * texel, part.size * texel))


## The flat map of an area off the overworld (your dungeon copy, a cave, the arena).
func _flat_map_of(area: Rect2i) -> ImageTexture:
	if area != _flat_area or _flat_texture == null:
		_flat_area = area
		_flat_texture = ImageTexture.create_from_image(_flat(area))
	return _flat_texture


## What the world map shows: the painted land and a margin of sea round it.
static func bounds() -> Rect2:
	return Rect2(WorldMap.PAINTED.grow(SEA_MARGIN).intersection(WorldMap.OVERWORLD))


func _build_controls(layer: CanvasLayer) -> void:
	minimap = Control.new()
	minimap.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	minimap.position = Layout.PANEL_ORIGIN + Vector2(0, 578)
	minimap.size = Vector2(184, 102)
	minimap.clip_contents = true
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.draw.connect(_draw_minimap)
	layer.add_child(minimap)
	world_map = Control.new()
	world_map.position = Layout.VIEW_ORIGIN
	world_map.size = Layout.VIEW_SIZE
	world_map.clip_contents = true
	world_map.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	world_map.visible = false
	world_map.draw.connect(_draw_world_map)
	world_map.gui_input.connect(_world_map_input)
	world_map.visibility_changed.connect(func() -> void:
		if world_map.visible:
			zoom = maxf(OPEN_ZOOM, _fit_zoom())
			# Underground (dungeon copies lie outside the overworld) it opens on the painted world's centre.
			var here: Vector2 = game.camera.focus() / World.TILE_SIZE
			var level: int = Atlas.floor_of(Vector2i(here))
			if level != Atlas.NO_FLOOR:
				here -= Vector2(Atlas.FLOOR_X[level], 0)
			center = here if WorldMap.OVERWORLD.has_point(Vector2i(here)) else bounds().get_center()
			_show_floor(level if level != Atlas.NO_FLOOR else 0)
			_clamp_view())
	layer.add_child(world_map)
	var buttons := HBoxContainer.new()
	buttons.position = Vector2(Layout.VIEW_SIZE.x - 300, 4)
	world_map.add_child(buttons)
	_floor_label = Label.new()
	_floor_label.custom_minimum_size = Vector2(84, 0)
	_floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buttons.add_child(_floor_label)
	for entry: Array in [["▲", func() -> void: _step_floor(1)], ["▼", func() -> void: _step_floor(-1)],
			["−", func() -> void: zoom_by(1.0 / ZOOM_STEP, _map_area().get_center())],
			["+", func() -> void: zoom_by(ZOOM_STEP, _map_area().get_center())], ["Close", world_map.hide]]:
		var button := Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(32, 0)
		button.pressed.connect(entry[1])
		buttons.add_child(button)
	_build_marker_menu()


## The floors the world map can show, top first: the surface and every floor with anything painted.
static func mapped_floors() -> Array[int]:
	var found: Array[int] = []
	for level: int in range(Atlas.TOP, Atlas.BOTTOM - 1, -1):
		if level == 0 or WorldMap.floor_bounds(level).has_area():
			found.append(level)
	return found


## Shows floor `level` (the nearest mapped floor to it).
func _show_floor(level: int) -> void:
	var floors: Array[int] = mapped_floors()
	shown_floor = 0
	for candidate: int in floors:
		if absi(candidate - level) < absi(shown_floor - level):
			shown_floor = candidate
	_floor_label.text = Atlas.floor_name(shown_floor)
	world_map.queue_redraw()


## One mapped floor up (1) or down (-1) from the one shown.
func _step_floor(direction: int) -> void:
	var floors: Array[int] = mapped_floors()
	var at: int = floors.find(shown_floor)
	_show_floor(floors[clampi(at - direction, 0, floors.size() - 1)])


## A floor off the surface at one pixel per tile, over its painted part.
func _floor_texture(level: int) -> ImageTexture:
	if not _floor_textures.has(level) and WorldMap.floor_bounds(level).has_area():
		_floor_textures[level] = ImageTexture.create_from_image(_flat(WorldMap.floor_bounds(level)))
	return _floor_textures.get(level)


## The part of the world map window that shows the map (below the header).
func _map_area() -> Rect2:
	return Rect2(Vector2(0, HEADER), Layout.VIEW_SIZE - Vector2(0, HEADER))


## The zoom at which the whole painted world fits the map area.
func _fit_zoom() -> float:
	var area: Vector2 = _map_area().size
	return minf(area.x / bounds().size.x, area.y / bounds().size.y)


## Where a (fractional) tile appears on the world map window at the current zoom and pan.
func map_point(tile: Vector2) -> Vector2:
	return _map_area().get_center() + (tile - center) * zoom


## Zooms by `factor`, keeping the tile under `at` (a world map position) where it is.
func zoom_by(factor: float, at: Vector2) -> void:
	var under: Vector2 = center + (at - _map_area().get_center()) / zoom
	zoom = clampf(zoom * factor, _fit_zoom(), MAX_ZOOM)
	center = under - (at - _map_area().get_center()) / zoom
	_clamp_view()
	world_map.queue_redraw()


## Keeps the painted world on screen: centred when it is smaller than the window, else edge to edge.
func _clamp_view() -> void:
	var half: Vector2 = _map_area().size / 2.0 / zoom
	var shown: Rect2 = bounds()
	for axis: int in 2:
		if half[axis] * 2.0 >= shown.size[axis]:
			center[axis] = shown.get_center()[axis]
		else:
			center[axis] = clampf(center[axis], shown.position[axis] + half[axis], shown.end[axis] - half[axis])


func _world_map_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		_step_floor(1 if event.keycode == KEY_PAGEUP else -1)
		world_map.accept_event()
	elif event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					zoom_by(ZOOM_STEP, event.position)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					zoom_by(1.0 / ZOOM_STEP, event.position)
			MOUSE_BUTTON_RIGHT:
				if event.pressed:
					_open_marker_menu(event.position)
			MOUSE_BUTTON_LEFT:
				_dragging = event.pressed
				world_map.mouse_default_cursor_shape = Control.CURSOR_DRAG if _dragging else Control.CURSOR_ARROW
		world_map.accept_event()
	elif event is InputEventMouseMotion and _dragging:
		center -= event.relative / zoom
		_clamp_view()
		world_map.queue_redraw()
		world_map.accept_event()
	elif event is InputEventMagnifyGesture:
		zoom_by(event.factor, event.position)
	elif event is InputEventPanGesture:
		center += event.delta * 8.0 / zoom
		_clamp_view()
		world_map.queue_redraw()


func redraw() -> void:
	minimap.queue_redraw()
	if world_map.visible:
		world_map.queue_redraw()


## Draws a label centred on `at` (plus `shift`) and returns the rectangle it covers.
func _draw_label(font: Font, at: Vector2, text: String, size: int, color: Color, shift: Vector2, outlined: bool) -> Rect2:
	var width: float = font.get_string_size(text, 0, -1, size).x
	var corner: Vector2 = at + shift - Vector2(width / 2.0, 0)
	if outlined:
		world_map.draw_string_outline(font, corner, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color.BLACK)
	world_map.draw_string(font, corner, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	return Rect2(corner - Vector2(2, size), Vector2(width + 4, size + 4))


## Where a cell's marker lands on a canvas. The world map (`folded`) draws each floor in the tiles
## of the surface and leaves out what lies on the other floors (Vector2.INF, outside every area).
func _marker_at(cell: Vector2, origin: Vector2, scale: float, folded: bool) -> Vector2:
	if folded:
		var level: int = Atlas.floor_of(Vector2i(cell))
		if level != shown_floor:
			return Vector2.INF
		cell -= Vector2(Atlas.FLOOR_X[level], 0)
	return origin + (cell + Vector2(0.5, 0.5)) * scale


func _draw_markers(canvas: Control, origin: Vector2, scale: float, area: Rect2, folded: bool = false) -> void:
	for id: String in WorldMap.FERRYMEN:
		var at: Vector2 = _marker_at(Vector2(WorldMap.FERRYMEN[id]["cell"]), origin, scale, folded)
		if area.has_point(at):
			canvas.draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), Color("#7fe0d0"))
	for id: String in WorldMap.QUEST_GIVERS:
		var at: Vector2 = _marker_at(Vector2(WorldMap.QUEST_GIVERS[id]["cell"]), origin, scale, folded)
		if area.has_point(at):
			canvas.draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), Color("#ffcf6a"))
	# Ways down and up: stairways, cave mouths, and the holes, ladders, and stairs between the floors.
	for cell: Vector2i in WorldMap.DUNGEON_ENTRANCES.keys() + WorldMap.CAVE_MOUTHS.keys() + WorldMap.HOLES.keys():
		var at: Vector2 = _marker_at(Vector2(cell), origin, scale, folded)
		if area.has_point(at):
			canvas.draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), Color("#c9884a"))
	for id: String in WorldMap.TOWNSFOLK:
		var at: Vector2 = _marker_at(Vector2(WorldMap.TOWNSFOLK[id]["cell"]), origin, scale, folded)
		if area.has_point(at):
			canvas.draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), TOWNSFOLK_COLORS[WorldMap.TOWNSFOLK[id]["role"]])
	var actors: Dictionary = game.client.actors
	for id: int in actors:
		var at: Vector2 = _marker_at(actors[id]["visual"], origin, scale, folded)
		if id != game.client.self_id and area.has_point(at):
			canvas.draw_rect(Rect2(at - Vector2.ONE * 1.5, Vector2.ONE * 3.0), Color.WHITE)
	if actors.has(game.client.self_id):
		var me: Dictionary = actors[game.client.self_id]
		var at: Vector2 = _marker_at(me["visual"], origin, scale, folded)
		if area.has_point(at):
			_draw_self(canvas, at, Vector2(me["state"].get("facing", Vector2i.DOWN)), 6.0 if canvas == world_map else 5.0)


## You: a gold arrow with a dark outline pointing the way you face, in a softly pulsing ring.
func _draw_self(canvas: Control, at: Vector2, facing: Vector2, size: float) -> void:
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0)
	canvas.draw_arc(at, size + 2.0 + pulse * 2.0, 0.0, TAU, 20, Color(SELF_COLOR, 0.35 + 0.3 * pulse), 1.5)
	var ahead: Vector2 = facing.normalized() if facing != Vector2.ZERO else Vector2.DOWN
	var side := Vector2(-ahead.y, ahead.x)
	var points := PackedVector2Array([at + ahead * size, at - ahead * size * 0.6 + side * size * 0.75,
		at - ahead * size * 0.25, at - ahead * size * 0.6 - side * size * 0.75])
	canvas.draw_colored_polygon(points, SELF_COLOR)
	points.append(points[0])
	canvas.draw_polyline(points, Color("#1a140a"), 1.0)


## Gold rings where your tasks send you (World.task_targets); on the minimap, an arrow at its
## edge toward the nearest place for your first task when none of them is on it.
func _draw_guidance(canvas: Control, origin: Vector2, scale: float, area: Rect2) -> void:
	if not game.client.actors.has(game.client.self_id):
		return
	var state: Dictionary = game.client.actors[game.client.self_id]["state"]
	var tasks: Array = state.get("tasks", {}).keys()
	tasks.sort()
	var radius: float = maxf(4.0, 2.5 * scale)
	var first: Array[Vector2] = []
	for index: int in tasks.size():
		for cell: Vector2i in World.task_targets(tasks[index], state):
			var at: Vector2 = origin + (Vector2(cell) + Vector2(0.5, 0.5)) * scale
			if index == 0:
				first.append(at)
			if area.grow(radius).has_point(at):
				canvas.draw_circle(at, radius, Color(GUIDE_COLOR, 0.16))
				canvas.draw_arc(at, radius, 0.0, TAU, 24, Color(GUIDE_COLOR, 0.85 if index == 0 else 0.45), 1.5)
	if canvas != minimap or first.is_empty() or first.any(func(at: Vector2) -> bool: return area.has_point(at)):
		return
	var centre: Vector2 = area.get_center()
	var nearest: Vector2 = first[0]
	for at: Vector2 in first:
		if at.distance_to(centre) < nearest.distance_to(centre):
			nearest = at
	var toward: Vector2 = (nearest - centre).normalized()
	var reach_x: float = absf((area.size.x / 2.0 - 7.0) / toward.x) if toward.x != 0.0 else INF
	var reach_y: float = absf((area.size.y / 2.0 - 7.0) / toward.y) if toward.y != 0.0 else INF
	var tip: Vector2 = centre + toward * minf(reach_x, reach_y)
	var side := Vector2(-toward.y, toward.x)
	canvas.draw_colored_polygon(PackedVector2Array([tip + toward * 5.0, tip - toward * 3.0 + side * 4.0,
		tip - toward * 3.0 - side * 4.0]), GUIDE_COLOR)


func _draw_minimap() -> void:
	var view := Rect2(Vector2.ZERO, minimap.size)
	minimap.draw_rect(view, Color.BLACK)
	var tiles: Vector2 = minimap.size / MINIMAP_SCALE
	var focus: Vector2 = game.camera.focus()
	var cell := Vector2i(focus / World.TILE_SIZE)
	var region := Rect2(focus / World.TILE_SIZE - tiles / 2.0, tiles)
	var origin: Vector2 = -region.position * MINIMAP_SCALE
	var away: bool = not WorldMap.OVERWORLD.has_point(cell)
	if away:
		# Off the overworld (a dungeon copy, a cave, the Void Throne): the flat map of the area you
		# are in only, never the copies next to it.
		var area: Rect2i = WorldMap.zone_at(cell).get("rect", Rect2i(cell - Vector2i(64, 64), Vector2i(128, 128)))
		var visible: Rect2 = region.intersection(Rect2(area))
		if visible.has_area():
			minimap.draw_texture_rect_region(_flat_map_of(area), Rect2(origin + visible.position * MINIMAP_SCALE,
				visible.size * MINIMAP_SCALE), Rect2(visible.position - Vector2(area.position), visible.size))
	else:
		_draw_terrain(minimap, origin, MINIMAP_SCALE, region, false)
		_draw_guidance(minimap, origin, MINIMAP_SCALE, view)
	_draw_markers(minimap, origin, MINIMAP_SCALE, view)
	_draw_player_markers(minimap, origin, MINIMAP_SCALE, view, false)
	var level: int = Atlas.floor_of(cell)
	if level != 0 and level != Atlas.NO_FLOOR:
		var font: Font = ThemeDB.fallback_font
		minimap.draw_string_outline(font, Vector2(4, 13), Atlas.floor_name(level), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color.BLACK)
		minimap.draw_string(font, Vector2(4, 13), Atlas.floor_name(level), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#f0d070"))
	minimap.draw_rect(view, Color("#3a4450"), false, 1.0)


func _draw_world_map() -> void:
	var view_size: Vector2 = Layout.VIEW_SIZE
	# The overworld only: dungeon copies are reached by stairways.
	var scale: float = zoom
	var origin: Vector2 = map_point(Vector2.ZERO).round()
	world_map.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.03, 0.04, 0.05))
	var painted: Rect2 = bounds()
	var shown := Rect2(origin + painted.position * scale, painted.size * scale).intersection(_map_area())
	var tiles := Rect2((shown.position - origin) / scale, shown.size / scale)
	var font: Font = ThemeDB.fallback_font
	if shown_floor != 0:
		_draw_other_floor(origin, scale, shown, font)
		_draw_header(font)
		return
	_draw_terrain(world_map, origin, scale, tiles, zoom < OVERVIEW_ZOOM)
	_draw_guidance(world_map, origin, scale, shown)
	_draw_markers(world_map, origin, scale, shown, true)
	_draw_player_markers(world_map, origin, scale, shown, true)
	_draw_quest_marks(origin, scale, shown)
	var labels: Array = [[World.WORLD_NAME, Vector2(WorldMap.SPAWNS[0]) + Vector2(4, -3)]]
	for id: String in WorldMap.FERRYMEN:
		var place: String = WorldMap.FERRYMEN[id]["place"]
		if WorldMap.zone_at(WorldMap.FERRYMEN[id]["cell"]).get("name", "") != place:
			labels.append([place, Vector2(WorldMap.FERRYMEN[id]["cell"]) + Vector2(0, -3)])
	for dungeon: String in WorldMap.ENTRANCE_OF:
		labels.append([Dungeons.DUNGEONS[dungeon]["name"], Vector2(WorldMap.ENTRANCE_OF[dungeon]) + Vector2(0, 4), Color("#e0a870")])
	for cave: String in WorldMap.MOUTH_OF:
		labels.append([World.Caves.CAVES[cave]["name"], Vector2(WorldMap.MOUTH_OF[cave]) + Vector2(0, 4), Color("#e0a870")])
	# Named regions first, so towns and ports draw over them where they meet.
	for region: String in WorldMap.REGION_NAMES:
		var info: Dictionary = WorldMap.REGION_INFO[region]
		if info["max_level"] == 0:
			continue
		var centre := Vector2(info["centre"])
		labels.append([region.to_upper(), centre, REGION_TINT, 12])
		labels.append(["levels %d–%d" % [info["min_level"], info["max_level"]], centre, REGION_TINT, 11])
	for zone: Dictionary in WorldMap.ZONES:
		if zone.get("underground", false):
			continue
		var text: String = zone["name"] if zone["town"] else "%s (%s, level %d-%d)" % [zone["name"],
			"PvP" if zone["pvp"] else "safe", zone["min_level"], zone["max_level"]]
		labels.append([text, Vector2(zone["rect"].get_center().x, zone["rect"].end.y + 3),
			Color("#9fe0a0") if zone["town"] else PVP_TINT.lightened(0.35)])
	# Place and town labels first, where they belong; region labels (and their level line) then
	# step up or down until they clear everything already placed.
	var taken: Array[Rect2] = []
	var regions: Array = labels.filter(func(label: Array) -> bool: return label.size() > 3)
	var fixed: Array = labels.filter(func(label: Array) -> bool: return label.size() <= 3)
	for label: Array in fixed:
		taken.append(_draw_label(font, origin + label[1] * scale, label[0], 13, label[2] if label.size() > 2 else Color("#f4ecd8"), Vector2.ZERO, true))
	for index: int in range(0, regions.size(), 2):
		var title: Array = regions[index]
		var levels: Array = regions[index + 1]
		var at: Vector2 = origin + title[1] * scale
		var block := Rect2(at - Vector2(70, 12), Vector2(140, 28))
		var shift := Vector2.ZERO
		for step: Vector2 in [Vector2.ZERO, Vector2(0, -18), Vector2(0, 18), Vector2(0, -36), Vector2(0, 36), Vector2(-60, 0),
				Vector2(60, 0), Vector2(0, -54), Vector2(0, 54), Vector2(-60, -24), Vector2(60, -24), Vector2(-60, 24), Vector2(60, 24)]:
			shift = step
			if not taken.any(func(rect: Rect2) -> bool: return rect.intersects(Rect2(block.position + shift, block.size))):
				break
		taken.append(_draw_label(font, at, title[0], title[3], title[2], shift, true))
		taken.append(_draw_label(font, at + Vector2(0, 13), levels[0], levels[3], levels[2], shift, true))
	_draw_header(font)


func _draw_header(font: Font) -> void:
	world_map.draw_rect(Rect2(Vector2.ZERO, Vector2(Layout.VIEW_SIZE.x, HEADER)), Color(0.03, 0.04, 0.05))
	world_map.draw_string(font, Vector2(12, 22), "Rings: tasks · orange: ways down · red: PvP · right-click: marker",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#dfe4ea"))


## A floor off the surface: black where nothing is painted, the rest in the tiles of the surface
## over or under it, its zones' names and levels, the ways up and down, and you when you are there.
func _draw_other_floor(origin: Vector2, scale: float, shown: Rect2, font: Font) -> void:
	world_map.draw_rect(shown, Color.BLACK)
	var texture: ImageTexture = _floor_texture(shown_floor)
	if texture == null:
		return
	var shift := Vector2i(Atlas.FLOOR_X[shown_floor], 0)
	var area: Rect2i = WorldMap.floor_bounds(shown_floor)
	var above := Rect2(Vector2(area.position - shift), Vector2(area.size))
	var visible: Rect2 = Rect2((shown.position - origin) / scale, shown.size / scale).intersection(above)
	if visible.has_area():
		world_map.draw_texture_rect_region(texture, Rect2(origin + visible.position * scale, visible.size * scale),
			Rect2(visible.position - above.position, visible.size))
	_draw_markers(world_map, origin, scale, shown, true)
	_draw_player_markers(world_map, origin, scale, shown, true)
	for zone: Dictionary in WorldMap.ZONES:
		if WorldMap.floor_of_rect(zone["rect"]) != shown_floor:
			continue
		var at: Vector2 = origin + Vector2(zone["rect"].get_center() - shift) * scale
		if shown.has_point(at):
			_draw_label(font, at, zone["name"], 13, Color("#e0a870"), Vector2.ZERO, true)
			_draw_label(font, at, "levels %d–%d" % [zone["min_level"], zone["max_level"]], 11, REGION_TINT, Vector2(0, 13), true)


## Gold "!" and "?" over quest givers that have something for you (World.quest_mark).
func _draw_quest_marks(origin: Vector2, scale: float, area: Rect2) -> void:
	if not game.client.actors.has(game.client.self_id):
		return
	var state: Dictionary = game.client.actors[game.client.self_id]["state"]
	var font: Font = ThemeDB.fallback_font
	for id: String in WorldMap.QUEST_GIVERS:
		var mark: String = World.quest_mark(id, state)
		var at: Vector2 = origin + (Vector2(WorldMap.QUEST_GIVERS[id]["cell"]) + Vector2(0.5, 0.5)) * scale
		if mark.is_empty() or not area.has_point(at):
			continue
		var corner: Vector2 = at + Vector2(-4, -5)
		world_map.draw_string_outline(font, corner, mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color.BLACK)
		world_map.draw_string(font, corner, mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#ffd84a"))
