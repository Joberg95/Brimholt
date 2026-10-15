# 09 - Single-target warrior taunt

**Effort:** S-M

## Request
A warrior taunt that targets one enemy, to take its focus off another player.

## Today
Warriors have **Challenge** (`game/data/spells.gd`, kind "taunt", level 20, radius 2): every
monster around the caster turns to them (`Combat`, the "taunt" case). There is no single-target
taunt.

## Steps
1. New spell **Provoke** (kind "taunt_target", warrior, about level 8, short cooldown, range 4):
   sets the target monster's `target` to the caster and holds it for a few seconds
   (`taunted_until`), so monster AI does not switch straight back.
2. Monster AI in `Combat` respects `taunted_until` when choosing a target. Bosses included.
3. PvP: monsters only at first. Forcing a player's target is a later decision.
4. Bots: companion warriors cast Provoke when a monster attacks a party member who is not a
   warrior (a LimboAI task like the loot tasks).
5. Spell book text, rune art, `docs/gameplay.md`.

## Tests
Unit: Provoke turns the target onto the warrior and holds it for the duration, works on a boss,
respects the cooldown; a companion warrior provokes a monster hitting its leader.

## Done when
A warrior can pull one monster off a healer, and companion warriors do it on their own.
