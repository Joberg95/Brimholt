extends SceneTree

const World = preload("res://game/world.gd")
const SpriteArt = preload("res://game/sprite_art.gd")
const WorldViewScript = preload("res://game/world_view.gd")
const TEST_ITEM_CELL: Vector2i = Vector2i(6, 8)
var game: Node2D
## The game renders offscreen into this buffer; the real window only needs to exist.
var screen: SubViewport
var finished: bool = false
var elapsed: float = 0.0


func _initialize() -> void:
	call_deferred("_run")


func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 20.0 and not finished:
		push_error("Visual capture timed out")
		quit(1)
	return false


func _run() -> void:
	# Keep the required OS window tiny, unfocused, and in a screen corner. Launching with
	# --resolution 64x64 --position 99999,99999 avoids even a brief full-size window.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_size(Vector2i(64, 64))
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	DisplayServer.window_set_position(usable.position)
	screen = SubViewport.new()
	screen.size = Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	screen.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	screen.canvas_item_default_texture_filter = root.canvas_item_default_texture_filter
	screen.gui_embed_subwindows = true
	root.add_child(screen)
	game = load("res://game/main.tscn").instantiate()
	game.close_ends_session = false
	screen.add_child(game)
	game.port = 0
	game.host_game()
	if not game.connected:
		quit(1)
		return
	# Remove the map's monsters so pixel checks are deterministic; combat is checked at the end.
	game.world.monsters.clear()
	game.monsters.clear()
	game.combat.respawns.clear()
	var directions: Array[Vector2i] = [
		Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT,
	]
	for id: int in range(1, 5):
		if id != 1 and not game.world.add_player(id, 0.0):
			push_error("Visual test could not spawn actor")
			quit(1)
			return
		game.world.players[id]["facing"] = directions[id - 1]
		game.world.players[id]["next_item"] = 0.0
		for slot: String in SpriteArt.VISIBLE_SLOTS:
			var result: Dictionary = game.world.toggle_equipment(id, slot, float(id) + SpriteArt.VISIBLE_SLOTS.find(slot))
			if not result["ok"]:
				push_error("Visual test equipment setup failed")
				quit(1)
				return
		game._apply_actor(game.world.export_player(id, 10.0, id == 1))
	game.world.ground[TEST_ITEM_CELL] = ["iron_coif"]
	game._apply_ground(TEST_ITEM_CELL, ["iron_coif"])
	await process_frame
	await RenderingServer.frame_post_draw
	if not _expect(_centred(Vector2(5, 6)), "Camera is not centred on the local character"):
		return
	var image: Image = screen.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("A graphical renderer is required for visual capture")
		quit(1)
		return
	var result: Error = image.save_png("res://.tools/visual.png")
	if result != OK:
		push_error("Cannot save visual capture: " + error_string(result))
		quit(1)
		return
	print("BRIMHOLT_VISUAL_CAPTURE res://.tools/visual.png")
	for id: int in range(1, 5):
		for slot: String in SpriteArt.VISIBLE_SLOTS:
			var unequip_result: Dictionary = game.world.toggle_equipment(id, slot, 20.0 + SpriteArt.VISIBLE_SLOTS.find(slot))
			if not unequip_result["ok"]:
				push_error("Visual test unequip failed: " + unequip_result["reason"])
				quit(1)
				return
		game._apply_actor(game.world.export_player(id, 25.0, id == 1))
	await process_frame
	await RenderingServer.frame_post_draw
	var unequipped: Image = screen.get_texture().get_image()
	if unequipped == null or unequipped.is_empty():
		push_error("Unequipped capture is empty")
		quit(1)
		return
	for id: int in range(1, 5):
		var cell: Vector2 = game.world.players[id]["cell"]
		var corner: Vector2 = game.map_to_screen((cell + Vector2(0.5, 0.5)) * World.TILE_SIZE - SpriteArt.FRAME_ANCHOR)
		var region: Rect2i = Rect2i(Vector2i(corner), Vector2i.ONE * int(SpriteArt.FRAME * game.ZOOM))
		if image.get_region(region).get_data() == unequipped.get_region(region).get_data():
			push_error("Unequipping did not visibly change actor %d" % id)
			quit(1)
			return
	for slot: String in SpriteArt.VISIBLE_SLOTS:
		var slot_region: Rect2i = Rect2i(Vector2i(game.slot_position({"type": "equipment", "slot": slot})),
			Vector2i(32, 32))
		if image.get_region(slot_region).get_data() == unequipped.get_region(slot_region).get_data():
			push_error("Unequipping did not change the %s panel slot" % slot)
			quit(1)
			return
	var icon_origin: Vector2 = Vector2(TEST_ITEM_CELL) * World.TILE_SIZE
	if not _expect(_matches_texel(image, SpriteArt.ITEM_ICONS, SpriteArt.item_region("iron_coif"), icon_origin),
			"Ground item sprite is not drawn on its tile"):
		return
	# Wall (8, 7) has open ground to its north/west; its raised top must cover tile (7, 6).
	var wall_origin: Vector2 = Vector2(8, 7) * World.TILE_SIZE - Vector2.ONE * SpriteArt.WALL_RAISE
	var wall_region: Rect2 = SpriteArt.wall_region(Vector2i(8, 7))
	if not _expect(_matches_texel(image, SpriteArt.WALLS, Rect2(wall_region.position + Vector2(2, 6), Vector2(4, 4)),
			wall_origin + Vector2(2, 6)), "Oblique wall top is not raised over the tile behind it"):
		return
	if unequipped.save_png("res://.tools/visual-unequipped.png") != OK:
		push_error("Cannot save unequipped capture")
		quit(1)
		return
	if not await _check_mouse_inventory():
		return
	var camera_start: float = game._world_view.position.x
	game.move_local(Vector2i.RIGHT)
	await create_timer(World.MOVE_SECONDS / 2.0).timeout
	var midpoint: float = game.actors[1]["visual"].x
	if midpoint <= 5.0 or midpoint >= 6.0:
		push_error("Movement did not interpolate between approved tiles")
		quit(1)
		return
	var camera_mid: float = game._world_view.position.x
	if not _expect(camera_mid < camera_start and camera_mid > camera_start - World.TILE_SIZE * game.ZOOM,
			"Camera did not glide with the character"):
		return
	await create_timer(World.MOVE_SECONDS).timeout
	await process_frame
	if not game.actors[1]["visual"].is_equal_approx(Vector2(6, 6)):
		push_error("Movement interpolation missed its endpoint")
		quit(1)
		return
	if not _expect(_centred(Vector2(6, 6)), "Camera did not follow the character to its new tile"):
		return
	if not await _check_ferry_and_maps():
		return
	print("BRIMHOLT_VISUAL_PASS four facings, visible unequip, panel slots, ground items, oblique walls, "
		+ "mouse drag/right-click, smooth midpoint/endpoint, following camera, trees, NPC menu and ferry trips, "
		+ "PvP island banner, action bar key, world map, click-to-target combat")
	finished = true
	await game.leave_game()
	quit()


func _push_mouse(at: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = button
	event.pressed = pressed
	if pressed and button == MOUSE_BUTTON_LEFT:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	screen.push_input(event, true)
	await process_frame


## Real input events start the drag; the drop is then delivered to the map's forwarded handler
## so the check does not depend on Godot's cursor tracking.
func _drag_to_map(from: Vector2, to: Vector2) -> bool:
	var expected: Dictionary = {"brimholt_item": {"type": "backpack", "index": 0}}
	var data: Variant = null
	var started: bool = false
	# Retry a few times in case window-manager events interrupt the synthetic drag.
	for attempt: int in 3:
		await _push_mouse(from, MOUSE_BUTTON_LEFT, true)
		for step: int in range(1, 9):
			var motion := InputEventMouseMotion.new()
			motion.position = from.lerp(to, step / 8.0)
			motion.global_position = motion.position
			motion.relative = (to - from) / 8.0
			motion.button_mask = MOUSE_BUTTON_MASK_LEFT
			screen.push_input(motion, true)
			await process_frame
		data = screen.gui_get_drag_data()
		started = screen.gui_is_dragging() and data == expected
		if started:
			break
		await _push_mouse(from, MOUSE_BUTTON_LEFT, false)
	var local: Vector2 = to - game.VIEW_ORIGIN
	var accepted: bool = started and game._map_can_drop(local, data)
	screen.gui_cancel_drag()
	await _push_mouse(to, MOUSE_BUTTON_LEFT, false)
	if not _expect(started, "Mouse drag did not pick up the backpack item") \
			or not _expect(accepted, "Map rejected a valid item drop"):
		return false
	game._map_drop(local, data)
	return true


func _expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition


## Real GUI input: drag a backpack item to a tile, right-click the tile, right-click to equip.
func _check_mouse_inventory() -> bool:
	var player: Dictionary = game.world.players[1]
	player["next_item"] = 0.0
	var slot_center: Vector2 = game.slot_position({"type": "backpack", "index": 0}) + Vector2.ONE * World.TILE_SIZE / 2.0
	var cell: Vector2i = player["cell"] + Vector2i.DOWN
	var tile_center: Vector2 = _tile_center(cell)
	if not await _drag_to_map(slot_center, tile_center):
		return false
	if not _expect(game.world.ground_stack(cell) == ["ember_cap"] and player["backpack"][0] == "",
			"Mouse drag did not drop the backpack item on the tile"):
		return false
	await create_timer(World.ITEM_SECONDS + 0.05).timeout
	await _push_mouse(tile_center, MOUSE_BUTTON_RIGHT, true)
	await _push_mouse(tile_center, MOUSE_BUTTON_RIGHT, false)
	if not _expect(game.world.ground_stack(cell).is_empty() and player["backpack"][0] == "ember_cap",
			"Right-clicking the tile did not pick up its item"):
		return false
	await create_timer(World.ITEM_SECONDS + 0.05).timeout
	await _push_mouse(slot_center, MOUSE_BUTTON_RIGHT, true)
	await _push_mouse(slot_center, MOUSE_BUTTON_RIGHT, false)
	if not _expect(player["equipment"].get("helmet", "") == "ember_cap" and game.actors[1]["state"]["backpack"][0] == "",
			"Right-clicking the backpack item did not equip it"):
		return false
	await process_frame
	return true


func _tile_center(cell: Vector2) -> Vector2:
	return game.map_to_screen((cell + Vector2(0.5, 0.5)) * World.TILE_SIZE)


func _centred(cell: Vector2) -> bool:
	return _tile_center(cell).distance_to(game.VIEW_ORIGIN + game.VIEW_SIZE / 2.0) <= 1.0


## Compares the screen with the first opaque texel nearest the centre of a sprite region.
func _matches_texel(screen: Image, texture: Texture2D, region: Rect2, map_origin: Vector2) -> bool:
	var sheet: Image = texture.get_image()
	var best: Vector2i = Vector2i(-1, -1)
	var center: Vector2 = region.size / 2.0
	for y: int in int(region.size.y):
		for x: int in int(region.size.x):
			var texel: Color = sheet.get_pixelv(Vector2i(region.position) + Vector2i(x, y))
			if texel.a >= 1.0 and (best.x < 0 or Vector2(x, y).distance_to(center) < Vector2(best).distance_to(center)):
				best = Vector2i(x, y)
	if best.x < 0:
		return false
	var expected: Color = sheet.get_pixelv(Vector2i(region.position) + best)
	var at: Vector2 = game.map_to_screen(map_origin + Vector2(best) + Vector2(0.5, 0.5))
	return screen.get_pixelv(Vector2i(at)).is_equal_approx(expected)


## A tree whose canopy no tree, wall, or ferryman in front covers, and a free tile beside or
## behind it for the camera to centre on.
func _forest_spot() -> Array:
	for y: int in range(20, World.height() - 4):
		for x: int in range(30, World.width() - 4):
			var tree := Vector2i(x, y)
			if World.terrain(tree) != "T":
				continue
			var clear: bool = true
			for ox: int in range(-2, 3):
				for oy: int in range(1, 4):
					var front: Vector2i = tree + Vector2i(ox, oy)
					clear = clear and World.terrain(front) not in ["T", "#", " "] and not World.NPC_CELLS.has(front)
			if not clear:
				continue
			for dy: int in range(-4, 1):
				for dx: int in range(-4, 5):
					var stand: Vector2i = tree + Vector2i(dx, dy)
					if (absi(dx) >= 3 or dy <= -3) and World.walkable(stand) and not game.world.occupied(stand, game._now()):
						return [tree, stand]
	return []


## Presses the first key bound to an action, as the player's own bindings define it.
func _press(action: String) -> void:
	var code: Key = game.keybinds.keys[action][0]
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	screen.push_input(event, true)
	await process_frame


## Sail with the real ferry menu, then open the world map with M.
func _check_ferry_and_maps() -> bool:
	var player: Dictionary = game.world.players[1]
	var spot: Array = _forest_spot()
	if not _expect(not spot.is_empty(), "No unobstructed tree on the map"):
		return false
	player["cell"] = spot[1]
	player["from"] = spot[1]
	game._publish_actor(1)
	await process_frame
	await RenderingServer.frame_post_draw
	var forest: Image = screen.get_texture().get_image()
	forest.save_png("res://.tools/visual-forest.png")
	var variant: int = SpriteArt.noise(spot[0], 7) % SpriteArt.TREE_VARIANTS
	var tree_origin: Vector2 = (Vector2(spot[0]) + Vector2(0.5, 0.5)) * World.TILE_SIZE - SpriteArt.TREE_ANCHOR
	if not _expect(_matches_texel(forest, SpriteArt.OBJECTS, Rect2(Vector2(variant * SpriteArt.TREE_SIZE.x, 0),
			SpriteArt.TREE_SIZE), tree_origin), "Tree sprite is not drawn on its tile"):
		return false
	var dock: Vector2i = game.world.arrival_cell("cinder_landing", game._now())
	player["cell"] = dock
	player["from"] = dock
	game._publish_actor(1)
	await process_frame
	await RenderingServer.frame_post_draw
	screen.get_texture().get_image().save_png("res://.tools/visual-landing.png")
	if not await _sail("cinder_landing", "mossford"):
		return false
	var gold: int = player["gold"]
	dock = game.world.arrival_cell("reedmere", game._now())
	player["cell"] = dock
	player["from"] = dock
	player["next_travel"] = 0.0
	game._publish_actor(1)
	await process_frame
	if not await _sail("reedmere", "blackreed_isle"):
		return false
	await process_frame
	await RenderingServer.frame_post_draw
	screen.get_texture().get_image().save_png("res://.tools/visual-isle.png")
	if not _expect(game._zone_label.visible and game._zone_label.text.contains("PvP") and game._zone_label.text.contains("40-50")
			and player["gold"] == gold - World.FERRYMEN["reedmere"]["routes"]["blackreed_isle"],
			"Arriving on Blackreed Isle did not show the PvP zone banner"):
		return false
	player["next_item"] = 0.0
	var helmet: String = player["equipment"].get("helmet", "")
	await _press("slot_1")
	if not _expect(not helmet.is_empty() and not player["equipment"].has("helmet"), "Action bar key 1 did not toggle the helmet"):
		return false
	await _press("world_map")
	await process_frame
	await RenderingServer.frame_post_draw
	var world_map: Image = screen.get_texture().get_image()
	world_map.save_png("res://.tools/visual-map.png")
	var map_size := Vector2(World.width(), World.height())
	var scale: float = maxf(1.0, floorf(minf(game.VIEW_SIZE.x / map_size.x, (game.VIEW_SIZE.y - 32.0) / map_size.y)))
	var origin: Vector2 = ((game.VIEW_SIZE - map_size * scale) / 2.0).floor() + Vector2(0, 12)
	var corner: Vector2i = Vector2i(World.width() - 1, World.height() - 1)
	var pixel: Vector2 = game.VIEW_ORIGIN + origin + (Vector2(corner) + Vector2(0.5, 0.5)) * scale
	if not _expect(game._world_map.visible and world_map.get_pixelv(Vector2i(pixel)).is_equal_approx(
			game.MAP_COLORS[World.terrain(corner)]), "The world map key did not open the world map"):
		return false
	await _press("world_map")
	if not _expect(not game._world_map.visible, "M did not close the world map"):
		return false
	return await _check_combat()


## Right-click a ferryman, choose Travel in his menu, then the destination.
func _sail(from: String, to: String) -> bool:
	var player: Dictionary = game.world.players[1]
	var gold: int = player["gold"]
	var ferryman: Vector2i = World.FERRYMEN[from]["cell"]
	await _push_mouse(_tile_center(ferryman), MOUSE_BUTTON_RIGHT, true)
	await _push_mouse(_tile_center(ferryman), MOUSE_BUTTON_RIGHT, false)
	if not _expect(game._npc_menu.visible and game._npc_menu_target == from, "Right-clicking %s opened no menu" % from):
		return false
	var travel: int = -1
	for index: int in game._npc_menu.item_count:
		if game._npc_menu.get_item_text(index) == "Travel":
			travel = game._npc_menu.get_item_id(index)
	game._npc_menu.id_pressed.emit(travel)
	game._npc_menu.hide()
	if not _expect(travel >= 0 and game._travel_panel.visible and game._talking_to == from,
			"Choosing Travel did not open the routes"):
		return false
	var pressed: bool = false
	for child: Node in game._travel_list.get_children():
		if child is Button and child.text.begins_with(World.FERRYMEN[to]["place"]) and not child.disabled:
			child.pressed.emit()
			pressed = true
	await process_frame
	return _expect(pressed and not game._travel_panel.visible and player["gold"] == gold - World.FERRYMEN[from]["routes"][to]
		and World.chebyshev(player["cell"], World.FERRYMEN[to]["cell"]) <= World.TALK_RANGE,
		"The ferry did not sail from %s to %s" % [from, to])


## Spawns two monsters beside the player, locks one with a real left-click, and checks the
## red target square, nameplates, and a hit.
func _check_combat() -> bool:
	var player: Dictionary = game.world.players[1]
	player["target"] = 0
	player["next_attack"] = 0.0
	player["health"] = game.world.player_stats(1)["health"]
	var spawned: Array[int] = []
	for step: Vector2i in [Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT]:
		var cell: Vector2i = player["cell"] + step * 2
		if spawned.size() < 2 and World.walkable(cell) and not game.world.occupied(cell, game._now()):
			var events: Array = []
			var id: int = game.combat.spawn_monster("field_vole" if spawned.is_empty() else "stone_golem", 1, cell,
				game._now(), -1, events)
			game.world.monsters[id]["health"] = 1000
			game.world.monsters[id]["max_health"] = 1000
			# Hold still so the click lands on the monster's tile.
			game.world.monsters[id]["next_move"] = INF
			game.world.monsters[id]["next_attack"] = INF
			game._handle_events(events)
			spawned.append(id)
	if not _expect(spawned.size() == 2, "No room for monsters beside the player"):
		return false
	await process_frame
	var target_cell: Vector2i = game.world.monsters[spawned[0]]["cell"]
	await _push_mouse(_tile_center(target_cell), MOUSE_BUTTON_LEFT, true)
	await _push_mouse(_tile_center(target_cell), MOUSE_BUTTON_LEFT, false)
	if not _expect(player["target"] == spawned[0] and game.own_target() == spawned[0], "Left-clicking a monster did not lock it"):
		return false
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var image: Image = screen.get_texture().get_image()
	image.save_png("res://.tools/visual-combat.png")
	var corner: Vector2 = Vector2(game.world.monsters[spawned[0]]["cell"]) * World.TILE_SIZE
	var edge: Vector2 = game.map_to_screen(corner + Vector2(1.5, World.TILE_SIZE / 2.0))
	if not _expect(image.get_pixelv(Vector2i(edge)).is_equal_approx(WorldViewScript.TARGET_COLOR), "The target square is not drawn"):
		return false
	var hit: bool = false
	for effect: Dictionary in game.effects:
		hit = hit or effect["kind"] == "text"
	return _expect(hit and game.world.monsters[spawned[0]]["health"] < 1000, "The locked monster was not attacked")
