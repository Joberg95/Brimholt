extends RefCounted
## The client API (plan 48): every request the UI, input, and bots on this peer make of the host,
## as `game.api.<name>_local(...)`. On the host they go straight to the gateway's handler as player 1;
## on a client they become the gateway's RPC. Nothing here changes game state itself; the host
## answers through replication. Solo controls run on the private host directly.

const World = preload("res://game/core/world.gd")
const Combat = preload("res://game/core/combat.gd")
const Crafting = preload("res://game/core/crafting.gd")
const Professions = preload("res://game/data/professions.gd")

## Seconds without an answer to a move before the host is treated as gone.
const MOVE_ANSWER_SECONDS: float = 3.0

## The main node (game/main.gd).
var game: Node
## When the unanswered move was sent (-1 if none), and when the next step may be tried.
var move_pending_since: float = -1.0
var next_move_attempt: float = 0.0


func _init(main: Node) -> void:
	game = main


func reset() -> void:
	move_pending_since = -1.0
	next_move_attempt = 0.0


## Whether this peer has a character in a world to send requests for.
func playing() -> bool:
	return game.session.connected and game.client.self_id != 0


## Sends a request: the gateway's `handle_<name>` as player 1 on the host, its `request_<name>` RPC on a client.
func _request(request: String, args: Array) -> void:
	if not playing():
		return
	if game.session.hosting:
		game.gateway.callv("handle_" + request, [1] + args)
	else:
		game.gateway.callv("rpc_id", [1, "request_" + request] + args)


## Steps one tile (one move in flight at a time; the host's answer clears it).
func move_local(direction: Vector2i) -> void:
	if not playing() or move_pending_since >= 0.0:
		return
	move_pending_since = game._now()
	next_move_attempt = game._now() + World.MOVE_SECONDS
	_request("move", [direction])


## The host stopped answering a move: true once it has been silent too long.
func move_timed_out(now: float) -> bool:
	return move_pending_since >= 0.0 and now - move_pending_since > MOVE_ANSWER_SECONDS


## Whether a new step may be tried now.
func can_step(now: float) -> bool:
	return move_pending_since < 0.0 and now >= next_move_attempt


## Party actions: "invite", "revoke", "join" (with the inviting leader), or "leave" (other = 0).
func party_local(action: String, other: int) -> void:
	_request("party", [action, other])


func equip_local(slot: String) -> void:
	_request("equipment", [slot])


func move_item_local(source: Dictionary, target: Dictionary) -> void:
	_request("item_move", [source, target])


## Picks up the top item on your tile, or else on the tile you face.
func pick_up_local() -> void:
	if not game.client.actors.has(game.client.self_id):
		return
	var state: Dictionary = game.client.actors[game.client.self_id]["state"]
	var cell: Vector2i = state["cell"]
	if not game.client.ground_view.has(cell):
		cell += Vector2i(state["facing"])
	move_item_local({"type": "ground", "cell": cell}, {"type": "backpack"})


func travel_local(ferryman: String, destination: String) -> void:
	_request("travel", [ferryman, destination])


func quest_local(npc: String, relic: String) -> void:
	_request("quest", [npc, relic])


func task_local(npc: String, task: String, action: String) -> void:
	_request("task", [npc, task, action])


## Whether this peer knows a gathering node is regrowing.
func node_worked(cell: Vector2i) -> bool:
	return game.worked_nodes.get(cell, -INF) > game._now()


## Starts gathering at a node (the host checks reach, skill, and the node).
func gather_local(cell: Vector2i) -> void:
	_request("gather", [cell])


## Gathers from the nearest unworked node within reach: the tile you face first.
func gather_nearby() -> void:
	if not game.client.actors.has(game.client.self_id):
		return
	var state: Dictionary = game.client.actors[game.client.self_id]["state"]
	var own: Vector2i = state["cell"]
	var best := Vector2i(-1, -1)
	var best_score: int = 1 << 30
	for dy: int in range(-3, 4):
		for dx: int in range(-3, 4):
			var cell: Vector2i = own + Vector2i(dx, dy)
			var profession: String = Crafting.node_at(cell)
			if profession.is_empty() or World.chebyshev(own, cell) > Professions.REACH[profession] \
					or node_worked(cell):
				continue
			var score: int = World.chebyshev(own, cell) * 10 + (0 if cell == own + state["facing"] else 1)
			if score < best_score:
				best_score = score
				best = cell
	if best.x < 0:
		game.last_action_message = "Nothing to gather within reach."
		return
	gather_local(best)


## Asks an artisan to craft `count` of a recipe (the host checks the skill and resources).
func craft_local(npc: String, recipe: String, count: int) -> void:
	_request("craft", [npc, recipe, count])


## Asks your class trainer to raise a spell's rank for rune shards (the host checks everything).
func empower_local(npc: String, spell: String) -> void:
	_request("empower", [npc, spell])


## Asks a trainer to make you their vocation (permanent; the host checks the trial and level).
func vocation_local(npc: String) -> void:
	_request("vocation", [npc])


## Turns your PvP on or off at the warden (Combat.set_pvp checks reach, skull, fight, and cooldown).
func pvp_local(npc: String, on: bool) -> void:
	_request("pvp", [npc, on])


func buy_local(npc: String, kind: String, count: int) -> void:
	_request("buy", [npc, kind, count])


## Sells the backpack stack at `index`, or with -1 every monster material.
func sell_local(npc: String, index: int) -> void:
	_request("sell", [npc, index])


func bank_local(npc: String, action: String, amount: int) -> void:
	_request("bank", [npc, action, amount])


func drink_local(index: int) -> void:
	_request("drink", [index])


## Drinks the strongest potion sharing `kind`'s timer in the backpack (the potion keys: a
## great health potion before a strong one before a plain one).
func drink_kind(kind: String) -> void:
	if not game.client.actors.has(game.client.self_id):
		return
	var backpack: Array = game.client.actors[game.client.self_id]["state"].get("backpack", [])
	var best: int = -1
	var strength: float = 0.0
	for index: int in backpack.size():
		var item: Dictionary = World.ITEMS.get(World.kind_of(backpack[index]), {})
		if item.get("timer", "") == kind:
			var share: float = 0.0
			for stat: String in item["drink"]:
				share += item["drink"][stat]
			if best < 0 or share > strength:
				best = index
				strength = share
	if best >= 0:
		drink_local(best)
		return
	game.last_action_message = "You have no %ss." % World.ITEMS[kind]["name"].to_lower()


func target_local(target: int) -> void:
	_request("target", [target])


func cast_local(spell: String) -> void:
	_request("spell", [spell])


## Casts a rune item from your backpack at your target (Combat.use_rune).
func rune_local(kind: String) -> void:
	_request("rune", [kind])


## Locks the nearest monster within targeting range.
func target_nearest() -> void:
	if not game.client.actors.has(game.client.self_id):
		return
	var own: Vector2i = game.client.actors[game.client.self_id]["state"]["cell"]
	var best: int = 0
	var best_distance: int = Combat.TARGET_RANGE + 1
	for id: int in game.client.monsters:
		var gap: int = Combat.distance(own, game.client.monsters[id]["state"]["cell"])
		if gap < best_distance:
			best = id
			best_distance = gap
	if best != 0:
		target_local(best)


# ---------------------------------------------------------------- solo (the private host)

func _solo_result(result: Dictionary, events: bool) -> void:
	if events:
		game.replication.handle_events(result["events"])
	if not result["ok"]:
		game.last_action_message = result["reason"]


func _solo() -> bool:
	return game.session.solo_mode and game.session.hosting


## Gathers a full raid around you, or sends it home (Solo.raid).
func raid_local(on: bool) -> void:
	if _solo():
		var result: Dictionary = game.solo.raid(on, game._now())
		_solo_result(result, result["ok"])


## Gives a companion slot another class (Solo.set_companion).
func companion_local(slot: int, vocation: String) -> void:
	if _solo():
		_solo_result(game.solo.set_companion(slot, vocation, game._now()), true)


## Brings a companion slot's companion to your side, or sends it home (Solo.invite, Solo.dismiss).
func invite_local(slot: int, on: bool) -> void:
	if _solo():
		_solo_result(game.solo.invite(slot, game._now()) if on else game.solo.dismiss(slot), true)


## One more or one fewer of a class in the raid plan (Solo.set_raid_plan).
func raid_plan_local(vocation: String, delta: int) -> void:
	if _solo():
		_solo_result(game.solo.set_raid_plan(vocation, delta), false)
