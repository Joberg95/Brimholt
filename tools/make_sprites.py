#!/usr/bin/env python3
"""Generate Brimholt's original pixel-art sprite sheets (Python standard library only).

Writes assets/sprites/*.png. Character, shirt, marker, and gear sheets use 48x48 frames:
three columns (stand, step A, step B) and four rows (down, up, left, right), with the
tile centre at frame pixel (24, 24). Items and floor tiles are 32x32 cells; walls are
48x48 cells drawn 16 pixels up and left of their tile, indexed by open sides
(1 north, 2 west, 4 south, 8 east).

Re-running overwrites the sheets. Once a sheet has been edited by hand (for example in
Aseprite), treat that PNG as the source of truth and stop regenerating it.
"""

import argparse
import random
import struct
import zlib
from pathlib import Path

FRAME = 48
TILE = 32
DIRECTIONS = ("down", "up", "left", "right")
ITEM_ORDER = (
    "ember_cap", "moss_coat", "copper_blade", "iron_coif", "ash_tunic", "flint_hatchet", "glowcap",
)


def rgba(value, alpha=255):
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha)


def scale(color, factor):
    return tuple(max(0, min(255, round(channel * factor))) for channel in color[:3]) + (color[3],)


OUTLINE = rgba("1a1612")
SHADOW = (0, 0, 0, 72)
SKIN, SKIN_SHADE, SKIN_LIGHT = rgba("eabf98"), rgba("c9946e"), rgba("f6d6b5")
HAIR, HAIR_DARK, HAIR_LIGHT = rgba("5b3a26"), rgba("3d2517"), rgba("7d5434")
EYE, MOUTH = rgba("1d2230"), rgba("a8664f")
PANTS, PANTS_DARK = rgba("3b4256"), rgba("2a2f3e")
BOOTS, BOOTS_DARK = rgba("4a3426"), rgba("2e2018")
BELT, BUCKLE = rgba("6a4a30"), rgba("d8b04a")
# Shirt pixels are greyscale and tinted per player at runtime.
SHIRT_LIGHT, SHIRT, SHIRT_DARK = (255, 255, 255, 255), (206, 206, 206, 255), (140, 140, 140, 255)
SHIRT_COLORS = {SHIRT_LIGHT, SHIRT, SHIRT_DARK}
MARKER = rgba("f2cf6a")

PALETTES = {
    "ember_cap": (rgba("ce8657"), rgba("edbd78"), rgba("e0d3a4")),
    "moss_coat": (rgba("6b9a68"), rgba("a9c287"), rgba("3a5c49")),
    "copper_blade": (rgba("d5d9cc"), rgba("cd945a"), rgba("8c5a32")),
    "iron_coif": (rgba("7c8590"), rgba("aeb6bf"), rgba("4f5862")),
    "ash_tunic": (rgba("8a4b46"), rgba("b8706a"), rgba("4d2b2a")),
    "flint_hatchet": (rgba("a3a79c"), rgba("8a6040"), rgba("5c3e2a")),
    "glowcap": (rgba("7fd6c2"), rgba("e8f2d0"), rgba("d9c9a3")),
}

HEADS = {
    "down": [
        "...hhhhhh...",
        ".hhjjjhhhhh.",
        "hhjjhhhhhhHH",
        "hhhhhhhhhhHH",
        "hhksssssssHH",
        "hksssssssssH",
        "hsssessessSH",
        "hsssessessSH",
        "hsssssssssSH",
        ".ssssmmsssS.",
        "..sssssssS..",
        "...SSSSSS...",
    ],
    "up": [
        "...hhhhhh...",
        ".hhjjjhhhhh.",
        "hhjjhhhhhhHH",
        "hhjhhhhhhhHH",
        "hhhhhhhhhhHH",
        "hhhhhhhhhhHH",
        "hhhhhhhhhHHH",
        "hhhhhhhhhHHH",
        "hhhhhhhhhHHH",
        ".hhhhhhhHHH.",
        "..SsssssSS..",
        "...SSSSSS...",
    ],
    "left": [
        "...hhhhhh...",
        "..hhjjjhhhh.",
        ".hjjhhhhhhHH",
        ".hhhhhhhhhHH",
        ".kssssshhhHH",
        ".sssssshhhHH",
        ".sesssShhhHH",
        "ssesssShhhHH",
        ".sssssShhhHH",
        ".ssmssShhHH.",
        "..ssssSShH..",
        "...SSSSS....",
    ],
}
HEAD_PALETTE = {
    "h": HAIR, "H": HAIR_DARK, "j": HAIR_LIGHT, "s": SKIN, "S": SKIN_SHADE, "k": SKIN_LIGHT,
    "e": EYE, "m": MOUTH,
}
CAP = [
    "......aa......",
    "....mmmmmm....",
    "...mllmmmmmd..",
    "..mlmmmmmmmdd.",
    "..mmmmmmmmmdd.",
    "..mmmmmmmmmdd.",
    "llllllllllllll",
    ".dddddddddddd.",
]


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

def swing(frame):
    return (0, 1, -1)[frame]


def side_arm_x(frame):
    return (22, 24, 20)[frame]


def draw_leg(image, x, height, pants, pants_dark, boots=BOOTS):
    top = 31
    image.rect(x, top, 4, height - 2, pants)
    image.rect(x + 3, top, 1, height - 2, pants_dark)
    image.rect(x, top + height - 2, 4, 1, boots)
    image.rect(x, top + height - 1, 4, 1, BOOTS_DARK)


def draw_arm(image, x, top, outer_left):
    sleeve = (SHIRT_LIGHT, SHIRT, SHIRT) if outer_left else (SHIRT, SHIRT, SHIRT_DARK)
    skin = (SKIN_LIGHT, SKIN, SKIN) if outer_left else (SKIN, SKIN, SKIN_SHADE)
    for column in range(3):
        image.rect(x + column, top, 1, 4, sleeve[column])
        image.rect(x + column, top + 4, 1, 5, skin[column])


def body_groups(direction, frame):
    """Main silhouette and, in side views, the near arm (outlined separately)."""
    main, arm = Image(FRAME, FRAME), Image(FRAME, FRAME)
    if direction in ("down", "up"):
        draw_leg(main, 19, 6 if swing(frame) == 1 else 7, PANTS, PANTS_DARK)
        draw_leg(main, 25, 6 if swing(frame) == -1 else 7, PANTS, PANTS_DARK)
        main.rect(18, 22, 12, 7, SHIRT)
        main.rect(18, 22, 1, 7, SHIRT_LIGHT)
        main.rect(18, 22, 10, 1, SHIRT_LIGHT)
        main.rect(28, 22, 2, 7, SHIRT_DARK)
        main.rect(18, 29, 12, 2, BELT)
        if direction == "down":
            main.rect(22, 22, 4, 1, SKIN)
            main.rect(23, 23, 2, 1, SKIN_SHADE)
            main.rect(23, 29, 2, 2, BUCKLE)
        draw_arm(main, 14, 23 + swing(frame), True)
        draw_arm(main, 31, 23 - swing(frame), False)
        main.template(18, 10, HEADS[direction], HEAD_PALETTE)
    else:
        near, far = ((20, 24), (18, 26), (26, 18))[frame]
        draw_leg(main, far, 7, PANTS_DARK, PANTS_DARK, BOOTS_DARK)
        draw_leg(main, near, 7, PANTS, PANTS_DARK)
        main.rect(19, 22, 10, 7, SHIRT)
        main.rect(19, 22, 1, 7, SHIRT_LIGHT)
        main.rect(19, 22, 9, 1, SHIRT_LIGHT)
        main.rect(27, 22, 2, 7, SHIRT_DARK)
        main.rect(19, 29, 10, 2, BELT)
        main.rect(19, 29, 2, 2, BUCKLE)
        main.template(18, 10, HEADS["left"], HEAD_PALETTE)
        draw_arm(arm, side_arm_x(frame), 23, True)
    return main, arm


def arm_cover(direction, frame):
    return body_groups(direction, frame)[1].outlined()


def full_body(direction, frame):
    main, arm = body_groups(direction, frame)
    image = Image(FRAME, FRAME)
    for x, y in ellipse(24, 37.5, 9, 2.6):
        image.set(x, y, SHADOW)
    return image.over(main.outlined()).over(arm.outlined())


def split_body(want_shirt):
    def build(direction, frame):
        image = full_body(direction, frame)
        for y in range(FRAME):
            for x in range(FRAME):
                if (image.pixels[y][x] in SHIRT_COLORS) != want_shirt:
                    image.clear(x, y)
        return image
    return build


def marker(direction, frame):
    image = Image(FRAME, FRAME)
    for y in range(FRAME):
        for x in range(FRAME):
            distance = ((x + 0.5 - 24) / 12.5) ** 2 + ((y + 0.5 - 37.5) / 4.6) ** 2
            if 0.62 <= distance <= 1.0:
                image.set(x, y, MARKER if y >= 37 else scale(MARKER, 0.8))
    return image


# ---------------------------------------------------------------- equipment

def armor_builder(kind):
    main, light, accent = PALETTES[kind]
    dark = scale(main, 0.72)
    tunic = kind == "ash_tunic"

    def build(direction, frame):
        image = Image(FRAME, FRAME)
        if direction in ("down", "up"):
            body = box(18, 22, 12, 11 if tunic else 9)
            if tunic:
                body |= box(17, 31, 14, 2)
            bevel(image, body, main, light, dark)
            if direction == "down":
                if tunic:
                    image.rect(18, 28, 12, 1, accent)
                else:
                    image.rect(23, 23, 2, 8, accent)
                    image.set(23, 25, light)
                    image.set(23, 28, light)
            sleeves = Image(FRAME, FRAME)
            if tunic:
                bevel(sleeves, box(14, 23 + swing(frame), 3, 3), main, light, dark)
                bevel(sleeves, box(31, 23 - swing(frame), 3, 3), main, light, dark)
            else:
                bevel(sleeves, box(13, 21, 5, 3), light, light, main)
                bevel(sleeves, box(30, 21, 5, 3), light, light, main)
            return image.outlined().over(sleeves.outlined())
        body = box(19, 22, 10, 11 if tunic else 9)
        if tunic:
            body |= box(18, 31, 12, 2)
        bevel(image, body, main, light, dark)
        if tunic:
            image.rect(19, 28, 10, 1, accent)
        else:
            image.rect(20, 23, 1, 8, accent)
        image = image.outlined().cut(arm_cover(direction, frame))
        shoulder = Image(FRAME, FRAME)
        arm_x = side_arm_x(frame)
        if tunic:
            bevel(shoulder, box(arm_x, 23, 3, 3), main, light, dark)
        else:
            bevel(shoulder, box(arm_x - 1, 21, 5, 3), light, light, main)
        return image.over(shoulder.outlined())
    return build


def helmet_builder(kind):
    main, light, accent = PALETTES[kind]
    dark = scale(main, 0.72)

    def build(direction, frame):
        image = Image(FRAME, FRAME)
        if kind == "ember_cap":
            image.template(17, 6, CAP, {"m": main, "l": light, "d": dark, "a": accent})
            return image.outlined()
        hood = box(20, 8, 8, 1) | box(18, 9, 12, 1) | box(17, 10, 14, 10) | box(17, 20, 3, 2) | box(28, 20, 3, 2)
        if direction == "down":
            hood -= box(20, 14, 8, 8)
        elif direction == "left":
            hood -= box(17, 14, 8, 8)
        for x, y in hood:
            if x >= 29:
                image.set(x, y, dark)
            elif y == min(row for column, row in hood if column == x):
                image.set(x, y, light)
            elif (x + y) % 2 == 0 and y % 2 == 0:
                image.set(x, y, light)
            else:
                image.set(x, y, main)
        return image.outlined()
    return build


def held_builder(kind):
    main, light, accent = PALETTES[kind]
    dark = scale(main, 0.7)
    hatchet = kind == "flint_hatchet"

    def build(direction, frame):
        image = Image(FRAME, FRAME)
        if direction in ("down", "up"):
            top = 23 - swing(frame)
            if hatchet:
                image.rect(32, top - 5, 2, 15, light)
                image.rect(33, top - 5, 1, 15, accent)
                bevel(image, box(34, top - 6, 4, 6), main, scale(main, 1.2), dark)
            else:
                image.rect(32, top - 9, 1, 15, main)
                image.rect(33, top - 9, 1, 15, dark)
                image.clear(33, top - 9)
                image.rect(30, top + 6, 6, 1, light)
                image.rect(32, top + 7, 2, 2, accent)
            return image.outlined()
        hand_x = side_arm_x(frame) + 1
        if hatchet:
            handle = thick(line(hand_x, 30, hand_x - 9, 19), ((0, 0), (1, 0)))
            for x, y in handle:
                image.set(x, y, light)
            bevel(image, box(hand_x - 11, 15, 5, 5) | box(hand_x - 12, 16, 1, 3), main, scale(main, 1.2), dark)
        else:
            blade = line(hand_x - 1, 28, hand_x - 11, 18)
            for x, y in blade:
                image.set(x, y, main)
                image.set(x + 1, y, dark)
            for x, y in line(hand_x - 2, 30, hand_x + 1, 27):
                image.set(x, y, light)
            image.set(hand_x, 30, accent)
            image.set(hand_x + 1, 31, accent)
        return image.outlined()
    return build


# ---------------------------------------------------------------- items

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


WALL_TOP = (rgba("7b8087"), rgba("9196a0"), rgba("62676f"), rgba("555a61"))
WALL_SOUTH = (rgba("4e535c"), rgba("393d45"), rgba("5d626b"))
WALL_EAST = (rgba("3c4048"), rgba("2d3037"), rgba("464a53"))
HEIGHT = 16


def wall(mask):
    open_north, open_west, open_south, open_east = (bool(mask & bit) for bit in (1, 2, 4, 8))
    rng = random.Random(600)
    image = Image(FRAME, FRAME)
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
        "shirt.png": character_sheet(split_body(True)),
        "marker.png": character_sheet(marker),
        "items.png": sheet([item_icon(kind) for kind in ITEM_ORDER], len(ITEM_ORDER), TILE),
        "tiles.png": sheet([grass_tile(v) for v in range(4)] + [dirt_tile(v) for v in range(4)]
                           + [water_tile(f) for f in range(4)] + edge_set("dirt") + edge_set("shore"), 4, TILE),
        "walls.png": sheet([wall(mask) for mask in range(16)], 16, FRAME),
        "gear/ember_cap.png": character_sheet(helmet_builder("ember_cap")),
        "gear/iron_coif.png": character_sheet(helmet_builder("iron_coif")),
        "gear/moss_coat.png": character_sheet(armor_builder("moss_coat")),
        "gear/ash_tunic.png": character_sheet(armor_builder("ash_tunic")),
        "gear/copper_blade.png": character_sheet(held_builder("copper_blade")),
        "gear/flint_hatchet.png": character_sheet(held_builder("flint_hatchet")),
    }
    for name, image in outputs.items():
        image.save(root / name)
        print(f"wrote assets/sprites/{name} ({image.width}x{image.height})")
    if args.preview:
        write_preview(outputs, args.preview)


def write_preview(outputs, path):
    """Dressed characters, items, tiles, and walls at 2x for reviewing the sheets."""
    preview = Image(1536, 900)
    preview.rect(0, 0, preview.width, preview.height, rgba("20262e"))
    loadouts = (("ember_cap", "moss_coat", "copper_blade"), ("iron_coif", "ash_tunic", "flint_hatchet"), ())
    tints = (rgba("c9714c"), rgba("648db0"), rgba("aa79ab"))
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
            frame.over(outputs["shirt.png"].crop(x, y, FRAME, FRAME).tinted(tints[row]))
            for kind in loadout:
                if kind not in held:
                    frame.over(outputs["gear/%s.png" % kind].crop(x, y, FRAME, FRAME))
            if held and index // 3 != 1:
                frame.over(outputs["gear/%s.png" % held[0]].crop(x, y, FRAME, FRAME))
            preview.over(frame.scaled(2), index * 2 * FRAME + (index // 3) * 8, row * 2 * FRAME)
    preview.over(outputs["items.png"].scaled(2), 0, 300)
    preview.over(outputs["tiles.png"].scaled(2), 0, 380)
    preview.over(outputs["walls.png"].scaled(2), 0, 780)
    preview.save(path)
    print(f"wrote preview {path}")

if __name__ == "__main__":
    main()
