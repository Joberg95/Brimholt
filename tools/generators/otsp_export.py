"""Writes the game's sprite sheets from the OpenTibia sprite pack (plan 49; otsp.py reads the pack).

  python tools/generators/otsp_export.py items     # assets/sprites/items.png (and a blank items_glow.png)
  python tools/generators/otsp_export.py outfits   # assets/sprites/outfits/<looktype>.png
  python tools/generators/otsp_export.py world     # assets/sprites/world.png and game/render/pack_atlas.gd
  python tools/generators/otsp_export.py palette   # assets/sprites/terrain_palette.png (the map editor's)

items.png holds every catalog item's pack sprite (items.json "sprite") in catalog order, ITEM_COLUMNS to a
row (SpriteArt.item_region). A two-by-two pack item is halved to fit its 32x32 cell.

An outfit sheet holds 72x72 frames of a pack outfit (players, townsfolk, and creatures), each placed as
the pack draws it so its tile centre is at (56, 56) (SpriteArt.OUTFIT_ANCHOR). Columns are stand, step A, step B, attack
wind-up, and strike (the pack has no attack frames: stand and step A stand in); rows are down, up, left,
right. A player outfit's sheet is five such blocks stacked: the untinted outfit, then the parts the pack's
colour mask marks as head, body, legs, and feet (yellow, red, green, blue), which the game tints like
Tibia does; a creature's sheet is the first block only.

world.png packs the pack's world things (WORLD_RANGES: grounds, borders, ways ...) for the floors and
objects: every pattern and animation frame of each, at its full size. pack_atlas.gd lists where each
lies (THINGS, RECTS) and the ground border sets (BORDERS).
"""
import json
import pathlib
import re
import struct
import sys
import zlib

import otsp

ROOT = pathlib.Path(__file__).resolve().parents[2]
ITEM_COLUMNS = 64
TILE = 32


def save_png(path, rows):
    """Writes RGBA rows (None for transparent)."""
    height, width = len(rows), len(rows[0])
    raw = b"".join(b"\0" + bytes(v for p in row for v in (p if p else (0, 0, 0, 0))) for row in rows)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def icon(sprite_id):
    """A pack item's first frame as a 32x32 icon (two-by-two items halved)."""
    rows = otsp.compose(otsp.load()["items"][sprite_id])
    if len(rows) == TILE and len(rows[0]) == TILE:
        return rows
    h, w = len(rows), len(rows[0])
    sy, sx = h / TILE, w / TILE
    return [[rows[int(y * sy)][int(x * sx)] for x in range(TILE)] for y in range(TILE)]


def items_sheet():
    catalog = json.load(open(ROOT / "game/data/items.json", encoding="utf-8"))["items"]
    rows_n = (len(catalog) + ITEM_COLUMNS - 1) // ITEM_COLUMNS
    sheet = [[None] * (ITEM_COLUMNS * TILE) for _ in range(rows_n * TILE)]
    for index, item in enumerate(catalog):
        ox, oy = (index % ITEM_COLUMNS) * TILE, (index // ITEM_COLUMNS) * TILE
        for y, row in enumerate(icon(item["sprite"])):
            sheet[oy + y][ox:ox + TILE] = row
    save_png(ROOT / "assets/sprites/items.png", sheet)
    save_png(ROOT / "assets/sprites/items_glow.png", [[None] * len(sheet[0]) for _ in sheet])
    print(f"wrote assets/sprites/items.png ({len(catalog)} items)")


# The player and townsfolk outfits (the pack's looktypes with a colour mask, a second layer); the
# creatures are every "outfit" in game/data/monsters.gd.
PLAYER_OUTFITS = [16, 17, 18, 20, 21, 45]
FRAME = 72
# Where the figure's tile centre sits in a frame (SpriteArt.OUTFIT_ANCHOR): the pack draws a thing
# from its tile's bottom-right corner, shifted up and left by its displacement.
ANCHOR = 56
# Our rows (down, up, left, right) in the pack's directions (north, east, south, west).
FACINGS = [2, 0, 3, 1]
POSES = [0, 1, 2, 0, 1]
MASK = [(255, 255, 0), (255, 0, 0), (0, 255, 0), (0, 0, 255)]


def creature_outfits():
    text = (ROOT / "game/data/monsters.gd").read_text(encoding="utf-8")
    return sorted({int(n) for n in re.findall(r'"outfit": (\d+)', text)})


def outfit_sheet(looktype):
    """FRAME frames, POSES by FACINGS; masked outfits stack their head, body, legs, and feet parts below."""
    thing = otsp.load()["outfits"][looktype]
    parts = 5 if thing.layers > 1 else 1
    rows = [[None] * (len(POSES) * FRAME) for _ in range(parts * len(FACINGS) * FRAME)]
    dx, dy = thing.displacement
    for row, facing in enumerate(FACINGS):
        for column, pose in enumerate(POSES):
            frame = pose % thing.frames
            base = otsp.compose(thing, px=facing, frame=frame)
            mask = otsp.compose(thing, layer=1, px=facing, frame=frame) if parts > 1 else None
            h, w = len(base), len(base[0])
            ox, oy = ANCHOR - (w - 16 + dx), ANCHOR - (h - 16 + dy)
            for y in range(h):
                for x in range(w):
                    pixel = base[y][x]
                    if pixel is None or not (0 <= ox + x < FRAME and 0 <= oy + y < FRAME):
                        continue
                    marked = mask[y][x][:3] if mask and mask[y][x] else None
                    part = MASK.index(marked) + 1 if marked in MASK else 0
                    rows[(part * len(FACINGS) + row) * FRAME + oy + y][column * FRAME + ox + x] = pixel
    return rows


def outfits():
    folder = ROOT / "assets/sprites/outfits"
    folder.mkdir(exist_ok=True)
    looktypes = sorted(set(PLAYER_OUTFITS) | set(creature_outfits()))
    for old in folder.glob("*.png"):
        if int(old.stem) not in looktypes:
            old.unlink()
    for looktype in looktypes:
        save_png(folder / f"{looktype}.png", outfit_sheet(looktype))
    print(f"wrote {len(looktypes)} outfit sheets to assets/sprites/outfits/")


# Pack items drawn in the world: grounds, ground borders, walls and rock, the ways down and up, doors,
# town objects, plants, trees, and stones, and the ores set into rock.
WORLD_RANGES = [(101, 214), (215, 517), (518, 994), (995, 1011), (1012, 1086), (1087, 1676), (2199, 2203)]
ATLAS_WIDTH = 2048
# Ground border sets: the pack lists each set's pieces in Tibia's order (BORDER_PIECES; the two moss sets
# have no diagonals), by first id. The snow set's pieces are out of order; 411 is a street's stone kerb.
BORDER_PIECES = ["n", "e", "s", "w", "cnw", "cne", "csw", "cse", "dnw", "dne", "dsw", "dse"]
STANDARD_BORDERS = {215: 12, 227: 12, 239: 12, 251: 12, 263: 8, 271: 8, 279: 12, 291: 12, 303: 12, 315: 12, 327: 12,
                    339: 12, 351: 12, 363: 12, 375: 12, 387: 12}
EXTRA_BORDERS = {399: {"n": 399, "e": 400, "s": 401, "w": 402, "cnw": 407, "cne": 408, "csw": 409, "cse": 410},
                 411: {"n": 411, "e": 412, "s": 413, "w": 414, "cnw": 415, "cne": 416, "csw": 417, "cse": 418}}


def world():
    items = otsp.load()["items"]
    pieces = []  # (id, rows)
    things = {}
    for first, last in WORLD_RANGES:
        for tid in range(first, last + 1):
            thing = items[tid]
            things[tid] = [thing.px, thing.py, thing.frames, thing.width * TILE, thing.height * TILE, len(pieces)]
            for frame in range(thing.frames):
                for py in range(thing.py):
                    for px in range(thing.px):
                        pieces.append(otsp.compose(thing, px=px, py=py, frame=frame))
    # Shelf packing, tallest first so rows fill evenly; RECTS keeps the pieces' own order.
    order = sorted(range(len(pieces)), key=lambda i: -len(pieces[i]))
    rects = [None] * len(pieces)
    x = y = shelf = 0
    for i in order:
        h, w = len(pieces[i]), len(pieces[i][0])
        if x + w > ATLAS_WIDTH:
            x, y, shelf = 0, y + shelf, 0
        rects[i] = (x, y)
        x, shelf = x + w, max(shelf, h)
    sheet = [[None] * ATLAS_WIDTH for _ in range(y + shelf)]
    for i, (rx, ry) in enumerate(rects):
        for dy, row in enumerate(pieces[i]):
            sheet[ry + dy][rx:rx + len(row)] = row
    save_png(ROOT / "assets/sprites/world.png", sheet)
    found = {first: {BORDER_PIECES[k]: first + k for k in range(count)} for first, count in STANDARD_BORDERS.items()}
    found.update(EXTRA_BORDERS)

    def wrap(entries, indent="\t"):
        lines, line = [], indent
        for entry in entries:
            if len(line) + len(entry) > 116:
                lines.append(line.rstrip())
                line = indent
            line += entry + " "
        lines.append(line.rstrip())
        return "\n".join(lines)
    text = """extends RefCounted
## Generated by tools/generators/otsp_export.py world (plan 49): where the OpenTibia pack's world things
## lie in assets/sprites/world.png. Do not edit by hand.

const TEXTURE: Texture2D = preload("res://assets/sprites/world.png")
## Pack id -> [patterns x, patterns y, frames, width, height, first piece]. A thing's pieces run
## frame by frame, row by row of its patterns; piece i's top-left corner is RECTS[2 i], RECTS[2 i + 1].
const THINGS: Dictionary = {
%s
}
const RECTS: Array[int] = [
%s
]
## Ground border sets by first id: Tibia's border pieces (n, e, s, w; cnw, cne, csw, cse small corners;
## dnw, dne, dsw, dse large diagonals) -> pack id.
const BORDERS: Dictionary = {
%s
}
""" % (wrap(["%d: [%s]," % (k, ", ".join(map(str, v))) for k, v in things.items()]),
       wrap(["%d, %d," % r for r in rects]),
       "\n".join("\t%d: {%s}," % (k, ", ".join('"%s": %d' % kv for kv in v.items())) for k, v in sorted(found.items())))
    (ROOT / "game/render/pack_atlas.gd").write_text(text, encoding="utf-8", newline="\n")
    print(f"wrote assets/sprites/world.png ({ATLAS_WIDTH}x{len(sheet)}, {len(pieces)} pieces) and game/render/pack_atlas.gd")


# The map editor's palette: one 32x32 tile per terrain in tools/generators/make_map.gd TERRAINS order,
# each the pack thing the game draws for it (larger things halved, like item icons).
PALETTE = {".": 106, ",": 140, "~": 163, "#": 534, "T": 1504, ":": 126, "=": 154, "b": 172, "d": 116, "o": 162, "O": 891,
           "D": 1512, "c": 139, "C": 956, "v": 995, "^": 1009, "K": 1576, "R": 1501, "L": 957, "W": 542, "m": 141,
           "U": 1585, "s": 145, "P": 1505, "F": 155, "Y": 176}


def palette():
    text = (ROOT / "tools/generators/make_map.gd").read_text(encoding="utf-8")
    terrains = re.findall(r'"(.)"', re.search(r"const TERRAINS: Array\[String\] = \[(.*?)\]", text).group(1))
    sheet = [[None] * (len(terrains) * TILE) for _ in range(TILE)]
    for index, terrain in enumerate(terrains):
        for y, row in enumerate(icon(PALETTE[terrain])):
            sheet[y][index * TILE:(index + 1) * TILE] = row
    save_png(ROOT / "assets/sprites/terrain_palette.png", sheet)
    print(f"wrote assets/sprites/terrain_palette.png ({len(terrains)} terrains)")


if __name__ == "__main__":
    {"items": items_sheet, "outfits": outfits, "world": world, "palette": palette}[sys.argv[1]]()
