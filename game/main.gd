extends Node2D
## The entry scene (/root/Main): builds the pieces and wires them together. The simulation (world,
## combat, economy, crafting, instances, bots) runs here on the host each frame. The network layer is
## game/net/ (Session, Gateway, and Replication, child nodes so their RPCs have the same path on every
## peer); this peer's side is game/client/ (the replicated view, the requests it sends, input, camera,
## and effects); the UI components in game/ui/ build and draw the panels.

const World = preload("res://game/core/world.gd")
const Keybinds = preload("res://game/input/keybinds.gd")
const Combat = preload("res://game/core/combat.gd")
const Economy = preload("res://game/core/systems/economy.gd")
const Crafting = preload("res://game/core/crafting.gd")
const Instances = preload("res://game/core/instances.gd")
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
const Replication = preload("res://game/net/replication.gd")
const Session = preload("res://game/net/session.gd")
const ClientApi = preload("res://game/client/client_api.gd")
const InputController = preload("res://game/client/input_controller.gd")
const Camera = preload("res://game/client/camera.gd")
const EffectView = preload("res://game/client/effect_view.gd")
const UiRoot = preload("res://game/ui/ui_root.gd")
## Tibia-style game window: 15x11 tiles at 2x, centred on your character.
const ZOOM: float = Layout.ZOOM
const VIEW_TILES: Vector2i = Layout.VIEW_TILES
const VIEW_ORIGIN: Vector2 = Layout.VIEW_ORIGIN
const VIEW_SIZE: Vector2 = Layout.VIEW_SIZE
const PANEL_ORIGIN: Vector2 = Layout.PANEL_ORIGIN

var world := World.new()
var combat := Combat.new(world)
var economy := Economy.new(world)
var crafting := Crafting.new(world)
## Gathering nodes this peer knows are regrowing: cell -> local _now() when they regrow.
var worked_nodes: Dictionary = {}
var instances := Instances.new(world, combat)
## Opt-in frame profile (tools/testing/bench.gd): section -> [microseconds, frames, worst]. Off in play.
var profiling: bool = false
var frame_profile: Dictionary = {}
## What this peer draws: the players, monsters, ground, and effects the host sent (game/client/).
var client := ClientState.new()
## Every request a player sends the host (game/net/gateway.gd), at /root/Main/Gateway on every peer.
var gateway: Gateway
## Host updates to every peer and their application here (game/net/replication.gd), at /root/Main/Replication.
var replication: Replication
## Hosting, joining, the handshake, saves, and bots (game/net/session.gd), at /root/Main/Session.
var session: Session
## This peer's requests to the host (game/client/client_api.gd), as game.api.<name>_local(...).
var api := ClientApi.new(self)
## Keys and clicks (game/client/input_controller.gd), at /root/Main/InputController.
var input_controller: InputController
var camera := Camera.new(self)
## How combat events look on this peer (game/client/effect_view.gd).
var effect_view := EffectView.new(self)
var solo: Solo
var last_action_message: String = ""
@warning_ignore("unused_private_class_variable")
var _view: GameWindow
var _world_view: Node2D
## Clients add this to their clock to follow the host's time of day.
var _clock_offset: float = 0.0
var keybinds := Keybinds.new()
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
# Shortcuts to component controls (set by game/ui/ui_root.gd), used by input handling and the tests.
@warning_ignore("unused_private_class_variable")
var _address: LineEdit
@warning_ignore("unused_private_class_variable")
var _controls: PanelContainer
@warning_ignore("unused_private_class_variable")
var _zone_label: Label
@warning_ignore("unused_private_class_variable")
var _minimap: Control
@warning_ignore("unused_private_class_variable")
var _world_map: Control
@warning_ignore("unused_private_class_variable")
var _travel_panel: PanelContainer
@warning_ignore("unused_private_class_variable")
var _travel_list: VBoxContainer
@warning_ignore("unused_private_class_variable")
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


## The network layer exists from the start, so tests and tools can set session options before the
## scene enters the tree.
func _init() -> void:
	gateway = Gateway.new()
	gateway.name = "Gateway"
	gateway.game = self
	add_child(gateway)
	replication = Replication.new()
	replication.name = "Replication"
	replication.game = self
	add_child(replication)
	session = Session.new()
	session.name = "Session"
	session.game = self
	add_child(session)
	input_controller = InputController.new()
	input_controller.name = "InputController"
	input_controller.game = self
	add_child(input_controller)


func _ready() -> void:
	keybinds.load_saved()
	# Menus and dialogs read small and minimal: every control without its own size uses this.
	ThemeDB.get_default_theme().default_font_size = UiTheme.FONT_SIZE
	UiRoot.build(self)
	get_tree().auto_accept_quit = false
	if not session.configure(OS.get_cmdline_user_args()):
		get_tree().quit(1)


## Test-only: seconds added to the clock, so soak tests can jump ahead (respawns, ground decay).
var clock_skew: float = 0.0


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0 + clock_skew


## The host's clock, for the day and night cycle on every peer.
func world_clock() -> float:
	return _now() + _clock_offset


func _process(delta: float) -> void:
	var now: float = _now()
	session.tick(now)
	if api.move_timed_out(now):
		session.fail("The host stopped answering movement requests.")
	var mark: int = Time.get_ticks_usec()
	if session.running():
		replication.handle_events(combat.tick(now))
		mark = _profiled("combat", mark)
		replication.handle_events(bots.tick(now))
		mark = _profiled("bots", mark)
		if session.solo_mode:
			replication.handle_events(solo.tick(now))
		replication.handle_events(instances.tick(now))
		replication.handle_events(crafting.tick(now))
		replication.handle_events(world.decay_ground(now))
		mark = _profiled("other ticks", mark)
		replication.tick(now)
		mark = _profiled("interest", mark)
		session.autosave(now)
	client.advance(delta, Time.get_ticks_msec() / 1000.0)
	input_controller.walk(now)
	mark = _profiled("actors and input", mark)
	_update_labels()
	UiRoot.refresh_inventory(self)
	camera.follow(_world_view)
	_world_view.queue_redraw()
	mark = _profiled("labels and inventory", mark)
	UiRoot.refresh_windows(self)
	_profiled("windows and maps", mark)


## A fresh simulation and view, for a new session: the world, its rules, bots, and what this peer drew.
func reset_world() -> void:
	world = World.new()
	combat = Combat.new(world)
	economy = Economy.new(world)
	crafting = Crafting.new(world)
	worked_nodes.clear()
	instances = Instances.new(world, combat)
	bots = Bots.new(world, combat)
	bots.instances = instances
	bots.difficulty = session.bot_difficulty
	solo = Solo.new(world, combat, bots)
	replication.reset()
	gateway.reset()
	client.clear()
	if _travel_panel != null:
		_close_travel()
		_world_map.hide()
	api.reset()
	last_action_message = ""


## Adds the time since `since` to a profile section (when profiling); returns now.
func _profiled(section: String, since: int) -> int:
	var now: int = Time.get_ticks_usec()
	if profiling:
		var entry: Array = frame_profile.get(section, [0, 0, 0])
		frame_profile[section] = [entry[0] + now - since, entry[1] + 1, maxi(entry[2], now - since)]
	return now


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and close_ends_session:
		await session.leave_game()
		get_tree().quit()

func _update_labels() -> void:
	UiRoot.update_labels(self)


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

