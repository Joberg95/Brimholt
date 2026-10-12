extends Node
## Heads-up display around the game window: the title row (Host, address, Join, Leave,
## Controls, vocation), the connection status line, the centred action message, the zone
## banner, the health and mana bars, and the Controls menu.

const World = preload("res://game/core/world.gd")
const Balance = preload("res://game/data/balance.gd")
const Layout = preload("res://game/ui/layout.gd")
const ControlsMenu = preload("res://game/ui/controls_menu.gd")
const MESSAGE_SECONDS: float = 4.0

var game: Node
var address: LineEdit
var vocation: OptionButton
var controls: PanelContainer
var zone_label: Label
var vitals: Control
var _status: Label
var _action: Label
var _zone_name: String = ""
var _shown_message: String = ""
var _message_since: float = 0.0


func build(game_node: Node, layer: CanvasLayer) -> void:
	game = game_node
	var row := HBoxContainer.new()
	row.position = Vector2(16, 12)
	layer.add_child(row)
	var title := Label.new()
	title.text = "BRIMHOLT  ·  " + World.WORLD_NAME + "   "
	title.add_theme_font_size_override("font_size", 20)
	row.add_child(title)
	_add_button(row, "Host", Callable(game, "host_game"))
	address = LineEdit.new()
	address.text = "127.0.0.1"
	address.placeholder_text = "Host LAN IP"
	address.custom_minimum_size.x = 200
	row.add_child(address)
	_add_button(row, "Join", Callable(game, "join_game"))
	_add_button(row, "Leave", Callable(game, "leave_game"))
	_add_button(row, "Controls", func() -> void: controls.visible = not controls.visible)
	vitals = Control.new()
	vitals.position = Layout.VIEW_ORIGIN + Vector2(10, 8)
	vitals.size = Vector2(220, 34)
	vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals.draw.connect(_draw_vitals)
	vocation = OptionButton.new()
	for choice: String in Balance.VOCATIONS:
		vocation.add_item(Balance.VOCATIONS[choice]["name"])
	vocation.select(Balance.VOCATIONS.keys().find(Balance.DEFAULT_VOCATION))
	vocation.tooltip_text = "Vocation used when you host or join"
	row.add_child(vocation)
	_status = Label.new()
	_status.position = Vector2(16, 48)
	layer.add_child(_status)
	_action = Label.new()
	_action.position = Layout.VIEW_ORIGIN + Vector2(0, Layout.VIEW_SIZE.y - 40 - Layout.BAR_SLOT - 8)
	_action.size = Vector2(Layout.VIEW_SIZE.x, 32)
	_action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action.add_theme_color_override("font_color", Color("#f4f0e6"))
	_action.add_theme_color_override("font_outline_color", Color("#101010"))
	_action.add_theme_constant_override("outline_size", 6)
	layer.add_child(_action)
	zone_label = Label.new()
	zone_label.position = Layout.VIEW_ORIGIN + Vector2(0, 44)
	zone_label.size = Vector2(Layout.VIEW_SIZE.x, 24)
	zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone_label.add_theme_color_override("font_color", Color("#ff8a7a"))
	zone_label.add_theme_color_override("font_outline_color", Color("#1a0605"))
	zone_label.add_theme_constant_override("outline_size", 6)
	zone_label.visible = false
	layer.add_child(zone_label)
	layer.add_child(vitals)
	controls = ControlsMenu.new()
	controls.visible = false
	controls.setup(game.keybinds, func() -> void: controls.hide())
	controls.position = Layout.VIEW_ORIGIN + Vector2(Layout.VIEW_SIZE.x / 2.0 - 190, 40)
	layer.add_child(controls)


## Per frame: the zone banner and the vitals.
func refresh() -> void:
	_update_zone()
	vitals.queue_redraw()


## The status line, and the action message until it has shown for MESSAGE_SECONDS.
func update_labels() -> void:
	var connected: bool = game.connected
	var actors: Dictionary = game.actors
	var status_message: String = game._status_message
	_status.text = status_message + ("  |  %d/%d players" % [actors.size(), World.MAX_PLAYERS] if connected else "")
	_status.modulate = Color("#9ccea4") if connected else Color("#e4bd8a")
	var message: String = game.last_action_message
	var now: float = game._now()
	if message != _shown_message:
		_shown_message = message
		_message_since = now
	elif not message.is_empty() and now - _message_since > MESSAGE_SECONDS:
		game.last_action_message = ""
		_shown_message = ""
	_action.text = game.last_action_message


func _add_button(parent: Node, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)


func _draw_vitals() -> void:
	var actors: Dictionary = game.actors
	var self_id: int = game.self_id
	if not actors.has(self_id) or not actors[self_id]["state"].has("mana"):
		return
	var state: Dictionary = actors[self_id]["state"]
	var font: Font = ThemeDB.fallback_font
	var rows: Array = [[state["health"], state["max_health"], Color("#c0392b"), "HP"],
		[state["mana"], state["max_mana"], Color("#2e6fd0"), "MP"]]
	for index: int in rows.size():
		var row: Array = rows[index]
		var area := Rect2(0, index * 17, vitals.size.x, 14)
		vitals.draw_rect(area, Color(0, 0, 0, 0.6))
		vitals.draw_rect(Rect2(area.position, Vector2(area.size.x * clampf(float(row[0]) / maxf(1.0, row[1]), 0.0, 1.0), 14)), row[2])
		vitals.draw_rect(area, Color("#0b0e12"), false, 1.0)
		vitals.draw_string(font, area.position + Vector2(4, 11), "%s %d / %d" % [row[3], row[0], row[1]],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)


func _update_zone() -> void:
	var actors: Dictionary = game.actors
	var self_id: int = game.self_id
	var zone: Dictionary = World.zone_at(actors[self_id]["state"]["cell"]) if actors.has(self_id) else {}
	var name: String = zone.get("name", "")
	var message: String = game.last_action_message
	# Announce the zone unless a newer message (such as a death report) is still showing.
	if name != _zone_name and not name.is_empty() and (message.is_empty() or game._now() - _message_since > 2.0):
		game.last_action_message = "Entering %s." % name
	_zone_name = name
	zone_label.visible = not zone.is_empty()
	if not zone.is_empty():
		var rule: String = "PvP zone: other players can attack you" if zone["pvp"] else "safe zone"
		if zone.get("full_loot", false):
			rule = "HIGH-RISK PvP: you drop all your gear if you die"
		zone_label.text = "%s  —  %s  ·  monsters level %d-%d" % [name, rule, zone["min_level"], zone["max_level"]]
		if zone.get("town", false):
			zone_label.text = "%s  —  safe town: no PvP, and monsters cannot enter" % name
		zone_label.add_theme_color_override("font_color", Color("#9fe0a0") if zone.get("town", false) else Color("#ff8a7a"))
