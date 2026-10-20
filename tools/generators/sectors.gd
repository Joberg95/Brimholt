extends SceneTree
## Writes the overworld's terrain back into sector scenes (game/maps/map_io.gd): splits an
## unsplit overworld.tscn the first time, and later moves cells painted into the wrong sector to
## their own and removes sector files left empty. The terrain itself never changes, so running
## again changes nothing.
##
##   godot --headless --path . --script res://tools/generators/sectors.gd

const MapIO = preload("res://game/maps/map_io.gd")


func _initialize() -> void:
	var scene_root: Node = MapIO.load_scene()
	var cells: int = (scene_root.get_node(MapIO.TERRAIN) as TileMapLayer).get_used_cells().size()
	var error: Error = MapIO.save_scene(scene_root)
	print("Wrote %d terrain cells in %d sectors under %s (%s)"
		% [cells, DirAccess.get_files_at(MapIO.SECTOR_DIR).size(), MapIO.SECTOR_DIR, error_string(error)])
	MapIO.free_scene(scene_root)
	quit(0 if error == OK else 1)
