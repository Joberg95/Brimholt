extends RefCounted
## The event bus (plan 48): systems append typed events (Damaged, Died, ItemMoved, Moved, ...) and
## other systems react to them in the same tick. An event is a Dictionary with a "type" and its own
## fields, so the existing event arrays (combat.tick's {"kind": ...} entries) can move onto the bus one
## kind at a time. Events are delivered in the order they were raised; a handler may raise more, which
## are delivered after the ones already queued, until the queue is empty.

## Event types systems may raise. A type must be listed here before it is used.
const TYPES: Array[String] = ["damaged", "died", "item_moved", "moved", "levelled", "message"]
## The most events one drain delivers, so a handler loop can never hang a tick.
const MAX_PER_DRAIN: int = 100000

## Event type -> handlers (Callables taking the event Dictionary), in subscription order.
var _handlers: Dictionary = {}
var _queue: Array[Dictionary] = []
## Every event delivered since the last take_log(), for replication and tests.
var _log: Array[Dictionary] = []


## Calls `handler` with every event of `type` from now on.
func subscribe(type: String, handler: Callable) -> void:
	assert(type in TYPES, "unknown event type " + type)
	if not _handlers.has(type):
		_handlers[type] = []
	_handlers[type].append(handler)


## Queues an event of `type` with `fields`; it is delivered on the next drain().
func raise(type: String, fields: Dictionary = {}) -> void:
	assert(type in TYPES, "unknown event type " + type)
	var event: Dictionary = fields.duplicate()
	event["type"] = type
	_queue.append(event)


## Delivers queued events in order, including those raised by handlers; returns how many.
func drain() -> int:
	var delivered: int = 0
	while not _queue.is_empty() and delivered < MAX_PER_DRAIN:
		var event: Dictionary = _queue.pop_front()
		delivered += 1
		_log.append(event)
		for handler: Callable in _handlers.get(event["type"], []):
			handler.call(event)
	return delivered


func pending() -> int:
	return _queue.size()


## The events delivered since the last call, oldest first; clears the log.
func take_log() -> Array[Dictionary]:
	var taken: Array[Dictionary] = _log
	_log = []
	return taken
