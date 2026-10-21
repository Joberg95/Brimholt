---
name: godot-gameplay
description: Use when implementing or changing Brimholt Godot GDScript, scenes, map resources, cardinal grid movement, collision, or smooth character presentation.
---

# Godot gameplay

1. Inspect the actual project, scenes, and resources first. Confirm the installed Godot version before relying on version-specific APIs.
2. Use typed GDScript and explicit scene/resource references. Keep gameplay state distinct from rendering and input.
3. Keep one shared source for tile types, walkability, map dimensions, and spawns: `game/maps/overworld.tscn` and its terrain sectors (`game/maps/sectors/`, read and written through `game/maps/map_io.gd`), loaded by `World._static_init` (terrain custom data on the sector TileMapLayers, marker nodes for spawns, items, ferrymen, zones, and monster spawns). Edit the map in the Godot editor, not by regenerating it: paint in a sector's root layer (the override, which always wins); its locked `Base` child belongs to generators and `make region NAME=<id>`. Use 32-pixel tiles; store gameplay positions as integer grid coordinates.
4. Accept only a single cardinal step per action. Reject diagonal, zero-length, out-of-bounds, and blocked (terrain, NPC, furniture) destinations server-side. Players walk through other players and monsters; only monsters avoid occupied tiles, and spawns and arrivals pick free ones.
5. Reserve an actor's origin and destination during an accepted step to prevent overlap and swaps. Enforce time between steps on the server.
6. Interpolate visuals between approved positions without changing authoritative coordinates. Keep equipment layers and facing attached to that visual transform. The camera follows the local character's interpolated position; convert screen positions through the camera (`map_to_screen`, `_map_location`) rather than assuming a fixed map origin.
7. Draw only the visible cells (`world_view.visible_cells`); the overworld is 1920×1920 (`Atlas.OVERWORLD_SIZE`, the 384×384 heartland in its north-west corner, deep sea elsewhere) and dungeon copies and caves lie in bands right of it. Floors (z from −2 to +3) are planes on the same grid at `Atlas.FLOOR_X[z]`; go between them with `Atlas.to_floor`/`below`/`above`/`floor_of`, never hard-coded x offsets, and use `World.floor_bounds(z)` for a floor's painted area. Whole-map passes cover `World.PAINTED`, never the whole grid. Draw from the sprite sheets in `assets/sprites` through `game/render/sprite_art.gd`. Draw floors first, then each row west to east (items, characters, oblique walls) so nearer walls cover what stands behind them. A stepping character belongs to the further south/east of its two tiles.
8. Use original deterministic placeholder drawings. Preserve scene/node paths required by multiplayer; do not transfer state authority to the input owner.
9. Check movement boundaries, blocked tiles, interpolation endpoints, and host/client parity using the validation skill.

Current entry points: `project.godot`, `game/main.tscn`, `game/core/world.gd` (shared rules), `game/main.gd` (RPCs, camera, input), `game/ui/` (HUD, inventory panel, action bar, maps, NPC dialogs), `game/render/world_view.gd` (depth-ordered world drawing), `game/render/sprite_art.gd` (sprite-sheet regions and layer order), and `tools/generators/make_sprites.py` (original sprite generator). See `docs/architecture.md` for the layout and `README.md` for setup; verify the local executable before running commands.
