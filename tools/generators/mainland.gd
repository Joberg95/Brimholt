extends "res://tools/generators/islands.gd"
## Grows the mainland from 384 x 384 to 640 x 640 (docs/plan/43-mainland-growth.md): new land east
## and south of the old heartland for levels 1-30, so the starting hunts are less crowded. A ragged
## coast with beaches (a bay south of Lastlight keeps its harbour on open sea), eight new regions
## whose woods, lakes, bogs, and rock follow their character, a broken ridge of hills along the old
## edge, the walled town of Brackenford at the elbow with a coach station, dirt roads from its gates
## up to Highmoor's roads, over to Lastlight's, and down to the shores, and hunting camps of today's
## level 1-30 monsters whose levels rise with the distance from Brackenford.
##
## Built on the island painter (tools/generators/islands.gd: coast distances, houses, roads,
## trails into walled-in clearings). Runs once (scene metadata mainland_grown); afterwards the
## scene is the source of truth. Then run make towns town-paths cobble-towns world-map.
##
##   godot --headless --path . --script res://tools/generators/mainland.gd

## The old heartland, which this pass never repaints (roads aside), and the grown mainland.
const OLD: Rect2i = Rect2i(0, 0, 384, 384)
const GROWN: Rect2i = Rect2i(0, 0, 640, 640)
const SALT: int = 5200
const TOWN_NAME: String = "Brackenford"
## The town's curtain walls (41 x 33: streets three wide cross at its centre).
const TOWN_RECT: Rect2i = Rect2i(494, 494, 41, 33)
## Levels rise from 1 here to MAX_LEVEL at the far ends of the new land (_level).
const CENTRE: Vector2i = Vector2i(514, 510)
const MAX_LEVEL: int = 30
const LEVEL_SPAN: float = 560.0
## The new regions (game/data/regions.gd has the same anchors): name, anchor, and the ground's
## character: wood (lower is more forest), lake and rock (lower is more). Bog stays Mirewood Fen's
## own (Biomes.SWAMP_REGION).
const AREAS: Array = [
	["Bracken Leas", Vector2i(560, 560), 0.62, 0.8, 0.86],
	["Hazel Downs", Vector2i(560, 420), 0.56, 0.78, 0.8],
	["Wolfholt", Vector2i(530, 300), 0.4, 0.8, 0.82],
	["Kestrel Heights", Vector2i(520, 180), 0.55, 0.82, 0.64],
	["Greycrag Peaks", Vector2i(520, 60), 0.62, 0.86, 0.5],
	["Fernmere", Vector2i(330, 560), 0.55, 0.54, 0.86],
	["Barrowmoor", Vector2i(200, 540), 0.58, 0.8, 0.68],
	["Saltreed Marsh", Vector2i(90, 470), 0.6, 0.58, 0.86],
]
## Camp monsters: id, the level band its heartland camps already have (so its tasks' bands,
## World.task_levels, stay as they are), and the ground it favours ("open", "wood", "wet", "rock").
const MONSTERS: Array = [
	["field_vole", 1, 1, "open"], ["marsh_toad", 3, 4, "wet"], ["thornback_boar", 5, 7, "wood"],
	["road_bandit", 8, 10, "open"], ["grey_wolf", 11, 14, "wood"], ["bog_lurker", 15, 18, "wet"],
	["outlaw_archer", 19, 23, "open"], ["dire_bear", 20, 22, "wood"], ["lizard_warrior", 21, 24, "wet"],
	["lizard_shaman", 23, 25, "wet"], ["harpy", 24, 27, "rock"], ["stone_golem", 24, 28, "rock"],
	["stone_troll", 25, 28, "rock"], ["cyclops", 29, 30, "rock"],
]
## Brackenford's coach fares to the other coach stations.
const COACHES: Dictionary = {"cinder_coach": 35, "ashford": 30, "highmoor": 25, "emberfall": 25, "dunmere": 25,
	"reedmere_coach": 30}
## Roads: waypoints from a gate (snapped to open ground), ending on an old road near the last point
## when it lies in the heartland.
const ROADS: Array = [
	[Vector2i(514, 492), Vector2i(520, 300), Vector2i(515, 150), Vector2i(356, 90)],
	[Vector2i(515, 150), Vector2i(530, 40)],
	[Vector2i(492, 510), Vector2i(380, 520), Vector2i(240, 540), Vector2i(120, 500), Vector2i(48, 362)],
	[Vector2i(536, 510), Vector2i(640, 470)],
	[Vector2i(514, 528), Vector2i(500, 640)],
]
## New cells this close to the heartland take after its edge; farther in, a broken ridge of hills.
const SEAM: int = 3
const RIDGE: int = 14
const MAIN_CAMP_GAP: int = 14
const CAMP_REACH: int = 12

var _all_land: Dictionary = {}


func _initialize() -> void:
	var scene_root: Node = MapIO.load_scene()
	var changed: int = apply(scene_root)
	var error: Error = OK
	if changed > 0:
		error = MapIO.save_scene(scene_root)
	print("Grew the mainland: %d changes (%s)" % [changed, error_string(error)])
	MapIO.free_scene(scene_root)
	quit(0 if error == OK else 1)


func apply(scene_root: Node) -> int:
	if scene_root.has_meta("mainland_grown"):
		return 0
	_root = scene_root
	_layer = scene_root.get_node(MapIO.TERRAIN)
	_ensure_tiles()
	_rng.seed = SALT
	var land: Dictionary = _grow_land()
	for y: int in range(GROWN.position.y, GROWN.end.y):
		for x: int in range(GROWN.position.x, GROWN.end.x):
			var cell := Vector2i(x, y)
			if land.has(cell):
				_all_land[cell] = true
			elif OLD.has_point(cell):
				if _tile(cell) != "~":
					_all_land[cell] = true
			else:
				_paint(cell, "~")
	_depth = _coast_distances(_all_land)
	_ground(land)
	var changed: int = land.size()
	changed += _town()
	for road: Array in ROADS:
		changed += _route(road)
	changed += _zone(TOWN_NAME, TOWN_RECT.grow(1), Vector2i(-1, -1))
	changed += _coach()
	var reached: Dictionary = _connect(land, TOWN_RECT.position + Vector2i(20, -2))
	changed += _hunts(land, reached)
	scene_root.set_meta("mainland_grown", true)
	return changed


# ---------------------------------------------------------------- the land

## The new land: everything in GROWN outside the heartland, short of a ragged coast on the east,
## south, and north, and of the bay that opens south of Lastlight. Only the piece joined to the
## heartland is kept. Paints it grass.
func _grow_land() -> Dictionary:
	var raw: Dictionary = {}
	for y: int in range(GROWN.position.y, GROWN.end.y):
		for x: int in range(GROWN.position.x, GROWN.end.x):
			var cell := Vector2i(x, y)
			if OLD.has_point(cell):
				continue
			# Headlands and bays a hundred cells across, coves on them, and a ragged edge.
			var ragged: float = (_fbm(cell, 90.0, SALT + 9) - 0.5) * 170.0 + (_fbm(cell, 40.0, SALT) - 0.5) * 50.0 \
				+ (_noise(cell, 9.0, SALT + 5) - 0.5) * 4.0
			var margin: float = clampf(48.0 + ragged * 0.75, 4.0, 95.0)
			if x >= GROWN.end.x - margin or y >= GROWN.end.y - margin:
				continue
			# The north coast eases into the heartland's, which runs along the top of the map.
			if x >= OLD.end.x and y < clampf(12.0 + ragged * 0.5, 3.0, 40.0) * smoothstep(OLD.end.x, OLD.end.x + 46.0, x):
				continue
			if y >= OLD.end.y and x < 18.0 + (y - OLD.end.y) * 0.55 + (_fbm(cell, 30.0, SALT + 7) - 0.5) * 16.0 \
					+ (_fbm(cell, 70.0, SALT + 8) - 0.5) * 120.0 * smoothstep(OLD.end.y, OLD.end.y + 40.0, y):
				continue
			raw[cell] = true
	var around_town: Rect2i = TOWN_RECT.grow(16)
	for y: int in range(around_town.position.y, around_town.end.y):
		for x: int in range(around_town.position.x, around_town.end.x):
			raw[Vector2i(x, y)] = true
	# The piece touching the heartland.
	var land: Dictionary = {}
	var queue: Array[Vector2i] = []
	for cell: Vector2i in raw:
		if cell.x == OLD.end.x and cell.y < OLD.end.y and _tile(cell + Vector2i.LEFT) != "~" \
				or cell.y == OLD.end.y and cell.x < OLD.end.x and _tile(cell + Vector2i.UP) != "~":
			land[cell] = true
			queue.append(cell)
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + side
			if raw.has(next) and not land.has(next):
				land[next] = true
				queue.append(next)
	for cell: Vector2i in land:
		_paint(cell, ".")
	return land


## Steps from a new cell to the heartland, up to RIDGE + 1.
static func _seam(cell: Vector2i) -> int:
	var dx: int = maxi(0, cell.x - (OLD.end.x - 1))
	var dy: int = maxi(0, cell.y - (OLD.end.y - 1))
	return mini(RIDGE + 1, maxi(dx, dy) if cell.x < OLD.end.x or cell.y < OLD.end.y else dx + dy)


## The regions' ground character at a cell, blended between their anchors.
static func _character(cell: Vector2i) -> Array[float]:
	var mix: Array[float] = [0.0, 0.0, 0.0]
	var total: float = 0.0
	for area: Array in AREAS:
		var weight: float = 1.0 / (Vector2(cell).distance_squared_to(Vector2(area[1])) + 400.0)
		total += weight
		for index: int in 3:
			mix[index] += float(area[2 + index]) * weight
	for index: int in 3:
		mix[index] /= total
	return mix


## Beaches, lakes with grassy rims, rock, and woods, each as much
## as the region's character asks; the first cells by the heartland take after its edge, and the
## ridge behind them is rockier and more wooded.
func _ground(land: Dictionary) -> void:
	for cell: Vector2i in land:
		var depth: int = _depth[cell]
		var seam: int = _seam(cell)
		var character: Array[float] = _character(cell)
		var wood_level: float = character[0]
		var rock_level: float = character[2]
		if seam <= SEAM:
			var edge: Vector2i = Vector2i(mini(cell.x, OLD.end.x - 1), mini(cell.y, OLD.end.y - 1))
			var tile: String = _tile(edge)
			if tile in ".TL" and _hash(cell, SALT + 3) % (SEAM + 1) >= seam:
				_paint(cell, tile)
				continue
		elif seam <= RIDGE:
			rock_level = minf(rock_level, 0.56)
			wood_level = minf(wood_level, 0.5)
		if depth <= 2 and _noise(cell, 14.0, SALT + 11) > 0.3:
			_paint(cell, ":")
		elif depth > 10 and _fbm(cell, 34.0, SALT + 21) > character[1]:
			_paint(cell, "~")
		elif depth > 7 and _fbm(cell, 16.0, SALT + 31) > rock_level:
			_paint(cell, "L")
		else:
			var wood: float = _fbm(cell, 22.0, SALT + 41)
			if depth > 3 and (wood > wood_level and _hash(cell, SALT + 43) % 100 < 80
					or wood > wood_level - 0.11 and _hash(cell, SALT + 47) % 100 < 9):
				_paint(cell, "T")
	for cell: Vector2i in land:
		if _tile(cell) in ["T", "L"] and _near(cell, 1, "~"):
			_paint(cell, ".")


# ---------------------------------------------------------------- Brackenford

## The walled town: castle walls with towers at the corners and beside the four gates, cobbled
## streets crossing at a square, and eight houses, the vendor's and artisan's among them (make
## towns moves them indoors).
func _town() -> int:
	var o: Vector2i = TOWN_RECT.position
	var s: Vector2i = TOWN_RECT.size
	for y: int in range(TOWN_RECT.position.y - 6, TOWN_RECT.end.y + 6):
		for x: int in range(TOWN_RECT.position.x - 6, TOWN_RECT.end.x + 6):
			var cell := Vector2i(x, y)
			if TOWN_RECT.has_point(cell):
				var edge: bool = x == o.x or y == o.y or x == TOWN_RECT.end.x - 1 or y == TOWN_RECT.end.y - 1
				_paint(cell, "W" if edge else "=")
			elif not _tile(cell) in [".", ","]:
				_paint(cell, ".")
	var towers: Array[Vector2i] = [o, o + Vector2i(s.x - 2, 0), o + Vector2i(0, s.y - 2), o + Vector2i(s.x - 2, s.y - 2)]
	for gate: Array in [[Vector2i(19, 0), Vector2i.RIGHT], [Vector2i(19, s.y - 1), Vector2i.RIGHT],
			[Vector2i(0, 15), Vector2i.DOWN], [Vector2i(s.x - 1, 15), Vector2i.DOWN]]:
		var start: Vector2i = o + gate[0]
		var along: Vector2i = gate[1]
		for step: int in 3:
			_paint(start + along * step, "=")
		for corner: Vector2i in [start - along * 2, start + along * 3]:
			var block: Vector2i = corner
			if along == Vector2i.DOWN:
				block.x = o.x if gate[0].x == 0 else o.x + s.x - 2
			else:
				block.y = o.y if gate[0].y == 0 else o.y + s.y - 2
			towers.append(block)
	for tower: Vector2i in towers:
		for offset: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
			_paint(tower + offset, "W")
	var changed: int = (s.x + 12) * (s.y + 12)
	for x: int in [3, 12, 22, 31]:
		changed += _house(o + Vector2i(x, 3), Vector2i(7, 6), Vector2i.DOWN)
		changed += _house(o + Vector2i(x, 24), Vector2i(7, 6), Vector2i.UP)
	for corner: Vector2i in [Vector2i(16, 13), Vector2i(24, 13), Vector2i(16, 19), Vector2i(24, 19)]:
		_decor("bush", o + corner)
	_townsfolk("Trader Merla", TOWN_NAME, o + Vector2i(18, 16), "vendor")
	_townsfolk("Artisan Wenna", TOWN_NAME, o + Vector2i(22, 16), "artisan")
	return changed


## Brackenford's waystone on the square, joined to every coach station both ways.
func _coach() -> int:
	var ferrymen: Node = _group("Ferrymen")
	var marker := Marker2D.new()
	marker.name = "brackenford"
	marker.set_script(FERRY_SCRIPT)
	marker.position = (Vector2(TOWN_RECT.position + Vector2i(17, 14)) + Vector2(0.5, 0.5)) * TILE
	marker.set("npc_name", "Waystone")
	marker.set("place", TOWN_NAME)
	var routes: Dictionary[String, int] = {}
	for id: String in COACHES:
		routes[id] = COACHES[id]
		var back: Dictionary[String, int] = ferrymen.get_node(id).get("routes")
		back["brackenford"] = COACHES[id]
		ferrymen.get_node(id).set("routes", back)
	marker.set("routes", routes)
	marker.set("facing", Vector2i.DOWN)
	marker.set("vehicle", "waystone")
	ferrymen.add_child(marker)
	marker.owner = _root
	return 1 + COACHES.size()


# ---------------------------------------------------------------- roads

## One road along its waypoints; a last waypoint in the heartland is moved onto the nearest road
## there.
func _route(waypoints: Array) -> int:
	var points: Array[Vector2i] = []
	for index: int in waypoints.size():
		var point: Vector2i = waypoints[index]
		if OLD.has_point(point):
			point = _nearest(point, ",=")
		else:
			point = _nearest(point, ".,:=")
		points.append(point)
	var changed: int = 0
	for index: int in points.size() - 1:
		changed += _road(points[index], points[index + 1], _all_land)
	return changed


## The cell nearest `toward` (within 40) whose terrain is one of `tiles`.
func _nearest(toward: Vector2i, tiles: String) -> Vector2i:
	for reach: int in 40:
		for dy: int in range(-reach, reach + 1):
			for dx: int in range(-reach, reach + 1):
				if maxi(absi(dx), absi(dy)) == reach and _tile(toward + Vector2i(dx, dy)) in tiles \
						and _all_land.has(toward + Vector2i(dx, dy)):
					return toward + Vector2i(dx, dy)
	return toward


## The island painter's road, over the heartland too: anything neither walkable nor a tree or water
## is in the way (the heartland's cliffs, mushrooms, and walls).
func _road(from: Vector2i, to: Vector2i, land: Dictionary) -> int:
	var astar := AStarGrid2D.new()
	var bounds := Rect2i(from, Vector2i.ONE).expand(to).grow(40).intersection(GROWN)
	astar.region = bounds
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar.update()
	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			var cell := Vector2i(x, y)
			var tile: String = _tile(cell)
			if not land.has(cell) or not (tile in WALKABLE or tile in "T~") or tile in "FYv^":
				astar.set_point_solid(cell, true)
			else:
				astar.set_point_weight_scale(cell, float({"T": 4.0, "~": 14.0, "=": 0.6, ",": 0.5, "m": 1.5}.get(tile, 1.0)))
	if not astar.is_in_boundsv(from) or not astar.is_in_boundsv(to) or astar.is_point_solid(from) or astar.is_point_solid(to):
		push_warning("No road from %s to %s" % [from, to])
		return 0
	var path: Array[Vector2i] = astar.get_id_path(from, to)
	for index: int in path.size():
		var cell: Vector2i = path[index]
		var across := Vector2i.RIGHT
		if index + 1 < path.size() and path[index + 1].x != cell.x:
			across = Vector2i.DOWN
		for side: Vector2i in [Vector2i.ZERO, across]:
			var spot: Vector2i = cell + side
			if not land.has(spot):
				continue
			var tile: String = _tile(spot)
			if tile == "~":
				_paint(spot, "b")
			elif tile in [".", ":", "T"]:
				_paint(spot, ",")
	return path.size()


# ---------------------------------------------------------------- hunting camps

## The monster level at a cell: 1 at Brackenford, rising along the new land to MAX_LEVEL.
static func _level(cell: Vector2i) -> int:
	var distance: int = maxi(0, CENTRE.y - cell.y) + maxi(0, CENTRE.x - cell.x)
	return clampi(1 + roundi(distance * (MAX_LEVEL - 1) / LEVEL_SPAN), 1, MAX_LEVEL)


## The ground round a camp: "wet" by water or bog, "rock" among rock, "wood" in the woods, or "open".
func _ground_kind(cell: Vector2i) -> String:
	var counts: Dictionary = {"wet": 0, "rock": 0, "wood": 0}
	for dy: int in range(-8, 9, 2):
		for dx: int in range(-8, 9, 2):
			var tile: String = _tile(cell + Vector2i(dx, dy))
			if tile == "~":
				counts["wet"] += 1
			elif tile == "L":
				counts["rock"] += 1
			elif tile == "T":
				counts["wood"] += 1
	var best: String = "open"
	var most: int = 8
	for kind: String in counts:
		if counts[kind] > most:
			most = counts[kind]
			best = kind
	return best


## Camps of 5-7 on open ground reached from the town, apart from each other, the town, the roads,
## and water; then one in every stretch still out of reach of a camp. Each camp's monster fits its
## level and, more often than not, its ground.
func _hunts(land: Dictionary, reached: Dictionary) -> int:
	var keep_out: Rect2i = TOWN_RECT.grow(TOWN_CLEAR + 2)
	var spots: Array[Vector2i] = []
	var cells: Array = land.keys()
	cells.sort()
	for cell: Vector2i in cells:
		if _hash(cell, SALT + 61) % 23 != 0 or _depth[cell] < 5 or keep_out.has_point(cell):
			continue
		if _tile(cell) != "." or not reached.has(cell) or _near(cell, ROAD_CLEAR, ",=b~LW"):
			continue
		if not spots.any(func(other: Vector2i) -> bool: return Vector2(cell).distance_to(Vector2(other)) < MAIN_CAMP_GAP):
			spots.append(cell)
	for cell: Vector2i in cells:
		if not reached.has(cell) or not _tile(cell) in [".", ":"] or keep_out.has_point(cell) or _near(cell, 1, ",=b~W"):
			continue
		if spots.any(func(other: Vector2i) -> bool: return maxi(absi(other.x - cell.x), absi(other.y - cell.y)) <= CAMP_REACH):
			continue
		spots.append(cell)
	var spawns: Node = _group("MonsterSpawns")
	for index: int in spots.size():
		var cell: Vector2i = spots[index]
		var kind: String = _ground_kind(cell)
		for dy: int in range(-2, 3):
			for dx: int in range(-2, 3):
				if _tile(cell + Vector2i(dx, dy)) in ["T", "L"]:
					_paint(cell + Vector2i(dx, dy), ".")
		# The monsters whose band is nearest the level here (holding it, where any does).
		var wanted: int = clampi(_level(cell) + _hash(cell, SALT + 67) % 3 - 1, 1, MAX_LEVEL)
		var gap: int = MAX_LEVEL
		for entry: Array in MONSTERS:
			gap = mini(gap, maxi(0, maxi(int(entry[1]) - wanted, wanted - int(entry[2]))))
		var choices: Array = []
		var total: int = 0
		for entry: Array in MONSTERS:
			if maxi(0, maxi(int(entry[1]) - wanted, wanted - int(entry[2]))) == gap:
				var weight: int = 4 if entry[3] == kind else 1
				choices.append(entry + [weight])
				total += weight
		var pick: int = _hash(cell, SALT + 71) % total
		var chosen: Array = choices[0]
		for choice: Array in choices:
			pick -= int(choice[4])
			if pick < 0:
				chosen = choice
				break
		var monster: String = chosen[0]
		var level: int = clampi(wanted, int(chosen[1]), int(chosen[2]))
		var marker := Marker2D.new()
		marker.name = "Mainland_%d" % index
		marker.set_script(SPAWN_SCRIPT)
		marker.position = (Vector2(cell) + Vector2(0.5, 0.5)) * TILE
		marker.set("monster", monster)
		marker.set("level", level)
		marker.set("count", 5 + _hash(cell, SALT + 79) % 3)
		marker.set("radius", 2)
		spawns.add_child(marker)
		marker.owner = _root
	return spots.size()
