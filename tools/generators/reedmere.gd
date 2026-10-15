extends "res://tools/generators/landscape.gd"
## Rebuilds Reedmere, the capital, as an open walled town: its west half (once a walled castle
## compound of roofless halls) becomes a quarter of streets around a square, with four stone
## houses small enough to take a roof (slate, game/render/roof_art.gd), and the town wall
## becomes castle wall with a new west gate on the main street beside the old south-west one;
## the north and south gates and the harbour stay. The east half (shops, bank, artisan, relic
## keepers, waystone, ferry) is left as it is. Running again changes nothing.
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


## Paints the layout and the castle wall; returns how many tiles changed, or -1 if a marker
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
