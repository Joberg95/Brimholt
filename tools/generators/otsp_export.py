"""Writes the game's sprite sheets from the OpenTibia sprite pack (plan 49; otsp.py reads the pack).

  python tools/generators/otsp_export.py items     # assets/sprites/items.png (and a blank items_glow.png)

items.png holds every catalog item's pack sprite (items.json "sprite") in catalog order, ITEM_COLUMNS to a
row (SpriteArt.item_region). A two-by-two pack item is halved to fit its 32x32 cell.
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


if __name__ == "__main__":
    {"items": items_sheet}[sys.argv[1]]()
