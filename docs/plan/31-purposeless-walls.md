# 31 - Walls that serve no purpose

**Effort:** S-M

## Request
Many building walls stand around the world with no purpose.

## Today
The landscape generator scatters "loose wall bits" (ruins) over the countryside, and towns keep
leftover wall stubs from older layouts (Reedmere's east quarter had one). Buildings are rooms
enclosed by walls and doors (`game/data/buildings.gd`); anything else made of `#` outside a
town wall or castle has no use.

## Steps
1. **Find them**: a tool that lists every `#` run that is not part of a building, a town wall, a
   castle, or a dungeon, with its length and place, and a world-map overlay to review.
2. **Decide per kind**: remove short stubs and lone segments; keep only deliberate ruins, made
   to read as ruins (broken, low, mossy; a "ruin" art variant) at a few landmarks.
3. **Clear them** with an idempotent painter, and stop the generator from making new ones.

## Tests
Unit: no wall run outside buildings, town walls, castles, dungeons, and listed ruins.

## Done when
Every wall in the world belongs to something.
