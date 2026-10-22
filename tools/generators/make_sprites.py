#!/usr/bin/env python3
"""Generate Brimholt's original pixel-art sprite sheets (Python standard library only).

Writes assets/sprites/*.png (not the item icons or character outfits: those come from the OpenTibia pack,
otsp_export.py). The marker and monster sheets use 64x64 frames:
five columns (stand, step A, step B, attack wind-up, strike; monsters only the first three)
and four rows (down, up, left, right), with the
tile centre at frame pixel (32, 40). Floor tiles are 32x32 cells; walls are
48x48 cells drawn 16 pixels up and left of their tile, indexed by open sides
(1 north, 2 west, 4 south, 8 east). objects.png holds 64x96 trees whose trunk base sits on
the tile centre at (32, 80).

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


# ---------------------------------------------------------------- item tones

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


def _luma(color):
    return color[0] * 0.3 + color[1] * 0.59 + color[2] * 0.11


import palette as pal  # noqa: E402
import pixel_coins  # noqa: E402


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


# ---------------------------------------------------------------- colours (the title painting, menu icons)

# Grass in the OpenTibia manner: a living mid green (not olive), darker clumps, and blade tufts
# with lit tips; light from the top-left like the rock.
GRASS = (rgba("517433"), rgba("5d823b"), rgba("44642a"), rgba("7a9d4c"), rgba("33501f"))
DIRT = (rgba("80725c"), rgba("766851"), rgba("92816a"), rgba("625944"))
WATER = (rgba("354b50"), rgba("49666a"), rgba("688281"), rgba("293e44"), rgba("30464b"))


SAND = (rgba("ac9c76"), rgba("9d8e6b"), rgba("c0ae86"), rgba("837759"))
COBBLE = (rgba("787971"), rgba("97988b"), rgba("63665f"), rgba("484e47"))


# The swamp of Mirewood Fen (tools/generators/swamp.gd): dark peaty mud and giant mushrooms.
BOG = (rgba("4a4632"), rgba("3e3a28"), rgba("585338"), rgba("2c2a1c"), rgba("5a6a3a"))


# ---------------------------------------------------------------- the frost isles

# Snow: base, lit drift tops, blue shadow, deep shadow, sparkle.
SNOW = (rgba("e4ebf2"), rgba("f6f9fc"), rgba("c4d0de"), rgba("a2b2c6"), rgba("ffffff"))


ROCK = (pal.ROCK[1], pal.ROCK[2], pal.ROCK[4], pal.ROCK[6])
MOSS = (pal.MOSS[1], pal.MOSS[2])


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


GRAVEL = (rgba("7c7a74"), rgba("6c6a65"), rgba("8e8c85"), rgba("5a5854"), rgba("9c9a92"))


# Tibia-style mountain rock ("L", and rock outcrops "C" on the overworld): an oblique block like a
# wall, its top a lumpy mass of weathered stone and its open south and east sides rough cliff faces.
# Seven cool greys from highlight to crevice.
ROCK = (pal.ROCK[0], pal.ROCK[1], pal.ROCK[2], pal.ROCK[4], pal.ROCK[5], pal.ROCK[6], pal.ROCK[7])
# The rock texture repeats every ROCK_SPAN tiles each way: a tile draws the variant
# (x % ROCK_SPAN) + (y % ROCK_SPAN) * ROCK_SPAN, the matching part of one seamless 96x96 texture.
ROCK_SPAN = 4
ROCK_PERIOD = TILE * ROCK_SPAN


def _grain(x, y, seed):
    """Fine, tileable pixel grain in [0, 1)."""
    return ((x % ROCK_PERIOD) * 73856093 ^ (y % ROCK_PERIOD) * 19349663 ^ seed * 83492791) % 1000 / 1000.0


# Cave rock (the owner's Tibia cave screenshots): masses of rounded light-grey boulders with dark
# crevices between them, on the same seamless span and block layout as the mountains.
# Darker and warmer than the mountains, so caves read as moody underground (plan 46 audit).
CAVE_ROCK = tuple(pal.CAVE_ROCK[:7])


# ---------------------------------------------------------------- materials

OAK = (rgba("a07a4c"), rgba("82603a"), rgba("5f4429"), rgba("3f2c1b"))
IRON = (rgba("8c8e8c"), rgba("5d605f"), rgba("3a3c3c"))


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


def hash_cell(x, y):
    value = (x * 73856093) ^ (y * 19349663) ^ 0x5F3759DF
    return value & 0x7FFFFFFF


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
        "title.png": title_painting(),
        "menu_icons.png": sheet_row([menu_icon(kind) for kind in MENU_ICONS]),
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
