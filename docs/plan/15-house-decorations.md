# 15 - House decorations

**Effort:** M-L  **References:** the `art-direction` skill's reference looks

## Request
Decorate houses the Tibia way (references to come).

## Today
Inside houses there are counters, a few props and wall torches (`sprite_art.gd`,
`make_sprites.py` objects sheet). Decorations are not a separate system.

## Steps
1. From the references, make a prop list: tables, chairs, beds, shelves with goods, barrels,
   crates, rugs, potted plants, wall hangings, fireplaces, windows in the house walls.
2. Art with the `art-direction` skill, in a `decor.png` sheet; wall-mounted props drawn on the
   house wall face (like torches), floor props in the depth pass.
3. Placement: a decoration marker in the map editor (`game/maps/markers/`) with a prop id, plus
   blocking or not. Walking rules: furniture blocks, rugs do not.
4. A themed set per building type: shop, tavern, smithy, home, temple; decorate every town
   building once.
5. Check performance (plan 08): props are static, so draw them into cached chunks.

## Tests
Unit: decoration markers load, blocking props block movement, no prop blocks a door or an NPC.
Visual-test capture of a decorated shop and home.

## Done when
Every town building is furnished in a style that matches the references.
