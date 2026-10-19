"""Hand-drawn pack and bag icons (32x32) for the plain carrying packs (looks "pack"): a belt
pouch, a satchel, canvas and framed packs, a reed basket, a silk drawstring sack, a haversack,
and a star-flecked rucksack. Same view and shading as pixel_bags.py: seen from slightly above and
to the left, each part shaded by code as a solid with its own curvature under the top-left light,
in a five-tone ramp of its material, with a darker seam where two parts meet and a dark outline
round the silhouette. Bigger packs (more slots) are drawn bigger.

Each style is a full part map (ROWS, one letter per pixel, "." transparent, "o" the outline
colour for holes and seams) plus PARTS: letter -> (material, shape, bias, texture), where
material is "main", "light", "accent", "shadow" (a deep tone of the main colour) or a FIXED
colour name; shape is (centre x, centre y, half width, half height, depth) for a curved part,
(nx, ny) for a flat one facing that way, or a tone index 0..4 for a flat-coloured detail
(stitches, flecks); texture is None, "grain" (leather), "canvas", "weave" (reed) or "silk".

make_sprites.py calls icon(style, colors).
"""

import math

from pixel_bags import FIXED as BAG_FIXED, LIGHT, _hash, _ramp, _rgb

FIXED = dict(BAG_FIXED, wool=(150, 74, 52), wood=(146, 104, 62), parchment=(226, 210, 166),
             thistle_leaf=(96, 136, 70), cord=(196, 176, 140), reed=(170, 150, 84))

STYLES = {}


def _materials(colors):
    main, light, accent = (_rgb(c) for c in colors)
    materials = {"main": _ramp(main), "light": _ramp(light), "accent": _ramp(accent),
                 "shadow": _ramp(tuple(round(c * 0.5) for c in main))}
    for name, color in FIXED.items():
        materials[name] = _ramp(color)
    return materials


def _texture(kind, x, y):
    """A shade offset for a material's surface texture."""
    if kind == "grain":
        noise = _hash(x, y) % 9
        return 0.55 if noise == 0 else -0.45 if noise == 1 else 0.0
    if kind == "canvas":
        noise = _hash(x, y, 3) % 11
        return (0.3 if y % 3 == 2 else 0.0) + (0.5 if noise == 0 else 0.0)
    if kind == "weave":
        # Horizontal weavers two pixels high, lit on top, crossing stakes that show between them.
        band = y // 2
        if x % 4 == (band % 2) * 2:
            return 1.3
        return -0.6 if y % 2 == 0 else 0.5
    return 0.0


def _level(spec, x, y):
    shape = spec[1]
    if isinstance(shape, int):
        return float(shape)
    bias, texture = spec[2], spec[3]
    if len(shape) == 2:
        nx, ny = shape
    else:
        cx, cy, rx, ry, depth = shape
        nx = max(-1.0, min(1.0, (x + 0.5 - cx) / rx)) * depth
        ny = max(-1.0, min(1.0, (y + 0.5 - cy) / ry)) * depth
    nz = math.sqrt(max(0.0, 1.0 - nx * nx - ny * ny))
    light = LIGHT[0] * nx + LIGHT[1] * ny + LIGHT[2] * nz
    level = (0.95 - light) * 3.2 + bias + _texture(texture, x, y)
    if texture == "silk":
        # A soft sheen band across the dome, from upper right to lower left.
        if abs((x - 3) + y * 0.55 - 26) < 1.6:
            level -= 1.0
    return level


def icon(style, colors, frame=0):
    """RGBA rows of a 32x32 pack icon in the item's colours (main, light, accent)."""
    spec = STYLES[style]
    rows, parts = spec["rows"], spec["parts"]
    materials = _materials(colors)
    pixels = [[None] * 32 for _ in range(32)]
    for y in range(32):
        for x in range(32):
            part = rows[y][x]
            if part == ".":
                continue
            if part == "o":
                pixels[y][x] = FIXED["o"] + (255,)
                continue
            entry = parts[part]
            level = _level(entry, x, y)
            if not isinstance(entry[1], int):
                seam = entry[4] if len(entry) > 4 else 4
                for dx, dy in ((1, 0), (0, 1)):
                    other = rows[y + dy][x + dx] if x + dx < 32 and y + dy < 32 else "."
                    if other not in (".", "o", part) and not isinstance(parts[other][1], int):
                        level = max(level, seam)
            pixels[y][x] = materials[entry[0]][max(0, min(4, round(level)))] + (255,)
    solid = {(x, y) for y in range(32) for x in range(32) if pixels[y][x] is not None}
    for x, y in list(solid):
        if any((x + dx, y + dy) not in solid for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            pixels[y][x] = FIXED["o"] + (255,)
    return pixels


# A small belt pouch: a belt loop behind, a rounded flap with a brass toggle.
STYLES["pouch"] = {
    "rows": [
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        ".............TTTTTTT............",
        ".............TTTTTTT............",
        ".............TToooTT............",
        ".............TTTTTTT............",
        "...........UUUUUUUUUU...........",
        "..........UUUUUUUUUUUUS.........",
        ".........LLLLLLLLLLLLLSS........",
        ".........LLLLLLLLLLLLLSSS.......",
        ".........LLLLLLLLLLLLLSSS.......",
        ".........FLLLLLLLLLLLFSSS.......",
        ".........FFLLLLLLLLLFFSSS.......",
        ".........FFFLLLLLLLFFFSSS.......",
        ".........FFFFLBBBLFFFFSSS.......",
        ".........FFFFFBBBFFFFFSSS.......",
        ".........FFFFFBBBFFFFFSSS.......",
        ".........FFFFFFFFFFFFFSSS.......",
        ".........FFFFFFFFFFFFFSSS.......",
        ".........FFFFFFFFFFFFFSS........",
        "..........FFFFFFFFFFFSS.........",
        "...........FFFFFFFFFSS..........",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
    ],
    "parts": {
        "T": ("strap", (-0.5, -0.3), 0.3, "grain"),
        "U": ("light", (15.5, 11.0, 6.0, 1.5, 0.7), -0.3, "grain"),
        "L": ("light", (15.0, 15.0, 7.0, 4.5, 0.75), 0.0, "grain"),
        "F": ("main", (15.0, 19.5, 7.0, 7.0, 0.6), 0.1, "grain"),
        "S": ("main", (23.0, 18.5, 2.0, 7.0, 0.3), 1.3, "grain"),
        "B": ("accent", (15.5, 19.0, 1.6, 1.6, 0.85), 0.0, None, 3),
    },
}

# A shoulder satchel: wide and flat, a long strap with a buckle, a flap held by two buckled straps.
STYLES["satchel"] = {
    "rows": [
        "................................",
        "................................",
        "...........TTTTTTTTTT...........",
        ".........TTTTTTTTTTTTTT.........",
        "........TTTTTTTTTTTTTTTT........",
        ".......TTTT..........TTTT.......",
        "......TTT..............TTT......",
        "......TTT..............TTT......",
        "......TTT..............TTT......",
        "......TTT..............TTT......",
        "......TTT..............TTT......",
        "......UUUUUUUUUUUUUUUUUS........",
        ".....LLLLLLLLLLLLLLLLLLSS.......",
        ".....LLLTTLLLLLLLLTTLLLSSS......",
        ".....LLLTTLLLLLLLLTTLLLSSS......",
        ".....LLLTTLLLLLLLLTTLLLSSS......",
        ".....LLLTTLLLLLLLLTTLLLSSS......",
        ".....LLLTTLLLLLLLLTTLLLSSS......",
        ".....LLLTTLLLLLLLLTTLLLSSS......",
        ".....LLLTTLLLLLLLLTTLLLSSS......",
        ".....LLBBBBLLLLLLBBBBLLSSS......",
        ".....FFBBBBFFFFFFBBBBFFSSS......",
        ".....FFFTTFFFFFFFFTTFFFSSS......",
        ".....FFFTTFFFFFFFFTTFFFSSS......",
        ".....FFFFFFFFFFFFFFFFFFSSS......",
        ".....FFFFFFFFFFFFFFFFFFSS.......",
        "......FFFFFFFFFFFFFFFFSS........",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
    ],
    "parts": {
        "T": ("strap", (-0.5, -0.4), 0.9, "grain"),
        "B": ("accent", (-0.6, -0.5), -0.3, None, 3),
        "U": ("light", (14.0, 11.5, 9.0, 1.0, 0.5), -0.4, "grain"),
        "L": ("light", (13.5, 15.5, 9.0, 5.0, 0.55), 0.1, "grain"),
        "F": ("main", (13.5, 23.5, 9.0, 3.5, 0.5), 0.2, "grain"),
        "S": ("main", (24.0, 18.5, 1.5, 7.5, 0.25), 1.3, "grain"),
    },
}

# A canvas pack: a gathered, corded top, a flap with one buckled strap, a wool bedroll strapped
# underneath with its rolled end showing.
STYLES["explorer"] = {
    "rows": [
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
        "...........UUUUUUUUU............",
        "..........UUUUUUUUUUU...........",
        ".........CCCCCCCCCCCCC..........",
        "........LLLLLLLLLLLLLLLS........",
        ".......LLLLLLLLLLLLLLLLSS.......",
        ".......LLLLLLLTTLLLLLLLSSS......",
        ".......LLLLLLLTTLLLLLLLSSS......",
        ".......LLLLLLLTTLLLLLLLSSS......",
        ".......FLLLLLLTTLLLLLLFSSS......",
        ".......FFLLLLBBBBLLLLFFSSS......",
        ".......FFFFFFBBBBFFFFFFSSS......",
        ".......FFFFFFFTTFFFFFFFSSS......",
        ".......FFFFFFFFFFFFFFFFSSS......",
        ".......FFFFFFFFFFFFFFFFSSS......",
        ".......FFFFFFFFFFFFFFFFSSS......",
        ".......FFFFFFFFFFFFFFFFSSS......",
        ".....EERRRTTRRRRRRRRRTTRRRRR....",
        "....EeeERRTTRRRRRRRRRTTRRRRRR...",
        "....eEEeRRTTRRRRRRRRRTTRRRRRR...",
        "....eEeeRRTTRRRRRRRRRTTRRRRRR...",
        "....EeeERRTTRRRRRRRRRTTRRRRRR...",
        ".....EERRRTTRRRRRRRRRTTRRRRR....",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
    ],
    "parts": {
        "U": ("light", (15.5, 6.0, 5.5, 1.6, 0.8), -0.2, "canvas"),
        "C": ("cord", (-0.4, -0.5), 0.3, None, 3),
        "L": ("light", (15.0, 11.0, 8.0, 3.5, 0.6), 0.0, "canvas"),
        "F": ("main", (15.0, 17.0, 8.0, 5.0, 0.45), 0.2, "canvas"),
        "S": ("main", (24.0, 15.0, 1.5, 6.0, 0.25), 1.3, "canvas"),
        "T": ("strap", (-0.5, -0.3), 0.3, "grain"),
        "B": ("accent", (-0.6, -0.5), -0.3, None, 3),
        "R": ("wool", (16.5, 22.0, 12.0, 3.2, 0.9), 0.0, "grain"),
        "E": ("wool", (5.5, 23.0, 2.0, 2.6, 0.6), -0.6, None),
        "e": ("wool", 3),
    },
}

# A woven reed basket-bag seen from above: the open rim with its dark inside, an arched reed
# handle, a straw band tied in a knot.
STYLES["basket"] = {
    "rows": [
        "................................",
        "................................",
        "................................",
        "............HHHHHHHH............",
        "..........HHHHHHHHHHHH..........",
        ".........HHHH......HHHH.........",
        "........HHH..........HHH........",
        ".......HHH............HHH.......",
        ".......HHH............HHH.......",
        ".......HHH............HHH.......",
        ".......RRRRRRRRRRRRRRRRRR.......",
        ".....RRRjjjjjjjjjjjjjjjjRRR.....",
        "....RRjjjjjjjjjjjjjjjjjjjjRR....",
        "....RRRiiiiiiiiiiiiiiiiiiRRR....",
        ".....RRRRRRRRRRRRRRRRRRRRRR.....",
        ".....WWWWWWWWWWWWWWWWWWWWWW.....",
        ".....WWWWWWWWWWWWWWWKKKWWWW.....",
        ".....AAAAAAAAAAAAAAKKKKKAAA.....",
        ".....AAAAAAAAAAAAAAKKKKKAAA.....",
        "......WWWWWWWWWWWWWWKKKWWW......",
        "......WWWWWWWWWWWWWWWWWWWW......",
        "......WWWWWWWWWWWWWWWWWWWW......",
        "......WWWWWWWWWWWWWWWWWWWW......",
        ".......WWWWWWWWWWWWWWWWWW.......",
        ".......WWWWWWWWWWWWWWWWWW.......",
        "........WWWWWWWWWWWWWWWW........",
        ".........WWWWWWWWWWWWWW.........",
        "................................",
        "................................",
        "................................",
        "................................",
        "................................",
    ],
    "parts": {
        "H": ("light", (-0.4, -0.5), 0.2, "grain"),
        "R": ("light", (15.5, 12.0, 11.0, 2.5, 0.6), -0.2, "weave"),
        "j": ("main", (15.5, 12.0, 9.0, 1.5, 0.3), 1.0, "weave"),
        "i": ("shadow", (15.5, 13.0, 9.0, 1.0, 0.3), 0.6, None),
        "W": ("main", (15.5, 19.0, 10.0, 8.0, 0.7), 0.0, "weave"),
        "A": ("accent", (15.5, 18.0, 10.5, 3.0, 0.7), 0.0, "grain"),
        "K": ("accent", (21.0, 17.5, 2.5, 2.0, 0.9), -0.2, None, 3),
    },
}

# A silk drawstring sack: a gathered ruffle above a corded neck, cord ends with tassels hanging
# over the front, a round sheened body embroidered with a thistle.
STYLES["silk"] = {
    "rows": [
        "................................",
        "................................",
        "................................",
        ".............U.UU.U.............",
        "............UUUUUUUU............",
        "...........UUUUUUUUUU...........",
        "............UUUUUUUU............",
        "............CCCCCCCCC...........",
        "............CCCCCCCCCC..........",
        "...........FFFFFFFFFCCF.........",
        ".........FFFFFFFFFFFFCFF........",
        "........FFFFFFFFFFFFFCFFF.......",
        ".......FFFFFFFFFFFFFFCFFFF......",
        "......FFFFEFEFEFFFFFKKKFFFF.....",
        ".....FFFFEEEEEEEFFFFKKKFFFFF....",
        ".....FFFFFEEEEEFFFFFFKFFFFFF....",
        "....FFFFFFGGGGGFFFFFFFFFFFFFF...",
        "....FFFFFFGgGgGFFFFFFFFFFFFFF...",
        "....FFFFFFFGGGFFFFFFFFFFFFFFF...",
        "....FFFFFFFFgFFFFFFFFFFFFFFFF...",
        "....FFFFFFFFgFFFFFFFFFFFFFFFF...",
        "....FFFFFggFgFggFFFFFFFFFFFFF...",
        "....FFFFFFggggFFFFFFFFFFFFFFF...",
        ".....FFFFFFFgFFFFFFFFFFFFFFF....",
        ".....FFFFFFFFFFFFFFFFFFFFFFF....",
        "......FFFFFFFFFFFFFFFFFFFFFF....",
        ".......FFFFFFFFFFFFFFFFFFFF.....",
        ".........FFFFFFFFFFFFFFFF.......",
        "................................",
        "................................",
        "................................",
        "................................",
    ],
    "parts": {
        "U": ("light", (15.5, 4.5, 4.5, 2.0, 0.8), -0.3, "silk"),
        "C": ("accent", (-0.4, -0.5), 0.6, None, 3),
        "K": ("accent", (21.0, 14.0, 1.6, 1.6, 0.8), 0.2, None, 3),
        "F": ("light", (14.5, 18.5, 12.0, 9.5, 0.85), 0.3, "silk"),
        "E": ("accent", (12.0, 14.0, 3.5, 1.8, 0.7), 0.0, None, 3),
        "G": ("thistle_leaf", (12.0, 17.0, 2.5, 1.5, 0.6), 0.0, None, 3),
        "g": ("thistle_leaf", 3),
    },
}

# A framed pack: wooden frame poles and crossbar standing proud of the bag, two buckled straps
# over the lid, a pocket, and a leather map case with brass caps strapped to the right side.
STYLES["framed"] = {
    "rows": [
        "................................",
        "................................",
        ".....WW..............WW.........",
        ".....WWWWWWWWWWWWWWWWWW.........",
        ".....WWWWWWWWWWWWWWWWWW.........",
        ".....WW..............WW..pp.....",
        ".....WW.LLLLLLLLLLLL.WW..pp.....",
        ".....WWLLLLLLLLLLLLLLSS.KKKK....",
        ".....WWLLLLLLLLLLLLLLSSSKKKK....",
        ".....WWLLLTTLLLLTTLLLSSSMMMM....",
        ".....WWLLLTTLLLLTTLLLSSSMMMM....",
        ".....WWLLLTTLLLLTTLLLSSSMMMM....",
        ".....WWLLLTTLLLLTTLLLSSSTTTT....",
        ".....WWFLLBBLLLLBBLLFSSSMMMM....",
        ".....WWFFFBBFFFFBBFFFSSSMMMM....",
        ".....WWFFFFFFFFFFFFFFSSSMMMM....",
        ".....WWFFQQQQQQQQQQFFSSSMMMM....",
        ".....WWFFQQQQQQQQQQFFSSSMMMM....",
        ".....WWFFPPPPNPPPPPFFSSSMMMM....",
        ".....WWFFPPPNNNPPPPFFSSSTTTT....",
        ".....WWFFPPPPNPPPPPFFSSSMMMM....",
        ".....WWFFPPPPPPPPPPFFSSSMMMM....",
        ".....WWFFPPPPPPPPPPFFSSSMMMM....",
        ".....WWFFFFFFFFFFFFFFSSSKKKK....",
        ".....WWFFFFFFFFFFFFFFSSSKKKK....",
        ".....WWFFFFFFFFFFFFFFSS.........",
        ".....WW.FFFFFFFFFFFFSS..........",
        ".....WW..............WW.........",
        ".....WW..............WW.........",
        "................................",
        "................................",
        "................................",
    ],
    "parts": {
        "W": ("wood", (-0.5, -0.4), 0.2, "grain", 3),
        "L": ("light", (14.0, 10.0, 7.5, 4.0, 0.6), 0.0, "canvas"),
        "F": ("main", (14.0, 19.0, 7.5, 7.0, 0.45), 0.2, "canvas"),
        "Q": ("main", (14.0, 16.5, 6.0, 1.5, 0.5), 0.0, "canvas"),
        "P": ("light", (14.0, 20.0, 6.0, 3.0, 0.65), 0.4, "canvas"),
        "N": ("accent", (13.0, 19.0, 1.6, 1.6, 0.8), -0.2, None, 3),
        "S": ("main", (22.0, 16.0, 1.5, 9.0, 0.25), 1.3, "canvas"),
        "T": ("strap", (-0.5, -0.3), 0.3, "grain"),
        "B": ("accent", (-0.6, -0.5), -0.3, None, 3),
        "M": ("strap", (25.5, 16.0, 2.0, 9.0, 0.9), 0.0, "grain"),
        "K": ("accent", (25.5, 16.0, 2.0, 9.0, 0.9), -0.2, None, 3),
        "p": ("parchment", (25.5, 5.5, 1.5, 1.0, 0.7), 0.0, None),
    },
}

# A dark cotton haversack: deep and rounded, a carry handle, a rounded flap with pale running
# stitches and a crescent-moon button.
STYLES["haversack"] = {
    "rows": [
        "................................",
        "................................",
        "................................",
        "................................",
        "...........HHHHHHHH.............",
        ".........HHH......HHH...........",
        "........HH..........HH..........",
        "........HH..........HH..........",
        "........HH..........HH..........",
        "......UUUUUUUUUUUUUUUUUU........",
        ".....UUUUUUUUUUUUUUUUUUUUS......",
        "....LxLLLLLLLLLLLLLLLLLxLSS.....",
        "....LLLxxLxxLxxLxxLxxLLLLSSS....",
        "....LxLLLLLLLLLLLLLLLLLxLSSS....",
        "....LLLLLLLLLLLLLLLLLLLLLSSS....",
        "....LxLLLLLLLLLLLLLLLLLxLSSS....",
        "....FLLLLLLLLLLLLLLLLLLLFSSS....",
        "....FFLxLLLLLLLLLLLLLxLFFSSS....",
        "....FFFLLLLLLLLLLLLLLLFFFSSS....",
        "....FFFFLxLLLLLLLLLxLFFFFSSS....",
        "....FFFFFLLLLMMMLLLLFFFFFSSS....",
        "....FFFFFFLxMMMLLxLFFFFFFSSS....",
        "....FFFFFFFFMMFFFFFFFFFFFSSS....",
        "....FFFFFFFFMMMFFFFFFFFFFSSS....",
        "....FFFFFFFFFMMMFFFFFFFFFSSS....",
        "....FFFFFFFFFFFFFFFFFFFFFSS.....",
        ".....FFFFFFFFFFFFFFFFFFFSS......",
        "......FFFFFFFFFFFFFFFFFSS.......",
        "........FFFFFFFFFFFFFS..........",
        "................................",
        "................................",
        "................................",
    ],
    "parts": {
        "H": ("main", (-0.4, -0.5), 0.0, "grain"),
        "U": ("light", (15.0, 10.0, 10.0, 1.5, 0.6), -0.3, "canvas"),
        "L": ("light", (14.5, 15.5, 10.5, 6.5, 0.6), 0.2, "canvas"),
        "F": ("main", (14.5, 21.0, 10.5, 7.5, 0.55), 0.2, "canvas"),
        "S": ("main", (26.0, 19.0, 1.5, 8.0, 0.25), 1.2, "canvas"),
        "x": ("accent", 1),
        "M": ("accent", (13.5, 22.0, 2.5, 2.5, 0.8), 0.2, None, 3),
    },
}

# The largest rucksack: star-flecked fabric, a drawstring collar under a carry handle, a lid with
# a star clasp, a front pocket with a star, and a side pocket.
STYLES["starweave"] = {
    "rows": [
        "................................",
        "................................",
        "..............HHHH..............",
        ".............HH..HH.............",
        "...........UUUHUUUUHUUU.........",
        ".........UUUUUUUUUUUUUUU........",
        ".......CCCCCCCCCCCCCCCCCC.......",
        ".....LLLLLLLLLLLLLLLLLLLS.......",
        "....LLLLLLL*LLLLLLLLLLLLSS......",
        "....LLLLLLLLLLLLLLLLL*LLSSS.....",
        "....LL*LLLLLLLLLLLLLLLLLSSSS....",
        "....FLLLLLLLLLLLLLLLLLLFSS*S....",
        "....FFLLLLLLLLLLLL*LLLFFSSSS....",
        "....FFFLLLLLL*LLLLLLLFFFSSSS....",
        "....FFFFLLLLLLBLLLLLLFFFSSSS....",
        "....F*FFFLLLLBBBLLLLFFFFSSSS....",
        "....FFFFFFLLBBBBBLLFFFFFSSSS....",
        "....FFFFFFFFFBBBFFFFFF*FSRRRR...",
        "....FFFFFFFFFFBFFFFFFFFFSRRRR...",
        "....FF*FFFFFFFFFFFFFFFFFSRR*R...",
        "....FFFQQQQQQQQQQQQQQFFFSRRRR...",
        "....FFFQQQQQQQQQQQQQQFFFSRRRR...",
        "....FFFPPPPPPPPPPPPPPFFFSRRRR...",
        "....FFFPPPPPPP*PPPPPPFFFSSRRS...",
        "....FFFPP*PPP***PPPPPFF*SSSS....",
        "....FFFPPPPPPP*PPPPPPFFFSSSS....",
        "....FFFPPPPPPPPPPP*PPFFFSSSS....",
        ".....FFFPPPPPPPPPPPPFFFSSSS.....",
        "......FFFFFFFFFFFFFFFFSSS.......",
        "........FFFFFFFFFFFFSS..........",
        "................................",
        "................................",
    ],
    "parts": {
        "H": ("main", (-0.4, -0.5), 0.2, "grain"),
        "U": ("light", (15.5, 4.5, 6.5, 1.6, 0.8), -0.2, None),
        "C": ("accent", (-0.4, -0.5), 0.6, None, 3),
        "L": ("light", (14.0, 10.5, 10.0, 4.5, 0.6), 0.2, None),
        "F": ("main", (14.0, 19.0, 10.0, 9.0, 0.5), 0.0, None),
        "S": ("main", (25.5, 18.0, 2.0, 10.0, 0.25), 1.2, None),
        "R": ("main", (26.5, 20.5, 1.8, 4.0, 0.6), 0.6, None),
        "Q": ("main", (13.5, 20.5, 7.0, 1.5, 0.5), 0.1, None),
        "P": ("light", (13.5, 24.5, 7.0, 3.5, 0.6), 0.4, None),
        "B": ("accent", (14.0, 15.5, 2.5, 2.5, 0.8), -0.2, None, 3),
        "*": ("accent", 0),
    },
}
