extends RefCounted
## Instanced dungeons on the host (layouts and copies in game/data/dungeons.gd). A player who
## steps on a stairway down enters their party's copy of that dungeon: the copy their party
## (keyed by its leader, or by the player when alone) already holds, else the first free copy,
## whose monsters spawn now. Stairs up lead back beside the stairway. A copy with nobody in it
## resets after Dungeons.RESET_SECONDS: its monsters and dropped items vanish and it is free
## again. Results carry events for main.gd to publish, like Combat.

const World = preload("res://game/core/world.gd")
const Combat = preload("res://game/core/combat.gd")
const Dungeons = preload("res://game/data/dungeons.gd")

var world: World
var combat: Combat
## dungeon id -> one {owner, empty_since, monsters} per copy; owner 0 means free.
var copies: Dictionary = {}


func _init(owner_world: World, owner_combat: Combat) -> void:
	world = owner_world
	combat = owner_combat
	for id: String in Dungeons.DUNGEONS:
		var list: Array = []
		for copy: int in Dungeons.DUNGEONS[id]["copies"]:
			list.append({"owner": 0, "empty_since": -1.0, "monsters": []})
		copies[id] = list


## A player's instance key: their party leader, or themselves.
func owner_key(id: int) -> int:
	var leader: int = world.players[id]["party"]
	return leader if leader != 0 else id


## Called after a player moves: stepping on a stairway enters, stepping on stairs up leaves.
func after_move(id: int, now: float) -> Array:
	if not world.players.has(id):
		return []
	var cell: Vector2i = world.players[id]["cell"]
	if World.DUNGEON_ENTRANCES.has(cell):
		return enter(id, World.DUNGEON_ENTRANCES[cell], now)
	if World.terrain(cell) == "^" and not World.dungeon_at(cell).is_empty():
		return leave(id, now)
	return []


func enter(id: int, dungeon: String, now: float) -> Array:
	var definition: Dictionary = Dungeons.DUNGEONS[dungeon]
	var key: int = owner_key(id)
	var chosen: int = -1
	for copy: int in copies[dungeon].size():
		if copies[dungeon][copy]["owner"] == key:
			chosen = copy
	var events: Array = []
	if chosen < 0:
		chosen = _claim(dungeon, key, now, events)
	if chosen < 0:
		_bounce(id, now, events)
		events.append({"kind": "message", "id": id, "text": "Every copy of the %s is in use. Try again soon." % definition["name"]})
		return events
	var origin: Vector2i = Dungeons.origin(dungeon, chosen)
	var arrival: Vector2i = _free_cell_near(origin + Dungeons.cells(dungeon, "@")[0], now, id)
	_teleport(id, arrival, events)
	events.append({"kind": "message", "id": id, "text": "You descend into the %s (levels %d-%d)." % [
		definition["name"], definition["min_level"], definition["max_level"]]})
	return events


func leave(id: int, now: float) -> Array:
	var place: Array = World.dungeon_at(world.players[id]["cell"])
	var events: Array = []
	_bounce_to(id, World.ENTRANCE_OF[place[0]], now, events)
	events.append({"kind": "message", "id": id, "text": "You climb back up to %s." % Dungeons.DUNGEONS[place[0]]["town"]})
	return events


## Moves a player standing in a dungeon (after a host restart, say) back to its stairway.
func evacuate(id: int, now: float) -> Array:
	var place: Array = World.dungeon_at(world.players[id]["cell"])
	var events: Array = []
	if not place.is_empty() and copies[place[0]][place[1]]["owner"] == 0:
		_bounce_to(id, World.ENTRANCE_OF[place[0]], now, events)
	return events


## Frees copies that have been empty for Dungeons.RESET_SECONDS.
func tick(now: float) -> Array:
	var events: Array = []
	var occupied: Dictionary = {}
	for id: int in world.players:
		var place: Array = World.dungeon_at(world.players[id]["cell"])
		if not place.is_empty():
			occupied[place] = true
	for dungeon: String in copies:
		for copy: int in copies[dungeon].size():
			var state: Dictionary = copies[dungeon][copy]
			if state["owner"] == 0:
				continue
			if occupied.has([dungeon, copy]):
				state["empty_since"] = -1.0
			elif state["empty_since"] < 0.0:
				state["empty_since"] = now
			elif now - state["empty_since"] >= Dungeons.RESET_SECONDS:
				reset(dungeon, copy, events)
	return events


## Empties a copy: its monsters and items vanish and any party may claim it.
func reset(dungeon: String, copy: int, events: Array) -> void:
	var state: Dictionary = copies[dungeon][copy]
	for monster: int in state["monsters"]:
		combat.despawn(monster, events)
	state["monsters"] = []
	state["owner"] = 0
	state["empty_since"] = -1.0
	var area: Rect2i = Dungeons.rect(dungeon, copy)
	var cleared: Array[Vector2i] = []
	for cell: Vector2i in world.ground.keys():
		if area.has_point(cell):
			world.ground.erase(cell)
			cleared.append(cell)
	if not cleared.is_empty():
		events.append({"kind": "ground", "cells": cleared})


func _claim(dungeon: String, key: int, now: float, events: Array) -> int:
	for copy: int in copies[dungeon].size():
		var state: Dictionary = copies[dungeon][copy]
		if state["owner"] == 0:
			state["owner"] = key
			state["empty_since"] = -1.0
			var origin: Vector2i = Dungeons.origin(dungeon, copy)
			var spawned: Array = []
			for spawn: Array in Dungeons.spawns(dungeon):
				spawned.append(combat.spawn_monster(spawn[1], spawn[2], origin + spawn[0], now, -1, events))
			state["monsters"] = spawned
			return copy
	return -1


func _teleport(id: int, cell: Vector2i, events: Array) -> void:
	var player: Dictionary = world.players[id]
	player["cell"] = cell
	player["from"] = cell
	player["target"] = 0
	events.append({"kind": "player", "id": id})


## Puts a player on a free tile beside a stairway (never on it, so they do not go back down).
func _bounce_to(id: int, stairway: Vector2i, now: float, events: Array) -> void:
	_teleport(id, _free_cell_near(stairway, now, id, true), events)


func _bounce(id: int, now: float, events: Array) -> void:
	_bounce_to(id, world.players[id]["cell"], now, events)


func _free_cell_near(center: Vector2i, now: float, id: int, avoid_center: bool = false) -> Vector2i:
	for radius: int in range(0 if not avoid_center else 1, 4):
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				var cell: Vector2i = center + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) == radius and World.walkable(cell) and World.terrain(cell) not in ["v", "^"] \
						and not world.occupied(cell, now, id):
					return cell
	return center
