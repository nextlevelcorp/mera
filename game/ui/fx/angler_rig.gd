class_name AnglerRig
extends RefCounted
## The motion of the angler's first-person rig: the smoothed rod curve, the
## reel handle with inertia, the spool that turns backwards when the fish
## takes line, the cast pose. The fishing screen owns the state (rod points
## from RodSpring, phase, tension) and calls update() once per frame; Rig3D
## draws the rod, reel, hands and forearms from it. Visual only,
## deterministic (no randf).

const SMOOTH_STEPS := 4
const GUIDES: Array[float] = [0.3, 0.44, 0.57, 0.68, 0.78, 0.87, 0.94]
const CRANK_TAU := 0.15        ## s for the handle to reach a new speed (inertia)
const SPOOL_TURNS_PER_M := 6.0 ## spool radians per metre of line taken

## Set by the screen each frame.
var light := 0.6
var tension := 0.0             ## tension over line strength
var bail_open := false
var cast_pose := 0.0           ## 0..1: left hand moves to the spool for the cast

var crank := 0.0
var crank_speed := 0.0
var spool := 0.0
var time := 0.0

var _curve := PackedVector2Array()
var _s := PackedFloat32Array()


## crank_target: rad/s the reel handle should turn; line_out: m/s of line the
## fish takes (positive) which turns the spool backwards against the drag.
func update(dt: float, crank_target: float, line_out: float) -> void:
	time += dt
	crank_speed += (crank_target - crank_speed) * minf(dt / CRANK_TAU, 1.0)
	crank = fmod(crank + crank_speed * dt, TAU * 64.0)
	if line_out > 0.0:
		spool = fmod(spool - line_out * SPOOL_TURNS_PER_M * dt, TAU * 64.0)
	else:
		spool = fmod(spool + crank_speed * 0.5 * dt, TAU * 64.0)


## Catmull-Rom through the spring points into _curve, with arc-length share in _s.
func _smooth(pts: PackedVector2Array) -> void:
	var n := pts.size()
	var count := (n - 1) * SMOOTH_STEPS + 1
	if _curve.size() != count:
		_curve.resize(count)
		_s.resize(count)
	var k := 0
	for i in n - 1:
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, n - 1)]
		for j in SMOOTH_STEPS:
			var t := float(j) / SMOOTH_STEPS
			var t2 := t * t
			var t3 := t2 * t
			_curve[k] = 0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3)
			k += 1
	_curve[k] = pts[n - 1]
	var total := 0.0
	_s[0] = 0.0
	for i in range(1, count):
		total += _curve[i].distance_to(_curve[i - 1])
		_s[i] = total
	for i in count:
		_s[i] = _s[i] / maxf(total, 0.001)


## For the 3D rig: smooth the spring points, then read points with at().
func prepare(pts: PackedVector2Array) -> void:
	_smooth(pts)


func at(t: float) -> Vector2:
	return _at(t)


## Point at share t (0 butt, 1 tip) of the smoothed blank's length.
func _at(t: float) -> Vector2:
	var count := _curve.size()
	for i in range(1, count):
		if _s[i] >= t:
			var span := maxf(_s[i] - _s[i - 1], 1e-6)
			return _curve[i - 1].lerp(_curve[i], (t - _s[i - 1]) / span)
	return _curve[count - 1]
