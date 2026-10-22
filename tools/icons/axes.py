"""Axes in the OpenTibia pack's proportions (measured from 67 pack axes, reference only): a 3 px haft
on the diagonal from near the top-left to the bottom-right corner, a head about 17 px across square to
the haft at its top end, the blade fanning out to the lower left with a bright honed edge. Axes
differ in blade (depth, spread, curve of the edge, beard), back (spike, second bit, none), collar,
haft wrap, and materials.
"""
from core import ROUND, Icon, at, local, to_local

TIP = (1.6, 1.6)
HAFT = (5.0, 38.5)  # where the haft starts and ends along the diagonal
SCALE = 1.6  # the designs' head sizes are in tenths of the pack's head; this brings them to its size


def _blade(icon, centre, d, side):
    """One bit: a fan from the haft (across 0) out to its edge (across `depth` on `side`), widening
    from the neck to `spread` either way along the haft, the edge bowed by `curve` and dropped toward
    the grip by `beard`. The outermost pixel of the edge is honed bright."""
    depth, spread, neck = d["depth"] * SCALE, d["spread"] * SCALE, d.get("neck", 1.6) * 1.3
    curve, beard = d.get("curve", 1.6) * SCALE, d.get("beard", 0.0) * SCALE

    def reach(t, w):  # how far along the haft the blade reaches at distance w from it
        return neck + (spread - neck) * (w / depth) ** 1.5

    def inside(t, v, margin=0.0):
        w = v * side
        if w < 0.4:
            return False
        t = t - beard * (w / depth) ** 2
        h = reach(t, w)
        return abs(t) <= h and w <= depth - curve * (t / max(h, 0.01)) ** 2 - margin

    cells = local(centre, inside)
    rim = cells - local(centre, lambda t, v: inside(t, v, 1.1))
    bevel = local(centre, lambda t, v: inside(t, v, 1.1)) - local(centre, lambda t, v: inside(t, v, 3.2))
    for (x, y) in cells:
        t, v = to_local(centre, x, y)
        w = v * side / depth
        # Forged: darker at the socket, lighter toward the edge, the upper (lit) half brighter.
        tone = 0.28 + 0.38 * w - 0.22 * (t / spread)
        if (x, y) in bevel:
            tone += 0.18 - (0.22 if (x, y) in bevel and w < 0.75 and abs(t) > spread * 0.2 else 0.0)
        if (x, y) in rim:
            tone = 0.92 - 0.12 * (t / spread)
        icon.put(x, y, d["head_mat"], tone)


def axe(d):
    """Draws one axe design (a dict, see DESIGNS) and returns the Icon."""
    icon = Icon()
    start, end = HAFT[0] + d.get("shorten", 0), HAFT[1]
    head = at(TIP, start + d.get("head_at", 4.0) * 1.9)
    wrap = d.get("wrap")
    pattern = (lambda length, u: -0.3 if length > (end - start) * 0.62 and int(length) % 2 == 0 else 0.04) if wrap else \
        (lambda length, u: 0.0)
    icon.stroke([at(TIP, start), at(TIP, end)], lambda s: 1.05, ROUND, d["haft_mat"], pattern=pattern)
    if wrap:
        icon.stroke([at(TIP, start + (end - start) * 0.62), at(TIP, end - 0.6)], lambda s: 1.15, ROUND, wrap,
                    pattern=lambda length, u: -0.3 if int(length) % 2 == 0 else 0.05)
    icon.ball(*at(TIP, end), 1.25, 1.25, d.get("cap_mat", d["collar_mat"]))
    _blade(icon, head, d, -1)
    back = d.get("back")
    if back == "bit":
        _blade(icon, head, dict(d, depth=d.get("back_depth", d["depth"])), 1)
    elif back == "spike":
        icon.stroke([at(head, 0, 0.8), at(head, -0.6, 8.0)], lambda s: 2.2 * (1 - s) + 0.2, ROUND, d["head_mat"])
    elif back == "knob":
        icon.ball(*at(head, 0, 2.6), 2.1, 2.1, d["collar_mat"])
    if d.get("top_spike"):
        icon.stroke([at(head, -1.0), at(TIP, start - 3.0)], lambda s: 1.0 * s + 0.25, ROUND, d["head_mat"])
    icon.stroke([at(head, -3.0), at(head, 3.0)], lambda s: 1.7, ROUND, d["collar_mat"])
    return icon


# Each design its own axe: blade shape, back, collar, wrap, and materials all differ.
DESIGNS = {
    # A woodsman's hatchet: a small square bit, short haft, iron collar.
    "hatchet": dict(depth=6.0, spread=3.2, curve=0.8, head_mat="iron", collar_mat="iron", haft_mat="wood",
                    shorten=6, head_at=3.5),
    # A bearded axe: a long beard dropping down the haft, a knob behind, a banded leather wrap.
    "bearded_axe": dict(depth=8.0, spread=4.6, beard=3.4, curve=1.2, head_mat="steel", back="knob",
                        collar_mat="bronze", haft_mat="wood", wrap="leather"),
    # A battle axe: two broad bits, a spike on top, a gold collar, a dark haft.
    "battle_axe": dict(depth=7.4, spread=5.0, curve=2.0, back="bit", top_spike=True, head_mat="steel",
                       collar_mat="gold", haft_mat="4a2e1e", wrap="2a2a32"),
    # A war axe: a deep dark bit with a back spike and an iron collar.
    "war_axe": dict(depth=9.0, spread=4.0, curve=1.4, back="spike", head_mat="darksteel", collar_mat="iron",
                    haft_mat="wood", wrap="7a1a14"),
    # A crescent axe: a wide moon-shaped silver bit, strongly bowed edge, a long pale haft.
    "crescent_axe": dict(depth=8.4, spread=7.0, neck=1.2, curve=3.6, head_mat="silver", collar_mat="silver",
                         haft_mat="c8b08a", head_at=4.6),
    # A bone axe: a crude bone bit with a short beard, a bone knob behind, a bound haft.
    "bone_axe": dict(depth=7.0, spread=4.2, beard=1.6, curve=1.0, back="knob", head_mat="bone", collar_mat="leather",
                     cap_mat="bone", haft_mat="wood", wrap="leather"),
    # A bronze labrys: two equal bronze bits, gently bowed, on a wrapped haft.
    "labrys": dict(depth=6.8, spread=5.6, curve=1.4, back="bit", head_mat="bronze", collar_mat="bronze",
                   haft_mat="5a3a22", wrap="9a2a22"),
    # A glass axe: a black glass bit with a short back bit, a gold collar.
    "glass_axe": dict(depth=8.6, spread=4.8, curve=2.4, beard=1.0, back="bit", back_depth=4.0, head_mat="obsidian",
                      collar_mat="gold", haft_mat="2a2a32", wrap="gold"),
}


def icon(name):
    return axe(DESIGNS[name]).render()
