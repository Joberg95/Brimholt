# 49 - All art from the OpenTibia sprite pack

**Effort:** XL  **Status:** started 2026-10-22 (branch `experiment/pack-paperdoll`); supersedes plan 48

## Request (owner, 2026-10-22)
Use all the art from the OpenTibia sprite pack (https://github.com/peonso/opentibia_sprite_pack,
CC BY 4.0) and stop making our own for now; delete what we made. Decisions:
- **Items:** the catalog is rebuilt from the pack. Each pack item sprite becomes one item with stats;
  our items without a matching sprite are deleted with their loot, shop, and quest entries.
- **Characters:** players wear the pack's outfits as in Tibia; gear is not drawn on the body.
- **Monsters:** only the pack's creatures (about 30); the rest are cut, and every camp, task, and boss
  that used a cut monster is re-seeded with the nearest pack creature by level and region.
- **World:** tiles, ground borders, walls, nature, town objects, doors, effects, and missiles all come
  from the pack.

The pack's license asks only for attribution: keep `assets/third_party/opentibia_sprite_pack/LICENSE.txt`,
`AUTHORS.md`, and the row in `assets/third_party/CREDITS.md`.

## What the pack has
`assets/third_party/opentibia_sprite_pack/`: twelve PNG sheets, the client files `otsp.dat` and
`otsp.spr` (protocol 10.41), and `server_files/items.xml` (category names per id).
`tools/generators/otsp.py` reads the client files: 2613 items (ids 100-2712; 1519 one tile, 971 two by
two), 46 outfits (four facings with walk frames), 64 effects, 60 missiles, 7691 sprites.

| Category (items.xml) | Count | | Category | Count |
| --- | --- | --- | --- | --- |
| sword | 148 | | wall | 418 |
| armor chest | 103 | | door / archway | 277 / 68 |
| helmet | ~67 | | border | 272 |
| axe | 63 | | plant / tree | 189 / 85 |
| shield | 39 | | mountain / stone(s) | 60 / 87 |
| distance weapon | 36 | | tile / grass | 56 / 25 |
| club | 29 | | object (town) | 300 |
| legs / boots | 20 / 15 | | roof | 79 |
| wand / grimoire | 15 / 5 | | bodies, pools | ~50 |
| equipment (tools, potions, rings, amulets, food, gems) | 75 | | | |

## Phases
1. **Pipeline.** `otsp.py` exports the game's sheets from the client files: item icons (one 32x32 frame
   per item, two-by-two items scaled to a slot or drawn on the ground at full size), outfits, creatures,
   effects, and missiles. Delete our own item, icon, worn-gear, and body art and their generators
   (`tools/icons/`, `pixel_worn.py`, `body.png`/`cloth.png` and the gear builders).
2. **Items.** Map each pack equipment sprite to an item: our item where one fits (its id, name, and
   role kept), else a new item; delete our items with no sprite (most boots and legs beyond the pack's
   15 and 20, amulets and rings beyond its few, capes, charms, mounts, and monster-drop materials unless
   a pack object fits). Stats from `Items.tier_stats` by slot and tier; names are our own. Update loot,
   shops, quests, start kits, relics, docs, and tests. A review sheet of every mapping comes first.
3. **Characters.** Players wear pack outfits (the player looktypes among the 46), chosen by vocation;
   remove the body, cloth, and gear layers and the worn-gear pipeline.
4. **Monsters.** The pack's creatures become the monster roster with level bands and loot; every camp,
   task, boss, and dungeon spawn of a cut monster is re-seeded with the nearest pack creature by level
   and region. Delete our creature art and its generator.
5. **World.** Grounds with the pack's borders, walls, mountains, trees and plants, town objects, doors,
   roofs, and stairs replace our tiles, walls, and props; the terrain shader's blending gives way to the
   pack's border tiles. Rebake the world map.
6. **Effects.** Spell effects and missiles from the pack.

Each phase: review renders by eye (art is never tested), functional tests, docs, commit.

## Progress
- **Phase 1 (done):** pack downloaded, `otsp.py` reads the client files, our item and worn art deleted.
- **Phase 2 (done):** `otsp_items.py` mapped 314 items to pack sprites (`sprite` in items.json) and
  deleted 205 (capes, charms, mounts, monster trophies, themed backpacks, most showpiece boots, and
  tier pieces past the pack's count, with their loot, shop, quest, and recipe entries); fish, logs, and
  herbs use pack food, tree logs, and plants. The cape, charm, and mount slots are gone (ten slots).
  `otsp_export.py items` writes `items.png`; `make_sprites.py` no longer writes item or mount sheets.
  Tier gaps: legs, boots, druid and sorcerer weapons and off-hands at some tiers; Sylvaine has no
  relics; dungeon champions lost their trophies. Phase 4 re-seeds loot and bosses.
- **Phase 3 (done):** players, townsfolk, and humanoid monsters wear pack outfits (`otsp_export.py
  outfits`, `SpriteArt.draw_actor`): Adventurer 17, Warrior 18, Hunter 45, Sorcerer 20, Druid 21,
  townsfolk 16, humanoid monsters 18, tinted through the pack's colour masks. The body, cloth, worn-gear,
  and mount code is gone (riding and its 25% step bonus too), along with the item-icon modules and about
  2,700 lines of `make_sprites.py`. The pack has no attack frames; the robes only tint hair.
- **Phase 4 (done):** monsters are the pack's creatures (`"outfit"` in monsters.gd, exported with the
  outfits). The 61 normal monsters folded into 30 pack creatures (Black cat, Ratkin, Brigand, the
  gargoyles, mages, ghosts, grubs, Fen dragon ...); every camp, task, dungeon legend, and generator was
  renamed to them, loot tables merged, and the farms' gear chance carried over. The 33 elites,
  champions, and bosses keep their names and roles in a pack creature's look, drawn larger; Vaelith and
  Morvain glow in their own colour now. Dungeon tasks name their dungeon (`"dungeon"`), and an overworld
  task's level band counts only camps within `World.TASK_SPAN` of its level. Our creature art, its
  sheets, and the creature builders are deleted (`creatures.py` kept only props' shading, now
  `shading.py`). Unused: the mount (looktype 12) and five creatures (5/40 and 10/35 are duplicates; 27, 43).
- **Phase 5 (done):** the world is the pack's. Floors are composed per chunk from pack grounds with
  Tibia's border pieces (`ground_art.gd`, `floor_layer.gd`; the terrain shader is gone); walls, doors,
  rock, and ores follow Tibia's wall rule (`wall_art.gd`); roofs are pack roof tiles raised a floor
  (`roof_art.gd`); trees, furniture, herbs, signs, decor, and waystones are pack things
  (`object_art.gd`). `otsp_export.py world` packs them into `world.png` and the generated
  `pack_atlas.gd`; `palette` exports the map editor's palette. The world map's colours follow the pack.
  The pack's map-editor files (`rme_files`) were added: nearly empty, but they name the creatures
  (the pack's names show some of ours misfit their art) and confirm the border order. The pack has no
  palms or cacti (dry trees stand in) and no water borders. make_sprites.py keeps only the marker,
  coins, spell effects, menu icons, and title painting (phase 6).
  After review the rock got its north and west rim and its top drawn with the floor, and the map's
  rock moved to where it belongs (`mountains.gd`): small clumps cleared, massifs around every cave
  mouth and hole, and mountains along the map's north and west edges (470 ore veins, from 422).
