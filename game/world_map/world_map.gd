extends RefCounted
## The world's map (plan 48): everything known about the map once it is loaded, read-only at runtime.
## The terrain grid (from the baked map, game/maps/map_io.gd), the markers (spawns, items, NPCs, zones,
## monster camps, stairways, cave mouths), the ways between floors, the town buildings with their
## signs and furniture, and the named regions; and the lookups on them (terrain, walkable, zone_at,
## region_at, npc, ...). The rules that change the world live in game/core/.

const Quests = preload("res://game/data/quests.gd")
const Dungeons = preload("res://game/data/dungeons.gd")
const Caves = preload("res://game/data/caves.gd")
const Atlas = preload("res://game/data/atlas.gd")
const MapIO = preload("res://game/maps/map_io.gd")
const Buildings = preload("res://game/data/buildings.gd")
const Regions = preload("res://game/data/regions.gd")
const Monsters = preload("res://game/data/monsters.gd")

## Talking range to an NPC (World.TALK_RANGE): a keeper's furniture must leave it reachable.
const TALK_RANGE: int = 2
## The world is painted in Godot's TileMap editor; see docs/world-editing.md.
const MAP_SCENE: String = "res://game/maps/overworld.tscn"
## Terrain characters: grass, dirt road, water, stone wall, tree, sand, cobblestone, pier/bridge,
## the Hollow Reach's dusk soil, obsidian floor, obsidian wall, and dead tree, and the
## dungeons' cave floor, cave wall, stairs down (a dungeon entrance), and stairs up (its exit),
## the desert's cacti and thorn scrub (on sand), boulders, mountain rock, and castle walls (town
## curtain walls and towers, see SpriteArt.tower), bog mud and giant mushrooms, snow and snowy
## firs, and the castles' sandstone flag floor (F) and carpet (Y; its fringe follows its outline).
const TERRAINS: String = ".,~#T:=bdoODcCv^KRLWmUsPFY"
const WALKABLE: String = ".,:=bdocv^msFY"
const LAND: String = ".,:=docv^msFY"
## Drawn as oblique walls / as trees; both block movement and line of sight.
const WALLS: String = "#OCLW"
const TREES: String = "TDKRUP"
## Loaded from MAP_SCENE and its sectors (MapIO): the terrain as one byte per cell (row-major;
## "~" for unpainted overworld, " " for unpainted cells beyond it; terrain() returns a cached
## one-character string), spawn cells, starting ground items, and ferrymen {id: {name, place,
## cell, facing, routes: {id: fare}}}.
static var GRID: PackedByteArray
static var GRID_SIZE: Vector2i = Vector2i.ZERO
static var _CHARS: Array[String] = []
static var SPAWNS: Array[Vector2i] = []
static var GROUND_ITEMS: Array = []
static var STARTING_CELLS: Dictionary = {}
static var FERRYMEN: Dictionary = {}
## Quest NPCs by node name: name, place, cell, facing, services (["quests"]), and task (a
## Quests.TASKS id, or "" for the Relic keeper).
static var QUEST_GIVERS: Dictionary = {}
## Vendors, bankers, artisans, and wardens by node name: name, place, cell, facing, role, services
## (["trade"], ["bank"], ["craft"], or ["pvp"]).
static var TOWNSFOLK: Dictionary = {}
## Cell -> NPC id (ferryman, quest giver, or townsfolk); NPCs block their tile.
static var NPC_CELLS: Dictionary = {}
## Gameplay zones {name, rect (tiles), pvp, min_level, max_level}; the first match wins.
static var ZONES: Array = []
## Overworld monster spawns {monster, level, count, radius, cell}; Combat.populate fills them.
static var MONSTER_SPAWNS: Array = []
## Dungeon stairways down: cell -> dungeon id, and dungeon id -> cell.
static var DUNGEON_ENTRANCES: Dictionary = {}
static var ENTRANCE_OF: Dictionary = {}
## Elite cave mouths (game/data/caves.gd): cell -> cave id, and cave id -> cell; and each cave's
## stairs up (its "^" cell), where players arrive and leave.
static var CAVE_MOUTHS: Dictionary = {}
static var MOUTH_OF: Dictionary = {}
## Ways between the floors (Atlas.FLOOR_X): stairs up ("^") on one floor and the hole or ladder
## ("v") right above them on the next, each cell -> the other.
static var HOLES: Dictionary = {}
## The painted part of each floor other than the surface: z -> Rect2i (MapIO).
static var FLOOR_BOUNDS: Dictionary = {}
static var CAVE_STAIRS: Dictionary = {}
## The walkable world players reach on foot (Atlas.OVERWORLD_SIZE); dungeon copies lie right of it.
static var OVERWORLD: Rect2i = Rect2i()
## The part of the overworld anyone painted: everything outside it is open deep sea, so passes
## over all the land (bot navigation, gathering nodes, checks) only need to cover this.
static var PAINTED: Rect2i = Rect2i()
## Town buildings (game/data/buildings.gd), found from the walls: {rect, interior, doors,
## footprint, outward}. ROOF_AT maps each footprint cell to its building's index, ROOM_AT each
## interior or doorway cell. Someone inside a building is only reached from inside it.
static var BUILDINGS: Array = []
static var ROOF_AT: Dictionary = {}
static var ROOM_AT: Dictionary = {}
## A sign hangs on the wall beside the door of each vendor's and banker's building:
## {cell (that wall), outward (door direction), kind (the keeper's role)}.
static var SIGNS: Array = []
## Lamp posts on town streets (World._decorate_streets), lit at night.
static var LAMPS: Array[Vector2i] = []
## Shop and bank furniture: cell -> kind (SpriteArt.FURNITURE). It blocks movement like an NPC.
static var FURNITURE: Dictionary = {}
## Decorations hung on walls (Decor markers on wall cells): cell -> kind (SpriteArt.WALL_DECOR).
static var WALL_DECOR: Dictionary = {}
## Cells of furniture placed by Decor markers (castles), which may stand outside buildings.
static var DECOR_CELLS: Dictionary = {}
## Named regions (game/data/regions.gd) on a grid of REGION_BLOCK x REGION_BLOCK tiles over PAINTED (an index
## into REGION_NAMES per block), and per region {min_level, max_level, centre} derived from the
## monster spawns and tiles inside it.
const REGION_BLOCK: int = 4
## Cells round a world map page that its painting looks at (shallows and surf near land).
const MAP_PAGE_REACH: int = 3
static var REGION_GRID: PackedByteArray
static var REGION_NAMES: Array[String] = []
static var REGION_INFO: Dictionary = {}
## Furniture around a keeper, standing at the back of their building facing the door:
## [steps toward the door, steps across, kind]. Pieces that would block the room are skipped.
## Laid out as the trade would be: a shopkeeper behind a counter three wide with the stock on
## shelves either side and spare goods at the ends; a banker behind the counter with strongboxes
## and ledgers at hand; a workshop with the forge and its anvil on one side, the workbench and loom
## on the other, and the brewing cauldron and a water barrel behind the master. A "fallback" spot
## is tried only when its kind found no place yet.
const FURNISHINGS: Dictionary = {
	"vendor": [[1, 0, "counter_shop"], [1, -1, "counter_shop"], [1, 1, "counter_shop"], [0, 1, "shelf_potions"],
		[0, -1, "shelf_potions"], [0, 2, "weapon_rack"], [0, -2, "barrel"], [-1, 2, "crate"], [-1, -2, "crate"]],
	"banker": [[1, 0, "counter_bank"], [1, -1, "counter_bank"], [1, 1, "counter_bank"], [0, 1, "strongbox"],
		[0, -1, "strongbox"], [0, 2, "shelf_books"], [0, -2, "shelf_books"]],
	"artisan": [[0, 2, "hearth"], [1, 2, "anvil"], [0, -2, "workbench"],
		# Narrow workshops: the tools nearer the master, where the far spots are wall (the forge,
		# anvil, and bench come before the rest).
		[0, 1, "hearth", "fallback"], [1, 1, "anvil", "fallback"], [2, 1, "anvil", "fallback"], [0, -1, "workbench", "fallback"],
		[1, -1, "anvil", "fallback"], [2, -2, "anvil", "fallback"], [2, -1, "anvil", "fallback"], [1, -2, "anvil", "fallback"],
		[1, -1, "workbench", "fallback"],
		[1, -2, "loom"], [-1, 1, "cauldron"], [-1, -1, "barrel"], [0, 3, "crate"],
		[1, -1, "loom", "fallback"], [2, -1, "loom", "fallback"], [2, 1, "cauldron", "fallback"], [2, -1, "cauldron", "fallback"]],
}
## A home's furniture, in the order it is placed: one piece per HOME_TILES tiles of floor (at
## least HOME_MIN), along the walls and in the corners, never beside the door, and never cutting
## any floor off from the door (World._furnish_homes).
const HOME_PIECES: Array[String] = ["bed", "chest", "table", "chair", "plant", "shelf_books", "barrel", "plant"]
const HOME_TILES: int = 4
const HOME_MIN: int = 3
## Street furniture: a lamp post every LAMP_GAP tiles or more against the walls along the cobbled
## streets (World._against_wall), and on each town's most open square a market round a fountain
## (3x3; a well where it does not fit): benches facing it from north and south, and two rows of
## stalls facing each other across the square with their stock in crates and barrels behind.
## Nothing is placed where it could split a street (World._splits) or beside a door.
const LAMP_GAP: int = 7
## How many open spots, nearest each town's centre first, are weighed for its market square.
const SQUARE_TRIES: int = 40
const SQUARE_PIECES: Array = [[Vector2i(0, 0), "fountain"],
	[Vector2i(-1, -3), "bench"], [Vector2i(1, -3), "bench"], [Vector2i(-1, 3), "bench_back"], [Vector2i(1, 3), "bench_back"],
	[Vector2i(-4, -5), "stall"], [Vector2i(-2, -5), "stall"], [Vector2i(2, -5), "stall"], [Vector2i(4, -5), "stall"],
	[Vector2i(-3, -6), "crate"], [Vector2i(3, -6), "barrel"],
	[Vector2i(-4, 5), "stall_back"], [Vector2i(-2, 5), "stall_back"], [Vector2i(2, 5), "stall_back"], [Vector2i(4, 5), "stall_back"],
	[Vector2i(-3, 6), "barrel"], [Vector2i(3, 6), "crate"]]
static var MAP_HASH: String = ""


static func _static_init() -> void:
	# The map as plain data (MapIO): from the bake, or from the scene when the bake is stale.
	var data: Dictionary = MapIO.read_map()
	var markers: Dictionary = data["markers"]
	GRID = data["grid"]
	GRID_SIZE = data["size"]
	PAINTED = data["painted"]
	FLOOR_BOUNDS = data.get("floors", {})
	_CHARS.clear()
	for code: int in 256:
		_CHARS.append(String.chr(code) if code > 0 else "")
	for marker: Dictionary in markers.get("Spawns", []):
		SPAWNS.append(marker["cell"])
	for marker: Dictionary in markers.get("Items", []):
		GROUND_ITEMS.append([marker["cell"], String(marker.get("item"))])
		STARTING_CELLS[marker["cell"]] = true
	for marker: Dictionary in markers.get("Ferrymen", []):
		var routes: Dictionary = {}
		var fares: Dictionary = marker.get("routes")
		for destination: Variant in fares:
			routes[String(destination)] = int(fares[destination])
		FERRYMEN[String(marker["name"])] = {
			"name": String(marker.get("npc_name")), "place": String(marker.get("place")),
			"cell": marker["cell"], "facing": marker.get("facing"), "routes": routes, "services": ["travel"],
			"vehicle": String(marker.get("vehicle")) if marker.get("vehicle") != null else "ferry",
		}
		NPC_CELLS[marker["cell"]] = String(marker["name"])
	if markers.has("QuestGivers"):
		for marker: Dictionary in markers["QuestGivers"]:
			# A giver offers every task naming it (game/data/quests.gd), plus its marker's task.
			var tasks: Array[String] = Quests.tasks_of(String(marker["name"]))
			var own: String = String(marker.get("task")) if marker.get("task") != null else ""
			if not own.is_empty() and Quests.TASKS.has(own) and own not in tasks:
				tasks.push_front(own)
			QUEST_GIVERS[String(marker["name"])] = {
				"name": String(marker.get("npc_name")), "place": String(marker.get("place")),
				"cell": marker["cell"], "facing": marker.get("facing"),
				"services": ["vocation", "runes"] if Quests.TRAINERS.has(String(marker["name"])) else ["quests"],
				"tasks": tasks, "boss": String(Quests.RELIC_KEEPERS.get(String(marker["name"]), "")),
			}
			NPC_CELLS[marker["cell"]] = String(marker["name"])
	if markers.has("Townsfolk"):
		for marker: Dictionary in markers["Townsfolk"]:
			var role: String = String(marker.get("role"))
			TOWNSFOLK[String(marker["name"])] = {
				"name": String(marker.get("npc_name")), "place": String(marker.get("place")),
				"cell": marker["cell"], "facing": marker.get("facing"), "role": role,
				"services": {"banker": ["bank"], "artisan": ["craft"], "warden": ["pvp"]}.get(role, ["trade"]),
			}
			NPC_CELLS[marker["cell"]] = String(marker["name"])
	if markers.has("Zones"):
		for marker: Dictionary in markers["Zones"]:
			ZONES.append({
				"name": String(marker.get("zone_name")), "rect": Rect2i(marker["cell"], marker.get("size_tiles")),
				"pvp": bool(marker.get("pvp")) and not bool(marker.get("town")), "full_loot": bool(marker.get("full_loot")),
				"town": bool(marker.get("town")), "min_level": int(marker.get("min_level")),
				"max_level": int(marker.get("max_level")),
			})
			if marker.get("ambient") is Color and marker.get("ambient") != Color.WHITE:
				ZONES[-1]["ambient"] = marker.get("ambient")
			if marker.get("square") is Vector2i and (marker.get("square") as Vector2i).x >= 0:
				ZONES[-1]["square"] = marker.get("square")
			# Zones on a floor below (tunnels and sewers) are underground: dim, dry, no mounts.
			if floor_of_rect(ZONES[-1]["rect"]) < 0:
				ZONES[-1]["underground"] = true
	if markers.has("DungeonEntrances"):
		for marker: Dictionary in markers["DungeonEntrances"]:
			var dungeon: String = String(marker.get("dungeon"))
			if Dungeons.DUNGEONS.has(dungeon):
				DUNGEON_ENTRANCES[marker["cell"]] = dungeon
				ENTRANCE_OF[dungeon] = marker["cell"]
	if markers.has("CaveMouths"):
		for marker: Dictionary in markers["CaveMouths"]:
			var cave: String = String(marker.get("cave"))
			if Caves.CAVES.has(cave):
				CAVE_MOUTHS[marker["cell"]] = cave
				MOUTH_OF[cave] = marker["cell"]
	# Every elite cave is an underground zone too, shared by everyone.
	for cave: String in Caves.ORDER:
		var definition: Dictionary = Caves.CAVES[cave]
		ZONES.append({
			"name": definition["name"], "rect": Caves.rect(cave), "pvp": false, "full_loot": false, "town": false,
			"underground": true, "ambient": definition["ambient"], "cave": cave,
			"min_level": definition["min_level"], "max_level": definition["max_level"],
		})
	# Every dungeon copy is an underground zone: a fixed dim light, and monsters stay inside.
	for dungeon: String in Dungeons.DUNGEONS:
		var definition: Dictionary = Dungeons.DUNGEONS[dungeon]
		for copy: int in definition["copies"]:
			ZONES.append({
				"name": definition["name"], "rect": Dungeons.rect(dungeon, copy), "pvp": false, "full_loot": false,
				"town": false, "underground": true, "ambient": definition["ambient"], "dungeon": dungeon, "copy": copy,
				"dark": definition.get("dark", false),
				"min_level": definition["min_level"], "max_level": definition["max_level"],
			})
	if markers.has("MonsterSpawns"):
		for marker: Dictionary in markers["MonsterSpawns"]:
			MONSTER_SPAWNS.append({
				"monster": String(marker.get("monster")), "level": int(marker.get("level")),
				"count": int(marker.get("count")), "radius": int(marker.get("radius")), "cell": marker["cell"],
			})
	# Decor markers (castles): furniture on open ground, decorations on walls. Placed before the
	# keepers furnish their buildings, so nothing is put on top of them.
	if markers.has("Decor"):
		for marker: Dictionary in markers["Decor"]:
			var kind: String = String(marker.get("kind"))
			if terrain(marker["cell"]) in WALLS:
				WALL_DECOR[marker["cell"]] = kind
			else:
				FURNITURE[marker["cell"]] = kind
				DECOR_CELLS[marker["cell"]] = true
	_find_buildings()
	_place_dungeon_props()
	for cave: String in Caves.ORDER:
		var area: Rect2i = Caves.rect(cave)
		for y: int in range(area.position.y, area.end.y):
			for x: int in range(area.position.x, area.end.x):
				if terrain(Vector2i(x, y)) == "^":
					CAVE_STAIRS[cave] = Vector2i(x, y)
	OVERWORLD = Rect2i(Vector2i.ZERO, Atlas.OVERWORLD_SIZE)
	_pair_holes()
	_map_regions()
	# The terrain bytes are hashed as they are (joining every row into one string costs more).
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(GRID)
	hashing.update((str(GRID_SIZE) + str(SPAWNS) + str(GROUND_ITEMS) + str(FERRYMEN) + str(QUEST_GIVERS) + str(TOWNSFOLK)
		+ str(ZONES) + str(MONSTER_SPAWNS) + str(WALL_DECOR) + str(FURNITURE) + str(DUNGEON_ENTRANCES) + str(Dungeons.DUNGEONS) + str(CAVE_MOUTHS)).to_utf8_buffer())
	MAP_HASH = hashing.finish().hex_encode()


## The painted part of floor z (the overworld for the surface; empty where nothing is painted):
## what its map shows and where bots route on it.
static func floor_bounds(z: int) -> Rect2i:
	return OVERWORLD if z == 0 else FLOOR_BOUNDS.get(z, Rect2i())


## The floor a rectangle lies on when it lies wholly on one (Atlas.NO_FLOOR otherwise).
static func floor_of_rect(rect: Rect2i) -> int:
	var z: int = Atlas.floor_of(rect.position)
	return z if z != Atlas.NO_FLOOR and Atlas.plane(z).encloses(rect) else Atlas.NO_FLOOR


## HOLES: every stairs up ("^") on a floor with a hole or ladder ("v") right above it on the next
## (found with the grid's own search: stairs are few, the floors are large).
static func _pair_holes() -> void:
	HOLES.clear()
	var up: int = "^".unicode_at(0)
	var at: int = GRID.find(up)
	while at >= 0:
		var cell := Vector2i(at % GRID_SIZE.x, at / GRID_SIZE.x)
		var over: Vector2i = Atlas.above(cell)
		if over.x >= 0 and terrain(over) == "v":
			HOLES[cell] = over
			HOLES[over] = cell
		at = GRID.find(up, at + 1)


## Buildings in town zones, and the signs of the shops and banks among them.
static func _find_buildings() -> void:
	var known: Dictionary = {}
	for zone: Dictionary in ZONES:
		if not zone["town"]:
			continue
		for building: Dictionary in Buildings.find(terrain, zone["rect"].grow(1)):
			if known.has(building["rect"]):
				continue
			known[building["rect"]] = true
			var index: int = BUILDINGS.size()
			BUILDINGS.append(building)
			for cell: Vector2i in building["footprint"]:
				ROOF_AT[cell] = index
			for cell: Vector2i in building["interior"] + building["doors"]:
				ROOM_AT[cell] = index
	var ids: Array = TOWNSFOLK.keys()
	ids.sort()
	for id: String in ids:
		var keeper: Dictionary = TOWNSFOLK[id]
		if not ROOM_AT.has(keeper["cell"]):
			continue
		var building: Dictionary = BUILDINGS[ROOM_AT[keeper["cell"]]]
		var door: Vector2i = building["doors"][0]
		var outward: Vector2i = building["outward"][door]
		var across := Vector2i(absi(outward.y), absi(outward.x))
		for side: Vector2i in [across, -across] if outward.y != 0 else [-across, across]:
			if terrain(door + side) in WALLS:
				SIGNS.append({"cell": door + side, "outward": outward, "kind": keeper["role"]})
				break
		_furnish(building, keeper)
	_furnish_homes()
	_decorate_streets()


## Barrels and crates from the dungeon layouts (Dungeons.props), in every copy.
static func _place_dungeon_props() -> void:
	for dungeon: String in Dungeons.ORDER:
		for copy: int in Dungeons.DUNGEONS[dungeon]["copies"]:
			for prop: Array in Dungeons.props(dungeon):
				FURNITURE[Dungeons.origin(dungeon, copy) + prop[0]] = prop[1]


## Places a keeper's furniture, skipping any piece on a marker or one that would cut a room
## cell (or every cell in talking range of the keeper) off from the entrance.
static func _furnish(building: Dictionary, keeper: Dictionary) -> void:
	var toward: Vector2i = keeper["facing"]
	var across := Vector2i(absi(toward.y), absi(toward.x))
	var door: Vector2i = building["doors"][0]
	var entrance: Vector2i = door - building["outward"][door]
	var taken: Dictionary = {}
	for spawn: Vector2i in SPAWNS:
		taken[spawn] = true
	for entry: Array in GROUND_ITEMS:
		taken[entry[0]] = true
	var placed: Dictionary = {}
	for piece: Array in FURNISHINGS.get(keeper["role"], []):
		if piece.size() > 3 and placed.has(piece[2]):
			continue
		var cell: Vector2i = keeper["cell"] + toward * int(piece[0]) + across * int(piece[1])
		if cell == entrance or taken.has(cell) or NPC_CELLS.has(cell) or FURNITURE.has(cell) \
				or not building["interior"].has(cell) or terrain(cell) != "=" or _hidden_by_wall(cell):
			continue
		FURNITURE[cell] = piece[2]
		if not _room_open(building, entrance, keeper["cell"]):
			FURNITURE.erase(cell)
		else:
			placed[piece[2]] = true


## Furnishes every town building nobody keeps (no townsfolk, quest giver, spawn, or stairway in
## it) as a home: a bed, a chest, a table and its chair, a plant, then shelves and a barrel in
## bigger rooms, corners first, then along the walls.
static func _furnish_homes() -> void:
	for building: Dictionary in BUILDINGS:
		var interior: Array[Vector2i] = building["interior"]
		var lived: bool = interior.any(func(cell: Vector2i) -> bool:
			return NPC_CELLS.has(cell) or FURNITURE.has(cell) or SPAWNS.has(cell) or terrain(cell) != "=")
		if lived:
			continue
		var door: Vector2i = building["doors"][0]
		var entrance: Vector2i = door - building["outward"][door]
		var items: Dictionary = {}
		for entry: Array in GROUND_ITEMS:
			items[entry[0]] = true
		var spots: Array[Vector2i] = []
		for cell: Vector2i in interior:
			if chebyshev(cell, entrance) > 1 and not items.has(cell) and _walls_beside(cell) > 0 and not _hidden_by_wall(cell):
				spots.append(cell)
		# Corners (two walls beside) first, then the rest of the walls, in a fixed shuffled order.
		spots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var walls_a: int = _walls_beside(a)
			var walls_b: int = _walls_beside(b)
			return walls_a > walls_b if walls_a != walls_b else (a.x * 31 + a.y * 17) % 13 < (b.x * 31 + b.y * 17) % 13)
		var wanted: int = clampi(interior.size() / HOME_TILES, HOME_MIN, HOME_PIECES.size())
		var table := Vector2i(-1, -1)
		for index: int in wanted:
			var kind: String = HOME_PIECES[index]
			var choices: Array[Vector2i] = spots.duplicate()
			if kind == "chair" and table.x >= 0:
				# The chair goes beside the table if it can, else along a wall like the rest.
				choices.assign(interior.filter(func(cell: Vector2i) -> bool:
					return chebyshev(cell, table) == 1 and (cell - table).x * (cell - table).y == 0 and chebyshev(cell, entrance) > 1))
				choices.append_array(spots)
			for cell: Vector2i in choices:
				if FURNITURE.has(cell):
					continue
				FURNITURE[cell] = kind
				if _room_open(building, entrance, entrance):
					if kind == "table":
						table = cell
					break
				FURNITURE.erase(cell)


## Lamp posts along each town's cobbled streets and a furnished square around a well.
static func _decorate_streets() -> void:
	var doors: Dictionary = {}
	for building: Dictionary in BUILDINGS:
		for door: Vector2i in building["doors"]:
			doors[door] = true
	var keep: Dictionary = {}
	for cell: Vector2i in SPAWNS:
		keep[cell] = true
	for entry: Array in GROUND_ITEMS:
		keep[entry[0]] = true
	var free: Callable = func(cell: Vector2i) -> bool:
		if terrain(cell) != "=" or ROOM_AT.has(cell) or not walkable(cell) or keep.has(cell):
			return false
		# Never in or beside a doorway or a gate (an opening in a wall line) or a person.
		for side: Vector2i in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i(1, 1),
				Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var near: Vector2i = cell + side
			if doors.has(near) or NPC_CELLS.has(near) or terrain(near) in ["v", "b"] or Buildings.is_door(terrain, near):
				return false
			if side.x * side.y == 0 and _in_gap(near):
				return false
		return not _splits(cell)
	for zone: Dictionary in ZONES:
		if not zone["town"]:
			continue
		var rect: Rect2i = zone["rect"]
		# The square: of the open cobbled tiles (40 of the 49 round them open), the one where most
		# of the market fits; the SQUARE_TRIES nearest the town's centre are tried, ring by ring.
		var centre: Vector2i = rect.get_center()
		var inner: Rect2i = rect.grow(-3)
		var candidates: Array[Vector2i] = []
		if zone.has("square"):
			candidates.append(zone["square"])
		for ring: int in maxi(rect.size.x, rect.size.y) / 2:
			if candidates.size() >= SQUARE_TRIES:
				break
			for dy: int in range(-ring, ring + 1):
				for dx: int in range(-ring, ring + 1):
					if maxi(absi(dx), absi(dy)) != ring:
						continue
					var cell: Vector2i = centre + Vector2i(dx, dy)
					if not inner.has_point(cell) or terrain(cell) != "=" or ROOM_AT.has(cell):
						continue
					var open: int = 0
					for oy: int in range(-3, 4):
						for ox: int in range(-3, 4):
							var near: Vector2i = cell + Vector2i(ox, oy)
							open += 1 if terrain(near) == "=" and walkable(near) and not ROOM_AT.has(near) else 0
					if open >= 40:
						candidates.append(cell)
		var best := Vector2i(-1, -1)
		var best_fit: int = -1
		for cell: Vector2i in candidates.slice(0, SQUARE_TRIES):
			var fit: int = 0
			for piece: Array in SQUARE_PIECES:
				fit += 1 if free.call(cell + piece[0]) else 0
			for side: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
				fit -= 0 if free.call(cell + side) else 4
			if fit > best_fit:
				best = cell
				best_fit = fit
			if best_fit == SQUARE_PIECES.size():
				break
		if best_fit >= 0:
			for piece: Array in SQUARE_PIECES:
				var cell: Vector2i = best + piece[0]
				if piece[1] == "fountain":
					# The fountain takes all nine tiles or none, drawn from the bottom-middle one.
					var basin: Array[Vector2i] = []
					for dy: int in range(-1, 2):
						for dx: int in range(-1, 2):
							basin.append(cell + Vector2i(dx, dy))
					if basin.all(func(spot: Vector2i) -> bool: return free.call(spot)):
						for spot: Vector2i in basin:
							FURNITURE[spot] = "fountain_basin"
						FURNITURE[cell + Vector2i.DOWN] = "fountain"
					elif free.call(cell):
						FURNITURE[cell] = "well"
				elif free.call(cell):
					FURNITURE[cell] = piece[1]
		# Lamps: against a house or town wall with at least two open tiles in front (never out in
		# a lane, where they would block the way), LAMP_GAP apart, and a tile in from the town's
		# edge so the split test sees all round.
		for y: int in range(rect.position.y + 1, rect.end.y - 1):
			for x: int in range(rect.position.x + 1, rect.end.x - 1):
				var cell := Vector2i(x, y)
				# Cheapest tests first: the street and lamp spacing, then the full free-tile check.
				if terrain(cell) != "=" or not LAMPS.all(func(lamp: Vector2i) -> bool: return chebyshev(lamp, cell) >= LAMP_GAP):
					continue
				if not _against_wall(cell) or not free.call(cell):
					continue
				FURNITURE[cell] = "lamp_post"
				LAMPS.append(cell)


## Whether blocking `cell` could cut a way: its walkable neighbours (all eight, in a ring) must
## form a single run, and at least four of them must be walkable.
static func _splits(cell: Vector2i) -> bool:
	var ring: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1),
		Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0)]
	var open: Array[bool] = []
	for step: Vector2i in ring:
		open.append(walkable(cell + step))
	var count: int = open.count(true)
	if count < 4:
		return true
	var runs: int = 0
	for index: int in ring.size():
		if open[index] and not open[index - 1]:
			runs += 1
	# A diagonal-only connection does not count: an open corner needs an open side next to it.
	for index: int in [0, 2, 4, 6]:
		if open[index] and not open[index - 1] and not open[(index + 1) % 8]:
			return true
	return runs > 1


## Whether a cell lies in a narrow opening of a wall line (a gate up to three tiles wide):
## walls within two steps on both sides along a row or a column.
static func _in_gap(cell: Vector2i) -> bool:
	for axis: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
		var ahead: bool = false
		var behind: bool = false
		for step: int in range(1, 3):
			ahead = ahead or terrain(cell + axis * step) in WALLS
			behind = behind or terrain(cell - axis * step) in WALLS
		if ahead and behind:
			return true
	return false


## Whether a cell stands against a wall with open ground in front of it (two tiles deep) and to
## both sides along it: a lamp there leaves the way past it free.
static func _against_wall(cell: Vector2i) -> bool:
	for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var along := Vector2i(side.y, side.x)
		if terrain(cell + side) in WALLS and walkable(cell - side) and walkable(cell - side * 2) \
				and walkable(cell + along) and walkable(cell - along):
			return true
	return false


## Whether a wall east of a cell hides it: house walls stand a full tile tall, drawn up and to the
## left of their own tile (SpriteArt.HOUSE_RAISE), over the tile west of them.
static func _hidden_by_wall(cell: Vector2i) -> bool:
	return terrain(cell + Vector2i.RIGHT) == "#"


## How many of a cell's four sides are walls.
static func _walls_beside(cell: Vector2i) -> int:
	var walls: int = 0
	for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		walls += 1 if terrain(cell + side) in WALLS else 0
	return walls


static func _room_open(building: Dictionary, entrance: Vector2i, keeper: Vector2i) -> bool:
	var reached: Dictionary = {entrance: true}
	var queue: Array[Vector2i] = [entrance]
	var talk: bool = false
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		talk = talk or chebyshev(cell, keeper) <= TALK_RANGE
		for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + side
			if not reached.has(next) and building["interior"].has(next) and walkable(next):
				reached[next] = true
				queue.append(next)
	for cell: Vector2i in building["interior"]:
		if walkable(cell) and not reached.has(cell):
			return false
	return talk


## Assigns each block of the overworld to a region and derives each region's level range.
static func _map_regions() -> void:
	REGION_NAMES = Regions.names()
	# Over the painted overworld only (from its corner); open sea beyond takes its nearest block.
	var blocks := Vector2i(ceili(PAINTED.size.x / float(REGION_BLOCK)), ceili(PAINTED.size.y / float(REGION_BLOCK)))
	REGION_GRID = PackedByteArray()
	REGION_GRID.resize(blocks.x * blocks.y)
	var sums: Dictionary = {}
	for by: int in blocks.y:
		for bx: int in blocks.x:
			var centre := PAINTED.position + Vector2i(bx * REGION_BLOCK + REGION_BLOCK / 2, by * REGION_BLOCK + REGION_BLOCK / 2)
			var name: String = Regions.name_at(centre)
			REGION_GRID[by * blocks.x + bx] = REGION_NAMES.find(name)
			if OVERWORLD.has_point(centre) and terrain(centre) in LAND:
				var sum: Array = sums.get_or_add(name, [Vector2.ZERO, 0])
				sum[0] += Vector2(centre)
				sum[1] += 1
	for name: String in REGION_NAMES:
		var sum: Array = sums.get(name, [Vector2.ZERO, 0])
		REGION_INFO[name] = {"min_level": 0, "max_level": 0,
			"centre": Vector2i((sum[0] / maxf(1.0, sum[1])).round())}
	for spawn: Dictionary in MONSTER_SPAWNS:
		# Raid bosses are not the region's hunting level.
		if not OVERWORLD.has_point(spawn["cell"]) or not zone_at(spawn["cell"]).is_empty() \
				or Monsters.MONSTERS[spawn["monster"]]["rank"] == "boss":
			continue
		var info: Dictionary = REGION_INFO[region_at(spawn["cell"])]
		info["min_level"] = spawn["level"] if info["min_level"] == 0 else mini(info["min_level"], spawn["level"])
		info["max_level"] = maxi(info["max_level"], spawn["level"])


## The region name at an overworld tile ("" outside the overworld; open sea away from the
## painted land counts as the nearest painted tile's region).
static func region_at(cell: Vector2i) -> String:
	if not OVERWORLD.has_point(cell):
		return ""
	var local: Vector2i = cell.clamp(PAINTED.position, PAINTED.end - Vector2i.ONE) - PAINTED.position
	var columns: int = ceili(PAINTED.size.x / float(REGION_BLOCK))
	return REGION_NAMES[REGION_GRID[(local.y / REGION_BLOCK) * columns + local.x / REGION_BLOCK]]


## Where a tile is, for the HUD: {name, kind ("town", "pvp", "dungeon", or "region"), min_level,
## max_level}; levels are 0 for towns and for regions without monsters.
static func location_at(cell: Vector2i) -> Dictionary:
	var zone: Dictionary = zone_at(cell)
	if not zone.is_empty():
		var kind: String = "town" if zone["town"] else ("dungeon" if zone.get("underground", false) else ("pvp" if zone["pvp"] else "region"))
		return {"name": zone["name"], "kind": kind, "min_level": 0 if zone["town"] else zone["min_level"],
			"max_level": 0 if zone["town"] else zone["max_level"]}
	var name: String = region_at(cell)
	if name.is_empty():
		return {}
	return {"name": name, "kind": "region", "min_level": REGION_INFO[name]["min_level"], "max_level": REGION_INFO[name]["max_level"]}


## Whether `cell` and `other` are on the same side of every building wall: both outside, or
## both inside (or in the doorway of) the same building.
static func same_room(cell: Vector2i, other: Vector2i) -> bool:
	return ROOM_AT.get(cell, -1) == ROOM_AT.get(other, -1)


## The town with the (one) bank and depot, or "".
static func bank_place() -> String:
	for id: String in TOWNSFOLK:
		if TOWNSFOLK[id]["role"] == "banker":
			return TOWNSFOLK[id]["place"]
	return ""


## A ferryman, quest giver, vendor, or banker by id, or {}.
static func npc(id: String) -> Dictionary:
	return FERRYMEN.get(id, QUEST_GIVERS.get(id, TOWNSFOLK.get(id, {})))


## The dungeon copy containing a cell as [dungeon id, copy index], or [] in the overworld.
static func dungeon_at(cell: Vector2i) -> Array:
	if OVERWORLD.has_point(cell):
		return []
	var zone: Dictionary = zone_at(cell)
	return [zone["dungeon"], zone["copy"]] if zone.has("dungeon") else []


static func zone_at(cell: Vector2i) -> Dictionary:
	for zone: Dictionary in ZONES:
		if zone["rect"].has_point(cell):
			return zone
	return {}


## The continent (Atlas.CONTINENTS) a cell lies on, or "" off the overworld or in open sea.
static func continent_at(cell: Vector2i) -> String:
	return Atlas.continent_at(cell)


static func width() -> int:
	return GRID_SIZE.x


static func height() -> int:
	return GRID_SIZE.y


## The world map pages (Atlas sectors) the overworld needs: every one near painted land. The rest
## are open deep sea and drawn as such.
static func map_pages() -> Array[Vector2i]:
	return Atlas.sectors_in(PAINTED.grow(MAP_PAGE_REACH).intersection(OVERWORLD))


## What a world map page is painted from, hashed: its terrain, the shore within MAP_PAGE_REACH
## around it, its roofs, and its towns. The baker (tools/generators/world_map.gd) stores it, so a
## page edited since shows its stale bake.
static func page_hash(sector: Vector2i) -> String:
	var area: Rect2i = Atlas.sector_rect(sector).grow(MAP_PAGE_REACH).intersection(Rect2i(Vector2i.ZERO, GRID_SIZE))
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	for y: int in range(area.position.y, area.end.y):
		hashing.update(GRID.slice(y * GRID_SIZE.x + area.position.x, y * GRID_SIZE.x + area.end.x))
	var roofs: int = 0
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			if ROOF_AT.has(Vector2i(x, y)):
				roofs += 1
	var towns: Array[Rect2i] = []
	for zone: Dictionary in ZONES:
		if zone["town"] and (zone["rect"] as Rect2i).intersects(area):
			towns.append(zone["rect"])
	hashing.update((str(roofs) + str(towns)).to_utf8_buffer())
	return hashing.finish().hex_encode()


static func terrain(cell: Vector2i) -> String:
	if cell.x < 0 or cell.y < 0 or cell.x >= GRID_SIZE.x or cell.y >= GRID_SIZE.y:
		return ""
	return _CHARS[GRID[cell.y * GRID_SIZE.x + cell.x]]


static func walkable(cell: Vector2i) -> bool:
	var tile: String = terrain(cell)
	return not tile.is_empty() and tile != " " and tile in WALKABLE and not NPC_CELLS.has(cell) and not FURNITURE.has(cell)


static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
