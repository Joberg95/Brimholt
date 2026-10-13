extends PanelContainer
## The host's Bots panel (the Bots button in the top bar, hosts only): add player bots of a
## vocation, level, and stance beside you, see where each is and how it fares, and remove them.
## Bots play through the server's own rules (game/core/bots.gd); clients cannot create them.

const World = preload("res://game/core/world.gd")
const Balance = preload("res://game/data/balance.gd")
const Bots = preload("res://game/core/bots.gd")
const Layout = preload("res://game/ui/layout.gd")

const WIDTH: float = 460.0
const TITLE: Color = Color("#ffcf6a")
const TEXT: Color = Color("#e8e4da")
const MUTED: Color = Color("#a7b0b8")
const STANCE_HELP: Dictionary = {
	"hunter": "Hunts monsters near where it stands and fights back if a player attacks it.",
	"pvp": "Also attacks any player within 7 tiles while both stand in a PvP zone (white skull and all).",
	"dummy": "Stands still and never fights back: test damage, spells, and skulls on it.",
}

var game: Node
var vocation: OptionButton
var level: SpinBox
var stance: OptionButton
var add_button: Button
var _help: Label
var _status: Label
var _list: VBoxContainer
var _key: String = "-"


func _init() -> void:
	position = Layout.VIEW_ORIGIN + Vector2((Layout.VIEW_SIZE.x - WIDTH) / 2.0, 60)
	custom_minimum_size = Vector2(WIDTH, 0)
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
	var title := _label("Player bots", 18, TITLE, 0.0)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "Close"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(hide)
	header.add_child(close)
	column.add_child(_label("Bots join this world as players, play by the same rules, and are never saved.", 12, MUTED))
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 8)
	column.add_child(choices)
	vocation = OptionButton.new()
	for choice: String in Balance.VOCATIONS:
		vocation.add_item(Balance.VOCATIONS[choice]["name"])
	vocation.focus_mode = Control.FOCUS_NONE
	choices.add_child(vocation)
	var level_label := _label("Level", 13, MUTED, 0.0)
	level_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	choices.add_child(level_label)
	level = SpinBox.new()
	level.min_value = 1
	level.max_value = Balance.MAX_LEVEL
	level.value = 40
	choices.add_child(level)
	stance = OptionButton.new()
	for choice: String in Bots.STANCES:
		stance.add_item(Bots.STANCE_NAMES[choice])
	stance.select(Bots.STANCES.find("pvp"))
	stance.focus_mode = Control.FOCUS_NONE
	stance.item_selected.connect(func(_index: int) -> void: _help.text = STANCE_HELP[Bots.STANCES[stance.selected]])
	choices.add_child(stance)
	_help = _label(STANCE_HELP["pvp"], 12, MUTED)
	column.add_child(_help)
	add_button = Button.new()
	add_button.text = "Add a bot beside me"
	add_button.focus_mode = Control.FOCUS_NONE
	add_button.pressed.connect(_add)
	column.add_child(add_button)
	_status = _label("", 12, Color("#e4bd8a"))
	column.add_child(_status)
	_list = VBoxContainer.new()
	column.add_child(_list)
	visible = false
	visibility_changed.connect(func() -> void:
		_key = "-"
		reset_size())


func _add() -> void:
	var refused: String = game.spawn_bot(Balance.VOCATIONS.keys()[vocation.selected], int(level.value), Bots.STANCES[stance.selected])
	_status.text = refused if not refused.is_empty() else "Added. Bots in a PvP zone need you there too to fight you."


## Per frame while open: rebuilds the bot list when bots or their state change.
func refresh() -> void:
	if not visible:
		return
	if not game.hosting:
		hide()
		return
	var help: String = STANCE_HELP[Bots.STANCES[stance.selected]]
	if _help.text != help:
		_help.text = help
	var lines: PackedStringArray = []
	for id: int in game.bots.bots:
		var player: Dictionary = game.world.players.get(id, {})
		if not player.is_empty():
			lines.append("%d|%s|%d|%s|%s|%d" % [id, player["level"], player["health"], player["skull"], player["target"],
				Vector2i(player["cell"]).x / 8 + Vector2i(player["cell"]).y / 8 * 1000])
	var key: String = "|".join(lines) + str(game.world.players.size())
	if key == _key:
		return
	_key = key
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	add_button.disabled = game.world.players.size() >= World.MAX_PLAYERS
	_list.add_child(_label("%d bots · %d of %d player slots used" % [game.bots.bots.size(), game.world.players.size(),
		World.MAX_PLAYERS], 13, TEXT))
	for id: int in game.bots.bots:
		if not game.world.players.has(id):
			continue
		var player: Dictionary = game.world.players[id]
		var bot: Dictionary = game.bots.bots[id]
		var row := HBoxContainer.new()
		var where: String = World.location_at(player["cell"])["name"]
		var doing: String = "restoring" if bot["restore_at"] >= 0.0 else ("fighting" if player["target"] != 0 else "idle")
		var text: String = "%s · %s · %s · %d/%d hp%s" % [game.combat.describe(id), Bots.STANCE_NAMES[bot["stance"]], where,
			player["health"], game.world.player_stats(id)["health"], "" if player["skull"].is_empty() else " · %s skull" % player["skull"]]
		var label := _label("%s · %s" % [text, doing], 12, TEXT, WIDTH - 110.0)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var remove := Button.new()
		remove.text = "Remove"
		remove.focus_mode = Control.FOCUS_NONE
		remove.pressed.connect(func() -> void: game.remove_bot(id))
		row.add_child(remove)
		_list.add_child(row)
	if not game.bots.bots.is_empty():
		var all := Button.new()
		all.text = "Remove all bots"
		all.focus_mode = Control.FOCUS_NONE
		all.pressed.connect(func() -> void:
			for id: int in game.bots.bots.keys():
				game.remove_bot(id))
		_list.add_child(all)
	reset_size()


## A wrapping label `width` wide (the panel's inner width by default).
func _label(content: String, font_size: int, color: Color, width: float = WIDTH - 24.0) -> Label:
	var label := Label.new()
	label.text = content
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = width
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
