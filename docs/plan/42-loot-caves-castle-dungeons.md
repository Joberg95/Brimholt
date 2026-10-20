# 42 - Loot worth in valuables, Tibia-style cave rock, dungeons in cities and castles

**Effort:** L  **Owner request (2026-10-20):** before world design resumes.

## Request
1. Monsters drop far fewer items; a kill's worth is in valuables (gems) to sell and trade up
   for high-value items, balanced so hunting pays.
2. Cave walls like the owner's Tibia screenshots: masses of rounded light-grey boulders with dark
   crevices round a dark earthen floor.
3. Dungeon variety inside cities and castles (for example guards in red to fight under a castle).

## Done
- **Loot (2026-10-20):** tiered gear from ordinary monsters 4% -> 1%, elites 25% -> 8%, named gear
  on ordinary and elite monsters at 40% of its old chance (champions and bosses unchanged).
  Ten cut gems (`small_amethyst` .. `small_diamond`, `great_emerald` .. `great_diamond`) drop
  worth `Balance.valuables_per_kill` on average (1 gold per level, x4 elites, x12 champions,
  x25 bosses), small gems by monster level (`Monsters.VALUABLES`), great gems from level 35
  carrying a quarter of it; they stack and sell to vendors for their value. Gem icons are small
  hand-pixelled cut stones (pixel_materials.py `gem`, `great_gem`, drawn at their own size).

- **Cave rock (2026-10-20):** cave_rock.png, rounded pale boulders with dark crevices, used for
  rock in caves only (overworld mountains unchanged); the farming caves got a brighter light.

- **Aldmoor barracks (2026-10-20):** an instanced dungeon under Aldmoor's keep (Dungeons
  aldmoor_barracks, copies stacked under the crypt's via "under"), entered by a ladder opening in
  the keep's lower hall: crimson guards and crossbowmen, Captain Marrec (champion, crimson warhorse
  mount), tasks from Sergeant Brenna beside the stairway. Sandstone floors, fieldstone walls.

## Next
- More town and castle dungeons on the next islands, each with its own guard or cult.
- Show valuables in the lexicon.
