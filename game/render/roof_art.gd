extends RefCounted
## Roofs for town buildings (WorldMap.BUILDINGS) from the OpenTibia sprite pack (plan 49), as Tibia
## shows them: the building's floor one level up, covered in roof tiles (its north row the tiles with
## the ridge's edge) and drawn a tile up and left, where a floor above sits in the pack's view. Each
## roof is composed once into an image.

const World = preload("res://game/core/world.gd")
const WorldMap = preload("res://game/world_map/world_map.gd")
const Biomes = preload("res://game/data/biomes.gd")
const PackAtlas = preload("res://game/render/pack_atlas.gd")
const GroundArt = preload("res://game/render/ground_art.gd")
const TILE: int = 32
## Roof materials: [north row tile, other rows] (pack ids). Clay, red, and shingle are spread over the
## towns; the castle town wears blue slate, the frost isles snow, Sunreach its sandstone.
const MATERIALS: Dictionary = {
	"clay": [183, 184], "red": [185, 186], "shingle": [189, 190], "slate": [187, 188], "snow": [200, 201],
	"sandstone": [192, 193],
}
const TOWN_MATERIALS: Array[String] = ["clay", "red", "shingle"]
const SLATE_TOWN: String = "Reedmere"


## The roof material of a building's rect.
static func material_of(rect: Rect2i) -> String:
	if WorldMap.zone_at(rect.position).get("name", "") == SLATE_TOWN:
		return "slate"
	if Biomes.in_isles(rect.position):
		return "snow"
	if Biomes.in_sunreach(rect.position):
		return "sandstone"
	return TOWN_MATERIALS[posmod(rect.position.x * 7 + rect.position.y * 13, TOWN_MATERIALS.size())]


## {texture, origin (map pixels)} for a building {rect, ...}.
static func build(building: Dictionary) -> Dictionary:
	var rect: Rect2i = building["rect"]
	var tiles: Array = MATERIALS[material_of(rect)]
	var atlas: Image = GroundArt.atlas_image()
	var image := Image.create_empty(rect.size.x * TILE, rect.size.y * TILE, false, Image.FORMAT_RGBA8)
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var id: int = tiles[0] if y == rect.position.y else tiles[1]
			var piece: int = GroundArt.piece(id, Vector2i(x, y))
			image.blit_rect(atlas, Rect2i(PackAtlas.RECTS[piece * 2], PackAtlas.RECTS[piece * 2 + 1], TILE, TILE),
				(Vector2i(x, y) - rect.position) * TILE)
	return {"texture": ImageTexture.create_from_image(image), "origin": Vector2(rect.position * TILE - Vector2i.ONE * TILE)}
