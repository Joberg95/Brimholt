extends RefCounted
## Original spells, cast from the action bar. Mana costs are a fraction of the caster's max
## mana; damage multiplies the caster's attack; heals restore a fraction of the healed
## player's max health ("heal_self") or the caster's healing stat times power ("heal_area").
## Like Tibia, every spell has its own cooldown and also starts its group's shared cooldown.
## "taunt" (Challenge) turns nearby monsters, bosses included, onto the caster: the tank swap.

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
		"power": 1.6, "mana": 0.08, "cooldown": 2.0, "group": "attack", "color": Color("#8ad0ff")},
	"mend": {"name": "Mend", "vocations": ["druid"], "level": 1, "kind": "heal_self", "power": 0.35, "mana": 0.1,
		"cooldown": 1.0, "group": "healing", "color": Color("#7fe08a")},
	"mass_mend": {"name": "Mass mend", "vocations": ["druid"], "level": 10, "kind": "heal_area", "radius": 3,
		"power": 3.0, "mana": 0.2, "cooldown": 2.0, "group": "healing", "color": Color("#a6f0b0")},
}


static func for_vocation(vocation: String) -> Array[String]:
	var result: Array[String] = []
	for id: String in SPELLS:
		if vocation in SPELLS[id]["vocations"]:
			result.append(id)
	return result
