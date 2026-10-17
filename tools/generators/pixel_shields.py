"""Hand-pixelled shields (32x32) in the classic style: seen from the front, a bevelled metal rim
round a domed field, the field divided (chevron, quarters, a pale, planks, scales) and charged with
a hand-drawn emblem or a boss, studs round the rim. Every shield has its own design (STYLES).

The shape is a mask (round, heater, kite, tower, oval); the rim is its outer two pixels. The whole
shield is lit as one shallow dome from the top-left, the rim catching the light on its upper-left
and falling dark on its lower-right; emblems are shaded as small rounded solids with a dark line
round them, and a dark outline goes round the whole shield (pixel_bags.py's ramps and domes).

Letters:  m l a  the item's main, light, and accent colours     g glowing accent
          y gold   s silver   k near-black   w white   e leaf   b bone   r red   t T wood

make_sprites.py calls icon(style, colors).
"""

import math

import pixel_bags as B

SIZE = 32
OUTLINE = (24, 18, 20)
FIXED = {"y": (216, 168, 58), "s": (176, 184, 192), "k": (40, 30, 32), "w": (240, 236, 228),
         "e": (96, 160, 62), "b": (232, 222, 196), "r": (190, 44, 40), "t": (150, 104, 62), "T": (96, 64, 40)}

# Emblems, drawn as they sit on the shield (centred on EMBLEM_AT).
EMBLEMS = {
    "boss": [
        "..yyy..",
        ".ywyyy.",
        "yyyyyyy",
        "yyyyyyy",
        "yyyyyyy",
        ".yyyyy.",
        "..yyy..",
    ],
    "cross": [
        "...aa...",
        "...aa...",
        "...aa...",
        "aaaaaaaa",
        "aaaaaaaa",
        "...aa...",
        "...aa...",
        "...aa...",
        "...aa...",
    ],
    "leaf": [
        "....ee....",
        "...eeee...",
        "..eeyeee..",
        ".eeeyeeee.",
        ".eeeyeeee.",
        ".eeeyeeee.",
        "..eeyeee..",
        "...eyee...",
        "....y.....",
        "....y.....",
    ],
    "eagle": [
        "a........a",
        "aa..aa..aa",
        "aaa.ab.aaa",
        ".aaaaaaaa.",
        "..aaaaaa..",
        "...aaaa...",
        "...aaaa...",
        "..a.aa.a..",
        "....aa....",
    ],
    "antlers": [
        "t.t....t.t",
        "tt.t..t.tt",
        ".tt.tt.tt.",
        "..tttttt..",
        "...bbbb...",
        "..bbkbkb..",
        "..bbbbbb..",
        "...bbbb...",
        "....bb....",
    ],
    "dragon": [
        "..a.....a.",
        "..aa...aa.",
        "...aaaaa..",
        "..aaaaaaa.",
        ".aagaaagaa",
        ".aaaaaaaaa",
        "..aaawaaa.",
        "...awawa..",
        "....aaa...",
    ],
    "skull": [
        "..bbbbb..",
        ".bbbbbbb.",
        "bbbbbbbbb",
        "bkkbbbkkb",
        "bkgbbbgkb",
        "bbbbkbbbb",
        ".bbbbbbb.",
        "..bkbkb..",
        "..bbbbb..",
    ],
    "star": [
        "....g....",
        "....g....",
        "...ggg...",
        "gggggwggg",
        ".ggggggg.",
        "..ggggg..",
        "..gg.gg..",
        ".gg...gg.",
        ".g.....g.",
    ],
    "eye": [
        "...aaaaa...",
        ".aawwwwwaa.",
        "aawwgggwwaa",
        "awwgkkkgwwa",
        "aawwgggwwaa",
        ".aawwwwwaa.",
        "...aaaaa...",
    ],
    "rose": [
        "...rrr...",
        "..rrrrr..",
        ".rrwrrrr.",
        ".rrrrrrr.",
        "..rrrrr..",
        "e..rrr..e",
        "ee..e..ee",
        ".eeeeeee.",
        "....e....",
    ],
    "sun": [
        "y...y...y",
        ".y..y..y.",
        "..yyyyy..",
        "..yaaay..",
        "yyyawayyy",
        "..yaaay..",
        "..yyyyy..",
        ".y..y..y.",
        "y...y...y",
    ],
    "axes": [
        "ss.....ss",
        "sss...sss",
        ".ss...ss.",
        "..ttstt..",
        "...tst...",
        "..tt.tt..",
        ".tt...tt.",
        "tt.....tt",
    ],
    "claw": [
        "a...a...a",
        "a...a...a",
        "aa..aa..a",
        ".a...a..a",
        ".aa..aa.a",
        "..a...a.a",
        "..a...a.a",
        "..a...a..",
    ],
    "wing": [
        "........ww",
        "......wwww",
        "....wwwlww",
        "..wwwlllw.",
        ".wwllllw..",
        "wwlllllw..",
        ".wwllww...",
        "...ww.....",
    ],
    "wave": [
        "...wwww...",
        "..wwaaww..",
        ".ww....ww.",
        "ww..ww..w.",
        "a..waaw...",
        "aaaa..aaaa",
        ".aaaaaaaa.",
        "...aaaa...",
    ],
    "flame": [
        "....g....",
        "...gg....",
        "..ggg.g..",
        "..gggggg.",
        ".gggwggg.",
        ".ggwwwgg.",
        "..gwwwg..",
        "...ggg...",
    ],
    "snowflake": [
        "....w....",
        ".w..w..w.",
        "..w.w.w..",
        "...www...",
        "wwwwgwwww",
        "...www...",
        "..w.w.w..",
        ".w..w..w.",
        "....w....",
    ],
}
EMBLEM_AT = (15.5, 14.5)
# Emblems are grown by this much (rows and columns repeat) so they fill the field like classic charges.
EMBLEM_GROW = 1.5

# shape; rim letter; field: plain, chevron, quarters, pale, planks, scales, plates (riveted bands),
# rays (from the emblem), hammered; emblem; studs on the rim; and extras: spikes (out of the rim),
# corners (metal fittings at the top corners), straps (iron bands across the field), sheen (a
# polished field with a glare streak).
STYLES = {
    "oakbuckler": {"shape": "round", "rim": "s", "field": "planks", "emblem": "boss", "studs": 6, "straps": True},
    "hidetarge": {"shape": "round", "rim": "t", "field": "hammered", "emblem": "cross", "studs": 10},
    "bronzeheater": {"shape": "heater", "rim": "y", "field": "chevron", "emblem": "boss", "studs": 0,
                     "corners": True, "sheen": True},
    "steelkite": {"shape": "kite", "rim": "s", "field": "pale", "emblem": "cross", "studs": 4, "sheen": True},
    "silverleaf": {"shape": "heater", "rim": "s", "field": "rays", "emblem": "leaf", "studs": 4},
    "lodgetarge": {"shape": "round", "rim": "T", "field": "quarters", "emblem": "antlers", "studs": 8},
    "drakescale": {"shape": "heater", "rim": "y", "field": "scales", "emblem": "dragon", "studs": 0, "corners": True},
    "cobalttower": {"shape": "tower", "rim": "s", "field": "plates", "emblem": "eagle", "studs": 0, "sheen": True},
    "duskiron": {"shape": "tower", "rim": "k", "field": "hammered", "emblem": "skull", "studs": 6, "spikes": True},
    "starforged": {"shape": "tower", "rim": "y", "field": "rays", "emblem": "star", "studs": 0, "corners": True,
                   "sheen": True},
    "abyssal": {"shape": "oval", "rim": "l", "field": "scales", "emblem": "eye", "studs": 0, "spikes": True},
    # Hunting drops.
    "bandit": {"shape": "round", "rim": "k", "field": "quarters", "emblem": "axes", "studs": 8},
    "lizardscale": {"shape": "oval", "rim": "y", "field": "scales", "emblem": "claw", "studs": 0},
    "harpywing": {"shape": "kite", "rim": "y", "field": "rays", "emblem": "wing", "studs": 0, "sheen": True},
    "cyclopseye": {"shape": "round", "rim": "s", "field": "planks", "emblem": "eye", "studs": 10, "straps": True},
    "gravewarden": {"shape": "tower", "rim": "s", "field": "quarters", "emblem": "cross", "studs": 0, "corners": True},
    "tidebound": {"shape": "oval", "rim": "l", "field": "rays", "emblem": "wave", "studs": 6},
    "cinderforge": {"shape": "tower", "rim": "k", "field": "hammered", "emblem": "flame", "studs": 0, "spikes": True,
                    "corners": True},
    "rimeheart": {"shape": "kite", "rim": "l", "field": "scales", "emblem": "snowflake", "studs": 4, "sheen": True},
}


def _inside(shape, x, y):
    """Whether the pixel centre (x, y) lies on the shield."""
    if shape == "round":
        return math.hypot(x - 15.5, y - 15.5) <= 12.6
    if shape == "oval":
        return ((x - 15.5) / 10.6) ** 2 + ((y - 15.5) / 14.2) ** 2 <= 1.0
    if shape == "heater":
        if y < 3 or y > 29.5:
            return False
        if y < 16:
            half = 12.0 - (1.5 if y < 4.2 else 0.0)
        else:
            half = 12.0 * math.sqrt(max(0.0, 1 - ((y - 16) / 13.6) ** 2))
        return abs(x - 15.5) <= half
    if shape == "kite":
        if y < 2:
            return False
        if y < 10:
            return math.hypot(x - 15.5, (y - 10) * 1.2) <= 10.8
        half = 10.8 * max(0.0, 1 - (y - 10) / 21.0) ** 0.6
        return abs(x - 15.5) <= half
    if shape == "tower":
        if y < 2 or y > 30:
            return False
        if y < 5:
            return abs(x - 15.5) <= 10.5 - (5 - y) ** 1.6 * 0.9
        if y < 24:
            return abs(x - 15.5) <= 10.5
        return abs(x - 15.5) <= 10.5 * (1 - (y - 24) / 6.5)
    raise ValueError(shape)


def _rgb(value):
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def _ramps(colors):
    main, light, accent = (_rgb(c) for c in colors[:3])
    ramps = {letter: B._ramp(color) for letter, color in FIXED.items()}
    # An emblem in a dark accent would vanish on the field: lift it until it reads.
    if sum(accent) < 400:
        accent = tuple(min(255, round(c * 1.6 + 50)) for c in accent)
    ramps.update({"m": B._ramp(main), "l": B._ramp(light), "a": B._ramp(accent),
                  "g": B._ramp(tuple(min(255, round(c * 1.15 + 30)) for c in accent))})
    return ramps


def _layout(style):
    spec = STYLES[style]
    shape = spec["shape"]
    body = {(x, y) for y in range(SIZE) for x in range(SIZE) if _inside(shape, x + 0.5, y + 0.5)}
    cells = {}
    # The rim: the outer two pixels of the shape.
    for x, y in body:
        edge = min((max(abs(dx), abs(dy)) for dx in range(-2, 3) for dy in range(-2, 3)
                    if (x + dx, y + dy) not in body), default=9)
        cells[(x, y)] = spec["rim"] if edge <= 2 else "m"
    rim = {cell for cell, letter in cells.items() if letter == spec["rim"]}
    field = [cell for cell in cells if cell not in rim]
    division = spec["field"]
    for x, y in field:
        if division == "chevron" and (y - 16) > -abs(x + 0.5 - 15.5) * 0.9 and (y - 20) < -abs(x + 0.5 - 15.5) * 0.9:
            cells[(x, y)] = "l"
        elif division == "quarters" and ((x < 16) == (y < 15)):
            cells[(x, y)] = "l"
        elif division == "pale" and 13 <= x <= 18:
            cells[(x, y)] = "l"
        elif division == "rays":
            angle = math.degrees(math.atan2(y + 0.5 - EMBLEM_AT[1], x + 0.5 - EMBLEM_AT[0])) % 30
            if angle < 9:
                cells[(x, y)] = "l"
    if spec.get("straps"):
        for x, y in field:
            if abs(x + 0.5 - 15.5) <= 1.2 or abs(y + 0.5 - 15.5) <= 1.2:
                cells[(x, y)] = "k"
    if spec.get("corners"):
        top = min(y for _, y in body)
        for x, y in body:
            left = min(xx for xx, yy in body if yy == y)
            right = max(xx for xx, yy in body if yy == y)
            near_top = y - top <= 4
            if near_top and (x - left <= 4 or right - x <= 4) and (y - top <= 1 or x - left <= 1 or right - x <= 1):
                cells[(x, y)] = "y"
                rim.discard((x, y))
    # Emblem.
    rows = EMBLEMS[spec["emblem"]]
    width = int(max(len(r) for r in rows) * EMBLEM_GROW)
    height = int(len(rows) * EMBLEM_GROW)
    left, top = round(EMBLEM_AT[0] - width / 2), round(EMBLEM_AT[1] - height / 2)
    emblem = set()
    for ry, row in enumerate(rows):
        for rx, letter in enumerate(row):
            if letter == ".":
                continue
            for dy in range(int(ry * EMBLEM_GROW), int((ry + 1) * EMBLEM_GROW)):
                for dx in range(int(rx * EMBLEM_GROW), int((rx + 1) * EMBLEM_GROW)):
                    if (left + dx, top + dy) in cells and (left + dx, top + dy) not in rim:
                        cells[(left + dx, top + dy)] = letter
                        emblem.add((left + dx, top + dy))
    # Studs round the rim, evenly spaced along its middle line.
    studs = set()
    if spec["studs"]:
        ring = sorted((cell for cell in rim if all((cell[0] + dx, cell[1] + dy) in cells
                                                     for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))),
                      key=lambda c: math.atan2(c[1] + 0.5 - 15.5, c[0] + 0.5 - 15.5))
        step = max(1, len(ring) // spec["studs"])
        for cell in ring[::step][:spec["studs"]]:
            studs.add(cell)
    # Spikes out of the rim at the sides and the top.
    if spec.get("spikes"):
        for side in (-1, 1):
            for k, (y, length) in enumerate(((9, 4), (16, 3))):
                xs = [x for x, yy in body if yy == y]
                if not xs:
                    continue
                x0 = max(xs) if side == 1 else min(xs)
                for i in range(1, length + 1):
                    cells[(x0 + side * i, y - (i // 2 if k == 0 else 0))] = "s"
    return cells, rim, emblem, studs, division, spec


def _domes(cells, letters_of):
    domes, seen = {}, set()
    for start in cells:
        if start in seen:
            continue
        key = letters_of(start)
        stack, group = [start], []
        seen.add(start)
        while stack:
            x, y = stack.pop()
            group.append((x, y))
            for q in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if q in cells and q not in seen and letters_of(q) == key:
                    seen.add(q)
                    stack.append(q)
        xs = [x for x, _ in group]
        ys = [y for _, y in group]
        dome = ((min(xs) + max(xs) + 1) / 2, (min(ys) + max(ys) + 1) / 2,
                max(1.5, (max(xs) - min(xs) + 1) / 2), max(1.5, (max(ys) - min(ys) + 1) / 2), 0.9)
        for cell in group:
            domes[cell] = dome
    return domes


def icon(style, colors):
    """RGBA rows of a 32x32 shield icon."""
    cells, rim, emblem, studs, division, spec = _layout(style)
    ramps = _ramps(colors)
    xs = [x for x, _ in cells]
    ys = [y for _, y in cells]
    cx, cy = (min(xs) + max(xs) + 1) / 2, (min(ys) + max(ys) + 1) / 2
    rx, ry = (max(xs) - min(xs) + 1) / 2, (max(ys) - min(ys) + 1) / 2
    # The whole shield is one shallow dome; emblem parts are small domes of their own.
    whole = (cx, cy, rx, ry, 0.8)
    small = _domes({c: cells[c] for c in emblem}, lambda c: cells[c])
    outside = lambda q: q not in cells  # noqa: E731
    pixels = [[None] * SIZE for _ in range(SIZE)]
    for (x, y), letter in cells.items():
        if not (0 <= x < SIZE and 0 <= y < SIZE):
            continue
        u, w = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
        facing = u + w
        if (x, y) in emblem:
            # Embossed: lit along its upper-left edges, dark along its lower-right ones.
            level = B._tone("P", small[(x, y)], x, y, 0.0)
            if (x - 1, y) not in emblem or (x, y - 1) not in emblem:
                level -= 1
            elif (x + 1, y) not in emblem or (x, y + 1) not in emblem:
                level += 1
        elif (x, y) in rim:
            # A three-step bevel: the outer ring lit on the upper-left and dark on the lower-right,
            # the inner ring the other way round, like a raised metal band.
            outer = any(outside((x + dx, y + dy)) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if outer:
                level = 0 if facing < -0.25 else 4 if facing > 0.35 else 2
            else:
                level = 3 if facing < -0.25 else 1 if facing > 0.35 else 2
        else:
            level = B._tone("P", whole, x, y, 0.0, grain=letter in "tTm" and division not in ("plates",))
            # The rim's shadow falls on the field below and right of it; the field's far edge rises.
            if (x - 1, y) in rim or (x, y - 1) in rim or (x - 1, y - 1) in rim:
                level += 2
            elif (x + 1, y) in rim or (x, y + 1) in rim:
                level -= 1
            # The emblem's drop shadow.
            if (x - 1, y - 1) in emblem or (x - 1, y) in emblem and (x, y - 1) in emblem:
                level += 2
            if division == "planks" and (x - 2) % 5 == 0:
                level = 4
            if division == "scales" and (x + (y // 2) % 2 * 2) % 4 == 0 and y % 2 == 0:
                level += 2
            if division == "hammered":
                dent = B._hash(x, y, 11) % 7
                level += 1 if dent == 0 else -1 if dent == 1 else 0
            if division == "plates" and (y - 3) % 6 == 0:
                level = 4
            if spec.get("sheen") and letter in "ml" and abs(u + w + 0.95) < 0.16:
                level = 0
        seam = (letter not in "gw" and (x, y) not in rim
                and any(cells.get((x + dx, y + dy)) not in (None, letter) and ((x, y) in emblem) != ((x + dx, y + dy) in emblem)
                        for dx, dy in ((1, 0), (0, 1), (-1, 0), (0, -1))))
        if letter == "g":
            level = min(level, 1)
        if letter == "w":
            level = 0
        color = ramps[letter][max(0, min(4, level))]
        if seam:
            color = tuple(round(c * 0.4 + o * 0.6) for c, o in zip(ramps[letter][4], OUTLINE))
        pixels[y][x] = color + (255,)
    # Rivets: a bright dot with a shadow below-right, on the rim and at the ends of plate seams.
    rivets = set(studs)
    if division == "plates":
        for y in range(SIZE):
            row = sorted(x for x, yy in cells if yy == y and (x, y) not in rim)
            if row and (y - 3) % 6 == 0:
                rivets |= {(row[0] + 1, y), (row[-1] - 1, y)}
    for x, y in rivets:
        if (x, y) in cells:
            pixels[y][x] = tuple(round(c + (255 - c) * 0.65) for c in ramps["s"][0]) + (255,)
            if (x + 1, y + 1) in cells:
                pixels[y + 1][x + 1] = ramps["s"][4] + (255,)
    for (x, y) in list(cells):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if q not in cells and 0 <= q[0] < SIZE and 0 <= q[1] < SIZE:
                pixels[q[1]][q[0]] = OUTLINE + (255,)
    return pixels
