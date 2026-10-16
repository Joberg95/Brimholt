extends RefCounted
## Item catalog: definitions from items.json, stats derived from Balance by tier and slot.
## Equipment comes in tiers every TIER_STEP levels; accessories (amulets, capes, charms,
## rings) start at ACCESSORY_LEVEL. Weapons and off-hands belong to classes; helmets, armor, legs,
## and boots have an "armor" type (plate, mail, leather, cloth) that only its class wears (Balance.ARMOR_OF).

const Balance = preload("res://game/data/balance.gd")
const Monsters = preload("res://game/data/monsters.gd")
const PATH: String = "res://game/data/items.json"
const TIER_LEVELS: Array[int] = [1, 5, 10, 15, 20, 25, 30, 35, 40, 45]
const ACCESSORY_LEVEL: int = 20
const ACCESSORY_SLOTS: Array[String] = ["necklace", "cape", "charm", "ring"]
## Relics: glowing level-50 gear that only final bosses drop. They are computed at level 50
## (one step past the last tier) and multiplied by RELIC_BONUS.
const RELIC_LEVEL: int = 50
const RELIC_BONUS: float = 1.15
## Mythic gear: unbound level-50 pieces (no glow) that only the level-50 farm monsters drop
## (Monsters.LOOT). Computed at RELIC_LEVEL with the smaller MYTHIC_BONUS: past the last tier, below relics.
const MYTHIC_BONUS: float = 1.05
## Quest pieces: bound gear that only a quest pays ("quest": the Hunters' Lodge chain or a boss
## task), a little better than the vendor piece of their tier. Being bound, they are never
## dropped on death, sold, or traded: what a player loses in PvP is only what they found or bought.
const QUEST_BONUS: float = 1.05
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
## Focused rings (items.json "focus"; monster drops) trade the tier ring's health, mana, and
## critical for more of one thing: twice the health or mana share, CRITICAL_RING * 2 + 1 critical,
## a charm's healing or 1.5x its regen with half the health, or a cape's defenses.
const RING_FOCUS: Array[String] = ["health", "mana", "critical", "healing", "regen", "defense"]
## Focused helmets and boots (showpieces that monsters drop) keep HELMET_FOCUS_DEFENSE of their defenses and
## add one bonus: half a rod's healing, half a book's mana, a ring's critical, an armor's regen,
## or half an amulet's health.
const HELMET_FOCUS: Array[String] = ["health", "mana", "critical", "healing", "regen"]
const HELMET_FOCUS_DEFENSE: float = 0.85
## Magic defense of capes, amulets, and books, as shares of their tier's set defense.
const MAGIC_SHARE: Dictionary = {"cape": 0.15, "necklace": 0.10, "book": 0.10}
## Critical chance (percent) on Hunters' and Sorcerers' weapons: CRITICAL_WEAPON, plus one more
## every other tier; rings add CRITICAL_RING. Druids' rods add healing power instead
## (ROD_HEALING of the reference health).
const CRITICAL_WEAPON: int = 2
const CRITICAL_RING: int = 2
const ROD_HEALING: float = 0.015
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
	[30, "Epic", Color("#b47cff")], [40, "Legendary", Color("#ff9a3c")], [RELIC_LEVEL, "Mythic", Color("#ff5a7a")],
]
## Lowest material value of each grade (Common, Uncommon, Rare, Epic, Legendary).
const QUALITY_VALUES: Array[int] = [0, 50, 150, 400, 1000]
## RARITIES index of Epic, the first grade only bosses, champions, and quests give equipment.
const EPIC: int = 3
## Gathered resources (game/data/professions.gd) grade by their band's value instead.
const GATHERED_LOOKS: Array[String] = ["ore", "log", "herb", "fish"]
const RESOURCE_VALUES: Array[int] = [0, 4, 7, 10, 14]


## id -> {name, slot, level, vocations, look, colors, stats, [armor], [outfit], [gold], [value], [price], [sell],
## [drink, cooldown, timer], [eat], [bound], [slots], [loot_only], [sold], [quest], [focus], [shine]} in file order. "sold" puts
## an item without a gear slot (a bag) in vendor stock. Potions sharing a
## "timer" share one cooldown (a strong health potion waits on the health potion's timer). "price" is the tier valuation,
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
		if entry.has("rune"):
			item["rune"] = String(entry["rune"])
		if bool(entry.get("loot_only", false)):
			item["loot_only"] = true
		if bool(entry.get("sold", false)):
			item["sold"] = true
		if entry.has("quest"):
			item["quest"] = String(entry["quest"])
		if entry.has("focus"):
			item["focus"] = String(entry["focus"])
		if entry.has("shine"):
			item["shine"] = String(entry["shine"])
		if boss_drops().has(String(entry["id"])):
			item["boss_drop"] = true
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
			item["timer"] = String(entry.get("timer", entry["id"]))
		if entry.has("eat"):
			item["eat"] = {"regen": float(entry["eat"]["regen"]), "seconds": float(entry["eat"]["seconds"])}
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
			if item.has("glow") or mythic(item) or item.has("quest"):
				var bonus: float = float(entry.get("bonus", RELIC_BONUS)) if item.has("glow") \
					else QUEST_BONUS if item.has("quest") else MYTHIC_BONUS
				stats = with_bonus(stats, bonus)
		# "extra" stats add on top of the derived ones (a crown's frost damage).
		for stat: String in entry.get("extra", {}):
			stats[stat] = int(stats.get(stat, 0)) + int(entry["extra"][stat])
		item["stats"] = stats
		catalog[String(entry["id"])] = item
	return catalog


static func gear_price(level: int, slot: String) -> int:
	var price: float = GEAR_PRICE * pow(level, PRICE_EXPONENT) * (WEAPON_PRICE if slot == "main_hand" else 1.0)
	return maxi(5, 5 * roundi(price / 5.0))


## Tier stats raised by a relic, mythic, or quest bonus: at least one point better in every stat,
## so the bonus shows even on small numbers.
static func with_bonus(stats: Dictionary, bonus: float) -> Dictionary:
	var raised: Dictionary = {}
	for stat: String in stats:
		raised[stat] = maxi(roundi(stats[stat] * bonus), stats[stat] + 1)
	return raised


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
			var tier: int = maxi(0, TIER_LEVELS.find(tier_for(level)))
			var floor_attack: int = 2 + tier
			var weapon: Dictionary = {"attack": maxi(floor_attack, roundi(budget * Balance.VOCATIONS[vocation]["damage"]))}
			if vocation in ["paladin", "sorcerer"]:
				weapon["critical"] = CRITICAL_WEAPON + (tier + 1) / 2
			elif vocation == "druid":
				weapon["healing"] = maxi(1, roundi(reference_health(level) * ROD_HEALING))
			return weapon
		"helmet", "armor", "legs", "boots":
			var piece: Dictionary = _armor(level, item["slot"], item.get("armor", ""))
			if item["slot"] == "armor":
				piece["regen"] = maxi(1, roundi(reference_health(level) * ARMOR_REGEN))
			if item["slot"] in ["helmet", "boots"] and item.has("focus"):
				for stat: String in piece:
					piece[stat] = maxi(1, roundi(piece[stat] * HELMET_FOCUS_DEFENSE))
				match String(item["focus"]):
					"healing":
						piece["healing"] = maxi(1, roundi(reference_health(level) * ROD_HEALING * 0.5))
					"mana":
						piece["mana"] = maxi(5, roundi(reference_mana(level) * BOOK_MANA * 0.5))
					"critical":
						piece["critical"] = CRITICAL_RING
					"regen":
						piece["regen"] = maxi(1, roundi(reference_health(level) * ARMOR_REGEN))
					"health":
						piece["health"] = roundi(reference_health(level) * AMULET_HEALTH * 0.5)
			return piece
		"off_hand":
			if item["look"] == "book":
				return {"defense": _defense(level, "book"), "magic_defense": _magic(level, "book"),
					"mana": maxi(5, roundi(reference_mana(level) * BOOK_MANA))}
			return {"defense": _defense(level, "shield")}
		"necklace":
			return {"health": roundi(reference_health(level) * AMULET_HEALTH), "magic_defense": _magic(level, "necklace")}
		"cape":
			return {"magic_defense": _magic(level, "cape"), "mana": roundi(reference_mana(level) * CAPE_MANA)}
		"charm":
			return {"regen": roundi(reference_health(level) * CHARM_REGEN), "healing": roundi(reference_health(level) * CHARM_HEALING)}
		"ring":
			var health: int = roundi(reference_health(level) * RING_SHARE)
			match String(item.get("focus", "")):
				"health":
					return {"health": health * 2}
				"mana":
					return {"mana": roundi(reference_mana(level) * RING_SHARE) * 2}
				"critical":
					return {"critical": CRITICAL_RING * 2 + 1}
				"healing":
					return {"healing": maxi(1, roundi(reference_health(level) * CHARM_HEALING)), "health": health / 2}
				"regen":
					return {"regen": maxi(1, roundi(reference_health(level) * CHARM_REGEN * 1.5)), "health": health / 2}
				"defense":
					return {"defense": _defense(level, "cape"), "magic_defense": _magic(level, "cape")}
			return {"health": health, "mana": roundi(reference_mana(level) * RING_SHARE), "critical": CRITICAL_RING}
	return {}


## A helmet, armor, legs, or boots piece: its share of the set defense, split into defense and
## magic defense by its armor type (Balance.ARMOR_TYPES). A piece without a type (a relic that
## fits everyone) serves every wearer as well as their own type would: the best of each. The
## total is rounded once and then split, so every tier stays an upgrade on the one below.
static func _armor(level: int, slot: String, armor: String) -> Dictionary:
	var kind: Dictionary = Balance.ARMOR_TYPES.get(armor, {})
	if kind.is_empty():
		for type: String in Balance.ARMOR_TYPES:
			for stat: String in Balance.ARMOR_TYPES[type]:
				kind[stat] = maxf(kind.get(stat, 0.0), Balance.ARMOR_TYPES[type][stat])
	var share: float = set_defense(level) * DEFENSE_SHARE[slot]
	var total: int = roundi(share * (kind["defense"] + kind["magic_defense"]))
	var magic: int = mini(total, roundi(share * kind["magic_defense"]))
	var piece: Dictionary = {"defense": total - magic}
	if magic > 0:
		piece["magic_defense"] = magic
	return piece


static func _magic(level: int, part: String) -> int:
	return maxi(1, roundi(set_defense(level) * MAGIC_SHARE[part]))


## [name, colour] of an item's quality, or [] for gold. Gear grades by tier (two tiers per
## grade) up to Rare; Epic and Legendary only for boss and champion drops and quest rewards; mythic
## gear and relics have their own; everything else grades by worth: materials and
## resources by value (QUALITY_VALUES), potions by strength, food by its regeneration, and bags
## and packs by their slots.
static func rarity(item: Dictionary) -> Array:
	if item.has("glow"):
		return ["Relic", item["glow"]]
	var grade: int = quality(item)
	return [] if grade < 0 else [RARITIES[grade][1], RARITIES[grade][2]]


## Index into RARITIES (-1 for gold piles and unknown items).
static func quality(item: Dictionary) -> int:
	var slot: String = item.get("slot", "")
	if item.is_empty() or item.has("gold"):
		return -1
	# Mounts are 1% boss drops: Legendary whatever their level.
	if slot == "mount":
		return RARITIES.size() - 2
	if slot in ["bag", "container"]:
		var slots: int = int(item.get("slots", 0))
		return clampi((slots - 6) / 2, 0, 4) if slot == "container" else clampi(slots / 4, 0, 4)
	if not slot.is_empty():
		var grade: int = 0
		for index: int in RARITIES.size():
			if item.get("level", 1) >= RARITIES[index][0]:
				grade = index
		# Epic and Legendary mean a boss or a quest: tier gear from vendors and ordinary monsters
		# stops at Rare, however high its level (mythic level-50 sets keep their own grade).
		if grade >= EPIC and grade < RARITIES.size() - 1 and not item.has("quest") and not item.get("boss_drop", false):
			grade = EPIC - 1
		return grade
	if item.has("drink"):
		var share: float = 0.0
		for stat: String in item["drink"]:
			share += float(item["drink"][stat])
		return clampi(floori((share - 0.2) / 0.1 + 0.001), 0, 4)
	if item.has("eat"):
		return clampi(roundi((float(item["eat"]["regen"]) - 0.2) / 0.18), 0, 4)
	var value: int = int(item.get("value", 0))
	var thresholds: Array[int] = RESOURCE_VALUES if item.get("look", "") in GATHERED_LOOKS else QUALITY_VALUES
	var result: int = 0
	for index: int in thresholds.size():
		if value >= thresholds[index]:
			result = index
	return result


## Items only champions and bosses drop (their own loot in Monsters.LOOT, no ordinary monster's):
## with quest rewards, the only equipment that grades Epic or Legendary.
static func boss_drops() -> Dictionary:
	var boss: Dictionary = {}
	var common: Dictionary = {}
	for kind: String in Monsters.LOOT:
		var rank: String = Monsters.MONSTERS[kind]["rank"]
		for entry: Array in Monsters.LOOT[kind]:
			if rank in ["champion", "boss"]:
				boss[entry[0]] = true
			else:
				common[entry[0]] = true
	for kind: String in Monsters.MOUNTS:
		boss[Monsters.MOUNTS[kind]] = true
	for id: String in common:
		boss.erase(id)
	return boss


## Whether an item is mythic: unbound level-50 equipment that monsters drop (not a relic).
static func mythic(item: Dictionary) -> bool:
	return item.get("level", 0) == RELIC_LEVEL and not item.get("slot", "").is_empty() and not item.has("glow") \
		and not item.get("bound", false)


## The highest tier level at or below `level`.
static func tier_for(level: int) -> int:
	var result: int = TIER_LEVELS[0]
	for tier: int in TIER_LEVELS:
		if level >= tier:
			result = tier
	return result
