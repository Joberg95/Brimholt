extends Node
## The network session (plan 48), /root/Main/Session on every peer: hosting (LAN, solo, or
## dedicated) and joining over ENet, the join handshake (map signature, identity, and the welcome
## snapshot), admitting players with their saved characters, saving, bots, and leaving. The command
## line options are read here (configure).

const World = preload("res://game/core/world.gd")
const WorldMap = preload("res://game/world_map/world_map.gd")
const CharacterStore = preload("res://game/persistence/character_store.gd")
const Identity = preload("res://game/persistence/identity.gd")
const Balance = preload("res://game/data/balance.gd")
const Bots = preload("res://game/core/bots.gd")

## Shown to a player when someone else is refused for joining with their identity.
const DUPLICATE_LOGIN_WARNING: String = "Someone tried to join as your character from another computer and was turned away."
## Seconds a joining client may take: connecting, and the handshake once connected.
const JOIN_SECONDS: float = 8.0
const HANDSHAKE_SECONDS: float = 5.0

## The main node (game/main.gd): the simulation, the replicated view, and the UI.
var game: Node
var connected: bool = false
var hosting: bool = false
## Playing solo: a private world (bound to this computer only) with companions and rival bands.
var solo_mode: bool = false
var dedicated: bool = false
var port: int = World.PORT
var peer: ENetMultiplayerPeer
var status_message: String = "Offline — host a world or join a LAN address."
## Hosts save characters (game/persistence/character_store.gd) unless started with --no-save;
## --save-dir=PATH picks the folder (default user://saves).
var save_enabled: bool = true
var save_dir: String = CharacterStore.DEFAULT_DIR
var store: CharacterStore
## How well bots fight players with the trained policy (Bots.DIFFICULTY): picked next to
## "Play solo", or --bot-difficulty=easy|normal|hard.
var bot_difficulty: String = "normal"
## This computer's identity token (game/persistence/identity.gd): from --profile=NAME, a new
## one per run with --fresh-identity (tests), or --token=HEX.
var identity_token: String = ""
var identity_profile: String = ""
## The vocation a new character asks to start with (--vocation=, for tests and bots); hosts only
## grant it when started with --allow-start-vocation, otherwise every new character is an Adventurer.
var start_vocation: String = Balance.ADVENTURER
var allow_start_vocation: bool = false
## Peers being disconnected (their requests and updates are ignored meanwhile).
var closing_peers: Dictionary = {}
## Peers connected but not yet through the handshake: id -> when they connected.
var _pending_peers: Dictionary = {}
var _joining_since: float = -1.0
var _leaving: bool = false
## Peer id -> save account (SHA-256 of the identity token) of every character in the world.
var _accounts: Dictionary = {}
var _next_autosave: float = 0.0
## Welcome-back messages for restored characters, sent after their snapshot.
var _greetings: Dictionary = {}
## Whether identity_token came from identity_profile's file (so the start menu's summary of that
## character may be updated), and the summary last written.
var _profile_backed: bool = false
var _remembered: String = ""


func _ready() -> void:
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_left)
	multiplayer.connected_to_server.connect(_connected_to_host)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_host_lost)


## Reads the command line: --vocation, --allow-start-vocation, --port, --no-save, --save-dir,
## --fresh-identity, --token, --profile, --bot-difficulty, then --host, --headless-server, or
## --join. False (after reporting why) if the program should exit with status 1.
func configure(args: PackedStringArray) -> bool:
	for arg: String in args:
		if arg.begins_with("--vocation="):
			var choice: String = arg.trim_prefix("--vocation=")
			if not Balance.is_vocation(choice):
				fail("Class must be one of: %s, %s." % [", ".join(Balance.VOCATIONS.keys()), Balance.ADVENTURER])
				return false
			start_vocation = choice
		elif arg == "--allow-start-vocation":
			allow_start_vocation = true
	for arg: String in args:
		if arg.begins_with("--port="):
			var value: String = arg.trim_prefix("--port=")
			if not value.is_valid_int() or int(value) < 1 or int(value) > 65535:
				fail("Port must be an integer from 1 to 65535.")
				return false
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
				fail("Bot difficulty must be one of: %s." % ", ".join(Bots.DIFFICULTIES))
				return false
	if not Identity.valid_profile(identity_profile) or not (identity_token.is_empty() or Identity.valid_token(identity_token)):
		fail("Profiles use letters, digits, - and _; tokens are 64 lowercase hex digits.")
		return false
	dedicated = "--headless-server" in args
	if "--host" in args or dedicated:
		host_game()
		if not connected:
			return false
	for arg: String in args:
		if arg.begins_with("--join="):
			game._address.text = arg.trim_prefix("--join=")
			join_game()
			if _joining_since < 0.0:
				return false
	return true


## The host's handshake deadlines, peers whose id a bot holds, and autosave; a client's join deadline.
func tick(now: float) -> void:
	if _joining_since >= 0.0 and now - _joining_since > JOIN_SECONDS:
		fail("Connection timed out. Check the LAN address, UDP port %d and firewall." % port)
	if not hosting or _leaving:
		return
	for id: int in _pending_peers.keys():
		if now - _pending_peers[id] > HANDSHAKE_SECONDS:
			_pending_peers.erase(id)
			reject_connection(id, "Client handshake timed out.")
	for id: int in multiplayer.get_peers():
		# ENet picks client ids at random: one that a bot already holds must join again.
		if game.bots.is_bot(id) and not closing_peers.has(id):
			reject_connection(id, "Your connection id is in use by a bot. Join again.")
		elif not game.world.players.has(id) and not _pending_peers.has(id):
			if not closing_peers.has(id):
				_pending_peers[id] = now


## Host: whether the simulation should run this frame.
func running() -> bool:
	return hosting and not _leaving


## Host: saves every character on schedule.
func autosave(now: float) -> void:
	if store != null and now >= _next_autosave:
		_next_autosave = now + CharacterStore.AUTOSAVE_SECONDS
		save_all()


func _reset() -> void:
	if peer != null:
		peer.close()
	peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	game.reset_world()
	solo_mode = false
	store = null
	_accounts.clear()
	_greetings.clear()
	_pending_peers.clear()
	closing_peers.clear()
	hosting = false
	connected = false
	_remembered = ""
	_joining_since = -1.0
	_leaving = false


## Ends the session with a message on the start screen (and in the log).
func fail(message: String) -> void:
	_reset()
	status_message = message
	push_error(message)
	game._update_labels()


## Hosts a game on the LAN, or (private) a solo world only this computer can reach, with your
## companions and rival bands (game/core/solo.gd).
func host_game(private: bool = false) -> void:
	_reset()
	solo_mode = private
	peer = ENetMultiplayerPeer.new()
	if private:
		peer.set_bind_ip("127.0.0.1")
	var error: Error = peer.create_server(0 if private else port, World.MAX_PLAYERS)
	if error != OK:
		fail("Cannot host on UDP port %d: %s" % [port, error_string(error)])
		return
	if save_enabled:
		store = CharacterStore.new(save_dir)
		var unusable: String = store.open()
		if not unusable.is_empty():
			fail(unusable)
			return
		_next_autosave = game._now() + CharacterStore.AUTOSAVE_SECONDS
	multiplayer.multiplayer_peer = peer
	hosting = true
	connected = true
	game.client.ground_view = game.world.ground_snapshot()
	if not dedicated:
		game.client.self_id = 1
		var refused: String = _admit(1, own_token(), start_vocation)
		if not refused.is_empty():
			fail(refused)
			return
		game.replication.apply_actor(game.world.export_player(1, game._now(), true))
		game.action_bar.fill_spell_slots(game.world.players[1]["vocation"])
		game.last_action_message = _greetings.get(1, "")
		_greetings.erase(1)
	game.replication.handle_events(game.combat.populate(game._now()))
	status_message = "Hosting on UDP %d%s" % [port, " (dedicated)" if dedicated else " — you are the host"]
	if solo_mode and game.world.players.has(1):
		game.replication.handle_events(game.solo.start(1, game._now()))
		status_message = "Playing solo — invite companions in the party window; rivals roam the world"
	get_viewport().gui_release_focus()
	print("BRIMHOLT_HOST_READY port=%d" % port)


## Starts a private solo world (the start screen's Play solo).
func play_solo() -> void:
	host_game(true)


func join_game() -> void:
	var address: String = game._address.text.strip_edges()
	_reset()
	if address.is_empty():
		fail("Enter the host's LAN IP address first.")
		return
	peer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(address, port)
	if error != OK:
		fail("Cannot connect to %s:%d: %s" % [address, port, error_string(error)])
		return
	multiplayer.multiplayer_peer = peer
	_joining_since = game._now()
	status_message = "Connecting to %s:%d…" % [address, port]
	get_viewport().gui_release_focus()


func leave_game() -> void:
	if hosting:
		save_all()
	var leaving_peer: ENetMultiplayerPeer = peer
	_leaving = true
	connected = false
	game.api.move_pending_since = -1.0
	_joining_since = -1.0
	if leaving_peer != null:
		if hosting:
			for id: int in multiplayer.get_peers():
				leaving_peer.disconnect_peer(id)
		elif 1 in multiplayer.get_peers():
			leaving_peer.disconnect_peer(1)
		await get_tree().create_timer(0.2).timeout
	if peer == leaving_peer:
		_reset()
		status_message = "Disconnected — host or join to play again."


func _peer_connected(id: int) -> void:
	if peer != null and (hosting or id == 1):
		peer.get_peer(id).set_timeout(16, 1000, 5000)


func _connected_to_host() -> void:
	hello.rpc_id(1, World.signature(), start_vocation, own_token())


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
func remember_character(state: Dictionary) -> void:
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
				game.replication.send_feedback(holder, DUPLICATE_LOGIN_WARNING, 0.0, false)
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
	if not game.world.add_player(id, game._now(), CharacterStore.saved_vocation(saved) if returning else fresh):
		return "This world is full (%d players maximum)." % World.MAX_PLAYERS
	_accounts[id] = account
	if returning:
		CharacterStore.restore(game.world, id, saved, game._now())
		# A character saved inside a dungeon returns to its stairway: copies do not persist.
		game.instances.evacuate(id, game._now())
		var player: Dictionary = game.world.players[id]
		_greetings[id] = "Welcome back: your level %d %s." % [player["level"], Balance.profile_of(player["vocation"])["name"]]
	else:
		if fresh == Balance.ADVENTURER:
			_greetings[id] = "Welcome, adventurer. Master Hesk outside the training hall has a trial for you."
		if store != null:
			save_player(id)
	return ""


func save_player(id: int) -> void:
	if store != null and _accounts.has(id) and game.world.players.has(id):
		if not store.save_character(_accounts[id], CharacterStore.capture(game.world, id, game._now())):
			push_warning("Could not save a character to %s." % ProjectSettings.globalize_path(store.dir))


## Saves every character in the world (autosave, and when the host leaves).
func save_all() -> void:
	for id: int in _accounts:
		save_player(id)


func _connection_failed() -> void:
	fail("Could not reach the host. Check the address, UDP %d and firewall." % port)


func _host_lost() -> void:
	if not _leaving:
		fail("The host disconnected. Your LAN session has ended.")


## Host only: adds a bot beside you (or the first spawn on a dedicated server). Returns "" or why not.
func spawn_bot(vocation: String, level: int, stance: String) -> String:
	if not hosting:
		return "Only the host can add bots"
	var self_id: int = game.client.self_id
	var near: Vector2i = game.world.players[self_id]["cell"] if game.world.players.has(self_id) else WorldMap.SPAWNS[0]
	var added: Dictionary = game.bots.add(vocation, level, stance, near, game._now())
	if not added["ok"]:
		return added["reason"]
	game.replication.publish_actor(added["id"])
	return ""


## Host only: removes a bot as if it had left.
func remove_bot(id: int) -> void:
	if not hosting or not game.bots.is_bot(id):
		return
	var events: Array = []
	game.combat.leave_party(id, events)
	game.bots.remove(id)
	game.client.actors.erase(id)
	game.replication.actor_left.rpc(id)
	for other: int in game.world.players:
		if game.world.players[other]["target"] == id:
			game.world.players[other]["target"] = 0
			events.append({"kind": "player", "id": other})
	game.replication.handle_events(events)


func _peer_left(id: int) -> void:
	if not hosting:
		return
	_pending_peers.erase(id)
	closing_peers.erase(id)
	game.gateway.forget(id)
	game.replication.forget(id)
	_greetings.erase(id)
	if game.world.players.has(id):
		save_player(id)
		_accounts.erase(id)
		var events: Array = []
		game.combat.leave_party(id, events)
		game.world.remove_player(id)
		game.client.actors.erase(id)
		if not _leaving:
			game.replication.actor_left.rpc(id)
			game.replication.handle_events(events)


@rpc("any_peer", "call_remote", "reliable")
func hello(map_signature: Variant, vocation: Variant, token: Variant) -> void:
	if not hosting:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender <= 1 or sender not in multiplayer.get_peers() \
			or game.world.players.has(sender) or closing_peers.has(sender):
		return
	_pending_peers.erase(sender)
	if typeof(map_signature) != TYPE_STRING or map_signature != World.signature():
		reject_connection(sender, "World/protocol mismatch. Use the same project files as the host.")
		return
	if not Balance.is_vocation(vocation):
		reject_connection(sender, "Unknown class.")
		return
	var refused: String = _admit(sender, token if typeof(token) == TYPE_STRING else "", vocation)
	if not refused.is_empty():
		reject_connection(sender, refused)
		return
	var now: float = game._now()
	welcome.rpc_id(sender, game.world.snapshot(now, sender), game.world.ground_snapshot(),
		game.replication.interest_snapshot(sender, now), game.world_clock())
	var regrowing: Dictionary = {}
	for cell: Vector2i in game.crafting.depleted:
		regrowing[cell] = game.crafting.depleted[cell] - now
	game.replication.nodes_worked.rpc_id(sender, regrowing)
	game.replication.publish_actor(sender)
	if _greetings.has(sender):
		game.replication.send_feedback(sender, _greetings[sender], 0.0, false)
		_greetings.erase(sender)


func reject_connection(id: int, reason: String) -> void:
	if closing_peers.has(id):
		return
	closing_peers[id] = true
	var rejecting_peer: ENetMultiplayerPeer = peer
	connection_rejected.rpc_id(id, reason)
	await get_tree().create_timer(0.2).timeout
	if peer != null and peer == rejecting_peer and hosting and id in multiplayer.get_peers():
		peer.disconnect_peer(id)


@rpc("authority", "call_remote", "reliable")
func connection_rejected(reason: String) -> void:
	fail(reason)


@rpc("authority", "call_remote", "reliable")
func welcome(states: Dictionary, ground_state: Dictionary, monster_states: Dictionary, host_clock: float) -> void:
	if hosting:
		return
	game._clock_offset = host_clock - game._now()
	game.client.actors.clear()
	for id: int in states:
		game.replication.apply_actor(states[id])
	game.client.ground_view = ground_state.duplicate(true)
	game.client.clear_monsters()
	for id: int in monster_states:
		game.client.put_monster(monster_states[id])
	game.client.self_id = multiplayer.get_unique_id()
	if not game.client.actors.has(game.client.self_id):
		fail("The host sent a snapshot without your player.")
		return
	connected = true
	_joining_since = -1.0
	remember_character(game.client.actors[game.client.self_id]["state"])
	status_message = "Connected to %s:%d" % [game._address.text, port]
	game.action_bar.fill_spell_slots(game.client.actors[game.client.self_id]["state"]["vocation"])
