extends SceneTree

const World = preload("res://game/world.gd")
const CharacterArt = preload("res://game/character_art.gd")
const TileArt = preload("res://game/tile_art.gd")
const TEST_ITEM_CELL: Vector2i = Vector2i(6, 8)
var game: Node2D
var finished: bool = false
var elapsed: float = 0.0


func _initialize() -> void:
	call_deferred("_run")


func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 10.0 and not finished:
		push_error("Visual capture timed out")
		quit(1)
	return false


func _run() -> void:
	game = load("res://game/main.tscn").instantiate()
	root.add_child(game)
	game.port = 0
	game.host_game()
	if not game.connected:
		quit(1)
		return
	var directions: Array[Vector2i] = [
		Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT,
	]
	for id: int in range(1, 5):
		if id != 1 and not game.world.add_player(id, 0.0):
			push_error("Visual test could not spawn actor")
			quit(1)
			return
		game.world.players[id]["facing"] = directions[id - 1]
		for slot: String in World.SLOTS:
			var result: Dictionary = game.world.toggle_equipment(id, slot, float(id) + World.SLOTS.find(slot))
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
	var image: Image = root.get_texture().get_image()
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
		for slot: String in World.SLOTS:
			var unequip_result: Dictionary = game.world.toggle_equipment(id, slot, 20.0 + World.SLOTS.find(slot))
			if not unequip_result["ok"]:
				push_error("Visual test unequip failed: " + unequip_result["reason"])
				quit(1)
				return
		game._apply_actor(game.world.export_player(id, 25.0, id == 1))
	await process_frame
	await RenderingServer.frame_post_draw
	var unequipped: Image = root.get_texture().get_image()
	if unequipped == null or unequipped.is_empty():
		push_error("Unequipped capture is empty")
		quit(1)
		return
	for id: int in range(1, 5):
		var center: Vector2i = Vector2i(_tile_center(game.world.players[id]["cell"]))
		var region: Rect2i = Rect2i(center - Vector2i(48, 48), Vector2i(96, 96))
		if image.get_region(region).get_data() == unequipped.get_region(region).get_data():
			push_error("Unequipping did not visibly change actor %d" % id)
			quit(1)
			return
	for slot: String in World.SLOTS:
		var slot_region: Rect2i = Rect2i(Vector2i(game.slot_position({"type": "equipment", "slot": slot})),
			Vector2i(32, 32))
		if image.get_region(slot_region).get_data() == unequipped.get_region(slot_region).get_data():
			push_error("Unequipping did not change the %s panel slot" % slot)
			quit(1)
			return
	var item_color: Color = CharacterArt.palette("iron_coif")[0]
	if not _expect(image.get_pixelv(Vector2i(_tile_center(TEST_ITEM_CELL))).is_equal_approx(item_color),
			"Ground item is not drawn on its tile"):
		return
	# Wall (8, 7) has open ground to its north/west; its raised top must cover tile (7, 6).
	var wall_top: Vector2 = game.map_to_screen(Vector2(8, 7) * World.TILE_SIZE
		- Vector2.ONE * TileArt.WALL_HEIGHT + Vector2(2.5, 6.5))
	if not _expect(image.get_pixelv(Vector2i(wall_top)).is_equal_approx(TileArt.WALL_TOP[0]),
			"Oblique wall top is not raised over the tile behind it"):
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
	print("BRIMHOLT_VISUAL_PASS four facings, visible unequip, panel slots, ground items, oblique walls, "
		+ "mouse drag/right-click, smooth midpoint/endpoint, following camera")
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
	Input.parse_input_event(event)
	await process_frame


## Real input events start the drag. Godot resolves the drop position from the OS cursor,
## which synthetic events cannot move, so the drop is delivered to the forwarded handler.
func _drag_to_map(from: Vector2, to: Vector2) -> bool:
	await _push_mouse(from, MOUSE_BUTTON_LEFT, true)
	for step: int in range(1, 9):
		var motion := InputEventMouseMotion.new()
		motion.position = from.lerp(to, step / 8.0)
		motion.global_position = motion.position
		motion.relative = (to - from) / 8.0
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(motion)
		await process_frame
	var data: Variant = root.gui_get_drag_data()
	var local: Vector2 = to - game.VIEW_ORIGIN
	var started: bool = root.gui_is_dragging() and data == {"brimholt_item": {"type": "backpack", "index": 0}}
	var accepted: bool = started and game._map_can_drop(local, data)
	root.gui_cancel_drag()
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
