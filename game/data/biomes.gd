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
