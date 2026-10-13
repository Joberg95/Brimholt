extends Node
## The micro menu right of the action bar: small drawn buttons that open the character window,
## spell book, quest list, world map, and Controls menu, the same as their keys. Each button's
## tooltip names it and its key, and an open panel's button is framed in gold.

const ItemSlot = preload("res://game/ui/item_slot.gd")
const Keybinds = preload("res://game/input/keybinds.gd")
const Layout = preload("res://game/ui/layout.gd")

const SIZE: float = 40.0
const GAP: float = 4.0
const ACCENT: Color = Color("#ffcf6a")
## [action, title, what it shows]; actions are Keybinds actions, except "controls" (no key).
const ENTRIES: Array = [
	["character", "Character", "Your stats explained, experience, party, skull, and town rest"],
	["spell_book", "Spell book", "Every spell of your vocation; drag one onto the action bar"],
	["quest_list", "Quests", "Show or hide the quest list"],
	["world_map", "World map", "Towns, ferries, dungeons, and PvP zones"],
	["controls", "Controls", "Rebind keys"],
]

var game: Node
var buttons: Array[Control] = []
## The key bindings the tooltips were written for.
var _keys: String = ""


func build(game_node: Node, layer: CanvasLayer) -> void:
	game = game_node
	var bar_end: float = Layout.VIEW_ORIGIN.x + (Layout.VIEW_SIZE.x + Keybinds.SLOTS * Layout.BAR_SLOT) / 2.0
	var top: float = Layout.VIEW_ORIGIN.y + Layout.VIEW_SIZE.y - Layout.BAR_SLOT - 6
	for index: int in ENTRIES.size():
		var entry: Array = ENTRIES[index]
		var button := ItemSlot.new()
		button.rarity_color = ACCENT
		button.position = Vector2(bar_end + 12 + index * (SIZE + GAP), top)
		button.size = Vector2.ONE * SIZE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.draw.connect(_draw_button.bind(button, entry[0]))
		button.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				game.toggle_panel(entry[0]))
		layer.add_child(button)
		buttons.append(button)


## Tooltips name the key, so they are rewritten when the bindings change.
func _update_tooltips() -> void:
	for index: int in ENTRIES.size():
		var entry: Array = ENTRIES[index]
		var key: String = ""
		if game.keybinds.keys.has(entry[0]):
			key = "  (%s)" % game.keybinds.label(entry[0])
		buttons[index].tooltip_text = "%s%s\n%s" % [entry[1], key, entry[2]]


func redraw() -> void:
	var keys: String = str(game.keybinds.keys)
	if keys != _keys:
		_keys = keys
		_update_tooltips()
	for button: Control in buttons:
		button.queue_redraw()


func _draw_button(button: Control, action: String) -> void:
	var area := Rect2(Vector2.ZERO, button.size)
	var open: bool = game.panel_open(action)
	button.draw_rect(area, Color(0.08, 0.1, 0.12, 0.85))
	button.draw_rect(area, ACCENT if open else Color("#4a5560"), false, 2.0 if open else 1.0)
	match action:
		"character":
			button.draw_circle(Vector2(20, 14), 5.5, Color("#d8b48a"))
			button.draw_colored_polygon(PackedVector2Array([Vector2(10, 33), Vector2(30, 33), Vector2(27, 22), Vector2(13, 22)]),
				Color("#4f7f86"))
			button.draw_rect(Rect2(18, 22, 4, 4), Color("#c9a24a"))
		"spell_book":
			button.draw_rect(Rect2(11, 9, 18, 23), Color("#7a3a3a"))
			button.draw_rect(Rect2(11, 9, 4, 23), Color("#4f2424"))
			button.draw_rect(Rect2(27, 11, 2, 19), Color("#efe6cf"))
			button.draw_circle(Vector2(21, 20), 4.0, Color("#ffcf6a"))
		"quest_list":
			button.draw_rect(Rect2(12, 11, 16, 20), Color("#e6d6a8"))
			button.draw_rect(Rect2(10, 8, 20, 4), Color("#c8b07a"))
			button.draw_rect(Rect2(10, 30, 20, 4), Color("#c8b07a"))
			for y: int in [15, 19, 23, 27]:
				button.draw_rect(Rect2(14, y, 12 if y != 27 else 7, 1), Color("#6a5a3a"))
		"world_map":
			var folds: Array[Color] = [Color("#6a8a4a"), Color("#4a6a8a"), Color("#6a8a4a")]
			for fold: int in 3:
				var x: float = 8 + fold * 8
				var lift: float = 2.0 if fold % 2 == 0 else -2.0
				button.draw_colored_polygon(PackedVector2Array([Vector2(x, 12 + lift), Vector2(x + 8, 12 - lift),
					Vector2(x + 8, 30 - lift), Vector2(x, 30 + lift)]), folds[fold])
			button.draw_line(Vector2(17, 18), Vector2(23, 24), Color("#e05a4a"), 2.0)
			button.draw_line(Vector2(23, 18), Vector2(17, 24), Color("#e05a4a"), 2.0)
		"controls":
			button.draw_rect(Rect2(7, 14, 26, 14), Color("#5a6470"))
			for row: int in 2:
				for column: int in 4:
					button.draw_rect(Rect2(9 + column * 6, 16 + row * 5, 4, 3), Color("#c8ccd0"))
			button.draw_rect(Rect2(13, 26, 14, 1), Color("#c8ccd0"))
