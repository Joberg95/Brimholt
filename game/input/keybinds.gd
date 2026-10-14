extends RefCounted
## Rebindable controls. Every action has up to two keys (primary and secondary), matched by
## physical key position so layouts such as Swedish or AZERTY keep the same hand placement.
## Bindings are saved per user in user://keybinds.cfg.

const Spells = preload("res://game/data/spells.gd")
const PATH: String = "user://keybinds.cfg"
const SLOTS: int = 9
## Action id -> [label, primary default, secondary default]; KEY_NONE means unbound.
const DEFAULTS: Dictionary = {
	"move_up": ["Move up", KEY_W, KEY_UP],
	"move_down": ["Move down", KEY_S, KEY_DOWN],
	"move_left": ["Move left", KEY_A, KEY_LEFT],
	"move_right": ["Move right", KEY_D, KEY_RIGHT],
	"pick_up": ["Pick up", KEY_G, KEY_NONE],
	"gather": ["Gather", KEY_F, KEY_NONE],
	"target_nearest": ["Target nearest", KEY_SPACE, KEY_NONE],
	"world_map": ["World map", KEY_M, KEY_NONE],
	"quest_list": ["Quest list", KEY_L, KEY_NONE],
	"spell_book": ["Spell book", KEY_B, KEY_NONE],
	"character": ["Character", KEY_C, KEY_NONE],
	"lexicon": ["Lexicon", KEY_K, KEY_NONE],
	"professions": ["Professions", KEY_P, KEY_NONE],
	"party": ["Party", KEY_O, KEY_NONE],
	"health_potion": ["Health potion", KEY_Q, KEY_NONE],
	"mana_potion": ["Mana potion", KEY_E, KEY_NONE],
	"slot_1": ["Action bar 1", KEY_1, KEY_NONE],
	"slot_2": ["Action bar 2", KEY_2, KEY_NONE],
	"slot_3": ["Action bar 3", KEY_3, KEY_NONE],
	"slot_4": ["Action bar 4", KEY_4, KEY_NONE],
	"slot_5": ["Action bar 5", KEY_5, KEY_NONE],
	"slot_6": ["Action bar 6", KEY_6, KEY_NONE],
	"slot_7": ["Action bar 7", KEY_7, KEY_NONE],
	"slot_8": ["Action bar 8", KEY_8, KEY_NONE],
	"slot_9": ["Action bar 9", KEY_9, KEY_NONE],
}
## Escape always closes menus and cannot be bound.
const RESERVED: Array[Key] = [KEY_ESCAPE]
## The action bar holds spells only, stored as "spell:<id>"; "" is an empty slot. Other
## actions (target nearest, pick up, gather, world map, quest list, spell book, character, lexicon, professions, party, potions) have their own key bindings above.
const DEFAULT_BAR: Array[String] = ["", "", "", "", "", "", "", "", ""]

## Action id -> [primary, secondary] physical keycodes.
var keys: Dictionary = {}
## Nine action-bar entries: "" or "spell:<id>".
var bar: Array[String] = []
var path: String = PATH
## False keeps the defaults and never reads or writes `path` (tests: the player's own bindings stay untouched).
var persistent: bool = true


func _init(config_path: String = PATH) -> void:
	path = config_path
	reset()


func reset() -> void:
	keys.clear()
	for action: String in DEFAULTS:
		keys[action] = [DEFAULTS[action][1], DEFAULTS[action][2]]
	bar = DEFAULT_BAR.duplicate()


## The action bound to a physical key, or "".
func action_for(key: Key) -> String:
	if key == KEY_NONE:
		return ""
	for action: String in keys:
		if key in keys[action]:
			return action
	return ""


func is_held(action: String) -> bool:
	for key: Key in keys.get(action, []):
		if key != KEY_NONE and Input.is_physical_key_pressed(key):
			return true
	return false


## Binds a key; any other binding of the same key is cleared. Returns false for reserved keys.
func bind(action: String, index: int, key: Key) -> bool:
	if not keys.has(action) or index < 0 or index > 1 or key in RESERVED:
		return false
	if key != KEY_NONE:
		for other: String in keys:
			for slot: int in 2:
				if keys[other][slot] == key:
					keys[other][slot] = KEY_NONE
	keys[action][index] = key
	return true


static func valid_bar_entry(entry: String) -> bool:
	return entry.is_empty() or (entry.begins_with("spell:") and Spells.SPELLS.has(entry.trim_prefix("spell:")))


func set_bar(slot: int, entry: String) -> bool:
	if slot < 0 or slot >= SLOTS or not valid_bar_entry(entry):
		return false
	bar[slot] = entry
	return true


static func key_name(key: Key) -> String:
	if key == KEY_NONE:
		return "—"
	var shown: Key = key
	# Show the key printed on this keyboard layout; headless servers have no layout.
	if DisplayServer.get_name() != "headless":
		shown = DisplayServer.keyboard_get_keycode_from_physical(key)
	return OS.get_keycode_string(shown if shown != KEY_NONE else key)


func label(action: String) -> String:
	var names: PackedStringArray = []
	for key: Key in keys.get(action, []):
		if key != KEY_NONE:
			names.append(key_name(key))
	return " / ".join(names)


func save() -> Error:
	if not persistent:
		return OK
	var config := ConfigFile.new()
	for action: String in keys:
		config.set_value("keys", action, keys[action])
	config.set_value("bar", "slots", bar)
	return config.save(path)


## Loads saved bindings over the defaults, ignoring unknown actions and malformed values.
func load_saved() -> void:
	if not persistent:
		return
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	reset()
	for action: String in DEFAULTS:
		if not config.has_section_key("keys", action):
			continue
		var saved: Variant = config.get_value("keys", action)
		if typeof(saved) == TYPE_ARRAY and saved.size() == 2:
			for index: int in 2:
				if typeof(saved[index]) == TYPE_INT and saved[index] not in RESERVED:
					keys[action][index] = saved[index]
	var saved_bar: Variant = config.get_value("bar", "slots") if config.has_section_key("bar", "slots") else null
	if typeof(saved_bar) == TYPE_ARRAY and saved_bar.size() == SLOTS:
		for slot: int in SLOTS:
			if typeof(saved_bar[slot]) == TYPE_STRING and valid_bar_entry(saved_bar[slot]):
				bar[slot] = saved_bar[slot]
	# A hand-edited file could bind one key twice; keep the first binding only.
	var seen: Dictionary = {}
	for action: String in keys:
		for index: int in 2:
			var key: Key = keys[action][index]
			if key != KEY_NONE and seen.has(key):
				keys[action][index] = KEY_NONE
			seen[key] = true
