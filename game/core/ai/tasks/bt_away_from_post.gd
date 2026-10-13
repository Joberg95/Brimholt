extends BTCondition
## Succeeds when the bot stands more than `distance` tiles from where it was placed.

@export var distance: int = 2


func _generate_name() -> String:
	return "AwayFromPost > %d" % distance


func _tick(_delta: float) -> Status:
	var far: int = maxi(absi(agent.player()["cell"].x - agent.bot()["post"].x), absi(agent.player()["cell"].y - agent.bot()["post"].y))
	return SUCCESS if far > distance else FAILURE
