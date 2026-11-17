class_name Quay3D
extends Stage3D
## A stone quay (roadmap R5, the second stage): a cobbled apron, a stone
## coping at the edge with no rail, iron bollards every few metres, a wet
## stone wall going down into the water and low lamp standards, with CC0
## textures from Poly Haven (cobblestone_floor_04, rough_concrete,
## stone_wall_04, rusty_metal_02). The
## neighbours stand right at the edge. The look along the quay is gentler
## than along a bridge. Generic: no real quay is modelled yet (the first
## position that uses it needs sourced data, roadmap R14).

const EDGE_Z := 0.9
const LENGTH := 90.0


func _init() -> void:
	kind = "quay"
	edge_z = EDGE_Z
	ready_yaw = 0.72
	length = LENGTH
	people_at = [2.8, 5.0, 8.0, 12.5]
	stand_back = 0.12
	lamp_first = 9.0
	lamp_step = 18.0
	lamp_height = 4.2
	build()


func _build_surface() -> void:
	var cobbles := pbr_material("cobblestone_floor_04", Color(0.85, 0.83, 0.8), 1.5)
	var stone := pbr_material("rough_concrete", Color(0.95, 0.93, 0.9), 2.0)
	var wet := pbr_material("stone_wall_04", Color(0.4, 0.45, 0.5), 1.5)
	var iron := pbr_material("rusty_metal_02", Color(0.7, 0.7, 0.72), 0.8, 0.25)
	var back := -6.0
	# The apron, the coping and the wall below the waterline.
	_box(Vector3(LENGTH, 0.6, 16.0), Vector3(LENGTH * 0.5 + back, -0.3, -8.0), cobbles)
	_box(Vector3(LENGTH, 0.22, 0.7), Vector3(LENGTH * 0.5 + back, 0.11, 0.2), stone)
	_box(Vector3(LENGTH, 3.2, 0.5), Vector3(LENGTH * 0.5 + back, -2.2, 0.35), wet)
	# Bollards every 8 m, with a cap.
	var x := 3.0
	while x < LENGTH - 6.0:
		var body := CylinderMesh.new()
		body.top_radius = 0.14
		body.bottom_radius = 0.2
		body.height = 0.5
		body.radial_segments = 12
		_mesh(body, iron).position = Vector3(x, 0.35, -0.55)
		var cap := SphereMesh.new()
		cap.radius = 0.19
		cap.height = 0.2
		cap.radial_segments = 12
		cap.rings = 4
		_mesh(cap, iron).position = Vector3(x, 0.62, -0.55)
		x += 8.0
