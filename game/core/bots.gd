extends RefCounted
## Player bots on the host, for testing PvP and hunting with friends missing. A bot is a real
## player record (World.add_player, never saved, counting toward MAX_PLAYERS) driven through
## the same rules as everyone: World.move for steps, Combat.set_target, cast, and drink, so
## skulls, PvP zones, death, and loot apply to it unchanged. A LimboAI behavior tree
## (game/data/bot_behavior.tres, built by game/core/ai/bot_tree.gd) decides each turn; its
## tasks call the helpers below. It plays like the fight simulator (tools/testing/fight_sim.gd):
## strongest ready spell, heals and potions at the same health shares. Clients cannot create
## bots; only the host's Bots panel (game/ui/bot_panel.gd) does.
##
## Stances:
##   "hunter"  hunts monsters near its post and fights back against players who attack it.
##   "pvp"     also attacks any player in reach while both stand in a PvP zone.
##   "dummy"   stands still and never attacks: a target for testing damage and skulls.
## A bot that dies is restored RESTORE_SECONDS later at its post with its level, gear, and
## potions, so a test can go on.

const World = preload("res://game/core/world.gd")
const Combat = preload("res://game/core/combat.gd")
const Balance = preload("res://game/data/balance.gd")
const Spells = preload("res://game/data/spells.gd")
const Items = preload("res://game/data/items.gd")
const BotAgent = preload("res://game/core/ai/bot_agent.gd")
const BotTree = preload("res://game/core/ai/bot_tree.gd")

const STANCES: Array[String] = ["hunter", "pvp", "dummy"]
const STANCE_NAMES: Dictionary = {"hunter": "Hunter", "pvp": "PvP", "dummy": "Training dummy"}
## Bot ids start here, away from the host (1); ENet picks client ids at random, so the host
## also refuses a peer whose id a bot holds (see main.gd).
const FIRST_ID: int = 2000000001
const THINK_SECONDS: float = 0.2
const RESTORE_SECONDS: float = 6.0
## Monsters a hunter goes for: within HUNT_RADIUS of it and HOME_RADIUS of its post, at most
## LEVEL_MARGIN levels above it. Players are attacked within PVP_RADIUS.
const HUNT_RADIUS: int = 7
const HOME_RADIUS: int = 10
const LEVEL_MARGIN: int = 3
const PVP_RADIUS: int = 7
## Fight simulator thresholds: heal below HEAL_SHARE health, drink a health potion below
## POTION_SHARE, a mana potion below MANA_SHARE mana; attack spells only above ATTACK_SHARE.
const HEAL_SHARE: float = 0.55
const POTION_SHARE: float = 0.35
const MANA_SHARE: float = 0.25
const ATTACK_SHARE: float = 0.3
const POTIONS: int = 50

var world: World
var combat: Combat
## Bot id -> {vocation, level, stance, post, next_think, last_cell, restore_at}.
var bots: Dictionary = {}
## Bot id -> [BotAgent node, BTInstance]: the behavior tree running for it.
var _brains: Dictionary = {}
var _tree: BehaviorTree = BotTree.load_tree()


func _init(owner: World, fights: Combat) -> void:
	world = owner
	combat = fights


## Agents are nodes outside the scene tree: free them with the bots.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for brain: Array in _brains.values():
			(brain[0] as Node).free()
		_brains.clear()


## Vendor-style gear for a level and vocation: the best regular helmet, armor, weapon, and
## off-hand of the tiers reached (no relics or hunting drops), plus accessories from their tier.
static func gear(level: int, vocation: String) -> Dictionary:
	var best: Dictionary = {}
	var tier: int = Items.tier_for(level)
	for kind: String in World.ITEMS:
		var item: Dictionary = World.ITEMS[kind]
		var slot: String = item["slot"]
		if slot.is_empty() or slot in ["bag", "container"] or item.get("loot_only", false) or item.has("glow") or item["level"] > tier \
				or not World.requirement_error(kind, level, vocation).is_empty():
			continue
		var target: String = "ring_1" if slot == "ring" else slot
		if not best.has(target) or World.ITEMS[best[target]]["level"] < item["level"]:
			best[target] = kind
	if best.has("ring_1"):
		best["ring_2"] = best["ring_1"]
	return best


## Adds a bot beside `near`. Returns {ok, id, reason}.
func add(vocation: String, level: int, stance: String, near: Vector2i, now: float) -> Dictionary:
	if not Balance.VOCATIONS.has(vocation) or stance not in STANCES:
		return {"ok": false, "reason": "Unknown class or stance"}
	var id: int = FIRST_ID
	while world.players.has(id):
		id += 1
	if not world.add_player(id, now, vocation):
		return {"ok": false, "reason": "The world is full (%d players)" % World.MAX_PLAYERS}
	var post: Vector2i = free_cell_near(near, now, id)
	bots[id] = {"vocation": vocation, "level": clampi(level, 1, Balance.MAX_LEVEL), "stance": stance, "post": post,
		"next_think": now, "last_cell": post, "restore_at": -1.0}
	world.players[id]["bot"] = true
	var agent: Node = BotAgent.new()
	agent.bots = self
	agent.id = id
	# The agent is its own scene root: bots live outside the scene tree.
	_brains[id] = [agent, _tree.instantiate(agent, Blackboard.new(), agent, agent)]
	_restore(id, now)
	return {"ok": true, "id": id}


func remove(id: int) -> void:
	bots.erase(id)
	_free_brain(id)
	world.remove_player(id)


func _free_brain(id: int) -> void:
	if _brains.has(id):
		var agent: Node = _brains[id][0]
		_brains.erase(id)
		agent.free()


func is_bot(id: int) -> bool:
	return bots.has(id)


## The nearest walkable, unoccupied overworld cell to `near` (ring by ring), else `near`.
func free_cell_near(near: Vector2i, now: float, except_id: int = 0) -> Vector2i:
	for radius: int in range(1, 6):
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				var cell: Vector2i = near + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) == radius and World.walkable(cell) and not world.occupied(cell, now, except_id) \
						and World.terrain(cell) not in ["v", "^"]:
					return cell
	return near


## Gives a bot its level, gear, potions, and full health and mana at its post.
func _restore(id: int, now: float) -> void:
	var bot: Dictionary = bots[id]
	var player: Dictionary = world.players[id]
	player["level"] = bot["level"]
	player["experience"] = 0
	player["equipment"] = gear(bot["level"], bot["vocation"])
	player["backpack"].fill("")
	player["backpack"][0] = World.make_entry("health_potion", POTIONS)
	player["backpack"][1] = World.make_entry("mana_potion", POTIONS)
	player["target"] = 0
	var cell: Vector2i = bot["post"] if not world.occupied(bot["post"], now, id) else free_cell_near(bot["post"], now, id)
	player["cell"] = cell
	player["from"] = cell
	player["next_move"] = now
	var limits: Dictionary = world.player_stats(id)
	player["health"] = limits["health"]
	player["mana"] = limits["mana"]
	bot["last_cell"] = cell
	bot["restore_at"] = -1.0


## Runs every bot's turn. Returns events like Combat.tick; steps carry "movement": true.
func tick(now: float) -> Array:
	var events: Array = []
	for id: int in bots.keys():
		if not world.players.has(id):
			bots.erase(id)
			_free_brain(id)
			continue
		var bot: Dictionary = bots[id]
		var player: Dictionary = world.players[id]
		if bot["restore_at"] >= 0.0:
			if now >= bot["restore_at"]:
				_restore(id, now)
				events.append({"kind": "player", "id": id})
			continue
		# A bot moves one tile per turn at most, so a jump means it died and woke up in town.
		if Combat.distance(player["cell"], bot["last_cell"]) > 2:
			bot["restore_at"] = now + RESTORE_SECONDS
			bot["last_cell"] = player["cell"]
			continue
		if now < bot["next_think"]:
			continue
		bot["next_think"] = now + THINK_SECONDS
		var agent: Node = _brains[id][0]
		agent.now = now
		agent.events = events
		_brains[id][1].update(THINK_SECONDS)
		bot["last_cell"] = player["cell"]
	return events


## Moves into reach of the bot's target along a real path; ranged vocations back off a step
## from a foe beside them, as players kite.
func engage(id: int, now: float, events: Array) -> void:
	var player: Dictionary = world.players[id]
	var target: int = player["target"]
	if target == 0 or not combat.exists(target):
		return
	var there: Vector2i = combat.creature(target)["cell"]
	var reach: int = combat.reach_of(id)
	if not Combat.in_reach(player["cell"], there, reach):
		_step(id, Combat.path_step(player["cell"], there, _blocked_for(id, now)), now, events)
	elif reach > 1 and Combat.distance(player["cell"], there) <= 1:
		_step(id, Combat.step_toward(player["cell"], player["cell"] * 2 - there, _blocked_for(id, now)), now, events)


## One step along a path back to the bot's post.
func walk_home(id: int, now: float, events: Array) -> void:
	_step(id, Combat.path_step(world.players[id]["cell"], bots[id]["post"], _blocked_for(id, now)), now, events)


## Keeps a valid target, else picks: an attacker, a PvP victim (PvP stance), a monster after
## the bot, then (hunters and PvP bots) the nearest monster worth hunting near its post.
func choose_target(id: int, now: float) -> int:
	var bot: Dictionary = bots[id]
	var player: Dictionary = world.players[id]
	var current: int = player["target"]
	if current != 0 and combat.hostile(id, current) \
			and Combat.distance(player["cell"], combat.creature(current)["cell"]) <= Combat.TARGET_RANGE:
		return current
	var best: int = 0
	var nearest: int = 1 << 30
	for other: int in world.players:
		var close: int = Combat.distance(player["cell"], world.players[other]["cell"])
		var attacked: bool = player["aggressors"].get(other, -INF) > now or world.players[other]["target"] == id
		var hunted: bool = bot["stance"] == "pvp" and close <= PVP_RADIUS
		if (attacked or hunted) and combat.hostile(id, other) and close < nearest:
			best = other
			nearest = close
	if best != 0:
		return best
	for monster: int in world.monsters:
		var state: Dictionary = world.monsters[monster]
		var close: int = Combat.distance(player["cell"], state["cell"])
		var chasing: bool = state["target"] == id
		var prey: bool = close <= HUNT_RADIUS and Combat.distance(state["cell"], bot["post"]) <= HOME_RADIUS \
			and state["level"] <= player["level"] + LEVEL_MARGIN and not state.get("returning", false)
		if (chasing or prey) and combat.hostile(id, monster) and close < nearest:
			best = monster
			nearest = close
	return best


## Spells and potions exactly as the fight simulator's careful player uses them.
func use_resources(id: int, now: float, events: Array) -> void:
	var player: Dictionary = world.players[id]
	var stats: Dictionary = world.player_stats(id)
	var share: float = float(player["health"]) / stats["health"]
	var fighting: bool = player["target"] != 0 and combat.exists(player["target"])
	for spell: String in _spells(id):
		var style: String = Spells.SPELLS[spell]["kind"]
		if (style.begins_with("heal") and share < HEAL_SHARE) or (fighting and not style.begins_with("heal") and style != "taunt"
				and share >= ATTACK_SHARE):
			var cast: Dictionary = combat.cast(id, spell, now)
			if cast["ok"]:
				events.append_array(cast["events"])
	var potion: String = ""
	if share < POTION_SHARE:
		potion = "health_potion"
	elif float(player["mana"]) / maxf(1.0, stats["mana"]) < MANA_SHARE:
		potion = "mana_potion"
	if potion.is_empty():
		return
	var index: int = player["backpack"].find_custom(func(entry: String) -> bool: return World.kind_of(entry) == potion)
	if index >= 0:
		var drunk: Dictionary = combat.drink(id, index, now)
		if drunk["ok"]:
			events.append_array(drunk["events"])


## The bot's known spells, strongest first (like a player reaching for their best ready spell).
func _spells(id: int) -> Array[String]:
	var player: Dictionary = world.players[id]
	var known: Array[String] = Spells.for_vocation(player["vocation"]).filter(func(spell: String) -> bool:
		return Spells.SPELLS[spell]["level"] <= player["level"])
	known.sort_custom(func(a: String, b: String) -> bool: return Spells.SPELLS[a]["power"] > Spells.SPELLS[b]["power"])
	return known


func _step(id: int, direction: Vector2i, now: float, events: Array) -> void:
	if direction == Vector2i.ZERO:
		return
	if world.move(id, direction, now)["ok"]:
		events.append({"kind": "player", "id": id, "movement": true})


## Occupied tiles and stairways block a bot's path (bots never take stairs or leave the world).
func _blocked_for(id: int, now: float) -> Callable:
	var taken: Dictionary = world.occupied_cells(now, id)
	return func(cell: Vector2i) -> bool: return taken.has(cell) or World.terrain(cell) in ["v", "^"]
