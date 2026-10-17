---
name: icon-art
description: Use when creating or changing any Brimholt item icon (weapons, armor, helmets, boots, rings, necklaces, backpacks, potions, materials, runes, mounts) or its in-hand or worn look, so it matches the classic Tibia item-icon style on the first attempt and goes through the shared pipeline: which builder to use, view and size rules, ramps and light, the finishing passes, animation, regeneration, and the side-by-side review.
---

# Item icon art

Brimholt's icons follow Tibia's item icons closely (the owner's decision, 2026-10-16): the same
kinds of items, silhouettes, colour schemes, and ornament. **Names stay our own**: never give an
item Tibia's exact name. **Every pixel is drawn here**:
never download, trace, recolour, or import Tibia's sprite files. The `art-direction` skill covers
world art; this one covers icons.

## The look

- **32x32, shown at 32.** Slots are 32 pixels (`Layout.SLOT_SIZE`); never draw an icon smaller or
  scale it down. Leave a transparent border of at least one pixel (a unit check enforces it).
- **Classic views.** Weapons lie on the diagonal, head or blade top-left, haft down to a pommel
  bottom-right, the head about a third of the length. Containers and objects are seen from in front,
  a little above and to the left (a three-quarter view: top, front, and right side show). Rings and
  necklaces are seen tilted (a 3/4 ellipse, back half in shadow).
- **Light from the top-left.** Five-tone ramps per material, lightest first, warm lights and cool
  shadows (`pixel_bags._ramp`); top-left edges lit, bottom-right shaded, side faces a step darker.
- **Materials, not fills.** Steel blades with a bright cutting edge and a coloured inlay, gold
  sockets and rims, gems with a glint, leather with grain. One colour all over reads as a blob.
- **Dark outline round the silhouette**, darker seams where two parts meet, small details at least
  three pixels across (the outline eats one- and two-pixel features).
- **Asymmetry.** A mirrored, flat front view looks like a UI symbol; lean, overlap, and shade it.

## Pick the builder

| Kind of icon | Builder | Reference |
| --- | --- | --- |
| Rounded objects with parts (containers, chests, pouches) | Hand-drawn part map shaded by code | `tools/generators/pixel_bags.py` |
| Weapons and other thin, ornate items | Hand-pixelled letter rows on a shared haft | `tools/generators/pixel_axes.py` |
| Necklaces | Chain loop plus a hand-drawn pendant | `tools/generators/pixel_necklaces.py` |
| Shields | A shape mask with a bevelled rim, a divided or textured field (planks, scales, plates, rays, hammered), an embossed emblem with a drop shadow, studs, straps, corner fittings | `tools/generators/pixel_shields.py` |
| Bows | A shaded limb rasterised along an arch (round, recurve, deflex), a straight string, grip, tips, and ornaments | `tools/generators/pixel_bows.py` |
| Wands and rods | A big hand-drawn head on a thin near-upright shaft, rim-lit, faceted gems, dark seams between parts | `tools/generators/pixel_staves.py` |
| Rings | Tilted band plus a centrepiece | `ring_icon` in `make_sprites.py` |
| Showpiece helmets and boots | Solids rendered in 3D | `tools/generators/gear3d.py` |
| Painted sets, tier armour | Painted art imported by `make outfits`; armour without its own painting stacks bands of two or three painted pieces (`armor_bases`), never a plain recolour or a code-drawn body | `art/outfits/`, `derive_icons.py` |

Prefer the first two for new families. `item_icon`'s older generated shapes are the fallback
being replaced; do not add new ones there.

**Hand-drawn rows.** One letter per pixel, `"."` transparent; every row exactly 32 characters (check
it with a short script before rendering). Letters name a material and tone, mapped to colours from
the item's catalog `colors` (main, light, accent) and fixed ramps. Keep the rows in the module as
the art's source; edit them like a sprite.

## The pipeline (automatic)

`main()` in `make_sprites.py` sends every icon through:

1. `icon_volume` (only where `needs_volume` says the builder has no volume of its own): a dome from
   each pixel's distance to the silhouette, lit from the top-left in whole shade steps.
2. `icon_finish`: one outline (`ICON_OUTLINE`), contrast for flat icons, a lit inner rim top-left
   and a shaded one bottom-right. Painted icons get only the repeatable part (`rim=False`).

Do not add a second outline or rim in a builder. A builder that shades its own volume is added to
the `needs_volume` exclusions.

**Animation.** Icons that move return a frame-dependent image (12 frames of 0.1 s, `ANIM_FRAMES`):
glowing eyes and gems pulse, flames flicker, sparks travel; `"shine": "sheen"` in `items.json`
sweeps a light across polished metal. Register the style in `animated()` so `items_anim/<id>.png`
is written; `SpriteArt.draw_item` plays it.

**Worn and held.** Helmets wear their icon (`textured`); boots are drawn as generated boots in the
item's colours with details from their look; weapons are held as the icon rebuilt into a weapon
(`painted_held`). Check all four facings.

## Workflow

1. Collect the Tibia references the owner sent (or the item family on the Tibia wiki) and decide
   the silhouette, view, materials, and one or two signature details per item.
2. Draw in the right builder, then render a 4-5x review sheet with a throw-away script: every new
   icon, its animation frames, and the finished version (`icon_finish(icon_volume(...))`) on the
   slot colour `#232a33` and on the wiki's tan, next to the references.
3. Compare side by side: proportions, outline weight, number of tones, highlight placement,
   detail size. Fix everything in one pass and look again; two rounds should do it.
4. Write only the sheets you changed: `python tools/generators/make_sprites.py --only items.png
   items_glow.png items_anim/<id>.png gear/<id>.png`; run `derive_icons.py` if you touched the
   finishing passes or templates. Then `make import`.
5. Unit checks (`tests/unit/rules_test.gd`): looks and styles, animated counts, icon padding, drop
   sources at live levels. Run the visual test for anything worn or held.
6. Update `docs/art.md` (builder, letters, styles) and the item tables in `docs/gameplay.md`.
