extends Node2D
## Draws the visible part of the world in map pixels, inside the lit world viewport. Floors
## come first; then each row is drawn west to east with ground items, characters, NPCs,
## oblique walls, and trees so nearer objects cover what stands behind them; a building's roof
## follows its southern wall row and fades out while you are inside. Children add
## ambient light and lights (lighting.gd), additive glow (glow_layer.gd), and particles
## (fx.gd). Names, bars, and floating numbers are drawn unlit by world_overlay.gd.

const World = preload("res://game/core/world.gd")
const SpriteArt = preload("res://game/render/sprite_art.gd")
const Monsters = preload("res://game/data/monsters.gd")
const Balance = preload("res://game/data/balance.gd")
const GlowLayer = preload("res://game/render/glow_layer.gd")
const Lighting = preload("res://game/render/lighting.gd")
const Fx = preload("res://game/render/fx.gd")
const FloorLayer = preload("res://game/render/floor_layer.gd")
const Crafting = preload("res://game/core/crafting.gd")
const FERRYMAN_GEAR: Dictionary = {"helmet": "ember_cap"}
const NPC_NAME: Color = Color("#9fe0c8")
## Quest givers stand out: gold cloth, a starweave cape, and a gold name.
const QUEST_GIVER_GEAR: Dictionary = {"cape": "starweave_cape"}
const QUEST_GIVER_TINT: Color = Color("#a8843a")
const QUEST_GIVER_NAME: Color = Color("#ffcf6a")
const WAYSTONE_NAME: Color = Color("#8fe8f0")
## Vendors wear a cap and coat, bankers a bronze coat.
const TOWNSFOLK_LOOKS: Dictionary = {
	"vendor": [{"helmet": "ember_cap", "armor": "moss_coat"}, Color("#8a6a3a")],
	"banker": [{"armor": "bronze_scale_coat"}, Color("#4a4a6a")],
	"artisan": [{"armor": "hide_jerkin", "helmet": "hide_hood"}, Color("#7a5a3a")],
}
## Extra tiles drawn around the view: tall sprites below the view reach up into it.
const MARGIN: Rect2i = Rect2i(-2, -2, 4, 6)

var game: Node
var glow: Node2D
var lighting: Node2D
var fx: Node2D
## [centre, name, colour] of NPCs drawn this frame, for the unlit overlay.
var npc_names: Array = []


## Walls, trees, NPCs, furniture, and herb patches of the cached area (the view plus TALL_MARGIN tiles) by cell,
## rebuilt only when the view leaves it.
const TALL_MARGIN: int = 8
var _tall: Dictionary = {}
var _tall_area: Rect2i = Rect2i()
var floor_layer: Node2D
## Roof opacity by building index (World.BUILDINGS): the roof of the building you stand in
## fades out, the roofs of buildings within ROOF_NEAR tiles of you turn see-through (ROOF_NEAR_ALPHA)
## so their doors and rooms show as you approach, and the rest fade back in. Signs by building index.
const ROOF_FADE_PER_SECOND: float = 5.0
const ROOF_NEAR: int = 3
const ROOF_NEAR_ALPHA: float = 0.35
## An ore vein glints for ORE_GLINT seconds every ORE_GLINT_EVERY seconds.
const ORE_GLINT: float = 0.35
const ORE_GLINT_EVERY: float = 2.6
var _roof_alpha: Dictionary = {}
var _signs_of: Dictionary = {}
## Wall torches by building index, like _signs_of.
var _torches_of: Dictionary = {}
var _last_draw: float = 0.0


func _ready() -> void:
	floor_layer = FloorLayer.new()
	floor_layer.view = self
	add_child(floor_layer)

	lighting = Lighting.new()
	lighting.view = self
	add_child(lighting)
	glow = GlowLayer.new()
	glow.view = self
	add_child(glow)
	fx = Fx.new()
	add_child(fx)


## Tiles to draw, as a rectangle clamped to the map.
func visible_cells() -> Rect2i:
	var focus: Vector2 = game.camera_focus() / World.TILE_SIZE
	var half: Vector2 = Vector2(game.VIEW_TILES) / 2.0
	var area := Rect2i(Vector2i((focus - half).floor()) + MARGIN.position,
		Vector2i((half * 2.0).ceil()) + Vector2i.ONE + MARGIN.size)
	return area.intersection(Rect2i(0, 0, World.width(), World.height()))


## Whether a cell inside a building is hidden by its roof (anyone there is not shown).
func covered(cell: Vector2i) -> bool:
	return World.ROOM_AT.has(cell) and _roof_alpha.get(World.ROOM_AT[cell], 1.0) > 0.5


## The building the local character stands in (or its doorway), or -1.
func inside_building() -> int:
	if not game.actors.has(game.self_id):
		return -1
	var visual: Vector2 = game.actors[game.self_id]["visual"]
	return World.ROOM_AT.get(Vector2i(roundi(visual.x), roundi(visual.y)), -1)


## The local character's tile (rounded from where it is drawn), or (-1000, -1000) without one.
func own_cell() -> Vector2i:
	if not game.actors.has(game.self_id):
		return Vector2i(-1000, -1000)
	var visual: Vector2 = game.actors[game.self_id]["visual"]
	return Vector2i(roundi(visual.x), roundi(visual.y))


## Whether a tile is within ROOF_NEAR tiles (Chebyshev) of a building's walls.
static func near_building(cell: Vector2i, rect: Rect2i) -> bool:
	var gap: Vector2i = Vector2i(maxi(maxi(rect.position.x - cell.x, cell.x - (rect.end.x - 1)), 0),
		maxi(maxi(rect.position.y - cell.y, cell.y - (rect.end.y - 1)), 0))
	return maxi(gap.x, gap.y) <= ROOF_NEAR


## Buildings in the area, fading their roofs; returns [bottom row, index] sorted by row.
func _roofs_in(area: Rect2i, time: float) -> Array:
	if _signs_of.is_empty():
		for sign: Dictionary in World.SIGNS:
			var building: int = World.ROOF_AT.get(sign["cell"], -1)
			if not _signs_of.has(building):
				_signs_of[building] = []
			_signs_of[building].append(sign)
	if _torches_of.is_empty():
		for cell: Vector2i in World.TORCHES:
			var building: int = World.ROOF_AT.get(cell, -1)
			if not _torches_of.has(building):
				_torches_of[building] = []
			_torches_of[building].append(cell)
	var step: float = clampf(time - _last_draw, 0.0, 0.1) * ROOF_FADE_PER_SECOND
	_last_draw = time
	var inside: int = inside_building()
	var here: Vector2i = own_cell()
	var roofs: Array = []
	for index: int in World.BUILDINGS.size():
		var rect: Rect2i = World.BUILDINGS[index]["rect"]
		var target: float = 0.0 if index == inside else ROOF_NEAR_ALPHA if near_building(here, rect) else 1.0
		if not rect.intersects(area):
			_roof_alpha[index] = target
			continue
		_roof_alpha[index] = move_toward(_roof_alpha.get(index, target), target, step)
		roofs.append([rect.end.y - 1, index])
	roofs.sort()
	return roofs


func _draw_roof(index: int) -> void:
	var alpha: float = _roof_alpha.get(index, 1.0)
	if alpha > 0.01:
		SpriteArt.draw_roof(self, index, World.BUILDINGS[index], alpha)
	for sign: Dictionary in _signs_of.get(index, []):
		SpriteArt.draw_sign(self, sign)
	var lit: bool = lighting.darkness > Lighting.TORCH_DARKNESS
	var time: float = Time.get_ticks_msec() / 1000.0
	for cell: Vector2i in _torches_of.get(index, []):
		SpriteArt.draw_torch(self, cell, 1 + (int(time * 7.0) + cell.x * 3 + cell.y) % 3 if lit else 0)


func _draw() -> void:
	var time: float = Time.get_ticks_msec() / 1000.0
	var area: Rect2i = visible_cells()
	var roofs: Array = _roofs_in(area, time)
	var next_roof: int = 0
	if not _tall_area.encloses(area):
		_cache_tall(area.grow(TALL_MARGIN).intersection(Rect2i(0, 0, World.width(), World.height())))
	for effect: Dictionary in game.effects:
		if effect["kind"] == "area":
			var fade: float = 1.0 - (time - effect["born"]) / 0.45
			for cell: Vector2i in effect["cells"]:
				draw_rect(Rect2(Vector2(cell) * World.TILE_SIZE, Vector2.ONE * World.TILE_SIZE), Color(effect["color"], 0.45 * fade))
	# Only cells with something standing on them are visited, in row-major (depth) order.
	var occupants: Dictionary = {}
	var keys := PackedInt32Array()
	var width: int = World.width()
	for cell: Vector2i in _tall:
		if area.has_point(cell):
			keys.append(cell.y * width + cell.x)
	var nearby: Array = game.actors.keys()
	nearby.append_array(game.monsters_in(area))
	for id: int in nearby:
		var visual: Vector2 = (game.actors[id] if id > 0 else game.monsters[id])["visual"]
		# A stepping creature belongs to the further south/east of its two tiles.
		var cell: Vector2i = Vector2i(ceili(visual.x - 0.001), ceili(visual.y - 0.001))
		if not area.has_point(cell):
			continue
		if not occupants.has(cell):
			occupants[cell] = []
			if not _tall.has(cell):
				keys.append(cell.y * width + cell.x)
		occupants[cell].append(id)
	for cell: Vector2i in game.ground_in(area):
		if not _tall.has(cell) and not occupants.has(cell):
			keys.append(cell.y * width + cell.x)
	keys.sort()
	var names: Array = []
	for key: int in keys:
		var cell := Vector2i(key % width, key / width)
		# A roof covers everything in its building's rows, and is covered by what stands south of it.
		while next_roof < roofs.size() and roofs[next_roof][0] < cell.y:
			_draw_roof(roofs[next_roof][1])
			next_roof += 1
		var tile: String = _tall.get(cell, "")
		if tile in World.WALLS and not tile.is_empty():
			SpriteArt.draw_wall(self, cell)
			if Crafting.ORES.has(cell) and not game.node_worked(cell):
				# Veins catch the eye: each glints for a moment every few seconds.
				SpriteArt.draw_ore(self, cell, Crafting.ORES[cell], fmod(time + SpriteArt.noise(cell, 17) % 100 * 0.031, ORE_GLINT_EVERY) < ORE_GLINT)
			continue
		if tile == "door":
			SpriteArt.draw_door(self, cell)
		if game.ground_view.has(cell):
			_draw_stack(cell, game.ground_view[cell])
		if tile == "furniture":
			SpriteArt.draw_furniture(self, cell, World.FURNITURE[cell])
		elif tile == "herb" and not game.node_worked(cell):
			SpriteArt.draw_herb(self, cell, Crafting.HERBS[cell])
		if tile == "npc" and World.npc(World.NPC_CELLS[cell]).get("vehicle", "") == "waystone":
			SpriteArt.draw_waystone(self, cell)
			if not covered(cell):
				# The stone stands taller than a person: its name sits above it.
				names.append([(Vector2(cell) + Vector2(0.5, 0.5)) * World.TILE_SIZE - Vector2(0, 24), "Waystone", WAYSTONE_NAME])
		elif tile == "npc":
			var npc: Dictionary = World.npc(World.NPC_CELLS[cell])
			var center: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * World.TILE_SIZE
			var keeper: bool = "quests" in npc["services"] or "vocation" in npc["services"]
			var look: Array = TOWNSFOLK_LOOKS.get(npc.get("role", ""),
				[QUEST_GIVER_GEAR, QUEST_GIVER_TINT] if keeper else [FERRYMAN_GEAR, SpriteArt.NPC_TINT])
			SpriteArt.draw_actor(self, center, {"id": 0, "facing": npc["facing"], "equipment": look[0]}, false, 0.0, look[1])
			if not covered(cell):
				names.append([center, npc["name"], QUEST_GIVER_NAME if keeper else NPC_NAME, World.NPC_CELLS[cell]])
		for id: int in occupants.get(cell, []):
			if id > 0:
				_draw_actor(id)
			else:
				_draw_monster(id)
		if tile in World.TREES and not tile.is_empty():
			SpriteArt.draw_tree(self, cell)
	while next_roof < roofs.size():
		_draw_roof(roofs[next_roof][1])
		next_roof += 1
	npc_names = names


## Walls, trees, and NPCs in the area: the static things drawn in depth order with creatures.
func _cache_tall(area: Rect2i) -> void:
	_tall.clear()
	_tall_area = area
	for y: int in range(area.position.y, area.end.y):
		var row: String = World.ROWS[y]
		for x: int in range(area.position.x, area.end.x):
			var tile: String = row[x]
			if tile in World.WALLS or tile in World.TREES:
				_tall[Vector2i(x, y)] = tile
	for building: Dictionary in World.BUILDINGS:
		if building["rect"].intersects(area):
			for cell: Vector2i in building["doors"]:
				if area.has_point(cell):
					_tall[cell] = "door"
	for cell: Vector2i in World.NPC_CELLS:
		if area.has_point(cell):
			_tall[cell] = "npc"
	for cell: Vector2i in World.FURNITURE:
		if area.has_point(cell):
			_tall[cell] = "furniture"
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			if Crafting.HERBS.has(Vector2i(x, y)):
				_tall[Vector2i(x, y)] = "herb"


## The top entry of a ground stack, with its stack count (or the number of entries beneath).
func _draw_stack(cell: Vector2i, stack: Array) -> void:
	var center: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * World.TILE_SIZE
	var top: String = stack.back()
	SpriteArt.draw_item(self, center, World.kind_of(top))
	var shown: int = World.count_of(top) if World.count_of(top) > 1 else stack.size()
	if shown > 1:
		SpriteArt.draw_count(self, center + Vector2(15, 14), shown)


func _draw_actor(id: int) -> void:
	var actor: Dictionary = game.actors[id]
	var center: Vector2 = (actor["visual"] + Vector2(0.5, 0.5)) * World.TILE_SIZE
	var stride: float = 0.0
	if actor["duration"] > 0.0 and actor["elapsed"] < actor["duration"]:
		stride = actor["elapsed"] / actor["duration"]
	SpriteArt.draw_actor(self, center, SpriteArt.posed(actor, Time.get_ticks_msec() / 1000.0), id == game.self_id, stride)


func _draw_monster(id: int) -> void:
	var monster: Dictionary = game.monsters[id]
	var center: Vector2 = (monster["visual"] + Vector2(0.5, 0.5)) * World.TILE_SIZE
	var stride: float = 0.0
	if monster["duration"] > 0.0 and monster["elapsed"] < monster["duration"]:
		stride = monster["elapsed"] / monster["duration"]
	SpriteArt.draw_monster(self, center, SpriteArt.posed(monster, Time.get_ticks_msec() / 1000.0), stride)


func _center_of(view: Dictionary) -> Vector2:
	return (view["visual"] + Vector2(0.5, 0.5)) * World.TILE_SIZE
