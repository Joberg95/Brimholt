# 13 - Bigger cellars and caves

**Effort:** L  **Needs from you:** Tibia cellar reference images

## Request
More monsters in cellars and caves. Caves get the rock textures and become about twice as large.
Cellars get a proper cellar theme (references to come).

## Today
Dungeons are text layouts in `game/data/dungeons.gd` (`ORDER`: cinder_cellar, ashford_crypt,
highmoor_mine, silkhollow), each with a floor and wall character, monsters as letters, and
instanced copies (`game/core/instances.gd`).

## Steps
1. **Caves (highmoor_mine, silkhollow).** Redraw the layouts at about twice the area: winding
   passages, a few chambers, dead ends with loot, the boss chamber at the far end. Walls drawn
   with the mountain rock (`mountain` + `_rock_field`, seamless across tiles) instead of `#`
   blocks. Floors: rough cave ground with gravel variants.
2. **Cellars (cinder_cellar, ashford_crypt).** After the references: brick or stone walls with
   wooden beams, barrels, crates, shelves, cobwebs, a few torches; flagstone floor. New props via
   the `art-direction` skill.
3. **More monsters.** About 1.5-2x the monsters, in small packs per chamber. Recheck the dungeon
   level range and the boss task.
4. Copies: the instance area grows; check that copies still fit to the right of the overworld and
   that `World.dungeon_at` maps them.
5. Bots and `Nav`: dungeons are walked with the same rules; check companions follow in.

## Tests
Unit: every dungeon is connected (all floor reachable from the arrival), has one boss, monster
counts within the target. Visual-test captures of one cave and one cellar.

## Done when
Caves look like caves in the rock style and take longer to clear; cellars look like cellars.
