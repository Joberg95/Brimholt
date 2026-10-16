# 35 - More monsters in empty spots, slower respawns

**Effort:** M

## Request
Add more monsters in the empty spots of the map, and lower the spawn rate to balance it out.

## Today
441 camps; regions have open stretches with no camp. Monsters respawn 45 s after a kill
(`Monsters.RESPAWN_SECONDS`), champions after 10 minutes.

## Steps
1. **Find the gaps**: a tool (`tools/generators/fill_gaps.gd`) that finds open, walkable country
   (not towns, zones, roads, or water) more than a camp gap from every camp, and fills it with
   camps of a monster that already lives in that region at that region's levels (so a gap in
   Greywood gets Greywood's wolves and bandits).
2. **Respawn slower**: 45 s becomes 75 s, so the world holds more monsters without a camp
   refilling under a party's feet.
3. Hunting tasks and the lexicon pick the new camps up from the markers.

## Tests
Unit: no large open stretch without a camp in any region; new camps match their region's levels;
respawn delay; camps still fill. Soak and the bench.

## Done when
The countryside is populated without empty stretches, and camps refill at a calmer pace.
