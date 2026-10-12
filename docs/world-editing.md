# Designing the world

The overworld is a Godot scene; this is how to edit it safely.

The world is the scene `game/maps/overworld.tscn`; open it in the Godot editor:

1. **Terrain**: select the `Terrain` node and use the TileMap panel at the bottom to paint
   with the palette (`game/maps/terrain.tres`). Each tile's custom data `terrain` sets its
   gameplay: grass `.`, dirt road `,`, water `~`, stone wall `#`, tree `T`, sand `:`,
   cobblestone `=`, pier/bridge `b`. Water, walls, and trees block movement. The editor
   shows flat palette tiles; in game they become oblique walls, tall trees, shorelines, and
   plank piers. Keep the map at non-negative coordinates; unpainted cells are void.
2. **Spawns**: the twelve `Marker2D` nodes under `Spawns`, one per player, in order.
3. **Ferrymen**: nodes under `Ferrymen`. The node name is the ferryman's id; set the name,
   dock name, facing, and `routes` (destination ferryman id → fare in gold) in the
   Inspector. Put a ferryman at the end of a pier with walkable tiles within 2 tiles.
4. **Items**: nodes under `Items` with an item id from `game/core/world.gd`, such as
   `gold_coins` or `glowcap`. Several markers on one tile make a stack.
5. **Zones**: nodes under `Zones`, placed on a tile corner, with a size in tiles, a name,
   a PvP flag, and a level range. The editor shows them as red rectangles.
6. **Monster spawns**: nodes under `MonsterSpawns` with a monster id from
   `game/data/monsters.gd`, level (1–50), count, and spawn radius.

A marker belongs to the tile its position falls in. Save the scene and run the rules
check: it verifies terrain, markers, routes, zone and spawn levels, and that every
ferryman and item can be reached on foot or by boat from the spawns. Every player must use the same map, because
it is part of the connection handshake. `tools/generators/make_map.gd` generated the first draft;
rerunning it with `make map-force`
**replaces your edits**, so treat the scene as the source of truth.
