# 32 - Continents with one major and one smaller city each

**Effort:** XL  **Needs from you:** which mainland towns stay as cities

## Request
Redesign the map so each continent has one major city and one smaller one. The sketch adds a new
continent in the sea south-west of the mainland, below the frost isles, and lets the mainland
run on past its current edges.

## Today
The mainland has seven towns (Cinder Crossing, Reedmere, Ashford, Emberfall, Dunmere, Highmoor,
Lastlight); the frost isles have Hrimvik. Towns hold the vendors, artisans, task givers, the bank,
ferries, and waystones, and the task chains assume them.

## Steps
1. **Decide the cities**: per continent one major city (bank, all services, several task givers)
   and one smaller town. The other mainland towns become outposts (a camp with one or two task
   givers and a waystone, no walls) or are removed; their givers move.
2. **The new continent**: placed like the frost isles in free grid space and on the world map
   (`game/data/atlas.gd`, plan 29's continents), reached by boat, with its own biome, a major city,
   a smaller town, hunts, and a cave, fitting a level band.
3. **Frost isles**: Hrimvik is the major city; add a smaller settlement.
4. **Move content**: tasks, givers, ferries, and coach routes; update the docs and tests.

## Tests
Unit: each continent has exactly one major city and one smaller town; every task giver stands in
a city, town, or outpost; every continent is reachable by boat.

## Done when
The world reads as continents, each with its capital and a second town.
