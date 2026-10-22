extends Node2D
## Floors in CHUNK x CHUNK tile pieces: each chunk is an image composed once from the OpenTibia pack's
## grounds and borders (game/render/ground_art.gd, pieces from pack_atlas.gd's world.png), one image per
## animation frame where water runs through it. Floors never change, so a chunk is built once; chunks
## near the camera are built a few per frame and far ones are freed.

const World = preload("res://game/core/world.gd")
const SpriteArt = preload("res://game/render/sprite_art.gd")
const GroundArt = preload("res://game/render/ground_art.gd")
const PackAtlas = preload("res://game/render/pack_atlas.gd")
const CHUNK: int = 16
const TILE: int = 32
## Chunks around the view kept or built ahead, and the most built in one frame.
const KEEP_MARGIN: int = 1
const BUILDS_PER_FRAME: int = 2
## Frames of animated ground (the pack's water has four).
const FRAMES: int = 4


class Chunk extends Node2D:
	var area: Rect2i
	var frames: Array[ImageTexture] = []

	func _process(_delta: float) -> void:
		if frames.size() > 1:
			queue_redraw()

	func _draw() -> void:
		var frame: int = int(Time.get_ticks_msec() / 1000.0 / GroundArt.FRAME_SECONDS) % frames.size()
		draw_texture(frames[frame], Vector2(area.position * TILE))


var view: Node2D
var _chunks: Dictionary = {}


func _ready() -> void:
	show_behind_parent = true


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
	var animated: bool = false
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			animated = animated or GroundArt.animated(GroundArt.base_of(Vector2i(x, y)))
	for frame: int in FRAMES if animated else 1:
		chunk.frames.append(ImageTexture.create_from_image(compose(area, frame)))
	chunk.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(chunk)
	return chunk


## An area's floor image in animation frame `frame` (the void is black). Pieces larger than a tile
## reach up and left from their cell, so cells just right of and below the area draw theirs too.
static func compose(area: Rect2i, frame: int = 0) -> Image:
	var atlas: Image = GroundArt.atlas_image()
	var image := Image.create_empty(area.size.x * TILE, area.size.y * TILE, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	for y: int in range(area.position.y, area.end.y + 1):
		for x: int in range(area.position.x, area.end.x + 1):
			var cell := Vector2i(x, y)
			var inside: bool = area.has_point(cell)
			var corner: Vector2i = (cell - area.position + Vector2i.ONE) * TILE
			for layer: Array in GroundArt.layers(cell, frame):
				var thing: Array = PackAtlas.THINGS[layer[0]]
				var size := Vector2i(thing[3], thing[4])
				if not inside and size == Vector2i(TILE, TILE):
					continue
				var source := Rect2i(PackAtlas.RECTS[layer[1] * 2], PackAtlas.RECTS[layer[1] * 2 + 1], size.x, size.y)
				if layer[2] == 15:
					image.blend_rect(atlas, source, corner - size)
					continue
				for quarter: int in 4:
					if layer[2] & (1 << quarter):
						var offset := Vector2i(quarter % 2, quarter / 2) * (TILE / 2)
						image.blend_rect(atlas, Rect2i(source.position + offset, Vector2i.ONE * (TILE / 2)),
							corner - Vector2i(TILE, TILE) + offset)
	return image
