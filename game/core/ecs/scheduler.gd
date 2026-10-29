extends RefCounted
## Runs systems in a fixed order each tick (plan 48). A system is any object with a
## `tick(now: float) -> void` method; after each system runs, the event bus is drained, so the next
## system sees every reaction to what the previous one did. The order is the order systems were added.

const Events = preload("res://game/core/ecs/events.gd")

var events: Events
var _systems: Array[Object] = []
var _names: Array[String] = []


func _init(bus: Events) -> void:
	events = bus


## Adds a system to the end of the order. False if the name is taken or it has no tick method.
func add(system_name: String, system: Object) -> bool:
	if system_name in _names or not system.has_method("tick"):
		return false
	_names.append(system_name)
	_systems.append(system)
	return true


## The system names in the order they run.
func order() -> Array[String]:
	return _names.duplicate()


func tick(now: float) -> void:
	for system: Object in _systems:
		system.call("tick", now)
		events.drain()
