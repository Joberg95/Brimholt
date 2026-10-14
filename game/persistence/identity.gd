extends RefCounted
## This computer's secret player identity: a random 256-bit token kept in user://identity.cfg
## (or identity-<profile>.cfg, for several players on one computer). Hosts store only its
## SHA-256, so the token is the key to your saved characters on every host you join: keep the
## file private, and copy it to play the same characters from another computer.
##
## Each profile is one character in the start menu. Its file also keeps a [character] summary
## (name, vocation, level, worn look, last played) that this computer writes from what the host
## sends back. It is only for the menu: hosts never read it, so it cannot change a character.

const FILE: String = "user://identity%s.cfg"


static func path_for(profile: String) -> String:
	return FILE % ("" if profile.is_empty() else "-" + profile)


## Profile names are letters, digits, "-" and "_" (they become part of a file name).
static func valid_profile(profile: String) -> bool:
	var pattern := RegEx.create_from_string("^[A-Za-z0-9_-]{1,32}$")
	return profile.is_empty() or pattern.search(profile) != null


static func valid_token(token: Variant) -> bool:
	if typeof(token) != TYPE_STRING or token.length() != 64:
		return false
	var pattern := RegEx.create_from_string("^[0-9a-f]{64}$")
	return pattern.search(token) != null


static func fresh() -> String:
	return Crypto.new().generate_random_bytes(32).hex_encode()


## The saved token for a profile, created on first use; "" if the file cannot be written.
static func load_or_create(profile: String = "") -> String:
	var path: String = path_for(profile)
	var config := ConfigFile.new()
	if config.load(path) == OK:
		var saved: Variant = config.get_value("identity", "token", "")
		if valid_token(saved):
			return saved
	var token: String = fresh()
	config.set_value("identity", "token", token)
	return token if config.save(path) == OK else ""


const MAX_NAME: int = 16
## Shown for a profile made before characters had names.
const UNNAMED: String = "Wanderer"
## The start menu's last chosen profile.
const SETTINGS: String = "user://start.cfg"


## Every character on this computer: [{profile, name, vocation, level, equipment, played}],
## most recently played first.
static func characters() -> Array:
	var result: Array = []
	for file: String in DirAccess.get_files_at("user://"):
		if not (file.begins_with("identity") and file.ends_with(".cfg")):
			continue
		var profile: String = file.trim_prefix("identity").trim_suffix(".cfg").trim_prefix("-")
		if file != "identity.cfg" and not file.begins_with("identity-") or not valid_profile(profile):
			continue
		var config := ConfigFile.new()
		if config.load(path_for(profile)) != OK or not valid_token(config.get_value("identity", "token", "")):
			continue
		result.append(summary(config, profile))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["played"] > b["played"] or a["played"] == b["played"] and a["name"] < b["name"])
	return result


static func summary(config: ConfigFile, profile: String) -> Dictionary:
	var equipment: Variant = config.get_value("character", "equipment", {})
	return {
		"profile": profile, "name": String(config.get_value("character", "name", UNNAMED)),
		"vocation": String(config.get_value("character", "vocation", "")), "level": int(config.get_value("character", "level", 0)),
		"equipment": equipment if typeof(equipment) == TYPE_DICTIONARY else {},
		"played": int(config.get_value("character", "played", 0)),
	}


## A display name: letters, digits, spaces, apostrophes, and hyphens, trimmed, 2 to MAX_NAME long.
static func clean_name(text: String) -> String:
	var kept: String = ""
	for character: String in text.strip_edges():
		if character == " " and kept.ends_with(" "):
			continue
		if character.is_valid_identifier() or character.is_valid_int() or character in " '-" \
				or character.unicode_at(0) > 127:
			kept += character
	kept = kept.strip_edges().left(MAX_NAME).strip_edges()
	return kept if kept.length() >= 2 else ""


## Makes a new character profile named `name`; returns its profile id ("" on failure).
static func create(name: String) -> String:
	var shown: String = clean_name(name)
	if shown.is_empty():
		return ""
	var slug: String = ""
	for character: String in shown.to_lower():
		slug += character if character in "abcdefghijklmnopqrstuvwxyz0123456789" else ("_" if not slug.ends_with("_") else "")
	var profile: String = "%s-%s" % [slug.trim_suffix("_").left(20), fresh().left(6)]
	var config := ConfigFile.new()
	config.set_value("identity", "token", fresh())
	config.set_value("character", "name", shown)
	config.set_value("character", "played", int(Time.get_unix_time_from_system()))
	return profile if valid_profile(profile) and config.save(path_for(profile)) == OK else ""


## Forgets a character on this computer: without its token, no host will hand it back.
static func delete(profile: String) -> bool:
	return valid_profile(profile) and FileAccess.file_exists(path_for(profile)) \
		and DirAccess.remove_absolute(ProjectSettings.globalize_path(path_for(profile))) == OK


## Stores what the host last showed of a profile's character (menu only).
static func remember(profile: String, vocation: String, level: int, equipment: Dictionary) -> void:
	var config := ConfigFile.new()
	if not valid_profile(profile) or config.load(path_for(profile)) != OK:
		return
	config.set_value("character", "vocation", vocation)
	config.set_value("character", "level", level)
	config.set_value("character", "equipment", equipment)
	config.set_value("character", "played", int(Time.get_unix_time_from_system()))
	config.save(path_for(profile))


static func last_profile() -> String:
	var config := ConfigFile.new()
	return String(config.get_value("start", "profile", "")) if config.load(SETTINGS) == OK else ""


static func set_last_profile(profile: String) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS)
	config.set_value("start", "profile", profile)
	config.save(SETTINGS)
