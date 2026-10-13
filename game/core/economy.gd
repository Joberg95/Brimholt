extends RefCounted
## Town services on the host: vendors sell potions and levelling gear and buy loot; bankers
## keep a gold account (the depot's items move through World.move_item). Every request names
## an NPC the player must stand within World.TALK_RANGE of; the server checks the stock,
## prices, gold, and backpack room. Results are {ok, reason} or {ok, message}.

const World = preload("res://game/core/world.gd")

## Vendors stock every potion and the helmet, armor, weapon, and off-hand of each tier up to
## MAX_TIER: gear for levelling a new character. Better gear comes from monsters and quests.
const MAX_TIER: int = 10
const GEAR_SLOTS: Array[String] = ["helmet", "armor", "main_hand", "off_hand"]
## Most of one stackable a single purchase may buy (one backpack stack).
const BUY_MAX: int = 100

var world: World


func _init(owner: World) -> void:
	world = owner


## What every vendor sells, potions first, then gear by tier.
static func stock() -> Array[String]:
	var result: Array[String] = []
	for kind: String in World.ITEMS:
		if World.ITEMS[kind].has("drink"):
			result.append(kind)
	for kind: String in World.ITEMS:
		var item: Dictionary = World.ITEMS[kind]
		if item["slot"] in GEAR_SLOTS and item["level"] <= MAX_TIER and item.has("price") and not item.get("loot_only", false):
			result.append(kind)
	return result


## What a vendor pays for one of `kind`, or 0 when vendors will not buy it.
static func sell_price(kind: String) -> int:
	return int(World.ITEMS.get(kind, {}).get("sell", 0))


func buy(id: int, npc: Variant, kind: Variant, count: Variant, now: float) -> Dictionary:
	if not world.players.has(id):
		return _refuse("Unknown player")
	var player: Dictionary = world.players[id]
	if not World.serves(npc, "trade", player["cell"]):
		return _refuse("Walk closer to a vendor")
	if typeof(kind) != TYPE_STRING or kind not in stock():
		return _refuse("The vendor does not sell that")
	if typeof(count) != TYPE_INT or count < 1 or count > BUY_MAX or (count > 1 and not World.stackable(kind)):
		return _refuse("You cannot buy that many")
	if now < player["next_item"]:
		return _refuse("Item cooldown")
	var cost: int = World.ITEMS[kind]["price"] * count
	if player["gold"] < cost:
		return _refuse("You need %d gold" % cost)
	var slot: int = World.receiving_slot(player["backpack"], kind, count)
	if slot < 0:
		return _refuse("Your backpack is full")
	player["gold"] -= cost
	player["backpack"][slot] = World.make_entry(kind, World.count_of(player["backpack"][slot]) + count)
	player["next_item"] = now + World.ITEM_SECONDS
	return {"ok": true, "message": "You bought %s for %d gold." % [_amount(kind, count), cost]}


## Sells the backpack entry at `index` (a whole stack), or with index -1 every monster
## material in the backpack. Bound items and potions are never bought.
func sell(id: int, npc: Variant, index: Variant, now: float) -> Dictionary:
	if not world.players.has(id):
		return _refuse("Unknown player")
	var player: Dictionary = world.players[id]
	if not World.serves(npc, "trade", player["cell"]):
		return _refuse("Walk closer to a vendor")
	var backpack: Array = player["backpack"]
	if typeof(index) != TYPE_INT or index < -1 or index >= backpack.size():
		return _refuse("Unknown item location")
	if now < player["next_item"]:
		return _refuse("Item cooldown")
	var chosen: Array[int] = []
	if index >= 0:
		if backpack[index].is_empty():
			return _refuse("There is no item there")
		if sell_price(World.kind_of(backpack[index])) <= 0:
			return _refuse("The vendor will not buy the %s" % World.ITEMS[World.kind_of(backpack[index])]["name"])
		chosen.append(index)
	else:
		for slot: int in backpack.size():
			if World.ITEMS.get(World.kind_of(backpack[slot]), {}).has("value"):
				chosen.append(slot)
		if chosen.is_empty():
			return _refuse("You carry no monster materials")
	var earned: int = 0
	var sold: PackedStringArray = []
	for slot: int in chosen:
		var kind: String = World.kind_of(backpack[slot])
		earned += sell_price(kind) * World.count_of(backpack[slot])
		sold.append(_amount(kind, World.count_of(backpack[slot])))
		backpack[slot] = ""
	player["gold"] += earned
	player["next_item"] = now + World.ITEM_SECONDS
	var what: String = sold[0] if sold.size() == 1 else "%d stacks of materials" % sold.size()
	return {"ok": true, "message": "You sold %s for %d gold." % [what, earned]}


## Moves `amount` gold between the purse and the bank ("deposit" or "withdraw"). Banked gold is
## never lost on death.
func bank(id: int, npc: Variant, action: Variant, amount: Variant, now: float) -> Dictionary:
	if not world.players.has(id):
		return _refuse("Unknown player")
	var player: Dictionary = world.players[id]
	if not World.serves(npc, "bank", player["cell"]):
		return _refuse("Walk closer to a banker")
	if typeof(action) != TYPE_STRING or action not in ["deposit", "withdraw"]:
		return _refuse("Unknown bank request")
	if typeof(amount) != TYPE_INT or amount < 1:
		return _refuse("Choose an amount of gold")
	if now < player["next_item"]:
		return _refuse("Item cooldown")
	var source: String = "gold" if action == "deposit" else "bank"
	if player[source] < amount:
		return _refuse("You only have %d gold %s" % [player[source], "with you" if source == "gold" else "in the bank"])
	player[source] -= amount
	player["bank" if action == "deposit" else "gold"] += amount
	player["next_item"] = now + World.ITEM_SECONDS
	return {"ok": true, "message": "You %s %d gold. Balance: %d gold." % [
		"deposited" if action == "deposit" else "withdrew", amount, player["bank"]]}


static func _amount(kind: String, count: int) -> String:
	var name: String = World.ITEMS[kind]["name"]
	return "%d × %s" % [count, name] if World.stackable(kind) else "the " + name


func _refuse(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
