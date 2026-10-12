---
name: godot-validation
description: Use when checking Brimholt Godot script parsing, scenes, grid/collision rules, authoritative RPC behavior, native ENet interoperability, or visible equipment synchronization.
---

# Godot validation

1. Check the available Godot executable and version. Require the project version (currently Godot 4.5+); do not claim parsing or runtime checks if tooling is missing.
2. Inspect the real project and test layout before selecting commands. Use the project's documented entry points once they exist.
3. Run a bounded headless editor import/parse with the actual project path. Fail on script/resource errors, not just a success-shaped process exit.
4. Run focused deterministic checks for cardinal steps, map boundaries/collision, occupancy/reservations, cooldowns, unique spawns, equipment validation, unequip removal, and inventory moves (malformed locations, reach, capacity, swaps, privacy).
5. Exercise real ENet peers with identical scene paths: a host and client, then a late joiner. Confirm accepted/rejected movement and item moves, visible-gear and ground-item synchronization, backpack privacy, late-join snapshots, and disconnect cleanup.
6. Keep tests finite with explicit timeouts and nonzero failure exits. Stop only processes created for the check; never kill processes by name or silently swallow failures.
7. Inspect graphical movement, camera following, oblique wall occlusion, and facing-aligned gear if graphical execution is possible. Document any gap between headless state coverage and visual verification.
8. Report the exact checks that ran and any missing executable, permission, network, or graphical limitation. Do not bypass denied tool approvals or install system-wide tooling without authorization.

Current checks: `tests/rules_test.gd`, `tests/peer_test.gd` via `tools/test_lan.py`, and `tests/visual_test.gd`. Follow the commands and prerequisites in `README.md`; check the executable path rather than assuming Godot is installed.
