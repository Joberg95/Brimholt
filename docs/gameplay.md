# Gameplay

How Brimholt plays: key bindings, combat, parties, loot, death, the world, inventory, and stats. Quick controls are in the [README](../README.md#controls).

## Action bar and key bindings

The nine-slot action bar sits at the bottom of the game window, with each slot's key in its
corner. The bar holds spells only: right-click a slot to pick one of your vocation's spells
or clear it. Change gear on the equipment panel; targeting, pick up, and the world map have
their own keys. Click **Controls** in the top bar to rebind any action: click a key button, then
press the new key. Each action has a primary and a secondary key; Backspace clears one,
Esc cancels, and a key already in use moves to the new action. Keys follow their physical
position, so WASD stays under your hand on any keyboard layout. Bindings and bar contents
are saved per computer in Godot's user data folder (`user://keybinds.cfg`).

## Combat

Combat follows Tibia's model. Left-click a monster (or Space for the nearest) to lock it
with a red square; you then attack automatically every **2 seconds** while it is in reach.
Knights fight in melee (any of the 8 surrounding tiles); Paladins (6 tiles), Sorcerers, and
Druids (5 tiles) attack at range, which needs a clear line of sight: walls and trees block
it, water does not. If your target is out of reach and you are not steering, you walk
toward it. Spells sit on the action bar; each costs mana, has its own cooldown, and starts
a shared cooldown for its group (attack 2 s, healing 1 s). Every vocation has Light heal;
Knights add Brutal blow and Whirling strike (level 10), Paladins Piercing shot and Holy
mend (level 8), Sorcerers Ember bolt and Flame wave (level 10), and Druids Frost bolt,
Mend, and Mass mend (level 10), which heals everyone within 3 tiles.

Monsters stand idle until a player comes within 6 tiles, then chase and attack, but never
farther than 12 tiles from their spawn or across a zone edge; out of reach, they walk home
and heal. They respawn 45 seconds after death, once no player stands within 4 tiles of the
spawn. Monsters chase along real paths around trees and walls. Level 1–4 voles and toads
ring Cinder Crossing; beyond them, levels rise to 35 in the far east and south, and
Blackreed Isle holds levels 40–50. Spawns sit in small clearings at least 7 steps from
roads, so travel between towns stays safe. Early monsters hit softer (half damage at level
1, full at level 11), and a monster's name shows its level in white (fair), yellow (tough),
or red (5+ levels above you). Experience is shared by damage dealt; level 2 takes about 4
kills. Monsters drop loot from their own table (see below), spilling onto nearby tiles when
the corpse tile is full. Health and mana regenerate every 2 seconds,
three times faster after 8 seconds out of combat. Players can only attack each other while both stand in a PvP zone (Blackreed
Isle); leaving it drops the target.

## Parties and shared experience

Right-click another player to **Invite to party**; they right-click you to **Join party**
(or you **Withdraw invitation**). Right-click yourself or a member to **Leave party**. Only
the leader invites; when the leader leaves, the member who joined the game first leads, and
a party of one disbands. Disconnecting leaves the party. Nameplates show a blue shield for
members (gold rim for the leader) and a faint shield for open invitations. Party members
cannot attack each other, even on Blackreed Isle.

Like Tibia's shared experience, the party pools its members' share of each kill and splits
it evenly among members who are within 20 tiles of the kill and fought, cast a spell
(healing too), or were hit in the last 2 minutes. So a Knight who tanks while a Sorcerer
deals the damage levels just as fast. Sharing needs at least two such members whose lowest
level is at least two thirds of the highest (otherwise everyone keeps their own damage
share). Distinct vocations among them multiply the pool: ×1.2 for one, ×1.3 for two, ×1.6
for three, and ×2 for all four.

## Loot

Each monster has a loot table in `game/data/monsters.gd` (`Monsters.LOOT`): every `[item,
chance]` row rolls independently, then gold piles are added (one per 10 levels plus a 60%
chance of one more; elites +3). Rows are a material unique to the monster (vole tails, toad
slime, boar tusks, bandit badges, wolf pelts, ... warden crests; 20–50% chance) and
occasional equipment (1–8%). Materials have a shop `value` in `World.ITEMS` for the
upcoming shops. Add a monster's row to `LOOT`, and a new material to `World.ITEMS`,
`SpriteArt.ITEM_ORDER`, and `tools/generators/make_sprites.py` (icon shape and palette). Loot is not
reserved for the killer yet.

## Death and skulls

Dying costs 10% of your total experience (which can lose levels) and returns you to Cinder
Crossing at full health. **Below level 8 you keep your items and gold**, so an early death
cannot strand you. From level 8, as in classic Tibia without blessings, you always lose your whole
backpack and all purse gold, and each worn item has a 10% chance to drop. Everything lost
lands on the tile where you fell, spilling onto tiles within 3 steps (six items per tile),
and anyone can pick it up, including you on a run back to your body.

Attacking an unmarked player gives you a **white skull** for 15 minutes (renewed while you
keep attacking). Fighting back against someone who attacked you, or attacking a skulled
player, is self-defence and gives no skull. Killing an unmarked player who did not attack
you is an **unjustified kill**; three within 24 hours give a **red skull** for 30 days, and a
red-skulled player who dies loses everything they wear as well. Skulls show next to the
name above the character and stay after death. Yellow and black skulls are not used.

On screen, creatures show a name and a health bar that turns yellow and red, damage rises
in red (critical hits in orange), healing in green, and experience in white. Ranged attacks
fly as projectiles and area spells flash their tiles. Your health and mana bars sit in the
top-left of the game window.

## Talking to people

There is no typed dialogue: right-click a person to open their menu and pick an option.
Ferrymen offer **Travel**; shops (**Buy**) and **Quests** will use the same menu later.

## The world and ferries

The world is 256×256 tiles: walking straight across takes about 46 seconds. Cinder
Crossing, the starting town, sits in the north-west corner with gates to the east and
south. A sea runs down the whole western edge with four port towns on its coast:
**Cinder Landing**, **Mossford**, **Saltmere**, and **Wrenhollow**. Their ferries sail
between each other. Inland to the east lies one large, irregular lake with the town of
**Reedmere** on its west shore. Its ferry is the only way to **Blackreed Isle**, the
island in the lake: a **level 40–50 PvP hunting ground**. Entering it shows a red banner,
and the island is tinted red on the minimap and world map.

Each port has a ferryman at the end of its pier. Stand within 2 tiles, right-click him,
choose **Travel**, and pick a destination; the host checks your
distance, the route, that you are standing still, a 1-second travel cooldown, and your
gold, then deducts the fare and lands you next to the destination ferryman. A crowded
dock refuses passengers.

Everyone starts with 100 gold. Gold coin piles lie around the wilds; picking one up adds
25 gold to your purse without using a backpack slot. Coastal fares are 15–30 gold; the
island crossing costs 40 each way. Extra gold lies near the island's monster spawns.

## Inventory

The right-hand panel shows a Tibia-style paperdoll with eight slots (necklace,
helmet, charm / main hand, armor, off hand / two rings), an eight-slot backpack, and
your stat sheet. Everyone starts with an Ember cap, Moss coat, Copper blade, Oak
buckler, and Copper band. A Garnet ring, River pendant, Hearth charm, and a few other
items lie around Cinder Crossing. Rings fit either ring slot; right-clicking a ring
fills an empty ring slot first. Helmets, armor, and both hands are drawn on the
character; rings, necklaces, and charms are too small to show. Items can be dropped
on any walkable tile, stacking up to six per tile, and the top item is picked up.
Ground tiles must be your own tile or one of the eight around you.

Peer 1 validates every item move: location shape, reach, slot type, free space,
stack limit, and a 150 ms item cooldown. Dragging onto an occupied slot swaps
items when both fit; a worn item displaced from the ground goes back to that tile.
Equipped items are visible to everyone; backpack contents are sent only to their
owner. Late joiners receive ground items in the snapshot. Items carried by a
player who leaves disappear with them; ground items remain until the host stops.
The backpack is flat: there are no nested containers or trading.

## Stats and balance

Pick a vocation in the top bar before hosting or joining (or pass `--vocation=knight`,
`paladin`, `sorcerer`, or `druid` after `--`). The four follow the classic roles:
**Knight** (tank: most health, base defense), **Paladin** (ranged damage, light healing),
**Sorcerer** (burst damage, frail), and **Druid** (healer, frail). The host validates the
choice during the handshake; everyone sees each player's vocation and level.

Each item has stats (health, mana, attack, defense, critical chance, regeneration,
healing) that add to your vocation's base stats for your level; the stat sheet shows the
totals and the gear bonus. Charms, rings, and necklaces give passive stats only. Stats are
computed with the same shared function on every peer from server-authoritative vocation,
level, and equipment.

`game/data/balance.gd` defines the level 1-50 curves, all derived from a **350,000-health
final boss** that needs a raid of **at least ten level-50 players with every vocation**:
an enrage timer demands damage, raid-wide pressure demands healers, and wound stacks
demand two tanks. See [`balance.md`](balance.md) for the anchors, vocation
profiles, raid checks, and full level table.
Combat uses these stats and curves directly.
