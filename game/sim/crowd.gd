class_name Crowd
extends RefCounted
## The background life of an area (owner, 2026-11-18: "make the world more
## crowded"): passers-by on the walkways and plazas, the tram and cars on the
## road, ferries on the water. None of them has a rule the player meets; they
## are scenery. Every position is a pure function of the elapsed time, so the
## crowd needs no state per frame and the same seed gives the same street.
## Counts and speeds are design fills in constants.json.

const LANE_MARGIN_M := 0.5     ## passers-by keep this far from rails and lamps
const TRAM_TRACKS_X := [28.8, 31.2]
const TRAM_LENGTH_M := 32.0     ## two coupled cars
const CAR_LANES_X := [[20.5, 1.0], [23.6, 1.0], [36.4, -1.0], [39.5, -1.0]]  ## x, direction (+1 towards Eminönü)


## The passers-by for a slot: walkway walkers going up and down the bridge,
## and plaza strollers going across. Each is {kind, from, to, speed, offset,
## palette}: kind "line" walks back and forth between from and to.
static func passers_by(area: WorldArea, slot: String, seed_value: int, constants: Dictionary) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var count := int((constants["CROWD_COUNT"] as Dictionary).get(slot, 0))
	var speeds: Array = constants["CROWD_WALK_M_PER_S"]
	var walkways := _rects(area, "walkway")
	var plazas := _rects(area, "plaza")
	var out: Array[Dictionary] = []
	for i in count:
		var speed := rng.randf_range(float(speeds[0]), float(speeds[1]))
		var from := Vector2.ZERO
		var to := Vector2.ZERO
		if i % 3 != 2 and not walkways.is_empty():
			# Along a walkway, on the road side of it, from plaza to plaza.
			var w: Rect2 = walkways[rng.randi() % walkways.size()]
			var x := rng.randf_range(w.position.x + w.size.x * 0.5, w.end.x - LANE_MARGIN_M)
			if w.position.x > area.size_m.x * 0.5:
				x = rng.randf_range(w.position.x + LANE_MARGIN_M, w.position.x + w.size.x * 0.5)
			from = Vector2(x, w.position.y - 6.0)
			to = Vector2(x, w.end.y + 6.0)
		elif not plazas.is_empty():
			# Across a plaza, in the open band between the kiosks and the water.
			var p: Rect2 = plazas[rng.randi() % plazas.size()]
			var y := rng.randf_range(p.position.y + 5.0, p.end.y - 2.0) if p.position.y < area.size_m.y * 0.5 else rng.randf_range(p.position.y + 2.0, p.end.y - 4.0)
			from = Vector2(p.position.x + 1.0, y)
			to = Vector2(p.end.x - 1.0, y)
		out.append({"kind": "line", "from": from, "to": to, "speed": speed,
			"offset": rng.randf() * 1000.0, "palette": rng.randi()})
	return out


## Where a passer-by is at time t (s), and which way they face.
static func walker_at(w: Dictionary, t: float) -> Dictionary:
	var from: Vector2 = w["from"]
	var to: Vector2 = w["to"]
	var length := maxf(from.distance_to(to), 0.01)
	var s := fmod(float(w["offset"]) + float(w["speed"]) * t, 2.0 * length)
	var forward := s < length
	var share := s / length if forward else 2.0 - s / length
	var dir := (to - from).normalized()
	return {"pos": from.lerp(to, share), "facing": dir if forward else -dir, "phase": s * 4.5}


## The trams: one each way on the middle tracks, {x, y (front centre), dir}.
## A tram crosses the area every TRAM_PERIOD_S, from beyond one end to beyond
## the other; y can be outside the area while it is out of sight.
static func trams(area: WorldArea, t: float, constants: Dictionary) -> Array[Dictionary]:
	var period := float(constants["TRAM_PERIOD_S"])
	var speed := float(constants["TRAM_M_PER_S"])
	var span := area.size_m.y + 2.0 * TRAM_LENGTH_M
	var out: Array[Dictionary] = []
	for k in 2:
		var dir := 1.0 if k == 0 else -1.0
		var travel := fmod(t + period * 0.5 * k, period) * speed
		var y := -TRAM_LENGTH_M + travel if dir > 0.0 else area.size_m.y + TRAM_LENGTH_M - travel
		if travel <= span:
			out.append({"x": TRAM_TRACKS_X[k], "y": y, "dir": dir})
	return out


## The cars: a few per lane, evenly spaced, moving through the area and on.
static func cars(area: WorldArea, t: float, slot: String, constants: Dictionary) -> Array[Dictionary]:
	var per_lane := int((constants["CARS_PER_LANE"] as Dictionary).get(slot, 0))
	var speed := float(constants["CAR_M_PER_S"])
	var span := area.size_m.y + 20.0
	var out: Array[Dictionary] = []
	for li in CAR_LANES_X.size():
		var lane: Array = CAR_LANES_X[li]
		var dir := float(lane[1])
		for c in per_lane:
			var s := fmod(t * speed + span * (float(c) / per_lane) + li * 17.0, span)
			var y := -10.0 + s if dir > 0.0 else area.size_m.y + 10.0 - s
			out.append({"x": float(lane[0]), "y": y, "dir": dir, "colour": (li * 7 + c * 3) % 6})
	return out


## The ferries: one per water rect, crossing the whole area under the bridge
## at that rect's height, {x (centre), y, dir}.
static func ferries(area: WorldArea, t: float, constants: Dictionary) -> Array[Dictionary]:
	var speed := float(constants["FERRY_M_PER_S"])
	var span := area.size_m.x + 60.0
	var out: Array[Dictionary] = []
	var waters := _rects(area, "water")
	for i in waters.size():
		var w: Rect2 = waters[i]
		var dir := 1.0 if i % 2 == 0 else -1.0
		var s := fmod(t * speed + i * span * 0.5, span)
		var x := -30.0 + s if dir > 0.0 else area.size_m.x + 30.0 - s
		out.append({"x": x, "y": w.position.y + w.size.y * (0.3 if i % 2 == 0 else 0.7), "dir": dir})
	return out


static func _rects(area: WorldArea, kind: String) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for r: Dictionary in area.rects:
		if r["kind"] == kind:
			out.append(r["rect"])
	return out
