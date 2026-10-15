extends RefCounted
## Gathering, crafting, and profession skills on the host (game/data/professions.gd). A player
## works a node next to them (an ore vein, a tree, a herb patch, or water within reach) for
## Professions.GATHER_SECONDS; moving cancels it. The node then regrows for REGROW_SECONDS and
## 1-5 of the land's band's resource (Professions.gather_count) land in the backpack. One cell
## in ten rests and is never a node (Professions.resting). Crafting happens at a town artisan
## (World service "craft"): the recipe's resources leave the backpack and its output arrives.
## Skills are player["skills"]: profession -> [level, experience]. Results are {ok, events} or
## {ok: false, reason, events}, like Combat.

const World = preload("res://game/core/world.gd")
const Professions = preload("res://game/data/professions.gd")

## Every recipe by id (Professions.build_recipes).
static var RECIPES: Dictionary = Professions.build_recipes(World.ITEMS)
## Herb patches: cell -> resource band. Herbs grow outside towns, dungeons, and markers.
static var HERBS: Dictionary = _find_herbs()
## Ore veins: cell -> resource band. Veins glitter in the south faces of mountains and outcrops in
## the wilds (not in towns or dungeons); the rest of the rock is scenery.
static var ORES: Dictionary = _find_ores()

var world: World
## Worked nodes: cell -> host time when they regrow.
var depleted: Dictionary = {}
## Gather yields; tests seed it for repeatable rolls.
var rng := RandomNumberGenerator.new()


func _init(owner: World, seed_value: int = -1) -> void:
	world = owner
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


static func _find_herbs() -> Dictionary:
	var herbs: Dictionary = {}
	var blocked: Dictionary = {}
	for cell: Vector2i in World.SPAWNS:
		blocked[cell] = true
	for entry: Array in World.GROUND_ITEMS:
		blocked[entry[0]] = true
	for group: Dictionary in [World.NPC_CELLS, World.FURNITURE, World.DUNGEON_ENTRANCES]:
		for cell: Vector2i in group:
			blocked[cell] = true
	var ground: PackedByteArray = Professions.HERB_GROUND.to_ascii_buffer()
	var rect: Rect2i = World.OVERWORLD
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var code: int = World.GRID[y * World.GRID_SIZE.x + x]
			if not code in ground:
				continue
			var cell := Vector2i(x, y)
			if Professions.herb_at(cell, World.terrain(cell)) and not blocked.has(cell) and World.zone_at(cell).is_empty() \
					and not Professions.resting(cell):
				herbs[cell] = band_at(cell)
	return herbs


static func _find_ores() -> Dictionary:
	var ores: Dictionary = {}
	var rect: Rect2i = World.OVERWORLD
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			var zone: Dictionary = World.zone_at(cell)
			var tile: String = World.terrain(cell)
			if tile.is_empty() or not tile in Professions.SOURCES["mining"] or zone.get("town", false) \
					or zone.get("underground", false) or Professions.resting(cell) \
					or not Professions.ore_at(cell, tile, World.walkable(cell + Vector2i.DOWN), band_at(cell)):
				continue
			var crowded: bool = false
			for dy: int in range(-Professions.ORE_GAP, 1):
				for dx: int in range(-Professions.ORE_GAP, Professions.ORE_GAP + 1):
					crowded = crowded or ores.has(cell + Vector2i(dx, dy))
			if not crowded:
				ores[cell] = band_at(cell)
	return ores


## The resource band of the land at a cell: the middle of its zone's (or region's) monster levels.
static func band_at(cell: Vector2i) -> int:
	var zone: Dictionary = World.zone_at(cell)
	var levels := Vector2i.ZERO
	if not zone.is_empty() and not zone["town"] and zone["max_level"] > 0:
		levels = Vector2i(zone["min_level"], zone["max_level"])
	else:
		var region: String = World.region_at(cell)
		if not region.is_empty():
			levels = Vector2i(World.REGION_INFO[region]["min_level"], World.REGION_INFO[region]["max_level"])
	return Professions.band_for_level((levels.x + levels.y) / 2)


## The gathering skill a cell serves as a node ("" for none): overworld only, never in dungeons.
static func node_at(cell: Vector2i) -> String:
	if not World.OVERWORLD.has_point(cell) or World.zone_at(cell).get("underground", false):
		return ""
	if HERBS.has(cell):
		return "herbalism"
	if ORES.has(cell):
		return "mining"
	return "" if Professions.resting(cell) else Professions.source_of(World.terrain(cell))


## What a node yields, by its land's band.
static func resource_at(cell: Vector2i, profession: String) -> String:
	return Professions.RESOURCES[profession][HERBS[cell] if profession == "herbalism" else band_at(cell)]


static func skill_of(player: Dictionary, profession: String) -> int:
	return int(player["skills"].get(profession, [1, 0])[0])


## Whether a node is regrowing at `now`.
func worked(cell: Vector2i, now: float) -> bool:
	return depleted.get(cell, -INF) > now


## Starts gathering at a node within reach. The work finishes in tick().
func start_gather(id: int, cell: Variant, now: float) -> Dictionary:
	if not world.players.has(id):
		return _refused("Unknown player")
	var player: Dictionary = world.players[id]
	if typeof(cell) != TYPE_VECTOR2I:
		return _refused("Unknown place")
	var profession: String = node_at(cell)
	if profession.is_empty():
		return _refused("There is nothing to gather there")
	if World.chebyshev(player["cell"], cell) > Professions.REACH[profession]:
		return _refused("Walk closer to gather")
	if player["health"] <= 0:
		return _refused("You are dead")
	if worked(cell, now):
		return _refused("It has been worked; it regrows in %d s" % ceili(depleted[cell] - now))
	var band: int = HERBS[cell] if profession == "herbalism" else band_at(cell)
	if skill_of(player, profession) < Professions.BAND_LEVELS[band]:
		return _refused("%s %d needed to gather %s here" % [Professions.NAMES[profession], Professions.BAND_LEVELS[band],
			World.ITEMS[resource_at(cell, profession)]["name"]])
	if World.receiving_slot(player["backpack"], resource_at(cell, profession), 1) < 0:
		return _refused("Your backpack is full")
	player["gathering"] = {"cell": cell, "profession": profession, "from": player["cell"],
		"until": now + Professions.GATHER_SECONDS}
	if cell != player["cell"]:
		var offset: Vector2i = cell - player["cell"]
		player["facing"] = Vector2i(signi(offset.x), 0) if absi(offset.x) >= absi(offset.y) else Vector2i(0, signi(offset.y))
	return {"ok": true, "events": [{"kind": "player", "id": id}]}


## Finishes gathering that is due, and forgets regrown nodes.
func tick(now: float) -> Array:
	var events: Array = []
	for id: int in world.players:
		var work: Dictionary = world.players[id].get("gathering", {})
		if not work.is_empty() and now >= work["until"]:
			_finish_gather(id, now, events)
	for cell: Vector2i in depleted.keys():
		if depleted[cell] <= now:
			depleted.erase(cell)
	return events


func _finish_gather(id: int, now: float, events: Array) -> void:
	var player: Dictionary = world.players[id]
	var work: Dictionary = player["gathering"]
	player["gathering"] = {}
	events.append({"kind": "player", "id": id})
	var cell: Vector2i = work["cell"]
	var profession: String = work["profession"]
	if player["cell"] != work["from"] or player["health"] <= 0 or worked(cell, now):
		return
	var kind: String = resource_at(cell, profession)
	var band: int = HERBS[cell] if profession == "herbalism" else band_at(cell)
	var count: int = Professions.gather_count(rng.randf(), skill_of(player, profession), band)
	var gathered: int = 0
	while gathered < count:
		var slot: int = World.receiving_slot(player["backpack"], kind, 1)
		if slot < 0:
			break
		player["backpack"][slot] = World.make_entry(kind, World.count_of(player["backpack"][slot]) + 1)
		gathered += 1
	if gathered == 0:
		events.append({"kind": "message", "id": id, "text": "Your backpack is full."})
		return
	depleted[cell] = now + Professions.REGROW_SECONDS
	var text: String = "You gather %d %s." % [gathered, World.ITEMS[kind]["name"]]
	if gathered < count:
		text += " Your backpack is full; %d more stay behind." % (count - gathered)
	text += train(player, profession, Professions.gather_gain(skill_of(player, profession), band))
	events.append({"kind": "message", "id": id, "text": text})
	events.append({"kind": "node", "cell": cell, "seconds": Professions.REGROW_SECONDS})


## Adds skill experience; returns " Your Mining rose to 12." for each level gained, or "".
static func train(player: Dictionary, profession: String, gain: int) -> String:
	var entry: Array = player["skills"].get(profession, [1, 0]).duplicate()
	var text: String = ""
	entry[1] += gain
	while entry[0] < Professions.SKILL_MAX and entry[1] >= Professions.experience_to_next(entry[0]):
		entry[1] -= Professions.experience_to_next(entry[0])
		entry[0] += 1
		text += " Your %s rose to %d." % [Professions.NAMES[profession], entry[0]]
	if entry[0] >= Professions.SKILL_MAX:
		entry[1] = 0
	player["skills"][profession] = entry
	return text


## Crafts `count` of a recipe at an artisan in range, as many as the resources allow.
func craft(id: int, npc: Variant, recipe_id: Variant, count: Variant, now: float) -> Dictionary:
	if not world.players.has(id):
		return _refused("Unknown player")
	var player: Dictionary = world.players[id]
	if not World.serves(npc, "craft", player["cell"]):
		return _refused("Walk closer to an artisan")
	if typeof(recipe_id) != TYPE_STRING or not RECIPES.has(recipe_id) or typeof(count) != TYPE_INT \
			or count < 1 or count > Professions.MAX_CRAFT_COUNT:
		return _refused("Unknown recipe")
	if now < player["next_craft"]:
		return _refused("You are still working")
	var recipe: Dictionary = RECIPES[recipe_id]
	var output: Array = recipe["output"]
	var profession: String = recipe["profession"]
	if skill_of(player, profession) < recipe["skill"]:
		return _refused("%s %d needed" % [Professions.NAMES[profession], recipe["skill"]])
	var made: int = 0
	var text: String = ""
	for attempt: int in count:
		var missing: String = ""
		for entry: Array in recipe["inputs"]:
			if World.carried(player["backpack"], entry[0]) < entry[1]:
				missing = World.ITEMS[entry[0]]["name"]
		if not missing.is_empty():
			if made == 0:
				return _refused("You need more %s" % missing)
			break
		var spent: Array = player["backpack"].duplicate()
		for entry: Array in recipe["inputs"]:
			World.remove_carried(spent, entry[0], entry[1])
		var filled: Array = World.with_items(spent, [output])
		if filled.is_empty():
			if made == 0:
				return _refused("Your backpack is full")
			break
		for index: int in filled.size():
			player["backpack"][index] = filled[index]
		made += 1
		text += train(player, profession, Professions.craft_gain(skill_of(player, profession), recipe))
	player["next_craft"] = now + Professions.CRAFT_SECONDS
	var title: String = World.ITEMS[output[0]]["name"]
	var message: String = "You craft %s." % (title if made * output[1] == 1 else "%d %ss" % [made * output[1], title])
	var flash: Array[Vector2i] = [player["cell"]]
	return {"ok": true, "events": [{"kind": "player", "id": id}, {"kind": "message", "id": id, "text": message + text},
		{"kind": "area", "cells": flash, "color": Color("#ffcf6a")}]}


func _refused(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "events": []}
