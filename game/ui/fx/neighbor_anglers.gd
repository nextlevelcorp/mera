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

## The neighbours' lines and fish on the 2D overlay; their bodies and rods
## are 3D (Bridge3D). tips and lures are screen points per person.
func draw_lines(ci: CanvasItem, size: Vector2, light: float, tips: PackedVector2Array, lures: PackedVector2Array) -> void:
	var line_col := Color(1, 1, 1, 0.10 + 0.22 * light)
	for i in mini(people.size(), tips.size()):
		var p: Dictionary = people[i]
		var tip := tips[i]
		var lure := lures[i]
		var state := int(p["state"])
		var hang := size.y * 0.55 / maxf(float(i) * 0.9 + 2.0, 1.0)
		if state == S.LIFT:
			lure = lure.lerp(tip + Vector2(0.0, hang), smoothstep(0.0, LIFT_S, float(p["t"])))
		elif state == S.RECAST:
			lure = tip + Vector2(0.0, hang)
		# A quadratic curve tip -> lure; the belly shrinks as the line comes tight.
		var belly := (1.0 - clampf(float(p["bend"]) * 1.4, 0.0, 1.0)) * size.y * 0.07
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
			var r := clampf(hang * 0.06, 2.0, 7.0)
			for k in int(p["fish"]):
				var at := tip.lerp(lure, 0.45 + 0.25 * k)
				var wag := sin(float(p["t"]) * 14.0 + k) * r * 0.6
				ci.draw_line(at + Vector2(wag, -r * 1.4), at + Vector2(-wag, r * 1.4), fish_col, r, true)
		elif state == S.IDLE or state == S.NIBBLE:
			ci.draw_circle(lure, 1.6, Color(0.95, 0.75, 0.3, 0.7))


func _ring(ci: CanvasItem, centre: Vector2, r: float, color: Color) -> void:
	ci.draw_set_transform(centre, 0.0, Vector2(1.0, 0.3))
	ci.draw_arc(Vector2.ZERO, r, 0.0, TAU, 12, color, 1.0, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
