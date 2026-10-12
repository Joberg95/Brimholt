extends SceneTree

const World = preload("res://game/core/world.gd")
const SpriteArt = preload("res://game/render/sprite_art.gd")
const Balance = preload("res://game/data/balance.gd")
const Keybinds = preload("res://game/input/keybinds.gd")
const Combat = preload("res://game/core/combat.gd")
const Monsters = preload("res://game/data/monsters.gd")
const Spells = preload("res://game/data/spells.gd")
const Items = preload("res://game/data/items.gd")
const Economy = preload("res://game/core/economy.gd")
const Quests = preload("res://game/data/quests.gd")
const CharacterStore = preload("res://game/persistence/character_store.gd")
const Identity = preload("res://game/persistence/identity.gd")
const SpriteArtSheets = preload("res://game/render/sprite_art.gd")
var failures: int = 0
var checks: int = 0
var clock: float = 0.0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func act(world: World, source: Variant, target: Variant) -> Dictionary:
	clock += 1.0
	return world.move_item(1, source, target, clock)


func _run() -> void:
	_map_checks()
	_zone_checks()
	_travel_checks()
	_keybind_checks()
	_combat_checks()
	_death_and_skull_checks()
	_party_checks()
	_gear_tier_checks()
	_town_checks()
	_persistence_checks()
	for spawn: Vector2i in World.SPAWNS:
		check(World.walkable(spawn), "walkable spawn")
	check(not World.walkable(Vector2i(-1, 1)), "negative bounds")
	check(not World.walkable(Vector2i(World.width(), 1)), "right bounds")
	check(not World.walkable(Vector2i(1, World.height())), "bottom bounds")
	check(not World.walkable(Vector2i(0, 1)), "wall collision")
	check(not World.walkable(Vector2i(3, 2)), "water collision")
	var world := World.new()
	check(world.add_player(1, 0.0), "playing host spawn")
	check(world.add_player(2, 0.0), "client spawn")
	check(not world.add_player(2, 0.0), "duplicate owner rejected")
	check(not world.add_player(0, 0.0), "invalid owner rejected")
	check(world.players[1]["cell"] != world.players[2]["cell"], "unique spawns")
	var before: Vector2i = world.players[2]["cell"]
	for direction: Vector2i in [Vector2i.ZERO, Vector2i(1, 1), Vector2i(2, 0)]:
		check(not world.move(2, direction, 0.0)["ok"], "non-cardinal or multiple tiles rejected")
	check(world.players[2]["cell"] == before, "invalid requests do not move player")
	check(not world.move(999, Vector2i.RIGHT, 0.0)["ok"], "unknown sender rejected")
	check(world.move(2, Vector2i.LEFT, 0.0)["ok"], "one cardinal move")
	check(world.players[2]["cell"] == Vector2i(6, 6), "server computes destination")
	check(not world.move(2, Vector2i.RIGHT, 0.01)["ok"], "server cooldown")
	check(not world.move(1, Vector2i.RIGHT, 0.2)["ok"], "occupied destination")
	check(world.move(2, Vector2i.DOWN, 0.2)["ok"], "next step after cooldown")
	check(world.occupied(Vector2i(6, 6), 0.21), "origin reserved in transit")
	check(not world.move(1, Vector2i.RIGHT, 0.21)["ok"], "cannot overlap a departing actor")
	var transit: Dictionary = world.export_player(2, 0.29)
	check(is_equal_approx(transit["remaining"], 0.09), "late join sees remaining movement")
	check(transit["from"] == Vector2i(6, 6), "late join sees movement origin")
	check(world.move(1, Vector2i.RIGHT, 0.4)["ok"], "origin released after movement")
	check(world.players[1]["facing"] == Vector2i.RIGHT, "authoritative facing")
	check(World.SPAWNS.size() == World.MAX_PLAYERS and World.MAX_PLAYERS == 12, "one spawn per player, twelve players")
	for id: int in range(3, World.MAX_PLAYERS + 1):
		check(world.add_player(id, 0.6), "spawn up to the player cap")
	check(not world.add_player(World.MAX_PLAYERS + 1, 0.6), "twelve-player cap")
	var cells: Dictionary = {}
	for id: int in world.players:
		cells[world.players[id]["cell"]] = true
	check(cells.size() == World.MAX_PLAYERS, "twelve unique spawn cells")
	world.remove_player(3)
	check(not world.players.has(3), "disconnect removes player")
	check(world.add_player(World.MAX_PLAYERS + 1, 0.6), "disconnect releases spawn")
	check(not world.toggle_equipment(999, "helmet", 0.0)["ok"], "unknown equipment owner rejected")
	check(not world.toggle_equipment(2, "unknown", 0.0)["ok"], "unknown slot rejected")
	check(world.toggle_equipment(2, "helmet", 0.6)["ok"], "equip sample")
	check(world.players[2]["equipment"]["helmet"] == "ember_cap", "server picks item")
	check(not world.toggle_equipment(2, "helmet", 0.61)["ok"], "equipment cooldown")
	var snapshot: Dictionary = world.snapshot(0.7)
	check(snapshot[2]["equipment"]["helmet"] == "ember_cap", "late-join equipment")
	snapshot[2]["equipment"].erase("helmet")
	check(world.players[2]["equipment"].has("helmet"), "snapshot cannot mutate server equipment")
	check(world.toggle_equipment(2, "helmet", 0.8)["ok"], "unequip sample")
	check(not world.players[2]["equipment"].has("helmet"), "unequip removes visual metadata")
	var walls := World.new()
	walls.add_player(1, 0.0)
	walls.players[1]["cell"] = Vector2i(8, 6)
	walls.players[1]["from"] = Vector2i(8, 6)
	check(not walls.move(1, Vector2i.DOWN, 0.0)["ok"], "map collision during movement")
	check(walls.players[1]["cell"] == Vector2i(8, 6), "blocked move preserves state")
	var joining := World.new()
	check(joining.add_player(1, 0.0), "late-join host spawn")
	check(joining.add_player(2, 0.0), "late-join client spawn")
	check(joining.move(2, Vector2i.RIGHT, 0.0)["ok"], "client vacates a spawn")
	check(joining.add_player(3, 0.1), "join during movement")
	check(joining.players[3]["cell"] == World.SPAWNS[2], "join skips reserved origin")
	joining.remove_player(3)
	check(joining.add_player(3, 0.2), "join after movement")
	check(joining.players[3]["cell"] == World.SPAWNS[1], "late join reuses released spawn")
	var timing := World.new()
	timing.add_player(1, 0.0)
	check(timing.move(1, Vector2i.RIGHT, 0.0)["ok"], "timing baseline move")
	check(not timing.move(1, Vector2i.RIGHT, World.MOVE_SECONDS - 0.000001)["ok"], "reject just before 180 ms")
	check(timing.move(1, Vector2i.RIGHT, World.MOVE_SECONDS)["ok"], "accept exactly at 180 ms")
	_inventory_checks()
	_sprite_checks()
	_slot_and_stat_checks()
	_balance_checks()
	print("BRIMHOLT_RULES: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _inventory_checks() -> void:
	for entry: Array in World.GROUND_ITEMS:
		check(World.walkable(entry[0]), "seeded ground item on walkable tile")
		check(World.ITEMS.has(World.kind_of(entry[1])), "seeded ground item is in the catalog")
	for vocation: String in Balance.VOCATIONS:
		for kind: String in World.start_kit(vocation):
			check(not World.slot_for(kind, {}).is_empty() and World.requirement_error(kind, 1, vocation).is_empty(),
				"%s start kit is equippable at level 1" % vocation)
		check(World.start_kit(vocation).size() <= World.BACKPACK_SIZE, "start kit fits the backpack")
	var bag := World.new()
	check(bag.ground_stack(Vector2i(10, 1)) == ["glowcap#2"], "seeded stackables merge into one ground entry")
	check(bag.add_player(1, 0.0, "knight"), "inventory player")
	var player: Dictionary = bag.players[1]
	# A level-5 Knight can use every item in this scenario (tier 1 and 5 armor and melee).
	player["level"] = 5
	var kit: Array = World.start_kit("knight")
	player["cell"] = Vector2i(8, 6)
	player["from"] = Vector2i(8, 6)
	var here: Vector2i = Vector2i(8, 6)
	var backpack: Array = player["backpack"]
	var equipment: Dictionary = player["equipment"]
	check(backpack.slice(0, kit.size()) == kit and backpack.count("") == World.BACKPACK_SIZE - kit.size(),
		"start kit in backpack")
	# The scenario below was written for a three-item backpack; keep that layout.
	for index: int in World.BACKPACK_SIZE:
		backpack[index] = kit[index] if index < 3 else ""
	check(not bag.export_player(1, 0.0).has("backpack"), "backpack is private by default")
	check(bag.export_player(1, 0.0, true)["backpack"] == backpack, "owner export includes backpack")
	check(not bag.snapshot(0.0, 2)[1].has("backpack"), "snapshot hides other players' backpacks")
	check(bag.snapshot(0.0, 1)[1].has("backpack"), "snapshot includes the viewer's backpack")
	var private_copy: Array = bag.export_player(1, 0.0, true)["backpack"]
	private_copy[0] = "glowcap"
	check(backpack[0] == "ember_cap", "exported backpack cannot mutate server state")

	var slot0: Dictionary = {"type": "backpack", "index": 0}
	var slot1: Dictionary = {"type": "backpack", "index": 1}
	var malformed: Array = [
		null, 5, "backpack", {}, {"type": 1}, {"type": "pocket", "index": 0},
		{"type": "backpack", "index": "0"}, {"type": "backpack", "index": 0.0},
		{"type": "backpack", "index": World.BACKPACK_SIZE}, {"type": "backpack", "index": -1},
		{"type": "backpack", "index": 0, "kind": "glowcap"}, {"type": "equipment", "slot": "feet"},
		{"type": "equipment", "slot": 1}, {"type": "ground", "cell": Vector2(8, 6)}, {"type": "ground"},
	]
	for bad: Variant in malformed:
		check(act(bag, bad, {"type": "backpack", "index": 7})["reason"] == "Unknown item location", "malformed source rejected")
		check(act(bag, slot0, bad)["reason"] == "Unknown item location", "malformed target rejected")
	check(not act(bag, {"type": "backpack"}, slot1)["ok"], "automatic slot is target-only")
	check(not bag.move_item(99, slot0, slot1, 100.0)["ok"], "unknown item owner rejected")
	check(act(bag, slot0, slot0)["reason"] == "The item is already there", "same location rejected")
	check(act(bag, {"type": "backpack", "index": 5}, slot1)["reason"] == "There is no item there", "empty source rejected")
	check(not act(bag, {"type": "equipment", "slot": "helmet"}, {"type": "backpack"})["ok"], "empty equipment rejected")
	check(act(bag, slot0, {"type": "equipment", "slot": "armor"})["reason"] == "That item does not fit there", "slot type enforced")
	check(backpack[0] == "ember_cap" and equipment.is_empty() and bag.ground_stack(here).is_empty(),
		"rejected item actions change nothing")

	check(act(bag, slot0, slot1)["ok"], "backpack swap")
	check(backpack[0] == "moss_coat" and backpack[1] == "ember_cap", "swap exchanges items")
	check(bag.move_item(1, slot0, slot1, clock + 0.01)["reason"] == "Item cooldown", "item cooldown")
	check(not bag.move_item(1, slot0, slot1, clock + World.ITEM_SECONDS - 0.000001)["ok"], "reject just before item cooldown")
	check(bag.move_item(1, slot0, slot1, clock + World.ITEM_SECONDS)["ok"], "accept exactly at item cooldown")
	clock += World.ITEM_SECONDS
	check(backpack[0] == "ember_cap" and backpack[1] == "moss_coat", "swap back")

	check(act(bag, slot0, {"type": "equipment", "slot": "helmet"})["ok"], "drag to equip")
	check(equipment["helmet"] == "ember_cap" and backpack[0] == "", "equip moves the item out of the backpack")
	var dropped: Dictionary = act(bag, {"type": "backpack", "index": 2}, {"type": "ground", "cell": here})
	check(dropped["ok"] and dropped["ground"] == [here], "drop reports its changed tile")
	check(bag.ground_stack(here) == ["copper_blade"] and backpack[2] == "", "drop places the item on the ground")
	check(act(bag, slot1, {"type": "ground", "cell": here + Vector2i(2, 0)})["reason"] == "That is too far away", "drop reach enforced")
	check(act(bag, slot1, {"type": "ground", "cell": Vector2i(8, 7)})["reason"] == "Items cannot be placed there", "no drops on walls")
	check(act(bag, {"type": "ground", "cell": Vector2i(14, 9)}, {"type": "backpack"})["reason"] == "That is too far away",
		"distant pickup rejected")
	check(bag.ground_stack(Vector2i(14, 9)) == ["iron_coif"], "distant item untouched")
	check(act(bag, slot1, {"type": "ground", "cell": Vector2i(9, 7)})["ok"], "diagonal drop within reach")
	var shifted: Dictionary = act(bag, {"type": "ground", "cell": Vector2i(9, 7)}, {"type": "ground", "cell": here})
	check(shifted["ok"] and shifted["ground"].size() == 2, "ground move reports both tiles")
	check(bag.ground_stack(here) == ["copper_blade", "moss_coat"] and not bag.ground.has(Vector2i(9, 7)),
		"ground move stacks on top and clears the source")
	check(act(bag, {"type": "ground", "cell": here}, {"type": "backpack"})["ok"], "pick up")
	check(backpack[0] == "moss_coat" and bag.ground_stack(here) == ["copper_blade"], "pick up takes the top item")
	check(act(bag, {"type": "ground", "cell": here}, {"type": "equipment", "slot": "main_hand"})["ok"], "equip from ground")
	check(equipment["main_hand"] == "copper_blade" and not bag.ground.has(here), "ground equip clears the tile")
	check(act(bag, {"type": "equipment", "slot": "helmet"}, {"type": "ground", "cell": here})["ok"], "drop worn item")
	check(not equipment.has("helmet") and bag.ground_stack(here) == ["ember_cap"], "worn item reaches the ground")
	bag.ground[Vector2i(9, 6)] = ["flint_hatchet"]
	check(act(bag, {"type": "ground", "cell": Vector2i(9, 6)}, {"type": "equipment", "slot": "main_hand"})["ok"],
		"equip over an occupied slot")
	check(equipment["main_hand"] == "flint_hatchet" and bag.ground_stack(Vector2i(9, 6)) == ["copper_blade"],
		"displaced item returns to the source tile")
	check(act(bag, slot0, {"type": "equipment", "slot": "armor"})["ok"], "equip armor")
	backpack[3] = "ash_tunic"
	check(act(bag, {"type": "equipment", "slot": "armor"}, {"type": "backpack", "index": 3})["ok"], "swap worn and carried armor")
	check(equipment["armor"] == "ash_tunic" and backpack[3] == "moss_coat", "worn/carried swap")
	backpack[4] = "glowcap"
	check(act(bag, {"type": "equipment", "slot": "armor"}, {"type": "backpack", "index": 4})["ok"], "unequip onto an unfit item")
	check(backpack[0] == "ash_tunic" and backpack[4] == "glowcap" and not equipment.has("armor"),
		"unfit occupant stays; item uses the first free slot")
	check(act(bag, {"type": "backpack", "index": 4}, {"type": "equipment", "slot": "helmet"})["reason"] \
		== "That item does not fit there", "non-equippable item rejected")
	check(bag.toggle_equipment(1, "helmet", clock + 1.0)["reason"] == "No item for that slot", "toggle needs an item")
	for index: int in World.BACKPACK_SIZE:
		if backpack[index] == "":
			backpack[index] = "glowcap"
	check(act(bag, {"type": "ground", "cell": here}, {"type": "backpack"})["reason"] == "Your backpack is full", "full pickup rejected")
	check(act(bag, {"type": "ground", "cell": here}, slot1)["reason"] == "Your backpack is full", "full explicit pickup rejected")
	clock += 1.0
	check(bag.toggle_equipment(1, "main_hand", clock)["reason"] == "Your backpack is full", "full unequip rejected")
	check(equipment["main_hand"] == "flint_hatchet" and bag.ground_stack(here) == ["ember_cap"], "full backpack keeps state")
	while bag.ground[here].size() < World.GROUND_STACK_MAX:
		bag.ground[here].append("iron_coif")
	backpack[1] = "ash_tunic"
	check(act(bag, slot1, {"type": "ground", "cell": here})["reason"] == "There is no room on that tile", "ground stack cap")
	var ground_copy: Dictionary = bag.ground_snapshot()
	ground_copy[here].append("glowcap")
	check(bag.ground[here].size() == World.GROUND_STACK_MAX, "ground snapshot cannot mutate server state")
	bag.remove_player(1)
	var seeded_cells: Dictionary = {}
	for entry: Array in World.GROUND_ITEMS:
		seeded_cells[entry[0]] = true
	# Seeded tiles that still hold items, plus the two test tiles (here and (9, 6)).
	check(bag.ground[here].size() == World.GROUND_STACK_MAX and bag.ground.size() == seeded_cells.size() + 2,
		"leaving keeps ground items; carried items leave with the player")
	_stacking_checks()


func _stacking_checks() -> void:
	check(World.kind_of("wolf_pelt#12") == "wolf_pelt" and World.count_of("wolf_pelt#12") == 12, "stack entry parts")
	check(World.count_of("wolf_pelt") == 1 and World.count_of("") == 0 and World.make_entry("wolf_pelt", 1) == "wolf_pelt",
		"a plain entry is a stack of one")
	check(World.stackable("wolf_pelt") and World.stackable("gold_coins") and World.stackable("glowcap")
		and not World.stackable("ember_cap") and not World.stackable("nope"), "only slotless items stack")
	var bag := World.new()
	check(bag.add_player(1, 0.0, "knight"), "stacking player")
	var player: Dictionary = bag.players[1]
	var backpack: Array = player["backpack"]
	var here := Vector2i(8, 6)
	player["cell"] = here
	player["from"] = here
	for index: int in World.BACKPACK_SIZE:
		backpack[index] = ""
	var clock: Array[float] = [10.0]
	var move := func(source: Dictionary, target: Dictionary) -> Dictionary:
		clock[0] += World.ITEM_SECONDS
		return bag.move_item(1, source, target, clock[0])
	var tile: Dictionary = {"type": "ground", "cell": here}
	var auto: Dictionary = {"type": "backpack"}
	backpack[2] = "wolf_pelt#5"
	bag.ground[here] = ["wolf_pelt#3"]
	check(move.call(tile, auto)["ok"] and backpack[2] == "wolf_pelt#8" and backpack[0] == "" and not bag.ground.has(here),
		"pickup merges into a matching backpack stack")
	backpack[4] = "wolf_pelt#2"
	check(move.call({"type": "backpack", "index": 4}, {"type": "backpack", "index": 2})["ok"]
		and backpack[2] == "wolf_pelt#10" and backpack[4] == "", "dragging onto a matching stack merges")
	backpack[4] = "ember_cap"
	backpack[5] = "wolf_pelt"
	check(move.call({"type": "backpack", "index": 5}, {"type": "backpack", "index": 4})["ok"]
		and backpack[2] == "wolf_pelt#11" and backpack[4] == "ember_cap", "dropping onto another item merges into the stack")
	backpack[2] = "wolf_pelt#%d" % World.STACK_MAX
	bag.ground[here] = ["wolf_pelt#4"]
	check(move.call(tile, auto)["ok"] and backpack[0] == "wolf_pelt#4" and World.count_of(backpack[2]) == World.STACK_MAX,
		"a full stack overflows into a free slot")
	check(move.call({"type": "backpack", "index": 0}, {"type": "backpack", "index": 2})["ok"]
		and backpack[0] == "wolf_pelt#%d" % World.STACK_MAX and backpack[2] == "wolf_pelt#4",
		"a merge past the stack limit swaps instead")
	var full: Array = []
	for count: int in World.GROUND_STACK_MAX:
		full.append("iron_coif")
	full[-1] = "wolf_pelt#2"
	bag.ground[here] = full
	var dropped: Dictionary = move.call({"type": "backpack", "index": 2}, tile)
	check(dropped["ok"] and dropped["ground"] == [here] and bag.ground[here].size() == World.GROUND_STACK_MAX
		and bag.ground[here][-1] == "wolf_pelt#6" and backpack[2] == "", "dropping merges onto a full tile's matching top stack")
	check(move.call({"type": "backpack", "index": 0}, {"type": "ground", "cell": Vector2i(8, 7)})["reason"]
		== "Items cannot be placed there", "stack drops still respect walls")
	bag.ground[here] = ["gold_coins#7"]
	var gold: int = player["gold"]
	check(move.call(tile, auto)["ok"] and player["gold"] == gold + 7 * World.ITEMS["gold_coins"]["gold"]
		and not backpack.has("gold_coins#7"), "a gold stack goes to the purse at full value")
	var stack: Array = ["wolf_pelt#%d" % (World.STACK_MAX - 1)]
	check(World.stack_onto(stack, "wolf_pelt#2") and stack == ["wolf_pelt#99", "wolf_pelt#2"],
		"ground stacks never exceed the stack limit")
	check(World.bound("abyssal_greathelm") and World.bound("abyssal_greathelm#1") and not World.bound("wolf_pelt#3"), "bound checks use the item id")


func _sprite_checks() -> void:
	var sheet_size: Vector2 = Vector2(3, 4) * SpriteArt.FRAME
	for texture: Texture2D in [SpriteArt.BODY, SpriteArt.CLOTH, SpriteArt.MARKER]:
		check(texture.get_size() == sheet_size, "character sheet uses 3x4 frames")
	check(SpriteArt.ITEM_ICONS.get_width() == SpriteArt.ITEM_ORDER.size() * SpriteArt.TILE, "one icon per item")
	check(SpriteArt.WALLS.get_width() == 16 * SpriteArt.WALL_SIZE, "one wall sprite per open-side mask")
	for kind: String in World.ITEMS:
		check(kind in SpriteArt.ITEM_ORDER, "catalog item has an icon")
		if World.ITEMS[kind]["slot"] in SpriteArt.VISIBLE_SLOTS:
			check(SpriteArt.GEAR.has(kind) and SpriteArt.GEAR[kind].get_size() == sheet_size,
				"equippable item has a worn sprite sheet")


func _slot_and_stat_checks() -> void:
	check(World.SLOTS.size() == 10 and World.SLOT_TYPES.size() == 10 and "cape" in World.SLOTS and "bag" in World.SLOTS,
		"ten equipment slots with a cape and a pack")
	for slot: String in World.SLOTS:
		check(World.SLOT_TYPES.has(slot), "every slot has a type")
		var fitting: bool = false
		for kind: String in World.ITEMS:
			fitting = fitting or World.fits(kind, slot)
		check(fitting, "every slot has at least one item")
	for kind: String in World.ITEMS:
		var item: Dictionary = World.ITEMS[kind]
		check(item["slot"] == "" or item["slot"] in World.SLOT_TYPES.values(), "item slot type is known")
		for stat: String in item["stats"]:
			check(stat in Balance.STATS and typeof(item["stats"][stat]) == TYPE_INT, "item stat is known")
	check(World.fits("garnet_ring", "ring_1") and World.fits("garnet_ring", "ring_2"), "rings fit both ring slots")
	check(not World.fits("garnet_ring", "necklace") and not World.fits("glowcap", "charm"), "wrong slot types rejected")
	check(World.fits("silverleaf_cape", "cape") and not World.fits("silverleaf_cape", "armor"), "capes fit the cape slot")
	check(not World.fits("no_such_item", "helmet") and not World.fits("ember_cap", "hand"), "unknown items or slots")
	check(World.slot_for("garnet_ring", {}) == "ring_1", "first ring goes to ring 1")
	check(World.slot_for("garnet_ring", {"ring_1": "cobalt_ring"}) == "ring_2", "second ring goes to ring 2")
	check(World.slot_for("garnet_ring", {"ring_1": "a", "ring_2": "b"}) == "ring_1", "full rings replace ring 1")
	check(World.slot_for("glowcap", {}) == "", "non-equippable item has no slot")

	var world := World.new()
	world.add_player(1, 0.0)
	var player: Dictionary = world.players[1]
	var equipment: Dictionary = player["equipment"]
	var backpack: Array = player["backpack"]
	check(player["level"] == 1 and player["experience"] == 0, "players start at level 1")
	check(world.export_player(1, 0.0)["level"] == 1 and not world.export_player(1, 0.0).has("experience"),
		"level is public, experience is private")
	check(world.export_player(1, 0.0, true)["experience"] == 0, "owner sees experience")
	backpack[4] = "cobalt_ring"
	backpack[5] = "garnet_ring"
	check(world.move_item(1, {"type": "backpack", "index": 5}, {"type": "equipment", "slot": "ring_1"}, 0.5)["reason"]
		== "The Garnet ring requires level 20", "accessories need their tier level")
	player["level"] = 25
	check(world.move_item(1, {"type": "backpack", "index": 4}, {"type": "equipment", "slot": "ring_2"}, 1.0)["ok"],
		"equip ring 2")
	check(world.move_item(1, {"type": "backpack", "index": 5}, {"type": "equipment", "slot": "ring_1"}, 2.0)["ok"],
		"equip ring 1")
	check(world.move_item(1, {"type": "equipment", "slot": "ring_1"}, {"type": "equipment", "slot": "ring_2"}, 3.0)["ok"],
		"swap rings between ring slots")
	check(equipment["ring_1"] == "cobalt_ring" and equipment["ring_2"] == "garnet_ring", "ring swap exchanges items")
	check(world.move_item(1, {"type": "equipment", "slot": "ring_1"}, {"type": "equipment", "slot": "necklace"}, 4.0)["reason"]
		== "That item does not fit there", "ring cannot be worn as a necklace")
	backpack[6] = "hearth_charm"
	check(world.move_item(1, {"type": "backpack", "index": 6}, {"type": "equipment", "slot": "ring_1"}, 5.0)["reason"]
		== "That item does not fit there", "charm cannot be worn as a ring")
	check(equipment["ring_1"] == "cobalt_ring" and backpack[6] == "hearth_charm", "rejected ring move changes nothing")
	check(world.move_item(1, {"type": "backpack", "index": 6}, {"type": "equipment", "slot": "charm"}, 6.0)["ok"], "equip charm")
	check(world.toggle_equipment(1, "off_hand", 7.0)["ok"] and equipment["off_hand"] == "oak_buckler", "toggle off hand")
	check(world.toggle_equipment(1, "main_hand", 8.0)["ok"] and equipment["main_hand"] == "willow_shortbow", "toggle main hand")
	var base: Dictionary = Balance.base_stats(25)
	var expected: Dictionary = base.duplicate()
	for slot: String in equipment:
		for stat: String in World.ITEMS[equipment[slot]]["stats"]:
			expected[stat] += World.ITEMS[equipment[slot]]["stats"][stat]
	check(World.stats(25, equipment) == expected, "worn item stats add to the base stats")
	check(World.stats(25, equipment)["mana"] > base["mana"] and World.stats(25, equipment)["regen"] > base["regen"],
		"rings and charms add mana and regeneration")
	check(World.stats(19, equipment)["health"] == Balance.base_stats(19)["health"],
		"accessories above your level give nothing (for example after losing levels)")
	check(World.stats(25, {"main_hand": "copper_blade"}) == base, "another vocation's weapon gives nothing")
	base = Balance.base_stats(1)
	check(World.stats(1, {}) == base, "no gear means base stats")
	check(World.stats(1, {"helmet": 5, "armor": "not_an_item"}) == base, "malformed equipment adds nothing")
	check(World.stats(Balance.MAX_LEVEL + 10, {}) == Balance.base_stats(Balance.MAX_LEVEL), "level clamps at max")


func _balance_checks() -> void:
	check(Balance.mob_health(Balance.MAX_LEVEL, "boss") == Balance.FINAL_BOSS_HEALTH, "final boss has 350,000 health")
	check(Balance.FINAL_BOSS_HEALTH == 350000, "final boss anchor")
	check(Balance.mob_health(1) == 30 and Balance.mob_health(Balance.MAX_LEVEL) == 1966, "normal mob health range")
	check(Balance.boss_ratio() > 150.0, "the boss is a raid boss, well over a hundred normal mobs")
	check(is_equal_approx(Balance.ATTACK_SECONDS, 2.0), "Tibia-style two-second attacks")
	_raid_checks()
	check(ceili(Balance.mob_health(1) / float(Balance.base_attack(1))) == 8, "ungeared level 1 needs 8 hits")
	for level: int in range(1, Balance.MAX_LEVEL + 1):
		var hits: int = ceili(Balance.mob_health(level) / float(Balance.geared_attack(level)))
		check(hits >= 5 and hits <= 7, "geared players need about six hits at every level")
		check(Balance.gear_attack_budget(level) >= 0, "gear budget is never negative")
		if level > 1:
			for rank: String in Balance.RANKS:
				check(Balance.mob_health(level, rank) > Balance.mob_health(level - 1, rank), "mob health grows")
				check(Balance.mob_damage(level, rank) >= Balance.mob_damage(level - 1, rank), "mob damage grows")
			check(Balance.player_health(level) > Balance.player_health(level - 1), "player health grows")
			check(Balance.experience_to_next(level) > Balance.experience_to_next(level - 1) \
				or level == Balance.MAX_LEVEL, "levels get longer")
		var falls: float = Balance.player_health(level) / float(Balance.mob_damage(level))
		if level > Balance.EARLY_DAMAGE_LEVELS:
			check(falls >= 14.0 and falls <= 16.0, "a player survives about 15 same-level normal hits")
		else:
			check(falls >= 15.0 and falls <= 31.0, "early monsters hit softer: 15 to 30 hits to fall")
	check(Balance.mob_health(10, "elite") == roundi(Balance.mob_health(10) * 4.0) \
		or absi(Balance.mob_health(10, "elite") - Balance.mob_health(10) * 4) <= 2, "elites have four times the health")
	check(Balance.experience_to_next(Balance.MAX_LEVEL) == 0, "no experience past max level")
	check(Balance.damage_taken(100, 0) == 100 and Balance.damage_taken(100, 100) == 50, "defense curve")
	check(Balance.damage_taken(100, -50) == 100, "negative defense cannot amplify damage")
	check(Balance.mob_health(0) == Balance.mob_health(1) and Balance.mob_health(99) == Balance.mob_health(50),
		"levels clamp to 1-50")


func _raid_checks() -> void:
	var raid: Dictionary = Balance.RAID
	var size: int = 0
	for vocation: String in raid:
		size += raid[vocation]
		check(Balance.VOCATIONS.has(vocation), "raid uses known vocations")
	check(size == 10 and raid.size() == Balance.VOCATIONS.size(), "intended raid is ten players of every vocation")
	var result: Dictionary = Balance.raid_check(raid)
	check(result["ok"], "the intended raid wins")
	check(absf(result["seconds"] - Balance.RAID_FIGHT_SECONDS) < 0.01, "the intended raid takes the planned time")
	for vocation: String in raid:
		var smaller: Dictionary = raid.duplicate()
		smaller[vocation] -= 1
		check(not Balance.raid_check(smaller)["ok"], "removing any one player loses")
	for vocation: String in Balance.VOCATIONS:
		check(not Balance.raid_check({vocation: 12})["ok"], "a single-vocation group of twelve loses")
	check(not Balance.raid_check({"knight": 1, "paladin": 1, "sorcerer": 1, "druid": 1})["ok"], "four players lose")
	check(Balance.raid_check({"knight": 2, "paladin": 2, "sorcerer": 4, "druid": 2})["ok"], "other ten-player mixes can win")
	check(Balance.raid_check({"knight": 2, "paladin": 4, "sorcerer": 4, "druid": 2})["ok"], "twelve players win faster")
	# Exhaustively: no group of nine or fewer level-50 players can win.
	var smallest: int = 99
	for knights: int in 10:
		for paladins: int in 10 - knights:
			for sorcerers: int in 10 - knights - paladins:
				for druids: int in 10 - knights - paladins - sorcerers:
					var group: Dictionary = {"knight": knights, "paladin": paladins, "sorcerer": sorcerers, "druid": druids}
					if Balance.raid_check(group)["ok"]:
						smallest = mini(smallest, knights + paladins + sorcerers + druids)
	check(smallest > 9, "no group of nine or fewer can defeat the final boss")
	var stats: Dictionary = {}
	for vocation: String in Balance.VOCATIONS:
		stats[vocation] = Balance.base_stats(Balance.MAX_LEVEL, vocation)
	check(stats["knight"]["health"] > stats["paladin"]["health"] and stats["paladin"]["health"] > stats["druid"]["health"],
		"knights are sturdiest, casters frailest")
	check(stats["sorcerer"]["attack"] > stats["paladin"]["attack"] and stats["paladin"]["attack"] > stats["knight"]["attack"],
		"sorcerers hit hardest")
	check(stats["druid"]["healing"] > stats["paladin"]["healing"] and stats["sorcerer"]["healing"] == 0, "druids heal most")
	check(stats["druid"]["mana"] > stats["paladin"]["mana"] and stats["paladin"]["mana"] > stats["knight"]["mana"],
		"casters have the most mana")
	check(stats["knight"]["defense"] > stats["sorcerer"]["defense"], "knights have base defense")
	check(Balance.base_stats(1, "no_such_vocation") == Balance.base_stats(1), "unknown vocation falls back")
	var world := World.new()
	check(not world.add_player(1, 0.0, "necromancer"), "unknown vocation rejected")
	check(world.add_player(1, 0.0, "druid") and world.players[1]["vocation"] == "druid", "vocation stored")
	check(world.export_player(1, 0.0)["vocation"] == "druid", "vocation is public")
	check(World.stats(1, {}, "druid") == Balance.base_stats(1, "druid"), "stats use vocation")


## Labels each walkable tile with a connected-component number (-1 for blocked tiles).
func _components() -> PackedInt32Array:
	var width: int = World.width()
	var labels := PackedInt32Array()
	labels.resize(width * World.height())
	labels.fill(-1)
	var next_label: int = 0
	for start: int in labels.size():
		if labels[start] >= 0 or not World.walkable(Vector2i(start % width, start / width)):
			continue
		labels[start] = next_label
		var stack: PackedInt32Array = [start]
		while not stack.is_empty():
			var index: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			var cell := Vector2i(index % width, index / width)
			for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var next: Vector2i = cell + step
				var next_index: int = next.y * width + next.x
				if World.walkable(next) and labels[next_index] < 0:
					labels[next_index] = next_label
					stack.append(next_index)
		next_label += 1
	return labels


func _map_checks() -> void:
	var unknown: int = 0
	var ragged: int = 0
	for row: String in World.ROWS:
		ragged += 0 if row.length() == World.width() else 1
		for tile: String in row:
			unknown += 0 if tile in World.TERRAINS or tile == " " else 1
	check(ragged == 0, "rectangular map")
	check(unknown == 0, "every tile is a known terrain")
	check(World.width() >= 24 and World.height() >= 18 and World.terrain(Vector2i(0, 1)) == "#", "map loaded from the scene")
	check(World.SPAWNS.size() == World.MAX_PLAYERS, "one spawn marker per player")
	var spawn_cells: Dictionary = {}
	for spawn: Vector2i in World.SPAWNS:
		spawn_cells[spawn] = true
	check(spawn_cells.size() == World.SPAWNS.size(), "spawn markers are on different tiles")
	for entry: Array in World.GROUND_ITEMS:
		check(World.ITEMS.has(entry[1]) and World.walkable(entry[0]), "item markers name catalog items on walkable tiles")
	check(World.FERRYMEN.size() >= 2, "the world has ferrymen")
	for id: String in World.FERRYMEN:
		var npc: Dictionary = World.FERRYMEN[id]
		check(not npc["name"].is_empty() and not npc["place"].is_empty(), "ferryman has a name and a dock name")
		check(World.NPC_CELLS.get(npc["cell"], "") == id and not World.walkable(npc["cell"]), "ferrymen block their tile")
		check(npc["facing"] in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT], "ferryman faces a cardinal direction")
		check(not npc["routes"].is_empty(), "ferryman has routes")
		for destination: String in npc["routes"]:
			check(World.FERRYMEN.has(destination) and destination != id, "route leads to another ferryman")
			check(npc["routes"][destination] > 0, "fares are positive")
	# Every ferryman, spawn, and item must be reachable on foot from the spawns or by boat.
	var labels: PackedInt32Array = _components()
	var width: int = World.width()
	var home: int = labels[World.SPAWNS[0].y * width + World.SPAWNS[0].x]
	for spawn: Vector2i in World.SPAWNS:
		check(labels[spawn.y * width + spawn.x] == home, "all spawns are connected")
	var dock_areas: Dictionary = {}
	for id: String in World.FERRYMEN:
		var areas: Dictionary = {}
		for dy: int in range(-World.TALK_RANGE, World.TALK_RANGE + 1):
			for dx: int in range(-World.TALK_RANGE, World.TALK_RANGE + 1):
				var cell: Vector2i = World.FERRYMEN[id]["cell"] + Vector2i(dx, dy)
				if World.walkable(cell):
					areas[labels[cell.y * width + cell.x]] = true
		check(not areas.is_empty(), "players can stand next to every ferryman")
		dock_areas[id] = areas
	var reached: Dictionary = {home: true}
	var changed: bool = true
	while changed:
		changed = false
		for id: String in World.FERRYMEN:
			var boards: bool = false
			for area: int in dock_areas[id]:
				boards = boards or reached.has(area)
			if boards:
				for destination: String in World.FERRYMEN[id]["routes"]:
					for area: int in dock_areas.get(destination, {}):
						if not reached.has(area):
							reached[area] = true
							changed = true
	for id: String in World.FERRYMEN:
		var reachable: bool = false
		for area: int in dock_areas[id]:
			reachable = reachable or reached.has(area)
		check(reachable, "every ferryman can be reached on foot or by boat")
	for entry: Array in World.GROUND_ITEMS:
		var cell: Vector2i = entry[0]
		check(reached.has(labels[cell.y * width + cell.x]), "every item can be reached")


func _travel_checks() -> void:
	var world := World.new()
	world.add_player(1, 0.0)
	var player: Dictionary = world.players[1]
	var from: String = "cinder_landing" if World.FERRYMEN.has("cinder_landing") else World.FERRYMEN.keys()[0]
	var to: String = World.FERRYMEN[from]["routes"].keys()[0]
	var fare: int = World.FERRYMEN[from]["routes"][to]
	check(player["gold"] == World.START_GOLD and world.export_player(1, 0.0, true)["gold"] == World.START_GOLD,
		"players start with gold, sent to their owner")
	check(not world.export_player(1, 0.0).has("gold"), "gold is private")
	check(world.travel(1, from, to, 1.0)["reason"] == "Walk closer to the ferryman", "must stand near the ferryman")
	check(world.travel(1, 5, to, 1.0)["reason"] == "Unknown ferryman", "malformed ferryman rejected")
	check(world.travel(1, "nobody", to, 1.0)["reason"] == "Unknown ferryman", "unknown ferryman rejected")
	check(world.travel(1, from, "nowhere", 1.0)["reason"] == "That ferryman does not sail there", "unknown route rejected")
	check(world.travel(1, from, from, 1.0)["reason"] == "That ferryman does not sail there", "cannot sail to yourself")
	check(world.travel(1, from, [to], 1.0)["reason"] == "That ferryman does not sail there", "malformed route rejected")
	check(not world.travel(99, from, to, 1.0)["ok"], "unknown traveller rejected")
	var dock: Vector2i = world.arrival_cell(from, 1.0)
	check(World.walkable(dock) and World.chebyshev(dock, World.FERRYMEN[from]["cell"]) <= World.TALK_RANGE,
		"arrival tiles are walkable and in talking range")
	player["cell"] = dock
	player["from"] = dock
	player["gold"] = fare - 1
	check(world.travel(1, from, to, 1.0)["reason"] == "You need %d gold to sail there" % fare, "fare is enforced")
	check(player["cell"] == dock and player["gold"] == fare - 1, "rejected travel changes nothing")
	player["gold"] = fare + 5
	player["next_move"] = 3.0
	check(world.travel(1, from, to, 2.0)["reason"] == "Stand still to board", "cannot board mid-step")
	player["next_move"] = 2.0
	var trip: Dictionary = world.travel(1, from, to, 2.0)
	check(trip["ok"] and player["gold"] == 5, "travel deducts the fare")
	check(World.chebyshev(player["cell"], World.FERRYMEN[to]["cell"]) <= World.TALK_RANGE and player["from"] == player["cell"],
		"travel lands next to the destination ferryman without a step")
	check(trip["state"]["gold"] == 5 and trip["message"].contains(World.FERRYMEN[to]["place"]), "travel reports the trip")
	var back: String = World.FERRYMEN[to]["routes"].keys()[0]
	check(world.travel(1, to, back, 2.5)["reason"] == "Travel cooldown", "travel cooldown")
	player["gold"] = 1000
	check(world.travel(1, to, back, 2.0 + World.TRAVEL_SECONDS)["ok"], "travel again after the cooldown")
	# A full dock refuses passengers instead of stacking them.
	var crowd := World.new()
	crowd.add_player(1, 0.0)
	var free_cells: Array[Vector2i] = []
	for dy: int in range(-World.TALK_RANGE, World.TALK_RANGE + 1):
		for dx: int in range(-World.TALK_RANGE, World.TALK_RANGE + 1):
			var cell: Vector2i = World.FERRYMEN[to]["cell"] + Vector2i(dx, dy)
			if World.walkable(cell):
				free_cells.append(cell)
	if free_cells.size() < World.MAX_PLAYERS:
		for index: int in free_cells.size():
			crowd.add_player(index + 2, 0.0)
			crowd.players[index + 2]["cell"] = free_cells[index]
			crowd.players[index + 2]["from"] = free_cells[index]
		crowd.players[1]["cell"] = crowd.arrival_cell(from, 0.0)
		crowd.players[1]["gold"] = 1000
		check(crowd.arrival_cell(to, 5.0) == Vector2i(-1, -1), "a full dock has no arrival tile")
		check(crowd.travel(1, from, to, 5.0)["reason"].begins_with("The dock at"), "a full dock refuses passengers")
	# Gold coins go straight into the purse, even with a full backpack.
	var purse := World.new()
	purse.add_player(1, 0.0)
	var owner: Dictionary = purse.players[1]
	owner["cell"] = Vector2i(8, 6)
	owner["backpack"].fill("glowcap")
	purse.ground[Vector2i(9, 6)] = ["gold_coins"]
	check(purse.move_item(1, {"type": "ground", "cell": Vector2i(9, 6)}, {"type": "equipment", "slot": "helmet"}, 1.0)["reason"]
		== "That item does not fit there", "gold cannot be worn")
	var pickup: Dictionary = purse.move_item(1, {"type": "ground", "cell": Vector2i(9, 6)}, {"type": "backpack"}, 2.0)
	check(pickup["ok"] and owner["gold"] == World.START_GOLD + 25, "picking up gold adds it to the purse")
	check(not purse.ground.has(Vector2i(9, 6)) and pickup["ground"] == [Vector2i(9, 6)], "gold leaves the ground")
	check(owner["backpack"].count("glowcap") == World.BACKPACK_SIZE, "gold does not use a backpack slot")


func _zone_checks() -> void:
	for zone: Dictionary in World.ZONES:
		check(not zone["name"].is_empty() and zone["rect"].has_area(), "zones have a name and an area")
		check(zone["min_level"] >= 1 and zone["min_level"] <= zone["max_level"] and zone["max_level"] <= Balance.MAX_LEVEL,
			"zone levels are within 1-50")
	for spawn: Dictionary in World.MONSTER_SPAWNS:
		check(not spawn["monster"].is_empty() and spawn["count"] >= 1 and spawn["radius"] >= 0, "monster spawn is complete")
		check(spawn["level"] >= 1 and spawn["level"] <= Balance.MAX_LEVEL and World.walkable(spawn["cell"]),
			"monster spawn has a valid level and stands on a walkable tile")
		var zone: Dictionary = World.zone_at(spawn["cell"])
		if not zone.is_empty():
			check(spawn["level"] >= zone["min_level"] and spawn["level"] <= zone["max_level"], "monster level fits its zone")
	check(World.zone_at(Vector2i(-50, -50)).is_empty(), "outside the map is no zone")
	check(World.zone_at(World.SPAWNS[0]).get("town", false) and not World.zone_at(World.SPAWNS[0])["pvp"],
		"Cinder Crossing is a safe town")
	var hollow: Rect2i = World.ZONES.filter(func(zone: Dictionary) -> bool: return zone["name"] == "The Hollow Reach")[0]["rect"]
	var towns: int = 0
	for zone: Dictionary in World.ZONES:
		if zone["town"]:
			towns += 1
			check(not zone["pvp"] and not zone["full_loot"], "%s is safe" % zone["name"])
			check(Vector2(zone["rect"].get_center()).distance_to(Vector2(hollow.get_center())) > 200.0,
				"%s is far from the Hollow Reach" % zone["name"])
			for spawn: Dictionary in World.MONSTER_SPAWNS:
				check(not zone["rect"].has_point(spawn["cell"]), "no monsters spawn in %s" % zone["name"])
	check(towns >= 7, "every town is a safe zone")
	var central: int = 0
	for id: String in World.FERRYMEN:
		var cell: Vector2 = Vector2(World.FERRYMEN[id]["cell"])
		if World.FERRYMEN[id]["vehicle"] == "coach" and cell.distance_to(Vector2(World.width(), World.height()) / 2.0) < 220.0:
			central += 1
	check(central >= 4, "coach towns ring the centre of the map")
	var ferries: Array = World.FERRYMEN.keys().filter(func(id: String) -> bool:
		return World.FERRYMEN[id]["vehicle"] == "ferry" and id not in ["reedmere", "blackreed_isle"])
	check(ferries.size() == 2 and World.FERRYMEN["cinder_landing"]["routes"].keys() == ["lastlight"]
		and World.FERRYMEN["lastlight"]["cell"].y > World.height() - 100, "one coastal ferry runs from the top to the bottom")
	if World.FERRYMEN.has("blackreed_isle") and World.FERRYMEN.has("reedmere"):
		var isle: Dictionary = World.zone_at(World.FERRYMEN["blackreed_isle"]["cell"])
		check(isle.get("pvp", false) and isle["min_level"] == 40 and isle["max_level"] == 50, "Blackreed Isle is a level 40-50 PvP zone")
		check(World.FERRYMEN["reedmere"]["routes"].keys() == ["blackreed_isle"]
			and World.FERRYMEN["blackreed_isle"]["routes"].keys() == ["reedmere"], "only Reedmere sails to the island")
		var on_isle: int = 0
		for spawn: Dictionary in World.MONSTER_SPAWNS:
			on_isle += 1 if World.zone_at(spawn["cell"]) == isle else 0
		check(on_isle >= 5, "the island has monster spawn points")
		var coaches: Array[String] = []
		for id: String in World.FERRYMEN:
			if World.FERRYMEN[id]["vehicle"] == "coach":
				coaches.append(id)
			elif id not in ["reedmere", "blackreed_isle"]:
				check(not World.FERRYMEN[id]["routes"].has("blackreed_isle") and World.FERRYMEN[id]["cell"].x < 64,
					"coastal ports sail the western sea only")
		check(World.width() == 768 and World.height() == 768, "the world is 768 by 768 tiles")
		check(coaches.size() >= 6, "coach stations link the inland towns")
		for id: String in coaches:
			var routes: Dictionary = World.FERRYMEN[id]["routes"]
			check(routes.size() == coaches.size() - 1, "%s runs to every other coach station" % id)
			for destination: String in routes:
				check(World.FERRYMEN[destination]["vehicle"] == "coach" and routes[destination] > 0,
					"coaches only run between coach stations, for a fare")


func _keybind_checks() -> void:
	var path: String = "user://keybinds_test.cfg"
	var binds := Keybinds.new(path)
	check(binds.action_for(KEY_1) == "slot_1" and binds.action_for(KEY_9) == "slot_9", "action bar defaults to 1-9")
	check(binds.action_for(KEY_W) == "move_up" and binds.action_for(KEY_UP) == "move_up", "movement has two default keys")
	check(binds.action_for(KEY_NONE) == "" and binds.action_for(KEY_F12) == "", "unbound keys do nothing")
	check(binds.bar == Keybinds.DEFAULT_BAR and binds.bar.count("") == Keybinds.SLOTS, "the bar starts empty (spells fill it)")
	check(binds.bind("slot_1", 0, KEY_Q) and binds.action_for(KEY_Q) == "slot_1" and binds.action_for(KEY_1) == "",
		"rebinding replaces the old key")
	check(binds.bind("slot_2", 1, KEY_Q) and binds.action_for(KEY_Q) == "slot_2" and binds.keys["slot_1"][0] == KEY_NONE,
		"a key used elsewhere moves to the new action")
	check(not binds.bind("slot_3", 0, KEY_ESCAPE) and binds.action_for(KEY_3) == "slot_3", "Escape cannot be bound")
	check(not binds.bind("no_such_action", 0, KEY_P) and not binds.bind("slot_3", 2, KEY_P), "invalid bindings rejected")
	check(binds.bind("slot_3", 0, KEY_NONE) and binds.action_for(KEY_3) == "", "a binding can be cleared")
	check(binds.set_bar(4, "spell:" + Spells.SPELLS.keys()[0]) and not binds.set_bar(9, "")
		and not binds.set_bar(0, "fireball") and not binds.set_bar(0, "spell:fireball"),
		"bar slots accept known spells only")
	for item_entry: String in ["pick_up", "target_nearest", "world_map", "toggle_helmet", "item:ember_cap", "ember_cap"]:
		check(not binds.set_bar(1, item_entry), "the action bar rejects non-spell entry %s" % item_entry)
	check(binds.set_bar(1, "") and binds.bar[1] == "", "a bar slot can be cleared")
	check(binds.save() == OK, "bindings save")
	var loaded := Keybinds.new(path)
	loaded.load_saved()
	check(loaded.keys == binds.keys and loaded.bar == binds.bar, "bindings load back")
	var config := ConfigFile.new()
	config.set_value("keys", "slot_1", [KEY_ESCAPE, "x"])
	config.set_value("keys", "slot_2", [KEY_P, KEY_NONE])
	config.set_value("keys", "slot_3", [KEY_P, KEY_NONE])
	config.set_value("bar", "slots", ["fireball"])
	config.save(path)
	var tampered := Keybinds.new(path)
	tampered.load_saved()
	check(tampered.keys["slot_1"] == [KEY_1, KEY_NONE] and tampered.bar == Keybinds.DEFAULT_BAR,
		"malformed saved values fall back to defaults")
	check(tampered.action_for(KEY_P) == "slot_2" and tampered.keys["slot_3"][0] == KEY_NONE, "duplicate saved keys are dropped")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _experience_from(events: Array) -> Dictionary:
	var gained: Dictionary = {}
	for event: Dictionary in events:
		if event["kind"] == "hit" and event["style"] == "experience":
			gained[event["target"]] = gained.get(event["target"], 0) + event["amount"]
	return gained


## Kills a fresh monster next to `cell`; `damage` maps player -> damage dealt (the first deals the blow).
func _party_kill(world: World, combat: Combat, cell: Vector2i, damage: Dictionary, now: float) -> Dictionary:
	var monster: int = combat.spawn_monster("road_bandit", 10, cell, now)
	world.monsters[monster]["damage_by"] = damage.duplicate()
	world.monsters[monster]["health"] = 1
	var events: Array = []
	var killer: int = damage.keys()[0]
	world.monsters[monster]["damage_by"][killer] -= 1
	combat._damage(killer, monster, 1, "damage", now, events)
	return _experience_from(events)


func _party_checks() -> void:
	var world := World.new()
	var combat := Combat.new(world, 21)
	var vocations: Array[String] = ["knight", "paladin", "sorcerer", "druid", "knight"]
	var cells: Array[Vector2i] = []
	var origin: Vector2i = World.SPAWNS[0]
	for radius: int in range(0, 6):
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				var cell: Vector2i = origin + Vector2i(dx, dy)
				if World.walkable(cell) and not cells.has(cell):
					cells.append(cell)
	for id: int in range(1, 6):
		check(world.add_player(id, 0.0, vocations[id - 1]), "party test player joins")
		_place(world, id, cells[id])
	var p: Dictionary = world.players
	# Validation.
	check(not combat.party_action(1, "join", 2, 1.0)["ok"], "joining needs an invitation")
	check(not combat.party_action(1, "invite", 1, 1.0)["ok"] and not combat.party_action(1, "invite", 99, 1.0)["ok"],
		"you cannot invite yourself or unknown players")
	check(not combat.party_action(1, "hug", 2, 1.0)["ok"] and not combat.party_action(1, "invite", "2", 1.0)["ok"]
		and not combat.party_action(1, 7, 2, 1.0)["ok"], "malformed party requests are rejected")
	check(not combat.party_action(1, "leave", 0, 1.0)["ok"], "leaving needs a party")
	check(not combat.party_action(2, "revoke", 1, 1.0)["ok"], "you can only withdraw your own invitations")
	# Invite and join.
	var invite: Dictionary = combat.party_action(1, "invite", 2, 1.0)
	check(invite["ok"] and p[1]["party"] == 0 and world.export_player(2, 1.0, true)["invites"] == [1]
		and world.export_player(1, 1.0, true)["invited"] == [2], "an invitation is private and creates no party yet")
	check(not world.export_player(2, 1.0).has("invites") and world.export_player(2, 1.0)["party"] == 0,
		"others see only party membership")
	var told: bool = false
	for event: Dictionary in invite["events"]:
		told = told or (event["kind"] == "message" and event["id"] == 2)
	check(told, "the invited player is told how to join")
	check(combat.party_action(2, "join", 1, 2.0)["ok"] and p[1]["party"] == 1 and p[2]["party"] == 1
		and p[1]["invited"].is_empty(), "accepting an invitation forms the party under the inviter")
	check(world.export_player(2, 2.0)["party"] == 1, "party membership is public")
	check(not combat.party_action(2, "invite", 3, 2.0)["ok"], "only the leader invites")
	check(combat.party_action(1, "invite", 3, 2.0)["ok"] and combat.party_action(1, "revoke", 3, 2.0)["ok"]
		and not combat.party_action(3, "join", 1, 2.0)["ok"], "a withdrawn invitation cannot be accepted")
	combat.party_action(1, "invite", 3, 3.0)
	combat.party_action(1, "invite", 4, 3.0)
	check(combat.party_action(3, "join", 1, 3.0)["ok"] and combat.party_action(4, "join", 1, 3.0)["ok"]
		and combat.party_members(1) == [1, 2, 3, 4], "the leader can grow the party")
	check(not combat.party_action(5, "invite", 2, 3.0)["ok"], "members of another party cannot be invited")
	# Party members are never hostile, even in a PvP zone.
	check(not combat.hostile(1, 2) and not combat.set_target(1, 2, 3.0)["ok"], "party members cannot attack each other")
	check(combat.same_party(3, 4) and not combat.same_party(1, 5), "party membership is shared")
	# Shared experience: every active nearby member gets an even share with the vocation bonus.
	var now: float = 10.0
	for id: int in range(1, 6):
		p[id]["active_at"] = now
	var experience: int = Balance.mob_experience(10)
	var gained: Dictionary = _party_kill(world, combat, cells[1], {1: 100}, now)
	var each: int = roundi(experience * Combat.SHARE_BONUS[4] / 4.0)
	check(gained.get(1, 0) == each and gained.get(2, 0) == each and gained.get(3, 0) == each and gained.get(4, 0) == each
		and not gained.has(5), "a party of four vocations shares a kill evenly with the full bonus")
	check(Combat.SHARE_BONUS[4] > Combat.SHARE_BONUS[2] and Combat.SHARE_BONUS[2] > Combat.SHARE_BONUS[1],
		"more distinct vocations earn a larger party bonus")
	gained = _party_kill(world, combat, cells[1], {2: 50, 5: 50}, now)
	check(gained.get(5, 0) == roundi(experience * 0.5) and gained.get(1, 0) == roundi(experience * 0.5 * Combat.SHARE_BONUS[4] / 4.0),
		"a party pools only its own members' damage; outsiders keep theirs")
	# A tanking knight who only took hits still counts as active.
	for id: int in range(1, 5):
		p[id]["active_at"] = -INF
	combat._damage(-1, 1, 1, "damage", now, [])
	p[2]["active_at"] = now
	gained = _party_kill(world, combat, cells[1], {2: 100}, now)
	each = roundi(experience * Combat.SHARE_BONUS[2] / 2.0)
	check(gained.get(1, 0) == each and gained.get(2, 0) == each and not gained.has(3) and not gained.has(4),
		"only members active recently share; being hit counts as active")
	p[3]["active_at"] = -INF
	p[3]["health"] = world.player_stats(3)["health"]
	check(combat.cast(3, "light_heal", now)["ok"] and p[3]["active_at"] < 0.0,
		"a self-heal at full health does not count as taking part")
	p[3]["active_at"] = now
	p[4]["active_at"] = now
	_place(world, 4, cells[1] + Vector2i(Combat.SHARE_RANGE + 1, 0))
	check(not combat.sharing_members(1, cells[1], now).has(4), "members far from the kill do not share")
	_place(world, 4, cells[4])
	p[3]["level"] = 30
	gained = _party_kill(world, combat, cells[1], {1: 25, 2: 75}, now)
	check(combat.sharing_members(1, cells[1], now).is_empty() and gained.get(1, 0) == roundi(experience * 0.25)
		and gained.get(2, 0) == roundi(experience * 0.75) and not gained.has(3),
		"a level gap beyond two thirds stops sharing; members keep their own damage share")
	p[3]["level"] = 1
	for id: int in range(1, 5):
		p[id]["level"] = 1
		p[id]["experience"] = 0
	check(combat.sharing_members(1, cells[1], now).size() == 4, "sharing resumes once levels are close")
	# Leaving passes leadership to the lowest id and disbands a party of one.
	combat.party_action(1, "invite", 5, now)
	check(combat.party_action(1, "leave", 0, now)["ok"] and p[1]["party"] == 0 and p[2]["party"] == 2
		and p[3]["party"] == 2 and p[4]["party"] == 2 and world.export_player(5, now, true)["invites"].is_empty(),
		"when the leader leaves, the next member leads and old invitations lapse")
	check(combat.party_action(2, "invite", 1, now)["ok"], "the new leader can invite")
	var events: Array = []
	combat.leave_party(4, events)
	combat.leave_party(3, events)
	check(p[2]["party"] == 0 and p[3]["party"] == 0 and world.export_player(1, now, true)["invites"].is_empty(),
		"a party of one disbands and its invitations lapse")
	# Disconnects withdraw invitations both ways.
	combat.party_action(1, "invite", 2, now)
	combat.party_action(3, "invite", 1, now)
	combat.leave_party(1, [])
	world.remove_player(1)
	check(world.export_player(2, now, true)["invites"].is_empty() and p[3]["invited"].is_empty(),
		"leaving the game withdraws invitations to and from the player")


func _gear_tier_checks() -> void:
	# Coverage: every tier has a helmet, armor, and a weapon and off-hand for each vocation;
	# accessories (amulet, cape, charm, ring) appear only from Items.ACCESSORY_LEVEL.
	var by_key: Dictionary = {}
	for kind: String in World.ITEMS:
		var item: Dictionary = World.ITEMS[kind]
		if item["slot"].is_empty():
			check(item["stats"].is_empty(), "%s is not equipment and has no stats" % kind)
			continue
		check(item["level"] in Items.TIER_LEVELS or (item.has("glow") and item["level"] == Items.RELIC_LEVEL),
			"%s has a tier level (or is a level-50 relic)" % kind)
		if item.has("glow"):
			continue
		if item["slot"] == "bag":
			check(item["stats"].is_empty() and World.bound(kind) and item["slots"] > 0 and kind in Quests.PACKS,
				"%s is a bound quest pack that adds backpack slots" % kind)
			continue
		check(not item["stats"].is_empty(), "%s has stats" % kind)
		if item["slot"] in Items.ACCESSORY_SLOTS:
			check(item["level"] >= Items.ACCESSORY_LEVEL, "%s is a later-stage accessory" % kind)
			check(item["vocations"].is_empty(), "accessories suit every vocation")
		if item["slot"] in ["main_hand", "off_hand"]:
			check(not item["vocations"].is_empty(), "%s belongs to vocations" % kind)
		for vocation: String in (item["vocations"] if not item["vocations"].is_empty() else Balance.VOCATIONS.keys()):
			check(Balance.VOCATIONS.has(vocation), "%s names a known vocation" % kind)
			var key: String = "%s/%s/%d" % [item["slot"], vocation, item["level"]]
			by_key[key] = by_key.get(key, []) + [kind]
	for level: int in Items.TIER_LEVELS:
		for vocation: String in Balance.VOCATIONS:
			var slots: Array[String] = ["helmet", "armor", "main_hand", "off_hand"]
			if level >= Items.ACCESSORY_LEVEL:
				slots.append_array(Items.ACCESSORY_SLOTS)
			for slot: String in slots:
				check(by_key.get("%s/%s/%d" % [slot, vocation, level], []).size() == 1,
					"exactly one %s for a level-%d %s" % [slot, level, vocation])
	# Each tier is an upgrade, and weapons keep a geared player near six hits per same-level kill.
	for vocation: String in Balance.VOCATIONS:
		var previous: Dictionary = {}
		for level: int in Items.TIER_LEVELS:
			for slot: String in ["helmet", "armor", "main_hand", "off_hand"]:
				var stats: Dictionary = World.ITEMS[by_key["%s/%s/%d" % [slot, vocation, level]][0]]["stats"]
				var total: int = 0
				for stat: String in stats:
					total += stats[stat]
				check(total > previous.get(slot, 0), "a tier-%d %s beats the tier below" % [level, slot])
				previous[slot] = total
			if vocation == Balance.DEFAULT_VOCATION:
				var weapon: Dictionary = {"main_hand": by_key["main_hand/%s/%d" % [vocation, level]][0]}
				for at: int in [level, mini(level + 4, Balance.MAX_LEVEL)]:
					var hits: int = ceili(Balance.mob_health(at) / float(World.stats(at, weapon, vocation)["attack"]))
					check(hits >= 5 and hits <= 7, "a tier-%d weapon needs about six hits at level %d" % [level, at])
	check(Items.set_defense(1) == Items.SET_DEFENSE_LOW and is_equal_approx(Items.set_defense(45), Items.SET_DEFENSE_HIGH),
		"set defense spans the tiers")
	check(Items.tier_for(1) == 1 and Items.tier_for(4) == 1 and Items.tier_for(5) == 5 and Items.tier_for(50) == 45,
		"levels map to tiers")
	_relic_checks(by_key)
	# Requirements, on the server.
	check(World.requirement_error("willow_shortbow", 50, "knight") == "Only Paladins can use the Willow shortbow",
		"weapons are vocation-bound")
	check(World.requirement_error("kindling_wand", 1, "sorcerer").is_empty() \
		and World.requirement_error("tattered_primer", 1, "druid").is_empty(), "casters use wands, rods, and spellbooks")
	check(World.requirement_error("oak_buckler", 1, "sorcerer") == "Only Knights and Paladins can use the Oak buckler",
		"shields are for Knights and Paladins")
	check(World.requirement_error("bronze_helm", 9, "knight") == "The Bronze helm requires level 10"
		and World.requirement_error("bronze_helm", 10, "knight").is_empty(), "the level requirement boundary")
	var world := World.new()
	world.add_player(1, 0.0, "knight")
	var knight: Dictionary = world.players[1]
	knight["backpack"][4] = "willow_shortbow"
	knight["backpack"][5] = "bronze_mace"
	var refused: Dictionary = world.move_item(1, {"type": "backpack", "index": 4}, {"type": "equipment", "slot": "main_hand"}, 1.0)
	check(not refused["ok"] and refused["reason"].begins_with("Only Paladins") and knight["backpack"][4] == "willow_shortbow",
		"a Knight cannot equip a bow")
	check(world.toggle_equipment(1, "main_hand", 2.0)["ok"] and knight["equipment"]["main_hand"] == "copper_blade",
		"the equip key picks a usable weapon")
	check(world.move_item(1, {"type": "backpack", "index": 5}, {"type": "equipment", "slot": "main_hand"}, 3.0)["reason"]
		== "The Bronze mace requires level 10", "a low-level Knight cannot equip a tier-10 mace")
	check(world.move_item(1, {"type": "equipment", "slot": "main_hand"}, {"type": "backpack", "index": 5}, 4.0)["reason"]
		== "The Bronze mace requires level 10" and knight["equipment"]["main_hand"] == "copper_blade",
		"swapping cannot sneak an unusable item into a slot")
	# Tier drops.
	var drops := Combat.new(World.new(), 13)
	var seen_lower: bool = false
	for roll: int in 400:
		var low: Dictionary = World.ITEMS[drops.gear_drop(3)]
		check(low["level"] == 1 and low["slot"] not in Items.ACCESSORY_SLOTS, "level-3 monsters drop tier-1 gear")
		var high: Dictionary = World.ITEMS[drops.gear_drop(23)]
		check(high["level"] in [15, 20], "level-23 monsters drop tier-20 gear, sometimes tier 15")
		seen_lower = seen_lower or high["level"] == 15
	check(seen_lower, "some drops come from the tier below")
	var elite_gear: int = 0
	for roll: int in 400:
		for entry: String in drops.roll_loot("blackreed_warden", 45):
			elite_gear += 1 if not World.ITEMS[World.kind_of(entry)]["slot"].is_empty() else 0
	check(elite_gear > 70 and elite_gear < 130, "elites drop gear about a quarter of the time")
	for kind: String in Monsters.MONSTERS:
		for slot: String in Monsters.MONSTERS[kind].get("gear", {}):
			check(World.fits(Monsters.MONSTERS[kind]["gear"][slot], slot), "%s wears catalog gear" % kind)


## Glowing relics: level-50 gear that only final bosses drop, one boss per relic.
func _relic_checks(by_key: Dictionary) -> void:
	var relics: Array[String] = []
	for kind: String in World.ITEMS:
		if World.ITEMS[kind].has("glow"):
			relics.append(kind)
	check(relics.size() == 17, "seventeen relics")
	var bosses: Array[String] = []
	for kind: String in Monsters.MONSTERS:
		if Monsters.MONSTERS[kind]["rank"] == "boss":
			bosses.append(kind)
	check(bosses.size() == 4, "three final bosses and the Hollow Reach's ultimate boss")
	var source: Dictionary = {}
	for monster: String in Monsters.LOOT:
		for entry: Array in Monsters.LOOT[monster]:
			check(not World.bound(entry[0]), "relics are quest rewards, never monster loot (%s)" % entry[0])
	for boss: String in bosses:
		for relic: String in Monsters.MONSTERS[boss].get("relics", []):
			source[relic] = source.get(relic, []) + [boss]
	for kind: String in relics:
		var item: Dictionary = World.ITEMS[kind]
		check(source.get(kind, []).size() == 1 and Combat.relic_boss(kind) == source[kind][0],
			"%s is the reward of exactly one boss quest" % kind)
		check(World.bound(kind), "%s is bound" % kind)
		check(item["level"] == Items.RELIC_LEVEL and not item["slot"].is_empty(), "%s is level-50 equipment" % kind)
		if item["slot"] in SpriteArt.VISIBLE_SLOTS:
			check(SpriteArt.GEAR_GLOW.has(kind) and SpriteArt.GEAR_GLOW[kind].get_size() == SpriteArt.GEAR[kind].get_size(),
				"%s has a worn glow sheet" % kind)
		var vocation: String = item["vocations"][0] if not item["vocations"].is_empty() else "knight"
		var best: Array = by_key.get("%s/%s/%d" % [item["slot"], vocation, Items.TIER_LEVELS[-1]], [])
		var relic_total: int = 0
		var tier_total: int = 0
		for stat: String in item["stats"]:
			relic_total += item["stats"][stat]
		for stat: String in World.ITEMS[best[0]]["stats"]:
			tier_total += World.ITEMS[best[0]]["stats"][stat]
		check(relic_total > tier_total, "%s beats the best tiered %s" % [kind, item["slot"]])
	for boss: String in bosses:
		var definition: Dictionary = Monsters.MONSTERS[boss]
		check(definition.get("relics", []).size() >= 4, "%s's quest offers at least four relics" % boss)
		check(definition.get("respawn", 0.0) >= 600.0, "%s respawns slowly" % boss)
		check(definition.has("glow") or definition["look"] == "humanoid", "%s glows (itself or through its gear)" % boss)
		var placed: Array = World.MONSTER_SPAWNS.filter(func(spawn: Dictionary) -> bool: return spawn["monster"] == boss)
		check(placed.size() == 1 and placed[0]["level"] == Balance.MAX_LEVEL and placed[0]["count"] == 1,
			"%s has one level-50 lair on the map" % boss)
		var world := World.new()
		var combat := Combat.new(world, 3)
		world.monsters.clear()
		var id: int = combat.spawn_monster(boss, 50, placed[0]["cell"], 0.0, World.MONSTER_SPAWNS.find(placed[0]))
		check(world.monsters[id]["max_health"] == Balance.FINAL_BOSS_HEALTH, "%s has final-boss health" % boss)
		combat._damage(-1, id, 10000000, "damage", 1.0, [])
		check(combat.respawns.size() == 1 and is_equal_approx(combat.respawns[0][0], 1.0 + definition["respawn"]),
			"%s waits its own respawn time" % boss)
	check(not World.ITEMS[Combat.new(World.new(), 5).gear_drop(50)].has("glow"), "tier drops never give relics")
	_relic_quest_checks()
	_endgame_zone_checks()
	_raid_mechanic_checks()


## Final-boss raid mechanics: engage message, raid-wide pulses, wound stacks and the Challenge
## tank swap, enrage, and the reset when the raid leaves.
func _raid_mechanic_checks() -> void:
	var world := World.new()
	var combat := Combat.new(world, 17)
	world.monsters.clear()
	var lair: Vector2i = World.MONSTER_SPAWNS.filter(func(spawn: Dictionary) -> bool: return spawn["monster"] == "vaelith")[0]["cell"]
	for id: int in [1, 2, 3]:
		world.add_player(id, 0.0, ["knight", "knight", "druid"][id - 1])
		world.players[id]["level"] = 50
		world.clamp_vitals(id)
		world.players[id]["health"] = 999999
	_place(world, 1, lair + Vector2i(-1, 0))
	_place(world, 2, lair + Vector2i(0, -1))
	_place(world, 3, lair + Vector2i(-4, 0))
	world.add_player(4, 0.0, "paladin")
	_place(world, 4, lair + Vector2i(-Combat.PULSE_RADIUS - 3, 0))
	world.players[4]["health"] = 999999
	var boss: int = combat.spawn_monster("vaelith", 50, lair, 0.0)
	var monster: Dictionary = world.monsters[boss]
	monster["next_move"] = INF
	var events: Array = []
	combat._monster_tick(boss, 1.0, events)
	var awoke: bool = false
	for event: Dictionary in events:
		awoke = awoke or (event["kind"] == "message" and String(event["text"]).contains("awakens"))
	check(monster["engaged_at"] == 1.0 and awoke, "a boss announces the fight when it engages")
	var pulse: int = Combat.pulse_damage(50)
	var raid: int = 0
	for vocation: String in Balance.RAID:
		raid += Balance.RAID[vocation]
	check(is_equal_approx(pulse * raid / Combat.PULSE_SECONDS, Balance.BOSS_HEALING_PRESSURE * Balance.base_stats(50, "druid")["healing"])
		or absf(pulse * raid / Combat.PULSE_SECONDS - Balance.BOSS_HEALING_PRESSURE * Balance.base_stats(50, "druid")["healing"]) < 5.0,
		"pulses add up to the raid's healing pressure")
	var before: Dictionary = {}
	for id: int in [1, 2, 3, 4]:
		before[id] = world.players[id]["health"]
	monster["next_attack"] = INF
	combat._boss_tick(boss, 1.0 + Combat.PULSE_SECONDS - 0.01, [])
	check(world.players[3]["health"] == before[3], "no pulse before its interval")
	combat._boss_tick(boss, 1.0 + Combat.PULSE_SECONDS, [])
	check(before[3] - world.players[3]["health"] == pulse and before[1] - world.players[1]["health"] == pulse,
		"a pulse hits every player near the boss, ignoring defense")
	check(world.players[4]["health"] == before[4], "players beyond the pulse radius are spared")
	# Wounds: repeated boss hits on one tank grow; another Knight's Challenge takes over.
	monster["target"] = 1
	var hits: Array[int] = []
	for hit: int in 4:
		var health: int = world.players[1]["health"]
		combat.rng.seed = 99
		combat._hit(boss, 1, 1.0, 10.0 + hit, [])
		hits.append(health - world.players[1]["health"])
	check(hits[3] > hits[0] * 1.6 and combat.wound_stacks(boss, 1, 13.5) == 4, "wound stacks make each boss hit on a tank harder")
	check(combat.wound_stacks(boss, 1, 13.0 + Combat.WOUND_SECONDS + 0.1) == 0, "wounds fade once the boss stops hitting you")
	world.players[2]["mana"] = 999999
	check(combat.cast(2, "challenge", 20.0)["ok"] and monster["target"] == 2, "Challenge pulls the boss onto the second Knight")
	check(not combat.cast(3, "challenge", 20.0)["ok"], "only Knights can Challenge")
	# Enrage.
	combat._boss_tick(boss, 1.0 + Balance.ENRAGE_SECONDS - 0.5, [])
	check(not monster["enraged"], "no enrage before its time")
	var enrage_events: Array = []
	combat._boss_tick(boss, 1.0 + Balance.ENRAGE_SECONDS, enrage_events)
	var announced: bool = false
	for event: Dictionary in enrage_events:
		announced = announced or (event["kind"] == "message" and String(event["text"]).contains("enrages"))
	check(monster["enraged"] and announced and combat.export_monster(boss, 300.0)["enraged"], "the boss enrages on time, visibly")
	check(is_equal_approx(combat.attack_of(boss), Balance.mob_damage(50, "boss") * Combat.ENRAGE_MULTIPLIER),
		"an enraged boss hits ten times as hard")
	# Everyone leaves: the boss heals and forgets the fight.
	for id: int in [1, 2, 3, 4]:
		world.remove_player(id)
	monster["health"] = 1000
	combat._monster_tick(boss, 400.0, [])
	check(monster["target"] == 0 and monster["engaged_at"] < 0.0 and not monster["enraged"] and monster["wounds"].is_empty()
		and monster["health"] == monster["max_health"], "an abandoned boss heals and resets its timer, wounds, and enrage")


## The Hollow Reach: a level 45-50 PvP zone walled in obsidian, entered through one gate, with the
## ultimate boss in the Sanctum's throne room at the end of a walkable corridor.
func _endgame_zone_checks() -> void:
	var zone: Dictionary = {}
	for candidate: Dictionary in World.ZONES:
		if candidate["name"] == "The Hollow Reach":
			zone = candidate
	check(not zone.is_empty() and zone["pvp"] and zone["full_loot"] and zone["min_level"] == 45 and zone["max_level"] == 50,
		"the Hollow Reach is a high-risk (full-loot) level 45-50 PvP zone")
	for other: Dictionary in World.ZONES:
		if other["name"] != "The Hollow Reach":
			check(not other["full_loot"], "%s keeps the normal 10%% worn-item loss" % other["name"])
	if zone.is_empty():
		return
	var area: Rect2i = zone["rect"]
	var gates: int = 0
	var themed: int = 0
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var tile: String = World.terrain(Vector2i(x, y))
			themed += 1 if tile in "doOD" else 0
			var edge: bool = x == area.position.x or y == area.position.y or x == area.end.x - 1 or y == area.end.y - 1
			if edge and World.walkable(Vector2i(x, y)):
				gates += 1
	check(themed == area.get_area(), "the whole zone uses the dark obsidian theme")
	check(gates > 0 and gates <= 5, "the obsidian wall has a single narrow gate")
	var throne: Dictionary = World.MONSTER_SPAWNS.filter(func(spawn: Dictionary) -> bool: return spawn["monster"] == "vaelith")[0]
	check(area.has_point(throne["cell"]) and World.terrain(throne["cell"]) == "o", "Vaelith sits on the Sanctum floor")
	for spawn: Dictionary in World.MONSTER_SPAWNS:
		if area.has_point(spawn["cell"]):
			check(spawn["level"] >= 45 and World.walkable(spawn["cell"]), "Hollow Reach spawns are level 45+ on open floor")
	# On foot from Cinder Crossing to the throne: the path enters through the gate.
	var seen: Dictionary = {World.SPAWNS[0]: true}
	var frontier: Array[Vector2i] = [World.SPAWNS[0]]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + step
			if not seen.has(next) and World.walkable(next):
				seen[next] = true
				frontier.append(next)
	check(seen.has(throne["cell"]), "the throne room is reachable on foot from Cinder Crossing")
	var line_blocked: bool = not Combat.line_of_sight(Vector2i(area.position.x - 2, area.position.y + 4),
		Vector2i(area.position.x + 2, area.position.y + 4))
	check(line_blocked and not World.walkable(Vector2i(area.position.x, area.position.y + 4)),
		"obsidian walls block movement and line of sight")
	check(World.walkable(Vector2i(area.position.x + 3, area.position.y + 3)) or World.terrain(Vector2i(area.position.x + 3, area.position.y + 3)) == "D",
		"dusk soil is walkable; dead trees block")
	# Full loot: dying inside drops every worn item and the backpack, but never a bound relic.
	var world := World.new()
	var combat := Combat.new(world, 31)
	world.monsters.clear()
	world.add_player(1, 0.0, "paladin")
	var victim: Dictionary = world.players[1]
	var inside: Vector2i = throne["cell"] + Vector2i(-4, 0)
	_place(world, 1, inside)
	victim["level"] = 50
	victim["equipment"] = {"helmet": "wyrmglass_greathelm", "armor": "wyrmglass_plate", "off_hand": "wyrmglass_ward",
		"necklace": "wyrmglass_amulet", "ring_1": "wyrmglass_ring", "main_hand": "eclipse_bow"}
	victim["backpack"][7] = "abyssal_greathelm"
	victim["gold"] = 50
	var events: Array = []
	combat._damage(-1, 1, 99999999, "damage", 10.0, events)
	check(victim["equipment"] == {"main_hand": "eclipse_bow"} and victim["backpack"].count("") == World.BACKPACK_SIZE - 1
		and victim["backpack"][7] == "abyssal_greathelm", "dying in the Hollow Reach drops all worn gear but keeps relics")
	var dropped: Array = []
	for cell: Vector2i in world.ground:
		dropped.append_array(world.ground[cell])
	for kind: String in ["wyrmglass_greathelm", "wyrmglass_plate", "wyrmglass_ward", "wyrmglass_amulet", "wyrmglass_ring"]:
		check(kind in dropped, "%s drops in the Hollow Reach" % kind)
	var message: String = ""
	for event: Dictionary in events:
		if event["kind"] == "message" and event["id"] == 1:
			message = event["text"]
	check(message.contains("Wyrmglass plate") and message.contains("your backpack"), "the death message lists everything lost")


## Trophy credit on a boss kill, claiming at the Relic keeper, and bound relics.
func _relic_quest_checks() -> void:
	check(World.QUEST_GIVERS.has("relic_keeper") and "quests" in World.npc("relic_keeper")["services"],
		"the Relic keeper offers quests")
	var keeper: Vector2i = World.QUEST_GIVERS["relic_keeper"]["cell"]
	check(not World.walkable(keeper) and World.NPC_CELLS.get(keeper, "") == "relic_keeper", "the Relic keeper blocks her tile")
	var world := World.new()
	var combat := Combat.new(world, 8)
	world.monsters.clear()
	var lair: Vector2i = World.MONSTER_SPAWNS.filter(func(spawn: Dictionary) -> bool: return spawn["monster"] == "morvain")[0]["cell"]
	for id: int in [1, 2, 3, 4]:
		world.add_player(id, 0.0, ["knight", "druid", "sorcerer", "paladin"][id - 1])
	_place(world, 1, lair + Vector2i(1, 0))
	_place(world, 2, lair + Vector2i(1, 3))
	_place(world, 3, lair + Vector2i(-4, 0))
	_place(world, 4, keeper + Vector2i(0, 1))
	var boss: int = combat.spawn_monster("morvain", 50, lair, 0.0)
	# Player 1 tanks (is hit) and attacks; player 2 heals player 1; player 3 stands nearby
	# self-healing at full health every so often; player 4 is far away.
	world.players[1]["level"] = 50
	world.players[2]["level"] = 50
	world.players[1]["health"] = world.player_stats(1)["health"]
	combat._damage(boss, 1, 500, "damage", 98.0, [])
	world.players[2]["mana"] = 999999
	check(combat.cast(2, "mass_mend", 99.0)["ok"], "the healer heals the wounded tank")
	world.players[3]["mana"] = 999999
	world.players[3]["active_at"] = 99.0
	combat.cast(3, "light_heal", 99.0)
	world.players[4]["active_at"] = 99.0
	var events: Array = []
	combat._damage(1, boss, 10000000, "damage", 100.0, events)
	check(world.players[1]["trophies"] == {"morvain": 1}, "the boss's attackers and tanks earn a trophy")
	check(world.players[2]["trophies"] == {"morvain": 1}, "a healer who healed a fighter earns a trophy")
	check(world.players[3]["trophies"].is_empty() and world.players[4]["trophies"].is_empty(),
		"bystanders earn nothing, even nearby and self-healing")
	check(world.export_player(1, 100.0, true)["trophies"] == {"morvain": 1} and not world.export_player(1, 100.0).has("trophies"),
		"trophies are private")
	var ground: int = 0
	for cell: Vector2i in world.ground:
		for kind: String in world.ground[cell]:
			check(not World.bound(kind), "bosses drop no relics")
			ground += 1
	check(ground > 0, "bosses still drop gold")
	# Claiming.
	world.players[4]["trophies"] = {"kharzul": 1}
	check(combat.claim_relic(1, "relic_keeper", "tidebreaker", 101.0)["reason"] == "Walk closer to Ysolde", "claiming needs the keeper nearby")
	check(combat.claim_relic(4, "cinder_landing", "cinderheart_bow", 101.0)["reason"] == "Unknown quest giver"
		and combat.claim_relic(4, 7, "cinderheart_bow", 101.0)["reason"] == "Unknown quest giver", "only quest givers trade relics")
	check(combat.claim_relic(4, "relic_keeper", "tidebreaker", 101.0)["reason"] == "Slay Morvain the Drowned first",
		"a trophy only buys that boss's relics")
	check(combat.claim_relic(4, "relic_keeper", "ember_cap", 101.0)["reason"] == "Unknown relic"
		and combat.claim_relic(4, "relic_keeper", null, 101.0)["reason"] == "Unknown relic", "malformed relic requests are rejected")
	var backpack: Array = world.players[4]["backpack"]
	var saved: Array = backpack.duplicate()
	backpack.fill("glowcap")
	check(combat.claim_relic(4, "relic_keeper", "cinderheart_bow", 101.0)["reason"] == "Your backpack is full"
		and world.players[4]["trophies"] == {"kharzul": 1}, "a full backpack keeps the trophy")
	backpack.assign(saved)
	var claimed: Dictionary = combat.claim_relic(4, "relic_keeper", "cinderheart_bow", 101.0)
	check(claimed["ok"] and backpack.has("cinderheart_bow") and world.players[4]["trophies"].is_empty(),
		"a trophy becomes the relic of your choice")
	check(combat.claim_relic(4, "relic_keeper", "molten_heart", 102.0)["reason"] == "Slay Kharzul the Cinder Colossus first",
		"each trophy is spent once")
	# Bound: no dropping, no losing on death.
	var player: Dictionary = world.players[4]
	player["level"] = 50
	var index: int = backpack.find("cinderheart_bow")
	check(world.move_item(4, {"type": "backpack", "index": index}, {"type": "ground", "cell": player["cell"]}, 103.0)["reason"]
		== "The Cinderheart bow is bound to you", "relics cannot be dropped")
	check(world.move_item(4, {"type": "backpack", "index": index}, {"type": "equipment", "slot": "main_hand"}, 104.0)["ok"],
		"a level-50 Paladin wields the relic bow")
	world.ground[player["cell"]] = ["yew_hunting_bow"]
	check(world.move_item(4, {"type": "ground", "cell": player["cell"]}, {"type": "equipment", "slot": "main_hand"}, 105.0)["reason"]
		== "The Cinderheart bow is bound to you", "equipping from the ground cannot push a relic onto the ground")
	world.ground.clear()
	player["skull"] = "red"
	combat._damage(-1, 4, 99999999, "damage", 106.0, [])
	check(player["equipment"].get("main_hand", "") == "cinderheart_bow", "relics are never lost on death, even with a red skull")


## A free walkable tile next to an NPC (within talking range).
func _beside(npc: String) -> Vector2i:
	var cell: Vector2i = World.npc(npc)["cell"]
	for step: Vector2i in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i(1, 1), Vector2i(-1, 1)]:
		if World.walkable(cell + step):
			return cell + step
	return cell


## Vendors, bankers and the depot, town hunting tasks and packs, and potions.
func _town_checks() -> void:
	# Every town has a vendor and a banker; NPCs block their tile and can be reached.
	var towns: Dictionary = {}
	for zone: Dictionary in World.ZONES:
		if zone["town"]:
			towns[zone["name"]] = []
	for id: String in World.TOWNSFOLK:
		var person: Dictionary = World.TOWNSFOLK[id]
		check(towns.has(person["place"]) and World.zone_at(person["cell"]).get("name", "") == person["place"],
			"%s stands in the safe zone of %s" % [person["name"], person["place"]])
		towns.get(person["place"], []).append(person["role"])
		check(World.NPC_CELLS.get(person["cell"], "") == id and not World.walkable(person["cell"]), "%s blocks its tile" % id)
		check(_beside(id) != person["cell"], "%s can be reached" % id)
		check(person["services"] == (["bank"] if person["role"] == "banker" else ["trade"]), "%s offers its service" % id)
	for town: String in towns:
		check("vendor" in towns[town] and "banker" in towns[town], "%s has a vendor and a banker" % town)
	var givers: Dictionary = {}
	for id: String in World.QUEST_GIVERS:
		var task: String = World.QUEST_GIVERS[id]["task"]
		if not task.is_empty():
			check(Quests.TASKS.has(task), "%s gives a known task" % id)
			check(World.zone_at(World.QUEST_GIVERS[id]["cell"]).get("town", false), "%s stands in a town" % id)
			givers[task] = id
	for task: String in Quests.TASKS:
		check(givers.has(task), "%s has a quest giver" % task)
		var monster: String = Quests.TASKS[task]["monster"]
		check(not World.MONSTER_SPAWNS.filter(func(spawn: Dictionary) -> bool: return spawn["monster"] == monster).is_empty(),
			"%s hunts a monster that spawns" % task)
	check(Quests.TASKS.size() == Quests.PACKS.size(), "one pack per town task")
	var last_slots: int = World.BACKPACK_SIZE
	for pack: String in Quests.PACKS:
		var slots: int = World.BACKPACK_SIZE + World.ITEMS[pack]["slots"]
		check(slots > last_slots and slots <= World.BACKPACK_MAX, "each pack is bigger than the last")
		last_slots = slots
	check(last_slots == World.BACKPACK_MAX, "the largest pack fills the backpack")
	check(Quests.next_pack("") == Quests.PACKS[0] and Quests.next_pack(Quests.PACKS[-1]).is_empty(), "packs upgrade in order")

	# Stock and prices.
	var stock: Array[String] = Economy.stock()
	check(stock.has("health_potion") and stock.has("mana_potion"), "vendors sell potions")
	for kind: String in stock:
		var item: Dictionary = World.ITEMS[kind]
		check(item["price"] > 0 and not World.bound(kind) and item["level"] <= Economy.MAX_TIER, "%s is levelling stock" % kind)
		if not item["slot"].is_empty():
			check(Economy.sell_price(kind) > 0 and Economy.sell_price(kind) < item["price"], "%s sells back for less" % kind)
	for vocation: String in Balance.VOCATIONS:
		for tier: int in [1, 5, 10]:
			for slot: String in Economy.GEAR_SLOTS:
				check(not stock.filter(func(kind: String) -> bool: return World.ITEMS[kind]["slot"] == slot \
					and World.ITEMS[kind]["level"] == tier and World.requirement_error(kind, tier, vocation).is_empty()).is_empty(),
					"vendors sell a tier-%d %s for %ss" % [tier, slot, vocation])
	check(World.ITEMS["copper_blade"]["price"] < World.ITEMS["flint_hatchet"]["price"]
		and World.ITEMS["flint_hatchet"]["price"] < World.ITEMS["bronze_mace"]["price"], "gear prices rise with the tier")
	check(World.ITEMS["ember_cap"]["price"] <= World.START_GOLD, "a new character can afford a tier-1 piece")
	for kind: String in ["abyssal_greathelm", "traveler_pack", "gold_coins"]:
		check(Economy.sell_price(kind) == 0 and kind not in stock, "%s is neither bought nor sold" % kind)
	check(Economy.sell_price("health_potion") == 0, "vendors do not buy potions back")
	check(Economy.sell_price("wolf_pelt") == World.ITEMS["wolf_pelt"]["value"], "materials sell for their value")
	check(World.bound("traveler_pack") and Combat.new(World.new(), 4).gear_drop(1) not in Quests.PACKS, "packs are bound and never drop")
	for roll: int in 200:
		check(not World.bound(Combat.new(World.new(), roll + 1).gear_drop(1)), "monsters never drop bound items")

	var world := World.new()
	var combat := Combat.new(world, 21)
	var economy := Economy.new(world)
	world.monsters.clear()
	check(world.add_player(1, 0.0, "knight") and world.add_player(2, 0.0, "druid"), "town players")
	var player: Dictionary = world.players[1]
	var backpack: Array = player["backpack"]
	var vendor: String = "cinder_vendor"
	var banker: String = "cinder_banker"
	check(World.TOWNSFOLK.has(vendor) and World.TOWNSFOLK.has(banker), "Cinder Crossing has a vendor and a banker")
	var clock: Array[float] = [10.0]
	var tick := func() -> float:
		clock[0] += 1.0
		return clock[0]
	for index: int in backpack.size():
		backpack[index] = ""
	player["gold"] = 1000

	# Buying.
	_place(world, 1, Vector2i(5, 6))
	check(economy.buy(1, vendor, "health_potion", 1, tick.call())["reason"] == "Walk closer to a vendor", "vendors need you nearby")
	_place(world, 1, _beside(vendor))
	check(economy.buy(1, banker, "health_potion", 1, tick.call())["reason"] == "Walk closer to a vendor", "bankers do not trade")
	for bad: Array in [[null, 1], [5, 1], ["abyssal_greathelm", 1], ["steel_hauberk", 1], ["health_potion", 0],
			["health_potion", 101], ["health_potion", "1"], ["health_potion", 1.0], ["copper_blade", 2], ["nope", 1]]:
		check(not economy.buy(1, vendor, bad[0], bad[1], tick.call())["ok"], "malformed or unstocked purchase rejected: %s" % [bad])
	check(player["gold"] == 1000 and backpack.count("") == backpack.size(), "rejected purchases change nothing")
	var bought: Dictionary = economy.buy(1, vendor, "health_potion", 10, tick.call())
	check(bought["ok"] and backpack[0] == "health_potion#10" and player["gold"] == 800, "buying potions")
	check(economy.buy(1, vendor, "health_potion", 5, clock[0] + 0.01)["reason"] == "Item cooldown", "trading has the item cooldown")
	check(economy.buy(1, vendor, "health_potion", 5, tick.call())["ok"] and backpack[0] == "health_potion#15"
		and backpack[1] == "", "potions merge into one stack")
	check(economy.buy(1, vendor, "copper_blade", 1, tick.call())["ok"] and backpack[1] == "copper_blade"
		and player["gold"] == 700 - World.ITEMS["copper_blade"]["price"], "buying gear")
	player["gold"] = 100
	check(economy.buy(1, vendor, "bronze_mace", 1, tick.call())["reason"].begins_with("You need") and player["gold"] == 100
		and not backpack.has("bronze_mace"), "gold is checked")
	player["gold"] = 650
	for index: int in backpack.size():
		if backpack[index].is_empty():
			backpack[index] = "glowcap"
	check(economy.buy(1, vendor, "mana_potion", 1, tick.call())["reason"] == "Your backpack is full", "full backpack refuses")
	check(economy.buy(1, vendor, "health_potion", 1, tick.call())["ok"], "a stack with room still takes potions")

	# Selling.
	backpack[2] = "wolf_pelt#10"
	backpack[3] = "boar_tusk#2"
	backpack[4] = "abyssal_greathelm"
	var gold: int = player["gold"]
	check(economy.sell(1, vendor, 1, tick.call())["ok"] and backpack[1] == ""
		and player["gold"] == gold + Economy.sell_price("copper_blade"), "selling gear")
	check(economy.sell(1, vendor, 4, tick.call())["reason"].contains("will not buy") and backpack[4] == "abyssal_greathelm",
		"relics cannot be sold")
	check(economy.sell(1, vendor, 0, tick.call())["reason"].contains("will not buy"), "potions cannot be sold")
	for bad: Variant in [null, "2", 2.0, -2, backpack.size(), 1]:
		check(not economy.sell(1, vendor, bad, tick.call())["ok"], "malformed or empty sale rejected")
	gold = player["gold"]
	var materials: int = 10 * World.ITEMS["wolf_pelt"]["value"] + 2 * World.ITEMS["boar_tusk"]["value"] \
		+ backpack.count("glowcap") * 0
	check(economy.sell(1, vendor, -1, tick.call())["ok"] and backpack[2] == "" and backpack[3] == ""
		and player["gold"] == gold + materials and backpack[0].begins_with("health_potion"), "selling every material")
	check(economy.sell(1, vendor, -1, tick.call())["reason"] == "You carry no monster materials", "nothing left to sell")

	# Banking.
	gold = player["gold"]
	check(economy.bank(1, banker, "deposit", 10, tick.call())["reason"] == "Walk closer to a banker", "bankers need you nearby")
	_place(world, 1, _beside(banker))
	for bad: Array in [["steal", 10], ["deposit", 0], ["deposit", -5], ["deposit", "10"], [null, 10], ["deposit", gold + 1],
			["withdraw", 1]]:
		check(not economy.bank(1, banker, bad[0], bad[1], tick.call())["ok"], "malformed bank request rejected: %s" % [bad])
	check(economy.bank(1, vendor, "deposit", 10, tick.call())["reason"] == "Walk closer to a banker", "vendors do not bank")
	check(economy.bank(1, banker, "deposit", 300, tick.call())["ok"] and player["bank"] == 300 and player["gold"] == gold - 300,
		"depositing gold")
	check(economy.bank(1, banker, "withdraw", 100, tick.call())["ok"] and player["bank"] == 200 and player["gold"] == gold - 200,
		"withdrawing gold")
	check(world.export_player(1, 0.0, true)["bank"] == 200 and not world.export_player(1, 0.0).has("bank"), "the bank balance is private")

	# The depot.
	var slot0: Dictionary = {"type": "backpack", "index": 0}
	var depot0: Dictionary = {"type": "depot", "index": 0}
	check(world.move_item(1, slot0, {"type": "depot"}, tick.call())["ok"] and player["depot"][0].begins_with("health_potion")
		and backpack[0] == "", "depositing an item")
	check(world.move_item(1, {"type": "backpack", "index": 5}, {"type": "depot"}, tick.call())["ok"]
		and player["depot"][1] == "glowcap", "auto deposit uses the next free slot")
	check(world.move_item(1, {"type": "backpack", "index": 6}, {"type": "depot"}, tick.call())["ok"]
		and player["depot"][1] == "glowcap#2", "auto deposit merges stacks")
	check(world.move_item(1, {"type": "backpack", "index": 4}, depot0, tick.call())["ok"] and player["depot"][0] == "abyssal_greathelm"
		and backpack[4].begins_with("health_potion"), "bound relics can be stored and depot moves swap")
	check(world.move_item(1, depot0, {"type": "equipment", "slot": "helmet"}, tick.call())["reason"].contains("through your backpack")
		and world.move_item(1, depot0, {"type": "ground", "cell": player["cell"]}, tick.call())["reason"].contains("through your backpack"),
		"the depot only trades with the backpack")
	for bad: Variant in [{"type": "depot", "index": World.DEPOT_SIZE}, {"type": "depot", "index": -1}, {"type": "depot", "index": "0"},
			{"type": "depot", "index": 0, "x": 1}]:
		check(world.move_item(1, bad, slot0, tick.call())["reason"] == "Unknown item location", "malformed depot location rejected")
	check(world.export_player(1, 0.0, true)["depot"] == player["depot"] and not world.export_player(1, 0.0).has("depot"),
		"the depot is private")
	_place(world, 1, Vector2i(5, 6))
	check(world.move_item(1, depot0, slot0, tick.call())["reason"] == "Your depot is kept by the town bankers", "depot needs a banker")
	_place(world, 1, _beside("ashford_banker"))
	check(world.move_item(1, depot0, {"type": "backpack"}, tick.call())["ok"] and player["depot"][0] == ""
		and backpack.has("abyssal_greathelm"), "every banker opens the same depot")

	# Death keeps the bank, the depot, and bound packs.
	var victim: Dictionary = world.players[2]
	victim["level"] = Combat.PROTECTION_LEVEL + 2
	world.wear_pack(2, "traveler_pack")
	victim["bank"] = 500
	victim["depot"][3] = "wolf_pelt#4"
	victim["gold"] = 50
	_place(world, 2, Vector2i(9, 12))
	combat._damage(-1, 2, 9999999, "damage", tick.call(), [])
	check(victim["bank"] == 500 and victim["depot"][3] == "wolf_pelt#4" and victim["equipment"].get("bag", "") == "traveler_pack"
		and victim["backpack"].size() == World.BACKPACK_SIZE + 4 and victim["gold"] == 0, "death keeps the bank, depot, and pack")

	# Packs: the bag slot cannot be moved, and backpack slots past your pack are locked.
	for index: int in backpack.size():
		backpack[index] = ""
	check(backpack.size() == World.BACKPACK_SIZE, "no pack means eight slots")
	check(world.move_item(1, {"type": "backpack", "index": World.BACKPACK_SIZE}, slot0, tick.call())["reason"] == "Unknown item location"
		and world.move_item(1, slot0, {"type": "backpack", "index": World.BACKPACK_MAX - 1}, tick.call())["reason"] == "Unknown item location",
		"locked backpack slots reject items")

	# Town tasks.
	var giver: String = "warden_brask"
	var task: String = World.QUEST_GIVERS[giver]["task"]
	var count: int = Quests.TASKS[task]["count"]
	var hunted: String = Quests.TASKS[task]["monster"]
	check(combat.task_action(1, giver, "accept", tick.call())["reason"] == "Walk closer to a quest giver", "tasks need the giver nearby")
	_place(world, 1, _beside(giver))
	check(not combat.task_action(1, giver, "dance", tick.call())["ok"] and not combat.task_action(1, 7, "accept", tick.call())["ok"]
		and not combat.task_action(1, "relic_keeper", "accept", tick.call())["ok"], "malformed task requests rejected")
	check(combat.task_action(1, giver, "complete", tick.call())["reason"].begins_with("Slay"), "a task must be accepted and finished")
	check(combat.task_action(1, giver, "accept", tick.call())["ok"] and player["tasks"] == {task: 0}, "accepting a task")
	check(not combat.task_action(1, giver, "accept", tick.call())["ok"], "a task is accepted once")
	check(not combat.claim_relic(1, giver, "tidebreaker", tick.call())["ok"], "task givers do not hand out relics")
	var field := Vector2i(9, 10)
	_place(world, 1, field + Vector2i(1, 0))
	_place(world, 2, field + Vector2i(-1, 0))
	world.players[2]["tasks"][task] = 0
	var kill := func(kind: String) -> void:
		var monster: int = combat.spawn_monster(kind, 6, field, clock[0])
		combat._damage(1, monster, 9999999, "damage", tick.call(), [])
	kill.call("field_vole")
	check(player["tasks"][task] == 0, "other monsters do not count")
	for index: int in count + 3:
		kill.call(hunted)
	check(player["tasks"][task] == count and world.players[2]["tasks"][task] == 0,
		"kills count up to the goal, and only for players who earned the kill")
	_place(world, 1, _beside(giver))
	var turned: Dictionary = combat.task_action(1, giver, "complete", tick.call())
	check(turned["ok"] and player["equipment"]["bag"] == Quests.PACKS[0] and backpack.size() == World.BACKPACK_SIZE + 4
		and not player["tasks"].has(task) and player["done_tasks"].has(task), "finishing a task gives the first pack")
	check(world.export_player(1, 0.0, true)["backpack"].size() == backpack.size() and task in world.export_player(1, 0.0, true)["done_tasks"],
		"the bigger backpack and finished tasks replicate to the owner")
	check(world.move_item(1, slot0, {"type": "backpack", "index": backpack.size() - 1}, tick.call())["reason"] == "There is no item there",
		"new pack slots are usable")
	check(not combat.task_action(1, giver, "accept", tick.call())["ok"], "a finished task cannot be repeated")
	for target: Variant in [slot0, {"type": "ground", "cell": player["cell"] + Vector2i.DOWN}, {"type": "backpack"}]:
		check(world.move_item(1, {"type": "equipment", "slot": "bag"}, target, tick.call())["reason"] == "Your pack stays on your back",
			"packs cannot be taken off")
	check(world.toggle_equipment(1, "bag", tick.call())["reason"] == "Your pack stays on your back", "the pack key does nothing")
	world.players[1]["done_tasks"].erase(task)
	world.players[1]["tasks"][task] = count
	check(combat.task_action(1, giver, "complete", tick.call())["ok"] and player["equipment"]["bag"] == Quests.PACKS[1]
		and backpack.size() == World.BACKPACK_SIZE + World.ITEMS[Quests.PACKS[1]]["slots"], "the next task upgrades the pack")

	# Potions.
	player["active_at"] = -INF
	backpack[0] = "health_potion#2"
	backpack[1] = "mana_potion"
	backpack[2] = "wolf_pelt"
	var limits: Dictionary = world.player_stats(1)
	player["health"] = limits["health"]
	check(combat.drink(1, 0, tick.call())["reason"] == "You are already at full health", "no drinking at full health")
	player["health"] = 1
	var drunk: Dictionary = combat.drink(1, 0, tick.call())
	check(drunk["ok"] and player["health"] == 1 + roundi(limits["health"] * 0.2) and backpack[0] == "health_potion",
		"a health potion restores a fifth of your health")
	check(combat.drink(1, 0, clock[0] + 0.5)["reason"] == "Potion cooldown", "potions share a cooldown")
	player["mana"] = 0
	check(combat.drink(1, 1, tick.call())["ok"] and player["mana"] == roundi(limits["mana"] * 0.25) and backpack[1] == "",
		"a mana potion restores a quarter of your mana and the last one is used up")
	check(combat.drink(1, 0, tick.call())["ok"] and backpack[0] == "", "the last health potion is used up")
	for bad: Variant in [2, 1, -1, "0", 0.0, null, backpack.size()]:
		check(not combat.drink(1, bad, tick.call())["ok"], "drinking needs a potion")
	check(player["active_at"] == -INF, "drinking is not combat activity")


func _remove_tree(path: String) -> void:
	var folder := DirAccess.open(path)
	if folder == null:
		return
	for child: String in folder.get_directories():
		_remove_tree(path.path_join(child))
	for file: String in folder.get_files():
		folder.remove(file)
	DirAccess.remove_absolute(path)


func _rewrite(path: String, change: Callable) -> void:
	var envelope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var body: Dictionary = JSON.parse_string(envelope["body"])
	change.call(body, envelope)
	envelope["body"] = JSON.stringify(body)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope))
	file.close()


## Host-side saves: round trip, atomic backups, signatures, and sanitizing; identities.
func _persistence_checks() -> void:
	var token: String = Identity.fresh()
	check(Identity.valid_token(token) and not Identity.valid_token(token.to_upper()) and not Identity.valid_token("abc")
		and not Identity.valid_token(5) and Identity.fresh() != token, "identity tokens are 256 random bits in hex")
	check(Identity.path_for("") == "user://identity.cfg" and Identity.path_for("alice") == "user://identity-alice.cfg",
		"identity profiles get their own file")
	for bad: String in ["a b", "../x", "x/y", "a.cfg", "abcdefghijklmnopqrstuvwxyz0123456789"]:
		check(not Identity.valid_profile(bad), "unsafe profile name rejected: %s" % bad)
	var profile: String = "rules-test-%d" % Time.get_ticks_usec()
	var first: String = Identity.load_or_create(profile)
	check(Identity.valid_token(first) and Identity.load_or_create(profile) == first, "an identity is created once and kept")
	DirAccess.remove_absolute(Identity.path_for(profile))
	var owner: String = CharacterStore.account(token)
	check(owner == token.sha256_text() and owner != token, "saves are named by a hash, never the token")

	var dir: String = "user://rules-test-saves-%d" % Time.get_ticks_usec()
	var store := CharacterStore.new(dir)
	check(store.open().is_empty() and FileAccess.file_exists(dir + "/host.key"), "the save folder and signing key are created")
	check(store.load_character(owner)["status"] == "new", "an unknown identity has no save")
	var world := World.new()
	world.add_player(1, 0.0, "druid")
	var player: Dictionary = world.players[1]
	player["level"] = 23
	player["experience"] = 10
	player["gold"] = 345
	player["bank"] = 1000
	world.wear_pack(1, "explorer_pack")
	player["equipment"]["helmet"] = "iron_coif"
	player["backpack"][0] = "wolf_pelt#12"
	player["backpack"][13] = "health_potion#5"
	player["depot"][3] = "abyssal_greathelm"
	player["trophies"] = {"morvain": 2}
	player["tasks"] = {"outlaw_bounty": 7}
	player["done_tasks"] = {"boar_cull": true}
	player["skull"] = "white"
	player["skull_until"] = 400.0
	player["unjustified"] = [50.0]
	_place(world, 1, Vector2i(6, 8))
	player["health"] = 50
	check(store.save_character(owner, CharacterStore.capture(world, 1, 100.0)), "saving a character")
	var loaded: Dictionary = store.load_character(owner)
	check(loaded["status"] == "ok" and CharacterStore.saved_vocation(loaded["data"]) == "druid", "loading a character")
	var later := World.new()
	later.add_player(5, 0.0, CharacterStore.saved_vocation(loaded["data"]))
	CharacterStore.restore(later, 5, loaded["data"], 1000.0)
	var back: Dictionary = later.players[5]
	check(back["level"] == 23 and back["experience"] == 10 and back["gold"] == 345 and back["bank"] == 1000
		and back["vocation"] == "druid", "level, experience, gold, and bank are restored")
	check(back["equipment"] == {"helmet": "iron_coif", "bag": "explorer_pack"} and back["backpack"].size() == 16
		and back["backpack"][0] == "wolf_pelt#12" and back["backpack"][13] == "health_potion#5"
		and back["depot"][3] == "abyssal_greathelm" and back["depot"].size() == World.DEPOT_SIZE, "items, pack, and depot are restored")
	check(back["trophies"] == {"morvain": 2} and back["tasks"] == {"outlaw_bounty": 7} and back["done_tasks"] == {"boar_cull": true},
		"trophies and tasks are restored")
	check(back["cell"] == Vector2i(6, 8) and back["from"] == back["cell"] and back["health"] == 50, "position and health are restored")
	check(back["skull"] == "white" and is_equal_approx(back["skull_until"], 1300.0) and back["unjustified"].size() == 1
		and is_equal_approx(back["unjustified"][0], 950.0), "skull timers keep their remaining time across restarts")
	var path: String = store.path_for(owner)
	check(not FileAccess.get_file_as_string(path).contains(token), "the token is not written to the save")
	check(store.save_character(owner, CharacterStore.capture(later, 5, 1000.0)) and FileAccess.file_exists(path + ".bak")
		and not FileAccess.file_exists(path + ".tmp"), "saving again keeps the previous save as a backup")
	var crowded := World.new()
	crowded.add_player(2, 0.0)
	_place(crowded, 2, Vector2i(6, 8))
	crowded.add_player(5, 0.0, "druid")
	CharacterStore.restore(crowded, 5, store.load_character(owner)["data"], 0.0)
	check(crowded.players[5]["cell"] != Vector2i(6, 8), "an occupied saved tile falls back to a spawn")

	# Edited, swapped, foreign, and damaged saves are refused.
	_rewrite(path, func(body: Dictionary, _envelope: Dictionary) -> void: body["gold"] = 999999)
	check(store.load_character(owner)["status"] == "invalid", "an edited save fails its signature")
	DirAccess.copy_absolute(path + ".bak", path)
	check(store.load_character(owner)["status"] == "ok", "the backup can be restored")
	var other: String = CharacterStore.account(Identity.fresh())
	DirAccess.copy_absolute(path, store.path_for(other))
	check(store.load_character(other)["reason"] == "belongs to another character", "a save copied to another identity is refused")
	var foreign := CharacterStore.new(dir + "-other")
	check(foreign.open().is_empty(), "a second host folder")
	DirAccess.make_dir_recursive_absolute(dir + "-other/characters")
	DirAccess.copy_absolute(path, foreign.path_for(owner))
	check(foreign.load_character(owner)["status"] == "invalid", "another host's save fails the signature")
	var file := FileAccess.open(store.path_for(other), FileAccess.WRITE)
	file.store_string("not json")
	file.close()
	check(store.load_character(other)["reason"] == "is damaged", "a damaged save is refused")

	# A correctly signed but hostile save cannot create invalid state.
	var hostile: String = CharacterStore.account(Identity.fresh())
	store.save_character(hostile, {
		"vocation": "knight", "level": 999, "experience": -5, "gold": -5, "bank": "lots", "health": -4, "mana": 1e9,
		"equipment": {"helmet": "copper_blade", "main_hand": "abyssal_greathelm", "armor": "nope", "bag": "pathfinder_pack"},
		"backpack": ["wolf_pelt#500", "copper_blade#2", "gold_coins", "nope", "traveler_pack", 5, "wolf_pelt#1", "wolf_pelt#007", "glowcap#3"],
		"depot": "everything", "trophies": {"field_vole": 3, "morvain": -1}, "tasks": {"nope": 3, "boar_cull": 999, "hollow_purge": 999},
		"done_tasks": ["boar_cull", "nope"], "cell": [0, 0], "skull": "black", "skull_left": 50, "unjustified_ages": ["x", -1, 1e12],
	})
	var bad: Dictionary = store.load_character(hostile)["data"]
	var sane := World.new()
	sane.add_player(3, 0.0, CharacterStore.saved_vocation(bad))
	CharacterStore.restore(sane, 3, bad, 0.0)
	var cleaned: Dictionary = sane.players[3]
	var limits: Dictionary = sane.player_stats(3)
	check(cleaned["level"] == Balance.MAX_LEVEL and cleaned["experience"] == 0 and cleaned["gold"] == 0 and cleaned["bank"] == 0,
		"numbers are clamped")
	check(cleaned["equipment"] == {"bag": "pathfinder_pack"} and cleaned["backpack"].size() == World.BACKPACK_MAX,
		"only fitting known equipment is restored")
	check(cleaned["backpack"].count("") == World.BACKPACK_MAX - 1 and cleaned["backpack"][8] == "glowcap#3"
		and cleaned["depot"].count("") == World.DEPOT_SIZE, "invalid entries, stacks, and containers are dropped")
	check(cleaned["trophies"].is_empty() and cleaned["tasks"] == {"hollow_purge": Quests.TASKS["hollow_purge"]["count"]}
		and cleaned["done_tasks"] == {"boar_cull": true}, "unknown trophies and tasks are dropped and progress is capped")
	check(World.walkable(cleaned["cell"]) and cleaned["skull"].is_empty() and cleaned["unjustified"].is_empty()
		and cleaned["health"] == limits["health"] and cleaned["mana"] == limits["mana"], "position, skulls, and vitals are sanitized")
	_remove_tree(dir)
	_remove_tree(dir + "-other")
	check(not DirAccess.dir_exists_absolute(dir), "test saves are cleaned up")


func _place(world: World, id: int, cell: Vector2i) -> void:
	world.players[id]["cell"] = cell
	world.players[id]["from"] = cell


func _hits_on(events: Array, target: int) -> int:
	var count: int = 0
	for event: Dictionary in events:
		if event["kind"] == "hit" and event["target"] == target and event["style"] in ["damage", "critical"]:
			count += 1
	return count


func _combat_checks() -> void:
	# Catalogs: every spawn names a known monster, every look can be drawn, spells are well formed.
	for spawn: Dictionary in World.MONSTER_SPAWNS:
		check(Monsters.MONSTERS.has(spawn["monster"]), "map spawns name catalog monsters")
	for kind: String in Monsters.MONSTERS:
		var definition: Dictionary = Monsters.MONSTERS[kind]
		check(definition["look"] == "humanoid" or SpriteArtSheets.MONSTER_SHEETS.has(definition["look"]), "monster look has a sprite")
		check(definition["rank"] in Balance.RANKS and definition["range"] >= 1 and definition["step"] > 0.0, "monster definition is complete")
		for slot: String in definition.get("gear", {}):
			check(World.fits(definition["gear"][slot], slot), "monster gear fits its slot")
	for spell: String in Spells.SPELLS:
		var definition: Dictionary = Spells.SPELLS[spell]
		check(Spells.GROUP_SECONDS.has(definition["group"]) and definition["mana"] > 0.0 and definition["cooldown"] > 0.0,
			"spell has a group, a mana cost, and a cooldown")
		for vocation: String in definition["vocations"]:
			check(Balance.VOCATIONS.has(vocation), "spell vocations exist")
	for vocation: String in Balance.VOCATIONS:
		check(not Spells.for_vocation(vocation).is_empty() and Combat.VOCATION_RANGE.has(vocation), "every vocation has spells and a range")
	for level: int in range(1, Balance.MAX_LEVEL + 1):
		for progress: int in [0, maxi(0, Balance.experience_to_next(level) - 1)]:
			check(Combat.level_from_total(Combat.total_experience(level, progress)) == [level, progress if level < Balance.MAX_LEVEL else 0],
				"experience totals round-trip")
	# Line of sight: walls and trees block, water does not; melee ignores it.
	check(not Combat.line_of_sight(Vector2i(7, 8), Vector2i(9, 8)), "a wall blocks line of sight")
	check(Combat.line_of_sight(Vector2i(5, 6), Vector2i(10, 6)), "open ground gives line of sight")
	check(Combat.line_of_sight(Vector2i(2, 3), Vector2i(6, 3)), "water does not block line of sight")
	check(Combat.in_reach(Vector2i(5, 6), Vector2i(6, 7), 1) and not Combat.in_reach(Vector2i(5, 6), Vector2i(7, 6), 1),
		"melee reaches the eight surrounding tiles only")
	check(not Combat.in_reach(Vector2i(7, 8), Vector2i(9, 8), 6), "ranged attacks need line of sight")
	# Populating the map.
	var map_world := World.new()
	var map_combat := Combat.new(map_world, 3)
	map_combat.populate(0.0)
	var expected: int = 0
	for spawn: Dictionary in World.MONSTER_SPAWNS:
		expected += spawn["count"]
	check(map_world.monsters.size() == expected, "every spawn marker fills its count")
	var cells: Dictionary = {}
	for id: int in map_world.monsters:
		var monster: Dictionary = map_world.monsters[id]
		cells[monster["cell"]] = true
		check(id < 0 and World.walkable(monster["cell"]), "monsters have negative ids and stand on walkable tiles")
		check(monster["health"] == Balance.mob_health(monster["level"], Monsters.MONSTERS[monster["kind"]]["rank"]),
			"monster health comes from the balance curves")
	check(cells.size() == map_world.monsters.size(), "monsters spawn on separate tiles")

	var world := World.new()
	var combat := Combat.new(world, 11)
	world.add_player(1, 0.0, "paladin")
	world.add_player(2, 0.0, "knight")
	_place(world, 1, Vector2i(5, 6))
	_place(world, 2, Vector2i(14, 2))
	var paladin: Dictionary = world.players[1]
	check(paladin["health"] == Balance.base_stats(1, "paladin")["health"] and paladin["mana"] == Balance.base_stats(1, "paladin")["mana"],
		"players start with full health and mana")
	var public: Dictionary = world.export_player(1, 0.0)
	check(public.has("health") and public.has("max_health") and not public.has("mana") and not public.has("target"),
		"health is public; mana and target are private")
	var vole: int = combat.spawn_monster("field_vole", 1, Vector2i(5, 8), 0.0)
	var far: int = combat.spawn_monster("field_vole", 1, Vector2i(15, 15), 0.0)
	check(world.move(1, Vector2i.DOWN, 0.0)["ok"] and not world.move(1, Vector2i.DOWN, 1.0)["ok"] and world.players[1]["cell"] == Vector2i(5, 7),
		"monsters block movement")
	_place(world, 1, Vector2i(5, 6))
	check(combat.set_target(1, "x", 0.0)["reason"] == "Unknown target", "malformed target rejected")
	check(combat.set_target(1, -999, 0.0)["reason"] == "Unknown target", "unknown target rejected")
	check(not combat.set_target(1, 2, 0.0)["ok"], "players cannot attack each other outside PvP zones")
	check(not combat.set_target(1, 1, 0.0)["ok"], "players cannot target themselves")
	check(combat.set_target(1, far, 0.0)["reason"] == "Your target is too far away", "targets must be within range")
	check(not combat.set_target(99, vole, 0.0)["ok"], "unknown attacker rejected")
	check(combat.set_target(1, vole, 0.0)["ok"] and paladin["target"] == vole, "lock a monster")
	var events: Array = combat.tick(0.0)
	check(_hits_on(events, vole) == 1 and world.monsters[vole]["damage_by"].get(1, 0) > 0, "auto-attack hits a target in range")
	var missile: bool = false
	for event: Dictionary in events:
		missile = missile or event["kind"] == "missile"
	check(missile, "ranged attacks fire a missile")
	var dealt: int = world.monsters[vole]["damage_by"][1]
	var attack: float = world.player_stats(1)["attack"]
	check(dealt >= floori(attack * 0.85) and dealt <= ceili(attack * 1.15 * Combat.CRITICAL_MULTIPLIER), "damage stays within its range")
	world.monsters[vole]["health"] = 1000
	world.monsters[vole]["max_health"] = 1000
	check(_hits_on(combat.tick(Balance.ATTACK_SECONDS - 0.15), vole) == 0, "no second attack before two seconds")
	check(_hits_on(combat.tick(Balance.ATTACK_SECONDS), vole) == 1, "next attack exactly at two seconds")
	_place(world, 1, Vector2i(7, 8))
	world.monsters[vole]["cell"] = Vector2i(9, 8)
	world.monsters[vole]["from"] = Vector2i(9, 8)
	world.monsters[vole]["next_move"] = 100.0
	check(_hits_on(combat.tick(10.0), vole) == 0, "walls stop ranged attacks")
	world.monsters.erase(vole)
	world.monsters.erase(far)
	paladin["target"] = 0

	# Monster AI: notice, chase without overlapping, attack, then return home and heal.
	var wolf: int = combat.spawn_monster("grey_wolf", 1, Vector2i(10, 6), 20.0)
	_place(world, 1, Vector2i(5, 6))
	_place(world, 2, Vector2i(20, 15))
	var health: int = paladin["health"]
	var time: float = 20.0
	var safe: bool = true
	while time < 30.0:
		time += 0.1
		combat.tick(time)
		var cell: Vector2i = world.monsters[wolf]["cell"]
		safe = safe and World.walkable(cell) and cell != paladin["cell"] and cell != world.players[2]["cell"]
	check(world.monsters[wolf]["target"] == 1 and Combat.distance(world.monsters[wolf]["cell"], paladin["cell"]) == 1,
		"a monster notices and reaches a nearby player")
	check(safe, "monsters only step onto free walkable tiles")
	check(paladin["health"] < health, "monsters attack players in reach")
	world.monsters[wolf]["health"] = 5
	_place(world, 1, world.arrival_cell("lastlight", time))
	paladin["health"] = 10000
	while time < 45.0:
		time += 0.1
		combat.tick(time)
	check(world.monsters[wolf]["target"] == 0 and world.monsters[wolf]["cell"] == Vector2i(10, 6)
		and world.monsters[wolf]["health"] == world.monsters[wolf]["max_health"], "out of the leash, monsters walk home and heal")
	world.monsters.erase(wolf)

	# Kills: experience shared by damage, level ups, and loot.
	paladin["health"] = world.player_stats(1)["health"]
	_place(world, 1, Vector2i(5, 6))
	var boar: int = combat.spawn_monster("thornback_boar", 40, Vector2i(9, 10), time)
	world.monsters[boar]["damage_by"] = {2: 30}
	world.monsters[boar]["health"] = 10
	events = []
	combat._damage(1, boar, 10, "damage", time, events)
	var experience: int = Balance.mob_experience(40)
	check(not world.monsters.has(boar), "a monster at zero health dies")
	var gained: Dictionary = {}
	for event: Dictionary in events:
		if event["kind"] == "hit" and event["style"] == "experience":
			gained[event["target"]] = event["amount"]
	check(gained.get(1, 0) == roundi(experience * 10.0 / 40.0) and gained.get(2, 0) == roundi(experience * 30.0 / 40.0),
		"experience is shared by damage dealt")
	check(world.players[2]["level"] > 1, "enough experience levels a player up")
	check(_count(world.ground.get(Vector2i(9, 10), []), "gold_coins") >= 1, "high-level monsters drop gold")
	# Loot tables.
	for kind: String in Monsters.MONSTERS:
		check(Monsters.LOOT.has(kind), "%s has a loot table" % kind)
		for entry: Array in Monsters.LOOT.get(kind, []):
			check(World.ITEMS.has(entry[0]) and entry[0] != "gold_coins", "%s loot %s is a catalog item" % [kind, entry[0]])
			check(float(entry[1]) > 0.0 and float(entry[1]) <= 1.0, "%s loot %s has a chance in (0, 1]" % [kind, entry[0]])
	for kind: String in World.ITEMS:
		if World.ITEMS[kind]["slot"].is_empty() and kind not in ["gold_coins", "glowcap"] and not World.ITEMS[kind].has("drink"):
			check(int(World.ITEMS[kind].get("value", 0)) > 0, "material %s has a shop value" % kind)
			check(SpriteArt.ITEM_ORDER.has(kind), "material %s has an icon" % kind)
	var loot_a := Combat.new(World.new(), 77)
	var loot_b := Combat.new(World.new(), 77)
	var same: bool = true
	for roll: int in 50:
		same = same and loot_a.roll_loot("road_bandit", 12) == loot_b.roll_loot("road_bandit", 12)
	check(same, "loot rolls are deterministic for a seed")
	var tally: Dictionary = {}
	var loot_rolls := Combat.new(World.new(), 3)
	for roll: int in 4000:
		for entry: String in loot_rolls.roll_loot("field_vole", 1):
			tally[World.kind_of(entry)] = tally.get(World.kind_of(entry), 0) + World.count_of(entry)
	check(tally.get("vole_tail", 0) > 1800 and tally.get("vole_tail", 0) < 2200, "common materials drop at their table chance")
	var gear: int = 0
	for kind: String in tally:
		if not World.ITEMS[kind]["slot"].is_empty():
			gear += tally[kind]
			check(World.ITEMS[kind]["level"] == 1, "a level-1 monster drops tier-1 gear only")
	check(gear > 110 and gear < 220, "normal monsters drop a piece of gear about 4% of the time")
	check(tally.get("gold_coins", 0) > 2200 and tally.get("gold_coins", 0) < 2600, "low monsters drop a gold pile about 60% of the time")
	var warden_loot: Array[String] = loot_rolls.roll_loot("blackreed_warden", 50)
	var warden_gold: int = _count(warden_loot, "gold_coins")
	check(warden_loot.filter(func(entry: String) -> bool: return World.kind_of(entry) == "gold_coins").size() == 1,
		"gold piles drop as one stack")
	check(warden_gold >= 8 and warden_gold <= 9, "elites add gold piles on top of the level scale")
	# Loot spills around a crowded corpse within the stack limit and never onto walls.
	var crowd := World.new()
	var crowd_combat := Combat.new(crowd, 9)
	var corpse := Vector2i(9, 10)
	crowd.ground[corpse] = ["glowcap", "glowcap", "glowcap", "glowcap", "glowcap", "glowcap"]
	var many: Array[String] = []
	for count: int in 10:
		many.append("wolf_pelt")
	var spilled: Array[Vector2i] = crowd_combat.spill(corpse, many)
	var placed: int = 0
	var tidy: bool = many.is_empty() and not spilled.has(corpse)
	for cell: Vector2i in spilled:
		placed += _count(crowd.ground[cell], "wolf_pelt")
		tidy = tidy and World.walkable(cell) and Combat.distance(cell, corpse) <= Combat.SPILL_RADIUS \
			and crowd.ground[cell].size() <= World.GROUND_STACK_MAX
	check(tidy and placed == 10 and crowd.ground[corpse].size() == World.GROUND_STACK_MAX,
		"loot spills past a full corpse tile onto nearby walkable tiles")
	# Respawn from markers.
	if not World.MONSTER_SPAWNS.is_empty():
		var any: int = map_world.monsters.keys()[0]
		var before: int = map_world.monsters.size()
		map_combat._damage(0, any, 1000000, "damage", 100.0, [])
		check(map_world.monsters.size() == before - 1 and map_combat.respawns.size() == 1, "dead monsters wait to respawn")
		map_combat.tick(100.0 + Monsters.RESPAWN_SECONDS - 1.0)
		check(map_world.monsters.size() == before - 1, "no respawn before the delay")
		map_combat.tick(100.0 + Monsters.RESPAWN_SECONDS + 0.2)
		check(map_world.monsters.size() == before, "monsters respawn after the delay")

	# Death: lose 10% of total experience, respawn in town at full health.
	var knight: Dictionary = world.players[2]
	_place(world, 2, Vector2i(20, 2))
	var total: int = Combat.total_experience(knight["level"], knight["experience"])
	events = []
	combat._damage(-1, 2, 999999, "damage", time, events)
	check(Combat.total_experience(knight["level"], knight["experience"]) == total - roundi(total * Combat.DEATH_PENALTY),
		"death costs ten percent of total experience")
	check(knight["cell"] in World.SPAWNS and knight["health"] == world.player_stats(2)["health"] and knight["target"] == 0,
		"the dead respawn in town at full health")
	# Resting: out of combat, regeneration is faster.
	var rester: Dictionary = world.players[1]
	rester["health"] = 1
	rester["mana"] = 0
	rester["last_combat"] = time
	rester["next_regen"] = 0.0
	combat.tick(time + 1.0)
	var fighting_gain: int = rester["health"] - 1
	rester["health"] = 1
	rester["next_regen"] = 0.0
	combat.tick(time + Combat.RESTING_SECONDS + 2.0)
	check(not combat.resting(1, time + 1.0) and combat.resting(1, time + Combat.RESTING_SECONDS + 2.0)
		and rester["health"] - 1 > fighting_gain, "resting out of combat regenerates faster")

	# Spells: vocation, level, target, mana, cooldowns, groups, heals, and areas.
	_place(world, 1, Vector2i(5, 6))
	paladin["mana"] = world.player_stats(1)["mana"]
	check(combat.cast(1, 5, time)["reason"] == "Unknown spell" and combat.cast(1, "fireball", time)["reason"] == "Unknown spell",
		"unknown spells rejected")
	check(combat.cast(1, "ember_bolt", time)["reason"].begins_with("Your vocation"), "vocation spells only")
	check(combat.cast(1, "holy_mend", time)["reason"] == "Holy mend needs level 8", "spell level requirement")
	check(combat.cast(1, "piercing_shot", time)["reason"] == "You need a target in range", "attack spells need a target")
	var dummy: int = combat.spawn_monster("stone_golem", 1, Vector2i(9, 6), time)
	world.monsters[dummy]["next_move"] = 1000.0
	world.monsters[dummy]["next_attack"] = 1000.0
	combat.set_target(1, dummy, time)
	var mana: int = paladin["mana"]
	var cost: int = maxi(1, roundi(world.player_stats(1)["mana"] * Spells.SPELLS["piercing_shot"]["mana"]))
	var cast: Dictionary = combat.cast(1, "piercing_shot", time)
	check(cast["ok"] and paladin["mana"] == mana - cost and _hits_on(cast["events"], dummy) == 1, "an attack spell costs mana and hits")
	check(combat.cast(1, "piercing_shot", time + 1.0)["reason"] == "You are exhausted", "spell cooldown")
	paladin["health"] -= 20
	var heal: Dictionary = combat.cast(1, "light_heal", time + 0.5)
	check(heal["ok"] and paladin["health"] <= world.player_stats(1)["health"], "a healing spell ignores the attack group and caps at max")
	check(combat.cast(1, "light_heal", time + 1.0)["reason"] == "You are exhausted", "healing group and spell cooldowns")
	paladin["mana"] = 0
	check(combat.cast(1, "light_heal", time + 10.0)["reason"].begins_with("Not enough mana"), "spells need mana")
	world.monsters.erase(dummy)
	world.add_player(3, 0.0, "knight")
	world.players[3]["level"] = 10
	world.clamp_vitals(3)
	_place(world, 3, Vector2i(10, 2))
	var left: int = combat.spawn_monster("stone_golem", 1, Vector2i(9, 2), time)
	var right: int = combat.spawn_monster("stone_golem", 1, Vector2i(11, 2), time)
	var whirl: Dictionary = combat.cast(3, "whirling_strike", time + 20.0)
	check(whirl["ok"] and _hits_on(whirl["events"], left) == 1 and _hits_on(whirl["events"], right) == 1, "area spells hit every enemy around")
	world.add_player(4, 0.0, "druid")
	var druid: Dictionary = world.players[4]
	druid["level"] = 10
	world.clamp_vitals(4)
	_place(world, 4, Vector2i(14, 4))
	_place(world, 1, Vector2i(15, 5))
	_place(world, 3, Vector2i(20, 1))
	paladin["health"] = 10
	world.players[3]["health"] = 10
	var mass: Dictionary = combat.cast(4, "mass_mend", time + 20.0)
	check(mass["ok"] and paladin["health"] > 10 and world.players[3]["health"] == 10, "mass mend heals players within its radius only")

	# Regeneration.
	paladin["health"] = 10
	paladin["mana"] = 0
	paladin["next_regen"] = 0.0
	combat.tick(time + 30.0)
	check(paladin["health"] > 10 and paladin["mana"] > 0, "health and mana regenerate")

	# PvP only inside a PvP zone.
	var pvp_cells: Array[Vector2i] = []
	for zone: Dictionary in World.ZONES:
		if zone["pvp"]:
			for y: int in range(zone["rect"].position.y, zone["rect"].end.y):
				for x: int in range(zone["rect"].position.x, zone["rect"].end.x):
					if World.walkable(Vector2i(x, y)) and pvp_cells.size() < 2 and (pvp_cells.is_empty() or Combat.distance(pvp_cells[0], Vector2i(x, y)) == 2):
						pvp_cells.append(Vector2i(x, y))
	if pvp_cells.size() == 2:
		world.monsters.clear()
		_place(world, 1, pvp_cells[0])
		_place(world, 4, pvp_cells[1])
		check(combat.set_target(1, 4, time + 40.0)["ok"] and combat.hostile(4, 1), "players can fight inside a PvP zone")
		_place(world, 4, Vector2i(14, 4))
		combat.tick(time + 41.0)
		check(paladin["target"] == 0, "leaving the PvP zone drops the target")


## Items of `kind` across entries, counting stacks.
func _count(entries: Array, kind: String) -> int:
	var total: int = 0
	for entry: String in entries:
		if World.kind_of(entry) == kind:
			total += World.count_of(entry)
	return total


func _ground_items(world: World) -> Array:
	var all: Array = []
	for cell: Vector2i in world.ground:
		all.append_array(world.ground[cell])
	return all


func _death_and_skull_checks() -> void:
	# Item loss: the backpack and purse always drop; worn items drop 10% of the time.
	var world := World.new()
	world.ground.clear()
	var combat := Combat.new(world, 21)
	world.add_player(1, 0.0, "knight")
	var victim: Dictionary = world.players[1]
	_place(world, 1, Vector2i(5, 6))
	# Beginner protection: below the protection level, death keeps items and gold.
	var protected_gold: int = victim["gold"]
	var protected_kit: Array = victim["backpack"].duplicate()
	var protected_events: Array = []
	combat._damage(-1, 1, 999999, "damage", 5.0, protected_events)
	check(victim["backpack"] == protected_kit and victim["gold"] == protected_gold and _ground_items(world).is_empty(),
		"below level 8, dying keeps items and gold")
	var protected_message: String = ""
	for event: Dictionary in protected_events:
		if event["kind"] == "message":
			protected_message = event["text"]
	check(protected_message.contains("keep your items"), "the death message explains beginner protection")
	victim["level"] = Combat.PROTECTION_LEVEL
	victim["experience"] = 0
	world.clamp_vitals(1)
	_place(world, 1, Vector2i(5, 6))
	for slot: String in ["helmet", "armor"]:
		world.toggle_equipment(1, slot, 10.0 + World.SLOTS.find(slot))
	victim["gold"] = 110
	var carried: Array = victim["backpack"].filter(func(kind: String) -> bool: return not kind.is_empty())
	var events: Array = []
	combat._damage(-1, 1, 999999, "damage", 20.0, events)
	var dropped: Array = _ground_items(world)
	check(victim["backpack"].count("") == World.BACKPACK_SIZE and victim["gold"] == 0, "death empties the backpack and purse")
	for kind: String in carried:
		check(kind in dropped, "carried items drop on death")
	check(_count(dropped, "gold_coins") == 4, "purse gold drops as coin piles")
	var kept: int = victim["equipment"].size()
	var items: int = 0
	for entry: String in dropped:
		items += World.count_of(entry)
	check(items == carried.size() + 4 + (2 - kept), "worn items either stay worn or drop")
	var near: bool = true
	for cell: Vector2i in world.ground:
		near = near and Combat.distance(cell, Vector2i(5, 6)) <= Combat.SPILL_RADIUS and world.ground[cell].size() <= World.GROUND_STACK_MAX
	check(near and world.ground.has(Vector2i(5, 6)), "lost items land on the death tile and spill nearby within the stack limit")
	var ground_event: bool = false
	for event: Dictionary in events:
		ground_event = ground_event or event["kind"] == "ground"
	check(ground_event, "dropped items are replicated")
	# Worn-item chance over many deaths: about 10% per item.
	var trials := World.new()
	var trial_combat := Combat.new(trials, 5)
	trials.add_player(1, 0.0)
	var lost: int = 0
	trials.players[1]["level"] = 20
	for trial: int in 400:
		trials.ground.clear()
		trials.players[1]["equipment"] = {"helmet": "ember_cap"}
		_place(trials, 1, Vector2i(5, 6))
		trials.players[1]["level"] = 20
		trial_combat._damage(-1, 1, 999999, "damage", 30.0 + trial, [])
		lost += 0 if trials.players[1]["equipment"].has("helmet") else 1
	check(lost > 20 and lost < 60, "each worn item drops about 10% of the time")
	# A red skull loses everything.
	victim["equipment"] = {"helmet": "ember_cap", "armor": "moss_coat", "main_hand": "copper_blade"}
	victim["skull"] = "red"
	victim["skull_until"] = 1.0e9
	victim["level"] = 20
	world.ground.clear()
	_place(world, 1, Vector2i(5, 6))
	combat._damage(-1, 1, 999999, "damage", 40.0, [])
	check(victim["equipment"].is_empty() and _ground_items(world).size() == 3, "a red skull loses every worn item")
	check(victim["skull"] == "red", "a red skull stays after death")

	# Skulls on Blackreed Isle.
	var cells: Array[Vector2i] = []
	for zone: Dictionary in World.ZONES:
		if zone["pvp"]:
			for y: int in range(zone["rect"].position.y, zone["rect"].end.y):
				for x: int in range(zone["rect"].position.x, zone["rect"].end.x):
					if World.walkable(Vector2i(x, y)) and cells.size() < 3:
						cells.append(Vector2i(x, y))
	if cells.size() < 3:
		return
	var pvp := World.new()
	var fight := Combat.new(pvp, 9)
	for id: int in [1, 2, 3]:
		pvp.add_player(id, 0.0, "knight")
		_place(pvp, id, cells[id - 1])
	var a: Dictionary = pvp.players[1]
	var b: Dictionary = pvp.players[2]
	check(pvp.export_player(1, 0.0).has("skull") and a["skull"] == "", "players start unmarked; the skull is public")
	fight._damage(1, 2, 1, "damage", 100.0, [])
	check(a["skull"] == "white" and is_equal_approx(a["skull_until"], 100.0 + Combat.WHITE_SKULL_SECONDS), "attacking an unmarked player gives a white skull")
	fight._damage(2, 1, 1, "damage", 101.0, [])
	check(b["skull"] == "", "fighting back is self-defence")
	fight._damage(3, 1, 1, "damage", 102.0, [])
	check(pvp.players[3]["skull"] == "", "attacking a skulled player is allowed")
	fight._damage(1, 2, 5, "damage", 103.0, [])
	check(a["skull_until"] > 100.0 + Combat.WHITE_SKULL_SECONDS, "attacking again extends the white skull")
	var events_kill: Array = []
	fight._damage(2, 1, 999999, "damage", 104.0, events_kill)
	check(b["unjustified"].is_empty() and b["skull"] == "", "killing your attacker is justified")
	# Three unjustified kills within a day give a red skull.
	a["skull"] = ""
	a["skull_until"] = 0.0
	for round_number: int in 3:
		b["skull"] = ""
		b["aggressors"].clear()
		a["aggressors"].clear()
		_place(pvp, 1, cells[0])
		_place(pvp, 2, cells[1])
		var time: float = 200.0 + round_number * 10.0
		fight._damage(1, 2, 999999, "damage", time, [])
		check(a["unjustified"].size() == round_number + 1, "killing an unmarked player is unjustified")
		check(a["skull"] == ("red" if round_number == 2 else "white"), "the third unjustified kill gives a red skull")
	check(pvp.export_player(1, 0.0, true)["unjustified"] == 3, "players see their unjustified kills")
	a["unjustified"] = [0.0]
	a["skull"] = ""
	b["skull"] = ""
	b["aggressors"].clear()
	a["aggressors"].clear()
	_place(pvp, 1, cells[0])
	_place(pvp, 2, cells[1])
	fight._damage(1, 2, 999999, "damage", Combat.UNJUSTIFIED_WINDOW_SECONDS + 10.0, [])
	check(a["unjustified"].size() == 1, "unjustified kills older than a day are forgotten")
	a["skull"] = "white"
	a["skull_until"] = 500.0
	fight.tick(500.0)
	check(a["skull"] == "", "white skulls expire")
