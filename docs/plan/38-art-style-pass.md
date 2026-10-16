# 38 - Bring the old tiles up to the new art style

**Effort:** L

## Request
Check where the world still uses the old art style next to the new one: a lot of it mismatches.

## The check (2026-10-16)
A screenshot tour at noon of every town, nineteen regions, the six hunting caves, the four
dungeons, the Void Throne, and the frost isles (`tools/testing/shot.gd`, contact sheets in
`.tools/artaudit/`). The new style is the grass (`grass_tile`: clumps, blade tufts, lit tips),
the kerbed cobbles, the Tibia-style house walls, mountains and outcrops (`mountains.png`), the
trees, firs, mushrooms, furniture, roofs, snow, and the painted creatures. Still in the old style:

| Where | What | Old art | Looks like |
| --- | --- | --- | --- |
| Every coast, lake, and pond | Water (`~`) | `water_tile` | One flat dark blue with faint lines; meets land in hard square steps with no shore, foam, or wet sand. The worst mismatch: the Cinder Crossing pond beside spawn is a black square |
| Lastlight, Blackreed Isle, Sunscar Dunes, beaches | Sand (`s`) | `sand_tile` | Flat beige with almost no texture; square edges against grass and water (the dry-grass fringes only on some sides) |
| Blackreed Isle, country roads, Westwind Coast | Dirt (`:`) and gravel | `dirt_tile`, `gravel_tile` | Flat brown with a few blobs; dirt roads have no ruts or verges, hard edges to grass |
| Mirewood Fen | Bog (`m`) | `bog_tile` | Dark flat mud, square edges to grass |
| Lastlight docks, Hrimvik's quay, bridges | Planks | `plank_tile` | Flat dark boards without grain, nails, or gaps of water between them |
| The Hollow Reach, the Void Throne | Obsidian flagstones and dusk soil | `obsidian_tile`, `dusk_tile`, walls.png row 1 | A flat purple grid; reads as a placeholder |
| All six hunting caves | Cave rock and cave floor | walls.png row 2, `cave_tile` | Blocky oblique brick cubes tinted per cave on a flat floor. The Highmoor deep mine already uses the new rock blocks (`mountains.png`), so the caves look a generation older than the mine next to them |
| Ashford crypt | Crypt walls | walls.png row 0 (grey stone) | The same old oblique cubes in grey |
| Humanoid monsters | Lizard warriors and shamans | catalog gear on the human rig | Lizardfolk drawn as hooded humans; ogre shamans likewise (`creatures.py` has no lizard or ogre biped) |

Already fine: town streets, house walls, roofs, snow and snowy cobbles, firs, trees, outcrops,
the cellar walls, furniture and lamps, the painted creatures, the frost isles' log walls.

## Steps
1. **Shores first** (the most seen): repaint `water_tile` in the grass's manner (two or three
   tones of blue in soft clumps, lit ripples, wrapping at the edges) and draw shore overlays where
   water meets land: wet sand and a foam line, as `curb_overlay` does for streets, picked by the
   land's sides (corners too, so no square steps show).
2. **Ground**: sand, dirt, gravel, bog, and dusk soil get the grass treatment (clumps, a texture
   of their own: ripples and shell bits, pebbles and ruts, wet glints and reeds), and soft fringes
   where each meets grass (grass blades spilling over the edge), all edges and corners.
3. **Planks**: grain, nail heads, board ends, and dark gaps; dock edges over water.
4. **Caves and the crypt**: draw cave rock (`O`/cave `#`) with the mountain rock builder, tinted
   per cave (`Caves.CAVES[...]["ambient"]`), and the crypt's walls as house-stone walls in grey
   ashlar; cave floors as rock floor with pebbles and cracks.
5. **Obsidian**: glassy black flagstones with violet glints and cracks, joints not a flat grid.
6. **Lizardfolk and ogre shamans**: `biped` builds in `creatures.py` (scaled snout and tail,
   ogre bulk), keeping their weapons.
7. Rebake the world map; refresh `docs/art.md`'s sheet table.

## Tests
Visual: one capture per repainted tile kind beside grass (water and shore, sand, dirt, bog,
planks, a cave, the crypt, obsidian), checked against its sheet texels; the shore overlay is drawn
on every land side of a lake. Unit: every terrain has its tiles and overlays in the sheet.

## Done when
The screenshot tour shows no flat or square-edged tile next to the new grass, and the caves
match the mine.
