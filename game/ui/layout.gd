extends RefCounted
## Screen layout shared by main.gd and the UI components: the Tibia-style game window
## (15x11 tiles at 2x, centred on your character) at the top left and the equipment panel to its
## right; the game menu (the cogwheel) holds what a title row used to.

const World = preload("res://game/core/world.gd")
const ZOOM: float = 2.0
const VIEW_TILES: Vector2i = Vector2i(15, 11)
const VIEW_ORIGIN: Vector2 = Vector2(16, 16)
const VIEW_SIZE: Vector2 = Vector2(VIEW_TILES * World.TILE_SIZE) * ZOOM
const PANEL_ORIGIN: Vector2 = Vector2(992, 16)
## Item slots show their 32-pixel icons at full size: a smaller slot would drop rows and columns
## of pixels (nearest filtering), which is what made icons look rough.
const SLOT_SIZE: float = 32.0
const BAR_SLOT: float = 36.0
