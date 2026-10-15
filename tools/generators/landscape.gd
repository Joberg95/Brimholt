extends SceneTree
## Reshapes the overworld into a settled countryside, in the existing scene:
## - towns grow outward where the land is free, with an outer stone wall, gates where roads
##   enter, a ring of houses against the wall, and cobblestone streets;
## - the capital (CAPITAL) gets a walled castle on its west side: keep, barracks, chapel,
##   corner towers, and a gatehouse facing the town;
## - roads between towns become two-tile cobblestone;
## - the speckled forest becomes coherent woods with meadows between (low-frequency noise);
## - rock outcrops (cave rock "C") and boulders ("R") dot the meadows, and the loose wall bits of
##   the highlands become rock;
## - each town gets dry-stone pastures on its outskirts;
## - MERGES join neighbouring towns into one: the start town and its harbour become one walled
##   Cinder Crossing, with houses filling the ground between them and an open, cobbled plaza
##   kept for a future starter guide.
## Blackreed Isle, the Hollow Reach, the desert, dungeons, markers, and monster camps are left
## alone. The scene remembers that it ran (metadata "landscape"); running again changes nothing.
##
##   godot --headless --path . --script res://tools/generators/landscape.gd

## Must match World.TERRAINS (the rules check verifies it).
const TERRAINS: String = ".,~#T:=bdoODcCv^KRLWmU"
const Regions = preload("res://game/data/regions.gd")
const SCENE_PATH: String = "res://game/maps/overworld.tscn"
const TILE: int = 32
## The overworld; the dungeon band lies to its right.
const WORLD: Rect2i = Rect2i(0, 0, 384, 384)
const CAPITAL: String = "Reedmere"
## [town, absorbed town]: the absorbed zone is removed, its townsfolk and quest givers take the
## town's name (ferrymen keep their dock name), and the ground between is built up.
const MERGES: Array = [["Cinder Crossing", "Cinder Landing"]]
## Extra tiles a merged town grows east (beyond RING) for a new district of houses.
const DISTRICT: int = 4
## The open plaza kept free in the middle of a merged town.
const PLAZA_SIZE: Vector2i = Vector2i(9, 7)
const INFILL_SIZES: Array[Vector2i] = [Vector2i(6, 5), Vector2i(7, 5), Vector2i(5, 5)]
## How far towns grow on each side: houses (5 deep, sharing the town wall) and a 3-tile street.
const RING: int = 8
## A side needs at least this margin for a wall (thinner margins stay open).
const MIN_WALL: int = 2
const HOUSE_DEPTH: int = 5
const HOUSE_WIDTHS: Array[int] = [5, 6, 7]
const HOUSE_GAP: int = 2
## Forest noise below MEADOW_LEVEL clears to meadow; above WOOD_LEVEL grows into woodland
## (WOOD_DENSITY trees per hundred tiles, for a ragged edge); between, the map stays as painted.
const MEADOW_LEVEL: float = 0.46
const WOOD_LEVEL: float = 0.56
const WOOD_DENSITY: int = 80
## Rock outcrops where the rock noise is above this (lower in the highlands).
const ROCK_LEVEL: float = 0.8
const HIGHLAND_ROCK_LEVEL: float = 0.74
## The north-eastern highlands around Highmoor.
const HIGHLANDS: Rect2i = Rect2i(230, 0, 154, 170)
## Boulders per thousand open meadow tiles, and per hundred beside an outcrop.
const BOULDERS_PER_THOUSAND: int = 7
const BOULDERS_BY_ROCK: int = 10
## Loose wall pieces outside towns up to this size become rock.
const LOOSE_WALL: int = 10
const PASTURES_PER_TOWN: int = 2
const PASTURE_SIZE: Vector2i = Vector2i(9, 7)
const MARKER_GROUPS: Array[String] = ["Spawns", "Items", "Ferrymen", "QuestGivers", "DungeonEntrances", "Townsfolk"]
const SIDES: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
## Castle plan, 24x18: "#" wall, "=" cobble, "." keep as is. The east gate faces the town.
const CASTLE: Array[String] = [
	"########################",
	"##==========#====#====##",
	"#===========#====#=====#",
	"#===========#====#=====#",
	"#===========#====#=====#",
	"#===========###=##=====#",
	"##########=============#",
	"#========#============##",
	"#========#==============",
	"#=======================",
	"#========#==============",
	"#========#============##",
	"##########==###=##=====#",
	"#===========#====#=====#",
	"#===========#====#=====#",
	"#===========#====#=====#",
	"##==========#====#====##",
	"########################",
]

var _layer: TileMapLayer
## Cells that must stay as they are (markers and the tiles around them).
var _reserved: Dictionary = {}
## [centre, radius, node] of every monster camp.
var _camps: Array = []
## [name, rect, town] of every zone, kept up to date as towns grow.
var _zones: Array = []
## Town name -> rects no new house may touch (the original towns, as painted, and plazas).
var _protected: Dictionary = {}
## Towns that get a DISTRICT.
var _districts: Array[String] = []


func _initialize() -> void:
	var scene_root: Node = (load(SCENE_PATH) as PackedScene).instantiate()
	if scene_root.has_meta("landscape"):
		print("The landscape is already painted into %s: nothing to do" % SCENE_PATH)
		scene_root.free()
		quit(0)
		return
	var report: Dictionary = apply(scene_root)
	var error: Error = ERR_INVALID_DATA
	if not report.is_empty():
		scene_root.set_meta("landscape", true)
		var packed := PackedScene.new()
		packed.pack(scene_root)
		error = ResourceSaver.save(packed, SCENE_PATH)
	print("Painted the landscape into %s: %s (%s)" % [SCENE_PATH, report, error_string(error)])
	scene_root.free()
	quit(0 if error == OK else 1)


## Paints everything; returns counts of what changed, or {} (with an error) when it cannot.
func apply(scene_root: Node) -> Dictionary:
	var town_nodes: Array[Node2D] = _prepare(scene_root)
	var report: Dictionary = {"towns": 0, "houses": 0, "castle": 0, "road": 0, "trees removed": 0, "outcrops": 0,
		"boulders": 0, "pastures": 0, "merged": 0}
	for merge: Array in MERGES:
		var houses: int = _merge(scene_root, merge[0], merge[1], town_nodes)
		if houses < 0:
			return {}
		report["merged"] += 1
		report["houses"] += houses
	# Roads first, so towns gate them and the countryside keeps clear of them.
	report["road"] = _roads()
	# The capital first: its castle needs the most room.
	town_nodes.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return String(a.get("zone_name")) == CAPITAL and String(b.get("zone_name")) != CAPITAL)
	for zone: Node2D in town_nodes:
		var grown: Dictionary = _grow_town(zone)
		if grown.is_empty():
			return {}
		report["towns"] += 1
		report["houses"] += grown["houses"]
		report["castle"] += grown.get("castle", 0)
	report["trees removed"] = _thin_forest()
	report["outcrops"] = _outcrops()
	report["boulders"] = _boulders()
	for index: int in _zones.size():
		if _zones[index][2]:
			report["pastures"] += _pastures(_zones[index][1])
	report["paths carved"] = _reconnect(scene_root)
	return report


## Every marker must stay reachable on foot from the player spawns (or its own dock): for any that
## is not, the shortest way back through trees, boulders, and rock outcrops is cleared to meadow.
## Places only reachable by boat (an island) are left alone. Returns the tiles cleared.
func _reconnect(scene_root: Node) -> int:
	var walkable: String = ".,:=bdocv^"
	var reached: Dictionary = {}
	var starts: Array[Vector2i] = []
	for group: String in ["Spawns", "Ferrymen"]:
		for marker: Node2D in scene_root.get_node(group).get_children():
			starts.append(_cell_of(marker))
	_flood(starts, walkable, reached)
	var targets: Array[Vector2i] = []
	for group: String in ["Items", "QuestGivers", "Townsfolk", "DungeonEntrances", "MonsterSpawns"]:
		for marker: Node2D in scene_root.get_node(group).get_children():
			targets.append(_cell_of(marker))
	var cleared: int = 0
	for target: Vector2i in targets:
		if reached.has(target) or not WORLD.has_point(target):
			continue
		# Search outward from the target through walkable ground and clearable obstacles.
		var came: Dictionary = {target: target}
		var queue: Array[Vector2i] = [target]
		var found := Vector2i(-1, -1)
		var head: int = 0
		while head < queue.size() and found.x < 0:
			var cell: Vector2i = queue[head]
			head += 1
			for side: Vector2i in SIDES:
				var next: Vector2i = cell + side
				if came.has(next) or not WORLD.has_point(next):
					continue
				var tile: String = _tile(next)
				if tile.is_empty() or not (tile in walkable or tile in "TRCL"):
					continue
				came[next] = cell
				if reached.has(next):
					found = next
					break
				queue.append(next)
		if found.x < 0:
			continue
		var step: Vector2i = came[found]
		var path: Array[Vector2i] = []
		while true:
			path.append(step)
			if _tile(step) in "TRCL":
				_paint(step, ".")
				cleared += 1
			if step == target:
				break
			step = came[step]
		_flood(path, walkable, reached)
	return cleared


func _flood(starts: Array[Vector2i], walkable: String, reached: Dictionary) -> void:
	var queue: Array[Vector2i] = []
	for start: Vector2i in starts:
		if not reached.has(start):
			reached[start] = true
			queue.append(start)
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for side: Vector2i in SIDES:
			var next: Vector2i = cell + side
			var tile: String = _tile(next)
			if not reached.has(next) and not tile.is_empty() and tile in walkable:
				reached[next] = true
				queue.append(next)


## Reads the terrain layer, markers (and the tiles around them), monster camps, and zones;
## returns the town zone nodes.
func _prepare(scene_root: Node) -> Array[Node2D]:
	_layer = scene_root.get_node("Terrain")
	for group: String in MARKER_GROUPS:
		if scene_root.has_node(group):
			for marker: Node2D in scene_root.get_node(group).get_children():
				var cell: Vector2i = _cell_of(marker)
				for y: int in range(-1, 2):
					for x: int in range(-1, 2):
						_reserved[cell + Vector2i(x, y)] = true
	for spawn: Node2D in scene_root.get_node("MonsterSpawns").get_children():
		_camps.append([_cell_of(spawn), int(spawn.get("radius")), spawn])
	var town_nodes: Array[Node2D] = []
	for zone: Node2D in scene_root.get_node("Zones").get_children():
		_zones.append([String(zone.get("zone_name")), Rect2i(Vector2i((zone.position / TILE).round()), zone.get("size_tiles")),
			bool(zone.get("town"))])
		if zone.get("town"):
			town_nodes.append(zone)
	return town_nodes


# ---------------------------------------------------------------- terrain helpers

func _tile(cell: Vector2i) -> String:
	var index: int = _layer.get_cell_atlas_coords(cell).x
	return TERRAINS[index] if index >= 0 and index < TERRAINS.length() else ""


func _paint(cell: Vector2i, tile: String) -> void:
	_layer.set_cell(cell, 0, Vector2i(TERRAINS.find(tile), 0))


## The zone at `cell`: [name, rect, town], or [] in the open.
func _zone(cell: Vector2i) -> Array:
	for zone: Array in _zones:
		if (zone[1] as Rect2i).has_point(cell):
			return zone
	return []


## Open country: overworld, outside every zone, not reserved.
func _countryside(cell: Vector2i) -> bool:
	return WORLD.has_point(cell) and _zone(cell).is_empty() and not _reserved.has(cell)


func _near(cell: Vector2i, distance: int, tiles: String) -> bool:
	for y: int in range(-distance, distance + 1):
		for x: int in range(-distance, distance + 1):
			var tile: String = _tile(cell + Vector2i(x, y))
			if not tile.is_empty() and tile in tiles:
				return true
	return false


func _near_camp(cell: Vector2i, extra: int) -> bool:
	for camp: Array in _camps:
		var offset: Vector2i = (camp[0] as Vector2i) - cell
		if maxi(absi(offset.x), absi(offset.y)) <= int(camp[1]) + extra:
			return true
	return false


static func _hash(cell: Vector2i, salt: int) -> int:
	return absi((cell.x * 73856093) ^ (cell.y * 19349663) ^ (salt * 83492791)) % 1000003


## Smooth value noise in 0..1: hashed lattice values every `period` tiles, blended smoothly.
static func _noise(cell: Vector2i, period: float, salt: int) -> float:
	var at: Vector2 = Vector2(cell) / period
	var base := Vector2i(floori(at.x), floori(at.y))
	var t: Vector2 = at - Vector2(base)
	t = t * t * (Vector2(3, 3) - 2.0 * t)
	var corners: Array[float] = []
	for offset: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		corners.append(float(_hash(base + offset, salt) % 1000) / 999.0)
	return lerpf(lerpf(corners[0], corners[1], t.x), lerpf(corners[2], corners[3], t.x), t.y)


# ---------------------------------------------------------------- merged towns

## Joins `absorbed` into `town`: one zone over both, the absorbed zone removed, its people
## renamed, and houses and a plaza on the ground between. Returns the houses built, or -1.
func _merge(scene_root: Node, town: String, absorbed: String, town_nodes: Array[Node2D]) -> int:
	var keep: int = _zones.find_custom(func(entry: Array) -> bool: return entry[0] == town)
	var gone: int = _zones.find_custom(func(entry: Array) -> bool: return entry[0] == absorbed)
	if keep < 0 or gone < 0:
		push_error("Cannot merge %s into %s: zone missing" % [absorbed, town])
		return -1
	var first: Rect2i = _zones[keep][1]
	var second: Rect2i = _zones[gone][1]
	var union: Rect2i = first.merge(second)
	for node: Node2D in town_nodes.duplicate():
		if String(node.get("zone_name")) == absorbed:
			town_nodes.erase(node)
			node.get_parent().remove_child(node)
			node.free()
		elif String(node.get("zone_name")) == town:
			node.position = Vector2(union.position * TILE)
			node.set("size_tiles", union.size)
	_zones[keep][1] = union
	_zones.remove_at(gone)
	_districts.append(town)
	for group: String in ["Townsfolk", "QuestGivers"]:
		for marker: Node in scene_root.get_node(group).get_children():
			if String(marker.get("place")) == absorbed:
				marker.set("place", town)
	# The ground between the two old towns: a plaza in its middle, houses around it.
	var between := Rect2i(union.position.x, mini(first.end.y, second.end.y), union.size.x,
		maxi(first.position.y, second.position.y) - mini(first.end.y, second.end.y))
	if between.size.y <= 0:
		between = Rect2i(mini(first.end.x, second.end.x), union.position.y,
			maxi(first.position.x, second.position.x) - mini(first.end.x, second.end.x), union.size.y)
	for y: int in range(union.position.y, union.end.y):
		for x: int in range(union.position.x, union.end.x):
			var cell := Vector2i(x, y)
			if not first.has_point(cell) and not second.has_point(cell) and _tile(cell) == "T":
				_paint(cell, ".")
	var plaza := Rect2i(between.get_center() - PLAZA_SIZE / 2, PLAZA_SIZE)
	for y: int in range(plaza.position.y, plaza.end.y):
		for x: int in range(plaza.position.x, plaza.end.x):
			if _tile(Vector2i(x, y)) in [".", ":", ","]:
				_paint(Vector2i(x, y), "=")
	_protected[town] = [first, second, plaza.grow(1)]
	_clear_camps(union)
	return 0


## Houses on open ground in `area`: each with a ring of meadow or street around it (so buildings
## never share walls or trap a corridor) and a door in the middle of its south wall.
func _infill(area: Rect2i, keep_clear: Array) -> int:
	var built: int = 0
	var y: int = area.position.y + 1
	while y < area.end.y - 1:
		var x: int = area.position.x + 1
		var tallest: int = 1
		while x < area.end.x - 1:
			var size: Vector2i = INFILL_SIZES[_hash(Vector2i(x, y), 41) % INFILL_SIZES.size()]
			var house := Rect2i(Vector2i(x, y), size)
			var door := Vector2i(house.position.x + size.x / 2, house.end.y - 1)
			var ok: bool = area.grow(-1).encloses(house) and not keep_clear.any(func(rect: Rect2i) -> bool:
				return house.grow(1).intersects(rect))
			if ok:
				for cy: int in range(house.position.y - 1, house.end.y + 1):
					for cx: int in range(house.position.x - 1, house.end.x + 1):
						var cell := Vector2i(cx, cy)
						# Streets may run along the ring, never through the house itself.
						var ring: bool = not house.has_point(cell)
						if _reserved.has(cell) or not (_tile(cell) in [".", ":"] or ring and _tile(cell) in ["=", ","]):
							ok = false
				ok = ok and _tile(door + Vector2i.DOWN * 2) in [".", ":", "="]
			if not ok:
				x += 1
				continue
			for cy: int in range(house.position.y, house.end.y):
				for cx: int in range(house.position.x, house.end.x):
					var border: bool = cx == house.position.x or cx == house.end.x - 1 or cy == house.position.y or cy == house.end.y - 1
					_paint(Vector2i(cx, cy), "#" if border else "=")
			_paint(door, "=")
			built += 1
			tallest = maxi(tallest, size.y + 2)
			x += size.x + HOUSE_GAP
		y += tallest
	return built


# ---------------------------------------------------------------- roads

## Dirt roads become cobblestone, widened to two tiles (east of north-south runs, south of
## the rest) where the extra tile is meadow or forest.
func _roads() -> int:
	var road: Array[Vector2i] = []
	for cell: Vector2i in _layer.get_used_cells():
		if WORLD.has_point(cell) and _tile(cell) == "," and (_zone(cell).is_empty() or _zone(cell)[2]):
			road.append(cell)
	var changed: int = 0
	for cell: Vector2i in road:
		_paint(cell, "=")
		changed += 1
	for cell: Vector2i in road:
		var vertical: bool = road.has(cell + Vector2i.UP) or road.has(cell + Vector2i.DOWN)
		var beside: Vector2i = cell + (Vector2i.RIGHT if vertical else Vector2i.DOWN)
		if _tile(beside) in [".", "T"] and _countryside(beside):
			_paint(beside, "=")
			changed += 1
	return changed


# ---------------------------------------------------------------- towns

## Grows a town zone by up to RING tiles per side, walls it, and lines the wall with houses.
## Returns {houses, [castle]}, or {} on failure.
func _grow_town(zone: Node2D) -> Dictionary:
	var name: String = String(zone.get("zone_name"))
	var index: int = _zones.find_custom(func(entry: Array) -> bool: return entry[0] == name)
	var old: Rect2i = _zones[index][1]
	# Margins: north, south, west, east.
	var margins: Array[int] = [RING, RING, RING, RING]
	var castle := Rect2i()
	if name in _districts:
		margins[3] = RING + DISTRICT
		_clear_camps(Rect2i(old.end.x, old.position.y - RING, RING + DISTRICT, old.size.y + RING * 2))
	if name == CAPITAL:
		castle = Rect2i(old.position.x - RING - CASTLE[0].length(), old.position.y + old.size.y / 2 - CASTLE.size() / 2,
			CASTLE[0].length(), CASTLE.size())
		margins[2] = old.position.x - castle.position.x
		_clear_camps(Rect2i(castle.position, Vector2i(old.position.x - castle.position.x, castle.size.y)))
	var grown: Rect2i = _fit(old, margins, index)
	if not castle.size.x == 0 and not grown.encloses(castle):
		push_error("No room for the castle west of %s (castle %s, town %s)" % [name, castle, grown])
		return {}
	_zones[index][1] = grown
	zone.position = Vector2(grown.position * TILE)
	zone.set("size_tiles", grown.size)
	var result: Dictionary = {"houses": 0}
	for y: int in range(grown.position.y, grown.end.y):
		for x: int in range(grown.position.x, grown.end.x):
			var cell := Vector2i(x, y)
			if not old.has_point(cell) and _tile(cell) == "T":
				_paint(cell, ".")
	if castle.size.x > 0:
		_castle(castle)
		result["castle"] = 1
	var depth: Array[int] = [old.position.y - grown.position.y, grown.end.y - old.end.y, old.position.x - grown.position.x,
		grown.end.x - old.end.x]
	# Town wall on every side deep enough, leaving 3-tile gates where streets cross it.
	for side: int in 4:
		if depth[side] < MIN_WALL:
			continue
		for cell: Vector2i in _edge(grown, side):
			if castle.has_point(cell) or _reserved.has(cell) or not _tile(cell) in [".", ":"]:
				continue
			if _gate(cell, side):
				continue
			_paint(cell, "#")
		_open_gate(grown, side, depth[side], castle)
	# Houses against the wall, doors toward the town, and a cobbled street inside them.
	for side: int in 4:
		if depth[side] < HOUSE_DEPTH + 1:
			continue
		result["houses"] += _house_row(grown, old, side, depth[side], castle)
	# Houses on the open ground left inside the new town, clear of the old town and the castle.
	var keep_clear: Array = _protected.get(name, [old]).duplicate()
	if castle.size.x > 0:
		keep_clear.append(castle.grow(1))
	result["houses"] += _infill(grown, keep_clear)
	return result


## Moves monster camps whose ground reaches into `site` out of it until they are
## clear of it (by 6 tiles, so monsters do not crowd the walls), on open meadow outside every zone, and not on top of another
## camp, in the same region (so its levels and lexicon place stay); starter camps stay close to their town.
func _clear_camps(site: Rect2i) -> void:
	for camp: Array in _camps:
		var cell: Vector2i = camp[0]
		var reach: int = int(camp[1]) + 2
		if not site.grow(reach).has_point(cell):
			continue
		var moved: Vector2i = cell
		var found: bool = false
		# Rings around the cleared site, nearest first; on the first ring with open ground, the
		# tile nearest the old camp.
		for ring: int in range(reach + 6, reach + 66):
			var around: Rect2i = site.grow(ring)
			var best: int = 1 << 30
			for edge: int in 4:
				for spot: Vector2i in _edge(around, edge):
					var distance: int = (spot - cell).length_squared()
					if distance < best and _camp_site(spot, cell, camp):
						best = distance
						moved = spot
						found = true
			if found:
				break
		if not found:
			push_warning("No open ground to move the %s camp at %s to" % [camp[2].get("monster"), cell])
			continue
		camp[0] = moved
		(camp[2] as Node2D).position = Vector2(moved * TILE) + Vector2.ONE * TILE / 2.0
		print("moved the %s camp from %s to %s" % [camp[2].get("monster"), cell, moved])


## Open meadow outside every zone, in the same region as `from`, and away from other camps.
func _camp_site(spot: Vector2i, from: Vector2i, camp: Array) -> bool:
	return WORLD.has_point(spot) and _tile(spot) == "." and _zone(spot).is_empty() and not _reserved.has(spot) \
		and _region(spot) == _region(from) and not _camps.any(func(other: Array) -> bool:
			return other != camp and maxi(absi(other[0].x - spot.x), absi(other[0].y - spot.y)) < 4)


## The largest rect within `margins` around `old` that stays on free land: inside the
## overworld, clear of other zones and monster camps, and without stairs, rock, or dungeon ground.
func _fit(old: Rect2i, margins: Array[int], own: int) -> Rect2i:
	while true:
		var rect := Rect2i(old.position.x - margins[2], old.position.y - margins[0],
			old.size.x + margins[2] + margins[3], old.size.y + margins[0] + margins[1])
		var bad: Dictionary = {}
		for y: int in range(rect.position.y, rect.end.y):
			for x: int in range(rect.position.x, rect.end.x):
				var cell := Vector2i(x, y)
				if old.has_point(cell) or _free(cell, own):
					continue
				# Corners belong to the north and south strips.
				if y < old.position.y:
					bad[0] = true
				elif y >= old.end.y:
					bad[1] = true
				elif x < old.position.x:
					bad[2] = true
				else:
					bad[3] = true
		if bad.is_empty():
			return rect
		for side: int in bad:
			margins[side] = maxi(0, margins[side] - 1)
	return old


func _free(cell: Vector2i, own: int) -> bool:
	if not WORLD.has_point(cell) or _near_camp(cell, 2):
		return false
	for index: int in _zones.size():
		if index != own and (_zones[index][1] as Rect2i).grow(2).has_point(cell):
			return false
	var tile: String = _tile(cell)
	# Water may lie inside a town (harbours already do); walls and houses go only on land.
	return not tile.is_empty() and tile in ".,:=T#K~b"


## The cells of a rect's border on one side (0 north, 1 south, 2 west, 3 east).
static func _edge(rect: Rect2i, side: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if side < 2:
		var y: int = rect.position.y if side == 0 else rect.end.y - 1
		for x: int in range(rect.position.x, rect.end.x):
			cells.append(Vector2i(x, y))
	else:
		var x: int = rect.position.x if side == 2 else rect.end.x - 1
		for y: int in range(rect.position.y, rect.end.y):
			cells.append(Vector2i(x, y))
	return cells


## Gives a walled side with no gate one in its middle (or the nearest land): three tiles wide,
## with a cobbled way through the house row and two tiles out into the country.
func _open_gate(grown: Rect2i, side: int, depth: int, castle: Rect2i) -> void:
	var wall: Array[Vector2i] = _edge(grown, side)
	var walled: Array[Vector2i] = wall.filter(func(cell: Vector2i) -> bool: return _tile(cell) == "#")
	if walled.is_empty() or wall.any(func(cell: Vector2i) -> bool: return _tile(cell) in [",", "="]):
		return
	var inward: Vector2i = [Vector2i.DOWN, Vector2i.UP, Vector2i.RIGHT, Vector2i.LEFT][side]
	var along: Vector2i = Vector2i.RIGHT if side < 2 else Vector2i.DOWN
	var middle: int = wall.size() / 2
	for offset: int in wall.size():
		for at: int in [middle + offset, middle - offset]:
			if at < 1 or at >= wall.size() - 1:
				continue
			var cells: Array[Vector2i] = []
			for across: int in range(-1, 2):
				for step: int in range(-2, mini(depth, RING)):
					cells.append(wall[at] + along * across + inward * step)
			if cells.all(func(cell: Vector2i) -> bool:
					return not castle.grow(1).has_point(cell) and not _reserved.has(cell) and _tile(cell) in [".", ":", "#", "T"]):
				for cell: Vector2i in cells:
					_paint(cell, "=")
				return


## A wall cell within one tile (along the wall) of a street or road crossing it.
func _gate(cell: Vector2i, side: int) -> bool:
	var along: Vector2i = Vector2i.RIGHT if side < 2 else Vector2i.DOWN
	for step: int in range(-1, 2):
		if _tile(cell + along * step) in [",", "="]:
			return true
	return false


## Houses along one side: HOUSE_DEPTH deep, sharing the town wall, a door in the middle of
## the inner wall, and a cobbled street between them and the old town.
func _house_row(grown: Rect2i, old: Rect2i, side: int, depth: int, castle: Rect2i) -> int:
	var inward: Vector2i = [Vector2i.DOWN, Vector2i.UP, Vector2i.RIGHT, Vector2i.LEFT][side]
	var wall: Array[Vector2i] = _edge(grown, side)
	# North and south rows run the full width (inside the corners); west and east rows only beside the old town.
	var first: int = 2 if side < 2 else old.position.y - grown.position.y
	var last: int = wall.size() - 2 if side < 2 else old.end.y - grown.position.y
	var built: int = 0
	var at: int = first
	while at < last:
		var width: int = HOUSE_WIDTHS[_hash(wall[at], 31) % HOUSE_WIDTHS.size()]
		if at + width > last:
			break
		var cells: Array[Vector2i] = []
		for a: int in width:
			for d: int in HOUSE_DEPTH:
				cells.append(wall[at + a] + inward * d)
		var door: Vector2i = wall[at + width / 2] + inward * (HOUSE_DEPTH - 1)
		var ok: bool = true
		for cell: Vector2i in cells + [door + inward]:
			if castle.grow(1).has_point(cell) or _reserved.has(cell) or _gate(cell, side) or not _tile(cell) in [".", ":", "#"]:
				ok = false
				break
		if not ok:
			at += 1
			continue
		for cell: Vector2i in cells:
			var offset: Vector2i = cell - wall[at]
			var a: int = offset.x if side < 2 else offset.y
			var d: int = absi(offset.y) if side < 2 else absi(offset.x)
			_paint(cell, "#" if a == 0 or a == width - 1 or d == 0 or d == HOUSE_DEPTH - 1 else "=")
		_paint(door, "=")
		built += 1
		at += width + HOUSE_GAP
	# The street: up to RING - HOUSE_DEPTH tiles of meadow inside the houses.
	for step: int in range(HOUSE_DEPTH, mini(depth, RING)):
		for cell: Vector2i in wall:
			var street: Vector2i = cell + inward * step
			if (side < 2 or old.has_point(Vector2i(old.position.x, street.y))) and not castle.grow(1).has_point(street) \
					and _tile(street) in [".", ":"] and not _reserved.has(street):
				_paint(street, "=")
	return built


func _castle(rect: Rect2i) -> void:
	for y: int in CASTLE.size():
		for x: int in CASTLE[y].length():
			var mark: String = CASTLE[y][x]
			if mark != ".":
				_paint(rect.position + Vector2i(x, y), mark)
	# A cobbled way from the gate to the town.
	var gate := Vector2i(rect.end.x, rect.position.y + 9)
	while _tile(gate) in [".", ":", "T"] and not _reserved.has(gate):
		_paint(gate, "=")
		gate += Vector2i.RIGHT


# ---------------------------------------------------------------- countryside

## Coherent woods and meadows from the forest noise: trees clear where it is low or beside a road,
## and meadow grows into woodland where it is high (never on camps, roads, or markers). Returns
## the net trees removed.
func _thin_forest() -> int:
	var cleared: int = 0
	for cell: Vector2i in _layer.get_used_cells():
		var tile: String = _tile(cell)
		if not tile in [".", "T"] or not _countryside(cell):
			continue
		var wood: float = _noise(cell, 26.0, 3) * 0.65 + _noise(cell, 9.0, 4) * 0.23 + _noise(cell, 3.0, 6) * 0.12
		if tile == "T" and (wood < MEADOW_LEVEL or _near(cell, 2, "=")):
			_paint(cell, ".")
			cleared += 1
		elif tile == "." and wood > WOOD_LEVEL and _hash(cell, 5) % 100 < WOOD_DENSITY and not _near(cell, 2, "=,~b#:") \
				and not _near_camp(cell, 1):
			_paint(cell, "T")
			cleared -= 1
	return cleared


func _rock_site(cell: Vector2i) -> bool:
	return _tile(cell) == "." and _countryside(cell) and not _near(cell, 3, "=,~b#") and not _near_camp(cell, 2)


## Rock outcrops where the rock noise peaks, more in the highlands; loose wall bits outside
## towns become rock too.
func _outcrops() -> int:
	var changed: int = 0
	for cell: Vector2i in _layer.get_used_cells():
		if not _rock_site(cell):
			continue
		var level: float = HIGHLAND_ROCK_LEVEL if HIGHLANDS.has_point(cell) else ROCK_LEVEL
		if _noise(cell, 7.0, 11) > level and _hash(cell, 13) % 100 < 85:
			_paint(cell, "C")
			changed += 1
	var seen: Dictionary = {}
	for cell: Vector2i in _layer.get_used_cells():
		if seen.has(cell) or _tile(cell) != "#" or not _countryside(cell):
			continue
		var piece: Array[Vector2i] = [cell]
		seen[cell] = true
		var open: int = 0
		while open < piece.size():
			for side: Vector2i in SIDES:
				var next: Vector2i = piece[open] + side
				if not seen.has(next) and _tile(next) == "#":
					seen[next] = true
					piece.append(next)
			open += 1
		if piece.size() <= LOOSE_WALL and piece.all(_countryside):
			for part: Vector2i in piece:
				_paint(part, "C")
				changed += 1
	return changed


func _boulders() -> int:
	var placed: int = 0
	for cell: Vector2i in _layer.get_used_cells():
		if not WORLD.has_point(cell) or _tile(cell) != "." or not _countryside(cell) or _near(cell, 2, "=,~b") \
				or _near_camp(cell, 1):
			continue
		var by_rock: bool = _near(cell, 1, "C")
		if (by_rock and _hash(cell, 21) % 100 < BOULDERS_BY_ROCK) or _hash(cell, 22) % 1000 < BOULDERS_PER_THOUSAND:
			_paint(cell, "R")
			placed += 1
	return placed


## Dry-stone pastures on a town's outskirts: a walled field with a two-tile opening toward the town.
func _pastures(town: Rect2i) -> int:
	var built: int = 0
	var candidates: Array[Vector2i] = []
	for distance: int in [5, 9, 13]:
		var around: Rect2i = town.grow(distance)
		candidates.append_array([Vector2i(around.position.x - PASTURE_SIZE.x, around.position.y + 2),
			Vector2i(around.end.x, around.end.y - PASTURE_SIZE.y - 2), Vector2i(around.position.x + 3, around.end.y),
			Vector2i(around.end.x - PASTURE_SIZE.x - 3, around.position.y - PASTURE_SIZE.y)])
	for corner: Vector2i in candidates:
		if built >= PASTURES_PER_TOWN:
			break
		var field := Rect2i(corner, PASTURE_SIZE)
		var ok: bool = true
		for y: int in range(field.position.y - 1, field.end.y + 1):
			for x: int in range(field.position.x - 1, field.end.x + 1):
				var cell := Vector2i(x, y)
				if not _countryside(cell) or not _tile(cell) in [".", "T", "R"] or _near(cell, 1, "=,~bC") or _near_camp(cell, 2):
					ok = false
					break
			if not ok:
				break
		if not ok:
			continue
		var toward: Vector2i = (town.get_center() - field.get_center()).sign()
		for y: int in range(field.position.y, field.end.y):
			for x: int in range(field.position.x, field.end.x):
				var cell := Vector2i(x, y)
				var border: bool = x == field.position.x or x == field.end.x - 1 or y == field.position.y or y == field.end.y - 1
				var middle: Vector2i = field.get_center()
				var opening: bool = (toward.x != 0 and x == (field.position.x if toward.x < 0 else field.end.x - 1)
					and absi(y - middle.y) <= 1) or (toward.x == 0 and y == (field.position.y if toward.y < 0 else field.end.y - 1)
					and absi(x - middle.x) <= 1)
				_paint(cell, "#" if border and not opening else ".")
		built += 1
	return built


## The region of a tile as the game sees it: World samples Regions at the centre of 4x4 blocks.
static func _region(cell: Vector2i) -> String:
	var block: int = 4
	return Regions.name_at(Vector2i(cell.x / block * block + block / 2, cell.y / block * block + block / 2))


static func _cell_of(marker: Node2D) -> Vector2i:
	return Vector2i((marker.position / TILE).floor())
