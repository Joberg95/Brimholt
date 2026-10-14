extends Marker2D
## A town vendor, banker, or artisan. Players within World.TALK_RANGE tiles right-click them:
## vendors Trade (potions and levelling gear; they buy loot), bankers Bank (gold and the item
## depot), and artisans Craft (game/core/crafting.gd).

@export var npc_name: String = "Vendor"
## Town name shown in the trade or bank window.
@export var place: String = ""
## "vendor", "banker", or "artisan".
@export_enum("vendor", "banker", "artisan") var role: String = "vendor"
@export var facing: Vector2i = Vector2i.DOWN
