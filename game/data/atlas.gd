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
## Floors (docs/plan/46 and 47): z 0 is the surface (the overworld), up to TOP above it and down
## to BOTTOM below. Cells stay 2D: each floor is a plane the size of the overworld laid beside it
## at a fixed x (FLOOR_X, on sector boundaries, a void gap between planes), so the cell over or
## under surface (x, y) on floor z is (x + FLOOR_X[z], y). Only the surface is full; the other
## floors are void wherever nothing is painted. Stairs up ("^") on floor z with a hole or ladder
## ("v") right above them on floor z + 1 join the two (World.HOLES). The dungeon and cave bands
## (x 1924-2560) lie on no floor: floor_of() is NO_FLOOR there.
const TOP: int = 3
const BOTTOM: int = -2
const FLOOR_X: Dictionary = {0: 0, -1: 2560, -2: 4608, 1: 6656, 2: 8704, 3: 10752}
const NO_FLOOR: int = 1000
## The floor below the overworld (docs/plan/44-underground-floor.md): tunnels, sewers, caves.
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


## A floor's plane: its cells in world coordinates.
static func plane(z: int) -> Rect2i:
	return Rect2i(Vector2i(FLOOR_X[z], 0), OVERWORLD_SIZE)


## The floor a cell lies on, or NO_FLOOR (the dungeon and cave bands, or off every plane).
static func floor_of(cell: Vector2i) -> int:
	if cell.y < 0 or cell.y >= OVERWORLD_SIZE.y:
		return NO_FLOOR
	for z: int in FLOOR_X:
		if cell.x >= FLOOR_X[z] and cell.x < FLOOR_X[z] + OVERWORLD_SIZE.x:
			return z
	return NO_FLOOR


## Below ground (a floor under the surface), or above it (a floor over the surface).
static func below_ground(cell: Vector2i) -> bool:
	return floor_of(cell) < 0


static func above_ground(cell: Vector2i) -> bool:
	var z: int = floor_of(cell)
	return z > 0 and z != NO_FLOOR


## The surface cell a cell lies over or under (itself on the surface); (-1, -1) off every floor.
static func on_surface(cell: Vector2i) -> Vector2i:
	var z: int = floor_of(cell)
	return cell - Vector2i(FLOOR_X[z], 0) if z != NO_FLOOR else Vector2i(-1, -1)


## The cell over or under `cell` on floor z; (-1, -1) off every floor or past TOP and BOTTOM.
static func to_floor(cell: Vector2i, z: int) -> Vector2i:
	if not FLOOR_X.has(z) or floor_of(cell) == NO_FLOOR:
		return Vector2i(-1, -1)
	return on_surface(cell) + Vector2i(FLOOR_X[z], 0)


## The cell one floor down and one floor up.
static func below(cell: Vector2i) -> Vector2i:
	return to_floor(cell, floor_of(cell) - 1)


static func above(cell: Vector2i) -> Vector2i:
	return to_floor(cell, floor_of(cell) + 1)


## A floor as players read it: "Surface", "Floor +1", "Floor −2".
static func floor_name(z: int) -> String:
	return "Surface" if z == 0 else "Floor %s%d" % ["+" if z > 0 else "−", absi(z)]
