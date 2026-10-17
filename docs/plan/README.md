# Implementation plans

One file per open item from [docs/ideas/prompts.md](../ideas/prompts.md), in the order we plan to
build them (least effort first, art and world overhauls last). Work through a plan top to bottom,
run its tests, playtest once at the end (the `playtest` skill), commit, then delete the plan file,
its row here, and its line in `prompts.md`.

Every plan has the same parts: the request, what the code does today, the steps, the tests, and
when it is done. **Needs from you** marks plans that wait on a decision. Reference looks for caves, towns,
interiors, cellars, the map and area spells are in the `art-direction` skill.

| # | Plan | Effort | Needs from you |
| --- | --- | --- | --- |
| 23 | [Lanterns flicker when you go near them](23-lantern-flicker.md) | S | Fixes in; confirm in game |
| 24 | [A Verdana-like game font](24-game-font.md) | S | Allow a non-CC0 free font (DejaVu Sans recommended) |
| 26 | [Balance pass for the new gear stats](26-gear-stat-balance.md) | M | |
| 25 | [More spells for every ten levels](25-spell-brackets.md) | L | Spells, runes, or both; approve the list |
| 39 | [Classic-style icons for the remaining item families](39-icon-families.md) | L | |
| 38 | [Bring the old tiles up to the new art style](38-art-style-pass.md) | L | |
| 20 | [Sound engine](20-sound-engine.md) | L | Choice of CC0 sounds |
| 21 | [Rare mini-bosses](21-mini-bosses.md) | L | Later, when the game is stable |
| 22 | [Outfits from quests](22-quest-outfits.md) | M-L | Later |
| 32 | [Continents with one major and one smaller city](32-continents-and-cities.md) | XL | Which mainland towns stay |

Build 26 after any plan that adds gear stats (25's runes and spells change the same sims), and 39
family by family between other plans. 38 and 32 both repaint the world, so do 38 first.

Always: typed GDScript, lint clean, rules covered in `tests/unit/rules_test.gd`, a visual-test
capture for art (the `art-direction` skill), and the docs (`docs/gameplay.md`, `docs/balance.md`,
`docs/art.md`) updated in the same commit.
