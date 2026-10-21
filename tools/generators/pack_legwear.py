"""Legwear icons: Brimholt variants built on OpenTibia sprite pack leg models (CC BY 4.0, see
assets/third_party/CREDITS.md). Each design keeps a model's silhouette and light, repaints its
pieces in the item's own materials and layout, and adds our own ornaments (pack_sprites.variant).
"""
import pack_sprites as S

SHEET = "otsp_equipment_01.png"


def _model(i: int) -> tuple[int, int]:
    return (32 * i, 1248) if i < 16 else (32 * (i - 16), 1280)


def P(sel: str, hexcode: str, tex: str = "none", smooth: bool = False):
    return (sel, hexcode, tex, smooth)


DESIGNS: dict[str, dict] = {
    # Legplates
    "rusted_legplates": dict(model=18, paint=[P("*:*", "8a8680", "rust"), P("o:*", "6a4a30", "leather", True)],
                             details=[("studs", "belt", 2, "b8a070")]),
    "bronze_legplates": dict(model=5, paint=[P("o:*", "c8a040"), P("y:*", "f0d878"), P("nbr:*", "a02a2a", "quilt", True)],
                             details=[("gem", 3, 14, "e04030")]),
    "steel_legplates": dict(model=10, paint=[P("*:*", "5a5a6a"), P("*:belt", "4a3426", "leather")],
                            details=[("studs", "belt", 3, "c0c0d0"), ("gem", 18, 6, "d03030")]),
    "silverleaf_legplates": dict(model=11, paint=[P("n:*", "dcd8cc"), P("yo:*", "5a9a4a"), P("cg:*", "b02a2a")],
                                 details=[("dots", "thigh", 9, "b02a2a", 4)]),
    "golden_lion_legplates": dict(model=3, paint=[P("ory:*", "c8a040"), P("*:belt", "3a5aa8", "none", True)],
                                  details=[("gem", 19, 7, "4a7ae0"), ("studs", "belt", 3, "f0d878")]),
    "frostborn_legplates": dict(model=12, paint=[P("cb:*", "80a8d8", "none", True), P("y:*", "e8f4ff"), P("n:*", "4a6aa0")],
                                details=[("dots", "leg", 8, "ffffff", 7)]),
    "crimson_aegis_legplates": dict(model=9, paint=[P("bp:*", "a02a2a"), P("yor:*", "e0b040")],
                                    details=[("gem", 4, 14, "f0f0ff")]),
    "skullcrusher_legplates": dict(model=14, paint=[P("n:*", "a09484"), P("o:*", "4a3a30", "leather", True)],
                                   details=[("dots", "upper", 6, "e8dcc0", 3)]),
    "obsidian_bulwark_legplates": dict(model=17, paint=[P("b:*", "2e2a34"), P("n:*", "5a5466"), P("y:*", "d03030")],
                                       details=[("gem", 20, 7, "ff4030")]),
    # Chausses
    "ringmail_chausses": dict(model=13, paint=[P("n:*", "9098a0", "rings", True), P("cy:*", "6a4a2a", "leather")],
                              details=[("band", "top", "belt", "6a4a2a")]),
    "ranger_s_chausses": dict(model=4, paint=[P("n:*", "6a8a4a", "mail", True), P("n:belt", "e8e4d8")],
                              details=[("stripe", "outer", 1, "e8e4d8", "leg")]),
    "windrider_chausses": dict(model=1, paint=[P("c:*", "e8e4dc", "scale"), P("b:*", "a8a498")],
                               details=[("stripe", "outer", 1, "f0f4f8", "leg")]),
    "shadowstalker_chausses": dict(model=8, paint=[P("n:*", "3a5a3a", "mail", True), P("g:*", "c8a050")],
                                   details=[("studs", "belt", 2, "c8a050")]),
    # Breeches
    "moss_breeches": dict(model=0, paint=[P("g:*", "5f7f55", "leather"), P("or:*", "3a5241", "leather"), P("n:*", "c9a24a")]),
    "hide_breeches": dict(model=16, paint=[P("o:*", "8f6649", "leather"), P("r:*", "4a2a26"), P("ny:*", "c8b090")]),
    "thornvine_breeches": dict(model=19, paint=[P("g:*", "3a6a2a", "leather"), P("y:*", "c8a050"), P("on:*", "4a3220")],
                               details=[("dots", "leg", 9, "8ad060", 5)]),
    "wolfhide_breeches": dict(model=2, paint=[P("*:upper", "d8d4c8", "fur", True), P("o:leg", "5a7a4a", "leather"), P("ry:leg", "d8d4c8", "fur")]),
    # Leggings
    "linen_leggings": dict(model=7, paint=[P("g:*", "9a9ca4", "none", True), P("o:*", "7a5a3a"), P("cn:*", "c9a24a")]),
    "apprentice_s_leggings": dict(model=15, paint=[P("b:*", "3a5aa8"), P("yo:*", "e0b040")]),
    "netherflame_leggings": dict(model=6, paint=[P("o:*", "3a1a1e"), P("y:*", "ffb040")],
                                 details=[("dots", "leg", 7, "ff6020", 2)]),
}

# No recolour of an existing icon: each model carries one design (docs/art.md, "No recolours").
_used = [d["model"] for d in DESIGNS.values()]
assert len(_used) == len(set(_used)), "two legwear designs share a pack model (a recolour)"


def icon(kind: str):
    """RGBA rows (None for transparent) of a legwear icon, or None when the item has no design."""
    d = DESIGNS.get(kind)
    if d is None:
        return None
    rows = S.variant(SHEET, *_model(d["model"]), d)
    return [[(c + (255,)) if c else None for c in r] for r in rows]
