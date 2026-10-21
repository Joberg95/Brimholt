"""Helmet icons: Brimholt variants built on OpenTibia sprite pack helmet models (CC BY 4.0, see
assets/third_party/CREDITS.md). Each design keeps a model's silhouette and light and repaints its
colour regions in the item's own colours (items.json main and accent) and materials; nothing ships
as the pack drew it. Helmets are seen in 3/4 view, so they are painted whole (variant(mirror=False)).
"""
import colorsys

import pack_sprites as S

SHEET = "otsp_equipment_01.png"
# Texture per armour class: plate is smooth metal, mail rings, leather grain, cloth plain.
TEXTURE = {"plate": "none", "mail": "mail", "leather": "leather", "cloth": "none", None: "none"}


def H(model: str, main: str, accent: str = "", extra: tuple = (), tex: str | None = None, details: tuple = (),
      add: tuple = ()):
    """model "row.col" in the pack sheet; main and accent are pack colour families (n neutral, y
    yellow, o orange, r red, g green, c cyan, b blue, p purple) painted in the item's main and
    accent colours; extra is (families, hex, texture) for a third material such as gold trim or
    bone horns; tex overrides the armour class's texture; add is our own construction on the base
    (_add: parts, bands, rivets, gems, nasal guards), so no icon is the pack's drawing recoloured."""
    return dict(model=model, main=main, accent=accent, extra=extra, tex=tex, details=details, add=add)


GOLD, STEEL, BONE, FUR, WOOD = "c9a24a", "9aa0a8", "e0d6bc", "8a6a4a", "6a4a2e"

DESIGNS: dict[str, dict] = {
    # Cloth: hats, hoods, cowls, and masks
    "linen_hat": H("28.5", "y", "r", tex="none"),
    "ashen_hat": H("30.1", "n", "yo"),
    "amber_hat": H("31.8", "p", "n"),
    "silkweave_hat": H("27.0", "g", "yn"),
    "moonsilk_hat": H("30.12", "b", "yn", extra=("n", "eef0f6", "none")),
    "cobalt_hat": H("30.14", "gn", "oy"),
    "emberweave_hat": H("30.10", "nb", "p"),
    "ashcaller_hat": H("31.0", "n", "oryg"),
    "warlock_s_cowl": H("30.6", "n", "rpo", extra=("by", "6a5a7a", "none")),
    "infernal_cowl": H("31.4", "r", "oy"),
    "gravecall_cowl": H("27.7", "n", "yc"),
    "lodgeseer_helm": H("27.3", "o", "y", tex="leather"),
    "starhalo_hat": H("31.9", "r", "n", extra=("y", "c8d8f0", "none")),
    "cinder_visage": H("27.12", "o", "yr"),
    # Leather: caps, hoods, circlets, crowns of horn and wood
    "ember_cap": H("27.2", "o", ""),
    "hide_hood": H("30.9", "r", "n"),
    "thornvine_circlet": H("28.3", "o", "gc"),
    "wolfhide_hood": H("27.13", "y", "n", tex="fur"),
    "silverleaf_circlet": H("27.5", "n", "", tex="none"),
    "mossbark_hood": H("28.7", "g", "", details=(("dots", "*", 7, "accent", 3),)),
    "emberbloom_circlet": H("27.14", "o", "y", extra=("n", BONE, "none")),
    "lodgestalker_helm": H("30.8", "o", "y"),
    "serpent_hood": H("28.4", "b", "yo", extra=("r", "c02a2a", "none")),
    "stagwood_circlet": H("28.8", "o", "r"),
    "stag_crown": H("29.3", "g", "c", extra=("oy", WOOD, "leather")),
    "fangmaw_mask": H("28.2", "y", "r", extra=("no", BONE, "none")),
    "elder_stag_crown": H("28.0", "n", "yo"),
    "rootbound_crown": H("30.15", "y", "r", extra=("no", WOOD, "leather")),
    "thornscale_circlet": H("28.15", "b", "yo", tex="none"),
    # Mail: coifs and open helms, bear and wolf hoods
    "ringmail_coif": H("29.1", "n", "o", tex="rings"),
    "iron_coif": H("29.6", "nb", ""),
    "bronze_coif": H("28.13", "nb", "yg"),
    "steel_coif": H("30.11", "o", "r", extra=("n", STEEL, "mail")),
    "silverleaf_coif": H("30.7", "n", "yc"),
    "delvers_lamp_helm": H("27.6", "o", "bp", extra=("r", "ffd060", "none"), tex="none"),
    "cobalt_coif": H("28.1", "n", "oy"),
    "rimeguard_coif": H("30.2", "n", "y"),
    "embersteel_coif": H("29.15", "n", "or"),
    "lodgeranger_helm": H("28.11", "n", "y", tex="fur"),
    "grizzly_coif": H("28.9", "y", "b", extra=("n", "e8f0ff", "fur")),
    "bearclaw_hood": H("29.2", "nc", "yo"),
    "great_bear_hood": H("27.10", "n", "yr", tex="fur"),
    "moonsteel_visor": H("28.14", "bn", "yo"),
    # Plate: closed, crested, horned, and crowned helms
    "dented_iron_helm": H("29.0", "n", "", tex="rust"),
    "iron_sallet": H("27.11", "o", "n"),
    "bronze_helm": H("27.8", "n", "o", extra=("y", BONE, "none")),
    "steel_kettle_hat": H("29.12", "yo", "rp"),
    "silverleaf_helm": H("30.13", "n", "o"),
    "cobalt_sallet": H("30.4", "y", "b", extra=("o", GOLD, "none")),
    "embersteel_helm": H("30.0", "y", "n"),
    "duskiron_visor": H("27.9", "n", ""),
    "sunforged_crownhelm": H("29.4", "o", "r", extra=("y", "f0d080", "none")),
    "gilded_hornhelm": H("29.8", "yo", "n"),
    "lodgewarden_helm": H("30.3", "n", "c", extra=("y", BONE, "none")),
    "rimeskull_helm": H("29.5", "n", ""),
    "starforged_helm": H("29.10", "o", "y"),
    "wyrmglass_greathelm": H("30.5", "o", "r"),
    "abyssal_greathelm": H("29.7", "yn", "c"),
    "drakeforged_helm": H("29.13", "o", "y", extra=("n", "f0b040", "none")),
}

# No recolour of an existing icon: each model carries one design (docs/art.md, "No recolours").
_used = [d["model"] for d in DESIGNS.values()]
assert len(_used) == len(set(_used)), "two helmet designs share a pack model (a recolour)"


# Our construction on each base, from the item's look (horns, crest, plume, feather, wings, spikes,
# stars, flames, leaves, antlers) and its own trim: what makes the icon ours and not the pack's.
ADD: dict[str, tuple] = {
    "linen_hat": (("feather", "light", 0.35, "right"), ("band", "accent", 2)),
    "ashen_hat": (("star", "accent", 1), ("rivets", "accent", 1)),
    "amber_hat": (("star", "accent", 2), ("gem", GOLD, 2)),
    "silkweave_hat": (("feather", "accent", 0.35, "left"), ("band", "accent", 1)),
    "moonsilk_hat": (("star", "light", 2),),
    "cobalt_hat": (("star", "accent", 2), ("band", "accent", 3)),
    "emberweave_hat": (("stub", "accent", 0.25), ("gem", GOLD, 1)),
    "ashcaller_hat": (("flames", "main", 3),),
    "warlock_s_cowl": (("spikes", "accent", 2), ("gem", "6a5a7a", 1)),
    "infernal_cowl": (("horn", BONE, 0.3), ("gem", GOLD, 1)),
    "gravecall_cowl": (("stub", BONE, 0.2),),
    "lodgeseer_helm": (("feather", "light", 0.25), ("band", "accent", 2)),
    "starhalo_hat": (("star", "accent", 1),),
    "cinder_visage": (("spikes", "main", 2),),
    "ember_cap": (("rivets", "accent", 1), ("finial", "accent", 2)),
    "hide_hood": (("antler", "b89a6a", 0.2),),
    "thornvine_circlet": (("sprig", "light", 0.4),),
    "wolfhide_hood": (("stub", BONE, 0.15), ("band", "accent", 4)),
    "silverleaf_circlet": (("sprig", "light", 0.5), ("gem", STEEL, 0)),
    "mossbark_hood": (("sprig", "light", 0.3),),
    "emberbloom_circlet": (("antler", "light", 0.2),),
    "lodgestalker_helm": (("antler", "accent", 0.1),),
    "serpent_hood": (("finial", GOLD, 2), ("gem", GOLD, 0)),
    "stagwood_circlet": (("sprig", "accent", 0.6), ("gem", GOLD, 0)),
    "stag_crown": (("antler", "8a6440", 0.15), ("sprig", "light", 0.5)),
    "fangmaw_mask": (("horn", BONE, 0.15),),
    "elder_stag_crown": (("antler", "light", 0.15), ("gem", GOLD, 1)),
    "rootbound_crown": (("sprig", "accent", 0.5),),
    "thornscale_circlet": (("spikes", "light", 2),),
    "ringmail_coif": (("finial", STEEL, 2), ("band", "8a6a4a", 3), ("rivets", GOLD, 3)),
    "iron_coif": (("feather", "accent", 0.3, "left"),),
    "bronze_coif": (("band", "accent", 2), ("finial", "accent", 2)),
    "steel_coif": (("feather", "accent", 0.35, "right"),),
    "silverleaf_coif": (("feather", "accent", 0.3, "left"), ("nasal", STEEL, 5)),
    "delvers_lamp_helm": (("lamp", GOLD, 1),),
    "cobalt_coif": (("crest", "accent", 2), ("gem", GOLD, 1)),
    "rimeguard_coif": (("spikes", "accent", 2),),
    "embersteel_coif": (("plume", "accent", 3),),
    "lodgeranger_helm": (("crest", "accent", 2), ("rivets", GOLD, 2)),
    "grizzly_coif": (("stub", "light", 0.1), ("nasal", STEEL, 5)),
    "bearclaw_hood": (("stub", "light", 0.15), ("gem", GOLD, 0)),
    "great_bear_hood": (("spikes", "light", 2), ("gem", GOLD, 1)),
    "moonsteel_visor": (("crest", "accent", 2),),
    "dented_iron_helm": (("finial", STEEL, 2), ("nasal", "8a8f96", 6)),
    "iron_sallet": (("band", "accent", 1), ("finial", "light", 2)),
    "bronze_helm": (("finial", "accent", 2), ("nasal", "main", 6)),
    "steel_kettle_hat": (("feather", "light", 0.3, "left"), ("gem", GOLD, 2)),
    "silverleaf_helm": (("crest", "accent", 2),),
    "cobalt_sallet": (("wing", "light", 0.35),),
    "embersteel_helm": (("spikes", "light", 2),),
    "duskiron_visor": (("horn", "accent", 0.25),),
    "sunforged_crownhelm": (("finial", "light", 2),),
    "gilded_hornhelm": (("horn", "light", 0.25),),
    "lodgewarden_helm": (("horn", "accent", 0.3),),
    "rimeskull_helm": (("stub", "light", 0.2),),
    "starforged_helm": (("horn", "accent", 0.25), ("gem", GOLD, 1)),
    "wyrmglass_greathelm": (("horn", "accent", 0.25),),
    "abyssal_greathelm": (("crest", "accent", 2),),
    "drakeforged_helm": (("spikes", "accent", 2), ("stub", "light", 0.25)),
}
assert set(ADD) == set(DESIGNS), "every helmet adds its own construction to its base"
for _kind, _ops in ADD.items():
    DESIGNS[_kind]["add"] = _ops


def _offset(hexcode: str) -> str:
    """A tone shift that keeps dark materials dark and pale ones pale on the model's light."""
    l = colorsys.rgb_to_hls(*(int(hexcode[i:i + 2], 16) / 255 for i in (0, 2, 4)))[1]
    return f"@{max(-0.18, min(0.2, (l - 0.5) * 0.7)):.2f}"


# --- Our own construction on the pack base: hand-pixelled parts and built-on trim ---------------
# Part rows: one letter per pixel, "." transparent, "k" the part's outline, "4" its highlight and
# "1" "2" "3" light, mid, and dark tones of the part's material; "a" "b" "c" the item's accent
# (gems, flame cores). Parts are drawn for the left side and mirrored for the right.

PARTS = {
    # A horn sweeping out from the helm and curling up; attached at its base (last row, last column).
    "horn": ["k.......",
             "1k......",
             "21k.....",
             "k21k....",
             ".k221k..",
             "..k3221k",
             "...k3322",
             "....kk33"],
    # A short straight horn, pointing up and out.
    "stub": ["k....",
             "1k...",
             "21k..",
             "k22k.",
             ".k322",
             "..k33"],
    # A swept wing of three feathers.
    "wing": ["k.......",
             "4k......",
             "14k.....",
             "k14k....",
             "k114kk..",
             ".k11224k",
             "k1122233",
             ".k12233.",
             "..k233k.",
             "...kkk.."],
    # A branched antler.
    "antler": ["k..k.....",
               "1k.1k....",
               "2k.2k.k..",
               "k2k2k.1k.",
               ".k22kk2k.",
               "..k2222k.",
               "...kk222k",
               ".....k22k",
               "......kk."],
    # A three-leaf sprig.
    "sprig": [".kk....",
              "k12k...",
              "k122k..",
              ".k23kkk",
              "..kk12k",
              "...k122",
              "....k23"],
    # A long feather, quill at the bottom right.
    "feather": [".kk.....",
                "k14k....",
                "k124k...",
                ".k1224k.",
                "..k1223k",
                "...k223k",
                "....kk3k",
                "......k3"],
}
# Parts on top of the helm, centred on its crown; attached at the middle of their last row.
TOP = {
    # A crest: a tall fin of stiff bristles from brow to nape, swept back.
    "crest": [".kk......",
              "k14k.....",
              "k114kk...",
              "k1124k...",
              ".k1124kk.",
              ".k11224k.",
              ".k12223k.",
              "k1222333k",
              "k1223333k"],
    # A plume: a tall tuft of feathers falling back.
    "plume": ["..kkk...",
              ".k114k..",
              "k11124k.",
              "k12224k.",
              ".k1223k.",
              "..k123k.",
              "..k223k.",
              "...k33k."],
    # Three spikes.
    "spikes": ["k...k...k",
               "1k.k1k.k1",
               "21k213k12",
               "k22k23k23"],
    # A finial: a spike on a ball on a collar.
    "finial": ["..k..",
               ".k4k.",
               ".k1k.",
               ".k2k.",
               "k142k",
               "k123k",
               ".k3k.",
               "k123k"],
    # Flames licking up from the crown.
    "flames": ["..k....k.",
               ".kak..kak",
               "kabak.kab",
               "kbcbkkbcb",
               "kbccbbccb"],
    # A star above the brow.
    "star": ["..k..",
             ".kak.",
             "kaabk",
             ".kbk.",
             "..k.."],
}
# Parts on the front of the helm, centred on the brow.
FRONT = {
    # A gem set in a metal bezel.
    "gem": [".k2k.",
            "k1abk",
            "k2bck",
            ".k3k."],
    # A miner's lamp: a lit lens in a metal housing.
    "lamp": [".kkkk.",
             "k1aa2k",
             "kabbck",
             "k2cc3k",
             ".kkkk."],
}


def _rgb(hexcode: str) -> tuple[int, int, int]:
    return tuple(int(hexcode[i:i + 2], 16) for i in (0, 2, 4))


def _tones(hexcode: str) -> dict[str, tuple[int, int, int]]:
    """Letters to colours for one material: a hue-shifted ramp around its colour."""
    rp = S.ramp(hexcode)
    l = colorsys.rgb_to_hls(*(v / 255 for v in _rgb(hexcode)))[1]
    shift = round((l - 0.5) * 4)
    pick = lambda i: rp[max(1, min(8, i + shift))]
    return {"4": pick(8), "1": pick(6), "2": pick(5), "3": pick(3), "k": tuple(int(v * 0.45) for v in rp[0])}


def _stamp(rows, part, x0, y0, material, accent, flip=False):
    """Draws part rows with their top-left at (x0, y0); clipped to the 32x32 icon."""
    tones = _tones(material)
    gem = _tones(accent)
    tones.update({"a": gem["4"], "b": gem["2"], "c": gem["3"]})
    for dy, line in enumerate(part):
        line = line[::-1] if flip else line
        for dx, ch in enumerate(line):
            x, y = x0 + dx, y0 + dy
            if ch != "." and 0 <= y < len(rows) and 0 <= x < len(rows):
                rows[y][x] = tones[ch]


def _mask(rows):
    return [[c is not None for c in r] for r in rows]


def _shape(rows):
    """Top, bottom, left, right of the drawing, the brow row (where the helm reaches 3/4 of its
    widest), and the centre column."""
    m = _mask(rows)
    ys = [y for y in range(len(m)) if any(m[y])]
    widths = {y: (min(x for x in range(len(m)) if m[y][x]), max(x for x in range(len(m)) if m[y][x])) for y in ys}
    widest = max(r - l for l, r in widths.values())
    brow = next(y for y in ys if widths[y][1] - widths[y][0] >= widest * 0.75)
    left = min(l for l, _ in widths.values())
    right = max(r for _, r in widths.values())
    return dict(top=ys[0], bot=ys[-1], left=left, right=right, brow=brow, cx=(left + right) // 2, widths=widths)


def _add(rows, op, colors):
    """One addition: (kind, material, args...). Materials are hex codes or main/light/accent."""
    kind, material, *args = op
    named = {"main": colors[0], "light": colors[1], "accent": colors[2]}
    material = named.get(material, material)
    accent = colors[2]
    a = _shape(rows)
    if kind in PARTS:
        part = PARTS[kind]
        # The side the part grows from: the helm's edge at the given fraction of its height, on
        # both sides (mirrored) or only "left" or "right".
        at = args[0] if args else 0.3
        y = a["top"] + round((a["bot"] - a["top"]) * at)
        y = min(a["widths"], key=lambda r: abs(r - y))
        l, r = a["widths"][y]
        h, w = len(part), len(part[0])
        side = args[1] if len(args) > 1 else "both"
        # On a wide helm the part tucks in over its edge so the icon keeps its 30-pixel width.
        reach = max(0, (29 - (a["right"] - a["left"])) // (2 if side == "both" else 1))
        if side in ("both", "left"):
            _stamp(rows, part, max(l - w + 2, a["left"] - reach), y - h + 2, material, accent)
        if side in ("both", "right"):
            _stamp(rows, part, min(r - 1, a["right"] + reach - w + 1), y - h + 2, material, accent, flip=True)
    elif kind in TOP:
        part = TOP[kind]
        h, w = len(part), len(part[0])
        sink = args[0] if args else 2
        _stamp(rows, part, a["cx"] - w // 2, a["top"] - h + sink, material, accent)
    elif kind in FRONT:  # (part, housing material[, rows below the brow])
        part = FRONT[kind]
        y = a["brow"] + (args[0] if args else 0)
        _stamp(rows, part, a["cx"] - len(part[0]) // 2, y, material, accent)
    elif kind in ("band", "rivets"):  # a bevelled band (or a row of rivets) round the helm
        y = a["brow"] + (args[0] if args else 0)
        tones = _tones(material)
        for dy, tone in ((0, "1"), (1, "3")):
            if y + dy not in a["widths"]:
                continue
            l, r = a["widths"][y + dy]
            for x in range(l + 1, r):
                if rows[y + dy][x] is not None and (kind == "band" or (dy == 0 and (x - l) % 3 == 1)):
                    rows[y + dy][x] = tones["4" if kind == "rivets" else tone]
    elif kind == "nasal":  # a nose guard from the brow down
        tones = _tones(material)
        length = args[0] if args else 6
        for y in range(a["brow"], min(a["bot"], a["brow"] + length)):
            for dx, tone in ((-1, "k"), (0, "1"), (1, "3")):
                x = a["cx"] + dx
                if rows[y][x] is not None or dx == 0:
                    rows[y][x] = tones[tone]
    elif kind == "trim":  # a lit rim along the helm's upper outline
        tones = _tones(material)
        for x in range(len(rows)):
            ys = [y for y in range(len(rows)) if rows[y][x] is not None]
            if len(ys) > 3:
                rows[ys[0] + 1][x] = tones["1"]
    else:
        raise ValueError(f"unknown helmet addition {kind}")


def _squeeze(rows, limit):
    """Drops the rows of the drawing's lower half most like the row below them until it is at most
    limit rows tall, as legwear loses shin rows (pack_sprites.fit)."""
    def same(a, b):
        return sum(bool((p is None) != (q is None) or (p and q and sum(abs(u - v) for u, v in zip(p, q)) > 60))
                   for p, q in zip(a, b))
    while True:
        ys = [y for y in range(len(rows)) if any(c is not None for c in rows[y])]
        if ys[-1] - ys[0] < limit:
            return rows
        lo = (ys[0] + ys[-1]) // 2
        del rows[min(range(lo, ys[-1] - 2), key=lambda y: same(rows[y], rows[y + 1]))]
        rows.append([None] * len(rows[0]))


def _fit(rows):
    """Crops the 48x48 working canvas to the 32x32 icon, centred, keeping the one-pixel border. A
    drawing taller than 30 rows (a crest or plume on a tall helm) loses rows of its lower half, and
    one wider than 30 columns (a broad pack base with horns) loses columns right of its middle."""
    rows = _squeeze(rows, 30)
    columns = _squeeze([list(c) for c in zip(*rows)], 30)
    rows = [list(r) for r in zip(*columns)]
    m = _mask(rows)
    ys = [y for y in range(len(m)) if any(m[y])]
    xs = [x for x in range(len(m)) if any(m[y][x] for y in range(len(m)))]
    x0 = (xs[0] + xs[-1] + 1) // 2 - 16
    y0 = (ys[0] + ys[-1] + 1) // 2 - 16
    return [[rows[y0 + y][x0 + x] if 0 <= y0 + y < len(rows) and 0 <= x0 + x < len(rows) else None
             for x in range(32)] for y in range(32)]


def icon(kind: str, colors: list[str], armor: str | None):
    """RGBA rows (None for transparent) of a helmet icon, or None when the item has no design."""
    d = DESIGNS.get(kind)
    if d is None:
        return None
    main, accent = colors[0], colors[2]
    tex = d["tex"] or TEXTURE.get(armor, "none")
    paint = []
    if d["main"]:
        paint.append((f"{d['main']}:*", main, tex + _offset(main), False))
    if d["extra"]:
        families, hexcode, extra_tex = d["extra"]
        paint.append((f"{families}:*", hexcode, extra_tex + _offset(hexcode), False))
    if d["accent"]:
        paint.append((f"{d['accent']}:*", accent, "none" + _offset(accent), False))
    details = tuple(tuple(accent if v == "accent" else v for v in det) for det in d["details"])
    row, col = (int(v) for v in d["model"].split("."))
    base = S.variant(SHEET, 32 * col, 32 * row, dict(paint=paint, details=details), mirror=False)
    rows = [[None] * 48 for _ in range(8)] + [[None] * 8 + r + [None] * 8 for r in base] + [[None] * 48 for _ in range(8)]
    for op in d["add"]:
        _add(rows, op, colors)
    return [[(c + (255,)) if c else None for c in r] for r in _fit(rows)]
