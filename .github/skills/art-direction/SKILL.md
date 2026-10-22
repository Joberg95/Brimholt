---
name: art-direction
description: Use when changing how any part of Brimholt's world looks (grounds, borders, walls, rock, doors, roofs, trees, furniture, signs, decor, creatures, outfits, item icons): every sprite is the OpenTibia sprite pack's, so this is choosing and placing pack things, not drawing.
---

# Art direction

All art is the OpenTibia sprite pack's (CC BY 4.0, plan 49, the owner's decision on 2026-10-22). We do
not draw our own art for now: change the world's look by picking other pack things, never by drawing
or recolouring. Keep `assets/third_party/opentibia_sprite_pack/LICENSE.txt`, `AUTHORS.md`, and the row
in `assets/third_party/CREDITS.md`.

## Where each look is chosen

| What | Where | How |
| --- | --- | --- |
| Floors | `game/render/ground_art.gd` `GROUNDS`, `ground_of` | terrain -> pack ground, its border set, and its priority (higher grounds lay their borders on lower ones) |
| Walls, doors, ores | `game/render/wall_art.gd` `WALLS`, `ORES` | each style's [vertical, horizontal, pole, corner, windows, doors] |
| Rock | `game/render/ground_art.gd` `ROCKS`, `ROCK_TOPS`, `ROCK_RIMS` | cliff pieces on the south and east faces, the raised flat top, the earth rim on the north and west |
| Roofs | `game/render/roof_art.gd` `MATERIALS` | [north row tile, other rows] per material |
| Trees, furniture, herbs, signs, decor | `game/render/object_art.gd` | terrain or kind -> pack thing |
| Characters | `game/render/sprite_art.gd` `OUTFITS`, `OUTFIT_COLORS` | a looktype and head/body/legs/feet colours per vocation |
| Monsters | `game/data/monsters.gd` `"outfit"` | a pack creature looktype and a size |
| Item icons | `game/data/items.json` `"sprite"` | a pack item id (the `icon-art` skill) |

## Steps

1. Find candidates: render a labelled contact sheet of a pack id range (the pack's `items.xml` names
   the ranges: grounds 100-214, borders 215-517, walls 518-1011, doors 1012-1086, objects 1087-1314,
   plants 1315-1499, trees 1500-1591, stones 1592-1676, mountain rims 2253-2257) with `otsp.compose`.
2. Change the table above, then re-export what it reads: `python tools/generators/otsp_export.py world`
   (`assets/sprites/world.png` and the generated `game/render/pack_atlas.gd`; add new id ranges to
   `WORLD_RANGES`), `outfits`, `items`, or `palette`, and reimport (`make import`).
3. Look at the result in the game (the visual test's captures in `.tools/`), against neighbouring
   things. Art is never unit-tested.

## How the pack draws

- A thing stands with its bottom-right corner on its tile and rises up and left (`WallArt.draw`).
- Grounds pick their pattern by cell position (`GroundArt.piece`), so they tile.
- Borders: n, e, s, w along a side; cnw, cne, csw, cse small corners; dnw, dne, dsw, dse large
  diagonals. The pack lists a set's pieces in that order.
- Walls lie along their cell's east (vertical) and south (horizontal) edges: vertical where the wall
  goes on north, horizontal where it goes on west, corner for both, pole otherwise.
- The pack's view leans: side-facing figures look like they are leaning over. That is the pack's
  style, not a bug.
