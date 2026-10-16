"""Hand-drawn backpack icons (32x32) in the classic item-icon style: seen from slightly above and
to the left, so the rounded lid, the front, and the right side show.

BASE is a hand-drawn map of the backpack's parts, one letter per pixel. Each part is shaded by
code from the same top-left light as a solid with its own curvature (the lid a dome, the front
a slight bulge, the side in shadow), in a five-tone ramp of its material, with a grainy leather
texture; a dark outline goes round the silhouette and a darker seam wherever two parts meet.
Each style lays its own hand-drawn parts on top (DETAILS), shaded the same way.

Parts:  H handle   L lid   F front   S right side   P pocket   Q pocket flap   R side pocket
        T strap    B buckle
Detail parts use the same idea with their own letters (see MATERIALS).

make_sprites.py calls icon(style, colors, frame).
"""

import colorsys
import math

ANIM_FRAMES = 12

BASE = [
    "................................",
    "................................",
    "..............HHHH..............",
    ".............HH..HH.............",
    ".............H....H.............",
    "...........LLHLLLLHLL...........",
    ".........LLLLLLLLLLLLLL.........",
    "........LLLLLLLLLLLLLLLLL.......",
    ".......LLLTTLLLLLLTTLLLLLL......",
    ".......LLLTTLLLLLLTTLLLLLLS.....",
    ".......LLLTTLLLLLLTTLLLLLLS.....",
    ".......LLLTTLLLLLLTTLLLLLSSS....",
    "........LLTTLLLLLLTTLLLLLSSS....",
    "........FLTTLLLLLLTTLLLLFSSS....",
    ".......FFFTTFFFFFFTTFFFFFSSSS...",
    ".......FFFBBFFFFFFBBFFFFFSSSS...",
    ".......FFFBBFFFFFFBBFFFFFSRRS...",
    ".......FFFFFFFFFFFFFFFFFFRRRR...",
    ".......FFFFFFFFFFFFFFFFFFRRRR...",
    ".......FFQQQQQQQQQQQQQFFFRRRR...",
    ".......FFQQQQQQQQQQQQQFFFRRRR...",
    ".......FFPPPPPPPPPPPPPFFFRRRR...",
    ".......FFPPPPPPPPPPPPPFFFSRRS...",
    ".......FFPPPPPPPPPPPPPFFFSSSS...",
    ".......FFPPPPPPPPPPPPPFFFSSSS...",
    ".......FFPPPPPPPPPPPPPFFFSSS....",
    "........FFPPPPPPPPPPPFFFSSS.....",
    "........FFFFFFFFFFFFFFFFSS......",
    ".........FFFFFFFFFFFFFFS........",
    "................................",
    "................................",
    "................................",
]

# Where each part bulges towards the light: (centre x, centre y, half width, half height, depth).
# Depth 1 is a full dome; small depths are nearly flat faces.
SHAPES = {"L": (15.5, 9.0, 9.5, 5.0, 0.9), "F": (14.5, 20.0, 9.0, 9.5, 0.45), "S": (26.5, 19.0, 2.5, 9.0, 0.2),
          "P": (15.0, 23.5, 7.0, 3.5, 0.7), "Q": (15.0, 19.5, 7.0, 1.6, 0.5), "R": (26.5, 19.5, 2.2, 3.5, 0.6),
          "H": (15.5, 3.0, 2.5, 1.5, 0.6), "T": (0, 0, 1.0, 9.0, 0.3), "B": (0, 0, 1.0, 1.0, 0.8)}
# Faces turned away from the light start darker.
FACE_BIAS = {"S": 1.2, "R": 0.8, "Q": 0.2, "T": 0.2, "F": 0.15, "Z": 1.0}
LIGHT = (-0.55, -0.65, 0.52)

# Style details: hand-drawn part maps laid over the base (same letters as their MATERIALS key).
DETAILS = {
    "adventurer": {
        "rows": {
            2: "......oooooooooooooooooooo......",
            3: ".....oVVVVTTVVVVVVTTVVVVVVo.....",
            4: ".....oVVVVTTVVVVVVTTVVVVVVo.....",
            5: ".....oVVVVTTVVVVVVTTVVVVVVo.....",
            6: "......oooooooooooooooooooo......",
        },
        "shapes": {"V": (15.5, 4.0, 10.5, 1.6, 0.9)},
    },
    "lilypad": {
        "rows": {
            8: "...............N.N..............",
            9: "..............NNYNN.............",
            10: ".............NNYYYNN............",
            11: "..............NNYNN.............",
            12: "...............N.N..............",
            16: "............................GG..",
            17: "...........................GGGG.",
            18: "...........................GGGG.",
            19: "............................GG..",
        },
        "shapes": {"N": (15.5, 10.0, 2.5, 2.5, 0.8), "Y": (15.5, 10.0, 1.0, 1.0, 0.9), "G": (29.0, 17.5, 2.0, 2.0, 0.7)},
    },
    "pillow": {
        "rows": {
            5: "........W..............W........",
            6: ".......WW..............WW.......",
            27: ".......WW..............WW.......",
            28: "........W..............W........",
        },
        "shapes": {"W": (15.5, 16.0, 9.0, 12.0, 0.6)},
    },
    "sailor": {
        "rows": {
            13: "...........................KKKK.",
            14: "..........................KKKKKK",
            15: "..........................KK..KK",
            16: "..........................KK..KK",
            17: "..........................KKKKKK",
            18: "...........................KKKK.",
            21: "...............I................",
            22: "..............III...............",
            23: "...............I................",
            24: ".............I.I.I..............",
            25: "..............III...............",
        },
        "shapes": {"K": (28.5, 15.5, 3.0, 3.0, 0.8), "I": (15.0, 23.0, 2.0, 2.5, 0.6)},
    },
    "winged": {
        "rows": {
            1: "..WW........................WW..",
            2: ".WWWW......................WWWW.",
            3: "WWWWWW....................WWWWWW",
            4: "WWZWWWW..................WWWWZWW",
            5: "WWWZWWWW................WWWWZWWW",
            6: ".WWWZWWWWW............WWWWWZWWW.",
            7: "..WWWWZWWW............WWWZWWWW..",
            8: "...WWWWWWW............WWWWWWW...",
            9: "....WWWWW..............WWWWW....",
            10: "......WWW..............WWW......",
        },
        "shapes": {"W": (15.5, 6.0, 16.0, 3.5, 0.7), "Z": (15.5, 6.0, 16.0, 3.5, 0.7)},
    },
    "ghost": {
        "rows": {
            6: "..............XXXXX.............",
            7: ".............XXXXXXX............",
            8: "............XXXXXXXXX...........",
            9: "............XooXXXooX...........",
            10: "............XooXXXooX...........",
            11: ".............XXXoXXX............",
            12: "..............XoXoX.............",
            13: "..............XXXXX.............",
        },
        "shapes": {"X": (16.0, 9.5, 4.5, 4.0, 0.8)},
        "glow": [(13, 9), (14, 9), (18, 9), (19, 9), (13, 10), (14, 10), (18, 10), (19, 10)],
    },
    "holding": {
        "rows": {
            13: "........YYYYYYYYYYYYYYYYY.......",
            19: ".........YYYYYYYYYYYYY..........",
            27: "........YYYYYYYYYYYYYYYY........",
        },
        "shapes": {"Y": (15.5, 16.0, 10.0, 12.0, 0.4)},
        "glow": [(15, 22), (14, 23), (16, 23), (15, 24), (13, 23), (17, 23)],
    },
}

FIXED = {"o": (26, 18, 20), "strap": (122, 86, 54), "gold": (216, 168, 58), "white": (236, 230, 216),
         "leaf": (90, 154, 58), "petal": (240, 170, 210), "bone": (230, 222, 200), "rope": (190, 160, 110),
         "bedroll": (180, 150, 100), "steel": (150, 160, 168)}


def _rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def _ramp(color):
    """Five tones, lightest first: warm lights, cool shadows."""
    h, l, s = colorsys.rgb_to_hls(*(c / 255 for c in color))
    tones = []
    for dl, dh, ds in ((0.2, -0.02, -0.05), (0.09, -0.01, 0.0), (0.0, 0.0, 0.0), (-0.12, 0.015, 0.05), (-0.22, 0.03, 0.08)):
        tones.append(tuple(round(c * 255) for c in colorsys.hls_to_rgb((h + dh) % 1.0, max(0.02, min(0.97, l + dl)),
                                                                        max(0.0, min(1.0, s + ds)))))
    return tones


def _materials(style, colors):
    main, light, accent = (_rgb(c) for c in colors)
    body, lid = _ramp(main), _ramp(light)
    return {"L": lid, "F": body, "S": body, "P": lid, "Q": body, "R": body, "H": _ramp(FIXED["strap"]),
            "T": _ramp(FIXED["strap"]), "B": _ramp(FIXED["gold"]), "V": _ramp(FIXED["bedroll"]),
            "N": _ramp(FIXED["petal"]), "Y": _ramp(FIXED["gold"]), "G": _ramp(FIXED["leaf"]),
            "W": _ramp(FIXED["white"]), "Z": _ramp(FIXED["white"])[1:] + [_ramp(FIXED["white"])[4]], "K": _ramp(FIXED["rope"]), "I": _ramp(FIXED["steel"]),
            "X": _ramp(FIXED["bone"])}


def _hash(x, y, salt=0):
    return (x * 73856093 ^ y * 19349663 ^ salt * 83492791) & 0xFFFF


def _tone(part, shape, x, y, bias=0.0, grain=True):
    """The ramp index (0 lightest .. 4) of a part's pixel from its curvature and the light."""
    cx, cy, rx, ry, depth = shape
    if part in ("T", "B"):
        nx, ny = -0.6, -0.3
    else:
        nx = max(-1.0, min(1.0, (x + 0.5 - cx) / rx))
        ny = max(-1.0, min(1.0, (y + 0.5 - cy) / ry))
    nx, ny = nx * depth, ny * depth
    nz = math.sqrt(max(0.0, 1.0 - nx * nx - ny * ny))
    light = LIGHT[0] * nx + LIGHT[1] * ny + LIGHT[2] * nz
    level = (0.95 - light) * 3.2 + bias
    if grain and part in "LFSPQR":
        noise = _hash(x, y) % 9
        level += 0.55 if noise == 0 else -0.45 if noise == 1 else 0.0
    return max(0, min(4, round(level)))


def icon(style, colors, frame=0):
    """RGBA rows of a 32x32 backpack icon; frame pulses its glowing details."""
    materials = _materials(style, colors)
    detail = DETAILS[style]
    parts = [list(row) for row in BASE]
    shapes = dict(SHAPES)
    shapes.update(detail.get("shapes", {}))
    for y, row in detail["rows"].items():
        for x, letter in enumerate(row):
            if letter != ".":
                parts[y][x] = letter
    pixels = [[None] * 32 for _ in range(32)]
    for y in range(32):
        for x in range(32):
            part = parts[y][x]
            if part == ".":
                continue
            if part == "o":
                pixels[y][x] = FIXED["o"] + (255,)
                continue
            if style == "pillow" and part in "LFSPQR":
                ramp = materials["W"]
            else:
                ramp = materials[part]
            level = _tone(part, shapes[part], x, y, FACE_BIAS.get(part, 0.0))
            # A seam where this part meets another one below or to the right.
            for dx, dy in ((1, 0), (0, 1)):
                other = parts[y + dy][x + dx] if 0 <= x + dx < 32 and 0 <= y + dy < 32 else "."
                if other not in (".", part) and other != "o":
                    level = max(level, 4 if part not in "TBYX" else 3)
            pixels[y][x] = ramp[level] + (255,)
    # The outline round the silhouette, darker than any shade.
    solid = {(x, y) for y in range(32) for x in range(32) if pixels[y][x] is not None}
    for x, y in list(solid):
        if any((x + dx, y + dy) not in solid for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            pixels[y][x] = FIXED["o"] + (255,)
    # Glowing details (eyes, runes) pulse.
    glow = 0.5 + 0.5 * math.cos(frame * math.tau / ANIM_FRAMES)
    accent = _rgb(colors[2])
    for x, y in detail.get("glow", []):
        bright = tuple(min(255, round(c * (0.75 + 0.45 * glow))) for c in accent)
        pixels[y][x] = bright + (255,)
    return pixels
