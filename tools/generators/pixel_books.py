"""Hand-pixelled spellbooks (32x32) in the classic style: a closed tome seen a little from the side
(the front cover, its spine on the left, the page block showing along the right and the bottom,
metal fittings at the corners, a clasp, a ribbon), or an open book with its pages fanned. Every book
has its own design (STYLES): form, cover emblem (the shields' emblems, pixel_shields.py), fittings,
clasp, and extras.

Each part is shaded as a rounded solid lit from the top-left (pixel_bags.py's ramps and domes); the
cover is bevelled at its border, the emblem embossed with a drop shadow, the pages lined, and a
dark outline goes round the whole book.

Letters:  m l a  the item's main, light, and accent colours     g glowing accent
          y gold   s silver   k near-black   w white (pages)   p page lines   e leaf   b bone
          v V    a snake's scales and its pale belly

make_sprites.py calls icon(style, colors).
"""

import math

import pixel_bags as B
import pixel_shields as S

SIZE = 32
OUTLINE = (24, 18, 20)
FIXED = {"v": (86, 140, 58), "V": (196, 200, 120), "y": (216, 168, 58), "s": (176, 184, 192), "k": (40, 30, 32), "w": (236, 228, 204),
         "p": (150, 132, 108), "e": (96, 160, 62), "b": (232, 222, 196), "r": (190, 44, 40), "t": (150, 104, 62),
         "T": (96, 64, 40)}
EMBLEMS = dict(S.EMBLEMS)
EMBLEMS["runes"] = [
    "..aaaaa..",
    ".a.....a.",
    "a..a.a..a",
    "a.aaaaa.a",
    "a..a.a..a",
    "a.aaaaa.a",
    "a..a.a..a",
    ".a.....a.",
    "..aaaaa..",
]
EMBLEMS["moon"] = [
    "...aaa...",
    "..aa.....",
    ".aa......",
    ".aa......",
    ".aa......",
    ".aa......",
    "..aa.....",
    "...aaa...",
]
EMBLEMS["none"] = []

# form: closed or open; emblem; corners: fitting letter or None; clasp; ribbon; extras: patches
# (worn leather), chains, spikes, gem (in the clasp), border (a gold frame instead of a leather
# one), straps (buckled bands across the cover), gems4 (gems set at the frame's corners), runeglow
# (glowing runes round the frame), stars (dots on open pages), flame (over open pages), sprout
# (vines from open pages), snake (a serpent coiled round the closed tome).
STYLES = {
    "primer": {"form": "closed", "emblem": "none", "corners": None, "clasp": "t", "ribbon": False,
               "extras": ("patches", "straps")},
    "apprentice": {"form": "closed", "emblem": "star", "corners": "s", "clasp": None, "ribbon": True,
                   "extras": ("runeglow",)},
    "codex": {"form": "closed", "emblem": "boss", "corners": "y", "clasp": "y", "ribbon": False,
              "extras": ("border", "gems4")},
    "runed": {"form": "closed", "emblem": "runes", "corners": "s", "clasp": "s", "ribbon": False,
              "extras": ("chains", "runeglow")},
    "folio": {"form": "closed", "emblem": "leaf", "corners": None, "clasp": None, "ribbon": True,
              "extras": ("border", "straps")},
    "cobalt": {"form": "closed", "emblem": "sun", "corners": "y", "clasp": "y", "ribbon": True, "extras": ("gems4",)},
    "ember": {"form": "open", "emblem": "flame", "corners": None, "clasp": None, "ribbon": True, "extras": ("flame",)},
    "dusk": {"form": "closed", "emblem": "moon", "corners": "s", "clasp": "s", "ribbon": False,
             "extras": ("spikes", "runeglow")},
    "atlas": {"form": "open", "emblem": "star", "corners": "y", "clasp": None, "ribbon": False, "extras": ("stars",)},
    "bestiary": {"form": "closed", "emblem": "antlers", "corners": "y", "clasp": "t", "ribbon": True,
                 "extras": ("straps",)},
    "wyrmglass": {"form": "closed", "emblem": "dragon", "corners": "y", "clasp": "y", "ribbon": False,
                  "extras": ("gem", "border", "gems4")},
    "verdant": {"form": "open", "emblem": "leaf", "corners": None, "clasp": None, "ribbon": True, "extras": ("sprout",)},
    "gravecall": {"form": "closed", "emblem": "skull", "corners": "s", "clasp": "s", "ribbon": False,
                  "extras": ("chains", "spikes", "runeglow")},
    "serpentcoil": {"form": "closed", "emblem": "none", "corners": "y", "clasp": None, "ribbon": False,
                    "extras": ("snake", "runeglow")},
}


def _snake(cells):
    """A serpent coiled round the tome: its body winds across the cover from the tail hanging off the
    bottom-left to the head rearing over the top-right corner; the scaled back on top, the pale
    belly on the lower edge, the head with glowing eyes and a forked tongue."""
    import math as _m
    book = set(cells)
    body = []
    steps = 160
    for i in range(steps + 1):
        t = i / steps
        x = 2.5 + 24.0 * t
        y = 30.0 - 25.0 * t + 4.2 * _m.sin(t * _m.tau * 1.5)
        # The coils pass behind the tome on every other turn, so it reads as wound round it.
        behind = _m.cos(t * _m.tau * 1.5) > 0.35 and t < 0.85
        body.append((x, y, 1.0 + 0.9 * min(1.0, t * 3.0), behind))
    for x, y, r, behind in body:
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                if dx * dx + dy * dy <= r * r + 0.3:
                    cell = (int(x + dx), int(y + dy))
                    if behind and cell in book:
                        continue
                    cells[cell] = "V" if dy >= r - 0.6 else "v"
    # The head: a wedge rearing over the corner, eyes, and a forked tongue.
    hx, hy = body[-1][0] + 1.0, body[-1][1] - 1.5
    for dy in range(-2, 3):
        for dx in range(-3, 4):
            if (dx / 3.2) ** 2 + (dy / 2.2) ** 2 <= 1.0:
                cells[(int(hx + dx), int(hy + dy))] = "v"
    cells[(int(hx - 1), int(hy - 1))] = "g"
    cells[(int(hx + 1), int(hy - 1))] = "g"
    for dx, dy in ((4, 0), (5, 0), (6, -1), (6, 1)):
        cells[(int(hx + dx), int(hy + dy))] = "r"
# Gems, metal, and glow get a bright glint where the light strikes each part.
GLOSSY = "ysag"


def _rgb(value):
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def _ramps(colors):
    main, light, accent = (_rgb(c) for c in colors[:3])
    ramps = {letter: B._ramp(color) for letter, color in FIXED.items()}
    if sum(accent) < 400:
        accent = tuple(min(255, round(c * 1.6 + 50)) for c in accent)
    ramps.update({"m": B._ramp(main), "l": B._ramp(light), "a": B._ramp(accent),
                  "M": B._ramp(tuple(round(c * 0.62) for c in main)),
                  "g": B._ramp(tuple(min(255, round(c * 1.15 + 30)) for c in accent))})
    return ramps


def _poly(cells, points, letter, over=None):
    for y in range(SIZE):
        fy = y + 0.5
        xs = []
        for (ax, ay), (bx, by) in zip(points, points[1:] + points[:1]):
            if (ay <= fy < by) or (by <= fy < ay):
                xs.append(ax + (fy - ay) * (bx - ax) / (by - ay))
        xs.sort()
        for left, right in zip(xs[::2], xs[1::2]):
            for x in range(int(math.ceil(left - 0.5)), int(math.floor(right - 0.5)) + 1):
                if 0 <= x < SIZE and (over is None or cells.get((x, y)) in over):
                    cells[(x, y)] = letter


def _emblem(cells, name, cx, cy, grow, allowed):
    rows = EMBLEMS[name]
    if not rows:
        return set()
    width = int(max(len(r) for r in rows) * grow)
    height = int(len(rows) * grow)
    left, top = round(cx - width / 2), round(cy - height / 2)
    placed = set()
    for ry, row in enumerate(rows):
        for rx, letter in enumerate(row):
            if letter == ".":
                continue
            for dy in range(int(ry * grow), int((ry + 1) * grow)):
                for dx in range(int(rx * grow), int((rx + 1) * grow)):
                    cell = (left + dx, top + dy)
                    if cells.get(cell) in allowed:
                        cells[cell] = letter
                        placed.add(cell)
    return placed


def _closed(spec, cells):
    """The closed tome: back cover and page block offset down-right, the front cover, the spine."""
    front = [(8, 3), (26, 4), (26, 26), (8, 27)]
    _poly(cells, [(x + 2, y + 2) for x, y in front], "M")
    _poly(cells, [(10, 26), (27, 26), (27, 28), (10, 29)], "w")
    _poly(cells, [(26, 5), (28, 6), (28, 28), (26, 27)], "w")
    _poly(cells, front, "m")
    _poly(cells, [(5, 4), (9, 3), (9, 27), (5, 28)], "M")
    # Lines across the page block.
    for (x, y), letter in list(cells.items()):
        if letter == "w" and ((x >= 26 and y % 2 == 0) or (y >= 27 and x % 2 == 0)):
            cells[(x, y)] = "p"
    # Raised bands across the spine.
    for y in (8, 15, 22):
        for x in range(5, 9):
            if cells.get((x, y)) == "M":
                cells[(x, y)] = "l"
    cover = {cell for cell, letter in cells.items() if letter == "m"}
    # An embossed frame inset from the cover's edge: tooled leather, or gold on ornate tomes.
    frame = "y" if "border" in spec["extras"] else "l"
    for x, y in cover:
        near = [max(abs(dx), abs(dy)) for dx in range(-3, 4) for dy in range(-3, 4) if (x + dx, y + dy) not in cover]
        if near and min(near) == 3:
            cells[(x, y)] = frame
    if "straps" in spec["extras"]:
        for y0 in (9, 20):
            for x in range(5, 29):
                for y in (y0, y0 + 1):
                    if cells.get((x, y)) in ("m", "l", "y", "M"):
                        cells[(x, y)] = "t"
            for x in range(20, 23):
                for y in (y0 - 1, y0 + 2):
                    if (x, y) in cover:
                        cells[(x, y)] = "s"
    if "gems4" in spec["extras"]:
        for x, y in ((12, 7), (22, 8), (22, 23), (12, 24)):
            for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
                cells[(x + dx, y + dy)] = "a"
    if "runeglow" in spec["extras"]:
        for i, (x, y) in enumerate(sorted(c for c in cover if cells.get(c) == "l")):
            if i % 5 == 0:
                cells[(x, y)] = "g"
    if "patches" in spec["extras"]:
        _poly(cells, [(11, 18), (16, 17), (17, 22), (12, 23)], "l", over="m")
        _poly(cells, [(19, 7), (23, 7), (23, 10), (19, 11)], "l", over="m")
    emblem = _emblem(cells, spec["emblem"], 16.5, 15.5, 1.3, ("m", "l", "t", "y", "g"))
    if spec["corners"]:
        for x0, y0, sx, sy in ((9, 4, 1, 1), (25, 5, -1, 1), (25, 25, -1, -1), (9, 26, 1, -1)):
            for i in range(5):
                for j in range(5):
                    if i + j <= 4:
                        cell = (x0 + sx * i, y0 + sy * j)
                        if cell in cover or cells.get(cell) in ("l", "y", "g"):
                            cells[cell] = spec["corners"]
    if spec["clasp"]:
        _poly(cells, [(23, 13), (29, 13), (29, 17), (23, 17)], spec["clasp"])
        if "gem" in spec["extras"]:
            cells[(26, 15)] = cells[(27, 15)] = "a"
    if "chains" in spec["extras"]:
        for i in range(0, 20, 2):
            x, y = 8 + i, 7 + i
            # The chain runs round the emblem, not across it.
            if (x, y) in cover and (x, y) not in emblem:
                cells[(x, y)] = "s"
                if (x + 1, y) in cover and (x + 1, y) not in emblem:
                    cells[(x + 1, y)] = "s"
    if "spikes" in spec["extras"]:
        for x, y, dx, dy in ((7, 2, -1, -1), (27, 3, 1, -1), (28, 29, 1, 1), (6, 29, -1, 1)):
            cells[(x, y)] = cells[(x + dx, y + dy)] = "s"
    if spec["ribbon"]:
        for i in range(4):
            cells[(20 - i // 2, 29 + i)] = "a" if 29 + i < SIZE else cells.get((20, 31))
    if "snake" in spec["extras"]:
        _snake(cells)
    return emblem


def _open(spec, cells):
    """The open book: two pages fanned up from the spine, the covers showing beneath."""
    _poly(cells, [(2, 12), (15, 15), (16, 29), (3, 25)], "M")
    _poly(cells, [(30, 12), (17, 15), (16, 29), (29, 25)], "M")
    _poly(cells, [(3, 10), (15, 13), (16, 27), (4, 23)], "w")
    _poly(cells, [(29, 10), (17, 13), (16, 27), (28, 23)], "w")
    for x in range(15, 18):
        for y in range(13, 29):
            if (x, y) in cells:
                cells[(x, y)] = "p" if x == 16 else cells[(x, y)]
    # Lines of writing on both pages.
    for y in range(14, 25, 2):
        for x in list(range(5, 14)) + list(range(19, 28)):
            if cells.get((x, y)) == "w" and (x * 7 + y * 3) % 5:
                cells[(x, y)] = "p"
    emblem = set()
    if "flame" in spec["extras"]:
        emblem = _emblem(cells, "flame", 16, 7.5, 1.3, (None, "w", "p"))
        for cell in list(emblem):
            pass
    if "stars" in spec["extras"]:
        for x, y in ((6, 15), (10, 18), (8, 21), (22, 16), (25, 19), (21, 22), (12, 14), (24, 13)):
            if (x, y) in cells:
                cells[(x, y)] = "g"
        emblem = _emblem(cells, "star", 16, 6.5, 1.0, (None,))
    if "sprout" in spec["extras"]:
        emblem = _emblem(cells, "leaf", 16, 7.0, 1.2, (None, "w", "p"))
        for y in range(12, 16):
            cells[(16, y)] = "e"
    if spec["corners"]:
        for x, y in ((2, 12), (3, 13), (30, 12), (29, 13), (3, 25), (4, 25), (29, 25), (28, 25)):
            if (x, y) in cells:
                cells[(x, y)] = spec["corners"]
    if spec["ribbon"]:
        for i in range(4):
            cells[(17 + i // 3, 27 + i)] = "a"
    return emblem


def _domes(cells, keep):
    domes, seen = {}, set()
    for start in cells:
        if start in seen or start not in keep:
            continue
        letter = cells[start]
        stack, group = [start], []
        seen.add(start)
        while stack:
            x, y = stack.pop()
            group.append((x, y))
            for q in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if q in keep and cells.get(q) == letter and q not in seen:
                    seen.add(q)
                    stack.append(q)
        xs = [x for x, _ in group]
        ys = [y for _, y in group]
        dome = ((min(xs) + max(xs) + 1) / 2, (min(ys) + max(ys) + 1) / 2,
                max(1.5, (max(xs) - min(xs) + 1) / 2), max(1.5, (max(ys) - min(ys) + 1) / 2), 0.85)
        for cell in group:
            domes[cell] = dome
    return domes


def icon(style, colors):
    """RGBA rows of a 32x32 spellbook icon."""
    spec = STYLES[style]
    cells = {}
    emblem = _closed(spec, cells) if spec["form"] == "closed" else _open(spec, cells)
    cells = {c: l for c, l in cells.items() if l is not None and 0 <= c[0] < SIZE and 0 <= c[1] < SIZE}
    ramps = _ramps(colors)
    domes = _domes(cells, set(cells))
    # Each glossy part's glint: its cell nearest the point the light strikes.
    glints = {}
    for cell, dome in domes.items():
        if cells[cell] in GLOSSY and dome[2] >= 1.5 and dome[3] >= 1.5:
            cx, cy, rx, ry, _depth = dome
            gap = (cell[0] + 0.5 - (cx - rx * 0.4)) ** 2 + (cell[1] + 0.5 - (cy - ry * 0.4)) ** 2
            if dome not in glints or gap < glints[dome][0]:
                glints[dome] = (gap, cell)
    shine = {cell for _gap, cell in glints.values()}
    pixels = [[None] * SIZE for _ in range(SIZE)]
    for (x, y), letter in cells.items():
        level = B._tone("P", domes[(x, y)], x, y, 0.0, grain=letter in "mMt")
        # Leather darkens toward the cover's edges and wears pale at its corners.
        if letter == "m":
            edge = min((max(abs(dx), abs(dy)) for dx in range(-2, 3) for dy in range(-2, 3)
                        if cells.get((x + dx, y + dy)) not in ("m", "l", "y", "a", "g", "t", "s")), default=3)
            if edge <= 1:
                level += 1
            if B._hash(x, y, 5) % 11 == 0:
                level -= 1
        if letter == "v" and (x + y * 2) % 3 == 0:
            level += 1
        # Pages shade toward the spine of an open book.
        if letter in "wp" and spec["form"] == "open":
            level += 1 if abs(x - 16) <= 3 else 0
        if (x, y) in emblem:
            if (x - 1, y) not in emblem or (x, y - 1) not in emblem:
                level -= 1
            elif (x + 1, y) not in emblem or (x, y + 1) not in emblem:
                level += 1
        elif letter in "mM" and ((x - 1, y - 1) in emblem or (x - 1, y) in emblem and (x, y - 1) in emblem):
            level += 2
        elif letter == "m":
            # The cover's bevel: lit along its top and left edges, dark along the right and bottom.
            if cells.get((x - 1, y)) != "m" or cells.get((x, y - 1)) != "m":
                level -= 1
            elif cells.get((x + 1, y)) != "m" or cells.get((x, y + 1)) != "m":
                level += 1
        if letter == "w":
            level = min(level, 2)
        if letter == "g":
            level = min(level, 1)
        seam = (letter not in "gwp" and any(cells.get((x + dx, y + dy)) not in (None, letter)
                                            and ((x, y) in emblem) != ((x + dx, y + dy) in emblem)
                                            for dx, dy in ((1, 0), (0, 1), (-1, 0), (0, -1))))
        color = ramps[letter][max(0, min(4, level))]
        if (x, y) in shine:
            color = tuple(round(c + (255 - c) * 0.7) for c in ramps[letter][0])
        if seam:
            color = tuple(round(c * 0.4 + o * 0.6) for c, o in zip(ramps[letter][4], OUTLINE))
        pixels[y][x] = color + (255,)
    for (x, y) in list(cells):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if q not in cells and 0 <= q[0] < SIZE and 0 <= q[1] < SIZE:
                pixels[q[1]][q[0]] = OUTLINE + (255,)
    return pixels
