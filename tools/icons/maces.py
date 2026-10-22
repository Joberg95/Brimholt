"""Maces, hammers, and clubs in the OpenTibia pack's proportions (measured from 28 pack maces,
reference only), built as real weapons seen from the side and dressed from Brimholt's flavour pillars
(motifs.py): a haft on the diagonal to the bottom-right corner with a wrapped grip and a cap, and at
its top a head about 12-14 px across. Real heads: a flanged mace (a long core with flanged plates
standing out on both sides), a morning star (a ball with conical spikes), a war hammer (a square face,
a curved beak behind, a spike on top), a maul (a banded block), a club (a log thickening to the top).
The pillar shows in materials and decoration, never in an unreal shape.
"""
import math

import motifs
from core import ROUND, Icon, at, local, to_local

TIP = (1.6, 1.6)
END = 38.6
HEAD_AT = 9.0


def _shade_block(icon, cells, c, mat, half_along, rough=False, seed=1):
    """A solid lit from the top-left: the upper (lit) part bright, faces toward the tip darker."""
    for (x, y) in cells:
        t, v = to_local(c, x, y)
        tone = 0.62 - 0.3 * (t / half_along) + 0.1 * (v / 6.0)
        if rough:
            tone += 0.14 * (motifs.noise(x * 31 + y, seed) - 0.5)
        icon.put(x, y, mat, tone)


def _flanged(icon, c, d):
    """A long core with flanged plates standing out on both sides and a bright front flange."""
    mat = d["head"]
    for side in (1, -1):
        for start in (-4.0, -0.4):
            plate = local(c, lambda t, v, a=start: a <= t <= a + 3.2 and 2.0 <= v * side <= 2.0 + 3.6 * (1 - (t - a) / 3.6))
            _shade_block(icon, plate, c, mat, 4.5)
    core = local(c, lambda t, v: (t / 5.0) ** 2 + (v / 2.6) ** 2 <= 1)
    icon.dome(core, mat, height=2.0)
    icon.stroke([at(c, -4.2), at(c, 3.8)], lambda s: 0.5, lambda u, *_: 0.95, mat)
    icon.ball(*at(c, -5.4), 1.3, 1.3, mat)
    return core


def _morning_star(icon, c, d):
    """A ball with conical spikes all round."""
    mat = d["head"]
    for k in range(10):
        a = k * 2 * math.pi / 10 + 0.2
        base = (c[0] + math.cos(a) * 3.6, c[1] + math.sin(a) * 3.6)
        icon.stroke([base, (c[0] + math.cos(a) * 7.0, c[1] + math.sin(a) * 7.0)], lambda s: 1.25 * (1 - s) + 0.15,
                    ROUND, d.get("spike", mat))
    icon.ball(c[0], c[1], 4.6, 4.6, mat)
    return local(c, lambda t, v: t * t + v * v <= 4.6 ** 2)


def _war_hammer(icon, c, d):
    """A square striking face on one side, a curved beak on the other, a spike on top."""
    mat = d["head"]
    face = local(c, lambda t, v: abs(t) <= 2.6 and -6.4 <= v <= 1.2)
    _shade_block(icon, face, c, mat, 2.6)
    icon.shade(local(c, lambda t, v: abs(t) <= 2.6 and -6.4 <= v <= -5.4), 0.28)  # the striking face
    icon.stroke([at(c, -0.4, 1.0), at(c, 0.4, 5.4), at(c, 3.4, 8.0)], lambda s: 2.0 * (1 - s) + 0.25, ROUND, mat)
    icon.stroke([at(c, -2.4), at(c, -6.6)], lambda s: 1.3 * s + 0.25, ROUND, mat)
    return face


def _maul(icon, c, d):
    """A heavy block square to the haft, banded at both ends."""
    mat = d["head"]
    block = local(c, lambda t, v: abs(t) <= 3.8 and abs(v) <= 6.8)
    _shade_block(icon, block, c, mat, 3.8, d.get("rough", False), d.get("seed", 1))
    for band in (-5.0, 5.0):
        icon.dome(local(c, lambda t, v, b=band: abs(t) <= 4.1 and abs(v - b) <= 0.8), d.get("band", "iron"), height=1.0)
    return block


def _club(icon, c, d):
    """A log thickening toward the top, knotted, with studs or bands."""
    mat = d["head"]
    icon.stroke([at(c, -5.8), at(c, 10.5)], lambda s: 4.4 - s * 3.2, ROUND, mat,
                pattern=lambda length, u: -0.14 if int(length * 0.8) % 4 == 0 else 0.0)
    cells = local(c, lambda t, v: -5.8 <= t <= 10.5 and abs(v) <= 4.4 - (t + 5.8) / 16.3 * 3.2)
    for along, across in d.get("studs", ()):
        icon.ball(*at(c, along, across), 0.95, 0.95, d.get("stud", "iron"))
    return cells


HEADS = {"flanged": _flanged, "morning_star": _morning_star, "war_hammer": _war_hammer, "maul": _maul, "club": _club}


def mace(d):
    """Draws one design (a dict, see DESIGNS) and returns the Icon."""
    icon = Icon()
    seed = d.get("seed", 1)
    head = at(TIP, d.get("head_at", HEAD_AT))
    icon.stroke([at(head, -2.0), at(TIP, END)], lambda s: d.get("haft_width", 1.0), ROUND, d["haft"])
    icon.stroke([at(TIP, END - 10.0), at(TIP, END - 0.8)], lambda s: 1.15, ROUND, d["grip"],
                pattern=motifs.GRIPS[d.get("wrap", "wrap")]())
    if d.get("root_wrap"):
        motifs.root(icon, [at(TIP, d.get("head_at", HEAD_AT) + 6 + k * 2.6, 1.3 if k % 2 else -1.3) for k in range(8)],
                    "wood", width=0.8)
    icon.ball(*at(TIP, END), 1.35, 1.35, d.get("cap", "iron"))
    cells = HEADS[d["shape"]](icon, head, d)
    # The pillar's dressing.
    if d.get("runes"):
        motifs.runes(icon, at(head, -0.4, 5.0), at(head, -0.4, -5.6), d["runes"])
    if d.get("cracks"):
        motifs.crack_cells(icon, cells, d["cracks"], seed, count=3)
    if d.get("seam"):
        motifs.seam(icon, at(head, -2.6, 5.4), at(head, 2.6, -5.4), d["seam"], seed)
    if d.get("moss"):
        tops = sorted(cells, key=lambda c: to_local(head, *c)[0])[: max(1, len(cells) // 3)]
        motifs.moss(icon, [(x + 0.5, y + 0.5) for (x, y) in tops[::4]], seed)
    if d.get("crystals"):
        for k, (along, across) in enumerate(((-4.0, -4.6), (-4.6, 4.4), (0.6, -6.6), (0.8, 6.4), (-6.8, 0.0))):
            base = at(head, along * 0.4, across * 0.4)
            motifs.crystal(icon, base, at(head, along, across), d["crystals"], width=1.4)
    if d.get("lashing"):
        for k in (-1, 1):
            icon.stroke([at(head, -4.0, k * 3.0), at(head, 4.0, -k * 3.0)], lambda s: 0.6, ROUND, "leather")
    for band, mat in d.get("bindings", ()):  # cord bound round the head
        icon.stroke([at(head, band, 4.6), at(head, band, -4.6)], lambda s: 0.7, ROUND, mat, pattern=motifs.reed())
    icon.stroke([at(head, 2.6), at(head, 4.6)], lambda s: 1.5, ROUND, d.get("collar", "iron"),
                pattern=motifs.GRIPS[d.get("collar_wrap", "plain")]())
    if d.get("tassel"):
        motifs.tassel(icon, at(head, 5.2, 0.8), d["tassel"], d.get("collar", "iron"))
    return icon


# Real maces, hammers, and clubs, each dressed from one of Brimholt's flavour pillars.
DESIGNS = {
    # Runes and old stone: an iron maul with silver runes across its block, a knotwork collar and grip.
    "rune_maul": dict(shape="maul", head="iron", band="bronze", runes="silver", collar="bronze", collar_wrap="knotwork",
                      haft="wood", grip="bronze", wrap="knotwork", cap="bronze", head_at=10.0),
    # Runes and old stone: a barrow mace, flanged bog bronze dug from a mound, a bone haft, a gold cap.
    "barrow_mace": dict(shape="flanged", head="verdigris", collar="gold", haft="bone", grip="leather", cap="gold",
                        head_at=10.0, seed=3),
    # Runes and old stone: a waystone maul, a rough stone block lashed to the haft, a glowing rune seam.
    "waystone_maul": dict(shape="maul", head="runestone", band="leather", rough=True, seam="glow_rune", lashing=True,
                          collar="leather", collar_wrap="wrap", haft="wood", grip="leather", cap="runestone",
                          head_at=10.0, seed=5),
    # Ember: a morning star of ember glass cracked through with fire, iron spikes, a dark haft.
    "ember_star": dict(shape="morning_star", head="emberglass", spike="iron", cracks="glow_ember", haft="2a2a32",
                       grip="iron", cap="glow_ember", head_at=9.5, seed=2),
    # Reed: a bog-oak club bound with reed cord, a lake-blue stud, a reed grip.
    "reed_club": dict(shape="club", head="4a3020", bindings=((-2.5, "reed"), (2.8, "reed")), studs=((-0.2, 2.2),),
                      stud="lakestone", haft="4a3020", grip="reed", wrap="reed", cap="lakestone", collar="reed",
                      head_at=9.5, haft_width=1.2),
    # Grey castles: a war hammer, a grey steel face and beak, a spike on top, a gold collar, a banner tassel.
    "castle_hammer": dict(shape="war_hammer", head="steel", collar="gold", haft="4a2e1e", grip="banner", cap="gold",
                          tassel="banner", head_at=10.0),
    # The Hollow: an obsidian mace whose flanges are violet crystals.
    "hollow_mace": dict(shape="morning_star", head="hollowglass", spike="hollowglass", crystals="glow_hollow",
                        haft="1a1a22", grip="hollowglass", cap="glow_hollow", collar="hollowglass", head_at=9.5, seed=4),
    # The land that wakes: a gnarled root club grown over with moss, green light in its cracks.
    "woken_club": dict(shape="club", head="wood", moss=True, cracks="glow_moss", root_wrap=True, haft="5a3a22",
                       grip="wood", wrap="plain", cap="moss", collar="wood", head_at=9.5, haft_width=1.2, seed=7),
}


def icon(name):
    return mace(DESIGNS[name]).render()
