extends RefCounted
## How this peer shows a combat event (plan 48): floating numbers, loot text, missiles, spell areas,
## the attacker's swing, and particle bursts. Presentation only: it adds to game.client.effects and
## the world view's particles, never to the game state.

const World = preload("res://game/core/world.gd")
const Combat = preload("res://game/core/combat.gd")

## How long a kill's green loot text stays over the body.
const LOOT_TEXT_SECONDS: float = 4.0
## Floating-number text and colour by hit style.
const STYLE_COLORS: Dictionary = {
	"damage": Color("#ff4a3a"), "critical": Color("#ffa030"), "heal": Color("#6ae07a"),
	"experience": Color("#f4f4f4"), "mana": Color("#6aa8ff"), "ward": Color("#6aa8ff"),
}

## The main node (game/main.gd).
var game: Node


func _init(main: Node) -> void:
	game = main


static func _map_point(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * World.TILE_SIZE


static func _style_text(style: String, amount: int) -> String:
	match style:
		"critical":
			return "%d!" % amount
		"heal", "mana":
			return "+%d" % amount
		"experience":
			return "%d xp" % amount
		"ward":
			return "-%d" % amount
	return str(amount)


func show(event: Dictionary) -> void:
	var client: RefCounted = game.client
	var born: float = Time.get_ticks_msec() / 1000.0
	match event.get("kind", ""):
		"hit":
			var view: Dictionary = client.creature_view(event["target"])
			if view.is_empty() or (event["amount"] <= 0 and event["style"] != "damage"):
				return
			var style: String = event["style"] if STYLE_COLORS.has(event["style"]) else "damage"
			var color: Color = STYLE_COLORS[style]
			var at: Vector2 = (view["visual"] + Vector2(0.5, 0.5)) * World.TILE_SIZE
			if game.game_menu == null or game.game_menu.settings.get("damage_numbers", true):
				client.effects.append({"kind": "text", "pos": at, "text": _style_text(style, event["amount"]), "color": color,
					"born": born, "big": event["style"] == "critical"})
			var attacker: Dictionary = client.creature_view(int(event.get("source", 0)))
			if not attacker.is_empty() and event["style"] in ["damage", "critical"]:
				# Presentation only: the attacker swings toward the target; its real facing is unchanged.
				attacker["attack_born"] = born
				attacker["attack_facing"] = Combat.facing_toward(Vector2i(attacker["visual"].round()), event["cell"])
			if event["style"] in ["damage", "critical"] and event["amount"] > 0:
				game._world_view.fx.burst("critical" if event["style"] == "critical" else "hit", at + Vector2(0, -8), color)
			elif event["style"] in ["heal", "mana"]:
				game._world_view.fx.burst("heal", at, color)
		"loot":
			var over: Vector2 = _map_point(event["cell"])
			client.effects.append({"kind": "loot", "pos": over, "text": event["text"], "born": born, "life": LOOT_TEXT_SECONDS})
			if event.has("label"):
				client.effects.append({"kind": "label", "pos": over, "text": event["label"][0], "color": event["label"][1],
					"born": born, "life": 2.5})
		"missile":
			_missile(event, born)
		"area":
			client.effects.append({"kind": "area", "cells": event["cells"], "color": event["color"], "born": born,
				"element": event.get("element", ""), "life": maxf(1.1, float(event.get("life", 0.0)))})
			game._world_view.fx.area(event["cells"], event["color"])


## A missile flies to its target; the spell's impact plays on the target's tile when it lands (at
## once for a melee strike, which does not fly).
func _missile(event: Dictionary, born: float) -> void:
	var element: String = event.get("element", "")
	game.client.effects.append({"kind": "missile", "from": _map_point(event["from"]), "to": _map_point(event["to"]),
		"color": event["color"], "born": born, "element": element})
	var landing: Vector2 = _map_point(event["to"])
	var tint: Color = event["color"]
	var target: Vector2i = event["to"]
	var lands: float = 0.0 if element == "slash" else 0.25
	var impact: Callable = func() -> void:
		if game._world_view == null:
			return
		game._world_view.fx.burst("impact", landing, tint)
		if not element.is_empty():
			game.client.effects.append({"kind": "area", "cells": [target], "color": tint, "born": Time.get_ticks_msec() / 1000.0,
				"element": element})
	if lands <= 0.0:
		impact.call()
	else:
		game.get_tree().create_timer(lands).timeout.connect(impact)
