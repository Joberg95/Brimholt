extends MarginContainer
## Wraps a dialog or lexicon control (a row, label, icon, or button) so hovering it shows an
## item's tooltip the way inventory slots do: the name and quality line in the quality colour,
## framed in that colour (item_slot.gd). The wrapped control keeps no tooltip of its own, so
## Godot asks this wrapper. Make one with InventoryPanel.tip().

const ItemSlot = preload("res://game/ui/item_slot.gd")

var rarity_color: Color = Color.TRANSPARENT
var _frame := StyleBoxFlat.new()


func _init() -> void:
	_frame.bg_color = Color("#14181d")
	_frame.set_border_width_all(1)
	_frame.set_content_margin_all(6)
	_frame.anti_aliasing = false
	theme = Theme.new()
	theme.set_stylebox("panel", "TooltipPanel", _frame)
	mouse_filter = Control.MOUSE_FILTER_PASS
	for side: String in ["left", "top", "right", "bottom"]:
		add_theme_constant_override("margin_" + side, 0)


func _make_custom_tooltip(for_text: String) -> Object:
	_frame.border_color = rarity_color if rarity_color.a > 0.0 else ItemSlot.BORDER
	return ItemSlot.tooltip_lines(for_text, rarity_color)
