extends PanelContainer
## The quest list in the top-left of the game window: each task you are on, its giver and town,
## and your progress (or a reminder to turn it in), then where to go next (World.next_task).
## Rebuilt only when your tasks or level change; hidden when there is nothing to show or when
## toggled off with the quest list key (Keybinds "quest_list").

const World = preload("res://game/core/world.gd")
const Quests = preload("res://game/data/quests.gd")
const Layout = preload("res://game/ui/layout.gd")
const WIDTH: float = 230.0
const TITLE: Color = Color("#ffcf6a")
const GIVER: Color = Color("#a7b0b8")
const PROGRESS: Color = Color("#e8e4da")
const DONE: Color = Color("#9fe07a")
const NEXT: Color = Color("#8fd0ff")

var game: Node
## Toggled by the quest list key; the list still hides itself when there is nothing to show.
var shown: bool = true
var _list: VBoxContainer
var _key: String = "-"


func _init() -> void:
	position = Layout.VIEW_ORIGIN + Vector2(10, 46)
	custom_minimum_size = Vector2(WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.04, 0.05, 0.06, 0.62)
	frame.border_color = Color("#3a4450")
	frame.set_border_width_all(1)
	frame.set_content_margin_all(6)
	frame.anti_aliasing = false
	add_theme_stylebox_override("panel", frame)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 0)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_list)
	visible = false


## Per frame: rebuild when your tasks or progress change.
func refresh() -> void:
	var state: Dictionary = game.actors[game.self_id]["state"] if game.actors.has(game.self_id) else {}
	var tasks: Dictionary = state.get("tasks", {})
	var next: String = World.next_task(state) if not state.is_empty() else ""
	var key: String = "%s|%s|%s" % [shown, tasks, next]
	if key == _key:
		return
	_key = key
	# Removed at once (not just queued) so the old lines do not count toward the new size.
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	visible = shown and (not tasks.is_empty() or not next.is_empty())
	if not visible:
		size = Vector2.ZERO
		return
	_line("Quests", 13, PROGRESS)
	var ids: Array = tasks.keys()
	ids.sort()
	for task: String in ids:
		if not Quests.TASKS.has(task):
			continue
		var definition: Dictionary = Quests.TASKS[task]
		var giver: Dictionary = World.QUEST_GIVERS.get(definition["giver"], {"name": "?", "place": "?"})
		var done: int = mini(int(tasks[task]), definition["count"])
		_line(definition["title"], 12, TITLE)
		_line("  %s, %s" % [giver["name"], giver["place"]], 10, GIVER)
		if done >= definition["count"]:
			_line("  Done: return to %s" % giver["name"], 11, DONE)
		elif definition["count"] == 1:
			_line("  Slay %s" % Quests.target_name(task), 11, PROGRESS)
		else:
			_line("  %d/%d %s" % [done, definition["count"], Quests.target_name(task)], 11, PROGRESS)
	if not next.is_empty():
		var giver: Dictionary = World.QUEST_GIVERS[Quests.TASKS[next]["giver"]]
		var band: Vector2i = World.task_levels(next)
		_line("Next: %s" % Quests.TASKS[next]["title"], 12, NEXT)
		_line("  %s, %s" % [giver["name"], giver["place"]], 10, GIVER)
		_line("  Monsters level %d-%d" % [band.x, band.y], 10, GIVER)
	# A container grows to fit but never shrinks on its own: fit the panel to these lines.
	reset_size()


func _line(text: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	label.custom_minimum_size = Vector2(WIDTH - 12, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_child(label)
