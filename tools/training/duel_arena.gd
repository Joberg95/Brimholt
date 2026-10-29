extends RefCounted
## One PvP duel on the real rules, for training the bots' combat policy (duel_env.gd) and for
## measuring it (tools/testing/duel_eval.gd). Every episode builds a fresh World, Combat, and
## Bots with no monsters, and puts two same-level bots in vendor gear (Bots.gear) a few tiles
## apart somewhere in a PvP zone: the learner and a scripted "pvp" bot (Bots.engage and
## use_resources). The learner is driven either from outside (advance(move, act), the trainer's
## choices through PvpBrain.apply) or, with a policy, by the bots' own runtime (Bots.run_policy
## inside the behavior tree, as in the game).
##
## An episode ends when either bot dies, the learner leaves the PvP zones, or EPISODE_SECONDS
## pass. Reward per step: damage dealt as a share of the foe's health, minus damage taken as a
## share of the learner's, +KILL_REWARD for a win, -KILL_REWARD for a loss, -FLED_PENALTY for
## leaving the PvP zones, and -STEP_PENALTY every step.

const World = preload("res://game/core/world.gd")
const WorldMap = preload("res://game/world_map/world_map.gd")
const Combat = preload("res://game/core/combat.gd")
const Bots = preload("res://game/core/bots.gd")
const PvpBrain = preload("res://game/core/ai/pvp_brain.gd")
const PolicyNet = preload("res://game/core/ai/policy_net.gd")

const STEP_SECONDS: float = Bots.THINK_SECONDS
const EPISODE_SECONDS: float = 150.0
const MIN_LEVEL: int = 10
const MAX_LEVEL: int = 50
const MAX_DISTANCE: int = 6
const KILL_REWARD: float = 1.0
const FLED_PENALTY: float = 0.5
const STEP_PENALTY: float = 0.001
const START: float = 1.0
## A bot that moved further than this in one tick died and woke in a temple.
const JUMP: int = 2

var rng := RandomNumberGenerator.new()
var world: World
var combat: Combat
var bots: Bots
var learner: int = 0
var foe: int = 0
var now: float = START
## "" while the duel goes on, then "win", "loss", "draw", or "fled" (from the learner's side).
var result: String = ""
## The episode's draw: {learner, foe (vocations), level, distance}.
var setup: Dictionary = {}
## Damage each side dealt this episode (for evaluation summaries).
var dealt: int = 0
var taken: int = 0
## Walkable PvP-zone cells, found once per run.
static var _cells: Array[Vector2i] = []


## Starts a new duel. Options override the random draw: "learner" and "foe" (vocations), "level",
## "distance"; "policy" (a PolicyNet) makes the bots' runtime drive the learner at "difficulty",
## and "scripted" makes the learner fight like its foe (the evaluation baseline). "opponent" (a
## PolicyNet, an earlier snapshot for self-play) drives the foe instead of the scripted fight,
## while the learner stays driven from outside. "rival" (a PolicyNet, with "policy") drives the foe
## through the bots' runtime as well: policy against policy, for comparing two models.
func start(options: Dictionary = {}) -> void:
	world = World.new()
	world.monsters.clear()
	combat = Combat.new(world, rng.randi() | 1)
	bots = Bots.new(world, combat)
	var opponent: PolicyNet = options.get("opponent", null) as PolicyNet
	var rival: PolicyNet = options.get("rival", null) as PolicyNet
	bots.policy = opponent if opponent != null else options.get("policy", null) as PolicyNet
	bots.difficulty = String(options.get("difficulty", "hard"))
	bots.rng.seed = rng.randi()
	now = START
	result = ""
	dealt = 0
	taken = 0
	setup = {
		"learner": String(options.get("learner", PvpBrain.VOCATIONS[rng.randi() % PvpBrain.VOCATIONS.size()])),
		"foe": String(options.get("foe", PvpBrain.VOCATIONS[rng.randi() % PvpBrain.VOCATIONS.size()])),
		"level": int(options.get("level", rng.randi_range(MIN_LEVEL, MAX_LEVEL))),
		"distance": int(options.get("distance", rng.randi_range(1, MAX_DISTANCE))),
		"opponent": "policy" if opponent != null or rival != null else "scripted",
	}
	var cells: Array[Vector2i] = _pair(setup["distance"])
	learner = bots.add(setup["learner"], setup["level"], "pvp", cells[0], now)["id"]
	foe = bots.add(setup["foe"], setup["level"], "pvp", cells[1], now)["id"]
	bots.bots[learner]["external"] = (opponent != null or bots.policy == null) and not options.get("scripted", false)
	bots.bots[foe]["scripted"] = opponent == null and rival == null
	if rival != null:
		bots.bots[foe]["net"] = rival
	for id: int in [learner, foe]:
		bots.bots[id]["post"] = cells[0 if id == learner else 1]
		bots.restore(id, now, bots.bots[id]["post"])
	if bots.bots[learner]["external"]:
		_aim()


## The fight from the learner's side (PvpBrain.observe).
func observe() -> PackedFloat32Array:
	return PvpBrain.observe(world, combat, learner, foe, now)


## One learner turn (STEP_SECONDS): its move and act (ignored unless driven from outside), then the
## world ticks. Returns the step's reward.
func advance(move: int = 0, act: int = 0) -> float:
	if not result.is_empty():
		return 0.0
	var events: Array = []
	var cells: Array[Vector2i] = [world.players[learner]["cell"], world.players[foe]["cell"]]
	if bots.bots[learner]["external"]:
		_aim()
		PvpBrain.apply(world, combat, learner, foe, move, act, now, events)
	var ticks: int = roundi(STEP_SECONDS / Combat.TICK_SECONDS)
	for _tick: int in ticks:
		now += Combat.TICK_SECONDS
		events.append_array(bots.tick(now))
		events.append_array(combat.tick(now))
		if _ended(cells):
			break
		cells = [world.players[learner]["cell"], world.players[foe]["cell"]]
	var reward: float = -STEP_PENALTY
	var foe_health: float = maxf(1.0, world.player_stats(foe)["health"])
	var own_health: float = maxf(1.0, world.player_stats(learner)["health"])
	for event: Dictionary in events:
		if event["kind"] != "hit" or not event["style"] in ["damage", "critical"]:
			continue
		if event["target"] == foe and event.get("source", 0) == learner:
			dealt += event["amount"]
			reward += event["amount"] / foe_health
		elif event["target"] == learner and event.get("source", 0) == foe:
			taken += event["amount"]
			reward -= event["amount"] / own_health
	if result.is_empty() and now - START >= EPISODE_SECONDS:
		result = "draw"
	match result:
		"win":
			reward += KILL_REWARD
		"loss":
			reward -= KILL_REWARD
		"fled":
			reward -= FLED_PENALTY
	return reward


func finished() -> bool:
	return not result.is_empty()


## Sets the result when someone died (a jump to a temple) or the learner left the PvP zones.
func _ended(before: Array[Vector2i]) -> bool:
	if Combat.distance(world.players[foe]["cell"], before[1]) > JUMP:
		result = "win"
	elif Combat.distance(world.players[learner]["cell"], before[0]) > JUMP:
		result = "loss"
	elif not WorldMap.zone_at(world.players[learner]["cell"]).get("pvp", false):
		result = "fled"
	return not result.is_empty()


## An external learner always targets its foe (a 1v1 has no one else to choose).
func _aim() -> void:
	if world.players[learner]["target"] != foe and combat.hostile(learner, foe):
		combat.set_target(learner, foe, now)


## Two walkable PvP-zone cells `distance` apart (Chebyshev), on the same side of every dungeon border.
func _pair(distance: int) -> Array[Vector2i]:
	if _cells.is_empty():
		for zone: Dictionary in WorldMap.ZONES:
			if not zone["pvp"]:
				continue
			for y: int in range(zone["rect"].position.y, zone["rect"].end.y):
				for x: int in range(zone["rect"].position.x, zone["rect"].end.x):
					var cell := Vector2i(x, y)
					if _open(cell):
						_cells.append(cell)
	for _try: int in 200:
		var first: Vector2i = _cells[rng.randi() % _cells.size()]
		var offset := Vector2i(rng.randi_range(-distance, distance), rng.randi_range(-distance, distance))
		if maxi(absi(offset.x), absi(offset.y)) != distance:
			offset[rng.randi() % 2] = distance * (1 if rng.randf() < 0.5 else -1)
		var second: Vector2i = first + offset
		if _open(second) and WorldMap.dungeon_at(first) == WorldMap.dungeon_at(second):
			return [first, second]
	return [_cells[0], _cells[0] + Vector2i.RIGHT]


static func _open(cell: Vector2i) -> bool:
	return WorldMap.walkable(cell) and WorldMap.zone_at(cell).get("pvp", false) and WorldMap.terrain(cell) not in ["v", "^"]
