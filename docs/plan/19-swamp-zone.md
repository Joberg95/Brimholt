# 19 - Swamp zone, levels 35-50

**Effort:** L (part of plan 18)

## Request
Expand the map with a swamp for levels 35 to 50: new hunt monsters, giant swamp mushrooms instead
of trees, and wooden walkways.

## Today
Swamp monsters exist at lower levels (bog lurker, mire stalker, reedfang, bog hulk, Blackreed
warden). There is no high-level swamp area.

## Steps
1. Area: a new region added to the map (extend the map if there is no room), placed in the
   biome layout of plan 18, between the mountains and the void.
2. Art with the `art-direction` skill: murky water and mud ground, giant mushroom "trees" (two
   tiles tall, like the trees), reeds, hanging moss, wooden walkways on posts over the water
   (walkable tiles drawn above water), a small stilt village as a hub.
3. Monsters, levels 35-50, three to four kinds plus an elite: for example a mire troll, a bog
   witch (magic caster), giant leeches, a swamp hydra elite. Loot tables with materials, level
   gear and runes (plan 11).
4. Tasks for each monster at the hub, with rewards from `Quests.reward()`, and a hub task chain.
5. Weather: frequent rain and fog.

## Tests
Unit: swamp tasks reachable over the walkways, monster levels in 35-50, loot tables valid. Soak
and a visual-test capture.

## Done when
Level 35-50 players have a swamp with its own hub, monsters and tasks.
