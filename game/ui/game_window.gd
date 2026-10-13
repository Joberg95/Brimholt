extends ColorRect
## The game window: a clipped view whose SubViewport renders the lit world (world_view.gd),
## covered by rain (rain_layer.gd), the vignette, and the unlit overlay. Clicks, drags, and drops on it go to the
## main node's map handlers.

const WorldView = preload("res://game/render/world_view.gd")
const WorldOverlay = preload("res://game/render/world_overlay.gd")
const RainLayer = preload("res://game/render/rain_layer.gd")
const Layout = preload("res://game/ui/layout.gd")
## Darkens only the outer edge of the game window.
const VIGNETTE: Shader = preload("res://game/render/vignette.gdshader")

var world_view: Node2D
## The world renders into its own viewport so ambient light and lights never touch the UI.
var world_viewport: SubViewport
var world_overlay: Node2D
var rain: ColorRect


func setup(game: Node) -> void:
	color = Color("#07090c")
	position = Layout.VIEW_ORIGIN
	size = Layout.VIEW_SIZE
	clip_contents = true
	set_drag_forwarding(Callable(game, "_map_drag"), Callable(game, "_map_can_drop"), Callable(game, "_map_drop"))
	gui_input.connect(Callable(game, "_map_input"))
	var container := SubViewportContainer.new()
	container.size = Layout.VIEW_SIZE
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	world_viewport = SubViewport.new()
	world_viewport.size = Vector2i(Layout.VIEW_SIZE)
	world_viewport.transparent_bg = true
	world_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	world_viewport.snap_2d_transforms_to_pixel = true
	world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(world_viewport)
	world_view = WorldView.new()
	world_view.game = game
	world_view.scale = Vector2.ONE * Layout.ZOOM
	world_viewport.add_child(world_view)
	rain = RainLayer.new()
	rain.world_view = world_view
	add_child(rain)
	var vignette := ColorRect.new()
	vignette.size = Layout.VIEW_SIZE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.material = ShaderMaterial.new()
	vignette.material.shader = VIGNETTE
	add_child(vignette)
	world_overlay = WorldOverlay.new()
	world_overlay.game = game
	world_overlay.view = world_view
	add_child(world_overlay)
