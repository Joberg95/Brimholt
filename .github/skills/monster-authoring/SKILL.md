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
"ash_hound": {"name": "Ash hound", "look": "quadruped", "color": Color("#6a5a50"), "size": 0.9,
	"rank": "normal", "range": 1, "step": 0.4},
```

- **id**: snake_case and unique. **name**: original, never a Tibia name.
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
- **look**: one of the tinted creature sheets (`quadruped`, `spider`, `blob`, `golem`, `wraith`) with
  `color` as the tint. Or `humanoid` with `gear`: catalog item ids per visible slot, each of
  which must fit its slot.
- **size**: scales the sprite, 0.4–2.0.
- Optional **glow**: a `Color` halo and light, for bosses and magical creatures only.
- Only the fields above are allowed; the check rejects anything else.

### A new body shape

Try an existing look with a different tint and size first. If a new body really is needed:
- Write a builder in `tools/generators/make_sprites.py`, next to `quadruped`, `spider`,
  `blob`, `golem` and `wraith`. Use the same 64×64 frames: three columns, four facings, feet at y 53.
- Add its sheets to the `monsters/` outputs.
- Register it in `SpriteArt.MONSTER_SHEETS` and `MONSTER_DETAILS` (and `MONSTER_GLOW` if it
  glows).

Art must be original (see `docs/art.md`).

## 2. Loot (`Monsters.LOOT`)

```gdscript
"ash_hound": [["ash_hound_fang", 0.35], ["glowcap", 0.08]],
```

- Every monster has an entry, which may be `[]`. Each `[item, chance]` rolls independently,
  with the chance in (0, 1].
- Gold piles and tier gear (`Combat.GEAR_DROP_CHANCE`, by rank) are added automatically.
- Give each monster one signature **material**: a row in `game/data/items.json` with:
  - a `look` from the material icons (`tail`, `vial`, `fang`, `badge`, `pelt`, `orb`, `coil`,
    `crystal`);
  - three colours;
  - `value`, the gold a vendor pays. Normal monsters range from 2 (level 1) through about
    35 (level 15) and 80 (level 30) to about 140 (level 45). Elites and champions drop a
    pricier trophy (150–2,500). Compare with neighbouring monsters.

  Run `make sprites` and `make import` after adding items.
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
make fight-sim MONSTER=ash_hound LEVELS=10,20 COUNT=1
make fight-sim MONSTER=ash_hound LEVELS=10,20 COUNT=3
make fight-sim MONSTER=ash_hound LEVELS=40 PLAYER_LEVEL=1     # an under-levelled player must lose
make fight-sim MONSTER=cave_spider LEVELS=16 OFF_HAND=torch   # a dark dungeon: torch, no shield or book
```

The simulator fights each vocation in its tier's vendor gear, first with auto-attacks only,
then with spells and potions. A normal monster at the player's level should land near the
current bands in `docs/balance.md`:
- One monster costs at most about a third of a player's health with auto-attacks alone.
- A camp of three kills sorcerers and druids that only auto-attack.
- Every vocation wins that camp with spells and potions, ending above about 40% health and
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
