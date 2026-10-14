extends Control
## The start screen shown until you host or join: a painted backdrop (assets/sprites/title.png,
## make_sprites.py title_painting) with your chosen character standing on the ledge, looking at
## the castle; a list of this computer's characters (game/persistence/identity.gd profiles) with
## their class, level, and look, a "Create new character" entry, and Host or Join for the chosen
## one. New characters start as Adventurers and choose a class in the game (Quests.TRAINERS).

const Identity = preload("res://game/persistence/identity.gd")
const World = preload("res://game/core/world.gd")
const Balance = preload("res://game/data/balance.gd")
const SpriteArt = preload("res://game/render/sprite_art.gd")
const BACKDROP: Texture2D = preload("res://assets/sprites/title.png")
const UiTheme = preload("res://game/ui/ui_theme.gd")

const GOLD: Color = Color("#ffcf6a")
const TEXT: Color = Color("#e8e4da")
const MUTED: Color = Color("#a7b0b8")
const WARN: Color = Color("#e4bd8a")
const CARD: Color = Color("#1a2028e6")
const CARD_HOVER: Color = Color("#232c36f0")
## Where the hero stands on the painting's ledge (screen pixels) and how large.
const HERO_FEET: Vector2 = Vector2(612, 676)
const HERO_SCALE: float = 3.0
## What a character with no saved look wears in the menu.
const DEFAULT_LOOK: Dictionary = {"helmet": "ember_cap", "armor": "moss_coat", "legs": "moss_breeches", "boots": "moss_boots",
	"main_hand": "copper_blade", "off_hand": "oak_buckler"}

var game: Node
var characters: Array = []
var selected: String = ""
var _have_selection: bool = false
var _list: VBoxContainer
var _form: VBoxContainer
var _name_field: LineEdit
var _play: VBoxContainer
var _status: Label
var _delete: Button
var _delete_armed_until: float = 0.0
var _hero: Control
var _scroll: ScrollContainer


func setup(game_node: Node, address: LineEdit) -> void:
	game = game_node
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := TextureRect.new()
	backdrop.texture = BACKDROP
	backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(backdrop)
	_hero = Control.new()
	_hero.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hero.draw.connect(_draw_hero)
	add_child(_hero)
	var title := Label.new()
	title.text = "BRIMHOLT"
	title.position = Vector2(48, 30)
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_color_override("font_outline_color", Color("#1a1420"))
	title.add_theme_constant_override("outline_size", 12)
	add_child(title)
	var tagline := Label.new()
	tagline.text = "A world for friends on the same network"
	tagline.position = Vector2(54, 112)
	tagline.add_theme_font_size_override("font_size", 16)
	tagline.add_theme_color_override("font_color", Color("#f0dcc0"))
	tagline.add_theme_color_override("font_outline_color", Color("#1a1420"))
	tagline.add_theme_constant_override("outline_size", 6)
	add_child(tagline)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#10141af0")
	style.border_color = Color("#6a5a3a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(14)
	style.anti_aliasing = false
	panel.add_theme_stylebox_override("panel", style)
	panel.theme = UiTheme.build()
	panel.position = Vector2(48, 156)
	panel.custom_minimum_size = Vector2(400, 0)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	column.add_child(_heading("Characters"))
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(372, 110)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	_scroll.add_child(_list)
	_form = VBoxContainer.new()
	_form.add_theme_constant_override("separation", 6)
	_form.visible = false
	column.add_child(_form)
	_build_form()
	_play = VBoxContainer.new()
	_play.add_theme_constant_override("separation", 6)
	column.add_child(_play)
	var solo := _button("Play solo", func() -> void: _start(true, true))
	solo.tooltip_text = "A private world: three companions join your party, rival bands roam, quest, and hunt you in PvP zones"
	solo.custom_minimum_size.y = 38
	solo.add_theme_font_size_override("font_size", 17)
	_play.add_child(solo)
	var actions := HBoxContainer.new()
	_play.add_child(actions)
	var host := _button("Host a game", func() -> void: _start(true))
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.custom_minimum_size.y = 34
	actions.add_child(host)
	_delete = _button("Delete", _delete_pressed)
	_delete.tooltip_text = "Forget this character on this computer (hosts keep its save, but nobody can play it again)"
	actions.add_child(_delete)
	var join_row := HBoxContainer.new()
	_play.add_child(join_row)
	var start_address := LineEdit.new()
	start_address.text = address.text
	start_address.placeholder_text = "Host's LAN IP, e.g. 192.168.1.20"
	start_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_address.text_changed.connect(func(text: String) -> void: address.text = text)
	start_address.text_submitted.connect(func(_text: String) -> void: _start(false))
	join_row.add_child(start_address)
	join_row.add_child(_button("Join", func() -> void: _start(false)))
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 372
	_status.add_theme_color_override("font_color", WARN)
	column.add_child(_status)
	reload()


func _build_form() -> void:
	_form.add_child(_heading("New character"))
	var note := Label.new()
	note.text = "You begin as an adventurer in Cinder Crossing: pass Master Hesk's trial, then choose your class from its trainers."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 372
	note.add_theme_color_override("font_color", MUTED)
	_form.add_child(note)
	_name_field = LineEdit.new()
	_name_field.placeholder_text = "Name (2-%d letters)" % Identity.MAX_NAME
	_name_field.max_length = Identity.MAX_NAME
	_name_field.text_submitted.connect(func(_text: String) -> void: _create())
	_form.add_child(_name_field)
	var row := HBoxContainer.new()
	_form.add_child(row)
	var create := _button("Create", _create)
	create.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(create)
	row.add_child(_button("Cancel", func() -> void: _show_form(false)))


## Reads this computer's characters and rebuilds the list (the selection is kept if it still exists).
func reload() -> void:
	characters = Identity.characters()
	rebuild()


func rebuild() -> void:
	var wanted: String = game.identity_profile if not _have_selection else selected
	if not _have_selection and wanted.is_empty():
		wanted = Identity.last_profile()
	if not characters.any(func(entry: Dictionary) -> bool: return entry["profile"] == wanted):
		wanted = characters[0]["profile"] if not characters.is_empty() else ""
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for entry: Dictionary in characters:
		_list.add_child(_card(entry))
	_list.add_child(_create_card())
	# Up to five characters show at once; more scroll.
	_scroll.custom_minimum_size.y = mini(5, characters.size()) * 64 + 42
	_select(wanted, not characters.is_empty())
	_show_form(characters.is_empty())


func _select(profile: String, known: bool) -> void:
	selected = profile
	_have_selection = known
	_delete_armed_until = 0.0
	_delete.text = "Delete"
	_delete.disabled = not known
	for card: Node in _list.get_children():
		(card as Control).queue_redraw()
	_hero.queue_redraw()


func _show_form(shown: bool) -> void:
	_form.visible = shown
	_play.visible = not shown and _have_selection
	if shown:
		_name_field.text = ""
		_name_field.call_deferred("grab_focus")


func _create() -> void:
	var profile: String = Identity.create(_name_field.text)
	if profile.is_empty():
		game._status_message = "Names need 2 to %d letters or digits." % Identity.MAX_NAME
		return
	game._status_message = ""
	_have_selection = true
	selected = profile
	reload()


func _delete_pressed() -> void:
	var entry: Dictionary = _entry(selected)
	if entry.is_empty():
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now > _delete_armed_until:
		_delete_armed_until = now + 4.0
		_delete.text = "Really delete?"
		game._status_message = "Click again to forget %s on this computer. This cannot be undone." % entry["name"]
		return
	Identity.delete(selected)
	game._status_message = "%s was forgotten." % entry["name"]
	_have_selection = false
	reload()


func _start(hosting: bool, alone: bool = false) -> void:
	if not _have_selection:
		game._status_message = "Create a character first."
		_show_form(true)
		return
	game.select_character(selected)
	if alone:
		game.play_solo()
	elif hosting:
		game.host_game()
	else:
		game.join_game()


func _entry(profile: String) -> Dictionary:
	for entry: Dictionary in characters:
		if entry["profile"] == profile:
			return entry
	return {}


## Per frame: shown while offline (never on a dedicated server), with the latest status.
func refresh() -> void:
	var was: bool = visible
	visible = not game.connected and not game.dedicated
	if visible and not was:
		reload()
	if visible:
		_status.text = game._status_message
		if _delete_armed_until > 0.0 and Time.get_ticks_msec() / 1000.0 > _delete_armed_until:
			_delete_armed_until = 0.0
			_delete.text = "Delete"


# ---------------------------------------------------------------- drawing

func _card(entry: Dictionary) -> Control:
	var card := Control.new()
	card.custom_minimum_size = Vector2(360, 58)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.draw.connect(func() -> void: _draw_card(card, entry))
	card.mouse_entered.connect(card.queue_redraw)
	card.mouse_exited.connect(card.queue_redraw)
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_select(entry["profile"], true)
			_show_form(false)
			if event.double_click:
				_start(true, true))
	card.tooltip_text = "Double-click to play solo with %s" % entry["name"]
	return card


func _draw_card(card: Control, entry: Dictionary) -> void:
	var area := Rect2(Vector2.ZERO, card.size)
	var chosen: bool = entry["profile"] == selected and _have_selection
	card.draw_rect(area, CARD_HOVER if card.get_rect().has_point(card.get_parent_control().get_local_mouse_position()) else CARD)
	card.draw_rect(area, GOLD if chosen else Color("#3a4450"), false, 2.0 if chosen else 1.0)
	card.draw_set_transform(Vector2(30, 58), 0.0, Vector2.ONE * 0.9)
	SpriteArt.draw_actor(card, Vector2.ZERO - SpriteArt.FEET, {"id": 0, "facing": Vector2i.DOWN, "equipment": _look(entry)}, false)
	card.draw_set_transform(Vector2.ZERO)
	var font: Font = ThemeDB.fallback_font
	card.draw_string(font, Vector2(64, 24), entry["name"], HORIZONTAL_ALIGNMENT_LEFT, 280, 17, GOLD if chosen else TEXT)
	var vocation: String = entry["vocation"]
	var what: String = "New adventurer" if entry["level"] <= 0 else "Level %d %s" % [entry["level"],
		Balance.profile_of(vocation)["name"] if Balance.is_vocation(vocation) else "Adventurer"]
	card.draw_string(font, Vector2(64, 44), "%s  ·  %s" % [what, _played(entry["played"])], HORIZONTAL_ALIGNMENT_LEFT, 290, 12, MUTED)


func _create_card() -> Control:
	var card := Control.new()
	card.custom_minimum_size = Vector2(360, 42)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.draw.connect(func() -> void:
		var area := Rect2(Vector2.ZERO, card.size)
		var hover: bool = card.get_rect().has_point(card.get_parent_control().get_local_mouse_position())
		card.draw_rect(area, CARD_HOVER if hover else Color("#141a20c0"))
		card.draw_rect(area.grow(-1), Color("#6a5a3a"), false, 1.0)
		card.draw_string(ThemeDB.fallback_font, Vector2(18, 27), "+  Create new character", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, GOLD))
	card.mouse_entered.connect(card.queue_redraw)
	card.mouse_exited.connect(card.queue_redraw)
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_show_form(true))
	return card


## The selected character on the ledge, seen from behind, looking out at the castle.
func _draw_hero() -> void:
	var entry: Dictionary = _entry(selected)
	if entry.is_empty():
		return
	_hero.draw_set_transform(HERO_FEET, 0.0, Vector2.ONE * HERO_SCALE)
	var shadow := PackedVector2Array()
	for step: int in 16:
		shadow.append(Vector2(cos(step * TAU / 16.0) * 11.0, sin(step * TAU / 16.0) * 3.5))
	_hero.draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
	SpriteArt.draw_actor(_hero, Vector2.ZERO - SpriteArt.FEET, {"id": 0, "facing": Vector2i.UP, "equipment": _look(entry)}, false)
	_hero.draw_set_transform(Vector2.ZERO)


## The character's saved look, keeping only items the catalog still knows.
func _look(entry: Dictionary) -> Dictionary:
	var look: Dictionary = {}
	for slot: Variant in entry["equipment"]:
		var kind: Variant = entry["equipment"][slot]
		if typeof(slot) == TYPE_STRING and typeof(kind) == TYPE_STRING and World.ITEMS.has(kind) and World.fits(kind, slot):
			look[slot] = kind
	return look if entry["level"] > 0 else DEFAULT_LOOK


static func _played(when: int) -> String:
	var days: int = int((Time.get_unix_time_from_system() - when) / 86400.0)
	if when <= 0:
		return "never played"
	return "played today" if days < 1 else ("played yesterday" if days < 2 else "played %d days ago" % days)


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", GOLD)
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	return button
