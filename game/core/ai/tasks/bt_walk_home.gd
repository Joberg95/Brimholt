extends BTAction
## Takes one step along a path back to the bot's post.


func _generate_name() -> String:
	return "WalkToPost"


func _tick(_delta: float) -> Status:
	agent.bots.walk_home(agent.id, agent.now, agent.events)
	return SUCCESS
