"""Writes the game's sprite sheets from the OpenTibia sprite pack (plan 49; otsp.py reads the pack).

  python tools/generators/otsp_export.py items     # assets/sprites/items.png (and a blank items_glow.png)
  python tools/generators/otsp_export.py outfits   # assets/sprites/outfits/<looktype>.png

items.png holds every catalog item's pack sprite (items.json "sprite") in catalog order, ITEM_COLUMNS to a
row (SpriteArt.item_region). A two-by-two pack item is halved to fit its 32x32 cell.

An outfit sheet holds 72x72 frames of a pack outfit (players, townsfolk, and creatures), each placed as
the pack draws it so its tile centre is at (56, 56) (SpriteArt.OUTFIT_ANCHOR). Columns are stand, step A, step B, attack
wind-up, and strike (the pack has no attack frames: stand and step A stand in); rows are down, up, left,
right. A player outfit's sheet is five such blocks stacked: the untinted outfit, then the parts the pack's
colour mask marks as head, body, legs, and feet (yellow, red, green, blue), which the game tints like
Tibia does; a creature's sheet is the first block only.
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


if __name__ == "__main__":
    {"items": items_sheet, "outfits": outfits}[sys.argv[1]]()
