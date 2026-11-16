class_name WaterView
extends Control
## The sea and sky in 3D (owner, 2026-11-15: option A, photorealistic in
## Godot): a Gerstner-wave sea mesh (ui/sea/sea.gdshader), a static sky
## (ui/sea/sky.gdshader), HDR tonemapping and glow, and a camera that
## reproduces project() exactly, so the 2D overlay (rod, line, rail, rings)
## stays in place on the water. Driven by the simulation's chop, visibility
## and light. The water prototype keeps the old 2D shader.

const SEA_SHADER := preload("res://ui/sea/sea.gdshader")
const SKY_SHADER := preload("res://ui/sea/sky.gdshader")
const CAM_NEAR := 0.05
const HORIZON := 0.38
const CAM_HEIGHT := 2.2
const FOV := 0.9
const PALETTES := {
	"dawn": [Color(0.25, 0.32, 0.5), Color(0.95, 0.65, 0.5), Color(0.07, 0.16, 0.25), Color(0.16, 0.33, 0.4)],
	"day": [Color(0.25, 0.5, 0.85), Color(0.7, 0.85, 0.95), Color(0.02, 0.12, 0.2), Color(0.05, 0.26, 0.33)],
	"evening": [Color(0.2, 0.2, 0.42), Color(0.98, 0.55, 0.3), Color(0.06, 0.12, 0.22), Color(0.2, 0.28, 0.35)],
	"night": [Color(0.02, 0.03, 0.08), Color(0.08, 0.1, 0.18), Color(0.01, 0.03, 0.06), Color(0.03, 0.07, 0.1)],
}
## Sun (moon at night) direction in world space (x right, y up, -z away),
## colour, and how bright its disc and glitter are.
const SUNS := {
	"dawn": [Vector3(0.3, 0.12, -1.0), Color(1.0, 0.72, 0.5), 1.0],
	"day": [Vector3(0.2, 0.75, -0.6), Color(1.0, 0.96, 0.88), 1.0],
	"evening": [Vector3(-0.25, 0.10, -1.0), Color(1.0, 0.55, 0.3), 1.0],
	"night": [Vector3(0.15, 0.45, -0.9), Color(0.35, 0.4, 0.55), 0.035],
}
## Tonemap exposure per slot (design fill, tuned by eye on screenshots).
const EXPOSURE := {"dawn": 1.0, "day": 0.95, "evening": 1.0, "night": 1.2}

## Far-shore lights by time of slot (generic city lights, design fill).
const CITY_LIGHTS := {"dawn": 0.3, "day": 0.0, "evening": 0.35, "night": 1.0}

var detail := true
var camera: Camera3D
var bridge: Bridge3D
var rig3d: Rig3D
var _sea: ShaderMaterial
var _sky: ShaderMaterial
var _env: Environment
var _sun: DirectionalLight3D


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var root := Node3D.new()
	root.name = "Sea3D"
	add_child(root)
	_sky = ShaderMaterial.new()
	_sky.shader = SKY_SHADER
	_sea = ShaderMaterial.new()
	_sea.shader = SEA_SHADER
	for m: ShaderMaterial in [_sky, _sea]:
		m.set_shader_parameter("cloud_tex", SeaMaps.cloud())
	_sea.set_shader_parameter("ripple_tex", SeaMaps.ripple())
	var sky := Sky.new()
	sky.sky_material = _sky
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.tonemap_white = 6.0
	_env.glow_enabled = true
	_env.glow_intensity = 0.7
	_env.glow_bloom = 0.0
	_env.glow_hdr_threshold = 1.2
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	root.add_child(world_env)
	_sun = DirectionalLight3D.new()
	root.add_child(_sun)
	var mesh := MeshInstance3D.new()
	mesh.mesh = SeaMaps.build_grid()
	mesh.material_override = _sea
	mesh.extra_cull_margin = 16.0
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mesh)
	camera = make_camera()
	root.add_child(camera)
	bridge = Bridge3D.new()
	root.add_child(bridge)
	rig3d = Rig3D.new()
	root.add_child(rig3d)
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_sun.directional_shadow_max_distance = 40.0


## A camera that sees exactly what project() computes: at CAM_HEIGHT, looking
## level along -z, with the frustum shifted so the horizon sits at HORIZON.
static func make_camera() -> Camera3D:
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, CAM_HEIGHT, 0.0)
	cam.near = CAM_NEAR
	cam.far = 9000.0
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.set_frustum(CAM_NEAR * FOV, Vector2(0.0, -(0.5 - HORIZON) * CAM_NEAR * FOV), CAM_NEAR, 9000.0)
	cam.current = true
	return cam


func set_conditions(slot: String, chop: float, visibility: float, light: float) -> void:
	var palette: Array = PALETTES[slot]
	var sun: Array = SUNS[slot]
	var sun_dir := (sun[0] as Vector3).normalized()
	for m: ShaderMaterial in [_sky, _sea]:
		m.set_shader_parameter("sky_top", palette[0])
		m.set_shader_parameter("sky_horizon", palette[1])
		m.set_shader_parameter("sun_dir", sun_dir)
		m.set_shader_parameter("sun_color", sun[1])
		m.set_shader_parameter("sun_power", sun[2])
		m.set_shader_parameter("cloud_cover", 0.25 + 0.45 * chop)
		m.set_shader_parameter("light", light)
		m.set_shader_parameter("city_lights", CITY_LIGHTS[slot])
	_sea.set_shader_parameter("chop", chop)
	_sea.set_shader_parameter("visibility", visibility)
	_sea.set_shader_parameter("water_deep", palette[2])
	_sea.set_shader_parameter("water_shallow", palette[3])
	_sea.set_shader_parameter("detail", 1.0 if detail else 0.0)
	_env.tonemap_exposure = EXPOSURE[slot]
	_sun.light_color = sun[1]
	_sun.light_energy = (0.25 + 1.6 * light) * (0.25 if slot == "night" else 1.0)
	bridge.set_light(light)
	if sun_dir.y > 0.0:
		_sun.look_at_from_position(Vector3.ZERO, -sun_dir, Vector3.UP if absf(sun_dir.x) + absf(sun_dir.z) > 0.01 else Vector3.FORWARD)


## Debug menu: switch the extra water detail off and on to measure its cost.
func set_detail(on: bool) -> void:
	detail = on
	_sea.set_shader_parameter("detail", 1.0 if on else 0.0)
	_env.glow_enabled = on


func shader_parameter(name_id: String) -> Variant:
	return _sea.get_shader_parameter(name_id)


## Screen position of a point on the water (x metres to the right, z metres
## away), at height h above the surface. Same camera as the shader.
static func project(world: Vector2, h: float, view_size: Vector2) -> Vector2:
	var aspect := view_size.x / maxf(view_size.y, 1.0)
	var z := maxf(world.y, 0.5)
	var u := 0.5 + world.x / (z * aspect * FOV)
	var v := HORIZON + (CAM_HEIGHT - h) / (z * FOV)
	return Vector2(u * view_size.x, v * view_size.y)
