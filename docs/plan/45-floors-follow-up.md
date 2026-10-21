# 45 - Floors follow-up: map floors, road speed, markers, old caves below

**Effort:** L  **Owner request (2026-10-20):** the rest of the Tibia map comparison, after plan
44's underground floor.

## Decision (recommended, taken)
Shared farming and elite caves stay shared and move below, under their mouths. Instanced
dungeons stay in the band: their parallel copies cannot all lie under one stairway.

## Done (2026-10-20)
1. **World map floors:** ▲ and ▼ in the world map's header (or Page Up and Page Down) switch
   between the surface and the floor below, drawn in the same tiles as the land above it: the
   tunnels, sewers, and moved caves at one pixel per tile (`World.underground_bounds`, built once
   from the map; since plan 46 step 2, `World.floor_bounds(z)` for every floor), their names and levels, the ways up, your markers, and you. It opens on the floor
   you stand on. No baked pages are needed below (it is mostly void).
2. **Walking cost:** `World.GROUND_STEP`: a step onto a dirt road or a street takes 0.8 of a plain
   step, a bridge or a keep's floor 0.85, sand 1.1, snow 1.15, bog 1.3. Clients take each step's
   duration from the server; Nav weights its grids by it, so bots follow the roads.
3. **Map markers:** right-click the world map to place a marker (six icons: star, flag, cross,
   skull, coin, heart, and an optional label) or rename and remove one. Kept on this computer
   (`user://map_markers.json`), as Tibia keeps its minimap markers, and drawn on the world map
   (with labels) and the minimap, each on its own floor.
4. **Caves below:** `make caves-below` (tools/generators/caves_below.gd) moves the caves that
   game/data/caves.gd marks `below` out of the band, cells and camps, so their stairs lie right
   under their mouth (the mouth then pairs with them in `World.HOLES` too). Moved: the Ogre
   Warrens, the Drowned Grotto, the Rimewater Trench, and the Thornroot Hollows. `make caves`
   leaves moved caves alone; saves standing in a moved cave's old band rect follow it.

## Next
- **Ember Deep, Frostvault, Cyclops Hollow, Moonwell Deeps** do not fit under their mouths yet:
  the first two would overlap the Dunmere and Highmoor sewers, the Cyclops Hollow the Smoulder
  Deeps and the top edge, and the Moonwell Deeps the Thornroot Hollows and the top edge. Move
  their mouths (or trim the sewers) so each fits, then mark them `below` and run `make
  caves-below`.
- **More floors:** a second floor below (a plane per floor in Atlas) once there is content for
  the deepest hunts.
