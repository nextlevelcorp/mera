class_name NeighborAnglers
extends RefCounted
## Other anglers along the bridge rail (Zengin 2009 counted hundreds a day),
## so the player fishes among people who are fishing too: they jig, get bites,
## fight, lift their fish over the rail and recast, at a pace tied to how
## often a bite comes at this place and hour. Visual only; seeded and
## deterministic for the same updates. The screen reads take_events() for the
## fish they lift (a distant splash).

enum S { IDLE, NIBBLE, FIGHT, LIFT, RECAST }

const COUNT := 4
const FIGHT_S := Vector2(3.0, 9.0)
const LIFT_S := 1.7
const RECAST_S := 1.4
const NIBBLE_S := 0.7

var people: Array[Dictionary] = []
var events: Array[Dictionary] = []

var _rng := RandomNumberGenerator.new()
var _mean_wait_s := 60.0
var _hull := PackedVector2Array()
var _line := PackedVector2Array()


func _init(seed_value: int = 5) -> void:
	_rng.seed = seed_value
	# Screen fractions along the rail (left of the player), size by distance along the bridge.
	var xs := [0.045, 0.13, 0.2, 0.30]
	var scales := [1.0, 0.86, 0.78, 0.66]
	var reach := [0.16, 0.14, 0.11, 0.10]     # rod length across the screen
	var rig := ["sabiki", "sabiki", "spin", "sabiki"]
	for i in COUNT:
		people.append({
			"x": xs[i], "scale": scales[i], "reach": reach[i], "rig": rig[i],
			"state": S.IDLE, "t": 0.0, "wait": _draw_wait(), "bend": 0.0, "bob": _rng.randf() * TAU,
			"cast_m": 5.0 + _rng.randf() * 9.0, "side": _rng.randf_range(-0.2, 0.2),
			"fish": 1, "tint": _rng.randf(), "jig": 0.0, "kick": 0.0,
		})


## mean_wait_s: how long a bite takes here and now (the player's median wait).
func set_pace(mean_wait_s: float) -> void:
	_mean_wait_s = clampf(mean_wait_s, 15.0, 300.0)


func update(dt: float) -> void:
	dt = clampf(dt, 0.0, 0.25)
	for p: Dictionary in people:
		p["t"] = float(p["t"]) + dt
		p["bob"] = float(p["bob"]) + dt
		p["kick"] = float(p["kick"]) * exp(-dt * 6.0)
		match int(p["state"]):
			S.IDLE:
				p["wait"] = float(p["wait"]) - dt
				# A little work on the lure now and then.
				if _rng.randf() < dt * 0.25:
					p["jig"] = 1.0
					p["kick"] = float(p["kick"]) - 0.5
				p["jig"] = maxf(float(p["jig"]) - dt * 1.5, 0.0)
				p["bend"] = lerpf(float(p["bend"]), 0.05, minf(dt * 4.0, 1.0))
				if float(p["wait"]) <= 0.0:
					_to(p, S.NIBBLE)
			S.NIBBLE:
				p["kick"] = float(p["kick"]) - 3.0 * dt * (1.0 if _rng.randf() < 0.5 else 0.2)
				if float(p["t"]) >= NIBBLE_S:
					p["fish"] = 1 if String(p["rig"]) != "sabiki" else _rng.randi_range(1, 3)
					p["dur"] = _rng.randf_range(FIGHT_S.x, FIGHT_S.y) if p["rig"] != "sabiki" else _rng.randf_range(1.5, 3.2)
					_to(p, S.FIGHT)
			S.FIGHT:
				var run := 0.55 + 0.35 * sin(float(p["t"]) * 2.6 + float(p["tint"]) * 9.0)
				p["bend"] = lerpf(float(p["bend"]), clampf(run, 0.2, 1.0), minf(dt * 6.0, 1.0))
				if _rng.randf() < dt * 2.0:
					p["kick"] = float(p["kick"]) + _rng.randf_range(-1.0, 1.0)
				if float(p["t"]) >= float(p["dur"]):
					_to(p, S.LIFT)
			S.LIFT:
				p["bend"] = lerpf(float(p["bend"]), 0.7, minf(dt * 6.0, 1.0))
				if float(p["t"]) >= LIFT_S:
					events.append({"type": "lift", "x": p["x"], "fish": p["fish"]})
					_to(p, S.RECAST)
			S.RECAST:
				p["bend"] = lerpf(float(p["bend"]), 0.0, minf(dt * 5.0, 1.0))
				if float(p["t"]) >= RECAST_S:
					p["cast_m"] = 5.0 + _rng.randf() * 9.0
					p["side"] = _rng.randf_range(-0.2, 0.2)
					p["wait"] = _draw_wait()
					_to(p, S.IDLE)


## Fish they lifted since the last call.
func take_events() -> Array[Dictionary]:
	var out := events.duplicate()
	events.clear()
	return out


func _to(p: Dictionary, s: int) -> void:
	p["state"] = s
	p["t"] = 0.0


func _draw_wait() -> float:
	# Exponential, like the model's waits, and never instant.
	return maxf(-log(1.0 - _rng.randf()) * _mean_wait_s, 6.0)


# ------------------------------------------------------------------ drawing

## rail_y: screen y of the rail's top bar. light: 0..1 from the scene.
func draw(ci: CanvasItem, size: Vector2, rail_y: float, light: float, time: float) -> void:
	var dusk := 1.0 - light
	var cloth := Color(0.12, 0.14, 0.19).lerp(Color(0.03, 0.035, 0.05), dusk)
	var skin := Color(0.5, 0.38, 0.3).lerp(Color(0.05, 0.05, 0.06), dusk)
	var rod_col := Color(0.07, 0.07, 0.09)
	var line_col := Color(1, 1, 1, 0.22 + 0.18 * light)
	# Back to front: the smallest, furthest figure first.
	var order := range(COUNT)
	order.reverse()
	for idx: int in order:
		_person(ci, people[idx], size, rail_y, cloth, skin, rod_col, line_col, time, light)


func _person(ci: CanvasItem, p: Dictionary, size: Vector2, rail_y: float, cloth: Color, skin: Color, rod_col: Color, line_col: Color, time: float, light: float) -> void:
	var s: float = p["scale"]
	var h := size.y * 0.30 * s
	var feet := Vector2(size.x * float(p["x"]), rail_y + 14.0)
	var sway := sin(time * 0.7 + float(p["tint"]) * 6.0) * 1.5 * s
	var shoulder := feet + Vector2(sway, -h * 0.82)
	var head := shoulder + Vector2(sway * 0.5, -h * 0.17)
	var vest := cloth.lerp(Color(0.2, 0.28, 0.4) if float(p["tint"]) < 0.5 else Color(0.34, 0.2, 0.16), 0.55 * light)
	# Legs and torso, seen from behind.
	var w := h * 0.17
	_hull.clear()
	_hull.append_array(PackedVector2Array([
		feet + Vector2(-w * 0.55, 0.0), feet + Vector2(w * 0.55, 0.0), shoulder + Vector2(w * 0.95, h * 0.04),
		shoulder + Vector2(w * 0.7, -h * 0.02), shoulder + Vector2(-w * 0.7, -h * 0.02), shoulder + Vector2(-w * 0.95, h * 0.04)]))
	ci.draw_colored_polygon(_hull, vest)
	ci.draw_circle(head, h * 0.085, skin)
	ci.draw_arc(head, h * 0.09, PI, TAU, 8, cloth, h * 0.05, true)   # cap
	# Hands at the rail, the rod from there out over the water.
	var hands := shoulder + Vector2(w * 0.9, h * 0.26)
	var bend: float = float(p["bend"]) + 0.15 * float(p["kick"])
	var reach := size.x * float(p["reach"]) * 1.1
	var tip_dir := Vector2(0.62, -0.78).normalized()
	var tip_free := hands + tip_dir * reach
	var droop := Vector2(0.0, size.y * 0.16 * bend * s) + Vector2(size.x * 0.02 * bend * s, 0.0)
	var tip := tip_free + droop + Vector2(0.0, sin(float(p["bob"]) * 1.1) * 1.5 * s)
	var mid := hands.lerp(tip, 0.55) + droop * 0.25
	ci.draw_line(shoulder + Vector2(w * 0.6, h * 0.04), hands, vest.lightened(0.1), h * 0.07, true)
	ci.draw_polyline(PackedVector2Array([hands, mid, tip]), rod_col, maxf(2.0 * s, 1.5), true)
	# Line to the water, with a belly while slack and a straight pull in a fight.
	var d := float(p["cast_m"])
	var lure := WaterView.project(Vector2(-6.0 + 14.0 * float(p["x"]) + float(p["side"]) * d, NEAR_M + d), 0.0, size)
	var state := int(p["state"])
	if state == S.LIFT:
		var up := smoothstep(0.0, LIFT_S, float(p["t"]))
		lure = lure.lerp(tip + Vector2(0.0, h * 0.22), up)
	# A quadratic curve tip -> lure; the belly shrinks as the line comes tight.
	var belly := (1.0 - clampf(bend * 1.4, 0.0, 1.0)) * size.y * 0.04
	var ctrl := tip.lerp(lure, 0.5) + Vector2(0.0, belly)
	_line.resize(9)
	for k in 9:
		var t := float(k) / 8.0
		_line[k] = tip.lerp(ctrl, t).lerp(ctrl.lerp(lure, t), t)
	ci.draw_polyline(_line, line_col, 1.0, true)
	if state == S.FIGHT:
		_ring(ci, lure, 5.0 + 3.0 * sin(float(p["t"]) * 7.0), Color(1, 1, 1, 0.35))
	if state == S.LIFT or state == S.RECAST and float(p["t"]) < 0.5:
		var fish_col := Color(0.82, 0.86, 0.9, 0.95).darkened(0.5 * (1.0 - light))
		var n := int(p["fish"])
		for k in n:
			var at := tip.lerp(lure, 0.2 + 0.25 * k) + Vector2(0.0, 6.0 * k)
			ci.draw_circle(at, 4.0 * s + 1.0, fish_col)
			ci.draw_line(at + Vector2(3, 0), at + Vector2(7, -2), fish_col, 1.5, true)
	elif state == S.IDLE or state == S.NIBBLE:
		ci.draw_circle(lure, 1.6, Color(0.95, 0.75, 0.3, 0.7))


func _ring(ci: CanvasItem, centre: Vector2, r: float, color: Color) -> void:
	ci.draw_set_transform(centre, 0.0, Vector2(1.0, 0.3))
	ci.draw_arc(Vector2.ZERO, r, 0.0, TAU, 12, color, 1.0, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


const NEAR_M := 4.6
