extends PanelContainer
## The character window (Keybinds "character", C by default): your vocation and role,
## experience to the next level, each stat (base, gear, and what it does), and your status:
## gold and bank, party, skull, town rest, meal, and relic trophies. Its labels are built once and
## only their text changes, and only while it is open.

const World = preload("res://game/core/world.gd")
const WorldMap = preload("res://game/world_map/world_map.gd")
const Titles = preload("res://game/data/titles.gd")
const Balance = preload("res://game/data/balance.gd")
const Combat = preload("res://game/core/combat.gd")
const Monsters = preload("res://game/data/monsters.gd")
const Quests = preload("res://game/data/quests.gd")
const Spells = preload("res://game/data/spells.gd")
const Layout = preload("res://game/ui/layout.gd")

const SIZE: Vector2 = Vector2(600, 560)
const TITLE: Color = Color("#ffcf6a")
const TEXT: Color = Color("#e8e4da")
const MUTED: Color = Color("#a7b0b8")
const BONUS: Color = Color("#9fe07a")
const WARNING: Color = Color("#e05a4a")

var game: Node
var _title: Label
var _role: Label
var _experience: Label
var _values: Dictionary = {}
var _notes: Dictionary = {}
var _status: Label
var _key: String = "-"


func _init() -> void:
	position = Layout.VIEW_ORIGIN + (Layout.VIEW_SIZE - SIZE) / 2.0
	size = SIZE
	custom_minimum_size = SIZE
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
	_title = _label("", 18, TITLE)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var close := Button.new()
	close.text = "Close"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(hide)
	header.add_child(close)
	_role = _label("", 13, MUTED)
	column.add_child(_role)
	_experience = _label("", 13, TEXT)
	column.add_child(_experience)
	column.add_child(_label("Stats", 15, TITLE))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 3)
	column.add_child(grid)
	for stat: String in Balance.STATS:
		var stat_name: Label = _label("Magic defense" if stat == "magic_defense" else stat.capitalize(), 13, MUTED)
		stat_name.autowrap_mode = TextServer.AUTOWRAP_OFF
		grid.add_child(stat_name)
		_values[stat] = _label("", 13, TEXT)
		_values[stat].autowrap_mode = TextServer.AUTOWRAP_OFF
		grid.add_child(_values[stat])
		_notes[stat] = _label("", 12, MUTED)
		_notes[stat].custom_minimum_size = Vector2(300, 0)
		_notes[stat].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(_notes[stat])
	column.add_child(_label("Status", 15, TITLE))
	_status = _label("", 13, TEXT)
	column.add_child(_status)
	visible = false


func toggle() -> void:
	visible = not visible


## Per frame while open: rewrite the texts when your character changed.
func refresh() -> void:
	if not visible:
		return
	if not game.client.actors.has(game.client.self_id):
		if _key != "":
			_key = ""
			_title.text = "Character"
			_role.text = "Host or join a game to see your character."
			_experience.text = ""
			_status.text = ""
			for stat: String in Balance.STATS:
				_values[stat].text = "-"
				_notes[stat].text = ""
		return
	var view: Dictionary = game.client.actors[game.client.self_id]
	var state: Dictionary = view["state"]
	var rest_left: int = ceili(state.get("town_rest_left", 0.0) - (game._now() - view.get("received", game._now())))
	var meal_left: int = 0
	if state.has("fed"):
		meal_left = ceili(float(state["fed"][1]) - (game._now() - view.get("received", game._now())))
	var key: String = "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [state.get("level"), state.get("experience"), state.get("vocation"),
		state.get("equipment"), state.get("health"), state.get("mana"), state.get("gold"), state.get("bank"),
		state.get("party"), state.get("skull"), state.get("town_rest"), maxi(rest_left, 0), maxi(meal_left, 0) / 60]
	key += "|%s|%s|%s" % [state.get("title"), state.get("done_tasks"), state.get("slain")]
	if key == _key:
		return
	_key = key
	_write(state, maxi(rest_left, 0), maxi(meal_left, 0))


func _write(state: Dictionary, rest_left: int, meal_left: int) -> void:
	var level: int = state.get("level", 1)
	var vocation: String = state.get("vocation", Balance.DEFAULT_VOCATION)
	var profile: Dictionary = Balance.profile_of(vocation)
	var stats: Dictionary = World.stats(level, state.get("equipment", {}), vocation)
	var base: Dictionary = Balance.base_stats(level, vocation)
	var title: String = Titles.name_of(vocation, int(state.get("title", 0)))
	_title.text = "%s · level %d" % [profile["name"] if title.is_empty() else "%s (%s)" % [title, profile["name"]], level]
	_role.text = "Role: %s" % profile["role"]
	var next: int = Balance.experience_to_next(level)
	var experience: int = state.get("experience", 0)
	_experience.text = "Experience: maximum level" if next <= 0 else "Experience %d / %d (%d%%) to level %d" % [
		experience, next, floori(100.0 * experience / next), level + 1]
	var reduction: int = 100 - Balance.damage_taken(100, stats["defense"])
	var notes: Dictionary = {
		"health": "Damage you can take. At 0 you die and lose %d%% of your experience." % roundi(Combat.DEATH_PENALTY * 100.0),
		"mana": "Pays for spells. Regenerates over time; mana potions restore a quarter.",
		"attack": "Damage of your auto-attack every 2 s, and the base of spell damage.",
		"defense": "Cuts physical damage (blades, arrows, most monsters) by %d%% (100 defense halves it). Plate gives the most." % reduction,
		"magic_defense": "Cuts magic damage (Sorcerers, Druids, runes, casting monsters) by %d%%. Cloth, capes, and amulets give it." % (
			100 - Balance.damage_taken(100, stats["magic_defense"])),
		"critical": "Chance per hit to deal %s× damage." % Spells.number(Combat.CRITICAL_MULTIPLIER),
		"regen": "Health regained every 10 s; %s× after %d s out of combat, %d× resting in town." % [
			Spells.number(Combat.RESTING_MULTIPLIER), int(Combat.RESTING_SECONDS), Combat.TOWN_REST_MULTIPLIER],
		"healing": "Strength of heals you cast on others (Mass mend, Wild growth)." if stats["healing"] > 0
			else "Only healers (Druids, and a little for Hunters) heal others.",
	}
	for stat: String in Balance.STATS:
		var text: String = str(stats[stat])
		if stat in ["health", "mana"] and state.has(stat):
			text = "%d / %d" % [state[stat], stats[stat]]
		elif stat == "critical":
			text += "%"
		var bonus: int = stats[stat] - base[stat]
		if bonus != 0:
			text += "  (%d %+d gear)" % [base[stat], bonus]
		_values[stat].text = text
		_values[stat].add_theme_color_override("font_color", BONUS if bonus > 0 else TEXT)
		_notes[stat].text = notes[stat]
	_status.text = "\n".join(_status_lines(state, rest_left, meal_left))
	_status.add_theme_color_override("font_color", WARNING if not String(state.get("skull", "")).is_empty() else TEXT)


func _status_lines(state: Dictionary, rest_left: int, meal_left: int) -> PackedStringArray:
	var lines: PackedStringArray = []
	lines.append("Gold %d carried · %d in the bank (%s)" % [state.get("gold", 0), state.get("bank", 0), WorldMap.bank_place()])
	var done: Dictionary = {}
	for task: String in state.get("done_tasks", []):
		done[task] = true
	var slain: Dictionary = {}
	for boss: String in state.get("slain", []):
		slain[boss] = true
	var next: String = Titles.next_step(state.get("vocation", ""), int(state.get("title", 0)), done, slain)
	if not next.is_empty():
		lines.append(next)
	var party: int = state.get("party", 0)
	if party == 0:
		lines.append("No party: right-click another player to invite them and share experience.")
	else:
		var members: int = 0
		for id: int in game.client.actors:
			if game.client.actors[id]["state"].get("party", 0) == party:
				members += 1
		lines.append("In a party of %d%s." % [members, " (you lead it)" if party == game.client.self_id else ""])
	match String(state.get("skull", "")):
		"white":
			lines.append("White skull: you attacked an unmarked player. Others may kill you freely while it lasts.")
		"red":
			lines.append("Red skull: too many unjustified kills. You drop everything if you die.")
		_:
			lines.append("No skull.")
	if state.get("unjustified", 0) > 0:
		lines.append("Unjustified kills: %d of %d before a red skull." % [state["unjustified"], Combat.RED_SKULL_KILLS])
	if state.get("town_rest", false):
		lines.append("Town rest: resting (%d× regeneration until full)." % Combat.TOWN_REST_MULTIPLIER)
	elif rest_left > 0:
		lines.append("Town rest: ready again in %d:%02d." % [rest_left / 60, rest_left % 60])
	else:
		lines.append("Town rest: ready; stand in a town while hurt.")
	if meal_left > 0 and state.has("fed"):
		lines.append("Well fed (%s): %d%% faster regeneration for %d more minutes." % [World.ITEMS[state["fed"][0]]["name"],
			roundi(World.ITEMS[state["fed"][0]]["eat"]["regen"] * 100.0), ceili(meal_left / 60.0)])
	else:
		lines.append("Hungry: eat cooked food (Cooking, at an artisan) for faster regeneration.")
	var trophies: Dictionary = state.get("trophies", {})
	for boss: String in trophies:
		var keeper: String = ""
		for giver: String in Quests.RELIC_KEEPERS:
			if Quests.RELIC_KEEPERS[giver] == boss and WorldMap.QUEST_GIVERS.has(giver):
				keeper = " in %s" % WorldMap.QUEST_GIVERS[giver]["place"]
		lines.append("%d trophy from %s: trade it for a relic at its relic keeper%s." % [trophies[boss],
			Monsters.MONSTERS.get(boss, {}).get("name", boss), keeper])
	return lines


func _label(content: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
