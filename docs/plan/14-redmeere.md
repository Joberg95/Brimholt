# 14 - Open Redmeere with castle houses

**Effort:** L  **References:** the `art-direction` skill's reference looks

## Request
Redesign Redmeere as an open town inside its walls, with gates west, north and south. Houses
become more castle-like (references to come).

## Today
Redmeere is painted in `game/maps/overworld.tscn` (walls, houses, NPC markers). Buildings are
found from walls by `game/data/buildings.gd`; roofs by `roof_art.gd`; castle blocks exist in
`make_sprites.py` (`castle_block`, `cuboid`, `_ashlar`).

## Steps
1. Sketch the new layout as a text grid in this plan first (walls, gates, streets, squares,
   houses, NPC spots) and agree on it before painting.
2. Paint it in the map: the town wall with gates west, north and south (gatehouse towers), open
   squares, cobblestone streets (plan 16) linking the gates to the centre.
3. Castle houses: stone ashlar walls in the house wall height (plan 01), crenellated tops or slate
   roofs, arched doors, a keep for the main building. New builders reuse `castle_block` and the
   house wall code.
4. Move NPC, quest giver, vendor and depot markers; keep every service reachable. Update
   `docs/world-editing.md` if the painting workflow changes.
5. Bots: check `Nav` paths through the new gates, and rival bands' town spots.

## Tests
Unit: every NPC in Redmeere is reachable from each gate; buildings detected by `Buildings` match
the intended houses. Visual-test capture of the town centre.

## Done when
Redmeere is an open walled town with three gates and castle-style houses.
