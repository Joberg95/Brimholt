extends Marker2D
## A travel NPC: a ferryman at the end of a pier, or a coachman at an inland coach station.
## Players within World.TALK_RANGE tiles right-click them to travel one of the routes.

@export var npc_name: String = "Ferryman"
## Dock name shown in the travel menu and on the world map.
@export var place: String = ""
## Destination ferryman node name -> fare in gold.
@export var routes: Dictionary[String, int] = {}
@export var facing: Vector2i = Vector2i.DOWN
## "ferry" (a pier ferryman) or "coach" (an inland coach station); both use the same routes.
@export var vehicle: String = "ferry"
