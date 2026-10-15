# 22 - Outfits from quests

**Effort:** M-L  **When:** later

## Request
Outfits earned from quests.

## Today
Painted full-figure outfits are tied to armor items: an armor with an `"outfit"` key in
`game/data/items.json` (for example Golden lion plate, Windrider mail, Spiritbloom leathers)
replaces the body layers while worn (`SpriteArt.OUTFITS`, imported from `art/outfits` by
`tools/generators/import_outfits.gd`). There are no outfits separate from armor.

## Steps
1. **Cosmetic outfits.** An outfit becomes something you own, not only something you wear:
   `player["outfits"]` (saved in `CharacterStore`), and a chosen outfit that overrides the look
   of your armor without changing stats. Outfit armor items keep working as today.
2. **Rewards.** Quest chains and boss tasks in `game/data/quests.gd` can reward an outfit
   (`"outfit": id` in the reward). One outfit per vocation per major chain to start, plus
   addons (helmet or cape variants) from harder tasks, Tibia-style but original.
3. **Choosing.** An Outfit tab in the character window: owned outfits, a preview with your
   colours, and "Wear" / "Show armor".
4. **Art.** New painted outfits through the existing import pipeline (`make outfits`), one at a
   time, with the `art-direction` skill.
5. Bots: rival bands wear outfits matching their level, so you can recognise strong groups.

## Tests
Unit: a reward grants the outfit; owned outfits survive save and load; wearing one changes the
look but not the stats.

## Done when
Finishing chosen quests unlocks outfits you can wear from the character window.
