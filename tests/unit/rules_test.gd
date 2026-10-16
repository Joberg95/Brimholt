extends SceneTree

const World = preload("res://game/core/world.gd")
const SpriteArt = preload("res://game/render/sprite_art.gd")
const Balance = preload("res://game/data/balance.gd")
const Keybinds = preload("res://game/input/keybinds.gd")
const Combat = preload("res://game/core/combat.gd")
const Monsters = preload("res://game/data/monsters.gd")
const Lexicon = preload("res://game/core/lexicon.gd")
const Bots = preload("res://game/core/bots.gd")
const BotLoot = preload("res://game/core/bot_loot.gd")
const Spells = preload("res://game/data/spells.gd")
const Items = preload("res://game/data/items.gd")
const Economy = preload("res://game/core/economy.gd")
const Quests = preload("res://game/data/quests.gd")
const CharacterStore = preload("res://game/persistence/character_store.gd")
const Identity = preload("res://game/persistence/identity.gd")
const Dungeons = preload("res://game/data/dungeons.gd")
const Instances = preload("res://game/core/instances.gd")
const Weather = preload("res://game/render/weather.gd")
const Biomes = preload("res://game/data/biomes.gd")
const TownPaths = preload("res://tools/generators/town_paths.gd")
const ClearWalls = preload("res://tools/generators/clear_walls.gd")
const CobbleTowns = preload("res://tools/generators/cobble_towns.gd")
const Landscape = preload("res://tools/generators/landscape.gd")
const Caves = preload("res://game/data/caves.gd")
const Atlas = preload("res://game/data/atlas.gd")
const Titles = preload("res://game/data/titles.gd")
const VoidThrone = preload("res://tools/generators/void_throne.gd")
const EndgameZone = preload("res://tools/generators/endgame_zone.gd")
const Regions = preload("res://game/data/regions.gd")
const Crafting = preload("res://game/core/crafting.gd")
const Professions = preload("res://game/data/professions.gd")
const Solo = preload("res://game/core/solo.gd")
const Nav = preload("res://game/core/nav.gd")
const SpriteArtSheets = preload("res://game/render/sprite_art.gd")
var failures: int = 0
var checks: int = 0
var clock: float = 0.0


func _initialize() -> void:
	call_deferred("_run")


## One assertion per call site: a check inside a loop (every item, spawn, tile, or pose) counts
## once however many cases it covers. `cases` counts every evaluation; each failing case is a
## failure, and the first few of each assertion are printed.
var _assertions: Dictionary = {}
var cases: int = 0


func check(condition: bool, message: String) -> void:
	var frames: Array = get_stack()
	var site: String = "%s:%d" % [frames[1]["function"], frames[1]["line"]] if frames.size() > 1 else message
	if not _assertions.has(site):
		_assertions[site] = 0
		checks += 1
	cases += 1
	if not condition:
		failures += 1
		_assertions[site] += 1
		if _assertions[site] <= 3:
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
	_dungeon_checks()
	_cave_checks()
	_isles_checks()
	_scale_checks()
	_spell_fx_checks()
	_title_checks()
	_gap_checks()
	_hollow_checks()
	_stray_wall_checks()
	_monster_title_checks()
	_climate_checks()
	_building_checks()
	_hardening_checks()
	_chase_checks()
	_monster_catalog_checks()
	_pvp_and_spell_checks()
	_dungeon_task_and_region_checks()
	_spawn_and_rest_checks()
	_armor_and_control_checks()
	_rune_checks()
	_map_guidance_checks()
	_trophy_steal_checks()
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
	check(world.move(2, Vector2i.DOWN, 0.2)["ok"], "next step after cooldown")
	check(world.occupied(Vector2i(6, 6), 0.21), "origin reserved in transit (for spawns and monsters)")
	check(world.move(1, Vector2i.RIGHT, 0.21)["ok"] and world.players[1]["cell"] == Vector2i(6, 6),
		"players walk through each other: only the land blocks them")
	var through: int = Combat.new(world, 3).spawn_monster("field_vole", 1, Vector2i(7, 6), 0.0)
	check(world.move(1, Vector2i.RIGHT, 0.4)["ok"] and world.players[1]["cell"] == world.monsters[through]["cell"],
		"players walk through monsters")
	world.monsters.erase(through)
	world.players[1]["cell"] = Vector2i(5, 6)
	world.players[1]["from"] = Vector2i(5, 6)
	world.players[1]["next_move"] = 0.0
	var transit: Dictionary = world.export_player(2, 0.29)
	check(is_equal_approx(transit["remaining"], 0.09), "late join sees remaining movement")
	check(transit["from"] == Vector2i(6, 6), "late join sees movement origin")
	check(world.move(1, Vector2i.RIGHT, 0.4)["ok"], "origin released after movement")
	check(world.players[1]["facing"] == Vector2i.RIGHT, "authoritative facing")
	check(World.SPAWNS.size() == World.MAX_PLAYERS and World.MAX_PLAYERS == 24, "one spawn per player, twenty-four players")
	for id: int in range(3, World.MAX_PLAYERS + 1):
		check(world.add_player(id, 0.6), "spawn up to the player cap")
	check(not world.add_player(World.MAX_PLAYERS + 1, 0.6), "twenty-four-player cap")
	var cells: Dictionary = {}
	for id: int in world.players:
		cells[world.players[id]["cell"]] = true
	check(cells.size() == World.MAX_PLAYERS, "twenty-four unique spawn cells")
	world.remove_player(3)
	check(not world.players.has(3), "disconnect removes player")
	check(world.add_player(World.MAX_PLAYERS + 1, 0.6), "disconnect releases spawn")
	check(not world.toggle_equipment(999, "helmet", 0.0)["ok"], "unknown equipment owner rejected")
	check(not world.toggle_equipment(2, "unknown", 0.0)["ok"], "unknown slot rejected")
	check(world.toggle_equipment(2, "helmet", 0.6)["ok"], "equip sample")
	check(world.players[2]["equipment"]["helmet"] == "ringmail_coif", "server picks item")
	check(not world.toggle_equipment(2, "helmet", 0.61)["ok"], "equipment cooldown")
	var snapshot: Dictionary = world.snapshot(0.7)
	check(snapshot[2]["equipment"]["helmet"] == "ringmail_coif", "late-join equipment")
	snapshot[2]["equipment"].erase("helmet")
	check(world.players[2]["equipment"].has("helmet"), "snapshot cannot mutate server equipment")
	check(world.toggle_equipment(2, "helmet", 0.8)["ok"], "unequip sample")
	check(not world.players[2]["equipment"].has("helmet"), "unequip removes visual metadata")
	var walls := World.new()
	walls.add_player(1, 0.0)
	var wall: Vector2i = _test_wall()
	walls.players[1]["cell"] = wall + Vector2i.UP
	walls.players[1]["from"] = wall + Vector2i.UP
	check(not walls.move(1, Vector2i.DOWN, 0.0)["ok"], "map collision during movement")
	check(walls.players[1]["cell"] == wall + Vector2i.UP, "blocked move preserves state")
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
	_adventurer_checks()
	_quest_hub_and_lexicon_checks()
	_bot_checks()
	_bot_loot_checks()
	_armor_type_checks()
	print("BRIMHOLT_RULES: %d checks, %d failures (%d cases)" % [checks, failures, cases])
	quit(0 if failures == 0 else 1)


## New characters start as Adventurers: shared tier-1 gear and spells, a level cap, then the
## trial and a permanent vocation from a trainer in Cinder Crossing's training hall.
func _adventurer_checks() -> void:
	var trainers: Dictionary = {}
	var hall: Array = []
	for trainer: String in Quests.TRAINERS:
		var giver: Dictionary = World.QUEST_GIVERS.get(trainer, {})
		trainers[Quests.TRAINERS[trainer][0]] = trainer
		check(not giver.is_empty() and giver["services"] == ["vocation", "runes"] and giver["tasks"].is_empty()
			and giver["place"] == "Cinder Crossing" and World.ROOM_AT.has(giver["cell"]), "%s teaches in a Cinder Crossing building" % trainer)
		hall.append(World.ROOM_AT.get(giver.get("cell", Vector2i(-1, -1)), -1))
	check(trainers.keys().size() == Balance.VOCATIONS.size() and trainers.has_all(Balance.VOCATIONS.keys())
		and hall.count(hall[0]) == hall.size(), "one trainer per vocation, together in the training hall")
	var trial: Dictionary = Quests.TASKS[Quests.TRIAL_TASK]
	var trial_levels: Array = World.MONSTER_SPAWNS.filter(func(spawn: Dictionary) -> bool: return spawn["monster"] == trial["monster"]) \
		.map(func(spawn: Dictionary) -> int: return spawn["level"])
	check(World.QUEST_GIVERS.get(trial["giver"], {}).get("tasks", []).has(Quests.TRIAL_TASK) and trial["level"] in trial_levels
		and Quests.reward(Quests.TRIAL_TASK)["experience"] > 0 and trial["level"] <= Balance.ADVENTURER_MAX_LEVEL,
		"the trial master hunts a nearby overworld monster within an Adventurer's reach and pays experience")

	var world := World.new()
	var combat := Combat.new(world, 5)
	world.monsters.clear()
	check(world.add_player(1, 0.0, Balance.ADVENTURER) and not world.add_player(2, 0.0, "pirate"), "Adventurer is a starting vocation")
	var adventurer: Dictionary = world.players[1]
	check(adventurer["backpack"].slice(0, 6) == World.START_KITS[Balance.ADVENTURER]
		and world.player_stats(1)["health"] == Balance.base_stats(1, Balance.ADVENTURER)["health"], "Adventurers start with a kit and their own profile")
	check(World.requirement_error("willow_shortbow", 1, Balance.ADVENTURER).is_empty()
		and World.requirement_error("kindling_wand", 1, Balance.ADVENTURER).is_empty()
		and not World.requirement_error("flint_hatchet", 5, Balance.ADVENTURER).is_empty(),
		"Adventurers try every vocation's tier-1 gear, and nothing vocation-bound beyond it")
	check(Combat.attack_style(Balance.ADVENTURER, {"main_hand": "willow_shortbow"}) == "paladin"
		and Combat.attack_style(Balance.ADVENTURER, {}) == "knight" and Combat.attack_style("druid", {"main_hand": "copper_blade"}) == "druid",
		"an Adventurer's weapon decides its reach and missile")
	check(Spells.for_vocation(Balance.ADVENTURER) == ["light_heal"] and not Spells.allows("brutal_blow", Balance.ADVENTURER),
		"Adventurers only know the spells every vocation shares")
	adventurer["mana"] = 999
	check(combat.cast(1, "light_heal", 1.0)["ok"] and not combat.cast(1, "brutal_blow", 5.0)["ok"], "Adventurers cast shared spells only")
	var events: Array = []
	combat.grant_experience(1, Combat.total_experience(20, 0), events)
	check(adventurer["level"] == Balance.ADVENTURER_MAX_LEVEL
		and adventurer["experience"] == Balance.experience_to_next(Balance.ADVENTURER_MAX_LEVEL) - 1
		and events.any(func(event: Dictionary) -> bool: return event["kind"] == "message" and event["text"].contains("without a class")),
		"Adventurers stop at level %d and are told why" % Balance.ADVENTURER_MAX_LEVEL)
	events.clear()
	combat.grant_experience(1, 100, events)
	check(not events.any(func(event: Dictionary) -> bool: return event["kind"] == "message"), "the level cap is announced once")
	# Choosing: in range, trial passed, and the level reached; then for good.
	var trainer: String = trainers["paladin"]
	var front: Vector2i = World.QUEST_GIVERS[trainer]["cell"] + World.QUEST_GIVERS[trainer]["facing"]
	check(world.choose_vocation(1, trainer, 2.0)["reason"] == "Walk closer to a trainer", "trainers teach only those beside them")
	_place(world, 1, front)
	check(world.choose_vocation(1, "trial_master", 2.0)["reason"] == "Walk closer to a trainer"
		and world.choose_vocation(1, 7, 2.0)["reason"] == "Walk closer to a trainer", "only trainers teach vocations")
	check(world.choose_vocation(1, trainer, 2.0)["reason"].begins_with("Pass"), "the trial comes first")
	adventurer["done_tasks"][Quests.TRIAL_TASK] = true
	adventurer["level"] = Balance.CHOOSE_LEVEL - 1
	check(world.choose_vocation(1, trainer, 2.0)["reason"] == "Reach level %d first" % Balance.CHOOSE_LEVEL, "choosing needs a level")
	adventurer["level"] = Balance.CHOOSE_LEVEL
	var full: Array = adventurer["backpack"].duplicate()
	adventurer["backpack"].fill("rat_tail")
	check(world.choose_vocation(1, trainer, 2.0)["reason"].begins_with("Make room") and adventurer["vocation"] == Balance.ADVENTURER,
		"the trainer's gift needs backpack room")
	adventurer["backpack"] = full
	var chosen: Dictionary = world.choose_vocation(1, trainer, 2.0)
	check(chosen["ok"] and adventurer["vocation"] == "paladin" and adventurer["backpack"].count("willow_shortbow") == 1
		and adventurer["backpack"].count("oak_buckler") == 1 and adventurer["health"] == world.player_stats(1)["health"],
		"a trainer makes you their vocation and hands you only the starting gear you lack")
	check(not adventurer["backpack"].has("ember_cap") and not adventurer["backpack"].has("copper_blade")
		and adventurer["backpack"].has("ringmail_coif") and adventurer["backpack"].has("ringmail_striders")
		and adventurer["backpack"].count("") == World.BACKPACK_SIZE - World.start_kit("paladin").size(),
		"the trainer trades the starter pieces the class cannot use for its own, so a full starter pack fits")
	check(not world.choose_vocation(1, trainers["knight"], 2.0)["ok"], "a vocation is permanent")
	combat.grant_experience(1, Combat.total_experience(12, 0), [])
	check(adventurer["level"] > Balance.ADVENTURER_MAX_LEVEL, "with a vocation you level past the cap")
	check(CharacterStore.saved_vocation({"vocation": Balance.ADVENTURER}) == Balance.ADVENTURER
		and CharacterStore.saved_vocation({"vocation": "pirate"}).is_empty(), "saves keep Adventurers and refuse unknown vocations")


## Quest hubs leave no level without a task, givers mark what they have for you, turning in
## points to the next stop, and the lexicon reports the drop tables the server rolls.
func _quest_hub_and_lexicon_checks() -> void:
	for task: String in Quests.TASKS:
		var band: Vector2i = World.task_levels(task)
		var definition: Dictionary = Quests.TASKS[task]
		check(band.x >= 1 and band.y >= band.x and World.QUEST_GIVERS.has(definition["giver"]), "%s has placed monsters and a giver" % task)
		if definition.has("level"):
			check(definition["level"] >= band.x and definition["level"] <= band.y, "%s pays for a level its monsters have" % task)
	for level: int in range(1, Balance.MAX_LEVEL + 1):
		var state: Dictionary = {"level": level, "vocation": "knight" if level > Balance.ADVENTURER_MAX_LEVEL else Balance.ADVENTURER,
			"tasks": {}, "done_tasks": []}
		check(not World.next_task(state).is_empty(), "a task fits at every level (%d)" % level)
	check(World.next_task({"level": 12, "vocation": "knight", "tasks": {}, "done_tasks": []}) == "wolf_winter"
		and World.next_task({"level": 12, "vocation": "knight", "tasks": {}, "done_tasks": ["wolf_winter", "lodge_wolves"]})
		== "highway_robbers", "the suggestion moves to the best remaining fit")
	_hunters_lodge_checks()
	_profession_data_checks()
	_gathering_checks()
	_crafting_checks()
	_bag_checks()
	_character_profile_checks()
	_solo_checks()
	check(World.next_task({"level": 3, "vocation": "knight", "tasks": {}, "done_tasks": []}) != Quests.TRIAL_TASK
		and World.task_open(Quests.TRIAL_TASK, {"vocation": Balance.ADVENTURER, "tasks": {}, "done_tasks": []}),
		"only Adventurers are pointed to the trial")
	var hub: Dictionary = {"level": 12, "vocation": "knight", "tasks": {}, "done_tasks": [], "trophies": {}}
	check(World.quest_mark("harbourmaster_ilse", hub) == "!" and World.quest_mark("huntmaster_corvel", hub) == ""
		and World.quest_mark("trainer_knight", hub) == "" and World.quest_mark("relic_keeper", hub) == "",
		"givers mark only what fits you")
	hub["tasks"] = {"wolf_winter": 20}
	check(World.quest_mark("harbourmaster_ilse", hub) == "?", "a finished task marks its giver ?")
	hub["tasks"] = {}
	hub["done_tasks"] = ["wolf_winter", "highway_robbers"]
	hub["trophies"] = {"morvain": 1}
	check(World.quest_mark("harbourmaster_ilse", hub) == "" and World.quest_mark("relic_keeper", hub) == "?",
		"a done giver loses its mark; a trophy marks its relic keeper")
	check(World.quest_mark("trainer_druid", {"level": 5, "vocation": Balance.ADVENTURER, "done_tasks": [Quests.TRIAL_TASK]}) == "!",
		"trainers mark a qualified Adventurer")
	# Choosing a class comes first: an Adventurer is offered only the trial and no dungeon lets them in.
	var fresh: Dictionary = {"level": 1, "vocation": Balance.ADVENTURER, "tasks": {}, "done_tasks": [], "trophies": {}}
	check(World.next_task(fresh) == Quests.TRIAL_TASK and Quests.TASKS.keys().all(func(task: String) -> bool:
		return World.task_open(task, fresh) == (task == Quests.TRIAL_TASK)), "an Adventurer is offered the trial and nothing else")
	check(World.quest_mark("warden_brask", fresh) == "" and World.quest_mark("cellarmaster_pell", fresh) == "",
		"other givers show no mark to an Adventurer")
	fresh["done_tasks"] = [Quests.TRIAL_TASK]
	check(World.next_task(fresh).is_empty(), "after the trial, the next step is a trainer, not a task")
	var gate := World.new()
	var gate_combat := Combat.new(gate, 4)
	gate.add_player(1, 0.0, Balance.ADVENTURER)
	var brask: Dictionary = World.QUEST_GIVERS["warden_brask"]
	_place(gate, 1, brask["cell"] + brask["facing"])
	check(gate_combat.task_action(1, "warden_brask", "boar_cull", "accept", 1.0)["reason"] == Combat.CHOOSE_CLASS_FIRST,
		"givers send an Adventurer to choose a class first")
	var stairway: Vector2i = World.DUNGEON_ENTRANCES.keys()[0]
	var gate_instances := Instances.new(gate, gate_combat)
	_place(gate, 1, stairway)
	var bounced: Array = gate_instances.enter(1, World.DUNGEON_ENTRANCES[stairway], 2.0)
	check(World.dungeon_at(gate.players[1]["cell"]).is_empty()
		and bounced.any(func(event: Dictionary) -> bool: return event["kind"] == "message" and String(event["text"]).begins_with("Choose your class")),
		"dungeon stairways turn Adventurers away")
	var world := World.new()
	var combat := Combat.new(world, 3)
	world.monsters.clear()
	world.add_player(1, 0.0, "knight")
	var player: Dictionary = world.players[1]
	player["level"] = 10
	_place(world, 1, World.QUEST_GIVERS["harbourmaster_ilse"]["cell"] + World.QUEST_GIVERS["harbourmaster_ilse"]["facing"])
	combat.task_action(1, "harbourmaster_ilse", "highway_robbers", "accept", 1.0)
	player["tasks"]["highway_robbers"] = 20
	var turned: Dictionary = combat.task_action(1, "harbourmaster_ilse", "highway_robbers", "complete", 2.0)
	var texts: Array = turned["events"].filter(func(event: Dictionary) -> bool: return event["kind"] == "message") \
		.map(func(event: Dictionary) -> String: return event["text"])
	check(turned["ok"] and texts.size() == 1 and not texts[0].contains("Next:"), "a giver with more work for you does not send you away")
	player["done_tasks"]["wolf_winter"] = true
	player["done_tasks"].erase("highway_robbers")
	player["level"] = 14
	player["tasks"]["highway_robbers"] = 20
	turned = combat.task_action(1, "harbourmaster_ilse", "highway_robbers", "complete", 3.0)
	texts = turned["events"].filter(func(event: Dictionary) -> bool: return event["kind"] == "message").map(
		func(event: Dictionary) -> String: return event["text"])
	check(texts.any(func(text: String) -> bool: return text.contains("Next: Fenwarden Ostrel in Reedmere")),
		"turning in a hub's last task names the next giver (%s)" % [texts])
	# Lexicon.
	var kinds: Array = Lexicon.entries().map(func(found: Dictionary) -> String: return found["kind"])
	check(kinds.size() == Monsters.MONSTERS.size() and Monsters.MONSTERS.keys().all(func(kind: String) -> bool: return kind in kinds),
		"the lexicon lists every monster once")
	for found: Dictionary in Lexicon.entries():
		check(found["drops"] == Monsters.LOOT[found["kind"]] and not found["places"].is_empty() and found["levels"].x >= 1
			and found["gear"] == Combat.GEAR_DROP_CHANCE[found["rank"]], "%s's lexicon entry matches its loot and spawns" % found["kind"])
	var spider: Dictionary = Lexicon.entry("cave_spider")
	check(spider["places"] == ["Silkhollow (dungeon)"] and spider["tasks"] == ["silk_harvest"] and Lexicon.matches(spider, "SILK")
		and Lexicon.matches(spider, "spider silk") and not Lexicon.matches(spider, "golem"), "lexicon search finds names, places, and drops")
	var vole: Dictionary = Lexicon.entry("field_vole")
	check(vole["gold"] == roundi(Balance.coins_per_kill(1) * World.ITEMS["gold_coins"]["gold"]) and vole["places"] == ["Cinder Meadows"],
		"the lexicon's gold matches the expected coin piles")


## An open cell in a zone (PvP zone when pvp is true) with walkable ground all around.
func _open_cell(pvp: bool) -> Vector2i:
	for zone: Dictionary in World.ZONES:
		if zone["pvp"] != pvp or zone["town"] or zone.get("underground", false):
			continue
		var rect: Rect2i = zone["rect"]
		for y: int in range(rect.position.y + 4, rect.end.y - 4):
			for x: int in range(rect.position.x + 4, rect.end.x - 4):
				var clear: bool = true
				for dy: int in range(-3, 4):
					for dx: int in range(-3, 4):
						clear = clear and World.walkable(Vector2i(x + dx, y + dy)) and World.zone_at(Vector2i(x + dx, y + dy)) == zone
				if clear:
					return Vector2i(x, y)
	return Vector2i(-1, -1)


## Runs bots and combat together for `seconds`, from `start`; returns the end time.
func _run_bots(bots: Bots, combat: Combat, start: float, seconds: float) -> float:
	var now: float = start
	while now < start + seconds:
		now += Combat.TICK_SECONDS
		bots.tick(now)
		combat.tick(now)
	return now


## Host-side player bots: hunting, PvP, self-defence, dummies, resources, death, and slots.
func _bot_checks() -> void:
	var kit: Dictionary = Bots.gear(30, "knight")
	check(kit.has("helmet") and kit.has("armor") and kit.has("main_hand") and kit.has("off_hand") and kit.has("necklace")
		and kit.has("ring_1") and kit.values().all(func(kind: String) -> bool: return World.requirement_error(kind, 30, "knight").is_empty()),
		"bots wear the best regular gear their level and vocation allow")
	var arena: Vector2i = _open_cell(true)
	var field: Vector2i = Vector2i(-1, -1)
	for spawn: Dictionary in World.MONSTER_SPAWNS:
		var spot: Vector2i = spawn["cell"] + Vector2i(0, 5)
		if World.zone_at(spot).is_empty() and World.walkable(spot) and World.walkable(spot + Vector2i(0, 3)) and field.x < 0:
			field = spot
	check(arena.x >= 0 and field.x >= 0, "bot test sites exist")
	# Hunting: a hunter walks to a monster near its post, kills it, and earns experience.
	var world := World.new()
	var combat := Combat.new(world, 9)
	var bots := Bots.new(world, combat)
	world.monsters.clear()
	var hunter: int = bots.add("knight", 20, "hunter", field, 0.0)["id"]
	var prey: int = combat.spawn_monster("grey_wolf", 12, world.players[hunter]["cell"] + Vector2i(0, 3), 0.0)
	world.monsters[prey]["next_attack"] = INF
	var now: float = _run_bots(bots, combat, 0.0, 30.0)
	check(world.players[hunter].get("bot", false) and world.export_player(hunter, now)["bot"] and not world.monsters.has(prey)
		and world.players[hunter]["experience"] > 0, "a hunter bot hunts monsters near its post")
	# PvP: a PvP bot attacks a player in a PvP zone (and takes a white skull) but not outside one.
	var pvp_world := World.new()
	var pvp_combat := Combat.new(pvp_world, 4)
	var pvp_bots := Bots.new(pvp_world, pvp_combat)
	pvp_world.monsters.clear()
	pvp_world.add_player(1, 0.0, "knight")
	pvp_world.players[1]["level"] = 40
	pvp_world.clamp_vitals(1)
	_place(pvp_world, 1, arena)
	var full_health: int = pvp_world.player_stats(1)["health"]
	pvp_world.players[1]["health"] = full_health
	var hunter_pvp: int = pvp_bots.add("paladin", 40, "pvp", arena + Vector2i(3, 0), 0.0)["id"]
	var passive: int = pvp_bots.add("knight", 40, "hunter", arena + Vector2i(-3, 0), 0.0)["id"]
	var dummy: int = pvp_bots.add("druid", 40, "dummy", arena + Vector2i(0, 3), 0.0)["id"]
	now = _run_bots(pvp_bots, pvp_combat, 0.0, 6.0)
	check(pvp_world.players[hunter_pvp]["target"] == 1 and pvp_world.players[1]["health"] < full_health
		and pvp_world.players[hunter_pvp]["skull"] == "white", "a PvP bot attacks players in a PvP zone and takes a white skull")
	check(pvp_world.players[passive]["target"] == 0 and pvp_world.players[dummy]["target"] == 0,
		"hunter bots and dummies leave players alone")
	# Self-defence: attacking the hunter bot makes it fight back, without a skull; the dummy never does.
	pvp_combat.set_target(1, passive, now)
	now = _run_bots(pvp_bots, pvp_combat, now, 4.0)
	check(pvp_world.players[passive]["target"] == 1 and pvp_world.players[passive]["skull"].is_empty(),
		"a hunter bot fights back in self-defence without a skull")
	pvp_combat.set_target(1, dummy, now)
	now = _run_bots(pvp_bots, pvp_combat, now, 4.0)
	check(pvp_world.players[dummy]["target"] == 0 and pvp_world.players[dummy]["health"] < pvp_world.player_stats(dummy)["health"],
		"a training dummy takes hits and never strikes back")
	# Outside PvP zones nobody is attacked.
	var calm_world := World.new()
	var calm_combat := Combat.new(calm_world, 4)
	var calm_bots := Bots.new(calm_world, calm_combat)
	calm_world.monsters.clear()
	calm_world.add_player(1, 0.0, "knight")
	_place(calm_world, 1, field)
	var calm: int = calm_bots.add("sorcerer", 40, "pvp", field + Vector2i(2, 0), 0.0)["id"]
	_run_bots(calm_bots, calm_combat, 0.0, 3.0)
	check(calm_world.players[calm]["target"] == 0, "a PvP bot attacks no one outside PvP zones")
	# Resources: a wounded bot drinks or heals; a ranged bot steps back from a melee foe.
	var medic: Dictionary = calm_world.players[calm]
	medic["health"] = roundi(calm_world.player_stats(calm)["health"] * 0.2)
	var low: int = medic["health"]
	_run_bots(calm_bots, calm_combat, 10.0, 1.0)
	check(medic["health"] > low and World.count_of(medic["backpack"][0]) < Bots.POTIONS, "a wounded bot drinks a potion like the fight simulator")
	# Mana: a bot low on mana, or too short for its strongest ready spell, drinks a mana potion,
	# on its own cooldown beside the health potion.
	medic["health"] = roundi(calm_world.player_stats(calm)["health"] * 0.2)
	medic["mana"] = roundi(calm_world.player_stats(calm)["mana"] * 0.4)
	var mana_before: int = World.count_of(medic["backpack"][1])
	var health_before: int = World.count_of(medic["backpack"][0])
	calm_bots.use_resources(calm, 40.0, [])
	check(World.count_of(medic["backpack"][1]) == mana_before - 1 and World.count_of(medic["backpack"][0]) == health_before - 1,
		"a hurt bot at 40% mana drinks a health and a mana potion in the same moment")
	var foe: int = calm_combat.spawn_monster("thornback_boar", 5, medic["cell"] + Vector2i(1, 0), 20.0)
	calm_world.monsters[foe]["next_move"] = INF
	calm_world.monsters[foe]["next_attack"] = INF
	_run_bots(calm_bots, calm_combat, 20.0, 0.5)
	check(Combat.distance(medic["cell"], calm_world.monsters[foe]["cell"]) >= 2 if calm_world.monsters.has(foe) else true,
		"a ranged bot backs away from a monster beside it")
	# Death: a killed bot comes back at its post with its level, gear, and potions.
	var events: Array = []
	var post: Vector2i = calm_bots.bots[calm]["post"]
	calm_combat._kill_player(calm, 30.0, events)
	_run_bots(calm_bots, calm_combat, 30.0, 1.0)
	var waiting: bool = calm_bots.bots[calm]["restore_at"] > 0.0 and Combat.distance(medic["cell"], post) > 2
	_run_bots(calm_bots, calm_combat, 31.0, Bots.RESTORE_SECONDS + 1.0)
	check(waiting and Combat.distance(medic["cell"], post) <= 2 and medic["level"] == 40 and medic["equipment"] == Bots.gear(40, "sorcerer")
		and medic["health"] == calm_world.player_stats(calm)["health"], "a dead bot is restored at its post")
	# Slots: bots count toward the player limit and free theirs when removed.
	var full := World.new()
	var full_bots := Bots.new(full, Combat.new(full, 1))
	var added: Array[int] = []
	for index: int in World.MAX_PLAYERS:
		added.append(full_bots.add("knight", 10, "dummy", World.SPAWNS[0], 0.0).get("id", 0))
	check(not full_bots.add("knight", 10, "dummy", World.SPAWNS[0], 0.0)["ok"] and not full.add_player(5, 0.0, "knight"),
		"bots count toward the player limit")
	full_bots.remove(added[0])
	check(full.add_player(5, 0.0, "knight") and not full_bots.is_bot(added[0]) and full.players.size() == World.MAX_PLAYERS,
		"removing a bot frees its slot")
	check(not full_bots.add("pirate", 10, "dummy", World.SPAWNS[0], 0.0)["ok"] and not full_bots.add("knight", 10, "berserk", World.SPAWNS[0], 0.0)["ok"],
		"bots need a real vocation and stance")


## Bot loot (game/core/bot_loot.gd): kills claim their loot for who earned them; bots collect only
## what their own group earned, leave what does not fit, give up on stacks they cannot reach, and
## sell at a vendor when nearly full.
func _bot_loot_checks() -> void:
	var field: Vector2i = Vector2i(-1, -1)
	for spawn: Dictionary in World.MONSTER_SPAWNS:
		var spot: Vector2i = spawn["cell"] + Vector2i(0, 5)
		if World.zone_at(spot).is_empty() and World.walkable(spot) and World.walkable(spot + Vector2i(0, 2)) and field.x < 0:
			field = spot
	var world := World.new()
	var combat := Combat.new(world, 17)
	var bots := Bots.new(world, combat)
	world.monsters.clear()
	var hunter: int = bots.add("knight", 20, "hunter", field, 0.0)["id"]
	var me: Dictionary = world.players[hunter]
	# A kill claims every tile its loot spilled onto for the players credited with it.
	# Level 40: Balance.coins_per_kill is 1.0, so the kill always drops gold as well as items.
	var prey: int = combat.spawn_monster("grey_wolf", 40, me["cell"] + Vector2i(0, 2), 0.0)
	world.monsters[prey]["damage_by"] = {hunter: 100}
	var events: Array = []
	combat._kill_monster(prey, 1.0, events)
	var claimed: Array = combat.loot_claims.keys()
	check(not claimed.is_empty() and claimed.all(func(cell: Vector2i) -> bool:
		return combat.loot_claims[cell]["owners"].has(hunter) and not world.ground.get(cell, []).is_empty()),
		"a kill claims its spilled loot for the players credited with it")
	# The hunter collects all of it: gold into the purse, items into the backpack.
	var gold: int = me["gold"]
	var now: float = _run_bots(bots, combat, 1.0, 12.0)
	check(claimed.all(func(cell: Vector2i) -> bool: return world.ground.get(cell, []).is_empty()) and me["gold"] > gold,
		"a bot collects the loot its kills dropped")
	# Loot a human player helped earn is left for them; so is loot that does not fit.
	world.add_player(1, now, "knight")
	_place(world, 1, field + Vector2i(4, 0))
	var material: String = ""
	for kind: String in World.ITEMS:
		if material.is_empty() and World.ITEMS[kind].has("value") and World.stackable(kind) and Economy.sell_price(kind) > 0:
			material = kind
	var shared: Vector2i = me["cell"] + Vector2i(1, 0)
	world.ground[shared] = [World.make_entry(material, 3)]
	combat.loot_claims[shared] = {"owners": {1: true, hunter: true}, "until": now + 60.0}
	var full: Vector2i = me["cell"] + Vector2i(-1, 0)
	world.ground[full] = ["rusted_breastplate"]
	combat.loot_claims[full] = {"owners": {hunter: true}, "until": now + 60.0}
	var kept: Array = me["backpack"].duplicate()
	for index: int in me["backpack"].size():
		if me["backpack"][index].is_empty():
			me["backpack"][index] = "copper_blade"
	now = _run_bots(bots, combat, now, 3.0)
	check(world.ground[shared] == [World.make_entry(material, 3)], "bots leave loot a human player helped earn")
	check(world.ground[full] == ["rusted_breastplate"], "loot that does not fit the backpack stays on the ground")
	check(BotLoot.fits(me, "gold_coins#4") and not BotLoot.fits(me, "rusted_breastplate"), "gold always fits; gear needs a free slot")
	me["backpack"] = kept
	# A stack the bot makes no progress on is given up while its claim lasts.
	var bot: Dictionary = bots.bots[hunter]
	_place(world, hunter, full + Vector2i(0, 1))
	bot["last_cell"] = me["cell"]  # a placed bot is not a dead one (Bots.tick reads a jump as a death)
	var chosen: Vector2i = bots.loot.choose_stack(hunter, now)
	bot["loot"] = {"cell": full, "since": now - BotLoot.GIVE_UP_SECONDS - 1.0}
	var gave_up: bool = not bots.loot.collect(hunter, now, [])
	check(chosen == full and gave_up and bot["skip"].has(full) and bots.loot.choose_stack(hunter, now) != full,
		"a bot gives up on a stack it has made no progress on and skips it")
	# Who loots: hunters, PvP bots, and rivals; never companions or dummies.
	check(BotLoot.loots({"stance": "rival"}) and BotLoot.loots({"stance": "pvp"}) and not BotLoot.loots({"stance": "companion"})
		and not BotLoot.loots({"stance": "dummy"}), "only roaming bots loot")
	# Claims lapse, and are swept.
	combat.loot_claims[full]["until"] = now - 1.0
	combat.tick(now + Combat.LOOT_SWEEP_SECONDS + 1.0)
	check(not combat.loot_claims.has(full), "lapsed loot claims are swept")
	# Selling: nearly full of materials and gear, the hunter travels to a vendor, sells what vendors
	# buy (not its potions), and returns to its post.
	world.remove_player(1)
	world.ground.erase(shared)
	world.ground.erase(full)
	combat.loot_claims.clear()
	for index: int in range(2, me["backpack"].size()):
		me["backpack"][index] = World.make_entry(material, 10) if index % 2 == 0 else "copper_blade"
	check(bots.loot.wants_to_sell(hunter), "a nearly full bot with something to sell wants a vendor")
	gold = me["gold"]
	var potions: int = World.count_of(me["backpack"][0])
	now = _run_bots(bots, combat, now + 20.0, 90.0)
	check(me["gold"] > gold and BotLoot.sellable_index(me) < 0 and World.count_of(me["backpack"][0]) == potions,
		"the bot sells everything a vendor buys and keeps its potions")
	check(bots.bots[hunter]["trip"].is_empty() and Combat.distance(me["cell"], bots.bots[hunter]["post"]) <= 2,
		"after selling, the bot goes back to its post")


## Each class wears one armor type: Warriors plate, Hunters mail, Druids leather, Sorcerers cloth.
func _armor_type_checks() -> void:
	check(World.requirement_error("rusted_breastplate", 50, "sorcerer") == "The Rusted breastplate is plate: only Warriors wear it"
		and World.requirement_error("linen_robe", 50, "knight").contains("only Sorcerers")
		and World.requirement_error("ringmail_coif", 50, "druid").contains("only Hunters")
		and World.requirement_error("ember_cap", 50, "paladin").contains("only Druids"), "each class is refused the other armor types")
	check(World.requirement_error("abyssal_plate", 50, "sorcerer").is_empty(), "relics fit every class")
	check(World.requirement_error("linen_robe", 1, Balance.ADVENTURER).is_empty()
		and not World.requirement_error("hide_jerkin", 5, Balance.ADVENTURER).is_empty(), "Adventurers try only tier-1 armor of any type")
	for vocation: String in Balance.VOCATIONS:
		var type: String = Balance.ARMOR_OF[vocation]
		for kind: String in World.start_kit(vocation):
			check(World.ITEMS[kind].get("armor", type) == type, "%s starts in %s" % [vocation, type])
		var tiers: Dictionary = {}
		for kind: String in World.ITEMS:
			var item: Dictionary = World.ITEMS[kind]
			if item.get("armor", "") == type and not item.get("loot_only", false) and not Items.mythic(item):
				tiers["%s/%d" % [item["slot"], item["level"]]] = true
		check(tiers.size() == Items.TIER_LEVELS.size() * 4, "%s has a helmet, armor, legs, and boots of every tier" % type)
	# Trainers hand over the class's armor; old saves swap shared pieces for the player's own type.
	var world := World.new()
	world.add_player(1, 0.0, Balance.ADVENTURER)
	var player: Dictionary = world.players[1]
	player["done_tasks"][Quests.TRIAL_TASK] = true
	player["level"] = Balance.CHOOSE_LEVEL
	var trainer: Dictionary = World.QUEST_GIVERS["trainer_sorcerer"]
	_place(world, 1, trainer["cell"] + trainer["facing"])
	check(world.choose_vocation(1, "trainer_sorcerer", 1.0)["ok"] and player["backpack"].has("linen_hat") and player["backpack"].has("linen_robe"),
		"a trainer hands over the class's tier-1 armor")
	player["equipment"] = {"helmet": "ember_cap", "armor": "steel_hauberk"}
	player["backpack"][7] = "embersteel_cuirass"
	CharacterStore.restore(world, 1, {"version": 1, "level": 30, "equipment": player["equipment"].duplicate(),
		"backpack": player["backpack"].duplicate()}, 2.0)
	check(player["equipment"] == {"helmet": "linen_hat", "armor": World.armor_counterpart("steel_hauberk", "sorcerer")}
		and World.ITEMS[player["equipment"]["armor"]]["armor"] == "cloth" and World.ITEMS[player["backpack"][7]]["armor"] == "cloth"
		and World.ITEMS[player["backpack"][7]]["level"] == 30, "a version-1 save swaps shared armor for the class's own type")
	CharacterStore.restore(world, 1, {"version": CharacterStore.VERSION, "level": 30, "equipment": {}, "backpack": ["steel_hauberk"]}, 3.0)
	check(player["backpack"][0] == "steel_hauberk", "newer saves keep spare armor of other types as it is")


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
	var layout: Array = ["dented_iron_helm", "rusted_breastplate", "copper_blade"]
	for index: int in World.BACKPACK_SIZE:
		backpack[index] = layout[index] if index < layout.size() else ""
	check(not bag.export_player(1, 0.0).has("backpack"), "backpack is private by default")
	check(bag.export_player(1, 0.0, true)["backpack"] == backpack, "owner export includes backpack")
	check(not bag.snapshot(0.0, 2)[1].has("backpack"), "snapshot hides other players' backpacks")
	check(bag.snapshot(0.0, 1)[1].has("backpack"), "snapshot includes the viewer's backpack")
	var private_copy: Array = bag.export_player(1, 0.0, true)["backpack"]
	private_copy[0] = "glowcap"
	check(backpack[0] == "dented_iron_helm", "exported backpack cannot mutate server state")

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
	check(backpack[0] == "dented_iron_helm" and equipment.is_empty() and bag.ground_stack(here).is_empty(),
		"rejected item actions change nothing")

	check(act(bag, slot0, slot1)["ok"], "backpack swap")
	check(backpack[0] == "rusted_breastplate" and backpack[1] == "dented_iron_helm", "swap exchanges items")
	check(bag.move_item(1, slot0, slot1, clock + 0.01)["reason"] == "Item cooldown", "item cooldown")
	check(not bag.move_item(1, slot0, slot1, clock + World.ITEM_SECONDS - 0.000001)["ok"], "reject just before item cooldown")
	check(bag.move_item(1, slot0, slot1, clock + World.ITEM_SECONDS)["ok"], "accept exactly at item cooldown")
	clock += World.ITEM_SECONDS
	check(backpack[0] == "dented_iron_helm" and backpack[1] == "rusted_breastplate", "swap back")

	check(act(bag, slot0, {"type": "equipment", "slot": "helmet"})["ok"], "drag to equip")
	check(equipment["helmet"] == "dented_iron_helm" and backpack[0] == "", "equip moves the item out of the backpack")
	var dropped: Dictionary = act(bag, {"type": "backpack", "index": 2}, {"type": "ground", "cell": here})
	check(dropped["ok"] and dropped["ground"] == [here], "drop reports its changed tile")
	check(bag.ground_stack(here) == ["copper_blade"] and backpack[2] == "", "drop places the item on the ground")
	check(act(bag, slot1, {"type": "ground", "cell": here + Vector2i(2, 0)})["reason"] == "That is too far away", "drop reach enforced")
	var stood: Vector2i = bag.players[1]["cell"]
	var wall: Vector2i = _test_wall()
	bag.players[1]["cell"] = wall + Vector2i.UP
	bag.players[1]["from"] = wall + Vector2i.UP
	check(act(bag, slot1, {"type": "ground", "cell": wall}).get("reason", "") == "Items cannot be placed there", "no drops on walls")
	bag.players[1]["cell"] = stood
	bag.players[1]["from"] = stood
	check(act(bag, {"type": "ground", "cell": Vector2i(14, 9)}, {"type": "backpack"})["reason"] == "That is too far away",
		"distant pickup rejected")
	check(bag.ground_stack(Vector2i(14, 9)) == ["iron_coif"], "distant item untouched")
	check(act(bag, slot1, {"type": "ground", "cell": Vector2i(9, 7)})["ok"], "diagonal drop within reach")
	var shifted: Dictionary = act(bag, {"type": "ground", "cell": Vector2i(9, 7)}, {"type": "ground", "cell": here})
	check(shifted["ok"] and shifted["ground"].size() == 2, "ground move reports both tiles")
	check(bag.ground_stack(here) == ["copper_blade", "rusted_breastplate"] and not bag.ground.has(Vector2i(9, 7)),
		"ground move stacks on top and clears the source")
	check(act(bag, {"type": "ground", "cell": here}, {"type": "backpack"})["ok"], "pick up")
	check(backpack[0] == "rusted_breastplate" and bag.ground_stack(here) == ["copper_blade"], "pick up takes the top item")
	check(act(bag, {"type": "ground", "cell": here}, {"type": "equipment", "slot": "main_hand"})["ok"], "equip from ground")
	check(equipment["main_hand"] == "copper_blade" and not bag.ground.has(here), "ground equip clears the tile")
	check(act(bag, {"type": "equipment", "slot": "helmet"}, {"type": "ground", "cell": here})["ok"], "drop worn item")
	check(not equipment.has("helmet") and bag.ground_stack(here) == ["dented_iron_helm"], "worn item reaches the ground")
	bag.ground[Vector2i(9, 6)] = ["flint_hatchet"]
	check(act(bag, {"type": "ground", "cell": Vector2i(9, 6)}, {"type": "equipment", "slot": "main_hand"})["ok"],
		"equip over an occupied slot")
	check(equipment["main_hand"] == "flint_hatchet" and bag.ground_stack(Vector2i(9, 6)) == ["copper_blade"],
		"displaced item returns to the source tile")
	check(act(bag, slot0, {"type": "equipment", "slot": "armor"})["ok"], "equip armor")
	backpack[3] = "iron_cuirass"
	check(act(bag, {"type": "equipment", "slot": "armor"}, {"type": "backpack", "index": 3})["ok"], "swap worn and carried armor")
	check(equipment["armor"] == "iron_cuirass" and backpack[3] == "rusted_breastplate", "worn/carried swap")
	backpack[4] = "glowcap"
	check(act(bag, {"type": "equipment", "slot": "armor"}, {"type": "backpack", "index": 4})["ok"], "unequip onto an unfit item")
	check(backpack[0] == "iron_cuirass" and backpack[4] == "glowcap" and not equipment.has("armor"),
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
	check(equipment["main_hand"] == "flint_hatchet" and bag.ground_stack(here) == ["dented_iron_helm"], "full backpack keeps state")
	while bag.ground[here].size() < World.GROUND_STACK_MAX:
		bag.ground[here].append("iron_sallet")
	backpack[1] = "iron_cuirass"
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
	var ticks: Array[float] = [10.0]
	var move := func(source: Dictionary, target: Dictionary) -> Dictionary:
		ticks[0] += World.ITEM_SECONDS
		return bag.move_item(1, source, target, ticks[0])
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
	var wall: Vector2i = _test_wall()
	player["cell"] = wall + Vector2i.UP
	player["from"] = wall + Vector2i.UP
	check(move.call({"type": "backpack", "index": 0}, {"type": "ground", "cell": wall}).get("reason", "")
		== "Items cannot be placed there", "stack drops still respect walls")
	player["cell"] = here
	player["from"] = here
	bag.ground[here] = ["gold_coins#7"]
	var gold: int = player["gold"]
	check(move.call(tile, auto)["ok"] and player["gold"] == gold + 7 * World.ITEMS["gold_coins"]["gold"]
		and not backpack.has("gold_coins#7"), "a gold stack goes to the purse at full value")
	var stack: Array = ["wolf_pelt#%d" % (World.STACK_MAX - 1)]
	check(World.stack_onto(stack, "wolf_pelt#2") and stack == ["wolf_pelt#99", "wolf_pelt#2"],
		"ground stacks never exceed the stack limit")
	check(World.bound("abyssal_greathelm") and World.bound("abyssal_greathelm#1") and not World.bound("wolf_pelt#3"), "bound checks use the item id")


## Professions: resources, derived recipes, and what crafting may make.
func _profession_data_checks() -> void:
	check(Professions.NAMES.size() == 9 and Professions.GATHERING.size() + Professions.CRAFTING.size() == 9,
		"four gathering and five crafting professions")
	for profession: String in Professions.GATHERING:
		var previous: int = 0
		for band: int in Professions.BAND_LEVELS.size():
			var kind: String = Professions.RESOURCES[profession][band]
			check(World.ITEMS.has(kind) and World.stackable(kind) and World.ITEMS[kind]["value"] > previous
				and not Economy.stock().has(kind), "%s is a stackable resource worth more than the band below" % kind)
			previous = World.ITEMS[kind]["value"]
	var crafted: Dictionary = {}
	for recipe: Dictionary in Crafting.RECIPES.values():
		var output: Dictionary = World.ITEMS[recipe["output"][0]]
		check(Crafting.RECIPES[recipe["id"]] == recipe and recipe["id"] == recipe["output"][0] and recipe["profession"] in Professions.CRAFTING
			and recipe["skill"] >= 1 and recipe["skill"] <= Professions.SKILL_MAX, "%s is a well-formed recipe" % recipe["id"])
		check(not output.get("loot_only", false) and not output.has("glow") and not Items.mythic(output) and not World.bound(recipe["id"]),
			"%s is never hunting, mythic, or relic gear" % recipe["id"])
		var value: int = 0
		for entry: Array in recipe["inputs"]:
			var gathered: bool = false
			for profession: String in Professions.RESOURCES:
				gathered = gathered or entry[0] in Professions.RESOURCES[profession]
			check(gathered and entry[1] >= 1, "%s is made from gathered resources" % recipe["id"])
			value += entry[1]
		if not Professions.gear_profession(output).is_empty():
			crafted[recipe["id"]] = true
			check(recipe["skill"] == maxi(1, output["level"]), "%s needs the skill of its tier" % recipe["id"])
		if not output["slot"].is_empty():
			check(Economy.sell_price(recipe["id"]) <= value * 30, "selling crafted %s pays at most 30 gold per resource" % recipe["id"])
	for kind: String in World.ITEMS:
		if not Professions.gear_profession(World.ITEMS[kind]).is_empty():
			check(crafted.has(kind), "%s can be crafted" % kind)
	for vocation: String in Balance.VOCATIONS:
		for tier: int in Items.TIER_LEVELS:
			for slot: String in ["helmet", "armor", "legs", "boots", "main_hand", "off_hand"]:
				var piece: String = World.class_piece(slot, tier, vocation)
				check(not piece.is_empty() and crafted.has(piece), "%ss can have their tier-%d %s crafted" % [vocation, tier, slot])
	for profession: String in Professions.CRAFTING:
		check(Crafting.RECIPES.values().any(func(recipe: Dictionary) -> bool: return recipe["profession"] == profession),
			"%s has recipes" % profession)
	for kind: String in ["strong_health_potion", "great_mana_potion"]:
		check(not Economy.stock().has(kind) and Crafting.RECIPES.has(kind), "%s is crafted, never sold" % kind)
	check(Economy.stock().has("health_potion") and Economy.stock().has("mana_potion"), "vendors still sell the plain potions")
	check(Combat.potion_timer("great_health_potion") == Combat.potion_timer("health_potion")
		and Combat.potion_timer("strong_mana_potion") == Combat.potion_timer("mana_potion"), "stronger potions share the plain potion's timer")
	# Herb patches grow outside towns and markers, and every band of every gathering skill has reachable nodes.
	for cell: Vector2i in Crafting.HERBS:
		check(World.zone_at(cell).is_empty() and not World.NPC_CELLS.has(cell) and not World.FURNITURE.has(cell)
			and World.walkable(cell), "herb patch %s grows in the open wilds" % cell)
	# Ore veins: only some rock faces, each facing open ground to the south (where its ore shows),
	# outside towns, never crowded together; the rest of the rock is scenery.
	var rock_faces: int = 0
	for cell: Vector2i in Crafting.ORES:
		check(World.terrain(cell) in ["L", "C"] and World.walkable(cell + Vector2i.DOWN) and not World.zone_at(cell).get("town", false)
			and Crafting.ORES[cell] == Crafting.band_at(cell), "ore vein %s shows in a rock face in the wilds" % cell)
		for other: Vector2i in Crafting.ORES:
			check(other == cell or World.chebyshev(cell, other) > Professions.ORE_GAP, "ore veins %s and %s are spread out" % [cell, other])
	for y: int in World.OVERWORLD.size.y:
		for x: int in World.OVERWORLD.size.x:
			var cell := Vector2i(x, y)
			if World.terrain(cell) in ["L", "C"] and World.walkable(cell + Vector2i.DOWN):
				rock_faces += 1
				check(Crafting.ORES.has(cell) == (Crafting.node_at(cell) == "mining"), "only ore veins are mined (%s)" % cell)
	check(Crafting.ORES.size() * 4 < rock_faces and Crafting.ORES.size() > 200,
		"ore veins are a few of the rock faces (%d of %d)" % [Crafting.ORES.size(), rock_faces])
	var found: Dictionary = {}
	for y: int in range(0, World.OVERWORLD.size.y, 1):
		for x: int in range(0, World.OVERWORLD.size.x, 1):
			var cell := Vector2i(x, y)
			var profession: String = Crafting.node_at(cell)
			if profession.is_empty():
				continue
			var band: int = Crafting.HERBS[cell] if profession == "herbalism" else Crafting.band_at(cell)
			if found.has("%s/%d" % [profession, band]):
				continue
			for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.ZERO]:
				if World.walkable(cell + step) and World.zone_at(cell + step).is_empty():
					found["%s/%d" % [profession, band]] = true
	for profession: String in Professions.GATHERING:
		for band: int in Professions.BAND_LEVELS.size():
			check(found.has("%s/%d" % [profession, band]), "%s band %d can be gathered somewhere" % [profession, band])
	# Every town has an artisan in a workshop.
	var artisans: Dictionary = {}
	for id: String in World.TOWNSFOLK:
		var person: Dictionary = World.TOWNSFOLK[id]
		if person["role"] != "artisan":
			continue
		artisans[person["place"]] = true
		var pieces: Array = World.FURNITURE.keys().filter(func(cell: Vector2i) -> bool:
			return World.ROOM_AT.get(cell, -1) == World.ROOM_AT.get(person["cell"], -2)).map(func(cell: Vector2i) -> String:
				return World.FURNITURE[cell])
		check(World.ROOM_AT.has(person["cell"]) and "anvil" in pieces and "workbench" in pieces and pieces.all(
			func(kind: String) -> bool: return kind in SpriteArt.FURNITURE), "%s works in a furnished workshop" % person["name"])
	for zone: Dictionary in World.ZONES:
		if zone["town"]:
			check(artisans.has(zone["name"]), "%s has an artisan" % zone["name"])


## A node of `profession` in `band` with a free walkable tile beside it (outside zones).
func _node_spot(profession: String, band: int) -> Array:
	for y: int in World.OVERWORLD.size.y:
		for x: int in World.OVERWORLD.size.x:
			var cell := Vector2i(x, y)
			if Crafting.node_at(cell) != profession:
				continue
			if (Crafting.HERBS[cell] if profession == "herbalism" else Crafting.band_at(cell)) != band:
				continue
			for step: Vector2i in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
				if World.walkable(cell + step) and World.walkable(cell + step * 2) and World.zone_at(cell + step).is_empty():
					return [cell, cell + step, step]
	return []


func _gathering_checks() -> void:
	var world := World.new()
	world.add_player(1, 0.0, "knight")
	world.add_player(2, 0.0, "druid")
	var crafting := Crafting.new(world, 11)
	var player: Dictionary = world.players[1]
	var rock: Array = _node_spot("mining", 0)
	check(not rock.is_empty(), "a copper rock to test on")
	_place(world, 1, rock[1] + rock[2] * 2)
	check(crafting.start_gather(1, rock[0], 1.0)["reason"] == "Walk closer to gather", "gathering needs the node within reach")
	_place(world, 1, rock[1])
	for bad: Variant in [7, "rock", [1, 2], Vector2(rock[0])]:
		check(not crafting.start_gather(1, bad, 1.0)["ok"], "malformed gather targets are refused")
	check(crafting.start_gather(1, rock[1] + rock[2], 1.0)["reason"] == "There is nothing to gather there"
		or Crafting.node_at(rock[1] + rock[2]) != "", "open ground is not a node")
	check(not crafting.start_gather(3, rock[0], 1.0)["ok"], "unknown players cannot gather")
	var started: Dictionary = crafting.start_gather(1, rock[0], 1.0)
	check(started["ok"] and world.export_player(1, 1.0).has("gathering") and player["facing"] == -rock[2], "gathering starts facing the rock")
	check(crafting.tick(1.0 + Professions.GATHER_SECONDS - 0.1).is_empty() and _count(player["backpack"], "copper_ore") == 0,
		"the work takes GATHER_SECONDS")
	var events: Array = crafting.tick(1.0 + Professions.GATHER_SECONDS)
	var mined: int = _count(player["backpack"], "copper_ore")
	check(mined >= 1 and mined <= 5 and player["gathering"].is_empty() and crafting.worked(rock[0], 5.0)
		and events.any(func(event: Dictionary) -> bool: return event["kind"] == "node" and event["cell"] == rock[0]),
		"finished work yields copper ore and the rock regrows")
	check(player["skills"]["mining"] == [1, Professions.gather_gain(1, 0)], "a gather trains the skill")
	check(crafting.start_gather(1, rock[0], 6.0)["reason"].begins_with("It has been worked"), "a worked node waits to regrow")
	crafting.tick(6.0 + Professions.REGROW_SECONDS)
	check(crafting.start_gather(1, rock[0], 7.0 + Professions.REGROW_SECONDS)["ok"], "a regrown node can be worked again")
	check(world.move(1, rock[2], 7.5 + Professions.REGROW_SECONDS)["ok"] and player["gathering"].is_empty(), "moving cancels gathering")
	crafting.tick(20.0 + Professions.REGROW_SECONDS)
	check(_count(player["backpack"], "copper_ore") == mined, "cancelled work yields nothing")
	_place(world, 1, rock[1])
	# Skill gates the bands: Mining 1 cannot work a band-2 rock.
	var deep: Array = _node_spot("mining", 2)
	_place(world, 1, deep[1])
	check(crafting.start_gather(1, deep[0], 100.0)["reason"].begins_with("Mining 20 needed"), "high bands need the skill")
	player["skills"]["mining"] = [20, 0]
	check(crafting.start_gather(1, deep[0], 100.0)["ok"], "the skill opens the band")
	crafting.tick(100.0 + Professions.GATHER_SECONDS)
	check(_count(player["backpack"], "silver_ore") >= 1, "band-2 rock yields silver ore")
	# A gather that does not all fit fills what it can and the rest stays behind.
	for index: int in player["backpack"].size():
		player["backpack"][index] = "copper_blade"
	player["backpack"][0] = World.make_entry("silver_ore", World.STACK_MAX - 1)
	crafting.tick(200.0 + Professions.REGROW_SECONDS)
	# A seed whose first roll yields at least two, so one cannot fit.
	var lucky: int = 0
	crafting.rng.seed = lucky
	while Professions.gather_count(crafting.rng.randf(), 20, 2) < 2:
		lucky += 1
		crafting.rng.seed = lucky
	crafting.rng.seed = lucky
	check(crafting.start_gather(1, deep[0], 300.0)["ok"], "a nearly full stack can still be added to")
	var partial: Array = crafting.tick(300.0 + Professions.GATHER_SECONDS)
	check(player["backpack"][0] == World.make_entry("silver_ore", World.STACK_MAX) and partial.any(func(event: Dictionary) -> bool:
		return event["kind"] == "message" and event["text"].contains("stay behind")), "a partial gather fills the stack and says so")
	# Yields: 1-5, about 2.1 on average at the band's level and more with mastery.
	var sums: Array[float] = [0.0, 0.0]
	var spread: Dictionary = {}
	for roll: int in 1000:
		var value: float = (roll + 0.5) / 1000.0
		var plain: int = Professions.gather_count(value, 10, 1)
		spread[plain] = true
		sums[0] += plain
		sums[1] += Professions.gather_count(value, 10 + Professions.GATHER_MASTERY, 1)
	check(spread.keys().all(func(count: int) -> bool: return count >= 1 and count <= 5) and spread.size() == 5
		and absf(sums[0] / 1000.0 - 2.12) < 0.05 and absf(sums[1] / 1000.0 - 2.65) < 0.05,
		"gathers yield 1-5, about 2.1 at the band's level and 2.65 mastered (%s)" % [sums])
	var rest: int = 0
	for x: int in 100:
		for y: int in 100:
			rest += 1 if Professions.resting(Vector2i(x, y)) else 0
	check(rest > 850 and rest < 1150, "about one cell in ten rests (%d of 10000)" % rest)
	# A full backpack refuses new resources.
	for index: int in player["backpack"].size():
		player["backpack"][index] = "copper_blade"
	var tree: Array = _node_spot("woodcutting", 0)
	_place(world, 1, tree[1])
	check(crafting.start_gather(1, tree[0], 200.0)["reason"] == "Your backpack is full", "a full backpack refuses a gather")
	# Herbs and water too, and never in a dungeon.
	var herb: Array = _node_spot("herbalism", 0)
	_place(world, 2, herb[1])
	check(crafting.start_gather(2, herb[0], 300.0)["ok"], "herbs are picked")
	crafting.tick(300.0 + Professions.GATHER_SECONDS)
	check(_count(world.players[2]["backpack"], "sunflax") >= 1, "a herb patch yields sunflax")
	var water: Array = _node_spot("fishing", 0)
	_place(world, 2, water[1] + water[2] * 2)
	check(crafting.start_gather(2, water[0], 400.0)["ok"], "fishing reaches water a few tiles away")
	check(Crafting.node_at(Dungeons.origin("silkhollow", 0)) == "", "dungeon rock is not a node")
	# Training: each level needs experience_to_next, and the skill stops at SKILL_MAX.
	var trainee: Dictionary = {"skills": {}}
	check(Crafting.train(trainee, "fishing", Professions.experience_to_next(1)).contains("Fishing rose to 2")
		and trainee["skills"]["fishing"] == [2, 0], "experience raises a skill")
	trainee["skills"]["fishing"] = [Professions.SKILL_MAX, 0]
	Crafting.train(trainee, "fishing", 1000)
	check(trainee["skills"]["fishing"] == [Professions.SKILL_MAX, 0], "skills stop at their maximum")
	check(Professions.gather_gain(1, 0) == 4 and Professions.gather_gain(30, 0) == 0 and Professions.gather_gain(20, 2) == 4,
		"easy bands stop teaching")
	# Skills are saved and sanitized.
	player["skills"] = {"mining": [12, 3], "cooking": [5, 1]}
	var saved: Dictionary = CharacterStore.capture(world, 1, 500.0)
	var restored := World.new()
	restored.add_player(1, 0.0, "knight")
	CharacterStore.restore(restored, 1, JSON.parse_string(JSON.stringify(saved)), 0.0)
	check(restored.players[1]["skills"] == {"mining": [12, 3], "cooking": [5, 1]}, "skills survive a save")
	saved["skills"] = {"mining": [999, 999], "jumping": [9, 0], "fishing": "x", "cooking": [3, -5]}
	var tampered := World.new()
	tampered.add_player(1, 0.0, "knight")
	CharacterStore.restore(tampered, 1, saved, 0.0)
	check(tampered.players[1]["skills"] == {"mining": [Professions.SKILL_MAX, 0], "cooking": [3, 0]}, "saved skills are sanitized")


func _crafting_checks() -> void:
	var world := World.new()
	world.add_player(1, 0.0, "knight")
	var crafting := Crafting.new(world)
	var combat := Combat.new(world, 77)
	var player: Dictionary = world.players[1]
	var artisan: String = ""
	for id: String in World.TOWNSFOLK:
		if World.TOWNSFOLK[id]["role"] == "artisan" and artisan.is_empty():
			artisan = id
	for index: int in player["backpack"].size():
		player["backpack"][index] = ""
	player["backpack"][0] = "copper_ore#10"
	player["backpack"][1] = "pine_log#3"
	_place(world, 1, World.SPAWNS[0] + Vector2i(40, 40))
	check(crafting.craft(1, artisan, "rusted_breastplate", 1, 1.0)["reason"] == "Walk closer to an artisan", "crafting needs an artisan")
	_place(world, 1, _beside(artisan))
	for bad: Array in [[7, "rusted_breastplate", 1], [artisan, "relic", 1], [artisan, "voidrend", 1], [artisan, "rusted_breastplate", 0],
			[artisan, "rusted_breastplate", 99], [artisan, "rusted_breastplate", "1"], ["relic_keeper", "rusted_breastplate", 1]]:
		check(not crafting.craft(1, bad[0], bad[1], bad[2], 1.0)["ok"], "malformed or impossible craft requests are refused")
	var before: Array = player["backpack"].duplicate()
	check(crafting.craft(1, artisan, "bronze_breastplate", 1, 1.0)["reason"] == "Smithing 10 needed" and player["backpack"] == before,
		"recipes above your skill are refused")
	check(crafting.craft(1, artisan, "health_potion", 1, 1.0)["reason"] == "You need more Sunflax" and player["backpack"] == before,
		"missing resources refuse the craft and change nothing")
	var result: Dictionary = crafting.craft(1, artisan, "rusted_breastplate", 1, 1.0)
	check(result["ok"] and _count(player["backpack"], "rusted_breastplate") == 1 and _count(player["backpack"], "copper_ore") == 4
		and _count(player["backpack"], "pine_log") == 1 and int(player["skills"]["smithing"][0]) > 1, "crafting spends resources, makes gear, and trains")
	check(crafting.craft(1, artisan, "rusted_breastplate", 1, 1.2)["reason"] == "You are still working", "crafts are paced")
	player["backpack"][2] = "sunflax#5"
	player["skills"]["alchemy"] = [3, 0]
	result = crafting.craft(1, artisan, "health_potion", 5, 5.0)
	check(result["ok"] and _count(player["backpack"], "health_potion") == 2 and _count(player["backpack"], "sunflax") == 1,
		"a batch makes as many as the resources allow")
	for index: int in player["backpack"].size():
		player["backpack"][index] = "copper_blade"
	player["backpack"][0] = "copper_ore#7"
	player["backpack"][1] = "pine_log#3"
	var full: Array = player["backpack"].duplicate()
	check(crafting.craft(1, artisan, "rusted_breastplate", 1, 9.0)["reason"] == "Your backpack is full" and player["backpack"] == full,
		"gear needs a free slot once its resources are spent")
	player["backpack"][0] = "copper_ore#6"
	check(crafting.craft(1, artisan, "rusted_breastplate", 1, 10.0)["ok"] and player["backpack"][0] == "rusted_breastplate",
		"spent resources make room for the gear")
	# Food and stronger potions.
	player["backpack"][4] = "grilled_perch#2"
	player["backpack"][5] = "strong_health_potion"
	player["backpack"][6] = "health_potion"
	check(combat.drink(1, 4, 20.0)["ok"] and player["fed"]["kind"] == "grilled_perch" and _count(player["backpack"], "grilled_perch") == 1
		and is_equal_approx(combat.meal_bonus(1, 21.0), 0.2) and combat.meal_bonus(1, 20.0 + 901.0) == 0.0,
		"food speeds regeneration for a while")
	check(world.export_player(1, 21.0, true).has("fed") and not world.export_player(1, 21.0, false).has("fed"),
		"only you see your meal")
	player["health"] = 10
	check(combat.drink(1, 5, 30.0)["ok"] and not combat.drink(1, 6, 31.0)["ok"], "a strong potion starts the plain potion's cooldown")
	var hungry := World.new()
	hungry.add_player(1, 0.0, "knight")
	var fed := World.new()
	fed.add_player(1, 0.0, "knight")
	fed.players[1]["fed"] = {"kind": "glimmerfin_feast", "until": 1000.0}
	var hungry_combat := Combat.new(hungry, 3)
	var fed_combat := Combat.new(fed, 3)
	for world_case: World in [hungry, fed]:
		world_case.players[1]["health"] = 1
		world_case.players[1]["mana"] = 0
		world_case.players[1]["next_regen"] = 0.0
	hungry_combat.tick(10.0)
	fed_combat.tick(10.0)
	check(fed.players[1]["health"] > hungry.players[1]["health"] and fed.players[1]["mana"] > hungry.players[1]["mana"],
		"a meal regenerates health and mana faster")


## Solo play: companions form your party at your level and follow you anywhere; rival bands
## take tasks and ambush you in PvP zones; a raid fills to Balance.RAID at level 50.
func _solo_checks() -> void:
	var world := World.new()
	var combat := Combat.new(world, 11)
	var instances := Instances.new(world, combat)
	var bots := Bots.new(world, combat)
	bots.instances = instances
	var solo := Solo.new(world, combat, bots)
	world.add_player(1, 0.0, "knight")
	var me: Dictionary = world.players[1]
	me["level"] = 20
	solo.start(1, 0.0)
	var sim_clock: Array[float] = [0.0]
	var run := func(seconds: float) -> void:
		var end: float = sim_clock[0] + seconds
		while sim_clock[0] < end:
			sim_clock[0] += 0.1
			combat.tick(sim_clock[0])
			bots.tick(sim_clock[0])
			solo.tick(sim_clock[0])
			instances.tick(sim_clock[0])
	var friends: Array[int] = solo.companions()
	var vocations: Array = friends.map(func(id: int) -> String: return world.players[id]["vocation"])
	vocations.sort()
	check(friends.size() == 3 and vocations == ["druid", "paladin", "sorcerer"] and combat.party_members(1).size() == 4
		and friends.all(func(id: int) -> bool: return world.players[id]["level"] == 20 and world.players[id].get("companion", false)),
		"three companions complete your group, in your party at your level")
	check(solo.bands.size() == 2 and solo.bands.values().all(func(band: Dictionary) -> bool:
		return band["members"].size() == 3 and combat.party_members(band["leader"]).size() == 3), "two rival bands of three roam")
	check(world.players.size() <= World.MAX_PLAYERS, "solo stays within the player limit")
	check(world.export_player(friends[0], 0.0).has("name") and combat.describe(friends[0]) == world.players[friends[0]]["name"],
		"bots have names")
	# Following: across the meadow, then in one jump after you travel far.
	var route: Array[Vector2i] = Nav.route(me["cell"], me["cell"] + Vector2i(14, 20))
	check(route.size() > 20, "the navigation grid routes across the overworld")
	for cell: Vector2i in route:
		world.move(1, cell - me["cell"], sim_clock[0])
		run.call(0.2)
	run.call(5.0)
	check(friends.all(func(id: int) -> bool: return Combat.distance(world.players[id]["cell"], me["cell"]) <= Bots.FOLLOW_RANGE + 1),
		"companions keep up with you")
	_place(world, 1, World.QUEST_GIVERS["lodgemaster_varga"]["cell"] + Vector2i(0, 2))
	run.call(1.0)
	check(friends.all(func(id: int) -> bool: return Combat.distance(world.players[id]["cell"], me["cell"]) <= Bots.FOLLOW_RANGE + 2),
		"companions rejoin you after a long journey")
	me["level"] = 23
	run.call(1.0)
	var paced: bool = true
	for id: int in friends:
		paced = paced and world.players[id]["level"] == 23 and world.players[id]["equipment"] == Bots.gear(23, world.players[id]["vocation"])
	check(paced, "companions keep your level and gear tier")
	# Down the stairs: companions follow you into your party's dungeon copy.
	instances.enter(1, "cinder_cellar", sim_clock[0])
	run.call(1.0)
	check(friends.all(func(id: int) -> bool: return World.dungeon_at(world.players[id]["cell"]) == World.dungeon_at(me["cell"])),
		"companions follow you into your dungeon copy")
	instances.leave(1, sim_clock[0])
	run.call(1.0)
	check(friends.all(func(id: int) -> bool: return World.dungeon_at(world.players[id]["cell"]).is_empty()), "and back out")
	# Group tactics.
	var druid: int = friends.filter(func(id: int) -> bool: return world.players[id]["vocation"] == "druid")[0]
	world.players[friends[1]]["health"] = 10
	_place(world, druid, world.players[friends[1]]["cell"] + Vector2i(1, 0))
	check(bots._hurt_ally(druid, 3, Bots.HEAL_ALLY_SHARE), "druids notice hurt allies")
	var wounded: int = roundi(world.player_stats(1)["health"] * 0.4)
	me["health"] = wounded
	world.players[druid]["cooldowns"] = {}
	world.players[druid]["groups"] = {}
	world.players[druid]["mana"] = world.player_stats(druid)["mana"]
	_place(world, druid, me["cell"] + Vector2i(0, 1))
	bots.use_resources(druid, sim_clock[0], [])
	check(me["health"] > wounded, "a druid companion heals you when you are hurt")
	check(Spells.for_vocation("druid").any(func(spell: String) -> bool:
		return Spells.SPELLS[spell]["kind"] == "heal_area" and Spells.SPELLS[spell]["level"] == 1), "druids heal their party from level 1")
	var guard: int = combat.spawn_monster("grey_wolf", 20, me["cell"] + Vector2i(1, 0), sim_clock[0])
	world.monsters[guard]["target"] = druid
	_place(world, druid, me["cell"] + Vector2i(2, 0))
	check(bots._should_taunt(1, 2, sim_clock[0]), "a warrior challenges a monster on a softer party member")
	world.monsters[guard]["target"] = 1
	check(not bots._should_taunt(1, 2, sim_clock[0]), "but not one already on the warrior")
	world.monsters[guard]["target"] = druid
	check(bots._loose_monster(1, 4) == guard, "a warrior spots a monster on a softer party member to Provoke")
	world.monsters[guard]["target"] = 1
	check(bots._loose_monster(1, 4) == 0, "and leaves one already on the warrior")
	combat.despawn(guard, [])
	me["health"] = 100
	var events: Array = []
	world.players[druid]["level"] = 20
	check(combat._drop_belongings(druid, events).is_empty(), "companions keep their belongings when they die")
	# Rival bands go about their errands: a task from its giver, at a camp of its monster.
	run.call(20.0)
	var heads: Array = solo.bands.values().map(func(band: Dictionary) -> int: return band["leader"])
	check(heads.any(func(head: int) -> bool: return not world.players[head]["tasks"].is_empty()), "rival bands take tasks")
	# Rivals level from what they earn: a level gained stays and brings its gear.
	var rival: int = solo.bands[0]["members"][1]
	var rival_player: Dictionary = world.players[rival]
	var earned: int = rival_player["level"] + 1
	combat.grant_experience(rival, Balance.experience_to_next(rival_player["level"]) - rival_player["experience"], [])
	run.call(1.0)
	check(rival_player["level"] >= earned and bots.bots[rival]["level"] == rival_player["level"]
		and rival_player["equipment"] == Bots.gear(rival_player["level"], bots.bots[rival]["vocation"]),
		"a rival keeps the level it earns and wears that level's gear")
	# Between errands a band only lifts a member who fell behind you; one ahead keeps its levels.
	var ahead: int = rival_player["level"]
	solo._level_band(0, [])
	check(rival_player["level"] == ahead, "a rival ahead of you is not pulled back to your level")
	me["level"] = ahead + 10
	solo._level_band(0, [])
	check(rival_player["level"] == ahead + 10 + Solo.BANDS[0][1][1][2] - Solo.BAND_SLACK
		and rival_player["equipment"] == Bots.gear(rival_player["level"], bots.bots[rival]["vocation"]),
		"a rival who falls behind is lifted to your level plus its offset, less BAND_SLACK")
	# A death costs a rival what it costs a player, and it wakes with the experience it has left.
	rival_player["experience"] = Balance.experience_to_next(rival_player["level"]) / 2
	var dying: Array = []
	combat._kill_player(rival, sim_clock[0], dying)
	var left: Array = [rival_player["level"], rival_player["experience"]]
	run.call(Bots.RESTORE_SECONDS + 1.0)
	check(rival_player["health"] > 0 and rival_player["level"] == left[0] and rival_player["experience"] >= left[1] and left[1] > 0,
		"a rival wakes after a death with the level and experience it kept (%s, now %d/%d)" % [left, rival_player["level"], rival_player["experience"]])
	me["level"] = 23
	# A raid at level 50: the balance check's composition, rival bands sent home to fit.
	check(not solo.raid(true, sim_clock[0])["ok"], "raids wait for level 50")
	me["level"] = Balance.MAX_LEVEL
	run.call(0.5)
	check(solo.raid(true, sim_clock[0])["ok"] and combat.party_members(1).size() == Solo.raid_target() and Solo.raid_target() == 20
		and world.players.size() <= World.MAX_PLAYERS, "a raid gathers twenty")
	# The raid's bots take their turns spread over THINK_SECONDS, not all in one frame.
	var turns: Dictionary = {}
	for id: int in combat.party_members(1):
		if bots.is_bot(id):
			var slot: int = floori(Bots.think_phase(id) / Bots.THINK_SECONDS * 10.0)
			turns[slot] = turns.get(slot, 0) + 1
	check(turns.size() >= 8 and turns.values().max() <= 4, "a raid's bots think at spread-out moments (%s)" % [turns])
	var counts: Dictionary = {}
	for id: int in combat.party_members(1):
		counts[world.players[id]["vocation"]] = counts.get(world.players[id]["vocation"], 0) + 1
	check(counts == Balance.RAID and Balance.raid_check(counts)["ok"], "the raid matches the balanced raid composition")
	check(solo.raid(false, sim_clock[0])["ok"] and combat.party_members(1).size() == 4 and solo.bands.values().all(
		func(band: Dictionary) -> bool: return band["members"].size() == 3), "disbanding keeps your companions and brings the rivals back")
	# Ambush: a band comes for your group in a PvP zone.
	var island: Vector2i = Vector2i(205, 197)
	check(World.zone_at(island).get("pvp", false), "Blackreed Isle is a PvP zone")
	for band: int in solo.bands:
		solo.bands[band]["rest_until"] = 0.0  # disbanding a raid gives the bands a rest first
	_place(world, 1, island)
	var hunted: bool = false
	# Whoever strikes first, a rival fighting one of your group in reach is the ambush.
	var group: Array = [1] + friends
	for step: int in 50:
		run.call(0.5)
		for band: int in solo.bands:
			for rival_id: int in solo.bands[band]["members"]:
				if world.players.has(rival_id) and world.players[rival_id]["target"] in group \
						and Combat.distance(world.players[rival_id]["cell"], me["cell"]) <= Combat.TARGET_RANGE:
					hunted = true
	check(hunted, "rivals ambush your group in a PvP zone")
	# Choosing companions: a slot swaps to another class, and the raid plan follows your party.
	_place(world, 1, World.SPAWNS[0])
	run.call(0.5)
	var swapped: Dictionary = solo.set_companion(0, "knight", sim_clock[0])
	var druids: int = solo.companions().filter(func(id: int) -> bool: return world.players[id]["vocation"] == "druid").size()
	check(swapped["ok"] and world.players[solo.slot_ids[0]]["vocation"] == "knight" and druids == 0
		and swapped["events"].any(func(event: Dictionary) -> bool: return event["kind"] == "bot_left"),
		"a companion swaps to another class (%s)" % swapped.get("reason", ""))
	check(solo.slot_ids[0] in combat.party_members(1) and solo.companions().size() == 3 and combat.party_members(1).size() == 4,
		"the new companion joins your party (%s, %d companions, party %s)" % [solo.slot_ids, solo.companions().size(), combat.party_members(1)])
	check(not solo.set_companion(0, "knight", sim_clock[0])["ok"] and not solo.set_companion(3, "druid", sim_clock[0])["ok"]
		and not solo.set_companion(1, "adventurer", sim_clock[0])["ok"], "swaps need a real slot and a new class")
	var names: Array = solo.companions().map(func(id: int) -> String: return world.players[id]["name"])
	check(names.size() == 3 and names[0] != names[1] and names[1] != names[2] and names[0] != names[2], "companions keep distinct names")
	check(solo.raid_plan["knight"] >= 2, "the raid plan keeps room for your party's classes")
	var planned_knights: int = solo.raid_plan["knight"]
	while solo.set_raid_plan("knight", -1)["ok"]:
		pass
	check(solo.raid_plan["knight"] == solo.party_classes()["knight"], "the plan never drops below your party")
	while solo.raid_plan["knight"] < planned_knights:
		solo.set_raid_plan("knight", 1)
	check(not solo.set_raid_plan("druid", 1)["ok"] if solo.raid_size() >= Solo.raid_target() else true, "a full plan takes no more")
	while solo.raid_size() > Solo.raid_target():
		for vocation: String in ["paladin", "sorcerer", "druid", "knight"]:
			if solo.raid_size() > Solo.raid_target():
				solo.set_raid_plan(vocation, -1)
	check(solo.set_raid_plan("sorcerer", -1)["ok"] and not solo.raid(true, sim_clock[0])["ok"], "a raid needs a full plan")
	me["level"] = Balance.MAX_LEVEL  # the ambush may have cost a level
	var gathering: Dictionary = solo.raid(true, sim_clock[0]) if solo.set_raid_plan("paladin", 1)["ok"] else {"ok": false, "reason": "plan"}
	check(gathering["ok"], "a planned raid gathers (%s)" % gathering.get("reason", ""))
	var gathered: Dictionary = {}
	for id: int in combat.party_members(1):
		gathered[world.players[id]["vocation"]] = gathered.get(world.players[id]["vocation"], 0) + 1
	var wanted: Dictionary = solo.raid_plan.duplicate()
	for vocation: String in wanted.keys():
		if wanted[vocation] == 0:
			wanted.erase(vocation)
	check(gathered == wanted, "the raid gathers exactly the planned classes")
	check(not solo.set_companion(1, "druid", sim_clock[0])["ok"] and not solo.set_raid_plan("druid", 1)["ok"],
		"companions and the plan are fixed while the raid is out")
	check(solo.raid(false, sim_clock[0])["ok"] and combat.party_members(1).size() == 4, "and it disbands back to your companions")


## Start-menu characters: names are cleaned, and a profile's summary is read defensively.
func _character_profile_checks() -> void:
	check(Identity.clean_name("  Brann   Ironfist ") == "Brann Ironfist" and Identity.clean_name("x") == ""
		and Identity.clean_name("<b>Sylra</b>/../") == "bSylrab" and Identity.clean_name("A".repeat(40)).length() == Identity.MAX_NAME
		and Identity.clean_name("Åsa O'Neil-Ek") == "Åsa O'Neil-Ek", "character names keep letters, digits, spaces, ' and -")
	var config := ConfigFile.new()
	config.set_value("identity", "token", Identity.fresh())
	check(Identity.summary(config, "p")["name"] == Identity.UNNAMED and Identity.summary(config, "p")["level"] == 0,
		"an old profile without a summary shows as an unnamed new character")
	config.set_value("character", "equipment", "not a dictionary")
	config.set_value("character", "level", 12)
	check(Identity.summary(config, "p")["equipment"] == {} and Identity.summary(config, "p")["level"] == 12,
		"a damaged summary falls back safely")


## Bag slots: a worn bag's slots extend the backpack; bags come off only when empty.
func _bag_checks() -> void:
	var world := World.new()
	world.add_player(1, 0.0, "knight")
	var player: Dictionary = world.players[1]
	var tick: Array[float] = [1.0]
	var at := func() -> float:
		tick[0] += 1.0
		return tick[0]
	check(Economy.stock().has("leather_satchel") and not Economy.stock().has("starweave_rucksack"), "vendors sell the satchel; better bags are crafted")
	player["backpack"].fill("")
	player["backpack"][0] = "leather_satchel"
	player["backpack"][1] = "reedweave_bag"
	player["backpack"][2] = "health_potion#5"
	for bad: Variant in [{"type": "bag", "bag": 3}, {"type": "bag", "bag": -1}, {"type": "bag", "bag": "0"}, {"type": "bag"},
			{"type": "bag", "bag": 0, "extra": 1}]:
		check(not world.move_item(1, {"type": "backpack", "index": 0}, bad, at.call())["ok"], "malformed bag slots are refused")
	check(world.move_item(1, {"type": "backpack", "index": 2}, {"type": "bag", "bag": 0}, at.call())["reason"] == "Only bags go in a bag slot",
		"only bags go in bag slots")
	check(not world.move_item(1, {"type": "backpack", "index": 0}, {"type": "equipment", "slot": "armor"}, at.call())["ok"],
		"a bag is not armor")
	check(world.move_item(1, {"type": "backpack", "index": 0}, {"type": "bag", "bag": 0}, at.call())["ok"]
		and player["bags"][0] == "leather_satchel" and player["backpack"][0] == ""
		and player["backpack"].size() == World.BACKPACK_SIZE + 6 and World.bag_range(player, 0) == Vector2i(8, 6),
		"a worn satchel adds its six slots after the main backpack")
	check(world.move_item(1, {"type": "backpack", "index": 1}, {"type": "bag", "bag": 2}, at.call())["ok"]
		and World.bag_range(player, 2) == Vector2i(14, 8) and player["backpack"].size() == World.BACKPACK_SIZE + 14,
		"bags line up slot by slot")
	check(world.move_item(1, {"type": "backpack", "index": 2}, {"type": "backpack", "index": 15}, at.call())["ok"]
		and player["backpack"][15] == "health_potion#5", "items move into a bag's slots")
	check(World.carried(player["backpack"], "health_potion") == 5 and Combat.new(world, 5).drink(1, 15, at.call())["reason"] != "Unknown item location",
		"bag contents count as carried and can be used in place")
	check(world.move_item(1, {"type": "bag", "bag": 2}, {"type": "backpack"}, at.call())["reason"] == "Empty the Reedweave bag first",
		"a bag with items stays on")
	check(world.move_item(1, {"type": "bag", "bag": 0}, {"type": "backpack", "index": 9}, at.call())["reason"] == "A bag cannot go inside itself",
		"a bag cannot be put into its own slots")
	# Wearing a bigger pack grows the main backpack in front of the bags, keeping their contents.
	world.wear_pack(1, "traveler_pack")
	check(World.main_size(player) == 12 and World.bag_range(player, 0) == Vector2i(12, 6) and player["backpack"][19] == "health_potion#5",
		"a pack grows the main backpack and shifts the bags intact")
	# Saves keep worn bags and what they hold.
	var saved: Dictionary = JSON.parse_string(JSON.stringify(CharacterStore.capture(world, 1, 0.0)))
	var restored := World.new()
	restored.add_player(1, 0.0, "knight")
	CharacterStore.restore(restored, 1, saved, 0.0)
	check(restored.players[1]["bags"] == player["bags"] and restored.players[1]["backpack"] == player["backpack"], "bags survive a save")
	saved["bags"] = ["voidrend", 7, "starweave_rucksack", "leather_satchel"]
	var tampered := World.new()
	tampered.add_player(1, 0.0, "knight")
	CharacterStore.restore(tampered, 1, saved, 0.0)
	check(tampered.players[1]["bags"] == ["", "", "starweave_rucksack"] and tampered.players[1]["backpack"].size() == 12 + 14,
		"saved bags are sanitized")
	# Empty bags come off into the backpack (or onto the ground); the slots after them close up.
	player["backpack"][19] = ""
	player["backpack"][0] = "health_potion#5"
	check(world.move_item(1, {"type": "bag", "bag": 0}, {"type": "backpack"}, at.call())["ok"] and player["bags"][0] == ""
		and player["backpack"].size() == 12 + 8 and World.bag_range(player, 2) == Vector2i(12, 8) and player["backpack"].has("leather_satchel"),
		"an empty bag comes off and later bags move up")
	var spot: Vector2i = player["cell"] + Vector2i.DOWN
	if World.walkable(spot):
		check(world.move_item(1, {"type": "bag", "bag": 2}, {"type": "ground", "cell": spot}, at.call())["ok"]
			and world.ground[spot] == ["reedweave_bag"] and player["backpack"].size() == 12, "a bag can be dropped from its slot")
		check(world.move_item(1, {"type": "ground", "cell": spot}, {"type": "bag", "bag": 1}, at.call())["ok"]
			and player["bags"][1] == "reedweave_bag", "a bag is worn straight from the ground")
	check(world.export_player(1, 0.0, true)["bags"] == player["bags"] and not world.export_player(1, 0.0).has("bags"),
		"only you see your bags")
	check(not World.parse_location({"type": "backpack", "index": World.BACKPACK_LIMIT}, false).size() > 0
		and World.parse_location({"type": "backpack", "index": World.BACKPACK_LIMIT - 1}, false).size() == 2, "backpack indices are bounded")


func _hunters_lodge_checks() -> void:
	# A chain: each contract opens when the previous is done, against harder prey, and pays more.
	var chain: Array[String] = []
	for task: String in Quests.TASKS:
		if Quests.TASKS[task].get("chain", "") == "hunters_lodge":
			chain.append(task)
	check(chain.size() == 6 and Quests.TASKS[chain[0]].get("requires", "").is_empty(), "the Hunters' Lodge has six contracts")
	for index: int in range(1, chain.size()):
		var definition: Dictionary = Quests.TASKS[chain[index]]
		check(definition["requires"] == chain[index - 1] and definition["level"] > Quests.TASKS[chain[index - 1]]["level"],
			"%s follows %s against harder prey" % [chain[index], chain[index - 1]])
	var fresh: Dictionary = {"level": 50, "vocation": "druid", "tasks": {}, "done_tasks": []}
	check(World.task_open(chain[0], fresh) and not World.task_open(chain[1], fresh)
		and World.task_open(chain[1], {"level": 50, "vocation": "druid", "tasks": {}, "done_tasks": [chain[0]]}),
		"a contract opens only after the one before it")
	for vocation: String in Balance.VOCATIONS:
		for task: String in chain:
			var items: Array = World.task_items(task, vocation)
			var gear: Array = items.filter(func(entry: Array) -> bool: return not World.ITEMS[entry[0]]["slot"].is_empty())
			check(gear.size() == 1 and World.requirement_error(gear[0][0], Balance.MAX_LEVEL, vocation).is_empty()
				and World.ITEMS[gear[0][0]]["level"] == Items.tier_for(Quests.TASKS[task]["level"]),
				"%s pays a %s a piece of its own class at the hunt's tier" % [task, vocation])
	for kind: String in ["frostfang_wolf", "cyclops", "cyclops_smith", "behemoth"]:
		var drops: Array = Monsters.LOOT[kind].map(func(entry: Array) -> String: return entry[0])
		check("rune_shard" in drops and "health_potion" in drops and "mana_potion" in drops
			and Monsters.MONSTERS[kind]["gear_chance"] > Combat.GEAR_DROP_CHANCE["normal"],
			"%s is a farm: potions, rune shards, and double gear drops" % kind)
	# Turning in: needs room, pays items and the class piece; the next contract opens.
	var world := World.new()
	var combat := Combat.new(world, 3)
	world.add_player(1, 0.0, "paladin")
	var player: Dictionary = world.players[1]
	var varga: Dictionary = World.QUEST_GIVERS["lodgemaster_varga"]
	_place(world, 1, varga["cell"] + varga["facing"])
	check(not combat.task_action(1, "lodgemaster_varga", chain[1], "accept", 1.0)["ok"], "the second contract waits for the first")
	check(combat.task_action(1, "lodgemaster_varga", chain[0], "accept", 1.0)["ok"], "accept the first contract")
	player["tasks"][chain[0]] = Quests.TASKS[chain[0]]["count"]
	var full: Array = player["backpack"].duplicate()
	player["backpack"].fill("glowcap#100")
	check(combat.task_action(1, "lodgemaster_varga", chain[0], "complete", 2.0)["reason"].begins_with("Make room"),
		"a reward needs backpack room")
	player["backpack"] = full
	player["backpack"][0] = ""
	check(combat.task_action(1, "lodgemaster_varga", chain[0], "complete", 3.0)["ok"]
		and World.carried(player["backpack"], "health_potion") == 5 and player["backpack"].has("lodgeranger_boots")
		and World.bound("lodgeranger_boots"), "the first contract pays potions and the Hunter's bound Lodge boots")
	check(combat.task_action(1, "lodgemaster_varga", chain[1], "accept", 4.0)["ok"], "the next contract opens")
	# Spell ranks: a class trainer carves rune shards into a known spell.
	var trainer: String = "trainer_paladin"
	var spot: Dictionary = World.QUEST_GIVERS[trainer]
	_place(world, 1, spot["cell"] + spot["facing"])
	player["level"] = 20
	var slot: int = player["backpack"].find("")
	player["backpack"][slot] = "rune_shard#2"
	check(combat.empower_spell(1, trainer, "piercing_shot", 5.0)["reason"] == "You need 3 rune shards", "ranks cost shards")
	player["backpack"][slot] = "rune_shard#9"
	check(not combat.empower_spell(1, "trainer_knight", "piercing_shot", 5.0)["ok"]
		and not combat.empower_spell(1, trainer, "ember_bolt", 5.0)["ok"] and not combat.empower_spell(1, trainer, 7, 5.0)["ok"],
		"only your own trainer, for your own spells")
	check(combat.empower_spell(1, trainer, "piercing_shot", 5.0)["ok"] and player["spell_ranks"]["piercing_shot"] == 2
		and World.carried(player["backpack"], "rune_shard") == 6, "rank 2 for three shards")
	check(combat.empower_spell(1, trainer, "piercing_shot", 6.0)["ok"] and player["spell_ranks"]["piercing_shot"] == 3
		and World.carried(player["backpack"], "rune_shard") == 0, "rank 3 for six more")
	check(combat.empower_spell(1, trainer, "piercing_shot", 7.0)["reason"].ends_with("highest rank"), "rank 3 is the top")
	check(is_equal_approx(Spells.ranked_power("piercing_shot", 3), Spells.SPELLS["piercing_shot"]["power"] * 1.3)
		and Spells.info("piercing_shot", {}, 20, 3)["name"].ends_with("rank 3") and not Spells.rankable("challenge"),
		"each rank adds 15% power and shows in the spell's name")
	check(CharacterStore.capture(world, 1, 8.0)["spell_ranks"] == {"piercing_shot": 3}, "ranks are saved")
	CharacterStore.restore(world, 1, {"version": CharacterStore.VERSION, "level": 20, "vocation": "paladin",
		"spell_ranks": {"piercing_shot": 3, "ember_bolt": 3, "holy_mend": 9, "nonsense": 2}}, 8.0)
	check(player["spell_ranks"] == {"piercing_shot": 3, "holy_mend": 3}, "saves keep only valid ranks of your own spells")


func _sprite_checks() -> void:
	# Every creature (and the undead) has its own painted-style sheet; only armed humanoids wear gear.
	for kind: String in Monsters.MONSTERS:
		var definition: Dictionary = Monsters.MONSTERS[kind]
		check(SpriteArt.CREATURES.has(kind) or (definition["look"] == "humanoid" and definition.has("gear")),
			"%s has its own creature sheet or wears gear" % kind)
		if SpriteArt.CREATURES.has(kind):
			check(SpriteArt.CREATURES[kind].get_size() == Vector2(3, 4) * SpriteArt.FRAME, "%s's sheet has 3 poses by 4 facings" % kind)
	check(World.ITEMS["bronze_scale_coat"]["look"] == "scale" and World.ITEMS["steel_hauberk"]["look"] == "mail",
		"scale armour and chainmail use distinct construction")
	check(World.ITEMS["iron_cuirass"]["look"] == "brigandine"
		and World.ITEMS["cobalt_warhammer"]["look"] == "hammer" and World.ITEMS["starforged_maul"]["look"] == "hammer",
		"brigandine and hammers have dedicated icon and worn shapes")
	# Five poses (stand, two steps, attack wind-up, strike) by four facings.
	var sheet_size: Vector2 = Vector2(5, 4) * SpriteArt.FRAME
	for texture: Texture2D in [SpriteArt.BODY, SpriteArt.CLOTH, SpriteArt.MARKER]:
		check(texture.get_size() == sheet_size, "character sheet uses 5x4 frames")
	check(SpriteArt.frame_region(Vector2i.LEFT, 0.0, 0.05).position == Vector2(3, 2) * SpriteArt.FRAME
		and SpriteArt.frame_region(Vector2i.LEFT, 0.0, 0.3).position == Vector2(4, 2) * SpriteArt.FRAME
		and SpriteArt.frame_region(Vector2i.LEFT, 0.3, SpriteArt.ATTACK_SECONDS).position == Vector2(1, 2) * SpriteArt.FRAME,
		"attacks play the wind-up then the strike, then walking resumes")
	var view: Dictionary = {"state": {"facing": Vector2i.DOWN}, "attack_born": 10.0, "attack_facing": Vector2i.RIGHT}
	check(SpriteArt.posed(view, 10.1)["facing"] == Vector2i.RIGHT and SpriteArt.posed(view, 10.1)["attack"] > 0.0
		and SpriteArt.posed(view, 11.0) == view["state"] and view["state"]["facing"] == Vector2i.DOWN,
		"an attack turns only the drawn pose toward the target")
	check(SpriteArt.ITEM_ICONS.get_width() == SpriteArt.ITEM_ORDER.size() * SpriteArt.TILE, "one icon per item")
	check(SpriteArt.WALLS.get_width() == 16 * SpriteArt.WALL_SIZE, "one wall sprite per open-side mask")
	for kind: String in World.ITEMS:
		check(kind in SpriteArt.ITEM_ORDER, "catalog item has an icon")
		if World.ITEMS[kind]["slot"] in SpriteArt.VISIBLE_SLOTS:
			check(SpriteArt.GEAR.has(kind) and SpriteArt.GEAR[kind].get_size() == sheet_size,
				"equippable item has a worn sprite sheet")
	var body: Image = SpriteArt.BODY.get_image()
	for facing: int in 4:
		for pose: int in 3:
			var bounds := Rect2i()
			var pixels: int = 0
			for y: int in 64:
				for x: int in 64:
					if body.get_pixel(pose * 64 + x, facing * 64 + y).a < 0.9:
						continue
					var pixel := Vector2i(x, y)
					bounds = Rect2i(pixel, Vector2i.ONE) if pixels == 0 else bounds.merge(Rect2i(pixel, Vector2i.ONE))
					pixels += 1
			check(pixels > 150 and bounds.size.y >= 33 and bounds.size.y <= 37,
				"compact character height is 33-37 pixels in every pose")
			check(bounds.end.y >= 53 and bounds.end.y <= 55 and bounds.size.x <= 26,
				"compact characters keep their foot anchor without a baked-in cape silhouette")
	var weapon_masks: Dictionary = {}
	for kind: String in World.ITEMS:
		if World.ITEMS[kind]["slot"] != "main_hand":
			continue
		var icon: Image = SpriteArt.ITEM_ICONS.get_image().get_region(Rect2i(SpriteArt.item_region(kind)))
		var used: Rect2i = icon.get_used_rect()
		check(used.has_area() and used.position.x > 0 and used.position.y > 0 and used.end.x < 32 and used.end.y < 32,
			"%s icon has transparent padding and no clipped tip" % kind)
		var opaque: int = 0
		var colours: Dictionary = {}
		var mask := PackedByteArray()
		for y: int in 32:
			for x: int in 32:
				var pixel: Color = icon.get_pixel(x, y)
				mask.append(1 if pixel.a > 0.0 else 0)
				if pixel.a > 0.0:
					opaque += 1
					colours[pixel] = true
		check(opaque >= 40 and colours.size() >= 5, "%s retains readable material surfaces at native 32px size" % kind)
		if World.ITEMS[kind].get("loot_only", false) and World.ITEMS[kind]["slot"] == "main_hand":
			var key: String = mask.hex_encode()
			check(not weapon_masks.has(key), "%s has a silhouette distinct from the other hunting weapons" % kind)
			weapon_masks[key] = true
	for kind: String in SpriteArt.GEAR:
		var sheet: Image = SpriteArt.GEAR[kind].get_image()
		for facing: int in 4:
			for pose: int in 3:
				var bounds: Rect2i = sheet.get_region(Rect2i(pose * 64, facing * 64, 64, 64)).get_used_rect()
				check(bounds.has_area() and bounds.position.x > 0 and bounds.end.x < 64
					and bounds.position.y > 0 and bounds.end.y < 64, "%s stays visible and unclipped in every compact pose" % kind)


func _slot_and_stat_checks() -> void:
	check(World.SLOTS.size() == 12 and World.SLOT_TYPES.size() == 12 and "cape" in World.SLOTS and "bag" in World.SLOTS
		and "legs" in World.SLOTS and "boots" in World.SLOTS, "twelve equipment slots with legs, boots, a cape, and a pack")
	for slot: String in World.SLOTS:
		check(World.SLOT_TYPES.has(slot), "every slot has a type")
		var fitting: bool = false
		for kind: String in World.ITEMS:
			fitting = fitting or World.fits(kind, slot)
		check(fitting, "every slot has at least one item")
	for kind: String in World.ITEMS:
		var item: Dictionary = World.ITEMS[kind]
		check(item["slot"] in ["", "container"] or item["slot"] in World.SLOT_TYPES.values(), "item slot type is known")
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
	backpack[6] = "cobalt_ring"
	backpack[7] = "garnet_ring"
	check(world.move_item(1, {"type": "backpack", "index": 7}, {"type": "equipment", "slot": "ring_1"}, 0.5)["reason"]
		== "The Garnet ring requires level 20", "accessories need their tier level")
	player["level"] = 25
	check(world.move_item(1, {"type": "backpack", "index": 6}, {"type": "equipment", "slot": "ring_2"}, 1.0)["ok"],
		"equip ring 2")
	check(world.move_item(1, {"type": "backpack", "index": 7}, {"type": "equipment", "slot": "ring_1"}, 2.0)["ok"],
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
	check(Balance.mob_health(Balance.MAX_LEVEL, "boss") == Balance.FINAL_BOSS_HEALTH, "final boss has 700,000 health")
	check(Balance.FINAL_BOSS_HEALTH == 700000, "final boss anchor")
	check(Balance.mob_health(1) == roundi(30 * Balance.MOB_HEALTH_SCALE)
		and Balance.mob_health(Balance.MAX_LEVEL) == roundi(Balance.max_level_mob_health() * Balance.MOB_HEALTH_SCALE),
		"normal mob health range (the curve, 20% tougher)")
	check(Balance.boss_ratio() > 150.0, "the boss is a raid boss, well over a hundred normal mobs")
	check(is_equal_approx(Balance.ATTACK_SECONDS, 2.0), "Tibia-style two-second attacks")
	_raid_checks()
	var first_hits: int = ceili(Balance.mob_health(1) / float(Balance.base_attack(1)))
	check(first_hits >= 8 and first_hits <= ceili(8 * Balance.MOB_HEALTH_SCALE), "ungeared level 1 needs 8-10 hits (%d)" % first_hits)
	for level: int in range(1, Balance.MAX_LEVEL + 1):
		var hits: int = ceili(Balance.mob_health(level) / float(Balance.geared_attack(level)))
		check(hits >= 5 and hits <= ceili(7 * Balance.MOB_HEALTH_SCALE), "geared players need about six hits (seven with tougher monsters) at every level")
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
			check(falls >= 17.0 and falls <= 19.0, "a player survives about 18 same-level normal hits")
		else:
			check(falls >= 18.0 and falls <= 38.0, "early monsters hit softer: 18 to 38 hits to fall")
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
	check(size == 20 and raid.size() == Balance.VOCATIONS.size(), "intended raid is twenty players of every vocation")
	var result: Dictionary = Balance.raid_check(raid)
	check(result["ok"], "the intended raid wins")
	check(absf(result["seconds"] - Balance.RAID_FIGHT_SECONDS) < 0.01, "the intended raid takes the planned time")
	for vocation: String in raid:
		var smaller: Dictionary = raid.duplicate()
		smaller[vocation] -= 1
		check(not Balance.raid_check(smaller)["ok"], "removing any one player loses")
	for vocation: String in Balance.VOCATIONS:
		check(not Balance.raid_check({vocation: World.MAX_PLAYERS})["ok"], "a single-vocation group of a full server loses")
	check(not Balance.raid_check({"knight": 1, "paladin": 1, "sorcerer": 1, "druid": 1})["ok"], "four players lose")
	check(Balance.raid_check({"knight": 4, "paladin": 4, "sorcerer": 8, "druid": 4})["ok"], "other twenty-player mixes can win")
	check(Balance.raid_check({"knight": 4, "paladin": 8, "sorcerer": 6, "druid": 4})["seconds"] < Balance.RAID_FIGHT_SECONDS
		and Balance.raid_check({"knight": 4, "paladin": 8, "sorcerer": 6, "druid": 4})["ok"], "twenty-two players win faster")
	# Exhaustively: no group smaller than the intended raid can win.
	var smallest: int = 99
	for knights: int in size:
		for paladins: int in size - knights:
			for sorcerers: int in size - knights - paladins:
				for druids: int in size - knights - paladins - sorcerers:
					var group: Dictionary = {"knight": knights, "paladin": paladins, "sorcerer": sorcerers, "druid": druids}
					if Balance.raid_check(group)["ok"]:
						smallest = mini(smallest, knights + paladins + sorcerers + druids)
	check(smallest >= size, "no group of nineteen or fewer can defeat the final boss")
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
	check(World.width() >= 24 and World.height() >= 18 and World.terrain(Vector2i(0, 1)) == "W", "map loaded from the scene")
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
			check(npc["routes"][destination] > 0 or npc["vehicle"] == "gate", "fares are positive (gateways are free)")
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
	# Hunting camps from level 11 are tight packs of 5-7 (tools/generators/camp_density.gd), and
	# populate fills every one of them on the first pass.
	for spawn: Dictionary in World.MONSTER_SPAWNS:
		if Monsters.MONSTERS[spawn["monster"]]["rank"] == "normal" and spawn["level"] >= 11:
			check(spawn["count"] >= 5 and spawn["count"] <= 7 and spawn["radius"] <= 3,
				"%s camp at %s is a tight pack of 5-7 (%d within %d)" % [spawn["monster"], spawn["cell"], spawn["count"], spawn["radius"]])
	var filled := Combat.new(World.new(), 5)
	filled.world.monsters.clear()
	filled.populate(0.0, true)
	check(filled.respawns.size() * 100 < filled.world.monsters.size(),
		"populate places nearly every camp monster at once (%d waiting, %d placed)" % [filled.respawns.size(), filled.world.monsters.size()])
	# Raised walls, rock, and trees lean up and left over the cells west and north of them, so a
	# stairway beside one would be half hidden (and read as two holes).
	for dungeon: String in World.ENTRANCE_OF:
		var hole: Vector2i = World.ENTRANCE_OF[dungeon]
		var covered: Array = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)].filter(func(side: Vector2i) -> bool:
			var tile: String = World.terrain(hole + side)
			return not tile.is_empty() and (tile in World.WALLS or tile in World.TREES))
		check(World.terrain(hole) == "v" and covered.is_empty(), "%s's stairway at %s lies in the open (covered from %s)" % [dungeon, hole, covered])
	check(World.zone_at(Vector2i(-50, -50)).is_empty(), "outside the map is no zone")
	check(World.zone_at(World.SPAWNS[0]).get("town", false) and not World.zone_at(World.SPAWNS[0])["pvp"],
		"Cinder Crossing is a safe town")
	var hollow: Rect2i = World.ZONES.filter(func(zone: Dictionary) -> bool: return zone["name"] == "The Hollow Reach")[0]["rect"]
	var towns: int = 0
	for zone: Dictionary in World.ZONES:
		if zone["town"]:
			towns += 1
			check(not zone["pvp"] and not zone["full_loot"], "%s is safe" % zone["name"])
			check(Vector2(zone["rect"].get_center()).distance_to(Vector2(hollow.get_center())) > 100.0,
				"%s is far from the Hollow Reach" % zone["name"])
			for spawn: Dictionary in World.MONSTER_SPAWNS:
				check(not zone["rect"].has_point(spawn["cell"]), "no monsters spawn in %s" % zone["name"])
	check(towns >= 7, "every town is a safe zone")
	var central: int = 0
	for id: String in World.FERRYMEN:
		var cell: Vector2 = Vector2(World.FERRYMEN[id]["cell"])
		if World.FERRYMEN[id]["vehicle"] == "waystone" and cell.distance_to(Vector2(World.width(), World.height()) / 2.0) < 220.0:
			central += 1
	check(central >= 4, "coach towns ring the centre of the map")
	var ferries: Array = World.FERRYMEN.keys().filter(func(id: String) -> bool:
		return World.FERRYMEN[id]["vehicle"] == "ferry" and id not in ["reedmere", "blackreed_isle", "hrimvik"])
	check(ferries.size() == 2 and World.FERRYMEN["cinder_landing"]["routes"].has("lastlight")
		and World.FERRYMEN["lastlight"]["cell"].y > Atlas.MAINLAND.end.y - 100, "one coastal ferry runs from the top to the bottom")
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
			if World.FERRYMEN[id]["vehicle"] == "waystone":
				coaches.append(id)
			elif id not in ["reedmere", "blackreed_isle", "hrimvik"] and World.FERRYMEN[id]["vehicle"] == "ferry":
				check(not World.FERRYMEN[id]["routes"].has("blackreed_isle") and World.FERRYMEN[id]["cell"].x < 64,
					"coastal ports sail the western sea only")
		check(Atlas.MAINLAND == Rect2i(0, 0, 384, 384) and World.OVERWORLD.encloses(Atlas.MAINLAND)
			and World.OVERWORLD.encloses(Biomes.ISLES), "the overworld is the 384 by 384 mainland and the frost isles")
		check(coaches.size() >= 6, "coach stations link the inland towns")
		for id: String in coaches:
			var routes: Dictionary = World.FERRYMEN[id]["routes"]
			check(routes.size() == coaches.size() - 1, "%s runs to every other coach station" % id)
			for destination: String in routes:
				check(World.FERRYMEN[destination]["vehicle"] == "waystone" and routes[destination] > 0,
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
	config.set_value("keys", "slot_2", [KEY_J, KEY_NONE])
	config.set_value("keys", "slot_3", [KEY_J, KEY_NONE])
	config.set_value("bar", "slots", ["fireball"])
	config.save(path)
	var tampered := Keybinds.new(path)
	tampered.load_saved()
	check(tampered.keys["slot_1"] == [KEY_1, KEY_NONE] and tampered.bar == Keybinds.DEFAULT_BAR,
		"malformed saved values fall back to defaults")
	check(tampered.action_for(KEY_J) == "slot_2" and tampered.keys["slot_3"][0] == KEY_NONE, "duplicate saved keys are dropped")
	var detached := Keybinds.new(path)
	detached.persistent = false
	detached.load_saved()
	detached.set_bar(4, "spell:mend")
	detached.save()
	var reread := Keybinds.new(path)
	reread.load_saved()
	check(detached.action_for(KEY_P) != "slot_2" and reread.bar[4] != "spell:mend", "test bindings never read or write the saved file")
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
		check(item["level"] in Items.TIER_LEVELS or (item["level"] == Items.RELIC_LEVEL and (item.has("glow") or Items.mythic(item))),
			"%s has a tier level (or is level-50 relic or mythic gear)" % kind)
		if item.has("glow"):
			continue
		if item["slot"] == "bag":
			check(item["stats"].is_empty() and World.bound(kind) and item["slots"] > 0 and kind in Quests.PACKS,
				"%s is a bound quest pack that adds backpack slots" % kind)
			continue
		if item["slot"] == "container":
			check(item["stats"].is_empty() and not World.bound(kind) and item["slots"] > 0 and item["slots"] <= World.BAG_MAX
				and Crafting.RECIPES.has(kind) and Economy.sell_price(kind) > 0, "%s is an unbound, craftable bag" % kind)
			continue
		if item["look"] == "torch":
			check(item["slot"] == "off_hand" and item["stats"].is_empty() and item["vocations"].is_empty()
				and kind in Economy.stock(), "%s is a statless off-hand light every vocation can buy" % kind)
			continue
		check(not item["stats"].is_empty(), "%s has stats" % kind)
		if item["slot"] in Items.ACCESSORY_SLOTS:
			check(item["level"] >= Items.ACCESSORY_LEVEL, "%s is a later-stage accessory" % kind)
			check(item["vocations"].is_empty(), "accessories suit every vocation")
		if item["slot"] in ["main_hand", "off_hand"]:
			check(not item["vocations"].is_empty(), "%s belongs to vocations" % kind)
		var wearers: Array = item["vocations"] if not item["vocations"].is_empty() else Balance.VOCATIONS.keys()
		if item.has("armor"):
			wearers = Balance.VOCATIONS.keys().filter(func(vocation: String) -> bool: return Balance.ARMOR_OF[vocation] == item["armor"])
		for vocation: String in wearers:
			check(Balance.VOCATIONS.has(vocation), "%s names a known vocation" % kind)
			var key: String = "%s/%s/%d" % [item["slot"], vocation, item["level"]]
			by_key[key] = by_key.get(key, []) + [kind]
	for level: int in Items.TIER_LEVELS:
		for vocation: String in Balance.VOCATIONS:
			var slots: Array[String] = ["helmet", "armor", "main_hand", "off_hand"]
			if level >= Items.ACCESSORY_LEVEL:
				slots.append_array(Items.ACCESSORY_SLOTS)
			for slot: String in slots:
				var pieces: Array = by_key.get("%s/%s/%d" % [slot, vocation, level], [])
				var regular: Array = pieces.filter(func(kind: String) -> bool:
					return not World.ITEMS[kind].get("loot_only", false) and not World.ITEMS[kind].has("quest"))
				check(regular.size() == 1, "exactly one regular %s for a level-%d %s plus optional hunting sidegrades and quest pieces" % [slot, level, vocation])
				# Keep the regular piece first: the upgrade and six-hit checks below read it.
				by_key["%s/%s/%d" % [slot, vocation, level]] = regular + pieces.filter(func(kind: String) -> bool: return not kind in regular)
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
					check(hits >= 5 and hits <= ceili(7 * Balance.MOB_HEALTH_SCALE),
						"a tier-%d weapon needs about seven hits at level %d" % [level, at])
	check(Items.set_defense(1) == Items.SET_DEFENSE_LOW and is_equal_approx(Items.set_defense(45), Items.SET_DEFENSE_HIGH),
		"set defense spans the tiers")
	check(Items.tier_for(1) == 1 and Items.tier_for(4) == 1 and Items.tier_for(5) == 5 and Items.tier_for(50) == 45,
		"levels map to tiers")
	_relic_checks(by_key)
	_mythic_checks(by_key)
	_quest_piece_checks()
	# Requirements, on the server.
	check(World.requirement_error("willow_shortbow", 50, "knight") == "Only Hunters can use the Willow shortbow",
		"weapons are class-bound")
	check(World.requirement_error("kindling_wand", 1, "sorcerer").is_empty() \
		and World.requirement_error("tattered_primer", 1, "druid").is_empty(), "casters use wands, rods, and spellbooks")
	check(World.requirement_error("oak_buckler", 1, "sorcerer") == "Only Warriors and Hunters can use the Oak buckler",
		"shields are for Warriors and Hunters")
	check(World.requirement_error("bronze_helm", 9, "knight") == "The Bronze helm requires level 10"
		and World.requirement_error("bronze_helm", 10, "knight").is_empty(), "the level requirement boundary")
	var world := World.new()
	world.add_player(1, 0.0, "knight")
	var knight: Dictionary = world.players[1]
	knight["backpack"][6] = "willow_shortbow"
	knight["backpack"][7] = "bronze_mace"
	var refused: Dictionary = world.move_item(1, {"type": "backpack", "index": 6}, {"type": "equipment", "slot": "main_hand"}, 1.0)
	check(not refused["ok"] and refused["reason"].begins_with("Only Hunters") and knight["backpack"][6] == "willow_shortbow",
		"a Warrior cannot equip a bow")
	check(world.toggle_equipment(1, "main_hand", 2.0)["ok"] and knight["equipment"]["main_hand"] == "copper_blade",
		"the equip key picks a usable weapon")
	check(world.move_item(1, {"type": "backpack", "index": 7}, {"type": "equipment", "slot": "main_hand"}, 3.0)["reason"]
		== "The Bronze mace requires level 10", "a low-level Knight cannot equip a tier-10 mace")
	check(world.move_item(1, {"type": "equipment", "slot": "main_hand"}, {"type": "backpack", "index": 7}, 4.0)["reason"]
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
	_hunting_weapon_checks()


func _hunting_weapon_checks() -> void:
	var weapons: Array[String] = []
	var vocations: Dictionary = {}
	var tiers: Dictionary = {}
	var sources: Dictionary = {}
	var world := World.new()
	world.add_player(1, 0.0, "knight")
	var player: Dictionary = world.players[1]
	for kind: String in World.ITEMS:
		var item: Dictionary = World.ITEMS[kind]
		if not item.get("loot_only", false) or item["slot"] != "main_hand":
			continue
		weapons.append(kind)
		tiers[item["level"]] = true
		var vocation: String = item["vocations"][0]
		vocations[vocation] = vocations.get(vocation, 0) + 1
		check(item["slot"] == "main_hand" and item["stats"] == Items.tier_stats(item),
			"%s uses the shared balance budget, not hand-tuned bonuses" % kind)
		check(not World.bound(kind) and not item.has("glow") and not World.stackable(kind),
			"%s is ordinary nonstacking loot, not a relic" % kind)
		check(not Economy.stock().has(kind) and Economy.sell_price(kind) > 0,
			"%s must be hunted but vendors accept it for sale" % kind)
		var rolled: Array[String] = Combat.new(world, 110).roll_loot("field_vole", 1)
		check(not rolled.has(kind), "%s is not a starter-monster reward" % kind)
		for other: String in Balance.VOCATIONS:
			check(World.requirement_error(kind, item["level"], other).is_empty() == (other == vocation),
				"%s keeps its vocation restriction" % kind)
		player["vocation"] = vocation
		player["equipment"].clear()
		player["backpack"][0] = kind
		player["next_item"] = 0.0
		player["level"] = maxi(1, item["level"] - 1)
		if item["level"] > 1:
			check(not world.move_item(1, {"type": "backpack", "index": 0},
				{"type": "equipment", "slot": "main_hand"}, 1.0)["ok"], "%s rejects below-tier equipment" % kind)
		player["level"] = item["level"]
		check(world.move_item(1, {"type": "backpack", "index": 0},
			{"type": "equipment", "slot": "main_hand"}, 2.0)["ok"], "%s equips at its tier" % kind)
		check(world.move_item(1, {"type": "equipment", "slot": "main_hand"},
			{"type": "backpack", "index": 0}, 3.0)["ok"] and player["backpack"][0] == kind,
			"%s unequips without loss" % kind)
		check(CharacterStore.valid_entry(kind), "%s survives character save validation" % kind)
	check(weapons.size() == 16 and vocations == {"knight": 9, "paladin": 3, "sorcerer": 2, "druid": 2},
		"sixteen hunting weapons cover all four vocations")
	check(tiers.size() == 10, "hunting weapons span every ordinary gear tier")
	var combat := Combat.new(world, 906)
	var spawns: Array = World.MONSTER_SPAWNS.duplicate()
	for dungeon: String in Dungeons.DUNGEONS:
		for spawn: Array in Dungeons.spawns(dungeon):
			spawns.append({"monster": spawn[1], "level": spawn[2]})
	for monster: String in Monsters.LOOT:
		var targets: Dictionary = {}
		var level: int = 1
		for entry: Array in Monsters.LOOT[monster]:
			if not World.ITEMS[entry[0]].get("loot_only", false):
				continue
			targets[entry[0]] = float(entry[1])
			level = maxi(level, World.ITEMS[entry[0]]["level"])
			sources[entry[0]] = true
			var reachable: bool = false
			for spawn: Dictionary in spawns:
				reachable = reachable or (spawn["monster"] == monster and spawn["level"] >= World.ITEMS[entry[0]]["level"])
			check(reachable, "%s has a live overworld or dungeon source at an eligible level" % entry[0])
		if targets.is_empty():
			continue
		var counts: Dictionary = {}
		for roll: int in 4000:
			for entry: String in combat.roll_loot(monster, level):
				if targets.has(entry):
					counts[entry] = counts.get(entry, 0) + 1
		for kind: String in targets:
			var expected: float = targets[kind] * 4000
			check(absf(counts.get(kind, 0) - expected) < maxf(20.0, expected * 0.4),
				"%s actually drops %s near its declared chance" % [monster, kind])
		for roll: int in 80:
			for entry: String in combat.roll_loot(monster, maxi(1, level - 1)):
				check(World.ITEMS[World.kind_of(entry)]["level"] <= maxi(1, level - 1),
					"named drops cannot bypass the monster's level")
	for kind: String in weapons:
		check(sources.has(kind), "%s has a reachable loot-table source" % kind)
	for tier: int in Items.TIER_LEVELS:
		for roll: int in 100:
			check(not World.ITEMS[combat.gear_drop(tier)].get("loot_only", false),
				"hunting weapons do not dilute the existing generic gear pool")


## Mythic gear: unbound level-50 sets that only the level-50 elite farm monsters drop, between the
## last tier and the relics, one full armor set and weapon per class.
## Quest pieces: bound gear that only the Hunters' Lodge chain and boss tasks pay, a little better
## than the vendor piece of their tier, so a PvP death drops only what was found or bought.
func _quest_piece_checks() -> void:
	var paid: Dictionary = {}
	for task: String in Quests.TASKS:
		var definition: Dictionary = Quests.TASKS[task]
		for vocation: String in Balance.VOCATIONS:
			for entry: Array in World.task_items(task, vocation):
				if World.ITEMS[entry[0]].has("quest"):
					paid[entry[0]] = true
		# A task's rare roll ("rare") pays its pieces too, one turn-in in a few.
		for kind: String in definition.get("rare", {}).get("items", []):
			paid[kind] = true
		if definition.has("gear") and definition.get("chain", "") == "hunters_lodge":
			for vocation: String in Balance.VOCATIONS:
				var piece: String = World.quest_piece("hunters_lodge", definition["gear"], vocation)
				check(not piece.is_empty() and World.bound(piece) and World.requirement_error(piece, Balance.MAX_LEVEL, vocation).is_empty()
					and World.ITEMS[piece]["level"] == Items.tier_for(definition["level"]),
					"%s pays a %s its bound Lodge %s of the hunt's tier" % [task, vocation, definition["gear"]])
	for task: String in ["silk_matron", "abbot_morrow", "forgemaw"]:
		var accessory: Array = Quests.TASKS[task].get("items", []).filter(func(entry: Array) -> bool:
			return World.ITEMS[entry[0]].get("quest", "") == task)
		check(accessory.size() == 1 and World.bound(accessory[0][0]), "the %s task pays its bound accessory" % task)
	var drops := Combat.new(World.new(), 21)
	var pool: Dictionary = {}
	for roll: int in 300:
		for level: int in [12, 22, 32, 42]:
			pool[drops.gear_drop(level)] = true
	for kind: String in World.ITEMS:
		var item: Dictionary = World.ITEMS[kind]
		if not item.has("quest"):
			continue
		check(paid.has(kind), "%s is paid by a quest" % kind)
		check(World.bound(kind) and not Economy.stock().has(kind) and Economy.sell_price(kind) == 0 and not pool.has(kind)
			and not Monsters.LOOT.values().any(func(table: Array) -> bool: return table.any(func(entry: Array) -> bool: return entry[0] == kind)),
			"%s is bound: never sold, bought, or dropped by monsters" % kind)
		var derived: Dictionary = Items.with_bonus(Items.tier_stats(item), Items.QUEST_BONUS)
		check(item["stats"] == derived, "%s derives its tier stats with the quest bonus" % kind)
	# A skulled death drops what was found but keeps what was earned.
	var world := World.new()
	var combat := Combat.new(world, 5)
	world.add_player(1, 0.0, "knight")
	var player: Dictionary = world.players[1]
	player["level"] = 30
	player["skull"] = "red"
	player["equipment"]["boots"] = "lodgewarden_boots"
	player["equipment"]["helmet"] = "embersteel_helm"
	player["backpack"][0] = "forgeheart_ring"
	player["backpack"][1] = "garnet_ring"
	combat._drop_belongings(1, [])
	check(player["equipment"].get("boots", "") == "lodgewarden_boots" and player["backpack"][0] == "forgeheart_ring"
		and not player["equipment"].has("helmet") and player["backpack"][1].is_empty(),
		"a red-skulled death drops found gear but keeps bound quest rewards")


func _mythic_checks(by_key: Dictionary) -> void:
	var mythic: Array[String] = []
	for kind: String in World.ITEMS:
		if Items.mythic(World.ITEMS[kind]):
			mythic.append(kind)
	check(mythic.size() == 26, "twenty-six mythic pieces")
	var sources: Dictionary = {}
	for monster: String in Monsters.LOOT:
		for entry: Array in Monsters.LOOT[monster]:
			if Items.mythic(World.ITEMS[entry[0]]):
				sources[entry[0]] = sources.get(entry[0], []) + [monster]
				check(Monsters.MONSTERS[monster]["rank"] == "elite" and float(entry[1]) <= 0.02,
					"%s drops %s rarely, and only as an elite" % [monster, entry[0]])
	var farms: Dictionary = {}
	for spawn: Dictionary in World.MONSTER_SPAWNS:
		if spawn["monster"] in sources.values().reduce(func(all: Array, list: Array) -> Array: return all + list, []):
			check(World.zone_at(spawn["cell"]).is_empty(), "level-50 farms are open countryside, not zones")
			farms[spawn["monster"]] = farms.get(spawn["monster"], 0) + 1
	for kind: String in mythic:
		var item: Dictionary = World.ITEMS[kind]
		check(Items.rarity(item)[0] == "Mythic", "%s shows as Mythic" % kind)
		check(not World.bound(kind) and not World.stackable(kind) and not Economy.stock().has(kind) and Economy.sell_price(kind) > 0,
			"%s is tradeable loot that vendors buy but never sell" % kind)
		var derived: Dictionary = Items.with_bonus(Items.tier_stats(item), Items.MYTHIC_BONUS)
		check(item["stats"] == derived, "%s derives its stats at level 50 with the small mythic bonus" % kind)
		check(sources.get(kind, []).size() == 1 and farms.has(sources.get(kind, [""])[0]),
			"%s has exactly one placed level-50 source" % kind)
		var vocation: String = item["vocations"][0] if not item["vocations"].is_empty() else ""
		if item.has("armor"):
			for other: String in Balance.ARMOR_OF:
				if Balance.ARMOR_OF[other] == item["armor"]:
					vocation = other
		var key: String = "%s/%s/%d" % [item["slot"], vocation if not vocation.is_empty() else "knight", Items.TIER_LEVELS[-1]]
		var tier_total: int = 0
		for stat: String in World.ITEMS[by_key[key][0]]["stats"]:
			tier_total += World.ITEMS[by_key[key][0]]["stats"][stat]
		var total: int = 0
		for stat: String in item["stats"]:
			total += item["stats"][stat]
		check(total > tier_total, "%s beats the tier-45 %s" % [kind, item["slot"]])
		for relic: String in World.ITEMS:
			if World.ITEMS[relic].has("glow") and World.ITEMS[relic]["slot"] == item["slot"] \
					and World.ITEMS[relic].get("armor", "") == item.get("armor", "") and World.ITEMS[relic]["vocations"] == item["vocations"]:
				var relic_total: int = 0
				for stat: String in World.ITEMS[relic]["stats"]:
					relic_total += World.ITEMS[relic]["stats"][stat]
				check(relic_total > total, "the relic %s still beats %s" % [relic, kind])
	for vocation: String in Balance.VOCATIONS:
		for slot: String in ["helmet", "armor", "legs", "boots", "main_hand"]:
			check(by_key.has("%s/%s/%d" % [slot, vocation, Items.RELIC_LEVEL]), "%s can farm a mythic %s" % [vocation, slot])
	for monster: String in farms:
		check(farms[monster] >= 3, "%s has several level-50 camps" % monster)
	var combat := Combat.new(World.new(), 51)
	var counts: Dictionary = {}
	for roll: int in 3000:
		for entry: String in combat.roll_loot("ashmaw_drake", 50):
			counts[World.kind_of(entry)] = counts.get(World.kind_of(entry), 0) + 1
	check(absf(counts.get("drakeforged_helm", 0) - 45.0) < 25.0 and counts.get("ashmaw_heartscale", 0) > 1300,
		"the drake drops its mythic pieces and trophy near their chances")
	check(not counts.has("drakeforged_helm") or combat.roll_loot("ashmaw_drake", 49).all(
		func(entry: String) -> bool: return World.ITEMS[World.kind_of(entry)]["level"] <= 49 or World.ITEMS[World.kind_of(entry)]["slot"].is_empty()),
		"mythic pieces need a level-50 monster")


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
	# Provoke: one monster, the caster's target, from a few tiles away; never a player.
	var knight_cell: Vector2i = world.players[1]["cell"]
	world.players[1]["mana"] = 999999
	world.players[1]["target"] = boss
	world.players[1]["cell"] = monster["cell"] + Vector2i(3, 0)
	check(combat.cast(1, "provoke", 30.0)["ok"] and monster["target"] == 1, "Provoke pulls one monster, a boss too, from three tiles")
	world.players[1]["cell"] = monster["cell"] + Vector2i(6, 0)
	check(not combat.cast(1, "provoke", 40.0)["ok"] and monster["target"] == 1, "Provoke needs its target within four tiles")
	world.players[1]["cell"] = knight_cell
	world.players[1]["target"] = 2
	check(not combat.cast(1, "provoke", 50.0)["ok"] and not combat.cast(3, "provoke", 50.0)["ok"] and not Spells.rankable("provoke"),
		"Provoke works on monsters only, for Knights only, and has no ranks")
	world.players[1]["target"] = 0
	monster["target"] = 2
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
		if other["name"] not in ["The Hollow Reach", "The Void Throne"]:
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
	# The throne room holds the Void Gate; Vaelith sits past it on the Void Throne, an open
	# full-loot PvP arena off the overworld.
	var gate: Dictionary = World.FERRYMEN.get("VoidGate", {})
	var arena: Dictionary = World.FERRYMEN.get("VoidThrone", {})
	check(not gate.is_empty() and area.has_point(gate["cell"]) and gate["vehicle"] == "gate" and gate["routes"] == {"VoidThrone": 0}
		and not arena.is_empty() and arena["routes"] == {"VoidGate": 0}, "the Sanctum's throne room holds a free gateway to the Void Throne")
	var throne: Dictionary = World.MONSTER_SPAWNS.filter(func(spawn: Dictionary) -> bool: return spawn["monster"] == "vaelith")[0]
	var void_zone: Dictionary = World.zone_at(throne["cell"])
	check(void_zone.get("name", "") == "The Void Throne" and void_zone["pvp"] and void_zone["full_loot"]
		and not World.OVERWORLD.has_point(throne["cell"]) and World.terrain(throne["cell"]) == "o"
		and void_zone["rect"].has_point(arena["cell"]), "Vaelith sits on the Void Throne, an open full-loot PvP arena")
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
	check([Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT].any(func(side: Vector2i) -> bool: return seen.has(gate["cell"] + side)),
		"the Void Gate in the throne room is reachable on foot from Cinder Crossing")
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
	check(message.contains("Obsidian bulwark plate") and message.contains("your backpack"), "the death message lists everything lost")


## Trophy credit on a boss kill, claiming at the Relic keeper, and bound relics.
func _relic_quest_checks() -> void:
	check(World.QUEST_GIVERS.has("relic_keeper") and "quests" in World.npc("relic_keeper")["services"],
		"the Relic keeper offers quests")
	var keeper: Vector2i = World.QUEST_GIVERS["relic_keeper"]["cell"]
	check(not World.walkable(keeper) and World.NPC_CELLS.get(keeper, "") == "relic_keeper", "the Relic keeper blocks her tile")
	var kept: Array = []
	for giver: String in World.QUEST_GIVERS:
		var boss_kept: String = World.QUEST_GIVERS[giver]["boss"]
		if not boss_kept.is_empty():
			check(boss_kept not in kept and Monsters.MONSTERS[boss_kept]["rank"] == "boss" and World.QUEST_GIVERS[giver]["tasks"].is_empty()
				and World.QUEST_GIVERS[giver]["place"] == "Reedmere" and World.zone_at(World.QUEST_GIVERS[giver]["cell"]).get("name", "") == "Reedmere",
				"%s keeps one boss's relics in Reedmere, the middle town" % giver)
			kept.append(boss_kept)
	for kind: String in Monsters.MONSTERS:
		if Monsters.MONSTERS[kind]["rank"] == "boss":
			check(kind in kept, "%s has a relic keeper" % kind)
	var world := World.new()
	var combat := Combat.new(world, 8)
	world.monsters.clear()
	var lair: Vector2i = World.MONSTER_SPAWNS.filter(func(spawn: Dictionary) -> bool: return spawn["monster"] == "morvain")[0]["cell"]
	for id: int in [1, 2, 3, 4]:
		world.add_player(id, 0.0, ["knight", "druid", "sorcerer", "paladin"][id - 1])
	_place(world, 1, lair + Vector2i(1, 0))
	_place(world, 2, lair + Vector2i(1, 3))
	_place(world, 3, lair + Vector2i(-4, 0))
	_place(world, 4, keeper + Vector2i(2, 1))
	var boss: int = combat.spawn_monster("morvain", 50, lair, 0.0)
	# Player 1 tanks (is hit) and attacks; player 2 heals player 1; player 3 stands nearby
	# self-healing at full health every so often; player 4 is far away.
	world.players[1]["level"] = 50
	world.players[2]["level"] = 50
	world.players[1]["health"] = world.player_stats(1)["health"]
	combat._damage(boss, 1, 500, "damage", 98.0, [])
	world.players[2]["mana"] = 999999
	# The lair is in a PvP zone, where group heals mend only the healer's party.
	world.players[1]["party"] = 1
	world.players[2]["party"] = 1
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
	check(combat.claim_relic(4, "relic_keeper", "cinderheart_bow", 101.0)["reason"].begins_with("Ysolde only keeps Morvain the Drowned's relics; see Brannoc"),
		"each relic keeper trades one boss's relics and points to the right keeper")
	check(combat.claim_relic(4, "relic_keeper_kharzul", "cinderheart_bow", 101.0)["reason"] == "Your backpack is full"
		and world.players[4]["trophies"] == {"kharzul": 1}, "a full backpack keeps the trophy")
	backpack.assign(saved)
	var claimed: Dictionary = combat.claim_relic(4, "relic_keeper_kharzul", "cinderheart_bow", 101.0)
	check(claimed["ok"] and backpack.has("cinderheart_bow") and world.players[4]["trophies"].is_empty(),
		"a trophy becomes the relic of your choice")
	check(combat.claim_relic(4, "relic_keeper_kharzul", "molten_heart", 102.0)["reason"] == "Slay Kharzul the Cinder Colossus first",
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
	for distance: int in range(1, World.TALK_RANGE + 1):
		for dy: int in range(-distance, distance + 1):
			for dx: int in range(-distance, distance + 1):
				var spot: Vector2i = cell + Vector2i(dx, dy)
				if World.walkable(spot) and World.in_talk_range(spot, cell):
					return spot
	return cell


## Vendors, bankers and the depot, town hunting tasks and packs, and potions.
func _town_checks() -> void:
	# Every town has a vendor; one town (Reedmere) has the only banker; NPCs block their tile and can be reached.
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
		check(person["services"] == {"banker": ["bank"], "artisan": ["craft"]}.get(person["role"], ["trade"]), "%s offers its service" % id)
	var banks: Array = []
	for town: String in towns:
		check("vendor" in towns[town], "%s has a vendor" % town)
		if "banker" in towns[town]:
			banks.append(town)
	check(banks == ["Reedmere"] and World.bank_place() == "Reedmere", "Reedmere is the only bank town (%s)" % [banks])
	var givers: Dictionary = {}
	for id: String in World.QUEST_GIVERS:
		for giver_task: String in World.QUEST_GIVERS[id]["tasks"]:
			check(Quests.TASKS.has(giver_task) and Quests.TASKS[giver_task]["giver"] == id, "%s gives a known task" % id)
			check(World.zone_at(World.QUEST_GIVERS[id]["cell"]).get("town", false) or _by_wild_stairway(World.QUEST_GIVERS[id]),
				"%s stands in a town (or by a wilderness stairway)" % id)
			givers[giver_task] = id
	var packs: int = 0
	for task: String in Quests.TASKS:
		var definition: Dictionary = Quests.TASKS[task]
		check(givers.has(task), "%s has a quest giver" % task)
		var placed: bool = Quests.monster_level(definition["monster"]) > 0 or not World.MONSTER_SPAWNS.filter(
			func(spawn: Dictionary) -> bool: return spawn["monster"] == definition["monster"]).is_empty()
		check(placed, "%s hunts a monster that spawns" % task)
		for kind: String in definition.get("also", []):
			check(Monsters.MONSTERS.has(kind) and Quests.counts(task, kind), "%s also counts %s" % [task, kind])
		check(definition["reward"] in ["pack", "experience"], "%s has a reward" % task)
		packs += 1 if definition["reward"] == "pack" else 0
	check(packs == Quests.PACKS.size(), "one pack per town task")
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
	var banker: String = "reedmere_banker"
	check(World.TOWNSFOLK.has(vendor) and World.TOWNSFOLK.has(banker), "Cinder Crossing has a vendor and Reedmere a banker")
	var ticks: Array[float] = [10.0]
	var tick := func() -> float:
		ticks[0] += 1.0
		return ticks[0]
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
	check(economy.buy(1, vendor, "health_potion", 5, ticks[0] + 0.01)["reason"] == "Item cooldown", "trading has the item cooldown")
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
	check(world.move_item(1, depot0, slot0, tick.call())["reason"] == "Your depot is kept at the bank in Reedmere", "depot needs a banker")
	_place(world, 1, _beside(banker))
	check(world.move_item(1, depot0, {"type": "backpack"}, tick.call())["ok"] and player["depot"][0] == ""
		and backpack.has("abyssal_greathelm"), "the depot hands items back at the bank")

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
	var task: String = World.QUEST_GIVERS[giver]["tasks"][0]
	var count: int = Quests.TASKS[task]["count"]
	var hunted: String = Quests.TASKS[task]["monster"]
	check(combat.task_action(1, giver, task, "accept", tick.call())["reason"] == "Walk closer to a quest giver", "tasks need the giver nearby")
	_place(world, 1, _beside(giver))
	check(not combat.task_action(1, giver, task, "dance", tick.call())["ok"] and not combat.task_action(1, 7, task, "accept", tick.call())["ok"]
		and not combat.task_action(1, "relic_keeper", task, "accept", tick.call())["ok"]
		and not combat.task_action(1, giver, "rat_king", "accept", tick.call())["ok"] and not combat.task_action(1, giver, 3, "accept", tick.call())["ok"],
		"malformed task requests rejected, and givers only offer their own tasks")
	check(combat.task_action(1, giver, task, "complete", tick.call())["reason"].begins_with("Slay"), "a task must be accepted and finished")
	check(combat.task_action(1, giver, task, "accept", tick.call())["ok"] and player["tasks"] == {task: 0}, "accepting a task")
	check(not combat.task_action(1, giver, task, "accept", tick.call())["ok"], "a task is accepted once")
	check(not combat.claim_relic(1, giver, "tidebreaker", tick.call())["ok"], "task givers do not hand out relics")
	var field := Vector2i(9, 10)
	_place(world, 1, field + Vector2i(1, 0))
	_place(world, 2, field + Vector2i(-1, 0))
	world.players[2]["tasks"][task] = 0
	var kill := func(kind: String) -> void:
		var monster: int = combat.spawn_monster(kind, 6, field, ticks[0])
		combat._damage(1, monster, 9999999, "damage", tick.call(), [])
	kill.call("field_vole")
	check(player["tasks"][task] == 0, "other monsters do not count")
	for index: int in count + 3:
		kill.call(hunted)
	check(player["tasks"][task] == count and world.players[2]["tasks"][task] == 0,
		"kills count up to the goal, and only for players who earned the kill")
	_place(world, 1, _beside(giver))
	var turned: Dictionary = combat.task_action(1, giver, task, "complete", tick.call())
	check(turned["ok"] and player["equipment"]["bag"] == Quests.PACKS[0] and backpack.size() == World.BACKPACK_SIZE + 4
		and not player["tasks"].has(task) and player["done_tasks"].has(task), "finishing a task gives the first pack")
	check(world.export_player(1, 0.0, true)["backpack"].size() == backpack.size() and task in world.export_player(1, 0.0, true)["done_tasks"],
		"the bigger backpack and finished tasks replicate to the owner")
	check(world.move_item(1, slot0, {"type": "backpack", "index": backpack.size() - 1}, tick.call())["reason"] == "There is no item there",
		"new pack slots are usable")
	check(not combat.task_action(1, giver, task, "accept", tick.call())["ok"], "a finished task cannot be repeated")
	for target: Variant in [slot0, {"type": "ground", "cell": player["cell"] + Vector2i.DOWN}, {"type": "backpack"}]:
		check(world.move_item(1, {"type": "equipment", "slot": "bag"}, target, tick.call())["reason"] == "Your pack stays on your back",
			"packs cannot be taken off")
	check(world.toggle_equipment(1, "bag", tick.call())["reason"] == "Your pack stays on your back", "the pack key does nothing")
	world.players[1]["done_tasks"].erase(task)
	world.players[1]["tasks"][task] = count
	check(combat.task_action(1, giver, task, "complete", tick.call())["ok"] and player["equipment"]["bag"] == Quests.PACKS[1]
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
	var health_ready: float = ticks[0] + World.ITEMS["health_potion"]["cooldown"]
	check(World.ITEMS["health_potion"]["cooldown"] > World.ITEMS["mana_potion"]["cooldown"] and World.ITEMS["mana_potion"]["cooldown"] >= 2.0,
		"health potions have the longer cooldown")
	check(combat.drink(1, 0, ticks[0] + 0.5)["reason"] == "Health potion ready in %d s" % ceili(World.ITEMS["health_potion"]["cooldown"] - 0.5),
		"a health potion has its own cooldown, and says when it is ready")
	check(combat.drink(1, 0, health_ready - 0.05)["reason"].begins_with("Health potion ready"), "the cooldown lasts its full time")
	check(world.export_player(1, ticks[0] + 1.0, true)["cooldowns"].has(Combat.potion_timer("health_potion")),
		"the owner sees the potion cooldown")
	player["mana"] = 0
	check(combat.drink(1, 1, ticks[0] + 0.6)["ok"] and player["mana"] == roundi(limits["mana"] * 0.25) and backpack[1] == "",
		"mana potions have a separate timer; the last one is used up")
	ticks[0] = health_ready
	check(combat.drink(1, 0, tick.call())["ok"] and backpack[0] == "", "after its cooldown the last health potion is used up")
	for bad: Variant in [2, 1, -1, "0", 0.0, null, backpack.size()]:
		check(not combat.drink(1, bad, tick.call())["ok"], "drinking needs a potion")
	check(player["active_at"] == -INF, "drinking is not combat activity")


## A quest giver outside towns must stand by a wilderness dungeon's stairway, in its region.
func _by_wild_stairway(giver: Dictionary) -> bool:
	for dungeon: String in Dungeons.DUNGEONS:
		var definition: Dictionary = Dungeons.DUNGEONS[dungeon]
		if definition.has("entrance") and giver["place"] == definition["town"] \
				and World.chebyshev(giver["cell"], World.ENTRANCE_OF[dungeon]) <= 6:
			return true
	return false



## The elite caves (game/data/caves.gd, tools/generators/caves.gd): shared underground zones
## beyond the Void Throne, a mouth in each region leading down and the stairs leading back, every
## camp reachable from the stairs, and fifteen or more tasks for levels 30-45.
func _cave_checks() -> void:
	var void_end: int = VoidThrone.AREA.end.x
	for cave: String in Caves.ORDER:
		var definition: Dictionary = Caves.CAVES[cave]
		var area: Rect2i = Caves.rect(cave)
		check(area.position.x >= void_end and not area.intersects(World.OVERWORLD), "%s lies beyond the Void Throne" % cave)
		for other: String in Caves.ORDER:
			check(other == cave or not area.intersects(Caves.rect(other)), "caves do not overlap")
		var zone: Dictionary = World.zone_at(area.get_center())
		check(zone.get("cave", "") == cave and zone.get("underground", false) and not zone["pvp"], "%s is a shared underground zone" % cave)
		check(World.MOUTH_OF.has(cave) and World.OVERWORLD.has_point(World.MOUTH_OF[cave])
			and World.terrain(World.MOUTH_OF[cave]) == "v" and World.region_at(World.MOUTH_OF[cave]) == definition["region"]
			and World.zone_at(World.MOUTH_OF[cave]).is_empty(), "%s's mouth opens in %s" % [cave, definition["region"]])
		check(World.CAVE_STAIRS.has(cave) and area.has_point(World.CAVE_STAIRS[cave]), "%s has stairs up" % cave)
		# Every camp is reachable from the stairs on foot.
		var reached: Dictionary = {World.CAVE_STAIRS.get(cave, area.position): true}
		var queue: Array[Vector2i] = [World.CAVE_STAIRS.get(cave, area.position)]
		while not queue.is_empty():
			var at: Vector2i = queue.pop_back()
			for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if area.has_point(at + side) and not reached.has(at + side) and World.terrain(at + side) in World.WALKABLE:
					reached[at + side] = true
					queue.append(at + side)
		var kinds: Dictionary = {}
		for spawn: Dictionary in World.MONSTER_SPAWNS:
			if area.has_point(spawn["cell"]):
				kinds[spawn["monster"]] = true
				check(reached.has(spawn["cell"]) and spawn["level"] >= definition["min_level"] and spawn["level"] <= definition["max_level"]
					and (Monsters.MONSTERS[spawn["monster"]]["rank"] in ["elite", "champion"] or not definition.get("elite", true)),
					"%s's camps hold elites (or, in the trench, normal monsters) of its levels, reachable from the stairs" % cave)
		for camp: Array in definition["camps"] + ([definition["champion"]] if definition.has("champion") else []):
			check(kinds.has(camp[0]) and (SpriteArt.CREATURES.has(camp[0]) or Monsters.MONSTERS[camp[0]].has("gear")),
				"%s holds %s, drawn" % [cave, camp[0]])
			check(Quests.TASKS.values().any(func(task: Dictionary) -> bool: return task["monster"] == camp[0]) and Monsters.LOOT.has(camp[0]),
				"%s has a task and loot" % camp[0])
	var world := World.new()
	var combat := Combat.new(world, 37)
	var instances := Instances.new(world, combat)
	world.monsters.clear()
	check(world.add_player(1, 0.0, "knight"), "cave player")
	_place(world, 1, World.MOUTH_OF["ogre_warrens"])
	var events: Array = instances.after_move(1, 1.0)
	var below: Vector2i = world.players[1]["cell"]
	check(World.zone_at(below).get("cave", "") == "ogre_warrens" and World.chebyshev(below, World.CAVE_STAIRS["ogre_warrens"]) <= 3
		and below != World.CAVE_STAIRS["ogre_warrens"], "a cave mouth leads down beside the stairs")
	check(events.any(func(event: Dictionary) -> bool: return event["kind"] == "message" and event["text"].contains("Ogre Warrens")),
		"climbing down names the cave")
	_place(world, 1, World.CAVE_STAIRS["ogre_warrens"])
	instances.after_move(1, 2.0)
	var above: Vector2i = world.players[1]["cell"]
	check(World.OVERWORLD.has_point(above) and World.chebyshev(above, World.MOUTH_OF["ogre_warrens"]) <= 3
		and above != World.MOUTH_OF["ogre_warrens"], "the stairs lead back out beside the mouth")
	var targets: Array[Vector2i] = World.task_targets("ogre_brutes", {})
	check(targets == [World.MOUTH_OF["ogre_warrens"]], "a cave task points at the cave's mouth")
	var thirties: int = 0
	for task: String in Quests.TASKS:
		var level: int = int(Quests.TASKS[task].get("level", 0))
		thirties += 1 if level >= 30 and level <= 45 and Caves.of_monster(Quests.TASKS[task]["monster"]) != "" else 0
	check(thirties >= 15, "the elite caves give levels 30-45 fifteen tasks (%d)" % thirties)


## The frost isles (tools/generators/frost_isles.gd): reached only by boat, shown west of the
## mainland on the world map, with Hrimvik's snowy streets and the trench under the sea ice.
func _isles_checks() -> void:
	var isles: Rect2i = Biomes.ISLES
	check(not isles.intersects(Atlas.MAINLAND) and isles.position.y - Atlas.MAINLAND.end.y >= 32,
		"open sea lies between the mainland and the frost isles")
	# The world map: every sheet maps onto its own part of the atlas and back.
	for sheet: Dictionary in Atlas.SHEETS:
		for cell: Vector2i in [sheet["cells"].position, sheet["cells"].end - Vector2i.ONE, sheet["cells"].get_center()]:
			var point: Vector2 = Atlas.to_map(Vector2(cell))
			check(Rect2(Vector2.ZERO, Vector2(Atlas.SIZE)).has_point(point) and Vector2i(Atlas.from_map(point)) == cell,
				"the world map places %s and finds it again" % cell)
	check(not Rect2(Atlas.SHEETS[0]["at"], Atlas.SHEETS[0]["cells"].size).intersects(Rect2(Atlas.SHEETS[1]["at"],
		Atlas.SHEETS[1]["cells"].size)) and Atlas.to_map(Vector2(isles.get_center())).x < Atlas.to_map(Vector2(0, 0)).x,
		"the isles lie west of the mainland on the world map")
	# Reached only by boat: walking from the mainland never reaches the isles, and every boat
	# route has a route back.
	var walk: Callable = func(start: Vector2i) -> Dictionary:
		var reached: Dictionary = {start: true}
		var queue: Array[Vector2i] = [start]
		while not queue.is_empty():
			var at: Vector2i = queue.pop_back()
			for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var next: Vector2i = at + side
				if not reached.has(next) and World.OVERWORLD.has_point(next) and World.terrain(next) in World.WALKABLE:
					reached[next] = true
					queue.append(next)
		return reached
	var mainland: Dictionary = walk.call(World.SPAWNS[0])
	check(not mainland.keys().any(func(cell: Vector2i) -> bool: return isles.has_point(cell)),
		"no road leads from the mainland to the isles")
	var boat: Vector2i = World.FERRYMEN["hrimvik"]["cell"]
	var island: Dictionary = walk.call(boat + Vector2i.LEFT)
	for port: String in World.FERRYMEN["hrimvik"]["routes"]:
		check(World.FERRYMEN[port]["routes"].get("hrimvik", -1) == World.FERRYMEN["hrimvik"]["routes"][port]
			and World.FERRYMEN[port]["vehicle"] == "ferry", "the boat to Hrimvik sails back from %s for the same fare" % port)
	check(World.FERRYMEN["hrimvik"]["routes"].size() >= 2, "Hrimvik's boat reaches the mainland ports")
	var mouth: Vector2i = World.MOUTH_OF["rimewater_trench"]
	check([Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN].any(func(side: Vector2i) -> bool: return island.has(mouth + side)),
		"the trench mouth is a walk from Hrimvik's harbour")
	var camps: int = 0
	for spawn: Dictionary in World.MONSTER_SPAWNS:
		if isles.has_point(spawn["cell"]):
			camps += 1
			check(island.has(spawn["cell"]), "%s's camp on the isles is a walk from the harbour" % spawn["monster"])
	check(camps >= 6, "the isles have tundra camps")
	var town: Dictionary = World.zone_at(boat + Vector2i(-14, 0))
	check(town.get("name", "") == "Hrimvik" and town.get("town", false), "Hrimvik is a safe town by its harbour")
	var homes: Array = World.BUILDINGS.filter(func(building: Dictionary) -> bool: return Biomes.in_isles(building["rect"].position))
	check(homes.size() >= 12, "Hrimvik has its blockhouses and huts (%d)" % homes.size())
	check(World.TOWNSFOLK.values().any(func(keeper: Dictionary) -> bool: return keeper["place"] == "Hrimvik" and keeper["role"] == "vendor"),
		"Hrimvik has a vendor")
	# Snow is land, firs are trees, and the isles draw in winter dress.
	check("s" in World.WALKABLE and "s" in World.LAND and "P" in World.TREES and "P" not in World.WALKABLE,
		"snow is walkable land and firs block")
	var house: Dictionary = homes[0]
	check(SpriteArt.wall_sheet(house["rect"].position) == SpriteArt.LOG_WALLS, "Hrimvik's houses have log walls")
	check(SpriteArt._floor_index("=", house["interior"][0], 0.0) in [SpriteArt.PLANK_TILE, SpriteArt.PLANK_TILE + 1]
		and SpriteArt._floor_index("=", town["rect"].position + Vector2i(1, 16), 0.0) >= SpriteArt.SNOW_COBBLE_TILE,
		"Hrimvik's houses have plank floors and its streets are snowy")
	var weather: Dictionary = Weather.local(0.0, boat)
	check(weather.get("snow", false) and weather["rain"] > 0.0 and weather["flash"] == 0.0, "it snows over the isles")
	var isle_regions: Array[String] = ["Hrimfold Tundra", "Wolfskerry", "Rimewater Floes"]
	check(World.region_at(boat + Vector2i(-14, 0)) in isle_regions and World.region_at(Vector2i(60, 370)) not in isle_regions,
		"the isles keep their own regions")


## Performance at scale (plan 29): a tick visits only monsters near players or busy, camps spawn
## when first visited, the bots' nearby lookup misses nothing, and continents cover the overworld.
func _scale_checks() -> void:
	var world := World.new()
	var combat := Combat.new(world, 29)
	world.monsters.clear()
	combat.populate(0.0)
	check(world.monsters.is_empty() and combat.dormant_camps() == World.MONSTER_SPAWNS.size(),
		"camps wait dormant until someone comes near")
	check(world.add_player(1, 0.0, "knight"), "scale player")
	# Level 50, so the camp it wakes does not kill it and send it home to wake others.
	world.players[1]["level"] = Balance.MAX_LEVEL
	world.players[1]["health"] = world.player_stats(1)["health"]
	var index: int = -1
	for spawn: int in World.MONSTER_SPAWNS.size():
		if World.MONSTER_SPAWNS[spawn]["monster"] == "snow_wolf":
			index = spawn
			break
	var camp: Dictionary = World.MONSTER_SPAWNS[index]
	_place(world, 1, camp["cell"] + Vector2i(4, 0))
	for step: int in 20:
		combat.tick(1.0 + step * 0.5)
	var placed: int = world.monsters.values().filter(func(monster: Dictionary) -> bool: return monster["spawn"] == index).size()
	check(placed == camp["count"], "a camp fills when a player comes near (%d of %d)" % [placed, camp["count"]])
	check(combat.dormant_camps() > World.MONSTER_SPAWNS.size() * 0.8 and world.monsters.size() < 200,
		"camps far from everyone stay dormant (%d live)" % world.monsters.size())
	var far: Vector2i = World.SPAWNS[0]
	check(not world.monsters.values().any(func(monster: Dictionary) -> bool:
		return Combat.distance(monster["home"], camp["cell"]) > (Combat.WAKE_REACH + 2) * Combat.SLEEP_CHUNK)
		and Combat.distance(far, camp["cell"]) > 100, "only the camps round the player woke")
	# Every camp filled at once, as tools and tests may ask: a tick visits a small share.
	var full_world := World.new()
	var full := Combat.new(full_world, 30)
	full_world.monsters.clear()
	full.populate(0.0, true)
	check(full.dormant_camps() == 0 and full_world.monsters.size() > 1000, "populate can still fill every camp at once")
	full_world.add_player(1, 0.0, "knight")
	_place(full_world, 1, camp["cell"] + Vector2i(4, 0))
	var visited: Array = full._near_players()
	check(visited.size() * 10 < full_world.monsters.size(), "a tick visits only the monsters near players (%d of %d)" % [
		visited.size(), full_world.monsters.size()])
	var in_order: bool = true
	for at: int in range(1, visited.size()):
		in_order = in_order and visited[at - 1] > visited[at]
	check(in_order, "monsters are visited oldest first, as world.monsters keeps them")
	# The bots' lookup finds every monster a full scan finds.
	for probe: Vector2i in [camp["cell"], World.SPAWNS[0], Vector2i(200, 150)]:
		var near: Array = full.monsters_near(probe, 10)
		var missed: int = 0
		for id: int in full_world.monsters:
			if Combat.distance(full_world.monsters[id]["cell"], probe) <= 10 and not near.has(id):
				missed += 1
		check(missed == 0, "monsters_near misses nothing within its radius of %s" % probe)
	# Adding and removing monsters behind Combat's back rebuilds the index.
	var odd: int = -900001
	full_world.monsters[odd] = {"id": odd, "kind": "snow_wolf", "home": camp["cell"], "cell": camp["cell"], "target": 0,
		"engaged_at": -1.0}
	check(full._near_players().has(odd), "a monster added directly is indexed")
	full_world.monsters.erase(odd)
	check(not full._near_players().has(odd), "a monster removed directly leaves the index")
	# Continents.
	for sheet: Dictionary in Atlas.SHEETS:
		for cell: Vector2i in [sheet["cells"].position, sheet["cells"].get_center(), sheet["cells"].end - Vector2i.ONE]:
			check(World.continent_at(cell) == sheet["name"], "%s lies on %s" % [cell, sheet["name"]])
	check(World.continent_at(World.FERRYMEN["hrimvik"]["cell"]) == "the frost isles"
		and World.continent_at(World.SPAWNS[0]) == "the mainland", "Hrimvik is on the frost isles, Cinder Crossing on the mainland")


## Spell effects (plan 33): every spell has an element with impact art, bolts and shots have
## projectile art, and casts carry the element to the client.
func _spell_fx_checks() -> void:
	for spell: String in Spells.SPELLS:
		var element: String = Spells.element_of(spell)
		check(Spells.ELEMENTS.has(spell) and (element.is_empty() or element in SpriteArt.RUNE_FX_ELEMENTS),
			"%s has an element with impact art (%s)" % [spell, element])
		if Spells.SPELLS[spell]["kind"] in ["target", "root", "slow"]:
			check(element in SpriteArt.MISSILE_ELEMENTS or element == "slash", "%s flies as a sprite or strikes in melee" % spell)
	check(SpriteArt.RUNE_FX.get_height() == SpriteArt.RUNE_FX_ELEMENTS.size() * World.TILE_SIZE
		and SpriteArt.SPELL_MISSILES.get_height() == SpriteArt.MISSILE_ELEMENTS.size() * SpriteArt.MISSILE_SIZE,
		"the effect sheets hold a row for every element")
	var world := World.new()
	var combat := Combat.new(world, 33)
	world.monsters.clear()
	check(world.add_player(1, 0.0, "sorcerer") and world.add_player(2, 0.0, "druid"), "spell effect players")
	_place(world, 1, Vector2i(5, 6))
	_place(world, 2, Vector2i(6, 6))
	var vole: int = combat.spawn_monster("field_vole", 1, Vector2i(5, 9), 0.0)
	combat.set_target(1, vole, 0.0)
	var bolt: Dictionary = combat.cast(1, "ember_bolt", 1.0)
	check(bolt["ok"] and bolt["events"].any(func(event: Dictionary) -> bool:
		return event["kind"] == "missile" and event.get("element", "") == "fire"), "an ember bolt flies as fire")
	var mend: Dictionary = combat.cast(2, "mass_mend", 1.0)
	check(mend["ok"] and mend["events"].any(func(event: Dictionary) -> bool:
		return event["kind"] == "area" and event.get("element", "") == "heal"), "a mass mend lands as healing motes")


## Endgame titles (game/data/titles.gd): the ladder's rules, earned once and kept, the final
## bosses slain recorded, saved and restored, and exported for others to see.
func _title_checks() -> void:
	var champions: Array[String] = Titles.champion_tasks()
	check(champions.size() >= Titles.CHAMPIONS_SECOND and Titles.final_bosses().size() >= 3,
		"there are enough champion tasks and final bosses for the ladder (%d, %d)" % [champions.size(), Titles.final_bosses().size()])
	for vocation: String in Balance.VOCATIONS:
		if vocation != Balance.ADVENTURER:
			check(Titles.NAMES.has(vocation) and Titles.NAMES[vocation].size() == 3, "%ss have three titles" % vocation)
	check(Titles.name_of(Balance.ADVENTURER, 2).is_empty(), "Adventurers carry no title")
	var three: Dictionary = {}
	var six: Dictionary = {Titles.LODGE_TASK: true}
	for index: int in champions.size():
		if index < 3:
			three[champions[index]] = true
		if index < 6:
			six[champions[index]] = true
	var all_bosses: Dictionary = {}
	for boss: String in Titles.final_bosses():
		all_bosses[boss] = true
	var one_short: Dictionary = all_bosses.duplicate()
	one_short.erase(Titles.final_bosses()[0])
	check(Titles.tier_for(29, three, {}) == 0 and Titles.tier_for(30, three, {}) == 1, "the first title asks for level 30 and three champions")
	check(Titles.tier_for(40, six, {}) == 2 and Titles.tier_for(40, three.merged({Titles.LODGE_TASK: true}), {}) == 1
		and Titles.tier_for(39, six, {}) == 1, "the second asks for level 40, the Lodge, and six champions")
	check(Titles.tier_for(50, six, all_bosses) == 3 and Titles.tier_for(50, six, one_short) == 2,
		"the third asks for level 50 and every final boss slain")
	check(Titles.next_step("knight", 0, {}, {}).contains("Vanguard") and Titles.next_step("knight", 3, six, all_bosses).is_empty(),
		"the character window names the next title, and nothing past the last")
	var world := World.new()
	var combat := Combat.new(world, 30)
	world.monsters.clear()
	check(world.add_player(1, 0.0, "sorcerer"), "title player")
	var player: Dictionary = world.players[1]
	check(player["title"] == 0 and player["slain"].is_empty(), "a new character has no title")
	player["level"] = 30
	player["done_tasks"] = three.duplicate()
	var events: Array = []
	combat.check_title(1, events)
	check(player["title"] == 1 and events.any(func(event: Dictionary) -> bool:
		return event["kind"] == "message" and event["text"].contains("Magister")), "earning a title says so")
	events.clear()
	combat.check_title(1, events)
	check(events.is_empty(), "a title is announced once")
	player["level"] = 20
	combat.check_title(1, events)
	check(player["title"] == 1 and world.export_player(1, 0.0)["title"] == 1, "a title is kept after a death costs levels, and others see it")
	combat._award_trophies(Titles.final_bosses()[0], {1: true}, player["cell"], [])
	check(player["slain"].has(Titles.final_bosses()[0]), "a final boss kill is recorded for the titles")
	var saved: Dictionary = CharacterStore.capture(world, 1, 0.0)
	var restored := World.new()
	restored.add_player(1, 0.0, "sorcerer")
	CharacterStore.restore(restored, 1, JSON.parse_string(JSON.stringify(saved)), 0.0)
	check(restored.players[1]["title"] == 1 and restored.players[1]["slain"].has(Titles.final_bosses()[0]),
		"titles and slain bosses are saved and restored")


## The countryside is populated (tools/generators/fill_gaps.gd): nearly all open ground lies within
## sight of a camp, the gap-filling camps copy a normal camp of their own region, and monsters come
## back at a calm pace.
func _gap_checks() -> void:
	check(is_equal_approx(Monsters.RESPAWN_SECONDS, 75.0), "monsters respawn after 75 seconds")
	var camps: Array[Vector2i] = []
	var by_region: Dictionary = {}
	for spawn: Dictionary in World.MONSTER_SPAWNS:
		camps.append(spawn["cell"])
		if Monsters.MONSTERS[spawn["monster"]]["rank"] == "normal" and World.zone_at(spawn["cell"]).is_empty():
			var region: String = World.region_at(spawn["cell"])
			if not by_region.has(region):
				by_region[region] = {}
			by_region[region]["%s/%d" % [spawn["monster"], spawn["level"]]] = true
	var near: int = 0
	var samples: int = 0
	for y: int in range(0, World.OVERWORLD.end.y, 6):
		for x: int in range(0, World.OVERWORLD.end.x, 6):
			var cell := Vector2i(x, y)
			if World.terrain(cell) not in [".", ":", "m", "s"] or not World.zone_at(cell).is_empty():
				continue
			samples += 1
			for camp: Vector2i in camps:
				if World.chebyshev(camp, cell) <= 11:
					near += 1
					break
	check(samples > 500 and near >= samples * 0.95, "open country lies within sight of a camp (%d of %d)" % [near, samples])
	for spawn: Dictionary in World.MONSTER_SPAWNS:
		var region: String = World.region_at(spawn["cell"])
		if spawn["count"] == 5 and spawn["radius"] == 2 and by_region.has(region) and World.zone_at(spawn["cell"]).is_empty() 				and Monsters.MONSTERS[spawn["monster"]]["rank"] == "normal":
			check(by_region[region].has("%s/%d" % [spawn["monster"], spawn["level"]]), "%s camps keep %s's levels" % [spawn["monster"], region])


## The Cyclops Hollow (plan 37): its 75-kill hunt counts only kills inside the cave, pays its
## potions, and rolls one of the Hollow's rare pieces about one turn-in in four.
func _hollow_checks() -> void:
	var task: String = "hundred_eyed_hollow"
	var definition: Dictionary = Quests.TASKS[task]
	check(definition["count"] == 75 and Quests.counts(task, "cyclops") and Quests.counts(task, "cyclops_smith")
		and Caves.CAVES.has(definition["cave"]) and World.MOUTH_OF.has(definition["cave"]), "the Hollow's hunt asks for 75 cyclopes in its cave")
	for kind: String in definition["rare"]["items"]:
		check(World.ITEMS[kind]["level"] == 35 and World.bound(kind) and World.ITEMS[kind].has("quest")
			and Items.rarity(World.ITEMS[kind])[0] == "Epic", "%s is the Hollow's own Epic piece" % kind)
	var world := World.new()
	var combat := Combat.new(world, 37)
	world.monsters.clear()
	check(world.add_player(1, 0.0, "knight"), "hollow player")
	var player: Dictionary = world.players[1]
	player["level"] = 35
	player["tasks"][task] = 0
	var inside: Vector2i = World.CAVE_STAIRS[definition["cave"]]
	combat._credit_tasks("cyclops", [1], [], Vector2i(310, 40))
	check(player["tasks"][task] == 0, "a cyclops killed outside the Hollow does not count")
	combat._credit_tasks("cyclops_smith", [1], [], inside)
	check(player["tasks"][task] == 1, "a smith killed inside the Hollow counts")
	var giver: Vector2i = World.QUEST_GIVERS[definition["giver"]]["cell"]
	var rare: int = 0
	for attempt: int in 40:
		player["done_tasks"].erase(task)
		player["tasks"][task] = definition["count"]
		player["backpack"].fill("")
		_place(world, 1, giver + Vector2i.DOWN)
		var done: Dictionary = combat.task_action(1, definition["giver"], task, "complete", 1.0)
		check(done["ok"], "the Hollow's hunt can be turned in (%s)" % done.get("reason", ""))
		var kinds: Array = player["backpack"].map(func(entry: String) -> String: return World.kind_of(entry))
		check(kinds.has("health_potion") and kinds.has("mana_potion"), "the Hollow pays its potions")
		if kinds.any(func(kind: String) -> bool: return kind in definition["rare"]["items"]):
			rare += 1
	check(rare >= 3 and rare <= 20, "a rare piece comes about one turn-in in four (%d of 40)" % rare)


## Walls that belong to nothing are gone (plan 31, tools/generators/clear_walls.gd): every stone
## wall left is part of a building or a town's own wall, and no pastures are fenced any more.
func _stray_wall_checks() -> void:
	var stray: Array[Vector2i] = ClearWalls.stray_walls()
	check(stray.is_empty(), "no stray walls on the map (%d, first %s)" % [stray.size(), stray.slice(0, 3)])
	check(Landscape.PASTURES_PER_TOWN == 0, "the landscape fences no pastures")
	# Towns are paved inside their walls, as in Tibia (tools/generators/cobble_towns.gd).
	var unpaved: Dictionary = CobbleTowns.paving()
	check(unpaved.is_empty(), "every town is paved (%d tiles left, first %s)" % [unpaved.size(), unpaved.keys().slice(0, 3)])


## Nameplates and the target frame (Monsters.title) mark elites, and roots and slows pass bosses
## and champions by.
func _monster_title_checks() -> void:
	for kind: String in Monsters.MONSTERS:
		var definition: Dictionary = Monsters.MONSTERS[kind]
		var title: String = Monsters.title(kind, 30)
		check(title.begins_with("Elite ") == (definition["rank"] == "elite") and title.ends_with("%s 30" % definition["name"]),
			"%s's title is \"%s\"" % [kind, title])
	check(Monsters.title("grimclaw", 37, true).ends_with("ENRAGED"), "a raging boss's title says so")

func _dungeon_checks() -> void:
	check(load("res://tools/generators/dungeons.gd").TERRAINS == World.TERRAINS, "the dungeon painter uses the map terrains")
	check(Dungeons.ORDER.size() == Dungeons.DUNGEONS.size() and World.ENTRANCE_OF.size() == Dungeons.DUNGEONS.size(),
		"every dungeon has one stairway")
	for dungeon: String in Dungeons.DUNGEONS:
		var definition: Dictionary = Dungeons.DUNGEONS[dungeon]
		var stairs: Vector2i = World.ENTRANCE_OF[dungeon]
		check(World.OVERWORLD.has_point(stairs) and World.terrain(stairs) == "v" and (World.zone_at(stairs).get("town", false)
			or definition.has("entrance") and World.zone_at(stairs).is_empty() and World.region_at(stairs) == definition["town"]),
			"%s starts from a town stairway (or one in the wilds of its region)" % dungeon)
		check(World.zone_at(Dungeons.origin(dungeon, 0)).get("dark", false) == definition.get("dark", false),
			"%s copies carry its darkness" % dungeon)
		check(Dungeons.cells(dungeon, "^").size() == 1 and Dungeons.cells(dungeon, "@").size() == 1
			and Dungeons.cells(dungeon, definition["boss"]).size() == 1, "%s has one exit, arrival, and champion" % dungeon)
		# Every floor tile, monster, and the champion can be walked to from the arrival, props and all.
		var first: Vector2i = Dungeons.origin(dungeon, 0)
		var arrival: Vector2i = first + Dungeons.cells(dungeon, "@")[0]
		var reached: Dictionary = {arrival: true}
		var queue: Array[Vector2i] = [arrival]
		while not queue.is_empty():
			var at: Vector2i = queue.pop_back()
			for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if not reached.has(at + step) and World.walkable(at + step):
					reached[at + step] = true
					queue.append(at + step)
		var open: int = 0
		for y: int in Dungeons.size(dungeon).y:
			for x: int in Dungeons.size(dungeon).x:
				var cell: Vector2i = first + Vector2i(x, y)
				open += 1 if World.walkable(cell) else 0
		check(reached.size() == open, "every open tile of %s can be reached (%d of %d)" % [dungeon, reached.size(), open])
		var boss: String = Dungeons.DUNGEONS[dungeon]["monsters"][definition["boss"]][0]
		check(Monsters.MONSTERS[boss]["rank"] == "champion" and Monsters.LOOT[boss].size() >= 2, "%s ends with a champion" % dungeon)
		for spawn: Array in Dungeons.spawns(dungeon):
			check(Monsters.MONSTERS.has(spawn[1]) and spawn[2] >= definition["min_level"] and spawn[2] <= definition["max_level"],
				"%s monster levels fit the dungeon" % dungeon)
		for copy: int in definition["copies"]:
			var rect: Rect2i = Dungeons.rect(dungeon, copy)
			check(not rect.intersects(World.OVERWORLD) and World.dungeon_at(rect.position + Vector2i.ONE) == [dungeon, copy],
				"%s copy %d sits outside the overworld" % [dungeon, copy])
			check(rect.end.x <= Dungeons.BAND_END, "%s copy %d ends before the Void Throne arena" % [dungeon, copy])
			for other_copy: int in range(copy + 1, definition["copies"]):
				check(not rect.intersects(Dungeons.rect(dungeon, other_copy)), "dungeon copies do not overlap")
			var origin: Vector2i = Dungeons.origin(dungeon, copy)
			check(World.terrain(origin + Dungeons.cells(dungeon, "^")[0]) == "^"
				and World.walkable(origin + Dungeons.cells(dungeon, "@")[0]), "%s copy %d is painted" % [dungeon, copy])
	var monster_count: int = 0
	for spawn: Dictionary in World.MONSTER_SPAWNS:
		check(World.OVERWORLD.has_point(spawn["cell"]) or World.zone_at(spawn["cell"]).get("name", "") == "The Void Throne"
			or World.zone_at(spawn["cell"]).has("cave"), "overworld spawns stay out of dungeon copies")
		monster_count += spawn["count"]
	check(monster_count > 550, "the smaller overworld is densely populated")

	var world := World.new()
	var combat := Combat.new(world, 31)
	var instances := Instances.new(world, combat)
	world.monsters.clear()
	for id: int in [1, 2, 3]:
		check(world.add_player(id, 0.0, ["knight", "druid", "paladin"][id - 1]), "dungeon player %d" % id)
	var entrance: Vector2i = World.ENTRANCE_OF["cinder_cellar"]
	_place(world, 1, entrance)
	var events: Array = instances.after_move(1, 1.0)
	var place: Array = World.dungeon_at(world.players[1]["cell"])
	check(place == ["cinder_cellar", 0] and instances.copies["cinder_cellar"][0]["owner"] == 1
		and world.monsters.size() == Dungeons.spawns("cinder_cellar").size(), "the stairway opens a private cellar copy")
	check(events.any(func(event: Dictionary) -> bool: return event["kind"] == "message" and event["text"].contains("Cinder cellar")),
		"entering a dungeon explains where you are")
	check(events.filter(func(event: Dictionary) -> bool: return event["kind"] == "monster").size() == Dungeons.spawns("cinder_cellar").size(),
		"a claimed copy publishes its monsters")
	combat.party_action(1, "invite", 2, 1.0)
	combat.party_action(2, "join", 1, 1.0)
	_place(world, 2, entrance)
	instances.after_move(2, 2.0)
	check(World.dungeon_at(world.players[2]["cell"]) == place and world.monsters.size() == Dungeons.spawns("cinder_cellar").size(),
		"party members share their leader's copy")
	_place(world, 3, entrance)
	instances.after_move(3, 3.0)
	check(World.dungeon_at(world.players[3]["cell"]) == ["cinder_cellar", 1]
		and world.monsters.size() == 2 * Dungeons.spawns("cinder_cellar").size(), "another player gets another copy")
	for id: int in world.monsters:
		check(World.dungeon_at(world.monsters[id]["cell"]) == World.dungeon_at(world.monsters[id]["home"]),
			"dungeon monsters stay in their copy")
	check(not events.any(func(event: Dictionary) -> bool: return event["kind"] == "message" and event["text"].contains("torch")),
		"a lit dungeon needs no torch")
	var exit: Vector2i = Dungeons.origin("cinder_cellar", 1) + Dungeons.cells("cinder_cellar", "^")[0]
	_place(world, 3, exit)
	instances.after_move(3, 4.0)
	check(World.OVERWORLD.has_point(world.players[3]["cell"]) and Combat.distance(world.players[3]["cell"], entrance) <= 3
		and world.players[3]["cell"] != entrance, "the stairs up return beside the town stairway")
	var copy_rect: Rect2i = Dungeons.rect("cinder_cellar", 1)
	world.ground[copy_rect.position + Vector2i(2, 2)] = ["rat_tail"]
	instances.tick(5.0)
	check(instances.copies["cinder_cellar"][1]["owner"] == 3, "an emptied copy waits before resetting")
	events = instances.tick(5.0 + Dungeons.RESET_SECONDS)
	check(instances.copies["cinder_cellar"][1]["owner"] == 0 and not world.ground.has(copy_rect.position + Vector2i(2, 2))
		and world.monsters.size() == Dungeons.spawns("cinder_cellar").size(), "an empty copy resets its monsters and items")
	check(events.any(func(event: Dictionary) -> bool: return event["kind"] == "monster_gone"), "a reset removes its monsters")
	for copy: int in range(1, Dungeons.DUNGEONS["cinder_cellar"]["copies"]):
		instances.copies["cinder_cellar"][copy]["owner"] = 100 + copy
	_place(world, 3, entrance)
	events = instances.after_move(3, 10.0)
	check(World.OVERWORLD.has_point(world.players[3]["cell"]) and world.players[3]["cell"] != entrance
		and events.any(func(event: Dictionary) -> bool: return event["kind"] == "message" and event["text"].contains("in use")),
		"a full dungeon keeps the player outside")
	var restored := World.new()
	var restored_combat := Combat.new(restored, 1)
	var restored_instances := Instances.new(restored, restored_combat)
	restored.add_player(4, 0.0)
	_place(restored, 4, Dungeons.origin("ashford_crypt", 2) + Dungeons.cells("ashford_crypt", "@")[0])
	restored_instances.evacuate(4, 0.0)
	check(Combat.distance(restored.players[4]["cell"], World.ENTRANCE_OF["ashford_crypt"]) <= 3,
		"a character saved in an expired dungeon returns to its stairway")
	# Silkhollow is dark: entering without a torch in the off hand says so.
	var torch_hints: Array[bool] = []
	for id: int in [5, 6]:
		restored.add_player(id, 0.0)
		if id == 6:
			restored.players[id]["equipment"]["off_hand"] = "torch"
		_place(restored, id, World.ENTRANCE_OF["silkhollow"])
		var entered: Array = restored_instances.after_move(id, 1.0)
		torch_hints.append(entered.any(func(event: Dictionary) -> bool: return event["kind"] == "message" and event["text"].contains("torch")))
	check(World.dungeon_at(restored.players[5]["cell"])[0] == "silkhollow" and torch_hints == [true, false],
		"Silkhollow tells players without a torch to bring one")

	var outside: int = combat.spawn_monster("field_vole", 1, Vector2i(World.OVERWORLD.end.x - 3, 5), 0.0)
	_place(world, 2, Dungeons.origin("cinder_cellar", 0) + Vector2i(1, 4))
	check(not combat.hostile(outside, 2) and not combat.hostile(2, outside), "the overworld and a dungeon copy never fight")
	# Sleeping monsters: an untouched monster far from players does not act.
	var quiet := World.new()
	var quiet_combat := Combat.new(quiet, 2)
	quiet.monsters.clear()
	quiet.add_player(1, 0.0)
	_place(quiet, 1, Vector2i(10, 10))
	var far: int = quiet_combat.spawn_monster("field_vole", 1, Vector2i(200, 200), 0.0)
	var near: int = quiet_combat.spawn_monster("field_vole", 1, Vector2i(13, 10), 0.0)
	quiet_combat.tick(1.0)
	check(quiet.monsters[far]["target"] == 0 and quiet.monsters[near]["target"] == 1, "only monsters near players wake")


## The desert's plants and sand, and weather derived from the shared host clock.
func _climate_checks() -> void:
	check(load("res://tools/generators/desert.gd").TERRAINS == World.TERRAINS, "the desert painter uses the map terrains")
	check("K" in World.TREES and "K" in World.TERRAINS and not "K" in World.WALKABLE, "desert plants block like trees")
	var plants: int = 0
	var leafy: int = 0
	var grass: int = 0
	var sand: int = 0
	for y: int in range(Biomes.DESERT_AREA.position.y, Biomes.DESERT_AREA.end.y):
		for x: int in range(Biomes.DESERT_AREA.position.x, Biomes.DESERT_AREA.end.x):
			var cell := Vector2i(x, y)
			var tile: String = World.terrain(cell)
			if tile == "K":
				plants += 1
				check(Biomes.desert_distance(cell) <= 1.25, "desert plants grow only in the desert")
			if Biomes.desert_distance(cell) < 0.85:
				leafy += 1 if tile == "T" else 0
				grass += 1 if tile == "." else 0
				sand += 1 if tile == ":" or tile == "K" else 0
	check(plants > 40, "the desert has cacti and thorn scrub")
	check(leafy == 0 and grass == 0 and sand > 8000, "no leafy trees or grass patches inside the desert")
	# Weather: the same clock gives the same weather on every peer, it changes smoothly, and
	# every kind occurs over a long session.
	Weather.override = ""
	var seen: Dictionary = {}
	var smooth: bool = true
	var bounded: bool = true
	var previous: Dictionary = Weather.at(0.0)
	for step: int in range(1, 24000):
		var ticks: float = step * 5.0
		var now: Dictionary = Weather.at(ticks)
		seen[now["kind"]] = true
		for key: String in ["cloud", "rain", "storm"]:
			bounded = bounded and now[key] >= 0.0 and now[key] <= 1.0
			smooth = smooth and absf(now[key] - previous[key]) <= 5.0 / Weather.BLEND_SECONDS * 1.6 + 0.001
		bounded = bounded and now["flash"] >= 0.0 and now["flash"] <= 1.0
		previous = now
	check(seen.size() == 4, "clear, overcast, rain, and storm all occur")
	check(smooth and bounded, "weather values stay in 0..1 and blend smoothly between slots")
	check(Weather.at(12345.6) == Weather.at(12345.6), "weather is a pure function of the host clock")
	var flashes: int = 0
	for step: int in 4000:
		flashes += 1 if Weather._flash(step * 0.05) > 0.5 else 0
	check(flashes > 0 and flashes < 400, "storms flash lightning briefly, not constantly")
	var rainy: float = -1.0
	for step: int in 2000:
		if Weather.at(step * 60.0)["rain"] > 0.6:
			rainy = step * 60.0
			break
	check(rainy >= 0.0, "it rains at some point")
	var cellar: Vector2i = Dungeons.origin("cinder_cellar", 0) + Dungeons.cells("cinder_cellar", "@")[0]
	check(Weather.local(rainy, cellar)["rain"] == 0.0 and Weather.local(rainy, cellar)["cloud"] == 0.0,
		"no weather underground")
	check(Weather.local(rainy, Vector2i(Biomes.DESERT_CENTRE))["rain"] == 0.0, "it never rains in the desert")
	check(Weather.local(rainy, World.SPAWNS[0])["rain"] > 0.6, "it rains in Cinder Crossing when the sky rains")
	_swamp_checks()
	Weather.override = "storm"
	check(Weather.tint(Weather.at(0.0)).v < 0.95 or Weather.at(0.0)["flash"] > 0.0, "storms darken the light")
	Weather.override = ""



## Mirewood Fen (tools/generators/swamp.gd): walkable bog mud and giant mushrooms that block
## like trees, only in the fen, and wet weather over it whatever the sky does elsewhere.
func _swamp_checks() -> void:
	var mud: Array[Vector2i] = []
	var mushrooms: int = 0
	var stray: int = 0
	for y: int in World.OVERWORLD.size.y:
		for x: int in World.OVERWORLD.size.x:
			var cell := Vector2i(x, y)
			var terrain: String = World.terrain(cell)
			if terrain not in ["m", "U"]:
				continue
			if World.region_at(cell) != Biomes.SWAMP_REGION:
				stray += 1
			if terrain == "m":
				mud.append(cell)
			else:
				mushrooms += 1
	check(mud.size() > 2000 and mushrooms > 300, "Mirewood Fen is bog mud and giant mushrooms")
	check(stray == 0, "bog and mushrooms grow only in Mirewood Fen")
	check(World.walkable(mud[0]) and not World.walkable(mud[0] + Vector2i(9999, 0)), "bog mud is walkable")
	check("U" in World.TREES and "U" not in World.WALKABLE, "giant mushrooms block like trees")
	check(SpriteArt.TILES.get_height() >= SpriteArt.TILE_REGIONS[SpriteArt.BOG_TILE + 3].end.y, "tiles.png holds the four bog tiles")
	var dry: float = -1.0
	for step: int in 2000:
		if Weather.at(step * 60.0)["rain"] == 0.0:
			dry = step * 60.0
			break
	check(dry >= 0.0 and Weather.local(dry, mud[0])["rain"] >= 0.3 and Weather.local(dry, mud[0])["cloud"] >= 0.55,
		"it drizzles over the fen even when the sky is dry elsewhere")
	check(Weather.local(dry, EndgameZone.THRONE_SEAT)["rain"] == 0.0, "the fen's drizzle stays out of the Hollow Reach")

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


## Town buildings: roofs, the shops and banks with their signs, and no dealing through walls.
func _building_checks() -> void:
	var Buildings: GDScript = load("res://game/data/buildings.gd")
	var Painter: GDScript = load("res://tools/generators/towns.gd")
	check(Painter.TERRAINS == World.TERRAINS, "the town painter uses the map terrains")
	var scene: Node = (load(World.MAP_SCENE) as PackedScene).instantiate()
	check(Painter.apply(scene) == 0, "the town painter has already furnished the map (a re-run changes nothing)")
	scene.free()
	# Doors: an open tile between two walls in one line only.
	var tiny: Dictionary = {}
	for y: int in 4:
		for x: int in 5:
			tiny[Vector2i(x, y)] = "#" if x == 0 or y == 0 or x == 4 or y == 3 else "="
	var lookup := func(cell: Vector2i) -> String: return tiny.get(cell, ".")
	check(Buildings.find(lookup, Rect2i(-2, -2, 9, 8)).is_empty(), "a closed room without a door is not a building")
	tiny[Vector2i(2, 3)] = "="
	check(Buildings.is_door(lookup, Vector2i(2, 3)) and not Buildings.is_door(lookup, Vector2i(0, 0))
		and not Buildings.is_door(lookup, Vector2i(2, 2)) and not Buildings.is_door(lookup, Vector2i(6, 6)),
		"doors sit between two walls in a line")
	var hut: Array = Buildings.find(lookup, Rect2i(-2, -2, 9, 8))
	check(hut.size() == 1 and hut[0]["doors"].size() == 1 and hut[0]["doors"][0] == Vector2i(2, 3)
		and hut[0]["outward"][Vector2i(2, 3)] == Vector2i.DOWN and hut[0]["rect"] == Rect2i(0, 0, 5, 4)
		and hut[0]["interior"].size() == 6 and hut[0]["footprint"].size() == 20, "a one-door hut is found with its roof footprint")
	check(Buildings.find(lookup, Rect2i(0, 0, 5, 3)).is_empty(), "a room reaching the search edge is not a building")
	# Every town: at least two buildings; its vendor (and Reedmere's banker) each keep one, with a sign.
	var towns: Dictionary = {}
	for zone: Dictionary in World.ZONES:
		if zone["town"]:
			towns[zone["name"]] = 0
	for building: Dictionary in World.BUILDINGS:
		for zone: Dictionary in World.ZONES:
			if zone["town"] and zone["rect"].grow(1).encloses(building["rect"]):
				towns[zone["name"]] += 1
		for cell: Vector2i in building["interior"] + building["doors"]:
			check(World.walkable(cell) or World.NPC_CELLS.has(cell) or World.FURNITURE.has(cell) or World.terrain(cell) == "v",
				"building rooms and doors are open")
		for door: Vector2i in building["doors"]:
			check(World.terrain(door + building["outward"][door]) in World.LAND and not World.ROOM_AT.has(door + building["outward"][door]),
				"every door opens onto land outside")
	for town: String in towns:
		check(towns[town] >= 2, "%s has at least two buildings" % town)
	check(World.SIGNS.size() == World.TOWNSFOLK.size(), "every vendor and banker has a sign")
	var stuck: Array[Vector2i] = []
	for zone: Dictionary in World.ZONES:
		if not zone["town"]:
			continue
		var buildings: Array = World.BUILDINGS.filter(func(building: Dictionary) -> bool:
			return zone["rect"].grow(1).encloses(building["rect"]))
		for front: Vector2i in TownPaths.door_fronts(buildings, zone["rect"]):
			var found: Dictionary = TownPaths.path_to_street(front, World.terrain, zone["rect"], buildings)
			if not found["ok"] or not found["cells"].is_empty():
				stuck.append(front)
	check(stuck.is_empty(), "every town door opens onto a street (tools/generators/town_paths.gd): %s" % [stuck])
	var lamp_towns: Dictionary = {}
	for lamp: Vector2i in World.LAMPS:
		lamp_towns[World.zone_at(lamp).get("name", "")] = true
	check(lamp_towns.size() == towns.size(), "every town has lamp posts")
	var used: Dictionary = {}
	for id: String in World.TOWNSFOLK:
		var keeper: Dictionary = World.TOWNSFOLK[id]
		var room: int = World.ROOM_AT.get(keeper["cell"], -1)
		check(room >= 0 and not used.has(room), "%s works inside a building of their own" % keeper["name"])
		used[room] = true
		var signs: Array = World.SIGNS.filter(func(sign: Dictionary) -> bool: return World.ROOF_AT.get(sign["cell"], -1) == room)
		check(signs.size() == 1 and signs[0]["kind"] == keeper["role"] and World.terrain(signs[0]["cell"]) in World.WALLS
			and SpriteArt.SIGN_KINDS.has(keeper["role"]) and SpriteArt.SIGN_OFFSETS.has(signs[0]["outward"]),
			"%s's building has a %s sign on the wall beside its door" % [keeper["name"], keeper["role"]])
		var building: Dictionary = World.BUILDINGS[maxi(room, 0)]
		check(keeper["facing"] == building["outward"].get(building["doors"][0], Vector2i.ZERO), "%s faces the door" % keeper["name"])
		var inside: bool = false
		var through_wall: bool = false
		for dy: int in range(-World.TALK_RANGE, World.TALK_RANGE + 1):
			for dx: int in range(-World.TALK_RANGE, World.TALK_RANGE + 1):
				var cell: Vector2i = keeper["cell"] + Vector2i(dx, dy)
				if not World.walkable(cell):
					continue
				var service: String = keeper["services"][0]
				if World.ROOM_AT.get(cell, -1) == room:
					inside = inside or World.serves(id, service, cell)
				else:
					through_wall = through_wall or World.serves(id, service, cell) or World.npc_near(cell, service) == id
		check(inside and not through_wall, "%s serves only customers inside the building" % keeper["name"])
	# Furniture: only inside keepers' buildings, blocking, and never cutting a room off.
	check(World.FURNITURE.size() >= World.TOWNSFOLK.size() * 3, "shops and the bank are furnished (%d pieces)" % World.FURNITURE.size())
	# Homes: every building nobody keeps has a bed and a chest, and its floor still reaches the door.
	var homes: int = 0
	for building: Dictionary in World.BUILDINGS:
		var interior: Array = building["interior"]
		var pieces: Array = interior.filter(func(cell: Vector2i) -> bool: return World.FURNITURE.has(cell)).map(
			func(cell: Vector2i) -> String: return World.FURNITURE[cell])
		if "bed" in pieces:
			homes += 1
			var door: Vector2i = building["doors"][0]
			var entrance: Vector2i = door - building["outward"][door]
			check("chest" in pieces and World._room_open(building, entrance, entrance),
				"the home at %s has a bed and a chest and every tile reaches its door" % building["rect"].position)
	check(homes >= 30, "town houses are lived in (%d homes)" % homes)
	# Streets: lamps, wells, benches, and stalls never split a town's ways (the same number of
	# connected areas with them as without).
	var street: Array[String] = ["lamp_post", "well", "bench", "stall", "fountain", "fountain_basin", "stall_back", "bench_back",
		"crate", "barrel"]
	check(World.LAMPS.size() >= 40, "town streets have lamp posts (%d)" % World.LAMPS.size())
	# Every town's square is a market round a fountain: 3x3, drawn from its bottom-middle tile.
	for zone: Dictionary in World.ZONES:
		if zone["town"]:
			var fountains: Array = World.FURNITURE.keys().filter(func(cell: Vector2i) -> bool:
				return World.FURNITURE[cell] == "fountain" and zone["rect"].has_point(cell))
			var basin: bool = fountains.size() == 1
			if basin:
				for dy: int in range(-2, 1):
					for dx: int in range(-1, 2):
						basin = basin and World.FURNITURE.get(fountains[0] + Vector2i(dx, dy), "") in SpriteArt.FOUNTAIN_KINDS
			var stalls: int = World.FURNITURE.keys().filter(func(cell: Vector2i) -> bool:
				return World.FURNITURE[cell] in ["stall", "stall_back"] and zone["rect"].has_point(cell)).size()
			check(basin and stalls >= 4, "%s's square has a fountain and a market (%d stalls)" % [zone["name"], stalls])
	for lamp: Vector2i in World.LAMPS:
		check(World._against_wall(lamp), "the lamp at %s stands against a wall with room in front" % lamp)
	for zone: Dictionary in World.ZONES:
		if zone["town"]:
			var with_pieces: int = _town_areas(zone["rect"], street, false)
			var without: int = _town_areas(zone["rect"], street, true)
			check(with_pieces == without, "%s's street furniture splits no way (%d areas, %d without it)" % [
				zone["name"], with_pieces, without])
	for cell: Vector2i in World.FURNITURE:
		check((World.ROOM_AT.has(cell) or not World.dungeon_at(cell).is_empty() or World.FURNITURE[cell] in street)
			and not World.walkable(cell)
			and (SpriteArt.FURNITURE.has(World.FURNITURE[cell]) or World.FURNITURE[cell] in SpriteArt.FOUNTAIN_KINDS),
			"furniture stands inside a building (or a dungeon) and blocks")
	for id: String in World.TOWNSFOLK:
		var building: Dictionary = World.BUILDINGS[World.ROOM_AT[World.TOWNSFOLK[id]["cell"]]]
		var door: Vector2i = building["doors"][0]
		check(World._room_open(building, door - building["outward"][door], World.TOWNSFOLK[id]["cell"]),
			"%s's room stays open around the furniture" % World.TOWNSFOLK[id]["name"])
	# Rarity grades replace the slot edge colour; only wearables have one.
	check(Items.rarity(World.ITEMS["copper_blade"])[0] == "Common" and Items.rarity(World.ITEMS["gold_coins"]).is_empty(),
		"gear grades by tier; gold has no quality")
	for kind: String in World.ITEMS:
		if not World.ITEMS[kind].has("gold"):
			check(not Items.rarity(World.ITEMS[kind]).is_empty(), "%s has a quality colour" % kind)
	var graded := func(kinds: Array) -> Array: return kinds.map(func(kind: String) -> String: return Items.rarity(World.ITEMS[kind])[0])
	check(graded.call(["health_potion", "strong_health_potion", "great_health_potion"]) == ["Common", "Uncommon", "Rare"]
		and graded.call(["copper_ore", "iron_ore", "silver_ore", "cobalt_ore", "starmetal_ore"]) == ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
		and graded.call(["grilled_perch", "glimmerfin_feast"]) == ["Common", "Legendary"]
		and graded.call(["leather_satchel", "starweave_rucksack"]) == ["Common", "Legendary"]
		and graded.call(["vole_tail", "rune_shard", "forge_heart"]) == ["Common", "Rare", "Legendary"],
		"potions, resources, food, bags, and materials grade by their worth")
	var grades: Array = []
	var special: Array = []
	for level: int in Items.TIER_LEVELS:
		var grade: String = Items.rarity({"slot": "helmet", "level": level})[0]
		if grades.is_empty() or grades[-1] != grade:
			grades.append(grade)
		var earned: String = Items.rarity({"slot": "helmet", "level": level, "quest": "any"})[0]
		if special.is_empty() or special[-1] != earned:
			special.append(earned)
	check(grades == ["Common", "Uncommon", "Rare"], "tier gear climbs only to Rare (%s)" % [grades])
	check(special == ["Common", "Uncommon", "Rare", "Epic", "Legendary"], "quest gear climbs through every rarity (%s)" % [special])
	for kind: String in World.ITEMS:
		var item: Dictionary = World.ITEMS[kind]
		# Bags and packs grade by their slots, not by where they come from.
		if item["slot"] in ["", "bag", "container"] or item.has("glow") or Items.mythic(item):
			continue
		var name: String = Items.rarity(item)[0]
		if name in ["Epic", "Legendary"]:
			check(item.has("quest") or item.get("boss_drop", false), "%s is %s, so a boss or a quest gives it" % [kind, name])
	check(Items.boss_drops().has("mourning_estoc") and not Items.boss_drops().has("health_potion"),
		"boss drops are what only champions and bosses drop")
	for kind: String in World.ITEMS:
		if World.ITEMS[kind].has("glow"):
			check(Items.rarity(World.ITEMS[kind])[0] == "Relic", "relics are their own rarity")
	# The server refuses trade through a wall.
	var world := World.new()
	var economy := Economy.new(world)
	check(world.add_player(1, 0.0, "knight"), "a shopper")
	world.players[1]["gold"] = 1000
	var landing: Vector2i = World.npc("cinder_landing_vendor")["cell"]
	var behind: Vector2i = Vector2i(-1, -1)
	for dy: int in range(-2, 3):
		for dx: int in range(-2, 3):
			var cell: Vector2i = landing + Vector2i(dx, dy)
			if World.walkable(cell) and not World.ROOM_AT.has(cell):
				behind = cell
	check(behind.x >= 0, "there is open ground behind the Cinder Landing shop wall")
	_place(world, 1, behind)
	check(economy.buy(1, "cinder_landing_vendor", "health_potion", 1, 10.0)["reason"] == "Walk closer to a vendor",
		"no trading through a shop wall")
	_place(world, 1, landing + Vector2i.DOWN)
	check(economy.buy(1, "cinder_landing_vendor", "health_potion", 1, 11.0)["ok"], "trading inside the shop")


## Long-session safety: ground decay, the client spatial index, and per-tick occupancy.
func _hardening_checks() -> void:
	var world := World.new()
	var start: Vector2i = World.GROUND_ITEMS[0][0] if not World.GROUND_ITEMS.is_empty() else Vector2i(-1, -1)
	var junk := Vector2i(30, 30)
	var relic: String = ""
	for kind: String in World.ITEMS:
		if World.ITEMS[kind].has("glow") and relic.is_empty():
			relic = kind
	world.ground[junk] = ["vole_tail#2"]
	world.ground[junk + Vector2i.RIGHT] = [relic]
	check(world.decay_ground(0.0).is_empty(), "a first sweep only notes the ground")
	check(world.decay_ground(World.GROUND_DECAY_SECONDS - 1.0).is_empty() and world.ground.has(junk), "fresh stacks stay")
	world.ground[junk] = ["vole_tail#2", "rat_tail"]
	check(world.decay_ground(World.GROUND_DECAY_SECONDS + 20.0).is_empty() and world.ground.has(junk), "a changed stack restarts its timer")
	var events: Array = world.decay_ground(World.GROUND_DECAY_SECONDS * 2.0 + 40.0)
	check(not world.ground.has(junk) and events.size() == 1 and events[0]["cells"].size() == 1 and events[0]["cells"][0] == junk, "an untouched stack decays and is announced")
	check(world.ground.has(junk + Vector2i.RIGHT), "bound items (relics) never decay")
	check(start.x < 0 or world.ground.has(start), "starting map items never decay")
	check(world.decay_ground(World.GROUND_DECAY_SECONDS * 2.0 + 41.0).is_empty(), "sweeps are rate-limited")
	# The spatial index answers by chunk, moves keys, and forgets removed ones.
	var index: RefCounted = load("res://game/render/cell_index.gd").new()
	index.put(-5, Vector2i(3, 3))
	index.put(-6, Vector2i(40, 40))
	check(index.query(Rect2i(0, 0, 10, 10)) == [-5] and index.query(Rect2i(-20, -20, 5, 5)).is_empty(), "index finds keys by area")
	index.put(-5, Vector2i(41, 41))
	check(index.query(Rect2i(0, 0, 10, 10)).is_empty() and index.query(Rect2i(32, 32, 16, 16)).size() == 2, "index moves keys")
	index.remove(-6)
	index.remove(-6)
	check(index.size() == 1 and index.query(Rect2i(32, 32, 16, 16)) == [-5], "index removes keys")
	# Monsters stepping in one tick never share a tile (occupancy is kept current within the tick).
	var crowd := World.new()
	var combat := Combat.new(crowd, 11)
	check(crowd.add_player(1, 0.0, "knight"), "crowd target")
	var open: Vector2i = Vector2i(-1, -1)
	for spawn: Dictionary in World.MONSTER_SPAWNS:
		var ring: int = 0
		for dy: int in range(-3, 4):
			for dx: int in range(-3, 4):
				ring += 1 if World.walkable(spawn["cell"] + Vector2i(dx, dy)) else 0
		if ring == 49 and open.x < 0:
			open = spawn["cell"]
	check(open.x >= 0, "an open field for the crowd")
	_place(crowd, 1, open)
	crowd.players[1]["health"] = 999999
	var spawned: Array = []
	for offset: Vector2i in [Vector2i(-3, -3), Vector2i(3, -3), Vector2i(-3, 3), Vector2i(3, 3), Vector2i(0, -3), Vector2i(0, 3)]:
		spawned.append(combat.spawn_monster("field_vole", 1, open + offset, 0.0, -1, []))
	var overlap: bool = false
	for step: int in 40:
		var now: float = 1.0 + step * Combat.TICK_SECONDS
		combat.tick(now)
		var seen: Dictionary = {crowd.players[1]["cell"]: true}
		for id: int in spawned:
			if crowd.monsters.has(id):
				overlap = overlap or seen.has(crowd.monsters[id]["cell"])
				seen[crowd.monsters[id]["cell"]] = true
	check(not overlap, "monsters closing in never share a tile")


## Monsters catch fleeing players; dragging one too far or into a town resets it at full health.
func _chase_checks() -> void:
	check(Balance.chase_seconds(5, 5) < World.MOVE_SECONDS and Balance.chase_seconds(5, 5) > World.MOVE_SECONDS - 0.03
		and Balance.chase_seconds(40, 1) < Balance.chase_seconds(5, 5) and Balance.chase_seconds(1, 40) == Balance.chase_seconds(5, 5),
		"a monster chases a touch faster than you walk, much faster only when it outlevels you")
	check(Monsters.AGGRO_RANGE <= 3 and Monsters.CHASE_RANGE > Monsters.AGGRO_RANGE, "monsters notice you up close but chase far")
	# An open straight corridor outside any town, at least 14 tiles east of a monster camp.
	var start: Vector2i = Vector2i(-1, -1)
	for spawn: Dictionary in World.MONSTER_SPAWNS:
		var clear: bool = World.dungeon_at(spawn["cell"]).is_empty()
		for dx: int in range(-2, 16):
			for dy: int in range(-1, 2):
				var cell: Vector2i = spawn["cell"] + Vector2i(dx, dy)
				clear = clear and World.walkable(cell) and World.zone_at(cell).is_empty()
		if clear and start.x < 0:
			start = spawn["cell"]
	check(start.x >= 0, "an open corridor for the chase checks")
	for level: int in [1, 40]:
		var world := World.new()
		var combat := Combat.new(world, 3)
		world.monsters.clear()
		world.add_player(1, 0.0, "sorcerer")
		var player: Dictionary = world.players[1]
		player["health"] = 999999
		_place(world, 1, start + Vector2i(2, 0))
		var monster: int = combat.spawn_monster("field_vole", level, start, 0.0)
		# The player flees east at full walking speed; the monster chases.
		var now: float = 0.0
		var caught: bool = false
		# About 8 tiles of fleeing: well inside the leash.
		while now < 1.5 and not caught:
			now += 0.05
			if now >= player["next_move"]:
				world.move(1, Vector2i.RIGHT, now)
			combat.tick(now)
			caught = caught or Combat.distance(world.monsters[monster]["cell"], player["cell"]) <= 1
		if level == 40:
			check(caught and world.monsters[monster]["target"] == 1, "a monster far above you catches you fleeing")
		else:
			check(Combat.distance(world.monsters[monster]["cell"], player["cell"]) <= 2 and world.monsters[monster]["target"] == 1,
				"an even-level monster keeps up with you (%d tiles behind)" % Combat.distance(world.monsters[monster]["cell"], player["cell"]))
	# Dragging a monster past its leash: it gives up at full health and walks home untouchable.
	var drag := World.new()
	var drag_combat := Combat.new(drag, 4)
	drag.monsters.clear()
	drag.add_player(1, 0.0, "knight")
	drag.players[1]["health"] = 999999
	_place(drag, 1, start + Vector2i(1, 0))
	var vole: int = drag_combat.spawn_monster("field_vole", 5, start, 0.0)
	var events: Array = []
	drag_combat._damage(1, vole, 20, "damage", 0.0, events)
	check(drag.monsters[vole]["health"] < drag.monsters[vole]["max_health"] and drag.monsters[vole]["target"] == 1, "a hit monster engages")
	_place(drag, 1, start + Vector2i(Monsters.LEASH + 1, 0))
	drag.monsters[vole]["cell"] = start + Vector2i(Monsters.LEASH, 0)
	drag_combat.tick(1.0)
	var returning: Dictionary = drag.monsters[vole]
	check(returning["target"] == 0 and returning["returning"] and returning["health"] == returning["max_health"]
		and returning["damage_by"].is_empty(), "past its leash a monster resets to full health and turns home")
	events = []
	drag_combat._damage(1, vole, 20, "damage", 1.1, events)
	check(returning["health"] == returning["max_health"] and returning["target"] == 0, "a monster going home cannot be hurt or re-pulled")
	_place(drag, 1, start + Vector2i(1, 0))
	var now_home: float = 1.2
	while now_home < 12.0 and returning["cell"] != returning["home"]:
		now_home += 0.15
		drag_combat.tick(now_home)
	drag_combat.tick(now_home + 0.15)
	drag_combat.tick(now_home + 0.3)
	check(returning["cell"] == returning["home"] and not returning["returning"] and returning["target"] == 1,
		"home again, it fights anyone nearby")
	# Into a town: a monster never follows, and resets.
	var town: Dictionary = {}
	for zone: Dictionary in World.ZONES:
		if zone["town"] and town.is_empty():
			town = zone
	var gate: Vector2i = Vector2i(-1, -1)
	for y: int in range(town["rect"].position.y, town["rect"].end.y):
		for x: int in range(town["rect"].position.x, town["rect"].end.x):
			var inside := Vector2i(x, y)
			if gate.x < 0 and World.walkable(inside) and World.walkable(inside + Vector2i.RIGHT) \
					and not World.zone_at(inside + Vector2i.RIGHT).get("town", false) and World.zone_at(inside + Vector2i.RIGHT).get("name", "").is_empty():
				gate = inside
	check(gate.x >= 0, "a town edge for the town check")
	var townsfolk := World.new()
	var town_combat := Combat.new(townsfolk, 5)
	townsfolk.monsters.clear()
	townsfolk.add_player(1, 0.0, "knight")
	_place(townsfolk, 1, gate + Vector2i.RIGHT)
	var hunter: int = town_combat.spawn_monster("field_vole", 5, gate + Vector2i(3, 0), 0.0)
	events = []
	town_combat._damage(1, hunter, 10, "damage", 0.0, events)
	_place(townsfolk, 1, gate)
	town_combat.tick(1.0)
	town_combat.tick(1.2)
	check(townsfolk.monsters[hunter]["target"] == 0 and townsfolk.monsters[hunter]["health"] == townsfolk.monsters[hunter]["max_health"]
		and townsfolk.monsters[hunter]["damage_by"].is_empty(), "a monster never follows into a town and resets")
	# The client is told how long each step really takes, so chases animate at chase speed.
	check(is_equal_approx(town_combat.export_monster(hunter, 1.0)["duration"], townsfolk.monsters[hunter]["last_step"]),
		"monster steps replicate their real duration")


## The monster catalog's contract (see .github/skills/monster-authoring): every monster, new ones
## included, is fully described, uses a drawable look, derives its numbers from Balance, has a
## loot table of real items, and appears somewhere in the world at a level its loot allows.
func _monster_catalog_checks() -> void:
	var placed: Dictionary = {}
	for spawn: Dictionary in World.MONSTER_SPAWNS:
		placed[spawn["monster"]] = mini(placed.get(spawn["monster"], 99), spawn["level"])
	for dungeon: String in Dungeons.DUNGEONS:
		for symbol: String in Dungeons.DUNGEONS[dungeon]["monsters"]:
			var entry: Array = Dungeons.DUNGEONS[dungeon]["monsters"][symbol]
			placed[entry[0]] = mini(placed.get(entry[0], 99), entry[1])
	for kind: String in Monsters.MONSTERS:
		var definition: Dictionary = Monsters.MONSTERS[kind]
		var named: String = "monster %s" % kind
		check(kind == kind.to_snake_case() and not String(definition.get("name", "")).is_empty(), "%s has a snake_case id and a name" % named)
		check(Balance.RANKS.has(definition.get("rank", "")), "%s has a Balance rank" % named)
		check(SpriteArt.MONSTER_SHEETS.has(definition.get("look", "")) or definition.get("look", "") == "humanoid", "%s has a drawable look" % named)
		check(definition.get("color") is Color and float(definition.get("size", 0.0)) >= 0.4 and float(definition.get("size", 0.0)) <= 2.0,
			"%s has a tint and a size between 0.4 and 2" % named)
		check(int(definition.get("range", 0)) >= 1 and int(definition.get("range", 0)) <= 6, "%s attacks from 1 to 6 tiles" % named)
		check(float(definition.get("step", 0.0)) >= 0.3 and float(definition.get("step", 0.0)) <= 0.8,
			"%s idles at 0.3 to 0.8 s per tile (chasing uses Balance.chase_seconds)" % named)
		for key: String in definition:
			check(key in ["name", "look", "color", "size", "rank", "range", "step", "gear", "glow", "relics", "respawn", "gear_chance"],
				"%s uses only known fields (%s)" % [named, key])
		for numbers: String in ["health", "damage", "experience", "attack", "defense", "level"]:
			check(not definition.has(numbers), "%s takes %s from Balance, not the catalog" % [named, numbers])
		check(Monsters.LOOT.has(kind), "%s has a loot table (may be empty)" % named)
		for entry: Array in Monsters.LOOT.get(kind, []):
			check(World.ITEMS.has(entry[0]) and float(entry[1]) > 0.0 and float(entry[1]) <= 1.0 and not World.ITEMS[entry[0]].has("glow"),
				"%s drops a catalog item at a chance in (0, 1], never a relic" % named)
		check(placed.has(kind), "%s is placed on the map or in a dungeon" % named)
		if definition["rank"] == "boss":
			check(definition.get("relics", []).size() >= 4 and definition.has("respawn"), "%s (boss) offers relics and a slow respawn" % named)
		else:
			check(not definition.has("relics"), "%s: only bosses have relics" % named)
	for kind: String in Monsters.LOOT:
		check(Monsters.MONSTERS.has(kind), "loot table %s belongs to a monster" % kind)


## Spell progression per vocation, and PvP damage, healing reduction, and dampening.
func _pvp_and_spell_checks() -> void:
	for vocation: String in Balance.VOCATIONS:
		var spells: Array[String] = Spells.for_vocation(vocation)
		var late: int = 0
		var best: float = 0.0
		var levels: Array[int] = []
		for spell: String in spells:
			levels.append(Spells.SPELLS[spell]["level"])
			if Spells.SPELLS[spell]["level"] >= 15:
				late += 1
		for index: int in range(1, levels.size()):
			check(levels[index] >= levels[index - 1], "%s spells are listed by unlock level" % vocation)
		for spell: String in spells:
			var definition: Dictionary = Spells.SPELLS[spell]
			if definition["kind"] in ["target", "area_self", "area_target"] and definition["level"] < 15:
				best = maxf(best, definition["power"])
		var stronger: bool = false
		for spell: String in spells:
			var definition: Dictionary = Spells.SPELLS[spell]
			stronger = stronger or (definition["level"] >= 15 and definition["kind"] in ["target", "area_self", "area_target"]
				and definition["power"] > best)
		check(late >= 3 and stronger and spells.size() <= Keybinds.SLOTS,
			"%s unlocks three or more spells from level 15, a stronger strike among them, and all fit the bar" % vocation)
	# PvP: harder hits between players, weaker healing while in PvP combat, fading over a long fight.
	var world := World.new()
	var combat := Combat.new(world, 6)
	world.monsters.clear()
	world.add_player(1, 0.0, "paladin")
	world.add_player(2, 0.0, "paladin")
	var arena: Vector2i = Vector2i(-1, -1)
	for zone: Dictionary in World.ZONES:
		if zone["pvp"] and arena.x < 0:
			for y: int in range(zone["rect"].position.y, zone["rect"].end.y):
				for x: int in range(zone["rect"].position.x, zone["rect"].end.x):
					if arena.x < 0 and World.walkable(Vector2i(x, y)) and World.walkable(Vector2i(x + 1, y)) \
							and World.zone_at(Vector2i(x + 1, y)).get("pvp", false):
						arena = Vector2i(x, y)
	_place(world, 1, arena)
	_place(world, 2, arena + Vector2i.RIGHT)
	check(combat.healing_factor(1, 0.0) == 1.0, "full healing outside PvP combat")
	var vole: int = combat.spawn_monster("field_vole", 1, arena + Vector2i(0, 1), 0.0)
	world.players[2]["health"] = 999999
	var dealt: int = 0
	for round_index: int in 400:
		var events: Array = []
		combat._hit(1, 2, 1.0, 1.0, events)
		for event: Dictionary in events:
			if event["kind"] == "hit" and event["target"] == 2:
				dealt += event["amount"]
	var critical: float = world.player_stats(1)["critical"] / 100.0
	var expected: float = Balance.damage_taken(roundi(combat.attack_of(1) * Balance.PVP_DAMAGE), combat.defense_of(2)) \
		* (1.0 + critical * (Combat.CRITICAL_MULTIPLIER - 1.0))
	check(Balance.PVP_DAMAGE > 1.0 and absf(dealt / 400.0 - expected) < expected * 0.12,
		"players hit players PVP_DAMAGE times harder (%.1f per hit, expected %.1f)" % [dealt / 400.0, expected])
	for id: int in [1, 2]:
		world.players[id]["pvp_until"] = -INF
		world.players[id]["pvp_since"] = -INF
	world.players[2]["health"] = 10
	var events_pvp: Array = []
	combat._damage(1, 2, 1, "damage", 5.0, events_pvp)
	check(world.players[1]["pvp_until"] == 5.0 + Balance.PVP_COMBAT_SECONDS and world.players[2]["pvp_since"] == 5.0,
		"a hit between players starts PvP combat for both")
	check(is_equal_approx(combat.healing_factor(2, 5.0), Balance.PVP_HEALING), "healing is reduced in PvP combat")
	# Keep the fight going (a hit every 5 s) so PvP combat stays continuous.
	var fight_time: float = 5.0
	while fight_time < 5.0 + Balance.PVP_DAMPENING_SECONDS / 2.0:
		fight_time += 5.0
		world.players[2]["health"] = 999
		combat._damage(1, 2, 1, "damage", fight_time, events_pvp)
	check(is_equal_approx(combat.healing_factor(2, 5.0 + Balance.PVP_DAMPENING_SECONDS / 2.0), Balance.PVP_HEALING * 0.5),
		"healing fades the longer PvP combat lasts")
	while fight_time < 5.0 + Balance.PVP_DAMPENING_SECONDS:
		fight_time += 5.0
		world.players[2]["health"] = 999
		combat._damage(1, 2, 1, "damage", fight_time, events_pvp)
	check(combat.healing_factor(2, 5.0 + Balance.PVP_DAMPENING_SECONDS) == 0.0, "after the dampening time, healing stops")
	var later: float = 5.0 + Balance.PVP_DAMPENING_SECONDS + Balance.PVP_COMBAT_SECONDS + 0.1
	check(combat.healing_factor(2, later) == 1.0, "leaving PvP combat restores healing")
	world.players[2]["health"] = 10
	var before: int = world.players[2]["health"]
	combat._heal(2, 100, [], 0, later)
	check(world.players[2]["health"] == before + 100, "outside PvP combat a heal restores its full amount")
	combat._damage(1, 2, 1, "damage", later, events_pvp)
	before = world.players[2]["health"]
	combat._heal(2, 100, [], 0, later)
	check(world.players[2]["health"] == before + roundi(100 * Balance.PVP_HEALING), "inside PvP combat heals are reduced")
	combat._damage(1, vole, 1, "damage", later + 20.0, events_pvp)
	check(combat.healing_factor(1, later + 20.0) == 1.0, "fighting monsters is never PvP combat")


## Dungeon hunting and boss tasks, their givers by the stairways, and named regions.
func _dungeon_task_and_region_checks() -> void:
	for dungeon: String in Dungeons.DUNGEONS:
		var definition: Dictionary = Dungeons.DUNGEONS[dungeon]
		var boss: String = definition["monsters"][definition["boss"]][0]
		var hunted: Array = []
		var boss_task: String = ""
		for task: String in Quests.TASKS:
			if Quests.monster_level(Quests.TASKS[task]["monster"]) == 0:
				continue
			if Quests.dungeon_of(task) != dungeon:
				continue
			if Quests.TASKS[task]["monster"] == boss:
				boss_task = task
			else:
				hunted.append(task)
		check(not boss_task.is_empty() and Quests.TASKS[boss_task]["count"] == 1 and hunted.size() >= 1,
			"%s has a hunting task and a boss task" % dungeon)
		var stairway_giver: Dictionary = World.QUEST_GIVERS.get(Quests.TASKS[boss_task]["giver"] if not boss_task.is_empty() else "", {})
		check(not stairway_giver.is_empty() and World.chebyshev(stairway_giver["cell"], World.ENTRANCE_OF[dungeon]) <= 6
			and stairway_giver["place"] == definition["town"], "%s's tasks are given by its stairway in %s" % [dungeon, definition["town"]])
		for task: String in hunted + [boss_task]:
			var reward: Dictionary = Quests.reward(task)
			check(reward.get("experience", 0) > 0 and reward.get("gold", 0) > 0 and reward["gold"] % 5 == 0,
				"%s pays experience and gold" % task)
		for symbol: String in definition["monsters"]:
			var kind: String = definition["monsters"][symbol][0]
			check(kind == boss or hunted.any(func(task: String) -> bool: return Quests.counts(task, kind)),
				"every %s monster counts toward a task" % dungeon)
	check(Quests.reward("rat_king")["experience"] == Balance.mob_experience(9, "champion"), "a boss task doubles the boss's experience")
	# Playing the cellar tasks.
	var world := World.new()
	var combat := Combat.new(world, 12)
	world.monsters.clear()
	world.add_player(1, 0.0, "knight")
	var player: Dictionary = world.players[1]
	var giver: String = "cellarmaster_pell"
	_place(world, 1, _beside(giver))
	check(combat.task_action(1, giver, "cellar_vermin", "accept", 1.0)["ok"] and combat.task_action(1, giver, "rat_king", "accept", 1.0)["ok"],
		"one giver offers both cellar tasks")
	var copy: Vector2i = Dungeons.origin("cinder_cellar", 0) + Dungeons.cells("cinder_cellar", "@")[0]
	_place(world, 1, copy)
	var kills: int = 0
	for kind: String in ["sewer_rat", "giant_rat", "giant_rat", "sewer_rat"]:
		var rat: int = combat.spawn_monster(kind, 3, copy + Vector2i(1, 0), 2.0)
		combat._damage(1, rat, 9999999, "damage", 2.0 + kills, [])
		kills += 1
	check(player["tasks"]["cellar_vermin"] == 4, "sewer and giant rats both count")
	player["tasks"]["cellar_vermin"] = Quests.TASKS["cellar_vermin"]["count"]
	var king: int = combat.spawn_monster("rat_king", 9, copy + Vector2i(1, 0), 10.0)
	combat._damage(1, king, 99999999, "damage", 10.0, [])
	check(player["tasks"]["rat_king"] == 1, "slaying the Rat King counts for the boss task")
	_place(world, 1, _beside(giver))
	var gold: int = player["gold"]
	var before: int = Combat.total_experience(player["level"], player["experience"])
	check(combat.task_action(1, giver, "cellar_vermin", "complete", 11.0)["ok"] and player["gold"] == gold + Quests.reward("cellar_vermin")["gold"]
		and Combat.total_experience(player["level"], player["experience"]) == before + Quests.reward("cellar_vermin")["experience"],
		"turning in a dungeon hunt pays its experience and gold")
	check(combat.task_action(1, giver, "rat_king", "complete", 12.0)["ok"] and player["done_tasks"].has("rat_king")
		and not player["equipment"].has("bag"), "the boss task pays out without a pack")
	check(not combat.task_action(1, giver, "rat_king", "accept", 13.0)["ok"], "a boss task is done once")
	check(not combat.task_action(1, "sexton_wren", "cellar_vermin", "accept", 13.0)["ok"], "only the right giver offers a task")
	# Regions: every overworld land tile is named, with levels from the monsters placed there.
	for name: String in World.REGION_NAMES:
		check(World.REGION_INFO.has(name) and not Regions.description(name).is_empty(), "%s is described" % name)
		var info: Dictionary = World.REGION_INFO[name]
		check(info["max_level"] >= info["min_level"] and info["max_level"] <= Balance.MAX_LEVEL, "%s has a level range from its monsters" % name)
	check(World.REGION_INFO["Cinder Meadows"]["min_level"] == 1 and World.region_at(World.SPAWNS[0] + Vector2i(30, 25)) == "Cinder Meadows",
		"the starting fields are Cinder Meadows, from level 1")
	check(World.region_at(Biomes.DESERT_CENTRE) == Regions.DESERT, "the desert is the Sunscar Dunes")
	var unnamed: int = 0
	for y: int in range(0, World.OVERWORLD.size.y, 7):
		for x: int in range(0, World.OVERWORLD.size.x, 7):
			if World.terrain(Vector2i(x, y)) in World.LAND and World.location_at(Vector2i(x, y)).is_empty():
				unnamed += 1
	check(unnamed == 0, "every overworld tile has a location")
	check(World.location_at(World.SPAWNS[0])["kind"] == "town" and World.location_at(World.SPAWNS[0])["min_level"] == 0,
		"towns show as safe")
	check(World.location_at(Vector2i(200, 190))["kind"] == "pvp", "Blackreed Isle shows as PvP")
	check(World.location_at(Dungeons.origin("cinder_cellar", 0) + Vector2i(2, 2))["kind"] == "dungeon"
		and World.region_at(Dungeons.origin("cinder_cellar", 0)).is_empty(), "dungeon copies are not regions")
	for spawn: Dictionary in World.MONSTER_SPAWNS:
		var place: Dictionary = World.location_at(spawn["cell"])
		if place.get("kind", "") == "region" and Monsters.MONSTERS[spawn["monster"]]["rank"] != "boss":
			check(spawn["level"] >= place["min_level"] and spawn["level"] <= place["max_level"], "region levels cover their monsters")


## Blocked spawns retry until their camp is full; town rest boosts regeneration with a cooldown;
## Blackreed Isle stays open enough to fight on.
func _spawn_and_rest_checks() -> void:
	var Island: GDScript = load("res://tools/generators/island.gd")
	var isle_scene: Node = (load(World.MAP_SCENE) as PackedScene).instantiate()
	check(Island.TERRAINS == World.TERRAINS and Island.apply(isle_scene) == 0, "Blackreed Isle is already thinned (a re-run changes nothing)")
	# Cinder Crossing's castle walls (castle_town.gd) and Silkhollow's trail (silkhollow.gd) are painted.
	var Castle: GDScript = load("res://tools/generators/castle_town.gd")
	var Trail: GDScript = load("res://tools/generators/silkhollow.gd")
	check(Castle.TERRAINS == World.TERRAINS and Castle.apply(isle_scene) == 0, "Cinder Crossing's castle is built (a re-run changes nothing)")
	check(Trail.TERRAINS == World.TERRAINS and Trail.apply(isle_scene) == 0, "the trail to Silkhollow is cut (a re-run changes nothing)")
	var Boulders: GDScript = load("res://tools/generators/clear_boulders.gd")
	check(Boulders.clear(isle_scene) == 0, "no boulders snag the overworld (a re-run of clear_boulders changes nothing)")
	var Capital: GDScript = load("res://tools/generators/reedmere.gd")
	check(Capital.TERRAINS == World.TERRAINS and Capital.rebuild(isle_scene) == 0, "Reedmere is rebuilt as an open town (a re-run changes nothing)")
	# The open quarter: every house has a roof, and the west, north, and south gates lead in.
	var quarter: int = 0
	for building: Dictionary in World.BUILDINGS:
		if building["rect"].position.x < 133 and World.zone_at(building["rect"].position).get("name", "") == "Reedmere":
			quarter += 1
	check(quarter == 4, "Reedmere's west quarter has four roofed houses (%d)" % quarter)
	for gate: Vector2i in [Vector2i(108, 194), Vector2i(150, 180), Vector2i(150, 207)]:
		check(World.walkable(gate), "Reedmere's gate at %s is open" % gate)
	isle_scene.free()
	var towers: int = 0
	var castle: Dictionary = Castle.plan()
	for cell: Vector2i in castle:
		towers += 1 if SpriteArt.tower(cell) else 0
		check(World.terrain(cell) == castle[cell], "castle cell %s is painted as planned" % cell)
	check(towers >= Castle.TOWERS.size() * 4, "every castle tower stands at least 2x2 (%d tower cells)" % towers)
	for gate: Vector2i in Castle.GATES:
		check(World.walkable(gate), "the castle gate at %s is open" % gate)
	var isle: Rect2i = World.ZONES.filter(func(zone: Dictionary) -> bool: return zone["name"] == "Blackreed Isle")[0]["rect"]
	var trees: int = 0
	var land: int = 0
	for y: int in range(isle.position.y, isle.end.y):
		for x: int in range(isle.position.x, isle.end.x):
			var tile: String = World.terrain(Vector2i(x, y))
			trees += 1 if tile == "T" else 0
			land += 1 if tile == "T" or tile in World.LAND else 0
	check(trees * 100 < land * 10, "Blackreed Isle is mostly open ground (%d trees on %d tiles)" % [trees, land])
	# Fill a camp's whole area with players so nothing can spawn there, then free it.
	var world := World.new()
	var combat := Combat.new(world, 21)
	var index: int = 0
	for candidate: int in World.MONSTER_SPAWNS.size():
		var spawn: Dictionary = World.MONSTER_SPAWNS[candidate]
		if spawn["radius"] <= 1 and spawn["count"] >= 1 and World.dungeon_at(spawn["cell"]).is_empty():
			index = candidate
			break
	var camp: Dictionary = World.MONSTER_SPAWNS[index]
	var blockers: Array[Vector2i] = []
	for dy: int in range(-camp["radius"], camp["radius"] + 1):
		for dx: int in range(-camp["radius"], camp["radius"] + 1):
			if World.walkable(camp["cell"] + Vector2i(dx, dy)):
				blockers.append(camp["cell"] + Vector2i(dx, dy))
	var held: Dictionary = {}
	for cell: Vector2i in blockers:
		world.monsters[-90000 - held.size()] = {"cell": cell, "from": cell, "next_move": 0.0}
		held[cell] = -90000 - (held.size())
	combat.populate(0.0, true)
	var in_camp: Callable = func() -> int:
		return world.monsters.values().filter(func(monster: Dictionary) -> bool:
			return monster.get("spawn", -1) == index).size()
	check(in_camp.call() == 0 and combat.respawns.filter(func(entry: Array) -> bool: return entry[1] == index).size() == camp["count"],
		"a blocked camp queues every monster it could not place")
	for id: int in world.monsters.keys():
		if id <= -90000:
			world.monsters.erase(id)
	var time: float = 0.0
	while time < Combat.SPAWN_RETRY_SECONDS * 3.0:
		time += Combat.TICK_SECONDS * 1.5
		combat.tick(time)
	check(in_camp.call() == camp["count"], "once there is room, the camp fills to its count")
	# Town rest.
	var town := World.new()
	var rest := Combat.new(town, 22)
	town.monsters.clear()
	town.add_player(1, 0.0, "knight")
	var player: Dictionary = town.players[1]
	var limits: Dictionary = town.player_stats(1)
	var outside: Vector2i = Vector2i(-1, -1)
	for dy: int in range(0, 40):
		if outside.x < 0 and World.walkable(World.SPAWNS[0] + Vector2i(0, dy)) and World.zone_at(World.SPAWNS[0] + Vector2i(0, dy)).is_empty():
			outside = World.SPAWNS[0] + Vector2i(0, dy)
	_place(town, 1, outside)
	player["health"] = 1
	var clock_now: float = 100.0
	rest.tick(clock_now)
	var outside_gain: int = player["health"] - 1
	check(not player["town_rest"], "no town rest outside a town")
	_place(town, 1, World.SPAWNS[0])
	player["health"] = 1
	player["next_regen"] = 0.0
	var events: Array = []
	clock_now += 1.0
	rest._player_tick(1, clock_now, events)
	var town_gain: int = player["health"] - 1
	check(player["town_rest"] and town_gain >= outside_gain * 3 and events.any(func(event: Dictionary) -> bool:
		return event["kind"] == "message" and event["text"].contains("rest")), "a town rest starts, announced, and heals much faster")
	var seconds: float = 0.0
	while player["health"] < limits["health"] and seconds < 60.0:
		seconds += Combat.REGEN_SECONDS
		player["next_regen"] = 0.0
		rest._player_tick(1, clock_now + seconds, [])
	check(seconds <= 32.0, "a town rest takes you from empty to full in about half a minute (%.0f s)" % seconds)
	player["mana"] = limits["mana"]
	player["next_regen"] = 0.0
	rest._player_tick(1, clock_now + seconds + 0.1, [])
	check(not player["town_rest"] and is_equal_approx(player["town_rest_ready"], clock_now + seconds + 0.1 + Combat.TOWN_REST_COOLDOWN),
		"a full player's rest ends and starts its cooldown")
	player["health"] = 1
	player["next_regen"] = 0.0
	rest._player_tick(1, clock_now + seconds + 10.0, [])
	check(not player["town_rest"] and player["health"] < 1 + town_gain, "town rest waits for its cooldown")
	check(town.export_player(1, clock_now + seconds + 10.0, true)["town_rest_left"] > 0.0
		and not town.export_player(1, clock_now + seconds + 10.0).has("town_rest_left"), "the owner sees when rest is ready")
	player["next_regen"] = 0.0
	rest._player_tick(1, clock_now + seconds + 0.2 + Combat.TOWN_REST_COOLDOWN, [])
	check(player["town_rest"], "after the cooldown a town rest starts again")
	_place(town, 1, outside)
	player["next_regen"] = 0.0
	rest._player_tick(1, clock_now + seconds + 1.0 + Combat.TOWN_REST_COOLDOWN, [])
	check(not player["town_rest"] and player["town_rest_ready"] > clock_now + seconds + Combat.TOWN_REST_COOLDOWN,
		"leaving town ends the rest and starts its cooldown")


## Armor types and the two kinds of damage (Balance.ARMOR_TYPES), the new gear stats, and the
## control spells: Entangling roots and Crippling arrow.
func _armor_and_control_checks() -> void:
	# Plate stops blades and arrows, cloth stops spells; capes, amulets, and books add magic defense.
	var helmets: Dictionary = {}
	for kind: String in World.ITEMS:
		var item: Dictionary = World.ITEMS[kind]
		if item["slot"] == "helmet" and item["level"] == 45 and item.has("armor") and not item.has("quest"):
			helmets[item["armor"]] = item["stats"]
	check(helmets.size() == 4 and helmets["plate"]["defense"] > helmets["mail"]["defense"]
		and helmets["mail"]["defense"] > helmets["leather"]["defense"] and helmets["leather"]["defense"] > helmets["cloth"]["defense"]
		and helmets["cloth"]["magic_defense"] > helmets["leather"]["magic_defense"]
		and helmets["leather"]["magic_defense"] > helmets["mail"]["magic_defense"] and not helmets["plate"].has("magic_defense"),
		"plate has the most defense and no magic defense; cloth the most magic defense (%s)" % [helmets])
	var cape: Dictionary = Items.tier_stats({"level": 30, "slot": "cape", "look": "cape", "vocations": []})
	var amulet: Dictionary = Items.tier_stats({"level": 30, "slot": "necklace", "look": "amulet", "vocations": []})
	check(cape.get("magic_defense", 0) > 0 and amulet.get("magic_defense", 0) > 0 and not cape.has("defense"),
		"capes and amulets give magic defense")
	var bow: Dictionary = Items.tier_stats({"level": 30, "slot": "main_hand", "look": "bow", "vocations": ["paladin"]})
	var wand: Dictionary = Items.tier_stats({"level": 30, "slot": "main_hand", "look": "wand", "vocations": ["sorcerer"]})
	var rod: Dictionary = Items.tier_stats({"level": 30, "slot": "main_hand", "look": "rod", "vocations": ["druid"]})
	var blade: Dictionary = Items.tier_stats({"level": 30, "slot": "main_hand", "look": "sword", "vocations": ["knight"]})
	var ring: Dictionary = Items.tier_stats({"level": 30, "slot": "ring", "look": "ring", "vocations": []})
	check(bow["critical"] > Items.CRITICAL_WEAPON and wand["critical"] == bow["critical"] and rod["healing"] > 0
		and not blade.has("critical") and ring["critical"] == Items.CRITICAL_RING,
		"Hunters' and Sorcerers' weapons and rings add critical chance, Druids' rods healing")
	# Physical hits meet defense, magic hits magic defense.
	var world := World.new()
	var combat := Combat.new(world, 21)
	world.monsters.clear()
	var arena: Vector2i = _open_cell(true)
	for spec: Array in [[1, "knight"], [2, "paladin"], [3, "sorcerer"]]:
		world.add_player(spec[0], 0.0, spec[1])
		world.players[spec[0]]["level"] = 45
		world.players[spec[0]]["equipment"] = Bots.gear(45, spec[1])
		_place(world, spec[0], arena + Vector2i(spec[0] - 1, 0))
	check(not combat.magic_attacker(1) and not combat.magic_attacker(2) and combat.magic_attacker(3),
		"Warriors and Hunters hit physically, Sorcerers and Druids with magic")
	check(combat.defense_of(1) > 2 * combat.defense_of(3) and combat.defense_of(1, true) < combat.defense_of(3, true),
		"a Warrior in plate has far more defense, and less magic defense, than a Sorcerer in cloth")
	var wraith: int = combat.spawn_monster("cinder_wraith", 30, arena + Vector2i(0, 2), 0.0)
	var wolf: int = combat.spawn_monster("grey_wolf", 30, arena + Vector2i(1, 2), 0.0)
	check(combat.magic_attacker(wraith) and not combat.magic_attacker(wolf), "wraiths cast; wolves bite")
	# Entangling roots holds a player in place, then they cannot be held again for a while.
	world.add_player(4, 0.0, "druid")
	world.players[4]["level"] = 45
	_place(world, 4, arena + Vector2i(0, 1))
	world.players[4]["mana"] = 999999
	world.players[4]["target"] = 2
	var rooted: Dictionary = combat.cast(4, "entangling_roots", 10.0)
	check(rooted["ok"] and world.players[2]["rooted_until"] == 13.0, "Entangling roots strikes and roots a player for 3 s")
	world.players[2]["next_move"] = 0.0
	check(world.move(2, Vector2i.DOWN, 11.0)["reason"] == "You are rooted in place" and world.move(2, Vector2i.DOWN, 13.1)["ok"],
		"a rooted player cannot step until the roots let go")
	world.players[4]["cooldowns"] = {}
	world.players[4]["groups"] = {}
	combat.cast(4, "entangling_roots", 14.0)
	check(world.players[2]["rooted_until"] == 13.0, "a player is immune to being held again for RESTRAIN_IMMUNITY after it ends")
	# Crippling arrow halves a pace; bosses shrug both off.
	world.players[2]["cooldowns"] = {}
	world.players[2]["groups"] = {}
	world.players[2]["mana"] = 999999
	world.players[2]["target"] = wolf
	_place(world, 2, arena + Vector2i(1, 0))
	check(combat.cast(2, "crippling_arrow", 30.0)["ok"] and world.monsters[wolf]["slowed_until"] == 34.0,
		"Crippling arrow slows a monster for 4 s")
	world.players[1]["next_move"] = 0.0
	combat.restrain(1, "slow", 4.0, 40.0, [])
	world.move(1, Vector2i.UP, 40.0)
	check(is_equal_approx(world.players[1]["next_move"], 40.0 + World.MOVE_SECONDS * World.SLOWED_STEP)
		and world.export_player(1, 40.0)["duration"] == World.MOVE_SECONDS * World.SLOWED_STEP, "a slowed player steps at half pace")
	var boss: int = combat.spawn_monster("morvain", 50, arena + Vector2i(3, 3), 0.0)
	combat.restrain(boss, "root", 3.0, 50.0, [])
	check(not world.monsters[boss].has("rooted_until"), "bosses cannot be rooted or slowed")
	var champion: int = combat.spawn_monster("grimclaw", 37, arena + Vector2i(-3, 3), 0.0)
	combat.restrain(champion, "slow", 3.0, 50.0, [])
	check(Monsters.MONSTERS["grimclaw"]["rank"] == "champion" and not world.monsters[champion].has("slowed_until"),
		"champions cannot be rooted or slowed either")


## Rune spells (Combat.use_rune): items that level 40+ hunts drop, cast by any class from the
## action bar, used up, with Tibia-style round areas and a chain.
func _rune_checks() -> void:
	for kind: String in ["fire_rune", "frost_rune", "lightning_rune"]:
		var item: Dictionary = World.ITEMS[kind]
		check(World.stackable(kind) and item["level"] == 40 and not Spells.rune_of(item).is_empty()
			and not Spells.rune_text(item).is_empty() and Keybinds.valid_bar_entry("item:" + kind),
			"%s is a stackable level-40 rune that goes on the action bar" % kind)
	check(not Keybinds.valid_bar_entry("item:wolf_pelt") and not Keybinds.valid_bar_entry("item:nothing"),
		"only runes go on the action bar as items")
	check(Combat.circle(Vector2i(60, 40), 3).size() <= 37 and Combat.circle(Vector2i(60, 40), 3).all(func(cell: Vector2i) -> bool:
		return (cell - Vector2i(60, 40)).length_squared() <= 12), "a radius-3 rune area is round: dx² + dy² <= r² + r")
	var open: int = 0
	for dy: int in range(-3, 4):
		for dx: int in range(-3, 4):
			open += 1 if dx * dx + dy * dy <= 12 else 0
	check(open == 37, "a full radius-3 circle is 37 tiles, as in Tibia")
	# Drops: only from monsters of level 40 and up.
	var looter := Combat.new(World.new(), 5)
	var low: int = 0
	var high: int = 0
	for roll: int in 3000:
		low += looter.roll_loot("mire_stalker", 36).count("frost_rune")
		high += looter.roll_loot("mire_stalker", 44).count("frost_rune")
	check(low == 0 and high > 20, "runes drop only from level-40+ monsters (%d at 36, %d at 44)" % [low, high])
	# Casting: a fire rune at a pack, from a few tiles off; used up; the shared rune cooldown.
	var world := World.new()
	var combat := Combat.new(world, 9)
	world.monsters.clear()
	# A camp in the wilds with open ground all around (no zone: no PvP, no town).
	var field := Vector2i(-1, -1)
	for spawn: Dictionary in World.MONSTER_SPAWNS:
		var clear: bool = World.zone_at(spawn["cell"]).is_empty() and field.x < 0
		for dy: int in range(-4, 5):
			for dx: int in range(-4, 5):
				clear = clear and World.walkable(spawn["cell"] + Vector2i(dx, dy))
		if clear:
			field = spawn["cell"]
	check(field.x >= 0, "an open camp in the wilds to try runes on")
	world.add_player(1, 0.0, "knight")
	var me: Dictionary = world.players[1]
	me["level"] = 45
	_place(world, 1, field + Vector2i(-3, 0))
	var pack: Array[int] = []
	for offset: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(2, 1), Vector2i(3, 3)]:
		pack.append(combat.spawn_monster("behemoth", 45, field + offset, 0.0))
	me["target"] = pack[0]
	check(combat.use_rune(1, "fire_rune", 1.0)["reason"].begins_with("You have no"), "a rune needs a rune in your backpack")
	me["backpack"][0] = World.make_entry("fire_rune", 3)
	var health: Array[int] = []
	for monster: int in pack:
		health.append(world.monsters[monster]["health"])
	var cast: Dictionary = combat.use_rune(1, "fire_rune", 1.0)
	var hit: Array = pack.filter(func(monster: int) -> bool: return world.monsters[monster]["health"] < health[pack.find(monster)])
	check(cast["ok"] and me["backpack"][0] == "fire_rune#2" and hit.size() == 4 and pack[4] not in hit,
		"a Warrior's fire rune burns every monster within its circle and is used up (%d hit, %s)" % [hit.size(), cast.get("reason", "")])
	check(cast["events"].any(func(event: Dictionary) -> bool: return event["kind"] == "area" and event.get("element", "") == "fire"),
		"the burst shows as fire on every tile")
	check(combat.use_rune(1, "fire_rune", 2.0)["reason"] == "You are exhausted" and combat.use_rune(1, "fire_rune", 3.1)["ok"],
		"runes share a two-second cooldown")
	_place(world, 1, field + Vector2i(-9, 0))
	check(combat.use_rune(1, "fire_rune", 6.0)["reason"] == "You need a target in range", "runes reach seven tiles")
	me["level"] = 30
	check(combat.use_rune(1, "fire_rune", 9.0)["reason"].contains("needs level 40"), "runes need level 40")
	me["level"] = 45
	# Lightning leaps to two more; frost slows what it hits.
	_place(world, 1, field + Vector2i(-3, 0))
	me["backpack"][1] = World.make_entry("lightning_rune", 1)
	me["backpack"][2] = World.make_entry("frost_rune", 1)
	for monster: int in pack:
		world.monsters[monster]["health"] = 100000
	var chained: Dictionary = combat.use_rune(1, "lightning_rune", 20.0)
	var struck: int = pack.filter(func(monster: int) -> bool: return world.monsters[monster]["health"] < 100000).size()
	check(chained["ok"] and struck == 3 and me["backpack"][1] == "", "a lightning rune strikes its target and leaps to two more")
	check(combat.use_rune(1, "frost_rune", 30.0)["ok"] and world.monsters[pack[0]].get("slowed_until", 0.0) == 32.0,
		"a frost rune slows what it hits")
	# Bots cast the runes they carry at a crowd (or a player), not at a lone monster.
	var bots := Bots.new(world, combat)
	var bot: int = bots.add("paladin", 45, "hunter", field + Vector2i(-3, 1), 40.0)["id"]
	world.players[bot]["backpack"][3] = World.make_entry("fire_rune", 2)
	world.players[bot]["target"] = pack[0]
	check(bots._rune_to_use(bot) == "fire_rune", "a bot casts a rune at a pack")
	world.players[bot]["target"] = pack[4]
	check(bots._rune_to_use(bot) == "", "but not at a lone monster")
	check(BotLoot.sellable_index({"backpack": ["fire_rune#2", "wolf_pelt"]}) == 1, "bots keep their runes when they sell")


## Boss kills can be stolen: only fighters alive and near the boss when it falls earn a trophy.
func _trophy_steal_checks() -> void:
	var world := World.new()
	var combat := Combat.new(world, 3)
	for id: int in [1, 2, 3]:
		world.add_player(id, 0.0, "knight")
	var lair := Vector2i(600, 20)
	world.players[1]["cell"] = lair + Vector2i(2, 0)
	world.players[1]["health"] = 0
	world.players[2]["cell"] = lair + Vector2i(40, 0)
	world.players[3]["cell"] = lair + Vector2i(3, 2)
	combat._award_trophies("vaelith", {1: true, 2: true, 3: true}, lair, [])
	check(not world.players[1]["trophies"].has("vaelith") and not world.players[2]["trophies"].has("vaelith")
		and world.players[3]["trophies"].get("vaelith", 0) == 1,
		"only fighters alive and near the boss when it falls earn its trophy (a wiped raid loses the kill)")


## The painted world map is baked from the current map, and every task points somewhere.
func _map_guidance_checks() -> void:
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/world_map.json"))
	var baked: Texture2D = load("res://assets/sprites/world_map.png")
	check(typeof(meta) == TYPE_DICTIONARY and meta.get("terrain", "") == World.overworld_hash()
		and baked.get_width() == Atlas.SIZE.x * int(meta["scale"]),
		"the painted world map matches the map (re-bake with make world-map after editing it)")
	for task: String in Quests.TASKS:
		var definition: Dictionary = Quests.TASKS[task]
		if not definition.has("monster"):
			continue
		var targets: Array[Vector2i] = World.task_targets(task, {"tasks": {task: 0}})
		check(not targets.is_empty(), "%s points to somewhere to hunt" % task)
		var done: Array[Vector2i] = World.task_targets(task, {"tasks": {task: definition["count"]}})
		check(done.size() == 1 and done[0] == World.QUEST_GIVERS[definition["giver"]]["cell"],
			"a finished %s points back to its giver" % task)
	# Levels 20-30 always have hunting work of their own level: three or more tasks whose monsters
	# are that level (plan 24: a party of 25 had only 40+ tasks left).
	for level: int in range(20, 31):
		var hunts: int = 0
		for task: String in Quests.TASKS:
			var band: Vector2i = World.task_levels(task)
			if Quests.TASKS[task].has("monster") and Quests.dungeon_of(task).is_empty() and band.x <= level and band.y >= level:
				hunts += 1
		check(hunts >= 3, "level %d has %d overworld hunting tasks of its level" % [level, hunts])
	var cellar: String = ""
	for task: String in Quests.TASKS:
		if Quests.dungeon_of(task) == "cinder_cellar" and cellar.is_empty():
			cellar = task
	check(not cellar.is_empty() and World.task_targets(cellar, {"tasks": {cellar: 0}}) == [World.ENTRANCE_OF["cinder_cellar"]],
		"a cellar task points to the cellar stairway")


## Connected areas of walkable town ground in `rect`; with `ignore`, the pieces of those kinds
## count as walkable.
func _town_areas(rect: Rect2i, kinds: Array[String], ignore: bool) -> int:
	var open: Callable = func(cell: Vector2i) -> bool:
		if not rect.has_point(cell):
			return false
		if ignore and World.FURNITURE.get(cell, "") in kinds:
			return true
		return World.walkable(cell)
	var seen: Dictionary = {}
	var areas: int = 0
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var start := Vector2i(x, y)
			if seen.has(start) or not open.call(start):
				continue
			areas += 1
			seen[start] = true
			var queue: Array[Vector2i] = [start]
			while not queue.is_empty():
				var cell: Vector2i = queue.pop_back()
				for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					if not seen.has(cell + step) and open.call(cell + step):
						seen[cell + step] = true
						queue.append(cell + step)
	return areas



## A building wall near the start, with open ground left of it, right of it, and above it: for
## collision and line-of-sight checks (lone wall stubs are gone from the map).
func _test_wall() -> Vector2i:
	for y: int in range(2, 120):
		for x: int in range(2, 120):
			var cell := Vector2i(x, y)
			if World.terrain(cell) == "#" and World.walkable(cell + Vector2i.LEFT) and World.walkable(cell + Vector2i.RIGHT) 					and World.walkable(cell + Vector2i.UP):
				return cell
	return Vector2i.ZERO

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
	# Catalogs: spells are well formed (monsters: _monster_catalog_checks).
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
	var wall: Vector2i = _test_wall()
	check(not Combat.line_of_sight(wall + Vector2i.LEFT, wall + Vector2i.RIGHT), "a wall blocks line of sight")
	check(Combat.line_of_sight(Vector2i(5, 6), Vector2i(10, 6)), "open ground gives line of sight")
	check(Combat.line_of_sight(Vector2i(2, 3), Vector2i(6, 3)), "water does not block line of sight")
	check(Combat.in_reach(Vector2i(5, 6), Vector2i(6, 7), 1) and not Combat.in_reach(Vector2i(5, 6), Vector2i(7, 6), 1),
		"melee reaches the eight surrounding tiles only")
	check(not Combat.in_reach(wall + Vector2i.LEFT, wall + Vector2i.RIGHT, 6), "ranged attacks need line of sight")
	# Populating the map.
	var map_world := World.new()
	var map_combat := Combat.new(map_world, 3)
	map_combat.populate(0.0, true)
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
	check(world.move(1, Vector2i.DOWN, 0.0)["ok"] and world.move(1, Vector2i.DOWN, 1.0)["ok"] and world.players[1]["cell"] == Vector2i(5, 8),
		"players walk onto a monster's tile")
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
	_place(world, 1, wall + Vector2i.LEFT)
	world.monsters[vole]["cell"] = wall + Vector2i.RIGHT
	world.monsters[vole]["from"] = wall + Vector2i.RIGHT
	world.monsters[vole]["next_move"] = 100.0
	check(_hits_on(combat.tick(10.0), vole) == 0, "walls stop ranged attacks")
	world.monsters.erase(vole)
	world.monsters.erase(far)
	paladin["target"] = 0

	# Monster AI: notice, chase without overlapping, attack, then return home and heal.
	var wolf: int = combat.spawn_monster("grey_wolf", 1, Vector2i(8, 6), 20.0)
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
	check(world.monsters[wolf]["target"] == 0 and world.monsters[wolf]["cell"] == Vector2i(8, 6)
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
		if World.ITEMS[kind]["slot"].is_empty() and kind not in ["gold_coins", "glowcap"] and not World.ITEMS[kind].has("drink") \
				and not World.ITEMS[kind].has("eat"):
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
	check(tally.get("gold_coins", 0) > 800 and tally.get("gold_coins", 0) < 960, "level-1 monsters drop a coin about 22% of the time")
	var warden_loot: Array[String] = loot_rolls.roll_loot("blackreed_warden", 50)
	var warden_gold: int = _count(warden_loot, "gold_coins")
	check(warden_loot.filter(func(entry: String) -> bool: return World.kind_of(entry) == "gold_coins").size() == 1,
		"gold piles drop as one stack")
	check(warden_gold >= 4 and warden_gold <= 5, "elites add gold coins on top of the level scale")
	# Gold income: kills from level 1 to 19 pay about one vendor gear set of that level, not three.
	var kill_gold: float = 0.0
	for level: int in range(1, 19):
		kill_gold += Balance.kills_to_level(level) * Balance.coins_per_kill(level) * World.ITEMS["gold_coins"]["gold"]
	var gear_set: int = 0
	for slot: String in ["helmet", "armor", "legs", "boots", "main_hand", "off_hand"]:
		gear_set += Items.gear_price(19, slot)
	check(kill_gold > 0.6 * gear_set and kill_gold < 1.6 * gear_set, "kills to level 19 pay about one gear set (%d gold, set %d)" % [kill_gold, gear_set])
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
	check(combat.cast(1, "ember_bolt", time)["reason"].begins_with("Your class"), "class spells only")
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
	var healed_to: int = paladin["health"]
	# On Blackreed Isle (PvP), a group heal mends the druid's party but never a foe beside them.
	var isle_cell: Vector2i = World.FERRYMEN["blackreed_isle"]["cell"]
	_place(world, 4, isle_cell)
	_place(world, 1, isle_cell + Vector2i(1, 0))
	paladin["health"] = 10
	druid["cooldowns"] = {}
	druid["groups"] = {}
	druid["mana"] = world.player_stats(4)["mana"]
	check(combat.hostile(4, 1) and combat.cast(4, "mass_mend", time + 20.0)["ok"] and paladin["health"] == 10,
		"group heals never mend a foe in a PvP zone")
	_place(world, 4, Vector2i(14, 4))
	_place(world, 1, Vector2i(15, 5))
	paladin["health"] = healed_to
	# Spell tooltips and the spell book state the numbers casting uses.
	var druid_stats: Dictionary = world.player_stats(4)
	var mend_info: Dictionary = Spells.info("mass_mend", druid_stats, 10)
	check(mend_info["amount"] == "Heals %d each" % (paladin["health"] - 10)
		and mend_info["cost"].begins_with("Mana %d " % maxi(1, roundi(druid_stats["mana"] * Spells.SPELLS["mass_mend"]["mana"]))),
		"a spell's description shows the healing and mana a cast really gives and costs")
	var bolt: Dictionary = Spells.info("piercing_shot", world.player_stats(1), 1)
	var shot_damage: float = world.player_stats(1)["attack"] * Spells.SPELLS["piercing_shot"]["power"]
	check(bolt["amount"].begins_with("%d–%d damage" % [roundi(shot_damage * 0.85), roundi(shot_damage * 1.15)]),
		"an attack spell's description shows its damage spread")
	check(not Spells.info("starfall", world.player_stats(1), 1)["unlocked"]
		and Spells.info("starfall", {}, 1)["requirement"] == "✗ Needs level 45 (Sorcerer)", "locked spells say what level they need")
	var runes: Dictionary = {}
	for spell: String in Spells.SPELLS:
		runes[Spells.SPELLS[spell]["rune"]] = true
	var sheet: Texture2D = load("res://assets/sprites/spells.png")
	var generator: String = FileAccess.get_file_as_string("res://tools/generators/make_sprites.py")
	check(runes.size() == Spells.SPELLS.size() and runes.keys().all(func(rune: String) -> bool:
		return Spells.RUNES.has(rune) and generator.contains('"%s": [[' % rune)), "every spell is carved as its own Elder Futhark rune")
	check(sheet.get_width() / 32 * (sheet.get_height() / 32) >= Spells.SPELLS.size(), "spells.png has a rune stone for every spell")
	for spell: String in Spells.SPELLS:
		var text: String = Spells.describe(spell, druid_stats, 50)
		check(text.split("\n").size() >= 5 and text.contains("Cooldown") and text.contains("Mana")
			and not Spells.info(spell, {}, 50)["effect"].is_empty(), "every spell explains itself")

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
