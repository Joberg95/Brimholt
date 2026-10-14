extends PanelContainer
## The professions window (Keybinds "professions", P by default): every gathering and crafting
## skill with its level, progress to the next, what it gathers or crafts now, and what opens
## next. Gather with the gather key (F) or by right-clicking a rock, tree, herb patch, or water;
## craft at any town's artisan. Rewritten only when your skills change, and only while open.

const Crafting = preload("res://game/core/crafting.gd")
const Professions = preload("res://game/data/professions.gd")
const World = preload("res://game/core/world.gd")
const Layout = preload("res://game/ui/layout.gd")

const SIZE: Vector2 = Vector2(640, 520)
const TITLE: Color = Color("#ffcf6a")
const TEXT: Color = Color("#e8e4da")
const MUTED: Color = Color("#a7b0b8")

var game: Node
var _levels: Dictionary = {}
var _notes: Dictionary = {}
var _hint: Label
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
	var title: Label = _label("Professions", 18, TITLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "Close"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(hide)
	header.add_child(close)
	_hint = _label("", 12, MUTED)
	column.add_child(_hint)
	for group: Array in [["Gathering", Professions.GATHERING], ["Crafting", Professions.CRAFTING]]:
		column.add_child(_label(group[0], 15, TITLE))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 4)
		column.add_child(grid)
		for profession: String in group[1]:
			var named: Label = _label(Professions.NAMES[profession], 13, TEXT)
			named.autowrap_mode = TextServer.AUTOWRAP_OFF
			named.tooltip_text = Professions.DESCRIPTIONS[profession]
			named.mouse_filter = Control.MOUSE_FILTER_PASS
			grid.add_child(named)
			_levels[profession] = _label("", 13, TEXT)
			_levels[profession].autowrap_mode = TextServer.AUTOWRAP_OFF
			grid.add_child(_levels[profession])
			_notes[profession] = _label("", 12, MUTED)
			_notes[profession].custom_minimum_size = Vector2(430, 0)
			_notes[profession].size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(_notes[profession])
	visible = false


func toggle() -> void:
	visible = not visible


func refresh() -> void:
	if not visible:
		return
	var skills: Dictionary = game.actors[game.self_id]["state"].get("skills", {}) if game.actors.has(game.self_id) else {}
	var key: String = "%s|%s" % [skills, game.keybinds.label("gather")]
	if key == _key:
		return
	_key = key
	_hint.text = "Gather with %s or right-click a rock, tree, herb patch, or water; the land's monster levels decide what it yields. Craft at any town's artisan." % (
		game.keybinds.label("gather"))
	for profession: String in Professions.NAMES:
		var entry: Array = skills.get(profession, [1, 0])
		var level: int = int(entry[0])
		var next: int = Professions.experience_to_next(level)
		_levels[profession].text = "%d  (%d%%)" % [level, floori(100.0 * entry[1] / next)] if next > 0 else "%d  (max)" % level
		_notes[profession].text = gathering_note(profession, level) if profession in Professions.GATHERING \
			else crafting_note(profession, level)


## "Gathers Copper ore and Iron ore. Next: Silver ore at 20."
static func gathering_note(profession: String, level: int) -> String:
	var known: PackedStringArray = []
	var next: String = ""
	for band: int in Professions.BAND_LEVELS.size():
		var resource: String = World.ITEMS[Professions.RESOURCES[profession][band]]["name"]
		if level >= Professions.BAND_LEVELS[band]:
			known.append(resource)
		elif next.is_empty():
			next = " Next: %s at %d." % [resource, Professions.BAND_LEVELS[band]]
	return "Gathers %s.%s" % [" and ".join(known) if known.size() <= 2 else ", ".join(known), next]


## "Crafts 12 recipes. Next: new recipes at 25."
static func crafting_note(profession: String, level: int) -> String:
	var known: int = 0
	var next: int = 0
	for recipe: Dictionary in Crafting.RECIPES.values():
		if recipe["profession"] != profession:
			continue
		if recipe["skill"] <= level:
			known += 1
		elif next == 0 or recipe["skill"] < next:
			next = recipe["skill"]
	return "%s Crafts %d recipe%s.%s" % [Professions.DESCRIPTIONS[profession], known, "" if known == 1 else "s",
		"" if next == 0 else " Next: new recipes at %d." % next]


func _label(content: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
