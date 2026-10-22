---
name: visible-equipment
description: Use when implementing or changing visible equipped items, the backpack/ground inventory, drag-and-drop, character drawing layers, item icons, facing alignment, or replicated appearance in Brimholt.
---

# Visible equipment and inventory

1. Keep the inventory shallow: equipment slots, one backpack (8 slots, grown to 20 by bound packs in the pack slot), three bag slots whose worn bags (slot "container") append their slots to the backpack array (`World.bag_range`; a worn bag comes off only when empty, and a bag elsewhere is just an item), the private depot (reachable only beside the banker in Reedmere), and ground stacks. Do not add deeper nested containers or player trading without a user-selected milestone. Monster drops come from `Monsters.LOOT` plus tier gear drops; relics are bound quest rewards. New items are rows in `game/data/items.json` (icon order, look, colours) and get sprites from `make sprites`.
2. Define item metadata (name, slot type or none, stats) in the shared catalog; equipment slots map to slot types through `World.SLOT_TYPES` (both ring slots take "ring") and must be checked with `World.fits`. Equipping checks `World.requirement_error` (tier level, class, and the helmet/armor `armor` type from `Balance.ARMOR_OF`). Helmet, equipped cape, armor, legs, boots, main hand, and off hand are drawn on the character (`SpriteArt.VISIBLE_SLOTS`); armor with an `outfit` draws its painted full figure instead of the body and armor layers (`art/outfits`, `make outfits`, see docs/art.md); relics add glow halos (`game/render/glow_layer.gd`) and visual identity (palette/icon) in the art module. Items are catalog kinds chosen by the server; clients name locations, never item kinds or contents.
3. Store equipment, backpacks, and ground items in authoritative state. Route every change through `World.move_item` (or `toggle_equipment`, which uses it) so host and remote input share validation: strict location shapes, reach, slot type, capacity, stack limit, and cooldown.
4. Worn gear is not drawn on the character (plan 49: Tibia-style outfits from the OpenTibia pack). Equipment shows in the paperdoll and inventory slots as the item's pack icon (`SpriteArt.draw_item`).
5. Appearance comes from replicated equipment metadata, never an independently client-authored appearance state.
6. Include equipment in accepted-action updates and late-join snapshots, and ground stacks in ground updates and snapshots. Send backpack contents only to their owner. Clean up carried items with the actor on disconnect.
7. Check equip/unequip and drop/pick-up locally, on another LAN peer, and after a late join. Verify malformed locations, out-of-reach tiles, and wrong slots cannot change authoritative state.
8. Perform a visual check when a graphical Godot session is available. A state-sync test alone does not prove drawing quality.

Current catalog: `game/data/items.json` and `game/data/items.gd`; state/rules: `game/core/world.gd`; replication: `game/main.gd`; panel and drag-and-drop: `game/ui/inventory_panel.gd`; sprite drawing: `game/render/sprite_art.gd`; item icons: `assets/sprites/items.png` exported from the OpenTibia pack by `tools/generators/otsp_export.py`. The graphical check is `tests/visual/visual_test.gd`. Do not invent asset paths.
