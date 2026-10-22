"""Maces, hammers, and clubs in the OpenTibia pack's proportions (measured from 28 pack maces,
reference only): a 2-3 px haft on the diagonal to the bottom-right corner, a compact head about 9 px
across at its top-left end, a wrapped grip and a small end cap. They differ in head (flanged, spiked,
hammer, maul, club, scepter, crystal, bone), haft, wrap, and materials.
"""
import math

from core import ROUND, Icon, at, local, to_local

TIP = (1.6, 1.6)
END = 38.5  # the haft's end along the diagonal


def _flanged(icon, c, d):
    for k in range(6):
        a = k * math.pi / 3 + 0.3
        icon.stroke([c, (c[0] + math.cos(a) * 6.6, c[1] + math.sin(a) * 6.6)], lambda s: 1.5 - s * 0.4, ROUND, d["head_mat"])
    icon.ball(c[0], c[1], 4.3, 4.3, d["head_mat"])


def _spiked(icon, c, d):
    for k in range(8):
        a = k * math.pi / 4 + 0.39
        icon.stroke([(c[0] + math.cos(a) * 3.2, c[1] + math.sin(a) * 3.2), (c[0] + math.cos(a) * 7.4, c[1] + math.sin(a) * 7.4)],
                    lambda s: 1.4 * (1 - s) + 0.15, ROUND, d.get("spike_mat", d["head_mat"]))
    icon.ball(c[0], c[1], 4.5, 4.5, d["head_mat"])


def _block(icon, c, d, half_along, half_across, spike=False):
    """A hammer head square to the haft: a lit top face, darker sides, bright striking faces."""
    cells = local(c, lambda t, v: abs(t) <= half_along and (-half_across <= v <= (1.0 if spike else half_across)))
    for (x, y) in cells:
        t, v = to_local(c, x, y)
        tone = 0.62 - 0.32 * (t / half_along) - 0.08 * (v / half_across)
        if abs(v) > half_across - 1.1:
            tone += 0.25  # the striking face catches the light
        icon.put(x, y, d["head_mat"], tone)
    if spike:
        icon.stroke([at(c, 0, 0.8), at(c, 0.6, half_across + 2.5)], lambda s: half_along * (1 - s) + 0.2, ROUND, d["head_mat"])
    for band in d.get("bands", ()):
        icon.shade(local(c, lambda t, v, b=band: abs(t) <= half_along and abs(v - b) < 0.7), -0.3)


def _club(icon, c, d):
    icon.stroke([at(c, -5.5), at(c, 10.0)], lambda s: 4.3 - s * 3.0, ROUND, d["head_mat"],
                pattern=lambda length, u: -0.12 if int(length * 0.7) % 3 == 0 else 0.0)
    for along, across in ((-2.5, 1.8), (0.5, -2.4), (3.2, 1.6), (-0.4, 0.6)):
        icon.ball(*at(c, along, across), 0.9, 0.9, d.get("stud_mat", "iron"))


def _scepter(icon, c, d):
    for k in (-1, 0, 1):
        icon.stroke([at(c, -1.2, k * 2.6), at(c, -6.4, k * 4.4)], lambda s: 1.2 * (1 - s) + 0.3, ROUND, d["head_mat"])
    icon.ball(c[0], c[1], 3.9, 3.9, d["head_mat"])
    icon.ball(*at(c, -1.4), 2.1, 2.1, d["gem"])


def _crystal(icon, c, d):
    cells = local(c, lambda t, v: abs(t + 1.5) / 7.6 + abs(v) / 4.5 <= 1)
    for (x, y) in cells:
        t, v = to_local(c, x, y)
        tone = 0.55 + (0.35 if v > 0 else -0.05) - 0.25 * ((t + 1.5) / 7.6)
        if abs(v) < 0.6:
            tone += 0.3  # the bright ridge between two facets
        icon.put(x, y, d["head_mat"], tone)


def _bone(icon, c, d):
    icon.stroke([at(c, -3.0), at(c, 7.0)], lambda s: 2.3 - s * 0.8, ROUND, d["head_mat"])
    for across in (2.1, -2.1):
        icon.ball(*at(c, -4.2, across), 2.6, 2.6, d["head_mat"])


HEADS = {"flanged": _flanged, "spiked": _spiked, "club": _club, "scepter": _scepter, "crystal": _crystal, "bone": _bone,
         "hammer": lambda icon, c, d: _block(icon, c, d, 3.2, 6.2, spike=d.get("spike", False)),
         "maul": lambda icon, c, d: _block(icon, c, d, 4.2, 7.0)}


def mace(d):
    """Draws one mace design (a dict, see DESIGNS) and returns the Icon."""
    icon = Icon()
    head = at(TIP, d.get("head_at", 8.5))
    grip = END - d.get("grip", 10)
    icon.stroke([head, at(TIP, END)], lambda s: d.get("haft_width", 1.0), ROUND, d["haft_mat"])
    icon.stroke([at(TIP, grip), at(TIP, END - 0.8)], lambda s: 1.15, ROUND, d["wrap"],
                pattern=lambda length, u: -0.3 if int(length) % 2 == 0 else 0.05)
    icon.ball(*at(TIP, END), 1.3, 1.3, d.get("cap_mat", "iron"))
    HEADS[d["head"]](icon, head, d)
    return icon


# Each design its own weapon: head, haft, wrap, and materials all differ.
DESIGNS = {
    # A flanged mace: six iron flanges round a ball, an iron haft, a leather grip.
    "flanged_mace": dict(head="flanged", head_mat="iron", haft_mat="iron", wrap="leather"),
    # A spiked mace: a dark ball bristling with eight spikes, a wooden haft, a red grip.
    "spiked_mace": dict(head="spiked", head_mat="darksteel", spike_mat="steel", haft_mat="wood", wrap="7a1a14"),
    # A war hammer: a steel block with a back spike, a wooden haft, a black grip.
    "war_hammer": dict(head="hammer", spike=True, head_mat="steel", haft_mat="wood", wrap="2a2a32", head_at=9.0),
    # A maul: a big bronze block banded twice, a long banded haft, a gold cap.
    "maul": dict(head="maul", head_mat="bronze", bands=(-2.2, 2.2), haft_mat="5a3a22", wrap="leather", cap_mat="gold",
                 head_at=9.5, haft_width=1.2),
    # A studded club: a tapering knotty log with iron studs, a short grip.
    "studded_club": dict(head="club", head_mat="wood", stud_mat="iron", haft_mat="wood", wrap="leather", grip=8,
                         head_at=9.5, haft_width=1.2),
    # A scepter: a gold ball crowned with three prongs and a ruby, a gold haft, a white grip.
    "scepter": dict(head="scepter", head_mat="gold", gem="c02040", haft_mat="gold", wrap="e8e4d8", cap_mat="gold"),
    # A crystal mace: a long faceted crystal on a silver haft, a blue grip.
    "crystal_mace": dict(head="crystal", head_mat="6ad0f0", haft_mat="silver", wrap="1a2a4a", cap_mat="silver",
                         head_at=9.5),
    # A bone club: a great knuckled bone, bound with a leather grip.
    "bone_club": dict(head="bone", head_mat="bone", haft_mat="bone", wrap="leather", cap_mat="bone", head_at=9.0,
                      haft_width=1.25),
}


def icon(name):
    return mace(DESIGNS[name]).render()
