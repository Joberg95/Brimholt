extends "res://tools/generators/islands.gd"
## The floor below the mainland (docs/plan/44-underground-floor.md, Atlas.UNDERGROUND): winding
## tunnel networks for levels 10-40 under the countryside, each entered by holes in the wilds right
## over its stairs up, and sewers under the bigger towns, entered by ladders in the streets.
##
## A network is a scatter of chambers (rounded blobs of cave earth) joined by passages that wander
## (paths over a noise field, two or three cells wide), a loop or two, and dead-end spurs, walled
## in by cave rock with the void beyond; its camps are today's cave monsters at the network's
## levels (overworld monsters kept inside their heartland bands, so task bands stay as they are).
## A sewer is a grid of walkways along water channels with bridges, brick walls, and rats.
## Every network and sewer is a zone (underground: dim, dry, no mounts; monsters stay inside).
##
## Runs once (scene metadata underground); then make world-map.
##
##   godot --headless --path . --script res://tools/generators/underground.gd

const Atlas = preload("res://game/data/atlas.gd")
const Buildings = preload("res://game/data/buildings.gd")
## Floors a camp can stand on and count as room round it (not a sewer's water).
const STANDING_FLOOR: String = "c=b"
## id: name, area on the surface (the tunnels lie right under it), levels, monsters by weight, salt.
const NETWORKS: Dictionary = {
	"greywood_burrows": {"name": "Greywood Burrows", "area": Rect2i(60, 56, 110, 84), "levels": Vector2i(10, 16),
		"monsters": [["cave_crawler", 3], ["giant_rat", 2], ["cave_spider", 1]], "salt": 6100},
	"wolfholt_warrens": {"name": "Wolfholt Warrens", "area": Rect2i(400, 260, 150, 110), "levels": Vector2i(12, 20),
		"monsters": [["cave_spider", 3], ["venom_weaver", 2], ["cave_crawler", 1]], "salt": 6200},
	"fernmere_grottoes": {"name": "Fernmere Grottoes", "area": Rect2i(250, 440, 160, 140), "levels": Vector2i(14, 22),
		"monsters": [["bog_lurker", 3], ["venom_weaver", 2], ["cave_spider", 1]], "salt": 6300},
	"barrowmoor_catacombs": {"name": "Barrowmoor Catacombs", "area": Rect2i(100, 430, 130, 150), "levels": Vector2i(18, 26),
		"monsters": [["crypt_skeleton", 3], ["grave_ghoul", 3]], "salt": 6400},
	"stonevale_delvings": {"name": "Stonevale Delvings", "area": Rect2i(60, 220, 100, 110), "levels": Vector2i(22, 30),
		"monsters": [["stone_golem", 3], ["stone_troll", 2], ["cave_crawler", 1]], "salt": 6500},
	"greycrag_mines": {"name": "Greycrag Mines", "area": Rect2i(420, 30, 170, 130), "levels": Vector2i(26, 34),
		"monsters": [["cyclops", 3], ["stone_troll", 2], ["stone_golem", 1]], "salt": 6600},
	"emberwaste_hollows": {"name": "Emberwaste Hollows", "area": Rect2i(226, 296, 94, 84), "levels": Vector2i(30, 36),
		"monsters": [["ember_golem", 3], ["cinder_wraith", 2], ["cyclops_smith", 1]], "salt": 6700},
	"hazel_dens": {"name": "Hazel Downs Dens", "area": Rect2i(420, 380, 190, 100), "levels": Vector2i(10, 14),
		"monsters": [["giant_rat", 3], ["cave_crawler", 2]], "salt": 6900},
	"kestrel_caverns": {"name": "Kestrel Caverns", "area": Rect2i(400, 170, 200, 80), "levels": Vector2i(20, 28),
		"monsters": [["grave_ghoul", 2], ["stone_golem", 2], ["venom_weaver", 1]], "salt": 7000},
	"saltreed_seacaves": {"name": "Saltreed Sea-caves", "area": Rect2i(20, 400, 72, 170), "levels": Vector2i(21, 25),
		"monsters": [["lizard_warrior", 3], ["lizard_shaman", 2]], "salt": 7100},
	"gloamwood_hollows": {"name": "Gloamwood Hollows", "area": Rect2i(140, 340, 76, 80), "levels": Vector2i(16, 24),
		"monsters": [["dire_bear", 2], ["cave_spider", 2], ["venom_weaver", 1]], "salt": 7200},
	"smoulder_deeps": {"name": "Smoulder Deeps", "area": Rect2i(200, 4, 100, 90), "levels": Vector2i(34, 40),
		"monsters": [["cave_troll", 3], ["cyclops_smith", 2], ["ember_golem", 1]], "salt": 6800},
}
const NETWORK_ORDER: Array[String] = ["greywood_burrows", "wolfholt_warrens", "fernmere_grottoes", "barrowmoor_catacombs",
	"stonevale_delvings", "greycrag_mines", "emberwaste_hollows", "smoulder_deeps", "hazel_dens", "kestrel_caverns",
	"saltreed_seacaves", "gloamwood_hollows"]
## The level bands overworld monsters already have in the heartland: their camps here stay inside
## them (World.task_levels reads every camp). Monsters not listed live only in dungeons today.
const BANDS: Dictionary = {"bog_lurker": Vector2i(15, 18), "stone_golem": Vector2i(24, 28), "stone_troll": Vector2i(25, 28),
	"cyclops": Vector2i(29, 31), "cyclops_smith": Vector2i(36, 38), "cinder_wraith": Vector2i(29, 32),
	"cave_troll": Vector2i(38, 42), "dire_bear": Vector2i(20, 22), "lizard_warrior": Vector2i(21, 24),
	"lizard_shaman": Vector2i(23, 25)}
## Towns with sewers: name, levels, and how many ladders down.
const SEWERS: Array = [["Reedmere", Vector2i(4, 8), 3], ["Ashford", Vector2i(5, 9), 2], ["Dunmere", Vector2i(6, 10), 2],
	["Highmoor", Vector2i(7, 11), 2], ["Brackenford", Vector2i(3, 7), 2]]
const TUNNEL_AMBIENT: Color = Color(0.66, 0.62, 0.58)
const SEWER_AMBIENT: Color = Color(0.6, 0.66, 0.72)
const CHAMBER_GAP: float = 16.0
const HOLES_PER_NETWORK: int = 8
const TUNNEL_CAMP_GAP: float = 10.0
## Open cells a camp needs in the 5 x 5 round it (Combat places a pack by random tries there).
const CAMP_ROOM: int = 17
const SEWER_CAMP_GAP: float = 9.0
## Sewer corridors: one along the town's long axis, cross corridors this far apart.
const SEWER_SPACING: int = 11

## Painted floor cells of the network or sewer being built (underground cells).
var _floor: Dictionary = {}
var _town_rects: Array[Rect2i] = []


func _initialize() -> void:
	var scene_root: Node = MapIO.load_scene()
	var changed: int = apply(scene_root)
	var error: Error = OK
	if changed > 0:
		error = MapIO.save_scene(scene_root)
	print("Dug the underground: %d changes (%s)" % [changed, error_string(error)])
	MapIO.free_scene(scene_root)
	quit(0 if error == OK else 1)


func apply(scene_root: Node) -> int:
	if scene_root.has_meta("underground"):
		return 0
	_root = scene_root
	_layer = scene_root.get_node(MapIO.TERRAIN)
	_ensure_tiles()
	var towns: Dictionary = {}
	for zone: Node2D in _group("Zones").get_children():
		if bool(zone.get("town")):
			var rect := Rect2i(Vector2i((zone.position / TILE).floor()), zone.get("size_tiles"))
			_town_rects.append(rect)
			towns[String(zone.get("zone_name"))] = rect
	var changed: int = 0
	for id: String in NETWORK_ORDER:
		changed += _network(id, NETWORKS[id])
	for sewer: Array in SEWERS:
		changed += _sewer(sewer[0], towns[sewer[0]], sewer[1], sewer[2])
	scene_root.set_meta("underground", true)
	return changed


static func under(cell: Vector2i) -> Vector2i:
	return Atlas.below(cell)


# ---------------------------------------------------------------- tunnel networks

func _network(id: String, spec: Dictionary) -> int:
	var area: Rect2i = spec["area"]
	var salt: int = spec["salt"]
	_rng.seed = salt
	_floor = {}
	# Chambers spread over the area, on land (not under the sea or a town).
	var chambers: Array[Vector2i] = []
	for attempt: int in 600:
		var cell := Vector2i(_rng.randi_range(area.position.x + 6, area.end.x - 7), _rng.randi_range(area.position.y + 6, area.end.y - 7))
		if _tile(cell) == "~" or _under_town(cell, 4):
			continue
		if chambers.any(func(other: Vector2i) -> bool: return Vector2(cell).distance_to(Vector2(other)) < CHAMBER_GAP):
			continue
		chambers.append(cell)
	# Passages: a spanning tree over the chambers (nearest first), and a loop for one in three.
	var joined: Array[Vector2i] = [chambers[0]]
	var edges: Array = []
	while joined.size() < chambers.size():
		var best: Array = []
		var nearest: float = INF
		for a: Vector2i in joined:
			for b: Vector2i in chambers:
				if not joined.has(b) and Vector2(a).distance_to(Vector2(b)) < nearest:
					nearest = Vector2(a).distance_to(Vector2(b))
					best = [a, b]
		joined.append(best[1])
		edges.append(best)
	for a: Vector2i in chambers:
		if _hash(a, salt + 3) % 3 != 0:
			continue
		var second: Vector2i = a
		var gaps: Array = chambers.duplicate()
		gaps.sort_custom(func(p: Vector2i, q: Vector2i) -> bool: return Vector2(p).distance_to(Vector2(a)) < Vector2(q).distance_to(Vector2(a)))
		if gaps.size() > 2:
			second = gaps[2]
		if second != a and not edges.any(func(edge: Array) -> bool: return edge.has(a) and edge.has(second)):
			edges.append([a, second])
	var grid := _winding_grid(area, salt)
	for edge: Array in edges:
		_passage(grid, edge[0], edge[1], salt)
	for chamber: Vector2i in chambers:
		_chamber(under(chamber), 3 + _hash(chamber, salt + 5) % 4, salt)
		# A dead-end spur from one chamber in two.
		if _hash(chamber, salt + 7) % 2 == 0:
			_spur(chamber, area, salt)
	var walls: int = _wall_in("C", 2)
	# Holes: over chambers whose surface is open ground in the wilds, spread out.
	var holes: Array[Vector2i] = []
	var ordered: Array[Vector2i] = chambers.duplicate()
	ordered.sort_custom(func(p: Vector2i, q: Vector2i) -> bool: return _hash(p, salt + 9) < _hash(q, salt + 9))
	for chamber: Vector2i in ordered:
		if holes.size() >= HOLES_PER_NETWORK:
			break
		if _open_surface(chamber) and not holes.any(func(other: Vector2i) -> bool: return Vector2(chamber).distance_to(Vector2(other)) < 24.0):
			holes.append(chamber)
	for hole: Vector2i in holes:
		_hole(hole, false)
	var camps: int = _camps_on_floor(id, spec["monsters"], spec["levels"], TUNNEL_CAMP_GAP, holes)
	_underground_zone(spec["name"], spec["levels"], TUNNEL_AMBIENT)
	return _floor.size() + walls + holes.size() * 2 + camps


## A path-finding grid over the area (underground) whose costs follow smooth noise, so passages
## wander instead of running straight.
func _winding_grid(area: Rect2i, salt: int) -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(under(area.position), area.size)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var cell := Vector2i(x, y)
			var weight: float = 1.0 + 14.0 * _fbm(cell, 9.0, salt + 11)
			if _under_town(cell, 2):
				grid.set_point_solid(under(cell), true)
			else:
				grid.set_point_weight_scale(under(cell), weight)
	return grid


## A passage two or three wide along the winding path between two chambers (surface cells).
func _passage(grid: AStarGrid2D, from: Vector2i, to: Vector2i, salt: int) -> void:
	if grid.is_point_solid(under(from)) or grid.is_point_solid(under(to)):
		return
	var path: Array[Vector2i] = grid.get_id_path(under(from), under(to))
	for index: int in path.size():
		var cell: Vector2i = path[index]
		_carve(cell)
		var across := Vector2i.DOWN if index + 1 < path.size() and path[index + 1].y == cell.y else Vector2i.RIGHT
		_carve(cell + across)
		if _hash(cell, salt + 13) % 4 == 0:
			_carve(cell - across)


## A rounded chamber with a ragged edge round an underground cell.
func _chamber(centre: Vector2i, radius: int, salt: int) -> void:
	for dy: int in range(-radius - 2, radius + 3):
		for dx: int in range(-radius - 2, radius + 3):
			var cell: Vector2i = centre + Vector2i(dx, dy)
			var reach: float = radius + (_noise(cell, 3.0, salt + 15) - 0.5) * 3.0
			if Vector2(dx, dy * 1.2).length() <= reach:
				_carve(cell)


## A dead-end side passage wandering off from a chamber (surface cell).
func _spur(chamber: Vector2i, area: Rect2i, salt: int) -> void:
	var cell: Vector2i = chamber
	var heading: Vector2i = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT][_hash(chamber, salt + 17) % 4]
	for step: int in 12 + _hash(chamber, salt + 19) % 14:
		if _hash(cell, salt + 21 + step) % 4 == 0:
			heading = Vector2i(heading.y, heading.x) * (1 if _hash(cell, salt + 23) % 2 == 0 else -1)
		var next: Vector2i = cell + heading
		if not area.grow(-3).has_point(next) or _under_town(next, 2):
			break
		cell = next
		_carve(under(cell))
		_carve(under(cell) + Vector2i(heading.y, heading.x).abs())
	_chamber(under(cell), 2, salt)


func _carve(cell: Vector2i) -> void:
	if Atlas.UNDERGROUND.has_point(cell):
		_paint(cell, "c")
		_floor[cell] = true


## Walls (`tile`) round the current floor out to `thickness` cells; returns how many.
func _wall_in(tile: String, thickness: int) -> int:
	var walls: Dictionary = {}
	for cell: Vector2i in _floor:
		for dy: int in range(-thickness, thickness + 1):
			for dx: int in range(-thickness, thickness + 1):
				var next: Vector2i = cell + Vector2i(dx, dy)
				if not _floor.has(next) and not walls.has(next) and _tile_or_void(next) == " ":
					walls[next] = true
	for cell: Vector2i in walls:
		_paint(cell, tile)
	return walls.size()


## The terrain letter at an underground cell, " " where nothing is painted.
func _tile_or_void(cell: Vector2i) -> String:
	var index: int = _layer.get_cell_atlas_coords(cell).x
	return " " if index < 0 else TERRAINS[index]


func _under_town(cell: Vector2i, margin: int) -> bool:
	return _town_rects.any(func(rect: Rect2i) -> bool: return rect.grow(margin).has_point(cell))


## A surface cell that can take a hole: open ground in the wilds with open ground round it.
func _open_surface(cell: Vector2i) -> bool:
	if not _tile(cell) in [".", ":"] or _under_town(cell, 6) or _near(cell, 2, "~,=b#W"):
		return false
	for zone: Node2D in _group("Zones").get_children():
		if Rect2i(Vector2i((zone.position / TILE).floor()), zone.get("size_tiles")).grow(2).has_point(cell):
			return false
	return true


## A hole (or, in a town, a ladder opening) at a surface cell over stairs up right below it; the
## ground round the hole is cleared (trees and rock) and the floor round the stairs dug out.
func _hole(cell: Vector2i, in_town: bool) -> void:
	_paint(cell, "v")
	if not in_town:
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				if _tile(cell + Vector2i(dx, dy)) in ["T", "L", "C", "U", "R", "K"]:
					_paint(cell + Vector2i(dx, dy), ".")
	_paint(under(cell), "^")
	_floor.erase(under(cell))


## Camps along the floor: apart from each other and the stairs, with room for a pack round them.
func _camps_on_floor(id: String, monsters: Array, levels: Vector2i, gap: float, stairs: Array[Vector2i]) -> int:
	var cells: Array = _floor.keys()
	cells.sort()
	var spots: Array[Vector2i] = []
	for cell: Vector2i in cells:
		if _hash(cell, 31) % 7 != 0 or not _tile(cell) in STANDING_FLOOR:
			continue
		if stairs.any(func(stair: Vector2i) -> bool: return Vector2(cell).distance_to(Vector2(under(stair))) < 6.0):
			continue
		var room: int = 0
		for dy: int in range(-2, 3):
			for dx: int in range(-2, 3):
				room += 1 if _tile(cell + Vector2i(dx, dy)) in STANDING_FLOOR else 0
		if room < CAMP_ROOM or spots.any(func(other: Vector2i) -> bool: return Vector2(cell).distance_to(Vector2(other)) < gap):
			continue
		spots.append(cell)
	var total: int = 0
	for entry: Array in monsters:
		total += int(entry[1])
	var spawns: Node = _group("MonsterSpawns")
	for index: int in spots.size():
		var cell: Vector2i = spots[index]
		var pick: int = _hash(cell, 37) % total
		var monster: String = monsters[0][0]
		for entry: Array in monsters:
			pick -= int(entry[1])
			if pick < 0:
				monster = entry[0]
				break
		var level: int = levels.x + _hash(cell, 41) % (levels.y - levels.x + 1)
		if BANDS.has(monster):
			level = clampi(level, BANDS[monster].x, BANDS[monster].y)
		var marker := Marker2D.new()
		marker.name = "Under_%s_%d" % [id, index]
		marker.set_script(SPAWN_SCRIPT)
		marker.position = (Vector2(cell) + Vector2(0.5, 0.5)) * TILE
		marker.set("monster", monster)
		marker.set("level", level)
		marker.set("count", 5 + _hash(cell, 43) % 3)
		marker.set("radius", 2)
		spawns.add_child(marker)
		marker.owner = _root
	return spots.size()


## The zone over everything just dug (floor and walls), on the floor below.
func _underground_zone(zone_name: String, levels: Vector2i, ambient: Color) -> void:
	var bounds := Rect2i()
	var first: bool = true
	for cell: Vector2i in _floor:
		bounds = Rect2i(cell, Vector2i.ONE) if first else bounds.expand(cell)
		first = false
	bounds = bounds.grow(3)
	var zone := Node2D.new()
	zone.name = zone_name.to_pascal_case()
	zone.set_script(ZONE_SCRIPT)
	zone.position = Vector2(bounds.position) * TILE
	zone.set("zone_name", zone_name)
	zone.set("size_tiles", bounds.size + Vector2i.ONE)
	zone.set("town", false)
	zone.set("min_level", levels.x)
	zone.set("max_level", levels.y)
	zone.set("ambient", ambient)
	_group("Zones").add_child(zone)
	zone.owner = _root


# ---------------------------------------------------------------- sewers

## Walkways along a water channel (bridged every few cells) down the town's long axis and across
## it every SEWER_SPACING cells, a chamber at each end, brick walls, ladders up into the streets,
## and rats.
func _sewer(town: String, rect: Rect2i, levels: Vector2i, ladders: int) -> int:
	_floor = {}
	var inner: Rect2i = rect.grow(-3)
	var wide: bool = inner.size.x >= inner.size.y
	var middle: Vector2i = inner.get_center()
	var long_start: int = inner.position.x if wide else inner.position.y
	var long_end: int = inner.end.x - 1 if wide else inner.end.y - 1
	_channel(middle, wide, long_start, long_end)
	var across_start: int = inner.position.y if wide else inner.position.x
	var across_end: int = inner.end.y - 1 if wide else inner.end.x - 1
	var at: int = long_start + SEWER_SPACING / 2
	while at < long_end - 2:
		var crossing: Vector2i = Vector2i(at, middle.y) if wide else Vector2i(middle.x, at)
		_channel(crossing, not wide, across_start, across_end)
		# A grated chamber where the channels meet, and one at each end of the cross corridor.
		var rooms: Array[Vector2i] = [crossing]
		for end: int in [across_start + 2, across_end - 2]:
			rooms.append(Vector2i(at, end) if wide else Vector2i(end, at))
		for room: Vector2i in rooms:
			for dy: int in range(-2, 3):
				for dx: int in range(-2, 3):
					_paint(under(room + Vector2i(dx, dy)), "=")
					_floor[under(room + Vector2i(dx, dy))] = true
		at += SEWER_SPACING
	for end: int in [long_start, long_end]:
		var room: Vector2i = Vector2i(end, middle.y) if wide else Vector2i(middle.x, end)
		for dy: int in range(-2, 3):
			for dx: int in range(-2, 3):
				_sewer_floor(under(room + Vector2i(dx, dy)), "=")
	# Ladders: street cells in the town over (or beside) the walkways, apart from each other.
	var placed: Array[Vector2i] = []
	var terrain_of: Callable = func(cell: Vector2i) -> String: return _tile(cell)
	var built: Dictionary = {}
	for building: Dictionary in Buildings.find(terrain_of, rect.grow(1)):
		for cell: Vector2i in building["footprint"]:
			built[cell] = true
	var markers: Dictionary = {}
	for group: String in ["Ferrymen", "QuestGivers", "Townsfolk", "Decor", "Spawns", "Items", "DungeonEntrances"]:
		for marker: Node2D in _group(group).get_children():
			markers[Vector2i((marker.position / TILE).floor())] = true
	var walkways: Array = _floor.keys().filter(func(cell: Vector2i) -> bool: return _tile(cell) == "=")
	walkways.sort()
	for cell: Vector2i in walkways:
		if placed.size() >= ladders:
			break
		var surface: Vector2i = Atlas.above(cell)
		if _tile(surface) != "=" or built.has(surface) or markers.has(surface) or _near(surface, 1, "#Wv"):
			continue
		if placed.any(func(other: Vector2i) -> bool: return Vector2(surface).distance_to(Vector2(other)) < 18.0):
			continue
		if surface.distance_to(rect.get_center()) < 6.0:
			continue
		placed.append(surface)
	for surface: Vector2i in placed:
		_hole(surface, true)
	var walls: int = _wall_in("#", 1)
	var spots: Array[Vector2i] = []
	for cell: Vector2i in placed:
		spots.append(cell)
	var rats: Array = [["sewer_rat", 2], ["giant_rat", 1]]
	var camps: int = _camps_on_floor(town.to_snake_case() + "_sewers", rats, levels, SEWER_CAMP_GAP, spots)
	_underground_zone("%s sewers" % town, levels, SEWER_AMBIENT)
	return _floor.size() + walls + placed.size() * 2 + camps


## One corridor: a water channel down the middle with walkways either side and a bridge every
## five cells, from `from` to `to` along the long (`wide`: west-east) or short axis through `through`.
func _channel(through: Vector2i, wide: bool, from: int, to: int) -> void:
	for along: int in range(from, to + 1):
		for side: int in range(-1, 2):
			var cell: Vector2i = Vector2i(along, through.y + side) if wide else Vector2i(through.x + side, along)
			var water: bool = side == 0 and along % 5 != 0
			_sewer_floor(under(cell), "~" if water else ("b" if side == 0 else "="))


## Paints a sewer floor cell; walkways never turn back into water where corridors cross.
func _sewer_floor(cell: Vector2i, tile: String) -> void:
	if _floor.has(cell) and tile == "~":
		return
	_paint(cell, tile)
	_floor[cell] = true
