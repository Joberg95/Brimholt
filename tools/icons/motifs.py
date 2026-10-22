"""Brimholt's motifs (docs/plan/46, "Flavour pillars"), shared by every item family: what makes an icon
ours rather than a pack archetype. Runes and old stone (carved or glowing glyphs, knotwork), ember
against reed (fire cracks, reed cord), the land that wakes (moss, roots, glowing seams), grey castles
(banner tassels), and the Hollow (violet crystal growths). All drawn bold enough to read at 32 px.
"""
import math

from core import ROUND, piecewise

# Each Brimholt pillar's materials, so families dress their designs alike.
PILLARS = {
    "seax": dict(metal="iron", trim="bronze", grip="bronze", glyph="silver"),
    "barrow": dict(metal="verdigris", trim="verdigris", grip="bone", glyph="glow_rune"),
    "waystone": dict(metal="runestone", trim="runestone", grip="leather", glyph="glow_rune"),
    "ember": dict(metal="emberglass", trim="iron", grip="2a2a32", glyph="glow_ember"),
    "reed": dict(metal="steel", trim="reed", grip="reed", glyph="lakestone"),
    "castle": dict(metal="steel", trim="gold", grip="banner", glyph="gold"),
    "hollow": dict(metal="hollowglass", trim="hollowglass", grip="1a1a22", glyph="glow_hollow"),
    "woken": dict(metal="runestone", trim="wood", grip="wood", glyph="glow_moss"),
}


def noise(i, seed):
    """A repeatable value in [0, 1) for an index and a seed."""
    n = (i * 374761393 + seed * 668265263) & 0xffffffff
    n = (n ^ (n >> 13)) * 1274126177 & 0xffffffff
    return ((n ^ (n >> 16)) & 0xffff) / 65535.0


def _frame(a, b):
    """Unit vectors along a->b and across it (to the left of travel), and the length."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dy) or 1.0
    return (dx / length, dy / length), (dy / length, -dx / length), length


def _point(a, along_v, across_v, along, across):
    return (a[0] + along_v[0] * along + across_v[0] * across, a[1] + along_v[1] * along + across_v[1] * across)


# ----------------------------------------------------------------------------- grip patterns
def wrap(spacing=2, depth=0.3):
    """Leather or cord wrap: dark turns across the grip."""
    return lambda length, u: -depth if int(length) % spacing == 0 else 0.06


def knotwork():
    """Interlace: two strands crossing over and under each other, light where a strand passes over."""
    return lambda length, u: 0.2 if (int(length * 1.4) + (1 if u > 0 else 0)) % 3 == 0 else -0.28


def reed():
    """Reed cord bound tight: thin turns of green and tan."""
    return lambda length, u: -0.3 if int(length * 1.5) % 3 == 0 else 0.12


GRIPS = {"wrap": wrap, "knotwork": knotwork, "reed": reed, "plain": lambda: None}


# ------------------------------------------------------------------------------------ motifs
def seam(icon, a, b, mat, seed, jag=0.9, width=0.5):
    """A glowing crack from a to b, jagged at random."""
    along_v, across_v, length = _frame(a, b)
    points = [a]
    for i in range(1, 7):
        points.append(_point(a, along_v, across_v, length * i / 7, (noise(i, seed) - 0.5) * 2 * jag))
    points.append(b)
    for p, q in zip(points, points[1:]):
        icon.stroke([p, q], lambda s: width, lambda u, *_: 0.95, mat)


# Runes as short strokes in (along, across) pixels: an upright with a branch, a slash, an upright
# with a twig, a zigzag, an arrow.
GLYPHS = [
    [((0, 0), (3.0, 0)), ((0.3, 0), (1.4, 1.3))],
    [((0, -1.2), (3.0, 1.2))],
    [((0, 0), (3.0, 0)), ((1.0, 0), (2.0, -1.3))],
    [((0, -1.0), (1.5, 1.0)), ((1.5, 1.0), (3.0, -1.0))],
    [((0, 0), (3.0, 0)), ((0, 0), (1.2, 1.2)), ((0, 0), (1.2, -1.2))],
]


def runes(icon, a, b, mat, carve=False, start=0):
    """Bold glyphs from a toward b, a little apart: glowing (or inlaid) unless carved dark."""
    along_v, across_v, length = _frame(a, b)
    along, i = 0.0, start
    while along + 3.0 <= length:
        for p, q in GLYPHS[i % len(GLYPHS)]:
            icon.stroke([_point(a, along_v, across_v, along + p[0], p[1] * 0.7),
                         _point(a, along_v, across_v, along + q[0], q[1] * 0.7)],
                        lambda s: 0.5, lambda u, *_: 0.0 if carve else 1.0, mat)
        along += 4.4
        i += 1


def moss(icon, points, seed, size=1.35):
    """Tufts of moss at some of the given points (on top of stone, bark, or bronze)."""
    for k, p in enumerate(points):
        if noise(k, seed) < 0.8:
            icon.ball(p[0], p[1], size, size * 0.9, "moss", glint=False)
            if noise(k, seed + 5) < 0.4:
                icon.put(int(p[0] - 1), int(p[1] - 1), "glow_moss", 0.85)


def crystal(icon, base, tip, mat, width=1.1):
    """A crystal growth from base to tip: two facets, the left one lit, a bright ridge."""
    icon.stroke([base, tip], lambda s: width * (1 - s) + 0.25, piecewise([(-1, 0.95), (-0.1, 0.8), (0.1, 0.45), (1, 0.3)]),
                mat)


def tassel(icon, at, cloth, knot):
    """A banner-cloth tassel hanging from a point, swinging down and to the left, with a knot."""
    icon.stroke([at, (at[0] - 0.8, at[1] + 3.0), (at[0] - 3.4, at[1] + 2.0)], lambda s: 1.0 + s * 1.0,
                piecewise([(-1, 0.3), (0, 0.8), (1, 0.45)]), cloth)
    for k in range(3):
        icon.put(int(at[0] - 3.6 + k * 0.9), int(at[1] + 3.6 - k * 0.6), cloth, 0.25)
    icon.ball(at[0], at[1], 1.15, 1.15, knot)


def root(icon, points, mat="wood", width=1.15):
    """A twisting root along a curve, thinning to its end."""
    icon.stroke(points, lambda s: width * (1 - s) + 0.35, ROUND, mat)


def crack_cells(icon, cells, mat, seed, count=2):
    """Glowing cracks across a set of cells (an axe head, a mace head): short jagged lines between
    cells picked at random."""
    cells = sorted(cells)
    if len(cells) < 6:
        return
    for k in range(count):
        a = cells[int(noise(k, seed) * len(cells))]
        b = cells[int(noise(k, seed + 9) * len(cells))]
        if math.hypot(a[0] - b[0], a[1] - b[1]) < 3:
            continue
        seam(icon, (a[0] + 0.5, a[1] + 0.5), (b[0] + 0.5, b[1] + 0.5), mat, seed + k, jag=0.6, width=0.45)
