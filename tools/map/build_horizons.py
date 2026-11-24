#!/usr/bin/env python3
"""Builds game/data/map/horizons.json: the skyline each spot sees, by bearing.

For every spot (and every boat position, from a point out on the water) a ray
is cast every degree of bearing over the land. Where the ray is over land the
ground height is modelled and the highest angle above the eye is kept, with
the Earth's curvature and normal refraction taken off. So a far shore, a
headland or a mountain stands where it stands in the real place.

Sources:
- Coast: Natural Earth 1:10m land (public domain), ne_10m_land.geojson from
  https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_land.geojson
- Peaks: Wikidata (CC0), mountains and hills of at least 100 m within 45 km of
  each spot, with their coordinates and elevations, in tools/map/peaks.json
  (fetched by tools/map/fetch_peaks.py).
- Design fill (no elevation model yet): the ground between the peaks, the cone
  each peak stands on and the height of the town along the shore, in
  TERRAIN below.

Usage: python3 tools/map/build_horizons.py <ne_10m_land.geojson> tools/map/peaks.json \
    game/data/spots.json game/data/map/horizons.json
"""
import json
import math
import sys

sys.path.insert(0, __import__('os').path.dirname(__file__))
from build_land import clip  # noqa: E402

R_EARTH = 6371000.0
REFRACTION = 0.13            # standard terrestrial refraction coefficient
EYE_M = 2.0                  # eye above the water
MAX_KM = 60.0                # rays end here
STEP_M = 100.0               # ground samples along a ray over land
START_SKIP_M = 400.0         # a spot on the shore line: skip the land it stands on
WATER_IN_M = 30.0            # metres out from the coast line, where a shore position stands
BOAT_OUT_M = 400.0           # a boat position is this far out along its facing
MAX_ELEV = 0.12              # rad; the texture's range (mountains)
NEAR_M = 2000.0              # land nearer than this is the shore the angler stands on or beside:
NEAR_ELEV = 0.035            # rad; its top is kept low, a waterfront and not a cliff (design fill)
PEAK_SLOPE = 6.0             # a peak's cone reaches the ground this many times its height away

# Design fill per spot: base_m is the ground's height a few km in from the
# shore, city_m the height of the buildings on the shore band city_km deep.
TERRAIN = {
    "galata_bridge": {"base_m": 80, "city_m": 30, "city_km": 4.0},
    "sarayburnu": {"base_m": 80, "city_m": 30, "city_km": 4.0},
    "izmir_kordon": {"base_m": 120, "city_m": 30, "city_km": 3.0},
    "puerto_banus": {"base_m": 120, "city_m": 15, "city_km": 1.0},
    "maro": {"base_m": 200, "city_m": 0, "city_km": 0.0},
    "almeria_espigon": {"base_m": 120, "city_m": 20, "city_km": 2.0},
    "napoli_moli": {"base_m": 120, "city_m": 30, "city_km": 3.0},
    "trieste_audace": {"base_m": 250, "city_m": 25, "city_km": 1.5},
    "genova_corso_italia": {"base_m": 250, "city_m": 25, "city_km": 1.5},
    "thessaloniki_paralia": {"base_m": 60, "city_m": 25, "city_km": 2.5},
    "kavala_port": {"base_m": 150, "city_m": 15, "city_km": 1.0},
    "patras_port": {"base_m": 150, "city_m": 20, "city_km": 2.0},
    "sesimbra_port": {"base_m": 150, "city_m": 10, "city_km": 0.5},
    "lagos_pier": {"base_m": 60, "city_m": 12, "city_km": 1.0},
    "cascais_bay": {"base_m": 80, "city_m": 15, "city_km": 1.5},
}
BASE_RAMP_M = 1500.0         # the ground rises to base_m over about this distance inland

DIRS = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]


def load_edges(path, lat0, lon0, span):
    """Coast segments within the box round (lat0, lon0), in local metres.
    Each ring is clipped to the box first (build_land.clip), so every piece is
    a closed ring and the inside test stays right at the box's edge."""
    kx = math.cos(math.radians(lat0)) * math.pi / 180.0 * R_EARTH
    ky = math.pi / 180.0 * R_EARTH
    dlon = span / math.cos(math.radians(lat0))
    box = (lon0 - dlon, lat0 - span, lon0 + dlon, lat0 + span)
    edges = []
    for feat in json.load(open(path))["features"]:
        geom = feat["geometry"]
        polys = geom["coordinates"] if geom["type"] == "MultiPolygon" else [geom["coordinates"]]
        for poly in polys:
            for ring in poly:
                xs = [p[0] for p in ring]
                ys = [p[1] for p in ring]
                if max(xs) < box[0] or min(xs) > box[2] or max(ys) < box[1] or min(ys) > box[3]:
                    continue
                cut = clip([(p[0], p[1]) for p in ring], box)
                pts = [((lon - lon0) * kx, (lat - lat0) * ky) for lon, lat in cut]
                for i in range(len(pts)):
                    a, b = pts[i - 1], pts[i]
                    edges.append((a[0], a[1], b[0], b[1]))
    return edges, kx, ky


def inside(x, y, edges):
    c = False
    for ax, ay, bx, by in edges:
        if (ay > y) != (by > y) and x < ax + (y - ay) * (bx - ax) / (by - ay):
            c = not c
    return c


def crossings(ox, oy, dx, dy, edges, length):
    out = []
    for ax, ay, bx, by in edges:
        ex, ey = bx - ax, by - ay
        den = dx * ey - dy * ex
        if abs(den) < 1e-12:
            continue
        t = ((ax - ox) * ey - (ay - oy) * ex) / den
        u = ((ax - ox) * dy - (ay - oy) * dx) / den
        if 0.0 < t <= length and 0.0 <= u < 1.0:
            out.append(t)
    out.sort()
    return out


def ground(x, y, inland, terrain, peaks):
    h = terrain["base_m"] * (1.0 - math.exp(-inland / BASE_RAMP_M))
    for px, py, pe in peaks:
        d = math.hypot(x - px, y - py)
        h = max(h, pe * (1.0 - d / (pe * PEAK_SLOPE)))
    city = inland < terrain["city_km"] * 1000.0 and terrain["city_m"] > 0
    return h + (terrain["city_m"] if city else 0.0), city


def profile(ox, oy, edges, terrain, peaks):
    start_in = inside(ox, oy, edges)
    length = MAX_KM * 1000.0
    elev, dist, urban = [], [], []
    for b in range(360):
        dx, dy = math.sin(math.radians(b)), math.cos(math.radians(b))
        cuts = crossings(ox, oy, dx, dy, edges, length)
        # Intervals over land along the ray: [enter, leave, distance inland is from enter].
        spans, on, at = [], start_in, 0.0
        for t in cuts + [length]:
            if on:
                spans.append((at, t))
            on, at = not on, t
        if start_in and spans and spans[0][0] == 0.0 and spans[0][1] <= START_SKIP_M:
            spans.pop(0)       # the shore the angler stands on
        best, best_d, best_city = -1.0, 0.0, False
        for a, z in spans:
            s = max(a, STEP_M * 0.5)
            while s <= z:
                inland = min(s - a, z - s) if z < length else s - a
                h, city = ground(ox + dx * s, oy + dy * s, inland, terrain, peaks)
                drop = s * s / (2.0 * R_EARTH) * (1.0 - REFRACTION)
                e = math.atan2(h - drop - EYE_M, s)
                if s < NEAR_M:
                    e = min(e, NEAR_ELEV)
                if e > best:
                    best, best_d, best_city = e, s, city
                s += STEP_M
        if best <= 0.0:
            elev.append(0.0)
            dist.append(0.0)
            urban.append(0)
        else:
            elev.append(round(min(best, MAX_ELEV) * 1000.0, 1))
            dist.append(round(best_d / 1000.0, 1))
            urban.append(1 if best_city else 0)
    return {"elev_mrad": elev, "dist_km": dist, "urban": urban}


def water_origin(facing_rad, edges):
    """The spot's coordinates name a pier or a mole, which the 1:10m coast is
    too coarse to show: the angler stands where the water begins, going out
    along the facing from the spot's point."""
    dx, dy = math.sin(facing_rad), math.cos(facing_rad)
    cuts = crossings(0.0, 0.0, dx, dy, edges, MAX_KM * 1000.0)
    if not inside(0.0, 0.0, edges) or not cuts:
        return 0.0, 0.0
    t = cuts[0] + WATER_IN_M
    return dx * t, dy * t


def main():
    land, peaks_path, spots_path, out_path = sys.argv[1:5]
    peaks_all = json.load(open(peaks_path))["peaks"]
    out = {
        "source": "Coast: Natural Earth 1:10m land (public domain). Peaks: Wikidata (CC0), tools/map/peaks.json. "
                  "Ground between peaks, peak cones and town heights: design fill (tools/map/build_horizons.py TERRAIN).",
        "design_fill": ["ground between peaks", "peak cones", "town height"],
        "step_deg": 1,
        "note": "One profile per position, keyed by position id, seen from where the water begins along the position's facing (a boat position 400 m further out). Arrays run by bearing, 0 = north, clockwise.",
        "profiles": {},
    }
    for spot in json.load(open(spots_path)):
        sid = spot["id"]
        edges, kx, ky = load_edges(land, spot["lat"], spot["lon"], MAX_KM / 111.0 + 0.1)
        peaks = [((p["lon"] - spot["lon"]) * kx, (p["lat"] - spot["lat"]) * ky, float(p["elev_m"])) for p in peaks_all.get(sid, [])]
        terrain = TERRAIN[sid]
        for pos in spot["positions"]:
            f = math.radians(DIRS.index(pos["facing"]) * 45.0)
            ox, oy = water_origin(f, edges)
            if pos.get("stage") == "boat":
                ox, oy = ox + math.sin(f) * BOAT_OUT_M, oy + math.cos(f) * BOAT_OUT_M
            out["profiles"][pos["id"]] = profile(ox, oy, edges, terrain, peaks)
        print(sid, "done", file=sys.stderr)
    with open(out_path, "w") as fh:
        json.dump(out, fh, separators=(",", ":"))


if __name__ == "__main__":
    main()
