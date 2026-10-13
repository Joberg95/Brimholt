#!/usr/bin/env python3
"""Generate Brimholt's original pixel-art sprite sheets (Python standard library only).

Writes assets/sprites/*.png. Character, cloth, marker, and gear sheets use 64x64 frames:
five columns (stand, step A, step B, attack wind-up, strike; monsters only the first three)
and four rows (down, up, left, right), with the
tile centre at frame pixel (32, 40). Items and floor tiles are 32x32 cells; walls are
48x48 cells drawn 16 pixels up and left of their tile, indexed by open sides
(1 north, 2 west, 4 south, 8 east). objects.png holds 64x96 trees whose trunk base sits on
the tile centre at (32, 80). terrain_palette.png is the map editor's tile palette.

Re-running overwrites the sheets. Once a sheet has been edited by hand (for example in
Aseprite), treat that PNG as the source of truth and stop regenerating it.
"""

import argparse
import json
import math
import random
import struct
import zlib
from pathlib import Path

FRAME = 64
TILE = 32
WALL = 48
DIRECTIONS = ("down", "up", "left", "right")
ROOT = Path(__file__).resolve().parents[2]
# The item catalog shared with the game: order sets items.png, colors are main/light/accent.
CATALOG = json.loads((ROOT / "game" / "data" / "items.json").read_text())["items"]
ITEMS = {item["id"]: item for item in CATALOG}
ITEM_ORDER = tuple(ITEMS)
VISIBLE_SLOTS = ("helmet", "cape", "armor", "main_hand", "off_hand")
# Map editor palette order; must match TERRAINS in tools/generators/make_map.gd.
TERRAINS = (".", ",", "~", "#", "T", ":", "=", "b", "d", "o", "O", "D", "c", "C", "v", "^", "K")


def rgba(value, alpha=255):
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha)


def scale(color, factor):
    return tuple(max(0, min(255, round(channel * factor))) for channel in color[:3]) + (color[3],)


def blend(first, second, weight):
    return tuple(round(a * (1 - weight) + b * weight) for a, b in zip(first[:3], second[:3])) + (first[3],)


OUTLINE = rgba("26251f")
SHADOW = (0, 0, 0, 72)
MARKER = rgba("bca878", 200)

def pigment(color):
    """Keep tier hues, but mix in neutral pigment instead of neon-flat colour."""
    grey = round(color[0] * 0.3 + color[1] * 0.5 + color[2] * 0.2)
    return tuple(round(channel * 0.78 + grey * 0.22) for channel in color[:3]) + (color[3],)


PALETTES = {kind: tuple(pigment(rgba(color)) for color in item["colors"]) for kind, item in ITEMS.items()}


def look(kind):
    """Base shape and decorations, e.g. "helm+plume" -> ("helm", {"plume"})."""
    parts = ITEMS[kind]["look"].split("+")
    return parts[0], set(parts[1:])


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


def polygon(vertices):
    """Filled pixel centres, used for tapered blades and forged faces."""
    points = set()
    for y in range(math.floor(min(p[1] for p in vertices)), math.ceil(max(p[1] for p in vertices))):
        for x in range(math.floor(min(p[0] for p in vertices)), math.ceil(max(p[0] for p in vertices))):
            inside = False
            px, py = x + 0.5, y + 0.5
            for a, b in zip(vertices, vertices[1:] + vertices[:1]):
                if (a[1] > py) != (b[1] > py) and px < (b[0] - a[0]) * (py - a[1]) / (b[1] - a[1]) + a[0]:
                    inside = not inside
            if inside:
                points.add((x, y))
    return points


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


def compact_humanoid(image):
    """Bake the same pixel-grid rig into every body/gear layer, with feet kept at y=53.

    No runtime scaling: silhouettes, grips, masks and cape holes all use this mapping;
    halos are generated afterwards. Monsters and the ground marker keep their own anatomy.
    """
    result = Image(FRAME, FRAME)
    for y in range(FRAME):
        source_y = round(53 + (y - 53) / 0.8)
        for x in range(FRAME):
            result.set(x, y, image.get(x, source_y))
    return result


def character_sheet(builder, compact=False, columns=3):
    """Rows: down, up, left, right. Monsters have 3 columns (stand, step A, step B); humanoid
    layers add the attack wind-up and strike (POSE_COLUMNS)."""
    frames = []
    for direction in DIRECTIONS:
        for frame in range(columns):
            if direction == "right":
                image = builder("left", frame).mirrored()
            else:
                image = builder(direction, frame)
            frames.append(compact_humanoid(image) if compact else image)
    return sheet(frames, columns, FRAME)


# ---------------------------------------------------------------- characters
# 64x64 frames; the tile centre is frame pixel (32, 40) and feet rest near y 53, so
# Geometry is authored in a shared rig, then baked to a compact ~36-pixel silhouette.

POSE_COLUMNS = 5
WIND_UP, STRIKE = 3, 4


def swing(frame):
    return (0, 1, -1, 0, 0)[frame]


def side_arm_x(frame):
    return (30, 33, 27, 31, 29)[frame]


# The weapon hand: the screen-right arm facing down or up, the near arm facing left. Walking it
# hangs at the side; attacking it rises (wind-up) and then swings out (strike).
WEAPON_SHOULDER = {"down": (41, 25), "up": (41, 25)}
ATTACK_HANDS = {
    WIND_UP: {"down": (45, 17), "up": (45, 17), "left": (27, 20)},
    STRIKE: {"down": (35, 36), "up": (37, 15), "left": (21, 31)},
}


def weapon_shoulder(direction, frame):
    return WEAPON_SHOULDER.get(direction, (side_arm_x(frame) + 1, 25))


def weapon_hand(direction, frame):
    if frame in ATTACK_HANDS:
        return ATTACK_HANDS[frame][direction]
    if direction in ("down", "up"):
        return (41, 39 - swing(frame))
    return (side_arm_x(frame) + 1, 39)


def reaching_arm(shoulder, hand):
    """An arm from shoulder to hand at any angle: a 3-pixel sleeve to the elbow, a 2-pixel
    forearm, a cuff, and a 3x3 fist centred on the hand."""
    sx, sy = shoulder
    hx, hy = hand
    ex, ey = round(sx + (hx - sx) * 0.55), round(sy + (hy - sy) * 0.55)
    sleeve = thick(line(sx, sy, ex, ey), box(-1, -1, 3, 3))
    fore = thick(line(ex, ey, hx, hy), box(0, 0, 2, 2)) - box(hx - 1, hy - 1, 3, 3)
    image = layer(sleeve | fore, LINEN, False)
    cx, cy = round(hx - (hx - sx) * 0.2), round(hy - (hy - sy) * 0.2)
    image.set(cx, cy, LINEN[2])
    image.over(layer(box(hx - 1, hy - 1, 3, 3), SKIN_TONES, False))
    return image


def steps(points, x, y, dx, dy, limit=3):
    count = 0
    while count < limit and (x + dx * (count + 1), y + dy * (count + 1)) in points:
        count += 1
    return count


def shade(image, points, tones, dither=True):
    """Directional clusters: small lit edges, broad midtones, and a shaded lower-right."""
    light, main, dark = tones
    for x, y in points:
        near_light = min(steps(points, x, y, 0, -1), steps(points, x, y, -1, 0))
        near_dark = min(steps(points, x, y, 0, 1), steps(points, x, y, 1, 0))
        fleck = (x * 7 + y * 11) % 9
        if near_light == 0 and near_dark > 0:
            color = light
        elif near_dark == 0:
            color = dark
        elif dither and near_dark == 1:
            color = dark if fleck < 3 else main
        elif dither and near_light == 1:
            color = light if fleck == 0 else main
        else:
            color = main
        image.set(x, y, color)


def grey(*values):
    return tuple((value, value, value, 255) for value in values)


SKIN_TONES = (rgba("d6b998"), rgba("bb9475"), rgba("896750"))
HAIR_TONES = (rgba("6b4a33"), rgba("4b3324"), rgba("33221a"))
LINEN = (rgba("b7ad96"), rgba("928974"), rgba("6b6454"))
TROUSERS = (rgba("5e554a"), rgba("4d453c"), rgba("38322b"))
TROUSERS_FAR = (rgba("443d35"), rgba("3a342d"), rgba("2c2722"))
BOOT_TONES = (rgba("54402f"), rgba("3a2a1f"), rgba("261b14"))
BELT_TONE, BUCKLE_TONE = rgba("5e432d"), rgba("c9a24a")
# Greyscale cloth is tinted per player at runtime; every value here is unique to cloth.
TABARD = grey(222, 185, 142)
HOOD = grey(191, 158, 116)
CLOAK = grey(169, 137, 98)
CLOAK_FOLD = grey(90)[0]
EMBLEM = grey(252)[0]
CLOTH_COLORS = set(TABARD) | set(HOOD) | {EMBLEM}
CLOAK_COLORS = set(CLOAK) | {CLOAK_FOLD}

HEADS = {
    "down": [
        "..hhhhhh..",
        ".hjjhhhhh.",
        "hjhhhhhhhH",
        "hhhhhhhhhH",
        "hhssssssHH",
        "hsssssssSH",
        "hseskseSH",
        "hsskssSS.",
        ".sssmsSS.",
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
        "seksSShhHH",
        "skssSShhHH",
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


def front_legs(left_lift, right_lift):
    """Front/back view: trousers joined at the hip, split into two legs with a visible gap.
    A lifted leg bends: its boot rises three pixels and tucks one pixel inward."""
    image = layer(box(26, 37, 12, 4), TROUSERS)
    for x, lifted, inward in ((26, left_lift, 1), (34, right_lift, -1)):
        bottom = 50 if lifted else 53
        shift = inward if lifted else 0
        leg = box(x, 40, 4, 6) | box(x + shift, 46, 4, bottom - 49)
        image.over(layer(leg, TROUSERS))
        image.over(layer(box(x + shift - (1 if x < 32 else 0), bottom - 3, 5, 4), BOOT_TONES, False))
    return image


def side_leg(hip_x, stride, far):
    """Side view (facing left): a leg slanting from the hip by `stride` pixels at the foot
    (negative is forward), with a boot whose toe points forward."""
    tones = TROUSERS_FAR if far else TROUSERS
    image = Image(FRAME, FRAME)
    points = set()
    for y in range(37, 50):
        x = hip_x + round(stride * (y - 37) / 16)
        points |= box(x, y, 4, 1)
    shade(image, points, tones, False)
    foot_x = hip_x + stride
    boot = box(foot_x, 50, 4, 3) | box(foot_x - 2, 52, 2, 1)
    shade(image, boot, BOOT_TONES, False)
    return image


def arm_layer(x, top):
    sleeve = box(x, top + 1, 3, 8) | box(x + 1, top + 9, 2, 5)
    image = layer(sleeve, LINEN, False)
    image.rect(x, top + 13, 3, 1, LINEN[2])
    image.over(layer(box(x, top + 14, 3, 3), SKIN_TONES, False))
    return image


TORSO_FRONT = box(24, 23, 16, 4) - {(24, 23), (39, 23)} | box(25, 27, 14, 6) | box(26, 33, 12, 4)
TORSO_SIDE = box(27, 23, 10, 14) - {(27, 23), (36, 23)}
HOOD_FRONT = box(28, 21, 8, 1) | box(26, 22, 12, 1) | box(25, 23, 14, 2) | box(26, 25, 12, 1)
HOOD_SIDE = box(29, 21, 8, 1) | box(28, 22, 10, 3)
TABARD_FRONT = box(28, 25, 8, 16) | box(29, 41, 6, 1) | box(30, 42, 4, 1)
TABARD_SIDE = box(27, 25, 3, 16) | box(27, 41, 2, 1)


def body_layers(direction, frame, with_cloak=False):
    """Ordered (image, outlined) layers, plus masks that worn armour must not cover."""
    layers = []
    covers = Image(FRAME, FRAME)
    if direction in ("down", "up"):
        left_lift, right_lift = swing(frame) == 1, swing(frame) == -1
        cloak = cloak_layer(cloak_points(23, 43, 9, 11), (25, 28, 35, 38))
        if direction == "down" and with_cloak:
            layers.append((cloak, True))
        layers.append((front_legs(left_lift, right_lift), True))
        torso = layer(TORSO_FRONT, LINEN)
        torso.over(arm_layer(21, 24 + swing(frame)))
        attacking = frame in ATTACK_HANDS
        if not attacking:
            torso.over(arm_layer(40, 24 - swing(frame)))
        elif direction == "up":
            torso.over(reaching_arm(weapon_shoulder(direction, frame), weapon_hand(direction, frame)))
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
            if attacking:
                arm = reaching_arm(weapon_shoulder(direction, frame), weapon_hand(direction, frame))
                layers.append((arm, True))
                covers.over(arm.outlined())
        elif with_cloak:
            layers.append((cloak, True))
        hood = layer(HOOD_FRONT, HOOD)
        layers.append((hood, True))
        covers.over(hood.outlined())
        head = Image(FRAME, FRAME)
        head.template(27, 11, HEADS[direction], HEAD_PALETTE)
        layers.append((head, True))
    else:
        # Stand: legs together; steps: the near and far leg scissor forward and back.
        near, far = ((0, 1), (-4, 4), (4, -4), (0, 1), (-3, 2))[frame]
        cloak = set(box(31, 22, 7, 2))
        for y in range(24, 45):
            cloak |= box(33, y, 5 + (y - 24) * 3 // 20, 1)
        cloak = cloak_layer(cloak, (37, 40))
        if with_cloak:
            layers.append((cloak, True))
        layers.append((side_leg(31, far, True), True))
        layers.append((side_leg(30, near, False), True))
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
        if frame in ATTACK_HANDS:
            arm = reaching_arm(weapon_shoulder(direction, frame), weapon_hand(direction, frame))
        else:
            arm = arm_layer(side_arm_x(frame), 24)
        layers.append((arm, True))
        covers.over(arm.outlined())
    return layers, covers


def body_covers(direction, frame):
    return body_layers(direction, frame)[1]


def full_body(direction, frame, with_cloak=False):
    image = Image(FRAME, FRAME)
    for x, y in ellipse(32, 53.5, 11, 3):
        image.set(x, y, SHADOW)
    for part, outlined in body_layers(direction, frame, with_cloak)[0]:
        image.over(part.outlined() if outlined else part)
    return image


def split_body(part):
    """Base body/cloth are cape-free; "cloak" is the visible mask for equippable capes."""
    def keep(color):
        if part == "cloth":
            return color in CLOTH_COLORS
        if part == "cloak":
            return color in CLOAK_COLORS
        return color not in CLOTH_COLORS and color not in CLOAK_COLORS

    def build(direction, frame):
        image = full_body(direction, frame, with_cloak=part == "cloak")
        for y in range(FRAME):
            for x in range(FRAME):
                if not keep(image.pixels[y][x]):
                    image.clear(x, y)
        return image
    return build


def marker(direction, frame):
    image = Image(FRAME, FRAME)
    for y in range(FRAME):
        for x in range(FRAME):
            distance = ((x + 0.5 - 32) / 14.5) ** 2 + ((y + 0.5 - 53.5) / 5.2) ** 2
            if 0.83 <= distance <= 1.0:
                image.set(x, y, MARKER if y >= 53 else scale(MARKER, 0.78))
    return image


# ---------------------------------------------------------------- equipment

def tones(kind):
    main, light, accent = PALETTES[kind]
    shape, _ = look(kind)
    if shape == "book":
        main = blend(main, LEATHER, 0.45)
        light = scale(main, 1.25)
    elif shape == "bow":
        main = blend(WOOD[1], main, 0.24)
        light = scale(main, 1.25)
    return (light, main, scale(main, 0.7)), accent


WOOD = (rgba("8a6440"), rgba("6e4a2e"), rgba("4f3420"))
BONE = (rgba("f0e6cc"), rgba("d8c8a4"), rgba("a8946c"))


def armor_surface(image, points, shape, palette):
    """Small overlapping scales or paired rivets; shared by the icon and worn layers."""
    light, main, dark = palette
    for x, y in sorted(points):
        if shape == "scale":
            column = (x + (y // 3 % 2) * 2) % 4
            if y % 3 == 2 and column in (1, 2):
                image.set(x, y, dark)
            elif y % 3 == 1 and column == 0:
                image.set(x, y, light)
        elif shape == "brigandine" and y % 4 == 0 and x % 4 in (0, 1):
            image.set(x, y, blend(main, rgba("b6afa0"), 0.5))


def armor_builder(kind):
    palette, accent = tones(kind)
    light, main, dark = palette
    shape, _ = look(kind)
    tunic = shape == "tunic"

    def build(direction, frame):
        covers = body_covers(direction, frame)
        pauldron = shape == "plate"
        side = direction == "left"
        if tunic:
            body = box(27, 24, 10, 18) | box(26, 41, 12, 3) if side else box(25, 24, 14, 18) | box(24, 41, 16, 3)
        else:
            body = box(27, 23, 10, 16) | box(28, 39, 8, 4) if side else (box(25, 23, 14, 16) | box(26, 39, 5, 4)
                                                                       | box(33, 39, 5, 4))
        image = layer(body, palette)
        if tunic:
            image.rect(26 if not side else 27, 36, 12 if not side else 10, 1, accent)
        elif shape == "mail":
            for x, y in body:
                if (x + y // 2) % 3 == 0 and y % 2 == 1 and image.get(x, y) == main:
                    image.set(x, y, scale(main, 1.12))
            image.rect(25 if not side else 27, 35, 14 if not side else 10, 1, LEATHER)
        elif shape in ("scale", "brigandine"):
            armor_surface(image, body, shape, palette)
            image.rect(27 if side else 25, 35, 10 if side else 14, 1, LEATHER)
            if shape == "brigandine":
                image.rect(31, 25, 1, 10, dark)
        elif shape == "plate":
            for y in (28, 31, 34):
                for x, row in body:
                    if row == y:
                        image.set(x, y, dark)
            if not side and direction != "up":
                image.rect(31, 25, 2, 2, accent)
            else:
                image.rect(27, 23, 3, 3, accent)
        elif not side and direction != "up":
            for y in range(27, 38, 3):
                image.set(31, y, dark)
        if direction == "up":
            image.rect(31, 27, 1, 8, dark)
        image = image.outlined().cut(covers)
        extra = Image(FRAME, FRAME)
        if side:
            arm_x = side_arm_x(frame)
            if tunic:
                extra = layer(box(arm_x, 24, 3, 4), palette)
            else:
                extra = layer(ellipse(arm_x + 1, 24, 3.5, 3) if pauldron else ellipse(arm_x + 1, 24, 2.5, 2.5), palette)
        elif tunic:
            extra = layer(box(21, 24 + swing(frame), 3, 4), palette).over(layer(box(40, 24 - swing(frame), 3, 4), palette))
        elif pauldron:
            extra = layer(ellipse(23, 24, 3.5, 3), palette).over(layer(ellipse(41, 24, 3.5, 3), palette))
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
    ".llmmmmmddd.",
    "..dddddddd..",
]
DOME = box(29, 8, 6, 1) | box(27, 9, 10, 1) | box(26, 10, 12, 1) | box(25, 11, 14, 6)


def mirror_x(points):
    return {(63 - x, y) for x, y in points}


def helmet_builder(kind):
    palette, accent = tones(kind)
    light, main, dark = palette
    shape, extras = look(kind)

    def build(direction, frame):
        image = Image(FRAME, FRAME)
        side = direction == "left"
        if shape == "cap":
            image.template(26, 7, CAP, {"m": main, "l": light, "d": dark, "a": accent})
            return image.outlined()
        if shape == "coif":
            hood = box(29, 9, 6, 1) | box(27, 10, 10, 1) | box(26, 11, 12, 1) | box(25, 12, 14, 11) | box(26, 23, 12, 2)
            if direction == "down":
                hood -= box(28, 15, 8, 8)
            elif side:
                hood -= box(25, 15, 7, 8)
            shade(image, hood, palette)
            for x, y in hood:
                if (x + y) % 2 == 0 and y % 2 == 1 and image.get(x, y) == main:
                    image.set(x, y, light)
            return image.outlined()
        shell = set(DOME)
        if shape == "greathelm":
            shell |= box(25, 17, 14, 5) | box(26, 22, 12, 2)
        elif shape == "helm":
            if direction == "up":
                shell |= box(26, 17, 12, 4)
            elif side:
                shell |= box(32, 17, 7, 4)
            else:
                shell |= box(25, 17, 3, 4) | box(36, 17, 3, 4)
        shade(image, shell, palette)
        image.rect(26, 14, 12, 1, main)
        if shape == "kettle":
            shade(image, box(22, 15, 20, 2), (light, main, dark), False)
        if shape == "helm" and direction != "up":
            if side:
                image.rect(26, 14, 2, 5, main)
            else:
                image.rect(31, 14, 2, 5, main)
        if shape == "greathelm" and direction != "up":
            if side:
                image.rect(25, 16, 6, 1, OUTLINE)
                image.set(27, 19, OUTLINE)
            else:
                image.rect(27, 16, 10, 1, OUTLINE)
                for x in (29, 31, 33, 35):
                    image.set(x, 19, OUTLINE)
        if "plume" in extras:
            plume = box(33, 2, 2, 6) | box(35, 4, 2, 5) | box(37, 7, 2, 3) if side else box(31, 1, 2, 8)
            shade(image, plume, (scale(accent, 1.1), accent, scale(accent, 0.7)), False)
        if "crest" in extras:
            crest = box(29, 5, 10, 3) if side else box(30, 4, 4, 5)
            shade(image, crest, (scale(accent, 1.25), accent, scale(accent, 0.7)), False)
        if "horns" in extras:
            horn = {(24, 11), (23, 10), (22, 9), (22, 8), (21, 7), (21, 6)}
            horn = thick(horn, ((0, 0), (1, 0)))
            horns = horn | mirror_x(horn) if not side else {(x + 12, y) for x, y in horn}
            shade(image, horns, BONE, False)
        return image.outlined()
    return build


WEAPON_SHAPES = {"sword", "greatsword", "axe", "mace", "hammer", "bow", "crossbow", "wand", "rod"}
WEAPON_GRIP = (32, 42)


def weapon_model(kind):
    """Original weapon construction about a shared grip, reused for icons and worn poses."""
    shape, extras = look(kind)
    palette, accent = tones(kind)
    light, main, dark = palette
    steel = blend(rgba("929fa1"), main, 0.28)
    steel_light = blend(rgba("e1e4d8"), light, 0.25)
    metal = (steel_light, steel, scale(steel, 0.58))
    wood = (WOOD[0], blend(WOOD[1], main, 0.18), WOOD[2])
    brass = (scale(accent, 1.12), accent, scale(accent, 0.55))
    image = Image(FRAME, FRAME)

    def place(points, colors):
        shade(image, {(x + 32, y + 42) for x, y in points}, colors, False)

    def dot(x, y, color):
        image.set(x + 32, y + 42, color)

    def rod(points, colors, width=2):
        place(thick(points, tuple((i, 0) for i in range(width))), colors)

    if shape in ("sword", "greatsword"):
        length = 19 if "short" in extras else (30 if shape == "greatsword" else 24 if ITEMS[kind]["level"] < 10 else 27)
        width = 3 if shape == "greatsword" else 2
        if "estoc" in extras:
            blade = polygon([(0, -29), (1.5, -8), (1.5, -5), (-1.5, -5), (-1.5, -8)])
        elif "curved" in extras:
            blade = polygon([(7, -27), (5, -20), (3, -12), (2, -5), (-1, -5), (0, -15), (3, -23)])
        elif "cleaver" in extras:
            blade = polygon([(-1, -24), (4, -23), (5, -18), (3, -6), (-2, -6), (-2, -21)])
        else:
            blade = polygon([(0, -length), (width, -length + 5), (width, -7),
                             (width - 1, -5), (-width, -5), (-width, -length + 5)])
        place(blade, metal)
        for x, y in sorted(blade):
            if (x - 1, y) not in blade:
                dot(x, y, steel_light)
            elif (x + 1, y) not in blade:
                dot(x, y, metal[2])
            elif x == 0 and "curved" not in extras and "cleaver" not in extras:
                dot(x, y, metal[2] if "fuller" in extras and -length + 6 < y < -8 else steel)
        if not extras.intersection({"curved", "cleaver", "estoc"}):
            dot(0, -length, steel_light)
        guard = polygon([(-6, -5), (-2, -6), (3, -6), (6, -4), (6, -2), (2, -4), (-3, -4), (-6, -3)])
        if "curved" in extras:
            guard |= line(4, -3, 4, 3) | line(4, 3, 1, 5)
        place(guard, brass)
        place(box(-1, -3, 2, 7), (rgba("98816a"), LEATHER, scale(LEATHER, 0.6)))
        for y in (-2, 0, 2):
            dot(0, y, rgba("3c3029"))
        place(ellipse(0, 5, 2, 1.5), metal if "estoc" in extras else brass)
    elif shape == "hammer":
        # A slim haft, a neck/socket and distinct striking face and peen, not a single block.
        rod(line(-1, -16, 0, 6), wood)
        place(box(-1, -1, 2, 5), (rgba("97856a"), LEATHER, WOOD[2]))
        place(box(-1, -15, 3, 5), metal)
        maul = "maul" in extras or kind == "starforged_maul"
        if maul:
            head = polygon([(-7, -20), (-5, -22), (5, -22), (7, -20), (7, -16),
                            (5, -14), (-5, -14), (-7, -16)])
            place(head, metal)
            place(box(-1, -21, 2, 6), brass)
            place(polygon([(-7, -20), (-5, -19), (-5, -15), (-7, -16)]), (steel, metal[2], scale(steel, 0.4)))
        else:
            head = polygon([(-6, -20), (-4, -21), (-2, -20), (-1, -19), (3, -19),
                            (3, -16), (-2, -16), (-4, -15), (-6, -16)])
            place(head, metal)
            place(polygon([(-6, -20), (-4, -19), (-4, -16), (-6, -16)]), (steel_light, steel, metal[2]))
            if "pick" in extras:
                place(polygon([(2, -19), (6, -19), (10, -15), (5, -17), (2, -16)]), metal)
            elif "peen" in extras:
                place(ellipse(4, -17.5, 2.5, 2), metal)
            else:
                place(polygon([(2, -19), (7, -18), (8, -16), (3, -17)]), metal)
            dot(0, -18, metal[2])
        for y in (0, 3):
            dot(0, y, wood[0])
    elif shape == "axe":
        rod(line(-1, -19, 0, 6), wood)
        blade = polygon([(-2, -19), (4, -22), (7, -23), (7, -17), (5, -12), (0, -14), (-2, -14)])
        place(blade, metal)
        rod(line(-1, -19, -1, -14), brass, 1)
    elif shape == "mace":
        rod(line(-1, -16, 0, 6), wood)
        place(ellipse(0, -18, 4, 5), metal)
        for x in (-3, 0, 3):
            rod(line(x, -21, x, -15), (steel_light, steel, metal[2]), 1)
        place(box(-1, -12, 2, 2), brass)
    elif shape == "bow":
        half = 16 if "flat" in extras else 18
        points = set()
        for y in range(-half, half + 1):
            bend = round(6 * (1 - (y / half) ** 2))
            if "recurve" in extras and abs(y) > half - 5:
                bend -= 2
            points.add((bend, y))
        rod(points, wood)
        rod(line(0 if "recurve" not in extras else -2, -half, 0 if "recurve" not in extras else -2, half),
            (LINEN[1], LINEN[1], LINEN[2]), 1)
        place(box(5, -3, 2, 6), (wood[0], LEATHER, wood[2]))
        for y in (-half + 1, half - 1):
            dot(-1 if "recurve" in extras else 1, y, accent)
    elif shape == "crossbow":
        wide = "arbalest" in extras
        place(polygon([(-1, -20), (2, -20), (2, -1), (3, 6), (0, 7), (-2, 3)]), wood)
        span = 11 if wide else 8
        for side in (-1, 1):
            rod(line(side, -14, side * span, -10), metal if wide else wood)
            rod(line(side * span, -10, 0, -6), (LINEN[1], LINEN[1], LINEN[2]), 1)
        rod(line(0, -21, 0, -5), metal, 1)
        place(box(-1, -4, 3, 2), brass)
        if wide:
            rod(line(-4, 1, 4, 1), metal, 1)
            place(box(4, 0, 2, 3), wood)
    elif shape == "wand":
        rod(line(-1, 5, 0, -13), wood)
        place(box(-1, -7, 3, 2), brass)
        if "fork" in extras:
            for side in (-1, 1):
                rod(line(0, -12, side * 4, -19) | line(side * 4, -19, side * 3, -22), metal, 1)
            place(polygon([(0, -22), (2, -19), (0, -16), (-2, -19)]), brass)
        elif "cage" in extras:
            place(ellipse(0, -18, 3, 4), (scale(accent, 1.1), accent, scale(accent, 0.6)))
            for side in (-1, 1):
                rod(line(0, -23, side * 4, -18) | line(side * 4, -18, 0, -12), metal, 1)
            rod(line(-4, -18, 4, -18), metal, 1)
        else:
            place(polygon([(0, -22), (3, -18), (2, -14), (-2, -14), (-3, -18)]), brass)
            dot(-1, -18, scale(accent, 1.3))
    elif shape == "rod":
        rod(line(0, 7, -1, -17), wood)
        if "crook" in extras:
            curve = set()
            for degree in range(-175, 100, 8):
                angle = math.radians(degree)
                curve.add((round(3 + 5 * math.cos(angle)), round(-21 + 5 * math.sin(angle))))
            rod(curve, wood)
            place(box(2, -18, 2, 2), brass)
        elif "root" in extras:
            for a, b in [((-1, -13), (-5, -22)), ((-1, -17), (4, -25)), ((-4, -19), (-7, -19)),
                         ((2, -22), (6, -21))]:
                rod(line(*a, *b), wood)
            place(ellipse(0, -20, 2, 3), brass)
        else:
            rod(line(-1, -16, -3, -20) | line(-3, -20, -1, -25) | line(1, -25, 3, -20), wood)
            place(ellipse(0, -22, 2.5, 3), brass)
        place(box(-1, -8, 2, 2), brass)
    else:
        raise ValueError(f"Unsupported weapon shape: {shape}")
    return image


def pose_weapon(model, size, grip, angle, scale_factor=1.0):
    """Inverse nearest-neighbour rasterization keeps rotated metal faces solid."""
    image = Image(size, size)
    cosine, sine = math.cos(angle), math.sin(angle)
    for y in range(size):
        for x in range(size):
            dx, dy = (x - grip[0]) / scale_factor, (y - grip[1]) / scale_factor
            u = round(dx * cosine + dy * sine + WEAPON_GRIP[0])
            v = round(-dx * sine + dy * cosine + WEAPON_GRIP[1])
            image.set(x, y, model.get(u, v))
    return image.outlined(rgba("302d27"))


def weapon_icon(kind):
    shape, extras = look(kind)
    grip = (11, 23)
    size = 0.88
    if shape == "bow":
        grip, size = (14, 15), 0.87
    elif shape == "crossbow":
        grip, size = (12, 22), 0.9
    elif shape == "greatsword":
        grip, size = (9, 25), 0.86
    elif shape == "rod":
        grip, size = (10, 23), 0.85
    elif "curved" in extras:
        grip, size = (8, 24), 0.83
    return pose_weapon(weapon_model(kind), TILE, grip, math.pi / 4, size)


# Weapon angle in degrees, clockwise from blade-up, by grip style, direction ("side" is facing
# left), and pose column (stand, step A, step B, wind-up, strike). Melee weapons rest tilted
# forward, are raised back, then cut down across the body; staves are raised and thrust;
# bows are carried tilted and pushed out upright to shoot; crossbows are raised and aimed level.
WEAPON_ANGLES = {
    "melee": {"down": (12, 8, 16, 40, -135), "up": (12, 8, 16, 40, -20), "side": (-25, -35, -15, 45, -100)},
    "staff": {"down": (6, 4, 8, 15, -25), "up": (6, 4, 8, 15, -15), "side": (-12, -18, -6, 10, -55)},
    "bow": {"down": (0, 0, 0, 0, 0), "up": (0, 0, 0, 0, 0), "side": (-18, -24, -12, 0, 0)},
    "crossbow": {"down": (0, 0, 0, 0, 0), "up": (0, 0, 0, 0, 0), "side": (-20, -26, -14, -60, -90)},
}
GRIP_STYLE = {"wand": "staff", "rod": "staff", "bow": "bow", "crossbow": "crossbow"}


def held_builder(kind):
    model = weapon_model(kind)
    shape, _ = look(kind)
    style = GRIP_STYLE.get(shape, "melee")

    def build(direction, frame):
        angle = WEAPON_ANGLES[style]["side" if direction == "left" else direction][frame]
        size = 0.85 if style == "bow" else 1.0
        return pose_weapon(model, FRAME, weapon_hand(direction, frame), math.radians(angle), size)
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
            image.set(x, y, scale(rim, 0.8))
    for x, y in boss:
        image.set(x, y, scale(rim, 1.25) if (x + y) % 2 == 0 else rim)


def heater_points(x, y, width, height):
    points = box(x, y, width, height - width // 2)
    for row in range(width // 2):
        points |= box(x + row, y + height - width // 2 + row, width - row * 2, 1)
    return points


def plate_face(image, points, palette, rim, emblem):
    shade(image, points, palette)
    for x, y in points:
        if any((x + dx, y + dy) not in points for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            image.set(x, y, rim)
    for x, y in emblem:
        image.set(x, y, rim)


def torch_flame(image, cx, base, height, sway):
    outer, mid, inner = rgba("d0581c"), rgba("f09a2a"), rgba("fff0a0")
    for y in range(height):
        half = max(0, round(2.4 * (1 - y / height) + 0.4))
        shift = round(sway * y / height)
        for x in range(cx - half + shift, cx + half + shift):
            image.set(x, base - y, mid if half > 1 and cx - half + shift < x < cx + half - 1 + shift else outer)
        if y < height // 2 and half > 1:
            image.set(cx + shift - 1 + (y % 2), base - y, inner)


def held_torch(direction, frame):
    """A burning torch held up in the off hand; the flame sways with the walk."""
    image = Image(FRAME, FRAME)
    if direction in ("down", "up"):
        x, top = 18, 24 + swing(frame)
    else:
        x, top = 20, 23 + swing(frame)
    image.rect(x, top + 4, 2, 10, WOOD[1])
    image.rect(x, top + 4, 1, 10, WOOD[0])
    image.rect(x - 1, top + 3, 4, 2, rgba("3a2a1c"))
    image = image.outlined()
    torch_flame(image, x + 1, top + 2, 7 + (frame % 2), (0, -1, 1, 1, -1)[frame])
    return image


def shield_builder(kind):
    """Off-hand items: buckler, heater, tower (shields), book (spellbooks) and torch."""
    palette, accent = tones(kind)
    light, main, dark = palette
    shape, _ = look(kind)

    def build(direction, frame):
        if shape == "torch":
            return held_torch(direction, frame)
        image = Image(FRAME, FRAME)
        if direction in ("down", "up"):
            top = 25 + swing(frame)
            if shape == "book":
                cover = box(15, top + 6, 8, 10)
                shade(image, cover, palette, False)
                if direction == "down":
                    image.rect(22, top + 7, 1, 8, rgba("efe6cf"))
                    image.rect(17, top + 9, 3, 3, accent)
                else:
                    image.rect(15, top + 6, 2, 10, dark)
                return image.outlined()
            if shape == "buckler":
                disc = ellipse(20, top + 7, 6.5, 7.5)
            elif shape == "heater":
                disc = heater_points(14, top, 13, 16)
            else:
                disc = box(13, top - 3, 14, 20)
            if direction == "down":
                if shape == "buckler":
                    shield_face(image, disc, palette, accent, box(19, top + 6, 2, 2))
                else:
                    plate_face(image, disc, palette, accent, box(19, top + 2, 3, 6) | box(17, top + 4, 7, 2))
            else:
                shade(image, disc, (palette[1], palette[2], scale(palette[2], 0.8)))
                image.rect(15, top + 6, 10, 2, LEATHER)
            return image.outlined()
        # Held on the far arm, seen edge-on in front of the chest and drawn behind the body.
        if shape == "book":
            edge = box(19, 30, 3, 9)
            shade(image, edge, palette, False)
            image.rect(19, 31, 1, 7, rgba("efe6cf"))
            return image.outlined()
        height = {"buckler": 13, "heater": 16, "tower": 21}[shape]
        top = 26 - (height - 13) // 2
        edge = box(19, top, 4, height) - {(19, top), (22, top), (19, top + height - 1), (22, top + height - 1)}
        shade(image, edge, palette)
        for y in range(top + 1, top + height - 1):
            image.set(19, y, accent)
        return image.outlined()
    return build


def cape_builder(kind):
    """A worn cape: exactly the visible cloak pixels, recoloured, with a hem and clasp."""
    palette, accent = tones(kind)
    light, main, dark = palette
    tone = {CLOAK[0]: light, CLOAK[1]: main, CLOAK[2]: dark, CLOAK_FOLD: scale(dark, 0.8)}

    def build(direction, frame):
        cloak = split_body("cloak")(direction, frame)
        image = Image(FRAME, FRAME)
        lowest = {}
        for y in range(FRAME):
            for x in range(FRAME):
                color = cloak.pixels[y][x]
                if color is not None:
                    image.set(x, y, tone[color])
                    lowest[x] = y
        for x, y in lowest.items():
            image.set(x, y, accent)
        if direction == "up":
            for x, y in ((32, 28), (31, 29), (32, 29), (33, 29), (32, 30)):
                if image.get(x, y) is not None:
                    image.set(x, y, accent)
        return image
    return build


# Halo alpha by distance from the sprite: inside (0) brightens the item, then a soft falloff.
HALO_ALPHA = {0: 18, 1: 96, 2: 58, 3: 28, 4: 10}


def halo(image):
    """White glow mask around and over a sprite, drawn additively in the relic's colour."""
    distance = {}
    frontier = []
    for y in range(image.height):
        for x in range(image.width):
            if image.opaque(x, y):
                distance[(x, y)] = 0
                frontier.append((x, y))
    reach = max(HALO_ALPHA)
    while frontier:
        following = []
        for x, y in frontier:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                point = (x + dx, y + dy)
                if point not in distance and 0 <= point[0] < image.width and 0 <= point[1] < image.height \
                        and distance[(x, y)] < reach:
                    distance[point] = distance[(x, y)] + 1
                    following.append(point)
        frontier = following
    result = Image(image.width, image.height)
    for (x, y), steps_away in distance.items():
        result.set(x, y, (255, 255, 255, HALO_ALPHA[steps_away]))
    return result


def framewise(sheet_image, cell_width, cell_height, transform):
    """Apply transform to each cell so halos never bleed into the neighbouring frame."""
    result = Image(sheet_image.width, sheet_image.height)
    for y in range(0, sheet_image.height, cell_height):
        for x in range(0, sheet_image.width, cell_width):
            result.over(transform(sheet_image.crop(x, y, cell_width, cell_height)), x, y)
    return result


GEAR_BUILDERS = {"helmet": helmet_builder, "armor": armor_builder, "main_hand": held_builder,
                 "off_hand": shield_builder, "cape": cape_builder}


# ---------------------------------------------------------------- monsters
# Greyscale bodies tinted per monster at runtime, plus untinted eye/detail sheets.
# Same 64x64 frame layout and tile centre (32, 40) as characters; feet near y 53.

MONSTER_TONES = grey(236, 186, 128)
EYE = rgba("d2bf87")
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
            shade(shape, box(x, y, 3, 8 - (y - 45)), MONSTER_TONES, False)
        shade(shape, ellipse(32, 40, 9, 9), MONSTER_TONES)
        if direction == "down":
            shade(shape, ellipse(32, 35, 6, 6) | ellipse(26, 29, 2, 3) | ellipse(37, 29, 2, 3), MONSTER_TONES)
            shade(shape, ellipse(32, 40, 3.5, 4), grey(208, 164, 116), False)
            detail.set(28, 35, EYE_DARK)
            detail.set(35, 35, EYE_DARK)
            detail.rect(31, 42, 2, 1, EYE_DARK)
        else:
            shade(shape, box(31, 30, 3, 6), MONSTER_TONES, False)
    else:
        front, back = ((22, 38), (20, 40), (24, 36))[frame]
        for x in (front, front + 5, back, back - 5):
            leg = thick(line(x + 1, 44, x, 51), ((0, 0), (1, 0)))
            shade(shape, leg | box(x - 1, 52, 4, 1), MONSTER_TONES, False)
        shade(shape, ellipse(32, 40, 14, 7), MONSTER_TONES)
        shade(shape, ellipse(20, 35, 6, 5) | ellipse(13, 38, 5, 2.5) | ellipse(20, 28, 2, 3), MONSTER_TONES)
        shade(shape, thick(line(44, 37, 52, 42), ((0, 0), (0, 1))), MONSTER_TONES, False)
        detail.set(17, 34, EYE_DARK)
        detail.rect(8, 38, 2, 1, EYE_DARK)
    for x, y in sorted(ellipse(32, 39, 8, 5)):
        if (x * 11 + y * 7) % 13 == 0 and shape.get(x, y) == MONSTER_TONES[1]:
            shape.set(x, y, (162, 162, 162, 255))
    body.over(shape.outlined())
    return body, detail


def spider(direction, frame):
    """Eight jointed legs around a small head and a bulbous, banded abdomen; a cluster of red eyes."""
    body, detail = Image(FRAME, FRAME), Image(FRAME, FRAME)
    for x, y in ellipse(32, 53, 15, 3):
        body.set(x, y, SHADOW)
    shape = Image(FRAME, FRAME)
    lift = swing(frame)
    legs = set()
    if direction in ("down", "up"):
        for side in (-1, 1):
            for index in range(4):
                up = lift if (index + (side > 0)) % 2 else -lift
                foot_y = 37 + index * 5 + up
                hip = (32 + side * 5, 37 + index * 2)
                knee = (32 + side * (11 + (2, 4, 4, 2)[index]), foot_y - 10)
                foot = (32 + side * (16 + (2, 5, 5, 2)[index]), foot_y)
                legs |= line(*hip, *knee) | line(*knee, *foot)
        shade(shape, thick(legs, ((0, 0), (1, 0))), MONSTER_TONES, False)
        abdomen_y, head_y = (34, 44) if direction == "down" else (45, 35)
        shade(shape, ellipse(32, abdomen_y, 10, 9), MONSTER_TONES)
        shade(shape, ellipse(32, head_y, 6, 5), MONSTER_TONES)
        for x, y in ellipse(32, abdomen_y, 10, 9):
            if (y - abdomen_y) in (-3, 2) and abs(x - 32) < 7:
                shape.set(x, y, (120, 120, 120, 255))
        if direction == "down":
            for x, y in ((29, 43), (34, 43), (30, 41), (33, 41)):
                detail.set(x, y, rgba("e0303a"))
            detail.rect(29, 48, 1, 2, EYE_DARK)
            detail.rect(34, 48, 1, 2, EYE_DARK)
    else:
        for index in range(4):
            up = lift if index % 2 else -lift
            for far in (2, 0):
                hip = (25 + index * 3 + far, 40 - far)
                knee = (17 + index * 8 + far, 27 + up - far)
                foot = (11 + index * 12 + far, 52 - far + (up if far else -up) // 2)
                legs |= line(*hip, *knee) | line(*knee, *foot)
        shade(shape, thick(legs, ((0, 0), (0, 1))), MONSTER_TONES, False)
        shade(shape, ellipse(41, 38, 11, 8), MONSTER_TONES)
        shade(shape, ellipse(23, 42, 6, 5), MONSTER_TONES)
        for x, y in ellipse(41, 38, 11, 8):
            if x in (38, 44) and abs(y - 38) < 6:
                shape.set(x, y, (120, 120, 120, 255))
        for x, y in ((19, 40), (21, 39), (20, 42)):
            detail.set(x, y, rgba("e0303a"))
        detail.rect(17, 45, 2, 1, EYE_DARK)
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
            detail.rect(x, y - squash, 2, 1, EYE_DARK)
            detail.set(x, y - squash, rgba("b9b18a"))
    return body, detail


def golem(direction, frame):
    body, detail = Image(FRAME, FRAME), Image(FRAME, FRAME)
    for x, y in ellipse(32, 53.5, 14, 3.5):
        body.set(x, y, SHADOW)
    shape = Image(FRAME, FRAME)
    side = direction in ("left", "right")
    lift = swing(frame)
    plates = [
        ellipse(27, 48 - max(lift, 0), 4, 6),
        ellipse(37, 48 - max(-lift, 0), 4, 6),
        ellipse(32, 38, 9, 8),
        ellipse(32, 29, 12, 9),
        ellipse(32, 18, 6, 7),
    ]
    if not side:
        plates += [ellipse(18, 28 + lift, 5, 6), ellipse(17, 37 + lift, 4, 6),
                   ellipse(46, 28 - lift, 5, 6), ellipse(47, 37 - lift, 4, 6)]
    else:
        plates += [ellipse(31 + lift * 2, 28, 5, 6), ellipse(29 + lift * 2, 38, 4, 6)]
    for index, points in enumerate(plates):
        stone_surface(shape, points, MONSTER_TONES, index)
    for x, y in line(35, 25, 31, 36) | line(31, 36, 34, 40):
        shape.set(x, y, (94, 94, 94, 255))
    body.over(shape.outlined())
    if direction == "down":
        detail.rect(28, 18, 2, 1, EYE)
        detail.rect(33, 18, 2, 1, EYE)
    elif direction != "up":
        detail.rect(27 if direction == "left" else 34, 18, 2, 1, EYE)
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
    elif shape == "potion":
        glass = (rgba("d8e4ec"), rgba("b8c8d4"), rgba("8a9aa8"))
        shade(image, box(14, 8, 4, 6), glass, False)
        shade(image, box(13, 4, 6, 4), (scale(accent, 1.15), accent, scale(accent, 0.7)), False)
        body = ellipse(16, 20, 8.5, 8)
        shade(image, body, palette)
        for x, y in body:
            if y < 15:
                image.set(x, y, glass[0] if (x + y) % 3 else glass[1])
        image.rect(11, 17, 2, 4, (255, 255, 255, 200))
        image.rect(13, 15, 1, 1, (255, 255, 255, 200))
    elif shape == "pack":
        body = box(8, 10, 16, 17) - {(8, 10), (23, 10), (8, 26), (23, 26)}
        shade(image, body, palette)
        flap = box(8, 8, 16, 9) - {(8, 8), (23, 8)}
        shade(image, flap, (main, dark, scale(dark, 0.8)))
        shade(image, box(11, 20, 10, 5), (light, main, dark), False)
        for x in (11, 20):
            image.rect(x, 4, 1, 5, dark)
        image.rect(11, 4, 10, 1, dark)
        shade(image, box(15, 15, 3, 3), (scale(accent, 1.2), accent, scale(accent, 0.7)), False)
    elif shape == "pile":
        shade(image, {p for p in ellipse(16, 24, 11, 8) if p[1] <= 24}, palette)
        for x, y in ((12, 19), (19, 18), (16, 21)):
            image.rect(x, y, 2, 1, accent)
    else:  # scale
        shade(image, {p for p in ellipse(16, 15, 9, 11) if p[1] >= 6}, palette)
        for y in range(9, 24, 4):
            image.rect(11, y, 10, 1, dark)


def item_icon(kind):
    palette, accent = tones(kind)
    light, main, dark = palette
    shape, extras = look(kind)
    if shape in WEAPON_SHAPES:
        return weapon_icon(kind)
    image = Image(TILE, TILE)
    gem = (scale(accent, 1.12), accent, scale(accent, 0.65))
    if shape == "cap":
        shade(image, {p for p in ellipse(16, 17, 8, 7) if p[1] <= 17}, (light, main, dark))
        image.rect(8, 18, 16, 1, dark)
        image.set(18, 11, accent)
    elif shape == "coif":
        hood = ellipse(16, 15, 9, 10) - ellipse(16, 18, 5, 6)
        hood = {p for p in hood if p[1] <= 24}
        shade(image, hood, (light, main, dark))
        for x, y in hood:
            if (x + y) % 2 == 0 and y % 2 == 1 and image.get(x, y) == main:
                image.set(x, y, scale(main, 1.1))
    elif shape in ("helm", "kettle", "greathelm"):
        dome = {p for p in ellipse(16, 17, 9, 9) if p[1] <= 17}
        if shape == "greathelm":
            dome = ellipse(16, 16, 8.5, 10)
        elif shape == "helm":
            dome |= box(8, 17, 4, 7) | box(20, 17, 4, 7)
        shade(image, dome, (light, main, dark))
        if shape == "kettle":
            bevel(image, box(5, 17, 22, 2), main, light, dark)
        if shape == "helm":
            image.rect(15, 14, 1, 8, main)
        if shape == "greathelm":
            image.rect(10, 15, 12, 1, OUTLINE)
            for x in (12, 15, 18):
                image.set(x, 19, OUTLINE)
        if "plume" in extras:
            shade(image, box(15, 1, 3, 7) | box(18, 3, 2, 5), gem, False)
        if "crest" in extras:
            shade(image, box(14, 3, 4, 5), gem, False)
        if "horns" in extras:
            for x, y in thick({(6, 9), (5, 7), (4, 5), (4, 3)} | {(25, 9), (26, 7), (27, 5), (27, 3)}, ((0, 0), (1, 0))):
                image.set(x, y, BONE[0])
    elif shape in ("coat", "tunic", "mail", "scale", "brigandine", "plate"):
        tunic = shape == "tunic"
        body = box(11, 9, 10, 15 if tunic else 16)
        if tunic:
            body |= box(10, 22, 12, 3)
        sleeves = box(7, 10, 4, 6 if tunic else 9) | box(21, 10, 4, 6 if tunic else 9)
        silhouette = (body | sleeves) - {(7, 10), (24, 10), (11, 24), (20, 24)}
        shade(image, silhouette, (light, main, dark))
        if tunic:
            image.rect(11, 18, 10, 1, LEATHER)
        elif shape == "coat":
            image.rect(15, 11, 1, 13, dark)
            for y in (13, 16, 19):
                image.set(16, y, accent)
        elif shape == "mail":
            for x, y in silhouette:
                if (x + y // 2) % 3 == 0 and y % 2 == 1:
                    image.set(x, y, scale(main, 1.12))
            image.rect(11, 20, 10, 1, LEATHER)
        elif shape in ("scale", "brigandine"):
            armor_surface(image, silhouette, shape, palette)
            image.rect(11, 20, 10, 1, LEATHER)
            if shape == "brigandine":
                image.rect(15, 11, 1, 9, dark)
        else:
            shade(image, ellipse(9, 11, 3, 3) | ellipse(23, 11, 3, 3), (light, main, dark))
            for y in (18, 22):
                image.rect(11, y, 10, 1, dark)
            image.rect(15, 12, 1, 4, light)
            image.set(17, 12, accent)
        for x in range(14, 18):
            for y in range(9, 11):
                if shape != "plate":
                    image.clear(x, y)
    elif shape == "buckler":
        shield_face(image, ellipse(16, 17, 8.5, 9), (light, main, dark), accent, box(15, 16, 2, 2))
    elif shape == "heater":
        plate_face(image, heater_points(9, 6, 15, 21), (light, main, dark), dark, box(16, 11, 1, 8))
    elif shape == "tower":
        plate_face(image, heater_points(9, 5, 15, 23), (light, main, dark), dark, box(15, 11, 2, 10))
    elif shape == "torch":
        stick = thick(line(9, 27, 19, 12), ((0, 0), (1, 0)))
        shade(image, stick, WOOD, False)
        image.rect(18, 10, 4, 3, rgba("3a2a1c"))
        torch_flame(image, 20, 10, 9, 1)
    elif shape == "book":
        bevel(image, box(9, 7, 14, 19), main, light, dark)
        image.rect(9, 7, 2, 19, dark)
        image.rect(21, 9, 1, 15, rgba("b9af93"))
        for y in (10, 22):
            image.rect(12, y, 8, 1, dark)
        image.rect(20, 15, 3, 2, accent)
        if ITEMS[kind].get("level", 1) >= 15:
            for x, y in line(14, 14, 17, 17) | line(17, 17, 15, 19):
                image.set(x, y, accent)
    elif shape == "cape":
        cape = set()
        for y in range(7, 26):
            half = 4 + (y - 7) * 4 // 18
            cape |= box(16 - half, y, half * 2, 1)
        shade(image, cape, (light, main, dark))
        for x in (12, 16, 20):
            for y in range(12, 25):
                image.set(x, y, dark)
        image.rect(15, 7, 2, 1, accent)
    elif shape == "ring":
        band = ellipse(16, 19, 6, 5) - ellipse(16, 19, 4, 3)
        shade(image, band, (light, main, dark), False)
        shade(image, ellipse(16, 14, 2.5, 2), gem, False)
        image.set(15, 13, light)
    elif shape == "amulet":
        for chain in (line(6, 5, 15, 17), line(26, 5, 17, 17)):
            for index, (x, y) in enumerate(sorted(chain)):
                image.set(x, y, light if index % 2 else main)
        shade(image, ellipse(16, 22, 4.5, 5.5) | {(16, 16)}, gem, False)
        image.set(15, 20, (230, 245, 255, 255))
    elif shape == "charm":
        for y in range(3, 10):
            image.set(16, y, LEATHER)
        shade(image, ellipse(16, 18, 8.5, 8.5), (light, main, dark))
        flame = box(15, 13, 2, 9) | box(13, 17, 6, 4) | box(14, 15, 4, 2) | {(16, 12)}
        for x, y in flame:
            image.set(x, y, accent if y < 19 else scale(accent, 1.3))
    elif shape == "coins":
        for cx, cy in ((11, 22), (20, 23), (15, 18), (9, 15), (21, 16), (16, 12)):
            coin = ellipse(cx, cy, 4.5, 3)
            for x, y in coin:
                image.set(x, y, light if y < cy - 1 else main)
            for x, y in coin:
                if (x, y + 1) not in coin:
                    image.set(x, y, dark)
        image.set(14, 10, (255, 248, 210, 255))
    elif shape == "glowcap":
        bevel(image, box(13, 15, 6, 10), accent, scale(accent, 1.1), scale(accent, 0.8))
        bevel(image, {p for p in ellipse(16, 15, 10, 8) if p[1] <= 15}, main, light, scale(main, 0.75))
        for x, y in ((12, 10), (19, 9), (16, 12), (22, 13)):
            image.rect(x, y, 2, 2, light)
    else:
        material_icon(image, shape, (light, main, dark), accent)
    return image.outlined(scale(main, 0.42))


# ---------------------------------------------------------------- terrain

GRASS = (rgba("505d3b"), rgba("5d6944"), rgba("465437"), rgba("707951"), rgba("3d4933"))
DIRT = (rgba("80725c"), rgba("766851"), rgba("92816a"), rgba("625944"))
WATER = (rgba("354b50"), rgba("49666a"), rgba("688281"), rgba("293e44"), rgba("30464b"))
FLOWERS = (rgba("beb793"), rgba("b3a56b"), rgba("a9999b"))


def grass_tile(variant):
    rng = random.Random(100 + variant)
    image = Image(TILE, TILE)
    image.rect(0, 0, TILE, TILE, GRASS[0])
    for _ in range(30):
        x, y = rng.randrange(TILE), rng.randrange(TILE)
        tone = GRASS[rng.choice((1, 2, 2))]
        for px, py in ellipse(x, y, rng.randrange(2, 5), rng.randrange(1, 3)):
            image.set(px % TILE, py % TILE, tone)
    for _ in range(30):
        x, y = rng.randrange(TILE), rng.randrange(TILE)
        length = rng.choice((1, 2, 2, 3))
        image.set(x, y, GRASS[4])
        for step in range(length):
            image.set((x + step // 2) % TILE, (y - step - 1) % TILE, GRASS[1 if step < 2 else 3])
    if variant == 3:
        for _ in range(2):
            x, y = rng.randrange(3, 28), rng.randrange(3, 28)
            petal = rng.choice(FLOWERS)
            image.set(x, y, petal)
            image.set(x + 1, y, FLOWERS[1])
    return image


def dirt_tile(variant):
    rng = random.Random(200 + variant)
    image = Image(TILE, TILE)
    image.rect(0, 0, TILE, TILE, DIRT[0])
    for _ in range(22):
        x, y = rng.randrange(TILE), rng.randrange(TILE)
        for px, py in ellipse(x, y, rng.randrange(2, 6), rng.randrange(1, 3)):
            image.set(px % TILE, py % TILE, DIRT[1])
    for _ in range(6):
        x, y = rng.randrange(1, 29), rng.randrange(1, 29)
        size = rng.choice((2, 2, 3))
        shade(image, ellipse(x, y, size / 2, 1), (DIRT[2], DIRT[0], DIRT[3]), False)
    return image


def water_tile(frame):
    rng = random.Random(300)
    image = Image(TILE, TILE)
    image.rect(0, 0, TILE, TILE, WATER[0])
    for _ in range(60):
        image.set(rng.randrange(TILE), rng.randrange(TILE), WATER[4])
    for wave in range(6):
        x, y = rng.randrange(TILE), 3 + wave * 5
        x = (x + frame * 2 * (1 if wave % 2 else -1)) % TILE
        for dx in range(rng.randrange(5, 12)):
            image.set((x + dx) % TILE, (y + dx // 5) % TILE, WATER[1])
        if wave % 3 == 0:
            image.set((x + 2) % TILE, y, WATER[2])
    return image


def edge_overlay(kind):
    """North-edge overlay; rotated for the other sides."""
    rng = random.Random({"shore": 400, "sand": 450}.get(kind, 500))
    image = Image(TILE, TILE)
    if kind == "sand":
        # Dry grass creeping onto sand: a ragged sun-bleached fringe with a few loose blades.
        dry = (blend(GRASS[3], SAND[0], 0.35), blend(GRASS[0], SAND[1], 0.3), blend(GRASS[2], SAND[3], 0.25))
        depth = 2
        for x in range(TILE):
            depth = max(1, min(4, depth + rng.choice((-1, 0, 0, 1))))
            for y in range(depth):
                image.set(x, y, dry[1] if y < depth - 1 else dry[2])
            if rng.random() < 0.18:
                for y in range(depth, depth + rng.choice((1, 2, 3))):
                    image.set(x, y, dry[0])
            image.set(x, depth, SAND[3][:3] + (90,))
        return image
    for x in range(TILE):
        if kind == "shore":
            image.set(x, 0, WATER[1] if rng.random() < 0.85 else WATER[2])
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


SAND = (rgba("ac9c76"), rgba("9d8e6b"), rgba("c0ae86"), rgba("837759"))
COBBLE = (rgba("787971"), rgba("97988b"), rgba("63665f"), rgba("484e47"))
PLANK = (rgba("76634b"), rgba("948063"), rgba("5e513f"), rgba("3d382c"))
LEAF = (rgba("798054"), rgba("525f3a"), rgba("303f2a"))
PINE = (rgba("617555"), rgba("425d42"), rgba("293c2d"))
BARK = (rgba("84725a"), rgba("62513d"), rgba("40382b"))


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


DUSK = (rgba("2e2438"), rgba("362a44"), rgba("251d2e"), rgba("43355a"), rgba("8a5ad0"))
OBSIDIAN = (rgba("221c2e"), rgba("2c2540"), rgba("15111d"), rgba("3a3150"), rgba("9a6ae0"))
# Dungeon cave floor: rough grey-brown rock with pebbles and cracks.
CAVE = (rgba("5a534c"), rgba("675f57"), rgba("4a443e"), rgba("7a7168"), rgba("3a3530"))


def dusk_tile(variant):
    """Blighted soil of the Hollow Reach: dark violet earth, cracks, and faint glowing motes."""
    rng = random.Random(700 + variant)
    image = Image(TILE, TILE)
    image.rect(0, 0, TILE, TILE, DUSK[0])
    for _ in range(110):
        image.set(rng.randrange(TILE), rng.randrange(TILE), DUSK[rng.choice((1, 1, 2))])
    for _ in range(2):
        x, y = rng.randrange(2, 28), rng.randrange(2, 28)
        for step in range(rng.randrange(4, 9)):
            image.set(x, y, DUSK[2])
            x, y = x + rng.choice((-1, 0, 1)), y + 1
    for _ in range(3):
        x, y = rng.randrange(1, 30), rng.randrange(1, 30)
        image.rect(x, y, 2, 1, DUSK[3])
    if variant % 2 == 0:
        image.set(rng.randrange(4, 28), rng.randrange(4, 28), DUSK[4])
    return image


def obsidian_tile(variant):
    """Obsidian flagstones of the Hollow Sanctum, with an occasional violet rune."""
    rng = random.Random(800 + variant)
    image = Image(TILE, TILE)
    image.rect(0, 0, TILE, TILE, OBSIDIAN[2])
    for sx, sy, w, h in ((0, 0, 16, 16), (16, 0, 16, 16), (0, 16, 16, 16), (16, 16, 16, 16)):
        slab = box(sx + 1, sy + 1, w - 1, h - 1)
        bevel(image, slab, OBSIDIAN[0], OBSIDIAN[3], OBSIDIAN[2])
        for _ in range(10):
            x, y = rng.choice(sorted(slab))
            image.set(x, y, OBSIDIAN[1])
    if variant == 0:
        for x, y in ((7, 6), (8, 7), (9, 8), (8, 9), (7, 10), (6, 9), (5, 8), (6, 7), (8, 4), (8, 12)):
            image.set(x, y, OBSIDIAN[4])
    return image


def cave_tile(variant):
    """Rough cave floor of the crypt and mine: uneven rock, pebbles, and hairline cracks."""
    rng = random.Random(1000 + variant)
    image = Image(TILE, TILE)
    image.rect(0, 0, TILE, TILE, CAVE[0])
    for _ in range(140):
        image.set(rng.randrange(TILE), rng.randrange(TILE), CAVE[rng.choice((1, 1, 2))])
    for _ in range(3 + variant % 2):
        x, y = rng.randrange(3, 27), rng.randrange(3, 27)
        bevel(image, box(x, y, rng.randrange(2, 4), 2), CAVE[3], CAVE[3], CAVE[4])
    x, y = rng.randrange(2, 28), rng.randrange(2, 12)
    for step in range(rng.randrange(6, 14)):
        image.set(x, y, CAVE[4])
        x, y = max(0, min(31, x + rng.choice((-1, 0, 1)))), min(31, y + 1)
    return image


def stairs_tile(down):
    """A stairway set in a stone frame: steps descend into darkness ("v") or rise toward the
    light ("^")."""
    image = Image(TILE, TILE)
    bevel(image, box(0, 0, TILE, TILE), COBBLE[1], COBBLE[0], COBBLE[3])
    for step in range(6):
        y = 4 + step * 4
        shade = (5 - step) / 5 if down else (step + 1) / 6
        tread = scale(COBBLE[1], 0.25 + 0.75 * shade)
        riser = scale(COBBLE[2], 0.2 + 0.6 * shade)
        image.rect(4, y, 24, 3, tread)
        image.rect(4, y + 3, 24, 1, riser)
    for y in range(4, 28):
        image.set(3, y, OUTLINE)
        image.set(28, y, OUTLINE)
    image.rect(3, 3, 26, 1, OUTLINE)
    image.rect(3, 28, 26, 1, OUTLINE)
    return image


def stone_surface(image, points, palette, seed):
    """Weathered stone with a shallow bevel, broad mottling and occasional worn flecks."""
    light, main, dark = palette
    shade(image, points, (light, main, dark), False)
    for x, y in sorted(points):
        fleck = (x * 71 + y * 131 + seed * 197) % 37
        if image.get(x, y) == main:
            if fleck < 3:
                image.set(x, y, scale(main, 0.91))
            elif fleck == 7:
                image.set(x, y, scale(main, 1.08))


def cobble_tile(variant):
    rng = random.Random(800 + variant)
    image = Image(TILE, TILE)
    image.rect(0, 0, TILE, TILE, COBBLE[3])
    for row in range(4):
        shift = (row % 2) * 4 + variant
        for column in range(-1, 4):
            x = column * 10 + shift
            y = row * 8 + rng.randrange(0, 2)
            stone = box(x + 1, y, 9, 7) - {(x + 1, y), (x + 9, y + 6), (x + 1, y + 6)}
            tone = rng.choice((0.92, 1.0, 1.04))
            stone_surface(image, stone, (scale(COBBLE[1], tone), scale(COBBLE[0], tone), COBBLE[2]), variant)
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
        for _ in range(3):
            start, y = rng.randrange(TILE), board * 8 + rng.randrange(1, 6)
            for x in range(start, start + rng.randrange(5, 13)):
                image.set(x % TILE, y, scale(PLANK[0], 0.88 * tone))
        if board == variant + 1:
            image.set(17, board * 8 + 3, PLANK[3])
            image.rect(15, board * 8 + 2, 5, 1, PLANK[2])
    return image.rotated() if vertical else image


DEAD_BARK = (rgba("5a4a66"), rgba("3e3249"), rgba("261e2e"))


def dead_tree(variant):
    """Bare, twisted tree of the Hollow Reach; same 64x96 cell and anchor as tree()."""
    rng = random.Random(1100 + variant)
    image = Image(FRAME, 96)
    for x, y in ellipse(32, 82, 12, 3):
        image.set(x, y, SHADOW)
    wood = set(box(29, 50, 5, 32) | box(27, 79, 9, 3))
    branches = [((31, 52), (18, 30)), ((32, 46), (46, 24)), ((30, 60), (16, 48)), ((33, 58), (48, 44)),
                ((31, 50), (30, 18))]
    for (x0, y0), (x1, y1) in branches[: 4 + variant]:
        x1, y1 = x1 + rng.randrange(-3, 4), y1 + rng.randrange(-3, 4)
        wood |= thick(line(x0, y0, x1, y1), ((0, 0), (1, 0)))
        for twig in range(2):
            tx, ty = x1 + rng.randrange(-6, 7), y1 - rng.randrange(3, 9)
            wood |= line(x1, y1, tx, ty)
    trunk = Image(FRAME, 96)
    shade(trunk, wood, DEAD_BARK, False)
    image.over(trunk.outlined())
    for _ in range(3):
        x, y = rng.choice(sorted(p for p in wood if p[1] < 50))
        image.set(x, y - 1, rgba("b07aff"))
    return image


CACTUS = (rgba("8e9a64"), rgba("6b7a49"), rgba("4a5636"))
SPINE = rgba("d4cca4")
THORN_WOOD = (rgba("a28c6c"), rgba("7c6852"), rgba("554638"))


def wall_torch(frame):
    """A torch in an iron bracket for town walls, 16x24: frame 0 unlit (charred head), frames 1-3 a
    flickering flame. The bracket's foot sits at the bottom centre."""
    image = Image(16, 24)
    iron, iron_light = rgba("3b3a38"), rgba("5d5c58")
    image.rect(5, 20, 6, 2, iron)
    image.rect(6, 19, 4, 1, iron_light)
    image.rect(7, 12, 2, 8, rgba("6b4a2c"))
    image.rect(7, 12, 1, 8, rgba("8a6440"))
    image.rect(6, 11, 4, 2, rgba("3a2a1c"))
    if frame == 0:
        image.rect(7, 10, 2, 1, rgba("2a2420"))
        return image.outlined()
    sway = (0, -1, 1)[frame - 1]
    height = (8, 7, 9)[frame - 1]
    outer, mid, inner = rgba("d0581c"), rgba("f09a2a"), rgba("fff0a0")
    for y in range(height):
        row = 11 - y
        half = max(0, round(2.6 * (1 - y / height) + 0.4))
        shift = round(sway * y / height)
        for x in range(8 - half + shift, 8 + half + shift):
            image.set(x, row, outer)
        if half > 1:
            for x in range(8 - half + 1 + shift, 8 + half - 1 + shift):
                image.set(x, row, mid)
        if y < height // 2 and half > 1:
            image.set(8 + shift, row, inner)
    return image.outlined(rgba("5a2010"))


def waystone():
    """A carved standing stone (64x96 object cell, base on the tile centre at (32, 80)): a weathered
    grey menhir on a ring of flat stones, with a rune that glows cyan; the travel point that
    replaced the coachmen."""
    image = Image(64, 96)
    for x, y in ellipse(32, 81, 15, 4):
        image.set(x, y, rgba("000000", 70))
    for cx, cy, rx in ((20, 80, 5), (44, 80, 5), (25, 84, 5), (39, 84, 5), (32, 85, 5)):
        for x, y in ellipse(cx, cy, rx, 2.2):
            image.set(x, y, WALL_TOP[2])
        for x in range(cx - rx + 1, cx + rx):
            image.set(x, cy - 2, WALL_TOP[0])
    body = set()
    for y in range(34, 82):
        t = (y - 34) / 47.0
        half = round(6 + 4 * t + (1 if 40 < y < 60 else 0))
        lean = round((1 - t) * 2)
        body |= {(x, y) for x in range(32 - half + lean, 32 + half + lean)}
    body -= {(x, y) for x, y in body if y < 38 and abs(x - 34) > 4 + (y - 34)}
    for x, y in body:
        left = min(px for px, py in body if py == y)
        right = max(px for px, py in body if py == y)
        color = WALL_TOP[0]
        if x - left < 2:
            color = WALL_TOP[1]
        elif right - x < 4:
            color = WALL_SOUTH[0]
        if (x * 7 + y * 3) % 23 == 0:
            color = scale(color, 0.85)
        if y % 11 == 0 and (x + y) % 3:
            color = scale(color, 0.92)
        image.set(x, y, color)
    rune = rgba("7fe8f0")
    core = rgba("e8ffff")
    for x, y in line(31, 46, 31, 64) | line(31, 50, 37, 46) | line(31, 56, 26, 52) | line(31, 60, 36, 64):
        image.set(x, y, rune)
    for x, y in ((31, 46), (31, 55), (31, 64)):
        image.set(x, y, core)
    return image.outlined()


def desert_plant(variant):
    """Original desert flora in the 64x96 tree cell, base on the tile centre at (32, 80):
    0 a ribbed columnar cactus with two arms, 1 a clump of barrel cacti, 2 a dry thorn shrub."""
    image = Image(FRAME, 96)
    for x, y in ellipse(32, 81, 10 if variant != 1 else 13, 3):
        image.set(x, y, SHADOW)
    plant = Image(FRAME, 96)
    if variant == 0:
        points = box(29, 44, 7, 37) | ellipse(32, 44, 3.5, 3)
        arms = (box(22, 56, 7, 4) | box(22, 46, 4, 12) | ellipse(24, 46, 2, 2)
                | box(36, 51, 6, 4) | box(39, 40, 4, 13) | ellipse(41, 40, 2, 2))
        points |= arms
        shade(plant, points, CACTUS, False)
        for x, y in sorted(points):
            if x % 2 == 0 and (x - 1, y) in points and (x + 1, y) in points and y % 5 != 0:
                plant.set(x, y, CACTUS[2] if x > 32 else CACTUS[1])
            if (x * 7 + y * 3) % 23 == 0 and ((x - 1, y) not in points or (x + 1, y) not in points):
                plant.set(x + (-1 if (x - 1, y) not in points else 1), y, SPINE)
    elif variant == 1:
        for cx, cy, rx, ry in ((27, 74, 6, 7), (37, 76, 5, 5), (31, 79, 4, 3)):
            barrel = ellipse(cx, cy, rx, ry)
            shade(plant, barrel, CACTUS, False)
            for x, y in sorted(barrel):
                if (x - cx) % 2 == 0 and abs(x - cx) < rx - 1 and y > cy - ry + 1:
                    plant.set(x, y, CACTUS[2])
                if (x * 5 + y * 11) % 19 == 0 and (x, y - 1) not in barrel:
                    plant.set(x, y - 1, SPINE)
        plant.set(27, 66, rgba("b4806a"))
        plant.set(28, 66, rgba("c99a7e"))
    else:
        rng = random.Random(1300)
        twigs = set(box(31, 70, 2, 11))
        for a, b in [((32, 74), (22, 60)), ((32, 72), (43, 58)), ((32, 76), (21, 70)), ((32, 75), (44, 68)),
                     ((32, 70), (31, 56))]:
            twigs |= line(*a, *b)
            end = b
            for _ in range(2):
                tip = (end[0] + rng.randrange(-5, 6), end[1] - rng.randrange(2, 7))
                twigs |= line(*end, *tip)
        shade(plant, twigs, THORN_WOOD, False)
        for _ in range(9):
            x, y = rng.choice(sorted(p for p in twigs if p[1] < 70))
            plant.set(x + rng.choice((-1, 1)), y, CACTUS[1] if rng.random() < 0.6 else CACTUS[0])
    image.over(plant.outlined(scale(CACTUS[2] if variant < 2 else THORN_WOOD[2], 0.75)))
    return image


def tree(variant):
    """64x96 cell; the trunk base sits on the tile centre at (32, 80)."""
    rng = random.Random(1000 + variant)
    image = Image(FRAME, 96)
    for x, y in ellipse(32, 82, 15, 4):
        image.set(x, y, SHADOW)
    trunk = Image(FRAME, 96)
    wood = box(29, 44, 6, 37)
    for a, b in [((31, 60), (19, 38)), ((32, 54), (46, 36)), ((31, 76), (24, 82)), ((33, 77), (42, 83))]:
        wood |= thick(line(*a, *b), ((0, 0), (1, 0)))
    shade(trunk, wood, BARK, False)
    for x, y in sorted(wood):
        if (x * 13 + y // 5) % 5 == 0:
            trunk.set(x, y, BARK[2])
    image.over(trunk.outlined(BARK[2]))
    crown = Image(FRAME, 96)
    if variant < 2:
        lobes = [(19, 51, 12, 9), (42, 53, 12, 10), (30, 44, 20, 18),
                 (20, 33, 12, 11), (45, 35, 10, 13), (33, 22, 13, 12)]
        for cx, cy, rx, ry in lobes:
            cx += rng.randrange(-2, 3)
            cy += rng.randrange(-2, 3)
            points = ellipse(cx, cy, rx, ry)
            for x, y in sorted(points):
                edge = any((x + dx, y + dy) not in points for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if edge and (x * 13 + y * 7) % 5 == 0:
                    continue
                lighting = (cx - x) / rx * 0.35 + (cy - y) / ry * 0.55
                patch = ((x // 3 * 7 + y // 2 * 11 + variant * 3) % 7 - 3) * 0.06
                tone = LEAF[0] if lighting + patch > 0.35 else (LEAF[2] if lighting + patch < -0.32 else LEAF[1])
                if (x * 17 + y * 31) % 11 < 2:
                    tone = scale(tone, 1.13)
                crown.set(x, y, tone)
    else:
        points = set()
        for y in range(9, 66):
            width = max(1, round((y - 8) * 0.35) - (y % 7) // 3)
            points |= box(32 - width, y, width * 2, 1)
        for x, y in sorted(points):
            branch = (y + abs(x - 32) // 2) % 7
            tone = PINE[2] if branch > 4 else (PINE[0] if x < 32 and branch < 2 else PINE[1])
            crown.set(x, y, tone)
    image.over(crown.outlined(LEAF[2] if variant < 2 else PINE[2]))
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
    cactus_tile = sand_tile(0)
    cactus_tile.over(desert_plant(0).crop(16, 52, TILE, TILE))
    dead_tile = dusk_tile(1)
    dead_tile.over(dead_tree(0).crop(16, 48, TILE, TILE))
    tiles = {".": grass_tile(0), ",": dirt_tile(0), "~": water_tile(0), "#": wall_tile, "T": tree_tile,
             ":": sand_tile(0), "=": cobble_tile(0), "b": plank_tile(False, 0), "d": dusk_tile(0),
             "o": obsidian_tile(0), "O": wall(0, OBSIDIAN_STONE).crop(0, 0, TILE, TILE), "D": dead_tile,
             "c": cave_tile(0), "C": wall(0, CAVE_STONE).crop(0, 0, TILE, TILE),
             "v": stairs_tile(True), "^": stairs_tile(False), "K": cactus_tile}
    return sheet([tiles[terrain] for terrain in TERRAINS], len(TERRAINS), TILE)


WALL_TOP = (rgba("797970"), rgba("939185"), rgba("64685f"), rgba("555b53"))
WALL_SOUTH = (rgba("56594f"), rgba("42473f"), rgba("676a5d"))
WALL_EAST = (rgba("434a43"), rgba("343b35"), rgba("545b50"))
STONE = (WALL_TOP, WALL_SOUTH, WALL_EAST)
# Obsidian walls of the Hollow Sanctum: the same oblique shape in violet-black glassy stone.
OBSIDIAN_STONE = ((rgba("3d3352"), rgba("4c4066"), rgba("2e2640"), rgba("5e4f80")),
                  (rgba("231c31"), rgba("17121f"), rgba("33294a")),
                  (rgba("1a1524"), rgba("110d18"), rgba("2a2238")))
# Raw rock walls of the deep mine.
CAVE_STONE = ((rgba("6e6156"), rgba("85766a"), rgba("54493f"), rgba("948476")),
              (rgba("43392f"), rgba("2f2821"), rgba("51463b")),
              (rgba("352d25"), rgba("251f19"), rgba("40372d")))
HEIGHT = 16


def wall(mask, stone=None):
    WALL_TOP, WALL_SOUTH, WALL_EAST = stone or STONE
    open_north, open_west, open_south, open_east = (bool(mask & bit) for bit in (1, 2, 4, 8))
    image = Image(WALL, WALL)
    if open_east:
        for y in range(FRAME):
            for x in range(32, 48):
                depth = 48 - (x + 0.5)
                if 16 - depth <= y + 0.5 < 48 - depth:
                    level = y + 0.5 + depth - 16
                    course = int(level // 8)
                    joint = (depth + (5 if course % 2 else 0)) % 12
                    color = WALL_EAST[0]
                    if level % 8 < 1.0 or joint < 1.0:
                        color = WALL_EAST[1]
                    elif level % 8 < 2.0 and joint > 2:
                        color = WALL_EAST[2]
                    elif (x * 13 + y * 7) % 19 < 3:
                        color = scale(color, 0.92)
                    if level < 1.0 or x == 47:
                        color = OUTLINE
                    image.set(x, y, color)
    if open_south:
        for y in range(32, 48):
            rise = 48 - (y + 0.5)
            for x in range(0, 48):
                if 16 - rise <= x + 0.5 < 48 - rise:
                    course = int(rise // 8)
                    along = x + 0.5 + rise - 16 + (7 if course % 2 else 0)
                    color = WALL_SOUTH[0]
                    if rise % 8 < 1.0 or along % 15 < 1.0:
                        color = WALL_SOUTH[1]
                    elif 8 - rise % 8 < 1.0 and along % 15 > 2:
                        color = WALL_SOUTH[2]
                    elif (x * 13 + y * 7) % 19 < 3:
                        color = scale(color, 0.92)
                    if y == 47 or x + 0.5 < 16 - rise + 1.0:
                        color = OUTLINE
                    image.set(x, y, color)
    top = box(0, 0, 32, 32)
    bevel(image, top, WALL_TOP[0], WALL_TOP[0], WALL_TOP[0])
    for row in range(3):
        offset = (row % 2) * 7
        for start in range(-offset, 32, 16):
            slab = {(x, y) for x, y in box(start + 1, row * 11, 15, 10) if 0 <= x < 32 and y < 32}
            slab -= {(start + 1, row * 11), (start + 15, row * 11 + 9)}
            stone_surface(image, slab, (WALL_TOP[1], WALL_TOP[0], WALL_TOP[2]), row)
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



THIN_BAND = (11, 21)  # a thin wall's masonry band across its tile


def thin_wall(mask, stone=None):
    """A thin wall (town houses and walls): a 10-pixel masonry band through the tile centre,
    reaching the tile edge toward each connected side (1 N, 2 W, 4 S, 8 E: a wall or a doorway
    there), raised 16 px like the thick walls with its south and east faces showing."""
    top_tones, south, east = stone or STONE
    lo, hi = THIN_BAND
    shape = set(box(lo, lo, hi - lo, hi - lo))
    for bit, area in ((1, box(lo, 0, hi - lo, lo)), (2, box(0, lo, lo, hi - lo)),
                      (4, box(lo, hi, hi - lo, TILE - hi)), (8, box(hi, lo, TILE - hi, hi - lo))):
        if mask & bit:
            shape |= set(area)
    image = Image(WALL, WALL)
    raise_ = WALL - TILE
    for k in range(raise_, 0, -1):
        height = raise_ - k
        for x, y in shape:
            px, py = x + k, y + k
            if (x, y + 1) not in shape:
                along = x + (7 if (height // 8) % 2 else 0)
                color = south[0]
                if height % 8 == 7 or along % 15 == 0:
                    color = south[1]
                elif height % 8 == 6 and along % 15 > 2:
                    color = south[2]
                if k == raise_:
                    color = OUTLINE
            else:
                along = y + (5 if (height // 8) % 2 else 0)
                color = east[0]
                if height % 8 == 7 or along % 12 == 0:
                    color = east[1]
                if k == raise_ or (x + 1, y) in shape:
                    color = OUTLINE if k == raise_ else color
            if (x + 1, y) in shape and (x, y + 1) in shape:
                continue
            image.set(px, py, color)
    for x, y in shape:
        course = y // 6 if mask & 5 and not mask & 10 else x // 6
        color = top_tones[0]
        if (x + y * 3 + course * 5) % 11 == 0:
            color = top_tones[2]
        elif (x * 7 + y) % 13 == 0:
            color = top_tones[1]
        edge = ((x, y - 1) not in shape and y > 0) or ((x - 1, y) not in shape and x > 0) \
            or ((x, y + 1) not in shape and y < TILE - 1) or ((x + 1, y) not in shape and x < TILE - 1)
        if edge:
            color = top_tones[3]
        image.set(x, y, color)
    for x, y in shape:
        for dx, dy in ((0, -1), (-1, 0)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < TILE and 0 <= ny < TILE and (nx, ny) not in shape and image.get(nx, ny) is None:
                image.set(nx, ny, OUTLINE)
    return image


# ---------------------------------------------------------------- furniture
# 32x48 cells; the tile is the bottom 32x32 (drawn 16 px above it), so pieces may stand taller
# than a tile. Order: FURNITURE_KINDS (SpriteArt.FURNITURE must match).

FURNITURE_KINDS = ["counter_shop", "counter_bank", "shelf_potions", "shelf_books", "weapon_rack", "barrel", "crate",
                   "strongbox"]
OAK = (rgba("a07a4c"), rgba("82603a"), rgba("5f4429"), rgba("3f2c1b"))
IRON = (rgba("8c8e8c"), rgba("5d605f"), rgba("3a3c3c"))


def plank_block(image, x, y, width, height, top_depth, wood=OAK):
    """A wooden block in 3/4 view: a lit top `top_depth` deep and a front face below it."""
    light, base, dark, deep = wood
    for py in range(y, y + top_depth):
        for px in range(x, x + width):
            image.set(px, py, light if (px - x) % 9 else base)
    for py in range(y + top_depth, y + height):
        for px in range(x, x + width):
            color = base if (py - y - top_depth) % 5 else dark
            if px in (x, x + width - 1):
                color = dark
            image.set(px, py, color)
    for px in range(x, x + width):
        image.set(px, y + top_depth, deep)
        image.set(px, y + height - 1, deep)


def furniture(kind):
    image = Image(TILE, 48)
    light, base, dark, deep = OAK
    if kind.startswith("counter"):
        plank_block(image, 1, 22, 30, 24, 8)
        if kind == "counter_shop":
            for x, color in ((5, rgba("a3332b")), (11, rgba("3f62a8")), (17, rgba("a3332b"))):
                image.template(x, 16, [".o.", "ogo", "occ", "occ", "ooo"], {"o": OUTLINE, "g": rgba("9fb7bf"), "c": color})
            image.template(22, 21, ["oooooo", "owwwwo", "oooooo"], {"o": OUTLINE, "w": rgba("d9cfb4")})
        else:
            gold, shine, shade = rgba("d4a73c"), rgba("f3d77a"), rgba("8f6a1e")
            for cx, cy in ((7, 25), (7, 23), (11, 25)):
                image.rect(cx - 2, cy - 1, 5, 2, gold)
                image.set(cx - 1, cy - 1, shine)
                image.rect(cx - 2, cy + 1, 5, 1, shade)
            image.rect(19, 11, 1, 13, IRON[1])
            image.rect(15, 12, 9, 1, IRON[0])
            for side in (15, 23):
                image.rect(side - 2, 16, 5, 1, IRON[1])
                image.set(side, 13, IRON[2])
                image.set(side, 14, IRON[2])
                image.set(side, 15, IRON[2])
            image.rect(17, 23, 5, 1, IRON[2])
    elif kind.startswith("shelf"):
        for x in (2, 29):
            image.rect(x, 4, 2, 42, dark)
        for y in (4, 15, 26, 37):
            image.rect(2, y, 29, 2, base)
            image.rect(2, y + 2, 29, 1, deep)
        image.rect(4, 6, 25, 40, rgba("2b231b"))
        for y in (15, 26, 37):
            image.rect(2, y, 29, 2, base)
            image.rect(2, y + 2, 29, 1, deep)
        image.rect(2, 45, 29, 2, deep)
        for row, top in enumerate((7, 18, 29)):
            for slot in range(5):
                x = 5 + slot * 5
                seed = hash_cell(slot, row + (7 if kind == "shelf_books" else 0))
                if kind == "shelf_potions":
                    color = (rgba("a3332b"), rgba("3f62a8"), rgba("5a8a3a"), rgba("a3332b"))[seed % 4]
                    image.template(x, top + 1, [".o.", "ogo", "occ", "occ", "ooo"],
                                   {"o": OUTLINE, "g": rgba("9fb7bf"), "c": color})
                else:
                    color = (rgba("6b2f2a"), rgba("2f4a6b"), rgba("4f5a2c"), rgba("6b5a2f"))[seed % 4]
                    height = 6 + seed % 3
                    image.rect(x, top + 8 - height, 4, height, color)
                    image.rect(x, top + 8 - height, 1, height, scale(color, 1.3))
                    image.rect(x + 1, top + 9 - height, 2, 1, rgba("c9a24a"))
    elif kind == "weapon_rack":
        image.rect(3, 40, 26, 6, dark)
        image.rect(3, 40, 26, 2, base)
        image.rect(3, 14, 26, 3, base)
        image.rect(3, 16, 26, 1, deep)
        for x in (4, 27):
            image.rect(x, 14, 2, 32, dark)
        for x, blade in ((9, rgba("c9cfd2")), (16, rgba("aab3b8")), (23, rgba("c9cfd2"))):
            image.rect(x, 4, 2, 30, blade)
            image.set(x, 3, blade)
            image.rect(x + 1, 4, 1, 30, scale(blade, 0.8))
            image.rect(x - 2, 33, 6, 2, rgba("c9a24a"))
            image.rect(x, 35, 2, 5, rgba("5a3f25"))
    elif kind == "barrel":
        for y in range(16, 46):
            bulge = 2 if 22 <= y <= 40 else (1 if 18 <= y <= 43 else 0)
            for x in range(7 - bulge, 26 + bulge):
                stave = (x - 4) % 5
                color = base if stave else dark
                if x == 7 - bulge or x == 25 + bulge:
                    color = deep
                image.set(x, y, color)
        for y in (20, 40):
            image.rect(5, y, 23, 2, IRON[1])
            image.rect(5, y, 23, 1, IRON[0])
        for x, y in ellipse(16, 16, 9, 3):
            image.set(x, y, light if (x + y) % 4 else base)
    elif kind == "crate":
        plank_block(image, 4, 20, 25, 26, 7)
        for y in range(28, 45):
            image.set(4 + (y - 28) * 24 // 17, y, deep)
        image.rect(12, 6, 2, 16, rgba("aab3b8"))
        image.rect(10, 18, 6, 2, rgba("c9a24a"))
        image.rect(19, 9, 2, 13, rgba("6b4a2c"))
        image.rect(17, 8, 6, 3, IRON[0])
    elif kind == "strongbox":
        plank_block(image, 4, 24, 25, 22, 7, (rgba("6b5a46"), rgba("54473a"), rgba("3d342b"), rgba("2a241e")))
        for x in (6, 26):
            image.rect(x, 24, 2, 22, IRON[1])
        image.rect(4, 31, 25, 2, IRON[1])
        image.rect(14, 33, 5, 5, IRON[0])
        image.set(16, 35, OUTLINE)
        image.set(16, 36, OUTLINE)
    return image.outlined()


# ---------------------------------------------------------------- roofs and signs

# Roof materials: (light, base, dark, deep) for clay tiles, slate, and wooden shingles.
ROOF_MATERIALS = [
    tuple(rgba(c) for c in ("a0573b", "86472f", "673424", "46231a")),
    tuple(rgba(c) for c in ("67707a", "525a64", "3e444d", "2a2f36")),
    tuple(rgba(c) for c in ("8a6a45", "715436", "573f27", "3c2b1b")),
]


def roof_swatches(material):
    """Four 32x32 swatches the game rasterizes onto each building's roof (game/render/roof_art.gd):
    the near (south) slope, the far slope, the timber gable, and trim (ridge cap in rows 0-5,
    eave board in rows 8-12, chimney stone in rows 16-31). Slope courses and joints are 8 px."""
    light, base, dark, deep = ROOF_MATERIALS[material]

    def slope(shade):
        """8-px courses whose lower edge throws a shadow: barrel clay tiles, staggered slates,
        or grained wooden shingles."""
        image = Image(TILE, TILE)
        for y in range(TILE):
            course, level = y // 8, y % 8
            for x in range(TILE):
                if material == 0:  # clay: rounded barrel tiles in columns
                    along = x % 8
                    color = (dark, base, light, light, base, base, dark, deep)[along]
                    if level == 7:
                        color = deep
                    elif level == 6:
                        color = scale(color, 0.82)
                    elif level == 0:
                        color = scale(color, 1.1)
                    color = scale(color, 1.0 + ((hash_cell(x // 8, course) % 5) - 2) * 0.03)
                elif material == 1:  # slate: staggered rectangles with thin gaps
                    along = (x + (4 if course % 2 else 0)) % 8
                    color = base
                    if level == 7 or along == 0:
                        color = deep
                    elif level == 6:
                        color = dark
                    elif level == 0 or along == 1:
                        color = light
                    color = scale(color, 1.0 + ((hash_cell((x + (4 if course % 2 else 0)) // 8, course) % 5) - 2) * 0.04)
                else:  # wooden shingles: staggered, grain lines, ragged ends
                    offset = 3 if course % 2 else 0
                    along = (x + offset) % 8
                    ragged = hash_cell((x + offset) // 8, course) % 3
                    color = base
                    if along == 0:
                        color = deep
                    elif level >= 7 - (1 if ragged == 0 else 0):
                        color = deep
                    elif level == 6:
                        color = dark
                    elif along in (3, 6) and level % 3 != 1:
                        color = scale(base, 0.9)
                    elif level <= 1:
                        color = light
                image.set(x, y, scale(color, shade))
        return image

    gable = Image(TILE, TILE)
    wood = SIGN_WOOD
    for y in range(TILE):
        for x in range(TILE):
            board = x % 6
            color = wood[1]
            if board == 0:
                color = wood[2]
            elif board == 1:
                color = wood[0]
            if hash_cell(x // 6, y // 9) % 4 == 0 and y % 9 == 0:
                color = wood[2]
            gable.set(x, y, scale(color, 0.82))
    trim = Image(TILE, TILE)
    for x in range(TILE):
        cap = x % 6
        for y, color in enumerate((deep, dark if cap == 0 else scale(light, 1.1), dark if cap == 0 else light,
                                   dark if cap == 0 else base, dark, deep)):
            trim.set(x, y, color)
        for y, color in zip(range(8, 13), (deep, scale(dark, 0.9), scale(dark, 0.8), deep, OUTLINE)):
            trim.set(x, y, color)
    for y in range(16, 32):  # chimney stone: courses of 4 px, joints of 6
        for x in range(TILE):
            joint = (x + (3 if (y // 4) % 2 else 0)) % 6 == 0
            color = WALL_TOP[2] if y % 4 == 3 or joint else WALL_TOP[0]
            if (x * 5 + y * 3) % 17 == 0:
                color = WALL_TOP[1]
            trim.set(x, y, color)
    return [slope(1.0), slope(0.72), gable, trim]


def hash_cell(x, y):
    value = (x * 73856093) ^ (y * 19349663) ^ 0x5F3759DF
    return value & 0x7FFFFFFF


def roof_sheet():
    return sheet([swatch for material in range(len(ROOF_MATERIALS)) for swatch in roof_swatches(material)], 4, TILE)


SIGN_WOOD = (rgba("9a7348"), rgba("7d5a36"), rgba("5a3f25"))
SIGN_IRON = rgba("3b3a38")


def sign(kind):
    """A hanging board on an iron bracket (32x32, board centred), painted with what is
    sold inside: a red flask and a sword for a merchant, a coin stack for a banker."""
    light, base, dark = SIGN_WOOD
    image = Image(TILE, TILE)
    for x in range(4, 28):  # bracket
        image.set(x, 5, SIGN_IRON)
    image.set(4, 4, SIGN_IRON)
    image.set(27, 4, SIGN_IRON)
    for chain_x in (8, 23):
        for y in range(6, 10):
            image.set(chain_x, y, SIGN_IRON if y % 2 else rgba("5c5a55"))
    image.rect(4, 10, 24, 16, OUTLINE)
    image.rect(5, 11, 22, 14, dark)
    image.rect(6, 12, 20, 12, base)
    for y in range(12, 24, 3):  # plank seams and grain
        for x in range(6, 26):
            if (x * 7 + y * 3) % 11 == 0:
                image.set(x, y, light)
    for x in range(6, 26):
        image.set(x, 12, light)
        image.set(x, 23, dark)
    if kind == "vendor":
        image.template(8, 13, [
            "..ooo..",
            "..oco..",
            "..ogo..",
            ".oogoo.",
            "orrhrro",
            "orrrrro",
            "orrrrro",
            ".ooooo.",
        ], {"o": OUTLINE, "c": rgba("b08a5a"), "g": rgba("9fb7bf"), "r": rgba("a3332b"), "h": rgba("e07a62")})
        image.template(17, 12, [
            "...o.",
            "..owo",
            "..oso",
            "..oso",
            "..oso",
            "..oso",
            "ooooo",
            ".obo.",
            ".obo.",
            ".opo.",
        ], {"o": OUTLINE, "w": rgba("e2e6e8"), "s": rgba("aab3b8"), "b": rgba("6b4a2c"), "p": rgba("c9a24a")})
    else:
        gold, shine, shade = rgba("d4a73c"), rgba("f3d77a"), rgba("8f6a1e")
        for index, (cx, cy) in enumerate(((11, 20), (11, 17), (11, 14), (20, 20), (20, 17))):
            image.rect(cx - 4, cy - 1, 9, 3, OUTLINE)
            image.rect(cx - 3, cy - 1, 7, 2, gold)
            image.set(cx - 2, cy - 1, shine)
            image.set(cx - 1, cy - 1, shine)
            image.rect(cx - 3, cy + 1, 7, 1, shade)
        image.template(17, 12, [
            ".ooo.",
            "oyyyo",
            "oyoyo",
            "oyyyo",
            ".ooo.",
        ], {"o": OUTLINE, "y": rgba("f3d77a")})
    return image

# ---------------------------------------------------------------- output

def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--preview", type=Path, help="also write a 4x preview sheet to this path")
    args = parser.parse_args()
    root = ROOT / "assets" / "sprites"
    outputs = {
        "body.png": character_sheet(split_body("body"), compact=True, columns=POSE_COLUMNS),
        "cloth.png": character_sheet(split_body("cloth"), compact=True, columns=POSE_COLUMNS),
        "marker.png": character_sheet(marker, columns=POSE_COLUMNS),
        "items.png": sheet([item_icon(kind) for kind in ITEM_ORDER], len(ITEM_ORDER), TILE),
        "tiles.png": sheet([grass_tile(v) for v in range(4)] + [dirt_tile(v) for v in range(4)]
                           + [water_tile(f) for f in range(4)] + edge_set("dirt") + edge_set("shore")
                           + [sand_tile(v) for v in range(4)] + [cobble_tile(v) for v in range(4)]
                           + [plank_tile(False, 0), plank_tile(False, 1), plank_tile(True, 0), plank_tile(True, 1)]
                           + [dusk_tile(v) for v in range(4)] + [obsidian_tile(v) for v in range(4)]
                           + [cave_tile(v) for v in range(4)] + [stairs_tile(True), stairs_tile(False)]
                           + edge_set("sand"),
                           4, TILE),
        "objects.png": sheet_row([tree(v) for v in range(3)] + [dead_tree(v) for v in range(2)]
                                 + [desert_plant(v) for v in range(3)] + [waystone()]),
        "roofs.png": roof_sheet(),
        "signs.png": sheet_row([sign("vendor"), sign("banker")]),
        "torch.png": sheet_row([wall_torch(frame) for frame in range(4)]),
        "terrain_palette.png": terrain_palette(),
        "walls.png": sheet([wall(mask) for mask in range(16)] + [wall(mask, OBSIDIAN_STONE) for mask in range(16)]
                           + [wall(mask, CAVE_STONE) for mask in range(16)] + [thin_wall(mask) for mask in range(16)],
                           16, WALL),
        "furniture.png": sheet_row([furniture(kind) for kind in FURNITURE_KINDS]),
        **{f"gear/{kind}.png": character_sheet(GEAR_BUILDERS[item["slot"]](kind), compact=True, columns=POSE_COLUMNS)
           for kind, item in ITEMS.items() if item.get("slot") in VISIBLE_SLOTS},
        **{f"gear/{kind}_glow.png": None for kind, item in ITEMS.items()
           if item.get("glow") and item.get("slot") in VISIBLE_SLOTS},
        "items_glow.png": None,
        **{f"monsters/{name}_glow.png": None for name in ("golem", "wraith")},
        **{f"monsters/{name}.png": monster_sheet(builder, False)
           for name, builder in (("quadruped", quadruped), ("spider", spider), ("blob", blob), ("golem", golem), ("wraith", wraith))},
        **{f"monsters/{name}_detail.png": monster_sheet(builder, True)
           for name, builder in (("quadruped", quadruped), ("spider", spider), ("blob", blob), ("golem", golem), ("wraith", wraith))},
    }
    for name in [name for name, image in outputs.items() if image is None]:
        if name == "items_glow.png":
            icons = outputs["items.png"]
            glowing = Image(icons.width, icons.height)
            for index, kind in enumerate(ITEM_ORDER):
                if ITEMS[kind].get("glow"):
                    glowing.over(halo(icons.crop(index * TILE, 0, TILE, TILE)), index * TILE, 0)
            outputs[name] = glowing
        else:
            base = outputs[name.replace("_glow.png", ".png")]
            outputs[name] = framewise(base, FRAME, FRAME, halo)
    for name, image in outputs.items():
        image.save(root / name)
        print(f"wrote assets/sprites/{name} ({image.width}x{image.height})")
    if args.preview:
        write_preview(outputs, args.preview)


def dressed(outputs, equipment, direction, column, tint):
    """One 64x64 frame layered exactly like SpriteArt.draw_actor."""
    x, y = column * FRAME, DIRECTIONS.index(direction) * FRAME
    frame = Image(FRAME, FRAME)
    frame.rect(0, 0, FRAME, FRAME, GRASS[0])

    def put(name, color=None):
        part = outputs[name].crop(x, y, FRAME, FRAME)
        frame.over(part.tinted(color) if color else part)

    held, shield = equipment.get("main_hand"), equipment.get("off_hand")
    if held and direction == "up":
        put(f"gear/{held}.png")
    if shield and direction in ("left", "right"):
        put(f"gear/{shield}.png")
    put("body.png")
    put("cloth.png", tint)
    if equipment.get("cape") and direction != "up":
        put(f"gear/{equipment['cape']}.png")
    if equipment.get("armor"):
        put(f"gear/{equipment['armor']}.png")
    if equipment.get("cape") and direction == "up":
        put(f"gear/{equipment['cape']}.png")
    if equipment.get("helmet"):
        put(f"gear/{equipment['helmet']}.png")
    if shield and direction in ("down", "up"):
        put(f"gear/{shield}.png")
    if held and direction != "up":
        put(f"gear/{held}.png")
    return frame


def write_preview(outputs, path):
    """Every tier worn by each vocation (rows), plus all item icons, at 2x."""
    tiers = sorted({item["level"] for item in CATALOG if item.get("slot")})
    vocations = ("knight", "paladin", "sorcerer", "druid")
    tint = rgba("6a88a8")
    views = [("knight", "down"), ("knight", "left"), ("knight", "up")] + [(v, "down") for v in vocations[1:]] \
        + [("paladin", "left"), ("sorcerer", "left")]
    icons_per_row = 24
    icon_rows = (len(ITEM_ORDER) + icons_per_row - 1) // icons_per_row
    preview = Image(len(views) * 2 * FRAME, len(tiers) * 2 * FRAME + icon_rows * 2 * TILE + 8)
    preview.rect(0, 0, preview.width, preview.height, rgba("20262e"))
    for row, tier in enumerate(tiers):
        for column, (vocation, direction) in enumerate(views):
            equipment = {}
            for kind, item in ITEMS.items():
                slot = item.get("slot")
                if slot in VISIBLE_SLOTS and item["level"] == tier and vocation in item.get("vocations", [vocation]) \
                        and not item.get("loot_only"):
                    equipment[slot] = kind
            preview.over(dressed(outputs, equipment, direction, 0, tint).scaled(2), column * 2 * FRAME, row * 2 * FRAME)
    for index in range(len(ITEM_ORDER)):
        icon = outputs["items.png"].crop(index * TILE, 0, TILE, TILE)
        preview.over(icon.scaled(2), (index % icons_per_row) * 2 * TILE,
                     len(tiers) * 2 * FRAME + 8 + (index // icons_per_row) * 2 * TILE)
    preview.save(path)
    print(f"wrote preview {path}")

if __name__ == "__main__":
    main()
