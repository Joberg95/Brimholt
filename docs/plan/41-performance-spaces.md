# 41 - Performance: baked map, spaces, dormant camps, loading screens

**Effort:** L  **Owner decision (2026-10-20):** do this before growing the map; then double the
mainland to about 640 x 640 (south and east), moving Silverwood further east.

## Measured (2026-10-20, after Silverwood and its two 300 x 220 caves)
World startup 2.5 s on host and every client (0.8 s instantiating the map scene); terrain grid
4.7 MB; startup scans over World.PAINTED: nav grid 0.5 s, ores 0.4 s, herbs 0.2 s; 5,323 camp
monsters on the map, 7.9 s and ~53 MB if all are placed; host tick 0.04 ms (only monsters near
players). Rendering, floors, world map pages, and network interest already follow the player.

## Steps
1. **Baked map:** `MapIO.read_map()` returns terrain bytes plus every marker as a record
   {name, cell, props}; World builds from records. `make bake-map` (and every
   `MapIO.save_scene`) writes a compressed bake with a fingerprint of overworld.tscn, the
   sectors, and terrain.tres; a stale bake falls back to the scene with a warning (rules check
   fails), exported builds trust the bake. Add `game/maps/*.bake` to the export filter.
2. **Spaces:** each landmass (Atlas.CONTINENTS plus every island), cave, and dungeon copy;
   `World.space_at(cell)`.
3. **Dormant camps:** when no player has been in a space for some minutes, its camps despawn back
   to dormant (Combat.populate wakes them again).
4. **Lazy per-space work:** bot navigation built per space on first use.
5. **Loading screen** on travel between spaces (ferry, cave, dungeon).
