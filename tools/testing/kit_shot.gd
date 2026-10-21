extends SceneTree
## Experiment capture (branch experiment/pack-paperdoll): the character bare and in one kit per worn
## family (plate, mail, leather, robe, horned plate), drawn by the game's own SpriteArt.draw_actor in
## four facings, standing and striking, scaled 3x, saved to .tools/kit_shot.png.
## godot --path . --script res://tools/testing/kit_shot.gd

const SpriteArt = preload("res://game/render/sprite_art.gd")
const KITS: Array[Dictionary] = [
	{},
	{"helmet": "iron_sallet", "armor": "iron_cuirass", "legs": "iron_legplates", "boots": "iron_sabatons",
		"main_hand": "steel_longsword", "off_hand": "steel_kite_shield"},
	{"helmet": "steel_kettle_hat", "armor": "steel_hauberk", "legs": "ringmail_chausses", "boots": "tracker_s_striders"},
	{"helmet": "wolfhide_hood", "armor": "wolfhide_coat", "legs": "wolfhide_breeches", "boots": "wolfhide_boots"},
	{"helmet": "amber_hat", "armor": "amber_robe", "legs": "apprentice_s_leggings", "boots": "amethyst_slippers"},
	{"helmet": "bronze_helm", "armor": "bronze_breastplate", "legs": "bronze_legplates", "boots": "bronze_sabatons"},
]
const POSES: Array[int] = [0, 1, 4]
const SCALE: float = 3.0
const CELL: Vector2 = Vector2(48, 52)


class Strip extends Node2D:
	func _draw() -> void:
		var columns: int = 4 * POSES.size()
		draw_rect(Rect2(Vector2.ZERO, Vector2(columns * CELL.x, KITS.size() * CELL.y)), Color("#4a5a3e"))
		for row: int in KITS.size():
			for facing: int in 4:
				for index: int in POSES.size():
					var pose: int = POSES[index]
					var center: Vector2 = Vector2((facing * POSES.size() + index + 0.5) * CELL.x, row * CELL.y + 32)
					var state: Dictionary = {"id": 1, "facing": SpriteArt.DIRECTIONS[facing], "equipment": KITS[row]}
					if pose == 4:
						state["attack"] = 0.3
					SpriteArt.draw_actor(self, center, state, false, 0.25 if pose == 1 else 0.0, Color("#5a7898"))


func _initialize() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(Vector2(4 * POSES.size() * CELL.x, KITS.size() * CELL.y) * SCALE)
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
