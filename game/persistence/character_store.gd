extends RefCounted
## Host-side character saves. Each character is one JSON file named after the SHA-256 of its
## owner's identity token (the token itself is never stored) and signed with HMAC-SHA256 using
## a random key kept beside the saves (host.key). Clients never send or receive save data:
## they only present their token when joining, and the host rebuilds the character from its
## own file. The signature catches edited, damaged, or swapped files; whoever can read
## host.key (the host's own OS account) can still forge saves, so a dedicated server on a
## machine no player controls is the only way to rule that out.
##
## Saved: vocation, level, experience, vitals, gold, bank, position, equipment, backpack,
## depot, boss trophies, town tasks, the endgame title and the final bosses slain, and skulls
## (as time remaining). Loading sanitizes every field against the current catalog, so old or
## hand-made data cannot create invalid items.

const World = preload("res://game/core/world.gd")
const Balance = preload("res://game/data/balance.gd")
const Monsters = preload("res://game/data/monsters.gd")
const Quests = preload("res://game/data/quests.gd")
const Combat = preload("res://game/core/combat.gd")
const Spells = preload("res://game/data/spells.gd")
const Professions = preload("res://game/data/professions.gd")

## Version 2 added armor types; version 1 saves still load and are migrated (_migrate_armor).
const VERSION: int = 2
const SUPPORTED_VERSIONS: Array[int] = [1, 2]
const DEFAULT_DIR: String = "user://saves"
## The host also saves everyone this often, so a crash loses at most this much progress.
const AUTOSAVE_SECONDS: float = 30.0

var dir: String
var _key: PackedByteArray = PackedByteArray()


func _init(path: String = DEFAULT_DIR) -> void:
	dir = path.trim_suffix("/")


## Creates the folders and the signing key. Returns "" or why the folder cannot be used.
func open() -> String:
	var error: Error = DirAccess.make_dir_recursive_absolute(dir + "/characters")
	if error != OK:
		return "Cannot create the save folder %s: %s" % [ProjectSettings.globalize_path(dir), error_string(error)]
	var key_path: String = dir + "/host.key"
	if FileAccess.file_exists(key_path):
		var text: String = FileAccess.get_file_as_string(key_path).strip_edges()
		if text.length() != 64 or text.hex_decode().size() != 32:
			return "The save signing key %s is damaged" % ProjectSettings.globalize_path(key_path)
		_key = text.hex_decode()
		return ""
	_key = Crypto.new().generate_random_bytes(32)
	var file := FileAccess.open(key_path, FileAccess.WRITE)
	if file == null:
		return "Cannot write the save signing key %s" % ProjectSettings.globalize_path(key_path)
	file.store_string(_key.hex_encode())
	file.close()
	return ""


## The save file name for an identity token.
static func account(token: String) -> String:
	return token.sha256_text()


func path_for(owner: String) -> String:
	return "%s/characters/%s.json" % [dir, owner]


## {"status": "new"} when there is no save, {"status": "ok", "data": {...}}, or
## {"status": "invalid", "reason": "..."} when the file is damaged or fails its signature.
func load_character(owner: String) -> Dictionary:
	var path: String = path_for(owner)
	if not FileAccess.file_exists(path):
		return {"status": "new", "data": {}}
	var envelope: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(envelope) != TYPE_DICTIONARY or typeof(envelope.get("body")) != TYPE_STRING \
			or typeof(envelope.get("signature")) != TYPE_STRING:
		return {"status": "invalid", "reason": "is damaged"}
	if envelope["signature"] != _sign(envelope["body"]):
		return {"status": "invalid", "reason": "failed its signature check (it was edited or made by another host)"}
	var body: Variant = JSON.parse_string(envelope["body"])
	if typeof(body) != TYPE_DICTIONARY or body.get("account") != owner:
		return {"status": "invalid", "reason": "belongs to another character"}
	if int(body.get("version", 0)) not in SUPPORTED_VERSIONS:
		return {"status": "invalid", "reason": "has unsupported save version %s" % body.get("version")}
	return {"status": "ok", "data": body}


## Writes a character atomically (a temporary file renamed over the save), keeping the previous
## save as <file>.bak.
func save_character(owner: String, data: Dictionary) -> bool:
	if _key.is_empty():
		return false
	var body: Dictionary = data.duplicate(true)
	body["account"] = owner
	body["version"] = VERSION
	body["saved_at"] = int(Time.get_unix_time_from_system())
	var text: String = JSON.stringify(body)
	var path: String = path_for(owner)
	var temporary: String = path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"body": text, "signature": _sign(text)}))
	file.close()
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(path + ".bak")
		DirAccess.rename_absolute(path, path + ".bak")
	return DirAccess.rename_absolute(temporary, path) == OK


func _sign(text: String) -> String:
	return Crypto.new().hmac_digest(HashingContext.HASH_SHA256, _key, text.to_utf8_buffer()).hex_encode()


## The saved part of a live player, as JSON-safe values.
static func capture(world: World, id: int, now: float) -> Dictionary:
	var player: Dictionary = world.players[id]
	var ages: Array[float] = []
	for time: float in player["unjustified"]:
		ages.append(maxf(0.0, now - time))
	return {
		"vocation": player["vocation"], "level": player["level"], "experience": player["experience"],
		"health": player["health"], "mana": player["mana"], "gold": player["gold"], "bank": player["bank"],
		"cell": [player["cell"].x, player["cell"].y],
		"equipment": player["equipment"].duplicate(), "bags": player["bags"].duplicate(), "backpack": player["backpack"].duplicate(),
		"depot": player["depot"].duplicate(), "trophies": player["trophies"].duplicate(),
		"title": player.get("title", 0), "slain": player.get("slain", {}).keys(),
		"tasks": player["tasks"].duplicate(), "done_tasks": player["done_tasks"].keys(),
		"spell_ranks": player["spell_ranks"].duplicate(),
		"skills": player["skills"].duplicate(true),
		"skull": player["skull"], "skull_left": maxf(0.0, player["skull_until"] - now) if not player["skull"].is_empty() else 0.0,
		"unjustified_ages": ages,
	}


## The saved vocation if it is valid, else "".
static func saved_vocation(data: Dictionary) -> String:
	var vocation: Variant = data.get("vocation")
	return vocation if Balance.is_vocation(vocation) else ""


## Applies a loaded save to a freshly added player (World.add_player with the saved vocation),
## keeping only values that are valid now. The saved tile is used when it is walkable and free.
## Before armor types every class shared the same helmets and armor: swap each piece of
## another type (worn, carried, or in the depot) for the same slot and tier of the player's own.
static func _migrate_armor(player: Dictionary) -> void:
	for slot: String in ["helmet", "armor", "legs", "boots"]:
		if player["equipment"].has(slot):
			player["equipment"][slot] = World.armor_counterpart(player["equipment"][slot], player["vocation"])
	for container: String in ["backpack", "depot"]:
		var slots: Array = player[container]
		for index: int in slots.size():
			if not String(slots[index]).is_empty():
				slots[index] = World.armor_counterpart(slots[index], player["vocation"])


static func restore(world: World, id: int, data: Dictionary, now: float) -> void:
	var player: Dictionary = world.players[id]
	player["level"] = clampi(_int(data.get("level"), 1), 1, Balance.MAX_LEVEL)
	var next: int = Balance.experience_to_next(player["level"])
	player["experience"] = clampi(_int(data.get("experience"), 0), 0, maxi(0, next - 1))
	player["gold"] = maxi(0, _int(data.get("gold"), 0))
	player["bank"] = maxi(0, _int(data.get("bank"), 0))
	player["equipment"].clear()
	var equipment: Variant = data.get("equipment")
	if typeof(equipment) == TYPE_DICTIONARY:
		for slot: String in World.SLOTS:
			var kind: Variant = equipment.get(slot)
			if typeof(kind) != TYPE_STRING or not World.fits(kind, slot):
				continue
			if slot == "bag":
				if kind in Quests.PACKS:
					world.wear_pack(id, kind)
			else:
				player["equipment"][slot] = kind
	# Worn bags first: their slots extend the backpack the saved entries are read into.
	var bags: Variant = data.get("bags")
	if typeof(bags) == TYPE_ARRAY:
		for bag: int in mini(bags.size(), World.BAG_SLOTS):
			if typeof(bags[bag]) == TYPE_STRING and World.is_bag(bags[bag]):
				world.wear_bag(id, bag, bags[bag])
	for container: String in ["backpack", "depot"]:
		var saved: Variant = data.get(container)
		var slots: Array = player[container]
		for index: int in slots.size():
			slots[index] = ""
			if typeof(saved) == TYPE_ARRAY and index < saved.size() and typeof(saved[index]) == TYPE_STRING \
					and valid_entry(saved[index]):
				slots[index] = saved[index]
	if _int(data.get("version"), VERSION) < 2:
		_migrate_armor(player)
	var trophies: Variant = data.get("trophies")
	if typeof(trophies) == TYPE_DICTIONARY:
		for boss: Variant in trophies:
			if typeof(boss) == TYPE_STRING and Monsters.MONSTERS.get(boss, {}).has("relics") and _int(trophies[boss], 0) > 0:
				player["trophies"][boss] = _int(trophies[boss], 0)
	player["title"] = clampi(_int(data.get("title"), 0), 0, 3)
	var slain: Variant = data.get("slain")
	if typeof(slain) == TYPE_ARRAY:
		for boss: Variant in slain:
			if typeof(boss) == TYPE_STRING and Monsters.MONSTERS.get(boss, {}).has("relics"):
				player["slain"][boss] = true
	var done: Variant = data.get("done_tasks")
	if typeof(done) == TYPE_ARRAY:
		for task: Variant in done:
			if typeof(task) == TYPE_STRING and Quests.TASKS.has(task):
				player["done_tasks"][task] = true
	var tasks: Variant = data.get("tasks")
	if typeof(tasks) == TYPE_DICTIONARY:
		for task: Variant in tasks:
			if typeof(task) == TYPE_STRING and Quests.TASKS.has(task) and not player["done_tasks"].has(task):
				player["tasks"][task] = clampi(_int(tasks[task], 0), 0, Quests.TASKS[task]["count"])
	var ranks: Variant = data.get("spell_ranks")
	if typeof(ranks) == TYPE_DICTIONARY:
		for spell: Variant in ranks:
			var rank: int = clampi(_int(ranks[spell], 1), 1, Spells.MAX_RANK)
			if typeof(spell) == TYPE_STRING and Spells.rankable(spell) and Spells.allows(spell, player["vocation"]) and rank > 1:
				player["spell_ranks"][spell] = rank
	var skills: Variant = data.get("skills")
	if typeof(skills) == TYPE_DICTIONARY:
		for profession: Variant in skills:
			var entry: Variant = skills[profession]
			if Professions.is_profession(profession) and typeof(entry) == TYPE_ARRAY and entry.size() == 2:
				var skill: int = clampi(_int(entry[0], 1), 1, Professions.SKILL_MAX)
				var progress: int = clampi(_int(entry[1], 0), 0, maxi(0, Professions.experience_to_next(skill) - 1))
				if skill > 1 or progress > 0:
					player["skills"][profession] = [skill, progress]
	var skull: Variant = data.get("skull")
	var left: float = _float(data.get("skull_left"))
	if skull in ["white", "red"] and left > 0.0:
		player["skull"] = skull
		player["skull_until"] = now + minf(left, Combat.RED_SKULL_SECONDS)
	var ages: Variant = data.get("unjustified_ages")
	if typeof(ages) == TYPE_ARRAY:
		for age: Variant in ages:
			if typeof(age) in [TYPE_INT, TYPE_FLOAT] and age >= 0.0 and age < Combat.UNJUSTIFIED_WINDOW_SECONDS:
				player["unjustified"].append(now - float(age))
	var cell: Variant = data.get("cell")
	if typeof(cell) == TYPE_ARRAY and cell.size() == 2 and typeof(cell[0]) in [TYPE_INT, TYPE_FLOAT] \
			and typeof(cell[1]) in [TYPE_INT, TYPE_FLOAT]:
		var saved_cell := Vector2i(int(cell[0]), int(cell[1]))
		if World.walkable(saved_cell) and not world.occupied(saved_cell, now, id):
			player["cell"] = saved_cell
			player["from"] = saved_cell
	var limits: Dictionary = world.player_stats(id)
	var health: int = _int(data.get("health"), 0)
	player["health"] = clampi(health, 1, limits["health"]) if health > 0 else limits["health"]
	player["mana"] = clampi(_int(data.get("mana"), limits["mana"]), 0, limits["mana"])


## A backpack or depot entry the current catalog accepts: a known carriable item (gold coins go
## to the purse) and, for stackables, a count from 1 to World.STACK_MAX.
static func valid_entry(entry: String) -> bool:
	if entry.is_empty():
		return true
	var kind: String = World.kind_of(entry)
	if not World.ITEMS.has(kind) or World.ITEMS[kind].has("gold") or World.ITEMS[kind]["slot"] == "bag":
		return false
	if not entry.contains("#"):
		return true
	var count: String = entry.get_slice("#", 1)
	return World.stackable(kind) and count.is_valid_int() and int(count) >= 2 and int(count) <= World.STACK_MAX \
		and entry == World.make_entry(kind, int(count))


static func _int(value: Variant, fallback: int) -> int:
	return int(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else fallback


static func _float(value: Variant) -> float:
	return float(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else 0.0
