extends BTAction
## Followers (companions, rival band members) stay beside their leader (Bots.follow): they
## rejoin them at once after stairs, waystones, or deaths, and druids move to hurt members.
## Fails for a bot without a leader to follow.


func _generate_name() -> String:
	return "FollowLeader"


func _tick(_delta: float) -> Status:
	return SUCCESS if agent.bots.follow(agent.id, agent.now, agent.events) else FAILURE
