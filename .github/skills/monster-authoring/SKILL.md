---
name: monster-authoring
description: Use when adding or changing a Brimholt monster (overworld, dungeon, elite, champion, or boss): its catalog row, loot table and materials, sprite look, map or dungeon placement, chase and leash behaviour, and balance checks with the fight simulator.
---

# Monster authoring

Every monster follows one model, so a new one fits the existing balance with no hand-tuned
numbers. The rules check (`_monster_catalog_checks` in `tests/unit/rules_test.gd`) enforces
the contract below. Consult the gameplay and validation skills for wider rules.

## 1. Catalog row (`game/data/monsters.gd`, `MONSTERS`)

```gdscript
"black_cat": {"name": "Black cat", "look": "outfit", "outfit": 1, "color": Color("#a08566"), "size": 1.0,
	"rank": "normal", "range": 1, "step": 0.6},
```

- **id**: snake_case and unique. **name**: original, never a Tibia name, even when the monster imitates a Tibia one closely.
- **rank**: a `Balance.RANKS` key.
  - `normal` for field monsters.
  - `elite` for tough overworld guards (×4 health, ×1.5 hits, ×5 experience).
  - `champion` for a dungeon's final room (×10, ×1.8, ×25; always drops tier gear).
  - `boss` only for level-50 raid bosses. A boss also needs `relics` (four or more bound
    quest rewards, see `Combat.claim_relic`) and a slow `respawn`.
- **No numbers of your own**: health, damage, experience, gold, and gear drops come from
  `game/data/balance.gd`, using the spawn's level and the rank. Never add `health`, `damage`,
  `experience`, `attack`, `defense`, or `level` to the row.
- **range**: 1 for melee; 3–5 for ranged attackers (they fire a missile and need line of
  sight). Ranged monsters hit as hard as melee ones, so keep them rarer in a camp.
- **step**: the idle and walk-home pace, 0.3–0.8 s per tile (slow brutes 0.6–0.7, beasts
  0.3–0.45).
  - Chasing always uses `Balance.chase_seconds(monster_level, target_level)` instead: 0.17 s
    per tile at even level (a touch faster than a player's 0.18 s), down to 0.13 s when the
    monster outlevels its target by 10 or more.
  - So `step` never makes a monster kitable.
- **look** is `"outfit"` and **outfit** an OpenTibia pack creature looktype (plan 49: monsters are
  the pack's creatures only; see `docs/art.md`). A normal monster is one pack creature, and its
  levels come from the spawn markers, so place an existing creature before adding a new one.
  Elites, champions, and bosses wear a pack creature larger. `color` is kept for the lexicon.
- **size**: scales the sprite, 0.4–2.0.
- Optional **glow**: a `Color` halo and light, for bosses and magical creatures only.
- Only the fields above are allowed; the check rejects anything else.

### A new creature

Only the pack's creatures exist (`tools/generators/otsp_export.py outfits` exports every `outfit` the
catalog names). Do not draw new monster art.

## 2. Loot (`Monsters.LOOT`)

```gdscript
"black_cat": [["glowcap", 0.08]],
```

- Every monster has an entry, which may be `[]`. Each `[item, chance]` rolls independently,
  with the chance in (0, 1].
- Gold piles and tier gear (`Combat.GEAR_DROP_CHANCE`, by rank) are added automatically.
- Monster materials and trophies were deleted with their art (plan 49): loot is valuables (added
  automatically), potions, runes, rune shards, and named gear. A new item needs a pack sprite (the
  `icon-art` skill).
- Named hunting weapons are `loot_only` items at 2–5% (12–18% on champions), gated by the
  monster's level.
- Relics are never loot.

## 3. Placement

- **Overworld**: add a `MonsterSpawn` marker under `MonsterSpawns` in
  `game/maps/overworld.tscn`, using the Godot editor.
  - Set `monster`, `level`, `count` (usually 3; elites 1–2) and `radius`.
  - Keep spawns out of towns and at least 7 steps from roads.
  - Levels follow the world's gradient (see `docs/gameplay.md`).
  - Do not regenerate the map to place monsters.
- **Dungeon**: add a symbol to a layout in `game/data/dungeons.gd` and to its `monsters`
  legend (`symbol: [id, level]`, within the dungeon's level range). Then run `make dungeons`.
- The check fails if a monster is never placed.

## 4. Behaviour you get for free

- Aggro within `Monsters.AGGRO_RANGE` (3 tiles), so players can pull from a camp's edge; it
  gives up beyond `Monsters.CHASE_RANGE` (12 tiles).
- Chasing at chase speed, along real paths.
- An auto-attack every 2 s.
- A reset when the target reaches a town, is dragged more than `Monsters.LEASH` (12 tiles)
  from the monster's home, or gets far away. The monster heals to full at once, then walks
  home untouchable and ignoring players.
- Experience shared by damage (or by party), loot spilling around the corpse, and a respawn
  after 45 s (or `respawn`).
- Bosses add the raid mechanics in `Combat._boss_tick`.

Do not give a monster its own movement, leash or targeting code. If every monster should
behave differently, change the shared rules in `combat.gd` and update the chase checks.

## 5. Check the balance

```sh
make fight-sim MONSTER=black_cat LEVELS=10,20 COUNT=1
make fight-sim MONSTER=black_cat LEVELS=10,20 COUNT=3
make fight-sim MONSTER=black_cat LEVELS=40 PLAYER_LEVEL=1     # an under-levelled player must lose
make fight-sim MONSTER=cave_spider LEVELS=16 OFF_HAND=torch   # a dark dungeon: torch, no shield or book
```

The simulator fights each class in its tier's vendor gear, first with auto-attacks only,
then with spells and potions. A normal monster at the player's level should land near the
current bands in `docs/balance.md`:
- One monster costs at most about a third of a player's health with auto-attacks alone.
- A camp of three kills sorcerers and druids that only auto-attack.
- Every class wins that camp with spells and potions, ending above about 40% health and
  using roughly 0–8 potions.

If a new monster falls outside the bands, change its rank, range or camp size, not its
numbers. If every monster is off, adjust the `Balance` constants and regenerate
`docs/balance.md` with `make balance-table`.

## 6. Finish

- Run `make lint` and `make test-unit` (catalog contract, spawns, loot).
- If the look is new, run `make test-visual` and look at the capture.
- If the monster lives near the starting town, run
  `python3 tools/testing/playtest.py --godot godot`.
- The Lexicon (`game/core/lexicon.gd`) lists the monster, its places, and its drops on its
  own. If the monster opens a level band with no task, give the nearest town's hub giver a
  task for it in `Quests.TASKS` (place the giver with `tools/generators/towns.gd`); the rules
  check requires a fitting task at every level.
- Document the monster where players meet it: `docs/gameplay.md` (zones, dungeons, hunting
  weapons), and `docs/art.md` for a new look.
