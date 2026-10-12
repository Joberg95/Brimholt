extends RefCounted
## This computer's secret player identity: a random 256-bit token kept in user://identity.cfg
## (or identity-<profile>.cfg, for several players on one computer). Hosts store only its
## SHA-256, so the token is the key to your saved characters on every host you join: keep the
## file private, and copy it to play the same characters from another computer.

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
