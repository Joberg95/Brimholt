extends PanelContainer
## The Controls menu: click a key button, then press the new key. Backspace or Delete clears
## the binding and Escape cancels. A key already used elsewhere moves to the new action.
## Changes are saved immediately. The actions sit in two side-by-side columns, and the list
## scrolls if it would be taller than `max_height`.

const Keybinds = preload("res://game/input/keybinds.gd")
const UiTheme = preload("res://game/ui/ui_theme.gd")

const FONT_SIZE: int = 13
const ROW_HEIGHT: int = 24
const ROW_GAP: int = 2
const LABEL_WIDTH: int = 104
const KEY_WIDTH: int = 78

var keybinds: Keybinds
var waiting: Array = []
var _buttons: Dictionary = {}
var _columns: Control
var _scroll: ScrollContainer
var _max_height: float = 0.0


func setup(binds: Keybinds, close: Callable, max_height: float = 480.0) -> void:
	keybinds = binds
	add_theme_stylebox_override("panel", UiTheme.panel())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var title := Label.new()
	title.text = "Controls: click a key, then press the new one. Backspace clears, Esc cancels."
	title.add_theme_font_size_override("font_size", FONT_SIZE)
	box.add_child(title)
	var actions: Array = Keybinds.DEFAULTS.keys()
	var rows: int = ceili(actions.size() / 2.0)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	for half: int in 2:
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("v_separation", ROW_GAP)
		grid.add_theme_constant_override("h_separation", 4)
		columns.add_child(grid)
		for action: String in actions.slice(half * rows, (half + 1) * rows):
			_add_row(grid, action)
	_max_height = max_height
	_columns = columns
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.add_child(columns)
	box.add_child(_scroll)
	columns.minimum_size_changed.connect(fit)
	fit()
	var row := HBoxContainer.new()
	box.add_child(row)
	var reset := Button.new()
	reset.text = "Reset to defaults"
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(func() -> void:
		var bar: Array[String] = keybinds.bar.duplicate()
		keybinds.reset()
		keybinds.bar = bar
		keybinds.save()
		refresh())
	row.add_child(reset)
	var done := Button.new()
	done.text = "Close"
	done.focus_mode = Control.FOCUS_NONE
	done.pressed.connect(close)
	row.add_child(done)
	refresh()


## Sizes the list to its rows (whose height depends on the theme), scrolling past `max_height`.
func fit() -> void:
	var content: Vector2 = _columns.get_combined_minimum_size()
	_scroll.custom_minimum_size = Vector2(content.x, minf(content.y, _max_height))
	reset_size()


## One action: its name, then its primary and secondary key buttons.
func _add_row(grid: GridContainer, action: String) -> void:
	var title_label := Label.new()
	title_label.text = Keybinds.DEFAULTS[action][0]
	title_label.custom_minimum_size.x = LABEL_WIDTH
	title_label.add_theme_font_size_override("font_size", FONT_SIZE)
	grid.add_child(title_label)
	for index: int in 2:
		var button := Button.new()
		button.custom_minimum_size = Vector2(KEY_WIDTH, ROW_HEIGHT)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", FONT_SIZE)
		button.clip_text = true
		button.pressed.connect(func() -> void:
			waiting = [action, index]
			refresh())
		grid.add_child(button)
		_buttons[[action, index]] = button


func refresh() -> void:
	for pair: Array in _buttons:
		var key: Key = keybinds.keys[pair[0]][pair[1]]
		_buttons[pair].text = "Press a key…" if pair == waiting else Keybinds.key_name(key)


func _input(event: InputEvent) -> void:
	if not visible or waiting.is_empty() or not event is InputEventKey or not event.pressed or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	var key: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	if key in [KEY_BACKSPACE, KEY_DELETE]:
		keybinds.bind(waiting[0], waiting[1], KEY_NONE)
	elif key != KEY_ESCAPE:
		keybinds.bind(waiting[0], waiting[1], key)
	keybinds.save()
	waiting = []
	refresh()
