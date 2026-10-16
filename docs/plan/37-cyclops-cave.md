# 37 - The Cyclops Hollow: a 75-kill hunt

**Effort:** M

## Request
More hunt quests, for example entering a cyclops cave and killing 75 cyclopes: a lot of
experience, potions, and a chance of a rare item.

## Today
Cyclopes hunt in the open on Smoulder Fells (29-31) and cyclops smiths on the Hollow March (36-38)
for the Hunters' Lodge. Shared caves (`game/data/caves.gd`) exist for the elites and the trench.

## Steps
1. **The cave**: the Cyclops Hollow, a shared cave (levels 30-36) of cyclopes and cyclops smiths
   in dense camps, its mouth in the Smoulder Fells.
2. **The hunt**: "The Hundred-Eyed Hollow" from a giver at the mouth's nearest town: slay 75
   cyclopes or smiths in the cave; pays experience and gold (half the kills', like other hunts),
   10 health and 10 mana potions, and a roll on a rare item: one of the Hollow's own level-35
   pieces (a cyclops-eye amulet, a forge-hammer, a hide war-cloak), one in four.
3. **Quest rolls**: tasks gain a `rare` list ([item, chance]) rolled on turn-in.

## Tests
Unit: the cave is reachable and holds cyclopes at its levels; the task counts both kinds; the
reward pays potions and rolls the rare list; the rare items have art and are unbound.

## Done when
A level-30-36 player has a long cyclops hunt in a cave worth doing.
