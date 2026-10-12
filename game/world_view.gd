extends Node2D
## Draws the visible part of the world in map pixels. Floors come first; then each row is
## drawn west to east with ground items, characters, ferrymen, oblique walls, and trees so
## nearer objects cover what stands behind them. Names are drawn last, on top.

const World = preload("res://game/world.gd")
const SpriteArt = preload("res://game/sprite_art.gd")
const Monsters = preload("res://game/monsters.gd")
const Balance = preload("res://game/balance.gd")
const TARGET_COLOR: Color = Color("#ff3a2a")
## Extra tiles drawn around the view: tall sprites below the view reach up into it.
const MARGIN: Rect2i = Rect2i(-2, -2, 4, 6)

var game: Node


## Tiles to draw, as a rectangle clamped to the map.
func visible_cells() -> Rect2i:
	var focus: Vector2 = game.camera_focus() / World.TILE_SIZE
	var half: Vector2 = Vector2(game.VIEW_TILES) / 2.0
	var area := Rect2i(Vector2i((focus - half).floor()) + MARGIN.position,
		Vector2i((half * 2.0).ceil()) + Vector2i.ONE + MARGIN.size)
	return area.intersection(Rect2i(0, 0, World.width(), World.height()))


func _draw() -> void:
	var time: float = Time.get_ticks_msec() / 1000.0
	var area: Rect2i = visible_cells()
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			SpriteArt.draw_floor(self, Vector2i(x, y), time)
	for effect: Dictionary in game.effects:
		if effect["kind"] == "area":
			var fade: float = 1.0 - (time - effect["born"]) / 0.45
			for cell: Vector2i in effect["cells"]:
				draw_rect(Rect2(Vector2(cell) * World.TILE_SIZE, Vector2.ONE * World.TILE_SIZE), Color(effect["color"], 0.45 * fade))
	var occupants: Dictionary = {}
	for group: Dictionary in [game.actors, game.monsters]:
		for id: int in group:
			var visual: Vector2 = group[id]["visual"]
			# A stepping creature belongs to the further south/east of its two tiles.
			var cell: Vector2i = Vector2i(ceili(visual.x - 0.001), ceili(visual.y - 0.001))
			if not occupants.has(cell):
				occupants[cell] = []
			occupants[cell].append(id)
	var names: Array = []
	for y: int in range(area.position.y, area.end.y):
		var row: String = World.ROWS[y]
		for x: int in range(area.position.x, area.end.x):
			var cell: Vector2i = Vector2i(x, y)
			var tile: String = row[x]
			if tile == "#":
				SpriteArt.draw_wall(self, cell)
				continue
			if game.ground_view.has(cell):
				_draw_stack(cell, game.ground_view[cell])
			if World.NPC_CELLS.has(cell):
				var ferryman: Dictionary = World.FERRYMEN[World.NPC_CELLS[cell]]
				var center: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * World.TILE_SIZE
				SpriteArt.draw_actor(self, center, {"id": 0, "facing": ferryman["facing"],
					"equipment": {"helmet": "ember_cap"}}, false, 0.0, SpriteArt.NPC_TINT)
				names.append([center, ferryman["name"]])
			for id: int in occupants.get(cell, []):
				if id > 0:
					_draw_actor(id)
				else:
					_draw_monster(id)
			if tile == "T":
				SpriteArt.draw_tree(self, cell)
	_draw_overlays(area, time)
	var font: Font = ThemeDB.fallback_font
	for entry: Array in names:
		var width: float = font.get_string_size(entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var at: Vector2 = entry[0] + Vector2(-width / 2.0, -SpriteArt.FRAME_ANCHOR.y + 6)
		draw_string_outline(font, at, entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, SpriteArt.OUTLINE)
		draw_string(font, at, entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#9fe0c8"))


func _draw_stack(cell: Vector2i, stack: Array) -> void:
	var center: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * World.TILE_SIZE
	SpriteArt.draw_item(self, center, stack.back())
	if stack.size() > 1:
		var font: Font = ThemeDB.fallback_font
		var at: Vector2 = center + Vector2(7, 14)
		draw_string_outline(font, at, str(stack.size()), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, SpriteArt.OUTLINE)
		draw_string(font, at, str(stack.size()), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#f2e6c4"))


func _draw_actor(id: int) -> void:
	var actor: Dictionary = game.actors[id]
	var center: Vector2 = (actor["visual"] + Vector2(0.5, 0.5)) * World.TILE_SIZE
	var stride: float = 0.0
	if actor["duration"] > 0.0 and actor["elapsed"] < actor["duration"]:
		stride = actor["elapsed"] / actor["duration"]
	SpriteArt.draw_actor(self, center, actor["state"], id == game.self_id, stride)


func _draw_monster(id: int) -> void:
	var monster: Dictionary = game.monsters[id]
	var center: Vector2 = (monster["visual"] + Vector2(0.5, 0.5)) * World.TILE_SIZE
	var stride: float = 0.0
	if monster["duration"] > 0.0 and monster["elapsed"] < monster["duration"]:
		stride = monster["elapsed"] / monster["duration"]
	SpriteArt.draw_monster(self, center, monster["state"], stride)


func _center_of(view: Dictionary) -> Vector2:
	return (view["visual"] + Vector2(0.5, 0.5)) * World.TILE_SIZE


## "leader"/"member" for your party, "invited" for an open invitation either way, else "".
func _party_mark(id: int, state: Dictionary) -> String:
	if not game.actors.has(game.self_id):
		return ""
	var mine: Dictionary = game.actors[game.self_id]["state"]
	var party: int = mine.get("party", 0)
	if party != 0 and state.get("party", 0) == party:
		return "leader" if id == party else "member"
	if id in mine.get("invites", []) or id in mine.get("invited", []):
		return "invited"
	return ""


## Target square, nameplates, missiles, and floating numbers, drawn above the world.
func _draw_overlays(area: Rect2i, time: float) -> void:
	var target: int = game.own_target()
	var view: Dictionary = game.creature_view(target)
	if not view.is_empty():
		var corner: Vector2 = view["visual"] * World.TILE_SIZE
		draw_rect(Rect2(corner + Vector2.ONE, Vector2.ONE * (World.TILE_SIZE - 2)), TARGET_COLOR, false, 2.0)
	var shown := Rect2(Vector2(area.position) * World.TILE_SIZE, Vector2(area.size) * World.TILE_SIZE)
	for id: int in game.monsters:
		var monster: Dictionary = game.monsters[id]
		var center: Vector2 = _center_of(monster)
		if shown.has_point(center):
			var definition: Dictionary = Monsters.MONSTERS.get(monster["state"]["kind"], {"name": "?", "size": 1.0})
			var own_level: int = game.actors[game.self_id]["state"].get("level", 1) if game.actors.has(game.self_id) else 1
			SpriteArt.draw_nameplate(self, center, "%s %d" % [definition["name"], monster["state"]["level"]],
				monster["state"]["health"], monster["state"]["max_health"], definition["size"], "",
				SpriteArt.danger_color(monster["state"]["level"], own_level))
	for id: int in game.actors:
		var actor: Dictionary = game.actors[id]
		var center: Vector2 = _center_of(actor)
		if shown.has_point(center) and actor["state"].has("health"):
			var state: Dictionary = actor["state"]
			var title: String = "%s %d" % [Balance.VOCATIONS.get(state.get("vocation", ""), {"name": "Player"})["name"],
				state.get("level", 1)]
			SpriteArt.draw_nameplate(self, center, title, state["health"], state["max_health"], 1.0, state.get("skull", ""),
				Color.TRANSPARENT, _party_mark(id, state))
	var font: Font = ThemeDB.fallback_font
	for effect: Dictionary in game.effects:
		var age: float = time - effect["born"]
		if effect["kind"] == "missile":
			var weight: float = clampf(age / 0.25, 0.0, 1.0)
			var at: Vector2 = effect["from"].lerp(effect["to"], weight)
			draw_line(at - (effect["to"] - effect["from"]).normalized() * 6.0, at, effect["color"], 2.0)
			draw_circle(at, 2.0, effect["color"])
		elif effect["kind"] == "text":
			var at: Vector2 = effect["pos"] + Vector2(-8, -20.0 - age * 22.0)
			var size: int = 11 if effect.get("big", false) else 9
			draw_string_outline(font, at, effect["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, SpriteArt.OUTLINE)
			draw_string(font, at, effect["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, size, effect["color"])
