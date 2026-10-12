# Testing

Run these through `make` (see `make help`) or directly. Every check uses Godot 4.5+ and Python 3 (standard library only).

| Command | What it runs | Time |
| --- | --- | --- |
| `make import` | Headless import; parses every script and resource | ~10 s |
| `make test-unit` | `tests/unit/rules_test.gd`: deterministic rule checks | ~5 s |
| `make test-lan` | `tools/testing/test_lan.py`: four real ENet scenarios | ~1 min |
| `make test` | Both of the above | ~1 min |
| `make test-visual` | `tools/testing/test_visual.py`: offscreen graphical checks, `.tools/visual-report.html` | ~30 s |
| `make check` | Import, unit, LAN, and visual | ~2 min |
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

## Unit rules

The rules checks cover movement, reservations, collision, spawns, equipment slots and
ring swaps, item stats, the balance anchors and curves, sprite sheet layout and coverage,
and inventory moves (malformed locations, reach, slot types, swaps, full backpack,
stack limit, cooldown boundary, and backpack privacy), the map scene (known terrain,
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
leadership hand-over, disbanding, no friendly fire, shared experience with the vocation
bonus, activity, range and level-ratio rules, disconnect clean-up),
respawn delays, the 10% death penalty and town respawn, spells (vocation, level, target,
mana, cooldowns and groups, heal caps, area hits, mass heal radius), regeneration, item
loss (backpack and purse always, worn items about 10%, everything with a red skull, spill
within the stack limit), and skulls (white for unprovoked attacks, self-defence, renewal,
unjustified kills, the third giving a red skull, the 24-hour window, expiry).

## LAN integration

The bounded ENet harness
runs a real playing host, client, and late joiner over loopback, checking
authority, cooldowns, collision, equipment updates, rejected item moves, a drop
seen in the late-join ground snapshot and then picked up by the late joiner,
a party invitation accepted through the right-click options (private invitations, public
membership) and disbanded when the member disconnects, backpack privacy, snapshots, and
disconnect cleanup. `--dedicated` checks a server
without a playing character and a moving, equipping, dropping, picking-up, and
ring-equipping client, checks the replicated level and backpack privacy, and sails the
client from Cinder Landing to Mossford after rejected out-of-range, unknown-route, and
malformed travel requests. (The server test script carries the client to the dock
instead of walking.) Then the server places a weak monster beside the client, which sends
a malformed target, locks the monster, casts Piercing shot, and must see floating damage,
the kill, its experience, and its cleared target; the late joiner must receive every
monster in its snapshot. `--host-loss` checks the exact disconnect error and
clearing stale client state. `--occupied-port` checks an explicit hosting error
and exit status 1 while another socket holds the port.

Each peer has a 20-second deadline; multiplayer scenarios have a 30-second outer
deadline. The occupied-port check has a 10-second deadline. The harness stops only
its own processes and fails on unexpected Godot errors; only the exact expected
disconnect message is accepted in the host-loss scenario. Inspect headless editor
output for script/resource errors, not just its exit status.

## Visual

The graphical check renders the game into an offscreen buffer; Godot only opens a
64×64 borderless window in the top-left corner, so nothing flashes over your work; it
ignores OS close requests. It writes
ignored captures (equipped, unequipped, forest, Cinder Landing, world map) and
`.tools/visual-report.html` (open it in a browser or an editor's browser panel). It checks pixel changes in each character's region
and each equipment panel slot after removing gear, four facings, ground item and
raised oblique wall pixels matching their sprite texels, the camera staying centred and gliding with the
character, an interpolated movement midpoint/endpoint, a tree sprite in depth order,
sailing through the real right-click menu and route list (Cinder Landing to Mossford,
then Reedmere to Blackreed Isle), the island's PvP banner, casting the spell in action
bar slot 1 with its key (the bar holds spells only), and opening and closing the world map with its bound key.
Key presses use the player's current bindings. Finally it spawns two monsters, locks one
with a real left-click, and checks the red target square and a landed hit. The map's own
monsters are removed at the start so the pixel checks stay deterministic. It also uses simulated mouse
input sent to the offscreen buffer to start a drag from the backpack, right-click a
tile to pick up, and right-click a backpack item to equip; the drop itself is delivered
to the map's drop handler.
Its 20-second timeout stays active through the assertions.

## Playthrough

The playthrough starts a real dedicated server and two bot clients (`tests/integration/playthrough.gd`),
a Knight and a Sorcerer, that play the game through the same calls as the UI: they form
a party, equip the start kit, walk out of town with pathfinding, hunt the nearest monsters
with spells and healing (checking that party sharing keeps the Knight level with the
Sorcerer), pick up gold and nearby monster materials, finish their fight, walk to Cinder Landing and sail to Mossford, walk to Reedmere
(routing around monster spawns), and sail to Blackreed Isle. There the Knight leaves the
party and attacks the
Sorcerer (white skull), the Sorcerer fights back (no skull), and the Knight kills him
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
