# 47 - The world plan: the frame frozen, every landmass and floor listed

**Effort:** S (a plan, no code)  **Part of:** plan 46 ("World size and how we build it", step 1)
**Owner request (2026-10-21):** fix where every landmass goes for the final world now, so nothing
is doubled or relocated again.

## Rules of the frame
- **Frozen.** The overworld stays 1920 × 1920 (`Atlas.OVERWORLD_SIZE`). Every landmass and reserved
  area below keeps its rectangle for good: no more `relocate.gd`, no save migrations for moves.
  Land grows inside its rectangle, never by moving it.
- **Changing the frame** takes an owner decision written into this file (date and reason) before
  any cell moves.
- **Sea between landmasses** is at least 64 tiles wide (as `Biomes.ISLES_SEA`), so each continent
  is crossed only by boat (`Atlas.CONTINENTS`). Anything outside a rectangle stays deep sea.
  Small islets (a quest rock, a lighthouse) need their own row here first.
- **Level rises with distance from Cinder Crossing**, roughly: mainland 1-50, first islands 50-90,
  the reaches 85-100, the far south-east past 100. Depth or height on a landmass means danger: the
  further from the surface, the higher the level (plan 46, "Floors: target").
- **Rectangles are bounds, not coastlines.** The island painter draws a ragged coast inside them.
- **Off-frame bands** (east of x = 1920) are not land: the instanced dungeons (`Dungeons.BAND_X`
  1924 to `BAND_END` 2116, then the Void Throne arena), the cave band (`Caves.BAND_X`), and today's
  underground plane (`Atlas.UNDER_X` 2560). After the floors-as-z refactor (plan 46, step 2) the
  plane becomes floor −1 at the same x, y, and only the instanced dungeons stay in a band, because
  their parallel copies can't all lie under one stairway.

## The map (one character = 64 tiles)

```text
x 0                            960                          1920
  MMMMMMMMMM.SSSSS..eeeeeeeeeeee   M  the mainland (built)
  MMMMMMMMMM.SSSSS..eeeeeeeeeeee   S  Silverwood (built)
  MMMMMMMMMM.SSSSS..eeeeeeeeeeee   F  the frost isles (built)
  MMMMMMMMMM.SSSSS..eeeeeeeeeeee   V  Verdance
  MMMMMMMMMM.SSSSS..eeeeeeeeeeee   U  Sunreach
  MMMMMMMMMM........eeeeeeeeeeee   D  Duskmarsh
  MMMMMMMMMM.VVVVVV.eeeeeeeeeeee   R  Rimehold
  MMMMMMMMMM.VVVVVV.eeeeeeeeeeee   A  Ashpeak
  MMMMMMMMMM.VVVVVV.eeeeeeeeeeee   e  the east reach (reserved)
  MMMMMMMMMM.VVVVVV.eeeeeeeeeeee   s  the south reach (reserved)
  ...........VVVVVV.eeeeeeeeeeee   x  the far south-east (reserved)
  FFF..UUUUUU.......eeeeeeeeeeee   .  deep sea
  FFF..UUUUUU...................
  .....UUUUUUDDDDD..............
  RRRRRUUUUUUDDDDD..............
  RRRRRUUUUUUDDDDD.AAAA.........
  RRRRR......DDDDD.AAAA.........
  RRRRR......DDDDD.AAAA.........
  .................AAAA.........
  .................AAAA.........
  ssssssssssssssss......xxxxxxxx
  ssssssssssssssss......xxxxxxxx
  ssssssssssssssss......xxxxxxxx
  ssssssssssssssss......xxxxxxxx
  ssssssssssssssss......xxxxxxxx
  ssssssssssssssss......xxxxxxxx
  ssssssssssssssss......xxxxxxxx
  ssssssssssssssss......xxxxxxxx
  ssssssssssssssss......xxxxxxxx
  ssssssssssssssss......xxxxxxxx
y 1920
```

## Landmasses

| Landmass | Bounds (x, y, w × h) | Biome | Levels (now / final) | Capital, town | Pillar | Status |
| --- | --- | --- | --- | --- | --- | --- |
| The mainland | 0, 0, 640 × 640 | All the heartland's biomes, the desert, the lake | 1-50 | Cinder Crossing; Reedmere, Ashford, Dunmere, Highmoor, Lastlight, Brackenford | Ember against reed | Built |
| The frost isles | 0, 704, 160 × 128 | Snow, firs, sea ice | As today | Hrimvik | The land that wakes | Built |
| Silverwood | 760, 60, 240 × 220 | Elven forest, still lakes | 45-50 / 50-60 | Aldmoor; Fernhollow | Runes and old stone | Built (layout) |
| Sunreach | 380, 740, 280 × 240 | Desert, oasis, sandstone | 45-50 / 60-70 | To name | Runes and old stone | Planned |
| Verdance | 760, 400, 280 × 280 | Jungle, rivers, ruins | 45-50 / 65-75 | To name | The land that wakes | Planned |
| Duskmarsh | 760, 860, 260 × 260 | Swamp, necropolis | 45-50 / 70-80 | To name | The Hollow creeps in | Planned |
| Rimehold | 0, 900, 288 × 250 | Northern fjords, beside the frost isles | 45-50 / 75-85 | To name | Grey castles in a wild land | Planned |
| Ashpeak | 1100, 1000, 240 × 240 | Volcanic, dragons | 45-50 / 80-90 | To name | Ember against reed | Planned |

Sunreach to Ashpeak are plan 40's first wave. It gave them rough cells that no longer fit:
Rimehold overlapped Silverwood after Silverwood moved east, and Verdance overlapped the frost isles
after they moved south (plan 43). The bounds above replace plan 40's layout table. Each
landmass still gets one castle capital and one smaller town (plan 40). "Now" is the placeholder
band until the level 50-100 monsters arrive (`docs/handoff/world-expansion.md`, phase 3).

## Reserved areas (later waves, kept as sea until chosen)

| Area | Bounds | Levels | Idea (not decided) |
| --- | --- | --- | --- |
| The east reach | 1180, 60, 680 × 700 | 85-100 | Up to two landmasses: a highland continent with large +1/+2 plateaus |
| The south reach | 60, 1300, 940 × 560 | 85-100 | Up to two landmasses: a sunken empire, sea caves |
| The far south-east | 1420, 1300, 440 × 560 | 100+ | Where the Hollow comes from: the deepest floors and the last bosses |

## Floors per landmass
Floors are partial (void where nothing is built); only the surface is full. Target levels:
+3 peaks, +2 highlands, +1 upper, 0 surface, −1 shallow, −2 deep (plan 46).

| Landmass | +3 | +2 | +1 | 0 | −1 | −2 |
| --- | --- | --- | --- | --- | --- | --- |
| The mainland | | Greycrag Peaks plateau | Storeys and walls in the towns, Cinder Crossing's keep and walls, Kestrel Heights | ✓ | Tunnels and sewers (plan 44, built), Ogre Warrens, Drowned Grotto | Under Smoulder Fells and Emberwaste: Ember Deep and Cyclops Hollow rebuilt as multi-floor hunts |
| The frost isles | | | Hrimvik storeys | ✓ | Rimewater Trench (built) | |
| Silverwood | | | Treetop village, Aldmoor's keep and walls | ✓ | Thornroot Hollows (built) | Moonwell Deeps rebuilt |
| Sunreach | | | Rooftops of the sandstone capital | ✓ | Tombs | Pyramid deep, boss |
| Verdance | | | Canopy walks | ✓ | Overgrown ruins | Temple deep, boss |
| Duskmarsh | | | | ✓ | Crypts | Necropolis deep, boss |
| Rimehold | | Fjord highlands | Castle walls | ✓ | Ice caves | Frostvault rebuilt, boss |
| Ashpeak | Summit, dragon's eyrie | Volcano slopes | Ridges | ✓ | Lava tubes | Magma deep, boss |

Frostvault moves from the Hollow March to Rimehold's deep because it doesn't fit under its mouth
(plan 45) and it fits the north. This is a proposal; the owner can keep it on the mainland.

## Density target (each 100 × 100 tiles of land)
Measured instead of tiles painted (plan 46, step 6): at least four landmarks, one way down (a cave
mouth, a hole, or a ladder), six camps, and a road or a shore path within about 30 tiles of any
cell. Towns and dungeons count apart.

## Ferry links
- Cinder Crossing ↔ every landmass's capital (the main route, as plan 40 asks).
- Neighbours: Silverwood ↔ Verdance, Verdance ↔ Duskmarsh, Duskmarsh ↔ Sunreach, Duskmarsh ↔
  Ashpeak, Sunreach ↔ the frost isles, the frost isles ↔ Rimehold.
- The reaches link to their nearest built landmass once they're built.

## Next (plan 46's order)
1. ~~Write the world plan~~ (this file).
2. ~~Floors as z refactor (engine)~~, with the underground plane moved to floor −1 (floor slots at
   `Atlas.FLOOR_X`; drawing across floors is plan 46 step 2b).
3. ~~Base and override layers plus `make region`~~; Silverwood converted (plan 46 step 3).
4. Editor brushes.
5. Build the landmasses above one at a time from their rows (plan 40's islands as region specs).

## Open
- Names of the new capitals and towns (chosen when each landmass is built).
- Frostvault's new home (proposal above).
- Whether the frost isles' level band should rise to sit between the mainland and Rimehold.
