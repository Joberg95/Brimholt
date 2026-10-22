extends RefCounted
## Walls, doors, and rock from the OpenTibia sprite pack (plan 49), drawn as Tibia draws them. A pack
## wall lies along its cell's east edge (vertical) or south edge (horizontal) and rises up and left, so
## a wall cell shows its vertical piece where the wall goes on north, its horizontal piece where it goes
## on west, the corner where it does both, and a pole where it only starts or stands alone. Natural rock
## is a raised rock top with cliff pieces (the same rule) on its cells that face open ground south or
## east (its raised top is drawn with the floor, GroundArt.ROCK_TOPS). Draw in row-major order: a piece
## reaches into the rows above.

const World = preload("res://game/core/world.gd")
const Biomes = preload("res://game/data/biomes.gd")
const PackAtlas = preload("res://game/render/pack_atlas.gd")
const GroundArt = preload("res://game/render/ground_art.gd")
const SpriteArt = preload("res://game/render/sprite_art.gd")

## Wall styles: [vertical, horizontal, pole, corner, vertical window, horizontal window (0: none),
## vertical door, horizontal door] (pack ids; a door piece carries its own stretch of wall).
const WALLS: Dictionary = {
	"stone": [534, 535, 536, 537, 539, 541, 1012, 1015],
	"plaster": [778, 779, 780, 781, 782, 784, 1052, 1055],
	"logs": [878, 879, 880, 881, 0, 0, 1018, 1019],
	"brick": [552, 553, 554, 555, 0, 0, 1020, 1021],
	"fieldstone": [518, 519, 520, 521, 0, 0, 1020, 1021],
	"castle": [542, 543, 544, 545, 550, 551, 1020, 1021],
	"sand_castle": [552, 553, 554, 555, 556, 557, 1020, 1021],
	"dark": [891, 892, 893, 894, 0, 0, 1020, 1021],
	"dungeon": [558, 559, 560, 561, 0, 0, 1020, 1021],
}
## Rock styles (GroundArt.rock_style): [vertical, horizontal, pole, corner] cliff pieces.
const ROCKS: Dictionary = {
	"grey": [957, 956, 958, 961],
	"cave": [957, 956, 958, 961],
	"snow": [935, 936, 937, 945],
	"sand": [919, 920, 921, 934],
}
## Ore veins by resource band (copper, iron, silver, cobalt, starmetal): the ore's pack sprite set into
## the rock face.
const ORES: Array[int] = [2200, 2202, 2201, 2199, 2203]
## About one straight overworld house wall in WINDOW_EVERY has a window.
const WINDOW_EVERY: int = 5


## Draws pack thing `id` on `cell` as the pack places it: its bottom-right corner at the cell's,
## moved up and left by its displacement; patterns by `pattern_cell`.
static func draw(canvas: CanvasItem, id: int, cell: Vector2i, pattern_cell: Vector2i = cell, frame: int = 0,
		color: Color = Color.WHITE) -> void:
	var thing: Array = PackAtlas.THINGS[id]
	var piece: int = GroundArt.piece(id, pattern_cell, frame)
	var size := Vector2(thing[3], thing[4])
	var source := Rect2(PackAtlas.RECTS[piece * 2], PackAtlas.RECTS[piece * 2 + 1], size.x, size.y)
	canvas.draw_texture_rect_region(PackAtlas.TEXTURE, Rect2((Vector2(cell) + Vector2.ONE) * SpriteArt.TILE - size, size), source, color)


## Tibia's wall rule: the piece of a [vertical, horizontal, pole, corner] set for a cell joined to more
## wall north (`north`) and west (`west`).
static func piece_of(pieces: Array, north: bool, west: bool) -> int:
	return pieces[3] if north and west else pieces[0] if north else pieces[1] if west else pieces[2]


static func draw_wall(canvas: CanvasItem, cell: Vector2i) -> void:
	if SpriteArt.natural_rock(cell):
		var rock: Array = ROCKS[GroundArt.rock_style(cell)]
		if _face(cell):
			draw(canvas, piece_of(rock, _face(cell + Vector2i.UP), _face(cell + Vector2i.LEFT)), cell)
		return
	var pieces: Array = WALLS[wall_style(cell)]
	var mask: int = SpriteArt.thin_wall_mask(cell)
	var north: bool = mask & 1 != 0
	var west: bool = mask & 2 != 0
	var id: int = piece_of(pieces, north, west)
	# Some straight overworld walls get a window.
	if north != west and SpriteArt.tile_at(cell) == "#" and World.OVERWORLD.has_point(cell) \
			and SpriteArt.noise(cell, 17) % WINDOW_EVERY == 0 and pieces[4 if north else 5] != 0:
		id = pieces[4 if north else 5]
	draw(canvas, id, cell)


## A doorway in a wall: the style's door, set into a north-south or a west-east wall.
static func draw_door(canvas: CanvasItem, cell: Vector2i) -> void:
	var north: String = SpriteArt.tile_at(cell + Vector2i.UP)
	var vertical: bool = not north.is_empty() and north in World.WALLS
	var pieces: Array = WALLS[wall_style(cell)]
	draw(canvas, pieces[6] if vertical else pieces[7], cell)


## An ore vein in a rock face: the ore glints (drawn brighter) for a moment now and then.
static func draw_ore(canvas: CanvasItem, cell: Vector2i, band: int, glint: bool) -> void:
	draw(canvas, ORES[band], cell, cell, 0, Color(1.4, 1.4, 1.4) if glint else Color.WHITE)


## A rock cell shows a cliff where open ground lies south, east, or south-east of it.
static func _face(cell: Vector2i) -> bool:
	return SpriteArt.natural_rock(cell) and not (SpriteArt.natural_rock(cell + Vector2i.RIGHT)
		and SpriteArt.natural_rock(cell + Vector2i.DOWN) and SpriteArt.natural_rock(cell + Vector2i.ONE))


## The wall style of a wall or doorway cell: castle walls ("W"), the Hollow Reach's obsidian ("O"), and
## house walls by place (Sunreach plaster, keep fieldstone, isle logs, cellar brick, other dungeons'
## stone blocks, town stone).
static func wall_style(cell: Vector2i) -> String:
	var tile: String = SpriteArt.tile_at(cell)
	if tile == "W":
		return "sand_castle" if Biomes.in_sunreach(cell) else "castle"
	if tile == "O":
		return "dark"
	if Biomes.in_sunreach(cell):
		return "plaster"
	if SpriteArt.castle_stone(cell):
		return "fieldstone"
	if Biomes.in_isles(cell):
		return "logs"
	if SpriteArt.theme_at(cell) == "cellar":
		return "brick"
	return "stone" if World.OVERWORLD.has_point(cell) else "dungeon"
