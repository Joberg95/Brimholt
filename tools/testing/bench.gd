extends SceneTree
## Frame benchmark: plays solo in the real game (offscreen, vsync off, no frame cap) through
## three busy scenes and prints the frame time and where it goes (main.gd's opt-in profile).
##
##   godot --position 99999,99999 --resolution 64x64 --path . --script res://tools/testing/bench.gd
##
## Scenes: "town" (you, your companions, and the rival bands in Cinder Crossing), "hunt" (your
## group at a camp of outlaw archers, fighting), "isles" (Hrimvik's square in the snow), and "raid"
## (level 50, a full twenty-player raid at the Hollow Reach's gate). A startup line gives the time
## to start a solo game and how many camps are still dormant (Combat spawns them when visited). Numbers go to stdout as BENCH lines and to .tools/bench.txt.

const Weather = preload("res://game/render/weather.gd")
const World = preload("res://game/core/world.gd")
const WorldMap = preload("res://game/world_map/world_map.gd")
const Balance = preload("res://game/data/balance.gd")
const SECONDS: float = 8.0
const WARMUP: float = 2.0

var game: Node
var screen: SubViewport
var lines: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_size(Vector2i(64, 64))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	screen = SubViewport.new()
	screen.size = Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	screen.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	screen.canvas_item_default_texture_filter = root.canvas_item_default_texture_filter
	root.add_child(screen)
	game = load("res://game/main.tscn").instantiate()
	game.close_ends_session = false
	game.keybinds.persistent = false
	game.session.start_vocation = "knight"
	game.session.allow_start_vocation = true
	screen.add_child(game)
	game.session.save_enabled = false
	game.session.identity_token = Crypto.new().generate_random_bytes(32).hex_encode()
	game.session.port = 0
	var started: int = Time.get_ticks_usec()
	game.session.play_solo()
	_line("BENCH startup %d ms  monsters live %d  camps dormant %d" % [(Time.get_ticks_usec() - started) / 1000,
		game.world.monsters.size(), game.combat.dormant_camps()])
	Weather.override = "clear"
	if not game.session.connected:
		quit(1)
		return
	var me: Dictionary = game.world.players[game.client.self_id]
	me["level"] = 20
	await _scene("town")
	_place(_camp_of("star_mage"))
	await _scene("hunt")
	me["level"] = 35
	_place(Vector2i(80, 746))
	await _scene("isles")
	me["level"] = Balance.MAX_LEVEL
	game.api.raid_local(true)
	await _scene("raid")
	var file := FileAccess.open("res://.tools/bench.txt", FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	quit(0)


## Measures one scene: SECONDS of frames after WARMUP, with the profile on.
func _scene(name: String) -> void:
	await create_timer(WARMUP).timeout
	game.frame_profile.clear()
	game.profiling = true
	var frames: Array[float] = []
	var last: int = Time.get_ticks_usec()
	var end: int = last + int(SECONDS * 1000000.0)
	var draw_calls: float = 0.0
	while Time.get_ticks_usec() < end:
		await process_frame
		var now: int = Time.get_ticks_usec()
		frames.append((now - last) / 1000.0)
		last = now
		draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	game.profiling = false
	frames.sort()
	var total: float = 0.0
	for frame: float in frames:
		total += frame
	var average: float = total / frames.size()
	_line("BENCH %-5s %5d frames  avg %6.2f ms  p95 %6.2f ms  worst %6.2f ms  (%d fps)  draw calls %d  players %d  monsters %d" % [
		name, frames.size(), average, frames[int(frames.size() * 0.95)], frames[-1], roundi(1000.0 / average),
		roundi(draw_calls / frames.size()), game.world.players.size(), game.world.monsters.size()])
	var sections: Array = game.frame_profile.keys()
	sections.sort_custom(func(a: String, b: String) -> bool: return game.frame_profile[a][0] > game.frame_profile[b][0])
	for section: String in sections:
		var entry: Array = game.frame_profile[section]
		_line("BENCH   %-22s %6.3f ms/frame  worst %6.2f ms" % [section, entry[0] / 1000.0 / frames.size(), entry[2] / 1000.0])


func _line(text: String) -> void:
	print(text)
	lines.append(text)


func _camp_of(monster: String) -> Vector2i:
	for spawn: Dictionary in WorldMap.MONSTER_SPAWNS:
		if spawn["monster"] == monster:
			return spawn["cell"]
	return WorldMap.SPAWNS[0]


## Puts you (and so your companions) beside `cell`.
func _place(cell: Vector2i) -> void:
	var me: Dictionary = game.world.players[game.client.self_id]
	for offset: Vector2i in [Vector2i(0, 3), Vector2i(3, 0), Vector2i(0, -3), Vector2i(-3, 0)]:
		if WorldMap.walkable(cell + offset):
			me["cell"] = cell + offset
			me["from"] = me["cell"]
			break
	game.replication.publish_actor(game.client.self_id)
