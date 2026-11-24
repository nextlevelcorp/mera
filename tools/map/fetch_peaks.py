#!/usr/bin/env python3
"""Fetches tools/map/peaks.json: mountains and hills of at least 100 m within
45 km of each spot, from Wikidata (CC0) through its SPARQL endpoint.
Usage (from the repository root): python3 tools/map/fetch_peaks.py tools/map/peaks.json
"""
import json, sys, time, urllib.parse, urllib.request
spots = json.load(open('game/data/spots.json'))
out = {}
for s in spots:
    q = f"""SELECT ?item ?itemLabel ?elev ?coord WHERE {{
  SERVICE wikibase:around {{ ?item wdt:P625 ?coord. bd:serviceParam wikibase:center "Point({s['lon']} {s['lat']})"^^geo:wktLiteral. bd:serviceParam wikibase:radius "45". }}
  ?item wdt:P31/wdt:P279* wd:Q8502 .
  ?item p:P2044/psv:P2044 [wikibase:quantityAmount ?elev; wikibase:quantityUnit wd:Q11573].
  FILTER(?elev >= 100)
  SERVICE wikibase:label {{ bd:serviceParam wikibase:language "en". }}
}}"""
    url = "https://query.wikidata.org/sparql?format=json&query=" + urllib.parse.quote(q)
    for attempt in range(4):
        try:
            r = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "mera-game-data/0.1"}), timeout=90)
            data = json.load(r); break
        except Exception as e:
            print(s['id'], 'retry', e, file=sys.stderr); time.sleep(10)
    rows = []
    seen = set()
    for b in data['results']['bindings']:
        qid = b['item']['value'].rsplit('/', 1)[1]
        if qid in seen: continue
        seen.add(qid)
        lon, lat = b['coord']['value'][6:-1].split()
        rows.append({"qid": qid, "name": b['itemLabel']['value'], "lat": round(float(lat), 4), "lon": round(float(lon), 4), "elev_m": round(float(b['elev']['value']))})
    rows.sort(key=lambda r: -r['elev_m'])
    out[s['id']] = rows
    print(s['id'], len(rows), [ (r['name'], r['elev_m']) for r in rows[:5]], file=sys.stderr)
    time.sleep(3)
json.dump({"source": "Wikidata (CC0): items that are mountains or hills (P31/P279* Q8502) with an elevation (P2044) of at least 100 m within 45 km of each spot, queried 2026-11-24 by tools/map/fetch_peaks.py.", "peaks": out}, open(sys.argv[1], 'w'), ensure_ascii=False, indent=0)
