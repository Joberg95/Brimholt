extends SceneTree
## The systems of plan 48, each tested alone: a system gets only the components and stand-ins it
## reads, never the whole world: regeneration, the bank (economy), and professions (game/core/systems/).
##
##   godot --headless --path . --script res://tests/unit/systems_test.gd

const Store = preload("res://game/core/ecs/store.gd")
const Regen = preload("res://game/core/components/regen.gd")
const RegenSystem = preload("res://game/core/systems/regen.gd")
const WorldMap = preload("res://game/world_map/world_map.gd")
const Bank = preload("res://game/core/components/bank.gd")
const Economy = preload("res://game/core/systems/economy.gd")
const Events = preload("res://game/core/ecs/events.gd")
const ProfessionState = preload("res://game/core/components/professions.gd")
const ProfessionsSystem = preload("res://game/core/systems/professions.gd")
const Professions = preload("res://game/data/professions.gd")

var checks: int = 0
var failures: int = 0


## What the regen system reads of the world: player records, their limits, and the component store.
class FakeWorld:
	extends RefCounted
	var players: Dictionary = {}
	var store := Store.new()
	var bus := Events.new()
	var limits: Dictionary = {"health": 100, "mana": 50, "regen": 10}

	func _init() -> void:
		store.declare(RegenSystem.COMPONENT, "regen")
		store.declare(Economy.COMPONENT, "economy")
		store.declare(ProfessionsSystem.COMPONENT, "professions")

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
	_bank_checks()
	_professions_checks()
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


func _bank_checks() -> void:
	var world := FakeWorld.new()
	var economy := Economy.new(world)
	var banker: String = ""
	for id: String in WorldMap.TOWNSFOLK:
		if WorldMap.TOWNSFOLK[id]["role"] == "banker":
			banker = id
	var at: Vector2i = WorldMap.TOWNSFOLK[banker]["cell"]
	var cell: Vector2i = at
	for dy: int in range(-2, 3):
		for dx: int in range(-2, 3):
			var spot: Vector2i = at + Vector2i(dx, dy)
			if cell == at and WorldMap.walkable(spot) and WorldMap.same_room(spot, at):
				cell = spot
	world.players[1] = {"cell": cell, "gold": 100, "next_item": 0.0}
	world.store.put(1, Economy.COMPONENT, Bank.new())
	check(economy.bank(1, banker, "deposit", 60, 1.0)["ok"] and economy.account_of(1).gold == 60 and world.players[1]["gold"] == 40,
		"a deposit moves gold from the purse to the account")
	check(not economy.bank(1, banker, "withdraw", 61, 2.0)["ok"] and economy.account_of(1).gold == 60, "no overdraft")
	check(economy.bank(1, banker, "withdraw", 10, 3.0)["message"].ends_with("Balance: 50 gold.")
		and world.players[1]["gold"] == 50, "a withdrawal reports the balance")
	check(not economy.bank(1, banker, "deposit", 1, 3.01)["ok"], "the item cooldown applies")
	world.players[1]["cell"] = cell + Vector2i(0, 20)
	check(economy.bank(1, banker, "deposit", 1, 9.0)["reason"] == "Walk closer to a banker", "only beside the banker")


func _professions_checks() -> void:
	var world := FakeWorld.new()
	var professions := ProfessionsSystem.new(world, 5)
	var vein: Vector2i = Vector2i(-1, -1)
	for cell: Vector2i in ProfessionsSystem.ORES:
		if ProfessionsSystem.ORES[cell] == 0 and WorldMap.walkable(cell + Vector2i.DOWN):
			vein = cell
			break
	var stand: Vector2i = vein + Vector2i.DOWN
	var backpack: Array = []
	backpack.resize(8)
	backpack.fill("")
	world.players[1] = {"cell": stand, "health": 10, "backpack": backpack, "facing": Vector2i.DOWN}
	world.store.put(1, ProfessionsSystem.COMPONENT, ProfessionState.new(0.0))
	check(professions.start_gather(1, vein, 1.0)["ok"] and not professions.profile(1).gathering.is_empty()
		and world.players[1]["facing"] == Vector2i.UP, "gathering starts, facing the node")
	check(professions.tick(1.0 + Professions.GATHER_SECONDS - 0.01).is_empty(), "the work takes GATHER_SECONDS")
	professions.tick(1.0 + Professions.GATHER_SECONDS)
	check(backpack[0].begins_with("copper_ore") and professions.profile(1).gathering.is_empty()
		and int(professions.profile(1).skills["mining"][1]) > 0 and professions.worked(vein, 5.0),
		"finished work yields ore, trains mining, and the vein regrows")
	world.players[1]["cell"] = stand
	check(professions.start_gather(1, vein, 1.0 + Professions.GATHER_SECONDS + Professions.REGROW_SECONDS)["ok"], "a regrown vein can be worked again")
	world.bus.raise("moved", {"id": 1})
	world.bus.drain()
	check(professions.profile(1).gathering.is_empty(), "a moved event cancels the work")
	var skills: Dictionary = {}
	check(ProfessionsSystem.train(skills, "fishing", Professions.experience_to_next(1)).contains("Fishing rose to 2")
		and skills["fishing"] == [2, 0], "experience raises a skill")


static func _outside_town() -> Vector2i:
	for dy: int in range(0, 60):
		var cell: Vector2i = WorldMap.SPAWNS[0] + Vector2i(0, dy)
		if WorldMap.walkable(cell) and WorldMap.zone_at(cell).is_empty():
			return cell
	return Vector2i(-1, -1)
