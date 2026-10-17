"""Hand-pixelled wands and rods (32x32) in the classic style: a big, richly shaded head at the top
and a thin shaft standing nearly upright, slanting a pixel to the right every SLANT rows down to a
pommel. Every item has its own head, each modelled on a classic wand or rod (STYLES).

A head is a letter map drawn as it appears in the icon; '+' marks where the shaft begins. Each
connected area of one material is shaded as a rounded solid lit from the top-left (pixel_bags.py's
five-tone ramps), gems, metal, and glass get a bright glint, and a dark line separates parts of
different materials; a dark outline goes round the whole item.

Letters:  m l a  the item's main, light, and accent colours     g glowing accent
          t T    wood, dark wood       y gold    s silver    k near-black    w white    e leaf
          b      bone                  o      a dark line inside the head (drawn as the outline)

make_sprites.py calls icon(style, colors).
"""

import pixel_bags as B

SIZE = 32
OUTLINE = (24, 18, 20)
FIXED = {"t": (138, 96, 58), "T": (92, 62, 38), "y": (216, 168, 58), "s": (176, 184, 192),
         "k": (34, 26, 30), "w": (240, 236, 228), "e": (96, 160, 62), "b": (232, 222, 196)}
# Glossy materials (gems, metal, glass) get a bright glint where the light strikes each part.
GLOSSY = "agsylm"
# Where each head map's top-left corner sits; the shaft slants one pixel right every SLANT rows.
HEAD_AT = (4, 2)
SLANT = 4
# Heads are grown by GROW (rows and columns repeat in a steady rhythm) before shading, so their
# outlines, seams, and glints stay one pixel crisp.
GROW = 1.3

HEADS = {
    # The ember wand: a flame crystal standing in a crown of gold leaves.
    "ember": [
        "........a.........",
        ".......aga........",
        "......aggga.......",
        "......agwga.......",
        ".....aggggga......",
        ".....aggwgga......",
        ".....aggggga......",
        "......aggga.......",
        "...y..aggga..y....",
        "...yy.yaaay.yy....",
        "....yyyyyyyyy.....",
        ".....yy.y.yy......",
        "......yyyyy.......",
        ".......yyy........",
        ".......+..........",
    ],
    # The crystal wand: a glossy orb held in four dark claws.
    "orb": [
        "......oooo........",
        "....oaaaaaao......",
        "...oaagwaaaao.....",
        "...oagwgaaaao.....",
        "..oaagaaaaaaao....",
        "..oaaaaaaaaaao....",
        "..oaaaaaaaaaao....",
        "...oaaaaaaaao.....",
        "...soaaaaaaos.....",
        "..ss.oooooo.ss....",
        "..s...s..s...s....",
        "...s..ssss..s.....",
        "....ssssssss......",
        "......ssss........",
        ".......+..........",
    ],
    # The ruby sceptre: a long ruby point set in a gold collar.
    "ruby": [
        "........a.........",
        ".......aga........",
        ".......aga........",
        "......aggga.......",
        "......agwga.......",
        "......aggga.......",
        ".....aggggga......",
        ".....aggggga......",
        ".....aagggaa......",
        "....y.aaaaa.y.....",
        "....yyyyyyyyy.....",
        ".....yy.y.yy......",
        "......yyyyy.......",
        ".......yyy........",
        ".......+..........",
    ],
    # The volcano wand: a club of black rock cracked with glowing lava.
    "volcano": [
        ".....kkkkkk.......",
        "...kkmmmmmmkk.....",
        "..kmmmgmmmmmmk....",
        "..kmmggmmmgmmk....",
        ".kmmmmgmmggmmmk...",
        ".kmgmmmmmgmmmmk...",
        ".kmggmmmmmmmgmk...",
        ".kmmmgmmmgmmmmk...",
        "..kmmmggmmmmmk....",
        "..kkmmmmmmmkk.....",
        "....kkmmmkk.......",
        "......TTT.........",
        "......TTT.........",
        ".......+..........",
    ],
    # The thunder wand: a spiked silver spire round a crackling core.
    "spiral": [
        ".......s..........",
        "......sss.........",
        "....s.sss.s.......",
        ".....ssgss........",
        "...ss.sgs.ss......",
        "....sssgsss.......",
        "..s...sgs...s.....",
        "...ss.sgs.ss......",
        ".....sssss........",
        "......sss.........",
        ".....s.s.s........",
        "......sss.........",
        ".......s..........",
        ".......+..........",
    ],
    # A reliquary cage of gold bars round a glowing core.
    "cage": [
        "......yyyy........",
        "....yy.yy.yy......",
        "...y..y..y..y.....",
        "..y..y.gg.y..y....",
        "..y.y.ggwg.y.y....",
        "..y.y.gggg.y.y....",
        "..y.y.gggg.y.y....",
        "..y..y.gg.y..y....",
        "...y..y..y..y.....",
        "....yy.yy.yy......",
        "......yyyy........",
        ".......yy.........",
        ".......+..........",
    ],
    # The shamanic energy staff: two forked prongs with a spark between them.
    "fork": [
        "..m.........m.....",
        "..mm..g.g..mm.....",
        "...mm..g..mm......",
        "...mm.ggg.mm......",
        "....mm.g.mm.......",
        "....mmm.mmm.......",
        ".....mmmmm........",
        "......yyy.........",
        "......mam.........",
        "......yyy.........",
        ".......m..........",
        ".......+..........",
    ],
    # The purple stigma: a serpent coiled into a hook round a gem.
    "hook": [
        "....mmmmm.........",
        "...mllllmm........",
        "..mlmmmmlmm.......",
        "..mlm...mlm.......",
        "..mm..a..mm.......",
        "..mm.ag..mm.......",
        "...m.....mm.......",
        "........mlm.......",
        ".......mlm........",
        "......mlm.........",
        ".....mlm..........",
        "......mm..........",
        ".......+..........",
    ],
    # Spellweaver's fortune: a banded hook curling over.
    "curl": [
        ".....aaaaa........",
        "...aallllaa.......",
        "..alm...mlaa......",
        "..am.....mla......",
        ".am.......ma......",
        ".am.......la......",
        "..a.......ma......",
        ".........mla......",
        "........mla.......",
        ".......yyy........",
        ".......yy.........",
        ".......m..........",
        ".......+..........",
    ],
    # The emerald sceptre: a faceted crystal spike on a dark socket.
    "crystal": [
        "........l.........",
        ".......lml........",
        ".......lmm........",
        "......lmgmm.......",
        "......lmgmm.......",
        ".....lmmgmmm......",
        ".....lmmgmmm......",
        ".....lmmmmmm......",
        "......mmmmm.......",
        ".....kyyyyyk......",
        "......kkkkk.......",
        ".......kkk........",
        ".......+..........",
    ],
    # The toxic rod: a ribbed fan like a cobra's hood.
    "fan": [
        "...mmmmmmmmmm.....",
        "..mlmlmlmlmlmm....",
        ".mlmlmlmlmlmlmm...",
        ".mlmlmlmlmlmlmm...",
        ".mmlmlmlmlmlmm....",
        "..mmlmlmlmlmm.....",
        "...mmlmlmlmm......",
        "....mmlmlmm.......",
        ".....mmlmm........",
        "......mmm.........",
        "......aaa.........",
        ".......a..........",
        ".......+..........",
    ],
    # The serpent sceptre: a round gem on a scaled collar.
    "serpent": [
        ".....aaaaa........",
        "....aggggaa.......",
        "...aggwggaaa......",
        "...agwggaaaa......",
        "...aggggaaaa......",
        "...aaggaaaaa......",
        "....aaaaaaa.......",
        ".....aaaaa........",
        "....mmmmmmm.......",
        ".....m.m.m........",
        "......mmm.........",
        ".......m..........",
        ".......+..........",
    ],
    # The gnomish rod: a branch splitting into two crooked tines.
    "branch": [
        ".t..............t.",
        ".tt............tt.",
        "..tt..........tt..",
        "...tt........tt...",
        "....tt......tt....",
        ".....tt....tt.....",
        "......tt..tt......",
        ".......tttt.......",
        "...tt...tt........",
        "....tt..tt........",
        ".....tttt.........",
        ".......tt.........",
        ".......tt.........",
        ".......+..........",
    ],
    # The heat staff: a charred club head with embers in the cracks.
    "club": [
        ".....TTTTTT.......",
        "...TTttttttTT.....",
        "..TttgttttttTT....",
        "..TttttttgtttT....",
        ".TttTtttttttttT...",
        ".TtttttgttTtttT...",
        ".TttttttttttttT...",
        "..TttgtttttttT....",
        "..TTttttttttTT....",
        "....TTaaaaTT......",
        "......aaaa........",
        ".......TT.........",
        ".......TT.........",
        ".......+..........",
    ],
    # The sceptre of nature: a green gem in a knot of dark wood.
    "knot": [
        ".....TT..TT.......",
        "....TttTTttT......",
        "...TtaaaaaatT.....",
        "..TtaggggwatT.....",
        "..TaggwggggaT.....",
        "..TaggggggggaT....",
        "..TaaggggggaaT....",
        "...TaaaaaaaaT.....",
        "....TTttttTT......",
        "......TttT........",
        ".......TT.........",
        ".......TT.........",
        ".......+..........",
    ],
    # Gorlag's rod: a crooked branch bent over into a hook.
    "crook": [
        ".....tttttt.......",
        "...tttT....tt.....",
        "..ttT.......tt....",
        "..tt.........t....",
        "..t..........tt...",
        "...t.........tt...",
        ".............tt...",
        "............tt....",
        "...........tt.....",
        "..........tt......",
        ".........tt.......",
        "........tt........",
        ".......+..........",
    ],
    # The ominous rod: a root curled into a hood round a glowing seed.
    "root": [
        "....TTTTTTT.......",
        "...TttttttttT.....",
        "..TttTTTTTttT.....",
        ".TttT.....TttT....",
        ".TtT..gg...TtT....",
        ".Tt...gwg...tT....",
        ".Tt...ggg...tT....",
        "..T.........tT....",
        "...........TtT....",
        "..........TtT.....",
        "........TttT......",
        ".......TtT........",
        ".......+..........",
    ],
    # The imperial rod: a jade trident with leaves curling from its foot.
    "jade": [
        ".m......m......m..",
        ".mm.....m.....mm..",
        "..mm...mlm...mm...",
        "...m...mlm...m....",
        "...mm..mlm..mm....",
        "....mmmmlmmmm.....",
        ".e...mmmmmmm...e..",
        ".ee...mmmmm...ee..",
        "..eee..yyy..eee...",
        "....eeeyyyeee.....",
        ".......yyy........",
        ".......mm.........",
        ".......+..........",
    ],
    # The whirlwind sceptre: a gnarled whorl of wood round a glowing knot.
    "whorl": [
        ".....TTTT.........",
        "...TTttttTT.......",
        "..TttTTTttT.......",
        ".TttT..TttT.......",
        ".Ttt.gg.TtT.......",
        ".TtT.gg.TtT.......",
        "..TtT..TttT.......",
        "...TttTttT........",
        "....TtttT.........",
        ".....TttT.........",
        "......TtT.........",
        ".......TT.........",
        ".......+..........",
    ],
    # The crypt jaw: a skull on the end of a stick.
    "skull": [
        ".....bbbbbb.......",
        "....bbbbbbbb......",
        "...bbbbbbbbbb.....",
        "...bbkkbbkkbb.....",
        "...bbkkbbkkbb.....",
        "...bbbbkkbbbb.....",
        "....bbbbbbbb......",
        "....bkbkbkbb......",
        ".....bbbbbb.......",
        ".......mm.........",
        "......mmmm........",
        ".......mm.........",
        ".......+..........",
    ],
    # The deepling fork: a glassy crystal flanked by fins.
    "fin": [
        "...l.....l........",
        "...lal..lal.......",
        "....lal.lal..l....",
        "....laallal.lal...",
        ".....laaaaaalal...",
        ".....lagwaaaal....",
        "......aggaaal.....",
        "......aaaaal......",
        ".......aaal.......",
        ".......mmm........",
        ".......mmm........",
        ".......mm.........",
        ".......+..........",
    ],
    # The springsprout rod: a sprout of leaves and curling vines.
    "sprout": [
        "..ee..........ee..",
        ".e..e........e..e.",
        ".e.ee........ee.e.",
        "..ee...e..e...ee..",
        ".......ee.ee......",
        "...eeeeeeeeeeee...",
        "..eaaeee..eeeaae..",
        "...ee.e....e.ee...",
        ".......tttt.......",
        "........tt........",
        "........tt........",
        "........tt........",
        "........+.........",
    ],
    # The ornate rod: golden antlers round a glowing gem.
    "antlers": [
        ".y..y........y..y.",
        ".yy.y...ll...y.yy.",
        "..yyy..llll..yyy..",
        "...yy..l..l..yy...",
        "....yyy.aa.yyy....",
        ".....yyagway......",
        ".....yaggggay.....",
        "......yaggay......",
        ".......yaay.......",
        "........yy........",
        "........aa........",
        "........yy........",
        "........+.........",
    ],
    # The terra rod: a green orb atop a thorned shaft.
    "thorns": [
        "......aaaaa.......",
        ".....aaggwaa......",
        ".....agggggaa.....",
        ".....aagggaaa.....",
        "......aaaaa.......",
        "......s.m.s.......",
        ".......mmm........",
        "......s.m.s.......",
        ".......mmm........",
        "......s.m.s.......",
        ".......mmm........",
        ".......mmm........",
        ".......+..........",
    ],
}
STYLES = {
    # Wands (sorcerers).
    "kindling": {"head": "ember", "shaft": "t", "pommel": "cap", "bands": ()},
    "spark": {"head": "orb", "shaft": "k", "pommel": "ball", "bands": (5,)},
    "embercrown": {"head": "ruby", "shaft": "m", "pommel": "gem", "bands": (4, 10)},
    "flame": {"head": "volcano", "shaft": "T", "pommel": "spike", "bands": (6,)},
    "silverfire": {"head": "spiral", "shaft": "s", "pommel": "ball", "bands": (4,)},
    "reliquary": {"head": "cage", "shaft": "m", "pommel": "gem", "bands": (3, 8)},
    "seerfork": {"head": "fork", "shaft": "m", "pommel": "cap", "bands": (5,)},
    "spindle": {"head": "hook", "shaft": "m", "pommel": "spike", "bands": (7,)},
    "dusk": {"head": "curl", "shaft": "m", "pommel": "ball", "bands": (4, 9)},
    "cinderheart": {"head": "crystal", "shaft": "k", "pommel": "gem", "bands": (3, 8)},
    "starless": {"head": "fan", "shaft": "a", "pommel": "spike", "bands": (5,)},
    "gravecall": {"head": "serpent", "shaft": "m", "pommel": "gem", "bands": (4, 10)},
    # Rods (druids).
    "sapling": {"head": "branch", "shaft": "t", "pommel": "cap", "bands": ()},
    "thornwood": {"head": "club", "shaft": "T", "pommel": "cap", "bands": (6,)},
    "moss": {"head": "knot", "shaft": "T", "pommel": "ball", "bands": (5,)},
    "alder": {"head": "crook", "shaft": "t", "pommel": "cap", "bands": ()},
    "rootbound": {"head": "root", "shaft": "T", "pommel": "ball", "bands": (6,)},
    "silverleaf": {"head": "jade", "shaft": "m", "pommel": "gem", "bands": (4,)},
    "stalker": {"head": "whorl", "shaft": "T", "pommel": "spike", "bands": (5, 10)},
    "duskroot": {"head": "skull", "shaft": "m", "pommel": "gem", "bands": (4,)},
    "wyrmglass": {"head": "fin", "shaft": "m", "pommel": "gem", "bands": (3, 9)},
    "bloomheart": {"head": "sprout", "shaft": "t", "pommel": "ball", "bands": (5,)},
    "nightbloom": {"head": "antlers", "shaft": "y", "pommel": "gem", "bands": ()},
    "thornscale": {"head": "thorns", "shaft": "m", "pommel": "spike", "bands": (3, 6, 9)},
}


def _rgb(value):
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def _ramps(colors):
    main, light, accent = (_rgb(c) for c in colors[:3])
    ramps = {letter: B._ramp(color) for letter, color in FIXED.items()}
    ramps.update({"o": [OUTLINE] * 5, "m": B._ramp(main), "l": B._ramp(light), "a": B._ramp(accent),
                  "g": B._ramp(tuple(min(255, round(c * 1.15 + 30)) for c in accent))})
    return ramps


def _layout(style):
    """({(x, y): letter} for the whole item: head, shaft, bands, and pommel; the shaft's cells)."""
    spec = STYLES[style]
    cells = {}
    start = None
    for y, row in enumerate(HEADS[spec["head"]]):
        for x, letter in enumerate(row):
            if letter == ".":
                continue
            x0, x1 = int(x * GROW), int((x + 1) * GROW)
            y0, y1 = int(y * GROW), int((y + 1) * GROW)
            if letter == "+":
                start = (HEAD_AT[0] + x0, HEAD_AT[1] + y0)
                continue
            for gy in range(y0, y1):
                for gx in range(x0, x1):
                    cells[(HEAD_AT[0] + gx, HEAD_AT[1] + gy)] = letter
    # The shaft: two pixels wide, nearly upright, down to the pommel, with a gold ferrule under
    # the head and above the pommel.
    x, y = start
    length = 0
    shaft = set()
    while y < SIZE - 5:
        ferrule = length < 2 or y >= SIZE - 6
        letter = "y" if length in spec["bands"] or ferrule else spec["shaft"]
        if not ferrule:
            shaft |= {(x, y), (x + 1, y)}
        cells.setdefault((x, y), letter)
        cells.setdefault((x + 1, y), letter)
        y, length = y + 1, length + 1
        if length % SLANT == 0:
            # A pixel of overlap where the shaft steps right keeps its edge a smooth slant.
            cells.setdefault((x + 2, y - 1), letter)
            x += 1
    ex, ey = x, y
    pommel = spec["pommel"]
    if pommel == "ball":
        for dx, dy in ((0, 0), (1, 0), (-1, 1), (0, 1), (1, 1), (2, 1), (0, 2), (1, 2)):
            cells[(ex + dx, ey + dy)] = "y"
    elif pommel == "gem":
        cells[(ex, ey)] = cells[(ex + 1, ey)] = "y"
        for dx, dy in ((-1, 1), (0, 1), (1, 1), (2, 1), (0, 2), (1, 2)):
            cells[(ex + dx, ey + dy)] = "a"
    elif pommel == "spike":
        for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1), (1, 2)):
            cells[(ex + dx, ey + dy)] = "s"
    else:
        for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
            cells[(ex + dx, ey + dy)] = "y" if spec["shaft"] in "tT" else spec["shaft"]
    return cells, shaft


def _domes(cells):
    """A dome over each connected area of one letter."""
    domes, seen = {}, set()
    for start in cells:
        if start in seen:
            continue
        letter = cells[start]
        stack, group = [start], []
        seen.add(start)
        while stack:
            x, y = stack.pop()
            group.append((x, y))
            for q in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if cells.get(q) == letter and q not in seen:
                    seen.add(q)
                    stack.append(q)
        xs = [x for x, _ in group]
        ys = [y for _, y in group]
        dome = ((min(xs) + max(xs) + 1) / 2, (min(ys) + max(ys) + 1) / 2,
                max(1.5, (max(xs) - min(xs) + 1) / 2), max(1.5, (max(ys) - min(ys) + 1) / 2), 0.95)
        for cell in group:
            domes[cell] = dome
    return domes


def icon(style, colors):
    """RGBA rows of a 32x32 wand or rod icon."""
    cells, shaft = _layout(style)
    ramps = _ramps(colors)
    domes = _domes(cells)
    # Each glossy part's glint: its cell nearest the point the light strikes.
    glints = {}
    for cell, dome in domes.items():
        if cells[cell] not in GLOSSY:
            continue
        cx, cy, rx, ry, _depth = dome
        spot = (cx - rx * 0.45, cy - ry * 0.45)
        gap = (cell[0] + 0.5 - spot[0]) ** 2 + (cell[1] + 0.5 - spot[1]) ** 2
        if dome not in glints or gap < glints[dome][0]:
            glints[dome] = (gap, cell)
    shine = {cell for gap, cell in glints.values() if domes[cell][2] >= 2 and domes[cell][3] >= 2}
    pixels = [[None] * SIZE for _ in range(SIZE)]
    for (x, y), letter in cells.items():
        if not (0 <= x < SIZE and 0 <= y < SIZE):
            continue
        if letter == "o":
            pixels[y][x] = OUTLINE + (255,)
            continue
        level = B._tone("P", domes[(x, y)], x, y, 0.0, grain=letter in "tT")
        # Thin strokes (shafts, prongs): lit on the left, shaded on the right.
        if (x - 1, y) not in cells:
            level = max(0, level - 1) if (x + 3, y) not in cells else level
        elif (x + 1, y) not in cells and (x - 3, y) not in cells:
            level = min(4, level + 1)
        # Rim light: every part's top-left edge catches the light, its bottom-right edge falls dark.
        if cells.get((x - 1, y)) != letter or cells.get((x, y - 1)) != letter:
            level = max(0, level - 1)
        elif cells.get((x + 1, y)) != letter or cells.get((x, y + 1)) != letter:
            level = min(4, level + 1)
        # Faceted gems: the half facing the light bright, the far half deep.
        if letter in "ag" and (x, y) not in shaft:
            cx, cy, rx, ry, _depth = domes[(x, y)]
            if rx >= 2 and ry >= 2:
                level = max(0, level - 1) if (x + 0.5 - cx) + (y + 0.5 - cy) < 0 else min(4, level + 1)
        # Wood grain along the length, and a spiral wrap round wooden and cloth shafts.
        if letter in "tT" and B._hash(x, y // 3, 7) % 5 == 0:
            level = min(4, level + 1)
        if (x, y) in shaft and STYLES[style]["shaft"] in "tTml" and (x + y) % 4 == 0:
            level = min(4, level + 2)
        # Where two parts meet, a dark line separates them, as in classic item art.
        seam = any(cells.get((x + dx, y + dy)) not in (None, letter, "o") and letter not in "gw"
                   and cells.get((x + dx, y + dy)) not in "gw" for dx, dy in ((1, 0), (0, 1)))
        if letter == "g":
            level = min(level, 1)
        if letter == "w":
            level = 0
        if letter == "k":
            level = max(level, 3)
        color = ramps[letter][level]
        if seam:
            color = tuple(round(c * 0.45 + o * 0.55) for c, o in zip(ramps[letter][4], OUTLINE))
        if (x, y) in shine:
            color = tuple(round(c + (255 - c) * 0.75) for c in ramps[letter][0])
        pixels[y][x] = color + (255,)
    # A sparkle cross on every glint of a large gem.
    for x, y in shine:
        if cells[(x, y)] in "ag" and domes[(x, y)][2] >= 3:
            for dx, dy in ((1, 0), (0, 1)):
                if cells.get((x + dx, y + dy)) == cells[(x, y)]:
                    pixels[y + dy][x + dx] = tuple(round(c + (255 - c) * 0.45) for c in ramps[cells[(x, y)]][0]) + (255,)
    for (x, y) in list(cells):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if q not in cells and 0 <= q[0] < SIZE and 0 <= q[1] < SIZE:
                pixels[q[1]][q[0]] = OUTLINE + (255,)
    return pixels
