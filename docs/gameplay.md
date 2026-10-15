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
book (B), Professions (P), Quests (L), Lexicon (K), World map (M), Party (O), and Controls, each with a painted icon (a helm, a red tome, pick and hammer,
a sealed scroll, a bestiary, a folded map, three companions under a pennant, and a cog). A gold frame marks the panels that are
open; hover a button for its key. The **character window** explains every stat (your base
value, what your gear adds, and what the stat does, such as how much your defense cuts
damage), shows experience to the next level, and your status: gold and bank, party, skull,
unjustified kills, town rest, your meal, and relic trophies waiting at a relic keeper. Change gear on the equipment panel; targeting, pick up, gathering (F), the professions window (P), the world map, and the
health and mana potions (Q and E), the quest list (L), the spell book (B), and the character window (C) have their own keys. Click **Controls** in the top bar (beside **Leave game**, which saves and returns to the start
screen) to rebind any action: click a key button, then
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
| Warrior | Brutal blow (1), Provoke (8, turns your target monster onto you from up to 4 tiles), Whirling strike (10, around you), Challenge (20, taunt), Rending cut (20), Sundering blow (30), Earthshaker (40, 2 tiles around you) |
| Hunter | Piercing shot (1), Holy mend (8), Crippling arrow (12, halves your target's pace for 4 s), Arrow volley (15, area), Radiant arrow (30), Sunlance barrage (40, area) |
| Sorcerer | Ember bolt (1), Flame wave (10, area), Arc lightning (20), Firestorm (30, area), Starfall (45, area) |
| Druid | Frost bolt (1), Mend (1), Mass mend (1, heals you, your party, and anyone you cannot attack within 3 tiles), Entangling roots (12, roots your target in place for 3 s), Thorn lash (15), Hailstorm (30, area), Wild growth (40, a strong group heal) |

**Rune spells.** Level 40+ hunting grounds drop runes: small carved stones of fire, frost, or
lightning (behemoths and obsidian golems fire, bog hulks and mire stalkers frost, reedfangs and
void wraiths lightning; the level-50 elites more often). Any class from level 40 casts one at its
target up to 7 tiles away: drag it from your backpack onto the action bar (or right-click a
slot), and each cast uses one up. A fire rune burns every enemy within 3 tiles of the target (a
round area of 37 tiles, as in Tibia), a frost rune freezes 2 tiles around and slows what it hits,
and a lightning rune strikes the target and leaps to two more enemies nearby. Runes are magic and
hit for a geared attack of your level, whatever your class, and all runes share a 2-second
cooldown. Bots carry the runes they find and cast them at packs.

**Roots and slows.** Entangling roots holds its target in place and Crippling arrow halves its
pace; both also hit it. Bosses shrug them off, and a player who was just held cannot be held
again until 6 seconds after it ended.

**Armor and the two kinds of damage.** Warriors' and Hunters' attacks and spells, and most
monsters, hit physically; Sorcerers' and Druids', rune spells, and casting monsters (wraiths,
the lich, the Hollow Bloom) hit with magic. Defense cuts physical damage and magic defense
cuts magic. Plate gives Warriors the most defense and no magic defense, cloth gives Sorcerers
the most magic defense and the least defense; mail and leather sit between. Capes, amulets,
and spellbooks add magic defense. So a Warrior shrugs off a Hunter's arrows but not a
Sorcerer's fire ([balance](balance.md#pvp)).

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
(or you **Withdraw invitation**). Right-click a member to **Leave party**. The **party window**
(O, or the micro menu) lists your party's members with their class, level, and health, the
invitations you can join or withdraw, and **Leave party**. Right-clicking yourself opens
nothing, and loot under a person is picked up rather than opening their menu. Only
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
`value`. On top, gold coins drop as one stack: `Balance.coins_per_kill` on average, 0.2 + 0.02
per level (about 5 gold a kill at level 1, 15 at level 19, 30 at level 50; elites and bosses 3
coins more), and a piece of **tiered gear** from the monster's level tier (4% from normal
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
and anyone can pick it up, including you on a run back to your body. What drops is only what
you **found or bought**: anything **bound** to you stays, wherever you die and whatever your
skull. Bound items are quest rewards: packs, relics, the Hunters' Lodge set, and the boss
tasks' accessories (their tooltips say "bound to you").

Attacking an unmarked player gives you a **white skull** for 15 minutes (renewed while you
keep attacking). Fighting back against someone who attacked you, or attacking a skulled
player, is self-defence and gives no skull. Killing an unmarked player who did not attack
you is an **unjustified kill**; three within 24 hours give a **red skull** for 30 days, and a
red-skulled player who dies loses everything they wear as well. Skulls show next to the
name above the character and stay after death. Yellow and black skulls are not used.

On screen, creatures show a name and a health bar that turns yellow and red, damage rises
in red (critical hits in orange), healing in green, and experience in white. Ranged attacks
fly as projectiles and area spells flash their tiles. Your health and mana bars sit in the
top-left of the game window; while you have a target, the **target frame** beside them shows its
name and level (coloured by danger, like its nameplate) and its health in numbers and percent.

## Playing solo: companions, rivals, and raids

**Play solo** on the start screen opens a private world that only this computer can reach. It
saves your character like hosting does, but brings the group game to you:

- **Companions.** Three named companions join your party at once, completing a tank, healer,
  and damage group around your class (a Warrior gets a Druid, a Hunter, and a Sorcerer, and so
  on). They always match your level, wear the best regular gear of your tier, and follow you
  everywhere: across the map, through waystones and ferries, after you die, and down dungeon
  stairs into your party's copy. They fight what you target and whatever attacks the group.
  Druids heal allies below 80% health with Mass mend from level 1, moving to them; Warriors **Provoke** a monster that turns on a softer
  member from up to four tiles away and **Challenge** everything around them. A companion who falls is back beside you six seconds later with what it carried.
  Party experience is shared by the usual rules, so a full group levels as a real one does.
- **Rival bands.** Two named adventurer bands of three (*the Ashen Hand* and *the
  Thornwardens*) roam the world at about your level. Their leader takes a task from its giver,
  hunts that monster at one of its camps, turns it in, and picks another; the band walks
  where you can see it and travels far in one go where you cannot. When you enter a **PvP
  zone**, one band comes for your group there (you are warned), arriving out of sight and
  closing in, so Blackreed Isle and the Hollow Reach become group fights. Outside PvP zones
  rivals cannot attack you, as for any player; skulls, death penalties, and loot drops all
  apply to them (beat them for their potions). A band rests a few minutes between ambushes.
- **How bots level.** Bots level while you play, not only when a game starts:

  | Bot | Level |
  | --- | --- |
  | Companion | Always your level; its gear follows your tier. |
  | Rival band member | Earns experience from its kills and tasks like a player; each level gained brings that level's gear. A death costs what it costs you. Between errands, a member more than 2 levels below its place (your level plus its band's offset, 1 or 2) is lifted to that floor; one ahead of you keeps its levels. |
  | Hunter, PvP, training dummy | Test bots: they return to their starting level when they fall. |
- **Choosing companions.** The party window (O) has a class picker beside each companion:
  pick another class and that companion goes home while one of the new class joins, at your
  level. Build the group you want, two healers for a hard dungeon or three damage dealers for PvP.
- **Raids.** The party window also holds the **raid plan**: a count per class (with − and +),
  starting from the twenty-player raid the final bosses are balanced for (four Warriors, six
  Hunters, six Sorcerers, four Druids, you included), and never below the classes already in
  your party. A line under it says whether that raid beats the final boss, and how fast, or
  what it lacks. At level 50, with twenty planned, choose **Gather a raid**: your party fills
  to the plan. The raid's Warriors trade the boss when its wounds stack on the tank (three or
  more), and the Druids keep everyone up through its pulses. The rival bands step aside
  meanwhile, to stay within the twenty-four-player limit. **Disband the raid** sends the extra
  companions home; your three stay. Companions and the plan stay fixed while a raid is out.

Companions and rivals are bots (below): they play through the server's own rules and are never
saved. Their nameplates show their name and level.

## Bots

Bots come with solo play (companions and rivals, above); there is no menu to add them. The
host's `spawn_bot` (tests, the fight and duel simulators) still adds standalone bots in three
stances. Bots are real players on the host: they take player slots (twenty-four in
all), wear the best regular gear of their level (with accessories from level 20), carry 50
health and 50 mana potions, and play through the server's own rules, so PvP zones, skulls,
death penalties, and loot drops all apply. Their nameplates read "Bot Warrior 40" and so on.
They fight like the fight simulator's careful player: their strongest ready attack spell
while above 30% health, healing spells below 55%, a health potion below 35%, and a mana potion
below 25% mana; ranged bots step back from anything beside them.

| Stance | Behaviour |
| --- | --- |
| Hunter | Hunts monsters (up to 3 levels above it) within 10 tiles of where it was placed, and fights back when a player attacks it |
| PvP | Also attacks any player (bots too) within 7 tiles while both stand in a PvP zone: take one to Blackreed Isle to duel it |
| Training dummy | Stands still and never fights back: test damage, spells, and skulls |

A **LimboAI behavior tree** (`game/data/bot_behavior.tres`) makes each bot's decisions: dummies
idle; everyone else uses spells and potions (in a party: heals for hurt allies, Provoke and Challenge for the
group), then fights a target (its leader's, attackers of its group, PvP victims, monsters after
it, or prey near its post), collects loot, sells it, follows its leader (companions and rival
band members), runs its errand (rival band leaders: tasks, camps, ambushes), or walks back to its
post.

**Bots and loot** (`game/core/bot_loot.gd`). When a monster dies, the tiles its loot spills onto
are claimed for three minutes by the players credited with the kill. Hunters, PvP bots, and
rivals pick up the claimed stacks within 5 tiles that their own bot group earned (gold into the
purse, the rest into the backpack), so a place where bots hunted is not a free loot pile. Loot a
human player helped earn is left for them, so companions never take yours; anyone may still pick
up anything, as before. Loot that does not fit a bot's backpack stays on the ground, and a stack a
bot cannot reach (across water or rock) is given up after 8 seconds. Once anyone in a bot group
has at most one free backpack slot and something to sell, the roaming bot (a hunter, PvP bot, or
rival band leader) travels to the nearest vendor, sells everything vendors buy (never potions or
bound items), and goes back to its post or errand; band members follow their leader into the
shop and sell there. Rivals carry what they collected, so beating them drops it. Long trips use
`game/core/nav.gd`, an A* grid over the walkable overworld. Open the tree in
the Godot editor's LimboAI tab to change how bots play; `make bot-tree` restores the default.

A standalone bot that dies comes back 6 seconds later where it was placed, with its level, gear,
and potions restored, so a test can go on (what it dropped stays on the ground). Bots are never
saved and leave with the host; clients cannot create them.

## Talking to people

There is no typed dialogue: right-click a person to open their menu and pick an option.
Ferrymen and waystones offer **Travel**, vendors **Trade**, bankers **Bank**, and quest givers
(gold names) **Quests**. Stand within 2 tiles; a dialog closes when you walk away.

## Vendors, potions, and the bank

Every house nobody keeps is a home with a bed, a chest, a table and chair, and in bigger rooms
plants, shelves, and a barrel (they block like any furniture). Each town's main square has a
well with benches and market stalls, and lamp posts line the streets, lit at night. Every town has a vendor (green on the maps) in a furnished shop, and an artisan (amber) in a
workshop for crafting (see [Professions](#professions-gathering-and-crafting)). There is only **one bank**:
Banker Orrin in **Reedmere** (pale blue on the maps), the lakeside hub with a waystone
and the ferry to Blackreed Isle. Plan trips to deposit gold and store gear there. Reedmere is the
castle town: a castle wall with gates to the west, north, and south and the harbour to the east,
an open quarter of streets and a square in its west half, and stone houses under slate roofs. A hanging
sign beside each door shows what is inside: a flask and a sword for the shop, a coin stack for
the bank. Step inside to deal with them; you cannot trade or bank through
a wall. Town buildings have roofs that hide whoever is inside, and every doorway has a
wooden door in its wall so you can see where to go in. Walk within 3 tiles of a building and its
roof turns see-through, showing the rooms and who is inside; the roof of the building you stand
in fades away completely.

**Vendors** sell health and mana potions (20 gold each, in ones or tens) and levelling gear:
the helmet, armor, weapon, and off-hand of tiers 1, 5, and 10, filtered to your class, and
torches for dark caves, and the Leather satchel (see [Bags](#inventory)).
Gear costs about 40 × level^1.05 gold (weapons a quarter more): 40–50 gold at tier 1,
215–270 at tier 5, and 450–560 at tier 10. Better gear comes from monsters and quests. Vendors
buy monster materials for their value (one stack, or **Sell all materials**) and unbound gear
for a quarter of its price; they never buy potions, relics, or packs.

**Potions** stack like materials. A health potion restores 20% of your maximum health, a mana
potion 25% of your maximum mana; alchemists brew stronger ones. Each kind has its own cooldown: 6 seconds for health
potions and 3 seconds for mana potions, so you can drink one of each together but cannot chain
health potions to outlast a fight. The backpack slot shades while a potion cools down, and
potions are refused at full health or mana.
Right-click one in the backpack, or press Q (health) or E (mana) to drink your strongest one.

**The banker** keeps your gold and an item depot. Deposit
or withdraw any amount; banked gold and depot items are never lost on death. The depot has
24 slots: drag items between it and your backpack, or right-click (backpack items go into the
depot while the bank dialog is open, depot items come back). Stacks merge as usual. Items
reach the depot only through the backpack, never straight from equipment or the ground.
Like the rest of your character, the bank and depot are saved on the host (see
[Saved characters](../README.md#saved-characters)).

## Professions: gathering and crafting

When you would rather not fight, gather and craft. Every character can learn all nine
**professions**; each skill starts at 1 and rises to 50 by doing it. Press **P** (or the hammer
button by the action bar) for the Professions window: each skill's level, progress, what it
gathers or crafts now, and what opens next.

**Gathering.** Stand next to a node and press **F** (it picks the nearest one, the tile you face
first), or right-click it. Work takes 3 seconds; moving cancels it, and a bar under your
character shows the progress. A gather yields 1-5 resources (about 2 on average, closer to 3
once your skill is 20 levels past the land's band); what does not fit stays behind. The node
then regrows for a minute. One tree, rock, patch, or shore cell in ten rests and cannot be
worked (`Professions.resting`), so nodes are a little scarcer than the land suggests.

| Skill | Node | Resources by land level (1+, 10+, 20+, 30+, 40+) |
| --- | --- | --- |
| Mining | ore veins: glittering nuggets in the cliff faces of mountains and outcrops (most rock is just rock) | Copper, Iron, Silver, Cobalt, Starmetal ore |
| Woodcutting | trees (and the Hollow Reach's dead trees) | Pine, Oak, Yew, Ironbark, Elderwood log |
| Herbalism | flowering herb patches in the wilds | Sunflax, Mirereed, Silverthistle, Nightcotton, Starpetal |
| Fishing | water up to 3 tiles away | River perch, Marsh eel, Silver trout, Deep pike, Glimmerfin |

The **land's level** (the middle of its region's or zone's monster levels, as on the location
line) decides the resource, and a skill must reach that level to gather it: Mining 20 for
silver ore in a level-20+ region. A gather teaches 4 skill experience at the land's level, 1
less every 5 skill levels above it, so move on to harder land as you improve. A level takes
4 + level experience. Nodes exist only outside dungeons; herb patches never grow in towns.
Vendors buy resources for 2, 4, 7, 10, or 14 gold by band.

**Crafting.** Every town has an **artisan** in a workshop (an anvil, workbench, cauldron, and
loom; amber on the maps). Right-click them and choose **Craft**: pick a profession tab and, for
gear, a tier, then craft any recipe your skill allows from the resources in your backpack
(×5 crafts potions and food in a batch). Crafting teaches up to 4 experience times half the
resources a recipe uses, less for recipes well below your skill.

- **Smithing** (ore with logs): plate and mail armor, Warrior weapons, shields, amulets, rings.
- **Woodworking** (logs with ore): bows, wands, rods, charms.
- **Tailoring** (herbs with ore): leather and cloth armor, spellbooks, capes, and bags (6 to 14 slots).
- **Alchemy** (herbs): health and mana potions, and from skill 20 and 40 strong and great
  potions (30% and 40% health, 35% and 45% mana) that vendors never sell.
- **Cooking** (fish and herbs): food. Eating (right-click it) speeds health and mana
  regeneration by 20%, 35%, 50%, 70%, or 100% for 15 minutes; a new meal replaces the last.
  The character window shows your meal.

Gear recipes exist for every regular tier piece (helmet, armor, legs, boots, weapon, off-hand,
and accessories): skill = the tier's level, and the band's resources (more for higher bands).
Crafted gear is the same item a vendor sells or a monster drops, so it never beats drops:
mythic gear, relics, and named hunting weapons are never crafted. Potions sharing a kind
share its cooldown, and Q/E drink your strongest health or mana potion first.

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
| Harbourmaster Ilse | Cinder Crossing (harbour) | 20 road bandits; 20 grey wolves | 8–10; 11–14 |
| Fenwarden Ostrel | Reedmere | 25 bog lurkers | 15–18 |
| Quartermaster Rhosyn | Dunmere | 25 stone golems; 25 cinder wraiths | 24–28; 29–32 |
| Ranger Aldric | Reedmere (west square) | 25 dire bears; 25 lizard warriors; 20 lizard shamans | 20–22; 21–24; 23–25 |
| Skywatch Mera | Lastlight | 25 harpies; 25 wraith knights | 24–27; 31–34 |
| Caravan master Idris | Dunmere | 25 stone trolls; 25 dune scorpions; 25 sand raiders | 25–28; 26–30; 28–32 |
| Huntmaster Corvel | Emberfall | 25 mire stalkers; 25 fen beasts (reedfangs, bog hulks); 20 marsh witches; 25 cave trolls | 36–44; 40–48; 33–36; 38–42 |

**The Hunters' Lodge.** **Lodgemaster Varga** on Reedmere's plaza runs a chain of six hunting
contracts, one at a time: each opens once the one before it is turned in, against harder prey in
a new region. The prey are also the best farms for their level: twice the usual chance of tier
gear, health and mana potions, and **rune shards**. Each contract pays experience and gold,
potions and shards, and one piece of the hunt's tier made for your class (your own armor type,
weapon, or off-hand); turning in needs a free backpack slot for every item. The pieces are the
**Lodge set**, made only for the Lodge (Lodgewarden for Warriors, Lodgeranger for Hunters,
Lodgestalker for Druids, Lodgeseer for Sorcerers), 5% stronger than the vendor piece of their
tier and **bound**: they are never dropped on death, sold, or traded.

| Contract | Prey | Where | Levels | Also pays |
| --- | --- | --- | --- | --- |
| The grey pack | 20 grey wolves | Greywood | 11–14 | 5+5 potions, boots |
| Frostfangs | 25 frostfang wolves (white, ice-eyed) | Outlaw Ridge | 19–21 | 8+8 potions, 1 shard, legs |
| Greymaw the Dire | the black dire wolf (champion, 10 min respawn) | Golemback Hills | 24 | 2 shards, weapon |
| The one-eyed | 25 cyclopes (with clubs) | Smoulder Fells | 29–31 | 10+10 potions, 1 shard, helmet |
| Cyclops forges | 25 cyclops smiths (hammers, aprons) | Hollow March | 36–38 | 10+10 potions, 2 shards, armor |
| Behemoth country | 20 behemoths (horned, tusked) | Gloamwood | 43–45 | 15+15 potions, 3 shards, off-hand |

**Spell ranks.** Right-click your class trainer in Cinder Crossing's training hall and choose
**Runes**: they carve rune shards into a spell you know, one rank at a time (rank 2 costs 3
shards, rank 3 costs 6 more). Each rank makes the spell 15% stronger (damage or healing);
Challenge and Provoke have no strength to raise. Ranks are saved with your character and show in the spell
book and tooltips ("Ember bolt · rank 3"). Shards drop from the Lodge prey (1.5–4%), Greymaw
(50%), and as contract rewards: the whole chain pays 9, enough to take one spell to rank 3.

**Where to go next:** a gold **!** over a quest giver means they have a task that suits your
level (or, over a trainer, that you may choose a class); a **?** means you can turn
something in (or bring a relic keeper a trophy). The same marks appear on the world map. The
quest list always ends with **Next**: the open task that fits your level best (monsters up
to 2 levels above you and not more than 5 below), with its giver, town, and monster levels;
and when you turn in a giver's last task that suits you, they name the next giver to visit.
Every level from 1 to 50 has a task that fits.

**The Lexicon** (K, or the green bestiary in the micro menu) lists every monster from the lowest
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
Three boss tasks also pay a bound accessory: **Matron's silk cape** (the Silk Matron, level 20),
**Abbot's prayer beads** (Abbot Morrow, level 25), and the **Forgeheart ring** (the Forgemaw,
level 35).

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
Emberwaste, the Mirewood Fen, and the Gloamwood (levels 34–45, with level-50 elite camps in the
Hollow March and the last three). The line under the minimap
shows where you are and the monster levels there, coloured white, yellow, or red by how they
compare to your level (hover it for a description); crossing into a new region is announced.
The world map (M) opens zoomed in on you; scroll (or + and −) to zoom around the cursor down
to the whole map, drag to move it, and close it with M, Esc, or Close. It labels every region with its levels. A region's levels come from the
monsters placed in it, so they stay correct when spawns move. The map is painted: sea and
shallows, forests, ridges, desert, and towns with their roofs. You are a gold arrow pointing the
way you face, on the world map and the minimap. **Gold rings mark where your tasks send you**:
the camps of a hunting task's monster in its level band, a dungeon task's stairway, or the giver
once a task is done. When none of your first task's places is on the minimap, an arrow at the
minimap's edge points toward the nearest.

The sky follows a 40-minute day and night and changing weather: clear, overcast, rain, and
thunderstorms with lightning, the same for everyone in the session. Weather is only for looks.
It never rains underground or in the desert, and over Mirewood Fen low cloud and drizzle hang
whatever the sky does elsewhere. At dusk the lamp posts along the town streets are lit.

The overworld is 384×384 tiles: walking straight across takes about a minute and three
quarters. Monster camps are dense (about 1,000 monsters, in packs of three or more), so levelling is close to town.
**Cinder Crossing**, the starting town, is a castle town: a battlemented curtain wall with towers
runs round it from the keep (the training hall in the north-west corner, its walls castle stone
with a tower at each corner) to the harbour, with gatehouses where the roads leave to the north,
east, and south. A sea
runs down the whole western edge with two ports: Cinder Crossing's harbour at the top and
**Lastlight** at the bottom, joined by one ferry. Two-tile cobbled roads join the walled towns
across woods, meadows, rocky mountains, and outcrops; **Reedmere**, the capital, is a walled
castle town. In the middle of the world lies a
great irregular lake with **Blackreed Isle** in it, a **level 40–50 PvP hunting ground** of open meadows and scattered trees
reached only by the ferry from **Reedmere** on the west shore; entering it shows a red
banner, and the island is tinted red on the minimap and world map.

Towns ring the lake: **Ashford** to the north, **Reedmere** to the west, **Emberfall** to the
east, and **Dunmere** to the south, with **Highmoor** as an outpost among the north-eastern
rock ridges. Every town (Cinder Crossing and the ports too) is a **safe zone**: no PvP, and
monsters never cross into it; a green banner shows when you enter. A desert spreads across
the south-west, Mirewood Fen (levels 30-50) is a swamp of bog mud, giant mushrooms, and murky
pools crossed by plank walkways, and the Hollow Reach waits in the far south-east, well away from the towns.

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

The caves are twice the size they were and twice as full: winding tunnels between chambers of
rough mountain rock, the champion in the farthest one. The Cinder cellar is a proper cellar of
red-brown brick with barrels and crates against its walls, and the cellar and the crypt hold
half again as many monsters.

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
| Silkhollow | Thornfield Wilds, a cave mouth west of the lake at the end of a dirt trail from the coast road | 15–20 | cave spiders, venom weavers (spit from 3 tiles) | The Silk Matron |

**Silkhollow is pitch dark**: you carry no light of your own, so you will not see a
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

The right-hand panel shows a Tibia-style paperdoll with twelve slots (necklace, helmet, pack /
main hand, armor, off hand / ring, legs, ring / cape, boots, charm), a backpack of 8 slots
(up to 20 with a pack from a town task), and your stat sheet. Adventurers start with an Ember
cap, Moss coat, Moss breeches, Moss boots, Copper blade, and Oak buckler in the backpack.
Choosing a class hands you its tier-1 kit (helmet, armor, legs, boots, weapon, and off-hand of
its armor type) that you lack: the trainer takes back each starter piece the class cannot use,
worn or carried, and puts the class's piece for that slot in its place, so only the remaining
gifts need free backpack slots. Druids keep the leather starter pieces. Tier-5 gear for every class lies around Cinder Crossing. Rings
fit either ring slot; right-clicking a ring fills an empty ring slot first. Helmets, capes,
armor, and both hands are drawn on the character (a cape appears only when equipped);
legs and boots too; rings, amulets, and charms are too small to show. Items can be dropped on any walkable
tile, stacking up to six per tile, and the top item is picked up. Ground tiles must be
your own tile or one of the eight around you.

**Bags.** Beside the paperdoll are three **bag slots**. Drag a bag into one (or right-click
the bag in your backpack) and click the slot to open the bag in its own window at the right of
the game window; click again (or ×, or Esc) to close it. Each bag adds its slots to what you
carry, so potions, food, materials, and spare gear can each have their own bag. Drag items
between the backpack and bag windows, or drop an item on a bag slot to put it in that bag.
Everything that uses your backpack uses your bags too: loot and purchases fill the backpack
first and then the bags, crafting and turning in tasks count what bags hold, potions and food
are drunk or eaten straight from a bag, and vendors buy from them. A worn bag comes off only
when it is empty; a bag lying in your backpack or another bag is just an item. Bags stay worn
on death, but what they hold is carried like the backpack and follows its death rules.

| Bag | Slots | Source |
| --- | ---: | --- |
| Leather satchel | 6 | vendors (120 gold), or Tailoring 1 |
| Reedweave bag | 8 | Tailoring 10 |
| Silkthistle pack | 10 | Tailoring 20 |
| Nightcotton haversack | 12 | Tailoring 30 |
| Starweave rucksack | 14 | Tailoring 40 |

Peer 1 validates every item move: location shape, reach, slot type, level and class,
free space, stack limit, and a 150 ms item cooldown. Dragging onto an occupied slot swaps
items when both fit; a worn item displaced from the ground goes back to that tile.
Equipped items are visible to everyone; backpack contents are sent only to their
owner. Late joiners receive ground items in the snapshot. Items carried by a
player who leaves disappear with them. Ground stacks left untouched for 15 minutes decay
(any change to a stack restarts its timer); the map's starting items and bound relics never
decay, and nothing on the ground survives a host restart.
Only bags in the three bag slots hold items (a bag inside a bag is just an item), and there is
no player trading.

**Stacking.** Items without an equipment slot (monster materials, glowcaps, potions, gold piles)
stack up to 100 in one backpack slot or ground entry; the count shows in the corner of the
slot or tile and in the tooltip. Picking one up merges it into a matching backpack stack
with room, or uses a free slot. Dragging onto a matching stack merges; dropping on the
ground merges with a matching top entry (even on a tile already holding six entries). A
stack always moves whole; there is no splitting yet. Loot and death drops merge the same
way, and a dead player's purse becomes one gold stack. Equipment never stacks.

Hover an item for its tooltip: wearable gear shows its rarity, from **Common** (tiers 1 and 5)
through **Uncommon** (10, 15), **Rare** (20, 25), and **Epic** (30, 35) to **Legendary** (40, 45)
and **Mythic** (level-50 monster sets), with relics as **Relic**. The name and the tooltip's frame take the rarity's colour. Gear you
cannot use yet is tinted red in its slot.

## Gear tiers

Equipment comes in ten tiers, every five levels (1, 5, 10 … 45), each in its own material
and colour: copper, iron, bronze, steel, silverleaf, cobalt, embersteel, duskiron,
starforged, and wyrmglass. Every tier has a helmet, armor, legs, and boots in four **armor types**, one per
class: **Plate** for Warriors, **Mail** for Hunters, **Leather** for Druids, and **Cloth** for
Sorcerers. A class wears only its own type (Adventurers may wear any tier-1 piece); the
types share stats per tier and differ in looks. Low tiers follow each class's
basic look: Warriors go from iron to gilded bronze, blackened steel, and Crusader plate; Hunters
wear feathered ranger hats and Woodland hoods; Druids antlered hide, Thornvine, Snowwolf, and
Silverleaf hoods; Sorcerers blue, purple, red, and white wizard hats and robes. From tier 25 the lines are named sets: Golden lion, Frostborn,
Crimson aegis, Skullcrusher, and the brute's Obsidian bulwark (Warrior); Windrider, Sunspear,
Glacierstrider, Shadowstalker, and the Great bear (Hunter); Spiritbloom, Mooncloak, Wildroot,
Verdant spirit, and the Elder stag (Druid); Astral veil, Arcane eclipse, Ashcaller, Voidweaver,
and the fire warlock's Netherflame (Sorcerer). Sets with painted art show the whole painted
figure when their armor is worn (see [art.md](art.md#painted-outfits)). There is also a weapon per
class (Warriors: swords, axes, and maces; Hunters: bows and crossbows; Sorcerers: wands;
Druids: rods), and an off-hand (shields for Warriors and Hunters, spellbooks for Sorcerers
and Druids). **Amulets, capes, charms, and rings start at tier 20.** An item needs its tier
level and, for weapons, off-hands, helmets, armor, legs, and boots, your class: the server refuses to equip it
otherwise, and worn items you no longer qualify for (after losing levels) give no stats.
Tooltips show the tier, level, and who can use an item; a coloured bar under each slot
shows its tier, red when you cannot use it yet. Stats come from the balance curves
(`game/data/items.gd`); the full table is in [balance.md](balance.md#gear-tiers).

## Level-50 hunting grounds and mythic gear

Endgame characters farm four **level 48–50 elites** in the high regions, each camp of two kept
at least seven tiles from roads so travellers are not caught. They hit like the Blackreed
warden: one at a time with spells and potions solo, a whole camp with a party. Each drops elite
gold, a 25% tier-45 gear roll, potions, rune shards (5%), a valuable trophy (50%), and pieces
of its own **mythic set** at 1.2–1.5% each:

| Elite | Region | Trophy (sells for) | Mythic pieces |
| --- | --- | --- | --- |
| Ashmaw drake (winged, horned) | Emberwaste | Ashmaw heartscale (380) | Drakeforged plate set (Warrior), Drakefang greatsword, Drakescale bulwark, Emberwing cape |
| Rime titan (ice-shard giant) | Hollow March | Rime core (360) | Rimeguard mail set (Hunter), Rimestring longbow, Rimeheart ring |
| Barrow lich (crowned, ranged) | Mirewood Fen | Lich phylactery (420) | Gravecall cloth set (Sorcerer), Gravecall wand and grimoire, Gravecall amulet |
| Thornscale basilisk | Gloamwood | Basilisk eye (340) | Thornscale leather set (Druid), Thornscale rod, Basilisk-eye charm |

**Mythic gear** is level 50, a step past tier 45 and below the relics (stats in
[balance.md](balance.md#gear-tiers)). Unlike relics it is ordinary loot: unbound, sold to
vendors (never bought from them), kept in the depot, and dropped on death like other gear.
Tooltips name each piece's source. Every class can farm a full mythic helmet, armor, legs,
boots, and weapon. Mythic pieces need a level-50 kill.

## The Hollow Reach

The endgame zone fills the south-east corner (tiles 700-757 x 690-753): a **high-risk level 45-50
PvP zone**
of blighted violet soil and dead trees inside an obsidian wall, entered on foot through a
single gate in its west wall (a clearing in the forest leads to it). An obsidian road runs
east past void wraiths, obsidian golems (elite), and hollow knights to the **Hollow
Sanctum**: an antechamber of pillars, a narrow gallery, and at the very end the throne room
with the **Void Gate**. Step through it (free, both ways) to the **Void Throne**, an arena
beyond the world where **Vaelith, Sovereign of the Hollow** sits; it is a level-50 full-loot
PvP zone open to everyone, so a rival raid can follow yours in. Void wraiths glow faintly; Vaelith wears
his own glowing relics. Obsidian walls block movement and sight like stone walls.

**Dying in the Hollow Reach drops everything**: your backpack, your gold, and every worn
item (as with a red skull), not the usual 10% chance per worn item. Only bound relics stay
with you. The banner warns you as you enter. Beginner protection (below level 8) still
applies. Zones get this rule with the `full_loot` flag on their marker.

## Final bosses and relics

Three level-50 final bosses each guard a lair: **Morvain the Drowned** at the far end of
Blackreed Isle, **Kharzul the Cinder Colossus** in the far east, and **Sylvaine the Hollow
Bloom** in the south-eastern forest, west of the Hollow Reach. The ultimate boss, **Vaelith**, waits on the Void
Throne past the Hollow Sanctum's gate and respawns after an hour. Each boss has the 700,000 health of the
raid boss (so it takes a twenty-player group), drops gold, and respawns 30 minutes after it
dies.

Bosses fight like raid bosses. When one engages, everyone within 20 tiles is warned that it
**enrages after 245 seconds**: from then on it hits ten times as hard, so the raid needs its
damage. Every 4 seconds it **pulses** dark energy at every player within 8 tiles, ignoring
defense; across a twenty-player raid that adds up to about 4.4 Druids' healing per second.
Each of its hits **wounds** its target, so every next hit on that player lands 25% harder
until 12 seconds pass without one: the Warriors (four, two pairs) must take turns, the second pulling the boss
with **Challenge** (Warrior spell from level 20: monsters within 2 tiles turn on the caster).
If the raid leaves, the boss walks home, heals, and forgets the fight. Its nameplate shows
ENRAGED once it enrages.

Glowing **relics** are quest rewards. Everyone who took part in the fight **and is still in
it** earns one **trophy** for that boss when it dies: players who damaged it, players it hit,
and players who healed any of them, if they are alive and within 15 tiles when it falls.
Standing nearby, or casting at full health, earns nothing. Every final boss stands in an open
PvP zone, so a raid can wipe the raid that is fighting it, finish the boss, and **steal the
kill**: the fallen raid gets nothing. Each final boss has its own **relic keeper** on Reedmere's north plaza, the town in the middle
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
**Choosing a class comes first**: until you have one, the trial is the only task anyone gives
you (other givers send you to the trainers, and show no mark), and the dungeon stairways turn
you away. The quest list leads the way: the trial, then "choose your class" at a trainer.
**Master Hesk**, outside Cinder Crossing's training hall in the south-east corner, gives
**The adventurer's trial**: hunt eight thornback boars in Greywood. Once you have passed it and
reached level 5, right-click a trainer in the hall and choose **Class**: Sir Garrow
(Warrior), Ranger Tamsin (Hunter), Magister Vell (Sorcerer), or Elder Fenna (Druid). Each
explains the class and its spells; **Become a ...** is permanent, restores your health
and mana, and hands you the class's tier-1 kit (helmet, armor, legs, boots, weapon, off-hand) that you lack, trading in starter pieces the class cannot use. Your
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

`game/data/balance.gd` defines the level 1-50 curves, all derived from a **700,000-health
final boss** that needs a raid of **at least twenty level-50 players with every class**:
an enrage timer demands damage, raid-wide pressure demands healers, and wound stacks
demand four tanks. See [`balance.md`](balance.md) for the anchors, class
profiles, raid checks, and full level table.
Combat uses these stats and curves directly.
