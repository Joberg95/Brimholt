extends Node2D
## Unlit layer above the world viewport, sharing the world view's map-pixel transform: target
## square, nameplates, NPC names, missiles, and floating numbers stay readable at night.

const World = preload("res://game/core/world.gd")
const SpriteArt = preload("res://game/render/sprite_art.gd")
const Monsters = preload("res://game/data/monsters.gd")
const Balance = preload("res://game/data/balance.gd")
const TARGET_COLOR: Color = Color("#ff3a2a")

var game: Node
var view: Node2D


func _process(_delta: float) -> void:
	position = view.position
	scale = view.scale
	queue_redraw()


const QUEST_MARK: Color = Color("#ffd84a")


func _draw() -> void:
	_draw_overlays(view.visible_cells(), Time.get_ticks_msec() / 1000.0)
	var font: Font = ThemeDB.fallback_font
	var own: Dictionary = game.actors[game.self_id]["state"] if game.actors.has(game.self_id) else {}
	var time: float = Time.get_ticks_msec() / 1000.0
	for entry: Array in view.npc_names:
		var width: float = font.get_string_size(entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var at: Vector2 = entry[0] + Vector2(-width / 2.0, -SpriteArt.FRAME_ANCHOR.y + 10)
		draw_string_outline(font, at, entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, SpriteArt.OUTLINE)
		draw_string(font, at, entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, entry[2])
		# "!" a quest giver has something for you, "?" you can turn something in; it bobs gently.
		var mark: String = World.quest_mark(entry[3], own) if entry.size() > 3 and not own.is_empty() else ""
		if not mark.is_empty():
			var top: Vector2 = entry[0] + Vector2(-3, -SpriteArt.FRAME_ANCHOR.y + 1 + sin(time * 3.0) * 1.5)
			draw_string_outline(font, top, mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, SpriteArt.OUTLINE)
			draw_string(font, top, mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, QUEST_MARK)


func _center_of(state_view: Dictionary) -> Vector2:
	return (state_view["visual"] + Vector2(0.5, 0.5)) * World.TILE_SIZE


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


## Target square, nameplates, missiles, and floating numbers, drawn above the world.
func _draw_overlays(area: Rect2i, time: float) -> void:
	var target: int = game.own_target()
	var target_view: Dictionary = game.creature_view(target)
	if not target_view.is_empty():
		var corner: Vector2 = target_view["visual"] * World.TILE_SIZE
		draw_rect(Rect2(corner + Vector2.ONE, Vector2.ONE * (World.TILE_SIZE - 2)), TARGET_COLOR, false, 2.0)
	var shown := Rect2(Vector2(area.position) * World.TILE_SIZE, Vector2(area.size) * World.TILE_SIZE)
	for id: int in game.monsters_in(area):
		var monster: Dictionary = game.monsters[id]
		var center: Vector2 = _center_of(monster)
		if shown.has_point(center) and not view.covered(Vector2i(monster["visual"].round())):
			var definition: Dictionary = Monsters.MONSTERS.get(monster["state"]["kind"], {"name": "?", "size": 1.0})
			var own_level: int = game.actors[game.self_id]["state"].get("level", 1) if game.actors.has(game.self_id) else 1
			var title: String = "%s %d%s" % [definition["name"], monster["state"]["level"],
				"  ENRAGED" if monster["state"].get("enraged", false) else ""]
			SpriteArt.draw_nameplate(self, center, title,
				monster["state"]["health"], monster["state"]["max_health"], definition["size"], "",
				SpriteArt.danger_color(monster["state"]["level"], own_level), "", definition.get("look", "") == "humanoid")
	for id: int in game.actors:
		var actor: Dictionary = game.actors[id]
		var center: Vector2 = _center_of(actor)
		if shown.has_point(center) and actor["state"].has("health") and not view.covered(Vector2i(actor["visual"].round())):
			var state: Dictionary = actor["state"]
			var title: String = "%s %d" % [Balance.VOCATIONS.get(state.get("vocation", ""), {"name": "Player"})["name"],
				state.get("level", 1)]
			SpriteArt.draw_nameplate(self, center, title, state["health"], state["max_health"], 1.0, state.get("skull", ""),
				Color.TRANSPARENT, _party_mark(id, state), true)
	var font: Font = ThemeDB.fallback_font
	for effect: Dictionary in game.effects:
		var age: float = time - effect["born"]
		if effect["kind"] == "missile":
			var weight: float = clampf(age / 0.25, 0.0, 1.0)
			var at: Vector2 = effect["from"].lerp(effect["to"], weight)
			draw_line(at - (effect["to"] - effect["from"]).normalized() * 6.0, at, effect["color"], 2.0)
			draw_circle(at, 2.0, effect["color"])
		elif effect["kind"] == "text":
			var at: Vector2 = effect["pos"] + Vector2(-8, -20.0 - age * 22.0)
			var size: int = 11 if effect.get("big", false) else 9
			draw_string_outline(font, at, effect["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, SpriteArt.OUTLINE)
			draw_string(font, at, effect["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, size, effect["color"])
