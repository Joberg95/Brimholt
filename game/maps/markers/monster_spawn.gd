extends Marker2D
## A monster spawn: Combat keeps `count` monsters of this id and level within `radius` tiles.
## Ids come from game/data/monsters.gd; levels 1-50 (bosses are level 50).

@export var monster: String = ""
@export_range(1, 50) var level: int = 1
@export_range(1, 20) var count: int = 1
## Monsters wander up to this many tiles from the marker.
@export_range(0, 10) var radius: int = 3
