"""Showpiece gear icons modelled in 3D, after the props (props.py): boxes, cylinders, ellipsoids,
and tubes of them for horns, seen from in front and a little above, lit from the top-left,
posterized into five-tone ramps per material with gloss on metal and gems, glowing eyes and
flames, a dark edge round the silhouette, and dark seams where a nearer part overlaps.

make_sprites.py calls icon(kind, look, colors, frame) for the helmets in HELM_STYLES; frame
(0..ANIM_FRAMES-1) moves flames, halos, and eyes. World units are icon pixels: x to the right,
y away from the viewer, z up; the helmet's front faces the viewer (-y).
"""

import math

import creatures as C
import props as P
from creatures import Material, emissive, add, sub, mul, dot, norm, basis

TILT = math.radians(22)
UP = (0.0, math.sin(TILT), math.cos(TILT))
VIEW = (0.0, math.cos(TILT), -math.sin(TILT))
LIGHT = norm((-0.62, -0.5, 0.62))
HALF = norm(sub(LIGHT, VIEW))
SIZE = 32
ORIGIN = (16, 27)
ANIM_FRAMES = 12
OUTLINE = (24, 20, 22)

VOID = Material("1c1418")
IVORY = C.IVORY
GOLD = Material("d8aa3c", gloss=0.9)
DARK_GOLD = Material("a8782a", gloss=0.7)
STEEL = Material("aab4bc", gloss=1.0)
IRON = Material("5e6268", gloss=0.6)
BRASS = Material("b88a3a", gloss=0.8)
FLAME = emissive("ffa83a")
FLAME_CORE = emissive("fff0a0")


def _hex(value):
    return "%02x%02x%02x" % value


def tube(points, r0, r1, material, group=None):
    """Cylinders through `points` tapering from radius r0 to r1, with a ball at every joint."""
    parts = []
    count = len(points) - 1
    for index, (a, b) in enumerate(zip(points, points[1:])):
        r = r0 + (r1 - r0) * index / max(1, count)
        axis = sub(b, a)
        parts.append({"kind": "cyl", "c": a, "r": r, "len": math.sqrt(dot(axis, axis)), "R": basis(norm(axis)),
                      "m": material, "g": group, "grain": 1})
        parts.append(P.ell(b, (r * 0.95,) * 3, material, group=group))
    return parts


def spike(base, tip, radius, material, group=None):
    """A tapering spike from base to tip (a stack of shrinking cylinders)."""
    steps = 4
    points = [add(base, mul(sub(tip, base), i / steps)) for i in range(steps + 1)]
    return tube(points, radius, radius * 0.25, material, group)


def render(parts):
    """Rows of RGBA or None: the parts seen by the icon camera."""
    gx, gy = ORIGIN
    hits = [[None] * SIZE for _ in range(SIZE)]
    for py in range(SIZE):
        su = gy - (py + 0.5)
        for px in range(SIZE):
            sx = px + 0.5 - gx
            start = (sx, su * UP[1] - 80 * VIEW[1], su * UP[2] - 80 * VIEW[2])
            for index, part in enumerate(parts):
                found = P._hit(part, start, VIEW)
                if found is not None and found[0] > 0 and (hits[py][px] is None or found[0] < hits[py][px][0]):
                    point = add(start, mul(VIEW, found[0]))
                    group = part["g"] if part["g"] is not None else index
                    hits[py][px] = (found[0], found[1], found[2], part, group, point)
    pixels = [[None] * SIZE for _ in range(SIZE)]
    for y in range(SIZE):
        for x in range(SIZE):
            hit = hits[y][x]
            if hit is None:
                continue
            _, n, q, part, _, p = hit
            material = part["m"]
            if material.pattern == "emissive":
                lit = 0.5 + 0.5 * max(0.0, -dot(n, VIEW))
                pixels[y][x] = C._shift(material.glow, 0.22 * lit - 0.08, 0.02, 0.0) + (255,)
                continue
            value = 0.3 + 0.75 * max(0.0, dot(n, LIGHT))
            change, override = P._surface(material, q, n, p, part["grain"])
            if override is not None:
                pixels[y][x] = override + (255,)
                continue
            value += change
            band = 0 if value > 0.88 else 1 if value > 0.68 else 2 if value > 0.48 else 3 if value > 0.32 else 4
            color = material.ramp[band]
            if material.gloss and max(0.0, dot(n, HALF)) ** 20 * material.gloss > 0.35:
                color = tuple(round(c + (255 - c) * 0.7) for c in material.ramp[0])
            pixels[y][x] = color + (255,)
    result = [row[:] for row in pixels]
    for y in range(SIZE):
        for x in range(SIZE):
            hit = hits[y][x]
            if hit is None:
                continue
            group = hit[4]
            emitting = hit[3]["m"].pattern == "emissive"
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                other = hits[ny][nx] if 0 <= nx < SIZE and 0 <= ny < SIZE else None
                if other is None and not emitting:
                    result[y][x] = OUTLINE + (255,)
                    break
                if other is not None and other[4] != group and other[0] < hit[0] - 1.4 and not emitting:
                    result[y][x] = hit[3]["m"].ramp[4] + (255,)
                    break
    # An outline outside the glowing parts too, so flames and halos sit on any background.
    for y in range(SIZE):
        for x in range(SIZE):
            if result[y][x] is None and any(
                    0 <= x + dx < SIZE and 0 <= y + dy < SIZE and hits[y + dy][x + dx] is not None
                    and hits[y + dy][x + dx][3]["m"].pattern == "emissive"
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                result[y][x] = (90, 30, 10, 255) if any(
                    0 <= x + dx < SIZE and 0 <= y + dy < SIZE and hits[y + dy][x + dx] is not None
                    and str(hits[y + dy][x + dx][4]).startswith("flame")
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))) else None
    return result


def _flicker(frame, seed=0):
    return math.sin((frame + seed * 3.7) * math.tau / ANIM_FRAMES * 2) * 0.5 + 0.5


def _flame(base, height, frame, seed=0):
    sway = math.sin((frame + seed * 4) * math.tau / ANIM_FRAMES) * 0.8
    tall = height * (0.85 + 0.3 * _flicker(frame, seed))
    x, y, z = base
    return [P.ell((x + sway * 0.4, y, z + tall * 0.45), (1.9, 1.5, tall * 0.5), FLAME, group="flame%d" % seed),
            P.ell((x + sway * 0.2, y - 0.6, z + tall * 0.3), (1.0, 1.0, tall * 0.32), FLAME_CORE, group="flame%d" % seed)]


def _eyes(material_hex, frame, positions, size=(1.3, 0.6, 0.9)):
    glow = 0.5 + 0.5 * math.cos(frame * math.tau / ANIM_FRAMES)
    color = C._shift(C._hex(material_hex), 0.05 + 0.18 * glow, 0.02, 0.0)
    eye = emissive(_hex(color))
    return [P.ell(p, size, eye, group="eyes") for p in positions]


def _mirror(parts_of_side):
    return parts_of_side(1) + parts_of_side(-1)


def model(style, extras, main, light, accent, frame):
    shell = Material(main, gloss=0.75 if style in ("hornhelm", "crownhelm", "visor") else 0.3)
    trim = Material(light, gloss=0.6)
    gem = Material(accent, gloss=1.0)
    parts = []
    if style == "lanternhelm":
        leather = Material(main, "cloth")
        parts += [P.ell((0, 1, 6), (10, 9.5, 10), leather, group="dome"),
                  P.cyl((0, 1, 1.6), 12.5, 1.6, Material(light), group="brim"),
                  P.ell((0, 1, 7.5), (10.3, 9.8, 1.0), BRASS, group="band")]
        parts += [P.box((0, -5.5, 14.5), (3.2, 2.2, 2.8), BRASS, group="lamp"),
                  P.box((0, -7.8, 14.5), (2.2, 0.3, 2.0), emissive("ffd060"), group="glass"),
                  P.box((0, -5.5, 17.6), (3.6, 2.6, 0.6), BRASS, group="lamp")]
        parts += _flame((0, -5.5, 18.2), 6.0, frame)
    elif style == "crownhelm":
        parts += [P.ell((0, 0, 8), (9.5, 9, 10.5), shell, group="dome"),
                  P.box((0, -8.6, 5.5), (5.2, 1.2, 2.6), VOID, group="face"),
                  P.box((0, -9.6, 6.5), (1.0, 0.6, 4.2), shell, group="nose"),
                  P.cyl((0, 0, 9.5), 10.2, 3.2, GOLD, group="crown")]
        for angle in range(-170, 10, 40):
            a = math.radians(angle)
            x, y = 9.6 * math.cos(a), 9.6 * math.sin(a)
            tall = 6.5 if angle == -90 else 5.0 if angle in (-130, -50) else 4.0
            parts += spike((x, y, 12.5), (x * 1.04, y * 1.04, 12.5 + tall), 1.4, GOLD, group="points")
            parts.append(P.ell((x * 1.04, y * 1.04, 13.5 + tall), (0.9, 0.9, 0.9), GOLD, group="points"))
        for angle in (-130, -90, -50):
            a = math.radians(angle)
            parts.append(P.ell((10.6 * math.cos(a), 10.6 * math.sin(a), 11.1), (1.3, 0.8, 1.2), gem, group="gems"))
    elif style == "cobra":
        scales = Material(main, "scales")
        parts += [P.ell((0, 2, 9), (8.5, 7, 11), scales, group="hood")]
        parts += _mirror(lambda s: [P.ell((s * 8, 2.5, 10.5), (5.5, 3.5, 9.5), scales, P.turn_y(s * 0.25), group="flare%d" % s)])
        parts += [P.ell((0, -4.6, 6.0), (4.6, 2.6, 6.0), VOID, group="face")]
        parts += _mirror(lambda s: [P.ell((s * 8.6, -1.4, 12), (1.6, 0.6, 1.8), gem, group="marks")])
        parts += tube([(0, 4, 18), (0, 1, 22), (0, -3, 23.5)], 2.8, 2.6, scales, group="neck")
        parts += [P.ell((0, -5.4, 23.4), (4.0, 4.4, 2.8), scales, group="head")]
        parts += _eyes(accent, frame, [(-2.3, -8.4, 24.4), (2.3, -8.4, 24.4)], (0.9, 0.5, 0.8))
        parts += _eyes(accent, frame, [(-1.8, -7.0, 7.4), (1.8, -7.0, 7.4)], (0.9, 0.4, 0.7))
        if frame % 6 < 3:
            parts.append(P.box((0, -10.6, 22.6), (0.4, 1.6, 0.3), emissive("d03a3a"), group="tongue"))
    elif style == "hornhelm":
        parts += [P.ell((0, 0, 9), (9.5, 9, 10.5), shell, group="dome"),
                  P.box((0, -8.4, 9), (6.4, 1.6, 1.2), VOID, group="visor"),
                  P.box((0, -8.4, 5), (1.4, 1.6, 3.0), VOID, group="visor"),
                  P.box((0, -9.3, 13.5), (1.2, 0.8, 5.5), Material(light, gloss=0.9), group="ridge"),
                  P.ell((0, -9.6, 14.5), (1.4, 0.8, 1.4), gem, group="gem")]
        parts += _mirror(lambda s: [P.box((s * 6.2, -7.6, 3.2), (2.4, 1.6, 2.6), shell, group="cheek%d" % s)])
        parts += _mirror(lambda s: tube([(s * 8, 0, 13), (s * 12, -1, 15), (s * 14.5, -1.5, 19), (s * 14.5, -1, 24),
                                         (s * 13, 0, 27)], 2.2, 0.6, IVORY, group="horn%d" % s))
    elif style == "fangmask":
        skin = Material(main, gloss=0.25)
        dark = Material(_hex(C._shift(C._hex(main), -0.14, 0, 0)), gloss=0.2)
        parts += [P.ell((0, 0, 10), (9.5, 7.5, 10.5), skin, group="head"),
                  P.ell((0, -6.0, 7.5), (7.8, 3.2, 6.5), skin, group="face")]
        parts += _mirror(lambda s: [P.ell((s * 3.6, -8.2, 13.2), (3.6, 1.2, 1.0), dark, P.turn_y(s * 0.35), group="brow%d" % s)])
        parts += _eyes(accent, frame, [(-3.4, -9.4, 10.2), (3.4, -9.4, 10.2)], (1.9, 0.7, 1.1))
        parts += [P.ell((0, -9.2, 8.2), (1.4, 0.6, 1.0), dark, group="nose"),
                  P.box((0, -8.4, 4.0), (5.6, 1.6, 2.2), VOID, group="mouth")]
        for x, tall in ((-4.4, 3.0), (-1.5, 2.0), (1.5, 2.0), (4.4, 3.0)):
            parts += spike((x, -9.7, 6.4), (x * 0.95, -10.0, 6.4 - tall), 0.9, IVORY, group="teeth")
        for x in (-3, 0, 3):
            parts += spike((x, -9.7, 1.9), (x, -10.0, 3.8), 0.8, IVORY, group="teeth")
        parts += _mirror(lambda s: tube([(s * 6, 0, 17), (s * 9, -1, 20), (s * 12.5, -1, 21), (s * 14.5, -2, 24),
                                         (s * 14, -3, 28)], 2.2, 0.6, IVORY, group="horn%d" % s))
    elif style == "dreadmask":
        iron = Material(main, gloss=0.55)
        dark = Material(_hex(C._shift(C._hex(main), -0.1, 0, 0)), gloss=0.4)
        parts += [P.ell((0, 0, 8), (8.5, 7.5, 9), iron, group="head"),
                  P.ell((0, -5.8, 6.5), (7.0, 2.6, 5.5), iron, group="face")]
        parts += _mirror(lambda s: [P.ell((s * 3.4, -8.0, 9.4), (3.6, 1.4, 0.9), dark, P.turn_y(-s * 0.45), group="brow%d" % s)])
        for x in (-3, -1, 1, 3):
            parts.append(P.box((x, -8.0, 3.4), (0.5, 1.0, 2.2), VOID, group="grille"))
        parts += _eyes(accent, frame, [(-3.2, -8.6, 7.8), (3.2, -8.6, 7.8)], (1.8, 0.5, 0.6))
        for index, angle in enumerate((-160, -125, -90, -55, -20)):
            a = math.radians(angle)
            base = (6 * math.cos(a), 6 * math.sin(a) + 2, 13)
            tall = 10 if angle == -90 else 8.5 if angle in (-125, -55) else 7
            tip = (base[0] * 2.0, base[1] * 1.2 - 1, 13 + tall)
            parts += spike(base, tip, 2.0, iron, group="spike%d" % index)
            if index in (1, 2, 3):
                parts += _flame(add(tip, (0, -0.3, 0.3)), 4.5, frame, index)
    elif style == "visor":
        parts += [P.ell((0, 0, 9), (9.5, 9, 10.5), shell, group="dome"),
                  P.box((0, -8.6, 8.6), (6.0, 1.4, 0.7), VOID, group="slits"),
                  P.box((0, -8.4, 6.6), (5.0, 1.4, 0.6), VOID, group="slits"),
                  P.box((0, -9.4, 4), (1.2, 0.8, 2.4), trim, group="chin"),
                  P.box((0, -1, 20), (1.8, 6.0, 4.5), Material(accent, gloss=0.8), group="fin"),
                  P.ell((0, -9.6, 12.2), (1.6, 0.8, 1.5), gem, group="gem")]
        parts += _mirror(lambda s: [P.ell((s * 11, -1, 12), (4.0, 1.2, 1.8), trim, P.turn_y(-s * 0.5), group="wing%d" % s)])
    elif style == "nimbus":
        cloth = Material(main, "cloth")
        parts.append(P.cyl((0, 0, 0.5), 13, 1.8, cloth, group="brim"))
        for step in range(14):
            r = 7.5 * (1 - step / 14) + 0.6
            lean = (step / 14) ** 2 * 4
            parts.append(P.cyl((-lean, lean * 0.3, 2.3 + step * 1.6), r, 1.7, cloth, group="cone"))
        parts.append(P.cyl((0, 0, 2.3), 7.8, 2.0, Material(accent, gloss=0.7), group="band"))
        sparkle = frame * math.tau / ANIM_FRAMES
        for index in range(28):
            a = index * math.tau / 28
            near = math.cos(a - sparkle)
            color = "ffffff" if near > 0.93 else _hex(C._shift(C._hex(accent), 0.18, 0, 0)) if near > 0.5 else accent
            parts.append(P.ell((12.5 * math.cos(a), 12.5 * math.sin(a), 10.5), (0.9, 0.9, 0.7), emissive(color),
                               group="halo"))
    return parts


def icon(kind, look, colors, frame=0):
    """RGBA rows of a 32x32 icon for a showpiece helmet."""
    style, *extras = look.split("+")
    main, light, accent = colors
    return render(model(style, set(extras), main, light, accent, frame))
