extends SceneTree

const CAPES: Array[String] = ["silverleaf_cape", "cobalt_cape", "ember_cape", "dusk_cape"]

const World = preload("res://game/core/world.gd")
const SpriteArt = preload("res://game/render/sprite_art.gd")
const WorldViewScript = preload("res://game/render/world_view.gd")
const WorldOverlay = preload("res://game/render/world_overlay.gd")
const Monsters = preload("res://game/data/monsters.gd")
const EndgameZone = preload("res://tools/generators/endgame_zone.gd")
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
	# Never touch the player's real saves or identity.
	game.save_enabled = false
	game.identity_token = Crypto.new().generate_random_bytes(32).hex_encode()
	game.port = 0
	game.host_game()
	# Pixel checks compare against sprite texels, so pin bright noon; night is checked at the end.
	game._world_view.lighting.time_override = 0.5
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
		# Capes are later-stage gear: level 20+, one tier per actor.
		game.world.players[id]["level"] = 20 + 5 * (id - 1)
		game.world.players[id]["backpack"][5] = CAPES[id - 1]
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
	if not await _check_relics():
		return
	if not await _check_town_services():
		return
	if not await _check_hollow_reach():
		return
	if not await _check_night_and_particles():
		return
	print("BRIMHOLT_VISUAL_PASS four facings, visible unequip, panel slots, ground items, oblique walls, "
		+ "mouse drag/right-click, smooth midpoint/endpoint, following camera, trees, NPC menu and ferry trips, "
		+ "PvP island banner, action bar spell key, world map, click-to-target combat, relic quest and glow, vendor/potion key/bank depot/pack slots, Hollow Reach gate and throne room, night lighting and particles")
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


## Right-clicks an NPC and chooses one of their services from the real menu.
func _open_service(npc: String, service: String) -> bool:
	var cell: Vector2i = World.npc(npc)["cell"]
	await _push_mouse(_tile_center(cell), MOUSE_BUTTON_RIGHT, true)
	await _push_mouse(_tile_center(cell), MOUSE_BUTTON_RIGHT, false)
	if not _expect(game._npc_menu.visible and game._npc_menu_target == npc, "Right-clicking %s opened no menu" % npc):
		return false
	var chosen: int = -1
	for index: int in game._npc_menu.item_count:
		if game._npc_menu.get_item_text(index) == service:
			chosen = game._npc_menu.get_item_id(index)
	game._npc_menu.id_pressed.emit(chosen)
	game._npc_menu.hide()
	await process_frame
	return _expect(chosen >= 0 and game._travel_panel.visible and game._talking_to == npc, "%s did not open %s" % [service, npc])


func _move_beside(npc: String) -> void:
	var player: Dictionary = game.world.players[1]
	var cell: Vector2i = World.npc(npc)["cell"]
	for step: Vector2i in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
		if World.walkable(cell + step):
			player["cell"] = cell + step
			player["from"] = cell + step
			break
	game._publish_actor(1)
	await process_frame
	await process_frame


## Distinct colours in a screen rectangle: an empty slot has a few, a drawn icon many.
func _colours(image: Image, area: Rect2) -> int:
	var seen: Dictionary = {}
	for y: int in range(int(area.position.y), int(area.end.y)):
		for x: int in range(int(area.position.x), int(area.end.x)):
			seen[image.get_pixel(x, y).to_html()] = true
	return seen.size()


## Buys potions with the vendor's real Buy button, drinks one with the potion key, deposits the
## stack into the depot by right-clicking it while the bank is open, and checks that the depot,
## the pack slot, and the unlocked backpack slots are drawn.
func _check_town_services() -> bool:
	var player: Dictionary = game.world.players[1]
	player["gold"] = 500
	player["next_item"] = 0.0
	for index: int in player["backpack"].size():
		player["backpack"][index] = ""
	await _move_beside("cinder_vendor")
	if not await _open_service("cinder_vendor", "Trade"):
		return false
	var buy: Button = null
	for row: Node in game._travel_list.find_children("*", "HBoxContainer", true, false):
		var named: bool = false
		for child: Node in row.get_children():
			named = named or (child is Label and child.text.begins_with("Health potion"))
		for child: Node in row.get_children():
			if named and child is Button and child.text == "Buy 10":
				buy = child
	if not _expect(buy != null and not buy.disabled and game.dialogs.mode == "trade", "The vendor offers no health potions"):
		return false
	buy.pressed.emit()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	screen.get_texture().get_image().save_png("res://.tools/visual-trade.png")
	if not _expect(player["backpack"][0] == "health_potion#10" and player["gold"] == 500 - 10 * World.ITEMS["health_potion"]["price"]
			and game._travel_list.get_child(1).text.contains(str(player["gold"])), "Buying potions did not update the trade window"):
		return false
	player["health"] = 1
	game._publish_actor(1)
	await process_frame
	await _press("health_potion")
	await process_frame
	if not _expect(player["health"] > 1 and player["backpack"][0] == "health_potion#9", "The potion key did not drink a potion"):
		return false
	game._close_travel()
	await create_timer(World.ITEM_SECONDS + 0.05).timeout
	await _move_beside("cinder_banker")
	if not await _open_service("cinder_banker", "Bank") or not _expect(game.dialogs.banking(), "The bank dialog is not open"):
		return false
	var slot_center: Vector2 = game.slot_position({"type": "backpack", "index": 0}) + Vector2.ONE * World.TILE_SIZE / 2.0
	await _push_mouse(slot_center, MOUSE_BUTTON_RIGHT, true)
	await _push_mouse(slot_center, MOUSE_BUTTON_RIGHT, false)
	if not _expect(player["depot"][0] == "health_potion#9" and player["backpack"][0] == "",
			"Right-clicking a backpack item with the bank open did not deposit it"):
		return false
	game.world.wear_pack(1, "pathfinder_pack")
	game._publish_actor(1)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = screen.get_texture().get_image()
	image.save_png("res://.tools/visual-bank.png")
	var depot_slot: Control = null
	for slot: Control in game.inventory._slots:
		if is_instance_valid(slot) and slot.get_meta("location") == {"type": "depot", "index": 0}:
			depot_slot = slot
	var bag: Rect2 = Rect2(game.slot_position({"type": "equipment", "slot": "bag"}), Vector2.ONE * World.TILE_SIZE)
	var last: Rect2 = Rect2(game.slot_position({"type": "backpack", "index": World.BACKPACK_MAX - 1}), Vector2.ONE * World.TILE_SIZE)
	return _expect(depot_slot != null and _colours(image, depot_slot.get_global_rect()) > 12, "The depot slot did not draw its item") \
		and _expect(_colours(image, bag) > _colours(image, last) + 4, "The pack slot did not draw the worn pack") \
		and _expect(game.inventory.capacity() == World.BACKPACK_MAX and not game.inventory._locked({"type": "backpack", "index": World.BACKPACK_MAX - 1})
			and _colours(image, last) <= 6, "The pack did not unlock the last backpack slot")


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
	if not await _sail("cinder_landing", "lastlight"):
		return false
	player["gold"] = 400
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
	var spells_only: bool = game.keybinds.bar.all(func(entry: String) -> bool:
		return entry.is_empty() or entry.begins_with("spell:"))
	if not _expect(spells_only and game.keybinds.bar.has("spell:light_heal"), "The action bar holds something other than spells"):
		return false
	game.keybinds.set_bar(0, "spell:light_heal")
	var mana: int = player["mana"]
	await _press("slot_1")
	if not _expect(player["cooldowns"].get("light_heal", 0.0) > game._now() and player["mana"] < mana,
			"Action bar key 1 did not cast its spell"):
		return false
	await _press("world_map")
	await process_frame
	await RenderingServer.frame_post_draw
	var world_map: Image = screen.get_texture().get_image()
	world_map.save_png("res://.tools/visual-map.png")
	var map_size := Vector2(World.width(), World.height())
	var fit: float = minf(game.VIEW_SIZE.x / map_size.x, (game.VIEW_SIZE.y - 32.0) / map_size.y)
	var scale: float = floorf(fit) if fit >= 1.0 else fit
	var origin: Vector2 = ((game.VIEW_SIZE - map_size * scale) / 2.0).floor() + Vector2(0, 12)
	# A tile a little inside the south-east border (forest), sampled at its scaled centre.
	var corner: Vector2i = Vector2i(World.width() - 2, World.height() - 2)
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
	if not _expect(image.get_pixelv(Vector2i(edge)).is_equal_approx(WorldOverlay.TARGET_COLOR), "The target square is not drawn"):
		return false
	var hit: bool = false
	for effect: Dictionary in game.effects:
		hit = hit or effect["kind"] == "text"
	return _expect(hit and game.world.monsters[spawned[0]]["health"] < 1000, "The locked monster was not attacked")


## Claims a relic through Ysolde's real right-click Quests window, then checks that the additive
## glow layer lights relic gear, a relic on the ground, and two bosses.
func _check_relics() -> bool:
	game.world.monsters.clear()
	game.monsters.clear()
	var player: Dictionary = game.world.players[1]
	var keeper: Vector2i = World.QUEST_GIVERS["relic_keeper"]["cell"]
	var beside: Vector2i = keeper + Vector2i.DOWN
	player["cell"] = beside
	player["from"] = beside
	player["target"] = 0
	player["level"] = 50
	player["trophies"] = {"morvain": 1}
	player["backpack"][World.BACKPACK_SIZE - 1] = ""
	player["next_item"] = 0.0
	game._publish_actor(1)
	await process_frame
	await process_frame
	await _push_mouse(_tile_center(keeper), MOUSE_BUTTON_RIGHT, true)
	await _push_mouse(_tile_center(keeper), MOUSE_BUTTON_RIGHT, false)
	if not _expect(game._npc_menu.visible and game._npc_menu_target == "relic_keeper", "Right-clicking Ysolde opened no menu"):
		return false
	var quests: int = -1
	for index: int in game._npc_menu.item_count:
		if game._npc_menu.get_item_text(index) == "Quests":
			quests = game._npc_menu.get_item_id(index)
	game._npc_menu.id_pressed.emit(quests)
	game._npc_menu.hide()
	if not _expect(quests >= 0 and game._travel_panel.visible and game._talking_to == "relic_keeper",
			"Choosing Quests did not open the relic quests"):
		return false
	var claim: Button = null
	var locked: int = 0
	for child: Node in game._travel_list.get_children():
		if child is Button and child.text.contains("Abyssal plate"):
			claim = child
		elif child is Button and child.text.contains("Claim") and child.disabled:
			locked += 1
	var others: int = 0
	for boss: String in Monsters.MONSTERS:
		if boss != "morvain":
			others += Monsters.MONSTERS[boss].get("relics", []).size()
	if not _expect(claim != null and not claim.disabled and locked == others,
			"The quest window should offer Morvain's relics and lock the bosses you have not slain"):
		return false
	claim.pressed.emit()
	await process_frame
	var plate: int = player["backpack"].find("abyssal_plate")
	if not _expect(plate >= 0 and player["trophies"].is_empty() and not game._travel_panel.visible,
			"Claiming did not trade the trophy for the relic"):
		return false
	if not _expect(game.world.move_item(1, {"type": "backpack", "index": plate}, {"type": "equipment", "slot": "armor"}, game._now())["ok"],
			"The claimed relic could not be worn"):
		return false
	player["equipment"]["helmet"] = "abyssal_greathelm"
	player["equipment"]["main_hand"] = "cinderheart_bow"
	player["equipment"]["cape"] = "hollowbloom_cape"
	player["facing"] = Vector2i.DOWN
	game._publish_actor(1)
	var free: Array[Vector2i] = []
	for dy: int in range(-3, 4):
		for dx: int in range(-4, 5):
			var cell: Vector2i = beside + Vector2i(dx, dy)
			if absi(dx) >= 2 and World.walkable(cell) and not game.world.occupied(cell, game._now()) and not game.world.ground.has(cell):
				free.append(cell)
	if not _expect(free.size() >= 3, "No room around the Relic keeper for the relic showcase"):
		return false
	var relic_cell: Vector2i = free[0]
	game.world.ground[relic_cell] = ["verdant_codex"]
	game._apply_ground(relic_cell, ["verdant_codex"])
	var bosses: Array[int] = []
	for kind: String in ["morvain", "kharzul"]:
		var events: Array = []
		var cell: Vector2i = free[-1] if bosses.is_empty() else free[free.size() / 2]
		var id: int = game.combat.spawn_monster(kind, 50, cell, game._now(), -1, events)
		game.world.monsters[id]["next_move"] = INF
		game.world.monsters[id]["next_attack"] = INF
		game._handle_events(events)
		bosses.append(id)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var lit: Image = screen.get_texture().get_image()
	lit.save_png("res://.tools/visual-relics.png")
	game._world_view.glow.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	var plain: Image = screen.get_texture().get_image()
	game._world_view.glow.visible = true
	var spots: Dictionary = {"the relic-wearing player": beside, "the relic on the ground": relic_cell}
	for id: int in bosses:
		spots[Monsters.MONSTERS[game.world.monsters[id]["kind"]]["name"]] = game.world.monsters[id]["cell"]
	for label: String in spots:
		var corner: Vector2 = game.map_to_screen(Vector2(spots[label]) * World.TILE_SIZE - Vector2(8, 24))
		var region := Rect2i(Vector2i(corner), Vector2i(48, 56) * int(game.ZOOM))
		if not _expect(lit.get_region(region).get_data() != plain.get_region(region).get_data(), "No glow around %s" % label):
			return false
	return true


## The endgame zone: its gate from the forest, and Vaelith in the Sanctum's throne room.
func _check_hollow_reach() -> bool:
	game.world.monsters.clear()
	game.monsters.clear()
	game.world.ground.clear()
	game.ground_view.clear()
	var player: Dictionary = game.world.players[1]
	var zone: Dictionary = World.ZONES.filter(func(candidate: Dictionary) -> bool: return candidate["name"] == "The Hollow Reach")[0]
	var gate: Vector2i = Vector2i(zone["rect"].position.x - 3, EndgameZone.GATE_Y)
	for stop: Array in [[gate, "visual-hollow-gate.png"], [EndgameZone.THRONE_SEAT + Vector2i(-5, 0), "visual-hollow-throne.png"]]:
		player["cell"] = stop[0]
		player["from"] = stop[0]
		player["facing"] = Vector2i.RIGHT
		game._publish_actor(1)
		if stop[1] == "visual-hollow-throne.png":
			var events: Array = []
			var boss: int = game.combat.spawn_monster("vaelith", 50, EndgameZone.THRONE_SEAT, game._now(), -1, events)
			game.world.monsters[boss]["next_move"] = INF
			game.world.monsters[boss]["next_attack"] = INF
			game._handle_events(events)
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		var image: Image = screen.get_texture().get_image()
		image.save_png("res://.tools/" + stop[1])
		if not _expect(game._zone_label.visible == (stop[1] != "visual-hollow-gate.png") or stop[1] == "visual-hollow-gate.png",
				"Zone banner state is wrong"):
			return false
	if not _expect(game._zone_label.visible and game._zone_label.text.contains("The Hollow Reach")
			and game._zone_label.text.contains("HIGH-RISK PvP"), "Entering the Hollow Reach did not show its high-risk banner"):
		return false
	if not _expect(game._world_view.lighting.ambient().v < 0.85, "The Hollow Reach is not dimmer than daylight"):
		return false
	# Compare floor texels without the zone's violet ambient, lights, or glow.
	game._world_view.lighting.visible = false
	game._world_view.glow.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	var unlit: Image = screen.get_texture().get_image()
	game._world_view.lighting.visible = true
	game._world_view.glow.visible = true
	var floor_cell: Vector2i = EndgameZone.THRONE_SEAT + Vector2i(-4, -2)
	var region: Rect2 = SpriteArt._tile_region(SpriteArt.obsidian_variant(floor_cell))
	return _expect(_matches_texel(unlit, SpriteArt.TILES, Rect2(region.position + Vector2(2, 20), Vector2(4, 4)),
		Vector2(floor_cell) * World.TILE_SIZE + Vector2(2, 20)), "The throne room floor is not drawn with obsidian tiles")


## Night in Cinder Crossing: darker world, a lantern around the player, unlit UI, and particle
## bursts for a hit and a spell.
func _check_night_and_particles() -> bool:
	game.world.monsters.clear()
	game.monsters.clear()
	var player: Dictionary = game.world.players[1]
	player["cell"] = World.SPAWNS[0]
	player["from"] = World.SPAWNS[0]
	game._publish_actor(1)
	var lighting: Node2D = game._world_view.lighting
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	var day: Image = screen.get_texture().get_image()
	lighting.time_override = 0.0
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	var night: Image = screen.get_texture().get_image()
	night.save_png("res://.tools/visual-night.png")
	var near: Vector2i = Vector2i(game.map_to_screen((Vector2(World.SPAWNS[0]) + Vector2(1.5, 0.5)) * World.TILE_SIZE))
	var far: Vector2i = Vector2i(game.map_to_screen((Vector2(World.SPAWNS[0]) + Vector2(6.5, -2.5)) * World.TILE_SIZE))
	var panel: Vector2i = Vector2i(game.PANEL_ORIGIN + Vector2(4, 300))
	if not _expect(night.get_pixelv(far).get_luminance() < day.get_pixelv(far).get_luminance() * 0.75,
			"Night does not darken the world"):
		return false
	if not _expect(night.get_pixelv(near).get_luminance() > night.get_pixelv(far).get_luminance() * 1.3,
			"The player's lantern does not light the ground around them"):
		return false
	if not _expect(night.get_pixelv(panel).is_equal_approx(day.get_pixelv(panel)), "Night lighting leaked into the UI panel"):
		return false
	var fx: Node2D = game._world_view.fx
	var before: int = fx.get_child_count()
	game._show_effect({"kind": "hit", "target": 1, "amount": 12, "style": "critical"})
	game._show_effect({"kind": "area", "cells": [World.SPAWNS[0] + Vector2i(2, 0), World.SPAWNS[0] + Vector2i(2, 1)],
		"color": Color("#ff9a5a")})
	if not _expect(fx.get_child_count() >= before + 3, "Hits and spells did not emit particles"):
		return false
	await create_timer(0.12).timeout
	await RenderingServer.frame_post_draw
	screen.get_texture().get_image().save_png("res://.tools/visual-particles.png")
	await create_timer(1.6).timeout
	lighting.time_override = 0.5
	return _expect(fx.get_child_count() == before, "Finished particle bursts were not freed")
