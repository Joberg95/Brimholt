---
name: icon-art
description: Use when adding an item or changing which picture a Brimholt item shows. Item icons are the OpenTibia sprite pack's own item sprites (plan 49), picked per item by a pack id in items.json and exported to items.png; nothing is drawn here.
---

# Item icons

Every item icon is a sprite from the OpenTibia sprite pack (CC BY 4.0,
`assets/third_party/CREDITS.md`), used as it is (plan 49, the owner's decision on 2026-10-22).
Our own drawn icons, worn gear, mounts, and painted outfits were deleted: do not bring them back
or draw new icons until the owner asks for that.

1. Each row of `game/data/items.json` names its pack item in `sprite` (an id from
   `assets/third_party/opentibia_sprite_pack/client_files/otsp.dat`). No two items share a sprite.
2. To change an item's picture, set `sprite` to another pack item of the same kind (the kinds and
   their id ranges are `PACK` in `tools/generators/otsp_items.py`), then run
   `python tools/generators/otsp_export.py items` and reimport (`make import`).
3. A new item needs a catalog row with an unused `sprite` of its kind. If the pack has none left,
   the item cannot be added yet.
4. `tools/generators/otsp.py` reads the pack's `otsp.dat` and `otsp.spr` (`load`, `compose`).
   `otsp_export.py` halves a two-by-two pack item to fit its 32×32 cell.
5. Check the result by eye (the paperdoll, the backpack, and the ground in `make test-visual`'s
   captures). Art is never unit-tested.
