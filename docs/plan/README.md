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
| 08 | [Performance pass](08-performance.md) | M | |
| 09 | [Single-target warrior taunt](09-warrior-taunt.md) | S-M | |
| 10 | [Armor types, new stats, class counters](10-armor-and-class-counters.md) | L | |
| 11 | [Rune spells from level 40+ monsters](11-rune-spells.md) | M-L | |
| 12 | [World map: arrow, quest guidance, new look](12-world-map.md) | M | |
| 13 | [Bigger cellars and caves](13-cellars-and-caves.md) | L | References in the art skill |
| 14 | [Open Redmeere with castle houses](14-redmeere.md) | L | References in the art skill |
| 15 | [House decorations](15-house-decorations.md) | M-L | References in the art skill |
| 16 | [Town design and cobblestone streets](16-town-design.md) | M-L | |
| 17 | [World textures overhaul](17-world-textures.md) | L | References in the art skill |
| 18 | [Biomes and the void gateway](18-biomes-and-void-gateway.md) | XL | |
| 19 | [Swamp zone, levels 35-50](19-swamp-zone.md) | L | |
| 20 | [Sound engine](20-sound-engine.md) | L | Choice of CC0 sounds |
| 21 | [Rare mini-bosses](21-mini-bosses.md) | L | Later, when the game is stable |
| 22 | [Outfits from quests](22-quest-outfits.md) | M-L | Later |

Build 18-19 together (the swamp is one of the
biomes). 09 can ship with 10 if that is simpler, since both change warrior play.

Always: typed GDScript, lint clean, rules covered in `tests/unit/rules_test.gd`, a visual-test
capture for art (the `art-direction` skill), and the docs (`docs/gameplay.md`, `docs/balance.md`,
`docs/art.md`) updated in the same commit.
