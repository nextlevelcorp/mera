class_name Beach3D
extends Stage3D
## A beach (owner, 2026-11-24: "at least one place should be a beach, not a
## breakwater"): sand sloping gently into the sea, a darker wet band where the
## wash reaches, and the wash itself, a line of foam that runs up the sand and
## slides back. No rail and no lamps; the neighbours stand well apart along
## the water. Sand is the CC0 coast_sand_01 texture from Poly Haven. Generic:
## the slope and the wash are design fills, not a survey of a real beach.

const EDGE_Z := 0.6
const LENGTH := 120.0
const SLOPE := 0.12          ## rise of the sand per metre
const WASH_S := 7.0          ## seconds for the wash to run up and back
const WASH_RUN := 1.1        ## how far up the sand the wash runs (m)

var _wash: MeshInstance3D
var _foam: StandardMaterial3D
var _t := 0.0


func _init() -> void:
	kind = "beach"
	edge_z = EDGE_Z
	ready_yaw = 0.6
	length = LENGTH
	people_at = [4.5, 10.0, 17.0, 26.0]
	stand_back = 0.4
	lamp_first = 1000.0   # no lamps on a beach
	build()


## Local depth of the water line in front of the angler (z out from the edge).
func waterline_z() -> float:
	return DECK_Y / SLOPE


func _build_surface() -> void:
	var sand := pbr_material("coast_sand_01", Color(0.95, 0.9, 0.82), 2.0)
	var wet := pbr_material("coast_sand_01", Color(0.55, 0.5, 0.44), 2.0)
	var tilt := atan(SLOPE)
	# The slope: one slab through the edge, ending just past the water line
	# (further out, sand seen under the sea surface flickers on a phone).
	var back := -20.0
	var front := waterline_z() + 1.5
	var slab := _box(Vector3(LENGTH, 0.2, front - back), Vector3(LENGTH * 0.5 - 20.0, 0.0, (front + back) * 0.5), sand)
	slab.rotation.x = tilt
	slab.position.y = -SLOPE * slab.position.z - 0.1
	var band := _box(Vector3(LENGTH, 0.2, 3.0), Vector3(LENGTH * 0.5 - 20.0, -0.1 + 0.012, waterline_z() - 1.6), wet)
	band.rotation.x = tilt
	band.position.y = -SLOPE * band.position.z - 0.1 + 0.012
	_foam = StandardMaterial3D.new()
	_foam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_foam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_foam.albedo_color = Color(0.96, 0.98, 1.0, 0.7)
	_wash = _box(Vector3(LENGTH, 0.01, 0.5), Vector3(LENGTH * 0.5 - 20.0, 0.0, waterline_z()), _foam)
	_wash.rotation.x = tilt
	_place_wash()


## The neighbours stand on the slope, a little higher the further back.
func arrange(spots: Array[Dictionary]) -> void:
	super.arrange(spots)
	for p: Node3D in _people:
		p.position.y = -SLOPE * p.position.z


func _process(delta: float) -> void:
	_t += delta
	_place_wash()


## The wash runs up the sand and slides back.
func _place_wash() -> void:
	var k := 0.5 - 0.5 * cos(TAU * _t / WASH_S)
	var z := waterline_z() - WASH_RUN * k
	_wash.position = Vector3(_wash.position.x, -SLOPE * z + 0.02, z)
	_wash.scale = Vector3(1.0, 1.0, 0.6 + 1.6 * (1.0 - k))
	_foam.albedo_color.a = 0.45 + 0.3 * k
