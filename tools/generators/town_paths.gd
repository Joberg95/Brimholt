extends SceneTree
## Lays a cobbled path from every town door to the town's streets. For each building in a town
## zone (Buildings.find), the cell in front of each door is joined to the nearest street network
## (a run of at least MIN_NETWORK street cells outside buildings) by the shortest walk over open
## ground, painted as cobblestone; a tree is cut only when no treeless path exists. Doors that
## face out of the town are left alone. Running again changes nothing: every door is connected.
##
##   godot --headless --path . --script res://tools/generators/town_paths.gd

const World = preload("res://game/core/world.gd")
const Buildings = preload("res://game/data/buildings.gd")
const SCENE_PATH: String = "res://game/maps/overworld.tscn"
## Streets a path joins, ground it may cross, and the tree it may cut as a last resort.
const STREETS: String = "=,"
const OPEN: String = ".,:d"
const TREE: String = "T"
const MIN_NETWORK: int = 30
const MAX_STEPS: int = 40
const SIDES: Array[Vector2i] = [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]


func _initialize() -> void:
	var scene_root: Node = (load(SCENE_PATH) as PackedScene).instantiate()
	var result: Dictionary = apply(scene_root)
	var error: Error = OK
	if result["painted"] > 0:
		var packed := PackedScene.new()
		packed.pack(scene_root)
		error = ResourceSaver.save(packed, SCENE_PATH)
	print("Joined %d doors to the streets with %d cobbles; %d doors found no way (%s)" % [
		result["doors"], result["painted"], result["stuck"].size(), error_string(error)])
	for stuck: Vector2i in result["stuck"]:
		print("  no street reachable from the door at %s" % stuck)
	scene_root.free()
	quit(0 if error == OK else 1)


## Paints the paths into the scene's Terrain layer: {doors joined, painted cells, stuck doors}.
static func apply(scene_root: Node) -> Dictionary:
	var layer: TileMapLayer = scene_root.get_node("Terrain")
	var painted: Dictionary = {}
	var terrain_of: Callable = func(cell: Vector2i) -> String:
		if painted.has(cell):
			return painted[cell]
		var index: int = layer.get_cell_atlas_coords(cell).x
		return "" if index < 0 else World.TERRAINS[index]
	var result: Dictionary = {"doors": 0, "painted": 0, "stuck": []}
	for zone: Dictionary in World.ZONES:
		if not zone["town"]:
			continue
		var buildings: Array = Buildings.find(terrain_of, zone["rect"].grow(1))
		for front: Vector2i in door_fronts(buildings, zone["rect"]):
			var found: Dictionary = path_to_street(front, terrain_of, zone["rect"], buildings)
			if not found["ok"]:
				result["stuck"].append(front)
				continue
			if found["cells"].is_empty():
				continue
			result["doors"] += 1
			for cell: Vector2i in found["cells"]:
				painted[cell] = "="
				layer.set_cell(cell, 0, Vector2i(World.TERRAINS.find("="), 0))
				result["painted"] += 1
	return result


## The cell in front of every door that opens into the town.
static func door_fronts(buildings: Array, area: Rect2i) -> Array[Vector2i]:
	var fronts: Array[Vector2i] = []
	for building: Dictionary in buildings:
		for door: Vector2i in building["doors"]:
			var front: Vector2i = door + building["outward"][door]
			if area.has_point(front):
				fronts.append(front)
	return fronts


## {ok, cells}: the cells to pave between `front` and a street network (empty when it already
## is on one); ok is false when no path of at most MAX_STEPS exists.
static func path_to_street(front: Vector2i, terrain_of: Callable, area: Rect2i, buildings: Array) -> Dictionary:
	var footprint: Dictionary = {}
	for building: Dictionary in buildings:
		for cell: Vector2i in building["footprint"]:
			footprint[cell] = true
	var network: Dictionary = street_network(terrain_of, area, footprint)
	if network.has(front):
		return {"ok": true, "cells": []}
	for crossing: String in [OPEN + STREETS, OPEN + STREETS + TREE]:
		var from: Dictionary = {front: front}
		var frontier: Array[Vector2i] = [front]
		if terrain_of.call(front) not in crossing or footprint.has(front):
			continue
		for step: int in MAX_STEPS:
			var next: Array[Vector2i] = []
			for cell: Vector2i in frontier:
				for side: Vector2i in SIDES:
					var near: Vector2i = cell + side
					if from.has(near) or not area.has_point(near) or footprint.has(near) or World.NPC_CELLS.has(near):
						continue
					if network.has(near):
						var cells: Array[Vector2i] = []
						var at: Vector2i = cell
						while true:
							if terrain_of.call(at) != "=":
								cells.append(at)
							if at == front:
								break
							at = from[at]
						return {"ok": true, "cells": cells}
					if terrain_of.call(near) in crossing:
						from[near] = cell
						next.append(near)
			frontier = next
	return {"ok": false, "cells": []}


## Street cells outside buildings that belong to a run of at least MIN_NETWORK of them.
static func street_network(terrain_of: Callable, area: Rect2i, footprint: Dictionary) -> Dictionary:
	var network: Dictionary = {}
	var seen: Dictionary = {}
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var start := Vector2i(x, y)
			if seen.has(start) or footprint.has(start) or terrain_of.call(start) not in STREETS:
				continue
			var run: Array[Vector2i] = [start]
			seen[start] = true
			var index: int = 0
			while index < run.size():
				for side: Vector2i in SIDES:
					var near: Vector2i = run[index] + side
					if area.has_point(near) and not seen.has(near) and not footprint.has(near) and terrain_of.call(near) in STREETS:
						seen[near] = true
						run.append(near)
				index += 1
			if run.size() >= MIN_NETWORK:
				for cell: Vector2i in run:
					network[cell] = true
	return network
