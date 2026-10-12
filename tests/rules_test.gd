extends SceneTree

const World = preload("res://game/world.gd")
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
	for row: String in World.ROWS:
		check(row.length() == World.ROWS[0].length(), "rectangular map")
		for tile: String in row:
			check(tile in ["#", ".", ",", "~"], "known tile")
	for spawn: Vector2i in World.SPAWNS:
		check(World.walkable(spawn), "walkable spawn")
	check(not World.walkable(Vector2i(-1, 1)), "negative bounds")
	check(not World.walkable(Vector2i(24, 1)), "right bounds")
	check(not World.walkable(Vector2i(1, 18)), "bottom bounds")
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
	check(world.add_player(3, 0.6), "third spawn")
	check(world.add_player(4, 0.6), "fourth spawn")
	check(not world.add_player(5, 0.6), "four-player cap")
	world.remove_player(3)
	check(not world.players.has(3), "disconnect removes player")
	check(world.add_player(5, 0.6), "disconnect releases spawn")
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
	print("BRIMHOLT_RULES: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _inventory_checks() -> void:
	for entry: Array in World.GROUND_ITEMS:
		check(World.walkable(entry[0]), "seeded ground item on walkable tile")
		check(World.ITEMS.has(entry[1]), "seeded ground item is in the catalog")
	for kind: String in World.START_KIT:
		check(World.ITEMS.has(kind) and World.ITEMS[kind]["slot"] in World.SLOTS, "start kit is equippable")
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
	check(backpack == ["ember_cap", "moss_coat", "copper_blade", "", "", "", "", ""], "start kit in backpack")
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
	check(act(bag, {"type": "ground", "cell": here}, {"type": "equipment", "slot": "hand"})["ok"], "equip from ground")
	check(equipment["hand"] == "copper_blade" and not bag.ground.has(here), "ground equip clears the tile")
	check(act(bag, {"type": "equipment", "slot": "helmet"}, {"type": "ground", "cell": here})["ok"], "drop worn item")
	check(not equipment.has("helmet") and bag.ground_stack(here) == ["ember_cap"], "worn item reaches the ground")
	bag.ground[Vector2i(9, 6)] = ["flint_hatchet"]
	check(act(bag, {"type": "ground", "cell": Vector2i(9, 6)}, {"type": "equipment", "slot": "hand"})["ok"],
		"equip over an occupied slot")
	check(equipment["hand"] == "flint_hatchet" and bag.ground_stack(Vector2i(9, 6)) == ["copper_blade"],
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
	check(bag.toggle_equipment(1, "hand", clock)["reason"] == "Your backpack is full", "full unequip rejected")
	check(equipment["hand"] == "flint_hatchet" and bag.ground_stack(here) == ["ember_cap"], "full backpack keeps state")
	while bag.ground[here].size() < World.GROUND_STACK_MAX:
		bag.ground[here].append("glowcap")
	check(act(bag, slot1, {"type": "ground", "cell": here})["reason"] == "There is no room on that tile", "ground stack cap")
	var ground_copy: Dictionary = bag.ground_snapshot()
	ground_copy[here].append("glowcap")
	check(bag.ground[here].size() == World.GROUND_STACK_MAX, "ground snapshot cannot mutate server state")
	bag.remove_player(1)
	check(bag.ground[here].size() == World.GROUND_STACK_MAX and bag.ground.size() == 6,
		"leaving keeps ground items; carried items leave with the player")
