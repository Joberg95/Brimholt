extends Node2D
## Floors on the GPU, in CHUNK x CHUNK tile pieces: each chunk is one quad whose texture is a small
## data image (one texel per cell plus a one-cell border, SpriteArt.floor_texel) that
## terrain.gdshader turns into tiles from tiles.png, with blended edges between natural grounds,
## animated water and shore foam, and swaying grass. Floors never change, so a chunk's data is built
## once; chunks near the camera are built a few per frame and far ones are freed.

const World = preload("res://game/core/world.gd")
const SpriteArt = preload("res://game/render/sprite_art.gd")
const TERRAIN_SHADER: Shader = preload("res://game/render/terrain.gdshader")
const CHUNK: int = 16
## Chunks around the view kept or built ahead, and the most built in one frame.
const KEEP_MARGIN: int = 1
const BUILDS_PER_FRAME: int = 2


class Chunk extends Node2D:
	var area: Rect2i
	var data: ImageTexture

	func _draw() -> void:
		draw_texture_rect(data, Rect2(Vector2(area.position * SpriteArt.TILE), Vector2(area.size * SpriteArt.TILE)), false)


var view: Node2D
var _chunks: Dictionary = {}
var _material: ShaderMaterial


func _ready() -> void:
	show_behind_parent = true
	_material = ShaderMaterial.new()
	_material.shader = TERRAIN_SHADER
	_material.set_shader_parameter("tiles", SpriteArt.TILES)
	_material.set_shader_parameter("curb_tile", SpriteArt.CURB_TILE)
	_material.set_shader_parameter("water_tile", SpriteArt.WATER_TILE)


func _process(_delta: float) -> void:
	var shown: Rect2i = view.visible_cells()
	var first := Vector2i(shown.position.x / CHUNK, shown.position.y / CHUNK) - Vector2i.ONE * KEEP_MARGIN
	var last := Vector2i((shown.end.x - 1) / CHUNK, (shown.end.y - 1) / CHUNK) + Vector2i.ONE * KEEP_MARGIN
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
				if pass_index == 0 and not area.intersects(shown):
					continue
				if built >= BUILDS_PER_FRAME and pass_index == 1:
					return
				_chunks[key] = _build(area)
				built += 1


func _build(area: Rect2i) -> Node2D:
	var chunk := Chunk.new()
	chunk.area = area
	chunk.data = ImageTexture.create_from_image(data_image(area))
	chunk.material = _material
	chunk.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(chunk)
	return chunk


## The floor data of an area and a one-cell border around it, RGBA8 (SpriteArt.floor_texel).
static func data_image(area: Rect2i) -> Image:
	var size: Vector2i = area.size + Vector2i(2, 2)
	var bytes := PackedByteArray()
	bytes.resize(size.x * size.y * 4)
	var at: int = 0
	for y: int in range(area.position.y - 1, area.end.y + 1):
		for x: int in range(area.position.x - 1, area.end.x + 1):
			bytes.encode_u32(at, SpriteArt.floor_texel(Vector2i(x, y)))
			at += 4
	return Image.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, bytes)
