class_name MapModel
extends RefCounted
## The map (roadmap R17, owner decision D6: pick a country, then a spot).
## Countries come from the jurisdictions' records, spots from spots.json
## through their `jurisdiction`; a country with rules but no spot yet is
## listed as coming. Positions on the chart are an equirectangular projection
## of the real coordinates, squeezed by the cosine of the middle latitude so
## the shapes keep their proportions. Pure.


## One entry per country: {country, name_key, jurisdictions, spots, official}.
## Countries with spots come first, then in the jurisdictions' order.
static func countries(database: Dictionary) -> Array[Dictionary]:
	var by_country := {}
	var order: Array[String] = []
	for j: Dictionary in database.get("jurisdiction", []):
		var c := String(j["country"])
		if not by_country.has(c):
			by_country[c] = {"country": c, "name_key": String(j["name_key"]), "jurisdictions": [], "spots": [], "official": true}
			order.append(c)
		(by_country[c]["jurisdictions"] as Array).append(String(j["id"]))
		by_country[c]["official"] = bool(by_country[c]["official"]) and bool(j.get("official", true))
	for s: Dictionary in database.get("spot", []):
		var j := Regulations.jurisdiction(database, String(s.get("jurisdiction", "")))
		if not j.is_empty():
			(by_country[String(j["country"])]["spots"] as Array).append(s)
	var out: Array[Dictionary] = []
	for c: String in order:
		if not (by_country[c]["spots"] as Array).is_empty():
			out.append(by_country[c])
	for c: String in order:
		if (by_country[c]["spots"] as Array).is_empty():
			out.append(by_country[c])
	return out


## A spot by its id, or an empty dictionary.
static func spot(database: Dictionary, spot_id: String) -> Dictionary:
	for s: Dictionary in database.get("spot", []):
		if s["id"] == spot_id:
			return s
	return {}


## The spots of one country.
static func spots_in(database: Dictionary, country: String) -> Array:
	for c: Dictionary in countries(database):
		if c["country"] == country:
			return c["spots"]
	return []


## The chart's bounds around points {lat, lon}: [min_lon, min_lat, max_lon,
## max_lat], with a margin in degrees so the pins are not on the edge.
static func bounds(points: Array, margin_deg: float) -> Array[float]:
	var b: Array[float] = [INF, INF, -INF, -INF]
	for p: Dictionary in points:
		b[0] = minf(b[0], float(p["lon"]))
		b[1] = minf(b[1], float(p["lat"]))
		b[2] = maxf(b[2], float(p["lon"]))
		b[3] = maxf(b[3], float(p["lat"]))
	return [b[0] - margin_deg, b[1] - margin_deg, b[2] + margin_deg, b[3] + margin_deg]


## Where (lat, lon) falls in a rectangle, keeping proportions (north up).
static func chart_point(lat: float, lon: float, b: Array[float], rect: Rect2) -> Vector2:
	var squeeze := cos(deg_to_rad((b[1] + b[3]) * 0.5))
	var w_deg := maxf((b[2] - b[0]) * squeeze, 1e-6)
	var h_deg := maxf(b[3] - b[1], 1e-6)
	var scale := minf(rect.size.x / w_deg, rect.size.y / h_deg)
	var centre := rect.get_center()
	var mid_lon := (b[0] + b[2]) * 0.5
	var mid_lat := (b[1] + b[3]) * 0.5
	return centre + Vector2((lon - mid_lon) * squeeze * scale, -(lat - mid_lat) * scale)
