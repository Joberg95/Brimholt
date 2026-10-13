extends PanelContainer
## The spell book (Keybinds "spell_book", B by default): every spell of your vocation by unlock
## level, with what it does and its numbers for your current level and gear (Spells.info).
## Drag a rune onto the action bar to put the spell there. Before you join it shows the
## vocation chosen in the menu. Rebuilt only while open and when your level, vocation, or gear
## change.

const World = preload("res://game/core/world.gd")
const Balance = preload("res://game/data/balance.gd")
const Spells = preload("res://game/data/spells.gd")
const Layout = preload("res://game/ui/layout.gd")
const SpellRune = preload("res://game/ui/spell_rune.gd")
const Keybinds = preload("res://game/input/keybinds.gd")

const SIZE: Vector2 = Vector2(560, 600)
const TITLE: Color = Color("#ffcf6a")
const TEXT: Color = Color("#e8e4da")
const MUTED: Color = Color("#a7b0b8")
const LOCKED: Color = Color("#e05a4a")

var game: Node
var _title: Label
var _hint: Label
var _list: VBoxContainer
var _key: String = "-"


func _init() -> void:
	position = Layout.VIEW_ORIGIN + (Layout.VIEW_SIZE - SIZE) / 2.0
	size = SIZE
	custom_minimum_size = SIZE
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.05, 0.06, 0.08, 0.95)
	frame.border_color = Color("#6a5a3a")
	frame.set_border_width_all(2)
	frame.set_content_margin_all(12)
	frame.anti_aliasing = false
	add_theme_stylebox_override("panel", frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_title = _label("", 18, TITLE)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close := Button.new()
	close.text = "Close"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(hide)
	header.add_child(close)
	_hint = _label("", 12, MUTED)
	column.add_child(_hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	visible = false


func toggle() -> void:
	visible = not visible


## Per frame: rebuild while open when what the book shows has changed.
func refresh() -> void:
	if not visible:
		return
	var state: Dictionary = game.actors[game.self_id]["state"] if game.actors.has(game.self_id) else {}
	var vocation: String = state.get("vocation", game.selected_vocation())
	var level: int = state.get("level", 1)
	var equipment: Dictionary = state.get("equipment", {})
	var key: String = "%s|%d|%s|%s" % [vocation, level, equipment, game.keybinds.keys["spell_book"]]
	if key == _key:
		return
	_key = key
	_title.text = "Spell book — %s, level %d" % [Balance.profile_of(vocation)["name"], level]
	_hint.text = "Drag a rune onto the action bar to use it. %s closes the book." % \
		Keybinds.key_name(game.keybinds.keys["spell_book"][0])
	for child: Node in _list.get_children():
		child.queue_free()
	var stats: Dictionary = World.stats(level, equipment, vocation)
	for spell: String in Spells.for_vocation(vocation):
		_list.add_child(_row(spell, Spells.info(spell, stats, level)))


func _row(spell: String, details: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var rune := SpellRune.new()
	rune.spell = spell
	rune.usable = details["unlocked"]
	rune.custom_minimum_size = Vector2(40, 40)
	rune.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	rune.tooltip_text = "%s\nDrag onto the action bar" % details["name"]
	rune.draw.connect(func() -> void: SpellRune.draw_rune(rune, spell, Vector2(20, 20), rune.usable, 36.0))
	rune.mouse_default_cursor_shape = Control.CURSOR_DRAG
	row.add_child(rune)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	var color: Color = Spells.SPELLS[spell]["color"]
	text.add_child(_label(details["name"], 15, color if details["unlocked"] else color.darkened(0.4)))
	text.add_child(_label(details["requirement"], 12, MUTED if details["unlocked"] else LOCKED))
	text.add_child(_label(details["rune"], 11, Color(Spells.SPELLS[spell]["color"]).lerp(MUTED, 0.5)))
	text.add_child(_label(details["effect"], 13, TEXT))
	var numbers: PackedStringArray = []
	for part: String in ["amount", "cost", "cooldown"]:
		if not details[part].is_empty():
			numbers.append(details[part])
	text.add_child(_label(" · ".join(numbers), 12, MUTED))
	return row


func _label(content: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
