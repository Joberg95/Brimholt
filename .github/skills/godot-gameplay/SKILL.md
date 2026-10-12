---
name: godot-gameplay
description: Use when implementing or changing Brimholt Godot GDScript, scenes, map resources, cardinal grid movement, collision, or smooth character presentation.
---

# Godot gameplay

1. Inspect the actual project, scenes, and resources first. Confirm the installed Godot version before relying on version-specific APIs.
2. Use typed GDScript and explicit scene/resource references. Keep gameplay state distinct from rendering and input.
3. Define one shared source for tile types, walkability, map dimensions, and spawns. Use 32-pixel tiles; store gameplay positions as integer grid coordinates.
4. Accept only a single cardinal step per action. Reject diagonal, zero-length, out-of-bounds, blocked, and occupied destinations server-side.
5. Reserve an actor's origin and destination during an accepted step to prevent overlap and swaps. Enforce time between steps on the server.
6. Interpolate visuals between approved positions without changing authoritative coordinates. Keep equipment layers and facing attached to that visual transform. The camera follows the local character's interpolated position; convert screen positions through the camera (`map_to_screen`, `_map_location`) rather than assuming a fixed map origin.
7. Draw floors first, then each row west to east (items, characters, oblique walls) so nearer walls cover what stands behind them. A stepping character belongs to the further south/east of its two tiles.
8. Use original deterministic placeholder drawings. Preserve scene/node paths required by multiplayer; do not transfer state authority to the input owner.
9. Check movement boundaries, blocked tiles, interpolation endpoints, and host/client parity using the validation skill.

Current entry points: `project.godot`, `game/main.tscn`, `game/world.gd` (shared rules), `game/main.gd` (camera, UI, input), `game/world_view.gd` (depth-ordered world drawing), `game/tile_art.gd` (terrain and oblique walls), and `game/character_art.gd` (character, gear, and item drawings). See `README.md` for setup; verify the local executable before running commands.
