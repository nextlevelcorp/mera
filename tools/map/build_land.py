#!/usr/bin/env python3
"""Builds game/data/map/land.json from Natural Earth 1:10m land polygons.

Natural Earth is public domain (https://www.naturalearthdata.com/about/terms-of-use/).
Input: ne_10m_land.geojson from
https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_land.geojson
Usage: python3 tools/map/build_land.py <ne_10m_land.geojson> game/data/map/land.json

Each polygon ring is clipped to the box the game's countries need
(Sutherland-Hodgman against the four edges), simplified with Douglas-Peucker
and written as flat [lon, lat, lon, lat, ...] lists rounded to 4 decimals.
"""
import json
import sys

BOX = (-14.0, 30.0, 40.0, 49.0)   # min lon, min lat, max lon, max lat
TOLERANCE = 0.004                # degrees, about 400 m


def clip(ring, box):
    def inside(p, edge):
        x, y = p
        return [x >= box[0], y >= box[1], x <= box[2], y <= box[3]][edge]

    def cross(a, b, edge):
        (x1, y1), (x2, y2) = a, b
        if edge in (0, 2):
            x = box[edge]
            t = (x - x1) / (x2 - x1)
            return (x, y1 + t * (y2 - y1))
        y = box[edge]
        t = (y - y1) / (y2 - y1)
        return (x1 + t * (x2 - x1), y)

    out = ring
    for edge in range(4):
        if not out:
            break
        src, out = out, []
        prev = src[-1]
        for cur in src:
            if inside(cur, edge):
                if not inside(prev, edge):
                    out.append(cross(prev, cur, edge))
                out.append(cur)
            elif inside(prev, edge):
                out.append(cross(prev, cur, edge))
            prev = cur
    return out


def simplify(pts, tol):
    if len(pts) < 3:
        return pts
    keep = [False] * len(pts)
    keep[0] = keep[-1] = True
    stack = [(0, len(pts) - 1)]
    while stack:
        a, b = stack.pop()
        (x1, y1), (x2, y2) = pts[a], pts[b]
        dx, dy = x2 - x1, y2 - y1
        norm = (dx * dx + dy * dy) ** 0.5
        best, idx = 0.0, -1
        for i in range(a + 1, b):
            x, y = pts[i]
            # A closed ring starts and ends on one point: measure from it.
            d = abs(dy * (x - x1) - dx * (y - y1)) / norm if norm > 1e-12 else ((x - x1) ** 2 + (y - y1) ** 2) ** 0.5
            if d > best:
                best, idx = d, i
        if best > tol and idx > 0:
            keep[idx] = True
            stack += [(a, idx), (idx, b)]
    return [p for p, k in zip(pts, keep) if k]


def main(src, dst):
    data = json.load(open(src))
    rings = []
    for f in data["features"]:
        g = f["geometry"]
        polys = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
        for poly in polys:
            outer = [tuple(p[:2]) for p in poly[0]]
            xs = [p[0] for p in outer]
            ys = [p[1] for p in outer]
            if max(xs) < BOX[0] or min(xs) > BOX[2] or max(ys) < BOX[1] or min(ys) > BOX[3]:
                continue
            r = simplify(clip(outer, BOX), TOLERANCE)
            if len(r) >= 4:
                rings.append([round(v, 4) for p in r for v in p])
    out = {
        "source": "Natural Earth 1:10m land (ne_10m_land), public domain: https://www.naturalearthdata.com/about/terms-of-use/",
        "box": list(BOX), "tolerance_deg": TOLERANCE, "rings": rings,
    }
    json.dump(out, open(dst, "w"), separators=(",", ":"))
    print(len(rings), "rings,", sum(len(r) // 2 for r in rings), "points")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
