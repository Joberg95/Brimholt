# Presentation and art

How the world is drawn, the sprite sheet layouts, and how to add or edit art.

## Presentation

The game window shows 15×11 tiles at 2× zoom and follows your character smoothly,
Tibia-style; the dedicated-server window centres the whole map. Walls are oblique:
their tops are raised up and to the left, and the world is drawn row by row so
walls nearer the camera (south/east) cover characters and items behind them.
Characters stand about 1.3 tiles tall with adult proportions, a 3/4 view, a
cloak, hood, and tabard tinted per player, dithered shading, and a two-step walk.
Grass, dirt, sand, cobblestone, animated water, plank piers, stone walls, trees, worn
gear, and item icons are sprites too. Trees stand about two tiles tall and hide whatever
walks behind them. Only the visible part of the map is drawn each frame.

## Art and sprites

`assets/sprites` holds original PNG sprite sheets made by `tools/generators/make_sprites.py`
(Python standard library only). `game/render/sprite_art.gd` draws them with nearest
filtering:

| Sheet | Layout |
| --- | --- |
| `body.png`, `cloth.png`, `cloak.png`, `marker.png`, `gear/<item>.png` | 64×64 frames; columns stand / step A / step B; rows down / up / left / right; tile centre at frame pixel (32, 40) |
| `items.png` | 32×32 icons in `SpriteArt.ITEM_ORDER` |
| `tiles.png` | 32×32 cells: 4 grass, 4 dirt, 4 water frames, dirt edges and shorelines (N, E, S, W), 4 sand, 4 cobblestone, 2 horizontal and 2 vertical plank tiles, 4 dusk soil, 4 obsidian flagstones (variant 0 carries a rune) |
| `walls.png` | 48×48 oblique walls drawn 16 px up-left of their tile; index = open sides (1 N, 2 W, 4 S, 8 E); row 0 grey stone, row 1 obsidian |
| `objects.png` | 64×96 trees (three living, two dead for the Hollow Reach); trunk base on the tile centre at cell pixel (32, 80) |
| `terrain_palette.png` | 32×32 map-editor palette, one tile per terrain |

A character is drawn as: worn hand item when facing up, body, `cloth.png` tinted
with the player colour (it is greyscale), armour, helmet, then the hand item when
not facing up. Gear sheets already leave holes where the hood or near arm must stay
visible, so each item needs only one sheet rather than one per combination.

To edit art, change a PNG in Aseprite or another pixel editor, keeping its frame
layout, then reimport (open the editor or run `make import`). Running
`make sprites` (`python3 tools/generators/make_sprites.py`) regenerates **all** sheets and overwrites hand edits;
add `--preview .tools/sprite-preview.png` for a 2× review sheet. A new item needs a
catalog entry in `game/core/world.gd`, an icon, and (if equippable) a gear sheet listed in
`game/render/sprite_art.gd`; the rules check verifies these exist.

## Items and gear

Every item is a row in `game/data/items.json`, read by both the game and the generator:
`id`, `name`, `slot`, `level`, optional `vocations`, `look`, and `colors` (main, light,
accent), plus `glow` for relics and `gold` or `value` for coins and materials. The row
order is the icon order in `items.png`. `look` picks the drawing: helmets `cap`, `coif`,
`helm`, `kettle`, `greathelm` (decorate with `+plume`, `+crest`, `+horns`); armor `coat`,
`tunic`, `mail`, `plate`; weapons `sword`, `greatsword`, `axe`, `mace`, `bow`, `crossbow`,
`wand`, `rod`; off-hands `buckler`, `heater`, `tower`, `book`; and `cape`, `amulet`,
`charm`, `ring`. Tiers share a material palette, so a new tier is mostly new colours. Run
`python3 tools/generators/make_sprites.py --preview .tools/gear-preview.png` for a sheet
of every tier worn by each vocation.

The character's cloak is its own tinted sheet (`cloak.png`) holding only the cloak pixels
left visible around the body. A cape sheet is those same pixels in the cape's colours with
a hem and clasp, so it replaces the cloak in every facing without covering the body.

**Glow.** Relics and glowing bosses have white halo sheets (`gear/<id>_glow.png`,
`items_glow.png`, `monsters/<look>_glow.png`): the sprite plus a 4-pixel soft falloff.
`game/render/glow_layer.gd` draws them additively in the item's `glow` colour with a slow
pulse and a few rising sparks, above the world (light shines through trees). Inventory
slots draw the icon halo behind the icon.

## Lighting, particles, and third-party textures

The world renders into its own `SubViewport` (`game/ui/game_window.gd`), so lighting never touches the UI.
`game/render/lighting.gd` tints it with a `CanvasModulate`: a day and night cycle on the
host's clock (a 40-minute day; sessions start in the morning; clients sync the clock in the
welcome snapshot), multiplied by a zone's `ambient` colour (the Hollow Reach is a permanent
violet dusk). Pooled `PointLight2D`s follow players (lanterns), NPCs, relic wearers, glowing
bosses and ground relics (coloured), missiles, and spell areas; lanterns fade in as the light
fades. `game/render/fx.gd` emits one-shot `CPUParticles2D` bursts for hits, critical hits,
heals, level-ups, monster deaths, spell areas, and missile impacts (sparks and magic blend
additively). `game/render/world_overlay.gd` draws nameplates, NPC names, the target square,
missiles, and floating numbers above the lit world, so text stays readable at night, and
`game/render/vignette.gdshader` darkens only the outer edge of the game window.

Original art is generated; the only third-party assets are CC0 textures in
`assets/third_party/` (currently eight 128 px textures from Kenney's Particle Pack, used for
lights and particles). Add a CC0 pack only with its original license file beside it and a row
in `assets/third_party/CREDITS.md`; never import ripped, proprietary, or Tibia-derived art.
