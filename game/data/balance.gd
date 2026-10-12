extends RefCounted
## Brimholt balance curves. Everything is anchored on the final boss: 350,000 health, built so
## that at least ten level-50 players with every vocation are needed (enrage timer, healing
## pressure, and tank swaps). Combat and mobs are not implemented yet; these curves are the
## design targets for mobs, items, vocations, and levelling.
## Print the full table with: godot --headless --path . --script res://tools/generators/balance_table.gd

const MAX_LEVEL: int = 50
const FINAL_BOSS_HEALTH: int = 350000
## Tibia-style auto-attack interval for players and monsters.
const ATTACK_SECONDS: float = 2.0
## Hits a damage-1.0 player with level-appropriate gear needs to defeat a normal mob of its level.
const GEARED_HITS_PER_KILL: float = 6.0
## Hits an ungeared damage-1.0 player needs; gear is expected to supply the difference.
const BASE_HITS_PER_KILL: float = 8.0
## Same-level normal mob hits an ungeared paladin survives (from level 11; more before that).
const HITS_TO_FALL: float = 15.0
const EARLY_DAMAGE_LEVELS: float = 10.0
const MOB_HEALTH_LEVEL_1: float = 30.0
const PLAYER_HEALTH_LEVEL_1: float = 150.0
const PLAYER_MANA_LEVEL_1: float = 60.0
const BASE_CRITICAL: int = 5
## Base health regenerated every 10 seconds, as a fraction of max health (tripled when resting).
const REGEN_FRACTION: float = 0.04
## Health a full healer (healing 1.0) restores per second, as a fraction of paladin health.
const HEAL_FRACTION: float = 0.04
## Vocation multipliers on the reference (paladin) curves, plus flat base defense.
const VOCATIONS: Dictionary = {
	"knight": {"name": "Knight", "role": "Tank", "health": 1.5, "mana": 0.5, "damage": 0.6,
		"healing": 0.0, "defense": 20},
	"paladin": {"name": "Paladin", "role": "Ranged damage, light healing", "health": 1.0, "mana": 1.0,
		"damage": 1.0, "healing": 0.1, "defense": 5},
	"sorcerer": {"name": "Sorcerer", "role": "Burst damage", "health": 0.6, "mana": 1.6, "damage": 1.3,
		"healing": 0.0, "defense": 0},
	"druid": {"name": "Druid", "role": "Healer", "health": 0.6, "mana": 1.6, "damage": 0.4,
		"healing": 1.0, "defense": 0},
}
const DEFAULT_VOCATION: String = "paladin"
## The smallest intended final-boss raid. Removing any one player makes the fight unwinnable.
const RAID: Dictionary = {"knight": 2, "paladin": 3, "sorcerer": 3, "druid": 2}
const RAID_FIGHT_SECONDS: float = 240.0
## The boss enrages and wipes the raid after this, leaving about 6% slack over the intended fight.
const ENRAGE_SECONDS: float = 255.0
## Raid-wide boss damage per second, in full-healer units at the same level.
const BOSS_HEALING_PRESSURE: float = 2.2
## Boss hits stack a wound on their target, so tanks must swap.
const MIN_TANKS: int = 2
const RANKS: Dictionary = {
	"normal": {"health": 1.0, "damage": 1.0, "experience": 1.0},
	"elite": {"health": 4.0, "damage": 1.5, "experience": 5.0},
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


## Defense reduces incoming damage hyperbolically: 100 defense halves it.
static func damage_taken(raw: int, defense: int) -> int:
	return roundi(raw * 100.0 / (100.0 + maxi(defense, 0)))


static func base_stats(level: int, vocation: String = DEFAULT_VOCATION) -> Dictionary:
	var profile: Dictionary = VOCATIONS.get(vocation, VOCATIONS[DEFAULT_VOCATION])
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
		BOSS_HEALING_PRESSURE, MIN_TANKS, RANKS])
