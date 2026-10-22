"""Reads the OpenTibia sprite pack's client files (assets/third_party/opentibia_sprite_pack/client_files,
CC BY 4.0, see assets/third_party/CREDITS.md): otsp.dat (every thing's flags and sprite ids, protocol
10.41) and otsp.spr (the 32x32 sprites). Things come in four lists: items (ids from 100), outfits
(players and creatures, ids from 1), effects, and missiles.

  things = load()                     # {"items": {id: Thing}, "outfits": {...}, ...}
  image = compose(things["items"][2400])   # its first frame as RGBA rows, w*32 by h*32
"""
import pathlib
import struct

ROOT = pathlib.Path(__file__).resolve().parents[2] / "assets/third_party/opentibia_sprite_pack/client_files"
# Flag byte -> the size in bytes of the data that follows it (protocol 10.10+ metadata).
FLAG_DATA = {0x00: 2, 0x08: 2, 0x09: 2, 0x16: 4, 0x19: 4, 0x1A: 2, 0x1D: 2, 0x1E: 2, 0x21: 2, 0x23: 2}
MARKET = 0x22
# How far up and left a thing is drawn from its tile (creatures and outfits: usually 8, 8).
DISPLACEMENT = 0x19


class Thing:
    def __init__(self, kind, tid):
        self.kind, self.id = kind, tid
        self.flags = set()
        self.width = self.height = 1
        self.layers = self.px = self.py = self.pz = self.frames = 1
        self.sprites = []
        self.market_name = ""
        self.displacement = (0, 0)

    def sprite_index(self, x, y, layer=0, px=0, py=0, pz=0, frame=0):
        """The index into `sprites` of one 32x32 tile of one frame (x, y counted from the bottom right)."""
        return ((((((frame * self.pz + pz) * self.py + py) * self.px + px) * self.layers + layer) * self.height + y)
                * self.width + x)


def _things(data):
    pos = 4
    counts = struct.unpack_from("<4H", data, pos)
    pos += 8
    out = {"items": {}, "outfits": {}, "effects": {}, "missiles": {}}
    ranges = (("items", 100, counts[0]), ("outfits", 1, counts[1]), ("effects", 1, counts[2]), ("missiles", 1, counts[3]))
    for kind, first, last in ranges:
        for tid in range(first, last + 1):
            thing = Thing(kind, tid)
            while True:
                flag = data[pos]
                pos += 1
                if flag == 0xFF:
                    break
                thing.flags.add(flag)
                if flag == MARKET:
                    pos += 6
                    name_len = struct.unpack_from("<H", data, pos)[0]
                    pos += 2
                    thing.market_name = data[pos:pos + name_len].decode("latin-1")
                    pos += name_len + 4
                else:
                    if flag == DISPLACEMENT:
                        thing.displacement = struct.unpack_from("<2H", data, pos)
                    pos += FLAG_DATA.get(flag, 0)
            thing.width, thing.height = data[pos], data[pos + 1]
            pos += 2
            if thing.width > 1 or thing.height > 1:
                pos += 1  # exact size
            thing.layers, thing.px, thing.py, thing.pz, thing.frames = data[pos:pos + 5]
            pos += 5
            n = thing.width * thing.height * thing.layers * thing.px * thing.py * thing.pz * thing.frames
            thing.sprites = list(struct.unpack_from(f"<{n}I", data, pos))
            pos += 4 * n
            out[kind][tid] = thing
    return out


class Sprites:
    """The 32x32 sprites of otsp.spr, decoded on demand."""

    def __init__(self, data):
        self.data = data
        self.count = struct.unpack_from("<I", data, 4)[0]

    def get(self, sid):
        """RGBA rows (None for transparent) of sprite `sid`, or None for the empty sprite."""
        if sid == 0 or sid > self.count:
            return None
        offset = struct.unpack_from("<I", self.data, 8 + (sid - 1) * 4)[0]
        if offset == 0:
            return None
        size = struct.unpack_from("<H", self.data, offset + 3)[0]
        pos, end = offset + 5, offset + 5 + size
        pixels = [None] * 1024
        i = 0
        while pos < end and i < 1024:
            transparent, coloured = struct.unpack_from("<2H", self.data, pos)
            pos += 4
            i += transparent
            for _ in range(coloured):
                if i < 1024:
                    pixels[i] = (self.data[pos], self.data[pos + 1], self.data[pos + 2], 255)
                pos += 3
                i += 1
        return [pixels[y * 32:(y + 1) * 32] for y in range(32)]


_CACHE = {}


def load():
    """All things (by kind) and the sprites, read once."""
    if not _CACHE:
        _CACHE["things"] = _things((ROOT / "otsp.dat").read_bytes())
        _CACHE["sprites"] = Sprites((ROOT / "otsp.spr").read_bytes())
    return _CACHE["things"]


def compose(thing, layer=0, px=0, py=0, pz=0, frame=0):
    """One frame of a thing as RGBA rows, width*32 by height*32 (multi-tile things grow up and left)."""
    load()
    sprites = _CACHE["sprites"]
    w, h = thing.width * 32, thing.height * 32
    out = [[None] * w for _ in range(h)]
    for ty in range(thing.height):
        for tx in range(thing.width):
            tile = sprites.get(thing.sprites[thing.sprite_index(tx, ty, layer, px, py, pz, frame)])
            if tile is None:
                continue
            ox, oy = w - (tx + 1) * 32, h - (ty + 1) * 32
            for y in range(32):
                for x in range(32):
                    if tile[y][x]:
                        out[oy + y][ox + x] = tile[y][x]
    return out
