# 30 - Endgame titles

**Effort:** M

## Request
Titles earned by the endgame quests you have completed, like Tibia's promoted vocations shown
in its highscores (Elite Knight, Royal Paladin, Master Sorcerer, Elder Druid).

## Today
Characters have a vocation (Warrior, Hunter, Sorcerer, Druid) chosen at the training hall. The
endgame has the final bosses with relic keepers, the Hunters' Lodge chain, the elite caves and
their champions, and the Void Throne. Nothing records an endgame rank.

## Steps
1. **Titles as data** (`game/data/titles.gd`): an ordered ladder per vocation with original
   names (for example a Warrior becomes Vanguard, then Warlord; a Hunter Pathwarden, then
   Huntmaster; a Sorcerer Magister, then Archmage; a Druid Wildwarden, then Archdruid), each
   with its requirement: level, finished tasks (the Lodge chain, every elite cave champion), and
   final boss trophies.
2. **Earning them**: checked on task turn-in and trophy award; a message and a small effect.
   Saved with the character (save version 3).
3. **Showing them**: in the character window, the nameplate tooltip, the party window, and the
   highscore-like list of players on the host (Controls window), with the title in its colour.
4. Optional small perk per title (cosmetic only, like a nameplate colour).

## Tests
Unit: each title's requirements; earned once; saved and restored; shown in the character
window state.

## Done when
Endgame players carry a title that shows what they have done.
