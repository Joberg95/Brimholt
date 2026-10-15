extends "res://tools/generators/landscape.gd"
## Rebuilds Reedmere, the capital, as an open walled town: its west half (once a walled castle
## compound of roofless halls) becomes a quarter of streets around a square, with four stone
## houses small enough to take a roof (slate, game/render/roof_art.gd), and the town wall
## becomes castle wall with a new west gate on the main street beside the old south-west one;
## the north and south gates and the harbour stay. The east half (shops, bank, artisan, relic
## keepers, waystone, ferry) keeps its buildings, but loses the trees that crowded them, and the
## waystone gets an open square (EAST, WAYSTONE_SQUARE). Running again changes nothing.
##
##   godot --headless --path . --script res://tools/generators/reedmere.gd

## Top-left cell of LAYOUT; a space keeps the cell as it is.
const ORIGIN: Vector2i = Vector2i(105, 180)
const LAYOUT: Array[String] = [
	"...WWWWWWWWWWWWWWWWWWWWWWWWW",
	"...W.######.T..T...######.T.",
	"...W.#====#........#====#...",
	"...W.#====#........#====#...",
	"...W.#====#........#====#...",
	"...W.#====#........#====#...",
	"...W.##=###........##=###...",
	"...W...=..........T..=......",
	"...W========================",
	"...W.T......=========.....T.",
	"...W........=========.......",
	"...W..T.....=========....T..",
	"...W........=========.......",
	"============================",
	"============================",
	"============================",
	"...W........=========.......",
	"...W..T.....=========....T..",
	"...W........=========.......",
	"...W========================",
	"...W=..=.............=......",
	"...W=##=###...T....##=###...",
	"...W=#====#........#====#...",
	"...W=#====#........#====#...",
	".====#====#........#====#...",
	".====#====#........#====#...",
	".====######........######...",
	"...WWWWWWWWWWWWWWWWWWWWWWWWW",
]
## The rest of the town wall (rows and column ranges, inclusive) turns from house wall to castle wall.
const WALL_RUNS: Array = [[180, 105 + 28, 105 + 51], [207, 105 + 28, 105 + 52]]
## The east quarter, beside LAYOUT: its trees are cleared (they crowded the houses, the relic
## keepers' square, and the bank), and WAYSTONE_SQUARE, once a doorless pair of walls boxing in
## the waystone beside the bank, is opened up into the street.
const EAST: Rect2i = Rect2i(133, 181, 25, 26)
const WAYSTONE_SQUARE: Array[Vector2i] = [Vector2i(143, 197), Vector2i(143, 198), Vector2i(143, 199),
	Vector2i(143, 200), Vector2i(143, 201)]
## The waystone stands in the middle of that square, clear of the bank's leaning wall and roof.
const WAYSTONE: String = "reedmere_coach"
const WAYSTONE_CELL: Vector2i = Vector2i(145, 199)


func _initialize() -> void:
	var scene_root: Node = (load(SCENE_PATH) as PackedScene).instantiate()
	var changed: int = rebuild(scene_root)
	var error: Error = OK
	if changed > 0:
		var packed := PackedScene.new()
		packed.pack(scene_root)
		error = ResourceSaver.save(packed, SCENE_PATH)
	print("Rebuilt Reedmere: %d tiles changed in %s (%s)" % [changed, SCENE_PATH, error_string(error)])
	scene_root.free()
	quit(0 if error == OK and changed >= 0 else 1)


## Paints the layout, the castle wall, and the east quarter's fixes; returns how many tiles changed, or -1 if a marker
## would end up inside a wall or tree.
static func rebuild(scene_root: Node) -> int:
	var layer: TileMapLayer = scene_root.get_node("Terrain")
	var blocked: Dictionary = {}
	for group: String in MARKER_GROUPS:
		if scene_root.has_node(group):
			for marker: Node2D in scene_root.get_node(group).get_children():
				blocked[_cell_of(marker)] = String(marker.name)
	var changed: int = 0
	var wanted: Dictionary = {}
	for y: int in LAYOUT.size():
		for x: int in LAYOUT[y].length():
			if LAYOUT[y][x] != " ":
				wanted[ORIGIN + Vector2i(x, y)] = LAYOUT[y][x]
	for run: Array in WALL_RUNS:
		for x: int in range(run[1], run[2] + 1):
			var cell := Vector2i(x, run[0])
			if _terrain_of(layer, cell) == "#":
				wanted[cell] = "W"
	for y: int in range(EAST.position.y, EAST.end.y):
		for x: int in range(EAST.position.x, EAST.end.x):
			if _terrain_of(layer, Vector2i(x, y)) == "T":
				wanted[Vector2i(x, y)] = "."
	for cell: Vector2i in WAYSTONE_SQUARE:
		wanted[cell] = "="
	var stone: Node2D = scene_root.get_node_or_null("Ferrymen/" + WAYSTONE)
	if stone != null and _cell_of(stone) != WAYSTONE_CELL:
		blocked.erase(_cell_of(stone))
		stone.position = (Vector2(WAYSTONE_CELL) + Vector2(0.5, 0.5)) * TILE
		blocked[WAYSTONE_CELL] = WAYSTONE
		changed += 1
	for cell: Vector2i in wanted:
		var tile: String = wanted[cell]
		if _terrain_of(layer, cell) == tile:
			continue
		if tile in "#WT" and blocked.has(cell):
			push_error("Reedmere would wall in %s at %s" % [blocked[cell], cell])
			return -1
		layer.set_cell(cell, 0, Vector2i(TERRAINS.find(tile), 0))
		changed += 1
	return changed


static func _terrain_of(layer: TileMapLayer, cell: Vector2i) -> String:
	var index: int = layer.get_cell_atlas_coords(cell).x
	return TERRAINS[index] if index >= 0 and index < TERRAINS.length() else ""
