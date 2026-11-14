class_name WaterView
extends Control
## The realistic water (water_realistic.gdshader) as a reusable full-rect
## control, driven by the simulation's chop, visibility and light, plus the
## camera used to place things on it. The water prototype keeps its own copy
## (to be merged later).

const SHADER := preload("res://scenes/water_prototype/water_realistic.gdshader")
const HORIZON := 0.38
const CAM_HEIGHT := 2.2
const FOV := 0.9
const PALETTES := {
	"dawn": [Color(0.25, 0.32, 0.5), Color(0.95, 0.65, 0.5), Color(0.07, 0.16, 0.25), Color(0.16, 0.33, 0.4)],
	"day": [Color(0.25, 0.5, 0.85), Color(0.7, 0.85, 0.95), Color(0.03, 0.2, 0.35), Color(0.1, 0.45, 0.55)],
	"evening": [Color(0.2, 0.2, 0.42), Color(0.98, 0.55, 0.3), Color(0.06, 0.12, 0.22), Color(0.2, 0.28, 0.35)],
	"night": [Color(0.02, 0.03, 0.08), Color(0.08, 0.1, 0.18), Color(0.01, 0.03, 0.06), Color(0.03, 0.07, 0.1)],
}
const SUNS := {
	"dawn": [Vector3(0.3, 0.12, 1.0), Color(1.0, 0.72, 0.5)],
	"day": [Vector3(0.2, 0.75, 0.6), Color(1.0, 0.96, 0.88)],
	"evening": [Vector3(-0.25, 0.10, 1.0), Color(1.0, 0.55, 0.3)],
	"night": [Vector3(0.15, 0.45, 0.9), Color(0.35, 0.4, 0.55)],
}

var _material: ShaderMaterial


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("horizon", HORIZON)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = _material
	add_child(rect)
	resized.connect(_update_aspect)


func set_conditions(slot: String, chop: float, visibility: float, light: float) -> void:
	var palette: Array = PALETTES[slot]
	var sun: Array = SUNS[slot]
	_material.set_shader_parameter("chop", chop)
	_material.set_shader_parameter("cloud_cover", 0.25 + 0.45 * chop)
	_material.set_shader_parameter("visibility", visibility)
	_material.set_shader_parameter("light", light)
	_material.set_shader_parameter("sky_top", palette[0])
	_material.set_shader_parameter("sky_horizon", palette[1])
	_material.set_shader_parameter("water_deep", palette[2])
	_material.set_shader_parameter("water_shallow", palette[3])
	_material.set_shader_parameter("sun_dir", (sun[0] as Vector3).normalized())
	_material.set_shader_parameter("sun_color", sun[1])
	_update_aspect()


func _update_aspect() -> void:
	_material.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))


## Screen position of a point on the water (x metres to the right, z metres
## away), at height h above the surface. Same camera as the shader.
static func project(world: Vector2, h: float, view_size: Vector2) -> Vector2:
	var aspect := view_size.x / maxf(view_size.y, 1.0)
	var z := maxf(world.y, 0.5)
	var u := 0.5 + world.x / (z * aspect * FOV)
	var v := HORIZON + (CAM_HEIGHT - h) / (z * FOV)
	return Vector2(u * view_size.x, v * view_size.y)
