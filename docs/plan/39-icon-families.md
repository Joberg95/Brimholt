# 39 - Classic-style icons for the remaining item families

**Effort:** L

## Request
(Following the icon work of 2026-10-16/17.) Bring every item icon up to the Tibia-style hand-drawn
look that rings, necklaces, axes, swords, backpacks, coins, and monster drops now have, so no
family is left on the old generated shapes or recoloured templates.

## Today
Drawn the new way (the `icon-art` skill): rings, necklaces, axes, swords, backpacks, coins, the 100
monster drops and gathered resources, the showpiece helmets and boots. Still old:

| Family | Today | Builder to use |
| --- | --- | --- |
| Potions (health, mana, strong) | `item_icon` vials | Part map like `pixel_bags` (glass, liquid, cork, label) |
| Runes and spell stones | `runestone_icon` | Hand-drawn stone shapes per rune family |
| Food | `item_icon` | Part maps (bread, meat, fish dish, fruit) |
| Bows, crossbows | painted templates, recoloured | Hand-pixelled on the diagonal like swords |
| Wands and rods | painted templates, recoloured | Hand-pixelled on the diagonal, glowing tips |
| Maces and hammers | generated `weapon_model` | Hand-pixelled heads on a haft like axes |
| Shields and spellbooks | painted templates, recoloured | Part maps, front view |
| Capes | generated | Part map, folded cloth |
| Tier helmets, armour, legs, boots | recoloured painted templates (`derive_icons.py`) | Part maps per armour type (plate, mail, leather, cloth), each tier its own trim |
| Torches, packs (quest), bags (crafted) | generated or older bag art | `pixel_bags` styles |

## Steps
Work family by family, in this order (most seen first): potions, tier armour and helmets, bows and
wands, shields, maces and hammers, capes, food, runes, the rest. For each:
1. Gather references and design one distinct look per item (no recolours of one blueprint).
2. Draw in the builder named above; route its looks in `item_icon` and `needs_volume`; held or
   worn items get `painted_held` or a textured worn layer.
3. Review side by side at 4x, regenerate (`--only items.png ...`), unit and visual tests.

## Tests
Per family: a look check in `rules_test.gd` (every item of the family uses the new look), the
weapon silhouette and padding checks, and a visual capture of the family worn or held.

## Done when
`derive_icons.py` derives nothing for icons and `item_icon`'s old shape branches are gone.
