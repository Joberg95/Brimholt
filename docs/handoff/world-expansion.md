# Handoff: Tibia-sized world, GPU terrain, uncapped levels

Paste this file into a new agent session (or point the agent at it) to take over the world
expansion. Read `.github/copilot-instructions.md`, `docs/architecture.md`, and the repository
skills it names (`godot-gameplay`, `godot-validation`, `art-direction`, `feature-playtest`) first.

## Your task

Grow Brimholt's world to the size of Tibia's, built the way the Godot engine handles large tile
worlds well, and finish moving the floor tiles to the shaded art style drawn by GPU shaders. Work
through the four phases below in order. Verify each phase once at its end (lint and unit tests
while building; visual, bench, soak, and playtest in the final pass of the phase) and then stop
and report to the owner before starting the next phase.

## Decisions the owner has made (do not revisit)

- **Size:** the overworld becomes **1920×1920 tiles** (5× each side of today's 384×384), "large as
  Tibia".
- **Heartland:** today's map (mainland 384×384 plus the frost isles south of it) stays in the
  **north-west corner with coordinates unchanged**. New regions grow **east and south**, higher
  level the further out they are. Unpainted overworld is deep sea.
- **Levels:** uncapped like Tibia. Gear tiers and bosses continue to about **level 100**;
  experience keeps working beyond that.
- **Tiles:** both a **shaded hand-pixelled redraw** of every floor tile **and** GPU shaders
  (blended edges, movement). The shader half is done (see below).
- **Engine best practice:** the map must not stay one giant scene; split it into sectors and
  stream the world map in pages.

## Working rules for this repository

- Work in place in `~/repos/Brimholt` on branch `rl-pvp-bots`. **No worktrees**, no new branches,
  no stash/reset/rebase unless the owner asks.
- Commit only when the owner asks. Commit as Joberg95 (the configured git identity) and **without**
  a `Co-authored-by` trailer.
- Push only when asked. `GH_TOKEN` in the environment belongs to a work account that gets 403, so
  push with the owner's personal login:

  ```sh
  T=$(env -u GH_TOKEN gh auth token --user Joberg95)
  git -c credential.helper= -c "credential.helper=!f() { echo username=Joberg95; echo password=$T; }; f" push
  ```

- `game/maps/overworld.tscn` is hand-edited in the Godot editor and is the source of truth. Never
  run `make map-force` / `make_map.gd --force`. Generators must keep existing edits.
- Tibia is the design reference: imitate its look closely, but draw every pixel here; never copy
  its files, maps, or code, and never use its names.
- Keep tests off the real saves (`--no-save`, `--fresh-identity`, `--save-dir`).
- Typed GDScript everywhere (typed loop variables too, or lint fails). Probe scripts must live under
  `res://` (for example `tools/_probe.gd`); delete them afterwards.
- Godot is `~/.local/bin/godot` (4.5+, gl_compatibility renderer). There is no PIL; use `sips` for
  image conversion.

## Validation commands

| Command | What it covers | Baseline |
| --- | --- | --- |
| `make lint` | Parses every script with strict warnings | 124 scripts, 0 failed |
| `make test-unit` | Deterministic rules | 1309 checks, 0 failures (two ERROR lines about JSON/format are pre-existing noise) |
| `make test-visual` | Offscreen captures; report in `.tools/visual-report.html` | PASS |
| `make bench` | Frame times in town, hunt, raid | Record before and after phase 1 |
| `make soak` | Object/node/memory growth | Memory growth warning is pre-existing |
| `make test-lan` | Real ENet scenarios | One persistence flake is pre-existing |
| `make playtest` | Two-bot playthrough, ~5 min | Read the findings, not only pass/fail |

Spot screenshots:
`~/.local/bin/godot --position 99999,99999 --resolution 64x64 --path . --script res://tools/testing/shot.gd -- 22,72 208,186`
writes `.tools/shot-22-72.png` and so on. Good sample cells: pier 19,48; sand and sea 22,72; road
208,186; town street 331,105; bog 313,176; shore 253,196.

## State when this was handed over

### Done: GPU terrain renderer (committed with this file)

- `game/render/terrain.gdshader` draws floors. `game/render/floor_layer.gd` builds one RGBA8
  data texture per 16×16-tile chunk (one texel per cell plus a one-cell border) and draws it as a
  single rect with a shared ShaderMaterial (uniforms `tiles`, `curb_tile`, `water_tile`,
  `edge_reach` 6, `edge_wander` 5). Two chunks are built per frame, visible ones first.
- Texel encoding from `SpriteArt.floor_texel(cell)`:
  - R: base tile index in `tiles.png` (`NO_TILE` 255 = void, drawn black).
  - G: overlay tile (pier planks, a building's floor beside its wall) or `NO_TILE`.
  - B: overlay quarters in bits 0–3, kerb sides as `16 << side` (EDGES order).
  - A: `SpriteArt.floor_blend`: priority from `FLOOR_PRIORITY` plus the flags `BLEND_WATER` (16)
    and `BLEND_SWAY` (32). Water 1, bog 2, dusk/cave 3, sand 4, gravel 5, dirt 6, snow 7, grass 8.
    Built floors are 0 and keep hard edges and exact texels (the visual test compares obsidian
    texels exactly).
- The shader does priority edge blending with two-octave pixel noise and a darkened lip on the lower
  ground, rounded fillets in concave corners, animated water (frames, glints, swell, breathing
  shore foam), and a 1 px grass lean in gust bands, all from `TIME`.
- The old `water.gdshader` was removed. `docs/architecture.md` describes the new path.

### Not done: sectors and world size (phase 1 core)

A first attempt was cancelled partway. Its partial diff is in
`docs/handoff/world-sectors-wip.patch`. It is **not applied** because on its own it breaks the game:
it moves the dungeon/cave band constants without moving the painted cells, and it removes
`Atlas.to_map`/`from_map`/`SIZE`, which `game/ui/world_maps.gd` and `tools/generators/world_map.gd`
still use. Treat it as a sketch of the intended constants:

- `Atlas.OVERWORLD_SIZE = Vector2i(1920, 1920)`, `Atlas.SECTOR = 128`, `sector_of`, `sector_rect`,
  `CONTINENTS` instead of `SHEETS`.
- `Dungeons.BAND_X = Atlas.OVERWORLD_SIZE.x + COPY_GAP`, `BAND_END = BAND_X + 192`.
- `Caves.BAND_X = Dungeons.BAND_END + 44` (past the Void Throne arena: 36 columns plus a gap of four
  on either side).

Today: `World.GRID` is about 682×560 (mainland 384×384, frost isles at `Biomes.ISLES` =
`Rect2i(0, 424, 160, 128)`, `Dungeons.BAND_X` 388 to `BAND_END` 580, the Void Throne past that,
`Caves.BAND_X` 624). `World.OVERWORLD` is computed in `World._static_init` (~line 329) as everything
left of `Dungeons.BAND_X - COPY_GAP`. `overworld.tscn` is about 3.8 MB. The world map
(`Atlas.SHEETS`) currently draws the isles west of the mainland; with the new layout every continent
should appear where it really lies.

## Phase 1: engine foundation (finish this first)

1. **Move the bands.** Write a one-time generator (pattern: the other `tools/generators/*.gd`
   passes plus a `make` target) that moves every dungeon, the Void Throne arena, and every cave from
   their current columns to the new bands past x = 1924. It has to carry terrain cells, all markers
   (spawns, items, ferrymen, stairs/portals, zones, monster spawns), and anything that refers to
   cells in those bands: `Dungeons`, `Caves`, `game/core/instances.gd`, quests, and the tests. It must
   be safe to re-run.
2. **Grow the overworld to 1920×1920.** Cells inside `Atlas.OVERWORLD_SIZE` that nobody painted
   read as deep sea `~` (impassable), so the heartland plays exactly as before.
3. **Sectors.** Split the terrain into 128×128 sector scenes `game/maps/sectors/<sx>_<sy>.tscn`
   (each a TileMapLayer sharing `game/maps/terrain.tres`; only sectors that have land need a file).
   `overworld.tscn` keeps the marker nodes and instances the sectors, so the editor still shows one
   world. Add `tools/generators/map_io.gd` (load/save cells and markers across sectors) and port
   every generator to it. `World._static_init` fills `GRID` from the sectors; the join handshake
   hash must still cover all terrain.
4. **World map pages.** Bake the world map per sector (`assets/sprites/world_map/<sx>_<sy>.png`)
   with an identity placement (map tile = world cell), and make `game/ui/world_maps.gd` load pages
   lazily around the view. Update the minimap, `tools/generators/world_map.gd`, and `make world-map`.
5. **Bench at 1920×1920.** Measure load time, memory, frame time, host tick, and handshake size
   before and after. Floors already only build visible chunks, but check `World.GRID`,
   `REGION_GRID`, monster sleeping (`World.occupied_cells`, 16-tile chunks), and anything that loops
   over the whole grid.
6. **Docs.** Update `docs/architecture.md`, `docs/art.md`, `README.md`, the godot-gameplay skill
   (it still says 384×384, with dungeon copies to the right), and `.github/copilot-instructions.md`
   (384×384 overworld) to the new layout.
7. **Clean up:** `DIRT_EDGE_TILE`, `SHORE_TILE`, and `SAND_EDGE_TILE` in `sprite_art.gd` (and their
   cells in `tiles.png` / `make_sprites.py`) are no longer drawn now that the shader blends edges.
   Remove them unless something else still needs them.

## Phase 2: floor tile art redraw (follow the `art-direction` skill)

Redraw every floor tile by hand in the shaded style: grass, dirt, sand, gravel, cobble, snow, bog,
cave, cellar, planks, obsidian, dusk, water, stairs, and holes. Use five-tone ramps, light from the
top-left, and material detail, with at least four variants each. `tiles.png` is 128×608, four tiles
per row, with index constants in `sprite_art.gd` (~lines 146–185). Keep tiles seamless, because the
shader blends their edges with noise. Check obsidian against the exact-texel visual test, and do
the side-by-side review the skill asks for.

## Phase 3: uncapped progression

- Continue the `game/data/balance.gd` curves past 50 (experience, health, damage, mana, regen) and
  regenerate `docs/balance.md` with `tools/generators/balance_table.gd`.
- `MAX_LEVEL` (50) is used in about 35 places, including the UI. Make level 100 a soft content cap
  (experience keeps working past it). `zone.gd`'s `max_level` has `@export_range(1, 50)`.
- Add gear tiers 11–20 (one every five levels to 100) as `game/data/items.json` rows, deriving stats
  from `items.gd`, with art from the icon-art and visible-equipment pipelines. Add monsters for
  levels 50–100 and a boss per band, with numbers derived from `balance.gd`.
- Revisit the level-50 assumptions: relics, raid gating, the Hollow Reach, the 700,000-health final
  boss, and party window text.

## Phase 4: new regions (one at a time, owner reviews each)

Grow regions east and south of the heartland, higher level the further out. Each region gets:

- a biome
- a safe town (zone flagged `town`) with coach and ferry links
- hunting camps
- an instanced dungeon
- a boss
- quests

Build each region with a generator pass that keeps existing edits (like
`tools/generators/endgame_zone.gd`), then let the owner paint it in the editor. Re-bake the world
map pages afterwards.
