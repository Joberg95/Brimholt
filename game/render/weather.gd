extends RefCounted
## Weather, computed from the host's clock (Main.world_clock) like the time of day, so every
## peer sees the same sky without any network messages. Time is split into SLOT_SECONDS
## slots; each slot's weather is a hash of its index (clear, overcast, rain, or storm), and
## neighbouring slots blend over BLEND_SECONDS. Storms flash lightning at hashed moments.
## Weather is presentation only: it never changes combat, movement, or loot.
##
## Underground (dungeon copies) there is no weather, and the Dunmere desert never gets rain
## (game/data/biomes.gd); its sky only clouds over a little.

const World = preload("res://game/core/world.gd")
const Biomes = preload("res://game/data/biomes.gd")
const SLOT_SECONDS: float = 240.0
const BLEND_SECONDS: float = 30.0
## Per-slot weather and its cumulative chance (out of 100): clear 50, overcast 20, rain 22, storm 8.
const KINDS: Array = [["clear", 50], ["overcast", 70], ["rain", 92], ["storm", 100]]
## [cloud, rain, storm] of each kind; cloud darkens the light, rain sets the drop density.
const LEVELS: Dictionary = {
	"clear": [0.0, 0.0, 0.0], "overcast": [0.55, 0.0, 0.0], "rain": [0.75, 0.65, 0.0], "storm": [1.0, 1.0, 1.0],
}
## Light under full cloud (multiplies the daylight), and the lightning flash colour.
const OVERCAST: Color = Color(0.7, 0.74, 0.82)
const FLASH: Color = Color(1.0, 1.0, 1.15)
const FLASH_SECONDS: float = 0.35
## A storm flashes about every FLASH_EVERY seconds.
const FLASH_EVERY: float = 14.0
## Tests and the visual check set this to a kind to pin the weather; "" follows the clock.
static var override: String = ""


static func kind_of_slot(slot: int) -> String:
	var roll: int = _hash(slot) % 100
	for kind: Array in KINDS:
		if roll < kind[1]:
			return kind[0]
	return "clear"


## {"kind", "cloud", "rain", "storm", "flash"} at a host-clock time, before local climate.
static func at(clock: float) -> Dictionary:
	if not override.is_empty():
		var pinned: Array = LEVELS[override]
		return {"kind": override, "cloud": pinned[0], "rain": pinned[1], "storm": pinned[2],
			"flash": _flash(clock) if override == "storm" else 0.0}
	var slot: int = floori(clock / SLOT_SECONDS)
	var into: float = clock - slot * SLOT_SECONDS
	var kind: String = kind_of_slot(slot)
	var levels: Array = LEVELS[kind]
	# Blend from the previous slot's weather during the first BLEND_SECONDS of a slot.
	var weight: float = smoothstep(0.0, BLEND_SECONDS, into)
	var previous: Array = LEVELS[kind_of_slot(slot - 1)]
	var cloud: float = lerpf(previous[0], levels[0], weight)
	var rain: float = lerpf(previous[1], levels[1], weight)
	var storm: float = lerpf(previous[2], levels[2], weight)
	return {"kind": kind, "cloud": cloud, "rain": rain, "storm": storm, "flash": _flash(clock) * storm}


## The weather where the camera is: none underground, no rain in the desert, and low cloud and
## drizzle all but always over the fen.
static func local(clock: float, cell: Vector2i) -> Dictionary:
	var weather: Dictionary = at(clock)
	if World.zone_at(cell).get("underground", false):
		return {"kind": "underground", "cloud": 0.0, "rain": 0.0, "storm": 0.0, "flash": 0.0}
	if World.region_at(cell) == Biomes.SWAMP_REGION:
		# The fen: low cloud nearly always, and rain more often than not.
		weather["cloud"] = maxf(weather["cloud"], 0.55)
		weather["rain"] = maxf(weather["rain"], 0.3)
	if Biomes.in_desert(cell):
		weather["cloud"] *= 0.35
		weather["rain"] = 0.0
		weather["storm"] = 0.0
		weather["flash"] = 0.0
	return weather


## How weather tints the world's light: clouds dim it, lightning briefly floods it.
static func tint(weather: Dictionary) -> Color:
	var light: Color = Color.WHITE.lerp(OVERCAST, weather["cloud"])
	return light.lerp(FLASH, clampf(weather["flash"], 0.0, 1.0) * 0.75)


## 0..1 strength of a lightning flash at a time: a sharp flash, a fade, and a faint echo.
static func _flash(clock: float) -> float:
	var window: int = floori(clock / FLASH_EVERY)
	var start: float = window * FLASH_EVERY + float(_hash(window * 7 + 3) % 1000) / 1000.0 * (FLASH_EVERY - 1.0)
	var since: float = clock - start
	if since < 0.0 or since > FLASH_SECONDS + 0.25:
		return 0.0
	if since < FLASH_SECONDS:
		return 1.0 - since / FLASH_SECONDS
	return 0.35 if since > FLASH_SECONDS + 0.12 else 0.0


static func _hash(value: int) -> int:
	var mixed: int = (value * 2654435761) ^ (value >> 7) ^ 0x2c1b3c6d
	return absi(mixed * 2246822519 ^ (mixed >> 13))
