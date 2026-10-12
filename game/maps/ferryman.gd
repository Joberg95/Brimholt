extends Marker2D
## A ferryman NPC. Place on a tile centre at the end of a pier. Players within
## World.TALK_RANGE tiles can right-click the ferryman to sail one of the routes.

@export var npc_name: String = "Ferryman"
## Dock name shown in the travel menu and on the world map.
@export var place: String = ""
## Destination ferryman node name -> fare in gold.
@export var routes: Dictionary[String, int] = {}
@export var facing: Vector2i = Vector2i.DOWN
