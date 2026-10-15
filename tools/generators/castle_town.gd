extends SceneTree
## Rebuilds Cinder Crossing as a walled castle town: a curtain wall of castle stone ("W") round the
## whole town from the keep (the training hall, whose outer walls become castle walls with a tower
## at each corner) to the sea, towers along it, and gatehouses (a tower either side of the road) at
## the north, east, and south gates. Houses built against the wall keep it as their back wall.
## Two houses by the north gate make room for its towers: the corner house goes and the one west of
## the road gets narrower. Only the cells listed here change, and never one under a marker, so
## running it again changes nothing.
##
##   godot --headless --path . --script res://tools/generators/castle_town.gd

## Must match World.TERRAINS (the rules check verifies it).
const TERRAINS: String = ".,~#T:=bdoODcCv^KRLWmU"
const SCENE_PATH: String = "res://game/maps/overworld.tscn"
const TILE: int = 32
## Wall runs [from, to] (inclusive, straight lines) and the gaps left open in them for the gates.
const WALLS: Array = [
	# The keep: the training hall's outer walls (its own south and east doors stay open).
	[Vector2i(0, 0), Vector2i(23, 0)], [Vector2i(0, 0), Vector2i(0, 17)], [Vector2i(0, 17), Vector2i(23, 17)],
	[Vector2i(23, 0), Vector2i(23, 17)],
	# The curtain wall: north from the keep to the corner, down the east side, along the south to the
	# sea, and from the keep's south-west corner down to the beach on the west.
	[Vector2i(24, 0), Vector2i(55, 0)], [Vector2i(55, 0), Vector2i(55, 54)], [Vector2i(19, 54), Vector2i(55, 54)],
	[Vector2i(0, 18), Vector2i(0, 26)],
]
const GATES: Array[Vector2i] = [
	Vector2i(11, 17), Vector2i(12, 17), Vector2i(23, 8), Vector2i(23, 9),
	Vector2i(48, 0), Vector2i(49, 0), Vector2i(50, 0),
	Vector2i(55, 26), Vector2i(55, 27), Vector2i(55, 28),
	Vector2i(41, 54), Vector2i(42, 54),
]
## Towers: [top-left, size] squares of castle wall (SpriteArt draws every 2x2 of it as a tower).
const TOWERS: Array = [
	# The keep's corners.
	[Vector2i(0, 0), 2], [Vector2i(22, 0), 2], [Vector2i(0, 17), 2], [Vector2i(22, 17), 2],
	# Corners of the town and the shore ends of the wall.
	[Vector2i(53, 0), 3], [Vector2i(55, 52), 3], [Vector2i(19, 53), 2], [Vector2i(0, 25), 2],
	# Gatehouses: north, east, and south.
	[Vector2i(46, 0), 2], [Vector2i(51, 0), 2], [Vector2i(55, 24), 2], [Vector2i(55, 29), 2],
	[Vector2i(39, 54), 2], [Vector2i(43, 54), 2],
	# Along the walls.
	[Vector2i(34, 0), 2], [Vector2i(55, 12), 2], [Vector2i(55, 40), 2], [Vector2i(29, 54), 2], [Vector2i(49, 54), 2],
]
## Ground repainted to make room (a space keeps the cell): the north-east corner house gives way to
## the corner and gate towers, the house west of the north gate narrows to clear its tower, and the
## south gate's road runs through.
const PATCHES: Array = [
	[Vector2i(51, 1), [
		"  ===",
		"=====",
		"=====",
		"=====",
	]],
	[Vector2i(41, 1), [
		"#####  ",
		"#===#..",
		"#===#..",
		"#===#..",
		"##=##..",
	]],
	[Vector2i(41, 54), [
		"==",
		"==",
	]],
]


func _initialize() -> void:
	var scene_root: Node = (load(SCENE_PATH) as PackedScene).instantiate()
	var changed: int = apply(scene_root)
	var error: Error = OK
	if changed >= 0:
		var packed := PackedScene.new()
		packed.pack(scene_root)
		error = ResourceSaver.save(packed, SCENE_PATH)
	print("Built Cinder Crossing's castle walls into %s: %d cells (%s)" % [SCENE_PATH, changed, error_string(error)])
	scene_root.free()
	quit(0 if error == OK and changed >= 0 else 1)


## The castle's cells: castle wall where the walls and towers stand, the patches' ground elsewhere.
static func plan() -> Dictionary:
	var cells: Dictionary = {}
	for patch: Array in PATCHES:
		for y: int in patch[1].size():
			for x: int in patch[1][y].length():
				if patch[1][y][x] != " ":
					cells[patch[0] + Vector2i(x, y)] = patch[1][y][x]
	for run: Array in WALLS:
		var step: Vector2i = (run[1] - run[0]).sign()
		var cell: Vector2i = run[0]
		while true:
			if not cell in GATES:
				cells[cell] = "W"
			if cell == run[1]:
				break
			cell += step
	for tower: Array in TOWERS:
		for y: int in tower[1]:
			for x: int in tower[1]:
				cells[tower[0] + Vector2i(x, y)] = "W"
	return cells


## Paints the castle into an overworld scene root; returns the number of changed cells, or -1
## (with an error) when a wall would cover a marker.
static func apply(scene_root: Node) -> int:
	var layer: TileMapLayer = scene_root.get_node("Terrain")
	var source: TileSetAtlasSource = layer.tile_set.get_source(0)
	for index: int in TERRAINS.length():
		if not source.has_tile(Vector2i(index, 0)):
			source.create_tile(Vector2i(index, 0))
			source.get_tile_data(Vector2i(index, 0), 0).set_custom_data("terrain", TERRAINS[index])
	var blocked: Dictionary = {}
	for group: String in ["Spawns", "Items", "Ferrymen", "QuestGivers", "DungeonEntrances", "Townsfolk"]:
		if scene_root.has_node(group):
			for marker: Node2D in scene_root.get_node(group).get_children():
				blocked[Vector2i((marker.position / TILE).floor())] = String(marker.name)
	var cells: Dictionary = plan()
	var changed: int = 0
	for cell: Vector2i in cells:
		var tile: String = cells[cell]
		if layer.get_cell_atlas_coords(cell).x == TERRAINS.find(tile):
			continue
		if tile == "W" and blocked.has(cell):
			push_error("The castle wall would cover %s at %s" % [blocked[cell], cell])
			return -1
		layer.set_cell(cell, 0, Vector2i(TERRAINS.find(tile), 0))
		changed += 1
	return changed
