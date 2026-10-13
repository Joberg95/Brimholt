extends Control
## A spell's rune: its pixel icon (assets/sprites/spells.png). Used by the action bar slots and
## the spell book. Its tooltip (Spells.describe) is framed in the spell's colour; runes can be
## dragged (spell book to bar, or bar slot to bar slot) and the bar slots accept drops.

const Spells = preload("res://game/data/spells.gd")
const ItemSlot = preload("res://game/ui/item_slot.gd")

const SPELL_ICONS: Texture2D = preload("res://assets/sprites/spells.png")
const ICON_CELL: float = 32.0
const ICONS_PER_ROW: int = 8
const ICON_SIZE: float = 32.0
const LOCKED: Color = Color(0.45, 0.45, 0.45, 0.6)

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
## Draws the spell's icon (spells.png, from the sprite generator) centred on `center`,
## `width` pixels wide; locked spells are greyed out.
static func draw_rune(canvas: CanvasItem, id: String, center: Vector2, lit: bool, width: float = ICON_SIZE) -> void:
	var area := Rect2(center - Vector2.ONE * width / 2.0, Vector2.ONE * width)
	canvas.draw_texture_rect_region(SPELL_ICONS, area, icon_region(id), Color.WHITE if lit else LOCKED)


## The spell's 32x32 cell in spells.png (icons follow Spells.SPELLS order, eight per row).
static func icon_region(id: String) -> Rect2:
	var index: int = Spells.SPELLS.keys().find(id)
	return Rect2(Vector2(index % ICONS_PER_ROW, index / ICONS_PER_ROW) * ICON_CELL, Vector2.ONE * ICON_CELL)


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
