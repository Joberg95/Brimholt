#!/usr/bin/env python3
"""Generate Brimholt's original pixel-art sprite sheets (Python standard library only).

Writes assets/sprites/*.png (not the item icons or character outfits: those come from the OpenTibia pack,
otsp_export.py). The marker and monster sheets use 64x64 frames:
five columns (stand, step A, step B, attack wind-up, strike; monsters only the first three)
and four rows (down, up, left, right), with the
tile centre at frame pixel (32, 40). Floor tiles are 32x32 cells; walls are
48x48 cells drawn 16 pixels up and left of their tile, indexed by open sides
(1 north, 2 west, 4 south, 8 east). objects.png holds 64x96 trees whose trunk base sits on
the tile centre at (32, 80). terrain_palette.png is the map editor's tile palette.

Re-running overwrites the sheets. Once a sheet has been edited by hand (for example in
Aseprite), treat that PNG as the source of truth and stop regenerating it.
"""

import argparse
import bisect
import json
import colorsys
import math
import re
import random
import struct
import zlib
from pathlib import Path

FRAME = 64
TILE = 32
WALL = 48
DIRECTIONS = ("down", "up", "left", "right")
ROOT = Path(__file__).resolve().parents[2]
# The item catalog shared with the game (colors are main/light/accent).
CATALOG = json.loads((ROOT / "game" / "data" / "items.json").read_text())["items"]
ITEMS = {item["id"]: item for item in CATALOG}
# Map editor palette order; must match TERRAINS in tools/generators/make_map.gd.
TERRAINS = (".", ",", "~", "#", "T", ":", "=", "b", "d", "o", "O", "D", "c", "C", "v", "^", "K", "R", "L", "W", "m", "U", "s", "P", "F", "Y")


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

    @staticmethod
    def load(path):
        """An 8-bit RGBA, non-interlaced PNG (what Godot's save_png writes)."""
        data = path.read_bytes()
        pos, chunks = 8, []
        while pos < len(data):
            length = struct.unpack(">I", data[pos:pos + 4])[0]
            chunks.append((data[pos + 4:pos + 8], data[pos + 8:pos + 8 + length]))
            pos += 12 + length
        width, height, depth, kind = struct.unpack(">IIBB", chunks[0][1][:10])
        if depth != 8 or kind != 6:
            raise ValueError(f"{path}: expected 8-bit RGBA")
        raw = zlib.decompress(b"".join(body for tag, body in chunks if tag == b"IDAT"))
        stride, at, previous = width * 4, 0, bytearray(width * 4)
        image = Image(width, height)
        for y in range(height):
            kind, row = raw[at], bytearray(raw[at + 1:at + 1 + stride])
            at += 1 + stride
            for x in range(stride):
                a = row[x - 4] if x >= 4 else 0
                b = previous[x]
                c = previous[x - 4] if x >= 4 else 0
                if kind == 1:
                    row[x] = (row[x] + a) & 255
                elif kind == 2:
                    row[x] = (row[x] + b) & 255
                elif kind == 3:
                    row[x] = (row[x] + (a + b) // 2) & 255
                elif kind == 4:
                    guess = a + b - c
                    pa, pb, pc = abs(guess - a), abs(guess - b), abs(guess - c)
                    row[x] = (row[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
            for x in range(width):
                pixel = tuple(row[x * 4:x * 4 + 4])
                if pixel[3] >= 128:
                    image.pixels[y][x] = pixel[:3] + (255,)
            previous = row
        return image

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


# The rig is authored tall and thin; compact_humanoid bakes it into the stocky outfitter build.
# Below the neck (rig y >= NECK) rows are squashed by BODY_SQUASH towards the feet at y=53; the
# head and anything worn on it keep full size, so the head is about a third of the figure.
# Rig columns WIDEN are drawn twice (two pixels wider through the head, chest and hips) while
# the outer columns, where the outlines run, move out by one: outlines stay one pixel thick.
NECK = 21
BODY_SQUASH = 0.8
WIDEN = (29, 34)


# Experiment (branch experiment/pack-paperdoll): the whole figure, head included, drawn THIN as wide
# (a fifth narrower), sampled about the rig's centre column instead of widened.
THIN = 0.8
THIN_CENTRE = 31.5


def _rig_x(x):
    """The rig column drawn at frame column x (the inverse of widening about x=32)."""
    if THIN:
        return round(THIN_CENTRE + (x - THIN_CENTRE) / THIN)
    left, right = WIDEN
    if x < left - 1:
        return x + 1
    if x <= left:
        return left
    if x > right + 1:
        return x - 1
    return min(x, right)


def _rig_y(y):
    neck = 53 + (NECK - 53) * BODY_SQUASH
    return round(53 + (y - 53) / BODY_SQUASH) if y >= neck else round(NECK - (neck - y))


def compact_humanoid(image):
    """Bake the same pixel-grid rig into every body/gear layer, with feet kept at y=53.

    No runtime scaling: silhouettes, grips, masks and cape holes all use this mapping;
    halos are generated afterwards. Monsters and the ground marker keep their own anatomy.
    """
    result = Image(FRAME, FRAME)
    for y in range(FRAME):
        source_y = _rig_y(y)
        for x in range(FRAME):
            result.set(x, y, image.get(_rig_x(x), source_y))
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
            frames.append(compact_humanoid(image) if compact and not getattr(builder, "compacted", False) else image)
    return sheet(frames, columns, FRAME)


# ---------------------------------------------------------------- characters
# 64x64 frames; the tile centre is frame pixel (32, 40) and feet rest near y 53, so
# Geometry is authored in a shared rig, then baked to a compact ~36-pixel silhouette.

POSE_COLUMNS = 5


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


LINEN = (rgba("b7ad96"), rgba("928974"), rgba("6b6454"))


def layer(points, tones, dither=True):
    image = Image(FRAME, FRAME)
    shade(image, points, tones, dither)
    return image


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


# ---------------------------------------------------------------- painted gear
# Items with a painted icon (assets/sprites/icons/<id>.png, imported from art/outfits by
# `make outfits`) wear it: the generated silhouette of each pose is filled from the icon, row by
# row, so the worn piece shows the icon's colours, trim, and pattern.


def _luma(color):
    return color[0] * 0.3 + color[1] * 0.59 + color[2] * 0.11


import palette as pal  # noqa: E402
import props  # noqa: E402
import pixel_coins  # noqa: E402
import pixel_floors  # noqa: E402


def coin_stage_icon(stage):
    """Gold coins at one stack-size stage (pixel_coins.STAGES)."""
    image = Image(TILE, TILE)
    image.pixels = pixel_coins.icon(stage)
    return image


# ---------------------------------------------------------------- icon finishing
# The coin, spell, and menu icons go through icon_finish on their way out: a single dark outline,
# a lit inner rim on the top-left and a shaded one on the bottom-right (the bevelled pop of
# classic item icons), and contrast stretched when an icon came out flat.

ICON_OUTLINE = rgba("181214")   # the outline next to grey or near-black parts
OUTLINE_LUMA = 72        # edge pixels darker than this already are outline
RIM = 0.16               # lighten / darken of the inner rim
CONTRAST_SPAN = 150      # luma range an icon's body should cover
SATURATION = 1.14


def _icon_outline(colors):
    """The master palette's outline (palette.outline) for an edge next to `colors`: the hue of the
    part it borders at near-black, so gold reads warm and steel cool; ICON_OUTLINE beside greys."""
    lit = [c for c in colors if c is not None and c[3] and _luma(c) >= OUTLINE_LUMA]
    if not lit:
        return ICON_OUTLINE
    r, g, b = (sum(c[i] for c in lit) / len(lit) for i in range(3))
    h, s, _ = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    if s < 0.12:
        return ICON_OUTLINE
    r, g, b = colorsys.hsv_to_rgb(h, min(0.6, s + 0.1), 0.09)
    return (round(r * 255), round(g * 255), round(b * 255), 255)


def _hls_shift(color, light=0.0, sat=1.0):
    h, l, s = colorsys.rgb_to_hls(*(c / 255 for c in color[:3]))
    l = max(0.0, min(1.0, l + light))
    s = max(0.0, min(1.0, s * sat))
    return tuple(round(c * 255) for c in colorsys.hls_to_rgb(h, l, s)) + (color[3],)


def icon_finish(icon, rim=True):
    """The shared finish for a 32x32 icon. rim=False leaves out the rim light and the saturation
    (for painted icons, which are finished in place and must not be lit twice); the outline and the
    contrast stretch are safe to repeat."""
    size = icon.width
    solid = {(x, y) for y in range(icon.height) for x in range(size) if icon.opaque(x, y)}
    if not solid:
        return icon
    near = lambda x, y: [(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
    edge = {p for p in solid if any(q not in solid for q in near(*p))}
    result = Image(size, icon.height)
    result.over(icon)
    inside = lambda x, y: [icon.pixels[qy][qx] for qx, qy in near(x, y) + [(x + 1, y + 1), (x - 1, y - 1),
                           (x + 1, y - 1), (x - 1, y + 1)] if (qx, qy) in solid]
    # One outline: dark edges become the outline, bright edges get one outside, each tinted by
    # the part it borders (_icon_outline).
    lines = set()
    for x, y in edge:
        if _luma(icon.pixels[y][x]) < OUTLINE_LUMA:
            result.pixels[y][x] = _icon_outline(inside(x, y))
            lines.add((x, y))
        else:
            for qx, qy in near(x, y):
                if (qx, qy) not in solid and 0 <= qx < size and 0 <= qy < icon.height:
                    result.pixels[qy][qx] = _icon_outline(inside(qx, qy))
                    lines.add((qx, qy))
    body = [p for p in solid if p not in edge or _luma(icon.pixels[p[1]][p[0]]) >= OUTLINE_LUMA]
    # Contrast: stretch a flat icon's body luma towards CONTRAST_SPAN, a little more saturated.
    lumas = sorted(_luma(icon.pixels[y][x]) for x, y in body)
    if lumas:
        low, high = lumas[len(lumas) // 20], lumas[-1 - len(lumas) // 20]
        span = max(1.0, high - low)
        gain = min(1.35, max(1.0, CONTRAST_SPAN / span))
        middle = (low + high) / 2
        for x, y in body:
            color = result.pixels[y][x]
            if color is None or (x, y) in lines:
                continue
            delta = (_luma(color) - middle) * (gain - 1.0) / 255
            result.pixels[y][x] = _hls_shift(color, delta, SATURATION if rim else 1.0)
    if rim:
        # The inner rim: lit where the outside is above or to the left, shaded below and right.
        for x, y in body:
            color = result.pixels[y][x]
            if color is None or (x, y) in lines or _luma(color) < OUTLINE_LUMA:
                continue
            outside = [(dx, dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                       if (x + dx, y + dy) not in solid or (x + dx, y + dy) in lines]
            if any(d in outside for d in ((-1, 0), (0, -1))):
                result.pixels[y][x] = _hls_shift(color, RIM)
            elif any(d in outside for d in ((1, 0), (0, 1))):
                result.pixels[y][x] = _hls_shift(color, -RIM)
    return result


# ---------------------------------------------------------------- terrain

# Grass in the OpenTibia manner: a living mid green (not olive), darker clumps, and blade tufts
# with lit tips; light from the top-left like the rock.
GRASS = (rgba("517433"), rgba("5d823b"), rgba("44642a"), rgba("7a9d4c"), rgba("33501f"))
DIRT = (rgba("80725c"), rgba("766851"), rgba("92816a"), rgba("625944"))
WATER = (rgba("354b50"), rgba("49666a"), rgba("688281"), rgba("293e44"), rgba("30464b"))
FLOWERS = (rgba("beb793"), rgba("b3a56b"), rgba("a9999b"))


def grass_tile(variant):
    """Seamless grass: soft clumps of lighter and darker green, then many small tufts of two or
    three blades (a dark root, a mid blade, a lit tip leaning right), and on two variants a few
    clover leaves or tiny flowers. Everything wraps at the tile edge so no grid shows."""
    rng = random.Random(100 + variant)
    image = Image(TILE, TILE)
    image.rect(0, 0, TILE, TILE, GRASS[0])
    for _ in range(14):
        x, y = rng.randrange(TILE), rng.randrange(TILE)
        tone = GRASS[rng.choice((1, 2, 2))]
        for px, py in ellipse(x, y, rng.randrange(3, 6), rng.randrange(2, 4)):
            image.set(px % TILE, py % TILE, tone)
    for _ in range(46):
        x, y = rng.randrange(TILE), rng.randrange(TILE)
        for blade in range(rng.choice((2, 3, 3))):
            bx = x + blade * 2 - 2
            height = rng.choice((2, 3, 3, 4))
            image.set(bx % TILE, y % TILE, GRASS[4])
            for step in range(1, height):
                tone = GRASS[3] if step == height - 1 else GRASS[1]
                image.set((bx + step // 3) % TILE, (y - step) % TILE, tone)
    if variant == 2:
        for _ in range(3):
            x, y = rng.randrange(TILE), rng.randrange(TILE)
            for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
                image.set((x + dx) % TILE, (y + dy) % TILE, GRASS[3] if dx + dy < 2 else GRASS[1])
    if variant == 3:
        for _ in range(3):
            x, y = rng.randrange(3, 28), rng.randrange(3, 28)
            petal = rng.choice(FLOWERS)
            image.set(x, y, petal)
            image.set(x + 1, y, petal)
            image.set(x, y + 1, FLOWERS[1])
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


def floor_tile(kind, variant=0):
    """One hand-pixelled floor tile from pixel_floors.py as an Image."""
    image = Image(TILE, TILE)
    image.pixels = pixel_floors.tile(kind, variant)
    return image


SAND = (rgba("ac9c76"), rgba("9d8e6b"), rgba("c0ae86"), rgba("837759"))
COBBLE = (rgba("787971"), rgba("97988b"), rgba("63665f"), rgba("484e47"))
PLANK = (rgba("76634b"), rgba("948063"), rgba("5e513f"), rgba("3d382c"))
LEAF = (rgba("798054"), rgba("525f3a"), rgba("303f2a"))


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
    """A stairway set in the floor, framed by a stone lip lit from the top-left. Going down ("v",
    a town cellar), the steps drop away into darkness and the shaded far wall of the shaft shows
    above them; going up ("^"), they climb toward the light."""
    image = Image(TILE, TILE)
    bevel(image, box(0, 0, TILE, TILE), COBBLE[1], COBBLE[0], COBBLE[3])
    # Ashlar joints in the lip so it reads as dressed stone.
    for x in (9, 21):
        image.set(x, 1, COBBLE[2])
        image.set(x + 2, TILE - 2, COBBLE[2])
    for y in (10, 22):
        image.set(1, y, COBBLE[2])
        image.set(TILE - 2, y + 1, COBBLE[2])
    image.rect(3, 3, 26, 26, OUTLINE)
    if down:
        image.rect(4, 4, 24, 24, rgba("15130f"))
        # The far wall of the shaft, in shadow, then steps dropping into the dark.
        image.rect(4, 4, 24, 3, scale(COBBLE[3], 0.7))
        image.rect(4, 7, 24, 1, scale(COBBLE[3], 0.45))
        for step in range(5):
            y = 8 + step * 4
            shade = (4 - step) / 4
            image.rect(5, y, 22, 2, scale(COBBLE[1], 0.2 + 0.75 * shade))
            image.rect(5, y + 2, 22, 1, scale(COBBLE[2], 0.15 + 0.55 * shade))
            image.rect(5, y + 3, 22, 1, rgba("15130f"))
        # The left side wall throws its shadow over the steps.
        for y in range(8, 28):
            image.set(4, y, rgba("15130f"))
            image.set(5, y, scale(image.get(5, y), 0.6))
    else:
        for step in range(6):
            y = 4 + step * 4
            shade = (step + 1) / 6
            image.rect(4, y, 24, 3, scale(COBBLE[1], 0.25 + 0.75 * shade))
            image.rect(4, y + 3, 24, 1, scale(COBBLE[2], 0.2 + 0.6 * shade))
    return image


# The swamp of Mirewood Fen (tools/generators/swamp.gd): dark peaty mud and giant mushrooms.
BOG = (rgba("4a4632"), rgba("3e3a28"), rgba("585338"), rgba("2c2a1c"), rgba("5a6a3a"))


def bog_tile(variant):
    """Bog mud ("m"): dark peat with wet glints, reed stubble, and a few murky puddles; seamless."""
    rng = random.Random(6100 + variant)
    image = Image(TILE, TILE)
    image.rect(0, 0, TILE, TILE, BOG[0])
    for _ in range(16):
        x, y = rng.randrange(TILE), rng.randrange(TILE)
        for px, py in ellipse(x, y, rng.randrange(2, 6), rng.randrange(1, 3)):
            image.set(px % TILE, py % TILE, BOG[rng.choice((1, 1, 2))])
    if variant in (1, 3):
        x, y = rng.randrange(6, 24), rng.randrange(8, 24)
        for px, py in ellipse(x, y, 5, 2.5):
            image.set(px, py, rgba("2e3428"))
        for px in range(x - 3, x + 2):
            image.set(px, y - 1, rgba("6a7468"))
    for _ in range(18):
        x, y = rng.randrange(TILE), rng.randrange(TILE)
        image.set(x, y, BOG[3])
        image.set(x % TILE, (y - 1) % TILE, BOG[4])
        if rng.random() < 0.5:
            image.set(x % TILE, (y - 2) % TILE, BOG[4])
    return image


def mushroom(variant):
    """A giant swamp mushroom ("U", in place of trees in Mirewood Fen): 64x96 like the trees, the
    stem's foot on the tile centre at (32, 80). A pale fibrous stem flaring into a cup at the
    foot, a broad cap lit from the top-left with darker spots and a shaded rim, the gills dark
    under it. Caps: dull teal, violet, and rust."""
    rng = random.Random(7100 + variant)
    caps = (pal.BOG_WATER[0:4], pal.HOLLOW[1:5], pal.BRONZE[2:6])[variant]
    stem = (pal.BONE[0], pal.BONE[1], pal.BONE[3], pal.BONE[5])
    image = Image(FRAME, 96)
    for x, y in ellipse(32, 82, 15, 4):
        image.set(x, y, SHADOW)
    body = Image(FRAME, 96)
    top = 34 + variant * 3
    for y in range(top, 81):
        half = 4 + (2 if y > 74 else 0) + (1 if y > 78 else 0)
        for x in range(32 - half, 32 + half):
            across = x - (32 - half)
            tone = 0 if across < 2 else 1 if across < half + 1 else 2 if across < half * 2 - 1 else 3
            if (x * 5 + y // 2) % 7 == 0:
                tone = min(3, tone + 1)
            body.set(x, y, stem[tone])
    rx, ry = 22 - variant, 14
    cy = top - 2
    cap = {p for p in ellipse(32, cy, rx, ry) if p[1] <= cy + 4}
    for x, y in cap:
        nx, ny = (x - 32) / rx, (y - cy) / ry
        light = -(nx * 0.6 + ny * 0.8)
        tone = 0 if light > 0.55 else 1 if light > 0.0 else 2 if light > -0.5 else 3
        if y >= cy + 2:
            tone = 3
        body.set(x, y, caps[tone])
    for x in range(32 - rx + 3, 32 + rx - 2):
        body.set(x, cy + 5, stem[3])
        if x % 3 == 0:
            body.set(x, cy + 6, stem[2])
    for _ in range(7):
        sx, sy = rng.randrange(32 - rx + 6, 32 + rx - 6), rng.randrange(cy - ry + 4, cy)
        if (sx, sy) in cap:
            for px, py in ellipse(sx, sy, 2, 1.4):
                if (px, py) in cap:
                    body.set(px, py, stem[0] if variant == 2 else blend(caps[0], stem[0], 0.6))
    image.over(body.outlined(pal.outline((pal.BOG_WATER, pal.HOLLOW, pal.BRONZE)[variant])))
    return image


# ---------------------------------------------------------------- the frost isles

# Snow: base, lit drift tops, blue shadow, deep shadow, sparkle.
SNOW = (rgba("e4ebf2"), rgba("f6f9fc"), rgba("c4d0de"), rgba("a2b2c6"), rgba("ffffff"))


def snow_tile(variant):
    """Snow ("s", the frost isles' ground): soft drifts lit from the top-left with cool blue
    shadows on their lower sides, a few wind ripples, and sparkles; seamless."""
    rng = random.Random(6400 + variant)
    image = Image(TILE, TILE)
    image.rect(0, 0, TILE, TILE, SNOW[0])
    for _ in range(7):
        x, y = rng.randrange(TILE), rng.randrange(TILE)
        rx, ry = rng.randrange(4, 9), rng.randrange(2, 4)
        for px, py in ellipse(x, y, rx, ry):
            image.set(px % TILE, py % TILE, SNOW[1] if py < y else SNOW[0])
        for px in range(x - rx + 1, x + rx - 1):
            image.set(px % TILE, (y + ry) % TILE, SNOW[2])
            if rng.random() < 0.4:
                image.set(px % TILE, (y + ry + 1) % TILE, SNOW[3] if rng.random() < 0.3 else SNOW[2])
    for _ in range(3):
        x, y = rng.randrange(TILE), rng.randrange(TILE)
        for step in range(rng.randrange(5, 10)):
            image.set((x + step) % TILE, (y + (step // 3)) % TILE, SNOW[2])
    for _ in range(6):
        image.set(rng.randrange(TILE), rng.randrange(TILE), SNOW[4])
    return image


def snowy_fir(variant):
    """A snow-laden fir ("P", the frost isles' tree): 64x96 like the trees, the trunk's foot on the
    tile centre at (32, 80). Tiers of dark drooping boughs, each loaded with snow on its upper face
    and lit from the top-left, the tip a narrow spire."""
    rng = random.Random(6600 + variant)
    needles = (pal.FIR[3], pal.FIR[4], pal.FIR[5], pal.FIR[6])
    bark = (pal.DARK_WOOD[1], pal.DARK_WOOD[3])
    snow = (pal.SNOW[1], pal.SNOW[0], pal.SNOW[3])
    image = Image(FRAME, 96)
    for x, y in ellipse(32, 82, 14, 4):
        image.set(x, y, SHADOW)
    body = Image(FRAME, 96)
    for y in range(70, 81):
        for x in range(30, 35):
            body.set(x, y, bark[0] if x < 32 else bark[1])
    # Variants differ in build, not just size: a full fir, a tall slender one, a squat broad one.
    top, tiers, spread, base = ((6, 5, 4, 7), (2, 6, 3, 5), (16, 4, 5, 9))[variant]
    height = 72 - top
    for tier in range(tiers):
        t0 = top + tier * height // (tiers + 1)
        t1 = t0 + height // (tiers + 1) + 8
        width = base + tier * spread + rng.randrange(-1, 2)
        for y in range(t0, t1):
            share = (y - t0) / max(1, t1 - t0)
            half = int(2 + share * width)
            droop = int(share * share * 3)
            for x in range(32 - half, 32 + half + 1):
                across = (x - 32) / max(1, half)
                tone = 1 if across < -0.2 else 2 if across < 0.45 else 3
                if share > 0.85:
                    tone = 3
                body.set(x, y + droop * (1 if abs(across) > 0.6 else 0), needles[tone])
            # Snow on the upper face of the tier: thick on the lit left, thinning to the right.
            if share < 0.5:
                for x in range(32 - half, 32 + half + 1):
                    across = (x - 32) / max(1, half)
                    if across < 0.55 and (share < 0.3 or rng.random() < 0.7):
                        body.set(x, y, snow[0] if across < -0.1 else snow[1] if across < 0.3 else snow[2])
    for _ in range(6):
        x, y = rng.randrange(20, 44), rng.randrange(top + 6, 70)
        if body.get(x, y) in needles:
            body.set(x, y, snow[1])
    image.over(body.outlined(pal.outline(pal.FIR)))
    return image


# Log walls in the frost isles: the house-wall shapes in timber courses under a cap of snow.
LOG_WOOD = ((pal.SNOW[0], pal.SNOW[1], pal.SNOW[2], pal.SNOW[4]),
            (pal.OAK[4], pal.OAK[6], pal.OAK[3]),
            (pal.OAK[5], pal.OAK[7], pal.OAK[4]))


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


DEAD_BARK = (pal.HOLLOW[3], pal.HOLLOW[4], pal.HOLLOW[6])


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
        # Limbs two to three px thick, forking into twigs two px thick, so every part keeps an outline.
        wood |= thick(line(x0, y0, x1, y1), ((0, 0), (1, 0), (0, 1)))
        for twig in range(2):
            tx, ty = x1 + rng.randrange(-6, 7), y1 - rng.randrange(3, 9)
            wood |= thick(line(x1, y1, tx, ty), ((0, 0), (1, 0)))
    trunk = Image(FRAME, 96)
    shade(trunk, wood, DEAD_BARK, False)
    for x, y in sorted(wood):
        if (x * 7 + y * 3) % 11 == 0 and (x + 1, y) in wood:
            trunk.set(x, y, DEAD_BARK[2])  # a split in the bark
    image.over(trunk.outlined(pal.outline(pal.HOLLOW)))
    for _ in range(3):
        x, y = rng.choice(sorted(p for p in wood if p[1] < 50))
        image.set(x, y - 1, pal.HOLLOW_GLOW[1])
    return image


CACTUS = (pal.BOG[0], pal.BOG[1], pal.BOG[3])
SPINE = pal.BONE[1]
THORN_WOOD = (pal.DIRT[1], pal.DIRT[3], pal.DIRT[5])


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
        plant.set(27, 66, pal.SKIN[2])
        plant.set(28, 66, pal.SKIN[1])
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
    image.over(plant.outlined(pal.outline(pal.BOG if variant < 2 else pal.DIRT)))
    return image


# A palm's crown (the master palette's FOLIAGE) and ringed trunk (OAK).
PALM_TOPS = ((41, 30), (23, 32), (35, 20))


def palm(variant):
    """A date palm (trees in Sunreach, Biomes.SUNREACH; palms.png), in the 64x96 tree cell with the
    trunk's foot on the tile centre at (32, 80): a leaning trunk of stacked rings lit on its left,
    a crown of long arching fronds whose leaflets hang from the spine, dark under the crown, and a
    cluster of dates. Variants lean right, lean left, and stand tall."""
    rng = random.Random(7700 + variant)
    image = Image(FRAME, 96)
    for x, y in ellipse(32, 81, 11, 3):
        image.set(x, y, SHADOW)
    top_x, top_y = PALM_TOPS[variant]
    bend_x = 32 + (top_x - 32) * 0.2
    trunk = Image(FRAME, 96)
    wood = pal.OAK
    steps_ = 80 - top_y
    for i in range(steps_ + 1):
        t = i / steps_
        # A quadratic curve from the foot up to the crown: the lean grows toward the top.
        cx = (1 - t) ** 2 * 32 + 2 * (1 - t) * t * bend_x + t * t * top_x
        cy = 80 - i
        half = 3.6 - 1.4 * t + (0.8 if i < 3 else 0.0)
        ring = (i + variant) % 4 == 0
        for x in range(int(cx - half - 1), int(cx + half + 2)):
            across = (x + 0.5 - cx) / half
            if abs(across) > 1.0:
                continue
            tone = 2 if across < -0.35 else 3 if across < 0.35 else 4
            if ring:
                tone = min(6, tone + 2)
            elif (i + variant) % 4 == 1 and across < 0.2:
                tone = max(1, tone - 1)  # the lit lip of each ring
            trunk.set(x, int(cy), wood[tone])
    image.over(trunk.outlined(pal.outline(wood)))
    crown = Image(FRAME, 96)
    leaf = pal.FOLIAGE
    # Fronds: (angle in degrees, 0 = east, counter-clockwise; length). The ones reaching back
    # (upward) are drawn first and darker; those hanging toward the viewer last.
    fronds = [(100, 15), (60, 17), (140, 17), (20, 21), (165, 21), (-15, 20), (195, 19), (-50, 15), (230, 15)]
    fronds.sort(key=lambda frond: math.sin(math.radians(frond[0])), reverse=True)
    for index, (angle, length) in enumerate(fronds):
        angle += rng.uniform(-8, 8)
        length += rng.randrange(-1, 2)
        dx, dy = math.cos(math.radians(angle)), -math.sin(math.radians(angle))
        back = dy < -0.3
        lit = dx < 0.2 and dy < 0.5
        spine = []
        for k in range(int(length * 2) + 1):
            t = k / (length * 2)
            # Out along the frond, rising a little first and then drooping under its own weight.
            x = top_x + dx * length * t
            y = top_y - 1 + dy * length * t * 0.7 - 4 * t + 13 * t * t
            spine.append((x, y, t))
        for x, y, t in spine:
            reach = (1.0 - t) * 4.6 + 1.0
            for side in (-1, 1):
                for r in range(1, int(reach) + 1):
                    # Leaflets slant toward the tip and hang down.
                    lx = x + (-dy * side) * r * 0.7 + dx * r * 0.45
                    ly = y + (dx * side) * r * 0.5 + r * 0.75
                    tone = 1 if lit else 3
                    if back:
                        tone += 1
                    if side == 1 and dy > -0.3:
                        tone += 1
                    if r == int(reach):
                        tone += 1
                    if _grain(int(lx), int(ly), 71 + variant) < 0.12:
                        tone -= 1
                    crown.set(int(round(lx)), int(round(ly)), leaf[max(0, min(6, tone))])
            crown.set(int(round(x)), int(round(y)), leaf[0 if lit and not back else 2])
    # Dates under the crown, and the shade it throws on the trunk's top.
    for ox, oy in ((-2, 3), (1, 4), (3, 2), (-1, 5)):
        for x, y in ellipse(top_x + ox, top_y + oy, 1.4, 1.4):
            crown.set(x, y, pal.BRONZE[3] if (x + y) % 3 else pal.BRONZE[1])
    image.over(crown.outlined(pal.outline(leaf)))
    return image


ROCK = (pal.ROCK[1], pal.ROCK[2], pal.ROCK[4], pal.ROCK[6])
MOSS = (pal.MOSS[1], pal.MOSS[2])


def boulder(variant):
    """Field rocks in the 64x96 tree cell, base on the tile centre at (32, 80): 0 a rounded
    boulder, 1 a pair of rocks, 2 a flat mossy slab. Lit from the top-left like walls."""
    image = Image(FRAME, 96)
    rocks = {0: [(32, 72, 12, 10)], 1: [(27, 75, 9, 7), (40, 78, 6, 4)], 2: [(32, 76, 14, 6)]}[variant]
    for x, y in ellipse(32, 82, 15, 3.5):
        image.set(x, y, SHADOW)
    stone = Image(FRAME, 96)
    for cx, cy, rx, ry in rocks:
        points = ellipse(cx, cy, rx, ry) - {(x, y) for x in range(FRAME) for y in range(96) if y > cy + ry * 0.6 and abs(x - cx) > rx * 0.8}
        for x, y in sorted(points):
            light = (cx - x) / rx * 0.45 + (cy - y) / ry * 0.6
            facet = ((x // 4 * 5 + y // 3 * 3 + variant) % 5 - 2) * 0.08
            value = light + facet
            tone = ROCK[0] if value > 0.45 else ROCK[1] if value > 0.0 else ROCK[2] if value > -0.45 else ROCK[3]
            if (x * 13 + y * 7) % 29 == 0:
                tone = scale(tone, 0.88)
            stone.set(x, y, tone)
        for x, y in sorted(points):
            if (x - cx + y - cy) % 9 == 0 and (x, y - 1) in points and abs(x - cx) < rx - 2:
                stone.set(x, y, ROCK[3])
        if variant == 2 or variant == 0:
            for x, y in sorted(points):
                if y < cy - ry * 0.35 and (x * 7 + y * 3) % 4 != 0 and (x < cx + 2 or variant == 2):
                    stone.set(x, y, MOSS[(x + y) % 2])
    image.over(stone.outlined(pal.outline(pal.ROCK)))
    return image


TREE_LEAF = tuple(pal.FOLIAGE[1:7])
TREE_LEAF_LINE = pal.outline(pal.FOLIAGE)
TREE_PINE = tuple(pal.FIR[0:6])
TREE_PINE_LINE = pal.outline(pal.FIR)
TREE_BARK = tuple(pal.OAK[3:7])
TREE_BARK_LINE = pal.outline(pal.OAK)


def tree(variant):
    """64x96 cell; the trunk base sits on the tile centre at (32, 80). Variants 0 and 1 are broadleaf
    trees, 2 a pine. Drawn like the mountain rock: clusters lit from the top-left on a six-tone ramp
    (warm lights, cool shadows), dark gaps between leaf clumps or needle tiers, and a dark outline
    in the foliage's own darkest hue."""
    rng = random.Random(1000 + variant)
    image = Image(FRAME, 96)
    for x, y in ellipse(32, 82, 16, 4):
        image.set(x, y, SHADOW)
    pine = variant == 2
    ramp, line_ = (TREE_PINE, TREE_PINE_LINE) if pine else (TREE_LEAF, TREE_LEAF_LINE)
    # The trunk: lit on its left, bark furrows, a root flare, and (broadleaf) two limbs into the crown.
    trunk = Image(FRAME, 96)
    wood = set()
    for y in range(44 if not pine else 58, 81):
        half = 3 + (1 if y > 74 else 0) + (1 if y > 78 else 0)
        wood |= box(32 - half, y, half * 2, 1)
    if not pine:
        for a, b in [((30, 58), (22, 44)), ((34, 55), (43, 42))]:
            wood |= thick(line(*a, *b), ((0, 0), (1, 0), (0, 1)))
    for x, y in wood:
        across = x - 32
        tone = 0 if across < -1 else 1 if across < 2 else 2
        if (x * 7 + y // 3 + variant) % 6 == 0:
            tone = min(3, tone + 1)  # a furrow in the bark
        trunk.set(x, y, TREE_BARK[tone])
    image.over(trunk.outlined(TREE_BARK_LINE))
    crown = Image(FRAME, 96)
    if not pine:
        lobes = [(32, 38, 20, 19), (20, 47, 12, 10), (44, 47, 12, 10), (24, 26, 12, 11), (41, 27, 12, 11), (32, 17, 11, 9)]
        if variant == 1:
            lobes = [(32, 40, 18, 18), (19, 44, 10, 11), (45, 42, 10, 12), (27, 24, 13, 12), (40, 22, 11, 10), (33, 12, 8, 7)]
        mask = set()
        for cx, cy, rx, ry in lobes:
            mask |= ellipse(cx + rng.randrange(-1, 2), cy + rng.randrange(-1, 2), rx, ry)
        # Leaf clumps: each pixel belongs to its nearest clump centre; clumps are lit on their
        # upper left, with dark gaps where two clumps meet.
        centres = []
        while len(centres) < 19:
            x, y = rng.randrange(10, 55), rng.randrange(6, 60)
            if (x, y) in mask and all((x - a) ** 2 + (y - b) ** 2 > 42 for a, b in centres):
                centres.append((x, y))
        top = min(y for _, y in mask)
        bottom = max(y for _, y in mask)
        for x, y in sorted(mask):
            dist = sorted(((x - a) ** 2 + (y - b) ** 2, a, b) for a, b in centres)
            first, ax, ay = dist[0]
            second = dist[1][0]
            radius = 7.5
            nx, ny = (x - ax) / radius, (y - ay) / radius
            # The crown is lit as one mass from the top-left; each clump only adds a soft swell,
            # and leaves show as 2 px flecks, so the crown reads as foliage, not pillows.
            light = -(nx * 0.45 + ny * 0.6) * 0.55 + (32 - x) / 22 * 0.5 + (bottom - y) / (bottom - top) * 0.75 - 0.3
            light += (_grain(x // 2, y // 2, 23 + variant) - 0.5) * 0.45
            tone = 0 if light > 0.75 else 1 if light > 0.35 else 2 if light > 0.0 else 3 if light > -0.4 else 4
            if math.sqrt(second) - math.sqrt(first) < 1.1 and nx + ny > -0.3:
                tone = min(5, max(tone + 2, 3))  # the shade a clump throws on its lower right
            crown.set(x, y, ramp[tone])
        # A leafy edge: bite a few pixels out and scatter single leaves just outside.
        for x, y in sorted(mask):
            edge = any((x + dx, y + dy) not in mask for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if edge and _grain(x, y, 31 + variant) < 0.3:
                crown.clear(x, y)
        for x, y in sorted(mask):
            for dx, dy in ((-1, -1), (1, -1), (-1, 1)):
                if (x + dx, y + dy) not in mask and _grain(x, y, 41 + variant) < 0.05:
                    crown.set(x + dx, y + dy, ramp[1] if dy < 0 else ramp[3])
        # Branches show in a few gaps low in the crown.
        for x, y in sorted(mask):
            if y > bottom - 14 and crown.get(x, y) == ramp[5] and _grain(x, y, 53) < 0.35:
                crown.set(x, y, TREE_BARK[3])
    else:
        # A pine: tiers of drooping boughs, each wider than the one above, lit on the left, dark
        # under the tier above, with a ragged hem of needle tips.
        tiers = [(8, 20, 6), (15, 29, 9), (22, 39, 12), (30, 49, 15), (39, 60, 18), (48, 68, 20)]
        for index, (top, bottom, width) in enumerate(tiers):
            for y in range(top, bottom + 1):
                share = (y - top) / max(1, bottom - top)
                half = width * (0.25 + 0.75 * share)
                for x in range(32 - int(half) - 1, 32 + int(half) + 2):
                    off = abs(x + 0.5 - 32)
                    droop = bottom - (off / max(1.0, half)) * 3.5  # the bough tips hang lower
                    if off > half or y > droop + (_grain(x, index, 61) * 3.0):
                        continue
                    light = (32 - x) / max(4.0, half) * 0.6 + (1.0 - share) * 0.5 - 0.2
                    light += (0.25 if (x + y) % 3 == 0 and x < 32 else 0.0) - (0.2 if (x - y) % 4 == 0 and x > 32 else 0.0)
                    tone = 0 if light > 0.7 else 1 if light > 0.35 else 2 if light > 0.0 else 3 if light > -0.35 else 4
                    if share < 0.22 and index > 0 and off < half * 0.75:
                        tone = min(5, tone + 2)  # in the shadow of the tier above
                    crown.set(x, y, ramp[tone])
        crown.set(32, 6, ramp[1])
        crown.set(32, 7, ramp[2])
    image.over(crown.outlined(line_))
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
    rock_tile = grass_tile(1)
    rock_tile.over(boulder(0).crop(16, 56, TILE, TILE))
    dead_tile = dusk_tile(1)
    dead_tile.over(dead_tree(0).crop(16, 48, TILE, TILE))
    tiles = {".": grass_tile(0), ",": dirt_tile(0), "~": water_tile(0), "#": wall_tile, "T": tree_tile,
             ":": sand_tile(0), "=": cobble_tile(0), "b": plank_tile(False, 0), "d": dusk_tile(0),
             "o": obsidian_tile(0), "O": wall(0, OBSIDIAN_STONE).crop(0, 0, TILE, TILE), "D": dead_tile,
             "c": cave_tile(0), "C": wall(0, CAVE_STONE).crop(0, 0, TILE, TILE),
             "v": stairs_tile(True), "^": stairs_tile(False), "K": cactus_tile, "R": rock_tile,
             "L": mountain(0, 0).crop(0, 0, TILE, TILE),
             "W": castle_block(0, False).crop(CASTLE_PAD, CASTLE_PAD, TILE, TILE)}
    tiles["C"] = mountain(15, 4).crop(0, 0, TILE, TILE)
    tiles["m"] = bog_tile(0)
    mushroom_tile = bog_tile(1)
    mushroom_tile.over(mushroom(0).crop(16, 52, TILE, TILE))
    tiles["U"] = mushroom_tile
    tiles["s"] = snow_tile(0)
    fir_tile = snow_tile(1)
    fir_tile.over(snowy_fir(0).crop(16, 52, TILE, TILE))
    tiles["P"] = fir_tile
    tiles["F"] = floor_tile("flags", 0)
    tiles["Y"] = floor_tile("carpet", 15)
    return sheet([tiles[terrain] for terrain in TERRAINS], len(TERRAINS), TILE)


# Grey town stone (house walls, walls.png rows 0 and 3) from the master palette's ROCK ramp:
# (top, lit top, dark top, top edge), (south face, mortar, lit course), (east face, mortar, lit).
WALL_TOP = (pal.ROCK[2], pal.ROCK[1], pal.ROCK[3], pal.ROCK[4])
WALL_SOUTH = (pal.ROCK[4], pal.ROCK[6], pal.ROCK[3])
WALL_EAST = (pal.ROCK[5], pal.ROCK[7], pal.ROCK[4])
STONE = (WALL_TOP, WALL_SOUTH, WALL_EAST)
STONE_LINE = pal.outline(pal.ROCK)
# Obsidian walls of the Hollow Sanctum: the same oblique shape in violet-black glassy stone.
OBSIDIAN_STONE = ((pal.HOLLOW[4], pal.HOLLOW[3], pal.HOLLOW[5], pal.HOLLOW[2]),
                  (pal.HOLLOW[5], pal.HOLLOW[6], pal.HOLLOW[4]),
                  (pal.HOLLOW[6], pal.HOLLOW[7], pal.HOLLOW[5]))
# Raw rock walls of the deep mine.
CAVE_STONE = ((pal.CAVE_ROCK[2], pal.CAVE_ROCK[1], pal.CAVE_ROCK[3], pal.CAVE_ROCK[0]),
              (pal.CAVE_ROCK[4], pal.CAVE_ROCK[5], pal.CAVE_ROCK[3]),
              (pal.CAVE_ROCK[5], pal.CAVE_ROCK[6], pal.CAVE_ROCK[4]))
# Cellar walls (dungeons with "theme": "cellar"): dark red-brown brick, as in Tibia's cellars.
CELLAR_STONE = ((pal.BRICK[3], pal.BRICK[2], pal.BRICK[4], pal.BRICK[1]),
                (pal.BRICK[4], pal.BRICK[6], pal.BRICK[3]),
                (pal.BRICK[5], pal.BRICK[7], pal.BRICK[4]))


def wall(mask, stone=None, line=None):
    WALL_TOP, WALL_SOUTH, WALL_EAST = stone or STONE
    OUTLINE = line or STONE_LINE
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


# Mountain rock: cool greys from highlight to crevice.
CRAG = (pal.ROCK[2], pal.ROCK[3], pal.ROCK[5], pal.ROCK[6], pal.ROCK[7])
CRAG_LINE = pal.outline(pal.ROCK)
GRAVEL = (rgba("7c7a74"), rgba("6c6a65"), rgba("8e8c85"), rgba("5a5854"), rgba("9c9a92"))


def boulder_shape(rng, cx, cy, rx, ry):
    """An irregular rounded boulder: an ellipse whose radius wobbles with the angle."""
    lobes = [rng.uniform(0.82, 1.08) for _ in range(7)]
    points = set()
    for y in range(int(cy - ry) - 2, int(cy + ry) + 3):
        for x in range(int(cx - rx) - 2, int(cx + rx) + 3):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            angle = (math.atan2(dy, dx) / (2 * math.pi) + 1) % 1 * 7
            low = int(angle)
            wobble = lobes[low] + (lobes[(low + 1) % 7] - lobes[low]) * (angle - low)
            if dx * dx + dy * dy <= wobble * wobble:
                points.add((x, y))
    return points


def paint_boulder(image, points, cx, cy, rx, ry, seed):
    """Faceted stone: lit from the top-left, darker toward the bottom-right, with a few crack
    lines and a dark outline."""
    rng = random.Random(seed)
    facets = [(cx + rng.uniform(-rx, rx) * 0.6, cy + rng.uniform(-ry, ry) * 0.6) for _ in range(3)]
    for x, y in points:
        light = (cx - x) / rx * 0.55 + (cy - y) / ry * 0.75
        nearest = min(range(len(facets)), key=lambda k: (x - facets[k][0]) ** 2 + (y - facets[k][1]) ** 2)
        light += (-0.18, 0.0, 0.16)[nearest]
        tone = 0 if light > 0.55 else 1 if light > 0.1 else 2 if light > -0.3 else 3 if light > -0.7 else 4
        if (x * 13 + y * 7 + seed) % 31 < 2:
            tone = min(4, tone + 1)
        image.set(x, y, CRAG[tone])
    # Facet edges: where the nearest facet changes, a darker seam on the lower side.
    for x, y in points:
        here = min(range(3), key=lambda k: (x - facets[k][0]) ** 2 + (y - facets[k][1]) ** 2)
        below = min(range(3), key=lambda k: (x - facets[k][0]) ** 2 + (y + 1 - facets[k][1]) ** 2)
        if here != below and (x, y + 1) in points and (x + y) % 3:
            image.set(x, y, CRAG[3])
    for x, y in points:
        if any((x + dx, y + dy) not in points for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            image.set(x, y, CRAG_LINE if (x - cx) / rx + (y - cy) / ry > -0.6 else CRAG[3])


def crag(variant, small=False):
    """A pile of boulders for one mountain ("L") or outcrop ("C") tile, in a 64x64 cell whose tile
    is (16..48, 24..56): boulders fill the tile and spill past it, rising above it, so neighbouring
    tiles drawn in row order merge into one ragged rock mass."""
    rng = random.Random((900 if small else 700) + variant)
    image = Image(FRAME, FRAME)
    for x, y in ellipse(32, 52, 18 if not small else 13, 4):
        image.set(x, y, SHADOW)
    stones = []
    if small:
        stones.append((32 + rng.uniform(-3, 3), 42 + rng.uniform(-2, 2), rng.uniform(10, 13), rng.uniform(9, 11)))
        for _ in range(rng.randrange(1, 3)):
            stones.append((32 + rng.uniform(-11, 11), 47 + rng.uniform(-3, 4), rng.uniform(5, 8), rng.uniform(4, 6)))
    else:
        # A dark mass behind the boulders so no ground shows through the pile.
        for x, y in ellipse(32, 36, 17, 15):
            image.set(x, y, CRAG[4])
        for row in range(3):
            for column in range(3):
                big = rng.random() < 0.3
                stones.append((20 + column * 12 + rng.uniform(-4, 4), 22 + row * 12 + rng.uniform(-3, 3),
                               rng.uniform(11, 15) if big else rng.uniform(7, 11), rng.uniform(9, 12) if big else rng.uniform(6, 9)))
        stones.append((32 + rng.uniform(-4, 4), 34 + rng.uniform(-3, 3), rng.uniform(10, 13), rng.uniform(9, 11)))
    stones.sort(key=lambda stone: stone[1] + stone[3])
    for index, (cx, cy, rx, ry) in enumerate(stones):
        points = {(x, y) for x, y in boulder_shape(rng, cx, cy, rx, ry) if 0 <= x < FRAME and 0 <= y < FRAME}
        paint_boulder(image, points, cx, cy, rx, ry, variant * 17 + index)
    return image


CLIFF_FACE = (rgba("7a6e5c"), rgba("5e5446"), rgba("463e33"), rgba("948770"))
CLIFF_SIDE = (rgba("5a5143"), rgba("443d33"), rgba("6a604f"))


def cliff(mask, rocky=False):
    """A cliff ("L"): the same oblique block as a wall, its top a meadow ledge with a rocky lip
    and its open south and east sides craggy rock faces with vertical cracks and tufts of grass.
    `rocky` gives a bare rock top instead: overworld rock outcrops ("C" outside dungeons)."""
    open_north, open_west, open_south, open_east = (bool(mask & bit) for bit in (1, 2, 4, 8))
    image = Image(WALL, WALL)

    def crag(x, y, along, rise, side):
        # Irregular boulders stacked in a face: cells of varying width per band, each lit at its
        # top-left and shaded at its bottom-right, with dark seams between them.
        band = int(rise // 5)
        width = 5 + (band * 7) % 4
        offset = (band * 11) % width
        cell_x = (along + offset) % width
        cell_y = rise % 5
        tones = CLIFF_SIDE if side else CLIFF_FACE
        if cell_x < 1.0 or cell_y < 1.0:
            return CLIFF_FACE[2] if not side else CLIFF_SIDE[1]
        light = (cell_y > 3.0) + (cell_x < 2.2)
        color = (tones[1], tones[0], CLIFF_FACE[3] if not side else tones[2])[min(light, 2)]
        if cell_x > width - 1.2:
            color = scale(color, 0.82)
        if (x * 13 + y * 7) % 29 < 2:
            color = scale(color, 0.9)
        return color

    if open_east:
        for y in range(FRAME):
            for x in range(32, 48):
                depth = 48 - (x + 0.5)
                if 16 - depth <= y + 0.5 < 48 - depth:
                    level = y + 0.5 + depth - 16
                    image.set(x, y, OUTLINE if level < 1.0 or x == 47 else crag(x, y, level, depth, True))
    if open_south:
        for y in range(32, 48):
            rise = 48 - (y + 0.5)
            for x in range(0, 48):
                if 16 - rise <= x + 0.5 < 48 - rise:
                    color = crag(x, y, x + 0.5 + rise - 16, rise, False)
                    if rise > 13 and (x * 5) % 7 < 3:
                        color = GRASS[3] if (x // 2) % 2 else GRASS[1]
                    if y == 47 or x + 0.5 < 16 - rise + 1.0:
                        color = OUTLINE
                    image.set(x, y, color)
    if rocky:
        top = Image(TILE, TILE)
        for x in range(32):
            for y in range(32):
                slab = (x // 7 + y // 5 * 3 + (y // 5) % 2) % 4
                color = (CLIFF_FACE[3], CLIFF_FACE[0], CLIFF_FACE[0], CLIFF_FACE[1])[slab]
                if (x + (y // 5) * 3) % 7 == 0 or y % 5 == 0 and (x * 3) % 4:
                    color = CLIFF_FACE[2]
                elif (x * 13 + y * 7) % 17 < 2:
                    color = scale(color, 0.9)
                elif (x * 5 + y * 11) % 41 < 2:
                    color = MOSS[(x + y) % 2]
                top.set(x, y, color)
        image.over(top)
    else:
        image.over(grass_tile(mask % 4))
    for x in range(32):
        for y in range(32):
            edge = min(y if open_north else 9, 31 - y if open_south else 9, x if open_west else 9, 31 - x if open_east else 9)
            if edge < 2 and (x * 7 + y * 3) % 5 < 3:
                image.set(x, y, CLIFF_FACE[3] if edge == 0 else CLIFF_FACE[0])
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


# Tibia-style mountain rock ("L", and rock outcrops "C" on the overworld): an oblique block like a
# wall, its top a lumpy mass of weathered stone and its open south and east sides rough cliff faces.
# Seven cool greys from highlight to crevice.
ROCK = (pal.ROCK[0], pal.ROCK[1], pal.ROCK[2], pal.ROCK[4], pal.ROCK[5], pal.ROCK[6], pal.ROCK[7])
ROCK_LINE = pal.outline(pal.ROCK)
# The rock texture repeats every ROCK_SPAN tiles each way: a tile draws the variant
# (x % ROCK_SPAN) + (y % ROCK_SPAN) * ROCK_SPAN, the matching part of one seamless 96x96 texture.
ROCK_SPAN = 4
ROCK_PERIOD = TILE * ROCK_SPAN
MOUNTAIN_VARIANTS = ROCK_SPAN * ROCK_SPAN


def _column_edges():
    """Where the rock columns of a cliff face start along the seamless texture (4-8 px apart)."""
    rng = random.Random(4500)
    edges, at = [0.0], 0.0
    while at < ROCK_PERIOD - 12:
        at += rng.choice((4, 5, 5, 6, 6, 7, 8))
        edges.append(at)
    edges.append(float(ROCK_PERIOD))
    return edges


COLUMN_EDGES = _column_edges()


def _feature_points(seed, count, period):
    rng = random.Random(seed)
    return [(rng.uniform(0, period), rng.uniform(0, period)) for _ in range(count)]


def _worley(x, y, points, period, stretch=1.0, which=False):
    """Distances to the nearest and second-nearest feature point, wrapping at `period` (so the
    texture tiles seamlessly); `stretch` squashes the vertical axis for tall cliff slabs. With
    `which`, also the indices of those two points."""
    first = second = 1e9
    near = other = 0
    for index, (px, py) in enumerate(points):
        dx = abs(x - px)
        dx = min(dx, period - dx)
        dy = abs(y - py)
        dy = min(dy, period - dy) * stretch
        distance = dx * dx + dy * dy
        if distance < first:
            first, second, near, other = distance, first, index, near
        elif distance < second:
            second, other = distance, index
    if which:
        return math.sqrt(first), math.sqrt(second), near, other
    return math.sqrt(first), math.sqrt(second)


def _grain(x, y, seed):
    """Fine, tileable pixel grain in [0, 1)."""
    return ((x % ROCK_PERIOD) * 73856093 ^ (y % ROCK_PERIOD) * 19349663 ^ seed * 83492791) % 1000 / 1000.0


_ROCK_FIELD = {}


def _rock_field():
    """The rock top's height and crevices over the whole seamless 96x96 texture: broad slabs, smaller
    knobs on them, and grit, with dark cracks where slabs meet."""
    if _ROCK_FIELD:
        return _ROCK_FIELD
    broad = _feature_points(4100, 60, ROCK_PERIOD)
    knobs = _feature_points(4200, 460, ROCK_PERIOD)
    for y in range(ROCK_PERIOD):
        for x in range(ROCK_PERIOD):
            f1, f2, a, b = _worley(x + 0.5, y + 0.5, broad, ROCK_PERIOD, which=True)
            g1, g2 = _worley(x + 0.5, y + 0.5, knobs, ROCK_PERIOD)
            height = max(0.0, 1.0 - f1 / 13.0) * 0.55 + max(0.0, 1.0 - g1 / 4.5) * 0.35 + _grain(x, y, 7) * 0.04
            # Only some slabs are split by a crack (wider in places); the rest weather into one mass.
            pair = (min(a, b) * 31 + max(a, b) * 17) % 7
            width = 0.7 + 0.5 * (0.5 + 0.5 * math.sin((x + y) * 0.35 + pair))
            crack = (pair < 4 and f2 - f1 < width and f1 > 1.5) or (g2 - g1 < 0.45 and _grain(x, y, 3) < 0.18)
            _ROCK_FIELD[x, y] = (height, crack)
    return _ROCK_FIELD


# Cave rock (the owner's Tibia cave screenshots): masses of rounded light-grey boulders with dark
# crevices between them, on the same seamless span and block layout as the mountains.
# Darker and warmer than the mountains, so caves read as moody underground (plan 46 audit).
CAVE_ROCK = tuple(pal.CAVE_ROCK[:7])
CAVE_ROCK_LINE = pal.outline(pal.CAVE_ROCK)
_BOULDER_FIELD = {}


def _boulder_field():
    """Every pixel of the seamless span: (dome height 0-1 of its boulder, crevice?, boulder id).
    Boulders 4-7 px across sit on jittered points; where two meet a dark crevice runs."""
    if _BOULDER_FIELD:
        return _BOULDER_FIELD
    points = _feature_points(4300, 260, ROCK_PERIOD)
    for y in range(ROCK_PERIOD):
        for x in range(ROCK_PERIOD):
            f1, f2, a, b = _worley(x + 0.5, y + 0.5, points, ROCK_PERIOD, which=True)
            radius = 4.5 + (a * 37 % 5) * 0.6
            dome = max(0.0, 1.0 - (f1 / radius) ** 2)
            _BOULDER_FIELD[x, y] = (dome, f2 - f1 < 0.85, a)
    return _BOULDER_FIELD


def cave_rock(mask, variant):
    """One cave rock block (48x48, laid out like mountain()): a top of rounded boulders lit from
    the top-left with dark crevices, ragged where it meets the cave floor to the north and west,
    and faces of stacked boulders, darker, on its open south and east sides."""
    open_north, open_west, open_south, open_east = (bool(mask & bit) for bit in (1, 2, 4, 8))
    ox, oy = (variant % ROCK_SPAN) * TILE, (variant // ROCK_SPAN) * TILE
    image = Image(WALL, WALL)
    field = _boulder_field()

    def boulder(u, v, darker):
        dome, crack, _ = field[int(u) % ROCK_PERIOD, int(v) % ROCK_PERIOD]
        if crack or dome <= 0.0:
            return CAVE_ROCK[5] if dome > 0.0 else CAVE_ROCK[6]
        lit = field[int(u - 1) % ROCK_PERIOD, int(v - 1) % ROCK_PERIOD][0] - field[int(u + 1) % ROCK_PERIOD, int(v + 1) % ROCK_PERIOD][0]
        tone = 1 if lit < -0.12 else 2 if dome > 0.55 else 3 if dome > 0.25 else 4
        if lit > 0.18:
            tone += 1
        return CAVE_ROCK[max(0, min(6, tone + darker))]

    if open_east:
        for y in range(FRAME):
            for x in range(32, 48):
                depth = 48 - (x + 0.5)
                if 16 - depth <= y + 0.5 < 48 - depth:
                    level = y + 0.5 + depth - 16
                    color = boulder(level + oy + 61, depth * 1.3 + 17, 2)
                    image.set(x, y, CAVE_ROCK_LINE if level < 1.0 or x == 47 else color)
    if open_south:
        for y in range(32, 48):
            rise = 48 - (y + 0.5)
            for x in range(0, 48):
                if 16 - rise <= x + 0.5 < 48 - rise:
                    color = boulder(x + 0.5 + rise - 16 + ox, rise * 1.3 + 41, 1)
                    if y == 47 or x + 0.5 < 16 - rise + 1.0:
                        color = CAVE_ROCK_LINE
                    image.set(x, y, color)

    def bite(t, salt):
        wave = 0.5 + 0.3 * math.sin(t * 0.55 + salt) + 0.2 * math.sin(t * 1.7 + salt * 2.3)
        return int(3.2 * math.sin(math.pi * t / TILE) * wave * (0.6 + 0.4 * _grain(int(t), int(salt), 5)) + 0.4)

    top = Image(TILE, TILE)
    for y in range(TILE):
        for x in range(TILE):
            if open_north and y < bite(x, ox * 0.37) or open_west and x < bite(y, oy * 0.37):
                continue
            if open_north and open_west and x < 4 and y < 4 and (x - 4) ** 2 + (y - 4) ** 2 > 14:
                continue
            top.set(x, y, boulder(x + ox, y + oy, 0))
    for x in range(TILE):
        for y in range(TILE):
            if top.get(x, y) is None:
                continue
            if any(top.get(x + dx, y + dy) is None and 0 <= x + dx < TILE and 0 <= y + dy < TILE
                   for dx, dy in ((-1, 0), (0, -1))) or (open_north and y == 0) or (open_west and x == 0):
                top.set(x, y, CAVE_ROCK_LINE)
    image.over(top)
    return image


def mountain(mask, variant):
    """One mountain rock block (48x48, drawn like a wall 16 px up and left of its tile), indexed by
    its open sides (1 N, 2 W, 4 S, 8 E) and its place in the seamless rock texture (variant): a
    weathered stone top of slabs and knobs lit from the top-left with dark cracks, ragged where it
    meets open ground to the north and west, and craggy cliff faces of tall slabs on its open south
    and east sides."""
    open_north, open_west, open_south, open_east = (bool(mask & bit) for bit in (1, 2, 4, 8))
    ox, oy = (variant % ROCK_SPAN) * TILE, (variant // ROCK_SPAN) * TILE
    image = Image(WALL, WALL)
    field = _rock_field()

    def face(along, rise, side):
        # A rough cliff of standing rock columns: each column (4-8 px wide, its edges wandering with
        # the height) is lit on its left and shaded on its right, with dark fissures between them,
        # broken ledges across some columns, a sunlit lip at the top and shadow at the foot.
        position = (along + math.sin(rise * 0.55 + along * 0.21) * 1.3) % ROCK_PERIOD
        index = bisect.bisect_right(COLUMN_EDGES, position) - 1
        left, right = COLUMN_EDGES[index], COLUMN_EDGES[index + 1]
        inside, width = position - left, right - left
        if inside < 1.0:
            return ROCK[6]
        shade = inside / width
        tone = 2 if shade < 0.3 else 3 if shade < 0.7 else 4
        ledge = 4 + index * 5 % 9
        if abs(rise - ledge) < 0.5 and index % 3 == 0:
            return ROCK[5]
        if abs(rise - ledge - 1) < 0.5 and index % 3 == 0:
            tone = 2
        grit = _grain(int(along), int(rise), 11 + index)
        if grit < 0.08:
            tone += 1
        if rise > 14.5:
            tone = 1
        elif rise < 3.0:
            tone += 2 if rise < 1.5 else 1
        return ROCK[max(1, min(6, tone + (1 if side else 0)))]

    if open_east:
        for y in range(FRAME):
            for x in range(32, 48):
                depth = 48 - (x + 0.5)
                if 16 - depth <= y + 0.5 < 48 - depth:
                    level = y + 0.5 + depth - 16
                    image.set(x, y, ROCK_LINE if level < 1.0 or x == 47 else face(level + oy, depth, True))
    if open_south:
        for y in range(32, 48):
            rise = 48 - (y + 0.5)
            for x in range(0, 48):
                if 16 - rise <= x + 0.5 < 48 - rise:
                    color = face(x + 0.5 + rise - 16 + ox, rise, False)
                    if y == 47 or x + 0.5 < 16 - rise + 1.0:
                        color = ROCK_LINE
                    image.set(x, y, color)

    def height(x, y):
        return field[(x + ox) % ROCK_PERIOD, (y + oy) % ROCK_PERIOD][0]

    def bite(t, salt):
        # How far a ragged open edge eats into the top at position t along it: irregular notches
        # of 0-3 pixels, none at the corners, so neighbouring tiles' edges meet.
        wave = 0.5 + 0.3 * math.sin(t * 0.55 + salt) + 0.2 * math.sin(t * 1.7 + salt * 2.3)
        return int(3.2 * math.sin(math.pi * t / TILE) * wave * (0.6 + 0.4 * _grain(int(t), int(salt), 5)) + 0.4)

    top = Image(TILE, TILE)
    for y in range(TILE):
        for x in range(TILE):
            if open_north and y < bite(x, ox * 0.37) or open_west and x < bite(y, oy * 0.37):
                continue
            if open_north and open_west and x < 4 and y < 4 and (x - 4) ** 2 + (y - 4) ** 2 > 14:
                continue
            light = (height(x + 1, y + 1) - height(x - 1, y - 1)) * 1.6 + height(x, y) * 0.8
            tone = 1 if light > 0.85 else 2 if light > 0.5 else 3 if light > 0.2 else 4
            if field[(x + ox) % ROCK_PERIOD, (y + oy) % ROCK_PERIOD][1]:
                tone = 5 if light > 0.3 else 6
            top.set(x, y, ROCK[tone])
    # A sunlit lip where the top breaks off into a cliff, and a dark rim where it meets open ground.
    for x in range(TILE):
        for y in range(TILE):
            if top.get(x, y) is None:
                continue
            if open_south and y >= 30:
                top.set(x, y, ROCK[1] if y == 30 and (x * 7 + ox) % 5 else ROCK[2])
            if open_east and x >= 31:
                top.set(x, y, ROCK[3])
            if any(top.get(x + dx, y + dy) is None and 0 <= x + dx < TILE and 0 <= y + dy < TILE
                   for dx, dy in ((-1, 0), (0, -1))) or (open_north and y == 0) or (open_west and x == 0):
                top.set(x, y, ROCK_LINE)
    image.over(top)
    return image


# Ore veins by resource band (Professions.RESOURCES["mining"]): dark, main, light, and glint.
ORE_COLOURS = (
    (rgba("6e3812"), rgba("cf7a34"), rgba("ffbd78"), rgba("fff0d8")),  # copper
    (rgba("55261a"), rgba("a24c38"), rgba("dc8a70"), rgba("ffd8c8")),  # iron
    (rgba("5e6872"), rgba("bcc6d0"), rgba("f4f8fc"), rgba("ffffff")),  # silver
    (rgba("1c2f72"), rgba("3a6ae0"), rgba("98bcff"), rgba("e8f0ff")),  # cobalt
    (rgba("42246e"), rgba("9a66ee"), rgba("e8d6ff"), rgba("ffe48a")),  # starmetal
)
# Nuggets in the cliff face as (along, rise) and on the rock top just above it as (x, y).
ORE_FACE = ((5, 9), (8, 5), (13, 11), (17, 6), (21, 9), (25, 4), (27, 11), (11, 2))
ORE_TOP = ((8, 27), (15, 25), (23, 27))


def ore_vein(band, glint):
    """An ore vein's overlay for a mountain block with an open south face (48x48, drawn over the
    block): nuggets of the band's ore set in the cliff face and the lip above it, each lit at its
    top-left and set in a dark seam. With `glint`, a few nuggets sparkle (the game flickers between
    the two frames now and then, so veins catch the eye)."""
    dark, main, light, shine = ORE_COLOURS[band]
    image = Image(WALL, WALL)

    def nugget(cx, cy, size, sparkle):
        cells = [(cx, cy), (cx + 1, cy), (cx, cy + 1), (cx + 1, cy + 1)]
        if size > 1:
            cells += [(cx - 1, cy), (cx, cy - 1), (cx + 2, cy + 1), (cx + 1, cy + 2)]
        for x, y in cells:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if (x + dx, y + dy) not in cells:
                    image.set(x + dx, y + dy, ROCK[6])
        for x, y in cells:
            image.set(x, y, main)
        image.set(cx, cy, light)
        image.set(cx + 1, cy + 1, dark)
        if size > 1:
            image.set(cx - 1, cy, light)
            image.set(cx + 1, cy + 2, dark)
        if sparkle:
            image.set(cx, cy, shine)
            for dx, dy in ((0, -2), (-2, 0), (2, 0), (0, 2)):
                image.set(cx + dx, cy + dy, blend(shine, main, 0.4))

    # A seam of ore wandering across the cliff face, the nuggets strung along and around it.
    for along in range(2, 30):
        rise = 8 + 2.5 * math.sin(along * 0.33) + (1 if along % 7 == 3 else 0)
        image.set(round(along + 16 - rise - 0.5), round(47.5 - rise), dark if along % 4 else main)
    for index, (along, rise) in enumerate(ORE_FACE):
        x = round(along + 16 - rise - 0.5)
        y = round(47.5 - rise)
        nugget(x, y, 1 if index % 3 == 2 else 2, glint and index in (2, 5))
    for index, (x, y) in enumerate(ORE_TOP):
        nugget(x, y, 1, glint and index == 1)
    return image


# Castle walls ("W"): town curtain walls of big pale ashlar blocks with a battlemented walkway on
# top, and towers twice as tall where the wall makes a 2x2 block (SpriteArt.tower). Both are
# drawn like walls, raised up-left of their tile, in frames with CASTLE_PAD pixels of room for the
# merlons: a wall frame is 32 + CASTLE_RAISE + CASTLE_PAD square, a tower's 32 + TOWER_RAISE +
# CASTLE_PAD.
CASTLE_RAISE = 16
TOWER_RAISE = 32
CASTLE_PAD = 6
MERLON = 5
CASTLE_FACE = (pal.ROCK[1], pal.ROCK[2], pal.ROCK[3], pal.ROCK[4], pal.ROCK[6])
CASTLE_SIDE = (pal.ROCK[2], pal.ROCK[3], pal.ROCK[4], pal.ROCK[5], pal.ROCK[7])
CASTLE_TOP = (pal.ROCK[0], pal.ROCK[1], pal.ROCK[2], pal.ROCK[3])
CASTLE_LINE = pal.outline(pal.ROCK)


def _ashlar(along, height, tones, course=6, length=13, salt=0):
    """Big squared stones in courses: mortar joints, a lit top edge, and per-stone shading."""
    row = int(height // course)
    shifted = along + (length // 2 if row % 2 else 0) + salt
    stone = int(shifted // length)
    if height % course < 1.0 or shifted % length < 1.0:
        return tones[4]
    shade = (stone * 7 + row * 13 + salt) % 5
    tone = (0, 1, 1, 2, 1)[shade]
    if height % course > course - 1.5:
        tone = max(0, tone - 1)
    if shifted % length > length - 1.5:
        tone = min(3, tone + 1)
    if ((int(along) * 13 + int(height) * 7 + salt) % 23) == 0:
        tone = min(3, tone + 1)
    return tones[tone]


def cuboid(image, x0, y0, width, depth, height, face, side, top, open_south=True, open_east=True, slits=False, line=CASTLE_LINE):
    """An axis-aligned block in the game's oblique view: its footprint (x0, y0, width, depth) on
    the ground plane, its top drawn `height` pixels up and left, and its south and east faces (when
    open) of ashlar between them. With `slits`, dark arrow slits in the faces."""
    for k in range(height):
        for fx in range(x0, x0 + width):
            if open_south:
                color = face(fx - x0, k)
                if slits and (fx - x0) % 16 == 7 and height * 0.35 < k < height * 0.65:
                    color = line
                image.set(fx - k, y0 + depth - 1 - k, color)
        for fy in range(y0, y0 + depth):
            if open_east:
                color = side(fy - y0, k)
                if slits and (fy - y0) % 16 == 7 and height * 0.35 < k < height * 0.65:
                    color = line
                image.set(x0 + width - 1 - k, fy - k, color)
    for fy in range(y0, y0 + depth):
        for fx in range(x0, x0 + width):
            image.set(fx - height, fy - height, top(fx - x0, fy - y0))
    # Outline the lower edges so blocks read against the ground and each other.
    if open_south:
        for fx in range(x0, x0 + width):
            image.set(fx, y0 + depth - 1, line)
    if open_east:
        for fy in range(y0, y0 + depth):
            image.set(x0 + width - 1, fy, line)


# Qasrun's curtain walls and towers (sandstone_castle_walls.png, sandstone_castle_towers.png):
# the castle's ashlar in sandstone (face and side: four tones and the mortar; the walkway; line).
SANDSTONE_CASTLE = ((pal.SANDSTONE[1], pal.SANDSTONE[2], pal.SANDSTONE[3], pal.SANDSTONE[4], pal.SANDSTONE[6]),
                    (pal.SANDSTONE[2], pal.SANDSTONE[3], pal.SANDSTONE[4], pal.SANDSTONE[5], pal.SANDSTONE[7]),
                    (pal.SANDSTONE[0], pal.SANDSTONE[1], pal.SANDSTONE[2], pal.SANDSTONE[3]),
                    pal.outline(pal.SANDSTONE))


def castle_block(mask, tower, stone=None):
    """A castle wall or tower block indexed by open sides (1 N, 2 W, 4 S, 8 E: sides not joined to
    more castle wall, or for a tower, to more tower): ashlar faces where open, a flagstone walkway,
    and merlons along every open edge of the top. Towers stand twice as tall, with arrow slits.
    `stone` swaps the grey stone for another (SANDSTONE_CASTLE)."""
    CASTLE_FACE, CASTLE_SIDE, CASTLE_TOP, CASTLE_LINE = stone or (globals()["CASTLE_FACE"], globals()["CASTLE_SIDE"],
                                                                  globals()["CASTLE_TOP"], globals()["CASTLE_LINE"])
    open_north, open_west, open_south, open_east = (bool(mask & bit) for bit in (1, 2, 4, 8))
    raise_ = TOWER_RAISE if tower else CASTLE_RAISE
    size = TILE + raise_ + CASTLE_PAD
    image = Image(size, size)
    base = CASTLE_PAD + raise_  # the tile's footprint on the ground plane

    def face(along, height):
        return _ashlar(along, height, CASTLE_FACE)

    def side(along, height):
        return _ashlar(along, height, CASTLE_SIDE, salt=5)

    def flag(x, y):
        # Flagstones of the walkway in staggered rows of uneven slabs, with a little grit.
        row = y // 7
        shifted = x + (row * 5) % 11
        length = (9, 12, 10, 13)[row % 4]
        if y % 7 == 0 or shifted % length == 0:
            return CASTLE_TOP[3]
        tone = (0, 1, 2, 1, 1)[(shifted // length * 3 + row * 7) % 5]
        if (x * 13 + y * 7) % 29 == 0:
            tone = min(3, tone + 1)
        return CASTLE_TOP[tone]

    cuboid(image, base, base, TILE, TILE, raise_, face, side, flag, open_south, open_east, slits=tower, line=CASTLE_LINE)
    top = CASTLE_PAD  # the walkway's top-left corner in the frame
    # Merlons stand along open edges: 6 px blocks with 4 px gaps, drawn from the back to the front.
    merlons = []
    for start in range(1, TILE - 5, 10):
        if open_north:
            merlons.append((top + start, top, 6, 4))
        if open_south:
            merlons.append((top + start, top + TILE - 4, 6, 4))
        if open_west:
            merlons.append((top, top + start, 4, 6))
        if open_east:
            merlons.append((top + TILE - 4, top + start, 4, 6))
    if open_north and open_west:
        merlons.append((top, top, 4, 4))
    if open_north and open_east:
        merlons.append((top + TILE - 4, top, 4, 4))
    if open_south and open_west:
        merlons.append((top, top + TILE - 4, 4, 4))
    if open_south and open_east:
        merlons.append((top + TILE - 4, top + TILE - 4, 4, 4))
    merlons.sort(key=lambda m: (m[1] + m[3], m[0]))
    for x, y, width, depth in merlons:
        cuboid(image, x, y, width, depth, MERLON,
               lambda a, h: CASTLE_FACE[1] if h < MERLON - 1 else CASTLE_FACE[0],
               lambda a, h: CASTLE_SIDE[2],
               lambda a, b: CASTLE_TOP[0] if a + b < 3 else CASTLE_TOP[1], line=CASTLE_LINE)
    return image


THIN_BAND = (11, 21)  # a thin wall's masonry band across its tile


def thin_wall(mask, stone=None, height=WALL - TILE, face=None, line=OUTLINE):
    """A thin wall (town houses and walls): a 10-pixel masonry band through the tile centre,
    reaching the tile edge toward each connected side (1 N, 2 W, 4 S, 8 E: a wall or a doorway
    there), raised height px (16 like the thick walls; HOUSE_RAISE for house walls) with its south
    and east faces showing, in a TILE + height square frame. `face(side, along, height)`, when
    given, colours the faces instead ("south" or "east", px along the face and up from its foot;
    None keeps the masonry), and `line` is the outline."""
    top_tones, south, east = stone or STONE
    lo, hi = THIN_BAND
    shape = set(box(lo, lo, hi - lo, hi - lo))
    for bit, area in ((1, box(lo, 0, hi - lo, lo)), (2, box(0, lo, lo, hi - lo)),
                      (4, box(lo, hi, hi - lo, TILE - hi)), (8, box(hi, lo, TILE - hi, hi - lo))):
        if mask & bit:
            shape |= set(area)
    image = Image(TILE + height, TILE + height)
    raise_ = height
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
                if face is not None and k != raise_:
                    color = face("south", x, height) or color
                if k == raise_:
                    color = line
            else:
                along = y + (5 if (height // 8) % 2 else 0)
                color = east[0]
                if height % 8 == 7 or along % 12 == 0:
                    color = east[1]
                if face is not None and k != raise_:
                    color = face("east", y, height) or color
                if k == raise_ or (x + 1, y) in shape:
                    color = line if k == raise_ else color
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
                image.set(nx, ny, line)
    return image


# Sunreach's houses (sandstone_walls.png): cream plaster over sandstone, from the master palette.
SANDSTONE_STONE = ((pal.SANDSTONE[1], pal.SANDSTONE[0], pal.SANDSTONE[3], pal.SANDSTONE[4]),
                   (pal.SANDSTONE[2], pal.SANDSTONE[4], pal.SANDSTONE[1]),
                   (pal.SANDSTONE[3], pal.SANDSTONE[5], pal.SANDSTONE[2]))
SANDSTONE_LINE = pal.outline(pal.SANDSTONE)


def sandstone_face(window=False):
    """Faces of a Sunreach wall, after the desert towns of the OpenTibia sprite pack (reference
    only): smooth plaster with fine speckle and a hairline crack here and there, a dark plinth at
    the foot, a lit cornice under a shadow line at the top, and (with `window`) a small arched
    window closed by a latticed wooden screen."""
    ramp = pal.SANDSTONE

    def color(side, along, height):
        east = side == "east"
        base = 3 if east else 2
        if height < 3:
            return ramp[base + 2]
        if height >= HOUSE_RAISE - 3:
            return ramp[base - 1]
        if height == HOUSE_RAISE - 4:
            return ramp[base + 2]
        if window and 11 <= along <= 20 and 14 <= height <= 25:
            inner = 12 <= along <= 19 and 15 <= height <= 24 - (1 if along in (12, 19) else 0)
            if not inner:
                return ramp[base - 2] if height == 14 else ramp[base + 1]
            if (along - 12) % 3 == 0 or (height - 15) % 3 == 0:
                return pal.OAK[4 if east else 3]
            return pal.DARK_WOOD[5]
        grain = _grain(along, height + (7 if east else 0), 87)
        if grain < 0.08:
            return ramp[base + 1]
        if grain > 0.95:
            return ramp[base - 1]
        if (along * 3 + height * 5) % 97 == 0:
            return ramp[base + 2]
        return ramp[base]
    return color


def sandstone_wall(mask, window=False):
    return thin_wall(mask, stone=SANDSTONE_STONE, height=HOUSE_RAISE, face=sandstone_face(window), line=SANDSTONE_LINE)


def _window(along, height, east, frame, glass, mullion):
    """A small square window with a cross mullion, in the same place on every house face (the
    Qasrun pattern): None outside it, else the colour. `frame` is (lit sill, shaded frame)."""
    if not (11 <= along <= 20 and 14 <= height <= 25):
        return None
    if not (12 <= along <= 19 and 15 <= height <= 24):
        return frame[0] if height == 14 or height == 25 else frame[1]
    if along in (15, 16) or height == 19:
        return mullion[1 if east else 0]
    pane_left = 12 if along < 15 else 17
    pane_top = 24 if height > 19 else 18
    if (along - pane_left) + (pane_top - height) == 1:
        return glass[0]
    return glass[2 if east else 1]


def stone_face(window=False):
    """Faces of a grey town house (house_walls.png) in the house style: coursed ROCK masonry with
    staggered joints and a fine speckle, a dark plinth at the foot, a lit cornice under a shadow
    line at the top, and (with `window`) a glazed window with a timber cross."""
    ramp = pal.ROCK

    def color(side, along, height):
        east = side == "east"
        base = 5 if east else 4
        if height < 3:
            return ramp[base + 2]
        if height >= HOUSE_RAISE - 3:
            return ramp[base - 1]
        if height == HOUSE_RAISE - 4:
            return ramp[base + 2]
        if window:
            pane = _window(along, height, east, (ramp[base - 3], ramp[base - 2]),
                           (pal.WATER[4], pal.WATER[6], pal.WATER[7]), (ramp[base - 2], ramp[base - 1]))
            if pane is not None:
                return pane
        course = (height - 3) // 6
        joint = (along + (7 if course % 2 else 0) + (5 if east else 0)) % 13
        if (height - 3) % 6 == 5 or joint == 0:
            return ramp[base + 2]
        if (height - 3) % 6 == 4 and joint > 1:
            return ramp[base - 1]
        grain = _grain(along, height + (7 if east else 0), 91)
        if grain < 0.1:
            return ramp[base + 1]
        if grain > 0.94:
            return ramp[base - 1]
        return ramp[base]
    return color


def stone_wall(mask, window=False):
    return thin_wall(mask, height=HOUSE_RAISE, face=stone_face(window), line=STONE_LINE)


def log_face(window=False):
    """Faces of a frost-isle log house (log_walls.png): round OAK logs stacked 5 px apart, lit on
    top and shaded in the seam under each, on a fieldstone footing, with snow lying on the top
    edge and (with `window`) a frosted window."""
    ramp = pal.OAK

    def color(side, along, height):
        east = side == "east"
        base = 4 if east else 3
        if height < 3:
            return pal.FIELDSTONE[6 if east else 5] if height < 2 or (along + 1) % 6 == 0 else pal.FIELDSTONE[4 if east else 3]
        if height >= HOUSE_RAISE - 2 - (1 if _grain(along, 3, 19) > 0.7 else 0):
            return pal.SNOW[2 if east else 1]
        if window:
            pane = _window(along, height, east, (ramp[base - 2], ramp[base - 1]),
                           (pal.ICE[1], pal.ICE[5], pal.ICE[6]), (ramp[base - 1], ramp[base]))
            if pane is not None:
                return pane
        row = (height - 3) % 5
        tone = (ramp[base + 3], ramp[base + 1], ramp[base], ramp[base], ramp[base - 1])[row]
        if row in (2, 3) and _grain(along, height, 23) < 0.12:
            return ramp[base + 1]
        return tone
    return color


def log_wall(mask, window=False):
    return thin_wall(mask, stone=LOG_WOOD, height=HOUSE_RAISE, face=log_face(window), line=pal.outline(pal.OAK))


def brick_face(side, along, height):
    """Faces of a cellar wall (cellar_walls.png): small dark BRICK bricks, 4 courses high and 8 px
    long, staggered, with dark mortar, a lit top edge on some bricks and a sooty plinth."""
    ramp = pal.BRICK
    east = side == "east"
    base = 4 if east else 3
    if height < 2:
        return ramp[base + 3]
    course = (height - 2) // 4
    joint = (along + (4 if course % 2 else 0) + (3 if east else 0)) % 8
    if (height - 2) % 4 == 3 or joint == 0:
        return ramp[base + 2]
    brick = _grain(course, (along + (4 if course % 2 else 0)) // 8, 61)
    tone = ramp[base + (1 if brick < 0.3 else 0)]
    if (height - 2) % 4 == 2 and joint > 1 and brick > 0.5:
        return ramp[base - 1]
    return tone


def cellar_wall(mask):
    return thin_wall(mask, stone=CELLAR_STONE, height=HOUSE_RAISE, face=brick_face, line=pal.outline(pal.BRICK))


def thin_wall_fill(stone=None):
    """The top of a thin-wall block: where four walls meet in a 2 x 2 square, their bands leave a
    gap between them, and looking down it shows the faces behind, so a thick wall read as a comb
    of notches. This patch (in the frame of the square's north-west wall, at the walls' full
    height) closes the gap with the same top surface, one pixel over each band's edge, so a block
    of walls reads as one mass. SpriteArt.draw_wall draws it over that wall."""
    top_tones = (stone or STONE)[0]
    lo, hi = THIN_BAND
    image = Image(TILE + HOUSE_RAISE, TILE + HOUSE_RAISE)
    for y in range(hi - 1, TILE + lo + 1):
        for x in range(hi - 1, TILE + lo + 1):
            course = x // 6
            color = top_tones[0]
            if (x + y * 3 + course * 5) % 11 == 0:
                color = top_tones[2]
            elif (x * 7 + y) % 13 == 0:
                color = top_tones[1]
            image.set(x, y, color)
    return image


# Castle keeps (the owner's castle reference, docs/plan/40-archipelago.md): thick walls of rounded
# grey fieldstones, light on top and the upper left, dark mortar between the stones.
FIELD_TOP = tuple(pal.FIELDSTONE[0:4])
FIELD_SOUTH = tuple(pal.FIELDSTONE[2:6])
FIELD_EAST = tuple(pal.FIELDSTONE[3:7])
FIELD_MORTAR = tuple(pal.FIELDSTONE[5:8])
FIELD_LINE = pal.outline(pal.FIELDSTONE)


def _fieldstone(u, v, seed, width=8, height=6):
    """Rubble masonry at a surface point: (stone tone 0-3 or -1 for mortar, edge) where edge is 1 on
    a stone's lit upper-left rim and 2 on its shaded lower-right. Stones sit on a jittered grid that
    repeats every TILE px along u, so walls join from tile to tile."""
    columns = TILE // width
    row = math.floor(v / height)
    best, second, owner = 1e9, 1e9, None
    for j in (row - 1, row, row + 1):
        shift = (width // 2) if j % 2 else 0
        base_i = math.floor((u - shift) / width)
        for i in (base_i - 1, base_i, base_i + 1):
            key = (i % columns, j)
            jx = (_grain(key[0], key[1], seed) - 0.5) * width * 0.5
            jy = (_grain(key[0], key[1], seed + 7) - 0.5) * height * 0.45
            cx, cy = i * width + shift + width / 2 + jx, j * height + height / 2 + jy
            d = ((u - cx) / width) ** 2 * 1.4 + ((v - cy) / height) ** 2
            if d < best:
                best, second, owner = d, best, key
            elif d < second:
                second = d
    if second - best < 0.16:
        return -1, 0
    tone = int(_grain(owner[0], owner[1], seed + 13) * 3)
    near = second - best
    edge = 0
    if near < 0.32:
        # Which side of the stone: compare with a point a little up-left.
        edge = 1 if (u + v) % 7 < 4 and best > 0.15 else 2
    return tone, edge


def _field_color(ramp, mortar, u, v, seed):
    tone, edge = _fieldstone(u, v, seed)
    if tone < 0:
        return mortar
    if edge == 1:
        return ramp[max(0, tone - 1)]
    if edge == 2:
        return ramp[min(3, tone + 1)]
    return ramp[tone]


def fieldstone_wall(mask, height=32):
    """A castle keep's wall: the thin wall's shape (thin_wall: a band through the tile centre
    reaching each connected side, raised `height` px with its south and east faces showing) in
    rounded grey fieldstones: the top lightest, the south face mid, the east face darker, dark
    mortar between the stones and an outline along the foot."""
    lo, hi = THIN_BAND
    shape = set(box(lo, lo, hi - lo, hi - lo))
    for bit, area in ((1, box(lo, 0, hi - lo, lo)), (2, box(0, lo, lo, hi - lo)),
                      (4, box(lo, hi, hi - lo, TILE - hi)), (8, box(hi, lo, TILE - hi, hi - lo))):
        if mask & bit:
            shape |= set(area)
    image = Image(TILE + height, TILE + height)
    for k in range(height, 0, -1):
        up = height - k
        for x, y in shape:
            if (x + 1, y) in shape and (x, y + 1) in shape:
                continue
            if (x, y + 1) not in shape:
                color = _field_color(FIELD_SOUTH, FIELD_MORTAR[1], x, up, 31)
            else:
                color = _field_color(FIELD_EAST, FIELD_MORTAR[2], y, up, 37)
            if k == height:
                color = FIELD_LINE
            image.set(x + k, y + k, color)
    for x, y in shape:
        color = _field_color(FIELD_TOP, FIELD_MORTAR[0], x, y * 1.2, 41)
        edge = ((x, y - 1) not in shape and y > 0) or ((x - 1, y) not in shape and x > 0) \
            or ((x, y + 1) not in shape and y < TILE - 1) or ((x + 1, y) not in shape and x < TILE - 1)
        if edge:
            color = FIELD_TOP[3]
        image.set(x, y, color)
    for x, y in shape:
        for dx, dy in ((0, -1), (-1, 0)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < TILE and 0 <= ny < TILE and (nx, ny) not in shape and image.get(nx, ny) is None:
                image.set(nx, ny, FIELD_LINE)
    return image


def fieldstone_fill():
    """The top of a fieldstone wall block (thin_wall_fill's job for the keep's walls)."""
    lo, hi = THIN_BAND
    image = Image(TILE + HOUSE_RAISE, TILE + HOUSE_RAISE)
    for y in range(hi - 1, TILE + lo + 1):
        for x in range(hi - 1, TILE + lo + 1):
            image.set(x, y, _field_color(FIELD_TOP, FIELD_MORTAR[0], x % TILE, y * 1.2, 41))
    return image


DOOR_WOOD = (pal.OAK[2], pal.OAK[3], pal.OAK[5], pal.OAK[6])


HOUSE_RAISE = 32
# House and town walls ("#") stand a full tile tall, as in Tibia: house_walls.png holds 16 thin walls
# by connected sides and then the doorway of a west-east and of a north-south wall, in frames
# TILE + HOUSE_RAISE square drawn HOUSE_RAISE px up and left of their tile (SpriteArt.draw_wall).
# A doorway's opening runs from, to (along the wall), is this tall, and its round head starts here.
HOUSE_DOOR = (4, 28, 29, 21)


def house_door(vertical, base=None):
    """A doorway in a house wall, Tibia-style: the wall runs on over it at full height and its
    visible face (south for a west-east wall, east for a north-south one) is cut by a timber-framed
    opening nearly a tile wide and as tall as a person, closed by an iron-banded plank door. It
    leans with the wall like every raised face, and one frame serves doorways facing either way."""
    image = base(5 if vertical else 10) if base else stone_wall(5 if vertical else 10)
    hi = THIN_BAND[1]
    left, right, top, spring = HOUSE_DOOR
    middle, span = (left + right - 1) / 2, (right - left) / 2

    def at(along, depth, height):
        # Pixel of a point `depth` px behind the visible face, `height` px up, `along` the wall.
        k = HOUSE_RAISE - height
        return (hi - 1 - depth + k, along + k) if vertical else (along + k, hi - 1 - depth + k)

    def inside(along, height):
        if not left <= along < right or height < 0 or height >= top:
            return False
        return height < spring or (along - middle) ** 2 / span ** 2 + (height - spring) ** 2 / (top - spring) ** 2 < 1

    # The door fills the opening: planks 4 px wide with a dark seam (wide enough to stay planks
    # when the face leans), lit on their left, two iron bands with rivets, a ring handle, and a
    # shadow under the head of the frame.
    for height in range(HOUSE_RAISE):
        for along in range(TILE):
            if not inside(along, height):
                continue
            plank = (along - left) % 5
            color = (DOOR_WOOD[0], DOOR_WOOD[1], DOOR_WOOD[1], DOOR_WOOD[1], DOOR_WOOD[3])[plank]
            if height in (6, 7, 21, 22):
                color = IRON[2] if height in (7, 22) else (IRON[0] if plank == 2 else IRON[1])
            if along in (right - 7, right - 6) and height in (13, 14, 15):
                color = pal.GOLD[1] if (along, height) == (right - 7, 15) else IRON[2]
            if not inside(along, height + 2) or along == right - 1:
                color = DOOR_WOOD[3]
            image.set(*at(along, 0, height), color)
    # The frame: timber posts and a lintel round the opening, lit on the left and top.
    for height in range(HOUSE_RAISE):
        for along in range(TILE):
            if inside(along, height):
                continue
            near = [inside(along + dx, height + dy) for dx, dy in ((1, 0), (2, 0), (-1, 0), (-2, 0), (0, -1), (0, -2))]
            if any(near):
                lit = near[0] or near[1] or near[4] or near[5]
                image.set(*at(along, 0, height), OAK[1] if lit else OAK[2])
    # A worn threshold where the floor runs through.
    for along in range(left, right):
        image.set(*at(along, 0, 0), COBBLE[2])
    return image


# ---------------------------------------------------------------- furniture
# 32x48 cells; the tile is the bottom 32x32 (drawn 16 px above it), so pieces may stand taller
# than a tile. Order: FURNITURE_KINDS (SpriteArt.FURNITURE must match).

FURNITURE_KINDS = ["counter_shop", "counter_bank", "shelf_potions", "shelf_books", "weapon_rack", "barrel", "crate",
                   "strongbox", "anvil", "workbench", "cauldron", "loom", "hearth",
                   # Homes (World._furnish_homes): every house without a keeper is lived in.
                   "bed", "table", "chair", "plant", "chest",
                   # Streets (World._decorate_streets): lamp posts, a well on each square, benches, stalls.
                   "lamp_post", "well", "bench", "stall",
                   # Seen from behind: a market row facing north, a bench facing the fountain.
                   "stall_back", "bench_back",
                   # Castles (Decor markers, docs/plan/40-archipelago.md).
                   "pillar", "knight_statue", "gargoyle", "bush", "flower_vase", "potted_palm", "candelabra",
                   "fruit_table", "stove", "throne"]
OAK = (rgba("a07a4c"), rgba("82603a"), rgba("5f4429"), rgba("3f2c1b"))
IRON = (rgba("8c8e8c"), rgba("5d605f"), rgba("3a3c3c"))


def wall_decor(kind):
    """A 32x32 wall decoration (banner, torch, painting) from props.py, hung on a wall's face."""
    image = Image(TILE, TILE)
    image.pixels = props.wall_decor(kind)
    return image


def furniture(kind):
    """A 32x48 furniture frame, painted from 3D solids (tools/generators/props.py)."""
    image = Image(TILE, 48)
    image.pixels = props.furniture(kind)
    return image


# ---------------------------------------------------------------- micro menu icons
# 32x32 icons for the buttons right of the action bar (game/ui/micro_menu.gd), shaded like
# the item icons. Order: MENU_ICONS (MicroMenu.ENTRIES actions).

MENU_ICONS = ["character", "spell_book", "professions", "quest_list", "lexicon", "world_map", "party", "controls"]


def menu_icon(kind):
    image = Image(TILE, TILE)
    leather = (rgba("b0623e"), rgba("8a4630"), rgba("5e2c20"))
    parchment = (rgba("f2e4c0"), rgba("dcc89a"), rgba("a8946a"))
    gold = (rgba("f6d77a"), rgba("d4a73c"), rgba("8f6a1e"))
    iron = (rgba("d0d4d8"), rgba("9aa0a8"), rgba("5e646c"))
    wood = (rgba("b08a5a"), rgba("8a6440"), rgba("5a3f25"))
    if kind == "character":
        # A helmeted bust: shoulders in mail, a steel helm with a gold crest.
        shade(image, {p for p in ellipse(16, 30, 12, 9) if p[1] <= 29}, (rgba("8a96a8"), rgba("5e6878"), rgba("3a4250")))
        shade(image, box(13, 17, 6, 5), (rgba("e8c0a0"), rgba("c89878"), rgba("98684c")))
        shade(image, {p for p in ellipse(16, 13, 7, 8) if p[1] <= 16} | box(9, 13, 14, 4), iron)
        image.rect(11, 14, 10, 2, rgba("26282c"))
        image.rect(15, 5, 2, 12, gold[1])
        image.rect(15, 5, 1, 12, gold[0])
        for x, y in ((12, 24), (20, 24), (16, 26)):
            image.set(x, y, gold[1])
    elif kind == "spell_book":
        # A closed tome in red leather with gold corners and a glowing rune.
        shade(image, box(7, 5, 18, 23), leather)
        image.rect(23, 7, 3, 20, parchment[1])
        image.rect(23, 7, 1, 20, parchment[2])
        image.rect(7, 5, 3, 23, scale(leather[2], 0.85))
        for x, y in ((10, 5), (21, 5), (10, 25), (21, 25)):
            image.rect(x, y, 3, 3, gold[1])
            image.set(x, y, gold[0])
        rune = line(16, 10, 16, 23) | line(16, 12, 20, 15) | line(16, 15, 20, 18)
        for x, y in thick(rune, ((0, 0), (1, 0))):
            image.set(x, y, rgba("ffd86a"))
        for x, y in ellipse(17, 16, 6, 8):
            if image.get(x, y) == leather[1] and (x + y) % 3 == 0:
                image.set(x, y, scale(leather[1], 1.25))
    elif kind == "professions":
        # A crossed pickaxe and hammer.
        for x, y in thick(line(8, 26, 24, 8), ((0, 0), (1, 0), (0, 1))):
            image.set(x, y, wood[1] if (x + y) % 4 else wood[0])
        for x, y in thick(line(8, 8, 24, 26), ((0, 0), (1, 0), (0, 1))):
            image.set(x, y, wood[1] if (x + y) % 4 else wood[0])
        shade(image, {(x, y) for x in range(16, 30) for y in range(3, 12) if abs((x - 23) * 0.55 - (y - 7)) < 1.6 + abs(x - 23) * 0.12}, iron)
        shade(image, box(3, 4, 9, 6), iron)
        image.rect(3, 4, 9, 1, iron[0])
    elif kind == "quest_list":
        # A parchment scroll with wooden rollers and a red wax seal.
        shade(image, box(9, 7, 14, 19), parchment)
        for y in (6, 25):
            shade(image, box(7, y, 18, 3), wood, False)
        for y in range(11, 22, 3):
            image.rect(11, y, 9 if y != 20 else 5, 1, rgba("8a7650"))
        shade(image, ellipse(20, 22, 3.2, 3.2), (rgba("e06a5a"), rgba("b03a32"), rgba("7a2420")), False)
    elif kind == "lexicon":
        # A green bestiary with a monster's eye on the cover.
        cover = (rgba("6a9a6a"), rgba("3e6a48"), rgba("24402c"))
        shade(image, box(7, 5, 18, 23), cover)
        image.rect(23, 7, 3, 20, parchment[1])
        image.rect(7, 5, 3, 23, scale(cover[2], 0.85))
        shade(image, ellipse(17, 16, 6, 4), (rgba("f8f0d8"), rgba("e0d0a0"), rgba("a89870")), False)
        shade(image, ellipse(17, 16, 2.6, 3.4), (rgba("ffb060"), rgba("e07a2a"), rgba("8a3a10")), False)
        image.rect(17, 14, 1, 5, rgba("1a1010"))
    elif kind == "world_map":
        # A folded map: three panels of land and sea, a red route and a cross.
        folds = [(rgba("b8c890"), rgba("98a870"), rgba("6a7a4a")), (rgba("90b8d0"), rgba("6a98b8"), rgba("4a7090")),
                 (rgba("b8c890"), rgba("98a870"), rgba("6a7a4a"))]
        for index, tones3 in enumerate(folds):
            x0 = 4 + index * 8
            lift = 2 if index % 2 == 0 else -2
            panel = {(x, y) for x in range(x0, x0 + 8) for y in range(8 + lift + (x - x0) * -lift // 4, 26 + lift + (x - x0) * -lift // 4)}
            shade(image, panel, tones3)
        for x, y in line(7, 20, 14, 14) | line(14, 14, 22, 18):
            if (x + y) % 2 == 0:
                image.set(x, y, rgba("c03a32"))
        for x, y in thick(line(20, 9, 25, 14) | line(25, 9, 20, 14), ((0, 0), (1, 0))):
            image.set(x, y, rgba("c03a32"))
    elif kind == "party":
        # Three companions shoulder to shoulder under a gold pennant: green and red hoods behind a
        # blue-cloaked leader.
        skin = (rgba("e8c0a0"), rgba("c89878"), rgba("98684c"))
        for cx, tones3 in ((9, (rgba("7ab06a"), rgba("4e8048"), rgba("2e5030"))), (23, (rgba("d0705a"), rgba("a04838"), rgba("682a22")))):
            shade(image, {p for p in ellipse(cx, 28, 7, 7) if p[1] <= 29}, tones3)
            shade(image, ellipse(cx, 16, 4, 4.5), skin)
            shade(image, {p for p in ellipse(cx, 15, 5, 5.5) if p[1] <= 14}, tones3, False)
        shade(image, {p for p in ellipse(16, 30, 8, 8) if p[1] <= 29}, (rgba("6a9ad8"), rgba("3e68b0"), rgba("243e78")))
        shade(image, ellipse(16, 18, 4.5, 5), skin)
        shade(image, {p for p in ellipse(16, 17, 5.5, 6) if p[1] <= 15}, iron, False)
        image.rect(15, 2, 1, 10, wood[2])
        shade(image, {(x, y) for x in range(16, 24) for y in range(2, 8) if y - 2 <= (24 - x) * 0.75}, gold, False)
    elif kind == "controls":
        # A brass cog with a key across it.
        cog = set()
        for step in range(8):
            angle = step * math.pi / 4
            cog |= box(round(16 + math.cos(angle) * 10) - 2, round(16 + math.sin(angle) * 10) - 2, 4, 4)
        cog |= ellipse(16, 16, 9, 9)
        shade(image, cog - ellipse(16, 16, 3.5, 3.5), gold)
        for x, y in thick(line(6, 26, 22, 10), ((0, 0), (1, 0), (0, 1))):
            image.set(x, y, iron[1] if (x + y) % 3 else iron[0])
        shade(image, ellipse(23, 9, 3.5, 3.5) - ellipse(23, 9, 1.5, 1.5), iron, False)
        image.rect(7, 23, 2, 3, iron[2])
        image.rect(10, 20, 2, 3, iron[2])
    return image.outlined()


# ---------------------------------------------------------------- title painting
# The start screen's backdrop (400x267, shown at 3x): a castle on a hill above a lake at dusk,
# mountains and a moon behind, pines framing a grassy ledge in front where the game draws the
# four heroes. Pixel art with ordered dithering between colour bands, in the game's palette.

TITLE_SIZE = (400, 267)
BAYER = ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5))
SKY = [(0, "121730"), (40, "1e2346"), (80, "3a3458"), (105, "6a4466"), (125, "a8565c"), (142, "e0884e"), (152, "f2b860")]


def _band(stops, y, x):
    """The dithered colour of a vertical gradient at (x, y): two neighbouring stops mixed."""
    for (y0, c0), (y1, c1) in zip(stops, stops[1:]):
        if y0 <= y < y1:
            share = (y - y0) / (y1 - y0)
            return rgba(c1) if share * 16 > BAYER[y % 4][x % 4] + 0.5 else rgba(c0)
    return rgba(stops[-1][1])


def _ridge(x, base, amplitude, seed, roughness=1.0):
    """A mountain or hill skyline: summed sines plus a little hashed jitter."""
    y = base
    for k, (period, weight) in enumerate(((97, 1.0), (41, 0.45), (17, 0.18 * roughness))):
        y -= amplitude * weight * math.sin((x + seed * (k + 3) * 13) * 2 * math.pi / period)
    return y + (hash_cell(x, seed) % 3 - 1) * 0.4 * roughness


def _pine(image, cx, base, height, body, rim):
    """A layered pine silhouette with a faint rim light on its left edges."""
    for y in range(base - height, base + 1):
        depth = (y - (base - height)) / height
        tier = (depth * 4) % 1.0
        half = int((2 + depth * height * 0.32) * (0.55 + 0.45 * tier))
        for x in range(cx - half, cx + half + 1):
            image.set(x, y, rim if x == cx - half and depth > 0.08 else body)
    image.rect(cx - 1, base, 2, 3, body)


def title_painting():
    width, height = TITLE_SIZE
    image = Image(width, height)
    horizon = 152
    for y in range(height):
        for x in range(width):
            image.set(x, y, _band(SKY, min(y, horizon), x))
    # Stars thin out toward the glowing horizon.
    for y in range(0, 95):
        for x in range(width):
            roll = hash_cell(x * 3 + 1, y * 7 + 2) % 1000
            if roll < 6 * (1 - y / 95):
                image.set(x, y, rgba("f4ecd8") if roll < 2 else rgba("9aa0c8"))
    # The moon, with a dithered halo and a few maria.
    mx, my, mr = 318, 44, 13
    for y in range(my - 30, my + 31):
        for x in range(mx - 30, mx + 31):
            d = math.hypot(x - mx, y - my)
            if d <= mr:
                shade = rgba("f2ead0") if (x - mx) + (y - my) * 0.4 < 4 else rgba("d8cca8")
                if hash_cell(x // 3, y // 3) % 9 == 0 and d < mr - 2:
                    shade = rgba("c4b894")
                image.set(x, y, shade)
            elif d <= mr + 16 and (mr + 16 - d) * 1.1 > BAYER[y % 4][x % 4]:
                image.set(x, y, scale(image.get(x, y), 1.25))
    # Sunset clouds: long streaks lit from below.
    for cy, cx, length, color in ((96, 40, 110, "8a4a66"), (108, 150, 140, "b05a5a"), (118, 20, 90, "c46a52"),
                                  (102, 260, 120, "7a4466"), (126, 230, 100, "d07a50")):
        for x in range(cx, cx + length):
            thick = 1 + int(2 * math.sin((x - cx) / length * math.pi))
            for y in range(cy - thick, cy + 1):
                if (x + y) % 5 or y == cy:
                    image.set(x, y, rgba(color) if y < cy else scale(rgba(color), 1.25))
    # Far mountains, hazy violet with lit western slopes; then darker nearer ranges.
    for x in range(width):
        top = int(_ridge(x, 128, 16, 3))
        for y in range(top, horizon + 1):
            lit = _ridge(x - 1, 128, 16, 3) > _ridge(x, 128, 16, 3) and y < top + 5
            image.set(x, y, rgba("7a5a7c") if lit else (rgba("54456e") if y < top + 9 else rgba("4a3e64")))
        top = int(_ridge(x, 146, 9, 11, 1.4))
        for y in range(top, horizon + 6):
            image.set(x, y, rgba("362f50") if y > top else rgba("5a4a6a"))
    # The castle hill (right) and its keep.
    for x in range(200, 400):
        top = int(150 - 22 * math.exp(-((x - 300) / 55) ** 2) + (hash_cell(x, 5) % 2))
        for y in range(top, 172):
            image.set(x, y, rgba("2a2640") if y > top else rgba("4a3a5a"))
    stone, rim, window = rgba("221f34"), rgba("4e4062"), rgba("ffcf6a")
    def tower(x0, top, w, roof):
        image.rect(x0, top, w, 150 - top, stone)
        image.rect(x0, top, 1, 150 - top, rim)
        for k in range(0, w, 2):
            image.set(x0 + k, top - 1, stone)
        if roof:
            rise = w + 4
            for row in range(rise):
                half = (w / 2 + 1.5) * (1 - row / rise)
                left = round(x0 + w / 2 - half)
                image.rect(left, top - 1 - row, max(1, round(half * 2)), 1, rgba("4a2a3e") if row and left == round(x0 + w / 2 - half) and row % 3 == 0 else rgba("3a2234"))
                image.set(left, top - 1 - row, rgba("6a3a4e"))
        for wy in range(top + 4, 146, 7):
            if hash_cell(x0, wy) % 3:
                image.rect(x0 + w // 2 - 1, wy, 2, 3, window)
    image.rect(266, 118, 70, 22, stone)
    for k in range(266, 336, 3):
        image.set(k, 117, stone)
    image.rect(266, 118, 70, 1, rim)
    tower(258, 102, 10, True)
    tower(286, 86, 14, True)
    tower(316, 98, 10, True)
    tower(334, 110, 8, False)
    image.rect(296, 70, 1, 16, stone)
    image.rect(297, 70, 7, 4, rgba("a83a3a"))
    for wx in (272, 280, 306, 326):
        image.rect(wx, 126, 2, 3, window)
    image.rect(300, 132, 6, 8, rgba("120f1c"))
    # The lake: the sky mirrored and darkened, broken by ripples; the moon and castle lights shimmer.
    for y in range(158, 236):
        mirror = horizon - (y - 158) * 2
        for x in range(width):
            color = scale(image.get(x, max(0, mirror)) or rgba("1e2346"), 0.62)
            if (y * 7 + x // 9) % 11 == 0:
                color = scale(color, 1.35)
            image.set(x, y, color)
    for y in range(160, 204, 2):
        wobble = hash_cell(y, 9) % 5 - 2
        image.rect(mx - 4 + wobble, y, 8 - abs(wobble), 1, rgba("d8cca8"))
        if y < 190:
            image.rect(300 + wobble, y, 3, 1, rgba("c89a4a"))
    for x in range(width):
        image.set(x, 158, rgba("1c1a2c"))
    # Far shore pines along the lake, then the grassy ledge in front with big framing pines.
    for k in range(0, width, 5):
        if not 240 < k < 360:
            _pine(image, k + hash_cell(k, 3) % 4, 160, 8 + hash_cell(k, 4) % 7, rgba("161a26"), rgba("2a2a40"))
    for x in range(width):
        top = int(214 + 10 * math.sin(x / 63.0) + 6 * math.sin(x / 23.0 + 1) + (hash_cell(x, 8) % 2))
        for y in range(top, height):
            depth = y - top
            if depth == 0:
                color = rgba("6a7a4a")
            elif depth < 3:
                color = rgba("4a5a36")
            else:
                color = rgba("2c3a26") if (depth * 3 + BAYER[y % 4][x % 4]) < 40 else rgba("1e2a1c")
            image.set(x, y, color)
        if hash_cell(x, 12) % 7 == 0:
            image.set(x, top - 1, rgba("5a6a3e"))
            image.set(x, top - 2, rgba("4a5a36"))
    for cx, base, size in ((14, 267, 120), (46, 262, 92), (372, 267, 128), (394, 258, 84), (342, 265, 70)):
        _pine(image, cx, base, size, rgba("0e1410"), rgba("26301e"))
    for cx, cy, r in ((96, 236, 7), (108, 240, 4), (262, 238, 6), (250, 243, 3)):
        for y in range(cy - r, cy + r):
            for x in range(cx - r - 3, cx + r + 4):
                if ((x - cx) / (r + 3)) ** 2 + ((y - cy) / r) ** 2 <= 1:
                    image.set(x, y, rgba("8a8578") if x - cx + y - cy < -2 else rgba("5a564e"))
    return image


# ---------------------------------------------------------------- herb patches
# Map patches for herbalism (game/core/crafting.gd HERBS): two 32x32 variants per resource band,
# in the band's herb colours. Order: HERB_KINDS (Professions.RESOURCES["herbalism"]).

HERB_KINDS = ["sunflax", "mirereed", "silverthistle", "nightcotton", "starpetal"]


def fountain(frame):
    """A 96x112 frame of the town square's fountain (props.py), 3x3 tiles with its bottom row last."""
    image = Image(*props.FOUNTAIN_SIZE)
    image.pixels = props.fountain(frame)
    return image


def herb_patch(kind, variant):
    """A 32x32 herb patch in the band's item colours, painted from 3D solids (props.py)."""
    main, light, accent = PALETTES[kind]
    image = Image(TILE, TILE)
    image.pixels = props.herb(main, light, accent, variant)
    return image


# ---------------------------------------------------------------- roofs and signs

# Roof materials: (light, base, dark, deep) for clay tiles, slate, wooden shingles, and snow, from
# the master palette like Qasrun's plaster.
ROOF_MATERIALS = [
    (pal.BRICK[0], pal.BRICK[1], pal.BRICK[3], pal.BRICK[5]),
    (pal.FIELDSTONE[3], pal.FIELDSTONE[4], pal.FIELDSTONE[5], pal.FIELDSTONE[7]),
    (pal.OAK[2], pal.OAK[3], pal.OAK[5], pal.OAK[6]),
    (pal.SNOW[0], pal.SNOW[1], pal.SNOW[3], pal.OAK[5]),
    # Sunreach's flat roofs of sand plaster (game/render/roof_art.gd _flat): light, base, dark, deep.
    (pal.SANDSTONE[0], pal.SANDSTONE[1], pal.SANDSTONE[3], pal.SANDSTONE[5]),
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
                elif material == 4:  # sand plaster: smooth, fine speckle, a hairline crack now and then
                    grain = _grain(x, y, 91)
                    color = base
                    if grain < 0.07:
                        color = dark
                    elif grain > 0.94:
                        color = light
                    elif (x * 5 + y * 3) % 61 == 0:
                        color = scale(dark, 0.92)
                elif material == 3:  # snow over shingles: soft drifts, a dark shingle edge peeking out
                    offset = 3 if course % 2 else 0
                    ragged = hash_cell((x + offset) // 8, course) % 5
                    color = base
                    if level == 7 and ragged == 0:
                        color = deep
                    elif level >= 6:
                        color = dark
                    elif level <= 2:
                        color = light
                    if (x * 7 + y * 3) % 23 == 0:
                        color = light
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


SIGN_WOOD = (pal.OAK[2], pal.OAK[3], pal.OAK[5])


def sign(kind):
    """A 32x32 hanging sign with its service's emblem, painted from 3D solids (props.py)."""
    image = Image(TILE, TILE)
    image.pixels = props.sign(kind)
    return image


# ---------------------------------------------------------------- spell icons

def spell_catalog():
    """(id, rune, colour) of every spell in game/data/spells.gd, in catalog order (the icon order)."""
    text = (ROOT / "game" / "data" / "spells.gd").read_text()
    body = text[text.index("const SPELLS"):]
    return [(match.group(1), match.group(2), rgba(match.group(3)))
            for match in re.finditer(r'"(\w+)": \{"rune": "(\w+)", "name": "[^"]+".*?"color": Color\("#(\w+)"\)', body, re.S)]


def _line(x0, y0, x1, y1):
    """line() for fractional endpoints."""
    return line(round(x0), round(y0), round(x1), round(y1))


## Elder Futhark runes as stroke paths in a box 1 tall and up to 0.7 wide (x right, y down).
RUNE_STROKES = {
    "fehu": [[(0, 1), (0, 0)], [(0, 0.3), (0.5, 0.02)], [(0, 0.58), (0.5, 0.3)]],
    "uruz": [[(0, 1), (0, 0), (0.55, 0.3), (0.55, 1)]],
    "thurisaz": [[(0, 0), (0, 1)], [(0, 0.25), (0.45, 0.5), (0, 0.75)]],
    "ansuz": [[(0, 1), (0, 0)], [(0, 0.02), (0.5, 0.3)], [(0, 0.32), (0.5, 0.6)]],
    "raido": [[(0, 1), (0, 0), (0.45, 0.22), (0, 0.45), (0.5, 1)]],
    "kenaz": [[(0.55, 0.1), (0, 0.5), (0.55, 0.9)]],
    "gebo": [[(0, 0), (0.7, 1)], [(0.7, 0), (0, 1)]],
    "wunjo": [[(0, 1), (0, 0), (0.45, 0.22), (0, 0.45)]],
    "hagalaz": [[(0, 0), (0, 1)], [(0.6, 0), (0.6, 1)], [(0, 0.3), (0.6, 0.65)]],
    "naudiz": [[(0.32, 0), (0.32, 1)], [(0, 0.32), (0.64, 0.62)]],
    "isa": [[(0, 0), (0, 1)]],
    "jera": [[(0.32, 0.02), (0, 0.27), (0.32, 0.52)], [(0.38, 0.48), (0.7, 0.73), (0.38, 0.98)]],
    "eihwaz": [[(0.3, 0), (0.3, 1)], [(0.3, 0), (0.62, 0.22)], [(0.3, 1), (0, 0.78)]],
    "perthro": [[(0, 0), (0, 1)], [(0, 0.04), (0.45, 0.28), (0.45, 0.04)], [(0, 0.96), (0.45, 0.72), (0.45, 0.96)]],
    "algiz": [[(0.35, 1), (0.35, 0)], [(0.35, 0.45), (0, 0.06)], [(0.35, 0.45), (0.7, 0.06)]],
    "sowilo": [[(0.5, 0), (0, 0.42), (0.55, 0.58), (0.05, 1)]],
    "tiwaz": [[(0.35, 1), (0.35, 0)], [(0.35, 0), (0, 0.35)], [(0.35, 0), (0.7, 0.35)]],
    "berkano": [[(0, 0), (0, 1)], [(0, 0), (0.48, 0.25), (0, 0.5), (0.48, 0.75), (0, 1)]],
    "ehwaz": [[(0, 1), (0, 0), (0.35, 0.35), (0.7, 0), (0.7, 1)]],
    "mannaz": [[(0, 1), (0, 0), (0.7, 0.55)], [(0.7, 1), (0.7, 0), (0, 0.55)]],
    "laguz": [[(0, 1), (0, 0), (0.48, 0.3)]],
    "ingwaz": [[(0.35, 0.05), (0.7, 0.5), (0.35, 0.95), (0, 0.5), (0.35, 0.05)]],
    "dagaz": [[(0, 0), (0, 1), (0.7, 0), (0.7, 1), (0, 0)]],
    "othala": [[(0.35, 0), (0.68, 0.36), (0.05, 1)], [(0.35, 0), (0.02, 0.36), (0.65, 1)]],
    # Two runes of the Anglo-Saxon row, for spells past the Elder Futhark's twenty-four.
    "ear": [[(0.35, 1), (0.35, 0)], [(0.35, 0), (0, 0.32)], [(0.35, 0), (0.7, 0.32)], [(0.1, 0.55), (0.6, 0.55)]],
    "yr": [[(0, 1), (0, 0), (0.6, 0.3), (0.6, 1)], [(0.3, 0.15), (0.3, 1)]],
    # More of the Anglo-Saxon row, for the spells of the empty level brackets.
    "stan": [[(0.35, 0), (0.35, 1)], [(0, 0.25), (0.7, 0.25), (0.7, 0.75), (0, 0.75), (0, 0.25)]],
    "ior": [[(0.35, 0), (0.35, 1)], [(0, 0.2), (0.7, 0.6)], [(0.7, 0.2), (0, 0.6)]],
    "gar": [[(0.35, 0), (0.35, 1)], [(0.35, 0.2), (0.7, 0.5), (0.35, 0.8), (0, 0.5), (0.35, 0.2)]],
    "calc": [[(0.35, 0), (0.35, 1)], [(0.35, 0.55), (0, 0.94)], [(0.35, 0.55), (0.7, 0.94)]],
    "cweorth": [[(0.35, 0), (0.35, 1)], [(0.35, 0.02), (0, 0.32)], [(0.35, 0.02), (0.7, 0.32)],
                [(0.35, 0.98), (0, 0.68)], [(0.35, 0.98), (0.7, 0.68)]],
    "ac": [[(0, 1), (0, 0)], [(0, 0.02), (0.5, 0.3), (0.5, 0.45)], [(0, 0.32), (0.5, 0.6)]],
    "aesc": [[(0.2, 1), (0.2, 0)], [(0.2, 0.02), (0.7, 0.3)], [(0.2, 0.32), (0.7, 0.6)], [(0.2, 0.1), (0, 0.25)]],
}
RUNE_HEIGHT = 18


def rune_sign(rune, height=RUNE_HEIGHT, width_px=2):
    """The rune's strokes, `width_px` pixels wide, centred on the stone."""
    strokes = RUNE_STROKES[rune]
    width = max(x for stroke in strokes for x, _ in stroke) * height
    left, top = 16 - width / 2 - 0.5, 16.5 - height / 2
    points = set()
    for stroke in strokes:
        for (ax, ay), (bx, by) in zip(stroke, stroke[1:]):
            points |= _line(left + ax * height, top + ay * height, left + bx * height, top + by * height)
    return thick(points, ((0, 0), (1, 0), (0, 1), (1, 1)) if width_px == 2 else ((0, 0),))


RUNE_FX_ELEMENTS = ("fire", "frost", "lightning", "holy", "nature", "slash", "pierce", "heal", "death", "ice_wall")
RUNE_FX_FRAMES = 4


def rune_fx(element, frame):
    """One tile of a rune spell landing (game/render/world_view.gd draws one on every tile hit):
    fire blooms into flame tongues and dies to embers; frost raises a cluster of ice shards that
    shatter; lightning strikes down as a forked bolt and scatters sparks. Saturated colour and
    glow are for magic only, per the art direction; outlines stay dark and coloured."""
    rng = random.Random(9100 + RUNE_FX_ELEMENTS.index(element) * 10 + frame)
    image = Image(TILE, TILE)
    grow = (0.45, 0.85, 1.0, 0.8)[frame]
    if element == "fire":
        ramp = (rgba("fff6c0"), rgba("ffd050"), rgba("ff8a28"), rgba("d8461a"), rgba("7a2412"))
        if frame < 3:
            # Overlapping flame tongues that taper to points, hottest low in the middle.
            tongues = [(16 + offset * grow, height * grow) for offset, height in
                       ((-7, 9), (-3.5, 15), (0, 19), (3.5, 14), (7, 10), (-1.5, 12), (2, 11))]
            for cx, height in tongues:
                cx += rng.uniform(-0.8, 0.8)
                for step in range(int(height)):
                    rise = step / height
                    half = 3.6 * grow * (1 - rise) ** 0.75
                    sway = math.sin(rise * 3.0 + cx) * rise * 1.5
                    for x in range(int(cx + sway - half), int(cx + sway + half) + 1):
                        edge = abs(x - cx - sway) / max(half, 0.6)
                        heat = 0.25 * edge + 0.75 * rise
                        image.set(x, 25 - step, ramp[min(4, int(heat * 4.2))])
            for x, y in ellipse(16, 25, 8.5 * grow, 2.2 * grow):
                image.set(x, y, ramp[0] if frame == 1 else ramp[1])
        else:
            # Embers rising from a scorch mark, and a soft smudge of smoke (no dithering).
            for x, y in ellipse(16, 24, 7, 2.5):
                image.set(x, y, (48, 36, 30, 170))
            for x, y in ellipse(15, 14, 4, 3) | ellipse(18, 10, 3, 2.5):
                image.set(x, y, (70, 62, 58, 110))
            for _ in range(9):
                x, y = rng.randrange(8, 25), rng.randrange(8, 24)
                image.set(x, y, rng.choice(ramp[1:4]))
    elif element == "frost":
        ramp = (rgba("ffffff"), rgba("c8f0ff"), rgba("8ad8ff"), rgba("4a90c8"), rgba("1c3c64"))
        if frame < 3:
            for shard in range(5 if frame else 2):
                x = 9 + shard * 3.5 + rng.randrange(-1, 2)
                height = (8 + rng.randrange(0, 10)) * grow
                lean = rng.choice((-1, 0, 1))
                for step in range(int(height)):
                    half = max(0, round((height - step) / height * 2.5))
                    for dx in range(-half, half + 1):
                        tone = ramp[1] if dx < 0 else ramp[2] if dx == 0 else ramp[3]
                        if step > height - 3:
                            tone = ramp[0]
                        image.set(int(x + dx + lean * step / 4), 26 - step, tone)
            for x, y in ellipse(16, 26, 9 * grow, 2):
                image.set(x, y, ramp[2])
        else:
            for _ in range(12):
                x, y = rng.randrange(6, 26), rng.randrange(14, 27)
                image.set(x, y, rng.choice(ramp[:3]))
                image.set(x + 1, y, ramp[3])
    elif element == "holy":
        # Golden rays bursting from a bright core, then a ring of light settling to motes.
        ramp = (rgba("ffffff"), rgba("fff4c0"), rgba("ffd860"), rgba("e0a030"), rgba("7a5a18"))
        if frame < 3:
            rays = 8
            for ray in range(rays):
                angle = ray / rays * math.tau + frame * 0.2
                length = (6 + 8 * grow) * (1.0 if ray % 2 == 0 else 0.65)
                for step in range(int(length)):
                    x = round(16 + math.cos(angle) * step)
                    y = round(17 + math.sin(angle) * step * 0.8)
                    image.set(x, y, ramp[1] if step < length * 0.5 else ramp[2])
            for x, y in ellipse(16, 17, 3.5 * grow + 1, 3.5 * grow + 1):
                image.set(x, y, ramp[0])
        else:
            for x, y in ellipse(16, 18, 9, 6) - ellipse(16, 18, 7.5, 4.8):
                image.set(x, y, ramp[2])
            for _ in range(8):
                image.set(rng.randrange(8, 25), rng.randrange(8, 25), ramp[1])
    elif element == "nature":
        # Thorny tendrils whipping up from the ground in a burst of green leaves.
        ramp = (rgba("e8ffa0"), rgba("9ad84a"), rgba("5aa02e"), rgba("2e6a1e"), rgba("5a3a1e"))
        if frame < 3:
            for vine in range(4):
                base = 8 + vine * 5.5
                height = (10 + vine % 2 * 6) * grow
                for step in range(int(height)):
                    x = round(base + math.sin(step * 0.5 + vine) * 2.5)
                    image.set(x, 27 - step, ramp[3])
                    image.set(x + 1, 27 - step, ramp[2])
                    if step % 4 == 2:
                        image.set(x + 2, 26 - step, ramp[4])
            for _ in range(5 + frame * 3):
                x, y = rng.randrange(6, 26), rng.randrange(6, 24)
                for px, py in ellipse(x, y, 1.6, 1):
                    image.set(px, py, rng.choice(ramp[:3]))
        else:
            for _ in range(10):
                x, y = rng.randrange(6, 26), rng.randrange(14, 28)
                image.set(x, y, rng.choice(ramp[1:4]))
    elif element == "slash":
        # A pale crescent sword arc sweeping across the tile and fading.
        ramp = (rgba("ffffff"), rgba("e8eef4"), rgba("b0bcc8"), rgba("6a7480"))
        sweep = (0.35, 0.7, 1.0, 1.0)[frame]
        fade = 0 if frame < 3 else 2
        for step in range(int(40 * sweep)):
            angle = -2.4 + step / 40.0 * 2.8
            for width in range(4 if frame < 3 else 2):
                radius = 11 - width
                x = round(16 + math.cos(angle) * radius)
                y = round(17 + math.sin(angle) * radius * 0.8)
                image.set(x, y, ramp[min(3, width + fade)])
    elif element == "pierce":
        # An arrow's strike: a bright point of impact with splinters thrown back along the shot.
        ramp = (rgba("ffffff"), rgba("f0e6c8"), rgba("c8b080"), rgba("6a5434"))
        if frame < 3:
            for x, y in ellipse(16, 17, 1.5 + frame, 1.5 + frame):
                image.set(x, y, ramp[0] if frame < 2 else ramp[1])
            for _ in range(4 + frame * 3):
                angle = rng.random() * math.tau
                reach = (2 + rng.random() * 6) * grow
                image.set(round(16 + math.cos(angle) * reach), round(17 + math.sin(angle) * reach * 0.7), ramp[2])
        else:
            for _ in range(5):
                image.set(rng.randrange(10, 22), rng.randrange(12, 22), ramp[3])
    elif element == "heal":
        # Green motes and small crosses rising and fading over the tile.
        ramp = (rgba("ffffff"), rgba("c8ffd0"), rgba("7fe08a"), rgba("3a9a4a"))
        for mote in range(7):
            x = 7 + (mote * 13) % 19
            y = round(27 - ((mote * 5 + frame * 6) % 22))
            tone = ramp[min(3, frame // 2 + (mote % 2))]
            image.set(x, y, tone)
            if mote % 3 == 0:
                for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                    image.set(x + dx, y + dy, ramp[2])
    elif element == "death":
        # Sudden death: a pale violet skull rises out of a burst of black smoke and fades to wisps.
        ramp = (rgba("f4e8ff"), rgba("d0b0ff"), rgba("9a6ae0"), rgba("4a2a7a"), rgba("1a0e2a"))
        if frame < 3:
            for x, y in ellipse(16, 22, 10 * grow, 4 * grow) | ellipse(10, 19, 4 * grow, 3 * grow) | ellipse(22, 19, 4 * grow, 3 * grow):
                image.set(x, y, (26, 14, 42, 200))
            lift = (4, 1, 0)[frame]
            top = 8 + lift
            skull = ellipse(16, top + 5, 6, 5.5) | box(12, top + 9, 9, 4)
            for x, y in skull:
                lit = x < 16 and y < top + 6
                image.set(x, y, ramp[0] if lit and frame > 0 else ramp[1] if not (x > 19 or y > top + 10) else ramp[2])
            for x, y in ellipse(13.5, top + 6, 1.6, 1.6) | ellipse(18.5, top + 6, 1.6, 1.6):
                image.set(x, y, ramp[4])
            image.set(16, top + 9, ramp[3])
            for x in range(13, 21, 2):
                image.set(x, top + 12, ramp[3])
            if frame == 1:
                for x, y in ellipse(13.5, top + 6, 0.6, 0.6) | ellipse(18.5, top + 6, 0.6, 0.6):
                    image.set(x, y, ramp[2])
        else:
            for _ in range(10):
                x, y = rng.randrange(7, 25), rng.randrange(6, 24)
                image.set(x, y, rng.choice(ramp[2:4]))
                image.set(x, y - 1, (60, 40, 90, 140))
    elif element == "ice_wall":
        # Glacier wall: a block of blue ice filling the tile, rising (0), standing with a shimmer
        # that moves (1, 2), then cracked and sunk (3). Lit from the top-left like the props.
        ramp = (rgba("ffffff"), rgba("d8f4ff"), rgba("9ad8f8"), rgba("5aa0d8"), rgba("2a5a8a"))
        height = (12, 26, 26, 18)[frame]
        bottom = 29
        block = set()
        for x in range(5, 27):
            # Crystal points along the top: tall spires between lower shoulders.
            spire = (0, 3, 6, 4, 1, 5, 2)[(x * 3) % 7]
            peak = height - spire - abs(x - 16) // 4
            for y in range(bottom - peak, bottom + 1):
                block.add((x, y))
        for x, y in block:
            face = (x + 1, y) not in block or (x, y + 1) not in block
            rim = (x - 1, y) not in block or (x, y - 1) not in block
            depth = (y - (bottom - height)) / max(1, height)
            # Facets: alternate columns catch the light, the far side and the base sit in shadow.
            facet = (x // 4) % 2 == 0
            tone = ramp[1] if rim else ramp[4] if face else ramp[2] if depth < (0.6 if facet else 0.35) else ramp[3]
            image.set(x, y, tone)
        shine = (0, 9, 15, 0)[frame]
        if shine:
            for step in range(7):
                image.set(shine + step // 2, bottom - height + 4 + step, ramp[0])
                image.set(shine + 1 + step // 2, bottom - height + 4 + step, ramp[1])
        for x, y in ((11, bottom - 6), (20, bottom - 9), (15, bottom - 14)):
            if (x, y) in block:
                image.set(x, y, ramp[1])
        if frame == 3:
            crack = [(10, bottom - 16), (13, bottom - 11), (12, bottom - 6), (16, bottom - 2)]
            for (ax, ay), (bx, by) in zip(crack, crack[1:]):
                for px, py in line(ax, ay, bx, by):
                    if (px, py) in block:
                        image.set(px, py, ramp[4])
            for _ in range(6):
                image.set(rng.randrange(4, 28), rng.randrange(bottom - 2, bottom + 2), ramp[1])
    else:
        ramp = (rgba("ffffff"), rgba("fff6b0"), rgba("ffe060"), rgba("e0a020"), rgba("6a4a10"))
        if frame < 2:
            # A forked bolt in sharp zigzags: a white core, gold edges, one branch off the main stroke.
            points = [(16 + rng.randrange(-2, 3), 0)]
            while points[-1][1] < 22:
                x, y = points[-1]
                points.append((x + rng.choice((-5, -4, 4, 5)), y + rng.randrange(3, 5)))
            points.append((16, 25))
            fork = points[len(points) // 2]
            branch = [fork, (fork[0] + 6, fork[1] + 4), (fork[0] + 4, fork[1] + 8)]
            for path in (points, branch):
                for (ax, ay), (bx, by) in zip(path, path[1:]):
                    for px, py in line(ax, ay, bx, by):
                        image.set(px - 1, py, ramp[2])
                        image.set(px + 1, py, ramp[3])
                    for px, py in line(ax, ay, bx, by):
                        image.set(px, py, ramp[0])
            if frame == 1:
                for x, y in ellipse(16, 25, 6, 2):
                    image.set(x, y, ramp[1])
        sparks = (4, 10, 14, 6)[frame]
        for _ in range(sparks):
            angle = rng.random() * math.tau
            reach = (3 + rng.random() * 9) * grow
            x, y = round(16 + math.cos(angle) * reach), round(24 + math.sin(angle) * reach * 0.5)
            image.set(x, y, ramp[1])
            image.set(x + 1, y, ramp[2])
    outline = {"fire": "26140a", "frost": "0e1c30", "holy": "3a2a08", "nature": "142a0e", "slash": "1e2228",
               "pierce": "2a1e10", "heal": "0e2a14", "death": "120a1e", "ice_wall": "16304a"}.get(element, "2a2008")
    return image.outlined(rgba(outline))


# Spell missiles (game/render/world_overlay.gd): small animated projectiles, drawn turned toward the
# target, one row per element in MISSILE_ELEMENTS, MISSILE_FRAMES frames of MISSILE_SIZE pixels.
MISSILE_ELEMENTS = ("fire", "frost", "lightning", "holy", "nature", "pierce")
MISSILE_FRAMES = 4
MISSILE_SIZE = 16


def spell_missile(element, frame):
    """A projectile pointing right (+x), centred: an ember trailing sparks, an ice shard, a crackling
    spark, a holy orb with a halo, a spinning thorn, and an arrow. Saturated, glowing colours are
    for magic only; the arrow is wood and steel."""
    rng = random.Random(9500 + MISSILE_ELEMENTS.index(element) * 10 + frame)
    image = Image(MISSILE_SIZE, MISSILE_SIZE)
    c = MISSILE_SIZE // 2
    if element == "fire":
        ramp = (rgba("fff6c0"), rgba("ffd050"), rgba("ff8a28"), rgba("d8461a"))
        for x, y in ellipse(c + 2, c, 3.2, 2.6):
            image.set(x, y, ramp[1])
        for x, y in ellipse(c + 3, c, 1.6, 1.3):
            image.set(x, y, ramp[0])
        for step in range(6):
            image.set(c - 1 - step, c + round(math.sin(step + frame) * 1.2), ramp[2 if step < 3 else 3])
        for _ in range(2):
            image.set(rng.randrange(1, c - 2), c + rng.randrange(-3, 4), ramp[2])
    elif element == "frost":
        ramp = (rgba("ffffff"), rgba("c8f0ff"), rgba("8ad8ff"), rgba("4a90c8"))
        for step in range(10):
            half = max(0, round(2.4 - abs(step - 6) * 0.5))
            for dy in range(-half, half + 1):
                image.set(c - 5 + step, c + dy, ramp[1] if dy < 0 else ramp[2] if dy == 0 else ramp[3])
        image.set(c + 5, c, ramp[0])
        if frame % 2:
            image.set(c - 6, c - 2, ramp[1])
            image.set(c - 7, c + 2, ramp[1])
    elif element == "lightning":
        ramp = (rgba("ffffff"), rgba("fff6b0"), rgba("ffe060"), rgba("e0a020"))
        y = c
        for x in range(2, MISSILE_SIZE - 2):
            y += rng.choice((-1, 0, 1)) if x % 2 == 0 else 0
            y = max(c - 3, min(c + 3, y))
            image.set(x, y, ramp[0])
            image.set(x, y - 1, ramp[2])
            image.set(x, y + 1, ramp[3])
    elif element == "holy":
        ramp = (rgba("ffffff"), rgba("fff4c0"), rgba("ffd860"), rgba("e0a030"))
        for x, y in ellipse(c, c, 4.5, 4.5) - ellipse(c, c, 3.5, 3.5):
            if (x + y + frame) % 3:
                image.set(x, y, ramp[2])
        for x, y in ellipse(c, c, 2.4, 2.4):
            image.set(x, y, ramp[0] if (x - c) ** 2 + (y - c) ** 2 < 2 else ramp[1])
    elif element == "nature":
        ramp = (rgba("9ad84a"), rgba("5aa02e"), rgba("2e6a1e"), rgba("5a3a1e"))
        angle = frame * math.pi / 4
        for step in range(-5, 6):
            x = round(c + math.cos(angle) * step)
            y = round(c + math.sin(angle) * step)
            image.set(x, y, ramp[3] if abs(step) < 4 else ramp[2])
        for spike in (-3, 0, 3):
            x = round(c + math.cos(angle) * spike - math.sin(angle) * 2)
            y = round(c + math.sin(angle) * spike + math.cos(angle) * 2)
            image.set(x, y, ramp[1])
            image.set(round(c + math.cos(angle) * spike + math.sin(angle) * 2),
                      round(c + math.sin(angle) * spike - math.cos(angle) * 2), ramp[0])
    else:
        wood, steel, feather = (rgba("8a6440"), rgba("5a3e24")), (rgba("e0e4e8"), rgba("8a9098")), rgba("e8e0d0")
        for x in range(2, 12):
            image.set(x, c, wood[0])
            image.set(x, c + 1, wood[1])
        for dx, dy in ((12, 0), (12, 1), (13, 0), (13, 1), (14, 0), (12, -1), (12, 2)):
            image.set(dx, c + dy, steel[0] if dy in (0, -1) else steel[1])
        for dx in (2, 3, 4):
            image.set(dx, c - 1, feather)
            image.set(dx, c + 2, feather)
    return image.outlined(rgba("2a1a0e") if element in ("fire", "nature", "pierce") else rgba("0e1c30"))


RUNE_STONE = (rgba("a29a8e"), rgba("7e776d"), rgba("5a544c"))


def rune_stone(spell_id, color):
    """A rounded, slightly irregular stone (different per spell), lightly tinted by the spell."""
    seed = sum(ord(c) * (i + 1) for i, c in enumerate(spell_id))
    bumps = [1.0 + 0.07 * math.sin(seed * 0.37 + k * 1.9) for k in range(8)]
    points = set()
    for y in range(TILE):
        for x in range(TILE):
            dx, dy = x + 0.5 - 16, y + 0.5 - 16.5
            angle = (math.atan2(dy, dx) / math.tau * 8) % 8
            k = int(angle)
            radius = bumps[k] + (bumps[(k + 1) % 8] - bumps[k]) * (angle - k)
            if (dx / (14.0 * radius)) ** 2 + (dy / (13.2 * radius)) ** 2 <= 1.0:
                points.add((x, y))
    light, main, dark = (blend(tone, color, 0.12) for tone in RUNE_STONE)
    image = Image(TILE, TILE)
    for x, y in points:
        # Lit from the top left, with a few speckles and pits like weathered stone.
        rim = (x - 1, y) not in points or (x, y - 1) not in points
        shadow = (x + 1, y) not in points or (x, y + 1) not in points or (x + 1, y + 1) not in points
        tone = light if rim or (x + y < 26 and (x * 7 + y * 13 + seed) % 9 == 0) else (dark if shadow else main)
        if (x * 5 + y * 3 + seed) % 23 == 0:
            tone = scale(tone, 0.82)
        image.set(x, y, tone)
    return image, points


def spell_icon(spell_id, rune, color):
    """A rune stone with the spell's Elder Futhark rune carved into it, glowing in its colour."""
    image, stone = rune_stone(spell_id, color)
    sign = rune_sign(rune) & stone
    bright = blend(color, rgba("ffffff"), 0.5)
    core = blend(color, rgba("ffffff"), 0.8)
    for x, y in sorted(stone):
        if (x, y) in sign:
            continue
        near = sum((x + dx, y + dy) in sign for dx in (-1, 0, 1) for dy in (-1, 0, 1))
        if near:
            # The groove's upper-left wall falls into shadow; light spills onto the stone around it.
            current = image.get(x, y)
            if (x + 1, y + 1) in sign and (x - 1, y - 1) not in sign:
                image.set(x, y, scale(current, 0.55))
            else:
                image.set(x, y, blend(current, color, 0.35))
    for x, y in sign:
        inner = all((x + dx, y + dy) in sign for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        image.set(x, y, core if inner else bright if (x - 1, y) in sign or (x, y - 1) in sign else color)
    return image.outlined(rgba("17140f"))


# ---------------------------------------------------------------- output

def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--only", nargs="+", metavar="SHEET",
                        help="write only these sheets (e.g. house_walls.png), leaving the others as they are")
    args = parser.parse_args()
    root = ROOT / "assets" / "sprites"
    outputs = {
        "marker.png": character_sheet(marker, columns=POSE_COLUMNS),
        "spells.png": sheet([spell_icon(spell, rune, color) for spell, rune, color in spell_catalog()], 8, TILE),
        "spell_missiles.png": sheet([spell_missile(element, frame) for element in MISSILE_ELEMENTS for frame in range(MISSILE_FRAMES)],
                                    MISSILE_FRAMES, MISSILE_SIZE),
        "rune_fx.png": sheet([rune_fx(element, frame) for element in RUNE_FX_ELEMENTS for frame in range(RUNE_FX_FRAMES)],
                             RUNE_FX_FRAMES, TILE),
        "crags.png": sheet_row([crag(v) for v in range(8)] + [crag(v, True) for v in range(6)]),
        "objects.png": sheet_row([tree(v) for v in range(3)] + [dead_tree(v) for v in range(2)]
                                 + [desert_plant(v) for v in range(3)] + [waystone()]
                                 + [boulder(v) for v in range(3)]),
        "mushrooms.png": sheet_row([mushroom(v) for v in range(3)]),
        "firs.png": sheet_row([snowy_fir(v) for v in range(3)]),
        "palms.png": sheet_row([palm(v) for v in range(3)]),
        "sandstone_walls.png": sheet([sandstone_wall(mask) for mask in range(16)]
                                     + [house_door(False, sandstone_wall), house_door(True, sandstone_wall),
                                        thin_wall_fill(SANDSTONE_STONE), sandstone_wall(10, True), sandstone_wall(5, True)],
                                     21, TILE + HOUSE_RAISE),
        "log_walls.png": sheet([log_wall(mask) for mask in range(16)]
                               + [house_door(False, log_wall), house_door(True, log_wall), thin_wall_fill(LOG_WOOD),
                                  log_wall(10, True), log_wall(5, True)], 21, TILE + HOUSE_RAISE),
        "roofs.png": roof_sheet(),
        "signs.png": sheet_row([sign("vendor"), sign("banker"), sign("artisan"), sign("warden")]),
        "title.png": title_painting(),
        "menu_icons.png": sheet_row([menu_icon(kind) for kind in MENU_ICONS]),
        "herbs.png": sheet_row([herb_patch(kind, variant) for kind in HERB_KINDS for variant in range(2)]),
        "house_walls.png": sheet([stone_wall(mask) for mask in range(16)]
                                  + [house_door(False), house_door(True), thin_wall_fill(),
                                     stone_wall(10, True), stone_wall(5, True)], 21, TILE + HOUSE_RAISE),
        "fieldstone_walls.png": sheet([fieldstone_wall(mask) for mask in range(16)]
                                      + [house_door(False, fieldstone_wall), house_door(True, fieldstone_wall), fieldstone_fill()],
                                      19, TILE + HOUSE_RAISE),
        "wall_decor.png": sheet_row([wall_decor(kind) for kind in props.WALL_DECOR_KINDS]),
        "cellar_walls.png": sheet([cellar_wall(mask) for mask in range(16)]
                                  + [house_door(False, cellar_wall), house_door(True, cellar_wall), thin_wall_fill(CELLAR_STONE)], 19,
                                  TILE + HOUSE_RAISE),
        "terrain_palette.png": terrain_palette(),
        "ores.png": sheet([ore_vein(band, glint) for glint in (False, True) for band in range(5)], 5, WALL),
        "castle_walls.png": sheet([castle_block(mask, False) for mask in range(16)], 16, TILE + CASTLE_RAISE + CASTLE_PAD),
        "castle_towers.png": sheet([castle_block(mask, True) for mask in range(16)], 16, TILE + TOWER_RAISE + CASTLE_PAD),
        "sandstone_castle_walls.png": sheet([castle_block(mask, False, SANDSTONE_CASTLE) for mask in range(16)], 16,
                                            TILE + CASTLE_RAISE + CASTLE_PAD),
        "sandstone_castle_towers.png": sheet([castle_block(mask, True, SANDSTONE_CASTLE) for mask in range(16)], 16,
                                             TILE + TOWER_RAISE + CASTLE_PAD),
        "cave_rock.png": sheet([cave_rock(mask, variant) for variant in range(MOUNTAIN_VARIANTS) for mask in range(16)], 16, WALL),
        "mountains.png": sheet([mountain(mask, variant) for variant in range(MOUNTAIN_VARIANTS) for mask in range(16)], 16, WALL),
        "walls.png": sheet([wall(mask) for mask in range(16)]
                           + [wall(mask, OBSIDIAN_STONE, pal.outline(pal.HOLLOW)) for mask in range(16)]
                           + [wall(mask, CAVE_STONE, pal.outline(pal.CAVE_ROCK)) for mask in range(16)]
                           + [thin_wall(mask, line=STONE_LINE) for mask in range(16)]
                           + [cliff(mask) for mask in range(16)] + [cliff(mask, True) for mask in range(16)],
                           16, WALL),
        "furniture.png": sheet_row([furniture(kind) for kind in FURNITURE_KINDS]),
        "fountain.png": sheet_row([fountain(frame) for frame in range(props.FOUNTAIN_FRAMES)]),
        "coins.png": sheet_row([icon_finish(coin_stage_icon(stage)) for stage in range(len(pixel_coins.STAGES))]),
    }
    unknown = set(args.only or []) - outputs.keys()
    if unknown:
        parser.error("unknown sheet(s): " + ", ".join(sorted(unknown)))
    for name, image in outputs.items():
        if args.only and name not in args.only:
            continue
        image.save(root / name)
        print(f"wrote assets/sprites/{name} ({image.width}x{image.height})")


if __name__ == "__main__":
    main()
