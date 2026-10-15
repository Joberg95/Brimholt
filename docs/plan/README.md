# Implementation plans

One file per open item from [docs/ideas/prompts.md](../ideas/prompts.md), in the order we plan to
build them (least effort first, art and world overhauls last). Work through a plan top to bottom,
run its tests, playtest once at the end (the `playtest` skill), commit, then delete the plan file,
its row here, and its line in `prompts.md`.

Every plan has the same parts: the request, what the code does today, the steps, the tests, and
when it is done. **Needs from you** marks plans that wait on reference images or a decision.

| # | Plan | Effort | Needs from you |
| --- | --- | --- | --- |
| 01 | [Tibia-style doors and house walls](01-doors.md) | S (finishing) | A look in game |
| 02 | [Vendor list keeps its scroll](02-vendor-scroll.md) | S | |
| 03 | [Less gold](03-gold-gain.md) | S | |
| 04 | [Gathering yields 1-5, fewer nodes](04-gathering-yield.md) | S | |
| 05 | [Tighter monster groups of 5-7](05-mob-density.md) | S | |
| 06 | [Bots level alongside you](06-bot-leveling.md) | S-M | |
| 07 | [One cellar hole per entrance](07-cellar-entrances.md) | M | Hole references (optional) |
| 08 | [Performance pass](08-performance.md) | M | |
| 09 | [Single-target warrior taunt](09-warrior-taunt.md) | S-M | |
| 10 | [Armor types, new stats, class counters](10-armor-and-class-counters.md) | L | |
| 11 | [Rune spells from level 40+ monsters](11-rune-spells.md) | M-L | |
| 12 | [World map: arrow, quest guidance, new look](12-world-map.md) | M | |
| 13 | [Bigger cellars and caves](13-cellars-and-caves.md) | L | Cellar references |
| 14 | [Open Redmeere with castle houses](14-redmeere.md) | L | Castle house references |
| 15 | [House decorations](15-house-decorations.md) | M-L | Decoration references |
| 16 | [Town design and cobblestone streets](16-town-design.md) | M-L | |
| 17 | [World textures overhaul](17-world-textures.md) | L | Tile references |
| 18 | [Biomes and the void gateway](18-biomes-and-void-gateway.md) | XL | |
| 19 | [Swamp zone, levels 35-50](19-swamp-zone.md) | L | |
| 20 | [Sound engine](20-sound-engine.md) | L | Choice of CC0 sounds |
| 21 | [Rare mini-bosses](21-mini-bosses.md) | L | Later, when the game is stable |
| 22 | [Outfits from quests](22-quest-outfits.md) | M-L | Later |

Build 13-17 once the reference images are in, and 18-19 together (the swamp is one of the
biomes). 09 can ship with 10 if that is simpler, since both change warrior play.

Always: typed GDScript, lint clean, rules covered in `tests/unit/rules_test.gd`, a visual-test
capture for art (the `art-direction` skill), and the docs (`docs/gameplay.md`, `docs/balance.md`,
`docs/art.md`) updated in the same commit.
