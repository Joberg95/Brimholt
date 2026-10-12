extends RefCounted

const Balance = preload("res://game/data/balance.gd")

const TILE_SIZE: int = 32
const WORLD_NAME: String = "Cinder Crossing"
## The world is painted in Godot's TileMap editor; see docs/world-editing.md.
const MAP_SCENE: String = "res://game/maps/overworld.tscn"
## Terrain characters: grass, dirt road, water, stone wall, tree, sand, cobblestone, pier/bridge.
const TERRAINS: String = ".,~#T:=b"
const WALKABLE: String = ".,:=b"
const LAND: String = ".,:="
## Loaded from MAP_SCENE: terrain rows (" " for unpainted cells), spawn cells, starting
## ground items, and ferrymen {id: {name, place, cell, facing, routes: {id: fare}}}.
static var ROWS: PackedStringArray
static var SPAWNS: Array[Vector2i] = []
static var GROUND_ITEMS: Array = []
static var FERRYMEN: Dictionary = {}
static var NPC_CELLS: Dictionary = {}
## Gameplay zones {name, rect (tiles), pvp, min_level, max_level}; the first match wins.
static var ZONES: Array = []
## Future monster spawns {monster, level, count, radius, cell}; not used in play yet.
static var MONSTER_SPAWNS: Array = []
static var MAP_HASH: String = ""
const MOVE_SECONDS: float = 0.18
const MAX_PLAYERS: int = 12
const PORT: int = 1234
const PROTOCOL: int = 5
const START_GOLD: int = 100
## Players must stand within this many tiles (in any direction) of a ferryman to sail.
const TALK_RANGE: int = 2
const TRAVEL_SECONDS: float = 1.0
## Equipment slots in paperdoll order. Each accepts items of one slot type; both rings take "ring".
const SLOTS: Array[String] = ["necklace", "helmet", "charm", "main_hand", "armor", "off_hand", "ring_1", "ring_2"]
const SLOT_TYPES: Dictionary = {
	"necklace": "necklace", "helmet": "helmet", "charm": "charm", "main_hand": "main_hand",
	"armor": "armor", "off_hand": "off_hand", "ring_1": "ring", "ring_2": "ring",
}
## Item stats add to Balance.base_stats(level). Starter items are tuned for levels 1-5.
const ITEMS: Dictionary = {
	"ember_cap": {"name": "Ember cap", "slot": "helmet", "stats": {"defense": 3}},
	"moss_coat": {"name": "Moss coat", "slot": "armor", "stats": {"defense": 6, "regen": 1}},
	"copper_blade": {"name": "Copper blade", "slot": "main_hand", "stats": {"attack": 2, "critical": 2}},
	"iron_coif": {"name": "Iron coif", "slot": "helmet", "stats": {"defense": 5}},
	"ash_tunic": {"name": "Ash tunic", "slot": "armor", "stats": {"defense": 8}},
	"flint_hatchet": {"name": "Flint hatchet", "slot": "main_hand", "stats": {"attack": 3}},
	"oak_buckler": {"name": "Oak buckler", "slot": "off_hand", "stats": {"defense": 5}},
	"copper_band": {"name": "Copper band", "slot": "ring", "stats": {"critical": 3}},
	"garnet_ring": {"name": "Garnet ring", "slot": "ring", "stats": {"health": 20}},
	"river_pendant": {"name": "River pendant", "slot": "necklace", "stats": {"health": 15, "regen": 1}},
	"hearth_charm": {"name": "Hearth charm", "slot": "charm", "stats": {"health": 10, "regen": 2, "attack": 1}},
	"glowcap": {"name": "Glowcap", "slot": "", "stats": {}},
	"gold_coins": {"name": "Gold coins", "slot": "", "stats": {}, "gold": 25},
	# Monster materials: loot that shops will buy for "value" gold.
	"vole_tail": {"name": "Vole tail", "slot": "", "stats": {}, "value": 2},
	"toad_slime": {"name": "Toad slime", "slot": "", "stats": {}, "value": 3},
	"boar_tusk": {"name": "Boar tusk", "slot": "", "stats": {}, "value": 6},
	"bandit_badge": {"name": "Bandit badge", "slot": "", "stats": {}, "value": 9},
	"wolf_pelt": {"name": "Wolf pelt", "slot": "", "stats": {}, "value": 14},
	"lurker_eye": {"name": "Lurker eye", "slot": "", "stats": {}, "value": 20},
	"waxed_bowstring": {"name": "Waxed bowstring", "slot": "", "stats": {}, "value": 26},
	"golem_core": {"name": "Golem core", "slot": "", "stats": {}, "value": 35},
	"wraith_ash": {"name": "Wraith ash", "slot": "", "stats": {}, "value": 45},
	"hollow_sigil": {"name": "Hollow sigil", "slot": "", "stats": {}, "value": 60},
	"stalker_fang": {"name": "Stalker fang", "slot": "", "stats": {}, "value": 80},
	"reedfang_scale": {"name": "Reedfang scale", "slot": "", "stats": {}, "value": 90},
	"bog_heart": {"name": "Bog heart", "slot": "", "stats": {}, "value": 110},
	"warden_crest": {"name": "Warden crest", "slot": "", "stats": {}, "value": 200},
}
const START_KIT: Array[String] = ["ember_cap", "moss_coat", "copper_blade", "oak_buckler", "copper_band"]
const BACKPACK_SIZE: int = 8
const GROUND_STACK_MAX: int = 6
const ITEM_SECONDS: float = 0.15

var players: Dictionary = {}
## Live monsters by negative id; game/core/combat.gd owns their behaviour.
var monsters: Dictionary = {}
var ground: Dictionary = {}


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
			var terrain: Variant = source.get_tile_data(coords, 0).get_custom_data("terrain")
			if typeof(terrain) == TYPE_STRING and terrain.length() == 1 and terrain in TERRAINS:
				lookup[Vector3i(source_id, coords.x, coords.y)] = terrain
	var size: Vector2i = layer.get_used_rect().end
	var grid := PackedByteArray()
	grid.resize(size.x * size.y)
	grid.fill(32)
	for cell: Vector2i in layer.get_used_cells():
		var coords: Vector2i = layer.get_cell_atlas_coords(cell)
		var terrain: String = lookup.get(Vector3i(layer.get_cell_source_id(cell), coords.x, coords.y), " ")
		if cell.x >= 0 and cell.y >= 0:
			grid[cell.y * size.x + cell.x] = terrain.unicode_at(0)
	ROWS = PackedStringArray()
	for y: int in size.y:
		ROWS.append(grid.slice(y * size.x, (y + 1) * size.x).get_string_from_ascii())
	for marker: Node2D in scene.get_node("Spawns").get_children():
		SPAWNS.append(_cell_of(marker))
	for marker: Node2D in scene.get_node("Items").get_children():
		GROUND_ITEMS.append([_cell_of(marker), String(marker.get("item"))])
	for marker: Node2D in scene.get_node("Ferrymen").get_children():
		var routes: Dictionary = {}
		var fares: Dictionary = marker.get("routes")
		for destination: Variant in fares:
			routes[String(destination)] = int(fares[destination])
		FERRYMEN[String(marker.name)] = {
			"name": String(marker.get("npc_name")), "place": String(marker.get("place")),
			"cell": _cell_of(marker), "facing": marker.get("facing"), "routes": routes, "services": ["travel"],
		}
		NPC_CELLS[_cell_of(marker)] = String(marker.name)
	if scene.has_node("Zones"):
		for marker: Node2D in scene.get_node("Zones").get_children():
			ZONES.append({
				"name": String(marker.get("zone_name")), "rect": Rect2i(_cell_of(marker), marker.get("size_tiles")),
				"pvp": bool(marker.get("pvp")), "min_level": int(marker.get("min_level")),
				"max_level": int(marker.get("max_level")),
			})
	if scene.has_node("MonsterSpawns"):
		for marker: Node2D in scene.get_node("MonsterSpawns").get_children():
			MONSTER_SPAWNS.append({
				"monster": String(marker.get("monster")), "level": int(marker.get("level")),
				"count": int(marker.get("count")), "radius": int(marker.get("radius")), "cell": _cell_of(marker),
			})
	scene.free()
	MAP_HASH = ("".join(ROWS) + str(SPAWNS) + str(GROUND_ITEMS) + str(FERRYMEN) + str(ZONES)
		+ str(MONSTER_SPAWNS)).sha256_text()


static func zone_at(cell: Vector2i) -> Dictionary:
	for zone: Dictionary in ZONES:
		if zone["rect"].has_point(cell):
			return zone
	return {}


static func _cell_of(marker: Node2D) -> Vector2i:
	return Vector2i((marker.position / TILE_SIZE).floor())


static func width() -> int:
	return ROWS[0].length() if not ROWS.is_empty() else 0


static func height() -> int:
	return ROWS.size()


static func terrain(cell: Vector2i) -> String:
	if cell.x < 0 or cell.y < 0 or cell.y >= ROWS.size() or cell.x >= ROWS[cell.y].length():
		return ""
	return ROWS[cell.y][cell.x]


func _init() -> void:
	for entry: Array in GROUND_ITEMS:
		var cell: Vector2i = entry[0]
		if not ground.has(cell):
			ground[cell] = []
		ground[cell].append(entry[1])


static func walkable(cell: Vector2i) -> bool:
	var tile: String = terrain(cell)
	return not tile.is_empty() and tile != " " and tile in WALKABLE and not NPC_CELLS.has(cell)


static func signature() -> String:
	return (str(PROTOCOL) + str(TILE_SIZE) + str(MAX_PLAYERS) + MAP_HASH + str(ITEMS) + str(START_GOLD) \
		+ str(TALK_RANGE) + str(TRAVEL_SECONDS) \
		+ str(MOVE_SECONDS) + str(SLOTS) + str(START_KIT) + str(GROUND_ITEMS) + str(BACKPACK_SIZE) \
		+ str(GROUND_STACK_MAX) + str(ITEM_SECONDS) + str(SLOT_TYPES) + Balance.signature()).sha256_text()


static func fits(kind: String, slot: String) -> bool:
	return ITEMS.has(kind) and SLOT_TYPES.has(slot) and ITEMS[kind]["slot"] == SLOT_TYPES[slot]


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
		if typeof(kind) == TYPE_STRING and ITEMS.has(kind):
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
			for index: int in START_KIT.size():
				backpack[index] = START_KIT[index]
			players[id] = {
				"id": id, "cell": cell, "from": cell, "next_move": now,
				"facing": Vector2i.DOWN, "equipment": {}, "backpack": backpack, "next_item": now,
				"level": 1, "experience": 0, "vocation": vocation, "gold": START_GOLD, "next_travel": now,
				"target": 0, "next_attack": now, "next_regen": now, "cooldowns": {}, "groups": {},
				"skull": "", "skull_until": 0.0, "unjustified": [], "aggressors": {},
				"party": 0, "invited": {}, "active_at": -INF,
			}
			var limits: Dictionary = stats(1, {}, vocation)
			players[id]["health"] = limits["health"]
			players[id]["mana"] = limits["mana"]
			return true
	return false


func remove_player(id: int) -> void:
	players.erase(id)


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
	for index: int in BACKPACK_SIZE:
		var kind: String = player["backpack"][index]
		if fits(kind, slot):
			return move_item(id, {"type": "backpack", "index": index}, {"type": "equipment", "slot": slot}, now)
	return _item_error("No item for that slot")


## Locations are {"type": "backpack", "index": int}, {"type": "equipment", "slot": String}
## or {"type": "ground", "cell": Vector2i}. A target backpack without an index means the
## first free slot. Anything else, including client-supplied extra keys, is rejected.
static func parse_location(value: Variant, allow_auto: bool) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var location: Dictionary = value
	var kind: Variant = location.get("type")
	if typeof(kind) != TYPE_STRING:
		return {}
	match kind:
		"backpack":
			if not location.has("index"):
				return {"type": "backpack", "index": -1} if allow_auto and location.size() == 1 else {}
			var index: Variant = location["index"]
			if location.size() == 2 and typeof(index) == TYPE_INT and index >= 0 and index < BACKPACK_SIZE:
				return {"type": "backpack", "index": index}
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
	if now < player["next_item"]:
		return _item_error("Item cooldown")
	if source == target:
		return _item_error("The item is already there")
	for location: Dictionary in [source, target]:
		if location["type"] == "ground" and not _within_reach(player, location["cell"]):
			return _item_error("That is too far away")
	var kind: String = _item_at(player, source)
	if kind.is_empty():
		return _item_error("There is no item there")
	if ITEMS[kind].has("gold"):
		if source["type"] != "ground" or target["type"] not in ["backpack", "ground"]:
			return _item_error("That item does not fit there")
		if target["type"] == "backpack":
			_take(player, source)
			player["gold"] += ITEMS[kind]["gold"]
			player["next_item"] = now + ITEM_SECONDS
			return {"ok": true, "state": export_player(id, now, true), "ground": [source["cell"]]}
	match target["type"]:
		"backpack":
			var occupant: String = _item_at(player, target)
			var swappable: bool = source["type"] == "backpack" or (source["type"] == "equipment" \
				and fits(occupant, source["slot"]))
			if target["index"] < 0 or (not occupant.is_empty() and not swappable):
				target = {"type": "backpack", "index": player["backpack"].find("")}
				if target["index"] < 0:
					return _item_error("Your backpack is full")
		"equipment":
			if not fits(kind, target["slot"]):
				return _item_error("That item does not fit there")
		"ground":
			if not walkable(target["cell"]):
				return _item_error("Items cannot be placed there")
			if ground.get(target["cell"], []).size() >= GROUND_STACK_MAX:
				return _item_error("There is no room on that tile")
	var displaced: String = _item_at(player, target) if target["type"] != "ground" else ""
	if source["type"] == "equipment" and not displaced.is_empty() and not fits(displaced, source["slot"]):
		return _item_error("That item does not fit there")
	_take(player, source)
	if not displaced.is_empty():
		_take(player, target)
		_put(player, source, displaced)
	_put(player, target, kind)
	player["next_item"] = now + ITEM_SECONDS
	clamp_vitals(id)
	var changed: Array[Vector2i] = []
	for location: Dictionary in [source, target]:
		if location["type"] == "ground" and location["cell"] not in changed:
			changed.append(location["cell"])
	return {"ok": true, "state": export_player(id, now, true), "ground": changed}


func _item_error(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "ground": []}


func _within_reach(player: Dictionary, cell: Vector2i) -> bool:
	var offset: Vector2i = cell - player["cell"]
	return maxi(absi(offset.x), absi(offset.y)) <= 1


func _item_at(player: Dictionary, location: Dictionary) -> String:
	match location["type"]:
		"backpack":
			return player["backpack"][location["index"]] if location["index"] >= 0 else ""
		"equipment":
			return player["equipment"].get(location["slot"], "")
		"ground":
			var stack: Array = ground.get(location["cell"], [])
			return stack.back() if not stack.is_empty() else ""
	return ""


func _take(player: Dictionary, location: Dictionary) -> void:
	match location["type"]:
		"backpack":
			player["backpack"][location["index"]] = ""
		"equipment":
			player["equipment"].erase(location["slot"])
		"ground":
			var stack: Array = ground[location["cell"]]
			stack.pop_back()
			if stack.is_empty():
				ground.erase(location["cell"])


func _put(player: Dictionary, location: Dictionary, kind: String) -> void:
	match location["type"]:
		"backpack":
			player["backpack"][location["index"]] = kind
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
	if chebyshev(player["cell"], FERRYMEN[ferryman]["cell"]) > TALK_RANGE:
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
		"message": "You sailed to %s for %d gold." % [FERRYMEN[destination]["place"], fare]}
