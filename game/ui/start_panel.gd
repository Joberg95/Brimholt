extends PanelContainer
## The start menu shown until you host or join: Host, and Join with an address kept in sync
## with the title row's address, plus the connection status. New characters start as
## Adventurers and choose a vocation in the game (Quests.TRAINERS).

const Balance = preload("res://game/data/balance.gd")
const Layout = preload("res://game/ui/layout.gd")

var game: Node
var _status: Label


func setup(game_node: Node, address: LineEdit) -> void:
	game = game_node
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#151a20")
	style.border_color = Color("#3a4450")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(18)
	add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var title := Label.new()
	title.text = "Welcome to Brimholt"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var intro := Label.new()
	intro.text = "Host a game for your friends, or join one on your network.\nNew characters start as adventurers in Cinder" \
		+ " Crossing,\npass a trial, and choose a vocation from its trainers.\nThe host saves yours, so you return as you left."
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.modulate = Color("#a7b0b8")
	box.add_child(intro)
	var host := Button.new()
	host.text = "Host a game"
	host.pressed.connect(Callable(game, "host_game"))
	box.add_child(host)
	var join_row := HBoxContainer.new()
	box.add_child(join_row)
	var start_address := LineEdit.new()
	start_address.text = address.text
	start_address.placeholder_text = "Host's LAN IP, e.g. 192.168.1.20"
	start_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_address.text_changed.connect(func(text: String) -> void: address.text = text)
	start_address.text_submitted.connect(func(_text: String) -> void: game.join_game())
	join_row.add_child(start_address)
	var join := Button.new()
	join.text = "Join"
	join.pressed.connect(Callable(game, "join_game"))
	join_row.add_child(join)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 380
	_status.modulate = Color("#e4bd8a")
	box.add_child(_status)
	custom_minimum_size = Vector2(420, 0)
	position = Layout.VIEW_ORIGIN + Vector2(Layout.VIEW_SIZE.x / 2.0 - 210, Layout.VIEW_SIZE.y / 2.0 - 140)


## Per frame: visible while offline (never on a dedicated server), with the latest status.
func refresh() -> void:
	visible = not game.connected and not game.dedicated
	if visible:
		_status.text = game._status_message
