"""Hand-pixelled crossbows (32x32) in the classic style: the stock on the diagonal from its butt at
the bottom-left to its nose at the top-right, the prod (the bow) bent across the nose, the string
drawn back to the nut, a bolt loaded along the top, a trigger underneath. Every crossbow has its own
design (STYLES): prod material and weight, stock, bands, and fittings (a stirrup at the nose, a
windlass crank at the butt, a gem).

Parts are rasterised along lines and arcs; each knows how far across it a pixel lies, so the
upper-left side is lit and the lower-right side shaded (pixel_bags.py's ramps); a dark outline goes
round everything except the string.

Letters:  m l a  the item's main, light, and accent colours     g glowing accent
          t T    wood, dark wood       y gold    s silver    k near-black    w white

make_sprites.py calls icon(style, colors).
"""

import math

import pixel_bags as B

SIZE = 32
OUTLINE = (24, 18, 20)
FIXED = {"t": (150, 104, 62), "T": (96, 64, 40), "y": (216, 168, 58), "s": (176, 184, 192),
         "k": (40, 30, 32), "w": (236, 232, 222)}
STRING = (226, 222, 208)
BUTT = (6.0, 26.0)
NOSE = (23.0, 9.0)

# prod: letter, half-length, thickness, bend; stock letter; bands (positions along the stock, 0 butt
# .. 1 nose); stirrup, crank, gem.
STYLES = {
    "cobalt": {"prod": ("m", 10.5, 2.0, 3.0), "stock": "t", "bands": (0.55,), "stirrup": False, "crank": False,
               "gem": False},
    "starforged": {"prod": ("y", 11.0, 2.2, 3.5), "stock": "T", "bands": (0.3, 0.55, 0.8), "stirrup": False,
                   "crank": False, "gem": True},
    "arbalest": {"prod": ("s", 11.5, 3.0, 2.5), "stock": "m", "bands": (0.4, 0.7), "stirrup": True, "crank": True,
                 "gem": False},
}


def _rgb(value):
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def _ramps(colors):
    main, light, accent = (_rgb(c) for c in colors[:3])
    ramps = {letter: B._ramp(color) for letter, color in FIXED.items()}
    ramps.update({"m": B._ramp(main), "l": B._ramp(light), "a": B._ramp(accent),
                  "g": B._ramp(tuple(min(255, round(c * 1.15 + 30)) for c in accent))})
    return ramps


def _segment(cells, across, a, b, half, letter):
    """A straight bar from a to b, `half` pixels either side of its line; records the offset across
    it (+1 at the upper-left edge)."""
    ax, ay = a
    bx, by = b
    length = math.hypot(bx - ax, by - ay)
    ux, uy = (bx - ax) / length, (by - ay) / length
    nx, ny = uy, -ux
    if nx + ny > 0:
        nx, ny = -nx, -ny
    for y in range(SIZE):
        for x in range(SIZE):
            px, py = x + 0.5 - ax, y + 0.5 - ay
            along = px * ux + py * uy
            side = px * nx + py * ny
            if -0.3 <= along <= length + 0.3 and abs(side) <= half:
                cells[(x, y)] = letter
                across[(x, y)] = side / max(0.6, half)


def _point(t):
    return BUTT[0] + (NOSE[0] - BUTT[0]) * t, BUTT[1] + (NOSE[1] - BUTT[1]) * t


def icon(style, colors):
    """RGBA rows of a 32x32 crossbow icon."""
    spec = STYLES[style]
    cells, across = {}, {}
    # The stock: broad at the butt, narrowing toward the nose; its nose capped in metal.
    _segment(cells, across, BUTT, _point(0.35), 2.4, spec["stock"])
    _segment(cells, across, _point(0.3), _point(0.92), 1.6, spec["stock"])
    _segment(cells, across, _point(0.9), NOSE, 1.7, "s")
    for t in spec["bands"]:
        _segment(cells, across, _point(t - 0.02), _point(t + 0.02), 2.0, "y")
    # A metal butt plate, a carved grip with an inlay, and a lock plate with its screws.
    _segment(cells, across, BUTT, _point(0.05), 2.6, "s")
    _segment(cells, across, _point(0.14), _point(0.3), 1.6, "T" if spec["stock"] != "T" else "k")
    gx, gy = _point(0.22)
    cells[(int(gx), int(gy))] = "y"
    lx, ly = _point(0.4)
    _segment(cells, across, (lx - 1.4, ly + 1.4), (lx + 1.4, ly - 1.4), 1.1, "s")
    for t in (0.36, 0.44):
        rx, ry = _point(t)
        cells[(int(rx), int(ry))] = "k"
    # Gold rivets along the forestock.
    for t in (0.62, 0.68, 0.74):
        rx, ry = _point(t)
        cells[(int(rx - 0.5), int(ry - 0.5))] = "y"
    # The trigger under the stock, behind the nut.
    tx, ty = _point(0.42)
    _segment(cells, across, (tx + 1.0, ty + 1.0), (tx + 2.5, ty + 4.0), 0.7, "k")
    # The prod: an arc across the nose, bent toward the front, tips swept back.
    letter, half_length, thick, bend = spec["prod"]
    ux, uy = (NOSE[0] - BUTT[0]), (NOSE[1] - BUTT[1])
    n = math.hypot(ux, uy)
    ux, uy = ux / n, uy / n
    px, py = -uy, ux
    base = _point(0.86)
    tips = []
    previous = None
    for i in range(-20, 21):
        s = i / 20
        x = base[0] + px * s * half_length + ux * bend * (1 - s * s)
        y = base[1] + py * s * half_length + uy * bend * (1 - s * s)
        width = thick / 2 * (1 - 0.45 * abs(s))
        if previous is not None:
            _segment(cells, across, previous, (x, y), width, letter)
        previous = (x, y)
        if i in (-20, 20):
            tips.append((x, y))
    # Nocks capping the prod's tips, and the bridle binding the prod to the stock.
    for tx, ty in tips:
        for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
            cells[(int(tx - 0.5) + dx, int(ty - 0.5) + dy)] = "y" if letter != "y" else "s"
            across[(int(tx - 0.5) + dx, int(ty - 0.5) + dy)] = 0.4
    bx, by = base[0] + ux * bend, base[1] + uy * bend
    _segment(cells, across, (bx - ux * 1.6, by - uy * 1.6), (bx + ux * 0.6, by + uy * 0.6), thick / 2 + 1.0, "k")
    # The string from each tip back to the nut, and the bolt along the top.
    nut = _point(0.5)
    string = set()
    for tip in tips:
        steps = 60
        for i in range(steps + 1):
            x = tip[0] + (nut[0] - tip[0]) * i / steps
            y = tip[1] + (nut[1] - tip[1]) * i / steps
            cell = (int(x), int(y))
            if cell not in cells:
                string.add(cell)
    bolt_from, bolt_to = _point(0.48), (NOSE[0] + ux * 3.5, NOSE[1] + uy * 3.5)
    _segment(cells, across, (bolt_from[0] - 0.8, bolt_from[1] - 0.8), (bolt_to[0] - 0.8, bolt_to[1] - 0.8), 0.6, "t")
    _segment(cells, across, (bolt_to[0] - 1.4, bolt_to[1] - 0.2), (bolt_to[0] + 0.8, bolt_to[1] - 2.2), 1.1, "s")
    fx, fy = bolt_from
    _segment(cells, across, (fx - 2.6, fy + 0.2), (fx - 0.2, fy - 2.6), 1.2, "a")
    if spec["stirrup"]:
        sx, sy = NOSE[0] + ux * 2.5, NOSE[1] + uy * 2.5
        previous = None
        for i in range(17):
            a = i / 16 * math.pi
            cx = sx + ux * 3.2 * math.sin(a) + px * 2.6 * math.cos(a)
            cy = sy + uy * 3.2 * math.sin(a) + py * 2.6 * math.cos(a)
            if previous is not None:
                _segment(cells, across, previous, (cx, cy), 0.7, "s")
            previous = (cx, cy)
    if spec["crank"]:
        cx, cy = _point(0.12)
        for dx, dy in ((-1, -1), (0, -1), (-1, 0), (0, 0), (1, 0), (0, 1)):
            cells[(int(cx) + dx, int(cy) + dy)] = "s"
            across[(int(cx) + dx, int(cy) + dy)] = 0.3
        _segment(cells, across, (cx, cy), (cx - 3.0, cy - 3.5), 0.8, "s")
        _segment(cells, across, (cx - 3.0, cy - 3.5), (cx - 5.0, cy - 2.2), 0.9, "T")
    if spec["gem"]:
        gx, gy = _point(0.7)
        for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
            cells[(int(gx - 1 + dx), int(gy - 1 + dy))] = "a"
            across[(int(gx - 1 + dx), int(gy - 1 + dy))] = 0.5
    cells = {c: l for c, l in cells.items() if 0 <= c[0] < SIZE and 0 <= c[1] < SIZE}
    ramps = _ramps(colors)
    pixels = [[None] * SIZE for _ in range(SIZE)]
    for (x, y), letter in cells.items():
        # Across each bar: the upper-left edge lit, the lower-right edge shaded; wood grain; a glint
        # along the lit edge of metal and of a glossy prod.
        side = across.get((x, y), 0.0)
        level = round(2.0 - side * 2.1)
        if letter in "tT" and B._hash(x, y, 9) % 5 == 0:
            level += 1
        if letter in "sym" and side > 0.75:
            pixels[y][x] = tuple(round(c + (255 - c) * 0.45) for c in ramps[letter][0]) + (255,)
            continue
        if any(cells.get((x + dx, y + dy)) not in (None, letter) for dx, dy in ((1, 0), (0, 1))) and letter != "a":
            level = 4
        pixels[y][x] = ramps[letter][max(0, min(4, level))] + (255,)
    for x, y in string:
        if 0 <= x < SIZE and 0 <= y < SIZE:
            pixels[y][x] = STRING + (255,)
    for (x, y) in list(cells):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if q not in cells and q not in string and 0 <= q[0] < SIZE and 0 <= q[1] < SIZE:
                pixels[q[1]][q[0]] = OUTLINE + (255,)
    return pixels
