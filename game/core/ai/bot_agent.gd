extends Node
## The LimboAI agent of one player bot (game/core/bots.gd). Not in the scene tree: the host's
## Bots ticks its behavior tree by hand, and the tree's tasks (game/core/ai/tasks/) read this
## node for the bot's id, the shared Bots brain, the current time, and the events to publish.

## The Bots brain, held weakly: Bots owns this node, and a strong reference back would keep
## both alive forever (Bots frees its agents when it is freed).
var bots: RefCounted:
	get:
		return _bots.get_ref() if _bots != null else null
	set(value):
		_bots = weakref(value)
var _bots: WeakRef
var id: int = 0
var now: float = 0.0
var events: Array = []


func player() -> Dictionary:
	return bots.world.players[id]


func bot() -> Dictionary:
	return bots.bots[id]
