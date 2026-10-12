extends RefCounted
## Town hunting tasks. A quest giver marker names its task; accept it from the giver, slay
## `count` of `monster` (any player who earns experience from the kill gets credit), then
## return to the giver. Each completed task replaces your pack with the next one in PACKS,
## so the reward does not depend on the order you finish them.

const TASKS: Dictionary = {
	"boar_cull": {"title": "Boar cull", "monster": "thornback_boar", "count": 15,
		"intro": "Thornback boars are tearing up the fields beyond the town walls."},
	"outlaw_bounty": {"title": "Outlaw bounty", "monster": "outlaw_archer", "count": 25,
		"intro": "Outlaw archers ambush every caravan on the road to Ashford."},
	"hollow_purge": {"title": "Hollow purge", "monster": "hollow_knight", "count": 30,
		"intro": "Hollow knights march on Emberfall from the wastes."},
}
## Bound packs worn in the bag slot, smallest first; each adds backpack slots.
const PACKS: Array[String] = ["traveler_pack", "explorer_pack", "pathfinder_pack"]


## The pack after `current` ("" for none), or "" when you already wear the largest.
static func next_pack(current: String) -> String:
	var index: int = PACKS.find(current) + 1
	return PACKS[index] if index < PACKS.size() else ""
