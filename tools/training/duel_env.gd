extends Node
## The training environment Godot RL Agents' Python trainer talks to (tools/training/train.py):
## ARENAS duels (duel_arena.gd) side by side in one headless process, each with a learner seat
## (duel_controller.gd) that the Sync node reads and drives. Every physics frame, after Sync has
## handed out the trainer's choices, each seat with a choice plays one turn; a finished duel
## reports done and a new one starts at once, so its next observation opens the next episode.
##
## Self-play: with --opponents=<directory of exported policy JSON> and --self_play=<share>, that
## share of duels pits the learner against a random earlier snapshot (train.py writes them)
## instead of the scripted bot.
##
##   godot --headless --path . res://tools/training/duel_env.tscn --port=11008 --env_seed=1 --arenas=16
## (tools/training/run_env.sh; train.py starts it.)

const DuelArena = preload("res://tools/training/duel_arena.gd")
const DuelController = preload("res://tools/training/duel_controller.gd")
const PolicyNet = preload("res://game/core/ai/policy_net.gd")
const DEFAULT_ARENAS: int = 16
## How often the opponents directory is listed again, in duels started.
const RESCAN_EVERY: int = 200

var arenas: Array[DuelArena] = []
var seats: Array[DuelController] = []
var opponents_dir: String = ""
var self_play: float = 0.0
var rng := RandomNumberGenerator.new()
## Snapshot path -> PolicyNet (null when broken), and the current list of snapshot paths.
var _snapshots: Dictionary = {}
var _paths: PackedStringArray = PackedStringArray()
var _starts: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# After the Sync node, so this frame's choices are already set.
	process_physics_priority = 10
	var count: int = DEFAULT_ARENAS
	var seed_value: int = 1
	for argument: String in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if argument.begins_with("--arenas="):
			count = maxi(1, argument.get_slice("=", 1).to_int())
		elif argument.begins_with("--env_seed="):
			seed_value = argument.get_slice("=", 1).to_int()
		elif argument.begins_with("--opponents="):
			opponents_dir = argument.get_slice("=", 1)
		elif argument.begins_with("--self_play="):
			self_play = clampf(argument.get_slice("=", 1).to_float(), 0.0, 1.0)
	rng.seed = hash([seed_value, "opponents"])
	for index: int in count:
		var arena := DuelArena.new()
		arena.rng.seed = hash([seed_value, index])
		var seat := DuelController.new()
		seat.name = "Seat%d" % index
		add_child(seat)
		arenas.append(arena)
		seats.append(seat)
		_open(index)


func _physics_process(_delta: float) -> void:
	for index: int in seats.size():
		var seat: DuelController = seats[index]
		if seat.needs_reset:
			seat.reset()
			_open(index)
			continue
		if seat.choice.is_empty():
			continue
		var arena: DuelArena = arenas[index]
		seat.outcome = ""
		seat.reward += arena.advance(int(seat.choice["move"]), int(seat.choice["act"]))
		seat.choice = {}
		if arena.finished():
			seat.done = true
			seat.outcome = arena.result
			seat.opponent = arena.setup["opponent"]
			_open(index)
		else:
			seat.sight = arena.observe()


## Starts the next duel in arena `index` and shows its first sight.
func _open(index: int) -> void:
	var options: Dictionary = {}
	var opponent: PolicyNet = _opponent()
	if opponent != null:
		options["opponent"] = opponent
	arenas[index].start(options)
	seats[index].sight = arenas[index].observe()


## A random snapshot for a self-play duel, or null for a scripted one.
func _opponent() -> PolicyNet:
	if self_play <= 0.0 or opponents_dir.is_empty():
		return null
	if _starts % RESCAN_EVERY == 0:
		_paths = PackedStringArray()
		for file: String in DirAccess.get_files_at(opponents_dir):
			if file.ends_with(".json"):
				_paths.append(opponents_dir.path_join(file))
	_starts += 1
	if _paths.is_empty() or rng.randf() >= self_play:
		return null
	var path: String = _paths[rng.randi() % _paths.size()]
	if not _snapshots.has(path):
		_snapshots[path] = PolicyNet.load_file(path)
	return _snapshots[path] as PolicyNet
