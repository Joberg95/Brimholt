# Brimholt balance sheet

Curves for levels 1-50 and four classes, used by combat (`game/core/combat.gd`), monsters
(`game/data/monsters.gd`), spells (`game/data/spells.gd`), and items. `game/data/balance.gd` is the one source.
Regenerate the tables after changing a constant:

```sh
godot --headless --path . --script res://tools/generators/balance_table.gd
```

## The final boss

| Anchor | Value |
| --- | --- |
| Final boss health | **700,000** |
| Smallest intended raid | **20 level-50 players**: 4 Warriors, 6 Hunters, 6 Sorcerers, 4 Druids |
| Intended fight | 240 s; the boss **enrages and wipes the raid at 245 s** |
| Healing pressure | raid-wide damage needing 4.4 Druids' worth of healing per second |
| Tank swaps | boss hits stack a wound, so at least **4 Warriors** (two swapping pairs) must alternate |

Each requirement removes a different shortcut: the enrage timer requires damage, the
healing pressure requires healers, and the wound stacks require four tanks. With only about
2% slack on the timer, removing **any one player** from the intended raid loses, and the
rules test checks every group of nineteen or fewer players exhaustively: none can win. Larger
or differently mixed groups can (see below). The raid and the boss's health doubled together
(from ten players and 350,000), so every monster and item curve below is unchanged.

## Classes

The four classes follow the classic tank / ranged / burst caster / healer split. They
multiply the reference (Hunter) curves:

| Class | Health | Mana | Damage | Healing | Base defense |
| --- | ---: | ---: | ---: | ---: | ---: |
| Warrior | ×1.5 | ×0.5 | ×0.6 | 0 | 20 |
| Hunter | ×1.0 | ×1.0 | ×1.0 | ×0.1 | 5 |
| Sorcerer | ×0.6 | ×1.6 | ×1.3 | 0 | 0 |
| Druid | ×0.6 | ×1.6 | ×0.4 | ×1.0 | 0 |

| Class | Role | HP 1 / 50 | Mana 1 / 50 | Attack 1 / 50 | Healing/s 1 / 50 | Base def |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Warrior | Tank | 225 / 14,747 | 30 / 1,966 | 2 / 147 | 0 / 0 | 35 |
| Hunter | Ranged damage, light healing | 150 / 9,831 | 60 / 3,933 | 4 / 246 | 1 / 39 | 5 |
| Sorcerer | Burst damage | 90 / 5,899 | 96 / 6,292 | 5 / 320 | 0 / 0 | 0 |
| Druid | Healer | 90 / 5,899 | 96 / 6,292 | 2 / 98 | 6 / 393 | 0 |

## Raid checks

| Level-50 group | Players | Boss down in | Healing (need 4.4) | Tanks | Result |
| --- | ---: | ---: | ---: | ---: | --- |
| 4 Warrior, 6 Hunter, 6 Sorcerer, 4 Druid | 20 | 240 s | 4.6 | 4 | wins |
| 3 Warrior, 6 Hunter, 6 Sorcerer, 4 Druid | 19 | 248 s | 4.6 | 3 | loses: not enough damage before the 245 s enrage, needs 4 tanks to swap |
| 4 Warrior, 5 Hunter, 6 Sorcerer, 4 Druid | 19 | 254 s | 4.5 | 4 | loses: not enough damage before the 245 s enrage |
| 4 Warrior, 6 Hunter, 5 Sorcerer, 4 Druid | 19 | 259 s | 4.6 | 4 | loses: not enough damage before the 245 s enrage |
| 4 Warrior, 6 Hunter, 6 Sorcerer, 3 Druid | 19 | 246 s | 3.6 | 4 | loses: not enough damage before the 245 s enrage, not enough healing |
| 4 Warrior, 4 Hunter, 8 Sorcerer, 4 Druid | 20 | 232 s | 4.4 | 4 | wins |
| 4 Warrior, 8 Hunter, 6 Sorcerer, 4 Druid | 22 | 216 s | 4.8 | 4 | wins |
| 4 Warrior, 0 Hunter, 10 Sorcerer, 5 Druid | 19 | 246 s | 5.0 | 4 | loses: not enough damage before the 245 s enrage |
| 2 Warrior, 3 Hunter, 3 Sorcerer, 2 Druid | 10 | 480 s | 2.3 | 2 | loses: not enough damage before the 245 s enrage, not enough healing, needs 4 tanks to swap |
| 1 Warrior, 1 Hunter, 1 Sorcerer, 1 Druid | 4 | 1295 s | 1.1 | 1 | loses: not enough damage before the 245 s enrage, not enough healing, needs 4 tanks to swap |

## Derivation

Players and monsters attack every **2 seconds**, as in Tibia. The intended raid deals 17.8
reference players' worth of damage (4×0.6 + 6×1.0 + 6×1.3 + 4×0.4). Killing 700,000 health
in 240 s means one geared Hunter-equivalent deals about **164 damage per second** at
level 50, or **328 per hit**. Six such hits kill a level-50 normal mob, so it has **1,966**
health and the boss equals 356 normal mobs. A single growth factor (**×1.089 per level**)
connects level 1 (30-health mobs, 150-health Hunters) to level 50 and scales mob health,
mob damage, player health, mana, attack, and healing together, so hit counts stay
constant at every level. On top of the curve, every monster but the final bosses has a fifth
more health (`Balance.MOB_HEALTH_SCALE` = 1.2: parties killed them too fast), so a geared
player needs about seven hits instead of six; experience follows the curve, not the scale.

| Rank | Health | Damage | Experience |
| --- | --- | --- | --- |
| Normal | ×1 | ×1 | ×1 |
| Elite | ×4 | ×1.5 | ×5 |
| Boss | ×356 | ×2.5 | ×100 |

- **Health / Mana** – maximums. **Attack** – damage per hit; gear should supply the gap
  between the base and geared columns (`Balance.gear_attack_budget(level)`). Hits vary
  ±15%; critical hits (base 5% chance) deal ×1.5.
- **Defense** – damage taken is `raw × 100 / (100 + defense)`: 100 defense halves it.
- **Regen** – health per 10 s; base 4% of max health. Mana regenerates 8% of max per 10 s.
  Both triple when you have been out of combat for 8 s.
- **Healing** – health per second a class can restore to others.
- **Spells** – damage is attack × spell power; mana costs are a share of max mana.

Leveling needs `4 + 3 × (level − 1)` same-level normal kills per level, so level 2 takes
about 4 kills and the whole climb to 50 about 3,700. Experience from a kill is shared by damage dealt; a sharing party pools it and splits it evenly with a ×1.2–×2 class bonus ([gameplay](gameplay.md#parties-and-shared-experience)). Dying costs 10% of total
experience, which can lose levels; below level 8, players keep their items and gold.

## Monster pace, leash, and fights you cannot dodge

Monsters notice players within 3 tiles (`Monsters.AGGRO_RANGE`), so a camp can be pulled one
monster at a time from its edge, and chase at `Balance.chase_seconds(monster_level,
target_level)` per tile: 0.17 s against a target of their level or higher (just quicker than a
player's 0.18 s step), falling to 0.13 s once they outlevel the target by 10 or more. Nobody
outruns a monster far above them; a monster far above your level simply kills you. A monster gives up when its target enters a
town, is dragged more than 12 tiles (`Monsters.LEASH`) from its home, or gets more than 12
tiles away; it heals to full at once and walks home at its own pace, untouchable and ignoring
players until it arrives. So a fight must be won where it starts, with armor, spells, and
potions. A same-level normal monster hits for 1/18 of a geared player's base health every
2 seconds (`HITS_TO_FALL`).

`make fight-sim MONSTER=<id> LEVELS=... COUNT=...` runs the real combat rules for each
class in its tier's vendor gear, auto-attacking only and with spells and potions. Normal
monsters at the player's level currently give:

| Fight | Auto-attacks only | Spells and potions |
| --- | --- | --- |
| One monster | 3–27% health lost; nobody dies | 3–27% lost, 0–3 potions |
| A camp of three | Warriors end at 5–60% health; Hunters die from level 10, Sorcerers and Druids always | Everyone wins, ending at 43–82% health, 0–6 potions (Druids about 4–6, mostly mana); higher-level spells clear camps faster (a level 45 Sorcerer in about 6 s, a Hunter in about 8 s) |
| Level 1 against a level 40 | Dead within 2 seconds | Dead |

## PvP

Player health is built to survive many monster hits, so without help duels never end: at level
45 a knight dealt about 35 damage per second to another knight with about 10,000 health,
less than natural regeneration. Three constants fix that (`Balance`):

- `PVP_DAMAGE` 1.5: player-on-player hits (auto-attacks and spells) deal 1.5× damage.
- `PVP_HEALING` 0.35: for `PVP_COMBAT_SECONDS` (10 s) after any hit between two players, both
  heal at 35% (spells, potions, regeneration).
- `PVP_DAMPENING_SECONDS` 90: that healing fades linearly to zero over 90 s of continuous PvP
  combat, so even two healers finish.

Potions have their own cooldowns (health 6 s, mana 3 s). `make duel-sim` fights same-level
duels with spells and potions (levels 20, 30, 45; duelists start adjacent):

| Matchup | Winner and time |
| --- | --- |
| Warrior vs Hunter | Warrior, 54–94 s |
| Hunter vs Sorcerer | Hunter, 10–13 s (Sorcerer at 30) |
| Sorcerer vs Warrior | Sorcerer, 15 s (Warrior at 30) |
| Warrior vs Druid | Warrior, 25–30 s |
| Hunter vs Druid | Hunter, 19–22 s |
| Sorcerer vs Druid | Sorcerer, 8–10 s |
| Warrior and Druid mirrors | 37–158 s |
| Hunter mirror | 55–61 s |
| Sorcerer mirror | 6 s: glass cannons |

The level 40-50 spells (plan 25, checked at levels 40, 45, 48, and 50) keep the triangle. Mana
ward was first a full mana shield (1 mana a point) and turned Hunter vs Sorcerer around and
tripled the Sorcerer mirror; it now takes 30% of each hit at 2 mana a point, and bots and sims
cast it when hurt, like a heal, since in a hunt it spends the mana heals need. With it the
Hunter wins in 13-15 s, and the Sorcerer mirror stays 6-9 s. Iron bulwark at 50 gives the Warrior
back the Hunter matchup (70 s; the Hunter had edged it at 50). Hunter's mark and Soulfire make
level 50 hunts a little quicker (a bog hulk pair 8.4 -> 6.4 s for a Hunter) without changing who
survives them.

**Class counters.** Damage is physical (Warriors, Hunters, most monsters) or magic (Sorcerers,
Druids, rune spells, wraiths, the lich, the Hollow Bloom), cut by defense and magic defense
respectively (`Balance.ARMOR_TYPES`). Plate makes Warriors hard to wear down for Hunters and
Druids, but spells pass through it, so the classes form a triangle: **Warrior beats Hunter,
Hunter beats Sorcerer, Sorcerer beats Warrior**, in 10 to 11 of 12 sampled levels from 20 to
48 each. Druids, the healers, lose one-on-one but slow fights with Entangling roots, and
Hunters keep their distance with Crippling arrow; the duels start adjacent, so they show
neither. Below level 20 the gear is too light for the counters to show (a Hunter still beats
a Warrior at level 10).

## Gear-only stats

The stats only gear gives (`World.GEAR_STATS`) were checked with loadouts over the tier gear
(`make fight-sim GEAR=slot:item`, `duel_sim.gd --gear1=... --gear2=...`), 2026-10-17:

| Stat | Source | Result |
| --- | --- | --- |
| Life leech | Warrior blades, 1-5% (`Items.leech_for`, cap `World.LEECH_MAX` 5) | A small help: 3 bog hulks or behemoths at 45, 2 Blackreed wardens at 50, 4 reedfangs at 47 end with 2-3 points more health and the same potions; about 100 more healing in a level-50 duel. A Warrior deals about 150 damage a second at 45, so 5% is about 7 health a second next to about 50 from regeneration. Leeching blades therefore keep a plain sword's full attack (no `WEAPON_FOCUS_ATTACK` trade); with the trade they ended fights slower and no healthier |
| Movement speed | Boots 4-10%, the Venomfang axe 4% (Warrior) | Stacks multiply: walking 5.6 tiles a second, mounted 6.9, mounted with 14% gear 7.9; Fleetfoot or Swift growth on top reach about 10 for 8 s every 20 s, an escape window, not a permanent lead. Mounted riders already outrun same-level monsters (0.144 s steps against 0.17 s chases), as before. In duels Hastewind boots only cost armour (a Warrior wins 6 s slower) |
| Maximum mana | Sorcerer cloth boots 6-8% (Frostbloom slippers, Phialbound boots) | +350-400 mana at 45 (about a third of a mana potion); hunts of 3 bog hulks are not mana-bound, so results do not move |
| Frost damage | The Rootbound crown, 9% | A Druid on 3 bog hulks at 45: 36.7 to 35.2 s, 8 to 6 potions |

Numbers kept: `HELMET_FOCUS_DEFENSE` 0.85, `WEAPON_FOCUS_SPEED` 4, the boots' extras, and
`LEECH_LEVELS` 6. Changed: leeching blades keep full attack.

## Early game

Monsters hit softer early: half damage at level 1, rising to full damage at level 11, so a
new player survives 18–38 same-level hits instead of 18. Twelve spawns of level 1–4 voles
and toads ring Cinder Crossing within 45 tiles; beyond that, levels rise by about one per
8.5 tiles. Spawns stay at least 7 steps from roads and sit in small clearings.

## Gold income

Gold comes from three places: coins from kills, task rewards, and selling loot to vendors.
Kills dominate, so they set the pace: `Balance.coins_per_kill(level, rank)` is 0.2 + 0.02 x
level coins of 25 gold (5 gold a kill at level 1, 15 at 19, 30 at 50; elites and bosses 3
coins more). Task rewards pay a `share` of the same expectation for their kills
(`Quests.reward`). The kills from level 1 to 19 pay about 5,900 gold, about one vendor gear
set of level 19 (5,500); the old step curve (a coin per 10 levels plus a 60% chance of one)
paid about 17,600, which with tasks and sales left a level-19 character near 22,000. A unit
test keeps kill gold to level 19 within 0.6-1.6 gear sets.

## Gear tiers

Ten tiers every five levels; accessories from tier 20; relics at level 50 from boss quests.
`game/data/items.gd` derives every item's stats from the curves above, so gear follows any
balance change:

- **Weapons** add the class's share of `gear_attack_budget(tier + 2)`, the attack that
  lifts a player from base to geared hits (about six per same-level kill), with a floor that
  rises one point per tier so early tiers still upgrade.
- **Defense** of a full set (helmet 15%, armor 30%, legs 15%, boots 10%, shield 30%) rises
  from 14 at tier 1 to 70 at tier 45 (about a third less damage taken). The armor type turns a
  piece's share into defense and magic defense (`Balance.ARMOR_TYPES`): plate ×2.2 defense
  and no magic defense, mail ×0.85 and ×0.25, leather ×0.7 and ×0.6, cloth ×0.5 and ×1.0.
  Armor adds 1% of reference health as regeneration; spellbooks give 6% of the set defense,
  10% of it as magic defense, and 10% of reference mana.
- **Accessories** take shares of the reference health and mana at their level: amulets 6%
  health and 10% of the set defense as magic defense, capes 15% as magic defense and 6% mana,
  charms 2% regen and 1% healing, rings 3% health, 3% mana, and 2% critical chance each.
- **Critical chance and healing power**: Hunters' and Sorcerers' weapons add 2% critical
  chance plus 1% every other tier (base 5%); Druids' rods add 1.5% of reference health as
  healing power.
- **Relics** are computed at level 50 and multiplied by 1.15 (Vaelith's by 1.3).

The 15 [hunting weapons](gameplay.md#hunting-weapons) are ordinary tier-balanced sidegrades.
They use `Items.tier_stats` without per-item stat overrides. Their source-specific loot rolls
do not dilute the existing generic tier pool or vendor stock; equipment rolls are gated by
the killed monster's level. Names and looks vary, not attack timing, range or damage type.

Helmets, armor, legs, and boots come in four armor types, one per class (`Balance.ARMOR_OF`): Plate for Warriors, Mail for Hunters, Leather for Druids and Cloth for Sorcerers. The type decides how a piece splits into defense (physical) and magic defense (above). Relics have no armor type and give each wearer the best of both. Mythic gear is level 50 and unbound, computed at level 50 with a 1.05 bonus (relics 1.15), so every piece sits between tier 45 and the relics; only the level-50 elites drop it. Every bonus adds at least one point to each stat.

Regenerate with `make gear-table`:

| Tier | Plate (Warrior) | Mail (Hunter) | Leather (Druid) | Cloth (Sorcerer) |
| ---: | --- | --- | --- | --- |
| 1 | Dented iron helm (5 def)<br>Rusted breastplate (9 def, 2 regen)<br>Rusted legplates (5 def)<br>Rusted sabatons (3 def) | Ringmail coif (1 def, 1 mdef)<br>Ringmail shirt (4 def, 1 mdef, 2 regen)<br>Ringmail chausses (1 def, 1 mdef)<br>Ringmail striders (2 def) | Ember cap (2 def, 1 mdef)<br>Moss coat (2 def, 3 mdef, 2 regen)<br>Moss breeches (2 def, 1 mdef)<br>Moss boots (1 def, 1 mdef) | Linen hat (1 def, 2 mdef)<br>Linen robe (2 def, 4 mdef, 2 regen)<br>Linen leggings (1 def, 2 mdef)<br>Linen slippers (1 def, 1 mdef) |
| 5 | Iron sallet (6 def)<br>Iron cuirass (13 def, 2 regen)<br>Iron legplates (6 def)<br>Iron sabatons (4 def) | Ranger's cap (2 def, 1 mdef)<br>Ranger's ringmail (5 def, 1 mdef, 2 regen)<br>Ranger's chausses (2 def, 1 mdef)<br>Ranger's striders (2 def) | Hide hood (2 def, 2 mdef)<br>Hide jerkin (4 def, 3 mdef, 2 regen)<br>Hide breeches (2 def, 2 mdef)<br>Hide boots (1 def, 1 mdef) | Apprentice's hat (1 def, 3 mdef)<br>Apprentice's robe (3 def, 6 mdef, 2 regen)<br>Apprentice's leggings (1 def, 3 mdef)<br>Apprentice's slippers (1 def, 2 mdef) |
| 10 | Bronze helm (8 def)<br>Bronze breastplate (17 def, 3 regen)<br>Bronze legplates (8 def)<br>Bronze sabatons (6 def) | Woodland hood (3 def, 1 mdef)<br>Woodland hauberk (6 def, 2 mdef, 3 regen)<br>Woodland chausses (3 def, 1 mdef)<br>Woodland striders (2 def, 1 mdef) | Thornvine hood (3 def, 2 mdef)<br>Thornvine jerkin (5 def, 5 mdef, 3 regen)<br>Thornvine breeches (3 def, 2 mdef)<br>Thornvine boots (1 def, 2 mdef) | Amethyst hat (2 def, 4 mdef)<br>Amethyst robe (3 def, 8 mdef, 3 regen)<br>Amethyst leggings (2 def, 4 mdef)<br>Amethyst slippers (1 def, 3 mdef) |
| 15 | Blackened steel helm (11 def)<br>Blackened steel breastplate (21 def, 5 regen)<br>Blackened steel legplates (11 def)<br>Blackened steel sabatons (7 def) | Tracker's hat (4 def, 1 mdef)<br>Tracker's hauberk (9 def, 2 mdef, 5 regen)<br>Tracker's chausses (4 def, 1 mdef)<br>Tracker's striders (3 def, 1 mdef) | Snowwolf hood (3 def, 3 mdef)<br>Snowwolf coat (6 def, 6 mdef, 5 regen)<br>Snowwolf breeches (3 def, 3 mdef)<br>Snowwolf boots (2 def, 2 mdef) | Crimson silk hat (2 def, 5 mdef)<br>Crimson silk robe (4 def, 10 mdef, 5 regen)<br>Crimson silk leggings (2 def, 5 mdef)<br>Crimson silk slippers (2 def, 3 mdef) |
| 20 | Crusader helm (13 def)<br>Crusader breastplate (25 def, 8 regen)<br>Crusader legplates (13 def)<br>Crusader sabatons (8 def) | Bloodfeather hat (5 def, 1 mdef)<br>Bloodfeather hauberk (10 def, 3 mdef, 8 regen)<br>Bloodfeather chausses (5 def, 1 mdef)<br>Bloodfeather striders (3 def, 1 mdef) | Silverleaf hood (4 def, 3 mdef)<br>Silverleaf leathers (8 def, 7 mdef, 8 regen)<br>Silverleaf breeches (4 def, 3 mdef)<br>Silverleaf boots (3 def, 2 mdef) | Moonsilk hat (3 def, 6 mdef)<br>Moonsilk robe (6 def, 11 mdef, 8 regen)<br>Moonsilk leggings (3 def, 6 mdef)<br>Moonsilk slippers (2 def, 4 mdef) |
| 25 | Golden lion helm (15 def)<br>Golden lion plate (29 def, 12 regen)<br>Golden lion legplates (15 def)<br>Golden lion sabatons (10 def) | Windrider helm (5 def, 2 mdef)<br>Windrider mail (12 def, 3 mdef, 12 regen)<br>Windrider chausses (5 def, 2 mdef)<br>Windrider striders (4 def, 1 mdef) | Spiritbloom hood (5 def, 4 mdef)<br>Spiritbloom leathers (9 def, 8 mdef, 12 regen)<br>Spiritbloom breeches (5 def, 4 mdef)<br>Spiritbloom boots (3 def, 3 mdef) | Astral veil hat (3 def, 7 mdef)<br>Astral veil robe (7 def, 13 mdef, 12 regen)<br>Astral veil leggings (3 def, 7 mdef)<br>Astral veil slippers (3 def, 4 mdef) |
| 30 | Frostborn helm (17 def)<br>Frostborn plate (34 def, 18 regen)<br>Frostborn legplates (17 def)<br>Frostborn sabatons (11 def) | Sunspear hood (6 def, 2 mdef)<br>Sunspear hauberk (13 def, 4 mdef, 18 regen)<br>Sunspear chausses (6 def, 2 mdef)<br>Sunspear striders (5 def, 1 mdef) | Mooncloak hood (5 def, 5 mdef)<br>Mooncloak leathers (11 def, 9 mdef, 18 regen)<br>Mooncloak breeches (5 def, 5 mdef)<br>Mooncloak boots (4 def, 3 mdef) | Arcane eclipse cowl (3 def, 8 mdef)<br>Arcane eclipse robe (8 def, 15 mdef, 18 regen)<br>Arcane eclipse leggings (3 def, 8 mdef)<br>Arcane eclipse slippers (3 def, 5 mdef) |
| 35 | Crimson aegis helm (19 def)<br>Crimson aegis plate (38 def, 27 regen)<br>Crimson aegis legplates (19 def)<br>Crimson aegis sabatons (13 def) | Glacierstrider hood (7 def, 2 mdef)<br>Glacierstrider hauberk (15 def, 4 mdef, 27 regen)<br>Glacierstrider chausses (7 def, 2 mdef)<br>Glacierstrider striders (5 def, 1 mdef) | Wildroot circlet (6 def, 5 mdef)<br>Wildroot leathers (12 def, 10 mdef, 27 regen)<br>Wildroot breeches (6 def, 5 mdef)<br>Wildroot boots (4 def, 3 mdef) | Ashcaller hat (4 def, 9 mdef)<br>Ashcaller robe (9 def, 17 mdef, 27 regen)<br>Ashcaller leggings (4 def, 9 mdef)<br>Ashcaller slippers (3 def, 6 mdef) |
| 40 | Skullcrusher helm (21 def)<br>Skullcrusher plate (42 def, 42 regen)<br>Skullcrusher legplates (21 def)<br>Skullcrusher sabatons (14 def) | Shadowstalker hood (9 def, 2 mdef)<br>Shadowstalker mail (16 def, 5 mdef, 42 regen)<br>Shadowstalker chausses (9 def, 2 mdef)<br>Shadowstalker striders (5 def, 2 mdef) | Verdant spirit hood (6 def, 6 mdef)<br>Verdant spirit hide (14 def, 11 mdef, 42 regen)<br>Verdant spirit breeches (6 def, 6 mdef)<br>Verdant spirit boots (4 def, 4 mdef) | Voidweaver cowl (4 def, 10 mdef)<br>Voidweaver robe (10 def, 19 mdef, 42 regen)<br>Voidweaver leggings (4 def, 10 mdef)<br>Voidweaver slippers (4 def, 6 mdef) |
| 45 | Obsidian bulwark helm (23 def)<br>Obsidian bulwark plate (46 def, 64 regen)<br>Obsidian bulwark legplates (23 def)<br>Obsidian bulwark sabatons (15 def) | Great bear hood (9 def, 3 mdef)<br>Great bear hauberk (18 def, 5 mdef, 64 regen)<br>Great bear chausses (9 def, 3 mdef)<br>Great bear striders (6 def, 2 mdef) | Elder stag crown (8 def, 6 mdef)<br>Elder stag hide (14 def, 13 mdef, 64 regen)<br>Elder stag breeches (8 def, 6 mdef)<br>Elder stag boots (5 def, 4 mdef) | Netherflame cowl (5 def, 11 mdef)<br>Netherflame robe (11 def, 21 mdef, 64 regen)<br>Netherflame leggings (5 def, 11 mdef)<br>Netherflame slippers (4 def, 7 mdef) |

| Tier | Shield (Warrior, Hunter) | Spellbook (Sorcerer, Druid) |
| ---: | --- | --- |
| 1 | Oak buckler (4 def) | Tattered primer (1 def, 1 mdef, 6 mana) |
| 5 | Hide targe (6 def) | Apprentice grimoire (1 def, 2 mdef, 8 mana) |
| 10 | Bronze heater (8 def) | Bound codex (2 def, 3 mdef, 13 mana) |
| 15 | Steel kite shield (10 def) | Runed tome (2 def, 3 mdef, 20 mana) |
| 20 | Silverleaf shield (11 def) | Silverleaf folio (2 def, 4 mdef, 30 mana) |
| 25 | Cobalt tower shield (13 def) | Cobalt codex (3 def, 4 mdef, 47 mana) |
| 30 | Embersteel aegis (15 def) | Ember tome (3 def, 5 mdef, 71 mana) |
| 35 | Duskiron bulwark (17 def) | Dusk grimoire (3 def, 6 mdef, 109 mana) |
| 40 | Starforged bulwark (19 def) | Star atlas (4 def, 6 mdef, 168 mana) |
| 45 | Wyrmglass ward (21 def) | Wyrmglass codex (4 def, 7 mdef, 257 mana) |

| Tier | Warrior | Hunter | Sorcerer | Druid |
| ---: | --- | --- | --- | --- |
| 1 | Copper blade (2 atk) | Willow shortbow (2 atk, 2 crit) | Kindling wand (2 atk, 2 crit) | Sapling rod (2 atk, 2 heal) |
| 5 | Flint hatchet (3 atk) | Yew hunting bow (3 atk, 3 crit) | Spark wand (3 atk, 3 crit) | Thornwood rod (3 atk, 3 heal) |
| 10 | Bronze mace (4 atk) | Bronze recurve (4 atk, 3 crit) | Ember wand (4 atk, 3 crit) | Moss rod (4 atk, 5 heal) |
| 15 | Steel longsword (5 atk) | Steel longbow (5 atk, 4 crit) | Flame wand (6 atk, 4 crit) | Rootbound rod (5 atk, 7 heal) |
| 20 | Silverleaf axe (6 atk) | Silverleaf bow (8 atk, 4 crit) | Silverfire wand (10 atk, 4 crit) | Silverleaf rod (6 atk, 11 heal) |
| 25 | Cobalt warhammer (7 atk) | Cobalt crossbow (12 atk, 5 crit) | Storm wand (15 atk, 5 crit) | Tide rod (7 atk, 17 heal) |
| 30 | Embersteel blade (11 atk) | Ember recurve (18 atk, 5 crit) | Blaze wand (23 atk, 5 crit) | Emberthorn rod (8 atk, 27 heal) |
| 35 | Duskiron cleaver (16 atk) | Dusk longbow (27 atk, 6 crit) | Dusk wand (35 atk, 6 crit) | Duskbloom rod (11 atk, 41 heal) |
| 40 | Starforged maul (25 atk) | Starforged crossbow (41 atk, 6 crit) | Starfire wand (54 atk, 6 crit) | Starbloom rod (17 atk, 63 heal) |
| 45 | Wyrmglass greatsword (38 atk) | Wyrmglass bow (63 atk, 7 crit) | Wyrmglass wand (82 atk, 7 crit) | Wyrmglass rod (25 atk, 96 heal) |

| Tier | Amulet | Cape | Charm | Ring |
| ---: | --- | --- | --- | --- |
| 20 | River pendant (46 hp, 4 mdef) | Silverleaf cape (6 mdef, 18 mana) | Hearth charm (15 regen, 8 heal) | Garnet ring (23 hp, 9 mana, 2 crit) |
| 25 | Cobalt amulet (70 hp, 4 mdef) | Cobalt cape (7 mdef, 28 mana) | Tide charm (23 regen, 12 heal) | Cobalt ring (35 hp, 14 mana, 2 crit) |
| 30 | Ember amulet (107 hp, 5 mdef) | Ember cape (8 mdef, 43 mana) | Cinder charm (36 regen, 18 heal) | Ember ring (53 hp, 21 mana, 2 crit) |
| 35 | Dusk amulet (164 hp, 6 mdef) | Dusk cape (9 mdef, 66 mana) | Dusk charm (55 regen, 27 heal) | Dusk ring (82 hp, 33 mana, 2 crit) |
| 40 | Star amulet (251 hp, 6 mdef) | Starweave cape (10 mdef, 101 mana) | Star charm (84 regen, 42 heal) | Star ring (126 hp, 50 mana, 2 crit) |
| 45 | Wyrmglass amulet (385 hp, 7 mdef) | Wyrmscale cape (11 mdef, 154 mana) | Wyrm charm (128 regen, 64 heal) | Wyrmglass ring (192 hp, 77 mana, 2 crit) |

| Boss | Relics (level 50, bound; one trophy each) |
| --- | --- |
| Vaelith, Sovereign of the Hollow | Voidrend (64 atk); Eclipse bow (107 atk, 9 crit); Starless wand (139 atk, 9 crit); Nightbloom rod (43 atk, 191 heal); Sovereign's mantle (14 mdef, 307 mana) |
| Morvain the Drowned | Abyssal greathelm (30 def, 13 mdef); Abyssal plate (57 def, 26 mdef, 113 regen); Tidebreaker (56 atk); Abyssal ward (26 def) |
| Kharzul the Cinder Colossus | Cinderheart bow (94 atk, 8 crit); Cinderheart wand (123 atk, 8 crit); Molten heart (679 hp, 9 mdef); Cinderheart charm (227 regen, 113 heal) |
| Sylvaine the Hollow Bloom | Bloomheart rod (38 atk, 169 heal); Verdant codex (6 def, 9 mdef, 452 mana); Hollowbloom cape (13 mdef, 271 mana); Bloomsoul ring (339 hp, 136 mana, 3 crit) |

| Elite | Mythic gear (level 50, unbound; chance per kill) |
| --- | --- |
| Ashmaw drake | Drakeforged helm (26 def) 1.5%; Drakeforged plate (53 def, 103 regen) 1.2%; Drakeforged legplates (26 def) 1.5%; Drakeforged sabatons (18 def) 1.5%; Drakefang greatsword (51 atk) 1.2%; Drakescale bulwark (24 def) 1.5%; Emberwing cape (12 mdef, 248 mana) 1.5% |
| Rime titan | Rimeguard coif (11 def, 4 mdef) 1.5%; Rimeguard hauberk (20 def, 7 mdef, 103 regen) 1.2%; Rimeguard chausses (11 def, 4 mdef) 1.5%; Rimeguard striders (7 def, 3 mdef) 1.5%; Rimestring longbow (86 atk, 8 crit) 1.2%; Rimeheart ring (310 hp, 124 mana, 3 crit) 1.5% |
| Barrow lich | Gravecall cowl (7 def, 12 mdef) 1.5%; Gravecall robe (12 def, 24 mdef, 103 regen) 1.2%; Gravecall leggings (7 def, 12 mdef) 1.5%; Gravecall slippers (4 def, 9 mdef) 1.5%; Gravecall wand (112 atk, 8 crit) 1.2%; Gravecall grimoire (6 def, 9 mdef, 413 mana) 1.5%; Gravecall amulet (620 hp, 9 mdef) 1.5% |
| Thornscale basilisk | Thornscale circlet (9 def, 8 mdef) 1.5%; Thornscale hide (17 def, 15 mdef, 103 regen) 1.2%; Thornscale breeches (9 def, 8 mdef) 1.5%; Thornscale boots (6 def, 6 mdef) 1.5%; Thornscale rod (35 atk, 154 heal) 1.2%; Basilisk-eye charm (207 regen, 103 heal) 1.5% |

## Level table (reference class: Hunter)

Champions are dungeon mini-bosses: 10x a normal monster's health, 1.8x its hits, and 25x its experience.

| Level | Player HP | Base atk | Geared atk | Mob HP | Elite HP | Champion HP | Boss HP | Mob hit | Elite hit | Champion hit | Boss hit | Mob XP | Champion XP | XP to next |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 150 | 4 | 5 | 36 | 144 | 360 | 10,680 | 4 | 6 | 8 | 10 | 15 | 375 | 60 |
| 2 | 163 | 4 | 5 | 39 | 157 | 392 | 11,632 | 5 | 7 | 9 | 12 | 16 | 408 | 112 |
| 3 | 178 | 4 | 6 | 43 | 171 | 427 | 12,668 | 6 | 9 | 11 | 15 | 18 | 445 | 180 |
| 4 | 194 | 5 | 6 | 47 | 186 | 465 | 13,797 | 7 | 10 | 13 | 17 | 19 | 484 | 247 |
| 5 | 211 | 5 | 7 | 51 | 203 | 507 | 15,027 | 8 | 12 | 15 | 21 | 21 | 528 | 336 |
| 6 | 230 | 6 | 8 | 55 | 221 | 552 | 16,366 | 10 | 14 | 17 | 24 | 23 | 575 | 437 |
| 7 | 250 | 6 | 8 | 60 | 240 | 601 | 17,824 | 11 | 17 | 20 | 28 | 25 | 626 | 550 |
| 8 | 273 | 7 | 9 | 65 | 262 | 654 | 19,412 | 13 | 19 | 23 | 32 | 27 | 682 | 675 |
| 9 | 297 | 7 | 10 | 71 | 285 | 713 | 21,142 | 15 | 22 | 27 | 37 | 30 | 742 | 840 |
| 10 | 323 | 8 | 11 | 78 | 310 | 776 | 23,026 | 17 | 26 | 31 | 43 | 32 | 808 | 992 |
| 11 | 352 | 9 | 12 | 85 | 338 | 845 | 25,078 | 20 | 29 | 35 | 49 | 35 | 881 | 1,190 |
| 12 | 384 | 10 | 13 | 92 | 368 | 921 | 27,313 | 21 | 32 | 38 | 53 | 38 | 959 | 1,406 |
| 13 | 418 | 10 | 14 | 100 | 401 | 1,003 | 29,746 | 23 | 35 | 42 | 58 | 42 | 1,044 | 1,680 |
| 14 | 455 | 11 | 15 | 109 | 437 | 1,092 | 32,397 | 25 | 38 | 46 | 63 | 46 | 1,138 | 1,978 |
| 15 | 496 | 12 | 17 | 119 | 476 | 1,189 | 35,284 | 28 | 41 | 50 | 69 | 50 | 1,239 | 2,300 |
| 16 | 540 | 13 | 18 | 130 | 518 | 1,295 | 38,428 | 30 | 45 | 54 | 75 | 54 | 1,349 | 2,646 |
| 17 | 588 | 15 | 20 | 141 | 564 | 1,411 | 41,853 | 33 | 49 | 59 | 82 | 59 | 1,470 | 3,068 |
| 18 | 640 | 16 | 21 | 154 | 615 | 1,536 | 45,582 | 36 | 53 | 64 | 89 | 64 | 1,600 | 3,520 |
| 19 | 697 | 17 | 23 | 167 | 669 | 1,673 | 49,644 | 39 | 58 | 70 | 97 | 70 | 1,743 | 4,060 |
| 20 | 759 | 19 | 25 | 182 | 729 | 1,823 | 54,068 | 42 | 63 | 76 | 105 | 76 | 1,898 | 4,636 |
| 21 | 827 | 21 | 28 | 198 | 794 | 1,985 | 58,886 | 46 | 69 | 83 | 115 | 83 | 2,068 | 5,312 |
| 22 | 901 | 23 | 30 | 216 | 865 | 2,162 | 64,133 | 50 | 75 | 90 | 125 | 90 | 2,252 | 6,030 |
| 23 | 981 | 25 | 33 | 235 | 942 | 2,354 | 69,848 | 55 | 82 | 98 | 136 | 98 | 2,453 | 6,860 |
| 24 | 1,068 | 27 | 36 | 256 | 1,026 | 2,564 | 76,072 | 59 | 89 | 107 | 148 | 107 | 2,671 | 7,811 |
| 25 | 1,164 | 29 | 39 | 279 | 1,117 | 2,793 | 82,851 | 65 | 97 | 116 | 162 | 116 | 2,909 | 8,816 |
| 26 | 1,267 | 32 | 42 | 304 | 1,217 | 3,042 | 90,234 | 70 | 106 | 127 | 176 | 127 | 3,168 | 10,033 |
| 27 | 1,380 | 35 | 46 | 331 | 1,325 | 3,313 | 98,275 | 77 | 115 | 138 | 192 | 138 | 3,451 | 11,316 |
| 28 | 1,503 | 38 | 50 | 361 | 1,443 | 3,608 | 107,032 | 84 | 125 | 150 | 209 | 150 | 3,758 | 12,750 |
| 29 | 1,637 | 41 | 55 | 393 | 1,572 | 3,929 | 116,570 | 91 | 136 | 164 | 227 | 164 | 4,093 | 14,432 |
| 30 | 1,783 | 45 | 59 | 428 | 1,712 | 4,279 | 126,958 | 99 | 149 | 178 | 248 | 178 | 4,458 | 16,198 |
| 31 | 1,942 | 49 | 65 | 466 | 1,864 | 4,661 | 138,271 | 108 | 162 | 194 | 270 | 194 | 4,855 | 18,236 |
| 32 | 2,115 | 53 | 71 | 508 | 2,030 | 5,076 | 150,592 | 118 | 176 | 212 | 294 | 212 | 5,288 | 20,564 |
| 33 | 2,304 | 58 | 77 | 553 | 2,211 | 5,528 | 164,012 | 128 | 192 | 230 | 320 | 230 | 5,759 | 23,000 |
| 34 | 2,509 | 63 | 84 | 602 | 2,408 | 6,021 | 178,627 | 139 | 209 | 251 | 348 | 251 | 6,272 | 25,853 |
| 35 | 2,732 | 68 | 91 | 656 | 2,623 | 6,558 | 194,544 | 152 | 228 | 273 | 379 | 273 | 6,831 | 28,938 |
| 36 | 2,976 | 74 | 99 | 714 | 2,857 | 7,142 | 211,880 | 165 | 248 | 298 | 413 | 298 | 7,440 | 32,482 |
| 37 | 3,241 | 81 | 108 | 778 | 3,111 | 7,778 | 230,761 | 180 | 270 | 324 | 450 | 324 | 8,103 | 36,288 |
| 38 | 3,530 | 88 | 118 | 847 | 3,389 | 8,472 | 251,324 | 196 | 294 | 353 | 490 | 353 | 8,825 | 40,595 |
| 39 | 3,844 | 96 | 128 | 923 | 3,691 | 9,227 | 273,720 | 214 | 320 | 384 | 534 | 384 | 9,611 | 45,312 |
| 40 | 4,187 | 105 | 140 | 1,005 | 4,019 | 10,049 | 298,111 | 233 | 349 | 419 | 582 | 419 | 10,467 | 50,699 |
| 41 | 4,560 | 114 | 152 | 1,094 | 4,378 | 10,944 | 324,676 | 253 | 380 | 456 | 633 | 456 | 11,400 | 56,544 |
| 42 | 4,966 | 124 | 166 | 1,192 | 4,768 | 11,919 | 353,608 | 276 | 414 | 497 | 690 | 497 | 12,416 | 63,119 |
| 43 | 5,409 | 135 | 180 | 1,298 | 5,193 | 12,982 | 385,118 | 300 | 451 | 541 | 751 | 541 | 13,522 | 70,330 |
| 44 | 5,891 | 147 | 196 | 1,414 | 5,655 | 14,138 | 419,436 | 327 | 491 | 589 | 818 | 589 | 14,727 | 78,337 |
| 45 | 6,416 | 160 | 214 | 1,540 | 6,159 | 15,398 | 456,813 | 356 | 535 | 642 | 891 | 642 | 16,040 | 87,312 |
| 46 | 6,988 | 175 | 233 | 1,677 | 6,708 | 16,770 | 497,520 | 388 | 582 | 699 | 971 | 699 | 17,469 | 97,161 |
| 47 | 7,610 | 190 | 254 | 1,826 | 7,306 | 18,265 | 541,854 | 423 | 634 | 761 | 1,057 | 761 | 19,026 | 108,062 |
| 48 | 8,288 | 207 | 276 | 1,989 | 7,957 | 19,892 | 590,139 | 460 | 691 | 829 | 1,151 | 829 | 20,721 | 120,205 |
| 49 | 9,027 | 226 | 301 | 2,166 | 8,666 | 21,665 | 642,726 | 502 | 752 | 903 | 1,254 | 903 | 22,568 | 133,644 |
| 50 | 9,831 | 246 | 328 | 2,360 | 9,438 | 23,596 | 700,000 | 546 | 819 | 983 | 1,365 | 983 | 24,579 | max |
| Vocation | Role | HP 1 / 50 | Mana 1 / 50 | Attack 1 / 50 | Healing/s 1 / 50 | Base def |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Warrior | Tank | 225 / 14,747 | 30 / 1,966 | 2 / 147 | 0 / 0 | 35 |
| Hunter | Ranged damage, light healing | 150 / 9,831 | 60 / 3,933 | 4 / 246 | 1 / 39 | 5 |
| Sorcerer | Burst damage | 90 / 5,899 | 96 / 6,292 | 5 / 320 | 0 / 0 | 0 |
| Druid | Healer | 90 / 5,899 | 96 / 6,292 | 2 / 98 | 6 / 393 | 0 |
| Level-50 group | Players | Boss down in | Healing (need 4.4) | Tanks | Result |
| --- | ---: | ---: | ---: | ---: | --- |
| 4 Warrior, 6 Hunter, 6 Sorcerer, 4 Druid | 20 | 240 s | 4.6 | 4 | wins |
| 3 Warrior, 6 Hunter, 6 Sorcerer, 4 Druid | 19 | 248 s | 4.6 | 3 | loses: not enough damage before the 245 s enrage, needs 4 tanks to swap |
| 4 Warrior, 5 Hunter, 6 Sorcerer, 4 Druid | 19 | 254 s | 4.5 | 4 | loses: not enough damage before the 245 s enrage |
| 4 Warrior, 6 Hunter, 5 Sorcerer, 4 Druid | 19 | 259 s | 4.6 | 4 | loses: not enough damage before the 245 s enrage |
| 4 Warrior, 6 Hunter, 6 Sorcerer, 3 Druid | 19 | 246 s | 3.6 | 4 | loses: not enough damage before the 245 s enrage, not enough healing |
| 4 Warrior, 4 Hunter, 8 Sorcerer, 4 Druid | 20 | 232 s | 4.4 | 4 | wins |
| 4 Warrior, 8 Hunter, 6 Sorcerer, 4 Druid | 22 | 216 s | 4.8 | 4 | wins |
| 4 Warrior, 0 Hunter, 10 Sorcerer, 5 Druid | 19 | 246 s | 5.0 | 4 | loses: not enough damage before the 245 s enrage |
| 2 Warrior, 3 Hunter, 3 Sorcerer, 2 Druid | 10 | 480 s | 2.3 | 2 | loses: not enough damage before the 245 s enrage, not enough healing, needs 4 tanks to swap |
| 1 Warrior, 1 Hunter, 1 Sorcerer, 1 Druid | 4 | 1295 s | 1.1 | 1 | loses: not enough damage before the 245 s enrage, not enough healing, needs 4 tanks to swap |

Growth per level: 1.0891. Boss = 356 normal mobs. Reference DPS at level 50: 163.9. Normal kills from 1 to 50: 3,724.
