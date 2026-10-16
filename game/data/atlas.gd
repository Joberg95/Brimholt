extends RefCounted
## The overworld's continents and how they sit on the world map. The grid keeps the frost isles
## south of the mainland (Biomes.ISLES), where they cost no coordinate changes; the world map
## shows them to the west instead, like islands off the coast. Each sheet is a rectangle of cells drawn with its
## corner at `at` in map tiles. The baker (tools/generators/world_map.gd) paints the sheets this
## way, and the map window (game/ui/world_maps.gd) places everything through to_map().

const Biomes = preload("res://game/data/biomes.gd")

## Map tiles of open sea between the isles and the mainland, and above the isles.
const STRAIT: int = 16
const ISLES_TOP: int = 16
const MAINLAND: Rect2i = Rect2i(0, 0, 384, 384)
## Each sheet is one continent: you cross between them only by boat.
const SHEETS: Array = [
	{"name": "the mainland", "cells": MAINLAND, "at": Vector2i(160 + STRAIT, 0)},
	{"name": "the frost isles", "cells": Biomes.ISLES, "at": Vector2i(0, ISLES_TOP)},
]
## The world map in tiles: the isles, the strait, and the mainland.
const SIZE: Vector2i = Vector2i(160 + STRAIT + 384, 384)


## The sheet holding `cell`, or the mainland's for cells on no sheet (the sea between them).
static func sheet_of(cell: Vector2i) -> Dictionary:
	for sheet: Dictionary in SHEETS:
		if (sheet["cells"] as Rect2i).has_point(cell):
			return sheet
	return SHEETS[0]


## Where a (fractional) tile appears on the world map, in map tiles.
static func to_map(tile: Vector2) -> Vector2:
	var sheet: Dictionary = sheet_of(Vector2i(tile.floor()))
	return tile - Vector2(sheet["cells"].position) + Vector2(sheet["at"])


## The tile under a world map point, or (-1, -1) for open sea between the sheets.
static func from_map(point: Vector2) -> Vector2:
	for sheet: Dictionary in SHEETS:
		var local: Vector2 = point - Vector2(sheet["at"])
		if Rect2(Vector2.ZERO, Vector2(sheet["cells"].size)).has_point(local):
			return local + Vector2(sheet["cells"].position)
	return Vector2(-1, -1)
