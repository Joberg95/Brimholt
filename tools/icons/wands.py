"""Wands and rods in the OpenTibia pack's proportions (measured from 19 pack wands and rods, reference
only): a thin 2 px shaft on the diagonal to the bottom-right corner with banded fittings, and an ornate
head about 10 px across at its top-left end, usually a gem or crystal held by prongs. They differ in
head (orb in a claw, crystal, crescent, star, skull, leaves, flame, coil), shaft, fittings, and
materials.
"""
import math

from core import ROUND, Icon, at, local, to_local

TIP = (1.6, 1.6)
END = 38.8


K = 1.6  # head size against the measured pack heads (about 10 px across, 40% of the wand)


def _claw(icon, c, d):
    for k in (-1, 0, 1):
        icon.stroke([at(c, 2.6 * K, k * 1.2 * K), at(c, -0.6 * K, k * 3.4 * K), at(c, -3.4 * K, k * 1.9 * K)],
                    lambda s: 1.0, ROUND, d["fitting"])
    icon.ball(*at(c, -1.0 * K), 3.0 * K, 3.0 * K, d["gem"])


def _crystal(icon, c, d):
    cells = local(c, lambda t, v: abs(t + 1.8 * K) / (6.4 * K) + abs(v) / (2.8 * K) <= 1)
    for (x, y) in cells:
        t, v = to_local(c, x, y)
        tone = 0.5 + (0.38 if v > 0 else -0.08) - 0.22 * ((t + 1.8 * K) / (6.4 * K)) + (0.3 if abs(v) < 0.55 else 0)
        icon.put(x, y, d["gem"], tone)
    icon.stroke([at(c, 3.4 * K, 2.4 * K), at(c, 4.6 * K), at(c, 3.4 * K, -2.4 * K)], lambda s: 1.0, ROUND, d["fitting"])


def _crescent(icon, c, d):
    icon.stroke([at(c, -5.0 * K, 3.0 * K), at(c, -1.6 * K, -4.4 * K), at(c, 3.0 * K, -1.0 * K)],
                lambda s: 1.6 * K * math.sin(math.pi * s) + 0.4, ROUND, d["gem"])
    icon.ball(*at(c, -0.4 * K, 1.2 * K), 1.5 * K, 1.5 * K, d["fitting"])


def _star(icon, c, d):
    centre = at(c, -2.0 * K)
    for k in range(5):
        a = k * 2 * math.pi / 5 - math.pi / 2 - 0.4
        icon.stroke([centre, (centre[0] + math.cos(a) * 5.2 * K, centre[1] + math.sin(a) * 5.2 * K)],
                    lambda s: 1.5 * K * (1 - s) + 0.2, ROUND, d["gem"])
    icon.ball(centre[0], centre[1], 1.9 * K, 1.9 * K, d["fitting"])


def _skull(icon, c, d):
    skull = at(c, -2.2 * K)
    icon.ball(skull[0], skull[1], 3.6 * K, 3.3 * K, "bone")
    for across in (1.3 * K, -1.3 * K):
        sockets = local(at(skull, -0.2 * K, across), lambda t, v: t * t + v * v <= 1.1)
        icon.shade(sockets, -0.75)
    icon.ball(*at(skull, -0.2 * K, 1.3 * K), 0.7, 0.7, d["gem"], glint=False)
    icon.ball(*at(skull, -0.2 * K, -1.3 * K), 0.7, 0.7, d["gem"], glint=False)
    icon.stroke([at(c, 1.6 * K, 1.4 * K), at(c, 1.6 * K, -1.4 * K)], lambda s: 1.1, ROUND, d["fitting"])


def _leaves(icon, c, d):
    for along, across, out in ((-3.4, 0.0, -1.0), (-0.8, 1.8, 1.0), (1.4, -1.9, -1.0)):
        base = at(c, along * K, 0)
        icon.stroke([base, at(base, -1.2 * K, (across + out * 2.6) * K), at(base, -3.6 * K, (across + out * 3.2) * K)],
                    lambda s: 1.5 * K * math.sin(math.pi * s) + 0.2, ROUND, d["gem"])
    icon.ball(*at(c, -4.6 * K), 1.6 * K, 1.6 * K, d["fitting"])


def _flame(icon, c, d):
    for across, length in ((0.0, 6.2), (2.0, 4.2), (-2.0, 4.6)):
        icon.stroke([at(c, 1.2 * K, across * 0.6 * K), at(c, -length * K, across * K)], lambda s: 1.8 * K * (1 - s) + 0.2,
                    lambda u, *_: 0.95 - 0.35 * abs(u), d["gem"])
    icon.ball(*at(c, 0.8 * K), 1.6 * K, 1.6 * K, d["fitting"])


def _coil(icon, c, d):
    for k in range(6):
        icon.ball(*at(c, (-4.0 + k * 1.6) * K, (1.4 if k % 2 else -1.4) * K), 0.9 * K, 0.9 * K, d["fitting"])
    icon.ball(*at(c, -5.0 * K), 2.3 * K, 2.3 * K, d["gem"])


HEADS = {"claw": _claw, "crystal": _crystal, "crescent": _crescent, "star": _star, "skull": _skull,
         "leaves": _leaves, "flame": _flame, "coil": _coil}


def wand(d):
    """Draws one wand or rod design (a dict, see DESIGNS) and returns the Icon."""
    icon = Icon()
    head = at(TIP, d.get("head_at", 7.0) * K)
    icon.stroke([head, at(TIP, END)], lambda s: d.get("shaft_width", 0.85), ROUND, d["shaft"])
    for along in d.get("bands", (14.0, 30.0)):
        icon.stroke([at(TIP, along - 0.7), at(TIP, along + 0.7)], lambda s: 1.15, ROUND, d["fitting"])
    icon.ball(*at(TIP, END), 1.15, 1.15, d["fitting"])
    HEADS[d["head"]](icon, head, d)
    return icon


# Each design its own wand: head, shaft, fittings, and materials all differ.
DESIGNS = {
    # An orb wand: a blue orb held in a three-pronged gold claw on dark wood.
    "orb_wand": dict(head="claw", gem="3a7af0", fitting="gold", shaft="4a2e1e"),
    # A crystal rod: a long faceted green crystal set in silver on a pale shaft.
    "crystal_rod": dict(head="crystal", gem="5ae08a", fitting="silver", shaft="c8b08a", head_at=8.0),
    # A moon rod: a silver crescent with a gold boss on a black shaft.
    "moon_rod": dict(head="crescent", gem="silver", fitting="gold", shaft="2a2a32", head_at=8.0),
    # A star wand: a five-pointed gold star on a white shaft with blue bands.
    "star_wand": dict(head="star", gem="gold", fitting="3a5aa8", shaft="e8e4d8", head_at=8.0),
    # A skull rod: a bone skull with a red eye on a dark shaft with iron bands.
    "skull_rod": dict(head="skull", gem="ff3020", fitting="iron", shaft="3a2a22", head_at=8.0),
    # A leaf rod: three green leaves and a bud on living wood, bound in bronze.
    "leaf_rod": dict(head="leaves", gem="4aa040", fitting="bronze", shaft="wood", head_at=8.5, bands=(22.0,)),
    # An ember wand: a three-tongued flame on a copper shaft.
    "ember_wand": dict(head="flame", gem="ff8a20", fitting="copper", shaft="copper", head_at=7.5),
    # A coil wand: copper wire wound round the head, a violet orb at its tip, a dark shaft.
    "coil_wand": dict(head="coil", gem="a050ff", fitting="copper", shaft="1a1a22", head_at=9.0),
}


def icon(name):
    return wand(DESIGNS[name]).render()
