"""Painted-style creature sprites, rendered from simple 3D anatomy.

Every creature is a list of ellipsoids (body, head, limbs, tail, horns ...) in its own frame
(X to its right, Y forward, Z up, in pixels at size 1). `render` ray-casts them for one facing
with an oblique camera and paints the result like the painted gear art: light from the top-left
posterized into a five-tone ramp per material (warm highlights, cool shadows), glossy highlights
on chitin and slime, material textures (fur strokes, stone cracks, glowing seams, warts, scales),
a coloured outline around the silhouette, and dark lines where one part overlaps another. Walk
poses move the limbs, so all four facings and the three walk frames stay consistent.

Standard library only; make_sprites.py turns the pixel rows into sheets.
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


IVORY = ramp_material(["f4f0e2", "dcd6c2", "bab4a2", "908c80", "6a6862"], "bone")
BONE = Material("d8ccb0", "bone")
GOLD = Material("c89a3a", gloss=0.8)
PINK = Material("c88a80")
CLAW = Material("3a3230", gloss=0.5)


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


def limb(a, b, radius, material, group=None, flat=None):
    """An elongated ellipsoid from a to b."""
    axis = sub(b, a)
    length = math.sqrt(dot(axis, axis))
    return ell(mul(add(a, b), 0.5), (radius, length / 2 + radius * 0.35, flat or radius), material, basis(axis), group)


def chain(points, radii, material, group=None):
    """A tapering tail or tendril through `points`."""
    return [limb(points[i], points[i + 1], radii[i], material, group) for i in range(len(points) - 1)]


def tilt_y(pitch):
    """A frame pitched about X: positive raises the forward (y) axis."""
    c, s = math.cos(pitch), math.sin(pitch)
    return ((1.0, 0.0, 0.0), (0.0, c, s), (0.0, -s, c))


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
            color = material.ramp[band]
            if material.gloss and max(0.0, dot(n, HALF)) ** 28 * material.gloss > 0.45:
                color = tuple(round(c + (255 - c) * 0.55) for c in material.ramp[0])
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
                        result[y][x] = material.edge + (255,)
                    break
                if other[5] != group and other[0] < hit[0] - 2.2 and material.pattern != "emissive":
                    result[y][x] = material.ramp[4] + (255,)
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


# ---------------------------------------------------------------- anatomy

def quadruped(frame, s):
    """A four-legged beast; `s` sets its proportions, materials, ears, tail, and extras."""
    L, H, g = s["length"], s["height"], s["girth"]
    body, belly, head_m = s["body"], s.get("belly", s["body"]), s.get("head_material", s["body"])
    swing = (0.0, 1.0, -1.0)[frame] * s.get("stride", 3.0)
    bob = (0.0, 0.7, 0.7)[frame]
    top = H + g * 0.55 + bob
    parts = [ell((0, -L * 0.12, top), (g * 0.95, L * 0.36, g * s.get("flat", 0.9)), body, group="body"),
             ell((0, L * 0.2, top + g * 0.08), (g * s.get("chest", 1.0), L * 0.3, g * s.get("flat", 0.9) * 1.04), body, group="body"),
             ell((0, L * 0.02, top - g * 0.45), (g * 0.75, L * 0.42, g * 0.42), belly, group="body")]
    spread = s.get("spread", 0.62)
    for side, end in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
        phase = swing if side * end > 0 else -swing
        hip = (side * g * 0.6, end * L * 0.3, H * 0.95 + bob)
        knee = (side * g * spread, end * L * 0.3 + phase * 0.5 + end * 0.5, H * 0.45 + bob * 0.5)
        foot = (side * g * spread, end * L * 0.3 + phase, s["leg"] + (1.2 if phase * end > 0.5 else 0.0))
        parts += [limb(hip, knee, s["leg"] * 1.35, body, group="leg%d%d" % (side, end)),
                  limb(knee, foot, s["leg"], s.get("leg_material", body), group="leg%d%d" % (side, end)),
                  ell(add(foot, (0, 0.6, -0.3)), (s["leg"] * 1.1, s["leg"] * 1.5, s["leg"] * 0.8), s.get("paw", body),
                      group="leg%d%d" % (side, end))]
    hr = s["head"]
    neck = s.get("neck", 0.5)
    hc = (0, L * 0.5 + hr * 0.45, top + g * neck)
    parts.append(ell(hc, (hr * 0.9, hr, hr * 0.85), head_m, group="head"))
    snout = s.get("snout", 1.0)
    tip = add(hc, (0, hr * (0.8 + snout * 0.9), -hr * 0.35))
    parts.append(limb(add(hc, (0, hr * 0.3, -hr * 0.15)), tip, hr * s.get("snout_width", 0.5), s.get("snout_material", head_m),
                      group="head", flat=hr * 0.45))
    parts.append(ell(add(tip, (0, hr * 0.15, hr * 0.05)), (hr * 0.28, hr * 0.22, hr * 0.22), s.get("nose", EYE), group="head"))
    for side in (1, -1):
        parts.append(ell(add(hc, (side * hr * 0.5, hr * 0.62, hr * 0.28)), (0.95, 0.8, 1.0), s.get("eye", EYE), group="eye"))
        ears = s.get("ears", "round")
        if ears == "round":
            parts.append(ell(add(hc, (side * hr * 0.62, -hr * 0.1, hr * 0.8)), (hr * 0.42, hr * 0.15, hr * 0.42), s.get("ear", head_m),
                             group="ear%d" % side))
        elif ears == "pointed":
            parts.append(limb(add(hc, (side * hr * 0.45, -hr * 0.05, hr * 0.55)), add(hc, (side * hr * 0.62, -hr * 0.15, hr * 1.55)),
                              hr * 0.26, head_m, group="ear%d" % side))
        elif ears == "small":
            parts.append(ell(add(hc, (side * hr * 0.55, -hr * 0.25, hr * 0.7)), (hr * 0.3, hr * 0.12, hr * 0.28), head_m,
                             group="ear%d" % side))
        if s.get("tusks"):
            base = add(tip, (side * hr * 0.42, -hr * 0.45, -hr * 0.15))
            parts.append(limb(base, add(base, (side * hr * 0.25, hr * 0.15, hr * 0.75)), 0.85, BONE, group="tusk%d" % side))
        if s.get("teeth"):
            for k in range(3):
                parts.append(ell(add(hc, (side * hr * 0.42, hr * (1.0 + k * 0.55), -hr * 0.55)), (0.7, 0.6, 0.9), BONE, group="head"))
    tail = s.get("tail")
    back = (0, -L * 0.5, top + g * 0.1)
    sway = (0.0, 1.5, -1.5)[frame]
    if tail == "thin":
        points = [back, add(back, (sway * 0.4, -4, -2)), add(back, (sway, -7.5, -2.5)), add(back, (sway * 1.6, -10.5, -1.0)),
                  add(back, (sway * 2.2, -13, 1.5))]
        parts += chain(points, [1.1, 0.9, 0.75, 0.6], s.get("tail_material", PINK), "tail")
    elif tail == "bushy":
        points = [back, add(back, (sway * 0.3, -5, -2)), add(back, (sway * 0.8, -9, -5)), add(back, (sway, -11, -9))]
        parts += chain(points, [2.0, 2.6, 2.2], s.get("tail_material", body), "tail")
    elif tail == "short":
        parts.append(limb(back, add(back, (sway * 0.3, -3, 1.5)), 1.0, body, group="tail"))
    elif tail == "heavy":
        points = [back, add(back, (sway * 0.4, -5, -3)), add(back, (sway, -10, -5)), add(back, (sway * 1.8, -14, -5.5)),
                  add(back, (sway * 2.6, -17, -5.5))]
        parts += chain(points, [g * 0.7, g * 0.5, g * 0.34, g * 0.2], body, "tail")
    if s.get("spikes"):
        for k in range(5):
            at = (0, L * (0.3 - k * 0.16), top + g * 0.8 - abs(k - 1.5) * 0.4)
            parts.append(limb(at, add(at, (0, -1.8, 3.2 - abs(k - 2) * 0.5)), 0.85, s["spikes"], group="spike%d" % k))
    if s.get("scutes"):
        for k in range(6):
            at = (0, L * (0.32 - k * 0.15), top + g * 0.55)
            parts.append(ell(at, (1.2, 1.4, 1.0), s["scutes"], group="body"))
    if s.get("ruff"):
        parts.append(ell((0, L * 0.38, top + g * 0.25), (g * 1.1, g * 0.8, g * 1.05), s["ruff"], group="body"))
    if s.get("horns"):
        # Swept back from the brow, curling up at the tips.
        for side in (1, -1):
            root = add(hc, (side * hr * 0.45, -hr * 0.2, hr * 0.7))
            points = [root, add(root, (side * hr * 0.25, -hr * 0.8, hr * 0.35)), add(root, (side * hr * 0.4, -hr * 1.5, hr * 0.9))]
            parts += chain(points, [hr * 0.24, hr * 0.15], s["horns"], "horn%d" % side)
    if s.get("wings"):
        # Bat-like wings from the shoulders: a bony leading edge and a membrane, beating with the stride.
        rise = (0.6, 1.0, 0.25)[frame]
        for side in (1, -1):
            shoulder = (side * g * 0.55, L * 0.22, top + g * 0.7)
            wrist = add(shoulder, (side * g * 1.3, -L * 0.04, g * (1.1 + 1.2 * rise)))
            tip = add(wrist, (side * g * 1.1, -L * 0.28, g * (0.2 + 0.6 * rise)))
            edge = s.get("wing_bone", body)
            parts += [limb(shoulder, wrist, 0.9, edge, group="wing%d" % side), limb(wrist, tip, 0.7, edge, group="wing%d" % side)]
            # Membrane sails hanging below each bone: thin along the body, so front and back views show them whole.
            for a, b, chord in ((shoulder, wrist, g * 0.75), (wrist, tip, g * 0.6)):
                axis = sub(b, a)
                centre = add(mul(add(a, b), 0.5), (0, -L * 0.04, -chord * 0.55))
                parts.append(ell(centre, (0.7, math.sqrt(dot(axis, axis)) * 0.55, chord), s["wings"], basis(axis), "wing%d" % side))
    if s.get("crown"):
        crown_c = add(hc, (0, -hr * 0.1, hr * 0.95))
        parts.append(ell(crown_c, (hr * 0.62, hr * 0.62, hr * 0.28), GOLD, group="crown"))
        for k in range(5):
            angle = k / 5 * 2 * math.pi
            base = add(crown_c, (math.cos(angle) * hr * 0.5, math.sin(angle) * hr * 0.5, hr * 0.15))
            parts.append(limb(base, add(base, (0, 0, hr * 0.55)), 0.7, GOLD, group="crown"))
        parts.append(ell(add(crown_c, (0, hr * 0.58, hr * 0.1)), (0.9, 0.6, 0.9), emissive("e04050"), group="gem"))
    return parts


def beetle(frame, s):
    """A six-legged crawler: domed carapace with a seam, a head with mandibles."""
    swing = (0.0, 1.0, -1.0)[frame] * 2.0
    shell, body = s["shell"], s["body"]
    parts = [ell((0, -2, 6), (8.5, 11, 5.5), shell, group="shell"),
             ell((0, 9, 4.5), (5, 4, 3.5), body, group="thorax"),
             ell((0, 13, 4), (3.6, 3, 3), body, group="head")]
    for side in (1, -1):
        parts.append(ell((side * 0.4, -1, 10.6), (0.5, 10, 0.6), Material(s["seam"]), group="shell"))
        parts.append(ell((side * 1.8, 15.2, 5), (0.8, 0.7, 0.8), emissive(s["eyes"]), group="eye"))
        jaw = (side * 1.6, 15.5, 3.2)
        parts.append(limb(jaw, add(jaw, (side * -1.5, 4, 0.2)), 0.8, CLAW, group="jaw%d" % side))
        for k, y in enumerate((7, 1, -5)):
            phase = swing if (k % 2 == 0) == (side > 0) else -swing
            hip = (side * 5, y, 4)
            knee = (side * 10, y + phase * 0.5, 6.5)
            foot = (side * 12, y + phase, 0.6)
            parts += [limb(hip, knee, 1.0, body, group="leg%d%d" % (side, k)), limb(knee, foot, 0.8, body, group="leg%d%d" % (side, k))]
    return parts


def spider(frame, s):
    """Eight jointed legs round a cephalothorax and a big patterned abdomen; a cluster of eyes."""
    k = s.get("scale", 1.0)
    swing = (0.0, 1.0, -1.0)[frame] * 2.2
    body = s["body"]
    a = s.get("abdomen_size", 1.0)
    parts = [ell((0, -8 * k, 8 * k), (8 * k * a, 9.5 * k * a, 7 * k * a), s["abdomen"], tilt_y(0.35), "abdomen"),
             ell((0, 3 * k, 6 * k), (5.5 * k, 6 * k, 4 * k), body, group="thorax"),
             ell((0, 8.5 * k, 5.5 * k), (3.6 * k, 3.2 * k, 3 * k), body, group="head")]
    if s.get("marking"):
        parts.append(ell((0, -9 * k, 14.4 * k), (2.6 * k, 4.5 * k, 0.8 * k), s["marking"], tilt_y(0.35), "abdomen"))
    for side in (1, -1):
        for i, (dx, dz) in enumerate(((0.9, 1.7), (2.0, 1.3))):
            parts.append(ell((side * dx * k, 10.8 * k, (5.5 + dz) * k), (0.8, 0.7, 0.8), emissive(s["eyes"]), group="eye"))
        fang = (side * 1.3 * k, 10.5 * k, 3.5 * k)
        parts.append(limb(fang, add(fang, (0, 1.5 * k, -2.5 * k)), 0.9 * k, CLAW, group="fang%d" % side))
        for i, y in enumerate((6, 3.5, 1, -1.5)):
            phase = swing if (i % 2 == 0) == (side > 0) else -swing
            hip = (side * 4.5 * k, y * k, 6.5 * k)
            reach = (12 - abs(i - 1.5) * 0.8) * k
            knee = (side * reach * 0.75, (y + (i - 1.5) * 3.5) * k + phase * 0.4, 13 * k)
            foot = (side * reach * 1.15, (y + (i - 1.5) * 6.5) * k + phase, 0.6)
            parts += [limb(hip, knee, 1.2 * k, s.get("legs", body), group="leg%d%d" % (side, i)),
                      limb(knee, foot, 0.9 * k, s.get("legs", body), group="leg%d%d" % (side, i))]
        if s.get("pincers"):
            arm = (side * 3 * k, 10 * k, 5.5 * k)
            claw = (side * 6.5 * k, 16 * k + swing * 0.3, 5 * k)
            parts.append(limb(arm, claw, 1.3 * k, s["pincers"], group="pincer%d" % side))
            parts.append(ell(claw, (2.4 * k, 3.2 * k, 1.8 * k), s["pincers"], group="pincer%d" % side))
            for tip in (-1, 1):
                parts.append(limb(add(claw, (side * tip * 0.8 * k, 2.5 * k, 0)), add(claw, (side * tip * 0.5 * k, 5 * k, 0)),
                                  0.6 * k, s["pincers"], group="pincer%d" % side))
    if s.get("stinger"):
        # A segmented tail rising from the abdomen and curling forward over the back.
        points = [(0, -13 * k, 7 * k), (0, -17 * k, 10 * k), (0, -17 * k, 14 * k), (0, -13 * k, 17 * k), (0, -9 * k, 16 * k)]
        parts += chain(points, [1.7 * k, 1.5 * k, 1.3 * k, 1.1 * k], s["abdomen"], "tail")
        parts.append(limb(points[-1], add(points[-1], (0, 2.5 * k, -2.5 * k)), 0.8 * k, s["stinger"], group="tail"))
    return parts


def toad(frame, s):
    squash = (0.0, -0.8, 1.2)[frame]
    skin, belly = s["skin"], s["belly"]
    parts = [ell((0, -1, 5.5 + squash * 0.5), (8.5, 8, 5.2 - squash * 0.4), skin, group="body"),
             ell((0, 5, 5 + squash * 0.5), (7.5, 5.5, 4.5), skin, group="body"),
             ell((0, 6, 2.6), (6, 5, 2.4), belly, group="body")]
    for side in (1, -1):
        parts.append(ell((side * 3.4, 6.5, 9.4 + squash * 0.5), (2.2, 2.2, 2.0), skin, group="dome%d" % side))
        parts.append(ell((side * 3.6, 7.8, 10.2 + squash * 0.5), (1.2, 1.0, 1.1), emissive(s["eyes"]), group="eye"))
        parts.append(ell((side * 3.8, 8.6, 10.4 + squash * 0.5), (0.6, 0.4, 0.6), EYE, group="eye"))
        parts.append(ell((side * 8.2, -3, 3.4 + squash * 0.3), (2.8, 5.5, 3.2), skin, group="thigh%d" % side))
        parts.append(ell((side * 7.5, 2.5, 0.9), (2.4, 3.6, 0.9), skin, group="foot%d" % side))
        parts.append(limb((side * 5, 7, 3.5), (side * 6.5, 10, 0.8), 1.1, skin, group="arm%d" % side))
    parts.append(ell((0, 10.4, 4.2 + squash * 0.4), (4.5, 0.5, 0.45), Material("3a2a20"), group="mouth"))
    return parts


def slime(frame, s):
    """A bog lurker: a heaving slime mound with eye stalks and dripping tendrils."""
    heave = (0.0, 1.0, -0.6)[frame]
    goo = s["goo"]
    parts = [ell((0, 0, 6 + heave * 0.4), (10 + heave * 0.5, 10 - heave * 0.3, 6.5 + heave), goo, group="body"),
             ell((-3, 3, 10 + heave), (5, 5, 4.5), goo, group="body"),
             ell((4, -3, 9.5 + heave * 0.7), (4.5, 4.5, 4), goo, group="body"),
             ell((0, 0, 1.4), (12, 11.5, 1.6), goo, group="base")]
    for i, (x, y, h) in enumerate(((-4, 6, 17), (3, 7, 15), (6, 2, 18))):
        top = (x + (0.8 if i % 2 else -0.8) * heave, y, h + heave)
        parts.append(limb((x * 0.6, y * 0.6, 10), top, 1.1, goo, group="stalk%d" % i))
        parts.append(ell(top, (1.6, 1.6, 1.6), emissive(s["eyes"]), group="eye%d" % i))
        parts.append(ell(add(top, (0, 1.2, 0.2)), (0.7, 0.4, 0.7), EYE, group="eye%d" % i))
    for i, angle in enumerate((0.6, 2.1, 3.6, 5.0)):
        at = (math.cos(angle) * 9, math.sin(angle) * 9, 3)
        parts.append(limb(at, (math.cos(angle) * 14, math.sin(angle) * 14 + heave, 0.8), 1.3, goo, group="tendril%d" % i))
    return parts


def golem(frame, s):
    """A walking stone giant: short legs, a boulder torso, heavy arms, a sunken head."""
    k = s.get("scale", 1.0)
    swing = (0.0, 1.0, -1.0)[frame] * 2.5
    bob = (0.0, 0.8, 0.8)[frame]
    rock = s["rock"]
    parts = []
    for side in (1, -1):
        phase = swing * side
        parts.append(limb((side * 4 * k, phase * 0.2, 11 * k + bob), (side * 4.5 * k, phase, 2.5 * k), 3.6 * k, rock, group="leg%d" % side))
        parts.append(ell((side * 4.5 * k, phase + 1, 1.8 * k), (3.6 * k, 4.4 * k, 2.2 * k), rock, group="leg%d" % side))
    torso_z = 19 * k + bob
    parts.append(ell((0, 0, torso_z), (10 * k, 7 * k, 8.5 * k), rock, group="torso"))
    parts.append(ell((0, 1.5 * k, torso_z - 6 * k), (7.5 * k, 5.5 * k, 4.5 * k), rock, group="torso"))
    parts.append(ell((0, 3 * k, torso_z + 8.5 * k), (4 * k, 3.8 * k, 3.6 * k), rock, group="head"))
    for side in (1, -1):
        parts.append(ell((side * 3.8 * 0.4 * k, 6.4 * k, torso_z + 9 * k), (0.9 * k, 0.6, 0.8 * k), emissive(s["eyes"]), group="eye"))
        shoulder = (side * 10 * k, 0.5 * k, torso_z + 4 * k)
        parts.append(ell(shoulder, (5 * k, 5 * k, 4.6 * k), rock, group="arm%d" % side))
        phase = -swing * side * 0.8
        elbow = (side * 12.5 * k, phase * 0.5 + 1.5 * k, torso_z - 4 * k)
        fist = (side * 12 * k, phase + 3 * k, torso_z - 12 * k)
        parts.append(limb(shoulder, elbow, 3.4 * k, rock, group="arm%d" % side))
        parts.append(limb(elbow, fist, 3.0 * k, rock, group="arm%d" % side))
        parts.append(ell(fist, (4.2 * k, 4.2 * k, 3.8 * k), rock, group="arm%d" % side))
        if s.get("horns"):
            base = (side * 3 * k, 3 * k, torso_z + 11 * k)
            parts += chain([base, add(base, (side * 3 * k, -1 * k, 3 * k)), add(base, (side * 5 * k, -3 * k, 7 * k))],
                           [1.6 * k, 1.0 * k], s["horns"], "horn%d" % side)
        if s.get("moss"):
            parts.append(ell(add(shoulder, (0, 0, 3.6 * k)), (4 * k, 4 * k, 1.6 * k), s["moss"], group="arm%d" % side))
    if s.get("maw"):
        parts.append(ell((0, 6.6 * k, torso_z + 1 * k), (4.5 * k, 1.0, 3.2 * k), emissive(s["maw"]), group="maw"))
        for side in (1, -1):
            for j in range(3):
                parts.append(ell((side * (1 + j * 1.4) * k, 7.2 * k, torso_z + 3.4 * k - j * 0.3), (0.6, 0.6, 1.0), BONE, group="maw"))
    if s.get("core"):
        parts.append(ell((0, 6.8 * k, torso_z), (2.4 * k, 0.8, 2.4 * k), emissive(s["core"]), group="core"))
    return parts


def wraith(frame, s):
    """A floating hooded spirit: a flared tattered robe, reaching sleeves, a dark face with eyes."""
    k = s.get("scale", 1.0)
    float_z = (3.0, 4.2, 2.4)[frame] * k
    sway = (0.0, 1.2, -1.2)[frame]
    robe = s["robe"]
    parts = []
    parts.append(ell((0, 0, float_z + 9 * k), (9 * k, 7.5 * k, 8 * k), robe, group="robe"))
    parts.append(ell((sway * 0.3, -0.5 * k, float_z + 18 * k), (6.6 * k, 5.4 * k, 7.5 * k), robe, group="robe"))
    for i in range(7):
        angle = i / 7 * 2 * math.pi + 0.3
        at = (math.cos(angle) * 8 * k, math.sin(angle) * 6.5 * k, float_z + 3 * k)
        tip = add(at, (math.cos(angle) * 2 * k + sway * 0.6, math.sin(angle) * 2 * k - 1.5, -(3 + (i * 3) % 4) * k))
        parts.append(limb(at, tip, 1.6 * k, robe, group="robe"))
    hood = (0, 1 * k, float_z + 28 * k)
    parts.append(ell(hood, (6 * k, 6 * k, 6.5 * k), s.get("hood", robe), group="hood"))
    parts.append(ell(add(hood, (0, 4.6 * k, -0.8 * k)), (3.6 * k, 1.8 * k, 4.2 * k), Material("0e0a12"), group="face"))
    for side in (1, -1):
        parts.append(ell(add(hood, (side * 1.5 * k, 6.2 * k, -0.2 * k)), (0.95 * k, 0.6, 0.85 * k), emissive(s["eyes"]), group="eye"))
        shoulder = (side * 5 * k, 1 * k, float_z + 22 * k)
        hand = (side * 6.5 * k, 8 * k + sway * side * 0.5, float_z + 15 * k)
        parts.append(limb(shoulder, hand, 2.2 * k, robe, group="sleeve%d" % side))
        for j in (-1, 0, 1):
            parts.append(limb(add(hand, (0, 1, 0)), add(hand, (j * 1.2 * k, 3.8 * k, -1.8 * k)), 0.55 * k, s["claws"], group="claw%d" % side))
    if s.get("flowers"):
        for i, (x, y, z) in enumerate(((-4, 3, 24), (4, 2, 26), (0, -4, 29), (-3, -1, 32), (3, -2, 31), (5, 3, 14), (-5, 2, 10))):
            at = (x * k, y * k, float_z + z * k)
            parts.append(ell(at, (1.8 * k, 1.8 * k, 1.1 * k), s["flowers"], group="flower%d" % i))
            parts.append(ell(add(at, (0, 0, 0.8 * k)), (0.7 * k, 0.7 * k, 0.5 * k), emissive("ffe08a"), group="flower%d" % i))
    if s.get("wings"):
        # Feathered wings from the shoulder blades, beating with the float.
        rise = (0.5, 1.0, 0.1)[frame]
        for side in (1, -1):
            shoulder = (side * 4 * k, -2 * k, float_z + 23 * k)
            wrist = add(shoulder, (side * 7 * k, -2 * k, (3 + 5 * rise) * k))
            tip = add(wrist, (side * 7 * k, -3 * k, (0.5 + 3 * rise) * k))
            edge = s.get("wing_bone", robe)
            parts += [limb(shoulder, wrist, 1.1 * k, edge, group="wing%d" % side),
                      limb(wrist, tip, 0.8 * k, edge, group="wing%d" % side)]
            for a, b, chord in ((shoulder, wrist, 4.5 * k), (wrist, tip, 3.6 * k)):
                axis = sub(b, a)
                centre = add(mul(add(a, b), 0.5), (0, -0.5 * k, -chord * 0.55))
                parts.append(ell(centre, (0.7, math.sqrt(dot(axis, axis)) * 0.55, chord), s["wings"], basis(axis), "wing%d" % side))
    if s.get("antlers"):
        for side in (1, -1):
            base = add(hood, (side * 3 * k, -1 * k, 4.5 * k))
            parts += chain([base, add(base, (side * 3 * k, 0, 4 * k)), add(base, (side * 6 * k, -1 * k, 7 * k))],
                           [1.0 * k, 0.8 * k], s["antlers"], "antler%d" % side)
    return parts


def biped(frame, s):
    """An undead walker: a skeleton (thin bones, ribs, skull), a hunched ghoul (gaunt flesh,
    long arms, rags), or a robed lich (`robe`, a hood or skull, a glowing focus)."""
    swing = (0.0, 1.0, -1.0)[frame] * 2.2
    bob = (0.0, 0.6, 0.6)[frame]
    flesh = s["flesh"]
    thin = s.get("thin", 1.0)
    hunch = s.get("hunch", 0.0)
    parts = []
    hip_z = 13 + bob
    if not s.get("robe"):
        for side in (1, -1):
            phase = swing * side
            knee = (side * 2.2, phase * 0.5 + 0.8, 7 + bob * 0.5)
            foot = (side * 2.4, phase, 1.0)
            parts += [limb((side * 2, 0, hip_z), knee, 1.15 * thin, flesh, group="leg%d" % side),
                      limb(knee, foot, 1.0 * thin, flesh, group="leg%d" % side),
                      ell(add(foot, (0, 1.0, -0.2)), (1.3, 2.0, 0.9), flesh, group="leg%d" % side)]
        parts.append(ell((0, 0, hip_z + 0.5), (3.6, 2.2, 1.6), s.get("rags", flesh), group="pelvis"))
    else:
        robe = s["robe"]
        parts.append(ell((0, 0, 7 + bob), (6.5, 5.5, 7.5), robe, group="robe"))
        parts.append(ell((0, 0, 1.6), (7.5, 6.5, 1.8), robe, group="robe"))
    chest = (0, hunch * 2.5, 19 + bob - hunch)
    if s.get("ribs"):
        parts.append(ell(add(chest, (0, -0.6, -1.0)), (0.9, 0.9, 5.2), flesh, group="spine"))
        for k in range(4):
            parts.append(ell(add(chest, (0, 0.4, 2.4 - k * 1.7)), (3.8 - k * 0.35, 2.4, 0.6), flesh, group="rib%d" % k))
        parts.append(ell(add(chest, (0, 0, 3.8)), (4.6, 1.6, 0.8), flesh, group="collar"))
    else:
        parts.append(ell(chest, (4.2, 2.8 + hunch * 0.5, 4.4), s.get("torso", s.get("robe", flesh)), tilt_y(-hunch * 0.3), "torso"))
    head = add(chest, (0, 0.8 + hunch * 2.5, 6.2 - hunch * 1.5))
    skull = s.get("skull", flesh)
    parts.append(ell(head, (3.0, 3.2, 3.3), skull, group="head"))
    parts.append(ell(add(head, (0, 1.6, -2.0)), (2.1, 1.8, 1.4), skull, group="head"))
    for side in (1, -1):
        if s.get("ribs"):
            # Deep sockets with a pinpoint of light.
            parts.append(ell(add(head, (side * 1.25, 2.55, 0.2)), (1.2, 0.8, 1.15), EYE, group="eye"))
            parts.append(ell(add(head, (side * 1.25, 3.0, 0.2)), (0.55, 0.45, 0.55), emissive(s["eyes"]), group="eye"))
        else:
            parts.append(ell(add(head, (side * 1.2, 2.7, 0.2)), (0.85, 0.5, 0.8),
                             emissive(s["eyes"]) if s.get("eyes") else EYE, group="eye"))
        shoulder = add(chest, (side * 4.4, 0, 2.6))
        reach = s.get("reach", 1.0)
        elbow = add(shoulder, (side * 1.4, -swing * side * 0.4 + 1.5 * hunch, -4.5 * reach))
        hand = add(elbow, (side * 0.4, -swing * side * 0.6 + 1.5 + 2 * hunch, -4.5 * reach))
        sleeve = s.get("robe") or flesh
        parts += [limb(shoulder, elbow, 1.15 * thin, sleeve, group="arm%d" % side),
                  limb(elbow, hand, 1.0 * thin, flesh if not s.get("robe") else sleeve, group="arm%d" % side),
                  ell(hand, (1.2, 1.3, 1.2), flesh, group="arm%d" % side)]
        if s.get("claws"):
            for j in (-1, 1):
                parts.append(limb(hand, add(hand, (j * 0.6, 1.4, -1.8)), 0.4, CLAW, group="arm%d" % side))
    if s.get("hood"):
        parts.append(ell(add(head, (0, -0.6, 0.6)), (3.8, 3.6, 3.9), s["hood"], group="hood"))
    if s.get("focus"):
        parts.append(ell(add(chest, (0, 5.5, -1.5)), (1.6, 1.6, 1.6), emissive(s["focus"]), group="focus"))
    if s.get("crown"):
        crown_c = add(head, (0, -0.2, 3.0))
        parts.append(ell(crown_c, (2.9, 2.9, 0.9), s["crown"], group="crown"))
        for k in range(6):
            angle = k / 6 * 2 * math.pi
            base = add(crown_c, (math.cos(angle) * 2.4, math.sin(angle) * 2.4, 0.4))
            parts.append(limb(base, add(base, (math.cos(angle) * 0.4, math.sin(angle) * 0.4, 2.2 + (k % 2) * 0.9)), 0.55,
                              s["crown"], group="crown"))
        parts.append(ell(add(crown_c, (0, 2.6, 0.3)), (0.8, 0.5, 0.8), emissive(s.get("focus", s["eyes"])), group="gem"))
    if s.get("rags"):
        for k, side in enumerate((1, -1, 1)):
            at = (side * 2.2 - k * 0.4, 1.0, hip_z - 0.6)
            parts.append(limb(at, add(at, (side * 0.3, 0.4, -4.0)), 1.0, s["rags"], group="rags%d" % k))
    return parts


def giant(frame, s):
    """A cyclops: thick legs under a loincloth, a big belly, broad shoulders, long arms, a small
    bald head with one great eye and a horn, and a weapon in the right hand (a club, or a smith's
    hammer); `apron` gives a leather smith's apron, `soot` darkens the hands."""
    swing = (0.0, 1.0, -1.0)[frame] * 2.6
    bob = (0.0, 0.7, 0.7)[frame]
    skin = s["skin"]
    parts = []
    for side in (1, -1):
        phase = swing * side
        knee = (side * 3.6, phase * 0.5 + 0.8, 6.5 + bob * 0.5)
        foot = (side * 3.8, phase, 1.4)
        parts += [limb((side * 3.4, 0, 12 + bob), knee, 2.6, skin, group="leg%d" % side),
                  limb(knee, foot, 2.2, skin, group="leg%d" % side),
                  ell(add(foot, (0, 1.2, -0.4)), (2.6, 3.4, 1.4), s.get("feet", skin), group="leg%d" % side)]
    parts.append(ell((0, 0.4, 13 + bob), (6.2, 4.4, 3.4), s["cloth"], group="cloth"))
    parts.append(ell((0, 1.8, 18 + bob), (7.2, 5.6, 6.4), skin, group="belly"))
    parts.append(ell((0, 0, 24 + bob), (8.4, 5.2, 4.6), skin, group="chest"))
    if s.get("apron"):
        parts.append(ell((0, 6.4, 18 + bob), (5.6, 1.6, 7.6), s["apron"], group="apron"))
    head = (0, 2.0, 30 + bob)
    parts.append(ell(head, (3.6, 3.6, 3.8), skin, group="head"))
    if s.get("troll"):
        # A troll: two small deep-set eyes under a heavy brow, and tusks from the jaw.
        parts.append(ell(add(head, (0, 2.6, 1.4)), (3.0, 1.4, 0.9), skin, group="brow"))
        for side in (1, -1):
            parts.append(ell(add(head, (side * 1.3, 3.2, 0.4)), (0.7, 0.5, 0.6), emissive(s["eye"]), group="eye"))
            tusk = add(head, (side * 1.6, 3.0, -2.0))
            parts.append(limb(tusk, add(tusk, (side * 0.4, 0.8, 1.8)), 0.55, BONE, group="tusk"))
        parts.append(ell(add(head, (0, 3.2, -2.2)), (2.4, 1.0, 0.7), Material("2a1a12"), group="mouth"))
    else:
        parts.append(ell(add(head, (0, 3.0, 0.6)), (2.6, 1.0, 2.2), Material("f4f0e2"), group="eye"))
        parts.append(ell(add(head, (0, 3.7, 0.6)), (1.4, 0.6, 1.4), emissive(s["eye"]), group="eye"))
        parts.append(ell(add(head, (0, 4.1, 0.6)), (0.6, 0.4, 0.6), EYE, group="eye"))
        parts.append(ell(add(head, (0, 3.2, -2.0)), (2.2, 1.0, 0.6), Material("3a2018"), group="mouth"))
        horn = add(head, (0, 0.5, 3.4))
        parts += chain([horn, add(horn, (0, -0.6, 2.2)), add(horn, (0, -1.4, 3.6))], [1.0, 0.6], s.get("horn", BONE), "horn")
    hands = s.get("hands", skin)
    for side in (1, -1):
        shoulder = (side * 8.0, 0, 25 + bob)
        parts.append(ell(shoulder, (3.4, 3.4, 3.2), skin, group="arm%d" % side))
        if s.get("shards"):
            # Ice crystals growing from the shoulders.
            for k, (dx, dy, h) in enumerate(((0.0, -0.6, 5.5), (1.6, 1.2, 3.8), (-1.4, -2.0, 3.2))):
                base = add(shoulder, (side * dx, dy, 2.2))
                parts.append(limb(base, add(base, (side * (0.8 + dx * 0.4), dy * 0.3, h)), 1.0 - k * 0.15, s["shards"],
                                  group="shard%d%d" % (side, k)))
        phase = -swing * side * 0.8
        elbow = (side * 10.0, phase * 0.5 + 1.0, 19 + bob)
        fist = (side * 9.6, phase + 2.4, 13 + bob)
        parts += [limb(shoulder, elbow, 2.4, skin, group="arm%d" % side), limb(elbow, fist, 2.2, skin, group="arm%d" % side),
                  ell(fist, (2.6, 2.6, 2.4), hands, group="arm%d" % side)]
        if side == 1:
            weapon = s["weapon"]
            # Held out to the side and forward, so it shows in every facing.
            if weapon == "club":
                parts.append(limb(add(fist, (0, 0, -1.0)), add(fist, (3.5, 5.0, 9.0)), 1.6, Material("8a6a44", "bone"), group="weapon"))
                parts.append(ell(add(fist, (4.0, 5.8, 10.5)), (3.0, 3.0, 3.8), Material("7a5a38", "bone"), group="weapon"))
                for k in range(3):
                    parts.append(ell(add(fist, (4.0 + (k - 1) * 2.0, 6.0, 12 + k % 2)), (0.7, 0.7, 1.2), BONE, group="weapon"))
            else:
                parts.append(limb(add(fist, (0, 0, -1.0)), add(fist, (3.0, 4.5, 8.0)), 1.0, Material("6a4a2e"), group="weapon"))
                parts.append(ell(add(fist, (3.3, 5.0, 9.4)), (4.0, 2.2, 2.4), Material("6a6a74", "stone", gloss=0.7),
                                 basis((1, 0.3, 0)), "weapon"))
    return parts


IRON = Material("8a8a92", "stone", gloss=0.7)
WOOD = Material("7a5a3a", "bone")


def _orc_weapon(kind, fist, side):
    """What an orc holds in one fist, held forward and to the side so it shows in every facing."""
    if kind == "axe":
        top = add(fist, (side * 1.2, 3.0, 7.5))
        return [limb(add(fist, (0, -0.4, -1.5)), top, 0.55, WOOD, group="weapon"),
                ell(add(top, (side * 0.4, 1.2, -0.8)), (0.6, 2.6, 2.4), IRON, basis((0, 1, 0.3)), "weapon")]
    if kind == "spear":
        tip = add(fist, (side * 0.4, 5.5, 11.0))
        return [limb(add(fist, (0, -2.2, -4.0)), tip, 0.45, WOOD, group="weapon"),
                limb(tip, add(tip, (0, 1.0, 2.6)), 0.65, IRON, group="weapon")]
    if kind == "staff":
        top = add(fist, (side * 0.6, 1.6, 12.0))
        parts = [limb(add(fist, (0, -0.6, -6.0)), top, 0.5, WOOD, group="weapon"),
                 ell(top, (1.4, 1.5, 1.4), BONE, group="weapon"),
                 ell(add(top, (0, 1.1, 0.1)), (0.5, 0.4, 0.45), emissive("70e070"), group="weapon")]
        for k in (-1, 1):
            parts.append(limb(add(top, (k * 0.9, 0, -1.2)), add(top, (k * 1.6, 0.2, -4.0)), 0.35,
                              Material("c84a3a", "fur"), group="weapon"))
        return parts
    if kind == "cleaver":
        top = add(fist, (side * 1.0, 3.2, 8.5))
        return [limb(add(fist, (0, -0.4, -1.2)), add(fist, (side * 0.4, 1.2, 2.6)), 0.6, WOOD, group="weapon"),
                ell(add(fist, (side * 0.8, 2.4, 6.4)), (0.55, 2.6, 4.6), IRON, basis((side * 0.15, 0.35, 1.0)), "weapon"),
                ell(top, (0.5, 0.8, 0.6), IRON, group="weapon")]
    if kind == "shield":
        center = add(fist, (side * 1.4, 1.8, 1.0))
        return [ell(center, (0.9, 3.4, 3.4), WOOD, basis((side, 0.2, 0)), "shield"),
                ell(add(center, (side * 0.8, 0.2, 0)), (0.6, 1.2, 1.2), IRON, group="shield")]
    return []


def orc(frame, s):
    """An orc: a stocky green biped with a heavy jaw, tusks from the underbite, a low brow over
    small glowing eyes, long pointed ears, a hide kilt and belt, boots, and its gear: `armor` over
    the chest (bare skin and `paint` for berserkers), `helmet` (with `horns`), `pauldrons`, a
    `cape`, a `hair` top-knot, and a weapon in each fist (`weapon`, `off`). `bulk` widens it."""
    swing = (0.0, 1.0, -1.0)[frame] * 2.4
    bob = (0.0, 0.6, 0.6)[frame]
    skin = s["skin"]
    bulk = s.get("bulk", 1.0)
    boots = s.get("boots", Material("3a2a1e", "fur"))
    cloth = s.get("cloth", Material("5a4632", "fur"))
    parts = []
    hip_z = 12 + bob
    for side in (1, -1):
        phase = swing * side
        knee = (side * 2.6 * bulk, phase * 0.5 + 0.8, 6.5 + bob * 0.5)
        foot = (side * 2.8 * bulk, phase, 1.2)
        group = "leg%d" % side
        parts += [limb((side * 2.4 * bulk, 0, hip_z), knee, 1.6 * bulk, skin, group=group),
                  limb(knee, foot, 1.4 * bulk, boots, group=group),
                  ell(add(foot, (0, 1.1, -0.3)), (1.6 * bulk, 2.3, 1.1), boots, group=group)]
    parts.append(ell((0, 0.2, hip_z + 0.2), (4.6 * bulk, 3.3 * bulk, 2.4), cloth, group="kilt"))
    for k, x in enumerate((-1.8, 1.8)):
        at = (x * bulk, 2.4 * bulk, hip_z - 0.4)
        parts.append(limb(at, add(at, (x * 0.2, 0.5, -4.2)), 1.2, cloth, group="flap%d" % k))
    chest = (0, 0.6, 18.5 + bob)
    parts.append(ell(chest, (5.2 * bulk, 3.6 * bulk, 5.0), s.get("armor", skin), tilt_y(-0.25), "torso"))
    if s.get("paint"):
        for k in (-1, 1):
            parts.append(limb(add(chest, (k * 2.6, 3.2 * bulk, 2.2)), add(chest, (k * 0.8, 3.5 * bulk, -1.6)), 0.55,
                              s["paint"], group="paint"))
    parts.append(ell((0, 0.3, hip_z + 2.4), (4.9 * bulk, 3.5 * bulk, 0.9), Material("4a3020", "cloth"), group="belt"))
    parts.append(ell((0, 3.5 * bulk, hip_z + 2.4), (1.0, 0.5, 0.8), IRON, group="buckle"))
    head = add(chest, (0, 1.6, 6.4))
    parts.append(ell(head, (3.1, 3.0, 3.0), skin, group="head"))
    parts.append(ell(add(head, (0, 1.8, -1.6)), (2.6, 1.9, 1.4), skin, group="jaw"))
    parts.append(ell(add(head, (0, 2.3, 0.9)), (2.9, 1.0, 0.7), skin, group="brow"))
    parts.append(ell(add(head, (0, 3.1, -0.3)), (0.8, 0.6, 0.8), skin, group="nose"))
    for side in (1, -1):
        parts.append(ell(add(head, (side * 1.15, 2.75, 0.25)), (0.6, 0.4, 0.5), emissive(s.get("eyes", "f0c040")), group="eye"))
        tusk = add(head, (side * 1.4, 3.0, -2.0))
        parts.append(limb(tusk, add(tusk, (side * 0.3, 0.5, 1.7)), 0.45, BONE, group="tusk"))
        ear = add(head, (side * 2.7, 0, 0.5))
        parts.append(limb(ear, add(ear, (side * 1.8, -0.7, 1.2)), 0.6, skin, group="ear%d" % side))
    if s.get("hair"):
        parts.append(ell(add(head, (0, -0.6, 2.9)), (1.2, 1.2, 1.5), s["hair"], group="hair"))
        parts += chain([add(head, (0, -1.4, 3.6)), add(head, (0, -3.0, 2.0)), add(head, (0, -3.6, -0.6))], [0.8, 0.6],
                       s["hair"], "hair")
    if s.get("helmet"):
        parts.append(ell(add(head, (0, -0.2, 1.3)), (3.4, 3.3, 2.5), s["helmet"], group="helmet"))
        if s.get("horns"):
            for side in (1, -1):
                base = add(head, (side * 2.8, 0, 2.2))
                parts += chain([base, add(base, (side * 1.8, 0.4, 1.6)), add(base, (side * 2.2, 1.2, 3.8))], [0.8, 0.5],
                               s["horns"], "horn%d" % side)
    if s.get("cape"):
        parts.append(ell(add(chest, (0, -3.6 * bulk, -2.5)), (4.8 * bulk, 0.8, 7.2), s["cape"], group="cape"))
    for side in (1, -1):
        group = "arm%d" % side
        shoulder = add(chest, (side * 5.4 * bulk, 0, 3.0))
        phase = -swing * side * 0.6
        elbow = add(shoulder, (side * 1.6, phase * 0.5 + 0.8, -4.6))
        fist = add(elbow, (side * 0.2, phase + 2.0, -4.0))
        parts += [ell(shoulder, (2.0 * bulk, 2.0 * bulk, 1.9), skin, group=group),
                  limb(shoulder, elbow, 1.5 * bulk, skin, group=group),
                  limb(elbow, fist, 1.4 * bulk, s.get("bracers", skin), group=group),
                  ell(fist, (1.5, 1.5, 1.4), skin, group=group)]
        if s.get("pauldrons"):
            parts.append(ell(add(shoulder, (0, 0, 0.8)), (2.5 * bulk, 2.5 * bulk, 1.6), s["pauldrons"], group="pauldron%d" % side))
        parts += _orc_weapon(s.get("weapon", "axe") if side == 1 else s.get("off", ""), fist, side)
    return parts


# ---------------------------------------------------------------- species

def M(base, pattern="smooth", **kw):
    return Material(base, pattern, **kw)


SPECIES = {
    "field_vole": (quadruped, dict(length=18, height=3, girth=5.2, head=4.2, snout=0.45, leg=1.0, stride=2.0, ears="round",
                                   tail="short", body=M("a08566", "fur"), belly=M("c8b090", "fur"), ear=PINK, paw=PINK,
                                   nose=PINK), (8, 3)),
    "sewer_rat": (quadruped, dict(length=18, height=3.2, girth=5.0, head=3.8, snout=0.9, snout_width=0.4, leg=0.9, stride=2.2,
                                  ears="round", tail="thin", body=M("7a6a5e", "fur"), belly=M("a09080", "fur"), ear=PINK,
                                  paw=PINK, nose=PINK), (8, 3)),
    "giant_rat": (quadruped, dict(length=22, height=4, girth=6.4, head=4.6, snout=1.0, snout_width=0.42, leg=1.2,
                                  ears="round", tail="thin", body=M("5e5046", "fur"), belly=M("8a7a6a", "fur"), ear=PINK,
                                  paw=PINK, nose=PINK, teeth=True, eye=emissive("e04040")), (10, 3.5)),
    "rat_king": (quadruped, dict(length=24, height=4.5, girth=7.4, head=5.2, snout=0.95, snout_width=0.42, leg=1.4,
                                 ears="round", tail="thin", body=M("8a6a52", "fur"), belly=M("b09a80", "fur"), ear=PINK,
                                 paw=PINK, nose=PINK, teeth=True, crown=True, eye=emissive("ff5a3a")), (11, 4)),
    "thornback_boar": (quadruped, dict(length=24, height=6, girth=7, head=5.4, snout=0.7, snout_width=0.55, leg=1.6,
                                       ears="small", tail="short", body=M("7a5440", "fur"), belly=M("8a6a52", "fur"),
                                       nose=M("c09080"), tusks=True, spikes=M("d8ccb0", "bone"), chest=1.08,
                                       paw=M("3a2a22")), (12, 4)),
    "grey_wolf": (quadruped, dict(length=26, height=9, girth=6.2, head=4.6, snout=1.05, snout_width=0.42, leg=1.25,
                                  ears="pointed", tail="bushy", body=M("8a9096", "fur"), belly=M("c8ccd0", "fur"),
                                  ruff=M("b0b6bc", "fur"), chest=1.1, neck=0.9, eye=emissive("e8c040"),
                                  paw=M("4a4c50")), (12, 3.5)),
    "frostfang_wolf": (quadruped, dict(length=27, height=9.5, girth=6.4, head=4.8, snout=1.05, snout_width=0.42, leg=1.3,
                                       ears="pointed", tail="bushy", body=M("c8d4dc", "fur"), belly=M("eef4f8", "fur"),
                                       ruff=M("e4ecf2", "fur"), chest=1.1, neck=0.9, eye=emissive("70d8ff"),
                                       paw=M("6a7a88"), nose=M("2a3038")), (12, 3.5)),
    "greymaw": (quadruped, dict(length=30, height=10.5, girth=7.4, head=5.4, snout=1.05, snout_width=0.45, leg=1.6,
                                ears="pointed", tail="bushy", body=M("3e3e46", "fur"), belly=M("5a5a64", "fur"),
                                ruff=M("4a4a54", "fur"), chest=1.15, neck=0.9, eye=emissive("ff3a2a"), teeth=True,
                                spikes=M("b8b0a0", "bone"), paw=M("22222a")), (14, 4)),
    "behemoth": (quadruped, dict(length=30, height=8, girth=9.5, head=6.2, snout=0.55, snout_width=0.7, leg=2.6, spread=0.75,
                                 stride=2.2, ears="small", tail="short", body=M("5a4a3a", "fur"), belly=M("7a6a52", "fur"),
                                 head_material=M("4a3c30", "stone"), nose=M("2a2018"), tusks=True,
                                 scutes=M("6a6050", "stone"), chest=1.15, neck=0.2, eye=emissive("e8a030"),
                                 paw=M("2a2420")), (16, 5)),
    "cyclops": (giant, dict(skin=M("b0927a"), cloth=M("6a5236", "fur"), eye="5a8ad0", weapon="club"), (13, 4)),
    "cyclops_smith": (giant, dict(skin=M("9a7a64"), cloth=M("4a3a2a", "fur"), apron=M("5a3a22", "cloth"), eye="e0703a",
                                  weapon="hammer", hands=M("4a3a32"), horn=M("3a3230", "stone")), (13, 4)),
    "reedfang": (quadruped, dict(length=26, height=3.2, girth=6.5, flat=0.6, head=5, snout=1.5, snout_width=0.5, leg=1.6,
                                 spread=1.05, stride=2.4, ears="none", tail="heavy", body=M("5d7346", "scales"),
                                 belly=M("a8a870", "scales"), scutes=M("3e5030", "stone"), teeth=True, neck=0.15,
                                 eye=emissive("e8d040"), nose=M("2a3420")), (15, 4)),
    "cave_crawler": (beetle, dict(shell=M("4a4038", "chitin", gloss=0.9), body=M("3a3230", "chitin", gloss=0.6),
                                  seam="241c18", eyes="d0a040"), (13, 4)),
    "cave_spider": (spider, dict(body=M("5a5260", "chitin", gloss=0.6), abdomen=M("4a4250", "fur"),
                                 marking=M("8a8296"), eyes="e03a3a"), (13, 4)),
    "venom_weaver": (spider, dict(body=M("5a6a30", "chitin", gloss=0.6), abdomen=M("6a7a3a", "fur"),
                                  marking=M("e0d040", gloss=0.4), eyes="c0f040", legs=M("3a4420", "chitin")), (13, 4)),
    "silk_matron": (spider, dict(body=M("3a2030", "chitin", gloss=0.8), abdomen=M("4a2a3a", "fur"),
                                 marking=M("c02a3a", gloss=0.6), eyes="ff4a4a", legs=M("2a1822", "chitin", gloss=0.5),
                                 scale=1.08), (15, 4.5)),
    "marsh_toad": (toad, dict(skin=M("7d9a52", "warts"), belly=M("c8c08a"), eyes="e8c040"), (11, 4)),
    "bog_lurker": (slime, dict(goo=M("5c7d6a", "smooth", gloss=1.0), eyes="e8e060"), (14, 4.5)),
    "stone_golem": (golem, dict(rock=M("8c887e", "stone", spread=1.3), eyes="f0b040", moss=M("6a8a48", "fur")), (14, 4.5)),
    "bog_hulk": (golem, dict(rock=M("5f7d58", "moss", accent="8cb04a"), eyes="d0f060", moss=M("6a9a40", "fur")), (14, 4.5)),
    "ember_golem": (golem, dict(rock=M("7a3a24", "ember", accent="ffa030"), eyes="ffd040", core="ff8a20"), (14, 4.5)),
    "forgemaw": (golem, dict(rock=M("5a2a1c", "ember", accent="ff7a20"), eyes="ffd040", maw="ff6a10",
                             horns=M("2a2220", "stone"), scale=1.05), (15, 4.5)),
    "kharzul": (golem, dict(rock=M("4a2a22", "ember", accent="ff9a3a"), eyes="fff060", maw="ff8a20",
                            horns=M("1e1a1a", "stone", gloss=0.4), core="ffb040", scale=1.1), (16, 5)),
    "obsidian_golem": (golem, dict(rock=M("3a3050", "obsidian", gloss=0.9, accent="a070ff"), eyes="c090ff",
                                   core="9a5aff"), (14, 4.5)),
    "crypt_skeleton": (biped, dict(flesh=IVORY, skull=IVORY, ribs=True, thin=0.75, eyes="70c8ff", rags=M("4a4038", "cloth")), (8, 3)),
    "grave_ghoul": (biped, dict(flesh=M("6f7d62", "warts"), torso=M("5e6a52", "warts"), hunch=1.0, reach=1.25, claws=True,
                                eyes="e0e070", rags=M("4a4438", "cloth"), thin=1.1), (9, 3)),
    "abbot_morrow": (biped, dict(flesh=IVORY, skull=IVORY, robe=M("5a4a78", "cloth", spread=1.3), hood=M("4a3a66", "cloth", spread=1.3),
                                 eyes="b080ff", focus="a070ff"), (9, 3)),
    "cinder_wraith": (wraith, dict(robe=M("5a2a1e", "cloth"), hood=M("4a2018", "cloth"), eyes="ffb040",
                                   claws=emissive("ff8a3a")), (10, 3)),
    "mire_stalker": (wraith, dict(robe=M("4a6040", "cloth"), hood=M("3a5034", "cloth"), eyes="d8f060",
                                  claws=M("2a3020")), (10, 3)),
    "void_wraith": (wraith, dict(robe=M("4a2a6a", "cloth"), hood=M("3a2058", "cloth"), eyes="d0a0ff",
                                 claws=emissive("b080ff")), (10, 3)),
    "ashmaw_drake": (quadruped, dict(length=28, height=8, girth=7, head=5.0, snout=1.3, snout_width=0.48, leg=1.7, spread=0.8,
                                     stride=2.4, ears="none", tail="heavy", body=M("4a3430", "scales"), belly=M("c8682a", "scales"),
                                     scutes=M("1e1818", "stone"), teeth=True, neck=1.4, eye=emissive("ffb030"),
                                     nose=M("1a1414"), paw=M("1e1818"), horns=M("d8ccb0", "bone"),
                                     wings=M("a83a26", "cloth"), wing_bone=M("2a2020", "scales")), (15, 4.5)),
    "thornscale_basilisk": (quadruped, dict(length=30, height=4, girth=7, flat=0.65, head=5.4, snout=1.3, snout_width=0.55,
                                            leg=1.9, spread=1.05, stride=2.4, ears="none", tail="heavy",
                                            body=M("4a6a2a", "scales"), belly=M("c8b860", "scales"), spikes=M("d8602a", "bone"),
                                            scutes=M("2e4420", "stone"), teeth=True, neck=0.2, eye=emissive("ff4030"),
                                            nose=M("1e2a14"), paw=M("2a3418"), horns=M("e0c060", "bone")), (16, 4.5)),
    "rime_titan": (giant, dict(skin=M("a8c4d8"), cloth=M("e8eef2", "fur"), eye="70e0ff", weapon="club",
                               horn=M("d8f4ff", gloss=0.8), hands=M("7a98b0"), shards=M("c8f0ff", gloss=0.9)), (14, 4.5)),
    "barrow_lich": (biped, dict(flesh=IVORY, skull=IVORY, robe=M("3e5a54", "cloth", spread=1.3), eyes="60ffc0",
                                focus="60ffc0", crown=M("d0a840", gloss=0.8), torso=M("4a6a62", "cloth")), (10, 3.5)),
    "dire_bear": (quadruped, dict(length=26, height=7, girth=8.6, head=5.6, snout=0.75, snout_width=0.6, leg=2.1, spread=0.8,
                                  stride=2.0, ears="round", tail="short", body=M("6a4a32", "fur"), belly=M("8a6a4a", "fur"),
                                  ruff=M("5a3e2a", "fur"), chest=1.15, neck=0.5, eye=emissive("e8a030"), nose=M("2a1e18"),
                                  paw=M("2a2018"), teeth=True), (15, 4.5)),
    "harpy": (wraith, dict(robe=M("8a6a42", "fur"), hood=M("b08a5a", "fur"), eyes="f0c040", claws=M("3a2a1a"),
                           wings=M("a07a4a", "fur"), wing_bone=M("5a4028", "fur")), (11, 3.5)),
    "dune_scorpion": (spider, dict(body=M("b08a40", "chitin", gloss=0.6), abdomen=M("c09a50", "chitin", gloss=0.5),
                                   legs=M("8a6a30", "chitin"), eyes="ffe080", stinger=M("d86a2a", "chitin", gloss=0.8),
                                   pincers=M("a07a38", "chitin", gloss=0.6), abdomen_size=0.7), (13, 4)),
    "stone_troll": (giant, dict(skin=M("7a7e66", "stone"), cloth=M("4a4234", "fur"), eye="e0c040", weapon="club",
                                troll=True, hands=M("5a5e4a", "stone")), (13, 4)),
    "cave_troll": (giant, dict(skin=M("4e5246", "warts"), cloth=M("3a3028", "fur"), eye="c0e040", weapon="club",
                               troll=True, hands=M("3a3e34", "warts")), (14, 4.5)),
    "ogre_brute": (giant, dict(skin=M("a08a64"), cloth=M("5a4630", "fur"), eye="e0a040", weapon="club",
                               hands=M("7a6a4a"), troll=True), (13, 4)),
    "ogre_smasher": (giant, dict(skin=M("8a7452"), cloth=M("4a3a28", "fur"), eye="f07a3a",
                                 weapon="hammer", hands=M("5a4a36"), troll=True), (14, 4.5)),
    "gorvak": (giant, dict(skin=M("74603e"), cloth=M("6a2a22", "fur"), eye="ff4a2a", weapon="hammer",
                           hands=M("4a3a28"), horn=M("d8ccb0", gloss=0.5), troll=True), (16, 5)),
    "bog_troll": (giant, dict(skin=M("4e6040", "moss"), cloth=M("3a4430", "fur"), eye="d0f060", weapon="club",
                              troll=True, hands=M("3e4a32", "moss")), (14, 4.5)),
    "grotto_leech": (slime, dict(goo=M("6a2a30", "smooth", gloss=1.0), eyes="ffb0a0"), (14, 4.5)),
    "drowned_abbess": (biped, dict(flesh=M("8aa8a0"), skull=M("9ab8b0"), robe=M("2e5a58", "cloth", spread=1.3),
                                   hood=M("244a48", "cloth", spread=1.3), eyes="60f0d0", focus="60f0d0",
                                   crown=M("b0c8b8", gloss=0.6)), (10, 3.5)),
    "magma_hound": (quadruped, dict(length=26, height=8.5, girth=6.6, head=4.8, snout=1.05, snout_width=0.45, leg=1.3,
                                    ears="pointed", tail="bushy", body=M("3e241c", "ember", accent="ff7a2a"),
                                    belly=M("6a3a22", "fur"), ruff=M("5a2a1e", "ember", accent="ffa040"), chest=1.12,
                                    neck=0.9, eye=emissive("ffd040"), teeth=True, paw=M("1e1410")), (12, 3.5)),
    "cinder_brute": (golem, dict(rock=M("4a2a20", "ember", accent="ff8a30"), eyes="ffe060", core="ff7a20",
                                 horns=M("2a2220", "stone")), (14, 4.5)),
    "frost_ogre": (giant, dict(skin=M("9ab4c8"), cloth=M("d8e4ec", "fur"), eye="70e0ff", weapon="club",
                               hands=M("7090a8"), troll=True), (14, 4.5)),
    "rime_stalker": (wraith, dict(robe=M("b8d0e0", "fur"), hood=M("d8e8f2", "fur"), eyes="70e8ff",
                                  claws=M("e8f8ff", gloss=0.8)), (10, 3)),
    "glacial_golem": (golem, dict(rock=M("7aa4c4", "stone", spread=1.3), eyes="c0f4ff", core="a0e8ff"), (14, 4.5)),
    "hoarfrost_jarl": (giant, dict(skin=M("a8c4d8"), cloth=M("5a6a80", "fur"), eye="a0f0ff", weapon="hammer",
                                   horn=M("e8f8ff", gloss=0.8), hands=M("7a98b0"), shards=M("c8f0ff", gloss=0.9),
                                   troll=True), (16, 5)),
    "snow_wolf": (quadruped, dict(length=27, height=9.5, girth=6.6, head=4.8, snout=1.05, snout_width=0.42, leg=1.3,
                                  ears="pointed", tail="bushy", body=M("d8e0e6", "fur"), belly=M("f4f8fa", "fur"),
                                  ruff=M("eef2f6", "fur"), chest=1.12, neck=0.9, eye=emissive("8ad0ff"),
                                  paw=M("8a96a0"), nose=M("2a3038")), (12, 3.5)),
    "tusked_walrus": (quadruped, dict(length=28, height=4.5, girth=10, flat=0.8, head=6.4, snout=0.55, snout_width=0.75,
                                      leg=1.2, spread=1.1, stride=1.6, ears="none", tail="short", body=M("7a5a44", "warts"),
                                      belly=M("9a7a62", "warts"), nose=M("4a362a"), tusks=True, chest=1.2, neck=0.2,
                                      eye=emissive("e8c060"), paw=M("4a3a2e")), (16, 5)),
    "trench_crab": (spider, dict(body=M("4a6a80", "chitin", gloss=0.7), abdomen=M("3e5a6e", "chitin", gloss=0.6),
                                 legs=M("34485a", "chitin"), eyes="e0f0ff", pincers=M("5a7a92", "chitin", gloss=0.7),
                                 abdomen_size=0.55), (13, 4)),
    "grimclaw": (spider, dict(body=M("3a5468", "chitin", gloss=0.8), abdomen=M("2e4658", "chitin", gloss=0.7),
                              legs=M("243848", "chitin", gloss=0.5), eyes="ffb0a0", pincers=M("6a8aa0", "chitin", gloss=0.8),
                              marking=M("c8e0f0", gloss=0.6), abdomen_size=0.6, scale=1.08), (15, 4.5)),
    # Orcs (the Grimtusk Hold, tools/generators/orcs.gd): raiders with axes and spears, armoured
    # warriors, bone-staffed shamans, painted berserkers, caped leaders, and their horned warlord.
    "orc": (orc, dict(skin=M("6e8a42", "warts"), armor=M("6a4a2e", "cloth"), hair=M("2a2018", "fur"), weapon="axe"), (9, 3)),
    "orc_spearman": (orc, dict(skin=M("7a8a4a", "warts"), armor=M("7a6040", "fur"), weapon="spear", eyes="e8d060"), (9, 3)),
    "orc_warrior": (orc, dict(skin=M("5e7a3a", "warts"), armor=M("6a6a72", "stone", gloss=0.5), helmet=M("5a5a62", "stone", gloss=0.6),
                              bracers=M("4a3a28", "cloth"), weapon="axe", off="shield", bulk=1.05), (10, 3.5)),
    "orc_shaman": (orc, dict(skin=M("7a9a5a", "warts"), armor=M("5a3a5a", "cloth"), cloth=M("4a2e4a", "cloth"),
                             hair=M("d8ccb0", "bone"), weapon="staff", eyes="80f080"), (9, 3)),
    "orc_berserker": (orc, dict(skin=M("6a8a3a", "warts"), paint=M("b02a20"), hair=M("c84a2a", "fur"), weapon="axe", off="axe",
                                eyes="ff4a2a", bulk=1.1, bracers=M("4a3a28", "cloth")), (10, 3.5)),
    "orc_leader": (orc, dict(skin=M("4e6a32", "warts"), armor=M("4a4a52", "stone", gloss=0.6), helmet=M("4a4a52", "stone", gloss=0.7),
                             pauldrons=M("5a5a62", "stone", gloss=0.7), cape=M("8a2a22", "cloth"), bracers=M("3a3a40", "stone"),
                             weapon="cleaver", off="shield", bulk=1.12), (10, 3.5)),
    "gruzzak": (orc, dict(skin=M("44602c", "warts"), armor=M("3a3a40", "stone", gloss=0.7), helmet=M("2e2e34", "stone", gloss=0.7),
                          horns=BONE, pauldrons=M("6a5a3a", "stone", gloss=0.6), cape=M("6a1e1a", "cloth"),
                          bracers=M("2e2e34", "stone"), weapon="cleaver", eyes="ff3a2a", bulk=1.2), (11, 4)),
    "sylvaine": (wraith, dict(robe=M("5a3a80", "cloth"), hood=M("3a5a3a", "fur"), eyes="f0d0ff", claws=M("5a7a40"),
                              flowers=M("e888c0", gloss=0.3), antlers=M("8a6a48", "bone"), scale=1.05), (11, 3.5)),
}


# On-screen scale per species at monster size 1 (the game scales again by Monsters "size").
ZOOM = {"frostfang_wolf": 1.2, "greymaw": 1.0, "behemoth": 1.05, "cyclops": 1.25, "cyclops_smith": 1.25,
        "field_vole": 1.6, "sewer_rat": 1.35, "giant_rat": 1.2, "rat_king": 1.1, "crypt_skeleton": 1.15,
        "grave_ghoul": 1.15, "abbot_morrow": 1.1, "grey_wolf": 1.2, "thornback_boar": 1.25, "reedfang": 1.0, "cave_crawler": 1.4, "cave_spider": 1.5,
        "venom_weaver": 1.5, "silk_matron": 1.5, "marsh_toad": 1.35, "bog_lurker": 1.35, "stone_golem": 1.6,
        "bog_hulk": 1.6, "ember_golem": 1.6, "forgemaw": 1.4, "kharzul": 1.35, "obsidian_golem": 1.6,
        "cinder_wraith": 1.15, "mire_stalker": 1.15, "void_wraith": 1.15, "sylvaine": 1.1, "ashmaw_drake": 1.0,
        "thornscale_basilisk": 1.0, "rime_titan": 1.2, "barrow_lich": 1.4, "dire_bear": 1.05, "harpy": 1.15,
        "dune_scorpion": 1.4, "stone_troll": 1.25, "cave_troll": 1.2, "ogre_brute": 1.25, "ogre_smasher": 1.2,
        "gorvak": 1.1, "bog_troll": 1.2, "grotto_leech": 1.35, "drowned_abbess": 1.3, "magma_hound": 1.2,
        "cinder_brute": 1.6, "frost_ogre": 1.2, "rime_stalker": 1.15, "glacial_golem": 1.6, "hoarfrost_jarl": 1.1,
        "snow_wolf": 1.2, "tusked_walrus": 1.0, "trench_crab": 1.4, "grimclaw": 1.4, "orc": 1.3, "orc_spearman": 1.3,
        "orc_warrior": 1.3, "orc_shaman": 1.3, "orc_berserker": 1.3, "orc_leader": 1.3, "gruzzak": 1.25}


def frames(kind, direction, frame):
    builder, spec, shadow = SPECIES[kind]
    return render(builder(frame, spec), direction, shadow, ZOOM.get(kind, 1.0))
