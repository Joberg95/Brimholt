extends Node
## Right-click menus and the shared dialog panel: an NPC's services (Travel, Trade, Bank,
## Quests), a ferryman's routes and fares, a vendor's stock, the banker's gold and depot,
## hunting tasks, the Relic keeper's quests, and party options for players. Trade, bank,
## and quest dialogs rebuild when your gold, items, or task progress change.

const World = preload("res://game/core/world.gd")
const Balance = preload("res://game/data/balance.gd")
const Monsters = preload("res://game/data/monsters.gd")
const Quests = preload("res://game/data/quests.gd")
const Spells = preload("res://game/data/spells.gd")
const Economy = preload("res://game/core/economy.gd")
const SpriteArt = preload("res://game/render/sprite_art.gd")
const Layout = preload("res://game/ui/layout.gd")
const NPC_SERVICES: Dictionary = {"travel": "Travel", "trade": "Trade", "bank": "Bank", "quests": "Quests", "vocation": "Vocation"}
const DEPOT_COLUMNS: int = 8
const PARTY_LABELS: Dictionary = {"invite": "Invite to party", "revoke": "Withdraw invitation",
	"join": "Join party", "leave": "Leave party"}

var game: Node
## The dialog panel (travel routes or quests) and its rows.
var panel: PanelContainer
var list: VBoxContainer
## The NPC whose dialog is open, or "".
var talking_to: String = ""
## The open dialog: "travel", "trade", "bank", "quests", or "vocation".
var mode: String = ""
var _shown_state: String = ""
var _bank_amount: int = 100
var npc_menu: PopupMenu
var npc_menu_target: String = ""
var _player_menu: PopupMenu
var _player_menu_target: int = 0


func build(game_node: Node, layer: CanvasLayer) -> void:
	game = game_node
	panel = PanelContainer.new()
	panel.visible = false
	panel.position = Layout.VIEW_ORIGIN + Vector2(Layout.VIEW_SIZE.x / 2.0 - 150, 120)
	panel.custom_minimum_size = Vector2(300, 0)
	var backdrop := StyleBoxFlat.new()
	backdrop.bg_color = Color("#151a20f0")
	backdrop.border_color = Color("#3a4450")
	backdrop.set_border_width_all(1)
	backdrop.set_content_margin_all(10)
	backdrop.set_corner_radius_all(3)
	# Anti-aliased edges draw a blurred halo around the box; pixel art wants crisp edges.
	backdrop.anti_aliasing = false
	panel.add_theme_stylebox_override("panel", backdrop)
	list = VBoxContainer.new()
	panel.add_child(list)
	layer.add_child(panel)
	npc_menu = PopupMenu.new()
	npc_menu.id_pressed.connect(_npc_service_chosen)
	add_child(npc_menu)
	_player_menu = PopupMenu.new()
	_player_menu.id_pressed.connect(func(index: int) -> void:
		var action: String = _player_menu.get_item_metadata(_player_menu.get_item_index(index))
		game.party_local(action, 0 if action == "leave" else _player_menu_target))
	add_child(_player_menu)


## Per frame: closes the dialog once you walk out of talking range.
func refresh() -> void:
	var actors: Dictionary = game.actors
	var self_id: int = game.self_id
	if not talking_to.is_empty() and (not actors.has(self_id) or not World.in_talk_range(
			actors[self_id]["state"]["cell"], World.npc(talking_to)["cell"])):
		close()
	elif not talking_to.is_empty() and mode in ["trade", "bank", "quests", "vocation"] and _state_key() != _shown_state:
		_open(mode, talking_to)


func close() -> void:
	talking_to = ""
	mode = ""
	panel.hide()


## Whether the bank dialog (and so the depot) is open.
func banking() -> bool:
	return mode == "bank" and not talking_to.is_empty()


func _state_key() -> String:
	var actors: Dictionary = game.actors
	if not actors.has(game.self_id):
		return ""
	var state: Dictionary = actors[game.self_id]["state"]
	return str([state.get("gold"), state.get("bank"), state.get("backpack"), state.get("tasks"), state.get("done_tasks"),
		state.get("trophies"), state.get("level"), state["equipment"].get("bag"), state.get("vocation")])


func _open(kind: String, npc: String) -> void:
	match kind:
		"trade":
			open_trade(npc)
		"bank":
			open_bank(npc)
		"quests":
			open_quests(npc)
		"vocation":
			open_vocation(npc)


## Right-clicking a person opens their services; there is no typed dialogue.
func open_npc_menu(npc: String, at: Vector2i) -> void:
	if World.npc(npc).is_empty():
		return
	npc_menu.clear()
	npc_menu.add_separator(World.npc(npc)["name"])
	var services: Array = World.npc(npc)["services"]
	for index: int in services.size():
		npc_menu.add_item(NPC_SERVICES.get(services[index], String(services[index]).capitalize()), index)
		npc_menu.set_item_metadata(npc_menu.get_item_index(index), services[index])
	npc_menu_target = npc
	npc_menu.popup(Rect2i(at, Vector2i.ZERO))


func _npc_service_chosen(id: int) -> void:
	var service: Variant = npc_menu.get_item_metadata(npc_menu.get_item_index(id))
	if service == "travel":
		talk_to(npc_menu_target)
	elif service in ["trade", "bank", "quests", "vocation"]:
		_open(service, npc_menu_target)


## Whether your character stands on (or just below) a clicked cell.
func is_self_at(cell: Vector2i) -> bool:
	var actors: Dictionary = game.actors
	var self_id: int = game.self_id
	if not actors.has(self_id):
		return false
	var at: Vector2i = Vector2i(actors[self_id]["visual"].round())
	return cell == at or cell == at + Vector2i.DOWN


## Party options for a player you right-click (yourself: leave). Empty when there are none.
func party_options(person: int) -> Array[String]:
	var actors: Dictionary = game.actors
	var self_id: int = game.self_id
	var options: Array[String] = []
	if not actors.has(self_id) or not actors.has(person):
		return options
	var mine: Dictionary = actors[self_id]["state"]
	var theirs: Dictionary = actors[person]["state"]
	var my_party: int = mine.get("party", 0)
	if person == self_id:
		if my_party != 0:
			options.append("leave")
		return options
	if person in mine.get("invites", []) and my_party == 0:
		options.append("join")
	elif theirs.get("party", 0) == 0 and (my_party == 0 or my_party == self_id):
		options.append("revoke" if person in mine.get("invited", []) else "invite")
	if my_party != 0 and theirs.get("party", 0) == my_party:
		options.append("leave")
	return options


func open_player_menu(person: int, at: Vector2i) -> bool:
	var options: Array[String] = party_options(person)
	if options.is_empty():
		return false
	var state: Dictionary = game.actors[person]["state"]
	_player_menu.clear()
	_player_menu.add_separator("You" if person == game.self_id else "%s %d" % [
		Balance.VOCATIONS.get(state.get("vocation", ""), {"name": "Player"})["name"], state.get("level", 1)])
	for index: int in options.size():
		_player_menu.add_item(PARTY_LABELS[options[index]], index)
		_player_menu.set_item_metadata(_player_menu.get_item_index(index), options[index])
	_player_menu_target = person
	_player_menu.popup(Rect2i(at, Vector2i.ZERO))
	return true


## Opens a ferryman's routes and fares when you stand within range.
func talk_to(ferryman: String) -> void:
	var actors: Dictionary = game.actors
	var self_id: int = game.self_id
	if not actors.has(self_id) or not World.FERRYMEN.has(ferryman):
		return
	var npc: Dictionary = World.FERRYMEN[ferryman]
	if not World.in_talk_range(actors[self_id]["state"]["cell"], npc["cell"]):
		game.last_action_message = "Walk closer to %s." % npc["name"]
		return
	for child: Node in list.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "%s, %s\n\"Where can I take you?\"" % [npc["name"], npc["place"]]
	list.add_child(title)
	var gold: int = actors[self_id]["state"].get("gold", 0)
	for destination: String in npc["routes"]:
		var fare: int = npc["routes"][destination]
		var button := Button.new()
		button.text = "%s  —  %d gold" % [World.FERRYMEN[destination]["place"], fare]
		button.disabled = gold < fare
		button.pressed.connect(func() -> void:
			game.travel_local(ferryman, destination)
			close())
		list.add_child(button)
	var farewell := Button.new()
	farewell.text = "Not today"
	farewell.pressed.connect(close)
	list.add_child(farewell)
	_show(ferryman, "travel")


## Clears the dialog for a new page; false (with a hint) when you are out of range.
func _begin(npc: String) -> bool:
	var actors: Dictionary = game.actors
	var self_id: int = game.self_id
	if not actors.has(self_id) or World.npc(npc).is_empty():
		return false
	if not World.in_talk_range(actors[self_id]["state"]["cell"], World.npc(npc)["cell"]):
		game.last_action_message = "Walk closer to %s." % World.npc(npc)["name"]
		return false
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()
	return true


func _show(npc: String, kind: String) -> void:
	talking_to = npc
	mode = kind
	_shown_state = _state_key()
	panel.reset_size()
	panel.show()


func _label(text: String, color: Color = Color.TRANSPARENT) -> Label:
	var label := Label.new()
	label.text = text
	if color.a > 0.0:
		label.add_theme_color_override("font_color", color)
	list.add_child(label)
	return label


func _button(text: String, enabled: bool, action: Callable, parent: Node = null) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	(list if parent == null else parent).add_child(button)
	return button


func _farewell(text: String = "Farewell") -> void:
	_button(text, true, close)


static func icon(kind: String) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = SpriteArt.ITEM_ICONS
	texture.region = SpriteArt.item_region(kind)
	return texture


## A vocation trainer: what the vocation does, what choosing needs (the trial and a level), and
## the permanent choice. Other vocations hear that they already have one.
func open_vocation(npc: String) -> void:
	if not _begin(npc) or not Quests.TRAINERS.has(npc):
		return
	var trainer: Dictionary = World.npc(npc)
	var vocation: String = Quests.TRAINERS[npc][0]
	var profile: Dictionary = Balance.VOCATIONS[vocation]
	var state: Dictionary = game.actors[game.self_id]["state"]
	_wrapped("%s, %s trainer\n\"%s\"" % [trainer["name"], profile["name"], Quests.TRAINERS[npc][1]])
	var spells: PackedStringArray = []
	for spell: String in Spells.for_vocation(vocation):
		spells.append("%s (%d)" % [Spells.SPELLS[spell]["name"], Spells.SPELLS[spell]["level"]])
	_wrapped("Role: %s. Health ×%s, mana ×%s, damage ×%s.\nSpells: %s." % [profile["role"], Spells.number(profile["health"]),
		Spells.number(profile["mana"]), Spells.number(profile["damage"]), ", ".join(spells)], Color("#a7b0b8"))
	if state.get("vocation", "") != Balance.ADVENTURER:
		_label("You are already a %s; a vocation is for life." % Balance.profile_of(state.get("vocation", ""))["name"], Color("#a7b0b8"))
		_farewell()
		_show(npc, "vocation")
		return
	var trial: String = Quests.TASKS[Quests.TRIAL_TASK]["title"]
	var passed: bool = Quests.TRIAL_TASK in state.get("done_tasks", [])
	var levelled: bool = state.get("level", 1) >= Balance.CHOOSE_LEVEL
	_label("%s %s" % ["✓" if passed else "✗", "Passed %s" % trial if passed else "Pass %s (Master Hesk, outside the hall)" % trial],
		Color("#9fe07a") if passed else Color("#e05a4a"))
	_label("%s Level %d or higher" % ["✓" if levelled else "✗", Balance.CHOOSE_LEVEL], Color("#9fe07a") if levelled else Color("#e05a4a"))
	_label("The choice is permanent. You receive the %s's starting weapon and off-hand." % profile["name"], Color("#ffcf6a"))
	_button("Become a %s" % profile["name"], passed and levelled, func() -> void: game.vocation_local(npc))
	_farewell()
	_show(npc, "vocation")


func _wrapped(text: String, color: Color = Color.TRANSPARENT) -> Label:
	var label: Label = _label(text, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 460
	return label


## A vendor: buy potions and levelling gear for your vocation, and sell loot.
func open_trade(npc: String) -> void:
	if not _begin(npc):
		return
	var vendor: Dictionary = World.npc(npc)
	var state: Dictionary = game.actors[game.self_id]["state"]
	var gold: int = state.get("gold", 0)
	var vocation: String = state.get("vocation", Balance.DEFAULT_VOCATION)
	_label("%s, %s\n\"Potions and gear for the road.\"" % [vendor["name"], vendor["place"]])
	_label("Your gold: %d" % gold, Color("#ffcf6a"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	var heading := Label.new()
	heading.text = "Buy"
	rows.add_child(heading)
	for kind: String in Economy.stock():
		var item: Dictionary = World.ITEMS[kind]
		if not item["vocations"].is_empty() and vocation not in item["vocations"]:
			continue
		var row := HBoxContainer.new()
		rows.add_child(row)
		var item_label := Label.new()
		item_label.text = "%s  %d gold" % [item["name"], item["price"]] if World.stackable(kind) \
			else "%s (level %d)  %d gold" % [item["name"], item["level"], item["price"]]
		item_label.tooltip_text = game.inventory.item_tooltip(kind)
		item_label.mouse_filter = Control.MOUSE_FILTER_PASS
		item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(item_label)
		var picture := TextureRect.new()
		picture.texture = icon(kind)
		row.add_child(picture)
		row.move_child(picture, 0)
		for count: int in ([1, 10] if World.stackable(kind) else [1]):
			_button("Buy %d" % count if World.stackable(kind) else "Buy", gold >= item["price"] * count,
				func() -> void: game.buy_local(npc, kind, count), row)
	var sell_heading := Label.new()
	sell_heading.text = "Sell"
	rows.add_child(sell_heading)
	var backpack: Array = state.get("backpack", [])
	var materials: int = 0
	var any: bool = false
	for index: int in backpack.size():
		var kind: String = World.kind_of(backpack[index])
		var price: int = Economy.sell_price(kind)
		if price <= 0:
			continue
		any = true
		if World.ITEMS[kind].has("value"):
			materials += price * World.count_of(backpack[index])
		var row := HBoxContainer.new()
		rows.add_child(row)
		var picture := TextureRect.new()
		picture.texture = icon(kind)
		row.add_child(picture)
		var item_label := Label.new()
		var count: int = World.count_of(backpack[index])
		item_label.text = "%s%s  %d gold" % [World.ITEMS[kind]["name"], " ×%d" % count if count > 1 else "", price * count]
		item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(item_label)
		_button("Sell", true, func() -> void: game.sell_local(npc, index), row)
	if materials > 0:
		_button("Sell all materials  (+%d gold)" % materials, true, func() -> void: game.sell_local(npc, -1), rows)
	if not any:
		var nothing := Label.new()
		nothing.text = "You carry nothing the vendor wants."
		nothing.modulate = Color("#a7b0b8")
		rows.add_child(nothing)
	_farewell()
	_show(npc, "trade")


## A banker: move gold between purse and bank, and items between backpack and depot.
func open_bank(npc: String) -> void:
	if not _begin(npc):
		return
	var banker: Dictionary = World.npc(npc)
	var state: Dictionary = game.actors[game.self_id]["state"]
	var gold: int = state.get("gold", 0)
	var balance: int = state.get("bank", 0)
	_label("%s, %s\n\"The only bank in the land: your gold and goods are safe here.\"" % [banker["name"], banker["place"]])
	_label("Purse: %d gold    Bank: %d gold" % [gold, balance], Color("#ffcf6a"))
	var row := HBoxContainer.new()
	list.add_child(row)
	var amount := SpinBox.new()
	amount.min_value = 1
	amount.max_value = maxi(1, maxi(gold, balance))
	amount.value = clampi(_bank_amount, 1, int(amount.max_value))
	amount.value_changed.connect(func(value: float) -> void: _bank_amount = int(value))
	row.add_child(amount)
	_button("Deposit", gold > 0, func() -> void: game.bank_local(npc, "deposit", mini(_bank_amount, gold)), row)
	_button("Withdraw", balance > 0, func() -> void: game.bank_local(npc, "withdraw", mini(_bank_amount, balance)), row)
	_button("Deposit all", gold > 0, func() -> void: game.bank_local(npc, "deposit", gold), row)
	_label("Depot  —  drag items to and from your backpack, or right-click them.", Color("#a7b0b8"))
	var grid := GridContainer.new()
	grid.columns = DEPOT_COLUMNS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	list.add_child(grid)
	for index: int in World.DEPOT_SIZE:
		grid.add_child(game.inventory.make_slot({"type": "depot", "index": index}))
	_farewell()
	_show(npc, "bank")


## A town hunting task: accept it, follow your progress, and turn it in for a bigger pack.
func _open_task(npc: String) -> void:
	if not _begin(npc):
		return
	var giver: Dictionary = World.QUEST_GIVERS[npc]
	var state: Dictionary = game.actors[game.self_id]["state"]
	var tasks: Dictionary = state.get("tasks", {})
	var done: Array = state.get("done_tasks", [])
	var first: Dictionary = Quests.TASKS[giver["tasks"][0]]
	_label("%s, %s\n\"%s\"" % [giver["name"], giver["place"], first["intro"]])
	for task: String in giver["tasks"]:
		var definition: Dictionary = Quests.TASKS[task]
		var target: String = Quests.target_name(task)
		if task != giver["tasks"][0] and task not in done:
			_label("\"%s\"" % definition["intro"], Color("#a7b0b8"))
		if task in done:
			_label("%s: done." % definition["title"], Color("#9fe07a"))
			continue
		if tasks.has(task):
			var finished: bool = tasks[task] >= definition["count"]
			_label("%s: %d/%d %s slain." % [definition["title"], tasks[task], definition["count"], target],
				Color("#9fe07a") if finished else Color("#ffcf6a"))
			_button("Turn in: %s" % definition["title"], finished, func() -> void: game.task_local(npc, task, "complete"))
		else:
			_label("%s: slay %s and return to %s." % [definition["title"],
				target if definition["count"] == 1 else "%d %s" % [definition["count"], target], giver["name"]], Color("#ffcf6a"))
			_button("Accept: %s" % definition["title"], true, func() -> void: game.task_local(npc, task, "accept"))
		_reward_label(task, state)
	_farewell()
	_show(npc, "quests")


## What a task pays: the next pack, or experience and gold.
func _reward_label(task: String, state: Dictionary) -> void:
	var reward: Dictionary = Quests.reward(task)
	if not reward.is_empty():
		_label("Reward: %d experience and %d gold." % [reward["experience"], reward["gold"]], Color("#a7b0b8"))
		return
	var pack: String = Quests.next_pack(state["equipment"].get("bag", ""))
	if pack.is_empty():
		return
	var line: Label = _label("Reward: a %s (%d backpack slots)." % [World.ITEMS[pack]["name"],
		mini(World.BACKPACK_MAX, World.BACKPACK_SIZE + World.ITEMS[pack]["slots"])], Color("#a7b0b8"))
	line.tooltip_text = game.inventory.item_tooltip(pack)
	line.mouse_filter = Control.MOUSE_FILTER_PASS


## A quest giver: their hunting task, or the Relic keeper's quests (one per final boss, with
## your trophies and a claim button per relic).
func open_quests(npc: String) -> void:
	var actors: Dictionary = game.actors
	var self_id: int = game.self_id
	if not actors.has(self_id) or not World.QUEST_GIVERS.has(npc):
		return
	if not World.QUEST_GIVERS[npc]["tasks"].is_empty():
		_open_task(npc)
		return
	var keeper: Dictionary = World.QUEST_GIVERS[npc]
	if not World.in_talk_range(actors[self_id]["state"]["cell"], keeper["cell"]):
		game.last_action_message = "Walk closer to %s." % keeper["name"]
		return
	for child: Node in list.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "%s, %s\n\"Bring me proof that %s has fallen and I will forge you a relic.\"" % [keeper["name"], keeper["place"],
		Monsters.MONSTERS[keeper["boss"]]["name"]]
	list.add_child(title)
	var state: Dictionary = actors[self_id]["state"]
	var trophies: Dictionary = state.get("trophies", {})
	var room: bool = state.get("backpack", []).has("")
	for boss: String in [keeper["boss"]]:
		var definition: Dictionary = Monsters.MONSTERS[boss]
		var heading := Label.new()
		heading.text = "Slay %s  —  trophies: %d" % [definition["name"], trophies.get(boss, 0)]
		heading.add_theme_color_override("font_color", Color("#ffcf6a") if trophies.get(boss, 0) > 0 else Color("#a7b0b8"))
		list.add_child(heading)
		for relic: String in definition["relics"]:
			var button := Button.new()
			var refused: String = game.inventory.requirement_for(relic)
			button.text = "  Claim the %s%s" % [World.ITEMS[relic]["name"], "" if refused.is_empty() else "  (%s)" % refused]
			button.tooltip_text = game.inventory.item_tooltip(relic)
			button.add_theme_color_override("font_color", World.ITEMS[relic]["glow"])
			button.disabled = trophies.get(boss, 0) <= 0 or not room
			button.pressed.connect(func() -> void:
				game.quest_local(npc, relic)
				close())
			list.add_child(button)
	if not room:
		var full := Label.new()
		full.text = "Make room in your backpack to carry a relic."
		list.add_child(full)
	_farewell()
	_show(npc, "quests")
