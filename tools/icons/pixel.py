"""Hand-pixelled icons: each icon is a 32x32 grid of tone letters drawn pixel by pixel; the code only maps
letters to colours through the icon's palette and adds the pure black outline round the silhouette
(docs/plan/48-item-icons-remake.md). The art is the grid.

Palettes map one letter per tone. The usual letters (an icon may define its own):
  1-9   the main metal, darkest to brightest        a-e  wood or leather, darkest to lightest
  A-E   trim (bronze, gold), darkest to brightest   S    a bright inlay or glow
  #     a black line inside the drawing             .    transparent
"""
import colorsys

SIZE = 32


def ramp(dark, light, steps):
    """`steps` colours from `dark` to `light` (hex), lightness linear, hue and saturation eased."""
    def hls(code):
        return colorsys.rgb_to_hls(*(int(code[i:i + 2], 16) / 255 for i in (0, 2, 4)))
    (h0, l0, s0), (h1, l1, s1) = hls(dark), hls(light)
    dh = ((h1 - h0 + 0.5) % 1) - 0.5
    out = []
    for i in range(steps):
        t = i / (steps - 1) if steps > 1 else 1.0
        rgb = colorsys.hls_to_rgb((h0 + dh * t) % 1, l0 + (l1 - l0) * t, s0 + (s1 - s0) * t)
        out.append(tuple(round(c * 255) for c in rgb))
    return out


def palette(**materials):
    """A palette from named ramps: materials maps a run of letters ("123456789") to (dark, light) hex."""
    colours = {"#": (0, 0, 0)}
    for letters, (dark, light) in materials.items():
        for letter, rgb in zip(letters, ramp(dark, light, len(letters))):
            colours[letter] = rgb
    return colours


def render(grid, colours):
    """RGBA rows of a tone grid: each letter its colour, then a black outline on the transparent pixels
    that touch the drawing (all four sides)."""
    assert len(grid) == SIZE and all(len(row) == SIZE for row in grid), [len(r) for r in grid]
    out = [[None] * SIZE for _ in range(SIZE)]
    for y, row in enumerate(grid):
        for x, ch in enumerate(row):
            if ch != ".":
                out[y][x] = colours[ch] + (255,)
    for y in range(SIZE):
        for x in range(SIZE):
            if grid[y][x] == "." and any(0 <= x + dx < SIZE and 0 <= y + dy < SIZE and grid[y + dy][x + dx] != "."
                                         for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out[y][x] = (0, 0, 0, 255)
    return out


def grid(rows):
    """Pads hand-written rows (each "x: tones" or a full row) to 32 columns: a row written as
    (column, "tones") places its tones from that column; several pieces may share a row."""
    out = []
    for row in rows:
        line = ["."] * SIZE
        for column, tones in row:
            for i, ch in enumerate(tones):
                if ch != " ":
                    line[column + i] = ch
        out.append("".join(line))
    return out
