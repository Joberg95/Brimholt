extends RefCounted
## Endgame titles: a ladder of three per vocation, earned by what a character has done at the
## top of the game, shown in the character and party windows and to everyone who sees the
## character (World.export_player). A title once earned is kept (World players' "title" is the
## highest tier reached), even if a death costs levels.
##
## Tier 1: level 30 and CHAMPIONS_FIRST champion tasks done (the dungeon and cave champions:
## any task whose monster is a "champion"). Tier 2: level 40, the Hunters' Lodge chain finished
## (LODGE_TASK), and CHAMPIONS_SECOND champion tasks. Tier 3: level 50 and every final boss
## (Monsters with "relics") slain at least once (World players' "slain").

const Monsters = preload("res://game/data/monsters.gd")
const Quests = preload("res://game/data/quests.gd")

const NAMES: Dictionary = {
	"knight": ["Vanguard", "Warlord", "Warlord of the Void"],
	"paladin": ["Pathwarden", "Ranger Lord", "Ranger Lord of the Void"],
	"sorcerer": ["Magister", "Archmage", "Archmage of the Void"],
	"druid": ["Wildwarden", "Archdruid", "Archdruid of the Void"],
}
const COLORS: Array[Color] = [Color("#9fd0ff"), Color("#ffd860"), Color("#d0a0ff")]
const LEVELS: Array[int] = [30, 40, 50]
const CHAMPIONS_FIRST: int = 3
const CHAMPIONS_SECOND: int = 6
const LODGE_TASK: String = "lodge_behemoth"


## The champion tasks: tasks whose monster is a champion, in catalog order.
static func champion_tasks() -> Array[String]:
	var tasks: Array[String] = []
	for task: String in Quests.TASKS:
		if Monsters.MONSTERS[Quests.TASKS[task]["monster"]]["rank"] == "champion":
			tasks.append(task)
	return tasks


## The final bosses a tier-3 title asks for.
static func final_bosses() -> Array[String]:
	var bosses: Array[String] = []
	for kind: String in Monsters.MONSTERS:
		if Monsters.MONSTERS[kind].has("relics"):
			bosses.append(kind)
	return bosses


## The highest tier (1-3) a character's record qualifies for, or 0: from its level, done tasks
## ({task: true}), and slain final bosses ({boss: true}).
static func tier_for(level: int, done: Dictionary, slain: Dictionary) -> int:
	var champions: int = champion_tasks().filter(func(task: String) -> bool: return done.has(task)).size()
	var tier: int = 0
	if level >= LEVELS[0] and champions >= CHAMPIONS_FIRST:
		tier = 1
	if tier == 1 and level >= LEVELS[1] and done.has(LODGE_TASK) and champions >= CHAMPIONS_SECOND:
		tier = 2
	if tier == 2 and level >= LEVELS[2] and final_bosses().all(func(boss: String) -> bool: return slain.has(boss)):
		tier = 3
	return tier


## The title's name for a vocation, or "" for tier 0 (and for Adventurers, who have none).
static func name_of(vocation: String, tier: int) -> String:
	if tier <= 0 or not NAMES.has(vocation):
		return ""
	return NAMES[vocation][mini(tier, 3) - 1]


static func color_of(tier: int) -> Color:
	return COLORS[clampi(tier, 1, 3) - 1]


## What the next title asks for, as one line for the character window ("" at the top).
static func next_step(vocation: String, tier: int, done: Dictionary, slain: Dictionary) -> String:
	if tier >= 3 or not NAMES.has(vocation):
		return ""
	var champions: int = champion_tasks().filter(func(task: String) -> bool: return done.has(task)).size()
	var name: String = name_of(vocation, tier + 1)
	match tier:
		0:
			return "Next title: %s at level %d with %d champion tasks done (%d/%d)." % [name, LEVELS[0], CHAMPIONS_FIRST,
				mini(champions, CHAMPIONS_FIRST), CHAMPIONS_FIRST]
		1:
			return "Next title: %s at level %d, with the Hunters' Lodge finished%s and %d champion tasks (%d/%d)." % [name,
				LEVELS[1], " (done)" if done.has(LODGE_TASK) else "", CHAMPIONS_SECOND, mini(champions, CHAMPIONS_SECOND),
				CHAMPIONS_SECOND]
	var left: int = final_bosses().filter(func(boss: String) -> bool: return not slain.has(boss)).size()
	return "Next title: %s at level %d, with every final boss slain (%d to go)." % [name, LEVELS[2], left]
