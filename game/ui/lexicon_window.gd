extends PanelContainer
## The Lexicon (Keybinds "lexicon", K by default): every monster, lowest level first, with a
## search over names, places, and drops. The selected monster shows its picture, rank and
## levels, where it lives, the tasks it counts toward, and its drop table (Lexicon.entries):
## each drop's chance and what a vendor pays, plus gold, tier gear, and a boss's relics.

const World = preload("res://game/core/world.gd")
const Items = preload("res://game/data/items.gd")
const Lexicon = preload("res://game/core/lexicon.gd")
const Quests = preload("res://game/data/quests.gd")
const Layout = preload("res://game/ui/layout.gd")
const SpriteArt = preload("res://game/render/sprite_art.gd")
const NpcDialogs = preload("res://game/ui/npc_dialogs.gd")

const SIZE: Vector2 = Vector2(900, 640)
const TITLE: Color = Color("#ffcf6a")
const TEXT: Color = Color("#e8e4da")
const MUTED: Color = Color("#a7b0b8")
const RANK_COLORS: Dictionary = {"normal": Color("#e8e4da"), "elite": Color("#8fd0ff"), "champion": Color("#ffb060"),
	"boss": Color("#ff6a5a")}

var game: Node
var search: LineEdit
var list: ItemList
var _details: VBoxContainer
var _shown: Array[Dictionary] = []
var _selected: String = ""


func _init() -> void:
	position = Layout.VIEW_ORIGIN + (Layout.VIEW_SIZE - SIZE) / 2.0
	size = SIZE
	custom_minimum_size = SIZE
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.05, 0.06, 0.08, 0.96)
	frame.border_color = Color("#6a5a3a")
	frame.set_border_width_all(2)
	frame.set_content_margin_all(12)
	frame.anti_aliasing = false
	add_theme_stylebox_override("panel", frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := _label("Lexicon", 18, TITLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "Close"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(hide)
	header.add_child(close)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	column.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(270, 0)
	body.add_child(left)
	search = LineEdit.new()
	search.placeholder_text = "Search monsters, places, or drops"
	search.clear_button_enabled = true
	search.text_changed.connect(func(_text: String) -> void: _fill_list())
	left.add_child(search)
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.focus_mode = Control.FOCUS_NONE
	list.item_selected.connect(func(index: int) -> void: select(_shown[index]["kind"]))
	left.add_child(list)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_details = VBoxContainer.new()
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.add_theme_constant_override("separation", 4)
	scroll.add_child(_details)
	visible = false
	visibility_changed.connect(func() -> void:
		if visible and list.item_count == 0:
			_fill_list()
		if not visible:
			search.release_focus())


func toggle() -> void:
	visible = not visible


## Lists the monsters matching the search, keeping the selection when it still matches.
func _fill_list() -> void:
	list.clear()
	_shown.clear()
	for found: Dictionary in Lexicon.entries():
		if not Lexicon.matches(found, search.text):
			continue
		_shown.append(found)
		var levels: Vector2i = found["levels"]
		var band: String = "%d" % levels.x if levels.x == levels.y else "%d–%d" % [levels.x, levels.y]
		var index: int = list.add_item("%s   lv %s" % [found["name"], band])
		list.set_item_custom_fg_color(index, RANK_COLORS[found["rank"]])
	var keep: int = _shown.map(func(found: Dictionary) -> String: return found["kind"]).find(_selected)
	if keep < 0 and not _shown.is_empty():
		keep = 0
	if keep >= 0:
		list.select(keep)
		select(_shown[keep]["kind"])
	else:
		_clear_details()
		_details.add_child(_label("Nothing matches \"%s\"." % search.text, 13, MUTED))


func select(kind: String) -> void:
	_selected = kind
	_clear_details()
	var found: Dictionary = Lexicon.entry(kind)
	for cached: Dictionary in Lexicon.entries():
		if cached["kind"] == kind:
			found = cached
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	_details.add_child(top)
	var portrait := Control.new()
	portrait.custom_minimum_size = Vector2(96, 96)
	var figure := Node2D.new()
	figure.scale = Vector2(1.5, 1.5)
	figure.position = Vector2(48, 44)
	figure.draw.connect(func() -> void:
		SpriteArt.draw_monster(figure, Vector2.ZERO, {"kind": kind, "facing": Vector2i.DOWN}, 0.0))
	portrait.add_child(figure)
	top.add_child(portrait)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(heading)
	heading.add_child(_label(found["name"], 20, RANK_COLORS[found["rank"]]))
	var levels: Vector2i = found["levels"]
	heading.add_child(_label("%s · level %s" % [String(found["rank"]).capitalize(),
		"%d" % levels.x if levels.x == levels.y else "%d–%d" % [levels.x, levels.y]], 13, MUTED))
	_section("Found in")
	_details.add_child(_label(", ".join(found["places"]) if not found["places"].is_empty() else "Nowhere yet", 13, TEXT))
	if not found["tasks"].is_empty():
		_section("Counts toward")
		for task: String in found["tasks"]:
			var giver: Dictionary = World.QUEST_GIVERS.get(Quests.TASKS[task]["giver"], {"name": "?", "place": "?"})
			_details.add_child(_label("%s — %s, %s" % [Quests.TASKS[task]["title"], giver["name"], giver["place"]], 13, TEXT))
	_section("Drops")
	for drop: Array in found["drops"]:
		_drop_row(drop[0], "%s%%" % _percent(float(drop[1])))
	if found["gold"] > 0:
		_drop_row("gold_coins", "about %d gold" % found["gold"])
	if not found.get("valuables", []).is_empty():
		_details.add_child(_label("Gems worth about %d gold a kill on average:" % found["valuable_gold"], 13, TEXT))
		for gem: String in found["valuables"]:
			_drop_row(gem, "sells for %d" % World.ITEMS[gem]["value"])
	if found["gear"] > 0.0:
		var tiers: Vector2i = found["gear_tiers"]
		_details.add_child(_label("%s%% chance of tier-%s gear (any slot)" % [_percent(found["gear"]),
			"%d" % tiers.x if tiers.x == tiers.y else "%d to %d" % [tiers.x, tiers.y]], 13, TEXT))
	if not found["relics"].is_empty():
		_section("Relics (trade its trophy at its relic keeper)")
		for relic: String in found["relics"]:
			_drop_row(relic, "quest reward")


func _drop_row(kind: String, chance: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var icon := TextureRect.new()
	icon.texture = NpcDialogs.icon(kind)
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var item: Dictionary = World.ITEMS[kind]
	var grade: Array = Items.rarity(item)
	var name_label := _label(item["name"], 13, grade[1] if not grade.is_empty() else TEXT)
	name_label.custom_minimum_size = Vector2(220, 0)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)
	var chance_label := _label(chance, 13, TITLE)
	chance_label.custom_minimum_size = Vector2(110, 0)
	chance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(chance_label)
	var sells: int = int(item.get("sell", 0))
	if sells > 0 and kind != "gold_coins":
		var value := _label("sells for %d" % sells, 12, MUTED)
		value.autowrap_mode = TextServer.AUTOWRAP_OFF
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(value)
	_details.add_child(row)
	game.inventory.tip(row, kind)


func _section(text: String) -> void:
	var label := _label(text, 14, TITLE)
	label.custom_minimum_size = Vector2(0, 26)
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_details.add_child(label)


func _clear_details() -> void:
	for child: Node in _details.get_children():
		_details.remove_child(child)
		child.queue_free()


static func _percent(chance: float) -> String:
	return ("%.1f" % (chance * 100.0)).trim_suffix(".0")


func _label(content: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
