# 34 - Monsters 20% tougher

**Effort:** S

## Request
Increase overall monster health by 20%: in a party, monsters die too fast.

## Today
`Balance.mob_health(level, rank)` scales a level-1 base along the curve and multiplies by the
rank. Bosses are tuned separately against the twenty-player raid (`boss_ratio`).

## Steps
1. `Balance.MOB_HEALTH_SCALE = 1.2` on every rank but bosses (the raid tuning stays).
2. Re-run the fight simulator and the balance table; update `docs/balance.md`.

## Tests
Unit: monster health is 1.2x the curve; the balance checks still hold (kills to level, six-hit
rules). Fight simulator: solo kills stay winnable at even level.

## Done when
Every monster but the final bosses has a fifth more health.
