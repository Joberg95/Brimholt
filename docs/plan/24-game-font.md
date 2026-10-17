# 24 - A Verdana-like game font

**Effort:** S

## Request
Add a font similar to Verdana (Verdana seems to be a paid font).

## Today
Every label, nameplate, floating number, and the loot text draws with `ThemeDB.fallback_font`
(Godot's built-in sans), at sizes from 8 to 15. There is no font asset and no project theme font.

Verdana belongs to Microsoft: it comes with Windows but may not be redistributed, so it cannot ship
in the repository. Close, freely licensed alternatives:

| Font | Licence | Notes |
| --- | --- | --- |
| **DejaVu Sans** (recommended) | Bitstream Vera licence (free, redistributable) | Grew out of Bitstream Vera, which was designed in the same humanist, wide, screen-first spirit as Verdana; the nearest look |
| Noto Sans | SIL Open Font License | Clean and wide, a little narrower than Verdana |
| A pixel font (e.g. Pixel Operator) | SIL OFL or CC0, depending on the font | Crisp at 8-10 px like the Tibia client, but no longer Verdana-like |

## Needs from you
The repository allows only CC0 downloads (`.github/copilot-instructions.md`). DejaVu Sans and Noto
Sans are free to bundle but not CC0. Choose: allow DejaVu Sans with its licence file beside it, or
look for a CC0 font instead.

## Steps
1. Add the chosen font under `assets/third_party/fonts/` with its licence, and a row in
   `assets/third_party/CREDITS.md`; update the asset rule if it is not CC0.
2. Import it with hinting and subpixel positioning set for small sizes (disable antialiasing if a
   pixel font), and make it the project's default theme font (`gui/theme/custom_font`), so every
   `ThemeDB.fallback_font` user picks it up.
3. Check every text size in use (8-15): nameplates, loot text, floating numbers, tooltips, the
   character window. Adjust sizes where the new metrics overflow a panel.

## Tests
- Unit check: the theme's default font is the bundled one.
- Visual captures of the panel, a tooltip, nameplates, and loot text, compared before and after.

## Done when
All game text uses the new font, nothing overflows, and the licence is in the repository.
