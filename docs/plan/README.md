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
| 20 | [Sound engine](20-sound-engine.md) | L | Choice of CC0 sounds |
| 21 | [Rare mini-bosses](21-mini-bosses.md) | L | Later, when the game is stable |
| 22 | [Outfits from quests](22-quest-outfits.md) | M-L | Later |
| 31 | [Walls that serve no purpose](31-purposeless-walls.md) | S-M | - |
| 32 | [Continents with one major and one smaller city](32-continents-and-cities.md) | XL | Which mainland towns stay |
| 35 | [More monsters in empty spots, slower respawns](35-more-camps.md) | M | - |
| 36 | [Epic and legendary gear only from bosses and quests](36-rare-grades.md) | S-M | - |
| 37 | [The Cyclops Hollow: a 75-kill hunt](37-cyclops-cave.md) | M | - |

Build 18-19 together, and 24-25 together (the new monsters feed the new tasks) (the swamp is one of the
biomes). 09 can ship with 10 if that is simpler, since both change warrior play.

Always: typed GDScript, lint clean, rules covered in `tests/unit/rules_test.gd`, a visual-test
capture for art (the `art-direction` skill), and the docs (`docs/gameplay.md`, `docs/balance.md`,
`docs/art.md`) updated in the same commit.
