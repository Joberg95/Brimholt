extends PanelContainer
## The game menu, opened by the cogwheel in the micro menu (and closed by it, Esc, or Close): the
## game's name and connection status, everyone on the host (name, class or endgame title, and
## level), settings, and the way to the Controls menu and back to the start screen. It replaces
## the old title row above the game window, so the window sits at the top of the screen.
##
## Settings are saved to SETTINGS_PATH (unless `persistent` is off, as in tests): weather effects
## (rain and snow over the game window), floating damage numbers, fullscreen, and pixel-perfect
## scaling. The game scales to fill the window or screen (project.godot: canvas_items, fractional,
## aspect kept), so text stays sharp at any size; pixel-perfect scaling keeps to whole steps
## (crisper pixel art, black borders on most screens). At startup the window opens at
## WINDOW_FILL of the screen, unless the command line sets its size or place (tests, the bench).

const World = preload("res://game/core/world.gd")
const Balance = preload("res://game/data/balance.gd")
const Titles = preload("res://game/data/titles.gd")
const Layout = preload("res://game/ui/layout.gd")
const UiTheme = preload("res://game/ui/ui_theme.gd")

const SETTINGS_PATH: String = "user://settings.cfg"
const WIDTH: float = 420.0
const MUTED: Color = Color("#a7b0b8")
## Setting key -> [label, tooltip, default].
const SETTINGS: Dictionary = {
	"weather": ["Weather effects", "Rain and snow falling over the game window", true],
	"damage_numbers": ["Damage numbers", "Floating numbers for damage, healing, and experience", true],
	"fullscreen": ["Fullscreen", "Fill the whole screen", false],
	"pixel_perfect": ["Pixel-perfect scaling", "Scale only in whole steps: the crispest pixels, but black borders on most screens", false],
}
## Share of the screen the window opens at.
const WINDOW_FILL: float = 0.85

var game: Node
var persistent: bool = true
var settings: Dictionary = {}
var status: Label
var controls_button: Button
var leave_button: Button
var _players: VBoxContainer
var _players_key: String = ""
var _window_fitted: bool = false


func build(game_node: Node, open_controls: Callable) -> void:
	game = game_node
	persistent = game.keybinds.persistent
	visible = false
	theme = UiTheme.build()
	add_theme_stylebox_override("panel", UiTheme.panel())
	custom_minimum_size = Vector2(WIDTH, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	var title := Label.new()
	title.text = "BRIMHOLT"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	column.add_child(title)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(WIDTH - 24, 0)
	column.add_child(status)
	column.add_child(_heading("Players"))
	_players = VBoxContainer.new()
	_players.add_theme_constant_override("separation", 1)
	column.add_child(_players)
	column.add_child(_heading("Settings"))
	_load_settings()
	for key: String in SETTINGS:
		var toggle := CheckBox.new()
		toggle.text = SETTINGS[key][0]
		toggle.tooltip_text = SETTINGS[key][1]
		toggle.button_pressed = settings[key]
		toggle.focus_mode = Control.FOCUS_NONE
		# Plain ticks, not framed like the buttons below.
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			toggle.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		toggle.toggled.connect(func(on: bool) -> void: set_setting(key, on))
		column.add_child(toggle)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	controls_button = _button(row, "Controls", "Rebind your keys", func() -> void:
		hide()
		open_controls.call())
	leave_button = _button(row, "Leave game", "Save and return to the start screen", Callable(game, "leave_game"))
	_button(row, "Close", "Close this menu (Esc)", hide)
	resized.connect(_centre)
	visibility_changed.connect(func() -> void:
		if visible:
			_players_key = ""
			refresh()
			# Shrink to the content (it grows with the player list) and stay centred.
			reset_size.call_deferred())
	apply_settings()


## Per frame while open: the status line and the player list (rebuilt only when it changes).
func refresh() -> void:
	if not visible:
		return
	var connected: bool = game.connected
	status.text = game._status_message + ("  ·  %d/%d players" % [game.actors.size(), World.MAX_PLAYERS] if connected else "")
	status.add_theme_color_override("font_color", Color("#9ccea4") if connected else Color("#e4bd8a"))
	var ids: Array = game.actors.keys()
	ids.sort()
	var rows: Array = []
	for id: int in ids:
		var state: Dictionary = game.actors[id]["state"]
		if not state.has("vocation"):
			continue
		rows.append([id, _name_of(id, state), state.get("vocation", ""), int(state.get("title", 0)), int(state.get("level", 1))])
	var key: String = str(rows)
	if key == _players_key:
		return
	_players_key = key
	for child: Node in _players.get_children():
		child.queue_free()
	for entry: Array in rows:
		var line := HBoxContainer.new()
		var who := Label.new()
		who.text = entry[1]
		who.custom_minimum_size = Vector2(170, 0)
		who.clip_text = true
		who.add_theme_color_override("font_color", UiTheme.GOLD if entry[0] == game.self_id else UiTheme.TEXT)
		line.add_child(who)
		var rank := Label.new()
		var title: String = Titles.name_of(entry[2], entry[3])
		rank.text = "%s %d" % [Balance.profile_of(entry[2])["name"] if title.is_empty() else title, entry[4]]
		rank.add_theme_color_override("font_color", MUTED if title.is_empty() else Titles.color_of(entry[3]))
		line.add_child(rank)
		_players.add_child(line)


func set_setting(key: String, on: bool) -> void:
	settings[key] = on
	apply_settings()
	if persistent:
		var file := ConfigFile.new()
		for setting: String in settings:
			file.set_value("game", setting, settings[setting])
		file.save(SETTINGS_PATH)


## Puts the settings into effect: the rain layer, damage numbers (main.gd reads the setting), and
## the window mode.
func apply_settings() -> void:
	if game._view != null and game._view.rain != null:
		game._view.rain.enabled = settings["weather"]
	if DisplayServer.get_name() != "headless" and persistent:
		get_tree().root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if settings["pixel_perfect"] \
			else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
		var mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
		if not _window_fitted and mode == DisplayServer.WINDOW_MODE_WINDOWED:
			_window_fitted = true
			_fit_window()


## Opens the window at WINDOW_FILL of the screen's usable area, in the game's shape, centred
## (not when the command line sets the window's size or place).
func _fit_window() -> void:
	for arg: String in OS.get_cmdline_args():
		if arg in ["--resolution", "--position", "--maximized", "--fullscreen"]:
			return
	var screen: int = DisplayServer.window_get_current_screen()
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	var base := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	var factor: float = minf(usable.size.x / base.x, usable.size.y / base.y) * WINDOW_FILL
	if factor <= 1.0:
		return
	var window := Vector2i((base * factor).round())
	DisplayServer.window_set_size(window)
	DisplayServer.window_set_position(usable.position + (usable.size - window) / 2)


func _load_settings() -> void:
	for key: String in SETTINGS:
		settings[key] = SETTINGS[key][2]
	if not persistent:
		return
	var file := ConfigFile.new()
	if file.load(SETTINGS_PATH) == OK:
		for key: String in SETTINGS:
			var value: Variant = file.get_value("game", key, settings[key])
			if typeof(value) == TYPE_BOOL:
				settings[key] = value


func _centre() -> void:
	position = Layout.VIEW_ORIGIN + Vector2((Layout.VIEW_SIZE.x - size.x) / 2.0, 40)


func _name_of(id: int, state: Dictionary) -> String:
	if id == game.self_id:
		return "You"
	if state.has("name"):
		return String(state["name"]).get_slice(" of ", 0)
	return "Player %d" % id


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", UiTheme.GOLD)
	return label


func _button(row: HBoxContainer, text: String, tip: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(pressed)
	row.add_child(button)
	return button
