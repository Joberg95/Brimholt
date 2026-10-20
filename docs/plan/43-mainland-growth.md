# 43 - The mainland doubled: 640 x 640, levels 1-30 in the new land

**Effort:** L  **Owner request (2026-10-20):** make the starter mainland bigger, about double in
both directions; the frost isles move south-west, the new land is for levels 1-30.

## Request
1. Grow the mainland from 384 x 384 to about 640 x 640, east and south of today's heartland.
2. Move the frost isles south (they sat just below the old south coast) and Silverwood east.
3. Fill the new land for levels 1-30 so the starting hunts are less crowded: meadows, woods,
   hills, a lake district, a new smaller town and roads, today's low-level monsters.

## Done
- **Relocation (2026-10-20):** `make relocate` (tools/generators/relocate.gd, once) moved every
  cell and marker of the frost isles 280 rows south (now `Biomes.ISLES` = 0,704 160x128) and of
  Silverwood 260 columns east (760,60 240x220); the data that names their cells moved with them
  (regions, caves, the barracks entrance, quest givers, the generators). Saves from before move
  too (`CharacterStore` version 4, `RELOCATED`).
- **New land (2026-10-20):** `make mainland` (tools/generators/mainland.gd, once, built on the
  island painter) paints `Atlas.MAINLAND` = 0,0 640x640 round `Atlas.HEARTLAND` (the old 384):
  a ragged coast with headlands, bays, and beaches, a bay south of Lastlight that keeps its
  harbour on the open sea, eight regions (Bracken Leas, Hazel Downs, Wolfholt, Kestrel Heights,
  Greycrag Peaks, Fernmere, Barrowmoor, Saltreed Marsh) whose woods, lakes, and rock follow
  their character, the first cells by the heartland taking after its edge and a broken ridge of
  hills behind them. Brackenford, a walled town at the elbow with eight houses (trader, artisan),
  a coach station on every coach route, and roads from its four gates to Highmoor's and
  Lastlight's roads and down to the shores. 624 camps of 5-7: the level rises from 1 at
  Brackenford to 30 at the far ends, and each camp takes the monster whose heartland band is
  nearest (favouring the ground round it: wolves and bears in the woods, toads, lurkers, and
  lizards by water, golems, harpies, trolls, and cyclopes in the rock), at a level inside that
  band, so every task's level band stays as it was. Then `make towns town-paths cobble-towns
  world-map`.

- **Orcs (2026-10-20):** a new race to hunt. `make orcs` (tools/generators/orcs.gd, once) builds
  the Grimtusk Hold east of the north road: a stone fort (its walls kept by
  `ClearWalls.FORTS`) with huts, a campfire, a cauldron, banners, and the warlord's hut, and the
  mainland camps round it turned into rings of orcs. Seven monsters with their own painted sheets
  (creatures.py `orc`): orc, orc spearman, orc warrior, orc shaman (magic), orc berserker, orc
  leader, and Warlord Gruzzak (champion, Grimtusk warg mount); seven trophies to sell; Scout
  Rhydda in Brackenford with a four-task chain ending at the warlord.

## Next
- Owner review in game; paint over anything that reads wrong (the scene is the source of truth).
- Quest givers in Brackenford for its hunts, and a cave or two in the peaks and the meres.
