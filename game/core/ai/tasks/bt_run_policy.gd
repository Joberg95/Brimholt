extends BTAction
## Fights a player with the trained PvP policy (Bots.run_policy): moves, spells, and potions
## through the real rules. Fails when there is no policy or the target is not a player, so the
## tree falls back to EngageTarget.


func _generate_name() -> String:
	return "RunPolicy"


func _tick(_delta: float) -> Status:
	return SUCCESS if agent.bots.run_policy(agent.id, agent.now, agent.events) else FAILURE
