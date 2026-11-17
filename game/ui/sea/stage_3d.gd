class_name Stage3D
extends Node3D
## The place the angler stands on, in 3D (roadmap R5): the base of every
## standing-place scene (Bridge3D, Quay3D). It owns what they share: the
## frame (the edge of the water runs along x at edge_z, square to the shore),
## the lamps that glow as the daylight goes, the neighbouring anglers with
## their rods, and the helpers that build shapes and materials in code.
## A subclass sets its numbers in _init, builds its surface in
## _build_surface() and calls build(). The spot's positions name their stage
## in data (position.stage); Stage3D.make(kind) creates it. Visual only.
##
## Local frame: +X along the edge away from the angler, +Y up, +Z towards the
## water; the origin is on the deck at the edge.

const KINDS: Array[String] = ["bridge", "quay"]

const ALONG := Vector2(-1.0, 0.0)           ## along the edge, to the angler's left (water metres: x right, z out)
const NORMAL := Vector2(0.0, 1.0)           ## towards the water
const DECK_Y := 0.6
const ROD_DIR := Vector3(0.12, 0.42, 0.9)
const ROD_LEN := 3.0
const HANDS := Vector3(0.0, 1.12, 0.28)
const JACKETS: Array[Color] = [Color(0.10, 0.14, 0.24), Color(0.30, 0.19, 0.13), Color(0.20, 0.24, 0.16), Color(0.26, 0.27, 0.30)]

## Set by the subclass before build().
var kind := ""
var edge_z := 0.844                 ## how far out from the angler the edge is
var ready_yaw := 0.9                ## the view's turn along the edge while getting ready
var length := 100.0
var people_at: Array[float] = [3.4, 5.4, 8.2, 11.8]
var stand_back := 0.34              ## how far behind the edge the neighbours stand
var lamp_first := 7.0
var lamp_step := 20.0
var lamp_height := 5.2

var _people: Array[Node3D] = []
var _rods: Array = []          # per person: [lower MeshInstance3D, upper MeshInstance3D]
var _tips: Array[Vector3] = [] # local tip of each rod
var _lamp_mat: StandardMaterial3D
var _lights: Array[OmniLight3D] = []
var _steel: StandardMaterial3D
## The debug menu can switch the lamps' real lights off to measure their cost.
var lights_enabled := true


## The stage of a kind (KINDS), or null for "" or an unknown kind.
static func make(stage_kind: String) -> Stage3D:
	match stage_kind:
		"bridge":
			return Bridge3D.new()
		"quay":
			return Quay3D.new()
	return null


func build() -> void:
	var f3 := Vector3(ALONG.x, 0.0, -ALONG.y)
	var n3 := Vector3(NORMAL.x, 0.0, -NORMAL.y)
	transform = Transform3D(Basis(f3, Vector3.UP, n3), Vector3(0.0, DECK_Y, -edge_z))
	_steel = _material(Color(0.13, 0.19, 0.19), 0.55, 0.42, 2.5)
	_build_surface()
	_build_lamps(_steel)
	for i in people_at.size():
		_build_person(i)


## The deck, the rail or coping and everything else of the place itself.
func _build_surface() -> void:
	pass


## Lamps glow as the daylight goes (light: 1 day, 0 night).
func set_light(light: float) -> void:
	var dark := clampf((0.75 - light) / 0.5, 0.0, 1.0)
	_lamp_mat.emission_energy_multiplier = 0.05 + 6.0 * dark
	for l: OmniLight3D in _lights:
		l.light_energy = 5.0 * dark
		l.visible = lights_enabled and dark > 0.02


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


## Where neighbour i's lure is on the water: cast_m out from the edge, side
## (-1..1) along it. Vector2(x right, z out).
func lure_water(i: int, cast_m: float, side: float) -> Vector2:
	var t := tip_water(i)
	return Vector2(t.x, t.z) + NORMAL * cast_m * 0.85 + ALONG * side * cast_m


# ------------------------------------------------------------------ building

func _build_lamps(steel: StandardMaterial3D) -> void:
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.albedo_color = Color(0.95, 0.93, 0.85)
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = Color(1.0, 0.82, 0.52)
	var x := lamp_first
	var n := 0
	while x < length - 10.0:
		var pole := CylinderMesh.new()
		pole.top_radius = 0.045
		pole.bottom_radius = 0.085
		pole.height = lamp_height
		pole.radial_segments = 10
		_mesh(pole, steel).position = Vector3(x, lamp_height * 0.5, -0.3)
		_box(Vector3(1.5, 0.05, 0.05), Vector3(x, lamp_height - 0.05, -0.3), steel)
		for sgn: float in [-1.0, 1.0]:
			var globe := SphereMesh.new()
			globe.radius = 0.15
			globe.height = 0.3
			globe.radial_segments = 12
			globe.rings = 6
			_mesh(globe, _lamp_mat).position = Vector3(x + sgn * 0.75, lamp_height - 0.22, -0.3)
		if n < 2:
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.8, 0.52)
			light.omni_range = 17.0
			light.omni_attenuation = 1.4
			light.position = Vector3(x, lamp_height - 0.4, -0.3)
			add_child(light)
			_lights.append(light)
		x += lamp_step
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
	person.position = Vector3(people_at[i], 0.0, -stand_back - 0.08 * rng.randf())
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
