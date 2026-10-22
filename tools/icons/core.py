"""The icon core: a 32x32 canvas, hue-shifted material ramps, three shading primitives, and the black
outline, in the OpenTibia sprite pack's style (docs/plan/48-item-icons-remake.md): smooth many-tone
shading lit from the top-left, extreme contrast, a pure black outline round the silhouette, and
almost no black inside. Our own drawings; the pack is reference only.

Primitives:
  stroke   a band along a curve with a width profile and a tone profile across it (blades, hafts,
           grips, bow limbs): the stylised cross-section the pack shades its blades with.
  ball     an ellipsoid lit as a solid, with a specular glint (pommels, gems, mace heads, rivets).
  dome     any mask lit as a cushion rising from its edge (plates, shields, guards, armour).
Later parts draw over earlier ones; render() maps tones through each material's ramp and adds the
outline.
"""
import colorsys
import math
import pathlib
import struct
import zlib

SIZE = 32
LIGHT = (-0.55, -0.62, 0.56)  # towards the light: up and to the left, and out of the picture
STEPS = 18  # tone steps per material (the pack's steel shows about 20)


def _norm(v):
    length = math.sqrt(sum(c * c for c in v)) or 1.0
    return tuple(c / length for c in v)


L = _norm(LIGHT)

# ------------------------------------------------------------------------- the diagonal
# Weapons lie on the icon's diagonal like the pack's: AXIS runs from the top-left end towards the
# bottom-right, ACROSS at right angles towards the upper right.
AXIS = (math.sqrt(0.5), math.sqrt(0.5))
ACROSS = (math.sqrt(0.5), -math.sqrt(0.5))


def at(origin, along, across=0.0):
    """The point `along` pixels down the diagonal and `across` pixels to its upper right."""
    return (origin[0] + AXIS[0] * along + ACROSS[0] * across, origin[1] + AXIS[1] * along + ACROSS[1] * across)


def piecewise(points):
    """A tone profile through (u, value) points, linear between them (u -1 .. 1 across a stroke)."""
    def f(u, *_):
        for (u0, v0), (u1, v1) in zip(points, points[1:]):
            if u <= u1:
                return v0 + (v1 - v0) * (u - u0) / max(1e-6, u1 - u0)
        return points[-1][1]
    return f


# A rod lit from above: grips, hafts, shafts, quillons.
ROUND = piecewise([(-1, 0.15), (-0.35, 0.5), (0.3, 1.0), (1, 0.42)])


def to_local(centre, x, y):
    """(along, across) of pixel (x, y)'s centre from `centre`, along and across the diagonal."""
    dx, dy = x + 0.5 - centre[0], y + 0.5 - centre[1]
    return dx * AXIS[0] + dy * AXIS[1], dx * ACROSS[0] + dy * ACROSS[1]


def local(centre, inside):
    """The pixels whose centres satisfy inside(along, across), in coordinates along and across the
    diagonal from `centre`: shapes drawn square to a haft (axe blades, hammer heads)."""
    cells = set()
    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = x + 0.5 - centre[0], y + 0.5 - centre[1]
            if inside(dx * AXIS[0] + dy * AXIS[1], dx * ACROSS[0] + dy * ACROSS[1]):
                cells.add((x, y))
    return cells


# ------------------------------------------------------------------------------- materials
# A material is a ramp from its darkest to its lightest tone: (hue, saturation, lightness) at the
# shadow end and at the light end. Shadows lean cool, lights warm, like the pack's gold.
MATERIALS = {
    "steel": ((0.60, 0.10, 0.10), (0.55, 0.06, 0.95)),
    "darksteel": ((0.66, 0.14, 0.06), (0.60, 0.08, 0.70)),
    "iron": ((0.62, 0.08, 0.10), (0.10, 0.06, 0.82)),
    "gold": ((0.075, 0.80, 0.14), (0.135, 0.95, 0.88)),
    "bronze": ((0.05, 0.62, 0.12), (0.10, 0.70, 0.78)),
    "copper": ((0.02, 0.62, 0.12), (0.06, 0.66, 0.78)),
    "silver": ((0.62, 0.12, 0.16), (0.58, 0.10, 0.97)),
    "wood": ((0.04, 0.55, 0.08), (0.08, 0.50, 0.62)),
    "leather": ((0.03, 0.50, 0.07), (0.07, 0.45, 0.55)),
    "bone": ((0.08, 0.30, 0.18), (0.13, 0.45, 0.92)),
    "obsidian": ((0.75, 0.30, 0.04), (0.70, 0.22, 0.60)),
    # Brimholt's own materials (plan 46 flavour pillars): old stone, bog bronze, ember and lake, the Hollow.
    "runestone": ((0.36, 0.10, 0.10), (0.20, 0.10, 0.80)),
    "verdigris": ((0.46, 0.38, 0.12), (0.40, 0.42, 0.70)),
    "emberglass": ((0.99, 0.75, 0.06), (0.04, 0.85, 0.50)),
    "glow_ember": ((0.03, 1.00, 0.45), (0.13, 1.00, 0.92)),
    "hollowglass": ((0.76, 0.40, 0.05), (0.78, 0.35, 0.55)),
    "glow_hollow": ((0.77, 0.90, 0.45), (0.80, 1.00, 0.92)),
    "glow_rune": ((0.53, 0.90, 0.45), (0.50, 1.00, 0.92)),
    "glow_moss": ((0.30, 0.90, 0.40), (0.25, 1.00, 0.88)),
    "moss": ((0.31, 0.65, 0.14), (0.24, 0.75, 0.62)),
    "reed": ((0.16, 0.45, 0.14), (0.12, 0.50, 0.72)),
    "lakestone": ((0.62, 0.70, 0.10), (0.55, 0.65, 0.70)),
    "banner": ((0.99, 0.70, 0.12), (0.02, 0.75, 0.62)),
}


def material(hexcode, spread=0.42):
    """A ramp around an item colour: its own hue and lightness in the middle, cooler and darker in
    shadow, warmer and lighter in the light."""
    r, g, b = (int(hexcode[i:i + 2], 16) / 255 for i in (0, 2, 4))
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    warm = 0.14 if 0.0 <= h < 0.45 or h > 0.92 else 0.66
    toward = lambda target, f: (h + (((target - h + 0.5) % 1) - 0.5) * f) % 1
    return ((toward(0.68, 0.05), min(1.0, s * 1.05), max(0.04, l - spread)),
            (toward(warm, 0.06), min(1.0, s * 1.15), min(0.97, l + spread * 0.9)))


def color(name, tone):
    """RGB of a tone (0 darkest .. 1 lightest) of a material (a MATERIALS name or a hex code)."""
    (h0, s0, l0), (h1, s1, l1) = MATERIALS.get(name) or material(name)
    t = round(max(0.0, min(1.0, tone)) * (STEPS - 1)) / (STEPS - 1)
    dh = ((h1 - h0 + 0.5) % 1) - 0.5
    rgb = colorsys.hls_to_rgb((h0 + dh * t) % 1, l0 + (l1 - l0) * t, s0 + (s1 - s0) * t)
    return tuple(round(c * 255) for c in rgb)


# ---------------------------------------------------------------------------------- canvas
class Icon:
    """A 32x32 drawing: each pixel has a material and a tone (0..1), or nothing."""

    def __init__(self):
        self.mat = [[None] * SIZE for _ in range(SIZE)]
        self.tone = [[0.0] * SIZE for _ in range(SIZE)]

    def put(self, x, y, mat, tone):
        if 0 <= x < SIZE and 0 <= y < SIZE:
            self.mat[y][x] = mat
            self.tone[y][x] = tone

    def stroke(self, points, width, profile, mat, shine=0.0, ends=(0.0, 0.0), pattern=None):
        """A band along a polyline (points in pixel coordinates, at least two). width(s) is its
        half-width at s (0 at the first point, 1 at the last); profile(u) its tone across it, u from
        -1 (the side on the left of the direction of travel) to 1. shine adds a lengthwise sheen
        toward the first point; ends darkens the first and last few pixels; pattern(length, u) adds
        to the tone by the distance in pixels from the first point (wraps, bands, engraving)."""
        samples = _resample(points, 64)
        total = sum(_dist(a, b) for a, b in zip(samples, samples[1:]))
        cumulative = [0.0]
        for a, b in zip(samples, samples[1:]):
            cumulative.append(cumulative[-1] + _dist(a, b))
        xs = [p[0] for p in samples]
        ys = [p[1] for p in samples]
        reach = max(width(s / 10) for s in range(11)) + 1
        for y in range(max(0, int(min(ys) - reach)), min(SIZE, int(max(ys) + reach) + 1)):
            for x in range(max(0, int(min(xs) - reach)), min(SIZE, int(max(xs) + reach) + 1)):
                px, py = x + 0.5, y + 0.5
                best = None
                for i, (a, b) in enumerate(zip(samples, samples[1:])):
                    t, d, side = _project(px, py, a, b)
                    if best is None or d < best[0]:
                        best = (d, (cumulative[i] + t * _dist(a, b)) / total, side)
                d, s, side = best
                half = width(s)
                if half <= 0 or d > half:
                    continue
                u = side * d / half
                tone = profile(u) + shine * (1 - s) * 0.25
                length = s * total
                if pattern:
                    tone += pattern(length, u)
                if length < ends[0]:
                    tone -= 0.25 * (1 - length / max(ends[0], 0.01))
                if total - length < ends[1]:
                    tone -= 0.25 * (1 - (total - length) / max(ends[1], 0.01))
                self.put(x, y, mat, tone)

    def ball(self, cx, cy, rx, ry, mat, glint=True, flat=0.0):
        """An ellipsoid centred on (cx, cy), lit as a solid; flat squashes its depth (a disc)."""
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                rr = nx * nx + ny * ny
                if rr > 1.0:
                    continue
                nz = math.sqrt(1 - rr) * (1 - flat) + flat
                tone = _lit(_norm((nx, ny, nz)))
                if glint and rr < 0.18 and nx < -0.05 and ny < -0.05:
                    tone += 0.25
                self.put(x, y, mat, tone)

    def dome(self, mask, mat, height=2.5, base=0.0):
        """Fills a set of (x, y) pixels lit as a cushion rising from its edge (height in pixels)."""
        cells = set(mask)
        depth = _distance(cells)
        for (x, y) in cells:
            hx = depth.get((x + 1, y), 0) - depth.get((x - 1, y), 0)
            hy = depth.get((x, y + 1), 0) - depth.get((x, y - 1), 0)
            k = height / max(1.0, max(depth.values()))
            n = _norm((-hx * k, -hy * k, 1.0))
            self.put(x, y, mat, _lit(n) + base)

    def shade(self, cells, amount):
        """Darkens (negative) or lightens existing pixels: seams, grooves, inlays."""
        for (x, y) in cells:
            if 0 <= x < SIZE and 0 <= y < SIZE and self.mat[y][x] is not None:
                self.tone[y][x] += amount

    def render(self):
        """RGBA rows: each pixel its material's tone, then a pure black outline round the silhouette
        (outside it, on all four sides)."""
        out = [[None] * SIZE for _ in range(SIZE)]
        for y in range(SIZE):
            for x in range(SIZE):
                if self.mat[y][x] is not None:
                    out[y][x] = color(self.mat[y][x], self.tone[y][x]) + (255,)
        for y in range(SIZE):
            for x in range(SIZE):
                if self.mat[y][x] is None and any(0 <= x + dx < SIZE and 0 <= y + dy < SIZE
                                                  and self.mat[y + dy][x + dx] is not None
                                                  for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    out[y][x] = (0, 0, 0, 255)
        return out


def _lit(n):
    """Tone of a surface normal: a little ambient, Lambert light, and a sharp highlight."""
    diffuse = max(0.0, sum(a * b for a, b in zip(n, L)))
    reflect = 2 * n[2] * diffuse - L[2]
    spec = max(0.0, reflect) ** 12 if diffuse > 0 else 0.0
    return 0.12 + 0.72 * diffuse + 0.35 * spec


def _dist(a, b):
    return math.hypot(b[0] - a[0], b[1] - a[1])


def _project(px, py, a, b):
    """(t along a->b clamped, distance, side: -1 left of travel, 1 right) of a point."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    length2 = dx * dx + dy * dy or 1e-9
    t = max(0.0, min(1.0, ((px - a[0]) * dx + (py - a[1]) * dy) / length2))
    qx, qy = a[0] + t * dx, a[1] + t * dy
    cross = dx * (py - a[1]) - dy * (px - a[0])
    return t, math.hypot(px - qx, py - qy), 1 if cross > 0 else -1


def _resample(points, n):
    """n points evenly along a polyline (a quadratic curve when given three points)."""
    if len(points) == 3:
        (x0, y0), (x1, y1), (x2, y2) = points
        return [((1 - t) ** 2 * x0 + 2 * (1 - t) * t * x1 + t * t * x2,
                 (1 - t) ** 2 * y0 + 2 * (1 - t) * t * y1 + t * t * y2) for t in (i / (n - 1) for i in range(n))]
    return list(points)


def _distance(cells):
    """Chessboard distance of each cell to the outside of the set (1 on the edge)."""
    depth = {c: 0 for c in cells}
    frontier = [c for c in cells if any((c[0] + dx, c[1] + dy) not in cells
                                        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for c in frontier:
        depth[c] = 1
    level = 1
    while frontier:
        level += 1
        nxt = []
        for (x, y) in frontier:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                c = (x + dx, y + dy)
                if c in depth and depth[c] == 0:
                    depth[c] = level
                    nxt.append(c)
        frontier = nxt
    return depth


# --------------------------------------------------------------------------------- output
def save_png(path, rows):
    """Writes RGBA rows (None for transparent) as a PNG."""
    height, width = len(rows), len(rows[0])
    raw = b"".join(b"\0" + bytes(v for p in row for v in (p if p else (0, 0, 0, 0))) for row in rows)

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)
    pathlib.Path(path).parent.mkdir(parents=True, exist_ok=True)
    pathlib.Path(path).write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
                                   + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def sheet(icons, columns, scale=1, background=None):
    """Icons (RGBA rows) in a grid, optionally scaled up and on a background colour."""
    rows_n = (len(icons) + columns - 1) // columns
    out = [[background] * (columns * SIZE * scale) for _ in range(rows_n * SIZE * scale)]
    for index, icon in enumerate(icons):
        ox, oy = (index % columns) * SIZE * scale, (index // columns) * SIZE * scale
        for y in range(SIZE):
            for x in range(SIZE):
                if icon[y][x]:
                    for dy in range(scale):
                        for dx in range(scale):
                            out[oy + y * scale + dy][ox + x * scale + dx] = icon[y][x]
    return out
