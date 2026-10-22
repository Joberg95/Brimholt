"""Hand-pixelled axes (pixel.py): each axe a 32x32 tone grid drawn pixel by pixel in the OpenTibia
pack's manner (reference only) and Brimholt's flavour pillars. Rows are (column, tones) pieces.
"""
from pixel import grid, palette

# Runes and old stone: a borderland bearded axe. An iron head filling the top-left, its edge honed
# bright along the outer contour with a dark grind line inside it, the cheek light at the top-left and
# dark at the eye, two silver runes inlaid; the beard hooking down to a heel; a bronze knotwork eye with
# an iron poll behind; a steep wooden haft, a bronze-banded grip, an iron knob.
BEARDED_AXE = grid([
    [],
    [],
    [(15, "BCDCB")],
    [(9, "677776"), (15, "CEBDB"), (20, "876")],
    [(5, "9877766554"), (15, "BD9CA"), (20, "765")],
    [(3, "983776655443"), (15, "ACEDB"), (20, "654")],
    [(2, "9836776554332"), (15, "BDCEC"), (20, "543")],
    [(2, "9835676544332"), (15, "CEBDB"), (20, "32")],
    [(1, "98355675S34S22"), (15, "BD9CA")],
    [(1, "98345566SS3SS2"), (15, "ACEDB")],
    [(1, "98344556S3SS22"), (15, "ABCBA")],
    [(1, "98344355S32S23"), (19, "bec")],
    [(1, "98343354S32S2"), (19, "bec")],
    [(1, "973435432221"), (20, "bec")],
    [(1, "973443322211"), (20, "bec")],
    [(2, "9734432211"), (21, "bec")],
    [(2, "9733432211"), (21, "bec")],
    [(2, "973342211"), (22, "bec")],
    [(3, "97333211"), (22, "bec")],
    [(3, "96432111"), (23, "bec")],
    [(4, "9643211"), (23, "BDC")],
    [(5, "865211"), (24, "bec")],
    [(6, "7621"), (24, "BDC")],
    [(8, "52"), (25, "bec")],
    [(25, "BDC")],
    [(26, "bec")],
    [(27, "BDC")],
    [(27, "bec")],
    [(28, "786")],
    [(28, "674")],
    [(29, "53")],
    [],
])

BEARDED_AXE_COLOURS = palette(**{
    "123456789": ("1a1d24", "f2f4f7"),   # iron, cool grey
    "abcde": ("3a2412", "c8925a"),       # ash wood
    "ABCDE": ("4a2a10", "f4c878"),       # bronze knotwork
    "S": ("e8f6ff", "e8f6ff"),           # silver inlay
})

DESIGNS = {"bearded_axe": (BEARDED_AXE, BEARDED_AXE_COLOURS)}
