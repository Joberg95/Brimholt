extends SceneTree
## The ECS core (plan 48 step 1): entity ids, component storage and ownership, event order, and the
## system order. Builds only the pieces it tests, never the world.
##
##   godot --headless --path . --script res://tests/unit/ecs_test.gd

const Entities = preload("res://game/core/ecs/entities.gd")
const Store = preload("res://game/core/ecs/store.gd")
const Events = preload("res://game/core/ecs/events.gd")
const Scheduler = preload("res://game/core/ecs/scheduler.gd")

var checks: int = 0
var failures: int = 0


## A component record for the tests.
class Health:
	extends RefCounted
	var value: int = 0

	func _init(start: int) -> void:
		value = start


## A system that logs its ticks and, on its first tick, raises an event another handler answers.
class Recorder:
	extends RefCounted
	var system_name: String
	var trail: Array[String]
	var bus: Events

	func _init(called: String, shared: Array[String], events: Events) -> void:
		system_name = called
		trail = shared
		bus = events

	func tick(now: float) -> void:
		trail.append("%s@%d" % [system_name, int(now)])
		if system_name == "first":
			bus.raise("damaged", {"by": system_name})


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _initialize() -> void:
	_entity_checks()
	_store_checks()
	_event_checks()
	_scheduler_checks()
	print("BRIMHOLT_ECS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _entity_checks() -> void:
	var entities := Entities.new()
	var first: int = entities.create("monster")
	var second: int = entities.create("monster")
	check(first >= Entities.FIRST_ID and second == first + 1, "created ids rise from FIRST_ID")
	check(entities.create("dragon") == 0, "an unknown kind gets no id")
	check(entities.claim(7, "player") and entities.kind_of(7) == "player", "a player keeps its peer id")
	check(not entities.claim(7, "player") and not entities.claim(0, "player") and not entities.claim(9, "nope"),
		"a taken, non-positive, or unknown claim is refused")
	entities.destroy(first)
	check(not entities.exists(first) and entities.kind_of(first) == "", "a destroyed entity is gone")
	check(entities.create("monster") == second + 1, "ids are never reused")
	check(entities.of_kind("monster") == [second, second + 1] and entities.count() == 3, "entities listed by kind in creation order")


func _store_checks() -> void:
	var store := Store.new()
	check(store.declare("health", "regen") and not store.declare("health", "combat"), "a component is declared once")
	check(store.owner_of("health") == "regen" and store.owners() == {"health": "regen"}, "each component has one owner")
	check(store.declare("position", "movement"), "a second component")
	store.put(5, "health", Health.new(30))
	store.put(3, "health", Health.new(10))
	store.put(3, "position", Health.new(1))
	check((store.get_record(5, "health") as Health).value == 30, "a record is stored by entity id")
	check(store.get_record(9, "health") == null and store.get_record(5, "missing") == null, "a missing record reads as null")
	check(store.ids_with("health") == [5, 3], "ids listed in the order their records were added")
	check(store.ids_with_all(["health", "position"]) == [3], "ids with every listed component")
	store.put(5, "health", Health.new(31))
	check((store.get_record(5, "health") as Health).value == 31 and store.ids_with("health") == [5, 3],
		"replacing a record keeps its place")
	store.remove_all(3)
	check(not store.has_record(3, "health") and not store.has_record(3, "position"), "a destroyed entity loses every record")


func _event_checks() -> void:
	var bus := Events.new()
	var seen: Array[String] = []
	bus.subscribe("damaged", func(event: Dictionary) -> void:
		seen.append("damaged:%s" % event["amount"])
		if event["amount"] == 1:
			bus.raise("died", {"who": 4}))
	bus.subscribe("died", func(event: Dictionary) -> void: seen.append("died:%s" % event["who"]))
	bus.subscribe("damaged", func(_event: Dictionary) -> void: seen.append("second handler"))
	bus.raise("damaged", {"amount": 1})
	bus.raise("damaged", {"amount": 2})
	check(bus.pending() == 2 and seen.is_empty(), "events wait for the drain")
	check(bus.drain() == 3, "a drain delivers raised events and their reactions")
	check(seen == ["damaged:1", "second handler", "damaged:2", "second handler", "died:4"],
		"events in raise order, handlers in subscription order, reactions after what was queued")
	var delivered: Array[Dictionary] = bus.take_log()
	check(delivered.size() == 3 and delivered[2]["type"] == "died" and bus.take_log().is_empty(), "the log holds delivered events once")


func _scheduler_checks() -> void:
	var bus := Events.new()
	var trail: Array[String] = []
	bus.subscribe("damaged", func(event: Dictionary) -> void: trail.append("reacted to " + event["by"]))
	var scheduler := Scheduler.new(bus)
	check(scheduler.add("first", Recorder.new("first", trail, bus)), "a system is added")
	check(scheduler.add("second", Recorder.new("second", trail, bus)), "another system is added")
	check(not scheduler.add("first", Recorder.new("first", trail, bus)) and not scheduler.add("plain", RefCounted.new()),
		"a taken name or an object without tick is refused")
	scheduler.tick(1.0)
	scheduler.tick(2.0)
	check(scheduler.order() == ["first", "second"], "systems run in the order added")
	check(trail == ["first@1", "reacted to first", "second@1", "first@2", "reacted to first", "second@2"],
		"the bus drains after each system, so the next system sees every reaction")
