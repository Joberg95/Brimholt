# Presentation and art

How the world is drawn, the sprite sheet layouts, and how to add or edit art.

## Presentation

The window scales the game by whole numbers only (`scale_mode="integer"`), and 2D transforms snap to
the pixel grid, so every art pixel is the same size on screen; a window between multiples shows a border.
The game window shows 15×11 tiles at 2× zoom and follows your character smoothly,
Tibia-style; the dedicated-server window centres the whole map. Walls are oblique:
their tops are raised up and to the left, and the world is drawn row by row so
walls nearer the camera (south/east) cover characters and items behind them.
Characters wear the OpenTibia sprite pack's player outfits as in Tibia (see Characters below); worn
gear is not drawn on them.
Grass, dirt, sand, cobblestone, animated water, plank piers, stone walls, trees, and item icons are
sprites too. Trees stand about two tiles tall and hide whatever
walks behind them. Only the visible part of the map is drawn each frame.

The visual direction is **modern Tibia (12+)**, matched in style with every design our own
(`docs/plan/46-modern-tibia-direction.md`, rules in the `art-direction` skill): saturated,
high-contrast colour everywhere, a hard top-left light with bright highlights and dark core
shadows, a full dark hue-tinted outline round characters, creatures, and items, smooth anti-aliased
ramps without dithering or pillow shading, the oblique 3/4 view for everything that stands, and
dense, readable detail. Glow and animation stay reserved for relics, ores, magic, and fire, and
relic halos remain visible without bleaching out the equipment underneath. Every ramp comes from the
master palette, `tools/generators/palette.py` (6–10 tones per material, `outline()` for each
material's near-black, and `IDENTITY`: each region's ground and accent ramps, from Brimholt's flavour
pillars); run it with `--swatch .tools/palette.png` to check the ramps and see them.

The world is moving to this look family by family (plan 46, phase 4). The environment is done:
walls, trees and plants, roofs, props, floors, and the world map use master-palette ramps. Creatures
and mounts have the palette's saturation, contrast, and hue-tinted near-black outline
(`creatures.STYLE`, `palette.outline`). Item-icon, effect, and UI sheets still use their builders' own
muted ramps, and the
character described above is the current rig, not the target: a chunkier body in 3/4 view with a
four-frame walk, a subtle attack swing, free head/body/legs/feet colours, and 64×64 frames.
Designs may imitate Tibia closely, but no Tibia artwork files, maps, or client data are copied:
every pixel is drawn here.

## Art and sprites

**House style: Qasrun.** Sunreach's capital (palms, plaster walls with latticed windows,
sandstone castle, flat plaster roofs, slab streets) is the reference look for all new and
repainted art. Its in-game captures are in `docs/art-reference/` (not imported by Godot), and
the builders and patterns it sets are listed in the `art-direction` skill.

`assets/sprites` holds original PNG sprite sheets made by `tools/generators/make_sprites.py`
(Python standard library only). `game/render/sprite_art.gd` draws them with nearest
filtering:

| Sheet | Layout |
| --- | --- |
| `outfits/<looktype>.png` | The pack's player outfits (see Characters below) |
| `marker.png` | 64×64 frames; columns stand / step A / step B / attack wind-up / strike; rows down / up / left / right; tile centre at frame pixel (32, 40). Monster sheets have only the first three columns |
| `coins.png` | Gold coin stacks, one 32×32 frame per size stage (`pixel_coins.STAGES`, matching `SpriteArt.COIN_STAGES`): one, two and three hand-drawn coins, a small heap, a heap with a second mound, and a big heap with loose coins (`tools/generators/pixel_coins.py`) |
| `items.png` | 32×32 icons in `SpriteArt.ITEM_ORDER`, 64 to a row (`ITEM_COLUMNS`, `item_cell`; one long row would pass the 16384-pixel texture limit): the OpenTibia sprite pack's item sprites, written by `tools/generators/otsp_export.py items` (see Items and gear). `items_glow.png` is blank for now |
| `spells.png` | 32×32 rune stones, eight per row in `Spells.SPELLS` order: a weathered stone (its outline varies per spell) with the spell's Elder Futhark rune (`Spells.RUNES`, strokes in `RUNE_STROKES`; two Anglo-Saxon runes, Ear and Yr, past the twenty-four) carved in and glowing in the spell's colour |
| `world_map/` | The painted world map in pages, one 512×512 PNG per 128×128-tile sector near land (`<sx>_<sy>.png`, 4 px per tile, map tile = world cell), baked by `tools/generators/world_map.gd` (not `make_sprites.py`): open sea one flat blue (so pages end without a seam), shallows and surf, land with soft variation, forest canopy clumps, lit and shaded ridges, roofs in towns. `overview.png` is the whole 1920×1920 overworld at 1 px per tile for zooming far out; `pages.json` holds each page's terrain hash |
| `rune_fx.png` | 32×32 frames of a spell or rune landing (`rune_fx`), one row per element (`Spells.ELEMENTS`: fire, frost, lightning, holy, nature, slash, pierce, heal, death, ice_wall), four frames each: flame tongues that bloom and die to embers, ice shards that rise and shatter, a forked bolt that scatters sparks, golden rays round a bright core, thorny tendrils in a burst of leaves, a pale sword arc, an arrow's strike with splinters, green motes rising, a pale violet skull out of black smoke (Sudden death, Soulfire), and a block of faceted ice with crystal points that rises, shimmers, and cracks (Glacier wall: `SpriteArt.HELD_FX` hold frames 1-2 for the effect's whole `life`). Drawn on every tile hit (`SpriteArt.draw_rune_fx`), 6 px up so they stand on the tile; bolts and shots play theirs on the target when they land |
| `spell_missiles.png` | 16×16 projectiles (`spell_missile`), one row per element (fire, frost, lightning, holy, nature, pierce), four frames each, pointing right and drawn turned toward the target (`SpriteArt.draw_missile`): an ember trailing sparks, an ice shard, a crackling spark, a holy orb in a halo, a spinning thorn, and an arrow |
| `tiles.png` | 32×32 floor cells, four to a row, hand-pixelled in `tools/generators/pixel_floors.py` (indices in `SpriteArt`'s `*_TILE` constants): 4 grass (the fourth, rarer, with wild flowers), 4 dirt, 4 water frames, 8 blank cells (12–19), 4 sand, 4 cobblestone, 2 horizontal and 2 vertical plank tiles, 4 dusk soil, 4 obsidian flagstones (variant 0 one slab with a glowing rune), 4 cave floors, then the ways down and up, all overlays drawn over the ground the stairway cell stands on (`SpriteArt.ground_under`, `way_tile`): a ladder opening into built dungeons (tile 44: the town cellar, the crypt), a ladder up out of them (45), rough stone steps up out of caves (46), 3 blank cells, 4 gravel, the hole into a cave (54: every cave, mine, and elite cave, in town or not), 4 cellar floors (large dark bricks), kerb stones (59–62: north, east, south, west, overlays), 4 bog, 4 snow, 4 snowy cobble, 4 sandstone flags (`F`), 16 carpet tiles by open sides (`Y`), and 4 cave earth floors (95–98: red-brown earth with gravel, the floor of every rock cave; cave rock is drawn as the mountains' rock blocks). Every material is one five-tone ramp lit from the top-left. Variants and water frames meet each other without seams: fields are shared within six pixels of the border and the variant's own further in, details near the border are the same in every variant, and built floors lay their joints the same way in every variant. The terrain shader blends natural ground into its neighbours |
| `cellar_walls.png` | The 16 house wall shapes of `house_walls.png` (`thin_wall` with `CELLAR_STONE`) in dark red-brown brick, for dungeons with `"theme": "cellar"` |
| `walls.png` | 48×48 oblique walls drawn 16 px up-left of their tile; index = open sides (1 N, 2 W, 4 S, 8 E); row 0 grey stone, row 1 obsidian, row 2 cave rock (dungeons), rows 4 and 5 (blocky cliffs and outcrops) are kept but unused on the overworld; row 3 thin town walls (`#`), indexed by connected sides (walls and doorways) instead, a 10 px masonry band through the tile centre |
| `roofs.png` | Per material row (clay, slate, wooden shingle, snow, and Sunreach's sand plaster, drawn almost flat without chimneys) four 32×32 swatches: near slope, far slope, timber gable, trim (ridge cap, eave board, chimney stone). `game/render/roof_art.gd` rasterizes each building's roof from them |
| `firs.png` | 64×96 snow-laden firs (`snowy_fir`), 3 variants drawn like trees for `P` in the frost isles: tiers of dark boughs loaded with snow on the lit side |
| `palms.png` | 64×96 date palms (`palm`), 3 variants drawn like trees for `T` in Sunreach: a leaning ringed trunk, arching fronds lit top-left, dates under the crown |
| `sandstone_walls.png` | Sunreach's house walls (`sandstone_wall`): the house-wall frames in cream plaster with a dark plinth and lit cornice, the doors and fill, then a south- and an east-facing wall with a latticed window (`SpriteArt.SANDSTONE_WINDOW`, picked on some straight walls) |
| `sandstone_castle_walls.png`, `sandstone_castle_towers.png` | Qasrun's castle walls and towers: `castle_block` in sandstone (`SANDSTONE_CASTLE`) |
| `log_walls.png` | The house-wall shapes (`thin_wall`) in timber courses under a cap of snow: house and palisade walls (`#`) in the frost isles |
| `mushrooms.png` | 64×96 giant mushrooms (`mushroom`), 3 variants drawn like trees for `U` in Mirewood Fen: a pale stalk and a broad spotted cap |
| `cave_rock.png` | The rock of every cave (rock off the overworld only; the mountains keep `mountains.png`): the mountains' 48×48 block layout (16 open-side masks by 16 places in the seamless span) built by `cave_rock` from rounded pale boulders (`_boulder_field`: domes on jittered points, lit from the top-left) with dark crevices, faces of stacked boulders darker on the south and east, as in Tibia's caves |
| `fieldstone_walls.png` | Castle keep walls: the 16 thin-wall shapes of `house_walls.png`, the two doorways, and the block fill (frame 18), in rounded grey fieldstones (`fieldstone_wall`, `_fieldstone`: stones on a jittered grid that repeats every tile, the top lightest, the south face mid, the east face darker, dark mortar). `SpriteArt.castle_stone` uses them for any `#` beside a sandstone floor or carpet |
| `wall_decor.png` | 32×32 decorations hung on a wall's visible face (`props.wall_decor`, leaned like the signs): a red banner with a gold crown, a wall torch with a real flame, a painting in a gilded frame. Placed by Decor markers on wall cells |
| `furniture.png` | 32×48 furniture drawn 16 px above its tile, painted like the creatures from 3D solids (`tools/generators/props.py`: boxes, cylinders, and ellipsoids under the same camera and top-left light, five-tone ramps, wood grain and plank seams, gloss on metal and glass, glowing flames and lantern glass, coloured outlines): shop counter, bank counter, potion shelf, bookshelf, weapon rack, barrel, crate, strongbox, anvil, workbench, cauldron, loom, hearth, then home furniture: bed, table, chair, potted plant, chest, then street furniture: lamp post, well, bench, market stall, then a stall and a bench seen from behind (`props.furniture("stall_back")`: any kind turned round), then the castle pieces (Decor markers): sandstone pillar, knight statue, gargoyle on a plinth, bush, flower vase, potted palm, candelabra table, fruit table, stove, throne (`SpriteArt.FURNITURE` order) |
| `fountain.png` | Four 96×112 frames of the town square's three-tier stone fountain (`props.fountain`): a round basin of stone blocks with a rippling pool, two bowls on a pedestal, and drops falling bowl to bowl a step lower each frame (6 fps). Drawn from the bottom-middle of the 3x3 tiles it blocks (`"fountain"`; the other eight are `"fountain_basin"`) |
| `signs.png` | 32×32 hanging signs on an iron bracket, painted from 3D solids (`props.sign`) with the board turned to the viewer: shop (flask and sword), bank (coins), workshop (hammer and green flask), warden (crossed swords) |
| `herbs.png` | 32×32 herb patches for herbalism, painted leafy bushes with flower heads (`props.herb`), two variants per resource band (sunflax, mirereed, silverthistle, nightcotton, starpetal colours), drawn on their tile (`SpriteArt.draw_herb`) |
| `menu_icons.png` | 8 painted 32×32 micro-menu icons in `MENU_ICONS` order (`make_sprites.py` `menu_icon`): character helm, spell book, professions pick and hammer, quest scroll, lexicon bestiary, world map, party trio under a pennant, controls cog |
| `title.png` | 400×267 start-screen painting shown at 3× (`make_sprites.py` `title_painting`): a castle on a hill above a lake at dusk, dithered sunset sky with stars and a moon, layered mountains, far-shore pines, and a grassy ledge framed by pines where the start screen draws your character from behind |
| `mountains.png` | 48×48 Tibia-style rock blocks for mountains (`L`) and overworld outcrops (`C`), drawn like walls 16 px up and left: 16 columns by open sides (`SpriteArt.rock_mask`), 16 rows that are the parts of one seamless 128×128 rock texture (a tile draws row `x % 4 + (y % 4) * 4`). A lumpy cracked stone top, ragged where it meets open ground, with cliff faces of rock columns (`make_sprites.py` `mountain`) |
| `ores.png` | 48×48 ore vein overlays for a rock block's south face (`Crafting.ORES`): one column per band (copper, iron, silver, cobalt, starmetal), row 0 plain and row 1 glinting (`ore_vein`) |
| `house_walls.png` | 64x64 frames drawn 32 px up and left of their tile: house and town walls (`#`) a full tile tall as in Tibia, 16 thin walls by connected sides, then a doorway in a west-east and a north-south wall, a timber-framed plank door ajar in the wall face (`house_door`) |
| `castle_walls.png`, `castle_towers.png` | Castle walls (`W`): 16 frames by open sides of ashlar blocks with a flagstone walkway and merlons, 54×54 walls raised 16 px and 70×70 towers raised 32 px (every 2×2 of castle wall is a tower, `SpriteArt.tower`), each with 6 px of room for the battlements (`castle_block`) |
| `crags.png` | 64×64 boulder piles (the old mountain art), kept for reference; nothing draws them now |
| `objects.png` | 64×96 trees (three living, drawn like the mountain rock: two broadleaf crowns of leaf clumps lit from the top-left with dark gaps between them and a ragged leafy edge, and a pine of drooping tiers shaded under the tier above, all on six-tone ramps with a dark outline (`tree`); two dead for the Hollow Reach, then three desert plants: a columnar cactus, a barrel-cactus clump, and a thorn shrub for terrain `K`, then the waystone, a carved standing stone with a cyan rune); trunk base on the tile centre at cell pixel (32, 80) |
| `terrain_palette.png` | 32×32 map-editor palette, one tile per terrain |

**Characters.** Players, townsfolk, and humanoid monsters wear the OpenTibia sprite pack's player
outfits (plan 49), drawn by `SpriteArt.draw_actor`; worn gear is not drawn on the body, as in Tibia.
`python tools/generators/otsp_export.py outfits` writes `outfits/<looktype>.png` from the pack's client
files: the pack's 64×64 frames as it draws them (the figure's tile is the bottom-right quarter, shifted
8 pixels up and left, so the tile centre is `SpriteArt.OUTFIT_ANCHOR` (56, 56)), five columns (stand,
step A, step B, and stand and step A again for the attack wind-up and strike, which the pack has no
frames for) by four rows (down, up, left, right). Each sheet stacks five such blocks: the untinted
outfit, then the parts the pack's colour mask marks as head, body, legs, and feet, which the game
multiplies by colours like Tibia's outfit colours. Each vocation has its looktype and colours
(`SpriteArt.OUTFITS`, `OUTFIT_COLORS`): Adventurer 17, Warrior 18 (the helmet sits in the "feet" part),
Hunter 45, Sorcerer 20 and Druid 21 (robes whose mask only covers the hair, so they differ by hair
colour). Townsfolk wear 16 with their trade's body colour. There are no mounts (the pack's one mount,
looktype 12, a saddled bear, is unused).
**Monsters** are the pack's creatures (plan 49): every row of `game/data/monsters.gd` names one in
`outfit`, exported by `otsp_export.py outfits` like the player outfits (one untinted block) and drawn at
the row's `size` around the feet (`SpriteArt.draw_monster`). The pack has 38 creatures besides the player
outfits; the normal monsters are one each (Black cat, Ratkin, Wild hog, Brigand, the gargoyles, mages,
ghosts, grubs, and the Fen dragon ...), and the elites, champions, and bosses wear one of them larger.
A glowing monster draws its creature again, `SpriteArt.GLOW_SCALE` larger, in its `glow` colour.

To edit art, change a PNG in Aseprite or another pixel editor, keeping its frame
layout, then reimport (open the editor or run `make import`). Running
`make sprites` (`python3 tools/generators/make_sprites.py`) regenerates its sheets and overwrites hand edits;
it no longer writes item icons (see Items and gear).

## Items and gear

Item icons are the OpenTibia sprite pack's own item sprites (CC BY 4.0,
`assets/third_party/CREDITS.md`), used as they are (plan 49). Our own drawn icons, worn gear, mounts,
and painted outfits were deleted. Every catalog row in `game/data/items.json` names the pack item it
shows in `sprite`. `python tools/generators/otsp_export.py items` reads the pack's client files
(`otsp.dat` and `otsp.spr` under `assets/third_party/opentibia_sprite_pack/client_files/`, decoded by
`tools/generators/otsp.py`) and writes `items.png` in catalog order (a two-by-two pack item is halved
to fit its 32×32 cell) and a blank `items_glow.png`.

`tools/generators/otsp_items.py` made the first mapping: it sorts the pack's items into kinds by id
range (`PACK`: swords, axes, helmets, armour, potions, ores, logs, herbs, gems, ...), and gives each of
our items one unused sprite of its kind (`KIND`), the plainer sprites to low levels and the richer ones
to high levels, colour as the tie-break. Items left without a sprite were deleted with their loot,
shop, quest, and recipe entries, so some tiers have gaps (legs, boots, and some weapons and
off-hands). Fish, logs, and herbs use the closest pack objects (food, tree logs, plants). To change
an item's picture, set its `sprite` to another pack item id and rerun the export; no two items share
a sprite.

Every item row has `id`, `sprite`, `name`, `slot`, `level`, optional `vocations`, `look`, and `colors`
(main, light, accent), plus `glow` for relics and `gold` or `value` for coins and materials. The row
order is the icon order in `items.png`. `look` and `colors` no longer draw the icon. Helmets, armor,
legs, and boots carry an `armor` type (`plate`, `mail`, `leather`, `cloth`).

**Glow.** Glowing monsters draw their creature again, a little larger, in their `glow` colour:
`game/render/glow_layer.gd` draws it additively with a slow pulse and a few rising sparks, above the
world (light shines through trees). Relic icons have no halo until the effects phase.

## Lighting, particles, and third-party textures

The world renders into its own `SubViewport` (`game/ui/game_window.gd`), so lighting never touches the UI.
`game/render/lighting.gd` tints it with a `CanvasModulate`: a day and night cycle on the
host's clock (a 40-minute day; sessions start in the morning; clients sync the clock in the
welcome snapshot), multiplied by a zone's `ambient` colour (the Hollow Reach is a permanent
violet dusk). Pooled `PointLight2D`s follow players who hold a torch (a wide flickering light; without one a
player carries no light, so a `dark` dungeon such as Silkhollow is pitch black), NPCs, town lamp posts (fading in through dusk), relic wearers, glowing
bosses and ground relics (coloured), missiles, and spell areas; lights fade in as the light
fades. Darkness eases rather than jumps (weather, lightning), a lamp, NPC lantern, or torch coming
into range fades in over 0.3 s, and lights are placed nearest the camera first, since Godot lets
only 16 lights reach one canvas item: the lights beside you always win. `game/render/fx.gd` emits one-shot `CPUParticles2D` bursts for hits, critical hits,
heals, level-ups, monster deaths, spell areas, and missile impacts (sparks and magic blend
additively). `game/render/world_overlay.gd` draws nameplates, NPC names, the target square,
missiles, and floating numbers above the lit world, so text stays readable at night, and
`game/render/vignette.gdshader` darkens only the outer edge of the game window.

**Held weapons and attacks.** The weapon is posed in the fist of the weapon arm in every frame
(`weapon_hand`, `WEAPON_ANGLES` in `make_sprites.py`): melee weapons rest tilted forward, staves
upright, bows carried at an angle, crossbows held low. When a hit lands (the `hit` event names
its `source`), every peer plays that creature's attack for `SpriteArt.ATTACK_SECONDS`: the arm
raises the weapon (wind-up), then cuts or thrusts it toward the target (strike). The swing only
turns the drawn pose (`SpriteArt.posed`); the creature's real facing is unchanged.

**Rarity** is not drawn on inventory slots. Wearables have a grade by tier (Common from 1,
Uncommon 10, Rare 20; Epic 30 and Legendary 40 only for champion and boss drops and quest gear;
relics are Relic in their glow colour, `Items.rarity`), shown on hover: `game/ui/item_slot.gd` colours the tooltip's name, rarity line,
and frame. Items you cannot use yet are tinted red.

**Thin walls and roofs.** Town walls (`#`) are thin: a masonry band through the tile centre,
joining neighbouring walls and doorways, with the outside ground and the room's floor drawn on
either side. Obsidian and cave walls stay full-tile blocks. House walls stand a full tile tall, as in Tibia, so every doorway is a person-high door set into the wall face, leaning with it, and roofs sit on top of the taller walls. Each building gets a pitched roof
(`game/render/roof_art.gd`): eaves on the wall bands, an east-west ridge raised with the walls'
up-left lean, a near slope shaded from the lit ridge to the eave, a darker sliver of the far
slope, a timber gable on the east end, a soft shadow under the eave, and a chimney on about
half the houses. Roofs are rasterized once per building and cached.

**Furniture.** Shops get a counter, potion shelf, weapon rack, barrel, and crate; the bank a
counter with scales and coins, bookshelves, and strongboxes (`World.FURNISHINGS`, placed around
the keeper at load). Furniture blocks movement and is skipped wherever it would cut off part
of the room or every tile in talking range.

**Roofs and signs.** `World.BUILDINGS` are the town rooms enclosed by walls with a door
(`game/data/buildings.gd`). `world_view.gd` draws each roof right after its building's south
wall row, so whoever stands south of it covers the eave, and fades it out while the local
character is inside (rooms or doorway). Names, bars, and glows of anyone under an opaque roof
are hidden. The material is picked from the building's position. Signs hang on the wall
beside a shop's or bank's door (`World.SIGNS`): on the south or east face, or above the roof
edge for a north or west door (`SpriteArt.SIGN_OFFSETS`).

**Weather** (`game/render/weather.gd`) is cosmetic and a pure function of the host clock, so
every peer sees the same sky without any RPC. The day is split into 4-minute slots, each
clear (50%), overcast (20%), rain (22%), or storm (8%), blending over 30 seconds. Clouds dim
the light (`Weather.tint`, multiplied into the `CanvasModulate`); storms add lightning
flashes. `game/render/rain_layer.gd` draws `rain.gdshader` over the world viewport: three
parallax layers of 1-pixel slanted drops in whole game pixels, ground splashes anchored to
the map, and a faint veil, all tinted by the world light so rain is dim at night. There is
no weather underground (dungeons) and no rain in the desert (`game/data/biomes.gd`), where
clouds are thin. Lanterns follow nightfall; clouds only add a little to them, so a rainy noon
stays unlit. Set `Weather.override` (for example `"storm"`) to pin the weather in tests.

Original art is generated; the only third-party assets are CC0 textures in
`assets/third_party/` (currently eight 128 px textures from Kenney's Particle Pack, used for
lights and particles) and the game font. All text draws with DejaVu Sans
(`assets/third_party/fonts/dejavu/`, the project font `gui/theme/custom_font`, so
`ThemeDB.fallback_font` is DejaVu too), a free Verdana-like font under the Bitstream Vera licence:
allowed by the owner. The other non-CC0 asset is the OpenTibia sprite pack sheet
(`assets/third_party/opentibia_sprite_pack/`, CC BY 4.0, allowed on 2026-10-21), read only by the
icon generators as models for our own repainted variants, never shipped as-is. Add a CC0 pack only with its original license file beside it and a row
in `assets/third_party/CREDITS.md`; never import ripped or proprietary art files (Tibia's included).
