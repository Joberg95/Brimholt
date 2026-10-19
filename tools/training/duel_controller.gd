extends AIController2D
## The learner's seat in one duel arena (duel_env.gd): Godot RL Agents' Sync node reads its
## observation, reward, and done flag and hands it the policy's choice. The arena does the rest,
## so this only stores what passes through.

const PvpBrain = preload("res://game/core/ai/pvp_brain.gd")

## The arena's latest observation of the learner's fight (PvpBrain.observe).
var sight := PackedFloat32Array()
## The choice waiting for the arena's next step ({"act": i, "move": j}), empty once taken.
var choice: Dictionary = {}
## The finished duel's result ("win", "loss", "draw", "fled") for the step that reports done.
var outcome: String = ""
## Who the finished duel was against: "scripted" or "policy" (a self-play snapshot).
var opponent: String = ""


func _init() -> void:
	sight.resize(PvpBrain.OBS_SIZE)


func get_obs() -> Dictionary:
	return {"obs": Array(sight)}


func get_info() -> Dictionary:
	return {} if outcome.is_empty() else {"result": outcome, "opponent": opponent}


func get_reward() -> float:
	return reward


func get_action_space() -> Dictionary:
	var space: Dictionary = {}
	for head: String in PvpBrain.HEADS:
		space[head] = {"size": PvpBrain.HEADS[head], "action_type": "discrete"}
	return space


func set_action(action: Variant) -> void:
	var picked: Dictionary = action
	choice = {}
	for head: String in PvpBrain.HEADS:
		choice[head] = int(picked.get(head, 0))


## The arena counts steps and ends episodes itself.
func _physics_process(_delta: float) -> void:
	pass
