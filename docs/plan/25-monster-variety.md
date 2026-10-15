# 25 - More monster variety for hunting tasks

**Effort:** L (with plan 24)

## Request
Expand the world with more monster variety for the hunting tasks.

## Today
About 25 hunted monster kinds (`game/data/monsters.gd`), drawn from a handful of body looks
(quadruped, spider, blob, golem, wraith, humanoid) and colours (`creatures/`, `monsters/`
sheets from `make_sprites.py`). Several bands rely on one kind each.

## Steps
1. Eight to ten new monsters, mostly levels 20-35 (feeding plan 24) and a few for 35-50: for
   example a dire bear, harpies, lizardmen (spear and shaman), a stone troll, giant scorpions in
   the desert, cave trolls, wraith knights, and a marsh witch. Each gets a role: melee, ranged,
   or caster (magic, Monsters.MAGIC_ATTACKERS), and its own material drop.
2. Looks: reuse the body builders with new silhouettes where cheap (a scorpion from the spider
   builder, a bear from the quadruped one), and add one or two new builders (harpy, lizardman)
   following the `art-direction` skill. Check each against a character in a capture.
3. Camps in the region that suits their level (`tools/generators/hunts.gd`), 5-7 per camp.
4. Loot rows and lexicon entries; materials have a vendor value.
5. Rival bands and the playthrough use them without changes.

## Tests
Unit: every new monster has a loot table, a camp, a lexicon entry, a sprite, and a level band
that a task uses. Visual capture of each new look next to a character.

## Done when
Levels 20-50 have several different monsters to hunt in each band.
