"""Swords in the OpenTibia pack's proportions and rendering (measured from 115 pack swords; the pack is
reference only), designed from Brimholt's flavour pillars (motifs.py). Every sword runs corner to
corner on the diagonal; the blade is about two thirds of it and 3-4 px wide, the guard a thin bar, the
grip a 2 px stripe, the pommel a small knob. What makes each one ours is its pillar: carved runes,
knotwork, glowing seams and cracks, moss and roots, reed cord, banner cloth, Hollow crystal.
"""
import math

import motifs
from core import ROUND, Icon, at, local, piecewise

# Cross-sections from the upper-right side (u -1) to the lower-left (u 1).
# A double edge: two flat planes split by a hard bright ridge, a thin lit rim on the near edge.
DOUBLE = piecewise([(-1, 0.52), (-0.8, 0.26), (-0.06, 0.34), (0.04, 1.0), (0.55, 0.84), (0.82, 0.7), (1, 0.95)])
# A single edge: a thick dark back rising to a bright honed edge.
SINGLE = piecewise([(-1, 0.18), (-0.7, 0.3), (-0.1, 0.5), (0.45, 0.78), (0.8, 1.0), (1, 0.9)])
# Rough stone: a blunt rounded face, no honed edge.
STONE = piecewise([(-1, 0.2), (-0.4, 0.45), (0.3, 0.72), (1, 0.4)])
EDGES = {"double": DOUBLE, "single": SINGLE, "stone": STONE}


def _width(shape, w, seed=0):
    """Half-width of a blade along it, s 0 at the tip and 1 at the guard: like the pack's, narrow at the
    point and widening toward the hilt."""
    taper = lambda s: 0.55 + 0.45 * s
    if shape == "point":
        return lambda s: w * taper(s) * min(1.0, 0.3 + s * 5)
    if shape == "leaf":
        return lambda s: w * (0.5 + 0.7 * math.sin(math.pi * min(0.92, s) / 0.92 * 0.85) ** 0.6) if s < 0.97 else w * 0.85
    if shape == "seax":  # the broken back: widest a quarter of the way down, then straight to the hilt
        return lambda s: w * (min(1.0, 0.25 + s * 3.2) if s < 0.25 else 1.0 - 0.08 * (s - 0.25))
    if shape == "chipped":  # knapped stone: the edge bitten in at random
        return lambda s: w * taper(s) * min(1.0, 0.35 + s * 4) * (1.0 - 0.3 * (motifs.noise(int(s * 16), seed) > 0.55))
    raise ValueError(shape)


# ------------------------------------------------------------------------------- the guards
GUARD_SCALE = 1.3


def _g(c, along, across=0.0):
    """at() for guard parts, scaled up so guards are as big as the pack's."""
    return at(c, along * GUARD_SCALE, across * GUARD_SCALE)


# Big and ornate like the pack's (about three blade widths across), each built from its pillar's motif.
def _knot_collar(icon, c, d):
    """Runes: a broad knotwork collar with two langets running up the blade."""
    for side in (1, -1):
        icon.stroke([_g(c, 0.4, side * 1.9), _g(c, -3.6, side * 1.5)], lambda s: 0.75 * (1 - s) + 0.35, ROUND,
                    d["guard_mat"])
    icon.stroke([_g(c, -1.4), _g(c, 2.0)], lambda s: 2.2, ROUND, d["guard_mat"], pattern=motifs.knotwork())
    icon.stroke([_g(c, 0, 3.0), _g(c, 0, -3.0)], lambda s: 1.0, ROUND, d["guard_mat"])


def _horns(icon, c, d):
    """Barrow: two bronze horns sweeping toward the point, a ring and a stone at the root."""
    for side in (1, -1):
        icon.stroke([c, _g(c, 0.4, side * 4.4), _g(c, -4.2, side * 6.6)], lambda s: 1.9 * (1 - s) + 0.35, ROUND,
                    d["guard_mat"])
    icon.ball(c[0], c[1], 2.0, 2.0, d["guard_mat"])
    icon.ball(c[0] - 0.2, c[1] - 0.2, 1.1, 1.1, d.get("guard_gem", "gold"))


def _block(icon, c, d):
    """Waystone: a carved stone block across the blade with a glowing rune."""
    cells = local(c, lambda t, v: abs(t) <= 1.9 and abs(v) <= 6.0 - abs(t) * 0.6)
    icon.dome(cells, d["guard_mat"], height=1.6)
    icon.shade(local(c, lambda t, v: abs(t) <= 1.9 and abs(abs(v) - 3.2) < 0.5), -0.3)
    motifs.runes(icon, _g(c, -0.9, 0.6), _g(c, 2.3, 0.6), d.get("glyph", "glow_rune"))


def _flames(icon, c, d):
    """Ember: wings of flame sweeping up from the hilt, glowing at their hearts."""
    for side in (1, -1):
        for reach, rise in ((6.4, 4.0), (4.6, 5.6)):
            path = [c, _g(c, -0.6, side * reach * 0.55), _g(c, -rise, side * reach)]
            icon.stroke(path, lambda s: 1.6 * (1 - s) + 0.3, ROUND, d["guard_mat"])
            icon.stroke(path[:2], lambda s: 0.5, lambda u, *_: 0.95, "glow_ember")
    icon.ball(c[0], c[1], 1.8, 1.8, d["guard_mat"])


def _reeds(icon, c, d):
    """Reed: a bundle of reeds bound across the blade, a lake stone set at the crossing."""
    for offset in (-1.1, 0.0, 1.1):
        icon.stroke([_g(c, offset, 6.6), _g(c, offset, -6.6)], lambda s: 0.6, ROUND, d["guard_mat"])
    for across in (5.4, -5.4):
        icon.stroke([_g(c, -1.6, across), _g(c, 1.6, across)], lambda s: 0.55, lambda u, *_: 0.15, "leather")
    icon.ball(c[0], c[1], 1.9, 1.9, "lakestone")


def _heraldic(icon, c, d):
    """Grey castles: a cross with trefoil ends and a shield boss in the middle."""
    for side in (1, -1):
        end = _g(c, 0, side * 6.0)
        icon.stroke([c, end], lambda s: 1.25, ROUND, d["guard_mat"])
        for along, across in ((0, side * 1.2), (-1.1, 0), (1.1, 0)):
            icon.ball(*_g(end, along, across), 1.05, 1.05, d["guard_mat"])
    shield = local(_g(c, -0.4), lambda t, v: -2.4 <= t <= 2.2 and abs(v) <= 2.2 - max(0.0, t) * 0.75)
    icon.dome(shield, d["guard_mat"], height=1.8)
    icon.dome(local(_g(c, -0.4), lambda t, v: -1.4 <= t <= 1.2 and abs(v) <= 1.1 - max(0.0, t) * 0.6), "banner",
              height=1.0)


def _crystal_guard(icon, c, d):
    """The Hollow: a cluster of violet crystals bursting out round the hilt."""
    for along, across in ((-3.0, 6.2), (-1.2, 4.8), (-3.6, -6.0), (-1.0, -4.6), (0.4, 6.4), (0.6, -6.6)):
        motifs.crystal(icon, c, _g(c, along, across), d.get("crystal_mat", "glow_hollow"), width=1.5)
    icon.ball(c[0], c[1], 1.7, 1.7, d["guard_mat"])


def _roots(icon, c, d):
    """The land that wakes: roots twisting out from the hilt, leaves at their ends."""
    for side, curl in ((1, 1.2), (-1, -1.2)):
        end = _g(c, -4.0, side * 5.0 + curl)
        motifs.root(icon, [c, _g(c, -0.6, side * 3.8), end], d["guard_mat"], width=1.6)
        icon.ball(*_g(end, -0.6, side * 0.8), 1.3, 0.9, "moss")
    icon.ball(c[0], c[1], 1.5, 1.5, d["guard_mat"])


GUARDS = {"knot_collar": _knot_collar, "horns": _horns, "block": _block, "flames": _flames, "reeds": _reeds,
          "heraldic": _heraldic, "crystals": _crystal_guard, "roots": _roots}


def _pommel(icon, kind, c, mat, size, gem=None):
    if kind == "knob":
        icon.ball(c[0], c[1], size, size, mat)
    elif kind == "gem":
        icon.ball(c[0], c[1], size, size, mat, flat=0.3)
        icon.ball(c[0] - 0.25, c[1] - 0.25, size * 0.62, size * 0.62, gem)
    elif kind == "cap":
        icon.stroke([at(c, -1.2), at(c, 1.0)], lambda s: size * (1.0 - s * 0.3), ROUND, mat, pattern=motifs.knotwork())


TIP = (1.6, 1.6)
LENGTH = 39.6


def sword(d):
    """Draws one sword design (a dict, see DESIGNS) and returns the Icon."""
    icon = Icon()
    seed = d.get("seed", 1)
    blade = LENGTH * d.get("guard_at", 0.66)
    guard = at(TIP, blade)
    pommel = at(TIP, LENGTH - d.get("pommel_size", 1.3))
    grip = motifs.GRIPS[d.get("wrap", "wrap")]()
    icon.stroke([guard, pommel], lambda s: d.get("grip_width", 0.95), ROUND, d["grip_mat"], pattern=grip)
    _pommel(icon, d["pommel"], pommel, d["pommel_mat"], d.get("pommel_size", 1.3), d.get("gem"))
    if d.get("tassel"):
        motifs.tassel(icon, at(pommel, 0.6), d["tassel"], d["pommel_mat"])
    icon.stroke([TIP, guard], _width(d["shape"], d["width"], seed), EDGES[d.get("edge", "double")], d["blade_mat"],
                shine=0.5)
    if d.get("moss"):
        motifs.moss(icon, [at(TIP, blade * 0.22 + k * 2.4, 1.1) for k in range(int(blade * 0.7 / 2.4))], seed)
    if d.get("crystals"):
        for k in range(3):
            base = at(TIP, blade * (0.25 + 0.25 * k), 1.0)
            motifs.crystal(icon, base, at(base, -1.8, 3.0 + motifs.noise(k, seed)), d["crystals"])
    if d.get("seam"):
        motifs.seam(icon, at(TIP, blade * 0.18), at(TIP, blade - 1.0), d["seam"], seed)
    if d.get("cracks"):
        for k in range(2):
            start = blade * (0.22 + 0.36 * k)
            motifs.seam(icon, at(TIP, start, 0.9), at(TIP, start + 6.0, -1.0), d["cracks"], seed + k, jag=0.6)
    if d.get("runes"):
        # A dark channel cut down the blade, the glyphs set in it, so they never melt into the ridge.
        icon.stroke([at(TIP, blade * 0.24), at(TIP, blade - 0.8)], lambda s: 1.15, lambda u, *_: 0.06, d["blade_mat"])
        motifs.runes(icon, at(TIP, blade * 0.28), at(TIP, blade - 1.2), d["runes"])
    GUARDS[d["guard"]](icon, guard, d)
    return icon


# Each sword is drawn from one of Brimholt's flavour pillars, so it is ours and not a pack archetype.
DESIGNS = {
    # Runes and old stone: a borderland seax, broken-backed and single-edged, silver runes in a channel, a
    # broad knotwork collar with langets in place of a cross, a knotwork grip and cap.
    "seax": dict(shape="seax", width=2.3, edge="single", blade_mat="iron", runes="silver", guard="knot_collar",
                 guard_mat="bronze", grip_mat="bronze", wrap="knotwork", pommel="cap", pommel_mat="bronze",
                 pommel_size=2.2),
    # Runes and old stone: a barrow blade of green-crusted bog bronze, gold runes, bronze horns for a guard
    # with a gold stone, a bone grip, a heavy knob.
    "barrow_blade": dict(shape="leaf", width=2.3, blade_mat="verdigris", runes="gold", guard="horns",
                         guard_mat="verdigris", guard_gem="gold", grip_mat="bone", pommel="knob",
                         pommel_mat="verdigris", pommel_size=2.2, seed=3),
    # Runes and old stone: a waystone blade, knapped stone with a glowing rune seam, a carved stone block
    # for a guard, a leather grip, a stone knob.
    "waystone_blade": dict(shape="chipped", width=2.5, edge="stone", blade_mat="runestone", seam="glow_rune",
                           guard="block", guard_mat="runestone", grip_mat="leather", pommel="knob",
                           pommel_mat="runestone", pommel_size=2.3, seed=5),
    # Ember: ember glass cracked through with fire, wings of flame for a guard, a glowing pommel stone.
    "ember_glass": dict(shape="point", width=2.3, blade_mat="emberglass", cracks="glow_ember", guard="flames",
                        guard_mat="emberglass", grip_mat="2a2a32", pommel="gem", pommel_mat="iron", gem="glow_ember",
                        pommel_size=2.1, seed=2),
    # Reed: a lake sword, steel, a bundle of bound reeds for a guard with a lake stone, a reed-cord grip.
    "reed_sword": dict(shape="point", width=2.1, blade_mat="steel", guard="reeds", guard_mat="reed",
                       grip_mat="reed", wrap="reed", pommel="gem", pommel_mat="reed", gem="lakestone", pommel_size=2.1),
    # Grey castles: a castle sword, grey steel, a gold heraldic cross with a shield boss, a banner-cloth
    # grip and tassel.
    "castle_sword": dict(shape="point", width=2.3, blade_mat="steel", guard="heraldic", guard_mat="gold",
                         grip_mat="banner", pommel="knob", pommel_mat="gold", pommel_size=2.0, tassel="banner"),
    # The Hollow: an obsidian blade with violet crystals on its back, a burst of crystals for a guard.
    "hollow_blade": dict(shape="point", width=2.2, blade_mat="hollowglass", crystals="glow_hollow",
                         seam="glow_hollow", guard="crystals", guard_mat="hollowglass", grip_mat="1a1a22",
                         pommel="gem", pommel_mat="hollowglass", gem="glow_hollow", pommel_size=2.1, seed=4),
    # The land that wakes: a mossy stone blade with green light in its cracks, roots and leaves for a guard.
    "woken_stone": dict(shape="chipped", width=2.4, edge="stone", blade_mat="runestone", moss=True,
                        cracks="glow_moss", guard="roots", guard_mat="wood", grip_mat="wood", wrap="plain",
                        pommel="knob", pommel_mat="moss", pommel_size=2.1, seed=7),
}


def icon(name):
    return sword(DESIGNS[name]).render()
