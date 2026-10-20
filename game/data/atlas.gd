extends RefCounted
## The world's geography: how big the overworld is, how its terrain and world map are cut into
## sectors, and its continents. Today's heartland (the mainland and the frost isles south of it)
## sits in the north-west corner; the rest of the OVERWORLD_SIZE square is open deep sea until new
## land is painted there, east and south. Instanced dungeons and elite caves lie in bands right of
## the overworld (game/data/dungeons.gd, caves.gd). The world map shows every cell where it really
## lies (map tile = world cell): it is baked in one page per sector (tools/generators/world_map.gd)
## that the map window (game/ui/world_maps.gd) loads as you look around.

const Biomes = preload("res://game/data/biomes.gd")

## The overworld in cells, from (0, 0): today's heartland in the north-west corner, open deep sea
## round it until new land is painted east and south.
const OVERWORLD_SIZE: Vector2i = Vector2i(1920, 1920)
## Cells per side of a terrain sector (game/maps/map_io.gd) and of a world map page.
const SECTOR: int = 128
## The mainland, grown to 640 x 640 (tools/generators/mainland.gd) round the old heartland in its
## north-west corner, where the game began.
const MAINLAND: Rect2i = Rect2i(0, 0, 640, 640)
const HEARTLAND: Rect2i = Rect2i(0, 0, 384, 384)
## The underground (docs/plan/44-underground-floor.md): a floor below the overworld, laid beside it
## past the dungeon and cave bands and lined up under it, so the cell under surface (x, y) is
## (x + UNDER_X, y). A hole ("v") on the surface over stairs up ("^") right below joins the two.
const UNDER_X: int = 2560
const UNDERGROUND: Rect2i = Rect2i(UNDER_X, 0, OVERWORLD_SIZE.x, OVERWORLD_SIZE.y)
## Each continent is crossed to and from only by boat.
const CONTINENTS: Array = [
	{"name": "the mainland", "cells": MAINLAND},
	{"name": "the frost isles", "cells": Biomes.ISLES},
	# The archipelago (tools/generators/islands.gd ISLANDS).
	{"name": "Silverwood", "cells": Rect2i(760, 60, 240, 220)},
]
## The baked world map: one PNG per page (<sx>_<sy>.png, MAP_SCALE pixels per cell), a small
## overview of the whole overworld (one pixel per cell) for zooming far out, and pages.json with
## the scale and each page's terrain hash (World.page_hash), so a page edited since shows stale.
const MAP_DIR: String = "res://assets/sprites/world_map"
const MAP_META: String = "res://assets/sprites/world_map/pages.json"
const MAP_OVERVIEW: String = "res://assets/sprites/world_map/overview.png"
const MAP_SCALE: int = 4


## The sector holding `cell`.
static func sector_of(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(cell.x / float(SECTOR)), floori(cell.y / float(SECTOR)))


## A sector's cells.
static func sector_rect(sector: Vector2i) -> Rect2i:
	return Rect2i(sector * SECTOR, Vector2i(SECTOR, SECTOR))


## The sectors overlapping `area`.
static func sectors_in(area: Rect2i) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	if area.size.x <= 0 or area.size.y <= 0:
		return found
	var first: Vector2i = sector_of(area.position)
	var last: Vector2i = sector_of(area.end - Vector2i.ONE)
	for sy: int in range(first.y, last.y + 1):
		for sx: int in range(first.x, last.x + 1):
			found.append(Vector2i(sx, sy))
	return found


## A world map page's PNG.
static func page_path(sector: Vector2i) -> String:
	return "%s/%d_%d.png" % [MAP_DIR, sector.x, sector.y]


## The continent a cell lies on, or "" off the overworld or in open sea.
static func continent_at(cell: Vector2i) -> String:
	for continent: Dictionary in CONTINENTS:
		if (continent["cells"] as Rect2i).has_point(cell):
			return continent["name"]
	return ""


## The underground cell under a surface cell, and the surface cell over an underground one.
static func below(cell: Vector2i) -> Vector2i:
	return cell + Vector2i(UNDER_X, 0)


static func above(cell: Vector2i) -> Vector2i:
	return cell - Vector2i(UNDER_X, 0)
