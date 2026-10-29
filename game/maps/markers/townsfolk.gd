extends Marker2D
## A town vendor, banker, artisan, or warden. Players within World.TALK_RANGE tiles right-click
## them: vendors Trade (potions and levelling gear; they buy loot), bankers Bank (gold and the item
## depot), artisans Craft (game/core/systems/professions.gd), and wardens PvP (Combat.set_pvp).

@export var npc_name: String = "Vendor"
## Town name shown in the trade or bank window.
@export var place: String = ""
## "vendor", "banker", "artisan", or "warden".
@export_enum("vendor", "banker", "artisan", "warden") var role: String = "vendor"
@export var facing: Vector2i = Vector2i.DOWN
