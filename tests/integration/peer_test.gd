extends SceneTree

const World = preload("res://game/core/world.gd")
const WorldMap = preload("res://game/world_map/world_map.gd")
const Combat = preload("res://game/core/combat.gd")
const Items = preload("res://game/data/items.gd")
const Crafting = preload("res://game/core/crafting.gd")
## The druid client drops its spare armor for the late-joining paladin to pick up and wear.
const DROPPED: String = "moss_coat"
const DROPPED_INDEX: int = 1
## Where the client stands for the collision and drop checks, and the pond tile north of it that
## blocks both (the town's west pond).
const STAND: Vector2i = Vector2i(5, 5)
const BLOCKED: Vector2i = Vector2i(5, 4)
## Where the client drops the item: in its reach, and in the late joiner's from its spawn.
const DROP: Vector2i = Vector2i(6, 6)
var game: Node2D
var role: String = ""
var stage: int = 0
var stage_since: float = 0.0
## Messages shown since the current stage began: an unrelated message (a town rest, a level-up)
## arriving in the same frame must not hide the one a stage waits for.
var stage_messages: Dictionary = {}
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
var saw_party: bool = false
var ring_given_at: float = -1.0
var quest_ready: bool = false
var saw_relic: bool = false
## Town services: when the relic was claimed, and which NPC the client was last carried to.
var relic_at: float = -1.0
var errand: String = ""
var saw_task: bool = false
var saw_dungeon: bool = false
var hunting_weapon_given: bool = false
var saw_hunting_weapon: bool = false
var saw_crafted: bool = false
var saw_gathered: bool = false
var finishing: bool = false
## Persistence: whether the host has seen a character in the world. A restarted host (one that
## found a save at start: 1, else 0, -1 before its first tick) also waits until it has refused the
## second login with the same identity, which starts while the returning client plays.
var had_player: bool = false
var restarted: int = -1
var refused_duplicate: bool = false


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
	var deadline: float = 55.0 if role.begins_with("dedicated") else 35.0
	if now - started > deadline:
		fail("Timeout stage %d feedback='%s' peers=%s equipped=%s unequipped=%s late_move=%s drop=%s pickup=%s" % [
			stage, game.last_action_message, game.client.actors.keys(),
			saw_equipped, saw_unequipped, saw_late_move, saw_drop, saw_pickup,
		])
		return false
	if role == "loss_client":
		_loss_client_tick()
		return false
	if role == "persist_duplicate":
		if game.session.status_message.contains("That character is already in the world"):
			finish()
		return false
	if not game.session.connected:
		return false
	match role:
		"host": _host_tick(now)
		"client": _client_tick(now)
		"late": _late_tick(now)
		"dedicated_host": _dedicated_host_tick()
		"dedicated_client": _dedicated_client_tick(now)
		"loss_host": _loss_host_tick()
		"persist_host": _persist_host_tick()
		"persist_first": _persist_first_tick(now)
		"persist_return": _persist_return_tick(now)
		_: fail("Unknown test role")
	return false


## Whether a message since the stage began starts with, or contains, `text`.
func _saw_start(text: String) -> bool:
	for message: String in stage_messages:
		if message.begins_with(text):
			return true
	return false


func _saw_part(text: String) -> bool:
	for message: String in stage_messages:
		if message.contains(text):
			return true
	return false


func advance() -> void:
	stage += 1
	stage_since = Time.get_ticks_msec() / 1000.0
	game.last_action_message = ""
	stage_messages.clear()
	print("BRIMHOLT_TEST_STAGE %s %d" % [role, stage])


func state(id: int) -> Dictionary:
	return game.client.actors[id]["state"]


func _watch_ground(cell: Vector2i, kind: String) -> void:
	if game.client.ground_view.get(cell, []) == [kind]:
		saw_drop = true
	elif saw_drop and not game.client.ground_view.has(cell):
		saw_pickup = true


func _others_hide_backpacks() -> bool:
	for id: int in game.client.actors:
		if (id == game.client.self_id) != state(id).has("backpack") or (id == game.client.self_id) != state(id).has("invites"):
			return false
	return true


func fail(message: String) -> void:
	finishing = true
	push_error("BRIMHOLT_TEST_FAIL %s: %s" % [role, message])
	quit(1)


func finish() -> void:
	finishing = true
	print("BRIMHOLT_TEST_PASS " + role)
	await game.session.leave_game()
	quit()


func _host_tick(now: float) -> void:
	if stage == 0:
		game.api.equip_local("armor")
		if not state(1)["equipment"].has("armor"):
			fail("Host input did not equip armor")
			return
		advance()
	for id: int in game.client.actors:
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
		if id != client_id and state(id)["cell"].y == 7 and state(id)["equipment"].has("armor"):
			saw_late_move = true
	_watch_ground(DROP, DROPPED)
	if not _others_hide_backpacks():
		fail("Host view exposes another player's backpack")
		return
	if stage == 1 and saw_equipped and saw_unequipped and saw_late_move and saw_drop and saw_pickup \
			and game.client.actors.size() == 1:
		game.api.move_local(Vector2i.DOWN)
		advance()
	if stage == 2 and now - stage_since > World.MOVE_SECONDS:
		if state(1)["cell"] != Vector2i(5, 7) or not state(1)["equipment"].has("armor"):
			fail("Host movement/equipment parity failed")
		elif game.client.ground_view != game.world.ground:
			fail("Host ground view diverged from authoritative ground")
		else:
			finish()


func _client_tick(now: float) -> void:
	var own: int = game.client.self_id
	if not game.client.actors.has(1) or not game.client.actors.has(own):
		fail("Missing actors")
		return
	match stage:
		0:
			if not state(1)["equipment"].has("armor"):
				return
			game.gateway.request_move.rpc_id(1, Vector2i(2, 0))
			advance()
		1:
			if game.last_action_message == "Only one cardinal tile is allowed":
				if state(own)["cell"] != Vector2i(7, 6):
					fail("Client supplied an illegal destination")
					return
				game.gateway.request_equipment.rpc_id(1, "not-a-slot")
				advance()
		2:
			if game.last_action_message == "Unknown equipment slot":
				game.api.move_local(Vector2i.LEFT)
				game.gateway.request_move.rpc_id(1, Vector2i.RIGHT)
				advance()
		3:
			if game.last_action_message == "Movement cooldown" and now - stage_since > 0.25:
				if state(own)["cell"] != Vector2i(6, 6):
					fail("Server cooldown failed")
					return
				game.api.move_local(Vector2i.LEFT)
				advance()
		4:
			# Players walk through each other: the client steps onto the host's tile.
			if state(own)["cell"] == Vector2i(5, 6) and now - stage_since > 0.25:
				if state(1)["cell"] != Vector2i(5, 6):
					fail("Remote input moved the host")
					return
				game.api.move_local(Vector2i.RIGHT)
				advance()
		5:
			if state(own)["cell"] == Vector2i(6, 6) and now - stage_since > 0.25:
				game.api.move_local(Vector2i.LEFT)
				stage_since = now
			elif state(own)["cell"] == Vector2i(5, 6) and now - stage_since > 0.25:
				game.api.move_local(Vector2i.UP)
				advance()
		6:
			if state(own)["cell"] == STAND and now - stage_since > 0.25:
				game.api.move_local(BLOCKED - STAND)
				advance()
		7:
			if game.last_action_message == "Blocked tile":
				if state(own)["cell"] != STAND:
					fail("Wall collision failed")
					return
				game.api.equip_local("helmet")
				advance()
		8:
			if state(own)["equipment"].has("helmet"):
				if not _others_hide_backpacks() or state(own)["backpack"][0] != "":
					fail("Client backpack privacy or equip-from-backpack failed")
					return
				game.gateway.request_item_move.rpc_id(1, {"type": "backpack", "index": 99}, {"type": "backpack"})
				advance()
		9:
			if game.last_action_message == "Unknown item location" and now - stage_since > 0.2:
				game.api.move_item_local({"type": "backpack", "index": DROPPED_INDEX}, {"type": "ground", "cell": BLOCKED})
				advance()
		10:
			if game.last_action_message == "Items cannot be placed there" and now - stage_since > 0.2:
				if state(own)["backpack"][DROPPED_INDEX] != DROPPED:
					fail("Rejected drop changed the backpack")
					return
				game.api.move_item_local({"type": "backpack", "index": DROPPED_INDEX}, {"type": "ground", "cell": DROP})
				advance()
		11:
			if game.client.ground_view.get(DROP, []) == [DROPPED] and state(own)["backpack"][DROPPED_INDEX] == "":
				print("BRIMHOLT_CLIENT_EQUIPPED")
				advance()
		12:
			if now - stage_since < 0.2:
				return
			for id: int in game.client.actors:
				if id != 1 and id != own and state(id)["equipment"].has("armor"):
					late_id = id
					game.api.equip_local("helmet")
					game.api.party_local("invite", late_id)
					advance()
					break
		13:
			if game.client.actors.has(late_id) and state(own)["party"] == own and state(late_id)["party"] == own:
				saw_party = true
			if not state(own)["equipment"].has("helmet") and not game.client.actors.has(late_id):
				if not saw_party:
					fail("Client never saw the late joiner accept its party invitation")
				elif state(own)["party"] != 0 or not state(own)["invited"].is_empty():
					fail("The party did not disband when its other member disconnected")
				elif not state(1)["equipment"].has("armor"):
					fail("Host equipment missing on client")
				elif game.client.ground_view.has(DROP):
					fail("Client did not see the late joiner pick up the dropped item")
				else:
					finish()


func _late_tick(now: float) -> void:
	match stage:
		0:
			if game.client.actors.size() != 3 or not state(1)["equipment"].has("armor"):
				fail("Late-join snapshot incomplete")
				return
			for id: int in game.client.actors:
				if id != 1 and id != game.client.self_id and state(id)["equipment"].has("helmet"):
					client_id = id
			if client_id == 0 or state(client_id)["cell"] != STAND or state(client_id)["vocation"] != "druid" \
					or state(game.client.self_id)["vocation"] != "paladin":
				fail("Late join did not receive current movement and equipment")
				return
			late_spawn = state(game.client.self_id)["cell"]
			if late_spawn == state(1)["cell"] or late_spawn == state(client_id)["cell"]:
				fail("Late join reused an occupied spawn")
				return
			if game.client.ground_view.get(DROP, []) != [DROPPED] \
					or game.client.ground_view.get(Vector2i(10, 1), []) != ["glowcap#2"]:
				fail("Late join did not receive the ground snapshot")
				return
			var kit: Array = World.start_kit("paladin")
			if not _others_hide_backpacks() or state(game.client.self_id)["backpack"].slice(0, kit.size()) != kit:
				fail("Late join backpack snapshot is wrong")
				return
			var own_cell: Vector2i = state(game.client.self_id)["cell"]
			# Monsters must arrive when a camp lies well inside the interest radius; the start town's
			# camps are outside its walls, and then none of the map's monsters may arrive at all.
			var camp_near: bool = WorldMap.MONSTER_SPAWNS.any(func(spawn: Dictionary) -> bool:
				return Combat.distance(spawn["cell"], own_cell) + int(spawn["radius"]) + 2 < game.replication.INTEREST_RADIUS)
			if (camp_near and game.client.monsters.is_empty()) or game.client.monsters.keys().any(func(id: int) -> bool:
					return id >= 0 or Combat.distance(game.client.monsters[id]["state"]["cell"], own_cell) > game.replication.INTEREST_RADIUS):
				fail("Late join did not receive only its nearby monsters")
				return
			print("BRIMHOLT_LATE_SNAPSHOT_OK")
			game.api.move_item_local({"type": "ground", "cell": DROP}, {"type": "backpack"})
			advance()
		1:
			if not game.client.ground_view.has(DROP) \
					and state(game.client.self_id)["backpack"][World.start_kit("paladin").size()] == DROPPED and now - stage_since > 0.2:
				game.api.equip_local("armor")
				advance()
		2:
			if not state(client_id)["equipment"].has("helmet") and state(game.client.self_id)["equipment"].has("armor"):
				game.api.move_local(Vector2i.DOWN)
				advance()
		3:
			if state(game.client.self_id)["cell"] == late_spawn + Vector2i.DOWN and now - stage_since > 0.25 \
					and client_id in state(game.client.self_id)["invites"]:
				if game.party_options(client_id) != ["join"]:
					fail("The right-click menu does not offer to join an inviting player")
					return
				game.api.party_local("join", client_id)
				advance()
		4:
			if state(game.client.self_id)["party"] == client_id and state(client_id)["party"] == client_id:
				if game.party_options(client_id) != ["leave"] or game.party_options(1) != []:
					fail("Party menu options are wrong for members and outsiders")
					return
				finish()


func _dedicated_host_tick() -> void:
	if game.client.self_id != 0 or game.client.actors.has(1):
		fail("Dedicated host created a playing character")
		return
	for id: int in game.client.actors:
		if state(id)["equipment"].has("main_hand") and state(id)["cell"] == Vector2i(5, 7):
			saw_late_move = true
	_watch_ground(Vector2i(5, 7), "ember_cap")
	for id: int in game.client.actors:
		if state(id)["equipment"].get("ring_2", "") == "garnet_ring" and state(id)["level"] == Items.ACCESSORY_LEVEL \
				and not state(id).has("backpack"):
			saw_ring = true
	# Test-only: hand the client a level-20 ring at level 1, then level it up a second later, so
	# the client sees the server refuse and then accept the same equip request.
	for id: int in game.world.players:
		var player: Dictionary = game.world.players[id]
		if ring_given_at < 0.0 and saw_pickup and player["backpack"].has(""):
			player["backpack"][player["backpack"].find("")] = "garnet_ring"
			game.replication.publish_actor(id)
			ring_given_at = game._now()
		elif ring_given_at >= 0.0 and game._now() - ring_given_at > 1.0 and player["level"] < Items.ACCESSORY_LEVEL:
			player["level"] = Items.ACCESSORY_LEVEL
			game.replication.publish_actor(id)
	# Test-only shortcut on the server: carry the client to Cinder Crossing harbour instead of a long walk.
	for id: int in game.world.players:
		var player: Dictionary = game.world.players[id]
		if not ferried and saw_ring and player["cell"] == Vector2i(6, 7):
			var dock: Vector2i = game.world.arrival_cell("cinder_landing", game._now())
			player["cell"] = dock
			player["from"] = dock
			game.replication.publish_actor(id)
			ferried = true
		var lastlight: Vector2i = WorldMap.FERRYMEN["lastlight"]["cell"]
		if ferried and World.chebyshev(player["cell"], lastlight) <= World.TALK_RANGE:
			saw_voyage = true
	# Test-only: put a weak monster next to the client once it has landed in Lastlight.
	if saw_voyage and sparring == 0:
		for id: int in game.world.players:
			var cell: Vector2i = game.world.players[id]["cell"]
			for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if sparring == 0 and WorldMap.walkable(cell + step) and not game.world.occupied(cell + step, game._now()):
					var events: Array = []
					sparring = game.combat.spawn_monster("black_cat", 1, cell + step, game._now(), -1, events)
					game.world.monsters[sparring]["health"] = 6
					game.replication.handle_events(events)
	# Test-only: after the fight, grant a boss trophy and carry the client to the Relic keeper.
	if saw_voyage and sparring != 0 and not game.world.monsters.has(sparring) and not quest_ready:
		for id: int in game.world.players:
			var player: Dictionary = game.world.players[id]
			# Between Ysolde and Brannoc, in talking range of both.
			var beside: Vector2i = WorldMap.QUEST_GIVERS["relic_keeper"]["cell"] + Vector2i(2, 1)
			player["trophies"] = {"kharzul": 1}
			player["cell"] = beside
			player["from"] = beside
			game.replication.publish_actor(id)
			quest_ready = true
	for id: int in game.world.players:
		var player: Dictionary = game.world.players[id]
		if player["backpack"].has("cinderheart_bow") and relic_at < 0.0:
			relic_at = game._now()
		saw_relic = saw_relic or player["backpack"].has("cinderheart_bow")
		saw_task = saw_task or player["tasks"].has("boar_cull")
		# Test-only: carry the client to the vendor (hurt, to test potions), then Reedmere's banker, then
		# Warden Brask, each once the client has finished its business with the previous one.
		var next: String = ""
		if errand.is_empty() and relic_at >= 0.0 and game._now() - relic_at > 1.5:
			next = "cinder_vendor"
		elif errand == "cinder_vendor" and player["backpack"].has("health_potion#2"):
			next = "reedmere_banker"
		elif errand == "reedmere_banker" and player["depot"].has("health_potion#2"):
			next = "warden_brask"
		elif errand == "warden_brask" and player["tasks"].has("boar_cull"):
			next = "cinder_cellar"
		elif errand == "cinder_cellar" and saw_hunting_weapon and not player["equipment"].has("main_hand"):
			next = "artisan_cinder"
			# Test-only: resources for one rusted breastplate.
			player["backpack"][-3] = "leather_satchel"
			player["backpack"][-2] = "copper_ore#6"
			player["backpack"][-1] = "pine_log#2"
		elif errand == "artisan_cinder" and player["backpack"].has("rusted_breastplate") and World.carried(player["backpack"], "copper_ore") == 0:
			saw_crafted = true
			next = "copper_rock"
		saw_gathered = saw_gathered or (errand == "copper_rock" and World.carried(player["backpack"], "copper_ore") > 0
			or World.carried(player["backpack"], "pine_log") > 0 or World.carried(player["backpack"], "sunflax") > 0)
		if next == "copper_rock":
			# Test-only: the nearest copper rock to Cinder Crossing with open ground beside it.
			for distance: int in range(1, 120):
				for dx: int in range(-distance, distance + 1):
					for dy: int in [-distance, distance]:
						var rock := Vector2i(30, 30) + Vector2i(dx, dy)
						if errand != "copper_rock" and Crafting.node_at(rock) == "mining" and Crafting.band_at(rock) == 0:
							for step: Vector2i in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
								if errand != "copper_rock" and WorldMap.walkable(rock + step) and WorldMap.zone_at(rock + step).is_empty() \
										and not game.world.occupied(rock + step, game._now()):
									player["cell"] = rock + step
									player["from"] = rock + step
									player["facing"] = -step
									errand = "copper_rock"
			game.replication.publish_actor(id)
			next = ""
		saw_dungeon = saw_dungeon or WorldMap.dungeon_at(player["cell"]) == ["cinder_cellar", 0]
		if saw_dungeon and WorldMap.OVERWORLD.has_point(player["cell"]) and not hunting_weapon_given:
			var free: int = player["backpack"].find("")
			if free < 0:
				fail("No room for the hunting weapon fixture")
				return
			player["backpack"][free] = "alder_crook"
			hunting_weapon_given = true
			game.replication.publish_actor(id)
		saw_hunting_weapon = saw_hunting_weapon or player["equipment"].get("main_hand", "") == "alder_crook"
		if not next.is_empty():
			var cell: Vector2i = WorldMap.ENTRANCE_OF[next] if next == "cinder_cellar" else WorldMap.npc(next)["cell"]
			var goal: Vector2i = cell
			# A free tile beside the stairs, or in talking range on the keeper's side of a counter.
			for distance: int in range(1, World.TALK_RANGE + 1):
				for dy: int in range(-distance, distance + 1):
					for dx: int in range(-distance, distance + 1):
						var spot: Vector2i = goal + Vector2i(dx, dy)
						if cell == goal and WorldMap.walkable(spot) and (next == "cinder_cellar"
								and absi(dx) + absi(dy) == 1 or next != "cinder_cellar" and World.in_talk_range(spot, goal)):
							cell = spot
			player["cell"] = cell
			player["from"] = cell
			if next == "cinder_vendor":
				player["health"] = 1
				player["gold"] += 200
			game.replication.publish_actor(id)
			errand = next
	if saw_late_move and saw_drop and saw_pickup and saw_ring and saw_voyage and sparring != 0 and saw_relic \
			and saw_task and saw_dungeon and saw_hunting_weapon and saw_crafted and saw_gathered and not game.world.monsters.has(sparring) \
			and game.client.actors.is_empty():
		finish()


func _dedicated_client_tick(now: float) -> void:
	var own: int = game.client.self_id
	stage_messages[game.last_action_message] = true
	match stage:
		0:
			if game.client.actors.size() != 1 or own == 1 or game.client.actors.has(1):
				fail("Dedicated snapshot contains a phantom host")
				return
			game.api.equip_local("main_hand")
			game.api.move_local(Vector2i.DOWN)
			# Vocations are chosen at a trainer the host checks, never by a forged or distant request.
			game.gateway.request_vocation.rpc_id(1, 42)
			advance()
		1:
			if state(own)["cell"] == Vector2i(5, 7) and state(own)["equipment"].has("main_hand") \
					and stage_messages.has("Walk closer to a trainer") and state(own)["vocation"] == "druid" \
					and now - stage_since > 0.25:
				game.api.move_item_local({"type": "backpack", "index": 0}, {"type": "ground", "cell": Vector2i(5, 7)})
				# PvP is switched only at the warden the host checks, never by a forged or distant request.
				game.gateway.request_pvp.rpc_id(1, "reedmere_warden", true)
				advance()
		2:
			if game.client.ground_view.get(Vector2i(5, 7), []) == ["ember_cap"] and stage_messages.has("Walk closer to the warden") \
					and not state(own)["pvp"] and now - stage_since > 0.2:
				game.api.move_item_local({"type": "ground", "cell": Vector2i(5, 7)}, {"type": "backpack"})
				advance()
		3:
			if not game.client.ground_view.has(Vector2i(5, 7)) and state(own)["backpack"][0] == "ember_cap" \
					and now - stage_since > 0.2:
				advance()
		4:
			var ring: int = state(own)["backpack"].find("garnet_ring")
			if ring >= 0 and state(own)["level"] == 1:
				game.api.move_item_local({"type": "backpack", "index": ring}, {"type": "equipment", "slot": "ring_2"})
				advance()
		5:
			if stage_messages.has("The Garnet ring requires level %d" % Items.ACCESSORY_LEVEL):
				if state(own)["equipment"].has("ring_2"):
					fail("The server equipped a ring below its level")
					return
				advance()
		6:
			if state(own)["level"] == Items.ACCESSORY_LEVEL and now - stage_since > 0.2:
				game.api.move_item_local({"type": "backpack", "index": state(own)["backpack"].find("garnet_ring")},
					{"type": "equipment", "slot": "ring_2"})
				advance()
		7:
			if state(own)["equipment"].get("ring_2", "") == "garnet_ring" and not state(own)["backpack"].has("garnet_ring"):
				game.api.travel_local("cinder_landing", "lastlight")
				advance()
		8:
			if stage_messages.has("Walk closer to the ferryman"):
				game.api.move_local(Vector2i.RIGHT)
				advance()
		9:
			var landing: Vector2i = WorldMap.FERRYMEN["cinder_landing"]["cell"]
			if World.chebyshev(state(own)["cell"], landing) <= World.TALK_RANGE and now - stage_since > 0.25:
				game.gateway.request_travel.rpc_id(1, "cinder_landing", "nowhere")
				advance()
		10:
			if stage_messages.has("That ferryman does not sail there"):
				game.gateway.request_travel.rpc_id(1, 5, null)
				advance()
		11:
			if stage_messages.has("Unknown ferryman"):
				game.api.travel_local("cinder_landing", "lastlight")
				advance()
		12:
			var fare: int = WorldMap.FERRYMEN["cinder_landing"]["routes"]["lastlight"]
			if World.chebyshev(state(own)["cell"], WorldMap.FERRYMEN["lastlight"]["cell"]) <= World.TALK_RANGE \
					and state(own)["gold"] == World.START_GOLD - fare and _saw_part("Lastlight"):
				advance()
		13:
			for id: int in game.client.monsters:
				if World.chebyshev(game.client.monsters[id]["state"]["cell"], state(own)["cell"]) == 1:
					sparring = id
					game.gateway.request_target.rpc_id(1, "not-a-creature")
					advance()
		14:
			if stage_messages.has("Unknown target"):
				game.api.target_local(sparring)
				advance()
		15:
			if state(own)["target"] == sparring:
				game.api.cast_local("piercing_shot")
				advance()
			elif not game.client.monsters.has(sparring):
				# The auto-attack killed the weak monster before the target update arrived.
				advance()
		16:
			for effect: Dictionary in game.client.effects:
				saw_hit = saw_hit or effect["kind"] == "text"
			if not game.client.monsters.has(sparring) and state(own)["experience"] > 0 and state(own)["target"] == 0 and saw_hit:
				advance()
		17:
			var keeper: Vector2i = WorldMap.QUEST_GIVERS["relic_keeper_kharzul"]["cell"]
			if state(own)["trophies"].get("kharzul", 0) == 1 and World.chebyshev(state(own)["cell"], keeper) <= World.TALK_RANGE:
				# Ysolde keeps only Morvain's relics and sends the client to Brannoc.
				game.api.quest_local("relic_keeper", "cinderheart_bow")
				advance()
		18:
			if _saw_start("Ysolde only keeps"):
				game.api.quest_local("relic_keeper_kharzul", "cinderheart_bow")
				advance()
		19:
			var relic: int = state(own)["backpack"].find("cinderheart_bow")
			if relic >= 0 and state(own)["trophies"].is_empty():
				game.api.move_item_local({"type": "backpack", "index": relic}, {"type": "ground", "cell": state(own)["cell"]})
				advance()
		20:
			if stage_messages.has("The Cinderheart bow is bound to you") and now - stage_since > 0.2:
				if not state(own)["backpack"].has("cinderheart_bow") or game.client.ground_view.has(state(own)["cell"]):
					fail("A bound relic left the backpack")
					return
				advance()
		21:
			if World.chebyshev(state(own)["cell"], WorldMap.npc("cinder_vendor")["cell"]) <= World.TALK_RANGE:
				game.gateway.request_buy.rpc_id(1, "cinder_vendor", "abyssal_greathelm", 1)
				advance()
		22:
			if stage_messages.has("The vendor does not sell that"):
				game.api.sell_local("cinder_vendor", state(own)["backpack"].find("cinderheart_bow"))
				advance()
		23:
			if stage_messages.has("The vendor will not buy the Cinderheart bow"):
				game.api.buy_local("cinder_vendor", "health_potion", 3)
				advance()
		24:
			var potions: int = state(own)["backpack"].find("health_potion#3")
			if potions >= 0 and state(own)["gold"] == World.START_GOLD - WorldMap.FERRYMEN["cinder_landing"]["routes"]["lastlight"] + 200 - 60 \
					and now - stage_since > 0.2:
				game.api.drink_local(potions)
				advance()
		25:
			if state(own)["backpack"].has("health_potion#2") and state(own)["health"] > 1 \
					and World.chebyshev(state(own)["cell"], WorldMap.npc("reedmere_banker")["cell"]) <= World.TALK_RANGE:
				game.api.bank_local("reedmere_banker", "deposit", 10)
				advance()
		26:
			if state(own).get("bank", 0) == 10 and now - stage_since > 0.2:
				game.gateway.request_bank.rpc_id(1, "reedmere_banker", "withdraw", 999)
				advance()
		27:
			if stage_messages.has("You only have 10 gold in the bank"):
				game.api.move_item_local({"type": "backpack", "index": state(own)["backpack"].find("health_potion#2")}, {"type": "depot"})
				advance()
		28:
			if state(own)["depot"][0] == "health_potion#2" and not state(own)["backpack"].has("health_potion#2") \
					and World.chebyshev(state(own)["cell"], WorldMap.npc("warden_brask")["cell"]) <= World.TALK_RANGE:
				game.api.task_local("warden_brask", "boar_cull", "accept")
				advance()
		29:
			if state(own)["tasks"].get("boar_cull", -1) == 0 and _saw_start("Boar cull"):
				advance()
		30:
			var stairway: Vector2i = WorldMap.ENTRANCE_OF["cinder_cellar"]
			if World.chebyshev(state(own)["cell"], stairway) == 1 and now - stage_since > 0.2:
				game.api.move_local(stairway - state(own)["cell"])
				advance()
		31:
			var stairway: Vector2i = WorldMap.ENTRANCE_OF["cinder_cellar"]
			if WorldMap.dungeon_at(state(own)["cell"]) == ["cinder_cellar", 0] and _only_dungeon_monsters(state(own)["cell"]) \
					and now - stage_since > World.MOVE_SECONDS + 0.05:
				game.api.move_local(Vector2i.LEFT)
				advance()
			elif now - stage_since > 4.0:
				var cells: Array = game.client.monsters.values().map(func(monster: Dictionary) -> Vector2i: return monster["state"]["cell"])
				fail("Stuck entering the cellar at %s (%s), message '%s', monsters %s" % [state(own)["cell"],
					WorldMap.dungeon_at(state(own)["cell"]), game.last_action_message, cells])
			elif World.chebyshev(state(own)["cell"], stairway) == 1 and now - stage_since > 0.5:
				# The first step may hit the movement cooldown; try again.
				game.api.move_local(stairway - state(own)["cell"])
				stage_since = now
		32:
			if WorldMap.OVERWORLD.has_point(state(own)["cell"]) and _saw_part("Cinder Crossing") \
					and not _has_dungeon_monster() and state(own)["backpack"].has("alder_crook"):
				game.api.move_item_local({"type": "backpack", "index": state(own)["backpack"].find("alder_crook")},
					{"type": "equipment", "slot": "main_hand"})
				advance()
		33:
			if state(own)["equipment"].get("main_hand", "") == "alder_crook" and now - stage_since > World.ITEM_SECONDS + 0.05:
				game.api.move_item_local({"type": "equipment", "slot": "main_hand"}, {"type": "backpack"})
				advance()
		34:
			if state(own)["backpack"].has("copper_ore#6") and World.chebyshev(state(own)["cell"], WorldMap.npc("artisan_cinder")["cell"]) <= World.TALK_RANGE:
				game.gateway.request_craft.rpc_id(1, "artisan_cinder", "voidrend", 1)
				advance()
		35:
			if stage_messages.has("Unknown recipe"):
				game.api.craft_local("artisan_cinder", "rusted_breastplate", 1)
				advance()
		36:
			if state(own)["backpack"].has("rusted_breastplate") and not state(own)["backpack"].has("copper_ore#6") \
					and int(state(own).get("skills", {}).get("smithing", [1, 0])[1]) > 0 and now - stage_since > 0.2:
				game.api.move_item_local({"type": "backpack", "index": state(own)["backpack"].find("leather_satchel")}, {"type": "bag", "bag": 0})
				advance()
		37:
			if state(own)["bags"][0] == "leather_satchel" and state(own)["backpack"].size() == World.main_size(state(own)) + 6 \
					and Crafting.node_at(state(own)["cell"] + state(own)["facing"]) == "mining":
				game.gateway.request_gather.rpc_id(1, "a rock")
				advance()
		38:
			if stage_messages.has("Unknown place"):
				game.api.gather_nearby()
				advance()
		39:
			if state(own).has("gathering"):
				advance()
		40:
			if not state(own).has("gathering") and not game.worked_nodes.is_empty() and now - stage_since > 0.2:
				var gathered: int = 0
				for kind: String in ["copper_ore", "pine_log", "sunflax", "river_perch"]:
					gathered += World.carried(state(own)["backpack"], kind)
				if gathered == 0:
					fail("Gathering finished without a resource")
					return
				finish()


## A dedicated host with a save folder: passes once a character has joined, left, and been
## written as exactly one signed save.
func _persist_host_tick() -> void:
	if restarted < 0:
		var folder: String = game.session.store.dir + "/characters"
		restarted = 1 if DirAccess.dir_exists_absolute(folder) and not DirAccess.get_files_at(folder).is_empty() else 0
	had_player = had_player or not game.world.players.is_empty()
	# A refused peer sits in _closing_peers until it is disconnected.
	refused_duplicate = refused_duplicate or not game.session.closing_peers.is_empty()
	if had_player and game.world.players.is_empty() and multiplayer_peers_gone() and (restarted == 0 or refused_duplicate):
		var saves: PackedStringArray = DirAccess.get_files_at(game.session.store.dir + "/characters")
		var json: Array = Array(saves).filter(func(file: String) -> bool: return file.ends_with(".json"))
		if json.size() != 1 or game.session.store.load_character(String(json[0]).get_basename())["status"] != "ok":
			fail("Expected one valid save, found %s" % saves)
			return
		finish()


func multiplayer_peers_gone() -> bool:
	return game.multiplayer.get_peers().is_empty()


## First visit: a druid steps down from its spawn and equips its weapon, then leaves.
func _persist_first_tick(now: float) -> void:
	var own: int = game.client.self_id
	match stage:
		0:
			if game.client.actors.has(own) and state(own)["cell"] == Vector2i(5, 6):
				game.api.move_local(Vector2i.DOWN)
				advance()
		1:
			if state(own)["cell"] == Vector2i(5, 7) and now - stage_since > 0.25:
				game.api.equip_local("main_hand")
				advance()
		2:
			if state(own)["equipment"].get("main_hand", "") == "sapling_rod":
				finish()


## After the host restarted: the same identity (asking for a knight) gets the saved druid back.
func _persist_return_tick(now: float) -> void:
	var own: int = game.client.self_id
	match stage:
		0:
			if game.client.actors.has(own) and game.last_action_message.begins_with("Welcome back"):
				var mine: Dictionary = state(own)
				if mine["vocation"] != "druid" or mine["cell"] != Vector2i(5, 7) \
						or mine["equipment"].get("main_hand", "") != "sapling_rod" or mine["backpack"].has("sapling_rod"):
					fail("The saved character was not restored: %s" % mine)
					return
				print("BRIMHOLT_PERSIST_IN")
				advance()
		1:
			# Stay until the second login with this identity (started on BRIMHOLT_PERSIST_IN) has
			# been refused: the host warns whoever plays the character.
			if game.last_action_message == game.session.DUPLICATE_LOGIN_WARNING and now - stage_since > 0.5:
				finish()


func _only_dungeon_monsters(own_cell: Vector2i) -> bool:
	if game.client.monsters.is_empty():
		return false
	for id: int in game.client.monsters:
		var cell: Vector2i = game.client.monsters[id]["state"]["cell"]
		if WorldMap.dungeon_at(cell) != WorldMap.dungeon_at(own_cell) or World.chebyshev(cell, own_cell) > game.replication.INTEREST_RADIUS:
			return false
	return true


func _has_dungeon_monster() -> bool:
	for id: int in game.client.monsters:
		if not WorldMap.dungeon_at(game.client.monsters[id]["state"]["cell"]).is_empty():
			return true
	return false


func _loss_host_tick() -> void:
	# A host bot (a training dummy) must reach the client like any player.
	if game.bots.bots.is_empty() and not game.session.spawn_bot("knight", 20, "dummy").is_empty():
		fail("The host could not add a bot")
		return
	for id: int in game.client.actors:
		if id != 1 and not game.bots.is_bot(id) and state(id)["equipment"].has("helmet"):
			finish()
			return


func _loss_client_tick() -> void:
	if stage == 0 and game.session.connected and game.client.actors.has(game.client.self_id) and game.client.actors.keys().any(func(id: int) -> bool:
			return game.client.actors[id]["state"].get("bot", false) and game.client.actors[id]["state"]["level"] == 20):
		if game.bots.bots.size() != 0 or not game.session.spawn_bot("knight", 1, "dummy").begins_with("Only the host"):
			fail("A client holds or can create bots")
			return
		# This host was started without --allow-start-vocation: asking for a vocation gets an Adventurer.
		if state(game.client.self_id)["vocation"] != "adventurer":
			fail("A client chose its own starting vocation (%s)" % state(game.client.self_id)["vocation"])
			return
		game.api.equip_local("helmet")
		advance()
	elif stage == 1 and not game.session.connected:
		if game.session.status_message != "The host disconnected. Your LAN session has ended." \
				or not game.client.actors.is_empty() or not game.client.ground_view.is_empty() or game.client.self_id != 0:
			fail("Host loss did not report an error and clear stale actors")
		else:
			finish()
