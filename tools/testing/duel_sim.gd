extends SceneTree
## Same-level PvP duels on Blackreed Isle, each side in its tier's vendor gear, starting adjacent
## and fighting like a careful player (fight_sim.gd): strongest attack spell when ready, heals
## below 55% health, a health potion below 35%, a mana potion below 25% mana. Prints the winner,
## the time, potions drunk, damage per second, and health healed. Uses the real Combat rules
## (PvP damage, PvP healing and its fading, potion cooldowns).
##
##   godot --headless --path . --script res://tools/testing/duel_sim.gd -- [--levels=20,30,45]

const World = preload("res://game/core/world.gd")
const Combat = preload("res://game/core/combat.gd")
const Spells = preload("res://game/data/spells.gd")
const FightSim = preload("res://tools/testing/fight_sim.gd")
const PAIRS: Array = [["druid", "knight"], ["druid", "paladin"], ["druid", "sorcerer"], ["druid", "druid"],
	["knight", "paladin"], ["knight", "sorcerer"], ["paladin", "sorcerer"], ["knight", "knight"],
	["paladin", "paladin"], ["sorcerer", "sorcerer"]]
const TIME_LIMIT: float = 180.0


func _initialize() -> void:
	var levels: String = "20,30,45"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--levels="):
			levels = argument.get_slice("=", 1)
	var gear: FightSim = FightSim.new()
	var arena: Vector2i = _arena()
	for level_text: String in levels.split(","):
		for pair: Array in PAIRS:
			print(_duel(level_text.to_int(), pair[0], pair[1], arena, gear))
	gear.free()
	quit()


func _arena() -> Vector2i:
	for zone: Dictionary in World.ZONES:
		if zone["pvp"]:
			for y: int in range(zone["rect"].position.y, zone["rect"].end.y):
				for x: int in range(zone["rect"].position.x, zone["rect"].end.x):
					var cell := Vector2i(x, y)
					if World.walkable(cell) and World.walkable(cell + Vector2i.RIGHT) and World.zone_at(cell + Vector2i.RIGHT)["pvp"]:
						return cell
	return Vector2i(-1, -1)


func _duel(level: int, first: String, second: String, arena: Vector2i, gear: FightSim) -> String:
	var world := World.new()
	var combat := Combat.new(world, 9)
	world.monsters.clear()
	world.add_player(1, 0.0, first)
	world.add_player(2, 0.0, second)
	for id: int in [1, 2]:
		var player: Dictionary = world.players[id]
		player["level"] = level
		player["equipment"] = gear._gear(level, player["vocation"])
		var stats: Dictionary = world.player_stats(id)
		player["health"] = stats["health"]
		player["mana"] = stats["mana"]
		player["backpack"][0] = "health_potion#100"
		player["backpack"][1] = "mana_potion#100"
		player["cell"] = arena + Vector2i(id - 1, 0)
		player["from"] = player["cell"]
	var potions: Array[int] = [0, 0]
	var dealt: Array[int] = [0, 0]
	var healed: Array[int] = [0, 0]
	var now: float = 0.0
	var result: String = "draw"
	while now < TIME_LIMIT:
		now += Combat.TICK_SECONDS
		var events: Array = []
		for id: int in [1, 2]:
			if world.players[id]["target"] == 0:
				combat.set_target(id, 3 - id, now)
			potions[id - 1] += _act(world, combat, id, now, events)
		events.append_array(combat.tick(now))
		for event: Dictionary in events:
			if event["kind"] == "hit" and event["target"] > 0:
				if event["style"] in ["damage", "critical"]:
					dealt[2 - event["target"]] += event["amount"]
				elif event["style"] == "heal":
					healed[event["target"] - 1] += event["amount"]
		# A dead player respawns in a temple far from the arena.
		if Combat.distance(world.players[1]["cell"], arena) > 20:
			result = "%s wins" % second
			break
		if Combat.distance(world.players[2]["cell"], arena) > 20:
			result = "%s wins" % first
			break
	return "L%d %-8s vs %-8s %-15s %5.1f s  potions %d/%d  dps %d/%d  healed %d/%d" % [level, first, second, result, now,
		potions[0], potions[1], dealt[0] / now, dealt[1] / now, healed[0], healed[1]]


## Casts and drinks like fight_sim's careful player; returns potions drunk and collects events.
func _act(world: World, combat: Combat, id: int, now: float, events: Array) -> int:
	var player: Dictionary = world.players[id]
	var stats: Dictionary = world.player_stats(id)
	var share: float = float(player["health"]) / stats["health"]
	var known: Array[String] = Spells.for_vocation(player["vocation"]).filter(func(spell: String) -> bool:
		return Spells.SPELLS[spell]["level"] <= player["level"])
	known.sort_custom(func(a: String, b: String) -> bool: return Spells.SPELLS[a]["power"] > Spells.SPELLS[b]["power"])
	for spell: String in known:
		var style: String = Spells.SPELLS[spell]["kind"]
		if (style.begins_with("heal") and share < 0.55) or (not style.begins_with("heal") and style != "taunt" and share >= 0.3):
			events.append_array(combat.cast(id, spell, now).get("events", []))
	var potion: String = "health_potion" if share < 0.35 else ("mana_potion" if float(player["mana"]) / stats["mana"] < 0.25 else "")
	if potion.is_empty():
		return 0
	var index: int = player["backpack"].find_custom(func(entry: String) -> bool: return entry.begins_with(potion))
	if index < 0:
		return 0
	var drunk: Dictionary = combat.drink(id, index, now)
	events.append_array(drunk.get("events", []))
	return 1 if drunk["ok"] else 0
