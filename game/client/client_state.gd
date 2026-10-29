extends RefCounted
## The replicated view this peer draws (plan 48): players and monsters as the host sent them, with
## their positions interpolated between tiles, ground stacks, and short-lived effects. It holds no rules;
## the host's world is the authority. The render and UI components read it through `game.client`.

const World = preload("res://game/core/world.gd")
const Combat = preload("res://game/core/combat.gd")
const CellIndex = preload("res://game/render/cell_index.gd")

## This peer's own player id (0 before joining or on a dedicated server).
var self_id: int = 0
## Player id -> {state (the host's export), start, visual (interpolated cell), duration, elapsed, received}.
var actors: Dictionary = {}
## Monster id -> the same shape as actors.
var monsters: Dictionary = {}
## Short-lived visuals: floating numbers, missiles, and spell areas.
var effects: Array = []
var ground_view: Dictionary = {}:
	set(value):
		ground_view = value
		_ground_index.clear()
		for cell: Vector2i in ground_view:
			_ground_index.put(cell, cell)
## Monsters and ground stacks by map chunk, so drawing visits only what is near the camera
## (the host knows every monster in the world). See monsters_in and ground_in.
var _monster_index := CellIndex.new()
var _ground_index := CellIndex.new()
## Monsters whose view is still sliding between tiles; the rest stand still and are skipped.
var _moving_monsters: Dictionary = {}


func clear() -> void:
	self_id = 0
	actors.clear()
	monsters.clear()
	_monster_index.clear()
	_moving_monsters.clear()
	effects.clear()
	ground_view = {}


## Moves every view along its step and drops expired effects (`clock` in seconds since start).
func advance(delta: float, clock: float) -> void:
	for id: int in actors:
		slide(actors[id], delta)
	for id: int in _moving_monsters.keys():
		if not monsters.has(id) or slide(monsters[id], delta):
			_moving_monsters.erase(id)
	effects = effects.filter(func(effect: Dictionary) -> bool: return clock - effect["born"] < effect.get("life", 1.1))


## Moves a creature's view along its step; true once it stands on its tile.
static func slide(view: Dictionary, delta: float) -> bool:
	view["elapsed"] = minf(view["elapsed"] + delta, view["duration"])
	var weight: float = view["elapsed"] / view["duration"] if view["duration"] > 0.0 else 1.0
	view["visual"] = view["start"].lerp(Vector2(view["state"]["cell"]), weight)
	return weight >= 1.0


## Where a player's view starts sliding for a new state: mid-step as the host reports it, or where
## it already stands when its tile did not change.
func actor_start(state: Dictionary) -> Vector2:
	var id: int = state["id"]
	var remaining: float = state["remaining"]
	var start: Vector2 = Vector2(state["from"]).lerp(
		Vector2(state["cell"]), 1.0 - clampf(remaining / state.get("duration", World.MOVE_SECONDS), 0.0, 1.0))
	if actors.has(id) and actors[id]["state"]["cell"] == state["cell"]:
		start = actors[id]["visual"]
	return start


## Replaces a player's view with a new state from the host, sliding from `start` (actor_start).
func put_actor(state: Dictionary, start: Vector2, received: float) -> void:
	var id: int = state["id"]
	var previous: Dictionary = actors.get(id, {})
	actors[id] = {
		"state": state.duplicate(true), "start": start, "visual": start,
		"duration": state["remaining"], "elapsed": 0.0, "received": received,
	}
	keep_attack(previous, actors[id])


func put_monster(state: Dictionary) -> void:
	var id: int = state["id"]
	var remaining: float = state["remaining"]
	var total: float = maxf(state.get("duration", World.MOVE_SECONDS), 0.01)
	var start: Vector2 = Vector2(state["from"]).lerp(Vector2(state["cell"]), 1.0 - clampf(remaining / total, 0.0, 1.0))
	if monsters.has(id) and monsters[id]["state"]["cell"] == state["cell"]:
		start = monsters[id]["visual"]
	var previous: Dictionary = monsters.get(id, {})
	monsters[id] = {"state": state.duplicate(true), "start": start, "visual": start, "duration": remaining, "elapsed": 0.0}
	_moving_monsters[id] = true
	_monster_index.put(id, state["cell"])
	keep_attack(previous, monsters[id])


func clear_monsters() -> void:
	monsters.clear()
	_monster_index.clear()
	_moving_monsters.clear()


func remove_monster(id: int) -> void:
	monsters.erase(id)
	_monster_index.remove(id)


func put_ground(cell: Vector2i, stack: Array) -> void:
	if stack.is_empty():
		ground_view.erase(cell)
		_ground_index.remove(cell)
	else:
		ground_view[cell] = stack.duplicate()
		_ground_index.put(cell, cell)


## An update arriving mid-swing must not cut the attack animation short.
static func keep_attack(previous: Dictionary, view: Dictionary) -> void:
	if previous.has("attack_born"):
		view["attack_born"] = previous["attack_born"]
		view["attack_facing"] = previous["attack_facing"]


func own_target() -> int:
	return actors[self_id]["state"].get("target", 0) if actors.has(self_id) else 0


## Ids of monsters in view whose tile (or the tile they are stepping from) is in `area`.
func monsters_in(area: Rect2i) -> Array[int]:
	var result: Array[int] = []
	for id: int in _monster_index.query(area.grow(1)):
		if monsters.has(id):
			result.append(id)
		else:
			_monster_index.remove(id)
	return result


## Cells with a ground stack in `area`.
func ground_in(area: Rect2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in _ground_index.query(area):
		if area.has_point(cell) and ground_view.has(cell):
			result.append(cell)
	return result


## A player's (positive id) or monster's (negative id) view, or {}.
func creature_view(id: int) -> Dictionary:
	if id > 0:
		return actors.get(id, {})
	return monsters.get(id, {}) if id < 0 else {}


## The creature drawn on a tile (or standing just below it, as figures reach a tile up), not yourself.
func creature_at(cell: Vector2i) -> int:
	for probe: Vector2i in [cell, cell + Vector2i.DOWN]:
		for group: Dictionary in [monsters, actors]:
			for id: int in group:
				if id != self_id and Vector2i(group[id]["visual"].round()) == probe:
					return id
	return 0


## The step toward a locked target that is out of reach, like Tibia's chase mode.
func chase_direction() -> Vector2i:
	var target: Dictionary = creature_view(own_target())
	if target.is_empty() or not actors.has(self_id):
		return Vector2i.ZERO
	var own: Dictionary = actors[self_id]["state"]
	var goal: Vector2i = target["state"]["cell"]
	if Combat.in_reach(own["cell"], goal, Combat.VOCATION_RANGE.get(Combat.attack_style(own["vocation"], own["equipment"]), 1)):
		return Vector2i.ZERO
	# Creatures never block a player, so only the land shapes the path.
	return Combat.path_step(own["cell"], goal, func(_cell: Vector2i) -> bool: return false)
