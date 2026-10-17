"""Hand-pixelled sword icons (32x32) on the classic diagonal: the tip at the top-left, the blade
running down to a guard, a wrapped grip, and a pommel at the bottom-right. Every sword has its own
design (STYLES): blade shape, guard, pommel, and extras.

A blade is drawn row by row along the diagonal: each row is its cross-section, from the lit upper
edge on the left to the shaded lower edge on the right, so the 45-degree edges stay clean. Letters:

  1-5 blade (the item's main colour, 1 the bright edge)   y Y z guard (the item's light colour)
  a A b inlay (the item's accent)                          g a gem that glows (pulses)
  w W grip wrap (leather)    s S bone                      . nothing

Blades: `blade` is the list of cross-sections from the tip. Extras: `curve` (a sabre's bow),
`wave` (a wavy blade), `teeth` (saw teeth on the lower edge every n rows), `fangs` (long hooked
teeth), `hook` (a fang near the tip).
Guards: cross, wing (arms swept toward the tip), crescent (swept toward the hilt), disc, lion
(a gold mask with eyes), spiked (a cross with barbs), trident (a crescent with prongs).
Pommels: ball, gem, ring, spike, skull.

The silhouette gets a dark outline at the end. make_sprites.py calls icon(style, colors, frame).
"""

import colorsys
import math

ANIM_FRAMES = 12
OUTLINE = (24, 18, 20)
FIXED = {"w": (122, 86, 54), "W": (78, 54, 34), "s": (236, 228, 206), "S": (180, 168, 140)}


def _blade(body, length, tip="12", taper=3):
    """Cross-sections from the tip: a taper of `taper` rows growing to `body`, then `body`."""
    rows = []
    for index in range(length):
        if index < taper:
            keep = max(1, round(len(body) * (index + 1) / (taper + 1)))
            rows.append(tip[:keep] if keep <= len(tip) else body[:keep])
        else:
            rows.append(body)
    return rows


STYLES = {
    "copper": {"tip": 7, "blade": _blade("1234", 11), "guard": ("cross", 3), "pommel": "ball", "grip": 4},
    "short": {"tip": 9, "blade": _blade("12534", 9, "12", 2), "guard": ("disc", 2), "pommel": "ring", "grip": 4},
    "falchion": {"tip": 5, "blade": ["1", "12", "123", "1234", "12344", "123445", "123445", "12344", "12344", "1234",
                                     "1234", "1234", "1234"], "guard": ("cross", 2), "pommel": "ball", "grip": 5},
    "longsword": {"tip": 3, "blade": _blade("12534", 16), "guard": ("wing", 4), "pommel": "gem", "grip": 5},
    "arming": {"tip": 5, "blade": _blade("13234", 13), "guard": ("lion", 3), "pommel": "spike", "grip": 4},
    "curved": {"tip": 4, "blade": _blade("1234", 14), "guard": ("crescent", 3), "pommel": "ball", "grip": 5,
               "curve": 2.2},
    "cleaver": {"tip": 4, "blade": ["12233", "122334", "1223344", "1223344", "1223344", "1223344", "1223344", "122334",
                                    "122334", "12334", "12334", "1234", "1234"], "guard": ("cross", 2), "pommel": "ring",
                "grip": 5},
    "serrated": {"tip": 4, "blade": _blade("12a34", 14), "guard": ("spiked", 4), "pommel": "skull", "grip": 5,
                 "teeth": 3},
    "estoc": {"tip": 3, "blade": _blade("134", 16, "1", 2), "guard": ("disc", 2), "pommel": "gem", "grip": 5},
    "fang": {"tip": 7, "blade": _blade("12a4", 11), "guard": ("wing", 3), "pommel": "gem", "grip": 4,
             "curve": 1.0, "hook": True, "glow": True},
    "sanguine": {"tip": 5, "blade": _blade("12yA4", 13), "guard": ("crescent", 4), "pommel": "gem", "grip": 5,
                 "glow": True},
    "rime": {"tip": 3, "blade": _blade("125345", 16), "guard": ("cross", 5), "pommel": "gem", "grip": 5,
             "curve": 1.6},
    "drakefang": {"tip": 3, "blade": _blade("12345", 16), "guard": ("wing", 5), "pommel": "spike", "grip": 5,
                  "fangs": 3},
    "tide": {"tip": 3, "blade": _blade("12a45", 16), "guard": ("trident", 4), "pommel": "gem", "grip": 5,
             "wave": 1.0, "glow": True},
    "void": {"tip": 3, "blade": _blade("12aA45", 16), "guard": ("spiked", 5), "pommel": "skull", "grip": 5,
             "curve": 3.0},
    "grand": {"tip": 3, "blade": _blade("12yA45", 15), "guard": ("lion", 4), "pommel": "gem", "grip": 5,
              "glow": True},
}
STYLE_NAMES = tuple(STYLES)
GLOWING = tuple(style for style, spec in STYLES.items() if spec.get("glow"))


def _rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def _ramp(color):
    h, l, s = colorsys.rgb_to_hls(*(c / 255 for c in color))
    return [tuple(round(c * 255) for c in colorsys.hls_to_rgb(h, max(0.03, min(0.96, l + dl)), s))
            for dl in (0.24, 0.1, 0.0, -0.13, -0.24)]


def icon(style, colors, frame=0):
    """RGBA rows of a 32x32 sword icon."""
    spec = STYLES[style]
    main, light, accent = (_rgb(c) for c in colors)
    blade, guard, inlay = _ramp(main), _ramp(light), _ramp(accent)
    glow = 0.5 + 0.5 * math.cos(frame * math.tau / ANIM_FRAMES) if spec.get("glow") else 0.6
    palette = {str(i + 1): blade[i] for i in range(5)}
    palette.update({"y": guard[0], "Y": guard[2], "z": guard[4], "a": inlay[1], "A": inlay[2], "b": inlay[4], **FIXED,
                    "g": tuple(min(255, round(c * (0.75 + 0.45 * glow))) for c in inlay[0])})
    pixels = [[None] * 32 for _ in range(32)]

    def put(x, y, letter):
        if letter != "." and 0 <= x < 32 and 0 <= y < 32:
            pixels[y][x] = palette[letter] + (255,)

    # The blade, row by row from the tip.
    tip, rows = spec["tip"], spec["blade"]
    length = len(rows)
    for index, section in enumerate(rows):
        y = tip + index
        bow = round(spec.get("curve", 0.0) * math.sin(math.pi * index / max(1, length - 1)))
        bow += round(spec.get("wave", 0.0) * math.sin(index * 0.45))
        left = y - len(section) // 2 + bow
        right = left + len(section) - 1
        for offset, letter in enumerate(section):
            put(left + offset, y, letter)
        if 3 < index < length - 1:
            if spec.get("teeth") and index % spec["teeth"] == 0:
                put(right + 1, y - 1, "4")
            if spec.get("fangs") and index % spec["fangs"] == 1:
                put(right + 1, y, "3")
                put(right + 2, y - 1, "4")
        if spec.get("hook") and index == 3:
            put(right + 1, y - 1, "3")
            put(right + 2, y - 2, "4")
    # The guard across the blade's foot.
    g = tip + length
    kind, reach = spec["guard"]
    if kind in ("cross", "spiked"):
        for k in range(-reach, reach + 1):
            end = abs(k) >= reach - 1
            put(g - k, g + k, "z" if end else "y")
            put(g - k + 1, g + k, "z" if end else "Y")
        if kind == "spiked":
            for s in (1, -1):
                x, y = g - s * reach, g + s * reach
                put(x - 1, y - 1, "y")
                put(x - 2, y - 2, "Y")
    elif kind in ("wing", "crescent", "trident"):
        toward = -1 if kind == "wing" else 1
        put(g, g, "y")
        put(g + 1, g, "Y")
        for k in range(1, reach + 1):
            bend = toward * (k // 2)
            for s in (1, -1):
                x, y = g - s * k + bend, g + s * k + bend
                put(x, y, "z" if k == reach else "y")
                put(x + 1, y, "z" if k == reach else "Y")
        if kind == "trident":
            for s in (1, -1):
                x, y = g - s * reach + reach // 2, g + s * reach + reach // 2
                put(x - 1, y - 1, "y")
                put(x - 2, y - 2, "Y")
            put(g - 1, g - 1, "y")
            put(g - 2, g - 2, "Y")
    elif kind in ("disc", "lion"):
        for dy in range(-reach, reach + 1):
            for dx in range(-reach, reach + 2):
                if abs(dx - 0.5) + abs(dy) <= reach + 0.5:
                    put(g + dx, g + dy, "y" if dx + dy < 0 else "Y" if dx + dy < reach else "z")
        if kind == "lion":
            for s in (1, -1):
                put(g - s * (reach + 2), g + s * (reach + 2), "Y")
                put(g - s * (reach + 1), g + s * (reach + 1), "y")
            put(g - 1, g - 1, "z")
            put(g + 1, g - 1, "z")
            put(g, g + 1, "z")
    if spec.get("glow"):
        put(g, g, "g")
        if kind in ("disc", "lion"):
            put(g + 1, g, "g")
    # The grip, wrapped, and the pommel.
    grip = spec.get("grip", 5)
    start = g + (reach if kind in ("disc", "lion") else 0)
    for index in range(1, grip + 1):
        y = start + index
        put(y, y, "w" if index % 2 else "W")
        put(y + 1, y, "W" if index % 2 else "w")
    p = start + grip + 1
    pommel = spec["pommel"]
    if pommel in ("ball", "gem", "spike"):
        for x, y, letter in ((p, p, "y"), (p + 1, p, "Y"), (p, p + 1, "Y"), (p + 1, p + 1, "z")):
            put(x, y, letter)
        if pommel == "gem":
            put(p, p, "g")
        if pommel == "spike":
            put(p + 2, p + 2, "Y")
            put(p + 3, p + 3, "z")
    elif pommel == "ring":
        for x, y in ((p, p), (p + 1, p), (p + 2, p + 1), (p + 2, p + 2), (p + 1, p + 2), (p, p + 1)):
            put(x, y, "y" if x + y < 2 * p + 2 else "z")
    elif pommel == "skull":
        for x, y, letter in ((p, p, "s"), (p + 1, p, "s"), (p + 2, p, "S"), (p, p + 1, "s"), (p + 2, p + 1, "S"),
                             (p, p + 2, "S"), (p + 1, p + 2, "S"), (p + 2, p + 2, "S")):
            put(x, y, letter)
        put(p + 1, p + 1, "z")
    # Dark outline round the silhouette.
    solid = {(x, y) for y in range(32) for x in range(32) if pixels[y][x] is not None}
    for x, y in solid:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if q not in solid and 0 <= q[0] < 32 and 0 <= q[1] < 32:
                pixels[q[1]][q[0]] = OUTLINE + (255,)
    return pixels
