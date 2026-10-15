extends RefCounted
## Player bots on the host, for testing PvP and hunting with friends missing. A bot is a real
## player record (World.add_player, never saved, counting toward MAX_PLAYERS) driven through
## the same rules as everyone: World.move for steps, Combat.set_target, cast, and drink, so
## skulls, PvP zones, death, and loot apply to it unchanged. A LimboAI behavior tree
## (game/data/bot_behavior.tres, built by game/core/ai/bot_tree.gd) decides each turn; its
## tasks call the helpers below. It plays like the fight simulator (tools/testing/fight_sim.gd):
## strongest ready spell, heals and potions at the same health shares. Clients cannot create
## bots: solo play (game/core/solo.gd) brings its own, and tests use the host's spawn_bot.
##
## Stances:
##   "hunter"  hunts monsters near its post and fights back against players who attack it.
##   "pvp"     also attacks any player in reach while both stand in a PvP zone.
##   "dummy"   stands still and never attacks: a target for testing damage and skulls.
## Solo play (game/core/solo.gd) adds two more:
##   "companion"  follows its leader in their party at their level and gear tier, fights what
##                they fight or what attacks the party, heals and taunts for the group, and
##                follows through waystones, ferries, deaths, and dungeon stairs.
##   "rival"      an adventurer band: its leader takes a task at its giver, hunts the task's
##                monsters at a camp, and turns it in, again and again (run_plan); members follow
##                the leader like companions. A band may ambush players in a PvP zone ("ambush").
## Hunters, PvP bots, and rivals also collect the loot their bot group earned and sell it at the
## nearest vendor when their packs are nearly full (game/core/bot_loot.gd); loot a human player
## earned is left for them, and loot that does not fit stays on the ground.
## A hunter, PvP, or dummy bot that dies is restored RESTORE_SECONDS later at its post with its
## level, gear, and potions, so a test can go on; companions come back beside their leader,
## rivals where they woke up (the town), and both keep going.
## Levels: companions keep their leader's level. Rivals earn experience from kills and tasks
## like players: each level gained upgrades their gear (track_level), and a death costs them
## what it costs a player (they wake with the level and experience left), never more.

const World = preload("res://game/core/world.gd")
const Combat = preload("res://game/core/combat.gd")
const Balance = preload("res://game/data/balance.gd")
const Spells = preload("res://game/data/spells.gd")
const Items = preload("res://game/data/items.gd")
const BotAgent = preload("res://game/core/ai/bot_agent.gd")
const BotTree = preload("res://game/core/ai/bot_tree.gd")
const Nav = preload("res://game/core/nav.gd")
const Quests = preload("res://game/data/quests.gd")
const Monsters = preload("res://game/data/monsters.gd")
const BotLoot = preload("res://game/core/bot_loot.gd")

## Stances for standalone bots (tests, the fight and duel simulators); solo play uses SOLO_STANCES.
const STANCES: Array[String] = ["hunter", "pvp", "dummy"]
const SOLO_STANCES: Array[String] = ["companion", "rival"]
const STANCE_NAMES: Dictionary = {"hunter": "Hunter", "pvp": "PvP", "dummy": "Training dummy", "companion": "Companion",
	"rival": "Rival"}
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
## Rivals carry fewer potions: what they drop is the reward for beating them.
const RIVAL_POTIONS: int = 10
## Followers keep within FOLLOW_RANGE of their leader and, beyond TELEPORT_RANGE or in another
## space (a dungeon copy, after a waystone or a death), rejoin them at once.
const FOLLOW_RANGE: int = 2
const TELEPORT_RANGE: int = 24
## Nobody sees a bot farther than SEEN_RADIUS from every player (the game window shows about
## eight tiles each way): rivals take long trips there in one jump instead of walking the world.
const SEEN_RADIUS: int = 14
const FAST_TRAVEL_DISTANCE: int = 40
## Group play: druids heal the party below HEAL_ALLY_SHARE; warriors challenge monsters on a
## softer member, and the off-tank takes the boss when its wounds on the main tank reach SWAP_WOUNDS.
const HEAL_ALLY_SHARE: float = 0.8
const SWAP_WOUNDS: int = 3
## Rival bands hunt a camp until their task is done or HUNT_SECONDS pass, and ambush players in
## PvP zones within AMBUSH_RADIUS.
const HUNT_SECONDS: float = 600.0
## A band waits CAMP_DISTANCE tiles from a camp's marker (its followers stand two tiles nearer,
## and monsters do not respawn with a player within four tiles), hunting what is within
## CAMP_REACH of the marker.
const CAMP_DISTANCE: int = 9
const CAMP_REACH: int = 6
## camp_post results by camp marker (posts never change).
static var _posts: Dictionary = {}
const AMBUSH_RADIUS: int = 12
var world: World
var combat: Combat
## Bot id -> {vocation, level, stance, post, next_think, last_cell, restore_at, leader, name,
## plan, route}. "leader" is a companion's player or a rival's band leader (0 for none, its own
## id for a band leader); "plan" is a band leader's errand (run_plan); "route" the cells ahead.
var bots: Dictionary = {}
## Dungeon copies (game/core/instances.gd), so companions can follow their leader down stairs.
var instances: RefCounted = null
## Bot id -> [BotAgent node, BTInstance]: the behavior tree running for it.
var _brains: Dictionary = {}
var _tree: BehaviorTree = BotTree.load_tree()
## Collecting the group's loot and selling it at vendors (game/core/bot_loot.gd).
var loot: BotLoot


func _init(owner: World, fights: Combat) -> void:
	world = owner
	combat = fights
	loot = BotLoot.new(self)


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


## Adds a bot beside `near`. Returns {ok, id, reason}. `extra` sets solo fields: leader, name.
func add(vocation: String, level: int, stance: String, near: Vector2i, now: float, extra: Dictionary = {}) -> Dictionary:
	if not Balance.VOCATIONS.has(vocation) or (stance not in STANCES and stance not in SOLO_STANCES):
		return {"ok": false, "reason": "Unknown class or stance"}
	var id: int = FIRST_ID
	while world.players.has(id):
		id += 1
	if not world.add_player(id, now, vocation):
		return {"ok": false, "reason": "The world is full (%d players)" % World.MAX_PLAYERS}
	var post: Vector2i = free_cell_near(near, now, id)
	bots[id] = {"vocation": vocation, "level": clampi(level, 1, Balance.MAX_LEVEL), "stance": stance, "post": post,
		"next_think": now + think_phase(id), "last_cell": post, "restore_at": -1.0, "leader": int(extra.get("leader", 0)),
		"name": String(extra.get("name", "")), "plan": {}, "route": []}
	world.players[id]["bot"] = true
	if not bots[id]["name"].is_empty():
		world.players[id]["name"] = bots[id]["name"]
	# Companions keep what they carry when they die (they come straight back); rivals drop theirs.
	world.players[id]["companion"] = stance == "companion"
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


## Gives a bot its level, gear, potions, and full health and mana at its post (or `at`).
## With keep_progress the experience it has left is kept (a rival after a death).
func _restore(id: int, now: float, at: Vector2i = Vector2i(-1, -1), keep_progress: bool = false) -> void:
	var bot: Dictionary = bots[id]
	var player: Dictionary = world.players[id]
	player["level"] = bot["level"]
	if not keep_progress:
		player["experience"] = 0
	player["equipment"] = gear(bot["level"], bot["vocation"])
	player["backpack"].fill("")
	var potions: int = RIVAL_POTIONS if bot["stance"] == "rival" else POTIONS
	player["backpack"][0] = World.make_entry("health_potion", potions)
	player["backpack"][1] = World.make_entry("mana_potion", potions)
	player["target"] = 0
	bot["route"] = []
	BotLoot.reset(bot)
	var spot: Vector2i = bot["post"] if at.x < 0 else at
	var cell: Vector2i = spot if not world.occupied(spot, now, id) else free_cell_near(spot, now, id)
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
				var leader: int = bot["leader"]
				if bot["stance"] == "companion" and world.players.has(leader):
					_restore(id, now, free_cell_near(world.players[leader]["cell"], now, id))
				elif bot["stance"] == "rival":
					bot["plan"] = {}
					bot["level"] = player["level"]
					_restore(id, now, player["cell"], true)
				else:
					_restore(id, now)
				events.append({"kind": "player", "id": id})
			continue
		# A bot moves one tile per turn at most (its own jumps reset last_cell), so a jump means
		# it died and woke up in town.
		if Combat.distance(player["cell"], bot["last_cell"]) > 2:
			bot["restore_at"] = now + RESTORE_SECONDS
			bot["last_cell"] = player["cell"]
			continue
		if now < bot["next_think"]:
			continue
		# Keep each bot's own phase (set when it was added) so their turns stay spread out.
		bot["next_think"] = maxf(bot["next_think"] + THINK_SECONDS, now)
		if bot["stance"] == "companion":
			_keep_pace(id, now, events)
		elif bot["stance"] == "rival" and player["level"] != bot["level"]:
			track_level(id, events)
		var agent: Node = _brains[id][0]
		agent.now = now
		agent.events = events
		_brains[id][1].update(THINK_SECONDS)
		bot["last_cell"] = player["cell"]
	return events


## When in each THINK_SECONDS a bot takes its turn, spread by the golden ratio over its id, so a
## raid's bots do not all think in the same frame.
static func think_phase(id: int) -> float:
	return THINK_SECONDS * fposmod(id * 0.6180339887, 1.0)


## Moves into reach of the bot's target along a real path; ranged vocations back off a step
## from a foe beside them, as players kite.
func engage(id: int, now: float, events: Array) -> void:
	var player: Dictionary = world.players[id]
	var target: int = player["target"]
	if target == 0 or not combat.exists(target):
		return
	if _tend(id, now, events):
		return
	var there: Vector2i = combat.creature(target)["cell"]
	var reach: int = combat.reach_of(id)
	if not Combat.in_reach(player["cell"], there, reach):
		_step(id, Combat.path_step(player["cell"], there, _blocked_for(id, now)), now, events)
	elif reach > 1 and Combat.distance(player["cell"], there) <= 1:
		_step(id, Combat.step_toward(player["cell"], player["cell"] * 2 - there, _blocked_for(id, now)), now, events)


## One step along a path back to the bot's post.
func walk_home(id: int, now: float, events: Array) -> void:
	step_toward(id, bots[id]["post"], now, events)


## One step along a path toward `cell` (never across a stairway).
func step_toward(id: int, cell: Vector2i, now: float, events: Array) -> void:
	_step(id, Combat.path_step(world.players[id]["cell"], cell, _blocked_for(id, now)), now, events)


## The bot's party, or just itself (for BotLoot and the behavior tree's tasks).
func party_of(id: int) -> Array[int]:
	return _group(id)


## Keeps a valid target, else picks: an attacker, a PvP victim (PvP stance), a monster after
## the bot, then (hunters and PvP bots) the nearest monster worth hunting near its post.
func choose_target(id: int, now: float) -> int:
	var bot: Dictionary = bots[id]
	var player: Dictionary = world.players[id]
	var current: int = player["target"]
	var leader: int = bot["leader"]
	# Followers fight what their leader fights.
	if leader != 0 and leader != id and world.players.has(leader):
		var wanted: int = world.players[leader]["target"]
		if wanted != 0 and combat.exists(wanted) and combat.hostile(id, wanted) \
				and Combat.distance(player["cell"], combat.creature(wanted)["cell"]) <= Combat.TARGET_RANGE:
			return wanted
	# An ambushing band leader goes for the players it came for, even off a monster that got in
	# the way; its members follow its target.
	if bot["stance"] == "rival" and bot["plan"].get("state", "") == "ambush" and current <= 0:
		var victim: int = _nearest_player(id, AMBUSH_RADIUS)
		if victim != 0:
			return victim
	if current != 0 and combat.hostile(id, current) \
			and Combat.distance(player["cell"], combat.creature(current)["cell"]) <= Combat.TARGET_RANGE:
		return current
	var defend: int = _defend_group(id, now)
	if defend != 0 or leader != 0 and leader != id:
		return defend
	if bot["stance"] == "rival":
		# A band leader looks for prey only at its camp.
		if bot["plan"].get("state", "") != "hunt":
			return 0
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
		var home: bool = Combat.distance(state["cell"], bot["post"]) <= HOME_RADIUS
		if bot["stance"] == "rival":
			home = Combat.distance(state["cell"], bot["plan"].get("marker", bot["post"])) <= CAMP_REACH
		var prey: bool = close <= (Combat.TARGET_RANGE if bot["stance"] == "rival" else HUNT_RADIUS) and home \
			and state["level"] <= player["level"] + LEVEL_MARGIN and not state.get("returning", false)
		if (chasing or prey) and combat.hostile(id, monster) and close < nearest:
			best = monster
			nearest = close
	return best


## Spells and potions as the fight simulator's careful player uses them; in a party, healing
## spells also mend hurt allies around the bot, and warriors use Challenge (every monster around)
## and Provoke (one monster a few tiles off, onto a softer member) to protect the group.
func use_resources(id: int, now: float, events: Array) -> void:
	var player: Dictionary = world.players[id]
	var stats: Dictionary = world.player_stats(id)
	var share: float = float(player["health"]) / stats["health"]
	var fighting: bool = player["target"] != 0 and combat.exists(player["target"])
	for spell: String in _spells(id):
		var definition: Dictionary = Spells.SPELLS[spell]
		var style: String = definition["kind"]
		var wanted: bool = (style.begins_with("heal") and share < HEAL_SHARE) or (fighting and not style.begins_with("heal")
			and style != "taunt" and share >= ATTACK_SHARE)
		if style == "heal_area" and not wanted:
			wanted = _hurt_ally(id, definition["radius"], HEAL_ALLY_SHARE)
		if style == "taunt":
			wanted = _should_taunt(id, definition["radius"], now)
		if style == "taunt_target":
			var loose: int = _loose_monster(id, definition["range"])
			wanted = loose != 0
			if wanted:
				player["target"] = loose
		if wanted:
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


## Stairways block a bot's path (bots never take stairs on their own); creatures never do.
func _blocked_for(_id: int, _now: float) -> Callable:
	return func(cell: Vector2i) -> bool: return World.terrain(cell) in ["v", "^"]



# ---------------------------------------------------------------- group play (solo)

## The bot's party, or just itself.
func _group(id: int) -> Array[int]:
	var leader: int = world.players[id]["party"]
	if leader == 0:
		var alone: Array[int] = [id]
		return alone
	return combat.party_members(leader)


## A creature attacking the bot's party (a player who hit a member, or a monster chasing one),
## nearest first; 0 when the group is left alone. One pass over the monsters.
func _defend_group(id: int, now: float) -> int:
	var own: Vector2i = world.players[id]["cell"]
	var group: Array[int] = _group(id)
	var best: int = 0
	var nearest: int = 1 << 30
	for other: int in world.players:
		var close: int = Combat.distance(own, world.players[other]["cell"])
		if close > Combat.TARGET_RANGE or close >= nearest or other in group:
			continue
		var attacking: bool = world.players[other]["target"] in group
		for member: int in group:
			attacking = attacking or world.players[member]["aggressors"].get(other, -INF) > now
		if attacking and combat.hostile(id, other):
			best = other
			nearest = close
	for monster: int in world.monsters:
		var state: Dictionary = world.monsters[monster]
		if state["target"] == 0 or not state["target"] in group:
			continue
		var close: int = Combat.distance(own, state["cell"])
		if close <= Combat.TARGET_RANGE and close < nearest and combat.hostile(id, monster):
			best = monster
			nearest = close
	return best


## The nearest player the bot may attack within `radius` (both must stand in a PvP zone).
func _nearest_player(id: int, radius: int) -> int:
	var own: Vector2i = world.players[id]["cell"]
	var best: int = 0
	var nearest: int = radius + 1
	for other: int in world.players:
		var close: int = Combat.distance(own, world.players[other]["cell"])
		if close < nearest and combat.hostile(id, other):
			best = other
			nearest = close
	return best


## Whether a party member (or the bot) within `radius` is below `share` of their health.
func _hurt_ally(id: int, radius: int, share: float) -> bool:
	var own: Vector2i = world.players[id]["cell"]
	for member: int in _group(id):
		var friend: Dictionary = world.players[member]
		if Combat.distance(own, friend["cell"]) <= radius \
				and float(friend["health"]) / world.player_stats(member)["health"] < share:
			return true
	return false


## A warrior in a party challenges when a monster within `radius` attacks a member who is not
## a warrior, or when a boss has wounded the other tank SWAP_WOUNDS times (the tank swap).
## The nearest monster within `reach` that is after a party member who is not a warrior, or 0.
func _loose_monster(id: int, reach: int) -> int:
	var group: Array[int] = _group(id)
	if group.size() < 2:
		return 0
	var own: Vector2i = world.players[id]["cell"]
	var best: int = 0
	var nearest: int = reach + 1
	for monster: int in world.monsters:
		var state: Dictionary = world.monsters[monster]
		var victim: int = state["target"]
		var gap: int = Combat.distance(own, state["cell"])
		if victim != id and victim in group and world.players[victim]["vocation"] != "knight" and gap < nearest:
			best = monster
			nearest = gap
	return best


func _should_taunt(id: int, radius: int, now: float) -> bool:
	var group: Array[int] = _group(id)
	if group.size() < 2:
		return false
	var own: Vector2i = world.players[id]["cell"]
	for monster: int in world.monsters:
		var state: Dictionary = world.monsters[monster]
		var victim: int = state["target"]
		if victim == id or victim not in group or Combat.distance(own, state["cell"]) > radius:
			continue
		if world.players[victim]["vocation"] != "knight":
			return true
		if Monsters.MONSTERS[state["kind"]]["rank"] == "boss" and combat.wound_stacks(monster, victim, now) >= SWAP_WOUNDS:
			return true
	return false


## Healers step toward a hurt member out of their heal's reach; returns whether they moved.
func _tend(id: int, now: float, events: Array) -> bool:
	var player: Dictionary = world.players[id]
	if player["vocation"] != "druid" or _group(id).size() < 2:
		return false
	var worst: int = 0
	var lowest: float = HEAL_ALLY_SHARE
	for member: int in _group(id):
		var share: float = float(world.players[member]["health"]) / world.player_stats(member)["health"]
		if member != id and share < lowest and Combat.distance(player["cell"], world.players[member]["cell"]) > 3:
			worst = member
			lowest = share
	if worst == 0:
		return false
	_step(id, Combat.path_step(player["cell"], world.players[worst]["cell"], _blocked_for(id, now)), now, events)
	return true


## A bot whose level changed (a level earned, a death, a band catching up) takes it as its own
## and wears the vendor gear of that level.
func track_level(id: int, events: Array) -> void:
	var bot: Dictionary = bots[id]
	var player: Dictionary = world.players[id]
	bot["level"] = player["level"]
	player["equipment"] = gear(player["level"], bot["vocation"])
	events.append({"kind": "player", "id": id})


## A companion keeps its leader's level and gear tier, and stays in their party.
func _keep_pace(id: int, now: float, events: Array) -> void:
	var bot: Dictionary = bots[id]
	var leader: int = bot["leader"]
	if not world.players.has(leader):
		return
	var level: int = world.players[leader]["level"]
	if bot["level"] != level:
		bot["level"] = level
		var player: Dictionary = world.players[id]
		player["level"] = level
		player["experience"] = 0
		player["equipment"] = gear(level, bot["vocation"])
		var limits: Dictionary = world.player_stats(id)
		player["health"] = limits["health"]
		player["mana"] = limits["mana"]
		events.append({"kind": "player", "id": id})
	join_leader(id, now, events)


## Puts a follower in its leader's party (the leader's party, or a new one led by the leader).
func join_leader(id: int, now: float, events: Array) -> void:
	var leader: int = bots[id]["leader"]
	if leader == id or not world.players.has(leader):
		return
	var party: int = world.players[leader]["party"]
	if world.players[id]["party"] != 0 and world.players[id]["party"] == party:
		return
	if world.players[id]["party"] != 0:
		combat.leave_party(id, events)
	var host: int = party if party != 0 else leader
	world.players[host]["invited"][id] = true
	var joined: Dictionary = combat.party_action(id, "join", host, now)
	events.append_array(joined["events"])


## Whether any player who is not a bot is within SEEN_RADIUS of `cell` in the same space.
func seen(cell: Vector2i) -> bool:
	for other: int in world.players:
		if not world.players[other].get("bot", false) and Combat.distance(world.players[other]["cell"], cell) <= SEEN_RADIUS \
				and World.dungeon_at(world.players[other]["cell"]) == World.dungeon_at(cell):
			return true
	return false


## Moves a bot to a free cell near `cell` in one jump (fast travel, rejoining a leader).
func jump(id: int, cell: Vector2i, now: float, events: Array) -> void:
	var player: Dictionary = world.players[id]
	var spot: Vector2i = free_cell_near(cell, now, id)
	player["cell"] = spot
	player["from"] = spot
	player["next_move"] = now
	player["target"] = 0
	player["gathering"] = {}
	bots[id]["last_cell"] = spot
	bots[id]["route"] = []
	events.append({"kind": "player", "id": id})


## Followers stay beside their leader, rejoining them at once in another space or far away
## (rivals only where nobody sees them jump). Fails without a leader to follow.
func follow(id: int, now: float, events: Array) -> bool:
	var bot: Dictionary = bots[id]
	var leader: int = bot["leader"]
	if leader == 0 or leader == id or not world.players.has(leader):
		return false
	var player: Dictionary = world.players[id]
	var there: Vector2i = world.players[leader]["cell"]
	var place: Array = World.dungeon_at(there)
	var apart: bool = World.dungeon_at(player["cell"]) != place or Combat.distance(player["cell"], there) > TELEPORT_RANGE
	if apart and (bot["stance"] == "companion" or not seen(player["cell"]) and not seen(there)):
		if not place.is_empty() and instances != null and bot["stance"] == "companion":
			events.append_array(instances.enter(id, place[0], now))
			bots[id]["last_cell"] = player["cell"]
		else:
			jump(id, there, now, events)
		return true
	if _tend(id, now, events):
		return true
	if Combat.distance(player["cell"], there) > FOLLOW_RANGE:
		if apart:
			travel(id, there, FOLLOW_RANGE, now, events)
		else:
			_step(id, Combat.path_step(player["cell"], there, _blocked_for(id, now)), now, events)
	return true


## Heads for `goal` along a planned route, or jumps there when far and unseen. Returns true
## once within `reach` tiles.
func travel(id: int, goal: Vector2i, reach: int, now: float, events: Array) -> bool:
	var bot: Dictionary = bots[id]
	var player: Dictionary = world.players[id]
	if Combat.distance(player["cell"], goal) <= reach:
		bot["route"] = []
		return true
	if Combat.distance(player["cell"], goal) > FAST_TRAVEL_DISTANCE and not seen(player["cell"]) and not seen(goal):
		jump(id, Nav.open_beside(goal) if not World.walkable(goal) else goal, now, events)
		return Combat.distance(world.players[id]["cell"], goal) <= reach
	var route: Array = bot["route"]
	if route.is_empty() or bot.get("route_goal", Vector2i(-1, -1)) != goal \
			or Combat.distance(player["cell"], route[0]) != 1:
		route = Nav.route(player["cell"], goal)
		bot["route"] = route
		bot["route_goal"] = goal
		if route.is_empty():
			return false
	var next: Vector2i = route[0]
	var direction: Vector2i = next - player["cell"]
	if world.move(id, direction, now)["ok"]:
		events.append({"kind": "player", "id": id, "movement": true})
		if player["cell"] == next:
			route.pop_front()
		else:
			bot["route"] = []
	return false


# ---------------------------------------------------------------- rival bands

## A rival band leader's errand, one step per turn when it has nothing to fight:
##   pick     choose a task that fits (or, with none, a camp to hunt) and its giver
##   accept   walk to the giver and take the task
##   camp     go to a camp of the task's monster; hunt there (choose_target hunts near the post)
##   hunt     until the task is done or HUNT_SECONDS pass
##   turn_in  walk back to the giver and turn it in, then pick again
##   ambush   (solo.gd) go to a player in a PvP zone and fight them
func run_plan(id: int, now: float, events: Array) -> void:
	var bot: Dictionary = bots[id]
	var player: Dictionary = world.players[id]
	var plan: Dictionary = bot["plan"]
	match plan.get("state", "pick"):
		"pick":
			bot["plan"] = _choose_errand(id, now)
		"accept":
			var giver: Dictionary = World.QUEST_GIVERS[Quests.TASKS[plan["task"]]["giver"]]
			if travel(id, giver["cell"], World.TALK_RANGE, now, events):
				var taken: Dictionary = combat.task_action(id, Quests.TASKS[plan["task"]]["giver"], plan["task"], "accept", now)
				plan["state"] = "camp" if taken["ok"] or player["tasks"].has(plan["task"]) else "pick"
		"camp":
			if travel(id, plan["camp"], 2, now, events):
				bot["post"] = plan["camp"]
				plan["state"] = "hunt"
				plan["until"] = now + HUNT_SECONDS
		"hunt":
			var task: String = plan.get("task", "")
			var done: bool = not task.is_empty() and int(player["tasks"].get(task, 0)) >= Quests.TASKS[task]["count"]
			var prey: int = _camp_prey(id)
			if done or now >= plan["until"]:
				plan["state"] = "turn_in" if done else "pick"
			elif prey != 0:
				# Close in on a monster at the camp (targets lock within Combat.TARGET_RANGE).
				travel(id, combat.creature(prey)["cell"], Combat.TARGET_RANGE - 2, now, events)
			elif Combat.distance(player["cell"], bot["post"]) > 2:
				travel(id, bot["post"], 1, now, events)
		"turn_in":
			var giver_id: String = Quests.TASKS[plan["task"]]["giver"]
			if travel(id, World.QUEST_GIVERS[giver_id]["cell"], World.TALK_RANGE, now, events):
				events.append_array(combat.task_action(id, giver_id, plan["task"], "complete", now)["events"])
				bot["plan"] = {}
		"ambush":
			var target: int = plan.get("target", 0)
			if not world.players.has(target) or not combat.in_pvp_zone(target) or now >= plan.get("until", 0.0):
				bot["plan"] = {}
			else:
				travel(id, world.players[target]["cell"], 2, now, events)


## A task that fits the band leader's level, with an overworld camp of its monster, else a
## camp of a monster near its level to hunt for a while.
func _choose_errand(id: int, now: float) -> Dictionary:
	var player: Dictionary = world.players[id]
	var state: Dictionary = {"level": player["level"], "vocation": player["vocation"], "tasks": player["tasks"],
		"done_tasks": player["done_tasks"].keys()}
	var choices: Array[String] = []
	for task: String in Quests.TASKS:
		if Quests.TASKS[task].has("monster") and World.task_open(task, state) and World.task_fits(task, player["level"]) \
				and not _camps_of(Quests.TASKS[task]["monster"], player["level"]).is_empty():
			choices.append(task)
	if choices.is_empty() and not player["done_tasks"].is_empty():
		# Done everything that fits: the band starts over (bots replay tasks).
		player["done_tasks"].clear()
		return {}
	if not choices.is_empty():
		var task: String = choices[combat.rng.randi_range(0, choices.size() - 1)]
		var camps: Array[Vector2i] = _camps_of(Quests.TASKS[task]["monster"], player["level"])
		var marker: Vector2i = camps[combat.rng.randi_range(0, camps.size() - 1)]
		return {"state": "accept", "task": task, "camp": camp_post(marker), "marker": marker}
	var near: Array[Vector2i] = []
	for spawn: Dictionary in World.MONSTER_SPAWNS:
		if absi(spawn["level"] - player["level"]) <= LEVEL_MARGIN and World.zone_at(spawn["cell"]).is_empty() \
				and Monsters.MONSTERS[spawn["monster"]]["rank"] == "normal" and camp_post(spawn["cell"]).x >= 0:
			near.append(spawn["cell"])
	if near.is_empty():
		return {}
	var spot: Vector2i = near[combat.rng.randi_range(0, near.size() - 1)]
	return {"state": "camp", "camp": camp_post(spot), "marker": spot, "until": now + HUNT_SECONDS}


## The nearest live monster of the band leader's camp worth hunting, or 0.
func _camp_prey(id: int) -> int:
	var player: Dictionary = world.players[id]
	var marker: Vector2i = bots[id]["plan"].get("marker", bots[id]["post"])
	var best: int = 0
	var nearest: int = 1 << 30
	for monster: int in world.monsters:
		var state: Dictionary = world.monsters[monster]
		var close: int = Combat.distance(player["cell"], state["cell"])
		if Combat.distance(state["cell"], marker) <= CAMP_REACH and close < nearest and not state.get("returning", false) \
				and state["level"] <= player["level"] + LEVEL_MARGIN and combat.hostile(id, monster):
			best = monster
			nearest = close
	return best


## Camp markers of overworld camps (outside zones) of a monster at most
## LEVEL_MARGIN levels above `level`.
func _camps_of(monster: String, level: int) -> Array[Vector2i]:
	var camps: Array[Vector2i] = []
	for spawn: Dictionary in World.MONSTER_SPAWNS:
		if spawn["monster"] == monster and spawn["level"] <= level + LEVEL_MARGIN and World.zone_at(spawn["cell"]).is_empty() \
				and camp_post(spawn["cell"]).x >= 0:
			camps.append(spawn["cell"])
	return camps


## Where a band waits at a camp: CAMP_DISTANCE tiles from its marker, since monsters do not
## respawn with a player right beside it (Combat respawns); (-1, -1) if there is no open ground.
static func camp_post(camp: Vector2i) -> Vector2i:
	if _posts.has(camp):
		return _posts[camp]
	_posts[camp] = _find_post(camp)
	return _posts[camp]


static func _find_post(camp: Vector2i) -> Vector2i:
	for step: Vector2i in [Vector2i(CAMP_DISTANCE, 0), Vector2i(-CAMP_DISTANCE, 0), Vector2i(0, CAMP_DISTANCE), Vector2i(0, -CAMP_DISTANCE),
			Vector2i(CAMP_DISTANCE, CAMP_DISTANCE - 2), Vector2i(-CAMP_DISTANCE, CAMP_DISTANCE - 2),
			Vector2i(CAMP_DISTANCE, 2 - CAMP_DISTANCE), Vector2i(-CAMP_DISTANCE, 2 - CAMP_DISTANCE)]:
		var cell: Vector2i = camp + step
		if World.walkable(cell) and World.zone_at(cell).is_empty() and not Nav.grid().is_point_solid(cell):
			var way: Array[Vector2i] = Nav.route(cell, camp)
			if not way.is_empty() and way.size() <= CAMP_DISTANCE * 2:
				return cell
	return Vector2i(-1, -1)
