extends "res://tools/generators/landscape.gd"
## Mountains where the land has a reason for them, in the existing overworld scene:
## - rock pieces ("CL") smaller than MIN_MASSIF tiles in the open are cleared to the ground most
##   common around them, so no lone clumps stand in fields and woods;
## - a massif rises around every way down outside towns (cave mouths, dungeon entrances, holes),
##   the way down at its south foot in a notch that opens south, as in a real cliff;
## - mountains run along the map's north and west edges where land meets them.
## Ore veins come from the new rock faces by themselves (Crafting.ORES). Roads, water, bridges,
## walls, towns, zones, markers, and monster camps are kept clear, and every marker and way down
## stays reachable. The scene remembers that it ran (metadata "mountains"); running again changes
## nothing.
##
##   godot --headless --path . --script res://tools/generators/mountains.gd

const World = preload("res://game/core/world.gd")
const Biomes = preload("res://game/data/biomes.gd")
const Towns = preload("res://tools/generators/towns.gd")

const MIN_MASSIF: int = 30
## Ground clumps are cleared to (trees count as the ground they grow on), and ground (with its
## trees) a massif may cover.
const GROUND: String = ".,:sdm"
const TREE_GROUND: Dictionary = {"T": ".", "K": ":", "P": "s", "D": "d", "U": "m"}
const COVER: String = ".,:sdmTKPDU"
const KEEP_CLEAR: String = "=~b#oOWFY"
## Massif radius around a cave mouth or dungeon entrance, and around any other hole.
const CAVE_RADIUS: float = 13.0
const HOLE_RADIUS: float = 8.0
## The radius swells and shrinks by this share with a smooth noise, so massifs are not round.
const RAGGED: float = 0.45
## Mountains along the north and west map edges: EDGE_DEPTH tiles deep, plus up to EDGE_SWELL.
const EDGE_DEPTH: int = 5
const EDGE_SWELL: int = 9
## Rock keeps this far outside a monster camp's radius, so the camp has room for its monsters.
const CAMP_MARGIN: float = 1.5
const EIGHT: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]


func _initialize() -> void:
	var scene_root: Node = MapIO.load_scene()
	if scene_root.has_meta("mountains"):
		print("The mountains are already painted into %s: nothing to do" % SCENE_PATH)
		MapIO.free_scene(scene_root)
		quit(0)
		return
	_prepare(scene_root)
	_keep_patches()
	var holes: Array[Vector2i] = _holes()
	var report: Dictionary = {"clump tiles cleared": _clear_clumps()}
	report["massif tiles"] = _massifs(scene_root, holes)
	report["edge tiles"] = _edges()
	# From the harbours only (player spawns stand at cave mouths, inside the new massifs), on every
	# island too.
	_reconnect_area = OVERWORLD
	report["paths carved"] = _reconnect(scene_root, holes, ["Ferrymen"])
	_settle()
	scene_root.set_meta("mountains", true)
	var error: Error = MapIO.save_scene(scene_root)
	print("Painted mountains into %s: %s (%s)" % [SCENE_PATH, report, error_string(error)])
	MapIO.free_scene(scene_root)
	quit(0 if error == OK else 1)


## Overworld ways down in the open (outside every zone).
func _holes() -> Array[Vector2i]:
	var holes: Array[Vector2i] = []
	for cell: Vector2i in _layer.get_used_cells():
		if OVERWORLD.has_point(cell) and _tile(cell) == "v" and _zone(cell).is_empty():
			holes.append(cell)
	return holes


func _open_land(cell: Vector2i) -> bool:
	return OVERWORLD.has_point(cell) and _zone(cell).is_empty() and not _patched.has(cell)


## The town painter's hand-made patches (towns.gd) stay as they are.
var _patched: Dictionary = {}


func _keep_patches() -> void:
	for patch: Array in Towns.PATCHES:
		for y: int in patch[1].size():
			for x: int in (patch[1][y] as String).length():
				if patch[1][y][x] != " ":
					_patched[patch[0] + Vector2i(x, y)] = true


## Clears every rock piece in the open smaller than MIN_MASSIF to the ground most common around it.
func _clear_clumps() -> int:
	var seen: Dictionary = {}
	var cleared: int = 0
	for cell: Vector2i in _layer.get_used_cells():
		if seen.has(cell) or not _tile(cell) in "CL" or not _open_land(cell):
			continue
		var piece: Array[Vector2i] = [cell]
		seen[cell] = true
		var open: int = 0
		var counts: Dictionary = {}
		while open < piece.size():
			for side: Vector2i in EIGHT:
				var next: Vector2i = piece[open] + side
				var tile: String = _tile(next)
				if tile.is_empty():
					continue
				if tile in "CL":
					if not seen.has(next):
						seen[next] = true
						piece.append(next)
				elif tile in GROUND or TREE_GROUND.has(tile):
					var under: String = TREE_GROUND.get(tile, tile)
					counts[under] = counts.get(under, 0) + 1
			open += 1
		if piece.size() >= MIN_MASSIF or not piece.all(_open_land):
			continue
		var ground: String = "."
		for tile: String in counts:
			if counts[tile] > counts.get(ground, 0):
				ground = tile
		for part: Vector2i in piece:
			_paint(part, _fitting(part, ground))
		cleared += piece.size()
	return cleared


## Paths carved through rock in the desert become sand, not meadow.
func _settle() -> void:
	for cell: Vector2i in _layer.get_used_cells():
		if _tile(cell) == "." and OVERWORLD.has_point(cell):
			_paint(cell, _fitting(cell, "."))


## `ground`, unless the land at `cell` wants its own: sand in the desert, bog only in the fen.
static func _fitting(cell: Vector2i, ground: String) -> String:
	if Biomes.desert_distance(cell) < 1.0:
		return ":"
	if ground == "m" and World.region_at(cell) != Biomes.SWAMP_REGION:
		return "."
	return ground


## Whether a massif may cover `cell`: open ground or trees in the country, away from roads, water,
## walls, markers, the town painter's patches, and monster camps (a round clearing, so the rock
## keeps no straight edges).
func _coverable(cell: Vector2i) -> bool:
	return _tile(cell) in COVER and _countryside(cell) and not _patched.has(cell) and not _near(cell, 1, KEEP_CLEAR) 		and not _in_camp(cell)


func _in_camp(cell: Vector2i) -> bool:
	for camp: Array in _camps:
		if Vector2(cell - (camp[0] as Vector2i)).length() <= float(camp[1]) + CAMP_MARGIN:
			return true
	return false


## A ragged massif around each hole, with a notch opening south from the hole.
func _massifs(scene_root: Node, holes: Array[Vector2i]) -> int:
	var caves: Dictionary = {}
	for group: String in ["CaveMouths", "DungeonEntrances"]:
		for marker: Node2D in scene_root.get_node(group).get_children():
			caves[_cell_of(marker)] = true
	var painted: int = 0
	for hole: Vector2i in holes:
		var radius: float = CAVE_RADIUS if caves.has(hole) else HOLE_RADIUS
		var reach: int = ceili(radius * (1.0 + RAGGED))
		for y: int in range(-reach, reach + 1):
			for x: int in range(-reach, reach + 1):
				var cell: Vector2i = hole + Vector2i(x, y)
				# The notch: the hole's row and a funnel widening south stay open.
				if y >= 0 and absi(x) <= 1 + y / 2:
					continue
				var swell: float = 1.0 + RAGGED * (2.0 * _noise(cell, 6.0, 71) - 1.0)
				if Vector2(x, y).length() > radius * swell or not _coverable(cell):
					continue
				_paint(cell, "L")
				painted += 1
	return painted


## Mountains along the north and west edges of the map, wherever land reaches them.
func _edges() -> int:
	var painted: int = 0
	for cell: Vector2i in _layer.get_used_cells():
		var along: int = cell.x if cell.y < cell.x else cell.y
		var depth: int = EDGE_DEPTH + int(EDGE_SWELL * _noise(Vector2i(along, 0), 8.0, 73))
		if mini(cell.x, cell.y) >= depth or not _coverable(cell):
			continue
		_paint(cell, "L")
		painted += 1
	return painted
