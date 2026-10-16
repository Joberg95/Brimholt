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
| `spells.png` | 32×32 rune stones, eight per row in `Spells.SPELLS` order: a weathered stone (its outline varies per spell) with the spell's Elder Futhark rune (`Spells.RUNES`, strokes in `RUNE_STROKES`; two Anglo-Saxon runes, Ear and Yr, past the twenty-four) carved in and glowing in the spell's colour |
| `world_map.png` | The painted world map, 4 px per overworld tile, baked by `tools/generators/world_map.gd` (not `make_sprites.py`): sea with shallows and surf, land with soft variation, forest canopy clumps, lit and shaded ridges, roofs in towns. `world_map.json` holds the map hash it was baked from |
| `rune_fx.png` | 32×32 frames of a spell or rune landing (`rune_fx`), one row per element (`Spells.ELEMENTS`: fire, frost, lightning, holy, nature, slash, pierce, heal), four frames each: flame tongues that bloom and die to embers, ice shards that rise and shatter, a forked bolt that scatters sparks, golden rays round a bright core, thorny tendrils in a burst of leaves, a pale sword arc, an arrow's strike with splinters, and green motes rising. Drawn on every tile hit (`SpriteArt.draw_rune_fx`), 6 px up so they stand on the tile; bolts and shots play theirs on the target when they land |
| `spell_missiles.png` | 16×16 projectiles (`spell_missile`), one row per element (fire, frost, lightning, holy, nature, pierce), four frames each, pointing right and drawn turned toward the target (`SpriteArt.draw_missile`): an ember trailing sparks, an ice shard, a crackling spark, a holy orb in a halo, a spinning thorn, and an arrow |
| `tiles.png` | 32×32 cells: 4 grass, 4 dirt, 4 water frames, dirt edges and shorelines (N, E, S, W), 4 sand, 4 cobblestone, 2 horizontal and 2 vertical plank tiles, 4 dusk soil, 4 obsidian flagstones, 4 cave floors, stairs down/up (`stairs_tile`: a stone-framed stairwell, used in towns), dry-grass fringes on sand (N, E, S, W; tiles 46–49), 4 gravel, a cave hole (`cave_hole_tile`, tile 54: the way down anywhere outside a town), then 4 cellar floors (`cellar_floor_tile`, tiles 55–58: dark brick in cellars), then kerb stones (`curb_overlay`, tiles 59–62: north, east, south, west) drawn on a cobbled street's side that meets grass, dirt, sand, trees, or bog, then 4 bog mud (`bog_tile`, tiles 63–66: dark peat with wet glints, reed stubble, and murky puddles), then 4 snow (`snow_tile`, tiles 67–70: soft drifts with blue shadows and sparkles) and 4 snowy cobbles (`snow_cobble_tile`, 71–74: snow packed into the joints) for the frost isles. Grass (`grass_tile`) is a living mid green in the OpenTibia manner: soft clumps and blade tufts with lit tips |
| `cellar_walls.png` | The 16 house wall shapes of `house_walls.png` (`thin_wall` with `CELLAR_STONE`) in dark red-brown brick, for dungeons with `"theme": "cellar"` |
| `walls.png` | 48×48 oblique walls drawn 16 px up-left of their tile; index = open sides (1 N, 2 W, 4 S, 8 E); row 0 grey stone, row 1 obsidian, row 2 cave rock (dungeons), rows 4 and 5 (blocky cliffs and outcrops) are kept but unused on the overworld; row 3 thin town walls (`#`), indexed by connected sides (walls and doorways) instead, a 10 px masonry band through the tile centre |
| `roofs.png` | Per material row (clay, slate, wooden shingle) four 32×32 swatches: near slope, far slope, timber gable, trim (ridge cap, eave board, chimney stone). `game/render/roof_art.gd` rasterizes each building's roof from them |
| `firs.png` | 64×96 snow-laden firs (`snowy_fir`), 3 variants drawn like trees for `P` in the frost isles: tiers of dark boughs loaded with snow on the lit side |
| `log_walls.png` | The house-wall shapes (`thin_wall`) in timber courses under a cap of snow: house and palisade walls (`#`) in the frost isles |
| `mushrooms.png` | 64×96 giant mushrooms (`mushroom`), 3 variants drawn like trees for `U` in Mirewood Fen: a pale stalk and a broad spotted cap |
| `furniture.png` | 32×48 furniture drawn 16 px above its tile, painted like the creatures from 3D solids (`tools/generators/props.py`: boxes, cylinders, and ellipsoids under the same camera and top-left light, five-tone ramps, wood grain and plank seams, gloss on metal and glass, glowing flames and lantern glass, coloured outlines): shop counter, bank counter, potion shelf, bookshelf, weapon rack, barrel, crate, strongbox, anvil, workbench, cauldron, loom, hearth, then home furniture: bed, table, chair, potted plant, chest, then street furniture: lamp post, well, bench, market stall, then a stall and a bench seen from behind (`props.furniture("stall_back")`: any kind turned round) (`SpriteArt.FURNITURE` order) |
| `fountain.png` | Four 96×112 frames of the town square's three-tier stone fountain (`props.fountain`): a round basin of stone blocks with a rippling pool, two bowls on a pedestal, and drops falling bowl to bowl a step lower each frame (6 fps). Drawn from the bottom-middle of the 3x3 tiles it blocks (`"fountain"`; the other eight are `"fountain_basin"`) |
| `signs.png` | 32×32 hanging signs on an iron bracket, painted from 3D solids (`props.sign`) with the board turned to the viewer: shop (flask and sword), bank (coins), workshop (hammer and green flask) |
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

A character is drawn as: main-hand item behind when facing up, side-facing shield behind,
body, legs, boots, tinted `cloth.png`, equipped cape, armour, helmet, front-facing shield, then the
main-hand item when not facing up. In the back view the cape goes **over** the armour.
Base body/cloth have neither cape fill nor cape outlines baked into them.
Gear sheets leave holes where the hood or near arm must stay visible, so each item
needs only one sheet rather than one per combination.

The rig is slim, after classic 32-pixel outfits: a 10-pixel head, a 12-pixel torso, 2-pixel
arms hanging at x 24–25 and 38–39, and 3-pixel legs (`leg_parts` is shared by the body and by
worn legs and boots so they line up). The generator applies `compact_humanoid` to every body, cloth and worn-item frame using
the same integer pixel mapping (80% authored height, feet anchored at frame y=53).
This is baked into the PNGs, not a runtime stretch. It keeps grips, masks, capes and
walk poses registered without altering the 64×64 frame or gameplay collision footprint.
Monster bodies keep their own proportions; humanoid monsters use the compact character rig.
Creatures have one sheet each, `creatures/<monster>.png` (untinted; stand, step A, step B by
four facings), made by `tools/generators/creatures.py`: each species is built from simple 3D
anatomy (ellipsoid body, head, jointed limbs, tails, horns, crowns ...) and rendered for every
facing and walk frame with the painted look of the gear art: top-left light posterized into a
five-tone ramp per material (warm lights, cool shadows), gloss on chitin and slime, textures
(fur strokes, stone slabs and cracks, glowing ember seams, warts, scales), emissive eyes and
cores, a coloured silhouette edge, and dark seams where parts overlap. Builders: `quadruped`
(voles, rats, the Rat King's crown, boars with tusks and spines, wolves with a ruff, the
reedfang lizard, the thornscale basilisk, and the Ashmaw drake's swept horns and beating wings:
a bony edge with a membrane sail under each bone), `beetle`, `spider` (the dune scorpion's curled tail and pincers), `toad`, `slime`, `golem` (stone, moss, ember, obsidian,
Forgemaw's and Kharzul's horns and burning maws), `wraith` (Sylvaine's flowers and antlers; the harpy's feathered wings), and
`biped` (the skeleton, ghoul, robed Abbot, and the Barrow lich's crown), and `giant` (cyclopes;
the Rime titan's shoulder crystals; trolls' two eyes, brow, and tusks). `SPECIES` sets each one's proportions and
materials and `ZOOM` its on-screen scale; `creatures/<monster>_glow.png` halos only the bright
parts of glowing creatures. Armed humanoids (bandits, archers, knights, Vaelith, Morvain) still
wear catalog gear. The old tinted `monsters/<look>.png` sheets remain as a fallback.
Glow masks are generated from the final compact sheets.

To edit art, change a PNG in Aseprite or another pixel editor, keeping its frame
layout, then reimport (open the editor or run `make import`). Running
`make sprites` (`python3 tools/generators/make_sprites.py`) regenerates **all** sheets and overwrites hand edits;
add `--preview .tools/sprite-preview.png` for a 2× review sheet. A new item needs a
catalog entry in `game/data/items.json`, an icon, and (if visibly equippable) a gear sheet loaded by
`game/render/sprite_art.gd`; the rules check verifies these exist.

## Painted outfits

The named class sets can be shown as painted full figures instead of generated layers.
`art/outfits/` holds the source paintings (`class_sets.png` and `class_pieces.png` were generated
and supplied by the project owner as the gear design reference) and `manifest.json`. Its
`icon_rows` take loose icons from a region split into equal columns (`class_pieces.png` gives
the helmet, armor, legs, and boots icons of tiers 5–20). An entry with `"grid": [columns, rows]`
and no region splits the whole image into cells, one item per cell in reading order;
`icons_<group>_<n>.png` sheets (4×4) cover every other item and are skipped until their PNG
exists, so painted icons can arrive a sheet at a time. Items without a painted icon get one derived
from the painted art (`tools/generators/derive_icons.py`, run by `make outfits`): a painted
template of the same kind (`TEMPLATES`, plain to ornate by level; for helmets, armor, legs, and
boots the nearest-tier painted piece of the same slot and armor type; a catalog `template`
names a specific painted icon instead, as the mythic sets do), recoloured to the item's
catalog colours: outlines and wood stay, gold trim takes the accent colour, and everything else
follows its brightness on a ramp from the main to the light colour. Rings lose the template's
dark middle. They are written to `assets/sprites/icons_derived/` every run. The extra templates
(`template_*` icons) come from the unused weapon and off-hand cells of `class_sets.png` and the
single pieces of `class_pieces.png`. Axes, maces, hammers, crossbows, torches, capes, packs,
potions, food, gathered resources (looks `ore`, `log`, `herb`, `fish`, `food`), and most materials have no template yet and keep their generated `items.png` cell.

Worn helmets, armor, legs, and boots with a painted icon wear that icon like a paper doll
(`textured` in `make_sprites.py`): in every pose the icon is shrunk (area-averaged, with a little
extra contrast) into the bounding box of the generated piece after `compact_humanoid`, and
clipped to the generated silhouette so the face, arms, and the gap between the legs stay. The
side view uses the icon's middle 70%; the back view the mirrored icon, darker, with its dark
openings (faces, visors) filled. `make outfits` regenerates the sheets, so new icons change the
worn gear too. Capes wear their icon the same way (the back view is the icon), and so do shields and
spellbooks (the face from the front, a slice edge-on). A weapon with a painted icon is
rebuilt from it (`painted_model`): the icon's long axis is found from its pixels, stood upright
with its upper end as the tip, and fitted to the generated model's length, so the grip and
every swing stay where they were. Its `outfits` list each painted figure: the
source file, the `figures` region and the facings in it (`order`), the `layout`, and optionally
an `icons` region whose icons (left to right) replace the generated icons of `icon_items`.
`make outfits` runs `tools/generators/import_outfits.gd`, which separates each figure from its
background, scales the outfit with one factor (the first figure becomes `figure_height`, 40
pixels), adds a dark outline, and writes `assets/sprites/outfits/<id>.png` (the same 64×64
pose/facing layout, feet at y=53) and `assets/sprites/icons/<item>.png` (32×32).

- `"layout": "strip"`: one standing figure per facing. Steps bob a pixel and attacks lean toward
  the facing. This is what the current sheet provides.
- `"layout": "grid"`: one row per facing (in `order`), five poses per row: stand, step A,
  step B, attack wind-up, strike. A missing left or right row is mirrored from the other.

An armor row's `"outfit"` names the sheet: wearing that armor draws the outfit instead of the
body, cloth, legs, boots, cape, armor, and helmet layers; weapons and shields are still drawn
at the usual hands. Pieces of the set worn with other armor use their generated layers.

**Requesting new outfit art.** One PNG per set, transparent or a flat single-colour
background, nothing else in the picture (no text, frames, shadows, or ground). Four rows
(facing the viewer, facing away, facing left, facing right) by five columns (standing, left
foot forward, right foot forward, weapon raised, weapon swung down), all at the same scale with
feet on one baseline per row, in the set's style, empty-handed (the game draws weapons and
shields). Add the set to `manifest.json` with `"layout": "grid"` and run `make outfits`.

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
`helm`, `kettle`, `greathelm`, `hood`, `hat`, `ranger`, `circlet`, `cowl`, `bearhood`, `staghelm`
(decorate with `+plume`, `+crest`, `+horns`, `+spikes`, `+feather`, `+wings`, `+stars`, `+flames`,
`+leaves`, `+flowers`, `+fur`, `+antlers`); armor `coat`, `tunic`, `leather`, `robe`, `mail`, `scale`, `brigandine`, `plate`
(decorate with `+fur`, `+pelt`, `+spikes`, `+trim`, `+flames`, `+leaves`, `+flowers`, `+runes`);
legs `legplates`, `chausses`, `breeches`, `leggings` and boots `sabatons`, `striders`, `boots`,
`slippers` (decorate with `+trim`, `+spikes`, `+fur`, `+leaves`, `+flames`, `+runes`); helmets,
armor, legs, and boots also carry an `armor` type (`plate`, `mail`, `leather`, `cloth`) whose shapes should
read at a glance: plate is brute steel, mail bear fur over rings, leather antler and leaf,
cloth a warlock's flame-hemmed robe; weapons `sword`, `greatsword`, `axe`, `mace`, `hammer`, `bow`, `crossbow`,
`wand`, `rod`; off-hands `buckler`, `heater`, `tower`, `book`, `torch` (held up, flame swaying with the walk); and `cape`, `amulet`,
`charm`, `ring`. Tiers share fitting colours, but item construction should not be reduced
to a colour swap: bows retain timber limbs and books leather covers with page edges. Run
`python3 tools/generators/make_sprites.py --preview .tools/gear-preview.png` for a sheet
of every tier worn by each class.

Each cape sheet uses a visibility mask built from the character rig, with its own palette,
hem and clasp. Removing the equipped cape removes the whole layer; it does not reveal a
replacement cloak. Back-facing armour has its own complete back, visible without a cape.

### Weapon construction

Held weapons are posed from `WEAPON_ANGLES` (per grip style: melee, wand, staff, bow, crossbow)
and held at `GRIP_AT`, a share of their length from the bottom: blades and axes by the hilt,
wands near the end, staves a little below the middle (the foot by the boots), bows in the
middle. A skin-toned fist is drawn over the grip whenever the weapon is in front of the body.
Walking, blades rest angled out from the hip; side-on they lean forward across the chest
and staves lean back over the shoulder. The attack wind-up raises the hand to shoulder height
and the strike swings it forward and low. Painted weapons are drawn at `LENGTHS` pixels.

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
violet dusk). Pooled `PointLight2D`s follow players who hold a torch (a wide flickering light; without one a
player carries no light, so a `dark` dungeon such as Silkhollow is pitch black), NPCs, town lamp posts (lit from dusk), relic wearers, glowing
bosses and ground relics (coloured), missiles, and spell areas; lights fade in as the light
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
lights and particles). Add a CC0 pack only with its original license file beside it and a row
in `assets/third_party/CREDITS.md`; never import ripped, proprietary, or Tibia-derived art.
