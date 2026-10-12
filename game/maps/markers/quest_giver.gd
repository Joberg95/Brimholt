extends Marker2D
## A quest NPC. Players within World.TALK_RANGE tiles right-click them and choose Quests.
## With a task (a game/data/quests.gd id) they give a town hunting task that rewards a
## bigger pack; without one, they are the Relic keeper, who trades boss trophies for relics.

@export var npc_name: String = "Quest giver"
## Town or place name shown in the quest window.
@export var place: String = ""
@export var facing: Vector2i = Vector2i.DOWN
## Quests.TASKS id; empty for the Relic keeper.
@export var task: String = ""
