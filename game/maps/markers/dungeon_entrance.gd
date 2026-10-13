extends Marker2D
## A stairway down into an instanced dungeon (game/data/dungeons.gd). Its tile is painted as
## stairs ("v"); stepping on it takes a player, and later their party, into a private copy.

@export var dungeon: String = ""
