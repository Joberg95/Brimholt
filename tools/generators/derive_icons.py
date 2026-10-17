#!/usr/bin/env python3
"""Derives painted-style icons for items without painted art, from the painted icons we have.

Each item without a painted icon (assets/sprites/icons/<id>.png, imported by
tools/generators/import_outfits.gd) takes a painted template of the same kind (TEMPLATES, or
for helmets, armor, legs, and boots bands of two or three painted pieces of the same slot and
armor type stacked into a new design: armor_bases), recoloured to its catalog colours: outlines stay, wood stays wood, gold trim takes the
item's accent colour, and every other pixel is mapped by its brightness onto a ramp from the
item's main colour to its light colour. Templates are ordered plain to ornate and picked by the
item's level. Results go to assets/sprites/icons_derived/<id>.png (rewritten every run); the
game and make_sprites.py use a painted icon first, then a derived one, then the generated
items.png cell. Kinds with no template (axes, maces, hammers, crossbows, capes, packs, torches,
potions, most materials) keep their generated icons.

    python3 tools/generators/derive_icons.py
"""
import colorsys
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_sprites as M  # noqa: E402

PAINTED = M.ROOT / "assets" / "sprites" / "icons"
DERIVED = M.ROOT / "assets" / "sprites" / "icons_derived"
ARMOR_SLOTS = ("helmet", "armor", "legs", "boots")
# Look -> painted templates, plain to ornate ("template_*" icons come from art/outfits/manifest.json).
TEMPLATES = {
    "heater": ["template_pieces_shield", "template_crimson_aegis_offhand", "template_golden_lion_offhand",
               "embersteel_aegis", "wyrmglass_ward"],
    "tower": ["template_pieces_shield", "template_golden_lion_offhand", "embersteel_aegis", "wyrmglass_ward"],
    "buckler": ["template_pieces_offhand"],
    "bow": ["template_pieces_bow", "template_windrider_weapon", "template_shadowstalker_weapon", "ember_recurve",
            "dusk_longbow"],
    "wand": ["template_pieces_wand", "storm_wand", "blaze_wand", "starfire_wand", "wyrmglass_wand"],
    "rod": ["template_pieces_staff", "tide_rod", "emberthorn_rod", "duskbloom_rod", "starbloom_rod"],
    "book": ["template_pieces_book"],
    "charm": ["template_verdant_spirit_offhand", "template_wildroot_offhand"],
    "orb": ["template_astral_veil_offhand", "template_arcane_eclipse_offhand"],
    "crystal": ["template_wildroot_offhand"],
}
# Templates whose own colours already suit any recolour as wood (brown, low saturation, dark).
WOODEN = {"bow", "rod", "wand", "book", "buckler"}


def hls(color):
    return colorsys.rgb_to_hls(*(channel / 255 for channel in color[:3]))


def rgb(h, l, s):
    return tuple(round(channel * 255) for channel in colorsys.hls_to_rgb(h, max(0.0, min(1.0, l)), max(0.0, min(1.0, s)))) + (255,)


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def ramp(main, light, t):
    """Brightness 0..1 onto dark main, main, light, and a near-white highlight."""
    dark = M.scale(main, 0.32)
    shine = mix(light, M.rgba("ffffff"), 0.45)
    stops = [(0.0, dark), (0.42, main), (0.78, light), (1.0, shine)]
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        if t <= t1:
            return mix(c0, c1, (t - t0) / (t1 - t0))
    return shine


def is_gold(h, l, s):
    return 0.08 <= h <= 0.17 and s >= 0.35 and l >= 0.35


def is_wood(h, l, s):
    return 0.03 <= h <= 0.12 and 0.15 <= s <= 0.75 and l < 0.42


def recolour(template, item, wooden):
    main, light, accent = (M.rgba(c) for c in item["colors"][:3])
    pixels = [(x, y, template.pixels[y][x]) for y in range(template.height) for x in range(template.width)
              if template.pixels[y][x] is not None]
    body = [hls(c) for _, _, c in pixels]
    ranged = [l for h, l, s in body if l >= 0.12 and not is_gold(h, l, s) and not (wooden and is_wood(h, l, s))]
    low, high = (min(ranged), max(ranged)) if ranged else (0.12, 1.0)
    ah, al, a_s = hls(accent)
    result = M.Image(template.width, template.height)
    for x, y, color in pixels:
        h, l, s = hls(color)
        if l < 0.12 or (wooden and is_wood(h, l, s)):
            result.pixels[y][x] = color
        elif is_gold(h, l, s):
            result.pixels[y][x] = rgb(ah, l * (0.6 + al * 0.8), max(a_s, s * 0.6))
        else:
            result.pixels[y][x] = ramp(main, light, (l - low) / max(0.05, high - low))
    return result


def hollow(image):
    """Clears large near-black areas enclosed by the item (the gap between a bow's
    limb and string): dark regions of at least 12 pixels at least 85% surrounded by the item."""
    dark = {(x, y) for y in range(image.height) for x in range(image.width)
            if image.pixels[y][x] is not None and hls(image.pixels[y][x])[1] < 0.16}
    seen = set()
    for start in sorted(dark):
        if start in seen:
            continue
        region, queue = [], [start]
        seen.add(start)
        while queue:
            x, y = queue.pop()
            region.append((x, y))
            for near in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if near in dark and near not in seen:
                    seen.add(near)
                    queue.append(near)
        # Enclosed: (almost) every neighbour outside the region is part of the item.
        border = [image.get(nx, ny) is not None for x, y in region
                  for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)) if (nx, ny) not in region]
        if len(region) >= 12 and border and sum(border) >= 0.85 * len(border):
            for x, y in region:
                image.pixels[y][x] = None
    return image


def painted(kind):
    path = PAINTED / f"{kind}.png"
    return M.Image.load(path) if path.exists() else None


# A derived armour piece is cut into bands across its height, each band from a different painted
# piece (BANDS: shares of the height where one band ends and the next begins), so every piece is
# a new design in the painted style: a helmet's crown over another's face, body armour's
# shoulders, belly, and skirt from three pieces, legs' hips, thighs, and shins, boots' shafts and feet.
BANDS = {"helmet": [(0.45,), (0.62,)], "armor": [(0.36, 0.66), (0.5,), (0.4,)], "legs": [(0.3, 0.62), (0.5,)],
         "boots": [(0.4, 0.7), (0.55,)]}


def _span(image, y):
    xs = [x for x in range(image.width) if image.pixels[y][x] is not None]
    return (xs[0], xs[-1]) if xs else None


def _rows(image):
    rows = [y for y in range(image.height) if any(image.pixels[y])]
    return rows[0], rows[-1]


def _meets(upper, lower, y):
    """Whether two painted pieces have about the same edges at row y and the row above it."""
    for row in (y - 1, y):
        a, b = _span(upper, row), _span(lower, row)
        if a is None or b is None or abs(a[0] - b[0]) > 1 or abs(a[1] - b[1]) > 1:
            return False
    return True


def _cuts(image, shares):
    top, bottom = _rows(image)
    return [top + round((bottom - top) * share) for share in shares]


def _combos(first, pool, shares):
    """Every list of len(shares) + 1 different pieces, starting with `first`, that meet cleanly at
    the cuts (taken from the first piece's height)."""
    cuts = _cuts(painted(first), shares)
    found = []

    def extend(chain):
        if len(chain) == len(shares) + 1:
            found.append(tuple(chain))
            return
        upper = painted(chain[-1])
        for other in pool:
            if other not in chain and _meets(upper, painted(other), cuts[len(chain) - 1]):
                extend(chain + [other])

    extend([first])
    return found


def armor_bases():
    """{item: (pieces, shares)} for every unpainted tier helmet, armour, legs, and boots: two or
    three painted pieces of the same slot and armor type (relics: plate), cut into bands at
    `shares` of the height, preferring pieces near the item's level, never the same combination
    twice, and spreading the work over all the painted pieces so none dominates."""
    bases = {}
    groups = {}
    for kind, item in M.ITEMS.items():
        if item.get("slot") in ARMOR_SLOTS:
            groups.setdefault((item["slot"], item.get("armor", "plate")), []).append(kind)
    for (slot, armor), kinds in sorted(groups.items()):
        pool = sorted(k for k in kinds if (PAINTED / f"{k}.png").exists())
        if len(pool) < 2:
            continue
        uses = {k: 0 for k in pool}
        taken = set()
        todo = sorted((k for k in kinds if k not in pool and M.look(k)[0] not in M.SHOWPIECE_STYLES),
                      key=lambda k: (M.ITEMS[k]["level"], k))
        # Pieces of the same slot but another armor type, for looks no piece of their own type fits.
        wider = sorted(k for k, entry in M.ITEMS.items() if entry.get("slot") == slot and (PAINTED / f"{k}.png").exists())
        for kind in todo:
            level = M.ITEMS[kind]["level"]
            template = M.ITEMS[kind].get("template")
            best = None
            for choices in (pool, wider):
                for shares in BANDS[slot]:
                    for first in choices:
                        for combo in _combos(first, choices, shares):
                            if combo in taken:
                                continue
                            # Near in level, pieces not used much yet, three bands before two, and a
                            # catalog template (the mythic sets' chosen look) among the bands.
                            score = (sum(abs(M.ITEMS[k]["level"] - level) for k in combo) / len(combo) / 10.0
                                     + sum(uses.get(k, 0) for k in combo) * 1.5 - len(combo) * 2.0
                                     - (2.5 if template in combo else 0.0))
                            if best is None or score < best[0]:
                                best = (score, combo, shares)
                if best is not None:
                    break
            if best is None:
                continue
            _, combo, shares = best
            taken.add(combo)
            for k in combo:
                uses[k] = uses.get(k, 0) + 1
            bases[kind] = (combo, shares)
    return bases


def armor_base(kind, bases):
    """The painted art an armour piece is recoloured from: its pieces' bands stacked."""
    combo, shares = bases[kind]
    images = [painted(k) for k in combo]
    cuts = _cuts(images[0], shares) + [images[0].height]
    out = M.Image(images[0].width, images[0].height)
    band = 0
    for y in range(out.height):
        while y >= cuts[band]:
            band += 1
        out.pixels[y] = list(images[band].pixels[y])
    return out


def template_for(kind, item):
    if item.get("template") and (PAINTED / f"{item['template']}.png").exists():
        return item["template"]
    shape = M.look(kind)[0]
    choices = [name for name in TEMPLATES.get(shape, []) if (PAINTED / f"{name}.png").exists()]
    if not choices:
        return None
    rank = min(len(choices) - 1, max(0, item.get("level", 1) - 1) * len(choices) // 50)
    return choices[rank]


def main():
    DERIVED.mkdir(parents=True, exist_ok=True)
    for old in DERIVED.glob("*.png"):
        old.unlink()
    made, skipped = 0, []
    bases = armor_bases()
    for kind, item in M.ITEMS.items():
        # Showpiece helmets and boots draw their own icon (make_sprites.py helm_icon).
        if (PAINTED / f"{kind}.png").exists() or not item.get("colors") or M.look(kind)[0] in M.SHOWPIECE_STYLES:
            continue
        shape = M.look(kind)[0]
        if kind in bases:
            icon = recolour(armor_base(kind, bases), item, False)
        else:
            name = template_for(kind, item)
            if name is None:
                skipped.append(kind)
                continue
            icon = recolour(painted(name), item, shape in WOODEN)
        if shape == "bow":
            icon = hollow(icon)
        M.icon_finish(M.icon_volume(icon)).save(DERIVED / f"{kind}.png")
        made += 1
    print(f"derived {made} icons into {DERIVED.relative_to(M.ROOT)}; {len(skipped)} keep generated icons")
    # The painted icons get the repeatable part of the shared finish (outline and contrast).
    for path in sorted(PAINTED.glob("*.png")):
        M.icon_finish(M.Image.load(path), rim=False).save(path)


if __name__ == "__main__":
    main()
