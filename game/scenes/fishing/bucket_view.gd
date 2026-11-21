class_name BucketView
extends Control
## The bucket at the angler's feet (owner's play notes, 2026-11-21: "end on a
## separate screen that shows the fish in a bucket"). Seen from above: the
## rim, the water, and every fish kept this visit swimming in it; the ones
## just landed drop in with a splash. A fish swims by steering (Nature of
## Code: a wandering heading, turned back from the wall), seeded so it is the
## same each time. The result panel sits to its right; the screen tells it
## which fish to show and which were put back.

const WANDER := 1.6     ## how fast a fish's wish to turn drifts (rad/s)
const SPEED := 0.09     ## swimming speed in bucket radii per second

var fish: Array[Dictionary] = []   ## {species_id, length_cm, new, pos, heading, wander, drop_t}
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## catches: the visit's kept fish ({species_id, length_cm}); the last
## new_count of them were just landed.
func open(catches: Array, new_count: int) -> void:
	_rng.seed = 7151 + catches.size()
	fish.clear()
	for i in catches.size():
		var c: Dictionary = catches[i]
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * 0.6
		fish.append({"species_id": String(c["species_id"]), "length_cm": float(c["length_cm"]), "new": i >= catches.size() - new_count,
			"pos": Vector2(cos(a), sin(a)) * r, "heading": _rng.randf() * TAU, "wander": 0.0,
			"drop_t": 0.0 if i < catches.size() - new_count else -0.25 * float(i - (catches.size() - new_count))})
	_t = 0.0
	visible = true


func centre() -> Vector2:
	return Vector2(size.x * 0.25, size.y * 0.55)


func radius() -> float:
	return minf(size.y * 0.31, size.x * 0.19)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	for f: Dictionary in fish:
		f["drop_t"] = float(f["drop_t"]) + delta
		if float(f["drop_t"]) < 0.0:
			continue
		# Wander: the wish to turn drifts; near the wall, steer back inside.
		f["wander"] = clampf(float(f["wander"]) + (_rng.randf() - 0.5) * WANDER * delta * 6.0, -1.2, 1.2)
		var pos: Vector2 = f["pos"]
		var turn := float(f["wander"])
		var out := pos.length()
		if out > 0.62:
			var inward := (-pos).angle()
			turn += angle_difference(float(f["heading"]), inward) * 3.0 * (out - 0.62) / 0.2
		var heading := float(f["heading"]) + turn * delta
		f["heading"] = heading
		var speed := SPEED * (2.5 if float(f["drop_t"]) < 0.8 else 1.0)   # a fresh fish darts about
		f["pos"] = (pos + Vector2.from_angle(heading) * speed * delta).limit_length(0.8)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.06, 0.09, 0.78))
	var c := centre()
	var r := radius()
	# Shadow, rim, inner wall, then the water.
	draw_circle(c + Vector2(10, 14), r * 1.12, Color(0, 0, 0, 0.35))
	draw_circle(c, r * 1.1, Color(0.86, 0.88, 0.9))
	draw_arc(c, r * 1.1, 0.0, TAU, 64, Color(0.62, 0.66, 0.7), 4.0, true)
	draw_circle(c, r * 1.0, Color(0.62, 0.7, 0.76))
	draw_circle(c, r * 0.95, Color(0.14, 0.32, 0.38))
	# Caustics: soft patches of light drifting over the bottom.
	for i in 9:
		var a := float(i) * 2.1 + _t * 0.12 * (1.0 + 0.1 * float(i))
		var p := c + Vector2(cos(a), sin(a * 1.3)) * r * (0.25 + 0.06 * float(i))
		draw_circle(p, r * (0.12 + 0.03 * sin(_t * 0.7 + float(i))), Color(0.5, 0.8, 0.8, 0.05))
	draw_arc(c + Vector2(-0.3, -0.35) * r, r * 0.5, PI * 1.05, PI * 1.45, 20, Color(1, 1, 1, 0.12), 6.0, true)   # sky glint
	for f: Dictionary in fish:
		_draw_fish(f, c, r)
	# The handle across the rim.
	draw_arc(c, r * 1.16, PI * 0.08, PI * 0.92, 40, Color(0.5, 0.52, 0.55), 5.0, true)


func _draw_fish(f: Dictionary, c: Vector2, r: float) -> void:
	var t := float(f["drop_t"])
	if t < 0.0:
		return
	var look: Array = LandingView.LOOKS.get(String(f["species_id"]), LandingView.LOOKS["istavrit"])
	var at := c + (f["pos"] as Vector2) * r * 0.95
	var dir := Vector2.from_angle(float(f["heading"]))
	var side := Vector2(-dir.y, dir.x)
	var len_px := clampf(float(f["length_cm"]) / 30.0, 0.4, 1.3) * r * 0.6
	var w := len_px * 0.17
	var flick := sin(_t * 9.0 + float(f["length_cm"])) * 0.25
	var head := at + dir * len_px * 0.5
	var tail := at - dir * len_px * 0.5
	var tail_dir := (-dir).rotated(flick)
	var body := PackedVector2Array([head, at + dir * len_px * 0.2 + side * w, at - dir * len_px * 0.25 + side * w * 0.7, tail,
		at - dir * len_px * 0.25 - side * w * 0.7, at + dir * len_px * 0.2 - side * w])
	draw_colored_polygon(PackedVector2Array([tail, tail + tail_dir.rotated(0.5) * w * 2.4, tail + tail_dir * w * 1.2, tail + tail_dir.rotated(-0.5) * w * 2.4]), (look[0] as Color).darkened(0.1))
	draw_colored_polygon(body, look[0])
	draw_line(head - dir * len_px * 0.1, tail + dir * len_px * 0.1, (look[1] as Color).darkened(0.1), maxf(w * 0.35, 1.5), true)
	draw_circle(head - dir * len_px * 0.12 + side * w * 0.45, maxf(w * 0.18, 1.5), Color(0.05, 0.05, 0.05))
	draw_circle(head - dir * len_px * 0.12 - side * w * 0.45, maxf(w * 0.18, 1.5), Color(0.05, 0.05, 0.05))
	if bool(f["new"]) and t < 1.6:
		# The splash it made going in.
		var k := t / 1.6
		draw_arc(at, len_px * (0.4 + 1.2 * k), 0.0, TAU, 32, Color(1, 1, 1, 0.6 * (1.0 - k)), 3.0, true)
