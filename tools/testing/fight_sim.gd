extends SceneTree
## Fight simulator for balancing monsters: a player in vendor-tier gear of their level stands
## and fights `count` monsters (no kiting; monsters catch up anyway). Two styles per vocation:
## "auto" (auto-attacks only) and "full" (attack spells when ready, healing spells below 55%
## health, a health potion below 35%, a mana potion below 25% mana). Prints time, lowest health,
## potions used, or the moment the player died. Uses the real Combat rules on the host model.
##
##   godot --headless --path . --script res://tools/testing/fight_sim.gd -- \
##       --monster=field_vole --levels=1,10,20,30,40 --count=3 [--player-level=N] [--vocations=knight,druid]
##
## Reference bands (normal rank, same level) live in .github/skills/monster-authoring/SKILL.md.

const World = preload("res://game/core/world.gd")
const Combat = preload("res://game/core/combat.gd")
const Balance = preload("res://game/data/balance.gd")
const Items = preload("res://game/data/items.gd")
const Spells = preload("res://game/data/spells.gd")
const Monsters = preload("res://game/data/monsters.gd")
const OFFSETS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1)]
const TIME_LIMIT: float = 300.0

## Replaces every vocation's off-hand item (--off-hand=torch: a dark dungeon, no shield or book).
var off_hand: String = ""


func _initialize() -> void:
	var options: Dictionary = {"monster": "field_vole", "levels": "1,10,20,30,40", "count": "1",
		"player-level": "", "vocations": "knight,paladin,sorcerer,druid", "off-hand": ""}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			options[argument.substr(2).get_slice("=", 0)] = argument.get_slice("=", 1)
	var kind: String = options["monster"]
	off_hand = options["off-hand"]
	if not off_hand.is_empty() and World.ITEMS.get(off_hand, {}).get("slot", "") != "off_hand":
		printerr("Unknown off-hand item %s" % off_hand)
		quit(1)
		return
	if not Monsters.MONSTERS.has(kind):
		printerr("Unknown monster %s" % kind)
		quit(1)
		return
	var definition: Dictionary = Monsters.MONSTERS[kind]
	print("%s (%s, range %d, step %.2f s, chase %.2f s at even level, %.2f s 10+ levels up)" % [definition["name"],
		definition["rank"], definition["range"], definition["step"], Balance.chase_seconds(1, 1), Balance.chase_seconds(50, 1)])
	for level_text: String in options["levels"].split(","):
		var level: int = level_text.to_int()
		var player_level: int = options["player-level"].to_int() if not options["player-level"].is_empty() else level
		for vocation: String in options["vocations"].split(","):
			var line: PackedStringArray = []
			for full: bool in [false, true]:
				line.append(_fight(player_level, level, vocation, clampi(options["count"].to_int(), 1, OFFSETS.size()), kind, full))
			print("%-9s L%2d vs %s x L%2d  |  auto: %-28s |  full: %s" % [vocation, player_level, options["count"], level, line[0], line[1]])
	quit()


## Vendor-style gear of the player's tier (no relics or hunting drops).
func _gear(level: int, vocation: String) -> Dictionary:
	var gear: Dictionary = {}
	var tier: int = Items.tier_for(level)
	for kind: String in World.ITEMS:
		var item: Dictionary = World.ITEMS[kind]
		if item["level"] == tier and not item.get("loot_only", false) and not item.has("glow") \
				and item["slot"] in ["helmet", "armor", "main_hand", "off_hand"] \
				and World.requirement_error(kind, Balance.MAX_LEVEL, vocation).is_empty() and not gear.has(item["slot"]):
			gear[item["slot"]] = kind
	if not off_hand.is_empty():
		gear["off_hand"] = off_hand
	return gear


## An open overworld field outside towns, with room for the fight.
func _arena() -> Vector2i:
	for spawn: Dictionary in World.MONSTER_SPAWNS:
		var clear: bool = World.dungeon_at(spawn["cell"]).is_empty()
		for dy: int in range(-3, 4):
			for dx: int in range(-3, 4):
				var cell: Vector2i = spawn["cell"] + Vector2i(dx, dy)
				clear = clear and World.walkable(cell) and World.zone_at(cell).is_empty()
		if clear:
			return spawn["cell"]
	return World.SPAWNS[0]


func _fight(level: int, monster_level: int, vocation: String, count: int, kind: String, full: bool) -> String:
	var world := World.new()
	var combat := Combat.new(world, 5)
	world.monsters.clear()
	world.add_player(1, 0.0, vocation)
	var player: Dictionary = world.players[1]
	player["level"] = level
	player["equipment"] = _gear(level, vocation)
	var stats: Dictionary = world.player_stats(1)
	player["health"] = stats["health"]
	player["mana"] = stats["mana"]
	var arena: Vector2i = _arena()
	player["cell"] = arena
	player["from"] = arena
	var ids: Array[int] = []
	for index: int in count:
		ids.append(combat.spawn_monster(kind, monster_level, arena + OFFSETS[index], 0.0))
	if full:
		player["backpack"][0] = "health_potion#100"
		player["backpack"][1] = "mana_potion#100"
	var spells: Array[String] = Spells.for_vocation(vocation).filter(func(id: String) -> bool: return Spells.SPELLS[id]["level"] <= level)
	# Strongest first, like a player reaching for their best spell that is ready.
	spells.sort_custom(func(a: String, b: String) -> bool: return Spells.SPELLS[a]["power"] > Spells.SPELLS[b]["power"])
	var now: float = 0.0
	var lowest: int = player["health"]
	var potions: int = 0
	while now < TIME_LIMIT:
		now += Combat.TICK_SECONDS
		var alive: Array[int] = ids.filter(func(id: int) -> bool: return world.monsters.has(id))
		if alive.is_empty():
			return "%5.1f s, lowest %3d%%, %2d potions" % [now, roundi(100.0 * lowest / stats["health"]), potions]
		if not world.monsters.has(player["target"]):
			combat.set_target(1, alive[0], now)
		if full:
			potions += _use_resources(world, combat, spells, now)
		combat.tick(now)
		lowest = mini(lowest, player["health"])
		# The player never walks here, so leaving the tile means they died and respawned.
		if player["cell"] != arena:
			return "DIED after %.1f s" % now
	return "unfinished after %d s" % TIME_LIMIT


## Casts and drinks like a careful player; returns potions drunk.
func _use_resources(world: World, combat: Combat, spells: Array[String], now: float) -> int:
	var player: Dictionary = world.players[1]
	var stats: Dictionary = world.player_stats(1)
	var share: float = float(player["health"]) / stats["health"]
	for spell: String in spells:
		var style: String = Spells.SPELLS[spell]["kind"]
		if (style.begins_with("heal") and share < 0.55) or (not style.begins_with("heal") and style != "taunt" and share >= 0.3):
			combat.cast(1, spell, now)
	var potion: String = ""
	if share < 0.35:
		potion = "health_potion"
	elif float(player["mana"]) / maxf(1.0, stats["mana"]) < 0.25:
		potion = "mana_potion"
	if potion.is_empty():
		return 0
	var index: int = player["backpack"].find_custom(func(entry: String) -> bool: return entry.begins_with(potion))
	return 1 if index >= 0 and combat.drink(1, index, now)["ok"] else 0
