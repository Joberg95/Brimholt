# 23 - Remove the small stones

**Effort:** S

## Request
Remove the small stones: they add nothing but annoyance.

## Today
825 boulders ("R", `objects.png`: a rounded boulder, a pair of rocks, a mossy slab) dot the
overworld, placed by `tools/generators/landscape.gd`. They block movement (World.TREES has "R"),
so walking and chasing keeps snagging on them. Mountains ("L") and rock outcrops ("C") are
separate and stay.

## Steps
1. A one-time generator (`tools/generators/clear_boulders.gd`, `make clear-boulders`) turns
   every overworld "R" into the ground around it (grass, sand, dirt: the most common open
   neighbour), and says how many it changed; running again changes nothing.
2. Rules check: no "R" left on the overworld (keep the terrain code for the editor palette).
3. Re-bake the world map (`make world-map`).
4. Docs: `docs/world-editing.md` and `docs/gameplay.md` no longer mention boulders in the meadows.

## Done when
No boulders on the map; walking across the land never snags on a stone.
