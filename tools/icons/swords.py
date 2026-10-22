"""Swords in the OpenTibia pack's proportions and rendering (measured from 115 pack swords; the pack is
reference only), designed from Brimholt's own flavour (docs/plan/46, "Flavour pillars"): runes and old
stone, ember against reed, the land that wakes, grey castles, and the Hollow. Every sword runs corner
to corner on the diagonal; the blade is about two thirds of it and 3-4 px wide, the guard a thin bar,
the grip a 2 px stripe, the pommel a small knob. What makes each one ours is its motif: carved runes,
glowing seams and cracks, moss, knotwork, reed bindings, banner cloth, crystal growths, roots.
"""
import math

from core import ROUND, Icon, at as _at, piecewise as _piecewise

# Cross-sections from the upper-right side (u -1) to the lower-left (u 1).
# A double edge: two flat planes split by a hard bright ridge, a thin lit rim on the near edge.
DOUBLE = _piecewise([(-1, 0.52), (-0.8, 0.26), (-0.06, 0.34), (0.04, 1.0), (0.55, 0.84), (0.82, 0.7), (1, 0.95)])
# A single edge: a thick dark back rising to a bright honed edge.
SINGLE = _piecewise([(-1, 0.18), (-0.7, 0.3), (-0.1, 0.5), (0.45, 0.78), (0.8, 1.0), (1, 0.9)])
# Rough stone: a blunt rounded face, no honed edge.
STONE = _piecewise([(-1, 0.2), (-0.4, 0.45), (0.3, 0.72), (1, 0.4)])


def _noise(i, seed):
    n = (i * 374761393 + seed * 668265263) & 0xffffffff
    n = (n ^ (n >> 13)) * 1274126177 & 0xffffffff
    return ((n ^ (n >> 16)) & 0xffff) / 65535.0


def _width(shape, w, seed=0):
    """Half-width of a blade along it, s 0 at the tip and 1 at the guard."""
    if shape == "point":
        return lambda s: w * min(1.0, 0.3 + s * 4.5)
    if shape == "leaf":
        return lambda s: w * (0.45 + 0.75 * math.sin(math.pi * min(0.92, s) / 0.92 * 0.85) ** 0.6) if s < 0.97 else w * 0.75
    if shape == "seax":  # the broken back: widest a quarter of the way down, then straight to the hilt
        return lambda s: w * (min(1.0, 0.25 + s * 3.2) if s < 0.25 else 1.0 - 0.12 * (s - 0.25))
    if shape == "chipped":  # knapped stone: the edge bitten in at random
        return lambda s: w * min(1.0, 0.35 + s * 3.5) * (1.0 - 0.32 * (_noise(int(s * 16), seed) > 0.55))
    raise ValueError(shape)


def _wrap(spacing=2, depth=0.3):
    """A leather or cord wrap: dark bands across the grip every `spacing` pixels."""
    return lambda length, u: -depth if int(length) % spacing == 0 else 0.06


def _knotwork():
    """Interlace: strands crossing over and under, light where a strand passes over."""
    return lambda length, u: 0.12 if (int(length * 1.4) + (1 if u > 0 else 0)) % 3 == 0 else -0.22


def _reed():
    """Reed cord bound tight: thin green and tan turns."""
    return lambda length, u: (-0.25 if int(length * 1.5) % 3 == 0 else 0.1)


GRIPS = {"wrap": _wrap, "knotwork": _knotwork, "reed": _reed, "plain": lambda: None}


# ------------------------------------------------------------------------------------ motifs
def _seam(icon, start, end, mat, seed, jag=0.9):
    """A glowing crack running from start to end, jagged at random."""
    steps = 7
    points = [start]
    for i in range(1, steps):
        f = i / steps
        base = (start[0] + (end[0] - start[0]) * f, start[1] + (end[1] - start[1]) * f)
        points.append(_at(base, 0, (_noise(i, seed) - 0.5) * 2 * jag))
    points.append(end)
    for a, b in zip(points, points[1:]):
        icon.stroke([a, b], lambda s: 0.42, lambda u, *_: 0.9, mat)


# Runes as a few short strokes in (along, across) pixels; carved into a blade they read as glyphs.
RUNES = [
    [((0, 0), (2.4, 0)), ((0.2, 0), (1.0, 1.0))],             # an upright with a branch
    [((0, -0.9), (2.2, 0.9))],                                 # a slash
    [((0, 0), (2.4, 0)), ((0.8, 0), (1.6, -1.0))],             # an upright with a twig
    [((0, -0.8), (1.2, 0.8)), ((1.2, 0.8), (2.4, -0.8))],      # a zigzag
]


def _runes(icon, tip, start, end, mat, carve=False):
    """Glyphs down the middle of the blade between `start` and `end` pixels from the tip."""
    along, i = start, 0
    while along + 2.4 <= end:
        for a, b in RUNES[i % len(RUNES)]:
            p, q = _at(tip, along + a[0], a[1] * 0.6), _at(tip, along + b[0], b[1] * 0.6)
            if carve:
                icon.stroke([p, q], lambda s: 0.4, lambda u, *_: 0.05, mat)
            else:
                icon.stroke([p, q], lambda s: 0.4, lambda u, *_: 0.95, mat)
        along += 3.6
        i += 1


def _moss(icon, tip, start, end, seed):
    """Tufts of moss over the upper (back) side of a stone blade."""
    for k in range(int((end - start) / 2.2)):
        along = start + k * 2.2 + _noise(k, seed) * 1.2
        if _noise(k, seed + 7) < 0.6:
            icon.ball(*_at(tip, along, 1.0 + _noise(k, seed + 3) * 0.7), 0.95, 0.95, "moss", glint=False)


def _crystals(icon, tip, start, end, mat, seed):
    """Violet crystal growths breaking out of the blade's back."""
    for k in range(3):
        along = start + (end - start) * (0.2 + 0.3 * k) + _noise(k, seed)
        base = _at(tip, along, 1.0)
        icon.stroke([base, _at(base, -1.6, 2.4 + _noise(k, seed + 2))], lambda s: 1.0 * (1 - s) + 0.2,
                    lambda u, *_: 0.55 + 0.4 * (u < 0), mat)


def _tassel(icon, at_point, cloth, knot):
    """A banner-cloth tassel hanging from the pommel, swinging down and to the left."""
    icon.stroke([at_point, (at_point[0] - 1.2, at_point[1] + 2.2), (at_point[0] - 2.6, at_point[1] - 0.2)],
                lambda s: 1.0 + s * 0.6, _piecewise([(-1, 0.3), (0, 0.75), (1, 0.45)]), cloth)
    icon.ball(at_point[0], at_point[1], 0.95, 0.95, knot)


def _roots(icon, at_point, mat):
    """Roots twisting out from the hilt in place of quillons."""
    for side, curl in ((1, 1.0), (-1, -1.0)):
        icon.stroke([at_point, _at(at_point, -0.8, side * 3.2), _at(at_point, -3.4, side * 4.2 + curl)],
                    lambda s: 1.1 * (1 - s) + 0.35, ROUND, mat)


# ------------------------------------------------------------------------------- hilt parts
def _guard(icon, kind, at, mat, span, thick, grip_pattern=None):
    knob = thick + 0.45
    if kind == "cross":
        a, b = _at(at, 0, span), _at(at, 0, -span)
        icon.stroke([a, b], lambda s: thick, ROUND, mat, pattern=grip_pattern)
        for end in (a, b):
            icon.ball(end[0], end[1], knob, knob, mat)
    elif kind == "collar":  # a seax has no cross: a knotwork collar at the blade's root
        icon.stroke([_at(at, -0.9), _at(at, 1.4)], lambda s: 1.55, ROUND, mat, pattern=grip_pattern)
    elif kind == "drooping":
        for side in (1, -1):
            icon.stroke([_at(at, 0.4, 0), _at(at, 0.0, side * span * 0.6), _at(at, -1.8, side * span)],
                        lambda s: thick, ROUND, mat)
            end = _at(at, -1.8, side * span)
            icon.ball(end[0], end[1], knob, knob, mat)
    elif kind == "bar":
        icon.stroke([_at(at, 0, span), _at(at, 0, -span)], lambda s: thick * 1.15, ROUND, mat)


def _pommel(icon, kind, at, mat, size, gem=None):
    if kind == "knob":
        icon.ball(at[0], at[1], size, size, mat)
    elif kind == "gem":
        icon.ball(at[0], at[1], size, size, mat, flat=0.3)
        icon.ball(at[0] - 0.2, at[1] - 0.2, size * 0.6, size * 0.6, gem)
    elif kind == "cap":
        icon.stroke([_at(at, -1.0), _at(at, 1.0)], lambda s: size * (1.0 - s * 0.3), ROUND, mat)


TIP = (1.6, 1.6)
LENGTH = 39.6


def sword(d):
    """Draws one sword design (a dict, see DESIGNS) and returns the Icon."""
    icon = Icon()
    seed = d.get("seed", 1)
    blade = LENGTH * d.get("guard_at", 0.66)
    guard = _at(TIP, blade)
    pommel = _at(TIP, LENGTH - d.get("pommel_size", 1.3))
    grip = GRIPS[d.get("wrap", "wrap")]()
    icon.stroke([guard, pommel], lambda s: d.get("grip_width", 0.95), ROUND, d["grip_mat"], pattern=grip)
    _pommel(icon, d["pommel"], pommel, d["pommel_mat"], d.get("pommel_size", 1.3), d.get("gem"))
    if d.get("tassel"):
        _tassel(icon, _at(pommel, 0.4), d["tassel"], d["pommel_mat"])
    edge = {"single": SINGLE, "stone": STONE}.get(d.get("edge"), DOUBLE)
    icon.stroke([TIP, guard], _width(d["shape"], d["width"], seed), edge, d["blade_mat"], shine=0.5)
    if d.get("moss"):
        _moss(icon, TIP, blade * 0.25, blade - 1.5, seed)
    if d.get("crystals"):
        _crystals(icon, TIP, blade * 0.2, blade - 2.0, d["crystals"], seed)
    if d.get("seam"):
        _seam(icon, _at(TIP, blade * 0.18), _at(TIP, blade - 1.0), d["seam"], seed)
    if d.get("cracks"):
        for k in range(2):
            start = blade * (0.25 + 0.35 * k)
            _seam(icon, _at(TIP, start, 0.8), _at(TIP, start + 5.0, -0.9), d["cracks"], seed + k, jag=0.5)
    if d.get("runes"):
        _runes(icon, TIP, blade * 0.3, blade - 2.0, d["runes"], carve=d.get("carved", False))
    if d.get("roots"):
        _roots(icon, guard, d["roots"])
    else:
        _guard(icon, d["guard"], guard, d["guard_mat"], d.get("guard_span", 5.0), d.get("guard_thick", 0.95),
               grip if d.get("wrap") == "knotwork" else None)
    return icon


# Each sword is drawn from one of Brimholt's flavour pillars, so it is ours and not a pack archetype.
DESIGNS = {
    # Runes and old stone: a borderland seax, broken-backed and single-edged, carved with runes, a knotwork
    # collar and grip, a capped pommel. No cross, as a seax has none.
    "seax": dict(shape="seax", width=1.8, edge="single", blade_mat="iron", runes="darksteel", carved=True,
                 guard="collar", guard_mat="bronze", grip_mat="bronze", wrap="knotwork", pommel="cap",
                 pommel_mat="bronze", pommel_size=1.4),
    # Runes and old stone: a barrow blade, green-crusted bog bronze dug from a mound, faint glowing runes,
    # a bone grip, a ball pommel.
    "barrow_blade": dict(shape="leaf", width=1.75, blade_mat="verdigris", runes="glow_rune", guard="cross",
                         guard_mat="verdigris", grip_mat="bone", pommel="knob", pommel_mat="verdigris", seed=3),
    # Runes and old stone: a waystone blade, knapped from a waystone, a glowing rune seam down its middle,
    # a leather-bound grip.
    "waystone_blade": dict(shape="chipped", width=1.95, edge="stone", blade_mat="runestone", seam="glow_rune",
                           guard="bar", guard_mat="runestone", guard_span=4.2, grip_mat="leather",
                           pommel="knob", pommel_mat="runestone", pommel_size=1.6, seed=5),
    # Ember: an ember-glass blade, dark red glass cracked through with fire, an iron cross.
    "ember_glass": dict(shape="point", width=1.7, blade_mat="emberglass", cracks="glow_ember", guard="cross",
                        guard_mat="iron", grip_mat="2a2a32", pommel="gem", pommel_mat="iron", gem="glow_ember", seed=2),
    # Reed: a lake sword, slim steel, its hilt bound in reed cord, a lake-blue stone pommel.
    "reed_sword": dict(shape="point", width=1.45, blade_mat="steel", guard="drooping", guard_mat="reed",
                       guard_span=4.6, grip_mat="reed", wrap="reed", pommel="gem", pommel_mat="reed",
                       gem="lakestone", pommel_size=1.5),
    # Grey castles: a castle guard's sword, plain grey steel, a gold cross, and a banner-cloth tassel.
    "castle_sword": dict(shape="point", width=1.65, blade_mat="steel", runes=None, guard="cross", guard_mat="gold",
                         grip_mat="banner", pommel="knob", pommel_mat="gold", tassel="banner"),
    # The Hollow: an obsidian blade with violet crystal breaking out of its back and a glowing seam.
    "hollow_blade": dict(shape="point", width=1.6, blade_mat="hollowglass", crystals="glow_hollow",
                         seam="glow_hollow", guard="bar", guard_mat="hollowglass", guard_span=4.4,
                         grip_mat="1a1a22", pommel="gem", pommel_mat="hollowglass", gem="glow_hollow", seed=4),
    # The land that wakes: a stone blade grown over with moss, green light in its cracks, roots for a guard.
    "woken_stone": dict(shape="chipped", width=1.85, edge="stone", blade_mat="runestone", moss=True,
                        cracks="glow_moss", roots="wood", grip_mat="wood", wrap="plain", pommel="knob",
                        pommel_mat="moss", pommel_size=1.5, seed=7),
}


def icon(name):
    return sword(DESIGNS[name]).render()
