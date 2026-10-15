# 11 - Rune spells from level 40+ monsters

**Effort:** M-L

## Request
A new kind of spell: a rune item dropped by level 40+ hunt monsters. It is an area damage spell
(fire, lightning or frost). You drag it to the action bar and cast it from there, but it takes a
backpack slot.

## Today
- Spells are learned per vocation (`game/data/spells.gd`) and live on the action bar
  (`game/input/keybinds.gd`, `game/ui/action_bar.gd`); `spell_rune.gd` is only the spell's icon.
- `rune_shard` is a level 40+ drop used for spell ranks.
- The "area_target" spell kind already exists in `Combat.cast`.

## Steps
1. **Items.** Three stackable rune items in `items.json`: `fire_rune`, `lightning_rune`,
   `frost_rune` (`"rune": {"spell": ..., "charges": N}` or one charge per rune in a stack). Any
   vocation, level 40. Frost slows, lightning has a short chain, fire leaves a burning tile; keep
   the first version to plain area damage if the extras grow the scope.
2. **Drops.** Add them to the loot tables of level 40+ hunt monsters (`Monsters.LOOT`) at low
   chances, a little higher on elites.
3. **Casting.** `Combat.use_rune(id, slot_or_kind, target)`: requires the rune in the backpack,
   uses the "area_target" path with power from the rune's level, consumes one, shares a
   "rune" cooldown group so runes cannot be spammed. Damage style "magic" (plan 10).
4. **Action bar.** A bar slot can hold an item kind as well as a spell. Dragging a rune from the
   backpack puts a reference on the bar; the slot shows the count in the backpack and greys out
   at 0. Keybind saves store the reference.
5. **Bots.** Rune use for bots at level 40+ (simple: cast at a group of 3+ monsters).
6. **Balance.** Runes add damage on top of a rotation; check the final-boss raid math and PvP
   burst (maybe runes do reduced damage to players).
7. Art: three rune icons with the `art-direction` skill (glow and saturated colour allowed:
   magic).

## Tests
Unit: dropping, casting consumes one, the bar slot reference survives a save, cannot cast with
none left, cooldown group, damage in the radius.

## Done when
Level 40+ hunts drop runes, and you can cast them from the action bar.
