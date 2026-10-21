extends RefCounted
## The map brushes behind the editor plugin (addons/brimholt_brushes): a terrain brush that paints
## one tile in a disc, a doodad brush that scatters a biome's trees and rocks over its ground, a
## clear brush that takes them away again, and an eraser that drops the hand override so the
## generated base shows through. Pure functions over cells and terrain letters, so the rules check
## runs them without the editor; the plugin writes the result into a sector's override layer.

const Atlas = preload("res://game/data/atlas.gd")

## Terrains the terrain brush paints, in palette order (stairs pair with holes and markers, so
## they are left to the generators).
const NAMES: Dictionary = {
	".": "Grass", ",": "Dirt road", ":": "Sand", "s": "Snow", "m": "Bog mud", "d": "Dusk soil",
	"=": "Cobblestone", "F": "Flag floor", "Y": "Carpet", "c": "Cave floor", "o": "Obsidian floor",
	"b": "Pier / bridge", "~": "Water", "T": "Tree", "P": "Snowy fir", "D": "Dead tree",
	"U": "Giant mushroom", "K": "Cactus", "R": "Boulder", "L": "Mountain rock", "C": "Cave rock",
	"#": "Stone wall", "W": "Castle wall", "O": "Obsidian wall",
}

## Doodad sets: the ground they grow on, their pieces by weight, and the ground clearing leaves.
const SCATTERS: Dictionary = {
	"forest": {"name": "Forest", "ground": ".", "pieces": {"T": 9, "R": 1}, "clear": "."},
	"rocks": {"name": "Rocks", "ground": ".:sd", "pieces": {"R": 1}, "clear": "."},
	"desert": {"name": "Desert", "ground": ":", "pieces": {"K": 4, "R": 1}, "clear": ":"},
	"fen": {"name": "Fen", "ground": "m.", "pieces": {"U": 3, "T": 1}, "clear": "m"},
	"snow": {"name": "Snow", "ground": "s", "pieces": {"P": 5, "R": 1}, "clear": "s"},
	"wastes": {"name": "Wastes", "ground": "d", "pieces": {"D": 3, "R": 1}, "clear": "d"},
}

## Doodads keep off the tiles beside a road, pier, or stairway, so paths stay open.
const PATHS: String = ",=b^v"
const SIDES: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


## The cells of a round brush: radius 0 is one cell.
static func disc(centre: Vector2i, radius: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var reach: float = (radius + 0.5) * (radius + 0.5)
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			if dx * dx + dy * dy <= reach:
				cells.append(centre + Vector2i(dx, dy))
	return cells


## {cell: letter} painting every cell with one terrain.
static func fill(cells: Array[Vector2i], letter: String) -> Dictionary:
	var changes: Dictionary = {}
	for cell: Vector2i in cells:
		changes[cell] = letter
	return changes


## {cell: piece} scattering a doodad set over its ground: each open ground cell takes a piece
## with chance density (0-1). terrain_of maps a cell to its letter.
static func scatter(cells: Array[Vector2i], kind: String, density: float, terrain_of: Callable,
		rng: RandomNumberGenerator) -> Dictionary:
	var spec: Dictionary = SCATTERS[kind]
	var pieces: Dictionary = spec["pieces"]
	var total: int = 0
	for piece: String in pieces:
		total += int(pieces[piece])
	var changes: Dictionary = {}
	for cell: Vector2i in cells:
		if not String(spec["ground"]).contains(terrain_of.call(cell)):
			continue
		if SIDES.any(func(side: Vector2i) -> bool: return PATHS.contains(terrain_of.call(cell + side))):
			continue
		if rng.randf() >= density:
			continue
		var pick: int = rng.randi_range(0, total - 1)
		for piece: String in pieces:
			pick -= int(pieces[piece])
			if pick < 0:
				changes[cell] = piece
				break
	return changes


## {cell: ground} taking a doodad set's pieces away again.
static func clear(cells: Array[Vector2i], kind: String, terrain_of: Callable) -> Dictionary:
	var spec: Dictionary = SCATTERS[kind]
	var changes: Dictionary = {}
	for cell: Vector2i in cells:
		if (spec["pieces"] as Dictionary).has(terrain_of.call(cell)):
			changes[cell] = spec["clear"]
	return changes


## The sector a sector scene's root (named "Sector_<sx>_<sy>") holds, or (-1, -1).
static func sector_of(layer: Node) -> Vector2i:
	var parts: PackedStringArray = String(layer.name).split("_")
	if parts.size() != 3 or parts[0] != "Sector" or not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return Vector2i(-1, -1)
	return Vector2i(int(parts[1]), int(parts[2]))


## letter -> Vector3i(source, atlas x, atlas y) from a tile set's "terrain" custom data.
static func tiles(tile_set: TileSet) -> Dictionary:
	var found: Dictionary = {}
	for index: int in tile_set.get_source_count():
		var source_id: int = tile_set.get_source_id(index)
		var source: TileSetAtlasSource = tile_set.get_source(source_id) as TileSetAtlasSource
		if source == null:
			continue
		for tile: int in source.get_tiles_count():
			var coords: Vector2i = source.get_tile_id(tile)
			var kind: Variant = source.get_tile_data(coords, 0).get_custom_data("terrain")
			if typeof(kind) == TYPE_STRING and not found.has(kind):
				found[String(kind)] = Vector3i(source_id, coords.x, coords.y)
	return found


## The letter a sector shows at a cell: its override, else its base, else "~" (open sea).
static func letter_at(override: TileMapLayer, base: TileMapLayer, cell: Vector2i, letters: Dictionary) -> String:
	for layer: TileMapLayer in [override, base]:
		if layer != null and layer.get_cell_source_id(cell) != -1:
			var coords: Vector2i = layer.get_cell_atlas_coords(cell)
			return letters.get(Vector3i(layer.get_cell_source_id(cell), coords.x, coords.y), "~")
	return "~"
