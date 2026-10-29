extends Node2D
## The entry scene (/root/Main): builds the pieces and wires them together. The simulation (world,
## combat, economy, crafting, instances, bots) runs here on the host each frame; the network layer is
## game/net/ (Session, Gateway, and Replication as child nodes, so their RPCs have the same path on
## every peer); what this peer draws is game/client/client_state.gd; the UI components in game/ui/
## build and draw the panels. Main still holds the client API (the *_local requests), input, and the
## camera until plan 48 step 2e.

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
const Replication = preload("res://game/net/replication.gd")
const Session = preload("res://game/net/session.gd")
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
## How long a kill's green loot text stays over the body.
const LOOT_TEXT_SECONDS: float = 4.0
var solo: Solo
var last_action_message: String = ""
var _move_pending_since: float = -1.0
var _next_move_attempt: float = 0.0
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
# Shortcuts to component controls, used by input handling and the tests.
var _address: LineEdit
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


func _ready() -> void:
	keybinds.load_saved()
	# Menus and dialogs read small and minimal: every control without its own size uses this.
	ThemeDB.get_default_theme().default_font_size = UiTheme.FONT_SIZE
	_build_ui()
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
	if _move_pending_since >= 0.0 and now - _move_pending_since > 3.0:
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
	if session.connected and client.self_id != 0 and not typing() and not _controls.visible \
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
	_move_pending_since = -1.0
	_next_move_attempt = 0.0
	last_action_message = ""


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
	if slot < 0 or slot >= Keybinds.SLOTS or not session.connected:
		return
	if keybinds.bar[slot].begins_with("spell:"):
		cast_local(keybinds.bar[slot].trim_prefix("spell:"))
	elif keybinds.bar[slot].begins_with("item:"):
		rune_local(keybinds.bar[slot].trim_prefix("item:"))


## Casts a rune item from your backpack at your target (Combat.use_rune).
func rune_local(kind: String) -> void:
	if not session.connected or client.self_id == 0:
		return
	if session.hosting:
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
	elif not session.connected:
		return
	elif action == "pick_up":
		pick_up_local()
	elif action == "target_nearest":
		target_nearest()
	elif action in ["health_potion", "mana_potion"]:
		drink_kind(action)
	elif action == "gather":
		gather_nearby()


## Solo only: gathers a full raid around you, or sends it home (Solo.raid).
func raid_local(on: bool) -> void:
	if not session.solo_mode or not session.hosting:
		return
	var result: Dictionary = solo.raid(on, _now())
	if result["ok"]:
		replication.handle_events(result["events"])
	else:
		last_action_message = result["reason"]


## Solo only: gives a companion slot another class (Solo.set_companion).
func companion_local(slot: int, vocation: String) -> void:
	if not session.solo_mode or not session.hosting:
		return
	var result: Dictionary = solo.set_companion(slot, vocation, _now())
	replication.handle_events(result["events"])
	if not result["ok"]:
		last_action_message = result["reason"]


## Solo only: brings a companion slot's companion to your side, or sends it home (Solo.invite, Solo.dismiss).
func invite_local(slot: int, on: bool) -> void:
	if not session.solo_mode or not session.hosting:
		return
	var result: Dictionary = solo.invite(slot, _now()) if on else solo.dismiss(slot)
	replication.handle_events(result["events"])
	if not result["ok"]:
		last_action_message = result["reason"]


## Solo only: one more or one fewer of a class in the raid plan (Solo.set_raid_plan).
func raid_plan_local(vocation: String, delta: int) -> void:
	if not session.solo_mode or not session.hosting:
		return
	var result: Dictionary = solo.set_raid_plan(vocation, delta)
	if not result["ok"]:
		last_action_message = result["reason"]


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and close_ends_session:
		await session.leave_game()
		get_tree().quit()


func move_local(direction: Vector2i) -> void:
	if not session.connected or client.self_id == 0 or _move_pending_since >= 0.0:
		return
	_move_pending_since = _now()
	_next_move_attempt = _now() + World.MOVE_SECONDS
	if session.hosting:
		gateway.handle_move(1, direction)
	else:
		gateway.request_move.rpc_id(1, direction)


## Party actions: "invite", "revoke", "join" (with the inviting leader), or "leave" (other = 0).
func party_local(action: String, other: int) -> void:
	if not session.connected or client.self_id == 0:
		return
	if session.hosting:
		gateway.handle_party(1, action, other)
	else:
		gateway.request_party.rpc_id(1, action, other)


func equip_local(slot: String) -> void:
	if not session.connected or client.self_id == 0:
		return
	if session.hosting:
		gateway.handle_equipment(1, slot)
	else:
		gateway.request_equipment.rpc_id(1, slot)


func move_item_local(source: Dictionary, target: Dictionary) -> void:
	if not session.connected or client.self_id == 0:
		return
	if session.hosting:
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
	if not session.connected or client.self_id == 0:
		return
	if session.hosting:
		gateway.handle_travel(1, ferryman, destination)
	else:
		gateway.request_travel.rpc_id(1, ferryman, destination)


func quest_local(npc: String, relic: String) -> void:
	if not session.connected or client.self_id == 0:
		return
	if session.hosting:
		gateway.handle_quest(1, npc, relic)
	else:
		gateway.request_quest.rpc_id(1, npc, relic)


# ---------------------------------------------------------------- town services

func task_local(npc: String, task: String, action: String) -> void:
	if not session.connected or client.self_id == 0:
		return
	if session.hosting:
		gateway.handle_task(1, npc, task, action)
	else:
		gateway.request_task.rpc_id(1, npc, task, action)


## Whether this peer knows a gathering node is regrowing.
func node_worked(cell: Vector2i) -> bool:
	return worked_nodes.get(cell, -INF) > _now()


## Starts gathering at a node (the host checks reach, skill, and the node).
func gather_local(cell: Vector2i) -> void:
	if not session.connected or client.self_id == 0:
		return
	if session.hosting:
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
	if not session.connected or client.self_id == 0:
		return
	if session.hosting:
		gateway.handle_craft(1, npc, recipe, count)
	else:
		gateway.request_craft.rpc_id(1, npc, recipe, count)


## Asks your class trainer to raise a spell's rank for rune shards (the host checks everything).
func empower_local(npc: String, spell: String) -> void:
	if not session.connected or client.self_id == 0:
		return
	if session.hosting:
		gateway.handle_empower(1, npc, spell)
	else:
		gateway.request_empower.rpc_id(1, npc, spell)


## Asks a trainer to make you their vocation (permanent; the host checks the trial and level).
func vocation_local(npc: String) -> void:
	if not session.connected or client.self_id == 0:
		return
	if session.hosting:
		gateway.handle_vocation(1, npc)
	else:
		gateway.request_vocation.rpc_id(1, npc)


## Turns your PvP on or off at the warden (Combat.set_pvp checks reach, skull, fight, and cooldown).
func pvp_local(npc: String, on: bool) -> void:
	if not session.connected or client.self_id == 0:
		return
	if session.hosting:
		gateway.handle_pvp(1, npc, on)
	else:
		gateway.request_pvp.rpc_id(1, npc, on)


func buy_local(npc: String, kind: String, count: int) -> void:
	if not session.connected or client.self_id == 0:
		return
	if session.hosting:
		gateway.handle_buy(1, npc, kind, count)
	else:
		gateway.request_buy.rpc_id(1, npc, kind, count)


## Sells the backpack stack at `index`, or with -1 every monster material.
func sell_local(npc: String, index: int) -> void:
	if not session.connected or client.self_id == 0:
		return
	if session.hosting:
		gateway.handle_sell(1, npc, index)
	else:
		gateway.request_sell.rpc_id(1, npc, index)


func bank_local(npc: String, action: String, amount: int) -> void:
	if not session.connected or client.self_id == 0:
		return
	if session.hosting:
		gateway.handle_bank(1, npc, action, amount)
	else:
		gateway.request_bank.rpc_id(1, npc, action, amount)


func drink_local(index: int) -> void:
	if not session.connected or client.self_id == 0:
		return
	if session.hosting:
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
	if not session.connected or client.self_id == 0:
		return
	if session.hosting:
		gateway.handle_target(1, target)
	else:
		gateway.request_target.rpc_id(1, target)


func cast_local(spell: String) -> void:
	if not session.connected or client.self_id == 0:
		return
	if session.hosting:
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


## Map pixel the camera centres: your character's interpolated position, else the map centre.
func camera_focus() -> Vector2:
	if client.actors.has(client.self_id):
		return (client.actors[client.self_id]["visual"] + Vector2(0.5, 0.5)) * World.TILE_SIZE
	if session.dedicated:
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
		if event.button_index == MOUSE_BUTTON_RIGHT and session.connected:
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

