"""Hand-pixelled showpiece axe icons (32x32), drawn on the diagonal like classic item icons: the
head at the top-left, the haft running down to a pommel at the bottom-right.

Each axe is rows of hand-placed pixels: {row: [(first column, "pixels"), ...]}, one letter per
pixel ("." leaves the pixel as it is). Letters:

  o outline      1-5 steel, bright cutting edge to deep shadow      y Y z gold, light to dark
  a A b the axe's own colour (light, base, dark)                    g a glowing gem (pulses)
  s S bone       T tongue

Each axe names its haft and pommel from pixel_hafts.py ("haft"), a two-pixel diagonal run from
HAFT_TOP down to the pommel. `back` segments are drawn under the haft and `wing` segments are also
mirrored across the haft (double-headed axes). make_sprites.py calls icon(style, colors, frame).
"""

import colorsys
import math

import pixel_hafts

ANIM_FRAMES = 12
HAFT_TOP = 6
HAFT_END = 23
SHIFT = (2, 2)

STEEL = {"1": "e8eef2", "2": "c4ccd2", "3": "9aa4ac", "4": "6e767e", "5": "4a5056"}
FIXED = {"o": "1c1618", "y": "f8e08a", "Y": "d8a83a", "z": "8a6020", "s": "f0e6cc", "S": "b8a888",
         "T": "d03a3a", **STEEL}

AXES = {
    # A plain bearded iron axe with a top spike and two rivets.
    "hewer": {
        "haft": "banded",
        "head": {
            3: [(3, "o")], 4: [(3, "o2o")], 5: [(4, "o23o")], 7: [(4, "ooo")],
            8: [(4, "o122")],
            9: [(3, "o12234"), (9, "25")],
            10: [(2, "o1233544"), (10, "35")],
            11: [(1, "o123333444"), (11, "35")],
            12: [(1, "o1233333544")],
            13: [(2, "o1233333444")],
            14: [(3, "o1233333445")],
            15: [(4, "o1233334455")],
            16: [(5, "o1233444555")],
            17: [(6, "o1245555555")],
            18: [(7, "oooooooooo")],
        },
    },
    # A steel crescent with an amber inlay, a gold collar with a gem, and an amber knob behind.
    "amberaxe": {
        "haft": "honey",
        "back": {5: [(7, "ooo")], 6: [(8, "aAo")], 7: [(9, "Abo")], 8: [(10, "o")]},
        "head": {
            5: [(3, "ooo")],
            6: [(2, "o122")],
            7: [(2, "o1223")],
            8: [(2, "o12aA3")],
            9: [(1, "o12aaAA4"), (9, "Yz")],
            10: [(1, "o12aaAAb4"), (10, "gz")],
            11: [(1, "o12aAAAbb4"), (11, "Yz")],
            12: [(1, "o12aAAAbbY4")],
            13: [(1, "o12AAAbbbYY4")],
            14: [(1, "o12AAbbbY44o")],
            15: [(1, "o12Abbb44o")],
            16: [(2, "o12b45o")],
            17: [(3, "o15o")],
            18: [(4, "oo")],
        },
    },
    # Dark steel with a green inlay, a fang hanging from the beard, and a serpent's head on top
    # whose eye glows; green coils wind down the haft.
    "venomaxe": {
        "haft": "serpent",
        "head": {
            1: [(3, "ooo")],
            2: [(1, "ToaAAo")],
            3: [(1, "oaAgbo")],
            4: [(1, "oAAbbo")],
            5: [(3, "obAb")],
            7: [(4, "ooo")],
            8: [(4, "o122")],
            9: [(3, "o12a44"), (9, "45")],
            10: [(2, "o12aA344"), (10, "45")],
            11: [(1, "o12aAAb344"), (11, "45")],
            12: [(1, "o12aAAbb344")],
            13: [(2, "o12AAbbb444")],
            14: [(3, "o12Abbb4445")],
            15: [(4, "o12bb444555")],
            16: [(5, "o1244455555")],
            17: [(6, "o1455555555")],
            18: [(7, "osSoooooooo")],
            19: [(7, "osSo")],
            20: [(8, "oSo")],
            21: [(9, "o")],
        },
    },
    # Two feathered silver wings, mirrored across the haft, round a gold collar with a blue gem.
    "seraphaxe": {
        "haft": "seraph",
        "wing": {
            5: [(3, "ooo")],
            6: [(2, "o122")],
            7: [(2, "o1222")],
            8: [(1, "o112223")],
            9: [(1, "o1222233")],
            10: [(2, "o3333334")],
            11: [(1, "o112222234")],
            12: [(1, "o1222222234")],
            13: [(2, "o3333333334")],
            14: [(1, "o1122222234o")],
            15: [(2, "o12222234o")],
            16: [(3, "o12234o")],
            17: [(4, "ooooo")],
        },
        "head": {9: [(9, "Yz")], 10: [(10, "gz")], 11: [(11, "Yz")]},
    },
    # A crimson crescent rimmed in gold with a round cut-out, a hook behind, and a glowing heart.
    "sanguineaxe": {
        "haft": "bone",
        "back": {3: [(9, "oo")], 4: [(8, "oAo")], 5: [(8, "Abo")], 6: [(8, "bo")]},
        "head": {
            5: [(3, "ooo")],
            6: [(2, "o1yy")],
            7: [(2, "o1yaA")],
            8: [(2, "o1yaAb")],
            9: [(1, "o12yaAAb"), (9, "Yz")],
            10: [(1, "o12yaooAb"), (10, "gz")],
            11: [(1, "o12yo..oAb"), (11, "Yz")],
            12: [(1, "o12yo..obbY")],
            13: [(1, "o12yaoobbbY4")],
            14: [(1, "o12yabbbY44o")],
            15: [(1, "o12ybbb44o")],
            16: [(2, "o1yb45o")],
            17: [(3, "o15o")],
            18: [(4, "oo")],
        },
    },
    # Two steel crescents with teal inlays and gold rims, mirrored; starlight glints on them.
    "starsteelaxe": {
        "haft": "runed",
        "sparks": [(5, 11), (11, 5), (3, 14), (14, 3)],
        "wing": {
            5: [(3, "ooo")],
            6: [(2, "o122")],
            7: [(2, "o1223")],
            8: [(2, "o12aA3")],
            9: [(1, "o12aaAy4")],
            10: [(1, "o12aAAb44")],
            11: [(1, "o12aAAbb44")],
            12: [(1, "o12aAAbbb44")],
            13: [(1, "o12AAbbb4444")],
            14: [(1, "o12Abbb4445o")],
            15: [(1, "o12bbb445o")],
            16: [(2, "o12445o")],
            17: [(3, "o15o")],
            18: [(4, "oo")],
        },
        "head": {9: [(9, "Yz")], 10: [(10, "gz")], 11: [(11, "Yz")]},
    },
}
STYLES = tuple(AXES)


def _rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def _lightness(rgb, delta):
    h, l, s = colorsys.rgb_to_hls(*(c / 255 for c in rgb))
    return tuple(round(c * 255) for c in colorsys.hls_to_rgb(h, max(0.0, min(1.0, l + delta)), s))


def _palette(style, colors, frame):
    main, light, accent = (_rgb(c) for c in colors)
    base = accent if style == "amberaxe" else main
    glow = 0.5 + 0.5 * math.cos(frame * math.tau / ANIM_FRAMES)
    palette = {key: _rgb(value) for key, value in FIXED.items()}
    palette.update({"a": _lightness(base, 0.14), "A": base, "b": _lightness(base, -0.14),
                    "g": _lightness(_rgb(colors[2]), -0.12 + 0.22 * glow)})
    return palette


def _place(pixels, segments, palette, mirror=False):
    for row, runs in segments.items():
        for column, text in runs:
            for offset, letter in enumerate(text):
                if letter == ".":
                    continue
                x, y = column + offset, row
                for px, py in ((x, y), (y, x)) if mirror else ((x, y),):
                    if 0 <= px < 32 and 0 <= py < 32:
                        pixels[py][px] = palette[letter] + (255,)


def _haft(pixels, palette, axe, colors, frame):
    """The axe's haft (pixel_hafts.py) inside a dark outline."""
    haft = {}

    def put(x, y, color):
        haft[(x, y)] = color

    pixel_hafts.draw(put, axe["haft"], HAFT_TOP, HAFT_END, _rgb(colors[0]), _rgb(colors[2]), frame)
    for x, y in haft:
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if (nx, ny) not in haft and 0 <= nx < 32 and 0 <= ny < 32:
                pixels[ny][nx] = palette["o"] + (255,)
    for (x, y), color in haft.items():
        pixels[y][x] = tuple(color[:3]) + (255,)


def icon(style, colors, frame=0):
    """RGBA rows of a 32x32 hand-pixelled axe icon; frame pulses its gem and moves its glints."""
    axe = AXES[style]
    palette = _palette(style, colors, frame)
    pixels = [[None] * 32 for _ in range(32)]
    _place(pixels, axe.get("back", {}), palette)
    _place(pixels, axe.get("wing", {}), palette, mirror=True)
    _haft(pixels, palette, axe, colors, frame)
    _place(pixels, axe.get("wing", {}), palette)
    _place(pixels, axe["head"], palette)
    sparks = axe.get("sparks", [])
    if sparks and frame < 8:
        x, y = sparks[frame // 2]
        if pixels[y][x] is not None:
            pixels[y][x] = (255, 255, 255, 255)
    # Drawn from the top-left corner; SHIFT centres it in the icon.
    dx, dy = SHIFT
    return [[pixels[y - dy][x - dx] if 0 <= x - dx < 32 and 0 <= y - dy < 32 else None for x in range(32)]
            for y in range(32)]
