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


func _ready() -> void:
	var errors: Array[String] = []
	_k = DataStore.load_constants(errors)
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
	_overlay.queue_redraw()


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


## Rod, line and lure at full resolution so they stay readable.
func _draw_overlay() -> void:
	var size := _overlay.size
	var water_top := size.y * HORIZON
	var bob: float = sin(_time * 1.3) * 6.0 * (0.2 + chop) + sin(_time * 2.9) * 3.0 * chop
	var lure := Vector2(size.x * 0.46, water_top + (size.y - water_top) * 0.42 + bob)
	var rod_butt := Vector2(size.x * 0.97, size.y * 1.02)
	var rod_tip := Vector2(size.x * 0.74, size.y * 0.30 + bob * 0.15)
	_overlay.draw_line(rod_butt, rod_tip, Color(0.1, 0.1, 0.12), 7.0, true)
	var sag := Vector2(0.0, 26.0 - 14.0 * chop)
	var points := PackedVector2Array()
	for i in 17:
		var t := i / 16.0
		points.append(rod_tip.lerp(lure, t) + sag * sin(t * PI))
	_overlay.draw_polyline(points, Color(1, 1, 1, 0.85), 1.5, true)
	_overlay.draw_circle(lure, 7.0, Color(0.95, 0.3, 0.15))
	_overlay.draw_circle(lure, 7.0, Color(1, 1, 1), false, 1.5)
	_overlay.draw_arc(lure, 14.0 + 6.0 * (0.5 + 0.5 * sin(_time * 1.3)), 0.0, TAU, 32, Color(1, 1, 1, 0.35), 1.5, true)


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
