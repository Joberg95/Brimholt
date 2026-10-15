extends RefCounted
## Professions: four gathering skills that collect resources from the land, and five crafting
## skills that turn them into gear, potions, and food at a town artisan. Every character can
## learn every profession; each skill rises from 1 to SKILL_MAX by doing it.
##
## The land has five resource bands from the monster levels where you stand (BAND_LEVELS: the
## middle of the region's or zone's level range). Gathering a band needs that skill level, so a
## miner works the Cinder Meadows' copper first and the Gloamwood's starmetal last. Crafted gear
## is the ordinary tier item (never mythic, relic, or hunting gear), so drops stay the best.

const Items = preload("res://game/data/items.gd")

const SKILL_MAX: int = 50
const GATHERING: Array[String] = ["mining", "woodcutting", "herbalism", "fishing"]
const CRAFTING: Array[String] = ["smithing", "woodworking", "tailoring", "alchemy", "cooking"]
const NAMES: Dictionary = {
	"mining": "Mining", "woodcutting": "Woodcutting", "herbalism": "Herbalism", "fishing": "Fishing",
	"smithing": "Smithing", "woodworking": "Woodworking", "tailoring": "Tailoring", "alchemy": "Alchemy", "cooking": "Cooking",
}
const DESCRIPTIONS: Dictionary = {
	"mining": "Break ore from the veins that glitter in rock faces.",
	"woodcutting": "Fell logs from trees.",
	"herbalism": "Pick herbs from the flowering patches in the wilds.",
	"fishing": "Fish open water within three tiles of the shore.",
	"smithing": "Plate and mail armor, Warrior weapons, shields, amulets, and rings.",
	"woodworking": "Bows, wands, rods, and charms.",
	"tailoring": "Leather and cloth armor, spellbooks, capes, and bags.",
	"alchemy": "Health and mana potions, up to great potions.",
	"cooking": "Food: more health and mana regeneration for a while.",
}
## Lowest land level of each resource band, and the skill gathering it needs.
const BAND_LEVELS: Array[int] = [1, 10, 20, 30, 40]
## The resource each gathering skill yields per band.
const RESOURCES: Dictionary = {
	"mining": ["copper_ore", "iron_ore", "silver_ore", "cobalt_ore", "starmetal_ore"],
	"woodcutting": ["pine_log", "oak_log", "yew_log", "ironbark_log", "elderwood_log"],
	"herbalism": ["sunflax", "mirereed", "silverthistle", "nightcotton", "starpetal"],
	"fishing": ["river_perch", "marsh_eel", "silver_trout", "deep_pike", "glimmerfin"],
}
## Terrain each gathering skill works, and how far away it may be (Chebyshev tiles). Herbalism
## works herb patches (herb_at) and mining works ore veins (Crafting.ORES): a few rock faces of
## mountains and outcrops ("CL") picked by ore_at, not every rock.
const SOURCES: Dictionary = {"mining": "CL", "woodcutting": "TD", "fishing": "~"}
## Ore veins: about one rock face in ORE_SPACING[band] facing open ground to the south, never two
## within ORE_GAP tiles of each other. The beginners' land has little rock, so copper is denser.
const ORE_SPACING: Array[int] = [2, 6, 6, 6, 6]
const ORE_GAP: int = 3
const REACH: Dictionary = {"mining": 1, "woodcutting": 1, "herbalism": 1, "fishing": 3}
## Seconds of work per gather (moving cancels it), and how long a worked node needs to regrow.
const GATHER_SECONDS: float = 3.0
const REGROW_SECONDS: float = 60.0
## Herb patches grow on grass, sand, and dusk soil outside towns: one cell in HERB_SPACING.
const HERB_GROUND: String = ".:d"
const HERB_SPACING: int = 89
## Seconds between crafts, and the most crafted in one request.
const CRAFT_SECONDS: float = 0.8
const MAX_CRAFT_COUNT: int = 10
## Gear recipes: [main, secondary] resources per slot at the lowest band; each band up multiplies
## both (band + 1). Smithing works ore with logs, woodworking logs with ore, tailoring herbs
## (fibre and dye) with ore (buckles and needles).
const GEAR_INPUTS: Dictionary = {
	"armor": [6, 2], "helmet": [4, 1], "legs": [4, 1], "boots": [3, 1], "main_hand": [7, 3], "off_hand": [5, 2],
	"necklace": [3, 2], "ring": [3, 2], "cape": [4, 1], "charm": [3, 2],
}
const MATERIALS: Dictionary = {
	"smithing": ["mining", "woodcutting"], "woodworking": ["woodcutting", "mining"], "tailoring": ["herbalism", "mining"],
}
## Potions, food, and bags: [output, count made, profession, skill, inputs [[resource, count], ...]].
const CONSUMABLES: Array = [
	["health_potion", 1, "alchemy", 1, [["sunflax", 2]]],
	["mana_potion", 1, "alchemy", 3, [["sunflax", 2]]],
	["strong_health_potion", 1, "alchemy", 20, [["silverthistle", 2], ["sunflax", 1]]],
	["strong_mana_potion", 1, "alchemy", 25, [["silverthistle", 1], ["mirereed", 2]]],
	["great_health_potion", 1, "alchemy", 40, [["starpetal", 2], ["nightcotton", 1]]],
	["great_mana_potion", 1, "alchemy", 45, [["starpetal", 1], ["nightcotton", 2]]],
	["grilled_perch", 1, "cooking", 1, [["river_perch", 2]]],
	["smoked_eel", 1, "cooking", 10, [["marsh_eel", 2], ["sunflax", 1]]],
	["trout_pie", 1, "cooking", 20, [["silver_trout", 2], ["mirereed", 1]]],
	["pike_stew", 1, "cooking", 30, [["deep_pike", 2], ["silverthistle", 1]]],
	["glimmerfin_feast", 1, "cooking", 40, [["glimmerfin", 2], ["nightcotton", 1]]],
	["leather_satchel", 1, "tailoring", 1, [["sunflax", 6], ["copper_ore", 2]]],
	["reedweave_bag", 1, "tailoring", 10, [["mirereed", 8], ["iron_ore", 2]]],
	["silkthistle_pack", 1, "tailoring", 20, [["silverthistle", 8], ["silver_ore", 3]]],
	["nightcotton_haversack", 1, "tailoring", 30, [["nightcotton", 10], ["cobalt_ore", 3]]],
	["starweave_rucksack", 1, "tailoring", 40, [["starpetal", 10], ["starmetal_ore", 4]]],
]


static func is_profession(id: Variant) -> bool:
	return typeof(id) == TYPE_STRING and NAMES.has(id)


## Experience from one skill level to the next (0 at SKILL_MAX).
static func experience_to_next(level: int) -> int:
	return 0 if level >= SKILL_MAX else 4 + level


## The band of land at a monster level.
static func band_for_level(level: int) -> int:
	var band: int = 0
	for index: int in BAND_LEVELS.size():
		if level >= BAND_LEVELS[index]:
			band = index
	return band


## Skill experience for one gather: 4 at the band's level, 1 less every 5 levels above it.
static func gather_gain(skill: int, band: int) -> int:
	return clampi(4 - (skill - BAND_LEVELS[band]) / 5, 0, 4)


## Skill experience for one craft: 4 at the recipe's level, 1 less every 3 levels above it,
## times half the resources it uses.
static func craft_gain(skill: int, recipe: Dictionary) -> int:
	var used: int = 0
	for entry: Array in recipe["inputs"]:
		used += entry[1]
	return clampi(4 - (skill - int(recipe["skill"])) / 3, 0, 4) * maxi(1, used / 2)


## Whether a herb patch grows on `cell` (given its terrain; zones are checked by the caller).
static func herb_at(cell: Vector2i, tile: String) -> bool:
	if tile.is_empty() or not tile in HERB_GROUND:
		return false
	var mixed: int = (cell.x * 73856093) ^ (cell.y * 19349663)
	return (mixed & 0x7fffffff) % HERB_SPACING == 0


## Whether a rock face on `cell` may hold an ore vein (given its terrain and whether open ground lies
## south of it, so the vein shows in its cliff face; zones and spacing are checked by the caller).
static func ore_at(cell: Vector2i, tile: String, open_south: bool, band: int) -> bool:
	if tile.is_empty() or not tile in SOURCES["mining"] or not open_south:
		return false
	var mixed: int = (cell.x * 83492791) ^ (cell.y * 73856093)
	return (mixed & 0x7fffffff) % ORE_SPACING[band] == 0


## The gathering skill a terrain tile serves, or "" (herb patches and ore veins are not a terrain:
## see Crafting.node_at).
static func source_of(tile: String) -> String:
	for profession: String in SOURCES:
		if profession != "mining" and not tile.is_empty() and tile in SOURCES[profession]:
			return profession
	return ""


## The crafting skill that makes a piece of equipment, or "" when it cannot be crafted:
## bags, torches, relics, mythic gear, and named hunting drops are never crafted.
static func gear_profession(item: Dictionary) -> String:
	var slot: String = item.get("slot", "")
	if slot.is_empty() or slot == "bag" or item.get("loot_only", false) or item.has("glow") or item.get("bound", false) \
			or Items.mythic(item) or item.get("look", "") == "torch" or not item.get("level", 0) in Items.TIER_LEVELS:
		return ""
	match slot:
		"helmet", "armor", "legs", "boots":
			return "smithing" if item.get("armor", "") in ["plate", "mail"] else "tailoring"
		"main_hand":
			return "smithing" if "knight" in item.get("vocations", []) else "woodworking"
		"off_hand":
			return "tailoring" if item.get("look", "") == "book" else "smithing"
		"necklace", "ring":
			return "smithing"
		"cape":
			return "tailoring"
		"charm":
			return "woodworking"
	return ""


## Every recipe by id (the id of what it makes): {id, profession, skill, inputs, output: [kind, count]}.
## Gear recipes come from the catalog: the tier's skill level, and its band's resources.
static func build_recipes(items: Dictionary) -> Dictionary:
	var recipes: Dictionary = {}
	for kind: String in items:
		var profession: String = gear_profession(items[kind])
		if profession.is_empty():
			continue
		var level: int = items[kind]["level"]
		var band: int = Items.TIER_LEVELS.find(level) / 2
		var amounts: Array = GEAR_INPUTS[items[kind]["slot"]]
		var inputs: Array = []
		for index: int in 2:
			inputs.append([RESOURCES[MATERIALS[profession][index]][band], int(amounts[index]) * (band + 1)])
		recipes[kind] = {"id": kind, "profession": profession, "skill": maxi(1, level), "inputs": inputs, "output": [kind, 1]}
	for entry: Array in CONSUMABLES:
		recipes[entry[0]] = {"id": entry[0], "profession": entry[2], "skill": entry[3], "inputs": entry[4].duplicate(true),
			"output": [entry[0], entry[1]]}
	return recipes
