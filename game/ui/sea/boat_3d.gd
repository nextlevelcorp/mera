class_name Boat3D
extends Stage3D
## A small rented boat (roadmap R23): the angler sits in a wooden open boat
## and looks over its gunwale; no neighbours, no lamps. The hull heaves and
## rolls a little on the swell (sway, set by the fishing screen each frame;
## the camera itself stays still so the 2D projection keeps matching). Built
## from boxes in code with the same CC0 textures as the quay. Generic: no
## real boat is modelled.

const EDGE_Z := 0.75
const HULL_LEN := 8.0

var _hull: Node3D


func _init() -> void:
	kind = "boat"
	edge_z = EDGE_Z
	ready_yaw = 0.35
	length = HULL_LEN
	people_at = []
	lamp_first = 1000.0   # no lamps on a boat
	build()


func _build_surface() -> void:
	var wood := pbr_material("rough_concrete", Color(0.55, 0.38, 0.24), 1.0)
	var paint := pbr_material("rough_concrete", Color(0.22, 0.36, 0.5), 1.0)
	_hull = Node3D.new()
	add_child(_hull)
	# The angler sits at the stern and looks over the bow: two gunwales run
	# forward (+Z) and meet at the stem, far enough ahead to be in view.
	var stem := Vector3(0.0, 0.35, 4.2)
	for side: float in [-1.0, 1.0]:
		var aft := Vector3(side * 0.95, 0.3, -0.6)
		_hull.add_child(_beam(aft, stem, 0.12, wood))                      # the gunwale
		_hull.add_child(_beam(aft + Vector3(0, -0.45, 0), stem + Vector3(0, -0.55, 0), 0.32, paint))   # the topside
	_hull.add_child(_part(Vector3(1.6, 0.06, 3.6), Vector3(0.0, -0.3, 1.2), wood))   # floorboards
	_hull.add_child(_part(Vector3(1.8, 0.07, 0.28), Vector3(0.0, 0.0, 1.6), wood))   # a thwart
	_hull.add_child(_beam(stem, stem + Vector3(0.0, 0.25, 0.25), 0.08, wood))       # the stem head


## A box from a to b, thick t, for a hull's long parts.
func _beam(a: Vector3, b: Vector3, t: float, mat: Material) -> MeshInstance3D:
	var mi := _part(Vector3(t, t, a.distance_to(b)), (a + b) * 0.5, mat)
	mi.look_at_from_position(mi.position, b, Vector3.UP)
	return mi


func _part(size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := _box(size, at, mat)
	remove_child(mi)
	return mi


## The swell under the hull: t in seconds, swell 0..1 (from the sea's chop).
func sway(t: float, swell: float) -> void:
	if _hull == null:
		return
	var a := 0.02 + 0.05 * swell
	_hull.rotation = Vector3(sin(t * 0.9) * a, 0.0, sin(t * 0.7 + 1.3) * a * 0.6)
	_hull.position.y = sin(t * 1.1) * 0.06 * (0.5 + swell)
