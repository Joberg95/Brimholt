# Designing the world

The overworld is a Godot scene; this is how to edit it safely.

The world is the scene `game/maps/overworld.tscn`; open it in the Godot editor:

1. **Terrain**: select the `Terrain` node and use the TileMap panel at the bottom to paint
   with the palette (`game/maps/terrain.tres`). Each tile's custom data `terrain` sets its
   gameplay: grass `.`, dirt road `,`, water `~`, stone wall `#`, tree `T`, sand `:`,
   cobblestone `=`, pier/bridge `b`, and the Hollow Reach's dusk soil `d`, obsidian floor
   `o`, obsidian wall `O`, and dead tree `D`. Water, walls, and trees block movement. The editor
   shows flat palette tiles; in game they become oblique walls, tall trees, shorelines, and
   plank piers. Keep the map at non-negative coordinates; unpainted cells are void.
2. **Spawns**: the twelve `Marker2D` nodes under `Spawns`, one per player, in order.
3. **Ferrymen and coachmen**: nodes under `Ferrymen` (set `vehicle` to `ferry` or `coach`).
   The node name is the id; set the name,
   dock name, facing, and `routes` (destination ferryman id → fare in gold) in the
   Inspector. Put a ferryman at the end of a pier with walkable tiles within 2 tiles.
4. **Items**: nodes under `Items` with an item id from `game/core/world.gd`, such as
   `gold_coins` or `glowcap`. Several markers on one tile make a stack.
5. **Zones**: nodes under `Zones`, placed on a tile corner, with a size in tiles, a name,
   a PvP flag, a full-loot flag (dying drops every worn item), a town flag (safe: no PvP, monsters
   stay out), an ambient light colour, and a level range. The editor shows them as red rectangles.
6. **Monster spawns**: nodes under `MonsterSpawns` with a monster id from
   `game/data/monsters.gd`, level (1–50), count, and spawn radius.
   The three final-boss lairs (`MorvainLair`, `KharzulLair`, `SylvaineLair`) are spawns
   too: count 1, radius 1, level 50.
7. **Quest givers**: nodes under `QuestGivers` with a name, place, facing, and `task` (a
   `game/data/quests.gd` id). The node name is the id; `relic_keeper` is Ysolde (no task),
   who trades boss trophies for relics. Like ferrymen, they block their tile and answer
   within 2 tiles.
8. **Townsfolk**: vendors and bankers, nodes under `Townsfolk` with a name, place, facing,
   and `role` (`vendor` or `banker`). Every town zone should have one of each; the rules
   check verifies it. The generator places them on each town plaza.

A marker belongs to the tile its position falls in. Save the scene and run the rules
check: it verifies terrain, markers, routes, zone and spawn levels, and that every
ferryman and item can be reached on foot or by boat from the spawns. Every player must use the same map, because
it is part of the connection handshake. `tools/generators/make_map.gd` generated the first draft;
rerunning it with `make map-force`
**replaces your edits**, so treat the scene as the source of truth.

**The Hollow Reach** is painted by `tools/generators/endgame_zone.gd` (`make endgame-zone`):
it repaints only the zone rectangle in the existing scene (terrain, its monster spawns, and
the `HollowReach` zone node) and keeps every other edit. Edit the layout constants there
(area, gate row, Sanctum rooms, spawns) and re-run it, or paint over the zone by hand in
Godot afterwards; once you do, the scene is the source of truth for the zone too.
`make_map.gd` applies the same painter to a freshly generated map. The map is 768×768, so the
scene file is large (about 9 MB); `make map-force` regenerates it in a few seconds.
