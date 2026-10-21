extends SceneTree
## Experiment capture (branch experiment/pack-paperdoll): the character bare and in the OpenTibia
## pack knight kit, drawn by the game's own SpriteArt.draw_actor in four facings and five poses,
## scaled 3x, saved to .tools/kit_shot.png.
## godot --path . --script res://tools/testing/kit_shot.gd

const SpriteArt = preload("res://game/render/sprite_art.gd")
const KIT: Dictionary = {"helmet": "iron_sallet", "armor": "iron_cuirass", "legs": "iron_legplates",
	"boots": "iron_sabatons", "main_hand": "steel_longsword", "off_hand": "steel_kite_shield"}
const SCALE: float = 3.0
const CELL: Vector2 = Vector2(64, 56)


class Strip extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(20 * CELL.x, 2 * CELL.y)), Color("#4a5a3e"))
		for row: int in 2:
			var equipment: Dictionary = {} if row == 0 else KIT
			for facing: int in 4:
				for pose: int in 5:
					var center: Vector2 = Vector2((facing * 5 + pose + 0.5) * CELL.x, row * CELL.y + 36)
					var state: Dictionary = {"id": 1, "facing": SpriteArt.DIRECTIONS[facing], "equipment": equipment}
					var stride: float = [0.0, 0.25, 0.75, 0.0, 0.0][pose]
					if pose >= 3:
						state["attack"] = [0.0, 0.0, 0.0, 0.05, 0.3][pose]
					SpriteArt.draw_actor(self, center, state, false, stride, Color("#5a7898"))


func _initialize() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(Vector2(20 * CELL.x, 2 * CELL.y) * SCALE)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var strip := Strip.new()
	strip.scale = Vector2.ONE * SCALE
	strip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(strip)
	root.add_child(viewport)
	for frame: int in 4:
		await process_frame
	var image: Image = viewport.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.tools"))
	image.save_png("res://.tools/kit_shot.png")
	print("wrote .tools/kit_shot.png")
	quit()
