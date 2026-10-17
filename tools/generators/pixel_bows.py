"""Hand-pixelled bows (32x32) in the classic style: the bow lies on the diagonal, its limb arching
toward the top-left from the tip at the top-right to the tip at the bottom-left, the string drawn
straight between the tips, a wrapped grip in the middle. Every bow has its own design (STYLES):
length, limb thickness, material, grip, tips, and ornaments along the limb.

The limb is a curve rasterised pixel by pixel; each pixel knows how far across the limb it lies,
so the outer (upper-left) edge is lit and the inner edge falls into shade, in five-tone ramps
(pixel_bags.py). Ornaments are shaded as small rounded solids, and a dark outline goes round the
whole bow except the string.

Letters:  m l a  the item's main, light, and accent colours     g glowing accent
          t T    wood, dark wood       y gold    s silver    w white   e leaf   b bone

make_sprites.py calls icon(style, colors).
"""

import math

import pixel_bags as B

SIZE = 32
OUTLINE = (24, 18, 20)
FIXED = {"t": (150, 104, 62), "T": (96, 64, 40), "y": (216, 168, 58), "s": (176, 184, 192),
         "w": (236, 232, 222), "e": (96, 160, 62), "b": (232, 222, 196), "k": (40, 30, 30)}
STRING = (226, 222, 208)

# reach: how far the tips sit from the corners (a short bow has a larger reach);
# arch: how far the limb's middle bows toward the top-left; width: the limb's width at the grip;
# shape: round (a plain arc), recurve (the tips flick further out), deflex (the grip set back,
# as on horn composite bows);
# limb: its letter; grip: letter and length; tips: curl, nock, blade, feather, flame, icicle, horn;
# ornaments: leaves, spikes, bands, fins, veins, thorns, gems, inlay (a stripe of the accent
# along the limb), notches (carved ticks), wraps (cord bound round the limb near the tips), riser
# (a broad plated grip), crescent (a moon at the grip).
STYLES = {
    "willow": {"reach": 6, "arch": 7.0, "width": 2.4, "shape": "round", "limb": "t", "grip": ("T", 2),
               "tips": "nock", "ornaments": ("notches", "wraps")},
    "yew": {"reach": 2, "arch": 6.5, "width": 2.2, "shape": "round", "limb": "T", "grip": ("t", 3),
            "tips": "nock", "ornaments": ("wraps", "notches")},
    "bronze": {"reach": 4, "arch": 7.5, "width": 2.4, "shape": "recurve", "limb": "t", "grip": ("y", 3),
               "tips": "curl", "ornaments": ("bands", "inlay", "riser")},
    "flat": {"reach": 5, "arch": 5.0, "width": 3.0, "shape": "round", "limb": "l", "grip": ("t", 4),
             "tips": "nock", "ornaments": ("bands", "notches", "wraps")},
    "steel": {"reach": 2, "arch": 7.0, "width": 2.2, "shape": "round", "limb": "s", "grip": ("y", 3),
              "tips": "blade", "ornaments": ("inlay", "riser")},
    "silverleaf": {"reach": 3, "arch": 8.0, "width": 2.2, "shape": "recurve", "limb": "m", "grip": ("y", 3),
                   "tips": "curl", "ornaments": ("leaves", "inlay")},
    "ridgewind": {"reach": 4, "arch": 8.0, "width": 2.4, "shape": "recurve", "limb": "m", "grip": ("t", 3),
                  "tips": "feather", "ornaments": ("bands", "wraps")},
    "hornbow": {"reach": 4, "arch": 8.5, "width": 2.8, "shape": "deflex", "limb": "b", "grip": ("m", 3),
                "tips": "horn", "ornaments": ("bands", "riser")},
    "wyrmglass": {"reach": 3, "arch": 8.5, "width": 2.4, "shape": "recurve", "limb": "a", "grip": ("s", 3),
                  "tips": "blade", "ornaments": ("fins", "gems", "riser")},
    "cinderheart": {"reach": 3, "arch": 9.0, "width": 2.6, "shape": "deflex", "limb": "m", "grip": ("y", 3),
                    "tips": "flame", "ornaments": ("veins", "gems", "spikes")},
    "eclipse": {"reach": 3, "arch": 8.5, "width": 2.4, "shape": "recurve", "limb": "m", "grip": ("y", 4),
                "tips": "curl", "ornaments": ("spikes", "crescent", "inlay")},
    "rimestring": {"reach": 2, "arch": 7.5, "width": 2.4, "shape": "round", "limb": "l", "grip": ("s", 3),
                   "tips": "icicle", "ornaments": ("thorns", "gems", "inlay")},
}
# Limb materials that shine: a bright stripe runs along their outer edge.
GLOSSY = "smayl"


def _rgb(value):
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def _ramps(colors):
    main, light, accent = (_rgb(c) for c in colors[:3])
    ramps = {letter: B._ramp(color) for letter, color in FIXED.items()}
    ramps.update({"m": B._ramp(main), "l": B._ramp(light), "a": B._ramp(accent),
                  "g": B._ramp(tuple(min(255, round(c * 1.15 + 30)) for c in accent))})
    return ramps


class Bow:
    """The bow's geometry: from the top-right tip to the bottom-left tip, the limb standing off the
    string toward the top-left by `arch` times a full, rounded sine."""

    def __init__(self, spec, shrink=0):
        r = max(4, spec["reach"]) + shrink
        self.a = (SIZE - 1 - r - 0.5, r + 0.5)
        self.b = (r + 0.5, SIZE - 1 - r - 0.5)
        self.arch = spec["arch"] * 0.85
        self.width = spec["width"]
        self.shape = spec["shape"]

    def point(self, t):
        depth = self.arch * math.sin(math.pi * t) ** 0.7
        if self.shape == "recurve":
            depth += self.arch * 0.35 * max(0.0, (abs(2 * t - 1) - 0.7) / 0.3) ** 2
        elif self.shape == "deflex":
            depth -= self.arch * 0.3 * math.exp(-((t - 0.5) / 0.09) ** 2)
        return (self.a[0] + (self.b[0] - self.a[0]) * t - depth / math.sqrt(2),
                self.a[1] + (self.b[1] - self.a[1]) * t - depth / math.sqrt(2))

    def tangent(self, t):
        e = 1e-3
        x0, y0 = self.point(max(0.0, t - e))
        x1, y1 = self.point(min(1.0, t + e))
        n = math.hypot(x1 - x0, y1 - y0)
        return (x1 - x0) / n, (y1 - y0) / n

    def outward(self, t):
        """The unit normal pointing away from the string (toward the top-left)."""
        tx, ty = self.tangent(t)
        nx, ny = ty, -tx
        return (nx, ny) if nx + ny < 0 else (-nx, -ny)

    def half_width(self, t):
        return max(0.9, self.width / 2 * (1 - 0.3 * abs(2 * t - 1) ** 1.5))


def _limb(bow, letter, cells, across, along):
    """Rasterises the limb: every pixel within half the width of the curve, with its offset across
    the limb (-1 inner edge .. +1 outer edge)."""
    samples = [bow.point(i / 400) for i in range(401)]
    for y in range(SIZE):
        for x in range(SIZE):
            px, py = x + 0.5, y + 0.5
            best, best_t = None, 0.0
            for i in range(0, 401, 2):
                sx, sy = samples[i]
                d = (px - sx) ** 2 + (py - sy) ** 2
                if best is None or d < best:
                    best, best_t = d, i / 400
            t = best_t
            sx, sy = bow.point(t)
            nx, ny = bow.outward(t)
            offset = (px - sx) * nx + (py - sy) * ny
            hw = bow.half_width(t)
            if math.sqrt(best) <= hw + 0.15:
                cells[(x, y)] = letter
                across[(x, y)] = max(-1.0, min(1.0, offset / max(0.6, hw)))
                along[(x, y)] = t


def _blob(cells, cx, cy, rx, ry, letter):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0 and 0 <= x < SIZE and 0 <= y < SIZE:
                cells[(x, y)] = letter


def _line(cells, ax, ay, bx, by, letter):
    steps = max(1, int(max(abs(bx - ax), abs(by - ay)) * 2))
    for i in range(steps + 1):
        x, y = ax + (bx - ax) * i / steps, ay + (by - ay) * i / steps
        if 0 <= int(x) < SIZE and 0 <= int(y) < SIZE:
            cells[(int(x), int(y))] = letter


def _tips(bow, spec, cells):
    style = spec["tips"]
    for t, sign in ((0.0, 1), (1.0, -1)):
        x, y = bow.point(t)
        tx, ty = bow.tangent(t)
        # Pointing out past the tip, along the limb.
        ox, oy = -tx * sign, -ty * sign
        nx, ny = bow.outward(t)
        if style == "curl":
            # A recurve: the tip turns back outward, away from the string.
            for k in range(1, 4):
                _blob(cells, x + ox * k * 0.9 + nx * k * 0.7, y + oy * k * 0.9 + ny * k * 0.7, 1.0, 1.0, spec["limb"])
        elif style == "nock":
            _blob(cells, x + ox * 0.8, y + oy * 0.8, 1.3, 1.3, "y")
        elif style == "blade":
            for k in range(1, 5):
                _blob(cells, x + ox * k + nx * k * 0.5, y + oy * k + ny * k * 0.5, max(0.6, 1.4 - k * 0.25),
                      max(0.6, 1.4 - k * 0.25), "s")
        elif style == "feather":
            _blob(cells, x + ox * 2.2 + nx * 1.4, y + oy * 2.2 + ny * 1.4, 1.4, 1.4, "w")
            _blob(cells, x + ox * 3.4 + nx * 2.4, y + oy * 3.4 + ny * 2.4, 1.0, 1.0, "w")
        elif style == "flame":
            for k, size in ((1, 1.5), (2, 1.2), (3, 0.8)):
                _blob(cells, x + ox * k + nx * k * 0.4, y + oy * k + ny * k * 0.4, size, size, "g")
        elif style == "icicle":
            _line(cells, x, y, x + ox * 4 + nx * 1.5, y + oy * 4 + ny * 1.5, "w")
            _line(cells, x + nx, y + ny, x + ox * 2.5 + nx * 3.5, y + oy * 2.5 + ny * 3.5, "w")
        elif style == "horn":
            for k in range(1, 4):
                _blob(cells, x + ox * k * 0.8 - nx * k * 0.6, y + oy * k * 0.8 - ny * k * 0.6, 1.0, 1.0, "b")


def _ornaments(bow, spec, cells, across, along):
    kinds = spec["ornaments"]
    limb = spec["limb"]
    for cell, t in along.items():
        if cells.get(cell) != limb:
            continue
        # An inlay down the middle of each limb, carved notches across it.
        if "inlay" in kinds and abs(across[cell]) < 0.3 and 0.1 < abs(t - 0.5) < 0.4:
            cells[cell] = "a" if limb != "a" else "y"
        if "notches" in kinds and 0.1 < abs(t - 0.5) and round(t * 400) % 22 in (0, 1) and across[cell] > -0.4:
            cells[cell] = "k"
    if "wraps" in kinds:
        for t in (0.08, 0.11, 0.89, 0.92):
            x, y = bow.point(t)
            nx, ny = bow.outward(t)
            hw = bow.half_width(t) + 0.3
            _line(cells, x - nx * hw, y - ny * hw, x + nx * hw, y + ny * hw, "w")
    spots = (0.14, 0.24, 0.34, 0.66, 0.76, 0.86) if "leaves" in kinds else (0.2, 0.32, 0.68, 0.8)
    for t in spots:
        x, y = bow.point(t)
        nx, ny = bow.outward(t)
        hw = bow.half_width(t)
        if "leaves" in kinds:
            tx, ty = bow.tangent(t)
            _blob(cells, x + nx * (hw + 1.6) + tx, y + ny * (hw + 1.6) + ty, 1.8, 1.8, "e")
        if "spikes" in kinds:
            _line(cells, x + nx * hw, y + ny * hw, x + nx * (hw + 4.0), y + ny * (hw + 4.0), "s")
            _line(cells, x + nx * hw + 0.6, y + ny * hw, x + nx * (hw + 3.0) + 0.6, y + ny * (hw + 3.0), "s")
        if "thorns" in kinds:
            _line(cells, x + nx * hw, y + ny * hw, x + nx * (hw + 2.5), y + ny * (hw + 2.5), "w")
        if "fins" in kinds and t in (0.32, 0.68):
            tx, ty = bow.tangent(t)
            for k in range(3):
                _blob(cells, x + nx * (hw + 0.8 + k * 0.8) + tx * k * 0.6, y + ny * (hw + 0.8 + k * 0.8) + ty * k * 0.6,
                      0.9, 0.9, "l")
    if "bands" in kinds:
        for t in (0.15, 0.85):
            x, y = bow.point(t)
            tx, ty = bow.tangent(t)
            nx, ny = bow.outward(t)
            hw = bow.half_width(t)
            _line(cells, x - nx * hw, y - ny * hw, x + nx * hw, y + ny * hw, "y")
            _line(cells, x - nx * hw + tx * 0.7, y - ny * hw + ty * 0.7, x + nx * hw + tx * 0.7, y + ny * hw + ty * 0.7, "y")
    if "veins" in kinds:
        for i in range(60, 341, 3):
            t = i / 400
            if abs(t - 0.5) < 0.08:
                continue
            x, y = bow.point(t)
            nx, ny = bow.outward(t)
            wave = math.sin(t * 40) * bow.half_width(t) * 0.5
            cell = (int(x + nx * wave), int(y + ny * wave))
            if cells.get(cell) == spec["limb"]:
                cells[cell] = "g"


def _grip(bow, spec, cells):
    letter, length = spec["grip"]
    if "riser" in spec["ornaments"]:
        # A broad riser: metal plates above and below the grip, wider than the limb.
        for t in (0.5 - (length + 2) / 400 * 10, 0.5 + (length + 2) / 400 * 10):
            x, y = bow.point(t)
            nx, ny = bow.outward(t)
            hw = bow.half_width(t)
            _blob(cells, x + nx * 0.6, y + ny * 0.6, hw + 0.9, hw + 0.9, "y" if letter != "y" else "s")
    for i in range(-length * 10, length * 10 + 1):
        t = 0.5 + i / 400
        x, y = bow.point(t)
        nx, ny = bow.outward(t)
        hw = bow.half_width(t) + 0.6
        _line(cells, x - nx * hw, y - ny * hw, x + nx * hw, y + ny * hw, letter)
    if "gems" in spec["ornaments"]:
        x, y = bow.point(0.5)
        nx, ny = bow.outward(0.5)
        hw = bow.half_width(0.5)
        _blob(cells, x + nx * (hw + 1.6), y + ny * (hw + 1.6), 2.2, 2.2, "a")


def _crescent(bow, spec, cells):
    """A crescent moon standing off the grip on the outer side (drawn after the grip)."""
    if "crescent" not in spec["ornaments"]:
        return
    x, y = bow.point(0.5)
    nx, ny = bow.outward(0.5)
    hw = bow.half_width(0.5)
    cx, cy = x + nx * (hw + 2.9), y + ny * (hw + 2.9)
    moon, cut = {}, {}
    _blob(moon, cx, cy, 2.7, 2.7, "w")
    _blob(cut, cx - nx * 1.4 + ny * 0.8, cy - ny * 1.4 - nx * 0.8, 2.4, 2.4, "x")
    for cell in moon:
        if cell not in cut:
            cells[cell] = "w"


def _domes(cells, skip):
    domes, seen = {}, set()
    for start in cells:
        if start in seen or start in skip:
            continue
        letter = cells[start]
        stack, group = [start], []
        seen.add(start)
        while stack:
            x, y = stack.pop()
            group.append((x, y))
            for q in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if cells.get(q) == letter and q not in seen and q not in skip:
                    seen.add(q)
                    stack.append(q)
        xs = [x for x, _ in group]
        ys = [y for _, y in group]
        dome = ((min(xs) + max(xs) + 1) / 2, (min(ys) + max(ys) + 1) / 2,
                max(1.5, (max(xs) - min(xs) + 1) / 2), max(1.5, (max(ys) - min(ys) + 1) / 2), 0.9)
        for cell in group:
            domes[cell] = dome
    return domes


def icon(style, colors, shrink=0):
    """RGBA rows of a 32x32 bow icon. A bow whose tips or ornaments would reach the icon's edge is
    drawn again a pixel shorter, until it keeps two pixels clear for the outline and the finish."""
    spec = STYLES[style]
    bow = Bow(spec, shrink)
    cells, across, along = {}, {}, {}
    _limb(bow, spec["limb"], cells, across, along)
    limb = set(cells)
    _ornaments(bow, spec, cells, across, along)
    _tips(bow, spec, cells)
    _grip(bow, spec, cells)
    _crescent(bow, spec, cells)
    ramps = _ramps(colors)
    # The string, straight from tip to tip on the inner side.
    string = set()
    steps = 120
    for i in range(steps + 1):
        x = bow.a[0] + (bow.b[0] - bow.a[0]) * i / steps
        y = bow.a[1] + (bow.b[1] - bow.a[1]) * i / steps
        cell = (int(x), int(y))
        if cell not in cells:
            string.add(cell)
    domes = _domes(cells, set())
    pixels = [[None] * SIZE for _ in range(SIZE)]
    for (x, y), letter in cells.items():
        if (x, y) in limb and letter in (spec["limb"], "a", "y", "k") and letter != "k":
            # Across the limb: the outer edge lit (a bright stripe on glossy limbs), the inner
            # edge in shade, a grain in wood; the far half of each limb a little darker.
            level = round(1.8 - across[(x, y)] * 2.0)
            if letter in "tTb" and B._hash(x, y, 3) % 5 == 0:
                level += 1
            # Glossy limbs: their outer edge one tone brighter, not a white stripe.
            if across[(x, y)] > 0.75 and letter in GLOSSY:
                level -= 1
        elif letter == "k":
            pixels[y][x] = FIXED["k"] + (255,)
            continue
        else:
            level = B._tone("P", domes[(x, y)], x, y, 0.0)
            if cells.get((x - 1, y)) != letter or cells.get((x, y - 1)) != letter:
                level -= 1
        # Where two parts meet, a dark line separates them.
        if any(cells.get((x + dx, y + dy)) not in (None, letter) for dx, dy in ((1, 0), (0, 1))) and letter not in "gw":
            pixels[y][x] = tuple(round(c * 0.45 + o * 0.55) for c, o in zip(ramps[letter][4], OUTLINE)) + (255,)
            continue
        if letter == "g":
            level = min(level, 1)
        pixels[y][x] = ramps[letter][max(0, min(4, level))] + (255,)
    for x, y in string:
        if 0 <= x < SIZE and 0 <= y < SIZE:
            pixels[y][x] = STRING + (255,)
    for (x, y) in list(cells):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if q not in cells and q not in string and 0 <= q[0] < SIZE and 0 <= q[1] < SIZE:
                pixels[q[1]][q[0]] = OUTLINE + (255,)
    solid = [(x, y) for y in range(SIZE) for x in range(SIZE) if pixels[y][x] is not None]
    if shrink < 6 and (min(x for x, _ in solid) < 1 or min(y for _, y in solid) < 1
                       or max(x for x, _ in solid) > SIZE - 2 or max(y for _, y in solid) > SIZE - 2
                       or any(c[0] < 1 or c[1] < 1 or c[0] > SIZE - 2 or c[1] > SIZE - 2 for c in cells)):
        return icon(style, colors, shrink + 1)
    return pixels
