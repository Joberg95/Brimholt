# 03 - Less gold

**Effort:** S

## Request
At level 19 you had 22k gold. That is too much.

## Today
Gold comes from three sources:
- Kill piles, `Combat.roll_loot` (`game/core/combat.gd`): `level / 10` piles plus a 60% chance of
  one more, 25 gold each (`gold_coins`), and 3 extra piles for ranked monsters.
- Task rewards, `Quests.reward()` (`game/data/quests.gd`): a `share` of the kills' expected gold
  (`COIN_VALUE`).
- Selling loot and materials to vendors (item `value`, vendor prices in `game/data/items.gd`).

## Steps
1. Measure first: a headless script (or soak variant) that plays a hunter bot from level 1 to 20
   and logs gold by source. Put the numbers in `docs/balance.md`.
2. Pick a target based on what you need to spend: a vendor gear set for your level plus potions,
   per 10 levels (for example about 6-8k at level 19). Put the target in `Balance` as a constant
   the tests can check.
3. Cut the largest source first. Likely: remove the flat 60% pile, scale piles more gently with
   level, lower the task gold share. Leave vendor sell prices alone unless they dominate.
4. Bots follow the same rules, so `BotLoot` selling needs no change.

## Tests
Unit test that expected gold per kill and per task at levels 5, 19 and 40 is within the target
band. Soak stays green.

## Done when
A level-19 character has roughly the target gold, and `docs/balance.md` says where gold comes from.
