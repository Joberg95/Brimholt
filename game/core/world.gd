extends RefCounted

const Balance = preload("res://game/data/balance.gd")
const Items = preload("res://game/data/items.gd")
const Quests = preload("res://game/data/quests.gd")
const Dungeons = preload("res://game/data/dungeons.gd")
const Buildings = preload("res://game/data/buildings.gd")

const TILE_SIZE: int = 32
const WORLD_NAME: String = "Cinder Crossing"
## The world is painted in Godot's TileMap editor; see docs/world-editing.md.
const MAP_SCENE: String = "res://game/maps/overworld.tscn"
## Terrain characters: grass, dirt road, water, stone wall, tree, sand, cobblestone, pier/bridge,
## the Hollow Reach's dusk soil, obsidian floor, obsidian wall, and dead tree, and the
## dungeons' cave floor, cave wall, stairs down (a dungeon entrance), and stairs up (its exit),
## and the desert's cacti and thorn scrub (on sand).
const TERRAINS: String = ".,~#T:=bdoODcCv^K"
const WALKABLE: String = ".,:=bdocv^"
const LAND: String = ".,:=docv^"
## Drawn as oblique walls / as trees; both block movement and line of sight.
const WALLS: String = "#OC"
const TREES: String = "TDK"
## Loaded from MAP_SCENE: terrain rows (" " for unpainted cells), spawn cells, starting
## ground items, and ferrymen {id: {name, place, cell, facing, routes: {id: fare}}}.
static var ROWS: PackedStringArray
## The same terrain as one byte per cell (row-major), for per-cell lookups: indexing ROWS copies
## a whole row string, so terrain() reads GRID and returns a cached one-character string.
static var GRID: PackedByteArray
static var GRID_SIZE: Vector2i = Vector2i.ZERO
static var _CHARS: Array[String] = []
static var SPAWNS: Array[Vector2i] = []
static var GROUND_ITEMS: Array = []
static var _STARTING_CELLS: Dictionary = {}
static var FERRYMEN: Dictionary = {}
## Quest NPCs by node name: name, place, cell, facing, services (["quests"]), and task (a
## Quests.TASKS id, or "" for the Relic keeper).
static var QUEST_GIVERS: Dictionary = {}
## Vendors and bankers by node name: name, place, cell, facing, role, services (["trade"] or ["bank"]).
static var TOWNSFOLK: Dictionary = {}
## Cell -> NPC id (ferryman, quest giver, vendor, or banker); NPCs block their tile.
static var NPC_CELLS: Dictionary = {}
## Gameplay zones {name, rect (tiles), pvp, min_level, max_level}; the first match wins.
static var ZONES: Array = []
## Overworld monster spawns {monster, level, count, radius, cell}; Combat.populate fills them.
static var MONSTER_SPAWNS: Array = []
## Dungeon stairways down: cell -> dungeon id, and dungeon id -> cell.
static var DUNGEON_ENTRANCES: Dictionary = {}
static var ENTRANCE_OF: Dictionary = {}
## The walkable world players reach on foot; dungeon copies lie right of it.
static var OVERWORLD: Rect2i = Rect2i()
## Town buildings (game/data/buildings.gd), found from the walls: {rect, interior, doors,
## footprint, outward}. ROOF_AT maps each footprint cell to its building's index, ROOM_AT each
## interior or doorway cell. Someone inside a building is only reached from inside it.
static var BUILDINGS: Array = []
static var ROOF_AT: Dictionary = {}
static var ROOM_AT: Dictionary = {}
## A sign hangs on the wall beside the door of each vendor's and banker's building:
## {cell (that wall), outward (door direction), kind (the keeper's role)}.
static var SIGNS: Array = []
## Shop and bank furniture: cell -> kind (SpriteArt.FURNITURE). It blocks movement like an NPC.
static var FURNITURE: Dictionary = {}
## Furniture around a keeper, standing at the back of their building facing the door:
## [steps toward the door, steps across, kind]. Pieces that would block the room are skipped.
const FURNISHINGS: Dictionary = {
	"vendor": [[1, 0, "counter_shop"], [0, 1, "shelf_potions"], [0, -1, "weapon_rack"], [0, 2, "barrel"], [0, -2, "crate"]],
	"banker": [[1, 0, "counter_bank"], [0, 1, "shelf_books"], [0, -1, "strongbox"], [0, 2, "shelf_books"], [0, -2, "strongbox"]],
}
static var MAP_HASH: String = ""
const MOVE_SECONDS: float = 0.18
const MAX_PLAYERS: int = 12
const PORT: int = 1234
const PROTOCOL: int = 8
const START_GOLD: int = 100
## Players must stand within this many tiles (in any direction) of a ferryman to sail.
const TALK_RANGE: int = 2
const TRAVEL_SECONDS: float = 1.0
## Equipment slots in paperdoll order. Each accepts items of one slot type; both rings take "ring".
## The bag slot holds a bound pack from a town task; packs are only ever replaced by a bigger one.
const SLOTS: Array[String] = ["necklace", "helmet", "cape", "main_hand", "armor", "off_hand", "ring_1", "charm", "ring_2", "bag"]
const SLOT_TYPES: Dictionary = {
	"necklace": "necklace", "helmet": "helmet", "cape": "cape", "charm": "charm", "main_hand": "main_hand",
	"armor": "armor", "off_hand": "off_hand", "ring_1": "ring", "ring_2": "ring", "bag": "bag",
}
## Item catalog from game/data/items.json (see game/data/items.gd): stats add to
## Balance.base_stats(level) when the wearer meets the item's level and vocation.
static var ITEMS: Dictionary = Items.load_catalog()
## Starting gear by vocation: tier-1 helmet, armor, weapon, and off-hand, in the backpack.
const START_KITS: Dictionary = {
	"knight": ["ember_cap", "moss_coat", "copper_blade", "oak_buckler"],
	"paladin": ["ember_cap", "moss_coat", "willow_shortbow", "oak_buckler"],
	"sorcerer": ["ember_cap", "moss_coat", "kindling_wand", "tattered_primer"],
	"druid": ["ember_cap", "moss_coat", "sapling_rod", "tattered_primer"],
}
## Backpack slots without a pack; a worn pack adds its "slots", up to BACKPACK_MAX.
const BACKPACK_SIZE: int = 8
const BACKPACK_MAX: int = 20
## Item depot slots, kept by the banker (one depot per player, at the one bank in Reedmere).
const DEPOT_SIZE: int = 24
const GROUND_STACK_MAX: int = 6
## Ground stacks left alone this long decay (Tibia-style), so a long session does not pile up
## every unlooted drop. Starting map items and bound items (relics) never decay.
const GROUND_DECAY_SECONDS: float = 900.0
const GROUND_SWEEP_SECONDS: float = 10.0
## Stackable items (materials, glowcaps, gold piles) share one backpack slot or ground entry,
## stored as "kind#count" (a plain "kind" is one). Equipment never stacks.
const STACK_MAX: int = 100
const ITEM_SECONDS: float = 0.15

var players: Dictionary = {}
## Live monsters by negative id; game/core/combat.gd owns their behaviour.
var monsters: Dictionary = {}
var ground: Dictionary = {}
## Per ground cell: [when its stack last changed (as seen by a sweep), the stack it had then].
var _ground_seen: Dictionary = {}
var _next_ground_sweep: float = 0.0


static func _static_init() -> void:
	var scene: Node = (load(MAP_SCENE) as PackedScene).instantiate()
	var layer: TileMapLayer = scene.get_node("Terrain")
	var lookup: Dictionary = {}
	for index: int in layer.tile_set.get_source_count():
		var source_id: int = layer.tile_set.get_source_id(index)
		var source: TileSetAtlasSource = layer.tile_set.get_source(source_id) as TileSetAtlasSource
		if source == null:
			continue
		for tile: int in source.get_tiles_count():
			var coords: Vector2i = source.get_tile_id(tile)
			var kind: Variant = source.get_tile_data(coords, 0).get_custom_data("terrain")
			if typeof(kind) == TYPE_STRING and kind.length() == 1 and kind in TERRAINS:
				lookup[Vector3i(source_id, coords.x, coords.y)] = kind
	var size: Vector2i = layer.get_used_rect().end
	var grid := PackedByteArray()
	grid.resize(size.x * size.y)
	grid.fill(32)
	for cell: Vector2i in layer.get_used_cells():
		var coords: Vector2i = layer.get_cell_atlas_coords(cell)
		var kind: String = lookup.get(Vector3i(layer.get_cell_source_id(cell), coords.x, coords.y), " ")
		if cell.x >= 0 and cell.y >= 0:
			grid[cell.y * size.x + cell.x] = kind.unicode_at(0)
	GRID = grid
	GRID_SIZE = size
	_CHARS.clear()
	for code: int in 256:
		_CHARS.append(String.chr(code) if code > 0 else "")
	ROWS = PackedStringArray()
	for y: int in size.y:
		ROWS.append(grid.slice(y * size.x, (y + 1) * size.x).get_string_from_ascii())
	for marker: Node2D in scene.get_node("Spawns").get_children():
		SPAWNS.append(_cell_of(marker))
	for marker: Node2D in scene.get_node("Items").get_children():
		GROUND_ITEMS.append([_cell_of(marker), String(marker.get("item"))])
		_STARTING_CELLS[_cell_of(marker)] = true
	for marker: Node2D in scene.get_node("Ferrymen").get_children():
		var routes: Dictionary = {}
		var fares: Dictionary = marker.get("routes")
		for destination: Variant in fares:
			routes[String(destination)] = int(fares[destination])
		FERRYMEN[String(marker.name)] = {
			"name": String(marker.get("npc_name")), "place": String(marker.get("place")),
			"cell": _cell_of(marker), "facing": marker.get("facing"), "routes": routes, "services": ["travel"],
			"vehicle": String(marker.get("vehicle")) if marker.get("vehicle") != null else "ferry",
		}
		NPC_CELLS[_cell_of(marker)] = String(marker.name)
	if scene.has_node("QuestGivers"):
		for marker: Node2D in scene.get_node("QuestGivers").get_children():
			QUEST_GIVERS[String(marker.name)] = {
				"name": String(marker.get("npc_name")), "place": String(marker.get("place")),
				"cell": _cell_of(marker), "facing": marker.get("facing"), "services": ["quests"],
				"task": String(marker.get("task")) if marker.get("task") != null else "",
			}
			NPC_CELLS[_cell_of(marker)] = String(marker.name)
	if scene.has_node("Townsfolk"):
		for marker: Node2D in scene.get_node("Townsfolk").get_children():
			var role: String = String(marker.get("role"))
			TOWNSFOLK[String(marker.name)] = {
				"name": String(marker.get("npc_name")), "place": String(marker.get("place")),
				"cell": _cell_of(marker), "facing": marker.get("facing"), "role": role,
				"services": ["bank"] if role == "banker" else ["trade"],
			}
			NPC_CELLS[_cell_of(marker)] = String(marker.name)
	if scene.has_node("Zones"):
		for marker: Node2D in scene.get_node("Zones").get_children():
			ZONES.append({
				"name": String(marker.get("zone_name")), "rect": Rect2i(_cell_of(marker), marker.get("size_tiles")),
				"pvp": bool(marker.get("pvp")) and not bool(marker.get("town")), "full_loot": bool(marker.get("full_loot")),
				"town": bool(marker.get("town")), "min_level": int(marker.get("min_level")),
				"max_level": int(marker.get("max_level")),
			})
			if marker.get("ambient") is Color and marker.get("ambient") != Color.WHITE:
				ZONES[-1]["ambient"] = marker.get("ambient")
	if scene.has_node("DungeonEntrances"):
		for marker: Node2D in scene.get_node("DungeonEntrances").get_children():
			var dungeon: String = String(marker.get("dungeon"))
			if Dungeons.DUNGEONS.has(dungeon):
				DUNGEON_ENTRANCES[_cell_of(marker)] = dungeon
				ENTRANCE_OF[dungeon] = _cell_of(marker)
	# Every dungeon copy is an underground zone: a fixed dim light, and monsters stay inside.
	for dungeon: String in Dungeons.DUNGEONS:
		var definition: Dictionary = Dungeons.DUNGEONS[dungeon]
		for copy: int in definition["copies"]:
			ZONES.append({
				"name": definition["name"], "rect": Dungeons.rect(dungeon, copy), "pvp": false, "full_loot": false,
				"town": false, "underground": true, "ambient": definition["ambient"], "dungeon": dungeon, "copy": copy,
				"min_level": definition["min_level"], "max_level": definition["max_level"],
			})
	if scene.has_node("MonsterSpawns"):
		for marker: Node2D in scene.get_node("MonsterSpawns").get_children():
			MONSTER_SPAWNS.append({
				"monster": String(marker.get("monster")), "level": int(marker.get("level")),
				"count": int(marker.get("count")), "radius": int(marker.get("radius")), "cell": _cell_of(marker),
			})
	scene.free()
	_find_buildings()
	OVERWORLD = Rect2i(0, 0, mini(size.x, Dungeons.BAND_X - Dungeons.COPY_GAP), size.y)
	MAP_HASH = ("".join(ROWS) + str(SPAWNS) + str(GROUND_ITEMS) + str(FERRYMEN) + str(QUEST_GIVERS) + str(TOWNSFOLK) + str(ZONES)
		+ str(MONSTER_SPAWNS) + str(DUNGEON_ENTRANCES) + str(Dungeons.DUNGEONS)).sha256_text()


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
	for piece: Array in FURNISHINGS.get(keeper["role"], []):
		var cell: Vector2i = keeper["cell"] + toward * int(piece[0]) + across * int(piece[1])
		if cell == entrance or taken.has(cell) or NPC_CELLS.has(cell) or FURNITURE.has(cell) \
				or not building["interior"].has(cell) or terrain(cell) != "=":
			continue
		FURNITURE[cell] = piece[2]
		if not _room_open(building, entrance, keeper["cell"]):
			FURNITURE.erase(cell)


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


## The id of an NPC offering `service` within TALK_RANGE of `cell`, or "".
static func npc_near(cell: Vector2i, service: String) -> String:
	for group: Dictionary in [FERRYMEN, QUEST_GIVERS, TOWNSFOLK]:
		for id: String in group:
			if service in group[id]["services"] and in_talk_range(cell, group[id]["cell"]):
				return id
	return ""


## Whether `npc` is a known NPC offering `service` and `cell` is within talking range of it.
static func serves(npc_id: Variant, service: String, cell: Vector2i) -> bool:
	if typeof(npc_id) != TYPE_STRING or not service in npc(npc_id).get("services", []):
		return false
	return in_talk_range(cell, npc(npc_id)["cell"])


## Within TALK_RANGE of an NPC and on the same side of any building wall.
static func in_talk_range(cell: Vector2i, npc_cell: Vector2i) -> bool:
	return chebyshev(cell, npc_cell) <= TALK_RANGE and same_room(cell, npc_cell)


## Relics and packs are bound to whoever earned them: never dropped, traded, or lost on death.
static func bound(entry: String) -> bool:
	var kind: String = kind_of(entry)
	return ITEMS.has(kind) and ITEMS[kind].get("bound", false)


## The item id of a backpack or ground entry ("wolf_pelt#12" -> "wolf_pelt").
static func kind_of(entry: String) -> String:
	return entry.get_slice("#", 0)


## How many items an entry holds (1 for a plain id, 0 for an empty slot).
static func count_of(entry: String) -> int:
	if entry.is_empty():
		return 0
	return maxi(1, entry.get_slice("#", 1).to_int()) if entry.contains("#") else 1


static func make_entry(kind: String, count: int) -> String:
	return kind if count <= 1 else "%s#%d" % [kind, count]


static func stackable(kind: String) -> bool:
	return ITEMS.has(kind) and ITEMS[kind]["slot"].is_empty()


## Adds an entry on top of a ground stack, merging into a matching stackable top entry.
## Returns false when the tile has no room (callers check walkability).
static func stack_onto(stack: Array, entry: String) -> bool:
	var kind: String = kind_of(entry)
	if not stack.is_empty() and stackable(kind) and kind_of(stack.back()) == kind \
			and count_of(stack.back()) + count_of(entry) <= STACK_MAX:
		stack[-1] = make_entry(kind, count_of(stack.back()) + count_of(entry))
		return true
	if stack.size() >= GROUND_STACK_MAX:
		return false
	stack.append(entry)
	return true


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


static func _cell_of(marker: Node2D) -> Vector2i:
	return Vector2i((marker.position / TILE_SIZE).floor())


static func width() -> int:
	return GRID_SIZE.x


static func height() -> int:
	return GRID_SIZE.y


static func terrain(cell: Vector2i) -> String:
	if cell.x < 0 or cell.y < 0 or cell.x >= GRID_SIZE.x or cell.y >= GRID_SIZE.y:
		return ""
	return _CHARS[GRID[cell.y * GRID_SIZE.x + cell.x]]


func _init() -> void:
	for entry: Array in GROUND_ITEMS:
		var cell: Vector2i = entry[0]
		if not ground.has(cell):
			ground[cell] = []
		stack_onto(ground[cell], entry[1])


static func walkable(cell: Vector2i) -> bool:
	var tile: String = terrain(cell)
	return not tile.is_empty() and tile != " " and tile in WALKABLE and not NPC_CELLS.has(cell) and not FURNITURE.has(cell)


static func signature() -> String:
	return (str(PROTOCOL) + str(TILE_SIZE) + str(MAX_PLAYERS) + MAP_HASH + str(ITEMS) + str(START_GOLD) \
		+ str(TALK_RANGE) + str(TRAVEL_SECONDS) \
		+ str(MOVE_SECONDS) + str(SLOTS) + str(START_KITS) + str(GROUND_ITEMS) + str(BACKPACK_SIZE) \
		+ str(GROUND_STACK_MAX) + str(ITEM_SECONDS) + str(SLOT_TYPES) + str(BACKPACK_MAX) + str(DEPOT_SIZE) \
		+ str(STACK_MAX) + str(Quests.TASKS) + str(Quests.PACKS) + Balance.signature()).sha256_text()


static func fits(kind: String, slot: String) -> bool:
	return ITEMS.has(kind) and SLOT_TYPES.has(slot) and ITEMS[kind]["slot"] == SLOT_TYPES[slot]


## Why `kind` cannot be worn at this level and vocation, or "" when it can.
static func requirement_error(kind: String, level: int, vocation: String) -> String:
	if not ITEMS.has(kind):
		return "Unknown item"
	var item: Dictionary = ITEMS[kind]
	if not item["vocations"].is_empty() and vocation not in item["vocations"]:
		var names: PackedStringArray = []
		for allowed: String in item["vocations"]:
			names.append(Balance.VOCATIONS[allowed]["name"] + "s")
		return "Only %s can use the %s" % [" and ".join(names), item["name"]]
	if level < item["level"]:
		return "The %s requires level %d" % [item["name"], item["level"]]
	return ""


static func start_kit(vocation: String) -> Array:
	return START_KITS.get(vocation, START_KITS[Balance.DEFAULT_VOCATION])


## The slot an item should be equipped into: the first empty fitting slot, else the first fitting one.
static func slot_for(kind: String, equipment: Dictionary) -> String:
	var fallback: String = ""
	for slot: String in SLOTS:
		if fits(kind, slot):
			if not equipment.has(slot):
				return slot
			if fallback.is_empty():
				fallback = slot
	return fallback


## Derived character stats: vocation and level base stats plus every equipped item's stats.
static func stats(level: int, equipment: Dictionary, vocation: String = Balance.DEFAULT_VOCATION) -> Dictionary:
	var result: Dictionary = Balance.base_stats(level, vocation)
	for slot: String in SLOTS:
		var kind: Variant = equipment.get(slot, "")
		if typeof(kind) == TYPE_STRING and requirement_error(kind, level, vocation).is_empty():
			var bonus: Dictionary = ITEMS[kind]["stats"]
			for stat: String in bonus:
				result[stat] += bonus[stat]
	return result


## Players and monsters block their tile and, while stepping, the tile they left.
func occupied(cell: Vector2i, now: float, except_id: int = 0) -> bool:
	for group: Dictionary in [players, monsters]:
		for id: int in group:
			if id == except_id:
				continue
			var creature: Dictionary = group[id]
			if creature["cell"] == cell:
				return true
			if now < creature["next_move"] and creature["from"] == cell:
				return true
	return false


## Every tile occupied() would report, built in one pass: use it when testing many tiles (path
## searches) instead of calling occupied() per tile, which scans every creature.
func occupied_cells(now: float, except_id: int = 0) -> Dictionary:
	var cells: Dictionary = {}
	for group: Dictionary in [players, monsters]:
		for id: int in group:
			if id == except_id:
				continue
			var creature: Dictionary = group[id]
			cells[creature["cell"]] = true
			if now < creature["next_move"]:
				cells[creature["from"]] = true
	return cells


func player_stats(id: int) -> Dictionary:
	var player: Dictionary = players[id]
	return stats(player["level"], player["equipment"], player["vocation"])


## Keeps health and mana within the maximums after gear or level changes.
func clamp_vitals(id: int) -> void:
	var player: Dictionary = players[id]
	var limits: Dictionary = player_stats(id)
	player["health"] = clampi(player["health"], 0, limits["health"])
	player["mana"] = clampi(player["mana"], 0, limits["mana"])


func add_player(id: int, now: float, vocation: String = Balance.DEFAULT_VOCATION) -> bool:
	if id <= 0 or players.has(id) or players.size() >= MAX_PLAYERS or not Balance.VOCATIONS.has(vocation):
		return false
	for cell: Vector2i in SPAWNS:
		if not occupied(cell, now):
			var backpack: Array = []
			backpack.resize(BACKPACK_SIZE)
			backpack.fill("")
			var depot: Array = []
			depot.resize(DEPOT_SIZE)
			depot.fill("")
			var kit: Array = start_kit(vocation)
			for index: int in kit.size():
				backpack[index] = kit[index]
			players[id] = {
				"id": id, "cell": cell, "from": cell, "next_move": now,
				"facing": Vector2i.DOWN, "equipment": {}, "backpack": backpack, "next_item": now,
				"level": 1, "experience": 0, "vocation": vocation, "gold": START_GOLD, "next_travel": now,
				"target": 0, "next_attack": now, "next_regen": now, "cooldowns": {}, "groups": {},
				"skull": "", "skull_until": 0.0, "unjustified": [], "aggressors": {},
				"party": 0, "invited": {}, "active_at": -INF, "trophies": {},
				"bank": 0, "depot": depot, "tasks": {}, "done_tasks": {},
			}
			var limits: Dictionary = stats(1, {}, vocation)
			players[id]["health"] = limits["health"]
			players[id]["mana"] = limits["mana"]
			return true
	return false


func remove_player(id: int) -> void:
	players.erase(id)


## Removes ground stacks unchanged for GROUND_DECAY_SECONDS, checking every GROUND_SWEEP_SECONDS.
## A stack's timer restarts whenever a sweep finds it changed. Returns ground events.
func decay_ground(now: float) -> Array:
	if now < _next_ground_sweep:
		return []
	_next_ground_sweep = now + GROUND_SWEEP_SECONDS
	var decayed: Array[Vector2i] = []
	for cell: Vector2i in _ground_seen.keys():
		if not ground.has(cell):
			_ground_seen.erase(cell)
	for cell: Vector2i in ground.keys():
		var stack: Array = ground[cell]
		var seen: Array = _ground_seen.get(cell, [])
		if seen.is_empty() or seen[1] != stack:
			_ground_seen[cell] = [now, stack.duplicate()]
		elif now - seen[0] >= GROUND_DECAY_SECONDS and not _STARTING_CELLS.has(cell) and not stack.any(bound):
			ground.erase(cell)
			_ground_seen.erase(cell)
			decayed.append(cell)
	return [{"kind": "ground", "cells": decayed}] if not decayed.is_empty() else []


## Public state is visible to every peer; the backpack is only exported to its owner.
func export_player(id: int, now: float, include_private: bool = false) -> Dictionary:
	var player: Dictionary = players[id]
	var remaining: float = maxf(0.0, player["next_move"] - now)
	var state: Dictionary = {
		"id": id, "cell": player["cell"],
		"from": player["from"] if remaining > 0.0 else player["cell"],
		"remaining": remaining, "facing": player["facing"],
		"equipment": player["equipment"].duplicate(), "level": player["level"], "vocation": player["vocation"],
		"health": player["health"], "max_health": player_stats(id)["health"], "skull": player["skull"],
		"party": player["party"],
	}
	if include_private:
		var invites: Array[int] = []
		for leader: int in players:
			if players[leader]["invited"].has(id):
				invites.append(leader)
		state["invites"] = invites
		state["invited"] = player["invited"].keys()
		state["trophies"] = player["trophies"].duplicate()
		state["unjustified"] = player["unjustified"].size()
		state["mana"] = player["mana"]
		state["max_mana"] = player_stats(id)["mana"]
		state["target"] = player["target"]
		for timers: String in ["cooldowns", "groups"]:
			var left: Dictionary = {}
			for key: String in player[timers]:
				if player[timers][key] > now:
					left[key] = player[timers][key] - now
			state[timers] = left
		state["backpack"] = player["backpack"].duplicate()
		state["depot"] = player["depot"].duplicate()
		state["bank"] = player["bank"]
		state["tasks"] = player["tasks"].duplicate()
		state["done_tasks"] = player["done_tasks"].keys()
		state["experience"] = player["experience"]
		state["gold"] = player["gold"]
	return state


func snapshot(now: float, viewer: int = 0) -> Dictionary:
	var result: Dictionary = {}
	for id: int in players:
		result[id] = export_player(id, now, id == viewer)
	return result


func ground_snapshot() -> Dictionary:
	return ground.duplicate(true)


func ground_stack(cell: Vector2i) -> Array:
	return ground.get(cell, []).duplicate()


func move(id: int, direction: Vector2i, now: float) -> Dictionary:
	if not players.has(id):
		return {"ok": false, "reason": "Unknown player", "retry": 0.0}
	if absi(direction.x) + absi(direction.y) != 1:
		return {"ok": false, "reason": "Only one cardinal tile is allowed", "retry": 0.0}
	var player: Dictionary = players[id]
	if now < player["next_move"]:
		return {"ok": false, "reason": "Movement cooldown", "retry": player["next_move"] - now}
	var destination: Vector2i = player["cell"] + direction
	if not walkable(destination):
		return {"ok": false, "reason": "Blocked tile", "retry": MOVE_SECONDS}
	if occupied(destination, now, id):
		return {"ok": false, "reason": "Another player is in the way", "retry": MOVE_SECONDS}
	player["from"] = player["cell"]
	player["cell"] = destination
	player["facing"] = direction
	player["next_move"] = now + MOVE_SECONDS
	return {"ok": true, "state": export_player(id, now)}


func toggle_equipment(id: int, slot: String, now: float) -> Dictionary:
	if not players.has(id):
		return _item_error("Unknown player")
	if slot not in SLOTS:
		return _item_error("Unknown equipment slot")
	var player: Dictionary = players[id]
	if player["equipment"].has(slot):
		return move_item(id, {"type": "equipment", "slot": slot}, {"type": "backpack"}, now)
	for index: int in player["backpack"].size():
		var kind: String = player["backpack"][index]
		if fits(kind, slot) and requirement_error(kind, player["level"], player["vocation"]).is_empty():
			return move_item(id, {"type": "backpack", "index": index}, {"type": "equipment", "slot": slot}, now)
	return _item_error("No item for that slot")


## Locations are {"type": "backpack", "index": int}, {"type": "depot", "index": int},
## {"type": "equipment", "slot": String} or {"type": "ground", "cell": Vector2i}. A target
## backpack or depot without an index means a matching stack or the first free slot. Anything
## else, including client-supplied extra keys, is rejected.
static func parse_location(value: Variant, allow_auto: bool) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var location: Dictionary = value
	var kind: Variant = location.get("type")
	if typeof(kind) != TYPE_STRING:
		return {}
	match kind:
		"backpack", "depot":
			if not location.has("index"):
				return {"type": kind, "index": -1} if allow_auto and location.size() == 1 else {}
			var index: Variant = location["index"]
			var size: int = BACKPACK_MAX if kind == "backpack" else DEPOT_SIZE
			if location.size() == 2 and typeof(index) == TYPE_INT and index >= 0 and index < size:
				return {"type": kind, "index": index}
		"equipment":
			var slot: Variant = location.get("slot")
			if location.size() == 2 and typeof(slot) == TYPE_STRING and slot in SLOTS:
				return {"type": "equipment", "slot": slot}
		"ground":
			var cell: Variant = location.get("cell")
			if location.size() == 2 and typeof(cell) == TYPE_VECTOR2I:
				return {"type": "ground", "cell": cell}
	return {}


func move_item(id: int, source_value: Variant, target_value: Variant, now: float) -> Dictionary:
	if not players.has(id):
		return _item_error("Unknown player")
	var source: Dictionary = parse_location(source_value, false)
	var target: Dictionary = parse_location(target_value, true)
	if source.is_empty() or target.is_empty():
		return _item_error("Unknown item location")
	var player: Dictionary = players[id]
	for location: Dictionary in [source, target]:
		if location["type"] in ["backpack", "depot"] and location["index"] >= player[location["type"]].size():
			return _item_error("Unknown item location")
	if now < player["next_item"]:
		return _item_error("Item cooldown")
	if source == target:
		return _item_error("The item is already there")
	for location: Dictionary in [source, target]:
		if location["type"] == "ground" and not _within_reach(player, location["cell"]):
			return _item_error("That is too far away")
		if location["type"] == "equipment" and location["slot"] == "bag":
			return _item_error("Your pack stays on your back")
	if "depot" in [source["type"], target["type"]]:
		if source["type"] not in ["backpack", "depot"] or target["type"] not in ["backpack", "depot"]:
			return _item_error("Move items to and from your depot through your backpack")
		if npc_near(player["cell"], "bank").is_empty():
			return _item_error("Your depot is kept at the bank in %s" % bank_place())
	var entry: String = _item_at(player, source)
	if entry.is_empty():
		return _item_error("There is no item there")
	var kind: String = kind_of(entry)
	var count: int = count_of(entry)
	if ITEMS[kind].has("gold"):
		if source["type"] != "ground" or target["type"] not in ["backpack", "ground"]:
			return _item_error("That item does not fit there")
		if target["type"] == "backpack":
			_take(player, source)
			player["gold"] += ITEMS[kind]["gold"] * count
			player["next_item"] = now + ITEM_SECONDS
			return {"ok": true, "state": export_player(id, now, true), "ground": [source["cell"]]}
	# Stackables merge into a matching stack with room: the chosen slot or tile, or any backpack
	# stack when no slot was named.
	if stackable(kind):
		var merge: Dictionary = _merge_target(player, source, target, kind, count)
		if not merge.is_empty():
			if merge["type"] == "ground" and not walkable(merge["cell"]):
				return _item_error("Items cannot be placed there")
			_take(player, source)
			_set_entry(player, merge, make_entry(kind, count_of(_item_at(player, merge)) + count))
			player["next_item"] = now + ITEM_SECONDS
			var touched: Array[Vector2i] = []
			for location: Dictionary in [source, merge]:
				if location["type"] == "ground" and location["cell"] not in touched:
					touched.append(location["cell"])
			return {"ok": true, "state": export_player(id, now, true), "ground": touched}
	match target["type"]:
		"backpack", "depot":
			var occupant: String = _item_at(player, target)
			var swappable: bool = source["type"] in ["backpack", "depot"] or (source["type"] == "equipment" \
				and fits(occupant, source["slot"]))
			if target["index"] < 0 or (not occupant.is_empty() and not swappable):
				target = {"type": target["type"], "index": player[target["type"]].find("")}
				if target["index"] < 0:
					return _item_error("Your %s is full" % target["type"])
		"equipment":
			if not fits(kind, target["slot"]):
				return _item_error("That item does not fit there")
			var refused: String = requirement_error(kind, player["level"], player["vocation"])
			if not refused.is_empty():
				return _item_error(refused)
		"ground":
			if bound(kind):
				return _item_error("The %s is bound to you" % ITEMS[kind]["name"])
			if not walkable(target["cell"]):
				return _item_error("Items cannot be placed there")
			if ground.get(target["cell"], []).size() >= GROUND_STACK_MAX:
				return _item_error("There is no room on that tile")
	var displaced: String = _item_at(player, target) if target["type"] != "ground" else ""
	if source["type"] == "ground" and bound(displaced):
		return _item_error("The %s is bound to you" % ITEMS[kind_of(displaced)]["name"])
	if source["type"] == "equipment" and not displaced.is_empty():
		if not fits(displaced, source["slot"]):
			return _item_error("That item does not fit there")
		var refused: String = requirement_error(displaced, player["level"], player["vocation"])
		if not refused.is_empty():
			return _item_error(refused)
	_take(player, source)
	if not displaced.is_empty():
		_take(player, target)
		_put(player, source, displaced)
	_put(player, target, entry)
	player["next_item"] = now + ITEM_SECONDS
	clamp_vitals(id)
	var changed: Array[Vector2i] = []
	for location: Dictionary in [source, target]:
		if location["type"] == "ground" and location["cell"] not in changed:
			changed.append(location["cell"])
	return {"ok": true, "state": export_player(id, now, true), "ground": changed}


## Where a moving stackable merges: the target slot or ground tile if its entry is the same
## kind with room, or (no slot named, or the named slot is taken) any stack with room in the
## target backpack or depot.
func _merge_target(player: Dictionary, source: Dictionary, target: Dictionary, kind: String, count: int) -> Dictionary:
	var container: bool = target["type"] in ["backpack", "depot"]
	var occupant: String = _item_at(player, target) if not container or target["index"] >= 0 else ""
	if not occupant.is_empty() and kind_of(occupant) == kind and count_of(occupant) + count <= STACK_MAX:
		return target
	if container and (target["index"] < 0 or not occupant.is_empty()):
		var slots: Array = player[target["type"]]
		for index: int in slots.size():
			var held: String = slots[index]
			if (source["type"] != target["type"] or source["index"] != index) and kind_of(held) == kind \
					and count_of(held) + count <= STACK_MAX:
				return {"type": target["type"], "index": index}
	return {}


## The slot in `slots` that can take `count` more of `kind`: a stack of it with room, else the
## first empty slot; -1 when there is none. Equipment always needs an empty slot.
static func receiving_slot(slots: Array, kind: String, count: int) -> int:
	if stackable(kind):
		for index: int in slots.size():
			if kind_of(slots[index]) == kind and count_of(slots[index]) + count <= STACK_MAX:
				return index
	return slots.find("")


## Wears a pack in the bag slot (replacing any smaller one) and grows the backpack to fit.
func wear_pack(id: int, kind: String) -> void:
	var player: Dictionary = players[id]
	player["equipment"]["bag"] = kind
	var size: int = mini(BACKPACK_MAX, BACKPACK_SIZE + int(ITEMS[kind].get("slots", 0)))
	while player["backpack"].size() < size:
		player["backpack"].append("")


func _set_entry(player: Dictionary, location: Dictionary, entry: String) -> void:
	match location["type"]:
		"backpack", "depot":
			player[location["type"]][location["index"]] = entry
		"ground":
			ground[location["cell"]][-1] = entry


func _item_error(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "ground": []}


func _within_reach(player: Dictionary, cell: Vector2i) -> bool:
	var offset: Vector2i = cell - player["cell"]
	return maxi(absi(offset.x), absi(offset.y)) <= 1


func _item_at(player: Dictionary, location: Dictionary) -> String:
	match location["type"]:
		"backpack", "depot":
			return player[location["type"]][location["index"]] if location["index"] >= 0 else ""
		"equipment":
			return player["equipment"].get(location["slot"], "")
		"ground":
			var stack: Array = ground.get(location["cell"], [])
			return stack.back() if not stack.is_empty() else ""
	return ""


func _take(player: Dictionary, location: Dictionary) -> void:
	match location["type"]:
		"backpack", "depot":
			player[location["type"]][location["index"]] = ""
		"equipment":
			player["equipment"].erase(location["slot"])
		"ground":
			var stack: Array = ground[location["cell"]]
			stack.pop_back()
			if stack.is_empty():
				ground.erase(location["cell"])


func _put(player: Dictionary, location: Dictionary, kind: String) -> void:
	match location["type"]:
		"backpack", "depot":
			player[location["type"]][location["index"]] = kind
		"equipment":
			player["equipment"][location["slot"]] = kind
		"ground":
			if not ground.has(location["cell"]):
				ground[location["cell"]] = []
			ground[location["cell"]].append(kind)


static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## The nearest free walkable tile within talking range of a ferryman, or (-1, -1).
func arrival_cell(ferryman: String, now: float) -> Vector2i:
	var origin: Vector2i = FERRYMEN[ferryman]["cell"]
	var best: Vector2i = Vector2i(-1, -1)
	var best_distance: int = 999
	for dy: int in range(-TALK_RANGE, TALK_RANGE + 1):
		for dx: int in range(-TALK_RANGE, TALK_RANGE + 1):
			var cell: Vector2i = origin + Vector2i(dx, dy)
			var distance: int = absi(dx) + absi(dy)
			if distance < best_distance and walkable(cell) and not occupied(cell, now):
				best = cell
				best_distance = distance
	return best


## Sail from a ferryman to one of its destinations; the server deducts the fare.
func travel(id: int, ferryman: Variant, destination: Variant, now: float) -> Dictionary:
	if not players.has(id):
		return {"ok": false, "reason": "Unknown player"}
	if typeof(ferryman) != TYPE_STRING or not FERRYMEN.has(ferryman):
		return {"ok": false, "reason": "Unknown ferryman"}
	var routes: Dictionary = FERRYMEN[ferryman]["routes"]
	if typeof(destination) != TYPE_STRING or not routes.has(destination) or not FERRYMEN.has(destination):
		return {"ok": false, "reason": "That ferryman does not sail there"}
	var player: Dictionary = players[id]
	if not in_talk_range(player["cell"], FERRYMEN[ferryman]["cell"]):
		return {"ok": false, "reason": "Walk closer to the ferryman"}
	if now < player["next_move"]:
		return {"ok": false, "reason": "Stand still to board"}
	if now < player["next_travel"]:
		return {"ok": false, "reason": "Travel cooldown"}
	var fare: int = routes[destination]
	if player["gold"] < fare:
		return {"ok": false, "reason": "You need %d gold to sail there" % fare}
	var arrival: Vector2i = arrival_cell(destination, now)
	if arrival.x < 0:
		return {"ok": false, "reason": "The dock at %s is crowded" % FERRYMEN[destination]["place"]}
	player["gold"] -= fare
	player["cell"] = arrival
	player["from"] = arrival
	player["next_move"] = now
	player["next_travel"] = now + TRAVEL_SECONDS
	return {"ok": true, "state": export_player(id, now, true),
		"message": "You %s to %s for %d gold." % ["rode" if FERRYMEN[ferryman]["vehicle"] == "coach" else "sailed",
			FERRYMEN[destination]["place"], fare]}
