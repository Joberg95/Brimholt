extends BTAction
## Collects loot the bot's group earned nearby (BotLoot.collect): succeeds while the bot is busy
## with a stack, fails when there is nothing to collect.


func _generate_name() -> String:
	return "CollectLoot"


func _tick(_delta: float) -> Status:
	return SUCCESS if agent.bots.loot.collect(agent.id, agent.now, agent.events) else FAILURE
