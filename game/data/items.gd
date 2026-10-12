extends RefCounted
## Item catalog: definitions from items.json, stats derived from Balance by tier and slot.
## Equipment comes in tiers every TIER_STEP levels; accessories (amulets, capes, charms,
## rings) start at ACCESSORY_LEVEL. Weapons and off-hands belong to vocations.

const Balance = preload("res://game/data/balance.gd")
const PATH: String = "res://game/data/items.json"
const TIER_LEVELS: Array[int] = [1, 5, 10, 15, 20, 25, 30, 35, 40, 45]
const ACCESSORY_LEVEL: int = 20
const ACCESSORY_SLOTS: Array[String] = ["necklace", "cape", "charm", "ring"]
## Relics: glowing level-50 gear that only final bosses drop. They are computed at level 50
## (one step past the last tier) and multiplied by RELIC_BONUS.
const RELIC_LEVEL: int = 50
const RELIC_BONUS: float = 1.15
## Defense of a full tier set (helmet, armor, shield) rises linearly from SET_DEFENSE_LOW at
## level 1 to SET_DEFENSE_HIGH at the last tier; each piece takes a share.
const SET_DEFENSE_LOW: float = 14.0
const SET_DEFENSE_HIGH: float = 70.0
const DEFENSE_SHARE: Dictionary = {"helmet": 0.22, "armor": 0.42, "shield": 0.36, "book": 0.12, "cape": 0.08}
## Weapons are tuned to the attack budget a little into their tier (Balance.gear_attack_budget),
## so each tier is an upgrade that slowly falls behind until the next one.
const WEAPON_LEVEL_OFFSET: int = 2
## Shares of the reference (Paladin) health or mana curve at the item's level.
const ARMOR_REGEN: float = 0.01
const BOOK_MANA: float = 0.10
const AMULET_HEALTH: float = 0.06
const CAPE_MANA: float = 0.06
const CHARM_REGEN: float = 0.02
const CHARM_HEALING: float = 0.01
const RING_SHARE: float = 0.03
## Vendor price of equipment: GEAR_PRICE x level^PRICE_EXPONENT (weapons x WEAPON_PRICE),
## rounded to 5 gold. Vendors buy unbound equipment back for SELL_SHARE of it.
const GEAR_PRICE: float = 40.0
const PRICE_EXPONENT: float = 1.05
const WEAPON_PRICE: float = 1.25
const SELL_SHARE: float = 0.25
## Name colour per tier level in tooltips and slot borders.
const TIER_COLORS: Dictionary = {
	1: Color("#cfc6b8"), 5: Color("#b8c0c8"), 10: Color("#d8b070"), 15: Color("#d8e0e8"), 20: Color("#9fe0a0"),
	25: Color("#8ab0ff"), 30: Color("#ff9a5a"), 35: Color("#c8a0ff"), 40: Color("#ffe080"), 45: Color("#6ae0c8"),
}


## id -> {name, slot, level, vocations, look, colors, stats, [gold], [value], [price], [sell],
## [drink], [bound], [slots]} in file order. "price" is what vendors charge, "sell" what they pay.
static func load_catalog() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert(typeof(parsed) == TYPE_DICTIONARY, "items.json did not parse")
	var catalog: Dictionary = {}
	for entry: Dictionary in parsed["items"]:
		var item: Dictionary = {
			"name": String(entry["name"]), "slot": String(entry.get("slot", "")), "level": int(entry.get("level", 1)),
			"look": String(entry.get("look", "")), "colors": Array(entry.get("colors", []), TYPE_STRING, "", null),
		}
		var vocations: Array[String] = []
		for vocation: Variant in entry.get("vocations", []):
			vocations.append(String(vocation))
		item["vocations"] = vocations
		for key: String in ["gold", "value", "price", "slots"]:
			if entry.has(key):
				item[key] = int(entry[key])
		if entry.has("glow"):
			item["glow"] = Color(String(entry["glow"]))
		if bool(entry.get("bound", false)) or item.has("glow"):
			item["bound"] = true
		if entry.has("drink"):
			var drink: Dictionary = {}
			for stat: String in entry["drink"]:
				drink[stat] = float(entry["drink"][stat])
			item["drink"] = drink
		if not item["slot"].is_empty() and not item.has("bound") and not item.has("price"):
			item["price"] = gear_price(item["level"], item["slot"])
		if item.has("value"):
			item["sell"] = item["value"]
		elif not item["slot"].is_empty() and not item.has("bound"):
			item["sell"] = maxi(1, floori(item["price"] * SELL_SHARE))
		var stats: Dictionary = {}
		if entry.has("stats"):
			for stat: String in entry["stats"]:
				stats[stat] = int(entry["stats"][stat])
		elif not item["slot"].is_empty():
			stats = tier_stats(item)
			if item.has("glow"):
				for stat: String in stats:
					stats[stat] = roundi(stats[stat] * float(entry.get("bonus", RELIC_BONUS)))
		item["stats"] = stats
		catalog[String(entry["id"])] = item
	return catalog


static func gear_price(level: int, slot: String) -> int:
	var price: float = GEAR_PRICE * pow(level, PRICE_EXPONENT) * (WEAPON_PRICE if slot == "main_hand" else 1.0)
	return maxi(5, 5 * roundi(price / 5.0))


## Rises linearly through the tiers and continues to RELIC_LEVEL.
static func set_defense(level: int) -> float:
	var last: int = TIER_LEVELS[-1]
	return SET_DEFENSE_LOW + (SET_DEFENSE_HIGH - SET_DEFENSE_LOW) * (clampi(level, 1, RELIC_LEVEL) - 1) / float(last - 1)


static func _defense(level: int, part: String) -> int:
	return roundi(set_defense(level) * DEFENSE_SHARE[part])


static func reference_health(level: int) -> int:
	return Balance.player_health(level)


static func reference_mana(level: int) -> int:
	return Balance.base_stats(level, Balance.DEFAULT_VOCATION)["mana"]


static func tier_stats(item: Dictionary) -> Dictionary:
	var level: int = item["level"]
	match item["slot"]:
		"main_hand":
			var vocation: String = item["vocations"][0] if not item["vocations"].is_empty() else Balance.DEFAULT_VOCATION
			var budget: float = Balance.gear_attack_budget_exact(mini(level + WEAPON_LEVEL_OFFSET, Balance.MAX_LEVEL))
			# Low tiers have budgets of a point or two, so a floor that rises one per tier keeps
			# every tier an upgrade; from about tier 25 the balance curve dominates.
			var floor_attack: int = 2 + maxi(0, TIER_LEVELS.find(tier_for(level)))
			return {"attack": maxi(floor_attack, roundi(budget * Balance.VOCATIONS[vocation]["damage"]))}
		"helmet":
			return {"defense": _defense(level, "helmet")}
		"armor":
			return {"defense": _defense(level, "armor"), "regen": maxi(1, roundi(reference_health(level) * ARMOR_REGEN))}
		"off_hand":
			if item["look"] == "book":
				return {"defense": _defense(level, "book"), "mana": maxi(5, roundi(reference_mana(level) * BOOK_MANA))}
			return {"defense": _defense(level, "shield")}
		"necklace":
			return {"health": roundi(reference_health(level) * AMULET_HEALTH)}
		"cape":
			return {"defense": _defense(level, "cape"), "mana": roundi(reference_mana(level) * CAPE_MANA)}
		"charm":
			return {"regen": roundi(reference_health(level) * CHARM_REGEN), "healing": roundi(reference_health(level) * CHARM_HEALING)}
		"ring":
			return {"health": roundi(reference_health(level) * RING_SHARE), "mana": roundi(reference_mana(level) * RING_SHARE)}
	return {}


static func tier_color(level: int) -> Color:
	return TIER_COLORS[tier_for(level)]


## Name and border colour: a relic's glow, else its tier colour.
static func item_color(item: Dictionary) -> Color:
	return item["glow"] if item.has("glow") else tier_color(item["level"])


## The highest tier level at or below `level`.
static func tier_for(level: int) -> int:
	var result: int = TIER_LEVELS[0]
	for tier: int in TIER_LEVELS:
		if level >= tier:
			result = tier
	return result
