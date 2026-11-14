class_name FishBody
extends RefCounted
## A fish seen from the shore near the surface, drawn procedurally (pillar 3:
## steering and oscillation). The head steers towards a target with a limited
## turn rate; the body is a spine of points behind it along the heading; a
## travelling sine wave runs down the spine, small at the head and largest at
## the tail. How fast and how wide the tail beats follows the fish's state in
## the fight simulation, so the player reads effort from the body as well as
## from the tension bar. Visual only: positions are in water-plane metres
## (x sideways, y out from the shore) and nothing here feeds the simulation.

const SEGMENTS := 10
const TURN_RATE := 2.5          # radians per second the heading can change
const SPEED_MAX := 3.0          # metres per second the head can move
## Tail beat per state: [frequency Hz, amplitude as a share of body length].
const BEAT := {"run": [3.2, 0.16], "rest": [1.1, 0.06], "thrash": [6.5, 0.30], "landing": [4.5, 0.22]}

var length_m: float
var head: Vector2
var heading: Vector2 = Vector2(0, 1)
var phase := 0.0
var _freq := 1.0
var _amp := 0.06


func _init(fish_length_m: float, start: Vector2) -> void:
	length_m = maxf(fish_length_m, 0.05)
	head = start


## target: where the simulation puts the fish; state: run, rest, thrash or
## landing. Heading leans away from the shore (fish face away from the pull).
func step(dt: float, target: Vector2, state: String) -> void:
	var to_target := target - head
	var move := to_target.limit_length(SPEED_MAX * dt)
	head += move
	# Fish face away from the pull but swing their flank now and then.
	var desired := Vector2(to_target.x * 0.6 + 0.7 * sin(phase * 0.05), 1.0).normalized()
	if state == "thrash" or state == "landing":
		desired = desired.rotated(sin(phase * 0.5) * 0.9)
	var angle := heading.angle_to(desired)
	heading = heading.rotated(clampf(angle, -TURN_RATE * dt, TURN_RATE * dt)).normalized()
	var beat: Array = BEAT.get(state, BEAT["rest"])
	# Ease towards the new beat so a change of state does not snap.
	_freq = lerpf(_freq, float(beat[0]), minf(dt * 4.0, 1.0))
	_amp = lerpf(_amp, float(beat[1]), minf(dt * 4.0, 1.0))
	phase = fmod(phase + TAU * _freq * dt, TAU * 64.0)


## Spine points from head to tail, in water-plane metres.
func spine() -> PackedVector2Array:
	var points := PackedVector2Array()
	var side := Vector2(-heading.y, heading.x)
	for i in SEGMENTS:
		var s := float(i) / float(SEGMENTS - 1)
		var sway := sin(phase - s * TAU * 0.9) * _amp * length_m * s * s
		points.append(head + heading * (s * length_m) + side * sway)
	return points


## Half-width of the body at s (0 head, 1 tail), as a share of length.
static func half_width(s: float) -> float:
	# The narrow tail stalk keeps some width so the fin stays joined to the body.
	return maxf(0.11 * sin(PI * clampf(s * 0.92 + 0.08, 0.0, 1.0)) * (1.0 - 0.55 * s), 0.022)


## Closed outline in water-plane metres: body sides plus a forked tail.
func outline() -> PackedVector2Array:
	var sp := spine()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in sp.size():
		var s := float(i) / float(sp.size() - 1)
		var a: Vector2 = sp[maxi(i - 1, 0)]
		var b: Vector2 = sp[mini(i + 1, sp.size() - 1)]
		var dir := (b - a).normalized()
		var normal := Vector2(-dir.y, dir.x)
		var w := half_width(s) * length_m
		left.append(sp[i] + normal * w)
		right.append(sp[i] - normal * w)
	var tail: Vector2 = sp[sp.size() - 1]
	var back := (tail - sp[sp.size() - 2]).normalized()
	var across := Vector2(-back.y, back.x)
	var fin := length_m * 0.16
	var out := PackedVector2Array()
	out.append_array(left)
	out.append(tail + back * fin + across * fin * 0.8)
	out.append(tail + back * fin * 0.35)
	out.append(tail + back * fin - across * fin * 0.8)
	right.reverse()
	out.append_array(right)
	return out
