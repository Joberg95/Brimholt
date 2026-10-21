"""Swords in the OpenTibia pack's proportions: every sword runs corner to corner on the diagonal (tip
top-left, pommel in the bottom-right corner); the blade takes about two thirds of it and is 3-4 px
wide, the guard is a thin crossbar about 11 px across with knobbed ends, the grip a 2 px stripe, the
pommel a small knob (measured from 115 pack swords; the pack is reference only). Swords differ in
blade shape (pointed, falchion, needle, leaf, curved, hooked), edge, guard, grip wrap, pommel, and
materials, never by colour alone.
"""
import math

from core import Icon

# Unit vectors along the blade (towards the pommel) and across it (towards upper right).
AXIS = (math.sqrt(0.5), math.sqrt(0.5))
ACROSS = (math.sqrt(0.5), -math.sqrt(0.5))


def _at(origin, along, across=0.0):
    return (origin[0] + AXIS[0] * along + ACROSS[0] * across, origin[1] + AXIS[1] * along + ACROSS[1] * across)


def _piecewise(points):
    """A function through (u, value) points, linear between them."""
    def f(u, *_):
        for (u0, v0), (u1, v1) in zip(points, points[1:]):
            if u <= u1:
                return v0 + (v1 - v0) * (u - u0) / max(1e-6, u1 - u0)
        return points[-1][1]
    return f


# Cross-sections from the upper-right side (u -1) to the lower-left (u 1).
# A double edge: two flat planes split by a hard bright ridge, a thin lit rim on the near edge.
DOUBLE = _piecewise([(-1, 0.52), (-0.8, 0.26), (-0.06, 0.34), (0.04, 1.0), (0.55, 0.84), (0.82, 0.7), (1, 0.95)])
# A single edge: a thick dark back rising to a bright honed edge.
SINGLE = _piecewise([(-1, 0.18), (-0.7, 0.3), (-0.1, 0.5), (0.45, 0.78), (0.8, 1.0), (1, 0.9)])
# A rod lit from above: grips, quillons.
ROUND = _piecewise([(-1, 0.15), (-0.35, 0.5), (0.3, 1.0), (1, 0.42)])


def _width(shape, w):
    """Half-width of a blade along it, s 0 at the tip and 1 at the guard."""
    if shape == "point":
        return lambda s: w * min(1.0, 0.3 + s * 4.5)
    if shape == "leaf":
        return lambda s: w * (0.45 + 0.75 * math.sin(math.pi * min(0.92, s) / 0.92 * 0.85) ** 0.6) if s < 0.97 else w * 0.75
    if shape == "falchion":
        return lambda s: w * (1.3 - 0.55 * s) * min(1.0, 0.25 + s * 7)
    if shape == "needle":
        return lambda s: w * min(1.0, 0.35 + s * 2.5)
    raise ValueError(shape)


def _wrap(spacing=2, depth=0.3):
    """A leather or cord wrap: dark bands across the grip every `spacing` pixels."""
    return lambda length, u: -depth if int(length) % spacing == 0 else 0.06


def _diamond_wrap():
    """A crossed cord wrap: diamonds of light between dark crossings."""
    return lambda length, u: -0.32 if (int(length * 1.3) + (1 if u > 0 else 0)) % 2 == 0 else 0.08


def _bands(length_px):
    """A plain grip with a dark band near each end."""
    return lambda length, u: -0.3 if length < 1 or length > length_px - 1 else 0.0


def _guard(icon, kind, at, mat, span, thick):
    """A thin crossbar across the blade (the pack's guards are about 2 px thick and 11 across)."""
    knob = thick + 0.45
    if kind == "cross":
        a, b = _at(at, 0, span), _at(at, 0, -span)
        icon.stroke([a, b], lambda s: thick, ROUND, mat)
        for end in (a, b):
            icon.ball(end[0], end[1], knob, knob, mat)
    elif kind == "drooping":  # quillons bent toward the blade
        for side in (1, -1):
            icon.stroke([_at(at, 0.4, 0), _at(at, 0.0, side * span * 0.6), _at(at, -1.8, side * span)],
                        lambda s: thick, ROUND, mat)
            end = _at(at, -1.8, side * span)
            icon.ball(end[0], end[1], knob, knob, mat)
    elif kind == "crescent":  # one curved bar, horns toward the tip
        icon.stroke([_at(at, -2.4, span), _at(at, 0.8, 0), _at(at, -2.4, -span)], lambda s: thick, ROUND, mat)
    elif kind == "ring":  # a small ring round the blade's root
        for bend in (-1.6, 1.6):
            icon.stroke([_at(at, 0, span * 0.55), _at(at, bend, 0), _at(at, 0, -span * 0.55)],
                        lambda s: thick * 0.85, ROUND, mat)
    elif kind == "wings":  # flat wings swept back toward the grip
        for side in (1, -1):
            icon.stroke([_at(at, -0.3, 0), _at(at, 1.6, side * span)], lambda s: thick * (1.4 - s * 0.6), ROUND, mat)
    elif kind == "bar":  # a plain straight bar, squared ends
        icon.stroke([_at(at, 0, span), _at(at, 0, -span)], lambda s: thick * 1.15, ROUND, mat)


def _pommel(icon, kind, at, mat, size, gem=None):
    """A small knob at the corner (the pack's pommels are 2-4 px)."""
    if kind == "knob":
        icon.ball(at[0], at[1], size, size, mat)
    elif kind == "ring":
        for side in (1, -1):
            icon.stroke([_at(at, -size, 0), _at(at, 0, side * size * 1.1), _at(at, size, 0)], lambda s: 0.7, ROUND, mat)
    elif kind == "gem":
        icon.ball(at[0], at[1], size, size, mat, flat=0.3)
        icon.ball(at[0] - 0.2, at[1] - 0.2, size * 0.55, size * 0.55, gem)
    elif kind == "fishtail":
        for side in (1, -1):
            icon.stroke([_at(at, -1.0), _at(at, size, side * size)], lambda s: 0.75, ROUND, mat)
    elif kind == "spike":
        icon.stroke([_at(at, -1.2), _at(at, size * 1.4)], lambda s: 1.0 * (1 - s) + 0.25, ROUND, mat)


# Every sword runs corner to corner like the pack's: tip at (1.6, 1.6), the pommel in the far corner.
TIP = (1.6, 1.6)
LENGTH = 39.6


def sword(d):
    """Draws one sword design (a dict, see DESIGNS) and returns the Icon."""
    icon = Icon()
    blade = LENGTH * d.get("guard_at", 0.66)
    guard = _at(TIP, blade)
    pommel = _at(TIP, LENGTH - d.get("pommel_size", 1.3))
    pattern = {"wrap": _wrap(), "diamond": _diamond_wrap(), "bands": _bands(LENGTH - blade),
               "plain": None}[d.get("wrap", "wrap")]
    icon.stroke([guard, pommel], lambda s: d.get("grip_width", 0.95), ROUND, d["grip_mat"], pattern=pattern)
    _pommel(icon, d["pommel"], pommel, d["pommel_mat"], d.get("pommel_size", 1.3), d.get("gem"))
    path = [TIP, _at(_at(TIP, blade / 2), 0, d["curve"]), guard] if d.get("curve") else [TIP, guard]
    edge = SINGLE if d.get("edge") == "single" else DOUBLE
    icon.stroke(path, _width(d["shape"], d["width"]), edge, d["blade_mat"], shine=0.5)
    if d.get("hook"):
        root = _at(TIP, blade * 0.42, 0)
        icon.stroke([root, _at(root, -0.6, 3.2), _at(root, 2.4, 3.8)], lambda s: 1.0 * (1 - s * 0.6), SINGLE,
                    d["blade_mat"])
    if d.get("fuller"):
        icon.stroke([_at(TIP, blade * 0.3), _at(TIP, blade - 1.2)], lambda s: 0.45, lambda u, *_: 0.22, d["blade_mat"])
    if d.get("inlay"):
        icon.stroke([_at(TIP, blade * 0.28), _at(TIP, blade - 1.4)], lambda s: 0.45, lambda u, *_: 0.95, d["inlay"])
    _guard(icon, d["guard"], guard, d["guard_mat"], d.get("guard_span", 5.4), d.get("guard_thick", 0.95))
    if d.get("guard_gem"):
        icon.ball(guard[0], guard[1], 1.1, 1.1, d["guard_gem"])
    return icon


# Each design its own sword within the pack's proportions: they differ in blade shape, guard, pommel,
# wrap, and materials.
DESIGNS = {
    # A knight's longsword: straight double edge with a fuller, knobbed cross, leather wrap, knob.
    "longsword": dict(shape="point", width=1.6, blade_mat="steel", fuller=True, guard="cross", guard_mat="iron",
                      grip_mat="leather", pommel="knob", pommel_mat="iron"),
    # A falchion: a single edge widening toward a clipped point, a crescent guard, banded grip.
    "falchion": dict(shape="falchion", width=1.55, edge="single", blade_mat="steel", guard="crescent",
                     guard_mat="bronze", grip_mat="wood", wrap="bands", pommel="knob", pommel_mat="bronze"),
    # A rapier: a needle blade, a ring guard, a long black cord grip, a gold knob.
    "rapier": dict(shape="needle", width=1.1, guard_at=0.7, blade_mat="silver", guard="ring", guard_mat="gold",
                   guard_span=4.6, grip_mat="2a2a32", wrap="diamond", pommel="knob", pommel_mat="gold", pommel_size=1.5),
    # A moonblade: a single-edged curve, a plain bar guard, a purple cord grip, a fishtail pommel.
    "moonblade": dict(shape="point", width=1.45, curve=2.6, edge="single", blade_mat="silver", guard="bar",
                      guard_mat="gold", guard_span=4.2, grip_mat="3a1a4a", wrap="diamond", pommel="fishtail",
                      pommel_mat="gold"),
    # A broadsword: a wide straight blade, drooping quillons, a wooden grip, a ring pommel.
    "broadsword": dict(shape="point", width=1.95, guard_at=0.64, blade_mat="steel", guard="drooping",
                       guard_mat="darksteel", guard_span=5.8, grip_mat="wood", wrap="bands", pommel="ring",
                       pommel_mat="darksteel", pommel_size=1.5),
    # A bronze leaf blade: a swelling leaf, swept wings, a bone grip, a knob.
    "leafblade": dict(shape="leaf", width=1.8, blade_mat="bronze", guard="wings", guard_mat="bronze", guard_span=4.0,
                      grip_mat="bone", wrap="bands", pommel="knob", pommel_mat="bronze", pommel_size=1.5),
    # The runeblade: a dark leaf blade with a glowing inlay, a knobbed silver cross with a gem, gem pommel.
    "runeblade": dict(shape="leaf", width=1.75, blade_mat="darksteel", inlay="5ae0ff", guard="cross",
                      guard_mat="silver", grip_mat="1a2a4a", pommel="gem", pommel_mat="silver", gem="5ae0ff",
                      guard_gem="5ae0ff"),
    # A hookblade: a black glass single edge with a hook off its back, gold wings, red wrap, a spike.
    "hookblade": dict(shape="point", width=1.5, edge="single", hook=True, blade_mat="obsidian", guard="wings",
                      guard_mat="gold", guard_span=4.4, grip_mat="7a1a14", pommel="spike", pommel_mat="gold"),
}


def icon(name):
    return sword(DESIGNS[name]).render()
