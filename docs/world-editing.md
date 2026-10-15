# Designing the world

The overworld is a Godot scene; this is how to edit it safely.

The world is the scene `game/maps/overworld.tscn`; open it in the Godot editor:

1. **Terrain**: select the `Terrain` node and use the TileMap panel at the bottom to paint
   with the palette (`game/maps/terrain.tres`). Each tile's custom data `terrain` sets its
   gameplay: grass `.`, dirt road `,`, water `~`, stone wall `#`, tree `T`, sand `:`,
   cobblestone `=`, boulder `R`, mountain rock `L`, castle wall `W` (a 2×2 block of it is a tower), pier/bridge `b`, and the Hollow Reach's dusk soil `d`, obsidian floor
   `o`, obsidian wall `O`, dead tree `D`, and Mirewood Fen's bog mud `m` and giant mushroom `U`. Water, walls, castle walls, trees, giant mushrooms, boulders, and mountain rock block movement; cave rock `C` on the overworld is a rock outcrop. The editor
   shows flat palette tiles; in game they become oblique walls, tall trees, shorelines, and
   plank piers. Keep the map at non-negative coordinates; unpainted cells are void.
2. **Spawns**: the twenty-four `Marker2D` nodes under `Spawns`, one per player, in order.
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
  more in the north-eastern highlands, and a few dry-stone pastures (`#`) outside towns. The
  boulders were cleared again later (`tools/generators/clear_boulders.gd`, `make clear-boulders`):
  they only snagged walking; the rules check keeps the overworld free of them.
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

**The Void Throne** (`tools/generators/void_throne.gd`, `make void-throne`): an arena beyond the dungeon
band, a level-50 full-loot PvP zone with Vaelith on the throne, reached through the free Void Gate
(a ferryman marker with vehicle `gate`) that stands in the Hollow Sanctum's throne room. It lies
past `Dungeons.BAND_END`, so repainting the dungeon band (`make dungeons`) leaves it alone.

**Mirewood Fen** (`Biomes.SWAMP_REGION`) was turned into a swamp by `tools/generators/swamp.gd`
(`make swamp`): open grass became bog mud (`m`) but for grassy hummocks, three trees in four
became giant mushrooms (`U`), and small murky pools, well apart and away from camps and roads,
open in the mud, each crossed both ways by plank walkways. The scene remembers it ran (metadata
`swamp`), so a re-run changes nothing; edit the fen by hand afterwards.

**Reedmere** was rebuilt by `tools/generators/reedmere.gd` (`make reedmere`): its west half,
once a walled castle compound, is an open quarter of streets around a square with four stone
houses (slate roofs, `RoofArt.SLATE_TOWN`), the town wall is castle wall, and a west gate opens
on the main street beside the old south-west one. The east quarter keeps its buildings without
the trees that crowded them, and the waystone stands in an open square beside the bank. Edit its
`LAYOUT` and run it again.

**Door paths** (`tools/generators/town_paths.gd`, `make town-paths`): every town door gets a
cobbled path to the nearest street, the shortest walk over open ground (a tree is cut only if
there is no other way). After adding a house, run it; the rules check fails while a door opens
onto grass with no street.

**Caves** (Highmoor deep mine, Silkhollow) are grown by `tools/generators/cave_layouts.py`:
irregular chambers joined by winding two-wide tunnels, the stairs at the north-west end, the
boss in the farthest open chamber, monsters spread through the rest. It writes the layout's
rows into `game/data/dungeons.gd`; then run `make dungeons` to paint the copies (the painter
clears the dungeon band first, so a layout may change size). Hand-drawn layouts (the cellar,
the crypt) may hold props: `B` a barrel and `X` a crate (`Dungeons.PROPS`), which block like
furniture; the rules check makes sure every open tile can still be reached.

**The world map** is painted from the map by `tools/generators/world_map.gd` (`make world-map`):
four pixels per tile in `assets/sprites/world_map.png`, with the map's hash in
`world_map.json`. After editing the terrain or buildings, bake it again; until then the game
shows a flat one-pixel-per-tile map, and the rules check fails with a reminder.

**Camp density**: `tools/generators/camp_density.gd` (`make camp-density`) made every camp of a
normal monster from level 11 a tight pack of 5-7 within two tiles, so a 25-kill task is two or
three camp clears. The starter camps stay at 3-4. It ran once (scene metadata `camp_density`);
set `count` and `radius` on a marker by hand from then on, and the rules check keeps them at 5-7.

**Buildings** are found from the walls: a room of at most 48 tiles in a town zone, enclosed
by `#` walls and doors (an open tile between two walls in a line). They get a roof, and
nobody inside can be dealt with from outside. Paint houses at least three tiles wide inside.
`tools/generators/towns.gd` (`make towns`) builds the shops and banks a town lacks (its
`PATCHES`), removes bankers outside `BANK_PLACE`, adds one artisan per town (`ARTISANS`,
Townsfolk role `artisan`: the Craft service), and moves every vendor, artisan, and the banker to the
back of a free building, facing the door: vendors to the first (north-west) building, the
banker and artisans from the last, skipping buildings with stairs or other NPCs. A sign and furniture
(`World.FURNISHINGS`) are added automatically at load. Re-run it after moving
houses; a second run changes nothing, and it refuses to wall in any marker.

**Cinder Crossing's castle walls** are painted by `tools/generators/castle_town.gd`
(`make castle-town`): wall runs, gate gaps, towers, and a few ground patches listed at the top of
the file. **The trail to Silkhollow** is cut by `tools/generators/silkhollow.gd` (`make silkhollow`).
Both only change their own cells and refuse to wall over a marker; re-running them changes
nothing. Ore veins are not painted: `Crafting.ORES` picks them from rock faces that look south
onto open ground (`Professions.ore_at`).
