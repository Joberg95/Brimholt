extends RefCounted
## Item catalog: definitions from items.json, stats derived from Balance by tier and slot.
## Equipment comes in tiers every TIER_STEP levels; accessories (amulets, capes, charms,
## rings) start at ACCESSORY_LEVEL. Weapons and off-hands belong to classes; helmets, armor, legs,
## and boots have an "armor" type (plate, mail, leather, cloth) that only its class wears (Balance.ARMOR_OF).

const Balance = preload("res://game/data/balance.gd")
const PATH: String = "res://game/data/items.json"
const TIER_LEVELS: Array[int] = [1, 5, 10, 15, 20, 25, 30, 35, 40, 45]
const ACCESSORY_LEVEL: int = 20
const ACCESSORY_SLOTS: Array[String] = ["necklace", "cape", "charm", "ring"]
## Relics: glowing level-50 gear that only final bosses drop. They are computed at level 50
## (one step past the last tier) and multiplied by RELIC_BONUS.
const RELIC_LEVEL: int = 50
const RELIC_BONUS: float = 1.15
## Defense of a full tier set (helmet, armor, legs, boots, shield) rises linearly from SET_DEFENSE_LOW at
## level 1 to SET_DEFENSE_HIGH at the last tier; each piece takes a share.
const SET_DEFENSE_LOW: float = 14.0
const SET_DEFENSE_HIGH: float = 70.0
const DEFENSE_SHARE: Dictionary = {"helmet": 0.15, "armor": 0.30, "legs": 0.15, "boots": 0.10, "shield": 0.30, "book": 0.06,
	"cape": 0.08}
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
## Gear rarity, shown in item tooltips: two tiers per grade (from this level up), and relics
## in their own glow colour. [from level, name, colour].
const RARITIES: Array = [
	[1, "Common", Color("#c9c4b8")], [10, "Uncommon", Color("#7ccf6a")], [20, "Rare", Color("#6a9cff")],
	[30, "Epic", Color("#b47cff")], [40, "Legendary", Color("#ff9a3c")],
]


## id -> {name, slot, level, vocations, look, colors, stats, [armor], [outfit], [gold], [value], [price], [sell],
## [drink], [bound], [slots], [loot_only]} in file order. "price" is the tier valuation,
## "sell" what vendors pay; loot_only items are never vendor stock or generic gear rolls.
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
		if entry.has("armor"):
			item["armor"] = String(entry["armor"])
		if entry.has("outfit"):
			item["outfit"] = String(entry["outfit"])
		if bool(entry.get("loot_only", false)):
			item["loot_only"] = true
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
			item["cooldown"] = float(entry.get("cooldown", 1.0))
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
		"legs", "boots":
			return {"defense": _defense(level, item["slot"])}
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


## [name, colour] of a wearable item's rarity, or [] for potions, materials, gold, and packs.
static func rarity(item: Dictionary) -> Array:
	if item.get("slot", "").is_empty() or item.get("slot", "") == "bag":
		return []
	if item.has("glow"):
		return ["Relic", item["glow"]]
	var grade: Array = RARITIES[0]
	for entry: Array in RARITIES:
		if item["level"] >= entry[0]:
			grade = entry
	return [grade[1], grade[2]]


## The highest tier level at or below `level`.
static func tier_for(level: int) -> int:
	var result: int = TIER_LEVELS[0]
	for tier: int in TIER_LEVELS:
		if level >= tier:
			result = tier
	return result
