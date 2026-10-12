@tool
extends Node2D
## A rectangular gameplay zone. Place the node on a tile corner; it covers size_tiles tiles
## to the right and down. The editor shows the area in red.

@export var zone_name: String = ""
@export var size_tiles: Vector2i = Vector2i(10, 10):
	set(value):
		size_tiles = value
		queue_redraw()
## Players may attack each other here once combat exists.
@export var pvp: bool = false
@export_range(1, 50) var min_level: int = 1
@export_range(1, 50) var max_level: int = 50


func _draw() -> void:
	if Engine.is_editor_hint():
		var area := Rect2(Vector2.ZERO, Vector2(size_tiles) * 32.0)
		draw_rect(area, Color(0.9, 0.2, 0.2, 0.15))
		draw_rect(area, Color(0.9, 0.2, 0.2, 0.8), false, 2.0)
