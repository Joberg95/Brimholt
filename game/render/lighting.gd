extends Node2D
## Ambient light and point lights for the world viewport (a child of the world view, so it
## shares its map-pixel transform). A CanvasModulate tints the world by time of day, darker
## in zones with an ambient colour (the Hollow Reach) and under clouds (weather.gd), and
## briefly bright with lightning. Point lights from a CC0 Kenney
## light texture follow players holding a torch, NPCs, glowing relics and bosses, spells, and
## missiles; they fade in as the ambient darkens. Day and night follow the host's clock.

const World = preload("res://game/core/world.gd")
const Monsters = preload("res://game/data/monsters.gd")
const Weather = preload("res://game/render/weather.gd")
const SpriteArt = preload("res://game/render/sprite_art.gd")
const LIGHT_TEXTURE: Texture2D = preload("res://assets/third_party/kenney_particle_pack/light_01.png")
## A full day and night, in seconds of host time; a session starts in the morning.
const DAY_SECONDS: float = 2400.0
const DAY_START: float = 0.32
const NIGHT: Color = Color(0.34, 0.38, 0.58)
const DUSK: Color = Color(0.92, 0.72, 0.6)
## The warm lamp light around NPCs. Light radii are in tiles (the texture is 128 px wide,
## fading to its edge).
const LANTERN: Color = Color(1.0, 0.82, 0.55)
## A held torch (look "torch" in the off hand) lights TORCH_TILES around its holder; players
## without one carry no light.
const TORCH_TILES: float = 6.0
const GLOW_TILES: float = 3.5
const SPELL_TILES: float = 3.0

var view: Node2D
## Set 0..1 to pin the time of day (tests); negative follows the clock.
var time_override: float = -1.0
var modulate_node: CanvasModulate
## The light before weather: what time of day and the zone alone would give.
var clear_light: Color = Color.WHITE
## The camera is in a "dark" dungeon (pitch black but for torches).
var dark_zone: bool = false
## The weather at the camera this frame (Weather.local), read by the rain layer.
var weather: Dictionary = {"kind": "clear", "cloud": 0.0, "rain": 0.0, "storm": 0.0, "flash": 0.0}
## Point lights reused every frame in request order; the pool only grows to the most lights
## ever shown at once (at most MAX_LIGHTS), so no node is created per creature or tile.
const MAX_LIGHTS: int = 64
const WAYSTONE_GLOW: Color = Color("#7fe8f0")
const TORCH_GLOW: Color = Color(1.0, 0.66, 0.32)
## Town wall torches burn once the darkness passes this (dusk onward).
const TORCH_DARKNESS: float = 0.12
## How dark the world is this frame, 0 by day to about 1 at night or in a dark zone.
var darkness: float = 0.0
var _pool: Array[PointLight2D] = []
var _in_use: int = 0


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
	dark_zone = zone.get("dark", false)
	weather = Weather.local(game.world_clock(), focus)
	clear_light = Color(light.r, light.g, light.b, 1.0)
	light = light * Weather.tint(weather)
	return Color(light.r, light.g, light.b, 1.0)


func _process(_delta: float) -> void:
	var light: Color = ambient()
	modulate_node.color = light
	# Lamps follow nightfall and dark zones; clouds only add a little, so a rainy noon stays unlit.
	var night: float = 1.0 - (clear_light.r + clear_light.g + clear_light.b) / 3.0
	var gloom: float = (clear_light.r + clear_light.g + clear_light.b - light.r - light.g - light.b) / 3.0
	darkness = clampf(night + gloom * 0.25, 0.0, 1.0) / 0.55
	var game: Node = view.game
	_in_use = 0
	var area: Rect2i = view.visible_cells().grow(4)
	var time: float = Time.get_ticks_msec() / 1000.0
	if darkness > 0.01:
		# Only a held torch lights a player: without one they stand in the dark like everyone else.
		for id: int in game.actors:
			var actor: Dictionary = game.actors[id]
			if area.has_point(Vector2i(actor["visual"])) and holds_torch(actor["state"]["equipment"]):
				var flicker: float = 0.92 + 0.08 * sin(time * 8.0 + id) * sin(time * 4.7)
				_light(_centre(actor["visual"]) - Vector2(0, 10), TORCH_GLOW, TORCH_TILES * flicker, 1.2 * darkness)
		for cell: Vector2i in World.NPC_CELLS:
			if area.has_point(cell) and not World.npc(World.NPC_CELLS[cell]).get("vehicle", "") in ["waystone", "gate"]:
				_light(_centre(Vector2(cell)), LANTERN, 3.0, 0.9 * darkness)
	if darkness > TORCH_DARKNESS:
		for cell: Vector2i in World.TORCHES:
			if area.has_point(cell):
				var flicker: float = 0.9 + 0.1 * sin(time * 9.0 + cell.x * 1.7) * sin(time * 5.3 + cell.y)
				_light(SpriteArt.torch_foot(cell) - Vector2(0, 5), TORCH_GLOW, 3.2 * flicker, 1.1 * darkness)
		for cell: Vector2i in World.LAMPS:
			if area.has_point(cell):
				_light(_centre(Vector2(cell)) - Vector2(0, 30), LANTERN, 3.6, 1.0 * darkness)
	# Coloured light from relics, glowing bosses, and waystone runes, faint even by day.
	var tint: float = maxf(darkness, 0.18)
	for id: String in World.FERRYMEN:
		var stone: Dictionary = World.FERRYMEN[id]
		if stone["vehicle"] in ["waystone", "gate"] and area.has_point(stone["cell"]):
			_light(_centre(Vector2(stone["cell"])) - Vector2(0, 12), WAYSTONE_GLOW, 2.0, 0.8 * tint)
	for id: int in game.actors:
		var actor: Dictionary = game.actors[id]
		var glow: Variant = _glow_color(actor["state"]["equipment"])
		if glow != null and area.has_point(Vector2i(actor["visual"])):
			_light(_centre(actor["visual"]), glow, GLOW_TILES, 0.9 * tint)
	for id: int in game.monsters_in(area):
		var monster: Dictionary = game.monsters[id]
		var definition: Dictionary = Monsters.MONSTERS.get(monster["state"]["kind"], {})
		var glow: Variant = definition.get("glow", _glow_color(definition.get("gear", {})))
		if glow != null and area.has_point(Vector2i(monster["visual"])):
			_light(_centre(monster["visual"]), glow, GLOW_TILES * definition.get("size", 1.0), 1.0 * tint)
	for cell: Vector2i in game.ground_in(area):
		var stack: Array = game.ground_view[cell]
		if area.has_point(cell) and not stack.is_empty() and World.bound(stack.back()):
			_light(_centre(Vector2(cell)), World.ITEMS[World.kind_of(stack.back())]["glow"], 2.0, 0.8 * tint)
	# Spells light their surroundings briefly, by day too.
	for index: int in game.effects.size():
		var effect: Dictionary = game.effects[index]
		var age: float = time - effect["born"]
		if effect["kind"] == "missile" and age < 0.3:
			var at: Vector2 = effect["from"].lerp(effect["to"], clampf(age / 0.25, 0.0, 1.0))
			_light(at, effect["color"], 1.6, 1.2 * maxf(darkness, 0.35))
		elif effect["kind"] == "area" and age < 0.6:
			var cells: Array = effect["cells"]
			var centre: Vector2 = Vector2.ZERO
			for cell: Vector2i in cells:
				centre += Vector2(cell)
			centre = centre / maxf(1.0, cells.size())
			_light(_centre(centre), effect["color"], SPELL_TILES, 1.4 * (1.0 - age / 0.6) * maxf(darkness, 0.35))
	for index: int in range(_in_use, _pool.size()):
		_pool[index].visible = false


func _light(at: Vector2, color: Color, tiles: float, energy: float) -> void:
	if _in_use >= MAX_LIGHTS:
		return
	if _in_use == _pool.size():
		var created := PointLight2D.new()
		created.texture = LIGHT_TEXTURE
		created.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(created)
		_pool.append(created)
	var light: PointLight2D = _pool[_in_use]
	_in_use += 1
	light.visible = true
	light.position = at
	light.color = color
	light.energy = energy
	light.texture_scale = tiles * 2.0 * World.TILE_SIZE / LIGHT_TEXTURE.get_width()


static func _centre(cell: Vector2) -> Vector2:
	return (cell + Vector2(0.5, 0.5)) * World.TILE_SIZE


static func holds_torch(equipment: Dictionary) -> bool:
	var kind: String = String(equipment.get("off_hand", ""))
	return World.ITEMS.has(kind) and World.ITEMS[kind]["look"] == "torch"


static func _glow_color(equipment: Dictionary) -> Variant:
	for slot: String in equipment:
		var kind: String = String(equipment[slot])
		if World.ITEMS.has(kind) and World.ITEMS[kind].has("glow"):
			return World.ITEMS[kind]["glow"]
	return null
