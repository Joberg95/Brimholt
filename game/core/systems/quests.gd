extends RefCounted
## Quests (plan 48): hunting tasks (accepting, counting kills, turning in for rewards and bigger
## packs), boss trophies and the relics they buy at the relic keepers, and the bosses slain. Owns
## the "quests" component (game/core/components/quests.gd). Combat (held weakly: it owns this system)
## grants the experience, spills what does not fit, rolls rare rewards, and raises titles.

const World = preload("res://game/core/world.gd")
const WorldMap = preload("res://game/world_map/world_map.gd")
const Combat = preload("res://game/core/combat.gd")
const Balance = preload("res://game/data/balance.gd")
const Quests = preload("res://game/data/quests.gd")
const Monsters = preload("res://game/data/monsters.gd")
const Caves = preload("res://game/data/caves.gd")
const QuestState = preload("res://game/core/components/quests.gd")

## The component this system owns.
const COMPONENT: String = "quests"
## A boss's trophies go only to fighters alive and this close to it when it falls (award_trophies).
const TROPHY_RADIUS: int = 15
const CHOOSE_CLASS_FIRST: String = "Choose your class first: pass the adventurer's trial, then see a trainer in Cinder Crossing's training hall"

var world: RefCounted
var _combat: WeakRef


func _init(owner: RefCounted, rules: RefCounted) -> void:
	world = owner
	_combat = weakref(rules)


## A player's quests (game/core/components/quests.gd).
func of(id: int) -> QuestState:
	return world.store.get_record(id, COMPONENT)


## Bots replay tasks: once a band has done everything that fits, its record of done tasks is cleared.
func replay(id: int) -> void:
	of(id).done_tasks.clear()


## What the task rules (World.task_open, next_task) read of a player: level, vocation, and quests.
func view(id: int) -> Dictionary:
	var player: Dictionary = world.players[id]
	return {"level": player["level"], "vocation": player["vocation"], "tasks": of(id).tasks, "done_tasks": of(id).done_tasks}


## Counts a kill toward the credited players' tasks; a task bound to a cave ("cave") counts only
## kills at `at` inside it.
func credit_tasks(kind: String, credited: Array[int], events: Array, at: Vector2i = Vector2i(-1, -1)) -> void:
	for id: int in credited:
		var tasks: Dictionary = of(id).tasks
		for task: String in tasks:
			var definition: Dictionary = Quests.TASKS[task]
			if definition.has("cave") and Caves.at(at) != definition["cave"]:
				continue
			if Quests.counts(task, kind) and tasks[task] < definition["count"]:
				tasks[task] += 1
				var done: bool = tasks[task] == definition["count"]
				events.append({"kind": "message", "id": id, "text": "%s: %d/%d%s" % [definition["title"], tasks[task],
					definition["count"], ". Return to the quest giver." if done else ""]})
				events.append({"kind": "player", "id": id})


## Everyone who took part in the fight and is still in it when the boss falls earns one trophy:
## players who damaged the boss, players it hit (tanks), and players who healed any of them, if
## they are alive and within TROPHY_RADIUS of it. Standing nearby is not enough, and neither is
## having fought and died: a raid that wipes the raid fighting a boss and finishes it takes the
## trophies (the bosses stand in open PvP zones).
func award_trophies(boss: String, fought: Dictionary, at: Vector2i, events: Array) -> void:
	var name: String = Monsters.MONSTERS[boss]["name"]
	for id: int in fought:
		if not world.players.has(id) or world.players[id]["health"] <= 0 or Combat.distance(world.players[id]["cell"], at) > TROPHY_RADIUS:
			continue
		var quests: QuestState = of(id)
		quests.trophies[boss] = quests.trophies.get(boss, 0) + 1
		quests.slain[boss] = true
		events.append({"kind": "message", "id": id, "text": "You helped slay %s. Claim a relic from %s." % [name, relic_keeper_text(boss)]})
		events.append({"kind": "player", "id": id})
		(_combat.get_ref() as RefCounted).check_title(id, events)


## Who trades `boss`'s trophies for relics, for messages ("Ysolde in Reedmere").
static func relic_keeper_text(boss: String) -> String:
	for id: String in WorldMap.QUEST_GIVERS:
		if WorldMap.QUEST_GIVERS[id]["boss"] == boss:
			return "%s in %s" % [WorldMap.QUEST_GIVERS[id]["name"], WorldMap.QUEST_GIVERS[id]["place"]]
	return "the relic keepers"


## The boss whose quest rewards a relic, or "".
static func relic_boss(relic: String) -> String:
	for boss: String in Monsters.MONSTERS:
		if relic in Monsters.MONSTERS[boss].get("relics", []):
			return boss
	return ""


## Trades one of the boss's trophies for a relic, in range of a quest giver, into the backpack.
func claim_relic(id: int, npc: Variant, relic: Variant, _now: float) -> Dictionary:
	if not world.players.has(id):
		return {"ok": false, "reason": "Unknown player", "events": []}
	if typeof(npc) != TYPE_STRING or not WorldMap.QUEST_GIVERS.has(npc) or WorldMap.QUEST_GIVERS[npc]["boss"].is_empty():
		return {"ok": false, "reason": "Unknown quest giver", "events": []}
	var player: Dictionary = world.players[id]
	var keeper: Dictionary = WorldMap.QUEST_GIVERS[npc]
	if not World.in_talk_range(player["cell"], keeper["cell"]):
		return {"ok": false, "reason": "Walk closer to %s" % keeper["name"], "events": []}
	var boss: String = relic_boss(relic) if typeof(relic) == TYPE_STRING else ""
	if boss.is_empty():
		return {"ok": false, "reason": "Unknown relic", "events": []}
	if boss != keeper["boss"]:
		return {"ok": false, "reason": "%s only keeps %s's relics; see %s" % [keeper["name"],
			Monsters.MONSTERS[keeper["boss"]]["name"], relic_keeper_text(boss)], "events": []}
	var quests: QuestState = of(id)
	if quests.trophies.get(boss, 0) <= 0:
		return {"ok": false, "reason": "Slay %s first" % Monsters.MONSTERS[boss]["name"], "events": []}
	var slot: int = player["backpack"].find("")
	if slot < 0:
		return {"ok": false, "reason": "Your backpack is full", "events": []}
	quests.trophies[boss] -= 1
	if quests.trophies[boss] == 0:
		quests.trophies.erase(boss)
	player["backpack"][slot] = relic
	var events: Array = [{"kind": "player", "id": id},
		{"kind": "message", "id": id, "text": "%s hands you the %s." % [keeper["name"], World.ITEMS[relic]["name"]]}]
	return {"ok": true, "events": events}


## Accepts ("accept") or turns in ("complete") the hunting task of a quest giver in range.
## Turning in a finished task replaces your pack with the next, bigger one.
func task_action(id: int, npc: Variant, task: Variant, action: Variant, _now: float) -> Dictionary:
	if not world.players.has(id):
		return {"ok": false, "reason": "Unknown player", "events": []}
	var player: Dictionary = world.players[id]
	if not World.serves(npc, "quests", player["cell"]) or WorldMap.QUEST_GIVERS[npc]["tasks"].is_empty():
		return {"ok": false, "reason": "Walk closer to a quest giver", "events": []}
	if typeof(task) != TYPE_STRING or task not in WorldMap.QUEST_GIVERS[npc]["tasks"]:
		return {"ok": false, "reason": "%s has no such task" % WorldMap.QUEST_GIVERS[npc]["name"], "events": []}
	var definition: Dictionary = Quests.TASKS[task]
	var giver: String = WorldMap.QUEST_GIVERS[npc]["name"]
	var quests: QuestState = of(id)
	if quests.done_tasks.has(task):
		return {"ok": false, "reason": "You already finished %s" % definition["title"], "events": []}
	var target: String = Quests.target_name(task)
	var text: String = ""
	var events: Array = [{"kind": "player", "id": id}]
	match action:
		"accept":
			if quests.tasks.has(task):
				return {"ok": false, "reason": "You are already on that task", "events": []}
			var requires: String = definition.get("requires", "")
			if not requires.is_empty() and not quests.done_tasks.has(requires):
				return {"ok": false, "reason": "Finish %s first" % Quests.TASKS[requires]["title"], "events": []}
			if not World.task_open(task, view(id)):
				return {"ok": false, "reason": CHOOSE_CLASS_FIRST if player["vocation"] == Balance.ADVENTURER
					else "That task is for Adventurers", "events": []}
			quests.tasks[task] = 0
			text = "%s: slay %s, then return to %s." % [definition["title"],
				target if definition["count"] == 1 else "%d %s" % [definition["count"], target], giver]
		"complete":
			if quests.tasks.get(task, 0) < definition["count"]:
				return {"ok": false, "reason": "Slay %s first" % (target if definition["count"] == 1
					else "%d %s" % [definition["count"], target]), "events": []}
			var items: Array = World.task_items(task, player["vocation"])
			# A pack task's supplies go into the pack it gives: the backpack as it will be once worn.
			var pack: String = "" if definition["reward"] == "experience" else Quests.next_pack(player["equipment"].get("bag", ""))
			var room: Array = player["backpack"].duplicate()
			if not pack.is_empty():
				var before: int = World.main_size(player)
				var grown: int = mini(World.BACKPACK_MAX, World.BACKPACK_SIZE + int(World.ITEMS[pack].get("slots", 0))) - before
				for added: int in maxi(0, grown):
					room.insert(before, "")
			# Gear and trophies need backpack room; potions and food that do not fit go to the ground
			# at your feet. A rare roll needs a slot ready for its prize, whether or not it comes.
			var needed: Array = items.filter(func(entry: Array) -> bool: return not _supply(entry[0]))
			var supplies: Array = items.filter(func(entry: Array) -> bool: return _supply(entry[0]))
			var rare: Dictionary = definition.get("rare", {})
			if not rare.is_empty() and World.with_items(room, needed + [[rare["items"][0], 1]]).is_empty():
				return {"ok": false, "reason": "Make room in your backpack for the reward (%d free slots)" % (needed.size() + 1),
					"events": []}
			var combat: RefCounted = _combat.get_ref()
			if not rare.is_empty() and combat.rng.randf() < float(rare["chance"]):
				var prize: Array = [rare["items"][combat.rng.randi_range(0, rare["items"].size() - 1)], 1]
				needed.append(prize)
				items.append(prize)
			var packed: Array = World.with_items(room, needed) if not needed.is_empty() else room
			if packed.is_empty():
				return {"ok": false, "reason": "Make room in your backpack for the reward (%d free slots)" % needed.size(),
					"events": []}
			var left: Array[String] = []
			for entry: Array in supplies:
				var fitted: Array = World.with_items(packed, [entry])
				if fitted.is_empty():
					left.append(World.make_entry(entry[0], entry[1]))
				else:
					packed = fitted
			quests.tasks.erase(task)
			quests.done_tasks[task] = true
			if not pack.is_empty():
				world.wear_pack(id, pack)
			# Filled in place: the pack was worn on this same array.
			(player["backpack"] as Array).assign(packed)
			if not left.is_empty():
				var dropped: Array[Vector2i] = combat.spill(player["cell"], left)
				if not dropped.is_empty():
					events.append({"kind": "ground", "cells": dropped})
			if definition["reward"] == "experience":
				var reward: Dictionary = Quests.reward(task)
				player["gold"] += reward["gold"]
				text = "%s rewards you with %d gold%s." % [giver, reward["gold"], World.items_text(items)]
				combat.grant_experience(id, reward["experience"], events)
			else:
				if pack.is_empty():
					text = "%s thanks you. Your pack is already the largest there is." % giver
				else:
					text = "%s gives you a %s: %d backpack slots." % [giver, World.ITEMS[pack]["name"], World.main_size(player)]
				if not items.is_empty():
					text += " Supplies: %s." % World.items_text(items).substr(2)
			if not left.is_empty():
				text += " Your backpack is full, so the rest lies at your feet."
		_:
			return {"ok": false, "reason": "Unknown task request", "events": []}
	if action == "complete":
		text += next_task_hint(id, npc)
	events.append({"kind": "message", "id": id, "text": text})
	if action == "complete":
		(_combat.get_ref() as RefCounted).check_title(id, events)
	return {"ok": true, "events": events}


## Whether a reward item is a supply (a potion or food: Quests.supplies) that may go to the ground
## when the backpack is full.
static func _supply(kind: String) -> bool:
	return World.ITEMS[kind].has("drink") or World.ITEMS[kind].has("eat")


## " Next: ..." pointing to the task World.next_task suggests, when another giver offers it.
func next_task_hint(id: int, current_giver: String) -> String:
	var next: String = World.next_task(view(id))
	if next.is_empty() or Quests.TASKS[next]["giver"] == current_giver:
		return ""
	var giver: Dictionary = WorldMap.QUEST_GIVERS[Quests.TASKS[next]["giver"]]
	var band: Vector2i = World.task_levels(next)
	return " Next: %s in %s has work for levels %d-%d." % [giver["name"], giver["place"], band.x, band.y]
