"""Bases from the OpenTibia sprite pack (CC BY 4.0, assets/third_party/opentibia_sprite_pack/,
see assets/third_party/CREDITS.md), turned into Brimholt's own variants.

A variant takes one pack sprite, moves each colour region (a hue family, or the neutral greys)
onto the item's own colour while keeping the pack's shading, then applies the item's edits.
Nothing is shipped from the pack untouched: every icon is recoloured and reworked here."""
import colorsys
import math
import pathlib
import struct
import zlib

PACK = pathlib.Path(__file__).resolve().parents[2] / "assets/third_party/opentibia_sprite_pack"
SHEETS: dict[str, list[list[tuple[int, int, int] | None]]] = {}


def _sheet(name: str) -> list[list[tuple[int, int, int] | None]]:
    """RGB rows of a pack sheet (8-bit RGB or RGBA PNG); magenta and transparent are None."""
    if name in SHEETS:
        return SHEETS[name]
    data = (PACK / name).read_bytes()
    pos, chunks = 8, []
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        chunks.append((data[pos + 4:pos + 8], data[pos + 8:pos + 8 + length]))
        pos += 12 + length
    width, height, depth, kind = struct.unpack(">IIBB", chunks[0][1][:10])
    bpp = {6: 4, 2: 3}[kind]
    if depth != 8:
        raise ValueError(f"{name}: expected 8-bit colour")
    raw = zlib.decompress(b"".join(body for tag, body in chunks if tag == b"IDAT"))
    stride, at, previous, rows = width * bpp, 0, bytearray(width * bpp), []
    for _ in range(height):
        kind, row = raw[at], bytearray(raw[at + 1:at + 1 + stride])
        at += 1 + stride
        for x in range(stride):
            a = row[x - bpp] if x >= bpp else 0
            b = previous[x]
            c = previous[x - bpp] if x >= bpp else 0
            if kind == 1:
                row[x] = (row[x] + a) & 255
            elif kind == 2:
                row[x] = (row[x] + b) & 255
            elif kind == 3:
                row[x] = (row[x] + (a + b) // 2) & 255
            elif kind == 4:
                guess = a + b - c
                pa, pb, pc = abs(guess - a), abs(guess - b), abs(guess - c)
                row[x] = (row[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        out = []
        for x in range(width):
            r, g, b = row[x * bpp:x * bpp + 3]
            alpha = row[x * bpp + 3] if bpp == 4 else 255
            out.append(None if alpha < 128 or (r > 200 and b > 200 and g < 60) else (r, g, b))
        rows.append(out)
        previous = row
    SHEETS[name] = rows
    return rows


def sprite(name: str, x0: int, y0: int) -> list[list[tuple[int, int, int] | None]]:
    rows = _sheet(name)
    return [[rows[y0 + y][x0 + x] for x in range(32)] for y in range(32)]


def _hls(rgb: tuple[int, int, int]) -> tuple[float, float, float]:
    return colorsys.rgb_to_hls(*(c / 255 for c in rgb))


def region(rgb: tuple[int, int, int]) -> str:
    """The colour family a pack pixel belongs to: 'k' outline, 'n' neutral, else a hue letter."""
    h, l, s = _hls(rgb)
    if l < 0.09:
        return "k"
    if s < 0.16 or (l > 0.85 and s < 0.35):
        return "n"
    for top, name in ((0.045, "r"), (0.105, "o"), (0.19, "y"), (0.42, "g"), (0.55, "c"), (0.76, "b"), (0.93, "p")):
        if h < top:
            return name
    return "r"


def _hex(code: str) -> tuple[float, float, float]:
    return _hls(tuple(int(code[i:i + 2], 16) for i in (0, 2, 4)))


def _toward(h: float, target: float, f: float) -> float:
    d = ((target - h + 0.5) % 1) - 0.5
    return (h + d * f) % 1


def recolour(base, mapping: dict[str, str], contrast: dict[str, float] | None = None):
    """Each region named in mapping moves onto that hex colour: its mean lightness lands on the
    colour's lightness, its hue and saturation become the colour's, and every pixel keeps its
    offset from the region mean (the pack's shading). Shadows lean violet, lights lean yellow."""
    contrast = contrast or {}
    stats: dict[str, list[tuple[float, float, float]]] = {}
    for row in base:
        for c in row:
            if c:
                stats.setdefault(region(c), []).append(_hls(c))
    means = {k: (sum(v[1] for v in vs) / len(vs), sum(v[2] for v in vs) / len(vs)) for k, vs in stats.items()}
    out = []
    for row in base:
        line = []
        for c in row:
            if c is None:
                line.append(None)
                continue
            k = region(c)
            if k not in mapping:
                line.append(c)
                continue
            h, l, s = _hls(c)
            th, tl, ts = _hex(mapping[k])
            ml, ms = means[k]
            nl = max(0.03, min(0.97, tl + (l - ml) * contrast.get(k, 1.0)))
            ns = min(1.0, ts * max(0.45, min(1.6, s / ms if ms > 0.02 else 1.0))) if ts > 0.02 else s * 0.15
            t = nl - tl
            nh = _toward(th, 0.70, min(0.12, -t * 0.4)) if t < 0 else _toward(th, 0.14, min(0.12, t * 0.4))
            rgb = colorsys.hls_to_rgb(nh, nl, ns)
            line.append(tuple(round(v * 255) for v in rgb))
        out.append(line)
    return out


def flip(img):
    return [list(reversed(r)) for r in img]


def stats(base) -> dict[str, int]:
    counts: dict[str, int] = {}
    for row in base:
        for c in row:
            if c:
                counts[region(c)] = counts.get(region(c), 0) + 1
    return counts


# --- Variants: the pack's model (silhouette, form, light), our pieces, colours, and details ---

def luma(rgb: tuple[int, int, int]) -> float:
    return (rgb[0] * 0.3 + rgb[1] * 0.59 + rgb[2] * 0.11) / 255


def anatomy(base, over: dict | None = None) -> dict:
    """Rows of a legwear model: top, belt end, crotch, knee, ankle, bottom."""
    rows = [y for y in range(32) if any(base[y])]
    top, bot = rows[0], rows[-1]
    def runs(y):
        n, prev = 0, False
        for x in range(16):
            on = base[y][x] is not None and luma(base[y][x]) > 0.09
            n += on and not prev
            prev = on
        return n
    crotch = next((y for y in rows if y > top + 8 and (base[y][15] is None or luma(base[y][15]) <= 0.09 or runs(y) >= 2)), top + 9)
    a = dict(top=top, belt=top + 3, c=crotch, k=crotch + round(0.45 * (bot - crotch)), ankle=bot - 3, bot=bot)
    a.update(over or {})
    return a


ZONES = {
    "belt": lambda y, a: y <= a["belt"],
    "hip": lambda y, a: a["belt"] < y < a["c"],
    "thigh": lambda y, a: a["c"] <= y < a["k"] - 2,
    "knee": lambda y, a: a["k"] - 2 <= y <= a["k"] + 2,
    "shin": lambda y, a: a["k"] + 2 < y < a["ankle"],
    "foot": lambda y, a: y >= a["ankle"],
    "upper": lambda y, a: y < a["c"],
    "leg": lambda y, a: y >= a["c"],
}


def ramp(base: str, n: int = 9, lo: float = 0.06, hi: float = 0.93, shift: float = 0.06):
    """A hue-shifted ramp around one colour: shadows lean violet, lights lean yellow."""
    h, l, s = _hex(base)
    out = []
    for i in range(n):
        t = i / (n - 1)
        hh = _toward(h, 0.70, shift * (1 - t) * 2) if t < 0.5 else _toward(h, 0.14, shift * (t - 0.5) * 2)
        ss = min(1.0, s * (0.75 + 0.5 * (1 - abs(2 * t - 1))))
        out.append(tuple(round(v * 255) for v in colorsys.hls_to_rgb(hh, lo + (hi - lo) * t, ss)))
    return out


def _noise(x: int, y: int, seed: int = 0) -> float:
    n = (x * 374761393 + y * 668265263 + seed * 2246822519) & 0xffffffff
    n = (n ^ (n >> 13)) * 1274126177 & 0xffffffff
    return ((n ^ (n >> 16)) & 0xffff) / 65535.0


TEXTURES = {
    "none": lambda x, y: 0.0,
    "mail": lambda x, y: (0.0, 0.16, 0.06)[(x + (y % 2) * 2) % 3] - 0.07,
    "scale": lambda x, y: 0.2 * ((y % 3) / 2.0) - (0.1 if (x // 2 + y // 3) % 2 == 0 else 0.18),
    "fur": lambda x, y: (_noise(x, y, 2) - 0.5) * 0.4,
    "leather": lambda x, y: (_noise(x, y, 1) - 0.5) * 0.1,
    "quilt": lambda x, y: -0.16 if (x + y) % 4 == 0 or (x - y) % 4 == 0 else 0.03,
    "rings": lambda x, y: -0.14 if (x % 2 == 0 and y % 2 == 0) else 0.04,
    "rust": lambda x, y: -0.22 if _noise(x // 2, y // 2, 5) * 0.7 + _noise(x, y, 6) * 0.4 > 0.8 else 0.0,
}


def fit(base):
    """Centre a model on the icon, then drop the shin rows most like their neighbour until it fits
    rows 1..30 (the icon border stays empty)."""
    cols = [x for x in range(32) if any(base[y][x] for y in range(32))]
    shift = round(15.5 - (cols[0] + cols[-1]) / 2)
    base = [[(r[x - shift] if 0 <= x - shift < 32 else None) for x in range(32)] for r in base]
    rows = [r for r in base if any(r)]
    while len(rows) > 30:
        lo = len(rows) // 2
        diff = lambda i: sum(bool((a is None) != (b is None) or (a and b and sum(abs(p - q) for p, q in zip(a, b)) > 60))
                             for a, b in zip(rows[i], rows[i + 1]))
        del rows[min(range(lo, len(rows) - 4), key=diff)]
    pad = (30 - len(rows)) // 2 + 1
    out = [[None] * 32 for _ in range(32)]
    for i, r in enumerate(rows):
        out[pad + i] = list(r)
    return out


def variant(sheet: str, x0: int, y0: int, design: dict):
    """design:
      paint   [(selector, hex, texture, smooth)] in order; later rules win. A selector is
              'region:zone' (pack colour family k/n/r/o/y/g/c/b/p or *, zone from ZONES or *),
              optionally '|outer<n' / '|inner<n' / '|mid<n' (columns from the leg's edge or centre).
              smooth=True replaces the pack's light inside the painted area by a soft blur (its
              ornaments vanish; our details go on top).
      details [(kind, args...)] our own ornaments, lit by the model (see _detail).
      anatomy row overrides.
    The left half is painted and mirrored, so both legs match."""
    base = fit(sprite(sheet, x0, y0))
    a = anatomy(base, design.get("anatomy"))
    lights = sorted(luma(c) for r in base for c in r if c and luma(c) > 0.09)
    lo, hi = lights[len(lights) // 25], lights[-max(1, len(lights) // 40)]
    V = [[None if c is None else max(0.0, min(1.0, (luma(c) - lo) / (hi - lo + 1e-6))) for c in r] for r in base]
    mat: list[list] = [[None] * 32 for _ in range(32)]
    for sel, hexcode, tex, smooth in design["paint"]:
        reg, _, rest = sel.partition(":")
        zone, *cols = rest.split("|")
        for y in range(32):
            if zone != "*" and not ZONES[zone](y, a):
                continue
            xs = [x for x in range(16) if base[y][x]]
            if not xs:
                continue
            for x in range(16):
                c = base[y][x]
                if c is None or (reg != "*" and region(c) not in reg):
                    continue
                ok = True
                for col in cols:
                    side, n = col.split("<")
                    if side == "outer":
                        ok &= x - xs[0] < int(n)
                    elif side == "mid":
                        ok &= x >= 16 - int(n)
                    elif side == "inner":
                        run_end = x
                        while run_end + 1 < 16 and base[y][run_end + 1]:
                            run_end += 1
                        ok &= run_end - x < int(n)
                if ok:
                    mat[y][x] = (hexcode, tex, smooth)
    out: list[list] = [[None] * 32 for _ in range(32)]
    ramps: dict[str, list] = {}
    for y in range(32):
        for x in range(16):
            c = base[y][x]
            if c is None:
                continue
            m = mat[y][x]
            if m is None:
                out[y][x] = c
                continue
            hexcode, tex, smooth = m
            rp = ramps.setdefault(hexcode, ramp(hexcode))
            if luma(c) <= 0.09:
                out[y][x] = tuple(int(v * 0.45) for v in rp[0])
                continue
            v = V[y][x]
            if smooth:
                s = w = 0.0
                for dy in range(-2, 3):
                    for dx in range(-2, 3):
                        yy, xx = y + dy, x + dx
                        if 0 <= yy < 32 and 0 <= xx < 16 and V[yy][xx] is not None and mat[yy][xx] == m and luma(base[yy][xx]) > 0.09:
                            k = math.exp(-(dx * dx + dy * dy) / 2.5)
                            s += V[yy][xx] * k
                            w += k
                v = s / w if w else v
            v += TEXTURES[tex](x, y)
            out[y][x] = rp[max(0, min(len(rp) - 1, round(v * (len(rp) - 1))))]
    for d in design.get("details", []):
        _detail(out, base, V, a, d, ramps)
    for y in range(32):
        for x in range(16, 32):
            out[y][x] = out[y][31 - x]
    for y, x, hexcode in design.get("over", []):
        out[y][x] = tuple(int(hexcode[i:i + 2], 16) for i in (0, 2, 4))
    return out


def _detail(out, base, V, a, d, ramps):
    """Our ornaments on the left half; each takes the light of the pixel under it."""
    kind, *args = d

    def lit(hexcode, y, x, bias=0.0):
        rp = ramps.setdefault(hexcode, ramp(hexcode))
        v = (V[y][x] if V[y][x] is not None else 0.5) + bias
        return rp[max(0, min(len(rp) - 1, round(v * (len(rp) - 1))))]

    def inside(y, x):
        return 0 <= y < 32 and 0 <= x < 16 and base[y][x] is not None and luma(base[y][x]) > 0.09

    if kind == "gem":  # ("gem", y, x, hex): a 2x2 cut stone, lit top-left
        y, x, hexcode = args
        rp = ramps.setdefault(hexcode, ramp(hexcode))
        for (dy, dx), t in zip(((0, 0), (0, 1), (1, 0), (1, 1)), (8, 5, 4, 1)):
            if inside(y + dy, x + dx):
                out[y + dy][x + dx] = rp[t]
    elif kind == "studs":  # ("studs", row_key_or_y, step, hex)
        y, step, hexcode = args
        y = a[y] if isinstance(y, str) else y
        for x in range(16):
            if inside(y, x) and x % step == 0:
                out[y][x] = lit(hexcode, y, x, 0.35)
    elif kind == "band":  # ("band", y0, y1, hex): a trim band across both legs, bevelled
        y0, y1, hexcode = args
        y0 = a[y0] if isinstance(y0, str) else y0
        y1 = a[y1] if isinstance(y1, str) else y1
        for y in range(y0, y1 + 1):
            for x in range(16):
                if inside(y, x):
                    out[y][x] = lit(hexcode, y, x, 0.2 if y == y0 else -0.25 if y == y1 else 0.0)
    elif kind == "stripe":  # ("stripe", side, width, hex, zone): a trim down the leg edge
        side, width, hexcode, zone = args
        for y in range(32):
            if zone != "*" and not ZONES[zone](y, a):
                continue
            xs = [x for x in range(16) if inside(y, x)]
            if not xs:
                continue
            cols = xs[:width] if side == "outer" else _inner(xs)[-width:]
            for x in cols:
                out[y][x] = lit(hexcode, y, x, 0.1)
    elif kind == "dots":  # ("dots", zone, every, hex, seed): scattered motifs (runes, leaves, spots)
        zone, every, hexcode, seed = args
        for y in range(32):
            if zone != "*" and not ZONES[zone](y, a):
                continue
            for x in range(16):
                if inside(y, x) and _noise(x, y, seed) < 1 / every:
                    out[y][x] = lit(hexcode, y, x, 0.3)
    elif kind == "pix":  # ("pix", [(y, x)], hex, bias): hand-placed lit pixels
        pts, hexcode, bias = args
        for y, x in pts:
            if inside(y, x):
                out[y][x] = lit(hexcode, y, x, bias)
    elif kind == "raw":  # ("raw", [(y, x)], hex): exact colour
        pts, hexcode = args
        for y, x in pts:
            out[y][x] = tuple(int(hexcode[i:i + 2], 16) for i in (0, 2, 4))


def _inner(xs: list[int]) -> list[int]:
    """The first run of a row (the leg itself, not a hanging flap)."""
    run = [xs[0]]
    for x in xs[1:]:
        if x != run[-1] + 1:
            break
        run.append(x)
    return run
