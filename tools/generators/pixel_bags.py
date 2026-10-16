"""Hand-pixelled backpack icons (32x32), seen from the front like classic item icons.

BASE is the left half of a backpack, one letter per pixel; the right half is its mirror, with
the left-edge highlights turned into right-edge shadows. Each style then lays its own details on
top as {row: [(first column, "pixels"), ...]}. Letters:

  o outline     a A b body (light, base, dark)     e c C d flap (edge light, light, base, dark)
  s S strap     y Y z gold                          k K the style's accent (light, dark)
  w W white or bone (light, dark)    g a glowing light (pulses)     r R rope    l L leaf green

make_sprites.py calls icon(style, colors, frame).
"""

import colorsys
import math

ANIM_FRAMES = 12

BASE = [
    "................",
    "................",
    ".............ooo",
    "............osss",
    "............oso.",
    "............oso.",
    "..........oooooo",
    ".........occsscc",
    "........oecCssCC",
    "........oeCCssCC",
    ".......oeCCCssCC",
    ".......oeCCCssCC",
    ".......oedCCssCC",
    ".......oadddyYdd",
    ".......oaaAAyYAA",
    ".......oaAAAAAAA",
    ".......oaAAAAAAA",
    "......oaAAAAAAAA",
    "......oaAAAAAAAA",
    "......oaAAoooooo",
    "......oaAAoecccc",
    "......oaAAoeCCCC",
    "......oaAAoeCCCC",
    "......oaAAoeCCCy",
    "......oaAAoeCCCC",
    "......obAAoddddd",
    "......obbAoooooo",
    ".......obbbbbbbb",
    "........oooooooo",
    "................",
    "................",
    "................",
]
# The right half: left-edge highlights become right-edge shadows.
MIRROR = {"a": "b", "e": "d", "s": "S", "y": "Y"}

FIXED = {"o": "1c1618", "s": "8a6440", "S": "5c3c24", "y": "f8e08a", "Y": "d8a83a", "z": "8a6020",
         "w": "f4f0e6", "W": "c8c0b0", "r": "c8a878", "R": "8a6a40", "l": "7ac04a", "L": "3e7a2a"}

STYLES = {
    # A bedroll strapped across the top.
    "adventurer": {
        3: [(5, "oooooooooooooooooooooo")],
        4: [(4, "orrrrrrrrrrrrrrrrrrrrRo")],
        5: [(4, "orwrrrrrrrrrrrrrrrrrRRo")],
        6: [(4, "oRRRRRRRRRRRRRRRRRRRRRo")],
        7: [(5, "oooooooooooooooooooooo")],
    },
    # A lily on the flap and a pad hanging at the side.
    "lilypad": {
        7: [(14, "kk"), (17, "k")],
        8: [(13, "kKk"), (16, "Kkk")],
        9: [(14, "kyyk")],
        10: [(13, "kkyyK")],
        11: [(14, "KkK")],
        16: [(24, "oll")],
        17: [(24, "olllo")],
        18: [(24, "oLlLo")],
        19: [(25, "oLo")],
    },
    # A plump white pillow with tufted corners.
    "pillow": {
        6: [(8, "o"), (23, "o")],
        5: [(8, "oo"), (22, "oo")],
        26: [(5, "oo"), (25, "oo")],
    },
    # A coil of rope at the side and an anchor on the pocket.
    "sailor": {
        14: [(23, "orro")],
        15: [(22, "orRRro")],
        16: [(22, "oRooRo")],
        17: [(22, "orooro")],
        18: [(22, "oRrrRo")],
        19: [(23, "oooo")],
        20: [(15, "o")],
        21: [(14, "oWo")],
        22: [(15, "W")],
        23: [(13, "oWWWo")],
        24: [(13, "W.W.W")],
    },
    # Feathered wings spreading from the sides.
    "winged": {
        9: [(2, "oo"), (28, "oo")],
        10: [(1, "owwo"), (27, "oWWo")],
        11: [(1, "owwwo"), (26, "oWWWo")],
        12: [(2, "owwwo"), (25, "oWWWo")],
        13: [(2, "oWwwo"), (25, "oWWWo")],
        14: [(3, "owWo"), (25, "oWWo")],
        15: [(3, "oWwo"), (25, "oWWo")],
        16: [(4, "ooo"), (25, "ooo")],
    },
    # A grinning skull on the flap whose eyes glow.
    "ghost": {
        8: [(14, "wwww")],
        9: [(13, "wgwwgw")],
        10: [(13, "wwwwwW")],
        11: [(14, "WoWo")],
    },
    # Gold-trimmed edges and a rune glowing on the pocket.
    "holding": {
        13: [(8, "yyyyyyyyyyyyyyyy")],
        20: [(12, "yyyyyyyy")],
        22: [(15, "gg")],
        23: [(14, "g"), (17, "g")],
        24: [(15, "gg")],
        27: [(8, "zzzzzzzzzzzzzzzz")],
    },
}


def _rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def _shift(rgb, delta):
    h, l, s = colorsys.rgb_to_hls(*(c / 255 for c in rgb))
    return tuple(round(c * 255) for c in colorsys.hls_to_rgb(h, max(0.0, min(1.0, l + delta)), s))


def _palette(colors, frame):
    main, light, accent = (_rgb(c) for c in colors)
    glow = 0.5 + 0.5 * math.cos(frame * math.tau / ANIM_FRAMES)
    palette = {key: _rgb(value) for key, value in FIXED.items()}
    palette.update({"a": _shift(main, 0.12), "A": main, "b": _shift(main, -0.14),
                    "e": _shift(light, 0.12), "c": _shift(light, 0.04), "C": light, "d": _shift(light, -0.16),
                    "k": accent, "K": _shift(accent, -0.16), "g": _shift(accent, -0.15 + 0.25 * glow)})
    return palette


def _base_rows():
    rows = []
    for half in BASE:
        right = "".join(MIRROR.get(letter, letter) for letter in reversed(half))
        rows.append(half + right)
    return rows


def icon(style, colors, frame=0):
    """RGBA rows of a 32x32 backpack icon; frame pulses its glowing details."""
    palette = _palette(colors, frame)
    pixels = [[None] * 32 for _ in range(32)]
    for y, row in enumerate(_base_rows()):
        for x, letter in enumerate(row):
            if letter != ".":
                pixels[y][x] = palette[letter] + (255,)
    for y, runs in STYLES[style].items():
        for column, text in runs:
            for offset, letter in enumerate(text):
                if letter != "." and 0 <= column + offset < 32:
                    pixels[y][column + offset] = palette[letter] + (255,)
    return pixels
