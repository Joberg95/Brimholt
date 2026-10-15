extends RefCounted
## Instanced dungeons. Each dungeon has a stairway down (terrain "v"), in a town or (with an
## "entrance" cell, the default for its DungeonEntrances marker) in the wilds, and several
## identical copies painted in a band right of the overworld (BAND_X onward, never reachable
## on foot). Stepping on the stairway puts you, and later your party, in a copy of your own:
## the first free copy is claimed by your party (its leader, or you when alone), its monsters
## spawn, and it resets (monsters and items gone, free again) RESET_SECONDS after the last
## player leaves. Stepping on the stairs up ("^") leads back to town. Monsters only run while
## players are inside, so dungeons cost the host nothing when empty.
##
## Layout legend: "#" wall, "." floor, "^" stairs up, "@" arrival, a prop from PROPS (a barrel or
## crate on the floor, blocking like furniture), anything else a monster from "monsters"
## (symbol -> [id, level]); "boss" names the symbol of the dungeon's boss. A "dark" dungeon is
## pitch black: only a held torch lights it. "theme" "cellar" draws its walls in red-brown brick
## over a dark brick floor (SpriteArt). Caves are grown by tools/generators/cave_layouts.py.

## Prop symbols in layouts -> furniture kinds (SpriteArt.FURNITURE).
const PROPS: Dictionary = {"B": "barrel", "X": "crate"}

## First column of the dungeon band; the overworld is everything left of BAND_X - COPY_GAP.
const BAND_X: int = 388
## Column the band stops before; the Void Throne arena (tools/generators/void_throne.gd) lies past
## it, and repainting the band (tools/generators/dungeons.gd) clears only up to here.
const BAND_END: int = 580
const COPY_GAP: int = 4
const RESET_SECONDS: float = 60.0
## Band columns, left to right.
const ORDER: Array[String] = ["cinder_cellar", "ashford_crypt", "highmoor_mine", "silkhollow"]
const DUNGEONS: Dictionary = {
	"cinder_cellar": {
		"name": "Cinder cellar", "town": "Cinder Crossing", "copies": 6, "floor": "=", "wall": "#", "theme": "cellar",
		"ambient": Color(0.46, 0.4, 0.36), "min_level": 3, "max_level": 9, "boss": "K",
		"monsters": {"r": ["sewer_rat", 3], "g": ["giant_rat", 6], "K": ["rat_king", 9]},
		"rows": [
			"################################",
			"#^@.....#B........B#..........X#",
			"#.......#..r....r..#.g.g....g..#",
			"#...r...#..........#...........#",
			"#.......####..######.....g.....#",
			"#..............r..............X#",
			"#####..##############..#########",
			"#.........r.B#......B#.........#",
			"#...r...g....#...g...#....g.r..#",
			"#.....r......#.......#.........#",
			"######..######...##..#####..####",
			"#B....g....r.....##...........X#",
			"#...g...........g..r.......g...#",
			"#.......########......######...#",
			"#.......#......#..r...#....#...#",
			"#.r.r...#..............g...#...#",
			"#.......#.....X#......#....#...#",
			"#.......####..##########..##...#",
			"#B............................B#",
			"######..########..##########..##",
			"#.........B#..............#B...#",
			"#...g......#...r..K.......#....#",
			"#B.........................g...#",
			"################################",
		],
	},
	"ashford_crypt": {
		"name": "Ashford crypt", "town": "Ashford", "copies": 4, "floor": "c", "wall": "#",
		"ambient": Color(0.36, 0.38, 0.48), "min_level": 19, "max_level": 25, "boss": "A",
		"monsters": {"s": ["crypt_skeleton", 19], "h": ["grave_ghoul", 22], "A": ["abbot_morrow", 25]},
		"rows": [
			"##################################",
			"#^@....#............#............#",
			"#......#...s....s.s.#....s...s...#",
			"#......#............#..........s.#",
			"#..s...######..######..s.........#",
			"#..........................h.....#",
			"####..########....######..########",
			"#........#..........#............#",
			"#...h.s..#...s..s...#....h.......#",
			"#........#.s......s.#............#",
			"#####..###...####...######..######",
			"#.....h......####................#",
			"#...s........####....s....s..s...#",
			"#....h.......####................#",
			"######..##########..############.#",
			"#................................#",
			"#..s...######..######..######....#",
			"#......#....#..#....#..#....#..h.#",
			"#......#....#..#....#..#....#....#",
			"#.........h....................s.#",
			"#####..##################..#######",
			"#..............#.................#",
			"#...h.h........#.s.....A....h....#",
			"#................................#",
			"##################################",
		],
	},
	"highmoor_mine": {
		"name": "Highmoor deep mine", "town": "Highmoor", "copies": 4, "floor": "c", "wall": "L",
		"ambient": Color(0.5, 0.38, 0.3), "min_level": 33, "max_level": 40, "boss": "F",
		"monsters": {"c": ["cave_crawler", 33], "e": ["ember_golem", 36], "F": ["forgemaw", 40]},
		"rows": [
			"############################################################",
			"#############################################....###########",
			"#..........#############........###########.........########",
			"#^@.........###########..........#########.......e..########",
			"#.............########.......c....########...........#######",
			"#......c.......########...c..............#...e........######",
			"##...............######...............c...........c...######",
			"####..e...........####.......#..#.............c........#####",
			"#####...e...................####..........c.e..............#",
			"#####.....e..............e...###.c..............#....e.....#",
			"######...........e.#.........###....c.........##...........#",
			"#######............#.........###...........######..........#",
			"########............#........####...e.....#######.........##",
			"#########....e.............c.#####.......######....#.....###",
			"###########..................######...########..........####",
			"##########...........#.......####.......####...........#####",
			"##########...e...c........#..............#....c......#######",
			"#########..........c.............................c....######",
			"#########........c..........................e..c......######",
			"##########...........................................#######",
			"###########..................................c.......#######",
			"#############....#...........c.........c............########",
			"####################....e...........................########",
			"###################............###........###......#.#######",
			"##################............#####.......###...........####",
			"###############........##....#########....###............###",
			"##############.......c.......#########....####............##",
			"#############...............####....#..c..#####...........##",
			"#############.c........##...##...........######........F..##",
			"###########......................e.......#######..e.......##",
			"#######.#................................#######..........##",
			"######.......e.c.........................########..c.....###",
			"#####...................................##########......####",
			"#####....................c......e...#..#####################",
			"#####..c......######...............#########################",
			"######.......########............###########################",
			"#########...##########.........#############################",
			"############################################################",
		],
	},
	# A lightless spider cave in the wilds: "dark" leaves it pitch black, so
	# players carry a torch (a vendor off-hand item) instead of a shield or book.
	"silkhollow": {
		"name": "Silkhollow", "town": "Thornfield Wilds", "copies": 4, "floor": "c", "wall": "L",
		"ambient": Color(0.05, 0.05, 0.07), "dark": true, "entrance": Vector2i(84, 163), "min_level": 15, "max_level": 20, "boss": "M",
		"monsters": {"s": ["cave_spider", 16], "S": ["cave_spider", 18], "w": ["venom_weaver", 17],
			"M": ["silk_matron", 20]},
		"rows": [
			"################################################",
			"##################.....#############......######",
			"#################.......###########........#####",
			"################..S......#########.........#####",
			"################.........#########.........#####",
			"################.........#########...s.....#####",
			"######...########........########.........######",
			"#####.......####...........#####..S......#######",
			"####.^@.....####..###..w....####........########",
			"####..............####......###.......#.########",
			"####..............#####.................########",
			"####.............#####........w.........########",
			"####......#.....#####..s.S..................####",
			"####.....###...#####.........s...............###",
			"#.........#....##..............#....#.w.......##",
			"#.............................######..........##",
			"#............................#######..........##",
			"#...........S................#..#####..S..w...##",
			"#................s......#.........####........##",
			"#.......w...............#...s......###.......###",
			"#...S.....s...s................S...####.....####",
			"##..................###......w.....####...######",
			"#####.........s.....###.S............##....#####",
			"#######..........S..........................####",
			"########....................................####",
			"#############................####........M..####",
			"##############......S.....s.######..........####",
			"###############..............#####..........####",
			"###############................###.....#..######",
			"###############..........s...........###########",
			"################....................############",
			"################################################",
		],
	},
}


static func size(id: String) -> Vector2i:
	var layout: Array = DUNGEONS[id]["rows"]
	return Vector2i(String(layout[0]).length(), layout.size())


## Top-left tile of a copy in the band.
static func origin(id: String, copy: int) -> Vector2i:
	var x: int = BAND_X
	for other: String in ORDER:
		if other == id:
			break
		x += size(other).x + COPY_GAP
	return Vector2i(x, COPY_GAP + copy * (size(id).y + COPY_GAP))


static func rect(id: String, copy: int) -> Rect2i:
	return Rect2i(origin(id, copy), size(id))


static func symbol(id: String, local: Vector2i) -> String:
	return String(DUNGEONS[id]["rows"][local.y])[local.x]


## The map terrain of a layout cell.
static func terrain(id: String, local: Vector2i) -> String:
	var mark: String = symbol(id, local)
	if mark == "#":
		return DUNGEONS[id]["wall"]
	return "^" if mark == "^" else DUNGEONS[id]["floor"]


## Layout cells (relative to the copy origin) holding one of `symbols`.
static func cells(id: String, symbols: String) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	var layout: Array = DUNGEONS[id]["rows"]
	for y: int in layout.size():
		for x: int in String(layout[y]).length():
			if String(layout[y])[x] in symbols:
				found.append(Vector2i(x, y))
	return found


## Props of a layout: [local cell, furniture kind].
static func props(id: String) -> Array:
	var result: Array = []
	for cell: Vector2i in cells(id, "".join(PROPS.keys())):
		result.append([cell, PROPS[symbol(id, cell)]])
	return result


## The theme of the dungeon a map cell lies in ("" outside dungeons or for plain ones).
static func theme_at(id: String) -> String:
	return String(DUNGEONS.get(id, {}).get("theme", ""))


## Monster placements of a layout: [local cell, monster id, level].
static func spawns(id: String) -> Array:
	var result: Array = []
	var legend: Dictionary = DUNGEONS[id]["monsters"]
	for cell: Vector2i in cells(id, "".join(legend.keys())):
		var entry: Array = legend[symbol(id, cell)]
		result.append([cell, entry[0], entry[1]])
	return result
