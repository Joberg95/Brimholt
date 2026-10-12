extends Node2D
## Draws Cinder Crossing in map pixels. Floors come first; then each row is drawn west to
## east with ground items, characters, and oblique walls so nearer walls cover what is behind.

const World = preload("res://game/world.gd")
const TileArt = preload("res://game/tile_art.gd")
const CharacterArt = preload("res://game/character_art.gd")

var game: Node


func _draw() -> void:
	var time: float = Time.get_ticks_msec() / 1000.0
	var width: int = World.ROWS[0].length()
	for y: int in World.ROWS.size():
		for x: int in width:
			TileArt.draw_floor(self, Vector2i(x, y), time)
	var occupants: Dictionary = {}
	for id: int in game.actors:
		var visual: Vector2 = game.actors[id]["visual"]
		# A stepping character belongs to the further south/east of its two tiles.
		var cell: Vector2i = Vector2i(ceili(visual.x - 0.001), ceili(visual.y - 0.001))
		if not occupants.has(cell):
			occupants[cell] = []
		occupants[cell].append(id)
	for y: int in World.ROWS.size():
		for x: int in width:
			var cell: Vector2i = Vector2i(x, y)
			if World.ROWS[y][x] == "#":
				TileArt.draw_wall(self, cell)
				continue
			if game.ground_view.has(cell):
				_draw_stack(cell, game.ground_view[cell])
			for id: int in occupants.get(cell, []):
				_draw_actor(id)


func _draw_stack(cell: Vector2i, stack: Array) -> void:
	var center: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * World.TILE_SIZE
	CharacterArt.draw_item(self, center, stack.back())
	if stack.size() > 1:
		var font: Font = ThemeDB.fallback_font
		var at: Vector2 = center + Vector2(7, 14)
		draw_string_outline(font, at, str(stack.size()), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, CharacterArt.OUTLINE)
		draw_string(font, at, str(stack.size()), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#f2e6c4"))


func _draw_actor(id: int) -> void:
	var actor: Dictionary = game.actors[id]
	var center: Vector2 = (actor["visual"] + Vector2(0.5, 0.5)) * World.TILE_SIZE
	var stride: float = 0.0
	if actor["duration"] > 0.0 and actor["elapsed"] < actor["duration"]:
		stride = actor["elapsed"] / actor["duration"]
	CharacterArt.draw_actor(self, center, actor["state"], id == game.self_id, stride)
