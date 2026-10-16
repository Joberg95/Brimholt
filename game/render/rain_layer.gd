extends ColorRect
## Draws rain, or snow over the frost isles (rain.gdshader), over the game window, between the
## lit world and the unlit names and bars. The weather comes from the world view's lighting (weather.gd), so rain,
## dimming, and lightning always agree; the layer hides itself when no rain falls here.

const RAIN: Shader = preload("res://game/render/rain.gdshader")
const Layout = preload("res://game/ui/layout.gd")

var world_view: Node2D
## Off when the player turns weather effects off in the game menu.
var enabled: bool = true


func _ready() -> void:
	size = Layout.VIEW_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = ShaderMaterial.new()
	material.shader = RAIN
	material.set_shader_parameter("view_pixels", Layout.VIEW_SIZE / Layout.ZOOM)


func _process(_delta: float) -> void:
	var weather: Dictionary = world_view.lighting.weather
	visible = enabled and weather.get("rain", 0.0) > 0.01
	if not visible:
		return
	var light: Color = world_view.lighting.modulate_node.color
	material.set_shader_parameter("rain", weather["rain"])
	material.set_shader_parameter("storm", weather["storm"])
	material.set_shader_parameter("snow", 1.0 if weather.get("snow", false) else 0.0)
	material.set_shader_parameter("light", Vector3(light.r, light.g, light.b).clampf(0.25, 1.2))
	material.set_shader_parameter("camera", -world_view.position / Layout.ZOOM)
