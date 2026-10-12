---
name: visible-equipment
description: Use when implementing or changing visible equipped items, the backpack/ground inventory, drag-and-drop, character drawing layers, item icons, facing alignment, or replicated appearance in Brimholt.
---

# Visible equipment and inventory

1. Keep the inventory flat: equipment slots, one fixed-size backpack, and ground stacks. Do not add nested containers, loot economies, or trading without a user-selected milestone.
2. Define item metadata (name, slot or none) in the shared catalog and visual identity (palette/icon) in the art module. Items are catalog kinds chosen by the server; clients name locations, never item kinds or contents.
3. Store equipment, backpacks, and ground items in authoritative state. Route every change through `World.move_item` (or `toggle_equipment`, which uses it) so host and remote input share validation: strict location shapes, reach, slot type, capacity, stack limit, and cooldown.
4. Render gear as original layers over the base character. Keep layers aligned with facing and the interpolated position; define a consistent behind/body/front ordering.
5. Unequipping removes the corresponding layer. Appearance comes from replicated equipment metadata, never an independently client-authored appearance state.
6. Include equipment in accepted-action updates and late-join snapshots, and ground stacks in ground updates and snapshots. Send backpack contents only to their owner. Clean up carried items with the actor on disconnect.
7. Check equip/unequip and drop/pick-up locally, on another LAN peer, and after a late join. Verify malformed locations, out-of-reach tiles, and wrong slots cannot change authoritative state.
8. Perform a visual check when a graphical Godot session is available. A state-sync test alone does not prove drawing quality.

Current catalog/state/rules: `game/world.gd`; replication, panel, and drag-and-drop: `game/main.gd`; layered rendering and icons: `game/character_art.gd`. The graphical check is `tests/visual_test.gd`. Do not invent asset paths or download proprietary artwork.
