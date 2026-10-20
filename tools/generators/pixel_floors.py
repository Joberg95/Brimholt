"""Hand-pixelled floor tiles (32x32) in the shaded classic style: every material is one five-tone
ramp (light to dark, warm lights and cooler shadows), lit from the top-left, with readable material
detail (blades, clods, pebbles, ripples, setts, bricks, boards, flagstones) about every 6-8 px.

Seams. The game picks one of four variants per cell (water: one of four frames, each cell at its
own point in the cycle), so every variant must meet every other variant of its material without a
seam, and itself when repeated. Two rules give that:

* Fields (the soft light and dark patches a material is shaded from) are tileable (period 32) and
  shared by all variants within FADE pixels of the tile's border; inside, each variant fades to a
  field of its own (_field), so variants differ without the border ever changing.
* Scattered details (_scatter) near the border are the same in every variant and wrap round the
  tile edge; details further in belong to the variant and never reach the border. Built floors
  (cobble, bricks, boards) lay their joints the same way in every variant and vary only the stones
  that lie wholly inside.

The terrain shader (game/render/terrain.gdshader) blends natural ground into its neighbours and
animates water on top (swell, glints, shore foam); built floors keep hard edges and exact texels.

make_sprites.py calls tile(kind, variant) for each cell of tiles.png and gets rows of RGBA tuples.
"""

import math

SIZE = 32
FADE = 6


def _hex(value, alpha=255):
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha)


def _ramp(*values):
    return tuple(_hex(value) for value in values)


# Five tones each, light to dark.
GRASS = _ramp("9fbd5e", "80a546", "66893a", "4d6f2e", "375323")
DIRT = _ramp("ab9370", "947c5b", "7c674a", "64533c", "4a3e2e")
SAND = _ramp("e6d6a4", "d6c38f", "c1ac7a", "a38f63", "82714d")
GRAVEL = _ramp("aeaba1", "939088", "7a7870", "615f59", "474641")
COBBLE = _ramp("b9b8ae", "9e9d93", "84837a", "6a6961", "4a4944")
MORTAR = _hex("55534c")
SNOW = _ramp("f6f9fb", "e5ecf2", "cfdae5", "b2c2d3", "91a5bb")
ICE = _ramp("e4f2f6", "c4e0ea", "a2cbd9", "7fb0c4", "5e91a8")
BOG = _ramp("75714a", "605d3d", "4d4b31", "3c3a26", "2a291b")
BOG_WATER = _ramp("6f7d6c", "56645a", "414e47", "303b36", "212a27")
DUSK = _ramp("806f8c", "695a75", "54475f", "40364b", "2d2536")
DUSK_CRYSTAL = _ramp("d6c4f0", "a98fd6", "7a62ad", "523f80", "352a58")
CAVE = _ramp("938a7e", "7d7469", "686056", "534c44", "3d3833")
BRICK = _ramp("94573f", "7c4734", "663a2a", "512e21", "3a2018")
BRICK_MORTAR = _hex("241712")
PLANK = _ramp("b48e5f", "9a774c", "7f613d", "654c2f", "473520")
NAIL = _ramp("c9c6bc", "8f8c84", "55534e", "3a3935", "262523")
OBSIDIAN = _ramp("5d4d76", "45395c", "342b47", "251e35", "171224")
RUNE = _ramp("e4d4ff", "b597f2", "8a6ad6", "6447a8", "40307a")
WATER = _ramp("86b6cf", "5d93b3", "437898", "33617f", "254b66")
STONE = _ramp("aaa69a", "8f8b80", "757168", "5b5850", "403e39")
CAVE_EARTH = _ramp("a0745a", "885f48", "714d3a", "5a3d2e", "402b21")
SANDSTONE = _ramp("ece0bf", "ddcda6", "cbb994", "b19f7c", "8e7c5e")
FLAG_JOINT = _hex("6d5f49")
CARPET = _ramp("dc4a30", "c43822", "a62b19", "862111", "5e170b")
FRINGE = _ramp("f6cf5a", "e6a835", "bd7f22", "8c5a17", "5a3a10")
FLOWERS = (_hex("f2eee0"), _hex("e8d36a"), _hex("c9a0d8"))
FLOWER_HEART = _hex("d8a83a")


def _hash(x, y, seed):
    """A repeatable integer in [0, 65536) for a lattice point and a seed."""
    value = (x * 73856093) ^ (y * 19349663) ^ (seed * 83492791)
    value = (value ^ (value >> 13)) * 1274126177
    return (value ^ (value >> 16)) & 0xFFFF


def _unit(x, y, seed):
    return _hash(x, y, seed) / 65536.0


def _noise(x, y, cell, seed):
    """Smooth value noise on a lattice of `cell` px that wraps every SIZE px."""
    count = SIZE // cell
    gx, gy = x / cell, y / cell
    x0, y0 = math.floor(gx), math.floor(gy)
    fx, fy = gx - x0, gy - y0
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)

    def corner(i, j):
        return _unit((x0 + i) % count, (y0 + j) % count, seed)

    top = corner(0, 0) * (1 - fx) + corner(1, 0) * fx
    bottom = corner(0, 1) * (1 - fx) + corner(1, 1) * fx
    return top * (1 - fy) + bottom * fy


def _fbm(x, y, seed, octaves=((16, 0.5), (8, 0.3), (4, 0.2))):
    return sum(_noise(x, y, cell, seed + index * 101) * weight for index, (cell, weight) in enumerate(octaves))


def _border_weight(x, y):
    """1 on the tile's border, falling to 0 FADE px in."""
    distance = min(x % SIZE, SIZE - 1 - x % SIZE, y % SIZE, SIZE - 1 - y % SIZE)
    t = max(0.0, min(1.0, distance / FADE))
    return 1.0 - t * t * (3 - 2 * t)


def _field(x, y, seed, variant, octaves=((16, 0.5), (8, 0.3), (4, 0.2))):
    """The shared field near the border, the variant's own further in; wraps every SIZE px."""
    common = _fbm(x, y, seed, octaves)
    own = _fbm(x, y, seed + 7919 * (variant + 1), octaves)
    weight = _border_weight(x, y)
    return common * weight + own * (1 - weight)


def _lit(field, x, y, strength=4.0):
    """How much a height field faces the top-left light at a pixel (positive is lit)."""
    return (field(x - 1, y - 1) - field(x + 1, y + 1)) * strength


def _canvas(color):
    return [[color] * SIZE for _ in range(SIZE)]


def _put(pixels, x, y, color):
    pixels[y % SIZE][x % SIZE] = color


def _get(pixels, x, y):
    return pixels[y % SIZE][x % SIZE]


def _scatter(seed, variant, spacing, margin):
    """Jittered lattice points for details: [(x, y, salt)]. Points within `margin` of the border
    are the same in every variant (and may wrap); the rest belong to the variant and keep clear of
    the border by `margin`."""
    points = []
    count = SIZE // spacing
    for j in range(count):
        for i in range(count):
            jx = _hash(i, j, seed) % spacing
            jy = _hash(i, j, seed + 1) % spacing
            x, y = i * spacing + jx, j * spacing + jy
            near = min(x, SIZE - 1 - x, y, SIZE - 1 - y) < margin
            if near:
                points.append((x, y, _hash(i, j, seed + 2)))
                continue
            vx = i * spacing + _hash(i, j, seed + 11 * (variant + 3)) % spacing
            vy = j * spacing + _hash(i, j, seed + 13 * (variant + 3)) % spacing
            if min(vx, SIZE - 1 - vx, vy, SIZE - 1 - vy) >= margin:
                points.append((vx, vy, _hash(i, j, seed + 17 * (variant + 3))))
    return points


def _shade_ground(ramp, seed, variant, low=0.34, high=0.66, light=1.0, octaves=((8, 0.5), (4, 0.35), (2, 0.15))):
    """Ground shaded in clusters from a field: mid tone, one lighter on rises, one darker in
    hollows, and a step lighter or darker where the slope faces toward or away from the light."""
    pixels = _canvas(ramp[2])

    def field(px, py):
        return _field(px, py, seed, variant, octaves)

    for y in range(SIZE):
        for x in range(SIZE):
            height = field(x, y)
            tone = 2
            if height > high:
                tone = 1
            elif height < low:
                tone = 3
            slope = _lit(field, x, y, 2.0)
            if slope > light * 0.5 and tone > 1:
                tone -= 1
            elif slope < -light * 0.5 and tone < 3:
                tone += 1
            pixels[y][x] = ramp[max(0, min(4, tone))]
    return pixels


def _pebble(pixels, x, y, size, ramp, ground_dark):
    """A small stone lit from the top-left, with a shadow falling to its lower right."""
    cells = [(dx, dy) for dy in range(size) for dx in range(size) if not (size > 2 and (dx, dy) in
             ((0, 0), (size - 1, 0), (0, size - 1), (size - 1, size - 1)))]
    for dx, dy in cells:
        _put(pixels, x + dx + 1, y + dy + 1, ground_dark)
    for dx, dy in cells:
        tone = 2
        if dx + dy == 0 or (size > 2 and dx + dy == 1):
            tone = 0
        elif dx == size - 1 or dy == size - 1:
            tone = 3
        _put(pixels, x + dx, y + dy, ramp[tone])


# ---------------------------------------------------------------- natural ground

def grass(variant):
    """Grass: soft rises and hollows, many small tufts (a dark root, mid blades, a lit tip that
    leans right), a few light flecks; variant 3, the rare one, has small wild flowers."""
    pixels = _shade_ground(GRASS, 100, variant, low=0.3, high=0.7)
    for x, y, salt in _scatter(110, variant, 6, 3):
        # A tuft: blades fanning out from a dark root, the middle one tallest, tips lit.
        lean = (0, 1, -1)[salt % 3]
        _put(pixels, x, y, GRASS[4])
        _put(pixels, x + 1, y, GRASS[3])
        for dx, height in ((-1, 1 + salt % 2), (0, 2 + (salt >> 2) % 2), (1, 1 + (salt >> 4) % 2)):
            if dx and (salt >> (6 + dx)) % 3 == 0:
                continue
            for step in range(1, height + 1):
                bx = x + dx * (1 + step // 2) + (lean if step == height and height > 1 else 0)
                _put(pixels, bx, y - step, GRASS[0] if step == height else GRASS[2])
    for x, y, salt in _scatter(130, variant, 8, 2):
        if salt % 3:
            continue
        _put(pixels, x, y, GRASS[1])
        if salt % 2:
            _put(pixels, x + 1, y + 1, GRASS[1])
    if variant == 3:
        for x, y, salt in _scatter(150, variant, 11, 4)[:4]:
            petal = FLOWERS[salt % len(FLOWERS)]
            for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
                _put(pixels, x + dx, y + dy, petal)
            _put(pixels, x, y, FLOWER_HEART)
            _put(pixels, x + 1, y + 2, GRASS[4])
    return pixels


def dirt(variant):
    """Packed earth: clods lit on their top-left with a shadow under them, small stones, and a
    few dry cracks."""
    pixels = _shade_ground(DIRT, 200, variant)
    for x, y, salt in _scatter(210, variant, 8, 3):
        if salt % 5 == 0:
            _pebble(pixels, x, y, 2, STONE, DIRT[4])
        else:
            width = 2 + salt % 2
            for dx in range(width):
                _put(pixels, x + dx, y, DIRT[1] if dx == 0 else DIRT[2])
                _put(pixels, x + dx, y + 1, DIRT[3])
            _put(pixels, x, y - 1, DIRT[0])
    for x, y, salt in _scatter(230, variant, 16, 5):
        cx, cy = x, y
        for step in range(3 + salt % 3):
            _put(pixels, cx, cy, DIRT[4])
            _put(pixels, cx + 1, cy, DIRT[3])
            cx += 1
            cy += (salt >> step) % 3 - 1
    return pixels


def sand(variant):
    """Sand: wind ripples (a lit crest over a soft shadow) that run on across tiles, faint grain,
    and here and there a shell or a pebble."""
    pixels = _shade_ground(SAND, 300, variant, low=0.28, high=0.72, light=1.4)
    for y in range(SIZE):
        for x in range(SIZE):
            # Shallow ripples running across the tile (period 16 by 32, so they run on across tiles),
            # bent by the shared field so they are not ruled lines.
            bend = _fbm(x, y, 305, ((16, 0.6), (8, 0.4))) * 6.0
            wave = math.sin(2 * math.pi * (2 * y + x + bend) / 16.0)
            patch = _field(x, y, 307, variant, ((8, 0.6), (4, 0.4)))
            if patch < 0.5:
                continue
            if wave > 0.93 and pixels[y][x] == SAND[2]:
                pixels[y][x] = SAND[1]
            elif wave < -0.95 and pixels[y][x] == SAND[2]:
                pixels[y][x] = SAND[3]
    for x, y, salt in _scatter(310, variant, 6, 2):
        if salt % 4 == 0:
            _put(pixels, x, y, SAND[0])
        elif salt % 4 == 1:
            _put(pixels, x, y, SAND[3])
    for x, y, salt in _scatter(330, variant, 16, 4):
        if salt % 2:
            _pebble(pixels, x, y, 2, STONE, SAND[4])
        else:
            for dx, dy, tone in ((0, 0, 0), (1, 0, 1), (0, 1, 1), (1, 1, 2), (2, 1, 3)):
                _put(pixels, x + dx, y + dy, _hex("efe6d6") if tone == 0 else SAND[tone])
    return pixels


def gravel(variant):
    """Grey grit under mountains: packed small stones, each lit top-left and shadowed below."""
    pixels = _shade_ground(GRAVEL, 400, variant)
    for x, y, salt in _scatter(410, variant, 4, 3):
        if salt % 3 == 0:
            continue
        _pebble(pixels, x, y, 2 + (salt % 5 == 0), GRAVEL, GRAVEL[3])
    return pixels


def snow(variant):
    """Snow in the owner's reference look: nearly white, smooth, with long soft wind streaks of pale
    blue-grey drifting across it (one pixel lit above, the shadow under), a few small dark specks,
    and on some variants a tuft of grass poking through."""
    pixels = _canvas(SNOW[0])

    def field(px, py):
        return _field(px, py, 500, variant, ((16, 0.5), (8, 0.35), (4, 0.15)))

    for y in range(SIZE):
        for x in range(SIZE):
            # Wind streaks: thin bands across the tile, bent by the field so they curve and break.
            bend = field(x, y)
            wave = math.sin(2 * math.pi * (y * 2 + x * 0.5 + bend * 9.0) / 16.0)
            if wave > 0.94 and bend > 0.5:
                pixels[y][x] = SNOW[2]
            elif wave > 0.78 and bend > 0.46:
                pixels[y][x] = SNOW[1]
            elif bend < 0.3:
                pixels[y][x] = SNOW[1]
    for x, y, salt in _scatter(510, variant, 8, 3):
        if salt % 5 == 0:
            _put(pixels, x, y, SNOW[3])
            _put(pixels, x + 1, y, SNOW[2])
    if variant in (1, 3):
        for x, y, salt in _scatter(520, variant, 16, 5)[:1 + variant // 3]:
            # A wisp of pale blades fanning up out of the snow, darker at the root.
            for dx, height, lean in ((-2, 3, -1), (-1, 4, 0), (0, 5, 0), (1, 4, 1), (2, 3, 1)):
                for step in range(height):
                    bx = x + dx + (lean * step) // 2
                    _put(pixels, bx, y - step, GRASS[3] if step == 0 else GRASS[1] if step < height - 1 else GRASS[0])
            for dx in range(-2, 3):
                _put(pixels, x + dx, y + 1, SNOW[2])
    return pixels


def bog(variant):
    """Bog mud: dark wet earth with a sheen in the low places, small dark puddles with a lit rim,
    and tufts of marsh grass."""
    pixels = _shade_ground(BOG, 600, variant)
    for x, y, salt in _scatter(610, variant, 10, 5):
        if salt % 2:
            continue
        width, height = 3 + salt % 3, 2
        for dy in range(height):
            for dx in range(width):
                if (dx, dy) in ((0, 0), (width - 1, 0)) and height > 1:
                    continue
                _put(pixels, x + dx, y + dy, BOG_WATER[3] if dy else BOG_WATER[2])
        _put(pixels, x + 1, y, BOG_WATER[0])
        for dx in range(width):
            _put(pixels, x + dx, y + height, BOG[1])
    for x, y, salt in _scatter(630, variant, 8, 3):
        if salt % 3:
            continue
        for blade in (-1, 0, 1):
            _put(pixels, x + blade, y, GRASS[4])
            _put(pixels, x + blade, y - 1, GRASS[3])
            if blade == 0:
                _put(pixels, x, y - 2, GRASS[1])
    for x, y, salt in _scatter(650, variant, 6, 2):
        if salt % 4 == 0:
            _put(pixels, x, y, BOG[0])
    return pixels


def dusk(variant):
    """Dusk soil of the Hollow Reach: grey-violet earth like the dirt's, with pale violet crystal
    chips catching the light."""
    pixels = _shade_ground(DUSK, 700, variant)
    for x, y, salt in _scatter(710, variant, 6, 3):
        if salt % 3 == 0:
            _pebble(pixels, x, y, 2, DUSK, DUSK[4])
        else:
            _put(pixels, x, y, DUSK[3])
            _put(pixels, x + 1, y, DUSK[4])
    for x, y, salt in _scatter(730, variant, 11, 4):
        if salt % 2:
            continue
        _put(pixels, x, y, DUSK_CRYSTAL[0])
        _put(pixels, x + 1, y, DUSK_CRYSTAL[2])
        _put(pixels, x, y + 1, DUSK_CRYSTAL[2])
        _put(pixels, x + 1, y + 1, DUSK_CRYSTAL[4])
    return pixels


def cave(variant):
    """Cave floor: flat grey-brown stone worn smooth, cracks between plates, and patches of
    loose gravel."""
    pixels = _shade_ground(CAVE, 800, variant)
    for x, y, salt in _scatter(810, variant, 16, 5):
        cx, cy = x, y
        for step in range(5 + salt % 4):
            _put(pixels, cx, cy, CAVE[4])
            _put(pixels, cx, cy - 1, CAVE[1])
            cx += 1 if (salt >> step) % 4 else 0
            cy += (salt >> (step + 3)) % 3 - 1
    for x, y, salt in _scatter(830, variant, 6, 3):
        if salt % 4 == 0:
            _pebble(pixels, x, y, 2, GRAVEL, CAVE[4])
        elif salt % 3 == 1:
            _put(pixels, x, y, CAVE[3])
    return pixels


# ---------------------------------------------------------------- built floors

def _setts(variant, seed, ramp, mortar):
    """Rounded setts in staggered courses of 8 px; the joints are the same in every variant, and
    each sett is domed from the top-left with its own tone and a worn face. Returns the pixels and
    a mortar mask."""
    courses = ((0, 9, 20), (4, 15, 25), (1, 12, 22), (6, 17, 27))
    pixels = _canvas(mortar)
    joint = [[True] * SIZE for _ in range(SIZE)]
    for row, starts in enumerate(courses):
        top = row * 8
        for index, start in enumerate(starts):
            end = starts[(index + 1) % 3] + (SIZE if index == 2 else 0)
            length = end - start - 1
            wraps = start + length > SIZE
            salt = _hash(row, index, seed) if wraps else _hash(row, index, seed + 31 * (variant + 1))
            base = (1, 2, 2, 1, 2, 2, 1, 2, 3)[salt % 9]
            height = 7 if salt % 4 else 6
            for dy in range(height):
                for dx in range(length):
                    # Round the corners: two pixels off each, one more where the sett is short.
                    edge_x = min(dx, length - 1 - dx)
                    edge_y = min(dy, height - 1 - dy)
                    if edge_x + edge_y < 1 or (edge_x == 0 and edge_y == 1 and (salt >> 5) % 2):
                        continue
                    x, y = start + dx, top + dy
                    tone = base
                    if dy == 0 or dx == 0:
                        tone = base - 1
                    elif dy == height - 1 or dx == length - 1:
                        tone = base + 1
                    elif dx == 1 and dy == 1:
                        tone = max(0, base - 1)
                    if (salt >> 3) % 12 == 0 and 1 < dy < height - 2 and dx == length // 2 + (dy - 3):
                        tone = 4
                    _put(pixels, x, y, ramp[max(0, min(4, tone))])
                    joint[y % SIZE][x % SIZE] = False
    return pixels, joint


def cobble(variant):
    """Cobblestone street: rounded grey setts in staggered courses with dark mortar, lit from the
    top-left, a crack in some setts."""
    pixels, _ = _setts(variant, 1000, COBBLE, MORTAR)
    return pixels


def snow_cobble(variant):
    """Snowy street on the frost isles: the cobbles with snow packed in the joints and drifted
    over a few stones, the stone tops scuffed clear by boots."""
    pixels, joint = _setts(variant, 1000, COBBLE, SNOW[3])

    def field(px, py):
        return _field(px, py, 1100, variant, ((8, 0.6), (4, 0.4)))

    for y in range(SIZE):
        for x in range(SIZE):
            if joint[y][x]:
                pixels[y][x] = SNOW[1] if not joint[(y - 1) % SIZE][x] else SNOW[2]
                continue
            if field(x, y) > 0.68:
                pixels[y][x] = SNOW[1] if _lit(field, x, y, 2.5) > -0.3 else SNOW[2]
    return pixels


def cellar(variant):
    """Cellar floor: large dark red-brown bricks (16 x 8 px) in running bond with sunken mortar,
    lit faintly from the top-left, worn hollows and a chipped corner on some."""
    pixels = _canvas(BRICK_MORTAR)
    for row in range(4):
        offset = 0 if row % 2 == 0 else 8
        for index in range(2):
            start = offset + index * 16
            wraps = start + 15 > SIZE
            salt = _hash(row, index, 1200) if wraps else _hash(row, index, 1200 + 37 * (variant + 1))
            base = (1, 2, 2, 3)[salt % 4]

            def wear(px, py):
                return _fbm(px, py, 1210 + (0 if wraps else variant * 3 + row * 5 + index), ((8, 0.6), (4, 0.4)))

            for dy in range(7):
                for dx in range(15):
                    tone = base
                    if dy == 0 or dx == 0:
                        tone = base - 1
                    elif dy == 6 or dx == 14:
                        tone = base + 1
                    elif wear(start + dx, row * 8 + dy) < 0.32:
                        tone = base + 1
                    elif _hash(start + dx, row * 8 + dy, 1220) % 29 == 0:
                        tone = base - 1
                    _put(pixels, start + dx, row * 8 + dy, BRICK[max(0, min(4, tone))])
            if salt % 5 == 0:
                for dx, dy in ((13, 1), (14, 1), (14, 2), (13, 0), (14, 0)):
                    _put(pixels, start + dx, row * 8 + dy, BRICK_MORTAR)
    return pixels


def planks(vertical, variant):
    """Boards (8 px wide) running across the tile, with dark seams, grain streaks, butt joints
    with a nail either side, and a knot on some boards. Vertical boards are the horizontal ones turned."""
    pixels = _canvas(PLANK[2])
    for board in range(4):
        top = board * 8
        joint = 6 + (_hash(board, 0, 1300 + variant) % 20)
        salt = _hash(board, 1, 1300 + variant * 7)
        for dy in range(8):
            for x in range(SIZE):
                tone = 2
                if dy == 0:
                    tone = 1
                elif dy == 7:
                    tone = 4
                elif dy == 6:
                    tone = 3
                elif (dy + _hash(board, x // 9, 1350) % 3) % 4 == 1 and (x + dy * 5 + board) % 11 > 2:
                    tone = 3
                if x == joint and 0 < dy < 7:
                    tone = 4
                elif x == joint + 1 and 0 < dy < 7:
                    tone = 1
                _put(pixels, x, top + dy, PLANK[tone])
        for nx, ny in ((joint - 2, top + 3), (joint + 3, top + 4)):
            _put(pixels, nx, ny, NAIL[1])
            _put(pixels, nx + 1, ny + 1, NAIL[3])
        if salt % 3 == 0:
            kx = (joint + 9 + salt % 6) % SIZE
            if 2 < kx < SIZE - 4:
                _put(pixels, kx, top + 3, PLANK[4])
                _put(pixels, kx + 1, top + 3, PLANK[3])
                _put(pixels, kx, top + 4, PLANK[3])
                _put(pixels, kx - 1, top + 2, PLANK[1])
    if vertical:
        pixels = [[pixels[SIZE - 1 - x][y] for x in range(SIZE)] for y in range(SIZE)]
    return pixels


def obsidian(variant):
    """Obsidian flagstones (16 px, four to a tile) with bevelled edges, dark glassy faces, a
    violet sheen streak and fine specks; variant 0 is one great slab with a glowing rune."""
    pixels = _canvas(OBSIDIAN[4])
    slabs = [(0, 0, 32, 32)] if variant == 0 else [(0, 0, 16, 16), (16, 0, 16, 16), (0, 16, 16, 16), (16, 16, 16, 16)]
    for index, (sx, sy, width, height) in enumerate(slabs):
        salt = _hash(index, variant, 1400)
        for dy in range(height - 1):
            for dx in range(width - 1):
                tone = 2
                if dx == 0 or dy == 0:
                    tone = 1
                elif dx == width - 2 or dy == height - 2:
                    tone = 3
                elif (dx + dy + salt % 7) % 13 == 0 and dx < width - 4 and dy < height - 4:
                    tone = 1
                elif _hash(sx + dx, sy + dy, 1410 + variant) % 41 == 0:
                    tone = 0
                _put(pixels, sx + dx, sy + dy, OBSIDIAN[tone])
        # A sheen streak across the face, from the upper left down.
        start = 3 + salt % 5
        for step in range(min(width, height) // 2):
            x, y = sx + start + step, sy + 2 + step // 2
            if x < sx + width - 3 and y < sy + height - 3:
                _put(pixels, x, y, OBSIDIAN[0] if step % 3 else OBSIDIAN[1])
    if variant == 0:
        rune = ["...a...",
                "..aaa..",
                ".a.a.a.",
                "a..a..a",
                "...a...",
                "..a.a..",
                ".a...a."]
        for dy, row in enumerate(rune):
            for dx, mark in enumerate(row):
                if mark == "a":
                    x, y = 12 + dx, 12 + dy
                    _put(pixels, x + 1, y + 1, OBSIDIAN[4])
                    _put(pixels, x, y, RUNE[1])
        _put(pixels, 15, 12, RUNE[0])
    return pixels


def water(frame):
    """Water: an almost even surface (the shader lays its swell and glints over it in world space,
    so nothing repeats from tile to tile), fine darker ripples, and small crests that grow and fade
    over the four frames at sites inside the tile. The surface is the same in every frame, so each
    frame meets every other."""
    pixels = _canvas(WATER[2])
    for y in range(SIZE):
        for x in range(SIZE):
            ripple = _fbm(x, y, 1500, ((4, 0.6), (2, 0.4)))
            if ripple < 0.2:
                pixels[y][x] = WATER[3]
            elif ripple > 0.86:
                pixels[y][x] = WATER[1]
    for x, y, salt in _scatter(1510, 0, 8, 4):
        if min(x, SIZE - 1 - x, y, SIZE - 1 - y) < 4:
            continue
        length = (0, 2, 4, 2)[(frame + salt) % 4]
        for dx in range(length):
            _put(pixels, x + dx - length // 2, y, WATER[0] if 0 < dx < length - 1 or length == 2 else WATER[1])
        if length:
            _put(pixels, x - length // 2 + 1, y + 1, WATER[3])
    return pixels


def cave_earth(variant):
    """The floor of a rock cave (the art direction's caves): warm red-brown earth trodden into
    soft hollows, patches of grey gravel, loose stones lit from the top-left, and a few dark
    cracks."""
    pixels = _shade_ground(CAVE_EARTH, 1900, variant)

    def patch(px, py):
        return _field(px, py, 1910, variant, ((8, 0.6), (4, 0.4)))

    for y in range(SIZE):
        for x in range(SIZE):
            if patch(x, y) > 0.8:
                pixels[y][x] = CAVE_EARTH[3] if (x * 7 + y * 3) % 3 else GRAVEL[3]
    for x, y, salt in _scatter(1920, variant, 6, 3):
        if salt % 3 == 0 and patch(x, y) > 0.6:
            _pebble(pixels, x, y, 2, GRAVEL, CAVE_EARTH[4])
        elif salt % 5 == 0:
            _pebble(pixels, x, y, 2 + (salt % 7 == 0), GRAVEL, CAVE_EARTH[4])
        elif salt % 3 == 1:
            _put(pixels, x, y, CAVE_EARTH[4])
            _put(pixels, x + 1, y, CAVE_EARTH[3])
    for x, y, salt in _scatter(1930, variant, 16, 5):
        cx, cy = x, y
        for step in range(4 + salt % 3):
            _put(pixels, cx, cy, CAVE_EARTH[4])
            cx += 1
            cy += (salt >> step) % 3 - 1
    return pixels


def flags(variant):
    """Castle floor: one large cream sandstone flag per tile (variant 3 split in two), lit on its
    top-left edge, shaded on its lower-right, with a fine dark joint on the tile's right and bottom
    and faint mottling; a chipped corner on variant 2."""
    pixels = _canvas(SANDSTONE[1])
    slabs = [(0, 0, 32, 32)] if variant != 3 else [(0, 0, 32, 16), (0, 16, 32, 16)]
    for index, (sx, sy, width, height) in enumerate(slabs):
        for dy in range(height):
            for dx in range(width):
                x, y = sx + dx, sy + dy
                if dx == width - 1 or dy == height - 1:
                    pixels[y][x] = FLAG_JOINT
                    continue
                tone = 1
                mottle = _fbm(x, y, 1800 + variant * 7 + index, ((8, 0.6), (4, 0.4)))
                if mottle > 0.68:
                    tone = 0
                elif mottle < 0.3:
                    tone = 2
                if dx == 0 or dy == 0:
                    tone = 0
                elif dx == width - 2 or dy == height - 2:
                    tone = 3
                pixels[y][x] = SANDSTONE[tone]
    if variant == 2:
        for dx, dy in ((27, 27), (28, 27), (29, 27), (28, 28), (29, 28), (29, 26)):
            pixels[dy][dx] = SANDSTONE[3]
        pixels[26][28] = SANDSTONE[4]
    if variant == 1:
        for step in range(6):
            _put(pixels, 8 + step, 18 + step // 2, SANDSTONE[3])
    return pixels


def carpet(mask):
    """A red carpet with a faint woven lattice; on each open side (mask: 1 N, 2 E, 4 S, 8 W, the
    sides where the carpet ends) a gold fringe with a dark inner border, so a carpet painted as an
    area reads as one rug with a border all round."""
    pixels = _canvas(CARPET[1])
    for y in range(SIZE):
        for x in range(SIZE):
            if (x + y) % 8 == 0 or (x - y) % 8 == 0:
                pixels[y][x] = CARPET[2]
            if (x + y) % 16 == 4 and (x - y) % 16 == 4:
                pixels[y][x] = CARPET[0]
    sides = {1: lambda x, y: y, 2: lambda x, y: SIZE - 1 - x, 4: lambda x, y: SIZE - 1 - y, 8: lambda x, y: x}
    for y in range(SIZE):
        for x in range(SIZE):
            depth = min((distance(x, y) for bit, distance in sides.items() if mask & bit), default=99)
            if depth == 0:
                pixels[y][x] = FRINGE[0] if (x + y) % 2 else FRINGE[2]
            elif depth == 1:
                pixels[y][x] = FRINGE[1]
            elif depth == 2:
                pixels[y][x] = FRINGE[3]
            elif depth == 3:
                pixels[y][x] = CARPET[4]
    return pixels


# ---------------------------------------------------------------- ways down and up (overlays), kerbs

def _clear():
    return [[None] * SIZE for _ in range(SIZE)]


def _shadow(alpha):
    return (12, 10, 8, alpha)


def _mix(first, second, weight):
    return tuple(round(a * (1 - weight) + b * weight) for a, b in zip(first[:3], second[:3])) + (255,)


def ladder_down():
    """The way down into a town cellar or a crypt: a hatch opening set into whatever floor the
    cell stands on (an overlay, transparent round it), framed in timber lit from the top-left, the
    far wall of the shaft catching a little light, and a ladder going down into the dark."""
    pixels = _clear()
    left, top, right, bottom = 7, 6, 24, 25
    dark = _hex("120f0c")
    # A soft shadow round the frame where it sits in the floor.
    for y in range(top - 1, bottom + 3):
        for x in range(left - 1, right + 3):
            if not (left <= x <= right and top <= y <= bottom):
                pixels[y][x] = _shadow(70 if x > right or y > bottom else 40)
    for y in range(top, bottom + 1):
        for x in range(left, right + 1):
            edge = min(x - left, right - x, y - top, bottom - y)
            if edge < 2:
                tone = 1 if (x - left < 2 or y - top < 2) and not (right - x < 2 or bottom - y < 2) else 3
                if edge == 0:
                    tone = 0 if tone == 1 else 4
                if (x + y) % 9 == 0 and edge == 1:
                    tone = 2
                pixels[y][x] = PLANK[tone]
                continue
            depth = (y - top - 2) / (bottom - top - 3)
            pixels[y][x] = _mix(PLANK[4], dark, min(1.0, 0.45 + depth)) if y < top + 5 else dark
    # The far wall: the top rows of the shaft, dimly lit.
    for x in range(left + 2, right - 1):
        pixels[top + 2][x] = _mix(STONE[3], dark, 0.35)
        pixels[top + 3][x] = _mix(STONE[3], dark, 0.6)
    # The ladder: two rails and rungs fading into the dark as they go down.
    rails = (left + 5, right - 5)
    for y in range(top - 1, bottom - 1):
        fade = max(0.0, min(1.0, (y - top) / (bottom - top)))
        for rail in rails:
            pixels[y][rail] = _mix(PLANK[1], dark, fade * 0.85)
            pixels[y][rail + 1] = _mix(PLANK[3], dark, fade * 0.85)
    for y in range(top + 3, bottom - 1, 4):
        fade = (y - top) / (bottom - top)
        for x in range(rails[0] + 2, rails[1]):
            pixels[y][x] = _mix(PLANK[1], dark, fade * 0.9)
            pixels[y + 1][x] = _mix(PLANK[4], dark, fade * 0.9)
    return pixels


def ladder_up():
    """The way up out of a cellar or a crypt (an overlay): a ladder standing against the hatch
    above, the floor round its foot lit by the daylight falling through."""
    pixels = _clear()
    cx, cy = 15.5, 15.5
    for y in range(SIZE):
        for x in range(SIZE):
            d = ((x - cx) / 12.0) ** 2 + ((y - cy) / 13.0) ** 2
            if d < 1.0:
                pixels[y][x] = (236, 220, 170, round(70 * (1.0 - d)))
    rails = (10, 20)
    for y in range(2, 30):
        for rail in rails:
            pixels[y][rail] = PLANK[1]
            pixels[y][rail + 1] = PLANK[3]
            pixels[y][rail + 2] = _shadow(90)
    for y in range(4, 30, 4):
        for x in range(rails[0] + 2, rails[1]):
            pixels[y][x] = PLANK[0]
            pixels[y + 1][x] = PLANK[3]
            pixels[y + 2][x] = _shadow(80)
    for rail in rails:
        pixels[1][rail] = PLANK[0]
        pixels[1][rail + 1] = PLANK[2]
    return pixels


def rock_steps():
    """The way up out of a cave (an overlay): rough stone steps climbing north toward the light,
    lighter as they rise, their ragged ends dark against the cave floor."""
    pixels = _clear()
    for step in range(6):
        y0 = 4 + step * 4
        light = 1.0 - step / 6
        inset = 3 + (_hash(step, 0, 1700) % 3)
        inset_right = 3 + (_hash(step, 1, 1700) % 3)
        for y in range(y0, y0 + 4):
            for x in range(inset, SIZE - inset_right):
                if y == y0:
                    color = _mix(STONE[3], STONE[0], light)
                elif y == y0 + 3:
                    color = _mix(STONE[4], _hex("1a1814"), 0.4)
                else:
                    color = _mix(STONE[4], STONE[1], light)
                if x == inset or x == SIZE - inset_right - 1:
                    color = _mix(color, _hex("1a1814"), 0.5)
                pixels[y][x] = color
            pixels[y][SIZE - inset_right] = _shadow(90)
    for x in range(4, SIZE - 4):
        pixels[3][x] = (236, 220, 170, 60)
    return pixels


def cave_hole():
    """A hole into a cave (an overlay on whatever ground it opens in): a ragged pit in an apron of
    worn earth that frays into the ground round it, the far wall of earth sliding down into the
    dark, and a broken rim of stones lit from the top-left."""
    pixels = _clear()
    cx, cy = 15.5, 16.0
    for y in range(SIZE):
        for x in range(SIZE):
            d = ((x - cx) / 15.0) ** 2 + ((y - cy) / 12.5) ** 2
            ragged = _unit(x, y, 1600) * 0.18
            if d < 0.8 - ragged:
                pixels[y][x] = DIRT[1] if d > 0.5 else DIRT[2]
                if _unit(x, y, 1601) < 0.08:
                    pixels[y][x] = DIRT[3]
            elif d < 1.0 - ragged and _unit(x, y, 1604) < 0.55:
                pixels[y][x] = DIRT[1][:3] + (150,)
    pit = set()
    for y in range(SIZE):
        for x in range(SIZE):
            ragged = 0.12 * _unit(x // 2, y // 2, 1602)
            if ((x - cx) / 11.0) ** 2 + ((y - cy - 1) / 8.0) ** 2 < 1.0 - ragged:
                pit.add((x, y))
    top = {}
    for x, y in pit:
        top[x] = min(top.get(x, y), y)
    dark = _hex("120f0c")
    for x, y in pit:
        depth = y - top[x]
        pixels[y][x] = _mix(DIRT[4], dark, min(1.0, depth / 6)) if depth < 6 else dark
    for x, y in pit:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + dx, y + dy) not in pit and 0 <= x + dx < SIZE and 0 <= y + dy < SIZE:
                pixels[y + dy][x + dx] = DIRT[4] if dy >= 0 else dark
    for angle in range(200, 520, 36):
        radians = math.radians(angle + _hash(angle, 0, 1603) % 16 - 8)
        x = round(cx + math.cos(radians) * 11.5)
        y = round(cy + 1 + math.sin(radians) * 8.5)
        _pebble(pixels, x - 1, y - 1, 3 if angle % 72 else 2, STONE, dark)
    return pixels


def curb(side):
    """Kerb stones where a cobbled street meets other ground, along one side (0 north, 1 east,
    2 south, 3 west): a row of dressed stones lighter than the setts, lit on top, with a dark
    joint toward the street. Transparent elsewhere."""
    pixels = [[None] * SIZE for _ in range(SIZE)]
    starts = (0, 9, 17, 25)
    for index, start in enumerate(starts):
        end = starts[index + 1] if index + 1 < len(starts) else SIZE
        for x in range(start, end):
            for y in range(4):
                tone = 1
                if y == 0:
                    tone = 0
                elif y == 3:
                    tone = 3
                if x == end - 1:
                    tone = 4 if y > 0 else 3
                pixels[y][x] = COBBLE[tone]
        for x in range(start, end):
            pixels[4][x] = MORTAR
    for _ in range(side):
        pixels = [[pixels[SIZE - 1 - x][y] for x in range(SIZE)] for y in range(SIZE)]
    return pixels


def tile(kind, variant=0):
    """One floor tile by kind: rows of RGBA tuples (None for transparent)."""
    builders = {
        "grass": grass, "dirt": dirt, "sand": sand, "gravel": gravel, "snow": snow, "bog": bog,
        "dusk": dusk, "cave": cave, "cobble": cobble, "snow_cobble": snow_cobble, "cellar": cellar,
        "obsidian": obsidian, "water": water,
    }
    if kind in builders:
        return builders[kind](variant)
    if kind == "cave_earth":
        return cave_earth(variant)
    if kind == "flags":
        return flags(variant)
    if kind == "carpet":
        return carpet(variant)
    if kind == "plank":
        return planks(variant >= 2, variant % 2)
    if kind == "ladder_down":
        return ladder_down()
    if kind == "ladder_up":
        return ladder_up()
    if kind == "rock_steps":
        return rock_steps()
    if kind == "cave_hole":
        return cave_hole()
    if kind == "curb":
        return curb(variant)
    raise KeyError(kind)
