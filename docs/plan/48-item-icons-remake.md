# 48 - Item icons remade in the OpenTibia pack's style

**Effort:** XL  **Status:** started 2026-10-22 on branch `experiment/pack-paperdoll`

## Request
The owner had every old item and gear sprite deleted (painted, derived, pack-recoloured, and
generated icons, worn layers squeezed from icons, painted outfits) and asked for all item icons to
be remade with a new, simple generator: our own designs in the style of the OpenTibia sprite pack
(https://github.com/peonso/opentibia_sprite_pack, CC BY 4.0), matched down to how contrast and
outlines are rendered. The pack is style reference only: nothing is sampled, traced, or recoloured.
The old icon code in `make_sprites.py` (~7k lines in all) is replaced, not extended.

## The style, measured (674 pack sprites, `otsp_equipment_01.png`)
- **32x32 icons** (as in Tibia; some large objects there are 64x64). The drawing fills about 29x30.
- **Pure black outline** (#000) on about 90% of the silhouette edge, on all four sides. Black is
  almost never used inside an icon (4% of black pixels are inner lines).
- **Smooth, many-tone shading**: about 33 colours per icon; a steel blade alone has about 21 grey
  tones with luma steps of 2-6. Pre-rendered look, not 4-5 hard bands. Almost no dithering.
- **Extreme contrast**: tones run from near-black (~26 luma) to near-white (~247).
- **Light from the top-left**: the brightest pixel sits in the upper-left third.
- **Hue-shifted ramps**: gold runs from orange shadows (hue ~0.09) to yellow lights (~0.13), with
  more saturation in the lights; steel stays cool grey.
- **Weapons on the diagonal**, tip top-left, grip bottom-right; blades shaded as a stylised
  cross-section (black edge, thin lit rim, bright core, dark far side).

## The generator (`tools/icons/`)
- `core.py`: a 32x32 canvas of material, tone, and part ids; three shading primitives (profile
  strokes along an axis for blades, hafts, grips; spheres and ellipses for pommels, gems, mace
  heads; domed masks for plates, shields, armour); hue-shifted material ramps; the black outline
  pass; PNG output.
- One module per family with its designs as short data (a sword is a blade profile, a guard, a
  grip, a pommel, and its materials), each item its own design: no two items share a silhouette.
- `make_icons.py` writes `items.png` (and later the animated and glow sheets).

## Steps
1. Core and swords as the golden sample; review at 4x beside the pack.
2. Axes, maces and hammers, bows and crossbows, wands and rods, spears.
3. Shields, spellbooks, quivers.
4. Helmets, armour, legs, boots.
5. Rings, necklaces, potions, food, materials, runes, containers, tools.
6. Retire the old icon code in `make_sprites.py`; animation and glow sheets.

## Tests
Per family: every item draws, fits the 32x32 cell with a transparent border, has a black outline,
and no two items of a slot share a silhouette (`rules_test.gd`).

## Done when
Every item's icon comes from `tools/icons/`, and the old icon code is gone.
