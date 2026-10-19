extends RefCounted
## What a bot sees and can do in a fight against a player, shared by the trained PvP policy
## (game/core/ai/policy_net.gd, run by Bots.run_policy) and its training arena
## (tools/training/duel_env.gd), so both always agree on the encoding.
##
## observe() turns the fight into OBS_SIZE numbers in [-1, 1]; a policy answers with one choice
## per head (HEADS): a move (stay, a cardinal step, chase along a path, back off) and an act
## (nothing, a spell class, or a potion). apply() carries the choice out through the real rules
## only (World.move, Combat.cast, Combat.drink), so cooldowns, mana, reach, skulls, and PvP
## zones hold for the policy as for everyone; a choice the rules refuse simply does nothing.

const World = preload("res://game/core/world.gd")
const Combat = preload("res://game/core/combat.gd")
const Spells = preload("res://game/data/spells.gd")
const Balance = preload("res://game/data/balance.gd")

const VOCATIONS: Array[String] = ["knight", "paladin", "sorcerer", "druid"]
## Move head: stay, the four cardinal steps, then chase (a path step toward the foe) and retreat.
const STEPS: Array[Vector2i] = [Vector2i.ZERO, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const MOVE_CHASE: int = 5
const MOVE_RETREAT: int = 6
const MOVES: int = 7
## Act head: spell classes (the strongest ready spell of that class) and potions.
const ACTS: Array[String] = ["none", "attack", "control", "heal", "support", "health_potion", "mana_potion"]
const SPELL_CLASSES: Array[String] = ["attack", "control", "heal", "support"]
## Head order and sizes, as the policy file lists them.
const HEADS: Dictionary = {"act": 7, "move": 7}
## Offsets and distances are divided by SPAN tiles; the grid covers GRID_RADIUS tiles each way.
const SPAN: float = 8.0
const GRID_RADIUS: int = 3
const SELF_SIZE: int = 15
const FOE_SIZE: int = 13
const RELATION_SIZE: int = 6
const READY_SIZE: int = 10
const GRID_SIZE: int = (2 * GRID_RADIUS + 1) * (2 * GRID_RADIUS + 1)
const NOWHERE := Vector2i(-100000, -100000)
const OBS_SIZE: int = SELF_SIZE + FOE_SIZE + RELATION_SIZE + READY_SIZE + GRID_SIZE


## The class a spell falls in for the act head, or "" for spells a duel has no use for (taunts).
static func spell_class(spell: String) -> String:
	var definition: Dictionary = Spells.SPELLS[spell]
	match definition["kind"]:
		"target", "area_self", "area_target", "execute":
			return "attack"
		"root", "slow":
			return "control"
		"heal_self", "heal_area":
			return "heal"
		"buff_self":
			return "heal" if definition.get("buff", "") == "ward" else "support"
		"buff_area", "mark", "wall":
			return "support"
	return ""


## The strongest spell of `kind` that `id` could cast at `foe` now: known, off its own and its
## group's cooldown, affordable, and (for spells that need one) with the foe in range. "" if none.
static func ready_spell(world: World, id: int, foe: int, kind: String, now: float) -> String:
	var player: Dictionary = world.players[id]
	var max_mana: int = world.player_stats(id)["mana"]
	var foe_cell: Vector2i = world.players[foe]["cell"] if world.players.has(foe) else NOWHERE
	var best: String = ""
	var best_power: float = -INF
	for spell: String in Spells.for_vocation(player["vocation"]):
		var definition: Dictionary = Spells.SPELLS[spell]
		if definition["level"] > player["level"] or spell_class(spell) != kind or definition["power"] <= best_power:
			continue
		if now < player["cooldowns"].get(spell, -INF) or now < player["groups"].get(definition["group"], -INF):
			continue
		if player["mana"] < maxi(1, roundi(max_mana * definition["mana"])):
			continue
		match definition["kind"]:
			"target", "area_target", "root", "slow", "mark", "execute":
				if not Combat.in_reach(player["cell"], foe_cell, definition.get("range", 1)):
					continue
			"area_self":
				if Combat.distance(player["cell"], foe_cell) > definition["radius"]:
					continue
		best = spell
		best_power = definition["power"]
	return best


## The backpack index of a potion of `kind` whose cooldown is over, else -1.
static func ready_potion(world: World, id: int, kind: String, now: float) -> int:
	var player: Dictionary = world.players[id]
	if now < player["cooldowns"].get(Combat.potion_timer(kind), -INF):
		return -1
	return player["backpack"].find_custom(func(entry: String) -> bool: return World.kind_of(entry) == kind)


## The fight from `id`'s side against `foe`, as OBS_SIZE numbers in [-1, 1].
static func observe(world: World, combat: Combat, id: int, foe: int, now: float) -> PackedFloat32Array:
	var obs := PackedFloat32Array()
	obs.resize(OBS_SIZE)
	var at: int = 0
	var me: Dictionary = world.players[id]
	at = _body(obs, at, world, combat, id, now)
	obs[at] = 1.0 if World.zone_at(me["cell"]).get("pvp", false) else 0.0
	obs[at + 1] = 1.0 if me["skull"] == "white" else 0.0
	obs[at + 2] = 1.0 if me["skull"] == "red" else 0.0
	obs[at + 3] = 1.0 if now >= me["next_move"] else 0.0
	at += 4
	var there: bool = foe != 0 and world.players.has(foe)
	if there:
		at = _body(obs, at, world, combat, foe, now)
		var other: Dictionary = world.players[foe]
		obs[at] = clampf((other["level"] - me["level"]) / 10.0, -1.0, 1.0)
		obs[at + 1] = 1.0 if other["target"] == id else 0.0
		at += 2
		var offset: Vector2i = other["cell"] - me["cell"]
		obs[at] = clampf(offset.x / SPAN, -1.0, 1.0)
		obs[at + 1] = clampf(offset.y / SPAN, -1.0, 1.0)
		obs[at + 2] = clampf(Combat.distance(me["cell"], other["cell"]) / SPAN, 0.0, 1.0)
		obs[at + 3] = 1.0 if Combat.in_reach(me["cell"], other["cell"], combat.reach_of(id)) else 0.0
		obs[at + 4] = 1.0 if Combat.in_reach(other["cell"], me["cell"], combat.reach_of(foe)) else 0.0
		obs[at + 5] = 1.0 if Combat.line_of_sight(me["cell"], other["cell"]) else 0.0
		at += RELATION_SIZE
	else:
		at += FOE_SIZE + RELATION_SIZE
	for kind: String in SPELL_CLASSES:
		obs[at] = 1.0 if there and not ready_spell(world, id, foe, kind, now).is_empty() else 0.0
		at += 1
	for group: String in ["attack", "healing"]:
		obs[at] = clampf((me["groups"].get(group, -INF) - now) / Spells.GROUP_SECONDS[group], 0.0, 1.0)
		at += 1
	for potion: String in ["health_potion", "mana_potion"]:
		obs[at] = 1.0 if ready_potion(world, id, potion, now) >= 0 else 0.0
		obs[at + 1] = 1.0 if me["backpack"].any(func(entry: String) -> bool: return World.kind_of(entry) == potion) else 0.0
		at += 2
	for dy: int in range(-GRID_RADIUS, GRID_RADIUS + 1):
		for dx: int in range(-GRID_RADIUS, GRID_RADIUS + 1):
			var cell: Vector2i = me["cell"] + Vector2i(dx, dy)
			obs[at] = 1.0 if World.walkable(cell) and not world.walled(cell, now) and not _blocked(cell) else 0.0
			at += 1
	assert(at == OBS_SIZE)
	return obs


## Health and mana shares, level, reach, class, and holds of one fighter (11 numbers).
static func _body(obs: PackedFloat32Array, at: int, world: World, combat: Combat, id: int, now: float) -> int:
	var body: Dictionary = world.players[id]
	var stats: Dictionary = world.player_stats(id)
	obs[at] = clampf(float(body["health"]) / maxf(1.0, stats["health"]), 0.0, 1.0)
	obs[at + 1] = clampf(float(body["mana"]) / maxf(1.0, stats["mana"]), 0.0, 1.0)
	obs[at + 2] = body["level"] / float(Balance.MAX_LEVEL)
	obs[at + 3] = combat.reach_of(id) / 6.0
	for index: int in VOCATIONS.size():
		obs[at + 4 + index] = 1.0 if body["vocation"] == VOCATIONS[index] else 0.0
	obs[at + 8] = 1.0 if now < body.get("rooted_until", -INF) else 0.0
	obs[at + 9] = 1.0 if now < body.get("slowed_until", -INF) else 0.0
	obs[at + 10] = clampf(maxf(0.0, body["next_move"] - now), 0.0, 1.0)
	return at + 11


## Carries out a choice (indices into the heads) for `id` against `foe`. Returns whether the
## rules accepted anything; events collect like Combat.tick's.
static func apply(world: World, combat: Combat, id: int, foe: int, move: int, act: int, now: float, events: Array) -> bool:
	if not world.players.has(id):
		return false
	var acted: bool = false
	if act > 0 and act < ACTS.size():
		var kind: String = ACTS[act]
		if kind in SPELL_CLASSES:
			var spell: String = ready_spell(world, id, foe, kind, now)
			if not spell.is_empty():
				var cast: Dictionary = combat.cast(id, spell, now)
				acted = cast["ok"]
				events.append_array(cast["events"])
		else:
			var index: int = ready_potion(world, id, kind, now)
			if index >= 0:
				var drunk: Dictionary = combat.drink(id, index, now)
				acted = drunk["ok"]
				events.append_array(drunk["events"])
	var direction := Vector2i.ZERO
	var cell: Vector2i = world.players[id]["cell"]
	if move > 0 and move < STEPS.size():
		direction = STEPS[move]
	elif (move == MOVE_CHASE or move == MOVE_RETREAT) and world.players.has(foe):
		var there: Vector2i = world.players[foe]["cell"]
		if move == MOVE_CHASE:
			direction = Combat.path_step(cell, there, _blocked)
		else:
			direction = Combat.step_toward(cell, cell * 2 - there, _blocked)
	if direction != Vector2i.ZERO and not _blocked(cell + direction) and world.move(id, direction, now)["ok"]:
		events.append({"kind": "player", "id": id, "movement": true})
		acted = true
	return acted


## Stairways block a bot's steps (bots never take stairs on their own), as in Bots.
static func _blocked(cell: Vector2i) -> bool:
	return World.terrain(cell) in ["v", "^"]
