# 27 - Elite caves, levels 30-45

**Effort:** L

## Request
A level-33 player runs out of tasks. Add about fifteen hunting tasks for levels 30-45, as new
caves of elites: a farming area for 35+ in a large cave of elite ogres, with more experience but
harder monsters.

## Today
Levels 30-45 have about a dozen tasks, several of them gated behind chains (the Hunters' Lodge).
Dungeons (`game/data/dungeons.gd`) are instanced and reset; nothing is a shared, respawning cave.
The "elite" rank (Balance: 4x health, 1.5x damage, 5x experience) is used by one monster.

## Steps
1. **Caves.** `game/data/caves.gd`: shared underground hunting caves painted beyond the Void
   Throne (outside the overworld, like the arena), each with a cave mouth on the overworld. Step
   on the mouth to go down; step on the stairs up to come back beside it. Underground zones
   (dim ambient, monsters stay inside), not instanced: everyone hunts the same cave.
2. **Painter.** `tools/generators/caves.gd` (`make caves`): carves each cave from noise (wide
   halls joined by tunnels, rock walls), places camps of elites and the mouths. Idempotent.
3. **Monsters.** Four caves, levels 30-45, three or four elite kinds each plus one champion:
   - Ogre Warrens (32-37): ogre brute, ogre shaman (magic), ogre smasher; champion Gorvak.
   - Drowned Grotto under Mirewood Fen (35-40): bog troll, grotto leech, drowned priest (magic).
   - Ember Deep (38-43): magma hound, cinder brute, ember witch (magic).
   - Frostvault (41-45): frost ogre, rime stalker, glacial golem; champion the Hoarfrost Jarl.
   Loot materials, rune shards and potions; creature art for non-humanoids.
4. **Tasks.** About fifteen, from a giver in the town nearest each cave, rewarded from
   `Quests.reward()`; no chains, so a level-33 player always has work.

## Tests
Unit: every cave is reachable from its mouth and back; caves are underground zones outside the
overworld; levels 30-45 have at least fifteen tasks; every new monster has art, loot and a task.

## Done when
A level-30-45 player has a choice of elite caves with tasks, and they are worth farming.
