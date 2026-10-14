extends BTAction
## A rival band leader's errand (Bots.run_plan): take a task, hunt its camp, turn it in, or
## ambush players in a PvP zone. Always succeeds.


func _generate_name() -> String:
	return "RunErrand"


func _tick(_delta: float) -> Status:
	agent.bots.run_plan(agent.id, agent.now, agent.events)
	return SUCCESS
