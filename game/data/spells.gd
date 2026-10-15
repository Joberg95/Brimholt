extends RefCounted
## Original spells, cast from the action bar. Mana costs are a fraction of the caster's max
## mana; damage multiplies the caster's attack; heals restore a fraction of the healed
## player's max health ("heal_self") or the caster's healing stat times power ("heal_area").
## Like Tibia, every spell has its own cooldown and also starts its group's shared cooldown.
## "taunt" (Challenge) turns nearby monsters, bosses included, onto the caster: the tank swap.
## "taunt_target" (Provoke) turns one monster, your target, onto the caster from a few tiles away:
## pull it off a healer before it reaches them. Monsters keep a target until they lose it.
## "root" (Entangling roots) and "slow" (Crippling arrow) hit the target and then hold it in
## place, or halve its pace, for the spell's "seconds" (Combat.restrain); bosses shrug them off,
## and a player cannot be held again until RESTRAIN_IMMUNITY seconds after it ends.

const Balance = preload("res://game/data/balance.gd")
## Each spell is carved as one Elder Futhark rune (its icon in assets/sprites/spells.png, drawn by
## tools/generators/make_sprites.py): rune id -> [name, meaning].
const RUNES: Dictionary = {
	"fehu": ["Fehu", "wealth"], "uruz": ["Uruz", "strength"], "thurisaz": ["Thurisaz", "Thor's thorn"],
	"ansuz": ["Ansuz", "the gods"], "raido": ["Raido", "the thunder road"], "kenaz": ["Kenaz", "the torch"],
	"gebo": ["Gebo", "the gift"], "wunjo": ["Wunjo", "joy"], "hagalaz": ["Hagalaz", "hail"], "naudiz": ["Naudiz", "need"],
	"isa": ["Isa", "ice"], "jera": ["Jera", "the turning year"], "eihwaz": ["Eihwaz", "the yew"],
	"perthro": ["Perthro", "fate"], "algiz": ["Algiz", "protection"], "sowilo": ["Sowilo", "the sun"],
	"tiwaz": ["Tiwaz", "Tyr's spear"], "berkano": ["Berkano", "the birch"], "ehwaz": ["Ehwaz", "the horse"],
	"mannaz": ["Mannaz", "kinship"], "laguz": ["Laguz", "water"], "ingwaz": ["Ingwaz", "the hearth"],
	"dagaz": ["Dagaz", "the dawn"], "othala": ["Othala", "the homeland"],
	# From the Anglo-Saxon row, for spells past the Elder Futhark's twenty-four.
	"ear": ["Ear", "the earth"], "yr": ["Yr", "the yew bow"],
}
const GROUP_SECONDS: Dictionary = {"attack": 2.0, "healing": 1.0, "rune": 2.0}
## Rune spells: items (items.json "rune") that level 40+ hunting grounds drop. Any class casts one
## from the action bar at its target within RUNE_RANGE, using it up; all runes share the "rune"
## cooldown group. They are magic, and their damage follows the caster's level, not class
## (Balance.geared_attack x power). Shapes, as in Tibia: "circle" is every tile within `radius`
## (radius 3 is 37 tiles; Combat.circle), "chain" hits the target and then `jumps` more enemies
## within `reach` of it for `chain_power`. Frost also slows what it hits (Combat.restrain).
const RUNE_RANGE: int = 7
const RUNES_BY_ELEMENT: Dictionary = {
	"fire": {"name": "Fire rune", "shape": "circle", "radius": 3, "power": 1.2, "color": Color("#ff7a2a")},
	"frost": {"name": "Frost rune", "shape": "circle", "radius": 2, "power": 1.2, "slow": 2.0, "color": Color("#8ad8ff")},
	"lightning": {"name": "Lightning rune", "shape": "chain", "power": 2.4, "jumps": 2, "reach": 3, "chain_power": 1.2,
		"color": Color("#ffe060")},
}
## Spell ranks: a class trainer raises a known spell one rank for rune shards (rank 2 costs
## RANK_COSTS[0], rank 3 RANK_COSTS[1]); each rank above 1 adds RANK_POWER to its power
## (damage or healing). Challenge has no power and cannot be empowered.
const MAX_RANK: int = 3
const RANK_COSTS: Array[int] = [3, 6]
const RANK_POWER: float = 0.15
const SHARD: String = "rune_shard"
const SPELLS: Dictionary = {
	"light_heal": {"rune": "berkano", "name": "Light heal", "vocations": ["knight", "paladin", "sorcerer", "druid"], "level": 1,
		"kind": "heal_self", "power": 0.15, "mana": 0.15, "cooldown": 2.0, "group": "healing", "color": Color("#7fe08a")},
	"brutal_blow": {"rune": "uruz", "name": "Brutal blow", "vocations": ["knight"], "level": 1, "kind": "target", "range": 1,
		"power": 2.0, "mana": 0.15, "cooldown": 4.0, "group": "attack", "color": Color("#e0b060")},
	"whirling_strike": {"rune": "jera", "name": "Whirling strike", "vocations": ["knight"], "level": 10, "kind": "area_self",
		"radius": 1, "power": 1.4, "mana": 0.25, "cooldown": 6.0, "group": "attack", "color": Color("#e0d0a0")},
	"challenge": {"rune": "algiz", "name": "Challenge", "vocations": ["knight"], "level": 20, "kind": "taunt", "radius": 2,
		"power": 0.0, "mana": 0.1, "cooldown": 4.0, "group": "attack", "color": Color("#f0c060")},
	"piercing_shot": {"rune": "tiwaz", "name": "Piercing shot", "vocations": ["paladin"], "level": 1, "kind": "target", "range": 6,
		"power": 1.8, "mana": 0.1, "cooldown": 4.0, "group": "attack", "color": Color("#f0e6b0")},
	"holy_mend": {"rune": "wunjo", "name": "Holy mend", "vocations": ["paladin"], "level": 8, "kind": "heal_self", "power": 0.3,
		"mana": 0.15, "cooldown": 3.0, "group": "healing", "color": Color("#f6e38a")},
	"ember_bolt": {"rune": "kenaz", "name": "Ember bolt", "vocations": ["sorcerer"], "level": 1, "kind": "target", "range": 5,
		"power": 2.2, "mana": 0.08, "cooldown": 2.0, "group": "attack", "color": Color("#ff8a4a")},
	"flame_wave": {"rune": "fehu", "name": "Flame wave", "vocations": ["sorcerer"], "level": 10, "kind": "area_target", "range": 5,
		"radius": 1, "power": 1.5, "mana": 0.2, "cooldown": 6.0, "group": "attack", "color": Color("#ff6a30")},
	"frost_bolt": {"rune": "isa", "name": "Frost bolt", "vocations": ["druid"], "level": 1, "kind": "target", "range": 5,
		"power": 1.6, "mana": 0.06, "cooldown": 2.0, "group": "attack", "color": Color("#8ad0ff")},
	"mend": {"rune": "laguz", "name": "Mend", "vocations": ["druid"], "level": 1, "kind": "heal_self", "power": 0.35, "mana": 0.1,
		"cooldown": 1.0, "group": "healing", "color": Color("#7fe08a")},
	# Higher-level spells: each vocation unlocks a stronger strike around level 15-20, another at 30,
	# and a signature spell at 40-45, so damage (or a druid's group healing) keeps growing with level.
	"rending_cut": {"rune": "naudiz", "name": "Rending cut", "vocations": ["knight"], "level": 20, "kind": "target", "range": 1,
		"power": 2.8, "mana": 0.15, "cooldown": 6.0, "group": "attack", "color": Color("#d89a5a")},
	"sundering_blow": {"rune": "thurisaz", "name": "Sundering blow", "vocations": ["knight"], "level": 30, "kind": "target", "range": 1,
		"power": 3.8, "mana": 0.2, "cooldown": 10.0, "group": "attack", "color": Color("#c8703a")},
	"earthshaker": {"rune": "othala", "name": "Earthshaker", "vocations": ["knight"], "level": 40, "kind": "area_self", "radius": 2,
		"power": 2.0, "mana": 0.3, "cooldown": 14.0, "group": "attack", "color": Color("#b89a6a")},
	"arrow_volley": {"rune": "ehwaz", "name": "Arrow volley", "vocations": ["paladin"], "level": 15, "kind": "area_target", "range": 6,
		"radius": 1, "power": 1.6, "mana": 0.15, "cooldown": 8.0, "group": "attack", "color": Color("#e8d8a0")},
	"radiant_arrow": {"rune": "sowilo", "name": "Radiant arrow", "vocations": ["paladin"], "level": 30, "kind": "target", "range": 6,
		"power": 3.2, "mana": 0.15, "cooldown": 8.0, "group": "attack", "color": Color("#fff0a0")},
	"sunlance_barrage": {"rune": "dagaz", "name": "Sunlance barrage", "vocations": ["paladin"], "level": 40, "kind": "area_target", "range": 6,
		"radius": 2, "power": 1.9, "mana": 0.3, "cooldown": 14.0, "group": "attack", "color": Color("#ffe070")},
	"arc_lightning": {"rune": "raido", "name": "Arc lightning", "vocations": ["sorcerer"], "level": 20, "kind": "target", "range": 5,
		"power": 3.2, "mana": 0.12, "cooldown": 6.0, "group": "attack", "color": Color("#a0c8ff")},
	"firestorm": {"rune": "ingwaz", "name": "Firestorm", "vocations": ["sorcerer"], "level": 30, "kind": "area_target", "range": 5,
		"radius": 2, "power": 1.8, "mana": 0.25, "cooldown": 10.0, "group": "attack", "color": Color("#ff5a20")},
	"starfall": {"rune": "perthro", "name": "Starfall", "vocations": ["sorcerer"], "level": 45, "kind": "area_target", "range": 5,
		"radius": 2, "power": 2.6, "mana": 0.35, "cooldown": 16.0, "group": "attack", "color": Color("#d8b0ff")},
	"thorn_lash": {"rune": "eihwaz", "name": "Thorn lash", "vocations": ["druid"], "level": 15, "kind": "target", "range": 5,
		"power": 2.4, "mana": 0.1, "cooldown": 6.0, "group": "attack", "color": Color("#7ac85a")},
	"hailstorm": {"rune": "hagalaz", "name": "Hailstorm", "vocations": ["druid"], "level": 30, "kind": "area_target", "range": 5,
		"radius": 2, "power": 1.5, "mana": 0.22, "cooldown": 10.0, "group": "attack", "color": Color("#c8e8ff")},
	"wild_growth": {"rune": "mannaz", "name": "Wild growth", "vocations": ["druid"], "level": 40, "kind": "heal_area", "radius": 3,
		"power": 5.0, "mana": 0.3, "cooldown": 8.0, "group": "healing", "color": Color("#60e070")},
	"mass_mend": {"rune": "gebo", "name": "Mass mend", "vocations": ["druid"], "level": 1, "kind": "heal_area", "radius": 3,
		"power": 3.0, "mana": 0.2, "cooldown": 2.0, "group": "healing", "color": Color("#a6f0b0")},
	"entangling_roots": {"rune": "ear", "name": "Entangling roots", "vocations": ["druid"], "level": 12, "kind": "root", "range": 5,
		"power": 0.6, "seconds": 3.0, "mana": 0.12, "cooldown": 12.0, "group": "attack", "color": Color("#6ab04a")},
	"crippling_arrow": {"rune": "yr", "name": "Crippling arrow", "vocations": ["paladin"], "level": 12, "kind": "slow", "range": 6,
		"power": 1.0, "seconds": 4.0, "mana": 0.1, "cooldown": 10.0, "group": "attack", "color": Color("#c8b070")},
	"provoke": {"rune": "ansuz", "name": "Provoke", "vocations": ["knight"], "level": 8, "kind": "taunt_target", "range": 4,
		"power": 0.0, "mana": 0.05, "cooldown": 6.0, "group": "attack", "color": Color("#f08a50")},
}


## Whether `vocation` may cast `id`: its own spells, or for Adventurers the spells every
## vocation shares.
static func allows(id: String, vocation: String) -> bool:
	var vocations: Array = SPELLS[id]["vocations"]
	if vocation == Balance.ADVENTURER:
		return vocations.size() == Balance.VOCATIONS.size()
	return vocation in vocations


## A vocation's spells by unlock level (catalog order within a level): the action bar's order.
static func for_vocation(vocation: String) -> Array[String]:
	var result: Array[String] = []
	var order: Dictionary = {}
	for id: String in SPELLS:
		if allows(id, vocation):
			order[id] = SPELLS[id]["level"] * 1000 + result.size()
			result.append(id)
	result.sort_custom(func(a: String, b: String) -> bool: return order[a] < order[b])
	return result


## A spell's power at a rank (1 = unranked).
static func ranked_power(id: String, rank: int) -> float:
	return SPELLS[id]["power"] * (1.0 + RANK_POWER * (clampi(rank, 1, MAX_RANK) - 1))


## Whether a spell can be empowered at all.
static func rankable(id: String) -> bool:
	return SPELLS.has(id) and SPELLS[id]["power"] > 0.0


## Rune shards the next rank costs, or 0 at the top rank.
static func rank_cost(rank: int) -> int:
	return RANK_COSTS[rank - 1] if rank >= 1 and rank < MAX_RANK else 0


## What a spell does, for its tooltip and the spell book, from the same numbers Combat.cast uses.
## `stats` are the caster's World.stats (empty: no estimates); `level` gates "unlocked".
## Returns name, requirement, effect, amount ("" for none), cost, cooldown, and unlocked.
static func info(id: String, stats: Dictionary, level: int, rank: int = 1) -> Dictionary:
	var spell: Dictionary = SPELLS[id]
	var power: float = ranked_power(id, rank)
	var radius: int = spell.get("radius", 0)
	var area: String = "%d tile%s" % [radius, "" if radius == 1 else "s"]
	var reach: int = spell.get("range", 1)
	var effect: String = ""
	var amount: String = ""
	var attack: float = float(stats.get("attack", 0))
	var hit: String = "%d–%d damage before armour" % [roundi(attack * power * 0.85), roundi(attack * power * 1.15)]
	match spell["kind"]:
		"target":
			effect = "Strikes %s for %s× your attack." % ["an adjacent target" if reach <= 1
				else "your target up to %d tiles away" % reach, number(power)]
			amount = hit
		"area_self":
			effect = "Hits every enemy within %s of you for %s× your attack." % [area, number(power)]
			amount = hit + " each"
		"area_target":
			effect = "Hits your target (up to %d tiles away) and every enemy within %s of it for %s× your attack." % [
				reach, area, number(power)]
			amount = hit + " each"
		"taunt":
			effect = "Turns every monster within %s of you, bosses included, onto you: take a boss off a wounded ally." % area
		"taunt_target":
			effect = "Turns your target monster (up to %d tiles away), bosses included, onto you: pull it off a friend." % reach
		"root":
			effect = "Strikes your target (up to %d tiles away) for %s× your attack and roots it in place for %s s." % [
				reach, number(power), number(spell["seconds"])]
			amount = hit
		"slow":
			effect = "Strikes your target (up to %d tiles away) for %s× your attack and halves its pace for %s s." % [
				reach, number(power), number(spell["seconds"])]
			amount = hit
		"heal_self":
			effect = "Heals you for %d%% of your max health." % roundi(power * 100.0)
			amount = "Heals about %d" % roundi(float(stats.get("health", 0)) * power)
		"heal_area":
			effect = "Heals every player within %s of you, you included, for %s× your healing." % [area, number(power)]
			amount = "Heals %d each" % maxi(1, roundi(float(stats.get("healing", 0)) * power))
	if stats.is_empty():
		amount = ""
	var cost: String = "Mana %d%%" % roundi(spell["mana"] * 100.0)
	if stats.has("mana"):
		cost = "Mana %d (%d%% of your max)" % [maxi(1, roundi(float(stats["mana"]) * spell["mana"])), roundi(spell["mana"] * 100.0)]
	var vocations: Array = spell["vocations"]
	var who: String = "Every class" if vocations.size() == Balance.VOCATIONS.size() \
		else ", ".join(vocations.map(_class_name))
	var rune: Array = RUNES[spell["rune"]]
	var ranked: int = clampi(rank, 1, MAX_RANK)
	return {
		"name": spell["name"] if ranked == 1 else "%s · rank %d" % [spell["name"], ranked], "rank": ranked,
		"unlocked": level >= spell["level"], "rune": "Rune of %s (%s)" % [rune[0], rune[1]],
		"requirement": "%s · level %d" % [who, spell["level"]] if level >= spell["level"]
			else "✗ Needs level %d (%s)" % [spell["level"], who],
		"effect": effect, "amount": amount, "cost": cost,
		"cooldown": "Cooldown %s s, and %s s for all %s spells" % [number(spell["cooldown"]),
			number(GROUP_SECONDS[spell["group"]]), spell["group"]],
	}


## A rune item's spell (RUNES_BY_ELEMENT), or {} for any other item.
static func rune_of(item: Dictionary) -> Dictionary:
	return RUNES_BY_ELEMENT.get(item.get("rune", ""), {})


## A rune's tooltip lines: what it does, its reach, and its cooldown.
static func rune_text(item: Dictionary) -> String:
	var rune: Dictionary = rune_of(item)
	if rune.is_empty():
		return ""
	var effect: String
	if rune["shape"] == "circle":
		effect = "Rune spell: hits every enemy within %d tiles of your target for %s× a geared attack of your level." % [
			rune["radius"], number(rune["power"])]
	else:
		effect = "Rune spell: strikes your target for %s× a geared attack of your level, then leaps to %d more enemies within %d tiles for %s×." % [
			number(rune["power"]), rune["jumps"], rune["reach"], number(rune["chain_power"])]
	if rune.has("slow"):
		effect += " Slows what it hits for %s s." % number(rune["slow"])
	var lines: PackedStringArray = [effect,
		"Magic damage, any class from level %d, range %d. Drag it to the action bar; each cast uses one." % [item["level"], RUNE_RANGE],
		"Cooldown %s s for all runes." % number(GROUP_SECONDS["rune"])]
	return "\n".join(lines)


## The tooltip text: name, requirement, effect, then the numbers.
static func describe(id: String, stats: Dictionary, level: int, rank: int = 1) -> String:
	var details: Dictionary = info(id, stats, level, rank)
	var lines: PackedStringArray = [details["name"], details["requirement"], details["rune"], details["effect"]]
	if not details["amount"].is_empty():
		lines.append(details["amount"])
	lines.append(details["cost"])
	lines.append(details["cooldown"])
	return "\n".join(lines)


## A multiplier or duration without trailing zeros: 2.0 -> "2", 1.45 -> "1.45".
static func number(value: float) -> String:
	return ("%.2f" % value).rstrip("0").rstrip(".")


static func _class_name(vocation: Variant) -> String:
	return Balance.profile_of(String(vocation))["name"]
