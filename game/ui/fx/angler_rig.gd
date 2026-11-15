class_name AnglerRig
extends RefCounted
## Draws the angler's first-person rig: the rod as a smooth tapered blank
## with cork grip, reel seat and ringed guides; a spinning reel with spool,
## rotor, bail and handle; and both hands. The fishing screen owns the state
## (rod points from RodSpring, phase, tension) and calls update() then draw()
## once per frame. Visual only, deterministic (no randf). Buffers are reused
## so drawing allocates nothing per frame.

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
var _quad := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])


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


func draw(ci: CanvasItem, pts: PackedVector2Array, size: Vector2) -> void:
	if pts.size() < 4:
		return
	_smooth(pts)
	var axis := (pts[2] - pts[0]).normalized()
	var normal := Vector2(-axis.y, axis.x)
	if normal.x > 0.0:
		normal = -normal   # the reel hangs to the lower left of the blank
	var shade := 1.0 - light
	# Tension makes the hands grip harder: a small tremor at high load.
	var tremor := Vector2(sin(time * 37.0), sin(time * 29.0 + 1.0)) * tension * tension * 1.6
	var seat := _at(0.16) + tremor
	var reel := seat + normal * 36.0
	var handle := reel + normal * 22.0 + (normal * cos(crank) * 22.0 + axis * sin(crank) * 12.0)
	var spool_pos := reel + axis * 24.0
	# Left forearm behind the reel, then reel, then rod, then right hand on top.
	var left_hand := handle.lerp(spool_pos + normal * 6.0, cast_pose)
	_forearm(ci, left_hand + Vector2(-6, 22), Vector2(size.x * 0.36, size.y * 1.22), 30.0, 46.0, shade)
	_draw_reel(ci, seat, reel, spool_pos, handle, axis, normal, shade)
	_draw_rod(ci, axis, shade)
	_left_hand(ci, left_hand, axis, normal, shade)
	var grip := _at(0.10) + tremor
	_forearm(ci, grip - axis * 18.0 + normal * -10.0, Vector2(size.x * 0.97, size.y * 1.22), 34.0, 54.0, shade)
	_right_hand(ci, grip, axis, normal, shade)


# ------------------------------------------------------------------ rod

func _draw_rod(ci: CanvasItem, axis: Vector2, shade: float) -> void:
	var n := _curve.size()
	var blank := Color(0.09, 0.09, 0.11)
	var shine := Color(0.78, 0.8, 0.88, 0.15 + 0.4 * light)
	# Taper in three widths along the blank.
	var a := int(n * 0.35)
	var b := int(n * 0.7)
	ci.draw_polyline(_curve.slice(0, a + 1), blank, 9.0, true)
	ci.draw_polyline(_curve.slice(a, b + 1), blank, 5.5, true)
	ci.draw_polyline(_curve.slice(b, n), blank, 2.6, true)
	ci.draw_polyline(_curve.slice(int(n * 0.12), n - 2), shine, 1.0, true)
	# Cork grip and the reel seat.
	var cork := Color(0.74, 0.58, 0.4).darkened(0.6 * shade)
	ci.draw_line(_at(0.0), _at(0.13), cork, 15.0, true)
	for t: float in [0.04, 0.08]:
		var p := _at(t)
		var nn := Vector2(-axis.y, axis.x) * 7.5
		ci.draw_line(p - nn, p + nn, cork.darkened(0.25), 1.5, true)
	ci.draw_line(_at(0.13), _at(0.19), Color(0.18, 0.19, 0.22), 12.0, true)
	# Ringed guides on short feet.
	var ring := Color(0.62, 0.64, 0.7).darkened(0.5 * shade)
	for i in GUIDES.size():
		var t: float = GUIDES[i]
		var p := _at(t)
		var r := lerpf(6.0, 2.2, float(i) / (GUIDES.size() - 1))
		var off := Vector2(axis.y, -axis.x) * (r + 2.0)
		if off.y > 0.0:
			off = -off
		ci.draw_line(p, p + off, ring, 1.5, true)
		ci.draw_arc(p + off * 1.4, r, 0.0, TAU, 12, ring, 1.4, true)


# ------------------------------------------------------------------ reel

func _draw_reel(ci: CanvasItem, seat: Vector2, reel: Vector2, spool_pos: Vector2, handle: Vector2, axis: Vector2, normal: Vector2, shade: float) -> void:
	var metal := Color(0.3, 0.32, 0.36).darkened(0.55 * shade)
	var dark := Color(0.12, 0.13, 0.15)
	var line_col := Color(0.88, 0.9, 0.95).darkened(0.5 * shade)
	# Foot from the seat down to the body.
	ci.draw_line(seat, reel, metal, 7.0, true)
	# Body.
	ci.draw_circle(reel, 19.0, metal)
	ci.draw_circle(reel, 11.0, metal.lightened(0.12))
	# Spool towards the rod tip: a band of line on a skirt, with ticks that
	# turn with the spool (backwards when the fish takes line).
	_rect_along(ci, spool_pos, axis, 22.0, 30.0, dark)
	_rect_along(ci, spool_pos + axis * 1.0, axis, 14.0, 26.0, line_col)
	for k in 2:
		var ph := spool + PI * k
		var tick := spool_pos + normal * (sin(ph) * 11.0)
		ci.draw_line(tick - axis * 6.0, tick + axis * 6.0, dark.lightened(0.15), 1.5, true)
	# Rotor arms and the bail wire: across the spool when closed, flipped back when open.
	var rot := sin(crank) * 12.0
	var arm_a := spool_pos - axis * 10.0 + normal * (16.0 + rot * 0.2)
	var arm_b := spool_pos - axis * 10.0 - normal * (16.0 - rot * 0.2)
	ci.draw_line(spool_pos - axis * 14.0, arm_a, metal, 4.0, true)
	ci.draw_line(spool_pos - axis * 14.0, arm_b, metal, 4.0, true)
	var bail_tip := spool_pos + axis * (6.0 if not bail_open else -18.0) + normal * (rot * 0.6)
	ci.draw_line(arm_a, bail_tip, Color(0.82, 0.84, 0.88).darkened(0.5 * shade), 2.0, true)
	ci.draw_line(bail_tip, arm_b, Color(0.82, 0.84, 0.88).darkened(0.5 * shade), 2.0, true)
	# Drag knob on the spool front.
	ci.draw_circle(spool_pos + axis * 17.0, 6.0, Color(0.55, 0.12, 0.1).darkened(0.5 * shade))
	# Handle arm and knob.
	ci.draw_line(reel, handle, dark, 5.0, true)
	ci.draw_circle(handle, 6.0, Color(0.2, 0.2, 0.22))


# ------------------------------------------------------------------ hands

func _skin(shade: float) -> Color:
	return Color(0.86, 0.66, 0.52).darkened(0.62 * shade)


## The right hand round the grip: palm, three fingers wrapped under the rod,
## the index finger stretched along the blank, the thumb on top.
func _right_hand(ci: CanvasItem, grip: Vector2, axis: Vector2, normal: Vector2, shade: float) -> void:
	var skin := _skin(shade)
	var crease := skin.darkened(0.22 + 0.2 * tension)
	_ellipse_fill(ci, grip - normal * 4.0, axis, 24.0, 19.0, skin)
	for k in 3:
		var base := grip - axis * (8.0 - 9.0 * k) + normal * 6.0
		_capsule(ci, base, base + normal * 16.0 - axis * 3.0, 8.5, skin, crease)
	_capsule(ci, grip + axis * 12.0 + normal * 4.0, grip + axis * 30.0 + normal * 5.0, 7.0, skin, crease)
	_capsule(ci, grip - normal * 12.0 - axis * 4.0, grip - normal * 4.0 + axis * 22.0, 8.0, skin.lightened(0.05), crease)


## The left hand on the handle knob: a loose fist whose wrist turns with the crank.
func _left_hand(ci: CanvasItem, knob: Vector2, axis: Vector2, normal: Vector2, shade: float) -> void:
	var skin := _skin(shade)
	var crease := skin.darkened(0.25)
	var turn := crank * 0.15
	var a := axis.rotated(sin(turn) * 0.25)
	_ellipse_fill(ci, knob + Vector2(-4, 10), a, 18.0, 15.0, skin)
	for k in 3:
		var base := knob + a * (6.0 - 7.0 * k) - normal * 2.0
		_capsule(ci, base, base + normal * 11.0, 7.0, skin, crease)
	_capsule(ci, knob + Vector2(-10, 6), knob + a * 14.0 + Vector2(-4, -2), 7.0, skin.lightened(0.05), crease)


## A forearm from the wrist to an elbow below the screen, tapered, with a cuff.
func _forearm(ci: CanvasItem, wrist: Vector2, elbow: Vector2, w_wrist: float, w_elbow: float, shade: float) -> void:
	var d := (elbow - wrist).normalized()
	var n := Vector2(-d.y, d.x)
	_quad[0] = wrist + n * w_wrist * 0.5
	_quad[1] = elbow + n * w_elbow * 0.5
	_quad[2] = elbow - n * w_elbow * 0.5
	_quad[3] = wrist - n * w_wrist * 0.5
	var sleeve := Color(0.16, 0.22, 0.3).darkened(0.5 * shade)
	ci.draw_colored_polygon(_quad, sleeve)
	ci.draw_line(wrist + d * 10.0 + n * w_wrist * 0.55, wrist + d * 10.0 - n * w_wrist * 0.55, sleeve.lightened(0.12), 7.0, true)


# ------------------------------------------------------------------ helpers

func _capsule(ci: CanvasItem, a: Vector2, b: Vector2, w: float, fill: Color, edge: Color) -> void:
	ci.draw_line(a, b, edge, w + 1.5, true)
	ci.draw_line(a, b, fill, w, true)
	ci.draw_circle(b, w * 0.5, fill)


func _ellipse_fill(ci: CanvasItem, centre: Vector2, axis: Vector2, rx: float, ry: float, color: Color) -> void:
	ci.draw_set_transform(centre, axis.angle(), Vector2(1.0, ry / rx))
	ci.draw_circle(Vector2.ZERO, rx, color)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _rect_along(ci: CanvasItem, centre: Vector2, axis: Vector2, length: float, width: float, color: Color) -> void:
	ci.draw_set_transform(centre, axis.angle(), Vector2.ONE)
	ci.draw_rect(Rect2(-length * 0.5, -width * 0.5, length, width), color)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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


## Point at share t (0 butt, 1 tip) of the smoothed blank's length.
func _at(t: float) -> Vector2:
	var count := _curve.size()
	for i in range(1, count):
		if _s[i] >= t:
			var span := maxf(_s[i] - _s[i - 1], 1e-6)
			return _curve[i - 1].lerp(_curve[i], (t - _s[i - 1]) / span)
	return _curve[count - 1]
