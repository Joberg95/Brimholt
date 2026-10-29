extends Node
## The request gateway (plan 48), /root/Main/Gateway on every peer: every request a player sends the
## host. Each @rpc checks its sender (a joined player, not being disconnected, under the rate limit)
## and hands the request to its handler; the handlers run the rule (world, combat, economy, crafting)
## and publish the result through replication (game/net/replication.gd). The host's own player calls the handlers
## directly with id 1.

const World = preload("res://game/core/world.gd")

## The most requests a player may send in one second before being disconnected.
const MAX_REQUESTS_PER_SECOND: int = 30

## The main node (game/main.gd): the simulation, the clock, and replication.
var game: Node
## Peer id -> {start, count}: requests in the current one-second window.
var _request_windows: Dictionary = {}


func reset() -> void:
	_request_windows.clear()


func forget(id: int) -> void:
	_request_windows.erase(id)


## Whether a request comes from a joined remote player who is under the rate limit; a player
## over it is disconnected.
func _valid_sender(sender: int) -> bool:
	if not game.hosting or sender <= 1 or not game.world.players.has(sender) or game._closing_peers.has(sender):
		return false
	var now: float = game._now()
	var window: Dictionary = _request_windows.get(sender, {"start": now, "count": 0})
	if now - window["start"] >= 1.0:
		window = {"start": now, "count": 0}
	window["count"] += 1
	_request_windows[sender] = window
	if window["count"] > MAX_REQUESTS_PER_SECOND:
		game._reject_connection(sender, "Too many commands. Reconnect and slow down.")
		return false
	return true


func _sender() -> int:
	var sender: int = multiplayer.get_remote_sender_id()
	return sender if _valid_sender(sender) else 0


# ---------------------------------------------------------------- requests

@rpc("any_peer", "call_remote", "reliable")
func request_move(direction: Vector2i) -> void:
	var sender: int = _sender()
	if sender != 0:
		handle_move(sender, direction)


@rpc("any_peer", "call_remote", "reliable")
func request_equipment(slot: String) -> void:
	var sender: int = _sender()
	if sender != 0:
		handle_equipment(sender, slot)


@rpc("any_peer", "call_remote", "reliable")
func request_item_move(source: Variant, target: Variant) -> void:
	var sender: int = _sender()
	if sender != 0:
		handle_item_move(sender, source, target)


@rpc("any_peer", "call_remote", "reliable")
func request_travel(ferryman: Variant, destination: Variant) -> void:
	var sender: int = _sender()
	if sender != 0:
		handle_travel(sender, ferryman, destination)


@rpc("any_peer", "call_remote", "reliable")
func request_target(target: Variant) -> void:
	var sender: int = _sender()
	if sender != 0:
		handle_target(sender, target)


@rpc("any_peer", "call_remote", "reliable")
func request_spell(spell: Variant) -> void:
	var sender: int = _sender()
	if sender != 0:
		handle_spell(sender, spell)


@rpc("any_peer", "call_remote", "reliable")
func request_rune(kind: Variant) -> void:
	var sender: int = _sender()
	if sender != 0:
		handle_rune(sender, kind)


@rpc("any_peer", "call_remote", "reliable")
func request_drink(index: Variant) -> void:
	var sender: int = _sender()
	if sender != 0:
		handle_drink(sender, index)


@rpc("any_peer", "call_remote", "reliable")
func request_party(action: Variant, other: Variant) -> void:
	var sender: int = _sender()
	if sender != 0:
		handle_party(sender, action, other)


@rpc("any_peer", "call_remote", "reliable")
func request_quest(npc: Variant, relic: Variant) -> void:
	var sender: int = _sender()
	if sender != 0:
		handle_quest(sender, npc, relic)


@rpc("any_peer", "call_remote", "reliable")
func request_task(npc: Variant, task: Variant, action: Variant) -> void:
	var sender: int = _sender()
	if sender != 0:
		handle_task(sender, npc, task, action)


@rpc("any_peer", "call_remote", "reliable")
func request_empower(npc: Variant, spell: Variant) -> void:
	var sender: int = _sender()
	if sender != 0:
		handle_empower(sender, npc, spell)


@rpc("any_peer", "call_remote", "reliable")
func request_gather(cell: Variant) -> void:
	var sender: int = _sender()
	if sender != 0:
		handle_gather(sender, cell)


@rpc("any_peer", "call_remote", "reliable")
func request_craft(npc: Variant, recipe: Variant, count: Variant) -> void:
	var sender: int = _sender()
	if sender != 0:
		handle_craft(sender, npc, recipe, count)


@rpc("any_peer", "call_remote", "reliable")
func request_vocation(npc: Variant) -> void:
	var sender: int = _sender()
	if sender != 0:
		handle_vocation(sender, npc)


@rpc("any_peer", "call_remote", "reliable")
func request_pvp(npc: Variant, on: Variant) -> void:
	var sender: int = _sender()
	if sender != 0:
		handle_pvp(sender, npc, on)


@rpc("any_peer", "call_remote", "reliable")
func request_buy(npc: Variant, kind: Variant, count: Variant) -> void:
	var sender: int = _sender()
	if sender != 0:
		handle_buy(sender, npc, kind, count)


@rpc("any_peer", "call_remote", "reliable")
func request_sell(npc: Variant, index: Variant) -> void:
	var sender: int = _sender()
	if sender != 0:
		handle_sell(sender, npc, index)


@rpc("any_peer", "call_remote", "reliable")
func request_bank(npc: Variant, action: Variant, amount: Variant) -> void:
	var sender: int = _sender()
	if sender != 0:
		handle_bank(sender, npc, action, amount)


# ---------------------------------------------------------------- handlers (host)

func handle_move(id: int, direction: Vector2i) -> void:
	var result: Dictionary = game.world.move(id, direction, game._now())
	if result["ok"]:
		game.replication.publish_actor(id, true)
		game.replication.handle_events(game.instances.after_move(id, game._now()))
	else:
		game.replication.send_feedback(id, result["reason"], result["retry"], true)


func handle_equipment(id: int, slot: String) -> void:
	_item_result(id, game.world.toggle_equipment(id, slot, game._now()))


func handle_item_move(id: int, source: Variant, target: Variant) -> void:
	_item_result(id, game.world.move_item(id, source, target, game._now()))


func handle_travel(id: int, ferryman: Variant, destination: Variant) -> void:
	var result: Dictionary = game.world.travel(id, ferryman, destination, game._now())
	if result["ok"]:
		game.replication.publish_actor(id)
		game.replication.send_feedback(id, result["message"], 0.0, false)
	else:
		game.replication.send_feedback(id, result["reason"], 0.0, false)


func handle_target(id: int, target: Variant) -> void:
	var result: Dictionary = game.combat.set_target(id, target, game._now())
	if result["ok"]:
		game.replication.publish_actor(id)
	else:
		game.replication.send_feedback(id, result["reason"], 0.0, false)


func handle_spell(id: int, spell: Variant) -> void:
	_events_or_reason(id, game.combat.cast(id, spell, game._now()))


func handle_rune(id: int, kind: Variant) -> void:
	_events_or_reason(id, game.combat.use_rune(id, kind, game._now()))


func handle_drink(id: int, index: Variant) -> void:
	_events_or_reason(id, game.combat.drink(id, index, game._now()))


func handle_party(id: int, action: Variant, other: Variant) -> void:
	_events_or_reason(id, game.combat.party_action(id, action, other, game._now()))


func handle_quest(id: int, npc: Variant, relic: Variant) -> void:
	_events_or_reason(id, game.combat.claim_relic(id, npc, relic, game._now()))


func handle_task(id: int, npc: Variant, task: Variant, action: Variant) -> void:
	_events_or_reason(id, game.combat.task_action(id, npc, task, action, game._now()))


func handle_gather(id: int, cell: Variant) -> void:
	_events_or_reason(id, game.crafting.start_gather(id, cell, game._now()))


## Lasting changes (a spell rank, a crafted item, PvP, a vocation) are saved at once.
func handle_empower(id: int, npc: Variant, spell: Variant) -> void:
	_events_or_reason(id, game.combat.empower_spell(id, npc, spell, game._now()), true)


func handle_craft(id: int, npc: Variant, recipe: Variant, count: Variant) -> void:
	_events_or_reason(id, game.crafting.craft(id, npc, recipe, count, game._now()), true)


func handle_pvp(id: int, npc: Variant, on: Variant) -> void:
	_events_or_reason(id, game.combat.set_pvp(id, npc, on, game._now()), true)


func handle_vocation(id: int, npc: Variant) -> void:
	_events_or_reason(id, game.world.choose_vocation(id, npc, game._now()), true)


func handle_buy(id: int, npc: Variant, kind: Variant, count: Variant) -> void:
	_service_result(id, game.economy.buy(id, npc, kind, count, game._now()))


func handle_sell(id: int, npc: Variant, index: Variant) -> void:
	_service_result(id, game.economy.sell(id, npc, index, game._now()))


func handle_bank(id: int, npc: Variant, action: Variant, amount: Variant) -> void:
	_service_result(id, game.economy.bank(id, npc, action, amount, game._now()))


## Replicates a result's events, saving the player when `save`; or tells them why it failed.
func _events_or_reason(id: int, result: Dictionary, save: bool = false) -> void:
	if result["ok"]:
		game.replication.handle_events(result["events"])
		if save:
			game._save_player(id)
	else:
		game.replication.send_feedback(id, result["reason"], 0.0, false)


func _item_result(id: int, result: Dictionary) -> void:
	if result["ok"]:
		game.replication.publish_actor(id)
		game.replication.publish_ground(result["ground"])
	else:
		game.replication.send_feedback(id, result["reason"], 0.0, false)


## Vendor and bank results change only the requesting player's private state.
func _service_result(id: int, result: Dictionary) -> void:
	if result["ok"]:
		game.replication.publish_actor(id)
		game.replication.send_feedback(id, result["message"], 0.0, false)
	else:
		game.replication.send_feedback(id, result["reason"], 0.0, false)
