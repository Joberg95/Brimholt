# 44 - The floor below: tunnels and sewers under the mainland

**Effort:** L  **Owner request (2026-10-20):** after comparing with Tibia's map (16 floors, caves
right under the land they belong to), add floors as planes beside the overworld, starting with
one underground floor under the mainland; keep moving the old caves and dungeons for later.

## Design
- A floor is a full overworld-sized plane laid beside it in the same 2D coordinates:
  `Atlas.UNDERGROUND` starts at `Atlas.UNDER_X` (2560, past the dungeon and cave bands, on a
  sector boundary), and the cell under surface (x, y) is `Atlas.below(x, y)` = (x + 2560, y).
  Every system keeps working on plain cells; unpainted plane cells are void.
- A hole or ladder (`v`) on the surface over stairs up (`^`) right below joins the floors
  (`World.HOLES`, found at load with the grid's own search). `Instances.climb` puts you beside
  the other end. Holes in the wilds draw as holes, ladders in towns as ladder openings, stairs up
  as rough steps (tunnels) or a ladder (sewers).
- Zones on the plane are underground (dim light, no weather, no mounts, monsters stay inside),
  the plane's rock is cave rock on cave earth (`SpriteArt.rock_cave`), bots route there in a
  space of their own (`Nav.space_of`), and the map marks every way up and down.

## Done (2026-10-20)
- `make underground` (tools/generators/underground.gd, once): twelve tunnel networks for levels
  10-40 under the countryside (Greywood Burrows, Hazel Downs Dens, Wolfholt Warrens, Fernmere
  Grottoes, Gloamwood Hollows, Barrowmoor Catacombs, Saltreed Sea-caves, Kestrel Caverns,
  Stonevale Delvings, Greycrag Mines, Emberwaste Hollows, Smoulder Deeps): chambers joined by
  passages that wander over a noise field, loops and dead-end spurs, walled in cave rock, about
  eight holes each in open ground, camps of 5-7 in the chambers (overworld monsters inside their
  heartland bands so task bands stay). Sewers under Reedmere, Ashford, Dunmere, Highmoor, and
  Brackenford: walkways along bridged water channels, chambers where they cross, brick walls,
  rats, and ladders down from the streets. About 80 000 cells, 188 ways between the floors.
- Tests (`_underground_checks`): the plane lines up, every hole pairs with stairs right below and
  nothing stands on it, every network and sewer is a separate underground zone whose camps are all
  reached from its stairs, climbing down and back works, nobody rides below.

## Next
See plan 45.
