extends SceneTree
## The refactor safety net (plan 48 step 0): a fixed, seeded play session (a party of three hunting
## monsters for two minutes of game time, item moves, a potion, a death, and a save round trip) whose
## outcome is digested section by section and compared with tests/unit/golden.txt. A refactor must
## leave every section as it was; a deliberate rule change records a new golden in its own commit.
##
##   godot --headless --path . --script res://tests/unit/golden_test.gd             # compare
##   godot --headless --path . --script res://tests/unit/golden_test.gd -- --record # write golden.txt
##
## Each run writes the full digests to .tools/golden/<section>.txt, so a changed section can be
## diffed against a run of the previous commit.

const World = preload("res://game/core/world.gd")
const Combat = preload("res://game/core/combat.gd")
const Spells = preload("res://game/data/spells.gd")
const CharacterStore = preload("res://game/persistence/character_store.gd")

const GOLDEN: String = "res://tests/unit/golden.txt"
const OUT_DIR: String = "res://.tools/golden"
const STEP: float = 0.1
const SECONDS: float = 120.0
const PLAYERS: Dictionary = {1: "knight", 2: "sorcerer", 3: "druid"}
const LEVEL: int = 20
## Monsters set around the party: [kind, level, offset from the party's first cell].
const PACK: Array = [["wild_hog", 18, Vector2i(4, 0)], ["wild_hog", 18, Vector2i(4, 2)], ["brigand", 20, Vector2i(-4, 1)],
	["brigand", 20, Vector2i(0, 4)], ["wild_hog", 18, Vector2i(-3, -3)]]

var world: World
var combat: Combat
var events: Array = []


func _initialize() -> void:
	seed(4242)
	world = World.new()
	combat = Combat.new(world, 7)
	var digests: Dictionary = _play()
	var lines: PackedStringArray = []
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for section: String in digests:
		var text: String = digests[section]
		FileAccess.open("%s/%s.txt" % [OUT_DIR, section], FileAccess.WRITE).store_string(text)
		lines.append("%s %s" % [section, text.sha256_text()])
	var result: String = "\n".join(lines) + "\n"
	if "--record" in OS.get_cmdline_user_args():
		FileAccess.open(GOLDEN, FileAccess.WRITE).store_string(result)
		print("BRIMHOLT_GOLDEN: recorded %d sections" % lines.size())
		quit(0)
		return
	var expected: String = FileAccess.get_file_as_string(GOLDEN) if FileAccess.file_exists(GOLDEN) else ""
	var failed: Array[String] = []
	for line: String in lines:
		if not expected.contains(line):
			failed.append(line.get_slice(" ", 0))
	if failed.is_empty() and expected.split("\n", false).size() == lines.size():
		print("BRIMHOLT_GOLDEN: %d sections match" % lines.size())
		quit(0)
	else:
		push_error("BRIMHOLT_GOLDEN: changed sections %s (digests in .tools/golden/)" % [failed])
		quit(1)


## Plays the session and returns its digests by section.
func _play() -> Dictionary:
	var arena: Vector2i = _arena()
	for id: int in PLAYERS:
		world.add_player(id, 0.0, PLAYERS[id])
		combat.grant_experience(id, Combat.total_experience(LEVEL, 0), events)
		var cell: Vector2i = arena + Vector2i(id - 2, 0)
		world.players[id]["cell"] = cell
		world.players[id]["from"] = cell
		var limits: Dictionary = world.player_stats(id)
		world.players[id]["health"] = limits["health"]
		world.players[id]["mana"] = limits["mana"]
	_note(combat.party_action(1, "invite", 2, 0.0))
	_note(combat.party_action(2, "join", 1, 0.0))
	_note(combat.party_action(1, "invite", 3, 0.0))
	_note(combat.party_action(3, "join", 1, 0.0))
	_spawn(arena, 0.0)
	var steps: int = roundi(SECONDS / STEP)
	for step: int in steps + 1:
		var time: float = step * STEP
		events.append_array(combat.tick(time))
		for id: int in PLAYERS:
			if world.players.has(id):
				_act(id, time)
		_script(step, time, arena)
	var now: float = steps * STEP
	var saves: Dictionary = {}
	var shown: Dictionary = {}
	var round_trip: Dictionary = {}
	for id: int in PLAYERS:
		if not world.players.has(id):
			continue
		saves[id] = CharacterStore.capture(world, id, now)
		shown[id] = world.export_player(id, now, true)
		var other := World.new()
		other.add_player(id, 0.0, PLAYERS[id])
		CharacterStore.restore(other, id, saves[id], now)
		round_trip[id] = CharacterStore.capture(other, id, now)
	return {
		"saves": _text(saves), "players": _text(shown), "round_trip": _text(round_trip),
		"monsters": _text(combat.monster_snapshot(now)), "ground": _text(world.ground_snapshot()),
		"events": _text(events),
	}


## What happens at fixed moments: item moves, a potion, a death, and fresh monsters (the last wave still alive at the end).
func _script(step: int, now: float, arena: Vector2i) -> void:
	match step:
		300:
			_note(world.move_item(1, {"type": "backpack", "index": 0}, {"type": "backpack", "index": 5}, now))
			_note(world.move_item(2, {"type": "backpack", "index": 1}, {"type": "ground", "cell": world.players[2]["cell"]}, now))
		320:
			_note(world.move_item(2, {"type": "ground", "cell": world.players[2]["cell"]}, {"type": "backpack"}, now))
		400:
			for index: int in world.players[3]["backpack"].size():
				if combat.drink(3, index, now)["ok"]:
					break
		600:
			world.players[3]["health"] = 1
		900, 1150:
			_spawn(arena, now)


## A player's turn: keep a target (the nearest monster), walk into reach, and cast what is ready.
func _act(id: int, now: float) -> void:
	var player: Dictionary = world.players[id]
	if player["target"] == 0 or not world.monsters.has(player["target"]):
		var best: int = 0
		var best_distance: int = 999
		for monster: int in world.monsters:
			var distance: int = Combat.distance(player["cell"], world.monsters[monster]["cell"])
			if distance < best_distance or (distance == best_distance and monster < best):
				best = monster
				best_distance = distance
		if best != 0 and best_distance <= 8:
			_note(combat.set_target(id, best, now))
	var target: int = player["target"]
	if target != 0 and world.monsters.has(target):
		var goal: Vector2i = world.monsters[target]["cell"]
		if not Combat.in_reach(player["cell"], goal, combat.reach_of(id)):
			var delta: Vector2i = goal - player["cell"]
			var direction := Vector2i(signi(delta.x), 0) if absi(delta.x) >= absi(delta.y) else Vector2i(0, signi(delta.y))
			_note(world.move(id, direction, now))
	if roundi(now / STEP) % 20 == id:
		for spell: String in Spells.for_vocation(player["vocation"]):
			var cast: Dictionary = combat.cast(id, spell, now)
			if cast["ok"]:
				_note(cast)
				break


func _spawn(arena: Vector2i, now: float) -> void:
	for entry: Array in PACK:
		var cell: Vector2i = arena + entry[2]
		if World.walkable(cell) and not world.occupied(cell, now):
			combat.spawn_monster(entry[0], entry[1], cell, now, -1, events)


func _note(result: Dictionary) -> void:
	events.append({"result": result.get("ok", false), "reason": result.get("reason", "")})
	events.append_array(result.get("events", []))


## The first open field near the first spawn: a 9x9 square of walkable ground outside every zone.
func _arena() -> Vector2i:
	var origin: Vector2i = World.SPAWNS[0]
	for radius: int in range(10, 200):
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var cell: Vector2i = origin + Vector2i(dx, dy)
				if _open(cell):
					return cell
	return origin


func _open(centre: Vector2i) -> bool:
	for dy: int in range(-4, 5):
		for dx: int in range(-4, 5):
			var cell: Vector2i = centre + Vector2i(dx, dy)
			if not World.walkable(cell) or not World.zone_at(cell).is_empty():
				return false
	return true


## A stable text form: dictionary keys sorted, floats as written.
static func _text(value: Variant) -> String:
	return JSON.stringify(value, "\t", true)
