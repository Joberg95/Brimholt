extends BTCondition
## Succeeds when the bot's stance (Bots.STANCES) is `stance`.

@export var stance: String = "dummy"


func _generate_name() -> String:
	return "IsStance %s" % stance


func _tick(_delta: float) -> Status:
	return SUCCESS if agent.bot()["stance"] == stance else FAILURE
