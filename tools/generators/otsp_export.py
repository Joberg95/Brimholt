"""Writes the game's sprite sheets from the OpenTibia sprite pack (plan 49; otsp.py reads the pack).

  python tools/generators/otsp_export.py items     # assets/sprites/items.png (and a blank items_glow.png)
  python tools/generators/otsp_export.py outfits   # assets/sprites/outfits/<looktype>.png

items.png holds every catalog item's pack sprite (items.json "sprite") in catalog order, ITEM_COLUMNS to a
row (SpriteArt.item_region). A two-by-two pack item is halved to fit its 32x32 cell.

An outfit sheet holds the pack outfit's 64x64 frames as the pack draws them (its tile is the bottom-right
quarter, shifted 8 pixels up and left: SpriteArt.OUTFIT_ANCHOR). Columns are stand, step A, step B, attack
wind-up, and strike (the pack has no attack frames: stand and step A stand in); rows are down, up, left,
right. The sheet is five such blocks stacked: the untinted outfit, then the parts the pack's colour mask
marks as head, body, legs, and feet (yellow, red, green, blue), which the game tints like Tibia does.
"""
import json
import pathlib
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


# The player outfits: the pack's looktypes with a colour mask (a second layer).
OUTFITS = [16, 17, 18, 20, 21, 45]
FRAME = 64
# Our rows (down, up, left, right) in the pack's directions (north, east, south, west).
FACINGS = [2, 0, 3, 1]
POSES = [0, 1, 2, 0, 1]
MASK = [(255, 255, 0), (255, 0, 0), (0, 255, 0), (0, 0, 255)]


def outfit_sheet(looktype):
    thing = otsp.load()["outfits"][looktype]
    rows = [[None] * (len(POSES) * FRAME) for _ in range(5 * len(FACINGS) * FRAME)]
    for row, facing in enumerate(FACINGS):
        for column, pose in enumerate(POSES):
            base = otsp.compose(thing, px=facing, frame=pose)
            mask = otsp.compose(thing, layer=1, px=facing, frame=pose) if thing.layers > 1 else None
            for y in range(FRAME):
                for x in range(FRAME):
                    pixel = base[y][x]
                    if pixel is None:
                        continue
                    marked = mask[y][x][:3] if mask and mask[y][x] else None
                    part = MASK.index(marked) + 1 if marked in MASK else 0
                    rows[(part * len(FACINGS) + row) * FRAME + y][column * FRAME + x] = pixel
    return rows


def outfits():
    folder = ROOT / "assets/sprites/outfits"
    folder.mkdir(exist_ok=True)
    for looktype in OUTFITS:
        save_png(folder / f"{looktype}.png", outfit_sheet(looktype))
    print(f"wrote {len(OUTFITS)} outfit sheets to assets/sprites/outfits/")


if __name__ == "__main__":
    {"items": items_sheet, "outfits": outfits}[sys.argv[1]]()
