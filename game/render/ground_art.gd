extends RefCounted
## Floors from the OpenTibia sprite pack (plan 49), drawn as Tibia draws them: each terrain's pack ground
## (GROUNDS), picking its pattern by the cell's position so it tiles, and, where a ground of a higher
## priority meets it, that ground's border pieces laid over it (n, e, s, w along a side; a small corner
## piece where only the diagonal neighbour is higher; a large diagonal piece where both sides are).
## Built floors (streets, planks, flagstones) have priority 1: natural ground spills over them, and a
## street's kerb lies on the water it meets. Dirt roads rank above grass, so their edge spills onto the
## grass and a one-tile road keeps its width. game/render/floor_layer.gd composes chunks from layers().

const World = preload("res://game/core/world.gd")
const Biomes = preload("res://game/data/biomes.gd")
const Caves = preload("res://game/data/caves.gd")
const Dungeons = preload("res://game/data/dungeons.gd")
const PackAtlas = preload("res://game/render/pack_atlas.gd")
const SpriteArt = preload("res://game/render/sprite_art.gd")
const Atlas = preload("res://game/data/atlas.gd")

## Ground name -> pack ground id, border set (PackAtlas.BORDERS, 0 for none), and priority (higher
## grounds lay their border over lower ones; water is lowest, so the shore borders lie on it).
const GROUNDS: Dictionary = {
	"dirt": [140, 363, 10],
	"grass": [106, 227, 9],
	"dusk": [116, 251, 8],
	"snow": [145, 399, 7],
	"sand": [126, 315, 6],
	"bog": [141, 375, 4],
	"gravel": [134, 327, 3],
	"obsidian": [162, 0, 2],
	"cave": [139, 0, 2],
	"cave_earth": [136, 0, 2],
	"ice": [156, 0, 2],
	"street": [154, 411, 1],
	"cellar": [147, 0, 1],
	"planks": [172, 0, 1],
	"snow_street": [146, 0, 1],
	"sandstone": [166, 0, 1],
	"flagstones": [155, 0, 1],
	"carpet": [176, 0, 1],
	"water": [163, 0, 0],
	# Natural rock's flat top by rock style (rock_style): a floor up, so the pack draws it a tile up and
	# left of its cell, over the ground beside it, with the cliff below its south and east edges (Tibia
	# builds mountains on two floors). Highest of all, so nothing lays a border on it.
	"rock_grey": [991, 0, 20],
	"rock_cave": [2298, 0, 20],
	"rock_snow": [991, 0, 20],
	"rock_sand": [990, 0, 20],
}
## Ways down and up (pack ids): a stairway frame into built dungeons and houses, a sewer grate in the
## streets, a stone hole into caves, a ladder up into a town, and a rope spot up out of a cave.
const STAIRS_DOWN: int = 997
const SEWER_GRATE: int = 999
const HOLE: int = 995
const LADDER: int = 1009
const ROPE_SPOT: int = 1000
## The pack's underground rock (Tibia's floor -1): solid red earth (2298) with grey rock edges, drawn
## as whole tiles in caves: [south, east, north, west,
## south-east, north-east, south-west, north-west outer corners, then the inner corners where only the
## south-east, south-west, north-east, or north-west neighbour is open]. Boulders face south and east.
const ROCK_EDGES: Dictionary = {
	"rock_cave": [2299, 2302, 2301, 2300, 2306, 2304, 2305, 2303, 2307, 2308, 2309, 2310],
}
## Rock styles: [vertical, horizontal, pole, corner] cliff pieces (WallArt draws them on the faces).
const ROCKS: Dictionary = {
	"grey": [957, 956, 958, 961],
	"cave": [957, 956, 958, 961],
	"snow": [935, 936, 937, 945],
	"sand": [919, 920, 921, 934],
}
## Animated grounds (water) cycle their frames this fast.
const FRAME_SECONDS: float = 0.35
const SIDES: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const DIAGONALS: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
static var _atlas: Image


## The pack atlas as an image (floors and roofs are composed from it on the CPU), loaded once.
static func atlas_image() -> Image:
	if _atlas == null:
		_atlas = PackAtlas.TEXTURE.get_image()
		_atlas.convert(Image.FORMAT_RGBA8)
	return _atlas


## The ground name of a terrain at a cell; `indoors` marks a building's floor seen beside its wall.
static func ground_of(tile: String, cell: Vector2i, indoors: bool = false) -> String:
	match tile:
		",":
			return "dirt"
		"~", "b":
			return "water"
		":", "K":
			return "sand"
		"s", "P":
			return "snow"
		"d", "D", "O":
			return "dusk"
		"o":
			return "obsidian"
		"L":
			return "gravel"
		"m", "U":
			return "bog"
		"F":
			return "flagstones"
		"Y":
			return "carpet"
		"=", "W":
			if SpriteArt.theme_at(cell) == "cellar":
				return "cellar"
			if Biomes.in_sunreach(cell):
				return "sandstone"
			# Houses have plank floors, as in Tibia.
			if indoors or World.ROOM_AT.has(cell):
				return "planks"
			return "snow_street" if Biomes.in_isles(cell) else "street"
		"c", "C":
			if tile == "C" and World.OVERWORLD.has_point(cell):
				return "grass"
			if Caves.at(cell) == SpriteArt.ICE_CAVE:
				return "ice"
			return "cave_earth" if SpriteArt.rock_cave(cell) else "cave"
	return "grass"


## The ground a cell's floor is (what its neighbours' borders meet): a wall stands on its outside
## ground, a stairway on the ground round it; "" for the void.
static func base_of(cell: Vector2i) -> String:
	var tile: String = SpriteArt.tile_at(cell)
	if tile == " " or tile.is_empty():
		return ""
	if tile == "#":
		return ground_of(_wall_sides(cell)[0], cell)
	if tile == "v" or tile == "^":
		return ground_of(SpriteArt.ground_under(cell), cell)
	if SpriteArt.natural_rock(cell):
		return "rock_" + rock_style(cell)
	return ground_of(tile, cell)


## A wall's outside and inside terrain ("" inside when no room touches it).
static func _wall_sides(cell: Vector2i) -> Array[String]:
	var outside: String = "."
	var inside: String = ""
	for side: Vector2i in SpriteArt.EDGES:
		var next: String = SpriteArt.tile_at(cell + side)
		if next.is_empty() or next in World.WALLS or next in World.TREES or next in ["~", "b", "v", "^", " "]:
			continue
		if _inner(cell + side):
			inside = next if inside.is_empty() and next in World.LAND and next != "v" else inside
		elif outside == ".":
			outside = next
	# A wall with nothing open on its outer side (a dungeon's outer wall) stands on its inside floor.
	if outside == "." and not inside.is_empty() and not SpriteArt.EDGES.any(
			func(side: Vector2i) -> bool: return SpriteArt.tile_at(cell + side) == "."):
		outside = inside
	# Below ground there is no grass: a corner wall of the sewers stands on the floor beside it.
	if outside == "." and inside.is_empty() and Atlas.below_ground(cell):
		for corner: Vector2i in DIAGONALS:
			var floor_beside: String = SpriteArt.tile_at(cell + corner)
			if floor_beside in World.LAND and floor_beside not in ["v", "^"]:
				outside = floor_beside
				break
	return [outside, inside]


## Inside a building or a castle keep: a wall's floor shows the inside there and the ground outside.
static func _inner(cell: Vector2i) -> bool:
	return World.ROOM_AT.has(cell) or SpriteArt.tile_at(cell) in ["F", "Y"]


## The atlas piece of pack thing `id` at a cell (its position pattern) in animation frame `frame`.
static func piece(id: int, cell: Vector2i, frame: int = 0) -> int:
	var thing: Array = PackAtlas.THINGS[id]
	return thing[5] + (posmod(frame, thing[2]) * thing[1] + posmod(cell.y, thing[1])) * thing[0] + posmod(cell.x, thing[0])


## Whether a ground animates (water).
static func animated(ground: String) -> bool:
	return not ground.is_empty() and PackAtlas.THINGS[GROUNDS[ground][0]][2] > 1


## What a cell's floor draws, bottom first: [pack id, atlas piece, quarters] (quarters: bits 1 top-left,
## 2 top-right, 4 bottom-left, 8 bottom-right; 15 the whole tile). Pieces larger than a tile (a ladder)
## reach up and left from the cell, as the pack draws them.
static func layers(cell: Vector2i, frame: int = 0) -> Array:
	var tile: String = SpriteArt.tile_at(cell)
	var base: String = base_of(cell)
	if base.is_empty():
		return []
	if ROCK_EDGES.has(base):
		# The rock's earth top with its edge: boulders where it drops south or east, a thin lip north
		# and west (whole tiles, so nothing leans out of the cell).
		var top: int = GROUNDS[base][0]
		var out_top: Array = [[top, piece(top, cell), 15]]
		var edge: int = _rock_edge(cell, ROCK_EDGES[base])
		if edge != 0:
			out_top.append([edge, piece(edge, cell), 15])
		return out_top
	if base.begins_with("rock_"):
		# The ground under the rock (seen where the cliff leaves a gap), then its top a floor up.
		var under: int = GROUNDS[ground_of(tile, cell)][0]
		return [[under, piece(under, cell), 15], [GROUNDS[base][0], piece(GROUNDS[base][0], cell), 15]]
	var out: Array = [[GROUNDS[base][0], piece(GROUNDS[base][0], cell, frame), 15]]
	_borders(cell, base, out)
	if tile == "#":
		var inside: String = _wall_sides(cell)[1]
		var quarters: int = 0
		for index: int in DIAGONALS.size():
			var corner: Vector2i = DIAGONALS[index]
			if _inner(cell + Vector2i(corner.x, 0)) or _inner(cell + Vector2i(0, corner.y)) or _inner(cell + corner):
				quarters |= 1 << index
		if quarters != 0:
			# A carpet never runs under a wall: a keep's wall shows its flagstones inside.
			var floor_inside: String = ground_of("=" if inside.is_empty() else ("F" if inside == "Y" else inside), cell, true)
			out.append([GROUNDS[floor_inside][0], piece(GROUNDS[floor_inside][0], cell), quarters])
	elif tile == "b":
		out.append([GROUNDS["planks"][0], piece(GROUNDS["planks"][0], cell), 15])
	elif tile == "v" or tile == "^":
		var way: int = way_of(cell)
		out.append([way, piece(way, cell), 15])
	return out


## The edge piece of a rock cell from ROCK_EDGES' `pieces`, by which neighbours are open; 0 inside.
static func _rock_edge(cell: Vector2i, pieces: Array) -> int:
	var open: Callable = func(offset: Vector2i) -> bool: return not SpriteArt.natural_rock(cell + offset)
	var n: bool = open.call(Vector2i.UP)
	var s: bool = open.call(Vector2i.DOWN)
	var w: bool = open.call(Vector2i.LEFT)
	var e: bool = open.call(Vector2i.RIGHT)
	if s and e:
		return pieces[4]
	if n and e:
		return pieces[5]
	if s and w:
		return pieces[6]
	if n and w:
		return pieces[7]
	for index: int in 4:
		if [s, e, n, w][index]:
			return pieces[index]
	for index: int in 4:
		if open.call([Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)][index]):
			return pieces[8 + index]
	return 0


## The rock style of a natural rock cell: snowy on the isles and in the ice cave, sandy in Sunreach,
## grey on the overworld, and black-topped in caves.
static func rock_style(cell: Vector2i) -> String:
	if Biomes.in_isles(cell) or Caves.at(cell) == SpriteArt.ICE_CAVE:
		return "snow"
	if Biomes.in_sunreach(cell):
		return "sand"
	return "grey" if World.OVERWORLD.has_point(cell) else "cave"


## The border pieces higher grounds lay over this cell, lowest ground first.
static func _borders(cell: Vector2i, base: String, out: Array) -> void:
	var mine: int = GROUNDS[base][2]
	var around: Array[String] = []
	for offset: Vector2i in SIDES + DIAGONALS:
		around.append(base_of(cell + offset))
	var higher: Array[String] = []
	for ground: String in around:
		if not ground.is_empty() and GROUNDS[ground][2] > mine and GROUNDS[ground][1] != 0 and ground not in higher:
			higher.append(ground)
	higher.sort_custom(func(a: String, b: String) -> bool: return GROUNDS[a][2] < GROUNDS[b][2])
	for ground: String in higher:
		var pieces: Dictionary = PackAtlas.BORDERS[GROUNDS[ground][1]]
		var n: bool = around[0] == ground
		var e: bool = around[1] == ground
		var s: bool = around[2] == ground
		var w: bool = around[3] == ground
		var names: Array[String] = []
		for pair: Array in [["dnw", n and w], ["dne", n and e], ["dsw", s and w], ["dse", s and e]]:
			if pair[1] and pieces.has(pair[0]):
				names.append(pair[0])
		var covered: String = "".join(names)
		if n and not covered.contains("dn"):
			names.append("n")
		if s and not covered.contains("ds"):
			names.append("s")
		if w and not covered.contains("w"):
			names.append("w")
		if e and not covered.contains("e"):
			names.append("e")
		for index: int in DIAGONALS.size():
			var corner: String = ["cnw", "cne", "csw", "cse"][index]
			var side_x: bool = around[3] == ground if DIAGONALS[index].x < 0 else around[1] == ground
			var side_y: bool = around[0] == ground if DIAGONALS[index].y < 0 else around[2] == ground
			if around[4 + index] == ground and not side_x and not side_y:
				names.append(corner)
		for name: String in names:
			out.append([pieces[name], piece(pieces[name], cell), 15])


## The way down or up drawn on a stairway cell: into a built dungeon or a house a stairway, from a
## street into the sewers a grate, into a cave a hole; out of a built dungeon or into a town a ladder,
## out of a cave a rope spot.
static func way_of(cell: Vector2i) -> int:
	var tile: String = SpriteArt.tile_at(cell)
	if tile == "^" and World.HOLES.has(cell):
		var town: bool = World.zone_at(cell).get("town", false) or World.zone_at(World.HOLES[cell]).get("town", false)
		return LADDER if town else ROPE_SPOT
	if tile == "^":
		var place: Array = World.dungeon_at(cell)
		return LADDER if not place.is_empty() and Dungeons.DUNGEONS[place[0]]["wall"] == "#" else ROPE_SPOT
	if World.DUNGEON_ENTRANCES.has(cell):
		return STAIRS_DOWN if Dungeons.DUNGEONS[World.DUNGEON_ENTRANCES[cell]]["wall"] == "#" else HOLE
	if World.CAVE_MOUTHS.has(cell) or not World.zone_at(cell).get("town", false):
		return HOLE
	return STAIRS_DOWN if World.ROOM_AT.has(cell) else SEWER_GRATE
