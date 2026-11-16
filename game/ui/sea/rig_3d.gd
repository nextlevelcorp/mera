class_name Rig3D
extends Node3D
## The angler's own rod, reel, hands and forearms as lit 3D shapes (owner,
## 2026-11-16: graphics). AnglerRig and RodSpring still own the motion in
## screen space; every frame this lifts their points to 3D at a depth that
## grows along the rod, so the shapes land exactly where the 2D rig was drawn
## (the line, drawn on the overlay, still meets the rod tip) while the sun,
## the lamps and the sky light them. Sizes are authored in the old screen
## pixels and scaled by depth. Visual only; shapes made in code.

const DEPTH_BUTT := 0.75
const DEPTH_TIP := 2.6
const SIDES := 8
const BLANK_RINGS := 22

var _size := Vector2(1280, 720)
var _blank: MeshInstance3D
var _cork: MeshInstance3D
var _seat: MeshInstance3D
var _arm_l: MeshInstance3D
var _arm_r: MeshInstance3D
var _guides: Array[MeshInstance3D] = []
var _reel: Node3D
var _rotor: Node3D
var _bail: MeshInstance3D
var _spool_spin: Node3D
var _handle_arm: MeshInstance3D
var _knob: MeshInstance3D
var _hand_r: Node3D
var _hand_l: Node3D
var _centres := PackedVector3Array()
var _radii := PackedFloat32Array()


func _init() -> void:
	var blank_mat := _mat(Color(0.05, 0.05, 0.06), 0.35, 0.22)
	var cork_mat := _mat(Color(0.74, 0.58, 0.4), 0.0, 0.9, 40.0)
	var metal := _mat(Color(0.32, 0.34, 0.38), 0.85, 0.32)
	var dark := _mat(Color(0.1, 0.105, 0.12), 0.5, 0.4)
	var sleeve := _mat(Color(0.14, 0.19, 0.27), 0.0, 0.92, 25.0)
	var skin := _mat(Color(0.84, 0.63, 0.5), 0.0, 0.55)
	_blank = _holder(blank_mat)
	_cork = _holder(cork_mat)
	_seat = _holder(dark)
	_arm_l = _holder(sleeve)
	_arm_r = _holder(sleeve)
	for i in AnglerRig.GUIDES.size():
		var torus := TorusMesh.new()
		torus.inner_radius = 0.78
		torus.outer_radius = 1.0
		torus.rings = 12
		torus.ring_segments = 5
		var g := MeshInstance3D.new()
		g.mesh = torus
		g.material_override = metal
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(g)
		_guides.append(g)
	_build_reel(metal, dark)
	_hand_r = Node3D.new()
	add_child(_hand_r)
	_blob(_hand_r, Vector3(0, -4, 5), Vector3(24, 19, 13), skin)
	for k in 3:
		_capsule(_hand_r, Vector3(-8.0 + 9.0 * k, 6, 9), Vector3(-11.0 + 9.0 * k, 22, 0), 4.4, skin)
	_capsule(_hand_r, Vector3(12, 4, 8), Vector3(30, 5, 6), 3.6, skin)
	_capsule(_hand_r, Vector3(-4, -12, 6), Vector3(22, -4, 8), 4.1, skin)
	_hand_l = Node3D.new()
	add_child(_hand_l)
	_blob(_hand_l, Vector3(0, 9, 2), Vector3(15, 12, 8), skin)
	for k in 3:
		_capsule(_hand_l, Vector3(6.0 - 7.0 * k, -2, 8), Vector3(6.0 - 7.0 * k, 11, 2), 3.7, skin)
	_capsule(_hand_l, Vector3(-8, 4, 8), Vector3(10, -2, 8), 3.6, skin)


## rig: the 2D rig after update(); pts: RodSpring.points(); size: the overlay's size.
func pose(rig: AnglerRig, pts: PackedVector2Array, size: Vector2) -> void:
	if pts.size() < 4 or size.y < 2.0:
		visible = false
		return
	visible = true
	_size = size
	rig.prepare(pts)
	var axis2 := (pts[2] - pts[0]).normalized()
	var normal2 := Vector2(-axis2.y, axis2.x)
	if normal2.x > 0.0:
		normal2 = -normal2
	var tremor := Vector2(sin(rig.time * 37.0), sin(rig.time * 29.0 + 1.0)) * rig.tension * rig.tension * 1.6
	# Blank, cork grip and reel seat as tubes along the smoothed rod.
	_tube_along(_blank, rig, 0.12, 1.0, 4.6, 1.3, BLANK_RINGS)
	_tube_along(_cork, rig, 0.0, 0.13, 7.6, 7.2, 4)
	_tube_along(_seat, rig, 0.13, 0.19, 6.2, 5.6, 3)
	# Guides: rings standing off the blank.
	for i in _guides.size():
		var t: float = AnglerRig.GUIDES[i]
		var p2 := rig.at(t)
		var r_px := lerpf(6.0, 2.2, float(i) / (_guides.size() - 1))
		var off := Vector2(axis2.y, -axis2.x) * (r_px + 2.0)
		if off.y > 0.0:
			off = -off
		var z := _depth(t)
		var along := (_lift(rig.at(minf(t + 0.03, 1.0)), _depth(minf(t + 0.03, 1.0))) - _lift(p2, z)).normalized()
		var s := r_px * _mpp(z)
		_guides[i].transform = Transform3D(_basis_y(along) * s, _lift(p2 + off * 1.4, z))
	# Reel and hands share the rod's frame at the seat.
	var seat2 := rig.at(0.16) + tremor
	var z_seat := _depth(0.16)
	var frame := _frame(seat2, axis2, normal2, z_seat)
	var reel2 := seat2 + normal2 * 36.0
	_reel.transform = Transform3D(frame, _lift(reel2, z_seat))
	_rotor.rotation.x = rig.crank
	_spool_spin.rotation.x = rig.spool
	_bail.position.x = -10.0 if rig.bail_open else 8.0
	var knob_local := Vector3(sin(rig.crank) * 12.0, 22.0 + cos(rig.crank) * 22.0, 7.0)
	_knob.position = knob_local
	_stretch(_handle_arm, Vector3(0, 0, 7), knob_local)
	var handle2 := reel2 + normal2 * 22.0 + (normal2 * cos(rig.crank) * 22.0 + axis2 * sin(rig.crank) * 12.0)
	var left2 := handle2.lerp(reel2 + axis2 * 24.0 + normal2 * 6.0, rig.cast_pose)
	_hand_l.transform = Transform3D(frame.rotated(frame.z.normalized(), sin(rig.crank * 0.15) * 0.25), _lift(left2, z_seat - 0.02))
	var grip2 := rig.at(0.10) + tremor
	var z_grip := _depth(0.10)
	_hand_r.transform = Transform3D(_frame(grip2, axis2, normal2, z_grip), _lift(grip2, z_grip))
	# Forearms from the wrists to elbows below the screen.
	_arm(_arm_l, left2 + Vector2(-6, 22), z_seat, Vector2(size.x * 0.36, size.y * 1.22), 15.0, 23.0)
	_arm(_arm_r, grip2 - axis2 * 18.0 - normal2 * 10.0, z_grip, Vector2(size.x * 0.97, size.y * 1.22), 17.0, 27.0)


## A screen point at depth z (metres in front of the camera) as a 3D point.
func _lift(p: Vector2, z: float) -> Vector3:
	var aspect := _size.x / maxf(_size.y, 1.0)
	return Vector3((p.x / _size.x - 0.5) * aspect * WaterView.FOV * z,
			WaterView.CAM_HEIGHT - (p.y / _size.y - WaterView.HORIZON) * WaterView.FOV * z, -z)


## Metres per screen pixel at depth z.
func _mpp(z: float) -> float:
	return z * WaterView.FOV / _size.y


static func _depth(t: float) -> float:
	return lerpf(DEPTH_BUTT, DEPTH_TIP, t)


## Basis of the rod's frame at a point: x along the rod, y along the reel's
## side, z towards the camera, scaled so one unit is one screen pixel.
func _frame(p2: Vector2, axis2: Vector2, normal2: Vector2, z: float) -> Basis:
	var o := _lift(p2, z)
	var a := (_lift(p2 + axis2 * 20.0, z + 0.02) - o).normalized()
	var n := _lift(p2 + normal2 * 20.0, z) - o
	n = (n - a * n.dot(a)).normalized()
	return Basis(a, n, a.cross(n)) * _mpp(z)


func _arm(mi: MeshInstance3D, wrist2: Vector2, z_wrist: float, elbow2: Vector2, r_wrist: float, r_elbow: float) -> void:
	var w := _lift(wrist2, z_wrist)
	var e := _lift(elbow2, 0.5)
	_centres.resize(4)
	_radii.resize(4)
	var d := (e - w).normalized()
	# A cuff, then the sleeve widening to the elbow.
	_centres[0] = w - d * 0.012
	_radii[0] = r_wrist * 1.12 * _mpp(z_wrist)
	_centres[1] = w + d * 0.02
	_radii[1] = r_wrist * 1.12 * _mpp(z_wrist)
	_centres[2] = w + d * 0.021
	_radii[2] = r_wrist * _mpp(z_wrist)
	_centres[3] = e
	_radii[3] = r_elbow * _mpp(0.5)
	_set_tube(mi)


func _tube_along(mi: MeshInstance3D, rig: AnglerRig, t0: float, t1: float, r0_px: float, r1_px: float, rings: int) -> void:
	_centres.resize(rings)
	_radii.resize(rings)
	for i in rings:
		var u := float(i) / float(rings - 1)
		var t := lerpf(t0, t1, u)
		var z := _depth(t)
		_centres[i] = _lift(rig.at(t), z)
		_radii[i] = lerpf(r0_px, r1_px, pow(u, 0.8)) * _mpp(z)
	_set_tube(mi)


## Builds a tube through _centres with _radii into mi's mesh.
func _set_tube(mi: MeshInstance3D) -> void:
	var n := _centres.size()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	verts.resize(n * SIDES + 2)
	normals.resize(n * SIDES + 2)
	var eye := Vector3(0.0, WaterView.CAM_HEIGHT, 0.0)
	for i in n:
		var c := _centres[i]
		var tangent := (_centres[mini(i + 1, n - 1)] - _centres[maxi(i - 1, 0)]).normalized()
		var x := tangent.cross((eye - c).normalized()).normalized()
		var y := x.cross(tangent)
		for k in SIDES:
			var a := TAU * k / SIDES
			var dir := x * cos(a) + y * sin(a)
			verts[i * SIDES + k] = c + dir * _radii[i]
			normals[i * SIDES + k] = dir
	for i in n - 1:
		for k in SIDES:
			var a := i * SIDES + k
			var b := i * SIDES + (k + 1) % SIDES
			indices.append_array(PackedInt32Array([a, b, a + SIDES, b, b + SIDES, a + SIDES]))
	# End caps.
	for cap in 2:
		var ring := 0 if cap == 0 else n - 1
		var centre_i := n * SIDES + cap
		verts[centre_i] = _centres[ring]
		normals[centre_i] = (_centres[ring] - _centres[1 if cap == 0 else n - 2]).normalized()
		for k in SIDES:
			var a := ring * SIDES + k
			var b := ring * SIDES + (k + 1) % SIDES
			indices.append_array(PackedInt32Array([centre_i, b, a] if cap == 0 else [centre_i, a, b]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := mi.mesh as ArrayMesh
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


# ------------------------------------------------------------------ building

func _build_reel(metal: StandardMaterial3D, dark: StandardMaterial3D) -> void:
	_reel = Node3D.new()
	add_child(_reel)
	var line_mat := _mat(Color(0.86, 0.88, 0.92), 0.0, 0.6)
	_part(_reel, _box(Vector3(7, 18, 6)), metal).position = Vector3(0, -27, 0)
	_part(_reel, _cyl(19.0, 14.0), metal).rotation.x = PI * 0.5
	var cap := _part(_reel, _cyl(11.0, 17.0), _mat(Color(0.42, 0.44, 0.48), 0.85, 0.28))
	cap.rotation.x = PI * 0.5
	# Spool on the rod's axis: skirt, the band of line, a marker that turns, the drag knob.
	var skirt := _part(_reel, _cyl(15.0, 22.0), dark)
	skirt.rotation.z = PI * 0.5
	skirt.position = Vector3(24, 0, 0)
	var band := _part(_reel, _cyl(15.8, 13.0), line_mat)
	band.rotation.z = PI * 0.5
	band.position = Vector3(25, 0, 0)
	_spool_spin = Node3D.new()
	_spool_spin.position = Vector3(34, 0, 0)
	_reel.add_child(_spool_spin)
	_part(_spool_spin, _box(Vector3(3, 5, 3)), metal).position = Vector3(0, 13, 0)
	var drag := _part(_reel, _cyl(6.0, 6.0), _mat(Color(0.55, 0.1, 0.08), 0.2, 0.4))
	drag.rotation.z = PI * 0.5
	drag.position = Vector3(38, 0, 0)
	# Rotor: two arms and the bail wire, turning round the spool with the handle.
	_rotor = Node3D.new()
	_rotor.position = Vector3(14, 0, 0)
	_reel.add_child(_rotor)
	for sgn: float in [-1.0, 1.0]:
		_part(_rotor, _box(Vector3(18, 4, 4)), metal).position = Vector3(3, sgn * 17.5, 0)
	var wire := TorusMesh.new()
	wire.inner_radius = 16.6
	wire.outer_radius = 18.2
	wire.rings = 20
	wire.ring_segments = 5
	_bail = _part(_rotor, wire, _mat(Color(0.8, 0.82, 0.86), 0.9, 0.2))
	_bail.rotation.x = PI * 0.5
	_handle_arm = _part(_reel, _cyl(2.4, 1.0), dark)
	var knob := SphereMesh.new()
	knob.radius = 6.5
	knob.height = 13.0
	knob.radial_segments = 12
	knob.rings = 6
	_knob = _part(_reel, knob, dark)


func _holder(mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = ArrayMesh.new()
	mi.material_override = mat
	# The shapes are rebuilt every frame; skip the bounds test.
	mi.custom_aabb = AABB(Vector3(-6, 0, -6), Vector3(12, 6, 12))
	add_child(mi)
	return mi


func _part(parent: Node3D, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


func _cyl(radius: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 16
	m.rings = 1
	return m


func _blob(parent: Node3D, at: Vector3, radii: Vector3, mat: Material) -> void:
	var m := SphereMesh.new()
	m.radius = 1.0
	m.height = 2.0
	m.radial_segments = 14
	m.rings = 8
	var mi := _part(parent, m, mat)
	mi.position = at
	mi.scale = radii


func _capsule(parent: Node3D, from: Vector3, to: Vector3, radius: float, mat: Material) -> void:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = from.distance_to(to) + radius * 2.0
	m.radial_segments = 10
	m.rings = 4
	_stretch(_part(parent, m, mat), from, to, false)


## Puts a mesh's Y axis between two points; scale_len stretches a unit height.
func _stretch(mi: MeshInstance3D, from: Vector3, to: Vector3, scale_len: bool = true) -> void:
	var d := to - from
	var len := maxf(d.length(), 0.001)
	var b := _basis_y(d / len)
	if scale_len:
		b.y *= len
	mi.transform = Transform3D(b, (from + to) * 0.5)


## An orthonormal basis whose Y axis is y.
static func _basis_y(y: Vector3) -> Basis:
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))


func _mat(colour: Color, metallic: float, roughness: float, tile: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.metallic = metallic
	mat.roughness = roughness
	if tile > 0.0:
		mat.normal_enabled = true
		mat.normal_texture = SeaMaps.grain_normal()
		mat.normal_scale = 0.6
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3.ONE * tile
	return mat
