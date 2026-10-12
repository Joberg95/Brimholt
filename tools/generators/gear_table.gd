extends SceneTree
## Prints the gear tier tables for docs/balance.md as Markdown.
## godot --headless --path . --script res://tools/generators/gear_table.gd

const World = preload("res://game/core/world.gd")
const Items = preload("res://game/data/items.gd")
const Balance = preload("res://game/data/balance.gd")
const Monsters = preload("res://game/data/monsters.gd")
const SHORT: Dictionary = {"health": "hp", "mana": "mana", "attack": "atk", "defense": "def", "regen": "regen",
	"healing": "heal", "critical": "crit"}


func _initialize() -> void:
	var lines: PackedStringArray = []
	_table(lines, "Tier", ["Helmet", "Armor", "Shield (Knight, Paladin)", "Spellbook (Sorcerer, Druid)"],
		func(level: int, column: int) -> String:
			var slot: String = ["helmet", "armor", "off_hand", "off_hand"][column]
			var vocation: String = ["", "", "knight", "sorcerer"][column]
			return _cell(_find(slot, level, vocation)))
	lines.append("")
	_table(lines, "Tier", ["Knight", "Paladin", "Sorcerer", "Druid"],
		func(level: int, column: int) -> String:
			return _cell(_find("main_hand", level, Balance.VOCATIONS.keys()[column])))
	lines.append("")
	_table(lines, "Tier", ["Amulet", "Cape", "Charm", "Ring"],
		func(level: int, column: int) -> String:
			return _cell(_find(Items.ACCESSORY_SLOTS[column], level, "")), Items.ACCESSORY_LEVEL)
	lines.append("")
	lines.append("| Boss | Relics (level %d, bound; one trophy each) |" % Items.RELIC_LEVEL)
	lines.append("| --- | --- |")
	for boss: String in Monsters.MONSTERS:
		if Monsters.MONSTERS[boss].has("relics"):
			var cells: PackedStringArray = []
			for relic: String in Monsters.MONSTERS[boss]["relics"]:
				cells.append(_cell(relic))
			lines.append("| %s | %s |" % [Monsters.MONSTERS[boss]["name"], "; ".join(cells)])
	print("\n".join(lines))
	quit()


func _table(lines: PackedStringArray, first: String, columns: Array, cell: Callable, from_level: int = 1) -> void:
	lines.append("| %s | %s |" % [first, " | ".join(columns)])
	lines.append("| ---: |%s" % " --- |".repeat(columns.size()))
	for level: int in Items.TIER_LEVELS:
		if level < from_level:
			continue
		var cells: PackedStringArray = []
		for column: int in columns.size():
			cells.append(cell.call(level, column))
		lines.append("| %d | %s |" % [level, " | ".join(cells)])


func _find(slot: String, level: int, vocation: String) -> String:
	for kind: String in World.ITEMS:
		var item: Dictionary = World.ITEMS[kind]
		if item["slot"] == slot and item["level"] == level and (vocation.is_empty() or vocation in item["vocations"]):
			return kind
	return ""


func _cell(kind: String) -> String:
	if kind.is_empty():
		return "-"
	var item: Dictionary = World.ITEMS[kind]
	var stats: PackedStringArray = []
	for stat: String in item["stats"]:
		stats.append("%d %s" % [item["stats"][stat], SHORT[stat]])
	return "%s (%s)" % [item["name"], ", ".join(stats)]
