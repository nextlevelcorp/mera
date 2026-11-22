#!/usr/bin/env python3
"""Monthly mean sea-surface temperature at a point, 1991-2020, from NOAA OISST v2.1.

NOAA OISST v2.1 (daily, 0.25 degree) through NOAA CoastWatch ERDDAP, dataset
ncdcOisst21Agg_LonPM180. NOAA data are in the US public domain.
Usage: python3 tools/data/sst_climatology.py LAT LON
Prints the twelve monthly means (degrees C, one decimal; every third day is
sampled, which keeps the request small) of the grid cell
nearest to LAT, LON; pick a point just offshore so the cell is sea.
"""
import csv
import io
import sys
import urllib.request

URL = ("https://coastwatch.pfeg.noaa.gov/erddap/griddap/ncdcOisst21Agg_LonPM180.csv?"
       "sst%5B(1991-01-01T12:00:00Z):3:(2020-12-31T12:00:00Z)%5D%5B(0.0)%5D%5B({lat})%5D%5B({lon})%5D")


def main(lat, lon):
    with urllib.request.urlopen(URL.format(lat=lat, lon=lon), timeout=300) as r:
        rows = list(csv.reader(io.TextIOWrapper(r, encoding="utf-8")))
    sums, counts = [0.0] * 12, [0] * 12
    cell = None
    for row in rows[2:]:
        if row[4] in ("", "NaN"):
            continue
        cell = (row[2], row[3])
        m = int(row[0][5:7]) - 1
        sums[m] += float(row[4])
        counts[m] += 1
    if not all(counts):
        sys.exit("no sea data at this cell; move the point offshore")
    print("cell", cell, "days", sum(counts))
    print([round(s / c, 1) for s, c in zip(sums, counts)])


if __name__ == "__main__":
    main(float(sys.argv[1]), float(sys.argv[2]))
