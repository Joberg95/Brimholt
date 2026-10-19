"""Hand-drawn food, glowcap, and torch icons (32x32) in the classic item-icon style: each dish
seen from a little above and to the left, lit from the top-left, shaded like the backpacks and
monster drops (pixel_bags.py, pixel_materials.py).

STYLES hold hand-drawn maps ("rows"), one letter per pixel, "." clear:

  m l a  the item's main, light, and accent colours      M L A  the same, in their darkest tone
  k char (grill marks, pupils)   e white (eyes)   g leaf   G dark leaf   n lemon   s silver skin
  p glazed clay   i ice   I ice crack   w pale wood   y gold   c linen wrap   t tar   d earth
  *      a white glint            1 2 3 4  flame, deep red to white-hot (flat, not shaded)

A style's "tones" name extra letters for one fixed tone of a ramp (curled bodies shaded by hand
as tubes), "dark" sets the tone of its uppercase letters (darkest by default).

Each solid (a style's "solids": letters shaded together, joined by touching) is lit as one rounded body over
its bounding box in a five-tone ramp of its material; darker seams where two solids meet, a
cast shadow on the plate, platter, or ice under the food ("ground"), and a dark outline round the
whole icon. The torch's flame is drawn per frame (it flickers, ANIM_FRAMES): see ANIMATED.

make_sprites.py calls icon(style, colors, frame).
"""

import math

import pixel_bags as B

ANIM_FRAMES = 12
FIXED = {"k": (52, 34, 28), "e": (238, 234, 222), "g": (98, 150, 62), "n": (236, 204, 84),
         "s": (184, 196, 204), "p": (222, 214, 196), "i": (196, 228, 240), "w": (200, 160, 108),
         "y": (216, 168, 58), "c": (176, 150, 108), "t": (74, 52, 40), "d": (92, 74, 60)}
FLAME = {"1": (196, 66, 26), "2": (238, 128, 36), "3": (252, 200, 80), "4": (255, 246, 210)}
GLINT = (255, 255, 248)
ANIMATED = ("torch",)

STYLES = {
    "perch": {
        "rows": [
            "..........mmmm............",
            "........mmmmmmmm..........",
            ".....mmmmmmmkMmmkMm.....mm",
            "...mmmMmmmmmkMmmkMm..aammm",
            "..mmmmMmmmmkMmmkMmmmaaAamm",
            ".mmeemmMmmmkMmmkMmmamAmamm",
            "mmmekmmMmmkMmmkMmmaaAmm...",
            "MMmmmmmMmmkMmmkMmammAma...",
            ".mmmmmMmmkMmmkMmaamAmaammm",
            "..llllMllkMllkMlllAma.mmmm",
            "...lllllkMllkMlllAlaa..mmm",
            ".....lllllllkMllll......mm",
            ".......llll..lll..........",
        ],
        "solids": ('mlke',),
    },
    "eel": {
        "rows": [
            "...hhhh...................",
            "..hjjjjjh.................",
            ".hjekjjjjm................",
            ".jjjjjjmmmn...............",
            ".KKKmmmmnnM...............",
            "....KKmnnnMjjmmmmmm.......",
            ".....hKmnnnnnnnnmmmmn.....",
            "....hjmnnMMKMMMnnnnnnn....",
            "...hjmnMKhhjjjjmmnmmnnn...",
            "..hjmnKhjmmnnnnmmnnmmnnM..",
            "..jmnMhjmnMKKMnnmnnnmmnn..",
            ".hjmMKjmnMKKKKKKmmnnjmnnM.",
            ".jmnMjmnMKKKKKKKKjmnMjmnM.",
            ".jmmnMmmnnKKKKKKjmnMhjnMK.",
            "..mmnnmmmnnmjhhjmnMKjmnM..",
            "..jmmnnmmnnmmmmnnMKhmnMK..",
            "...mmmnnmnnMMMMKKhjmnMK.nn",
            "....mmmmmmmjjjhjjmmnMKnnnK",
            ".....nnnnnmmmmmmnnMKKnnKK.",
            ".......nnnnnnMMMMKK...K...",
            "..........................",
            "..........................",
        ],
        "tones": {'h': ('l', 0), 'j': ('l', 2), 'm': ('m', 1), 'n': ('m', 2), 'M': ('m', 3), 'K': ('m', 4)},
    },
    "pie": {
        "rows": [
            "............ss.....ss.....",
            "............sSs...sSs.....",
            ".............ssssSss......",
            "..............sssss.......",
            "...............sss........",
            "........lllllllsss........",
            ".....lllllllllllsllll.....",
            "...llllllAaaaalAAAallll...",
            "..lllAllllaaallllaaallll..",
            ".lllAllAallallAallallAall.",
            ".lllllAaaalllAaaalllAaalL.",
            ".lllllaaaalllaaaalllaaalL.",
            ".lLlAllaallAllaallAllaalL.",
            ".MLllAllllAaallllAaallLlm.",
            ".MmlLllllAaaaallAaalllLmm.",
            ".MmmMlLlLlllllllllLlLmMmm.",
            ".MmmMmmMLlLlLlLlLlmMmmMmm.",
            "..mmMmmMmmMmmMmmMmmMmmMm..",
            "....MmmMmmMmmMmmMmmMmm....",
            "......mMmmMmmMmmMmmM......",
            "..........................",
        ],
        "solids": ('lma',),
        "dark": {'L': 3, 'S': 3, 'A': 2},
    },
    "stew": {
        "rows": [
            ".......................wwW",
            "......................wwW.",
            "........mmmmmmmmmm...wwW..",
            ".....mmmmmmmmmmmmmmmwwW...",
            "...mmmmllllllllllllwwmm...",
            "..mmllllllllllllaawwllmm..",
            ".mmlllaalgllllllawwllllmm.",
            ".mmlllaAllllllllwwllgllmm.",
            ".mmllgllllllaallllpplllmm.",
            ".mmllllllaalaAlllllplllmm.",
            ".MmmmllllaAlllgllllllmmmM.",
            "..MMmmmmmllllllllmmmmmMM..",
            "..mmMMmmmmmmmmmmmmmmMMmm..",
            "...mmmMMMMmmmmmmMMMMmmm...",
            "....mmmmmmMMMMMMmmmmmm....",
            ".....mmmmmmmmmmmmmmmm.....",
            "......mmmmmmmmmmmmmm......",
            "........mMMMMMMMMM........",
            ".........mmmmmmmmm........",
            "..........................",
        ],
        "solids": ('m', 'laAgp'),
    },
    "feast": {
        "rows": [
            "............................",
            "............................",
            "............................",
            "............................",
            "............................",
            "..........aaaa..............",
            "........aaa**aa.......aa....",
            ".....aaaAaAaaaa*aall.aaa....",
            "...aaaaaAaaaaaAaaa*alaaaa...",
            "..aaekaaaAaaaaaaaaAaaaaal...",
            "..assssssAsssssssaaaaaaall..",
            ".llsssssssssssssaammmaaamll.",
            ".lmmmssssssssssmmmmmmmaamml.",
            "llmmmmmmmmmmmmmmmmmmmmmmmmll",
            "MlmmmnnnmmmmmmmmmmmmmmmmmmlM",
            ".llmnnNnnmmmmmmmmmmmmmggmll.",
            ".MllmnnnmgggmmmmmmmggGmgllM.",
            "..MlllmmmmgGgmmmmmggGggllM..",
            "...MMllllmmmmmmmmmmllllMM...",
            ".....MMMllllllllllllMMM.....",
            "........MMMMMMMMMMMM........",
        ],
        "solids": ('aske', 'ml', 'ng'),
        "ground": 'ml',
        "dark": {'A': 3},
    },
    "shrimp": {
        "rows": [
            "..........................",
            "K.........................",
            ".K..hhhh..................",
            "..Khjjjjjh................",
            "..kjjjqjjjjr.K............",
            "...bbbbqjjjrM.K..hhhh.....",
            "....M.MbbjqrM..Khjjjjjh...",
            "......bbjjjrM..kjjjqjjjjr.",
            "...rr.bjjqrM....bbbbqjjjrM",
            "..rjjrjjjrrM.....M.MbbjqrM",
            "..rrqjqjrrMiiiii...bbjjjrM",
            "...rMMMMMMii*iiirr.bjjqrM.",
            "..iiiiiiiiiiiiirjjrjjjrrM.",
            ".iiiiiiIiiiiiiirrqjqjrrMi.",
            ".ii*iIIiiiiiiiiirMMMMMMii.",
            ".iiiIiiiiiiiiiIiiiiIIiiii.",
            ".iiiiiiii*iiIIiiiiiiiI*ii.",
            "..iiiiiiiiiIiiiiiiiiiiii..",
            "....iiiiiiiiiiiiiiiiii....",
            ".......iiii....iiii.......",
        ],
        "ground": 'i',
        "tones": {'h': ('l', 0), 'j': ('l', 1), 'q': ('l', 2), 'r': ('m', 1), 'M': ('m', 3), 'K': ('m', 4), 'b': ('a', 1), 'B': ('a', 3)},
    },
    "glowcap": {
        "rows": [
            "........................",
            "........................",
            "..........m.............",
            "......mmmmmmllm.........",
            ".....mmllmmmmmmm........",
            "....mmmlmmmmmmmmm.......",
            "...mmmmmmmmmmmllmm......",
            "...mmlmmmmlmmmmmmm......",
            "...mmmmmmmmmmmmmmm......",
            "....MMMMMMMMMMMmmmmmm...",
            ".........aaa..mmmmmmlm..",
            ".........aaa.mmmmmllmmm.",
            ".........aaa.mmmlmmmmmm.",
            ".........aaa..MMMMMMMMM.",
            "...mmmmm.aaa.....aa.....",
            "..mmllmmmaaa.....aa.....",
            "..mmmmmmmaaa.....aa.....",
            "...MMMMMMaaa.....aa.....",
            ".....aa..aaa.....aa.....",
            ".....aaddaaadddddaa.....",
            "..ddggaddaaadggddaagg...",
            "..dddddddddddddgddddd...",
            ".....ddddddddddddd......",
            "........................",
        ],
        "solids": ('ml',),
        "dark": {'M': 3},
    },
    "torch": {
        "rows": [
            "................................",
            "................................",
            "................................",
            "................................",
            "................................",
            "................................",
            "................................",
            "................................",
            "................................",
            "................................",
            ".................tttt...........",
            "................tttttt..........",
            "................cccccc..........",
            "...............CCcccc...........",
            "...............ccccCC...........",
            "..............CCcccc............",
            "..............cccccc............",
            ".............lmccCC.............",
            ".............lmmM...............",
            "............lmmM................",
            "...........lmmM.................",
            "..........lmmM..................",
            ".........lmmM...................",
            ".........lmmM...................",
            "........lmmM....................",
            ".......lmmM.....................",
            "......lmmM......................",
            "......lmmM......................",
            ".....lmmM.......................",
            "....lmmM........................",
            "................................",
            "................................",
        ],
        "solids": ('lm', 'ct'),
        "dark": {'C': 3},
    },
}


def _flame(frame):
    """The torch flame at `frame`: {(x, y): tone digit}, a teardrop on the torch head that
    leans and stretches as it flickers."""
    sway = (0, 1, 1, 0, -1, -1, 0, 1, 0, -1, 0, 1)[frame % ANIM_FRAMES]
    height = (8, 9, 8, 7, 8, 9, 9, 8, 7, 8, 9, 8)[frame % ANIM_FRAMES]
    cx, base = 19.0, 10
    flame = {}
    for step in range(height):
        t = step / height
        half = 3.2 * min(1.0, (t + 0.3) / 0.5) * (1.0 - t) ** 0.9
        mid = cx + sway * t * t * 2.2 + 0.6 * math.sin(t * 5.0 + frame) * t
        y = base - step
        for x in range(32):
            gap = abs(x + 0.5 - mid)
            if gap <= half + 0.25:
                core = gap / max(0.6, half) + t * 0.9
                flame[(x, y)] = "4" if core < 0.55 else "3" if core < 0.95 else "2" if core < 1.35 else "1"
    # The tongue's tip and a spark that drifts up from it.
    tip = base - height - 1 - frame % 2
    if frame % 4 < 2 and tip >= 2:
        flame[(round(cx + sway * 2), tip)] = "2"
    return flame


def _ramps(colors):
    main, light, accent = (B._rgb(c) for c in colors)
    ramps = {"m": B._ramp(main), "l": B._ramp(light), "a": B._ramp(accent)}
    ramps.update({key: B._ramp(value) for key, value in FIXED.items()})
    return ramps


def _components(parts, group):
    """Connected solids: touching pixels of the same SOLIDS group."""
    owner = {}
    solids = []
    for start in parts:
        if start in owner:
            continue
        index = len(solids)
        stack, members = [start], []
        owner[start] = index
        while stack:
            x, y = stack.pop()
            members.append((x, y))
            for q in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if q in parts and q not in owner and group(parts[q]) == group(parts[start]):
                    owner[q] = index
                    stack.append(q)
        xs = [x for x, _ in members]
        ys = [y for _, y in members]
        solids.append(((min(xs) + max(xs) + 1) / 2, (min(ys) + max(ys) + 1) / 2,
                       max(1.5, (max(xs) - min(xs) + 1) / 2), max(1.5, (max(ys) - min(ys) + 1) / 2)))
    return owner, solids


def icon(style, colors, frame=0):
    """RGBA rows of a 32x32 icon of `style` in the item's colours; frame flickers a flame."""
    spec = STYLES[style]
    rows = spec["rows"]
    width, height = len(rows[0]), len(rows)
    left, top = (32 - width) // 2 + spec.get("shift", (0, 0))[0], (32 - height) // 2 + spec.get("shift", (0, 0))[1]
    parts = {}
    for y, row in enumerate(rows):
        for x, letter in enumerate(row):
            if letter != ".":
                parts[(left + x, top + y)] = letter
    if style in ANIMATED:
        parts.update(_flame(frame))
    groups = {letter: index for index, solid in enumerate(spec.get("solids", ())) for letter in solid}
    ground = spec.get("ground", "")
    depth = spec.get("depth", {})

    def group(letter):
        family = letter.lower()
        return groups.get(family, family)

    owner, solids = _components(parts, group)
    ramps = _ramps(colors)
    pixels = [[None] * 32 for _ in range(32)]
    for (x, y), letter in parts.items():
        if letter in FLAME:
            pixels[y][x] = FLAME[letter] + (255,)
            continue
        if letter == "*":
            pixels[y][x] = GLINT + (255,)
            continue
        if letter in spec.get("tones", {}):
            family, level = spec["tones"][letter]
            pixels[y][x] = ramps[family][level] + (255,)
            continue
        family = letter.lower()
        cx, cy, rx, ry = solids[owner[(x, y)]]
        bend = depth.get(family, 0.8)
        nx = max(-1.0, min(1.0, (x + 0.5 - cx) / rx)) * bend
        ny = max(-1.0, min(1.0, (y + 0.5 - cy) / ry)) * bend
        nz = math.sqrt(max(0.0, 1.0 - nx * nx - ny * ny))
        light = B.LIGHT[0] * nx + B.LIGHT[1] * ny + B.LIGHT[2] * nz
        level = (0.95 - light) * 3.2
        if family in "ml":
            noise = B._hash(x, y, 3) % 9
            level += 0.5 if noise == 0 else -0.45 if noise == 1 else 0.0
        level = round(level)
        # A darker seam where this solid ends against another below or to the right.
        for q in ((x + 1, y), (x, y + 1)):
            if q in owner and owner[q] != owner[(x, y)] and parts[q] not in FLAME and parts[q] != "*":
                level = max(level, 3)
        # The food casts a shadow down and right onto the plate, platter, or ice.
        if family in ground:
            level += sum(1 for q in ((x - 1, y - 1), (x, y - 1), (x - 1, y))
                         if q in parts and parts[q].lower() not in ground and parts[q] not in FLAME)
        if letter != family:
            level = spec.get("dark", {}).get(letter, 4)
        pixels[y][x] = ramps[family][max(0, min(4, level))] + (255,)
    for (x, y) in list(parts):
        for q in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if q not in parts and 0 <= q[0] < 32 and 0 <= q[1] < 32:
                pixels[q[1]][q[0]] = B.FIXED["o"] + (255,)
    return pixels
