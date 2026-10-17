"""Gold coin icons (32x32) that grow with the stack, like classic loot: one coin, two, three, then
a small heap and a big one. Hand-drawn: COIN is one coin seen at a slight tilt (its face lit from
the top-left, its rim a darker band below), and HEAPS are mounds of coins with coin edges picked
out in the shading. Letters are a five-step gold ramp, 1 lightest.

make_sprites.py writes coins.png (one frame per stage, in STAGES order); SpriteArt.coin_stage
picks the frame for a stack's count. The two lists of thresholds must match.
"""

# The smallest count shown by each stage: 1, 2, 3, 4-9, 10-29, 30 and more.
STAGES = (1, 2, 3, 4, 10, 30)
GOLD = {"1": (255, 244, 176), "2": (246, 214, 104), "3": (222, 172, 58), "4": (168, 118, 34), "5": (110, 72, 22)}

COIN = [
    ".1122.",
    "122233",
    "123334",
    "233344",
    ".4455.",
]

SMALL_HEAP = [
    ".....1122.....",
    "...11223323...",
    "..1223343334..",
    ".122334233344.",
    "12233423334445",
    "22334433444455",
    ".334445444555.",
    "..4455555555..",
]

BIG_HEAP = [
    "........11222.........",
    "......112233322.......",
    "....1122334233333.....",
    "...122233423334434....",
    "..12233342333444344...",
    ".1223334233344434445..",
    "122333423334444344455.",
    "2233344333444443444555",
    ".33344443344444445555.",
    "..444455544445555555..",
    "....5555555555555.....",
]

# Each stage: coins and heaps, (rows, left, top), drawn in order (later ones in front).
LAYOUTS = (
    [(COIN, 13, 15)],
    [(COIN, 9, 17), (COIN, 16, 12)],
    [(COIN, 12, 11), (COIN, 9, 17), (COIN, 16, 16)],
    [(SMALL_HEAP, 9, 14), (COIN, 20, 19)],
    [(SMALL_HEAP, 5, 16), (SMALL_HEAP, 12, 13), (COIN, 21, 20)],
    [(BIG_HEAP, 5, 11), (COIN, 4, 21), (COIN, 22, 22)],
)


def icon(stage):
    """RGBA rows of a 32x32 coin icon for the stage's index in STAGES."""
    pixels = [[None] * 32 for _ in range(32)]
    for rows, left, top in LAYOUTS[stage]:
        for dy, row in enumerate(rows):
            for dx, letter in enumerate(row):
                if letter != ".":
                    pixels[top + dy][left + dx] = GOLD[letter] + (255,)
    return pixels
