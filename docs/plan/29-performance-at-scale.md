# 29 - Performance at scale: only what is near a player costs anything

**Effort:** M

## Request
Before the world map grows much bigger: render and simulate only what is near the player (say
100 tiles), and perhaps treat each continent (the frost isles) as its own zone, without breaking
gameplay. What is the best practice?

## Today (measured on this machine, 2272 monsters in 441 camps, a 682x560 grid)
- **Rendering is already local.** The world view draws only the visible cells; floors are built in
  16x16 chunks near the camera and freed far from it; lights are culled to the view. Frames take
  4-5 ms (190-234 fps) in a busy town, a hunt, and a twenty-player raid. Map size does not show.
- **Network is already local.** Clients get monsters and effects only within 24 tiles
  (`main.gd` INTEREST_RADIUS); the terrain itself is 380 KB, small enough to keep whole.
- **The host is not.** Monster AI sleeps outside the chunks round players, but every tick still
  visits all 2272 monsters to ask: 2.2 ms a tick with none awake, growing with every camp added.
  Startup builds the whole world (1.7 s: the scene 0.5 s, buildings and furnishing 0.5 s, regions
  0.2 s, the map hash 0.3 s) and then spawns every camp (1.4 s).

## Best practice, for this game
Spatial partitioning and interest management, at chunk grain rather than continent grain: a
continent is just a big chunk set, and chunks also cover a large continent with one player on
it. Keep the static map whole (it is tiny); make live entities and their cost proportional to
where players are. Concretely:

## Steps
1. **Tick only awake monsters.** Index monsters by sleep chunk (`Combat`), and keep a set of
   active ones (chasing, returning home, engaged). A tick visits the chunks round players plus
   the active set: constant in map size.
2. **Spawn camps when first needed.** `populate` registers camps by chunk; a camp spawns the
   first time a player (or bot) comes within the wake range (two chunks), and stays. Startup
   no longer spawns 2000+ monsters; far camps cost nothing until visited. Respawns unchanged.
3. **Cheaper world load.** Hash the terrain bytes instead of joining every row into a string,
   and remove the quadratic parts of street dressing (lamp spacing by a spatial lookup).
4. **Continents as data.** `Atlas` sheets become named continents (`World.continent_at`): the
   banner says when you sail to another continent, and the minimap and world map open on it.
5. **Keep it measured.** `make bench` gains a frost-isles scene and prints the host tick and
   startup times, so growth shows up in numbers.

## Tests
Unit: a tick visits only monsters near players or active; a camp spawns when a player comes
near and not before; far camps cost nothing; every camp still fills when visited; continents
cover every overworld cell. Soak, visual, playthrough, LAN, and the bench before and after.

## Done when
Host tick cost and startup no longer grow with the number of camps far from players, and the
bench shows it.
