# 46 - Brimholt direction: modern-Tibia feel (art, world, floors, hunts, quests)

**Effort:** XL (umbrella plan; phases split into their own plans as they start)

Status: direction agreed and Phase 0 decided, no code changed yet (2026-10-21). See
"Phase 0 decisions" below.

## Goal

Every sprite in Brimholt should look like it came out of **modern Tibia (12+)**: same projection,
proportions, outlines, saturation, contrast, and level of detail. The pixels, designs, and content are
our own (Brimholt's flavour). Guiding rule: **match the style; every design is our own.**

"Done" means: put a Brimholt screenshot next to a modern Tibia screenshot and nothing in ours reads as a
different game, and nothing in ours reads as a different *generation* of art next to its neighbours.

## Why the art looks off today

1. **The rules point the wrong way.** `.github/skills/art-direction/SKILL.md` and `docs/art.md` ask for
   "restrained earth colours", low saturation, no pure black, saturation only for relics/magic. Tibia is
   the opposite. Assets that follow the rules faithfully still don't look like Tibia.
2. **Three generations of art are mixed.** Old flat tiles and brick cubes, the newer "art pass" assets
   (grass, cobbles, house walls, mountains, painted creatures), and hand-pixelled icons sit side by side.
3. **Procedural generation caps the quality.** All art is drawn by Python (`tools/generators/*.py`).
   Modern-Tibia detail is very hard to reach that way without hand-made references to copy.

## Style spec (modern Tibia 12+)

| Aspect | Target |
| --- | --- |
| Grid | 32×32 tile. Big creatures and objects are 64×64 (2×2), anchored bottom-right like Tibia. 15×11 visible tiles (already matches) |
| Projection | Oblique for **everything that stands**: height goes up and to the left. Characters and creatures are drawn in 3/4 view in four directions, not flat front/side |
| Light | Hard top-left key light. Bright highlights, dark core shadows, clear form |
| Colour | Saturated and high-contrast everywhere: lush greens, deep blues, warm sandstone, rich outfit colours. Not only for relics |
| Outlines | Dark (near-black, slightly hue-tinted) outline around the full silhouette of creatures, characters, and items. Internal lines softened by colour (selective outline) |
| Shading | Smooth multi-tone ramps (6–10 tones per material), careful anti-aliasing on curves, no checkerboard dither, no pillow shading |
| Detail | Dense and readable: mortar and chipped bricks, moss, grain, rivets, folds, grass with flowers and pebbles |
| Characters | Chunky outfitter proportions filling ~32×32 (big head, broad shoulders, short legs). Outfit split into four tintable layers (head / body / legs / feet) plus addon pieces |
| Ground | Rich textured ground with soft natural transitions (Brimholt does this with `terrain.gdshader` blending instead of Tibia's border tiles; keep that) and animated water with shore foam; built floors (cobble, planks, flags) keep hard kerbed edges |
| Items | 32×32 icons, same art on the ground and in the inventory, full outline, strong highlight |
| Effects | Big, bright, saturated spell and hit effects, tile-based |

### Our flavour (what makes it Brimholt, not a Tibia clone)

- Original creature designs, gear sets, relics, towns, and regions.
- A colour identity per region (e.g. Mirewood Fen, Sunscar Dunes, Frost Isles, Hollow Reach) on top of
  the shared style.
- Original UI frame and icons that echo Tibia's layout but use our motifs.

### Flavour pillars (owner, 2026-10-21)

1. **Runes and old stone.** An old English and Norse borderland: *-holt*, *-mere*, *-fell*, *-wick*,
   barrows, and waystones. Magic is carved into stone, so recurring motifs are runestones, glyphs, and
   knotwork on gear and doors.
2. **Ember against reed.** The world swings between fire country (Cinder Crossing, Smoulder Fells,
   Emberwaste) and wet country (Reedmere lake, Lurkmoor, Fernmere, Mirewood Fen). The signature colours
   are ember orange against reed green and deep lake blue.
3. **The land that wakes.** Old things stir: hills that stand up (Golemback), peaks where the stone
   walks, barrows, and dead that still march. The motif is mossy stone with glowing seams, as if the
   ground itself is alive.
4. **Grey castles in a wild land.** Capitals are thick grey castles with a warm inside (hearth light,
   banners); everything outside the walls is wild and overgrown. The contrast is cool stone against warm
   interiors.
5. **The Hollow creeps in.** The endgame enemy is the Hollow: the Hollow Reach, the Hollow March, the
   Void Throne. Violet and obsidian belong to it alone and appear more often the closer a place is to
   the endgame.

## Character model (the most important asset)

The player character is what you look at all game, so it has to feel like a Tibia outfit first.

### Best reference we already have
`art/outfits/class_sets.png` (Crimson Aegis, Verdant Spirit, Arcane Eclipse, supplied by the owner) is
already very close to the target: saturated, chunky, fully outlined, 3/4 view, strong top-left light,
dense detail. **Use these painted figures as the golden reference for the character model.** The
generated rig in `body.png` / `cloth.png` / `gear/*` does not match them; the painted figures win.

### Today vs target

| Aspect | Today (`game/render/sprite_art.gd`, `body.png`) | Target (modern-Tibia feel) |
| --- | --- | --- |
| Canvas | 64×64 frame, anchor (32, 40), feet at y=53 | Keep 64×64 frame (outfits with addons/weapons overflow 32×32 in Tibia too), but the **body** fills about one 32×32 tile and is drawn offset up-left so the feet sit on the tile in the oblique view |
| Size and build | ~22 wide × 38 tall, slim, small head | Chunky: ~26–30 wide × ~32–34 tall unarmoured, big head (~40% of height), broad shoulders, short legs, big hands and boots, like the painted class sets |
| View | Flat front, back, and side | 3/4: the down-facing figure shows a bit of its right side, the side views show a bit of the chest; same angle as the walls |
| Outline | None on the body; dark tunic vanishes on dark ground | Full dark silhouette outline (hue-tinted near-black), selective lighter inner lines, readable on any ground |
| Colour | Muted cloth, brown hair | Saturated outfit colours; four **tint layers** (head, body/primary, legs/secondary, feet/detail) like Tibia's outfitter, from a fixed outfit palette |
| Directions | down / up / left / right | Same four. Diagonal movement shows the side view, as in Tibia |
| Walk | Two steps (stand, step A, step B) | Four-frame walk cycle (decided), matched to the tile-step speed so feet don't slide; optional idle breathing |
| Attack | Wind-up and strike frames | **Decided:** keep a short, subtle swing (Brimholt flavour; shows off visible weapons). Missiles, hit effects, and numbers still carry the attack, as in Tibia |
| Equipment | Helmets, armour, legs, boots, capes, both hands drawn on the body (375 gear sheets) | Keep: visible gear is Brimholt's flavour (Tibia only shows outfits). Each gear sheet must sit exactly on the new chunky body and follow the painted-set style. Full named sets can show as one painted figure (`art/outfits`, already supported) |
| Addons | None | Optional: addon layers (e.g. a hat, a pauldron, a backpiece) earned from quests (fits plan 22, quest outfits) |
| Mounts | `mounts/*` (30) | Rider sits on a 64×64 mount, same outline and saturation as creatures |
| Overhead | Name and bars | Tibia-style: name in the player's colour, a small health bar (and mana for self) just above the head, skull icons beside it |

### Character preview window (outfitter)

Add or restyle a Tibia-style outfit window, opened from the character window (C) and NPC outfitters:
- A large preview of your character on a ground tile, at 2–4× zoom, with arrows to turn it through the
  four directions and a toggle to play the walk cycle.
- Colour pickers for head / body / legs / feet from the outfit palette.
- Outfit list (class base outfits, quest outfits), addon checkboxes, and a mount toggle.
- Shows the gear you're wearing on the figure, so it matches what other players see.
- The same preview figure appears in the character-select screen and next to the paperdoll.

### Order of work for the character
1. Paint one unarmoured base body in the new build (four directions, stand + walk) matching the painted
   class sets. This is golden sprite #1.
2. Paint one full set of tier-1 gear on it (helmet, armour, legs, boots, a sword, a shield), checking layer
   order in all four directions.
3. Decide the attack-animation question and the walk frame count.
4. Rebuild the gear generator to fit the new body (or switch the most-used tiers to painted sheets), then
   regenerate all 375 gear sheets and re-anchor in `sprite_art.gd`.
5. Build the outfit/preview window.

## Floors (world layers)

Brimholt now has Tibia-style floors (plans 44/45, 2026-10-20): an underground plane under the mainland
(`Atlas.UNDERGROUND`, `Atlas.below(x, y)`) with tunnels, sewers, and moved caves, joined by holes,
ladders, and stairs (`World.HOLES`), and the world map switches floors. Each floor is currently its own
plane; you see only the floor you stand on.

What makes floors *feel* like Tibia, and what the art needs for it:

| Tibia feel | Art / rendering needed | Status |
| --- | --- | --- |
| Holes, ladders, stairs, ramps read instantly | `tiles.png` ways down/up (44–46, 54) restyled to the new outline/saturation; add ramps and rope spots if used | Exists, restyle |
| Underground is darker and moodier, lit by your light | Underground palette ramps (cave earth, cave rock, sewer brick, sewer water) a step darker and cooler than the surface; light radius does the rest | Partly (dim zones) |
| Sewers look like sewers | Brick walls, channels with dirty water, grates, pipes, rats; consistent with `cellar_walls` | Restyle |
| Floors **above** ground: house upper storeys, towers, castle walls you walk on, mountains you climb | Upper-floor floor tiles, wall tops you can stand on, stairs up inside buildings | Future (only one floor below exists) |
| Upper floors and roofs **hide** when you're under them | Roof and upper-floor fade/hide rule in the renderer; roofs drawn per floor | Future, needs floors above |
| Looking down from a height shows the floor below, shifted one tile up-left per floor and darkened | Render lower floors under transparent/void cells with a per-floor offset (Tibia: 32 px up-left per floor) and dim | Future, design decision |
| Stacked visual parallax only applies to *visible* lower floors | Void/rock cells on a floor must be fully opaque so nothing leaks through | Check |

Decisions for later: do we add floors above ground (needed for roof-hiding and looking down), and do
we render lower floors through openings Tibia-style, or keep one floor visible at a time?

## World size and how we build it

### The real gap with Tibia
Brimholt's overworld is already 1920×1920 (`Atlas.OVERWORLD_SIZE`), about the size of Tibia's surface
(roughly 2,000–2,500 tiles across, much of it sea). The gap is not the frame, it is:

| | Tibia | Brimholt today |
| --- | --- | --- |
| Surface painted | Most of the frame, densely | Mainland 640×640, frost isles, Silverwood, first islands in progress |
| Floors | 16 (7 above ground, 8 below + surface) | 2 (surface + one underground plane) |
| Floors in the engine | A real z coordinate | Planes laid **beside** the overworld (`Atlas.UNDER_X` = 2560, `Atlas.below(x, y)`); a second floor below needs another plane |
| Density | Something every few tiles: landmarks, houses, caves under most hills | Large generated fills; plans 40/43 ask for "no empty filler" |
| Build process | One map editor (RME) with brushes, hand-mapped | One-shot generators per expansion (`mainland.gd`, `orcs.gd`, `underground.gd`, `caves_below.gd`, `relocate.gd`, …), moves with save migrations, hand edits in `overworld.tscn` that generators must not overwrite (`make map-force` forbidden) |

So the slow part is the **process**: each growth step is a bespoke script run once, then later
relocations, then fix-ups. That doesn't scale to Tibia density.

### Streamlined approach

1. **Freeze the world frame once (no more doubling or relocating).**
   One `world_plan` data file (extend `Atlas`/`Biomes`) that lays out *every* landmass and region for the
   final world now: bounds, biome, level band, capital/town, ferry links, and which floors each region
   has (e.g. surface + 2 below + towers above). Empty regions stay as sea/void until built, but their
   coordinates never move again, so no more `relocate.gd` or save migrations.

2. **Real floors (z) instead of side planes.**
   Make floor a coordinate: cells are (x, y, z), sectors are stored per floor
   (`game/maps/sectors/<z>/<sx>_<sy>`), `Atlas.below` becomes z+1. Every new floor is then free, floors
   above ground become possible (houses, towers, mountains, roof-hiding, looking down; see "Floors"), and
   the world map shows any floor. One engine refactor up front instead of a new plane hack per floor.

3. **One region pipeline, re-runnable, instead of many one-shot scripts.**
   A region is a spec (data): bounds, biome palette, level band, towns, roads, points of interest, caves
   below, camp density, monster list. One command, `make region NAME`, builds terrain → roads → towns →
   camps → underground → world-map pages for that region only. It can run again any time.

4. **Generated layer + hand-edit layer.**
   Generators write a *base* layer; hand edits in the Godot editor go to an *override* layer per sector
   that always wins. Regenerating a region never wipes manual work, so "never run `--force`" stops being a
   rule you have to remember.

5. **Brushes for hand detail (the RME way).**
   A small Godot editor plugin: terrain brush (blends handled by the shader), doodad brushes (scatter
   trees, rocks, flowers, bones by biome), house/castle brush (walls + floor + roof from furniture
   catalogue), spawn brush (camp of N monsters at a level). Generators do the rough land; brushes do
   the Tibia-style density by hand.

6. **Grow by region, not by size.**
   Pick the next region from the plan, run the pipeline, detail it with brushes, review in game, done.
   Measure density (points of interest, camps, landmarks per 100×100) instead of tiles painted.

7. **Art first where possible.**
   Do Phase 1–2 of the art plan (rules + golden sprites) before mass-building new regions, so new land
   isn't painted in the old style and repainted later (same reason plans 38/39 pause).

### Suggested order
1. Write the world plan (frame frozen, all regions and floors listed). No code. Done: plan 47.
2. Floors as z refactor (engine), with the underground plane migrated to z = below. Done (engine):
   floor slots, not a Vector3i migration (owner's choice): cells stay 2D and each floor from −2 to
   +3 is a plane at `Atlas.FLOOR_X[z]`; holes pair any two neighbouring floors, zones, nav, and the
   world map (▲/▼ through every painted floor) and minimap (floor name) know z. Drawing other floors
   (lower floors offset and dimmed, roof and upper-floor hiding, cliff faces) waits for a painted
   upper floor (step 2b, "Making floors feel right").
3. Base/override layers + `make region` pipeline; convert one existing region (e.g. Brackenford's
   mainland ring) to prove it. Done: every sector scene's root is the hand **override** and its
   locked child `Base` the generated layer (`MapIO`; overrides always win, generators write the
   base). `make region NAME=<id>` (`tools/generators/region.gd`) rebuilds an island spec from
   `islands.gd` in place: it keeps cave mouths and dungeon entrances in its rect, clears its base,
   paints coast, landscape, towns, roads, harbour, and camps, furnishes and paves the towns, tags its
   markers with `region=<id>`, and re-bakes the world map; a re-run is a no-op. Silverwood was
   converted with a fresh rebuild (owner's choice: today's painter, empty overrides). Not done:
   a "keep today's look" conversion for hand-shaped regions such as Brackenford (copy their
   current cells into overrides first), and hunt/cave specs.
4. Editor brushes. Started: the `Brimholt brushes` editor plugin (`addons/brimholt_brushes`, logic
   in `game/maps/brushes.gd`) paints a terrain disc, scatters or clears doodad sets (forest, rocks,
   desert, fen, snow, wastes; kept off road verges), and erases overrides, into an open sector's
   override layer, one undo per stroke; stamps houses (roofed, door side chosen) and castle
   curtain walls (towers, gates); and adds or removes monster camps in `overworld.tscn` (level
   from the camps round it). Done. Later, if wanted: painting across sectors from
   `overworld.tscn`, and furnishing stamped houses (Decor markers).
5. Then build regions one by one from the plan (plan 40's islands become region specs).

### Floors: target
Up to six levels; every floor is **partial** (void where nothing is built), only the surface is full:
- **+3 peaks (rare):** summits, the top of a wizard's tower, a sky shrine; boss or quest spots.
- **+2 highlands:** high plateaus and mountain ridges with their own hunts, cliff paths, eyries.
- **+1 upper:** house storeys, towers, castle walls you walk on, hilltops, treetop villages (elven
  island), rooftop routes in capitals.
- **0 surface:** as today.
- **−1 shallow:** tunnels, sewers, cave mouths, easy hunts (plan 44's floor).
- **−2 deep:** the big hunting grounds and their bosses.

Depth or height = danger: the further from the surface, the higher the level.

**Upper floors as "another overworld".** A highland floor (+1/+2) over a mountain region can be a real
area of its own: a plateau of 100–300 tiles with grass, trees, a village, hunts, and roads, reached by
ladders, mountain stairs, and ramps from the land below. It is not a second full-size world (that would
double the content to build); it sits over the regions whose ground is mountains and hills.

**Required to make upper floors feel right:** see "Making floors feel right" below.

### Hunting grounds (Tibia-scale caves)
What makes Tibia hunts feel massive isn't one huge flat cave, it's **a multi-floor complex built as a
loop**:

| Trait | What it means for Brimholt |
| --- | --- |
| Spans floors | One hunt = several connected areas on −1 and −2 (and sometimes a surface ruin on top), joined by ramps, holes, ladders, and rope spots |
| Respawn loop | A main route that circles back to its start; one lap takes roughly as long as the respawn time, so a party can hunt it continuously without waiting. Long lap = solo/duo; wider halls and denser camps = party |
| Gets harder going down | Upper level easier monsters, lower level the strong ones and the boss; players choose how deep to go |
| Several entrances | Two or three ways in from different places on the surface, so it feels part of the world, not an instance |
| Shape variety | Long corridors for pulling, open halls for party fights, narrow chokepoints, dead ends with loot, small "safe" alcoves to rest |
| Secrets | Hidden passages, levers, a quest room or rare spawn off the main loop |
| Landmarks | Each hall recognisable (an underground lake, a collapsed temple, a lava bridge), so players learn the route by sight |
| Mixed spawns | 2–4 monster types that belong together (e.g. orc fort above, orc cave below), not one type everywhere |

Sizing guide (to tune in play): a solo lap of 10–15 minutes, a party hunt covering two floors of
roughly 150–250 tiles across each, one boss room at the deepest point.

These fit the `make region` pipeline as a **hunt spec**: entrances, floors, halls with their
monster mix and level, the loop route, secrets, boss. Plan 45's unmoved caves (Ember Deep, Frostvault,
Cyclops Hollow, Moonwell Deeps) are good first candidates to rebuild as multi-floor hunts once floors
are real z levels.

Decided (2026-10-21): floors above ground with roof hiding and looking down, Tibia-style (target
+3 … −2, partial floors). Plan 40's island building continues its layout now; its art is repainted
later.

## Making floors feel right

Floors only feel like Tibia if moving between them and looking across them is seamless. This is the
checklist; most of it is rendering in `game/render/` (`floor_layer.gd`, `sprite_art.gd`) and needs
floors as a real z coordinate first (see "Streamlined approach", step 2).

### Reference: the "2D that looks 3D" view

The trick is simple: every floor is a flat 2D layer, and each floor up is drawn **one tile further
up-left**. The camera "looks down from the up-left", so the shift opens a strip on the south and east
edges of every raised area. Fill that strip with a **cliff face** and the flat layers read as solid,
stacked land. Darken each floor below yours a step, hide every floor above you, and it looks 3D.

Reference images to collect (keep Tibia screenshots **private**, never in the repo or AI prompts):
- Standing on a mountain top looking down at the land below.
- Walking on a city wall or tower top, then stepping into the tower (roof hides).
- A multi-storey house, inside and outside.
- Standing next to a hole into a cave (seeing the floor below through it).
- A ramp up a mountain mid-climb.

Committed reference: our own mock-up scene in Godot (one hill with +1/+2, a two-storey house, a hole)
captured as golden screenshots for `make test-visual`, so every later change is checked against it.

### 1. Seeing other floors
- **Looking down.** Above ground, draw every floor from yours down to the surface. Wherever your floor
  is void, the floors below show through, each one shifted **one tile up-left per floor** (32 px at 1×)
  and slightly darker per step. A plateau then reads as raised land with the world spread out below it,
  not an island in black.
- **Underground.** Show only your own floor (and at most the one directly below through holes);
  everything else is rock and darkness. Keeps caves claustrophobic.
- **Draw order.** Lowest visible floor first, then up to yours; within a floor the existing row-by-row
  order (walls south/east cover what's behind).
- **Opaque ground.** Any built cell (floor, roof, wall top) fully covers what's below it, so nothing leaks
  through.

### 2. Hiding what's above you
- **Roofs and upper storeys.** If any floor above you covers your tile (or the tiles next to you), hide
  all floors above yours. Walking into a house, under a bridge, or into a cave mouth instantly shows the
  inside.
- **Leaving.** Step out from under the cover and the floors above come back. Use a short fade (about 0.15 s)
  rather than a pop.
- **Roofs per building.** Hide only the roof of the building you're in when possible, so the street outside
  still shows the neighbours' roofs (nicer than Tibia's all-or-nothing, optional).

### 3. Edges and shape of raised land
- **Cliff faces.** Where an upper floor ends over void, draw a cliff/wall face hanging down-right from its
  edge (the oblique view), in the material of the land (rock, earth, castle stone, wood for treetop
  platforms). Without faces, raised land looks pasted on.
- **Edge lips and shadow.** A lit lip on the top edge and a soft shadow cast on the floor below, down-right.
- **Railings and parapets** on walls and towers where you can't fall/step off.

### 4. Moving between floors
- **Ways up and down**, all in the new style and readable at a glance: ladders, stairs (in buildings),
  stone ramps (mountains, step onto them to change floor), holes (fall/climb down), rope spots (need a
  rope to climb up), trapdoors, and magic portals for special places.
- **Arrival.** You land on the matching cell above/below, never inside a wall; a short step animation
  and the camera eases to the new floor's offset instead of jumping.
- **Feedback.** A small floor indicator in the HUD (e.g. "+1", "−2") and on the minimap.

### 5. Creatures, combat, and light across floors
- **See, don't touch.** Players and monsters on visible lower floors are drawn (dimmed with their floor)
  so you can spot them, but targeting, melee, spells, and missiles only work on your own floor.
- **Names and bars** only for your own floor.
- **Light.** Each floor has its own ambient (surface follows day/night and weather; underground dark; high
  floors slightly brighter and windier). Lamps and the player's light only light their own floor.
- **Weather.** Rain and snow fall on the highest uncovered floor you can see, not under roofs.

### 6. Map, network, and performance
- **Minimap and world map** per floor (already started in plan 45), with the floors above/below faded as
  context.
- **Network interest** includes the floors you can see (so creatures below appear), not just your own.
- **Performance.** Draw only visible floors and only the visible window of each; skip cells fully covered
  by the floor above. Upper floors are sparse, so cost stays low.

### 7. Art needed
Cliff faces per material, wall tops you can stand on, parapets, ladders, stairs, ramps, rope spots,
trapdoors, holes, roof edges, and a per-floor dimming/tint value. Everything follows the style spec
(outline, saturation, oblique).

### Acceptance (play test)
- [ ] Standing on a +2 plateau, the land below is visible, shifted up-left, and reads as lower.
- [ ] Walking into a house hides its roof and the floor above within a short fade; walking out restores it.
- [ ] Every raised edge has a cliff face; nothing floats.
- [ ] Climbing any ladder, stair, or ramp lands on a free cell and the camera eases.
- [ ] Monsters on the floor below are visible but can't be targeted.
- [ ] No leaking floors below through built cells; no frame-time regression in `make bench`.

## Castle and city hunting grounds

Tibia has big hunts that are **places**, not caves: ruined cities, fortresses, and walled districts full
of monsters. Brimholt has castles only as safe towns (Cinder Crossing's walls via `castle_town.gd`, plan
40's castle capitals). This adds the hostile kind.

### Tibia examples (research 2026-10-21; details to verify before relying on them)
| Example | What it is | Pattern |
| --- | --- | --- |
| Banuta | Jungle city ruins taken over by apes; temples and pagodas on the surface, apes on −1/−2, much deadlier creatures deeper, reached through a quest | Easy ruins on top, gated dangerous basement |
| Zzaion | A walled lizard fortress city with gates, rising danger from the outer area to the elite tower | Concentric rings, harder toward the core; event raids |
| Yalahar | A ruined metropolis: a safe inner city surrounded by themed quarters (cemetery, factory, alchemist, sunken, arena, …), each with its own monsters | Hub and spoke: safe core, themed districts |
| Drefia | A cursed colony half sunk underground, necromancer halls below, reached over a dangerous mountain pass | The journey there is part of the hunt |
| Roshamuul | Demon island opened in stages: repair a bridge, breach a wall, then the prison holding the princes | Staged unlocks, each zone bigger and harder |
| Orc fortress / citadels | Fortified strongholds with gates, courtyards, towers, and a leader or boss at the heart | Fort as a hunt, boss in the keep |

### Patterns to use
1. **Gradient**: outer walls and courtyards easy, keep and towers harder, below the keep hardest.
2. **Floors**: towers and walls (+1/+2), the streets (0), dungeons and catacombs under it (−1/−2), all
   using the floor system.
3. **Themed districts**: a big city hunt is split into named quarters, each with its own monster mix and
   look (barracks, temple, market, graveyard, harbour, sewers).
4. **Gates and unlocks**: levers, keys, a bridge to repair, a breach in a wall, opened by quests (see
   below), so getting deeper is progress you can see.
5. **The approach is dangerous**: a road, pass, or swamp leading in, with its own monsters.
6. **Why it's ruined**: one paragraph of story per place (war, curse, plague, uprising) that explains its
   rooms, its monsters, and its loot.
7. **Boss at the heart**: a throne room, prison, or sanctum built to fit its boss.
8. **Hunt-friendly layout**: a respawn loop through the districts (see "Hunting grounds"), corners and
   doorways to fight in, wide halls for parties, small safe alcoves.

### Building blocks (art and map)
- **Castle kit** (extends plan 40's castle look): fieldstone curtain walls, towers (2×2, with +1/+2
  floors), gatehouses with portcullis, battlements you walk on, keep with hall and throne room, courtyards,
  stables, barracks, chapel, dungeon cells, sewers.
- **Ruin kit**: the same pieces broken: collapsed walls, rubble, missing roofs, overgrowth (jungle vines,
  moss), scorch marks, flooded floors; one kit per biome (jungle, desert, swamp/necropolis, volcanic,
  northern).
- **District props**: market stalls, graves and crypts, forges, temple altars, harbour cranes and crates.
- All in the new style (outline, saturation, oblique), all hand-placeable with the editor brushes.

### Brimholt plan
1. Design one **castle hunt** as the prototype: a ruined fortress on the mainland, three rings
   (outer bailey → inner courtyard → keep), towers +1/+2, catacombs −1/−2, a boss in the keep or the
   deepest catacomb, two entrances, one quest that opens the catacombs. Fits right after the floors refactor.
2. Turn it into a **hunt spec** for `make region` (districts, rings, floors, monster mix per ring, loop,
   gates).
3. Then one **ruined city** per archipelago island where it fits (plan 40): e.g. a jungle temple city, a
   desert tomb city, a necropolis quarter, a volcanic dwarf hold, a northern siege fort.
4. Build the castle and ruin kits as art before step 1's final paint, following the art plan.

## Quest design

### Brimholt today
Quests are hunting tasks (`game/data/quests.gd`): a giver asks for N kills of a monster, you return,
you get experience, gold, supplies, sometimes gear or a pack; tasks can chain (`requires`), count only
inside a cave, and are done once. Plan 22 adds outfit rewards. There are no puzzles, access quests,
exploration secrets, group mechanics, or quests that open new areas.

### What Tibia does (research 2026-10-21; details to verify)
- **Access quests open the world**: finishing a quest opens a hunting ground, a shortcut, or a travel
  route (e.g. a deeper level of Banuta, the stages of Roshamuul). The reward is *more world*, not
  only items.
- **NPC conversations by keyword**: you talk to NPCs and ask about things (hi, job, mission, a
  name, an item); the right questions lead to quests and lore.
- **Discovery**: many quests are found by exploring (a strange door, a book, a lever) rather than from
  a marker; players share finds with each other. A quest log tracks the big story chains.
- **A small set of puzzle pieces, reused**: levers (sometimes in a sequence or pulled together), pressure
  plates, placing an item on an altar, keys, quest doors and level doors, paying a toll, riddles from books,
  rope spots and shovels for hidden ways.
- **Group quests**: several players must stand on plates or pull levers at the same time, then fight
  together (the Annihilator style: four players on tiles, then a demon arena).
- **Reward rooms**: a room of chests where you **choose one** reward, once per character; boss rewards
  go to each participant individually.
- **Long story chains**: many missions mixing travel, talking, fetching, puzzles, and fights, with a
  big boss at the end.
- **Repeatables**: daily task chains with tokens and reputation ranks (unlock outfits, mounts,
  teleports), and a slayer-task system for long-term hunting goals.
- **Challenges**: arenas with waves under a clock, boss rooms with cooldowns.
- **Cosmetics**: outfits, addons, and mounts from quests (fits plan 22).

### Design principles for Brimholt
1. **Every major quest opens something**: a deeper floor, a district, a shortcut, a boat route, a
   waystone. Progress you can see on the map.
2. **A puzzle toolkit, reused**: levers, plates, keys, item-on-altar, quest/level doors, tolls,
   rope/shovel spots, readable books. Build each once as a map marker with props, then remix.
3. **Some secrets with no marker**: hidden levers and walls, rewards for exploring. Quest log only for
   chains.
4. **Group moments that work at a LAN party**: plates and levers needing 2–4 players at once; AI
   companions can fill seats when playing solo (Brimholt already has companions).
5. **Choose-one reward rooms**: one chest of three or four, once per character; individual boss loot
   so nobody fights over drops.
6. **Talking to NPCs**: keep the current dialogs, but add a keyword layer (ask about names, places,
   items) for lore and hidden starts. Optional typed keywords, Tibia style, or clickable topics.
7. **Mix of quest types**: access quests, story chains, kill tasks (have them already), daily/reputation
   tasks, arenas, outfit/addon/mount quests.
8. **The approach is part of the quest**: dangerous routes to the quest area pace who gets there.

### Steps (investigation first, no code yet)
1. **Investigate**: play or read through 5–10 classic Tibia quests of different types (an access quest,
   a long chain, a group quest, an exploration quest, an arena, a daily system) and write one paragraph
   each on *the pattern*, not the content. Keep notes private if they quote Tibia.
2. **Design the toolkit**: list Brimholt's puzzle pieces and their data format (markers in the scene,
   state per character/party), plus reward rooms.
3. **Write one prototype quest per type** with Brimholt's own story, tied to the castle hunt prototype
   (e.g. the quest that opens its catacombs; a group lever puzzle in the keep; a choose-one reward room
   after the boss).
4. **Quest log and NPC keywords**: decide the UI (log for chains only; keywords typed or clicked).
5. Then fold quests into each region spec, so every new region ships with its access quest and secrets.

## Loot and economy (investigation 2026-10-21)

Owner: "it drops way too much stuff". Investigated read-only on `main`. Numbers come from a quick
simulation over every monster spawn in the maps (11,110 monsters, 317 kind/level pairs). They are
estimates: solo, same-level normal kills only. Elites, champions, quests, and bots come on top, so real
drops are **higher**.

### How loot works today
- `Combat.roll_loot` rolls, per kill:
  - every `Monsters.LOOT` entry independently (material 25–50%, a second material 10–15%, potions
    4–25%, runes 2–12%, named gear 0.2–2%)
  - tier gear (`GEAR_DROP_CHANCE`: normal 1%, elite 8%, champion 100%)
  - homeward rune (1.5% from L30)
  - mounts (1%)
  - gems worth `level × 1 gold` (×4 elite, ×12 champion, ×25 boss)
  - gold coins (`0.2 + 0.02 × level` piles of 25)
- Loot **spills onto the ground** within 3 tiles of the kill. There is no corpse, and a green loot text
  pops up.
- Materials sell well: ogre tooth 90, ember charm 145, shaman pearl 135. Gear sells at 25% of price.
- Vendors sell only potions, bags, and gear **up to level 10** (`Economy.MAX_TIER`). Quests give 23 gear
  rewards and no gold. There are 81 gold-coin ground spawns.
- Levelling: `kills_to_level = 4 + 3 × (L − 1)` adds up to only **~3,700 same-level kills from 1 to 50**.

### What the numbers say
| Tier (levels) | Kills spent | Gear pieces from normal kills | Loot worth (gold) | 6-slot vendor-priced set |
| --- | --- | --- | --- | --- |
| 10–14 | 185 | ~3.5 | ~5,700 | ~2,800 |
| 20–24 | 335 | ~7 | ~17,000 | ~5,800 |
| 30–34 | 485 | ~10 | ~35,000 | ~8,900 |
| 45–49 | 710 | ~12.6 | ~71,000 | ~13,600 |

- **Something drops on nearly every kill**: about 1.0 ground stacks per kill at L1–9, rising to 1.7 at
  L40–50. Every 1–3 kills you walk over a pile.
- **Gear floods**: 4–13 pieces per 5-level tier from normal monsters alone. Add 8% from elites, 100%
  from champions, and quest gear, and that is more than the 6 slots each tier needs, so most drops are
  vendor trash.
- **Gold has nothing to buy**: a tier's loot is worth **2–5× a full set**, but vendors stop at level-10
  gear, and potions and runes also drop. Gold piles up and loses meaning.
- **Supplies are not a cost**: in Tibia, potions and runes are the main gold sink, and a hunt's profit is
  loot minus supplies. Here they drop for free.
- **Fast levelling makes it worse**: few kills per level mean each upgrade comes quickly.

### What Tibia does (pattern, not numbers to copy)
- Loot goes **into the corpse**. You open it and take items; the ground stays clean.
- Most kills give **gold plus maybe one common item**. Good items are 0.1–1%, and the best are rarer
  than 1 in 1,000, so a rare drop is an event players talk about.
- **Supplies cost gold**, and you measure a hunt as profit or waste per hour. Gold sinks are supplies,
  travel, blessings, houses, upgrades, and outfits/addons.
- Gear mostly comes from quests, rare drops, and **trading between players**, not from the floor every
  few minutes.

### Direction (no code yet; for the owner to confirm)
1. **Corpses with one-click loot (owner decision 2026-10-21)**: loot goes into one corpse container on
   the kill tile, and the corpse decays after a while. This is the biggest fix to both the feel and the
   clutter.
   - **One click loots every nearby corpse**: corpses within a small radius (e.g. 1–2 tiles, Tibia-like)
     that you or your party earned (use the existing `loot_claims`). Bind it to a key and an action-bar
     button.
   - **Loot window in the UI** to set what one click takes, Tibia quick-loot style:
     - item categories to take or skip (gold, gems, materials, gear, potions/runes, mounts, rare)
     - a skip list for single items
     - a minimum value
     - optional destination per category (main backpack, a loot bag)
   - Opening a single corpse still works for a manual look.
   - **Feedback**: one summary line per click ("Looted 3 corpses: 240 gold, small ruby, 2 ogre teeth");
     loot text over the corpse only for rare drops. A full backpack leaves the rest in the corpse with a
     message.
   - **Corpse art**: one corpse sprite per monster look (template plus tint), in the new style. The
     corpse shows a sparkle or other mark while it still holds loot.
   - Bots and companions use the same corpse rules (`bot_loot.gd`).
2. **Fewer stacks per kill**: target about 0.5–0.8 non-gold stacks per normal kill.
   - Materials: 10–25%.
   - Second material: 3–5%.
   - Potions and runes: off normal monsters (elites only, low chance).
   - Gems: rarer but bigger. Keep the worth, cut the count.
3. **Gear rarity**:
   - Tier gear: normal 1% → ~0.1–0.3%, elite 8% → ~1–2%.
   - Named hunting gear: ~0.05–0.5%.
   - Champions: one roll on a better table, not a guaranteed piece.
   - Quests stay the reliable gear source (fits the quest plan).
4. **Gold sinks**:
   - Supplies bought, not dropped.
   - Vendor or crafting gear above level 10 at real prices, or upgrade costs (an imbuement-like sink).
   - Travel fees (ferries).
   - A death blessing.
   - Quest tolls.
   - Outfits/addons, house rent (later).
5. **A target to balance against**: "a level-appropriate hunt earns supplies + 20–50% profit per hour; a
   rare drop is ~1 per X hours". Set the loot worth per kill from that target, not the other way round.
6. **Re-check levelling**: decide whether ~3,700 kills to 50 is intended. If levelling slows down, loot
   per hour must be retuned with it.
7. **Make it measurable**: a re-runnable loot report (expected stacks, worth, and gear per kill, tier,
   and hour) checked into the repo, plus a test that fails when a monster goes over budget. The lexicon
   already shows drops.

### Open questions
- ~~Corpses with manual looting or a quick-loot key?~~ Decided: one click loots nearby corpses, with
  what it takes set in a loot window.
- Quick-loot radius (adjacent only, or 2 tiles)? How long until a corpse decays?
- Is player trading the main way to get gear (needs enough players on a LAN), or are quests and
  crafting the main source?
- What should gold be **for** in Brimholt: supplies, upgrades, housing, cosmetics?
- Keep the champion "guaranteed piece" as a feel-good, or make it rare?

## The style's name: OTS / Tibia-style

Name to use in docs, art briefs, and searches: **OTS / Tibia-style pixel art** (OTS = OpenTibia server
style). In practice that means:
- **32×32 tiles** in an **oblique (3/4) projection**: you see the front and the top of things.
- **64×64 frames** for outfits and big creatures (2×2 tiles), anchored bottom-right.
- Outfits as a **base plus a tint mask** (head, body, legs, feet), so players pick their own colours.
- Saturated colours, full dark outlines, light from the top-left, chunky readable silhouettes.

Everything stays Brimholt's own art; we match the style and draw every design ourselves. No bought or
third-party art packs.

## Key additions beyond art (review 2026-10-21)

**Baseline (what Brimholt already has)**:
- Play: LAN for up to 24 players with a server-authoritative host and signed saves. Solo with AI
  companions, rivals, and a 20-player AI raid.
- Character: 4 classes, spells with ranks, runes, parties with shared experience, skulls and PvP zones,
  classic death loss from level 8.
- Gear: 10 gear tiers, hunting weapons, mythic sets, relics, mounts.
- World: towns, waystones, ferries, instanced dungeons, elite caves, the frost isles, the Hollow
  Reach, final bosses.
- Professions: 9 (gathering and crafting); a bank, vendors, and a lexicon of monsters.
- Tasks: town tasks and packs, Hunters' Lodge contracts, endgame titles.
- UI: minimap and world maps, rebindable keys.

**Missing compared with Tibia's feel**:
- chat and speech
- sound
- any measure of a hunt
- gold sinks
- real darkness
- world events
- player trading
- houses and guilds

Ranked by value for effort. The first five tie directly into the loot, floors, and quest plans above.

1. **Hunt analyser (session stats)**: a small window showing experience/hour, loot value/hour,
   supplies used, **profit/hour**, kills by monster, and rare drops. A party version adds a fair loot
   split. This is the tool to balance the new loot against ("supplies + 20–50% profit"), and players
   love it in Tibia. Cheap: Combat already emits kill and loot events.
2. **Blessings and gold sinks**: death already costs the whole backpack and gold from level 8, so sell
   **blessings** at temples (price rising with level) that reduce what you lose, plus a cheap amulet of
   loss. Add travel fees, supplies bought (not dropped), and upgrade costs (see Loot). This gives the
   gold from the loot rework a purpose.
3. **Speech and spell words**: yellow text above a character for local talk, and **spell words** shown
   when casting (our own invented words, Tibia's iconic feel). NPC talk by keyword (see Quest design).
   Also a simple chat log with local, party, and system tabs, and messages that look like server
   messages (white for loot, green for experience). Very high feel for a small cost; even on a LAN,
   speech bubbles make bots and NPCs feel alive.
4. **Real darkness and light**: caves and lower floors dark around a light radius. Torches, a light
   spell, glowing lava and mushrooms light the area; night dims the overworld. Darkness is half of how
   Tibia's caves feel and makes the floor plan work (deeper means darker). Check today's cave lighting
   first.
5. **Sound and music**: plan 20 is waiting on the owner's choice of CC0 sounds. Footsteps per ground
   type, hits, spells, monster sounds, ambient sound per biome and floor, town music. Probably the
   single biggest feel jump left; unblock it.
6. **Living world events**: a **boosted creature of the day** (more experience and loot, announced at
   login), and **raids** announced in a broadcast ("Orcs are gathering near Cinder Crossing!") that send
   a wave and a raid boss into a town or castle hunt. Rare mini-bosses (plan 21) fit here. Cheap, and
   gives a LAN session shared moments.
7. **Safe trade window**: two players put items in and both accept. Unbound gear is already meant to
   be traded; the corpse/loot rework makes trading the way to get the best gear.
8. **Houses and guildhalls (later)**: rentable houses in towns (rent is a gold sink), storage and
   decoration, and a guild with a shared hall for the LAN group. Towns already have furnished empty
   homes.
9. **Bestiary progress (later)**: extend the lexicon. Killing N of a monster unlocks its loot table and
   gives points for small permanent bonuses (Tibia's bestiary and charms). A long-term hunting goal
   beside the tasks.

Skills trained by use (Tibia's sword, distance, and magic level) are left out on purpose: they would
redo the whole balance model (`docs/balance.md`) for little feel gain over spell ranks and professions.

## UI: from lackluster to Tibia-functional (2026-10-21)

From earlier reads only, no new repo access. Check details when back on the owner's own machine.

**Today**:
- About 4,900 lines of UI over 22 scripts: start panel, HUD, action bar, inventory, character
  window, spell book, party, professions, lexicon, quest list, NPC dialogs, world maps, buff bar, micro
  menu, controls.
- One code-drawn theme (`ui_theme.gd`, flat dark boxes) instead of a painted frame.
- No chat, no hunt stats, no loot settings, no battle list, no skills/stats panel beyond the
  character window.
- Slots drawn about a fifth smaller than the 32 px art.

**What Tibia's client gets right** (functionality, not its look):
- **Side panels**: windows dock in columns at the right and left of the game view. You open, collapse,
  resize, and stack them, and the layout is saved.
- **Battle list**: every creature and player on screen, sorted by distance or health. Click to target,
  with filters (monsters, players, party, skulls).
- Containers open as small windows. Several backpacks are open at once, and you drag between them.
- **Hotkeys for anything**: spells, runes on target, potions, equipping a ring, saying a word.
- Status bar icons: poisoned, burning, in battle (no logout), PZ-locked, haste, a skull.
- Server log and chat tabs, with yellow speech over heads.
- **Analysers**: hunting (experience/hour, profit), loot, supplies, damage and healing.
- **Minimap with marks**: icons and notes you place, floor up/down buttons, centring.
- Right-click menu on everything: look, use, open, trade with, attack, follow, add to VIP.

**Brimholt UI plan** (ordered by value):
1. **Dockable side panels**: one system that every window uses (dock left or right, collapse, reorder,
   save the layout per character). Today's windows move into it.
2. **Battle list** with click-to-target and filters. Pairs with the existing Space for nearest target.
3. **Loot window and quick loot** (see Loot: one click loots nearby corpses, settings in the window).
4. **Hunt analyser** (see Key additions).
5. **Chat and log**: local, party, and system tabs; server-style messages; speech over heads; spell
   words.
6. **Hotkeys for items**: put a potion, a rune, or a food on the action bar, and use it on yourself or
   the target, with a shared cooldown shown on the slot.
7. **Status icons** under the health and mana bars: in combat, protection zone, poison, burning,
   haste, skull, PvP on.
8. **Minimap marks and floor buttons** (fits the floors plan): place your own icons and notes, ↑/↓
   to look at other floors.
9. **Context menu** on creatures, players, items, and corpses.
10. **Look and feel**: a painted UI kit in the new art style (stone and wood frame, metal corners,
    parchment for text) instead of flat boxes, pixel font at whole sizes, slots at the art's real 32 px.
    Done once as a 9-slice theme so every window picks it up.

## Spell icons and rune items

**Today** (from earlier reads):
- **Spell icons** (`assets/sprites/spells.png`, 32×32, 8 per row): each spell is a stone tablet with a
  glowing rune-alphabet sign (Elder Futhark plus a few Anglo-Saxon runes) drawn as strokes, coloured by
  the spell's colour (`make_sprites.py` `spell_catalog`, `RUNE_STROKES`).
- **Rune items** (fire, frost, lightning, great fireball, sudden death, homeward) use the look
  `runestone+<rune>`: a grey stone with a coloured sign.
- `rune_fx.png` holds the effects.

**Owner's view**: the rune art is the higher-quality part and he likes it, but it does not sit with the new
style: shading, outline, and saturation do not match the painted gear and creatures.

**Direction**:
- **Keep the idea, restyle the execution**: keep the stone-with-glyph identity, which is Brimholt's own
  flavour, and bring it to the style spec:
  - full dark outline
  - top-left light with five-tone ramps
  - saturated glyph glow with one bright core pixel and a soft halo
  - an oblique 3/4 bevel on the stone so it reads as an object, not a flat tile
- **Readable at a glance in the bar**: spell icons need a stronger silhouette than the glyph alone.
  Add an **element background** (fire orange-red, frost cyan, energy violet, earth green, holy
  gold, death black-purple, healing light green, physical steel), plus an **effect shape** in the
  glyph's place or behind it (a burst for area, an arrow for a strike, a ring for a buff, a cross for
  healing). The glyph becomes a small mark, so 40 spells don't all look like grey stones.
- **Rune items vs spell icons**: rune *items* stay stones (an inventory object, Tibia's rune feel,
  with charges shown as a number). Spell *icons* move to the element-tile language above. One look per
  meaning.
- **One palette for both**: elements share exact colours with `rune_fx.png`, missiles
  (`spell_missiles.png`), damage numbers, and buff icons, so a fire spell reads the same from the bar to
  the hit.
- **Cooldown on the slot**: a clockwise dark sweep and a ready flash (part of the UI plan).
- **Process**: restyle 4 spells (one per class) as a sample sheet, review at 1× and 2× zoom next to
  painted gear icons, then batch the rest in the generator.

## Rule changes to make in the repo (Phase 1)

Update `.github/skills/art-direction/SKILL.md` and `docs/art.md`:

| Current rule | Replace with |
| --- | --- |
| "Imitating Tibia's items and looks closely is welcome, copying its pixels is not" | **"Match the style; every design is our own."** |
| Restrained earth colours, low saturation | Saturated, high contrast, modern-Tibia palette |
| Saturated colour/glow only for relics, ores, magic, fire | Saturation everywhere; glow/animation stays reserved for relics, ores, magic, fire |
| Outline only on lower/outer edges, no pure black | Full dark silhouette outline on creatures, characters, items; selective inner lines |
| Character ~22×38, slim | Chunky character ~32×32, four tint layers + addons |
| Ramps of 4–7 tones | Ramps of 6–10 tones, smooth, anti-aliased |
| (no rule) | Every natural terrain transition blends (shader); built floors meet ground with a kerb |
| (no rule) | Characters and creatures in 3/4 oblique view |
| "Tibia screenshot" references in prose | Add a `docs/art-reference/` folder of **our own** golden sprites (see Phase 2) and point every rule at them |

Keep: top-left light, no checkerboard dithering, oblique walls, readable construction, integer scaling,
nearest filtering, no copied Tibia files.

## Audit: what doesn't match today

From a sprite review on 2026-10-21 (plus plan 38's audit of 2026-10-16).

| Area | Assets | Problem | Priority |
| --- | --- | --- | --- |
| Player character | `body.png`, `cloth.png`, `outfits/*`, `art/outfits/*`, 375 `gear/*` sheets | No outline, slim, flat front/side view, dark tunic vanishes on dark ground. Monsters already look more "finished" than players. Changing the body changes every gear sheet | **1** |
| Ground | `tiles.png` via `tools/generators/pixel_floors.py`, blended and animated by `game/render/terrain.gdshader` / `water.gdshader` | **Mostly aligned** (floor redraw + terrain shader, 2026-10-20): hand-pixelled 32×32 floors, blended natural edges, animated water with shore foam. Remaining: the five-tone ramps are still on the muted side (e.g. `GRASS` 9fbd5e→375323); a saturation/contrast pass to the new master palette, and maybe 6–8 tones per ramp for modern-Tibia smoothness. (The black block in the sheet is blank cells 12–19, not a broken tile.) | 3 |
| Old walls | `walls.png` rows 0–2 (grey crypt, purple obsidian, brown cave) | First-generation brick cubes | **1** |
| Cave rock | `cave_rock.png` | Near-white boulders, too bright and contrasty in the wrong way; caves should be dark and moody | 2 |
| Other walls | `house_walls`, `castle_walls`, `castle_towers`, `fieldstone_walls`, `cellar_walls`, `log_walls`, `mountains`, `crags` | Closest to target, but low saturation and thin detail; need a recolour/detail pass to the new palette | 2 |
| Creatures | `creatures/*` (67), `monsters/*` (12 tinted templates), `mounts/*` (30) | Best current art, but muted and some read as blobs (behemoth). Need saturation, 3/4 view, clearer silhouettes. Lizardfolk/ogre shamans are humans in hoods | 2 |
| Item icons | `items.png`, `icons/*` (168), `icons_derived/*` (80), `items_anim/*` (34) | Two generations: rich hand-pixelled weapons/potions/food vs flat generated armour/legs/boots (plan 39) | 2 |
| Trees and plants | `firs.png`, trees, `herbs.png`, `mushrooms.png` | Oak canopy pillow-shaded cells, snowy firs repetitive, dead purple trees are 1px lines with no outline | 2 |
| Props and furniture | `objects.png`, `furniture.png`, `signs.png`, `wall_decor.png`, `fountain.png`, `ores.png`, `coins.png` | Several pieces drawn flat front-on instead of oblique; palette muted | 3 |
| Roofs | `roofs.png` | Recolour to saturated palette | 3 |
| Effects | `spells.png`, `spell_missiles.png`, `rune_fx.png`, `items_glow.png`, `assets/third_party/kenney_particle_pack` | Check against Tibia's bold effects; Kenney particles are a different style | 3 |
| UI | `menu_icons.png`, `title.png`, fonts | Not reviewed yet | 3 |
| World map | `world_map/*` (57) | Rebake after terrain changes | last |

## Plan

### Phase 0: Decide (now, no code)
- [x] Style target: modern Tibia 12+, saturated, high contrast, original art.
- [x] Write the flavour pillars (above).
- [ ] Collect 10–20 modern Tibia screenshots for **private** reference (not committed): a town, grass
      plains, a cave, a desert, snow, swamp, outfitter, a few monsters, inventory, spell effects.
- [x] Pause plans 38 (old tiles) and 39 (icon families) so nothing gets repainted twice. Plan 40
      (archipelago, being built now) builds its layout now, art later.

### Phase 1: Rewrite the rules (done 2026-10-21)
- [x] Update the art-direction skill and `docs/art.md` per the table above.
- [x] Define the new master palette: `tools/generators/palette.py`, one saturated ramp of 6–10 tones
  per material (34 ramps), `outline()` for each material's hue-tinted near-black, and `IDENTITY`
  (each region's ground and accent ramps from the flavour pillars, checked against `regions.gd`).
  The old module ramps (`GRASS`, `ROCK`, `COBBLE`, `OAK`, `IRON`, ...) are replaced family by family
  in phase 4; the outfit tint palette (head/body/legs/feet) comes with the character in phase 2.

### Phase 2: Golden reference sprites (hand-made or AI-assisted, then cleaned up by hand)
Make a small set that defines the look; everything else copies it. Start from
`art/outfits/class_sets.png` and `class_pieces.png`, which already hit the target best.
1. Character: one outfit, four directions, walk frames, with head/body/legs/feet tint layers (see
   "Character model").
2. One small and one large (64×64) monster.
3. Ground: take the current `pixel_floors.py` grass, dirt, and water (already close) as the ground
   reference; only re-tune their ramps once the master palette exists.
4. One house wall and one cave wall, in the oblique view.
5. One weapon, one armour, one potion icon.
6. One tree and one piece of furniture.

Put them in a test scene beside each other and beside private Tibia screenshots. Iterate until they read as
the same game. Commit only our own sprites (e.g. `docs/art-reference/`).

Tooling choices to make here: Aseprite (or Pixelorama, free) for hand work; optional AI generation at a
higher resolution, then downscaled to the 32px grid and hand-cleaned (palette snap, outline, AA).

### Phase 3: Pipeline decision
For each asset family, pick one:
- **Generator** (keep Python): good for huge, systematic families (375 gear sheets, icon tiers, tints).
  Rebuild the generator to reproduce the golden sprite exactly, using the new palettes.
- **Hand-made sheets**: better for the most visible, low-count assets (character base, ground + borders,
  walls, trees, signature monsters).
- Hybrid is expected: hand-drawn base + generated recolours/variants.

### Phase 4: Roll out, most visible first
1. Character base + outfits + gear sheets (biggest visual win, biggest job: the body size change ripples
   through all 375 gear sheets and `game/render/sprite_art.gd` anchors).
2. Ground: already redrawn with shader blending and shore foam; only a palette/saturation pass to the
   master ramps is left, and a check of which plan 38 ground steps are still open.
3. Walls: replace `walls.png` cubes; restyle house/castle/cellar/log/fieldstone/cave/mountain (absorbs plan 38 steps 4–5).
4. Creatures and mounts (absorbs plan 38 step 6).
5. Item icons (absorbs plan 39).
6. Trees, plants, props, furniture, roofs, signs.
7. Effects, UI, title, then rebake the world map.

After each step: screenshot tour (`tools/testing/shot.gd`) of every town, region, cave and dungeon, and
compare against the golden sprites and private Tibia references.

### Phase 5: Consistency gate
- A checklist in the art-direction skill every new sprite must pass (outline, light, palette ramp,
  projection, scale vs character, transitions blend or kerb).
- Optional: a small script that flags palette colours outside the master ramps and missing outlines.

## Acceptance checklist (per sprite)
- [ ] On the 32px grid, anchored like its neighbours, correct scale next to the character.
- [ ] Oblique / 3/4 view if it stands up.
- [ ] Top-left light; highlights and shadows are strong.
- [ ] Colours come from the master palette ramps; saturated.
- [ ] Full dark silhouette outline (creatures, characters, items); selective inner lines.
- [ ] Smooth ramps, clean anti-aliasing, no dither, no pillow shading.
- [ ] Detail level matches the golden sprites.
- [ ] Original pixels; no Tibia files used.

## Phase 0 decisions (owner, 2026-10-21)
- **Flavour pillars:** the five under "Our flavour" above.
- **Character canvas:** keep 64×64 frames (as Tibia's modern outfits and big creatures do); the body
  fills about one 32×32 tile, anchored bottom-right.
- **Attack animation:** keep a short, subtle swing.
- **Walk cycle:** four frames.
- **Floors:** add floors above ground (house storeys, towers, climbable mountains) with Tibia-style roof
  hiding and looking down at lower floors.
- **Outfit tinting:** free head/body/legs/feet colours from a fixed outfit palette, like Tibia.
- **Golden sprites:** AI-assisted, then cleaned up by hand in Aseprite or Pixelorama. AI prompts
  describe the style in words and use our own sprites as references; never Tibia screenshots or files.
- **Plans 38 and 39:** paused until Phase 2 (golden sprites) is done, so nothing is repainted twice.
- **Plan 40:** continue the layout now; repaint its art after Phase 2.

## Still open
- Collect the private Tibia reference screenshots (Phase 0, owner).
- The open questions under "Loot and economy" (quick-loot radius, corpse decay, gear sources, what gold
  is for, champion drops).
- The keyword layer for NPC talk must stay clickable topics: typed keywords are against the repository
  rules (right-click service menus only). Player trading and houses need the owner to select them as a
  milestone first.
