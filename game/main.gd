extends Node2D

const World = preload("res://game/world.gd")
const CharacterArt = preload("res://game/character_art.gd")
const WorldView = preload("res://game/world_view.gd")
## Tibia-style game window: 15x11 tiles at 2x, centred on your character.
const ZOOM: float = 2.0
const VIEW_TILES: Vector2i = Vector2i(15, 11)
const VIEW_ORIGIN: Vector2 = Vector2(16, 76)
const VIEW_SIZE: Vector2 = Vector2(VIEW_TILES * World.TILE_SIZE) * ZOOM
const PANEL_ORIGIN: Vector2 = Vector2(992, 76)
const SLOT_STEP: float = 36.0
const PAPERDOLL: Dictionary = {"helmet": Vector2(1, 0), "hand": Vector2(0, 1), "armor": Vector2(1, 1)}

var world := World.new()
var actors: Dictionary = {}
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
var _status: Label
var _action: Label
var _backpack_label: Label
var _slots: Array[Control] = []
var _view: ColorRect
var _world_view: Node2D


func _ready() -> void:
	_build_ui()
	get_tree().auto_accept_quit = false
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_left)
	multiplayer.connected_to_server.connect(_connected_to_host)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_host_lost)
	var args: PackedStringArray = OS.get_cmdline_user_args()
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
	for id: int in actors:
		var actor: Dictionary = actors[id]
		actor["elapsed"] = minf(actor["elapsed"] + delta, actor["duration"])
		var weight: float = 1.0
		if actor["duration"] > 0.0:
			weight = actor["elapsed"] / actor["duration"]
		actor["visual"] = actor["start"].lerp(Vector2(actor["state"]["cell"]), weight)
	if connected and self_id != 0 and not _address.has_focus() \
			and _move_pending_since < 0.0 and now >= _next_move_attempt:
		var direction: Vector2i = _input_direction()
		if direction != Vector2i.ZERO:
			move_local(direction)
	_update_labels()
	for slot: Control in _slots:
		var kind: String = _local_item(slot.get_meta("location"))
		slot.tooltip_text = World.ITEMS[kind]["name"] if not kind.is_empty() else ""
		slot.queue_redraw()
	_world_view.position = (VIEW_SIZE / 2.0 - camera_focus() * ZOOM).round()
	_world_view.queue_redraw()


func _input_direction() -> Vector2i:
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		return Vector2i.UP
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		return Vector2i.DOWN
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		return Vector2i.LEFT
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		return Vector2i.RIGHT
	return Vector2i.ZERO


func _unhandled_key_input(event: InputEvent) -> void:
	if not connected or _address.has_focus() or not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey:
		match event.keycode:
			KEY_1: equip_local("helmet")
			KEY_2: equip_local("armor")
			KEY_3: equip_local("hand")
			KEY_G: pick_up_local()


func _reset_session() -> void:
	if peer != null:
		peer.close()
	peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	world = World.new()
	actors.clear()
	ground_view.clear()
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
		if not world.add_player(1, _now()):
			_fail("The host could not find a valid spawn.")
			return
		_apply_actor(world.export_player(1, _now(), true))
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
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		await leave_game()
		get_tree().quit()


func _peer_connected(id: int) -> void:
	if peer != null and (hosting or id == 1):
		peer.get_peer(id).set_timeout(16, 1000, 5000)


func _connected_to_host() -> void:
	hello.rpc_id(1, World.signature())


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
func hello(map_signature: String) -> void:
	if not hosting:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender <= 1 or sender not in multiplayer.get_peers() \
			or world.players.has(sender) or _closing_peers.has(sender):
		return
	_pending_peers.erase(sender)
	if map_signature != World.signature():
		_reject_connection(sender, "World/protocol mismatch. Use the same project files as the host.")
		return
	if not world.add_player(sender, _now()):
		_reject_connection(sender, "This world is full (four players maximum).")
		return
	welcome.rpc_id(sender, world.snapshot(_now(), sender), world.ground_snapshot())
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
func welcome(states: Dictionary, ground_state: Dictionary) -> void:
	if hosting:
		return
	actors.clear()
	for id: int in states:
		_apply_actor(states[id])
	ground_view = ground_state.duplicate(true)
	self_id = multiplayer.get_unique_id()
	if not actors.has(self_id):
		_fail("The host sent a snapshot without your player.")
		return
	connected = true
	_joining_since = -1.0
	_status_message = "Connected to %s:%d" % [_address.text, port]


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
		"duration": remaining, "elapsed": 0.0,
	}
	if id == self_id:
		last_action_message = ""
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
	_status = Label.new()
	_status.position = Vector2(16, 48)
	layer.add_child(_status)
	_action = Label.new()
	_action.position = VIEW_ORIGIN + Vector2(0, VIEW_SIZE.y - 40)
	_action.size = Vector2(VIEW_SIZE.x, 32)
	_action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action.add_theme_color_override("font_color", Color("#f4f0e6"))
	_action.add_theme_color_override("font_outline_color", Color("#101010"))
	_action.add_theme_constant_override("outline_size", 6)
	layer.add_child(_action)
	_build_inventory(layer)


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
	_backpack_label = _add_panel_label(layer, "Backpack", PANEL_ORIGIN + Vector2(0, 116))
	for index: int in World.BACKPACK_SIZE:
		_add_slot(layer, {"type": "backpack", "index": index}, slot_position({"type": "backpack", "index": index}))
	var hint: Label = _add_panel_label(layer, "Drag items between slots\nor onto nearby tiles.\nRight-click: equip,\nunequip or pick up.\n\nWASD / arrows: move\n1 / 2 / 3: toggle gear\nG: pick up\nGold ring: you",
		PANEL_ORIGIN + Vector2(0, 236))
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color("#a7b0b8")


func slot_position(location: Dictionary) -> Vector2:
	if location["type"] == "equipment":
		return PANEL_ORIGIN + Vector2(42, 32) + PAPERDOLL[location["slot"]] * SLOT_STEP
	var index: int = location["index"]
	return PANEL_ORIGIN + Vector2(24, 142) + Vector2(index % 4, index / 4) * SLOT_STEP


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
		CharacterArt.draw_item(slot, slot.size / 2.0, kind)
	elif location["type"] == "equipment":
		CharacterArt.draw_slot_hint(slot, slot.size / 2.0, location["slot"])


func _item_drag(_at: Vector2, source: Control, location: Dictionary) -> Variant:
	var kind: String = _local_item(location)
	if not connected or kind.is_empty():
		return null
	var preview := Control.new()
	preview.draw.connect(func() -> void: CharacterArt.draw_item(preview, Vector2.ZERO, kind))
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
	elif not World.ITEMS[kind]["slot"].is_empty():
		move_item_local(location, {"type": "equipment", "slot": World.ITEMS[kind]["slot"]})


## Map pixel the camera centres: your character's interpolated position, else the map centre.
func camera_focus() -> Vector2:
	if actors.has(self_id):
		return (actors[self_id]["visual"] + Vector2(0.5, 0.5)) * World.TILE_SIZE
	return Vector2(World.ROWS[0].length(), World.ROWS.size()) * World.TILE_SIZE / 2.0


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
		_slot_input(event, _map_location(event.position))


func _update_labels() -> void:
	_status.text = _status_message + ("  |  %d/%d players" % [actors.size(), World.MAX_PLAYERS] if connected else "")
	_status.modulate = Color("#9ccea4") if connected else Color("#e4bd8a")
	_action.text = last_action_message
	var carried: int = 0
	if actors.has(self_id):
		carried = World.BACKPACK_SIZE - actors[self_id]["state"].get("backpack", []).count("")
	_backpack_label.text = "Backpack  %d/%d" % [carried, World.BACKPACK_SIZE]
