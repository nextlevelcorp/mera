class_name GullFlock
extends RefCounted
## Gulls working over the bait shoals (pillar 3: steering). Each gull steers
## towards a point circling its shoal, with a limited turn rate, glides and
## flaps, and now and then drops to the water and climbs again. Visual only,
## seeded; the shoals come from ShoalField. Positions in water metres plus a
## height: Vector3(x right, height, z out). Drawn as 3D instances (pose).

const PER_SHOAL := 4
const SPEED := 7.0
const TURN := 1.6
const SPAN := 0.55   ## the mesh is 2 m across, so a 1.1 m wingspan

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


## One gull's mesh, wingspan 2 m (x from -1 to 1), nose along -z, built once.
static func gull_mesh() -> ArrayMesh:
	var v := PackedVector3Array()
	var idx := PackedInt32Array()
	# Body: a thin diamond along z.
	v.append_array(PackedVector3Array([Vector3(0, 0.02, -0.28), Vector3(-0.07, 0, 0.0), Vector3(0.07, 0, 0.0), Vector3(0, 0.0, 0.3), Vector3(0, 0.07, 0.02)]))
	idx.append_array(PackedInt32Array([0, 1, 4, 0, 4, 2, 3, 4, 1, 3, 2, 4, 0, 2, 1, 3, 1, 2]))
	# Wings, left then right: root, mid and tip, each front and back.
	for sgn: float in [-1.0, 1.0]:
		var base := v.size()
		v.append_array(PackedVector3Array([
			Vector3(0.05 * sgn, 0.0, -0.1), Vector3(0.05 * sgn, 0.0, 0.14),
			Vector3(0.5 * sgn, 0.0, -0.12), Vector3(0.5 * sgn, 0.0, 0.1),
			Vector3(1.0 * sgn, 0.0, 0.08)]))
		idx.append_array(PackedInt32Array([base, base + 2, base + 1, base + 1, base + 2, base + 3, base + 2, base + 4, base + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Writes the flock into a MultiMesh (transform format 3D, custom data on):
## one instance per gull, in the 3D scene's coordinates (x right, y up, -z
## away), heading along its flight, the flap phase in the custom data.
func pose(mm: MultiMesh) -> void:
	if mm.instance_count != gulls.size():
		mm.instance_count = gulls.size()
	for i in gulls.size():
		mm.set_instance_transform(i, gull_transform(gulls[i]))
		mm.set_instance_custom_data(i, Color(float((gulls[i] as Dictionary)["phase"]), 0.0, 0.0, 0.0))


## Where and how a gull sits in the 3D scene: nose (-z of the mesh) along its flight.
static func gull_transform(g: Dictionary) -> Transform3D:
	var pos: Vector3 = g["pos"]
	var dir: Vector2 = g["dir"]
	# dir is (x, z_out); the scene's z is -z_out.
	var forward := Vector3(dir.x, 0.0, -dir.y)
	var right := forward.cross(Vector3.UP)
	return Transform3D(Basis(right, Vector3.UP, -forward) * SPAN, Vector3(pos.x, pos.y, -pos.z))
