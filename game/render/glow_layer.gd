extends Node2D
## Additive light over the world: pulsing halos and rising sparks around glowing relics, both
## worn and on the ground, and around glowing bosses. A child of the world view, so it shares
## its map-pixel transform; drawn above the world, so the light also shines through trees.

const World = preload("res://game/core/world.gd")
const SpriteArt = preload("res://game/render/sprite_art.gd")
const Monsters = preload("res://game/data/monsters.gd")
const SPARKS: int = 3

var view: Node2D


func _ready() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var game: Node = view.game
	var time: float = Time.get_ticks_msec() / 1000.0
	var area: Rect2i = view.visible_cells()
	var shown := Rect2(Vector2(area.position) * World.TILE_SIZE, Vector2(area.size) * World.TILE_SIZE)
	for id: int in game.client.monsters_in(area):
		var monster: Dictionary = game.client.monsters[id]
		var center: Vector2 = (monster["visual"] + Vector2(0.5, 0.5)) * World.TILE_SIZE
		if shown.has_point(center) and SpriteArt.draw_monster_glow(self, center, SpriteArt.posed(monster, time), _stride(monster), _pulse(time, id)):
			var definition: Dictionary = Monsters.MONSTERS[monster["state"]["kind"]]
			_sparks(center, definition["glow"], time, id, definition["size"])
	for cell: Vector2i in game.client.ground_in(area):
		var stack: Array = game.client.ground_view[cell]
		var center: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * World.TILE_SIZE
		if area.has_point(cell) and not stack.is_empty() and not view.covered(cell) and SpriteArt.draw_item_glow(self, center, stack.back(), _pulse(time, cell.x * 31 + cell.y)):
			_sparks(center + Vector2(0, 8), World.ITEMS[World.kind_of(stack.back())]["glow"], time, cell.x * 31 + cell.y, 0.6)


func _stride(view_state: Dictionary) -> float:
	if view_state["duration"] > 0.0 and view_state["elapsed"] < view_state["duration"]:
		return view_state["elapsed"] / view_state["duration"]
	return 0.0


static func _pulse(time: float, seed_value: int) -> float:
	return 0.42 + 0.18 * sin(time * 2.6 + seed_value * 0.7)


## Small sparks drifting up from the item and fading, a few per glowing thing.
func _sparks(center: Vector2, color: Color, time: float, seed_value: int, size: float) -> void:
	for spark: int in SPARKS:
		var phase: float = time * 0.7 + float(spark) / SPARKS + seed_value * 0.37
		var cycle: float = floorf(phase)
		var rise: float = phase - cycle
		var drift: float = sin(cycle * 12.9898 + spark * 78.233 + seed_value) * 13.0 * size
		var at: Vector2 = center + Vector2(drift, 8.0 - rise * 34.0 * size)
		draw_rect(Rect2(at.round(), Vector2.ONE), Color(color, sin(rise * PI) * 0.9))
