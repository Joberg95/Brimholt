extends BTAction
## Picks the bot's target (Bots.choose_target: attackers, PvP victims, monsters after it, prey
## near its post) and locks it through Combat.set_target. Fails when there is none.


func _generate_name() -> String:
	return "PickTarget"


func _tick(_delta: float) -> Status:
	var target: int = agent.bots.choose_target(agent.id, agent.now)
	if target != agent.player()["target"]:
		agent.bots.combat.set_target(agent.id, target, agent.now)
		agent.events.append({"kind": "player", "id": agent.id})
	blackboard.set_var(&"target", agent.player()["target"])
	return SUCCESS if agent.player()["target"] != 0 else FAILURE
