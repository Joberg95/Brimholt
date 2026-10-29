extends SceneTree
## The systems of plan 48, each tested alone: a system gets only the components and stand-ins it
## reads, never the whole world. So far: regeneration (game/core/systems/regen.gd).
##
##   godot --headless --path . --script res://tests/unit/systems_test.gd

const Store = preload("res://game/core/ecs/store.gd")
const Regen = preload("res://game/core/components/regen.gd")
const RegenSystem = preload("res://game/core/systems/regen.gd")
const WorldMap = preload("res://game/world_map/world_map.gd")

var checks: int = 0
var failures: int = 0


## What the regen system reads of the world: player records, their limits, and the component store.
class FakeWorld:
	extends RefCounted
	var players: Dictionary = {}
	var store := Store.new()
	var limits: Dictionary = {"health": 100, "mana": 50, "regen": 10}

	func _init() -> void:
		store.declare(RegenSystem.COMPONENT, "regen")

	func add(id: int, cell: Vector2i) -> void:
		players[id] = {"health": 1, "mana": 0, "cell": cell}
		store.put(id, RegenSystem.COMPONENT, Regen.new(0.0))

	func player_stats(_id: int) -> Dictionary:
		return limits


## What it reads of combat: meals and PvP healing.
class FakeCombat:
	extends RefCounted
	var meal: float = 0.0

	func meal_bonus(_id: int, _now: float) -> float:
		return meal

	func healing_factor(_id: int, _now: float) -> float:
		return 1.0


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _initialize() -> void:
	_regen_checks()
	print("BRIMHOLT_SYSTEMS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _regen_checks() -> void:
	var world := FakeWorld.new()
	var combat := FakeCombat.new()
	var regen := RegenSystem.new(world, combat)
	var outside: Vector2i = _outside_town()
	world.add(1, outside)
	world.players[1]["last_combat"] = 0.0
	var events: Array = []
	regen.tick_player(1, 1.0, events)
	var gain: int = world.players[1]["health"] - 1
	check(gain > 0 and world.players[1]["mana"] > 0 and events == [{"kind": "player", "id": 1}],
		"health and mana regenerate, and the player is published")
	check(is_equal_approx(regen.of(1).next_regen, 1.0 + RegenSystem.REGEN_SECONDS), "the next regeneration waits REGEN_SECONDS")
	events.clear()
	regen.tick_player(1, 2.0, events)
	check(world.players[1]["health"] == 1 + gain and events.is_empty(), "nothing happens before it is time")
	world.players[1]["health"] = 1
	regen.of(1).next_regen = 0.0
	regen.tick_player(1, RegenSystem.RESTING_SECONDS + 1.0, [])
	check(world.players[1]["health"] - 1 > gain, "resting out of combat regenerates faster")
	world.players[1]["health"] = 1
	regen.of(1).next_regen = 0.0
	combat.meal = 1.0
	regen.tick_player(1, 1.0, [])
	check(world.players[1]["health"] - 1 > gain, "a meal speeds regeneration")
	combat.meal = 0.0
	# A town rest: in a town and hurt, much faster, announced once; it ends when full.
	world.add(2, WorldMap.SPAWNS[0])
	world.players[2]["last_combat"] = 0.0
	events.clear()
	regen.tick_player(2, 1.0, events)
	check(regen.of(2).town_rest and world.players[2]["health"] - 1 >= gain * 3
		and events.any(func(event: Dictionary) -> bool: return event["kind"] == "message"), "a town rest starts, announced, and heals faster")
	world.players[2]["health"] = 100
	world.players[2]["mana"] = 50
	regen.of(2).next_regen = 0.0
	regen.tick_player(2, 5.0, [])
	check(not regen.of(2).town_rest and is_equal_approx(regen.of(2).town_rest_ready, 5.0 + RegenSystem.TOWN_REST_COOLDOWN),
		"a full player's town rest ends and starts its cooldown")
	world.players[2]["health"] = 1
	regen.of(2).next_regen = 0.0
	regen.tick_player(2, 10.0, [])
	check(not regen.of(2).town_rest, "a town rest waits for its cooldown")


static func _outside_town() -> Vector2i:
	for dy: int in range(0, 60):
		var cell: Vector2i = WorldMap.SPAWNS[0] + Vector2i(0, dy)
		if WorldMap.walkable(cell) and WorldMap.zone_at(cell).is_empty():
			return cell
	return Vector2i(-1, -1)
