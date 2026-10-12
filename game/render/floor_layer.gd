extends Node2D
## Floors drawn behind the world view, in CHUNK x CHUNK tile pieces. Floors never change, so
## each chunk is drawn once and kept; chunks near the camera are built a few per frame and far
## ones are freed. Water and piers sit in a child of each chunk with an animated shader
## (water.gdshader), so the water moves without any redrawing.

const World = preload("res://game/core/world.gd")
const SpriteArt = preload("res://game/render/sprite_art.gd")
const WATER_SHADER: Shader = preload("res://game/render/water.gdshader")
const CHUNK: int = 16
## Chunks around the view kept or built ahead, and the most built in one frame.
const KEEP_MARGIN: int = 1
const BUILDS_PER_FRAME: int = 1


class Chunk extends Node2D:
	var area: Rect2i
	var water: bool

	func _draw() -> void:
		for y: int in range(area.position.y, area.end.y):
			var row: String = World.ROWS[y]
			for x: int in range(area.position.x, area.end.x):
				if (row[x] == "~" or row[x] == "b") == water:
					SpriteArt.draw_floor(self, Vector2i(x, y), 0.0)


var view: Node2D
var _chunks: Dictionary = {}
var _water_material: ShaderMaterial


func _ready() -> void:
	show_behind_parent = true
	_water_material = ShaderMaterial.new()
	_water_material.shader = WATER_SHADER


func _process(_delta: float) -> void:
	var visible: Rect2i = view.visible_cells()
	var first := Vector2i(visible.position.x / CHUNK, visible.position.y / CHUNK) - Vector2i.ONE * KEEP_MARGIN
	var last := Vector2i((visible.end.x - 1) / CHUNK, (visible.end.y - 1) / CHUNK) + Vector2i.ONE * KEEP_MARGIN
	var wanted := Rect2i(first, last - first + Vector2i.ONE)
	for key: Vector2i in _chunks.keys():
		if not wanted.has_point(key):
			_chunks[key].queue_free()
			_chunks.erase(key)
	# Visible chunks first, so a teleport never shows bare ground for long.
	var built: int = 0
	for pass_index: int in 2:
		for cy: int in range(wanted.position.y, wanted.end.y):
			for cx: int in range(wanted.position.x, wanted.end.x):
				var key := Vector2i(cx, cy)
				var area := Rect2i(key * CHUNK, Vector2i.ONE * CHUNK).intersection(Rect2i(0, 0, World.width(), World.height()))
				if _chunks.has(key) or not area.has_area():
					continue
				if pass_index == 0 and not area.intersects(visible):
					continue
				if built >= BUILDS_PER_FRAME and pass_index == 1:
					return
				_chunks[key] = _build(area)
				built += 1


func _build(area: Rect2i) -> Node2D:
	var ground := Chunk.new()
	ground.area = area
	ground.water = false
	add_child(ground)
	var wet := Chunk.new()
	wet.area = area
	wet.water = true
	wet.material = _water_material
	ground.add_child(wet)
	return ground
