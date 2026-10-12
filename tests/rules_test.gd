extends SceneTree

const World = preload("res://game/world.gd")
const SpriteArt = preload("res://game/sprite_art.gd")
const Balance = preload("res://game/balance.gd")
const Keybinds = preload("res://game/keybinds.gd")
const Combat = preload("res://game/combat.gd")
const Monsters = preload("res://game/monsters.gd")
const Spells = preload("res://game/spells.gd")
const SpriteArtSheets = preload("res://game/sprite_art.gd")
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
		check(World.ITEMS.has(entry[1]), "seeded ground item is in the catalog")
	for kind: String in World.START_KIT:
		check(not World.slot_for(kind, {}).is_empty(), "start kit is equippable")
	check(World.START_KIT.size() <= World.BACKPACK_SIZE, "start kit fits the backpack")
	var bag := World.new()
	check(bag.ground_stack(Vector2i(10, 1)) == ["glowcap", "glowcap"], "seeded ground stack")
	check(bag.add_player(1, 0.0), "inventory player")
	var player: Dictionary = bag.players[1]
	player["cell"] = Vector2i(8, 6)
	player["from"] = Vector2i(8, 6)
	var here: Vector2i = Vector2i(8, 6)
	var backpack: Array = player["backpack"]
	var equipment: Dictionary = player["equipment"]
	check(backpack.slice(0, World.START_KIT.size()) == World.START_KIT and backpack.count("") \
		== World.BACKPACK_SIZE - World.START_KIT.size(), "start kit in backpack")
	# The scenario below was written for a three-item backpack; keep that layout.
	for index: int in World.BACKPACK_SIZE:
		backpack[index] = World.START_KIT[index] if index < 3 else ""
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
		bag.ground[here].append("glowcap")
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
	check(World.SLOTS.size() == 8 and World.SLOT_TYPES.size() == 8, "eight equipment slots")
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
	check(World.fits("copper_band", "ring_1") and World.fits("copper_band", "ring_2"), "rings fit both ring slots")
	check(not World.fits("copper_band", "necklace") and not World.fits("glowcap", "charm"), "wrong slot types rejected")
	check(not World.fits("no_such_item", "helmet") and not World.fits("ember_cap", "hand"), "unknown items or slots")
	check(World.slot_for("garnet_ring", {}) == "ring_1", "first ring goes to ring 1")
	check(World.slot_for("garnet_ring", {"ring_1": "copper_band"}) == "ring_2", "second ring goes to ring 2")
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
	var ring_index: int = backpack.find("copper_band")
	backpack[5] = "garnet_ring"
	check(world.move_item(1, {"type": "backpack", "index": ring_index}, {"type": "equipment", "slot": "ring_2"}, 1.0)["ok"],
		"equip ring 2")
	check(world.move_item(1, {"type": "backpack", "index": 5}, {"type": "equipment", "slot": "ring_1"}, 2.0)["ok"],
		"equip ring 1")
	check(world.move_item(1, {"type": "equipment", "slot": "ring_1"}, {"type": "equipment", "slot": "ring_2"}, 3.0)["ok"],
		"swap rings between ring slots")
	check(equipment["ring_1"] == "copper_band" and equipment["ring_2"] == "garnet_ring", "ring swap exchanges items")
	check(world.move_item(1, {"type": "equipment", "slot": "ring_1"}, {"type": "equipment", "slot": "necklace"}, 4.0)["reason"]
		== "That item does not fit there", "ring cannot be worn as a necklace")
	backpack[6] = "hearth_charm"
	check(world.move_item(1, {"type": "backpack", "index": 6}, {"type": "equipment", "slot": "ring_1"}, 5.0)["reason"]
		== "That item does not fit there", "charm cannot be worn as a ring")
	check(equipment["ring_1"] == "copper_band" and backpack[6] == "hearth_charm", "rejected ring move changes nothing")
	check(world.move_item(1, {"type": "backpack", "index": 6}, {"type": "equipment", "slot": "charm"}, 6.0)["ok"], "equip charm")
	check(world.toggle_equipment(1, "off_hand", 7.0)["ok"] and equipment["off_hand"] == "oak_buckler", "toggle off hand")
	check(world.toggle_equipment(1, "main_hand", 8.0)["ok"], "toggle main hand")
	var base: Dictionary = Balance.base_stats(1)
	var stats: Dictionary = World.stats(1, equipment)
	check(stats["attack"] == base["attack"] + 2 + 1, "blade and charm add attack")
	check(stats["critical"] == base["critical"] + 2 + 3, "blade and ring add critical")
	check(stats["health"] == base["health"] + 20 + 10, "ring and charm add health")
	check(stats["defense"] == base["defense"] + 5, "buckler adds defense")
	check(stats["regen"] == base["regen"] + 2, "charm adds regen")
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
	check(World.zone_at(Vector2i(-50, -50)).is_empty() and World.zone_at(World.SPAWNS[0]).is_empty(), "towns are outside zones")
	if World.FERRYMEN.has("blackreed_isle") and World.FERRYMEN.has("reedmere"):
		var isle: Dictionary = World.zone_at(World.FERRYMEN["blackreed_isle"]["cell"])
		check(isle.get("pvp", false) and isle["min_level"] == 40 and isle["max_level"] == 50, "Blackreed Isle is a level 40-50 PvP zone")
		check(World.FERRYMEN["reedmere"]["routes"].keys() == ["blackreed_isle"]
			and World.FERRYMEN["blackreed_isle"]["routes"].keys() == ["reedmere"], "only Reedmere sails to the island")
		var on_isle: int = 0
		for spawn: Dictionary in World.MONSTER_SPAWNS:
			on_isle += 1 if World.zone_at(spawn["cell"]) == isle else 0
		check(on_isle >= 5, "the island has monster spawn points")
		for id: String in World.FERRYMEN:
			if id not in ["reedmere", "blackreed_isle"]:
				check(not World.FERRYMEN[id]["routes"].has("blackreed_isle") and World.FERRYMEN[id]["cell"].x < 64,
					"coastal ports sail the western sea only")


func _keybind_checks() -> void:
	var path: String = "user://keybinds_test.cfg"
	var binds := Keybinds.new(path)
	check(binds.action_for(KEY_1) == "slot_1" and binds.action_for(KEY_9) == "slot_9", "action bar defaults to 1-9")
	check(binds.action_for(KEY_W) == "move_up" and binds.action_for(KEY_UP) == "move_up", "movement has two default keys")
	check(binds.action_for(KEY_NONE) == "" and binds.action_for(KEY_F12) == "", "unbound keys do nothing")
	check(binds.bar[0] == "toggle_helmet" and binds.bar[8] == "", "bar starts with the gear toggles")
	check(binds.bind("slot_1", 0, KEY_Q) and binds.action_for(KEY_Q) == "slot_1" and binds.action_for(KEY_1) == "",
		"rebinding replaces the old key")
	check(binds.bind("slot_2", 1, KEY_Q) and binds.action_for(KEY_Q) == "slot_2" and binds.keys["slot_1"][0] == KEY_NONE,
		"a key used elsewhere moves to the new action")
	check(not binds.bind("slot_3", 0, KEY_ESCAPE) and binds.action_for(KEY_3) == "slot_3", "Escape cannot be bound")
	check(not binds.bind("no_such_action", 0, KEY_P) and not binds.bind("slot_3", 2, KEY_P), "invalid bindings rejected")
	check(binds.bind("slot_3", 0, KEY_NONE) and binds.action_for(KEY_3) == "", "a binding can be cleared")
	check(binds.set_bar(4, "pick_up") and not binds.set_bar(9, "pick_up") and not binds.set_bar(0, "fireball"),
		"bar slots accept known actions only")
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
	_place(world, 1, world.arrival_cell("mossford", time))
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
	check(world.ground.get(Vector2i(9, 10), []).count("gold_coins") >= 1, "high-level monsters drop gold")
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
	check(dropped.count("gold_coins") == 4, "purse gold drops as coin piles")
	var kept: int = victim["equipment"].size()
	check(dropped.size() == carried.size() + 4 + (2 - kept), "worn items either stay worn or drop")
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
