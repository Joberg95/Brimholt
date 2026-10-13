extends SceneTree
## Saves the player bots' behavior tree (game/core/ai/bot_tree.gd) to game/data/bot_behavior.tres,
## which the game loads and the LimboAI editor edits (open it in the editor's LimboAI tab).
##
##   godot --headless --path . --script res://tools/generators/bot_tree.gd
##
## Rerunning it replaces edits made in the editor with the builder's tree.

const BotTree = preload("res://game/core/ai/bot_tree.gd")


func _initialize() -> void:
	var error: Error = ResourceSaver.save(BotTree.build(), BotTree.PATH)
	print("Saved the bot behavior tree to %s (%s)" % [BotTree.PATH, error_string(error)])
	quit(0 if error == OK else 1)
