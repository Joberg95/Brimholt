extends BTAction
## Sells loot at a vendor (BotLoot.sell): succeeds while the bot is on a selling trip, fails
## otherwise (followers sell in passing and keep following).


func _generate_name() -> String:
	return "SellLoot"


func _tick(_delta: float) -> Status:
	return SUCCESS if agent.bots.loot.sell(agent.id, agent.now, agent.events) else FAILURE
