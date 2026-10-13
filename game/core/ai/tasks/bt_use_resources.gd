extends BTAction
## Casts and drinks like the fight simulator's careful player (Bots.use_resources); always succeeds.


func _generate_name() -> String:
	return "UseSpellsAndPotions"


func _tick(_delta: float) -> Status:
	agent.bots.use_resources(agent.id, agent.now, agent.events)
	return SUCCESS
