extends SceneTree

const CAPES: Array[String] = ["silverleaf_cape", "cobalt_cape", "ember_cape", "dusk_cape"]

const World = preload("res://game/core/world.gd")
const SpriteArt = preload("res://game/render/sprite_art.gd")
const Combat = preload("res://game/core/combat.gd")
const WorldViewScript = preload("res://game/render/world_view.gd")
const WorldOverlay = preload("res://game/render/world_overlay.gd")
const Monsters = preload("res://game/data/monsters.gd")
const EndgameZone = preload("res://tools/generators/endgame_zone.gd")
const Dungeons = preload("res://game/data/dungeons.gd")
const Weather = preload("res://game/render/weather.gd")
const Biomes = preload("res://game/data/biomes.gd")
const Spells = preload("res://game/data/spells.gd")
const Quests = preload("res://game/data/quests.gd")
const Layout = preload("res://game/ui/layout.gd")
const TEST_ITEM_CELL: Vector2i = Vector2i(6, 8)
var game: Node2D
## The game renders offscreen into this buffer; the real window only needs to exist.
var screen: SubViewport
var finished: bool = false
var elapsed: float = 0.0


class WardrobeStrip extends Node2D:
	const OUTFITS: Array[Dictionary] = [
		{}, {"armor": "moss_coat"}, {"cape": "silverleaf_cape"},
		{"armor": "moss_coat", "cape": "silverleaf_cape"},
	]
	const BACKGROUND: Color = Color("#414637")

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 768, 256), BACKGROUND)
		for row: int in OUTFITS.size():
			for facing: int in SpriteArt.DIRECTIONS.size():
				for pose: int in 3:
					var center: Vector2 = Vector2((facing * 3 + pose) * 64, row * 64) + SpriteArt.FRAME_ANCHOR
					SpriteArt.draw_actor(self, center, {"id": 1, "facing": SpriteArt.DIRECTIONS[facing],
						"equipment": OUTFITS[row]}, false, [0.0, 0.25, 0.75][pose])


class WeaponStudy extends Node2D:
	const CARD := Vector2i(360, 292)
	var weapons: Array[String] = []
	var equipped: bool = true

	func _draw() -> void:
		var font: Font = ThemeDB.fallback_font
		draw_rect(Rect2(0, 0, CARD.x * 3, CARD.y * 5), Color("#171c22"))
		for index: int in weapons.size():
			var kind: String = weapons[index]
			var item: Dictionary = World.ITEMS[kind]
			var origin := Vector2(index % 3 * CARD.x, index / 3 * CARD.y)
			draw_rect(Rect2(origin + Vector2(4, 4), Vector2(CARD) - Vector2(8, 8)), Color("#272e33"))
			draw_string(font, origin + Vector2(12, 24), item["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#d8ceb4"))
			draw_string(font, origin + Vector2(12, 43), "Level %d | %s" % [item["level"], item["vocations"][0]],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#a4b0b4"))
			SpriteArt.draw_item(self, origin + Vector2(30, 70), kind)
			draw_set_transform(origin + Vector2(96, 70), 0.0, Vector2(2, 2))
			SpriteArt.draw_item(self, Vector2.ZERO, kind)
			draw_set_transform(Vector2.ZERO)
			for pose: int in 3:
				for facing: int in 4:
					var corner: Vector2 = origin + Vector2(20 + facing * 80, 100 + pose * 60)
					SpriteArt.draw_actor(self, corner + SpriteArt.FRAME_ANCHOR, {"id": 1,
						"facing": SpriteArt.DIRECTIONS[facing], "equipment": {"main_hand": kind} if equipped else {}},
						false, [0.0, 0.25, 0.75][pose])


func _initialize() -> void:
	call_deferred("_run")


func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 40.0 and not finished:
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
	# Never touch the player's real key bindings, saves, or identity.
	game.keybinds.persistent = false
	# The checks play a Paladin; real new characters start as Adventurers (see _check_training_hall).
	game.start_vocation = "paladin"
	game.allow_start_vocation = true
	screen.add_child(game)
	game.save_enabled = false
	game.identity_token = Crypto.new().generate_random_bytes(32).hex_encode()
	game.port = 0
	game.host_game()
	# Pixel checks compare against sprite texels, so pin bright noon and clear skies; night and
	# weather are checked near the end.
	game._world_view.lighting.time_override = 0.5
	Weather.override = "clear"
	if not game.connected:
		quit(1)
		return
	if not await _check_cape_layers():
		return
	if not await _check_weapon_study():
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
			var toggled: Dictionary = game.world.toggle_equipment(id, slot, float(id) + SpriteArt.VISIBLE_SLOTS.find(slot))
			if not toggled["ok"]:
				push_error("Visual test equipment setup failed")
				quit(1)
				return
		game._apply_actor(game.world.export_player(id, 10.0, id == 1))
	game.world.ground[TEST_ITEM_CELL] = ["iron_coif"]
	game._apply_ground(TEST_ITEM_CELL, ["iron_coif"])
	await process_frame
	await RenderingServer.frame_post_draw
	if not _expect(_centred(Vector2(5, 6)), "Camera is not centred on the local character (at %s, visual %s, focus %s)" % [game.world.players[1]["cell"], game.actors[1]["visual"], game.camera_focus()]):
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
	# Wall (8, 7) has open ground to its north/west; its raised top must reach over tile (7, 6).
	var wall_origin: Vector2 = Vector2(8, 7) * World.TILE_SIZE - Vector2.ONE * SpriteArt.WALL_RAISE
	var wall_region: Rect2 = SpriteArt.wall_region(Vector2i(8, 7))
	# Thin walls: the centre post's top (sprite 12..16) lies over tile (7, 6), up-left of the wall's own tile.
	if not _expect(_matches_texel(image, SpriteArt.WALLS, Rect2(wall_region.position + Vector2(12, 12), Vector2(4, 4)),
			wall_origin + Vector2(12, 12)), "Oblique wall top is not raised over the tile behind it"):
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
	if not await _check_quest_list():
		return
	if not await _check_spell_book():
		return
	if not await _check_micro_menu():
		return
	if not await _check_training_hall():
		return
	if not await _check_lexicon_and_marks():
		return
	if not await _check_bots():
		return
	if not await _check_waystone():
		return
	if not await _check_town_services():
		return
	if not await _check_roofs_and_signs():
		return
	if not await _check_dungeons():
		return
	if not await _check_weather_and_desert():
		return
	if not await _check_hollow_reach():
		return
	if not await _check_night_and_particles():
		return
	if not await _check_town_torches():
		return
	if not await _check_dark_cave():
		return
	print("BRIMHOLT_VISUAL_PASS four facings, cape-free base and 12 cape poses, 15 hunting weapons in 180 worn poses, visible unequip, panel slots, ground items, oblique walls, "
		+ "mouse drag/right-click, smooth midpoint/endpoint, following camera, trees, NPC menu and ferry trips, "
		+ "PvP island banner, action bar spell key, world map, click-to-target combat, relic quest and glow, vendor/potion key/bank depot/pack slots, cellar stairs and Rat King copy, mine caves, shop roof and sign (roof fades inside), storm and rainy night, dry desert with cacti, Hollow Reach gate and throne room, night lighting and particles, town wall torches lit at night, pitch-dark spider cave lit by a held torch, spell book and spell tooltips with drag to the action bar, micro menu and character window, training hall vocation choice, lexicon search and quest marks, host bots panel")
	finished = true
	await game.leave_game()
	quit()


func _check_cape_layers() -> bool:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(768, 256)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	viewport.add_child(WardrobeStrip.new())
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var body: Image = SpriteArt.BODY.get_image()
	var cloth: Image = SpriteArt.CLOTH.get_image()
	var cape: Image = SpriteArt.GEAR["silverleaf_cape"].get_image()
	var valid: bool = true
	for facing: int in 4:
		for pose: int in 3:
			var bare_at := Vector2i((facing * 3 + pose) * 64, 0)
			var source_at := Vector2i(pose * 64, facing * 64)
			var visible_cape: int = 0
			for y: int in 64:
				for x: int in 64:
					var pixel := Vector2i(x, y)
					if body.get_pixelv(source_at + pixel).a == 0.0 and cloth.get_pixelv(source_at + pixel).a == 0.0:
						valid = valid and image.get_pixelv(bare_at + pixel).is_equal_approx(WardrobeStrip.BACKGROUND)
						if cape.get_pixelv(source_at + pixel).a > 0.0:
							visible_cape += 1
			valid = valid and visible_cape > 0
			for armor_row: int in 2:
				var naked: Image = image.get_region(Rect2i(bare_at + Vector2i(0, armor_row * 64), Vector2i(64, 64)))
				var dressed: Image = image.get_region(Rect2i(bare_at + Vector2i(0, (armor_row + 2) * 64), Vector2i(64, 64)))
				valid = valid and naked.get_data() != dressed.get_data()
	var saved: Error = image.save_png("res://.tools/visual-wardrobe.png")
	viewport.queue_free()
	return _expect(valid, "Capes must be visible when worn, with no default cape or silhouette when empty") \
		and _expect(saved == OK, "Could not save wardrobe capture")


func _check_weapon_study() -> bool:
	var viewport := SubViewport.new()
	viewport.size = WeaponStudy.CARD * Vector2i(3, 5)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var study := WeaponStudy.new()
	for kind: String in World.ITEMS:
		if World.ITEMS[kind].get("loot_only", false):
			study.weapons.append(kind)
	viewport.add_child(study)
	await process_frame
	await RenderingServer.frame_post_draw
	var dressed: Image = viewport.get_texture().get_image()
	var saved: Error = dressed.save_png("res://.tools/visual-weapons.png")
	study.equipped = false
	study.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var bare: Image = viewport.get_texture().get_image()
	var visible: bool = study.weapons.size() == 15
	for index: int in study.weapons.size():
		var origin: Vector2i = Vector2i(index % 3, index / 3) * WeaponStudy.CARD
		for pose: int in 3:
			for facing: int in 4:
				var region := Rect2i(origin + Vector2i(20 + facing * 80, 100 + pose * 60), Vector2i(64, 60))
				visible = visible and dressed.get_region(region).get_data() != bare.get_region(region).get_data()
	viewport.queue_free()
	return _expect(visible, "Every new weapon must remain visible in four facings and three animation poses") \
		and _expect(saved == OK, "Could not save the weapon study")


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
	# The nearest free tile in talking range on the keeper's side of any wall (counters may be between).
	var best: Vector2i = cell
	for dy: int in range(-World.TALK_RANGE, World.TALK_RANGE + 1):
		for dx: int in range(-World.TALK_RANGE, World.TALK_RANGE + 1):
			var spot: Vector2i = cell + Vector2i(dx, dy)
			if World.walkable(spot) and World.in_talk_range(spot, cell) and (best == cell
					or absi(dx) + absi(dy) < absi(best.x - cell.x) + absi(best.y - cell.y)):
				best = spot
	player["cell"] = best
	player["from"] = best
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
	# Gear rarity lives in the hover tooltip (coloured name and frame), not on the slot.
	var rated: Control = null
	for slot: Control in game.inventory._slots:
		if is_instance_valid(slot) and slot.rarity_color.a > 0.0 and rated == null:
			rated = slot
	if not _expect(rated != null, "No equipped item has a rarity tooltip"):
		return false
	var tip: Control = rated._make_custom_tooltip(rated.tooltip_text)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", rated.theme.get_stylebox("panel", "TooltipPanel"))
	frame.add_child(tip)
	frame.position = Vector2(game.VIEW_ORIGIN) + Vector2(20, 40)
	var on_top := CanvasLayer.new()
	on_top.layer = 100
	on_top.add_child(frame)
	game.add_child(on_top)
	await process_frame
	await RenderingServer.frame_post_draw
	screen.get_texture().get_image().save_png("res://.tools/visual-tooltip.png")
	var title: Label = tip.get_child(0)
	var colour: Color = title.get_theme_color("font_color")
	on_top.queue_free()
	if not _expect(colour == rated.rarity_color and tip.get_child(1).text.split(" ")[0] in ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Relic"],
			"The tooltip must name the rarity in its colour (%s)" % tip.get_child(1).text):
		return false
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
	await _move_beside("reedmere_banker")
	if not await _open_service("reedmere_banker", "Bank") or not _expect(game.dialogs.banking(), "The bank dialog is not open"):
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
func _matches_texel(image: Image, texture: Texture2D, region: Rect2, map_origin: Vector2) -> bool:
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
	return image.get_pixelv(Vector2i(at)).is_equal_approx(expected)


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
	# It opens zoomed in on you: your own tile's terrain sits at the map's centre.
	var maps: Node = game.maps
	var here: Vector2i = game.world.players[1]["cell"]
	var probe: Vector2i = here + Vector2i(3, 2)
	var pixel: Vector2 = game.VIEW_ORIGIN + maps.map_point(Vector2(probe) + Vector2(0.5, 0.5))
	if not _expect(game._world_map.visible and maps.zoom >= maps.OPEN_ZOOM and world_map.get_pixelv(Vector2i(pixel)).is_equal_approx(
			maps._texture.get_image().get_pixelv(probe)), "The world map key did not open the world map zoomed in on you (zoom %s)" % maps.zoom):
		return false
	# Wheel in around a point (it stays under the cursor), drag (the map follows the mouse), then
	# wheel out until the whole map fits, where it can no longer pan.
	var middle: Vector2 = game._world_map.size / 2.0
	var wheel_in := InputEventMouseButton.new()
	wheel_in.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_in.pressed = true
	wheel_in.position = middle + Vector2(100, 50)
	var under: Vector2 = maps.center + (wheel_in.position - maps._map_area().get_center()) / maps.zoom
	game._world_map.gui_input.emit(wheel_in)
	var kept: bool = maps.map_point(under).distance_to(wheel_in.position) < 1.0 and maps.zoom > maps.OPEN_ZOOM
	var before: Vector2 = maps.center
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	game._world_map.gui_input.emit(press)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(-40, -30)
	game._world_map.gui_input.emit(motion)
	press.pressed = false
	game._world_map.gui_input.emit(press)
	var dragged: bool = maps.center.distance_to(before + Vector2(40, 30) / maps.zoom) < 0.01 and game._world_map.visible
	for step: int in 12:
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		wheel.position = middle
		game._world_map.gui_input.emit(wheel)
	var whole: bool = is_equal_approx(maps.zoom, maps._fit_zoom())
	if not _expect(whole and kept and dragged, "World map zoom (whole %s, kept %s) or drag (%s) is wrong" % [whole, kept, dragged]):
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
		"The ferry did not sail from %s to %s (pressed %s, panel %s, gold %d of %d, at %s, feedback %s)" % [from, to, pressed,
			game._travel_panel.visible, player["gold"], gold, player["cell"], game.last_action_message])


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
	if not _expect(hit and game.world.monsters[spawned[0]]["health"] < 1000, "The locked monster was not attacked"):
		return false
	# The weapon swings: the drawn character changes between the wind-up and the strike, toward the target.
	var me: Dictionary = game.actors[1]
	var centre: Vector2 = game.map_to_screen((me["visual"] + Vector2(0.5, 0.5)) * World.TILE_SIZE)
	var body := Rect2i(Vector2i(centre) - Vector2i(48, 72), Vector2i(96, 104))
	var frames: Array[Image] = []
	# Drawn-only: show the swing with a sword in hand (the server's equipment is untouched).
	var worn: Dictionary = me["state"]["equipment"]
	me["state"]["equipment"] = worn.merged({"main_hand": "ashford_arming_sword"}, true)
	for age: float in [0.05, 0.25, 1.0]:
		me["attack_born"] = Time.get_ticks_msec() / 1000.0 - age
		me["attack_facing"] = Combat.facing_toward(player["cell"], target_cell)
		await process_frame
		await RenderingServer.frame_post_draw
		var full: Image = screen.get_texture().get_image()
		if age == 0.25:
			full.save_png("res://.tools/visual-swing.png")
		frames.append(full.get_region(body))
	me["state"]["equipment"] = worn
	return _expect(frames[0].get_data() != frames[1].get_data() and frames[1].get_data() != frames[2].get_data(),
		"The weapon must visibly wind up and strike")


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
	var offered: int = 0
	var locked: int = 0
	for child: Node in game._travel_list.get_children():
		if child is Button and child.text.contains("Abyssal plate"):
			claim = child
		if child is Button and child.text.contains("Claim"):
			offered += 1
			locked += 1 if child.disabled else 0
	# Ysolde keeps only Morvain's relics; the other bosses have their own keepers in Reedmere.
	if not _expect(claim != null and not claim.disabled and locked == 0 and offered == Monsters.MONSTERS["morvain"]["relics"].size(),
			"Ysolde's quest window should offer exactly Morvain's relics"):
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
## Steps down the Cinder Crossing stairway through the client's move request, then captures the Rat
## King's room in the private cellar copy and the cave-rock Highmoor mine.
func _check_dungeons() -> bool:
	game.world.monsters.clear()
	game.monsters.clear()
	game.world.ground.clear()
	game.ground_view.clear()
	var player: Dictionary = game.world.players[1]
	var stairway: Vector2i = World.ENTRANCE_OF["cinder_cellar"]
	var step: Vector2i = Vector2i.ZERO
	for candidate: Vector2i in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
		if step == Vector2i.ZERO and World.walkable(stairway + candidate):
			step = -candidate
	player["cell"] = stairway - step
	player["from"] = player["cell"]
	player["next_move"] = 0.0
	game._publish_actor(1)
	await process_frame
	# Held movement keys are polled from the OS keyboard, so step through the same client request.
	game.move_local(step)
	await create_timer(0.3).timeout
	var place: Array = World.dungeon_at(player["cell"])
	if not _expect(place.size() == 2 and place[0] == "cinder_cellar" and game.last_action_message.contains("Cinder cellar")
			and game.monsters.size() > 3, "The cellar stairway did not open a copy with rats: %s %s '%s' %d" % [
				player["cell"], place, game.last_action_message, game.monsters.size()]):
		return false
	var king: Vector2i = Dungeons.origin("cinder_cellar", place[1]) + Dungeons.cells("cinder_cellar", "K")[0]
	for id: int in game.world.monsters:
		game.world.monsters[id]["next_move"] = INF
		game.world.monsters[id]["next_attack"] = INF
	player["cell"] = king + Vector2i(-3, 0)
	player["from"] = player["cell"]
	player["facing"] = Vector2i.RIGHT
	game._publish_actor(1)
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var cellar: Image = screen.get_texture().get_image()
	cellar.save_png("res://.tools/visual-cellar.png")
	var king_seen: bool = game.monsters.values().any(func(monster: Dictionary) -> bool: return monster["state"]["kind"] == "rat_king")
	if not _expect(king_seen and game._zone_label.text.contains("Cinder cellar"), "The Rat King's copy is not drawn"):
		return false
	player["cell"] = Dungeons.origin("highmoor_mine", 0) + Dungeons.cells("highmoor_mine", "@")[0]
	player["from"] = player["cell"]
	game._publish_actor(1)
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var mine: Image = screen.get_texture().get_image()
	mine.save_png("res://.tools/visual-mine.png")
	return _expect(_colours(mine, Rect2(game.VIEW_ORIGIN + Vector2(260, 220), Vector2(160, 120))) > 20, "The mine caves are blank")


## The waystone outside Cinder Crossing: a standing stone (not a person) with its name.
func _check_waystone() -> bool:
	var player: Dictionary = game.world.players[1]
	var stone: Vector2i = World.FERRYMEN["cinder_coach"]["cell"]
	player["cell"] = stone + Vector2i(-2, 1)
	player["from"] = player["cell"]
	game._publish_actor(1)
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	screen.get_texture().get_image().save_png("res://.tools/visual-waystone.png")
	var named: bool = game._world_view.npc_names.any(func(entry: Array) -> bool: return entry[1] == "Waystone")
	return _expect(World.FERRYMEN["cinder_coach"]["vehicle"] == "waystone" and named, "The Cinder Crossing waystone is not drawn")


## Wall torches: unlit by day, a flame and warm light on the wall at night.
func _check_town_torches() -> bool:
	var torch: Vector2i = World.TORCHES[0]
	for cell: Vector2i in World.TORCHES:
		if Vector2(cell).distance_to(Vector2(World.SPAWNS[0])) < Vector2(torch).distance_to(Vector2(World.SPAWNS[0])):
			torch = cell
	var player: Dictionary = game.world.players[1]
	var stand: Vector2i = torch + Vector2i.DOWN
	for offset: Vector2i in [Vector2i(3, 2), Vector2i(-3, 2), Vector2i(2, 3), Vector2i(-2, 3), Vector2i(0, 3), Vector2i(3, 1), Vector2i(-3, 1)]:
		if World.walkable(torch + offset):
			stand = torch + offset
			break
	player["cell"] = stand
	player["from"] = stand
	game._publish_actor(1)
	await create_timer(0.8).timeout
	var lighting: Node2D = game._world_view.lighting
	var flame: Vector2i = Vector2i(game.map_to_screen(Vector2(torch) * World.TILE_SIZE + Vector2(16, 8)))
	var wall: Vector2i = Vector2i(game.map_to_screen(Vector2(torch) * World.TILE_SIZE + Vector2(4, 22)))
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var day: Image = screen.get_texture().get_image()
	lighting.time_override = 0.0
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var night: Image = screen.get_texture().get_image()
	night.save_png("res://.tools/visual-torches.png")
	lighting.time_override = 0.5
	var lit: Color = night.get_pixelv(flame)
	if not _expect(lit.r > 0.75 and lit.r > lit.b + 0.3 and lit.get_luminance() > day.get_pixelv(flame).get_luminance(),
			"A town wall torch does not burn at night (%s at %s)" % [lit, torch]):
		return false
	return _expect(night.get_pixelv(wall).r > night.get_pixelv(wall).b,
		"A town wall torch does not cast warm light on its wall")


## Silkhollow is pitch dark: a lantern lights an arm's length, a held torch three tiles and more.
func _check_dark_cave() -> bool:
	var player: Dictionary = game.world.players[1]
	var home: Vector2i = player["cell"]
	var worn: Dictionary = player["equipment"].duplicate()
	player["equipment"] = {}
	var arrival: Vector2i = Dungeons.origin("silkhollow", 3) + Dungeons.cells("silkhollow", "@")[0]
	var shots: Array[Image] = []
	var spiders: Array[int] = []
	for torch: bool in [false, true]:
		if torch:
			player["equipment"]["off_hand"] = "torch"
			var events: Array = []
			for entry: Array in [["cave_spider", Vector2i(3, 1)], ["venom_weaver", Vector2i(2, 3)]]:
				var id: int = game.combat.spawn_monster(entry[0], 16, arrival + entry[1], game._now(), -1, events)
				game.world.monsters[id]["next_move"] = INF
				game.world.monsters[id]["next_attack"] = INF
				spiders.append(id)
			game._handle_events(events)
		else:
			player["equipment"].erase("off_hand")
		player["cell"] = arrival
		player["from"] = arrival
		game._publish_actor(1)
		await create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		shots.append(screen.get_texture().get_image())
	shots[0].save_png("res://.tools/visual-cave.png")
	shots[1].save_png("res://.tools/visual-cave-torch.png")
	var gone: Array = []
	for id: int in spiders:
		game.combat.despawn(id, gone)
	game._handle_events(gone)
	# The cave mouth in Thornfield Wilds, by day.
	var mouth: Vector2i = World.ENTRANCE_OF["silkhollow"] + Vector2i(0, 3)
	player["cell"] = mouth
	player["from"] = mouth
	game._publish_actor(1)
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	screen.get_texture().get_image().save_png("res://.tools/visual-cave-mouth.png")
	player["equipment"] = worn
	player["cell"] = home
	player["from"] = home
	game._publish_actor(1)
	await create_timer(0.5).timeout
	var centre: Vector2 = game.map_to_screen(Vector2(home) * World.TILE_SIZE + Vector2(16, 16))
	var dark: float = _mean_luminance(shots[0], Rect2i(Vector2i(centre) - Vector2i(240, 200), Vector2i(480, 400)))
	var lit: float = _mean_luminance(shots[1], Rect2i(Vector2i(centre) - Vector2i(240, 200), Vector2i(480, 400)))
	return _expect(dark < 0.06 and lit > dark * 2.5 and lit > 0.08, "Silkhollow is not dark without a torch, or a torch does not light it (%.2f -> %.2f)" % [dark, lit])


func _mean_luminance(image: Image, area: Rect2i) -> float:
	var region: Rect2i = area.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var total: float = 0.0
	var samples: int = 0
	for y: int in range(region.position.y, region.end.y, 8):
		for x: int in range(region.position.x, region.end.x, 8):
			total += image.get_pixel(x, y).get_luminance()
			samples += 1
	return total / maxi(samples, 1)


## The spell book opens with its key and lists your vocation's spells with their numbers; a bar
## slot's tooltip explains its spell; dragging a rune from the book onto the bar fills the slot.
func _check_spell_book() -> bool:
	var saved_bar: Array[String] = game.keybinds.bar.duplicate()
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = game.keybinds.keys["spell_book"][0]
	game._unhandled_key_input(key)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	screen.get_texture().get_image().save_png("res://.tools/visual-spellbook.png")
	var book: Control = game.spell_book
	var vocation: String = game.actors[game.self_id]["state"]["vocation"]
	var text: PackedStringArray = []
	_texts(book, text)
	var listed: bool = Spells.for_vocation(vocation).all(func(spell: String) -> bool:
		return Spells.SPELLS[spell]["name"] in text)
	if not _expect(book.visible and listed and "\n".join(text).contains("Cooldown"),
			"The spell book does not list every %s spell with its numbers" % vocation):
		return false
	var slot: Control = game.action_bar._slots[0]
	var tip: Control = slot._make_custom_tooltip(slot.tooltip_text)
	var tip_text: PackedStringArray = []
	_texts(tip, tip_text)
	tip.free()
	if not _expect(tip_text.size() >= 5 and tip_text[0] == Spells.SPELLS[slot.spell]["name"] and "\n".join(tip_text).contains("Mana"),
			"An action bar slot has no spell tooltip (%s)" % [tip_text]):
		return false
	var last: String = Spells.for_vocation(vocation)[-1]
	var runes: Array = book.find_children("*", "Control", true, false).filter(func(node: Node) -> bool:
		return node.get("spell") == last)
	var drag: Variant = runes[0]._get_drag_data(Vector2.ZERO) if not runes.is_empty() else null
	var target: Control = game.action_bar._slots[8]
	if drag != null and target._can_drop_data(Vector2.ZERO, drag):
		target._drop_data(Vector2.ZERO, drag)
	var dropped: bool = game.keybinds.bar[8] == "spell:" + last
	game.keybinds.bar = saved_bar
	game._unhandled_key_input(key)
	await process_frame
	return _expect(dropped and not book.visible, "Dragging a spell from the book onto the bar failed, or the key did not close it")


## The micro menu beside the action bar opens the character window (stats explained) and the
## other panels by click, marks open panels, and names each button's key in its tooltip.
func _check_micro_menu() -> bool:
	var menu: Node = game.micro_menu
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	menu.buttons[0].gui_input.emit(release)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	screen.get_texture().get_image().save_png("res://.tools/visual-character.png")
	var window: Control = game.character_window
	var text: PackedStringArray = []
	_texts(window, text)
	var joined: String = "\n".join(text)
	var bar_right: float = game.action_bar._slots[-1].get_global_rect().end.x
	var placed: bool = menu.buttons.all(func(button: Control) -> bool:
		return button.position.x > bar_right and button.get_global_rect().end.x <= Layout.VIEW_ORIGIN.x + Layout.VIEW_SIZE.x)
	if not _expect(window.visible and game.panel_open("character") and joined.contains("Defense") and joined.contains("Cuts damage")
			and joined.contains("Town rest") and joined.contains("Experience"), "The micro menu does not open a character window with stats explained"):
		return false
	if not _expect(placed and menu.buttons[1].tooltip_text.begins_with("Spell book  (B)"),
			"The micro menu sits outside the space right of the action bar, or its tooltips lack keys"):
		return false
	menu.buttons[1].gui_input.emit(release)
	menu.buttons[0].gui_input.emit(release)
	await process_frame
	var swapped: bool = game.spell_book.visible and not window.visible
	menu.buttons[1].gui_input.emit(release)
	await process_frame
	return _expect(swapped and not game.spell_book.visible, "Micro menu buttons do not toggle their panels")


## Cinder Crossing's training hall: an Adventurer who passed the trial right-clicks a trainer,
## chooses Vocation, and becomes a Paladin through the real dialog button.
func _check_training_hall() -> bool:
	var player: Dictionary = game.world.players[1]
	var saved: Dictionary = {"cell": player["cell"], "backpack": player["backpack"].duplicate(), "done": player["done_tasks"].duplicate()}
	var trainer: Dictionary = World.QUEST_GIVERS["trainer_paladin"]
	var front: Vector2i = trainer["cell"] + trainer["facing"]
	player["vocation"] = "adventurer"
	player["done_tasks"][Quests.TRIAL_TASK] = true
	player["backpack"] = player["backpack"].map(func(_entry: String) -> String: return "")
	player["cell"] = front
	player["from"] = front
	game._publish_actor(1)
	await create_timer(0.8).timeout
	if not await _open_service("trainer_paladin", "Class"):
		return false
	await process_frame
	await RenderingServer.frame_post_draw
	screen.get_texture().get_image().save_png("res://.tools/visual-trainer.png")
	var become: Button = null
	for button: Node in game._travel_list.find_children("*", "Button", true, false):
		if button.text == "Become a Hunter":
			become = button
	if not _expect(become != null and not become.disabled and game.dialogs.mode == "vocation",
			"The Hunter trainer offers no class to a qualified Adventurer"):
		return false
	become.pressed.emit()
	await create_timer(0.3).timeout
	var chosen: bool = player["vocation"] == "paladin" and player["backpack"].has("willow_shortbow") \
		and game.actors[1]["state"]["vocation"] == "paladin"
	game.dialogs.close()
	player["backpack"] = saved["backpack"]
	player["done_tasks"] = saved["done"]
	player["cell"] = saved["cell"]
	player["from"] = saved["cell"]
	game._publish_actor(1)
	await create_timer(0.5).timeout
	return _expect(chosen, "Choosing a class at the trainer did not make the Adventurer a Hunter")


## The lexicon (K) searched for "silk" lists the spiders with their drops; a level-12 player
## at Cinder Landing sees Harbourmaster Ilse's "!" and the quest list's next stop.
func _check_lexicon_and_marks() -> bool:
	await _press("lexicon")
	var book: Control = game.lexicon
	book.search.text = "silk"
	book.search.text_changed.emit("silk")
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	screen.get_texture().get_image().save_png("res://.tools/visual-lexicon.png")
	var names: Array = []
	for index: int in book.list.item_count:
		names.append(book.list.get_item_text(index).get_slice("   ", 0))
	var text: PackedStringArray = []
	_texts(book, text)
	if not _expect(book.visible and names.has("Cave spider") and names.has("Venom weaver") and not names.has("Field vole")
			and "\n".join(text).contains("Spider silk") and "\n".join(text).contains("Silkhollow (dungeon)"),
			"The lexicon search for silk did not find the spiders and their drops (%s)" % [names]):
		return false
	await _press("lexicon")
	var player: Dictionary = game.world.players[1]
	var saved: Dictionary = {"cell": player["cell"], "level": player["level"], "tasks": player["tasks"].duplicate(),
		"done": player["done_tasks"].duplicate()}
	var ilse: Dictionary = World.QUEST_GIVERS["harbourmaster_ilse"]
	player["level"] = 12
	player["tasks"] = {}
	player["done_tasks"] = {}
	player["cell"] = ilse["cell"] + Vector2i(0, 2)
	player["from"] = player["cell"]
	game._publish_actor(1)
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	screen.get_texture().get_image().save_png("res://.tools/visual-quest-marks.png")
	var listed: PackedStringArray = []
	_texts(game.quest_list, listed)
	var marked: String = World.quest_mark("harbourmaster_ilse", game.actors[1]["state"])
	player["level"] = saved["level"]
	player["tasks"] = saved["tasks"]
	player["done_tasks"] = saved["done"]
	player["cell"] = saved["cell"]
	player["from"] = saved["cell"]
	game._publish_actor(1)
	await create_timer(0.5).timeout
	return _expect(marked == "!" and "\n".join(listed).contains("Next: Wolves at the woodline"),
		"Harbourmaster Ilse shows no quest mark, or the quest list no next stop (%s)" % [listed])


## The host's Bots button opens the panel; adding a bot puts a "Bot" player beside you that the
## panel lists; removing it takes it out of the world.
func _check_bots() -> bool:
	var button: Button = game.hud.bots_button
	if not _expect(button.visible, "The host has no Bots button"):
		return false
	button.pressed.emit()
	var panel: Control = game.bot_panel
	panel.level.value = 30
	panel.stance.select(0)
	panel.add_button.pressed.emit()
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	screen.get_texture().get_image().save_png("res://.tools/visual-bots.png")
	var ids: Array = game.bots.bots.keys()
	var text: PackedStringArray = []
	_texts(panel, text)
	var shown: bool = ids.size() == 1 and game.actors.has(ids[0]) and game.actors[ids[0]]["state"].get("bot", false) \
		and "\n".join(text).contains("Bot Warrior 30") and Combat.distance(game.world.players[ids[0]]["cell"], game.world.players[1]["cell"]) <= 2
	game.remove_bot(ids[0] if not ids.is_empty() else 0)
	panel.hide()
	await process_frame
	return _expect(shown and game.bots.bots.is_empty() and not game.actors.has(ids[0] if not ids.is_empty() else 0),
		"Adding a bot from the Bots panel did not put a bot beside you, or removing it failed (%s)" % [text])


func _texts(node: Node, into: PackedStringArray) -> void:
	if node is Label:
		into.append(node.text)
	for child: Node in node.get_children():
		_texts(child, into)


## The quest list: one task in progress and one ready to turn in, then hidden with its key.
func _check_quest_list() -> bool:
	var player: Dictionary = game.world.players[1]
	var before: Dictionary = player["tasks"].duplicate()
	player["tasks"] = {"cellar_vermin": 12, "rat_king": 1}
	game._publish_actor(1)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	screen.get_texture().get_image().save_png("res://.tools/visual-quests.png")
	var lines: PackedStringArray = []
	for child: Node in game.quest_list.get_child(0).get_children():
		if child is Label and not child.is_queued_for_deletion():
			lines.append(child.text)
	var text: String = "\n".join(lines)
	var ok: bool = game.quest_list.visible and text.contains("Vermin in the cellar") and text.contains("12/25 cellar rats") \
		and text.contains("Cellarmaster Pell, Cinder Crossing") and text.contains("Done: return to Cellarmaster Pell")
	game._run_action("quest_list")
	await process_frame
	await process_frame
	var hidden: bool = not game.quest_list.visible
	game._run_action("quest_list")
	player["tasks"] = before
	game._publish_actor(1)
	await process_frame
	return _expect(ok, "The quest list should show each task's giver and progress:\n%s" % text) \
		and _expect(hidden, "The quest list key should hide the list")


## Ashford's shop from the plaza (roof over the merchant, sign by the door, no name through
## the roof), then from inside (the roof has faded and the merchant shows).
func _check_roofs_and_signs() -> bool:
	var player: Dictionary = game.world.players[1]
	var keeper: Vector2i = World.npc("ashford_vendor")["cell"]
	var building: Dictionary = World.BUILDINGS[World.ROOM_AT.get(keeper, 0)]
	var door: Vector2i = building["doors"][0]
	var sign: Dictionary = {}
	for entry: Dictionary in World.SIGNS:
		if World.ROOF_AT.get(entry["cell"], -1) == World.ROOM_AT.get(keeper, -2):
			sign = entry
	if not _expect(World.ROOM_AT.has(keeper) and not sign.is_empty(), "Ashford's merchant has no shop with a sign"):
		return false
	player["cell"] = door + building["outward"][door] * 2
	player["from"] = player["cell"]
	game._publish_actor(1)
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var outside: Image = screen.get_texture().get_image()
	outside.save_png("res://.tools/visual-roofs.png")
	var named_outside: bool = game._world_view.npc_names.any(func(entry: Array) -> bool: return entry[1] == World.npc("ashford_vendor")["name"])
	player["cell"] = keeper + Vector2i.DOWN * 2
	player["from"] = player["cell"]
	game._publish_actor(1)
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var inside: Image = screen.get_texture().get_image()
	inside.save_png("res://.tools/visual-shop-inside.png")
	var named_inside: bool = game._world_view.npc_names.any(func(entry: Array) -> bool: return entry[1] == World.npc("ashford_vendor")["name"])
	var spot: Vector2 = game.map_to_screen((Vector2(keeper) + Vector2(0.5, 0.2)) * World.TILE_SIZE)
	var keeper_area := Rect2i(Vector2i(spot) - Vector2i(10, 10), Vector2i(20, 20))
	var sign_centre: Vector2 = game.map_to_screen(Vector2(sign["cell"]) * World.TILE_SIZE + SpriteArt.SIGN_OFFSETS[sign["outward"]])
	return _expect(not named_outside and named_inside, "The merchant's name must hide under the roof and show inside (%s, %s)"
			% [named_outside, named_inside]) \
		and _expect(not game._world_view.covered(keeper) and game._world_view.inside_building() == World.ROOM_AT[keeper],
			"The roof must fade while you are inside") \
		and _expect(_colours(inside, Rect2(sign_centre - Vector2(16, 12), Vector2(32, 24))) > 8, "The shop sign is not drawn (%d colours at %s)"
			% [_colours(inside, Rect2(sign_centre - Vector2(16, 12), Vector2(32, 24))), sign_centre]) \
		and _expect(outside.get_region(keeper_area).get_data() != inside.get_region(keeper_area).get_data(),
			"The roof must cover the merchant from outside")


## A storm at noon over Cinder Crossing (rain drawn, light dimmed), the same rain at night (the
## lantern lights up), and the desert in a storm: dry, with cacti on sand.
func _check_weather_and_desert() -> bool:
	game.world.monsters.clear()
	game.monsters.clear()
	var player: Dictionary = game.world.players[1]
	player["cell"] = World.SPAWNS[0] + Vector2i(1, 2)
	player["from"] = player["cell"]
	game._publish_actor(1)
	# Floor chunks around a new spot build one per frame; let them finish before comparing.
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var clear: Image = screen.get_texture().get_image()
	Weather.override = "rain"
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var rainy: Image = screen.get_texture().get_image()
	rainy.save_png("res://.tools/visual-rain.png")
	var centre := Rect2i(Vector2i(game.VIEW_ORIGIN + game.VIEW_SIZE / 2.0) - Vector2i(140, 100), Vector2i(280, 200))
	if not _expect(game._view.rain.visible and _brightness(rainy, centre) < _brightness(clear, centre) - 0.02
			and rainy.get_region(centre).get_data() != clear.get_region(centre).get_data(),
			"Rain must draw drops and dim the light (visible %s, brightness %.3f -> %.3f)" % [game._view.rain.visible,
				_brightness(clear, centre), _brightness(rainy, centre)]):
		return false
	game._world_view.lighting.time_override = 0.02
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var night: Image = screen.get_texture().get_image()
	night.save_png("res://.tools/visual-rain-night.png")
	# Carried lights brighten the centre at night, so compare the whole game window.
	var view := Rect2i(Vector2i(game.VIEW_ORIGIN), Vector2i(game.VIEW_SIZE))
	if not _expect(_brightness(night, view) < _brightness(rainy, view) - 0.05, "Night rain should be darker than day rain (%.3f -> %.3f)"
			% [_brightness(rainy, view), _brightness(night, view)]):
		return false
	game._world_view.lighting.time_override = 0.5
	var plant: Vector2i = Vector2i(-1, -1)
	for y: int in range(Biomes.DESERT_AREA.position.y + 20, Biomes.DESERT_AREA.end.y - 20):
		for x: int in range(Biomes.DESERT_AREA.position.x + 20, Biomes.DESERT_AREA.end.x - 20):
			if plant.x < 0 and World.terrain(Vector2i(x, y)) == "K" and World.walkable(Vector2i(x - 2, y)) \
					and Biomes.desert_distance(Vector2i(x, y)) < 0.6:
				plant = Vector2i(x, y)
	if not _expect(plant.x >= 0, "No cactus found inside the desert"):
		return false
	player["cell"] = plant + Vector2i(-2, 0)
	player["from"] = player["cell"]
	Weather.override = "storm"
	game._publish_actor(1)
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var desert: Image = screen.get_texture().get_image()
	desert.save_png("res://.tools/visual-desert.png")
	var plant_drawn: bool = false
	var origin: Vector2 = game.map_to_screen((Vector2(plant) + Vector2(0.5, 0.5)) * World.TILE_SIZE)
	var sand: Color = desert.get_pixelv(Vector2i(game.map_to_screen((Vector2(plant) + Vector2(-1.0, 0.5)) * World.TILE_SIZE)))
	for dy: int in range(-40, 0, 2):
		var pixel: Color = desert.get_pixelv(Vector2i(origin) + Vector2i(0, dy))
		plant_drawn = plant_drawn or (pixel.g > pixel.r and pixel.g > pixel.b + 0.05)
	Weather.override = "clear"
	var location: String = game.hud.location_label.text
	if not _expect(location.begins_with("Sunscar Dunes · levels "), "The location line should name the desert and its levels (%s)" % location):
		return false
	return _expect(not game._view.rain.visible, "It must not rain in the desert") \
		and _expect(plant_drawn and sand.r > sand.b + 0.1, "Desert plants must stand on sand")


func _brightness(image: Image, area: Rect2i) -> float:
	var total: float = 0.0
	var samples: int = 0
	for y: int in range(area.position.y, area.end.y, 4):
		for x: int in range(area.position.x, area.end.x, 4):
			total += image.get_pixel(x, y).get_luminance()
			samples += 1
	return total / maxf(1.0, samples)


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
