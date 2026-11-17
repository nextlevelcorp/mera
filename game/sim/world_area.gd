class_name WorldArea
extends RefCounted
## One place of the top-down world (architecture.md 4): its size, the ground
## rectangles (some of them blocked: water, a road), rails and lamps for
## drawing, and the fishing markers that link to the positions of its spot.
## Loaded from game/data/areas/<id>.json, validated against the spot
## database. Pure data: no nodes. The layout is a design fill; the file says so.

const DIR := "res://data/areas"
const KINDS := ["plaza", "walkway", "road", "water"]
const SHOPS := ["fishmonger", "tackle"]

var id := ""
var spot_id := ""
var note := ""
var size_m := Vector2.ZERO
var px_per_m := 24.0
var start_m := Vector2.ZERO
var rects: Array[Dictionary] = []   ## {kind, rect: Rect2, blocked}
var rails: Array[Dictionary] = []   ## {from: Vector2, to: Vector2}
var lamps: Array[Vector2] = []
var markers: Array[Dictionary] = [] ## {position_id, pos: Vector2, facing}
var shops: Array[Dictionary] = []   ## {id, pos}: id is fishmonger or tackle


## Loads and validates an area. Returns {"ok", "errors", "area"}.
static func load_area(area_id: String, database: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var raw: Variant = DataStore.read_json("%s/%s.json" % [DIR, area_id], errors)
	var area := WorldArea.new()
	if typeof(raw) != TYPE_DICTIONARY:
		return {"ok": false, "errors": errors, "area": area}
	var d: Dictionary = raw
	for key: String in ["id", "spot_id", "design_fill", "size_m", "px_per_m", "start_m", "rects", "rails", "lamps_m", "markers"]:
		if not d.has(key):
			errors.append("area:%s: missing %s" % [area_id, key])
	if not errors.is_empty():
		return {"ok": false, "errors": errors, "area": area}
	if d["id"] != area_id:
		errors.append("area:%s: id %s does not match the file name" % [area_id, d["id"]])
	if d["design_fill"] != true and not d.has("source"):
		errors.append("area:%s: needs a source or design_fill true" % area_id)
	area.id = String(d["id"])
	area.spot_id = String(d["spot_id"])
	area.note = String(d.get("note", ""))
	area.size_m = _v(d["size_m"])
	area.px_per_m = float(d["px_per_m"])
	area.start_m = _v(d["start_m"])
	for r: Dictionary in d["rects"]:
		if not String(r.get("kind", "")) in KINDS:
			errors.append("area:%s: unknown ground kind %s" % [area_id, str(r.get("kind"))])
		var a: Array = r["rect"]
		area.rects.append({"kind": r["kind"], "rect": Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3])), "blocked": bool(r["blocked"])})
	for r: Dictionary in d["rails"]:
		area.rails.append({"from": _v(r["from_m"]), "to": _v(r["to_m"])})
	for l: Variant in d["lamps_m"]:
		area.lamps.append(_v(l))
	var spot := {}
	for s: Dictionary in database.get("spot", []):
		if s["id"] == area.spot_id:
			spot = s
	if spot.is_empty():
		errors.append("area:%s: unknown spot %s" % [area_id, area.spot_id])
	var position_ids := {}
	for p: Dictionary in spot.get("positions", []):
		position_ids[p["id"]] = true
	for m: Dictionary in d["markers"]:
		if not position_ids.has(m["position_id"]):
			errors.append("area:%s: marker for unknown position %s" % [area_id, m["position_id"]])
		area.markers.append({"position_id": m["position_id"], "pos": _v(m["pos_m"]), "facing": String(m["facing"])})
	for sh: Dictionary in d.get("shops", []):
		if not String(sh.get("id", "")) in SHOPS:
			errors.append("area:%s: unknown shop %s" % [area_id, str(sh.get("id"))])
		area.shops.append({"id": String(sh.get("id", "")), "pos": _v(sh["pos_m"])})
	if area.size_m.x <= 0.0 or area.size_m.y <= 0.0 or area.px_per_m <= 0.0:
		errors.append("area:%s: size and scale must be positive" % area_id)
	if area.blocked_at(area.start_m, 0.35):
		errors.append("area:%s: the start point is blocked" % area_id)
	for sh: Dictionary in area.shops:
		if area.blocked_at(sh["pos"], 0.35):
			errors.append("area:%s: shop %s stands on blocked ground" % [area_id, sh["id"]])
	for m: Dictionary in area.markers:
		if area.blocked_at(m["pos"], 0.35):
			errors.append("area:%s: marker %s stands on blocked ground" % [area_id, m["position_id"]])
	return {"ok": errors.is_empty(), "errors": errors, "area": area}


## True when a circle of this radius at p touches blocked ground or leaves the area.
func blocked_at(p: Vector2, radius: float) -> bool:
	if p.x < radius or p.y < radius or p.x > size_m.x - radius or p.y > size_m.y - radius:
		return true
	for r: Dictionary in rects:
		if r["blocked"] and (r["rect"] as Rect2).grow(radius).has_point(p):
			return true
	return false


static func _v(a: Variant) -> Vector2:
	return Vector2(float((a as Array)[0]), float((a as Array)[1]))
