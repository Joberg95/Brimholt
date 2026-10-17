# 26 - Balance pass for the new gear stats

**Effort:** M

## Request
(From the showpiece gear work, 2026-10-16/17.) The new gear-only stats were added without running
the balance simulations: movement speed, life leech, maximum mana in percent, and frost damage.

## Today
- `World.GEAR_STATS`: `speed` (steps take `1 / (1 + speed%)`, stacking with mounts), `mana_percent`,
  `frost` (frost spells and runes), `leech` (share of damage dealt healed, capped at
  `World.LEECH_MAX` 5%).
- Sources: showpiece boots (speed 4-10%, mana 6-8%), axes (speed 4%), the Rootbound crown (frost
  9%), and four leeching swords (1-5% by level, `Items.leech_for`).
- Focus pieces trade 15% of armour or 10% of weapon attack for their bonus.

## Steps
1. Extend `tools/testing/fight_sim.gd` and `duel_sim.gd` with gear loadouts that use the new stats:
   a Warrior with the Bloodvein greatblade vs the plain tier sword, a Druid with the crown vs the
   tier hood, Hastewind boots in a duel.
2. Check solo sustain (life leech should let a Warrior hunt longer, not forever), PvP chase
   (speed stacking with a mount must not make a player uncatchable), and caster mana pools.
3. Adjust the numbers in one place each (`LEECH_LEVELS`, `WEAPON_FOCUS_SPEED`, the boots' `extra`,
   `HELMET_FOCUS_DEFENSE`) and record the reasoning in `docs/balance.md`.

## Tests
Sim results within the bands `docs/balance.md` sets; unit checks for any changed caps.

## Done when
Each new stat has a sim result in `docs/balance.md` and the numbers are tuned or confirmed.
