class_name TerminalTackle
extends RefCounted
## What hangs from the rod tip before the cast (owner's play notes,
## 2026-11-21: "the tackle at the end of the line should look different by
## float, sinker, bait and their kinds"). Drawn in code under the line's end:
## a jig head with a curly-tail grub, a hard minnow on a snap with two
## trebles, a sabiki's string of flashers over its lead, or a float rig
## (float, split shot, hook) with a shrimp or a live horse mackerel on the
## hook. A bare hook when nothing is on. Presentation only: it reads the
## kind and draws; `sway` is a small pendulum angle so it swings in the wind.

const STEEL := Color(0.72, 0.75, 0.78)
const LEAD := Color(0.38, 0.4, 0.42)
const LINE := Color(1, 1, 1, 0.55)


## The look for the rig in hand: "soft_plastic", "minnow", "sabiki",
## "float_shrimp", "float_live" or "bare" (needs baiting).
static func look_of(lure: Dictionary, float_bait: String, baited: bool) -> String:
	if not baited:
		return "bare"
	if Presentation.is_float(lure):
		return "float_live" if float_bait.begins_with("live") else "float_shrimp"
	var t := String(lure.get("type", ""))
	return t if t in ["soft_plastic", "minnow", "sabiki"] else "minnow"


## How long it is, in centimetres from the line's end (to fit it in a box).
static func extent_cm(look: String) -> float:
	return {"soft_plastic": 5.6, "minnow": 7.0, "sabiki": 11.2, "shrimp": 3.4, "live": 5.0, "float_shrimp": 12.0, "float_live": 13.0}.get(look, 3.0)


## Draws it hanging from `top` (the line's end), k pixels per centimetre.
static func draw(c: CanvasItem, top: Vector2, look: String, k: float, sway: float, t: float) -> void:
	var down := Vector2(sin(sway), cos(sway))
	match look:
		"soft_plastic":
			_jig(c, top, down, k, t)
		"minnow":
			_minnow(c, top, down, k, t)
		"sabiki":
			_sabiki(c, top, down, k, t)
		"shrimp":
			_shrimp(c, _hook(c, top, down, k), down, k)
		"live":
			_live(c, _hook(c, top, down, k), down, k, t)
		"float_shrimp", "float_live":
			var hook_at := _float_rig(c, top, down, k)
			if look == "float_live":
				_live(c, hook_at, down, k, t)
			else:
				_shrimp(c, hook_at, down, k)
		_:
			_hook(c, top + down * 2.0 * k, down, k)


static func _hook(c: CanvasItem, at: Vector2, down: Vector2, k: float) -> Vector2:
	var side := Vector2(-down.y, down.x)
	var shank_end := at + down * 1.6 * k
	c.draw_line(at, shank_end, STEEL, maxf(0.18 * k, 1.2), true)
	var bend := PackedVector2Array()
	for i in 9:
		var a := PI * float(i) / 8.0
		bend.append(shank_end + side * (0.45 * k) * (1.0 - cos(a)) + down * (0.45 * k) * sin(a))
	c.draw_polyline(bend, STEEL, maxf(0.18 * k, 1.2), true)
	var point := bend[bend.size() - 1]
	c.draw_line(point, point - down * 0.6 * k, STEEL, maxf(0.15 * k, 1.0), true)
	c.draw_circle(at, maxf(0.15 * k, 1.2), STEEL)   # the eye
	return shank_end


## A lead jig head with a curly-tail soft plastic.
static func _jig(c: CanvasItem, top: Vector2, down: Vector2, k: float, t: float) -> void:
	var side := Vector2(-down.y, down.x)
	var head := top + down * 0.6 * k
	c.draw_circle(head, 0.5 * k, Color(0.9, 0.3, 0.2))   # painted jig head
	c.draw_circle(head + side * 0.18 * k - down * 0.1 * k, 0.12 * k, Color(1, 1, 0.8))
	var body := PackedVector2Array()
	var colours := PackedColorArray()
	for i in 10:
		var u := float(i) / 9.0
		var w := 0.32 * k * (1.0 - 0.5 * u)
		var p := head + down * (0.4 + u * 3.0) * k
		body.append(p + side * w)
		colours.append(Color(0.65, 0.78, 0.25))
	for i in range(9, -1, -1):
		var u := float(i) / 9.0
		body.append(head + down * (0.4 + u * 3.0) * k - side * 0.32 * k * (1.0 - 0.5 * u))
		colours.append(Color(0.5, 0.62, 0.18))
	c.draw_polygon(body, colours)
	# The curly tail flutters.
	var tail := PackedVector2Array()
	var base := head + down * 3.4 * k
	for i in 10:
		var a := float(i) / 9.0 * 4.0 + sin(t * 6.0) * 0.6
		tail.append(base + side * sin(a) * 0.7 * k + down * (float(i) / 9.0) * 1.4 * k)
	c.draw_polyline(tail, Color(0.65, 0.78, 0.25), maxf(0.35 * k, 1.5), true)


## A hard minnow on a snap: lipped body, two trebles.
static func _minnow(c: CanvasItem, top: Vector2, down: Vector2, k: float, t: float) -> void:
	var side := Vector2(-down.y, down.x)
	var snap := top + down * 0.8 * k
	c.draw_line(top, snap, STEEL, maxf(0.15 * k, 1.0), true)
	c.draw_arc(snap + down * 0.25 * k, 0.25 * k, 0.0, TAU, 10, STEEL, maxf(0.12 * k, 1.0), true)
	var nose := snap + down * 0.5 * k
	var wob := sin(t * 3.0) * 0.06
	var axis := down.rotated(wob)
	var ax_side := Vector2(-axis.y, axis.x)
	var body := PackedVector2Array([nose, nose + axis * 1.2 * k + ax_side * 0.7 * k, nose + axis * 4.6 * k + ax_side * 0.35 * k,
		nose + axis * 5.6 * k, nose + axis * 4.6 * k - ax_side * 0.35 * k, nose + axis * 1.2 * k - ax_side * 0.7 * k])
	c.draw_colored_polygon(body, Color(0.8, 0.85, 0.88))
	c.draw_colored_polygon(PackedVector2Array([nose + axis * 0.8 * k + ax_side * 0.6 * k, nose + axis * 4.6 * k + ax_side * 0.3 * k, nose + axis * 4.6 * k, nose + axis * 0.9 * k]), Color(0.15, 0.35, 0.45))   # the back
	c.draw_colored_polygon(PackedVector2Array([nose, nose - axis * 0.9 * k + ax_side * 0.4 * k, nose - axis * 0.9 * k - ax_side * 0.4 * k]), Color(0.85, 0.9, 0.95, 0.6))   # the clear lip
	c.draw_circle(nose + axis * 0.8 * k + ax_side * 0.2 * k, 0.22 * k, Color(1, 0.85, 0.2))
	for at: float in [2.0, 5.4]:
		var root := nose + axis * at * k - ax_side * (0.5 * k if at < 3.0 else 0.0)
		for j in 3:
			var d := (-ax_side if at < 3.0 else axis).rotated(-0.7 + 0.7 * float(j))
			c.draw_line(root, root + d * 0.9 * k, STEEL, maxf(0.12 * k, 1.0), true)


## A sabiki: a string of small flasher hooks on droppers, the lead below.
static func _sabiki(c: CanvasItem, top: Vector2, down: Vector2, k: float, t: float) -> void:
	var side := Vector2(-down.y, down.x)
	var end := top + down * 9.0 * k
	c.draw_line(top, end, LINE, 1.2, true)
	for i in 6:
		var at := top + down * (0.8 + 1.3 * float(i)) * k
		var sgn := 1.0 if i % 2 == 0 else -1.0
		var tip := at + (side * sgn * 0.9 + down * 0.4) * k
		c.draw_line(at, tip, LINE, 1.0, true)
		# Fish-skin flasher and a tuft of feather; they glint in turn.
		var glint := 0.5 + 0.5 * sin(t * 4.0 + float(i) * 1.3)
		c.draw_line(tip, tip + down * 0.7 * k, Color(0.95, 0.9, 0.75).lerp(Color(1, 1, 1), glint), maxf(0.3 * k, 1.5), true)
		c.draw_circle(tip + down * 0.2 * k, maxf(0.16 * k, 1.2), Color(0.95, 0.3, 0.45) if i % 3 == 0 else Color(0.4, 0.85, 0.6))
	var lead := PackedVector2Array([end, end + down * 0.6 * k + side * 0.5 * k, end + down * 1.6 * k + side * 0.6 * k, end + down * 2.1 * k, end + down * 1.6 * k - side * 0.6 * k, end + down * 0.6 * k - side * 0.5 * k])
	c.draw_colored_polygon(lead, LEAD)   # pear lead


## A float, a split shot under it, then the hook; returns the hook's bend.
static func _float_rig(c: CanvasItem, top: Vector2, down: Vector2, k: float) -> Vector2:
	var side := Vector2(-down.y, down.x)
	var f0 := top + down * 0.3 * k
	var f1 := f0 + down * 3.2 * k
	c.draw_line(f0 - down * 0.8 * k, f0, Color(0.95, 0.3, 0.15), maxf(0.25 * k, 1.5), true)   # the antenna
	var body := PackedVector2Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		body.append(f0.lerp(f1, 0.5 + 0.5 * cos(a)) + side * sin(a) * 0.55 * k * (0.6 + 0.4 * cos(a)))
	c.draw_colored_polygon(body, Color(0.96, 0.95, 0.9))
	c.draw_colored_polygon(PackedVector2Array([body[0], body[1], body[11]]), Color(0.95, 0.25, 0.15))
	var shot := f1 + down * 2.2 * k
	c.draw_line(f1, shot, LINE, 1.0, true)
	c.draw_circle(shot, 0.3 * k, LEAD)
	c.draw_circle(shot + down * 0.7 * k, 0.22 * k, LEAD)
	var hook_top := shot + down * 1.8 * k
	c.draw_line(shot, hook_top, LINE, 1.0, true)
	return _hook(c, hook_top, down, k)


## A peeled shrimp threaded on the hook, curled.
static func _shrimp(c: CanvasItem, at: Vector2, down: Vector2, k: float) -> void:
	var side := Vector2(-down.y, down.x)
	for i in 7:
		var a := float(i) / 6.0 * 2.4
		var p := at + (side * (1.0 - cos(a)) * 0.6 + down * (sin(a) * 0.9 - 0.8)) * k
		c.draw_circle(p, (0.42 - 0.04 * float(i)) * k, Color(0.95, 0.68, 0.6).lerp(Color(0.98, 0.8, 0.72), float(i % 2)))


## A live horse mackerel hooked behind the back fin, kicking.
static func _live(c: CanvasItem, at: Vector2, down: Vector2, k: float, t: float) -> void:
	var side := Vector2(-down.y, down.x)
	var kick := sin(t * 9.0) * 0.4
	var head := at - side * 2.2 * k
	var tail := at + side * 2.6 * k + down * kick * k
	var body := PackedVector2Array([head, at - side * 1.0 * k - down * 0.6 * k, at + side * 1.6 * k - down * 0.35 * k, tail,
		at + side * 1.6 * k + down * 0.35 * k, at - side * 1.0 * k + down * 0.6 * k])
	c.draw_colored_polygon(body, Color(0.75, 0.82, 0.86))
	c.draw_colored_polygon(PackedVector2Array([head, at - side * 1.0 * k - down * 0.6 * k, at + side * 1.6 * k - down * 0.35 * k, tail]), Color(0.22, 0.42, 0.5))
	c.draw_colored_polygon(PackedVector2Array([tail, tail + side * 0.8 * k - down * 0.6 * k, tail + side * 0.4 * k, tail + side * 0.8 * k + down * 0.6 * k]), Color(0.3, 0.45, 0.5))
	c.draw_circle(head + side * 0.5 * k - down * 0.1 * k, 0.2 * k, Color(0.05, 0.05, 0.05))
