extends Node2D
## The entry scene (/root/Main): ENet hosting and joining, the sender-validated RPC endpoint,
## replicated client state, the camera, and input. The UI components in game/ui/ build and
## draw the panels; main keeps shortcuts to their controls and thin wrappers for tests.

const World = preload("res://game/core/world.gd")
const Keybinds = preload("res://game/input/keybinds.gd")
const Combat = preload("res://game/core/combat.gd")
const Economy = preload("res://game/core/economy.gd")
const Instances = preload("res://game/core/instances.gd")
const CharacterStore = preload("res://game/persistence/character_store.gd")
const Identity = preload("res://game/persistence/identity.gd")
const Balance = preload("res://game/data/balance.gd")
const Layout = preload("res://game/ui/layout.gd")
const GameWindow = preload("res://game/ui/game_window.gd")
const Hud = preload("res://game/ui/hud.gd")
const InventoryPanel = preload("res://game/ui/inventory_panel.gd")
const WorldMaps = preload("res://game/ui/world_maps.gd")
const ActionBar = preload("res://game/ui/action_bar.gd")
const NpcDialogs = preload("res://game/ui/npc_dialogs.gd")
const StartPanel = preload("res://game/ui/start_panel.gd")
const CellIndex = preload("res://game/render/cell_index.gd")
const QuestList = preload("res://game/ui/quest_list.gd")
## Tibia-style game window: 15x11 tiles at 2x, centred on your character.
const ZOOM: float = Layout.ZOOM
const VIEW_TILES: Vector2i = Layout.VIEW_TILES
const VIEW_ORIGIN: Vector2 = Layout.VIEW_ORIGIN
const VIEW_SIZE: Vector2 = Layout.VIEW_SIZE
const PANEL_ORIGIN: Vector2 = Layout.PANEL_ORIGIN
const MAP_COLORS: Dictionary = WorldMaps.MAP_COLORS

var world := World.new()
var combat := Combat.new(world)
var economy := Economy.new(world)
var instances := Instances.new(world, combat)
## Clients receive monsters and combat effects only within INTEREST_RADIUS tiles of their
## character; peer id -> {monster id: true} they currently know about.
const INTEREST_RADIUS: int = 24
const INTEREST_SECONDS: float = 0.25
var _known_monsters: Dictionary = {}
var _next_interest: float = 0.0
var actors: Dictionary = {}
## Client view of monsters, interpolated like actors.
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
var _view: GameWindow
var _world_view: Node2D
## Clients add this to their clock to follow the host's time of day.
var _clock_offset: float = 0.0
var keybinds := Keybinds.new()
## Hosts save characters (game/persistence/character_store.gd) unless started with --no-save;
## --save-dir=PATH picks the folder (default user://saves).
var save_enabled: bool = true
var save_dir: String = CharacterStore.DEFAULT_DIR
var store: CharacterStore
## Peer id -> save account (SHA-256 of the identity token) of every character in the world.
var _accounts: Dictionary = {}
var _next_autosave: float = 0.0
## Welcome-back messages for restored characters, sent after their snapshot.
var _greetings: Dictionary = {}
## This computer's identity token (game/persistence/identity.gd): from --profile=NAME, a new
## one per run with --fresh-identity (tests), or --token=HEX.
var identity_token: String = ""
var identity_profile: String = ""
## Automated tests and bots run in hidden windows and set this false, so a stray OS close
## request (a click or shortcut meant for another app) cannot end their session.
var close_ends_session: bool = true
var hud: Hud
var quest_list: QuestList
var inventory: InventoryPanel
var maps: WorldMaps
var action_bar: ActionBar
var dialogs: NpcDialogs
var start_panel: StartPanel
# Shortcuts to component controls, used by input handling and the tests.
var _address: LineEdit
var _vocation: OptionButton
var _controls: PanelContainer
var _zone_label: Label
var _minimap: Control
var _world_map: Control
var _travel_panel: PanelContainer
var _travel_list: VBoxContainer
var _npc_menu: PopupMenu
## Shortcuts to the dialog state, used by the integration and visual tests.
@warning_ignore("unused_private_class_variable")
var _talking_to: String:
	get:
		return dialogs.talking_to
@warning_ignore("unused_private_class_variable")
var _npc_menu_target: String:
	get:
		return dialogs.npc_menu_target


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
	for arg: String in args:
		if arg == "--no-save":
			save_enabled = false
		elif arg.begins_with("--save-dir="):
			save_dir = arg.trim_prefix("--save-dir=")
		elif arg == "--fresh-identity":
			identity_token = Identity.fresh()
		elif arg.begins_with("--token="):
			identity_token = arg.trim_prefix("--token=")
		elif arg.begins_with("--profile="):
			identity_profile = arg.trim_prefix("--profile=")
	if not Identity.valid_profile(identity_profile) or not (identity_token.is_empty() or Identity.valid_token(identity_token)):
		_fail("Profiles use letters, digits, - and _; tokens are 64 lowercase hex digits.")
		get_tree().quit(1)
		return
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


## Test-only: seconds added to the clock, so soak tests can jump ahead (respawns, ground decay).
var clock_skew: float = 0.0


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0 + clock_skew


## The host's clock, for the day and night cycle on every peer.
func world_clock() -> float:
	return _now() + _clock_offset


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
		_handle_events(instances.tick(now))
		_handle_events(world.decay_ground(now))
		if now >= _next_interest:
			_next_interest = now + INTEREST_SECONDS
			_sync_interest(now)
		if store != null and now >= _next_autosave:
			_next_autosave = now + CharacterStore.AUTOSAVE_SECONDS
			save_all()
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
	inventory.redraw_slots()
	_world_view.position = (VIEW_SIZE / 2.0 - camera_focus() * ZOOM).round()
	_world_view.queue_redraw()
	dialogs.refresh()
	hud.refresh()
	quest_list.refresh()
	start_panel.refresh()
	action_bar.redraw()
	maps.redraw()


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
		_run_action(action)


## Casts the spell in an action-bar slot (0-8).
func use_bar_slot(slot: int) -> void:
	if slot >= 0 and slot < Keybinds.SLOTS and keybinds.bar[slot].begins_with("spell:") and connected:
		cast_local(keybinds.bar[slot].trim_prefix("spell:"))


func _run_action(action: String) -> void:
	if action == "world_map":
		_world_map.visible = not _world_map.visible
	elif action == "quest_list":
		quest_list.shown = not quest_list.shown
	elif not connected:
		return
	elif action == "pick_up":
		pick_up_local()
	elif action == "target_nearest":
		target_nearest()
	elif action in ["health_potion", "mana_potion"]:
		drink_kind(action)


func _reset_session() -> void:
	if peer != null:
		peer.close()
	peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	world = World.new()
	combat = Combat.new(world)
	economy = Economy.new(world)
	instances = Instances.new(world, combat)
	_known_monsters.clear()
	_next_interest = 0.0
	store = null
	_accounts.clear()
	_greetings.clear()
	actors.clear()
	monsters.clear()
	_monster_index.clear()
	effects.clear()
	ground_view = {}
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
	if save_enabled:
		store = CharacterStore.new(save_dir)
		var unusable: String = store.open()
		if not unusable.is_empty():
			_fail(unusable)
			return
		_next_autosave = _now() + CharacterStore.AUTOSAVE_SECONDS
	multiplayer.multiplayer_peer = peer
	hosting = true
	connected = true
	ground_view = world.ground_snapshot()
	if not dedicated:
		self_id = 1
		var refused: String = _admit(1, own_token(), selected_vocation())
		if not refused.is_empty():
			_fail(refused)
			return
		_apply_actor(world.export_player(1, _now(), true))
		action_bar.fill_spell_slots(world.players[1]["vocation"])
		last_action_message = _greetings.get(1, "")
		_greetings.erase(1)
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
	if hosting:
		save_all()
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
	hello.rpc_id(1, World.signature(), selected_vocation(), own_token())


## This computer's identity token, loaded or created on first use.
func own_token() -> String:
	if identity_token.is_empty():
		identity_token = Identity.load_or_create(identity_profile)
	return identity_token


## Adds a joining player: their saved character if the host has one for this identity, else a
## new one of the chosen vocation (saved at once). Returns "" or why they cannot join.
func _admit(id: int, token: String, vocation: String) -> String:
	if not Identity.valid_token(token):
		return "Your client sent no valid identity."
	var account: String = CharacterStore.account(token)
	if account in _accounts.values():
		return "That character is already in the world."
	var saved: Dictionary = {}
	if store != null:
		var loaded: Dictionary = store.load_character(account)
		if loaded["status"] == "invalid":
			push_warning("Refused a join: the save %s %s." % [ProjectSettings.globalize_path(store.path_for(account)), loaded["reason"]])
			return "Your saved character on this host %s. Ask the host to restore its .bak file." % loaded["reason"]
		saved = loaded["data"]
	var returning: bool = not CharacterStore.saved_vocation(saved).is_empty()
	if not world.add_player(id, _now(), CharacterStore.saved_vocation(saved) if returning else vocation):
		return "This world is full (%d players maximum)." % World.MAX_PLAYERS
	_accounts[id] = account
	if returning:
		CharacterStore.restore(world, id, saved, _now())
		# A character saved inside a dungeon returns to its stairway: copies do not persist.
		instances.evacuate(id, _now())
		var player: Dictionary = world.players[id]
		_greetings[id] = "Welcome back: your level %d %s." % [player["level"], Balance.VOCATIONS[player["vocation"]]["name"]]
	elif store != null:
		_save_player(id)
	return ""


func _save_player(id: int) -> void:
	if store != null and _accounts.has(id) and world.players.has(id):
		if not store.save_character(_accounts[id], CharacterStore.capture(world, id, _now())):
			push_warning("Could not save a character to %s." % ProjectSettings.globalize_path(store.dir))


## Saves every character in the world (autosave, and when the host leaves).
func save_all() -> void:
	for id: int in _accounts:
		_save_player(id)


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
	_known_monsters.erase(id)
	_greetings.erase(id)
	if world.players.has(id):
		_save_player(id)
		_accounts.erase(id)
		var events: Array = []
		combat.leave_party(id, events)
		world.remove_player(id)
		actors.erase(id)
		if not _leaving:
			actor_left.rpc(id)
			_handle_events(events)


@rpc("any_peer", "call_remote", "reliable")
func hello(map_signature: Variant, vocation: Variant, token: Variant) -> void:
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
	var refused: String = _admit(sender, token if typeof(token) == TYPE_STRING else "", vocation)
	if not refused.is_empty():
		_reject_connection(sender, refused)
		return
	welcome.rpc_id(sender, world.snapshot(_now(), sender), world.ground_snapshot(), _interest_snapshot(sender, _now()), world_clock())
	_publish_actor(sender)
	if _greetings.has(sender):
		_send_feedback(sender, _greetings[sender], 0.0, false)
		_greetings.erase(sender)


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
func welcome(states: Dictionary, ground_state: Dictionary, monster_states: Dictionary, host_clock: float) -> void:
	if hosting:
		return
	_clock_offset = host_clock - _now()
	actors.clear()
	for id: int in states:
		_apply_actor(states[id])
	ground_view = ground_state.duplicate(true)
	monsters.clear()
	_monster_index.clear()
	for id: int in monster_states:
		_apply_monster(monster_states[id])
	self_id = multiplayer.get_unique_id()
	if not actors.has(self_id):
		_fail("The host sent a snapshot without your player.")
		return
	connected = true
	_joining_since = -1.0
	_status_message = "Connected to %s:%d" % [_address.text, port]
	action_bar.fill_spell_slots(actors[self_id]["state"]["vocation"])


func move_local(direction: Vector2i) -> void:
	if not connected or self_id == 0 or _move_pending_since >= 0.0:
		return
	_move_pending_since = _now()
	_next_move_attempt = _now() + World.MOVE_SECONDS
	if hosting:
		_handle_move(1, direction)
	else:
		request_move.rpc_id(1, direction)


## Party actions: "invite", "revoke", "join" (with the inviting leader), or "leave" (other = 0).
func party_local(action: String, other: int) -> void:
	if not connected or self_id == 0:
		return
	if hosting:
		_handle_party(1, action, other)
	else:
		request_party.rpc_id(1, action, other)


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


func quest_local(npc: String, relic: String) -> void:
	if not connected or self_id == 0:
		return
	if hosting:
		_handle_quest(1, npc, relic)
	else:
		request_quest.rpc_id(1, npc, relic)


# ---------------------------------------------------------------- town services

func task_local(npc: String, task: String, action: String) -> void:
	if not connected or self_id == 0:
		return
	if hosting:
		_handle_task(1, npc, task, action)
	else:
		request_task.rpc_id(1, npc, task, action)


func buy_local(npc: String, kind: String, count: int) -> void:
	if not connected or self_id == 0:
		return
	if hosting:
		_handle_buy(1, npc, kind, count)
	else:
		request_buy.rpc_id(1, npc, kind, count)


## Sells the backpack stack at `index`, or with -1 every monster material.
func sell_local(npc: String, index: int) -> void:
	if not connected or self_id == 0:
		return
	if hosting:
		_handle_sell(1, npc, index)
	else:
		request_sell.rpc_id(1, npc, index)


func bank_local(npc: String, action: String, amount: int) -> void:
	if not connected or self_id == 0:
		return
	if hosting:
		_handle_bank(1, npc, action, amount)
	else:
		request_bank.rpc_id(1, npc, action, amount)


func drink_local(index: int) -> void:
	if not connected or self_id == 0:
		return
	if hosting:
		_handle_drink(1, index)
	else:
		request_drink.rpc_id(1, index)


## Drinks the first potion of `kind` in the backpack (the potion keys).
func drink_kind(kind: String) -> void:
	if not actors.has(self_id):
		return
	var backpack: Array = actors[self_id]["state"].get("backpack", [])
	for index: int in backpack.size():
		if World.kind_of(backpack[index]) == kind:
			drink_local(index)
			return
	last_action_message = "You have no %ss." % World.ITEMS[kind]["name"].to_lower()


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
	var taken: Dictionary = {}
	for group: Dictionary in [actors, monsters]:
		for id: int in group:
			if id != self_id:
				taken[group[id]["state"]["cell"]] = true
	return Combat.path_step(own["cell"], goal, func(cell: Vector2i) -> bool: return taken.has(cell))


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
func request_party(action: Variant, other: Variant) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if _valid_sender(sender):
		_handle_party(sender, action, other)


func _handle_party(id: int, action: Variant, other: Variant) -> void:
	var result: Dictionary = combat.party_action(id, action, other, _now())
	if result["ok"]:
		_handle_events(result["events"])
	else:
		_send_feedback(id, result["reason"], 0.0, false)


@rpc("any_peer", "call_remote", "reliable")
func request_quest(npc: Variant, relic: Variant) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if _valid_sender(sender):
		_handle_quest(sender, npc, relic)


func _handle_quest(id: int, npc: Variant, relic: Variant) -> void:
	var result: Dictionary = combat.claim_relic(id, npc, relic, _now())
	if result["ok"]:
		_handle_events(result["events"])
	else:
		_send_feedback(id, result["reason"], 0.0, false)


@rpc("any_peer", "call_remote", "reliable")
func request_task(npc: Variant, task: Variant, action: Variant) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if _valid_sender(sender):
		_handle_task(sender, npc, task, action)


func _handle_task(id: int, npc: Variant, task: Variant, action: Variant) -> void:
	var result: Dictionary = combat.task_action(id, npc, task, action, _now())
	if result["ok"]:
		_handle_events(result["events"])
	else:
		_send_feedback(id, result["reason"], 0.0, false)


@rpc("any_peer", "call_remote", "reliable")
func request_drink(index: Variant) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if _valid_sender(sender):
		_handle_drink(sender, index)


func _handle_drink(id: int, index: Variant) -> void:
	var result: Dictionary = combat.drink(id, index, _now())
	if result["ok"]:
		_handle_events(result["events"])
	else:
		_send_feedback(id, result["reason"], 0.0, false)


@rpc("any_peer", "call_remote", "reliable")
func request_buy(npc: Variant, kind: Variant, count: Variant) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if _valid_sender(sender):
		_handle_buy(sender, npc, kind, count)


func _handle_buy(id: int, npc: Variant, kind: Variant, count: Variant) -> void:
	_publish_service(id, economy.buy(id, npc, kind, count, _now()))


@rpc("any_peer", "call_remote", "reliable")
func request_sell(npc: Variant, index: Variant) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if _valid_sender(sender):
		_handle_sell(sender, npc, index)


func _handle_sell(id: int, npc: Variant, index: Variant) -> void:
	_publish_service(id, economy.sell(id, npc, index, _now()))


@rpc("any_peer", "call_remote", "reliable")
func request_bank(npc: Variant, action: Variant, amount: Variant) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if _valid_sender(sender):
		_handle_bank(sender, npc, action, amount)


func _handle_bank(id: int, npc: Variant, action: Variant, amount: Variant) -> void:
	_publish_service(id, economy.bank(id, npc, action, amount, _now()))


## Vendor and bank results change only the requesting player's private state.
func _publish_service(id: int, result: Dictionary) -> void:
	if result["ok"]:
		_publish_actor(id)
		_send_feedback(id, result["message"], 0.0, false)
	else:
		_send_feedback(id, result["reason"], 0.0, false)


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
				_monster_died(event["id"])
				for peer_id: int in _remote_players():
					if _known_monsters.get(peer_id, {}).has(event["id"]):
						_known_monsters[peer_id].erase(event["id"])
						monster_gone.rpc_id(peer_id, event["id"])
			"ground":
				_publish_ground(event["cells"])
			"message":
				messages.append(event)
			_:
				_show_effect(event)
				var at: Vector2i = _event_cell(event)
				for peer_id: int in _remote_players():
					if _near_peer(peer_id, at):
						combat_event.rpc_id(peer_id, event)
	for id: int in players_changed:
		if world.players.has(id):
			_publish_actor(id)
	for id: int in monsters_changed:
		if world.monsters.has(id):
			_publish_monster(id)
	for event: Dictionary in messages:
		if world.players.has(event["id"]):
			_send_feedback(event["id"], event["text"], 0.0, false)


## The tile an effect happens on, for interest management.
func _event_cell(event: Dictionary) -> Vector2i:
	match event["kind"]:
		"missile":
			return event["from"]
		"area":
			return event["cells"][0] if not event["cells"].is_empty() else Vector2i(-9999, -9999)
	return event.get("cell", Vector2i(-9999, -9999))


func _near_peer(peer_id: int, cell: Vector2i) -> bool:
	if not world.players.has(peer_id):
		return false
	var own: Vector2i = world.players[peer_id]["cell"]
	return Combat.distance(own, cell) <= INTEREST_RADIUS and World.dungeon_at(own) == World.dungeon_at(cell)


## Sends a monster's state to the host's view and to remote players near it; peers it left
## behind are told it is gone.
func _publish_monster(id: int) -> void:
	var state: Dictionary = combat.export_monster(id, _now())
	_apply_monster(state)
	for peer_id: int in _remote_players():
		var known: Dictionary = _known_monsters.get_or_add(peer_id, {})
		if _near_peer(peer_id, state["cell"]):
			known[id] = true
			monster_updated.rpc_id(peer_id, state)
		elif known.has(id):
			known.erase(id)
			monster_gone.rpc_id(peer_id, id)


## Monsters near a joining player; remembered as what that peer knows.
func _interest_snapshot(peer_id: int, now: float) -> Dictionary:
	var result: Dictionary = {}
	var known: Dictionary = {}
	for id: int in world.monsters:
		if _near_peer(peer_id, world.monsters[id]["cell"]):
			result[id] = combat.export_monster(id, now)
			known[id] = true
	_known_monsters[peer_id] = known
	return result


## Brings each remote player's monsters up to date as they move: new ones in range, gone
## ones out of range (monsters that moved are already sent by _publish_monster).
func _sync_interest(now: float) -> void:
	for peer_id: int in _remote_players():
		var known: Dictionary = _known_monsters.get_or_add(peer_id, {})
		for id: int in world.monsters:
			var near: bool = _near_peer(peer_id, world.monsters[id]["cell"])
			if near and not known.has(id):
				known[id] = true
				monster_updated.rpc_id(peer_id, combat.export_monster(id, now))
		for id: int in known.keys():
			if not world.monsters.has(id) or not _near_peer(peer_id, world.monsters[id]["cell"]):
				known.erase(id)
				monster_gone.rpc_id(peer_id, id)


@rpc("authority", "call_remote", "reliable")
func monster_updated(state: Dictionary) -> void:
	_apply_monster(state)


@rpc("authority", "call_remote", "reliable")
func monster_gone(id: int) -> void:
	_monster_died(id)


func _monster_died(id: int) -> void:
	if monsters.has(id) and _world_view != null:
		_world_view.fx.burst("death", (monsters[id]["visual"] + Vector2(0.5, 0.5)) * World.TILE_SIZE, Color(0.75, 0.7, 0.8))
	monsters.erase(id)
	_monster_index.remove(id)


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
	var previous: Dictionary = monsters.get(id, {})
	monsters[id] = {"state": state.duplicate(true), "start": start, "visual": start, "duration": remaining, "elapsed": 0.0}
	_monster_index.put(id, state["cell"])
	_keep_attack(previous, monsters[id])


## An update arriving mid-swing must not cut the attack animation short.
func _keep_attack(previous: Dictionary, view: Dictionary) -> void:
	if previous.has("attack_born"):
		view["attack_born"] = previous["attack_born"]
		view["attack_facing"] = previous["attack_facing"]


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
				"mana": ["+%d" % event["amount"], Color("#6aa8ff")],
			}
			var style: Array = styles.get(event["style"], styles["damage"])
			var at: Vector2 = (view["visual"] + Vector2(0.5, 0.5)) * World.TILE_SIZE
			effects.append({"kind": "text", "pos": at, "text": style[0], "color": style[1], "born": born,
				"big": event["style"] == "critical"})
			var attacker: Dictionary = creature_view(int(event.get("source", 0)))
			if not attacker.is_empty() and event["style"] in ["damage", "critical"]:
				# Presentation only: the attacker swings toward the target; its real facing is unchanged.
				attacker["attack_born"] = born
				attacker["attack_facing"] = Combat.facing_toward(Vector2i(attacker["visual"].round()), event["cell"])
			if event["style"] in ["damage", "critical"] and event["amount"] > 0:
				_world_view.fx.burst("critical" if event["style"] == "critical" else "hit", at + Vector2(0, -8), style[1])
			elif event["style"] in ["heal", "mana"]:
				_world_view.fx.burst("heal", at, style[1])
		"missile":
			effects.append({"kind": "missile", "from": _map_point(event["from"]), "to": _map_point(event["to"]),
				"color": event["color"], "born": born})
			var landing: Vector2 = _map_point(event["to"])
			var tint: Color = event["color"]
			get_tree().create_timer(0.25).timeout.connect(func() -> void:
				if _world_view != null:
					_world_view.fx.burst("impact", landing, tint))
		"area":
			effects.append({"kind": "area", "cells": event["cells"], "color": event["color"], "born": born})
			_world_view.fx.area(event["cells"], event["color"])


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
		_handle_events(instances.after_move(id, _now()))
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
	elif id in multiplayer.get_peers():
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
		_ground_index.remove(cell)
	else:
		ground_view[cell] = stack.duplicate()
		_ground_index.put(cell, cell)


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
	if actors.has(id) and state.get("level", 1) > actors[id]["state"].get("level", 1) and _world_view != null:
		_world_view.fx.burst("level_up", (start + Vector2(0.5, 0.5)) * World.TILE_SIZE, Color("#ffd86a"))
	var previous: Dictionary = actors.get(id, {})
	actors[id] = {
		"state": state.duplicate(true), "start": start, "visual": start,
		"duration": remaining, "elapsed": 0.0, "received": _now(),
	}
	_keep_attack(previous, actors[id])
	if id == self_id:
		if movement:
			_move_pending_since = -1.0
			_next_move_attempt = _now() + remaining + 0.01


@rpc("authority", "call_remote", "reliable")
func actor_left(id: int) -> void:
	actors.erase(id)


# ---------------------------------------------------------------- UI

## Builds the game window and the panels through the components in game/ui/.
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_view = GameWindow.new()
	_view.setup(self)
	layer.add_child(_view)
	_world_view = _view.world_view
	hud = Hud.new()
	inventory = InventoryPanel.new()
	maps = WorldMaps.new()
	action_bar = ActionBar.new()
	dialogs = NpcDialogs.new()
	for component: Node in [hud, inventory, maps, action_bar, dialogs]:
		add_child(component)
	hud.build(self, layer)
	inventory.build(self, layer)
	maps.build(self, layer)
	action_bar.build(self, layer)
	dialogs.build(self, layer)
	start_panel = StartPanel.new()
	start_panel.setup(self, hud.address, hud.vocation)
	layer.add_child(start_panel)
	quest_list = QuestList.new()
	quest_list.game = self
	layer.add_child(quest_list)
	# Stacking, bottom to top: the panels above, then the start menu, zone banner, vitals, quest
	# list, location line, world map, dialog panel, and Controls menu.
	for top: Control in [hud.zone_label, hud.vitals, quest_list, hud.location_label, maps.world_map, dialogs.panel, hud.controls]:
		layer.move_child(top, -1)
	_address = hud.address
	_vocation = hud.vocation
	_controls = hud.controls
	_zone_label = hud.zone_label
	_minimap = maps.minimap
	_world_map = maps.world_map
	_travel_panel = dialogs.panel
	_travel_list = dialogs.list
	_npc_menu = dialogs.npc_menu


func _update_labels() -> void:
	hud.update_labels()
	inventory.update_stats()


# Entry points the tests and bots call on the main node; the components implement them.

func slot_position(location: Dictionary) -> Vector2:
	return inventory.slot_position(location)


func item_tooltip(kind: String) -> String:
	return inventory.item_tooltip(kind)


func party_options(person: int) -> Array[String]:
	return dialogs.party_options(person)


func open_player_menu(person: int, at: Vector2i) -> bool:
	return dialogs.open_player_menu(person, at)


func talk_to(ferryman: String) -> void:
	dialogs.talk_to(ferryman)


func open_quests(npc: String) -> void:
	dialogs.open_quests(npc)


func open_trade(npc: String) -> void:
	dialogs.open_trade(npc)


func open_bank(npc: String) -> void:
	dialogs.open_bank(npc)


func _close_travel() -> void:
	dialogs.close()


func selected_vocation() -> String:
	return Balance.VOCATIONS.keys()[maxi(0, _vocation.selected)]


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
	return inventory.item_drag(at, _view, _map_location(at))


func _map_can_drop(at: Vector2, data: Variant) -> bool:
	return inventory.item_can_drop(at, data, _map_location(at))


func _map_drop(at: Vector2, data: Variant) -> void:
	inventory.item_drop(at, data, _map_location(at))


func _map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		get_viewport().gui_release_focus()
		var cell: Vector2i = _map_location(event.position)["cell"]
		var npc: String = World.NPC_CELLS.get(cell, World.NPC_CELLS.get(cell + Vector2i.DOWN, ""))
		if event.button_index == MOUSE_BUTTON_RIGHT and not npc.is_empty():
			dialogs.open_npc_menu(npc, Vector2i(VIEW_ORIGIN + event.position))
			return
		var creature: int = _creature_at(cell)
		if event.button_index == MOUSE_BUTTON_RIGHT and connected:
			var person: int = creature if creature > 0 else (self_id if dialogs.is_self_at(cell) else 0)
			if person > 0 and dialogs.open_player_menu(person, Vector2i(VIEW_ORIGIN + event.position)):
				return
		if event.button_index == MOUSE_BUTTON_LEFT and creature != 0:
			target_local(0 if creature == own_target() else creature)
			return
		inventory.slot_input(event, _map_location(event.position))

