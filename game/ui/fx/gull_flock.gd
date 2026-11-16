class_name GullFlock
extends RefCounted
## Gulls working over the bait shoals (pillar 3: steering). Each gull steers
## towards a point circling its shoal, with a limited turn rate, glides and
## flaps, and now and then drops to the water and climbs again. Visual only,
## seeded; the shoals come from ShoalField. Positions in water metres plus a
## height: Vector3(x right, height, z out).

const PER_SHOAL := 4
const SPEED := 7.0
const TURN := 1.6

var gulls: Array[Dictionary] = []
var dives: Array[Vector2] = []   ## water points hit since the last take_dives()

var _rng := RandomNumberGenerator.new()


func _init(shoal_count: int, seed_value: int = 3) -> void:
	_rng.seed = seed_value
	for s in shoal_count:
		for i in PER_SHOAL:
			gulls.append({
				"shoal": s, "pos": Vector3(_rng.randf_range(-20, 20), _rng.randf_range(8, 16), _rng.randf_range(20, 60)),
				"dir": Vector2.from_angle(_rng.randf() * TAU), "phase": _rng.randf() * TAU,
				"orbit": _rng.randf() * TAU, "orbit_r": _rng.randf_range(2.0, 6.0), "high": _rng.randf_range(5.0, 11.0),
				"dive": 0.0, "wait": _rng.randf_range(3.0, 12.0),
			})


func update(dt: float, field: ShoalField) -> void:
	dt = clampf(dt, 0.0, 0.1)
	for g: Dictionary in gulls:
		var s: Dictionary = field.shoals[int(g["shoal"]) % field.shoals.size()]
		var power := ShoalField.strength(s)
		var centre: Vector2 = s["pos"]
		g["orbit"] = float(g["orbit"]) + dt * 0.5
		var target := centre + Vector2.from_angle(float(g["orbit"])) * float(g["orbit_r"]) * (1.0 + 2.0 * (1.0 - power))
		var pos: Vector3 = g["pos"]
		var flat := Vector2(pos.x, pos.z)
		var dir: Vector2 = g["dir"]
		var want := (target - flat).normalized()
		dir = dir.rotated(clampf(dir.angle_to(want), -TURN * dt, TURN * dt)).normalized()
		flat += dir * SPEED * dt
		# Height: cruising, or a dive to the water and back up.
		var height := float(g["high"]) + 6.0 * (1.0 - power)
		g["wait"] = float(g["wait"]) - dt * power
		if float(g["dive"]) <= 0.0 and float(g["wait"]) <= 0.0 and flat.distance_to(centre) < float(s["radius"]):
			g["dive"] = 1.6
			g["wait"] = _rng.randf_range(5.0, 14.0)
		if float(g["dive"]) > 0.0:
			var before := float(g["dive"])
			g["dive"] = before - dt
			height *= absf(cos(PI * clampf(1.0 - float(g["dive"]) / 1.6, 0.0, 1.0)))
			if before > 0.8 and float(g["dive"]) <= 0.8:
				dives.append(flat)
		pos = Vector3(flat.x, lerpf(pos.y, maxf(height, 0.2), minf(dt * 3.0, 1.0)), flat.y)
		g["pos"] = pos
		g["dir"] = dir
		g["phase"] = float(g["phase"]) + dt * (9.0 if float(g["dive"]) > 0.0 else 5.0)


func take_dives() -> Array[Vector2]:
	var out := dives.duplicate()
	dives.clear()
	return out


## Draws each gull as two wings from its body, flapping; smaller with distance.
func draw(ci: CanvasItem, size: Vector2, light: float) -> void:
	var col := Color(0.93, 0.94, 0.96).lerp(Color(0.16, 0.17, 0.2), 1.0 - light)
	var tip_col := col.darkened(0.45)
	for g: Dictionary in gulls:
		var pos: Vector3 = g["pos"]
		if WaterView.view_depth(Vector2(pos.x, pos.z)) < 3.0:
			continue
		var at := WaterView.project(Vector2(pos.x, pos.z), pos.y, size)
		var span := clampf(size.y * 1.3 / (WaterView.view_depth(Vector2(pos.x, pos.z)) * WaterView.FOV), 3.0, 60.0) * 0.5
		var dir: Vector2 = g["dir"]
		var side := clampf(dir.x, -1.0, 1.0)   # banking: wings foreshorten when flying across
		var flap := sin(float(g["phase"])) * 0.55
		var w := span * (0.55 + 0.45 * absf(dir.y))
		var body := Vector2(side * span * 0.25, 0.0)
		for sgn: float in [-1.0, 1.0]:
			var elbow := at + Vector2(sgn * w * 0.5, -span * (0.12 + 0.3 * flap))
			var tip := at + Vector2(sgn * w, -span * (0.6 * flap) + span * 0.08)
			ci.draw_line(at, elbow, col, maxf(span * 0.14, 1.2), true)
			ci.draw_line(elbow, tip, tip_col, maxf(span * 0.09, 1.0), true)
		ci.draw_line(at - body, at + body, col, maxf(span * 0.2, 1.5), true)
