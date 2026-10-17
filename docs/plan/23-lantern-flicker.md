# 23 - Lanterns flicker when you go near them

**Effort:** S

## Request
The lanterns flicker when you go near them; fix it.

## Today
`game/render/lighting.gd` rebuilds the lights every frame from a pool of at most `MAX_LIGHTS` (64)
`PointLight2D`s, in a fixed order: held torches, NPC lanterns, town lamps (`World.LAMPS`, from
`LAMP_DARKNESS` on), waystones, relic and boss glows, glowing ground items. Lights are only made for
things inside `view.visible_cells().grow(4)`. A held torch already flickers on purpose
(`0.92 + 0.08 * sin(...)`); lamps and NPC lanterns are steady.

Likely causes, in order:
1. **Per-item light limits.** The project renders with GL Compatibility, which limits how many
   2D lights reach one canvas item. Floor chunks are big canvas items, so near a lamp cluster plus
   your torch and glows, some lights drop for a whole chunk and pop back as you move.
2. **The pool's order.** When more than 64 lights want a slot, the ones added last (glows, ground
   items) lose theirs, and which those are changes frame to frame as things enter the area.
3. **The area edge.** A lamp entering `grow(4)` switches on at full strength in one frame.

## Steps
1. Reproduce: a night capture sequence walking past a lamp row in Cinder Crossing with and
   without a torch (`tools/testing/shot.gd` or a visual-test step), and log `_in_use` and the
   lights per chunk each frame.
2. Fix the cause found: raise the GL Compatibility 2D light limit in `project.godot` if that is
   it; give lights a stable priority (nearest to the player first, lamps above ground-item glows)
   so the same lights win every frame; fade a light in over a few frames when it enters the area
   instead of popping it on.
3. If chunk size is the cause, split the floor into smaller canvas items near lights.

## Tests
- A visual-test step: a night frame beside a lamp row, then the same after a one-tile step; the
  lamp's lit pixels may not drop by more than a few percent.
- Unit check: light priority puts lamps within N tiles of the player ahead of distant glows.

## Status (2026-10-17)
Not reproduced: walking past the lamp by the spawn and the busiest lamp cluster at midnight, with
and without a torch, gave smooth brightness and 9-14 of 64 lights. Godot hard-codes 16 lights per
canvas item in 2D (no project setting), so cause 1 stays possible near crowded spots. Fixed anyway:
lamps fade in through dusk (`lamp_strength`), darkness eases (`DARKNESS_RATE`), keyed lights fade
in over `FADE_IN_SECONDS` when they come into range, and lights are placed nearest the camera first
(`nearest`). Chunk splitting (step 3) not done. Unit checks and a visual walk-past step added.
Waiting on an in-game check before this plan is closed.

## Done when
Walking past lamps at night, with and without a torch, shows steady lamp light.
