"""Painted-style props: furniture, hanging signs, and herb patches, built from simple 3D solids
(boxes, cylinders, ellipsoids) and rendered with the painted shading of shading.py: the same
tilted camera and top-left light, five-tone ramps per material (warm lights, cool shadows),
textures (wood grain and plank seams, stone slabs, cloth), gloss on metal and glass, glowing
flames and lantern glass, a coloured edge round the silhouette, and dark seams where a nearer
part overlaps. make_sprites.py calls furniture(kind), sign(kind), wall_decor(kind), and herb(main, light,
accent, variant) and packs the frames into furniture.png, signs.png, wall_decor.png, and herbs.png.

World units are pixels: x to the right, y away from the viewer (north), z up; the floor is z 0.
"""

import math

import shading as C
import palette as pal
from shading import Material, ramp_material, emissive, add, sub, mul, dot, norm, basis, IDENT, _hash, _pattern

UP = C.UP
VIEW = C.VIEW
# Lit from the top-left and a little in front, so the faces turned to the viewer read (shading.py's
# light comes from behind; a counter's front would be in shadow).
LIGHT = norm((-0.5, -0.55, 0.7))
HALF = norm(sub(LIGHT, VIEW))
SHADOW = (0, 0, 0, 72)


# ---------------------------------------------------------------- materials

def wood(base, planks=0.0):
    """Wood with grain along the solid's long axis; `planks` (px) adds dark seams across it."""
    material = Material(base, "wood")
    material.planks = planks
    return material


def _pal(ramp, start, pattern="smooth", gloss=0.0, planks=0.0):
    """A material on five consecutive tones of a master-palette ramp (palette.py), from `start`."""
    tones = [ramp[min(len(ramp) - 1, start + i)] for i in range(5)]
    material = ramp_material(["%02x%02x%02x" % tuple(t[:3]) for t in tones], pattern, gloss)
    material.planks = planks
    return material


OAK = _pal(pal.OAK, 1, "wood", planks=5.0)
OAK_SOLID = _pal(pal.OAK, 1, "wood")
LIGHT_OAK = _pal(pal.OAK, 0, "wood")
DARK_WOOD = _pal(pal.DARK_WOOD, 0, "wood")
TIMBER = _pal(pal.OAK, 2, "wood")
IRON = _pal(pal.IRON, 2, gloss=0.7)
DARK_IRON = _pal(pal.IRON, 3, gloss=0.6)
BRASS = _pal(pal.GOLD, 1, gloss=0.9)
STONE = _pal(pal.ROCK, 1, "stone")
DARK_STONE = _pal(pal.ROCK, 2, "stone")
CLAY = _pal(pal.BRICK, 0)
LINEN = Material("e6dec8", "cloth")
WOOL_RED = Material("a83a2e", "cloth")
WOOL_BLUE = Material("3c5c9c", "cloth")
WOOL_GREEN = Material("4f7a34", "cloth")
CANDLE = Material("ece2c4")
LEAF = _pal(pal.FOLIAGE, 1, "leaf")
WATER = _pal(pal.WATER, 2, gloss=0.9)
GLASS_RED = Material("b83a30", gloss=1.0)
GLASS_BLUE = Material("3c62b0", gloss=1.0)
GLASS_GREEN = Material("4a9a3c", gloss=1.0)
GOLD = _pal(pal.GOLD, 0, gloss=0.9)
STEEL = _pal(pal.IRON, 0, gloss=1.0)
FLAME = emissive("ffb040")
FLAME_CORE = emissive("fff0a0")
EMBER = emissive("ff7a2a")
BREW = emissive("7ad04a")
LANTERN = emissive("ffb84a")
LANTERN_CORE = emissive("fff4c0")
AWNING_RED = Material("c8463a")
AWNING_WHITE = Material("eee4cc")
BOOKS = [Material(c) for c in ("7a3028", "2f4a74", "4f5e2c", "7a6430", "5a2a50")]
CASTLE_STONE = _pal(pal.ROCK, 0, "stone")
CASTLE_STONE_DARK = _pal(pal.ROCK, 1, "stone")
BUSH_LEAF = _pal(pal.FOLIAGE, 2, "leaf")
ROSE = Material("e88aa8")
BANNER_RED = Material("b02a22", "cloth")
FRUIT = [Material(c, gloss=0.5) for c in ("d84a2a", "e8b030", "6aa83a", "c83a3a")]


def _surface(material, u, n, p, axis):
    """Shade change and override colour for the props' own textures, else shading.py's."""
    if material.pattern == "wood":
        along = u[axis]
        across = u[(axis + 1) % 3] + u[(axis + 2) % 3] * 0.7
        grain = (_hash(round(across * 1.1), math.floor(along / 13.0)) % 7)
        change = -0.12 if grain == 0 else 0.07 if grain == 1 else 0.0
        if _hash(round(along / 3), round(across / 3)) % 61 == 0:
            change -= 0.22
        planks = getattr(material, "planks", 0.0)
        if planks and (across / planks) % 1.0 < 0.16:
            change -= 0.32
        return change, None
    if material.pattern == "ripple":
        # Rings spreading from the middle of the pool, broken up so they read as moving water.
        ring = (math.hypot(p[0], p[1]) / 3.2 + _hash(round(p[0] / 4), round(p[1] / 4)) % 3 * 0.15) % 1.0
        return (0.22 if ring < 0.12 else -0.08 if ring > 0.7 else 0.0), None
    if material.pattern == "leaf":
        return (0.12 if _hash(round(u[0] / 1.5), round(u[1] / 1.5), round(u[2] / 1.5)) % 5 == 0 else 0.0), None
    return _pattern(material, u, n, p)


# ---------------------------------------------------------------- solids

def box(center, half, material, rotation=IDENT, group=None, grain=None):
    """A box of half-extents `half` round `center`; its wood grain runs along `grain` (default:
    the longest side)."""
    if grain is None:
        grain = max(range(3), key=lambda i: half[i])
    return {"kind": "box", "c": center, "h": half, "R": rotation, "m": material, "g": group, "grain": grain}


def cyl(base, radius, height, material, axis=(0.0, 0.0, 1.0), group=None):
    """A cylinder standing on `base` (its bottom centre) along `axis`, grain along the axis."""
    return {"kind": "cyl", "c": base, "r": radius, "len": height, "R": basis(axis), "m": material, "g": group, "grain": 1}


def ell(center, radii, material, rotation=IDENT, group=None):
    return {"kind": "ell", "c": center, "r": radii, "R": rotation, "m": material, "g": group, "grain": 2}


def turn_z(angle):
    c, s = math.cos(angle), math.sin(angle)
    return ((c, s, 0.0), (-s, c, 0.0), (0.0, 0.0, 1.0))


def turn_x(angle):
    """A frame tilted about the x axis: positive lifts the far (y) side."""
    c, s = math.cos(angle), math.sin(angle)
    return ((1.0, 0.0, 0.0), (0.0, c, s), (0.0, -s, c))


def turn_y(angle):
    c, s = math.cos(angle), math.sin(angle)
    return ((c, 0.0, -s), (0.0, 1.0, 0.0), (s, 0.0, c))


def _local(rotation, v):
    return (dot(v, rotation[0]), dot(v, rotation[1]), dot(v, rotation[2]))


def _world(rotation, v):
    return add(add(mul(rotation[0], v[0]), mul(rotation[1], v[1])), mul(rotation[2], v[2]))


def _hit(part, origin, direction):
    """(distance, world normal, local point) where the ray first meets the solid, or None."""
    rotation = part["R"]
    o = _local(rotation, sub(origin, part["c"]))
    d = _local(rotation, direction)
    if part["kind"] == "box":
        near, far, face = -1e9, 1e9, 0
        for i in range(3):
            h = part["h"][i]
            if abs(d[i]) < 1e-9:
                if abs(o[i]) > h:
                    return None
                continue
            t0, t1 = (-h - o[i]) / d[i], (h - o[i]) / d[i]
            if t0 > t1:
                t0, t1 = t1, t0
            if t0 > near:
                near, face = t0, i
            far = min(far, t1)
            if near > far:
                return None
        q = add(o, mul(d, near))
        n = [0.0, 0.0, 0.0]
        n[face] = 1.0 if q[face] > 0 else -1.0
        return near, norm(_world(rotation, n)), q
    if part["kind"] == "cyl":
        r, length = part["r"], part["len"]
        best = None
        # Side: x^2 + z^2 = r^2 in the local frame, whose y axis is the cylinder's axis.
        a = d[0] * d[0] + d[2] * d[2]
        if a > 1e-9:
            b = 2 * (o[0] * d[0] + o[2] * d[2])
            disc = b * b - 4 * a * (o[0] * o[0] + o[2] * o[2] - r * r)
            if disc >= 0:
                t = (-b - math.sqrt(disc)) / (2 * a)
                q = add(o, mul(d, t))
                if 0.0 <= q[1] <= length:
                    best = (t, norm(_world(rotation, (q[0], 0.0, q[2]))), q)
        for cap, sign in ((0.0, -1.0), (length, 1.0)):
            if abs(d[1]) > 1e-9:
                t = (cap - o[1]) / d[1]
                q = add(o, mul(d, t))
                if q[0] * q[0] + q[2] * q[2] <= r * r and (best is None or t < best[0]):
                    best = (t, norm(_world(rotation, (0.0, sign, 0.0))), q)
        return best
    radii = part["r"]
    ol = (o[0] / radii[0], o[1] / radii[1], o[2] / radii[2])
    dl = (d[0] / radii[0], d[1] / radii[1], d[2] / radii[2])
    a = dot(dl, dl)
    b = 2 * dot(ol, dl)
    disc = b * b - 4 * a * (dot(ol, ol) - 1)
    if disc < 0:
        return None
    t = (-b - math.sqrt(disc)) / (2 * a)
    q = add(o, mul(d, t))
    n = _world(rotation, (q[0] / radii[0] ** 2, q[1] / radii[1] ** 2, q[2] / radii[2] ** 2))
    return t, norm(n), q


# ---------------------------------------------------------------- rendering

def render(parts, width, height, origin, shadow=None):
    """Rows of RGBA tuples or None: the parts seen from the game's camera, the world origin (floor
    centre) at frame pixel `origin`, with an optional floor shadow (rx, ry) under it."""
    gx, gy = origin
    hits = [[None] * width for _ in range(height)]
    for py in range(height):
        su = gy - (py + 0.5)
        for px in range(width):
            sx = px + 0.5 - gx
            start = (sx, su * UP[1] - 80 * VIEW[1], su * UP[2] - 80 * VIEW[2])
            for index, part in enumerate(parts):
                found = _hit(part, start, VIEW)
                if found is not None and (hits[py][px] is None or found[0] < hits[py][px][0]):
                    point = add(start, mul(VIEW, found[0]))
                    group = part["g"] if part["g"] is not None else index
                    hits[py][px] = (found[0], found[1], found[2], part, group, point)
    pixels = [[None] * width for _ in range(height)]
    for y in range(height):
        for x in range(width):
            hit = hits[y][x]
            if hit is None:
                continue
            _, n, q, part, _, p = hit
            material = part["m"]
            if material.pattern == "emissive":
                lit = 0.5 + 0.5 * max(0.0, -dot(n, VIEW))
                pixels[y][x] = C._shift(material.glow, 0.2 * lit - 0.06, 0.02, 0.0) + (255,)
                continue
            value = 0.34 + 0.7 * max(0.0, dot(n, LIGHT))
            value *= 0.84 + 0.16 * min(1.0, max(0.0, p[2] / 20.0))
            change, override = _surface(material, q, n, p, part["grain"])
            if override is not None:
                pixels[y][x] = override + (255,)
                continue
            value += change
            band = 0 if value > 0.86 else 1 if value > 0.66 else 2 if value > 0.46 else 3 if value > 0.3 else 4
            color = material.ramp[band]
            if material.gloss and max(0.0, dot(n, HALF)) ** 24 * material.gloss > 0.4:
                color = tuple(round(c + (255 - c) * 0.6) for c in material.ramp[0])
            pixels[y][x] = color + (255,)
    result = [row[:] for row in pixels]
    for y in range(height):
        for x in range(width):
            hit = hits[y][x]
            if hit is None or hit[3]["m"].pattern == "emissive":
                continue
            material, group = hit[3]["m"], hit[4]
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                other = hits[ny][nx] if 0 <= nx < width and 0 <= ny < height else None
                if other is None:
                    result[y][x] = material.edge + (255,)
                    break
                if other[4] != group and other[0] < hit[0] - 1.6:
                    result[y][x] = material.ramp[4] + (255,)
                    break
    if shadow:
        rx, ry = shadow
        for y in range(height):
            for x in range(width):
                if result[y][x] is None and ((x + 0.5 - gx) / rx) ** 2 + ((y + 0.5 - gy) / ry) ** 2 <= 1.0:
                    result[y][x] = SHADOW
    return result


# ---------------------------------------------------------------- furniture (32x48, on its tile)

FURNITURE_ORIGIN = (16, 36)


def _legs(points, height, material, radius=1.2):
    return [box((x, y, height / 2), (radius, radius, height / 2), material) for x, y in points]


def _bottle(x, y, z, glass, size=1.0):
    return [ell((x, y, z + 2.6 * size), (2.0 * size, 2.0 * size, 2.6 * size), glass),
            cyl((x, y, z + 4.6 * size), 0.8 * size, 2.2 * size, glass),
            cyl((x, y, z + 6.6 * size), 1.0 * size, 0.8 * size, LIGHT_OAK)]


def _counter(width=14.5):
    return [box((0, 1, 8.5), (width, 7, 8.5), OAK, grain=2),
            box((0, 1, 17.6), (width + 0.8, 7.8, 0.9), LIGHT_OAK, grain=0),
            box((0, -6.4, 1.0), (width + 0.4, 0.8, 1.0), DARK_WOOD)]


def _shelf(fill):
    parts = [box((0, 9, 18), (13, 0.8, 17), Material("3a2c20"), group=2),
             box((-13.5, 5, 18), (1.2, 5, 18), DARK_WOOD, grain=2, group=1),
             box((13.5, 5, 18), (1.2, 5, 18), DARK_WOOD, grain=2, group=1),
             box((0, 5, 35.4), (14.7, 5, 0.8), DARK_WOOD, grain=0, group=1)]
    for z in (1.5, 12.5, 23.5, 34.5):
        parts.append(box((0, 5, z), (12.4, 4.4, 0.8), LIGHT_OAK, grain=0))
    for row, z in enumerate((2.4, 13.4, 24.4)):
        for slot in range(5):
            x = -9.6 + slot * 4.8
            seed = _hash(slot, row, 7 if fill is _book_fill else 0)
            parts += fill(x, z, seed)
    return parts


def _potion_fill(x, z, seed):
    glass = (GLASS_RED, GLASS_BLUE, GLASS_GREEN, GLASS_RED)[seed % 4]
    return _bottle(x, 4.5, z, glass, 0.95)


def _book_fill(x, z, seed):
    height = 6.5 + seed % 3
    material = BOOKS[seed % len(BOOKS)]
    return [box((x - 1.1, 5.0, z + height / 2), (1.0, 3.2, height / 2), material),
            box((x + 1.1, 5.0, z + (height - 1) / 2), (1.0, 3.2, (height - 1) / 2), BOOKS[(seed + 2) % len(BOOKS)])]


def _sword(x, y, z, length, lean=0.0):
    tilt = turn_y(lean)
    up = _world(tilt, (0, 0, 1))
    at = lambda h: add((x, y, z), mul(up, h))
    return [box(at(3), (0.9, 0.9, 3), DARK_WOOD, tilt), box(at(6.3), (3.2, 1.0, 0.7), BRASS, tilt),
            box(at(6.8 + length / 2), (1.1, 0.5, length / 2), STEEL, tilt)]


def _turned(parts, angle):
    """The parts turned about the upright axis through the floor centre."""
    c, s = math.cos(angle), math.sin(angle)
    turn = lambda v: (v[0] * c - v[1] * s, v[0] * s + v[1] * c, v[2])
    return [dict(part, c=turn(part["c"]), R=tuple(turn(axis) for axis in part["R"])) for part in parts]


def furniture(kind):
    """One 32x48 furniture frame (rows of RGBA or None), its tile the bottom 32 rows. A kind ending
    in "_back" is the piece seen from behind (a market row facing north, a bench facing a
    fountain from the south)."""
    if kind.endswith("_back"):
        front = kind[:-len("_back")]
        return _render_piece(front, math.pi)
    return _render_piece(kind, 0.0)


def _render_piece(kind, angle):
    parts = []
    shadow = (13, 6)
    if kind == "counter_shop":
        parts = _counter()
        parts += _bottle(-9, 0, 18.5, GLASS_RED) + _bottle(-4, 1.5, 18.5, GLASS_BLUE) + _bottle(1, 0, 18.5, GLASS_RED)
        parts += [box((8, 0, 19.0), (4.5, 3.0, 0.5), LINEN, turn_z(0.2)), cyl((5, -1.5, 19.0), 0.9, 6.5, LINEN, (1, 0.2, 0))]
    elif kind == "counter_bank":
        parts = _counter()
        for x, y, h in ((-10, 0, 3.5), (-6.5, 2, 2.4), (-8, -2.5, 1.6)):
            parts.append(cyl((x, y, 18.5), 2.2, h, GOLD))
        parts += [cyl((6, 2, 18.5), 0.8, 10, IRON), box((6, 2, 28.5), (6, 0.7, 0.6), IRON),
                  cyl((1, 2, 23), 2.6, 0.7, BRASS), cyl((11, 2, 23), 2.6, 0.7, BRASS),
                  box((1, 2, 25.8), (0.3, 0.3, 2.6), IRON), box((11, 2, 25.8), (0.3, 0.3, 2.6), IRON)]
    elif kind == "shelf_potions":
        parts = _shelf(_potion_fill)
        shadow = (14, 5)
    elif kind == "shelf_books":
        parts = _shelf(_book_fill)
        shadow = (14, 5)
    elif kind == "weapon_rack":
        parts = [box((0, 3, 2), (13, 4, 2), DARK_WOOD), box((-11.5, 3, 14), (1.4, 1.4, 14), TIMBER),
                 box((11.5, 3, 14), (1.4, 1.4, 14), TIMBER), box((0, 3, 21), (13, 1.2, 1.2), LIGHT_OAK)]
        parts += _sword(-6, 2, 4, 18, -0.08) + _sword(0, 2, 4, 21) + _sword(6, 2, 4, 18, 0.08)
    elif kind == "barrel":
        parts = [cyl((0, 0, 0), 9.5, 23, _pal(pal.OAK, 1, "wood", planks=3.4), group=1),
                 cyl((0, 0, 23), 8.6, 0.6, LIGHT_OAK, group=1)]
        for z in (3.5, 17.5):
            parts.append(cyl((0, 0, z), 9.9, 1.6, IRON, group=1))
        shadow = (11, 5)
    elif kind == "crate":
        parts = [box((0, 0, 10.5), (11, 9.5, 10.5), OAK, grain=0, group=1)]
        parts += [box((0, -9.7, 10.5), (12.5, 0.6, 1.4), LIGHT_OAK, turn_y(0.72), group=1),
                  box((-10.6, -9.7, 10.5), (0.9, 0.7, 10.5), LIGHT_OAK, group=1),
                  box((10.6, -9.7, 10.5), (0.9, 0.7, 10.5), LIGHT_OAK, group=1)]
        parts += _sword(-3, 1, 15, 12, -0.25) + [cyl((5, 2, 18), 0.9, 9, DARK_WOOD), box((5, 2, 27), (3, 1.4, 1.4), IRON)]
    elif kind == "strongbox":
        dark = _pal(pal.DARK_WOOD, 1, "wood")
        parts = [box((0, 0, 8), (11, 8, 8), dark, group=1), box((0, 0, 16.6), (11.6, 8.6, 0.8), dark, group=1)]
        for x in (-8, 8):
            parts.append(box((x, 0, 8.6), (1.0, 8.4, 8.6), DARK_IRON, group=1))
        parts += [box((0, -8.2, 11), (2.6, 0.6, 2.6), BRASS), box((0, -8.6, 10.6), (0.5, 0.3, 1.0), Material("1a1614"))]
        shadow = (12, 5)
    elif kind == "anvil":
        parts = [cyl((0, 1, 0), 7, 11, TIMBER, group=1), box((0, 1, 13), (4, 3.5, 2), DARK_IRON, group=2),
                 box((1, 1, 16.5), (8, 4.2, 1.8), IRON, group=2),
                 ell((-9.5, 1, 16.4), (5, 2.6, 1.6), IRON, group=2),
                 cyl((4, -3, 18.6), 0.8, 9, DARK_WOOD, (0.9, -0.2, 0.35)), box((12, -4.6, 21.8), (1.8, 1.8, 2.4), DARK_IRON)]
    elif kind == "workbench":
        parts = [box((0, 1, 16), (14.5, 7, 1.6), LIGHT_OAK, grain=0, group=1)]
        parts += _legs(((-12.5, -4.5), (12.5, -4.5), (-12.5, 6.5), (12.5, 6.5)), 14.5, TIMBER, 1.4)
        parts += [box((0, 1, 4), (12.5, 0.8, 0.8), TIMBER),
                  box((-6, -1, 18.1), (6, 2.6, 0.4), STEEL, turn_z(0.1)), box((1.5, -1.2, 18.6), (1.8, 1.4, 0.9), DARK_WOOD),
                  cyl((8, 1, 17.6), 2.0, 5, OAK_SOLID, (1, 0, 0)), box((10, 4, 19), (3, 1.2, 1.2), LIGHT_OAK, turn_z(0.6))]
    elif kind == "cauldron":
        parts = [ell((0, 0, 11), (11, 11, 9), DARK_IRON, group=1), ell((0, 0, 17.4), (11.6, 11.6, 1.6), IRON, group=1),
                 ell((0, 0, 18.1), (9.6, 9.6, 1.4), BREW, group=2),
                 ell((-3, -2, 19.2), (1.3, 1.3, 0.8), emissive("c8ff90")), ell((3.5, 1.5, 19.1), (1.0, 1.0, 0.7), emissive("c8ff90"))]
        for x in (-7, 7):
            parts.append(box((x, -4, 2), (1.2, 1.2, 2.5), DARK_IRON))
        for x in (-4, 0, 4):
            parts.append(ell((x, -7, 0.8), (2.2, 1.6, 1.0), EMBER))
    elif kind == "loom":
        parts = [box((-12.5, 2, 17), (1.4, 1.4, 17), TIMBER), box((12.5, 2, 17), (1.4, 1.4, 17), TIMBER),
                 box((0, 2, 31.5), (13.5, 1.8, 1.4), LIGHT_OAK), box((0, 2, 8), (13.5, 1.8, 1.4), LIGHT_OAK)]
        for x in range(-10, 11, 2):
            parts.append(box((x, 1.6, 22), (0.35, 0.3, 9), LINEN))
        stripes = (WOOL_RED, LINEN, WOOL_BLUE, LINEN)
        for index in range(5):
            parts.append(box((0, 1.0, 10.4 + index * 2.2), (10.8, 0.5, 1.1), stripes[index % 4]))
        parts += [box((0, -4, 3), (8, 3, 1), DARK_WOOD), box((-6, -4, 1), (1, 1, 1), DARK_WOOD), box((6, -4, 1), (1, 1, 1), DARK_WOOD)]
        shadow = (14, 5)
    elif kind == "hearth":
        for angle in range(0, 360, 45):
            a = math.radians(angle)
            parts.append(ell((9 * math.cos(a), 6 * math.sin(a), 1.6), (3.4, 2.8, 2.2), STONE))
        parts += [ell((-2, 0, 3), (2.4, 2.4, 4), FLAME), ell((2, 1, 2.6), (2.2, 2.2, 3.4), FLAME),
                  ell((0, -1, 2.6), (1.4, 1.4, 2.6), FLAME_CORE), ell((0, 0, 0.6), (5, 3.4, 0.8), EMBER)]
        for x, y in ((-11, -5), (11, -5), (0, 8)):
            parts.append(cyl((x, y, 0), 0.7, 26, DARK_WOOD, norm(sub((0, 0, 24), (x, y, 0)))))
        parts += [ell((0, 0, 13), (4.5, 4.5, 3.6), DARK_IRON), cyl((0, 0, 16), 0.3, 8, IRON)]
    elif kind == "bed":
        parts = [box((0, 8.5, 12), (12.5, 1.6, 12), DARK_WOOD, grain=0, group=1),
                 box((0, -1, 4.5), (12.5, 9.5, 4.5), OAK_SOLID, grain=1, group=2),
                 box((0, -0.5, 10.4), (11.5, 9, 1.6), LINEN, group=3),
                 ell((0, 5, 13), (7.5, 3, 2.2), Material("f4f0e4"), group=3),
                 box((0, -3.5, 10.9), (11.8, 6.6, 1.5), WOOL_RED, group=4),
                 box((0, -10.4, 4.5), (12.5, 0.9, 4.5), DARK_WOOD, grain=0, group=2)]
        shadow = (14, 7)
    elif kind == "table":
        parts = [box((0, 0, 15), (13, 8, 1.2), OAK, grain=0, group=1)]
        parts += _legs(((-11, -6), (11, -6), (-11, 6), (11, 6)), 14, TIMBER)
        parts += [cyl((-7, 1, 16.2), 1.3, 6, CANDLE), ell((-7, 1, 23.4), (0.9, 0.9, 1.6), FLAME_CORE),
                  ell((3, 0, 17.4), (4, 3.4, 1.6), Material("8a6a44")), cyl((9, 2, 16.2), 1.8, 3.6, Material("7a8a94", gloss=0.6))]
    elif kind == "chair":
        parts = [box((0, 0, 11), (7, 6.5, 1.0), LIGHT_OAK, grain=0, group=1)]
        parts += _legs(((-5.8, -5.2), (5.8, -5.2)), 10, TIMBER)
        parts += [box((-5.8, 5.2, 14), (1.1, 1.1, 14), TIMBER), box((5.8, 5.2, 14), (1.1, 1.1, 14), TIMBER),
                  box((0, 5.2, 21), (5.5, 0.7, 1.0), LIGHT_OAK), box((0, 5.2, 26), (5.5, 0.7, 1.2), LIGHT_OAK)]
        shadow = (9, 5)
    elif kind == "plant":
        parts = [cyl((0, 0, 0), 6.2, 9, CLAY, group=1), cyl((0, 0, 8.4), 7.2, 1.8, Material("c8784a"), group=1),
                 ell((0, 0, 10), (5.6, 5.6, 0.6), Material("4a3424"))]
        for x, y, z, r in ((0, 0, 17, 6), (-5, -1, 14, 4.2), (5, 1, 14.5, 4.2), (-3, 2, 21, 4), (3, -2, 22, 4.2),
                           (0, 1, 26, 3.6), (-6, 3, 19, 3.2), (6, -1, 19, 3.2)):
            parts.append(ell((x, y, z), (r, r * 0.9, r * 0.8), LEAF, turn_z(x * 0.1), group=2))
        shadow = (8, 4)
    elif kind == "chest":
        parts = [box((0, 0, 6.5), (11.5, 7.5, 6.5), OAK, grain=0, group=1),
                 cyl((-11.5, 0, 12.5), 7.5, 23, LIGHT_OAK, (1, 0, 0), group=1)]
        for x in (-7, 7):
            parts += [box((x, 0, 6.6), (1.1, 7.7, 6.6), IRON, group=1), cyl((x - 1.1, 0, 12.5), 7.7, 2.2, IRON, (1, 0, 0), group=1)]
        parts += [box((0, -7.8, 10.5), (2.2, 0.6, 2.4), BRASS), box((0, -8.3, 10), (0.5, 0.3, 0.9), Material("1a1614"))]
        shadow = (12, 6)
    elif kind == "lamp_post":
        parts = [box((0, 0, 2), (5, 5, 2), DARK_STONE, group=1), box((0, 0, 4.6), (3.4, 3.4, 0.9), STONE, group=1),
                 cyl((0, 0, 5), 1.6, 25, DARK_IRON, group=2), box((0, 0, 30.6), (5.4, 5.4, 0.7), DARK_IRON, group=3),
                 box((0, 0, 35), (4.2, 4.2, 4.0), LANTERN, group=3), box((0, -2.4, 35), (2.0, 2.0, 2.4), LANTERN_CORE, group=3)]
        for x in (-4.4, 4.4):
            for y in (-4.4, 4.4):
                parts.append(box((x, y, 35), (0.6, 0.6, 4.2), DARK_IRON, group=3))
        parts += [ell((0, 0, 39.6), (6, 6, 1.8), DARK_IRON, group=3), ell((0, 0, 42), (1.2, 1.2, 1.4), IRON, group=3)]
        shadow = (6, 3)
    elif kind == "well":
        parts = [cyl((0, 0, 0), 11.5, 9, STONE, group=1), cyl((0, 0, 9), 12.2, 1.4, DARK_STONE, group=1),
                 cyl((0, 0, 9.2), 9.4, 1.4, WATER, group=2)]
        for x in (-10.5, 10.5):
            parts.append(box((x, 0, 17), (1.3, 1.3, 9), TIMBER, group=3))
        roof = wood("7a4e30", 3.0)
        parts += [box((0, -3.6, 27.5), (13.5, 4.8, 0.8), roof, turn_x(0.6), group=4, grain=1),
                  box((0, 3.6, 27.5), (13.5, 4.8, 0.8), roof, turn_x(-0.6), group=4, grain=1),
                  box((0, 0, 30.2), (13.5, 0.9, 0.9), DARK_WOOD, group=4),
                  cyl((-10.5, 0, 22), 1.4, 21, LIGHT_OAK, (1, 0, 0), group=3), cyl((0, 0, 12), 0.35, 10, LINEN),
                  cyl((0, 0, 9.8), 2.2, 3.2, OAK_SOLID), cyl((0, 0, 12.6), 2.4, 0.5, IRON)]
        shadow = (14, 7)
    elif kind == "bench":
        parts = [box((0, 0, 9), (14, 4.6, 1.2), LIGHT_OAK, grain=0, group=1),
                 box((0, 3.6, 14.5), (14, 0.9, 2.2), OAK_SOLID, grain=0, group=1)]
        for x in (-10.5, 10.5):
            parts += [box((x, 0, 4), (2.2, 4.2, 4), STONE), box((x, 3.6, 11.5), (0.8, 0.8, 3), DARK_WOOD)]
        shadow = (15, 5)
    elif kind == "stall":
        parts = _counter(13.5)
        for x in (-13.5, 13.5):
            for y in (-6.5, 7.5):
                parts.append(cyl((x, y, 0), 0.9, 34 if y > 0 else 30, TIMBER, group=5))
        for index in range(8):
            x = -14 + index * 3.6 + 1.8
            cloth = AWNING_RED if index % 2 == 0 else AWNING_WHITE
            parts.append(box((x, 0.5, 32), (1.85, 8.6, 0.5), cloth, turn_x(0.24), group=6))
        parts.append(box((0, -8.4, 30.4), (14.6, 0.5, 1.6), AWNING_RED, group=6))
        for index, x in enumerate((-9, -5, -1, 3)):
            parts.append(ell((x, -1 + (index % 2) * 2, 20), (2.0, 2.0, 2.0), FRUIT[index]))
        parts += [cyl((6, 1, 18.5), 2.4, 9, WOOL_BLUE, (1, 0, 0)), ell((-3, 3, 20.4), (2.2, 2.2, 2.0), FRUIT[1])]
        shadow = (15, 7)
    elif kind == "pillar":
        # A square column of dressed sandstone on a plinth, with a capital.
        parts = [box((0, 0, 2), (8.5, 8.5, 2), CASTLE_STONE_DARK, group=1), box((0, 0, 5), (7.2, 7.2, 1.2), CASTLE_STONE, group=1),
                 box((0, 0, 22), (6, 6, 16), CASTLE_STONE, group=2), box((0, 0, 39), (7.4, 7.4, 1.4), CASTLE_STONE, group=3),
                 box((0, 0, 41.6), (8.4, 8.4, 1.3), CASTLE_STONE_DARK, group=3)]
        shadow = None
    elif kind == "knight_statue":
        # A suit of armour on a plinth, a spear upright in its right hand.
        ARMOUR = Material("8a929a", gloss=0.8)
        parts = [box((0, 0, 2.5), (7.5, 6.5, 2.5), CASTLE_STONE_DARK, group=1),
                 box((-2.4, 0, 9.5), (1.9, 1.9, 4.5), ARMOUR, group=2), box((2.4, 0, 9.5), (1.9, 1.9, 4.5), ARMOUR, group=2),
                 box((0, 0, 17), (4.6, 3.0, 4.2), ARMOUR, group=2), ell((0, 0, 21.4), (5.6, 3.6, 2.2), ARMOUR, group=2),
                 ell((-5.6, 0, 20.4), (2.0, 2.0, 2.0), ARMOUR, group=2), ell((5.6, 0, 20.4), (2.0, 2.0, 2.0), ARMOUR, group=2),
                 box((-6.0, -0.5, 15.5), (1.3, 1.3, 4), ARMOUR, group=2), box((6.0, -0.5, 15.5), (1.3, 1.3, 4), ARMOUR, group=2),
                 ell((0, 0, 26.5), (3.0, 3.2, 3.6), ARMOUR, group=3), box((0, -2.9, 26.6), (2.0, 0.3, 0.5), Material("1e2024"), group=3),
                 box((0, 0.5, 30.6), (0.7, 2.6, 1.2), WOOL_RED, group=3),
                 cyl((7.4, -1.2, 5), 0.6, 33, DARK_WOOD), ell((7.4, -1.2, 39), (1.2, 1.2, 2.6), ARMOUR),
                 box((-6.6, -1.6, 13.5), (2.4, 0.8, 4.8), WOOL_RED, group=4), box((-6.6, -2.5, 13.5), (0.6, 0.2, 2.6), GOLD)]
        shadow = (9, 5)
    elif kind == "gargoyle":
        # A crouching dark stone gargoyle on a plinth, wings folded, horns and glowing eyes.
        dark = Material("4a4a4e", "stone")
        parts = [box((0, 0, 3), (8.5, 8, 3), CASTLE_STONE, group=1), box((0, 0, 6.6), (9.2, 8.6, 0.8), CASTLE_STONE_DARK, group=1),
                 ell((0, 1, 13), (5.2, 4.6, 6), dark, group=2), ell((-3.2, -2.6, 9), (1.8, 2.6, 2.2), dark, group=2),
                 ell((3.2, -2.6, 9), (1.8, 2.6, 2.2), dark, group=2), ell((0, -2.2, 21), (3.6, 3.2, 3.2), dark, group=3),
                 ell((-5.8, 2.4, 17), (2.2, 3.4, 6), dark, turn_y(0.4), group=4), ell((5.8, 2.4, 17), (2.2, 3.4, 6), dark, turn_y(-0.4), group=4),
                 cyl((-2.0, -2.2, 23), 0.6, 3.2, dark, norm((-0.4, 0, 1))), cyl((2.0, -2.2, 23), 0.6, 3.2, dark, norm((0.4, 0, 1))),
                 ell((-1.3, -5.0, 21.4), (0.5, 0.3, 0.4), emissive("c84a2a")), ell((1.3, -5.0, 21.4), (0.5, 0.3, 0.4), emissive("c84a2a"))]
        shadow = (10, 5)
    elif kind == "bush":
        parts = [ell((x, y, z), (r, r * 0.9, r * 0.8), BUSH_LEAF, turn_z(x * 0.2), group=1)
                 for x, y, z, r in ((0, 0, 7, 8), (-6, 2, 6, 5.4), (6, 1, 6, 5.6), (-2, -3, 11, 5), (3, -2, 12, 4.6),
                                    (0, 2, 13, 4.4))]
        shadow = (10, 4)
    elif kind == "flower_vase":
        vase = Material("c8c0b4", gloss=0.6)
        parts = [cyl((0, 0, 0), 3.2, 1.0, Material("8a7a68"), group=1), ell((0, 0, 5), (4.0, 4.0, 4.4), vase, group=1),
                 cyl((0, 0, 8.5), 2.0, 3.0, vase, group=1), cyl((0, 0, 11), 2.8, 0.8, Material("b0a89c"), group=1)]
        for x, y, z in ((0, 0, 17), (-3, 1, 15), (3, -1, 15.4), (-1.5, -2, 19), (2, 2, 19)):
            parts += [cyl((x * 0.4, y * 0.4, 11), 0.35, z - 12, LEAF, norm((x, y, 8))), ell((x, y, z), (1.9, 1.9, 1.7), ROSE)]
        parts += [ell((-4, 0, 12.4), (2.2, 1.2, 0.8), LEAF), ell((4, 1, 13), (2.2, 1.2, 0.8), LEAF)]
        shadow = (6, 3)
    elif kind == "potted_palm":
        parts = [cyl((0, 0, 0), 5.2, 8, CLAY, group=1), cyl((0, 0, 7.6), 6.0, 1.6, Material("c8784a"), group=1),
                 cyl((0, 0, 8), 0.9, 12, DARK_WOOD, group=2)]
        for angle_deg in range(0, 360, 60):
            a = math.radians(angle_deg)
            parts.append(ell((math.cos(a) * 5.5, math.sin(a) * 4, 19 - abs(math.sin(a)) * 2), (6.5, 1.6, 0.8), LEAF,
                             turn_z(a), group=3))
        shadow = (7, 3)
    elif kind == "candelabra":
        # A small table with a three-armed golden candelabra.
        parts = [box((0, 0, 13), (9.5, 7, 1.1), OAK, grain=0, group=1)]
        parts += _legs(((-8, -5), (8, -5), (-8, 5), (8, 5)), 12, TIMBER)
        parts += [cyl((0, 0, 14), 2.4, 0.8, GOLD), cyl((0, 0, 14.6), 0.6, 9, GOLD), box((0, 0, 21), (5.6, 0.5, 0.5), GOLD)]
        for x in (-5.4, 0, 5.4):
            lift = 1.2 if x == 0 else 0.0
            parts += [cyl((x, 0, 21.4 + lift), 0.9, 4, CANDLE), ell((x, 0, 26.6 + lift), (0.8, 0.8, 1.4), FLAME_CORE)]
        shadow = (11, 6)
    elif kind == "fruit_table":
        parts = [box((0, 0, 13), (9.5, 7, 1.1), OAK, grain=0, group=1)]
        parts += _legs(((-8, -5), (8, -5), (-8, 5), (8, 5)), 12, TIMBER)
        parts += [ell((0, 0, 15.2), (6.4, 5, 1.6), Material("c8b090", gloss=0.4))]
        for index, (x, y, z) in enumerate(((-3, -1, 17), (0, 1.5, 17), (3, -1, 17), (-1.5, -2, 19), (1.5, 0, 19.6), (0, -0.5, 21.5))):
            parts.append(ell((x, y, z), (2.0, 2.0, 1.9), FRUIT[index % len(FRUIT)]))
        shadow = (11, 6)
    elif kind == "stove":
        parts = [box((0, 1, 9), (9, 7, 9), DARK_IRON, group=1), box((0, 1, 18.6), (9.6, 7.6, 0.8), IRON, group=1),
                 box((0, -6.2, 7), (5, 0.4, 3.6), EMBER, group=2), box((0, -6.4, 7), (3, 0.3, 2.0), FLAME_CORE, group=2),
                 cyl((4, 4, 19), 1.6, 18, DARK_IRON, group=3), cyl((-3, 0, 19.2), 3.4, 2.2, IRON, group=4)]
        shadow = (11, 6)
    elif kind == "throne":
        parts = [box((0, 0, 1.5), (11, 9, 1.5), CASTLE_STONE_DARK, group=1),
                 box((0, 0, 8.5), (8, 6.5, 5.5), GOLD, group=2), box((0, -0.5, 14.6), (7.4, 6, 1.0), WOOL_RED, group=3),
                 box((0, 5.6, 22), (8, 1.4, 13), GOLD, group=4), box((0, 4.2, 22), (6.2, 0.4, 10.4), WOOL_RED, group=5),
                 box((-7.6, -0.5, 17), (1.0, 6, 2.6), GOLD, group=6), box((7.6, -0.5, 17), (1.0, 6, 2.6), GOLD, group=6),
                 ell((0, 5.6, 36), (3, 1.2, 2.4), GOLD, group=4), ell((-6.5, 5.6, 35), (1.4, 1.2, 1.6), GOLD, group=4),
                 ell((6.5, 5.6, 35), (1.4, 1.2, 1.6), GOLD, group=4), ell((0, 4.2, 36.2), (1.0, 0.6, 1.0), GLASS_RED)]
        shadow = (12, 7)
    else:
        raise ValueError(kind)
    return render(_turned(parts, angle) if angle else parts, 32, 48, FURNITURE_ORIGIN, shadow)


# ---------------------------------------------------------------- wall decorations (32x32, on a wall face)

WALL_DECOR_KINDS = ["banner", "wall_torch", "painting"]


def wall_decor(kind):
    """Something hung on the visible face of a wall (SpriteArt.draw_wall_decor), leaned with the
    wall like a sign: a red banner with a gold crown on a rod, a torch in an iron bracket with a
    real flame, or a painting of hills in a gilded frame."""
    face = -1.0
    if kind == "banner":
        parts = [cyl((-8, 0, 17.5), 0.7, 16, BRASS, (1, 0, 0), group=1), ell((-8.6, 0, 17.5), (0.9, 0.9, 0.9), GOLD, group=1),
                 ell((8.6, 0, 17.5), (0.9, 0.9, 0.9), GOLD, group=1),
                 box((0, 0.4, 8.5), (6.5, 0.5, 8.5), BANNER_RED, grain=2, group=2)]
        for x in (-4.5, 0, 4.5):
            parts.append(box((x, 0.4, -0.6), (1.6, 0.5, 1.4), BANNER_RED, turn_y(0.785), group=2))
        parts += [box((0, face, 10.5), (3.6, 0.3, 1.2), GOLD), box((-2.7, face, 12.4), (0.6, 0.3, 1.2), GOLD),
                  box((0, face, 12.8), (0.6, 0.3, 1.6), GOLD), box((2.7, face, 12.4), (0.6, 0.3, 1.2), GOLD),
                  box((0, face, 6.0), (5.4, 0.3, 0.4), GOLD)]
        return render(_lean(parts, math.radians(40)), 32, 32, (16, 28))
    if kind == "wall_torch":
        parts = [box((0, 0.6, 7), (2.4, 0.6, 3.6), DARK_IRON, group=1), box((0, -2.4, 10.6), (1.4, 3.4, 0.9), DARK_IRON, group=1),
                 cyl((0, -5.0, 6), 1.5, 12, DARK_WOOD, norm((0, -0.3, 1)), group=2), cyl((0, -6.2, 16), 2.0, 2.0, DARK_IRON),
                 ell((0, -6.6, 21), (2.8, 2.8, 4.2), FLAME), ell((0, -7.0, 21.8), (1.5, 1.5, 2.4), FLAME_CORE)]
        return render(_lean(parts, math.radians(40)), 32, 32, (16, 26))
    if kind == "painting":
        sky, hill, meadow = Material("7aa6c8"), Material("5c8a44"), Material("8aa850")
        parts = [box((0, 0.4, 11), (11, 0.5, 8.5), GOLD, group=1), box((0, face, 12.4), (9.4, 0.3, 6.4), sky, group=2),
                 ell((-3, face - 0.1, 7.6), (7.5, 0.3, 3.8), hill, group=3), ell((5, face - 0.15, 6.6), (6, 0.3, 3.0), meadow, group=3),
                 ell((-5, face - 0.2, 15.6), (1.6, 0.3, 1.6), Material("f4e8a0"), group=4)]
        return render(_lean(parts, math.radians(40)), 32, 32, (16, 26))
    raise ValueError(kind)


# ---------------------------------------------------------------- the fountain (96x112, 3x3 tiles)

FOUNTAIN_SIZE = (96, 112)
## The basin's centre in the frame: the middle of the 3x3 tiles, whose bottom row is frame rows 80-111.
FOUNTAIN_ORIGIN = (48, 64)  # the frame keeps 48 rows above it for the tiers
FOUNTAIN_FRAMES = 4
SPRAY = Material("cfeaf4", gloss=1.0)
FOUNTAIN_STONE = Material("a49a88", "stone")
FOUNTAIN_DARK = Material("857c6c", "stone")
POOL = ramp_material(["7aa6b8", "52809a", "3a6680", "2a5068", "1e3c52"], "ripple", gloss=0.9)


def _ring(radius, thickness, height, material, segments=36, z=0.0):
    """A round wall of stone blocks: a basin's rim."""
    parts = []
    arc = math.pi * radius / segments + 0.5
    for index in range(segments):
        angle = 2 * math.pi * index / segments
        centre = (radius * math.cos(angle), radius * math.sin(angle), z + height / 2)
        parts.append(box(centre, (thickness / 2, arc, height / 2), material, turn_z(angle), group=1, grain=1))
    return parts


def fountain(frame):
    """A three-tier stone fountain in a round basin, its water falling from bowl to bowl; frame
    0-3 moves the falling drops down a step at a time."""
    parts = _ring(42, 5, 10, FOUNTAIN_STONE)
    parts += _ring(44.6, 1.6, 2.0, FOUNTAIN_DARK, 40, 10.0)
    parts += [cyl((0, 0, 0), 40, 7.5, POOL, group=2),
              box((0, 0, 9), (9, 9, 2.2), FOUNTAIN_DARK, group=3), cyl((0, 0, 9), 6.5, 16, FOUNTAIN_STONE, group=3),
              ell((0, 0, 25), (6.5, 6.5, 3), FOUNTAIN_DARK, group=3),
              ell((0, 0, 30), (21, 21, 7), FOUNTAIN_STONE, group=4), ell((0, 0, 35.4), (16.5, 16.5, 1.6), POOL, group=5),
              cyl((0, 0, 35), 3.6, 10, FOUNTAIN_STONE, group=6), ell((0, 0, 45), (4.5, 4.5, 2.2), FOUNTAIN_DARK, group=6),
              ell((0, 0, 49), (11, 11, 4.6), FOUNTAIN_STONE, group=6),
              ell((0, 0, 52.2), (8.4, 8.4, 1.2), POOL, group=7), ell((0, 0, 57), (3.2, 3.2, 5), FOUNTAIN_DARK, group=8),
              ell((0, 0, 62.4), (1.4, 1.4, 1.6), FOUNTAIN_STONE, group=8), cyl((0, 0, 63), 0.6, 4, SPRAY, group=9)]
    # Falling water: drops in rings round each bowl's lip, a step lower each frame.
    for lip, top, bottom, count in ((11.5, 51.0, 36.0, 10), (21.5, 32.0, 7.5, 14)):
        for index in range(count):
            angle = 2 * math.pi * (index + 0.5 * (index % 2)) / count
            for step in range(3):
                fall = ((step + frame / FOUNTAIN_FRAMES) / 3.0) % 1.0
                z = top - (top - bottom) * fall
                out = lip + 2.5 * fall
                parts.append(ell((out * math.cos(angle), out * math.sin(angle), z), (0.7, 0.7, 1.5), SPRAY, group=10))
    for index in range(6):
        angle = 2 * math.pi * index / 6 + frame
        parts.append(ell((3 * math.cos(angle), 3 * math.sin(angle), 65 - 2 * ((index + frame) % 3)), (0.6, 0.6, 1.0), SPRAY))
    return render(parts, FOUNTAIN_SIZE[0], FOUNTAIN_SIZE[1], FOUNTAIN_ORIGIN, (47, 30))


# ---------------------------------------------------------------- hanging signs (32x32)

def _lean(parts, angle):
    """The parts tipped back about the x axis by `angle`, so an upright face turns to the camera."""
    c, s = math.cos(angle), math.sin(angle)
    turn = lambda v: (v[0], v[1] * c + v[2] * s, -v[1] * s + v[2] * c)
    return [dict(part, c=turn(part["c"]), R=tuple(turn(axis) for axis in part["R"])) for part in parts]


def sign(kind):
    """A painted wooden sign hanging from an iron bracket, its face turned to the viewer, with the
    service's emblem on it: a potion and a sword (vendor), a heap of coins (banker), a hammer and
    a green flask (artisan), two crossed swords (warden)."""
    board = wood("8e6238", 4.4)
    parts = [box((-1, 0, 16.4), (13, 0.7, 0.7), DARK_IRON, group=1), box((-13.5, 0, 12), (0.7, 0.7, 5), DARK_IRON, group=1),
             box((-6, 0, 15), (0.35, 0.35, 1.4), DARK_IRON), box((8, 0, 15), (0.35, 0.35, 1.4), DARK_IRON),
             box((1, 0.6, 7.5), (11.5, 0.9, 6.5), board, grain=0, group=2),
             box((1, -0.4, 7.5), (10.2, 0.2, 5.3), wood("6a4428"), grain=0, group=3)]
    face = -1.4
    if kind == "vendor":
        parts += [ell((-3.5, face, 5.6), (3.0, 1.0, 3.0), GLASS_RED), box((-3.5, face, 9.6), (1.0, 0.7, 1.6), GLASS_RED),
                  box((-3.5, face, 11.6), (1.3, 0.7, 0.6), LIGHT_OAK),
                  box((5.5, face, 8.6), (0.9, 0.5, 4.2), STEEL), box((5.5, face, 4.2), (3.0, 0.6, 0.7), BRASS),
                  box((5.5, face, 2.6), (0.7, 0.6, 1.1), DARK_WOOD)]
    elif kind == "banker":
        for x, z in ((-5, 4.2), (0.5, 4.2), (6, 4.2), (-2.2, 9.2), (3.2, 9.2)):
            parts += [cyl((x, face + 0.9, z), 2.5, 0.6, Material("8a6418")), cyl((x, face + 0.3, z), 1.9, 0.6, GOLD, (0, -1, 0))]
    elif kind == "warden":
        # Narrow blades in a blued steel so the two read apart on the small board.
        blade = Material("a2aab2", gloss=0.9)
        for tilt, depth in ((0.75, face), (-0.75, face - 0.5)):
            axis = (math.sin(tilt), 0.0, math.cos(tilt))
            at = lambda along, axis=axis, depth=depth: (1 + axis[0] * along, depth, 6.5 + axis[2] * along)
            turn = turn_y(tilt)
            parts += [box(at(1.8), (0.55, 0.4, 4.6), blade, turn), box(at(-3.2), (2.4, 0.6, 0.55), BRASS, turn),
                      box(at(-4.5), (0.6, 0.5, 0.8), DARK_WOOD, turn), box(at(-5.7), (0.8, 0.6, 0.5), BRASS, turn)]
    else:
        parts += [box((-3.5, face, 6.0), (0.8, 0.6, 4.4), DARK_WOOD), box((-3.5, face, 11.0), (3.6, 0.8, 1.7), IRON),
                  ell((5, face, 5.6), (3.0, 1.0, 3.0), GLASS_GREEN), box((5, face, 9.6), (1.0, 0.7, 1.6), GLASS_GREEN),
                  box((5, face, 11.6), (1.3, 0.7, 0.6), LIGHT_OAK)]
    return render(_lean(parts, math.radians(40)), 32, 32, (16, 27))


# ---------------------------------------------------------------- herb patches (32x32)

def herb(main, light, accent, variant):
    """A herb patch on its tile: leafy bushes in the band's colours, flower heads on top."""
    leaf = ramp_material(["%02x%02x%02x" % tuple(round(min(255, v * k)) for v in c[:3])
                          for c, k in ((light, 1.15), (light, 1.0), (main, 1.0), (main, 0.75), (main, 0.5))], "leaf")
    bloom = Material("%02x%02x%02x" % tuple(accent[:3]), gloss=0.5)
    parts = []
    bushes = ((0, 1, 4.2), (-6.5, 2.5, 3.4), (6.5, 0.5, 3.6), (-3, -4, 3.0), (4, -3.5, 2.8))
    for index, (x, y, r) in enumerate(bushes):
        if variant:
            x = -x
        for leaf_index in range(3):
            angle = leaf_index * 2.1 + index
            at = (x + math.cos(angle) * r * 0.45, y + math.sin(angle) * r * 0.35, r * 0.75 + leaf_index * 0.6)
            parts.append(ell(at, (r * 0.75, r * 0.6, r * 0.55), leaf, turn_z(angle), group=1))
        if index < 4:
            parts.append(ell((x - 0.5, y - 0.5, r * 1.75), (2.1, 2.1, 1.8), bloom, group=2 + index))
    return render(parts, 32, 32, (16, 26), (10, 3))
