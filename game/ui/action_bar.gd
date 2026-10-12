extends Node
## The nine-slot spell bar under the game window: click or press a slot's key to cast,
## right-click to choose one of your vocation's spells, with level and cooldown shading.

const Keybinds = preload("res://game/input/keybinds.gd")
const Spells = preload("res://game/data/spells.gd")
const Layout = preload("res://game/ui/layout.gd")

var game: Node
var keybinds: Keybinds
var _slots: Array[Control] = []
var _menu: PopupMenu
var _menu_slot: int = -1


func build(game_node: Node, layer: CanvasLayer) -> void:
	game = game_node
	keybinds = game.keybinds
	var start: Vector2 = Layout.VIEW_ORIGIN + Vector2((Layout.VIEW_SIZE.x - Keybinds.SLOTS * Layout.BAR_SLOT) / 2.0,
		Layout.VIEW_SIZE.y - Layout.BAR_SLOT - 6)
	for slot: int in Keybinds.SLOTS:
		var button := Control.new()
		button.position = start + Vector2(slot * Layout.BAR_SLOT, 0)
		button.size = Vector2.ONE * (Layout.BAR_SLOT - 4)
		button.draw.connect(_draw_slot.bind(button, slot))
		button.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_LEFT:
					game.use_bar_slot(slot)
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					_open_menu(slot, Vector2i(button.global_position + event.position)))
		layer.add_child(button)
		_slots.append(button)
	_menu = PopupMenu.new()
	_menu.id_pressed.connect(func(index: int) -> void:
		var entry: String = _menu.get_item_metadata(_menu.get_item_index(index))
		if keybinds.set_bar(_menu_slot, entry):
			keybinds.save())
	add_child(_menu)


func redraw() -> void:
	for slot: Control in _slots:
		slot.queue_redraw()


## Replaces spells of other vocations and fills empty bar slots with this vocation's spells.
func fill_spell_slots(vocation: String) -> void:
	var own: Array[String] = Spells.for_vocation(vocation)
	for slot: int in Keybinds.SLOTS:
		var entry: String = keybinds.bar[slot]
		if entry.begins_with("spell:") and entry.trim_prefix("spell:") not in own:
			keybinds.bar[slot] = ""
	for spell: String in own:
		if "spell:" + spell in keybinds.bar:
			continue
		for slot: int in Keybinds.SLOTS:
			if keybinds.bar[slot].is_empty():
				keybinds.bar[slot] = "spell:" + spell
				break


## Lists the spells of your vocation, with their level, and an option to clear the slot.
func _open_menu(slot: int, at: Vector2i) -> void:
	var actors: Dictionary = game.actors
	var self_id: int = game.self_id
	_menu_slot = slot
	_menu.clear()
	var entries: Array[String] = []
	if actors.has(self_id):
		_menu.add_separator("Spells")
		var level: int = actors[self_id]["state"].get("level", 1)
		for spell: String in Spells.for_vocation(actors[self_id]["state"]["vocation"]):
			var definition: Dictionary = Spells.SPELLS[spell]
			entries.append("spell:" + spell)
			_menu.add_item("%s%s" % [definition["name"], "" if level >= definition["level"]
				else "  (level %d)" % definition["level"]], entries.size() - 1)
			_menu.set_item_metadata(_menu.get_item_index(entries.size() - 1), "spell:" + spell)
		_menu.add_separator()
	entries.append("")
	_menu.add_item("Clear slot", entries.size() - 1)
	_menu.set_item_metadata(_menu.get_item_index(entries.size() - 1), "")
	_menu.popup(Rect2i(at, Vector2i.ZERO))


func _draw_slot(button: Control, slot: int) -> void:
	var area := Rect2(Vector2.ZERO, button.size)
	button.draw_rect(area, Color(0.08, 0.1, 0.12, 0.85))
	button.draw_rect(area, Color("#4a5560"), false, 1.0)
	var entry: String = keybinds.bar[slot]
	var font: Font = ThemeDB.fallback_font
	if entry.begins_with("spell:") and Spells.SPELLS.has(entry.trim_prefix("spell:")):
		_draw_spell_slot(button, entry.trim_prefix("spell:"))
	var key: String = Keybinds.key_name(keybinds.keys["slot_%d" % (slot + 1)][0])
	button.draw_string_outline(font, Vector2(3, 11), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color.BLACK)
	button.draw_string(font, Vector2(3, 11), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#f2e6c4"))


## A spell slot: coloured rune with initials, dimmed when unusable, with a cooldown shade.
func _draw_spell_slot(button: Control, spell: String) -> void:
	var actors: Dictionary = game.actors
	var self_id: int = game.self_id
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
	var now: float = game._now()
	var elapsed: float = now - actors[self_id].get("received", now)
	var left: float = maxf(state.get("cooldowns", {}).get(spell, 0.0), state.get("groups", {}).get(definition["group"], 0.0)) - elapsed
	if left > 0.0:
		var share: float = clampf(left / maxf(definition["cooldown"], Spells.GROUP_SECONDS[definition["group"]]), 0.0, 1.0)
		button.draw_rect(Rect2(Vector2(0, button.size.y * (1.0 - share)), Vector2(button.size.x, button.size.y * share)),
			Color(0, 0, 0, 0.6))
