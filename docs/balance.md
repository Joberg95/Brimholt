# Brimholt balance sheet

Curves for levels 1-50 and four vocations, used by combat (`game/core/combat.gd`), monsters
(`game/data/monsters.gd`), spells (`game/data/spells.gd`), and items. `game/data/balance.gd` is the one source.
Regenerate the tables after changing a constant:

```sh
godot --headless --path . --script res://tools/generators/balance_table.gd
```

## The final boss

| Anchor | Value |
| --- | --- |
| Final boss health | **350,000** |
| Smallest intended raid | **10 level-50 players**: 2 Knights, 3 Paladins, 3 Sorcerers, 2 Druids |
| Intended fight | 240 s; the boss **enrages and wipes the raid at 255 s** |
| Healing pressure | raid-wide damage needing 2.2 Druids' worth of healing per second |
| Tank swaps | boss hits stack a wound, so at least **2 Knights** must alternate |

Each requirement removes a different shortcut: the enrage timer requires damage, the
healing pressure requires healers, and the wound stacks require two tanks. With only about
6% slack on the timer, removing **any one player** from the intended raid loses, and the
rules test checks every group of nine or fewer players exhaustively: none can win. Larger
or differently mixed groups can (see below).

## Vocations

The four vocations follow the classic tank / ranged / burst caster / healer split. They
multiply the reference (Paladin) curves:

| Vocation | Health | Mana | Damage | Healing | Base defense |
| --- | ---: | ---: | ---: | ---: | ---: |
| Knight | ×1.5 | ×0.5 | ×0.6 | 0 | 20 |
| Paladin | ×1.0 | ×1.0 | ×1.0 | ×0.1 | 5 |
| Sorcerer | ×0.6 | ×1.6 | ×1.3 | 0 | 0 |
| Druid | ×0.6 | ×1.6 | ×0.4 | ×1.0 | 0 |

| Vocation | Role | HP 1 / 50 | Mana 1 / 50 | Attack 1 / 50 | Healing/s 1 / 50 | Base def |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Knight | Tank | 225 / 14,747 | 30 / 1,966 | 2 / 147 | 0 / 0 | 20 |
| Paladin | Ranged damage, light healing | 150 / 9,831 | 60 / 3,933 | 4 / 246 | 1 / 39 | 5 |
| Sorcerer | Burst damage | 90 / 5,899 | 96 / 6,292 | 5 / 320 | 0 / 0 | 0 |
| Druid | Healer | 90 / 5,899 | 96 / 6,292 | 2 / 98 | 6 / 393 | 0 |

## Raid checks

| Level-50 group | Players | Boss down in | Healing (need 2.2) | Tanks | Result |
| --- | ---: | ---: | ---: | ---: | --- |
| 2 Knight, 3 Paladin, 3 Sorcerer, 2 Druid | 10 | 240 s | 2.3 | 2 | wins |
| 1 Knight, 3 Paladin, 3 Sorcerer, 2 Druid | 9 | 257 s | 2.3 | 1 | loses: not enough damage before the 255 s enrage, needs 2 tanks to swap |
| 2 Knight, 2 Paladin, 3 Sorcerer, 2 Druid | 9 | 270 s | 2.2 | 2 | loses: not enough damage before the 255 s enrage |
| 2 Knight, 3 Paladin, 2 Sorcerer, 2 Druid | 9 | 281 s | 2.3 | 2 | loses: not enough damage before the 255 s enrage |
| 2 Knight, 3 Paladin, 3 Sorcerer, 1 Druid | 9 | 251 s | 1.3 | 2 | loses: not enough healing |
| 2 Knight, 2 Paladin, 4 Sorcerer, 2 Druid | 10 | 232 s | 2.2 | 2 | wins |
| 2 Knight, 4 Paladin, 4 Sorcerer, 2 Druid | 12 | 191 s | 2.4 | 2 | wins |
| 1 Knight, 1 Paladin, 1 Sorcerer, 1 Druid | 4 | 647 s | 1.1 | 1 | loses: not enough damage before the 255 s enrage, not enough healing, needs 2 tanks to swap |

## Derivation

Players and monsters attack every **2 seconds**, as in Tibia. The intended raid deals 8.9
reference players' worth of damage (2×0.6 + 3×1.0 + 3×1.3 + 2×0.4). Killing 350,000 health
in 240 s means one geared Paladin-equivalent deals about **164 damage per second** at
level 50, or **328 per hit**. Six such hits kill a level-50 normal mob, so it has **1,966**
health and the boss equals 178 normal mobs. A single growth factor (**×1.089 per level**)
connects level 1 (30-health mobs, 150-health Paladins) to level 50 and scales mob health,
mob damage, player health, mana, attack, and healing together, so hit counts stay
constant at every level.

| Rank | Health | Damage | Experience |
| --- | --- | --- | --- |
| Normal | ×1 | ×1 | ×1 |
| Elite | ×4 | ×1.5 | ×5 |
| Boss | ×178 | ×2.5 | ×100 |

- **Health / Mana** – maximums. **Attack** – damage per hit; gear should supply the gap
  between the base and geared columns (`Balance.gear_attack_budget(level)`). Hits vary
  ±15%; critical hits (base 5% chance) deal ×1.5.
- **Defense** – damage taken is `raw × 100 / (100 + defense)`: 100 defense halves it.
- **Regen** – health per 10 s; base 4% of max health. Mana regenerates 8% of max per 10 s.
  Both triple when you have been out of combat for 8 s.
- **Healing** – health per second a vocation can restore to others.
- **Spells** – damage is attack × spell power; mana costs are a share of max mana.

Leveling needs `4 + 3 × (level − 1)` same-level normal kills per level, so level 2 takes
about 4 kills and the whole climb to 50 about 3,700. Experience from a kill is shared by damage dealt; a sharing party pools it and splits it evenly with a ×1.2–×2 vocation bonus ([gameplay](gameplay.md#parties-and-shared-experience)). Dying costs 10% of total
experience, which can lose levels; below level 8, players keep their items and gold.

## Early game

Monsters hit softer early: half damage at level 1, rising to full damage at level 11, so a
new player survives 15–30 same-level hits instead of 15. Twelve spawns of level 1–4 voles
and toads ring Cinder Crossing within 45 tiles; beyond that, levels rise by about one per
8.5 tiles. Spawns stay at least 7 steps from roads and sit in small clearings.

## Level table (reference vocation: Paladin)

| Level | Player HP | Base atk | Geared atk | Mob HP | Elite HP | Boss HP | Mob hit | Elite hit | Boss hit | Mob XP | XP to next |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 150 | 4 | 5 | 30 | 120 | 5,340 | 5 | 8 | 13 | 15 | 60 |
| 2 | 163 | 4 | 5 | 33 | 131 | 5,816 | 6 | 9 | 15 | 16 | 112 |
| 3 | 178 | 4 | 6 | 36 | 142 | 6,334 | 7 | 11 | 18 | 18 | 180 |
| 4 | 194 | 5 | 6 | 39 | 155 | 6,899 | 8 | 13 | 21 | 19 | 247 |
| 5 | 211 | 5 | 7 | 42 | 169 | 7,513 | 10 | 15 | 25 | 21 | 336 |
| 6 | 230 | 6 | 8 | 46 | 184 | 8,183 | 11 | 17 | 29 | 23 | 437 |
| 7 | 250 | 6 | 8 | 50 | 200 | 8,912 | 13 | 20 | 33 | 25 | 550 |
| 8 | 273 | 7 | 9 | 55 | 218 | 9,706 | 15 | 23 | 39 | 27 | 675 |
| 9 | 297 | 7 | 10 | 59 | 238 | 10,571 | 18 | 27 | 45 | 30 | 840 |
| 10 | 323 | 8 | 11 | 65 | 259 | 11,513 | 20 | 31 | 51 | 32 | 992 |
| 11 | 352 | 9 | 12 | 70 | 282 | 12,539 | 23 | 35 | 59 | 35 | 1,190 |
| 12 | 384 | 10 | 13 | 77 | 307 | 13,656 | 26 | 38 | 64 | 38 | 1,406 |
| 13 | 418 | 10 | 14 | 84 | 334 | 14,873 | 28 | 42 | 70 | 42 | 1,680 |
| 14 | 455 | 11 | 15 | 91 | 364 | 16,199 | 30 | 46 | 76 | 46 | 1,978 |
| 15 | 496 | 12 | 17 | 99 | 396 | 17,642 | 33 | 50 | 83 | 50 | 2,300 |
| 16 | 540 | 13 | 18 | 108 | 432 | 19,214 | 36 | 54 | 90 | 54 | 2,646 |
| 17 | 588 | 15 | 20 | 118 | 470 | 20,926 | 39 | 59 | 98 | 59 | 3,068 |
| 18 | 640 | 16 | 21 | 128 | 512 | 22,791 | 43 | 64 | 107 | 64 | 3,520 |
| 19 | 697 | 17 | 23 | 139 | 558 | 24,822 | 46 | 70 | 116 | 70 | 4,060 |
| 20 | 759 | 19 | 25 | 152 | 608 | 27,034 | 51 | 76 | 127 | 76 | 4,636 |
| 21 | 827 | 21 | 28 | 165 | 662 | 29,443 | 55 | 83 | 138 | 83 | 5,312 |
| 22 | 901 | 23 | 30 | 180 | 721 | 32,067 | 60 | 90 | 150 | 90 | 6,030 |
| 23 | 981 | 25 | 33 | 196 | 785 | 34,924 | 65 | 98 | 164 | 98 | 6,860 |
| 24 | 1,068 | 27 | 36 | 214 | 855 | 38,036 | 71 | 107 | 178 | 107 | 7,811 |
| 25 | 1,164 | 29 | 39 | 233 | 931 | 41,426 | 78 | 116 | 194 | 116 | 8,816 |
| 26 | 1,267 | 32 | 42 | 253 | 1,014 | 45,117 | 84 | 127 | 211 | 127 | 10,033 |
| 27 | 1,380 | 35 | 46 | 276 | 1,104 | 49,137 | 92 | 138 | 230 | 138 | 11,316 |
| 28 | 1,503 | 38 | 50 | 301 | 1,203 | 53,516 | 100 | 150 | 251 | 150 | 12,750 |
| 29 | 1,637 | 41 | 55 | 327 | 1,310 | 58,285 | 109 | 164 | 273 | 164 | 14,432 |
| 30 | 1,783 | 45 | 59 | 357 | 1,426 | 63,479 | 119 | 178 | 297 | 178 | 16,198 |
| 31 | 1,942 | 49 | 65 | 388 | 1,554 | 69,135 | 129 | 194 | 324 | 194 | 18,236 |
| 32 | 2,115 | 53 | 71 | 423 | 1,692 | 75,296 | 141 | 212 | 353 | 212 | 20,564 |
| 33 | 2,304 | 58 | 77 | 461 | 1,843 | 82,006 | 154 | 230 | 384 | 230 | 23,000 |
| 34 | 2,509 | 63 | 84 | 502 | 2,007 | 89,313 | 167 | 251 | 418 | 251 | 25,853 |
| 35 | 2,732 | 68 | 91 | 546 | 2,186 | 97,272 | 182 | 273 | 455 | 273 | 28,938 |
| 36 | 2,976 | 74 | 99 | 595 | 2,381 | 105,940 | 198 | 298 | 496 | 298 | 32,482 |
| 37 | 3,241 | 81 | 108 | 648 | 2,593 | 115,380 | 216 | 324 | 540 | 324 | 36,288 |
| 38 | 3,530 | 88 | 118 | 706 | 2,824 | 125,662 | 235 | 353 | 588 | 353 | 40,595 |
| 39 | 3,844 | 96 | 128 | 769 | 3,076 | 136,860 | 256 | 384 | 641 | 384 | 45,312 |
| 40 | 4,187 | 105 | 140 | 837 | 3,350 | 149,056 | 279 | 419 | 698 | 419 | 50,699 |
| 41 | 4,560 | 114 | 152 | 912 | 3,648 | 162,338 | 304 | 456 | 760 | 456 | 56,544 |
| 42 | 4,966 | 124 | 166 | 993 | 3,973 | 176,804 | 331 | 497 | 828 | 497 | 63,119 |
| 43 | 5,409 | 135 | 180 | 1,082 | 4,327 | 192,559 | 361 | 541 | 901 | 541 | 70,330 |
| 44 | 5,891 | 147 | 196 | 1,178 | 4,713 | 209,718 | 393 | 589 | 982 | 589 | 78,337 |
| 45 | 6,416 | 160 | 214 | 1,283 | 5,133 | 228,406 | 428 | 642 | 1,069 | 642 | 87,312 |
| 46 | 6,988 | 175 | 233 | 1,398 | 5,590 | 248,760 | 466 | 699 | 1,165 | 699 | 97,161 |
| 47 | 7,610 | 190 | 254 | 1,522 | 6,088 | 270,927 | 507 | 761 | 1,268 | 761 | 108,062 |
| 48 | 8,288 | 207 | 276 | 1,658 | 6,631 | 295,069 | 553 | 829 | 1,381 | 829 | 120,205 |
| 49 | 9,027 | 226 | 301 | 1,805 | 7,222 | 321,363 | 602 | 903 | 1,505 | 903 | 133,644 |
| 50 | 9,831 | 246 | 328 | 1,966 | 7,865 | 350,000 | 655 | 983 | 1,639 | 983 | max |

Growth per level: 1.0891. Boss = 178 normal mobs. Reference DPS at level 50: 163.9. Normal kills from 1 to 50: 3,724.
