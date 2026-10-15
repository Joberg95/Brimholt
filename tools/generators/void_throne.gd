extends SceneTree
## The Void Throne: the final boss room past the Hollow Sanctum. The Sanctum's throne room no
## longer holds Vaelith; a gateway stone stands there instead, and anyone may step through it
## (free, both ways, like a waystone) into an arena outside the overworld, beyond the dungeon
## band: a ring of obsidian around a dais, a level-50 full-loot PvP zone with Vaelith on the
## throne. The room is open to everyone, so a raid can wipe the raid that is fighting the boss
## and take the kill (Combat._award_trophies: only fighters alive and near the boss when it dies
## earn a trophy). Running again changes nothing.
##
##   godot --headless --path . --script res://tools/generators/void_throne.gd

const World = preload("res://game/core/world.gd")
const EndgameZone = preload("res://tools/generators/endgame_zone.gd")
const MONSTER_SCRIPT: Script = preload("res://game/maps/markers/monster_spawn.gd")
const FERRY_SCRIPT: Script = preload("res://game/maps/markers/ferryman.gd")
const ZONE_SCRIPT: Script = preload("res://game/maps/markers/zone.gd")
const SCENE_PATH: String = "res://game/maps/overworld.tscn"
const ZONE_NAME: String = "The Void Throne"
## Beyond the dungeon band (game/data/dungeons.gd), never reachable on foot.
const AREA: Rect2i = Rect2i(Vector2i(584, 6), Vector2i(36, 30))
const SEAT: Vector2i = AREA.position + Vector2i(18, 8)
const ARRIVAL: Vector2i = AREA.position + Vector2i(18, 26)
const GATE: Vector2i = EndgameZone.THRONE_SEAT
const AMBIENT: Color = Color(0.42, 0.32, 0.6)


func _initialize() -> void:
	var scene_root: Node = (load(SCENE_PATH) as PackedScene).instantiate()
	var changed: int = apply(scene_root)
	var error: Error = OK
	if changed > 0:
		var packed := PackedScene.new()
		packed.pack(scene_root)
		error = ResourceSaver.save(packed, SCENE_PATH)
	print("Built %s: %d changes in %s (%s)" % [ZONE_NAME, changed, SCENE_PATH, error_string(error)])
	scene_root.free()
	quit(0 if error == OK else 1)


## The arena's terrain: obsidian wall round the edge, a floor of obsidian flagstones with dusk
## soil worn into it, two rows of pillars, and the dais under the throne.
static func layout() -> Dictionary:
	var cells: Dictionary = {}
	for y: int in range(AREA.position.y, AREA.end.y):
		for x: int in range(AREA.position.x, AREA.end.x):
			var cell := Vector2i(x, y)
			var local: Vector2i = cell - AREA.position
			var edge: bool = local.x == 0 or local.y == 0 or local.x == AREA.size.x - 1 or local.y == AREA.size.y - 1
			var tile: String = "O" if edge else "o"
			if not edge and (local.x * 7 + local.y * 13) % 11 == 0:
				tile = "d"
			# Pillars down both sides of the hall.
			if local.x in [7, 28] and local.y % 5 == 3 and local.y < AREA.size.y - 4:
				tile = "O"
			cells[cell] = tile
	return cells


## Paints the arena, its zone, the gateway stones, and moves Vaelith; returns how many changes.
static func apply(scene_root: Node) -> int:
	var changed: int = 0
	var layer: TileMapLayer = scene_root.get_node("Terrain")
	var cells: Dictionary = layout()
	for cell: Vector2i in cells:
		var index: int = World.TERRAINS.find(cells[cell])
		if layer.get_cell_atlas_coords(cell).x != index:
			layer.set_cell(cell, 0, Vector2i(index, 0))
			changed += 1
	var spawns: Node = scene_root.get_node("MonsterSpawns")
	for marker: Node2D in spawns.get_children():
		if String(marker.get("monster")) == "vaelith" and not AREA.has_point(Vector2i(marker.position / World.TILE_SIZE)):
			spawns.remove_child(marker)
			marker.free()
			changed += 1
	if not spawns.has_node("VoidThroneVaelith"):
		var boss := Marker2D.new()
		boss.name = "VoidThroneVaelith"
		boss.set_script(MONSTER_SCRIPT)
		boss.position = (Vector2(SEAT) + Vector2(0.5, 0.5)) * World.TILE_SIZE
		boss.set("monster", "vaelith")
		boss.set("level", 50)
		boss.set("count", 1)
		boss.set("radius", 1)
		spawns.add_child(boss)
		boss.owner = scene_root
		changed += 1
	var zones: Node = scene_root.get_node("Zones")
	if not zones.has_node("VoidThrone"):
		var zone := Node2D.new()
		zone.name = "VoidThrone"
		zone.set_script(ZONE_SCRIPT)
		zone.position = Vector2(AREA.position) * World.TILE_SIZE
		zone.set("zone_name", ZONE_NAME)
		zone.set("size_tiles", AREA.size)
		zone.set("pvp", true)
		zone.set("full_loot", true)
		zone.set("ambient", AMBIENT)
		zone.set("min_level", 50)
		zone.set("max_level", 50)
		zones.add_child(zone)
		zone.owner = scene_root
		changed += 1
	var ferrymen: Node = scene_root.get_node("Ferrymen")
	for stone: Array in [["VoidGate", "The Void Gate", "Hollow Sanctum", GATE, "VoidThrone"],
			["VoidThrone", "The Void Gate", ZONE_NAME, ARRIVAL, "VoidGate"]]:
		if ferrymen.has_node(String(stone[0])):
			var placed: Node = ferrymen.get_node(String(stone[0]))
			if placed.get("vehicle") != "gate":
				placed.set("vehicle", "gate")
				changed += 1
			continue
		var marker := Marker2D.new()
		marker.name = stone[0]
		marker.set_script(FERRY_SCRIPT)
		marker.position = (Vector2(stone[3]) + Vector2(0.5, 0.5)) * World.TILE_SIZE
		marker.set("npc_name", stone[1])
		marker.set("place", stone[2])
		var routes: Dictionary[String, int] = {String(stone[4]): 0}
		marker.set("routes", routes)
		marker.set("vehicle", "gate")
		ferrymen.add_child(marker)
		marker.owner = scene_root
		changed += 1
	return changed
