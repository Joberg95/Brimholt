# 48 - Direction: art from the OpenTibia pack, code split into components

**Effort:** XL (umbrella plan; each step is its own commit series)

**Status:** taken up again 2026-10-29 (owner): Part A is done by plan 49 (phases 1-5); Part B starts
now. Plans 38 and 39 are closed. The mountain look work (Tibia-style cliffs) is parked in a git
stash, "WIP mountains", on `experiment/pack-paperdoll`.

## Why

Two things have stalled the game.

1. **Art eats the project.** Most recent commits were art, and generated art never gets close to
   Tibia's look. Agents are good at code and bad at pixel art.
2. **The code has three god objects.** `main.gd` (1,956 lines, 30 RPCs) owns networking,
   replication, input, camera, and UI wiring. `world.gd` (1,855 lines) and `combat.gd` (2,067
   lines) each own a dozen unrelated rules. A player is one flat dictionary of about 45 keys that
   every system reads and writes. Adding a feature means editing all three files, and every test
   has to stand up the whole world.

The direction: **stop drawing art, take it from the OpenTibia sprite pack, and spend the time on
gameplay, starting with a component-based restructure that makes gameplay cheap to add.**

## Part A: art (done by plan 49)

- The OpenTibia sprite pack (CC BY 4.0) is the game's base art; attribution stays in
  `assets/third_party/CREDITS.md`. Risk accepted: the pack's origins can't be fully verified; fine
  for a LAN game among friends, review before any public release.
- **Art freeze:** agents no longer draw, repaint, or "improve" sprites. No new generator code in
  `tools/generators/` except to slice and index sheets.
- Outfits instead of visible gear; monsters fitted to the pack's creatures; items rebuilt from the
  pack (plan 49 phases 2-4). The world is the pack's (phase 5). Effects and missiles (plan 49 phase
  6) remain.
- **Still to do here (step 7):** the sprite catalog, one swap point for all drawing:
  `game/render/sprite_catalog.gd` (id -> sheet, region, anchor, frames, tint mask) over
  `assets/sprites/catalog.json`; a sprite with no art resolves to a magenta "?" placeholder, and a
  script lists every id the game uses and whether it resolves. Then retire `make_sprites.py` to
  `tools/legacy/` once nothing reads its sheets, and rewrite the `art-direction` and `icon-art`
  skills as short rules: use the catalog, don't draw.

## Part B: component-based code

### Principles

1. **The simulation stays node-free.** `core/` keeps running headless with about 640 monsters, so
   components there are plain data, not scene nodes. Nodes are for presentation only.
2. **Entities are ids; components are data; systems are behaviour.** An entity (player, monster,
   bot, NPC, ground stack) is an integer id. A component is a small typed record stored by id. A
   system owns one rule set, reads and writes only the components it declares, and talks to other
   systems through events.
3. **One owner per piece of state.** Each component has exactly one system that writes it; the
   others read it or send an event.
4. **Events, not calls across systems.** Systems append typed events (`Damaged`, `Died`,
   `ItemMoved`, `Moved`) to a bus; other systems react in the same tick. The existing event arrays
   become this bus.
5. **Networking is a layer, not a file.** Requests come in, get validated, become commands to a
   system; state changes go out as component diffs filtered by interest.

### Target layout

```text
game/
  core/
    ecs/
      entities.gd        Entity ids, create/destroy, kind (player, monster, bot, npc)
      store.gd           Component storage: one Dictionary per component type, id -> record
      events.gd          The event bus and event types
      scheduler.gd       Runs systems in a fixed order each tick
    components/          Plain data records (RefCounted with typed fields), one file each:
      position.gd        cell, from, facing, floor, next_move
      vitals.gd          health, mana, max values, next_regen, town_rest
      progression.gd     level, experience, vocation, spell_ranks, title
      combat_state.gd    target, next_attack, cooldowns, aggressors
      pvp.gd             skull, skull_until, unjustified, pvp flags
      inventory.gd       backpack, bags, equipment, gold
      bank.gd            bank gold, depot
      party.gd           party, invited
      quests.gd          tasks, done_tasks, trophies
      skills.gd          profession skills, gathering, next_craft, meal
      monster_ai.gd      kind, home, spawn, returning, engaged_at, damage_by
      boss.gd            wounds, enraged, next_pulse, fought
      outfit.gd          outfit id, four tint colours, addons
    systems/
      movement.gd        Walking, collision, travel cooldown
      regen.gd           Regeneration, town rest, meals
      targeting.gd       Targets, reach, line of sight
      attacks.gd         Auto-attacks and damage
      spells.gd          Casting, cooldown groups, ranks
      monster_ai.gd      Aggro, chase, leash, respawn
      bosses.gd          Pulses, wounds, enrage
      death.gd           Death penalties, drops, respawn
      pvp.gd             Skulls, justified kills, PvP zones
      parties.gd         Invites, shared experience
      loot.gd            Loot tables, spill, ground stacks
      inventory.gd       Item moves, equip, bags, stacking
      economy.gd         Vendors and bank (today's economy.gd)
      quests.gd          Tasks, credits, relic keepers
      professions.gd     Gathering and crafting (today's crafting.gd)
      instances.gd       Dungeon copies (today's instances.gd)
    bots/                bots.gd, solo.gd, nav.gd, ai/ (unchanged behaviour, read through components)
  world_map/             Map data: terrain grid, zones, buildings, markers, floors (today's static
                         half of world.gd); read-only at runtime
  net/
    session.gd           ENet host/join/leave, handshake, identities
    gateway.gd           Every @rpc: validates the sender and arguments, turns them into commands
    replication.gd       Interest areas, snapshots, component diffs to each peer
  client/
    client_state.gd      The replicated view: actors, monsters, ground (today's main.gd dictionaries)
    input_controller.gd  Keys, mouse, auto-walk
    camera.gd            Camera and interpolation
  render/                Drawing through sprite_catalog.gd; one node component per actor
                         (body, nameplate, health bar, effects) instead of one big draw loop
  ui/                    Panels read client_state and send commands through one client API
  main.gd                Under 200 lines: builds the pieces and wires them together
```

### How a request flows (after)

```text
UI / input -> client API -> gateway (@rpc, validation) -> command -> system
system -> writes its components -> events -> other systems react
replication -> component diffs -> client_state -> render and UI refresh
```

### Migration (strangler pattern, tests green after every step)

The game keeps working the whole time. Each step moves one area behind the new shape and deletes
the old code it replaces. No step lasts longer than a few commits.

| Step | Work | Done when |
| --- | --- | --- |
| 0 | Safety net: tighten the unit and LAN tests around current behaviour (combat, items, parties, saves) so a refactor can't change rules silently | Tests pass; coverage list in `docs/testing.md` |
| 1 | `ecs/` core: entities, store, events, scheduler. Add a facade so the old flat player dictionary is still readable (`world.players[id]["level"]` keeps working while it migrates) | New tests for the store and event ordering |
| 2 | Split `main.gd` into `net/session`, `net/gateway`, `net/replication`, `client/*`. No rule changes | `main.gd` under 300 lines; LAN tests pass |
| 3 | Split the static map data out of `world.gd` into `world_map/` | `world.gd` holds no static map state |
| 4 | Move components and systems one area at a time, smallest first: regen, movement, inventory, economy, professions, parties, quests, pvp, then targeting, attacks, spells, monster AI, bosses, death, loot | Each move deletes its code from `world.gd` or `combat.gd` |
| 5 | Saves read and write components (`character_store.gd`), with a migration from the old flat format | Old saves load; round-trip test |
| 6 | Bots read components through the same API as players | Playtest bots behave as before |
| 7 | Sprite catalog (Part A) on top of the new render components | Every id resolves or shows the placeholder |
| 8 | Delete the facade, `world.gd`, `combat.gd`, and the retired art generators | Lint clean, all tests green |

### Rules while restructuring

- **No gameplay changes in a refactor commit.** Behaviour changes go in their own commits.
- Each system file stays under about 400 lines; split it if it grows past that.
- A system may read any component but writes only its own. Cross-system effects go through events.
- Every system gets unit tests that build only the components it needs, not the whole world.
- Keep the existing conventions: typed GDScript, strict lint, `preload` with full paths, no
  `class_name` globals.
- Performance budget stays: no per-tick scans of every monster or ground stack (see
  `docs/architecture.md`); `make soak` must pass after steps 4 and 8.

## After this plan

With art fixed and the code split, gameplay work is mostly a new component and a new system:
floors above ground, NPC dialogue and quest chains, mini-bosses (plan 21), quest outfits (plan 22),
sound (plan 20), and balance passes.

## Needs from you

- Approve the step order above (the default: 0, 1, 2, ... in turn).

## Progress

- **Step 0 (2026-10-29):** the golden session `tests/unit/golden_test.gd` (see `docs/testing.md`)
  pins the outcome of combat, parties, items, potions, death, and saves; the existing rules and LAN
  tests stay as they are.
- **Step 1 (2026-10-29):** `game/core/ecs/` (entities, store, events, scheduler) with
  `tests/unit/ecs_test.gd`. Not used by the game yet. The facade that keeps
  `world.players[id]["level"]` readable comes with the first component that moves (step 4), where it
  has something to front.
- **Step 2 (2026-10-29):** `main.gd` 1,956 -> 282 lines. `game/client/client_state.gd` (the
  replicated view), `game/net/gateway.gd` (requests), `game/net/replication.gd` (updates and
  interest), `game/net/session.gd` (hosting, joining, saves, bots, options), `game/client/client_api.gd`,
  `input_controller.gd`, `camera.gd`, `effect_view.gd`, and `game/ui/ui_root.gd`. The network pieces
  are child nodes of Main created in `_init`, so their RPC paths match on every peer. No rule
  changed: the golden session, unit, visual, playthrough, and four LAN scenarios pass. The LAN
  `--dedicated` scenario already failed before this plan on this machine (it polls
  `last_action_message` once a frame and misses a refusal that a zone message overwrites in the
  same frame); still to fix. Two test fixes on the way: LAN deadlines for a 6.5 s scene load,
  and the playthrough builds its path grid before joining.
- **Step 3 (2026-10-29):** the map moves out of `world.gd` into `game/world_map/world_map.gd`
  (`WorldMap`): the terrain grid, every marker table (spawns, ground items, NPCs, zones, camps,
  stairways, cave mouths, holes, floors), buildings with their signs and furniture, regions, the map
  hash, and their lookups (`terrain`, `walkable`, `zone_at`, `region_at`, `npc`, `width`, ...).
  Every `World.<map>` reference now reads `WorldMap.<map>`. `world.gd` keeps only the item catalog
  and a task-level cache as static state; `World.TALK_RANGE` reads `WorldMap.TALK_RANGE`.
