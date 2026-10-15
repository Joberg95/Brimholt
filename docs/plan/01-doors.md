# 01 - Tibia-style doors and house walls

**Effort:** S (finishing)  **Needs from you:** a look in game

## Request
Doors looked too small, and the porch door stuck up over the roof. Tibia houses are the model:
walls a full tile tall, doors set into the wall face.

## Today (uncommitted)
- `tools/generators/make_sprites.py`: `thin_wall(..., height=HOUSE_RAISE)` and `house_door()`,
  sheet `assets/sprites/house_walls.png` (16 wall masks + 2 doors, 64x64 frames). `doors.png` removed.
- `game/render/sprite_art.gd`: `wall_sheet`, `wall_raise`, `draw_door`; sign and torch offsets moved up.
- `game/render/world_view.gd`: porch deferral removed; doors draw in the depth pass like walls.
- `game/render/roof_art.gd`: `RAISE = 32`, roofs lifted 16 px.
- Lint passes.

## Steps
1. Remove the leftover `DOOR_LEAF_DEPTH` constant from `make_sprites.py` if it is unused.
2. Run the visual test and look at `.tools/visual-roofs.png`, `visual-shop-inside.png`,
   `visual-torches.png` and `visual-cellar.png`.
3. Check, in order: the roof eaves sit on the wall tops, the door is a character's height, signs
   and torches sit on the wall face, the cinder cellar's `#` walls are not too tall for a dungeon
   (if they are, keep the old 16 px raise for dungeon walls in `wall_raise`).
4. One fix pass, one more look.
5. Unit and soak tests, then commit.

## Done when
Houses read like Tibia houses in the captures and in game, all tests pass, committed.
