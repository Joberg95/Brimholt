"""Charm icons (32x32) in the classic item-icon style: a talisman (a carved token, a shell, a caged
coal, an idol...) hung on a short leather cord loop with a wrapped knot, seen a little tilted with
the light from the top-left. Unlike the necklaces (pixel_necklaces.py: a long chain round a tilted
loop with a small pendant), the charm itself fills most of the icon and the cord is only a loop to
tie it by.

ROWS are hand-drawn part maps, one letter per pixel, every row exactly 32 characters. Each part is
shaded by code as in pixel_bags.py: five-tone ramps lit from the top-left with the style's dome (or
the part's own, SHAPES), darker seams where two materials meet, and a dark outline round the
silhouette (drawn outside it, so one-pixel cords survive).

Letters:  C cord (front)  c cord (back, in shadow)  N cord wrap and knot  B bail (gold)
          M main  L light  A accent  a accent in shadow  e the token's edge (main, in shadow)
          S stone (main, grained)  D a dark recess  F flame yellow  W white  Y gold  y gold in
          shadow  I iron  P a near-black pupil  o outline  K a glowing core (pulses)  k a glowing
          vein (pulses, weaker)

make_sprites.py calls icon(style, colors, frame).
"""

import math

import pixel_bags as B

ANIM_FRAMES = 12

FIXED = {"o": B.FIXED["o"], "strap": B.FIXED["strap"], "rope": B.FIXED["rope"], "gold": B.FIXED["gold"],
         "white": B.FIXED["white"], "iron": (98, 102, 112), "flame": (250, 206, 96), "pupil": (34, 26, 24), "soot": (70, 48, 40), "wood": (112, 72, 42)}

# Letter -> (material, shade bias). Materials: main, light, accent, or a FIXED key.
LETTERS = {"C": ("strap", 0.0), "c": ("strap", 1.4), "N": ("rope", 0.3), "B": ("gold", 0.0), "M": ("main", 0.0),
           "L": ("light", 0.0), "l": ("light", 1.0), "A": ("accent", 0.0), "a": ("accent", 1.5), "e": ("main", 1.6),
           "S": ("main", 0.0), "D": ("soot", 0.5), "H": ("wood", 0.0), "Q": ("gold", 1.5), "F": ("flame", -0.5), "W": ("white", -1.0), "Y": ("gold", -0.7),
           "y": ("gold", 1.0), "I": ("iron", 0.0), "P": ("pupil", 0.0), "K": ("accent", -2.0), "k": ("light", -1.0),
           "J": ("accent", -0.3)}
GRAINED = "S"
# Pulsing letters fade from their tone towards a darker, richer one by this many ramp steps.
PULSING = {"K": 2, "k": 1, "J": 1}

STYLES = {
    "hearth": {
        "dome": (15.5, 19.0, 9.0, 10.0, 0.6),
        "rows": [
            "................................",
            "................................",
            "............cccccc..............",
            "...........c......c.............",
            "...........C.......c............",
            "............C.....C.............",
            ".............CC..CC.............",
            "...............NN...............",
            "..............NNNN..............",
            "...............BB...............",
            "..............SSSS..............",
            "............SSSSSSSS............",
            "..........SSSSSSeSSSSS..........",
            ".........SSSSSSSeSSSSSe.........",
            ".........eeeeeeeeeeeeeee........",
            ".........SSSeSSSSSSSeSSe........",
            "........LLLLLLLLLLLLLLLL........",
            "........eLLLLLLLLLLLLLLe........",
            ".........SSDDDDDDDDDDSSe........",
            ".........SSDDDDDDDDDDSSe........",
            ".........SSDDDDDADDDDSSe........",
            ".........SSDDDDAADDDDSSe........",
            ".........SSDDDAAFADDDSSe........",
            ".........SSDDDAFFADDDSSe........",
            ".........SSDDAAFFAADDSSe........",
            ".........SSDDAFFFFADDSSe........",
            ".........SSDHHHHHHHHDSSe........",
            "........LLLLLLLLLLLLLLLLe.......",
            ".........eeeeeeeeeeeeeeee.......",
            "................................",
            "................................",
            "................................",
        ],
    },
    "tide": {
        "dome": (15.5, 19.0, 10.5, 9.0, 0.8),
        "shapes": {"A": (15.5, 10.0, 2.0, 1.5, 0.9)},
        "rows": [
            "................................",
            "................................",
            "............cccccc..............",
            "...........c......c.............",
            "...........C.......c............",
            "............C.....C.............",
            ".............CC..CC.............",
            "...............NN...............",
            "..............NNNN..............",
            "..............AAAA..............",
            "..............AAAA..............",
            ".........LLLLLLLLLLLLLL.........",
            ".........LLLLLMLLMLLLLL.........",
            "..........MMMMLLLLMMMM..........",
            "............LLLLLLLL............",
            "..........LLLlMMMMLLLL..........",
            ".........LLLlMMMMMMLLLL.........",
            "........LLLlMlMMMlMMLLLL........",
            ".......LLLLlMMlMMlMlMLLLL.......",
            "......LLLLlMlMlMlMMlMLLLLL......",
            ".....LLLLlMLlMlMlMlMlMLLLLL.....",
            ".....LLLLlMlMLlMlMlMLlMLLLL.....",
            ".....LLLlMLlMlMLlMLlMlMLLLL.....",
            "......LLlMlMLlMLlMLlMLlMLL......",
            "......LlMLlMLlMLlMLlMLLlML......",
            ".......MLLlMLlMLlMLLlMLlM.......",
            "........LL..LL.LL..LL.LL........",
            "................................",
            "................................",
            "................................",
            "................................",
            "................................",
        ],
    },
    "cinder": {
        "dome": (15.5, 18.5, 8.0, 8.0, 0.9),
        "letters": {"B": ("iron", 0.0)},
        "rows": [
            "................................",
            "................................",
            "............cccccc..............",
            "...........c......c.............",
            "...........C.......c............",
            "............C.....C.............",
            ".............CC..CC.............",
            "...............NN...............",
            "..............NNNN..............",
            "...............II...............",
            ".............IIIIII.............",
            "............IIIIIIII............",
            "..........IIIIIIIIIIII..........",
            ".........IMMMILLMLIMMLI.........",
            "........IMMMLILLMMIMMLLI........",
            "........IMMMLILLLMILMMMI........",
            "........IMMMLIAALLILMMMI........",
            "........ILLMLIAAALIMMMLI........",
            "........ILMMLIAAALIMLMMI........",
            "........IMMMLIAALLIMLMMI........",
            "........IMLLMILLLMIMLMMI........",
            "........IMMLMIMMMLIMMMMI........",
            "........IMMLMILLMMIMMLMI........",
            "........ILMMMIMMMMIMMLLI........",
            ".........IMMLIMMMMILMMI.........",
            "..........IIIIIIIIIIII..........",
            "............IIIIIIII............",
            ".............IIIIII.............",
            "...............II...............",
            "................................",
            "................................",
            "................................",
        ],
    },
    "dusk": {
        "dome": (17.0, 21.5, 11.0, 11.0, 0.75),
        "shapes": {"A": (9.5, 20.5, 1.9, 1.9, 0.9), "Y": (9.5, 20.5, 2.9, 2.9, 0.9)},
        "rows": [
            "................................",
            "................................",
            "............cccccc..............",
            "...........c......c.............",
            "...........C.......c............",
            "............C.....C.............",
            ".............CC..CC.............",
            "...............NN...............",
            "..............NNNN..............",
            "...............BB...............",
            "..............MM................",
            "...........MMMM.................",
            "..........MMMM..................",
            "........MMMMMM..................",
            "........MMMMM...................",
            ".......MMMMMM...................",
            ".......MMMMMM...................",
            "......MMMMMMM...................",
            "......MMYYYMM...................",
            "......MYWAAYM...................",
            "......MYAAAYMM..................",
            "......MYAAAYMM..................",
            "......MMYYYMMMM.................",
            ".......MMMMMMMMMM...............",
            ".......MMMMMMMMMMMM...MM........",
            "........MMMMMMMMMMMMMMM.........",
            "........MMMMMMMMMMMMMMM.........",
            "..........MMMMMMMMMMM...........",
            "...........MMMMMMMMM............",
            "..............MMM...............",
            "................................",
            "................................",
        ],
    },
    "star": {
        "dome": (16.0, 20.5, 12.0, 12.0, 0.3),
        "shapes": {"A": (16.0, 20.5, 2.9, 2.9, 0.95)},
        "letters": {"Q": ("gold", 2.2)},
        "rows": [
            "................................",
            "................................",
            "............cccccc..............",
            "...........c......c.............",
            "...........C.......c............",
            "............C.....C.............",
            ".............CC..CC.............",
            "...............NN...............",
            "..............NNNN..............",
            "..............YBB...............",
            "..............Yy................",
            "..............Yy................",
            "..............Yyy...............",
            ".............YYyyy..............",
            ".............YYyyy..............",
            ".............YYyyyy.............",
            "...........YYYYYyyYYYYYYYy......",
            "......YYYYYYYYQQQQYYYYYyy.......",
            ".....yyYYYYYYQAAAAQYYyyy........",
            "......yyyyyYQAAWAAAQyyy.........",
            "........yyyyQAAAAAAQyyy.........",
            ".........yyyQAAAAAAQYy..........",
            "...........YYQAAAAQYYY..........",
            "...........YYYQQQQyYYY..........",
            "...........YYYyyyyyyYY..........",
            "...........YYyyyyyyyYYY.........",
            "..........YYyyyy.yyyyYY.........",
            "..........YYyyy.....yyY.........",
            "..........Yyy.........yY........",
            "..........Yy....................",
            "................................",
            "................................",
        ],
    },
    "wyrm": {
        "dome": (15.5, 19.5, 10.0, 10.0, 0.9),
        "shapes": {"A": (15.5, 21.5, 4.6, 4.0, 0.95)},
        "rows": [
            "................................",
            "................................",
            "............cccccc..............",
            "...........c......c.............",
            "...........C.......c............",
            "............C.....C.............",
            ".............CC..CC.............",
            "...............NN...............",
            "..............NNNN..............",
            "...............BB....ee.........",
            "..............MMMMMMMMe.........",
            ".............MMMMMMFFMMe........",
            "...........LMMMMMMFPMMMM........",
            "...........LLLMMMMMMMMMM........",
            "...........oLLLLLLooMMMMM.......",
            "..........MMMoLLLLLLMMMMM.......",
            ".........MMMMMoooooMMMMMM.......",
            ".......MMeML...A...LMMMM........",
            ".......MMML.AAAAAAA.LMMM........",
            "......MMML..AWWAAAA..LMMM.......",
            "......MMML.AAAAAAAAA.LMMM.......",
            ".....MMeML.AAAAAAAAA.LMeM.......",
            ".....MMMML.AAAAAAAAA.LMMM.......",
            "......MMML..AAAAAAA..LMMM.......",
            ".......MMML.AAAAAAA.LMMM........",
            ".......MMMML...A...LMMMM........",
            "........MMeMLLLLLLLMMeM.........",
            ".........MMMMMMMMMMMMM..........",
            ".........MMMMMMeMMMMM...........",
            ".............MMMMM..............",
            "................................",
            "................................",
        ],
    },
    "cinderheart": {
        "dome": (16.0, 19.5, 9.6, 9.6, 0.9),
        "letters": {"M": ("main", 1.1), "K": ("accent", -0.6), "k": ("light", -0.4)},
        "rows": [
            "................................",
            "................................",
            "............cccccc..............",
            "...........c......c.............",
            "...........C.......c............",
            "............C.....C.............",
            ".............CC..CC.............",
            "...............NN...............",
            "..............NNNN..............",
            "...............BB...............",
            "...............YY...............",
            "..........MMMk.YY.MMMM..........",
            ".........MMMMkMYYkMMMMM.........",
            "........MMMMMkMMMkMMMMMM........",
            "........MMMMMkMMMkMMMMMM........",
            "........kkkkkkkkMkkkkkkk........",
            "........MMMMkKKKkkMMMMkk........",
            ".........MMMkKKKMMMMMMM.........",
            ".........MMMkKKKMMMMMMM.........",
            "..........MMkkkkkkkMMM..........",
            "...........kMMMkMMMkkM..........",
            "............MMMkMMMMkk..........",
            ".............MMkMMMMM...........",
            "..............MkMMMM............",
            "...............kkMM.............",
            "................kM..............",
            "................................",
            "................................",
            "................................",
            "................................",
            "................................",
            "................................",
        ],
    },
    "basilisk": {
        "dome": (16.0, 20.0, 9.4, 9.4, 0.9),
        "shapes": {"J": (16.0, 20.0, 6.5, 3.8, 0.8)},
        "letters": {"a": ("main", 3.0)},
        "rows": [
            "................................",
            "................................",
            "............cccccc..............",
            "...........c......c.............",
            "...........C.......c............",
            "............C.....C.............",
            ".............CC..CC.............",
            "...............NN...............",
            "..............NNNN..............",
            "...............BB...............",
            "................................",
            "............MMMMMMMM............",
            "..........MMeMMMeMMMeM..........",
            ".........MMMMMMMMMMMMMM.........",
            "........MMMMMMMMMMMMMMMM........",
            "........MMeMMMaaaaeMMMeM........",
            ".......MMMMMaaJPJJaaMMMMM.......",
            ".......MMMaaJJJPJJJJaaMMM.......",
            ".......MeaaJWWJPPJJJJaaMe.......",
            ".......MaaJJJJJPPJJJJJaaM.......",
            ".......MaaJJJJJPPJJJJJaaM.......",
            ".......MMaaJJJJPPJJJJaaMM.......",
            ".......MMMaaJJJPPJJJaaMMM.......",
            ".......MMMMMaaJPJJaaMMMMM.......",
            "........eMMMeMaPaaMMeMMM........",
            "........MMMMMMMMMMMMMMMM........",
            ".........MMMMMMMMMMMMMM.........",
            "..........eMMMeMMMeMMM..........",
            "............MMMMMMMM............",
            "................................",
            "................................",
            "................................",
        ],
    },
}


def _tone(shape, x, y, bias):
    cx, cy, rx, ry, depth = shape
    nx = max(-1.0, min(1.0, (x + 0.5 - cx) / rx)) * depth
    ny = max(-1.0, min(1.0, (y + 0.5 - cy) / ry)) * depth
    nz = math.sqrt(max(0.0, 1.0 - nx * nx - ny * ny))
    light = B.LIGHT[0] * nx + B.LIGHT[1] * ny + B.LIGHT[2] * nz
    return (0.95 - light) * 3.2 + bias


def icon(style, colors, frame=0):
    """RGBA rows of a 32x32 charm icon; frame pulses its glowing parts."""
    spec = STYLES[style]
    main, light, accent = (B._rgb(c) for c in colors)
    sources = {"main": main, "light": light, "accent": accent}
    ramps = {}
    glow = 0.5 + 0.5 * math.cos(frame * math.tau / ANIM_FRAMES)
    rows = spec["rows"]
    shapes = spec.get("shapes", {})
    letters = dict(LETTERS)
    letters.update(spec.get("letters", {}))
    pixels = [[None] * 32 for _ in range(32)]
    for y in range(32):
        for x in range(32):
            letter = rows[y][x]
            if letter == ".":
                continue
            if letter == "o":
                pixels[y][x] = FIXED["o"] + (255,)
                continue
            material, bias = letters[letter]
            if material not in ramps:
                ramps[material] = B._ramp(sources.get(material) or FIXED[material])
            level = _tone(shapes.get(letter, spec["dome"]), x, y, bias)
            if letter in GRAINED:
                noise = B._hash(x, y, 7) % 9
                level += 0.6 if noise == 0 else -0.5 if noise == 1 else 0.0
            # A seam where this material meets another one below or to the right.
            for dx, dy in ((1, 0), (0, 1)):
                other = rows[y + dy][x + dx] if x + dx < 32 and y + dy < 32 else "."
                if other not in (".", "o") and letters[other][0] != material and letter not in PULSING:
                    level = max(level, 3.0)
            index = max(0, min(4, round(level)))
            color = ramps[material][index]
            if letter in PULSING:
                dim = ramps[material][min(4, index + PULSING[letter])]
                color = tuple(round(d + (c - d) * glow) for c, d in zip(color, dim))
            pixels[y][x] = color + (255,)
    solid = {(x, y) for y in range(32) for x in range(32) if pixels[y][x] is not None}
    for x, y in solid:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            qx, qy = x + dx, y + dy
            if (qx, qy) not in solid and 0 <= qx < 32 and 0 <= qy < 32:
                pixels[qy][qx] = FIXED["o"] + (255,)
    return pixels


# Charms whose glowing parts pulse (make_sprites.animated).
ANIMATED = tuple(style for style, spec in STYLES.items() if any(letter in PULSING for row in spec["rows"] for letter in row))
