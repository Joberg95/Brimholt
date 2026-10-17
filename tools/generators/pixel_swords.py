"""Hand-pixelled sword icons (32x32) on the classic diagonal: the tip at the top-left, the blade
running down to a crossguard, a wrapped grip, and a pommel at the bottom-right.

A blade is drawn row by row along the diagonal: each row is its cross-section (SECTIONS), from the
lit upper edge on the left to the shaded lower edge on the right, so the 45-degree edges stay
clean. Letters:

  1-5 blade (the item's main colour, 1 the bright edge)   y Y z guard (the item's light colour)
  a A b inlay or grip (the item's accent)                  g a gem that glows (pulses)
  w W grip wrap (leather)                                  . nothing

A style sets the cross-section along the blade (from the tip), the guard's shape, and extras: a
curve (sabres), saw teeth on the edge (serrated), a fuller (a dark groove), a glowing gem. The silhouette gets a
dark outline at the end. make_sprites.py calls icon(style, colors, frame).
"""

import colorsys
import math

ANIM_FRAMES = 12
OUTLINE = (24, 18, 20)
LEATHER = {"w": (122, 86, 54), "W": (78, 54, 34)}


def _sections(tip, body, length, taper=3):
    """Cross-sections from the tip: a taper of `taper` rows growing to `body`, then `body`."""
    rows = []
    for index in range(length):
        if index < taper:
            keep = max(1, round(len(body) * (index + 1) / (taper + 1)))
            rows.append(tip[:keep] if tip else body[:keep])
        else:
            rows.append(body)
    return rows


# style: tip row (y = x on the diagonal), blade rows, guard half-length, guard letters, extras
STYLES = {
    "plain": {"tip": 4, "blade": _sections("12", "1234", 14), "guard": 4},
    "short": {"tip": 8, "blade": _sections("12", "1234", 10), "guard": 3},
    "fuller": {"tip": 4, "blade": _sections("12", "12534", 14), "guard": 4},
    "cleaver": {"tip": 4, "blade": _sections("1233", "123344", 7, 1) + _sections("", "12344", 7, 0), "guard": 3},
    "curved": {"tip": 4, "blade": _sections("12", "1234", 14), "guard": 3, "curve": 2.2},
    "estoc": {"tip": 3, "blade": _sections("1", "134", 15, 2), "guard": 4},
    "great": {"tip": 3, "blade": _sections("12", "12345", 16), "guard": 5},
    "greatfuller": {"tip": 3, "blade": _sections("12", "125345", 16), "guard": 5},
    "serrated": {"tip": 4, "blade": _sections("12", "12a34", 14), "guard": 4, "teeth": 3},
    "fang": {"tip": 7, "blade": _sections("12", "12a4", 11), "guard": 3, "curve": 1.0, "gem": True},
    "sanguine": {"tip": 5, "blade": _sections("12", "12aA4", 13), "guard": 5, "gem": True},
    "grand": {"tip": 3, "blade": _sections("12", "12yA45", 16), "guard": 6, "gem": True},
}
STYLE_NAMES = tuple(STYLES)
GLOWING = tuple(style for style, spec in STYLES.items() if spec.get("gem"))


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
    glow = 0.5 + 0.5 * math.cos(frame * math.tau / ANIM_FRAMES)
    palette = {str(i + 1): blade[i] for i in range(5)}
    palette.update({"y": guard[0], "Y": guard[2], "z": guard[4], "a": inlay[1], "A": inlay[2], "b": inlay[4], **LEATHER,
                    "g": tuple(min(255, round(c * (0.75 + 0.45 * glow))) for c in inlay[0])})
    pixels = [[None] * 32 for _ in range(32)]

    def put(x, y, letter):
        if letter != "." and 0 <= x < 32 and 0 <= y < 32:
            pixels[y][x] = palette[letter] + (255,)

    tip, rows = spec["tip"], spec["blade"]
    length = len(rows)
    for index, section in enumerate(rows):
        y = tip + index
        # A sabre's blade bows away from the straight diagonal in its middle.
        bow = round(spec.get("curve", 0.0) * math.sin(math.pi * index / max(1, length - 1)))
        left = y - len(section) // 2 + bow
        for offset, letter in enumerate(section):
            put(left + offset, y, letter)
        # Saw teeth stand out of the lower edge every few rows.
        if spec.get("teeth") and index > 3 and index % spec["teeth"] == 0:
            put(left + len(section), y - 1, "4")
    # The crossguard runs across the blade at its foot (along the other diagonal), two pixels thick.
    g = tip + length
    reach = spec["guard"]
    for k in range(-reach, reach + 1):
        end = abs(k) >= reach - 1
        put(g - k, g + k, "z" if end else "y")
        put(g - k + 1, g + k, "z" if end else "Y")
    if spec.get("gem"):
        put(g, g, "g")
        put(g + 1, g, "g")
    # The grip, wrapped, and the pommel.
    for index in range(1, 6):
        y = g + index
        put(y, y, "w" if index % 2 else "W")
        put(y + 1, y, "W" if index % 2 else "w")
    p = g + 6
    for x, y, letter in ((p, p, "y"), (p + 1, p, "Y"), (p, p + 1, "Y"), (p + 1, p + 1, "z")):
        put(x, y, letter)
    if spec.get("gem"):
        put(p, p, "g")
    # Dark outline round the silhouette.
    solid = {(x, y) for y in range(32) for x in range(32) if pixels[y][x] is not None}
    for x, y in solid:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if q not in solid and 0 <= q[0] < 32 and 0 <= q[1] < 32:
                pixels[q[1]][q[0]] = OUTLINE + (255,)
    return pixels
