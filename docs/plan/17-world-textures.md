# 17 - World textures overhaul

**Effort:** L  **References:** the `art-direction` skill's reference looks

## Request
Update the world textures to match the new rock design, much more like OpenTibia (references to
come per tile type).

## Today
Terrain tiles come from `make_sprites.py` (`terrain_palette` and friends), drawn in cached chunks
by `game/render/floor_layer.gd`; water by `water.gdshader`. The mountain rock (`mountain`,
`_rock_field`, `ROCK_SPAN`) is the current reference style.

## Steps
1. One tile type at a time, in this order: grass, dirt and paths, sand, snow, swamp ground, then
   shorelines. Per type: a seamless field, 3-4 variants, and transition edges to each neighbour
   type (Tibia-style borders), lit from the top-left like the rock.
2. A border system in `floor_layer.gd`: for each cell, pick edge and corner overlays from the
   neighbour types, so transitions are drawn instead of hard tile edges.
3. Keep the generator deterministic and regenerate only the sheets that change (a full
   regeneration rewrites other sheets).
4. Check performance: chunks are cached, so the cost is at chunk build time only.

## Tests
Visual-test captures of each terrain type with its borders, next to a character; no seams across
tiles; chunk build time logged.

## Done when
The overworld ground matches the rock style everywhere, with drawn borders between terrains.
