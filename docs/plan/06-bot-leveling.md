# 06 - Bots level alongside you

**Effort:** S-M

## Request
Do the bots level as you do, or only when a new game is made? Check they follow the game's curve
alongside your team and other groups.

## Today
- Companions (`game/core/bots.gd`, stance "companion") copy their leader's level and gear tier.
- Rival bands (`Solo._level_band` in `game/core/solo.gd`) are set to your level plus an offset
  between errands: the level is written directly, experience reset to 0, gear from `Bots.gear`.
- Hunter bots on a LAN host: unknown whether kills give them experience and levels. Check.
- Saves: check whether `CharacterStore` keeps anything for bots or they are recreated each game.

## Steps
1. Write down what each stance does today, as a short table in `docs/gameplay.md`.
2. Rule: bots earn real experience from kills and tasks like players (they already use the real
   rules). Companions and rivals are kept within a band around the leader (for example 2 levels
   behind to 2 ahead) instead of being set exactly.
3. Level-ups go through the same path as players (experience -> level -> stats, spells, gear
   upgrade), and the experience reset goes away.
4. Rival bands level while you are away from them.

## Tests
Unit: a rival bot that kills monsters gains experience and levels; a companion stays within the
band. Soak: bots' levels rise over a run.

## Done when
Bots visibly level during a session at about the player's pace, and the doc says how.
