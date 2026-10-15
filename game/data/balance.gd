extends RefCounted
## Brimholt balance curves. Everything is anchored on the final boss: 700,000 health, built so
## that at least twenty level-50 players with every vocation are needed (enrage timer, healing
## pressure, and tank swaps). Combat and mobs are not implemented yet; these curves are the
## design targets for mobs, items, vocations, and levelling.
## Print the full table with: godot --headless --path . --script res://tools/generators/balance_table.gd

const MAX_LEVEL: int = 50
const FINAL_BOSS_HEALTH: int = 700000
## Tibia-style auto-attack interval for players and monsters.
const ATTACK_SECONDS: float = 2.0
## Hits a damage-1.0 player with level-appropriate gear needs to defeat a normal mob of its level.
const GEARED_HITS_PER_KILL: float = 6.0
## Hits an ungeared damage-1.0 player needs; gear is expected to supply the difference.
const BASE_HITS_PER_KILL: float = 8.0
## Same-level normal mob hits an ungeared paladin survives (from level 11; more before that).
const HITS_TO_FALL: float = 18.0
## PvP: players hit players PVP_DAMAGE times harder (player health is built to survive many
## monster hits). For PVP_COMBAT_SECONDS after any hit between players, both heal at PVP_HEALING
## strength (spells, potions, and regeneration), fading to nothing over PVP_DAMPENING_SECONDS of
## continuous PvP combat, so even two healers cannot stall forever.
const PVP_DAMAGE: float = 1.5
const PVP_HEALING: float = 0.35
const PVP_COMBAT_SECONDS: float = 10.0
const PVP_DAMPENING_SECONDS: float = 90.0
## Seconds per tile a chasing monster takes: CHASE_SECONDS_EVEN against a target of its level or
## higher (a touch quicker than a player's World.MOVE_SECONDS, 0.18), down to CHASE_SECONDS_FAST
## once it outlevels the target by CHASE_GAP_LEVELS or more. Nobody outruns a monster far above
## them; a fair fight is not a sprint.
const CHASE_SECONDS_EVEN: float = 0.17
const CHASE_SECONDS_FAST: float = 0.13
const CHASE_GAP_LEVELS: float = 10.0
const EARLY_DAMAGE_LEVELS: float = 10.0
const MOB_HEALTH_LEVEL_1: float = 30.0
const PLAYER_HEALTH_LEVEL_1: float = 150.0
const PLAYER_MANA_LEVEL_1: float = 60.0
const BASE_CRITICAL: int = 5
## Base health regenerated every 10 seconds, as a fraction of max health (tripled when resting).
const REGEN_FRACTION: float = 0.04
## Health a full healer (healing 1.0) restores per second, as a fraction of paladin health.
const HEAL_FRACTION: float = 0.04
## Class multipliers on the reference (Hunter, id "paladin") curves, plus flat base defense. Players see
## "class" and these names; the ids (knight = Warrior, paladin = Hunter) stay for saves and data.
const VOCATIONS: Dictionary = {
	"knight": {"name": "Warrior", "role": "Tank", "health": 1.5, "mana": 0.5, "damage": 0.6,
		"healing": 0.0, "defense": 20},
	"paladin": {"name": "Hunter", "role": "Ranged damage, light healing", "health": 1.0, "mana": 1.0,
		"damage": 1.0, "healing": 0.1, "defense": 5},
	"sorcerer": {"name": "Sorcerer", "role": "Burst damage", "health": 0.6, "mana": 1.6, "damage": 1.3,
		"healing": 0.0, "defense": 0},
	"druid": {"name": "Druid", "role": "Healer", "health": 0.6, "mana": 1.6, "damage": 0.4,
		"healing": 1.0, "defense": 0},
}
const DEFAULT_VOCATION: String = "paladin"
## The helmet and armor type each class wears (and only that type): Warriors plate, Hunters
## mail, Druids leather, Sorcerers cloth. Items without an "armor" type (relics) fit everyone.
const ARMOR_OF: Dictionary = {"knight": "plate", "paladin": "mail", "druid": "leather", "sorcerer": "cloth"}
## New characters start as Adventurers: no vocation yet. They pass the trial (Quests.TRIAL_TASK)
## and, from CHOOSE_LEVEL, pick a vocation at its trainer in Cinder Crossing, for good. Until
## then they stop at ADVENTURER_MAX_LEVEL, may use every vocation's tier-1 gear, and only know
## spells every vocation shares.
const ADVENTURER: String = "adventurer"
const ADVENTURER_PROFILE: Dictionary = {"name": "Adventurer",
	"role": "No class yet: pass the trial, then choose one at a trainer in Cinder Crossing", "health": 1.0,
	"mana": 0.8, "damage": 0.8, "healing": 0.0, "defense": 5}
const CHOOSE_LEVEL: int = 5
const ADVENTURER_MAX_LEVEL: int = 8
## The smallest intended final-boss raid. Removing any one player makes the fight unwinnable.
## Boss health and RAID grow together (reference_dps divides one by the other), so a bigger raid
## leaves every monster and item curve unchanged.
const RAID: Dictionary = {"knight": 4, "paladin": 6, "sorcerer": 6, "druid": 4}
const RAID_FIGHT_SECONDS: float = 240.0
## The boss enrages and wipes the raid after this, leaving about 2% slack over the intended fight:
## less than the damage of any one raid member (a Druid is about 2.2% of it).
const ENRAGE_SECONDS: float = 245.0
## Raid-wide boss damage per second, in full-healer units at the same level.
const BOSS_HEALING_PRESSURE: float = 4.4
## Boss hits stack a wound on their target, so tanks must swap: two pairs of Warriors.
const MIN_TANKS: int = 4
const RANKS: Dictionary = {
	"normal": {"health": 1.0, "damage": 1.0, "experience": 1.0},
	"elite": {"health": 4.0, "damage": 1.5, "experience": 5.0},
	"champion": {"health": 10.0, "damage": 1.8, "experience": 25.0},
	"boss": {"health": 0.0, "damage": 2.5, "experience": 100.0},
}
const STATS: Array[String] = ["health", "mana", "attack", "defense", "critical", "regen", "healing"]


static func raid_damage(composition: Dictionary) -> float:
	var total: float = 0.0
	for vocation: String in composition:
		total += composition[vocation] * VOCATIONS[vocation]["damage"]
	return total


## Damage per second of a geared damage-1.0 player at max level: the intended raid's
## combined damage must defeat the boss in RAID_FIGHT_SECONDS.
static func reference_dps() -> float:
	return FINAL_BOSS_HEALTH / (raid_damage(RAID) * RAID_FIGHT_SECONDS)


## Normal max-level mob health: GEARED_HITS_PER_KILL hits from a geared damage-1.0 player.
static func max_level_mob_health() -> float:
	return reference_dps() * ATTACK_SECONDS * GEARED_HITS_PER_KILL


static func growth() -> float:
	return pow(max_level_mob_health() / MOB_HEALTH_LEVEL_1, 1.0 / (MAX_LEVEL - 1))


static func boss_ratio() -> float:
	return FINAL_BOSS_HEALTH / max_level_mob_health()


static func _scale(level: int) -> float:
	return pow(growth(), clampi(level, 1, MAX_LEVEL) - 1)


static func mob_health(level: int, rank: String = "normal") -> int:
	var multiplier: float = boss_ratio() if rank == "boss" else RANKS[rank]["health"]
	return roundi(MOB_HEALTH_LEVEL_1 * _scale(level) * multiplier)


## Early monsters hit softer: half damage at level 1, full damage from EARLY_DAMAGE_LEVELS + 1.
static func early_damage(level: int) -> float:
	return clampf(0.5 + 0.5 * (clampi(level, 1, MAX_LEVEL) - 1) / EARLY_DAMAGE_LEVELS, 0.5, 1.0)


static func mob_damage(level: int, rank: String = "normal") -> int:
	return maxi(1, roundi(PLAYER_HEALTH_LEVEL_1 * _scale(level) / HITS_TO_FALL * RANKS[rank]["damage"] * early_damage(level)))


## A monster's step time while chasing a target of `target_level` (its own, slower pace is for
## idling and going home).
static func chase_seconds(monster_level: int, target_level: int) -> float:
	var gap: float = clampf((monster_level - target_level) / CHASE_GAP_LEVELS, 0.0, 1.0)
	return lerpf(CHASE_SECONDS_EVEN, CHASE_SECONDS_FAST, gap)


static func mob_experience(level: int, rank: String = "normal") -> int:
	return roundi(MOB_HEALTH_LEVEL_1 * _scale(level) / 2.0 * RANKS[rank]["experience"])


## Same-level normal kills per level: quick early levels (4 for level 2), longer later.
static func kills_to_level(level: int) -> int:
	return 4 + 3 * (clampi(level, 1, MAX_LEVEL) - 1)


static func experience_to_next(level: int) -> int:
	if level >= MAX_LEVEL:
		return 0
	return kills_to_level(level) * mob_experience(level)


static func player_health(level: int) -> int:
	return roundi(PLAYER_HEALTH_LEVEL_1 * _scale(level))


static func base_attack(level: int) -> int:
	return maxi(1, roundi(MOB_HEALTH_LEVEL_1 * _scale(level) / BASE_HITS_PER_KILL))


static func geared_attack(level: int) -> int:
	return roundi(MOB_HEALTH_LEVEL_1 * _scale(level) / GEARED_HITS_PER_KILL)


## Attack that a full set of level-appropriate gear should add on top of base attack.
static func gear_attack_budget(level: int) -> int:
	return geared_attack(level) - base_attack(level)


## Unrounded gear_attack_budget, for item tiers whose budgets are only a few points.
static func gear_attack_budget_exact(level: int) -> float:
	return MOB_HEALTH_LEVEL_1 * _scale(level) * (1.0 / GEARED_HITS_PER_KILL - 1.0 / BASE_HITS_PER_KILL)


## Defense reduces incoming damage hyperbolically: 100 defense halves it.
static func damage_taken(raw: int, defense: int) -> int:
	return roundi(raw * 100.0 / (100.0 + maxi(defense, 0)))


## A vocation's (or the Adventurer's) multipliers, name, and role; unknown ids get the default.
static func profile_of(vocation: String) -> Dictionary:
	if vocation == ADVENTURER:
		return ADVENTURER_PROFILE
	return VOCATIONS.get(vocation, VOCATIONS[DEFAULT_VOCATION])


## A vocation a character may have: one of VOCATIONS, or the starting Adventurer.
static func is_vocation(vocation: Variant) -> bool:
	return typeof(vocation) == TYPE_STRING and (VOCATIONS.has(vocation) or vocation == ADVENTURER)


static func base_stats(level: int, vocation: String = DEFAULT_VOCATION) -> Dictionary:
	var profile: Dictionary = profile_of(vocation)
	var health: int = roundi(player_health(level) * profile["health"])
	return {
		"health": health,
		"mana": roundi(PLAYER_MANA_LEVEL_1 * _scale(level) * profile["mana"]),
		"attack": maxi(1, roundi(MOB_HEALTH_LEVEL_1 * _scale(level) / BASE_HITS_PER_KILL * profile["damage"])),
		"defense": profile["defense"], "critical": BASE_CRITICAL,
		"regen": maxi(1, roundi(health * REGEN_FRACTION)),
		"healing": roundi(player_health(level) * HEAL_FRACTION * profile["healing"]),
	}


## Whether a group of max-level, level-appropriately geared players can defeat the final boss.
## composition maps vocation to player count.
static func raid_check(composition: Dictionary) -> Dictionary:
	var players: int = 0
	var healing: float = 0.0
	var tanks: int = 0
	for vocation: String in composition:
		players += composition[vocation]
		healing += composition[vocation] * VOCATIONS[vocation]["healing"]
		if VOCATIONS[vocation]["role"] == "Tank":
			tanks += composition[vocation]
	var damage: float = raid_damage(composition) * reference_dps()
	var seconds: float = INF if damage <= 0.0 else FINAL_BOSS_HEALTH / damage
	var reasons: PackedStringArray = []
	if seconds > ENRAGE_SECONDS:
		reasons.append("not enough damage before the %d s enrage" % roundi(ENRAGE_SECONDS))
	if healing < BOSS_HEALING_PRESSURE - 0.0001:
		reasons.append("not enough healing")
	if tanks < MIN_TANKS:
		reasons.append("needs %d tanks to swap" % MIN_TANKS)
	return {"ok": reasons.is_empty(), "players": players, "seconds": seconds, "healing": healing,
		"tanks": tanks, "reasons": reasons}


static func signature() -> String:
	return str([MAX_LEVEL, FINAL_BOSS_HEALTH, ATTACK_SECONDS, GEARED_HITS_PER_KILL, BASE_HITS_PER_KILL,
		HITS_TO_FALL, MOB_HEALTH_LEVEL_1, PLAYER_HEALTH_LEVEL_1, PLAYER_MANA_LEVEL_1, BASE_CRITICAL,
		REGEN_FRACTION, HEAL_FRACTION, EARLY_DAMAGE_LEVELS, VOCATIONS, RAID, RAID_FIGHT_SECONDS, ENRAGE_SECONDS,
		BOSS_HEALING_PRESSURE, MIN_TANKS, RANKS, CHASE_SECONDS_EVEN, CHASE_SECONDS_FAST, CHASE_GAP_LEVELS,
		PVP_DAMAGE, PVP_HEALING, PVP_COMBAT_SECONDS, PVP_DAMPENING_SECONDS])
