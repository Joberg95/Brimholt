extends RefCounted
## Climate regions shared by the map painters and the client's weather. The Dunmere desert is
## an ellipse in the south-west of the overworld: sand ground, cacti and thorn scrub instead
## of leafy trees, and no rain. tools/generators/desert.gd paints it into the map scene;
## game/render/weather.gd keeps it dry.

const DESERT_CENTRE: Vector2 = Vector2(118, 300)
const DESERT_RADII: Vector2 = Vector2(75, 52)
## Map cells the desert painter may touch: the ellipse plus its ragged noise edge.
const DESERT_AREA: Rect2i = Rect2i(36, 240, 170, 125)


## 0 at the desert's centre, 1 on its nominal edge, growing outside it.
static func desert_distance(cell: Vector2i) -> float:
	return ((Vector2(cell) + Vector2(0.5, 0.5) - DESERT_CENTRE) / DESERT_RADII).length()


## The swamp: Mirewood Fen, its bog mud and giant mushrooms painted by tools/generators/swamp.gd.
## Rain and fog hang over it more often than anywhere else.
const SWAMP_REGION: String = "Mirewood Fen"


static func in_desert(cell: Vector2i) -> bool:
	return desert_distance(cell) < 1.0


## The frost isles (tools/generators/frost_isles.gd): snow, firs, and the port of Hrimvik, in free
## grid space south of the mainland behind ISLES_SEA rows of open sea, reached only by boat. The
## world map shows them west of the mainland (game/data/atlas.gd). Houses there have log walls,
## snowed roofs, and plank floors; it snows instead of raining, and the light is colder.
const ISLES_SEA: int = 64
## South of the doubled mainland (640 x 640, plan 43), moved there by tools/generators/relocate.gd.
const ISLES: Rect2i = Rect2i(0, 640 + ISLES_SEA, 160, 128)
const ISLES_LIGHT: Color = Color(0.9, 0.95, 1.06)


static func in_isles(cell: Vector2i) -> bool:
	return ISLES.has_point(cell)


## Sunreach (docs/plan/47-world-plan.md), the desert island south of the mainland painted by
## make region NAME=sunreach: palms by its oases, and the sandstone castle of Qasrun and town of
## Duneford, whose houses have sandstone walls, flat sand-plaster roofs, and slab streets. It never
## rains there, and the light is warmer.
const SUNREACH: Rect2i = Rect2i(380, 740, 280, 240)
const SUNREACH_LIGHT: Color = Color(1.06, 1.0, 0.9)


static func in_sunreach(cell: Vector2i) -> bool:
	return SUNREACH.has_point(cell)
