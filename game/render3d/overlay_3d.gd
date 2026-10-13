extends Control
## The unlit layer over the 3D view (the 3D twin of world_overlay.gd): your target's square,
## nameplates over players and monsters, NPC names with quest marks, missiles, and floating
## numbers, each projected from the 3D world so they stay readable at any zoom and at night.

const World = preload("res://game/core/world.gd")
const Monsters = preload("res://game/data/monsters.gd")
const Balance = preload("res://game/data/balance.gd")
const SpriteArt = preload("res://game/render/sprite_art.gd")
const TARGET_COLOR: Color = Color("#ff3a2a")
const QUEST_MARK: Color = Color("#ffd84a")
const NPC_NAME: Color = Color("#ffcf6a")
## Nameplates and labels are drawn at this scale (the 2D view's zoom).
const TEXT_SCALE: float = 1.7

var game: Node
var world: Node3D


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if world == null or world.camera == null:
		return
	_draw_target()
	var own_level: int = game.actors[game.self_id]["state"].get("level", 1) if game.actors.has(game.self_id) else 1
	for id: int in world.monster_nodes:
		if not game.monsters.has(id):
			continue
		var state: Dictionary = game.monsters[id]["state"]
		var definition: Dictionary = Monsters.MONSTERS.get(state["kind"], {"name": "?", "size": 1.0})
		var title: String = "%s %d%s" % [definition["name"], state["level"], "  ENRAGED" if state.get("enraged", false) else ""]
		_plate(world.monster_nodes[id], 1.55 * float(definition["size"]), title, state["health"], state["max_health"], "",
			SpriteArt.danger_color(state["level"], own_level), "")
	for id: int in world.actor_nodes:
		if not game.actors.has(id) or not game.actors[id]["state"].has("health"):
			continue
		var state: Dictionary = game.actors[id]["state"]
		var title: String = "%s%s %d" % ["Bot " if state.get("bot", false) else "", Balance.profile_of(state.get("vocation", ""))["name"],
			state.get("level", 1)]
		_plate(world.actor_nodes[id], 1.6, title, state["health"], state["max_health"], state.get("skull", ""), Color.TRANSPARENT,
			_party_mark(id, state))
	_draw_npc_names()
	_draw_effects()


func _plate(body: Node3D, height: float, title: String, health: int, max_health: int, skull: String, color: Color,
		party: String) -> void:
	if world.camera.is_position_behind(body.position):
		return
	var head: Vector2 = world.head_of(body, height)
	if not Rect2(Vector2.ZERO, size).grow(40).has_point(head):
		return
	draw_set_transform(head, 0.0, Vector2.ONE * TEXT_SCALE)
	SpriteArt.draw_nameplate(self, Vector2(0, 30), title, health, max_health, 1.0, skull, color, party, false)
	draw_set_transform(Vector2.ZERO)


func _draw_target() -> void:
	var target: Dictionary = game.creature_view(game.own_target())
	if target.is_empty():
		return
	var corner: Vector2 = target["visual"]
	var points := PackedVector2Array()
	for offset: Vector2 in [Vector2(0.05, 0.05), Vector2(0.95, 0.05), Vector2(0.95, 0.95), Vector2(0.05, 0.95), Vector2(0.05, 0.05)]:
		points.append(world.camera.unproject_position(Vector3(corner.x + offset.x, 0.02, corner.y + offset.y)))
	draw_polyline(points, TARGET_COLOR, 2.5)


func _draw_npc_names() -> void:
	var font: Font = ThemeDB.fallback_font
	var own: Dictionary = game.actors[game.self_id]["state"] if game.actors.has(game.self_id) else {}
	var time: float = Time.get_ticks_msec() / 1000.0
	for cell: Vector2i in world.npc_nodes:
		var body: Node3D = world.npc_nodes[cell]
		if world.camera.is_position_behind(body.position):
			continue
		var npc_id: String = World.NPC_CELLS[cell]
		var npc: Dictionary = World.npc(npc_id)
		var head: Vector2 = world.head_of(body, 2.0 if npc.get("vehicle", "") == "waystone" else 1.55)
		draw_set_transform(head, 0.0, Vector2.ONE * TEXT_SCALE)
		var title: String = "Waystone" if npc.get("vehicle", "") == "waystone" else String(npc["name"])
		var width: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_string_outline(font, Vector2(-width / 2.0, 0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, SpriteArt.OUTLINE)
		draw_string(font, Vector2(-width / 2.0, 0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, NPC_NAME)
		var mark: String = World.quest_mark(npc_id, own) if not own.is_empty() else ""
		if not mark.is_empty():
			var top := Vector2(-3, -10 + sin(time * 3.0) * 1.5)
			draw_string_outline(font, top, mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, SpriteArt.OUTLINE)
			draw_string(font, top, mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, QUEST_MARK)
		draw_set_transform(Vector2.ZERO)


## Missiles fly between tiles; floating numbers rise from the tile they appeared on.
func _draw_effects() -> void:
	var font: Font = ThemeDB.fallback_font
	var time: float = Time.get_ticks_msec() / 1000.0
	for effect: Dictionary in game.effects:
		var age: float = time - effect["born"]
		if effect["kind"] == "missile":
			var weight: float = clampf(age / 0.25, 0.0, 1.0)
			var at: Vector2 = Vector2(effect["from"]).lerp(effect["to"], weight) / World.TILE_SIZE
			var spot: Vector2 = world.camera.unproject_position(Vector3(at.x, 0.8, at.y))
			draw_circle(spot, 4.0, effect["color"])
		elif effect["kind"] == "text":
			var tile: Vector2 = Vector2(effect["pos"]) / World.TILE_SIZE
			var spot: Vector2 = world.camera.unproject_position(Vector3(tile.x, 1.4 + age * 0.9, tile.y))
			var font_size: int = 18 if effect.get("big", false) else 15
			draw_string_outline(font, spot - Vector2(10, 0), effect["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, SpriteArt.OUTLINE)
			draw_string(font, spot - Vector2(10, 0), effect["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, effect["color"])


## "leader"/"member" for your party, "invited" for an open invitation either way, else "".
func _party_mark(id: int, state: Dictionary) -> String:
	if not game.actors.has(game.self_id):
		return ""
	var mine: Dictionary = game.actors[game.self_id]["state"]
	var party: int = mine.get("party", 0)
	if party != 0 and state.get("party", 0) == party:
		return "leader" if id == party else "member"
	if id in mine.get("invites", []) or id in mine.get("invited", []):
		return "invited"
	return ""
