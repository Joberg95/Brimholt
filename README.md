# Brimholt

An original Godot tile-world prototype for up to **four LAN players**, including a
playing host. It uses native ENet, server-authoritative grid movement, collision,
smooth visual interpolation, a flat backpack with ground items, and layered visible
equipment. Maps, items, and character drawings are original procedural placeholders. Brimholt is a working name;
trademark/name availability has not been verified.

## Setup and LAN play

Requires **Godot 4.5+**; development checks use **4.5.1**. Open `project.godot` in
Godot and press **F5**, or run from this folder:

```sh
godot --path .
```

Replace `godot` with your executable path if it is not on PATH. There is no Node
server, external service, API key, or bundled engine dependency.

Click **Host** in one instance. In another instance, enter the host's LAN IPv4
address and click **Join**. Use `127.0.0.1` only for two instances on the same
computer. All computers must use the same project files. Allow inbound **UDP
1234** through the host firewall; ENet does not use TCP/WebSockets.

```sh
# Playing host
godot --path . -- --host

# Client on the same computer; replace the IP for another LAN computer
godot --path . -- --join=127.0.0.1

# Optional dedicated host: no host character, up to four clients
godot --headless --path . -- --headless-server
```

For an alternative UDP port, add `--port=1235` after `--` on every instance.
The world resets when the host stops; there is no persistence. This is a
**trusted-LAN prototype**, not an Internet-ready service. Do not expose its port
to the public Internet.

## Controls

| Control | Action |
| --- | --- |
| WASD / arrows | Move one cardinal tile; hold to repeat |
| Drag an item | Move it between backpack slots, equipment slots, and nearby tiles |
| Right-click item | Equip from the backpack, or unequip into the backpack |
| Right-click tile / G | Pick up the top item on a tile (G: your tile, else the one you face) |
| 1 / 2 / 3 | Toggle helmet / armor / hand using the first fitting backpack item |
| Leave / close window | Disconnect; leaving the host ends the session |

Walls, water, and players block movement. A gold ring marks your character.

## Presentation

The game window shows 15×11 tiles at 2× zoom and follows your character smoothly,
Tibia-style; the dedicated-server window centres the whole map. Walls are oblique:
their tops are raised up and to the left, and the world is drawn row by row so
walls nearer the camera (south/east) cover characters and items behind them.
Grass, dirt, animated water, stone walls, characters, worn gear, and item icons
are original procedural pixel art with outlines, shading, and a walking stride;
no image assets are used.

## Inventory

The right-hand panel shows your equipment slots (helmet, armor, hand) and an
eight-slot backpack. Everyone starts with an Ember cap, Moss coat, and Copper blade
in the backpack. A few more items lie around Cinder Crossing; items can be dropped
on any walkable tile, stacking up to six per tile, and the top item is picked up.
Ground tiles must be your own tile or one of the eight around you.

Peer 1 validates every item move: location shape, reach, slot type, free space,
stack limit, and a 150 ms item cooldown. Dragging onto an occupied slot swaps
items when both fit; a worn item displaced from the ground goes back to that tile.
Equipped items are visible to everyone; backpack contents are sent only to their
owner. Late joiners receive ground items in the snapshot. Items carried by a
player who leaves disappear with them; ground items remain until the host stops.
The backpack is flat: there are no nested containers, loot tables, or trading.

## Structure and checks

`game/world.gd` owns the original map, spawns, item catalog, ground items, and
authoritative movement/inventory rules. `game/main.gd` handles ENet,
sender-validated RPCs, host/join UI, the camera, the inventory panel,
drag-and-drop, and interpolation. `game/world_view.gd` draws the depth-ordered
world, `game/tile_art.gd` the terrain and oblique walls, and
`game/character_art.gd` facing-aligned character/equipment layers and item icons. Peer 1 keeps gameplay authority; clients request actions,
never positions, item contents, or appearance.
The connection handshake checks matching map, catalog, ground items, inventory
and movement parameters, player capacity, and protocol. Command-line startup exits nonzero if hosting
cannot bind its UDP port or the supplied join address is empty.

From this folder, with Godot 4.5+ and Python 3 (standard library only):

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/rules_test.gd
python3 tools/test_lan.py --godot godot
python3 tools/test_lan.py --godot godot --dedicated
python3 tools/test_lan.py --godot godot --host-loss
python3 tools/test_lan.py --godot godot --occupied-port

# Graphical gear/removal and interpolation checks; not headless
mkdir -p .tools
godot --path . --script res://tests/visual_test.gd
```

The rules checks cover movement, reservations, collision, spawns, equipment, and
inventory moves (malformed locations, reach, slot types, swaps, full backpack,
stack limit, cooldown boundary, and backpack privacy). The bounded ENet harness
runs a real playing host, client, and late joiner over loopback, checking
authority, cooldowns, collision, equipment updates, rejected item moves, a drop
seen in the late-join ground snapshot and then picked up by the late joiner,
backpack privacy, snapshots, and disconnect cleanup. `--dedicated` checks a server
without a playing character and a moving, equipping, dropping, and picking-up client. `--host-loss` checks the exact disconnect error and
clearing stale client state. `--occupied-port` checks an explicit hosting error
and exit status 1 while another socket holds the port.

Each peer has a 20-second deadline; multiplayer scenarios have a 30-second outer
deadline. The occupied-port check has a 10-second deadline. The harness stops only
its own processes and fails on unexpected Godot errors; only the exact expected
disconnect message is accepted in the host-loss scenario. Inspect headless editor
output for script/resource errors, not just its exit status.

The graphical check writes ignored `.tools/visual.png` and
`.tools/visual-unequipped.png`. It checks pixel changes in each character's region
and each equipment panel slot after removing gear, four facings, a drawn ground
item, a raised oblique wall top, the camera staying centred and gliding with the
character, and an interpolated movement midpoint/endpoint. It also uses simulated mouse
input to start a drag from the backpack, right-click a tile to pick up, and
right-click a backpack item to equip. Godot resolves the final drop position from
the real OS cursor, so the test delivers the drop to the map's drop handler
instead of moving your cursor.
Its 10-second timeout stays active through the assertions. Headless checks do
**not** establish visual quality. Inspect the images or play with two windows to
assess it. Networking scenarios run on local loopback; **separate physical-machine
LAN play remains unverified** and still needs network/firewall checks.

## Scope and reference licensing

Combat, vocations, nested containers, loot/trading, death penalties, procedural
caves, floors, NPCs, persistence, and authentication are outside this prototype.

[The Forgotten Server](https://github.com/otland/forgottenserver) (GPL-2.0) and
[OTClient Redemption](https://github.com/mehah/otclient) (MIT) are useful references
for high-level container/item concepts and inventory-event/UI separation, not
Godot/ENet dependencies. No third-party code or assets are imported here. Do not
copy or translate GPL code into this project without a licensing decision.
MIT reuse requires checking the specific files/dependencies and retaining their
copyright/license notices. Neither engine's source license grants rights to
proprietary Tibia sprites, maps, or client data.
