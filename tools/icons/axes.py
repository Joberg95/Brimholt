"""Axes in the OpenTibia pack's proportions (measured from 67 pack axes, reference only), designed from
Brimholt's flavour pillars (motifs.py): a 3 px haft on the diagonal to the bottom-right corner, a head
about 17 px across square to the haft at its top end, the blade fanning out to the lower left, forged
dark at the socket and bright at the honed edge. Each axe takes its pillar's materials and motif:
runes, knotwork, lashing, fire cracks, reed cord, a banner tassel, Hollow crystal, moss and roots.
"""
import motifs
from core import ROUND, Icon, at, local, to_local

TIP = (1.6, 1.6)
HAFT = (5.0, 38.5)  # where the haft starts and ends along the diagonal
SCALE = 1.6  # head sizes in the designs are a fraction of the pack's head; this brings them to its size


def _blade(icon, centre, d, side, mat):
    """One bit: a fan from the haft (across 0) out to its edge (across `depth` on `side`), widening from
    the neck to `spread` either way along the haft, the edge bowed by `curve`, dropped toward the grip
    by `beard`, and knapped at random when `chipped`. Returns its cells."""
    depth, spread, neck = d["depth"] * SCALE, d["spread"] * SCALE, d.get("neck", 1.6) * 1.3
    curve, beard, seed = d.get("curve", 1.6) * SCALE, d.get("beard", 0.0) * SCALE, d.get("seed", 1)

    def inside(t, v, margin=0.0):
        w = v * side
        if w < 0.4:
            return False
        t = t - beard * (w / depth) ** 2
        h = neck + (spread - neck) * (w / depth) ** 1.5
        bite = 1.3 * (motifs.noise(int(t + 20), seed) > 0.6) if d.get("chipped") else 0.0
        return abs(t) <= h and w <= depth - curve * (t / max(h, 0.01)) ** 2 - margin - bite

    cells = local(centre, inside)
    rim = cells - local(centre, lambda t, v: inside(t, v, 1.1))
    bevel = local(centre, lambda t, v: inside(t, v, 1.1)) - local(centre, lambda t, v: inside(t, v, 3.2))
    for (x, y) in cells:
        t, v = to_local(centre, x, y)
        w = v * side / depth
        # Forged: darker at the socket, lighter toward the edge, the upper (lit) half brighter. Stone
        # has no honed edge.
        tone = 0.28 + 0.38 * w - 0.22 * (t / spread)
        if (x, y) in bevel and not d.get("chipped"):
            tone += 0.18 - (0.22 if w < 0.75 and abs(t) > spread * 0.2 else 0.0)
        if (x, y) in rim and not d.get("chipped"):
            tone = 0.92 - 0.12 * (t / spread)
        icon.put(x, y, mat, tone)
    return cells


def axe(d):
    """Draws one axe design (a dict, see DESIGNS) and returns the Icon."""
    icon = Icon()
    seed = d.get("seed", 1)
    start, end = HAFT[0], HAFT[1]
    head = at(TIP, start + d.get("head_at", 4.0) * 1.9)
    grip_from = start + (end - start) * 0.62
    icon.stroke([at(TIP, start), at(TIP, end)], lambda s: 1.05, ROUND, d["haft"])
    if d.get("grip"):
        icon.stroke([at(TIP, grip_from), at(TIP, end - 0.6)], lambda s: 1.15, ROUND, d["grip"],
                    pattern=motifs.GRIPS[d.get("wrap", "wrap")]())
    if d.get("root_wrap"):  # a root winding down the haft
        points = [at(TIP, start + 6 + k * 3.0, 1.3 if k % 2 else -1.3) for k in range(8)]
        motifs.root(icon, points, "wood", width=0.8)
    icon.ball(*at(TIP, end), 1.3, 1.3, d.get("cap", d["collar"]))
    cells = _blade(icon, head, d, -1, d["head"])
    back = d.get("back")
    if back == "bit":
        cells |= _blade(icon, head, dict(d, depth=d.get("back_depth", d["depth"])), 1, d["head"])
    elif back == "spike":
        icon.stroke([at(head, 0, 0.8), at(head, -0.6, 8.0)], lambda s: 2.2 * (1 - s) + 0.2, ROUND, d["head"])
    elif back == "knob":
        icon.ball(*at(head, 0, 2.6), 2.1, 2.1, d["collar"])
    # The pillar's motif on the head.
    if d.get("runes"):
        a, b = at(head, -0.6, -2.4), at(head, -1.4, -d["depth"] * SCALE + 1.6)
        icon.stroke([a, b], lambda s: 1.15, lambda u, *_: 0.06, d["head"])
        motifs.runes(icon, a, b, d["runes"])
    if d.get("cracks"):
        motifs.crack_cells(icon, cells, d["cracks"], seed, count=3)
    if d.get("seam"):
        motifs.seam(icon, at(head, -2.0, -2.0), at(head, 1.5, -d["depth"] * SCALE + 1.5), d["seam"], seed)
    if d.get("moss"):
        tops = sorted(cells, key=lambda c: to_local(head, *c)[0])[: max(1, len(cells) // 4)]
        motifs.moss(icon, [(x + 0.5, y + 0.5) for (x, y) in tops[::3]], seed)
    if d.get("crystals"):
        for k, (along, across) in enumerate(((-3.0, -3.0), (-3.6, 2.6), (-2.4, -6.0))):
            base = at(head, along, across)
            motifs.crystal(icon, base, at(base, -3.2 - motifs.noise(k, seed), across * 0.25), d["crystals"])
    icon.stroke([at(head, -3.0), at(head, 3.0)], lambda s: 1.75, ROUND, d["collar"],
                pattern=motifs.GRIPS[d.get("collar_wrap", "plain")]())
    if d.get("tassel"):
        motifs.tassel(icon, at(head, 3.4, 0.6), d["tassel"], d["collar"])
    return icon


# Each axe is drawn from one of Brimholt's flavour pillars, so it is ours and not a pack archetype.
DESIGNS = {
    # Runes and old stone: a borderland bearded axe, iron, silver runes across the bit, a knotwork collar
    # and grip, a bronze knob behind.
    "bearded_axe": dict(depth=8.4, spread=4.6, beard=3.6, curve=1.2, head="iron", runes="silver", back="knob",
                        collar="bronze", collar_wrap="knotwork", haft="wood", grip="bronze", wrap="knotwork"),
    # Runes and old stone: a barrow axe, a wide crescent of green bog bronze with gold runes, a bone haft.
    "barrow_axe": dict(depth=8.2, spread=6.4, neck=1.2, curve=3.0, head="verdigris", runes="gold", collar="verdigris",
                       haft="bone", grip="leather", seed=3),
    # Runes and old stone: a waystone axe, a knapped stone head lashed to the haft, a glowing rune seam.
    "waystone_axe": dict(depth=7.6, spread=5.0, curve=1.0, chipped=True, head="runestone", seam="glow_rune",
                         collar="leather", collar_wrap="wrap", haft="wood", grip="leather", seed=5),
    # Ember: an ember-glass bit cracked through with fire, a short back bit, an iron collar.
    "ember_axe": dict(depth=8.6, spread=4.8, curve=2.2, beard=1.0, back="bit", back_depth=4.0, head="emberglass",
                      cracks="glow_ember", collar="iron", haft="2a2a32", grip="iron", seed=2),
    # Reed: a lake axe, a slim steel bit, its collar and grip bound in reed cord, a lake-blue cap.
    "reed_axe": dict(depth=7.8, spread=3.8, curve=1.4, beard=1.8, head="steel", collar="reed", collar_wrap="reed",
                     haft="c8b08a", grip="reed", wrap="reed", cap="lakestone"),
    # Grey castles: a castle axe, grey steel with a back spike, a gold collar, a banner tassel.
    "castle_axe": dict(depth=8.8, spread=4.4, curve=1.6, back="spike", head="steel", collar="gold", haft="4a2e1e",
                       grip="banner", tassel="banner"),
    # The Hollow: an obsidian double bit with violet crystals breaking out of it.
    "hollow_axe": dict(depth=7.6, spread=5.2, curve=2.0, back="bit", head="hollowglass", crystals="glow_hollow",
                       collar="hollowglass", haft="1a1a22", grip="hollowglass", cap="glow_hollow", seed=4),
    # The land that wakes: a stone head grown over with moss, green light in its cracks, a root winding
    # down the haft.
    "woken_axe": dict(depth=7.8, spread=5.0, curve=1.2, chipped=True, head="runestone", moss=True,
                      cracks="glow_moss", collar="wood", haft="5a3a22", root_wrap=True, cap="moss", seed=7),
}


def icon(name):
    return axe(DESIGNS[name]).render()
