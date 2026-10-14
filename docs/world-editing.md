# Designing the world

The overworld is a Godot scene; this is how to edit it safely.

The world is the scene `game/maps/overworld.tscn`; open it in the Godot editor:

1. **Terrain**: select the `Terrain` node and use the TileMap panel at the bottom to paint
   with the palette (`game/maps/terrain.tres`). Each tile's custom data `terrain` sets its
   gameplay: grass `.`, dirt road `,`, water `~`, stone wall `#`, tree `T`, sand `:`,
   cobblestone `=`, boulder `R`, mountain rock `L`, pier/bridge `b`, and the Hollow Reach's dusk soil `d`, obsidian floor
   `o`, obsidian wall `O`, and dead tree `D`. Water, walls, trees, boulders, and mountain rock block movement; cave rock `C` on the overworld is a rock outcrop. The editor
   shows flat palette tiles; in game they become oblique walls, tall trees, shorelines, and
   plank piers. Keep the map at non-negative coordinates; unpainted cells are void.
2. **Spawns**: the twelve `Marker2D` nodes under `Spawns`, one per player, in order.
3. **Ferrymen and waystones**: nodes under `Ferrymen` (set `vehicle` to `ferry` for a pier
   ferryman, or `waystone` for an inland standing stone, drawn as a stone with a glowing rune).
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
7. **Quest givers**: nodes under `QuestGivers` with a name, place, and facing. The node name is
   the id: a giver offers every task in `game/data/quests.gd` whose `giver` is that id, and
   a relic keeper trades the trophies of the boss `Quests.RELIC_KEEPERS` assigns to it. Like
   ferrymen, they block their tile and answer within 2 tiles. `make towns` places the relic
   keepers in Reedmere and the dungeon task givers by their stairways (`QUEST_GIVERS` in
   `tools/generators/towns.gd`).
9. **Dungeon entrances**: nodes under `DungeonEntrances`, with `dungeon` set to a
   `game/data/dungeons.gd` id. Keep them inside a town zone.
8. **Townsfolk**: vendors and the banker, nodes under `Townsfolk` with a name, place, facing,
   and `role` (`vendor` or `banker`). Every town zone has a vendor; only Reedmere has a
   banker (`towns.gd` `BANK_PLACE`). The rules check verifies both. `make towns` moves them
   into buildings.

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
`make_map.gd` applies the same painter to a freshly generated map. The overworld is
384×384; `make map-force` regenerates it in a few seconds.

**Instanced dungeons** are defined in `game/data/dungeons.gd`: an ASCII layout (walls, floor,
one arrival `@`, one stairs up `^`, and monster symbols), its monster legend, its number of
copies, and light. `tools/generators/dungeons.gd` (`make dungeons`) repaints every copy in
the band right of the overworld and the stairway under each `DungeonEntrances` marker, keeping
other edits. Move a `DungeonEntrance` marker in Godot to move a stairway, then run
`make dungeons` and the rules check. Never paint gameplay into the dungeon band by hand: the
painter replaces it.

**The south-western desert** is defined by `game/data/biomes.gd` (an ellipse) and painted by
`tools/generators/desert.gd` (`make desert`): inside it, grass (`.`) and trees (`T`) where
most of the surroundings are sand become sand (`:`) or cactus scrub (`K`, a blocking plant on
sand). It repeats until nothing changes, so re-running it is harmless, and it never touches
water, walls, roads, towns, spawns, or items. Paint `K` by hand for single cacti. Sand next to
grass draws a dry-grass fringe automatically.

**Regions** are defined in `game/data/regions.gd`: a name, an anchor tile, and a one-line
description. Every overworld tile belongs to the nearest anchor (the desert is always the
Sunscar Dunes); towns and the PvP zones keep their own zones on top. Levels are not stored:
`World` derives each region's range from the monster spawns inside it (bosses excluded). Move
an anchor to reshape regions; add one to split a region.

**Blackreed Isle** is kept open for PvP: `tools/generators/island.gd` (`make island`) keeps about
a quarter of the trees inside its zone (a fixed hash of each tile picks which) and turns the rest
into grass. Re-running it changes nothing.

**The landscape pass** (`tools/generators/landscape.gd`, `make landscape`) turned the first
draft into settled countryside, once (the scene's `landscape` metadata stops a second run):
- Every town grew outward where the land was free, with a stone town wall, three-tile gates
  where roads enter (or one in the middle of a side without a road), a row of houses against
  the wall, a cobbled street inside them, and more houses on open ground.
- Cinder Landing was merged into Cinder Crossing (`MERGES`): one start town from the training
  hall to the harbour, with a four-tile eastern district and an open cobbled plaza between the old
  towns, kept free for a future starter guide.
- Reedmere, the capital, has a walled castle on its west side (`CASTLE`): a keep, barracks and a
  chapel around a courtyard, corner towers, and a gate toward the town.
- Dirt roads between towns became two-tile cobblestone.
- The speckled forest became woods and meadows (two layers of smooth noise), with rock outcrops
  (`C`, drawn on grass outside dungeons) and boulders (`R`, a blocking object like trees),
  more in the north-eastern highlands, and a few dry-stone pastures (`#`) outside towns.
- Monster camps in the way were moved just outside, in the same region, and the shortest way
  back to any marker cut off by trees or rock was cleared.
Run `make towns` after it to move vendors into free buildings. Edit the constants and restore
the scene from git to try again; otherwise paint over the result in Godot like any other edit.

**Mountains** (`L`: masses of grey boulders over grit) were added by
`tools/generators/cliffs.gd` (`make cliffs`), once (scene metadata `cliffs`): they fill the high
ground of a smooth height field, more in the north-eastern highlands, broken by passes, kept
clear of roads, water, towns, markers, and camps, with no trees inside or at their foot. The same pass cut
about 30% of the countryside trees. Ground a cliff closed off got a way in, and every marker
stays reachable. Paint `L` by hand for more rock.

**Hunting grounds** for the Hunters' Lodge and the level-50 elites are placed by
`tools/generators/hunts.gd` (`make hunts`): camps named `Hunt_<monster>_<n>` in the region that
suits each prey (`HUNTS`), on open meadow that can be walked to, away from zones and other camps;
the elite rows also keep seven tiles from roads. Existing camps are kept, so running it again
changes nothing; move them in Godot like any other spawn.

**Buildings** are found from the walls: a room of at most 48 tiles in a town zone, enclosed
by `#` walls and doors (an open tile between two walls in a line). They get a roof, and
nobody inside can be dealt with from outside. Paint houses at least three tiles wide inside.
`tools/generators/towns.gd` (`make towns`) builds the shops and banks a town lacks (its
`PATCHES`), removes bankers outside `BANK_PLACE`, and moves every vendor and the banker to the
back of a free building, facing the door: vendors to the first (north-west) building, the
banker to the last, skipping buildings with stairs or other NPCs. A sign and furniture
(`World.FURNISHINGS`) are added automatically at load. Re-run it after moving
houses; a second run changes nothing, and it refuses to wall in any marker.
