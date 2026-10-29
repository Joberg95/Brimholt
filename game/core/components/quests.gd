extends RefCounted
## A player's quests (plan 48): tasks in hand and done, boss trophies to trade for relics, and the
## bosses slain. Owned by the quests system (game/core/systems/quests.gd); saved with the character.

## Task id -> kills counted so far.
var tasks: Dictionary = {}
## Task id -> true, for every task turned in.
var done_tasks: Dictionary = {}
## Boss -> trophies not yet traded for a relic.
var trophies: Dictionary = {}
## Boss -> true, for every relic boss this player helped slay (titles count them).
var slain: Dictionary = {}
