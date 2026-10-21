"""The master palette (docs/plan/46-modern-tibia-direction.md, phase 1): one saturated ramp per
material in the modern-Tibia look, shared by every generator.

Each ramp runs light to dark, 6-10 tones: warm, bright lights, cooler and more saturated shadows,
and a near-black core. Outlines are not in the ramp: outline(ramp) gives the material's own
hue-tinted near-black (the painted class sets in art/outfits outline in #100808, not grey or pure
black). The glow ramps (EMBER, HOLLOW, HOLLOW_GLOW, WAKE_GLOW) are for light sources, magic, relics,
and the regions their flavour pillar names; never for ordinary things.

Generators still use their own module ramps (pixel_floors.GRASS, make_sprites.ROCK, ...); each
family switches to these when it is repainted in phase 4 of plan 46. New art uses these from now on.
Tune a ramp here, never with a copy in a builder.

  python3 tools/generators/palette.py [--swatch .tools/palette.png]

checks every ramp and the region table against game/data/regions.gd, and writes a swatch sheet
(one row per ramp, then its outline) to look at.
"""

import argparse
import colorsys
import os
import re
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def _hex(value, alpha=255):
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha)


def _ramp(*values):
    return tuple(_hex(value) for value in values)


# Ground and plants.
GRASS = _ramp("b3d660", "91ba4f", "75a141", "5b8a34", "457429", "315e1f", "214816", "13330e")
FOLIAGE = _ramp("9fcc52", "79af42", "5a9634", "3f7f29", "28681f", "165216", "0f3c14", "082610")
FIR = _ramp("5ca35a", "498d50", "3b7949", "2f6743", "24553c", "1b4333", "12322a", "0b211e")
REED = _ramp("d9e667", "afc453", "8ca742", "6c8b33", "507126", "38571b", "233d11")
MOSS = _ramp("8fb853", "6a9740", "4c7b30", "336123", "1e4717", "0f2e0e")
DIRT = _ramp("bd9d6d", "a4835b", "8f6d4b", "7b593d", "684730", "553725", "43281b", "301a12")
CAVE_EARTH = _ramp("a37052", "8d5c44", "7a4b38", "683c2e", "562f24", "45231c", "341814", "240f0d")
SAND = _ramp("f5e4ab", "dcc791", "c7ae7a", "b39666", "a07f54", "8d6a44", "7a5636")
SNOW = _ramp("f7fcff", "dbe2ec", "c3cbdb", "acb5cb", "96a0bc", "818bad", "6c779e")
ICE = _ramp("defafc", "b5dce2", "93c0ca", "75a4b4", "5b8a9f", "44708a", "315875")
BOG = _ramp("888f4f", "6e7840", "576534", "435329", "31411f", "223016", "141f0d")

# Water.
WATER = _ramp("8bdcf0", "6eb7d2", "5697b9", "427aa1", "305f8a", "224673", "16315d", "0d1e47")
DEEP_SEA = _ramp("366d9e", "285384", "1c3d6d", "132a57", "0c1a42", "060e2e")
BOG_WATER = _ramp("538052", "406945", "31553c", "244233", "193028", "0f1f1c")

# Stone and building.
GRAVEL = _ramp("c7bfaf", "a8a297", "8e8a83", "74726f", "5c5c5c", "44464a", "2d3038")
COBBLE = _ramp("d6d0c1", "b7b2a7", "9c9890", "82807b", "696866", "505152", "383a3f", "21232b")
FIELDSTONE = _ramp(
    "d1dae0", "b4bcc3", "9ca3a9", "858a91", "6e737a",
    "585c63", "43454d", "2d2f37", "191921",
)
ROCK = _ramp(
    "d1c7b8", "b4aca0", "9c958c", "847f79", "6d6966",
    "575454", "414042", "2c2c30", "17181f",
)
CAVE_ROCK = _ramp("94877c", "7d726a", "69605b", "564f4c", "443e3d", "322e30", "201e22", "0f0e14")
SANDSTONE = _ramp("edd8a6", "d0b88a", "b79c73", "a0825e", "896a4c", "73533b", "5d3f2c", "472d1f")
BRICK = _ramp("b86e53", "9e5744", "894538", "74342d", "602623", "4c1a1a", "391214", "260b0e")
OAK = _ramp("d6af74", "b98f5e", "9f754d", "875d3d", "6f472f", "583423", "412318", "2b140f")
DARK_WOOD = _ramp("8f6447", "774d39", "633a2e", "502a23", "3d1c1a", "2b1112", "190a0b")
THATCH = _ramp("ebd375", "cbb061", "b09251", "967742", "7d5e34", "644828", "4c331d")

# Gear and bodies.
IRON = _ramp("dfe5eb", "bdc2c8", "9fa4a9", "83878d", "686c71", "4e5156", "34363b", "1b1c21")
GOLD = _ramp("fff494", "e0cc73", "c5a958", "ac8742", "93692f", "7b4d1f", "643413", "4d2009")
BRONZE = _ramp("f5c689", "cf9c69", "af794f", "905939", "723e27", "552719", "38150d")
LEATHER = _ramp("c29161", "a2734d", "87593c", "6d432e", "542f21", "3c1e16", "24100c")
BONE = _ramp("faf5e1", "dcd4bd", "c3b89e", "ab9c83", "93826b", "7c6a55", "665241")
SKIN = _ramp("ffe0c2", "dab498", "ba8e75", "9b6c58", "7e4e3f", "61342b")

# Glow (light sources, magic, relics only).
EMBER = _ramp("fff78c", "e8d06f", "d4ab56", "c18741", "af642e", "9d431e", "8c2511", "7a0a06")
HOLLOW = _ramp("a783c7", "8767a8", "6c518e", "543d75", "3e2c5d", "2a1e45", "19122e", "0b0817")
HOLLOW_GLOW = _ramp("f6d1ff", "cc9adf", "a56ec3", "8049a8", "5e2c8e", "3f1575")
WAKE_GLOW = _ramp("ccffe6", "96dcbf", "6abea2", "47a28b", "2b8677", "156b64")

## Every ramp by name, in swatch order.
RAMPS = {name: value for name, value in globals().items() if name.isupper() and isinstance(value, tuple)}

# Region identity (the flavour pillars in plan 46): the ground ramp and the accent each region is
# painted with on top of the shared style. Towns use "castle" and the Hollow Reach zone "hollow"
# whatever region they stand in.
IDENTITY = {
    "meadow": {"ground": "GRASS", "accent": "REED", "regions": [
        "Cinder Meadows", "Westwind Coast", "Thornfield Wilds", "Lastlight Downs", "Bracken Leas",
        "Hazel Downs"]},
    "wetland": {"ground": "BOG", "accent": "WATER", "regions": [
        "Lurkmoor", "Stillwater Shore", "Mirewood Fen", "Fernmere", "Saltreed Marsh"]},
    "woodland": {"ground": "FOLIAGE", "accent": "FIR", "regions": [
        "Greywood", "Gloamwood", "Wolfholt", "Silverwood"]},
    "waking_stone": {"ground": "ROCK", "accent": "WAKE_GLOW", "regions": [
        "Golemback Hills", "Stonevale", "Greycrag Peaks", "Kestrel Heights", "Outlaw Ridge",
        "Barrowmoor"]},
    "ember": {"ground": "CAVE_EARTH", "accent": "EMBER", "regions": [
        "Smoulder Fells", "Emberwaste", "Grimtusk Hold"]},
    "hollow": {"ground": "HOLLOW", "accent": "HOLLOW_GLOW", "regions": ["Hollow March"]},
    "desert": {"ground": "SAND", "accent": "SANDSTONE", "regions": ["Sunscar Dunes"]},
    "frost": {"ground": "SNOW", "accent": "ICE", "regions": [
        "Hrimfold Tundra", "Wolfskerry", "Rimewater Floes"]},
    "castle": {"ground": "FIELDSTONE", "accent": "EMBER", "regions": []},
}


def outline(ramp):
    """The material's outline: its darkest tone's hue at near-black."""
    r, g, b, _ = ramp[-1]
    h, s, _ = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    r, g, b = colorsys.hsv_to_rgb(h, min(0.6, s + 0.1), 0.08)
    return (round(r * 255), round(g * 255), round(b * 255), 255)


def _value(colour):
    return max(colour[:3])


def check():
    """Every problem with the ramps and the region table, as messages."""
    problems = []
    for name, ramp in RAMPS.items():
        if not 6 <= len(ramp) <= 10:
            problems.append("%s has %d tones (6-10)" % (name, len(ramp)))
        for a, b in zip(ramp, ramp[1:]):
            if _value(b) >= _value(a):
                problems.append("%s is not light to dark" % name)
                break
    for key, entry in IDENTITY.items():
        for part in ("ground", "accent"):
            if entry[part] not in RAMPS:
                problems.append("%s: unknown ramp %s" % (key, entry[part]))
    with open(os.path.join(ROOT, "game", "data", "regions.gd"), encoding="utf-8") as handle:
        source = handle.read()
    names = set(re.findall(r'^\t\["([^"]+)", Vector2i', source, re.M))
    names |= set(re.findall(r'^const DESERT: String = "([^"]+)"', source, re.M))
    listed = [name for entry in IDENTITY.values() for name in entry["regions"]]
    for name in sorted(names - set(listed)):
        problems.append("region %s has no identity" % name)
    for name in sorted(set(listed) - names):
        problems.append("identity lists unknown region %s" % name)
    for name in sorted({name for name in listed if listed.count(name) > 1}):
        problems.append("region %s has two identities" % name)
    return problems


def swatch(path, cell=16):
    """A PNG with one row per ramp: its tones, a gap, then its outline."""
    columns = max(len(ramp) for ramp in RAMPS.values()) + 2
    width, height = columns * cell, len(RAMPS) * cell
    background = (40, 40, 40)
    rows = []
    for ramp in RAMPS.values():
        colours = [tone[:3] for tone in ramp]
        colours += [background] * (columns - 1 - len(ramp)) + [outline(ramp)[:3]]
        line = b"".join(bytes(colour) * cell for colour in colours)
        rows += [b"\x00" + line] * cell

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(b"\x89PNG\r\n\x1a\n")
        handle.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)))
        handle.write(chunk(b"IDAT", zlib.compress(b"".join(rows))))
        handle.write(chunk(b"IEND", b""))


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--swatch", help="write a swatch sheet PNG here")
    args = parser.parse_args()
    problems = check()
    for problem in problems:
        print(problem, file=sys.stderr)
    if args.swatch:
        swatch(args.swatch)
        print("wrote %s (%d ramps)" % (args.swatch, len(RAMPS)))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
