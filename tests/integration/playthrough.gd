extends SceneTree
## Automated playthrough bot. Two of these join a real dedicated server as a Knight and a
## Sorcerer and play through every system using the same client calls as the UI: gear up,
## walk out of town with pathfinding, hunt the nearest monsters with spells and healing, loot
## gold, walk to Cinder Landing and sail to Mossford, walk to Reedmere and sail to Blackreed
## Isle, then duel there (white skull, self-defence, death, item loss, looting the corpse).
## Rendering goes to an offscreen buffer; screenshots land in .tools/playtest. Run it through
## tools/testing/playtest.py, which starts the server and writes the report.
## Output lines: PLAYTEST <role> <phase> <ok|fail|info|finding> <detail>, PLAYTEST_SHOT <file> <caption>.

const World = preload("res://game/core/world.gd")
const Combat = preload("res://game/core/combat.gd")
const Balance = preload("res://game/data/balance.gd")
const ATTACK_SPELLS: Dictionary = {"knight": "brutal_blow", "sorcerer": "ember_bolt", "paladin": "piercing_shot", "druid": "frost_bolt"}
const HEAL_SPELLS: Dictionary = {"knight": "light_heal", "sorcerer": "light_heal", "paladin": "light_heal", "druid": "mend"}
const HUNT_SECONDS: float = 200.0
const WALK_SECONDS: float = 120.0
const HUNT_LEVEL: int = 3

var role: String = ""
var game: Node
var screen: SubViewport
var astar := AStarGrid2D.new()
var phase: String = ""
var phase_since: float = 0.0
var path: Array[Vector2i] = []
var goal := Vector2i(-1, -1)
var stuck_since: float = 0.0
var last_cell := Vector2i(-1, -1)
var next_action: float = 0.0
var shots: int = 0
var kills: int = 0
var deaths: int = 0
var last_target: int = 0
var hunt_spots: Array[Vector2i] = []
var spot_index: int = 0
var quiet_since: float = 0.0
var flags: Dictionary = {}
var partner_last_cell := Vector2i(-1, -1)
var finished: bool = false
var previous_cell := Vector2i(-1, -1)


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--bot="):
			role = arg.trim_prefix("--bot=")
	call_deferred("_start")


func _start() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_size(Vector2i(64, 64))
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	DisplayServer.window_set_position(usable.position + Vector2i(64 * (1 if role == "knight" else 0), 0))
	# Report anything from the OS that could end the session, so a stray shortcut is visible.
	root.close_requested.connect(func() -> void: report("info", "ignored a close request from the OS"))
	root.focus_entered.connect(func() -> void: report("info", "the window took keyboard focus"))
	screen = SubViewport.new()
	screen.size = Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	screen.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	screen.canvas_item_default_texture_filter = root.canvas_item_default_texture_filter
	screen.gui_embed_subwindows = true
	root.add_child(screen)
	# RPCs address nodes by path; root this branch's multiplayer at the buffer so the game is
	# "Main" here exactly as on the server.
	set_multiplayer(MultiplayerAPI.create_default_interface(), screen.get_path())
	game = load("res://game/main.tscn").instantiate()
	game.close_ends_session = false
	screen.add_child(game)
	astar.region = Rect2i(0, 0, World.width(), World.height())
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()
	for y: int in World.height():
		for x: int in World.width():
			var cell := Vector2i(x, y)
			if not World.walkable(cell):
				astar.set_point_solid(cell)
	var spawns: Array = World.MONSTER_SPAWNS.filter(func(spawn: Dictionary) -> bool: return World.zone_at(spawn["cell"]).is_empty())
	spawns.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return Vector2(a["cell"]).distance_to(Vector2(11, 18)) < Vector2(b["cell"]).distance_to(Vector2(11, 18)))
	for spawn: Dictionary in spawns.slice(0, 3):
		hunt_spots.append(spawn["cell"])
	_enter("join")


# ---------------------------------------------------------------- helpers

func now() -> float:
	return Time.get_ticks_msec() / 1000.0


func report(kind: String, detail: String) -> void:
	print("PLAYTEST %s %s %s %s" % [role, phase, kind, detail])


func shot(name: String, caption: String) -> void:
	shots += 1
	var file: String = "res://.tools/playtest/%02d-%s-%s.png" % [shots, role, name]
	var image: Image = screen.get_texture().get_image()
	if image != null and image.save_png(file) == OK:
		print("PLAYTEST_SHOT %s %s" % [file.trim_prefix("res://.tools/playtest/"), caption])


func _enter(next: String) -> void:
	phase = next
	phase_since = now()
	path.clear()
	report("info", "started")


func me() -> Dictionary:
	return game.actors[game.self_id]["state"] if game.actors.has(game.self_id) else {}


func partner() -> int:
	for id: int in game.actors:
		if id != game.self_id:
			return id
	return 0


func partner_state() -> Dictionary:
	var id: int = partner()
	return game.actors[id]["state"] if id != 0 else {}


func stats() -> Dictionary:
	var state: Dictionary = me()
	return World.stats(state["level"], state["equipment"], state["vocation"])


func throttle(seconds: float = 0.35) -> bool:
	if now() < next_action:
		return false
	next_action = now() + seconds
	return true


## Spawn neighbourhoods cost more so travel routes avoid monsters a level-1 party cannot fight.
func avoid_monsters(enabled: bool) -> void:
	for spawn: Dictionary in World.MONSTER_SPAWNS:
		for dy: int in range(-9, 10):
			for dx: int in range(-9, 10):
				var cell: Vector2i = spawn["cell"] + Vector2i(dx, dy)
				if astar.is_in_boundsv(cell) and not astar.is_point_solid(cell):
					astar.set_point_weight_scale(cell, 30.0 if enabled else 1.0)


## Walks one step along an A* path to goal; returns true on arrival (within reach tiles).
func walk_to(target: Vector2i, reach: int = 0) -> bool:
	var cell: Vector2i = me()["cell"]
	if Combat.distance(cell, target) <= reach:
		path.clear()
		return true
	if target != goal or path.is_empty():
		goal = target
		path.assign(astar.get_id_path(cell, target))
		if path.is_empty():
			return false
	while not path.is_empty() and path[0] == cell:
		path.pop_front()
	if cell != last_cell:
		last_cell = cell
		stuck_since = now()
	elif now() - stuck_since > 1.5:
		# Something stands in the way: step aside and plan again.
		stuck_since = now()
		path.clear()
		for step: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT]:
			if World.walkable(cell + step):
				game.move_local(step)
				break
		return false
	if not path.is_empty() and game._move_pending_since < 0.0 and now() >= game._next_move_attempt:
		var step: Vector2i = path[0] - cell
		if absi(step.x) + absi(step.y) == 1:
			game.move_local(step)
		else:
			path.clear()
	return false


func nearest_monster(radius: int) -> int:
	var best: int = 0
	var best_distance: int = radius + 1
	for id: int in game.monsters:
		var gap: int = Combat.distance(me()["cell"], game.monsters[id]["state"]["cell"])
		if gap < best_distance:
			best = id
			best_distance = gap
	return best


func dock_cell(ferryman: String) -> Vector2i:
	var center: Vector2i = World.FERRYMEN[ferryman]["cell"]
	for radius: int in range(1, World.TALK_RANGE + 1):
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				if World.walkable(center + Vector2i(dx, dy)):
					return center + Vector2i(dx, dy)
	return center


## Uses the ferry exactly like a player: the person menu's Travel, then the route button.
func sail(ferryman: String, destination: String) -> bool:
	game.talk_to(ferryman)
	for child: Node in game._travel_list.get_children():
		if child is Button and child.text.begins_with(World.FERRYMEN[destination]["place"]):
			if child.disabled:
				report("fail", "cannot afford the fare to %s (gold %d)" % [destination, me().get("gold", 0)])
				game._close_travel()
				return false
			child.pressed.emit()
			return true
	return false


func fight(spell_target: bool = true, radius: int = Combat.TARGET_RANGE) -> void:
	var state: Dictionary = me()
	if state["health"] < stats()["health"] * 0.55 and throttle(0.6):
		game.cast_local(HEAL_SPELLS[state["vocation"]])
		return
	if game.own_target() == 0:
		var monster: int = nearest_monster(radius)
		if monster != 0 and throttle(0.3):
			game.target_local(monster)
		return
	if spell_target and throttle(0.6):
		game.cast_local(ATTACK_SPELLS[state["vocation"]])


func track_events() -> void:
	var target: int = game.own_target()
	if last_target < 0 and target == 0 and not game.monsters.has(last_target):
		kills += 1
		if kills == 1:
			shot("first-kill", "First kill: floating experience and the gold it dropped")
	last_target = target
	if game.last_action_message.begins_with("You are dead") and not flags.get("death_seen", false):
		flags["death_seen"] = true
		deaths += 1
		report("info" if phase == "duel" else "finding", "died at %s: %s" % [previous_cell, game.last_action_message])
		if phase not in ["duel", "recover"] and deaths == 1:
			flags["corpse"] = previous_cell
			flags["after_gear"] = phase
			if game.last_action_message.contains("keep your items"):
				report("ok", "beginner protection: nothing to recover, carrying on from town")
				_enter("gear")
			else:
				_enter("recover")
	elif not game.last_action_message.begins_with("You are dead"):
		flags["death_seen"] = false
	if game.last_action_message.begins_with("You advanced") and not flags.get("level_shot_%d" % me()["level"], false):
		flags["level_shot_%d" % me()["level"]] = true
		report("ok", game.last_action_message)
		shot("level-up", "Level up: %s" % game.last_action_message)


# ---------------------------------------------------------------- phases

func _process(delta: float) -> bool:
	if delta > 1.0:
		report("finding", "the process stalled for %.1f s (macOS may pause hidden windows)" % delta)
	if game == null or finished:
		return false
	if not game.connected or me().is_empty():
		if phase != "join" and now() - phase_since > 5.0:
			report("fail", "lost the connection: %s (connected %s, self %d, actors %s, message '%s')" % [game._status_message,
				game.connected, game.self_id, game.actors.keys(), game.last_action_message])
			_finish()
		elif phase == "join" and now() - phase_since > 20.0:
			report("fail", "could not join: %s" % game._status_message)
			_finish()
		return false
	track_events()
	if me()["health"] < flags.get("last_health", me()["health"]) and me()["cell"] == previous_cell:
		flags["hurt_at"] = now()
	flags["last_health"] = me()["health"]
	previous_cell = me()["cell"]
	match phase:
		"join": _join()
		"gear": _gear()
		"walk_out": _walk_out()
		"hunt": _hunt()
		"to_port": _to_port()
		"sail_coast": _sail_coast()
		"to_reedmere": _to_reedmere()
		"sail_isle": _sail_isle()
		"duel": _duel()
		"recover": _recover()
	return false


func _join() -> void:
	if partner() == 0:
		return
	if not flags.get("joined_reported", false):
		flags["joined_reported"] = true
		report("ok", "joined as %s with %d gold; partner is a %s" % [me()["vocation"], me()["gold"], partner_state()["vocation"]])
		shot("joined", "Joined Cinder Crossing as a %s" % me()["vocation"].capitalize())
	# The Knight invites, the Sorcerer accepts through the same options as the right-click menu.
	if me().get("party", 0) == 0:
		if role == "knight" and not partner() in me().get("invited", []) and throttle(1.0):
			game.party_local("invite", partner())
		elif role == "sorcerer" and "join" in game.party_options(partner()) and throttle(0.5):
			game.party_local("join", partner())
		if now() - phase_since < 20.0:
			return
		report("fail", "could not form a party")
	else:
		report("ok", "formed a party (leader: %s)" % ("me" if me()["party"] == game.self_id else "partner"))
	_enter("gear")


func _gear() -> void:
	var state: Dictionary = me()
	for index: int in World.BACKPACK_SIZE:
		var kind: String = state["backpack"][index]
		if kind.is_empty():
			continue
		var slot: String = World.slot_for(kind, state["equipment"])
		if not slot.is_empty() and not state["equipment"].has(slot):
			if throttle(0.3):
				game.move_item_local({"type": "backpack", "index": index}, {"type": "equipment", "slot": slot})
			return
	report("ok", "equipped %s; attack %d, defense %d" % [", ".join(state["equipment"].values()), stats()["attack"], stats()["defense"]])
	shot("geared", "Start kit equipped from the backpack")
	var next: String = flags.get("after_gear", "walk_out")
	avoid_monsters(next not in ["walk_out", "hunt"])
	_enter(next)


func _walk_out() -> void:
	if walk_to(hunt_spots[0], 5) or nearest_monster(6) != 0:
		report("ok", "left town and reached the first hunting ground at %s in %.0f s" % [me()["cell"], now() - phase_since])
		shot("hunting-ground", "Out of town at the nearest monsters")
		quiet_since = now()
		_enter("hunt")
	elif now() - phase_since > WALK_SECONDS:
		report("fail", "could not reach the hunting ground")
		_enter("to_port")


func _hunt() -> void:
	var sorcerer_level: int = me()["level"] if role == "sorcerer" else partner_state().get("level", 1)
	var elapsed: float = now() - phase_since
	if sorcerer_level >= HUNT_LEVEL or elapsed > HUNT_SECONDS:
		# Finish the current fight first: walking off drags the pack along to the port.
		if (game.own_target() != 0 or nearest_monster(3) != 0) and elapsed < HUNT_SECONDS + 30.0:
			fight(true, 3)
			return
		if sorcerer_level < HUNT_LEVEL:
			report("finding", "the Sorcerer did not reach level %d in %.0f s of hunting (%d kills, %d/%d experience)"
				% [HUNT_LEVEL, elapsed, kills, me()["experience"], Balance.experience_to_next(me()["level"])])
		report("ok", "hunt over: %d kills, level %d, %d experience, %d gold, %d deaths" % [kills, me()["level"],
			me()["experience"], me()["gold"], deaths])
		var materials: Array = me()["backpack"].filter(func(kind: String) -> bool: return World.ITEMS.get(kind, {}).has("value"))
		report("info", "carrying %d monster materials: %s" % [materials.size(), ", ".join(materials)])
		if role == "knight":
			var gap: int = partner_state().get("level", 1) - me()["level"]
			report("ok" if absi(gap) <= 1 else "finding",
				"party sharing kept the tanking Knight within %d level(s) of the Sorcerer" % absi(gap))
		game.target_local(0)
		avoid_monsters(true)
		_enter("to_port")
		return
	if nearest_monster(Combat.TARGET_RANGE) != 0 or game.own_target() != 0:
		quiet_since = now()
		if game.own_target() != 0 and not flags.get("fight_shot", false) and not game.effects.is_empty():
			flags["fight_shot"] = true
			shot("fighting", "Fighting: locked target, spells, floating damage")
		fight()
		return
	var room: bool = me()["backpack"].has("")
	for cell: Vector2i in game.ground_view:
		var stack: Array = game.ground_view[cell]
		var top: String = stack[-1] if not stack.is_empty() else ""
		# Gold is worth a detour; materials only when close, so looting does not pull into other spawns.
		var reach: int = 8 if top == "gold_coins" else (3 if room and World.ITEMS.get(top, {}).has("value") else -1)
		if Combat.distance(cell, me()["cell"]) <= reach:
			if walk_to(cell, 1) and throttle(0.3):
				var gold: int = me()["gold"]
				game.move_item_local({"type": "ground", "cell": cell}, {"type": "backpack"})
				if top == "gold_coins" and not flags.get("loot_reported", false):
					flags["loot_reported"] = true
					report("ok", "picked up dropped gold (purse was %d)" % gold)
				elif top != "gold_coins" and not flags.get("material_reported", false):
					flags["material_reported"] = true
					report("ok", "picked up a monster material from a loot table: %s" % World.ITEMS[top]["name"])
			return
	if now() - quiet_since > 2.0 and walk_to(hunt_spots[spot_index], 3):
		spot_index = (spot_index + 1) % hunt_spots.size()
		quiet_since = now()


## While travelling, fight off anything that catches up instead of walking into a crowd.
func defend() -> bool:
	if now() - flags.get("hurt_at", -INF) < 3.0 and nearest_monster(2) != 0:
		fight(true, 2)
		return true
	if game.own_target() != 0:
		game.target_local(0)
	return false


func _to_port() -> void:
	if defend():
		return
	if walk_to(dock_cell("cinder_landing")):
		report("ok", "reached Cinder Landing in %.0f s" % (now() - phase_since))
		_enter("sail_coast")
	elif now() - phase_since > WALK_SECONDS:
		report("fail", "could not reach Cinder Landing from %s" % me()["cell"])
		_finish()


func _sail_coast() -> void:
	if Combat.distance(me()["cell"], World.FERRYMEN["mossford"]["cell"]) <= World.TALK_RANGE:
		report("ok", "sailed to Mossford; gold now %d" % me()["gold"])
		shot("mossford", "Arrived at Mossford by ferry")
		_enter("to_reedmere")
	elif throttle(1.2) and not sail("cinder_landing", "mossford"):
		_finish()
	elif now() - phase_since > 15.0:
		report("fail", "the ferry did not sail: %s" % game.last_action_message)
		_finish()


func _to_reedmere() -> void:
	if defend():
		return
	if walk_to(dock_cell("reedmere")):
		report("ok", "walked to Reedmere in %.0f s" % (now() - phase_since))
		_enter("sail_isle")
	elif now() - phase_since > WALK_SECONDS:
		report("fail", "could not reach Reedmere from %s" % me()["cell"])
		_finish()


func _sail_isle() -> void:
	if World.zone_at(me()["cell"]).get("pvp", false):
		report("ok", "sailed to Blackreed Isle; banner says: %s" % game._zone_label.text)
		shot("island", "Arrived on Blackreed Isle: PvP banner")
		_enter("duel")
	elif throttle(1.2) and not sail("reedmere", "blackreed_isle"):
		_finish()
	elif now() - phase_since > 15.0:
		report("fail", "the island ferry did not sail: %s" % game.last_action_message)
		_finish()


## The Knight attacks the unmarked Sorcerer (white skull), the Sorcerer fights back briefly
## (self-defence, no skull), and the Knight kills him: unjustified kill, item loss, looting.
func _duel() -> void:
	var other: int = partner()
	var them: Dictionary = partner_state()
	# Party members cannot fight each other, so the Knight leaves before the duel.
	if me().get("party", 0) != 0:
		if role == "knight" and throttle(1.0):
			game.party_local("leave", 0)
		return
	# The duel clock starts once both have arrived on the island.
	if not flags.get("both_here", false):
		if not them.is_empty() and World.zone_at(them["cell"]).get("pvp", false):
			flags["both_here"] = true
			phase_since = now()
		elif now() - phase_since > 240.0 or them.is_empty():
			report("fail", "the partner never arrived on the island")
			_finish()
			return
		else:
			return
	var elapsed: float = now() - phase_since
	if elapsed > 120.0:
		report("fail", "duel did not finish")
		_finish()
		return
	if role == "knight":
		if not flags.get("victim_down", false):
			if them.is_empty() or not World.zone_at(them["cell"]).get("pvp", false):
				if flags.get("attacked", false):
					flags["victim_down"] = true
					flags["drop_near"] = partner_last_cell
				return
			partner_last_cell = them["cell"]
			flags["victim_level"] = them["level"]
			if not flags.get("attacked", false):
				if throttle(0.5):
					game.target_local(other)
				if game.own_target() == other:
					flags["attacked"] = true
					report("info", "attacked the unmarked Sorcerer")
				return
			if me()["skull"] == "white" and not flags.get("skull_reported", false):
				flags["skull_reported"] = true
				report("ok", "white skull for attacking an unmarked player")
			if Combat.distance(me()["cell"], them["cell"]) > 1 or not throttle(0.6):
				return
			game.cast_local("brutal_blow")
			return
		if not flags.get("loot_done", false):
			if flags.get("victim_level", 1) < Combat.PROTECTION_LEVEL and me().get("unjustified", 0) >= 1:
				flags["loot_done"] = true
				report("ok", "unjustified kill counted; the level-%d Sorcerer dropped nothing (beginner protection below level %d)"
					% [flags["victim_level"], Combat.PROTECTION_LEVEL])
				return
			if me().get("unjustified", 0) >= 1 and not flags.get("kill_reported", false):
				flags["kill_reported"] = true
				report("ok", "unjustified kill counted (%d of 3 before a red skull); message: %s" % [me()["unjustified"], game.last_action_message])
			for cell: Vector2i in game.ground_view:
				if Combat.distance(cell, flags["drop_near"]) <= Combat.SPILL_RADIUS and World.zone_at(cell).get("pvp", false):
					if walk_to(cell, 1) and throttle(0.4):
						report("info", "pick up %s from %s at %s (gold %d, last message '%s')" % [game.ground_view[cell].back(), cell,
							me()["cell"], me()["gold"], game.last_action_message])
						game.move_item_local({"type": "ground", "cell": cell}, {"type": "backpack"})
						flags["picked"] = flags.get("picked", 0) + 1
					if me()["backpack"].count("") < World.BACKPACK_SIZE or flags.get("picked", 0) >= 6:
						flags["loot_done"] = true
						report("ok", "looted the fallen Sorcerer's dropped items: %s" % ", ".join(me()["backpack"].filter(func(k: String) -> bool: return not k.is_empty())))
						shot("looting", "Knight with a white skull looting the Sorcerer's dropped items")
					return
			if flags.get("picked", 0) > 0:
				flags["loot_done"] = true
				report("ok", "looted everything the Sorcerer dropped (%d pickups); gold now %d, backpack %s" % [flags["picked"],
					me()["gold"], ", ".join(me()["backpack"].filter(func(k: String) -> bool: return not k.is_empty()))])
				shot("looting", "Knight with a white skull after looting the Sorcerer's dropped items")
				return
			if elapsed > 90.0:
				var nearby: Array = game.ground_view.keys().filter(func(cell: Vector2i) -> bool:
					return Combat.distance(cell, flags["drop_near"]) <= 8)
				report("fail", "found no dropped items near %s; own cell %s, ground nearby %s, gold %d" % [flags["drop_near"],
					me()["cell"], nearby.map(func(cell: Vector2i) -> String: return "%s=%s" % [cell, game.ground_view[cell]]), me()["gold"]])
				flags["loot_done"] = true
			return
		report("ok", "duel complete")
		_finish()
		return
	# Sorcerer.
	if not flags.get("died", false):
		if flags.get("death_seen", false) or (deaths > 0 and not World.zone_at(me()["cell"]).get("pvp", false)):
			flags["died"] = true
			var state: Dictionary = me()
			var protected: bool = flags.get("level_before", 1) < Combat.PROTECTION_LEVEL
			var kept: bool = state["gold"] == flags.get("gold_before", -1) and state["equipment"].size() == flags.get("worn_before", -1)
			var lost: bool = state["backpack"].count("") == World.BACKPACK_SIZE and state["gold"] == 0
			report("ok" if (kept if protected else lost) else "fail", "%s; after death: gold %d, worn %s, level %d, respawned at %s"
				% ["beginner protection kept everything" if protected else "lost backpack and gold", state["gold"],
				state["equipment"].keys(), state["level"], state["cell"]])
			shot("after-death", "Respawned in Cinder Crossing after the duel")
			_finish()
			return
		flags["level_before"] = me()["level"]
		flags["gold_before"] = me()["gold"]
		flags["worn_before"] = me()["equipment"].size()
		if them.get("skull", "") == "white" and not flags.get("skull_seen", false):
			flags["skull_seen"] = true
			report("ok", "the Knight shows a white skull")
			shot("white-skull", "The attacking Knight wears a white skull")
		if flags.get("skull_seen", false) and not flags.get("defended", false):
			if game.own_target() != partner():
				if throttle(0.5):
					game.target_local(partner())
				return
			if not flags.has("defend_since"):
				flags["defend_since"] = now()
			if now() - flags["defend_since"] > 3.0:
				flags["defended"] = true
				game.target_local(0)
				report("ok" if me()["skull"] == "" else "fail", "fought back in self-defence; own skull: '%s'" % me()["skull"])


## After dying, walk back to where you fell and pick your belongings up again, as in Tibia.
func _recover() -> void:
	var corpse: Vector2i = flags["corpse"]
	if now() - phase_since > WALK_SECONDS:
		report("fail", "could not recover belongings at %s" % corpse)
		_enter("gear")
		return
	if nearest_monster(2) != 0:
		fight(true, 2)
		return
	for cell: Vector2i in game.ground_view:
		var stack: Array = game.ground_view[cell]
		# Own belongings are gold and gear; monster materials from earlier kills stay behind.
		if Combat.distance(cell, corpse) <= Combat.SPILL_RADIUS and not stack.is_empty() \
				and not World.ITEMS.get(stack[-1], {}).has("value"):
			if walk_to(cell, 1) and throttle(0.3):
				game.move_item_local({"type": "ground", "cell": cell}, {"type": "backpack"})
			return
	if Combat.distance(me()["cell"], corpse) > 4:
		walk_to(corpse, 2)
		return
	report("ok", "walked back and recovered belongings: %d gold, backpack %s" % [me()["gold"],
		", ".join(me()["backpack"].filter(func(kind: String) -> bool: return not kind.is_empty()))])
	shot("recovered", "Recovered belongings from where the character fell")
	_enter("gear")


func _finish() -> void:
	if finished:
		return
	finished = true
	report("info", "done after %d kills and %d deaths" % [kills, deaths])
	print("PLAYTEST_DONE %s" % role)
	await game.leave_game()
	quit()
