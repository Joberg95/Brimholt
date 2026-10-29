extends RefCounted
## A player's bank account (plan 48): gold kept at the banker, never lost on death. Owned by the
## economy system (game/core/systems/economy.gd); saved with the character.

var gold: int = 0
