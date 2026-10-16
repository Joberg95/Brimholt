# 36 - Epic and legendary gear only from bosses and quests

**Effort:** S-M

## Request
Restrict epic items to bosses and endgame quests, and the same for legendary items.

## Today
Equipment grades purely by level: level 30-39 gear is Epic and 40-49 Legendary, whatever drops it,
so every ordinary monster from level 30 drops Epic gear (`Items.quality`, `Combat.gear_drop`).

## Steps
1. **Grade by source**: tier gear from vendors and ordinary monster drops tops out at **Rare**.
   **Epic** (level 30-39) and **Legendary** (40-49) mark gear that only champions and bosses drop
   (their own loot) and quest reward gear. Relics and mythic sets keep their own grades.
2. The tooltip says where Epic and Legendary gear comes from.

## Tests
Unit: generic tier gear never grades above Rare; champion-only and quest gear grade Epic and
Legendary by level; relics and mythics unchanged.

## Done when
An Epic or Legendary item means a boss or a quest.
