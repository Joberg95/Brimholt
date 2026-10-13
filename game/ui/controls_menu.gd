extends PanelContainer
## The Controls menu: click a key button, then press the new key. Backspace or Delete clears
## the binding and Escape cancels. A key already used elsewhere moves to the new action.
## Changes are saved immediately.

const Keybinds = preload("res://game/input/keybinds.gd")

var keybinds: Keybinds
var waiting: Array = []
var _buttons: Dictionary = {}


func setup(binds: Keybinds, close: Callable) -> void:
	keybinds = binds
	var box := VBoxContainer.new()
	add_child(box)
	var title := Label.new()
	title.text = "Controls: click a key, then press the new one.\nBackspace clears, Esc cancels."
	box.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("v_separation", 2)
	box.add_child(grid)
	for action: String in Keybinds.DEFAULTS:
		var title_label := Label.new()
		title_label.text = Keybinds.DEFAULTS[action][0]
		title_label.custom_minimum_size.x = 130
		grid.add_child(title_label)
		for index: int in 2:
			var button := Button.new()
			button.custom_minimum_size = Vector2(96, 0)
			button.focus_mode = Control.FOCUS_NONE
			button.pressed.connect(func() -> void:
				waiting = [action, index]
				refresh())
			grid.add_child(button)
			_buttons[[action, index]] = button
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
