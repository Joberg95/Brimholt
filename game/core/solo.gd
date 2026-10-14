extends RefCounted
## Solo play on the host (the start screen's "Play solo"): a private world where your own
## companions (Bots "companion") complete a tank, healer, and damage group around your class,
## and two rival adventurer bands (Bots "rival") take tasks, hunt, level alongside you, and
## ambush your group when you enter a PvP zone. "Raid" fills your party to the ten-player raid
## the final bosses are balanced for (Balance.RAID), sending the rival bands home meanwhile to
## stay within World.MAX_PLAYERS; "Disband raid" sends the extra companions away again.
## Everything runs through game/core/bots.gd, so bots play by the same rules as players.
## Results are events like Combat.tick; {"kind": "bot_left", "id"} asks the host to drop a bot.

const World = preload("res://game/core/world.gd")
const Combat = preload("res://game/core/combat.gd")
const Balance = preload("res://game/data/balance.gd")
const Bots = preload("res://game/core/bots.gd")
const Nav = preload("res://game/core/nav.gd")

## Companions for each class: the other three, or (for an Adventurer) a tank, healer, and caster.
const COMPANIONS: Dictionary = {
	"knight": ["druid", "paladin", "sorcerer"], "paladin": ["knight", "druid", "sorcerer"],
	"sorcerer": ["knight", "druid", "paladin"], "druid": ["knight", "paladin", "sorcerer"],
	"adventurer": ["knight", "druid", "sorcerer"],
}
const COMPANION_NAMES: Dictionary = {
	"knight": ["Garrick", "Thora", "Bram"], "paladin": ["Wren", "Caelan", "Isolde"],
	"sorcerer": ["Maelis", "Orrin", "Sable"], "druid": ["Fenna", "Rowan", "Elowen"],
}
## Rival bands: a name, then [vocation, name, level offset from you] for the leader and members.
const BANDS: Array = [
	["the Ashen Hand", [["knight", "Varric", 1], ["sorcerer", "Ysmay", 1], ["druid", "Corvin", 1]]],
	["the Thornwardens", [["paladin", "Lirien", 2], ["knight", "Haldor", 2], ["druid", "Saskia", 2]]],
]
## Rivals go after you in PvP zones at your level, one band at a time, with a rest between.
const AMBUSH_SECONDS: float = 300.0
const AMBUSH_COOLDOWN: float = 240.0
const CHECK_SECONDS: float = 2.0
const CAMP_GAP: int = 7

var world: World
var combat: Combat
var bots: Bots
## The playing host.
var leader: int = 1
var raiding: bool = false
## Band index -> {leader: bot id (0 while away), members: [ids], rest_until}.
var bands: Dictionary = {}
var _next_check: float = 0.0


func _init(owner: World, fights: Combat, brains: Bots) -> void:
	world = owner
	combat = fights
	bots = brains


## Brings out your companions and the rival bands.
func start(id: int, now: float) -> Array:
	leader = id
	var events: Array = []
	var player: Dictionary = world.players[id]
	var vocation: String = player["vocation"]
	for index: int in COMPANIONS[vocation].size():
		var kind: String = COMPANIONS[vocation][index]
		_add_companion(kind, COMPANION_NAMES[kind][0], now, events)
	for band: int in BANDS.size():
		bands[band] = {"leader": 0, "members": [], "rest_until": 0.0}
		_send_band(band, now, events)
	return events


## Your companions (raid companions included), in the order they joined.
func companions() -> Array[int]:
	var result: Array[int] = []
	for id: int in bots.bots:
		if bots.bots[id]["stance"] == "companion":
			result.append(id)
	result.sort()
	return result


## Fills your party to Balance.RAID (on) or sends the extra companions home (off).
func raid(on: bool, now: float) -> Dictionary:
	var events: Array = []
	if on == raiding:
		return {"ok": false, "reason": "Your raid is already gathered" if on else "You are not leading a raid", "events": events}
	if on and world.players[leader]["level"] < Balance.MAX_LEVEL:
		return {"ok": false, "reason": "Raids are for level %d: the final bosses need a full raid at the top" % Balance.MAX_LEVEL,
			"events": events}
	raiding = on
	if on:
		for band: int in bands:
			_recall_band(band, events)
		var wanted: Dictionary = Balance.RAID.duplicate()
		for id: int in [leader] + companions():
			var vocation: String = world.players[id]["vocation"]
			if wanted.get(vocation, 0) > 0:
				wanted[vocation] -= 1
		for vocation: String in wanted:
			for count: int in wanted[vocation]:
				var names: Array = COMPANION_NAMES[vocation]
				_add_companion(vocation, names[(count + 1) % names.size()], now, events, true)
		events.append({"kind": "message", "id": leader, "text": "Your raid gathers: %d strong. Two warriors trade the boss with Challenge; stay near the druids." % (companions().size() + 1)})
	else:
		for id: int in companions():
			if bots.bots[id].get("raid", false):
				_drop(id, events)
		for band: int in bands:
			bands[band]["rest_until"] = now + AMBUSH_COOLDOWN
			_send_band(band, now, events)
		events.append({"kind": "message", "id": leader, "text": "Your raid disbands; your companions stay with you."})
	return {"ok": true, "events": events}


## Keeps rival bands at your level between errands and sends one after you in a PvP zone.
func tick(now: float) -> Array:
	var events: Array = []
	if now < _next_check or not world.players.has(leader):
		return events
	_next_check = now + CHECK_SECONDS
	for band: int in bands:
		var state: Dictionary = bands[band]
		if state["leader"] == 0 or not bots.bots.has(state["leader"]):
			continue
		var head: Dictionary = bots.bots[state["leader"]]
		if head["plan"].is_empty():
			_level_band(band, events)
	if combat.in_pvp_zone(leader) and not raiding:
		var busy: bool = bands.values().any(func(state: Dictionary) -> bool:
			return state["leader"] != 0 and bots.bots.has(state["leader"]) and bots.bots[state["leader"]]["plan"].get("state", "") == "ambush")
		for band: int in bands:
			var state: Dictionary = bands[band]
			if busy or state["leader"] == 0 or not bots.bots.has(state["leader"]) or now < state["rest_until"]:
				continue
			_level_band(band, events)
			_ambush(band, now, events)
			busy = true
	return events


# ---------------------------------------------------------------- helpers

func _add_companion(vocation: String, name: String, now: float, events: Array, for_raid: bool = false) -> void:
	var player: Dictionary = world.players[leader]
	var added: Dictionary = bots.add(vocation, player["level"], "companion", player["cell"], now,
		{"leader": leader, "name": name})
	if not added["ok"]:
		return
	bots.bots[added["id"]]["raid"] = for_raid
	bots.join_leader(added["id"], now, events)
	events.append({"kind": "player", "id": added["id"]})


## Puts a rival band in a town away from you, at its level.
func _send_band(band: int, now: float, events: Array) -> void:
	var state: Dictionary = bands[band]
	if state["leader"] != 0:
		return
	var home: Vector2i = _far_town(band)
	var members: Array = BANDS[band][1]
	var head: int = 0
	for index: int in members.size():
		var entry: Array = members[index]
		var added: Dictionary = bots.add(entry[0], _band_level(entry[2]), "rival", home, now,
			{"leader": head, "name": "%s of %s" % [entry[1], BANDS[band][0]]})
		if not added["ok"]:
			continue
		var id: int = added["id"]
		if head == 0:
			head = id
			bots.bots[id]["leader"] = id
		state["members"].append(id)
		events.append({"kind": "player", "id": id})
	state["leader"] = head
	for id: int in state["members"]:
		if id != head:
			bots.join_leader(id, now, events)


func _recall_band(band: int, events: Array) -> void:
	var state: Dictionary = bands[band]
	for id: int in state["members"]:
		_drop(id, events)
	state["members"] = []
	state["leader"] = 0


func _drop(id: int, events: Array) -> void:
	combat.leave_party(id, events)
	bots.remove(id)
	for other: int in world.players:
		if world.players[other]["target"] == id:
			world.players[other]["target"] = 0
			events.append({"kind": "player", "id": other})
	events.append({"kind": "bot_left", "id": id})


func _band_level(offset: int) -> int:
	var level: int = world.players[leader]["level"] if world.players.has(leader) else 1
	return clampi(level + offset, 1, Balance.MAX_LEVEL)


## Between errands, a band catches up with your level (they level as you do).
func _level_band(band: int, events: Array) -> void:
	var members: Array = BANDS[band][1]
	var state: Dictionary = bands[band]
	for index: int in state["members"].size():
		var id: int = state["members"][index]
		if not bots.bots.has(id):
			continue
		var level: int = _band_level(members[mini(index, members.size() - 1)][2])
		if bots.bots[id]["level"] != level:
			bots.bots[id]["level"] = level
			if world.players[id]["level"] != level:
				var player: Dictionary = world.players[id]
				player["level"] = level
				player["experience"] = 0
				player["equipment"] = Bots.gear(level, bots.bots[id]["vocation"])
				world.clamp_vitals(id)
				events.append({"kind": "player", "id": id})


## Sends a band to fight you in your PvP zone: they arrive out of sight inside the zone and close in.
func _ambush(band: int, now: float, events: Array) -> void:
	var state: Dictionary = bands[band]
	var head: int = state["leader"]
	var you: Vector2i = world.players[leader]["cell"]
	var zone: Dictionary = World.zone_at(you)
	var best := Vector2i(-1, -1)
	var rect: Rect2i = zone.get("rect", Rect2i())
	for distance: int in [Bots.SEEN_RADIUS + 4, Bots.SEEN_RADIUS + 2, Bots.SEEN_RADIUS + 1]:
		for step: int in 32:
			var angle: float = step * TAU / 32.0
			var cell: Vector2i = you + Vector2i(roundi(cos(angle) * distance), roundi(sin(angle) * distance))
			if best.x < 0 and rect.has_point(cell) and World.walkable(cell) and World.zone_at(cell) == zone \
					and not _near_camp(cell) and not Nav.route(cell, you).is_empty():
				best = cell
		if best.x >= 0:
			break
	if best.x < 0:
		return
	# The whole band arrives together, out of sight, and closes in.
	for id: int in state["members"]:
		if bots.bots.has(id) and not bots.seen(world.players[id]["cell"]):
			bots.jump(id, best, now, events)
	bots.bots[head]["plan"] = {"state": "ambush", "target": leader, "until": now + AMBUSH_SECONDS}
	state["rest_until"] = now + AMBUSH_SECONDS + AMBUSH_COOLDOWN
	events.append({"kind": "message", "id": leader, "text": "Rivals from %s are hunting you in %s!" % [BANDS[band][0], zone["name"]]})


## Whether a monster camp is within CAMP_GAP tiles: rivals arrive away from monsters.
static func _near_camp(cell: Vector2i) -> bool:
	for spawn: Dictionary in World.MONSTER_SPAWNS:
		if Combat.distance(spawn["cell"], cell) <= CAMP_GAP:
			return true
	return false


## A town far from you (towns are zones flagged "town"), different for each band.
func _far_town(band: int) -> Vector2i:
	var you: Vector2i = world.players[leader]["cell"] if world.players.has(leader) else World.SPAWNS[0]
	var towns: Array = World.ZONES.filter(func(zone: Dictionary) -> bool: return zone["town"])
	towns.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return Combat.distance(a["rect"].get_center(), you) > Combat.distance(b["rect"].get_center(), you))
	var town: Dictionary = towns[mini(band, towns.size() - 1)]
	var centre: Vector2i = town["rect"].get_center()
	for radius: int in range(0, 12):
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				var cell: Vector2i = centre + Vector2i(dx, dy)
				if World.walkable(cell) and not World.ROOM_AT.has(cell):
					return cell
	return centre
