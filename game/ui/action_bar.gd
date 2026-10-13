extends Node
## The nine-slot spell bar under the game window: click or press a slot's key to cast,
## right-click to choose one of your vocation's spells, or drag one in from the spell book
## (or from another slot), with level and cooldown shading. Hovering a slot explains its spell.

const Keybinds = preload("res://game/input/keybinds.gd")
const Spells = preload("res://game/data/spells.gd")
const Layout = preload("res://game/ui/layout.gd")
const SpellRune = preload("res://game/ui/spell_rune.gd")
const World = preload("res://game/core/world.gd")

## The right-click menu entry that opens the spell book instead of filling the slot.
const BOOK_ENTRY: String = "book"

var game: Node
var keybinds: Keybinds
var _slots: Array[Control] = []
var _menu: PopupMenu
var _menu_slot: int = -1
## What the tooltips were last written for (bar entries, level, vocation, and gear).
var _tooltip_key: String = ""
## The vocation the bar was last filled for.
var _vocation: String = ""


func build(game_node: Node, layer: CanvasLayer) -> void:
	game = game_node
	keybinds = game.keybinds
	var start: Vector2 = Layout.VIEW_ORIGIN + Vector2((Layout.VIEW_SIZE.x - Keybinds.SLOTS * Layout.BAR_SLOT) / 2.0,
		Layout.VIEW_SIZE.y - Layout.BAR_SLOT - 6)
	for slot: int in Keybinds.SLOTS:
		var button := SpellRune.new()
		button.bar_slot = slot
		button.on_drop = _dropped.bind(slot)
		button.position = start + Vector2(slot * Layout.BAR_SLOT, 0)
		button.size = Vector2.ONE * (Layout.BAR_SLOT - 4)
		button.draw.connect(_draw_slot.bind(button, slot))
		# Casting on release lets a press start a drag to another slot instead.
		button.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton:
				if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
					game.use_bar_slot(slot)
				elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
					_open_menu(slot, Vector2i(button.global_position + event.position)))
		layer.add_child(button)
		_slots.append(button)
	_menu = PopupMenu.new()
	_menu.id_pressed.connect(func(index: int) -> void:
		var entry: String = _menu.get_item_metadata(_menu.get_item_index(index))
		if entry == BOOK_ENTRY:
			game.spell_book.show()
		elif keybinds.set_bar(_menu_slot, entry):
			keybinds.save())
	add_child(_menu)


func redraw() -> void:
	for slot: Control in _slots:
		slot.queue_redraw()
	var state: Dictionary = game.actors[game.self_id]["state"] if game.actors.has(game.self_id) else {}
	var key: String = "%s|%s|%s|%s" % [keybinds.bar, state.get("level", 0), state.get("vocation", ""), state.get("equipment", {})]
	if key == _tooltip_key:
		return
	_tooltip_key = key
	# Choosing a vocation at a trainer brings its spells onto the bar.
	if state.get("vocation", "") != _vocation and not state.is_empty():
		_vocation = state["vocation"]
		fill_spell_slots(_vocation)
	for slot: int in _slots.size():
		var rune: SpellRune = _slots[slot]
		var entry: String = keybinds.bar[slot]
		rune.spell = entry.trim_prefix("spell:") if Spells.SPELLS.has(entry.trim_prefix("spell:")) else ""
		rune.tooltip_text = "" if rune.spell.is_empty() else spell_tooltip(rune.spell, state)


## A spell's tooltip with numbers for your current level and gear (none before you join).
static func spell_tooltip(spell: String, state: Dictionary) -> String:
	if state.is_empty():
		return Spells.describe(spell, {}, 0)
	var level: int = state.get("level", 1)
	return Spells.describe(spell, World.stats(level, state.get("equipment", {}), state.get("vocation", "knight")), level)


## A rune dropped on a bar slot: a spell-book drag fills it; a drag from another slot swaps them.
func _dropped(spell: String, from_slot: int, slot: int) -> void:
	var previous: String = keybinds.bar[slot]
	if keybinds.set_bar(slot, "spell:" + spell):
		if from_slot >= 0 and from_slot != slot:
			keybinds.set_bar(from_slot, previous)
		keybinds.save()


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
	entries.append(BOOK_ENTRY)
	_menu.add_item("Open spell book (%s)" % Keybinds.key_name(keybinds.keys["spell_book"][0]), entries.size() - 1)
	_menu.set_item_metadata(_menu.get_item_index(entries.size() - 1), BOOK_ENTRY)
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
	SpellRune.draw_rune(button, spell, center + Vector2(0, 2), usable)
	if state.is_empty():
		return
	var now: float = game._now()
	var elapsed: float = now - actors[self_id].get("received", now)
	var left: float = maxf(state.get("cooldowns", {}).get(spell, 0.0), state.get("groups", {}).get(definition["group"], 0.0)) - elapsed
	if left > 0.0:
		var share: float = clampf(left / maxf(definition["cooldown"], Spells.GROUP_SECONDS[definition["group"]]), 0.0, 1.0)
		button.draw_rect(Rect2(Vector2(0, button.size.y * (1.0 - share)), Vector2(button.size.x, button.size.y * share)),
			Color(0, 0, 0, 0.6))
