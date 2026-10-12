extends Node2D
## Ambient light and point lights for the world viewport (a child of the world view, so it
## shares its map-pixel transform). A CanvasModulate tints the world by time of day, and
## darker in zones with an ambient colour (the Hollow Reach). Point lights from a CC0 Kenney
## light texture follow players (lanterns), NPCs, glowing relics and bosses, spells, and
## missiles; they fade in as the ambient darkens. Day and night follow the host's clock.

const World = preload("res://game/core/world.gd")
const Monsters = preload("res://game/data/monsters.gd")
const LIGHT_TEXTURE: Texture2D = preload("res://assets/third_party/kenney_particle_pack/light_01.png")
## A full day and night, in seconds of host time; a session starts in the morning.
const DAY_SECONDS: float = 2400.0
const DAY_START: float = 0.32
const NIGHT: Color = Color(0.34, 0.38, 0.58)
const DUSK: Color = Color(0.92, 0.72, 0.6)
const LANTERN: Color = Color(1.0, 0.82, 0.55)
## Light radius in tiles (the texture is 128 px wide, fading to its edge).
const LANTERN_TILES: float = 5.0
const GLOW_TILES: float = 3.5
const SPELL_TILES: float = 3.0

var view: Node2D
## Set 0..1 to pin the time of day (tests); negative follows the clock.
var time_override: float = -1.0
var modulate_node: CanvasModulate
var _lights: Dictionary = {}


func _ready() -> void:
	modulate_node = CanvasModulate.new()
	add_child(modulate_node)


## 0 midnight, 0.25 dawn, 0.5 noon, 0.75 dusk.
func time_of_day() -> float:
	if time_override >= 0.0:
		return time_override
	return fposmod(view.game.world_clock() / DAY_SECONDS + DAY_START, 1.0)


static func daylight(phase: float) -> Color:
	# Full day between 0.3 and 0.7, night outside 0.15-0.85, warm dusk and dawn between.
	var day: float = clampf(1.0 - absf(phase - 0.5) * 2.0, 0.0, 1.0)
	if day >= 0.4:
		return Color.WHITE
	if day >= 0.3:
		return DUSK.lerp(Color.WHITE, (day - 0.3) / 0.1)
	return NIGHT.lerp(DUSK, clampf((day - 0.15) / 0.15, 0.0, 1.0))


func ambient() -> Color:
	var light: Color = daylight(time_of_day())
	var game: Node = view.game
	var focus: Vector2i = Vector2i((game.camera_focus() / World.TILE_SIZE).floor())
	var zone: Dictionary = World.zone_at(focus)
	if zone.has("ambient"):
		light = light * zone["ambient"]
	return Color(light.r, light.g, light.b, 1.0)


func _process(_delta: float) -> void:
	var light: Color = ambient()
	modulate_node.color = light
	var darkness: float = clampf(1.0 - (light.r + light.g + light.b) / 3.0, 0.0, 1.0) / 0.55
	var game: Node = view.game
	var used: Dictionary = {}
	var area: Rect2i = view.visible_cells().grow(4)
	var time: float = Time.get_ticks_msec() / 1000.0
	if darkness > 0.01:
		for id: int in game.actors:
			var actor: Dictionary = game.actors[id]
			if area.has_point(Vector2i(actor["visual"])):
				_light("actor%d" % id, _centre(actor["visual"]), LANTERN, LANTERN_TILES * (1.0 if id == game.self_id else 0.7),
					1.15 * darkness, used)
		for cell: Vector2i in World.NPC_CELLS:
			if area.has_point(cell):
				_light("npc%s" % cell, _centre(Vector2(cell)), LANTERN, 3.0, 0.9 * darkness, used)
	# Coloured light from relics and glowing bosses, faint even by day.
	var tint: float = maxf(darkness, 0.18)
	for id: int in game.actors:
		var actor: Dictionary = game.actors[id]
		var glow: Variant = _glow_color(actor["state"]["equipment"])
		if glow != null and area.has_point(Vector2i(actor["visual"])):
			_light("relic%d" % id, _centre(actor["visual"]), glow, GLOW_TILES, 0.9 * tint, used)
	for id: int in game.monsters:
		var monster: Dictionary = game.monsters[id]
		var definition: Dictionary = Monsters.MONSTERS.get(monster["state"]["kind"], {})
		var glow: Variant = definition.get("glow", _glow_color(definition.get("gear", {})))
		if glow != null and area.has_point(Vector2i(monster["visual"])):
			_light("boss%d" % id, _centre(monster["visual"]), glow, GLOW_TILES * definition.get("size", 1.0), 1.0 * tint, used)
	for cell: Vector2i in game.ground_view:
		var stack: Array = game.ground_view[cell]
		if area.has_point(cell) and not stack.is_empty() and World.bound(stack.back()):
			_light("ground%s" % cell, _centre(Vector2(cell)), World.ITEMS[World.kind_of(stack.back())]["glow"], 2.0, 0.8 * tint, used)
	# Spells light their surroundings briefly, by day too.
	for index: int in game.effects.size():
		var effect: Dictionary = game.effects[index]
		var age: float = time - effect["born"]
		if effect["kind"] == "missile" and age < 0.3:
			var at: Vector2 = effect["from"].lerp(effect["to"], clampf(age / 0.25, 0.0, 1.0))
			_light("fx%d" % index, at, effect["color"], 1.6, 1.2 * maxf(darkness, 0.35), used)
		elif effect["kind"] == "area" and age < 0.6:
			var cells: Array = effect["cells"]
			var centre: Vector2 = Vector2.ZERO
			for cell: Vector2i in cells:
				centre += Vector2(cell)
			centre = centre / maxf(1.0, cells.size())
			_light("fx%d" % index, _centre(centre), effect["color"], SPELL_TILES, 1.4 * (1.0 - age / 0.6) * maxf(darkness, 0.35), used)
	for key: String in _lights:
		_lights[key].visible = used.has(key)


func _light(key: String, at: Vector2, color: Color, tiles: float, energy: float, used: Dictionary) -> void:
	var light: PointLight2D = _lights.get(key)
	if light == null:
		light = PointLight2D.new()
		light.texture = LIGHT_TEXTURE
		light.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(light)
		_lights[key] = light
	light.position = at
	light.color = color
	light.energy = energy
	light.texture_scale = tiles * 2.0 * World.TILE_SIZE / LIGHT_TEXTURE.get_width()
	used[key] = true


static func _centre(cell: Vector2) -> Vector2:
	return (cell + Vector2(0.5, 0.5)) * World.TILE_SIZE


static func _glow_color(equipment: Dictionary) -> Variant:
	for slot: String in equipment:
		var kind: String = String(equipment[slot])
		if World.ITEMS.has(kind) and World.ITEMS[kind].has("glow"):
			return World.ITEMS[kind]["glow"]
	return null
