extends RefCounted
## Screen layout shared by main.gd and the UI components: the Tibia-style game window
## (15x11 tiles at 2x, centred on your character) and the equipment panel to its right.

const World = preload("res://game/core/world.gd")
const ZOOM: float = 2.0
const VIEW_TILES: Vector2i = Vector2i(15, 11)
const VIEW_ORIGIN: Vector2 = Vector2(16, 76)
const VIEW_SIZE: Vector2 = Vector2(VIEW_TILES * World.TILE_SIZE) * ZOOM
const PANEL_ORIGIN: Vector2 = Vector2(992, 76)
const BAR_SLOT: float = 44.0
