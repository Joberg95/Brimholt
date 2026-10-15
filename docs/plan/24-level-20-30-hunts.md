# 24 - More hunting tasks for levels 20-30

**Effort:** M-L (with plan 25)

## Request
More hunt quests for levels 20-30: a party of level 25 ended up doing the 40+ tasks. About
5-10 more stages.

## Today
Hunting tasks by level band (`Quests.TASKS`, `World.task_levels`):
- 19-25: crypt_rest, lodge_frostfang, outlaw_bounty
- 24-28: golem_breakers, lodge_greymaw (one champion)
- 29-32: lodge_cyclops, wraith_quench

That is about seven tasks for levels 20-30, while the climb takes about 745 same-level kills
(`Balance.kills_to_level`), some thirty tasks' worth. Players run out and jump ahead.

## Steps
1. Six to eight new tasks spread over 20-30 (two or three per band of three levels), each at a
   camp of its own monster: the new monsters of plan 25 where they fit, else existing ones in
   new places. Count 25-30, `share` like their neighbours, rewards from `Quests.reward`.
2. Givers: a new hub task giver in a 20-30 region town (Stonevale or Golemback Hills), plus
   new stages on existing chains (Captain Ardo, Quartermaster Rhosyn, the Lodge) so each giver
   offers a next step.
3. Camps placed by `tools/generators/hunts.gd` rows (5-7 per camp, plan 05), in the region of
   their level.
4. Bots (rival bands) pick the new tasks up automatically (`Bots._choose_errand`).
5. Docs: the task table in `docs/gameplay.md`; `docs/balance.md` note on task coverage.

## Tests
Unit: every level from 20 to 30 has at least three open tasks; each new task has camps in its
band (`World.task_targets`), a giver, and a reward. Playthrough unchanged.

## Done when
A party levelling 20-30 always has two or three tasks of its level to choose from.
