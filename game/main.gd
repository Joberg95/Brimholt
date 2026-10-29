extends Node2D
## The entry scene (/root/Main): ENet hosting and joining, the sender-validated RPC endpoint,
## replicated client state, the camera, and input. The UI components in game/ui/ build and
## draw the panels; main keeps shortcuts to their controls and thin wrappers for tests.

const World = preload("res://game/core/world.gd")
const Keybinds = preload("res://game/input/keybinds.gd")
const Combat = preload("res://game/core/combat.gd")
const Economy = preload("res://game/core/economy.gd")
const Crafting = preload("res://game/core/crafting.gd")
const Professions = preload("res://game/data/professions.gd")
const Instances = preload("res://game/core/instances.gd")
const CharacterStore = preload("res://game/persistence/character_store.gd")
const Identity = preload("res://game/persistence/identity.gd")
const Balance = preload("res://game/data/balance.gd")
const Titles = preload("res://game/data/titles.gd")
const Layout = preload("res://game/ui/layout.gd")
const GameWindow = preload("res://game/ui/game_window.gd")
const Hud = preload("res://game/ui/hud.gd")
const InventoryPanel = preload("res://game/ui/inventory_panel.gd")
const WorldMaps = preload("res://game/ui/world_maps.gd")
const ActionBar = preload("res://game/ui/action_bar.gd")
const NpcDialogs = preload("res://game/ui/npc_dialogs.gd")
const StartPanel = preload("res://game/ui/start_panel.gd")
const ClientState = preload("res://game/client/client_state.gd")
const QuestList = preload("res://game/ui/quest_list.gd")
const SpellBook = preload("res://game/ui/spell_book.gd")
const CharacterWindow = preload("res://game/ui/character_window.gd")
const GameMenu = preload("res://game/ui/game_menu.gd")
const UiTheme = preload("res://game/ui/ui_theme.gd")
const ProfessionsWindow = preload("res://game/ui/professions_window.gd")
const PartyWindow = preload("res://game/ui/party_window.gd")
const MicroMenu = preload("res://game/ui/micro_menu.gd")
const LexiconWindow = preload("res://game/ui/lexicon_window.gd")
const Bots = preload("res://game/core/bots.gd")
const Solo = preload("res://game/core/solo.gd")
const Gateway = preload("res://game/net/gateway.gd")
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
var crafting := Crafting.new(world)
## Gathering nodes this peer knows are regrowing: cell -> local _now() when they regrow.
var worked_nodes: Dictionary = {}
var instances := Instances.new(world, combat)
## Clients receive client.monsters and combat client.effects only within INTEREST_RADIUS tiles of their
## character; peer id -> {monster id: true} they currently know about.
const INTEREST_RADIUS: int = 24
const INTEREST_SECONDS: float = 0.25
var _known_monsters: Dictionary = {}
## Shown to a player when someone else is refused for joining with their identity.
const DUPLICATE_LOGIN_WARNING: String = "Someone tried to join as your character from another computer and was turned away."
var _next_interest: float = 0.0
## Opt-in frame profile (tools/testing/bench.gd): section -> [microseconds, frames, worst]. Off in play.
var profiling: bool = false
var frame_profile: Dictionary = {}
## What this peer draws: the players, client.monsters, ground, and client.effects the host sent (game/client/).
var client := ClientState.new()
## Every request a player sends the host (game/net/gateway.gd), at /root/Main/Gateway on every peer.
var gateway: Gateway
## How long a kill's green loot text stays over the body.
const LOOT_TEXT_SECONDS: float = 4.0
var connected: bool = false
var hosting: bool = false
## Playing solo: a private world (bound to this computer only) with companions and rival bands.
var solo_mode: bool = false
var solo: Solo
var dedicated: bool = false
var port: int = World.PORT
var last_action_message: String = ""
var peer: ENetMultiplayerPeer
var _pending_peers: Dictionary = {}
var _closing_peers: Dictionary = {}
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
## How well bots fight players with the trained policy (Bots.DIFFICULTY): picked next to
## "Play solo", or --bot-difficulty=easy|normal|hard.
var bot_difficulty: String = "normal"
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
## Whether identity_token came from identity_profile's file (so the start menu's summary of that
## character may be updated), and the summary last written.
var _profile_backed: bool = false
var _remembered: String = ""
## Automated tests and bots run in hidden windows and set this false, so a stray OS close
## request (a click or shortcut meant for another app) cannot end their session.
var close_ends_session: bool = true
var hud: Hud
var quest_list: QuestList
var spell_book: SpellBook
var character_window: CharacterWindow
## The cogwheel's menu: status, players, settings, Controls, and Leave game.
var game_menu: GameMenu
var professions_window: ProfessionsWindow
var party_window: PartyWindow
var micro_menu: MicroMenu
var lexicon: LexiconWindow
## Host-only player bots (game/core/bots.gd).
var bots: Bots
var inventory: InventoryPanel
var maps: WorldMaps
var action_bar: ActionBar
var dialogs: NpcDialogs
var start_panel: StartPanel
# Shortcuts to component controls, used by input handling and the tests.
var _address: LineEdit
## The vocation a new character asks to start with (--vocation=, for tests and bots); hosts only
## grant it when started with --allow-start-vocation, otherwise every new character is an Adventurer.
var start_vocation: String = Balance.ADVENTURER
var allow_start_vocation: bool = false
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
	gateway = Gateway.new()
	gateway.name = "Gateway"
	gateway.game = self
	add_child(gateway)
	keybinds.load_saved()
	# Menus and dialogs read small and minimal: every control without its own size uses this.
	ThemeDB.get_default_theme().default_font_size = UiTheme.FONT_SIZE
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
			if not Balance.is_vocation(choice):
				_fail("Class must be one of: %s, %s." % [", ".join(Balance.VOCATIONS.keys()), Balance.ADVENTURER])
				get_tree().quit(1)
				return
			start_vocation = choice
		elif arg == "--allow-start-vocation":
			allow_start_vocation = true
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
		elif arg.begins_with("--bot-difficulty="):
			bot_difficulty = arg.trim_prefix("--bot-difficulty=")
			if not bot_difficulty in Bots.DIFFICULTIES:
				_fail("Bot difficulty must be one of: %s." % ", ".join(Bots.DIFFICULTIES))
				get_tree().quit(1)
				return
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
			# ENet picks client ids at random: one that a bot already holds must join again.
			if bots.is_bot(id) and not _closing_peers.has(id):
				_reject_connection(id, "Your connection id is in use by a bot. Join again.")
			elif not world.players.has(id) and not _pending_peers.has(id):
				if not _closing_peers.has(id):
					_pending_peers[id] = now
	var mark: int = Time.get_ticks_usec()
	if hosting and not _leaving:
		_handle_events(combat.tick(now))
		mark = _profiled("combat", mark)
		_handle_events(bots.tick(now))
		mark = _profiled("bots", mark)
		if solo_mode:
			_handle_events(solo.tick(now))
		_handle_events(instances.tick(now))
		_handle_events(crafting.tick(now))
		_handle_events(world.decay_ground(now))
		mark = _profiled("other ticks", mark)
		if now >= _next_interest:
			_next_interest = now + INTEREST_SECONDS
			_sync_interest(now)
		mark = _profiled("interest", mark)
		if store != null and now >= _next_autosave:
			_next_autosave = now + CharacterStore.AUTOSAVE_SECONDS
			save_all()
	client.advance(delta, Time.get_ticks_msec() / 1000.0)
	if connected and client.self_id != 0 and not typing() and not _controls.visible \
			and _move_pending_since < 0.0 and now >= _next_move_attempt:
		var direction: Vector2i = _input_direction()
		if direction == Vector2i.ZERO:
			direction = client.chase_direction()
		if direction != Vector2i.ZERO:
			move_local(direction)
	mark = _profiled("actors and input", mark)
	_update_labels()
	inventory.redraw_slots()
	inventory.refresh_bags()
	_world_view.position = (VIEW_SIZE / 2.0 - camera_focus() * ZOOM).round()
	_world_view.queue_redraw()
	mark = _profiled("labels and inventory", mark)
	dialogs.refresh()
	hud.refresh()
	quest_list.refresh()
	spell_book.refresh()
	character_window.refresh()
	professions_window.refresh()
	party_window.refresh()
	start_panel.refresh()
	action_bar.redraw()
	micro_menu.redraw()
	maps.redraw()
	_profiled("windows and maps", mark)


## Adds the time since `since` to a profile section (when profiling); returns now.
func _profiled(section: String, since: int) -> int:
	var now: int = Time.get_ticks_usec()
	if profiling:
		var entry: Array = frame_profile.get(section, [0, 0, 0])
		frame_profile[section] = [entry[0] + now - since, entry[1] + 1, maxi(entry[2], now - since)]
	return now


func _input_direction() -> Vector2i:
	for pair: Array in [["move_up", Vector2i.UP], ["move_down", Vector2i.DOWN],
			["move_left", Vector2i.LEFT], ["move_right", Vector2i.RIGHT]]:
		if keybinds.is_held(pair[0]):
			return pair[1]
	return Vector2i.ZERO


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo() or (typing() and not _escape(event)):
		return
	if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
		if not _world_map.visible and not _travel_panel.visible and not _controls.visible and not spell_book.visible \
				and not character_window.visible and not professions_window.visible and not party_window.visible and not lexicon.visible \
				and client.own_target() != 0:
			target_local(0)
		_world_map.hide()
		_close_travel()
		_controls.hide()
		game_menu.hide()
		spell_book.hide()
		character_window.hide()
		professions_window.hide()
		party_window.hide()
		for window: PanelContainer in inventory.bag_windows:
			window.hide()
		lexicon.hide()
		return
	var key: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	var action: String = keybinds.action_for(key)
	if action.begins_with("slot_"):
		use_bar_slot(int(action.trim_prefix("slot_")) - 1)
	elif not action.is_empty():
		_run_action(action)


## Whether a text field (the address, the lexicon search) has the keyboard: game keys wait.
func typing() -> bool:
	return get_viewport().gui_get_focus_owner() is LineEdit


static func _escape(event: InputEventKey) -> bool:
	return event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE


## Opens or closes a panel from the micro menu: a Keybinds action, or "controls".
func toggle_panel(action: String) -> void:
	if action == "controls":
		var open: bool = game_menu.visible or _controls.visible
		_controls.hide()
		game_menu.visible = not open
	else:
		_run_action(action)


## Whether the micro menu should show a panel's button as open.
func panel_open(action: String) -> bool:
	match action:
		"character":
			return character_window.visible
		"professions":
			return professions_window.visible
		"party":
			return party_window.visible
		"lexicon":
			return lexicon.visible
		"spell_book":
			return spell_book.visible
		"quest_list":
			return quest_list.shown
		"world_map":
			return _world_map.visible
		"controls":
			return game_menu.visible or _controls.visible
	return false


## Casts the spell in an action-bar slot (0-8).
func use_bar_slot(slot: int) -> void:
	if slot < 0 or slot >= Keybinds.SLOTS or not connected:
		return
	if keybinds.bar[slot].begins_with("spell:"):
		cast_local(keybinds.bar[slot].trim_prefix("spell:"))
	elif keybinds.bar[slot].begins_with("item:"):
		rune_local(keybinds.bar[slot].trim_prefix("item:"))


## Casts a rune item from your backpack at your target (Combat.use_rune).
func rune_local(kind: String) -> void:
	if not connected or client.self_id == 0:
		return
	if hosting:
		gateway.handle_rune(1, kind)
	else:
		gateway.request_rune.rpc_id(1, kind)


func _run_action(action: String) -> void:
	if action == "world_map":
		_world_map.visible = not _world_map.visible
	elif action == "quest_list":
		quest_list.shown = not quest_list.shown
	elif action == "spell_book":
		spell_book.toggle()
	elif action == "character":
		character_window.toggle()
	elif action == "professions":
		professions_window.toggle()
	elif action == "party":
		party_window.toggle()
	elif action == "lexicon":
		lexicon.toggle()
	elif not connected:
		return
	elif action == "pick_up":
		pick_up_local()
	elif action == "target_nearest":
		target_nearest()
	elif action in ["health_potion", "mana_potion"]:
		drink_kind(action)
	elif action == "gather":
		gather_nearby()


func _reset_session() -> void:
	if peer != null:
		peer.close()
	peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	world = World.new()
	combat = Combat.new(world)
	economy = Economy.new(world)
	crafting = Crafting.new(world)
	worked_nodes.clear()
	instances = Instances.new(world, combat)
	bots = Bots.new(world, combat)
	bots.instances = instances
	bots.difficulty = bot_difficulty
	solo = Solo.new(world, combat, bots)
	solo_mode = false
	_known_monsters.clear()
	_next_interest = 0.0
	store = null
	_accounts.clear()
	_greetings.clear()
	client.clear()
	if _travel_panel != null:
		_close_travel()
		_world_map.hide()
	_pending_peers.clear()
	_closing_peers.clear()
	if gateway != null:
		gateway.reset()
	hosting = false
	connected = false
	_remembered = ""
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


## Hosts a game on the LAN, or (private) a solo world only this computer can reach, with your
## companions and rival bands (game/core/solo.gd).
func host_game(private: bool = false) -> void:
	_reset_session()
	solo_mode = private
	peer = ENetMultiplayerPeer.new()
	if private:
		peer.set_bind_ip("127.0.0.1")
	var error: Error = peer.create_server(0 if private else port, World.MAX_PLAYERS)
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
	client.ground_view = world.ground_snapshot()
	if not dedicated:
		client.self_id = 1
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
	if solo_mode and world.players.has(1):
		_handle_events(solo.start(1, _now()))
		_status_message = "Playing solo — invite companions in the party window; rivals roam the world"
	get_viewport().gui_release_focus()
	print("BRIMHOLT_HOST_READY port=%d" % port)


## Starts a private solo world (the start screen's Play solo).
func play_solo() -> void:
	host_game(true)


## Solo only: gathers a full raid around you, or sends it home (Solo.raid).
func raid_local(on: bool) -> void:
	if not solo_mode or not hosting:
		return
	var result: Dictionary = solo.raid(on, _now())
	if result["ok"]:
		_handle_events(result["events"])
	else:
		last_action_message = result["reason"]


## Solo only: gives a companion slot another class (Solo.set_companion).
func companion_local(slot: int, vocation: String) -> void:
	if not solo_mode or not hosting:
		return
	var result: Dictionary = solo.set_companion(slot, vocation, _now())
	_handle_events(result["events"])
	if not result["ok"]:
		last_action_message = result["reason"]


## Solo only: brings a companion slot's companion to your side, or sends it home (Solo.invite, Solo.dismiss).
func invite_local(slot: int, on: bool) -> void:
	if not solo_mode or not hosting:
		return
	var result: Dictionary = solo.invite(slot, _now()) if on else solo.dismiss(slot)
	_handle_events(result["events"])
	if not result["ok"]:
		last_action_message = result["reason"]


## Solo only: one more or one fewer of a class in the raid plan (Solo.set_raid_plan).
func raid_plan_local(vocation: String, delta: int) -> void:
	if not solo_mode or not hosting:
		return
	var result: Dictionary = solo.set_raid_plan(vocation, delta)
	if not result["ok"]:
		last_action_message = result["reason"]


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
		_profile_backed = not identity_token.is_empty()
	return identity_token


## Plays as a character profile from the start menu (game/persistence/identity.gd).
func select_character(profile: String) -> void:
	if not Identity.valid_profile(profile) or connected:
		return
	identity_profile = profile
	identity_token = ""
	_profile_backed = false
	Identity.set_last_profile(profile)


## Keeps the start menu's summary of the playing character current (class, level, and look as
## the host sends them; local only, never sent anywhere).
func _remember_character(state: Dictionary) -> void:
	if not _profile_backed:
		return
	var look: Dictionary = {}
	for slot: String in state["equipment"]:
		if slot != "bag":
			look[slot] = state["equipment"][slot]
	var key: String = "%s|%s|%s" % [state.get("vocation"), state.get("level"), look]
	if key != _remembered:
		_remembered = key
		Identity.remember(identity_profile, String(state.get("vocation", "")), int(state.get("level", 1)), look)


## Adds a joining player: their saved character if the host has one for this identity, else a
## new one of the chosen vocation (saved at once). Returns "" or why they cannot join.
func _admit(id: int, token: String, vocation: String) -> String:
	if not Identity.valid_token(token):
		return "Your client sent no valid identity."
	var account: String = CharacterStore.account(token)
	if account in _accounts.values():
		# Tell whoever plays the character: someone else holds their identity token.
		for holder: int in _accounts:
			if _accounts[holder] == account:
				_send_feedback(holder, DUPLICATE_LOGIN_WARNING, 0.0, false)
		return "That character is already in the world."
	var saved: Dictionary = {}
	if store != null:
		var loaded: Dictionary = store.load_character(account)
		if loaded["status"] == "invalid":
			push_warning("Refused a join: the save %s %s." % [ProjectSettings.globalize_path(store.path_for(account)), loaded["reason"]])
			return "Your saved character on this host %s. Ask the host to restore its .bak file." % loaded["reason"]
		saved = loaded["data"]
	var returning: bool = not CharacterStore.saved_vocation(saved).is_empty()
	var fresh: String = vocation if allow_start_vocation and Balance.VOCATIONS.has(vocation) else Balance.ADVENTURER
	if not world.add_player(id, _now(), CharacterStore.saved_vocation(saved) if returning else fresh):
		return "This world is full (%d players maximum)." % World.MAX_PLAYERS
	_accounts[id] = account
	if returning:
		CharacterStore.restore(world, id, saved, _now())
		# A character saved inside a dungeon returns to its stairway: copies do not persist.
		instances.evacuate(id, _now())
		var player: Dictionary = world.players[id]
		_greetings[id] = "Welcome back: your level %d %s." % [player["level"], Balance.profile_of(player["vocation"])["name"]]
	else:
		if fresh == Balance.ADVENTURER:
			_greetings[id] = "Welcome, adventurer. Master Hesk outside the training hall has a trial for you."
		if store != null:
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


## Host only: adds a bot beside you (or the first spawn on a dedicated server). Returns "" or why not.
func spawn_bot(vocation: String, level: int, stance: String) -> String:
	if not hosting:
		return "Only the host can add bots"
	var near: Vector2i = world.players[client.self_id]["cell"] if world.players.has(client.self_id) else World.SPAWNS[0]
	var added: Dictionary = bots.add(vocation, level, stance, near, _now())
	if not added["ok"]:
		return added["reason"]
	_publish_actor(added["id"])
	return ""


## Host only: removes a bot as if it had left.
func remove_bot(id: int) -> void:
	if not hosting or not bots.is_bot(id):
		return
	var events: Array = []
	combat.leave_party(id, events)
	bots.remove(id)
	client.actors.erase(id)
	actor_left.rpc(id)
	for other: int in world.players:
		if world.players[other]["target"] == id:
			world.players[other]["target"] = 0
			events.append({"kind": "player", "id": other})
	_handle_events(events)


func _peer_left(id: int) -> void:
	if not hosting:
		return
	_pending_peers.erase(id)
	_closing_peers.erase(id)
	gateway.forget(id)
	_known_monsters.erase(id)
	_greetings.erase(id)
	if world.players.has(id):
		_save_player(id)
		_accounts.erase(id)
		var events: Array = []
		combat.leave_party(id, events)
		world.remove_player(id)
		client.actors.erase(id)
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
	if not Balance.is_vocation(vocation):
		_reject_connection(sender, "Unknown class.")
		return
	var refused: String = _admit(sender, token if typeof(token) == TYPE_STRING else "", vocation)
	if not refused.is_empty():
		_reject_connection(sender, refused)
		return
	welcome.rpc_id(sender, world.snapshot(_now(), sender), world.ground_snapshot(), _interest_snapshot(sender, _now()), world_clock())
	var regrowing: Dictionary = {}
	for cell: Vector2i in crafting.depleted:
		regrowing[cell] = crafting.depleted[cell] - _now()
	nodes_worked.rpc_id(sender, regrowing)
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
	client.actors.clear()
	for id: int in states:
		_apply_actor(states[id])
	client.ground_view = ground_state.duplicate(true)
	client.clear_monsters()
	for id: int in monster_states:
		_apply_monster(monster_states[id])
	client.self_id = multiplayer.get_unique_id()
	if not client.actors.has(client.self_id):
		_fail("The host sent a snapshot without your player.")
		return
	connected = true
	_joining_since = -1.0
	_remember_character(client.actors[client.self_id]["state"])
	_status_message = "Connected to %s:%d" % [_address.text, port]
	action_bar.fill_spell_slots(client.actors[client.self_id]["state"]["vocation"])


func move_local(direction: Vector2i) -> void:
	if not connected or client.self_id == 0 or _move_pending_since >= 0.0:
		return
	_move_pending_since = _now()
	_next_move_attempt = _now() + World.MOVE_SECONDS
	if hosting:
		gateway.handle_move(1, direction)
	else:
		gateway.request_move.rpc_id(1, direction)


## Party actions: "invite", "revoke", "join" (with the inviting leader), or "leave" (other = 0).
func party_local(action: String, other: int) -> void:
	if not connected or client.self_id == 0:
		return
	if hosting:
		gateway.handle_party(1, action, other)
	else:
		gateway.request_party.rpc_id(1, action, other)


func equip_local(slot: String) -> void:
	if not connected or client.self_id == 0:
		return
	if hosting:
		gateway.handle_equipment(1, slot)
	else:
		gateway.request_equipment.rpc_id(1, slot)


func move_item_local(source: Dictionary, target: Dictionary) -> void:
	if not connected or client.self_id == 0:
		return
	if hosting:
		gateway.handle_item_move(1, source, target)
	else:
		gateway.request_item_move.rpc_id(1, source, target)


## Picks up the top item on your tile, or else on the tile you face.
func pick_up_local() -> void:
	if not client.actors.has(client.self_id):
		return
	var state: Dictionary = client.actors[client.self_id]["state"]
	var cell: Vector2i = state["cell"]
	if not client.ground_view.has(cell):
		cell += Vector2i(state["facing"])
	move_item_local({"type": "ground", "cell": cell}, {"type": "backpack"})


func travel_local(ferryman: String, destination: String) -> void:
	if not connected or client.self_id == 0:
		return
	if hosting:
		gateway.handle_travel(1, ferryman, destination)
	else:
		gateway.request_travel.rpc_id(1, ferryman, destination)


func quest_local(npc: String, relic: String) -> void:
	if not connected or client.self_id == 0:
		return
	if hosting:
		gateway.handle_quest(1, npc, relic)
	else:
		gateway.request_quest.rpc_id(1, npc, relic)


# ---------------------------------------------------------------- town services

func task_local(npc: String, task: String, action: String) -> void:
	if not connected or client.self_id == 0:
		return
	if hosting:
		gateway.handle_task(1, npc, task, action)
	else:
		gateway.request_task.rpc_id(1, npc, task, action)


## Whether this peer knows a gathering node is regrowing.
func node_worked(cell: Vector2i) -> bool:
	return worked_nodes.get(cell, -INF) > _now()


## Starts gathering at a node (the host checks reach, skill, and the node).
func gather_local(cell: Vector2i) -> void:
	if not connected or client.self_id == 0:
		return
	if hosting:
		gateway.handle_gather(1, cell)
	else:
		gateway.request_gather.rpc_id(1, cell)


## Gathers from the nearest unworked node within reach: the tile you face first.
func gather_nearby() -> void:
	if not client.actors.has(client.self_id):
		return
	var state: Dictionary = client.actors[client.self_id]["state"]
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
		last_action_message = "Nothing to gather within reach."
		return
	gather_local(best)


## Asks an artisan to craft `count` of a recipe (the host checks the skill and resources).
func craft_local(npc: String, recipe: String, count: int) -> void:
	if not connected or client.self_id == 0:
		return
	if hosting:
		gateway.handle_craft(1, npc, recipe, count)
	else:
		gateway.request_craft.rpc_id(1, npc, recipe, count)


## Asks your class trainer to raise a spell's rank for rune shards (the host checks everything).
func empower_local(npc: String, spell: String) -> void:
	if not connected or client.self_id == 0:
		return
	if hosting:
		gateway.handle_empower(1, npc, spell)
	else:
		gateway.request_empower.rpc_id(1, npc, spell)


## Asks a trainer to make you their vocation (permanent; the host checks the trial and level).
func vocation_local(npc: String) -> void:
	if not connected or client.self_id == 0:
		return
	if hosting:
		gateway.handle_vocation(1, npc)
	else:
		gateway.request_vocation.rpc_id(1, npc)


## Turns your PvP on or off at the warden (Combat.set_pvp checks reach, skull, fight, and cooldown).
func pvp_local(npc: String, on: bool) -> void:
	if not connected or client.self_id == 0:
		return
	if hosting:
		gateway.handle_pvp(1, npc, on)
	else:
		gateway.request_pvp.rpc_id(1, npc, on)


func buy_local(npc: String, kind: String, count: int) -> void:
	if not connected or client.self_id == 0:
		return
	if hosting:
		gateway.handle_buy(1, npc, kind, count)
	else:
		gateway.request_buy.rpc_id(1, npc, kind, count)


## Sells the backpack stack at `index`, or with -1 every monster material.
func sell_local(npc: String, index: int) -> void:
	if not connected or client.self_id == 0:
		return
	if hosting:
		gateway.handle_sell(1, npc, index)
	else:
		gateway.request_sell.rpc_id(1, npc, index)


func bank_local(npc: String, action: String, amount: int) -> void:
	if not connected or client.self_id == 0:
		return
	if hosting:
		gateway.handle_bank(1, npc, action, amount)
	else:
		gateway.request_bank.rpc_id(1, npc, action, amount)


func drink_local(index: int) -> void:
	if not connected or client.self_id == 0:
		return
	if hosting:
		gateway.handle_drink(1, index)
	else:
		gateway.request_drink.rpc_id(1, index)


## Drinks the strongest potion sharing `kind`'s timer in the backpack (the potion keys: a
## great health potion before a strong one before a plain one).
func drink_kind(kind: String) -> void:
	if not client.actors.has(client.self_id):
		return
	var backpack: Array = client.actors[client.self_id]["state"].get("backpack", [])
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
	last_action_message = "You have no %ss." % World.ITEMS[kind]["name"].to_lower()


# ---------------------------------------------------------------- combat

func target_local(target: int) -> void:
	if not connected or client.self_id == 0:
		return
	if hosting:
		gateway.handle_target(1, target)
	else:
		gateway.request_target.rpc_id(1, target)


func cast_local(spell: String) -> void:
	if not connected or client.self_id == 0:
		return
	if hosting:
		gateway.handle_spell(1, spell)
	else:
		gateway.request_spell.rpc_id(1, spell)


## Locks the nearest monster within targeting range.
func target_nearest() -> void:
	if not client.actors.has(client.self_id):
		return
	var own: Vector2i = client.actors[client.self_id]["state"]["cell"]
	var best: int = 0
	var best_distance: int = Combat.TARGET_RANGE + 1
	for id: int in client.monsters:
		var gap: int = Combat.distance(own, client.monsters[id]["state"]["cell"])
		if gap < best_distance:
			best = id
			best_distance = gap
	if best != 0:
		target_local(best)


## Nodes being worked, with seconds until they regrow (one when worked, all on joining).
@rpc("authority", "call_remote", "reliable")
func nodes_worked(regrowing: Dictionary) -> void:
	for cell: Variant in regrowing:
		if typeof(cell) == TYPE_VECTOR2I and typeof(regrowing[cell]) in [TYPE_INT, TYPE_FLOAT]:
			worked_nodes[cell] = _now() + float(regrowing[cell])


## Replicates combat events: visuals immediately, then each changed creature once, then messages.
func _handle_events(events: Array) -> void:
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
				for peer_id: int in _remote_players():
					if _known_monsters.get(peer_id, {}).has(event["id"]):
						_known_monsters[peer_id].erase(event["id"])
						monster_gone.rpc_id(peer_id, event["id"])
			"ground":
				_publish_ground(event["cells"])
			"message":
				messages.append(event)
			"loot":
				# Loot text is only for the players the kill is credited to.
				for looter: int in event["ids"]:
					if looter == client.self_id:
						_show_effect(event)
					elif looter in _remote_players():
						combat_event.rpc_id(looter, event)
			"bot_left":
				client.actors.erase(event["id"])
				actor_left.rpc(event["id"])
			"node":
				var regrowing: Dictionary = {event["cell"]: event["seconds"]}
				nodes_worked(regrowing)
				for peer_id: int in _remote_players():
					nodes_worked.rpc_id(peer_id, regrowing)
			_:
				_show_effect(event)
				var at: Vector2i = _event_cell(event)
				for peer_id: int in _remote_players():
					if _near_peer(peer_id, at):
						combat_event.rpc_id(peer_id, event)
	for id: int in players_changed:
		if world.players.has(id):
			_publish_actor(id, players_changed[id])
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


## Brings each remote player's client.monsters up to date as they move: new ones in range, gone
## ones out of range (client.monsters that moved are already sent by _publish_monster).
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
	if client.monsters.has(id) and _world_view != null:
		_world_view.fx.burst("death", (client.monsters[id]["visual"] + Vector2(0.5, 0.5)) * World.TILE_SIZE, Color(0.75, 0.7, 0.8))
	client.remove_monster(id)


@rpc("authority", "call_remote", "reliable")
func combat_event(event: Dictionary) -> void:
	_show_effect(event)


func _apply_monster(state: Dictionary) -> void:
	client.put_monster(state)


func _map_point(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * World.TILE_SIZE


func _show_effect(event: Dictionary) -> void:
	var born: float = Time.get_ticks_msec() / 1000.0
	match event.get("kind", ""):
		"hit":
			var view: Dictionary = client.creature_view(event["target"])
			if view.is_empty() or (event["amount"] <= 0 and event["style"] != "damage"):
				return
			var styles: Dictionary = {
				"damage": [str(event["amount"]), Color("#ff4a3a")], "critical": ["%d!" % event["amount"], Color("#ffa030")],
				"heal": ["+%d" % event["amount"], Color("#6ae07a")], "experience": ["%d xp" % event["amount"], Color("#f4f4f4")],
				"mana": ["+%d" % event["amount"], Color("#6aa8ff")], "ward": ["-%d" % event["amount"], Color("#6aa8ff")],
			}
			var style: Array = styles.get(event["style"], styles["damage"])
			var at: Vector2 = (view["visual"] + Vector2(0.5, 0.5)) * World.TILE_SIZE
			if game_menu == null or game_menu.settings.get("damage_numbers", true):
				client.effects.append({"kind": "text", "pos": at, "text": style[0], "color": style[1], "born": born,
					"big": event["style"] == "critical"})
			var attacker: Dictionary = client.creature_view(int(event.get("source", 0)))
			if not attacker.is_empty() and event["style"] in ["damage", "critical"]:
				# Presentation only: the attacker swings toward the target; its real facing is unchanged.
				attacker["attack_born"] = born
				attacker["attack_facing"] = Combat.facing_toward(Vector2i(attacker["visual"].round()), event["cell"])
			if event["style"] in ["damage", "critical"] and event["amount"] > 0:
				_world_view.fx.burst("critical" if event["style"] == "critical" else "hit", at + Vector2(0, -8), style[1])
			elif event["style"] in ["heal", "mana"]:
				_world_view.fx.burst("heal", at, style[1])
		"loot":
			var over: Vector2 = _map_point(event["cell"])
			client.effects.append({"kind": "loot", "pos": over, "text": event["text"], "born": born, "life": LOOT_TEXT_SECONDS})
			if event.has("label"):
				client.effects.append({"kind": "label", "pos": over, "text": event["label"][0], "color": event["label"][1],
					"born": born, "life": 2.5})
		"missile":
			var element: String = event.get("element", "")
			client.effects.append({"kind": "missile", "from": _map_point(event["from"]), "to": _map_point(event["to"]),
				"color": event["color"], "born": born, "element": element})
			var landing: Vector2 = _map_point(event["to"])
			var tint: Color = event["color"]
			var target: Vector2i = event["to"]
			# The spell's impact plays on the target's tile when the missile lands (at once for a
			# melee strike, which does not fly).
			var lands: float = 0.0 if element == "slash" else 0.25
			var impact: Callable = func() -> void:
				if _world_view == null:
					return
				_world_view.fx.burst("impact", landing, tint)
				if not element.is_empty():
					client.effects.append({"kind": "area", "cells": [target], "color": tint, "born": Time.get_ticks_msec() / 1000.0,
						"element": element})
			if lands <= 0.0:
				impact.call()
			else:
				get_tree().create_timer(lands).timeout.connect(impact)
		"area":
			client.effects.append({"kind": "area", "cells": event["cells"], "color": event["color"], "born": born,
				"element": event.get("element", ""), "life": maxf(1.1, float(event.get("life", 0.0)))})
			_world_view.fx.area(event["cells"], event["color"])


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
	_apply_actor(world.export_player(id, now, id == client.self_id), movement)
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
	client.put_ground(cell, stack)


@rpc("authority", "call_remote", "reliable")
func actor_updated(state: Dictionary, movement: bool) -> void:
	_apply_actor(state, movement)


func _apply_actor(state: Dictionary, movement: bool = false) -> void:
	var id: int = state["id"]
	var start: Vector2 = client.actor_start(state)
	var previous: Dictionary = client.actors.get(id, {})
	if not previous.is_empty() and _world_view != null:
		if state.get("level", 1) > previous["state"].get("level", 1):
			_world_view.fx.burst("level_up", (start + Vector2(0.5, 0.5)) * World.TILE_SIZE, Color("#ffd86a"))
		if state.get("title", 0) > previous["state"].get("title", 0):
			_world_view.fx.burst("level_up", (start + Vector2(0.5, 0.5)) * World.TILE_SIZE, Titles.color_of(state["title"]))
	client.put_actor(state, start, _now())
	if id == client.self_id and connected:
		_remember_character(state)
	if id == client.self_id and movement:
		_move_pending_since = -1.0
		_next_move_attempt = _now() + state["remaining"] + 0.01


@rpc("authority", "call_remote", "reliable")
func actor_left(id: int) -> void:
	client.actors.erase(id)


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
	# The start screen covers the whole window, above every other UI, until you host or join.
	var start_layer := CanvasLayer.new()
	start_layer.layer = layer.layer + 5
	add_child(start_layer)
	start_panel = StartPanel.new()
	start_layer.add_child(start_panel)
	start_panel.setup(self, hud.address)
	quest_list = QuestList.new()
	quest_list.game = self
	layer.add_child(quest_list)
	spell_book = SpellBook.new()
	spell_book.game = self
	layer.add_child(spell_book)
	character_window = CharacterWindow.new()
	character_window.game = self
	layer.add_child(character_window)
	professions_window = ProfessionsWindow.new()
	professions_window.game = self
	layer.add_child(professions_window)
	party_window = PartyWindow.new()
	party_window.game = self
	layer.add_child(party_window)
	lexicon = LexiconWindow.new()
	lexicon.game = self
	layer.add_child(lexicon)
	micro_menu = MicroMenu.new()
	add_child(micro_menu)
	micro_menu.build(self, layer)
	game_menu = GameMenu.new()
	layer.add_child(game_menu)
	game_menu.build(self, func() -> void: hud.controls.show())
	# Stacking, bottom to top: the panels above, then the start menu, zone banner, vitals, quest
	# list, location line, spell book, character window, lexicon, world map, dialog panel, and Controls menu.
	for top: Control in [hud.zone_label, hud.vitals, quest_list, hud.location_label, spell_book, character_window,
			professions_window, party_window, lexicon, maps.world_map, dialogs.panel, game_menu, hud.controls]:
		layer.move_child(top, -1)
	_address = hud.address
	_controls = hud.controls
	_zone_label = hud.zone_label
	_minimap = maps.minimap
	_world_map = maps.world_map
	_travel_panel = dialogs.panel
	_travel_list = dialogs.list
	_npc_menu = dialogs.npc_menu


func _update_labels() -> void:
	hud.update_labels()
	game_menu.refresh()
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
	return start_vocation


## Map pixel the camera centres: your character's interpolated position, else the map centre.
func camera_focus() -> Vector2:
	if client.actors.has(client.self_id):
		return (client.actors[client.self_id]["visual"] + Vector2(0.5, 0.5)) * World.TILE_SIZE
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
		var creature: int = client.creature_at(cell)
		if event.button_index == MOUSE_BUTTON_RIGHT and connected:
			# Creatures never block a tile, so loot under someone is picked up rather than opening their menu.
			var person: int = creature if creature > 0 and not client.ground_view.has(cell) else 0
			if person > 0 and dialogs.open_player_menu(person, Vector2i(VIEW_ORIGIN + event.position)):
				return
			if person == 0 and not Crafting.node_at(cell).is_empty() and not client.ground_view.has(cell):
				gather_local(cell)
				return
		if event.button_index == MOUSE_BUTTON_LEFT and creature != 0:
			target_local(0 if creature == client.own_target() else creature)
			return
		inventory.slot_input(event, _map_location(event.position))

