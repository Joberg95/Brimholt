extends Node
## Keyboard and mouse on the game window (plan 48), /root/Main/InputController: walking (held keys,
## or chasing a locked target), the action keys and action-bar slots, Escape, the micro menu's
## panel toggles, and clicks, drags, and drops on the map. Requests go through game.api.

const World = preload("res://game/core/world.gd")
const WorldMap = preload("res://game/world_map/world_map.gd")
const Keybinds = preload("res://game/input/keybinds.gd")
const Crafting = preload("res://game/core/crafting.gd")
const Layout = preload("res://game/ui/layout.gd")

## The main node (game/main.gd).
var game: Node


## Takes one step this frame if a move key is held (or the locked target is out of reach) and the
## last step has been answered.
func walk(now: float) -> void:
	if game.session.connected and game.client.self_id != 0 and not typing() and not game._controls.visible \
			and game.api.can_step(now):
		var direction: Vector2i = _input_direction()
		if direction == Vector2i.ZERO:
			direction = game.client.chase_direction()
		if direction != Vector2i.ZERO:
			game.api.move_local(direction)


func _input_direction() -> Vector2i:
	for pair: Array in [["move_up", Vector2i.UP], ["move_down", Vector2i.DOWN],
			["move_left", Vector2i.LEFT], ["move_right", Vector2i.RIGHT]]:
		if game.keybinds.is_held(pair[0]):
			return pair[1]
	return Vector2i.ZERO


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo() or (typing() and not _escape(event)):
		return
	if _escape(event):
		_close_everything()
		return
	var key: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	var action: String = game.keybinds.action_for(key)
	if action.begins_with("slot_"):
		use_bar_slot(int(action.trim_prefix("slot_")) - 1)
	elif not action.is_empty():
		run_action(action)


## Escape: drops your target when nothing is open, and closes every window.
func _close_everything() -> void:
	if not game._world_map.visible and not game._travel_panel.visible and not game._controls.visible and not game.spell_book.visible \
			and not game.character_window.visible and not game.professions_window.visible and not game.party_window.visible \
			and not game.lexicon.visible and game.client.own_target() != 0:
		game.api.target_local(0)
	game._world_map.hide()
	game._close_travel()
	game._controls.hide()
	game.game_menu.hide()
	game.spell_book.hide()
	game.character_window.hide()
	game.professions_window.hide()
	game.party_window.hide()
	for window: PanelContainer in game.inventory.bag_windows:
		window.hide()
	game.lexicon.hide()


## Whether a text field (the address, the lexicon search) has the keyboard: game keys wait.
func typing() -> bool:
	return get_viewport().gui_get_focus_owner() is LineEdit


static func _escape(event: InputEventKey) -> bool:
	return event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE


## Opens or closes a panel from the micro menu: a Keybinds action, or "controls".
func toggle_panel(action: String) -> void:
	if action == "controls":
		var open: bool = game.game_menu.visible or game._controls.visible
		game._controls.hide()
		game.game_menu.visible = not open
	else:
		run_action(action)


## Whether the micro menu should show a panel's button as open.
func panel_open(action: String) -> bool:
	match action:
		"character":
			return game.character_window.visible
		"professions":
			return game.professions_window.visible
		"party":
			return game.party_window.visible
		"lexicon":
			return game.lexicon.visible
		"spell_book":
			return game.spell_book.visible
		"quest_list":
			return game.quest_list.shown
		"world_map":
			return game._world_map.visible
		"controls":
			return game.game_menu.visible or game._controls.visible
	return false


## Casts the spell (or the rune) in an action-bar slot (0-8).
func use_bar_slot(slot: int) -> void:
	if slot < 0 or slot >= Keybinds.SLOTS or not game.session.connected:
		return
	var entry: String = game.keybinds.bar[slot]
	if entry.begins_with("spell:"):
		game.api.cast_local(entry.trim_prefix("spell:"))
	elif entry.begins_with("item:"):
		game.api.rune_local(entry.trim_prefix("item:"))


## A Keybinds action: a window toggle, or (while playing) picking up, targeting, a potion, gathering.
func run_action(action: String) -> void:
	if action == "world_map":
		game._world_map.visible = not game._world_map.visible
	elif action == "quest_list":
		game.quest_list.shown = not game.quest_list.shown
	elif action == "spell_book":
		game.spell_book.toggle()
	elif action == "character":
		game.character_window.toggle()
	elif action == "professions":
		game.professions_window.toggle()
	elif action == "party":
		game.party_window.toggle()
	elif action == "lexicon":
		game.lexicon.toggle()
	elif not game.session.connected:
		return
	elif action == "pick_up":
		game.api.pick_up_local()
	elif action == "target_nearest":
		game.api.target_nearest()
	elif action in ["health_potion", "mana_potion"]:
		game.api.drink_kind(action)
	elif action == "gather":
		game.api.gather_nearby()


# ---------------------------------------------------------------- the map (the game window's input)

func map_drag(at: Vector2) -> Variant:
	return game.inventory.item_drag(at, game._view, game.camera.map_location(at))


func map_can_drop(at: Vector2, data: Variant) -> bool:
	return game.inventory.item_can_drop(at, data, game.camera.map_location(at))


func map_drop(at: Vector2, data: Variant) -> void:
	game.inventory.item_drop(at, data, game.camera.map_location(at))


## A click on the map: right on an NPC opens its menu, on a player their menu, on a node gathers
## it; left on a creature targets it (or drops the target); otherwise the inventory's slot input.
func map_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	get_viewport().gui_release_focus()
	var cell: Vector2i = game.camera.map_location(event.position)["cell"]
	var npc: String = WorldMap.NPC_CELLS.get(cell, WorldMap.NPC_CELLS.get(cell + Vector2i.DOWN, ""))
	if event.button_index == MOUSE_BUTTON_RIGHT and not npc.is_empty():
		game.dialogs.open_npc_menu(npc, Vector2i(Layout.VIEW_ORIGIN + event.position))
		return
	var creature: int = game.client.creature_at(cell)
	if event.button_index == MOUSE_BUTTON_RIGHT and game.session.connected:
		# Creatures never block a tile, so loot under someone is picked up rather than opening their menu.
		var person: int = creature if creature > 0 and not game.client.ground_view.has(cell) else 0
		if person > 0 and game.dialogs.open_player_menu(person, Vector2i(Layout.VIEW_ORIGIN + event.position)):
			return
		if person == 0 and not Crafting.node_at(cell).is_empty() and not game.client.ground_view.has(cell):
			game.api.gather_local(cell)
			return
	if event.button_index == MOUSE_BUTTON_LEFT and creature != 0:
		game.api.target_local(0 if creature == game.client.own_target() else creature)
		return
	game.inventory.slot_input(event, game.camera.map_location(event.position))
