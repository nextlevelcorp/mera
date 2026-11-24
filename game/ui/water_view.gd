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
const GULL_SHADER := preload("res://ui/sea/gull.gdshader")
const MAX_RINGS := 12
const MAX_SHADOWS := 8
## The sun's shadow map is 1024 square: the shadows cover 40 m, and the
## engine's default of 4096 is a large depth texture to fill on a phone.
const SHADOW_ATLAS := 1024
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

## The view's turn to the left of straight out over the water, in radians.
## The world is square to the rail (z out over the water); the angler looks
## along the bridge while getting ready (BRIDGE_YAW) and turns to the water
## to cast and fish (0). project() and the 3D camera share it.
const BRIDGE_YAW := 0.9856
## The sun and moon stand this far to the left of straight out, so they are in
## view both along the bridge and facing the water.
const SUN_YAW := 0.49
static var view_yaw := 0.0

var detail := true
## Quality switches the debug menu flips to find what costs frame time on a
## phone (owner measurement 2026-11-17: worst 1% fell from 47 to 34 fps).
var shadows := true
var glow := true
var lamp_lights := true
var camera: Camera3D
var stage: Stage3D
var rig3d: Rig3D
var _sea: ShaderMaterial
var _sky: ShaderMaterial
var _env: Environment
var _sun: DirectionalLight3D
var _root: Node3D
var gulls_mm: MultiMeshInstance3D
var fish_world: Fish3D
var fish_hand: Fish3D
var _light := 1.0


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
	_root = root
	var gull_mm := MultiMesh.new()
	gull_mm.transform_format = MultiMesh.TRANSFORM_3D
	gull_mm.use_custom_data = true
	gull_mm.mesh = GullFlock.gull_mesh()
	gulls_mm = MultiMeshInstance3D.new()
	gulls_mm.multimesh = gull_mm
	var gull_mat := ShaderMaterial.new()
	gull_mat.shader = GULL_SHADER
	gulls_mm.material_override = gull_mat
	gulls_mm.custom_aabb = AABB(Vector3(-200, -5, -300), Vector3(400, 60, 300))
	gulls_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(gulls_mm)
	fish_world = Fish3D.new()
	root.add_child(fish_world)
	rig3d = Rig3D.new()
	camera.add_child(rig3d)
	fish_hand = Fish3D.new()
	camera.add_child(fish_hand)
	RenderingServer.directional_shadow_atlas_set_size(SHADOW_ATLAS, false)
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
	var sun_dir := (sun[0] as Vector3).normalized().rotated(Vector3.UP, SUN_YAW)
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
	_light = light
	_apply_quality()
	if sun_dir.y > 0.0:
		_sun.look_at_from_position(Vector3.ZERO, -sun_dir, Vector3.UP if absf(sun_dir.x) + absf(sun_dir.z) > 0.01 else Vector3.FORWARD)


## Puts the standing place of a kind (Stage3D.KINDS) in the scene; "" or an
## unknown kind leaves only the sea.
func set_stage(kind: String) -> void:
	if stage != null and stage.kind == kind:
		return
	if stage != null:
		stage.queue_free()
		stage = null
	stage = Stage3D.make(kind)
	if stage != null:
		_root.add_child(stage)
		stage.lights_enabled = lamp_lights
		stage.set_light(_light)


## The place's own skyline (Horizon) for a position facing a compass
## direction; an empty profile keeps the generic ridge.
func set_horizon(prof: Dictionary, facing: String) -> void:
	var on := not prof.is_empty()
	var tex: ImageTexture = ImageTexture.create_from_image(Horizon.image(prof)) if on else null
	for m: ShaderMaterial in [_sky, _sea]:
		m.set_shader_parameter("horizon_on", 1.0 if on else 0.0)
		m.set_shader_parameter("horizon_bearing", Horizon.bearing(facing))
		m.set_shader_parameter("horizon_tex", tex)


## Rings and boils on the surface, from SplashFx.rings (world: x right, z out).
## At most MAX_RINGS, the strongest first when there are more.
func set_rings(rings: Array[Dictionary], extra: Array[Vector4] = []) -> void:
	_sea.set_shader_parameter("ring_count", 0)
	var packed := pack_rings(rings, extra)
	_sea.set_shader_parameter("rings", packed)
	_sea.set_shader_parameter("ring_count", packed.size())


## The shader's ring array (x, z in the sea's own coordinates where z runs
## away as a negative number; radius; strength). Extra rings come first.
static func pack_rings(rings: Array[Dictionary], extra: Array[Vector4] = []) -> PackedVector4Array:
	var live: Array[Vector4] = []
	live.append_array(extra)
	for r: Dictionary in rings:
		var world: Vector2 = r["world"]
		var strength := SplashFx.ring_alpha(r)
		if strength > 0.02:
			live.append(Vector4(world.x, -world.y, SplashFx.ring_radius(r), strength))
	live.sort_custom(func(a: Vector4, b: Vector4) -> bool: return a.w > b.w)
	var out := PackedVector4Array()
	for v: Vector4 in live.slice(0, MAX_RINGS):
		out.append(v)
	return out


## A fish under the surface as soft dark blobs along its spine (water
## metres, head first); strength 0..1 hides it with distance and clarity.
## An empty spine clears the shadow.
func set_fish_shadow(spine: PackedVector2Array, radius_m: float, strength: float) -> void:
	var out := PackedVector4Array()
	if spine.size() >= 2 and strength > 0.01:
		var step := float(spine.size() - 1) / float(MAX_SHADOWS - 1)
		for i in MAX_SHADOWS:
			var p: Vector2 = spine[mini(int(roundf(step * i)), spine.size() - 1)]
			var s := float(i) / float(MAX_SHADOWS - 1)
			out.append(Vector4(p.x, -p.y, maxf(radius_m * (0.6 + 0.8 * sin(PI * clampf(s * 0.9 + 0.05, 0.0, 1.0))), 0.06), strength))
	_sea.set_shader_parameter("shadow_count", 0)
	_sea.set_shader_parameter("fish_shadow", out if not out.is_empty() else PackedVector4Array([Vector4()]))
	_sea.set_shader_parameter("shadow_count", out.size())


func set_view_yaw(yaw: float) -> void:
	view_yaw = yaw
	camera.rotation.y = yaw


func set_shadows(on: bool) -> void:
	shadows = on
	_apply_quality()


func set_glow(on: bool) -> void:
	glow = on
	_apply_quality()


func set_lamp_lights(on: bool) -> void:
	lamp_lights = on
	_apply_quality()


## Shadows only when the sun is up enough to show them: at night the moon's
## shadows are invisible and not worth a pass.
func _apply_quality() -> void:
	_env.glow_enabled = glow
	_sun.shadow_enabled = shadows and _light > 0.3
	if stage:
		stage.lights_enabled = lamp_lights
		stage.set_light(_light)


## Debug menu: switch the extra water detail off and on to measure its cost.
func set_detail(on: bool) -> void:
	detail = on
	_sea.set_shader_parameter("detail", 1.0 if on else 0.0)


func shader_parameter(name_id: String) -> Variant:
	return _sea.get_shader_parameter(name_id)


## Screen position of a point on the water (x metres to the right, z metres
## away), at height h above the surface. Same camera as the shader.
static func project(world: Vector2, h: float, view_size: Vector2) -> Vector2:
	var aspect := view_size.x / maxf(view_size.y, 1.0)
	var c := cos(view_yaw)
	var sn := sin(view_yaw)
	var x := world.x * c + world.y * sn
	var z := maxf(world.y * c - world.x * sn, 0.5)
	var u := 0.5 + x / (z * aspect * FOV)
	var v := HORIZON + (CAM_HEIGHT - h) / (z * FOV)
	return Vector2(u * view_size.x, v * view_size.y)


## Distance of a water point in front of the view (negative: behind it).
static func view_depth(world: Vector2) -> float:
	return world.y * cos(view_yaw) - world.x * sin(view_yaw)
