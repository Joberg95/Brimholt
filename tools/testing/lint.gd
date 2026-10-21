extends SceneTree
## Parses every project script (game, tests, tools) so a broken file is reported even when
## nothing loads it. project.godot promotes bug-prone warnings to errors (untyped declarations,
## unused variables and parameters, shadowing, unreachable code, narrowing conversions, ...);
## the engine prints each one. Exits 1 if any script fails.
##   godot --headless --path . --script res://tools/testing/lint.gd
func _init() -> void:
	var failed: int = 0
	var count: int = 0
	for root_dir: String in ["res://game", "res://tests", "res://tools", "res://addons/brimholt_brushes"]:
		for path: String in _scripts(root_dir):
			count += 1
			var script: GDScript = GDScript.new()
			script.source_code = FileAccess.get_file_as_string(path)
			script.resource_path = path
			if script.reload() != OK:
				failed += 1
				printerr("LINT_FAIL ", path)
	print("LINT %d scripts, %d failed" % [count, failed])
	quit(1 if failed > 0 else 0)

func _scripts(dir: String) -> Array[String]:
	var found: Array[String] = []
	for file: String in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			found.append(dir.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir):
		found.append_array(_scripts(dir.path_join(sub)))
	return found
