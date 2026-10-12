extends Node2D

const World = preload("res://game/world.gd")
const SpriteArt = preload("res://game/sprite_art.gd")
const WorldView = preload("res://game/world_view.gd")
const Keybinds = preload("res://game/keybinds.gd")
const Combat = preload("res://game/combat.gd")
const Monsters = preload("res://game/monsters.gd")
const Spells = preload("res://game/spells.gd")
const MESSAGE_SECONDS: float = 4.0
const ControlsMenu = preload("res://game/controls_menu.gd")
const BAR_SLOT: float = 44.0
const NPC_SERVICES: Dictionary = {"travel": "Travel", "buy": "Buy", "quests": "Quests"}
## Tibia-style game window: 15x11 tiles at 2x, centred on your character.
const ZOOM: float = 2.0
const VIEW_TILES: Vector2i = Vector2i(15, 11)
const VIEW_ORIGIN: Vector2 = Vector2(16, 76)
const VIEW_SIZE: Vector2 = Vector2(VIEW_TILES * World.TILE_SIZE) * ZOOM
const PANEL_ORIGIN: Vector2 = Vector2(992, 76)
const SLOT_STEP: float = 36.0
const Balance = preload("res://game/balance.gd")
## Tibia-style paperdoll grid: necklace/helmet/charm, main hand/armor/off hand, ring/-/ring.
const PAPERDOLL: Dictionary = {
	"necklace": Vector2(0, 0), "helmet": Vector2(1, 0), "charm": Vector2(2, 0),
	"main_hand": Vector2(0, 1), "armor": Vector2(1, 1), "off_hand": Vector2(2, 1),
	"ring_1": Vector2(0, 2), "ring_2": Vector2(2, 2),
}
const MINIMAP_SCALE: float = 2.0
const PVP_TINT: Color = Color("#c43c32")
const MAP_COLORS: Dictionary = {
	".": Color("#4e693b"), ",": Color("#a08a6a"), "~": Color("#2d5a78"), "#": Color("#9196a0"),
	"T": Color("#26401f"), ":": Color("#d8c48a"), "=": Color("#b0aca4"), "b": Color("#8a5a34"),
}
const STAT_LABELS: Dictionary = {
	"health": "Health", "mana": "Mana", "attack": "Attack", "defense": "Defense", "critical": "Critical",
	"regen": "Regen", "healing": "Healing",
}

var world := World.new()
var combat := Combat.new(world)
var actors: Dictionary = {}
## Client view of monsters, interpolated like actors.
var monsters: Dictionary = {}
## Short-lived visuals: floating numbers, missiles, and spell areas.
var effects: Array = []
var ground_view: Dictionary = {}
var self_id: int = 0
var connected: bool = false
var hosting: bool = false
var dedicated: bool = false
var port: int = World.PORT
var last_action_message: String = ""
var peer: ENetMultiplayerPeer
var _pending_peers: Dictionary = {}
var _closing_peers: Dictionary = {}
var _request_windows: Dictionary = {}
var _joining_since: float = -1.0
var _leaving: bool = false
var _move_pending_since: float = -1.0
var _next_move_attempt: float = 0.0
var _status_message: String = "Offline — host a world or join a LAN address."
var _address: LineEdit
var _vocation: OptionButton
var _status: Label
var _action: Label
var _backpack_label: Label
var _stat_values: Dictionary = {}
var _slots: Array[Control] = []
var _view: ColorRect
var _world_view: Node2D
var _map_texture: ImageTexture
var _minimap: Control
var _world_map: Control
var _travel_panel: PanelContainer
var _travel_list: VBoxContainer
var _talking_to: String = ""
var keybinds := Keybinds.new()
## Automated tests and bots run in hidden windows and set this false, so a stray OS close
## request (a click or shortcut meant for another app) cannot end their session.
var close_ends_session: bool = true
var _bar_slots: Array[Control] = []
var _bar_menu: PopupMenu
var _bar_menu_slot: int = -1
var _controls: PanelContainer
var _npc_menu: PopupMenu
var _npc_menu_target: String = ""
var _zone_label: Label
var _zone_name: String = ""
var _vitals: Control
var _start_panel: PanelContainer
var _start_status: Label
var _start_address: LineEdit
var _start_vocation: OptionButton
var _shown_message: String = ""
var _message_since: float = 0.0


func _ready() -> void:
	keybinds.load_saved()
	_build_ui()
	get_tree().auto_accept_quit = false
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_left)
	multiplayer.connected_to_server.connect(_connected_to_host)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_host_lost)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for arg: String in args:
		if arg.begins_with("--vocation="):
			var choice: String = arg.trim_prefix("--vocation=")
			if not Balance.VOCATIONS.has(choice):
				_fail("Vocation must be one of: %s." % ", ".join(Balance.VOCATIONS.keys()))
				get_tree().quit(1)
				return
			_vocation.select(Balance.VOCATIONS.keys().find(choice))
	for arg: String in args:
		if arg.begins_with("--port="):
			var value: String = arg.trim_prefix("--port=")
			if not value.is_valid_int() or int(value) < 1 or int(value) > 65535:
				_fail("Port must be an integer from 1 to 65535.")
				get_tree().quit(1)
				return
			port = int(value)
	dedicated = "--headless-server" in args
	if "--host" in args or dedicated:
		host_game()
		if not connected:
			get_tree().quit(1)
			return
	for arg: String in args:
		if arg.begins_with("--join="):
			_address.text = arg.trim_prefix("--join=")
			join_game()
			if _joining_since < 0.0:
				get_tree().quit(1)
				return


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _process(delta: float) -> void:
	var now: float = _now()
	if _joining_since >= 0.0 and now - _joining_since > 8.0:
		_fail("Connection timed out. Check the LAN address, UDP port %d and firewall." % port)
	if _move_pending_since >= 0.0 and now - _move_pending_since > 3.0:
		_fail("The host stopped answering movement requests.")
	if hosting and not _leaving:
		for id: int in _pending_peers.keys():
			if now - _pending_peers[id] > 5.0:
				_pending_peers.erase(id)
				_reject_connection(id, "Client handshake timed out.")
		for id: int in multiplayer.get_peers():
			if not world.players.has(id) and not _pending_peers.has(id):
				if not _closing_peers.has(id):
					_pending_peers[id] = now
	if hosting and not _leaving:
		_handle_events(combat.tick(now))
	for group: Dictionary in [actors, monsters]:
		for id: int in group:
			var actor: Dictionary = group[id]
			actor["elapsed"] = minf(actor["elapsed"] + delta, actor["duration"])
			var weight: float = 1.0
			if actor["duration"] > 0.0:
				weight = actor["elapsed"] / actor["duration"]
			actor["visual"] = actor["start"].lerp(Vector2(actor["state"]["cell"]), weight)
	var clock: float = Time.get_ticks_msec() / 1000.0
	effects = effects.filter(func(effect: Dictionary) -> bool: return clock - effect["born"] < 1.1)
	if connected and self_id != 0 and not _address.has_focus() and not _controls.visible \
			and _move_pending_since < 0.0 and now >= _next_move_attempt:
		var direction: Vector2i = _input_direction()
		if direction == Vector2i.ZERO:
			direction = _chase_direction()
		if direction != Vector2i.ZERO:
			move_local(direction)
	_update_labels()
	for slot: Control in _slots:
		var kind: String = _local_item(slot.get_meta("location"))
		slot.tooltip_text = item_tooltip(kind)
		slot.queue_redraw()
	_world_view.position = (VIEW_SIZE / 2.0 - camera_focus() * ZOOM).round()
	_world_view.queue_redraw()
	if not _talking_to.is_empty() and (not actors.has(self_id) or World.chebyshev(
			actors[self_id]["state"]["cell"], World.FERRYMEN[_talking_to]["cell"]) > World.TALK_RANGE):
		_close_travel()
	_update_zone()
	_start_panel.visible = not connected and not dedicated
	if _start_panel.visible:
		_start_status.text = _status_message
	_vitals.queue_redraw()
	for slot: Control in _bar_slots:
		slot.queue_redraw()
	_minimap.queue_redraw()
	if _world_map.visible:
		_world_map.queue_redraw()


func _input_direction() -> Vector2i:
	for pair: Array in [["move_up", Vector2i.UP], ["move_down", Vector2i.DOWN],
			["move_left", Vector2i.LEFT], ["move_right", Vector2i.RIGHT]]:
		if keybinds.is_held(pair[0]):
			return pair[1]
	return Vector2i.ZERO


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo() or _address.has_focus():
		return
	if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
		if not _world_map.visible and not _travel_panel.visible and not _controls.visible and own_target() != 0:
			target_local(0)
		_world_map.hide()
		_close_travel()
		_controls.hide()
		return
	var key: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	var action: String = keybinds.action_for(key)
	if action.begins_with("slot_"):
		use_bar_slot(int(action.trim_prefix("slot_")) - 1)
	elif not action.is_empty():
		_run_bar_action(action)


## Runs the action-bar entry in a slot (0-8).
func use_bar_slot(slot: int) -> void:
	if slot >= 0 and slot < Keybinds.SLOTS:
		_run_bar_action(keybinds.bar[slot])


func _run_bar_action(entry: String) -> void:
	if entry == "world_map":
		_world_map.visible = not _world_map.visible
	elif not connected:
		return
	elif entry == "pick_up":
		pick_up_local()
	elif entry == "target_nearest":
		target_nearest()
	elif entry.begins_with("spell:"):
		cast_local(entry.trim_prefix("spell:"))
	elif entry.begins_with("toggle_"):
		equip_local(entry.trim_prefix("toggle_"))


func _reset_session() -> void:
	if peer != null:
		peer.close()
	peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	world = World.new()
	combat = Combat.new(world)
	actors.clear()
	monsters.clear()
	effects.clear()
	ground_view.clear()
	if _travel_panel != null:
		_close_travel()
		_world_map.hide()
	_pending_peers.clear()
	_closing_peers.clear()
	_request_windows.clear()
	self_id = 0
	hosting = false
	connected = false
	_joining_since = -1.0
	_leaving = false
	_move_pending_since = -1.0
	_next_move_attempt = 0.0
	last_action_message = ""


func _fail(message: String) -> void:
	_reset_session()
	_status_message = message
	push_error(message)
	_update_labels()


func host_game() -> void:
	_reset_session()
	peer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(port, World.MAX_PLAYERS)
	if error != OK:
		_fail("Cannot host on UDP port %d: %s" % [port, error_string(error)])
		return
	multiplayer.multiplayer_peer = peer
	hosting = true
	connected = true
	ground_view = world.ground_snapshot()
	if not dedicated:
		self_id = 1
		if not world.add_player(1, _now(), selected_vocation()):
			_fail("The host could not find a valid spawn.")
			return
		_apply_actor(world.export_player(1, _now(), true))
		_fill_spell_slots(selected_vocation())
	_handle_events(combat.populate(_now()))
	_status_message = "Hosting on UDP %d%s" % [port, " (dedicated)" if dedicated else " — you are the host"]
	get_viewport().gui_release_focus()
	print("BRIMHOLT_HOST_READY port=%d" % port)


func join_game() -> void:
	var address: String = _address.text.strip_edges()
	_reset_session()
	if address.is_empty():
		_fail("Enter the host's LAN IP address first.")
		return
	peer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(address, port)
	if error != OK:
		_fail("Cannot connect to %s:%d: %s" % [address, port, error_string(error)])
		return
	multiplayer.multiplayer_peer = peer
	_joining_since = _now()
	_status_message = "Connecting to %s:%d…" % [address, port]
	get_viewport().gui_release_focus()


func leave_game() -> void:
	var leaving_peer: ENetMultiplayerPeer = peer
	_leaving = true
	connected = false
	_move_pending_since = -1.0
	_joining_since = -1.0
	if leaving_peer != null:
		if hosting:
			for id: int in multiplayer.get_peers():
				leaving_peer.disconnect_peer(id)
		elif 1 in multiplayer.get_peers():
			leaving_peer.disconnect_peer(1)
		await get_tree().create_timer(0.2).timeout
	if peer == leaving_peer:
		_reset_session()
		_status_message = "Disconnected — host or join to play again."


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and close_ends_session:
		await leave_game()
		get_tree().quit()


func _peer_connected(id: int) -> void:
	if peer != null and (hosting or id == 1):
		peer.get_peer(id).set_timeout(16, 1000, 5000)


func _connected_to_host() -> void:
	hello.rpc_id(1, World.signature(), selected_vocation())


func _connection_failed() -> void:
	_fail("Could not reach the host. Check the address, UDP %d and firewall." % port)


func _host_lost() -> void:
	if not _leaving:
		_fail("The host disconnected. Your LAN session has ended.")


func _peer_left(id: int) -> void:
	if not hosting:
		return
	_pending_peers.erase(id)
	_closing_peers.erase(id)
	_request_windows.erase(id)
	if world.players.has(id):
		world.remove_player(id)
		actors.erase(id)
		if not _leaving:
			actor_left.rpc(id)


@rpc("any_peer", "call_remote", "reliable")
func hello(map_signature: Variant, vocation: Variant) -> void:
	if not hosting:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender <= 1 or sender not in multiplayer.get_peers() \
			or world.players.has(sender) or _closing_peers.has(sender):
		return
	_pending_peers.erase(sender)
	if typeof(map_signature) != TYPE_STRING or map_signature != World.signature():
		_reject_connection(sender, "World/protocol mismatch. Use the same project files as the host.")
		return
	if typeof(vocation) != TYPE_STRING or not Balance.VOCATIONS.has(vocation):
		_reject_connection(sender, "Unknown vocation.")
		return
	if not world.add_player(sender, _now(), vocation):
		_reject_connection(sender, "This world is full (%d players maximum)." % World.MAX_PLAYERS)
		return
	welcome.rpc_id(sender, world.snapshot(_now(), sender), world.ground_snapshot(), combat.monster_snapshot(_now()))
	_publish_actor(sender)


func _reject_connection(id: int, reason: String) -> void:
	if _closing_peers.has(id):
		return
	_closing_peers[id] = true
	var rejecting_peer: ENetMultiplayerPeer = peer
	connection_rejected.rpc_id(id, reason)
	await get_tree().create_timer(0.2).timeout
	if peer != null and peer == rejecting_peer and hosting and id in multiplayer.get_peers():
		peer.disconnect_peer(id)


@rpc("authority", "call_remote", "reliable")
func connection_rejected(reason: String) -> void:
	_fail(reason)


@rpc("authority", "call_remote", "reliable")
func welcome(states: Dictionary, ground_state: Dictionary, monster_states: Dictionary) -> void:
	if hosting:
		return
	actors.clear()
	for id: int in states:
		_apply_actor(states[id])
	ground_view = ground_state.duplicate(true)
	monsters.clear()
	for id: int in monster_states:
		_apply_monster(monster_states[id])
	self_id = multiplayer.get_unique_id()
	if not actors.has(self_id):
		_fail("The host sent a snapshot without your player.")
		return
	connected = true
	_joining_since = -1.0
	_status_message = "Connected to %s:%d" % [_address.text, port]
	_fill_spell_slots(actors[self_id]["state"]["vocation"])


func move_local(direction: Vector2i) -> void:
	if not connected or self_id == 0 or _move_pending_since >= 0.0:
		return
	_move_pending_since = _now()
	_next_move_attempt = _now() + World.MOVE_SECONDS
	if hosting:
		_handle_move(1, direction)
	else:
		request_move.rpc_id(1, direction)


func equip_local(slot: String) -> void:
	if not connected or self_id == 0:
		return
	if hosting:
		_handle_equipment(1, slot)
	else:
		request_equipment.rpc_id(1, slot)


func move_item_local(source: Dictionary, target: Dictionary) -> void:
	if not connected or self_id == 0:
		return
	if hosting:
		_handle_item_move(1, source, target)
	else:
		request_item_move.rpc_id(1, source, target)


## Picks up the top item on your tile, or else on the tile you face.
func pick_up_local() -> void:
	if not actors.has(self_id):
		return
	var state: Dictionary = actors[self_id]["state"]
	var cell: Vector2i = state["cell"]
	if not ground_view.has(cell):
		cell += Vector2i(state["facing"])
	move_item_local({"type": "ground", "cell": cell}, {"type": "backpack"})


func travel_local(ferryman: String, destination: String) -> void:
	if not connected or self_id == 0:
		return
	if hosting:
		_handle_travel(1, ferryman, destination)
	else:
		request_travel.rpc_id(1, ferryman, destination)


# ---------------------------------------------------------------- combat

func target_local(target: int) -> void:
	if not connected or self_id == 0:
		return
	if hosting:
		_handle_target(1, target)
	else:
		request_target.rpc_id(1, target)


func cast_local(spell: String) -> void:
	if not connected or self_id == 0:
		return
	if hosting:
		_handle_spell(1, spell)
	else:
		request_spell.rpc_id(1, spell)


## Locks the nearest monster within targeting range.
func target_nearest() -> void:
	if not actors.has(self_id):
		return
	var own: Vector2i = actors[self_id]["state"]["cell"]
	var best: int = 0
	var best_distance: int = Combat.TARGET_RANGE + 1
	for id: int in monsters:
		var gap: int = Combat.distance(own, monsters[id]["state"]["cell"])
		if gap < best_distance:
			best = id
			best_distance = gap
	if best != 0:
		target_local(best)


func own_target() -> int:
	return actors[self_id]["state"].get("target", 0) if actors.has(self_id) else 0


func creature_view(id: int) -> Dictionary:
	if id > 0:
		return actors.get(id, {})
	return monsters.get(id, {}) if id < 0 else {}


## Walks toward a locked target that is out of reach, like Tibia's chase mode.
func _chase_direction() -> Vector2i:
	var target: Dictionary = creature_view(own_target())
	if target.is_empty() or not actors.has(self_id):
		return Vector2i.ZERO
	var own: Dictionary = actors[self_id]["state"]
	var goal: Vector2i = target["state"]["cell"]
	if Combat.in_reach(own["cell"], goal, Combat.VOCATION_RANGE.get(own["vocation"], 1)):
		return Vector2i.ZERO
	return Combat.path_step(own["cell"], goal, func(cell: Vector2i) -> bool:
		for group: Dictionary in [actors, monsters]:
			for id: int in group:
				if id != self_id and group[id]["state"]["cell"] == cell:
					return true
		return false)


func _creature_at(cell: Vector2i) -> int:
	for probe: Vector2i in [cell, cell + Vector2i.DOWN]:
		for group: Dictionary in [monsters, actors]:
			for id: int in group:
				if id != self_id and Vector2i(group[id]["visual"].round()) == probe:
					return id
	return 0


@rpc("any_peer", "call_remote", "reliable")
func request_target(target: Variant) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if _valid_sender(sender):
		_handle_target(sender, target)


@rpc("any_peer", "call_remote", "reliable")
func request_spell(spell: Variant) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if _valid_sender(sender):
		_handle_spell(sender, spell)


func _handle_target(id: int, target: Variant) -> void:
	var result: Dictionary = combat.set_target(id, target, _now())
	if result["ok"]:
		_publish_actor(id)
	else:
		_send_feedback(id, result["reason"], 0.0, false)


func _handle_spell(id: int, spell: Variant) -> void:
	var result: Dictionary = combat.cast(id, spell, _now())
	if result["ok"]:
		_handle_events(result["events"])
	else:
		_send_feedback(id, result["reason"], 0.0, false)


## Replicates combat events: visuals immediately, then each changed creature once, then messages.
func _handle_events(events: Array) -> void:
	var players_changed: Dictionary = {}
	var monsters_changed: Dictionary = {}
	var messages: Array = []
	for event: Dictionary in events:
		match event["kind"]:
			"player":
				players_changed[event["id"]] = true
			"monster":
				monsters_changed[event["id"]] = monsters_changed.get(event["id"], false) or event["movement"]
			"monster_gone":
				monsters_changed.erase(event["id"])
				monsters.erase(event["id"])
				for peer_id: int in _remote_players():
					monster_gone.rpc_id(peer_id, event["id"])
			"ground":
				_publish_ground(event["cells"])
			"message":
				messages.append(event)
			_:
				_show_effect(event)
				for peer_id: int in _remote_players():
					combat_event.rpc_id(peer_id, event)
	for id: int in players_changed:
		if world.players.has(id):
			_publish_actor(id)
	for id: int in monsters_changed:
		if world.monsters.has(id):
			var state: Dictionary = combat.export_monster(id, _now())
			_apply_monster(state)
			for peer_id: int in _remote_players():
				monster_updated.rpc_id(peer_id, state)
	for event: Dictionary in messages:
		if world.players.has(event["id"]):
			_send_feedback(event["id"], event["text"], 0.0, false)


@rpc("authority", "call_remote", "reliable")
func monster_updated(state: Dictionary) -> void:
	_apply_monster(state)


@rpc("authority", "call_remote", "reliable")
func monster_gone(id: int) -> void:
	monsters.erase(id)


@rpc("authority", "call_remote", "reliable")
func combat_event(event: Dictionary) -> void:
	_show_effect(event)


func _apply_monster(state: Dictionary) -> void:
	var id: int = state["id"]
	var remaining: float = state["remaining"]
	var total: float = maxf(state.get("duration", World.MOVE_SECONDS), 0.01)
	var start: Vector2 = Vector2(state["from"]).lerp(Vector2(state["cell"]), 1.0 - clampf(remaining / total, 0.0, 1.0))
	if monsters.has(id) and monsters[id]["state"]["cell"] == state["cell"]:
		start = monsters[id]["visual"]
	monsters[id] = {"state": state.duplicate(true), "start": start, "visual": start, "duration": remaining, "elapsed": 0.0}


func _map_point(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * World.TILE_SIZE


func _show_effect(event: Dictionary) -> void:
	var born: float = Time.get_ticks_msec() / 1000.0
	match event.get("kind", ""):
		"hit":
			var view: Dictionary = creature_view(event["target"])
			if view.is_empty() or (event["amount"] <= 0 and event["style"] != "damage"):
				return
			var styles: Dictionary = {
				"damage": [str(event["amount"]), Color("#ff4a3a")], "critical": ["%d!" % event["amount"], Color("#ffa030")],
				"heal": ["+%d" % event["amount"], Color("#6ae07a")], "experience": ["%d xp" % event["amount"], Color("#f4f4f4")],
			}
			var style: Array = styles.get(event["style"], styles["damage"])
			effects.append({"kind": "text", "pos": (view["visual"] + Vector2(0.5, 0.5)) * World.TILE_SIZE,
				"text": style[0], "color": style[1], "born": born, "big": event["style"] == "critical"})
		"missile":
			effects.append({"kind": "missile", "from": _map_point(event["from"]), "to": _map_point(event["to"]),
				"color": event["color"], "born": born})
		"area":
			effects.append({"kind": "area", "cells": event["cells"], "color": event["color"], "born": born})


func _draw_vitals() -> void:
	if not actors.has(self_id) or not actors[self_id]["state"].has("mana"):
		return
	var state: Dictionary = actors[self_id]["state"]
	var font: Font = ThemeDB.fallback_font
	var rows: Array = [[state["health"], state["max_health"], Color("#c0392b"), "HP"],
		[state["mana"], state["max_mana"], Color("#2e6fd0"), "MP"]]
	for index: int in rows.size():
		var row: Array = rows[index]
		var area := Rect2(0, index * 17, _vitals.size.x, 14)
		_vitals.draw_rect(area, Color(0, 0, 0, 0.6))
		_vitals.draw_rect(Rect2(area.position, Vector2(area.size.x * clampf(float(row[0]) / maxf(1.0, row[1]), 0.0, 1.0), 14)), row[2])
		_vitals.draw_rect(area, Color("#0b0e12"), false, 1.0)
		_vitals.draw_string(font, area.position + Vector2(4, 11), "%s %d / %d" % [row[3], row[0], row[1]],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)


## Replaces spells of other vocations and fills empty bar slots with this vocation's spells.
func _fill_spell_slots(vocation: String) -> void:
	var own: Array[String] = Spells.for_vocation(vocation)
	for slot: int in Keybinds.SLOTS:
		var entry: String = keybinds.bar[slot]
		if entry.begins_with("spell:") and entry.trim_prefix("spell:") not in own:
			keybinds.bar[slot] = ""
	for spell: String in own:
		if "spell:" + spell in keybinds.bar:
			continue
		for slot: int in range(4, Keybinds.SLOTS) + range(0, 4):
			if keybinds.bar[slot].is_empty():
				keybinds.bar[slot] = "spell:" + spell
				break


func _valid_sender(sender: int) -> bool:
	if not hosting or sender <= 1 or not world.players.has(sender) or _closing_peers.has(sender):
		return false
	var now: float = _now()
	var window: Dictionary = _request_windows.get(sender, {"start": now, "count": 0})
	if now - window["start"] >= 1.0:
		window = {"start": now, "count": 0}
	window["count"] += 1
	_request_windows[sender] = window
	if window["count"] > 30:
		_reject_connection(sender, "Too many commands. Reconnect and slow down.")
		return false
	return true


@rpc("any_peer", "call_remote", "reliable")
func request_move(direction: Vector2i) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if _valid_sender(sender):
		_handle_move(sender, direction)


@rpc("any_peer", "call_remote", "reliable")
func request_equipment(slot: String) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if _valid_sender(sender):
		_handle_equipment(sender, slot)


@rpc("any_peer", "call_remote", "reliable")
func request_item_move(source: Variant, target: Variant) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if _valid_sender(sender):
		_handle_item_move(sender, source, target)


@rpc("any_peer", "call_remote", "reliable")
func request_travel(ferryman: Variant, destination: Variant) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if _valid_sender(sender):
		_handle_travel(sender, ferryman, destination)


func _handle_travel(id: int, ferryman: Variant, destination: Variant) -> void:
	var result: Dictionary = world.travel(id, ferryman, destination, _now())
	if result["ok"]:
		_publish_actor(id)
		_send_feedback(id, result["message"], 0.0, false)
	else:
		_send_feedback(id, result["reason"], 0.0, false)


func _handle_move(id: int, direction: Vector2i) -> void:
	var result: Dictionary = world.move(id, direction, _now())
	if result["ok"]:
		_publish_actor(id, true)
	else:
		_send_feedback(id, result["reason"], result["retry"], true)


func _handle_equipment(id: int, slot: String) -> void:
	_publish_item_result(id, world.toggle_equipment(id, slot, _now()))


func _handle_item_move(id: int, source: Variant, target: Variant) -> void:
	_publish_item_result(id, world.move_item(id, source, target, _now()))


func _publish_item_result(id: int, result: Dictionary) -> void:
	if result["ok"]:
		_publish_actor(id)
		_publish_ground(result["ground"])
	else:
		_send_feedback(id, result["reason"], 0.0, false)


func _send_feedback(id: int, reason: String, retry: float, movement: bool) -> void:
	if id == 1:
		action_feedback(reason, retry, movement)
	else:
		action_feedback.rpc_id(id, reason, retry, movement)


@rpc("authority", "call_remote", "reliable")
func action_feedback(reason: String, retry: float, movement: bool) -> void:
	last_action_message = reason
	if movement:
		_move_pending_since = -1.0
		_next_move_attempt = _now() + retry + 0.02


func _remote_players() -> Array[int]:
	var result: Array[int] = []
	for id: int in world.players:
		if id != 1 and not _closing_peers.has(id) and id in multiplayer.get_peers():
			result.append(id)
	return result


## Everyone receives public state; only the owner receives its backpack.
func _publish_actor(id: int, movement: bool = false) -> void:
	var now: float = _now()
	_apply_actor(world.export_player(id, now, id == self_id), movement)
	for peer_id: int in _remote_players():
		actor_updated.rpc_id(peer_id, world.export_player(id, now, peer_id == id), movement)


func _publish_ground(cells: Array) -> void:
	for cell: Vector2i in cells:
		var stack: Array = world.ground_stack(cell)
		_apply_ground(cell, stack)
		for peer_id: int in _remote_players():
			ground_updated.rpc_id(peer_id, cell, stack)


@rpc("authority", "call_remote", "reliable")
func ground_updated(cell: Vector2i, stack: Array) -> void:
	_apply_ground(cell, stack)


func _apply_ground(cell: Vector2i, stack: Array) -> void:
	if stack.is_empty():
		ground_view.erase(cell)
	else:
		ground_view[cell] = stack.duplicate()


@rpc("authority", "call_remote", "reliable")
func actor_updated(state: Dictionary, movement: bool) -> void:
	_apply_actor(state, movement)


func _apply_actor(state: Dictionary, movement: bool = false) -> void:
	var id: int = state["id"]
	var remaining: float = state["remaining"]
	var start: Vector2 = Vector2(state["from"]).lerp(
		Vector2(state["cell"]), 1.0 - remaining / World.MOVE_SECONDS)
	if actors.has(id) and actors[id]["state"]["cell"] == state["cell"]:
		start = actors[id]["visual"]
	actors[id] = {
		"state": state.duplicate(true), "start": start, "visual": start,
		"duration": remaining, "elapsed": 0.0, "received": _now(),
	}
	if id == self_id:
		if movement:
			_move_pending_since = -1.0
			_next_move_attempt = _now() + remaining + 0.01


@rpc("authority", "call_remote", "reliable")
func actor_left(id: int) -> void:
	actors.erase(id)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_view = ColorRect.new()
	_view.color = Color("#07090c")
	_view.position = VIEW_ORIGIN
	_view.size = VIEW_SIZE
	_view.clip_contents = true
	_view.set_drag_forwarding(_map_drag, _map_can_drop, _map_drop)
	_view.gui_input.connect(_map_input)
	layer.add_child(_view)
	_world_view = WorldView.new()
	_world_view.game = self
	_world_view.scale = Vector2.ONE * ZOOM
	_view.add_child(_world_view)
	var row := HBoxContainer.new()
	row.position = Vector2(16, 12)
	layer.add_child(row)
	var title := Label.new()
	title.text = "BRIMHOLT  ·  " + World.WORLD_NAME + "   "
	title.add_theme_font_size_override("font_size", 20)
	row.add_child(title)
	_add_button(row, "Host", host_game)
	_address = LineEdit.new()
	_address.text = "127.0.0.1"
	_address.placeholder_text = "Host LAN IP"
	_address.custom_minimum_size.x = 200
	row.add_child(_address)
	_add_button(row, "Join", join_game)
	_add_button(row, "Leave", leave_game)
	_add_button(row, "Controls", func() -> void: _controls.visible = not _controls.visible)
	_vitals = Control.new()
	_vitals.position = VIEW_ORIGIN + Vector2(10, 8)
	_vitals.size = Vector2(220, 34)
	_vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vitals.draw.connect(_draw_vitals)
	_vocation = OptionButton.new()
	for vocation: String in Balance.VOCATIONS:
		_vocation.add_item(Balance.VOCATIONS[vocation]["name"])
	_vocation.select(Balance.VOCATIONS.keys().find(Balance.DEFAULT_VOCATION))
	_vocation.tooltip_text = "Vocation used when you host or join"
	row.add_child(_vocation)
	_status = Label.new()
	_status.position = Vector2(16, 48)
	layer.add_child(_status)
	_action = Label.new()
	_action.position = VIEW_ORIGIN + Vector2(0, VIEW_SIZE.y - 40 - BAR_SLOT - 8)
	_action.size = Vector2(VIEW_SIZE.x, 32)
	_action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action.add_theme_color_override("font_color", Color("#f4f0e6"))
	_action.add_theme_color_override("font_outline_color", Color("#101010"))
	_action.add_theme_constant_override("outline_size", 6)
	layer.add_child(_action)
	_build_inventory(layer)
	_build_maps(layer)
	_build_action_bar(layer)
	_build_travel_panel(layer)
	_build_start_panel(layer)
	_zone_label = Label.new()
	_zone_label.position = VIEW_ORIGIN + Vector2(0, 44)
	_zone_label.size = Vector2(VIEW_SIZE.x, 24)
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zone_label.add_theme_color_override("font_color", Color("#ff8a7a"))
	_zone_label.add_theme_color_override("font_outline_color", Color("#1a0605"))
	_zone_label.add_theme_constant_override("outline_size", 6)
	_zone_label.visible = false
	layer.add_child(_zone_label)
	layer.add_child(_vitals)
	layer.move_child(_world_map, -1)
	layer.move_child(_travel_panel, -1)
	_npc_menu = PopupMenu.new()
	_npc_menu.id_pressed.connect(_npc_service_chosen)
	add_child(_npc_menu)
	_controls = ControlsMenu.new()
	_controls.visible = false
	_controls.setup(keybinds, func() -> void: _controls.hide())
	_controls.position = VIEW_ORIGIN + Vector2(VIEW_SIZE.x / 2.0 - 190, 40)
	layer.add_child(_controls)


## The start menu shown until you host or join: vocation, Host, and Join with an address.
func _build_start_panel(layer: CanvasLayer) -> void:
	_start_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#151a20")
	style.border_color = Color("#3a4450")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(18)
	_start_panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_start_panel.add_child(box)
	var title := Label.new()
	title.text = "Welcome to Brimholt"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var intro := Label.new()
	intro.text = "Host a game for your friends, or join one on your network.\nEveryone starts in Cinder Crossing."
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.modulate = Color("#a7b0b8")
	box.add_child(intro)
	var vocation_row := HBoxContainer.new()
	box.add_child(vocation_row)
	var vocation_label := Label.new()
	vocation_label.text = "Vocation"
	vocation_label.custom_minimum_size.x = 90
	vocation_row.add_child(vocation_label)
	_start_vocation = OptionButton.new()
	for vocation: String in Balance.VOCATIONS:
		_start_vocation.add_item("%s  (%s)" % [Balance.VOCATIONS[vocation]["name"], Balance.VOCATIONS[vocation]["role"]])
	_start_vocation.select(_vocation.selected)
	_start_vocation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_vocation.item_selected.connect(func(index: int) -> void: _vocation.select(index))
	_vocation.item_selected.connect(func(index: int) -> void: _start_vocation.select(index))
	vocation_row.add_child(_start_vocation)
	var host := Button.new()
	host.text = "Host a game"
	host.pressed.connect(host_game)
	box.add_child(host)
	var join_row := HBoxContainer.new()
	box.add_child(join_row)
	_start_address = LineEdit.new()
	_start_address.text = _address.text
	_start_address.placeholder_text = "Host's LAN IP, e.g. 192.168.1.20"
	_start_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_address.text_changed.connect(func(text: String) -> void: _address.text = text)
	_start_address.text_submitted.connect(func(_text: String) -> void: join_game())
	join_row.add_child(_start_address)
	var join := Button.new()
	join.text = "Join"
	join.pressed.connect(join_game)
	join_row.add_child(join)
	_start_status = Label.new()
	_start_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_start_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_start_status.custom_minimum_size.x = 380
	_start_status.modulate = Color("#e4bd8a")
	box.add_child(_start_status)
	_start_panel.custom_minimum_size = Vector2(420, 0)
	_start_panel.position = VIEW_ORIGIN + Vector2(VIEW_SIZE.x / 2.0 - 210, VIEW_SIZE.y / 2.0 - 140)
	layer.add_child(_start_panel)


func selected_vocation() -> String:
	return Balance.VOCATIONS.keys()[maxi(0, _vocation.selected)]


func _add_button(parent: Node, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)


func _build_inventory(layer: CanvasLayer) -> void:
	var frame := ColorRect.new()
	frame.color = Color("#151a20")
	frame.position = PANEL_ORIGIN - Vector2(8, 0)
	frame.size = Vector2(200, VIEW_SIZE.y)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(frame)
	_add_panel_label(layer, "Equipment", PANEL_ORIGIN + Vector2(0, 6))
	for slot: String in World.SLOTS:
		_add_slot(layer, {"type": "equipment", "slot": slot}, slot_position({"type": "equipment", "slot": slot}))
	_backpack_label = _add_panel_label(layer, "Backpack", PANEL_ORIGIN + Vector2(0, 146))
	for index: int in World.BACKPACK_SIZE:
		_add_slot(layer, {"type": "backpack", "index": index}, slot_position({"type": "backpack", "index": index}))
	_build_stat_sheet(layer)
	var hint: Label = _add_panel_label(layer, "Drag / right-click items and people.\nRight-click a bar slot to change it.",
		PANEL_ORIGIN + Vector2(0, 648))
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color("#a7b0b8")


func slot_position(location: Dictionary) -> Vector2:
	if location["type"] == "equipment":
		return PANEL_ORIGIN + Vector2(42, 32) + PAPERDOLL[location["slot"]] * SLOT_STEP
	var index: int = location["index"]
	return PANEL_ORIGIN + Vector2(24, 172) + Vector2(index % 4, index / 4) * SLOT_STEP


func _build_stat_sheet(layer: CanvasLayer) -> void:
	_add_panel_label(layer, "Stats", PANEL_ORIGIN + Vector2(0, 252))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.position = PANEL_ORIGIN + Vector2(0, 278)
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 0)
	layer.add_child(grid)
	for stat: String in ["vocation", "level", "experience", "gold"] + Array(Balance.STATS):
		var name := Label.new()
		name.text = {"vocation": "Vocation", "level": "Level", "experience": "Experience", "gold": "Gold"}.get(stat,
			STAT_LABELS.get(stat, stat))
		name.modulate = Color("#a7b0b8")
		name.add_theme_font_size_override("font_size", 13)
		grid.add_child(name)
		var value := Label.new()
		value.add_theme_font_size_override("font_size", 13)
		grid.add_child(value)
		_stat_values[stat] = value


func item_tooltip(kind: String) -> String:
	if not World.ITEMS.has(kind):
		return ""
	var item: Dictionary = World.ITEMS[kind]
	var lines: PackedStringArray = [item["name"]]
	if not item["slot"].is_empty():
		lines.append(item["slot"].capitalize())
	for stat: String in item["stats"]:
		lines.append("%+d %s%s" % [item["stats"][stat], STAT_LABELS[stat], "%" if stat == "critical" else ""])
	if item.has("gold"):
		lines.append("Worth %d gold; picked up into your purse" % item["gold"])
	return "\n".join(lines)


func _build_maps(layer: CanvasLayer) -> void:
	var lookup := PackedColorArray()
	lookup.resize(128)
	lookup.fill(Color.BLACK)
	for terrain: String in MAP_COLORS:
		lookup[terrain.unicode_at(0)] = MAP_COLORS[terrain]
	var image := Image.create(World.width(), World.height(), false, Image.FORMAT_RGB8)
	for y: int in World.height():
		var row: PackedByteArray = World.ROWS[y].to_ascii_buffer()
		for x: int in row.size():
			image.set_pixel(x, y, lookup[row[x] & 127])
	for zone: Dictionary in World.ZONES:
		if not zone["pvp"]:
			continue
		var area: Rect2i = zone["rect"].intersection(Rect2i(0, 0, World.width(), World.height()))
		for y: int in range(area.position.y, area.end.y):
			for x: int in range(area.position.x, area.end.x):
				if World.terrain(Vector2i(x, y)) not in ["~", " "]:
					image.set_pixel(x, y, image.get_pixel(x, y).lerp(PVP_TINT, 0.45))
	_map_texture = ImageTexture.create_from_image(image)
	_minimap = Control.new()
	_minimap.position = PANEL_ORIGIN + Vector2(0, 504)
	_minimap.size = Vector2(184, 136)
	_minimap.clip_contents = true
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap.draw.connect(_draw_minimap)
	layer.add_child(_minimap)
	_world_map = Control.new()
	_world_map.position = VIEW_ORIGIN
	_world_map.size = VIEW_SIZE
	_world_map.visible = false
	_world_map.draw.connect(_draw_world_map)
	_world_map.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_world_map.hide())
	layer.add_child(_world_map)


func _draw_markers(canvas: Control, origin: Vector2, scale: float, area: Rect2) -> void:
	for id: String in World.FERRYMEN:
		var at: Vector2 = origin + (Vector2(World.FERRYMEN[id]["cell"]) + Vector2(0.5, 0.5)) * scale
		if area.has_point(at):
			canvas.draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), Color("#7fe0d0"))
	for id: int in actors:
		var at: Vector2 = origin + (actors[id]["visual"] + Vector2(0.5, 0.5)) * scale
		var mine: bool = id == self_id
		var radius: float = 2.5 if mine else 1.5
		if area.has_point(at):
			canvas.draw_rect(Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2.0),
				Color("#f2cf6a") if mine else Color.WHITE)


func _draw_minimap() -> void:
	var view := Rect2(Vector2.ZERO, _minimap.size)
	_minimap.draw_rect(view, Color.BLACK)
	var tiles: Vector2 = _minimap.size / MINIMAP_SCALE
	var region := Rect2(camera_focus() / World.TILE_SIZE - tiles / 2.0, tiles)
	var visible := region.intersection(Rect2(0, 0, World.width(), World.height()))
	if visible.has_area():
		_minimap.draw_texture_rect_region(_map_texture,
			Rect2((visible.position - region.position) * MINIMAP_SCALE, visible.size * MINIMAP_SCALE), visible)
	_draw_markers(_minimap, -region.position * MINIMAP_SCALE, MINIMAP_SCALE, view)
	_minimap.draw_rect(view, Color("#3a4450"), false, 1.0)


func _draw_world_map() -> void:
	var map_size := Vector2(World.width(), World.height())
	var scale: float = maxf(1.0, floorf(minf(VIEW_SIZE.x / map_size.x, (VIEW_SIZE.y - 32.0) / map_size.y)))
	var origin: Vector2 = ((VIEW_SIZE - map_size * scale) / 2.0).floor() + Vector2(0, 12)
	_world_map.draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(0.03, 0.04, 0.05))
	_world_map.draw_texture_rect(_map_texture, Rect2(origin, map_size * scale), false)
	_draw_markers(_world_map, origin, scale, Rect2(Vector2.ZERO, VIEW_SIZE))
	var font: Font = ThemeDB.fallback_font
	var labels: Array = [[World.WORLD_NAME, Vector2(World.SPAWNS[0]) + Vector2(4, -3)]]
	for id: String in World.FERRYMEN:
		var place: String = World.FERRYMEN[id]["place"]
		if World.zone_at(World.FERRYMEN[id]["cell"]).get("name", "") != place:
			labels.append([place, Vector2(World.FERRYMEN[id]["cell"]) + Vector2(0, -3)])
	for zone: Dictionary in World.ZONES:
		var text: String = "%s (%s, level %d-%d)" % [zone["name"], "PvP" if zone["pvp"] else "safe",
			zone["min_level"], zone["max_level"]]
		labels.append([text, Vector2(zone["rect"].get_center().x, zone["rect"].end.y + 3), PVP_TINT.lightened(0.35)])
	for label: Array in labels:
		var at: Vector2 = origin + label[1] * scale - Vector2(font.get_string_size(label[0], 0, -1, 13).x / 2.0, 0)
		_world_map.draw_string_outline(font, at, label[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color.BLACK)
		_world_map.draw_string(font, at, label[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			label[2] if label.size() > 2 else Color("#f4ecd8"))
	_world_map.draw_string(font, Vector2(12, 22), "World map: gold = you, cyan = ferrymen, red = PvP. Click to close.",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#dfe4ea"))


func _build_travel_panel(layer: CanvasLayer) -> void:
	_travel_panel = PanelContainer.new()
	_travel_panel.visible = false
	_travel_panel.position = VIEW_ORIGIN + Vector2(VIEW_SIZE.x / 2.0 - 150, 120)
	_travel_panel.custom_minimum_size = Vector2(300, 0)
	_travel_list = VBoxContainer.new()
	_travel_panel.add_child(_travel_list)
	layer.add_child(_travel_panel)


## Right-clicking a person opens their services; there is no typed dialogue.
func open_npc_menu(npc: String, at: Vector2i) -> void:
	if not World.FERRYMEN.has(npc):
		return
	_npc_menu.clear()
	_npc_menu.add_separator(World.FERRYMEN[npc]["name"])
	var services: Array = World.FERRYMEN[npc]["services"]
	for index: int in services.size():
		_npc_menu.add_item(NPC_SERVICES.get(services[index], String(services[index]).capitalize()), index)
		_npc_menu.set_item_metadata(_npc_menu.get_item_index(index), services[index])
	_npc_menu_target = npc
	_npc_menu.popup(Rect2i(at, Vector2i.ZERO))


func _npc_service_chosen(id: int) -> void:
	var service: Variant = _npc_menu.get_item_metadata(_npc_menu.get_item_index(id))
	if service == "travel":
		talk_to(_npc_menu_target)


## Opens a ferryman's routes and fares when you stand within range.
func talk_to(ferryman: String) -> void:
	if not actors.has(self_id) or not World.FERRYMEN.has(ferryman):
		return
	var npc: Dictionary = World.FERRYMEN[ferryman]
	if World.chebyshev(actors[self_id]["state"]["cell"], npc["cell"]) > World.TALK_RANGE:
		last_action_message = "Walk closer to %s." % npc["name"]
		return
	for child: Node in _travel_list.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "%s, %s\n\"Where can I take you?\"" % [npc["name"], npc["place"]]
	_travel_list.add_child(title)
	var gold: int = actors[self_id]["state"].get("gold", 0)
	for destination: String in npc["routes"]:
		var fare: int = npc["routes"][destination]
		var button := Button.new()
		button.text = "%s  —  %d gold" % [World.FERRYMEN[destination]["place"], fare]
		button.disabled = gold < fare
		button.pressed.connect(func() -> void:
			travel_local(ferryman, destination)
			_close_travel())
		_travel_list.add_child(button)
	var close := Button.new()
	close.text = "Not today"
	close.pressed.connect(_close_travel)
	_travel_list.add_child(close)
	_talking_to = ferryman
	_travel_panel.reset_size()
	_travel_panel.show()


func _update_zone() -> void:
	var zone: Dictionary = World.zone_at(actors[self_id]["state"]["cell"]) if actors.has(self_id) else {}
	var name: String = zone.get("name", "")
	if name != _zone_name and not name.is_empty():
		last_action_message = "Entering %s." % name
	_zone_name = name
	_zone_label.visible = not zone.is_empty()
	if not zone.is_empty():
		_zone_label.text = "%s  —  %s  ·  monsters level %d-%d" % [name,
			"PvP zone: other players can attack you" if zone["pvp"] else "safe zone", zone["min_level"], zone["max_level"]]


func _build_action_bar(layer: CanvasLayer) -> void:
	var start: Vector2 = VIEW_ORIGIN + Vector2((VIEW_SIZE.x - Keybinds.SLOTS * BAR_SLOT) / 2.0, VIEW_SIZE.y - BAR_SLOT - 6)
	for slot: int in Keybinds.SLOTS:
		var button := Control.new()
		button.position = start + Vector2(slot * BAR_SLOT, 0)
		button.size = Vector2.ONE * (BAR_SLOT - 4)
		button.draw.connect(_draw_bar_slot.bind(button, slot))
		button.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_LEFT:
					use_bar_slot(slot)
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					_open_bar_menu(slot, Vector2i(button.global_position + event.position)))
		layer.add_child(button)
		_bar_slots.append(button)
	_bar_menu = PopupMenu.new()
	_bar_menu.id_pressed.connect(func(index: int) -> void:
		var entry: String = _bar_menu.get_item_metadata(_bar_menu.get_item_index(index))
		if keybinds.set_bar(_bar_menu_slot, entry):
			keybinds.save())
	add_child(_bar_menu)


## Lists the general bar actions and the spells of your vocation, with their level.
func _open_bar_menu(slot: int, at: Vector2i) -> void:
	_bar_menu_slot = slot
	_bar_menu.clear()
	var entries: Array = Keybinds.BAR_ACTIONS.keys()
	if actors.has(self_id):
		_bar_menu.add_separator("Spells")
		var level: int = actors[self_id]["state"].get("level", 1)
		for spell: String in Spells.for_vocation(actors[self_id]["state"]["vocation"]):
			var definition: Dictionary = Spells.SPELLS[spell]
			entries.append("spell:" + spell)
			_bar_menu.add_item("%s%s" % [definition["name"], "" if level >= definition["level"]
				else "  (level %d)" % definition["level"]], entries.size() - 1)
			_bar_menu.set_item_metadata(_bar_menu.get_item_index(entries.size() - 1), "spell:" + spell)
		_bar_menu.add_separator("Other")
	for index: int in Keybinds.BAR_ACTIONS.size():
		_bar_menu.add_item(Keybinds.BAR_ACTIONS[entries[index]], index)
		_bar_menu.set_item_metadata(_bar_menu.get_item_index(index), entries[index])
	_bar_menu.popup(Rect2i(at, Vector2i.ZERO))


func _draw_bar_slot(button: Control, slot: int) -> void:
	var area := Rect2(Vector2.ZERO, button.size)
	button.draw_rect(area, Color(0.08, 0.1, 0.12, 0.85))
	button.draw_rect(area, Color("#4a5560"), false, 1.0)
	var entry: String = keybinds.bar[slot]
	var center: Vector2 = button.size / 2.0
	var font: Font = ThemeDB.fallback_font
	if entry.begins_with("toggle_") and actors.has(self_id):
		var equipment_slot: String = entry.trim_prefix("toggle_")
		var worn: String = actors[self_id]["state"]["equipment"].get(equipment_slot, "")
		if not worn.is_empty():
			SpriteArt.draw_item(button, center, worn)
		else:
			SpriteArt.draw_slot_hint(button, center, equipment_slot)
	elif entry.begins_with("spell:") and Spells.SPELLS.has(entry.trim_prefix("spell:")):
		_draw_spell_slot(button, entry.trim_prefix("spell:"))
	elif not entry.is_empty():
		var text: String = Keybinds.BAR_ACTIONS[entry]
		button.draw_string(font, Vector2(2, center.y + 4), text, HORIZONTAL_ALIGNMENT_CENTER, button.size.x - 4, 9)
	var key: String = Keybinds.key_name(keybinds.keys["slot_%d" % (slot + 1)][0])
	button.draw_string_outline(font, Vector2(3, 11), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color.BLACK)
	button.draw_string(font, Vector2(3, 11), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#f2e6c4"))


## A spell slot: coloured rune with initials, dimmed when unusable, with a cooldown shade.
func _draw_spell_slot(button: Control, spell: String) -> void:
	var definition: Dictionary = Spells.SPELLS[spell]
	var center: Vector2 = button.size / 2.0
	var state: Dictionary = actors[self_id]["state"] if actors.has(self_id) else {}
	var usable: bool = not state.is_empty() and state.get("level", 1) >= definition["level"]
	button.draw_circle(center + Vector2(0, 2), 13.0, Color(definition["color"], 1.0 if usable else 0.35))
	button.draw_arc(center + Vector2(0, 2), 13.0, 0, TAU, 24, Color("#0b0e12"), 1.0)
	var initials: String = "".join(Array(definition["name"].split(" ")).map(func(word: String) -> String: return word[0]))
	var font: Font = ThemeDB.fallback_font
	button.draw_string(font, Vector2(0, center.y + 6), initials, HORIZONTAL_ALIGNMENT_CENTER, button.size.x, 12, Color("#14181c"))
	if state.is_empty():
		return
	var elapsed: float = _now() - actors[self_id].get("received", _now())
	var left: float = maxf(state.get("cooldowns", {}).get(spell, 0.0), state.get("groups", {}).get(definition["group"], 0.0)) - elapsed
	if left > 0.0:
		var share: float = clampf(left / maxf(definition["cooldown"], Spells.GROUP_SECONDS[definition["group"]]), 0.0, 1.0)
		button.draw_rect(Rect2(Vector2(0, button.size.y * (1.0 - share)), Vector2(button.size.x, button.size.y * share)),
			Color(0, 0, 0, 0.6))


func _close_travel() -> void:
	_talking_to = ""
	_travel_panel.hide()


func _add_panel_label(layer: CanvasLayer, text: String, at: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	layer.add_child(label)
	return label


func _add_slot(layer: CanvasLayer, location: Dictionary, at: Vector2) -> void:
	var slot := Control.new()
	slot.position = at
	slot.size = Vector2.ONE * World.TILE_SIZE
	slot.set_meta("location", location)
	slot.draw.connect(_draw_slot.bind(slot, location))
	slot.gui_input.connect(_slot_input.bind(location))
	slot.set_drag_forwarding(_item_drag.bind(slot, location), _item_can_drop.bind(location), _item_drop.bind(location))
	layer.add_child(slot)
	_slots.append(slot)


func _local_item(location: Dictionary) -> String:
	if location["type"] == "ground":
		var stack: Array = ground_view.get(location["cell"], [])
		return stack.back() if not stack.is_empty() else ""
	if not actors.has(self_id):
		return ""
	var state: Dictionary = actors[self_id]["state"]
	if location["type"] == "equipment":
		return state["equipment"].get(location["slot"], "")
	var backpack: Array = state.get("backpack", [])
	return backpack[location["index"]] if location["index"] < backpack.size() else ""


func _draw_slot(slot: Control, location: Dictionary) -> void:
	slot.draw_rect(Rect2(Vector2.ZERO, slot.size), Color("#232a33"))
	slot.draw_rect(Rect2(Vector2(-1, -1), slot.size + Vector2(2, 2)), Color("#0b0e12"), false, 1.0)
	slot.draw_rect(Rect2(Vector2.ZERO, Vector2(slot.size.x, 1)), Color("#3a4450"))
	slot.draw_rect(Rect2(Vector2.ZERO, Vector2(1, slot.size.y)), Color("#3a4450"))
	var kind: String = _local_item(location)
	if not kind.is_empty():
		SpriteArt.draw_item(slot, slot.size / 2.0, kind)
	elif location["type"] == "equipment":
		SpriteArt.draw_slot_hint(slot, slot.size / 2.0, location["slot"])


func _item_drag(_at: Vector2, source: Control, location: Dictionary) -> Variant:
	var kind: String = _local_item(location)
	if not connected or kind.is_empty():
		return null
	var preview := Control.new()
	preview.draw.connect(func() -> void: SpriteArt.draw_item(preview, Vector2.ZERO, kind))
	source.set_drag_preview(preview)
	return {"brimholt_item": location}


func _item_can_drop(_at: Vector2, data: Variant, target: Dictionary) -> bool:
	return connected and typeof(data) == TYPE_DICTIONARY and data.has("brimholt_item") \
		and data["brimholt_item"] != target


func _item_drop(at: Vector2, data: Variant, target: Dictionary) -> void:
	if _item_can_drop(at, data, target):
		move_item_local(data["brimholt_item"], target)


func _slot_input(event: InputEvent, location: Dictionary) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		return
	var kind: String = _local_item(location)
	if kind.is_empty():
		return
	if location["type"] != "backpack":
		move_item_local(location, {"type": "backpack"})
	elif actors.has(self_id):
		var slot: String = World.slot_for(kind, actors[self_id]["state"]["equipment"])
		if not slot.is_empty():
			move_item_local(location, {"type": "equipment", "slot": slot})


## Map pixel the camera centres: your character's interpolated position, else the map centre.
func camera_focus() -> Vector2:
	if actors.has(self_id):
		return (actors[self_id]["visual"] + Vector2(0.5, 0.5)) * World.TILE_SIZE
	if dedicated:
		return Vector2(World.width(), World.height()) * World.TILE_SIZE / 2.0
	# Before joining, show the starting town rather than the middle of the map.
	return (Vector2(World.SPAWNS[0]) + Vector2(4.5, 2.5)) * World.TILE_SIZE


func map_to_screen(point: Vector2) -> Vector2:
	return VIEW_ORIGIN + _world_view.position + point * ZOOM


## at is relative to the game window.
func _map_location(at: Vector2) -> Dictionary:
	var point: Vector2 = (at - _world_view.position) / ZOOM
	return {"type": "ground", "cell": Vector2i((point / World.TILE_SIZE).floor())}


func _map_drag(at: Vector2) -> Variant:
	return _item_drag(at, _view, _map_location(at))


func _map_can_drop(at: Vector2, data: Variant) -> bool:
	return _item_can_drop(at, data, _map_location(at))


func _map_drop(at: Vector2, data: Variant) -> void:
	_item_drop(at, data, _map_location(at))


func _map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		get_viewport().gui_release_focus()
		var cell: Vector2i = _map_location(event.position)["cell"]
		var npc: String = World.NPC_CELLS.get(cell, World.NPC_CELLS.get(cell + Vector2i.DOWN, ""))
		if event.button_index == MOUSE_BUTTON_RIGHT and not npc.is_empty():
			open_npc_menu(npc, Vector2i(VIEW_ORIGIN + event.position))
			return
		var creature: int = _creature_at(cell)
		if event.button_index == MOUSE_BUTTON_LEFT and creature != 0:
			target_local(0 if creature == own_target() else creature)
			return
		_slot_input(event, _map_location(event.position))


func _update_labels() -> void:
	_status.text = _status_message + ("  |  %d/%d players" % [actors.size(), World.MAX_PLAYERS] if connected else "")
	_status.modulate = Color("#9ccea4") if connected else Color("#e4bd8a")
	if last_action_message != _shown_message:
		_shown_message = last_action_message
		_message_since = _now()
	elif not last_action_message.is_empty() and _now() - _message_since > MESSAGE_SECONDS:
		last_action_message = ""
		_shown_message = ""
	_action.text = last_action_message
	var carried: int = 0
	if actors.has(self_id):
		carried = World.BACKPACK_SIZE - actors[self_id]["state"].get("backpack", []).count("")
	_backpack_label.text = "Backpack  %d/%d" % [carried, World.BACKPACK_SIZE]
	if not actors.has(self_id):
		for value: Label in _stat_values.values():
			value.text = "-"
		return
	var state: Dictionary = actors[self_id]["state"]
	var level: int = state.get("level", 1)
	var vocation: String = state.get("vocation", Balance.DEFAULT_VOCATION)
	var stats: Dictionary = World.stats(level, state["equipment"], vocation)
	var base: Dictionary = Balance.base_stats(level, vocation)
	_stat_values["vocation"].text = Balance.VOCATIONS[vocation]["name"]
	_stat_values["vocation"].tooltip_text = Balance.VOCATIONS[vocation]["role"]
	_stat_values["vocation"].mouse_filter = Control.MOUSE_FILTER_PASS
	var next: int = Balance.experience_to_next(level)
	_stat_values["level"].text = "%d / %d" % [level, Balance.MAX_LEVEL]
	_stat_values["experience"].text = "%d / %d" % [state.get("experience", 0), next] if next > 0 else "max"
	_stat_values["gold"].text = str(state.get("gold", 0))
	for stat: String in Balance.STATS:
		var bonus: int = stats[stat] - base[stat]
		var text: String = str(stats[stat])
		if stat in ["health", "mana"] and state.has(stat):
			text = "%d / %d" % [state[stat], stats[stat]]
		if stat == "critical":
			text += "%"
		elif stat == "defense":
			text += "  (-%d%%)" % (100 - Balance.damage_taken(100, stats[stat]))
		elif stat == "regen":
			text += " / 10 s"
		elif stat == "healing":
			text += " / s"
		if bonus != 0:
			text += "  %+d" % bonus
		_stat_values[stat].text = text
