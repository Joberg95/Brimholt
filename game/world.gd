extends RefCounted

const TILE_SIZE: int = 32
const WORLD_NAME: String = "Cinder Crossing"
const ROWS: Array[String] = [
	"########################",
	"#...........#..........#",
	"#..~~~......#..........#",
	"#..~~~......#...####...#",
	"#..~~~..........#..#...#",
	"#...............#..#...#",
	"#...,,,,,,,,,,,,,,,....#",
	"#...,...#...#.....,....#",
	"#...,...#...#.....,....#",
	"#...,...#.........,....#",
	"#...,,,,,,,,,,,,,,,....#",
	"#.......#..............#",
	"#.......#.....~~~......#",
	"#.............~~~......#",
	"#..####.......~~~......#",
	"#......................#",
	"#......................#",
	"########################",
]
const SPAWNS: Array[Vector2i] = [
	Vector2i(5, 6), Vector2i(7, 6), Vector2i(9, 6), Vector2i(11, 6),
]
const MOVE_SECONDS: float = 0.18
const MAX_PLAYERS: int = 4
const PORT: int = 1234
const PROTOCOL: int = 2
const SLOTS: Array[String] = ["helmet", "armor", "hand"]
const ITEMS: Dictionary = {
	"ember_cap": {"name": "Ember cap", "slot": "helmet"},
	"moss_coat": {"name": "Moss coat", "slot": "armor"},
	"copper_blade": {"name": "Copper blade", "slot": "hand"},
	"iron_coif": {"name": "Iron coif", "slot": "helmet"},
	"ash_tunic": {"name": "Ash tunic", "slot": "armor"},
	"flint_hatchet": {"name": "Flint hatchet", "slot": "hand"},
	"glowcap": {"name": "Glowcap", "slot": ""},
}
const START_KIT: Array[String] = ["ember_cap", "moss_coat", "copper_blade"]
const GROUND_ITEMS: Array = [
	[Vector2i(14, 9), "iron_coif"], [Vector2i(20, 15), "ash_tunic"],
	[Vector2i(2, 12), "flint_hatchet"], [Vector2i(10, 1), "glowcap"], [Vector2i(10, 1), "glowcap"],
]
const BACKPACK_SIZE: int = 8
const GROUND_STACK_MAX: int = 6
const ITEM_SECONDS: float = 0.15

var players: Dictionary = {}
var ground: Dictionary = {}


func _init() -> void:
	for entry: Array in GROUND_ITEMS:
		var cell: Vector2i = entry[0]
		if not ground.has(cell):
			ground[cell] = []
		ground[cell].append(entry[1])


static func walkable(cell: Vector2i) -> bool:
	return cell.y >= 0 and cell.y < ROWS.size() and cell.x >= 0 \
		and cell.x < ROWS[0].length() and ROWS[cell.y][cell.x] in [".", ","]


static func signature() -> String:
	return (str(PROTOCOL) + str(TILE_SIZE) + str(MAX_PLAYERS) + str(ROWS) + str(SPAWNS) + str(ITEMS) \
		+ str(MOVE_SECONDS) + str(SLOTS) + str(START_KIT) + str(GROUND_ITEMS) + str(BACKPACK_SIZE) \
		+ str(GROUND_STACK_MAX) + str(ITEM_SECONDS)).sha256_text()


func occupied(cell: Vector2i, now: float, except_id: int = 0) -> bool:
	for id: int in players:
		if id == except_id:
			continue
		var player: Dictionary = players[id]
		if player["cell"] == cell:
			return true
		if now < player["next_move"] and player["from"] == cell:
			return true
	return false


func add_player(id: int, now: float) -> bool:
	if id <= 0 or players.has(id) or players.size() >= MAX_PLAYERS:
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
			}
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
		"equipment": player["equipment"].duplicate(),
	}
	if include_private:
		state["backpack"] = player["backpack"].duplicate()
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
		if not kind.is_empty() and ITEMS[kind]["slot"] == slot:
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
	match target["type"]:
		"backpack":
			var occupant: String = _item_at(player, target)
			var swappable: bool = source["type"] == "backpack" or (source["type"] == "equipment" \
				and not occupant.is_empty() and ITEMS[occupant]["slot"] == source["slot"])
			if target["index"] < 0 or (not occupant.is_empty() and not swappable):
				target = {"type": "backpack", "index": player["backpack"].find("")}
				if target["index"] < 0:
					return _item_error("Your backpack is full")
		"equipment":
			if ITEMS[kind]["slot"] != target["slot"]:
				return _item_error("That item does not fit there")
		"ground":
			if not walkable(target["cell"]):
				return _item_error("Items cannot be placed there")
			if ground.get(target["cell"], []).size() >= GROUND_STACK_MAX:
				return _item_error("There is no room on that tile")
	var displaced: String = _item_at(player, target) if target["type"] != "ground" else ""
	_take(player, source)
	if not displaced.is_empty():
		_take(player, target)
		_put(player, source, displaced)
	_put(player, target, kind)
	player["next_item"] = now + ITEM_SECONDS
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
