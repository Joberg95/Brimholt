extends Marker2D
## Where monsters will appear once combat exists; not used in play yet.
## Levels should come from game/data/balance.gd (1-50).

@export var monster: String = ""
@export_range(1, 50) var level: int = 1
@export_range(1, 20) var count: int = 1
## Monsters wander up to this many tiles from the marker.
@export_range(0, 10) var radius: int = 3
