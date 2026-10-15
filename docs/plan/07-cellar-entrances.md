# 07 - One cellar hole per entrance

**Effort:** M  **References:** the `art-direction` skill's reference looks

## Request
Some cellar entrances look like two holes next to each other; there should be one. Better hole
art too, with OpenTibia as inspiration.

## Today
Dungeon stairways are terrain "v" cells (`game/data/dungeons.gd`); `World.ENTRANCE_OF` maps each
dungeon to its entrance. Some entrances are two "v" cells wide in `overworld.tscn`.

## Steps
1. Find every entrance with more than one "v" cell (a tool script over the map), reduce it to one,
   and turn the extra cell into floor.
2. Check that `Instances` entry and the bots' `Nav` still find the single cell.
3. New art with the `art-direction` skill: a dark opening with a stone or timber rim and steps
   going down, lit from the top-left, drawn in the floor layer. A trapdoor variant for town
   cellars, a rocky one for caves.
4. Unit test: every dungeon has exactly one entrance cell.

## Done when
Each entrance is one clearly readable hole, in the visual-cellar capture and in game.
