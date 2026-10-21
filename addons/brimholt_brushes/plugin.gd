@tool
extends EditorPlugin
## Map brushes for sector scenes (game/maps/brushes.gd; see docs/world-editing.md). Open a
## sector, tick "Brush on" in the Brushes dock, and drag in the 2D view: strokes go into the
## sector's override (its root layer, which always wins) and undo as one action, while the locked
## Base stays the generators'. Nothing needs to be selected, so Godot's TileMap tools stay idle.

const Brushes = preload("res://game/maps/brushes.gd")
const Atlas = preload("res://game/data/atlas.gd")
const MapIO = preload("res://game/maps/map_io.gd")

const MODES: PackedStringArray = ["Terrain", "Scatter doodads", "Clear doodads", "Erase override"]
enum Mode { TERRAIN, SCATTER, CLEAR, ERASE }
const EMPTY: Vector3i = Vector3i(-1, -1, -1)

var _dock: VBoxContainer
var _on: CheckButton
var _mode: OptionButton
var _terrain: OptionButton
var _set: OptionButton
var _radius: SpinBox
var _density: SpinBox
var _rng := RandomNumberGenerator.new()
## The stroke under way: cell -> its override tile before the stroke, and the cells a scatter
## or clear brush already rolled (one roll per cell per stroke).
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
	_mode = _options("Mode", MODES)
	var terrains: PackedStringArray = []
	for letter: String in Brushes.NAMES:
		terrains.append("%s  %s" % [letter, Brushes.NAMES[letter]])
	_terrain = _options("Terrain", terrains)
	var sets: PackedStringArray = []
	for kind: String in Brushes.SCATTERS:
		sets.append(String(Brushes.SCATTERS[kind]["name"]))
	_set = _options("Doodads", sets)
	_radius = _number("Radius", 0, 12, 1, 1)
	_density = _number("Density", 0.05, 1.0, 0.05, 0.3)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	set_input_event_forwarding_always_enabled()


func _exit_tree() -> void:
	remove_control_from_docks(_dock)
	_dock.queue_free()


func _options(label: String, items: PackedStringArray) -> OptionButton:
	var button := OptionButton.new()
	for item: String in items:
		button.add_item(item)
	_row(label, button)
	return button


func _number(label: String, low: float, high: float, step: float, value: float) -> SpinBox:
	var box := SpinBox.new()
	box.min_value = low
	box.max_value = high
	box.step = step
	box.value = value
	box.value_changed.connect(func(_value: float) -> void: update_overlays())
	_row(label, box)
	return box


func _row(label: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var text := Label.new()
	text.text = label
	text.custom_minimum_size.x = 70
	row.add_child(text)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	_dock.add_child(row)


## The edited scene's root when it is a terrain sector, else null.
func _sector() -> TileMapLayer:
	var root: TileMapLayer = EditorInterface.get_edited_scene_root() as TileMapLayer
	if root == null or Brushes.sector_of(root).x < 0 or root.tile_set == null:
		return null
	return root


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if not _on.button_pressed:
		return false
	var root: TileMapLayer = _sector()
	if root == null:
		return false
	var cell: Vector2i = root.local_to_map(root.get_local_mouse_position())
	if event is InputEventMouseMotion:
		if cell != _hover:
			_hover = cell
			update_overlays()
		if _painting:
			_paint(root, cell)
			return true
		return false
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return false
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
	var cells: Array[Vector2i] = []
	for cell: Vector2i in Brushes.disc(centre, int(_radius.value)):
		if rect.has_point(cell) and (_mode.selected == Mode.TERRAIN or _mode.selected == Mode.ERASE or not _rolled.has(cell)):
			cells.append(cell)
			_rolled[cell] = true
	var terrain_of: Callable = func(cell: Vector2i) -> String: return Brushes.letter_at(root, base, cell, letters)
	var kind: String = String(Brushes.SCATTERS.keys()[_set.selected])
	var changes: Dictionary = {}
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
	for cell: Vector2i in changes:
		if not _before.has(cell):
			_before[cell] = _tile(root, cell)
		var letter: String = changes[cell]
		_set_tile(root, cell, tiles.get(letter, EMPTY) if letter != "" else EMPTY)


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
	undo.create_action("Brush stroke (%d tiles)" % after.size(), UndoRedo.MERGE_DISABLE, root)
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


func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	var root: TileMapLayer = _sector()
	if root == null or not _on.button_pressed:
		return
	var xform: Transform2D = root.get_viewport_transform() * root.get_global_transform()
	var size: float = float(root.tile_set.tile_size.x) * xform.get_scale().x
	var colour: Color = Color(1.0, 0.35, 0.3) if _mode.selected == Mode.ERASE else Color(1.0, 0.9, 0.4)
	for cell: Vector2i in Brushes.disc(_hover, int(_radius.value)):
		var corner: Vector2 = xform * root.map_to_local(cell) - Vector2(size, size) * 0.5
		overlay.draw_rect(Rect2(corner, Vector2(size, size)), colour, false, 1.0)
