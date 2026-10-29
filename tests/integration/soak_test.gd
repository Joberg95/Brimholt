extends SceneTree
## Soak test: hosts a game (offscreen, no saves) and keeps it busy: the player is moved around
## the overworld, monsters are killed so loot spills and they respawn, effects and particles
## fire, and the clock jumps ahead so respawns and ground decay run. Object, node, and memory
## counts are sampled; after a warm-up they must level off, and pools and caches must stay
## bounded. Fails (exit 1) on growth or an error.
##   godot --position 99999,99999 --resolution 64x64 --path . --script res://tests/integration/soak_test.gd

const World = preload("res://game/core/world.gd")
const ROUNDS: int = 36
const FRAMES_PER_ROUND: int = 20
## Clock jump per round: long enough for respawns, and over the run for ground to decay.
const SKEW_PER_ROUND: float = 120.0
## After the warm-up third, the last third may exceed the middle third by at most this share.
const GROWTH_LIMIT: float = 0.03

var game: Node
var screen: SubViewport
var samples: Array = []
## Every cell that held a ground stack at a sample.
var ever_ground: Dictionary = {}
var deadline: float = 0.0


func _initialize() -> void:
	deadline = Time.get_ticks_msec() / 1000.0 + 150.0
	call_deferred("_setup")


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() / 1000.0 > deadline:
		printerr("BRIMHOLT_SOAK_FAIL timed out")
		quit(1)
	return false


func _setup() -> void:
	screen = SubViewport.new()
	screen.size = Vector2i(1200, 740)
	screen.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(screen)
	game = load("res://game/main.tscn").instantiate()
	game.close_ends_session = false
	game.save_enabled = false
	screen.add_child(game)
	game.port = 0
	game.host_game()
	_run()


func _run() -> void:
	await process_frame
	await process_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var player: Dictionary = game.world.players[1]
	player["level"] = 50
	var spots: Array[Vector2i] = []
	for spawn: Dictionary in World.MONSTER_SPAWNS:
		spots.append(spawn["cell"])
	for zone: Dictionary in World.ZONES:
		if zone["town"]:
			spots.append(zone["rect"].get_center())
	var drops: int = 0
	for round_index: int in ROUNDS:
		var spot: Vector2i = spots[rng.randi_range(0, spots.size() - 1)]
		var cell: Vector2i = _free_near(spot)
		player["cell"] = cell
		player["from"] = cell
		player["health"] = game.world.player_stats(1)["health"]
		game.replication.publish_actor(1)
		for frame: int in FRAMES_PER_ROUND:
			var now: float = game._now()
			# Kill a nearby monster now and then: loot spills, death effects fire, a respawn queues.
			if frame % 4 == 0:
				for id: int in game.world.monsters.keys():
					if game.combat.distance(game.world.monsters[id]["cell"], cell) <= 6:
						var events: Array = []
						game.combat._damage(1, id, 999999, "critical", now, events)
						game.replication.handle_events(events)
						break
			# A dropped stack of junk on the player's tile (decays later).
			if frame == 1 and World.walkable(cell):
				game.world.ground[cell] = ["glowcap#3"]
				game.replication.publish_ground([cell])
				drops += 1
			await process_frame
		game.clock_skew += SKEW_PER_ROUND
		for ground_cell: Vector2i in game.world.ground:
			ever_ground[ground_cell] = true
		samples.append(_sample())
	_report(drops)


func _free_near(spot: Vector2i) -> Vector2i:
	for radius: int in range(0, 6):
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				var cell: Vector2i = spot + Vector2i(dx, dy)
				if World.walkable(cell) and not game.world.occupied(cell, game._now(), 1):
					return cell
	return World.SPAWNS[0]


func _sample() -> Dictionary:
	var view: Node2D = game._world_view
	return {
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		"memory": Performance.get_monitor(Performance.MEMORY_STATIC),
		"ground": game.world.ground.size(),
		"claims": game.combat.loot_claims.size(),
		"monsters": game.world.monsters.size(),
		"lights": view.lighting._pool.size(),
		"particles": view.fx.get_child_count(),
		"effects": game.client.effects.size(),
		"chunks": view.floor_layer._chunks.size(),
	}


func _mean(key: String, from: int, to: int) -> float:
	var total: float = 0.0
	for index: int in range(from, to):
		total += samples[index][key]
	return total / maxf(1.0, to - from)


func _report(drops: int) -> void:
	var third: int = samples.size() / 3
	var failures: PackedStringArray = []
	for key: String in ["objects", "nodes", "memory"]:
		var middle: float = _mean(key, third, 2 * third)
		var last: float = _mean(key, 2 * third, samples.size())
		printerr("SOAK %-9s middle %.0f last %.0f (%+.1f%%)" % [key, middle, last, (last / maxf(1.0, middle) - 1.0) * 100.0])
		if last > middle * (1.0 + GROWTH_LIMIT):
			failures.append("%s keeps growing (%.0f -> %.0f)" % [key, middle, last])
	var final: Dictionary = samples.back()
	printerr("SOAK final %s after %d drops" % [final, drops])
	if final["orphans"] > 0:
		failures.append("%d orphan nodes" % final["orphans"])
	if final["lights"] > game._world_view.lighting.MAX_LIGHTS:
		failures.append("light pool exceeded its cap")
	# Stacks older than the decay time are gone: only recent drops (and starting items) remain.
	var recent: int = ceili(World.GROUND_DECAY_SECONDS / SKEW_PER_ROUND) + 1
	printerr("SOAK ground cells ever %d, now %d" % [ever_ground.size(), final["ground"]])
	if final["ground"] > World.GROUND_ITEMS.size() + recent * 8:
		failures.append("ground stacks are not decaying (%d now, %d ever)" % [final["ground"], ever_ground.size()])
	var spawned: int = 0
	for spawn: Dictionary in World.MONSTER_SPAWNS:
		spawned += spawn["count"]
	if final["monsters"] > spawned + 40:
		failures.append("more monsters than spawn slots (%d > %d)" % [final["monsters"], spawned])
	# Loot claims are swept with their stacks: never more claims than loot on the ground.
	if final["claims"] > final["ground"]:
		failures.append("loot claims outlive their loot (%d claims, %d ground tiles)" % [final["claims"], final["ground"]])
	game.leave_game()
	await process_frame
	if failures.is_empty():
		print("BRIMHOLT_SOAK_PASS %d rounds, %d clock-skipped hours, objects/nodes/memory level, pools bounded"
			% [ROUNDS, int(ROUNDS * SKEW_PER_ROUND / 3600.0)])
		quit(0)
	else:
		printerr("BRIMHOLT_SOAK_FAIL " + "; ".join(failures))
		quit(1)
