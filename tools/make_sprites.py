#!/usr/bin/env python3
"""Generate Brimholt's original pixel-art sprite sheets (Python standard library only).

Writes assets/sprites/*.png. Character, cloth, marker, and gear sheets use 64x64 frames:
three columns (stand, step A, step B) and four rows (down, up, left, right), with the
tile centre at frame pixel (32, 40). Items and floor tiles are 32x32 cells; walls are
48x48 cells drawn 16 pixels up and left of their tile, indexed by open sides
(1 north, 2 west, 4 south, 8 east). objects.png holds 64x96 trees whose trunk base sits on
the tile centre at (32, 80). terrain_palette.png is the map editor's tile palette.

Re-running overwrites the sheets. Once a sheet has been edited by hand (for example in
Aseprite), treat that PNG as the source of truth and stop regenerating it.
"""

import argparse
import random
import struct
import zlib
from pathlib import Path

FRAME = 64
TILE = 32
WALL = 48
DIRECTIONS = ("down", "up", "left", "right")
ITEM_ORDER = (
    "ember_cap", "moss_coat", "copper_blade", "iron_coif", "ash_tunic", "flint_hatchet", "glowcap",
    "oak_buckler", "copper_band", "garnet_ring", "river_pendant", "hearth_charm", "gold_coins",
    "vole_tail", "toad_slime", "boar_tusk", "bandit_badge", "wolf_pelt", "lurker_eye", "waxed_bowstring", "golem_core", "wraith_ash", "hollow_sigil", "stalker_fang", "reedfang_scale", "bog_heart", "warden_crest",
)
# Monster materials: id -> icon shape.
MATERIAL_SHAPES = {"vole_tail": "tail", "toad_slime": "vial", "boar_tusk": "fang", "bandit_badge": "badge", "wolf_pelt": "pelt", "lurker_eye": "orb", "waxed_bowstring": "coil", "golem_core": "crystal", "wraith_ash": "pile", "hollow_sigil": "badge", "stalker_fang": "fang", "reedfang_scale": "scale", "bog_heart": "orb", "warden_crest": "badge"}
# Map editor palette order; must match TERRAINS in tools/make_map.gd.
TERRAINS = (".", ",", "~", "#", "T", ":", "=", "b")


def rgba(value, alpha=255):
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha)


def scale(color, factor):
    return tuple(max(0, min(255, round(channel * factor))) for channel in color[:3]) + (color[3],)


OUTLINE = rgba("1a1612")
SHADOW = (0, 0, 0, 72)
MARKER = rgba("f2cf6a")

PALETTES = {
    "ember_cap": (rgba("a8673f"), rgba("cf9663"), rgba("e2c38a")),
    "moss_coat": (rgba("5f7f55"), rgba("8ea777"), rgba("3a5241")),
    "copper_blade": (rgba("c9ccc2"), rgba("b98450"), rgba("6e4a2e")),
    "iron_coif": (rgba("767d86"), rgba("a3aab2"), rgba("4d535b")),
    "ash_tunic": (rgba("7d4840"), rgba("a5685d"), rgba("4a2a26")),
    "flint_hatchet": (rgba("9a9c92"), rgba("7c5838"), rgba("4f3725")),
    "glowcap": (rgba("74c4b0"), rgba("dcecc8"), rgba("cbb894")),
    "oak_buckler": (rgba("86603d"), rgba("ad865a"), rgba("8a9097")),
    "copper_band": (rgba("b07444"), rgba("dca46c"), rgba("744526")),
    "garnet_ring": (rgba("c39b46"), rgba("e6cc86"), rgba("962c38")),
    "river_pendant": (rgba("a4adb5"), rgba("dbe2e6"), rgba("3d78a8")),
    "hearth_charm": (rgba("c8b590"), rgba("e8dcbe"), rgba("c85a2c")),
    "gold_coins": (rgba("d6aa3c"), rgba("f2d37a"), rgba("9c7424")),
    "vole_tail": (rgba("8a6a50"), rgba("b08e70"), rgba("5a4232")),
    "toad_slime": (rgba("7fb050"), rgba("c8e8a0"), rgba("d8d4c8")),
    "boar_tusk": (rgba("e6dcc0"), rgba("fff6e0"), rgba("9c8c70")),
    "bandit_badge": (rgba("a0884a"), rgba("d8c080"), rgba("5a4a2a")),
    "wolf_pelt": (rgba("8f959a"), rgba("c0c6ca"), rgba("5d6266")),
    "lurker_eye": (rgba("5aa090"), rgba("e8f4e0"), rgba("1a2a28")),
    "waxed_bowstring": (rgba("c8b078"), rgba("f0e0b0"), rgba("7a6438")),
    "golem_core": (rgba("d09a40"), rgba("f8d890"), rgba("7a5420")),
    "wraith_ash": (rgba("7a6e68"), rgba("b8aca4"), rgba("d0784e")),
    "hollow_sigil": (rgba("4a4e58"), rgba("8a909c"), rgba("c04a3a")),
    "stalker_fang": (rgba("c8d8b0"), rgba("f0f8e0"), rgba("6a8a5a")),
    "reedfang_scale": (rgba("5d7346"), rgba("9ab070"), rgba("34442a")),
    "bog_heart": (rgba("8a2a2a"), rgba("e07060"), rgba("3a1010")),
    "warden_crest": (rgba("2c3b33"), rgba("d8b04a"), rgba("8ac0a0")),
}
LEATHER = rgba("5a4030")

class Image:
    def __init__(self, width, height):
        self.width, self.height = width, height
        self.pixels = [[None] * width for _ in range(height)]

    def get(self, x, y):
        if 0 <= x < self.width and 0 <= y < self.height:
            return self.pixels[y][x]
        return None

    def set(self, x, y, color):
        if color is not None and 0 <= x < self.width and 0 <= y < self.height:
            self.pixels[y][x] = color

    def clear(self, x, y):
        if 0 <= x < self.width and 0 <= y < self.height:
            self.pixels[y][x] = None

    def rect(self, x, y, width, height, color):
        for row in range(y, y + height):
            for column in range(x, x + width):
                self.set(column, row, color)

    def template(self, x, y, rows, palette):
        for dy, row in enumerate(rows):
            for dx, char in enumerate(row):
                if char != ".":
                    self.set(x + dx, y + dy, palette[char])

    def opaque(self, x, y):
        color = self.get(x, y)
        return color is not None and color[3] >= 128

    def over(self, other, ox=0, oy=0):
        for y in range(other.height):
            for x in range(other.width):
                top = other.pixels[y][x]
                if top is None:
                    continue
                below = self.get(ox + x, oy + y)
                if top[3] == 255 or below is None:
                    self.set(ox + x, oy + y, top)
                    continue
                alpha = top[3] / 255.0
                out_alpha = alpha + below[3] / 255.0 * (1.0 - alpha)
                mixed = tuple(round((top[i] * alpha + below[i] * (below[3] / 255.0) * (1.0 - alpha)) / out_alpha)
                              for i in range(3))
                self.set(ox + x, oy + y, mixed + (round(out_alpha * 255),))
        return self

    def outlined(self, color=OUTLINE):
        result = Image(self.width, self.height)
        for y in range(self.height):
            for x in range(self.width):
                if not self.opaque(x, y) and any(self.opaque(x + dx, y + dy)
                                                 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    result.set(x, y, color)
        return result.over(self)

    def mirrored(self):
        result = Image(self.width, self.height)
        for y in range(self.height):
            result.pixels[y] = list(reversed(self.pixels[y]))
        return result

    def rotated(self):
        """Clockwise quarter turn of a square image."""
        result = Image(self.height, self.width)
        for y in range(self.height):
            for x in range(self.width):
                result.set(self.height - 1 - y, x, self.pixels[y][x])
        return result

    def cut(self, mask):
        for y in range(self.height):
            for x in range(self.width):
                if mask.pixels[y][x] is not None:
                    self.pixels[y][x] = None
        return self

    def crop(self, x, y, width, height):
        result = Image(width, height)
        for row in range(height):
            result.pixels[row] = list(self.pixels[y + row][x:x + width])
        return result

    def tinted(self, color):
        result = Image(self.width, self.height)
        for y in range(self.height):
            for x in range(self.width):
                pixel = self.pixels[y][x]
                if pixel is not None:
                    result.pixels[y][x] = tuple(round(pixel[i] * color[i] / 255) for i in range(3)) + (pixel[3],)
        return result

    def scaled(self, factor):
        result = Image(self.width * factor, self.height * factor)
        for y in range(self.height):
            for x in range(self.width):
                result.rect(x * factor, y * factor, factor, factor, self.pixels[y][x])
        return result

    def save(self, path):
        raw = bytearray()
        for row in self.pixels:
            raw.append(0)
            for color in row:
                raw.extend(color if color is not None else (0, 0, 0, 0))

        def chunk(tag, data):
            return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"\x89PNG\r\n\x1a\n"
                         + chunk(b"IHDR", struct.pack(">IIBBBBB", self.width, self.height, 8, 6, 0, 0, 0))
                         + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))


def bevel(image, points, main, light, dark):
    """Fill a pixel set with light top/left edges and dark bottom/right edges."""
    for x, y in points:
        if (x - 1, y) not in points or (x, y - 1) not in points:
            image.set(x, y, light)
        elif (x + 1, y) not in points or (x, y + 1) not in points:
            image.set(x, y, dark)
        else:
            image.set(x, y, main)


def box(x, y, width, height):
    return {(column, row) for row in range(y, y + height) for column in range(x, x + width)}


def ellipse(cx, cy, rx, ry):
    return {(x, y) for y in range(int(cy - ry) - 1, int(cy + ry) + 2) for x in range(int(cx - rx) - 1, int(cx + rx) + 2)
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0}


def line(x0, y0, x1, y1):
    points = set()
    steps = max(abs(x1 - x0), abs(y1 - y0))
    for step in range(steps + 1):
        points.add((round(x0 + (x1 - x0) * step / steps), round(y0 + (y1 - y0) * step / steps)))
    return points


def thick(points, offsets):
    return {(x + dx, y + dy) for x, y in points for dx, dy in offsets}


def sheet(frames, columns, cell):
    rows = (len(frames) + columns - 1) // columns
    result = Image(columns * cell, rows * cell)
    for index, frame in enumerate(frames):
        result.over(frame, (index % columns) * cell, (index // columns) * cell)
    return result


def sheet_row(frames):
    result = Image(sum(frame.width for frame in frames), max(frame.height for frame in frames))
    x = 0
    for frame in frames:
        result.over(frame, x, 0)
        x += frame.width
    return result


def character_sheet(builder):
    frames = []
    for direction in DIRECTIONS:
        for frame in range(3):
            if direction == "right":
                frames.append(builder("left", frame).mirrored())
            else:
                frames.append(builder(direction, frame))
    return sheet(frames, 3, FRAME)


# ---------------------------------------------------------------- characters
# 64x64 frames; the tile centre is frame pixel (32, 40) and feet rest near y 53, so
# characters stand about 1.3 tiles tall and overlap the tile behind them.

def swing(frame):
    return (0, 1, -1)[frame]


def side_arm_x(frame):
    return (30, 33, 27)[frame]


def steps(points, x, y, dx, dy, limit=3):
    count = 0
    while count < limit and (x + dx * (count + 1), y + dy * (count + 1)) in points:
        count += 1
    return count


def shade(image, points, tones, dither=True):
    """Soft top-left lighting with checkerboard dithering at the tone boundaries."""
    light, main, dark = tones
    for x, y in points:
        near_light = min(steps(points, x, y, 0, -1), steps(points, x, y, -1, 0))
        near_dark = min(steps(points, x, y, 0, 1), steps(points, x, y, 1, 0))
        checker = (x + y) % 2 == 0
        if near_light == 0:
            color = light
        elif near_dark == 0:
            color = dark
        elif dither and near_dark == 1:
            color = dark if checker else main
        elif dither and near_light == 1:
            color = light if checker else main
        else:
            color = main
        image.set(x, y, color)


def grey(*values):
    return tuple((value, value, value, 255) for value in values)


SKIN_TONES = (rgba("ebc4a0"), rgba("d9a982"), rgba("b8835f"))
HAIR_TONES = (rgba("6b4a33"), rgba("4b3324"), rgba("33221a"))
LINEN = (rgba("cdbd9c"), rgba("b3a283"), rgba("8c7d63"))
TROUSERS = (rgba("5e554a"), rgba("4d453c"), rgba("38322b"))
TROUSERS_FAR = (rgba("443d35"), rgba("3a342d"), rgba("2c2722"))
BOOT_TONES = (rgba("54402f"), rgba("3a2a1f"), rgba("261b14"))
BELT_TONE, BUCKLE_TONE = rgba("5e432d"), rgba("c9a24a")
# Greyscale cloth is tinted per player at runtime; every value here is unique to cloth.
TABARD = grey(240, 210, 162)
HOOD = grey(198, 172, 130)
CLOAK = grey(178, 146, 106)
CLOAK_FOLD = grey(90)[0]
EMBLEM = grey(252)[0]
TINT_COLORS = set(TABARD) | set(HOOD) | set(CLOAK) | {CLOAK_FOLD, EMBLEM}

HEADS = {
    "down": [
        "..hhhhhh..",
        ".hjjhhhhh.",
        "hjhhhhhhhH",
        "hhhhhhhhhH",
        "hhssssssHH",
        "hsssssssSH",
        "hsesssseSH",
        "hsssssssSH",
        ".sssmmssS.",
        "..sssssS..",
    ],
    "up": [
        "..hhhhhh..",
        ".hjjhhhhh.",
        "hjhhhhhhhH",
        "hjhhhhhhhH",
        "hhhhhhhhHH",
        "hhhhhhhhHH",
        "hhhhhhhhHH",
        "hhhhhhhHHH",
        ".hhhhhhHH.",
        "..SsssSS..",
    ],
    "left": [
        "..hhhhhh..",
        ".hhjjhhhh.",
        "hjjhhhhhhH",
        "hhhhhhhhhH",
        ".ssssshhHH",
        "sssssShhHH",
        "sesssShhHH",
        "ssssSShhHH",
        ".smssShhH.",
        "..sssShH..",
    ],
}
HEAD_PALETTE = {
    "h": HAIR_TONES[1], "H": HAIR_TONES[2], "j": HAIR_TONES[0], "s": SKIN_TONES[1], "S": SKIN_TONES[2],
    "k": SKIN_TONES[0], "e": rgba("1f1a1c"), "m": rgba("9c6048"),
}


def layer(points, tones, dither=True):
    image = Image(FRAME, FRAME)
    shade(image, points, tones, dither)
    return image


def cloak_points(top, bottom, start_half, end_half):
    points = set()
    for y in range(top, bottom + 1):
        half = round(start_half + (end_half - start_half) * (y - top) / (bottom - top))
        points |= box(32 - half, y, half * 2, 1)
    return points - {(32 - start_half, top), (31 + start_half, top)}


def cloak_layer(points, folds):
    image = layer(points, CLOAK)
    for x in folds:
        for y in range(min(p[1] for p in points) + 8, max(p[1] for p in points)):
            if (x, y) in points and y % 2 == 0:
                image.set(x, y, CLOAK_FOLD)
    return image


def leg_points(x, lifted):
    return box(x, 37, 5, 15 if lifted else 17)


def leg_layer(x, lifted, far=False):
    bottom = 51 if lifted else 53
    image = layer(box(x, 37, 5, bottom - 40), TROUSERS_FAR if far else TROUSERS)
    image.over(layer(box(x, bottom - 3, 5, 4), BOOT_TONES))
    return image


def arm_layer(x, top):
    image = layer(box(x, top, 3, 14), LINEN)
    image.rect(x, top + 13, 3, 1, LINEN[2])
    image.over(layer(box(x, top + 14, 3, 3), SKIN_TONES, False))
    return image


TORSO_FRONT = box(24, 23, 16, 4) - {(24, 23), (39, 23)} | box(25, 27, 14, 8) | box(26, 35, 12, 2)
TORSO_SIDE = box(27, 23, 10, 14) - {(27, 23), (36, 23)}
HOOD_FRONT = box(28, 21, 8, 1) | box(26, 22, 12, 1) | box(25, 23, 14, 2) | box(26, 25, 12, 1)
HOOD_SIDE = box(29, 21, 8, 1) | box(28, 22, 10, 3)
TABARD_FRONT = box(28, 25, 8, 16) | box(29, 41, 6, 1) | box(30, 42, 4, 1)
TABARD_SIDE = box(27, 25, 3, 16) | box(27, 41, 2, 1)


def body_layers(direction, frame):
    """Ordered (image, outlined) layers, plus masks that worn armour must not cover."""
    layers = []
    covers = Image(FRAME, FRAME)
    if direction in ("down", "up"):
        left_lift, right_lift = swing(frame) == 1, swing(frame) == -1
        cloak = cloak_layer(cloak_points(23, 44, 9, 14), (22, 26, 37, 41))
        if direction == "down":
            layers.append((cloak, True))
        layers.append((leg_layer(26, left_lift).over(leg_layer(33, right_lift)), True))
        torso = layer(TORSO_FRONT, LINEN)
        torso.over(arm_layer(21, 24 + swing(frame))).over(arm_layer(40, 24 - swing(frame)))
        layers.append((torso, True))
        if direction == "down":
            tabard = layer(TABARD_FRONT, TABARD)
            for x, y in ((31, 29), (32, 29), (30, 30), (33, 30), (30, 31), (33, 31), (31, 32), (32, 32)):
                tabard.set(x, y, EMBLEM)
            layers.append((tabard, True))
            belt = Image(FRAME, FRAME)
            belt.rect(25, 35, 14, 2, BELT_TONE)
            belt.rect(31, 35, 2, 2, BUCKLE_TONE)
            layers.append((belt, False))
        else:
            layers.append((cloak, True))
        hood = layer(HOOD_FRONT, HOOD)
        layers.append((hood, True))
        covers.over(hood.outlined())
        head = Image(FRAME, FRAME)
        head.template(27, 11, HEADS[direction], HEAD_PALETTE)
        layers.append((head, True))
    else:
        near, far = ((28, 31), (25, 34), (34, 25))[frame]
        cloak = set(box(31, 22, 7, 2))
        for y in range(24, 45):
            cloak |= box(33, y, 6 + (y - 24) * 4 // 20, 1)
        cloak = cloak_layer(cloak, (37, 40))
        layers.append((cloak, True))
        layers.append((leg_layer(far, False, True), True))
        layers.append((leg_layer(near, False), True))
        layers.append((layer(TORSO_SIDE, LINEN), True))
        tabard = layer(TABARD_SIDE, TABARD)
        tabard.set(28, 30, EMBLEM)
        tabard.set(28, 31, EMBLEM)
        layers.append((tabard, True))
        belt = Image(FRAME, FRAME)
        belt.rect(27, 35, 10, 2, BELT_TONE)
        belt.rect(27, 35, 2, 2, BUCKLE_TONE)
        layers.append((belt, False))
        hood = layer(HOOD_SIDE, HOOD)
        layers.append((hood, True))
        covers.over(hood.outlined())
        head = Image(FRAME, FRAME)
        head.template(27, 11, HEADS["left"], HEAD_PALETTE)
        layers.append((head, True))
        arm = arm_layer(side_arm_x(frame), 24)
        layers.append((arm, True))
        covers.over(arm.outlined())
    return layers, covers


def body_covers(direction, frame):
    return body_layers(direction, frame)[1]


def full_body(direction, frame):
    image = Image(FRAME, FRAME)
    for x, y in ellipse(32, 53.5, 11, 3):
        image.set(x, y, SHADOW)
    for part, outlined in body_layers(direction, frame)[0]:
        image.over(part.outlined() if outlined else part)
    return image


def split_body(want_tint):
    def build(direction, frame):
        image = full_body(direction, frame)
        for y in range(FRAME):
            for x in range(FRAME):
                if (image.pixels[y][x] in TINT_COLORS) != want_tint:
                    image.clear(x, y)
        return image
    return build


def marker(direction, frame):
    image = Image(FRAME, FRAME)
    for y in range(FRAME):
        for x in range(FRAME):
            distance = ((x + 0.5 - 32) / 14.5) ** 2 + ((y + 0.5 - 53.5) / 5.2) ** 2
            if 0.66 <= distance <= 1.0:
                image.set(x, y, MARKER if y >= 53 else scale(MARKER, 0.78))
    return image


# ---------------------------------------------------------------- equipment

def tones(kind):
    main, light, accent = PALETTES[kind]
    return (light, main, scale(main, 0.7)), accent


def armor_builder(kind):
    palette, accent = tones(kind)
    tunic = kind == "ash_tunic"

    def build(direction, frame):
        covers = body_covers(direction, frame)
        if direction == "up":
            if tunic:
                return layer(box(24, 44, 16, 3), palette).outlined()
            return layer(box(22, 22, 6, 5) | box(36, 22, 6, 5), palette).outlined()
        side = direction == "left"
        if tunic:
            body = box(27, 24, 10, 18) | box(26, 41, 12, 3) if side else box(25, 24, 14, 18) | box(24, 41, 16, 3)
        else:
            body = box(27, 23, 10, 16) | box(28, 39, 8, 4) if side else (box(25, 23, 14, 16) | box(26, 39, 5, 4)
                                                                       | box(33, 39, 5, 4))
        image = layer(body, palette)
        if tunic:
            image.rect(26 if not side else 27, 36, 12 if not side else 10, 1, accent)
        elif not side:
            for y in range(27, 38, 3):
                image.rect(31, y, 2, 1, accent)
        image = image.outlined().cut(covers)
        extra = Image(FRAME, FRAME)
        if side:
            arm_x = side_arm_x(frame)
            if tunic:
                extra = layer(box(arm_x, 24, 3, 4), palette)
            else:
                extra = layer(box(arm_x - 1, 22, 5, 5), palette)
        elif tunic:
            extra = layer(box(21, 24 + swing(frame), 3, 4), palette).over(layer(box(40, 24 - swing(frame), 3, 4), palette))
        else:
            extra = layer(box(21, 22, 6, 5), palette).over(layer(box(37, 22, 6, 5), palette))
        return image.over(extra.outlined())
    return build


CAP = [
    ".....aa.....",
    "...mmmmmm...",
    "..mllmmmmd..",
    ".mlmmmmmmdd.",
    ".mmmmmmmmdd.",
    ".mmmmmmmmdd.",
    "llllllllllll",
    ".dddddddddd.",
]


def helmet_builder(kind):
    palette, accent = tones(kind)
    light, main, dark = palette

    def build(direction, frame):
        image = Image(FRAME, FRAME)
        if kind == "ember_cap":
            image.template(26, 7, CAP, {"m": main, "l": light, "d": dark, "a": accent})
            return image.outlined()
        hood = box(29, 9, 6, 1) | box(27, 10, 10, 1) | box(26, 11, 12, 1) | box(25, 12, 14, 11) | box(26, 23, 12, 2)
        if direction == "down":
            hood -= box(28, 15, 8, 8)
        elif direction == "left":
            hood -= box(25, 15, 7, 8)
        shade(image, hood, palette)
        for x, y in hood:
            if (x + y) % 2 == 0 and y % 2 == 1 and image.get(x, y) == main:
                image.set(x, y, light)
        return image.outlined()
    return build


def held_builder(kind):
    palette, accent = tones(kind)
    light, main, dark = palette
    hatchet = kind == "flint_hatchet"

    def build(direction, frame):
        image = Image(FRAME, FRAME)
        if direction in ("down", "up"):
            top = 24 - swing(frame)
            if hatchet:
                image.rect(41, top - 2, 2, 20, PALETTES[kind][1])
                image.rect(42, top - 2, 1, 20, accent)
                shade(image, box(43, top - 2, 2, 4) | box(45, top - 4, 3, 8) | box(48, top - 3, 1, 6), palette)
            else:
                image.rect(41, top - 5, 1, 18, main)
                image.rect(42, top - 5, 1, 18, dark)
                image.clear(42, top - 5)
                image.rect(38, top + 13, 8, 1, PALETTES[kind][1])
                image.rect(41, top + 14, 2, 3, accent)
                image.rect(41, top + 17, 2, 1, PALETTES[kind][1])
            return image.outlined()
        hand_x = side_arm_x(frame) + 1
        if hatchet:
            for x, y in thick(line(hand_x, 40, hand_x - 12, 25), ((0, 0), (1, 0))):
                image.set(x, y, PALETTES[kind][1])
            shade(image, box(hand_x - 14, 23, 3, 3) | box(hand_x - 17, 20, 3, 8) | box(hand_x - 18, 21, 1, 6), palette)
        else:
            for x, y in line(hand_x - 1, 37, hand_x - 15, 23):
                image.set(x, y, main)
                image.set(x + 1, y, dark)
            for x, y in line(hand_x - 3, 39, hand_x + 1, 35):
                image.set(x, y, PALETTES[kind][1])
            image.set(hand_x, 40, accent)
            image.set(hand_x + 1, 41, accent)
        return image.outlined()
    return build


def shield_face(image, disc, palette, rim, boss):
    shade(image, disc, palette)
    xs = sorted({x for x, y in disc})
    for x in xs[len(xs) // 3::len(xs) // 3][:2]:
        for px, py in disc:
            if px == x:
                image.set(px, py, palette[2])
    for x, y in disc:
        if any((x + dx, y + dy) not in disc for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            image.set(x, y, rim)
    for x, y in boss:
        image.set(x, y, scale(rim, 1.25) if (x + y) % 2 == 0 else rim)


def shield_builder(kind):
    palette, accent = tones(kind)

    def build(direction, frame):
        image = Image(FRAME, FRAME)
        if direction in ("down", "up"):
            top = 25 + swing(frame)
            disc = ellipse(20, top + 7, 6.5, 7.5)
            if direction == "down":
                shield_face(image, disc, palette, accent, box(19, top + 6, 2, 2))
            else:
                shade(image, disc, (palette[1], palette[2], scale(palette[2], 0.8)))
                image.rect(15, top + 6, 10, 2, LEATHER)
            return image.outlined()
        # Held on the far arm, seen edge-on in front of the chest and drawn behind the body.
        edge = box(19, 26, 4, 13) - {(19, 26), (22, 26), (19, 38), (22, 38)}
        shade(image, edge, palette)
        for y in range(27, 38):
            image.set(19, y, accent)
        return image.outlined()
    return build


# ---------------------------------------------------------------- monsters
# Greyscale bodies tinted per monster at runtime, plus untinted eye/detail sheets.
# Same 64x64 frame layout and tile centre (32, 40) as characters; feet near y 53.

MONSTER_TONES = grey(236, 186, 128)
EYE = rgba("fff2b0")
EYE_DARK = rgba("1a1612")


def bob(frame):
    return (0, -1, 1)[frame]


def quadruped(direction, frame):
    body, detail = Image(FRAME, FRAME), Image(FRAME, FRAME)
    for x, y in ellipse(32, 53.5, 13, 3):
        body.set(x, y, SHADOW)
    shape = Image(FRAME, FRAME)
    if direction in ("down", "up"):
        legs = [(25, 45 + (1 if swing(frame) == 1 else 0)), (35, 45 + (1 if swing(frame) == -1 else 0))]
        for x, y in legs:
            shade(shape, box(x, y, 4, 8 - (y - 45)), MONSTER_TONES, False)
        shade(shape, ellipse(32, 40, 10, 8), MONSTER_TONES)
        if direction == "down":
            shade(shape, ellipse(32, 36, 7, 6) | box(25, 29, 3, 4) | box(37, 29, 3, 4), MONSTER_TONES)
            detail.rect(29, 35, 2, 2, EYE_DARK)
            detail.rect(34, 35, 2, 2, EYE_DARK)
            detail.set(29, 35, EYE)
            detail.set(34, 35, EYE)
            detail.rect(31, 40, 3, 1, EYE_DARK)
        else:
            shade(shape, box(31, 30, 3, 6), MONSTER_TONES, False)
    else:
        front, back = ((22, 38), (20, 40), (24, 36))[frame]
        for x in (front, front + 5, back, back - 5):
            shade(shape, box(x, 44, 4, 9), MONSTER_TONES, False)
        shade(shape, ellipse(32, 40, 14, 7), MONSTER_TONES)
        shade(shape, ellipse(20, 35, 7, 6) | box(17, 27, 3, 4) | box(21, 27, 3, 4), MONSTER_TONES)
        shade(shape, box(45, 36, 5, 2), MONSTER_TONES, False)
        detail.rect(17, 34, 2, 2, EYE_DARK)
        detail.set(17, 34, EYE)
        detail.rect(13, 38, 3, 1, EYE_DARK)
    body.over(shape.outlined())
    return body, detail


def blob(direction, frame):
    body, detail = Image(FRAME, FRAME), Image(FRAME, FRAME)
    for x, y in ellipse(32, 53.5, 13, 3):
        body.set(x, y, SHADOW)
    squash = (0, 1, -1)[frame]
    shape = Image(FRAME, FRAME)
    shade(shape, {p for p in ellipse(32, 45 - squash, 13 + squash, 10 - squash) if p[1] <= 53}, MONSTER_TONES)
    for x, y in ((24, 52), (38, 52)):
        shade(shape, box(x, y - 2, 4, 3), MONSTER_TONES, False)
    body.over(shape.outlined())
    if direction != "up":
        eyes = [(27, 39), (34, 39)] if direction == "down" else ([(23, 40)] if direction == "left" else [(39, 40)])
        for x, y in eyes:
            detail.rect(x, y - squash, 3, 3, EYE)
            detail.set(x + 1, y + 1 - squash, EYE_DARK)
        if direction == "down":
            detail.rect(28, 45 - squash, 8, 1, EYE_DARK)
    return body, detail


def golem(direction, frame):
    body, detail = Image(FRAME, FRAME), Image(FRAME, FRAME)
    for x, y in ellipse(32, 53.5, 14, 3.5):
        body.set(x, y, SHADOW)
    shape = Image(FRAME, FRAME)
    side = direction in ("left", "right")
    lift = (0, 1, -1)[frame]
    shade(shape, box(24, 44 - max(lift, 0), 6, 10) | box(34, 44 - max(-lift, 0), 6, 10), MONSTER_TONES, False)
    shade(shape, box(21, 24, 22, 21) - {(21, 24), (42, 24)}, MONSTER_TONES)
    shade(shape, box(26, 13, 12, 11), MONSTER_TONES)
    if not side:
        shade(shape, box(14, 25 + lift, 7, 17), MONSTER_TONES)
        shade(shape, box(43, 25 - lift, 7, 17), MONSTER_TONES)
    else:
        shade(shape, box(28 + lift * 2, 26, 8, 17), MONSTER_TONES)
    rng = random.Random(77)
    for _ in range(18):
        x, y = rng.randrange(22, 42), rng.randrange(25, 44)
        if shape.get(x, y) == MONSTER_TONES[1]:
            shape.set(x, y, MONSTER_TONES[2])
    body.over(shape.outlined())
    if direction == "down":
        detail.rect(28, 17, 3, 2, EYE)
        detail.rect(33, 17, 3, 2, EYE)
    elif direction != "up":
        detail.rect(27 if direction == "left" else 34, 17, 3, 2, EYE)
    return body, detail


def wraith(direction, frame):
    body, detail = Image(FRAME, FRAME), Image(FRAME, FRAME)
    for x, y in ellipse(32, 54, 9, 2.5):
        body.set(x, y, SHADOW)
    rise = bob(frame) - 2
    shape = Image(FRAME, FRAME)
    robe = set()
    for y in range(14, 50):
        half = 6 + (y - 14) * 7 // 36
        robe |= box(32 - half, y + rise, half * 2, 1)
    for x in range(24, 41, 4):
        robe -= box(x + frame % 2, 47 + rise, 2, 3)
    shade(shape, robe, MONSTER_TONES)
    if direction != "up":
        hood = box(27, 15 + rise, 10, 9) if direction == "down" else box(25 if direction == "left" else 29, 15 + rise, 10, 9)
        for x, y in hood:
            shape.set(x, y, (40, 40, 40, 255))
    body.over(shape.outlined())
    if direction == "down":
        detail.rect(29, 19 + rise, 2, 2, EYE)
        detail.rect(33, 19 + rise, 2, 2, EYE)
    elif direction != "up":
        detail.rect(27 if direction == "left" else 35, 19 + rise, 2, 2, EYE)
    return body, detail


def monster_sheet(builder, want_detail):
    def build(direction, frame):
        if direction == "right":
            image = builder("left", frame)[1 if want_detail else 0]
        else:
            image = builder(direction, frame)[1 if want_detail else 0]
        return image
    return character_sheet(build)


# ---------------------------------------------------------------- items

def material_icon(image, shape, palette, accent):
    """Simple original icons for monster materials, shaded with shade()."""
    light, main, dark = palette
    if shape == "tail":
        for index, (x, y) in enumerate(sorted(thick(line(7, 24, 22, 9), ((0, 0), (1, 0), (0, 1))))):
            image.set(x, y, main if index % 5 else light)
        shade(image, box(22, 7, 4, 4), palette, False)
    elif shape == "vial":
        shade(image, box(13, 8, 6, 4), (accent, accent, scale(accent, 0.8)), False)
        shade(image, ellipse(16, 20, 7, 7) | box(14, 11, 4, 4), palette)
        image.rect(12, 18, 3, 2, light)
    elif shape == "fang":
        points = set()
        for y in range(6, 27):
            half = max(1, round(4 - (y - 6) * 3 / 20))
            offset = round((y - 6) ** 2 / 60)
            points |= box(13 + offset - half, y, half * 2, 1)
        shade(image, points, palette)
    elif shape == "badge":
        points = box(9, 7, 14, 10) | {(x, y) for x, y in ellipse(16, 17, 7, 9) if y >= 17}
        shade(image, points, palette)
        shade(image, ellipse(16, 15, 3, 3), (accent, accent, scale(accent, 0.7)), False)
    elif shape == "pelt":
        points = box(7, 9, 18, 14) | box(5, 7, 4, 4) | box(23, 7, 4, 4) | box(5, 21, 4, 4) | box(23, 21, 4, 4)
        shade(image, points, palette)
        for x in range(9, 24, 3):
            image.rect(x, 12, 1, 8, dark)
    elif shape == "orb":
        shade(image, ellipse(16, 16, 9, 9), palette)
        shade(image, ellipse(16, 16, 4, 4), (accent, accent, accent), False)
        image.rect(12, 11, 2, 2, (255, 255, 255, 255))
    elif shape == "coil":
        for radius in (9, 6, 3):
            ring = ellipse(16, 16, radius, radius) - ellipse(16, 16, radius - 1.5, radius - 1.5)
            for x, y in ring:
                image.set(x, y, main if (x + y) % 3 else light)
    elif shape == "crystal":
        points = set()
        for y in range(5, 28):
            half = round(8 * (1 - abs(y - 16) / 11))
            points |= box(16 - half, y, half * 2, 1)
        shade(image, points, palette)
        image.rect(15, 8, 2, 16, light)
    elif shape == "pile":
        shade(image, {p for p in ellipse(16, 24, 11, 8) if p[1] <= 24}, palette)
        for x, y in ((12, 19), (19, 18), (16, 21)):
            image.rect(x, y, 2, 1, accent)
    else:  # scale
        shade(image, {p for p in ellipse(16, 15, 9, 11) if p[1] >= 6}, palette)
        for y in range(9, 24, 4):
            image.rect(11, y, 10, 1, dark)


def item_icon(kind):
    main, light, accent = PALETTES[kind]
    dark = scale(main, 0.7)
    image = Image(TILE, TILE)
    if kind == "ember_cap":
        bevel(image, {p for p in ellipse(16, 16, 9, 8) if p[1] <= 15}, main, light, dark)
        bevel(image, box(5, 16, 22, 3), light, scale(light, 1.1), main)
        bevel(image, box(15, 6, 2, 3), accent, accent, scale(accent, 0.8))
    elif kind == "iron_coif":
        hood = ellipse(16, 15, 9, 10) - ellipse(16, 18, 5, 6)
        hood = {p for p in hood if p[1] <= 24}
        bevel(image, hood, main, light, dark)
        for x, y in hood:
            if (x + y) % 2 == 0 and y % 2 == 1 and image.get(x, y) == main:
                image.set(x, y, light)
    elif kind in ("moss_coat", "ash_tunic"):
        tunic = kind == "ash_tunic"
        body = box(10, 9, 12, 15 if tunic else 16)
        if tunic:
            body |= box(8, 22, 16, 4)
        sleeves = box(6, 9, 4, 6 if tunic else 11) | box(22, 9, 4, 6 if tunic else 11)
        bevel(image, body | sleeves, main, light, dark)
        if tunic:
            image.rect(10, 17, 12, 1, accent)
        else:
            bevel(image, box(5, 7, 7, 3) | box(20, 7, 7, 3), light, light, main)
            image.rect(15, 10, 2, 15, accent)
        for x in range(14, 18):
            for y in range(9, 11):
                image.clear(x, y)
    elif kind == "copper_blade":
        for x, y in line(11, 20, 25, 6):
            image.set(x, y, main)
            image.set(x + 1, y + 1, dark)
            image.set(x + 1, y, main)
        for x, y in line(7, 18, 13, 24):
            image.set(x, y, light)
        for x, y in line(6, 25, 9, 22):
            image.set(x, y, accent)
            image.set(x + 1, y, accent)
        image.set(5, 26, light)
    elif kind == "flint_hatchet":
        for x, y in thick(line(8, 26, 20, 10), ((0, 0), (1, 0))):
            image.set(x, y, light)
        bevel(image, box(17, 5, 8, 8) | box(25, 6, 2, 6), main, scale(main, 1.2), dark)
    elif kind == "oak_buckler":
        shield_face(image, ellipse(16, 16, 11, 11), (light, main, dark), accent, box(15, 15, 3, 3))
    elif kind in ("copper_band", "garnet_ring"):
        gem = kind == "garnet_ring"
        cy = 19 if gem else 17
        band = ellipse(16, cy, 8, 7) - ellipse(16, cy, 5, 4)
        shade(image, band, (light, main, dark), False)
        if gem:
            shade(image, ellipse(16, 11, 4, 4), (scale(accent, 1.6), accent, scale(accent, 0.65)), False)
            image.rect(14, 9, 2, 1, (255, 235, 235, 255))
    elif kind == "river_pendant":
        for chain in (line(6, 5, 15, 17), line(26, 5, 17, 17)):
            for index, (x, y) in enumerate(sorted(chain)):
                image.set(x, y, light if index % 2 else main)
        shade(image, ellipse(16, 22, 4.5, 5.5) | {(16, 16)}, (scale(accent, 1.5), accent, scale(accent, 0.6)), False)
        image.set(15, 20, (230, 245, 255, 255))
    elif kind in MATERIAL_SHAPES:
        material_icon(image, MATERIAL_SHAPES[kind], (light, main, dark), accent)
    elif kind == "gold_coins":
        for cx, cy in ((11, 22), (20, 23), (15, 18), (9, 15), (21, 16), (16, 12)):
            coin = ellipse(cx, cy, 4.5, 3)
            for x, y in coin:
                image.set(x, y, light if y < cy - 1 else main)
            for x, y in coin:
                if (x, y + 1) not in coin:
                    image.set(x, y, dark)
        image.set(14, 10, (255, 248, 210, 255))
    elif kind == "hearth_charm":
        for y in range(3, 10):
            image.set(16, y, LEATHER)
        shade(image, ellipse(16, 18, 8.5, 8.5), (light, main, dark))
        flame = box(15, 13, 2, 9) | box(13, 17, 6, 4) | box(14, 15, 4, 2) | {(16, 12)}
        for x, y in flame:
            image.set(x, y, accent if y < 19 else scale(accent, 1.3))
    else:
        bevel(image, box(13, 15, 6, 10), accent, scale(accent, 1.1), scale(accent, 0.8))
        bevel(image, {p for p in ellipse(16, 15, 10, 8) if p[1] <= 15}, main, light, scale(main, 0.75))
        for x, y in ((12, 10), (19, 9), (16, 12), (22, 13)):
            image.rect(x, y, 2, 2, light)
    return image.outlined()


# ---------------------------------------------------------------- terrain

GRASS = (rgba("4e693b"), rgba("5a7745"), rgba("445d33"), rgba("6d8b4f"), rgba("3d532d"))
DIRT = (rgba("8a7458"), rgba("7d6950"), rgba("a08a6a"), rgba("655440"))
WATER = (rgba("2d5a78"), rgba("3f7394"), rgba("9fd0de"), rgba("234860"), rgba("29546f"))
FLOWERS = (rgba("f1e7c4"), rgba("e8c45a"), rgba("c98fd0"))


def grass_tile(variant):
    rng = random.Random(100 + variant)
    image = Image(TILE, TILE)
    image.rect(0, 0, TILE, TILE, GRASS[0])
    for _ in range(90):
        image.set(rng.randrange(TILE), rng.randrange(TILE), GRASS[rng.choice((1, 2, 2))])
    for _ in range(5):
        x, y = rng.randrange(2, 28), rng.randrange(4, 30)
        image.rect(x, y - 2, 1, 3, GRASS[3])
        image.rect(x + 1, y - 3, 1, 4, GRASS[1])
        image.rect(x + 2, y - 2, 1, 3, GRASS[3])
        image.rect(x, y + 1, 3, 1, GRASS[4])
    if variant == 3:
        for _ in range(3):
            x, y = rng.randrange(3, 28), rng.randrange(3, 28)
            petal = rng.choice(FLOWERS)
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                image.set(x + dx, y + dy, petal)
            image.set(x, y, FLOWERS[1] if petal != FLOWERS[1] else FLOWERS[0])
    return image


def dirt_tile(variant):
    rng = random.Random(200 + variant)
    image = Image(TILE, TILE)
    image.rect(0, 0, TILE, TILE, DIRT[0])
    for _ in range(70):
        image.set(rng.randrange(TILE), rng.randrange(TILE), DIRT[rng.choice((1, 1, 3))])
    for _ in range(6):
        x, y = rng.randrange(1, 29), rng.randrange(1, 29)
        size = rng.choice((2, 2, 3))
        bevel(image, box(x, y, size, size - 1), DIRT[2], scale(DIRT[2], 1.12), DIRT[3])
    return image


def water_tile(frame):
    rng = random.Random(300)
    image = Image(TILE, TILE)
    image.rect(0, 0, TILE, TILE, WATER[0])
    for _ in range(60):
        image.set(rng.randrange(TILE), rng.randrange(TILE), WATER[4])
    for wave in range(6):
        x, y = rng.randrange(TILE), 3 + wave * 5
        x = (x + frame * 8 * (1 if wave % 2 else -1)) % TILE
        for dx in range(6):
            image.set((x + dx) % TILE, y, WATER[1])
        image.set((x + 2) % TILE, y - 1, WATER[2])
        image.set((x + 3) % TILE, y - 1, WATER[2])
    return image


def edge_overlay(kind):
    """North-edge overlay; rotated for the other sides."""
    rng = random.Random(400 if kind == "shore" else 500)
    image = Image(TILE, TILE)
    for x in range(TILE):
        if kind == "shore":
            image.set(x, 0, WATER[2] if rng.random() < 0.85 else WATER[1])
            image.set(x, 1, WATER[3][:3] + (190,))
            image.set(x, 2, WATER[3][:3] + (110,))
            image.set(x, 3, WATER[3][:3] + (50,))
        else:
            depth = rng.choice((1, 2, 2, 3))
            for y in range(depth):
                image.set(x, y, GRASS[0] if y < depth - 1 else GRASS[2])
            image.set(x, depth, DIRT[3][:3] + (150,))
    return image


def edge_set(kind):
    north = edge_overlay(kind)
    east = north.rotated()
    south = east.rotated()
    west = south.rotated()
    return [north, east, south, west]


SAND = (rgba("c8b27a"), rgba("b59e68"), rgba("dcc896"), rgba("9c8656"))
COBBLE = (rgba("85827b"), rgba("9d9a92"), rgba("6b6862"), rgba("4f4c47"))
PLANK = (rgba("8a6a44"), rgba("a1805a"), rgba("6c5034"), rgba("3e2c1e"))
LEAF = (rgba("6a9a4c"), rgba("4a733d"), rgba("2f4a2b"))
PINE = (rgba("4f7d50"), rgba("35593c"), rgba("213a29"))
BARK = (rgba("7a5a3c"), rgba("5c4230"), rgba("3e2c20"))


def sand_tile(variant):
    rng = random.Random(700 + variant)
    image = Image(TILE, TILE)
    image.rect(0, 0, TILE, TILE, SAND[0])
    for _ in range(80):
        image.set(rng.randrange(TILE), rng.randrange(TILE), SAND[rng.choice((1, 1, 2))])
    for _ in range(3):
        x, y = rng.randrange(2, 29), rng.randrange(2, 29)
        image.rect(x, y, 2, 1, SAND[3])
        image.set(x, y - 1, SAND[2])
    return image


def cobble_tile(variant):
    rng = random.Random(800 + variant)
    image = Image(TILE, TILE)
    image.rect(0, 0, TILE, TILE, COBBLE[3])
    for row in range(4):
        shift = 4 if row % 2 else 0
        for column in range(-1, 4):
            x = column * 8 + shift + rng.randrange(0, 2)
            stone = {(px, py) for px, py in box(x + 1, row * 8 + 1, 6, 6) if 0 <= px < TILE}
            tone = rng.choice((1.0, 1.0, 0.92, 1.08))
            bevel(image, stone, scale(COBBLE[0], tone), scale(COBBLE[1], tone), scale(COBBLE[2], tone))
    return image


def plank_tile(vertical, variant):
    rng = random.Random(900 + variant + (10 if vertical else 0))
    image = Image(TILE, TILE)
    image.rect(0, 0, TILE, TILE, PLANK[3])
    for board in range(4):
        tone = rng.choice((1.0, 0.94, 1.06))
        points = box(0, board * 8, TILE, 7)
        bevel(image, points, scale(PLANK[0], tone), scale(PLANK[1], tone), scale(PLANK[2], tone))
        seam = rng.randrange(6, 26)
        for y in range(board * 8, board * 8 + 7):
            image.set(seam, y, PLANK[3])
        for nail in (2, 29):
            image.set(nail, board * 8 + 3, PLANK[3])
        for _ in range(6):
            image.set(rng.randrange(TILE), board * 8 + rng.randrange(1, 6), scale(PLANK[0], 0.85 * tone))
    return image.rotated() if vertical else image


def tree(variant):
    """64x96 cell; the trunk base sits on the tile centre at (32, 80)."""
    rng = random.Random(1000 + variant)
    image = Image(FRAME, 96)
    for x, y in ellipse(32, 82, 15, 4):
        image.set(x, y, SHADOW)
    trunk = Image(FRAME, 96)
    shade(trunk, box(29, 56, 6, 26) | box(27, 79, 10, 3), BARK, False)
    image.over(trunk.outlined())
    crown = Image(FRAME, 96)
    if variant < 2:
        points = set()
        for cx, cy, rx, ry in ((32, 38, 20, 18), (20, 50, 13, 11), (44, 50, 13, 11), (32, 24, 13, 11),
                               (25 + variant * 6, 32, 12, 10)):
            points |= ellipse(cx + rng.randrange(-1, 2), cy, rx, ry)
        shade(crown, points, LEAF)
        for _ in range(40):
            x, y = rng.choice(sorted(points))
            if crown.get(x, y) == LEAF[1]:
                crown.set(x, y, LEAF[0] if y < 40 else LEAF[2])
    else:
        points = set()
        for tier, (top, half) in enumerate(((8, 7), (20, 12), (33, 16), (46, 20))):
            for y in range(top, top + 16):
                width = round(half * (y - top + 3) / 18)
                points |= box(32 - width, y, width * 2, 1)
        shade(crown, points, PINE)
    image.over(crown.outlined())
    return image


def terrain_palette():
    """One 32x32 tile per map terrain, used by the Godot map editor."""
    tree_tile = grass_tile(0)
    for x, y in ellipse(16, 15, 12, 11):
        tree_tile.set(x, y, LEAF[1] if (x + y) % 5 else LEAF[0])
    tree_tile.over(Image(TILE, TILE).outlined())
    for x, y in ellipse(16, 15, 12, 11):
        if any((x + dx, y + dy) not in ellipse(16, 15, 12, 11) for dx, dy in ((1, 0), (0, 1))):
            tree_tile.set(x, y, LEAF[2])
    wall_tile = wall(0).crop(0, 0, TILE, TILE)
    tiles = {".": grass_tile(0), ",": dirt_tile(0), "~": water_tile(0), "#": wall_tile, "T": tree_tile,
             ":": sand_tile(0), "=": cobble_tile(0), "b": plank_tile(False, 0)}
    return sheet([tiles[terrain] for terrain in TERRAINS], len(TERRAINS), TILE)


WALL_TOP = (rgba("7b8087"), rgba("9196a0"), rgba("62676f"), rgba("555a61"))
WALL_SOUTH = (rgba("4e535c"), rgba("393d45"), rgba("5d626b"))
WALL_EAST = (rgba("3c4048"), rgba("2d3037"), rgba("464a53"))
HEIGHT = 16


def wall(mask):
    open_north, open_west, open_south, open_east = (bool(mask & bit) for bit in (1, 2, 4, 8))
    rng = random.Random(600)
    image = Image(WALL, WALL)
    if open_east:
        for y in range(FRAME):
            for x in range(32, 48):
                depth = 48 - (x + 0.5)
                if 16 - depth <= y + 0.5 < 48 - depth:
                    level = y + 0.5 + depth - 16
                    course = int(level // (32 / 6))
                    joint = (depth + (4 if course % 2 else 0)) % 8
                    color = WALL_EAST[0]
                    if level % (32 / 6) < 1.0 or joint < 1.0:
                        color = WALL_EAST[1]
                    elif level % (32 / 6) < 2.0:
                        color = WALL_EAST[2]
                    if level < 1.0 or x == 47:
                        color = OUTLINE
                    image.set(x, y, color)
    if open_south:
        for y in range(32, 48):
            rise = 48 - (y + 0.5)
            for x in range(0, 48):
                if 16 - rise <= x + 0.5 < 48 - rise:
                    course = int(rise // (16 / 3))
                    along = x + 0.5 + rise - 16 + (8 if course % 2 else 0)
                    color = WALL_SOUTH[0]
                    if rise % (16 / 3) < 1.0 or along % 16 < 1.0:
                        color = WALL_SOUTH[1]
                    elif (16 / 3) - rise % (16 / 3) < 1.0:
                        color = WALL_SOUTH[2]
                    if y == 47 or x + 0.5 < 16 - rise + 1.0:
                        color = OUTLINE
                    image.set(x, y, color)
    top = box(0, 0, 32, 32)
    bevel(image, top, WALL_TOP[0], WALL_TOP[0], WALL_TOP[0])
    for row, offset in ((0, 0), (1, 10)):
        for start in range(-offset, 32, 20):
            slab = {(x, y) for x, y in box(start + 1, row * 16 + 1, 19, 15) if 0 <= x < 32}
            bevel(image, slab, WALL_TOP[0], WALL_TOP[1], WALL_TOP[2])
    for _ in range(26):
        image.set(rng.randrange(32), rng.randrange(32), WALL_TOP[rng.choice((1, 2, 3))])
    for x in range(32):
        if open_north:
            image.set(x, 0, OUTLINE)
        if open_south:
            image.set(x, 31, OUTLINE)
    for y in range(32):
        if open_west:
            image.set(0, y, OUTLINE)
        if open_east:
            image.set(31, y, OUTLINE)
    return image


# ---------------------------------------------------------------- output

def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--preview", type=Path, help="also write a 4x preview sheet to this path")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent / "assets" / "sprites"
    outputs = {
        "body.png": character_sheet(split_body(False)),
        "cloth.png": character_sheet(split_body(True)),
        "marker.png": character_sheet(marker),
        "items.png": sheet([item_icon(kind) for kind in ITEM_ORDER], len(ITEM_ORDER), TILE),
        "tiles.png": sheet([grass_tile(v) for v in range(4)] + [dirt_tile(v) for v in range(4)]
                           + [water_tile(f) for f in range(4)] + edge_set("dirt") + edge_set("shore")
                           + [sand_tile(v) for v in range(4)] + [cobble_tile(v) for v in range(4)]
                           + [plank_tile(False, 0), plank_tile(False, 1), plank_tile(True, 0), plank_tile(True, 1)],
                           4, TILE),
        "objects.png": sheet_row([tree(v) for v in range(3)]),
        "terrain_palette.png": terrain_palette(),
        "walls.png": sheet([wall(mask) for mask in range(16)], 16, WALL),
        "gear/ember_cap.png": character_sheet(helmet_builder("ember_cap")),
        "gear/iron_coif.png": character_sheet(helmet_builder("iron_coif")),
        "gear/moss_coat.png": character_sheet(armor_builder("moss_coat")),
        "gear/ash_tunic.png": character_sheet(armor_builder("ash_tunic")),
        "gear/copper_blade.png": character_sheet(held_builder("copper_blade")),
        "gear/flint_hatchet.png": character_sheet(held_builder("flint_hatchet")),
        "gear/oak_buckler.png": character_sheet(shield_builder("oak_buckler")),
        **{f"monsters/{name}.png": monster_sheet(builder, False)
           for name, builder in (("quadruped", quadruped), ("blob", blob), ("golem", golem), ("wraith", wraith))},
        **{f"monsters/{name}_detail.png": monster_sheet(builder, True)
           for name, builder in (("quadruped", quadruped), ("blob", blob), ("golem", golem), ("wraith", wraith))},
    }
    for name, image in outputs.items():
        image.save(root / name)
        print(f"wrote assets/sprites/{name} ({image.width}x{image.height})")
    if args.preview:
        write_preview(outputs, args.preview)


def write_preview(outputs, path):
    """Dressed characters, items, tiles, and walls at 2x for reviewing the sheets."""
    preview = Image(2400, 1100)
    preview.rect(0, 0, preview.width, preview.height, rgba("20262e"))
    loadouts = (("ember_cap", "moss_coat", "copper_blade"), ("iron_coif", "ash_tunic", "flint_hatchet"), ())
    tints = (rgba("b06a48"), rgba("6a88a8"), rgba("8c6a8a"))
    for row, loadout in enumerate(loadouts):
        for index in range(12):
            x, y = (index % 3) * FRAME, (index // 3) * FRAME
            frame = Image(FRAME, FRAME)
            frame.rect(0, 0, FRAME, FRAME, GRASS[0])
            held = [kind for kind in loadout if kind in ("copper_blade", "flint_hatchet")]
            layers = []
            if held and index // 3 == 1:
                layers.append(outputs["gear/%s.png" % held[0]])
            layers += [outputs["marker.png"], outputs["body.png"]]
            for layer in layers:
                frame.over(layer.crop(x, y, FRAME, FRAME))
            frame.over(outputs["cloth.png"].crop(x, y, FRAME, FRAME).tinted(tints[row]))
            for kind in loadout:
                if kind not in held:
                    frame.over(outputs["gear/%s.png" % kind].crop(x, y, FRAME, FRAME))
            if held and index // 3 != 1:
                frame.over(outputs["gear/%s.png" % held[0]].crop(x, y, FRAME, FRAME))
            preview.over(frame.scaled(2), index * 2 * FRAME + (index // 3) * 8, row * 2 * FRAME)
    preview.over(outputs["items.png"].scaled(2), 0, 400)
    preview.over(outputs["tiles.png"].scaled(2), 0, 480)
    preview.over(outputs["walls.png"].scaled(2), 0, 880)
    preview.save(path)
    print(f"wrote preview {path}")

if __name__ == "__main__":
    main()
