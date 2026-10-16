"""Necklace icons (32x32) in the classic item-icon style: a chain loop seen at a tilt (its back
half in shadow, its front links lit), a gold clasp at the top, and a hand-drawn pendant hanging at
the bottom, shaded like the backpacks (pixel_bags.py): five-tone ramps lit from the top-left with
each part's curvature, a dark outline, darker seams.

PENDANTS are hand-drawn part maps, one letter per pixel, hung so their top row sits at the chain's
lowest point. Letters:  M metal (the item's main colour)  Y gold  G gem (the accent)  X bone
E eye white  o outline  K a glowing core (pulses)

make_sprites.py calls icon(style, colors, frame).
"""

import math

import pixel_bags as B

ANIM_FRAMES = 12
CHAIN = (16.0, 11.5, 9.0, 6.5)     # centre x, centre y, half width, half height of the loop

PENDANTS = {
    "pendant": ["..YYY..", ".YGGGY.", "YGGGGGY", "YGGGGGY", ".YGGGY.", "..YGY..", "...Y..."],
    "disc": ["...YYY...", ".YYMMMYY.", ".YMMGMMY.", "YMMGGGMMY", "YMGGGGGMY", "YMMGGGMMY", ".YMMGMMY.", ".YYMMMYY.",
             "...YYY..."],
    "flame": ["...Y...", "..YGY..", "..GGG..", ".GGGGG.", "GGGKGGG", "GGKKKGG", ".GGKGG.", "..YYY.."],
    "crescent": ["..MMMM...", ".MMMMMM..", "MMMM.....", "MMM......", "MMM......", "MMMM.....", ".MMMMMM..",
                 "..MMMMG.."],
    "star": ["....Y....", "...YYY...", "YYYYGYYYY", ".YYGGGYY.", "..YYGYY..", ".YYY.YYY.", ".YY...YY."],
    "fang": [".YYY.", "YGGGY", ".XXX.", ".XXX.", ".XXX.", "..XX.", "..X..", "..X.."],
    "heart": [".GG.GG.", "GGGGGGG", "GGKKKGG", ".GGKGG.", "..GGG..", "...G..."],
    "skull": ["..XXXXX..", ".XXXXXXX.", "XXXXXXXXX", "XooXXXooX", "XooXXXooX", ".XXXoXXX.", "..XoXoX..",
              "..XXXXX.."],
    "beads": ["..YYY..", "...Y...", ".YYYYY.", "...Y...", "...Y...", "...Y..."],
    "eye": ["..MMMMM..", ".MEEEEEM.", "MEEGGGEEM", "MEGGoGGEM", "MEEGGGEEM", ".MEEEEEM.", "..MMMMM.."],
}
# Pendants whose middle glows (pulses with the frame).
GLOWING = ("heart", "flame")
BEADED = ("beads",)


def _shape(pendant, x0, y0):
    width, height = max(len(row) for row in pendant), len(pendant)
    return (x0 + width / 2, y0 + height / 2, width / 2 + 0.5, height / 2 + 0.5, 0.85)


def icon(style, colors, frame=0):
    main, light, accent = (B._rgb(c) for c in colors)
    # A heart's flesh is its main colour; other gems are the accent.
    gem = main if style == "heart" else accent
    ramps = {"M": B._ramp(main), "Y": B._ramp(B.FIXED["gold"]), "G": B._ramp(gem), "X": B._ramp(B.FIXED["bone"]),
             "E": B._ramp(B.FIXED["white"])}
    glow = 0.5 + 0.5 * math.cos(frame * math.tau / ANIM_FRAMES)
    pixels = [[None] * 32 for _ in range(32)]
    cx, cy, rx, ry = CHAIN
    metal = ramps["M"] if style not in BEADED else B._ramp(light)
    # The chain: links (or beads) round a tilted loop, the back half behind and darker.
    steps = 26 if style not in BEADED else 16
    for index in range(steps):
        angle = index * math.tau / steps
        x, y = cx + rx * math.cos(angle), cy + ry * math.sin(angle)
        behind = math.sin(angle) < -0.2
        lit = -0.6 * math.cos(angle) - 0.5 * math.sin(angle)
        level = 3 if behind else (1 if lit > 0.3 else 2)
        if style in BEADED:
            for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
                shade = level + (0 if (dx, dy) == (0, 0) else 1)
                pixels[round(y) + dy][round(x) + dx] = metal[min(4, shade)] + (255,)
        else:
            pixels[round(y)][round(x)] = metal[level] + (255,)
            if index % 2 == 0:
                pixels[round(y)][round(x) + 1] = metal[min(4, level + 1)] + (255,)
    # The clasp at the top.
    for x, y, level in ((15, 4, 0), (16, 4, 1), (15, 5, 2), (16, 5, 3)):
        pixels[y][x] = ramps["Y"][level] + (255,)
    # The pendant, hanging from the lowest link.
    pendant = PENDANTS[style]
    width = max(len(row) for row in pendant)
    x0, y0 = round(cx - width / 2), round(cy + ry) + 1
    shape = _shape(pendant, x0, y0)
    for row_index, row in enumerate(pendant):
        for col, letter in enumerate(row):
            x, y = x0 + col, y0 + row_index
            if letter == "." or not (0 <= x < 32 and 0 <= y < 32):
                continue
            if letter == "o":
                pixels[y][x] = B.FIXED["o"] + (255,)
            elif letter == "K":
                core = tuple(min(255, round(c * (0.8 + 0.4 * glow))) for c in B._ramp(accent)[0])
                pixels[y][x] = core + (255,)
            else:
                level = B._tone("P", shape, x, y, 0.0, grain=False)
                pixels[y][x] = ramps[letter][level] + (255,)
    # Outline round everything.
    solid = {(x, y) for y in range(32) for x in range(32) if pixels[y][x] is not None}
    outline = set()
    for x, y in solid:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if q not in solid and 0 <= q[0] < 32 and 0 <= q[1] < 32:
                outline.add(q)
    for x, y in outline:
        pixels[y][x] = B.FIXED["o"] + (255,)
    return pixels
