---
name: godot-validation
description: Use when checking Brimholt Godot script parsing, scenes, grid/collision rules, authoritative RPC behavior, native ENet interoperability, or visible equipment synchronization.
---

# Godot validation

1. Check the available Godot executable and version. Require the project version (currently Godot 4.5+); do not claim parsing or runtime checks if tooling is missing.
2. Inspect the real project and test layout before selecting commands. Use the project's documented entry points once they exist.
3. Run a bounded headless editor import/parse with the actual project path; it also imports the sprite sheets, which a fresh checkout needs before any other run. Fail on script/resource errors, not just a success-shaped process exit.
4. Run focused deterministic checks for cardinal steps, map boundaries/collision, occupancy/reservations, cooldowns, unique spawns, equipment validation and slot types (two rings, off hand, charm, necklace), item stats and balance anchors (final boss 350,000; no group under ten players wins), vocations, the twelve-player cap, map-scene integrity and reachability, ferry travel and fares, gold pickup, zones and monster spawn levels, key bindings, combat (reach, line of sight, attack timing, AI, death, experience, spells), unequip removal, and inventory moves (malformed locations, reach, capacity, swaps, privacy).
5. Exercise real ENet peers with identical scene paths: a host and client, then a late joiner. Confirm accepted/rejected movement and item moves, visible-gear and ground-item synchronization, backpack privacy, late-join snapshots, and disconnect cleanup.
6. Keep tests finite with explicit timeouts and nonzero failure exits. Stop only processes created for the check; never kill processes by name or silently swallow failures.
7. Inspect graphical movement, camera following, oblique wall occlusion, and facing-aligned gear if graphical execution is possible. Document any gap between headless state coverage and visual verification.
8. Report the exact checks that ran and any missing executable, permission, network, or graphical limitation. Do not bypass denied tool approvals or install system-wide tooling without authorization.

For end-to-end coverage, run the automated playthrough (`tools/testing/playtest.py`, bots in `tests/integration/playthrough.gd`) and report its findings.

Current checks: `tests/unit/rules_test.gd`, `tests/integration/peer_test.gd` via `tools/testing/test_lan.py`, and `tests/visual/visual_test.gd` via `tools/testing/test_visual.py` (offscreen rendering; open `.tools/visual-report.html` in the browser side panel instead of showing a game window). Run them with `make test`, `make test-visual`, `make check`, or `make playtest` (`docs/testing.md`); check the executable path rather than assuming Godot is installed.
