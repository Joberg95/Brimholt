"""Hand-drawn monster drops and gathered resources (32x32): one shape per kind of thing (a claw, a
feather, an eye, a crown, a log...), shaded like the backpacks (pixel_bags.py).

SHAPES are hand-drawn maps, one letter per material:

  m l a  the item's main, light, and accent colours     b bone    f flesh    y gold    s silver
  t wood    w white    k near-black (pupils, roots, openings)

Every material area is shaded as one rounded solid lit from the top-left (five-tone ramps, a dome
over its bounding box), with a darker seam where two materials meet and a dark outline round the
whole shape, which is centred in the icon. make_sprites.py calls icon(shape, colors).
"""

import pixel_bags as B

FIXED = {"b": (232, 222, 196), "f": (214, 140, 130), "y": (216, 168, 58), "s": (176, 184, 192),
         "t": (122, 86, 54), "w": (240, 236, 228), "k": (34, 26, 30)}

# Shapes no larger than this (in either direction) are drawn at twice the size.
GROW_BELOW = 14
# Shapes always drawn at their own size: the gems stay small, as in Tibia.
KEEP_SIZE = {"gem", "great_gem"}

SHAPES = {
    "tail": [
        "...........mm.",
        "..........mm..",
        ".........mm...",
        "........mm....",
        ".......mm.....",
        "......mm......",
        ".....mmm......",
        "....mmmm......",
        "...mmmmm......",
        "..mmmmm.......",
        ".mmmmm........",
        "mmmm..........",
    ],
    "claw": [
        "b.....b.....b.",
        "bb....bb....bb",
        ".bb....bb...bb",
        ".bbb...bbb..bb",
        "..bbb...bbb.bb",
        "..mmmmmmmmmmmm",
        ".mmmmmmmmmmmmm",
        ".mmmmmmmmmmmmm",
        "..mmmmmmmmmmm.",
        "...mmmmmmmmm..",
    ],
    "tusk": [
        "bb..........",
        "bbb.........",
        ".bbb........",
        ".bbbb.......",
        "..bbbb......",
        "...bbbb.....",
        "....bbbbb...",
        ".....bbbbbb.",
        "......mmmmmm",
        ".......mmmmm",
    ],
    "fang": [
        ".mmmmm.",
        "mmmmmmm",
        ".bbbbb.",
        ".bbbbb.",
        "..bbbb.",
        "..bbbb.",
        "..bbb..",
        "...bb..",
        "...bb..",
        "...b...",
    ],
    "horn": [
        "........mmmm..",
        "......mmmmmm..",
        ".....mmmmll...",
        "....mmmmll....",
        "...mmmmll.....",
        "..mmmmll......",
        "..mmmll.......",
        ".mmmll........",
        ".mmll.........",
        "mmll..........",
        "ml............",
    ],
    "feather": [
        "..........mmm.",
        "........mmmmmm",
        ".......mmmlmmm",
        "......mmmlmmm.",
        ".....mmmlmmm..",
        "....mmmlmmm...",
        "...mmmlmmm....",
        "...mmlmmm.....",
        "..mmlmm.......",
        "..mlmm........",
        ".ll...........",
        "l.............",
    ],
    "stinger": [
        "..........aa.",
        ".........aaa.",
        "........aaa..",
        "......mmma...",
        ".....mmmm....",
        "....mmmmm....",
        "...mmmmm.....",
        "..lllll......",
        ".mmmmm.......",
        "mmmmm........",
        "mmmm.........",
    ],
    "bone": [
        "bb..........",
        "bbb.........",
        ".bbb........",
        "..bbb.......",
        "...bbb......",
        "....bbb.....",
        ".....bbb....",
        "......bbb...",
        ".......bbbbb",
        "........bbb.",
        "........bb..",
    ],
    "pelt": [
        "..mmmmmmmmmm..",
        ".mmmmmmmmmmmm.",
        "mmmllllllllmmm",
        "mmlllllllllllm",
        "mmlllllllllllm",
        "mmlllllllllllm",
        ".mmmmmmmmmmmm.",
        "mm.mm.mm.mm.mm",
    ],
    "scale": [
        "....mmmmm....",
        "..mmmmmmmmm..",
        ".mmmmlmmmmmm.",
        "mmmmlllmmmmmm",
        "mmmllllllmmmm",
        "mmmmllllmmmmm",
        ".mmmmmlmmmmm.",
        "..mmmmmmmmm..",
        "....mmmmm....",
        "......m......",
    ],
    "chitin": [
        "...mmmmmm...",
        ".mmmmmmmmmm.",
        "aaaaaaaaaaaa",
        "mmmmmmmmmmmm",
        "mmmmmmmmmmmm",
        "aaaaaaaaaaaa",
        "mmmmmmmmmmmm",
        ".mmmmmmmmmm.",
        "..aaaaaaaa..",
        "...mmmmmm...",
    ],
    "eye": [
        "...wwwwww...",
        ".wwwwwwwwww.",
        "wwwwaaaawwww",
        "wwwaaaaaawww",
        "wwwaakkaawww",
        "wwwaakkaawww",
        "wwwaaaaaawww",
        "wwwwaaaawwww",
        ".wwwwwwwwww.",
        "...wwwwww...",
    ],
    "heart": [
        ".mmm..mmm.",
        "mmmmmmmmmm",
        "mmmmmmmmmm",
        "mmmmmmmmmm",
        "mmmaammmmm",
        ".mmaammmm.",
        "..mmmmmm..",
        "...mmmm...",
        "....mm....",
        "....aa....",
        "....aa....",
    ],
    "censer": [
        ".....y.....",
        ".....y.....",
        ".....y.....",
        "...yyyyy...",
        "..mmmmmmm..",
        ".mmmmmmmmm.",
        ".mmakkkamm.",
        ".mmmmmmmmm.",
        "..mmmmmmm..",
        "...yyyyy...",
        "....yyy....",
    ],
    "badge": [
        "..yyyyyy..",
        ".yyyyyyyy.",
        "yymmmmmmyy",
        "yymmaammyy",
        "yymaaaamyy",
        "yymmaammyy",
        ".yymmmmyy.",
        "..yymmyy..",
        "...yyyy...",
    ],
    "sigil": [
        "...mmmmm...",
        ".mmmmmmmmm.",
        ".mmaammaam.",
        "mmmmaaaammm",
        "mmmaammaamm",
        "mmmmaaaammm",
        ".mmaammaam.",
        ".mmmmmmmmm.",
        "...mmmmm...",
    ],
    "crown": [
        "y...y...y",
        "yy.yyy.yy",
        "yyyyyyyyy",
        "yaayyyaay",
        "yyyyyyyyy",
        ".yyyyyyy.",
    ],
    "fetish": [
        "..aa...aa..",
        "...aa.aa...",
        "...bbbbb...",
        "..bkbbbkb..",
        "..bbbbbbb..",
        "...bkbkb...",
        ".....t.....",
        ".....t.....",
        "....mtm....",
        ".....t.....",
        ".....t.....",
        ".....t.....",
    ],
    "totem": [
        "..tttttt..",
        ".tttttttt.",
        ".tkttttkt.",
        ".tttttttt.",
        ".ttkkkktt.",
        ".tttttttt.",
        "aaaaaaaaaa",
        ".tttttttt.",
        ".tkttttkt.",
        ".tttttttt.",
        "..tttttt..",
    ],
    "charm": [
        "....ss....",
        "...s..s...",
        "...s..s...",
        "..mmmmmm..",
        ".mmmmmmmm.",
        ".mmaaaamm.",
        ".mmaaaamm.",
        ".mmmmmmmm.",
        "..mmmmmm..",
        "...mmmm...",
    ],
    "reliquary": [
        "....yy....",
        "..yyyyyy..",
        ".mmmmmmmm.",
        "ymmmmmmmmy",
        "ymmmaammmy",
        "ymmmaammmy",
        "ymmmmmmmmy",
        "yyyyyyyyyy",
    ],
    "coil": [
        "...mmmmm...",
        ".mmm...mmm.",
        "mm..mmm..mm",
        "m..m...m..m",
        "m.m..m..m.m",
        "m.m..m..m.m",
        "m..m...m..m",
        "mm..mmm..mm",
        ".mmm...mmm.",
        "...mmmmm...",
    ],
    "silk": [
        "...wwwww...",
        ".wwwwwwwww.",
        "wwwwlwwwwww",
        "wwwlwwwlwww",
        "wwlwwwlwwww",
        "wwwwwlwwwww",
        ".wwwlwwwww.",
        "...wwwww.w.",
        "..........w",
    ],
    "sash": [
        "mmmmmmmmmmm...",
        ".mmmmmmmmmmm..",
        "..aaaaaaaaaaa.",
        "...mmmmmmmmmmm",
        "...mmmmmmmmmm.",
        "....mm....mm..",
        "....mm.....mm.",
    ],
    "rosary": [
        "...m.m.m...",
        "..m.....m..",
        ".m.......m.",
        "m.........m",
        ".m.......m.",
        "..m.....m..",
        "...m.m.m...",
        ".....a.....",
        "....aaa....",
        ".....a.....",
        ".....a.....",
    ],
    "shard": [
        "......a.....",
        ".....aa..a..",
        "....aaa.aa..",
        "....aaaaaa..",
        "..a.aaaaaa..",
        ".aa.aaaaaaa.",
        ".aaaaaaaaaa.",
        ".aaaaaaaaaaa",
        "..mmmmmmmmm.",
        "...mmmmmmm..",
    ],
    "core": [
        "....mmmm....",
        "..mmmmmmmm..",
        ".mmmaaaammm.",
        ".mmaaaaaamm.",
        "mmaaawwaaamm",
        "mmaaawwaaamm",
        ".mmaaaaaamm.",
        ".mmmaaaammm.",
        "..mmmmmmmm..",
        "....mmmm....",
    ],
    "ash": [
        ".....mm.....",
        "...mmmmmm...",
        "..mmmmmmmmm.",
        ".mmmmammmmmm",
        "mmmmmmmmamm.",
        "mmammmmmmmmm",
        ".mmmmmmmmmm.",
    ],
    "chunk": [
        "....mmmmm...",
        "..mmmmmmmmm.",
        ".mmmmmmmmmmm",
        "mmmmammmmmmm",
        "mmmmmmmmammm",
        "mmmmmmmmmmm.",
        ".mmmmmmmmm..",
        "..mmmmmm....",
    ],
    "vial": [
        "...tt...",
        "...tt...",
        "..wwww..",
        "..w..w..",
        ".wmmmmw.",
        "wmmmmmmw",
        "wmmaammw",
        "wmmmmmmw",
        ".wmmmmw.",
        "..wwww..",
    ],
    "gland": [
        "....ff....",
        "...ffff...",
        "..mmmmmm..",
        ".mmmmmmmm.",
        "mmmaammmmm",
        "mmmaaammmm",
        "mmmmmmmmmm",
        ".mmmmmmmm.",
        "..mmmmmm..",
    ],
    "phylactery": [
        "...yyyy...",
        "....yy....",
        "..yyyyyy..",
        ".mmmmmmmm.",
        "ymmmaammmy",
        "ymmaaaammy",
        "ymmmaammmy",
        ".mmmmmmmm.",
        "..yyyyyy..",
        ".yyyyyyyy.",
    ],
    "ore": [
        "....kkkkk...",
        "..kkkkkkkkk.",
        ".kkkaakkkkkk",
        "kkkaaakkkaak",
        "kkkkkkkkaaak",
        "kkaakkkkkkk.",
        ".kaakkkkkk..",
        "..kkkkkk....",
    ],
    "log": [
        "............ll",
        "..........llll",
        "........mmlllt",
        "......mmmmllt.",
        "....mmmmmmtt..",
        "..mmmmmmmm....",
        "mmmmmmmmm.....",
        "mmmmmmm.......",
        ".mmmm.........",
    ],
    "herb": [
        "..a...a...a..",
        ".aaa.aaa.aaa.",
        "..a...a...a..",
        "..m...m..m...",
        "...m..m.m....",
        "....m.mm.....",
        "..mm.mm.mm...",
        "....mmmm.....",
        ".....tt......",
        ".....tt......",
    ],
    "fish": [
        "...mmmmm......",
        ".mmmmmmmmm..ll",
        "mkmmmmmmmmmlll",
        "mmmllllllmmlll",
        ".mmmmmmmmmmlll",
        "..mmmmmmm...ll",
        "....mmm.......",
    ],
    "skull": [
        "...bbbbbb...",
        ".bbbbbbbbbb.",
        "bbbbbbbbbbbb",
        "bbkkbbbbkkbb",
        "bbkkbbbbkkbb",
        "bbbbbkkbbbbb",
        ".bbbbkkbbbb.",
        "..bkbkbkbb..",
        "..bbbbbbbb..",
        "...bbbbbb...",
    ],
    "torc": [
        "...yyyyyy...",
        ".yyy....yyy.",
        "yy........yy",
        "y..........y",
        "yy........yy",
        ".yaa....aay.",
        "..aa....aa..",
    ],
    "shell": [
        "....mmmmm....",
        "..mmlmmmlmm..",
        ".mmlmmmmmlmm.",
        "mmlmmmmmmmlmm",
        "mmlmmmmmmmlmm",
        "mmmmmmmmmmmmm",
        ".aaaaaaaaaaa.",
        "..aaa...aaa..",
    ],
    "pearl": [
        "..mmmmmmmm..",
        ".mmmmmmmmmm.",
        "mmmllllllmmm",
        "mmlllwwlllmm",
        "mmllwwwwllmm",
        "mmlllwwlllmm",
        ".mmllllllmm.",
        "..mmmmmmmm..",
    ],
    # Cut gems (Combat's valuables), small like Tibia's: a chunky stone rounded on its upper left,
    # a steep right side and a flat base, its facets lit on the top-left (l, w) and shaded toward
    # the lower right (a). Drawn at their own size (KEEP_SIZE).
    "gem": [
        "......mmmm...",
        "....mmlwwlm..",
        "..mmlwlllwlm.",
        ".mlwllwlllllm",
        "mlllwllwllmam",
        "mllllmllwmaam",
        "mmlllmmmmaaam",
        ".mmmmmmmaaaam",
        "..mmmmmaaaam.",
        "...mmmmmmmm..",
    ],
    "great_gem": [
        ".........mmmmmm...",
        "......mmmlwwwllm..",
        "....mmlwwlllllwlm.",
        "...mlwwllllwlllllm",
        "..mlwllllwllwllllm",
        ".mllllwlllllwllmam",
        "mllllwlllllllwmaam",
        "mllllmllllmmmmaaam",
        "mmlllmmllmmmmaaaam",
        ".mmmmmmmmmmmaaaaam",
        "..mmmmmmmmmaaaaam.",
        "...mmmmmmmaaaaam..",
        "....mmmmmmmmmmm...",
    ],
    "pincer": [
        "mm.......",
        "mmm......",
        ".mmm..mm.",
        "..mmm.mmm",
        "..mmmmmmm",
        "...mmmmmm",
        "....aaaa.",
        "...aaaa..",
        "..aaaa...",
        ".aaa.....",
    ],
}


def _ramps(colors):
    main, light, accent = (B._rgb(c) for c in colors)
    ramps = {"m": B._ramp(main), "l": B._ramp(light), "a": B._ramp(accent)}
    ramps.update({key: B._ramp(value) for key, value in FIXED.items()})
    return ramps


def icon(shape, colors):
    """RGBA rows of a 32x32 icon of `shape` in the item's colours."""
    rows = SHAPES[shape]
    # Small shapes are drawn at twice the size (the shading still works per pixel), so every drop
    # fills about two thirds of its icon.
    if shape not in KEEP_SIZE and max(max(len(row) for row in rows), len(rows)) <= GROW_BELOW:
        rows = ["".join(letter * 2 for letter in row)
                for row in rows for _ in range(2)]
    width, height = max(len(row) for row in rows), len(rows)
    left, top = (32 - width) // 2, (32 - height) // 2
    ramps = _ramps(colors)
    parts = {}
    for y, row in enumerate(rows):
        for x, letter in enumerate(row):
            if letter != ".":
                parts[(left + x, top + y)] = letter
    # A dome over each material's bounding box.
    domes = {}
    for letter in set(parts.values()):
        xs = [x for (x, y), l in parts.items() if l == letter]
        ys = [y for (x, y), l in parts.items() if l == letter]
        domes[letter] = ((min(xs) + max(xs) + 1) / 2, (min(ys) + max(ys) + 1) / 2,
                         max(1.5, (max(xs) - min(xs) + 1) / 2), max(1.5, (max(ys) - min(ys) + 1) / 2), 0.8)
    pixels = [[None] * 32 for _ in range(32)]
    for (x, y), letter in parts.items():
        level = B._tone("P", domes[letter], x, y, 0.0, grain=letter in "mlt")
        for dx, dy in ((1, 0), (0, 1)):
            other = parts.get((x + dx, y + dy))
            if other is not None and other != letter:
                level = max(level, 3)
        if letter == "k":
            level = min(level, 3)
        pixels[y][x] = ramps[letter][level] + (255,)
    for (x, y) in list(parts):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if q not in parts and 0 <= q[0] < 32 and 0 <= q[1] < 32:
                pixels[q[1]][q[0]] = B.FIXED["o"] + (255,)
    return pixels
