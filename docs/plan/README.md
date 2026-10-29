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
| 48 | [Direction: art from the pack, code split into components](48-components.md) | XL | Step order |
| 49 | [All art from the OpenTibia sprite pack: items, outfits, creatures, world](49-opentibia-art.md) | XL | Review each phase's renders |
| 47 | [The world plan: the frame frozen, every landmass and floor listed](47-world-plan.md) | S | New capital and town names; Frostvault's home |
| 46 | [Direction: modern-Tibia feel (art, world, floors, hunts, quests)](46-modern-tibia-direction.md) | XL | Private Tibia reference screenshots; loot questions |
| 20 | [Sound engine](20-sound-engine.md) | L | Choice of CC0 sounds |
| 21 | [Rare mini-bosses](21-mini-bosses.md) | L | Later, when the game is stable |
| 22 | [Outfits from quests](22-quest-outfits.md) | M-L | Later |
| 45 | [Floors follow-up: map floors, road speed, markers, old caves below](45-floors-follow-up.md) | L | Review in game; four caves left to fit |
| 44 | [The floor below: tunnels and sewers under the mainland](44-underground-floor.md) | L | Review in game |
| 43 | [The mainland doubled: 640 x 640, levels 1-30](43-mainland-growth.md) | L | Review in game |
| 42 | [Loot in valuables, cave rock, castle dungeons](42-loot-caves-castle-dungeons.md) | L | |
| 41 | [Performance: baked map, spaces, dormant camps](41-performance-spaces.md) | L | |
| 40 | [The archipelago: biome islands with castle capitals](40-archipelago.md) | XL | Review each island |

Plan 48 (2026-10-29) freezes art: no plan draws or repaints sprites; plans 38 and 39 are closed.

Always: typed GDScript, lint clean, rules covered in `tests/unit/rules_test.gd`, a visual-test
capture for art (the `art-direction` skill), and the docs (`docs/gameplay.md`, `docs/balance.md`,
`docs/art.md`) updated in the same commit.
