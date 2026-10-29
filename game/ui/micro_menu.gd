extends Node
## The micro menu right of the action bar: small painted buttons that open the character window,
## spell book, professions, quest list, lexicon, world map, party, and the game menu (the cogwheel), the same as their keys. Each button's
## tooltip names it and its key, and an open panel's button is framed in gold.

const ItemSlot = preload("res://game/ui/item_slot.gd")
const Keybinds = preload("res://game/input/keybinds.gd")
const Layout = preload("res://game/ui/layout.gd")

const SIZE: float = 26.0
const GAP: float = 2.0
## Painted 32-pixel icons (tools/generators/make_sprites.py MENU_ICONS), one per entry in ICON_ORDER.
const ICONS: Texture2D = preload("res://assets/sprites/menu_icons.png")
const ICON: float = 26.0
## The icons' size in menu_icons.png.
const ICON_ART: float = 32.0
const ICON_ORDER: Array[String] = ["character", "spell_book", "professions", "quest_list", "lexicon", "world_map", "party",
	"controls"]
const ACCENT: Color = Color("#ffcf6a")
## [action, title, what it shows]; actions are Keybinds actions, except "controls" (no key).
const ENTRIES: Array = [
	["character", "Character", "Your stats explained, experience, party, skull, and town rest"],
	["spell_book", "Spell book", "Every spell of your class; drag one onto the action bar"],
	["professions", "Professions", "Gathering and crafting skills: what you can gather and craft now"],
	["quest_list", "Quests", "Show or hide the quest list"],
	["lexicon", "Lexicon", "Every monster: where it lives, its levels, and what it drops"],
	["world_map", "World map", "Towns, ferries, dungeons, and PvP zones"],
	["party", "Party", "Your party's members and health, invitations, and (solo) the raid"],
	["controls", "Game menu", "Players on the host, settings, controls, and leaving the game"],
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
		button.position = Vector2(bar_end + 6 + index * (SIZE + GAP), top)
		button.size = Vector2.ONE * SIZE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.mouse_entered.connect(button.queue_redraw)
		button.mouse_exited.connect(button.queue_redraw)
		button.draw.connect(_draw_button.bind(button, entry[0]))
		button.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				game.input_controller.toggle_panel(entry[0]))
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
	var open: bool = game.input_controller.panel_open(action)
	var hovered: bool = button.get_global_rect().has_point(button.get_global_mouse_position())
	button.draw_rect(area, Color("#1a1612", 0.92))
	button.draw_rect(area.grow(-2), Color("#2a231c") if not open else Color("#3a2e1e"))
	button.draw_rect(Rect2(2, 2, area.size.x - 4, 1), Color(1, 1, 1, 0.08))
	var frame: Color = ACCENT if open else (Color("#b89a5a") if hovered else Color("#6a5638"))
	button.draw_rect(area, frame, false, 2.0 if open else 1.0)
	var index: int = ICON_ORDER.find(action)
	if index >= 0:
		var inset: float = (SIZE - ICON) / 2.0
		button.draw_texture_rect_region(ICONS, Rect2(inset, inset, ICON, ICON),
			Rect2(index * ICON_ART, 0, ICON_ART, ICON_ART), Color.WHITE if open or hovered else Color(0.88, 0.88, 0.88))
