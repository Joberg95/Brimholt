extends Node
## The sound engine: plays the game's sounds (game/data/sounds.gd) on their buses (Music,
## Ambience, Effects, UI, each sent to Master), with volumes saved in the client settings.
##
## Effects in the world play from a fixed pool of POOL_SIZE AudioStreamPlayer2D under the world
## view, heard from an AudioListener2D at the camera; when every player is busy the oldest sound
## is cut off. Sounds farther than HEARING_TILES are not played. Sounds without a place (your own
## level up, coins, book pages) use a few plain AudioStreamPlayer. Ambience is two looping
## layers ("bed" and "rain") that fade between places and weather, and storms add thunder a
## moment after each lightning flash. Everything is presentation only: the host decides nothing
## from sound, and headless runs (tests, dedicated servers) start no playback at all.

const World = preload("res://game/core/world.gd")
const Monsters = preload("res://game/data/monsters.gd")
const Biomes = preload("res://game/data/biomes.gd")
const Sounds = preload("res://game/data/sounds.gd")
const GameMenu = preload("res://game/ui/game_menu.gd")
const Layout = preload("res://game/ui/layout.gd")

const POOL_SIZE: int = 16
const FLAT_SIZE: int = 4
const HEARING_TILES: int = 12
## Bus -> default volume (0..1). Music has no slider until there is music.
const VOLUMES: Dictionary = {"Master": 0.8, "Ambience": 0.6, "Effects": 0.8, "UI": 0.7}
const SETTINGS_SECTION: String = "audio"
## Seconds for an ambience layer to fade fully in or out.
const FADE_SECONDS: float = 2.5
## How often the ambience looks at the place and weather again.
const AMBIENCE_SECONDS: float = 0.5
## A monster speaks at most once per VOICE_SECONDS while it fights.
const VOICE_SECONDS: float = 8.0

var game: Node
var volumes: Dictionary = VOLUMES.duplicate()
var muted: bool = false
## False in headless runs (tests, dedicated servers): everything is chosen and set up but
## nothing starts playing, so no playback is left running when they quit.
var audible: bool = DisplayServer.get_name() != "headless"
## Plays this many effects at most at once (tests read it).
var pool: Array[AudioStreamPlayer2D] = []
var _flat: Array[AudioStreamPlayer] = []
var _next: int = 0
var _next_flat: int = 0
var _listener: AudioListener2D
var _streams: Dictionary = {}
## Layer -> {"player", "id", "level" (current 0..1), "target" (0..1), "want" (id to fade to)}.
var _layers: Dictionary = {}
var _next_ambience: float = 0.0
var _voiced: Dictionary = {}
var _flash: float = 0.0
## [time, id, cell, volume] of sounds still to play (later()).
var _pending: Array = []


## Creates the buses once per run (they live in the AudioServer, not in a scene).
static func ensure_buses() -> void:
	for bus: String in Sounds.BUSES:
		if AudioServer.get_bus_index(bus) >= 0:
			continue
		AudioServer.add_bus()
		var index: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus)
		AudioServer.set_bus_send(index, "Master")


## `world_view` holds the positional players and the listener; without one (tests) they sit here.
func setup(game_node: Node, world_view: Node2D) -> void:
	game = game_node
	name = "Sound"
	ensure_buses()
	var holder: Node = self
	if world_view != null:
		holder = world_view
	for index: int in POOL_SIZE:
		var player := AudioStreamPlayer2D.new()
		player.bus = "Effects"
		# Distances are on screen, where the world view is zoomed.
		player.max_distance = (HEARING_TILES + 1) * World.TILE_SIZE * Layout.ZOOM
		player.attenuation = 1.5
		player.max_polyphony = 1
		holder.add_child(player)
		pool.append(player)
	for index: int in FLAT_SIZE:
		var flat := AudioStreamPlayer.new()
		flat.bus = "UI"
		add_child(flat)
		_flat.append(flat)
	for layer: String in ["bed", "rain"]:
		var loop := AudioStreamPlayer.new()
		loop.bus = "Ambience"
		add_child(loop)
		_layers[layer] = {"player": loop, "id": "", "level": 0.0, "target": 0.0, "want": ""}
	_listener = AudioListener2D.new()
	holder.add_child(_listener)
	_listener.make_current()
	load_settings()
	if audible:
		# Load every sound up front (a few MB), so the first fight does not stall on disk and
		# memory stays level while playing.
		for id: String in Sounds.SOUNDS:
			for path: String in Sounds.SOUNDS[id]["files"]:
				_stream(path)


# ---------------------------------------------------------------- playing

## Plays a sound id at a map tile (heard from the camera) or, with no tile, flat. Returns the
## player used, or null when the sound is unknown, too far away, or its file is missing.
func play(id: String, cell: Variant = null, volume: float = 1.0) -> Node:
	if not Sounds.exists(id) or volume <= 0.0:
		return null
	var sound: Dictionary = Sounds.SOUNDS[id]
	var stream: AudioStream = _stream(sound["files"][randi() % sound["files"].size()])
	if stream == null:
		return null
	var pitch: float = 1.0 + randf_range(-sound["pitch"], sound["pitch"])
	if cell is Vector2i:
		if World.chebyshev(cell, listener_cell()) > HEARING_TILES:
			return null
		var player: AudioStreamPlayer2D = pool[_next]
		_next = (_next + 1) % pool.size()
		player.stop()
		player.stream = stream
		player.bus = sound["bus"]
		player.volume_db = sound["db"] + linear_to_db(volume)
		player.pitch_scale = pitch
		player.position = (Vector2(cell) + Vector2(0.5, 0.5)) * World.TILE_SIZE
		if audible:
			player.play()
		return player
	var flat: AudioStreamPlayer = _flat[_next_flat]
	_next_flat = (_next_flat + 1) % _flat.size()
	flat.stop()
	flat.stream = stream
	flat.bus = sound["bus"]
	flat.volume_db = sound["db"] + linear_to_db(volume)
	flat.pitch_scale = pitch
	if audible:
		flat.play()
	return flat


## The tile the listener stands on (the camera's focus).
func listener_cell() -> Vector2i:
	if game == null or not game.has_method("camera_focus"):
		return Vector2i.ZERO
	return Vector2i((game.camera_focus() / World.TILE_SIZE).floor())


func _stream(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if stream == null:
		push_warning("Missing sound file " + path)
	_streams[path] = stream
	return stream


# ---------------------------------------------------------------- game events

## A combat event the view shows (Main._show_effect): hits, missiles, and spell areas.
func on_event(event: Dictionary) -> void:
	var id: String = Sounds.for_event(event)
	match event.get("kind", ""):
		"hit":
			play(id, event.get("cell"))
			var source: int = int(event.get("source", 0))
			if source < 0 and event.get("style", "") in ["damage", "critical"]:
				_voice(source)
		"missile":
			play(id, event["from"])
			var landing: String = Sounds.landing(event)
			if not landing.is_empty():
				later(0.25, landing, event["to"])
		"area":
			var cells: Array = event.get("cells", [])
			if not cells.is_empty():
				play(id, cells[0])


## A monster speaks as it attacks, now and then.
func _voice(monster: int) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now < _voiced.get(monster, -INF):
		return
	_voiced[monster] = now + VOICE_SECONDS * randf_range(0.7, 1.3)
	var view: Dictionary = game.monsters.get(monster, {}) if game != null else {}
	if view.is_empty():
		return
	play(_voices_of(view)[0], Vector2i(view["visual"].round()))


## A monster died where its view stood.
func monster_died(view: Dictionary) -> void:
	_voiced.erase(view.get("state", {}).get("id", 0))
	play(_voices_of(view)[1], Vector2i(view["visual"].round()))


func _voices_of(view: Dictionary) -> Array:
	var kind: String = view["state"].get("kind", "")
	return Sounds.monster_voices(kind, Monsters.MONSTERS.get(kind, {}).get("look", ""))


## Your own character changed: footsteps as you step, coins and pick-ups, and level ups.
func own_update(before: Dictionary, after: Dictionary) -> void:
	if before.is_empty():
		return
	if after["cell"] != before["cell"]:
		play(Sounds.footstep(after["cell"]), after["cell"])
	if after.get("level", 1) > before.get("level", 1) or after.get("title", 0) > before.get("title", 0):
		play("level_up")
	if after.has("backpack") and before.has("backpack"):
		if after.get("gold", 0) > before.get("gold", 0):
			play("coins")
		elif _items(after) > _items(before):
			play("pick_up")


## Items carried, counting every stack (bags' contents are part of the backpack).
static func _items(state: Dictionary) -> int:
	var total: int = 0
	for entry: String in state["backpack"]:
		if not entry.is_empty():
			total += World.count_of(entry)
	return total


# ---------------------------------------------------------------- ambience

## Stops every sound as the game closes: a loop still playing at exit keeps its stream alive.
func _exit_tree() -> void:
	_pending.clear()
	_silence()
	for player: Node in pool + _flat:
		player.stop()
		player.stream = null


func _silence() -> void:
	for layer: String in _layers:
		var entry: Dictionary = _layers[layer]
		if entry["player"].stream != null:
			entry["player"].stop()
			entry["player"].stream = null
		entry["id"] = ""
		entry["want"] = ""
		entry["level"] = 0.0
		entry["target"] = 0.0


## Plays a sound after `seconds` (a missile landing, thunder after its flash). Queued here rather
## than on SceneTree timers, so nothing outlives the engine when the game quits.
func later(seconds: float, id: String, cell: Variant = null, volume: float = 1.0) -> void:
	_pending.append([Time.get_ticks_msec() / 1000.0 + seconds, id, cell, volume])


func _process(delta: float) -> void:
	var clock: float = Time.get_ticks_msec() / 1000.0
	for index: int in range(_pending.size() - 1, -1, -1):
		if _pending[index][0] <= clock:
			var due: Array = _pending[index]
			_pending.remove_at(index)
			play(due[1], due[2], due[3])
	if game == null:
		return
	_listener.position = game.camera_focus()
	if not game_active():
		# Leaving a game silences the loops at once, while the mixer still runs to release them.
		_silence()
		return
	if clock >= _next_ambience:
		_next_ambience = clock + AMBIENCE_SECONDS
		var place: Dictionary = _place()
		set_ambience(Sounds.ambience(place))
		_thunder(place)
	_fade(delta)


## Where the camera is, for Sounds.ambience: the location, climate, night, and weather.
func _place() -> Dictionary:
	var cell: Vector2i = listener_cell()
	var weather: Dictionary = {}
	var phase: float = 0.5
	var view: Node = game._world_view if "_world_view" in game else null
	if view != null and view.get("lighting") != null:
		weather = view.lighting.weather
		phase = view.lighting.time_of_day()
	var day: float = clampf(1.0 - absf(phase - 0.5) * 2.0, 0.0, 1.0)
	var location: Dictionary = World.location_at(cell)
	return {
		"kind": location.get("kind", ""), "region": World.region_at(cell),
		"underground": World.zone_at(cell).get("underground", false) or weather.get("kind", "") == "underground",
		"desert": Biomes.in_desert(cell), "isles": Biomes.in_isles(cell), "snow": weather.get("snow", false),
		"night": 1.0 - smoothstep(0.15, 0.35, day), "rain": weather.get("rain", 0.0),
		"flash": weather.get("flash", 0.0), "storm": weather.get("storm", 0.0),
	}


## Sets what each ambience layer should play ({layer: [sound id, 0..1]}); layers fade there.
func set_ambience(layers: Dictionary) -> void:
	if not game_active():
		layers = {}
	for layer: String in _layers:
		var entry: Dictionary = _layers[layer]
		var wanted: Array = layers.get(layer, ["", 0.0])
		entry["want"] = wanted[0]
		entry["target"] = wanted[1] if not wanted[0].is_empty() else 0.0


## Ambience plays only in a game, not over the start screen.
func game_active() -> bool:
	return game != null and game.get("connected") == true and game.get("self_id") != 0


func _fade(delta: float) -> void:
	var step: float = delta / FADE_SECONDS
	for layer: String in _layers:
		var entry: Dictionary = _layers[layer]
		var player: AudioStreamPlayer = entry["player"]
		if entry["want"] != entry["id"]:
			# Fade the old loop out, then start the new one from silence.
			entry["level"] = maxf(0.0, entry["level"] - step * 2.0)
			if entry["level"] <= 0.0:
				entry["id"] = entry["want"]
				player.stop()
				if not entry["id"].is_empty():
					var sound: Dictionary = Sounds.SOUNDS[entry["id"]]
					var stream: AudioStream = _stream(sound["files"][0])
					if stream != null:
						_loop(stream)
						player.stream = stream
						if audible:
							player.play(randf() * maxf(0.0, stream.get_length() - 1.0))
		else:
			entry["level"] = move_toward(entry["level"], entry["target"], step)
		if not entry["id"].is_empty():
			var level: float = entry["level"]
			player.volume_db = Sounds.SOUNDS[entry["id"]]["db"] + linear_to_db(maxf(level, 0.0001))


static func _loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD


## Thunder rolls a moment after each lightning flash, louder in a full storm.
func _thunder(place: Dictionary) -> void:
	var flash: float = place.get("flash", 0.0)
	if flash > 0.4 and _flash <= 0.4 and game_active():
		var volume: float = clampf(place.get("storm", 0.0), 0.3, 1.0)
		later(randf_range(0.3, 1.5), "thunder", null, volume)
	_flash = flash


## Current level and sound of an ambience layer, for tests.
func layer_state(layer: String) -> Dictionary:
	var entry: Dictionary = _layers[layer]
	return {"id": entry["id"], "want": entry["want"], "level": entry["level"], "target": entry["target"]}


# ---------------------------------------------------------------- settings

## Sets a bus's volume (0..1) and saves it when `save`.
func set_volume(bus: String, value: float, save: bool = true) -> void:
	volumes[bus] = clampf(value, 0.0, 1.0)
	_apply()
	if save:
		save_settings()


func toggle_mute() -> void:
	muted = not muted
	_apply()
	save_settings()


func _apply() -> void:
	for bus: String in volumes:
		var index: int = AudioServer.get_bus_index(bus)
		if index >= 0:
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volumes[bus], 0.0001)))
			AudioServer.set_bus_mute(index, volumes[bus] <= 0.0 or (bus == "Master" and muted))


func _persistent() -> bool:
	return game != null and game.get("keybinds") != null and game.keybinds.persistent


func load_settings() -> void:
	volumes = VOLUMES.duplicate()
	muted = false
	var file := ConfigFile.new()
	if _persistent() and file.load(_settings_path()) == OK:
		for bus: String in VOLUMES:
			var value: Variant = file.get_value(SETTINGS_SECTION, bus, VOLUMES[bus])
			if typeof(value) in [TYPE_FLOAT, TYPE_INT]:
				volumes[bus] = clampf(float(value), 0.0, 1.0)
		muted = file.get_value(SETTINGS_SECTION, "muted", false) == true
	_apply()


func save_settings() -> void:
	if not _persistent():
		return
	# The same file as the game menu's settings, in its own section.
	var file := ConfigFile.new()
	file.load(_settings_path())
	for bus: String in volumes:
		file.set_value(SETTINGS_SECTION, bus, volumes[bus])
	file.set_value(SETTINGS_SECTION, "muted", muted)
	file.save(_settings_path())


static func _settings_path() -> String:
	return GameMenu.SETTINGS_PATH
