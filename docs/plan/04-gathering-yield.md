# 04 - Gathering yields 1-5, fewer nodes

**Effort:** S

## Request
A gathering node should give 1-5 items, and nodes should be about 10% rarer.

## Today
`_finish_gather()` in `game/core/crafting.gd` always gives one item, then the node regrows for
`Professions.REGROW_SECONDS` (60 s). Nodes are cells whose terrain is a source
(`Crafting.node_at`); herb patches come from `HERBS`.

## Steps
1. `Professions.gather_count(skill, band) -> int`: 1-5, weighted toward 1-2, shifted up when the
   skill is well above the band. Use the host rng so tests are deterministic.
2. `_finish_gather`: give that many, stacked through `World.receiving_slot`. If only part fits,
   give what fits and say so. Message: "You gather 3 iron ore." Skill gain stays per gather.
3. 10% fewer nodes, picked by a deterministic cell hash so the same cells are always inactive:
   skip them in `node_at` (terrain nodes) and when placing herb patches.
4. Check recipe material costs against the ~2.5x average yield; raise material counts if crafting
   becomes too cheap. Note the change in `docs/balance.md`.

## Tests
Unit: counts are 1-5, the average at equal skill is about 2-2.5, a nearly full backpack gets a
partial stack, about 10% of candidate cells are not nodes.

## Done when
Gathering feels rewarding and fewer nodes are workable.
