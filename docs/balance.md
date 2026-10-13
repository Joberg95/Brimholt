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

## Monster pace, leash, and fights you cannot dodge

Monsters chase at `Balance.chase_seconds(level)` per tile: 0.14 s at level 1 down to 0.11 s at
level 50, always quicker than a player's 0.18 s step. Nobody outruns or kites a monster; a
monster far above your level simply kills you. A monster gives up when its target enters a
town, is dragged more than 12 tiles (`Monsters.LEASH`) from its home, or gets more than 12
tiles away; it heals to full at once and walks home at its own pace, untouchable and ignoring
players until it arrives. So a fight must be won where it starts, with armor, spells, and
potions. A same-level normal monster hits for 1/18 of a geared player's base health every
2 seconds (`HITS_TO_FALL`).

`make fight-sim MONSTER=<id> LEVELS=... COUNT=...` runs the real combat rules for each
vocation in its tier's vendor gear, auto-attacking only and with spells and potions. Normal
monsters at the player's level currently give:

| Fight | Auto-attacks only | Spells and potions |
| --- | --- | --- |
| One monster | 3–27% health lost; nobody dies | 3–27% lost, 0–3 potions |
| A camp of three | Knights end at 5–60% health; Paladins die from level 10, Sorcerers and Druids always | Everyone wins, ending at 43–82% health, 0–8 potions (Druids about 5–6, mostly mana) |
| Level 1 against a level 40 | Dead within 2 seconds | Dead |

## Early game

Monsters hit softer early: half damage at level 1, rising to full damage at level 11, so a
new player survives 18–38 same-level hits instead of 18. Twelve spawns of level 1–4 voles
and toads ring Cinder Crossing within 45 tiles; beyond that, levels rise by about one per
8.5 tiles. Spawns stay at least 7 steps from roads and sit in small clearings.

## Gear tiers

Ten tiers every five levels; accessories from tier 20; relics at level 50 from boss quests.
`game/data/items.gd` derives every item's stats from the curves above, so gear follows any
balance change:

- **Weapons** add the vocation's share of `gear_attack_budget(tier + 2)`, the attack that
  lifts a player from base to geared hits (about six per same-level kill), with a floor that
  rises one point per tier so early tiers still upgrade.
- **Defense** of a full set (helmet 22%, armor 42%, shield 36%) rises from 14 at tier 1 to
  70 at tier 45 (about a third less damage taken). Armor adds 1% of reference health as
  regeneration; spellbooks give 12% of the set defense plus 10% of reference mana.
- **Accessories** take shares of the reference health and mana at their level: amulets 6%
  health, capes 8% defense share and 6% mana, charms 2% regen and 1% healing, rings 3%
  health and 3% mana each.
- **Relics** are computed at level 50 and multiplied by 1.15 (Vaelith's by 1.3).

The 15 [hunting weapons](gameplay.md#hunting-weapons) are ordinary tier-balanced sidegrades.
They use `Items.tier_stats` without per-item stat overrides. Their source-specific loot rolls
do not dilute the existing generic tier pool or vendor stock; equipment rolls are gated by
the killed monster's level. Names and looks vary, not attack timing, range or damage type.

Regenerate with `make gear-table`:

| Tier | Helmet | Armor | Shield (Knight, Paladin) | Spellbook (Sorcerer, Druid) |
| ---: | --- | --- | --- | --- |
| 1 | Ember cap (3 def) | Moss coat (6 def, 2 regen) | Oak buckler (5 def) | Tattered primer (2 def, 6 mana) |
| 5 | Iron coif (4 def) | Ash tunic (8 def, 2 regen) | Hide targe (7 def) | Apprentice grimoire (2 def, 8 mana) |
| 10 | Bronze helm (6 def) | Bronze scale coat (11 def, 3 regen) | Bronze heater (9 def) | Bound codex (3 def, 13 mana) |
| 15 | Steel kettle hat (7 def) | Steel hauberk (13 def, 5 regen) | Steel kite shield (11 def) | Runed tome (4 def, 20 mana) |
| 20 | Silverleaf helm (8 def) | Silverleaf mail (16 def, 8 regen) | Silverleaf shield (14 def) | Silverleaf folio (5 def, 30 mana) |
| 25 | Cobalt sallet (10 def) | Cobalt brigandine (19 def, 12 regen) | Cobalt tower shield (16 def) | Cobalt codex (5 def, 47 mana) |
| 30 | Embersteel helm (11 def) | Embersteel cuirass (21 def, 18 regen) | Embersteel aegis (18 def) | Ember tome (6 def, 71 mana) |
| 35 | Duskiron visor (13 def) | Duskiron plate (24 def, 27 regen) | Duskiron bulwark (21 def) | Dusk grimoire (7 def, 109 mana) |
| 40 | Starforged helm (14 def) | Starforged plate (27 def, 42 regen) | Starforged bulwark (23 def) | Star atlas (8 def, 168 mana) |
| 45 | Wyrmglass greathelm (15 def) | Wyrmglass plate (29 def, 64 regen) | Wyrmglass ward (25 def) | Wyrmglass codex (8 def, 257 mana) |
| Tier | Knight | Paladin | Sorcerer | Druid |
| ---: | --- | --- | --- | --- |
| 1 | Copper blade (2 atk) | Willow shortbow (2 atk) | Kindling wand (2 atk) | Sapling rod (2 atk) |
| 5 | Flint hatchet (3 atk) | Yew hunting bow (3 atk) | Spark wand (3 atk) | Thornwood rod (3 atk) |
| 10 | Bronze mace (4 atk) | Bronze recurve (4 atk) | Ember wand (4 atk) | Moss rod (4 atk) |
| 15 | Steel longsword (5 atk) | Steel longbow (5 atk) | Flame wand (6 atk) | Rootbound rod (5 atk) |
| 20 | Silverleaf axe (6 atk) | Silverleaf bow (8 atk) | Silverfire wand (10 atk) | Silverleaf rod (6 atk) |
| 25 | Cobalt warhammer (7 atk) | Cobalt crossbow (12 atk) | Storm wand (15 atk) | Tide rod (7 atk) |
| 30 | Embersteel blade (11 atk) | Ember recurve (18 atk) | Blaze wand (23 atk) | Emberthorn rod (8 atk) |
| 35 | Duskiron cleaver (16 atk) | Dusk longbow (27 atk) | Dusk wand (35 atk) | Duskbloom rod (11 atk) |
| 40 | Starforged maul (25 atk) | Starforged crossbow (41 atk) | Starfire wand (54 atk) | Starbloom rod (17 atk) |
| 45 | Wyrmglass greatsword (38 atk) | Wyrmglass bow (63 atk) | Wyrmglass wand (82 atk) | Wyrmglass rod (25 atk) |
| Tier | Amulet | Cape | Charm | Ring |
| ---: | --- | --- | --- | --- |
| 20 | River pendant (46 hp) | Silverleaf cape (3 def, 18 mana) | Hearth charm (15 regen, 8 heal) | Garnet ring (23 hp, 9 mana) |
| 25 | Cobalt amulet (70 hp) | Cobalt cape (4 def, 28 mana) | Tide charm (23 regen, 12 heal) | Cobalt ring (35 hp, 14 mana) |
| 30 | Ember amulet (107 hp) | Ember cape (4 def, 43 mana) | Cinder charm (36 regen, 18 heal) | Ember ring (53 hp, 21 mana) |
| 35 | Dusk amulet (164 hp) | Dusk cape (5 def, 66 mana) | Dusk charm (55 regen, 27 heal) | Dusk ring (82 hp, 33 mana) |
| 40 | Star amulet (251 hp) | Starweave cape (5 def, 101 mana) | Star charm (84 regen, 42 heal) | Star ring (126 hp, 50 mana) |
| 45 | Wyrmglass amulet (385 hp) | Wyrmscale cape (6 def, 154 mana) | Wyrm charm (128 regen, 64 heal) | Wyrmglass ring (192 hp, 77 mana) |
| Boss | Relics (level 50, bound; one trophy each) |
| --- | --- |
| Vaelith, Sovereign of the Hollow | Voidrend (64 atk); Eclipse bow (107 atk); Starless wand (139 atk); Nightbloom rod (43 atk); Sovereign's mantle (8 def, 307 mana) |
| Morvain the Drowned | Abyssal greathelm (20 def); Abyssal plate (37 def, 113 regen); Tidebreaker (56 atk); Abyssal ward (31 def) |
| Kharzul the Cinder Colossus | Cinderheart bow (94 atk); Cinderheart wand (123 atk); Molten heart (679 hp); Cinderheart charm (227 regen, 113 heal) |
| Sylvaine the Hollow Bloom | Bloomheart rod (38 atk); Verdant codex (10 def, 452 mana); Hollowbloom cape (7 def, 271 mana); Bloomsoul ring (339 hp, 136 mana) |

## Level table (reference vocation: Paladin)

Champions are dungeon mini-bosses: 10x a normal monster's health, 1.8x its hits, and 25x its experience.

| Level | Player HP | Base atk | Geared atk | Mob HP | Elite HP | Champion HP | Boss HP | Mob hit | Elite hit | Champion hit | Boss hit | Mob XP | Champion XP | XP to next |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 150 | 4 | 5 | 30 | 120 | 300 | 5,340 | 4 | 6 | 8 | 10 | 15 | 375 | 60 |
| 2 | 163 | 4 | 5 | 33 | 131 | 327 | 5,816 | 5 | 7 | 9 | 12 | 16 | 408 | 112 |
| 3 | 178 | 4 | 6 | 36 | 142 | 356 | 6,334 | 6 | 9 | 11 | 15 | 18 | 445 | 180 |
| 4 | 194 | 5 | 6 | 39 | 155 | 388 | 6,899 | 7 | 10 | 13 | 17 | 19 | 484 | 247 |
| 5 | 211 | 5 | 7 | 42 | 169 | 422 | 7,513 | 8 | 12 | 15 | 21 | 21 | 528 | 336 |
| 6 | 230 | 6 | 8 | 46 | 184 | 460 | 8,183 | 10 | 14 | 17 | 24 | 23 | 575 | 437 |
| 7 | 250 | 6 | 8 | 50 | 200 | 501 | 8,912 | 11 | 17 | 20 | 28 | 25 | 626 | 550 |
| 8 | 273 | 7 | 9 | 55 | 218 | 545 | 9,706 | 13 | 19 | 23 | 32 | 27 | 682 | 675 |
| 9 | 297 | 7 | 10 | 59 | 238 | 594 | 10,571 | 15 | 22 | 27 | 37 | 30 | 742 | 840 |
| 10 | 323 | 8 | 11 | 65 | 259 | 647 | 11,513 | 17 | 26 | 31 | 43 | 32 | 808 | 992 |
| 11 | 352 | 9 | 12 | 70 | 282 | 704 | 12,539 | 20 | 29 | 35 | 49 | 35 | 881 | 1,190 |
| 12 | 384 | 10 | 13 | 77 | 307 | 767 | 13,656 | 21 | 32 | 38 | 53 | 38 | 959 | 1,406 |
| 13 | 418 | 10 | 14 | 84 | 334 | 836 | 14,873 | 23 | 35 | 42 | 58 | 42 | 1,044 | 1,680 |
| 14 | 455 | 11 | 15 | 91 | 364 | 910 | 16,199 | 25 | 38 | 46 | 63 | 46 | 1,138 | 1,978 |
| 15 | 496 | 12 | 17 | 99 | 396 | 991 | 17,642 | 28 | 41 | 50 | 69 | 50 | 1,239 | 2,300 |
| 16 | 540 | 13 | 18 | 108 | 432 | 1,079 | 19,214 | 30 | 45 | 54 | 75 | 54 | 1,349 | 2,646 |
| 17 | 588 | 15 | 20 | 118 | 470 | 1,176 | 20,926 | 33 | 49 | 59 | 82 | 59 | 1,470 | 3,068 |
| 18 | 640 | 16 | 21 | 128 | 512 | 1,280 | 22,791 | 36 | 53 | 64 | 89 | 64 | 1,600 | 3,520 |
| 19 | 697 | 17 | 23 | 139 | 558 | 1,394 | 24,822 | 39 | 58 | 70 | 97 | 70 | 1,743 | 4,060 |
| 20 | 759 | 19 | 25 | 152 | 608 | 1,519 | 27,034 | 42 | 63 | 76 | 105 | 76 | 1,898 | 4,636 |
| 21 | 827 | 21 | 28 | 165 | 662 | 1,654 | 29,443 | 46 | 69 | 83 | 115 | 83 | 2,068 | 5,312 |
| 22 | 901 | 23 | 30 | 180 | 721 | 1,801 | 32,067 | 50 | 75 | 90 | 125 | 90 | 2,252 | 6,030 |
| 23 | 981 | 25 | 33 | 196 | 785 | 1,962 | 34,924 | 55 | 82 | 98 | 136 | 98 | 2,453 | 6,860 |
| 24 | 1,068 | 27 | 36 | 214 | 855 | 2,137 | 38,036 | 59 | 89 | 107 | 148 | 107 | 2,671 | 7,811 |
| 25 | 1,164 | 29 | 39 | 233 | 931 | 2,327 | 41,426 | 65 | 97 | 116 | 162 | 116 | 2,909 | 8,816 |
| 26 | 1,267 | 32 | 42 | 253 | 1,014 | 2,535 | 45,117 | 70 | 106 | 127 | 176 | 127 | 3,168 | 10,033 |
| 27 | 1,380 | 35 | 46 | 276 | 1,104 | 2,761 | 49,137 | 77 | 115 | 138 | 192 | 138 | 3,451 | 11,316 |
| 28 | 1,503 | 38 | 50 | 301 | 1,203 | 3,007 | 53,516 | 84 | 125 | 150 | 209 | 150 | 3,758 | 12,750 |
| 29 | 1,637 | 41 | 55 | 327 | 1,310 | 3,274 | 58,285 | 91 | 136 | 164 | 227 | 164 | 4,093 | 14,432 |
| 30 | 1,783 | 45 | 59 | 357 | 1,426 | 3,566 | 63,479 | 99 | 149 | 178 | 248 | 178 | 4,458 | 16,198 |
| 31 | 1,942 | 49 | 65 | 388 | 1,554 | 3,884 | 69,135 | 108 | 162 | 194 | 270 | 194 | 4,855 | 18,236 |
| 32 | 2,115 | 53 | 71 | 423 | 1,692 | 4,230 | 75,296 | 118 | 176 | 212 | 294 | 212 | 5,288 | 20,564 |
| 33 | 2,304 | 58 | 77 | 461 | 1,843 | 4,607 | 82,006 | 128 | 192 | 230 | 320 | 230 | 5,759 | 23,000 |
| 34 | 2,509 | 63 | 84 | 502 | 2,007 | 5,018 | 89,313 | 139 | 209 | 251 | 348 | 251 | 6,272 | 25,853 |
| 35 | 2,732 | 68 | 91 | 546 | 2,186 | 5,465 | 97,272 | 152 | 228 | 273 | 379 | 273 | 6,831 | 28,938 |
| 36 | 2,976 | 74 | 99 | 595 | 2,381 | 5,952 | 105,940 | 165 | 248 | 298 | 413 | 298 | 7,440 | 32,482 |
| 37 | 3,241 | 81 | 108 | 648 | 2,593 | 6,482 | 115,380 | 180 | 270 | 324 | 450 | 324 | 8,103 | 36,288 |
| 38 | 3,530 | 88 | 118 | 706 | 2,824 | 7,060 | 125,662 | 196 | 294 | 353 | 490 | 353 | 8,825 | 40,595 |
| 39 | 3,844 | 96 | 128 | 769 | 3,076 | 7,689 | 136,860 | 214 | 320 | 384 | 534 | 384 | 9,611 | 45,312 |
| 40 | 4,187 | 105 | 140 | 837 | 3,350 | 8,374 | 149,056 | 233 | 349 | 419 | 582 | 419 | 10,467 | 50,699 |
| 41 | 4,560 | 114 | 152 | 912 | 3,648 | 9,120 | 162,338 | 253 | 380 | 456 | 633 | 456 | 11,400 | 56,544 |
| 42 | 4,966 | 124 | 166 | 993 | 3,973 | 9,933 | 176,804 | 276 | 414 | 497 | 690 | 497 | 12,416 | 63,119 |
| 43 | 5,409 | 135 | 180 | 1,082 | 4,327 | 10,818 | 192,559 | 300 | 451 | 541 | 751 | 541 | 13,522 | 70,330 |
| 44 | 5,891 | 147 | 196 | 1,178 | 4,713 | 11,782 | 209,718 | 327 | 491 | 589 | 818 | 589 | 14,727 | 78,337 |
| 45 | 6,416 | 160 | 214 | 1,283 | 5,133 | 12,832 | 228,406 | 356 | 535 | 642 | 891 | 642 | 16,040 | 87,312 |
| 46 | 6,988 | 175 | 233 | 1,398 | 5,590 | 13,975 | 248,760 | 388 | 582 | 699 | 971 | 699 | 17,469 | 97,161 |
| 47 | 7,610 | 190 | 254 | 1,522 | 6,088 | 15,221 | 270,927 | 423 | 634 | 761 | 1,057 | 761 | 19,026 | 108,062 |
| 48 | 8,288 | 207 | 276 | 1,658 | 6,631 | 16,577 | 295,069 | 460 | 691 | 829 | 1,151 | 829 | 20,721 | 120,205 |
| 49 | 9,027 | 226 | 301 | 1,805 | 7,222 | 18,054 | 321,363 | 502 | 752 | 903 | 1,254 | 903 | 22,568 | 133,644 |
| 50 | 9,831 | 246 | 328 | 1,966 | 7,865 | 19,663 | 350,000 | 546 | 819 | 983 | 1,365 | 983 | 24,579 | max |
| Vocation | Role | HP 1 / 50 | Mana 1 / 50 | Attack 1 / 50 | Healing/s 1 / 50 | Base def |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Knight | Tank | 225 / 14,747 | 30 / 1,966 | 2 / 147 | 0 / 0 | 20 |
| Paladin | Ranged damage, light healing | 150 / 9,831 | 60 / 3,933 | 4 / 246 | 1 / 39 | 5 |
| Sorcerer | Burst damage | 90 / 5,899 | 96 / 6,292 | 5 / 320 | 0 / 0 | 0 |
| Druid | Healer | 90 / 5,899 | 96 / 6,292 | 2 / 98 | 6 / 393 | 0 |
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

Growth per level: 1.0891. Boss = 178 normal mobs. Reference DPS at level 50: 163.9. Normal kills from 1 to 50: 3,724.
