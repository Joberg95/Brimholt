extends SceneTree
## Paints the archipelago's islands (docs/plan/40-archipelago.md) into the open sea of the
## 1920 x 1920 overworld: a ragged coast with beaches, the island's biome (woods with clearings,
## meadows, lakes, rocky knolls), a castle capital, a smaller town, dirt roads cut through the
## woods between them and out to the shores, a harbour with a ferry to the mainland, and hunting
## camps (placeholders from today's level 45-50 monsters until the island's own band is added).
##
## The castle follows the owner's reference: curtain walls with corner and gate towers round
## cobbled streets, rows of houses, and a keep of fieldstone walls (SpriteArt.castle_stone) on a
## sandstone floor with a carpet down the hall, pillars, banners, torches, knight statues, a
## throne, and a furnished living wing, gargoyles and bushes at its door (Decor markers).
##
## Each island is painted once (scene metadata island_<id>); from then on the scene is the source
## of truth (paint over it in Godot, move markers), so running again changes nothing. Afterwards
## run make towns town-paths world-map.
##
##   godot --headless --path . --script res://tools/generators/islands.gd

const MapIO = preload("res://game/maps/map_io.gd")
const TERRAINS: String = ".,~#T:=bdoODcCv^KRLWmUsPFY"
const TILE: int = 32
const SPAWN_SCRIPT: Script = preload("res://game/maps/markers/monster_spawn.gd")
const ZONE_SCRIPT: Script = preload("res://game/maps/markers/zone.gd")
const FERRY_SCRIPT: Script = preload("res://game/maps/markers/ferryman.gd")
const TOWNSFOLK_SCRIPT: Script = preload("res://game/maps/markers/townsfolk.gd")
const DECOR_SCRIPT: Script = preload("res://game/maps/markers/decor.gd")
const ORDER: Array[String] = ["silverwood", "sunreach"]
## rect: the island's bounds; capital and town: their names, keepers, and where they stand
## (castle's top-left; the town's square centre); camps: placeholder monsters by weight;
## levels: the placeholder band; port: the mainland ferryman the harbour sails to, and the fare;
## biome: "forest" (the default: woods, meadows, lakes) or "desert" (sand, oases with palms,
## mesas, cactus groves; _desert).
const ISLANDS: Dictionary = {
	"silverwood": {
		"rect": Rect2i(760, 60, 240, 220), "seed": 4100,
		"capital": {"name": "Aldmoor", "at": Vector2i(788, 140), "ferryman": "Ferryman Edric",
			"vendor": "Quartermaster Hale", "artisan": "Master Brannoc"},
		"town": {"name": "Fernhollow", "at": Vector2i(920, 130), "vendor": "Trader Wynne", "artisan": "Woodwright Ilsa"},
		"port": ["cinder_landing", 90],
		"levels": Vector2i(45, 50),
		"camps": [["giant_bat", 3], ["harpy", 3], ["skeleton_warrior", 2], ["skeleton_warrior", 2], ["sand_lion", 1]],
	},
	# The desert island south of the mainland (docs/plan/47-world-plan.md): the sandstone castle of
	# Qasrun by the west shore, the oasis town of Duneford to the east.
	"sunreach": {
		"rect": Rect2i(380, 740, 280, 240), "seed": 4200, "biome": "desert",
		"capital": {"name": "Qasrun", "at": Vector2i(410, 820), "ferryman": "Ferryman Hassid",
			"vendor": "Quartermaster Zahra", "artisan": "Master Idris"},
		"town": {"name": "Duneford", "at": Vector2i(590, 860), "vendor": "Trader Nasrin", "artisan": "Potter Samir"},
		"port": ["cinder_landing", 100],
		"levels": Vector2i(45, 50),
		"camps": [["sand_lion", 3], ["brigand", 3], ["thornscale_basilisk", 2], ["harpy", 2], ["sand_lion", 1]],
	},
}
const CASTLE_SIZE: Vector2i = Vector2i(46, 40)
const CAMP_GAP: int = 12
## Clearings walled in by woods this big or bigger get a trail out (_connect); smaller pockets
## are just glades.
const POCKET: int = 24
const WALKABLE: String = ".,:=bdocv^msFY"
const TOWN_CLEAR: int = 12
const ROAD_CLEAR: int = 3
const COAST_LIMIT: int = 12
## Open ground kept round each point of interest in a spec's "keep" ({cell: tile}).
const KEEP_CLEAR: int = 4
## Plants a road or a trail cuts through (and a camp clears).
const CUTTABLE: String = "TKR"

var _layer: TileMapLayer
var _root: Node
var _rng := RandomNumberGenerator.new()
## The current island's land cells' steps to the sea (_coast_distances).
var _depth: Dictionary = {}
## The current island's open ground: grass, or sand in the desert.
var _soil: String = "."


func _initialize() -> void:
	var scene_root: Node = MapIO.load_scene()
	var changed: int = apply(scene_root)
	var error: Error = OK
	if changed > 0:
		error = MapIO.save_scene(scene_root)
	print("Painted the islands: %d changes (%s)" % [changed, error_string(error)])
	MapIO.free_scene(scene_root)
	quit(0 if error == OK else 1)


## Paints every island not yet painted; returns how many cells and markers changed.
func apply(scene_root: Node) -> int:
	_root = scene_root
	_layer = scene_root.get_node(MapIO.TERRAIN)
	_ensure_tiles()
	var changed: int = 0
	for id: String in ORDER:
		if scene_root.has_meta("island_" + id):
			continue
		changed += _island(id, ISLANDS[id])
		scene_root.set_meta("island_" + id, true)
	return changed


## The editor tile set has a tile for every terrain letter.
func _ensure_tiles() -> void:
	var source: TileSetAtlasSource = _layer.tile_set.get_source(0)
	var added: bool = false
	for index: int in TERRAINS.length():
		if not source.has_tile(Vector2i(index, 0)):
			source.create_tile(Vector2i(index, 0))
			source.get_tile_data(Vector2i(index, 0), 0).set_custom_data("terrain", TERRAINS[index])
			added = true
	if added:
		ResourceSaver.save(_layer.tile_set, _layer.tile_set.resource_path)


# ---------------------------------------------------------------- terrain access

func _tile(cell: Vector2i) -> String:
	var index: int = _layer.get_cell_atlas_coords(cell).x
	return "~" if index < 0 else TERRAINS[index]


func _paint(cell: Vector2i, tile: String) -> void:
	_layer.set_cell(cell, 0, Vector2i(TERRAINS.find(tile), 0))


static func _hash(cell: Vector2i, salt: int) -> int:
	var value: int = (cell.x * 73856093) ^ (cell.y * 19349663) ^ (salt * 83492791)
	value = (value ^ (value >> 13)) * 1274126177
	return (value ^ (value >> 16)) & 0x7fffffff


## Smooth value noise in [0, 1) with features about `period` cells across.
static func _noise(cell: Vector2i, period: float, salt: int) -> float:
	var g := Vector2(cell) / period
	var c := Vector2i(floori(g.x), floori(g.y))
	var f: Vector2 = g - Vector2(c)
	f = f * f * (Vector2(3, 3) - 2.0 * f)
	var a: float = (_hash(c, salt) % 1000) / 1000.0
	var b: float = (_hash(c + Vector2i(1, 0), salt) % 1000) / 1000.0
	var d: float = (_hash(c + Vector2i(0, 1), salt) % 1000) / 1000.0
	var e: float = (_hash(c + Vector2i(1, 1), salt) % 1000) / 1000.0
	return lerpf(lerpf(a, b, f.x), lerpf(d, e, f.x), f.y)


static func _fbm(cell: Vector2i, period: float, salt: int) -> float:
	return _noise(cell, period, salt) * 0.55 + _noise(cell, period / 2.0, salt + 1) * 0.3 + _noise(cell, period / 4.0, salt + 2) * 0.15


# ---------------------------------------------------------------- one island

func _island(id: String, spec: Dictionary) -> int:
	var rect: Rect2i = spec["rect"]
	var salt: int = spec["seed"]
	_rng.seed = salt
	_soil = ":" if spec.get("biome", "forest") == "desert" else "."
	var castle := Rect2i(spec["capital"]["at"], CASTLE_SIZE)
	var town_at: Vector2i = spec["town"]["at"]
	# Points of interest other passes placed (cave mouths, stairways; tools/generators/region.gd):
	# land with open ground round them, their own tile kept, and no camp on them.
	var keep: Dictionary = spec.get("keep", {})
	var kept_areas: Array = []
	for cell: Vector2i in keep:
		kept_areas.append(Rect2i(cell - Vector2i.ONE * KEEP_CLEAR, Vector2i.ONE * (KEEP_CLEAR * 2 + 1)))
	var land: Dictionary = _coast(rect, salt, [castle.grow(5), Rect2i(town_at - Vector2i(16, 13), Vector2i(32, 26))] + kept_areas)
	_depth = _coast_distances(land)
	var changed: int = land.size()
	if spec.get("biome", "forest") == "desert":
		_desert(land, salt)
	else:
		_landscape(land, salt)
	var reserved: Dictionary = {}
	changed += _castle(castle, spec, reserved)
	changed += _village(town_at, spec, reserved)
	var village := Rect2i(town_at - Vector2i(15, 12), Vector2i(31, 25))
	for area: Rect2i in kept_areas:
		for y: int in range(area.position.y, area.end.y):
			for x: int in range(area.position.x, area.end.x):
				var cell := Vector2i(x, y)
				if land.has(cell) and not castle.has_point(cell) and not village.has_point(cell) and not reserved.has(cell):
					_paint(cell, _soil)
	for cell: Vector2i in keep:
		_paint(cell, keep[cell])
		reserved[cell] = true
	var harbour: Vector2i = _harbour(castle, land)
	# Roads: the castle's gates to the village, the village out to the north shore, and the south
	# gate down to the south shore, so every part of the island is a walk from a gate.
	var east_gate := Vector2i(castle.end.x, castle.position.y + 27)
	var south_gate := Vector2i(castle.position.x + 23, castle.end.y)
	changed += _road(east_gate + Vector2i.RIGHT, town_at + Vector2i(-6, 0), land)
	changed += _road(town_at + Vector2i(0, -5), _shore(land, rect, Vector2i(town_at.x, rect.position.y)), land)
	changed += _road(town_at + Vector2i(6, 0), _shore(land, rect, Vector2i(rect.end.x, town_at.y + 30)), land)
	changed += _road(south_gate + Vector2i.DOWN, _shore(land, rect, Vector2i(south_gate.x + 10, rect.end.y)), land)
	changed += _zone(spec["capital"]["name"], castle.grow(1), castle.position + Vector2i(23, 31))
	changed += _zone(spec["town"]["name"], Rect2i(town_at - Vector2i(15, 12), Vector2i(31, 25)), Vector2i(-1, -1))
	changed += _ferry(id, spec, harbour)
	var reached: Dictionary = _connect(land, harbour)
	changed += _camps(id, spec, land, reached, [castle.grow(TOWN_CLEAR), Rect2i(town_at - Vector2i(15 + TOWN_CLEAR, 12 + TOWN_CLEAR),
		Vector2i(31 + TOWN_CLEAR * 2, 25 + TOWN_CLEAR * 2))] + kept_areas)
	return changed


## Land cells of the island: an ellipse with a coast that wanders, every `keep` rect always land,
## and only the largest connected piece kept (no unreachable islets). Paints them grass.
func _coast(rect: Rect2i, salt: int, keep: Array) -> Dictionary:
	var centre: Vector2 = Vector2(rect.get_center())
	var radius: Vector2 = Vector2(rect.size) / 2.0 - Vector2(6, 6)
	var raw: Dictionary = {}
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			var offset: Vector2 = (Vector2(cell) - centre) / radius
			var reach: float = 0.8 + (_fbm(cell, 40.0, salt) - 0.5) * 0.7 + (_noise(cell, 9.0, salt + 5) - 0.5) * 0.12
			var kept: bool = false
			for area: Rect2i in keep:
				kept = kept or area.has_point(cell)
			if kept or offset.length() < reach:
				raw[cell] = true
	# The largest piece.
	var best: Dictionary = {}
	var seen: Dictionary = {}
	for start: Vector2i in raw:
		if seen.has(start):
			continue
		var piece: Dictionary = {start: true}
		var queue: Array[Vector2i] = [start]
		seen[start] = true
		while not queue.is_empty():
			var cell: Vector2i = queue.pop_back()
			for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var next: Vector2i = cell + side
				if raw.has(next) and not seen.has(next):
					seen[next] = true
					piece[next] = true
					queue.append(next)
		if piece.size() > best.size():
			best = piece
	for cell: Vector2i in best:
		_paint(cell, _soil)
	return best


## The biome over the land: sand beaches, woods with clearings and lone trees, small lakes with a
## grassy rim, and rocky knolls inland.
func _landscape(land: Dictionary, salt: int) -> void:
	for cell: Vector2i in land:
		var depth: int = _depth[cell]
		if depth <= 2 and _noise(cell, 14.0, salt + 11) > 0.3:
			_paint(cell, ":")
			continue
		if depth > 10 and _fbm(cell, 34.0, salt + 21) > 0.72:
			_paint(cell, "~")
			continue
		if depth > 7 and _fbm(cell, 16.0, salt + 31) > 0.79:
			_paint(cell, "L")
			continue
		var wood: float = _fbm(cell, 22.0, salt + 41)
		if depth > 3 and (wood > 0.47 and _hash(cell, salt + 43) % 100 < 80 or wood > 0.36 and _hash(cell, salt + 47) % 100 < 9):
			_paint(cell, "T")
	# Lakes get a clear grassy rim, and no rock stands alone in the water.
	for cell: Vector2i in land:
		if _tile(cell) in ["T", "L"] and _near(cell, 1, "~"):
			_paint(cell, ".")


## The desert over the land: sand, mesas of bare rock, cactus groves and lone cacti, a few
## boulders, and oases: pools ringed with grass and palms (trees drawn as palms in Sunreach).
func _desert(land: Dictionary, salt: int) -> void:
	for cell: Vector2i in land:
		var depth: int = _depth[cell]
		if depth > 10 and _fbm(cell, 30.0, salt + 21) > 0.74:
			_paint(cell, "~")
		elif depth > 6 and _fbm(cell, 18.0, salt + 31) > 0.7:
			_paint(cell, "L")
		elif depth > 3 and _fbm(cell, 24.0, salt + 41) > 0.56 and _hash(cell, salt + 43) % 100 < 12:
			_paint(cell, "K")
		elif depth > 3 and _hash(cell, salt + 47) % 100 < 2:
			_paint(cell, "K" if _hash(cell, salt + 49) % 3 > 0 else "R")
	# Oases: grass three deep round each pool, palms on its outer ring, no rock at the water. The
	# sea's shore stays sand (pools lie deeper than 10, so their rings deeper than 7).
	for cell: Vector2i in land:
		if _tile(cell) == "~" or _depth[cell] < 8 or not _near(cell, 3, "~"):
			continue
		var palm: bool = not _near(cell, 1, "~") and _hash(cell, salt + 51) % 100 < 28
		_paint(cell, "T" if palm else ".")


## Steps from every land cell to the nearest sea (one breadth-first pass out from the shore),
## counted up to COAST_LIMIT.
static func _coast_distances(land: Dictionary) -> Dictionary:
	var distance: Dictionary = {}
	var queue: Array[Vector2i] = []
	for cell: Vector2i in land:
		for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i(1, 1), Vector2i(-1, 1),
				Vector2i(1, -1), Vector2i(-1, -1)]:
			if not land.has(cell + side):
				distance[cell] = 1
				queue.append(cell)
				break
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		if distance[cell] >= COAST_LIMIT:
			continue
		for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + side
			if land.has(next) and not distance.has(next):
				distance[next] = distance[cell] + 1
				queue.append(next)
	for cell: Vector2i in land:
		if not distance.has(cell):
			distance[cell] = COAST_LIMIT + 1
	return distance


func _near(cell: Vector2i, distance: int, tiles: String) -> bool:
	for dy: int in range(-distance, distance + 1):
		for dx: int in range(-distance, distance + 1):
			if (dx != 0 or dy != 0) and _tile(cell + Vector2i(dx, dy)) in tiles:
				return true
	return false


## A land cell on the coast nearest to `toward`, a couple of cells in from the water.
func _shore(land: Dictionary, rect: Rect2i, toward: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var nearest: float = INF
	for cell: Vector2i in land:
		if _depth[cell] == 3 and (_tile(cell) in [".", ":"] or _tile(cell) in CUTTABLE):
			var d: float = Vector2(cell).distance_squared_to(Vector2(toward))
			if d < nearest:
				nearest = d
				best = cell
	return best if best.x >= 0 else rect.get_center()


# ---------------------------------------------------------------- the castle capital

## The castle: curtain walls ("W") with corner towers, towers by the gates and along the walls,
## gates west (harbour), east, and south, cobbled streets, houses, and the keep. Returns changes.
func _castle(castle: Rect2i, spec: Dictionary, reserved: Dictionary) -> int:
	var changed: int = 0
	for y: int in range(castle.position.y - 1, castle.end.y + 1):
		for x: int in range(castle.position.x - 1, castle.end.x + 1):
			var cell := Vector2i(x, y)
			var edge: bool = x == castle.position.x or y == castle.position.y or x == castle.end.x - 1 or y == castle.end.y - 1
			var outside: bool = not castle.has_point(cell)
			_paint(cell, _soil if outside else ("W" if edge else "="))
			reserved[cell] = true
			changed += 1
	var o: Vector2i = castle.position
	var s: Vector2i = castle.size
	# Towers: 2 x 2 blocks of wall at the corners, beside each gate, and along the long walls.
	var towers: Array[Vector2i] = [o, o + Vector2i(s.x - 2, 0), o + Vector2i(0, s.y - 2), o + Vector2i(s.x - 2, s.y - 2)]
	for x: int in [12, 32]:
		towers.append(o + Vector2i(x, 0))
	for y: int in [12]:
		towers.append(o + Vector2i(0, y))
		towers.append(o + Vector2i(s.x - 2, y))
	# Gates (3 wide) with a tower either side: west and east at row 27, south at column 23.
	for gate: Array in [[Vector2i(0, 26), Vector2i(0, 1)], [Vector2i(s.x - 1, 26), Vector2i(0, 1)], [Vector2i(22, s.y - 1), Vector2i(1, 0)]]:
		var start: Vector2i = o + gate[0]
		var along: Vector2i = gate[1]
		for step: int in 3:
			_paint(start + along * step, "=")
		var before: Vector2i = start - along * 2
		var after: Vector2i = start + along * 3
		for corner: Vector2i in [before, after]:
			var block: Vector2i = corner
			if along.y != 0:
				block.x = o.x if gate[0].x == 0 else o.x + s.x - 2
			else:
				block.y = o.y + s.y - 2
			towers.append(block)
	for tower: Vector2i in towers:
		for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
			_paint(tower + offset, "W")
	_townsfolk(String(spec["capital"]["vendor"]), String(spec["capital"]["name"]), o + Vector2i(18, 27), "vendor")
	# The keep, top centre; its door opens on the avenue to the south gate.
	changed += _keep(o + Vector2i(12, 2))
	# Houses: a column down each side of the keep, and two pairs either side of the avenue.
	for at: Vector2i in [Vector2i(3, 3), Vector2i(3, 11), Vector2i(3, 18), Vector2i(36, 3), Vector2i(36, 11), Vector2i(36, 18)]:
		changed += _house(o + at, Vector2i(7, 6), Vector2i.RIGHT if at.x < 20 else Vector2i.LEFT)
	# The market square below the keep (Zone.square), open between them from the keep to the
	# south gate.
	for at: Vector2i in [Vector2i(3, 30), Vector2i(10, 30), Vector2i(30, 30), Vector2i(37, 30)]:
		changed += _house(o + at, Vector2i(7, 6), Vector2i.UP)
	_townsfolk(String(spec["capital"]["artisan"]), String(spec["capital"]["name"]), o + Vector2i(28, 27), "artisan")
	return changed


## A house: stone walls ("#") round a cobbled floor with a doorway in the middle of the side facing
## `door`.
func _house(at: Vector2i, size: Vector2i, door: Vector2i) -> int:
	for y: int in size.y:
		for x: int in size.x:
			var edge: bool = x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1
			_paint(at + Vector2i(x, y), "#" if edge else "=")
	var gap: Vector2i
	match door:
		Vector2i.RIGHT:
			gap = at + Vector2i(size.x - 1, size.y / 2)
		Vector2i.LEFT:
			gap = at + Vector2i(0, size.y / 2)
		Vector2i.UP:
			gap = at + Vector2i(size.x / 2, 0)
		_:
			gap = at + Vector2i(size.x / 2, size.y - 1)
	_paint(gap, "=")
	return size.x * size.y


## The keep (the owner's castle reference): a hall 21 wide whose lower part narrows to 15, a
## living wing north of it, fieldstone walls wherever the floor meets anything else, a carpet from
## the door to the throne, and the furnishings. `at` is the wing's top-left corner.
func _keep(at: Vector2i) -> int:
	var floors: Dictionary = {}
	for area: Rect2i in [Rect2i(at + Vector2i(6, 1), Vector2i(9, 4)), Rect2i(at + Vector2i(1, 6), Vector2i(19, 8)),
			Rect2i(at + Vector2i(4, 14), Vector2i(13, 7))]:
		for y: int in range(area.position.y, area.end.y):
			for x: int in range(area.position.x, area.end.x):
				floors[Vector2i(x, y)] = true
	var walls: Dictionary = {}
	for cell: Vector2i in floors:
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var next: Vector2i = cell + Vector2i(dx, dy)
				if not floors.has(next):
					walls[next] = true
	for cell: Vector2i in walls:
		_paint(cell, "#")
	for cell: Vector2i in floors:
		_paint(cell, "F")
	var wing_door: Vector2i = at + Vector2i(10, 5)
	var door: Vector2i = at + Vector2i(10, 21)
	_paint(wing_door, "F")
	_paint(door, "F")
	for y: int in range(at.y + 8, at.y + 21):
		for x: int in range(at.x + 7, at.x + 14):
			_paint(Vector2i(x, y), "Y")
	_paint(door + Vector2i.DOWN, "=")
	var decor: Array = [
		# The hall: the throne at the head of the carpet, pillars in rows, statues by the wing's door.
		["throne", Vector2i(10, 7)], ["knight_statue", Vector2i(8, 6)], ["knight_statue", Vector2i(12, 6)],
		["pillar", Vector2i(3, 8)], ["pillar", Vector2i(17, 8)], ["pillar", Vector2i(3, 12)], ["pillar", Vector2i(17, 12)],
		["pillar", Vector2i(5, 16)], ["pillar", Vector2i(15, 16)], ["pillar", Vector2i(5, 19)], ["pillar", Vector2i(15, 19)],
		["flower_vase", Vector2i(1, 6)], ["flower_vase", Vector2i(19, 6)], ["potted_palm", Vector2i(1, 13)],
		["potted_palm", Vector2i(19, 13)], ["flower_vase", Vector2i(4, 20)], ["flower_vase", Vector2i(16, 20)],
		# Banners and torches on the hall's north wall, a painting and a torch in the wing.
		["banner", Vector2i(2, 5)], ["wall_torch", Vector2i(4, 5)], ["banner", Vector2i(7, 5)], ["banner", Vector2i(13, 5)],
		["wall_torch", Vector2i(16, 5)], ["banner", Vector2i(18, 5)], ["painting", Vector2i(8, 0)], ["wall_torch", Vector2i(12, 0)],
		# The living wing.
		["shelf_books", Vector2i(6, 1)], ["chest", Vector2i(8, 1)], ["bed", Vector2i(13, 1)], ["chair", Vector2i(7, 3)],
		["candelabra", Vector2i(8, 3)], ["chair", Vector2i(12, 3)], ["fruit_table", Vector2i(13, 3)], ["stove", Vector2i(14, 4)],
		["crate", Vector2i(6, 4)],
		# Outside the door: gargoyles on plinths and bushes.
		["gargoyle", Vector2i(8, 22)], ["gargoyle", Vector2i(12, 22)], ["bush", Vector2i(7, 22)], ["bush", Vector2i(13, 22)],
	]
	for entry: Array in decor:
		_decor(entry[0], at + entry[1])
	return floors.size() + walls.size() + decor.size()


func _decor(kind: String, cell: Vector2i) -> void:
	var group: Node = _group("Decor")
	var marker := Marker2D.new()
	marker.name = "Decor_%d_%d" % [cell.x, cell.y]
	marker.set_script(DECOR_SCRIPT)
	marker.position = (Vector2(cell) + Vector2(0.5, 0.5)) * TILE
	marker.set("kind", kind)
	group.add_child(marker)
	marker.owner = _root


func _group(group_name: String) -> Node:
	if _root.has_node(group_name):
		return _root.get_node(group_name)
	var group := Node2D.new()
	group.name = group_name
	_root.add_child(group)
	group.owner = _root
	return group


# ---------------------------------------------------------------- the village

## The smaller town: a cobbled square with four houses round it, doors on the square, and the
## village trader on it.
func _village(centre: Vector2i, spec: Dictionary, reserved: Dictionary) -> int:
	var area := Rect2i(centre - Vector2i(15, 12), Vector2i(31, 25))
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var cell := Vector2i(x, y)
			reserved[cell] = true
			if _tile(cell) in ["T", "L", "~", ":", "K", "R"]:
				_paint(cell, _soil)
	for y: int in range(-3, 4):
		for x: int in range(-4, 5):
			_paint(centre + Vector2i(x, y), "=")
	var changed: int = area.size.x * area.size.y
	changed += _house(centre + Vector2i(-13, -10), Vector2i(7, 6), Vector2i.DOWN)
	changed += _house(centre + Vector2i(6, -10), Vector2i(7, 6), Vector2i.DOWN)
	changed += _house(centre + Vector2i(-13, 5), Vector2i(7, 6), Vector2i.UP)
	changed += _house(centre + Vector2i(6, 5), Vector2i(7, 6), Vector2i.UP)
	# Paths from each door to the square.
	for door: Vector2i in [centre + Vector2i(-10, -4), centre + Vector2i(9, -4), centre + Vector2i(-10, 4), centre + Vector2i(9, 4)]:
		var cell: Vector2i = door
		while absi(cell.x - centre.x) > 4:
			_paint(cell, "=")
			cell.x += signi(centre.x - cell.x)
	_townsfolk(String(spec["town"]["vendor"]), String(spec["town"]["name"]), centre + Vector2i(-2, -1), "vendor")
	_townsfolk(String(spec["town"]["artisan"]), String(spec["town"]["name"]), centre + Vector2i(2, 1), "artisan")
	return changed


func _townsfolk(npc_name: String, place: String, cell: Vector2i, role: String) -> void:
	var marker := Marker2D.new()
	marker.name = place.to_snake_case() + "_" + role
	marker.set_script(TOWNSFOLK_SCRIPT)
	marker.position = (Vector2(cell) + Vector2(0.5, 0.5)) * TILE
	marker.set("npc_name", npc_name)
	marker.set("place", place)
	marker.set("role", role)
	marker.set("facing", Vector2i.DOWN)
	_group("Townsfolk").add_child(marker)
	marker.owner = _root


# ---------------------------------------------------------------- roads, harbour, zones

## A dirt road (two wide) along the cheapest way over the island: open ground is cheap, woods
## cost more (the trees are cut), rock is avoided, water is bridged at a price. Cobbles stay.
func _road(from: Vector2i, to: Vector2i, land: Dictionary) -> int:
	var astar := AStarGrid2D.new()
	var bounds := Rect2i(from, Vector2i.ONE).expand(to).grow(40)
	astar.region = bounds
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()
	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			var cell := Vector2i(x, y)
			var tile: String = _tile(cell)
			if not land.has(cell) or tile in ["L", "W", "#", "F", "Y"]:
				astar.set_point_solid(cell, true)
			else:
				astar.set_point_weight_scale(cell, float({"T": 4.0, "K": 4.0, "R": 4.0, "~": 14.0, "=": 0.6, ",": 0.5}.get(tile, 1.0)))
	if not astar.is_in_boundsv(from) or not astar.is_in_boundsv(to) or astar.is_point_solid(from) or astar.is_point_solid(to):
		return 0
	var path: Array[Vector2i] = astar.get_id_path(from, to)
	for index: int in path.size():
		var cell: Vector2i = path[index]
		var across := Vector2i.RIGHT
		if index + 1 < path.size() and path[index + 1].x != cell.x:
			across = Vector2i.DOWN
		for side: Vector2i in [Vector2i.ZERO, across]:
			var spot: Vector2i = cell + side
			if not land.has(spot):
				continue
			var tile: String = _tile(spot)
			if tile == "~":
				_paint(spot, "b")
			elif tile in [".", ":"] or tile in CUTTABLE:
				_paint(spot, ",")
	return path.size()


## The harbour: a cobbled way out of the west gate to the shore, then a pier three wide into the
## sea with the ferryman at its end. Returns the ferryman's cell.
func _harbour(castle: Rect2i, land: Dictionary) -> Vector2i:
	var cell := Vector2i(castle.position.x - 1, castle.position.y + 27)
	while land.has(cell) and cell.x > castle.position.x - 60:
		for dy: int in [-1, 0, 1]:
			_paint(cell + Vector2i(0, dy), "=")
		cell += Vector2i.LEFT
	for step: int in 6:
		for dy: int in [-1, 0, 1]:
			_paint(cell + Vector2i(-step, dy), "b")
	return cell + Vector2i(-5, 0)


func _zone(zone_name: String, area: Rect2i, square: Vector2i) -> int:
	var zone := Node2D.new()
	zone.name = zone_name.to_pascal_case()
	zone.set_script(ZONE_SCRIPT)
	zone.position = Vector2(area.position) * TILE
	zone.set("zone_name", zone_name)
	zone.set("size_tiles", area.size)
	zone.set("town", true)
	zone.set("min_level", 1)
	zone.set("max_level", 50)
	zone.set("square", square)
	_group("Zones").add_child(zone)
	zone.owner = _root
	return 1


## The capital's ferryman, and the mainland port's route back.
func _ferry(id: String, spec: Dictionary, cell: Vector2i) -> int:
	var port: String = spec["port"][0]
	var fare: int = spec["port"][1]
	var ferrymen: Node = _group("Ferrymen")
	var marker := Marker2D.new()
	marker.name = id
	marker.set_script(FERRY_SCRIPT)
	marker.position = (Vector2(cell) + Vector2(0.5, 0.5)) * TILE
	marker.set("npc_name", spec["capital"]["ferryman"])
	marker.set("place", spec["capital"]["name"])
	var routes: Dictionary[String, int] = {port: fare}
	marker.set("routes", routes)
	marker.set("facing", Vector2i.RIGHT)
	marker.set("vehicle", "ferry")
	ferrymen.add_child(marker)
	marker.owner = _root
	if ferrymen.has_node(port):
		var back: Dictionary[String, int] = ferrymen.get_node(port).get("routes")
		back[id] = fare
		ferrymen.get_node(port).set("routes", back)
	return 1


## Every sizeable clearing reached on foot from the harbour: flood out from the pier over the
## walkable land; each clearing the woods wall in (POCKET cells or more) gets a grass trail cut
## through the trees to the nearest reached ground. Returns the reached cells.
func _connect(land: Dictionary, harbour: Vector2i) -> Dictionary:
	var reached: Dictionary = {}
	_flood([harbour], land, reached)
	var cells: Array = land.keys()
	cells.sort()
	for start: Vector2i in cells:
		if reached.has(start) or not _tile(start) in WALKABLE:
			continue
		var pocket: Dictionary = {}
		_flood([start], land, pocket)
		for cell: Vector2i in pocket:
			if not reached.has(cell):
				reached[cell] = false
		if pocket.size() < POCKET:
			continue
		# A trail from the pocket's first cell to the nearest reached cell, through the trees.
		var goal := Vector2i(-1, -1)
		var nearest: float = INF
		for cell: Vector2i in reached:
			if reached[cell] and Vector2(cell).distance_squared_to(Vector2(start)) < nearest:
				nearest = Vector2(cell).distance_squared_to(Vector2(start))
				goal = cell
		if goal.x < 0:
			continue
		var astar := AStarGrid2D.new()
		astar.region = Rect2i(start, Vector2i.ONE).expand(goal).grow(12)
		astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
		astar.update()
		for y: int in range(astar.region.position.y, astar.region.end.y):
			for x: int in range(astar.region.position.x, astar.region.end.x):
				var cell := Vector2i(x, y)
				var tile: String = _tile(cell)
				if not land.has(cell) or not (tile in WALKABLE or tile in CUTTABLE):
					astar.set_point_solid(cell, true)
				elif tile in CUTTABLE:
					astar.set_point_weight_scale(cell, 3.0)
		if astar.is_point_solid(start) or astar.is_point_solid(goal):
			continue
		for cell: Vector2i in astar.get_id_path(start, goal):
			if _tile(cell) in CUTTABLE:
				_paint(cell, _soil)
		_flood([start], land, reached)
	for cell: Vector2i in reached.keys():
		if not reached[cell]:
			reached.erase(cell)
	return reached


## Marks every walkable land cell connected to `starts` as reached (true).
func _flood(starts: Array, land: Dictionary, reached: Dictionary) -> void:
	var queue: Array[Vector2i] = []
	for start: Vector2i in starts:
		if _tile(start) in WALKABLE and not reached.get(start, false):
			reached[start] = true
			queue.append(start)
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + side
			if not reached.get(next, false) and (land.has(next) or _tile(next) == "b") and _tile(next) in WALKABLE:
				reached[next] = true
				queue.append(next)


## Placeholder hunting camps: tight packs of 5-7 on open meadow, apart from each other, the towns,
## and the roads, each clearing the trees round it.
func _camps(id: String, spec: Dictionary, land: Dictionary, reached: Dictionary, keep_out: Array) -> int:
	var spots: Array[Vector2i] = []
	var cells: Array = land.keys()
	cells.sort()
	for cell: Vector2i in cells:
		if _hash(cell, int(spec["seed"]) + 61) % 23 != 0 or _depth[cell] < 5:
			continue
		var blocked: bool = false
		for area: Rect2i in keep_out:
			blocked = blocked or area.has_point(cell)
		if blocked or _tile(cell) != _soil or not reached.has(cell) or _near(cell, ROAD_CLEAR, ",=b~L"):
			continue
		var crowded: bool = false
		for other: Vector2i in spots:
			crowded = crowded or Vector2(cell).distance_to(Vector2(other)) < CAMP_GAP
		if not crowded:
			spots.append(cell)
	# Then the gaps: open ground still out of sight of every camp gets one of its own.
	for cell: Vector2i in cells:
		if not reached.has(cell) or not _tile(cell) in [".", ":"] or _near(cell, 1, ",=b~"):
			continue
		var blocked: bool = false
		for area: Rect2i in keep_out:
			blocked = blocked or area.has_point(cell)
		if blocked or spots.any(func(other: Vector2i) -> bool: return maxi(absi(other.x - cell.x), absi(other.y - cell.y)) <= 10):
			continue
		spots.append(cell)
	var weights: Array = spec["camps"]
	var total: int = 0
	for entry: Array in weights:
		total += int(entry[1])
	var levels: Vector2i = spec["levels"]
	var spawns: Node = _group("MonsterSpawns")
	for index: int in spots.size():
		var cell: Vector2i = spots[index]
		for dy: int in range(-2, 3):
			for dx: int in range(-2, 3):
				if _tile(cell + Vector2i(dx, dy)) in CUTTABLE:
					_paint(cell + Vector2i(dx, dy), _soil)
		var pick: int = _hash(cell, 71) % total
		var monster: String = ""
		for entry: Array in weights:
			pick -= int(entry[1])
			if pick < 0:
				monster = entry[0]
				break
		var marker := Marker2D.new()
		marker.name = "Island_%s_%d" % [id, index]
		marker.set_script(SPAWN_SCRIPT)
		marker.position = (Vector2(cell) + Vector2(0.5, 0.5)) * TILE
		marker.set("monster", monster)
		marker.set("level", levels.x + _hash(cell, 73) % (levels.y - levels.x + 1))
		marker.set("count", 5 + _hash(cell, 79) % 3)
		marker.set("radius", 2)
		spawns.add_child(marker)
		marker.owner = _root
	return spots.size()
