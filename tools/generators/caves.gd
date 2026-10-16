extends "res://tools/generators/landscape.gd"
## Paints the elite caves (game/data/caves.gd) into the band beyond the Void Throne and opens a
## mouth for each in its region. A cave is cave rock ("C") carved into wide halls ("c", ragged
## ellipses) joined by winding tunnels: a spanning tree between the halls plus a couple of loops,
## so there is more than one way round. The westmost hall holds the stairs up ("^"); the halls
## further from it (counted along the tunnels) hold later camps, and the deepest the champion.
## The mouth ("v", a CaveMouths marker) opens on open ground of the cave's region that players
## reach on foot, as near to the cave's "near" cell as fits, clear of camps and roads.
##
## Terrain is repainted the same way every run; camps ("Cave_<cave>_<n>" spawn markers) and
## mouths that already exist keep their places (move them in Godot), and camps take their
## monster, level, and size from the table, so running again changes nothing.
##
##   godot --headless --path . --script res://tools/generators/caves.gd

const Caves = preload("res://game/data/caves.gd")
const SPAWN_SCRIPT: Script = preload("res://game/maps/markers/monster_spawn.gd")
const MOUTH_SCRIPT: Script = preload("res://game/maps/markers/cave_mouth.gd")
const WALKABLE: String = ".,:=bdocv^ms"
## Rock kept round the edge, the gap between hall centres, and the halls' half sizes.
const MARGIN: int = 6
const HALL_GAP: float = 11.0
const HALL_RADIUS: Vector2i = Vector2i(5, 4)
const HALL_SPREAD: Vector2i = Vector2i(2, 1)
## Tunnels between halls that are not in the spanning tree, for loops.
const LOOPS: int = 2
## Cells kept clear round a mouth: open ground, and distance from camps and roads.
const MOUTH_CLEAR: int = 4


func _initialize() -> void:
	var scene_root: Node = (load(SCENE_PATH) as PackedScene).instantiate()
	_prepare(scene_root)
	var changed: int = 0
	var spawns: Node = scene_root.get_node("MonsterSpawns")
	var mouths: Node = scene_root.get_node_or_null("CaveMouths")
	if mouths == null:
		mouths = Node2D.new()
		mouths.name = "CaveMouths"
		scene_root.add_child(mouths)
		mouths.owner = scene_root
		changed += 1
	var reached: Dictionary = {}
	var starts: Array[Vector2i] = []
	# From the player spawns, and from every port (the frost isles are reached by boat).
	for group: String in ["Spawns", "Ferrymen"]:
		for marker: Node2D in scene_root.get_node(group).get_children():
			starts.append(_cell_of(marker))
	_flood(starts, WALKABLE, reached)
	var missing: PackedStringArray = []
	for cave: String in Caves.ORDER:
		var halls: Array = _carve(cave)
		changed += halls.size()
		changed += _place_camps(scene_root, spawns, cave, halls)
		var name: String = cave.to_pascal_case()
		if mouths.has_node(name):
			_paint(_cell_of(mouths.get_node(name)), "v")
			continue
		var spot: Vector2i = _mouth_spot(cave, reached)
		if spot.x < 0:
			missing.append(cave)
			continue
		_paint(spot, "v")
		var marker := Marker2D.new()
		marker.name = name
		marker.set_script(MOUTH_SCRIPT)
		marker.position = Vector2(spot * TILE) + Vector2.ONE * TILE / 2.0
		marker.set("cave", cave)
		mouths.add_child(marker)
		marker.owner = scene_root
		changed += 1
	var packed := PackedScene.new()
	packed.pack(scene_root)
	var error: Error = ResourceSaver.save(packed, SCENE_PATH)
	print("Painted %d elite caves (%d halls, camps, and mouths) into %s (%s)%s" % [Caves.ORDER.size(), changed, SCENE_PATH, error_string(error),
		"" if missing.is_empty() else "; no room for the mouth of " + ", ".join(missing)])
	scene_root.free()
	quit(0 if error == OK and missing.is_empty() else 1)


## Carves the cave's rock; returns its halls [{centre, radius, depth}], the stairs' hall first.
func _carve(cave: String) -> Array:
	var area: Rect2i = Caves.rect(cave)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cave)
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			_paint(Vector2i(x, y), "C")
	var halls: Array = []
	var tries: int = 0
	while halls.size() < Caves.CAVES[cave]["halls"] and tries < 4000:
		tries += 1
		var centre := Vector2i(rng.randi_range(area.position.x + MARGIN, area.end.x - MARGIN - 1),
			rng.randi_range(area.position.y + MARGIN, area.end.y - MARGIN - 1))
		if halls.any(func(hall: Dictionary) -> bool: return Vector2(hall["centre"]).distance_to(Vector2(centre)) < HALL_GAP):
			continue
		halls.append({"centre": centre, "radius": HALL_RADIUS + Vector2i(rng.randi_range(0, HALL_SPREAD.x),
			rng.randi_range(0, HALL_SPREAD.y)), "depth": 0})
	halls.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["centre"].x < b["centre"].x)
	for hall: Dictionary in halls:
		_carve_hall(hall, area)
	# Prim's spanning tree from the stairs' hall, then the shortest edges left over as loops.
	var linked: Array[int] = [0]
	var edges: Array = []
	var spare: Array = []
	while linked.size() < halls.size():
		var best: Array = []
		for from: int in linked:
			for to: int in halls.size():
				if to in linked:
					continue
				var length: float = Vector2(halls[from]["centre"]).distance_to(Vector2(halls[to]["centre"]))
				if best.is_empty() or length < best[2]:
					best = [from, to, length]
		linked.append(best[1])
		edges.append(best)
	for from: int in halls.size():
		for to: int in range(from + 1, halls.size()):
			if not edges.any(func(edge: Array) -> bool: return (edge[0] == from and edge[1] == to) or (edge[0] == to and edge[1] == from)):
				spare.append([from, to, Vector2(halls[from]["centre"]).distance_to(Vector2(halls[to]["centre"]))])
	spare.sort_custom(func(a: Array, b: Array) -> bool: return a[2] < b[2])
	for edge: Array in edges + spare.slice(0, LOOPS):
		_carve_tunnel(halls[edge[0]]["centre"], halls[edge[1]]["centre"], area, rng)
	# Depth: tunnel hops from the stairs' hall along the tree.
	var depth: Dictionary = {0: 0}
	var queue: Array[int] = [0]
	while not queue.is_empty():
		var at: int = queue.pop_front()
		for edge: Array in edges:
			for pair: Array in [[edge[0], edge[1]], [edge[1], edge[0]]]:
				if pair[0] == at and not depth.has(pair[1]):
					depth[pair[1]] = depth[at] + 1
					queue.append(pair[1])
	for index: int in halls.size():
		halls[index]["depth"] = depth[index] * 1000 + int(Vector2(halls[index]["centre"]).distance_to(Vector2(halls[0]["centre"])))
	_paint(halls[0]["centre"], "^")
	return halls


## A ragged ellipse of cave floor.
func _carve_hall(hall: Dictionary, area: Rect2i) -> void:
	var radius: Vector2i = hall["radius"]
	for dy: int in range(-radius.y - 1, radius.y + 2):
		for dx: int in range(-radius.x - 1, radius.x + 2):
			var cell: Vector2i = hall["centre"] + Vector2i(dx, dy)
			var reach: float = pow(float(dx) / radius.x, 2.0) + pow(float(dy) / radius.y, 2.0)
			if reach <= 0.85 + 0.3 * _noise(cell, 3.0, 81) and area.grow(-2).has_point(cell):
				_paint(cell, "c")


## A winding tunnel two to three cells wide.
func _carve_tunnel(from: Vector2i, to: Vector2i, area: Rect2i, rng: RandomNumberGenerator) -> void:
	var at: Vector2i = from
	var steps: int = 0
	while at != to and steps < 400:
		steps += 1
		var offset: Vector2i = to - at
		var horizontal: bool = absi(offset.x) > absi(offset.y)
		if rng.randf() < 0.3:
			horizontal = not horizontal
		var step: Vector2i = Vector2i(signi(offset.x), 0) if horizontal else Vector2i(0, signi(offset.y))
		if step == Vector2i.ZERO:
			step = Vector2i(signi(offset.x), signi(offset.y))
		at += step
		var width: int = 1 if rng.randf() < 0.6 else 0
		for dy: int in range(-1, width + 1):
			for dx: int in range(-1, width + 1):
				if area.grow(-2).has_point(at + Vector2i(dx, dy)):
					_paint(at + Vector2i(dx, dy), "c")


## Spawn markers for the camps, shallow camps in shallow halls; returns how many were added or changed.
func _place_camps(scene_root: Node, spawns: Node, cave: String, halls: Array) -> int:
	var definition: Dictionary = Caves.CAVES[cave]
	var order: Array = halls.slice(1)
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["depth"] < b["depth"])
	var plan: Array = []
	if definition.has("champion"):
		var deepest: Dictionary = order.pop_back()
		plan.append([deepest, definition["champion"][0], definition["champion"][1], 1])
	var rows: Array = definition["camps"]
	var row_of: Array[int] = []
	for index: int in order.size():
		row_of.append(mini(rows.size() - 1, index * rows.size() / order.size()))
	for index: int in order.size():
		var row: int = row_of[index]
		var first: int = row_of.find(row)
		var last: int = row_of.rfind(row)
		var share: float = 0.0 if last == first else float(index - first) / float(last - first)
		var camp: Array = rows[row]
		plan.append([order[index], camp[0], camp[1] + roundi(share * (camp[2] - camp[1])), camp[3]])
	var added: int = 0
	for index: int in plan.size():
		var entry: Array = plan[index]
		var name: String = "Cave_%s_%d" % [cave, index + 1]
		var hall: Dictionary = entry[0]
		var marker: Node2D = spawns.get_node_or_null(name)
		if marker == null:
			marker = Marker2D.new()
			marker.name = name
			marker.set_script(SPAWN_SCRIPT)
			spawns.add_child(marker)
			marker.owner = scene_root
			marker.position = Vector2(hall["centre"] * TILE) + Vector2.ONE * TILE / 2.0
			added += 1
		# An existing camp keeps its place but follows the cave's table.
		var stats: Dictionary = {"monster": entry[1], "level": entry[2], "count": entry[3],
			"radius": 1 if entry[3] == 1 else mini(mini(hall["radius"].x, hall["radius"].y) - 1, 3)}
		for key: String in stats:
			if marker.get(key) != stats[key]:
				marker.set(key, stats[key])
				added += 1
	return added


## Open ground in the cave's region that players reach, nearest its "near" cell; (-1, -1) if none.
func _mouth_spot(cave: String, reached: Dictionary) -> Vector2i:
	var definition: Dictionary = Caves.CAVES[cave]
	var best := Vector2i(-1, -1)
	for cell: Vector2i in reached:
		if not _countryside(cell) or _region(cell) != definition["region"] or _tile(cell) not in ".:ms" \
				or _near_camp(cell, MOUTH_CLEAR) or _near(cell, 2, ",=b~"):
			continue
		var open: bool = true
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				open = open and _tile(cell + Vector2i(dx, dy)) in ".:ms"
		if open and (best.x < 0 or Vector2(cell).distance_to(Vector2(definition["near"]))
				< Vector2(best).distance_to(Vector2(definition["near"]))):
			best = cell
	return best
