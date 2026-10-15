# 05 - Tighter monster groups of 5-7

**Effort:** S

## Request
Outlaw archers and similar camps are 3-4 monsters spread over a wide area. Tasks need 25 kills,
so there is too much walking. Make groups of 5-7, closer together.

## Today
Overworld spawns are markers in `game/maps/overworld.tscn` (`game/maps/markers/monster_spawn.gd`:
monster, level, `count`, `radius`). `Combat.populate` fills each camp to `count` within `radius`.
Tier 1 raised the counts once.

## Steps
1. List every spawn with its count and radius (a small tool script), grouped by the tasks that
   need it (`Quests.TASKS`).
2. For task monsters: count 5-7, radius 2-3, and camps for the same task within a short walk of
   each other.
3. Careful at low levels: playtests showed low-level bots dying in starter packs. Keep level 1-5
   camps at 3-4, or make those monsters weaker.
4. Tune monster `respawn` so a 25-kill task takes about two or three camp clears.

## Tests
Soak test; the playthrough (a fresh character reaches level 10 without stalling); a unit test that
every task monster outside the starter area has a camp with count >= 5.

## Done when
A 25-kill task is done in two or three nearby camps.
