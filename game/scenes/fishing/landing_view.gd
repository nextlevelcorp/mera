class_name LandingView
extends Control
## The landing, close up (owner's play notes, 2026-11-21: "landing the fish
## is poor; make it realistic"). When the fish reaches the foot of the wall
## the view looks down over the rail: the bridge's side (or the quay's
## stones) drops to the water, and the fish hangs on the line, swinging and
## kicking, as the angler reels it up the lift_height_m of the wall. A ruler
## on the wall gives the height. At the top it is swung over the rail; if the
## line parts or the hook comes out it falls back. Drawn in code; it only
## reads state the fishing screen sets each frame (no rules here) and lets
## every touch through to the controls above it.

const FALL_S := 0.9   ## a lost fish falls back into the water
const OVER_S := 0.7   ## a landed fish is swung over the rail

## Per-species look, side on: back, flank, belly, and a mark ("scutes",
## "stripes", "spot" or "").
const LOOKS := {
	"istavrit": [Color(0.22, 0.42, 0.5), Color(0.72, 0.8, 0.84), Color(0.92, 0.93, 0.92), "scutes"],
	"lufer": [Color(0.2, 0.42, 0.42), Color(0.55, 0.68, 0.66), Color(0.88, 0.9, 0.88), ""],
	"palamut": [Color(0.12, 0.2, 0.38), Color(0.6, 0.66, 0.72), Color(0.9, 0.91, 0.92), "stripes"],
	"izmarit": [Color(0.42, 0.45, 0.5), Color(0.68, 0.7, 0.74), Color(0.88, 0.88, 0.9), "spot"],
	"kalamar": [Color(0.82, 0.55, 0.6), Color(0.95, 0.82, 0.8), Color(0.97, 0.92, 0.9), "squid"],
	"cipura": [Color(0.45, 0.52, 0.58), Color(0.78, 0.8, 0.82), Color(0.92, 0.92, 0.9), "gold_brow"],
	"levrek": [Color(0.38, 0.45, 0.5), Color(0.78, 0.82, 0.85), Color(0.94, 0.95, 0.95), ""],
	"sargoz": [Color(0.55, 0.58, 0.6), Color(0.82, 0.83, 0.84), Color(0.93, 0.93, 0.92), "bands"],
}

var lift := 0.0            ## 0 at the water, 1 at the rail
var height_m := 5.0
var kicking := false
var swing := 0.0           ## the pendulum angle of the fish on the line (rad)
var length_cm := 20.0
var species_id := "istavrit"
var quay := false
var light := 1.0
var tension_share := 0.0   ## line tension / line strength
var _t := 0.0
var _end := ""             ## "", "over" (landed) or "fall" (lost)
var _end_t := 0.0
var _end_lift := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func open(species: String, fish_cm: float, lift_height_m: float, on_quay: bool) -> void:
	species_id = species
	length_cm = fish_cm
	height_m = lift_height_m
	quay = on_quay
	_end = ""
	_end_t = 0.0
	visible = true


## The landing ended: "over" swings it over the rail, "fall" drops it back.
func finish(how: String) -> void:
	if not visible or _end != "":
		return
	_end = how
	_end_t = 0.0
	_end_lift = lift


func ended() -> bool:
	return _end != ""


func is_done() -> bool:
	return _end != "" and _end_t >= (OVER_S if _end == "over" else FALL_S)


## Moved on by the fishing screen's frame, so the tests see the same timing.
func advance(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _end != "":
		_end_t += delta
		if is_done():
			visible = false
	queue_redraw()


## Geometry, in pixels: the rail's top, the water line, the rod tip.
func rail_y() -> float:
	return size.y * (0.16 if quay else 0.13)


func water_y() -> float:
	return size.y * 0.9


func tip() -> Vector2:
	return Vector2(size.x * 0.6, -size.y * 0.02)


## Where the fish's mouth is now.
func mouth() -> Vector2:
	var l := lift
	var y := lerpf(water_y(), rail_y() + size.y * 0.12, l)
	if _end == "fall":
		var f := clampf(_end_t / FALL_S, 0.0, 1.0)
		y = lerpf(lerpf(water_y(), rail_y() + size.y * 0.12, _end_lift), water_y() + size.y * 0.1, f * f)
	elif _end == "over":
		var o := clampf(_end_t / OVER_S, 0.0, 1.0)
		y = lerpf(rail_y() + size.y * 0.12, -size.y * 0.25, o * o)
	var rope := tip().distance_to(Vector2(tip().x, y))
	return Vector2(tip().x + sin(swing) * rope * 0.35, y)


## Pixels per metre of fish: bigger as it comes up towards the eye.
func fish_scale() -> float:
	return size.y * lerpf(0.55, 1.0, lift) * 0.9


func _draw() -> void:
	var s := size
	var dusk := clampf(light, 0.15, 1.0)
	# The deck or the quay underfoot, beyond the rail at the top.
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.42, 0.42, 0.4).darkened(0.6 * (1.0 - dusk)))
	_draw_water(s, dusk)
	_draw_wall(s, dusk)
	var m := mouth()
	var line_c := Color(0.95, 0.97, 1.0, 0.85) if tension_share < 0.85 else Color(1.0, 0.45, 0.35, 0.95)
	if _end != "fall" or _end_t < 0.05:
		draw_line(tip(), m, line_c, 2.0, true)
	_draw_fish(m, dusk)
	_draw_rail(s, dusk)
	_draw_ruler(s, dusk)


func _draw_water(s: Vector2, dusk: float) -> void:
	var top := rail_y() + s.y * 0.1
	draw_rect(Rect2(0, top, s.x, s.y - top), Color(0.05, 0.16, 0.22).lerp(Color(0.12, 0.32, 0.4), dusk * 0.6))
	# Long swell bands seen from above, drifting.
	for i in 14:
		var y := top + fposmod(float(i) * 0.08 * s.y + _t * 9.0, s.y - top)
		var a := 0.05 + 0.04 * sin(float(i) * 1.7)
		draw_line(Vector2(0, y), Vector2(s.x, y + 18.0 * sin(float(i) + _t * 0.3)), Color(0.6, 0.8, 0.85, a * dusk), 3.0, true)
	# Where the fish left the water: rings, and splashes while it hangs low.
	var foot := Vector2(tip().x, water_y())
	for k in 3:
		var r := fposmod(_t * 70.0 + float(k) * 60.0, 180.0)
		draw_arc(foot, r, 0.0, TAU, 40, Color(0.85, 0.95, 1.0, 0.35 * (1.0 - r / 180.0)), 2.0, true)
	if lift < 0.12 and kicking:
		for k in 8:
			var a := float(k) * 0.8 + _t * 3.0
			draw_circle(foot + Vector2(cos(a) * 40.0, -absf(sin(a * 1.3)) * 50.0), 4.0, Color(0.9, 0.97, 1.0, 0.7))


func _draw_wall(s: Vector2, dusk: float) -> void:
	var top := rail_y()
	var wall_c := Color(0.32, 0.34, 0.36) if not quay else Color(0.5, 0.47, 0.42)
	wall_c = wall_c.darkened(0.6 * (1.0 - dusk))
	if quay:
		# Quay stones: two courses of blocks at the top, then the water.
		for row in 2:
			var y := top + float(row) * s.y * 0.05
			draw_rect(Rect2(0, y, s.x, s.y * 0.05), wall_c.darkened(0.1 * row))
			for b in 9:
				var x := float(b) * s.x / 8.0 + (40.0 if row == 1 else 0.0)
				draw_line(Vector2(x, y), Vector2(x, y + s.y * 0.05), wall_c.darkened(0.35), 2.0)
	else:
		# The bridge deck's side girder, with rivets, and a pier going down.
		draw_rect(Rect2(0, top, s.x, s.y * 0.1), wall_c)
		draw_rect(Rect2(0, top + s.y * 0.085, s.x, s.y * 0.015), wall_c.darkened(0.4))
		for b in 24:
			draw_circle(Vector2(float(b) * s.x / 23.0, top + s.y * 0.02), 3.0, wall_c.lightened(0.25))
		var pier := Rect2(s.x * 0.08, top + s.y * 0.1, s.x * 0.16, s.y)
		draw_rect(pier, wall_c.darkened(0.15))
		draw_rect(Rect2(pier.position.x + pier.size.x * 0.75, pier.position.y, pier.size.x * 0.25, pier.size.y), wall_c.darkened(0.35))
		# Weed and wet at the waterline.
		draw_rect(Rect2(pier.position.x, water_y() - s.y * 0.05, pier.size.x, s.y * 0.05), Color(0.16, 0.26, 0.16, 0.9))


func _draw_rail(s: Vector2, dusk: float) -> void:
	var steel := Color(0.16, 0.18, 0.2).lerp(Color(0.3, 0.33, 0.36), dusk)
	var top := rail_y()
	if quay:
		draw_rect(Rect2(0, top - 10.0, s.x, 12.0), steel.lightened(0.1))   # the edge's iron strip
		return
	draw_rect(Rect2(0, top - 34.0, s.x, 16.0), steel)
	draw_line(Vector2(0, top - 34.0), Vector2(s.x, top - 34.0), steel.lightened(0.35), 2.0)
	for b in 17:
		var x := float(b) * s.x / 16.0
		draw_rect(Rect2(x - 4.0, top - 20.0, 8.0, 22.0), steel.darkened(0.2))


## An engraved ruler on the wall: metres above the water, and the fish's mark.
func _draw_ruler(s: Vector2, _dusk: float) -> void:
	var x := s.x * 0.9
	var y0 := water_y()
	var y1 := rail_y() + s.y * 0.12
	var brass := Color(0.86, 0.72, 0.42, 0.9)
	draw_line(Vector2(x, y0), Vector2(x, y1), brass, 2.0, true)
	var font := get_theme_default_font()
	for m in int(ceil(height_m)) + 1:
		var f := minf(float(m) / height_m, 1.0)
		var y := lerpf(y0, y1, f)
		draw_line(Vector2(x - 10.0, y), Vector2(x + 10.0, y), brass, 2.0, true)
		draw_string(font, Vector2(x + 16.0, y + 7.0), "%d m" % m if m <= height_m else "", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, brass)
	var fy := lerpf(y0, y1, clampf(lift, 0.0, 1.0))
	draw_colored_polygon(PackedVector2Array([Vector2(x - 12.0, fy), Vector2(x - 30.0, fy - 9.0), Vector2(x - 30.0, fy + 9.0)]), brass)
	draw_string(font, Vector2(x - 120.0, fy + 7.0), "%.1f m" % (lift * height_m), HORIZONTAL_ALIGNMENT_RIGHT, 84, 20, brass)


## The fish hangs head up from the hook, its body bending with each kick.
func _draw_fish(m: Vector2, dusk: float) -> void:
	var look: Array = LOOKS.get(species_id, LOOKS["istavrit"])
	var len_px := clampf(length_cm / 100.0 * fish_scale(), 46.0, size.y * 0.55)
	var depth := len_px * 0.2
	var bend := (0.45 if kicking else 0.08) * sin(_t * (13.0 if kicking else 3.0))
	var tilt := swing * 0.6
	if _end == "over":
		tilt += clampf(_end_t / OVER_S, 0.0, 1.0) * 2.4
	elif _end == "fall":
		tilt += _end_t * 5.0
	var spine := PackedVector2Array()
	for i in 13:
		var u := float(i) / 12.0
		var off := bend * u * u * len_px * 0.35
		spine.append(m + Vector2(off, u * len_px).rotated(tilt))
	var top_edge := PackedVector2Array()
	var bottom_edge := PackedVector2Array()
	for i in spine.size():
		var u := float(i) / float(spine.size() - 1)
		var w := depth * sin(PI * clampf(u * 1.05 + 0.04, 0.0, 1.0)) * (1.0 - 0.45 * u)
		var dir := (spine[mini(i + 1, spine.size() - 1)] - spine[maxi(i - 1, 0)]).normalized()
		var side := Vector2(-dir.y, dir.x)
		top_edge.append(spine[i] + side * w)
		bottom_edge.append(spine[i] - side * w)
	var tail_root := spine[spine.size() - 1]
	var tail_dir := (tail_root - spine[spine.size() - 2]).normalized()
	var tail_side := Vector2(-tail_dir.y, tail_dir.x)
	var shade := lerpf(0.5, 1.0, dusk)
	if String(look[3]) != "squid":
		draw_colored_polygon(PackedVector2Array([tail_root, tail_root + tail_dir * depth * 1.1 + tail_side * depth * 0.9, tail_root + tail_dir * depth * 0.55, tail_root + tail_dir * depth * 1.1 - tail_side * depth * 0.9]), (look[0] as Color) * shade)
	var body := PackedVector2Array(top_edge)
	var reversed := bottom_edge.duplicate()
	reversed.reverse()
	body.append_array(reversed)
	var colours := PackedColorArray()
	for i in top_edge.size():
		colours.append((look[0] as Color) * shade)
	for i in reversed.size():
		colours.append((look[2] as Color) * shade)
	draw_polygon(body, colours)
	# The flank's sheen along the middle, and the species' mark.
	var mid := PackedVector2Array()
	for i in range(1, spine.size() - 1):
		mid.append(spine[i].lerp(top_edge[i], 0.15))
	draw_polyline(mid, (look[1] as Color) * shade, maxf(depth * 0.5, 3.0), true)
	match String(look[3]):
		"scutes":
			for i in range(3, spine.size() - 1):
				draw_circle(spine[i].lerp(top_edge[i], 0.1), maxf(depth * 0.07, 1.5), Color(0.9, 0.92, 0.92, 0.8) * shade)
		"stripes":
			for i in range(3, spine.size() - 2, 2):
				draw_line(top_edge[i], spine[i].lerp(top_edge[i], 0.3), Color(0.08, 0.12, 0.25, 0.85), maxf(depth * 0.1, 2.0), true)
		"spot":
			draw_circle(spine[5].lerp(top_edge[5], 0.3), maxf(depth * 0.22, 3.0), Color(0.1, 0.1, 0.12, 0.8))
		"gold_brow":
			# The gilthead's gold band between the eyes.
			draw_line(spine[1].lerp(top_edge[1], 0.6), spine[2].lerp(top_edge[2], 0.7), Color(0.95, 0.78, 0.3), maxf(depth * 0.18, 2.5), true)
		"bands":
			# The white sea bream's dark bands and the black saddle by the tail.
			for i in range(3, spine.size() - 3, 2):
				draw_line(top_edge[i], spine[i].lerp(bottom_edge[i], 0.4), Color(0.25, 0.27, 0.3, 0.5), maxf(depth * 0.12, 2.0), true)
			draw_circle(spine[spine.size() - 2], maxf(depth * 0.35, 3.0), Color(0.08, 0.08, 0.1, 0.85))
		"squid":
			# Arms wrapped round the jig at the top, the fins' diamond at the mantle's tip.
			var up := (spine[0] - spine[1]).normalized()
			var across := Vector2(-up.y, up.x)
			for a in 8:
				var off := (float(a) - 3.5) / 3.5
				var arm := PackedVector2Array()
				for j in 6:
					var u := float(j) / 5.0
					arm.append(spine[0] + across * off * depth * 0.6 + up * u * len_px * 0.28 + across * sin(_t * 4.0 + float(a) + u * 3.0) * depth * 0.2 * u)
				draw_polyline(arm, (look[0] as Color) * shade, maxf(depth * 0.16, 2.0), true)
			var tip := spine[spine.size() - 1]
			var back := spine[spine.size() - 4]
			var fin_side := Vector2(-tail_dir.y, tail_dir.x)
			draw_colored_polygon(PackedVector2Array([back, back.lerp(tip, 0.5) + fin_side * depth * 1.3, tip, back.lerp(tip, 0.5) - fin_side * depth * 1.3]), Color((look[0] as Color) * shade, 0.85))
	var eye := spine[1].lerp(top_edge[1], 0.3)
	draw_circle(eye, maxf(depth * 0.18, 3.0), Color(0.92, 0.9, 0.8))
	draw_circle(eye, maxf(depth * 0.1, 1.5), Color(0.05, 0.05, 0.05))
	# Drips from the tail while it is wet.
	if _end == "":
		for k in 4:
			var d := fposmod(_t * 1.6 + float(k) * 0.25, 1.0)
			draw_circle(tail_root + Vector2(0, d * size.y * 0.3), 2.5, Color(0.85, 0.95, 1.0, 0.7 * (1.0 - d)))
