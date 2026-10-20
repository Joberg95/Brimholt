extends SceneTree
## Writes the baked map (game/maps/map_io.gd BAKE_PATH) from overworld.tscn and its sectors: what
## the game loads instead of instancing the scene. Every generator that saves the map bakes it
## too; run this after painting in Godot (the rules check fails while the bake is stale).
##
##   godot --headless --path . --script res://tools/generators/bake_map.gd

const MapIO = preload("res://game/maps/map_io.gd")


func _initialize() -> void:
	var error: Error = MapIO.write_bake()
	print("Baked the map into %s (%s)" % [MapIO.BAKE_PATH, error_string(error)])
	quit(0 if error == OK else 1)
