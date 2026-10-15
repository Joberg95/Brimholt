# 10 - Armor types, new stats, class counters

**Effort:** L

## Request
- New item stats: **healing power**, **critical chance**, **magic defense**. Damage stays as it is.
- Warriors in plate take less melee damage from armor; spells hit them in full, so Sorcerers
  counter Warriors.
- Warriors are strong against Druids and Hunters, who wear lighter armor.
- Rebalance spells to fit: for example a Druid root and a Hunter slowing arrow.

## Today
- `Balance.VOCATIONS` (`game/data/balance.gd`): health, mana, damage, healing, flat `defense`
  (Warrior 20, Hunter 5, others 0). `BASE_CRITICAL` exists as a constant.
- `Balance.ARMOR_OF`: Warrior plate, Hunter mail, Druid leather, Sorcerer cloth.
- Item stats come from `game/data/items.gd` (`defense`, `regen`, `mana`, `healing` on charms).
- `Combat._hit` uses `Balance.damage_taken(raw, defense_of(target))` for every hit, melee or
  spell alike.

## Steps
1. **Damage styles.** Every hit carries a style: "melee" (weapon and melee spells), "ranged"
   (arrows) or "magic" (spells and runes). `_hit` already has `_damage(..., style)`; make the
   style reach the mitigation step.
2. **Two defenses.** `armor` (from helmet, armor, legs, boots, shield; scales with armor type:
   plate > mail > leather > cloth) reduces melee and ranged. `magic_defense` (from capes,
   amulets, books, a few relics) reduces magic. Replace the single `defense` stat in
   `items.gd` and `World.player_stats` with both; keep the vocation flat defense as armor.
3. **New stats on items.** `healing` (healing power, already on charms) spread to druid gear and
   rings; `critical` (percent, added to `BASE_CRITICAL`) on hunter and sorcerer gear and weapons.
   Generated from level and slot in `items.gd` like today's stats, shown in the item tooltip and
   the character window.
4. **Counters.** Tune armor and magic defense so, at equal level and gear:
   Warrior vs Sorcerer: the Sorcerer wins most fights. Warrior vs Druid or Hunter: the Warrior
   wins most. Sorcerer vs Hunter: about even. Write a headless duel simulator (two bots, N fights)
   and put the win rates in `docs/balance.md`.
5. **Control spells.** Druid **Root** (target cannot move for 3 s, can still act; diminishing
   returns in PvP) and Hunter **Crippling arrow** (target moves 50% slower for 4 s). Movement in
   `World` gets a `rooted_until` and `slowed_until` check.
6. **PvE stays balanced.** The final boss check (`reference_dps`, twenty-player raid) must still
   pass: monster damage types decide how much armor matters (most monsters melee, casters magic).
7. Bots: `Bots.gear` picks the new stats; companions use Root and Crippling arrow on PvP targets.
8. Character saves: old saves get the new stats derived from their items (items are derived from
   the catalog, so only the stat sheet changes); bump the catalog signature.

## Tests
Unit: armor reduces melee but not magic; magic defense the reverse; crit chance from gear; Root
and slow durations; duel simulator win rates within the target bands; the balance curves test
still passes.

## Done when
Class matchups follow the counters above in the duel simulator and in a PvP playtest, and the
new stats show on items and in the character window.
