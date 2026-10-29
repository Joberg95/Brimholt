extends RefCounted
## A player's professions (plan 48): skill levels, the work in hand, and the crafting pace. Owned by
## the professions system (game/core/systems/professions.gd); skills are saved with the character.

## Profession -> [level, experience toward the next level]; untrained professions are absent (level 1).
var skills: Dictionary = {}
## The node being worked: {cell, profession, from (where the player stood), until}, or {}.
var gathering: Dictionary = {}
## When the next craft may start.
var next_craft: float = 0.0


func _init(now: float = 0.0) -> void:
	next_craft = now
