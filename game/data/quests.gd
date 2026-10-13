extends RefCounted
## Hunting tasks. A quest giver offers every task that names it as "giver": accept one, slay
## `count` of `monster` (or any of `also`; any player who earns experience from the kill gets
## credit), then return to the giver. Each task is done once per character.
##
## Rewards: town tasks ("reward": "pack") replace your pack with the next one in PACKS, so the
## reward does not depend on the order you finish them. Dungeon tasks ("reward": "experience")
## pay experience and gold derived from Balance (see reward()): `share` of what the kills
## themselves gave, so a boss task (share 1) doubles the boss's experience.

const Balance = preload("res://game/data/balance.gd")
const Monsters = preload("res://game/data/monsters.gd")
const Dungeons = preload("res://game/data/dungeons.gd")

const TASKS: Dictionary = {
	# The adventurer's trial: passing it (and reaching Balance.CHOOSE_LEVEL) lets an Adventurer
	# choose a vocation at a trainer. "level" sets the reward for monsters outside dungeons.
	"adventurers_trial": {"title": "The adventurer's trial", "giver": "trial_master", "monster": "thornback_boar",
		"count": 8, "level": 6, "reward": "experience", "share": 0.5,
		"intro": "Every vocation began as an adventurer. Hunt eight thornback boars in Greywood,\nand the trainers in the hall behind me will teach you."},
	"boar_cull": {"title": "Boar cull", "giver": "warden_brask", "monster": "thornback_boar", "count": 15,
		"reward": "pack", "intro": "Thornback boars are tearing up the fields beyond the town walls."},
	"outlaw_bounty": {"title": "Outlaw bounty", "giver": "captain_ardo", "monster": "outlaw_archer", "count": 25,
		"reward": "pack", "intro": "Outlaw archers ambush every caravan on the road to Ashford."},
	"hollow_purge": {"title": "Hollow purge", "giver": "marshal_venn", "monster": "hollow_knight", "count": 30,
		"reward": "pack", "intro": "Hollow knights march on Emberfall from the wastes."},
	# Quest hubs: a giver in the town nearest each band of overworld monsters, so there is always
	# a next stop (World.next_task). "level" is the band's typical level, for the reward.
	"highway_robbers": {"title": "Highway robbers", "giver": "harbourmaster_ilse", "monster": "road_bandit", "count": 20,
		"level": 9, "reward": "experience", "share": 0.5,
		"intro": "Bandits rob every cart between the landing and Greywood. Twenty fewer would do."},
	"wolf_winter": {"title": "Wolves at the woodline", "giver": "harbourmaster_ilse", "monster": "grey_wolf", "count": 20,
		"level": 12, "reward": "experience", "share": 0.5,
		"intro": "Grey wolves come down from Greywood and Westwind for our nets and goats."},
	"lurker_drain": {"title": "Drain the bog pools", "giver": "fenwarden_ostrel", "monster": "bog_lurker", "count": 25,
		"level": 16, "reward": "experience", "share": 0.5,
		"intro": "Bog lurkers spit at the reed cutters in Thornfield and Lurkmoor. Clear them out."},
	"golem_breakers": {"title": "Golem breakers", "giver": "quartermaster_rhosyn", "monster": "stone_golem", "count": 25,
		"level": 26, "reward": "experience", "share": 0.5,
		"intro": "The hills around the desert stand up and walk. Break twenty-five stone golems."},
	"wraith_quench": {"title": "Quench the wraiths", "giver": "quartermaster_rhosyn", "monster": "cinder_wraith", "count": 25,
		"level": 30, "reward": "experience", "share": 0.5,
		"intro": "Cinder wraiths drift over the waste and the fells, setting the scrub alight."},
	"stalker_hunt": {"title": "Stalkers in the fen", "giver": "huntmaster_corvel", "monster": "mire_stalker", "count": 25,
		"level": 40, "reward": "experience", "share": 0.5,
		"intro": "Mire stalkers took three of my hunters in Mirewood Fen. Take twenty-five of them."},
	"fen_beasts": {"title": "Beasts of the drowned wood", "giver": "huntmaster_corvel", "monster": "reedfang",
		"also": ["bog_hulk"], "target": "fen beasts", "count": 25, "level": 45, "reward": "experience", "share": 0.5,
		"intro": "Reedfangs and bog hulks rule the deep fen and Gloamwood. Thin them before they reach Emberfall."},
	# Dungeon tasks: a hunt through the copies, and the dungeon's champion.
	"cellar_vermin": {"title": "Vermin in the cellar", "giver": "cellarmaster_pell", "monster": "giant_rat",
		"also": ["sewer_rat"], "target": "cellar rats", "count": 25, "reward": "experience", "share": 0.5,
		"intro": "Rats have taken the old cellar under the town. Thin them out before they reach the granary."},
	"rat_king": {"title": "Down with the Rat King", "giver": "cellarmaster_pell", "monster": "rat_king", "count": 1,
		"reward": "experience", "share": 1.0,
		"intro": "A rat the size of a pony rules that cellar. Bring it down and the rest will scatter."},
	"crypt_rest": {"title": "Rest for the dead", "giver": "sexton_wren", "monster": "crypt_skeleton",
		"also": ["grave_ghoul"], "target": "risen dead", "count": 30, "reward": "experience", "share": 0.5,
		"intro": "The dead of Ashford's crypt will not lie still. Put them back to rest."},
	"abbot_morrow": {"title": "The abbot's last rites", "giver": "sexton_wren", "monster": "abbot_morrow", "count": 1,
		"reward": "experience", "share": 1.0,
		"intro": "Abbot Morrow raises them all from the bottom of the crypt. End his vigil."},
	"mine_clearing": {"title": "Clear the deep mine", "giver": "foreman_dagny", "monster": "cave_crawler",
		"also": ["ember_golem"], "target": "mine creatures", "count": 30, "reward": "experience", "share": 0.5,
		"intro": "Crawlers and ember golems drove my miners out. Clear the shafts so we can dig again."},
	"forgemaw": {"title": "Quench the Forgemaw", "giver": "foreman_dagny", "monster": "forgemaw", "count": 1,
		"reward": "experience", "share": 1.0,
		"intro": "Something burns at the bottom of the mine. The miners call it the Forgemaw."},
	"silk_harvest": {"title": "Cut the webs", "giver": "trapper_maud", "monster": "cave_spider",
		"also": ["venom_weaver"], "target": "Silkhollow spiders", "count": 25, "reward": "experience", "share": 0.5,
		"intro": "Spiders the size of dogs nest in Silkhollow. Take a torch, it is black as pitch down there."},
	"silk_matron": {"title": "The Silk Matron", "giver": "trapper_maud", "monster": "silk_matron", "count": 1,
		"reward": "experience", "share": 1.0,
		"intro": "Their mother spins at the bottom of the cave. Burn her nest and the wilds are ours again."},
}
## Relic keepers: quest giver -> the final boss whose trophies they trade for relics.
const RELIC_KEEPERS: Dictionary = {
	"relic_keeper": "morvain", "relic_keeper_kharzul": "kharzul", "relic_keeper_sylvaine": "sylvaine",
	"relic_keeper_vaelith": "vaelith",
}
## The trial an Adventurer passes before choosing a vocation.
const TRIAL_TASK: String = "adventurers_trial"
## Vocation trainers in Cinder Crossing's training hall: quest giver -> the vocation they teach,
## with what they say about it.
const TRAINERS: Dictionary = {
	"trainer_knight": ["knight", "Knights stand in front: the most health and armour, blades, axes, and maces, and Challenge to pull monsters off friends."],
	"trainer_paladin": ["paladin", "Paladins shoot from six tiles with bows and crossbows, heal themselves, and hit hard all the way to level 50."],
	"trainer_sorcerer": ["sorcerer", "Sorcerers burn everything from five tiles with wands: the most damage and mana, but little health."],
	"trainer_druid": ["druid", "Druids keep everyone alive with healing that reaches the whole party, and freeze enemies with rods."],
}
## Bound packs worn in the bag slot, smallest first; each adds backpack slots.
const PACKS: Array[String] = ["traveler_pack", "explorer_pack", "pathfinder_pack"]
## Gold coins are worth 25; Combat.roll_loot drops level / 10 piles, one more 60% of the time,
## and three more for ranked monsters. Reward gold follows the same expectation.
const COIN_VALUE: int = 25


## The pack after `current` ("" for none), or "" when you already wear the largest.
static func next_pack(current: String) -> String:
	var index: int = PACKS.find(current) + 1
	return PACKS[index] if index < PACKS.size() else ""


## The tasks a quest giver offers, in catalog order.
static func tasks_of(giver: String) -> Array[String]:
	var result: Array[String] = []
	for task: String in TASKS:
		if TASKS[task]["giver"] == giver:
			result.append(task)
	return result


## Whether killing a `kind` counts toward `task`.
static func counts(task: String, kind: String) -> bool:
	var definition: Dictionary = TASKS[task]
	return definition["monster"] == kind or kind in definition.get("also", [])


## How the task names what to slay ("cellar rats", or the monster's name in the plural).
static func target_name(task: String) -> String:
	var definition: Dictionary = TASKS[task]
	if definition.has("target"):
		return definition["target"]
	var name: String = Monsters.MONSTERS[definition["monster"]]["name"]
	return name if definition["count"] == 1 else name.to_lower() + "s"


## The level a task's monster is placed at (its dungeon legend), or 0 if it is not in a dungeon.
static func monster_level(kind: String) -> int:
	for dungeon: String in Dungeons.DUNGEONS:
		for symbol: String in Dungeons.DUNGEONS[dungeon]["monsters"]:
			var entry: Array = Dungeons.DUNGEONS[dungeon]["monsters"][symbol]
			if entry[0] == kind:
				return entry[1]
	return 0


## The dungeon a task's monster lives in, or "".
static func dungeon_of(task: String) -> String:
	var kind: String = TASKS[task]["monster"]
	for dungeon: String in Dungeons.DUNGEONS:
		for symbol: String in Dungeons.DUNGEONS[dungeon]["monsters"]:
			if Dungeons.DUNGEONS[dungeon]["monsters"][symbol][0] == kind:
				return dungeon
	return ""


## {experience, gold} for an "experience" task: `share` of the experience and expected gold of
## its kills at their dungeon level (or the task's "level" for overworld monsters); {} for pack tasks.
static func reward(task: String) -> Dictionary:
	var definition: Dictionary = TASKS[task]
	if definition["reward"] != "experience":
		return {}
	var kind: String = definition["monster"]
	var level: int = definition.get("level", monster_level(kind))
	var rank: String = Monsters.MONSTERS[kind]["rank"]
	var piles: float = level / 10 + 0.6 + (3.0 if rank != "normal" else 0.0)
	var share: float = definition["share"]
	return {
		"experience": roundi(definition["count"] * Balance.mob_experience(level, rank) * share),
		"gold": roundi(definition["count"] * piles * COIN_VALUE * share / 5.0) * 5,
	}
