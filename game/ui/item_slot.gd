extends Control
## An inventory, depot, or ground slot. Its hover tooltip shows the item's rarity: the name
## and rarity line in the rarity colour, framed in that colour (inventory_panel.gd sets
## `rarity_color`; transparent for items without a rarity).

const TEXT: Color = Color("#c8ccd0")
const REFUSED: Color = Color("#e05a4a")
const BORDER: Color = Color("#3a4450")

var rarity_color: Color = Color.TRANSPARENT
var _frame := StyleBoxFlat.new()


func _init() -> void:
	_frame.bg_color = Color("#14181d")
	_frame.set_border_width_all(1)
	_frame.set_content_margin_all(6)
	_frame.anti_aliasing = false
	theme = Theme.new()
	theme.set_stylebox("panel", "TooltipPanel", _frame)


func _make_custom_tooltip(for_text: String) -> Object:
	_frame.border_color = rarity_color if rarity_color.a > 0.0 else BORDER
	return tooltip_lines(for_text, rarity_color)


## Tooltip text as labels: the first line (the name) large, the first two in the accent colour,
## refused requirements ("✗ ...") in red.
static func tooltip_lines(text: String, accent: Color) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	var lines: PackedStringArray = text.split("\n")
	for index: int in lines.size():
		var label := Label.new()
		label.text = lines[index]
		var color: Color = TEXT
		if accent.a > 0.0 and index == 0:
			color = accent
		elif accent.a > 0.0 and index == 1:
			color = accent.lerp(TEXT, 0.35)
		if lines[index].begins_with("✗"):
			color = REFUSED
		label.add_theme_color_override("font_color", color)
		if index == 0:
			label.add_theme_font_size_override("font_size", 15)
		box.add_child(label)
	return box
