# 08 - Performance pass

**Effort:** M

## Request
The game feels a little choppy and laggy.

## Today
`_process` in `game/main.gd` runs the host simulation every frame (`combat.tick`, `bots.tick`,
`solo.tick`, `instances.tick`, `crafting.tick`, `decay_ground`) and redraws `world_view`. Floors,
water and roofs are cached; walls, trees and actors are depth-sorted and drawn by `world_view.gd`.

## Steps
1. Measure before changing anything, in busy scenes (solo raid, a town, a PvP zone): Godot's
   profiler and `Performance` monitors, plus timing around each tick in a debug build. Note frame
   time, the slowest ticks, draw calls and spikes. Write the numbers in `docs/architecture.md`.
2. Suspects to check:
   - Bots thinking every frame instead of at `next_think` (behavior trees, `Nav` A* paths).
   - `world_view` redrawing every wall and tree in view each frame; cache static things in chunks
     like `floor_layer` and redraw only actors.
   - Size and rate of the state sent to clients.
   - Allocations in hot loops (new arrays and dictionaries, `filter`, string formatting).
   - Monster AI scanning every player and monster instead of using `cell_index`.
3. Fix the top two or three causes, measure again.
4. If ticks are the cost: run the simulation at a fixed rate (for example 20 Hz) separate from
   rendering, with movement interpolated.

## Tests
The soak test logs milliseconds per tick and fails above a budget, so regressions show.

## Done when
A steady 60 fps in a full solo raid on this machine, with before and after numbers in the docs.
