extends "res://tools/generators/mainland.gd"
## The Grimtusk Hold: an orc fort in the woods east of the north road (between the Wolfholt and
## Kestrel Heights) and the orc camps round it. Rough stone walls round a dirt yard with a gate to
## the road, huts, a campfire and the shaman's cauldron, banners on the walls, and the warlord's
## great hut at the back. Camps rise in rings the way Tibia's orc fortress does: raiders and spear
## throwers (levels 10-14) in the woods round it, warriors and shamans (15-20) under the walls,
## berserkers and leaders (21-27) in the yard, and Warlord Gruzzak (30) in his hut. The rings take
## over the mainland camps (tools/generators/mainland.gd) that stood there.
##
## Runs once (scene metadata orc_hold); then make world-map.
##
##   godot --headless --path . --script res://tools/generators/orcs.gd

## The fort's walls (32 x 22), and the cell its rings are measured from.
const FORT: Rect2i = Rect2i(536, 236, 32, 22)
const HOLD_CENTRE: Vector2i = Vector2i(552, 247)
const INNER_RING: float = 40.0
const OUTER_RING: float = 80.0
## Huts (top-left relative to FORT, door side); the warlord's hut is HALL.
const HUTS: Array = [[Vector2i(3, 3), Vector2i.DOWN], [Vector2i(11, 3), Vector2i.DOWN], [Vector2i(3, 14), Vector2i.UP],
	[Vector2i(11, 14), Vector2i.UP]]
const HALL: Rect2i = Rect2i(19, 7, 9, 8)
## Camps in the fort: monster, level, count, radius, cell (relative to FORT).
const YARD_CAMPS: Array = [
	["green_gargoyle", 22, 5, 2, Vector2i(6, 10)], ["green_gargoyle", 23, 5, 2, Vector2i(24, 3)],
	["green_gargoyle", 26, 5, 2, Vector2i(24, 18)], ["green_gargoyle", 25, 5, 2, Vector2i(15, 10)],
	["gruzzak", 30, 1, 1, Vector2i(23, 11)],
]
## Decor (relative to FORT): furniture in the yard and the hall, banners and torches on the walls.
const FURNISHING: Array = [
	["hearth", Vector2i(9, 10)], ["cauldron", Vector2i(13, 11)], ["weapon_rack", Vector2i(2, 9)], ["weapon_rack", Vector2i(2, 12)],
	["barrel", Vector2i(1, 1)], ["barrel", Vector2i(2, 1)], ["crate", Vector2i(1, 2)], ["barrel", Vector2i(30, 20)],
	["crate", Vector2i(29, 20)], ["crate", Vector2i(30, 1)], ["barrel", Vector2i(1, 20)],
	["throne", Vector2i(25, 9)], ["chest", Vector2i(26, 12)], ["weapon_rack", Vector2i(21, 8)],
	["banner", Vector2i(6, 0)], ["banner", Vector2i(16, 0)], ["banner", Vector2i(25, 0)], ["banner", Vector2i(23, 7)],
	["wall_torch", Vector2i(0, 8)], ["wall_torch", Vector2i(0, 13)],
]
## The outer camps' monsters by ring: [monster, lowest level, highest level].
const INNER: Array = [["green_gargoyle", 15, 18], ["green_mage", 17, 20]]
const OUTER: Array = [["green_gargoyle", 10, 13], ["green_mage", 12, 14]]
const GATE_ROWS: Array[int] = [10, 11]


func _initialize() -> void:
	var scene_root: Node = MapIO.load_scene()
	var changed: int = apply(scene_root)
	var error: Error = OK
	if changed > 0:
		error = MapIO.save_scene(scene_root)
	print("Built the Grimtusk Hold: %d changes (%s)" % [changed, error_string(error)])
	MapIO.free_scene(scene_root)
	quit(0 if error == OK else 1)


func apply(scene_root: Node) -> int:
	if scene_root.has_meta("orc_hold"):
		return 0
	_root = scene_root
	_layer = scene_root.get_node(MapIO.TERRAIN)
	var changed: int = _fort()
	changed += _rings()
	scene_root.set_meta("orc_hold", true)
	return changed


## The walls, the yard, the gate and its path west to the road, the huts and hall, and the decor.
func _fort() -> int:
	var o: Vector2i = FORT.position
	for y: int in range(FORT.position.y - 3, FORT.end.y + 3):
		for x: int in range(FORT.position.x - 3, FORT.end.x + 3):
			var cell := Vector2i(x, y)
			if not FORT.has_point(cell):
				if _tile(cell) in ["T", "L", "~"]:
					_paint(cell, ".")
				continue
			var edge: bool = x == FORT.position.x or y == FORT.position.y or x == FORT.end.x - 1 or y == FORT.end.y - 1
			_paint(cell, "#" if edge else ("." if _hash(cell, SALT + 91) % 5 == 0 else ","))
	# The gate, and a dirt path from it west to the north road.
	for row: int in GATE_ROWS:
		var cell: Vector2i = o + Vector2i(0, row)
		_paint(cell, ",")
		cell += Vector2i.LEFT
		while _tile(cell) != "," and cell.x > o.x - 40:
			_paint(cell, "b" if _tile(cell) == "~" else ",")
			cell += Vector2i.LEFT
	var changed: int = FORT.size.x * FORT.size.y
	for hut: Array in HUTS:
		changed += _house(o + hut[0], Vector2i(6, 5), hut[1])
	changed += _house(o + HALL.position, HALL.size, Vector2i.LEFT)
	for entry: Array in FURNISHING:
		_decor(entry[0], o + entry[1])
	for entry: Array in YARD_CAMPS:
		_camp("Grimtusk_%d" % YARD_CAMPS.find(entry), entry[0], entry[1], entry[2], entry[3], o + entry[4])
	return changed + FURNISHING.size() + YARD_CAMPS.size()


## The mainland camps round the hold become orc camps (warriors and shamans within INNER_RING,
## raiders and spear throwers out to OUTER_RING); any that stood where the fort is now go.
func _rings() -> int:
	var changed: int = 0
	for marker: Node2D in _group("MonsterSpawns").get_children():
		if not String(marker.name).begins_with("Mainland_"):
			continue
		var cell := Vector2i((marker.position / TILE).floor())
		if FORT.grow(3).has_point(cell):
			marker.get_parent().remove_child(marker)
			marker.free()
			changed += 1
			continue
		var distance: float = Vector2(cell).distance_to(Vector2(HOLD_CENTRE))
		if distance > OUTER_RING:
			continue
		var ring: Array = INNER if distance < INNER_RING else OUTER
		var pick: Array = ring[_hash(cell, SALT + 93) % ring.size()]
		marker.set("monster", pick[0])
		marker.set("level", int(pick[1]) + _hash(cell, SALT + 97) % (int(pick[2]) - int(pick[1]) + 1))
		changed += 1
	return changed


func _camp(marker_name: String, monster: String, level: int, count: int, radius: int, cell: Vector2i) -> void:
	var marker := Marker2D.new()
	marker.name = marker_name
	marker.set_script(SPAWN_SCRIPT)
	marker.position = (Vector2(cell) + Vector2(0.5, 0.5)) * TILE
	marker.set("monster", monster)
	marker.set("level", level)
	marker.set("count", count)
	marker.set("radius", radius)
	_group("MonsterSpawns").add_child(marker)
	marker.owner = _root
