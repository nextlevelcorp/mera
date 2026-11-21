class_name Baiting
extends RefCounted
## Baiting the hook by hand (roadmap R20, owner decisions D9 and 2026-11-20:
## "really put the bait on: choose it first, then put it on by hand, with
## realistic mechanics"). The angler first picks a bait or lure from the bag
## (which also picks the rig it goes on), then makes the real movements on a
## close-up of the hook: each kind has two or three strokes. A trace stroke
## is a path the hook point must follow (threading a shrimp from the tail,
## a soft plastic along its centre, a snap onto a lure's eye); a hold stroke
## asks for a steady thumb on a wriggling live fish. Each stroke scores 0..1;
## the baiting quality is their mean, which the session uses (a well-baited
## hook holds on the cast and against a nibbling fish and looks natural; a
## live fish tires more slowly). Pure: the screen draws and sends the finger
## positions in the work area's own 0..1 coordinates. Paths are design fills.

## The work area is 1 wide and ASPECT high (a landscape close-up).
const ASPECT := 0.56
## A trace counts as finished when the point got this far along its path.
const FINISH := 0.92
## A steady hand (2026-11-21): the point ignores finger tremble smaller than
## this (work units), so a shaking thumb does not shake the hook.
const STEADY := 0.006

## Strokes per kind: {key, type "trace" (path, tol) or "hold" (at, hold_s, tol)}.
const STROKES := {
	"shrimp": [
		{"key": "BAIT_STEP_SHRIMP_PEEL", "type": "trace", "tol": 0.06, "path": [Vector2(0.80, 0.36), Vector2(0.88, 0.30)]},
		{"key": "BAIT_STEP_SHRIMP_THREAD", "type": "trace", "tol": 0.045, "path": [Vector2(0.78, 0.33), Vector2(0.68, 0.37), Vector2(0.56, 0.38), Vector2(0.45, 0.35), Vector2(0.37, 0.29)]},
		{"key": "BAIT_STEP_SHRIMP_HIDE", "type": "trace", "tol": 0.035, "path": [Vector2(0.37, 0.29), Vector2(0.33, 0.22)]},
	],
	"live": [
		{"key": "BAIT_STEP_LIVE_HOLD", "type": "hold", "at": Vector2(0.40, 0.33), "hold_s": 1.2, "tol": 0.08},
		{"key": "BAIT_STEP_LIVE_HOOK", "type": "trace", "tol": 0.03, "path": [Vector2(0.56, 0.17), Vector2(0.56, 0.29)]},
	],
	"soft_plastic": [
		{"key": "BAIT_STEP_SOFT_LINE_UP", "type": "trace", "tol": 0.05, "path": [Vector2(0.20, 0.16), Vector2(0.27, 0.28)]},
		{"key": "BAIT_STEP_SOFT_THREAD", "type": "trace", "tol": 0.028, "path": [Vector2(0.27, 0.28), Vector2(0.46, 0.28)]},
		{"key": "BAIT_STEP_SOFT_STRAIGHT", "type": "trace", "tol": 0.03, "path": [Vector2(0.46, 0.28), Vector2(0.50, 0.20)]},
	],
	"minnow": [
		{"key": "BAIT_STEP_SNAP_OPEN", "type": "trace", "tol": 0.04, "path": [Vector2(0.30, 0.30), Vector2(0.33, 0.20)]},
		{"key": "BAIT_STEP_SNAP_CLIP", "type": "trace", "tol": 0.03, "path": [Vector2(0.33, 0.20), Vector2(0.43, 0.25), Vector2(0.49, 0.29)]},
	],
	"sabiki": [
		{"key": "BAIT_STEP_SABIKI_UNWIND", "type": "trace", "tol": 0.05, "path": [Vector2(0.62, 0.28), Vector2(0.56, 0.16), Vector2(0.44, 0.13), Vector2(0.36, 0.22), Vector2(0.38, 0.36), Vector2(0.50, 0.42), Vector2(0.62, 0.36)]},
		{"key": "BAIT_STEP_SABIKI_WEIGHT", "type": "trace", "tol": 0.035, "path": [Vector2(0.50, 0.42), Vector2(0.50, 0.52)]},
	],
}


## The kind of baiting a lure-shaped record needs.
static func kind_of(lure: Dictionary, bait_record: Dictionary = {}) -> String:
	if Presentation.is_float(lure):
		return "live" if bait_record.has("from_species") else "shrimp"
	var t := String(lure.get("type", ""))
	if t == "sabiki":
		return "sabiki"
	if t == "soft_plastic":
		return "soft_plastic"
	return "minnow"


static func strokes(kind: String) -> Array:
	return STROKES.get(kind, STROKES["minnow"])


## What can go on the hook, for the choosing step: one entry per lure rig
## and per float bait, with how many are in the bag. {rig, float_bait (the
## float rig's bait id, else ""), item_id, name_key, kind, stock}.
static func options(database: Dictionary, save: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for rig: String in FightSetup.TACKLES:
		if rig == "float":
			for bait: Dictionary in database.get("bait", []):
				out.append({"rig": rig, "float_bait": String(bait["id"]), "item_id": String(bait["id"]), "name_key": String(bait["name_key"]),
					"kind": "live" if bait.has("from_species") else "shrimp", "stock": Presentation.bait_stock(save, bait, database["species"])})
		else:
			var id := FightSetup.lure_id(rig)
			for lure: Dictionary in database.get("lure", []):
				if lure["id"] == id:
					out.append({"rig": rig, "float_bait": "", "item_id": id, "name_key": String(lure["name_key"]), "kind": kind_of(lure), "stock": Inventory.count(save, id)})
	return out


## The species a bait or lure suits, by what it imitates (a lure) or what
## it smells of (a bait) against each species' diet. Name keys, for the
## choosing step's "good for" line (2026-11-21).
static func good_for(database: Dictionary, option: Dictionary) -> Array[String]:
	var tags: Array = []
	for b: Dictionary in database.get("bait", []):
		if b["id"] == option["item_id"]:
			tags = b.get("target_diet_tags", [])
	for l: Dictionary in database.get("lure", []):
		if l["id"] == option["item_id"]:
			tags = l.get("imitates", [])
	var out: Array[String] = []
	for sp: Dictionary in database.get("species", []):
		for tag: Variant in sp.get("diet_tags", []):
			if tag in tags:
				out.append(String(sp["name_key"]))
				break
	return out


## Distance from a point to a polyline, and how far along it (0..1) the
## nearest point lies.
static func nearest_on(path: Array, p: Vector2) -> Dictionary:
	var total := 0.0
	for i in range(1, path.size()):
		total += (path[i] as Vector2).distance_to(path[i - 1])
	var best := INF
	var best_s := 0.0
	var walked := 0.0
	for i in range(1, path.size()):
		var a: Vector2 = path[i - 1]
		var b: Vector2 = path[i]
		var seg := b - a
		var t := clampf((p - a).dot(seg) / maxf(seg.length_squared(), 1e-9), 0.0, 1.0)
		var d := p.distance_to(a + seg * t)
		if d < best:
			best = d
			best_s = (walked + seg.length() * t) / maxf(total, 1e-9)
		walked += seg.length()
	return {"distance": best, "along": best_s}


## True when a touch at p may start this trace (close to its start).
static func starts_trace(stroke: Dictionary, p: Vector2) -> bool:
	return p.distance_to(stroke["path"][0]) <= float(stroke["tol"]) * 2.5


## Where a paused trace picks up again: the point on the path as far as the
## samples got (the thumb may lift and come back, 2026-11-21).
static func resume_point(stroke: Dictionary, samples: Array) -> Vector2:
	var progress := float(trace_score(stroke, samples)["progress"]) if not samples.is_empty() else 0.0
	return point_at(stroke["path"], progress)


## True when a touch at p may carry on a paused trace.
static func resumes_trace(stroke: Dictionary, samples: Array, p: Vector2) -> bool:
	return p.distance_to(resume_point(stroke, samples)) <= float(stroke["tol"]) * 2.5


## The point a share s (0..1) along a polyline, and its direction there.
static func point_at(path: Array, s: float) -> Vector2:
	return _walk(path, s)[0]


static func tangent_at(path: Array, s: float) -> Vector2:
	return _walk(path, s)[1]


static func _walk(path: Array, s: float) -> Array:
	var total := 0.0
	for i in range(1, path.size()):
		total += (path[i] as Vector2).distance_to(path[i - 1])
	var want := clampf(s, 0.0, 1.0) * total
	for i in range(1, path.size()):
		var a: Vector2 = path[i - 1]
		var b: Vector2 = path[i]
		var seg := a.distance_to(b)
		if want <= seg or i == path.size() - 1:
			return [a.lerp(b, clampf(want / maxf(seg, 1e-9), 0.0, 1.0)), (b - a).normalized()]
		want -= seg
	return [path[0], Vector2.RIGHT]


## The hook's point after a new finger sample: still for a tremble, on the
## finger for a real move (no lag, so the point never trails the thumb).
static func steady(point: Vector2, finger: Vector2) -> Vector2:
	return point if point.distance_to(finger) < STEADY else finger


## A trace's score from the finger's samples: accuracy (1 on the path, 0 at
## the tolerance and beyond, averaged) times how far along it got (full
## marks at FINISH). {score, accuracy, progress, finished}.
static func trace_score(stroke: Dictionary, samples: Array) -> Dictionary:
	if samples.is_empty():
		return {"score": 0.0, "accuracy": 0.0, "progress": 0.0, "finished": false}
	var tol := float(stroke["tol"])
	var acc := 0.0
	var progress := 0.0
	for p: Vector2 in samples:
		var n := nearest_on(stroke["path"], p)
		acc += clampf(1.0 - float(n["distance"]) / tol, 0.0, 1.0)
		# Progress only counts while the point is on the path.
		if float(n["distance"]) <= tol * 1.5:
			progress = maxf(progress, float(n["along"]))
	acc /= samples.size()
	return {"score": acc * clampf(progress / FINISH, 0.0, 1.0), "accuracy": acc, "progress": progress, "finished": progress >= FINISH}


## A hold's score: how long the thumb stayed on the fish (full at hold_s)
## times how steady it was (the mean distance from where it should hold).
static func hold_score(stroke: Dictionary, held_s: float, samples: Array) -> Dictionary:
	var tol := float(stroke["tol"])
	var steady := 0.0
	for p: Vector2 in samples:
		steady += clampf(1.0 - p.distance_to(stroke["at"]) / tol, 0.0, 1.0)
	steady = steady / samples.size() if not samples.is_empty() else 0.0
	var time := clampf(held_s / float(stroke["hold_s"]), 0.0, 1.0)
	return {"score": time * steady, "finished": time >= 1.0}


## The baiting quality from the strokes' scores.
static func quality(scores: Array) -> float:
	if scores.is_empty():
		return 0.0
	var total := 0.0
	for s: float in scores:
		total += s
	return total / scores.size()


## The word the result shows: good, fair or poor.
static func rating_key(q: float) -> String:
	if q >= 0.75:
		return "BAIT_RESULT_GOOD"
	if q >= 0.4:
		return "BAIT_RESULT_FAIR"
	return "BAIT_RESULT_POOR"

