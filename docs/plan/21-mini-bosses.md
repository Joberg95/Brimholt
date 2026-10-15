# 21 - Rare mini-bosses

**Effort:** L  **When:** later, when the game is in a good and stable state

## Request
Small rare bosses across the world from level 10 to 50 that only attack if you attack them.
Themed like our own versions of Tibia's Sword of Fury, minotaur mage, Serpentine Tower and
Paradoxica.

## Today
Monsters have ranks (`normal`, elites, `boss`) in `game/data/monsters.gd`; final bosses respawn
slowly. All monsters are aggressive.

## Steps
1. A "rare" rank: passive until attacked (`Combat` monster AI skips targeting until hit), spawns
   at a random spot from a list of candidate places, with a long and random respawn.
2. Five to eight originals spread over 10-50, each with a theme and one signature mechanic: an
   animated cursed blade, a minotaur spellcaster, a tower serpent that calls adds, a time-skewed
   wraith that rewinds its health once. Original names and art; no copied Tibia content.
3. Loot: a unique cosmetic or useful item each, plus a lexicon entry that unlocks on first kill.
4. A world message when one appears (optional, rare).

## Tests
Unit: passive until hit; respawn picks a valid place; loot rolls; a party gets credit.

## Done when
Rare passive bosses appear around the world and are worth hunting.
