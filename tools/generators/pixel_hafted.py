"""Hand-pixelled hafted weapon icons (32x32): hammers, maces, and plain axes, on the classic
diagonal: the head at the top-left, a wooden haft down to a pommel at the bottom-right.

A head is laid out across the haft, in diagonal coordinates: u = x + y runs along the haft (small
toward the top-left) and v = y - x across it (positive toward the bottom-left). `head` is a list of
blocks (v_from, v_to, u_from, u_to, material), offsets from the head's centre; each pixel is shaded
by where it sits across its block's u span, from the lit top-left edge to the shaded lower edge, so
the 45-degree edges stay clean; an optional sixth value lightens (negative) or darkens a block, as
on a cutting edge. A mace head is a ball (`ball`: radius) shaded from the top-left,
with `flanges` round it. `marks` are single pixels at (x, y) offsets from the head's centre, in letters:

  l d the main colour, light and dark    a A b the item's accent (light, base, dark)
  y Y z gold, light to dark              g a glowing gem or ember      o outline

Materials: "metal" (the item's main colour), "steel", "gold", "accent", "wood", "glow" (the accent,
lit, pulsing on glowing styles).
Each weapon has its own haft and pommel from pixel_hafts.py (HAFTS).
make_sprites.py calls icon(style, colors, frame).
"""

import colorsys
import math

import pixel_hafts

ANIM_FRAMES = 12
OUTLINE = (28, 22, 24)
WOOD = ((150, 110, 70), (108, 76, 46), (70, 48, 30))
STEEL = ((232, 238, 242), (196, 204, 210), (154, 164, 172), (110, 118, 126), (74, 80, 86))
GOLD = ((248, 224, 138), (232, 196, 96), (216, 168, 58), (170, 124, 40), (122, 86, 28))

STYLES = {
    # A small iron mallet: a broad flat face, a socket band, and a narrow wedge peen behind.
    "handhammer": {
        "head": [(-8, -7, -5, 5, "steel"), (-6, -3, -5, 5, "steel"), (-2, 1, -6, 6, "accent"),
                 (2, 5, -5, 5, "steel"), (6, 7, -4, 4, "steel"), (8, 8, -3, 3, "steel")],
        "marks": [],
    },
    # A flanged bronze mace: a ball with eight flanges and a collar.
    "mace": {
        "ball": 5.0, "flanges": 8, "material": "metal",
        "head": [(-3, 2, 10, 12, "accent")],
        "marks": [],
    },
    # A knight's warhammer: a steel block banded in cobalt enamel with a back spike and a top spike.
    "warhammer": {
        "head": [(-10, -9, -6, 6, "steel"), (-8, -3, -5, 5, "steel"), (-2, 1, -6, 6, "metal"),
                 (2, 4, -4, 4, "steel"), (5, 7, -3, 3, "steel"), (8, 10, -2, 2, "steel"), (11, 13, -1, 1, "steel"),
                 (-1, 0, -11, -7, "steel")],
        "marks": [(0, 0, "a"), (-1, 1, "a"), (1, -1, "a")],
    },
    # A quarry pickhammer: a hammer face on one side, a long curved pick on the other.
    "pickhammer": {
        "head": [(-8, -7, -5, 5, "steel"), (-6, -3, -4, 4, "steel"), (-2, 1, -5, 5, "accent"),
                 (2, 4, -3, 3, "steel"), (5, 7, -2, 2, "steel"), (8, 10, -1, 2, "steel"),
                 (11, 13, 0, 2, "steel"), (14, 15, 1, 3, "steel"), (16, 16, 2, 3, "steel")],
        "marks": [],
    },
    # A forge hammer from the Hundred-Eyed Hollow: a soot-dark block split by a glowing ember seam.
    "forgehammer": {
        "head": [(-9, -8, -5, 5, "metal"), (-7, 7, -6, 6, "metal"), (8, 9, -5, 5, "metal"),
                 (-6, 6, -1, 0, "glow"), (-6, -6, -3, 2, "glow"), (6, 6, -2, 3, "glow")],
        "marks": [],
        "glow": True,
    },
    # A starforged maul: a heavy steel head with gold-capped flared ends and a blue star gem.
    "maul": {
        "head": [(-10, -9, -6, 6, "metal"), (-8, -7, -5, 5, "metal"), (-6, 6, -5, 5, "steel", 1),
                 (7, 8, -5, 5, "metal"), (9, 10, -6, 6, "metal")],
        "marks": [(0, 0, "g"), (-1, 0, "g"), (0, -1, "g"), (1, 0, "g"), (0, 1, "g"),
                  (-2, 0, "A"), (2, 0, "A"), (0, -2, "A"), (0, 2, "A"),
                  (-1, -1, "b"), (1, 1, "b"), (-1, 1, "b"), (1, -1, "b")],
        "glow": True,
    },
    # A sanctum warhammer: a pale steel maul banded in gold with a sun emblem and a top spike.
    "sanctum": {
        "head": [(-10, -9, -5, 5, "metal"), (-8, -7, -6, 6, "gold"), (-6, 6, -5, 5, "metal"),
                 (7, 8, -6, 6, "gold"), (9, 10, -5, 5, "metal"), (-1, 0, -11, -6, "gold")],
        "marks": [(0, 0, "y"), (-1, 0, "Y"), (1, 0, "Y"), (0, -1, "Y"), (0, 1, "Y"),
                  (-2, 0, "y"), (2, 0, "y"), (0, -2, "y"), (0, 2, "y")],
    },
    # A flint hatchet: a knapped stone wedge lashed to the haft with rawhide.
    "hatchet": {
        "head": [(-5, -3, -2, 2, "metal", 1), (-2, 1, -4, 4, "accent"), (2, 4, -4, 4, "metal"),
                 (5, 7, -5, 5, "metal"), (8, 10, -5, 6, "metal"), (11, 12, -4, 5, "metal", -1),
                 (13, 13, -3, 4, "metal", -2)],
        "marks": [(-2, 4, "d"), (-4, 5, "d"), (-1, 6, "d"), (-5, 7, "d"), (-3, 3, "l"), (-4, 7, "l"),
                  (-1, -1, "b"), (1, 1, "b")],
    },
    # A silverleaf axe: a bearded silver crescent with a green leaf etched in it and a gold collar.
    "leafaxe": {
        "head": [(-5, -4, -2, 2, "metal", 1), (-3, -2, -3, 3, "metal", 1), (-1, 1, -4, 4, "gold"),
                 (2, 4, -4, 4, "metal", 1), (5, 7, -5, 6, "metal", 1), (8, 10, -6, 8, "metal", 1),
                 (11, 12, -7, 10, "metal", 1), (13, 13, -7, 10, "steel", 2), (14, 15, -6, 10, "steel", -1)],
        "marks": [(-2, 3, "b"), (-3, 4, "b"), (-4, 5, "b"), (-5, 6, "b"), (-2, 2, "a"), (-3, 3, "a"),
                  (-4, 4, "A"), (-1, 3, "a"), (-2, 4, "A"), (-3, 5, "A"), (-4, 6, "b"), (-5, 5, "A"),
                  (-1, 2, "a")],
    },
    # A duskiron cleaver: a broad square blade of dark iron with a glowing violet edge.
    "cleaver": {
        "head": [(-5, -4, -3, 3, "metal"), (-3, 0, -4, 5, "metal"), (1, 11, -6, 9, "metal"),
                 (12, 12, -6, 9, "metal", 2), (13, 14, -6, 9, "glow"), (-1, 0, 6, 8, "gold")],
        "marks": [(-2, 3, "o"), (0, 5, "o"), (-4, 5, "y"), (-1, 3, "b"), (1, 5, "b")],
        "glow": True,
    },
}
STYLE_NAMES = tuple(STYLES)
GLOWING = tuple(name for name, spec in STYLES.items() if spec.get("glow"))


def _rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def _ramp(color):
    h, l, s = colorsys.rgb_to_hls(*(c / 255 for c in color))
    return tuple(tuple(round(c * 255) for c in colorsys.hls_to_rgb(h, max(0.04, min(0.94, l + dl)), s))
                 for dl in (0.22, 0.1, 0.0, -0.12, -0.22))


MARGIN = 6
CANVAS = 32 + 2 * MARGIN
HEAD = (8, 8)
HAFT = (6, 23)
# Each weapon's haft (pixel_hafts.py).
HAFTS = {"hatchet": "branch", "leafaxe": "birch", "cleaver": "twisted", "handhammer": "ash", "mace": "collared",
         "warhammer": "iron", "pickhammer": "banded", "forgehammer": "ember", "maul": "gilded", "sanctum": "ivory"}


def icon(style, colors, frame=0):
    """RGBA rows of a 32x32 hammer or mace icon; frame pulses a glowing gem or ember seam."""
    spec = STYLES[style]
    main, _light, accent = (_rgb(c) for c in colors)
    pulse = 0.5 + 0.5 * math.cos(frame * math.tau / ANIM_FRAMES) if spec.get("glow") else 0.6
    glow = tuple(min(255, round(c * (0.75 + 0.45 * pulse))) for c in _ramp(accent)[0])
    embers = (tuple(min(255, c + 60) for c in glow), glow, _ramp(accent)[1], _ramp(accent)[2])
    ramps = {"metal": _ramp(main), "steel": STEEL, "gold": GOLD, "accent": _ramp(accent), "wood": WOOD,
             "glow": embers}
    letters = {"a": ramps["accent"][1], "A": ramps["accent"][2], "b": ramps["accent"][4],
               "y": GOLD[0], "Y": GOLD[2], "z": GOLD[4], "g": glow, "o": OUTLINE,
               "l": _ramp(main)[0], "d": _ramp(main)[4]}
    # Drawn on a margin round the cell, then centred in it (centred()).
    pixels = [[None] * CANVAS for _ in range(CANVAS)]
    area = range(-MARGIN, 32 + MARGIN)

    def put(x, y, color):
        if -MARGIN <= x < 32 + MARGIN and -MARGIN <= y < 32 + MARGIN:
            pixels[y + MARGIN][x + MARGIN] = tuple(color[:3]) + (255,)

    pixel_hafts.draw(put, HAFTS[style], *HAFT, main, accent, frame)

    hx, hy = HEAD
    centre = hx + hy
    # Blocks across the haft, shaded on the diagonal from the lit top-left edge.
    for v_from, v_to, u_from, u_to, material, *shade in spec["head"]:
        ramp = ramps[material]
        for y in area:
            for x in area:
                u, v = x + y - centre, y - x
                if v_from <= v <= v_to and u_from <= u <= u_to:
                    share = (u - u_from) / max(1, u_to - u_from)
                    tone = min(len(ramp) - 1, round(share * (len(ramp) - 1.4)))
                    if v == v_to and v_to - v_from > 1:
                        tone = min(len(ramp) - 1, tone + 1)
                    elif v == v_from and v_to - v_from > 1:
                        tone = max(0, tone - 1)
                    tone = max(0, min(len(ramp) - 1, tone + (shade[0] if shade else 0)))
                    put(x, y, ramp[tone])
    # A mace's ball, lit from the top-left, with flanges round it.
    if "ball" in spec:
        ramp = ramps[spec["material"]]
        radius = spec["ball"]
        cx, cy = hx + 0.5, hy + 0.5
        lx, ly, lz = -0.55, -0.6, 0.58
        for index in range(spec["flanges"]):
            angle = index * math.tau / spec["flanges"] + math.pi / 8
            ca, sa = math.cos(angle), math.sin(angle)
            lit = ca * lx + sa * ly
            for step, half in ((radius + 0.5, 0.7), (radius + 1.5, 0.0)):
                for side in {-half, 0.0, half}:
                    fx, fy = cx + ca * step - sa * side, cy + sa * step + ca * side
                    tone = 1 if lit > 0.3 else 2 if lit > -0.3 else 3
                    put(math.floor(fx), math.floor(fy), ramp[tone])
        for y in area:
            for x in area:
                dx, dy = (x + 0.5 - cx) / radius, (y + 0.5 - cy) / radius
                if dx * dx + dy * dy <= 1.0:
                    nz = math.sqrt(max(0.0, 1 - dx * dx - dy * dy))
                    light = dx * lx + dy * ly + nz * lz
                    tone = 4 if light < 0.05 else 3 if light < 0.35 else 2 if light < 0.62 else 1 if light < 0.85 else 0
                    put(x, y, ramp[tone])
        put(hx - 2, hy - 2, (250, 244, 226))
    for dx, dy, letter in spec["marks"]:
        put(hx + dx, hy + dy, letters[letter])
    # Dark outline round the silhouette.
    solid = {(x, y) for y in range(CANVAS) for x in range(CANVAS) if pixels[y][x] is not None}
    for x, y in solid:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if q not in solid and 0 <= q[0] < CANVAS and 0 <= q[1] < CANVAS:
                pixels[q[1]][q[0]] = OUTLINE + (255,)
    return _centred(pixels)


def _centred(pixels):
    """The drawing moved so its bounds sit in the middle of a 32x32 cell (whole pixels, the same
    shift on every frame since glows never change the silhouette)."""
    used = [(x, y) for y in range(CANVAS) for x in range(CANVAS) if pixels[y][x] is not None]
    left, right = min(x for x, _ in used), max(x for x, _ in used)
    top, bottom = min(y for _, y in used), max(y for _, y in used)
    assert right - left <= 29 and bottom - top <= 29, "a hafted icon must fit inside the cell's 1px border"
    sx = (32 - (right - left + 1)) // 2 - left
    sy = (32 - (bottom - top + 1)) // 2 - top
    return [[pixels[y - sy][x - sx] if 0 <= y - sy < CANVAS and 0 <= x - sx < CANVAS else None for x in range(32)]
            for y in range(32)]
