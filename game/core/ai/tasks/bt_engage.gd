extends BTAction
## Moves into reach of the target along a real path; ranged vocations back off a step from a
## foe beside them, as players kite. Auto-attacks come from Combat.tick.


func _generate_name() -> String:
	return "EngageTarget"


func _tick(_delta: float) -> Status:
	agent.bots.engage(agent.id, agent.now, agent.events)
	return SUCCESS
