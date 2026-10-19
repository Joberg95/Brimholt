extends Node
## Heads-up display around the game window: the centred action message, the zone banner, the health and mana bars, the target frame (your target's name, level, and health
## beside your bars), the buff bar (game/ui/buff_bar.gd), and the Controls menu.

const World = preload("res://game/core/world.gd")
const Balance = preload("res://game/data/balance.gd")
const Layout = preload("res://game/ui/layout.gd")
const ControlsMenu = preload("res://game/ui/controls_menu.gd")
const UiTheme = preload("res://game/ui/ui_theme.gd")
const SpriteArt = preload("res://game/render/sprite_art.gd")
const Regions = preload("res://game/data/regions.gd")
const Monsters = preload("res://game/data/monsters.gd")
const BuffBar = preload("res://game/ui/buff_bar.gd")
const MESSAGE_SECONDS: float = 4.0

var game: Node
## The host's LAN address for Join, edited on the start screen (kept here, hidden, for main.gd).
var address: LineEdit
var controls: PanelContainer
var zone_label: Label
var vitals: Control
## The effects on you (a meal, roots, slows), above the minimap.
var buff_bar: Node
## Your target's name, level, and health, right of the vitals; hidden without a target.
var target_frame: Control
var _action: Label
var _zone_name: String = ""
## The continent you were last on (World.continent_at): sailing to another one is announced.
var _continent: String = ""
## Under the minimap: where you are and its monster levels (World.location_at).
var location_label: Label
var _location_key: String = ""
var _shown_message: String = ""
var _message_since: float = 0.0


func build(game_node: Node, layer: CanvasLayer) -> void:
	game = game_node
	address = LineEdit.new()
	address.text = "127.0.0.1"
	address.visible = false
	layer.add_child(address)
	vitals = Control.new()
	vitals.position = Layout.VIEW_ORIGIN + Vector2(10, 8)
	vitals.size = Vector2(220, 34)
	vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals.draw.connect(_draw_vitals)
	target_frame = Control.new()
	target_frame.position = vitals.position + Vector2(vitals.size.x + 16, 0)
	target_frame.size = Vector2(240, 34)
	target_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_frame.draw.connect(_draw_target)
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
	location_label = Label.new()
	location_label.position = Layout.PANEL_ORIGIN + Vector2(0, 681)
	location_label.size = Vector2(184, 18)
	location_label.add_theme_font_size_override("font_size", 11)
	location_label.clip_text = true
	location_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	location_label.mouse_filter = Control.MOUSE_FILTER_PASS
	# The side panel's background is built later in the same layer; stay above it.
	location_label.z_index = 2
	layer.add_child(location_label)
	layer.add_child(vitals)
	layer.add_child(target_frame)
	buff_bar = BuffBar.new()
	add_child(buff_bar)
	buff_bar.build(game, layer)
	controls = ControlsMenu.new()
	controls.theme = UiTheme.build()
	controls.visible = false
	controls.setup(game.keybinds, func() -> void: controls.hide(), Layout.VIEW_SIZE.y - 140)
	layer.add_child(controls)
	var centre: Callable = func() -> void:
		controls.position = Layout.VIEW_ORIGIN + Vector2((Layout.VIEW_SIZE.x - controls.size.x) / 2.0, 24)
	controls.resized.connect(centre)
	controls.fit()
	centre.call()


## Per frame: the zone banner and the vitals.
func refresh() -> void:
	_update_zone()
	buff_bar.refresh()
	vitals.queue_redraw()
	target_frame.queue_redraw()


## Your target's title, danger-coloured like its nameplate, and its health; {} without a target.
func target_info() -> Dictionary:
	var view: Dictionary = game.creature_view(game.own_target())
	if view.is_empty() or not view.has("state") or not view["state"].has("health"):
		return {}
	var state: Dictionary = view["state"]
	var own_level: int = game.actors[game.self_id]["state"].get("level", 1) if game.actors.has(game.self_id) else 1
	var title: String
	if state.has("kind"):
		title = Monsters.title(state["kind"], state.get("level", 1), state.get("enraged", false))
	elif state.has("name"):
		title = "%s %d" % [String(state["name"]).get_slice(" of ", 0), state.get("level", 1)]
	else:
		title = "%s %d" % [Balance.profile_of(state.get("vocation", ""))["name"], state.get("level", 1)]
	return {"title": title, "health": int(state["health"]), "max_health": int(state["max_health"]),
		"color": SpriteArt.danger_color(state.get("level", 1), own_level)}


func _draw_target() -> void:
	var info: Dictionary = target_info()
	if info.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	target_frame.draw_string_outline(font, Vector2(2, 11), info["title"], HORIZONTAL_ALIGNMENT_LEFT, target_frame.size.x, 12, 4,
		Color("#0b0e12"))
	target_frame.draw_string(font, Vector2(2, 11), info["title"], HORIZONTAL_ALIGNMENT_LEFT, target_frame.size.x, 12, info["color"])
	var area := Rect2(0, 17, target_frame.size.x, 14)
	var share: float = clampf(float(info["health"]) / maxf(1.0, info["max_health"]), 0.0, 1.0)
	target_frame.draw_rect(area, Color(0, 0, 0, 0.6))
	target_frame.draw_rect(Rect2(area.position, Vector2(area.size.x * share, area.size.y)), Color("#c0392b"))
	target_frame.draw_rect(area, Color("#0b0e12"), false, 1.0)
	target_frame.draw_string(font, area.position + Vector2(4, 11), "HP %d / %d" % [info["health"], info["max_health"]],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	target_frame.draw_string(font, area.position + Vector2(area.size.x - 40, 11), "%d%%" % roundi(share * 100.0),
		HORIZONTAL_ALIGNMENT_RIGHT, 36, 11, Color.WHITE)


## The action message until it has shown for MESSAGE_SECONDS (the status line is in the game menu).
func update_labels() -> void:
	var message: String = game.last_action_message
	var now: float = game._now()
	if message != _shown_message:
		_shown_message = message
		_message_since = now
	elif not message.is_empty() and now - _message_since > MESSAGE_SECONDS:
		game.last_action_message = ""
		_shown_message = ""
	_action.text = game.last_action_message


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


## The location line under the minimap, and "Entering ..." when you cross into a new region.
func _update_location() -> void:
	var actors: Dictionary = game.actors
	if not actors.has(game.self_id):
		location_label.text = ""
		return
	var state: Dictionary = actors[game.self_id]["state"]
	var place: Dictionary = World.location_at(state["cell"])
	var rest: String = _rest_text(state, actors[game.self_id]) if place.get("kind", "") == "town" else ""
	var key: String = "%s|%d|%s" % [place.get("name", ""), state.get("level", 1), rest]
	if key == _location_key:
		return
	var entered: bool = place.get("name", "") != _location_key.get_slice("|", 0)
	_location_key = key
	if place.is_empty():
		location_label.text = ""
		return
	var levels: String = "safe town%s" % rest if place["kind"] == "town" else ("no monsters" if place["max_level"] == 0
		else "levels %d–%d" % [place["min_level"], place["max_level"]])
	location_label.text = "%s · %s%s" % [place["name"], levels, " · PvP" if place["kind"] == "pvp" else ""]
	location_label.tooltip_text = Regions.description(place["name"])
	var colour: Color = Color("#9fe0a0") if place["kind"] == "town" else SpriteArt.danger_color(place["max_level"], state.get("level", 1))
	location_label.add_theme_color_override("font_color", Color("#ff8a7a") if place["kind"] == "pvp" else colour)
	if entered and place["kind"] == "region" and game.last_action_message.is_empty():
		game.last_action_message = "Entering %s (%s)." % [place["name"], levels]


## " · resting", " · rest ready", or " · rest in 2:31" (town rest, combat.gd TOWN_REST_*).
func _rest_text(state: Dictionary, view: Dictionary) -> String:
	if state.get("town_rest", false):
		return " · resting"
	var left: float = state.get("town_rest_left", 0.0) - (game._now() - view.get("received", game._now()))
	if left <= 0.0:
		return " · rest ready"
	return " · rest in %d:%02d" % [int(left) / 60, int(left) % 60]


func _update_zone() -> void:
	var actors: Dictionary = game.actors
	var self_id: int = game.self_id
	_update_location()
	var zone: Dictionary = World.zone_at(actors[self_id]["state"]["cell"]) if actors.has(self_id) else {}
	var zone_name: String = zone.get("name", "")
	var message: String = game.last_action_message
	# Caves and dungeons need no banner or announcement: the line under the minimap names them.
	var below: bool = zone.has("cave") or zone.get("underground", false)
	# Announce the zone unless a newer message (such as a death report) is still showing.
	if zone_name != _zone_name and not zone_name.is_empty() and not below \
			and (message.is_empty() or game._now() - _message_since > 2.0):
		game.last_action_message = "Entering %s." % zone_name
	_zone_name = zone_name
	var continent: String = World.continent_at(actors[self_id]["state"]["cell"]) if actors.has(self_id) else ""
	if not continent.is_empty() and continent != _continent:
		if not _continent.is_empty():
			game.last_action_message = "You arrive on %s." % continent
		_continent = continent
	zone_label.visible = not zone.is_empty() and not below
	if not zone.is_empty():
		var pvp: bool = actors[self_id]["state"].get("pvp", false)
		var rule: String = ("PvP zone: other PvP players can attack you" if pvp
			else "PvP zone, but your PvP is off: players cannot attack you") if zone["pvp"] else "safe zone"
		if zone.has("cave"):
			rule = "a hunting cave shared with every hunter; the stairs up lead back"
		elif zone.get("underground", false):
			rule = "your party's private copy; the stairs up lead back"
		if zone.get("full_loot", false):
			rule = "HIGH-RISK PvP: you drop all your gear if you die"
		zone_label.text = "%s  —  %s  ·  monsters level %d-%d" % [zone_name, rule, zone["min_level"], zone["max_level"]]
		if zone.get("town", false):
			zone_label.text = "%s  —  safe zone" % zone_name
		zone_label.add_theme_color_override("font_color", Color("#9fe0a0") if zone.get("town", false) else Color("#ff8a7a"))
