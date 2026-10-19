extends SceneTree
## The trained PvP policy (game/data/policies/pvp_duel.json) against the scripted PvP bot on the
## real rules: same-level duels in a PvP zone (tools/training/duel_arena.gd), the policy bot
## running through Bots.run_policy inside the behavior tree as in the game. Prints the policy's
## win rate per vocation pair (rows: policy, columns: scripted foe) and overall. A loss also
## counts when the policy bot leaves the PvP zones; a draw is a half win.
##
##   godot --headless --path . --script res://tools/testing/duel_eval.gd -- [--games=10]
##       [--levels=10,20,30,40,50] [--difficulty=hard] [--policy=res://...json]
##       [--baseline]  (the scripted bot in the learner's seat too: about 50%)
##       [--rival=res://...json]  (that policy in the foe's seat instead of the scripted bot)

const DuelArena = preload("res://tools/training/duel_arena.gd")
const PolicyNet = preload("res://game/core/ai/policy_net.gd")
const PvpBrain = preload("res://game/core/ai/pvp_brain.gd")


func _initialize() -> void:
	var games: int = 10
	var levels: PackedStringArray = PackedStringArray(["10", "20", "30", "40", "50"])
	var difficulty: String = "hard"
	var path: String = PolicyNet.PVP_PATH
	var baseline: bool = false
	var rival_path: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--games="):
			games = maxi(1, argument.get_slice("=", 1).to_int())
		elif argument.begins_with("--levels="):
			levels = argument.get_slice("=", 1).split(",")
		elif argument.begins_with("--difficulty="):
			difficulty = argument.get_slice("=", 1)
		elif argument.begins_with("--policy="):
			path = argument.get_slice("=", 1)
		elif argument == "--baseline":
			baseline = true
		elif argument.begins_with("--rival="):
			rival_path = argument.get_slice("=", 1)
	var net: PolicyNet = null if baseline else PolicyNet.load_file(path) as PolicyNet
	if net == null and not baseline:
		push_error("No usable policy at %s" % path)
		quit(1)
		return
	var rival: PolicyNet = null
	if not rival_path.is_empty():
		rival = PolicyNet.load_file(rival_path) as PolicyNet
		if rival == null:
			push_error("No usable rival policy at %s" % rival_path)
			quit(1)
			return
	var arena := DuelArena.new()
	arena.rng.seed = 20261017
	var score: float = 0.0
	var played: int = 0
	var worst: float = 1.0
	var totals: Dictionary = {}
	var foe_name: String = "scripted" if rival == null else rival_path
	print("%s vs %s, difficulty %s, %d games per pair and level, levels %s" % [
		"scripted" if baseline else path, foe_name, difficulty, games, ",".join(levels)])
	print("%-10s %s" % ["", " ".join(PvpBrain.VOCATIONS.map(func(v: String) -> String: return "%9s" % v))])
	for vocation: String in PvpBrain.VOCATIONS:
		var row: String = "%-10s" % vocation
		for foe: String in PvpBrain.VOCATIONS:
			var pair_score: float = 0.0
			var pair_games: int = 0
			for level: String in levels:
				for _game: int in games:
					var options: Dictionary = {"learner": vocation, "foe": foe, "level": level.to_int(), "difficulty": difficulty}
					if baseline:
						options["scripted"] = true
					else:
						options["policy"] = net
						if rival != null:
							options["rival"] = rival
					arena.start(options)
					while not arena.finished():
						arena.advance()
					totals[arena.result] = totals.get(arena.result, 0) + 1
					pair_score += {"win": 1.0, "draw": 0.5}.get(arena.result, 0.0)
					pair_games += 1
			var rate: float = pair_score / pair_games
			worst = minf(worst, rate)
			score += pair_score
			played += pair_games
			row += " %8.0f%%" % (rate * 100.0)
		print(row)
	print("overall %.1f%% over %d duels, worst pair %.0f%%, results %s" % [score / played * 100.0, played, worst * 100.0, totals])
	quit()
