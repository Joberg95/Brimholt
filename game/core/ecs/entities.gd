extends RefCounted
## Entity ids (plan 48): an entity is an integer id with a kind. Ids are handed out in rising order and
## never reused within a session, so a stale id can never point at a new entity. Players keep their
## peer ids (claim), everything else gets the next free id (create).

const KINDS: Array[String] = ["player", "monster", "bot", "npc", "ground"]
## Created ids start here, above any peer id the network hands out for players.
const FIRST_ID: int = 1 << 31

var _kinds: Dictionary = {}
var _next: int = FIRST_ID


## A new entity of `kind`; returns its id, or 0 for an unknown kind.
func create(kind: String) -> int:
	if kind not in KINDS:
		return 0
	var id: int = _next
	_next += 1
	_kinds[id] = kind
	return id


## Registers an entity under an id chosen elsewhere (a player's peer id). False if the id is taken,
## not positive, or the kind is unknown.
func claim(id: int, kind: String) -> bool:
	if id <= 0 or _kinds.has(id) or kind not in KINDS:
		return false
	_kinds[id] = kind
	return true


func destroy(id: int) -> void:
	_kinds.erase(id)


func exists(id: int) -> bool:
	return _kinds.has(id)


## The entity's kind, or "" if it does not exist.
func kind_of(id: int) -> String:
	return _kinds.get(id, "")


## Every entity of `kind`, in creation order.
func of_kind(kind: String) -> Array[int]:
	var found: Array[int] = []
	for id: int in _kinds:
		if _kinds[id] == kind:
			found.append(id)
	return found


func count() -> int:
	return _kinds.size()
