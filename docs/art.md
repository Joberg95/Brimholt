# Presentation and art

How the world is drawn, the sprite sheet layouts, and how to add or edit art.

## Presentation

The window scales the game by whole numbers only (`scale_mode="integer"`), and 2D transforms snap to
the pixel grid, so every art pixel is the same size on screen; a window between multiples shows a border.
The game window shows 15×11 tiles at 2× zoom and follows your character smoothly,
Tibia-style; the dedicated-server window centres the whole map. Walls are oblique:
their tops are raised up and to the left, and the world is drawn row by row so
walls nearer the camera (south/east) cover characters and items behind them.
Everything in the world is the OpenTibia sprite pack's art (CC BY 4.0, plan 49): grounds and their
borders, walls, rock, roofs, trees, town objects, item icons, character outfits, and creatures. Only
the visible part of the map is drawn each frame.

The pack draws everything in an oblique view that leans up and left: a thing stands with its
bottom-right corner on its tile and rises toward the top-left, so a wall lies along its tile's east or
south edge and a tree or creature reaches into the tiles above and left of it. Designs imitate Tibia,
but no Tibia artwork files, maps, or client data are used; the art is the OpenTibia sprite pack's.

## Art and sprites

`assets/sprites` holds the sprite sheets. The pack's are exported by `tools/generators/otsp_export.py`
from its client files (`assets/third_party/opentibia_sprite_pack/client_files`, read by
`tools/generators/otsp.py`); `tools/generators/make_sprites.py` (Python standard library only) still
draws the few sheets of our own that remain (the ground marker, coins, spell runes and effects, menu
icons, and the title painting) until the effects phase. `game/render/sprite_art.gd` and the
`*_art.gd` scripts beside it draw them with nearest filtering:

| Sheet | Layout |
| --- | --- |
| `outfits/<looktype>.png` | The pack's player outfits and creatures (see Characters below) |
| `world.png` | Every pack world thing (`otsp_export.py world`: grounds, borders, walls and rock, ways, doors, town objects, plants, trees, stones, and ores) with each pattern and animation frame, shelf-packed; `game/render/pack_atlas.gd` (generated) lists where each lies (`THINGS`, `RECTS`) and the ground border sets (`BORDERS`) |
| `marker.png` | 64×64 frames; columns stand / step A / step B / attack wind-up / strike; rows down / up / left / right; tile centre at frame pixel (32, 40). Monster sheets have only the first three columns |
| `coins.png` | Gold coin stacks, one 32×32 frame per size stage (`pixel_coins.STAGES`, matching `SpriteArt.COIN_STAGES`): one, two and three hand-drawn coins, a small heap, a heap with a second mound, and a big heap with loose coins (`tools/generators/pixel_coins.py`) |
| `items.png` | 32×32 icons in `SpriteArt.ITEM_ORDER`, 64 to a row (`ITEM_COLUMNS`, `item_cell`; one long row would pass the 16384-pixel texture limit): the OpenTibia sprite pack's item sprites, written by `tools/generators/otsp_export.py items` (see Items and gear). `items_glow.png` is blank for now |
| `spells.png` | 32×32 rune stones, eight per row in `Spells.SPELLS` order: a weathered stone (its outline varies per spell) with the spell's Elder Futhark rune (`Spells.RUNES`, strokes in `RUNE_STROKES`; two Anglo-Saxon runes, Ear and Yr, past the twenty-four) carved in and glowing in the spell's colour |
| `world_map/` | The painted world map in pages, one 512×512 PNG per 128×128-tile sector near land (`<sx>_<sy>.png`, 4 px per tile, map tile = world cell), baked by `tools/generators/world_map.gd` (not `make_sprites.py`): open sea one flat blue (so pages end without a seam), shallows and surf, land with soft variation, forest canopy clumps, lit and shaded ridges, roofs in towns. `overview.png` is the whole 1920×1920 overworld at 1 px per tile for zooming far out; `pages.json` holds each page's terrain hash |
| `rune_fx.png` | 32×32 frames of a spell or rune landing (`rune_fx`), one row per element (`Spells.ELEMENTS`: fire, frost, lightning, holy, nature, slash, pierce, heal, death, ice_wall), four frames each: flame tongues that bloom and die to embers, ice shards that rise and shatter, a forked bolt that scatters sparks, golden rays round a bright core, thorny tendrils in a burst of leaves, a pale sword arc, an arrow's strike with splinters, green motes rising, a pale violet skull out of black smoke (Sudden death, Soulfire), and a block of faceted ice with crystal points that rises, shimmers, and cracks (Glacier wall: `SpriteArt.HELD_FX` hold frames 1-2 for the effect's whole `life`). Drawn on every tile hit (`SpriteArt.draw_rune_fx`), 6 px up so they stand on the tile; bolts and shots play theirs on the target when they land |
| `spell_missiles.png` | 16×16 projectiles (`spell_missile`), one row per element (fire, frost, lightning, holy, nature, pierce), four frames each, pointing right and drawn turned toward the target (`SpriteArt.draw_missile`): an ember trailing sparks, an ice shard, a crackling spark, a holy orb in a halo, a spinning thorn, and an arrow |
| `menu_icons.png` | 8 painted 32×32 micro-menu icons in `MENU_ICONS` order (`make_sprites.py` `menu_icon`): character helm, spell book, professions pick and hammer, quest scroll, lexicon bestiary, world map, party trio under a pennant, controls cog |
| `title.png` | 400×267 start-screen painting shown at 3× (`make_sprites.py` `title_painting`): a castle on a hill above a lake at dusk, dithered sunset sky with stars and a moon, layered mountains, far-shore pines, and a grassy ledge framed by pines where the start screen draws your character from behind |
| `terrain_palette.png` | 32×32 map-editor palette, one tile per terrain: the pack thing the game draws for it (`otsp_export.py palette`) |

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

**Floors** (`game/render/ground_art.gd`, `floor_layer.gd`) are drawn as Tibia draws them: each
terrain's pack ground (`GroundArt.GROUNDS`: grass, dirt, sand, snow, swamp, streets, planks ...)
picks its pattern by the cell's position so it tiles, and where a ground of higher priority meets a
lower one its border pieces lie over the lower cell (an edge along a side, a small corner, or a large
diagonal piece; grass over sand over water, dirt roads over grass, a stone kerb where a street meets
water). Floors are composed once per 16×16 chunk into an image, four images where water animates.
Houses have plank floors.

**Walls and rock** (`game/render/wall_art.gd`): a pack wall lies along its cell's east edge
(vertical) or south edge (horizontal) and rises up and left, so a wall cell shows its vertical piece
where the wall goes on north, its horizontal piece where it goes on west, the corner where both, and a
pole where it only starts or stands alone. `WallArt.WALLS` picks the style by place: stone with
windows in towns, yellow plaster in Sunreach, logs on the frost isles, brick in cellars, fieldstone
keeps, round-topped castle walls, dark stone in the Hollow Reach, stone blocks in other dungeons; each
style has its doors. Natural rock is a raised rock top with cliff pieces on its cells that face open
ground south or east (`GroundArt.ROCKS`: grey, snowy, sandy, and black-topped in caves). As in Tibia,
where mountains are built on two floors, rock shows its cliff only to the south and east: to the north
and west its flat top just ends in an earth rim on the open ground (`GroundArt.ROCK_RIMS`, grey rock
and caves). Ore veins are the ores' pack sprites set into the face.

**Roofs** (`game/render/roof_art.gd`) are the pack's roof tiles over each building's rectangle, the
north row the tiles with the ridge's edge, raised a tile up and left like a floor above: clay, red,
and shingle in the towns, blue slate in Reedmere, snow on the isles, sandstone in Sunreach. Roofs are
composed once per building and cached.

**Trees and objects** (`game/render/object_art.gd`): trees by terrain (`ObjectArt.TREES`: broadleaf
woods, dark Gloamwood trees, dry trees in the desert, as the pack has no palms or cacti, dead trees in
the Hollow Reach, giant mushrooms in the fen, firs on the isles), furniture by kind
(`ObjectArt.FURNITURE`), herb patches as the herbs' plants, signs and wall decorations as banners,
paintings, and wall torches, and waystones as a moss-grown shrine stone. Shops get a counter, potion
shelf, weapon rack, barrel, and crate; the bank a counter, bookshelves, and strongboxes
(`World.FURNISHINGS`, placed around the keeper at load). Furniture blocks movement and is skipped
wherever it would cut off part of the room or every tile in talking range.

**Roofs and signs.** `World.BUILDINGS` are the town rooms enclosed by walls with a door
(`game/data/buildings.gd`). `world_view.gd` draws each roof right after its building's south
wall row, so whoever stands south of it covers the eave, and fades it out while the local
character is inside (rooms or doorway). Names, bars, and glows of anyone under an opaque roof
are hidden. Signs hang on the wall beside a shop's or bank's door (`World.SIGNS`).

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
