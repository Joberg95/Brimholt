"""Worn looks: gear as it sits on the character, hand-pixelled at body resolution, one drawing per
family of items and tinted by each item's colours (catalog main, light, accent). The icon carries an
item's own detail; on the figure every piece of a family has the same cut, so worn gear reads cleanly
at body scale. The OpenTibia sprite pack's items are reference only, never sampled.

Helmets are drawn whole: the head never moves between poses, so a family needs its front ("down"),
back ("up"), and side ("left") views (the right side is the left mirrored). Armour, legs, and boots
follow the body through its poses: a family is a template of letters by frame row and column that
repaints the body's own cloth and leg pixels in each frame, so a swinging arm or a stepping leg keeps
its material without a drawing per pose.

Letters:  k outline   4 highlight   1 2 3 light, mid, dark of the item's main colour
          a b         light and dark of its accent   m n  light and dark of its second colour
          w x y       bone (horns)   o p  antler   . nothing (the body shows through)
"""
import colorsys

X0 = 22  # frame column of a helmet row's first letter
TX = 24  # frame column of a body template row's first letter


def _rgb(hexcode):
    return tuple(int(hexcode[i:i + 2], 16) for i in (0, 2, 4))


def _shade(hexcode, light):
    h, l, s = colorsys.rgb_to_hls(*(v / 255 for v in _rgb(hexcode)))
    return tuple(round(v * 255) for v in colorsys.hls_to_rgb(h, max(0.0, min(1.0, light)), s)) + (255,)


def _light(hexcode):
    return colorsys.rgb_to_hls(*(v / 255 for v in _rgb(hexcode)))[1]


def _tones(colors):
    """Letters to RGBA: the main colour as a four-step ramp around its own lightness, the second
    colour and the accent as two steps each, and fixed bone and antler tones."""
    main, second, accent = colors[0], colors[1], colors[2]
    l, sl, al = _light(main), _light(second), _light(accent)
    return {"4": _shade(main, l + 0.24), "1": _shade(main, l + 0.12), "2": _shade(main, l),
            "3": _shade(main, l - 0.14), "k": _shade(main, max(0.04, l * 0.28)),
            "a": _shade(accent, al + 0.08), "b": _shade(accent, al - 0.16),
            "m": _shade(second, sl), "n": _shade(second, sl - 0.16),
            "w": (232, 224, 200, 255), "x": (196, 184, 156, 255), "y": (148, 134, 108, 255),
            "o": (154, 116, 74, 255), "p": (104, 74, 46, 255)}


# --------------------------------------------------------------------------------- helmets
# Each family: {view: (top row, [rows])}, rows starting at frame column X0. The head spans
# columns 27-36 and rows 16-26; the face shows rows 20-25 (eyes on row 23 at columns 30 and 33).
HELMS = {
    # An open helm: a domed skull with a rivet band, cheek guards, and a nasal bar.
    "helm": {
        "down": (14, ["........kkkk",
                      "......kk1442kk",
                      ".....k14422223k",
                      "....k1442222233k",
                      "....k1422222233k",
                      "....k1222222333k",
                      "....k3a3a3a3a33k",
                      "....k23kk33kk33k",
                      "....k2k..13..k3k",
                      "....k2k..k3..k3k",
                      "....k3k......k3k",
                      ".....kk......kk"]),
        "up": (14, ["........kkkk",
                    "......kk1223kk",
                    ".....k12222333k",
                    "....k1222222333k",
                    "....k1222222333k",
                    "....k1222222333k",
                    "....k3a3a3a3a33k",
                    "....k2222223333k",
                    "....k2222223333k",
                    "....k2222233333k",
                    "....k3333333333k",
                    ".....kkkkkkkkkk"]),
        "left": (14, ["........kkkk",
                      "......kk1442kk",
                      ".....k14422223k",
                      "....k1442222233k",
                      "....k1422222333k",
                      "....k1222222333k",
                      "....k3a3a3a3a33k",
                      "....k3kkkk22333k",
                      "....kk....k2333k",
                      "..........k2333k",
                      "..........k3333k",
                      "...........kkkk"]),
    },
    # A great helm: a closed bucket with a T-shaped visor and breathing holes.
    "greathelm": {
        "down": (14, ["........kkkk",
                      "......kk1442kk",
                      ".....k14422223k",
                      "....k1442222233k",
                      "....k1422222233k",
                      "....k1222222333k",
                      "....k1222222333k",
                      "....k12kkkkk233k",
                      "....k1222kk2333k",
                      "....k1222kk2333k",
                      "....k22a222a333k",
                      "....k2333333333k",
                      ".....kkkkkkkkkk"]),
        "up": (14, ["........kkkk",
                    "......kk1223kk",
                    ".....k12222333k",
                    "....k1222222333k",
                    "....k1222222333k",
                    "....k3a3a3a3a33k",
                    "....k2222223333k",
                    "....k2222223333k",
                    "....k2222223333k",
                    "....k2222233333k",
                    "....k2222233333k",
                    "....k3333333333k",
                    ".....kkkkkkkkkk"]),
        "left": (14, ["........kkkk",
                      "......kk1442kk",
                      ".....k14422223k",
                      "....k1442222233k",
                      "....k1422222333k",
                      "....k1222222333k",
                      "....k1222222333k",
                      "....kkkkk222333k",
                      "....k12k2222333k",
                      "....k12k2222333k",
                      "....k1a22222333k",
                      "....k2333333333k",
                      ".....kkkkkkkkkk"]),
    },
    # A hood: cloth over the head and shoulders, the face in a deep opening.
    "hood": {
        "down": (14, ["........kkkk",
                      "......kk1122kk",
                      ".....k11222223k",
                      "....k1122222233k",
                      "....k1222222233k",
                      "....k12kkkkkk33k",
                      "....k1k......k3k",
                      "....k1k......k3k",
                      "....k1k......k3k",
                      "....k1k......k3k",
                      "....k12k....k23k",
                      "...k1222kkkk2333k",
                      "...k122222333333k",
                      "....kk22223333kk",
                      "......kkkkkkkk"]),
        "up": (14, ["........kkkk",
                    "......kk1223kk",
                    ".....k12222333k",
                    "....k1222222333k",
                    "....k1222222333k",
                    "....k1222222333k",
                    "....k1222222333k",
                    "....k1222223333k",
                    "....k1222223333k",
                    "....k2222223333k",
                    "....k2222233333k",
                    "...k122222233333k",
                    "...k222223333333k",
                    "....kk33333333kk",
                    "......kkkkkkkk"]),
        "left": (14, ["........kkkk",
                      "......kk1122kk",
                      ".....k11222223k",
                      "....k1122222233k",
                      "....k1222222333k",
                      "....kkkkk222333k",
                      "....k....k22333k",
                      "....k....k22333k",
                      "....k....k22333k",
                      "....k....k22333k",
                      "....kk..k222333k",
                      "...k12kk22223333k",
                      "...k122222333333k",
                      "....kk22223333kk",
                      "......kkkkkkkk"]),
    },
    # A pointed hat: a tall cone with a band and a broad brim.
    "hat": {
        "down": (4, [".........kk",
                     "........k14k",
                     "........k12k",
                     ".......k1223k",
                     ".......k1223k",
                     "......k122233k",
                     "......k122233k",
                     ".....k12222333k",
                     ".....k12222333k",
                     "....kaaaaaaabbbk",
                     "....kaaaaaaabbbk",
                     "..kk122222222333kk",
                     ".k1122222222223333k",
                     "..kk333333333333kk",
                     "....kkkkkkkkkkkk"]),
        "up": (4, [".........kk",
                   "........k12k",
                   "........k12k",
                   ".......k1233k",
                   ".......k1233k",
                   "......k122333k",
                   "......k122333k",
                   ".....k12223333k",
                   ".....k12223333k",
                   "....kbbbbbbbbbbk",
                   "....kbbbbbbbbbbk",
                   "..kk122222233333kk",
                   ".k1122222223333333k",
                   "..kk333333333333kk",
                   "....kkkkkkkkkkkk"]),
        "left": (4, ["............kk",
                     "...........k14k",
                     "..........k122k",
                     ".........k1223k",
                     "........k1223k",
                     "......kk122233k",
                     "......k122233k",
                     ".....k12222333k",
                     ".....k12222333k",
                     "....kaaaaaaabbbk",
                     "....kaaaaaaabbbk",
                     "..kk122222222333kk",
                     ".k1122222222223333k",
                     "..kk333333333333kk",
                     "....kkkkkkkkkkkk"]),
    },
    # A circlet: a band round the brow with a set stone at the front.
    "circlet": {
        "down": (18, [".........kk",
                      ".....kkkk4akkkk",
                      ".....k112bb223k",
                      ".....kkkkkkkkkk"]),
        "up": (18, ["",
                    ".....kkkkkkkkkk",
                    ".....k111222223k",
                    ".....kkkkkkkkkk"]),
        "left": (18, ["....kk",
                      "....k4akkkkkkkk",
                      "....kbbk1222233k",
                      ".....kkkkkkkkkk"]),
    },
}

# Overlays drawn over a helmet for its look's extras, for a helm whose crown is row 14 (they move
# with a family's own crown, down onto a circlet's band, never up a hat's cone).
OVERLAYS = {
    # Bone horns curving up and out from the temples.
    "horns": {
        "down": (11, ["kk................kk",
                      "kwk..............kxk",
                      "kwxk............kxyk",
                      ".kxyk..........kyyk",
                      "..kxyk........kyyk",
                      "...kxyk......kyyk"]),
        "up": (11, ["kk................kk",
                    "kxk..............kxk",
                    "kxxk............kxyk",
                    ".kxyk..........kyyk",
                    "..kxyk........kyyk",
                    "...kxyk......kyyk"]),
        "left": (11, ["...............kk",
                      "..............kwk",
                      ".............kwxk",
                      "............kxyk",
                      "...........kxyk",
                      "..........kxyk"]),
    },
    # Branched antlers rising from the temples.
    "antlers": {
        "down": (9, ["k.k..............k.k",
                     "okok............kpkp",
                     "kookk..........kkppk",
                     ".kook..........kppk",
                     "..kok..........kpk",
                     "...kok........kpk",
                     "....kok......kpk"]),
        "up": (9, ["k.k..............k.k",
                   "okok............kpkp",
                   "kookk..........kkppk",
                   ".kook..........kppk",
                   "..kok..........kpk",
                   "...kok........kpk",
                   "....kok......kpk"]),
        "left": (9, ["...............k.k",
                     "..............kokp",
                     ".............kookk",
                     ".............kopk",
                     "............kopk",
                     "...........kopk",
                     "..........kpk"]),
    },
    # A crest of bristles from brow to nape (accent).
    "crest": {
        "down": (9, [".........kk",
                     "........kaak",
                     "........kabk",
                     "........kabk",
                     "........kabk"]),
        "up": (9, [".........kk",
                   "........kabk",
                   "........kabk",
                   "........kabk",
                   "........kbbk"]),
        "left": (9, ["",
                     ".......kkkkkk",
                     "......kaaaaabkk",
                     "......kaaaabbbbk",
                     ".......kkabbbbk",
                     ".........kkkkk"]),
    },
}
# Plumes stand on the crown like a crest; spikes rise from the temples like horns.
OVERLAYS["plume"] = OVERLAYS["crest"]
OVERLAYS["spikes"] = OVERLAYS["horns"]

# Which family each helmet look (its first word) wears as.
HELM_OF = {
    "helm": "helm", "cap": "helm", "hornhelm": "helm", "crownhelm": "helm", "lanternhelm": "helm",
    "greathelm": "greathelm", "visor": "greathelm", "fangmask": "greathelm", "dreadmask": "greathelm",
    "hood": "hood", "coif": "hood", "cowl": "hood", "ranger": "hood", "bearhood": "hood", "cobra": "hood",
    "hat": "hat", "nimbus": "hat",
    "circlet": "circlet", "staghelm": "circlet", "rootcrown": "circlet",
}


def helmet_layer(shape, extras, colors, view, image):
    """Draws a helmet's worn look onto image (a 64x64 frame) for view down, up, or left; False
    when the look has no family."""
    family = HELM_OF.get(shape)
    if family is None:
        return False
    tones = _tones(colors)
    top, rows = HELMS[family][view]
    rise = max(-1, min(4, HELMS[family]["down"][0] - 14))
    drawings = [(top, rows)] + [(t + rise, r) for t, r in (OVERLAYS[extra][view] for extra in sorted(extras)
                                                           if extra in OVERLAYS)]
    for top, rows in drawings:
        for dy, row in enumerate(rows):
            for dx, ch in enumerate(row):
                if ch != ".":
                    image.set(X0 + dx, top + dy, tones[ch])
    return True


# ----------------------------------------------------------------------------- body gear
# Body templates: {family: {view: (top row, [rows])}}, rows starting at frame column TX. A template
# repaints the body's own pixels in each pose: armour its cloth (shirt and sleeves) and the belt
# row, legs and boots the legs. Where an arm has moved off its standing place, a pixel takes the
# nearest letter in its row, so sleeves keep their material while they swing. Standing, the torso
# is columns 28-35 (shoulders 27-36) on rows 28-43, sleeves are 25-26 and 37-38 on rows 31-35, and
# the belt is row 39; from the side the torso is 31-34 and the near sleeve 29.

ARMOR = {
    # A breastplate with a gorget, pauldrons, a ridge down the chest, a belt, and a fauld of lames.
    "plate": {
        "down": (28, ["....12444223....",
                      "...4111442233...",
                      "..k41k1422k33k..",
                      ".41k22222223k33.",
                      ".12.14k42223.23.",
                      ".nm.1442k223.mn.",
                      ".nm.12422233.mn.",
                      ".nm.12242333.mn.",
                      "....1224k333....",
                      "....12224333....",
                      "....12222333....",
                      "....bbbabbbb....",
                      "....3a3a3a3a....",
                      "....12222333....",
                      "....k2k22k3k....",
                      "...1222k2223k..."]),
        "up": (28, ["....12222333....",
                    "...4111222333...",
                    "..k41k2222k33k..",
                    ".41k22222223k33.",
                    ".12.12222233.23.",
                    ".nm.12222233.mn.",
                    ".nm.12222333.mn.",
                    ".nm.12222333.mn.",
                    "....12222333....",
                    "....12223333....",
                    "....12223333....",
                    "....bbbbbbbb....",
                    "....3a3a3a3a....",
                    "....12222333....",
                    "....k2k22k3k....",
                    "...1222k2223k..."]),
        "left": (28, [".....122233.....",
                      ".....4411233....",
                      ".....41k1k33....",
                      ".....4k122333...",
                      ".....1k144233...",
                      ".....mk142233...",
                      ".....mk122333...",
                      ".....mk122333...",
                      ".....nk122333...",
                      ".....nk122333...",
                      ".....nk122333...",
                      ".....bkabbbb....",
                      ".....kk3a3a3....",
                      ".....1k22233....",
                      "....12k2k233....",
                      "....1222k233...."]),
    },
    # A mail hauberk: rings in rows (light and dark alternating), a belt, mail sleeves.
    "mail": {
        "down": (28, ["....nmmnnmmn....",
                      "...mnmmnnmmnn...",
                      "..kmnnmmnnmnnk..",
                      ".mnkkkkkkkkkknm.",
                      ".nm.mnmnmnmn.mn.",
                      ".mn.nmnmnmnm.nm.",
                      ".nm.mnmnmnmn.mn.",
                      ".mn.nmnmnmnm.nm.",
                      "....mnmnmnmn....",
                      "....nmnmnmnm....",
                      "....mnmnmnmn....",
                      "....33a33333....",
                      "....nmnmnmnm....",
                      "....mnmnmnmn....",
                      "....nmnmnmnm....",
                      "...mnmnmnmnmn..."]),
        "up": (28, ["....nmmnnmmn....",
                    "...mnmmnnmmnn...",
                    "..kmnnmmnnmnnk..",
                    ".mnkkkkkkkkkknm.",
                    ".nm.mnmnmnmn.mn.",
                    ".mn.nmnmnmnm.nm.",
                    ".nm.mnmnmnmn.mn.",
                    ".mn.nmnmnmnm.nm.",
                    "....mnmnmnmn....",
                    "....nmnmnmnm....",
                    "....mnmnmnmn....",
                    "....33333333....",
                    "....nmnmnmnm....",
                    "....mnmnmnmn....",
                    "....nmnmnmnm....",
                    "...mnmnmnmnmn..."]),
        "left": (28, [".....nmmnmn.....",
                      ".....mnmnmnm....",
                      ".....nmnmnmn....",
                      ".....mknmnmnm...",
                      ".....nkmnmnmn...",
                      ".....mknmnmnm...",
                      ".....nkmnmnmn...",
                      ".....mknmnmnm...",
                      ".....nkmnmnmn...",
                      ".....mknmnmnm...",
                      ".....nkmnmnmn...",
                      ".....3ka3333....",
                      ".....nkmnmnm....",
                      ".....mknmnmn....",
                      "....nmknmnmn....",
                      "....mnmknmnm...."]),
    },
    # A leather jerkin: a laced front, shoulder pads, stitched skirts, a belt with a buckle.
    "leather": {
        "down": (28, ["....11222223....",
                      "...111222223k...",
                      "..k11k2222k33k..",
                      ".12k12222223k23.",
                      ".12.122ab223.23.",
                      ".23.1222b223.33.",
                      ".23.122ab233.33.",
                      ".23.1222b233.33.",
                      "....122ab233....",
                      "....1222b333....",
                      "....12222333....",
                      "....pppaappp....",
                      "....12222333....",
                      "....1k2222k3....",
                      "....12222333....",
                      "...1222222333..."]),
        "up": (28, ["....11222223....",
                    "...111222223k...",
                    "..k11k2222k33k..",
                    ".12k12222223k23.",
                    ".12.12k22k33.23.",
                    ".23.12k22k33.33.",
                    ".23.12k22k33.33.",
                    ".23.12k22k33.33.",
                    "....12222333....",
                    "....12222333....",
                    "....12222333....",
                    "....pppppppp....",
                    "....12222333....",
                    "....1k2222k3....",
                    "....12222333....",
                    "...1222222333..."]),
        "left": (28, [".....1122233....",
                      ".....1122233....",
                      ".....11k2233....",
                      ".....1k122333...",
                      ".....1kab2233...",
                      ".....2k1b2233...",
                      ".....2kab2333...",
                      ".....2k1b2333...",
                      ".....2k122333...",
                      ".....2k122333...",
                      ".....2k122333...",
                      ".....pkaappp....",
                      ".....1k22233....",
                      ".....1k2k233....",
                      "....12k22333....",
                      "....1222k333...."]),
    },
    # A robe: a high collar, a trimmed opening down the front, wide sleeves, a sash, and a skirt
    # that falls over the legs to the ankles (SKIRT).
    "robe": {
        "down": (28, ["....1aa22aa3....",
                      "...11a2222a33...",
                      "..k112a22a233k..",
                      ".12k1122a2233k23",
                      ".12.1122a2233.23",
                      ".12.1122a2233.23",
                      ".22.1122a2233.33",
                      ".22.1122a2233.33",
                      "....1122a2233...",
                      "....1122a2233...",
                      "....1122a2233...",
                      "....bbbabbbb....",
                      "....1122a2233...",
                      "....1122a2233...",
                      "....1122a2233...",
                      "...11222a22333.."]),
        "up": (28, ["....11222233....",
                    "...1122222333...",
                    "..k1122222333k..",
                    ".12k112222333k23",
                    ".12.112222333.23",
                    ".12.112222333.23",
                    ".22.112222333.33",
                    ".22.112222333.33",
                    "....11222233....",
                    "....11222233....",
                    "....11222233....",
                    "....bbbbbbbb....",
                    "....11222233....",
                    "....11222233....",
                    "....11222233....",
                    "...1122222333..."]),
        "left": (28, [".....1a22233....",
                      ".....1a222333...",
                      ".....1ak22333...",
                      ".....12k22333...",
                      ".....12ka2233...",
                      ".....12ka2233...",
                      ".....22ka2233...",
                      ".....22ka2333...",
                      ".....22ka2333...",
                      ".....22ka2333...",
                      ".....22ka2333...",
                      ".....bkabbbb....",
                      ".....12ka233....",
                      ".....12ka233....",
                      "....112ka233....",
                      "....1122a233...."]),
    },
}
# The robe's skirt, drawn over the legs from the hem down whatever the legs do.
SKIRT = {
    "down": (44, ["...k1122a22333k.",
                  "...k1122a22333k.",
                  "...k1122a223333k",
                  "..k11222a223333k",
                  "..k11222a223333k",
                  "..k11222a223333k",
                  "..k1122aaa22333k",
                  "...kkkkkkkkkkkk."]),
    "up": (44, ["...k1122222333k.",
                "...k1122222333k.",
                "...k11222223333k",
                "..k112222223333k",
                "..k112222223333k",
                "..k112222223333k",
                "..k1122bbb22333k",
                "...kkkkkkkkkkkk."]),
    "left": (44, ["....k1ka2233k...",
                  "....k1ka22333k..",
                  "...k12ka22333k..",
                  "...k12ka22333k..",
                  "...k12ka223333k.",
                  "...k12ka223333k.",
                  "...k1aaa223333k.",
                  "....kkkkkkkkkk.."]),
}

# Legs: a pattern per leg by row from the hip (row 45) down, the leg's near (lit) pixel and the
# rest of it; each leg is two pixels wide from the front and three from the side.
LEGS = {
    # Plate legs: tassets at the hip, cuisses, a bright knee cop, greaves.
    "legplates": ["3a", "13", "13", "4a", "13", "13", "13"],
    # Mail chausses: alternating rings down the leg, a strap at the knee.
    "chausses": ["mn", "nm", "mn", "33", "nm", "mn", "nm"],
    # Leather breeches: a dark seam at the knee, a turned cuff.
    "breeches": ["13", "13", "13", "33", "13", "13", "ab"],
    # Cloth leggings: plain, an accent stripe down the outside.
    "leggings": ["13", "1a", "1a", "13", "1a", "13", "13"],
}
# Boots from the row they start (frame row, standing) to the soles, top row first.
BOOTS = {
    # Plate sabatons: a lit cuff, lames, an armoured toe.
    "sabatons": (48, ["4a", "13", "12", "13", "k3", "kk"]),
    # Leather boots: a turned-down cuff in the accent, a dark sole.
    "boots": (48, ["ab", "13", "13", "13", "k3", "kk"]),
    # Striders: soft boots with a lacing stripe.
    "striders": (49, ["1a", "13", "1a", "k3", "kk"]),
    # Slippers: low shoes, only the feet, a bright toe.
    "slippers": (51, ["1a", "k3", "kk"]),
}
ARMOR_OF = {"plate": "plate", "brigandine": "plate", "mail": "mail", "scale": "mail",
            "leather": "leather", "coat": "leather", "robe": "robe"}
LEGS_OF = {"legplates": "legplates", "chausses": "chausses", "breeches": "breeches", "leggings": "leggings"}
BOOTS_OF = {"sabatons": "sabatons", "boots": "boots", "striders": "striders", "slippers": "slippers",
            "furboots": "boots", "wingboots": "boots", "bloomboots": "boots", "vialboots": "boots",
            "frostboots": "slippers", "flameboots": "sabatons", "scaleboots": "sabatons"}


def _nearest(row, x):
    """The template letter at column x of a row, else the nearest letter in it."""
    for reach in range(16):
        for col in (x - reach, x + reach):
            if 0 <= col < len(row) and row[col] != ".":
                return row[col]
    return None


def _dark(pixel):
    return pixel[0] * 0.3 + pixel[1] * 0.59 + pixel[2] * 0.11 < 45


BELT_ROW = 11  # the template row (frame row 39) where armour also covers the body's belt


def armor_layer(shape, colors, view, cloth, body, image):
    """Repaints the cloth (and the torso's belt row) of one body frame with an armour family's
    template; cloth and body are that frame's 64x64 pixel rows. False when the look has no family."""
    family = ARMOR_OF.get(shape)
    if family is None:
        return False
    tones = _tones(colors)
    top, rows = ARMOR[family][view]
    for dy, row in enumerate(rows):
        y = top + dy
        for x in range(64):
            inside = TX <= x < TX + len(row) and row[x - TX] != "."
            belt = dy == BELT_ROW and inside and body[y][x] is not None and not _dark(body[y][x])
            if cloth[y][x] is None and not belt:
                continue
            letter = row[x - TX] if inside else _nearest(row, x - TX)
            if letter:
                image.set(x, y, tones[letter])
    if family == "robe":
        top, rows = SKIRT[view]
        for dy, row in enumerate(rows):
            for dx, letter in enumerate(row):
                if letter != ".":
                    image.set(TX + dx, top + dy, tones[letter])
    return True


def _runs(row):
    """(first, last) columns of each run of non-outline pixels in a frame row."""
    runs, start = [], None
    for x in range(65):
        on = x < 64 and row[x] is not None and not _dark(row[x])
        if on and start is None:
            start = x
        elif not on and start is not None:
            runs.append((start, x - 1))
            start = None
    return runs


def legs_layer(shape, colors, view, body, image):
    """Repaints each leg of one body frame from the hip down with a legwear family's pattern."""
    family = LEGS_OF.get(shape)
    if family is None:
        return False
    tones = _tones(colors)
    for index, letters in enumerate(LEGS[family]):
        y = 45 + index
        for first, last in _runs(body[y]):
            for x in range(first, last + 1):
                image.set(x, y, tones[letters[0] if x == first else letters[1]])
    return True


def boots_layer(shape, colors, view, body, image):
    """Repaints the feet and lower legs of one body frame with a boot family's pattern, outlines
    included (the sole and toe take the boot's dark tones)."""
    family = BOOTS_OF.get(shape)
    if family is None:
        return False
    tones = _tones(colors)
    top, pattern = BOOTS[family]
    for index, letters in enumerate(pattern):
        y = top + index
        for first, last in _runs(body[y]):
            for x in range(first, last + 1):
                image.set(x, y, tones[letters[0] if x == first else letters[1]])
        for x in range(64):
            if body[y][x] is not None and _dark(body[y][x]):
                image.set(x, y, tones["k"])
    return True
