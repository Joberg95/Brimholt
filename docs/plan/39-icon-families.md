# 39 - Classic-style icons for the remaining item families

**Effort:** L

## Request
(Following the icon work of 2026-10-16/17.) Bring every item icon up to the Tibia-style hand-drawn
look that rings, necklaces, axes, swords, backpacks, coins, and monster drops now have, so no
family is left on the old generated shapes or recoloured templates.

## Today
Done: tier helmets, armour, legs, and boots stay painted, and the pieces without a painting each take
bands of two or three painted pieces stacked into a new design (`derive_icons.py armor_bases`;
code-drawn armour fell short of the painted look). Drawn the new way (the `icon-art` skill): shields (pixel_shields.py: round, heater, kite, tower,
and oval shapes, bevelled rims, divided and textured fields, embossed emblems), bows (pixel_bows.py: round, recurve, and deflex limbs,
each with its own grip, tips, and ornaments), wands and rods (pixel_staves.py: big heads modelled on
classic wands and rods, near upright on thin shafts), potions, rings, necklaces, axes, swords, backpacks, coins, the 100
monster drops and gathered resources, the showpiece helmets and boots. Still old:

| Family | Today | Builder to use |
| --- | --- | --- |
| Runes and spell stones | `runestone_icon` | Hand-drawn stone shapes per rune family |
| Food | `item_icon` | Part maps (bread, meat, fish dish, fruit) |
| Crossbows | generated | Hand-pixelled on the diagonal like the bows |
| Maces and hammers | generated `weapon_model` | Hand-pixelled heads on a haft like axes |
| Spellbooks | painted templates, recoloured | Part maps, front view |
| Capes | generated | Part map, folded cloth |
| Torches, packs (quest), bags (crafted) | generated or older bag art | `pixel_bags` styles |

## Steps
Work family by family, in this order (most seen first): spellbooks, crossbows, maces and hammers, capes, food, runes, the rest. For each:
1. Gather references and design one distinct look per item (no recolours of one blueprint).
2. Draw in the builder named above; route its looks in `item_icon` and `needs_volume`; held or
   worn items get `painted_held` or a textured worn layer.
3. Review side by side at 4x, regenerate (`--only items.png ...`), unit and visual tests.

## Tests
Per family: a look check in `rules_test.gd` (every item of the family uses the new look), the
weapon silhouette and padding checks, and a visual capture of the family worn or held.

## Done when
`derive_icons.py` derives only tier armour (bands of painted pieces) and `item_icon`'s
old shape branches are gone.
