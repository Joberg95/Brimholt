extends RefCounted
## The game's dark-and-gold look for buttons and text fields (start screen, top bar).

const GOLD: Color = Color("#ffcf6a")
const TEXT: Color = Color("#e8e4da")


## Buttons and fields in the game's dark-and-gold look.
static func build() -> Theme:
	var look := Theme.new()
	var looks: Dictionary = {"normal": [Color("#2a2320"), Color("#6a5a3a")], "hover": [Color("#3a2f24"), GOLD],
		"pressed": [Color("#1e1a16"), GOLD], "disabled": [Color("#1a1c20"), Color("#3a4450")], "focus": [Color(0, 0, 0, 0), GOLD]}
	for state: String in looks:
		var box := StyleBoxFlat.new()
		box.bg_color = looks[state][0]
		box.border_color = looks[state][1]
		box.set_border_width_all(1)
		box.set_corner_radius_all(3)
		box.set_content_margin_all(6)
		box.content_margin_left = 12
		box.content_margin_right = 12
		box.anti_aliasing = false
		look.set_stylebox(state, "Button", box)
	look.set_color("font_color", "Button", TEXT)
	look.set_color("font_hover_color", "Button", GOLD)
	look.set_color("font_disabled_color", "Button", Color("#5a6068"))
	for state: String in ["normal", "focus"]:
		var field := StyleBoxFlat.new()
		field.bg_color = Color("#0b0e12")
		field.border_color = GOLD if state == "focus" else Color("#3a4450")
		field.set_border_width_all(1)
		field.set_corner_radius_all(3)
		field.set_content_margin_all(6)
		field.anti_aliasing = false
		look.set_stylebox(state, "LineEdit", field)
	return look
