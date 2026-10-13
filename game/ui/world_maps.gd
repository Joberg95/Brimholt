extends Node
## The minimap under the stat sheet and the full world map over the game window (toggled
## by its key, closed by a click), drawn from one terrain texture with PvP zones tinted red.

const World = preload("res://game/core/world.gd")
const Layout = preload("res://game/ui/layout.gd")
const Dungeons = preload("res://game/data/dungeons.gd")
const MINIMAP_SCALE: float = 2.0
const PVP_TINT: Color = Color("#c43c32")
## Map markers: ferrymen teal, quest givers gold, vendors green, bankers pale blue.
const TOWNSFOLK_COLORS: Dictionary = {"vendor": Color("#9fe07a"), "banker": Color("#a8c8ff")}
const MAP_COLORS: Dictionary = {
	".": Color("#4e693b"), ",": Color("#a08a6a"), "~": Color("#2d5a78"), "#": Color("#9196a0"),
	"T": Color("#26401f"), ":": Color("#d8c48a"), "=": Color("#b0aca4"), "b": Color("#8a5a34"),
	"d": Color("#3a2c4a"), "o": Color("#2c2438"), "O": Color("#6a5a88"), "D": Color("#1e1626"),
	"c": Color("#5a534c"), "C": Color("#85766a"), "v": Color("#f0d070"), "^": Color("#f0d070"),
	"K": Color("#7c8450"),
}

var game: Node
var minimap: Control
var world_map: Control
var _texture: ImageTexture


func build(game_node: Node, layer: CanvasLayer) -> void:
	game = game_node
	# Terrain byte -> RGB, then one pass over raw bytes (far faster than set_pixel per tile).
	var lookup := PackedByteArray()
	lookup.resize(128 * 3)
	for terrain: String in MAP_COLORS:
		var color: Color = MAP_COLORS[terrain]
		var at: int = terrain.unicode_at(0) * 3
		lookup[at] = color.r8
		lookup[at + 1] = color.g8
		lookup[at + 2] = color.b8
	var width: int = World.width()
	var pixels := PackedByteArray()
	pixels.resize(width * World.height() * 3)
	for y: int in World.height():
		var row: PackedByteArray = World.ROWS[y].to_ascii_buffer()
		var base: int = y * width * 3
		for x: int in row.size():
			var source: int = (row[x] & 127) * 3
			pixels[base + x * 3] = lookup[source]
			pixels[base + x * 3 + 1] = lookup[source + 1]
			pixels[base + x * 3 + 2] = lookup[source + 2]
	var image := Image.create_from_data(width, World.height(), false, Image.FORMAT_RGB8, pixels)
	for zone: Dictionary in World.ZONES:
		if not zone["pvp"]:
			continue
		var area: Rect2i = zone["rect"].intersection(Rect2i(0, 0, World.width(), World.height()))
		for y: int in range(area.position.y, area.end.y):
			for x: int in range(area.position.x, area.end.x):
				if World.terrain(Vector2i(x, y)) not in ["~", " "]:
					image.set_pixel(x, y, image.get_pixel(x, y).lerp(PVP_TINT, 0.45))
	_texture = ImageTexture.create_from_image(image)
	minimap = Control.new()
	minimap.position = Layout.PANEL_ORIGIN + Vector2(0, 578)
	minimap.size = Vector2(184, 102)
	minimap.clip_contents = true
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.draw.connect(_draw_minimap)
	layer.add_child(minimap)
	world_map = Control.new()
	world_map.position = Layout.VIEW_ORIGIN
	world_map.size = Layout.VIEW_SIZE
	world_map.visible = false
	world_map.draw.connect(_draw_world_map)
	world_map.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			world_map.hide())
	layer.add_child(world_map)


func redraw() -> void:
	minimap.queue_redraw()
	if world_map.visible:
		world_map.queue_redraw()


func _draw_markers(canvas: Control, origin: Vector2, scale: float, area: Rect2) -> void:
	for id: String in World.FERRYMEN:
		var at: Vector2 = origin + (Vector2(World.FERRYMEN[id]["cell"]) + Vector2(0.5, 0.5)) * scale
		if area.has_point(at):
			canvas.draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), Color("#7fe0d0"))
	for id: String in World.QUEST_GIVERS:
		var at: Vector2 = origin + (Vector2(World.QUEST_GIVERS[id]["cell"]) + Vector2(0.5, 0.5)) * scale
		if area.has_point(at):
			canvas.draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), Color("#ffcf6a"))
	for cell: Vector2i in World.DUNGEON_ENTRANCES:
		var at: Vector2 = origin + (Vector2(cell) + Vector2(0.5, 0.5)) * scale
		if area.has_point(at):
			canvas.draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), Color("#c9884a"))
	for id: String in World.TOWNSFOLK:
		var at: Vector2 = origin + (Vector2(World.TOWNSFOLK[id]["cell"]) + Vector2(0.5, 0.5)) * scale
		if area.has_point(at):
			canvas.draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), TOWNSFOLK_COLORS[World.TOWNSFOLK[id]["role"]])
	var actors: Dictionary = game.actors
	for id: int in actors:
		var at: Vector2 = origin + (actors[id]["visual"] + Vector2(0.5, 0.5)) * scale
		var mine: bool = id == game.self_id
		var radius: float = 2.5 if mine else 1.5
		if area.has_point(at):
			canvas.draw_rect(Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2.0),
				Color("#f2cf6a") if mine else Color.WHITE)


func _draw_minimap() -> void:
	var view := Rect2(Vector2.ZERO, minimap.size)
	minimap.draw_rect(view, Color.BLACK)
	var tiles: Vector2 = minimap.size / MINIMAP_SCALE
	var focus: Vector2 = game.camera_focus()
	var region := Rect2(focus / World.TILE_SIZE - tiles / 2.0, tiles)
	var shown := Rect2(World.OVERWORLD)
	var place: Array = World.dungeon_at(Vector2i(focus / World.TILE_SIZE))
	if not place.is_empty():
		# Underground, show only your own copy, never the copies next to it.
		shown = Rect2(Dungeons.rect(place[0], place[1]))
	var visible := region.intersection(shown)
	if visible.has_area():
		minimap.draw_texture_rect_region(_texture,
			Rect2((visible.position - region.position) * MINIMAP_SCALE, visible.size * MINIMAP_SCALE), visible)
	_draw_markers(minimap, -region.position * MINIMAP_SCALE, MINIMAP_SCALE, view)
	minimap.draw_rect(view, Color("#3a4450"), false, 1.0)


func _draw_world_map() -> void:
	var view_size: Vector2 = Layout.VIEW_SIZE
	# The overworld only: dungeon copies right of it are reached by stairways.
	var map_size := Vector2(World.OVERWORLD.size)
	# Whole pixels per tile when the map fits; otherwise shrink it.
	var fit: float = minf(view_size.x / map_size.x, (view_size.y - 32.0) / map_size.y)
	var scale: float = floorf(fit) if fit >= 1.0 else fit
	var origin: Vector2 = ((view_size - map_size * scale) / 2.0).floor() + Vector2(0, 12)
	world_map.draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.03, 0.04, 0.05))
	var shown := Rect2(origin, map_size * scale)
	world_map.draw_texture_rect_region(_texture, shown, Rect2(Vector2.ZERO, map_size))
	_draw_markers(world_map, origin, scale, shown)
	var font: Font = ThemeDB.fallback_font
	var labels: Array = [[World.WORLD_NAME, Vector2(World.SPAWNS[0]) + Vector2(4, -3)]]
	for id: String in World.FERRYMEN:
		var place: String = World.FERRYMEN[id]["place"]
		if World.zone_at(World.FERRYMEN[id]["cell"]).get("name", "") != place:
			labels.append([place, Vector2(World.FERRYMEN[id]["cell"]) + Vector2(0, -3)])
	for dungeon: String in World.ENTRANCE_OF:
		labels.append([Dungeons.DUNGEONS[dungeon]["name"], Vector2(World.ENTRANCE_OF[dungeon]) + Vector2(0, 4), Color("#e0a870")])
	for zone: Dictionary in World.ZONES:
		if zone.get("underground", false):
			continue
		var text: String = "%s (%s, level %d-%d)" % [zone["name"], "PvP" if zone["pvp"] else "safe",
			zone["min_level"], zone["max_level"]]
		labels.append([text, Vector2(zone["rect"].get_center().x, zone["rect"].end.y + 3), PVP_TINT.lightened(0.35)])
	for label: Array in labels:
		var at: Vector2 = origin + label[1] * scale - Vector2(font.get_string_size(label[0], 0, -1, 13).x / 2.0, 0)
		world_map.draw_string_outline(font, at, label[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color.BLACK)
		world_map.draw_string(font, at, label[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			label[2] if label.size() > 2 else Color("#f4ecd8"))
	world_map.draw_string(font, Vector2(12, 22), "World map: gold = you, cyan = ferrymen, orange = dungeons, red = PvP. Click to close.",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#dfe4ea"))
