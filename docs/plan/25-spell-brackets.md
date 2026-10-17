# 25 - More spells for every ten levels

**Effort:** L

## Request
More spell variety for each tenth-level bracket: brainstorm what to add, or make endgame spells
rune based so the really high-damage spells come from runes.

## Today
Spells (`game/data/spells.gd`) by class and level:

| Class | 1 | 8-15 | 20 | 30 | 40 | 45-50 |
| --- | --- | --- | --- | --- | --- | --- |
| Warrior | Brutal blow, Light heal | Provoke 8, Whirling strike 10 | Challenge, Rending cut | Sundering blow | Earthshaker | none |
| Hunter | Piercing shot, Light heal | Holy mend 8, Crippling arrow 12, Arrow volley 15 | none | Radiant arrow | Sunlance barrage | none |
| Sorcerer | Ember bolt, Light heal | Flame wave 10 | Arc lightning | Firestorm | none | Starfall 45 |
| Druid | Frost bolt, Mend, Mass mend, Light heal | Entangling roots 12, Thorn lash 15 | none | Hailstorm | Wild growth | none |

Four runes exist: Fire, Frost, Lightning (level 40) and Homeward (30). Gear can now add frost damage
(`Combat.ELEMENT_STATS`), life leech, speed, and mana percent.

## Two directions
- **More spells per bracket.** Every class gets one spell in each empty bracket (20, 40, 50), each
  with a job the class lacks: a Warrior self-heal or damage-reduction stance, a Hunter haste and
  a pet-free sustain, a Sorcerer mana shield and a single-target finisher, a Druid ally haste and
  an ice wall. Cooldowns and mana from `Balance`, like today.
- **Runes for the big damage.** Spells stay utility and steady damage; the heaviest hits come from
  runes crafted or bought from level 40 (a great fireball area, a sudden-death single target, an
  ice wave), so damage costs supplies and gold, as in classic play. Runes already exist
  (`Combat.use_rune`, `Spells.RUNES`), so this is new rows plus balance.

**Recommendation: both, split by job.** Fill every empty bracket with one class spell that adds a
new *kind* of play (heal, shield, haste, control), and put the two strongest damage effects of the
40-50 range on runes every class can use, gated by level. Damage spells keep scaling with spell
ranks, so nothing old is lost.

## Needs from you
Pick the direction (or the recommendation), then approve the spell list below.

## Proposed list (to confirm)
| Class | Level | Spell | Job |
| --- | --- | --- | --- |
| Warrior | 50 | Iron bulwark | Takes 30% less damage for 6 s, long cooldown |
| Hunter | 20 | Fleetfoot | 30% movement speed for 8 s |
| Hunter | 50 | Hunter's mark | Target takes 15% more damage from the party for 10 s |
| Sorcerer | 40 | Mana ward | Damage drains mana before health while active |
| Sorcerer | 50 | Soulfire | Single-target finisher, more damage below 30% target health |
| Druid | 20 | Swift growth | Haste for a party member |
| Druid | 50 | Glacier wall | Blocks three tiles for 5 s |
| Runes (all) | 45 | Great fireball rune | Large fire area |
| Runes (all) | 50 | Sudden death rune | Heavy single-target damage |

## Steps
1. Settle the list, then add each spell to `Spells.SPELLS` (rune, name, vocations, level, kind,
   power, mana, cooldown, group, colour) and any new `kind` to `Combat.cast`.
2. New kinds: `buff_self` (damage reduction, speed), `mark` (damage taken debuff), `mana_shield`,
   `wall` (temporary blocking tiles in `World`), `execute` (bonus below a health share).
3. Rune stones for the new spells and runes (`rune_stone`, `spells.png`), effects in `rune_fx`.
4. Balance with `fight_sim.gd` and `duel_sim.gd`; regenerate `docs/balance.md`.

## Tests
Unit checks per new kind (effect, duration, cooldown, mana), every class has a spell in every
bracket, runes gated by level; the visual test casts one of each.

## Done when
Every class has a new spell in each empty bracket, the endgame runes exist, and the sims stay in band.
