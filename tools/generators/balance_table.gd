extends SceneTree
## Prints Brimholt's level 1-50 balance table as Markdown.
## godot --headless --path . --script res://tools/generators/balance_table.gd

const Balance = preload("res://game/data/balance.gd")


func _initialize() -> void:
	var lines: PackedStringArray = [
		"| Level | Player HP | Base atk | Geared atk | Mob HP | Elite HP | Champion HP | Boss HP | Mob hit | Elite hit | Champion hit | Boss hit | Mob XP | Champion XP | XP to next |",
		"| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
	]
	var total_kills: int = 0
	for level: int in range(1, Balance.MAX_LEVEL + 1):
		if level < Balance.MAX_LEVEL:
			total_kills += Balance.kills_to_level(level)
		lines.append("| %d | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % [
			level, _n(Balance.player_health(level)), _n(Balance.base_attack(level)), _n(Balance.geared_attack(level)),
			_n(Balance.mob_health(level)), _n(Balance.mob_health(level, "elite")), _n(Balance.mob_health(level, "champion")),
			_n(Balance.mob_health(level, "boss")), _n(Balance.mob_damage(level)), _n(Balance.mob_damage(level, "elite")),
			_n(Balance.mob_damage(level, "champion")), _n(Balance.mob_damage(level, "boss")), _n(Balance.mob_experience(level)),
			_n(Balance.mob_experience(level, "champion")), _n(Balance.experience_to_next(level)) if level < Balance.MAX_LEVEL else "max",
		])
	lines.append("")
	lines.append("| Vocation | Role | HP 1 / 50 | Mana 1 / 50 | Attack 1 / 50 | Healing/s 1 / 50 | Base def |")
	lines.append("| --- | --- | ---: | ---: | ---: | ---: | ---: |")
	for vocation: String in Balance.VOCATIONS:
		var low: Dictionary = Balance.base_stats(1, vocation)
		var high: Dictionary = Balance.base_stats(Balance.MAX_LEVEL, vocation)
		lines.append("| %s | %s | %s / %s | %s / %s | %s / %s | %s / %s | %d |" % [
			Balance.VOCATIONS[vocation]["name"], Balance.VOCATIONS[vocation]["role"],
			_n(low["health"]), _n(high["health"]), _n(low["mana"]), _n(high["mana"]),
			_n(low["attack"]), _n(high["attack"]), _n(low["healing"]), _n(high["healing"]), low["defense"]])
	lines.append("")
	lines.append("| Level-50 group | Players | Boss down in | Healing (need %.1f) | Tanks | Result |" % Balance.BOSS_HEALING_PRESSURE)
	lines.append("| --- | ---: | ---: | ---: | ---: | --- |")
	var groups: Array = [Balance.RAID]
	for vocation: String in Balance.RAID:
		var smaller: Dictionary = Balance.RAID.duplicate()
		smaller[vocation] -= 1
		groups.append(smaller)
	groups.append({"knight": 4, "paladin": 4, "sorcerer": 8, "druid": 4})
	groups.append({"knight": 4, "paladin": 8, "sorcerer": 6, "druid": 4})
	groups.append({"knight": 4, "paladin": 0, "sorcerer": 10, "druid": 5})
	groups.append({"knight": 2, "paladin": 3, "sorcerer": 3, "druid": 2})
	groups.append({"knight": 1, "paladin": 1, "sorcerer": 1, "druid": 1})
	for group: Dictionary in groups:
		var result: Dictionary = Balance.raid_check(group)
		var parts: PackedStringArray = []
		for vocation: String in group:
			parts.append("%d %s" % [group[vocation], Balance.VOCATIONS[vocation]["name"]])
		lines.append("| %s | %d | %s | %.1f | %d | %s |" % [", ".join(parts), result["players"],
			"%d s" % roundi(result["seconds"]), result["healing"], result["tanks"],
			"wins" if result["ok"] else "loses: " + ", ".join(result["reasons"])])
	print("\n".join(lines))
	print("\nGrowth per level: %.4f. Boss = %.0f normal mobs. Reference DPS at level %d: %.1f. Normal kills from 1 to %d: %s." % [
		Balance.growth(), Balance.boss_ratio(), Balance.MAX_LEVEL, Balance.reference_dps(), Balance.MAX_LEVEL, _n(total_kills)])
	quit()


func _n(value: int) -> String:
	var text: String = str(absi(value))
	var result: String = ""
	while text.length() > 3:
		result = "," + text.right(3) + result
		text = text.left(text.length() - 3)
	return ("-" if value < 0 else "") + text + result
