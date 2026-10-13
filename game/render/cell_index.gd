extends RefCounted
## A coarse spatial index: keys (monster ids or ground cells) bucketed by CHUNK x CHUNK tile
## chunk, so per-frame drawing and lighting visit only what is near the camera instead of
## every monster or ground stack the host knows about. Queries return candidate keys; callers
## still check that the key exists, so a stale entry is harmless.

const CHUNK: int = 16

var _chunks: Dictionary = {}
var _chunk_of: Dictionary = {}


func put(key: Variant, cell: Vector2i) -> void:
	var chunk := Vector2i(floori(cell.x / float(CHUNK)), floori(cell.y / float(CHUNK)))
	var old: Variant = _chunk_of.get(key)
	if old == chunk:
		return
	if old != null:
		_chunks[old].erase(key)
		if _chunks[old].is_empty():
			_chunks.erase(old)
	_chunk_of[key] = chunk
	if not _chunks.has(chunk):
		_chunks[chunk] = {}
	_chunks[chunk][key] = true


func remove(key: Variant) -> void:
	var old: Variant = _chunk_of.get(key)
	if old == null:
		return
	_chunk_of.erase(key)
	_chunks[old].erase(key)
	if _chunks[old].is_empty():
		_chunks.erase(old)


func clear() -> void:
	_chunks.clear()
	_chunk_of.clear()


func size() -> int:
	return _chunk_of.size()


## Keys in chunks overlapping `area` (tiles); a superset of the keys inside it.
func query(area: Rect2i) -> Array:
	var result: Array = []
	var first := Vector2i(floori(area.position.x / float(CHUNK)), floori(area.position.y / float(CHUNK)))
	var last := Vector2i(floori((area.end.x - 1) / float(CHUNK)), floori((area.end.y - 1) / float(CHUNK)))
	for cy: int in range(first.y, last.y + 1):
		for cx: int in range(first.x, last.x + 1):
			var bucket: Variant = _chunks.get(Vector2i(cx, cy))
			if bucket != null:
				result.append_array(bucket.keys())
	return result
