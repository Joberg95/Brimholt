"""Maps Brimholt's items onto the OpenTibia sprite pack's item sprites (plan 49, phase 2).

Each pack equipment sprite serves one item. Within a category our items are matched to sprites in level
order against the sprites' richness (plain sprites for low tiers, ornate ones for high), with the
item's own colours as the tie-breaker; an item left without a sprite is to be deleted.

  python tools/generators/otsp_items.py            # writes otsp_items.json: {item id: pack id or null}
"""
import colorsys
import json
import pathlib
import sys

import otsp

ROOT = pathlib.Path(__file__).resolve().parents[2]


def _ids(*ranges):
    out = []
    for r in ranges:
        out += list(range(r[0], r[1] + 1)) if isinstance(r, tuple) else [r]
    return out


# Pack sprite ids per category (checked by eye against otsp_contact renders).
PACK = {
    "sword": _ids((1677, 1799), (2264, 2272), (2586, 2601)),
    "club": _ids((1800, 1818), (2273, 2274), (2602, 2609)),
    "axe": _ids((1819, 1869), 2275, (2610, 2620)),
    "bow": _ids(1870, 1872, 1873, (1877, 1879), (1882, 1884), 1886, 1887, 1889, 2622, (2625, 2627)),
    "crossbow": _ids(1871, 1885, 1888, 2624),
    "wand": _ids(1897, 1898, (1900, 1903), (1906, 1909), 2276, 2277, (2628, 2630)),
    "book": _ids(1899, 1904, 1905, 2631, 2632),
    "shield": _ids((1910, 1940), 1992, (2278, 2282), 2633, 2634),
    "helmet": _ids((1941, 1991), 2283, (2635, 2650)),
    "armor": _ids((1995, 2076), (2284, 2293), (2651, 2661)),
    "legs": _ids((2077, 2089), 2294, (2662, 2667)),
    "boots": _ids((2090, 2098), (2668, 2672)),
    "backpack": _ids((2099, 2102), 2673),
    "torch": _ids(2103, 2104),
    "potion": _ids((2128, 2136)),
    "amulet": _ids(2139, 2140, 2142, 2219, 2220, 2677, 2678),
    "ring": _ids((2143, 2151), (2679, 2682)),
    "food": _ids(2174, (2177, 2188)),
    "ore": _ids(2199, 2201, 2203, 2200, 2202),
    # The gathering professions: logs from the pack's nature items, herbs from its small plants; fish
    # share the food pool (the pack has no fish).
    "log": _ids(1588, 1589, 1590, 2258, 2259),
    "herb": _ids(1315, 1328, 1338, 1344, 1349, 1318),
    "rune": _ids((2694, 2699)),
    "gem": _ids(2205, 2207, 2209, 2211, 2213, 2214, 2215, 2216, 2217, 2218),
    "shard": _ids(2161),
    "pearl": _ids(2191),
    "coins": _ids(2192),
}

# Our item kinds (slot, or slot:look) to a pack category; kinds not listed have no pack art.
KIND = {
    "helmet": "helmet", "armor": "armor", "legs": "legs", "boots": "boots", "ring": "ring",
    "necklace": "amulet", "container": "backpack", "bag": "backpack",
    "main_hand:sword": "sword", "main_hand:greatsword": "sword",
    "main_hand:axe": "axe", "main_hand:hewer": "axe", "main_hand:amberaxe": "axe", "main_hand:venomaxe": "axe",
    "main_hand:seraphaxe": "axe", "main_hand:sanguineaxe": "axe", "main_hand:starsteelaxe": "axe",
    "main_hand:hammer": "club", "main_hand:mace": "club",
    "main_hand:bow": "bow", "main_hand:crossbow": "crossbow",
    "main_hand:wand": "wand", "main_hand:rod": "wand",
    "off_hand:book": "book", "off_hand:heater": "shield", "off_hand:tower": "shield", "off_hand:buckler": "shield",
    "off_hand:torch": "torch",
    "-:drink": "potion", "-:eat": "food", "-:fish": "food", "-:ore": "ore", "-:log": "log", "-:herb": "herb",
    "-:runestone": "rune", "-:coins": "coins",
    "-:trophy:gem": "gem", "-:trophy:great_gem": "gem", "-:trophy:pearl": "pearl", "rune_shard": "shard", "glowcap": "herb",
}


BACKPACK_FIRST = ["traveler_pack", "explorer_pack", "pathfinder_pack", "leather_satchel", "reedweave_bag"]


def kind(item):
    if item["id"] in KIND:
        return KIND[item["id"]]
    slot = item.get("slot") or "-"
    parts = item["look"].split("+")
    shape = parts[0]
    if slot == "-":
        shape = "drink" if item.get("drink") else "eat" if item.get("eat") else shape
        if shape == "trophy" and len(parts) > 1:  # monster drops: only gems and pearls have pack art
            return KIND.get(f"-:trophy:{parts[1]}")
    return KIND.get(slot) or KIND.get(f"{slot}:{shape}")


def _profile(rows):
    """(richness, hue, saturation, lightness) of a sprite: its colour count and its mean colour."""
    pixels = [p for r in rows for p in r if p and p[0] + p[1] + p[2] > 40]
    if not pixels:
        return 0, 0.0, 0.0, 0.0
    r, g, b = (sum(p[i] for p in pixels) / len(pixels) / 255 for i in range(3))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    return len({p[:3] for p in pixels}), h, s, l


def _item_colour(item):
    code = item["colors"][0]
    return colorsys.rgb_to_hls(*(int(code[i:i + 2], 16) / 255 for i in (0, 2, 4)))


def _distance(item_hls, sprite):
    h, l, s = item_hls
    _, sh, ss, sl = sprite
    dh = min(abs(h - sh), 1 - abs(h - sh)) * min(s, ss) * 2
    return dh + abs(l - sl) + abs(s - ss) * 0.5


def mapping(items):
    """{item id: pack id or None}: each category's sprites shared out among its items."""
    things = otsp.load()["items"]
    by_category = {}
    for item in items:
        category = kind(item)
        by_category.setdefault(category, []).append(item)
    out = {}
    for category, members in by_category.items():
        if category is None:
            for item in members:
                out[item["id"]] = None
            continue
        sprites = {sid: _profile(otsp.compose(things[sid])) for sid in PACK[category] if sid in things}
        ranked = sorted(sprites, key=lambda sid: sprites[sid][0])  # plainest first
        members = sorted(members, key=lambda i: (i.get("slot") != "bag", i.get("level", 0), i["id"]))
        free = list(ranked)
        n = len(members)
        if category == "backpack":  # the quests' packs, then tailoring's bags, get the few backpacks
            members = sorted(members, key=lambda i: (i["id"] not in BACKPACK_FIRST, BACKPACK_FIRST.index(i["id"])
                                                     if i["id"] in BACKPACK_FIRST else 0, i.get("level", 0)))
        for index, item in enumerate(members):
            if not free:
                out[item["id"]] = None
                continue
            target = index / max(1, n - 1) * (len(ranked) - 1)
            colour = _item_colour(item)
            best = min(free, key=lambda sid: abs(ranked.index(sid) - target) / max(1, len(ranked)) * 2
                       + _distance(colour, sprites[sid]))
            out[item["id"]] = best
            free.remove(best)
    return out


def catalog():
    data = json.load(open(ROOT / "game/data/items.json", encoding="utf-8"))
    items = data.get("items", data) if isinstance(data, dict) else data
    return items if isinstance(items, list) else [dict(v, id=k) for k, v in items.items()]


if __name__ == "__main__":
    result = mapping(catalog())
    path = ROOT / "tools/generators/otsp_items.json"
    path.write_text(json.dumps(result, indent=1, sort_keys=True), encoding="utf-8")
    kept = sum(1 for v in result.values() if v)
    print(f"{kept} items mapped, {len(result) - kept} without a pack sprite -> {path}")
    sys.exit(0)
