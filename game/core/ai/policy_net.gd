extends RefCounted
## A trained combat policy run in plain GDScript, so the game needs neither Python nor the .NET
## build: a small multilayer perceptron whose weights tools/training/export_policy.py writes as
## JSON (game/data/policies/). observe() numbers go in (game/core/ai/pvp_brain.gd); one score per
## choice of each head comes out, and choose() takes the best one, or with `noise` sometimes a
## random one (the bots' difficulty, Bots.DIFFICULTY).
##
## File: {"version": 1, "obs_size": n, "heads": [{"name", "size"}...],
##        "layers": [{"inputs", "outputs", "activation": "tanh"|"linear", "weights": [outputs * inputs,
##        row by row], "biases": [outputs]}...]}; the last layer's outputs are the heads' scores in order.

const VERSION: int = 1
const PVP_PATH: String = "res://game/data/policies/pvp_duel.json"

var obs_size: int = 0
## [{name: String, size: int}] in output order.
var heads: Array[Dictionary] = []
## Per layer: [weights, biases, inputs, outputs, tanh].
var _layers: Array = []
static var _cache: Dictionary = {}


## The policy at `path`, loaded once per run and shared; null (with a warning only when the file
## exists but is broken) when there is none, so callers fall back to scripted play.
static func shared(path: String = PVP_PATH) -> RefCounted:
	if not _cache.has(path):
		_cache[path] = load_file(path)
	return _cache[path]


static func load_file(path: String) -> RefCounted:
	if not FileAccess.file_exists(path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var net: RefCounted = from_dict(data) if data is Dictionary else null
	if net == null:
		push_warning("Ignoring the broken policy file %s" % path)
	return net


## A policy from parsed JSON, or null when anything is missing or the sizes do not chain.
static func from_dict(data: Dictionary) -> RefCounted:
	var net: RefCounted = new()
	if int(data.get("version", 0)) != VERSION or not data.get("heads") is Array or not data.get("layers") is Array:
		return null
	net.obs_size = int(data.get("obs_size", 0))
	var outputs: int = 0
	for head: Variant in data["heads"]:
		if not head is Dictionary or int(head.get("size", 0)) <= 0:
			return null
		net.heads.append({"name": String(head.get("name", "")), "size": int(head["size"])})
		outputs += int(head["size"])
	var width: int = net.obs_size
	for layer: Variant in data["layers"]:
		if not layer is Dictionary:
			return null
		var inputs: int = int(layer.get("inputs", 0))
		var size: int = int(layer.get("outputs", 0))
		var weights := PackedFloat32Array(layer.get("weights", []))
		var biases := PackedFloat32Array(layer.get("biases", []))
		if inputs != width or size <= 0 or weights.size() != inputs * size or biases.size() != size:
			return null
		net._layers.append([weights, biases, inputs, size, layer.get("activation", "linear") == "tanh"])
		width = size
	if net._layers.is_empty() or width != outputs or net.obs_size <= 0:
		return null
	return net


## The scores of every choice, heads one after another.
func scores(obs: PackedFloat32Array) -> PackedFloat32Array:
	var values: PackedFloat32Array = obs
	for layer: Array in _layers:
		var weights: PackedFloat32Array = layer[0]
		var biases: PackedFloat32Array = layer[1]
		var inputs: int = layer[2]
		var outputs: int = layer[3]
		var squash: bool = layer[4]
		var result := PackedFloat32Array()
		result.resize(outputs)
		for row: int in outputs:
			var total: float = biases[row]
			var base: int = row * inputs
			for column: int in inputs:
				total += weights[base + column] * values[column]
			result[row] = tanh(total) if squash else total
		values = result
	return values


## One choice per head (name -> index): the best score, or drawn by the scores' softmax when
## `sample` (as in training), or with chance `noise` a random choice.
func choose(obs: PackedFloat32Array, rng: RandomNumberGenerator, noise: float = 0.0, sample: bool = false) -> Dictionary:
	var choice: Dictionary = {}
	if obs.size() != obs_size:
		return choice
	var values: PackedFloat32Array = scores(obs)
	var at: int = 0
	for head: Dictionary in heads:
		var size: int = head["size"]
		var best: int = 0
		for index: int in range(1, size):
			if values[at + index] > values[at + best]:
				best = index
		if sample:
			best = _draw(values, at, size, values[at + best], rng)
		if noise > 0.0 and rng.randf() < noise:
			best = rng.randi_range(0, size - 1)
		choice[head["name"]] = best
		at += size
	return choice


## A choice among scores[at, at + size) with softmax odds (`top` is their maximum).
static func _draw(values: PackedFloat32Array, at: int, size: int, top: float, rng: RandomNumberGenerator) -> int:
	var total: float = 0.0
	for index: int in size:
		total += exp(values[at + index] - top)
	var left: float = rng.randf() * total
	for index: int in size:
		left -= exp(values[at + index] - top)
		if left <= 0.0:
			return index
	return size - 1
