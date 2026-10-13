extends ColorRect
## The game window: a clipped view whose SubViewport renders the lit world (world_view.gd),
## covered by rain (rain_layer.gd), the vignette, and the unlit overlay. With 3D on (set_3d),
## a second viewport renders game/render3d/world_3d.gd with its overlay instead; the 2D world
## is hidden but kept. Clicks, drags, and drops on it go to the main node's map handlers.

const WorldView = preload("res://game/render/world_view.gd")
const WorldOverlay = preload("res://game/render/world_overlay.gd")
const RainLayer = preload("res://game/render/rain_layer.gd")
const Layout = preload("res://game/ui/layout.gd")
## Darkens only the outer edge of the game window.
const VIGNETTE: Shader = preload("res://game/render/vignette.gdshader")
const WorldView3D = preload("res://game/render3d/world_3d.gd")
const Overlay3D = preload("res://game/render3d/overlay_3d.gd")

var world_view: Node2D
## The world renders into its own viewport so ambient light and lights never touch the UI.
var world_viewport: SubViewport
var world_overlay: Node2D
var rain: ColorRect
## The 3D renderer, built the first time 3D is switched on.
var world_3d: Node3D
var _container_2d: SubViewportContainer
var _container_3d: SubViewportContainer
var _overlay_3d: Control
var _game: Node


func setup(game: Node) -> void:
	color = Color("#07090c")
	position = Layout.VIEW_ORIGIN
	size = Layout.VIEW_SIZE
	clip_contents = true
	set_drag_forwarding(Callable(game, "_map_drag"), Callable(game, "_map_can_drop"), Callable(game, "_map_drop"))
	gui_input.connect(Callable(game, "_map_input"))
	_game = game
	var container := SubViewportContainer.new()
	_container_2d = container
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


## Shows the 3D world (building it on first use) or the 2D one.
func set_3d(enabled: bool) -> void:
	if enabled and world_3d == null:
		_container_3d = SubViewportContainer.new()
		_container_3d.size = Layout.VIEW_SIZE
		_container_3d.stretch = true
		_container_3d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_container_3d)
		move_child(_container_3d, _container_2d.get_index() + 1)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(Layout.VIEW_SIZE)
		viewport.own_world_3d = true
		viewport.msaa_3d = Viewport.MSAA_2X
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_container_3d.add_child(viewport)
		world_3d = WorldView3D.new()
		world_3d.game = _game
		viewport.add_child(world_3d)
		_overlay_3d = Overlay3D.new()
		_overlay_3d.game = _game
		_overlay_3d.world = world_3d
		_overlay_3d.size = Layout.VIEW_SIZE
		_overlay_3d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_overlay_3d)
	_container_2d.visible = not enabled
	world_view.visible = not enabled
	world_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if enabled else SubViewport.UPDATE_ALWAYS
	world_overlay.visible = not enabled
	rain.visible = not enabled
	if world_3d != null:
		_container_3d.visible = enabled
		_overlay_3d.visible = enabled
		world_3d.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
		_overlay_3d.process_mode = world_3d.process_mode
		(_container_3d.get_child(0) as SubViewport).render_target_update_mode = \
			SubViewport.UPDATE_ALWAYS if enabled else SubViewport.UPDATE_DISABLED
