extends SceneTree

const World = preload("res://game/world.gd")
var game: Node2D
var role: String = ""
var stage: int = 0
var stage_since: float = 0.0
var started: float = 0.0
var client_id: int = 0
var late_id: int = 0
var late_spawn: Vector2i = Vector2i.ZERO
var saw_equipped: bool = false
var saw_unequipped: bool = false
var saw_late_move: bool = false
var saw_drop: bool = false
var saw_pickup: bool = false
var saw_ring: bool = false
var saw_voyage: bool = false
var ferried: bool = false
var sparring: int = 0
var saw_hit: bool = false
var finishing: bool = false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--test-role="):
			role = arg.trim_prefix("--test-role=")
	started = Time.get_ticks_msec() / 1000.0
	call_deferred("_start")


func _start() -> void:
	game = load("res://game/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	if game == null or finishing:
		return false
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - started > 20.0:
		fail("Timeout stage %d feedback='%s' peers=%s equipped=%s unequipped=%s late_move=%s drop=%s pickup=%s" % [
			stage, game.last_action_message, game.actors.keys(),
			saw_equipped, saw_unequipped, saw_late_move, saw_drop, saw_pickup,
		])
		return false
	if role == "loss_client":
		_loss_client_tick()
		return false
	if not game.connected:
		return false
	match role:
		"host": _host_tick(now)
		"client": _client_tick(now)
		"late": _late_tick(now)
		"dedicated_host": _dedicated_host_tick()
		"dedicated_client": _dedicated_client_tick(now)
		"loss_host": _loss_host_tick()
		_: fail("Unknown test role")
	return false


func advance() -> void:
	stage += 1
	stage_since = Time.get_ticks_msec() / 1000.0
	game.last_action_message = ""
	print("BRIMHOLT_TEST_STAGE %s %d" % [role, stage])


func state(id: int) -> Dictionary:
	return game.actors[id]["state"]


func _watch_ground(cell: Vector2i, kind: String) -> void:
	if game.ground_view.get(cell, []) == [kind]:
		saw_drop = true
	elif saw_drop and not game.ground_view.has(cell):
		saw_pickup = true


func _others_hide_backpacks() -> bool:
	for id: int in game.actors:
		if (id == game.self_id) != state(id).has("backpack"):
			return false
	return true


func fail(message: String) -> void:
	finishing = true
	push_error("BRIMHOLT_TEST_FAIL %s: %s" % [role, message])
	quit(1)


func finish() -> void:
	finishing = true
	print("BRIMHOLT_TEST_PASS " + role)
	await game.leave_game()
	quit()


func _host_tick(now: float) -> void:
	if stage == 0:
		game.equip_local("armor")
		if not state(1)["equipment"].has("armor"):
			fail("Host input did not equip armor")
			return
		advance()
	for id: int in game.actors:
		if id == 1:
			continue
		if state(id)["equipment"].has("helmet"):
			if state(id)["vocation"] != "druid":
				fail("Host did not record the client's chosen vocation")
				return
			client_id = id
			saw_equipped = true
		if id == client_id and saw_equipped and not state(id)["equipment"].has("helmet"):
			saw_unequipped = true
		if id != client_id and state(id)["cell"].y == 7 and state(id)["equipment"].has("main_hand"):
			saw_late_move = true
	_watch_ground(Vector2i(8, 6), "copper_blade")
	if not _others_hide_backpacks():
		fail("Host view exposes another player's backpack")
		return
	if stage == 1 and saw_equipped and saw_unequipped and saw_late_move and saw_drop and saw_pickup \
			and game.actors.size() == 1:
		game.move_local(Vector2i.DOWN)
		advance()
	if stage == 2 and now - stage_since > World.MOVE_SECONDS:
		if state(1)["cell"] != Vector2i(5, 7) or not state(1)["equipment"].has("armor"):
			fail("Host movement/equipment parity failed")
		elif game.ground_view != game.world.ground:
			fail("Host ground view diverged from authoritative ground")
		else:
			finish()


func _client_tick(now: float) -> void:
	var own: int = game.self_id
	if not game.actors.has(1) or not game.actors.has(own):
		fail("Missing actors")
		return
	match stage:
		0:
			if not state(1)["equipment"].has("armor"):
				return
			game.request_move.rpc_id(1, Vector2i(2, 0))
			advance()
		1:
			if game.last_action_message == "Only one cardinal tile is allowed":
				if state(own)["cell"] != Vector2i(7, 6):
					fail("Client supplied an illegal destination")
					return
				game.request_equipment.rpc_id(1, "not-a-slot")
				advance()
		2:
			if game.last_action_message == "Unknown equipment slot":
				game.move_local(Vector2i.LEFT)
				game.request_move.rpc_id(1, Vector2i.RIGHT)
				advance()
		3:
			if game.last_action_message == "Movement cooldown" and now - stage_since > 0.25:
				if state(own)["cell"] != Vector2i(6, 6):
					fail("Server cooldown failed")
					return
				game.move_local(Vector2i.LEFT)
				advance()
		4:
			if game.last_action_message == "Another player is in the way":
				if state(1)["cell"] != Vector2i(5, 6):
					fail("Remote input moved the host")
					return
				game.move_local(Vector2i.RIGHT)
				advance()
		5:
			if state(own)["cell"] == Vector2i(7, 6) and now - stage_since > 0.25:
				game.move_local(Vector2i.RIGHT)
				advance()
		6:
			if state(own)["cell"] == Vector2i(8, 6) and now - stage_since > 0.25:
				game.move_local(Vector2i.DOWN)
				advance()
		7:
			if game.last_action_message == "Blocked tile":
				if state(own)["cell"] != Vector2i(8, 6):
					fail("Wall collision failed")
					return
				game.equip_local("helmet")
				advance()
		8:
			if state(own)["equipment"].has("helmet"):
				if not _others_hide_backpacks() or state(own)["backpack"][0] != "":
					fail("Client backpack privacy or equip-from-backpack failed")
					return
				game.request_item_move.rpc_id(1, {"type": "backpack", "index": 99}, {"type": "backpack"})
				advance()
		9:
			if game.last_action_message == "Unknown item location" and now - stage_since > 0.2:
				game.move_item_local({"type": "backpack", "index": 2}, {"type": "ground", "cell": Vector2i(8, 7)})
				advance()
		10:
			if game.last_action_message == "Items cannot be placed there" and now - stage_since > 0.2:
				if state(own)["backpack"][2] != "copper_blade":
					fail("Rejected drop changed the backpack")
					return
				game.move_item_local({"type": "backpack", "index": 2}, {"type": "ground", "cell": Vector2i(8, 6)})
				advance()
		11:
			if game.ground_view.get(Vector2i(8, 6), []) == ["copper_blade"] and state(own)["backpack"][2] == "":
				print("BRIMHOLT_CLIENT_EQUIPPED")
				advance()
		12:
			if now - stage_since < 0.2:
				return
			for id: int in game.actors:
				if id != 1 and id != own and state(id)["equipment"].has("main_hand"):
					late_id = id
					game.equip_local("helmet")
					advance()
					break
		13:
			if not state(own)["equipment"].has("helmet") and not game.actors.has(late_id):
				if not state(1)["equipment"].has("armor"):
					fail("Host equipment missing on client")
				elif game.ground_view.has(Vector2i(8, 6)):
					fail("Client did not see the late joiner pick up the dropped item")
				else:
					finish()


func _late_tick(now: float) -> void:
	match stage:
		0:
			if game.actors.size() != 3 or not state(1)["equipment"].has("armor"):
				fail("Late-join snapshot incomplete")
				return
			for id: int in game.actors:
				if id != 1 and id != game.self_id and state(id)["equipment"].has("helmet"):
					client_id = id
			if client_id == 0 or state(client_id)["cell"] != Vector2i(8, 6) or state(client_id)["vocation"] != "druid" \
					or state(game.self_id)["vocation"] != "paladin":
				fail("Late join did not receive current movement and equipment")
				return
			late_spawn = state(game.self_id)["cell"]
			if late_spawn == state(1)["cell"] or late_spawn == state(client_id)["cell"]:
				fail("Late join reused an occupied spawn")
				return
			if game.ground_view.get(Vector2i(8, 6), []) != ["copper_blade"] \
					or game.ground_view.get(Vector2i(10, 1), []) != ["glowcap", "glowcap"]:
				fail("Late join did not receive the ground snapshot")
				return
			if not _others_hide_backpacks() or state(game.self_id)["backpack"].slice(0, World.START_KIT.size()) != World.START_KIT:
				fail("Late join backpack snapshot is wrong")
				return
			if game.monsters.size() != game.monsters.keys().filter(func(id: int) -> bool: return id < 0).size() \
					or game.monsters.size() != World.MONSTER_SPAWNS.reduce(func(sum: int, spawn: Dictionary) -> int: return sum + spawn["count"], 0):
				fail("Late join did not receive every monster")
				return
			print("BRIMHOLT_LATE_SNAPSHOT_OK")
			game.move_item_local({"type": "ground", "cell": Vector2i(8, 6)}, {"type": "backpack"})
			advance()
		1:
			if not game.ground_view.has(Vector2i(8, 6)) and state(game.self_id)["backpack"][World.START_KIT.size()] == "copper_blade" \
					and now - stage_since > 0.2:
				game.equip_local("main_hand")
				advance()
		2:
			if not state(client_id)["equipment"].has("helmet") and state(game.self_id)["equipment"].has("main_hand"):
				game.move_local(Vector2i.DOWN)
				advance()
		3:
			if state(game.self_id)["cell"] == late_spawn + Vector2i.DOWN and now - stage_since > 0.25:
				finish()


func _dedicated_host_tick() -> void:
	if game.self_id != 0 or game.actors.has(1):
		fail("Dedicated host created a playing character")
		return
	for id: int in game.actors:
		if state(id)["equipment"].has("main_hand") and state(id)["cell"] == Vector2i(5, 7):
			saw_late_move = true
	_watch_ground(Vector2i(5, 7), "ember_cap")
	for id: int in game.actors:
		if state(id)["equipment"].get("ring_2", "") == "copper_band" and state(id)["level"] == 1 \
				and not state(id).has("backpack"):
			saw_ring = true
	# Test-only shortcut on the server: carry the client to Cinder Landing instead of a long walk.
	for id: int in game.world.players:
		var player: Dictionary = game.world.players[id]
		if not ferried and saw_ring and player["cell"] == Vector2i(6, 7):
			var dock: Vector2i = game.world.arrival_cell("cinder_landing", game._now())
			player["cell"] = dock
			player["from"] = dock
			game._publish_actor(id)
			ferried = true
		var mossford: Vector2i = World.FERRYMEN["mossford"]["cell"]
		if ferried and World.chebyshev(player["cell"], mossford) <= World.TALK_RANGE:
			saw_voyage = true
	# Test-only: put a weak monster next to the client once it has landed in Mossford.
	if saw_voyage and sparring == 0:
		for id: int in game.world.players:
			var cell: Vector2i = game.world.players[id]["cell"]
			for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if sparring == 0 and World.walkable(cell + step) and not game.world.occupied(cell + step, game._now()):
					var events: Array = []
					sparring = game.combat.spawn_monster("field_vole", 1, cell + step, game._now(), -1, events)
					game.world.monsters[sparring]["health"] = 6
					game._handle_events(events)
	if saw_late_move and saw_drop and saw_pickup and saw_ring and saw_voyage and sparring != 0 \
			and not game.world.monsters.has(sparring) and game.actors.is_empty():
		finish()


func _dedicated_client_tick(now: float) -> void:
	var own: int = game.self_id
	match stage:
		0:
			if game.actors.size() != 1 or own == 1 or game.actors.has(1):
				fail("Dedicated snapshot contains a phantom host")
				return
			game.equip_local("main_hand")
			game.move_local(Vector2i.DOWN)
			advance()
		1:
			if state(own)["cell"] == Vector2i(5, 7) and state(own)["equipment"].has("main_hand") \
					and now - stage_since > 0.25:
				game.move_item_local({"type": "backpack", "index": 0}, {"type": "ground", "cell": Vector2i(5, 7)})
				advance()
		2:
			if game.ground_view.get(Vector2i(5, 7), []) == ["ember_cap"] and now - stage_since > 0.2:
				game.move_item_local({"type": "ground", "cell": Vector2i(5, 7)}, {"type": "backpack"})
				advance()
		3:
			if not game.ground_view.has(Vector2i(5, 7)) and state(own)["backpack"][0] == "ember_cap" \
					and now - stage_since > 0.2:
				var ring: int = state(own)["backpack"].find("copper_band")
				game.move_item_local({"type": "backpack", "index": ring}, {"type": "equipment", "slot": "ring_2"})
				advance()
		4:
			if state(own)["equipment"].get("ring_2", "") == "copper_band" and state(own)["level"] == 1 \
					and not state(own)["backpack"].has("copper_band"):
				game.travel_local("cinder_landing", "mossford")
				advance()
		5:
			if game.last_action_message == "Walk closer to the ferryman":
				game.move_local(Vector2i.RIGHT)
				advance()
		6:
			var landing: Vector2i = World.FERRYMEN["cinder_landing"]["cell"]
			if World.chebyshev(state(own)["cell"], landing) <= World.TALK_RANGE and now - stage_since > 0.25:
				game.request_travel.rpc_id(1, "cinder_landing", "nowhere")
				advance()
		7:
			if game.last_action_message == "That ferryman does not sail there":
				game.request_travel.rpc_id(1, 5, null)
				advance()
		8:
			if game.last_action_message == "Unknown ferryman":
				game.travel_local("cinder_landing", "mossford")
				advance()
		9:
			var fare: int = World.FERRYMEN["cinder_landing"]["routes"]["mossford"]
			if World.chebyshev(state(own)["cell"], World.FERRYMEN["mossford"]["cell"]) <= World.TALK_RANGE \
					and state(own)["gold"] == World.START_GOLD - fare and game.last_action_message.contains("Mossford"):
				advance()
		10:
			for id: int in game.monsters:
				if World.chebyshev(game.monsters[id]["state"]["cell"], state(own)["cell"]) == 1:
					sparring = id
					game.request_target.rpc_id(1, "not-a-creature")
					advance()
		11:
			if game.last_action_message == "Unknown target":
				game.target_local(sparring)
				advance()
		12:
			if state(own)["target"] == sparring:
				game.cast_local("piercing_shot")
				advance()
		13:
			for effect: Dictionary in game.effects:
				saw_hit = saw_hit or effect["kind"] == "text"
			if not game.monsters.has(sparring) and state(own)["experience"] > 0 and state(own)["target"] == 0 and saw_hit:
				finish()


func _loss_host_tick() -> void:
	for id: int in game.actors:
		if id != 1 and state(id)["equipment"].has("helmet"):
			finish()
			return


func _loss_client_tick() -> void:
	if stage == 0 and game.connected:
		game.equip_local("helmet")
		advance()
	elif stage == 1 and not game.connected:
		if game._status_message != "The host disconnected. Your LAN session has ended." \
				or not game.actors.is_empty() or not game.ground_view.is_empty() or game.self_id != 0:
			fail("Host loss did not report an error and clear stale actors")
		else:
			finish()
