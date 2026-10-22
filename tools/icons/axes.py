"""Axes in the OpenTibia pack's proportions (measured from 67 pack axes, reference only), built as real
axes and dressed from Brimholt's flavour pillars (motifs.py). Anatomy, square to the haft at its top
end: the eye (a socket round the haft, the haft ending just above it), a narrow cheek flaring out to
the bit, a long convex cutting edge running parallel to the haft, a fairly straight top line and a
bottom line curving down into the beard; behind the eye a poll, a spike, or a second bit. The pillar
shows in materials and decoration (runes, verdigris, lashing, fire cracks, reed cord, a tassel,
crystals, moss), never in an unreal shape.
"""
import motifs
from core import ROUND, Icon, at, local, to_local

TIP = (4.2, 0.4)  # right of the corner, so the big head hanging to the lower left fits
HEAD_AT = 11.0  # the head's centre along the diagonal; the haft starts just above it
END = 36.6
SCALE = 1.6  # head sizes in the designs, scaled to the pack's (about 20 px along the haft, 12 out)


def _bit(icon, centre, d, side, mat):
    """One bit, in haft coordinates (t along the haft, positive toward the grip; w out from it):
    `top` and `beard` are how far the edge reaches above and below the eye, `depth` how far out the
    edge is, `neck` the cheek's half-height at the eye, `belly` how much the edge bulges."""
    depth, top, beard = d["depth"] * SCALE, d["top"] * SCALE, d["beard"] * SCALE
    neck, belly = d.get("neck", 1.8) * SCALE, d.get("belly", 1.4) * SCALE

    def inside(t, v, margin=0.0):
        w = v * side
        if w < 0.5:
            return False
        f = w / depth
        upper = neck + (top - neck) * f ** 1.8        # the top line flaring up into a sharp toe
        lower = neck + (beard - neck) * f ** 2.6      # the bottom line sweeping down into the heel
        if not -upper <= t <= lower:
            return False
        mid, half = (lower - upper) / 2, (lower + upper) / 2
        return w <= depth - margin + belly * (1 - ((t - mid) / max(half, 0.01)) ** 2) - belly * 0.25

    cells = local(centre, inside)
    rim = cells - local(centre, lambda t, v: inside(t, v, 1.0))
    bevel = local(centre, lambda t, v: inside(t, v, 1.0)) - local(centre, lambda t, v: inside(t, v, 2.6))
    grind = local(centre, lambda t, v: inside(t, v, 2.6)) - local(centre, lambda t, v: inside(t, v, 3.4))
    rough = d.get("rough", False)
    for (x, y) in cells:
        t, v = to_local(centre, x, y)
        f = v * side / depth
        # Forged: dark at the eye, lighter toward the edge, the upper (lit) part brighter; stone stays rough.
        tone = 0.26 + 0.4 * f - 0.18 * (t / max(top, beard))
        if rough:
            tone += 0.12 * (motifs.noise(x * 31 + y, d.get("seed", 1)) - 0.5)
        elif (x, y) in rim:
            tone = 0.95 - 0.1 * (t / max(top, beard))
        elif (x, y) in bevel:
            tone += 0.16
        elif (x, y) in grind:
            tone -= 0.14  # the grind line where the bevel starts
        icon.put(x, y, mat, tone)
    return cells


def axe(d):
    """Draws one axe design (a dict, see DESIGNS) and returns the Icon."""
    icon = Icon()
    seed = d.get("seed", 1)
    head = at(TIP, d.get("head_at", HEAD_AT))
    start = d.get("head_at", HEAD_AT) - 3.6  # the haft pokes just above the eye
    end = END - d.get("shorten", 0)
    icon.stroke([at(TIP, start), at(TIP, end)], lambda s: 1.05, ROUND, d["haft"])
    if d.get("grip"):
        icon.stroke([at(TIP, end - 11), at(TIP, end - 0.6)], lambda s: 1.15, ROUND, d["grip"],
                    pattern=motifs.GRIPS[d.get("wrap", "wrap")]())
    if d.get("root_wrap"):
        motifs.root(icon, [at(TIP, start + 7 + k * 2.6, 1.3 if k % 2 else -1.3) for k in range(9)], "wood", width=0.8)
    icon.ball(*at(TIP, end), 1.3, 1.3, d.get("cap", d["socket"]))
    cells = _bit(icon, head, d, -1, d["head"])
    back = d.get("back")
    if back == "bit":
        cells |= _bit(icon, head, dict(d, **d.get("back_bit", {})), 1, d["head"])
    elif back == "spike":
        icon.stroke([at(head, 0.4, 1.0), at(head, 1.6, 9.4)], lambda s: 2.4 * (1 - s) + 0.25, ROUND, d["head"])
    elif back == "poll":  # a flat hammer face behind the eye
        icon.dome(local(head, lambda t, v: abs(t - 0.4) <= 2.6 and 0.5 <= v <= 4.6), d["head"], height=1.6)
    # The pillar's dressing.
    if d.get("runes"):
        motifs.runes(icon, at(head, 0.6, -3.4), at(head, 0.6, -d["depth"] * SCALE + 2.0), d["runes"])
    if d.get("cracks"):
        motifs.crack_cells(icon, cells, d["cracks"], seed, count=3)
    if d.get("seam"):
        motifs.seam(icon, at(head, -d["top"] * SCALE + 3, -3.4), at(head, d["beard"] * SCALE - 3, -d["depth"] * SCALE + 3),
                    d["seam"], seed)
    if d.get("moss"):
        tops = sorted(cells, key=lambda c: to_local(head, *c)[0])[: max(1, len(cells) // 3)]
        motifs.moss(icon, [(x + 0.5, y + 0.5) for (x, y) in tops[::4]], seed)
    if d.get("crystals"):
        for k, (along, across) in enumerate(((-6.4, -8.0), (-5.0, 7.0), (4.8, -12.8))):
            base = at(head, along, across)
            motifs.crystal(icon, base, at(base, -2.8 - motifs.noise(k, seed), across * 0.15), d["crystals"])
    if d.get("lashing"):  # leather thongs crossed over the eye, binding a stone head
        for k in (-1, 1):
            icon.stroke([at(head, -3.8, k * 3.2), at(head, 3.8, -k * 3.2)], lambda s: 0.6, ROUND, "leather")
    # The eye: a band round the haft, two rivets.
    icon.stroke([at(head, -3.2), at(head, 3.4)], lambda s: 2.1, ROUND, d["socket"],
                pattern=motifs.GRIPS[d.get("socket_wrap", "plain")]())
    for along in (-1.2, 1.4):
        icon.ball(*at(head, along, 0.5), 0.55, 0.55, d.get("rivet", "silver"))
    if d.get("tassel"):
        motifs.tassel(icon, at(head, 4.0, 0.8), d["tassel"], d["socket"])
    return icon


# Real axe types, each dressed from one of Brimholt's flavour pillars.
DESIGNS = {
    # Runes and old stone: a borderland bearded axe, iron, a long hooked beard, silver runes across the
    # cheek, a poll behind, a knotwork-bound eye and grip.
    "bearded_axe": dict(depth=9.5, top=3.4, beard=8.6, belly=1.2, head="iron", runes="silver", back="poll",
                        socket="bronze", socket_wrap="knotwork", haft="wood", grip="bronze", wrap="knotwork"),
    # Runes and old stone: a barrow labrys, two matched bits of green bog bronze with gold runes, a bone haft.
    "barrow_axe": dict(depth=8.2, top=5.6, beard=5.8, belly=1.8, head="verdigris", runes="gold", back="bit",
                       socket="verdigris", rivet="gold", haft="bone", grip="leather", seed=3),
    # Runes and old stone: a stone axe, a polished stone wedge lashed with crossed thongs, a glowing rune seam.
    "waystone_axe": dict(depth=8.4, top=4.2, beard=4.6, neck=2.6, belly=2.0, rough=True, head="runestone",
                         seam="glow_rune", lashing=True, socket="leather", socket_wrap="wrap", rivet="bronze",
                         haft="wood", grip="leather", seed=5),
    # Ember: a battle axe, a broad ember-glass bit cracked through with fire, a spike behind, an iron eye.
    "ember_axe": dict(depth=10.0, top=5.4, beard=6.6, belly=1.6, head="emberglass", cracks="glow_ember", back="spike",
                      socket="iron", haft="2a2a32", grip="iron", seed=2),
    # Reed: a fisher's hatchet, a small steel head on a short haft, its eye and grip bound in reed cord.
    "reed_axe": dict(depth=7.0, top=2.8, beard=4.6, belly=1.0, head="steel", back="poll", socket="reed",
                     socket_wrap="reed", rivet="lakestone", haft="c8b08a", grip="reed", wrap="reed", cap="lakestone",
                     head_at=13.0),
    # Grey castles: a broad axe, a wide grey steel bit with a spike behind, a gold eye, a banner tassel.
    "castle_axe": dict(depth=9.6, top=6.0, beard=7.0, belly=1.0, head="steel", back="spike", socket="gold",
                       rivet="gold", haft="4a2e1e", grip="banner", tassel="banner"),
    # The Hollow: a great double axe of obsidian, the back bit smaller, violet crystals breaking out of it.
    "hollow_axe": dict(depth=9.6, top=6.2, beard=6.4, belly=2.0, head="hollowglass", back="bit",
                       back_bit=dict(depth=6.6, top=4.0, beard=4.2), crystals="glow_hollow", socket="hollowglass",
                       rivet="glow_hollow", haft="1a1a22", grip="hollowglass", cap="glow_hollow", seed=4),
    # The land that wakes: a stone wedge grown over with moss, green light in its cracks, a root down the haft.
    "woken_axe": dict(depth=8.6, top=4.0, beard=5.4, neck=2.4, belly=1.6, rough=True, head="runestone", moss=True,
                      cracks="glow_moss", lashing=True, socket="wood", rivet="moss", haft="5a3a22", root_wrap=True,
                      cap="moss", seed=7),
}


def icon(name):
    return axe(DESIGNS[name]).render()
