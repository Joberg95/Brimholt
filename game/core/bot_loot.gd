extends RefCounted
## What player bots (game/core/bots.gd) do with loot: collect the stacks their own group earned
## (Combat.loot_claims) and, once their backpack is nearly full, sell at a vendor. Everything goes
## through the rules players use: World.move_item picks up (reach, room, cooldown, bound items) and
## Economy.sell sells (talking range, what vendors buy), so a bot can never do more than a player.
##
## Who loots: every bot but companions and training dummies. A bot takes only stacks whose kill
## credited it or its party and no human player: what a person earned waits for that person (and
## companions, who always share their leader's kills, never take it). With no room in the
## backpack, loot stays on the ground for anyone.
##
## Who sells: roaming bots (hunters, PvP bots, rival band leaders) head for the nearest vendor once
## anyone in their bot group has at most SELL_WHEN_FREE free backpack slots and something to sell,
## sell everything a vendor buys (never potions or bound items), and go back to work; a band's
## members follow their leader into the shop and sell there.
##
## Per-bot state lives in the bot's record (Bots.bots[id]), cleared when it is restored:
##   "loot"  {cell, since}  the stack being collected
##   "skip"  {cell: until}  stacks given up on (unreachable) while their claim lasts
##   "trip"  {vendor, state, until}  a selling trip: "go" to the counter, "sell", "back" to the post

const World = preload("res://game/core/world.gd")
const Combat = preload("res://game/core/combat.gd")
const Economy = preload("res://game/core/economy.gd")

## Bots collect claimed stacks within LOOT_RADIUS tiles, and give up on one they have not taken
## anything from for GIVE_UP_SECONDS (out of reach behind water or rock).
const LOOT_RADIUS: int = 5
const GIVE_UP_SECONDS: float = 8.0
## A trip starts when a group member has at most SELL_WHEN_FREE free backpack slots, and is
## abandoned after TRIP_SECONDS (a vendor that cannot be reached).
const SELL_WHEN_FREE: int = 1
const TRIP_SECONDS: float = 240.0
const STANCES_THAT_LOOT: Array[String] = ["hunter", "pvp", "rival"]
const NO_CELL := Vector2i(-1000000, -1000000)

var world: World
var combat: Combat
var economy: Economy
## The Bots brain, held weakly: Bots owns this object (a strong reference back would leak both).
var brain: RefCounted:
	get:
		return _brain.get_ref() if _brain != null else null
var _brain: WeakRef
## Vendor NPC ids on the overworld, found once.
static var _vendors: Array[String] = []


func _init(owner: RefCounted) -> void:
	_brain = weakref(owner)
	world = owner.world
	combat = owner.combat
	economy = Economy.new(world)


## Whether a bot's stance collects and sells loot.
static func loots(bot: Dictionary) -> bool:
	return bot["stance"] in STANCES_THAT_LOOT


## Forgets a bot's loot errands (on restore, after death or a jump home).
static func reset(bot: Dictionary) -> void:
	bot["loot"] = {}
	bot["skip"] = {}
	bot["trip"] = {}


# ---------------------------------------------------------------- collecting

## Works on the nearest stack the bot's group earned: steps toward it, or picks up its top entry.
## Returns whether the bot is busy with loot (false: nothing to collect).
func collect(id: int, now: float, events: Array) -> bool:
	var bot: Dictionary = brain.bots[id]
	if not loots(bot):
		return false
	var player: Dictionary = world.players[id]
	var cell: Vector2i = choose_stack(id, now)
	if cell == NO_CELL:
		bot["loot"] = {}
		return false
	var aim: Dictionary = bot.get("loot", {})
	if aim.get("cell", NO_CELL) != cell:
		aim = {"cell": cell, "since": now}
		bot["loot"] = aim
	elif now - float(aim["since"]) > GIVE_UP_SECONDS:
		bot.get_or_add("skip", {})[cell] = float(combat.loot_claims[cell]["until"])
		bot["loot"] = {}
		return false
	if Combat.distance(player["cell"], cell) <= 1:
		var taken: Dictionary = world.move_item(id, {"type": "ground", "cell": cell}, {"type": "backpack"}, now)
		if taken["ok"]:
			aim["since"] = now
			events.append({"kind": "ground", "cells": taken["ground"]})
			events.append({"kind": "player", "id": id})
		return true
	brain.step_toward(id, cell, now, events)
	return true


## The nearest claimed stack within LOOT_RADIUS that the bot's group earned, that is not given up
## on, and whose top entry fits in the bot's backpack; NO_CELL when there is none.
func choose_stack(id: int, now: float) -> Vector2i:
	var player: Dictionary = world.players[id]
	var own: Vector2i = player["cell"]
	var group: Array[int] = brain.party_of(id)
	var skip: Dictionary = brain.bots[id].get("skip", {})
	for cell: Vector2i in skip.keys():
		if float(skip[cell]) <= now:
			skip.erase(cell)
	var best: Vector2i = NO_CELL
	var nearest: int = LOOT_RADIUS + 1
	for cell: Vector2i in combat.loot_claims:
		var gap: int = Combat.distance(own, cell)
		if gap >= nearest or skip.has(cell) or not earned(combat.loot_claims[cell]["owners"], group):
			continue
		var stack: Array = world.ground.get(cell, [])
		if stack.is_empty() or not fits(player, stack.back()) or World.dungeon_at(cell) != World.dungeon_at(own):
			continue
		best = cell
		nearest = gap
	return best


## Whether loot credited to `owners` belongs to the bot group: one of them earned it, and no
## human player did.
func earned(owners: Dictionary, group: Array[int]) -> bool:
	var ours: bool = false
	for owner: int in owners:
		if world.players.has(owner) and not world.players[owner].get("bot", false):
			return false
		ours = ours or owner in group
	return ours


## Whether a ground entry can go into the player's backpack (gold always goes to the purse).
static func fits(player: Dictionary, entry: String) -> bool:
	var kind: String = World.kind_of(entry)
	if not World.ITEMS.has(kind):
		return false
	return World.ITEMS[kind].has("gold") or World.receiving_slot(player["backpack"], kind, World.count_of(entry)) >= 0


# ---------------------------------------------------------------- selling

## Runs a selling trip for a roaming bot, or lets a follower sell at a vendor it stands beside.
## Returns whether the bot is busy with a trip.
func sell(id: int, now: float, events: Array) -> bool:
	var bot: Dictionary = brain.bots[id]
	if not loots(bot):
		return false
	var player: Dictionary = world.players[id]
	if follower(id, bot):
		var near: String = World.npc_near(player["cell"], "trade")
		if not near.is_empty():
			sell_one(id, near, now, events)
		return false
	var trip: Dictionary = bot.get("trip", {})
	if trip.is_empty():
		if not wants_to_sell(id) or not World.dungeon_at(player["cell"]).is_empty():
			return false
		var vendor: String = nearest_vendor(player["cell"])
		if vendor.is_empty():
			return false
		trip = {"vendor": vendor, "state": "go", "until": now + TRIP_SECONDS}
		bot["trip"] = trip
	if now >= float(trip["until"]):
		bot["trip"] = {}
		return false
	var vendor_id: String = trip["vendor"]
	match trip["state"]:
		"go":
			if World.serves(vendor_id, "trade", player["cell"]):
				trip["state"] = "sell"
			else:
				brain.travel(id, counter(vendor_id), 0, now, events)
		"sell":
			if not sell_one(id, vendor_id, now, events) and not group_selling(id, vendor_id):
				# Rival leaders go back to their errand (run_plan heads for the camp again); the
				# others walk back to their post.
				if bot["stance"] == "rival":
					bot["trip"] = {}
					return false
				trip["state"] = "back"
		"back":
			if brain.travel(id, bot["post"], 1, now, events):
				bot["trip"] = {}
				return false
	return true


## Sells the first backpack stack a vendor buys. Returns whether anything is left to sell (true
## while the item cooldown runs); false when the bot carries nothing a vendor buys.
func sell_one(id: int, vendor: String, now: float, events: Array) -> bool:
	var player: Dictionary = world.players[id]
	var index: int = sellable_index(player)
	if index < 0:
		return false
	if now < player["next_item"]:
		return true
	var sold: Dictionary = economy.sell(id, vendor, index, now)
	if sold["ok"]:
		events.append({"kind": "player", "id": id})
	return sold["ok"]


## The first backpack index holding something a vendor buys, or -1.
static func sellable_index(player: Dictionary) -> int:
	var backpack: Array = player["backpack"]
	for index: int in backpack.size():
		if not backpack[index].is_empty() and Economy.sell_price(World.kind_of(backpack[index])) > 0:
			return index
	return -1


## Whether a bot of the group (its bot followers included) is nearly full and has something to sell.
func wants_to_sell(id: int) -> bool:
	for member: int in _bot_group(id):
		var player: Dictionary = world.players[member]
		if player["backpack"].count("") <= SELL_WHEN_FREE and sellable_index(player) >= 0:
			return true
	return false


## Whether a follower of the bot still has something to sell at this vendor (the leader waits).
func group_selling(id: int, vendor: String) -> bool:
	for member: int in _bot_group(id):
		if member != id and World.serves(vendor, "trade", world.players[member]["cell"]) \
				and sellable_index(world.players[member]) >= 0:
			return true
	return false


## The bot's party members who are bots (just itself outside a party).
func _bot_group(id: int) -> Array[int]:
	var result: Array[int] = []
	for member: int in brain.party_of(id):
		if brain.bots.has(member):
			result.append(member)
	return result


static func follower(id: int, bot: Dictionary) -> bool:
	return bot["leader"] != 0 and bot["leader"] != id


## The overworld vendor nearest to `cell`, or "".
static func nearest_vendor(cell: Vector2i) -> String:
	if _vendors.is_empty():
		for npc: String in World.TOWNSFOLK:
			if "trade" in World.TOWNSFOLK[npc]["services"] and World.dungeon_at(World.TOWNSFOLK[npc]["cell"]).is_empty():
				_vendors.append(npc)
	var best: String = ""
	var nearest: int = 1 << 30
	for npc: String in _vendors:
		var gap: int = Combat.distance(cell, World.TOWNSFOLK[npc]["cell"])
		if gap < nearest:
			best = npc
			nearest = gap
	return best


## The tile in front of a keeper's counter, inside their shop: where a customer stands.
static func counter(vendor: String) -> Vector2i:
	var keeper: Dictionary = World.npc(vendor)
	return keeper["cell"] + keeper["facing"]
