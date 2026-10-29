extends RefCounted
## The camera (plan 48): what map pixel the game window centres, and converting between map and
## screen positions. The world view is moved each frame (follow).

const World = preload("res://game/core/world.gd")
const WorldMap = preload("res://game/world_map/world_map.gd")
const Layout = preload("res://game/ui/layout.gd")

## The main node (game/main.gd).
var game: Node


func _init(main: Node) -> void:
	game = main


## Map pixel the camera centres: your character's interpolated position, else the map centre.
func focus() -> Vector2:
	var client: RefCounted = game.client
	if client.actors.has(client.self_id):
		return (client.actors[client.self_id]["visual"] + Vector2(0.5, 0.5)) * World.TILE_SIZE
	if game.session.dedicated:
		return Vector2(WorldMap.width(), WorldMap.height()) * World.TILE_SIZE / 2.0
	# Before joining, show the starting town rather than the middle of the map.
	return (Vector2(WorldMap.SPAWNS[0]) + Vector2(4.5, 2.5)) * World.TILE_SIZE


## Moves the world view so the focus sits in the middle of the game window.
func follow(world_view: Node2D) -> void:
	world_view.position = (Layout.VIEW_SIZE / 2.0 - focus() * Layout.ZOOM).round()


func to_screen(point: Vector2) -> Vector2:
	return Layout.VIEW_ORIGIN + game._world_view.position + point * Layout.ZOOM


## The ground location under a point of the game window (`at` relative to the window).
func map_location(at: Vector2) -> Dictionary:
	var point: Vector2 = (at - game._world_view.position) / Layout.ZOOM
	return {"type": "ground", "cell": Vector2i((point / World.TILE_SIZE).floor())}
