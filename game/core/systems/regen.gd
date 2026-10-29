extends RefCounted
## Regeneration (plan 48): every REGEN_SECONDS a player regains health and mana, faster when resting
## (out of combat for RESTING_SECONDS) and much faster during a town rest; a meal and PvP healing
## scale it. Owns the "regen" component (game/core/components/regen.gd). Health and mana still live
## in the player's record until the attack and death rules move (then this raises an event instead).

const WorldMap = preload("res://game/world_map/world_map.gd")
const Regen = preload("res://game/core/components/regen.gd")

const COMPONENT: String = "regen"
const REGEN_SECONDS: float = 2.0
## Mana restored per 10 seconds, as a fraction of max mana.
const MANA_REGEN_FRACTION: float = 0.08
## Out of combat for this long, health and mana regenerate RESTING_MULTIPLIER times faster.
const RESTING_SECONDS: float = 8.0
const RESTING_MULTIPLIER: float = 3.0
## Town rest: in a town and missing health or mana, you regenerate TOWN_REST_MULTIPLIER times the
## base rate (about 25 s from empty to full) until you are full or leave; then it needs
## TOWN_REST_COOLDOWN before it starts again, so towns are not a free mid-fight heal.
const TOWN_REST_MULTIPLIER: float = 10.0
const TOWN_REST_COOLDOWN: float = 180.0

## The world (its players and component store), and combat (meals and PvP healing, read only), held
## weakly: combat owns this system, and a strong reference back would keep both alive forever.
var world: RefCounted
var _combat: WeakRef


func _init(owner: RefCounted, rules: RefCounted) -> void:
	world = owner
	_combat = weakref(rules)


## A player's regeneration state.
func of(id: int) -> Regen:
	return world.store.get_record(id, COMPONENT)


## Regenerates a player when it is time; appends "player" (changed) and "message" events.
func tick_player(id: int, now: float, events: Array) -> void:
	var regen: Regen = of(id)
	if now < regen.next_regen:
		return
	regen.next_regen = now + REGEN_SECONDS
	var player: Dictionary = world.players[id]
	var limits: Dictionary = world.player_stats(id)
	var before: Array = [player["health"], player["mana"]]
	var rate: float = REGEN_SECONDS / 10.0 * (RESTING_MULTIPLIER if resting(id, now) else 1.0)
	if _town_rest(id, regen, limits, now, events):
		rate = REGEN_SECONDS / 10.0 * TOWN_REST_MULTIPLIER
	var combat: RefCounted = _combat.get_ref()
	rate *= 1.0 + combat.meal_bonus(id, now)
	player["health"] = mini(limits["health"], player["health"] + maxi(1, roundi(limits["regen"] * rate * combat.healing_factor(id, now))))
	player["mana"] = mini(limits["mana"], player["mana"] + maxi(1, roundi(limits["mana"] * MANA_REGEN_FRACTION * rate)))
	if [player["health"], player["mana"]] != before:
		events.append({"kind": "player", "id": id})


## Whether a player is out of combat long enough to regenerate faster.
func resting(id: int, now: float) -> bool:
	return now - world.players[id].get("last_combat", -INF) >= RESTING_SECONDS


## Starts, keeps, or ends a player's town rest; returns whether it boosts this regeneration tick.
func _town_rest(id: int, regen: Regen, limits: Dictionary, now: float, events: Array) -> bool:
	var player: Dictionary = world.players[id]
	var in_town: bool = WorldMap.zone_at(player["cell"]).get("town", false)
	var missing: bool = player["health"] < limits["health"] or player["mana"] < limits["mana"]
	if regen.town_rest:
		if in_town and missing:
			return true
		regen.town_rest = false
		regen.town_rest_ready = now + TOWN_REST_COOLDOWN
		events.append({"kind": "player", "id": id})
		return false
	if in_town and missing and now >= regen.town_rest_ready:
		regen.town_rest = true
		events.append({"kind": "message", "id": id, "text": "You rest in town and recover quickly."})
		return true
	return false
