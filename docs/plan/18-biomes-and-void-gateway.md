# 18 - Biomes and the void gateway

**Effort:** XL

## Request
- A biome-based world: mountain ranges, swamp, woodlands, desert, and the void zone as the
  endgame area.
- The palace in the bottom right stays, but becomes a gateway to the boss room.
- The boss room is open to everyone, so PvP matters during the boss fight: a group or raid can
  wipe the team fighting the boss, take over, and steal the kill.

## Today
- `game/data/biomes.gd` has one climate region, the Dunmere desert (sand, cacti, no rain),
  painted by `tools/generators/desert.gd`.
- `game/data/regions.gd` names overworld regions with derived levels.
- Final bosses (`Monsters`, rank "boss", level 50, twenty-player raid) and `void_wraith` exist.

## Steps
1. **Biome map.** Generalise `Biomes` from one ellipse to a biome grid: each cell belongs to one
   biome (woodland, mountains, swamp, desert, void), with noisy borders. Draw the layout as a
   picture in this plan before painting, with level bands per biome (woodland 1-20, mountains
   20-35, swamp 35-50, desert where it is, void 50).
2. **Painters.** One painter per biome in `tools/generators/` like `desert.gd`: ground, trees or
   scrub, rocks, water, and decorations per biome; weather per biome (`weather.gd`: rain in the
   swamp, snow in the mountains, none in the desert, strange light in the void).
3. **Move content.** Re-home monster camps, tasks and towns to fit their biome and level band;
   update `Regions` names and descriptions.
4. **Void gateway.** The palace holds a gateway (a portal tile) to a boss arena outside the
   overworld, like dungeon copies but one shared arena, not instanced. Everyone can enter.
5. **Boss contest.** Boss damage credit goes to the party or raid that dealt the most damage
   (or the last one standing at the kill). If a raid wipes, the boss leashes and resets slowly
   (not instantly), so a waiting raid can take over. The arena is a PvP zone with skull rules.
6. **Bots.** Rival raids can contest the boss in solo mode (from `Solo`), at a low rate so it
   is an event, not a constant.

## Tests
Unit: biome lookup covers every cell; each biome's level band has tasks and camps; the gateway
leads to the arena and back; kill credit goes to the right raid; boss reset after a wipe.

## Done when
The world reads as distinct biomes, and the final boss is fought in an open, contestable arena.
