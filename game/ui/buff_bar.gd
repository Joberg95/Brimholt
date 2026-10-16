extends Node
## The buff bar above the minimap: one small icon per effect on you, with the time it has left
## and a tooltip. A meal's regeneration shows the food it came from; being rooted or slowed shows
## the spell's rune stone. New effects (party buff spells) add an entry in effects().

const World = preload("res://game/core/world.gd")
const Layout = preload("res://game/ui/layout.gd")
const SpriteArt = preload("res://game/render/sprite_art.gd")
const SpellRune = preload("res://game/ui/spell_rune.gd")
const ICON: float = 22.0
const GAP: float = 4.0
const MAX_ICONS: int = 6
const HARMFUL: Color = Color("#ff7a6a")
const HELPFUL: Color = Color("#9fe0a0")

var game: Node
var _icons: Array[Control] = []
var _shown: Array[Dictionary] = []


func build(game_node: Node, layer: CanvasLayer) -> void:
	game = game_node
	for index: int in MAX_ICONS:
		var icon := Control.new()
		icon.position = Layout.PANEL_ORIGIN + Vector2(index * (ICON + GAP), 544)
		# Icons are shrunk to ICON pixels: blend them down instead of dropping pixel rows.
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icon.size = Vector2(ICON, ICON + 10)
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		icon.visible = false
		# The side panel's background is built later in the same layer; stay above it.
		icon.z_index = 2
		icon.draw.connect(_draw_icon.bind(icon, index))
		layer.add_child(icon)
		_icons.append(icon)


## Per frame: what is on you and how long each lasts.
func refresh() -> void:
	_shown = effects()
	for index: int in _icons.size():
		var icon: Control = _icons[index]
		icon.visible = index < _shown.size()
		if icon.visible:
			icon.tooltip_text = "%s (%s left)\n%s" % [_shown[index]["title"], _time(_shown[index]["left"]), _shown[index]["text"]]
			icon.queue_redraw()


## The effects on your character now: {title, text, left (seconds), item or spell, harmful}.
func effects() -> Array[Dictionary]:
	var shown: Array[Dictionary] = []
	if not game.actors.has(game.self_id):
		return shown
	var view: Dictionary = game.actors[game.self_id]
	var state: Dictionary = view["state"]
	var since: float = game._now() - view.get("received", game._now())
	if state.has("fed"):
		var meal: Dictionary = World.ITEMS.get(state["fed"][0], {})
		var left: float = float(state["fed"][1]) - since
		if left > 0.0 and not meal.is_empty():
			shown.append({"title": "Well fed: %s" % meal["name"], "left": left, "item": state["fed"][0], "harmful": false,
				"text": "+%d%% health and mana regeneration" % roundi(meal["eat"]["regen"] * 100.0)})
	for held: Array in [["rooted", "entangling_roots", "Rooted", "You cannot step"],
			["slowed", "crippling_arrow", "Slowed", "Your steps take twice as long"]]:
		var left: float = float(state.get(held[0], 0.0)) - since
		if left > 0.0:
			shown.append({"title": held[2], "left": left, "spell": held[1], "harmful": true, "text": held[3]})
	return shown


func _draw_icon(icon: Control, index: int) -> void:
	if index >= _shown.size():
		return
	var effect: Dictionary = _shown[index]
	var area := Rect2(Vector2.ZERO, Vector2.ONE * ICON)
	icon.draw_rect(area, Color("#171c22"))
	if effect.has("item"):
		SpriteArt.draw_item(icon, area.get_center(), effect["item"], Color.WHITE, ICON - 2)
	else:
		SpellRune.draw_rune(icon, effect["spell"], area.get_center(), true, ICON - 2)
	icon.draw_rect(area, HARMFUL if effect["harmful"] else HELPFUL, false, 1.0)
	var font: Font = ThemeDB.fallback_font
	var text: String = _time(effect["left"])
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	icon.draw_string(font, Vector2((ICON - width) / 2.0, ICON + 9), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#dfe6ee"))


## "12m" for minutes, "45s" for the last minute.
static func _time(seconds: float) -> String:
	return "%dm" % ceili(seconds / 60.0) if seconds >= 60.0 else "%ds" % ceili(seconds)
