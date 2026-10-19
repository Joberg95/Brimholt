"""Hand-pixelled cape and cloak icons (32x32) in the classic item-icon style: a cloak seen from the
front and turned a little, hanging from a rolled collar with a clasp, its cloth falling in folds lit
from the top-left, the right edge turned back to show the lining, and a hem that swings.

BASE is the shared cloak, one letter per pixel, hand-placed tone by tone (the folds are drawn, not
computed). Each style lays its own hand-placed segments on top ({row: [(first column, "pixels")]},
"." leaves a pixel as it is), most of them relative to the cloth underneath, so embroidery, scales,
and singed patches follow the folds. Then a dark outline goes round the silhouette, a seam shades
the cloth under the collar, and a trim runs along the hem just inside the outline.

BASE letters:   1-5 cloth (the item's main colour, lightest to deepest fold)
                l m lining (the light colour, turned away so in shadow)
                c C d collar (lit, mid, shaded)      n the dark inside of the collar
                K the clasp (gold, shaded as a dome)
Style letters:  + - the cloth underneath one tone lighter / darker
                a   the accent, as light as the cloth underneath     A the accent, bright
                y   gold, as light as the cloth underneath           w white (silver, silk, ermine)
                f   fur (lit by the light)                           k a dark spot or stitch
                E   eye white    i iris (fixed amber)                g a glowing core (pulses)
                _   erases the pixel (ragged hems, cut edges); any BASE letter reshapes the cloak

make_sprites.py calls icon(style, colors, frame) for the item icon and icon(..., back=True) for the
texture of the worn cape.
"""

import math

import pixel_bags as B

ANIM_FRAMES = 12

BASE = [
    "................................",  # 0
    "................................",  # 1
    "................................",  # 2
    "............cccccCdd............",  # 3
    "...........cCnnnnnnCd...........",  # 4
    "..........ccCnnnnnnCdd..........",  # 5
    ".........cccCCnnnnCCddd.........",  # 6
    "........21ccccCCCCCCdd34m.......",  # 7
    ".......2113ccKKKKCCdd344lm......",  # 8
    "......211342KKKKKK344234lm......",  # 9
    "......211342KKKKKK342344lm......",  # 10
    "......2113452KKKK23342344lm.....",  # 11
    ".....21122441223334522333lm.....",  # 12
    ".....21122451223334522342lm.....",  # 13
    ".....21122451223334522442lm.....",  # 14
    ".....21124522233334522452lm.....",  # 15
    ".....21124522234124522452lm.....",  # 16
    ".....21124522244124522452lm.....",  # 17
    ".....21124522245124522452llm....",  # 18
    "....2112245222451234524522lm....",  # 19
    "....2112245222452234524522lm....",  # 20
    "....2112245222452234522452llm...",  # 21
    "....2112452223452234522452llm...",  # 22
    "....2112452224522334522452llm...",  # 23
    "....21124522245223345224522lm...",  # 24
    "....21124522245223345224522llm..",  # 25
    "....211245222452233452245223llm.",  # 26
    "....211245222452233452245223lll.",  # 27
    ".....2114.2224.22334.224.223ll..",  # 28
    "......21...22...234...4...3ll...",  # 29
    "................................",  # 30
    "................................",  # 31
]

CLOTH = "12345"
COLLAR = {"c": 1, "C": 2, "d": 3}
LINING = {"l": 2, "m": 3}
OUTLINE = B.FIXED["o"]
FIXED = {"gold": (216, 168, 58), "white": (236, 232, 222), "iris": (200, 96, 40), "eye": (240, 232, 214),
         "ermine": (244, 240, 230)}
CLASP = (14.5, 9.5, 3.0, 2.0, 0.9)

STYLES = {
    # Grey-green wool with a silver hem and three green leaves stitched above it.
    "silverleaf": {
        "hem": "w",
        "segments": {
            20: [(5, "...Vv"), (19, "...Vv")],
            21: [(5, "..Vvv"), (12, "...Vv"), (19, "..Vvv")],
            22: [(5, ".Vvvb"), (12, "..Vvv"), (19, ".Vvvb")],
            23: [(5, ".vbb."), (12, ".Vvvb"), (19, ".vbb.")],
            24: [(5, "b"), (12, ".vbb."), (19, "b")],
            25: [(12, "b")],
        },
    },
    # Pale silk with a dark web spun across its back and a spider-dark clasp.
    "matronsilk": {
        "hem": "a",
        "clasp": "a",
        "segments": {
            13: [(10, "a....a....a")],
            14: [(11, "a...a...a")],
            15: [(12, "aaaaaaa")],
            16: [(9, "a.a..a..a.a")],
            17: [(11, "a.aaa.a")],
            18: [(7, "aaaaaa.aaa.aaaaaa")],
            19: [(11, "a.aaa.a")],
            20: [(9, "a.a..a..a.a")],
            21: [(12, "aaaaaaa")],
            22: [(11, "a...a...a")],
            23: [(10, "a....a....a")],
        },
    },
    # Cobalt wool with a pale double hem band, a row of lozenges between, and a silver clasp.
    "cobalt": {
        "hem": "A",
        "clasp": "w",
        "segments": {
            23: [(5, "aaaaaaaaaaaaaaaaaaaaa")],
            24: [(5, ".-a-.-a-.-a-.-a-.-a-.")],
            25: [(5, "-aaa-aaa-aaa-aaa-aaa-")],
            26: [(5, ".-a-.-a-.-a-.-a-.-a-.")],
        },
    },
    # Rust-red wool singed black along a ragged hem, embers still glowing in it.
    "ember": {
        "segments": {
            21: [(6, "-..-...-....-...-..-")],
            22: [(5, "-.--.-.--.--.-.--.--")],
            23: [(5, "-s--s-ss--.-s--.-s--s")],
            24: [(4, "ss-sss-ss-sss-ss-ss-ss")],
            25: [(4, "sssAsssssssAssssssAsss")],
            26: [(4, "ssAasssAssssssasssAsss")],
            27: [(4, "sAsss_ssAs_sssAss_sssA")],
            28: [(5, "_sAs._s._A.s_._s.")],
            29: [(6, "s....._....s")],
        },
    },
    # Dusk-violet cloth fading darker to the hem, a pale crescent moon and two stars on its back.
    "dusk": {
        "hem": "a",
        "segments": {
            12: [(16, "AA")],
            13: [(15, "AA.."), (21, "a")],
            14: [(14, "AA"), (20, "aAa")],
            15: [(14, "A."), (21, "a")],
            16: [(14, "AA")],
            17: [(15, "AA"), (10, "a")],
            18: [(16, "AA"), (9, "aAa")],
            19: [(10, "a")],
            22: [(5, "--------------------")],
            23: [(5, "---------------------")],
            24: [(5, "---------------------")],
            25: [(5, "----------------------")],
            26: [(5, "----------------------")],
            27: [(5, "----------------------")],
        },
    },
    # Rough tanned hide, patched and stitched, under a shaggy fur collar, a great eye painted on it.
    "cyclopshide": {
        "collar": "fur",
        "clasp": "k",
        "segments": {
            2: [(12, "f.ff.f")],
            3: [(11, "f"), (20, "f")],
            6: [(8, "f"), (23, "f")],
            7: [(7, "ff"), (22, "fff")],
            8: [(6, "fff"), (22, "ff")],
            9: [(6, "f")],
            12: [(7, "k")],
            13: [(8, "k"), (22, "-+")],
            14: [(12, "kkkkkkk"), (21, "-++")],
            15: [(10, "kkEEiiiEEkk"), (22, "--")],
            16: [(9, "kEEEiEiiiEEEk")],
            17: [(9, "kEEEiikiiEEEk")],
            18: [(9, "kEEEiikiiEEEk")],
            19: [(10, "kkEEiiiEEkk")],
            20: [(12, "kkkkkkk")],
            21: [(7, "+-")],
            22: [(6, "-++-"), (22, "k")],
            23: [(6, "--"), (23, "k")],
            24: [(24, "k")],
            27: [(9, "_")],
            28: [(5, "_"), (12, "__"), (22, "_")],
            29: [(7, "_"), (18, "_"), (28, "_")],
        },
    },
    # Golden cloth woven with pale blue stars, a blue hem.
    "starweave": {
        "hem": "a",
        "segments": {
            9: [(20, "..A..")],
            10: [(20, ".bAb.")],
            11: [(20, "AAwAA")],
            12: [(20, ".bAb.")],
            13: [(20, "..A..")],
            14: [(6, "..A..")],
            15: [(6, ".bAb."), (15, "a")],
            16: [(6, "AAwAA")],
            17: [(6, ".bAb.")],
            18: [(6, "..A.."), (22, "a")],
            19: [(13, "..A..")],
            20: [(13, ".bAb.")],
            21: [(13, "AAwAA")],
            22: [(13, ".bAb."), (7, "a")],
            23: [(13, "..A..")],
            24: [(21, "a")],
        },
    },
    # Teal wyrm scales, row on staggered row, with a red-gem clasp and a red hem.
    "wyrmscale": {
        "hem": "A",
        "clasp_gem": True,
        "scales": (12, 27),
    },
    # Black cloth lined red, its shoulders swept out into wings with gold claws, red ribs running
    # down to a hem cut into wing points, a gold clasp with an ember.
    "emberwing": {
        "clasp_gem": True,
        "ribs": [(8, 10, 4, 28), (11, 12, 10, 28), (15, 13, 16, 29), (19, 12, 22, 28)],
        "points": (4, 10, 16, 22, 28),
        "segments": {
            8: [(6, "2"), (25, "m")],
            9: [(3, "y221"), (26, "lm")],
            10: [(2, "yy211"), (26, "llm"), (29, "y")],
            11: [(2, "2111"), (26, "lllyy")],
            12: [(2, "211"), (27, "lmm")],
            13: [(2, "21"), (27, "lm")],
            14: [(3, "21"), (27, "lm")],
            15: [(3, "2"), (27, "m")],
            16: [(4, "2")],
        },
    },
    # Deep violet cloth wound with dark green vines and pale blooms whose hearts glow.
    "hollowbloom": {
        "hem": "a",
        "segments": {
            9: [(19, ".pp.")],
            10: [(19, "pggp")],
            11: [(19, "pggp")],
            12: [(19, ".pp."), (18, "j")],
            13: [(17, "j"), (7, ".pp.")],
            14: [(16, "j"), (7, "pggp")],
            15: [(15, "j"), (7, "pggp")],
            16: [(7, ".pp."), (11, "j"), (14, "j")],
            17: [(12, "jj")],
            18: [(13, "j"), (17, ".pp.")],
            19: [(13, "j"), (17, "pggp")],
            20: [(13, "jj"), (17, "pggp")],
            21: [(12, "j"), (15, "j"), (17, ".pp.")],
            22: [(8, ".pp."), (11, "j")],
            23: [(8, "pggp")],
            24: [(8, "pggp")],
            25: [(8, ".pp.")],
        },
        "glow": [(20, 10), (21, 10), (20, 11), (21, 11), (8, 14), (9, 14), (8, 15), (9, 15),
                 (18, 19), (19, 19), (18, 20), (19, 20), (9, 23), (10, 23), (9, 24), (10, 24)],
    },
    # A royal purple mantle under a broad spotted ermine capelet, a great gold clasp with a glowing
    # gem, a gold hem, and a train that sweeps out to the right.
    "sovereign": {
        "hem": "y",
        "collar": "ermine",
        "clasp_gem": True,
        "segments": {
            6: [(8, "c"), (23, "d")],
            7: [(7, "ccc"), (22, "ddd")],
            8: [(6, "ccccc"), (21, "dddddd")],
            9: [(5, "cccccCc"), (18, "CCddddddd")],
            10: [(5, "ccCccCc"), (18, "CCCdddddd")],
            11: [(4, "cCcccCcCc"), (17, "CcCCCCdddd")],
            12: [(4, "dCCCCCCCCCCCCCCCCCCdddd")],
            13: [(8, "ddddddddddddddd")],
            25: [(3, "2"), (28, "lm")],
            26: [(3, "21"), (30, "m")],
            27: [(3, "22"), (30, "m")],
            28: [(3, "212"), (28, "lmm")],
            29: [(4, "2_"), (9, "2"), (12, "22"), (16, "3"), (21, "4"), (24, "4"), (27, "lm")],
        },
        "spots": [(7, 9), (10, 11), (14, 12), (19, 11), (22, 9), (25, 11)],
        "glow": [(14, 9), (15, 9), (14, 10), (15, 10)],
    },
}


def _rgb(value):
    return B._rgb(value)


FUR = (164, 142, 108)
VINE = (76, 128, 70)
SOOT = (74, 50, 42)


def _materials(style, colors):
    main, light, accent = (_rgb(c) for c in colors)
    collar = {"light": light, "fur": FUR, "ermine": FIXED["ermine"]}[STYLES[style].get("collar", "light")]
    return {"cloth": B._ramp(main), "lining": B._ramp(light), "collar": B._ramp(collar), "accent": B._ramp(accent),
            "gold": B._ramp(FIXED["gold"]), "white": B._ramp(FIXED["white"]), "eye": B._ramp(FIXED["eye"]),
            "iris": B._ramp(FIXED["iris"]), "soot": B._ramp(SOOT), "vine": B._ramp(VINE)}


def _line(x0, y0, x1, y1):
    steps = max(abs(x1 - x0), abs(y1 - y0))
    return [(round(x0 + (x1 - x0) * t / steps), round(y0 + (y1 - y0) * t / steps)) for t in range(steps + 1)]


def _layout(style):
    """The BASE letters with the style's segments laid over them, plus its stamped patterns: wyrm
    scales, a hem cut into wing points, and ribs running down to the points."""
    parts = [list(row) for row in BASE]
    detail = STYLES[style]
    if "scales" in detail:
        # Staggered scales six pixels wide: a lit top, a shaded side, a dark rounded lower edge.
        top, bottom = detail["scales"]
        tile = (".++...", "-+....", "-.....", ".----.")
        for y in range(top, bottom + 1):
            course = (y - top) // 4
            for x in range(32):
                if parts[y][x] in CLOTH:
                    letter = tile[(y - top) % 4][(x + 3 * (course % 2)) % 6]
                    if letter != ".":
                        parts[y][x] = letter
    for row, runs in detail.get("segments", {}).items():
        for column, text in runs:
            for offset, letter in enumerate(text):
                if letter != "." and 0 <= column + offset < 32:
                    parts[row][column + offset] = letter
    points = detail.get("points")
    if points:
        # Each column hangs down to a wing point and curves up between two of them.
        for x in range(32):
            reach = min(abs(x - point) for point in points)
            lowest = 29 - (0, 1, 2, 3, 3)[min(4, reach)]
            for y in range(24, 32):
                if y > lowest:
                    parts[y][x] = "."
                elif parts[y][x] == "." and points[0] <= x <= points[-1] and y > 24:
                    parts[y][x] = "m" if x >= 27 else "4" if reach == 0 else "3"
    for x0, y0, x1, y1 in detail.get("ribs", []):
        for x, y in _line(x0, y0, x1, y1):
            if parts[y][x] in CLOTH:
                parts[y][x] = "r"
    return parts


def _cloth_tone(x, y):
    """The tone the BASE cloth has under a style pixel (2, the middle, where BASE has none)."""
    letter = BASE[y][x]
    return int(letter) - 1 if letter in CLOTH else 2


def icon(style, colors, frame=0, back=False):
    """RGBA rows of a 32x32 cloak icon; frame pulses its glowing blooms or gems. back=True is the
    texture the worn cape is filled from: seen from behind there is no clasp and no neck opening,
    the collar runs on across them."""
    detail = STYLES[style]
    ramps = _materials(style, colors)
    parts = _layout(style)
    clasped = {(x, y) for y in range(32) for x in range(32) if parts[y][x] == "K"}
    if back:
        parts = [["C" if letter in "nK" else letter for letter in row] for row in parts]
    glow = 0.5 + 0.5 * math.cos(frame * math.tau / ANIM_FRAMES)
    pixels = [[None] * 32 for _ in range(32)]
    clasp = detail.get("clasp", "y")
    for y in range(32):
        for x in range(32):
            part = parts[y][x]
            if part in "._":
                continue
            under = _cloth_tone(x, y)
            if part in CLOTH:
                color = ramps["cloth"][int(part) - 1]
            elif part in "+-":
                color = ramps["cloth"][max(0, min(4, under + (1 if part == "-" else -1)))]
            elif part in LINING:
                color = ramps["lining"][LINING[part]]
            elif part in COLLAR or part == "f":
                tone = COLLAR.get(part, 2)
                if detail.get("collar") == "fur":
                    noise = B._hash(x, y, 3) % 5
                    tone = max(0, min(4, tone + (-1 if noise == 0 else 1 if noise == 1 else 0)))
                color = ramps["collar"][tone]
            elif part == "n":
                color = ramps["cloth"][4] if detail.get("collar") != "ermine" else ramps["lining"][4]
            elif part == "K":
                tone = B._tone("K", CLASP, x, y, 0.0, grain=False)
                if clasp == "y":
                    color = ramps["gold"][tone]
                elif clasp == "w":
                    color = ramps["white"][min(4, tone + 1)]
                elif clasp == "a":
                    color = ramps["accent"][min(4, tone + 1)]
                else:
                    color = ramps["soot"][min(4, tone + 2)]
            elif part == "a":
                color = ramps["accent"][max(0, min(4, under - 1))]
            elif part == "A":
                color = ramps["accent"][0 if under < 3 else 1]
            elif part in "Vvb":
                color = ramps["accent"]["Vvb".index(part) + 1]
            elif part == "j":
                color = ramps["vine"][2 if (x + y) % 3 else 3]
            elif part == "r":
                color = ramps["lining"][max(1, min(4, under))]
            elif part == "p":
                color = ramps["lining"][0]
            elif part == "s":
                color = ramps["soot"][3 + B._hash(x, y, 7) % 2]
            elif part == "y":
                color = ramps["gold"][max(0, min(4, under - 1))]
            elif part == "w":
                color = ramps["white"][max(0, min(4, under))]
            elif part == "k":
                color = OUTLINE
            elif part == "E":
                color = ramps["eye"][1 if x < 15 else 2]
            elif part == "i":
                color = ramps["iris"][1 if y < 17 else 2]
            elif part == "g":
                color = ramps["accent"][0]
            else:
                raise ValueError(f"pixel_capes: unknown letter {part!r} in {style}")
            pixels[y][x] = color + (255,)
    # The cloth just under the collar and clasp lies in their shadow.
    for y in range(1, 32):
        for x in range(32):
            if parts[y][x] in CLOTH and parts[y - 1][x] in "cCdK":
                pixels[y][x] = ramps["cloth"][max(3, int(parts[y][x]) - 1)] + (255,)
    gem = [(14, 9), (15, 9), (14, 10), (15, 10)] if detail.get("clasp_gem") and not back else []
    for x, y in gem:
        pixels[y][x] = ramps["accent"][1 if (x, y) == (14, 9) else 2] + (255,)
    # Ermine tails: short black tufts two pixels long.
    for x, y in detail.get("spots", []):
        pixels[y][x] = pixels[y + 1][x] = OUTLINE + (255,)
    # The outline round the silhouette.
    solid = {(x, y) for y in range(32) for x in range(32) if pixels[y][x] is not None}
    edge = [(x, y) for x, y in solid
            if any((x + dx, y + dy) not in solid for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for x, y in edge:
        pixels[y][x] = OUTLINE + (255,)
    # The hem trim: the lowest pixel inside the outline in each column of the lower cloak.
    hem = detail.get("hem")
    if hem:
        ramp = {"a": ramps["accent"], "A": ramps["accent"], "w": ramps["white"], "y": ramps["gold"]}[hem]
        for x in range(32):
            column = [y for y in range(20, 32) if (x, y) in solid and pixels[y][x] != OUTLINE + (255,)]
            if column and parts[column[-1]][x] not in LINING:
                pixels[column[-1]][x] = ramp[1 if x < 16 or hem == "A" else 2] + (255,)
    # Glowing hearts and gems pulse.
    for x, y in detail.get("glow", []):
        if back and (x, y) in clasped:
            continue
        base = _rgb(colors[2])
        pixels[y][x] = tuple(min(255, round(c * (0.8 + 0.4 * glow))) for c in base) + (255,)
    return pixels
