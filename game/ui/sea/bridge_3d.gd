class_name Bridge3D
extends Stage3D
## The Galata Bridge deck (owner, 2026-11-16): paving, a steel rail with a
## round handrail and two bars, posts every 1.5 m and lamp standards with
## lit lamps at dusk and night. While getting ready the angler looks along
## the rail (WaterView.BRIDGE_YAW), so the rail and the row of anglers recede
## towards the far shore, as in any photo of the bridge.

const RAIL_Z := 0.844                       ## the rail runs along x, this far out from the angler
const RAIL_H := 1.05
const LENGTH := 150.0


func _init() -> void:
	kind = "bridge"
	edge_z = RAIL_Z
	ready_yaw = WaterView.BRIDGE_YAW
	length = LENGTH
	people_at = [3.4, 5.4, 8.2, 11.8]
	stand_back = 0.34
	lamp_first = 7.0
	lamp_step = 20.0
	lamp_height = 5.2
	build()


func _build_surface() -> void:
	var paving := pbr_material("concrete_pavement", Color(0.82, 0.8, 0.78), 3.0)
	var back := -6.0
	_box(Vector3(LENGTH, 0.6, 14.3), Vector3(LENGTH * 0.5 + back, -0.3, -6.9), paving)
	_box(Vector3(LENGTH, 0.16, 0.32), Vector3(LENGTH * 0.5 + back, 0.08, 0.02), pbr_material("concrete_pavement", Color(1.0, 0.98, 0.95), 2.0))
	# Rails: a round handrail and two thinner bars.
	for bar: Array in [[RAIL_H, 0.036], [0.72, 0.016], [0.4, 0.016]]:
		var m := CylinderMesh.new()
		m.top_radius = bar[1]
		m.bottom_radius = bar[1]
		m.height = LENGTH
		m.radial_segments = 10
		m.rings = 1
		var mi := _mesh(m, _steel)
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
	posts.material_override = _steel
	add_child(posts)
