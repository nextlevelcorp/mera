class_name NpcRoster
extends RefCounted
## The people of the world (roadmap R10): fictional anglers who keep a daily
## routine along the rail, and the two kiosk vendors. Data in
## game/data/npcs.json (design fill); rules here, pure and deterministic:
## where someone is meant to be in a time-of-day slot (plan), and how they
## walk there in a WorldArea (walk_step). The world draws them; the fishing
## view turns the anglers next to the player into its 3D neighbours.

const FILE := "res://data/npcs.json"
const ROLES := ["angler", "vendor"]
const ACTIVITIES := ["fish", "away"]
const SLOTS := ["dawn", "day", "evening", "night"]
const ARRIVE_M := 0.15
const ENTRY_M := 6.0


## Loads and validates the roster against the area. Returns {"ok", "errors", "npcs"}.
static func load_roster(area: WorldArea) -> Dictionary:
	var errors: Array[String] = []
	var raw: Variant = DataStore.read_json(FILE, errors)
	if typeof(raw) != TYPE_DICTIONARY:
		return {"ok": false, "errors": errors, "npcs": []}
	var d: Dictionary = raw
	if d.get("design_fill", false) != true and not d.has("source"):
		errors.append("npcs: needs a source or design_fill true")
	var markers := {}
	for m: Dictionary in area.markers:
		markers[m["position_id"]] = true
	var shops := {}
	for sh: Dictionary in area.shops:
		shops[sh["id"]] = true
	var seen := {}
	for n: Dictionary in d.get("npcs", []):
		var id := String(n.get("id", ""))
		if seen.has(id) or id == "":
			errors.append("npcs: missing or duplicate id %s" % id)
		seen[id] = true
		if not String(n.get("role", "")) in ROLES:
			errors.append("npcs:%s: unknown role" % id)
		if n.get("role") == "vendor" and not shops.has(String(n.get("shop", ""))):
			errors.append("npcs:%s: vendor of an unknown shop" % id)
		if n.get("role") == "angler":
			for slot: String in SLOTS:
				var plan: Dictionary = (n.get("schedule", {}) as Dictionary).get(slot, {})
				if not String(plan.get("activity", "")) in ACTIVITIES:
					errors.append("npcs:%s: no plan for %s" % [id, slot])
				elif plan["activity"] == "fish" and not markers.has(String(plan.get("position_id", ""))):
					errors.append("npcs:%s: fishes at an unknown position in %s" % [id, slot])
	return {"ok": errors.is_empty(), "errors": errors, "npcs": d.get("npcs", [])}


## Where npc should be in this slot: {present, pos (world m), facing ("E", "W"
## or "S" for a vendor), fishing, position_id}.
static func plan(npc: Dictionary, slot: String, area: WorldArea) -> Dictionary:
	if npc["role"] == "vendor":
		for sh: Dictionary in area.shops:
			if sh["id"] == npc["shop"]:
				return {"present": true, "pos": (sh["pos"] as Vector2) + Vector2(0.0, -1.2), "facing": "S", "fishing": false, "position_id": ""}
		return {"present": false}
	var p: Dictionary = npc["schedule"][slot]
	if p["activity"] != "fish":
		return {"present": false}
	for m: Dictionary in area.markers:
		if m["position_id"] == p["position_id"]:
			return {"present": true, "pos": (m["pos"] as Vector2) + Vector2(0.0, float(p.get("offset_m", 0.0))),
				"facing": m["facing"], "fishing": true, "position_id": p["position_id"]}
	return {"present": false}


## Where an angler enters the area: the plaza nearest their spot, in front of
## the buildings that close it.
static func entry_point(target: Vector2, area: WorldArea) -> Vector2:
	return Vector2(target.x, ENTRY_M if target.y < area.size_m.y * 0.5 else area.size_m.y - ENTRY_M)


## One walking step towards target, around the blocked road: someone on the
## wrong side first walks to the nearer plaza, crosses there and comes back
## along the walkway. Returns the new position.
static func walk_step(pos: Vector2, target: Vector2, dt: float, area: WorldArea, speed: float) -> Vector2:
	var goal := target
	if _blocked_between(pos, target, area):
		var y_cross := 10.0 if absf(pos.y - 10.0) + absf(target.y - 10.0) < absf(pos.y - (area.size_m.y - 10.0)) + absf(target.y - (area.size_m.y - 10.0)) else area.size_m.y - 10.0
		if absf(pos.y - y_cross) > 0.3 and absf(pos.x - target.x) > 0.3:
			goal = Vector2(pos.x, y_cross)
		else:
			goal = Vector2(target.x, y_cross) if absf(pos.x - target.x) > 0.3 else target
	var step := goal - pos
	var d := step.length()
	if d <= ARRIVE_M:
		return goal
	var reach := minf(speed * clampf(dt, 0.0, 0.1), d)
	# Straight on if open, else slide along one axis (the larger first), else wait.
	var tries: Array[Vector2] = [pos + step / d * reach]
	var along_x := Vector2(signf(step.x) * minf(reach, absf(step.x)), 0.0)
	var along_y := Vector2(0.0, signf(step.y) * minf(reach, absf(step.y)))
	tries.append_array([pos + along_x, pos + along_y] if absf(step.x) > absf(step.y) else [pos + along_y, pos + along_x])
	for next: Vector2 in tries:
		if next != pos and not area.blocked_at(next, 0.2):
			return next
	return pos


static func _blocked_between(a: Vector2, b: Vector2, area: WorldArea) -> bool:
	for i in range(1, 12):
		if area.blocked_at(a.lerp(b, float(i) / 12.0), 0.2):
			return true
	return false


## The person within reach of pos who is nearest, from {id: pos}; "" for none.
static func nearest(pos: Vector2, people: Dictionary, reach: float) -> String:
	var best := ""
	var best_d := reach
	for id: String in people:
		var d := pos.distance_to(people[id])
		if d <= best_d:
			best = id
			best_d = d
	return best
