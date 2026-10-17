"""Hand-drawn potion bottles (32x32), in the classic style: a round glass bottle lying on the
diagonal, cork to the upper left and the full belly to the lower right, the liquid's colour
filling the glass, lit from the top-left like a sphere (a five-tone ramp), with a white glint, a
pale rim of reflected light on the shadow side, and a dark outline in the liquid's own darkest
tone. Stronger potions are bigger bottles: SIZES grows from a small vial to a fat flask.

make_sprites.py calls icon(size, colors) with the item's look extra ("vial", "jar", "flask") and
its colours: [deep, bright, cork].
"""

import math

TILE = 32
# Bottle sizes: the belly is an egg lying along the bottle's axis, "belly" long (half length) and
# "width" wide (half width), so it reads tall and slim rather than round; then the neck's length
# and half-width, and the cork's length.
SIZES = {
    "vial": {"belly": 6.6, "width": 4.4, "neck": 4.2, "neck_half": 1.8, "cork": 3.0},
    "jar": {"belly": 8.0, "width": 5.6, "neck": 4.4, "neck_half": 2.2, "cork": 3.4},
    "flask": {"belly": 9.6, "width": 6.8, "neck": 4.6, "neck_half": 2.6, "cork": 3.8},
}
# The bottle lies along this axis: from the belly's centre toward the cork (up and left).
AXIS = (-math.sqrt(0.5), -math.sqrt(0.5))
ACROSS = (-AXIS[1], AXIS[0])
LIGHT = (-0.55, -0.65, 0.52)


def _rgb(text):
    return tuple(int(text[i:i + 2], 16) for i in (0, 2, 4))


def _mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def _scale(color, factor):
    return tuple(max(0, min(255, round(c * factor))) for c in color)


def _ramp(deep, bright):
    """Five tones, darkest first: shadow, deep, the colour, its bright tone, near white."""
    return [_scale(deep, 0.5), _scale(deep, 0.85), _mix(deep, bright, 0.45), bright, _mix(bright, (255, 255, 255), 0.45)]


def _tone(ramp, level):
    return ramp[max(0, min(len(ramp) - 1, level))]


def icon(size, colors):
    """The bottle as rows of RGBA tuples (None for clear)."""
    spec = SIZES[size]
    deep, bright, cork = (_rgb(c) for c in colors[:3])
    liquid = _ramp(deep, bright)
    wood = _ramp(_scale(cork, 0.7), _mix(cork, (255, 240, 210), 0.3))
    outline = _scale(deep, 0.32) + (255,)
    belly, width = spec["belly"], spec["width"]
    neck_end = belly + spec["neck"] - 0.6
    # Centre the whole bottle (belly plus neck and cork along the axis) in the tile.
    reach = belly + spec["neck"] + spec["cork"]
    centre = (TILE / 2 - AXIS[0] * (reach - belly) / 2, TILE / 2 - AXIS[1] * (reach - belly) / 2 + 0.5)
    pixels = [[None] * TILE for _ in range(TILE)]
    kinds = {}
    for y in range(TILE):
        for x in range(TILE):
            px, py = x + 0.5 - centre[0], y + 0.5 - centre[1]
            # Along and across the bottle's axis.
            along = px * AXIS[0] + py * AXIS[1]
            across = px * ACROSS[0] + py * ACROSS[1]
            nu, nv = along / belly, across / width
            if nu * nu + nv * nv <= 1.0:
                kinds[(x, y)] = ("belly", nu, nv)
            elif along > 0 and along <= neck_end and abs(across) <= spec["neck_half"]:
                kinds[(x, y)] = ("neck", across / spec["neck_half"], along)
            elif neck_end < along <= reach and abs(across) <= spec["neck_half"] + 0.7:
                kinds[(x, y)] = ("cork", across / (spec["neck_half"] + 0.7), along)
    for (x, y), (kind, u, v) in kinds.items():
        if kind == "belly":
            # An egg lit from the top-left: its surface normal, turned back to screen space; the
            # far edge picks up a little reflected light.
            z = math.sqrt(max(0.0, 1.0 - u * u - v * v))
            nx = u * AXIS[0] + v * ACROSS[0]
            ny = u * AXIS[1] + v * ACROSS[1]
            light = nx * LIGHT[0] + ny * LIGHT[1] + z * LIGHT[2]
            level = 1 + round(light * 2.6)
            edge = math.hypot(u, v)
            rim = edge > 0.78 and nx + ny > 0.55
            color = _tone(liquid, level - (1 if rim else 0))
            if rim and edge > 0.88:
                color = _mix(color, liquid[3], 0.35)
        elif kind == "neck":
            # A cylinder: lit on its upper-left side, the glass a little paler than the belly.
            level = 3 - round((u + 1) * 1.4)
            color = _mix(_tone(liquid, level), (230, 240, 248), 0.18)
        else:
            level = 3 - round((u + 1) * 1.4)
            color = _tone(wood, level)
            # The cork's end is cut flat and catches the light.
            if v > reach - 1.2:
                color = _tone(wood, level + 1)
        pixels[y][x] = color + (255,)
    # The glint: a white blob, longer along the bottle, on the belly's upper-left (toward the
    # cork and the lit side), with a softer halo round it.
    gx = centre[0] + belly * 0.3 * AXIS[0] - width * 0.45 * ACROSS[0]
    gy = centre[1] + belly * 0.3 * AXIS[1] - width * 0.45 * ACROSS[1]
    blob = max(1.0, width * 0.24)
    for (x, y), (kind, _u, _v) in kinds.items():
        if kind != "belly":
            continue
        dx, dy = x + 0.5 - gx, y + 0.5 - gy
        gap = math.hypot(dx * AXIS[0] + dy * AXIS[1], (dx * ACROSS[0] + dy * ACROSS[1]) * 1.6)
        if gap <= blob:
            pixels[y][x] = (255, 255, 255, 255)
        elif gap <= blob + 1.1:
            pixels[y][x] = _mix(pixels[y][x][:3], (255, 255, 255), 0.45) + (255,)
    # A seam where the neck meets the cork, and the outline round the whole bottle.
    for (x, y), (kind, _u, _v) in kinds.items():
        if kind == "cork" and any(kinds.get((x + dx, y + dy), ("",))[0] == "neck" for dx, dy in ((1, 0), (0, 1), (1, 1))):
            pixels[y][x] = _tone(wood, 0) + (255,)
    for y in range(TILE):
        for x in range(TILE):
            if (x, y) not in kinds and any((x + dx, y + dy) in kinds for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                pixels[y][x] = outline
    return pixels
