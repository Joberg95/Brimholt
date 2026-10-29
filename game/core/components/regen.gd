extends RefCounted
## A player's regeneration state (plan 48): when health and mana next regenerate, and town rest.
## Owned by the regen system (game/core/systems/regen.gd); read by the player's export.

## When health and mana next regenerate.
var next_regen: float = 0.0
## Whether a town rest is running (faster regeneration in a town until full).
var town_rest: bool = false
## When a new town rest may start (the cooldown after the last one).
var town_rest_ready: float = -INF


func _init(now: float = 0.0) -> void:
	next_regen = now
