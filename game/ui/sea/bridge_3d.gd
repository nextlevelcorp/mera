class_name Bridge3D
extends Node3D
## The bridge the angler stands on, in 3D (owner, 2026-11-16: graphics): the
## deck, the steel rail running away to the left, lamp standards with lit
## lamps at dusk and night, and the neighbouring anglers as lit figures with
## rods. The rail runs square to the water; while getting ready the angler
## looks along it (WaterView.BRIDGE_YAW), so the rail and the row of anglers
## recede towards the far shore, as in any photo of the Galata Bridge. Shapes and materials are made in code (no model assets yet).
## Visual only. Local frame: +X along the rail away from the angler, +Y up,
## +Z towards the water; the origin is on the deck under the rail.

const RAIL_Z := 0.844                       ## the rail runs along x, this far out from the angler
const RAIL_P := Vector2(0.0, RAIL_Z)        ## a point of the rail: x right, z out (water metres)
const RAIL_F := Vector2(-1.0, 0.0)          ## along the rail, to the angler's left
const RAIL_N := Vector2(0.0, 1.0)           ## towards the water
const DECK_Y := 0.6
const RAIL_H := 1.05
const LENGTH := 150.0
const PEOPLE_AT: Array[float] = [3.4, 5.4, 8.2, 11.8]
const ROD_DIR := Vector3(0.12, 0.42, 0.9)
const ROD_LEN := 3.0
const HANDS := Vector3(0.0, 1.12, 0.28)
const JACKETS: Array[Color] = [Color(0.10, 0.14, 0.24), Color(0.30, 0.19, 0.13), Color(0.20, 0.24, 0.16), Color(0.26, 0.27, 0.30)]

var _people: Array[Node3D] = []
var _rods: Array = []          # per person: [lower MeshInstance3D, upper MeshInstance3D]
var _tips: Array[Vector3] = [] # local tip of each rod
var _lamp_mat: StandardMaterial3D
var _lights: Array[OmniLight3D] = []


func _init() -> void:
	var f3 := Vector3(RAIL_F.x, 0.0, -RAIL_F.y)
	var n3 := Vector3(RAIL_N.x, 0.0, -RAIL_N.y)
	transform = Transform3D(Basis(f3, Vector3.UP, n3), Vector3(RAIL_P.x, DECK_Y, -RAIL_P.y))
	var paving := _material(Color(0.36, 0.35, 0.34), 0.0, 0.82, 0.45)
	var steel := _material(Color(0.13, 0.19, 0.19), 0.55, 0.42, 2.5)
	var back := -6.0
	_box(Vector3(LENGTH, 0.6, 14.3), Vector3(LENGTH * 0.5 + back, -0.3, -6.9), paving)
	_box(Vector3(LENGTH, 0.16, 0.32), Vector3(LENGTH * 0.5 + back, 0.08, 0.02), _material(Color(0.42, 0.41, 0.4), 0.0, 0.7, 0.8))
	# Rails: a round handrail and two thinner bars.
	for bar: Array in [[RAIL_H, 0.036], [0.72, 0.016], [0.4, 0.016]]:
		var m := CylinderMesh.new()
		m.top_radius = bar[1]
		m.bottom_radius = bar[1]
		m.height = LENGTH
		m.radial_segments = 10
		m.rings = 1
		var mi := _mesh(m, steel)
		mi.rotation = Vector3(0.0, 0.0, PI * 0.5)
		mi.position = Vector3(LENGTH * 0.5 + back, bar[0], 0.0)
	# Posts every 1.5 m, drawn in one call.
	var post := BoxMesh.new()
	post.size = Vector3(0.06, RAIL_H, 0.06)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = post
	mm.instance_count = 64
	for i in mm.instance_count:
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(back + 1.5 * i, RAIL_H * 0.5, 0.0)))
	var posts := MultiMeshInstance3D.new()
	posts.multimesh = mm
	posts.material_override = steel
	add_child(posts)
	_build_lamps(steel)
	for i in PEOPLE_AT.size():
		_build_person(i)


## Lamps glow as the daylight goes (light: 1 day, 0 night).
func set_light(light: float) -> void:
	var dark := clampf((0.75 - light) / 0.5, 0.0, 1.0)
	_lamp_mat.emission_energy_multiplier = 0.05 + 6.0 * dark
	for l: OmniLight3D in _lights:
		l.light_energy = 5.0 * dark
		l.visible = dark > 0.02


## Poses the neighbours' rods from NeighborAnglers.people.
func pose(people: Array[Dictionary], time: float) -> void:
	var dir := ROD_DIR.normalized()
	for i in mini(people.size(), _people.size()):
		var p: Dictionary = people[i]
		var bend: float = float(p["bend"]) + 0.15 * float(p["kick"])
		var tip_free := HANDS + dir * ROD_LEN
		var droop := Vector3(0.0, -0.95 * bend, 0.22 * bend)
		var tip := tip_free + droop + Vector3(0.0, sin(float(p["bob"]) * 1.1) * 0.02, 0.0)
		var mid := HANDS + dir * ROD_LEN * 0.55 + droop * 0.22
		_tips[i] = tip
		_stretch(_rods[i][0], HANDS, mid)
		_stretch(_rods[i][1], mid, tip)
		_people[i].rotation.z = sin(time * 0.7 + i * 1.9) * 0.012


## Rod tip of neighbour i in water metres: Vector3(x right, height, z out).
func tip_water(i: int) -> Vector3:
	var g: Vector3 = _people[i].transform * _tips[i]
	g = transform * g
	return Vector3(g.x, g.y, -g.z)


## Where neighbour i's lure is on the water: cast_m out from the rail, side
## (-1..1) along it. Vector2(x right, z out).
func lure_water(i: int, cast_m: float, side: float) -> Vector2:
	var t := tip_water(i)
	return Vector2(t.x, t.z) + RAIL_N * cast_m * 0.85 + RAIL_F * side * cast_m


# ------------------------------------------------------------------ building

func _build_lamps(steel: StandardMaterial3D) -> void:
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.albedo_color = Color(0.95, 0.93, 0.85)
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = Color(1.0, 0.82, 0.52)
	var x := 7.0
	var n := 0
	while x < LENGTH - 10.0:
		var pole := CylinderMesh.new()
		pole.top_radius = 0.045
		pole.bottom_radius = 0.085
		pole.height = 5.2
		pole.radial_segments = 10
		_mesh(pole, steel).position = Vector3(x, 2.6, -0.3)
		_box(Vector3(1.5, 0.05, 0.05), Vector3(x, 5.15, -0.3), steel)
		for sgn: float in [-1.0, 1.0]:
			var globe := SphereMesh.new()
			globe.radius = 0.15
			globe.height = 0.3
			globe.radial_segments = 12
			globe.rings = 6
			_mesh(globe, _lamp_mat).position = Vector3(x + sgn * 0.75, 4.98, -0.3)
		if n < 2:
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.8, 0.52)
			light.omni_range = 17.0
			light.omni_attenuation = 1.4
			light.position = Vector3(x, 4.8, -0.3)
			add_child(light)
			_lights.append(light)
		x += 20.0
		n += 1
	# The lamp behind the angler: lights the hands, the rod and the near rail.
	var near := OmniLight3D.new()
	near.light_color = Color(1.0, 0.8, 0.52)
	near.omni_range = 9.0
	near.omni_attenuation = 1.2
	near.position = Vector3(-3.0, 4.2, -1.2)
	add_child(near)
	_lights.append(near)


func _build_person(i: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 100 + i
	var person := Node3D.new()
	person.position = Vector3(PEOPLE_AT[i], 0.0, -0.34 - 0.08 * rng.randf())
	person.rotation.y = rng.randf_range(-0.25, 0.25)
	var tall := rng.randf_range(0.94, 1.06)
	person.scale = Vector3.ONE * tall
	add_child(person)
	var jacket := _material(JACKETS[i % JACKETS.size()], 0.0, 0.85, 3.0)
	var trousers := _material(Color(0.09, 0.1, 0.13), 0.0, 0.9, 3.0)
	var skin := _material(Color(0.62, 0.45, 0.36), 0.0, 0.6, 0.0)
	var dark := _material(Color(0.07, 0.07, 0.08), 0.0, 0.7, 0.0)
	for sgn: float in [-1.0, 1.0]:
		_limb(person, Vector3(sgn * 0.1, 0.0, 0.0), Vector3(sgn * 0.11, 0.92, -0.02), 0.085, trousers)
		_limb(person, Vector3(sgn * 0.1, 0.03, 0.06), Vector3(sgn * 0.1, 0.03, -0.1), 0.06, dark)   # shoes
		# Arms: shoulder to elbow to the hands on the rod.
		var shoulder := Vector3(sgn * 0.22, 1.42, 0.02)
		var elbow := Vector3(sgn * 0.26, 1.18, 0.14)
		_limb(person, shoulder, elbow, 0.058, jacket)
		_limb(person, elbow, HANDS + Vector3(sgn * 0.05, 0.0, -0.02), 0.048, jacket)
	_limb(person, Vector3(0.0, 0.9, -0.01), Vector3(0.0, 1.46, 0.04), 0.2, jacket).scale = Vector3(1.0, 1.0, 0.72)
	var head := SphereMesh.new()
	head.radius = 0.105
	head.height = 0.23
	head.radial_segments = 14
	head.rings = 8
	var head_mi := MeshInstance3D.new()
	head_mi.mesh = head
	head_mi.material_override = skin
	head_mi.position = Vector3(0.0, 1.66, 0.05)
	person.add_child(head_mi)
	# A cap or a beanie.
	var cap := SphereMesh.new()
	cap.radius = 0.112
	cap.height = 0.14
	cap.is_hemisphere = true
	cap.radial_segments = 14
	cap.rings = 5
	var cap_mi := MeshInstance3D.new()
	cap_mi.mesh = cap
	cap_mi.material_override = dark if i % 2 == 0 else jacket
	cap_mi.position = Vector3(0.0, 1.69, 0.05)
	person.add_child(cap_mi)
	if i % 2 == 0:
		# A bucket for the catch at the feet.
		var bucket := CylinderMesh.new()
		bucket.top_radius = 0.15
		bucket.bottom_radius = 0.12
		bucket.height = 0.28
		bucket.radial_segments = 12
		var b := MeshInstance3D.new()
		b.mesh = bucket
		b.material_override = _material(Color(0.75, 0.78, 0.8) if i == 0 else Color(0.2, 0.35, 0.6), 0.0, 0.5, 0.0)
		b.position = Vector3(0.38, 0.14, 0.0)
		person.add_child(b)
	var rod_mat := _material(Color(0.05, 0.05, 0.06), 0.3, 0.3, 0.0)
	var parts: Array = []
	for r: Array in [[0.012, 0.008], [0.008, 0.003]]:
		var seg := CylinderMesh.new()
		seg.bottom_radius = r[0]
		seg.top_radius = r[1]
		seg.height = 1.0
		seg.radial_segments = 6
		seg.rings = 1
		var mi := MeshInstance3D.new()
		mi.mesh = seg
		mi.material_override = rod_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		person.add_child(mi)
		parts.append(mi)
	_people.append(person)
	_rods.append(parts)
	_tips.append(HANDS + ROD_DIR.normalized() * ROD_LEN)


## A capsule between two points.
func _limb(parent: Node3D, from: Vector3, to: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(from.distance_to(to) + radius * 2.0, radius * 2.0)
	m.radial_segments = 10
	m.rings = 4
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	parent.add_child(mi)
	_stretch(mi, from, to, false)
	return mi


## Puts a unit-height mesh (its Y axis) between two points; scale_len stretches it.
func _stretch(mi: MeshInstance3D, from: Vector3, to: Vector3, scale_len: bool = true) -> void:
	var d := to - from
	var len := maxf(d.length(), 0.001)
	var y := d / len
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	mi.transform = Transform3D(Basis(x, y * (len if scale_len else 1.0), z), (from + to) * 0.5)


func _box(size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	var mi := _mesh(m, mat)
	mi.position = at
	return mi


func _mesh(m: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	add_child(mi)
	return mi


## A lit material with the shared grain as wear; tile sets how fine it is (0: none).
func _material(colour: Color, metallic: float, roughness: float, tile: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.metallic = metallic
	mat.roughness = roughness
	if tile > 0.0:
		mat.albedo_texture = SeaMaps.grain()
		mat.albedo_color = colour * 1.5
		mat.normal_enabled = true
		mat.normal_texture = SeaMaps.grain_normal()
		mat.normal_scale = 0.5
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3.ONE * tile
	return mat
