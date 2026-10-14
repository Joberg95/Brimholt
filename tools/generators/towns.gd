extends SceneTree
## Puts every town's vendor (and the one banker, in BANK_PLACE) inside a building of their own,
## in the existing overworld scene, and removes bankers from other towns. Buildings are found
## from the walls (game/data/buildings.gd); the patches below add the buildings a town lacks:
## Cinder Crossing's shop and a second house, and Reedmere's bank. Each keeper stands at the back of their building, facing the door; the
## game hangs a sign beside that door (World.SIGNS) and draws roofs over every building.
##
##   godot --headless --path . --script res://tools/generators/towns.gd
##
## tools/generators/make_map.gd applies the same painter to a freshly generated map. Running
## it again changes nothing.

const Buildings = preload("res://game/data/buildings.gd")
## Must match World.TERRAINS (the rules check verifies it). World itself is not loaded here
## because its static map loading needs the scene this tool is editing.
const TERRAINS: String = ".,~#T:=bdoODcCv^KR"
const SCENE_PATH: String = "res://game/maps/overworld.tscn"
## The only town with a banker (and so the only bank and depot).
const BANK_PLACE: String = "Reedmere"
const TILE: int = 32
const QUEST_SCRIPT: Script = preload("res://game/maps/markers/quest_giver.gd")
## Quest givers this painter places (or moves): node name, display name, place, cell, facing.
## Relic keepers (one per final boss, game/data/quests.gd RELIC_KEEPERS) stand in the corners of
## Reedmere's north plaza (far enough apart that their names do not overlap), the town at the middle of the world; dungeon task givers stand by their stairway.
const QUEST_GIVERS: Array = [
	["relic_keeper", "Ysolde", "Reedmere", Vector2i(148, 187), Vector2i.DOWN],
	["relic_keeper_kharzul", "Brannoc the Forgemaster", "Reedmere", Vector2i(152, 187), Vector2i.DOWN],
	["relic_keeper_sylvaine", "Liraen of the Thorn", "Reedmere", Vector2i(148, 190), Vector2i.RIGHT],
	["relic_keeper_vaelith", "Oswin the Ashen", "Reedmere", Vector2i(152, 190), Vector2i.LEFT],
	["cellarmaster_pell", "Cellarmaster Pell", "Cinder Crossing", Vector2i(15, 5), Vector2i.DOWN],
	["sexton_wren", "Sexton Wren", "Ashford", Vector2i(189, 127), Vector2i.RIGHT],
	["foreman_dagny", "Foreman Dagny", "Highmoor", Vector2i(337, 75), Vector2i.RIGHT],
	["trapper_maud", "Trapper Maud", "Thornfield Wilds", Vector2i(85, 165), Vector2i.LEFT],
	# Quest hubs: one giver per hunting band, on the plaza of the town nearest its monsters.
	["harbourmaster_ilse", "Harbourmaster Ilse", "Cinder Crossing", Vector2i(33, 48), Vector2i.UP],
	["fenwarden_ostrel", "Fenwarden Ostrel", "Reedmere", Vector2i(146, 196), Vector2i.UP],
	["quartermaster_rhosyn", "Quartermaster Rhosyn", "Dunmere", Vector2i(192, 271), Vector2i.RIGHT],
	["huntmaster_corvel", "Huntmaster Corvel", "Emberfall", Vector2i(286, 200), Vector2i.RIGHT],
	# Cinder Crossing's training hall (its old bank house): the trial master by the door, and
	# one vocation trainer in each corner (Quests.TRAINERS).
	["trial_master", "Master Hesk", "Cinder Crossing", Vector2i(21, 12), Vector2i.DOWN],
	["trainer_knight", "Sir Garrow", "Cinder Crossing", Vector2i(18, 14), Vector2i.RIGHT],
	["trainer_paladin", "Ranger Tamsin", "Cinder Crossing", Vector2i(22, 14), Vector2i.LEFT],
	["trainer_sorcerer", "Magister Vell", "Cinder Crossing", Vector2i(18, 16), Vector2i.RIGHT],
	["trainer_druid", "Elder Fenna", "Cinder Crossing", Vector2i(22, 16), Vector2i.LEFT],
]
## Ground a quest giver may stand on.
const STANDING: String = ".,:="
## Terrain patches: top-left cell and rows; a space keeps the cell as it is.
const PATCHES: Array = [
	# Cinder Crossing's shop in the south-west corner of the town walls, door to the east.
	[Vector2i(0, 11), [
		"#######",
		"#=====#",
		"#=====#",
		"#======",
		"#=====#",
		"#=====#",
		"#######",
	]],
	# Cinder Crossing's training hall in the south-east corner (its bank before banking moved to Reedmere).
	[Vector2i(17, 13), [
		"##=####",
		"#=====#",
		"#=====#",
		"#=====#",
		"#######",
	]],
	# Reedmere's bank on the south side of the plaza, east of the coachman.
	[Vector2i(148, 197), [
		"##=##",
		"#===#",
		"#===#",
		"#===#",
		"#####",
	]],
	# Silkhollow's cave mouth in Thornfield Wilds: a ring of cave rock, open to the south, around
	# the stairway (painted by dungeons.gd at Dungeons.DUNGEONS["silkhollow"]["entrance"]), in a
	# small clearing.
	[Vector2i(79, 161), [
		"   .....  ",
		"   .CCC.  ",
		"  .CC CC. ",
		"  .C...C. ",
		"..........",
		"..........",
		" ........ ",
		"  ......  ",
	]],
]
## Marker groups that must never end up inside a wall.
const MARKER_GROUPS: Array[String] = ["Spawns", "Items", "Ferrymen", "QuestGivers", "DungeonEntrances", "MonsterSpawns"]


func _initialize() -> void:
	var scene_root: Node = (load(SCENE_PATH) as PackedScene).instantiate()
	var changed: int = apply(scene_root)
	var error: Error = OK
	if changed >= 0:
		var packed := PackedScene.new()
		packed.pack(scene_root)
		error = ResourceSaver.save(packed, SCENE_PATH)
	print("Painted the towns into %s: %d changes (%s)" % [SCENE_PATH, changed, error_string(error)])
	scene_root.free()
	quit(0 if error == OK and changed >= 0 else 1)


## Paints the patches and moves the keepers in an overworld scene root; returns the number of
## changed cells and markers, or -1 (with an error) when a town cannot be furnished.
static func apply(scene_root: Node) -> int:
	var layer: TileMapLayer = scene_root.get_node("Terrain")
	var blocked: Dictionary = {}
	for group: String in MARKER_GROUPS:
		if scene_root.has_node(group):
			for marker: Node2D in scene_root.get_node(group).get_children():
				blocked[_cell_of(marker)] = String(marker.name)
	var changed: int = 0
	for patch: Array in PATCHES:
		for y: int in patch[1].size():
			var row: String = patch[1][y]
			for x: int in row.length():
				var cell: Vector2i = patch[0] + Vector2i(x, y)
				if row[x] == " " or _terrain(layer, cell) == row[x]:
					continue
				if row[x] == "#" and blocked.has(cell):
					push_error("Town patch would wall in %s at %s" % [blocked[cell], cell])
					return -1
				layer.set_cell(cell, 0, Vector2i(TERRAINS.find(row[x]), 0))
				changed += 1
	var placed: int = _place_quest_givers(scene_root, layer, blocked)
	if placed < 0:
		return -1
	changed += placed
	var terrain: Callable = func(cell: Vector2i) -> String: return _terrain(layer, cell)
	var keepers: Array = []
	if scene_root.has_node("Townsfolk"):
		for keeper: Node2D in scene_root.get_node("Townsfolk").get_children():
			if String(keeper.get("role")) == "banker" and String(keeper.get("place")) != BANK_PLACE:
				keeper.get_parent().remove_child(keeper)
				keeper.free()
				changed += 1
			else:
				keepers.append(keeper)
	var others: Dictionary = {}
	for group: String in ["QuestGivers", "Ferrymen"]:
		if scene_root.has_node(group):
			for marker: Node2D in scene_root.get_node(group).get_children():
				others[_cell_of(marker)] = true
	for zone: Node2D in scene_root.get_node("Zones").get_children():
		if not bool(zone.get("town")):
			continue
		var rect := Rect2i(_cell_of_corner(zone), zone.get("size_tiles"))
		var free: Array = []
		for building: Dictionary in Buildings.find(terrain, rect.grow(1)):
			if not building["interior"].any(func(cell: Vector2i) -> bool: return _terrain(layer, cell) == "v" or others.has(cell)):
				free.append(building)
		free.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a["rect"].position.y < b["rect"].position.y or (a["rect"].position.y == b["rect"].position.y
				and a["rect"].position.x < b["rect"].position.x))
		var here: Array = keepers.filter(func(keeper: Node2D) -> bool: return rect.has_point(_cell_of(keeper)))
		if free.size() < here.size():
			push_error("%s needs a free building for each of its keepers" % zone.get("zone_name"))
			return -1
		# A keeper already inside a free building stays; the rest take the next unclaimed one
		# (vendors from the north-west, the banker from the south-east). Each building holds one.
		var claimed: Dictionary = {}
		var homes: Dictionary = {}
		for keeper: Node2D in here:
			for index: int in free.size():
				if not claimed.has(index) and free[index]["interior"].has(_cell_of(keeper)):
					claimed[index] = true
					homes[keeper] = free[index]
		for keeper: Node2D in here:
			if homes.has(keeper):
				continue
			var order: Array = range(free.size()) if String(keeper.get("role")) == "vendor" else range(free.size() - 1, -1, -1)
			for index: int in order:
				if not claimed.has(index):
					claimed[index] = true
					homes[keeper] = free[index]
					break
		for keeper: Node2D in here:
			var building: Dictionary = homes[keeper]
			var door: Vector2i = building["doors"][0]
			var outward: Vector2i = building["outward"][door]
			var spot: Vector2i = door - outward
			while building["interior"].has(spot - outward):
				spot -= outward
			var position := Vector2((Vector2(spot) + Vector2(0.5, 0.5)) * TILE)
			if keeper.position != position or keeper.get("facing") != outward:
				keeper.position = position
				keeper.set("facing", outward)
				changed += 1
	return changed


## Creates missing QUEST_GIVERS markers and moves existing ones into place; -1 on a bad cell.
static func _place_quest_givers(scene_root: Node, layer: TileMapLayer, blocked: Dictionary) -> int:
	var changed: int = 0
	var group: Node = scene_root.get_node("QuestGivers")
	# Givers this painter places may swap tiles; only other markers block them.
	var placing: Array = QUEST_GIVERS.map(func(entry: Array) -> String: return entry[0])
	for cell: Vector2i in blocked.keys():
		if blocked[cell] in placing:
			blocked.erase(cell)
	for entry: Array in QUEST_GIVERS:
		var cell: Vector2i = entry[3]
		var marker: Node2D = group.get_node_or_null(String(entry[0]))
		var other: String = blocked.get(cell, "")
		if not _terrain(layer, cell) in STANDING or _terrain(layer, cell).is_empty() or (not other.is_empty() and other != entry[0]):
			push_error("%s cannot stand at %s" % [entry[1], cell])
			return -1
		if marker == null:
			marker = Marker2D.new()
			marker.name = String(entry[0])
			marker.set_script(QUEST_SCRIPT)
			group.add_child(marker)
			marker.owner = scene_root
		var position := Vector2((Vector2(cell) + Vector2(0.5, 0.5)) * TILE)
		if marker.position != position or marker.get("facing") != entry[4] or marker.get("npc_name") != entry[1] \
				or marker.get("place") != entry[2]:
			marker.position = position
			marker.set("facing", entry[4])
			marker.set("npc_name", entry[1])
			marker.set("place", entry[2])
			changed += 1
		blocked[cell] = String(entry[0])
	return changed


static func _terrain(layer: TileMapLayer, cell: Vector2i) -> String:
	var coords: Vector2i = layer.get_cell_atlas_coords(cell)
	return TERRAINS[coords.x] if coords.x >= 0 and coords.x < TERRAINS.length() else ""


static func _cell_of(marker: Node2D) -> Vector2i:
	return Vector2i((marker.position / TILE).floor())


static func _cell_of_corner(zone: Node2D) -> Vector2i:
	return Vector2i((zone.position / TILE).round())
