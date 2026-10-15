# 12 - World map: arrow, quest guidance, new look

**Effort:** M

## Request
Map indication of where to go for quests; better world map graphics and art style; make your own
position easier to see, for example a small arrow.

## Today
`game/ui/world_maps.gd` draws the minimap and world map from one terrain texture, with labels
(towns, dungeons) and markers: gold for you, cyan for ferrymen, green towns, orange dungeons,
red PvP, and "!" for quest givers (`_draw_quest_marks`).

## Steps
1. **You.** Replace the gold dot with a small arrow pointing the way you face, with a dark
   outline and a gentle pulse, on both the minimap and the world map.
2. **Quest guidance.** For each active task, mark where to go: the camp area of its monster
   (`World.MONSTER_SPAWNS` for the task's monster, as a soft circle), or the giver when the task
   is ready to turn in. The tracked task (first in the quest list, or one you click) also gets an
   edge-of-minimap arrow when its target is off screen.
3. **New look.** Draw the terrain texture as a painted map: muted parchment tint, darker coasts,
   hatched mountains, small tree marks for forests, town icons instead of plain squares, region
   names in a serif font. Keep it readable at every zoom level.
4. Legend line updated, and the same markers in the minimap.

## Tests
Visual test captures of the minimap and world map with an active task; unit test that every task
monster resolves to at least one map area.

## Done when
You can open the map and see where you are, which way you face, and where your tasks are.
