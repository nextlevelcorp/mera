extends Control
## Water prototype (docs/design_direction.md section 5). Not the game: a test
## scene with on-screen controls so the water can be judged and its frame rate
## measured on a phone. To be removed or moved behind the debug menu before 0.1.

const WATER_SHADERS := {
	"realistic": preload("res://scenes/water_prototype/water_realistic.gdshader"),
	"basic": preload("res://scenes/water_prototype/water.gdshader"),
}
const MAIN_SCENE := "res://scenes/main.tscn"
const SLOTS: Array[String] = ["dawn", "day", "evening", "night"]
const HORIZON := 0.38
## Same camera as water_realistic.gdshader, so overlay objects sit on its water.
const CAM_HEIGHT := 2.2
const FOV := 0.9
## Top edge of the breakwater the angler stands on, as a share of the height.
const EDGE_LEFT := 0.90
const EDGE_RIGHT := 0.86
const PALETTES := {
	"dawn": [Color(0.25, 0.32, 0.5), Color(0.95, 0.65, 0.5), Color(0.07, 0.16, 0.25), Color(0.16, 0.33, 0.4)],
	"day": [Color(0.25, 0.5, 0.85), Color(0.7, 0.85, 0.95), Color(0.03, 0.2, 0.35), Color(0.1, 0.45, 0.55)],
	"evening": [Color(0.2, 0.2, 0.42), Color(0.98, 0.55, 0.3), Color(0.06, 0.12, 0.22), Color(0.2, 0.28, 0.35)],
	"night": [Color(0.02, 0.03, 0.08), Color(0.08, 0.1, 0.18), Color(0.01, 0.03, 0.06), Color(0.03, 0.07, 0.1)],
}
## Sun or moon per slot: direction (x right, y up, z away from the angler) and colour.
const SUNS := {
	"dawn": [Vector3(0.3, 0.12, 1.0), Color(1.0, 0.72, 0.5)],
	"day": [Vector3(0.2, 0.75, 0.6), Color(1.0, 0.96, 0.88)],
	"evening": [Vector3(-0.25, 0.10, 1.0), Color(1.0, 0.55, 0.3)],
	"night": [Vector3(0.15, 0.45, 0.9), Color(0.35, 0.4, 0.55)],
}

var chop := 0.3
var clarity := 11.0
var slot_index := 1
var low_res := false
var realistic := true

var _k: Dictionary
var _material: ShaderMaterial
var _container: SubViewportContainer
var _overlay: Control
var _stats := FrameStats.new(60.0)
var _fps_label: Label
var _visible_label: Label
var _chop_label: Label
var _clarity_label: Label
var _slot_button: Button
var _res_button: Button
var _style_button: Button
var _since_label_update := 0.0
var _time := 0.0
var _cast_button: Button

# Lure on the water, in metres: x to the right, z away from the angler.
var _lure_world := Vector2(-1.5, 22.0)
var _flight_t := -1.0
var _flight_from := Vector2.ZERO
var _flight_to := Vector2.ZERO
var _next_ring_s := 1.0
var _rope: VerletRope
var _fx := SplashFx.new(11)
var _rng := RandomNumberGenerator.new()
var _rocks: Array[PackedVector2Array] = []
var _wind_noise := FastNoiseLite.new()


func _ready() -> void:
	var errors: Array[String] = []
	_k = DataStore.load_constants(errors)
	_rng.seed = 5
	_wind_noise.seed = 3
	_wind_noise.frequency = 0.15
	_build_rocks()
	_build_water()
	_build_overlay()
	_build_controls()
	add_child(DeviceGuard.new())
	resized.connect(_apply)
	_apply()


## The same environment numbers the simulation uses (data_model.md 5.0).
func environment() -> Dictionary:
	var light: float = float(_k["LIGHT"][SLOTS[slot_index]])
	var clarity_eff: float = clampf(clarity - float(_k["CHOP_CLARITY"]) * chop, 1.0, 20.0)
	var visibility: float = CatchModel.n(clarity_eff) * light
	return {"light": light, "clarity_eff": clarity_eff, "visibility": visibility, "visible_at_m": float(_k["VIS_BASE"]) + float(_k["VIS_RANGE"]) * visibility}


func _process(delta: float) -> void:
	_time += delta
	_stats.add(delta)
	_since_label_update += delta
	if _since_label_update >= 0.5:
		_since_label_update = 0.0
		_fps_label.text = tr("PROTO_FPS") % [int(round(_stats.average_fps())), int(round(_stats.low_1pct_fps())), int(_stats.seconds())]
	_step_motion(minf(delta, 0.1))
	_overlay.queue_redraw()


## Screen position of a point on the water surface (world metres, height h).
func project(world: Vector2, h: float = 0.0) -> Vector2:
	var size := _overlay.size
	var aspect := size.x / maxf(size.y, 1.0)
	var u := 0.5 + world.x / (world.y * aspect * FOV)
	var v := HORIZON + (CAM_HEIGHT - h) / (world.y * FOV)
	return Vector2(u * size.x, v * size.y)


## Wave height at a water point: the three largest waves of the realistic shader.
func wave_height(world: Vector2) -> float:
	var t := Time.get_ticks_msec() / 1000.0
	var amp := 0.05 + 0.30 * chop
	var sharp := 1.0 + 1.5 * chop
	var h := 0.0
	for w in [[Vector2(0.25, 1.0), 0.35, 0.9, 1.0, sharp], [Vector2(-0.5, 1.0), 0.62, 1.2, 0.6, sharp], [Vector2(0.8, 0.6), 1.1, 1.7, 0.35, sharp]]:
		var phase: float = world.dot((w[0] as Vector2).normalized()) * float(w[1]) + t * float(w[2])
		h += amp * float(w[3]) * (pow(maxf(0.5 + 0.5 * sin(phase), 0.0001), float(w[4])) * 2.0 - 1.0)
	return h


func _rod_tip() -> Vector2:
	var size := _overlay.size
	var sway := sin(_time * 1.1) * 3.0 * (0.3 + chop)
	return Vector2(size.x * 0.74 + sway, size.y * 0.30)


func _lure_screen() -> Vector2:
	if _flight_t >= 0.0:
		var t := _flight_t
		return _flight_from.lerp(_flight_to, t) + Vector2(0.0, -_overlay.size.y * 0.22 * sin(t * PI))
	return project(_lure_world, wave_height(_lure_world))


func cast_lure() -> void:
	_flight_from = _rod_tip()
	_lure_world = Vector2(_rng.randf_range(-4.0, 3.0), _rng.randf_range(14.0, 32.0))
	_flight_to = project(_lure_world)
	_flight_t = 0.0
	_rope.set_total_length(_flight_from.distance_to(_flight_to) * 0.6)


func _step_motion(dt: float) -> void:
	var tip := _rod_tip()
	# Advance the flight first, so the line ends exactly where the lure is drawn.
	if _flight_t >= 0.0:
		_flight_t += dt / 0.9
		if _flight_t >= 1.0:
			_flight_t = -1.0
			var landed := _lure_screen()
			_fx.splash(landed, _lure_world, 0.3)
			_rope.set_total_length(tip.distance_to(landed) * 1.06)
			_next_ring_s = 1.5
	else:
		_next_ring_s -= dt
		if _next_ring_s <= 0.0:
			_next_ring_s = _rng.randf_range(1.6, 3.2)
			_fx.add_ring(_lure_world, 0.25, 1.8, 0.45 * (1.0 - 0.7 * chop))
	var lure := _lure_screen()
	if _rope == null:
		_rope = VerletRope.new(tip, lure, 18, 1.06)
	if _flight_t >= 0.0:
		# Line pays out behind the flying lure.
		_rope.set_total_length(maxf(_rope.total_length(), tip.distance_to(lure) * 1.02))
	var wind := (_wind_noise.get_noise_1d(_time) * 2.0) * (20.0 + 140.0 * chop)
	# Small sub-steps keep the chain stable when frames are slow.
	var steps := maxi(1, int(ceil(dt / 0.02)))
	for i in steps:
		_rope.step(dt / steps, tip, lure, Vector2(wind, 260.0))
	_fx.step(dt)


func _build_rocks() -> void:
	# Irregular armour stones along the water line on the left: the breakwater.
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var x := -0.02
	while x < 0.42:
		var w := rng.randf_range(0.05, 0.09)
		var top := rng.randf_range(0.80, 0.86)
		var poly := PackedVector2Array()
		var corners := 7
		for i in corners:
			var a := TAU * i / corners
			var r := rng.randf_range(0.75, 1.0)
			poly.append(Vector2(x + w * 0.5 + cos(a) * w * 0.5 * r, top + 0.06 + sin(a) * 0.06 * r))
		_rocks.append(poly)
		x += w * rng.randf_range(0.7, 0.9)


func _build_water() -> void:
	_container = SubViewportContainer.new()
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.stretch = true
	_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_container.add_child(viewport)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_material = ShaderMaterial.new()
	_material.shader = WATER_SHADERS["realistic"]
	_material.set_shader_parameter("horizon", HORIZON)
	rect.material = _material
	viewport.add_child(rect)


func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)


## Rings, lure, line, splash, the breakwater and the rod, at full resolution
## so they stay readable over the water.
func _draw_overlay() -> void:
	var size := _overlay.size
	var light: float = environment()["light"]
	# Rings on the water, in perspective.
	for ring: Dictionary in _fx.rings:
		var world: Vector2 = ring["world"]
		var r := SplashFx.ring_radius(ring)
		var centre := project(world)
		var aspect := size.x / maxf(size.y, 1.0)
		var rx := r / (world.y * aspect * FOV) * size.x
		var ry := CAM_HEIGHT * r / (world.y * world.y * FOV) * size.y
		_draw_ellipse(centre, rx, ry, Color(1, 1, 1, 0.55 * SplashFx.ring_alpha(ring) * (0.4 + 0.6 * light)))
	var lure := _lure_screen()
	var lure_size := clampf(140.0 / _lure_world.y, 3.0, 9.0) if _flight_t < 0.0 else 6.0
	_overlay.draw_circle(lure, lure_size, Color(0.95, 0.3, 0.15))
	_overlay.draw_circle(lure, lure_size, Color(1, 1, 1, 0.8), false, 1.2)
	if _rope != null:
		_overlay.draw_polyline(_rope.points, Color(1, 1, 1, 0.55 + 0.3 * light), 1.4, true)
	for p: Dictionary in _fx.particles:
		var alpha: float = float(p["life"]) / float(p["max_life"])
		_overlay.draw_circle(p["pos"], p["size"], Color(0.92, 0.96, 1.0, 0.85 * alpha))
	_draw_breakwater(size, light)
	var tip := _rod_tip()
	_overlay.draw_line(Vector2(size.x * 0.97, size.y * 1.02), tip, Color(0.1, 0.1, 0.12), 7.0, true)


## Darkens a colour for the light slot without making it transparent.
static func _shaded(color: Color, shade: float) -> Color:
	return Color(color.r * shade, color.g * shade, color.b * shade, 1.0)


func _draw_ellipse(centre: Vector2, rx: float, ry: float, color: Color) -> void:
	if rx < 0.5 or color.a <= 0.01:
		return
	var points := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		points.append(centre + Vector2(cos(a) * rx, sin(a) * ry))
	_overlay.draw_polyline(points, color, 1.2, true)


## The concrete top of the breakwater and armour stones along its edge.
## Generic shapes, not a survey of a real structure.
func _draw_breakwater(size: Vector2, light: float) -> void:
	var shade := 0.25 + 0.75 * light
	for poly in _rocks:
		var pts := PackedVector2Array()
		for q in poly:
			pts.append(Vector2(q.x * size.x, q.y * size.y))
		_overlay.draw_colored_polygon(pts, _shaded(Color(0.30, 0.29, 0.27), shade))
		_overlay.draw_polyline(pts + PackedVector2Array([pts[0]]), _shaded(Color(0.45, 0.43, 0.40), shade), 1.5, true)
	var top_left := Vector2(0.0, size.y * EDGE_LEFT)
	var top_right := Vector2(size.x, size.y * EDGE_RIGHT)
	var slab := PackedVector2Array([top_left, top_right, Vector2(size.x, size.y), Vector2(0.0, size.y)])
	_overlay.draw_colored_polygon(slab, _shaded(Color(0.52, 0.50, 0.46), shade))
	# Wet, darker strip along the edge and a lighter worn rim.
	var wet := PackedVector2Array([top_left, top_right, top_right + Vector2(0, size.y * 0.018), top_left + Vector2(0, size.y * 0.018)])
	_overlay.draw_colored_polygon(wet, _shaded(Color(0.36, 0.35, 0.33), shade))
	_overlay.draw_line(top_left, top_right, _shaded(Color(0.68, 0.66, 0.62), shade), 2.0, true)
	# Slab joints in perspective.
	for i in range(1, 9):
		var t := i / 9.0
		var a := top_left.lerp(top_right, t)
		var b := Vector2(size.x * (0.5 + (t - 0.5) * 1.6), size.y)
		_overlay.draw_line(a, b, _shaded(Color(0.40, 0.38, 0.35), shade), 1.5, true)


func _build_controls() -> void:
	var back := Button.new()
	back.text = tr("PROTO_BACK")
	back.custom_minimum_size = Vector2(160, 96)
	back.position = Vector2(16, 16)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file.call_deferred(MAIN_SCENE))
	add_child(back)

	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top.offset_right = -16
	top.offset_top = 16
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_fps_label = _label(top, 26)
	_visible_label = _label(top, 22)
	var note := _label(top, 18)
	note.text = tr("PROTO_NOTE")
	for label: Label in [_fps_label, _visible_label, note]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = 16
	panel.offset_bottom = -16
	panel.custom_minimum_size = Vector2(380, 0)
	add_child(panel)
	_chop_label = _label(panel, 22)
	_slider(panel, 0.0, 1.0, 0.05, chop, func(v: float) -> void:
		chop = v
		_apply())
	_clarity_label = _label(panel, 22)
	_slider(panel, 1.0, 20.0, 1.0, clarity, func(v: float) -> void:
		clarity = v
		_apply())
	var row := HBoxContainer.new()
	panel.add_child(row)
	_slot_button = _button(row, func() -> void:
		slot_index = (slot_index + 1) % SLOTS.size()
		_apply())
	_res_button = _button(row, func() -> void:
		low_res = not low_res
		_stats.reset()
		_apply())
	_style_button = _button(panel, func() -> void:
		realistic = not realistic
		_stats.reset()
		_apply())

	_cast_button = Button.new()
	_cast_button.text = tr("PROTO_CAST")
	_cast_button.custom_minimum_size = Vector2(200, 120)
	_cast_button.add_theme_font_size_override("font_size", 28)
	_cast_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_cast_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_cast_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_cast_button.offset_right = -16
	_cast_button.offset_bottom = -16
	_cast_button.pressed.connect(cast_lure)
	add_child(_cast_button)


func _label(parent: Node, font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	parent.add_child(label)
	return label


func _slider(parent: Node, lo: float, hi: float, step: float, value: float, on_change: Callable) -> void:
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(380, 80)
	slider.value_changed.connect(on_change)
	parent.add_child(slider)


func _button(parent: Node, on_press: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(186, 96)
	button.pressed.connect(on_press)
	parent.add_child(button)
	return button


func _apply() -> void:
	var env := environment()
	var palette: Array = PALETTES[SLOTS[slot_index]]
	var sun: Array = SUNS[SLOTS[slot_index]]
	_material.shader = WATER_SHADERS["realistic" if realistic else "basic"]
	_material.set_shader_parameter("sun_dir", (sun[0] as Vector3).normalized())
	_material.set_shader_parameter("sun_color", sun[1])
	_material.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	_material.set_shader_parameter("horizon", HORIZON)
	_material.set_shader_parameter("chop", chop)
	_material.set_shader_parameter("cloud_cover", 0.25 + 0.45 * chop)
	_material.set_shader_parameter("visibility", env["visibility"])
	_material.set_shader_parameter("light", env["light"])
	_material.set_shader_parameter("sky_top", palette[0])
	_material.set_shader_parameter("sky_horizon", palette[1])
	_material.set_shader_parameter("water_deep", palette[2])
	_material.set_shader_parameter("water_shallow", palette[3])
	_container.stretch_shrink = 2 if low_res else 1
	_chop_label.text = "%s: %.2f" % [tr("PROTO_CHOP"), chop]
	_clarity_label.text = "%s: %d" % [tr("PROTO_CLARITY"), int(clarity)]
	_slot_button.text = "%s: %s" % [tr("PROTO_LIGHT"), tr("SLOT_%s" % SLOTS[slot_index].to_upper())]
	_res_button.text = "%s: %s" % [tr("PROTO_RES"), "360p" if low_res else "720p"]
	_style_button.text = "%s: %s" % [tr("PROTO_STYLE"), tr("STYLE_REALISTIC") if realistic else tr("STYLE_BASIC")]
	_visible_label.text = tr("PROTO_VISIBLE") % env["visible_at_m"]
