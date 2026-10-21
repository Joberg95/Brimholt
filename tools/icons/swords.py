"""Swords: a blade, a guard, a grip, and a pommel on the icon's diagonal (tip top-left, pommel bottom-
right), each sword its own design. A design is data: the blade's length, width along it (straight,
leaf, broad, curved, wavy, serrated), its cross-section and materials, the guard, grip, and pommel.
"""
import math

from core import Icon

# The diagonal: unit vectors along the blade (towards the pommel) and across it (towards upper right).
AXIS = (math.sqrt(0.5), math.sqrt(0.5))
ACROSS = (math.sqrt(0.5), -math.sqrt(0.5))


def _at(origin, along, across=0.0):
    return (origin[0] + AXIS[0] * along + ACROSS[0] * across, origin[1] + AXIS[1] * along + ACROSS[1] * across)


def _piecewise(points):
    """A function through (u, value) points, linear between them."""
    def f(u):
        for (u0, v0), (u1, v1) in zip(points, points[1:]):
            if u <= u1:
                return v0 + (v1 - v0) * (u - u0) / max(1e-6, u1 - u0)
        return points[-1][1]
    return f


# Blade cross-sections, from the upper-right edge (u -1) to the lower-left edge (u 1): the pack's
# stylised bevel, dark far side, bright core, lit near edge.
BEVEL = _piecewise([(-1, 0.52), (-0.8, 0.26), (-0.06, 0.34), (0.04, 1.0), (0.55, 0.84), (0.82, 0.7), (1, 0.95)])
FLAT = _piecewise([(-1, 0.5), (-0.82, 0.3), (-0.3, 0.42), (-0.2, 0.86), (0.6, 0.78), (0.85, 0.66), (1, 0.97)])
ROUND = _piecewise([(-1, 0.15), (-0.35, 0.5), (0.3, 1.0), (1, 0.42)])


def _width(kind, base):
    """Half-width of the blade along it (s 0 at the tip, 1 at the guard)."""
    if kind == "straight":
        return lambda s: base * min(1.0, 0.35 + s * 4)
    if kind == "leaf":
        return lambda s: base * (0.4 + 0.9 * math.sin(math.pi * min(1.0, s * 1.15)) ** 0.7) if s < 0.95 else base * 0.7
    if kind == "broad":
        return lambda s: base * min(1.0, 0.5 + s * 5)
    if kind == "wavy":
        return lambda s: base * min(1.0, 0.35 + s * 4) * (0.7 + 0.34 * math.sin(s * 24))
    if kind == "serrated":
        return lambda s: base * min(1.0, 0.35 + s * 4) * (1.15 - 0.5 * ((s * 11) % 1.0))
    raise ValueError(kind)


def sword(design):
    """Draws one sword design (a dict, see DESIGNS) and returns the Icon."""
    icon = Icon()
    tip = (2.6 + design.get("shift", 0), 2.6 + design.get("shift", 0))
    guard_at = design["blade"]
    guard = _at(tip, guard_at)
    # Grip and pommel first, under the guard.
    grip_end = _at(guard, design["grip"])
    icon.stroke([guard, grip_end], lambda s: 1.45, ROUND, design["grip_mat"])
    if design.get("wrap"):
        cells = []
        for i in range(1, int(design["grip"]), 2):
            cx, cy = _at(guard, i + 0.5)
            cells += [(int(cx), int(cy)), (int(cx) + 1, int(cy) - 1)]
        icon.shade(cells, -0.22)
    pommel = _at(grip_end, design.get("pommel_gap", 1.2))
    pr = design.get("pommel_size", 2.3)
    icon.ball(pommel[0], pommel[1], pr, pr, design["pommel_mat"])
    # The blade, straight or curved.
    if design.get("curve"):
        bend = _at(_at(tip, guard_at / 2), 0, design["curve"])
        path = [tip, bend, guard]
    else:
        path = [tip, guard]
    icon.stroke(path, _width(design["shape"], design["width"]), design.get("section", BEVEL), design["blade_mat"],
                shine=0.5)
    if design.get("fuller"):
        start, end = _at(tip, guard_at * 0.25), _at(tip, guard_at - 1.0)
        icon.stroke([start, end], lambda s: 0.55, lambda u: 0.18, design["blade_mat"])
    if design.get("inlay"):
        start, end = _at(tip, guard_at * 0.3), _at(tip, guard_at - 1.5)
        icon.stroke([start, end], lambda s: 0.5, lambda u: 0.95, design["inlay"])
    # The guard across the blade.
    g = design["guard"]
    span, thick = design.get("guard_span", 6.0), design.get("guard_thick", 1.7)
    if g == "cross":
        icon.stroke([_at(guard, 0, span), _at(guard, 0, -span)], lambda s: thick, ROUND, design["guard_mat"])
    elif g == "swept":
        icon.stroke([_at(guard, -1.5, span), _at(guard, 0.4, 0), _at(guard, -1.5, -span)],
                    lambda s: thick, ROUND, design["guard_mat"])
    elif g == "disc":
        icon.ball(guard[0], guard[1], 2.6, 2.6, design["guard_mat"], flat=0.45)
    elif g == "wings":
        icon.stroke([_at(guard, 1.0, span), _at(guard, -1.2, span * 0.4), _at(guard, 0.2, 0)],
                    lambda s: thick * (1.2 - s * 0.5), ROUND, design["guard_mat"])
        icon.stroke([_at(guard, 1.0, -span), _at(guard, -1.2, -span * 0.4), _at(guard, 0.2, 0)],
                    lambda s: thick * (1.2 - s * 0.5), ROUND, design["guard_mat"])
    if design.get("gem"):
        icon.ball(guard[0], guard[1], 1.2, 1.2, design["gem"])
    return icon


# Each design its own sword: a different blade, guard, grip, or pommel, not a recolour.
DESIGNS = {
    "short_sword": dict(blade=19, shape="straight", width=2.1, blade_mat="steel", guard="cross",
                        guard_mat="iron", guard_span=4.6, grip=6, grip_mat="leather", wrap=True,
                        pommel_mat="iron", pommel_size=2.0, shift=4),
    "longsword": dict(blade=27, shape="straight", width=2.2, blade_mat="steel", fuller=True, guard="cross",
                      guard_mat="gold", grip=7, grip_mat="9a2a22", wrap=True, pommel_mat="gold"),
    "broadsword": dict(blade=24, shape="broad", width=3.2, blade_mat="steel", section=FLAT, fuller=True,
                       guard="swept", guard_mat="bronze", guard_span=6.4, grip=6, grip_mat="wood",
                       pommel_mat="bronze", pommel_size=2.5, shift=1),
    "sabre": dict(blade=26, shape="straight", width=2.1, curve=3.4, blade_mat="silver", guard="disc",
                  guard_mat="gold", grip=7, grip_mat="2a2a3a", wrap=True, pommel_mat="gold", pommel_size=1.9),
    "flamberge": dict(blade=27, shape="wavy", width=2.6, blade_mat="steel", guard="wings", guard_mat="darksteel",
                      guard_span=6.4, grip=7, grip_mat="4a2a1a", wrap=True, pommel_mat="darksteel"),
    "sawtooth": dict(blade=25, shape="serrated", width=2.7, blade_mat="iron", guard="cross", guard_mat="bone",
                     guard_thick=2.0, grip=7, grip_mat="bone", pommel_mat="bone", pommel_size=2.6),
    "runeblade": dict(blade=26, shape="leaf", width=2.6, blade_mat="darksteel", inlay="5ae0ff", guard="swept",
                      guard_mat="silver", grip=7, grip_mat="1a2a4a", wrap=True, pommel_mat="2a9ad8", gem="5ae0ff"),
    "emberblade": dict(blade=26, shape="leaf", width=2.5, blade_mat="copper", inlay="ffcf40", guard="wings",
                       guard_mat="gold", guard_span=6.0, grip=7, grip_mat="5a1a12", wrap=True, pommel_mat="c02a1a",
                       gem="ff6a20"),
}


def icon(name):
    return sword(DESIGNS[name]).render()
