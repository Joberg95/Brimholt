# 40 - The archipelago: biome islands with castle capitals

**Effort:** XL (one island per round, owner reviews each)  **Replaces:** plan 32

## Request
Grow the world the way Tibia's is laid out: many islands round the main continent, each with its
own biome, reached by boat. Every area gets the ground and plants that belong there, and the land
is good to roam (roads that go somewhere, landmarks, clearings, shores, no empty filler). Main
cities are castles, like Tibia's: thick grey stone walls with towers and gatehouses round paved
streets, a keep with a hall inside. Each landmass has one castle capital and one smaller town.

## Decisions (owner, 2026-10-20)
- **Content:** build each island's land, cities, roads, and docks now as a future level 50-100
  region; seed its camps with today's level 35-50 monsters until phase 3 of the world expansion
  (`docs/handoff/world-expansion.md`) adds the 50-100 monsters and gear.
- **First wave:** six islands, one per biome: elven forest, desert, jungle, swamp and necropolis,
  volcanic dragon land, and a northern island beside the frost isles. Each about 150-250 tiles
  across, with a castle capital, a smaller town, roads, a dungeon, and a boss. Build one, show
  it, then the rest.
- **Mainland:** Cinder Crossing stays its only castle capital; one other town stays a town, the
  rest become outposts later (a separate round, with the task chains).
- The old sketch is dropped. Islands lie east and south of the heartland, higher level further out.

## The look: castles, decorations, and furniture (owner's reference, 2026-10-20)
The owner's reference is a small Tibia keep on a snowy shore; match its look closely and draw
every pixel here (art-direction skill):
- **Walls:** thick rubble walls of rounded grey fieldstones, light on top and the upper-left,
  dark between the stones, a full tile tall; the keep's outline steps in and out (wings, an
  entrance bay), not one plain box.
- **Floors:** large cream sandstone flags (one or two per tile) with fine dark joints; a big red
  carpet with a gold-orange fringe down the hall.
- **Inside the hall:** square stone pillars standing in rows, each casting a long shadow to the
  lower right; red banners with a gold crown on the walls between the pillars; wall torches with
  a real flame; armoured knight statues either side of the door to the next room; flower vases,
  potted plants in clay pots, a sign; light stone stairs going up and a dark stairwell going
  down.
- **Living room:** a tall bookcase of coloured books, crates and chests, a small table, a bed
  with a blue blanket, chairs round a table with a candelabra, a fruit bowl, a clay pot, a
  stove, a picture on the wall.
- **The door outside:** a plank gate in the wall flanked by two dark gargoyle statues on stone
  plinths and round green bushes.
- **Snow** (the owner's snow reference): nearly white and smooth, long soft wind streaks of
  pale blue-grey curving across it, small tufts of grass poking through, and grass patches with
  a ragged edge that frays into the snow.
- **Round it:** the biome's ground with patches (here snow with grass showing through), dead
  branches, fallen logs, small stones, fir trees, and a shore with an earthen bank.
Each piece is furniture (blocks like the shop furniture) or a wall decoration (drawn on the
wall's face), so castles, houses, and shops are furnished from one catalogue.

## Layout (first wave, 1920 x 1920 overworld, heartland at 0-384 x 0-552)
| Island | Biome | Cells (approx.) | Band (now / later) |
| --- | --- | --- | --- |
| Silverwood | elven forest, lakes | 500-740 x 60-280 | 45-50 / 50-60 |
| Duskmarsh | swamp, necropolis | 880-1120 x 400-640 | 45-50 / 70-80 |
| Sunreach | desert, oasis, sandstone | 470-750 x 660-900 | 45-50 / 60-70 |
| Verdance | jungle, rivers, ruins | 150-420 x 760-1040 | 45-50 / 65-75 |
| Ashpeak | volcanic, dragons | 1000-1240 x 900-1150 | 45-50 / 80-90 |
| Rimehold | northern, fjords | 880-1100 x 40-240 | 45-50 / 75-85 |

## Steps (per island)
1. **Tiles first.** The biome's ground, plants, and walls as hand-pixelled art (pixel_floors.py
   and the object builders), new terrain letters where the gameplay differs (blocking, walkable).
   Before the first island: the castle set above (fieldstone walls, sandstone flags, carpet,
   pillars, banners, statues, and the furniture catalogue).
2. **Island painter** (`tools/generators/islands.gd`, `make islands`): a ragged coast with
   beaches, the biome's terrain (woods with clearings, hills, lakes, rivers with bridges), a
   castle capital, a smaller town, roads joining gates, docks, the dungeon, and the hunts, and
   placeholder camps. Paints each island once (scene metadata `island_<id>`), then the scene
   is the source of truth, like the other passes.
3. **Castle capital** from a layout: castle walls and towers with gatehouses, cobbled streets on
   a grid with a square, the keep (stone hall floor, carpet, throne), houses, shops and a bank
   (`towns.gd`), a harbour with a ferry.
4. **Links:** ferry routes to Cinder Crossing and the neighbouring islands; zones (town safe,
   hunting regions with level ranges); region names (`game/data/regions.gd`).
5. **Bake** the world map pages; rules checks (reachability by boat, towns safe, camps on open
   ground, every road reaches a gate); look in game with the art-direction review; playtest.

## Progress
- 2026-10-20: the castle set (fieldstone walls, sandstone flags, carpet, pillars, statues,
  gargoyles, banners, torches, paintings, the furniture catalogue, Decor markers), the island
  painter, and **Silverwood** (Aldmoor's castle and keep, Fernhollow, roads, harbour, 100+
  placeholder camps). Owner reviewed it ("looks pretty good") and asked for two really big caves
  to farm, so the island has a purpose: Thornroot Hollows and Moonwell Deeps (game/data/caves.gd,
  300 x 220 with 200 halls of dense camps each (made bigger twice at the owner's request), mouths in the island's woods). Every island gets
  big farming caves like these. Its dungeon and
  boss come with the island's own monsters (phase 3).

## Tests
Unit: every island is reached by boat from the mainland and back; each landmass has one castle
capital and at most one smaller town; every camp stands on walkable open ground of its island;
roads join the capital's gates to the town and the docks.

## Done when
Six islands, each with its own look, castle capital, town, roads, dungeon, and boss, on the
world map, reachable by boat.
