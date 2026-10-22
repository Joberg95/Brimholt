extends Node
## The panel right of the game window: the paperdoll and backpack slots (drag-and-drop,
## right-click to equip, unequip, drink, eat, or deposit), three bag slots beside the paperdoll
## whose bags open in windows of their own (click a bag slot), the stat sheet, and item tooltips.
## Depot slots in the bank dialog are made here too (make_slot).

const World = preload("res://game/core/world.gd")
const SpriteArt = preload("res://game/render/sprite_art.gd")
const Balance = preload("res://game/data/balance.gd")
const Items = preload("res://game/data/items.gd")
const Combat = preload("res://game/core/combat.gd")
const Monsters = preload("res://game/data/monsters.gd")
const Professions = preload("res://game/data/professions.gd")
const Spells = preload("res://game/data/spells.gd")
const Quests = preload("res://game/data/quests.gd")
const Layout = preload("res://game/ui/layout.gd")
const ItemSlot = preload("res://game/ui/item_slot.gd")
const ItemTip = preload("res://game/ui/item_tip.gd")
const SLOT_STEP: float = 34.0
## Tibia-style paperdoll grid: necklace/helmet/pack, main hand/armor/off hand, ring/legs/ring, and boots.
const PAPERDOLL: Dictionary = {
	"necklace": Vector2(0, 0), "helmet": Vector2(1, 0), "bag": Vector2(2, 0),
	"main_hand": Vector2(0, 1), "armor": Vector2(1, 1), "off_hand": Vector2(2, 1),
	"ring_1": Vector2(0, 2), "legs": Vector2(1, 2), "ring_2": Vector2(2, 2),
	"boots": Vector2(1, 3),
}
const BACKPACK_COLUMNS: int = 5
## Size of the rarity notch in a slot's top-left corner, in pixels.
const NOTCH: float = 6.0
const LOCKED_TOOLTIP: String = "Locked: finish a town hunting task for a bigger pack"
const STAT_LABELS: Dictionary = {
	"health": "Health", "mana": "Mana", "attack": "Attack", "defense": "Defense", "magic_defense": "Magic def.", "critical": "Critical",
	"regen": "Regen", "healing": "Healing", "frost": "Frost damage",
	"speed": "Movement speed", "mana_percent": "Max mana", "leech": "Life leech",
}

var game: Node
var _backpack_label: Label
## One window per bag slot: a title and a grid of the bag's backpack slots, rebuilt when the
## backpack layout (pack size and worn bags) changes.
var bag_windows: Array[PanelContainer] = []
var _bag_titles: Array[Label] = []
var _bag_grids: Array[GridContainer] = []
var _bag_layout: String = ""
var _stat_values: Dictionary = {}
var _slots: Array[Control] = []


func build(game_node: Node, layer: CanvasLayer) -> void:
	game = game_node
	var frame := ColorRect.new()
	frame.color = Color("#151a20")
	frame.position = Layout.PANEL_ORIGIN - Vector2(8, 0)
	frame.size = Vector2(200, Layout.VIEW_SIZE.y)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(frame)
	_add_panel_label(layer, "Equipment", Layout.PANEL_ORIGIN + Vector2(0, 6))
	for slot: String in World.SLOTS:
		_add_slot(layer, {"type": "equipment", "slot": slot}, slot_position({"type": "equipment", "slot": slot}))
	_backpack_label = _add_panel_label(layer, "Backpack", Layout.PANEL_ORIGIN + Vector2(0, 166))
	for index: int in World.BACKPACK_MAX:
		_add_slot(layer, {"type": "backpack", "index": index}, slot_position({"type": "backpack", "index": index}))
	for bag: int in World.BAG_SLOTS:
		_add_slot(layer, {"type": "bag", "bag": bag}, slot_position({"type": "bag", "bag": bag}))
		_build_bag_window(layer)
	_build_stat_sheet(layer)


func _build_bag_window(layer: CanvasLayer) -> void:
	var window := PanelContainer.new()
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("#151a20f0")
	frame.border_color = Color("#6a5a3a")
	frame.set_border_width_all(1)
	frame.set_content_margin_all(6)
	frame.anti_aliasing = false
	window.add_theme_stylebox_override("panel", frame)
	window.visible = false
	var column := VBoxContainer.new()
	window.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 13)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(window.hide)
	header.add_child(close)
	var grid := GridContainer.new()
	grid.columns = BACKPACK_COLUMNS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	column.add_child(grid)
	layer.add_child(window)
	bag_windows.append(window)
	_bag_titles.append(title)
	_bag_grids.append(grid)


## Opens or closes the window of the bag in bag slot `bag` (nothing happens for an empty slot).
func toggle_bag(bag: int) -> void:
	if not game.actors.has(game.self_id) or String(game.actors[game.self_id]["state"].get("bags", ["", "", ""])[bag]).is_empty():
		return
	bag_windows[bag].visible = not bag_windows[bag].visible
	_place_bag_windows()


## Open bag windows stack down the right edge of the game window.
func _place_bag_windows() -> void:
	var top: float = Layout.VIEW_ORIGIN.y + 8
	for window: PanelContainer in bag_windows:
		if window.visible:
			window.reset_size()
			window.position = Vector2(Layout.VIEW_ORIGIN.x + Layout.VIEW_SIZE.x - window.size.x - 8, top)
			top += window.size.y + 6


## Per frame: rebuild bag windows when the layout changed, and keep their titles current.
func refresh_bags() -> void:
	var state: Dictionary = game.actors[game.self_id]["state"] if game.actors.has(game.self_id) else {}
	var bags: Array = state.get("bags", ["", "", ""])
	var layout: String = "%s|%s" % [World.main_size(state) if state.has("equipment") else 0, bags]
	if layout != _bag_layout:
		_bag_layout = layout
		for bag: int in World.BAG_SLOTS:
			for child: Node in _bag_grids[bag].get_children():
				_bag_grids[bag].remove_child(child)
				child.queue_free()
			if String(bags[bag]).is_empty():
				bag_windows[bag].hide()
				continue
			var region: Vector2i = World.bag_range(state, bag)
			for index: int in range(region.x, region.x + region.y):
				var slot: Control = make_slot({"type": "backpack", "index": index})
				slot.set_meta("in_bag", true)
				_bag_grids[bag].add_child(slot)
	_place_bag_windows()
	for bag: int in World.BAG_SLOTS:
		if bag_windows[bag].visible:
			var region: Vector2i = World.bag_range(state, bag)
			var used: int = state.get("backpack", []).slice(region.x, region.x + region.y).filter(
				func(entry: String) -> bool: return not entry.is_empty()).size()
			_bag_titles[bag].text = "%s  %d/%d" % [World.ITEMS[bags[bag]]["name"], used, region.y]


func slot_position(location: Dictionary) -> Vector2:
	if location["type"] == "equipment":
		return Layout.PANEL_ORIGIN + Vector2(40, 28) + PAPERDOLL[location["slot"]] * SLOT_STEP
	if location["type"] == "bag":
		return Layout.PANEL_ORIGIN + Vector2(40, 28) + Vector2(3.2, location["bag"]) * SLOT_STEP
	var index: int = location["index"]
	return Layout.PANEL_ORIGIN + Vector2(4, 186) + Vector2(index % BACKPACK_COLUMNS, index / BACKPACK_COLUMNS) * SLOT_STEP


## Main backpack slots you can use: 8, plus your pack's slots (bags have their own windows).
func capacity() -> int:
	if not game.actors.has(game.self_id):
		return World.BACKPACK_SIZE
	return World.main_size(game.actors[game.self_id]["state"])


## A main backpack slot beyond your pack's size (slots in bag windows are never locked).
func _locked(location: Dictionary, slot: Control = null) -> bool:
	return location["type"] == "backpack" and location["index"] >= capacity() and not (slot != null and slot.get_meta("in_bag", false))


## Per frame: refresh a slot only when its item or your level or vocation changed (tooltips
## and requirement colours), and keep relic slots redrawing for their glow pulse.
func redraw_slots() -> void:
	var state: Dictionary = game.actors[game.self_id]["state"] if game.actors.has(game.self_id) else {}
	var who: String = "%s/%s/%d" % [state.get("level", 0), state.get("vocation", ""), capacity()]
	var stale: bool = false
	for slot: Control in _slots:
		if not is_instance_valid(slot):
			stale = true
			continue
		var location: Dictionary = slot.get_meta("location")
		var entry: String = local_item(location)
		var kind: String = World.kind_of(entry)
		var key: String = entry + "|" + who
		if slot.get_meta("shown", "") != key:
			slot.set_meta("shown", key)
			slot.tooltip_text = LOCKED_TOOLTIP if _locked(location, slot) else item_tooltip(kind)
			if location["type"] == "bag" and kind.is_empty():
				slot.tooltip_text = "Bag slot: put a bag here; click it to open the bag"
			elif location["type"] == "bag":
				slot.tooltip_text += "\nClick to open or close it; empty it to take it off"
			var grade: Array = Items.rarity(World.ITEMS.get(kind, {})) if not _locked(location, slot) else []
			slot.rarity_color = grade[1] if not grade.is_empty() else Color.TRANSPARENT
			if World.count_of(entry) > 1:
				slot.tooltip_text += "\nStack of %d" % World.count_of(entry)
			slot.queue_redraw()
		elif World.ITEMS.has(kind) and (World.ITEMS[kind].has("glow") or SpriteArt.ANIMATED.has(kind) or potion_cooldown(kind) > 0.0):
			slot.queue_redraw()
	if stale:
		var alive: Array[Control] = []
		for slot: Variant in _slots:
			if is_instance_valid(slot):
				alive.append(slot)
		_slots = alive


func _build_stat_sheet(layer: CanvasLayer) -> void:
	_add_panel_label(layer, "Stats", Layout.PANEL_ORIGIN + Vector2(0, 322))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.position = Layout.PANEL_ORIGIN + Vector2(0, 342)
	grid.add_theme_constant_override("h_separation", 6)
	# Twelve rows must end above the minimap: lines sit a little closer than a label's own height.
	grid.add_theme_constant_override("v_separation", -1)
	layer.add_child(grid)
	for stat: String in ["vocation", "level", "experience", "gold"] + Array(Balance.STATS):
		var stat_label := Label.new()
		stat_label.text = {"vocation": "Class", "level": "Level", "experience": "Experience", "gold": "Gold"}.get(stat,
			STAT_LABELS.get(stat, stat))
		stat_label.modulate = Color("#a7b0b8")
		stat_label.add_theme_font_size_override("font_size", 12)
		grid.add_child(stat_label)
		var value := Label.new()
		value.add_theme_font_size_override("font_size", 12)
		grid.add_child(value)
		_stat_values[stat] = value


## The backpack count and the stat sheet, with gear bonuses over the base stats.
func update_stats() -> void:
	var actors: Dictionary = game.actors
	var self_id: int = game.self_id
	var carried: int = 0
	if actors.has(self_id):
		carried = capacity() - actors[self_id]["state"].get("backpack", []).slice(0, capacity()).count("")
	_backpack_label.text = "Backpack  %d/%d" % [carried, capacity()]
	if not actors.has(self_id):
		for value: Label in _stat_values.values():
			value.text = "-"
		return
	var state: Dictionary = actors[self_id]["state"]
	var level: int = state.get("level", 1)
	var vocation: String = state.get("vocation", Balance.DEFAULT_VOCATION)
	var stats: Dictionary = World.stats(level, state["equipment"], vocation)
	var base: Dictionary = Balance.base_stats(level, vocation)
	_stat_values["vocation"].text = Balance.profile_of(vocation)["name"]
	_stat_values["vocation"].tooltip_text = Balance.profile_of(vocation)["role"]
	_stat_values["vocation"].mouse_filter = Control.MOUSE_FILTER_PASS
	var next: int = Balance.experience_to_next(level)
	_stat_values["level"].text = "%d / %d" % [level, Balance.MAX_LEVEL]
	_stat_values["experience"].text = "%d / %d" % [state.get("experience", 0), next] if next > 0 else "max"
	_stat_values["gold"].text = str(state.get("gold", 0))
	for stat: String in Balance.STATS:
		var bonus: int = stats[stat] - base[stat]
		var text: String = str(stats[stat])
		if stat in ["health", "mana"] and state.has(stat):
			text = "%d / %d" % [state[stat], stats[stat]]
		if stat == "critical":
			text += "%"
		elif stat in ["defense", "magic_defense"]:
			text += " (-%d%%)" % (100 - Balance.damage_taken(100, stats[stat]))
		elif stat == "regen":
			text += " / 10 s"
		elif stat == "healing":
			text += " / s"
		if bonus != 0:
			text += " %+d" % bonus
		_stat_values[stat].text = text


## Why the local player cannot use an item (level or vocation), or "".
func requirement_for(kind: String) -> String:
	var actors: Dictionary = game.actors
	var self_id: int = game.self_id
	if not actors.has(self_id):
		return ""
	var state: Dictionary = actors[self_id]["state"]
	return World.requirement_error(kind, state.get("level", 1), state.get("vocation", Balance.DEFAULT_VOCATION))


## The boss whose quest rewards a relic.
func _relic_source(kind: String) -> String:
	var boss: String = Combat.relic_boss(kind)
	return Monsters.MONSTERS[boss]["name"] if not boss.is_empty() else "a final boss"


## Who pays a quest piece: "the Hunters' Lodge", or the boss task's title.
func _quest_source(quest: String) -> String:
	if quest == "hunters_lodge":
		return "the Hunters' Lodge"
	return Quests.TASKS[quest]["title"] if Quests.TASKS.has(quest) else "a quest"


func item_tooltip(kind: String) -> String:
	if not World.ITEMS.has(kind):
		return ""
	var item: Dictionary = World.ITEMS[kind]
	var lines: PackedStringArray = [item["name"]]
	var grade: Array = Items.rarity(item)
	if (item["slot"].is_empty() or item["slot"] in ["bag", "container"]) and not grade.is_empty():
		# Everything but gear and gold: the quality and what kind of thing it is.
		lines.append("%s %s" % [grade[0], _category(kind)])
	if not item["slot"].is_empty() and not item["slot"] in ["bag", "container"]:
		var who: String = "all classes"
		if not item["vocations"].is_empty():
			var names: PackedStringArray = []
			for vocation: String in item["vocations"]:
				names.append(Balance.VOCATIONS[vocation]["name"] + "s")
			who = " and ".join(names)
		if item.has("glow"):
			lines.append("Relic %s  ·  level %d+  ·  %s" % [item["slot"].capitalize().to_lower(), item["level"], who])
			lines.append("Quest reward for slaying %s; bound to you (never dropped or lost)" % _relic_source(kind))
		else:
			var slot_name: String = item["slot"].capitalize().to_lower()
			lines.append("%s  ·  tier %d  ·  level %d+  ·  %s" % [
				"%s %s" % [grade[0], slot_name] if not grade.is_empty() else slot_name.capitalize(), item["level"], item["level"], who])
	for stat: String in item["stats"]:
		lines.append("%+d%s %s" % [item["stats"][stat], "%" if stat in ["critical"] + World.GEAR_STATS else "", STAT_LABELS[stat]])
	if not item["slot"].is_empty() and not World.is_bag(kind):
		var refused: String = requirement_for(kind)
		if not refused.is_empty():
			lines.append("✗ " + refused)
	if item.has("quest"):
		lines.append("Quest reward (%s); bound to you (never dropped or lost)" % _quest_source(item["quest"]))
	if item.has("gold"):
		lines.append("Worth %d gold; picked up into your purse" % item["gold"])
	if item.has("rune"):
		lines.append(Spells.rune_text(item))
	if item.get("loot_only", false) or Items.mythic(item):
		var sources: PackedStringArray = []
		for monster: String in Monsters.LOOT:
			for entry: Array in Monsters.LOOT[monster]:
				if entry[0] == kind:
					sources.append(Monsters.MONSTERS[monster]["name"])
		lines.append("%s drop: %s" % ["Mythic" if Items.mythic(item) else "Hunting", ", ".join(sources)])
	var gathered: String = ""
	for profession: String in Professions.RESOURCES:
		var band: int = Professions.RESOURCES[profession].find(kind)
		if band >= 0:
			gathered = "Gathered with %s %d in lands of level %d+; vendors buy it for %d gold" % [Professions.NAMES[profession],
				Professions.BAND_LEVELS[band], Professions.BAND_LEVELS[band], item["value"]]
	if not gathered.is_empty():
		lines.append(gathered)
	elif item.has("value"):
		lines.append("Vendors buy it for %d gold" % item["value"])
	if item.has("eat"):
		lines.append("+%d%% health and mana regeneration for %d minutes" % [roundi(item["eat"]["regen"] * 100.0),
			roundi(item["eat"]["seconds"] / 60.0)])
		lines.append("Right-click to eat (replaces your last meal)")
	if item.has("drink"):
		for stat: String in item["drink"]:
			lines.append("Restores %d%% of your maximum %s" % [roundi(item["drink"][stat] * 100.0), stat])
		var key: String = game.keybinds.label(item["timer"])
		lines.append("Right-click%s to drink  ·  %d s cooldown" % ["" if key.is_empty() else " or press " + key, roundi(item["cooldown"])])
	if World.is_bag(kind):
		lines.append("Bag: holds %d items. Put it in a bag slot beside your equipment, then click the slot to open it" % item["slots"])
	elif item.has("slots"):
		lines.append("+%d backpack slots  ·  bound to you" % item["slots"])
	elif item.get("sell", 0) > 0 and not item.has("value"):
		lines.append("Vendors buy it for %d gold" % item["sell"])
	return "\n".join(lines)


## What a non-gear item is, for its quality line: "Rare material", "Common potion" ...
func _category(kind: String) -> String:
	var item: Dictionary = World.ITEMS[kind]
	for profession: String in Professions.RESOURCES:
		if kind in Professions.RESOURCES[profession]:
			return "%s resource" % Professions.NAMES[profession].to_lower()
	if item.has("drink"):
		return "potion"
	if item.has("eat"):
		return "food"
	if item["slot"] == "container":
		return "bag"
	if item["slot"] == "bag":
		return "pack"
	return "material"


## Gives `content` a coloured item tooltip (ItemTip): a wrapper takes its place in its parent,
## if it has one, and is returned so callers can add it themselves otherwise.
func tip(content: Control, kind: String) -> Control:
	var wrapper := ItemTip.new()
	wrapper.tooltip_text = item_tooltip(kind)
	var grade: Array = Items.rarity(World.ITEMS.get(kind, {}))
	wrapper.rarity_color = grade[1] if not grade.is_empty() else Color.TRANSPARENT
	wrapper.size_flags_horizontal = content.size_flags_horizontal
	wrapper.size_flags_vertical = content.size_flags_vertical
	content.tooltip_text = ""
	var parent: Node = content.get_parent()
	if parent != null:
		var index: int = content.get_index()
		parent.remove_child(content)
		parent.add_child(wrapper)
		parent.move_child(wrapper, index)
	wrapper.add_child(content)
	return wrapper


func _add_panel_label(layer: CanvasLayer, text: String, at: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	layer.add_child(label)
	return label


func _add_slot(layer: CanvasLayer, location: Dictionary, at: Vector2) -> void:
	var slot: Control = make_slot(location)
	slot.position = at
	layer.add_child(slot)


## A drag-and-drop item slot for a location; freed slots are dropped from the redraw list.
func make_slot(location: Dictionary) -> Control:
	var slot := ItemSlot.new()
	slot.size = Vector2.ONE * Layout.SLOT_SIZE
	slot.custom_minimum_size = slot.size
	slot.set_meta("location", location)
	slot.draw.connect(_draw_slot.bind(slot, location))
	slot.gui_input.connect(slot_input.bind(location))
	slot.set_drag_forwarding(item_drag.bind(slot, location), item_can_drop.bind(location, slot), item_drop.bind(location, slot))
	_slots.append(slot)
	return slot


## The entry ("kind" or "kind#count") at an equipment, backpack, or ground location as this
## client sees it, or "".
func local_item(location: Dictionary) -> String:
	if location["type"] == "ground":
		var stack: Array = game.ground_view.get(location["cell"], [])
		return stack.back() if not stack.is_empty() else ""
	var actors: Dictionary = game.actors
	var self_id: int = game.self_id
	if not actors.has(self_id):
		return ""
	var state: Dictionary = actors[self_id]["state"]
	if location["type"] == "equipment":
		return state["equipment"].get(location["slot"], "")
	if location["type"] == "bag":
		return state.get("bags", ["", "", ""])[location["bag"]]
	var backpack: Array = state.get(location["type"], [])
	return backpack[location["index"]] if location["index"] < backpack.size() else ""


## The item's rarity as a small triangle in the slot's top-left corner, in its rarity colour
## (Items.RARITIES; relics in their glow), with a dark edge so it reads over any icon.
func _draw_rarity_notch(slot: Control, item: Dictionary) -> void:
	var grade: Array = Items.rarity(item)
	if grade.is_empty():
		return
	var notch := PackedVector2Array([Vector2(1, 1), Vector2(1 + NOTCH, 1), Vector2(1, 1 + NOTCH)])
	slot.draw_colored_polygon(notch, grade[1])
	slot.draw_line(Vector2(1 + NOTCH, 1), Vector2(1, 1 + NOTCH), Color("#0b0e12"), 1.0)


func _draw_slot(slot: Control, location: Dictionary) -> void:
	if _locked(location, slot):
		slot.draw_rect(Rect2(Vector2.ZERO, slot.size), Color("#171c22"))
		slot.draw_rect(Rect2(Vector2(-1, -1), slot.size + Vector2(2, 2)), Color("#0b0e12"), false, 1.0)
		return
	slot.draw_rect(Rect2(Vector2.ZERO, slot.size), Color("#232a33"))
	slot.draw_rect(Rect2(Vector2(-1, -1), slot.size + Vector2(2, 2)), Color("#0b0e12"), false, 1.0)
	slot.draw_rect(Rect2(Vector2.ZERO, Vector2(slot.size.x, 1)), Color("#3a4450"))
	slot.draw_rect(Rect2(Vector2.ZERO, Vector2(1, slot.size.y)), Color("#3a4450"))
	var entry: String = local_item(location)
	var kind: String = World.kind_of(entry)
	if not kind.is_empty():
		var item: Dictionary = World.ITEMS.get(kind, {})
		var usable: bool = item.get("slot", "").is_empty() or requirement_for(kind).is_empty()
		var now: float = game._now()
		SpriteArt.draw_item_glow(slot, slot.size / 2.0, kind, 0.6 + 0.25 * sin(now * 2.6))
		# An item you cannot use yet is tinted red.
		SpriteArt.draw_item(slot, slot.size / 2.0, kind, Color.WHITE if usable else Color(1.0, 0.55, 0.55), slot.size.x,
			World.count_of(entry))
		_draw_rarity_notch(slot, item)
		var cooling: float = potion_cooldown(kind)
		if cooling > 0.0:
			# Shade the part of the potion still cooling down, draining from the top.
			var share: float = clampf(cooling / item["cooldown"], 0.0, 1.0)
			slot.draw_rect(Rect2(Vector2(0, slot.size.y * (1.0 - share)), Vector2(slot.size.x, slot.size.y * share)), Color(0, 0, 0, 0.6))
		if World.count_of(entry) > 1:
			SpriteArt.draw_count(slot, slot.size - Vector2(3, 3), World.count_of(entry))
	elif location["type"] == "equipment":
		SpriteArt.draw_slot_hint(slot, slot.size / 2.0, location["slot"], slot.size.x)
	elif location["type"] == "bag":
		SpriteArt.draw_item(slot, slot.size / 2.0, "leather_satchel", Color(0, 0, 0, 0.35), slot.size.x)
	if location["type"] == "bag" and bag_windows.size() > location["bag"] and bag_windows[location["bag"]].visible:
		slot.draw_rect(Rect2(Vector2.ZERO, slot.size), Color("#ffcf6a"), false, 1.0)


## Seconds until you can drink another potion of `kind` (0 when ready or not a potion).
func potion_cooldown(kind: String) -> float:
	if not World.ITEMS.get(kind, {}).has("drink") or not game.actors.has(game.self_id):
		return 0.0
	var view: Dictionary = game.actors[game.self_id]
	var left: float = view["state"].get("cooldowns", {}).get(Combat.potion_timer(kind), 0.0)
	return maxf(0.0, left - (game._now() - view.get("received", game._now())))


func item_drag(_at: Vector2, source: Control, location: Dictionary) -> Variant:
	var kind: String = World.kind_of(local_item(location))
	if not game.connected or kind.is_empty():
		return null
	var preview := Control.new()
	preview.draw.connect(func() -> void: SpriteArt.draw_item(preview, Vector2.ZERO, kind))
	source.set_drag_preview(preview)
	return {"brimholt_item": location}


func item_can_drop(_at: Vector2, data: Variant, target: Dictionary, slot: Control = null) -> bool:
	return game.connected and typeof(data) == TYPE_DICTIONARY and data.has("brimholt_item") \
		and data["brimholt_item"] != target and not _locked(target, slot)


## Dropping on a bag slot wears a bag there, or puts any other item into that bag.
func item_drop(at: Vector2, data: Variant, target: Dictionary, slot: Control = null) -> void:
	if not item_can_drop(at, data, target, slot):
		return
	var kind: String = World.kind_of(local_item(data["brimholt_item"]))
	if target["type"] == "bag" and not World.is_bag(kind) and game.actors.has(game.self_id):
		var state: Dictionary = game.actors[game.self_id]["state"]
		var region: Vector2i = World.bag_range(state, target["bag"])
		var backpack: Array = state.get("backpack", [])
		for index: int in range(region.x, region.x + region.y):
			if backpack[index].is_empty():
				game.move_item_local(data["brimholt_item"], {"type": "backpack", "index": index})
				return
		game.last_action_message = "That bag is full" if region.y > 0 else "Put a bag in that slot first"
		return
	game.move_item_local(data["brimholt_item"], target)


## Right-click: unequip or pick up into the backpack, or equip from the backpack. Click a bag
## slot to open its bag.
func slot_input(event: InputEvent, location: Dictionary) -> void:
	if location["type"] == "bag" and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		toggle_bag(location["bag"])
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		return
	var kind: String = World.kind_of(local_item(location))
	if kind.is_empty():
		return
	if location["type"] != "backpack":
		game.move_item_local(location, {"type": "backpack"})
	elif game.dialogs.banking():
		game.move_item_local(location, {"type": "depot"})
	elif World.ITEMS[kind].has("drink") or World.ITEMS[kind].has("eat"):
		game.drink_local(location["index"])
	elif World.is_bag(kind) and game.actors.has(game.self_id):
		var bags: Array = game.actors[game.self_id]["state"].get("bags", ["", "", ""])
		if bags.has(""):
			game.move_item_local(location, {"type": "bag", "bag": bags.find("")})
	elif game.actors.has(game.self_id):
		var slot: String = World.slot_for(kind, game.actors[game.self_id]["state"]["equipment"])
		if not slot.is_empty():
			game.move_item_local(location, {"type": "equipment", "slot": slot})
