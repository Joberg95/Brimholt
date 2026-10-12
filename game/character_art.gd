extends RefCounted
## Original procedural character, equipment, and item art. Each layer draws a 1-pixel
## outline under its fills, so later layers (armor, helmet, held item) read as worn on top.

const World = preload("res://game/world.gd")
const OUTLINE: Color = Color("#1a1612")
const SKIN: Color = Color("#e0b48f")
const SKIN_SHADE: Color = Color("#b98a6a")
const HAIR: Color = Color("#4a3426")
const PANTS: Color = Color("#343a4a")
const BOOTS: Color = Color("#3b2c22")
const EYES: Color = Color("#1e2330")
const COLORS: Array[Color] = [
	Color("#c9714c"), Color("#648db0"), Color("#aa79ab"), Color("#c3ab5a"),
]
## Original placeholder palettes: [main, highlight, accent].
const PALETTES: Dictionary = {
	"ember_cap": [Color("#ce8657"), Color("#edbd78"), Color("#e0d3a4")],
	"moss_coat": [Color("#6b9a68"), Color("#a9c287"), Color("#3a5c49")],
	"copper_blade": [Color("#d5d9cc"), Color("#cd945a"), Color("#8c5a32")],
	"iron_coif": [Color("#7c8590"), Color("#aeb6bf"), Color("#4f5862")],
	"ash_tunic": [Color("#8a4b46"), Color("#b8706a"), Color("#4d2b2a")],
	"flint_hatchet": [Color("#a3a79c"), Color("#8a6040"), Color("#5c3e2a")],
	"glowcap": [Color("#7fd6c2"), Color("#e8f2d0"), Color("#d9c9a3")],
}
const STYLES: Dictionary = {"iron_coif": "coif", "ash_tunic": "tunic", "flint_hatchet": "hatchet"}
const HINT_PALETTE: Array = [Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.14), Color(1, 1, 1, 0.1)]


static func palette(kind: String) -> Array:
	return PALETTES.get(kind, [Color("#d04fd0"), Color("#ffffff"), Color("#202020")])


static func _layer(canvas: CanvasItem, parts: Array, outline: bool = true) -> void:
	if outline:
		for part: Array in parts:
			canvas.draw_rect(part[0].grow(1.0), OUTLINE)
	for part: Array in parts:
		canvas.draw_rect(part[0], part[1])


static func _ellipse(center: Vector2, radius: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = []
	for index: int in 16:
		var angle: float = TAU * index / 16.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points


## stride is the 0..1 progress of the current step, or 0 when standing still.
static func draw_actor(canvas: CanvasItem, center: Vector2, state: Dictionary, local: bool, stride: float = 0.0) -> void:
	var facing: Vector2i = state["facing"]
	var equipment: Dictionary = state["equipment"]
	var tunic: Color = COLORS[int(state["id"]) % COLORS.size()]
	var side: int = facing.x
	var swing: int = 0 if stride <= 0.0 else (1 if stride < 0.5 else -1)
	canvas.draw_set_transform(center)
	canvas.draw_colored_polygon(_ellipse(Vector2(0, 12), Vector2(9, 3.5)), Color(0, 0, 0, 0.3))
	if local:
		var ring: PackedVector2Array = _ellipse(Vector2(0, 12), Vector2(12, 5))
		ring.append(ring[0])
		canvas.draw_polyline(ring, Color("#f2cf6a"), 1.0)
	if equipment.has("hand") and facing == Vector2i.UP:
		_draw_held(canvas, facing, equipment["hand"])
	var legs: Array[Rect2] = []
	var arms: Array[Rect2] = []
	var torso: Rect2
	if side == 0:
		legs = [Rect2(-5, 5 - maxi(swing, 0), 4, 7), Rect2(1, 5 - maxi(-swing, 0), 4, 7)]
		arms = [Rect2(-9, -3 + swing, 3, 9), Rect2(6, -3 - swing, 3, 9)]
		torso = Rect2(-6, -4, 12, 10)
	else:
		legs = [Rect2(-4 + swing * 2, 5, 4, 7), Rect2(0 - swing * 2, 5, 4, 7)]
		arms = [Rect2(-2 + swing * 2 * side, -3, 3, 9)]
		torso = Rect2(-5, -4, 10, 10)
	var head: Rect2 = Rect2(-5, -14, 10, 10)
	var body: Array = []
	for leg: Rect2 in legs:
		body.append([leg, PANTS])
	if side == 0:
		for arm: Rect2 in arms:
			body.append([arm, SKIN])
	body.append([torso, tunic])
	body.append([head, SKIN])
	_layer(canvas, body)
	var details: Array = []
	for leg: Rect2 in legs:
		details.append([Rect2(leg.position.x, leg.end.y - 2, leg.size.x, 2), BOOTS])
	if side == 0:
		for arm: Rect2 in arms:
			details.append([Rect2(arm.position, Vector2(3, 4)), tunic.darkened(0.1)])
	details.append([Rect2(torso.end.x - 2, torso.position.y, 2, torso.size.y), tunic.darkened(0.25)])
	details.append([Rect2(torso.position, Vector2(torso.size.x, 1)), tunic.lightened(0.2)])
	details.append([Rect2(torso.position.x, 3, torso.size.x, 2), Color("#5a4332")])
	details.append([Rect2(head.end.x - 2, head.position.y + 3, 2, 7), SKIN_SHADE])
	if facing == Vector2i.DOWN:
		details.append_array([
			[Rect2(-5, -14, 10, 3), HAIR], [Rect2(-5, -11, 1, 3), HAIR], [Rect2(4, -11, 1, 3), HAIR],
			[Rect2(-3, -9, 2, 2), EYES], [Rect2(1, -9, 2, 2), EYES],
		])
	elif facing == Vector2i.UP:
		details.append([Rect2(-5, -14, 10, 8), HAIR])
	elif facing == Vector2i.LEFT:
		details.append_array([[Rect2(-5, -14, 10, 3), HAIR], [Rect2(1, -11, 4, 4), HAIR], [Rect2(-4, -9, 2, 2), EYES]])
	else:
		details.append_array([[Rect2(-5, -14, 10, 3), HAIR], [Rect2(-5, -11, 4, 4), HAIR], [Rect2(2, -9, 2, 2), EYES]])
	_layer(canvas, details, false)
	if equipment.has("armor"):
		_draw_armor(canvas, equipment["armor"], torso, side)
	if side != 0:
		_layer(canvas, [[arms[0], SKIN]])
		_layer(canvas, [[Rect2(arms[0].position, Vector2(3, 4)), tunic.darkened(0.1)]], false)
	if equipment.has("helmet"):
		_draw_helmet(canvas, equipment["helmet"], facing)
	if equipment.has("hand") and facing != Vector2i.UP:
		_draw_held(canvas, facing, equipment["hand"])
	canvas.draw_set_transform(Vector2.ZERO)


static func _draw_armor(canvas: CanvasItem, kind: String, torso: Rect2, side: int) -> void:
	var colors: Array = palette(kind)
	if STYLES.get(kind, "") == "tunic":
		_layer(canvas, [[torso, colors[0]], [Rect2(torso.position.x - 1, 4, torso.size.x + 2, 3), colors[1]]])
		_layer(canvas, [[Rect2(torso.position.x, 2, torso.size.x, 1), colors[2]],
			[Rect2(torso.end.x - 2, torso.position.y, 2, 6), colors[0].darkened(0.25)]], false)
		return
	var parts: Array = [[torso, colors[0]]]
	if side == 0:
		parts.append_array([[Rect2(-9, -4, 4, 3), colors[1]], [Rect2(5, -4, 4, 3), colors[1]]])
	else:
		parts.append([Rect2(-3, -4, 5, 3), colors[1]])
	_layer(canvas, parts)
	_layer(canvas, [[Rect2(-1, -1, 2, 7), colors[2]], [Rect2(torso.position, Vector2(torso.size.x, 1)), colors[1]],
		[Rect2(torso.end.x - 2, torso.position.y + 1, 2, torso.size.y - 1), colors[0].darkened(0.25)]], false)


static func _draw_helmet(canvas: CanvasItem, kind: String, facing: Vector2i) -> void:
	var colors: Array = palette(kind)
	if STYLES.get(kind, "") == "coif":
		var flaps: Array = [[Rect2(-6, -16, 12, 6), colors[0]]]
		if facing != Vector2i.RIGHT:
			flaps.append([Rect2(-6, -11, 2, 6), colors[0]])
		if facing != Vector2i.LEFT:
			flaps.append([Rect2(4, -11, 2, 6), colors[0]])
		_layer(canvas, flaps)
		_layer(canvas, [[Rect2(-4, -15, 2, 1), colors[1]], [Rect2(0, -15, 2, 1), colors[1]],
			[Rect2(-2, -13, 2, 1), colors[1]], [Rect2(2, -13, 2, 1), colors[1]]], false)
		return
	_layer(canvas, [[Rect2(-6, -16, 12, 5), colors[0]], [Rect2(-7, -12, 14, 2), colors[1]], [Rect2(-1, -18, 2, 3), colors[2]]])
	_layer(canvas, [[Rect2(-5, -15, 3, 1), colors[1]]], false)


static func _draw_held(canvas: CanvasItem, facing: Vector2i, kind: String) -> void:
	var colors: Array = palette(kind)
	var hatchet: bool = STYLES.get(kind, "") == "hatchet"
	var parts: Array = []
	if facing.x != 0:
		var start: float = 9.0 if facing.x > 0 else -23.0
		var grip: float = 10.0 if facing.x > 0 else -12.0
		if hatchet:
			parts = [[Rect2(start, 1, 14, 2), colors[1]], [Rect2(start + (9 if facing.x > 0 else 0), -4, 5, 7), colors[0]]]
		else:
			parts = [[Rect2(start, 0, 14, 3), colors[0]], [Rect2(grip, -3, 2, 9), colors[1]]]
	else:
		var top: float = -14.0 if facing.y < 0 else 1.0
		if hatchet:
			parts = [[Rect2(12, top, 2, 14), colors[1]], [Rect2(9, top if facing.y < 0 else top + 9, 7, 5), colors[0]]]
		else:
			parts = [[Rect2(11, top, 3, 14), colors[0]], [Rect2(8, -2 if facing.y < 0 else 3, 9, 2), colors[1]]]
	_layer(canvas, parts)


## Draws an item icon centred on a 32-pixel slot or ground tile.
static func draw_item(canvas: CanvasItem, center: Vector2, kind: String) -> void:
	var slot: String = World.ITEMS[kind]["slot"] if World.ITEMS.has(kind) else ""
	canvas.draw_set_transform(center)
	_draw_icon(canvas, slot, STYLES.get(kind, ""), palette(kind), true)
	canvas.draw_set_transform(Vector2.ZERO)


static func draw_slot_hint(canvas: CanvasItem, center: Vector2, slot: String) -> void:
	canvas.draw_set_transform(center)
	_draw_icon(canvas, slot, "", HINT_PALETTE, false)
	canvas.draw_set_transform(Vector2.ZERO)


static func _draw_icon(canvas: CanvasItem, slot: String, style: String, colors: Array, outline: bool) -> void:
	match slot:
		"helmet":
			if style == "coif":
				_layer(canvas, [[Rect2(-8, -7, 16, 8), colors[0]], [Rect2(-8, 1, 3, 7), colors[0]], [Rect2(5, 1, 3, 7), colors[0]]], outline)
				_layer(canvas, [[Rect2(-5, -5, 2, 1), colors[1]], [Rect2(0, -5, 2, 1), colors[1]], [Rect2(-3, -3, 2, 1), colors[1]],
					[Rect2(2, -3, 2, 1), colors[1]]], false)
			else:
				_layer(canvas, [[Rect2(-8, -6, 16, 8), colors[0]], [Rect2(-10, 1, 20, 3), colors[1]], [Rect2(-1, -9, 3, 4), colors[2]]], outline)
		"armor":
			if style == "tunic":
				_layer(canvas, [[Rect2(-8, -8, 16, 15), colors[0]], [Rect2(-9, 5, 18, 4), colors[1]], [Rect2(-11, -8, 4, 7), colors[0]],
					[Rect2(7, -8, 4, 7), colors[0]]], outline)
				_layer(canvas, [[Rect2(-8, 2, 16, 1), colors[2]]], false)
			else:
				_layer(canvas, [[Rect2(-8, -7, 16, 16), colors[0]], [Rect2(-11, -8, 22, 4), colors[1]], [Rect2(-1, -4, 2, 12), colors[2]]], outline)
		"hand":
			if style == "hatchet":
				if outline:
					canvas.draw_line(Vector2(-8, 8), Vector2(7, -7), OUTLINE, 5.0)
				canvas.draw_line(Vector2(-8, 8), Vector2(7, -7), colors[1], 3.0)
				_layer(canvas, [[Rect2(2, -11, 8, 7), colors[0]]], outline)
			else:
				if outline:
					canvas.draw_line(Vector2(-4, 4), Vector2(9, -9), OUTLINE, 5.0)
					canvas.draw_line(Vector2(-9, 0), Vector2(0, 9), OUTLINE, 4.0)
					canvas.draw_line(Vector2(-10, 10), Vector2(-5, 5), OUTLINE, 5.0)
				canvas.draw_line(Vector2(-4, 4), Vector2(9, -9), colors[0], 3.0)
				canvas.draw_line(Vector2(-8, 1), Vector2(-1, 8), colors[1], 2.0)
				canvas.draw_line(Vector2(-10, 10), Vector2(-5, 5), colors[2], 3.0)
		_:
			if outline:
				canvas.draw_circle(Vector2(0, -1), 8.0, OUTLINE)
				canvas.draw_rect(Rect2(-3, -1, 6, 10), OUTLINE)
			canvas.draw_rect(Rect2(-2, 0, 4, 8), colors[2])
			canvas.draw_circle(Vector2(0, -1), 7.0, colors[0])
			canvas.draw_circle(Vector2(-3, -3), 1.5, colors[1])
			canvas.draw_circle(Vector2(3, -1), 1.5, colors[1])
