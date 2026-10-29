extends SceneTree
## Puts every town's vendor and artisan (and the one banker, in BANK_PLACE, and the PvP warden) inside a building of their own,
## in the existing overworld scene, and removes bankers from other towns. Buildings are found
## from the walls (game/data/buildings.gd); the patches below add the buildings a town lacks:
## Cinder Crossing's shop and a second house, and Reedmere's bank. Each keeper stands at the back of their building, facing the door; the
## game hangs a sign beside that door (WorldMap.SIGNS) and draws roofs over every building.
##
##   godot --headless --path . --script res://tools/generators/towns.gd
##
## tools/generators/make_map.gd applies the same painter to a freshly generated map. Running
## it again changes nothing.

const Buildings = preload("res://game/data/buildings.gd")
## Must match WorldMap.TERRAINS (the rules check verifies it). World itself is not loaded here
## because its static map loading needs the scene this tool is editing.
const TERRAINS: String = ".,~#T:=bdoODcCv^KRLWmUsPFY"
const MapIO = preload("res://game/maps/map_io.gd")
const SCENE_PATH: String = "res://game/maps/overworld.tscn"
## The only town with a banker (and so the only bank and depot).
const BANK_PLACE: String = "Reedmere"
const TILE: int = 32
const QUEST_SCRIPT: Script = preload("res://game/maps/markers/quest_giver.gd")
const TOWNSFOLK_SCRIPT: Script = preload("res://game/maps/markers/townsfolk.gd")
## Artisans (World role "artisan", service "craft"): one per town, in a free building of their
## own like the vendors, with a workshop (WorldMap.FURNISHINGS): node name, display name, town.
const ARTISANS: Array = [
	["artisan_cinder", "Artisan Brenna", "Cinder Crossing"],
	["artisan_lastlight", "Artisan Odo", "Lastlight"],
	["artisan_reedmere", "Guildmistress Talia", "Reedmere"],
	["artisan_ashford", "Artisan Corwen", "Ashford"],
	["artisan_emberfall", "Artisan Hild", "Emberfall"],
	["artisan_dunmere", "Artisan Maelis", "Dunmere"],
	["artisan_highmoor", "Artisan Torvald", "Highmoor"],
	["artisan_hrimvik", "Ropewright Ingvar", "Hrimvik"],
]
## The PvP warden (World role "warden", service "pvp"; Combat.set_pvp): node name, display name, town.
const WARDENS: Array = [["reedmere_warden", "Warden Kessa", "Reedmere"]]
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
	["sergeant_brenna", "Sergeant Brenna", "Aldmoor", Vector2i(806, 156), Vector2i.LEFT],
	# Brackenford's square: the Grimtusk Hold's tasks (tools/generators/orcs.gd).
	["scout_rhydda", "Scout Rhydda", "Brackenford", Vector2i(520, 510), Vector2i.LEFT],
	["trapper_maud", "Trapper Maud", "Thornfield Wilds", Vector2i(85, 165), Vector2i.LEFT],
	# Quest hubs: one giver per hunting band, on the plaza of the town nearest its monsters.
	["harbourmaster_ilse", "Harbourmaster Ilse", "Cinder Crossing", Vector2i(33, 48), Vector2i.UP],
	["fenwarden_ostrel", "Fenwarden Ostrel", "Reedmere", Vector2i(146, 196), Vector2i.UP],
	# The Hunters' Lodge chain (Quests "hunters_lodge") starts and ends here, in the capital.
	["lodgemaster_varga", "Lodgemaster Varga", "Reedmere", Vector2i(140, 196), Vector2i.UP],
	["quartermaster_rhosyn", "Quartermaster Rhosyn", "Dunmere", Vector2i(192, 271), Vector2i.RIGHT],
	["huntmaster_corvel", "Huntmaster Corvel", "Emberfall", Vector2i(286, 200), Vector2i.RIGHT],
	# More hunting hubs for the twenties: the lake shore, the desert and quarries, the downs.
	["ranger_aldric", "Ranger Aldric", "Reedmere", Vector2i(117, 191), Vector2i.DOWN],
	["caravan_master_idris", "Caravan master Idris", "Dunmere", Vector2i(200, 264), Vector2i.DOWN],
	["skywatch_mera", "Skywatch Mera", "Lastlight", Vector2i(36, 350), Vector2i.DOWN],
	# The elite caves (game/data/caves.gd): one giver per cave in the town nearest its mouth.
	["delver_hask", "Delver Hask", "Highmoor", Vector2i(326, 89), Vector2i.DOWN],
	["icewarden_sigrun", "Icewarden Sigrun", "Highmoor", Vector2i(334, 89), Vector2i.DOWN],
	["watchman_brega", "Watchman Brega", "Highmoor", Vector2i(330, 90), Vector2i.DOWN],
	["tidewarden_neve", "Tidewarden Neve", "Emberfall", Vector2i(284, 192), Vector2i.DOWN],
	["forgewarden_kel", "Forgewarden Kel", "Dunmere", Vector2i(196, 272), Vector2i.UP],
	# The frost isles: Hrimvik's square (tools/generators/frost_isles.gd).
	["huntswoman_eyra", "Huntswoman Eyra", "Hrimvik", Vector2i(75, 745), Vector2i.DOWN],
	["trenchwarden_olav", "Trenchwarden Olav", "Hrimvik", Vector2i(79, 745), Vector2i.DOWN],
	# Cinder Crossing's training hall (its old bank house): the trial master by the door, and
	# one vocation trainer in each corner (Quests.TRAINERS).
	["trial_master", "Master Hesk", "Cinder Crossing", Vector2i(21, 12), Vector2i.DOWN],
	["trainer_knight", "Sir Garrow", "Cinder Crossing", Vector2i(18, 14), Vector2i.RIGHT],
	["trainer_paladin", "Ranger Tamsin", "Cinder Crossing", Vector2i(22, 14), Vector2i.LEFT],
	["trainer_sorcerer", "Magister Vell", "Cinder Crossing", Vector2i(18, 16), Vector2i.RIGHT],
	["trainer_druid", "Elder Fenna", "Cinder Crossing", Vector2i(22, 16), Vector2i.LEFT],
]
## Ground a quest giver may stand on.
const STANDING: String = ".,:=F"
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
	# Silkhollow's cave mouth in Thornfield Wilds: a ring of cave rock, open to the south and
	# south-east, around the stairway (painted by dungeons.gd at Dungeons.DUNGEONS["silkhollow"]
	# ["entrance"]), in a small clearing where the trail from the coast road (silkhollow.gd)
	# arrives. No rock stands east or south of the stairway: it would lean over the hole.
	[Vector2i(79, 161), [
		"   .....  ",
		"   .CCC.  ",
		"  .CC .C. ",
		"  ,C,..C. ",
		",,,,,.....",
		"..........",
		" ........ ",
		"  ......  ",
	]],
]
## Marker groups that must never end up inside a wall.
const MARKER_GROUPS: Array[String] = ["Spawns", "Items", "Ferrymen", "QuestGivers", "DungeonEntrances", "MonsterSpawns"]


func _initialize() -> void:
	var scene_root: Node = MapIO.load_scene()
	var changed: int = apply(scene_root)
	var error: Error = OK
	if changed >= 0:
		error = MapIO.save_scene(scene_root)
	print("Painted the towns into %s: %d changes (%s)" % [SCENE_PATH, changed, error_string(error)])
	MapIO.free_scene(scene_root)
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
				# Castle walls (castle_town.gd) stand in for a patch's town walls.
				if row[x] == " " or _terrain(layer, cell) == row[x] or (row[x] == "#" and _terrain(layer, cell) == "W"):
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
	var added: int = _add_keepers(scene_root)
	if added < 0:
		return -1
	changed += added
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


## Creates missing ARTISANS and WARDENS markers inside their town (the keeper pass then moves
## them into a free building); -1 when a town is unknown.
static func _add_keepers(scene_root: Node) -> int:
	var group: Node = scene_root.get_node("Townsfolk")
	var towns: Dictionary = {}
	for zone: Node2D in scene_root.get_node("Zones").get_children():
		if bool(zone.get("town")):
			towns[String(zone.get("zone_name"))] = Rect2i(_cell_of_corner(zone), zone.get("size_tiles"))
	var changed: int = 0
	for entry: Array in ARTISANS.map(func(row: Array) -> Array: return row + ["artisan"]) \
			+ WARDENS.map(func(row: Array) -> Array: return row + ["warden"]):
		if group.has_node(String(entry[0])):
			continue
		if not towns.has(entry[2]):
			push_error("%s has no town %s" % [entry[1], entry[2]])
			return -1
		var marker := Marker2D.new()
		marker.name = String(entry[0])
		marker.set_script(TOWNSFOLK_SCRIPT)
		group.add_child(marker)
		marker.owner = scene_root
		marker.position = Vector2((Vector2(towns[entry[2]].get_center()) + Vector2(0.5, 0.5)) * TILE)
		marker.set("npc_name", entry[1])
		marker.set("place", entry[2])
		marker.set("role", entry[3])
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
