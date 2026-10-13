extends RefCounted
## Original spells, cast from the action bar. Mana costs are a fraction of the caster's max
## mana; damage multiplies the caster's attack; heals restore a fraction of the healed
## player's max health ("heal_self") or the caster's healing stat times power ("heal_area").
## Like Tibia, every spell has its own cooldown and also starts its group's shared cooldown.
## "taunt" (Challenge) turns nearby monsters, bosses included, onto the caster: the tank swap.

const Balance = preload("res://game/data/balance.gd")
const GROUP_SECONDS: Dictionary = {"attack": 2.0, "healing": 1.0}
const SPELLS: Dictionary = {
	"light_heal": {"name": "Light heal", "vocations": ["knight", "paladin", "sorcerer", "druid"], "level": 1,
		"kind": "heal_self", "power": 0.15, "mana": 0.15, "cooldown": 2.0, "group": "healing", "color": Color("#7fe08a")},
	"brutal_blow": {"name": "Brutal blow", "vocations": ["knight"], "level": 1, "kind": "target", "range": 1,
		"power": 2.0, "mana": 0.15, "cooldown": 4.0, "group": "attack", "color": Color("#e0b060")},
	"whirling_strike": {"name": "Whirling strike", "vocations": ["knight"], "level": 10, "kind": "area_self",
		"radius": 1, "power": 1.4, "mana": 0.25, "cooldown": 6.0, "group": "attack", "color": Color("#e0d0a0")},
	"challenge": {"name": "Challenge", "vocations": ["knight"], "level": 20, "kind": "taunt", "radius": 2,
		"power": 0.0, "mana": 0.1, "cooldown": 4.0, "group": "attack", "color": Color("#f0c060")},
	"piercing_shot": {"name": "Piercing shot", "vocations": ["paladin"], "level": 1, "kind": "target", "range": 6,
		"power": 1.8, "mana": 0.1, "cooldown": 4.0, "group": "attack", "color": Color("#f0e6b0")},
	"holy_mend": {"name": "Holy mend", "vocations": ["paladin"], "level": 8, "kind": "heal_self", "power": 0.3,
		"mana": 0.15, "cooldown": 3.0, "group": "healing", "color": Color("#f6e38a")},
	"ember_bolt": {"name": "Ember bolt", "vocations": ["sorcerer"], "level": 1, "kind": "target", "range": 5,
		"power": 2.2, "mana": 0.08, "cooldown": 2.0, "group": "attack", "color": Color("#ff8a4a")},
	"flame_wave": {"name": "Flame wave", "vocations": ["sorcerer"], "level": 10, "kind": "area_target", "range": 5,
		"radius": 1, "power": 1.5, "mana": 0.2, "cooldown": 6.0, "group": "attack", "color": Color("#ff6a30")},
	"frost_bolt": {"name": "Frost bolt", "vocations": ["druid"], "level": 1, "kind": "target", "range": 5,
		"power": 1.6, "mana": 0.06, "cooldown": 2.0, "group": "attack", "color": Color("#8ad0ff")},
	"mend": {"name": "Mend", "vocations": ["druid"], "level": 1, "kind": "heal_self", "power": 0.35, "mana": 0.1,
		"cooldown": 1.0, "group": "healing", "color": Color("#7fe08a")},
	# Higher-level spells: each vocation unlocks a stronger strike around level 15-20, another at 30,
	# and a signature spell at 40-45, so damage (or a druid's group healing) keeps growing with level.
	"rending_cut": {"name": "Rending cut", "vocations": ["knight"], "level": 20, "kind": "target", "range": 1,
		"power": 2.8, "mana": 0.15, "cooldown": 6.0, "group": "attack", "color": Color("#d89a5a")},
	"sundering_blow": {"name": "Sundering blow", "vocations": ["knight"], "level": 30, "kind": "target", "range": 1,
		"power": 3.8, "mana": 0.2, "cooldown": 10.0, "group": "attack", "color": Color("#c8703a")},
	"earthshaker": {"name": "Earthshaker", "vocations": ["knight"], "level": 40, "kind": "area_self", "radius": 2,
		"power": 2.0, "mana": 0.3, "cooldown": 14.0, "group": "attack", "color": Color("#b89a6a")},
	"arrow_volley": {"name": "Arrow volley", "vocations": ["paladin"], "level": 15, "kind": "area_target", "range": 6,
		"radius": 1, "power": 1.6, "mana": 0.15, "cooldown": 8.0, "group": "attack", "color": Color("#e8d8a0")},
	"radiant_arrow": {"name": "Radiant arrow", "vocations": ["paladin"], "level": 30, "kind": "target", "range": 6,
		"power": 3.2, "mana": 0.15, "cooldown": 8.0, "group": "attack", "color": Color("#fff0a0")},
	"sunlance_barrage": {"name": "Sunlance barrage", "vocations": ["paladin"], "level": 40, "kind": "area_target", "range": 6,
		"radius": 2, "power": 1.9, "mana": 0.3, "cooldown": 14.0, "group": "attack", "color": Color("#ffe070")},
	"arc_lightning": {"name": "Arc lightning", "vocations": ["sorcerer"], "level": 20, "kind": "target", "range": 5,
		"power": 3.2, "mana": 0.12, "cooldown": 6.0, "group": "attack", "color": Color("#a0c8ff")},
	"firestorm": {"name": "Firestorm", "vocations": ["sorcerer"], "level": 30, "kind": "area_target", "range": 5,
		"radius": 2, "power": 1.8, "mana": 0.25, "cooldown": 10.0, "group": "attack", "color": Color("#ff5a20")},
	"starfall": {"name": "Starfall", "vocations": ["sorcerer"], "level": 45, "kind": "area_target", "range": 5,
		"radius": 2, "power": 2.6, "mana": 0.35, "cooldown": 16.0, "group": "attack", "color": Color("#d8b0ff")},
	"thorn_lash": {"name": "Thorn lash", "vocations": ["druid"], "level": 15, "kind": "target", "range": 5,
		"power": 2.4, "mana": 0.1, "cooldown": 6.0, "group": "attack", "color": Color("#7ac85a")},
	"hailstorm": {"name": "Hailstorm", "vocations": ["druid"], "level": 30, "kind": "area_target", "range": 5,
		"radius": 2, "power": 1.5, "mana": 0.22, "cooldown": 10.0, "group": "attack", "color": Color("#c8e8ff")},
	"wild_growth": {"name": "Wild growth", "vocations": ["druid"], "level": 40, "kind": "heal_area", "radius": 3,
		"power": 5.0, "mana": 0.3, "cooldown": 8.0, "group": "healing", "color": Color("#60e070")},
	"mass_mend": {"name": "Mass mend", "vocations": ["druid"], "level": 10, "kind": "heal_area", "radius": 3,
		"power": 3.0, "mana": 0.2, "cooldown": 2.0, "group": "healing", "color": Color("#a6f0b0")},
}


## A vocation's spells by unlock level (catalog order within a level): the action bar's order.
static func for_vocation(vocation: String) -> Array[String]:
	var result: Array[String] = []
	var order: Dictionary = {}
	for id: String in SPELLS:
		if vocation in SPELLS[id]["vocations"]:
			order[id] = SPELLS[id]["level"] * 1000 + result.size()
			result.append(id)
	result.sort_custom(func(a: String, b: String) -> bool: return order[a] < order[b])
	return result


## What a spell does, for its tooltip and the spell book, from the same numbers Combat.cast uses.
## `stats` are the caster's World.stats (empty: no estimates); `level` gates "unlocked".
## Returns name, requirement, effect, amount ("" for none), cost, cooldown, and unlocked.
static func info(id: String, stats: Dictionary, level: int) -> Dictionary:
	var spell: Dictionary = SPELLS[id]
	var power: float = spell["power"]
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
				else "your target up to %d tiles away" % reach, _times(power)]
			amount = hit
		"area_self":
			effect = "Hits every enemy within %s of you for %s× your attack." % [area, _times(power)]
			amount = hit + " each"
		"area_target":
			effect = "Hits your target (up to %d tiles away) and every enemy within %s of it for %s× your attack." % [
				reach, area, _times(power)]
			amount = hit + " each"
		"taunt":
			effect = "Turns every monster within %s of you, bosses included, onto you: take a boss off a wounded ally." % area
		"heal_self":
			effect = "Heals you for %d%% of your max health." % roundi(power * 100.0)
			amount = "Heals about %d" % roundi(float(stats.get("health", 0)) * power)
		"heal_area":
			effect = "Heals every player within %s of you, you included, for %s× your healing." % [area, _times(power)]
			amount = "Heals %d each" % maxi(1, roundi(float(stats.get("healing", 0)) * power))
	if stats.is_empty():
		amount = ""
	var cost: String = "Mana %d%%" % roundi(spell["mana"] * 100.0)
	if stats.has("mana"):
		cost = "Mana %d (%d%% of your max)" % [maxi(1, roundi(float(stats["mana"]) * spell["mana"])), roundi(spell["mana"] * 100.0)]
	var vocations: Array = spell["vocations"]
	var who: String = "Every vocation" if vocations.size() == Balance.VOCATIONS.size() \
		else ", ".join(vocations.map(_capitalized))
	return {
		"name": spell["name"], "unlocked": level >= spell["level"],
		"requirement": "%s · level %d" % [who, spell["level"]] if level >= spell["level"]
			else "✗ Needs level %d (%s)" % [spell["level"], who],
		"effect": effect, "amount": amount, "cost": cost,
		"cooldown": "Cooldown %s s, and %s s for all %s spells" % [_times(spell["cooldown"]),
			_times(GROUP_SECONDS[spell["group"]]), spell["group"]],
	}


## The tooltip text: name, requirement, effect, then the numbers.
static func describe(id: String, stats: Dictionary, level: int) -> String:
	var details: Dictionary = info(id, stats, level)
	var lines: PackedStringArray = [details["name"], details["requirement"], details["effect"]]
	if not details["amount"].is_empty():
		lines.append(details["amount"])
	lines.append(details["cost"])
	lines.append(details["cooldown"])
	return "\n".join(lines)


static func _times(value: float) -> String:
	return String.num(value, 2)


static func _capitalized(text: Variant) -> String:
	return String(text).capitalize()
