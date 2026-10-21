@tool
extends EditorPlugin
## Map brushes (game/maps/brushes.gd; see docs/world-editing.md). Tick "Brush on" in the Brushes
## dock and click or drag in the 2D view, with nothing selected so Godot's TileMap tools stay idle.
## Terrain modes (terrain, doodads, erase, house, castle) work in an open sector scene and paint
## its override (the root layer, which always wins; the locked Base stays the generators'). Camp
## modes work in overworld.tscn and add or remove MonsterSpawns markers. Each stroke undoes as one.

const Brushes = preload("res://game/maps/brushes.gd")
const Atlas = preload("res://game/data/atlas.gd")
const MapIO = preload("res://game/maps/map_io.gd")
const SPAWN_SCRIPT = preload("res://game/maps/markers/monster_spawn.gd")

enum Mode { TERRAIN, SCATTER, CLEAR, ERASE, HOUSE, CASTLE, CAMP, REMOVE_CAMP }
const MODES: PackedStringArray = ["Terrain", "Scatter doodads", "Clear doodads", "Erase override", "House",
	"Castle", "Monster camp", "Remove camp"]
const SIDES: Array[Vector2i] = [Vector2i.DOWN, Vector2i.UP, Vector2i.RIGHT, Vector2i.LEFT]
const SIDE_NAMES: PackedStringArray = ["South", "North", "East", "West"]
const GATES: PackedStringArray = ["Facing side", "Facing and opposite", "All four sides"]
const TILE: float = 32.0
const EMPTY: Vector3i = Vector3i(-1, -1, -1)

var _dock: VBoxContainer
var _on: CheckButton
var _mode: OptionButton
var _terrain: OptionButton
var _set: OptionButton
var _radius: SpinBox
var _density: SpinBox
var _width: SpinBox
var _height: SpinBox
var _facing: OptionButton
var _gates: OptionButton
var _monster: OptionButton
var _level: SpinBox
var _nearby: CheckBox
var _count: SpinBox
var _spread: SpinBox
## Each row's control -> the modes that show it.
var _rows: Dictionary = {}
var _monsters: Array[String] = Brushes.camp_monsters()
var _rng := RandomNumberGenerator.new()
## The stroke under way: cell -> its override tile before the stroke, and the cells a scatter or
## clear brush already rolled (one roll per cell per stroke).
var _before: Dictionary = {}
var _rolled: Dictionary = {}
var _painting: bool = false
var _hover: Vector2i = Vector2i(-1, -1)


func _enter_tree() -> void:
	_dock = VBoxContainer.new()
	_dock.name = "Brushes"
	_on = CheckButton.new()
	_on.text = "Brush on"
	_on.toggled.connect(func(_pressed: bool) -> void: update_overlays())
	_dock.add_child(_on)
	_mode = _options("Mode", MODES, [])
	_mode.item_selected.connect(func(_index: int) -> void: _show_rows())
	var terrains: PackedStringArray = []
	for letter: String in Brushes.NAMES:
		terrains.append("%s  %s" % [letter, Brushes.NAMES[letter]])
	_terrain = _options("Terrain", terrains, [Mode.TERRAIN])
	var sets: PackedStringArray = []
	for kind: String in Brushes.SCATTERS:
		sets.append(String(Brushes.SCATTERS[kind]["name"]))
	_set = _options("Doodads", sets, [Mode.SCATTER, Mode.CLEAR])
	_radius = _number("Radius", 0, 12, 1, 1, [Mode.TERRAIN, Mode.SCATTER, Mode.CLEAR, Mode.ERASE])
	_density = _number("Density", 0.05, 1.0, 0.05, 0.3, [Mode.SCATTER])
	_width = _number("Width", Brushes.HOUSE_MIN.x, Brushes.CASTLE_MAX, 1, 7, [Mode.HOUSE, Mode.CASTLE])
	_height = _number("Height", Brushes.HOUSE_MIN.y, Brushes.CASTLE_MAX, 1, 6, [Mode.HOUSE, Mode.CASTLE])
	_facing = _options("Door", SIDE_NAMES, [Mode.HOUSE, Mode.CASTLE])
	_gates = _options("Gates", GATES, [Mode.CASTLE])
	var names: PackedStringArray = []
	for id: String in _monsters:
		names.append(String(Brushes.Monsters.MONSTERS[id]["name"]))
	_monster = _options("Monster", names, [Mode.CAMP])
	_level = _number("Level", 1, 50, 1, 10, [Mode.CAMP])
	_nearby = CheckBox.new()
	_nearby.text = "Level from nearby camps"
	_nearby.button_pressed = true
	_dock.add_child(_nearby)
	_rows[_nearby] = [Mode.CAMP]
	_count = _number("Count", 1, 20, 1, 5, [Mode.CAMP])
	_spread = _number("Spread", 0, 10, 1, 2, [Mode.CAMP])
	_show_rows()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	set_input_event_forwarding_always_enabled()


func _exit_tree() -> void:
	remove_control_from_docks(_dock)
	_dock.queue_free()


func _options(label: String, items: PackedStringArray, modes: Array) -> OptionButton:
	var button := OptionButton.new()
	for item: String in items:
		button.add_item(item)
	_row(label, button, modes)
	return button


func _number(label: String, low: float, high: float, step: float, value: float, modes: Array) -> SpinBox:
	var box := SpinBox.new()
	box.min_value = low
	box.max_value = high
	box.step = step
	box.value = value
	box.value_changed.connect(func(_value: float) -> void: update_overlays())
	_row(label, box, modes)
	return box


func _row(label: String, control: Control, modes: Array) -> void:
	var row := HBoxContainer.new()
	var text := Label.new()
	text.text = label
	text.custom_minimum_size.x = 70
	row.add_child(text)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	_dock.add_child(row)
	if not modes.is_empty():
		_rows[row] = modes


func _show_rows() -> void:
	for row: Control in _rows:
		row.visible = _mode.selected in _rows[row]
	update_overlays()


func _camp_mode() -> bool:
	return _mode.selected == Mode.CAMP or _mode.selected == Mode.REMOVE_CAMP


func _stamp_mode() -> bool:
	return _mode.selected == Mode.HOUSE or _mode.selected == Mode.CASTLE


## The edited scene's root when it is a terrain sector, else null.
func _sector() -> TileMapLayer:
	var root: TileMapLayer = EditorInterface.get_edited_scene_root() as TileMapLayer
	if root == null or Brushes.sector_of(root).x < 0 or root.tile_set == null:
		return null
	return root


## The edited scene's MonsterSpawns group when it is the overworld, else null.
func _spawns() -> Node2D:
	var root: Node = EditorInterface.get_edited_scene_root()
	return root.get_node_or_null("MonsterSpawns") as Node2D if root != null else null


## The scene the active mode works in: a sector, or the overworld's camps.
func _target() -> Node2D:
	return _spawns() if _camp_mode() else _sector()


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if not _on.button_pressed:
		return false
	var target: Node2D = _target()
	if target == null:
		return false
	var mouse: Vector2 = target.get_local_mouse_position()
	var cell := Vector2i(floori(mouse.x / TILE), floori(mouse.y / TILE))
	if event is InputEventMouseMotion:
		if cell != _hover:
			_hover = cell
			update_overlays()
		if _painting and not _stamp_mode():
			_paint(target as TileMapLayer, cell)
			return true
		return false
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return false
	if _camp_mode():
		if button.pressed:
			if _mode.selected == Mode.CAMP:
				_add_camp(target, cell)
			else:
				_remove_camp(target, cell)
		return true
	var root: TileMapLayer = target as TileMapLayer
	if button.pressed:
		_painting = true
		_before = {}
		_rolled = {}
		_paint(root, cell)
		return true
	if _painting:
		_painting = false
		_commit(root)
		return true
	return false


func _paint(root: TileMapLayer, centre: Vector2i) -> void:
	var base: TileMapLayer = root.get_node_or_null(MapIO.BASE) as TileMapLayer
	var tiles: Dictionary = Brushes.tiles(root.tile_set)
	var letters: Dictionary = {}
	for letter: String in tiles:
		letters[tiles[letter]] = letter
	var rect: Rect2i = Atlas.sector_rect(Brushes.sector_of(root))
	var terrain_of: Callable = func(cell: Vector2i) -> String: return Brushes.letter_at(root, base, cell, letters)
	var kind: String = String(Brushes.SCATTERS.keys()[_set.selected])
	var side: Vector2i = SIDES[_facing.selected]
	var changes: Dictionary = {}
	match _mode.selected:
		Mode.HOUSE:
			changes = Brushes.house(centre, _size(), side)
		Mode.CASTLE:
			var gates: Array[Vector2i] = [side]
			if _gates.selected >= 1:
				gates.append(-side)
			if _gates.selected == 2:
				gates.append(Vector2i(side.y, side.x))
				gates.append(Vector2i(-side.y, -side.x))
			changes = Brushes.castle(centre, _size(), gates)
		_:
			var cells: Array[Vector2i] = []
			for cell: Vector2i in Brushes.disc(centre, int(_radius.value)):
				if rect.has_point(cell) and (_mode.selected in [Mode.TERRAIN, Mode.ERASE] or not _rolled.has(cell)):
					cells.append(cell)
					_rolled[cell] = true
			match _mode.selected:
				Mode.TERRAIN:
					changes = Brushes.fill(cells, String(Brushes.NAMES.keys()[_terrain.selected]))
				Mode.SCATTER:
					changes = Brushes.scatter(cells, kind, _density.value, terrain_of, _rng)
				Mode.CLEAR:
					changes = Brushes.clear(cells, kind, terrain_of)
				Mode.ERASE:
					for cell: Vector2i in cells:
						changes[cell] = ""
	if changes.keys().any(func(cell: Vector2i) -> bool: return not rect.has_point(cell)):
		push_warning("Brimholt brushes: the %s does not fit inside this sector (%s); open the sector it reaches into." % [MODES[_mode.selected].to_lower(), rect])
		return
	for cell: Vector2i in changes:
		if not _before.has(cell):
			_before[cell] = _tile(root, cell)
		var letter: String = changes[cell]
		_set_tile(root, cell, tiles.get(letter, EMPTY) if letter != "" else EMPTY)


func _size() -> Vector2i:
	return Vector2i(int(_width.value), int(_height.value))


func _commit(root: TileMapLayer) -> void:
	var before: Dictionary = {}
	var after: Dictionary = {}
	for cell: Vector2i in _before:
		if _tile(root, cell) != _before[cell]:
			before[cell] = _before[cell]
			after[cell] = _tile(root, cell)
	_before = {}
	if after.is_empty():
		return
	var undo: EditorUndoRedoManager = get_undo_redo()
	undo.create_action("%s (%d tiles)" % [MODES[_mode.selected], after.size()], UndoRedo.MERGE_DISABLE, root)
	undo.add_do_method(self, "_apply", root, after)
	undo.add_undo_method(self, "_apply", root, before)
	undo.commit_action(false)


func _apply(root: TileMapLayer, cells: Dictionary) -> void:
	for cell: Vector2i in cells:
		_set_tile(root, cell, cells[cell])


func _tile(root: TileMapLayer, cell: Vector2i) -> Vector3i:
	var source: int = root.get_cell_source_id(cell)
	if source == -1:
		return EMPTY
	var coords: Vector2i = root.get_cell_atlas_coords(cell)
	return Vector3i(source, coords.x, coords.y)


func _set_tile(root: TileMapLayer, cell: Vector2i, tile: Vector3i) -> void:
	if tile == EMPTY:
		root.erase_cell(cell)
	else:
		root.set_cell(cell, tile.x, Vector2i(tile.y, tile.z))


func _camps(spawns: Node2D) -> Array:
	var camps: Array = []
	for marker: Node in spawns.get_children():
		if marker is Marker2D:
			camps.append({"cell": _cell_of(marker as Marker2D), "level": int(marker.get("level")), "node": marker})
	return camps


func _cell_of(marker: Marker2D) -> Vector2i:
	return Vector2i(floori(marker.position.x / TILE), floori(marker.position.y / TILE))


func _add_camp(spawns: Node2D, cell: Vector2i) -> void:
	var monster: String = _monsters[_monster.selected]
	if _nearby.button_pressed:
		_level.value = Brushes.camp_level(cell, _camps(spawns), int(_level.value))
	var marker := Marker2D.new()
	marker.set_script(SPAWN_SCRIPT)
	marker.name = "%s_%d_%d" % [monster.to_pascal_case(), cell.x, cell.y]
	marker.position = (Vector2(cell) + Vector2(0.5, 0.5)) * TILE
	marker.set("monster", monster)
	marker.set("level", int(_level.value))
	marker.set("count", int(_count.value))
	marker.set("radius", int(_spread.value))
	var root: Node = spawns.owner if spawns.owner != null else spawns.get_parent()
	var undo: EditorUndoRedoManager = get_undo_redo()
	undo.create_action("Add %s camp (level %d)" % [monster, int(_level.value)], UndoRedo.MERGE_DISABLE, root)
	undo.add_do_method(spawns, "add_child", marker, true)
	undo.add_do_method(marker, "set_owner", root)
	undo.add_do_reference(marker)
	undo.add_undo_method(spawns, "remove_child", marker)
	undo.commit_action()


func _remove_camp(spawns: Node2D, cell: Vector2i) -> void:
	var nearest: Marker2D = null
	var best: int = 1 << 30
	for camp: Dictionary in _camps(spawns):
		var at: Vector2i = camp["cell"]
		var reach: int = maxi(absi(at.x - cell.x), absi(at.y - cell.y))
		if reach <= int(camp["node"].get("radius")) + 1 and reach < best:
			best = reach
			nearest = camp["node"]
	if nearest == null:
		return
	var root: Node = spawns.owner if spawns.owner != null else spawns.get_parent()
	var undo: EditorUndoRedoManager = get_undo_redo()
	undo.create_action("Remove camp %s" % nearest.name, UndoRedo.MERGE_DISABLE, root)
	undo.add_do_method(spawns, "remove_child", nearest)
	undo.add_undo_method(spawns, "add_child", nearest)
	undo.add_undo_method(spawns, "move_child", nearest, nearest.get_index())
	undo.add_undo_method(nearest, "set_owner", root)
	undo.add_undo_reference(nearest)
	undo.commit_action()


func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	var target: Node2D = _target()
	if target == null or not _on.button_pressed:
		return
	var xform: Transform2D = target.get_viewport_transform() * target.get_global_transform()
	var colour: Color = Color(1.0, 0.35, 0.3) if _mode.selected in [Mode.ERASE, Mode.REMOVE_CAMP] else Color(1.0, 0.9, 0.4)
	var area: Rect2i
	if _stamp_mode():
		area = Rect2i(_hover, _size())
	elif _camp_mode():
		var spread: int = int(_spread.value) if _mode.selected == Mode.CAMP else 1
		area = Rect2i(_hover - Vector2i(spread, spread), Vector2i.ONE * (spread * 2 + 1))
	else:
		for cell: Vector2i in Brushes.disc(_hover, int(_radius.value)):
			overlay.draw_rect(_screen(xform, Rect2i(cell, Vector2i.ONE)), colour, false, 1.0)
		return
	overlay.draw_rect(_screen(xform, area), colour, false, 2.0)


func _screen(xform: Transform2D, cells: Rect2i) -> Rect2:
	var corner: Vector2 = xform * (Vector2(cells.position) * TILE)
	return Rect2(corner, Vector2(cells.size) * TILE * xform.get_scale())
