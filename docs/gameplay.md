# Gameplay

How Brimholt plays: key bindings, combat, parties, loot, death, the world, inventory, and stats. Quick controls are in the [README](../README.md#controls).

## Action bar and key bindings

The nine-slot action bar sits at the bottom of the game window, with each slot's key in its
corner. The bar holds spells only: right-click a slot to pick one of your class's spells
or clear it, or drag a slot onto another to swap them. Hover a slot to see what its spell
does: its unlock level, effect, damage or healing for your current level and gear (damage is
before the target's armour), mana cost, and cooldown.

Every spell is a **rune stone** carved with an Elder Futhark rune chosen for its meaning: Kenaz
(the torch) for Ember bolt, Isa (ice) for Frost bolt, Hagalaz (hail) for Hailstorm, Berkano
(the birch) for Light heal, Tiwaz (Tyr's spear) for Piercing shot, and so on; the tooltip and the
spell book name it.

The **spell book** (B, or "Open spell book" in a slot's right-click menu) lists every spell of
your class by unlock level with the same details; locked spells say the level they need.
Drag a spell's rune from the book onto the action bar to put it there. Before you join, it
shows the Adventurer's spells.

The **micro menu** right of the action bar has a button for each panel: Character (C), Spell
book (B), Quests (L), Lexicon (K), World map (M), and Controls. A gold frame marks the panels that are
open; hover a button for its key. The **character window** explains every stat (your base
value, what your gear adds, and what the stat does, such as how much your defense cuts
damage), shows experience to the next level, and your status: gold and bank, party, skull,
unjustified kills, town rest, and relic trophies waiting at a relic keeper. Change gear on the equipment panel; targeting, pick up, the world map, and the
health and mana potions (Q and E), the quest list (L), the spell book (B), and the character window (C) have their own keys. Click **Controls** in the top bar to rebind any action: click a key button, then
press the new key. Each action has a primary and a secondary key; Backspace clears one,
Esc cancels, and a key already in use moves to the new action. Keys follow their physical
position, so WASD stays under your hand on any keyboard layout. Bindings and bar contents
are saved per computer in Godot's user data folder (`user://keybinds.cfg`).

## Combat

Combat follows Tibia's model. Left-click a monster (or Space for the nearest) to lock it
with a red square; you then attack automatically every **2 seconds** while it is in reach.
Warriors fight in melee (any of the 8 surrounding tiles); Hunters (6 tiles), Sorcerers, and
Druids (5 tiles) attack at range, which needs a clear line of sight: walls and trees block
it, water does not. If your target is out of reach and you are not steering, you walk
toward it. Spells sit on the action bar; each costs mana, has its own cooldown, and starts
a shared cooldown for its group (attack 2 s, healing 1 s). Every class has Light heal, and each
unlocks stronger spells as it levels, so its damage keeps growing (spell damage is your attack
times the spell's power):

| Class | Spells (unlock level) |
| --- | --- |
| Warrior | Brutal blow (1), Whirling strike (10, around you), Challenge (20, taunt), Rending cut (20), Sundering blow (30), Earthshaker (40, 2 tiles around you) |
| Hunter | Piercing shot (1), Holy mend (8), Arrow volley (15, area), Radiant arrow (30), Sunlance barrage (40, area) |
| Sorcerer | Ember bolt (1), Flame wave (10, area), Arc lightning (20), Firestorm (30, area), Starfall (45, area) |
| Druid | Frost bolt (1), Mend (1), Mass mend (10, heals everyone within 3 tiles), Thorn lash (15), Hailstorm (30, area), Wild growth (40, a strong group heal) |

New spells fill empty action-bar slots when you reach their level (or right-click a slot to
choose one).

Monsters stand idle until a player comes within 3 tiles, so you can pull one from the edge of
a camp instead of the whole camp, then chase and attack. A chasing monster is a touch quicker
than you (0.17 s per tile against your 0.18 s), and much quicker when it outlevels you, down
to 0.13 s from 10 levels above: you cannot outrun a monster far above your level, and kiting
one of your own level gains you little. Fight with armor, spells, and potions, or flee. A monster gives up if you reach a town, drag it more than 12 tiles from its spawn, or
get more than 12 tiles away. It then heals to full at once and walks home, ignoring everyone
and taking no damage until it gets there, so you cannot wear one down and run. Every camp holds a fixed number of monsters (usually three). A killed monster respawns at its
camp 45 seconds later, once no player stands within 4 tiles of the camp, so hunting is
unlimited but limited by how fast camps refill: good camps are worth holding, and worth
fighting over in PvP zones. A camp that cannot place a monster (its ground is blocked) keeps
retrying every 5 seconds until it is full. Monsters chase along real paths around trees and walls. Level 1–4 voles and toads
ring Cinder Crossing; beyond them, levels rise to 35 in the far east and south, and
Blackreed Isle holds levels 40–50. Spawns sit in small clearings at least 7 steps from
roads, so travel between towns stays safe. Early monsters hit softer (half damage at level
1, full at level 11; a same-level monster needs about 18 hits to drop you), and a monster's name shows its level in white (fair), yellow (tough),
or red (5+ levels above you). Experience is shared by damage dealt; level 2 takes about 4
kills. Monsters drop loot from their own table (see below), spilling onto nearby tiles when
the corpse tile is full. Health and mana regenerate every 2 seconds,
three times faster after 8 seconds out of combat. In a town you **rest**: missing health or
mana comes back ten times faster than normal (about 25 seconds from empty to full) until you
are full or leave town. Then the rest needs 3 minutes before it can start again, so a town is
not a free heal in the middle of a fight; the line under the minimap shows "resting", "rest
ready", or the time left. Players can only attack each other while both stand in a PvP zone (Blackreed
Isle or the Hollow Reach); leaving it drops the target. Players hit each other 1.5 times
harder than their normal damage, and for 10 seconds after any hit between players both are
in **PvP combat**: all healing (spells, potions, and regeneration) works at 35%, and it fades
to nothing over 90 seconds of continuous PvP combat, so every duel ends. Same-level duels take
roughly 10–90 seconds.

## Parties and shared experience

Right-click another player to **Invite to party**; they right-click you to **Join party**
(or you **Withdraw invitation**). Right-click yourself or a member to **Leave party**. Only
the leader invites; when the leader leaves, the member who joined the game first leads, and
a party of one disbands. Disconnecting leaves the party. Nameplates show a blue shield for
members (gold rim for the leader) and a faint shield for open invitations. Party members
cannot attack each other, even on Blackreed Isle.

Like Tibia's shared experience, the party pools its members' share of each kill and splits
it evenly among members who are within 20 tiles of the kill and dealt damage, were hit,
or healed another player in the last 2 minutes (casting at full health does not count). So a Warrior who tanks while a Sorcerer
deals the damage levels just as fast. Sharing needs at least two such members whose lowest
level is at least two thirds of the highest (otherwise everyone keeps their own damage
share). Distinct classes among them multiply the pool: ×1.2 for one, ×1.3 for two, ×1.6
for three, and ×2 for all four.

## Loot

Each monster has a loot table in `game/data/monsters.gd` (`Monsters.LOOT`): every `[item,
chance]` row rolls independently. Rows include materials unique to the monster (vole tails,
toad slime, boar tusks, ... warden crests; 20–50% chance), which vendors will buy for its
`value`. On top, gold piles drop as one stack (one pile per 10 levels plus a 60% chance of
one more; elites and bosses +3), and a piece of **tiered gear** from the monster's level tier (4% from normal
monsters, 25% from elites; 30% of those come from the tier below). Loot spills onto nearby
tiles when the corpse tile is full and is not reserved for the killer yet. A new material
needs a row in `game/data/items.json` and a loot row; `make sprites` draws its icon.

### Hunting weapons

Fifteen additional weapons are **source-specific drops**, not shop stock or additions to the
generic tier pool. Existing equipment remains available. They use the same tier/class
attack budget as the regular weapon at that level: these are visual alternatives to collect,
not extra damage types or a new combat system. They can be equipped, sold, stored and saved
normally; none is a glowing or bound relic. Tooltips name their hunting sources.

Each chance below is an independent roll per kill, in addition to normal materials, gold and
generic gear. A monster must be at least the weapon's required level for that roll to award it.

| Weapon | Level | Class | Source and chance |
| --- | ---: | --- | --- |
| Quarry handhammer | 1 | Warrior | Giant rat 2%; Rat King 12% |
| Watchman's shortsword | 5 | Warrior | Road bandit 3.5% |
| Burrow falchion | 5 | Warrior | Rat King 18% |
| Poacher's flatbow | 10 | Hunter | Grey wolf 2.5% |
| Alder crook | 10 | Druid | Bog lurker 3.5% |
| Ashford arming sword | 15 | Warrior | Crypt skeleton 3.5% |
| Reedsteel sabre | 20 | Warrior | Outlaw archer 2.5% |
| Ridgewind recurve | 20 | Hunter | Outlaw archer 4% |
| Reliquary focus | 20 | Sorcerer | Abbot Morrow 12% |
| Stonebreak pickhammer | 25 | Warrior | Stone golem 3.5% |
| Mourning estoc | 25 | Warrior | Abbot Morrow 12% |
| Cinder spindle | 30 | Sorcerer | Cinder wraith 3.5% |
| Duskroot branch | 35 | Druid | Mire stalker 3.5% |
| Forgemaw arbalest | 40 | Hunter | Forgemaw 14% |
| Sanctum warhammer | 45 | Warrior | Obsidian golem 5.5% |

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

## Player bots (host only)

The host's top bar has a **Bots** button. Pick a class, a level (1–50), and a stance, then
**Add a bot beside me**. Bots are real players on the host: they take player slots (twelve in
all), wear the best regular gear of their level (with accessories from level 20), carry 50
health and 50 mana potions, and play through the server's own rules, so PvP zones, skulls,
death penalties, and loot drops all apply. Their nameplates read "Bot Warrior 40" and so on.
They fight like the fight simulator's careful player: their strongest ready attack spell
while above 30% health, healing spells below 55%, a health potion below 35%, and a mana potion
below 25% mana; ranged bots step back from anything beside them.

| Stance | Behaviour |
| --- | --- |
| Hunter | Hunts monsters (up to 3 levels above it) within 10 tiles of where you placed it, and fights back when a player attacks it |
| PvP | Also attacks any player (bots too) within 7 tiles while both stand in a PvP zone: take one to Blackreed Isle to duel it |
| Training dummy | Stands still and never fights back: test damage, spells, and skulls |

A **LimboAI behavior tree** (`game/data/bot_behavior.tres`) makes each bot's decisions: dummies
idle; everyone else uses spells and potions, then fights a target (picked from attackers, PvP
victims, monsters after it, or prey near its post) or walks back to its post. Open the tree in
the Godot editor's LimboAI tab to change how bots play; `make bot-tree` restores the default.

A bot that dies comes back 6 seconds later where you placed it, with its level, gear, and
potions restored, so a test can go on (what it dropped stays on the ground for you to loot).
The panel lists each bot's stance, place, health, skull, and whether it is fighting, with
**Remove** and **Remove all**. Bots are never saved and leave with the host; clients cannot
create them.

## Talking to people

There is no typed dialogue: right-click a person to open their menu and pick an option.
Ferrymen and waystones offer **Travel**, vendors **Trade**, bankers **Bank**, and quest givers
(gold names) **Quests**. Stand within 2 tiles; a dialog closes when you walk away.

## Vendors, potions, and the bank

Every town has a vendor (green on the maps) in a furnished shop. There is only **one bank**:
Banker Orrin in **Reedmere** (pale blue on the maps), the lakeside hub with a waystone
and the ferry to Blackreed Isle. Plan trips to deposit gold and store gear there. A hanging
sign beside each door shows what is inside: a flask and a sword for the shop, a coin stack for
the bank. Step inside to deal with them; you cannot trade or bank through
a wall. Town buildings have roofs that hide whoever is inside; the roof of the building you
stand in fades away while you are there.

**Vendors** sell health and mana potions (20 gold each, in ones or tens) and levelling gear:
the helmet, armor, weapon, and off-hand of tiers 1, 5, and 10, filtered to your class, and
torches for dark caves.
Gear costs about 40 × level^1.05 gold (weapons a quarter more): 40–50 gold at tier 1,
215–270 at tier 5, and 450–560 at tier 10. Better gear comes from monsters and quests. Vendors
buy monster materials for their value (one stack, or **Sell all materials**) and unbound gear
for a quarter of its price; they never buy potions, relics, or packs.

**Potions** stack like materials. A health potion restores 20% of your maximum health, a mana
potion 25% of your maximum mana. Each kind has its own cooldown: 6 seconds for health
potions and 3 seconds for mana potions, so you can drink one of each together but cannot chain
health potions to outlast a fight. The backpack slot shades while a potion cools down, and
potions are refused at full health or mana.
Right-click one in the backpack, or press Q (health) or E (mana) to drink the first one.

**The banker** keeps your gold and an item depot. Deposit
or withdraw any amount; banked gold and depot items are never lost on death. The depot has
24 slots: drag items between it and your backpack, or right-click (backpack items go into the
depot while the bank dialog is open, depot items come back). Stacks merge as usual. Items
reach the depot only through the backpack, never straight from equipment or the ground.
Like the rest of your character, the bank and depot are saved on the host (see
[Saved characters](../README.md#saved-characters)).

## Town tasks and packs

Three quest givers hand out hunting tasks: **Warden Brask** in Cinder Crossing (15 thornback
boars, levels 5–7), **Captain Ardo** in Ashford (25 outlaw archers, levels 19–23), and
**Marshal Venn** in Emberfall (30 hollow knights, levels 33–35). Accept a task, then every
kill of that monster that earns you experience (your own or your party's shared kills) counts;
progress shows in the message line and in the quest dialog. Turn it in to the giver.

**Quest hubs** fill the levels between: one giver in the town nearest each band of overworld
monsters, paying experience and gold.

| Giver | Town | Tasks | Monster levels |
| --- | --- | --- | --- |
| Harbourmaster Ilse | Cinder Landing | 20 road bandits; 20 grey wolves | 8–10; 11–14 |
| Fenwarden Ostrel | Reedmere | 25 bog lurkers | 15–18 |
| Quartermaster Rhosyn | Dunmere | 25 stone golems; 25 cinder wraiths | 24–28; 29–32 |
| Huntmaster Corvel | Emberfall | 25 mire stalkers; 25 fen beasts (reedfangs, bog hulks) | 36–44; 40–48 |

**Where to go next:** a gold **!** over a quest giver means they have a task that suits your
level (or, over a trainer, that you may choose a class); a **?** means you can turn
something in (or bring a relic keeper a trophy). The same marks appear on the world map. The
quest list always ends with **Next**: the open task that fits your level best (monsters up
to 2 levels above you and not more than 5 below), with its giver, town, and monster levels;
and when you turn in a giver's last task that suits you, they name the next giver to visit.
Every level from 1 to 50 has a task that fits.

**The Lexicon** (K, or the magnifier in the micro menu) lists every monster from the lowest
level up, coloured by rank: where it lives (regions, zones, and dungeons), its levels, the
tasks it counts toward, and its drop table: each material and hunting weapon with its chance
and what a vendor pays, the gold it usually drops, its chance of tier gear, and a final
boss's relics. Search by monster, place, or item: "silk" finds the spiders, "Greywood" the
monsters that live there. Hover a drop for its tooltip.

**Dungeon tasks** are given by the stairway down into each dungeon: **Cellarmaster Pell** in
Cinder Crossing (25 cellar rats, then the Rat King), **Sexton Wren** inside Ashford's crypt
house (30 risen dead, then Abbot Morrow), and **Foreman Dagny** inside Highmoor's mine house
(30 mine creatures, then the Forgemaw); **Trapper Maud** waits at Silkhollow's cave mouth in
Thornfield Wilds (25 Silkhollow spiders, then the Silk Matron). Any of the dungeon's regular monsters count toward its
hunt, and your party's shared kills count too. They pay experience and gold instead of a pack:
half of what the kills themselves gave for a hunt, and as much again as the boss gave for a
boss task (shown in the quest dialog). A giver lists all their tasks; each is done once.

The **quest list** in the top-left of the game window shows every task you are on: its giver
and town, and your progress, or "Done: return to ..." once you can turn it in. Press L
(rebindable) to hide or show it.

Each finished town task gives you the next **pack**, worn in the bag slot (top right of the
paperdoll): a Traveler's pack (12 backpack slots), then an Explorer's pack (16), then a
Pathfinder's pack (20), whichever task you finish first. Packs are bound: they never come off,
drop, or get lost on death. Backpack slots beyond your pack are shown dark and locked.

## The world, towns, and travel

The overworld is divided into named **regions**, each with its own monsters: the Cinder
Meadows (levels 1–5) around the starting town, the Greywood, the Westwind Coast, Lurkmoor,
Outlaw Ridge, the Thornfield Wilds, the Golemback Hills, Stillwater Shore, Stonevale, the
Smoulder Fells, the Sunscar Dunes (the desert), the Hollow March, Lastlight Downs, the
Emberwaste, the Mirewood Fen, and the Gloamwood (levels 34–45). The line under the minimap
shows where you are and the monster levels there, coloured white, yellow, or red by how they
compare to your level (hover it for a description); crossing into a new region is announced.
The world map (M) opens zoomed in on you; scroll (or + and −) to zoom around the cursor down
to the whole map, drag to move it, and close it with M, Esc, or Close. It labels every region with its levels. A region's levels come from the
monsters placed in it, so they stay correct when spawns move.

The sky follows a 40-minute day and night and changing weather: clear, overcast, rain, and
thunderstorms with lightning, the same for everyone in the session. Weather is only for looks.
It never rains underground or in the desert. At dusk the torches on the town walls are lit.

The overworld is 384×384 tiles: walking straight across takes about a minute and three
quarters. Monster camps are dense (about 600 monsters), so levelling is close to town.
**Cinder Crossing**, the starting town, sits in the north-west corner with gates to the east
and south. A sea runs down the whole western edge with two ports: **Cinder Landing** at the
top and **Lastlight** at the bottom, joined by one ferry. In the middle of the world lies a
great irregular lake with **Blackreed Isle** in it, a **level 40–50 PvP hunting ground** of open meadows and scattered trees
reached only by the ferry from **Reedmere** on the west shore; entering it shows a red
banner, and the island is tinted red on the minimap and world map.

Towns ring the lake: **Ashford** to the north, **Reedmere** to the west, **Emberfall** to the
east, and **Dunmere** to the south, with **Highmoor** as an outpost among the north-eastern
rock ridges. Every town (Cinder Crossing and the ports too) is a **safe zone**: no PvP, and
monsters never cross into it; a green banner shows when you enter. A desert spreads across
the south-west, and the Hollow Reach waits in the far south-east, well away from the towns.

**Waystones** are the fast travel over land: carved standing stones with a glowing rune, one in
each inland town and one just outside Cinder Crossing's east gate. Every waystone links to the
others; ferrymen on the piers sail along the coast and to the island. Stand within 2 tiles of a
waystone or ferryman, right-click it, choose **Travel**, and pick a destination; the host checks
your distance, the route, that you are standing still, a 1-second travel cooldown, and your
gold, then deducts the fare and lands you next to the destination's waystone or ferryman. A
crowded stop refuses travellers.

Everyone starts with 100 gold. Gold coin piles lie around the wilds; picking one up adds 25
gold per coin pile in the stack to your purse without using a backpack slot. Waystone fares are about 5 gold per 60
tiles (Cinder Crossing to Reedmere is about 45), the coastal ferry from top to bottom costs
65, and the island crossing 40 each way. Monsters grow from level 1-4 around Cinder
Crossing to level 45 in the far east and south.

## Instanced dungeons

Some town buildings hold stairs down (orange on the world map), and one rock-ringed stairway
lies in the wilds. Step on them to enter a
private copy of that dungeon for you and your party; the party leader's copy is shared by
everyone in the party. Stairs up lead back beside the town stairway. A copy runs its monsters
only while players are inside, and resets 60 seconds after the last player leaves: monsters
come back and items left on its floor are gone. If every copy is in use, the stairway says so
and leaves you in town.

| Dungeon | Entrance | Levels | Monsters | Champion |
| --- | --- | --- | --- | --- |
| Cinder cellar | Cinder Crossing, north-east house | 3–9 | sewer rats, giant rats | The Rat King |
| Ashford crypt | Ashford, south-west house | 19–25 | crypt skeletons, grave ghouls | Abbot Morrow |
| Highmoor deep mine | Highmoor, north-east house | 33–40 | cave crawlers, ember golems | Forgemaw |
| Silkhollow | Thornfield Wilds, a cave mouth west of the lake | 15–20 | cave spiders, venom weavers (spit from 3 tiles) | The Silk Matron |

**Silkhollow is pitch dark**: your lantern lights only an arm's length, so you will not see a
spider until it bites. Hold a **Torch** (15 gold at any vendor, any class, no stats) in your
off hand for a wide, flickering light that everyone nearby sees by. That means going without
your shield or spellbook: the spiders come singly or in pairs (weavers alone), so the camps
stay fair without one (`make fight-sim MONSTER=cave_spider OFF_HAND=torch`). Entering without
a torch tells you so. A torch also lights the night outside.

Champions have ten times a normal monster's health, hit 1.8 times as hard, give 25 times the
experience, and always drop gear of their tier plus a valuable trophy material. Dungeon copies
are separate spaces: players and monsters in a copy cannot fight anyone outside it, even if
the copy is close to the overworld on the host's map.

## Inventory

The right-hand panel shows a Tibia-style paperdoll with ten slots (necklace, helmet, pack /
main hand, armor, off hand / ring, cape, ring / charm), a backpack of 8 slots (up to 20 with
a pack from a town task), and your stat sheet. Adventurers start with an Ember cap, Moss
coat, Copper blade, and Oak buckler in the backpack. Choosing a class adds its tier-1 kit
if you lack it: a Dented iron helm and Rusted breastplate (Warrior), a Ringmail coif,
Ringmail shirt, and Willow shortbow (Hunter), a Linen hat, Linen robe, Kindling wand, and
Tattered primer (Sorcerer), or a Sapling rod and Tattered primer (Druid, who keeps the
leather Ember cap and Moss coat). Tier-5 gear for every class lies around Cinder Crossing. Rings
fit either ring slot; right-clicking a ring fills an empty ring slot first. Helmets, capes,
armor, and both hands are drawn on the character (a cape appears only when equipped);
rings, amulets, and charms are too small to show. Items can be dropped on any walkable
tile, stacking up to six per tile, and the top item is picked up. Ground tiles must be
your own tile or one of the eight around you.

Peer 1 validates every item move: location shape, reach, slot type, level and class,
free space, stack limit, and a 150 ms item cooldown. Dragging onto an occupied slot swaps
items when both fit; a worn item displaced from the ground goes back to that tile.
Equipped items are visible to everyone; backpack contents are sent only to their
owner. Late joiners receive ground items in the snapshot. Items carried by a
player who leaves disappear with them. Ground stacks left untouched for 15 minutes decay
(any change to a stack restarts its timer); the map's starting items and bound relics never
decay, and nothing on the ground survives a host restart.
The backpack is flat: there are no nested containers or player trading.

**Stacking.** Items without an equipment slot (monster materials, glowcaps, potions, gold piles)
stack up to 100 in one backpack slot or ground entry; the count shows in the corner of the
slot or tile and in the tooltip. Picking one up merges it into a matching backpack stack
with room, or uses a free slot. Dragging onto a matching stack merges; dropping on the
ground merges with a matching top entry (even on a tile already holding six entries). A
stack always moves whole; there is no splitting yet. Loot and death drops merge the same
way, and a dead player's purse becomes one gold stack. Equipment never stacks.

Hover an item for its tooltip: wearable gear shows its rarity, from **Common** (tiers 1 and 5)
through **Uncommon** (10, 15), **Rare** (20, 25), and **Epic** (30, 35) to **Legendary** (40, 45),
with relics as **Relic**. The name and the tooltip's frame take the rarity's colour. Gear you
cannot use yet is tinted red in its slot.

## Gear tiers

Equipment comes in ten tiers, every five levels (1, 5, 10 … 45), each in its own material
and colour: copper, iron, bronze, steel, silverleaf, cobalt, embersteel, duskiron,
starforged, and wyrmglass. Every tier has a helmet and armor in four **armor types**, one per
class: **Plate** for Warriors, **Mail** for Hunters, **Leather** for Druids, and **Cloth** for
Sorcerers. A class wears only its own type (Adventurers may wear any tier-1 piece); the
types share stats per tier and differ in looks. From tier 35 each line takes its class's
theme, ending at tier 45 in a brute's horned helm and spiked plate (Warrior), a great bear's
hood and fur hauberk (Hunter), an elder stag's antlered crown and hide (Druid), and an
infernal warlock's cowl and burning robe (Sorcerer). There is also a weapon per
class (Warriors: swords, axes, and maces; Hunters: bows and crossbows; Sorcerers: wands;
Druids: rods), and an off-hand (shields for Warriors and Hunters, spellbooks for Sorcerers
and Druids). **Amulets, capes, charms, and rings start at tier 20.** An item needs its tier
level and, for weapons, off-hands, helmets, and armor, your class: the server refuses to equip it
otherwise, and worn items you no longer qualify for (after losing levels) give no stats.
Tooltips show the tier, level, and who can use an item; a coloured bar under each slot
shows its tier, red when you cannot use it yet. Stats come from the balance curves
(`game/data/items.gd`); the full table is in [balance.md](balance.md#gear-tiers).

## The Hollow Reach

The endgame zone fills the south-east corner (tiles 700-757 x 690-753): a **high-risk level 45-50
PvP zone**
of blighted violet soil and dead trees inside an obsidian wall, entered on foot through a
single gate in its west wall (a clearing in the forest leads to it). An obsidian road runs
east past void wraiths, obsidian golems (elite), and hollow knights to the **Hollow
Sanctum**: an antechamber of pillars, a narrow gallery, and at the very end the throne room
where **Vaelith, Sovereign of the Hollow** sits. Void wraiths glow faintly; Vaelith wears
his own glowing relics. Obsidian walls block movement and sight like stone walls.

**Dying in the Hollow Reach drops everything**: your backpack, your gold, and every worn
item (as with a red skull), not the usual 10% chance per worn item. Only bound relics stay
with you. The banner warns you as you enter. Beginner protection (below level 8) still
applies. Zones get this rule with the `full_loot` flag on their marker.

## Final bosses and relics

Three level-50 final bosses each guard a lair: **Morvain the Drowned** at the far end of
Blackreed Isle, **Kharzul the Cinder Colossus** in the far east, and **Sylvaine the Hollow
Bloom** in the south-eastern forest, west of the Hollow Reach. The ultimate boss, **Vaelith**, waits in the Hollow
Sanctum's throne room and respawns after an hour. Each boss has the 350,000 health of the
raid boss (so it takes a ten-player group), drops gold, and respawns 30 minutes after it
dies.

Bosses fight like raid bosses. When one engages, everyone within 20 tiles is warned that it
**enrages after 255 seconds**: from then on it hits ten times as hard, so the raid needs its
damage. Every 4 seconds it **pulses** dark energy at every player within 8 tiles, ignoring
defense; across a ten-player raid that adds up to about 2.2 Druids' healing per second.
Each of its hits **wounds** its target, so every next hit on that player lands 25% harder
until 12 seconds pass without one: two Warriors must take turns, the second pulling the boss
with **Challenge** (Warrior spell from level 20: monsters within 2 tiles turn on the caster).
If the raid leaves, the boss walks home, heals, and forgets the fight. Its nameplate shows
ENRAGED once it enrages.

Glowing **relics** are quest rewards. Everyone who took part in the fight earns one
**trophy** for that boss when it dies: players who damaged it, players it hit, and players
who healed any of them. Standing nearby, or casting at full health, earns nothing. Each final boss has its own **relic keeper** on Reedmere's north plaza, the town in the middle
of the world (gold names): **Ysolde** keeps Morvain's relics, **Brannoc the Forgemaster**
Kharzul's, **Liraen of the Thorn** Sylvaine's, and **Oswin the Ashen** Vaelith's. Right-click
the keeper, choose **Quests**, and trade a trophy for any one of that boss's relics: Morvain gives
Warrior and shared armor, Kharzul a Hunter bow, Sorcerer wand, amulet, and charm, and
Sylvaine a Druid rod, spellbook, cape, and ring. Vaelith's trophies buy the strongest
relics: a void weapon for each class (Voidrend, Eclipse bow, Starless wand, Nightbloom
rod) or the Sovereign's mantle. Trophies stack, so kill a boss again for
another relic. Relics are level 50, beat the best tiered gear, glow in their boss's colour
with drifting sparks, and are **bound**: they cannot be dropped and are never lost on death,
even with a red skull.

## Stats and balance

Every new character starts as an **Adventurer**: no class yet, middling health and
mana, only Light heal, and the tier-1 gear of every class to try (an Adventurer with a
bow shoots from six tiles, with a wand or rod from five). Adventurers stop at level 8.
**Master Hesk**, outside Cinder Crossing's training hall in the south-east corner, gives
**The adventurer's trial**: hunt eight thornback boars in Greywood. Once you have passed it and
reached level 5, right-click a trainer in the hall and choose **Class**: Sir Garrow
(Warrior), Ranger Tamsin (Hunter), Magister Vell (Sorcerer), or Elder Fenna (Druid). Each
explains the class and its spells; **Become a ...** is permanent, restores your health
and mana, and hands you the class's tier-1 kit (helmet, armor, weapon, off-hand) that you lack. Your
spells fill the action bar at once.

The four follow the classic roles: **Warrior** (tank: most health, base defense), **Hunter**
(ranged damage, light healing), **Sorcerer** (burst damage, frail), and **Druid** (healer,
frail). The host checks every choice; clients never pick their own class. Characters
saved before trainers existed keep their class, and saves from before armor types swap
worn, carried, and stored helmets and armor for the same tier's piece of their class's type. Test hosts started with
`--allow-start-vocation` let new characters begin with `--vocation=knight` (and so on);
without it, `--vocation` is ignored. Everyone sees each player's class and level.

Each item has stats (health, mana, attack, defense, critical chance, regeneration,
healing) that add to your class's base stats for your level; the stat sheet shows the
totals and the gear bonus. Charms, rings, and necklaces give passive stats only. Stats are
computed with the same shared function on every peer from server-authoritative class,
level, and equipment.

`game/data/balance.gd` defines the level 1-50 curves, all derived from a **350,000-health
final boss** that needs a raid of **at least ten level-50 players with every class**:
an enrage timer demands damage, raid-wide pressure demands healers, and wound stacks
demand two tanks. See [`balance.md`](balance.md) for the anchors, class
profiles, raid checks, and full level table.
Combat uses these stats and curves directly.
