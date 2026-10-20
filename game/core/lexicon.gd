extends RefCounted
## The monster lexicon: for every monster, the levels and places it is found at (overworld
## regions and zones from the map's spawns, and dungeons), its rank, its drops with their chances
## (Monsters.LOOT, as Combat.roll_loot rolls them), the gold and tier gear it adds, the tasks it
## counts toward, and a final boss's relics. Built once from the catalogs; read by the Lexicon
## window (game/ui/lexicon_window.gd).

const World = preload("res://game/core/world.gd")
const Combat = preload("res://game/core/combat.gd")
const Monsters = preload("res://game/data/monsters.gd")
const Dungeons = preload("res://game/data/dungeons.gd")
const Quests = preload("res://game/data/quests.gd")
const Items = preload("res://game/data/items.gd")
const Balance = preload("res://game/data/balance.gd")

## A level above any real one, replaced by the first placement found.
const UNPLACED: int = 1 << 20

static var _entries: Array[Dictionary] = []


## Every monster, lowest level first: {kind, name, rank, levels (Vector2i), places, drops
## ([item, chance] rolls), gold (expected coins' value), gear (chance), gear_tiers, tasks, relics}.
static func entries() -> Array[Dictionary]:
	if _entries.is_empty():
		for kind: String in Monsters.MONSTERS:
			_entries.append(entry(kind))
		_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a["levels"].x < b["levels"].x or (a["levels"].x == b["levels"].x and a["name"] < b["name"]))
	return _entries


static func entry(kind: String) -> Dictionary:
	var definition: Dictionary = Monsters.MONSTERS[kind]
	var levels := Vector2i(UNPLACED, 0)
	var places: Array[String] = []
	for spawn: Dictionary in World.MONSTER_SPAWNS:
		if spawn["monster"] != kind:
			continue
		levels = Vector2i(mini(levels.x, spawn["level"]), maxi(levels.y, spawn["level"]))
		var zone: Dictionary = World.zone_at(spawn["cell"])
		var place: String = zone["name"] if not zone.is_empty() else World.region_at(spawn["cell"])
		if not place in places:
			places.append(place)
	for dungeon: String in Dungeons.ORDER:
		for symbol: String in Dungeons.DUNGEONS[dungeon]["monsters"]:
			var placed: Array = Dungeons.DUNGEONS[dungeon]["monsters"][symbol]
			if placed[0] == kind:
				levels = Vector2i(mini(levels.x, placed[1]), maxi(levels.y, placed[1]))
				var place: String = "%s (dungeon)" % Dungeons.DUNGEONS[dungeon]["name"]
				if not place in places:
					places.append(place)
	if levels.y == 0:
		levels = Vector2i.ZERO
	var ranked: bool = definition["rank"] != "normal"
	var average: float = (levels.x + levels.y) / 2.0
	var tasks: Array[String] = []
	for task: String in Quests.TASKS:
		if Quests.counts(task, kind):
			tasks.append(task)
	return {
		"kind": kind, "name": definition["name"], "rank": definition["rank"], "levels": levels, "places": places,
		"drops": Monsters.LOOT.get(kind, []).duplicate(),
		"gold": roundi(Balance.coins_per_kill(average, "elite" if ranked else "normal") * World.ITEMS["gold_coins"]["gold"]),
		"gear": float(Combat.GEAR_DROP_CHANCE.get(definition["rank"], 0.0)),
		"gear_tiers": Vector2i(Items.tier_for(maxi(levels.x, 1)), Items.tier_for(maxi(levels.y, 1))),
		"tasks": tasks, "relics": definition.get("relics", []),
		"valuables": valuables(levels), "valuable_gold": roundi(Balance.valuables_per_kill(average, definition["rank"])),
	}


## The gems monsters of `levels` can drop (Combat.roll_valuables): the best small gem of each level
## and the one below it, and the great gems from level 35.
static func valuables(levels: Vector2i) -> Array[String]:
	var found: Array[String] = []
	if levels.y <= 0:
		return found
	for level: int in range(maxi(levels.x, 1), levels.y + 1):
		var smalls: Array = Monsters.VALUABLES.filter(func(gem_row: Array) -> bool: return level >= int(gem_row[1]))
		for gem_row: Array in smalls.slice(maxi(0, smalls.size() - 2)):
			if not String(gem_row[0]) in found:
				found.append(gem_row[0])
		var greats: Array = Monsters.GREAT_VALUABLES.filter(func(gem_row: Array) -> bool: return level >= int(gem_row[1]))
		if not greats.is_empty() and not String(greats[-1][0]) in found:
			found.append(greats[-1][0])
	return found


## Whether an entry matches a search: its name, a place, or a drop's name contains `text`.
static func matches(found: Dictionary, text: String) -> bool:
	var needle: String = text.strip_edges().to_lower()
	if needle.is_empty() or String(found["name"]).to_lower().contains(needle):
		return true
	for place: String in found["places"]:
		if place.to_lower().contains(needle):
			return true
	for gem: String in found.get("valuables", []):
		if String(World.ITEMS[gem]["name"]).to_lower().contains(needle):
			return true
	for drop: Array in found["drops"]:
		if String(World.ITEMS[drop[0]]["name"]).to_lower().contains(needle):
			return true
	return false
