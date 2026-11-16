class_name ShoalField
extends RefCounted
## Bait shoals in front of the angler (owner, 2026-11-16: biggest step in
## mechanics; pillar 2: realism you can read). A shoal is a patch of water
## where small fish are pushed to the surface; predators and the shoal's own
## fish bite more there. Gulls working over the water mark it, so reading the
## birds and landing the cast near them is the skill. Pure and deterministic:
## the same seed gives the same shoals at the same times. Positions are in
## water metres: x to the right of the angler, z out from the shore.
## All numbers are design fills (constants.json SHOAL_FIELD_*).

var shoals: Array[Dictionary] = []   ## {pos: Vector2, vel: Vector2, radius, left_s, age_s}

var _k: Dictionary
var _rng := RandomNumberGenerator.new()
## The shoals keep to the water side of this line: x >= min_x_at_zero + min_x_per_m * z.
var _min_x0 := 0.0
var _min_x_per_m := -0.45


func _init(k: Dictionary, seed_value: int) -> void:
	_k = k
	_rng.seed = seed_value
	for i in int(k["SHOAL_FIELD_COUNT"]):
		shoals.append(_spawn())
		# Start somewhere in its life, so not every shoal ends together.
		shoals[i]["left_s"] = float(shoals[i]["left_s"]) * _rng.randf_range(0.4, 1.0)
		shoals[i]["age_s"] = 10.0


func advance(dt: float) -> void:
	dt = clampf(dt, 0.0, 1.0)
	for i in shoals.size():
		var s: Dictionary = shoals[i]
		s["pos"] = (s["pos"] as Vector2) + (s["vel"] as Vector2) * dt
		s["left_s"] = float(s["left_s"]) - dt
		s["age_s"] = float(s["age_s"]) + dt
		var p: Vector2 = s["pos"]
		if float(s["left_s"]) <= 0.0 or p.y < 8.0 or p.y > 55.0 or p.x < _min_x0 + _min_x_per_m * p.y:
			shoals[i] = _spawn()


## How strongly a shoal is feeding now, 0..1: it rises, holds and breaks up.
static func strength(s: Dictionary) -> float:
	return clampf(float(s["age_s"]) / 8.0, 0.0, 1.0) * clampf(float(s["left_s"]) / 8.0, 0.0, 1.0)


## Multiplier on the interest rate for a lure at (x, z): 1 away from every
## shoal, up to 1 + SHOAL_FIELD_GAIN in the middle of one.
func boost_at(x: float, z: float) -> float:
	var best := 0.0
	for s: Dictionary in shoals:
		var d := (s["pos"] as Vector2).distance_to(Vector2(x, z)) / float(s["radius"])
		best = maxf(best, exp(-d * d) * strength(s))
	return 1.0 + float(_k["SHOAL_FIELD_GAIN"]) * best


## Distance from (x, z) to the nearest shoal's centre, in metres (for the debug view).
func nearest_m(x: float, z: float) -> float:
	var best := INF
	for s: Dictionary in shoals:
		best = minf(best, (s["pos"] as Vector2).distance_to(Vector2(x, z)))
	return best


func _spawn() -> Dictionary:
	var z := _rng.randf_range(12.0, 42.0)
	var x := _rng.randf_range(maxf(_min_x0 + _min_x_per_m * z + 3.0, -0.35 * z), 0.4 * z)
	var drift := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.05, float(_k["SHOAL_FIELD_DRIFT_M_PER_S"]))
	return {
		"pos": Vector2(x, z), "vel": drift,
		"radius": _rng.randf_range(float(_k["SHOAL_FIELD_RADIUS_M"][0]), float(_k["SHOAL_FIELD_RADIUS_M"][1])),
		"left_s": _rng.randf_range(float(_k["SHOAL_FIELD_LIFE_S"][0]), float(_k["SHOAL_FIELD_LIFE_S"][1])),
		"age_s": 0.0,
	}
