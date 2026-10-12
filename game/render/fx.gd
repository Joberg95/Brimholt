extends Node2D
## One-shot particle bursts in the world viewport (map pixels, under the world's lighting),
## using CC0 Kenney particle textures. Sparks, stars, and magic blend additively so they glow;
## smoke blends normally. Each burst frees itself when it finishes.

const PACK: String = "res://assets/third_party/kenney_particle_pack/"
const TEXTURES: Dictionary = {
	"spark": preload(PACK + "spark_04.png"), "star": preload(PACK + "star_06.png"), "magic": preload(PACK + "magic_03.png"),
	"smoke": preload(PACK + "smoke_04.png"), "slash": preload(PACK + "slash_02.png"), "flare": preload(PACK + "flare_01.png"),
	"circle": preload(PACK + "circle_05.png"),
}
## kind -> texture, amount, lifetime, speed range, size in map pixels, upward pull, spread, additive.
const KINDS: Dictionary = {
	"hit": {"texture": "spark", "amount": 8, "lifetime": 0.35, "speed": [40.0, 90.0], "size": 12.0, "gravity": 60.0, "spread": 180.0, "add": true},
	"critical": {"texture": "star", "amount": 14, "lifetime": 0.5, "speed": [60.0, 120.0], "size": 16.0, "gravity": 40.0, "spread": 180.0, "add": true},
	"heal": {"texture": "magic", "amount": 10, "lifetime": 0.8, "speed": [10.0, 25.0], "size": 14.0, "gravity": -60.0, "spread": 180.0, "add": true},
	"level_up": {"texture": "star", "amount": 30, "lifetime": 1.3, "speed": [20.0, 50.0], "size": 14.0, "gravity": -80.0, "spread": 40.0, "add": true},
	"death": {"texture": "smoke", "amount": 10, "lifetime": 0.9, "speed": [8.0, 24.0], "size": 30.0, "gravity": -20.0, "spread": 180.0, "add": false},
	"spell": {"texture": "magic", "amount": 6, "lifetime": 0.55, "speed": [10.0, 35.0], "size": 16.0, "gravity": -30.0, "spread": 180.0, "add": true},
	"impact": {"texture": "flare", "amount": 3, "lifetime": 0.25, "speed": [0.0, 10.0], "size": 28.0, "gravity": 0.0, "spread": 180.0, "add": true},
}

var _additive: CanvasItemMaterial


func _ready() -> void:
	_additive = CanvasItemMaterial.new()
	_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


## Emits a burst of `kind` at a map-pixel position, tinted `color`.
func burst(kind: String, at: Vector2, color: Color = Color.WHITE) -> CPUParticles2D:
	var spec: Dictionary = KINDS[kind]
	var particles := CPUParticles2D.new()
	var texture: Texture2D = TEXTURES[spec["texture"]]
	particles.texture = texture
	particles.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = spec["amount"]
	particles.lifetime = spec["lifetime"]
	particles.direction = Vector2.UP
	particles.spread = spec["spread"]
	particles.initial_velocity_min = spec["speed"][0]
	particles.initial_velocity_max = spec["speed"][1]
	particles.gravity = Vector2(0, spec["gravity"])
	var size: float = spec["size"] / texture.get_width()
	particles.scale_amount_min = size * 0.6
	particles.scale_amount_max = size
	particles.color = color
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	particles.color_ramp = fade
	particles.local_coords = false
	if spec["add"]:
		particles.material = _additive
	particles.position = at
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
	add_child(particles)
	return particles


## A burst on each cell of a spell area (at most a dozen), plus a flash at its centre.
func area(cells: Array, color: Color) -> void:
	var step: int = maxi(1, cells.size() / 12)
	var centre: Vector2 = Vector2.ZERO
	for index: int in range(0, cells.size(), step):
		var at: Vector2 = (Vector2(cells[index]) + Vector2(0.5, 0.5)) * 32.0
		burst("spell", at, color)
		centre += at
	if not cells.is_empty():
		burst("impact", centre / ceilf(cells.size() / float(step)), color)
