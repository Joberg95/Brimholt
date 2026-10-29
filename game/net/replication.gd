extends Node
## Replication (plan 48), /root/Main/Replication on every peer. On the host it turns the
## simulation's events into updates: each changed player and monster once, ground stacks, effects,
## and messages, sent only to the players who should see them (a monster or an effect only within
## INTEREST_RADIUS tiles in the same space; a backpack only to its owner). On every peer its
## authority RPCs apply those updates to the replicated view (game.client).

const World = preload("res://game/core/world.gd")
const Combat = preload("res://game/core/combat.gd")
const Titles = preload("res://game/data/titles.gd")

## Clients receive monsters and combat effects only within INTEREST_RADIUS tiles of their
## character; peer id -> {monster id: true} they currently know about.
const INTEREST_RADIUS: int = 24
const INTEREST_SECONDS: float = 0.25

## The main node (game/main.gd): the simulation, the clock, the view, and the session.
var game: Node
var _known_monsters: Dictionary = {}
var _next_interest: float = 0.0


func reset() -> void:
	_known_monsters.clear()
	_next_interest = 0.0


func forget(peer_id: int) -> void:
	_known_monsters.erase(peer_id)


## Host: brings each remote player's monsters up to date every INTEREST_SECONDS.
func tick(now: float) -> void:
	if now >= _next_interest:
		_next_interest = now + INTEREST_SECONDS
		_sync_interest(now)


## Replicates events: visuals immediately, then each changed creature once, then messages.
func handle_events(events: Array) -> void:
	var players_changed: Dictionary = {}
	var monsters_changed: Dictionary = {}
	var messages: Array = []
	for event: Dictionary in events:
		match event["kind"]:
			"player":
				players_changed[event["id"]] = players_changed.get(event["id"], false) or event.get("movement", false)
			"monster":
				monsters_changed[event["id"]] = monsters_changed.get(event["id"], false) or event["movement"]
			"monster_gone":
				monsters_changed.erase(event["id"])
				_monster_died(event["id"])
				for peer_id: int in remote_players():
					if _known_monsters.get(peer_id, {}).has(event["id"]):
						_known_monsters[peer_id].erase(event["id"])
						monster_gone.rpc_id(peer_id, event["id"])
			"ground":
				publish_ground(event["cells"])
			"message":
				messages.append(event)
			"loot":
				# Loot text is only for the players the kill is credited to.
				for looter: int in event["ids"]:
					if looter == game.client.self_id:
						game._show_effect(event)
					elif looter in remote_players():
						combat_event.rpc_id(looter, event)
			"bot_left":
				game.client.actors.erase(event["id"])
				actor_left.rpc(event["id"])
			"node":
				var regrowing: Dictionary = {event["cell"]: event["seconds"]}
				nodes_worked(regrowing)
				for peer_id: int in remote_players():
					nodes_worked.rpc_id(peer_id, regrowing)
			_:
				game._show_effect(event)
				var at: Vector2i = _event_cell(event)
				for peer_id: int in remote_players():
					if _near_peer(peer_id, at):
						combat_event.rpc_id(peer_id, event)
	for id: int in players_changed:
		if game.world.players.has(id):
			publish_actor(id, players_changed[id])
	for id: int in monsters_changed:
		if game.world.monsters.has(id):
			_publish_monster(id)
	for event: Dictionary in messages:
		if game.world.players.has(event["id"]):
			send_feedback(event["id"], event["text"], 0.0, false)


## The joined remote players who receive updates (not the host, nor peers being disconnected).
func remote_players() -> Array[int]:
	var result: Array[int] = []
	for id: int in game.world.players:
		if id != 1 and not game.session.closing_peers.has(id) and id in multiplayer.get_peers():
			result.append(id)
	return result


## Everyone receives public state; only the owner receives its backpack.
func publish_actor(id: int, movement: bool = false) -> void:
	var now: float = game._now()
	apply_actor(game.world.export_player(id, now, id == game.client.self_id), movement)
	for peer_id: int in remote_players():
		actor_updated.rpc_id(peer_id, game.world.export_player(id, now, peer_id == id), movement)


func publish_ground(cells: Array) -> void:
	for cell: Vector2i in cells:
		var stack: Array = game.world.ground_stack(cell)
		game.client.put_ground(cell, stack)
		for peer_id: int in remote_players():
			ground_updated.rpc_id(peer_id, cell, stack)


## Tells a player why a request failed (or a message); a refused move also says when to retry.
func send_feedback(id: int, reason: String, retry: float, movement: bool) -> void:
	if id == 1:
		action_feedback(reason, retry, movement)
	elif id in multiplayer.get_peers():
		action_feedback.rpc_id(id, reason, retry, movement)


## Monsters near a joining player; remembered as what that peer knows.
func interest_snapshot(peer_id: int, now: float) -> Dictionary:
	var result: Dictionary = {}
	var known: Dictionary = {}
	for id: int in game.world.monsters:
		if _near_peer(peer_id, game.world.monsters[id]["cell"]):
			result[id] = game.combat.export_monster(id, now)
			known[id] = true
	_known_monsters[peer_id] = known
	return result


## The tile an effect happens on, for interest management.
static func _event_cell(event: Dictionary) -> Vector2i:
	match event["kind"]:
		"missile":
			return event["from"]
		"area":
			return event["cells"][0] if not event["cells"].is_empty() else Vector2i(-9999, -9999)
	return event.get("cell", Vector2i(-9999, -9999))


func _near_peer(peer_id: int, cell: Vector2i) -> bool:
	if not game.world.players.has(peer_id):
		return false
	var own: Vector2i = game.world.players[peer_id]["cell"]
	return Combat.distance(own, cell) <= INTEREST_RADIUS and World.dungeon_at(own) == World.dungeon_at(cell)


## Sends a monster's state to the host's view and to remote players near it; peers it left
## behind are told it is gone.
func _publish_monster(id: int) -> void:
	var state: Dictionary = game.combat.export_monster(id, game._now())
	game.client.put_monster(state)
	for peer_id: int in remote_players():
		var known: Dictionary = _known_monsters.get_or_add(peer_id, {})
		if _near_peer(peer_id, state["cell"]):
			known[id] = true
			monster_updated.rpc_id(peer_id, state)
		elif known.has(id):
			known.erase(id)
			monster_gone.rpc_id(peer_id, id)


## Brings each remote player's monsters up to date as they move: new ones in range, gone
## ones out of range (monsters that moved are already sent by _publish_monster).
func _sync_interest(now: float) -> void:
	for peer_id: int in remote_players():
		var known: Dictionary = _known_monsters.get_or_add(peer_id, {})
		for id: int in game.world.monsters:
			var near: bool = _near_peer(peer_id, game.world.monsters[id]["cell"])
			if near and not known.has(id):
				known[id] = true
				monster_updated.rpc_id(peer_id, game.combat.export_monster(id, now))
		for id: int in known.keys():
			if not game.world.monsters.has(id) or not _near_peer(peer_id, game.world.monsters[id]["cell"]):
				known.erase(id)
				monster_gone.rpc_id(peer_id, id)


# ---------------------------------------------------------------- applying updates (every peer)

## Puts a player's new state into the view, with a burst for a level or title gained; your own
## move's arrival lets you queue the next step.
func apply_actor(state: Dictionary, movement: bool = false) -> void:
	var id: int = state["id"]
	var start: Vector2 = game.client.actor_start(state)
	var previous: Dictionary = game.client.actors.get(id, {})
	if not previous.is_empty() and game._world_view != null:
		if state.get("level", 1) > previous["state"].get("level", 1):
			game._world_view.fx.burst("level_up", (start + Vector2(0.5, 0.5)) * World.TILE_SIZE, Color("#ffd86a"))
		if state.get("title", 0) > previous["state"].get("title", 0):
			game._world_view.fx.burst("level_up", (start + Vector2(0.5, 0.5)) * World.TILE_SIZE, Titles.color_of(state["title"]))
	game.client.put_actor(state, start, game._now())
	if id == game.client.self_id and game.session.connected:
		game.session.remember_character(state)
	if id == game.client.self_id and movement:
		game._move_pending_since = -1.0
		game._next_move_attempt = game._now() + state["remaining"] + 0.01


func _monster_died(id: int) -> void:
	if game.client.monsters.has(id) and game._world_view != null:
		game._world_view.fx.burst("death", (game.client.monsters[id]["visual"] + Vector2(0.5, 0.5)) * World.TILE_SIZE,
			Color(0.75, 0.7, 0.8))
	game.client.remove_monster(id)


@rpc("authority", "call_remote", "reliable")
func actor_updated(state: Dictionary, movement: bool) -> void:
	apply_actor(state, movement)


@rpc("authority", "call_remote", "reliable")
func actor_left(id: int) -> void:
	game.client.actors.erase(id)


@rpc("authority", "call_remote", "reliable")
func monster_updated(state: Dictionary) -> void:
	game.client.put_monster(state)


@rpc("authority", "call_remote", "reliable")
func monster_gone(id: int) -> void:
	_monster_died(id)


@rpc("authority", "call_remote", "reliable")
func ground_updated(cell: Vector2i, stack: Array) -> void:
	game.client.put_ground(cell, stack)


@rpc("authority", "call_remote", "reliable")
func combat_event(event: Dictionary) -> void:
	game._show_effect(event)


## Nodes being worked, with seconds until they regrow (one when worked, all on joining).
@rpc("authority", "call_remote", "reliable")
func nodes_worked(regrowing: Dictionary) -> void:
	for cell: Variant in regrowing:
		if typeof(cell) == TYPE_VECTOR2I and typeof(regrowing[cell]) in [TYPE_INT, TYPE_FLOAT]:
			game.worked_nodes[cell] = game._now() + float(regrowing[cell])


@rpc("authority", "call_remote", "reliable")
func action_feedback(reason: String, retry: float, movement: bool) -> void:
	game.last_action_message = reason
	if movement:
		game._move_pending_since = -1.0
		game._next_move_attempt = game._now() + retry + 0.02
