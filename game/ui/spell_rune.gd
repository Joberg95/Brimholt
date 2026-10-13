extends Control
## A spell's rune: a coloured disc with the spell's initials. Used by the action bar slots and
## the spell book. Its tooltip (Spells.describe) is framed in the spell's colour; runes can be
## dragged (spell book to bar, or bar slot to bar slot) and the bar slots accept drops.

const Spells = preload("res://game/data/spells.gd")
const ItemSlot = preload("res://game/ui/item_slot.gd")

const RADIUS: float = 13.0
const INK: Color = Color("#14181c")
const RIM: Color = Color("#0b0e12")

## The spell shown, "" for none.
var spell: String = ""
## Dimmed when the spell is still locked.
var usable: bool = true
## Bar slot index (-1 in the spell book); sent with drags so a bar drop can swap slots.
var bar_slot: int = -1
## Called with (spell, from_bar_slot) when a rune is dropped here; null refuses drops.
var on_drop: Callable
var _frame := StyleBoxFlat.new()


func _init() -> void:
	_frame.bg_color = Color("#14181d")
	_frame.set_border_width_all(1)
	_frame.set_content_margin_all(6)
	_frame.anti_aliasing = false
	theme = Theme.new()
	theme.set_stylebox("panel", "TooltipPanel", _frame)


func _make_custom_tooltip(for_text: String) -> Object:
	var accent: Color = Spells.SPELLS[spell]["color"] if Spells.SPELLS.has(spell) else ItemSlot.BORDER
	_frame.border_color = accent
	return ItemSlot.tooltip_lines(for_text, accent)


## Draws the rune centred at `center` on any canvas item.
static func draw_rune(canvas: CanvasItem, id: String, center: Vector2, lit: bool) -> void:
	var definition: Dictionary = Spells.SPELLS[id]
	canvas.draw_circle(center, RADIUS, Color(definition["color"], 1.0 if lit else 0.35))
	canvas.draw_arc(center, RADIUS, 0, TAU, 24, RIM, 1.0)
	var initials: String = ""
	for word: String in String(definition["name"]).split(" "):
		initials += word[0]
	canvas.draw_string(ThemeDB.fallback_font, Vector2(center.x - 20.0, center.y + 4.0), initials,
		HORIZONTAL_ALIGNMENT_CENTER, 40.0, 12, INK)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not Spells.SPELLS.has(spell):
		return null
	if get_viewport().gui_is_dragging():
		var preview := Control.new()
		preview.draw.connect(draw_rune.bind(preview, spell, Vector2.ZERO, true))
		set_drag_preview(preview)
	return {"spell": spell, "from_bar_slot": bar_slot}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return on_drop.is_valid() and typeof(data) == TYPE_DICTIONARY and Spells.SPELLS.has(data.get("spell", ""))


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	on_drop.call(String(data["spell"]), int(data.get("from_bar_slot", -1)))
