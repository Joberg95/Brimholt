"""Bows and crossbows in the OpenTibia pack's construction (pack bows studied, reference only): the
limbs a 2-3 px arc from the top-right corner to the bottom-left, bulging toward the top-left, a
straight 1 px string from tip to tip, a wrapped grip at the middle of the arc, small nocks at the
tips. A crossbow is a stock on the diagonal with the prod across its front. They differ in limbs
(depth of the arc, recurved tips, thickness), grip, nocks, an arrow on the string, and materials.
"""
import math

from core import ROUND, Icon, at, piecewise

TOP, BOTTOM = (27.6, 3.4), (3.4, 27.6)  # the limb tips
LIMB = piecewise([(-1, 0.2), (-0.3, 0.55), (0.35, 1.0), (1, 0.45)])


def _arc(depth, recurve=0.0, n=40):
    """Points of the limbs from the top tip to the bottom tip: a curve bowed `depth` px toward the
    top-left, the tips curled back `recurve` px."""
    points = []
    for i in range(n):
        s = i / (n - 1)
        x = TOP[0] + (BOTTOM[0] - TOP[0]) * s
        y = TOP[1] + (BOTTOM[1] - TOP[1]) * s
        bow = depth * math.sin(math.pi * s)
        curl = recurve * (max(0.0, 1 - s * 5) ** 2 + max(0.0, s * 5 - 4) ** 2)
        x, y = x - bow * 0.7071 + curl * 0.7071, y - bow * 0.7071 + curl * 0.7071
        points.append((x, y))
    return points


def bow(d):
    """Draws one bow design (a dict, see DESIGNS) and returns the Icon."""
    icon = Icon()
    limbs = _arc(d["depth"], d.get("recurve", 0.0))
    top, bottom = limbs[0], limbs[-1]
    if d.get("arrow"):
        icon.stroke([at((16.0, 16.0), 11.0), at((16.0, 16.0), -13.5)], lambda s: 0.5, lambda u, *_: 0.7, "wood")
        tip = at((16.0, 16.0), -13.5)
        icon.stroke([tip, at(tip, 2.4)], lambda s: 1.2 * s + 0.2, ROUND, "steel")
        for across in (1.0, -1.0):
            icon.stroke([at((16.0, 16.0), 8.5), at((16.0, 16.0), 11.0, across * 1.6)], lambda s: 0.6, ROUND, d["arrow"])
    icon.stroke([top, bottom], lambda s: 0.42, lambda u, *_: 0.85, d.get("string", "e8e4d8"))
    thick = d.get("thick", 1.25)
    icon.stroke(limbs, lambda s: thick * (0.6 + 0.5 * math.sin(math.pi * s)), LIMB, d["limb"])
    if d.get("inner"):
        icon.stroke(limbs[4:-4], lambda s: thick * 0.35 * math.sin(math.pi * s) + 0.15, lambda u, *_: 0.85, d["inner"])
    middle = limbs[len(limbs) // 2]
    grip = [limbs[len(limbs) // 2 - 4], middle, limbs[len(limbs) // 2 + 4]]
    icon.stroke(grip, lambda s: thick + 0.45, ROUND, d["grip"], pattern=lambda length, u: -0.28 if int(length) % 2 == 0 else 0.05)
    for tip in (top, bottom):
        icon.ball(tip[0], tip[1], d.get("nock_size", 1.2), d.get("nock_size", 1.2), d["nock"])
    return icon


def crossbow(d):
    """A crossbow: a stock down the diagonal, the prod across its front, the string drawn back."""
    icon = Icon()
    front, back = at((1.6, 1.6), 7.5), at((1.6, 1.6), 38.0)
    icon.stroke([front, back], lambda s: 1.5 + s * 0.7, ROUND, d["stock"])
    icon.stroke([at(back, -3.0), back], lambda s: 2.3, ROUND, d["fitting"])
    prod = [at(front, 3.4, 9.5), at(front, -2.2, 0), at(front, 3.4, -9.5)]
    icon.stroke([prod[0], at(front, 8.5), prod[2]], lambda s: 0.42, lambda u, *_: 0.85, "e8e4d8")
    icon.stroke(prod, lambda s: 1.25 * (0.6 + 0.6 * math.sin(math.pi * s)), LIMB, d["prod"])
    icon.stroke([at(front, -1.2), at(front, -3.4)], lambda s: 1.3, ROUND, d["fitting"])
    icon.ball(*at(front, 15.0, -1.8), 1.0, 1.0, d["fitting"])
    icon.stroke([at(front, 15.0, -1.5), at(front, 17.5, -3.2)], lambda s: 0.6, ROUND, d["fitting"])
    return icon


# Each design its own bow: limbs, curve, tips, grip, and materials all differ.
DESIGNS = {
    # A short bow: a shallow plain wooden arc, a leather grip, wooden nocks.
    "short_bow": dict(depth=5.0, limb="wood", grip="leather", nock="wood", thick=1.1),
    # A longbow: a deep tall arc of yew, a green grip, horn nocks.
    "longbow": dict(depth=8.5, limb="8a5a2a", grip="3a6a2a", nock="bone"),
    # A recurve bow: dark limbs with curled-back tips, gold nocks, a red grip.
    "recurve_bow": dict(depth=6.5, recurve=3.2, limb="4a2e1e", grip="9a2a22", nock="gold"),
    # A horn bow: thick bone limbs, an iron-banded grip, iron nocks.
    "horn_bow": dict(depth=6.0, limb="bone", grip="iron", nock="iron", thick=1.5),
    # An elven bow: slender silver limbs with leaf-green inlay, a white grip.
    "elven_bow": dict(depth=7.5, recurve=1.8, limb="silver", inner="4aa040", grip="e8e4d8", nock="4aa040", thick=1.05),
    # A composite bow: wood limbs faced with horn, a black grip, bronze nocks.
    "composite_bow": dict(depth=7.0, limb="6a4a2a", inner="bone", grip="2a2a32", nock="bronze"),
    # An ember bow: copper limbs, gold nocks, an arrow fletched in orange on the string.
    "ember_bow": dict(depth=6.8, limb="copper", grip="5a1a12", nock="gold", arrow="ff8a20"),
}
CROSSBOWS = {
    # A crossbow: a wooden stock, a steel prod, iron fittings, a trigger underneath.
    "crossbow": dict(stock="wood", prod="steel", fitting="iron"),
}


def icon(name):
    return (crossbow(CROSSBOWS[name]) if name in CROSSBOWS else bow(DESIGNS[name])).render()


DESIGNS.update({name: None for name in CROSSBOWS})
