class_name FishingOverlay
extends Control
## The 2D layer over the 3D fishing scene: the line, lure, aim marker, water
## rings, splashes, gulls, the fish near the surface and on the line, the
## neighbours' lines, the cast power gauge and the tension bar. It reads the
## fishing screen's state and never changes a rule or a simulation; the two
## exceptions are view-only poses it hands to the 3D scene each frame (the
## bridge's neighbours and the angler's rig). Split from fishing_screen.gd
## on 2026-11-17 (roadmap R1) without changing what is drawn.

var scr: FishingScreen


func _init(screen: FishingScreen) -> void:
	scr = screen
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	match scr.phase:
		FishingScreen.Phase.READY, FishingScreen.Phase.CHARGE:
			_draw_line(false)
			if scr.is_float():
				_draw_float(scr._end_pos + Vector2(0.0, 8.0), 0.0)   # the float hangs from the tip (R18)
			else:
				draw_circle(scr._end_pos, 4.0, Color(0.95, 0.75, 0.3))
			if scr.phase == FishingScreen.Phase.CHARGE:
				_draw_aim_marker(size)
		FishingScreen.Phase.FLIGHT:
			_draw_line(false)
			draw_circle(scr._end_pos, 4.0, Color(0.95, 0.75, 0.3))
		FishingScreen.Phase.WAIT:
			_draw_line(false)
			if scr.is_float():
				_draw_float(scr._end_pos, scr.float_dip)
			else:
				draw_circle(scr._end_pos, 3.0, Color(0.95, 0.75, 0.3))
		FishingScreen.Phase.FIGHT, FishingScreen.Phase.RESULT:
			if scr._lifted() or scr._landing_now():
				_draw_line(false)
			elif not scr._hud.is_empty():
				_draw_fight(size)
		FishingScreen.Phase.LIFT:
			_draw_line(false)
	for p: Dictionary in scr._fx.particles:
		draw_circle(p["pos"], p["size"], Color(0.92, 0.96, 1.0, 0.85 * float(p["life"]) / float(p["max_life"])))
	if scr._water.stage != null:
		_draw_stage(size)
	scr._water.rig3d.pose(scr._rig, scr._rod.points(), size)
	if scr.phase == FishingScreen.Phase.FIGHT or (scr.phase == FishingScreen.Phase.RESULT and not scr._hud.is_empty()):
		_draw_tension_bar(size)
	if scr.phase == FishingScreen.Phase.CHARGE:
		_draw_power(size)


func _draw_fight(size: Vector2) -> void:
	var outcome: String = scr._hud["outcome"]
	var line_gone := outcome == FightSim.OUTCOME_LINE_BREAK or outcome == FightSim.OUTCOME_LEADER_CUT
	var pos := scr._fish_world()
	if not line_gone and scr.phase == FishingScreen.Phase.FIGHT:
		_draw_line(float(scr._hud["strain_ratio"]) > 0.0)
	# Which way it runs: a small arrow at the line's end, so side strain can be read.
	if scr.phase == FishingScreen.Phase.FIGHT and scr._hud["fish_state"] == "run" and not line_gone:
		var at := WaterView.project(pos, 0.0, size) + Vector2(0.0, -26.0)
		var hd := float(scr._hud["heading"])
		draw_colored_polygon(PackedVector2Array([at + Vector2(hd * 16.0, 0.0), at + Vector2(-hd * 6.0, -9.0), at + Vector2(-hd * 6.0, 9.0)]), Color(1, 1, 1, 0.85))


## The standing place is 3D (Stage3D); the overlay adds the neighbours' lines
## and the fish they lift.
func _draw_stage(size: Vector2) -> void:
	var bridge := scr._water.stage
	bridge.pose(scr._neighbours.people, scr._time)
	var tips := PackedVector2Array()
	var lures := PackedVector2Array()
	for i in scr._neighbours.people.size():
		var p: Dictionary = scr._neighbours.people[i]
		var t := bridge.tip_water(i)
		tips.append(WaterView.project(Vector2(t.x, t.z), t.y, size))
		lures.append(WaterView.project(bridge.lure_water(i, float(p["cast_m"]), float(p["side"])), 0.0, size))
	scr._neighbours.draw_lines(self, size, float(scr._env.get("light", 0.6)), tips, lures)


## The float on the water (R12): a red tip over a white body, cut off at the
## waterline, so a dip shows less of it and a take pulls it under.
func _draw_float(at: Vector2, dip: float) -> void:
	var water_y := at.y
	var top := at + Vector2(0.0, -15.0 + dip)
	draw_line(at + Vector2(-9.0, 1.0), at + Vector2(9.0, 1.0), Color(1, 1, 1, 0.35), 1.5, true)   # the meniscus
	if top.y + 5.0 < water_y:
		draw_rect(Rect2(top + Vector2(-3.5, 5.0), Vector2(7.0, minf(water_y - top.y - 5.0, 10.0))), Color(0.96, 0.95, 0.9))
	if top.y < water_y:
		draw_rect(Rect2(top + Vector2(-2.5, 0.0), Vector2(5.0, minf(water_y - top.y, 5.0))), Color(0.95, 0.25, 0.15))


## The line along the Verlet rope; warm-coloured and thicker while straining.
## The line as a thin thread: thicker and clearer near the rod, finer and
## fainter far out (distance), with the odd glint where the sun catches it.
## Warm and thicker while it strains.
func _draw_line(strained: bool) -> void:
	if scr._rope == null:
		return
	var pts := scr._rope.points
	var n := pts.size() - 1
	var light := float(scr._env.get("light", 0.6))
	var base := Color(1.0, 0.86, 0.58) if strained else Color(0.84, 0.91, 1.0).lerp(Color(1.0, 0.82, 0.62), 0.5 * (1.0 - light))
	for i in n:
		var t := float(i) / n
		var w := lerpf(1.7, 0.6, pow(t, 0.7)) * (1.4 if strained else 1.0)
		var col := base
		col.a = lerpf(0.85, 0.35, pow(t, 0.9))
		var ph := sin(scr._time * 2.7 + i * 1.9)
		if ph > 0.92:
			col = col.lerp(Color(1, 1, 1, 1), (ph - 0.92) / 0.08 * (0.35 + 0.65 * light))
		draw_line(pts[i], pts[i + 1], col, w, true)


## While charging: where the lure would land at the current power and aim
## (the skill error is not shown; it is added at release).
func _draw_aim_marker(size: Vector2) -> void:
	var c := CatchModel.cast(scr._k, scr._ctx["rod"], scr._ctx["lure"], scr._ctx["angler"], scr._ctx["position"], scr.conditions, maxf(FishingScreen.power_at(scr._charge_s), 0.15))
	var d := maxf(float(c["cast_m"]), float(scr._k["WAIT_END_M"]) + 2.0)
	var world := Vector2(-0.3 + tan(scr._aim) * d, FishingScreen.NEAR_DRAW_M + d)
	var centre := WaterView.project(world, 0.0, size)
	var aspect := size.x / maxf(size.y, 1.0)
	var rx := 0.8 / (world.y * aspect * WaterView.FOV) * size.x
	var ry := WaterView.CAM_HEIGHT * 0.8 / (world.y * world.y * WaterView.FOV) * size.y
	_ellipse(centre, maxf(rx, 6.0), maxf(ry, 2.0), Color(1, 1, 1, 0.6))
	_ellipse(centre, maxf(rx, 6.0) * 0.4, maxf(ry, 2.0) * 0.4, Color(1, 1, 1, 0.45))


func _ellipse(centre: Vector2, rx: float, ry: float, color: Color) -> void:
	if rx < 0.5 or color.a <= 0.01:
		return
	var points := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		points.append(centre + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(points, color, 1.2, true)


## Cast power: a vertical gauge beside the Cast button; the marker swings up
## and down and the top band is the best release.
func _draw_power(size: Vector2) -> void:
	var x := size.x - 290.0
	var y0 := size.y - 300.0
	var h := 260.0
	var p := FishingScreen.power_at(scr._charge_s)
	draw_rect(Rect2(x - 3, y0 - 3, 34, h + 6), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(x, y0, 28, h), Color(0.12, 0.14, 0.18, 0.9))
	draw_rect(Rect2(x, y0, 28, h * 0.1), Color(0.55, 0.85, 0.6))
	draw_rect(Rect2(x, y0 + h * (1.0 - p), 28, h * p), Color(0.95, 0.8, 0.35, 0.8))
	draw_rect(Rect2(x - 8, y0 + h * (1.0 - p) - 3, 44, 6), Color(1, 1, 1))


## Tension against the line's strength. Shape, not colour, tells the danger:
## a tick at the strain threshold, a thick block at the break point, and the
## numbers in kilograms (PRD F8, F18).
func _draw_tension_bar(size: Vector2) -> void:
	var w := minf(size.x * 0.46, 600.0)
	var h := 40.0
	var x := (size.x - w) * 0.5
	var y := 26.0
	var ratio: float = clampf(float(scr._hud["tension_ratio"]), 0.0, 1.0)
	draw_rect(Rect2(x - 3, y - 3, w + 6, h + 6), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(x, y, w, h), Color(0.12, 0.14, 0.18, 0.9))
	var fill := Color(0.55, 0.85, 0.6) if ratio < 0.6 else (Color(0.95, 0.8, 0.35) if ratio < 0.8 else Color(0.95, 0.4, 0.3))
	draw_rect(Rect2(x, y, w * ratio, h), fill)
	var thr := float(scr._hud["strain_threshold_ratio"])
	draw_line(Vector2(x + w * thr, y - 8), Vector2(x + w * thr, y + h + 8), Color(1, 1, 1), 3.0)
	draw_rect(Rect2(x + w - 8, y - 8, 8, h + 16), Color(1, 1, 1))
	var drag_ratio: float = clampf(float(scr._hud["drag_set_kg"]) / float(scr._hud["line_strength_kg"]), 0.0, 1.0)
	var nx := x + w * drag_ratio
	draw_colored_polygon(PackedVector2Array([Vector2(nx, y + h + 3), Vector2(nx - 9, y + h + 18), Vector2(nx + 9, y + h + 18)]), Color(1, 1, 1))
	var strain: float = clampf(float(scr._hud["strain_ratio"]), 0.0, 1.0)
	if strain > 0.0:
		draw_rect(Rect2(x, y - 14, w * strain, 6), Color(1.0, 0.35, 0.25))
