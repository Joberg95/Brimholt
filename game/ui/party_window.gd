extends PanelContainer
## The party window (Keybinds "party", O by default, or the micro menu): your party's members
## with their class, level, and health, invitations to accept, invitations you sent, and
## Leave party. Solo, it lists your companions with a class picker each (main.companion_local),
## the raid plan with a count per class and whether it can beat the final boss (Balance.raid_check,
## main.raid_plan_local), and gathers or disbands that raid at level 50 (main.raid_local). Invite players by right-clicking them. Rebuilt only when the party,
## invitations, or raid change; health bars redraw while it is open.

const Balance = preload("res://game/data/balance.gd")
const Layout = preload("res://game/ui/layout.gd")
const UiTheme = preload("res://game/ui/ui_theme.gd")

const WIDTH: float = 560.0
## Classes in the pickers, in the trainers' order.
const CLASSES: Array[String] = ["knight", "paladin", "sorcerer", "druid"]
const TITLE: Color = Color("#ffcf6a")
const TEXT: Color = Color("#e8e4da")
const MUTED: Color = Color("#a7b0b8")
const HEALTH: Color = Color("#c0392b")

var game: Node
## The raid button (solo only), for tests.
var raid_button: Button
var _column: VBoxContainer
var _bars: Array[Control] = []
var _key: String = "-"


func _init() -> void:
	position = Layout.VIEW_ORIGIN + Vector2((Layout.VIEW_SIZE.x - WIDTH) / 2.0, 90)
	custom_minimum_size = Vector2(WIDTH, 0)
	theme = UiTheme.build()
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.05, 0.06, 0.08, 0.95)
	frame.border_color = Color("#6a5a3a")
	frame.set_border_width_all(2)
	frame.set_content_margin_all(12)
	frame.anti_aliasing = false
	add_theme_stylebox_override("panel", frame)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 6)
	add_child(_column)
	visible = false


func toggle() -> void:
	visible = not visible


func refresh() -> void:
	if not visible or not game.actors.has(game.self_id):
		return
	var key: String = _state_key()
	if key != _key:
		_key = key
		_rebuild()
	for bar: Control in _bars:
		bar.queue_redraw()
	# Wrapped labels settle their height a frame after a rebuild; shrink to fit them.
	if size.y > get_combined_minimum_size().y + 1.0:
		reset_size()


## The party's members, its leader first (just you without a party).
func members() -> Array[int]:
	var party: int = game.actors[game.self_id]["state"].get("party", 0)
	var result: Array[int] = []
	if party == 0:
		result.append(game.self_id)
		return result
	for id: int in game.actors:
		if game.actors[id]["state"].get("party", 0) == party:
			result.append(id)
	result.sort_custom(func(a: int, b: int) -> bool: return a == party or (b != party and a < b))
	return result


func _state_key() -> String:
	var state: Dictionary = game.actors[game.self_id]["state"]
	var named: Array = []
	for id: int in members() + Array(state.get("invites", [])) + Array(state.get("invited", [])):
		if game.actors.has(id):
			named.append([id, game.actors[id]["state"].get("level", 1), game.actors[id]["state"].get("vocation", "")])
	return str([named, state.get("party", 0), state.get("invites", []), state.get("invited", []), state.get("level", 1),
		game.solo_mode, game.solo.raiding if game.solo_mode and game.solo != null else false,
		[game.solo.party_plan, game.solo.slot_ids, game.solo.raid_plan] if game.solo_mode and game.solo != null else []])


func _rebuild() -> void:
	for child: Node in _column.get_children():
		_column.remove_child(child)
		child.queue_free()
	_bars.clear()
	raid_button = null
	var state: Dictionary = game.actors[game.self_id]["state"]
	var party: int = state.get("party", 0)
	var header := HBoxContainer.new()
	_column.add_child(header)
	var title: Label = _label("Party", 18, TITLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "Close"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(hide)
	header.add_child(close)
	if game.solo_mode:
		_column.add_child(_hint("Your companions follow you everywhere and share experience and loot. At level %d, gather a raid of %d for the final bosses." % [Balance.MAX_LEVEL, _raid_size()], 12, MUTED))
	elif party == 0:
		_column.add_child(_hint("You are not in a party. Right-click another player to invite them; party members share experience.", 12, MUTED))
	else:
		_column.add_child(_hint("Party members share experience. Right-click another player to invite them.", 12, MUTED))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	_column.add_child(grid)
	for id: int in members():
		var member: Dictionary = game.actors[id]["state"]
		var named: Label = _label(("★ " if id == party else "") + _name_of(id), 13, TITLE if id == game.self_id else TEXT)
		named.custom_minimum_size = Vector2(150, 0)
		named.autowrap_mode = TextServer.AUTOWRAP_OFF
		grid.add_child(named)
		var vocation: Label = _label("%s %d" % [Balance.profile_of(member.get("vocation", ""))["name"], member.get("level", 1)], 13, MUTED)
		vocation.autowrap_mode = TextServer.AUTOWRAP_OFF
		vocation.custom_minimum_size = Vector2(90, 0)
		grid.add_child(vocation)
		var bar := Control.new()
		bar.custom_minimum_size = Vector2(160, 14)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.draw.connect(_draw_health.bind(bar, id))
		grid.add_child(bar)
		_bars.append(bar)
		var slot: int = game.solo.slot_ids.find(id) if game.solo_mode else -1
		grid.add_child(_class_picker(slot) if slot >= 0 else Control.new())
	for leader: int in state.get("invites", []):
		if game.actors.has(leader) and party == 0:
			_row("%s invites you to their party." % _name_of(leader), "Join", func() -> void: game.party_local("join", leader))
	for invited: int in state.get("invited", []):
		if game.actors.has(invited):
			_row("You invited %s." % _name_of(invited), "Withdraw", func() -> void: game.party_local("revoke", invited))
	if game.solo_mode:
		var raiding: bool = game.solo.raiding
		_raid_plan(raiding)
		raid_button = Button.new()
		raid_button.text = "Disband the raid" if raiding else "Gather a raid (%d players)" % _raid_size()
		raid_button.focus_mode = Control.FOCUS_NONE
		var too_low: bool = state.get("level", 1) < Balance.MAX_LEVEL
		raid_button.disabled = not raiding and (too_low or game.solo.raid_size() != _raid_size())
		raid_button.tooltip_text = "Raids are for level %d: the final bosses need a full raid at the top." % Balance.MAX_LEVEL \
			if not raiding and too_low else ("Plan a raid of %d first." % _raid_size() if raid_button.disabled
			else "Send the raid home and keep your three companions." if raiding
			else "Fill your party to the planned raid (rival bands step aside).")
		raid_button.pressed.connect(func() -> void: game.raid_local(not raiding))
		_column.add_child(raid_button)
	elif party != 0:
		var leave := Button.new()
		leave.text = "Leave party"
		leave.focus_mode = Control.FOCUS_NONE
		leave.pressed.connect(func() -> void: game.party_local("leave", 0))
		_column.add_child(leave)


## A companion's class picker: choosing another class sends it home and brings one of that class.
func _class_picker(slot: int) -> OptionButton:
	var picker := OptionButton.new()
	picker.focus_mode = Control.FOCUS_NONE
	picker.add_theme_font_size_override("font_size", 12)
	for vocation: String in CLASSES:
		picker.add_item(Balance.VOCATIONS[vocation]["name"])
	picker.select(CLASSES.find(game.solo.party_plan[slot]))
	picker.disabled = game.solo.raiding
	picker.tooltip_text = "Disband the raid to change companions" if game.solo.raiding else "Swap this companion for another class"
	picker.item_selected.connect(func(index: int) -> void: game.companion_local(slot, CLASSES[index]))
	return picker


## The raid plan: a count per class with - and + (never below your party's own), and whether
## that raid can beat the final boss before it enrages.
func _raid_plan(raiding: bool) -> void:
	var plan: Dictionary = game.solo.raid_plan
	_column.add_child(_label("Raid plan  (%d / %d)" % [game.solo.raid_size(), _raid_size()], 14, TITLE))
	var row := GridContainer.new()
	row.columns = 6
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 4)
	_column.add_child(row)
	for vocation: String in CLASSES:
		var count: Label = _label("%s  %d" % [Balance.VOCATIONS[vocation]["name"], plan.get(vocation, 0)], 13, TEXT)
		count.autowrap_mode = TextServer.AUTOWRAP_OFF
		count.custom_minimum_size = Vector2(120, 0)
		row.add_child(count)
		for delta: int in [-1, 1]:
			var step := Button.new()
			step.text = "−" if delta < 0 else "+"
			step.focus_mode = Control.FOCUS_NONE
			step.disabled = raiding
			step.custom_minimum_size = Vector2(30, 0)
			step.pressed.connect(func() -> void: game.raid_plan_local(vocation, delta))
			row.add_child(step)
	var check: Dictionary = Balance.raid_check(plan)
	var verdict: String = "This raid beats the final boss in about %d:%02d." % [int(check["seconds"]) / 60, int(check["seconds"]) % 60] \
		if check["ok"] else "This raid falls short: %s." % ", ".join(check["reasons"])
	_column.add_child(_hint(verdict, 12, MUTED if check["ok"] else HEALTH.lightened(0.3)))


func _row(text: String, action: String, callback: Callable) -> void:
	var row := HBoxContainer.new()
	var info: Label = _label(text, 13, TEXT)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var button := Button.new()
	button.text = action
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	row.add_child(button)
	_column.add_child(row)


func _draw_health(bar: Control, id: int) -> void:
	if not game.actors.has(id):
		return
	var member: Dictionary = game.actors[id]["state"]
	var area := Rect2(Vector2.ZERO, bar.size)
	var share: float = clampf(float(member.get("health", 0)) / maxf(1.0, member.get("max_health", 1)), 0.0, 1.0)
	bar.draw_rect(area, Color(0, 0, 0, 0.6))
	bar.draw_rect(Rect2(Vector2.ZERO, Vector2(area.size.x * share, area.size.y)), HEALTH)
	bar.draw_rect(area, Color("#0b0e12"), false, 1.0)
	bar.draw_string(ThemeDB.fallback_font, Vector2(4, 11), "%d / %d" % [member.get("health", 0), member.get("max_health", 0)],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)


## A named bot's name, "You", or the player's class.
func _name_of(id: int) -> String:
	if id == game.self_id:
		return "You"
	var state: Dictionary = game.actors[id]["state"]
	if state.has("name"):
		return String(state["name"]).get_slice(" of ", 0)
	return "%s (player %d)" % [Balance.profile_of(state.get("vocation", ""))["name"], id]


func _raid_size() -> int:
	var total: int = 0
	for vocation: String in Balance.RAID:
		total += Balance.RAID[vocation]
	return total


func _hint(text: String, font_size: int, color: Color) -> Label:
	var label: Label = _label(text, font_size, color)
	label.custom_minimum_size = Vector2(WIDTH - 24, 0)
	return label


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
