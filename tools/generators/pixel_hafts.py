"""Hafts for the hand-pixelled hafted weapons (pixel_hafted.py, pixel_axes.py), after the classic
item icons' variety: plain ash with a leather grip, oak bound with iron rings, a knotted branch
lashed with rawhide, an iron shaft, ebony wound with gold, bone with knuckled joints, a soot-black
shaft with glowing cracks, and so on, each with its own pommel.

A haft runs down the diagonal two pixels wide, (row, row) lit and (row + 1, row) shaded, from the
head to a pommel at the bottom-right. Rings and knots stand a pixel proud of the shaft on both
sides; they are placed by rows up from the grip end, since the heads cover the top of the haft.
The pommel is a small block of pixels after the last row; a longer pommel shortens the shaft
so every weapon keeps the same length. Materials are three tones (light, mid, dark): woods, bone,
"steel", "gold", "leather", "main" and "accent" (the item's catalog colours), "glow" (the accent,
pulsing with the frame).
"""

import colorsys
import math

ANIM_FRAMES = 12
TONES = {
    "ash": ((184, 140, 90), (138, 100, 62), (94, 64, 40)),
    "oak": ((132, 92, 58), (98, 66, 40), (64, 42, 26)),
    "ebony": ((92, 72, 66), (60, 46, 42), (36, 28, 26)),
    "birch": ((222, 214, 192), (178, 168, 146), (124, 116, 100)),
    "bone": ((242, 234, 210), (208, 196, 166), (150, 138, 110)),
    "soot": ((78, 70, 66), (52, 46, 44), (32, 28, 28)),
    "leather": ((140, 94, 58), (100, 66, 40), (62, 40, 26)),
    "steel": ((214, 220, 226), (150, 160, 168), (86, 92, 100)),
    "gold": ((246, 218, 124), (214, 164, 56), (138, 96, 30)),
}
# Pommels: (dx, dy, tone) from the first pixel past the shaft, tone 0-2 or "g" for the glow.
POMMELS = {
    "knob": ((0, 0, 0), (1, 0, 1), (0, 1, 1), (1, 1, 2)),
    "knot": ((0, 0, 1), (1, 0, 1), (0, 1, 2), (1, 1, 2), (2, 1, 2), (-1, 1, 1)),
    "cap": ((0, 0, 0), (1, 0, 0), (2, 0, 1), (-1, 1, 0), (0, 1, 1), (1, 1, 1), (2, 1, 2), (0, 2, 2), (1, 2, 2)),
    "ball": ((0, 0, 0), (1, 0, 0), (2, 0, 1), (0, 1, 0), (1, 1, 1), (2, 1, 2), (0, 2, 1), (1, 2, 2), (2, 2, 2)),
    "spike": ((0, 0, 0), (1, 0, 1), (0, 1, 1), (1, 1, 2), (2, 1, 2), (1, 2, 1), (2, 2, 1), (3, 3, 2)),
    "gem": ((0, 0, 0), (1, 0, 0), (2, 0, 1), (0, 1, 0), (1, 1, "g"), (2, 1, 2), (0, 2, 1), (1, 2, 2), (2, 2, 2)),
}

HAFTS = {
    # Plain ash, a leather grip between two dark bindings, a wooden knob.
    "ash": {"shaft": "ash", "grip": "leather", "pommel": ("knob", "ash")},
    # A rough oak branch with knots and bark, lashed under the head with rawhide.
    "branch": {"shaft": "oak", "knots": (7, 10, 13), "lash": "accent", "pommel": ("knot", "oak")},
    # Oak bound with iron rings, a leather grip, an iron cap.
    "banded": {"shaft": "oak", "rings": ("steel", (7, 11)), "grip": "leather", "pommel": ("cap", "steel")},
    # Pale birch with silver rings and a grip in the item's colour.
    "birch": {"shaft": "birch", "rings": ("steel", (7, 10)), "grip": "accent", "pommel": ("knob", "steel")},
    # Oak with a collar and ball pommel in the head's metal.
    "collared": {"shaft": "oak", "rings": ("main", (6, 8)), "grip": "leather", "pommel": ("ball", "main")},
    # An iron shaft, a leather grip bound in the item's colour, a spiked pommel.
    "iron": {"shaft": "steel", "grip": "leather", "grip_ends": "accent", "pommel": ("spike", "steel")},
    # The head's metal twisted with the accent wound round it, a spike.
    "twisted": {"shaft": "main", "spiral": "accent", "grip": "accent", "grip_ends": "main", "pommel": ("spike", "main")},
    # Soot-black iron cracked with glowing seams, iron rings, an iron cap.
    "ember": {"shaft": "soot", "cracks": True, "rings": ("steel", (6, 11)), "grip": "leather", "pommel": ("cap", "steel")},
    # Ebony wound with a gold spiral, a grip in the item's colour, a gold pommel set with a gem.
    "gilded": {"shaft": "ebony", "spiral": "gold", "grip": "accent", "pommel": ("gem", "gold")},
    # Pale bone in gold rings with a gold cap.
    "ivory": {"shaft": "birch", "rings": ("gold", (6, 10)), "grip": "main", "grip_ends": "gold", "pommel": ("cap", "gold")},
    # Knuckled bone, a red-wrapped grip, a bone knob.
    "bone": {"shaft": "bone", "joints": 4, "grip": "accent", "pommel": ("knot", "bone")},
    # Dark wood with the item's colour coiled round it like a snake.
    "serpent": {"shaft": "oak", "coils": "main", "pommel": ("knob", "main")},
    # Pale birch in a gold collar, a grip in the item's colour, a gold cap.
    "seraph": {"shaft": "birch", "rings": ("gold", (6, 9)), "grip": "accent", "grip_ends": "gold", "pommel": ("cap", "gold")},
    # Ebony wound with the item's colour, a leather grip in gold bindings, a gold pommel set with a gem.
    "runed": {"shaft": "ebony", "spiral": "main", "grip": "leather", "grip_ends": "gold", "pommel": ("gem", "gold")},
    # Honey ash with a gold collar and an amber knob.
    "honey": {"shaft": "ash", "rings": ("gold", (6,)), "grip": "leather", "pommel": ("ball", "accent")},
}
STYLES = tuple(HAFTS)


def _ramp3(color):
    h, l, s = colorsys.rgb_to_hls(*(c / 255 for c in color))
    return tuple(tuple(round(c * 255) for c in colorsys.hls_to_rgb(h, max(0.05, min(0.92, l + dl)), s))
                 for dl in (0.14, 0.0, -0.16))


def pommel_length(style):
    """Pixels the pommel reaches past the shaft along the diagonal."""
    shape = POMMELS[HAFTS[style]["pommel"][0]]
    return max(max(dx, dy) for dx, dy, _ in shape) + 1


def draw(put, style, top, end, main, accent, frame=0):
    """Draw the haft from row top down to a pommel ending where a two-pixel knob after row `end`
    would, through put(x, y, (r, g, b))."""
    spec = HAFTS[style]
    pulse = 0.5 + 0.5 * math.cos(frame * math.tau / ANIM_FRAMES)
    glow_ramp = _ramp3(accent)
    glow = tuple(min(255, round(c * (1.0 + 0.35 * pulse)) + 30) for c in glow_ramp[0])
    tones = dict(TONES)
    tones.update({"main": _ramp3(main), "accent": _ramp3(accent), "glow": (glow, glow_ramp[0], glow_ramp[1])})
    last = end - (pommel_length(style) - 2)
    grip = range(last - 5, last) if "grip" in spec else range(0)
    shaft = tones[spec["shaft"]]
    ring_material, ring_rows = spec.get("rings", (None, ()))

    def pair(row, light, dark):
        put(row, row, light)
        put(row + 1, row, dark)

    def proud(row, light, dark):
        """A ring or knot standing a pixel proud on both sides."""
        put(row + 1, row - 1, light)
        put(row, row + 1, dark)

    for row in range(top, last + 1):
        step = row - top
        up = last - row
        light, dark = shaft[0], shaft[2]
        if up % 5 == 2:
            light = shaft[1]
        if row in grip:
            wrap = tones[spec["grip"]]
            light, dark = (wrap[0], wrap[2]) if row % 2 else (wrap[1], wrap[1])
        if spec.get("spiral") and row not in grip:
            wind = tones[spec["spiral"]]
            if up % 3 == 0:
                light = wind[0]
            elif up % 3 == 1:
                dark = wind[1]
        if spec.get("coils") and row not in grip and 1 <= up <= 13:
            coil = tones[spec["coils"]]
            if up % 3 != 1:
                light, dark = coil[0], coil[2]
        if spec.get("cracks") and row not in grip and up % 4 == 1:
            dark = tones["glow"][0]
        if spec.get("lash") and step <= 2:
            lash = tones[spec["lash"]]
            light, dark = (lash[0], lash[2]) if step % 2 == 0 else (lash[1], lash[2])
            if step % 2 == 0:
                proud(row, lash[1], lash[2])
        pair(row, light, dark)
        if up in spec.get("knots", ()):
            proud(row, shaft[1], shaft[2])
        if spec.get("joints") and up % spec["joints"] == 2 and row not in grip:
            pair(row, shaft[0], shaft[1])
            proud(row, shaft[0], shaft[2])
        if up in ring_rows:
            ring = tones[ring_material]
            pair(row, ring[0], ring[2])
            proud(row, ring[1], ring[2])
    if grip:
        ends = tones[spec.get("grip_ends", "oak" if spec["shaft"] != "oak" else "ebony")]
        for row in (grip.start - 1, grip.stop):
            pair(row, ends[1], ends[2])
    shape, material = spec["pommel"]
    knob = tones[material]
    p = last + 1
    for dx, dy, tone in POMMELS[shape]:
        put(p + dx, p + dy, tones["glow"][0] if tone == "g" else knob[tone])
