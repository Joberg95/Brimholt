extends SceneTree
## Screenshots of places in the real game (offscreen, solo, noon, clear sky), for looking at art
## and map work: each argument is x,y (a tile) and becomes .tools/shot-x-y.png with you there;
## level=N first makes you that level (so monsters in the shot do not kill you), and night
## makes the following shots at midnight.
##
##   godot --position 99999,99999 --resolution 64x64 --path . --script res://tools/testing/shot.gd -- 140,193 120,190

const Weather = preload("res://game/render/weather.gd")

var game: Node
var screen: SubViewport


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_size(Vector2i(64, 64))
	screen = SubViewport.new()
	screen.size = Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	screen.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	screen.canvas_item_default_texture_filter = root.canvas_item_default_texture_filter
	root.add_child(screen)
	game = load("res://game/main.tscn").instantiate()
	game.close_ends_session = false
	game.keybinds.persistent = false
	game.start_vocation = "knight"
	game.allow_start_vocation = true
	screen.add_child(game)
	game.save_enabled = false
	game.identity_token = Crypto.new().generate_random_bytes(32).hex_encode()
	game.port = 0
	game.host_game()
	game._world_view.lighting.time_override = 0.5
	Weather.override = "clear"
	for argument: String in OS.get_cmdline_user_args():
		if argument == "night":
			game._world_view.lighting.time_override = 0.0
			continue
		if argument.begins_with("level="):
			var me: Dictionary = game.world.players[game.self_id]
			me["level"] = argument.get_slice("=", 1).to_int()
			me["health"] = game.world.player_stats(game.self_id)["health"]
			continue
		var parts: PackedStringArray = argument.split(",")
		var cell := Vector2i(parts[0].to_int(), parts[1].to_int())
		var player: Dictionary = game.world.players[game.self_id]
		player["cell"] = cell
		player["from"] = cell
		game._publish_actor(game.self_id)
		await create_timer(1.2).timeout
		await RenderingServer.frame_post_draw
		screen.get_texture().get_image().save_png("res://.tools/shot-%d-%d.png" % [cell.x, cell.y])
		print("SHOT .tools/shot-%d-%d.png" % [cell.x, cell.y])
	quit(0)
