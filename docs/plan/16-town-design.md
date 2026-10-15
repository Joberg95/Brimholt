# 16 - Town design and cobblestone streets

**Effort:** M-L

## Request
Towns that feel designed: more decorations and more cobblestone streets.

## Today
Towns are painted in `overworld.tscn`; there is a cobble ramp (`COBBLE` in `make_sprites.py`) and
some paved cells.

## Steps
1. Cobblestone street tiles: a seamless field with variants and edges where cobble meets grass or
   dirt (so streets have curbs, not a hard grid), with the `art-direction` skill.
2. For each town: streets from every gate to the square and to every service, a central square
   (well, fountain, statue or market stalls), small yards with fences.
3. Outdoor decorations: lamp posts (lit at night through `lighting.gd`), benches, crates and
   barrels by shops, market stalls, flower beds, signposts at junctions. Reuse the decoration
   markers from plan 15.
4. One town at a time, Redmeere last (plan 14 redesigns it).

## Tests
Unit: streets connect every gate and NPC; no decoration blocks a path. Visual-test capture of
each town square.

## Done when
Every town has paved streets, a square, and street decorations.
