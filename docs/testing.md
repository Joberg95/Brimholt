# Testing

Run these through `make` (see `make help`) or directly. Every check uses Godot 4.5+ and Python 3 (standard library only).

| Command | What it runs | Time |
| --- | --- | --- |
| `make import` | Headless import; parses every script and resource | ~10 s |
| `make lint` | `tools/testing/lint.gd`: parses every script with the strict warnings in `project.godot` | ~5 s |
| `make test-unit` | `tests/unit/rules_test.gd`: deterministic rule checks (about 780 assertions) | ~3 s |
| `make test-lan` | `tools/testing/test_lan.py`: five real ENet scenarios | ~1 min |
| `make test` | Lint, unit, and LAN | ~1 min |
| `make test-visual` | `tools/testing/test_visual.py`: offscreen graphical checks, `.tools/visual-report.html` | ~30 s |
| `make fight-sim` | `tools/testing/fight_sim.gd`: one monster (`MONSTER=`, `LEVELS=`, `COUNT=`) against each class, auto-attacks vs spells and potions | ~10 s |
| `make duel-sim` | `tools/testing/duel_sim.gd`: same-level PvP duels per class pair with spells and potions (`LEVELS=`) | ~30 s |
| `make soak` | `tests/integration/soak_test.gd`: busy hosted session, fails on growth (memory, objects, nodes, pools) | ~1 min |
| `make check` | Import, lint, unit, LAN, visual, and soak | ~3 min |
| `make playtest` | `tools/testing/playtest.py`: two-bot playthrough, `.tools/playtest/report.html` | ~5 min |

Without `make`:

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/unit/rules_test.gd
python3 tools/testing/test_lan.py --godot godot            # also --dedicated, --host-loss, --occupied-port
python3 tools/testing/test_visual.py --godot godot
python3 tools/testing/playtest.py --godot godot
```

Tests live by kind: `tests/unit/` (pure rules, no networking or rendering),
`tests/integration/` (real ENet peers and the bot playthrough), and `tests/visual/`
(offscreen rendering). The Python runners in `tools/testing/` start and supervise the
Godot processes and write the reports.

## Lint

`project.godot` treats these GDScript warnings as errors: untyped declarations, unused
variables, constants, parameters, private members, and signals, shadowing (locals, members,
and base-class properties such as `name`, `owner`, `visible`), unreachable code and patterns,
standalone expressions and ternaries, confusable local declarations, narrowing conversions,
redundant awaits, and constant asserts. Prefix an intentionally unused parameter with `_`.
The "unsafe" Variant warnings stay off: game state is dictionaries by design. `make lint`
parses every script under `game/`, `tests/`, and `tools/`, so a file nothing loads still
fails the check.

## Soak

`make soak` hosts a game offscreen (no saves) for 36 rounds. Each round moves the player to a
monster camp or town, kills nearby monsters (loot spills, effects fire, respawns queue), drops
a junk stack, and jumps the clock two minutes (`main.clock_skew`). It samples object, node,
orphan-node, and static-memory counts plus pool sizes. After a warm-up third, the last third may
not exceed the middle third by more than 3%. Orphan nodes, a light pool over its cap, ground
stacks that never decay, or more monsters than spawn slots also fail it. Run it after changing
anything that creates nodes, caches, or per-player/per-monster state.

## Unit rules

Each `check()` call site is one assertion, however many cases a loop feeds it (every item,
spawn, tile, or pose): the summary reads `BRIMHOLT_RULES: <assertions> checks, <failures>
failures (<cases> cases)`. Every failing case counts as a failure; the first three of each
assertion are printed. Prefer one assertion over a loop to many near-identical ones, and do not
re-check what another section already covers.

The rules checks cover movement, reservations, collision, spawns, equipment slots and
ring swaps, item stats, the balance anchors and curves, sprite sheet layout and coverage,
and inventory moves (malformed locations, reach, slot types, swaps, full backpack,
stack limit, cooldown boundary, and backpack privacy), item stacking (merging on pickup,
drag, and drop, the 100-item limit and overflow, gold stacks, bound checks), town services
(a vendor in every town and the one banker in Reedmere, stock and prices, buying, selling, and bad requests, bank
deposits and withdrawals, the shared depot and its banker range, what survives death, hunting
task credit and turn-in, pack upgrades and locked backpack slots, potions and their per-kind cooldowns), and saved characters (identity tokens and profiles, a full save and
restore including time-relative skull timers, `.bak` backups, refusing edited, swapped,
foreign, and damaged saves, and sanitizing a hostile but signed save), the map scene (known terrain,
spawn/item/ferryman markers, routes, and reachability of every ferryman and item on foot
or by boat), ferry travel (range, routes, malformed requests, standing still, fares,
cooldown, crowded docks), gold pickup, zones and monster spawns (levels within 1–50 and
their zone, Blackreed Isle as a level 40–50 PvP zone reached only from Reedmere), and key
bindings (defaults 1–9, rebinding moves conflicting keys, Escape is reserved, save/load,
and malformed or duplicate saved values), and combat: catalogs and spawns, line of sight
and reach, target validation (malformed, unknown, self, too far, PvP only in PvP zones),
the two-second attack boundary and damage range, monster aggro, chasing onto free tiles
only, leashing home and healing, experience shared by damage and level ups, loot tables
(every monster has one, catalog items with icons and shop values, seeded determinism,
drop rates, elite gold, spilling past a full corpse tile), parties (invites, joining,
leadership hand-over, disbanding, no friendly fire, shared experience with the class
bonus, activity, range and level-ratio rules, disconnect clean-up),
respawn delays, the 10% death penalty and town respawn, spells (class, level, target,
mana, cooldowns and groups, heal caps, area hits, mass heal radius), regeneration, item
loss (backpack and purse always, worn items about 10%, everything with a red skull, spill
within the stack limit), and skulls (white for unprovoked attacks, self-defence, renewal,
unjustified kills, the third giving a red skull, the 24-hour window, expiry), gear tiers
(every tier has one helmet, armor, weapon, and off-hand per class; accessories only
from tier 20; each tier beats the one below; tier weapons keep about six hits per kill;
level and class requirements, including swaps and the equip key; start kits; tier
drops), and relics (twelve, bound, glow sheets, each the reward of exactly one boss quest
and better than tier 45; boss health, lairs, slow respawns; trophies for attackers and
nearby active helpers only; one relic keeper per boss in Reedmere, claiming with range, the
wrong keeper (who names the right one), malformed, full backpack, and spent-trophy checks; no dropping and no loss on death), and the Hollow Reach (level 45-50 PvP zone, fully
themed, a single narrow gate, level 45+ spawns on open floor, Vaelith on the Sanctum floor
and reachable on foot from Cinder Crossing, obsidian blocking movement and sight, full
loot on death inside it while relics stay and other zones keep the 10% rule), boss raid
mechanics (engage warning, pulse timing, radius, and damage, wound stacks and their expiry,
Challenge swaps, enrage time and damage, and the reset when the raid leaves), and the
384×384 overworld (a single top-to-bottom coastal ferry, waystones linking every town,
towns as safe zones without spawns and away from the Hollow Reach, and more than 550 monsters),
instanced dungeons (stairways in towns, copies outside the overworld, layouts with one arrival,
exit, and champion, private and party-shared copies, a full dungeon, exits, delayed reset of
monsters and items, return to a stairway after a restart, separate spaces), monster sleep, and climate (desert
painter parity with the world terrains, cactus scrub blocks, no grass or trees left in the
desert core, spawns and items still walkable, and weather that is deterministic, smooth,
within range, reaches every kind, flashes only in storms, and is absent underground and dry
in the desert), chasing and leashing (monsters outpace players, a level 1 and a level 40
monster both catch a fleeing player, dragging past the leash or into a town resets them to full
health, a monster going home cannot be hurt or re-pulled and fights again once home, and steps
replicate their real duration), dungeon tasks (a hunt and a boss task per dungeon, given by its stairway, every dungeon
monster counting, experience and gold rewards, one giver per task), regions (every overworld
tile located, level ranges covering their monsters, the desert, towns, PvP, and dungeons),
blocked camps (queued at start, filled once there is room), town rest (only in towns, much
faster, ends when full or on leaving, a 3-minute cooldown visible to the owner),
spell progression (every class unlocks three or more spells from level 15 including a
stronger strike, listed by level, fitting the bar), PvP (player hits scaled by `PVP_DAMAGE`,
PvP combat starting for both players, reduced and fading healing, recovery after combat, and
monster fights never counting), the monster catalog contract (ids, names, ranks, looks, sizes,
ranges, idle pace, known fields only, no hand-set numbers, loot of real non-relic items, placement
on the map or in a dungeon, boss relics), long-session safety (ground decay timing, restarts on change, rate limit, and
exemptions for starting items and relics; the client spatial index; monsters closing in on a
player in one tick never sharing a tile), and buildings (door and room detection, the town painter is a no-op on the
map, two or more buildings per town, furniture inside keepers' buildings that blocks without
cutting rooms off, rarity grades (Common to Legendary by tier, relics apart, none for potions or packs), every vendor and the banker inside a building of their own
facing the door with a matching sign beside it, open rooms and doors, and no trading or banking
through a wall).

## LAN integration

The bounded ENet harness
runs a real playing host, client, and late joiner over loopback, checking
authority, cooldowns, collision, equipment updates, rejected item moves, a drop
seen in the late-join ground snapshot and then picked up by the late joiner,
a party invitation accepted through the right-click options (private invitations, public
membership) and disbanded when the member disconnects, backpack privacy, snapshots, and
disconnect cleanup. `--dedicated` checks a server
without a playing character and a moving, equipping, dropping, picking-up, and
client that is refused a level-20 ring at level 1 and wears it once the server raises it to
20, checks the replicated level and backpack privacy, and sails the
client from Cinder Landing to Lastlight after rejected out-of-range, unknown-route, and
malformed travel requests. (The server test script carries the client to the dock
instead of walking.) Then the server places a weak monster beside the client, which sends
a malformed target, locks the monster, casts Piercing shot, and must see floating damage,
the kill, its experience, and its cleared target; the late joiner must receive every
monster in its snapshot. Finally the server grants a Kharzul trophy in Reedmere: Ysolde
refuses the Cinderheart bow and names Brannoc, who trades it; the client cannot drop it.
The server then carries the client (hurt, with 200 extra gold) to the Cinder Crossing
vendor, banker, and Warden Brask: the client is refused an unstocked relic and the sale of
its bound bow, buys three health potions, drinks one, deposits gold, is refused an
overdraft, moves the potions into its depot, and accepts the boar task, all as RPCs. Then it
steps onto the cellar stairway, must receive only nearby monsters from its own copy, steps on
the stairs up, and must forget the copy's monsters back in town. Clients receive monsters and
combat effects only within 24 tiles in the same space; the late joiner checks it gets nearby
monsters only.
`--persistence` gives a dedicated host a temporary save folder: a druid joins with a fixed
identity, steps off its spawn, equips its weapon, and leaves; the host process is restarted on
the same folder; the same identity rejoins asking for a knight and must get its druid back on
the same tile with the weapon worn, and a third client with that identity is refused.
Integration tests and the visual check never use your real saves or identity: hosts run with
`--no-save` (or a temporary `--save-dir`) and clients with `--fresh-identity`. Test hosts add
`--allow-start-vocation` so bots can start with `--vocation=...`; the host-loss scenario
leaves it out and checks that such a client still arrives as an Adventurer.
`--host-loss` checks that a host bot reaches the client as a player (and that clients cannot create bots), the exact disconnect error, and
clearing stale client state. `--occupied-port` checks an explicit hosting error
and exit status 1 while another socket holds the port.

Each peer has a 20-second deadline (32 seconds in the longer dedicated-server scenario); multiplayer scenarios have a 30-second outer
deadline. The occupied-port check has a 10-second deadline. The harness stops only
its own processes and fails on unexpected Godot errors; only the exact expected
disconnect message is accepted in the host-loss scenario. Inspect headless editor
output for script/resource errors, not just its exit status.

## Visual

Quest list capture: `visual-quests.png` (a task in progress and one ready to turn in, each
with its giver and town; the quest list key hides it).

Roof captures: `visual-roofs.png` (Ashford's shop from the plaza: the roof hides the merchant
and their name; the sign hangs beside the door) and `visual-shop-inside.png` (inside, the roof
has faded and the merchant shows).

Weather and desert captures: `visual-rain.png` (rain draws drops and dims the light at noon),
`visual-rain-night.png` (night rain is darker; carried lights still show), and
`visual-desert.png` (a storm leaves the desert dry; cacti stand on sand).

The weapon study (`visual-weapons.png`) renders all 15 hunting additions as native/2x icons
and in four facings with stand/step-A/step-B poses (180 worn frames). Unit checks cover the
five-column sheets, the wind-up then strike timing, and that a swing turns only the drawn pose;
`visual-swing.png` shows a sword strike, and the frames before, during, and after must differ.
`visual-tooltip.png` shows an item tooltip whose name and frame carry the rarity colour. Each must differ from
the empty-hand render. Unit tests check all old and new weapon icon bounds and colours,
unique hunting silhouettes, tier-derived stats, equip/unequip and class/level rejection,
save eligibility, exclusion from shop stock and generic rolls, real source spawns, seeded
drop frequencies, and below-tier loot rejection. The dedicated ENet scenario equips and
unequips an Alder crook granted by its server fixture.

The isolated wardrobe capture (`visual-wardrobe.png`) compares no gear, armour only,
cape only, and armour plus cape in all four facings and all three animation poses.
Pixels outside the base body/cloth must be background when the cape slot is empty;
equipping a cape must change each pose. Unit checks also require a 33–37-pixel opaque
base-character height, stable foot anchors, and nonempty, unclipped frames for every
worn item.

The graphical check renders the game into an offscreen buffer; Godot only opens a
64×64 borderless window in the top-left corner, so nothing flashes over your work; it
ignores OS close requests. It writes
ignored captures (equipped, unequipped, forest, Cinder Landing, world map) and
`.tools/visual-report.html` (open it in a browser or an editor's browser panel). It checks pixel changes in each character's region
and each equipment panel slot after removing gear, four facings, ground item and
raised oblique wall pixels matching their sprite texels, the camera staying centred and gliding with the
character, an interpolated movement midpoint/endpoint, a tree sprite in depth order,
sailing through the real right-click menu and route list (Cinder Landing to Lastlight,
then Reedmere to Blackreed Isle), the island's PvP banner, casting the spell in action
bar slot 1 with its key (the bar holds spells only), and opening and closing the world map with its bound key.
Key presses use the player's current bindings. Finally it spawns two monsters, locks one
with a real left-click, and checks the red target square and a landed hit. Last, it
right-clicks Ysolde, opens Quests, claims the Abyssal plate with a Morvain trophy (she offers
exactly Morvain's relics), and checks that the glow layer lights the relic-wearing
player, a relic on the ground, Morvain, and Kharzul (`visual-relics.png`). Then it opens the
Cinder Crossing vendor's Trade window from the real menu, presses Buy 10 on health potions
(`visual-trade.png`), drinks one with the potion key, opens the banker's Bank window,
right-clicks the potions into the depot, wears a Pathfinder's pack, and checks the depot
slot, the pack slot, and the unlocked twentieth backpack slot are drawn (`visual-bank.png`). It
steps onto the Cinder cellar stairway, captures the Rat King in the private copy
(`visual-cellar.png`, with only that copy on the minimap), and captures the Highmoor mine's
cave rock (`visual-mine.png`). It ends at the
Hollow Reach gate and in the throne room with Vaelith, checking the PvP banner and the
obsidian floor texels (`visual-hollow-gate.png`, `visual-hollow-throne.png`). At night it
checks that the world darkens, the player's lantern lights the ground, the UI panel is
unchanged, and hits and spells emit particles that free themselves (`visual-night.png`,
`visual-particles.png`). Pixel checks run at a pinned noon. The map's own
monsters are removed at the start so the pixel checks stay deterministic. It also uses simulated mouse
input sent to the offscreen buffer to start a drag from the backpack, right-click a
tile to pick up, and right-click a backpack item to equip; the drop itself is delivered
to the map's drop handler.
Its 20-second timeout stays active through the assertions.

## Playthrough

The playthrough starts a real dedicated server and two bot clients (`tests/integration/playthrough.gd`),
a Warrior and a Sorcerer, that play the game through the same calls as the UI: they form
a party, equip the start kit, walk out of town with pathfinding, hunt the nearest monsters
with spells and healing (checking that party sharing keeps the Warrior level with the
Sorcerer), pick up gold and nearby monster materials, finish their fight, walk to the Cinder Crossing waystone and travel through it to Reedmere, walk to its pier
(routing around monster spawns), and sail to Blackreed Isle. There the Warrior leaves the
party and attacks the
Sorcerer (white skull), the Sorcerer fights back (no skull), and the Warrior kills him
(unjustified kill), then loots the dropped items while the Sorcerer checks his empty
backpack and purse in town. A bot that dies earlier walks back to recover its belongings (or, under beginner
protection, carries on).
The report lists each step as ok, fail, or finding (gameplay observations such as slow
levelling) with screenshots. Bots render offscreen in two borderless 64×64 windows in the
top-left corner. macOS may still give them keyboard focus, so test and bot windows
ignore OS close requests; the orchestrator stops them when the run ends. Headless checks do
**not** establish visual quality. Inspect the images or play with two windows to
assess it. Networking scenarios run on local loopback; **separate physical-machine
LAN play remains unverified** and still needs network/firewall checks.
