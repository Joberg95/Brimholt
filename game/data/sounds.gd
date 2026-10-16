extends RefCounted
## What the game sounds like: every sound id with its files and bus, which sound a combat
## event, a monster, a footstep, or a place makes. Pure data and lookups, so the unit tests can
## check every mapping without an audio device; game/audio/sound.gd plays them.
##
## All files are CC0 (assets/third_party/CREDITS.md). Each id lists variants; one is picked at
## random each time, and `pitch` adds a little random pitch so repeats do not sound identical.

const World = preload("res://game/core/world.gd")
const Biomes = preload("res://game/data/biomes.gd")

const ROOT: String = "res://assets/third_party/audio/"
const BUSES: Array[String] = ["Music", "Ambience", "Effects", "UI"]


static func _files(folder: String, pattern: String, first: int, last: int) -> Array[String]:
	var result: Array[String] = []
	for index: int in range(first, last + 1):
		result.append(ROOT + folder + "/" + pattern % index)
	return result


static func _one(path: String) -> Array[String]:
	var result: Array[String] = [ROOT + path]
	return result


## Sound id -> {files, bus, db (volume), pitch (random spread, 0 for none)}.
static var SOUNDS: Dictionary = {
	# Combat.
	"hit": {"files": _files("kenney_impact_sounds", "impactPunch_medium_%03d.ogg", 0, 4), "bus": "Effects", "db": -6.0, "pitch": 0.1},
	"critical": {"files": _files("kenney_impact_sounds", "impactPunch_heavy_%03d.ogg", 0, 4), "bus": "Effects", "db": -3.0, "pitch": 0.08},
	"miss": {"files": _files("oga_rpg_sound_pack", "swing%d.wav", 2, 3) + _one("oga_rpg_sound_pack/swing.wav"),
		"bus": "Effects", "db": -10.0, "pitch": 0.1},
	"swing": {"files": _one("kenney_rpg_audio/knifeSlice.ogg") + _one("kenney_rpg_audio/knifeSlice2.ogg"),
		"bus": "Effects", "db": -12.0, "pitch": 0.12},
	"arrow": {"files": _files("kenney_rpg_audio", "drawKnife%d.ogg", 1, 2), "bus": "Effects", "db": -12.0, "pitch": 0.15},
	"heal": {"files": _one("oga_80_cc0_rpg_sfx/spell_02.ogg"), "bus": "Effects", "db": -10.0, "pitch": 0.05},
	"drink": {"files": _files("oga_rpg_sound_pack", "bubble%d.wav", 2, 3) + _one("oga_rpg_sound_pack/bubble.wav"),
		"bus": "Effects", "db": -8.0, "pitch": 0.08},
	"cast": {"files": _one("oga_rpg_sound_pack/magic1.wav"), "bus": "Effects", "db": -12.0, "pitch": 0.08},
	# Spell and rune elements, where they land.
	"fire": {"files": _files("oga_80_cc0_rpg_sfx", "spell_fire_%02d.ogg", 1, 4), "bus": "Effects", "db": -8.0, "pitch": 0.08},
	"frost": {"files": _files("kenney_impact_sounds", "impactGlass_light_%03d.ogg", 0, 4), "bus": "Effects", "db": -6.0, "pitch": 0.1},
	"lightning": {"files": _one("freesound/zap.ogg"), "bus": "Effects", "db": -10.0, "pitch": 0.15},
	"holy": {"files": _one("oga_80_cc0_rpg_sfx/spell_01.ogg"), "bus": "Effects", "db": -10.0, "pitch": 0.08},
	"nature": {"files": _files("kenney_impact_sounds", "impactWood_light_%03d.ogg", 0, 4), "bus": "Effects", "db": -6.0, "pitch": 0.1},
	"recall": {"files": _one("oga_rpg_sound_pack/spell.wav"), "bus": "Effects", "db": -8.0, "pitch": 0.0},
	"flash": {"files": _one("kenney_interface_sounds/maximize_006.ogg"), "bus": "Effects", "db": -10.0, "pitch": 0.0},
	# The player's own progress and belongings (heard only by them, so on the UI bus).
	"level_up": {"files": _one("freesound/level_up.ogg"), "bus": "UI", "db": -6.0, "pitch": 0.0},
	"coins": {"files": _one("kenney_rpg_audio/handleCoins.ogg") + _one("kenney_rpg_audio/handleCoins2.ogg")
		+ _files("oga_80_cc0_rpg_sfx", "item_coins_%02d.ogg", 1, 2), "bus": "UI", "db": -8.0, "pitch": 0.05},
	"pick_up": {"files": _one("kenney_rpg_audio/dropLeather.ogg") + _files("kenney_rpg_audio", "cloth%d.ogg", 1, 2),
		"bus": "UI", "db": -8.0, "pitch": 0.1},
	"book_open": {"files": _one("kenney_rpg_audio/bookOpen.ogg"), "bus": "UI", "db": -10.0, "pitch": 0.05},
	"book_close": {"files": _one("kenney_rpg_audio/bookClose.ogg"), "bus": "UI", "db": -10.0, "pitch": 0.05},
	"open": {"files": _one("kenney_interface_sounds/open_001.ogg"), "bus": "UI", "db": -12.0, "pitch": 0.0},
	"close": {"files": _one("kenney_interface_sounds/close_001.ogg"), "bus": "UI", "db": -12.0, "pitch": 0.0},
	# Footsteps by ground (FOOTSTEPS).
	"step_grass": {"files": _files("kenney_impact_sounds", "footstep_grass_%03d.ogg", 0, 4), "bus": "Effects", "db": -20.0, "pitch": 0.1},
	"step_snow": {"files": _files("kenney_impact_sounds", "footstep_snow_%03d.ogg", 0, 4), "bus": "Effects", "db": -18.0, "pitch": 0.1},
	"step_wood": {"files": _files("kenney_impact_sounds", "footstep_wood_%03d.ogg", 0, 4), "bus": "Effects", "db": -20.0, "pitch": 0.1},
	"step_stone": {"files": _files("kenney_impact_sounds", "footstep_concrete_%03d.ogg", 0, 4), "bus": "Effects", "db": -20.0, "pitch": 0.1},
	"step_dirt": {"files": _files("kenney_rpg_audio", "footstep%02d.ogg", 0, 9), "bus": "Effects", "db": -18.0, "pitch": 0.1},
	# Monster voices (MONSTER_VOICES).
	"voice_humanoid": {"files": _files("oga_80_cc0_creature_sfx", "grunt_%02d.ogg", 1, 5), "bus": "Effects", "db": -10.0, "pitch": 0.1},
	"death_humanoid": {"files": _files("oga_80_cc0_creature_sfx", "hurt_%02d.ogg", 1, 5), "bus": "Effects", "db": -8.0, "pitch": 0.1},
	"voice_beast": {"files": _files("oga_80_cc0_creature_sfx", "roar_%02d.ogg", 1, 3) + _files("oga_rpg_sound_pack", "mnstr%d.wav", 1, 3),
		"bus": "Effects", "db": -10.0, "pitch": 0.1},
	"death_beast": {"files": _files("oga_rpg_sound_pack", "mnstr%d.wav", 4, 6) + _one("oga_80_cc0_rpg_sfx/creature_die_01.ogg"),
		"bus": "Effects", "db": -8.0, "pitch": 0.1},
	"voice_wolf": {"files": _one("oga_80_cc0_creature_sfx/howl.ogg") + _files("oga_80_cc0_creature_sfx", "barking_%02d.ogg", 1, 2)
		+ _one("oga_rpg_sound_pack/wolfman.wav"), "bus": "Effects", "db": -10.0, "pitch": 0.08},
	"voice_rat": {"files": _files("oga_80_cc0_creature_sfx", "cute_%02d.ogg", 1, 3), "bus": "Effects", "db": -12.0, "pitch": 0.15},
	"voice_golem": {"files": _files("oga_80_cc0_rpg_sfx", "stones_%02d.ogg", 1, 4), "bus": "Effects", "db": -8.0, "pitch": 0.1},
	"death_golem": {"files": _files("kenney_impact_sounds", "impactMining_%03d.ogg", 0, 4), "bus": "Effects", "db": -4.0, "pitch": 0.1},
	"voice_giant": {"files": _files("oga_rpg_sound_pack", "ogre%d.wav", 1, 4) + _files("oga_rpg_sound_pack", "giant%d.wav", 1, 4)
		+ _files("oga_80_cc0_creature_sfx", "troll_%02d.ogg", 1, 3), "bus": "Effects", "db": -8.0, "pitch": 0.08},
	"voice_wraith": {"files": _files("oga_rpg_sound_pack", "shade%d.wav", 1, 6), "bus": "Effects", "db": -10.0, "pitch": 0.1},
	"death_wraith": {"files": _files("oga_80_cc0_creature_sfx", "scream_%02d.ogg", 1, 2), "bus": "Effects", "db": -12.0, "pitch": 0.1},
	"voice_spider": {"files": _files("oga_80_cc0_creature_sfx", "bug_%02d.ogg", 1, 4), "bus": "Effects", "db": -10.0, "pitch": 0.1},
	"death_spider": {"files": _files("oga_rpg_sound_pack", "bite-small%d.wav", 2, 3) + _one("oga_rpg_sound_pack/bite-small.wav"),
		"bus": "Effects", "db": -8.0, "pitch": 0.1},
	"voice_blob": {"files": _files("oga_rpg_sound_pack", "slime%d.wav", 1, 6), "bus": "Effects", "db": -10.0, "pitch": 0.1},
	# Weather one-shots and ambience loops (ambience()).
	"thunder": {"files": _one("freesound/thunder_1.ogg") + _one("freesound/thunder_2.ogg"), "bus": "Ambience", "db": -4.0, "pitch": 0.05},
	"rain": {"files": _one("freesound/rain_loop.ogg"), "bus": "Ambience", "db": -6.0, "pitch": 0.0, "loop": true},
	"birds": {"files": _one("freesound/birds.ogg"), "bus": "Ambience", "db": -12.0, "pitch": 0.0, "loop": true},
	"crickets": {"files": _one("freesound/crickets.ogg"), "bus": "Ambience", "db": -14.0, "pitch": 0.0, "loop": true},
	"town": {"files": _one("freesound/town.ogg"), "bus": "Ambience", "db": -12.0, "pitch": 0.0, "loop": true},
	"wind": {"files": _one("freesound/wind_plain.ogg"), "bus": "Ambience", "db": -10.0, "pitch": 0.0, "loop": true},
	"blizzard": {"files": _one("freesound/wind_arctic.ogg"), "bus": "Ambience", "db": -8.0, "pitch": 0.0, "loop": true},
	"swamp": {"files": _one("freesound/swamp.ogg"), "bus": "Ambience", "db": -10.0, "pitch": 0.0, "loop": true},
	"cave": {"files": _one("freesound/cave_drips.ogg"), "bus": "Ambience", "db": -10.0, "pitch": 0.0, "loop": true},
}

## Monster look -> [voice on attack, sound on death]. A monster whose id names a kind in
## KIND_VOICES (wolves howl, rats squeak, ogres and trolls bellow) uses that voice instead.
const MONSTER_VOICES: Dictionary = {
	"humanoid": ["voice_humanoid", "death_humanoid"],
	"quadruped": ["voice_beast", "death_beast"],
	"golem": ["voice_golem", "death_golem"],
	"wraith": ["voice_wraith", "death_wraith"],
	"spider": ["voice_spider", "death_spider"],
	"blob": ["voice_blob", "death_beast"],
}
const KIND_VOICES: Dictionary = {
	"wolf": "voice_wolf", "hound": "voice_wolf", "greymaw": "voice_wolf", "fang": "voice_wolf",
	"rat": "voice_rat", "vole": "voice_rat",
	"ogre": "voice_giant", "troll": "voice_giant", "cyclops": "voice_giant", "titan": "voice_giant", "jarl": "voice_giant",
	"gorvak": "voice_giant", "brute": "voice_giant",
}
## Terrain character -> footstep sound; anything else is "step_dirt".
const FOOTSTEPS: Dictionary = {
	".": "step_grass", "=": "step_stone", "b": "step_wood", "o": "step_stone", "c": "step_stone",
	"v": "step_stone", "^": "step_stone",
}
## Spell, rune, and missile elements -> the sound where they land.
const ELEMENTS: Dictionary = {
	"slash": "swing", "pierce": "arrow", "fire": "fire", "frost": "frost", "lightning": "lightning",
	"holy": "holy", "nature": "nature", "heal": "recall",
}
## Regions where the wind blows over open high ground.
const WINDY_REGIONS: Array[String] = ["Golemback Hills", "Smoulder Fells", "Outlaw Ridge", "Stonevale", "Lastlight Downs",
	"Westwind Coast"]
## Regions of bog and reed, with frogs.
const WET_REGIONS: Array[String] = ["Mirewood Fen", "Lurkmoor", "Stillwater Shore"]


static func exists(id: String) -> bool:
	return SOUNDS.has(id)


## The sound a combat event makes, or "" for none ("hit", "missile", "area"; other kinds,
## such as "player" or "message", are silent). Missiles sound as they leave; their element
## sounds again where they land (Sound.on_event).
static func for_event(event: Dictionary) -> String:
	match event.get("kind", ""):
		"hit":
			match event.get("style", ""):
				"damage":
					return "hit" if int(event.get("amount", 0)) > 0 else "miss"
				"critical":
					return "critical"
				"heal":
					return "heal"
				"mana":
					return "drink"
			return ""
		"missile":
			var element: String = event.get("element", "")
			return "arrow" if element == "pierce" else ("swing" if element in ["", "slash"] else "cast")
		"area":
			var element: String = event.get("element", "")
			return ELEMENTS.get(element, "flash") if not element.is_empty() else "flash"
	return ""


## Where a missile's element sounds on landing ("" when it has none).
static func landing(event: Dictionary) -> String:
	var element: String = event.get("element", "")
	if element in ["", "slash", "pierce"]:
		return ""
	return ELEMENTS.get(element, "")


## [voice, death] sound ids for a monster kind and look.
static func monster_voices(kind: String, look: String) -> Array:
	var voices: Array = MONSTER_VOICES.get(look, MONSTER_VOICES["quadruped"]).duplicate()
	for word: String in KIND_VOICES:
		if word in kind:
			voices[0] = KIND_VOICES[word]
			break
	return voices


## The footstep for a tile: snow on the frost isles' open ground.
static func footstep(cell: Vector2i) -> String:
	var ground: String = World.terrain(cell)
	if Biomes.in_isles(cell) and ground in [".", ",", ":"]:
		return "step_snow"
	return FOOTSTEPS.get(ground, "step_dirt")


## The ambience at a place: {layer: [sound id, 0..1 volume]} for the "bed" (the place's own
## sound) and "rain" layers. `place` holds {location kind ("town", "dungeon", ...), region,
## underground, desert, isles, night (0..1), rain (0..1), snow}.
static func ambience(place: Dictionary) -> Dictionary:
	var rain: float = clampf(place.get("rain", 0.0), 0.0, 1.0)
	var night: float = clampf(place.get("night", 0.0), 0.0, 1.0)
	var bed: Array = ["", 0.0]
	if place.get("underground", false) or place.get("kind", "") == "dungeon":
		return {"bed": ["cave", 1.0], "rain": ["", 0.0]}
	if place.get("isles", false) or place.get("snow", false):
		# Snow falls silently; the wind carries the storm.
		return {"bed": ["blizzard", 0.5 + 0.5 * rain], "rain": ["", 0.0]}
	if place.get("desert", false):
		bed = ["wind", 0.8]
	elif place.get("kind", "") == "town":
		bed = ["town", 1.0 - 0.7 * night] if night < 0.6 else ["crickets", 0.6]
	elif place.get("region", "") in WET_REGIONS:
		bed = ["swamp", 1.0]
	elif place.get("region", "") in WINDY_REGIONS:
		bed = ["wind", 0.7]
	else:
		bed = ["birds", 1.0] if night < 0.5 else ["crickets", 1.0]
	# Birds fall quiet in the rain.
	if bed[0] == "birds":
		bed[1] *= 1.0 - 0.8 * rain
	return {"bed": bed, "rain": ["rain", rain] if rain > 0.02 else ["", 0.0]}
