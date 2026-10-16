extends RefCounted
## Server-authoritative, Tibia-style combat. Players lock a target and auto-attack every
## Balance.ATTACK_SECONDS while in range (melee: the 8 surrounding tiles; ranged: clear line
## of sight past walls and trees). Spells cost mana and use their own and their group's
## cooldown. Monsters idle until a player comes near, chase within a leash, and respawn.
## Experience is split by damage dealt (pooled within a sharing party); dying costs DEATH_PENALTY of
## total experience.
## tick() and the request functions return events for game/main.gd to replicate:
##   {kind: "player"|"monster"|"monster_gone", id}, {kind: "hit", target, amount, style, source (the attacker, for damage)},
##   {kind: "missile", from, to, color}, {kind: "area", cells, color}, {kind: "ground", cells},
##   {kind: "message", id, text}.

const World = preload("res://game/core/world.gd")
const Balance = preload("res://game/data/balance.gd")
const Monsters = preload("res://game/data/monsters.gd")
const Spells = preload("res://game/data/spells.gd")
const Items = preload("res://game/data/items.gd")
const Quests = preload("res://game/data/quests.gd")

const TICK_SECONDS: float = 0.1
const REGEN_SECONDS: float = 2.0
## Mana restored per 10 seconds, as a fraction of max mana.
const MANA_REGEN_FRACTION: float = 0.08
## Out of combat for this long, health and mana regenerate RESTING_MULTIPLIER times faster.
const RESTING_SECONDS: float = 8.0
const RESTING_MULTIPLIER: float = 3.0
## Town rest: in a town and missing health or mana, you regenerate TOWN_REST_MULTIPLIER times the
## base rate (about 25 s from empty to full) until you are full or leave; then it needs
## TOWN_REST_COOLDOWN before it starts again, so towns are not a free mid-fight heal.
const TOWN_REST_MULTIPLIER: float = 10.0
const TOWN_REST_COOLDOWN: float = 180.0
## A spawn that finds no free tile (or a player standing on its camp) tries again this much later.
const SPAWN_RETRY_SECONDS: float = 5.0
## Below this level, dying never drops items or gold, so new players cannot be stranded.
const PROTECTION_LEVEL: int = 8
## Players can lock targets within this many tiles.
const TARGET_RANGE: int = 8
const DEATH_PENALTY: float = 0.1
## Tibia-style loss: the backpack and purse are always lost, each worn item has this chance,
## and a red skull loses everything. Lost items land on the death tile and spill nearby.
const EQUIPMENT_LOSS_CHANCE: float = 0.1
const SPILL_RADIUS: int = 3
## Skulls: attacking an unmarked player gives a white skull; three unjustified kills within a
## day give a red skull. Attacking a skulled player, or someone who attacked you, is self-defence.
const WHITE_SKULL_SECONDS: float = 900.0
const RED_SKULL_SECONDS: float = 30.0 * 86400.0
const AGGRESSION_SECONDS: float = 900.0
const UNJUSTIFIED_WINDOW_SECONDS: float = 86400.0
const RED_SKULL_KILLS: int = 3
const CRITICAL_MULTIPLIER: float = 1.5
## A boss's trophies go only to fighters alive and this close to it when it falls (_award_trophies).
const TROPHY_RADIUS: int = 15
## After a root or slow on a player ends, that player cannot be held again for this long.
const RESTRAIN_IMMUNITY: float = 6.0
const VOCATION_RANGE: Dictionary = {"knight": 1, "paladin": 6, "sorcerer": 5, "druid": 5}
const MISSILE_COLORS: Dictionary = {"paladin": Color("#e8dcb0"), "sorcerer": Color("#ff9a5a"),
	"druid": Color("#9ad8ff"), "monster": Color("#c8e070")}
## Parties (Tibia-style shared experience): members within SHARE_RANGE of a kill who fought,
## healed, or were hit within SHARE_ACTIVE_SECONDS split the party's experience evenly when the
## lowest level is at least SHARE_LEVEL_RATIO of the highest. More vocations earn a bonus.
const SHARE_RANGE: int = 20
const SHARE_ACTIVE_SECONDS: float = 120.0
const SHARE_LEVEL_RATIO: float = 2.0 / 3.0
const SHARE_BONUS: Array[float] = [1.0, 1.2, 1.3, 1.6, 2.0]
## Final-boss raid mechanics (Balance: ENRAGE_SECONDS, BOSS_HEALING_PRESSURE, MIN_TANKS).
## Every PULSE_SECONDS the boss damages every player within PULSE_RADIUS, a raid-wide total of
## BOSS_HEALING_PRESSURE full healers' healing per second for the intended raid. Each boss hit
## adds a wound to its target: +WOUND_STEP damage from the boss per stack, cleared after
## WOUND_SECONDS without a new hit, so two Knights must swap with Challenge. After
## ENRAGE_SECONDS of fighting the boss deals ENRAGE_MULTIPLIER times damage. Leaving it resets.
const PULSE_SECONDS: float = 4.0
const PULSE_RADIUS: int = 8
const WOUND_STEP: float = 0.25
const WOUND_SECONDS: float = 12.0
const ENRAGE_MULTIPLIER: float = 10.0
## Chance per kill of one equipment piece from the monster's tier (Combat.gear_drop).
## Bosses drop relics from their loot table instead.
const GEAR_DROP_CHANCE: Dictionary = {"normal": 0.04, "elite": 0.25, "champion": 1.0, "boss": 0.0}
const GEAR_LOWER_TIER_CHANCE: float = 0.3
const PARTY_ACTIONS: Array[String] = ["invite", "revoke", "join", "leave"]
## What an Adventurer hears from every giver but the trial master, and at a dungeon stairway.
const CHOOSE_CLASS_FIRST: String = "Choose your class first: pass the adventurer's trial, then see a trainer in Cinder Crossing's training hall"
const STEPS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var world: World
var rng := RandomNumberGenerator.new()
## [due time, spawn index] for monsters waiting to respawn.
var respawns: Array = []
## Who earned the loot on a ground cell: cell -> {"owners": {player id: true}, "until": time},
## set for every tile a kill's loot spilled onto (the players credited with the kill). Anyone may
## still pick it up; bots use it to collect only what their own group earned (game/core/bot_loot.gd).
## Claims lapse after LOOT_CLAIM_SECONDS and are swept every LOOT_SWEEP_SECONDS.
var loot_claims: Dictionary = {}
const LOOT_CLAIM_SECONDS: float = 180.0
const LOOT_SWEEP_SECONDS: float = 10.0
var _next_claim_sweep: float = 0.0
var _next_id: int = -1
var _last_tick: float = -INF
## Monsters by the SLEEP_CHUNK of their home (chunk -> {id: true}) and the active ones (chasing,
## away from home, or in a fight). A tick visits only the monsters homed near a player plus the
## active set, so its cost does not grow with camps far from everyone. Rebuilt if world.monsters
## changes behind Combat's back (tests add and remove monsters directly).
var _by_home: Dictionary = {}
var _indexed: int = 0
var _active: Dictionary = {}
## Camps not spawned yet (populate's lazy mode): marker chunk -> [spawn indices]. A camp spawns the
## first time a player or bot comes within WAKE_REACH chunks of it, and stays.
var _dormant: Dictionary = {}
## Occupied tiles (cell -> number of creatures on or reserving it) for one moment, built once and
## kept current as monsters step, instead of scanning every creature for each step.
var _taken: Dictionary = {}
var _taken_at: float = NAN


func _init(owner: World, seed_value: int = 0) -> void:
	world = owner
	rng.seed = seed_value if seed_value != 0 else Time.get_ticks_usec()


# ---------------------------------------------------------------- geometry

static func distance(a: Vector2i, b: Vector2i) -> int:
	return World.chebyshev(a, b)


## Walls, trees, and void block projectiles and spells; water and creatures do not.
static func line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	var steps: int = maxi(absi(to.x - from.x), absi(to.y - from.y))
	for step: int in range(1, steps):
		var cell := Vector2i(Vector2(from).lerp(Vector2(to), float(step) / steps).round())
		var tile: String = World.terrain(cell)
		if tile.is_empty() or tile == " " or tile in World.WALLS or tile in World.TREES:
			return false
	return true


static func in_reach(from: Vector2i, to: Vector2i, reach: int) -> bool:
	return distance(from, to) <= reach and (reach <= 1 or line_of_sight(from, to))


## The cardinal step from a cell that best approaches goal, or ZERO. blocked(cell) -> bool.
static func step_toward(from: Vector2i, goal: Vector2i, blocked: Callable) -> Vector2i:
	var best := Vector2i.ZERO
	var best_score: int = distance(from, goal) * 100 + absi(goal.x - from.x) + absi(goal.y - from.y)
	for step: Vector2i in STEPS:
		var next: Vector2i = from + step
		if not World.walkable(next) or blocked.call(next):
			continue
		var score: int = distance(next, goal) * 100 + absi(goal.x - next.x) + absi(goal.y - next.y)
		if score < best_score:
			best = step
			best_score = score
	return best


## The first step of a shortest path toward goal around walls, trees, and blocked tiles,
## searching at most limit tiles; falls back to step_toward when no path is found. The goal
## itself may be occupied (it is usually the creature being chased).
static func path_step(from: Vector2i, goal: Vector2i, blocked: Callable, limit: int = 900) -> Vector2i:
	if from == goal:
		return Vector2i.ZERO
	var previous: Dictionary = {from: from}
	var queue: Array[Vector2i] = [from]
	var head: int = 0
	while head < queue.size() and queue.size() < limit:
		var cell: Vector2i = queue[head]
		head += 1
		for step: Vector2i in STEPS:
			var next: Vector2i = cell + step
			if previous.has(next):
				continue
			if next == goal:
				var back: Vector2i = cell
				while previous[back] != from:
					back = previous[back]
				return (next if cell == from else back) - from
			if not World.walkable(next) or blocked.call(next):
				continue
			previous[next] = cell
			queue.append(next)
	return step_toward(from, goal, blocked)


static func facing_toward(from: Vector2i, to: Vector2i) -> Vector2i:
	var offset: Vector2i = to - from
	if offset == Vector2i.ZERO:
		return Vector2i.DOWN
	if absi(offset.x) > absi(offset.y):
		return Vector2i(signi(offset.x), 0)
	return Vector2i(0, signi(offset.y))


# ---------------------------------------------------------------- creatures

func exists(id: int) -> bool:
	return world.players.has(id) if id > 0 else world.monsters.has(id)


func creature(id: int) -> Dictionary:
	return world.players[id] if id > 0 else world.monsters[id]


func monster_def(id: int) -> Dictionary:
	return Monsters.MONSTERS[world.monsters[id]["kind"]]


func reach_of(id: int) -> int:
	if id > 0:
		return VOCATION_RANGE.get(attack_style(world.players[id]["vocation"], world.players[id]["equipment"]), 1)
	return monster_def(id)["range"]


## The vocation whose auto-attack (reach and missile) a player uses: their own, or for an
## Adventurer the vocation their weapon belongs to (melee when unarmed).
static func attack_style(vocation: String, equipment: Dictionary) -> String:
	if vocation != Balance.ADVENTURER:
		return vocation
	var weapon: Dictionary = World.ITEMS.get(World.kind_of(String(equipment.get("main_hand", ""))), {})
	return weapon["vocations"][0] if not weapon.get("vocations", []).is_empty() else "knight"


func in_pvp_zone(id: int) -> bool:
	return World.zone_at(creature(id)["cell"]).get("pvp", false)


## Players fight monsters anywhere, and each other only when both stand in a PvP zone.
func hostile(attacker: int, target: int) -> bool:
	if attacker == target or not exists(attacker) or not exists(target):
		return false
	if attacker < 0 and target < 0:
		return false
	# The overworld and each dungeon copy are separate spaces, even where they are close on the map.
	if World.dungeon_at(creature(attacker)["cell"]) != World.dungeon_at(creature(target)["cell"]):
		return false
	if attacker > 0 and target > 0:
		if same_party(attacker, target):
			return false
		return in_pvp_zone(attacker) and in_pvp_zone(target)
	return true


func export_monster(id: int, now: float) -> Dictionary:
	var monster: Dictionary = world.monsters[id]
	var remaining: float = maxf(0.0, monster["next_move"] - now)
	return {
		"id": id, "kind": monster["kind"], "level": monster["level"], "cell": monster["cell"],
		"from": monster["from"] if remaining > 0.0 else monster["cell"],
		"remaining": remaining, "duration": monster["last_step"], "facing": monster["facing"],
		"health": monster["health"], "max_health": monster["max_health"], "enraged": monster["enraged"],
	}


func monster_snapshot(now: float) -> Dictionary:
	var result: Dictionary = {}
	for id: int in world.monsters:
		result[id] = export_monster(id, now)
	return result


# ---------------------------------------------------------------- spawning

## Fills every overworld spawn to its count. A monster that finds no free tile now is queued like
## a respawn and retried every SPAWN_RETRY_SECONDS, so every camp reaches its full count.
## Fills the camps: every one now when `everywhere` (tests and tools), else each the first time a
## player or bot comes near it (_wake_camps), so startup and memory do not grow with the map.
func populate(now: float, everywhere: bool = false) -> Array:
	var events: Array = []
	for index: int in World.MONSTER_SPAWNS.size():
		if not everywhere:
			var chunk: Vector2i = World.MONSTER_SPAWNS[index]["cell"] / SLEEP_CHUNK
			if not _dormant.has(chunk):
				_dormant[chunk] = []
			_dormant[chunk].append(index)
			continue
		_fill_camp(index, now, events)
	return events


func _fill_camp(index: int, now: float, events: Array) -> void:
	for count: int in World.MONSTER_SPAWNS[index]["count"]:
		if not _spawn_at_marker(index, now, events):
			respawns.append([now + SPAWN_RETRY_SECONDS, index])


## Spawns the dormant camps within WAKE_REACH chunks of every player and bot, at most
## WAKE_BUDGET camps a tick (nearest players first), so a band walking out spreads the work.
func _wake_camps(now: float, events: Array) -> void:
	if _dormant.is_empty():
		return
	var budget: int = WAKE_BUDGET
	for id: int in world.players:
		var centre: Vector2i = world.players[id]["cell"] / SLEEP_CHUNK
		for dy: int in range(-WAKE_REACH, WAKE_REACH + 1):
			for dx: int in range(-WAKE_REACH, WAKE_REACH + 1):
				var chunk: Vector2i = centre + Vector2i(dx, dy)
				while _dormant.has(chunk) and budget > 0:
					_fill_camp(_dormant[chunk].pop_back(), now, events)
					budget -= 1
					if _dormant[chunk].is_empty():
						_dormant.erase(chunk)
				if budget == 0:
					return


## Camps still waiting for a visitor.
func dormant_camps() -> int:
	var total: int = 0
	for chunk: Vector2i in _dormant:
		total += _dormant[chunk].size()
	return total


func _spawn_at_marker(index: int, now: float, events: Array) -> bool:
	var spawn: Dictionary = World.MONSTER_SPAWNS[index]
	if not Monsters.MONSTERS.has(spawn["monster"]):
		return false
	for attempt: int in 12:
		var offset := Vector2i(rng.randi_range(-spawn["radius"], spawn["radius"]),
			rng.randi_range(-spawn["radius"], spawn["radius"])) if attempt > 0 else Vector2i.ZERO
		var cell: Vector2i = spawn["cell"] + offset
		if World.walkable(cell) and not world.occupied(cell, now):
			spawn_monster(spawn["monster"], spawn["level"], cell, now, index, events)
			return true
	return false


## Removes a monster without a kill (an emptied dungeon copy): no loot, experience, or respawn.
func despawn(id: int, events: Array) -> void:
	if not world.monsters.has(id):
		return
	var cell: Vector2i = world.monsters[id]["cell"]
	_unindex(id)
	world.monsters.erase(id)
	_taken_at = NAN
	events.append({"kind": "monster_gone", "id": id, "cell": cell})
	for player: int in world.players:
		if world.players[player]["target"] == id:
			world.players[player]["target"] = 0
			events.append({"kind": "player", "id": player})


## Creates a monster; spawn -1 means it does not respawn.
func spawn_monster(kind: String, level: int, cell: Vector2i, now: float, spawn: int = -1, events: Array = []) -> int:
	var definition: Dictionary = Monsters.MONSTERS[kind]
	var id: int = _next_id
	_next_id -= 1
	var health: int = Balance.mob_health(level, definition["rank"])
	_taken_at = NAN
	world.monsters[id] = {
		"id": id, "kind": kind, "level": clampi(level, 1, Balance.MAX_LEVEL), "spawn": spawn, "home": cell,
		"cell": cell, "from": cell, "next_move": now, "step": definition["step"], "last_step": definition["step"],
		## Walking home after losing its target: at full health, ignoring players, untouchable.
		"returning": false, "facing": Vector2i.DOWN,
		"health": health, "max_health": health, "target": 0, "next_attack": now, "damage_by": {},
		"engaged_at": -1.0, "next_pulse": INF, "enraged": false, "wounds": {},
		## Players who damaged this monster, were hit by it, or healed someone in the fight.
		"fought": {},
	}
	_index(id)
	events.append({"kind": "monster", "id": id, "movement": false})
	return id


# ---------------------------------------------------------------- requests

func set_target(id: int, target: Variant, _now: float) -> Dictionary:
	if not world.players.has(id):
		return {"ok": false, "reason": "Unknown player"}
	var player: Dictionary = world.players[id]
	if typeof(target) != TYPE_INT:
		return {"ok": false, "reason": "Unknown target"}
	if target == 0:
		player["target"] = 0
		return {"ok": true}
	if not exists(target):
		return {"ok": false, "reason": "Unknown target"}
	if target > 0 and not hostile(id, target):
		return {"ok": false, "reason": "You can only attack players inside a PvP zone"}
	if not hostile(id, target):
		return {"ok": false, "reason": "You cannot attack that"}
	if distance(player["cell"], creature(target)["cell"]) > TARGET_RANGE:
		return {"ok": false, "reason": "Your target is too far away"}
	player["target"] = target
	return {"ok": true}


func cast(id: int, spell: Variant, now: float) -> Dictionary:
	if not world.players.has(id):
		return {"ok": false, "reason": "Unknown player", "events": []}
	if typeof(spell) != TYPE_STRING or not Spells.SPELLS.has(spell):
		return {"ok": false, "reason": "Unknown spell", "events": []}
	var player: Dictionary = world.players[id]
	var definition: Dictionary = Spells.SPELLS[spell]
	if not Spells.allows(spell, player["vocation"]):
		return {"ok": false, "reason": "Your class cannot cast %s" % definition["name"], "events": []}
	if player["level"] < definition["level"]:
		return {"ok": false, "reason": "%s needs level %d" % [definition["name"], definition["level"]], "events": []}
	if now < player["cooldowns"].get(spell, -INF) or now < player["groups"].get(definition["group"], -INF):
		return {"ok": false, "reason": "You are exhausted", "events": []}
	var limits: Dictionary = world.player_stats(id)
	var cost: int = maxi(1, roundi(limits["mana"] * definition["mana"]))
	if player["mana"] < cost:
		return {"ok": false, "reason": "Not enough mana (%d needed)" % cost, "events": []}
	var target: int = player["target"]
	var needs_target: bool = definition["kind"] in ["target", "area_target", "taunt_target", "root", "slow"]
	if needs_target and (target == 0 or not hostile(id, target)
			or not in_reach(player["cell"], creature(target)["cell"], definition.get("range", 1))):
		return {"ok": false, "reason": "You need a target in range", "events": []}
	if definition["kind"] == "taunt_target" and target > 0:
		return {"ok": false, "reason": "%s works on monsters" % definition["name"], "events": []}
	var events: Array = []
	player["mana"] -= cost
	player["cooldowns"][spell] = now + definition["cooldown"]
	player["groups"][definition["group"]] = now + Spells.GROUP_SECONDS[definition["group"]]
	var power: float = Spells.ranked_power(spell, int(player["spell_ranks"].get(spell, 1)))
	match definition["kind"]:
		"target":
			_missile(player["cell"], creature(target)["cell"], definition["color"], events)
			_hit(id, target, power, now, events)
		"area_self", "area_target":
			var center: Vector2i = player["cell"] if definition["kind"] == "area_self" else creature(target)["cell"]
			_area(center, definition["radius"], definition["color"], events)
			for victim: int in _enemies_near(id, center, definition["radius"]):
				_hit(id, victim, power, now, events)
		"taunt":
			_area(player["cell"], definition["radius"], definition["color"], events)
			for monster: int in world.monsters:
				if distance(world.monsters[monster]["cell"], player["cell"]) <= definition["radius"]:
					world.monsters[monster]["target"] = id
			events.append({"kind": "message", "id": id, "text": "You challenge every monster around you."})
		"root", "slow":
			_missile(player["cell"], creature(target)["cell"], definition["color"], events)
			_hit(id, target, power, now, events)
			if exists(target):
				restrain(target, definition["kind"], definition["seconds"], now, events)
		"taunt_target":
			_missile(player["cell"], creature(target)["cell"], definition["color"], events)
			_area(creature(target)["cell"], 0, definition["color"], events)
			world.monsters[target]["target"] = id
			events.append({"kind": "monster", "id": target, "movement": false})
			var provoked: Dictionary = monster_def(target)
			events.append({"kind": "message", "id": id, "text": "You provoke %s." % (provoked["name"] if provoked["rank"] == "boss"
				else "the " + provoked["name"].to_lower())})
		"heal_self":
			_heal(id, roundi(limits["health"] * power * rng.randf_range(0.9, 1.1)), events, id, now)
			_area(player["cell"], 0, definition["color"], events)
		"heal_area":
			var amount: int = maxi(1, roundi(limits["healing"] * power))
			_area(player["cell"], definition["radius"], definition["color"], events)
			# Group heals mend the caster and anyone they could not attack (never a foe in a PvP zone).
			for friend: int in world.players:
				if distance(world.players[friend]["cell"], player["cell"]) <= definition["radius"] and not hostile(id, friend):
					_heal(friend, amount, events, id, now)
	events.append({"kind": "player", "id": id})
	return {"ok": true, "events": events}


func _enemies_near(id: int, center: Vector2i, radius: int) -> Array[int]:
	var result: Array[int] = []
	for group: Dictionary in [world.monsters, world.players]:
		for other: int in group:
			if distance(group[other]["cell"], center) <= radius and hostile(id, other) \
					and line_of_sight(center, group[other]["cell"]):
				result.append(other)
	return result


# ---------------------------------------------------------------- damage and death

## What cuts a hit on `id`: its defense against physical hits, its magic defense against magic.
func defense_of(id: int, magic: bool = false) -> int:
	return world.player_stats(id)["magic_defense" if magic else "defense"] if id > 0 else 0


## Whether `attacker`'s attacks and spells are magic: Sorcerers, Druids, and casting monsters
## (Balance.ARMOR_TYPES, Monsters.MAGIC_ATTACKERS).
func magic_attacker(attacker: int) -> bool:
	if attacker > 0:
		return world.players.has(attacker) and world.players[attacker]["vocation"] in Balance.MAGIC_VOCATIONS
	return world.monsters.has(attacker) and world.monsters[attacker]["kind"] in Monsters.MAGIC_ATTACKERS


func attack_of(id: int) -> float:
	if id > 0:
		return world.player_stats(id)["attack"]
	var monster: Dictionary = world.monsters[id]
	return Balance.mob_damage(monster["level"], monster_def(id)["rank"]) * (ENRAGE_MULTIPLIER if monster["enraged"] else 1.0)


## One hit for `power` times the attacker's attack, or times `rune_base` for a rune spell (always magic).
func _hit(attacker: int, target: int, power: float, now: float, events: Array, rune_base: float = 0.0) -> void:
	var raw: float = (rune_base if rune_base > 0.0 else attack_of(attacker)) * power * rng.randf_range(0.85, 1.15)
	if attacker < 0 and target > 0 and monster_def(attacker)["rank"] == "boss":
		raw *= 1.0 + WOUND_STEP * wound_stacks(attacker, target, now)
		var wounds: Dictionary = world.monsters[attacker]["wounds"]
		wounds[target] = [wound_stacks(attacker, target, now) + 1, now + WOUND_SECONDS]
	if attacker > 0 and target > 0:
		raw *= Balance.PVP_DAMAGE
	var critical: bool = attacker > 0 and rng.randi_range(1, 100) <= world.player_stats(attacker)["critical"]
	if critical:
		raw *= CRITICAL_MULTIPLIER
	var amount: int = maxi(1, Balance.damage_taken(roundi(raw), defense_of(target, rune_base > 0.0 or magic_attacker(attacker))))
	_damage(attacker, target, amount, "critical" if critical else "damage", now, events)


func _damage(attacker: int, target: int, amount: int, style: String, now: float, events: Array) -> void:
	var victim: Dictionary = creature(target)
	if target < 0 and victim["returning"]:
		# A monster walking home after a leash reset cannot be hurt (no free kills on the way back).
		events.append({"kind": "hit", "target": target, "cell": victim["cell"], "amount": 0, "style": "damage", "source": attacker})
		return
	for id: int in [attacker, target]:
		if id > 0 and world.players.has(id):
			world.players[id]["last_combat"] = now
			world.players[id]["active_at"] = now
	if attacker > 0 and target > 0:
		for id: int in [attacker, target]:
			if world.players.has(id):
				if now >= world.players[id]["pvp_until"]:
					world.players[id]["pvp_since"] = now
				world.players[id]["pvp_until"] = now + Balance.PVP_COMBAT_SECONDS
	victim["health"] -= amount
	events.append({"kind": "hit", "target": target, "cell": victim["cell"], "amount": amount, "style": style, "source": attacker})
	if attacker < 0 and target > 0 and world.monsters.has(attacker):
		world.monsters[attacker]["fought"][target] = true
	if target < 0:
		if attacker > 0:
			victim["fought"][attacker] = true
			victim["damage_by"][attacker] = victim["damage_by"].get(attacker, 0) + amount
			if victim["target"] == 0:
				victim["target"] = attacker
		if victim["health"] <= 0:
			_kill_monster(target, now, events)
		else:
			events.append({"kind": "monster", "id": target, "movement": false})
	else:
		if attacker > 0:
			_register_aggression(attacker, target, now, events)
		if victim["health"] <= 0:
			_kill_player(target, now, events, attacker)
		else:
			events.append({"kind": "player", "id": target})


## Self-defence: the target is skulled or attacked the attacker unprovoked within AGGRESSION_SECONDS.
func justified(attacker: int, target: int, now: float) -> bool:
	var victim: Dictionary = world.players[target]
	return not victim["skull"].is_empty() or world.players[attacker]["aggressors"].get(target, -INF) > now


func _register_aggression(attacker: int, target: int, now: float, events: Array) -> void:
	var player: Dictionary = world.players[attacker]
	if justified(attacker, target, now):
		return
	if player["skull"] != "red":
		player["skull"] = "white"
		player["skull_until"] = maxf(player["skull_until"], now + WHITE_SKULL_SECONDS)
	# Only an unprovoked attack gives the victim the right to strike back.
	var aggressors: Dictionary = world.players[target]["aggressors"]
	for id: int in aggressors.keys():
		if aggressors[id] <= now:
			aggressors.erase(id)
	aggressors[attacker] = now + AGGRESSION_SECONDS
	events.append({"kind": "player", "id": attacker})


## Restores health. A healer who actually restores health to someone else counts as active
## (party sharing), and healing anyone a monster is fighting joins that monster's fight
## (boss trophies). Casting at full health earns neither.
func _heal(id: int, amount: int, events: Array, healer: int = 0, now: float = 0.0) -> void:
	var player: Dictionary = world.players[id]
	amount = roundi(amount * healing_factor(id, now))
	var healed: int = mini(amount, world.player_stats(id)["health"] - player["health"])
	player["health"] += healed
	if healer > 0 and healed > 0 and world.players.has(healer):
		if healer != id:
			world.players[healer]["active_at"] = now
		for monster: int in world.monsters:
			if world.monsters[monster]["fought"].has(id):
				world.monsters[monster]["fought"][healer] = true
	events.append({"kind": "hit", "target": id, "cell": player["cell"], "amount": healed, "style": "heal"})
	events.append({"kind": "player", "id": id})


## Healing strength for a player: 1 outside PvP combat; in it Balance.PVP_HEALING, fading to 0
## over PVP_DAMPENING_SECONDS of continuous PvP combat.
func healing_factor(id: int, now: float) -> float:
	var player: Dictionary = world.players[id]
	if now >= player.get("pvp_until", -INF):
		return 1.0
	var fading: float = 1.0 - (now - player.get("pvp_since", now)) / Balance.PVP_DAMPENING_SECONDS
	return Balance.PVP_HEALING * clampf(fading, 0.0, 1.0)


## Casts the rune spell of a rune item from the backpack at your target (Spells.RUNES_BY_ELEMENT):
## it is used up, starts the shared "rune" cooldown, and hits as magic for a geared attack of your
## level times its power, whatever your class.
func use_rune(id: int, kind: Variant, now: float) -> Dictionary:
	if not world.players.has(id):
		return {"ok": false, "reason": "Unknown player", "events": []}
	if typeof(kind) != TYPE_STRING or not World.ITEMS.has(kind) or Spells.rune_of(World.ITEMS[kind]).is_empty():
		return {"ok": false, "reason": "That is not a rune", "events": []}
	var player: Dictionary = world.players[id]
	var item: Dictionary = World.ITEMS[kind]
	var rune: Dictionary = Spells.rune_of(item)
	if player["level"] < item["level"]:
		return {"ok": false, "reason": "%s needs level %d" % [item["name"], item["level"]], "events": []}
	if now < player["groups"].get("rune", -INF):
		return {"ok": false, "reason": "You are exhausted", "events": []}
	var slot: int = player["backpack"].find_custom(func(entry: String) -> bool: return World.kind_of(entry) == kind)
	if slot < 0:
		return {"ok": false, "reason": "You have no %s left" % item["name"].to_lower(), "events": []}
	var target: int = player["target"]
	if target == 0 or not hostile(id, target) or not in_reach(player["cell"], creature(target)["cell"], Spells.RUNE_RANGE):
		return {"ok": false, "reason": "You need a target in range", "events": []}
	var left: int = World.count_of(player["backpack"][slot]) - 1
	player["backpack"][slot] = World.make_entry(kind, left) if left > 0 else ""
	player["groups"]["rune"] = now + Spells.GROUP_SECONDS["rune"]
	var events: Array = [{"kind": "player", "id": id}]
	var base: float = Balance.geared_attack(player["level"])
	var center: Vector2i = creature(target)["cell"]
	_missile(player["cell"], center, rune["color"], events)
	var struck: Array[int] = []
	if rune["shape"] == "circle":
		var cells: Array[Vector2i] = circle(center, rune["radius"])
		events.append({"kind": "area", "cells": cells, "color": rune["color"], "element": item["rune"]})
		for victim: int in _enemies_near(id, center, rune["radius"]):
			if creature(victim)["cell"] in cells:
				struck.append(victim)
				_hit(id, victim, rune["power"], now, events, base)
	else:
		struck.append(target)
		_hit(id, target, rune["power"], now, events, base)
		events.append({"kind": "area", "cells": [center], "color": rune["color"], "element": item["rune"]})
		var from: Vector2i = center
		for jump: int in rune["jumps"]:
			var next: int = 0
			var nearest: int = rune["reach"] + 1
			for other: int in _enemies_near(id, from, rune["reach"]):
				var gap: int = distance(creature(other)["cell"], from)
				if other not in struck and gap < nearest:
					next = other
					nearest = gap
			if next == 0:
				break
			struck.append(next)
			_missile(from, creature(next)["cell"], rune["color"], events)
			events.append({"kind": "area", "cells": [creature(next)["cell"]], "color": rune["color"], "element": item["rune"]})
			from = creature(next)["cell"]
			_hit(id, next, rune["chain_power"], now, events, base)
	if rune.has("slow"):
		for victim: int in struck:
			if exists(victim):
				restrain(victim, "slow", rune["slow"], now, events)
	return {"ok": true, "events": events}


## Tiles of a round area, as Tibia's: every tile with dx² + dy² <= r² + r (radius 2: 21 tiles,
## radius 3: 37), skipping walls and the void.
static func circle(center: Vector2i, radius: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var cell: Vector2i = center + Vector2i(dx, dy)
			var tile: String = World.terrain(cell)
			if dx * dx + dy * dy <= radius * radius + radius and tile not in [" ", ""] and tile not in World.WALLS:
				cells.append(cell)
	return cells


func _missile(from: Vector2i, to: Vector2i, color: Color, events: Array) -> void:
	if from != to:
		events.append({"kind": "missile", "from": from, "to": to, "color": color})


func _area(center: Vector2i, radius: int, color: Color, events: Array) -> void:
	var cells: Array[Vector2i] = []
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var cell: Vector2i = center + Vector2i(dx, dy)
			if World.terrain(cell) not in [" ", ""] and World.terrain(cell) not in World.WALLS:
				cells.append(cell)
	events.append({"kind": "area", "cells": cells, "color": color})


func _kill_monster(id: int, now: float, events: Array) -> void:
	var monster: Dictionary = world.monsters[id]
	var definition: Dictionary = monster_def(id)
	var experience: int = Balance.mob_experience(monster["level"], definition["rank"])
	var credited: Array[int] = _award_experience(experience, monster["damage_by"], monster["cell"], now, events)
	_credit_tasks(monster["kind"], credited, events)
	if definition.has("relics"):
		_award_trophies(monster["kind"], monster["fought"], monster["cell"], events)
	_drop_loot(monster, credited, now, events)
	_unindex(id)
	world.monsters.erase(id)
	_taken_at = NAN
	events.append({"kind": "monster_gone", "id": id, "cell": monster["cell"]})
	for player: int in world.players:
		if world.players[player]["target"] == id:
			world.players[player]["target"] = 0
			events.append({"kind": "player", "id": player})
	if monster["spawn"] >= 0:
		respawns.append([now + definition.get("respawn", Monsters.RESPAWN_SECONDS), monster["spawn"]])


## Splits a kill's experience by damage dealt; a sharing party pools its members' portions
## and divides the pool (with the vocation bonus) evenly among its active members nearby.
## Returns every player credited with the kill.
func _award_experience(experience: int, damage_by: Dictionary, cell: Vector2i, now: float, events: Array) -> Array[int]:
	var credited: Array[int] = []
	var total: int = 0
	for attacker: int in damage_by:
		total += damage_by[attacker]
	if total <= 0:
		return credited
	var pools: Dictionary = {}
	for attacker: int in damage_by:
		if not world.players.has(attacker):
			continue
		var portion: float = experience * float(damage_by[attacker]) / total
		var leader: int = world.players[attacker]["party"]
		if leader != 0 and sharing_members(leader, cell, now).has(attacker):
			pools[leader] = pools.get(leader, 0.0) + portion
		else:
			grant_experience(attacker, roundi(portion), events)
			credited.append(attacker)
	for leader: int in pools:
		var members: Array[int] = sharing_members(leader, cell, now)
		var each: int = roundi(pools[leader] * share_bonus(members) / members.size())
		for member: int in members:
			grant_experience(member, each, events)
			if member not in credited:
				credited.append(member)
	return credited


# ---------------------------------------------------------------- relic quests

## Everyone who took part in the fight and is still in it when the boss falls earns one trophy:
## players who damaged the boss, players it hit (tanks), and players who healed any of them, if
## they are alive and within TROPHY_RADIUS of it. Standing nearby is not enough, and neither is
## having fought and died: a raid that wipes the raid fighting a boss and finishes it takes the
## trophies (the bosses stand in open PvP zones).
func _award_trophies(boss: String, fought: Dictionary, at: Vector2i, events: Array) -> void:
	var name: String = Monsters.MONSTERS[boss]["name"]
	for id: int in fought:
		if not world.players.has(id) or world.players[id]["health"] <= 0 or distance(world.players[id]["cell"], at) > TROPHY_RADIUS:
			continue
		var player: Dictionary = world.players[id]
		player["trophies"][boss] = player["trophies"].get(boss, 0) + 1
		events.append({"kind": "message", "id": id, "text": "You helped slay %s. Claim a relic from %s." % [name, relic_keeper_text(boss)]})
		events.append({"kind": "player", "id": id})


## Who trades `boss`'s trophies for relics, for messages ("Ysolde in Reedmere").
static func relic_keeper_text(boss: String) -> String:
	for id: String in World.QUEST_GIVERS:
		if World.QUEST_GIVERS[id]["boss"] == boss:
			return "%s in %s" % [World.QUEST_GIVERS[id]["name"], World.QUEST_GIVERS[id]["place"]]
	return "the relic keepers"


## The boss whose quest rewards a relic, or "".
static func relic_boss(relic: String) -> String:
	for boss: String in Monsters.MONSTERS:
		if relic in Monsters.MONSTERS[boss].get("relics", []):
			return boss
	return ""


## Trades one of the boss's trophies for a relic, in range of a quest giver, into the backpack.
func claim_relic(id: int, npc: Variant, relic: Variant, _now: float) -> Dictionary:
	if not world.players.has(id):
		return {"ok": false, "reason": "Unknown player", "events": []}
	if typeof(npc) != TYPE_STRING or not World.QUEST_GIVERS.has(npc) or World.QUEST_GIVERS[npc]["boss"].is_empty():
		return {"ok": false, "reason": "Unknown quest giver", "events": []}
	var player: Dictionary = world.players[id]
	var keeper: Dictionary = World.QUEST_GIVERS[npc]
	if not World.in_talk_range(player["cell"], keeper["cell"]):
		return {"ok": false, "reason": "Walk closer to %s" % keeper["name"], "events": []}
	var boss: String = relic_boss(relic) if typeof(relic) == TYPE_STRING else ""
	if boss.is_empty():
		return {"ok": false, "reason": "Unknown relic", "events": []}
	if boss != keeper["boss"]:
		return {"ok": false, "reason": "%s only keeps %s's relics; see %s" % [keeper["name"],
			Monsters.MONSTERS[keeper["boss"]]["name"], relic_keeper_text(boss)], "events": []}
	if player["trophies"].get(boss, 0) <= 0:
		return {"ok": false, "reason": "Slay %s first" % Monsters.MONSTERS[boss]["name"], "events": []}
	var slot: int = player["backpack"].find("")
	if slot < 0:
		return {"ok": false, "reason": "Your backpack is full", "events": []}
	player["trophies"][boss] -= 1
	if player["trophies"][boss] == 0:
		player["trophies"].erase(boss)
	player["backpack"][slot] = relic
	var events: Array = [{"kind": "player", "id": id},
		{"kind": "message", "id": id, "text": "%s hands you the %s." % [keeper["name"], World.ITEMS[relic]["name"]]}]
	return {"ok": true, "events": events}


# ---------------------------------------------------------------- spell ranks

## A class trainer in range raises one of your known spells a rank for rune shards from your
## backpack (Spells.RANK_COSTS). Returns {ok, events} or {ok: false, reason, events}.
func empower_spell(id: int, npc: Variant, spell: Variant, _now: float) -> Dictionary:
	if not world.players.has(id):
		return {"ok": false, "reason": "Unknown player", "events": []}
	var player: Dictionary = world.players[id]
	if not World.serves(npc, "runes", player["cell"]):
		return {"ok": false, "reason": "Walk closer to a class trainer", "events": []}
	var trainer: Dictionary = World.QUEST_GIVERS[npc]
	if Quests.TRAINERS[npc][0] != player["vocation"]:
		return {"ok": false, "reason": "%s only teaches %ss" % [trainer["name"],
			Balance.VOCATIONS[Quests.TRAINERS[npc][0]]["name"]], "events": []}
	if typeof(spell) != TYPE_STRING or not Spells.rankable(spell) or not Spells.allows(spell, player["vocation"]):
		return {"ok": false, "reason": "%s cannot empower that" % trainer["name"], "events": []}
	var definition: Dictionary = Spells.SPELLS[spell]
	if player["level"] < definition["level"]:
		return {"ok": false, "reason": "%s needs level %d" % [definition["name"], definition["level"]], "events": []}
	var rank: int = int(player["spell_ranks"].get(spell, 1))
	var cost: int = Spells.rank_cost(rank)
	if cost == 0:
		return {"ok": false, "reason": "%s is already at its highest rank" % definition["name"], "events": []}
	if World.carried(player["backpack"], Spells.SHARD) < cost:
		return {"ok": false, "reason": "You need %d rune shards" % cost, "events": []}
	World.remove_carried(player["backpack"], Spells.SHARD, cost)
	player["spell_ranks"][spell] = rank + 1
	var text: String = "%s carves %d rune shards into your %s: rank %d, %d%% stronger." % [trainer["name"], cost,
		definition["name"], rank + 1, roundi(Spells.RANK_POWER * rank * 100.0)]
	var flash: Array[Vector2i] = [player["cell"]]
	return {"ok": true, "events": [{"kind": "player", "id": id}, {"kind": "message", "id": id, "text": text},
		{"kind": "area", "cells": flash, "color": definition["color"]}]}


# ---------------------------------------------------------------- town tasks

## Accepts ("accept") or turns in ("complete") the hunting task of a quest giver in range.
## Turning in a finished task replaces your pack with the next, bigger one.
func task_action(id: int, npc: Variant, task: Variant, action: Variant, _now: float) -> Dictionary:
	if not world.players.has(id):
		return {"ok": false, "reason": "Unknown player", "events": []}
	var player: Dictionary = world.players[id]
	if not World.serves(npc, "quests", player["cell"]) or World.QUEST_GIVERS[npc]["tasks"].is_empty():
		return {"ok": false, "reason": "Walk closer to a quest giver", "events": []}
	if typeof(task) != TYPE_STRING or task not in World.QUEST_GIVERS[npc]["tasks"]:
		return {"ok": false, "reason": "%s has no such task" % World.QUEST_GIVERS[npc]["name"], "events": []}
	var definition: Dictionary = Quests.TASKS[task]
	var giver: String = World.QUEST_GIVERS[npc]["name"]
	if player["done_tasks"].has(task):
		return {"ok": false, "reason": "You already finished %s" % definition["title"], "events": []}
	var target: String = Quests.target_name(task)
	var text: String = ""
	var events: Array = [{"kind": "player", "id": id}]
	match action:
		"accept":
			if player["tasks"].has(task):
				return {"ok": false, "reason": "You are already on that task", "events": []}
			var requires: String = definition.get("requires", "")
			if not requires.is_empty() and not player["done_tasks"].has(requires):
				return {"ok": false, "reason": "Finish %s first" % Quests.TASKS[requires]["title"], "events": []}
			if not World.task_open(task, player):
				return {"ok": false, "reason": CHOOSE_CLASS_FIRST if player["vocation"] == Balance.ADVENTURER
					else "That task is for Adventurers", "events": []}
			player["tasks"][task] = 0
			text = "%s: slay %s, then return to %s." % [definition["title"],
				target if definition["count"] == 1 else "%d %s" % [definition["count"], target], giver]
		"complete":
			if player["tasks"].get(task, 0) < definition["count"]:
				return {"ok": false, "reason": "Slay %s first" % (target if definition["count"] == 1
					else "%d %s" % [definition["count"], target]), "events": []}
			var items: Array = World.task_items(task, player["vocation"])
			var packed: Array = World.with_items(player["backpack"], items)
			if not items.is_empty() and packed.is_empty():
				return {"ok": false, "reason": "Make room in your backpack for the reward (%d free slots)" % items.size(),
					"events": []}
			player["tasks"].erase(task)
			player["done_tasks"][task] = true
			if not items.is_empty():
				player["backpack"] = packed
			if definition["reward"] == "experience":
				var reward: Dictionary = Quests.reward(task)
				player["gold"] += reward["gold"]
				text = "%s rewards you with %d gold%s." % [giver, reward["gold"], World.items_text(items)]
				grant_experience(id, reward["experience"], events)
			else:
				var pack: String = Quests.next_pack(player["equipment"].get("bag", ""))
				if pack.is_empty():
					text = "%s thanks you. Your pack is already the largest there is." % giver
				else:
					world.wear_pack(id, pack)
					text = "%s gives you a %s: %d backpack slots." % [giver, World.ITEMS[pack]["name"], World.main_size(player)]
		_:
			return {"ok": false, "reason": "Unknown task request", "events": []}
	if action == "complete":
		text += next_task_hint(player, npc)
	events.append({"kind": "message", "id": id, "text": text})
	return {"ok": true, "events": events}


## " Next: ..." pointing to the task World.next_task suggests, when another giver offers it.
static func next_task_hint(player: Dictionary, current_giver: String) -> String:
	var next: String = World.next_task(player)
	if next.is_empty() or Quests.TASKS[next]["giver"] == current_giver:
		return ""
	var giver: Dictionary = World.QUEST_GIVERS[Quests.TASKS[next]["giver"]]
	var band: Vector2i = World.task_levels(next)
	return " Next: %s in %s has work for levels %d-%d." % [giver["name"], giver["place"], band.x, band.y]


func _credit_tasks(kind: String, credited: Array[int], events: Array) -> void:
	for id: int in credited:
		var tasks: Dictionary = world.players[id]["tasks"]
		for task: String in tasks:
			var definition: Dictionary = Quests.TASKS[task]
			if Quests.counts(task, kind) and tasks[task] < definition["count"]:
				tasks[task] += 1
				var done: bool = tasks[task] == definition["count"]
				events.append({"kind": "message", "id": id, "text": "%s: %d/%d%s" % [definition["title"], tasks[task],
					definition["count"], ". Return to the quest giver." if done else ""]})
				events.append({"kind": "player", "id": id})


# ---------------------------------------------------------------- potions

## The cooldown timer key of a potion kind (shared with spell timers in player["cooldowns"]).
static func potion_timer(kind: String) -> String:
	return "potion:" + String(World.ITEMS.get(kind, {}).get("timer", kind))


## Drinks one potion from a backpack stack: restores its share of maximum health or mana.
func drink(id: int, index: Variant, now: float) -> Dictionary:
	if not world.players.has(id):
		return {"ok": false, "reason": "Unknown player", "events": []}
	var player: Dictionary = world.players[id]
	var backpack: Array = player["backpack"]
	if typeof(index) != TYPE_INT or index < 0 or index >= backpack.size():
		return {"ok": false, "reason": "Unknown item location", "events": []}
	var kind: String = World.kind_of(backpack[index])
	if World.ITEMS.get(kind, {}).has("eat"):
		return _eat(id, index, kind, now)
	if not World.ITEMS.get(kind, {}).has("drink"):
		return {"ok": false, "reason": "You cannot drink that", "events": []}
	# Each potion kind has its own cooldown (items.json), kept with the spell timers so the client sees it.
	var ready: float = player["cooldowns"].get(potion_timer(kind), -INF)
	if now < ready:
		return {"ok": false, "reason": "%s ready in %d s" % [World.ITEMS[kind]["name"], ceili(ready - now)], "events": []}
	var limits: Dictionary = world.player_stats(id)
	var restores: Dictionary = World.ITEMS[kind]["drink"]
	var needed: bool = false
	for stat: String in restores:
		needed = needed or player[stat] < limits[stat]
	if not needed:
		return {"ok": false, "reason": "You are already at full %s" % " and ".join(restores.keys()), "events": []}
	backpack[index] = World.make_entry(kind, World.count_of(backpack[index]) - 1) if World.count_of(backpack[index]) > 1 else ""
	player["cooldowns"][potion_timer(kind)] = now + World.ITEMS[kind]["cooldown"]
	var events: Array = []
	for stat: String in restores:
		var amount: int = maxi(1, roundi(limits[stat] * restores[stat]))
		if stat == "health":
			_heal(id, amount, events, 0, now)
		else:
			var gained: int = mini(amount, limits[stat] - player[stat])
			player[stat] += gained
			events.append({"kind": "hit", "target": id, "cell": player["cell"], "amount": gained, "style": "mana"})
	events.append({"kind": "player", "id": id})
	return {"ok": true, "events": events}


## Eats one food from a backpack stack: its "eat" regen share speeds health and mana
## regeneration for its seconds, replacing any meal eaten before.
func _eat(id: int, index: int, kind: String, now: float) -> Dictionary:
	var player: Dictionary = world.players[id]
	var backpack: Array = player["backpack"]
	var meal: Dictionary = World.ITEMS[kind]["eat"]
	backpack[index] = World.make_entry(kind, World.count_of(backpack[index]) - 1) if World.count_of(backpack[index]) > 1 else ""
	player["fed"] = {"kind": kind, "until": now + meal["seconds"]}
	var text: String = "You eat the %s: %d%% faster regeneration for %d minutes." % [World.ITEMS[kind]["name"],
		roundi(meal["regen"] * 100.0), roundi(meal["seconds"] / 60.0)]
	return {"ok": true, "events": [{"kind": "player", "id": id}, {"kind": "message", "id": id, "text": text}]}


## The extra share of regeneration from the meal a player has eaten (0 when hungry).
func meal_bonus(id: int, now: float) -> float:
	var fed: Dictionary = world.players[id].get("fed", {})
	if fed.is_empty() or fed["until"] <= now:
		return 0.0
	return World.ITEMS[fed["kind"]]["eat"]["regen"]


# ---------------------------------------------------------------- parties

func same_party(first: int, second: int) -> bool:
	return world.players.has(first) and world.players.has(second) and world.players[first]["party"] != 0 \
		and world.players[first]["party"] == world.players[second]["party"]


func party_members(leader: int) -> Array[int]:
	var members: Array[int] = []
	if leader == 0:
		return members
	for id: int in world.players:
		if world.players[id]["party"] == leader:
			members.append(id)
	members.sort()
	return members


## Members who share a kill at `cell`: nearby and recently active, at least two of them, and
## within the level ratio. An empty result means every member keeps their own damage share.
func sharing_members(leader: int, cell: Vector2i, now: float) -> Array[int]:
	var members: Array[int] = []
	var lowest: int = Balance.MAX_LEVEL
	var highest: int = 1
	for id: int in party_members(leader):
		var player: Dictionary = world.players[id]
		if distance(player["cell"], cell) <= SHARE_RANGE and now - player["active_at"] <= SHARE_ACTIVE_SECONDS:
			members.append(id)
			lowest = mini(lowest, player["level"])
			highest = maxi(highest, player["level"])
	if members.size() < 2 or lowest < ceili(highest * SHARE_LEVEL_RATIO):
		members.clear()
	return members


func share_bonus(members: Array[int]) -> float:
	var vocations: Dictionary = {}
	for id: int in members:
		vocations[world.players[id]["vocation"]] = true
	return SHARE_BONUS[mini(vocations.size(), SHARE_BONUS.size() - 1)]


func describe(id: int) -> String:
	var player: Dictionary = world.players[id]
	if not String(player.get("name", "")).is_empty():
		return String(player["name"])
	return "%s%s %d" % ["Bot " if player.get("bot", false) else "", Balance.profile_of(player["vocation"])["name"], player["level"]]


## invite/revoke (by a leader or a player without a party), join (an inviting leader), and leave.
func party_action(id: int, action: Variant, other: Variant, _now: float) -> Dictionary:
	if not world.players.has(id):
		return {"ok": false, "reason": "Unknown player", "events": []}
	if typeof(action) != TYPE_STRING or action not in PARTY_ACTIONS or typeof(other) != TYPE_INT:
		return {"ok": false, "reason": "Unknown party action", "events": []}
	var player: Dictionary = world.players[id]
	var events: Array = []
	if action == "leave":
		if player["party"] == 0:
			return {"ok": false, "reason": "You are not in a party", "events": []}
		leave_party(id, events)
		return {"ok": true, "events": events}
	if other == id or not world.players.has(other):
		return {"ok": false, "reason": "Unknown player", "events": []}
	var friend: Dictionary = world.players[other]
	match action:
		"invite":
			if player["party"] != 0 and player["party"] != id:
				return {"ok": false, "reason": "Only the party leader can invite", "events": []}
			if friend["party"] != 0:
				return {"ok": false, "reason": "%s is already in a party" % describe(other), "events": []}
			if party_members(id).size() >= World.MAX_PLAYERS:
				return {"ok": false, "reason": "Your party is full", "events": []}
			player["invited"][other] = true
			events.append({"kind": "message", "id": id, "text": "You invited %s to your party." % describe(other)})
			events.append({"kind": "message", "id": other,
				"text": "%s invites you to a party. Right-click them to join." % describe(id)})
		"revoke":
			if not player["invited"].has(other):
				return {"ok": false, "reason": "You have not invited %s" % describe(other), "events": []}
			player["invited"].erase(other)
			events.append({"kind": "message", "id": other, "text": "%s withdrew the party invitation." % describe(id)})
		"join":
			if not friend["invited"].has(id) or (friend["party"] != 0 and friend["party"] != other):
				return {"ok": false, "reason": "%s has not invited you" % describe(other), "events": []}
			if player["party"] != 0:
				return {"ok": false, "reason": "Leave your party first", "events": []}
			friend["invited"].erase(id)
			player["invited"].clear()
			friend["party"] = other
			player["party"] = other
			for member: int in party_members(other):
				for partner: int in party_members(other):
					if world.players[member]["target"] == partner:
						world.players[member]["target"] = 0
				events.append({"kind": "message", "id": member, "text":
					"You joined %s's party." % describe(other) if member == id
					else "%s joined the party." % describe(id)})
	events.append({"kind": "player", "id": id})
	events.append({"kind": "player", "id": other})
	return {"ok": true, "events": events}


## Removes a player from their party (also on disconnect), passing leadership to the lowest id
## and disbanding a party of one. Invitations sent by or to the player are withdrawn.
func leave_party(id: int, events: Array) -> void:
	var player: Dictionary = world.players[id]
	var leader: int = player["party"]
	player["invited"].clear()
	for other: int in world.players:
		if world.players[other]["invited"].erase(id):
			events.append({"kind": "player", "id": other})
	if leader == 0:
		return
	player["party"] = 0
	events.append({"kind": "player", "id": id})
	events.append({"kind": "message", "id": id, "text": "You left the party."})
	var rest: Array[int] = party_members(leader)
	var successor: int = 0 if rest.size() < 2 else (leader if rest.has(leader) else rest[0])
	for member: int in rest:
		world.players[member]["party"] = successor
		if successor == 0:
			world.players[member]["invited"].clear()
		events.append({"kind": "player", "id": member})
		var note: String = "%s left the party." % describe(id)
		if successor == 0:
			note += " The party has disbanded."
		elif successor != leader:
			note += " %s now leads." % ("You" if member == successor else describe(successor))
		events.append({"kind": "message", "id": member, "text": note})


## Rolls the monster's loot table plus level-scaled gold coins (Balance.coins_per_kill). Returns the dropped item ids.
func roll_loot(kind: String, level: int) -> Array[String]:
	var loot: Array[String] = []
	for entry: Array in Monsters.LOOT.get(kind, []):
		var item: Dictionary = World.ITEMS[entry[0]]
		# Equipment and runes only drop from monsters of their level.
		if rng.randf() < float(entry[1]) and (item["slot"].is_empty() and not item.has("rune") or level >= item["level"]):
			loot.append(entry[0])
	var definition: Dictionary = Monsters.MONSTERS[kind]
	if rng.randf() < float(definition.get("gear_chance", GEAR_DROP_CHANCE.get(definition["rank"], 0.0))):
		loot.append(gear_drop(level))
	var expected: float = Balance.coins_per_kill(level, definition["rank"])
	var piles: int = floori(expected) + (1 if rng.randf() < expected - floorf(expected) else 0)
	if piles > 0:
		loot.append(World.make_entry("gold_coins", piles))
	return loot


## A random equipment piece from the monster's level tier, or (GEAR_LOWER_TIER_CHANCE) the
## tier below. Accessories exist only from Items.ACCESSORY_LEVEL, so lower monsters never drop them.
## Source-specific hunting weapons roll through Monsters.LOOT instead.
func gear_drop(level: int) -> String:
	var tier: int = Items.tier_for(level)
	var index: int = Items.TIER_LEVELS.find(tier)
	if index > 0 and rng.randf() < GEAR_LOWER_TIER_CHANCE:
		tier = Items.TIER_LEVELS[index - 1]
	var choices: Array[String] = []
	for kind: String in World.ITEMS:
		if World.ITEMS[kind]["level"] == tier and not World.ITEMS[kind]["slot"].is_empty() \
				and not World.bound(kind) and not World.ITEMS[kind].get("loot_only", false) and not World.is_bag(kind):
			choices.append(kind)
	return choices[rng.randi_range(0, choices.size() - 1)]


func _drop_loot(monster: Dictionary, credited: Array[int], now: float, events: Array) -> void:
	var loot: Array[String] = roll_loot(monster["kind"], monster["level"])
	loot.reverse()  # spill() places from the back: items before gold, nearest tiles first
	var changed: Array[Vector2i] = spill(monster["cell"], loot)
	if changed.is_empty():
		return
	events.append({"kind": "ground", "cells": changed})
	var owners: Dictionary = {}
	for player: int in credited:
		owners[player] = true
	if not owners.is_empty():
		for cell: Vector2i in changed:
			loot_claims[cell] = {"owners": owners, "until": now + LOOT_CLAIM_SECONDS}


## Drops lapsed loot claims and claims on tiles that have since been cleared.
func _sweep_loot_claims(now: float) -> void:
	if now < _next_claim_sweep:
		return
	_next_claim_sweep = now + LOOT_SWEEP_SECONDS
	for cell: Vector2i in loot_claims.keys():
		if now >= loot_claims[cell]["until"] or world.ground.get(cell, []).is_empty():
			loot_claims.erase(cell)


## Places items on walkable tiles within SPILL_RADIUS of origin, nearest first, up to
## GROUND_STACK_MAX per tile. Consumes `items` from the back; anything left did not fit.
func spill(origin: Vector2i, items: Array[String]) -> Array[Vector2i]:
	var changed: Array[Vector2i] = []
	var cells: Array[Vector2i] = [origin]
	var seen: Dictionary = {origin: true}
	var index: int = 0
	while not items.is_empty() and index < cells.size():
		var cell: Vector2i = cells[index]
		index += 1
		var stack: Array = world.ground.get(cell, [])
		if World.walkable(cell):
			var placed: bool = false
			while not items.is_empty() and World.stack_onto(stack, items.back()):
				items.pop_back()
				placed = true
			if placed:
				world.ground[cell] = stack
				changed.append(cell)
		for step: Vector2i in STEPS:
			var next: Vector2i = cell + step
			if not seen.has(next) and distance(next, origin) <= SPILL_RADIUS and World.terrain(next) not in ["", " "]:
				seen[next] = true
				cells.append(next)
	return changed


static func total_experience(level: int, progress: int) -> int:
	var total: int = progress
	for below: int in range(1, clampi(level, 1, Balance.MAX_LEVEL)):
		total += Balance.experience_to_next(below)
	return total


## [level, progress within that level] for a total amount of experience.
static func level_from_total(total: int) -> Array:
	var level: int = 1
	var left: int = maxi(total, 0)
	while level < Balance.MAX_LEVEL and left >= Balance.experience_to_next(level):
		left -= Balance.experience_to_next(level)
		level += 1
	return [level, left if level < Balance.MAX_LEVEL else 0]


func grant_experience(id: int, amount: int, events: Array) -> void:
	var player: Dictionary = world.players[id]
	var before: int = player["level"]
	var result: Array = level_from_total(total_experience(player["level"], player["experience"]) + maxi(amount, 0))
	# Adventurers stop just short of the level after ADVENTURER_MAX_LEVEL until they choose a vocation.
	if player["vocation"] == Balance.ADVENTURER and result[0] > Balance.ADVENTURER_MAX_LEVEL:
		var full: int = Balance.experience_to_next(Balance.ADVENTURER_MAX_LEVEL) - 1
		if player["level"] < Balance.ADVENTURER_MAX_LEVEL or player["experience"] < full:
			events.append({"kind": "message", "id": id, "text":
				"You cannot grow past level %d without a class. Choose one at a trainer in Cinder Crossing." % Balance.ADVENTURER_MAX_LEVEL})
		result = [Balance.ADVENTURER_MAX_LEVEL, full]
	player["level"] = result[0]
	player["experience"] = result[1]
	events.append({"kind": "hit", "target": id, "cell": player["cell"], "amount": amount, "style": "experience"})
	if player["level"] > before:
		events.append({"kind": "message", "id": id, "text": "You advanced to level %d." % player["level"]})
	events.append({"kind": "player", "id": id})


func _kill_player(id: int, now: float, events: Array, killer: int = 0) -> void:
	var player: Dictionary = world.players[id]
	if killer > 0 and killer != id and world.players.has(killer) and not justified(killer, id, now):
		var murderer: Dictionary = world.players[killer]
		murderer["unjustified"] = murderer["unjustified"].filter(func(time: float) -> bool:
			return now - time < UNJUSTIFIED_WINDOW_SECONDS)
		murderer["unjustified"].append(now)
		if murderer["unjustified"].size() >= RED_SKULL_KILLS:
			murderer["skull"] = "red"
			murderer["skull_until"] = now + RED_SKULL_SECONDS
			events.append({"kind": "message", "id": killer, "text": "You have a red skull: you will lose everything if you die."})
		else:
			events.append({"kind": "message", "id": killer,
				"text": "Unjustified kill (%d of %d before a red skull)." % [murderer["unjustified"].size(), RED_SKULL_KILLS]})
		events.append({"kind": "player", "id": killer})
	var lost_items: Array[String] = _drop_belongings(id, events)
	var total: int = total_experience(player["level"], player["experience"])
	var lost: int = roundi(total * DEATH_PENALTY)
	var result: Array = level_from_total(total - lost)
	player["level"] = result[0]
	player["experience"] = result[1]
	var home: Vector2i = World.SPAWNS[0]
	for spawn: Vector2i in World.SPAWNS:
		if not world.occupied(spawn, now, id):
			home = spawn
			break
	player["cell"] = home
	player["from"] = home
	player["next_move"] = now
	player["target"] = 0
	var limits: Dictionary = world.player_stats(id)
	player["health"] = limits["health"]
	player["mana"] = limits["mana"]
	for monster: int in world.monsters:
		if world.monsters[monster]["target"] == id:
			world.monsters[monster]["target"] = 0
	for other: int in world.players:
		if world.players[other]["target"] == id:
			world.players[other]["target"] = 0
			events.append({"kind": "player", "id": other})
	player["aggressors"].clear()
	player["pvp_until"] = -INF
	var summary: String = "You are dead. You lost %d experience" % lost
	if lost_items.is_empty():
		summary += "; below level %d you keep your items and gold" % PROTECTION_LEVEL
	elif lost_items.size() == 1:
		summary += ", your backpack, and your gold"
	else:
		summary += ", your backpack, your gold, and %s" % ", ".join(lost_items.slice(1))
	events.append({"kind": "message", "id": id, "text": summary + "."})
	events.append({"kind": "player", "id": id})


## Drops the backpack, purse gold, and unlucky (or, with a red skull, all) worn items around
## the death tile; in a full-loot zone every worn item drops. Bound relics and packs, banked
## gold, and the depot always stay. Returns ["backpack", worn item names...] or [] if nothing was carried.
func _drop_belongings(id: int, events: Array) -> Array[String]:
	var player: Dictionary = world.players[id]
	# Solo companions come straight back to their player with what they carried.
	if player["level"] < PROTECTION_LEVEL or player.get("companion", false):
		return []
	var dropped: Array[String] = []
	var lost_worn: Array[String] = []
	# High-risk zones (the Hollow Reach) drop everything worn, like a red skull.
	var full_loot: bool = World.zone_at(player["cell"]).get("full_loot", false)
	for index: int in player["backpack"].size():
		if not player["backpack"][index].is_empty() and not World.bound(player["backpack"][index]):
			dropped.append(player["backpack"][index])
			player["backpack"][index] = ""
	var piles: int = player["gold"] / World.ITEMS["gold_coins"]["gold"]
	while piles > 0:
		dropped.append(World.make_entry("gold_coins", mini(piles, World.STACK_MAX)))
		piles -= World.STACK_MAX
	player["gold"] = 0
	for slot: String in World.SLOTS:
		if player["equipment"].has(slot) and not World.bound(player["equipment"][slot]) \
				and (player["skull"] == "red" or full_loot or rng.randf() < EQUIPMENT_LOSS_CHANCE):
			dropped.append(player["equipment"][slot])
			lost_worn.append(World.ITEMS[player["equipment"][slot]]["name"])
			player["equipment"].erase(slot)
	var changed: Array[Vector2i] = spill(player["cell"], dropped)
	if not changed.is_empty():
		events.append({"kind": "ground", "cells": changed})
	world.clamp_vitals(id)
	var result: Array[String] = ["backpack"]
	result.append_array(lost_worn)
	return result


# ---------------------------------------------------------------- simulation

func tick(now: float) -> Array:
	var events: Array = []
	if now - _last_tick < TICK_SECONDS:
		return events
	_last_tick = now
	_taken_at = NAN
	_sweep_loot_claims(now)
	for id: int in world.players.keys():
		if world.players.has(id):
			_player_tick(id, now, events)
	_wake_camps(now, events)
	var awake: Dictionary = _awake_chunks()
	for id: int in _near_players():
		if world.monsters.has(id) and _awake(world.monsters[id], awake):
			_monster_tick(id, now, events)
			if world.monsters.has(id):
				_track_active(id)
	for index: int in range(respawns.size() - 1, -1, -1):
		if now >= respawns[index][0]:
			var spawn: int = respawns[index][1]
			respawns.remove_at(index)
			if _player_near(World.MONSTER_SPAWNS[spawn]["cell"], 4) or not _spawn_at_marker(spawn, now, events):
				respawns.append([now + SPAWN_RETRY_SECONDS, spawn])
	return events


func _player_tick(id: int, now: float, events: Array) -> void:
	var player: Dictionary = world.players[id]
	if not player["skull"].is_empty() and now >= player["skull_until"]:
		player["skull"] = ""
		events.append({"kind": "player", "id": id})
	if now >= player["next_regen"]:
		player["next_regen"] = now + REGEN_SECONDS
		var limits: Dictionary = world.player_stats(id)
		var before: Array = [player["health"], player["mana"]]
		var rate: float = REGEN_SECONDS / 10.0 * (RESTING_MULTIPLIER if resting(id, now) else 1.0)
		if _town_rest(id, limits, now, events):
			rate = REGEN_SECONDS / 10.0 * TOWN_REST_MULTIPLIER
		rate *= 1.0 + meal_bonus(id, now)
		player["health"] = mini(limits["health"], player["health"] + maxi(1, roundi(limits["regen"] * rate * healing_factor(id, now))))
		player["mana"] = mini(limits["mana"], player["mana"] + maxi(1, roundi(limits["mana"] * MANA_REGEN_FRACTION * rate)))
		if [player["health"], player["mana"]] != before:
			events.append({"kind": "player", "id": id})
	var target: int = player["target"]
	if target == 0:
		return
	if not hostile(id, target) or distance(player["cell"], creature(target)["cell"]) > TARGET_RANGE:
		player["target"] = 0
		events.append({"kind": "player", "id": id})
		return
	if now >= player["next_attack"] and in_reach(player["cell"], creature(target)["cell"], reach_of(id)):
		player["next_attack"] = now + Balance.ATTACK_SECONDS
		if reach_of(id) > 1:
			_missile(player["cell"], creature(target)["cell"], MISSILE_COLORS.get(attack_style(player["vocation"],
				player["equipment"]), Color.WHITE), events)
		_hit(id, target, 1.0, now, events)


## Starts, keeps, or ends a player's town rest; returns whether it boosts this regeneration tick.
func _town_rest(id: int, limits: Dictionary, now: float, events: Array) -> bool:
	var player: Dictionary = world.players[id]
	var in_town: bool = World.zone_at(player["cell"]).get("town", false)
	var missing: bool = player["health"] < limits["health"] or player["mana"] < limits["mana"]
	if player["town_rest"]:
		if in_town and missing:
			return true
		player["town_rest"] = false
		player["town_rest_ready"] = now + TOWN_REST_COOLDOWN
		events.append({"kind": "player", "id": id})
		return false
	if in_town and missing and now >= player["town_rest_ready"]:
		player["town_rest"] = true
		events.append({"kind": "message", "id": id, "text": "You rest in town and recover quickly."})
		return true
	return false


func resting(id: int, now: float) -> bool:
	return now - world.players[id].get("last_combat", -INF) >= RESTING_SECONDS


## Monsters sleep at home with nobody near: no target search or AI runs for them. A monster
## wakes when a player enters a nearby SLEEP_CHUNK, and stays awake while it fights or walks home.
const SLEEP_CHUNK: int = 16
## Chunks round a player whose monsters a tick visits (a monster strays at most Monsters.LEASH
## from home, under a chunk) and whose dormant camps spawn: well beyond the view and INTEREST.
const WAKE_REACH: int = 3
const WAKE_BUDGET: int = 4


func _index(id: int) -> void:
	var monster: Dictionary = world.monsters[id]
	var chunk: Vector2i = monster.get("home", monster.get("cell", Vector2i.ZERO)) / SLEEP_CHUNK
	if not _by_home.has(chunk):
		_by_home[chunk] = {}
	if not _by_home[chunk].has(id):
		_by_home[chunk][id] = true
		_indexed += 1
	_track_active(id)


func _unindex(id: int) -> void:
	_active.erase(id)
	var monster: Dictionary = world.monsters.get(id, {})
	var chunk: Vector2i = monster.get("home", monster.get("cell", Vector2i.ZERO)) / SLEEP_CHUNK
	if _by_home.has(chunk) and _by_home[chunk].has(id):
		_by_home[chunk].erase(id)
		_indexed -= 1
		if _by_home[chunk].is_empty():
			_by_home.erase(chunk)


func _track_active(id: int) -> void:
	var monster: Dictionary = world.monsters[id]
	if monster.get("target", 0) != 0 or monster.get("cell") != monster.get("home") or monster.get("engaged_at", -1.0) >= 0.0:
		_active[id] = true
	else:
		_active.erase(id)


## Keeps the index true to world.monsters when something added or removed monsters directly.
func _check_index() -> void:
	if _indexed == world.monsters.size():
		return
	_by_home.clear()
	_active.clear()
	_indexed = 0
	for id: int in world.monsters:
		_index(id)


## Monsters homed within WAKE_REACH chunks of a player or bot, and the active ones, oldest first
## (the order world.monsters keeps), so ticks and target choices stay deterministic.
func _near_players() -> Array:
	_check_index()
	var picked: Dictionary = _active.duplicate()
	var seen: Dictionary = {}
	for player: int in world.players:
		var centre: Vector2i = world.players[player]["cell"] / SLEEP_CHUNK
		for dy: int in range(-WAKE_REACH, WAKE_REACH + 1):
			for dx: int in range(-WAKE_REACH, WAKE_REACH + 1):
				var chunk: Vector2i = centre + Vector2i(dx, dy)
				if seen.has(chunk) or not _by_home.has(chunk):
					continue
				seen[chunk] = true
				picked.merge(_by_home[chunk])
	return _oldest_first(picked)


## Monsters that may stand within `radius` of `cell` (homed within reach, plus the active ones),
## oldest first: what bots scan instead of every monster. Callers still check the distance.
func monsters_near(cell: Vector2i, radius: int) -> Array:
	_check_index()
	var picked: Dictionary = _active.duplicate()
	var reach: int = ceili(float(radius + Monsters.LEASH) / SLEEP_CHUNK)
	var centre: Vector2i = cell / SLEEP_CHUNK
	for dy: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var chunk: Vector2i = centre + Vector2i(dx, dy)
			if _by_home.has(chunk):
				picked.merge(_by_home[chunk])
	return _oldest_first(picked)


## Monster ids count down from -1 as they spawn: descending is the order they were made.
static func _oldest_first(picked: Dictionary) -> Array:
	var ids: Array = picked.keys()
	ids.sort_custom(func(a: int, b: int) -> bool: return a > b)
	return ids


func _awake_chunks() -> Dictionary:
	var chunks: Dictionary = {}
	for id: int in world.players:
		var chunk: Vector2i = world.players[id]["cell"] / SLEEP_CHUNK
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				chunks[chunk + Vector2i(dx, dy)] = true
	return chunks


func _awake(monster: Dictionary, chunks: Dictionary) -> bool:
	return monster["target"] != 0 or monster["cell"] != monster["home"] or monster["engaged_at"] >= 0.0 \
		or chunks.has(monster["cell"] / SLEEP_CHUNK)


func _player_near(cell: Vector2i, radius: int) -> bool:
	for id: int in world.players:
		if distance(world.players[id]["cell"], cell) <= radius:
			return true
	return false


func _monster_tick(id: int, now: float, events: Array) -> void:
	var monster: Dictionary = world.monsters[id]
	var target: int = monster["target"]
	if target != 0 and not _can_chase(monster, target):
		# Dragged too far or into a town: give up, heal fully, and walk home untouchable.
		target = 0
		_leash_reset(monster)
		monster["returning"] = true
		events.append({"kind": "monster", "id": id, "movement": false})
	if target == 0 and not monster["returning"]:
		var nearest: int = Monsters.AGGRO_RANGE + 1
		for player: int in world.players:
			var gap: int = distance(world.players[player]["cell"], monster["cell"])
			if gap < nearest and _can_chase(monster, player):
				nearest = gap
				target = player
		if target != 0:
			monster["next_attack"] = maxf(monster["next_attack"], now + 1.0)
	monster["target"] = target
	if target != 0 and monster_def(id)["rank"] == "boss":
		_boss_tick(id, now, events)
		if not world.monsters.has(id) or not world.players.has(target):
			return
	if target != 0:
		var goal: Vector2i = world.players[target]["cell"]
		if in_reach(monster["cell"], goal, reach_of(id)):
			if now >= monster["next_attack"] and now >= monster["next_move"]:
				monster["next_attack"] = now + Balance.ATTACK_SECONDS
				var facing: Vector2i = facing_toward(monster["cell"], goal)
				if facing != monster["facing"]:
					monster["facing"] = facing
					events.append({"kind": "monster", "id": id, "movement": false})
				if reach_of(id) > 1:
					_missile(monster["cell"], goal, MISSILE_COLORS["monster"], events)
				_hit(id, target, 1.0, now, events)
		elif now >= monster["next_move"]:
			_monster_step(id, goal, now, events)
	elif monster["cell"] != monster["home"] and now >= monster["next_move"]:
		_monster_step(id, monster["home"], now, events)
	elif monster["cell"] == monster["home"] and (monster["returning"] or monster["engaged_at"] >= 0.0
			or monster["health"] < monster["max_health"]):
		_leash_reset(monster)
		monster["returning"] = false
		events.append({"kind": "monster", "id": id, "movement": false})


## Whether a monster may chase `player`: alive, outside every town (monsters never follow
## anyone into a safe zone), within LEASH of the monster's home, and not far out of sight.
func _can_chase(monster: Dictionary, player: int) -> bool:
	if not world.players.has(player):
		return false
	var cell: Vector2i = world.players[player]["cell"]
	var into_town: bool = World.zone_at(cell).get("town", false) and not World.zone_at(monster["home"]).get("town", false)
	return not into_town and distance(cell, monster["home"]) <= Monsters.LEASH \
		and distance(cell, monster["cell"]) <= Monsters.CHASE_RANGE and World.dungeon_at(cell) == World.dungeon_at(monster["home"])


## Forgets the fight: full health, no experience or trophy claims, and (for bosses) no timer.
func _leash_reset(monster: Dictionary) -> void:
	monster["health"] = monster["max_health"]
	monster["damage_by"].clear()
	monster["fought"].clear()
	_reset_boss(monster)


func wound_stacks(boss: int, player: int, now: float) -> int:
	var wound: Array = world.monsters[boss]["wounds"].get(player, [0, -INF])
	return wound[0] if now < wound[1] else 0


## Engage, raid-wide pulses, and enrage for a boss with a target; called every tick.
func _boss_tick(id: int, now: float, events: Array) -> void:
	var monster: Dictionary = world.monsters[id]
	var name: String = monster_def(id)["name"]
	if monster["engaged_at"] < 0.0:
		monster["engaged_at"] = now
		monster["next_pulse"] = now + PULSE_SECONDS
		_raid_message(id, "%s awakens! Defeat it within %d seconds before it enrages." % [name, roundi(Balance.ENRAGE_SECONDS)], events)
	if not monster["enraged"] and now - monster["engaged_at"] >= Balance.ENRAGE_SECONDS:
		monster["enraged"] = true
		_raid_message(id, "%s enrages!" % name, events)
		events.append({"kind": "monster", "id": id, "movement": false})
	if now >= monster["next_pulse"]:
		monster["next_pulse"] += PULSE_SECONDS
		var amount: int = pulse_damage(monster["level"]) * (roundi(ENRAGE_MULTIPLIER) if monster["enraged"] else 1)
		_area(monster["cell"], 2, Color("#b06aff"), events)
		for player: int in world.players.keys():
			if world.players.has(player) and distance(world.players[player]["cell"], monster["cell"]) <= PULSE_RADIUS:
				_damage(id, player, amount, "damage", now, events)


## A pulse's damage to each player: the intended raid shares BOSS_HEALING_PRESSURE full healers'
## healing per second.
static func pulse_damage(level: int) -> int:
	var raid: int = 0
	for vocation: String in Balance.RAID:
		raid += Balance.RAID[vocation]
	var healer: float = Balance.base_stats(level, "druid")["healing"]
	return roundi(Balance.BOSS_HEALING_PRESSURE * healer * PULSE_SECONDS / raid)


func _raid_message(boss: int, text: String, events: Array) -> void:
	for player: int in world.players:
		if distance(world.players[player]["cell"], world.monsters[boss]["cell"]) <= SHARE_RANGE:
			events.append({"kind": "message", "id": player, "text": text})


## A boss walking home forgets the fight: no timer, wounds, or enrage.
func _reset_boss(monster: Dictionary) -> void:
	monster["engaged_at"] = -1.0
	monster["next_pulse"] = INF
	monster["enraged"] = false
	monster["wounds"].clear()


## World.occupied_cells as counts, built once per moment (see _taken).
func _occupancy(now: float) -> Dictionary:
	if _taken_at != now:
		_taken.clear()
		for group: Dictionary in [world.players, world.monsters]:
			for id: int in group:
				var body: Dictionary = group[id]
				_taken[body["cell"]] = _taken.get(body["cell"], 0) + 1
				if now < body["next_move"]:
					_taken[body["from"]] = _taken.get(body["from"], 0) + 1
		_taken_at = now
	return _taken


## Roots ("root": no steps) or slows ("slow": World.SLOWED_STEP times slower) a player or monster
## for `seconds`. Bosses shrug it off; a player who was just held is immune for RESTRAIN_IMMUNITY.
func restrain(id: int, kind: String, seconds: float, now: float, events: Array) -> void:
	var held: Dictionary = creature(id)
	if id < 0 and monster_def(id)["rank"] == "boss":
		return
	if id > 0 and now < held.get("restrain_immune_until", -INF):
		events.append({"kind": "message", "id": id, "text": "You shake off the %s." % ("roots" if kind == "root" else "slowing")})
		return
	held["rooted_until" if kind == "root" else "slowed_until"] = now + seconds
	if id > 0:
		held["restrain_immune_until"] = now + seconds + RESTRAIN_IMMUNITY
		events.append({"kind": "message", "id": id, "text": "You are %s for %s s." % [
			"rooted in place" if kind == "root" else "slowed", Spells.number(seconds)]})
	events.append({"kind": "player" if id > 0 else "monster", "id": id, "movement": false})


func _monster_step(id: int, goal: Vector2i, now: float, events: Array) -> void:
	var monster: Dictionary = world.monsters[id]
	if now < monster.get("rooted_until", -INF):
		return
	var home: Vector2i = monster["home"]
	var taken: Dictionary = _occupancy(now)
	var own: Dictionary = {monster["cell"]: 1}
	if now < monster["next_move"]:
		own[monster["from"]] = own.get(monster["from"], 0) + 1
	var home_zoned: bool = not World.zone_at(home).is_empty()
	var step: Vector2i = path_step(monster["cell"], goal, func(cell: Vector2i) -> bool:
		return taken.get(cell, 0) > own.get(cell, 0) or distance(cell, home) > Monsters.LEASH \
			or World.zone_at(cell).is_empty() == home_zoned)
	# Chasing is quicker than a player's step (Balance.chase_seconds); idling and going home use the monster's own pace.
	var hunted: int = monster["target"]
	var pace: float = monster["step"]
	if hunted > 0 and world.players.has(hunted):
		pace = minf(pace, Balance.chase_seconds(monster["level"], world.players[hunted]["level"]))
	if now < monster.get("slowed_until", -INF):
		pace *= World.SLOWED_STEP
	# Steps happen on ticks; carry the leftover so a steady chase keeps its real pace between ticks.
	var since: float = now - monster["next_move"]
	monster["next_move"] = (monster["next_move"] if since >= 0.0 and since < pace else now) + pace
	monster["last_step"] = pace
	if step == Vector2i.ZERO:
		return
	# The old tile stays reserved (as "from") until the step ends; the new one is taken now.
	taken[monster["cell"] + step] = taken.get(monster["cell"] + step, 0) + 1
	monster["from"] = monster["cell"]
	monster["cell"] += step
	monster["facing"] = step
	events.append({"kind": "monster", "id": id, "movement": true})
