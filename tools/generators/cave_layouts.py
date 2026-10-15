#!/usr/bin/env python3
"""Grows an organic cave layout for an instanced dungeon and writes it into game/data/dungeons.gd.

Irregular chambers joined by winding two-wide tunnels are carved out of rock; only the
largest connected cave is kept. The stairs up ("^") and the arrival ("@") go to the cave's north-west end, the
boss to the open chamber farthest from them, and the monsters in packs through the rest, never
near the stairs. The same seed always gives the same cave. Python standard library only.

    python tools/generators/cave_layouts.py highmoor_mine --size 54x36 --seed 7 \\
        --monsters c:30,e:22 --boss F

Then run tools/generators/dungeons.gd (make dungeons) to paint the copies, and the rules check.
"""
import argparse
import random
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DUNGEONS = ROOT / "game" / "data" / "dungeons.gd"
NEIGHBOURS = [(dx, dy) for dy in (-1, 0, 1) for dx in (-1, 0, 1) if (dx, dy) != (0, 0)]
STEPS = ((1, 0), (-1, 0), (0, 1), (0, -1))


def grow(width, height, rng, chambers=16, fill=0.0):
    """Chambers joined by winding tunnels, as Tibia caves are: irregular blobs of open floor,
    linked along a spanning tree (plus a couple of loops) by two-wide tunnels that wander, then
    roughened so no edge is straight. `fill` is unused (kept for older command lines)."""
    rock = [[True] * width for _ in range(height)]

    def carve(x, y):
        if 1 <= x < width - 1 and 1 <= y < height - 1:
            rock[y][x] = False

    centres = []
    for _ in range(chambers * 40):
        if len(centres) == chambers:
            break
        c = (rng.randrange(5, width - 5), rng.randrange(4, height - 4))
        if all(abs(c[0] - o[0]) + abs(c[1] - o[1]) >= 11 for o in centres):
            centres.append(c)
    for cx, cy in centres:
        rx, ry = rng.uniform(3.5, 6.5), rng.uniform(2.5, 4.5)
        for y in range(int(cy - ry - 2), int(cy + ry + 3)):
            for x in range(int(cx - rx - 2), int(cx + rx + 3)):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0 + rng.uniform(-0.25, 0.25):
                    carve(x, y)
    # A spanning tree by nearest links, then two extra links for loops.
    linked, links = [centres[0]], []
    rest = centres[1:]
    while rest:
        a, b = min(((a, b) for a in linked for b in rest), key=lambda pair: abs(pair[0][0] - pair[1][0]) + abs(pair[0][1] - pair[1][1]))
        links.append((a, b))
        linked.append(b)
        rest.remove(b)
    for _ in range(2):
        links.append(tuple(rng.sample(centres, 2)))
    for (ax, ay), (bx, by) in links:
        x, y = ax, ay
        while (x, y) != (bx, by):
            if rng.random() < 0.3:
                x += rng.choice((-1, 1))
            elif rng.random() < 0.3:
                y += rng.choice((-1, 1))
            elif abs(bx - x) > abs(by - y):
                x += 1 if bx > x else -1
            else:
                y += 1 if by > y else -1
            x, y = max(2, min(width - 3, x)), max(2, min(height - 3, y))
            carve(x, y)
            carve(x + 1, y)
            carve(x, y + 1)
    # Roughen: bite into straight walls a little, and fill single pockets of floor.
    for _ in range(2):
        nxt = [row[:] for row in rock]
        for y in range(1, height - 1):
            for x in range(1, width - 1):
                walls = sum(rock[y + dy][x + dx] for dx, dy in NEIGHBOURS)
                if not rock[y][x] and walls >= 7:
                    nxt[y][x] = True
                elif rock[y][x] and walls <= 4 and rng.random() < 0.5:
                    nxt[y][x] = False
        rock = nxt
    return rock


def regions(rock):
    """Connected open regions, largest first."""
    height, width = len(rock), len(rock[0])
    seen, found = set(), []
    for y in range(height):
        for x in range(width):
            if rock[y][x] or (x, y) in seen:
                continue
            region, queue = [], deque([(x, y)])
            seen.add((x, y))
            while queue:
                cx, cy = queue.popleft()
                region.append((cx, cy))
                for dx, dy in STEPS:
                    nx, ny = cx + dx, cy + dy
                    if not rock[ny][nx] and (nx, ny) not in seen:
                        seen.add((nx, ny))
                        queue.append((nx, ny))
            found.append(region)
    return sorted(found, key=len, reverse=True)


def distances(open_cells, start):
    dist = {start: 0}
    queue = deque([start])
    while queue:
        cx, cy = queue.popleft()
        for dx, dy in STEPS:
            nxt = (cx + dx, cy + dy)
            if nxt in open_cells and nxt not in dist:
                dist[nxt] = dist[(cx, cy)] + 1
                queue.append(nxt)
    return dist


def roomy(open_cells, cell, radius=1):
    return all((cell[0] + dx, cell[1] + dy) in open_cells for dy in range(-radius, radius + 1) for dx in range(-radius, radius + 1))


def layout(width, height, seed, monsters, boss, fill=0.46):
    rng = random.Random(seed)
    for attempt in range(200):
        rock = grow(width, height, rng)
        found = regions(rock)
        cave = set(found[0])
        if len(cave) > width * height * 0.25:
            break
    else:
        raise SystemExit("no cave large enough; try another seed or size")
    rows = [["#" if (x, y) not in cave else "." for x in range(width)] for y in range(height)]
    # Stairs and arrival at the north-west end: the open cell nearest the top-left corner whose
    # east neighbour is open too.
    start = min((c for c in cave if (c[0] + 1, c[1]) in cave and roomy(cave, (c[0] + 1, c[1]))),
                key=lambda c: c[0] + c[1])
    arrival = (start[0] + 1, start[1])
    rows[start[1]][start[0]] = "^"
    rows[arrival[1]][arrival[0]] = "@"
    dist = distances(cave, arrival)
    lair = max((c for c in cave if roomy(cave, c, 2)), key=lambda c: dist.get(c, -1))
    rows[lair[1]][lair[0]] = boss
    # Monsters in packs of 2-4 through the cave, at least 7 steps from the stairs and 2 apart.
    taken = {start, arrival, lair}
    spots = sorted((c for c in cave if dist.get(c, 0) >= 7 and roomy(cave, c) and abs(c[0] - lair[0]) + abs(c[1] - lair[1]) > 3),
                   key=lambda c: rng.random())
    wanted = [symbol for symbol, count in monsters for _ in range(count)]
    rng.shuffle(wanted)
    for spot in spots:
        if not wanted:
            break
        if any(abs(spot[0] - other[0]) <= 1 and abs(spot[1] - other[1]) <= 1 for other in taken):
            continue
        rows[spot[1]][spot[0]] = wanted.pop()
        taken.add(spot)
    if wanted:
        raise SystemExit("room for all but %d monsters; make the cave larger" % len(wanted))
    return ["".join(row) for row in rows]


def write(dungeon, rows):
    text = DUNGEONS.read_text(encoding="utf-8")
    start = text.index('\t"%s": {' % dungeon)
    begin = text.index('"rows": [', start)
    end = text.index("\t\t],", begin)
    block = '"rows": [\n' + "".join('\t\t\t"%s",\n' % row for row in rows)
    DUNGEONS.write_text(text[:begin] + block + text[end:], encoding="utf-8", newline="\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("dungeon")
    parser.add_argument("--size", default="54x36")
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--monsters", required=True, help="symbol:count,... e.g. c:30,e:22")
    parser.add_argument("--boss", required=True)
    parser.add_argument("--fill", type=float, default=0.46, help="starting share of rock: more gives narrower passages")
    args = parser.parse_args()
    width, height = (int(v) for v in args.size.split("x"))
    monsters = [(part.split(":")[0], int(part.split(":")[1])) for part in args.monsters.split(",")]
    rows = layout(width, height, args.seed, monsters, args.boss, args.fill)
    write(args.dungeon, rows)
    print("\n".join(rows))
    print("wrote %s: %dx%d, %d open tiles" % (args.dungeon, width, height, sum(row.count(".") for row in rows)))


if __name__ == "__main__":
    main()
