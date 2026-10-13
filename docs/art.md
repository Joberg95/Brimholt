# Presentation and art

How the world is drawn, the sprite sheet layouts, and how to add or edit art.

## Presentation

The game window shows 15×11 tiles at 2× zoom and follows your character smoothly,
Tibia-style; the dedicated-server window centres the whole map. Walls are oblique:
their tops are raised up and to the left, and the world is drawn row by row so
walls nearer the camera (south/east) cover characters and items behind them.
Characters have compact adult proportions: an unarmoured silhouette is about 36 pixels
tall (previously 44–45), with a 3/4 view, a tinted hood and tabard, and a two-step walk.
**There is no default cape.** A cape is drawn only when an item occupies the cape slot,
including on NPCs and humanoid monsters.
Grass, dirt, sand, cobblestone, animated water, plank piers, stone walls, trees, worn
gear, and item icons are sprites too. Trees stand about two tiles tall and hide whatever
walks behind them. Only the visible part of the map is drawn each frame.

The visual direction is grounded, original classic-RPG pixel art: restrained earth colours,
directional shading in pixel clusters rather than checkerboard borders, broken foliage
canopies, weathered masonry, wood grain, and subdued water reflections. Item icons use
smaller silhouettes and quieter trim; metal, leather and cloth retain distinct tier hues.
Relic halos remain visible without bleaching out the equipment underneath. No artwork,
maps or character designs from Tibia are copied.

## Art and sprites

`assets/sprites` holds original PNG sprite sheets made by `tools/generators/make_sprites.py`
(Python standard library only). `game/render/sprite_art.gd` draws them with nearest
filtering:

| Sheet | Layout |
| --- | --- |
| `body.png`, `cloth.png`, `marker.png`, `gear/<item>.png` | 64×64 frames; columns stand / step A / step B / attack wind-up / strike; rows down / up / left / right; tile centre at frame pixel (32, 40). Monster sheets have only the first three columns |
| `items.png` | 32×32 icons in `SpriteArt.ITEM_ORDER` |
| `tiles.png` | 32×32 cells: 4 grass, 4 dirt, 4 water frames, dirt edges and shorelines (N, E, S, W), 4 sand, 4 cobblestone, 2 horizontal and 2 vertical plank tiles, 4 dusk soil, 4 obsidian flagstones, 4 cave floors, stairs down/up, then dry-grass fringes on sand (N, E, S, W; tiles 46–49) |
| `walls.png` | 48×48 oblique walls drawn 16 px up-left of their tile; index = open sides (1 N, 2 W, 4 S, 8 E); row 0 grey stone, row 1 obsidian, row 2 cave rock; row 3 thin town walls (`#`), indexed by connected sides (walls and doorways) instead, a 10 px masonry band through the tile centre |
| `roofs.png` | Per material row (clay, slate, wooden shingle) four 32×32 swatches: near slope, far slope, timber gable, trim (ridge cap, eave board, chimney stone). `game/render/roof_art.gd` rasterizes each building's roof from them |
| `furniture.png` | 32×48 shop and bank furniture drawn 16 px above their tile: shop counter, bank counter, potion shelf, bookshelf, weapon rack, barrel, crate, strongbox (`SpriteArt.FURNITURE` order) |
| `signs.png` | 32×32 hanging signs on an iron bracket: shop (flask and sword), bank (coins) |
| `torch.png` | 16×24 wall torches: unlit, then three flame frames; hung on the south faces of town buildings (`World.TORCHES`) |
| `objects.png` | 64×96 trees (three living, two dead for the Hollow Reach, then three desert plants: a columnar cactus, a barrel-cactus clump, and a thorn shrub for terrain `K`, then the waystone, a carved standing stone with a cyan rune); trunk base on the tile centre at cell pixel (32, 80) |
| `terrain_palette.png` | 32×32 map-editor palette, one tile per terrain |

A character is drawn as: main-hand item behind when facing up, side-facing shield behind,
body, tinted `cloth.png`, equipped cape, armour, helmet, front-facing shield, then the
main-hand item when not facing up. In the back view the cape goes **over** the armour.
Base body/cloth have neither cape fill nor cape outlines baked into them.
Gear sheets leave holes where the hood or near arm must stay visible, so each item
needs only one sheet rather than one per combination.

The generator applies `compact_humanoid` to every body, cloth and worn-item frame using
the same integer pixel mapping (80% authored height, feet anchored at frame y=53).
This is baked into the PNGs, not a runtime stretch. It keeps grips, masks, capes and
walk poses registered without altering the 64×64 frame or gameplay collision footprint.
Monster bodies keep their own proportions; humanoid monsters use the compact character rig.
Creature sheets (`monsters/<look>.png`, greyscale and tinted per monster, with an untinted
`_detail` sheet for eyes): `quadruped`, `spider` (eight jointed legs, a banded abdomen, red
eyes), `blob`, `golem`, `wraith`.
Glow masks are generated from the final compact sheets.

To edit art, change a PNG in Aseprite or another pixel editor, keeping its frame
layout, then reimport (open the editor or run `make import`). Running
`make sprites` (`python3 tools/generators/make_sprites.py`) regenerates **all** sheets and overwrites hand edits;
add `--preview .tools/sprite-preview.png` for a 2× review sheet. A new item needs a
catalog entry in `game/data/items.json`, an icon, and (if visibly equippable) a gear sheet loaded by
`game/render/sprite_art.gd`; the rules check verifies these exist.

## Items and gear

The user-selected theme reference is the [Tibia item index](https://tibia.fandom.com/wiki/Items)
([alternative category index](https://www.tibiawiki.com.br/wiki/Itens)). Use it for broad
equipment families and readability at small sizes, not as an asset source or a tracing guide.
Brimholt keeps its own silhouettes, ornament, names and palettes. Do not download, recolour,
trace or import reference sprites into the game.

Weapon proportion references also include [Tibia's hammer](https://tibia.fandom.com/wiki/Hammer)
and [sword families](https://tibia.fandom.com/wiki/Sword_Weapons), plus
[RuneScape warhammers](https://oldschool.runescape.wiki/w/Warhammer).
The references inform construction and readability only; all pixel geometry is original.

Items should look like crafted objects, not flat badges: wood and leather remain visible
under tier-coloured fittings; mail, overlapping scales, riveted brigandine and plate have
different construction; a hammer has a forged head rather than a mace's round head.
Keep ordinary equipment modest and reserve unusual ornament and restrained glow for relics.
Apply the same construction to inventory icons and worn layers without changing their stats.

Every item is a row in `game/data/items.json`, read by both the game and the generator:
`id`, `name`, `slot`, `level`, optional `vocations`, `look`, and `colors` (main, light,
accent), plus `glow` for relics and `gold` or `value` for coins and materials. The row
order is the icon order in `items.png`. `look` picks the drawing: helmets `cap`, `coif`,
`helm`, `kettle`, `greathelm` (decorate with `+plume`, `+crest`, `+horns`); armor `coat`,
`tunic`, `mail`, `scale`, `brigandine`, `plate`; weapons `sword`, `greatsword`, `axe`, `mace`, `hammer`, `bow`, `crossbow`,
`wand`, `rod`; off-hands `buckler`, `heater`, `tower`, `book`, `torch` (held up, flame swaying with the walk); and `cape`, `amulet`,
`charm`, `ring`. Tiers share fitting colours, but item construction should not be reduced
to a colour swap: bows retain timber limbs and books leather covers with page edges. Run
`python3 tools/generators/make_sprites.py --preview .tools/gear-preview.png` for a sheet
of every tier worn by each vocation.

Each cape sheet uses a visibility mask built from the character rig, with its own palette,
hem and clasp. Removing the equipped cape removes the whole layer; it does not reveal a
replacement cloak. Back-facing armour has its own complete back, visible without a cape.

### Weapon construction

`weapon_model` builds each weapon about a common grip: blade/head, socket/guard, haft and
wrapped handle are separate material surfaces. `pose_weapon` uses inverse nearest-neighbour
rasterization for the icon angle and worn poses, avoiding the diagonal gaps that forward
pixel stamping creates. The common model keeps the inventory silhouette and worn weapon
consistent; all body/gear layers then use the existing compact-rig mapping.

Steel edges stay narrow and light; lower-right faces stay darker. Hammers have clipped
striking faces, a neck/socket and an asymmetric peen or pick; heavy mauls keep bevelled ends
and a contrasting central band, rather than a flat rectangular head. Swords have tapered
points, a bevel/ridge or fuller, separate crossguards, leather grips and small pommels.
The hunting weapons add `sword+short|cleaver|fuller|curved|estoc`,
`hammer+peen|pick|maul`, `bow+flat|recurve`, `crossbow+arbalest`,
`wand+fork|cage`, and `rod+crook|root`. These are art variations, not new attack rules.

`make test-visual` writes `.tools/visual-weapons.png`: all 15 additions at native and 2x icon
size, alongside all four facings and three animation poses. It compares worn and empty hands
to verify each weapon remains visible. The unit checks verify padding, material colour
coverage, distinct hunting silhouettes, and unclipped worn frames for new and existing gear.

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
violet dusk). Pooled `PointLight2D`s follow players (lanterns, or a wider flickering torch light when a torch
is held; in a `dark` dungeon such as Silkhollow the lantern shrinks to 1.4 tiles), NPCs, town wall torches (lit from dusk, flickering), relic wearers, glowing
bosses and ground relics (coloured), missiles, and spell areas; lanterns fade in as the light
fades. `game/render/fx.gd` emits one-shot `CPUParticles2D` bursts for hits, critical hits,
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
Uncommon 10, Rare 20, Epic 30, Legendary 40; relics are Relic in their glow colour,
`Items.rarity`), shown on hover: `game/ui/item_slot.gd` colours the tooltip's name, rarity line,
and frame. Items you cannot use yet are tinted red.

**Thin walls and roofs.** Town walls (`#`) are thin: a masonry band through the tile centre,
joining neighbouring walls and doorways, with the outside ground and the room's floor drawn on
either side. Obsidian and cave walls stay full-tile blocks. Each building gets a pitched roof
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
lights and particles). Add a CC0 pack only with its original license file beside it and a row
in `assets/third_party/CREDITS.md`; never import ripped, proprietary, or Tibia-derived art.
