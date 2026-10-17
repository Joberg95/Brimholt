# Presentation and art

How the world is drawn, the sprite sheet layouts, and how to add or edit art.

## Presentation

The window scales the game by whole numbers only (`scale_mode="integer"`), and 2D transforms snap to
the pixel grid, so every art pixel is the same size on screen; a window between multiples shows a border.
The game window shows 15×11 tiles at 2× zoom and follows your character smoothly,
Tibia-style; the dedicated-server window centres the whole map. Walls are oblique:
their tops are raised up and to the left, and the world is drawn row by row so
walls nearer the camera (south/east) cover characters and items behind them.
Characters have stocky outfitter proportions (the Tibia outfitter is the reference for the feel,
nothing is copied): an unarmoured silhouette is about 38 pixels tall and 22 wide, the head
a full-size third of it with lit hair, a fringe, ears and a shaded jaw. They wear a tinted
collar and a tinted tunic with short sleeves, a belt, linen forearms, trousers, and boots, and
walk in two steps.
**There is no default cape.** A cape is drawn only when an item occupies the cape slot,
including on NPCs and humanoid monsters.
Grass, dirt, sand, cobblestone, animated water, plank piers, stone walls, trees, worn
gear, and item icons are sprites too. Trees stand about two tiles tall and hide whatever
walks behind them. Only the visible part of the map is drawn each frame.

The visual direction is grounded, original classic-RPG pixel art: restrained earth colours,
directional shading in pixel clusters rather than checkerboard borders, broken foliage
canopies, weathered masonry, wood grain, and subdued water reflections. Item icons use
smaller silhouettes and quieter trim; metal, leather and cloth retain distinct tier hues.
Relic halos remain visible without bleaching out the equipment underneath. Designs may imitate
Tibia closely, but no Tibia artwork files, maps, or client data are copied: every pixel is drawn here.

## Art and sprites

`assets/sprites` holds original PNG sprite sheets made by `tools/generators/make_sprites.py`
(Python standard library only). `game/render/sprite_art.gd` draws them with nearest
filtering:

| Sheet | Layout |
| --- | --- |
| `body.png`, `cloth.png`, `marker.png`, `gear/<item>.png` | 64×64 frames; columns stand / step A / step B / attack wind-up / strike; rows down / up / left / right; tile centre at frame pixel (32, 40). Monster sheets have only the first three columns |
| `items_anim/<id>.png` | 12 frames of 32×32 (0.1 s each) for items whose icon moves, drawn instead of the `items.png` cell (`SpriteArt.ANIMATED`): the showpiece helmets' flames, eyes and halo, and a white sheen sweeping across items with `"shine": "sheen"` in the first half of the loop (`icon_frames`, `_sheen`) |
| Bows | Hand-pixelled in `tools/generators/pixel_bows.py` (`BOW_STYLES` in make_sprites.py): on the diagonal, the limb arching toward the top-left from tip to tip and a straight string on the inner side; each bow its own length, arch (round, recurve with tips flicked out, or deflex with the grip set back), limb material, grip, tips (nock, curl, blade, feather, flame, icicle, horn), and ornaments (leaves, spikes, fins, gold bands, inlays, notches, cord wraps, a plated riser, gems, a crescent moon). The limb is shaded across its width, lit on its outer edge. Held like the painted bows (`painted_held`) |
| Wands and rods | Hand-pixelled in `tools/generators/pixel_staves.py` (`STAFF_STYLES` in make_sprites.py): each its own big head modelled on a classic wand or rod (an orb in claws, a ruby point, a volcanic club, a cobra fan, a skull, deepling fins, a sprout, golden antlers...), standing nearly upright on a thin two-pixel shaft that slants right toward the pommel; every part shaded as a rounded solid with rim light, gems faceted with a glint, a dark line between parts, a grained or wrapped shaft with gold ferrules. Held head first (`painted_held`). Painted wands and rods keep their art |
| Potions | Hand-drawn in `tools/generators/pixel_potions.py`: a slim egg-shaped bottle on the diagonal, cork to the upper left, the liquid's colour filling the glass, lit from the top-left (five tones), a white glint on the upper-left of the belly, a pale reflected rim, and an outline in the liquid's darkest tone. Stronger potions are bigger bottles: `potion` (vial), `potion+jar`, `potion+flask`. Health potions are red, mana potions magenta |
| Monster drops and gathered resources | Hand-drawn shapes in `tools/generators/pixel_materials.py` (`material_shape_icon`): one per kind of thing (tail, claw, tusk, fang, horn, feather, stinger, bone, skull, pelt, scale, chitin, eye, heart, censer, badge, sigil, crown, fetish, totem, charm, reliquary, coil, silk, sash, rosary, torc, shell, pearl, pincer, shard, core, ash, chunk, vial, gland, phylactery; ore, log, herb, fish), one letter per material (the item's colours, bone, flesh, gold, silver, wood, white, near-black), each material shaded as a rounded solid from the top-left with seams and an outline; shapes up to 14 pixels across are drawn at twice the size. Monster drops have the look `trophy+<shape>` |
| `coins.png` | Gold coin stacks, one 32×32 frame per size stage (`pixel_coins.STAGES`, matching `SpriteArt.COIN_STAGES`): one, two and three hand-drawn coins, a small heap, a heap with a second mound, and a big heap with loose coins (`tools/generators/pixel_coins.py`) |
| `items.png` | 32×32 icons in `SpriteArt.ITEM_ORDER`, 64 to a row (`ITEM_COLUMNS`, `item_cell`; one long row would pass the 16384-pixel texture limit). Showpiece helmets (looks in `HELM_STYLES`: `rootcrown`, `fangmask`, `dreadmask`, `hornhelm`, `crownhelm`, `lanternhelm`, `nimbus`, `visor`, `cobra`) are modelled in 3D and rendered with the props' look by `tools/generators/gear3d.py`: boxes, cylinders, ellipsoids and tapering tubes for horns and spikes, a camera in front and 22° above, top-left light, five-tone ramps with gloss on metal and gems, glowing eyes, flames and halos, a dark outline and seams. Swords and greatswords without a painted icon are hand-pixelled by `tools/generators/pixel_swords.py` (`sword_icon`), each to its own design named by its look (`sword+<style>`, `greatsword+<style>`: copper, short, falchion, longsword, arming, curved, cleaver, serrated, estoc, fang, sanguine; rime, drakefang, tide, void, grand). The blade is drawn row by row on the diagonal as a cross-section from its lit upper edge to its shaded lower edge (so 45-degree edges stay clean), with its own width along its length and extras (a sabre's bow, a wave, saw teeth, fangs, a hook); the guard is a cross, swept wings, a crescent, a disc, a lion mask, a spiked cross, or a trident; the pommel a ball, gem, ring, spike, or skull; gems glow on the leeching and relic blades. Held, they are the icon rebuilt into a weapon (`painted_held`). Showpiece axes (`AXE_WORN`: `hewer`, `amberaxe`, `venomaxe`, `seraphaxe`, `sanguineaxe`, `starsteelaxe`) are hand-pixelled in `tools/generators/pixel_axes.py`: rows of letters, one per pixel (outline, a five-step steel ramp from the bright cutting edge down, gold, the axe's own colour, a glowing gem, bone), the head at the top-left and a shared two-pixel diagonal haft with a wrapped grip down to a pommel. Double-headed axes mirror their `wing` rows across the haft. Held, they are the icon rebuilt into a weapon (`painted_held`). Edit the rows to change the art. Necklaces (look `necklace+<pendant>`: `pendant`, `disc`, `flame`, `crescent`, `star`, `fang`, `heart`, `skull`, `beads`, `eye`) are drawn by `tools/generators/pixel_necklaces.py`: a chain of links (or beads) round a tilted loop, its back half in shadow, a gold clasp, and a hand-drawn pendant shaded like the backpacks; the heart and flame cores pulse. Themed backpacks (look `backpack+<style>`: `adventurer`, `lilypad`, `pillow`, `sailor`, `winged`, `ghost`, `holding`) are drawn in `tools/generators/pixel_bags.py` in the classic icon view, from slightly above and to the left: a hand-drawn map of the backpack's parts (handle, domed lid, front, right side, pocket and flap, side pocket, straps, buckles) that code shades from the top-left light with each part's own curvature, in five-tone ramps with a leather grain, a dark outline and darker seams between parts; each style's details (wings, skull, lily, bedroll, rope, anchor, gold trim) are hand-drawn part maps on top (`backpack_icon`). Showpiece boots (`BOOT_WORN`: `wingboots`, `furboots`, `flameboots`, `frostboots`, `vialboots`, `scaleboots`, `bloomboots`) are a pair seen from the side, toes left, the far boot a step behind, modelled the same way at 1.25x (`gear3d.boots`). Worn, helmets take `HELM_WORN`'s generated helmet textured with the icon; boots are too small for that and are `BOOT_WORN`'s generated boots in the item's own colours with the details their look names (`furcuff`, `wings` at the ankles, `blaze` flames above the cuff, `bloom`, a `glow`ing stone, `trim`, `spikes`). derive_icons.py leaves them alone. Rings (`ring_icon`) are small tilted bands, about 15 pixels across: the top face lit from the top-left, the outer wall showing at the front and the inner wall in shadow at the back, and a centrepiece on top from the look's style (`ring+gem`, `signet`, `plasma` beads, `wreath`, `serpent`, `claw`, `skull`, `twin` bands, `crystal`, `star`), in the item's metal colours with its accent as the stone |
| `spells.png` | 32×32 rune stones, eight per row in `Spells.SPELLS` order: a weathered stone (its outline varies per spell) with the spell's Elder Futhark rune (`Spells.RUNES`, strokes in `RUNE_STROKES`; two Anglo-Saxon runes, Ear and Yr, past the twenty-four) carved in and glowing in the spell's colour |
| `world_map.png` | The painted world map, 4 px per overworld tile, baked by `tools/generators/world_map.gd` (not `make_sprites.py`): sea with shallows and surf, land with soft variation, forest canopy clumps, lit and shaded ridges, roofs in towns. `world_map.json` holds the map hash it was baked from |
| `rune_fx.png` | 32×32 frames of a spell or rune landing (`rune_fx`), one row per element (`Spells.ELEMENTS`: fire, frost, lightning, holy, nature, slash, pierce, heal, death, ice_wall), four frames each: flame tongues that bloom and die to embers, ice shards that rise and shatter, a forked bolt that scatters sparks, golden rays round a bright core, thorny tendrils in a burst of leaves, a pale sword arc, an arrow's strike with splinters, green motes rising, a pale violet skull out of black smoke (Sudden death, Soulfire), and a block of faceted ice with crystal points that rises, shimmers, and cracks (Glacier wall: `SpriteArt.HELD_FX` hold frames 1-2 for the effect's whole `life`). Drawn on every tile hit (`SpriteArt.draw_rune_fx`), 6 px up so they stand on the tile; bolts and shots play theirs on the target when they land |
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

The rig is authored tall and slim: a 10-pixel head, a 12-pixel torso, 3-pixel arms (`ARM_W`)
hanging at x 23–25 and 38–40, and 3-pixel legs (`leg_parts` is shared by the body and by
worn legs and boots so they line up). The generator applies `compact_humanoid` to every body, cloth and worn-item frame using
the same integer pixel mapping: rows below the neck (`NECK`) are squashed to 80% towards the
feet at frame y=53 while the head and headgear keep full size, and rig columns 29 and 34
(`WIDEN`) are drawn twice, so head, chest and hips are two pixels wider and outlines stay one
pixel thick. Rig rows 25, 31, 35, 41, 45 and 51 fall out in the squash; put details elsewhere.
This is baked into the PNGs, not a runtime stretch. It keeps grips, masks, capes and
walk poses registered without altering the 64×64 frame or gameplay collision footprint.
Monster bodies keep their own proportions; humanoid monsters use the compact character rig.
Mounts have two sheets each, `mounts/<id>.png` drawn under the rider and `mounts/<id>_front.png`
over it (a steed's head and forelegs facing you, its tail from behind), stand / step A / step B by
four facings, feet at y=53 (`mount_frames` in `make_sprites.py`). Four shapes take the item's
colours (hide, light, mane or saddle cloth): `steed`, `wolf`, `spider`, `lizard`, decorated by
`+antlers`, `+tusks` (a boar) and `+tail` (a rat). The rider is drawn in its standing pose
`RIDER_LIFT` pixels up by shape (steed 10, spider 9, wolf and lizard 6; one more on step
frames) and, facing toward or away from you, only above frame row `RIDER_CUT` (45), so it sits
astride. `SpriteArt` keeps both constants in step with the generator. The item icon is the side
view shrunk to 32 pixels (`mount_icon`).
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
template of the same kind (`TEMPLATES`, plain to ornate by level; a catalog `template` names a
specific painted icon instead, as the mythic sets do), recoloured to the item's
catalog colours: outlines and wood stay, gold trim takes the accent colour, and everything else
follows its brightness on a ramp from the main to the light colour. Tier helmets, armour, legs,
and boots without their own painting, the mythic sets included, are new designs in the painted
style (`armor_bases`): bands of two or three painted pieces of the same slot and armor type (another
type's when none fit) stacked where their edges meet cleanly (`BANDS`: a helmet's crown over
another's face; body armour's shoulders, belly, and skirt; legs' hips, thighs, and shins; boots'
shafts and feet), near the item's level, every combination used once, then recoloured. Drawing armour from code (part maps or 3D solids)
was tried and fell short of the painted look, so armour stays painted-derived. They are written to `assets/sprites/icons_derived/` every run. The extra templates
(`template_*` icons) come from the unused weapon and off-hand cells of `class_sets.png` and the
single pieces of `class_pieces.png`. Rings, axes, maces, hammers, crossbows, torches, capes, packs,
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

**Icon volume.** Icons not already shaded with volume (`needs_volume`: everything but the 3D showpieces, axes, backpacks and necklaces) go through `icon_volume` first: each pixel's distance from the silhouette makes a dome, and the top-left light on it shifts the pixel's own colour by whole shade steps (`VOLUME_STEP`), so flat icons read as solids without gradients.

**Icon finishing.** Every icon goes through `icon_finish` in `make_sprites.py` on its way out:
generated cells of `items.png`, every `items_anim` frame, the derived icons (`derive_icons.py`), and
the painted icons. It gives all of them one dark outline (`ICON_OUTLINE`; an outline is added where
an edge was bright, never doubled), stretches a flat icon's contrast towards `CONTRAST_SPAN`, and,
except on painted icons (finished in place, so only the repeatable steps), adds a lit inner rim on
the top-left and a shaded one on the bottom-right with a touch more saturation. Item slots show
icons at their full 32 pixels (`Layout.SLOT_SIZE`): any smaller and nearest filtering drops rows
and columns of pixels.


The user-selected theme reference is the [Tibia item index](https://tibia.fandom.com/wiki/Items)
([alternative category index](https://www.tibiawiki.com.br/wiki/Itens)). Use it for broad
equipment families, silhouettes, ornament, and palettes: items may imitate its art closely (the
owner's decision, 2026-10-16), but names stay our own. It is a model to draw from, not an asset source: do not
download, recolour, trace or import reference sprites into the game.

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
the one non-CC0 asset, allowed by the owner. Add a CC0 pack only with its original license file beside it and a row
in `assets/third_party/CREDITS.md`; never import ripped or proprietary art files (Tibia's included).
