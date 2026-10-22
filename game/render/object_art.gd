extends RefCounted
## Trees, plants, furniture, signs, and wall decorations from the OpenTibia sprite pack (plan 49), each
## a pack thing drawn as the pack places it (WallArt.draw) in the world's row-major depth order.

const World = preload("res://game/core/world.gd")
const WallArt = preload("res://game/render/wall_art.gd")
const SpriteArt = preload("res://game/render/sprite_art.gd")

## Trees by terrain, a variant picked per cell: broadleaf woods ("T"), Gloamwood's dark trees ("D"),
## Sunreach's and the dunes' dry trees ("K"; the pack has no palms or cacti), the Hollow Reach's dead
## trees ("R"), Mirewood Fen's giant mushrooms ("U"), and the frost isles' firs ("P").
const TREES: Dictionary = {
	"T": [1504, 1507, 1509, 1531, 1533, 1563, 1564, 1582, 1505, 1508],
	"D": [1512, 1513, 1514, 1515, 1529],
	"K": [1576, 1500, 1486],
	"R": [1501, 1502, 1576],
	"U": [1585, 1586],
	"P": [1505, 1508, 1565, 1566],
}
## Furniture kinds (World.FURNITURE) -> pack thing.
const FURNITURE: Dictionary = {
	"counter_shop": 1189, "counter_bank": 1193, "shelf_potions": 1211, "shelf_books": 1209, "weapon_rack": 1175,
	"barrel": 1110, "crate": 1109, "strongbox": 1113, "anvil": 1138, "workbench": 1197, "cauldron": 1153, "loom": 1213,
	"hearth": 1207, "bed": 1199, "table": 1197, "chair": 1094, "plant": 1088, "chest": 1111, "lamp_post": 1169,
	"well": 1154, "bench": 1100, "stall": 1198, "stall_back": 1197, "bench_back": 1101, "pillar": 1131,
	"knight_statue": 1275, "gargoyle": 1157, "bush": 1498, "flower_vase": 1120, "potted_palm": 1089, "candelabra": 1166,
	"fruit_table": 1198, "stove": 1208, "throne": 1102, "fountain": 1151,
}
## Herb patches by resource band (Crafting.HERBS): the plant each band's herb item shows.
const HERBS: Array[int] = [1328, 1338, 1344, 1349, 1318]
## Things hung on a wall's visible face: [on a west-east wall, on a north-south wall]. Shop signs are
## banners in their trade's colour.
const WALL_DECOR: Dictionary = {"banner": [1233, 1234], "wall_torch": [1243, 1241], "painting": [1225, 1227]}
const SIGNS: Dictionary = {"vendor": [1233, 1234], "banker": [1237, 1238], "artisan": [1235, 1236], "warden": [1233, 1234]}
## A waystone: the pack's moss-grown shrine stone.
const WAYSTONE: int = 1146


static func draw_tree(canvas: CanvasItem, cell: Vector2i) -> void:
	var kinds: Array = TREES.get(SpriteArt.tile_at(cell), TREES["T"])
	WallArt.draw(canvas, kinds[SpriteArt.noise(cell, 7) % kinds.size()], cell)


static func draw_furniture(canvas: CanvasItem, cell: Vector2i, kind: String) -> void:
	if FURNITURE.has(kind):
		WallArt.draw(canvas, FURNITURE[kind], cell)


static func draw_herb(canvas: CanvasItem, cell: Vector2i, band: int) -> void:
	WallArt.draw(canvas, HERBS[band], cell)


static func draw_waystone(canvas: CanvasItem, cell: Vector2i) -> void:
	WallArt.draw(canvas, WAYSTONE, cell)


## A decoration on a wall cell, on the face the wall shows.
static func draw_wall_decor(canvas: CanvasItem, cell: Vector2i, kind: String) -> void:
	var pieces: Array = WALL_DECOR.get(kind, WALL_DECOR["banner"])
	WallArt.draw(canvas, pieces[1 if _north_south(cell) else 0], cell)


## A shop sign on the wall beside its door, facing out of the building.
static func draw_sign(canvas: CanvasItem, sign: Dictionary) -> void:
	var pieces: Array = SIGNS.get(sign["kind"], SIGNS["vendor"])
	var outward: Vector2i = sign["outward"]
	WallArt.draw(canvas, pieces[1 if outward.x != 0 else 0], sign["cell"])


## Whether a wall cell runs north-south (more wall above or below it).
static func _north_south(cell: Vector2i) -> bool:
	for side: Vector2i in [Vector2i.UP, Vector2i.DOWN]:
		var tile: String = SpriteArt.tile_at(cell + side)
		if not tile.is_empty() and tile in World.WALLS:
			return true
	return false
