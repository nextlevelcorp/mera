class_name Fish3D
extends Node3D
## A fish as a lit 3D body (roadmap R6): a tube along a spine of points with a
## laterally compressed cross-section, a silvery belly and a dark back from
## vertex colours, a forked tail fin and an eye. Used for what is above the
## water: a jump (world space) and the landing and lift on the line (camera
## space, like Rig3D). A fish under the water is not a mesh: the sea shader
## draws it as a shadow (sea.gdshader, fish_shadow). Visual only.

const SIDES := 10
const BACK := Color(0.14, 0.24, 0.31)
const BELLY := Color(0.86, 0.89, 0.92)
const FIN := Color(0.2, 0.27, 0.32)

var _mi: MeshInstance3D
var _eye: MeshInstance3D
var _mesh := ArrayMesh.new()


func _init() -> void:
	_mi = MeshInstance3D.new()
	_mi.mesh = _mesh
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.28
	mat.metallic = 0.35
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mi.material_override = mat
	_mi.custom_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mi)
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 8
	ball.rings = 4
	_eye = MeshInstance3D.new()
	_eye.mesh = ball
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.03, 0.03, 0.04)
	dark.roughness = 0.2
	_eye.material_override = dark
	_eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_eye)
	visible = false


## Shows the fish along spine (head first, any number of points above 2).
## back: the direction of its back (it is flattened across this axis'
## perpendicular); length_m: the fish's length, which sets its thickness.
func show_along(spine: PackedVector3Array, back: Vector3, length_m: float) -> void:
	if spine.size() < 3:
		visible = false
		return
	visible = true
	var n := spine.size()
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var rings := n
	verts.resize(rings * SIDES)
	colors.resize(rings * SIDES)
	var last_a := back
	for i in n:
		var s := float(i) / float(n - 1)
		var t := (spine[mini(i + 1, n - 1)] - spine[maxi(i - 1, 0)]).normalized()
		var a := (back - t * back.dot(t)).normalized()
		if a.length() < 0.5:
			a = last_a
		last_a = a
		var b := t.cross(a).normalized()
		var h := FishBody.half_width(s) * length_m
		var ra := h
		var rb := h * 0.55
		for k in SIDES:
			var ang := TAU * k / SIDES
			var up := cos(ang)         # +1 on the back, -1 on the belly
			verts[i * SIDES + k] = spine[i] + a * up * ra + b * sin(ang) * rb
			colors[i * SIDES + k] = BELLY.lerp(BACK, smoothstep(-0.25, 0.55, up))
	for i in n - 1:
		for k in SIDES:
			var p := i * SIDES + k
			var q := i * SIDES + (k + 1) % SIDES
			indices.append_array(PackedInt32Array([p, q, p + SIDES, q, q + SIDES, p + SIDES]))
	# Close the snout.
	var snout := verts.size()
	verts.append(spine[0] - (spine[1] - spine[0]).normalized() * length_m * 0.02)
	colors.append(BACK)
	for k in SIDES:
		indices.append_array(PackedInt32Array([snout, (k + 1) % SIDES, k]))
	# The forked tail: two triangles past the last ring.
	var tail := spine[n - 1]
	var tt := (spine[n - 1] - spine[n - 2]).normalized()
	var ta := (back - tt * back.dot(tt)).normalized()
	var fin := length_m * 0.17
	var v0 := verts.size()
	verts.append(tail)
	verts.append(tail + tt * fin * 0.55)
	verts.append(tail + tt * fin + ta * fin * 0.8)
	verts.append(tail + tt * fin - ta * fin * 0.8)
	for _i in 4:
		colors.append(FIN)
	indices.append_array(PackedInt32Array([v0, v0 + 2, v0 + 1, v0, v0 + 1, v0 + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	_mesh.clear_surfaces()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# The eye, a little behind the snout and towards the viewer's side.
	var head_t := (spine[1] - spine[0]).normalized()
	var head_a := (back - head_t * back.dot(head_t)).normalized()
	var head_b := head_t.cross(head_a).normalized()
	var h0 := FishBody.half_width(0.12) * length_m
	_eye.position = spine[0] + head_t * length_m * 0.07 + head_a * h0 * 0.25 + head_b * h0 * 0.5
	_eye.scale = Vector3.ONE * maxf(length_m * 0.018, 0.004)
	_eye.visible = true


func hide_fish() -> void:
	visible = false
