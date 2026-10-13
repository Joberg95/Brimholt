extends Node3D
## The 3D world view (the renderer the game window shows with game.renderer_3d): a fixed
## angled camera following your character with zoom, a sun and sky that follow the shared
## day/night clock and zone ambience, terrain streamed in chunks around the camera
## (terrain_3d.gd), and players, NPCs, monsters, and ground items synced from the main
## node's interpolated views each frame. Night lights: town torches and lanterns from a small
## pool, a held torch lighting far more. Screen <-> tile mapping for clicks lives here too.

const World = preload("res://game/core/world.gd")
const Combat = preload("res://game/core/combat.gd")
const Monsters = preload("res://game/data/monsters.gd")
const Lighting = preload("res://game/render/lighting.gd")
const SpriteArt = preload("res://game/render/sprite_art.gd")
const Terrain = preload("res://game/render3d/terrain_3d.gd")
const Character = preload("res://game/render3d/character_3d.gd")
const Creature = preload("res://game/render3d/creature_3d.gd")

## Camera: looks down at PITCH degrees from ZOOM tiles away (wheel changes it within bounds).
const PITCH: float = 52.0
const FOV: float = 32.0
const MIN_ZOOM: float = 10.0
const MAX_ZOOM: float = 30.0
const DEFAULT_ZOOM: float = 17.0
## Chunks within VIEW_CHUNKS of the camera's chunk are built (BUILDS_PER_FRAME at most per
## frame) and those beyond KEEP_CHUNKS freed, so memory stays flat while you travel.
const VIEW_CHUNKS: int = 2
const KEEP_CHUNKS: int = 3
const BUILDS_PER_FRAME: int = 2
## Creatures and items are shown within this many tiles of the camera.
const SHOW_RADIUS: int = 26
const LIGHTS: int = 16
const TORCH_GLOW: Color = Color(1.0, 0.62, 0.3)
const LANTERN: Color = Color(1.0, 0.82, 0.55)

var game: Node
var camera: Camera3D
var sun: DirectionalLight3D
var environment: Environment
var zoom: float = DEFAULT_ZOOM
## How dark it is (0 day .. 1 deep night or dark dungeon), for the light pool and the overlay.
var darkness: float = 0.0
## Node by id or cell, for the overlay: creatures' heads and NPC names come from these.
var actor_nodes: Dictionary = {}
var monster_nodes: Dictionary = {}
var npc_nodes: Dictionary = {}
var _chunks: Dictionary = {}
var _items: Dictionary = {}
var _lights: Array[OmniLight3D] = []
var _focus: Vector2 = Vector2.ZERO


func _ready() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.35
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 1.2
	environment.ssao_enabled = true
	environment.ssao_radius = 1.2
	environment.ssao_intensity = 1.6
	environment.fog_enabled = true
	environment.fog_density = 0.006
	environment.fog_sky_affect = 0.0
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = FOV
	camera.far = 160.0
	add_child(camera)
	for index: int in LIGHTS:
		var light := OmniLight3D.new()
		light.visible = false
		light.shadow_enabled = false
		add_child(light)
		_lights.append(light)


func _process(delta: float) -> void:
	_focus = game.camera_focus() / World.TILE_SIZE
	var target := Vector3(_focus.x, 0.0, _focus.y)
	var pitch: float = deg_to_rad(PITCH)
	camera.position = target + Vector3(0.0, sin(pitch), cos(pitch)) * zoom
	camera.look_at(target, Vector3.UP)
	_stream_chunks()
	_light_world()
	var area := Rect2i(Vector2i(_focus) - Vector2i.ONE * SHOW_RADIUS, Vector2i.ONE * SHOW_RADIUS * 2)
	_sync_actors(delta)
	_sync_monsters(delta, area)
	_sync_npcs(area)
	_sync_items(area)
	_place_lights(area)


func zoom_by(steps: float) -> void:
	zoom = clampf(zoom * pow(1.12, steps), MIN_ZOOM, MAX_ZOOM)


# ---------------------------------------------------------------- mapping

## A map point (pixels, as the 2D view uses) on the ground, in game window coordinates.
func screen_point(map_point: Vector2) -> Vector2:
	return camera.unproject_position(Vector3(map_point.x, 0.0, map_point.y) / World.TILE_SIZE)


## The tile under a game window position: a creature whose body is drawn there, else the ground.
func cell_at(at: Vector2) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var nearest: float = 30.0
	for group: Dictionary in [actor_nodes, monster_nodes]:
		for id: int in group:
			var body: Node3D = group[id]
			if not body.visible or camera.is_position_behind(body.position):
				continue
			var spot: Vector2 = camera.unproject_position(body.position + Vector3(0, 0.55 * body.scale.y, 0))
			if spot.distance_to(at) < nearest:
				nearest = spot.distance_to(at)
				best = Vector2i(floori(body.position.x), floori(body.position.z))
	if best.x >= 0:
		return best
	var origin: Vector3 = camera.project_ray_origin(at)
	var direction: Vector3 = camera.project_ray_normal(at)
	if absf(direction.y) < 0.0001:
		return Vector2i(-1, -1)
	var hit: Vector3 = origin + direction * (-origin.y / direction.y)
	return Vector2i(floori(hit.x), floori(hit.z))


## Screen position of a point `height` tiles above a creature node's feet.
func head_of(body: Node3D, height: float) -> Vector2:
	return camera.unproject_position(body.position + Vector3(0, height, 0))


# ---------------------------------------------------------------- terrain

func _stream_chunks() -> void:
	var here := Vector2i(floori(_focus.x / Terrain.CHUNK), floori(_focus.y / Terrain.CHUNK))
	var built: int = 0
	for radius: int in VIEW_CHUNKS + 1:
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				var chunk: Vector2i = here + Vector2i(dx, dy)
				if _chunks.has(chunk) or built >= BUILDS_PER_FRAME:
					continue
				var node: Node3D = Terrain.build(chunk)
				_chunks[chunk] = node
				if node != null:
					add_child(node)
					built += 1
	for chunk: Vector2i in _chunks.keys():
		if maxi(absi(chunk.x - here.x), absi(chunk.y - here.y)) > KEEP_CHUNKS:
			if _chunks[chunk] != null:
				_chunks[chunk].queue_free()
			_chunks.erase(chunk)


# ---------------------------------------------------------------- light

func _light_world() -> void:
	var lighting: Node2D = game._world_view.lighting
	var phase: float = lighting.time_of_day()
	var day: Color = Lighting.daylight(phase)
	var zone: Dictionary = World.zone_at(Vector2i(_focus))
	var tint: Color = zone.get("ambient", Color.WHITE)
	var underground: bool = zone.get("underground", false)
	var brightness: float = (day.r + day.g + day.b) / 3.0
	darkness = 1.0 if zone.get("dark", false) else clampf((1.0 - brightness * (tint.r + tint.g + tint.b) / 3.0) / 0.55, 0.0, 1.0)
	# The sun crosses from east to west over the day; at night a dim blue moon lights the scene.
	var arc: float = (phase - 0.25) * TAU
	sun.rotation = Vector3(-deg_to_rad(35.0 + 30.0 * absf(sin(arc))), deg_to_rad(-40.0) + arc * 0.25, 0.0)
	sun.light_color = day * tint
	sun.light_energy = 0.0 if underground else lerpf(0.08, 1.0, brightness)
	environment.ambient_light_color = (day * tint).lerp(Color(0.35, 0.4, 0.6), 0.35)
	environment.ambient_light_energy = lerpf(0.12, 0.38, brightness) * (0.25 if zone.get("dark", false) else 1.0)
	environment.background_color = (day * tint).darkened(0.55)
	environment.fog_light_color = (day * tint).darkened(0.2)


func _place_lights(area: Rect2i) -> void:
	var used: int = 0
	var time: float = Time.get_ticks_msec() / 1000.0
	if darkness > 0.1:
		for id: int in actor_nodes:
			if used >= LIGHTS or not game.actors.has(id):
				continue
			var holds_torch: bool = Lighting.holds_torch(game.actors[id]["state"]["equipment"])
			var radius: float = 7.0 if holds_torch else (1.6 if darkness >= 1.0 else 4.5)
			if id != game.self_id and not holds_torch:
				radius *= 0.7
			used = _light(used, actor_nodes[id].position + Vector3(0, 1.4, 0), TORCH_GLOW if holds_torch else LANTERN, radius,
				1.4 * darkness * (0.92 + 0.08 * sin(time * 8.0 + id)))
		for cell: Vector2i in World.TORCHES:
			if used >= LIGHTS:
				break
			if area.has_point(cell):
				used = _light(used, Vector3(cell.x + 0.5, 1.0, cell.y + 1.05), TORCH_GLOW, 4.0,
					1.6 * darkness * (0.9 + 0.1 * sin(time * 9.0 + cell.x * 1.7)))
	for index: int in range(used, LIGHTS):
		_lights[index].visible = false


func _light(index: int, at: Vector3, color: Color, radius: float, energy: float) -> int:
	var light: OmniLight3D = _lights[index]
	light.visible = true
	light.position = at
	light.light_color = color
	light.omni_range = radius
	light.light_energy = energy
	return index + 1


# ---------------------------------------------------------------- creatures

static func _ground(visual: Vector2) -> Vector3:
	return Vector3(visual.x + 0.5, 0.0, visual.y + 0.5)


static func _turn(node: Node3D, facing: Vector2i) -> void:
	node.rotation.y = atan2(float(facing.x), float(facing.y))


func _sync_actors(_delta: float) -> void:
	var time: float = Time.get_ticks_msec() / 1000.0
	for id: int in actor_nodes.keys():
		if not game.actors.has(id):
			actor_nodes[id].queue_free()
			actor_nodes.erase(id)
	for id: int in game.actors:
		var view: Dictionary = game.actors[id]
		var state: Dictionary = SpriteArt.posed(view, time)
		var vocation: String = String(state.get("vocation", "adventurer"))
		var body: Node3D = actor_nodes.get(id)
		if body == null or body.vocation != vocation:
			if body != null:
				body.queue_free()
			body = Character.new()
			add_child(body)
			body.setup(vocation)
			actor_nodes[id] = body
		body.position = _ground(view["visual"])
		_turn(body, state["facing"])
		body.set_gear(state.get("equipment", {}))
		body.animate(view["elapsed"] < view["duration"], state.has("attack"), Combat.attack_style(vocation, state.get("equipment", {})))


func _sync_monsters(delta: float, area: Rect2i) -> void:
	var time: float = Time.get_ticks_msec() / 1000.0
	var shown: Dictionary = {}
	for id: int in game.monsters_in(area):
		shown[id] = true
		var view: Dictionary = game.monsters[id]
		var state: Dictionary = SpriteArt.posed(view, time)
		var kind: String = state["kind"]
		var definition: Dictionary = Monsters.MONSTERS.get(kind, {})
		if definition.is_empty():
			continue
		var body: Node3D = monster_nodes.get(id)
		if body == null:
			if definition["look"] == "humanoid":
				body = Character.new()
				add_child(body)
				body.setup(_humanoid_model(definition))
				body.set_gear(definition.get("gear", {}))
				body.scale = Vector3.ONE * float(definition["size"])
			else:
				body = Creature.new()
				add_child(body)
				body.setup(kind)
			monster_nodes[id] = body
		body.position = _ground(view["visual"])
		_turn(body, state["facing"])
		var moving: bool = view["elapsed"] < view["duration"]
		if body is Character:
			body.animate(moving, state.has("attack"), "paladin" if definition["range"] > 1 else "knight")
		else:
			body.animate(delta, moving, state.has("attack"))
	for id: int in monster_nodes.keys():
		if not shown.has(id):
			monster_nodes[id].queue_free()
			monster_nodes.erase(id)


## Humanoid monsters borrow a character by their weapon: casters robed, archers hooded, others armoured.
static func _humanoid_model(definition: Dictionary) -> String:
	var weapon: Dictionary = World.ITEMS.get(String(definition.get("gear", {}).get("main_hand", "")), {})
	var shape: String = String(weapon.get("look", ""))
	if shape in ["wand", "rod"]:
		return "sorcerer"
	if shape in ["bow", "crossbow"]:
		return "paladin"
	return "knight" if definition.get("gear", {}).has("helmet") else "druid"


func _sync_npcs(area: Rect2i) -> void:
	for cell: Vector2i in npc_nodes.keys():
		if not area.has_point(cell):
			npc_nodes[cell].queue_free()
			npc_nodes.erase(cell)
	for cell: Vector2i in World.NPC_CELLS:
		if not area.has_point(cell) or npc_nodes.has(cell):
			continue
		var npc: Dictionary = World.npc(World.NPC_CELLS[cell])
		var body: Node3D
		if npc.get("vehicle", "") == "waystone":
			body = _waystone()
		else:
			body = Character.new()
			add_child(body)
			body.setup("knight" if "quests" in npc["services"] or "vocation" in npc["services"] else "adventurer")
			body.set_gear({"helmet": "ember_cap"} if npc.get("role", "") == "banker" else {})
			_turn(body, npc["facing"])
		if body.get_parent() == null:
			add_child(body)
		body.position = _ground(Vector2(cell))
		npc_nodes[cell] = body


## A carved standing stone with a glowing cyan rune.
static func _waystone() -> Node3D:
	var stone := Node3D.new()
	var block := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.55, 1.6, 0.4)
	block.mesh = mesh
	block.position = Vector3(0, 0.8, 0)
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color("#8a8f96")
	rock.roughness = 0.95
	block.material_override = rock
	stone.add_child(block)
	var rune := MeshInstance3D.new()
	var plate := BoxMesh.new()
	plate.size = Vector3(0.22, 0.32, 0.05)
	rune.mesh = plate
	rune.position = Vector3(0, 1.0, 0.21)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("#7fe8ff")
	glow.emission_enabled = true
	glow.emission = Color("#5ad8ff")
	glow.emission_energy_multiplier = 3.0
	rune.material_override = glow
	stone.add_child(rune)
	return stone


## Ground stacks show their top item's icon on a small billboard.
func _sync_items(area: Rect2i) -> void:
	var cells: Array[Vector2i] = game.ground_in(area)
	var seen: Dictionary = {}
	for cell: Vector2i in cells:
		var stack: Array = game.ground_view.get(cell, [])
		if stack.is_empty():
			continue
		var kind: String = World.kind_of(stack.back())
		seen[cell] = true
		var icon: Sprite3D = _items.get(cell)
		if icon == null:
			icon = Sprite3D.new()
			icon.texture = SpriteArt.ITEM_ICONS
			icon.region_enabled = true
			icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			icon.pixel_size = 0.018
			icon.position = Vector3(cell.x + 0.5, 0.3, cell.y + 0.5)
			add_child(icon)
			_items[cell] = icon
		if not icon.has_meta("kind") or icon.get_meta("kind") != kind:
			icon.set_meta("kind", kind)
			icon.region_rect = SpriteArt.item_region(kind)
	for cell: Vector2i in _items.keys():
		if not seen.has(cell):
			_items[cell].queue_free()
			_items.erase(cell)
