class_name VerletRope
extends RefCounted
## A fishing line as a chain of point masses joined by distance constraints
## (Verlet integration, Nature of Code springs and forces). Screen-space and
## visual only: the fight's line tension comes from FightSim, not from here.
## Deterministic: the same inputs give the same shape.

var points := PackedVector2Array()
var segment_length := 0.0
var iterations := 12
var damping := 0.98

var _previous := PackedVector2Array()


func _init(start: Vector2, end: Vector2, count: int = 16, slack: float = 1.05) -> void:
	for i in count:
		points.append(start.lerp(end, float(i) / (count - 1)))
	_previous = points.duplicate()
	set_total_length(start.distance_to(end) * slack)


func set_total_length(total: float) -> void:
	segment_length = maxf(total, 0.0) / (points.size() - 1)


func total_length() -> float:
	return segment_length * (points.size() - 1)


## Advances the chain by dt with both ends pinned. force is an acceleration
## (gravity plus wind) in pixels per second squared.
func step(dt: float, start: Vector2, end: Vector2, force: Vector2) -> void:
	var last := points.size() - 1
	for i in range(1, last):
		var p := points[i]
		var velocity := (p - _previous[i]) * damping
		_previous[i] = p
		points[i] = p + velocity + force * dt * dt
	points[0] = start
	points[last] = end
	_previous[0] = start
	_previous[last] = end
	for _k in iterations:
		for i in last:
			var a := points[i]
			var b := points[i + 1]
			var delta := b - a
			var d := delta.length()
			if d < 1e-6:
				continue
			var correction := delta * ((d - segment_length) / d)
			var a_pinned := i == 0
			var b_pinned := i + 1 == last
			if a_pinned and b_pinned:
				continue
			elif a_pinned:
				points[i + 1] = b - correction
			elif b_pinned:
				points[i] = a + correction
			else:
				points[i] = a + correction * 0.5
				points[i + 1] = b - correction * 0.5
