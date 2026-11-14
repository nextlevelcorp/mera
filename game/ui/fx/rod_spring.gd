class_name RodSpring
extends RefCounted
## The rod as a chain of joints with angular springs (pillar 3: springs and
## oscillation). Stiff at the butt, soft at the tip, like a fast-action rod.
## A load at the tip (line tension, a fish's run, a hanging fish, wind)
## bends it; when the load changes the rod swings and settles. Visual only:
## the fight's tension comes from FightSim. Screen-space, deterministic.

const SEGMENTS := 10
const MAX_SUBSTEP_S := 0.005   ## explicit integration stays stable below this step
const MAX_SUBSTEPS := 60
const MAX_FRAME_S := 0.1         ## a hitch longer than this is not simulated in full
const LOAD_TORQUE := 250.0     ## torque per unit load at full rod length
const STIFF_BUTT := 2600.0
const STIFF_TIP := 140.0
const DAMPING := 0.22          ## share of critical damping per joint

var angles := PackedFloat32Array()     ## joint bend relative to the segment below
var velocities := PackedFloat32Array()
var _points := PackedVector2Array()
var _stiffness := PackedFloat32Array()


func _init() -> void:
	angles.resize(SEGMENTS)
	velocities.resize(SEGMENTS)
	_stiffness.resize(SEGMENTS)
	for i in SEGMENTS:
		var s := float(i) / float(SEGMENTS - 1)
		# Stiffness falls off quickly towards the tip.
		_stiffness[i] = lerpf(STIFF_BUTT, STIFF_TIP, pow(s, 0.7))
	_points.resize(SEGMENTS + 1)


## butt: screen position of the butt; base_angle: direction of the unloaded rod
## (radians, screen space, y down); length: px; load: force at the tip in
## "rod loads" (1.0 bends the rod to its working curve), screen direction.
func step(dt: float, butt: Vector2, base_angle: float, length: float, load: Vector2) -> void:
	# Long frames (slow phones, software rendering) are split so the stiff butt
	# joints never take a step large enough to blow up.
	dt = clampf(dt, 0.0, MAX_FRAME_S)
	var steps := clampi(ceili(dt / MAX_SUBSTEP_S), 1, MAX_SUBSTEPS)
	var h := dt / steps
	var seg := length / SEGMENTS
	for _s in steps:
		_forward(butt, base_angle, seg)
		var tip: Vector2 = _points[SEGMENTS]
		for i in SEGMENTS:
			var arm: Vector2 = (tip - _points[i]) / length
			# 2D cross product: torque of the tip load about joint i.
			var torque := (arm.x * load.y - arm.y * load.x) * LOAD_TORQUE
			var k: float = _stiffness[i]
			var c := 2.0 * sqrt(k) * DAMPING
			var acc: float = torque - k * angles[i] - c * velocities[i]
			velocities[i] += acc * h
			angles[i] = clampf(angles[i] + velocities[i] * h, -0.6, 0.6)
	_forward(butt, base_angle, seg)


## A sudden jolt (a fish turning, a strike): adds angular velocity, most at the tip.
func kick(strength: float) -> void:
	for i in SEGMENTS:
		var s := float(i + 1) / float(SEGMENTS)
		velocities[i] += strength * s * s


func points() -> PackedVector2Array:
	return _points


func tip() -> Vector2:
	return _points[SEGMENTS]


## Total bend from butt to tip in radians (for tests and the debug view).
func total_bend() -> float:
	var t := 0.0
	for a: float in angles:
		t += a
	return t


func _forward(butt: Vector2, base_angle: float, seg: float) -> void:
	var angle := base_angle
	_points[0] = butt
	for i in SEGMENTS:
		angle += angles[i]
		_points[i + 1] = _points[i] + Vector2(cos(angle), sin(angle)) * seg
