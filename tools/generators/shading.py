"""Painted 3D shading shared by props.py (plan 49 removed the creature builders this came with: monsters
are the OpenTibia pack's creatures now).

Things are lists of ellipsoids and solids in their own frame (X right, Y forward, Z up, in pixels).
`render` ray-casts them for one facing with an oblique camera and paints the result: light from the
top-left posterized into a five-tone ramp per material (warm highlights, cool shadows), gloss,
material textures, a coloured outline around the silhouette, and dark lines where one part overlaps
another. Standard library only.
"""
import colorsys
import math

FRAME = 64
GROUND = (32.0, 53.0)
TILT = math.radians(40)
SHADOW = (0, 0, 0, 72)


def add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def mul(a, k):
    return (a[0] * k, a[1] * k, a[2] * k)


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def norm(a):
    length = math.sqrt(dot(a, a)) or 1.0
    return (a[0] / length, a[1] / length, a[2] / length)


UP = (0.0, math.sin(TILT), math.cos(TILT))
VIEW = (0.0, math.cos(TILT), -math.sin(TILT))
LIGHT = norm((-0.55, 0.35, 0.85))
HALF = norm(sub(LIGHT, VIEW))
IDENT = ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0))
# Facing -> creature frame to world (x east, y north, z up); "right" is the mirrored "left".
FACINGS = {
    "down": lambda v: (-v[0], -v[1], v[2]),
    "up": lambda v: (v[0], v[1], v[2]),
    "left": lambda v: (-v[1], v[0], v[2]),
}


# ---------------------------------------------------------------- materials

def _hex(value):
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def _toward(hue, target, amount):
    delta = (target - hue + 0.5) % 1.0 - 0.5
    return (hue + max(-amount, min(amount, delta))) % 1.0


def _shift(rgb, dl, warm, ds):
    h, l, s = colorsys.rgb_to_hls(*(c / 255 for c in rgb))
    h = _toward(h, 0.09, warm) if warm > 0 else _toward(h, 0.63, -warm)
    out = colorsys.hls_to_rgb(h, max(0.02, min(0.97, l + dl)), max(0.0, min(1.0, s + ds)))
    return tuple(round(c * 255) for c in out)


class Material:
    """A five-tone ramp (lightest first) built around `base`, a texture, gloss, and emission."""

    def __init__(self, base, pattern="smooth", gloss=0.0, glow=None, spread=1.0, accent=None):
        rgb = _hex(base)
        k = spread
        self.ramp = [_shift(rgb, 0.24 * k, 0.04, -0.04), _shift(rgb, 0.11 * k, 0.02, 0.0), rgb,
                     _shift(rgb, -0.13 * k, -0.03, 0.05), _shift(rgb, -0.24 * k, -0.05, 0.07)]
        self.pattern = pattern
        self.gloss = gloss
        self.glow = _hex(glow) if glow else None
        self.accent = _hex(accent) if accent else None
        self.edge = _shift(self.ramp[4], -0.12, -0.03, 0.0)


def emissive(color):
    material = Material(color)
    material.glow = _hex(color)
    material.pattern = "emissive"
    return material


EYE = Material("1a1416", gloss=1.0)


def ramp_material(colors, pattern="smooth", gloss=0.0):
    """A material with an explicit five-tone ramp (lightest first)."""
    material = Material(colors[2], pattern, gloss)
    material.ramp = [_hex(c) for c in colors]
    material.edge = _shift(material.ramp[4], -0.15, -0.02, 0.0)
    return material


BONE = Material("d8ccb0", "bone")
GOLD = Material("c89a3a", gloss=0.8)
PINK = Material("c88a80")


# ---------------------------------------------------------------- parts

def basis(direction, roll=0.0):
    """Columns (x, y, z) of a frame whose y axis points along `direction`."""
    y = norm(direction)
    helper = (0.0, 0.0, 1.0) if abs(y[2]) < 0.95 else (1.0, 0.0, 0.0)
    x = norm(cross(y, helper))
    z = cross(x, y)
    if roll:
        c, s = math.cos(roll), math.sin(roll)
        x, z = add(mul(x, c), mul(z, s)), add(mul(x, -s), mul(z, c))
    return (x, y, z)


def ell(center, radii, material, rotation=IDENT, group=None):
    return {"c": center, "r": radii, "R": rotation, "m": material, "g": group}


# ---------------------------------------------------------------- rendering

def _hash(*values):
    h = 2166136261
    for value in values:
        h = ((h ^ (int(value) & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
    return h


def _pattern(material, u, n, p):
    """Shade change (and an override colour or None) from the material's texture at local
    unscaled coordinates u, world normal n, and world point p."""
    kind = material.pattern
    if kind == "fur":
        stroke = _hash(round(u[0] / 1.6), math.floor(u[1] / 3.2 + (round(u[0] / 1.6) % 3) * 0.33), round(u[2] / 1.6)) % 9
        return (-0.13 if stroke == 0 else 0.1 if stroke == 1 else 0.0), None
    if kind in ("stone", "ember", "moss", "obsidian"):
        row = math.floor(u[2] / 4.0)
        fx = (u[1] / 4.6 + 0.43 * row + (u[0] / 5.1)) % 1.0
        fz = (u[2] / 4.0) % 1.0
        crack = fx < 0.14 or fz < 0.16
        if crack and kind in ("ember", "obsidian") and material.accent and _hash(math.floor(u[1] / 4.6 + 0.43 * row), row) % 3:
            return 0.0, material.accent
        if kind == "moss" and material.accent and n[2] > 0.25 and _hash(round(u[0] / 2), round(u[1] / 2), round(u[2] / 2)) % 3 == 0:
            return 0.05, material.accent
        speck = _hash(round(u[0]), round(u[1]), round(u[2])) % 9
        # Each slab is tilted a little differently, so the rock reads as blocks, not clay.
        slab = (_hash(math.floor(u[1] / 4.6 + 0.43 * row), row) % 5 - 2) * 0.07
        return (-0.4 if crack else slab - 0.1 if speck == 0 else slab + 0.08 if speck == 1 else slab), None
    if kind == "chitin":
        return (-0.2 if (u[1] / 3.0) % 1.0 < 0.16 else 0.0), None
    if kind == "warts":
        return (0.16 if _hash(round(u[0] / 2.2), round(u[1] / 2.2), round(u[2] / 2.2)) % 5 == 0 else 0.0), None
    if kind == "scales":
        return (-0.1 if (round(u[1] / 2.4) + round(u[0] / 2.4) + round(u[2] / 2.4)) % 2 else 0.0), None
    if kind == "cloth":
        return 0.12 * math.sin(p[0] * 0.9 + p[1] * 0.4), None
    if kind == "bone":
        return (-0.1 if _hash(round(u[0]), round(u[1] / 2)) % 7 == 0 else 0.0), None
    if kind == "petals" and material.accent:
        return 0.0, (material.accent if _hash(round(u[0] / 2.5), round(u[1] / 2.5), round(u[2] / 2.5)) % 4 == 0 else None)
    return 0.0, None


# The master palette's look (palette.py, plan 46 phase 4): every material's ramp is pushed to more
# saturation and contrast round its base, and outlined in its own hue-tinted near-black
# (palette.outline), instead of the muted ramp and soft edge Material builds.
STYLE = True
SATURATION = 1.3
CONTRAST = 1.25
_STYLED = {}


def _punch(rgb, base_value):
    h, s, v = colorsys.rgb_to_hsv(*(c / 255 for c in rgb))
    s = min(0.95, s * SATURATION + 0.03)
    v = max(0.0, min(1.0, base_value + (v - base_value) * CONTRAST))
    return tuple(round(c * 255) for c in colorsys.hsv_to_rgb(h, s, v))


def _styled(material):
    """(ramp, edge) for `material` in the master palette's look; emissive materials keep theirs."""
    if not STYLE or material.pattern == "emissive":
        return material.ramp, material.edge
    key = id(material)
    if key not in _STYLED:
        base_value = max(material.ramp[2]) / 255
        ramp = [_punch(tone, base_value) for tone in material.ramp]
        h, s, _ = colorsys.rgb_to_hsv(*(c / 255 for c in ramp[4]))
        edge = tuple(round(c * 255) for c in colorsys.hsv_to_rgb(h, min(0.6, s + 0.1), 0.08))
        _STYLED[key] = (material, ramp, edge)
    return _STYLED[key][1], _STYLED[key][2]


def render(parts, direction, shadow=(10.0, 3.5), zoom=1.0):
    """Rows of RGBA tuples or None for one 64x64 frame; the ground origin lands on (32, 53).
    `zoom` scales the creature on screen (anatomy is authored at a common scale)."""
    to_world = FACINGS[direction]
    prepared = []
    for index, part in enumerate(parts):
        part = dict(part, c=mul(part["c"], zoom), r=mul(part["r"], zoom))
        c = to_world(part["c"])
        axes = tuple(to_world(axis) for axis in part["R"])
        r = part["r"]
        dl = tuple(dot(VIEW, axes[i]) / r[i] for i in range(3))
        sx, su = c[0], dot(c, UP)
        reach = max(r) + 1.5
        prepared.append((c, axes, r, dl, dot(dl, dl), part["m"], part["g"] if part["g"] is not None else index,
                         (math.floor(GROUND[0] + sx - reach), math.ceil(GROUND[0] + sx + reach),
                          math.floor(GROUND[1] - su - reach), math.ceil(GROUND[1] - su + reach))))
    depth = [[None] * FRAME for _ in range(FRAME)]
    for c, axes, r, dl, a, material, group, (x0, x1, y0, y1) in prepared:
        for py in range(max(0, y0), min(FRAME, y1 + 1)):
            su = GROUND[1] - (py + 0.5)
            for px in range(max(0, x0), min(FRAME, x1 + 1)):
                sx = px + 0.5 - GROUND[0]
                origin = (sx, su * UP[1] - 80 * VIEW[1], su * UP[2] - 80 * VIEW[2])
                rel = sub(origin, c)
                ol = (dot(rel, axes[0]) / r[0], dot(rel, axes[1]) / r[1], dot(rel, axes[2]) / r[2])
                b = 2 * dot(ol, dl)
                disc = b * b - 4 * a * (dot(ol, ol) - 1)
                if disc < 0:
                    continue
                s = (-b - math.sqrt(disc)) / (2 * a)
                here = depth[py][px]
                if here is None or s < here[0]:
                    q = add(ol, mul(dl, s))
                    depth[py][px] = (s, q, axes, r, material, group, add(origin, mul(VIEW, s)))
    pixels = [[None] * FRAME for _ in range(FRAME)]
    for y in range(FRAME):
        for x in range(FRAME):
            hit = depth[y][x]
            if hit is None:
                continue
            _, q, axes, r, material, _, p = hit
            n = norm(add(add(mul(axes[0], q[0] / r[0]), mul(axes[1], q[1] / r[1])), mul(axes[2], q[2] / r[2])))
            if material.pattern == "emissive":
                lit = 0.5 + 0.5 * max(0.0, -dot(n, VIEW))
                pixels[y][x] = _shift(material.glow, 0.18 * lit - 0.05, 0.02, 0.0) + (255,)
                continue
            value = 0.24 + 0.76 * max(0.0, dot(n, LIGHT))
            value *= 0.82 + 0.18 * min(1.0, max(0.0, p[2] / 14.0))
            u = (q[0] * r[0] / zoom, q[1] * r[1] / zoom, q[2] * r[2] / zoom)
            change, override = _pattern(material, u, n, p)
            if override is not None:
                pixels[y][x] = override + (255,)
                continue
            value += change
            band = 0 if value > 0.86 else 1 if value > 0.66 else 2 if value > 0.46 else 3 if value > 0.3 else 4
            ramp = _styled(material)[0]
            color = ramp[band]
            if material.gloss and max(0.0, dot(n, HALF)) ** 28 * material.gloss > 0.45:
                color = tuple(round(c + (255 - c) * 0.55) for c in ramp[0])
            pixels[y][x] = color + (255,)
    # Outlines: a coloured edge round the silhouette, and dark seams where a nearer part overlaps.
    result = [row[:] for row in pixels]
    for y in range(FRAME):
        for x in range(FRAME):
            hit = depth[y][x]
            if hit is None:
                continue
            material, group = hit[4], hit[5]
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                other = depth[ny][nx] if 0 <= nx < FRAME and 0 <= ny < FRAME else None
                if other is None:
                    if material.pattern != "emissive":
                        result[y][x] = _styled(material)[1] + (255,)
                    break
                if other[5] != group and other[0] < hit[0] - 2.2 and material.pattern != "emissive":
                    result[y][x] = _styled(material)[0][4] + (255,)
                    break
    frame = [[None] * FRAME for _ in range(FRAME)]
    rx, ry = shadow[0] * zoom, shadow[1] * zoom
    cy = GROUND[1] + 0.5
    for y in range(FRAME):
        for x in range(FRAME):
            if ((x + 0.5 - GROUND[0]) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                frame[y][x] = SHADOW
            if result[y][x] is not None:
                frame[y][x] = result[y][x]
    return frame
