"""Swords: a blade, a guard, a grip, and a pommel on the icon's diagonal (tip top-left, pommel bottom-
right). Each sword is its own construction, not a recolour: a design is data naming its blade shape
(pointed, falchion, cleaver, needle, leaf, curved, hooked) and length, its edge (double or single),
guard (cross, flared, cup, square, crescent, collar), grip (length, wrap or bands), and pommel (ball,
disc, ring, spike, gem, cap), with the materials of each.
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
    if shape == "cleaver":
        return lambda s: w * min(1.0, 0.9 + s * 10)
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
    if kind == "cross":
        a, b = _at(at, 0, span), _at(at, 0, -span)
        icon.stroke([a, b], lambda s: thick, ROUND, mat)
        for end in (a, b):
            icon.ball(end[0], end[1], thick + 0.6, thick + 0.6, mat)
    elif kind == "flared":
        for side in (1, -1):
            icon.stroke([_at(at, 0.3, 0), _at(at, -0.4, side * span * 0.6), _at(at, -2.2, side * span)],
                        lambda s: thick * (0.8 + s * 0.7), ROUND, mat)
    elif kind == "cup":
        cup = _at(at, -0.8)
        icon.ball(cup[0], cup[1], span * 0.62, span * 0.62, mat, flat=0.25)
    elif kind == "square":
        cells = set()
        for y in range(32):
            for x in range(32):
                along = (x + 0.5 - at[0]) * AXIS[0] + (y + 0.5 - at[1]) * AXIS[1]
                across = (x + 0.5 - at[0]) * ACROSS[0] + (y + 0.5 - at[1]) * ACROSS[1]
                if abs(along) <= thick * 0.9 and abs(across) <= span:
                    cells.add((x, y))
        icon.dome(cells, mat, height=1.5)
    elif kind == "crescent":
        icon.stroke([_at(at, -2.0, span), _at(at, 0.6, 0), _at(at, -2.0, -span)], lambda s: thick, ROUND, mat)
    elif kind == "collar":
        icon.stroke([_at(at, -0.6), _at(at, 0.8)], lambda s: thick + 0.9, ROUND, mat)


def _pommel(icon, kind, at, mat, size, gem=None):
    if kind == "ball":
        icon.ball(at[0], at[1], size, size, mat)
    elif kind == "disc":
        icon.ball(at[0], at[1], size * 1.2, size * 1.2, mat, flat=0.55)
    elif kind == "ring":
        icon.stroke([_at(at, -size * 0.2, size), _at(at, size * 1.3, 0), _at(at, -size * 0.2, -size)],
                    lambda s: 0.95, ROUND, mat)
        icon.stroke([_at(at, -size * 0.2, size), _at(at, -size * 0.9, 0), _at(at, -size * 0.2, -size)],
                    lambda s: 0.95, ROUND, mat)
    elif kind == "spike":
        icon.ball(at[0], at[1], size * 0.8, size * 0.8, mat)
        icon.stroke([_at(at, 0.5), _at(at, size * 2.2)], lambda s: 1.2 * (1 - s) + 0.2, ROUND, mat)
    elif kind == "gem":
        icon.ball(at[0], at[1], size * 1.1, size * 1.1, mat, flat=0.4)
        icon.ball(at[0], at[1], size * 0.6, size * 0.6, gem)
    elif kind == "cap":
        icon.stroke([_at(at, -0.8), _at(at, 1.0)], lambda s: size * (1.0 - s * 0.35), ROUND, mat)


def sword(d):
    """Draws one sword design (a dict, see DESIGNS) and returns the Icon."""
    icon = Icon()
    tip = _at((2.6, 2.6), d.get("start", 0))
    guard = _at(tip, d["blade"])
    grip_end = _at(guard, d["grip"])
    # Handle first: grip, then pommel over its end.
    pattern = {"wrap": _wrap(), "diamond": _diamond_wrap(), "bands": _bands(d["grip"]), "plain": None}[d.get("wrap", "wrap")]
    icon.stroke([guard, grip_end], lambda s: d.get("grip_width", 1.7), ROUND, d["grip_mat"], pattern=pattern)
    _pommel(icon, d["pommel"], _at(grip_end, d.get("pommel_size", 2.0) * 0.6), d["pommel_mat"],
            d.get("pommel_size", 2.0), d.get("gem"))
    # Blade, straight or curved, and its extras.
    path = [tip, _at(_at(tip, d["blade"] / 2), 0, d["curve"]), guard] if d.get("curve") else [tip, guard]
    edge = SINGLE if d.get("edge") == "single" else DOUBLE
    icon.stroke(path, _width(d["shape"], d["width"]), edge, d["blade_mat"], shine=0.5)
    if d.get("hook"):
        root = _at(tip, d["blade"] * 0.38, 0)
        icon.stroke([root, _at(root, -1.0, 4.2), _at(root, 3.2, 5.0)], lambda s: 1.5 * (1 - s * 0.7), SINGLE, d["blade_mat"])
    if d.get("fuller"):
        icon.stroke([_at(tip, d["blade"] * 0.3), _at(tip, d["blade"] - 1.0)], lambda s: 0.6, lambda u, *_: 0.2, d["blade_mat"])
    if d.get("inlay"):
        icon.stroke([_at(tip, d["blade"] * 0.3), _at(tip, d["blade"] - 1.5)], lambda s: 0.55, lambda u, *_: 0.95,
                    d["inlay"])
    if d.get("knuckle"):
        end = _at(grip_end, 0.6)
        icon.stroke([_at(guard, -0.4, -2.4), _at(guard, d["grip"] * 0.5, -3.6), _at(end, 0, -1.2)], lambda s: 0.85,
                    ROUND, d["guard_mat"])
    _guard(icon, d["guard"], guard, d["guard_mat"], d.get("guard_span", 5.0), d.get("guard_thick", 1.5))
    if d.get("guard_gem"):
        icon.ball(guard[0], guard[1], 1.3, 1.3, d["guard_gem"])
    return icon


# Each design its own sword: blade, guard, grip, and pommel all differ between them.
DESIGNS = {
    # A plain knight's sword: pointed double edge with a fuller, ball-ended cross, wrapped grip, disc pommel.
    "arming_sword": dict(blade=22, shape="point", width=2.1, blade_mat="steel", fuller=True,
                         guard="cross", guard_mat="iron", guard_span=4.6, grip=8, grip_mat="leather",
                         pommel="disc", pommel_mat="iron"),
    # A falchion: single edge widening to a clipped point, crescent guard, banded wooden grip, cap pommel.
    "falchion": dict(blade=19, start=2, shape="falchion", width=2.4, edge="single", blade_mat="steel",
                     guard="crescent", guard_mat="bronze", guard_span=4.4, grip=8, grip_mat="wood", wrap="bands",
                     pommel="cap", pommel_mat="bronze", pommel_size=1.8),
    # A cleaver: a broad squared blade with no point, a collar, a thick bone grip, a ring pommel.
    "cleaver": dict(blade=16, start=4, shape="cleaver", width=3.4, edge="single", blade_mat="darksteel",
                    guard="cross", guard_mat="iron", guard_span=3.0, guard_thick=1.7, grip=8, grip_mat="bone",
                    grip_width=1.9, wrap="bands", pommel="ring", pommel_mat="iron", pommel_size=2.4),
    # A rapier: a needle blade, a big gold cup guard, a long black cord grip, a heavy ball pommel.
    "rapier": dict(blade=23, shape="needle", width=1.2, blade_mat="silver", guard="cup", guard_mat="gold",
                   guard_span=5.0, grip=9, grip_mat="2a2a32", wrap="diamond", pommel="ball", pommel_mat="gold",
                   pommel_size=2.0, knuckle=True),
    # A moonblade: a long single-edged curve, a square guard, a long crossed-cord grip, a cap.
    "moonblade": dict(blade=21, shape="point", width=1.8, curve=3.2, edge="single", blade_mat="silver",
                      guard="square", guard_mat="gold", guard_span=3.8, guard_thick=1.6, grip=10,
                      grip_mat="3a1a4a", wrap="diamond", pommel="cap", pommel_mat="darksteel", pommel_size=1.6),
    # A gladius: a short broad leaf, a thick flared guard, a ridged bone grip, a big ball pommel.
    "gladius": dict(blade=15, start=4, shape="leaf", width=2.7, blade_mat="bronze", guard="flared", guard_mat="wood",
                    guard_span=4.0, guard_thick=1.4, grip=7, grip_mat="bone", grip_width=1.8, pommel="ball",
                    pommel_mat="wood", pommel_size=2.5),
    # The runeblade: a dark leaf blade with a glowing inlay, swept silver guard, blue wrap, gem pommel.
    "runeblade": dict(blade=21, shape="leaf", width=2.4, blade_mat="darksteel", inlay="5ae0ff", guard="flared",
                      guard_mat="silver", guard_span=5.0, grip=8, grip_mat="1a2a4a", pommel="gem",
                      pommel_mat="silver", gem="5ae0ff", guard_gem="5ae0ff"),
    # A hookblade: a black glass blade with a hook on its back, a gold cross, red wrap, spike pommel.
    "hookblade": dict(blade=21, shape="point", width=2.0, edge="single", hook=True, blade_mat="obsidian",
                      guard="cross", guard_mat="gold", guard_span=4.2, guard_thick=1.3, grip=8, grip_mat="7a1a14",
                      pommel="spike", pommel_mat="gold", pommel_size=1.7),
}


def icon(name):
    return sword(DESIGNS[name]).render()
