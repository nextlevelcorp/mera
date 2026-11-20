class_name FishingHud
extends Control
## The controls of the fishing screen (PRD F4-F11): the cast and strike
## button, the reel pad, drag slider and pull button of the fight, the wait
## buttons, the status and hint texts, and the rig, catch log, result, why
## and settings panels. It builds and owns the widgets and the raw thumb
## state (reel, pull, side strain, drag); what a press means is decided by
## the fishing screen, which it calls. Split from fishing_screen.gd on
## 2026-11-17 (roadmap R1) without changing the layout or behaviour.

const TOUCH_MIN := 96.0

var scr: FishingScreen
var motion_chip: Button
var mon_label: Label
var depth_label: Label
var mon_pull: ProgressBar
var mon_jig: ProgressBar
var reel_pressed := false
var reel_y := 0.0
var pull_pressed := false
var steer := 0.0
var drag_ratio := 0.33
var reel_pad: Control
var drag_slider: Control
var pull_button: Button
var main_button: Button
var reel_in_button: Button
var speed_button: Button
var rig_button: Button
var log_button: Button
var bait_button: Button
var status_label: Label
var toast_label: Label
var hint_label: Label
var tension_label: Label
var distance_label: Label
var drag_label: Label
var rig_panel: Control
var rig_label: Label
var float_row: HBoxContainer
var float_label: Label
var bait_cycle: Button
var rig_cycle: Button
var position_cycle: Button
var result_panel: Control
var result_label: Label
var result_detail: Label
var log_panel: Control
var why_panel: Control
var why_text: Label
var why_button: Button
var settings_panel: Control
var settings_button: Button
var vol_slider: HSlider
var sens_slider: HSlider
var flip_check: CheckButton
var log_text: Label
## The drawn instruments over the fight and cast controls (Tide Instruments).
var cast_dial: Instrument
var reel_gauge: Instrument
var drag_lever: Instrument
var pull_well: Instrument


func _init(screen: FishingScreen) -> void:
	scr = screen
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_hud()
	_build_rig_panel()
	_build_result()
	_build_log()
	_build_why()
	_build_settings()


func _build_hud() -> void:
	var back := _button(tr("PROTO_BACK"), 22, func() -> void: scr.leave())
	back.custom_minimum_size = Vector2(160, TOUCH_MIN)
	back.position = Vector2(16, 16)
	_glass_key(back, "back")
	add_child(back)

	status_label = _label(20)
	add_child(status_label)
	status_label.position = Vector2(192, 20)
	status_label.size = Vector2(700, 30)

	# Motion status: shown only where the browser can send motion. A tap on it
	# (like any tap) lets iPhone Safari ask for permission.
	motion_chip = _button("", 16, func() -> void:
		if scr._motion:
			scr._motion.request_permission())
	motion_chip.anchor_left = 1.0
	motion_chip.anchor_right = 1.0
	motion_chip.offset_left = -360.0
	motion_chip.offset_right = -16.0
	motion_chip.offset_top = 100.0
	motion_chip.offset_bottom = 150.0
	motion_chip.custom_minimum_size = Vector2(0, 54)
	motion_chip.clip_text = true
	motion_chip.visible = false
	add_child(motion_chip)

	tension_label = _label(24)
	add_child(tension_label)
	_top_center(tension_label, 98.0, 32.0)
	tension_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	distance_label = _label(30)
	add_child(distance_label)
	_top_center(distance_label, 132.0, 40.0)
	distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	depth_label = _label(22)
	add_child(depth_label)
	_top_center(depth_label, 172.0, 30.0)
	depth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label = _label(30)
	add_child(toast_label)
	_top_center(toast_label, 200.0, 44.0)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.visible = false
	hint_label = _label(22)
	add_child(hint_label)
	_top_center(hint_label, 176.0, 32.0)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.text = tr("FISH_OVERMATCHED")
	hint_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	hint_label.visible = false

	# Fight controls.
	reel_pad = _pad(tr("FIGHT_REEL"))
	_place_bottom(reel_pad, false, Vector2(260, 300), 16.0)
	reel_pad.gui_input.connect(_on_reel_input)
	reel_gauge = _skin(reel_pad, Instrument.Kind.REEL, tr("FIGHT_REEL"))
	drag_slider = _pad(tr("FIGHT_DRAG"))
	_place_bottom(drag_slider, true, Vector2(120, 300), 230.0)
	drag_slider.gui_input.connect(_on_drag_input)
	drag_lever = _skin(drag_slider, Instrument.Kind.LEVER, tr("FIGHT_DRAG"))
	drag_label = _label(20)
	drag_slider.add_child(drag_label)
	drag_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	drag_label.offset_left = -40.0
	drag_label.offset_right = 40.0
	drag_label.offset_top = -30.0
	drag_label.offset_bottom = -4.0
	drag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pull_button = _button(tr("FIGHT_PULL"), 28, Callable())
	_place_bottom(pull_button, true, Vector2(210, 210), 16.0)
	pull_button.button_down.connect(func() -> void: pull_pressed = true)
	pull_button.button_up.connect(func() -> void: pull_pressed = false)
	# A second finger does not emulate a mouse, so listen to raw touch as well.
	pull_button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			pull_pressed = event.pressed
		# Where the thumb sits sideways on the button is the side strain.
		if event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouse:
			steer = FightController.steer_from_pad(event.position.x, pull_button.size.x))
	pull_well = _skin(pull_button, Instrument.Kind.WELL, tr("FIGHT_PULL"))
	add_child(pull_button)

	# Cast / strike: the same right-corner button.
	main_button = _button(tr("FISH_CAST"), 32, Callable())
	main_button.theme_type_variation = UiTheme.PRIMARY
	_place_bottom(main_button, true, Vector2(220, 220), 16.0)
	cast_dial = _skin(main_button, Instrument.Kind.DIAL, main_button.text)
	main_button.button_down.connect(scr._on_main_down)
	main_button.button_up.connect(scr._on_main_up)
	main_button.gui_input.connect(scr._on_main_input)
	add_child(main_button)

	# Wait controls on the left.
	reel_in_button = _button(tr("FISH_REEL_IN"), 24, scr.reel_in)
	_top_left(reel_in_button, 128.0)
	_glass_key(reel_in_button, "reel_in")
	add_child(reel_in_button)
	speed_button = _button(tr("FISH_SPEED"), 24, func() -> void: scr._speed_on = not scr._speed_on)
	speed_button.toggle_mode = true
	_top_left(speed_button, 232.0)
	_glass_key(speed_button, "speed")
	add_child(speed_button)

	# Ready controls on the left.
	rig_button = _button(tr("FISH_RIG"), 24, func() -> void:
		log_panel.visible = false
		rig_panel.visible = not rig_panel.visible)
	_top_left(rig_button, 128.0)
	_glass_key(rig_button, "rig")
	add_child(rig_button)
	log_button = _button(tr("FISH_LOG"), 24, func() -> void:
		rig_panel.visible = false
		log_panel.visible = not log_panel.visible
		scr._update_log())
	_top_left(log_button, 232.0)
	_glass_key(log_button, "log")
	add_child(log_button)
	# Choose and put on a bait at any time while getting ready (R20).
	bait_button = _button(tr("FISH_BAIT"), 24, func() -> void:
		rig_panel.visible = false
		log_panel.visible = false
		scr.open_baiting())
	_top_left(bait_button, 336.0)
	_glass_key(bait_button, "hook")
	add_child(bait_button)


func _build_rig_panel() -> void:
	var box := _panel(Vector2(560, 0))
	rig_panel = box.get_parent()
	rig_panel.visible = false
	var title := _plain_label(tr("FISH_RIG"), 30)
	box.add_child(title)
	rig_cycle = _button("", 24, func() -> void: scr.next_open_rig())
	box.add_child(rig_cycle)
	position_cycle = _button("", 24, func() -> void:
		var positions: Array = scr.spot()["positions"]
		scr.set_rig(scr.rig, positions[(scr._position_index(scr.position_id) + 1) % positions.size()]["id"]))
	box.add_child(position_cycle)
	# Float rig: where the float stop sits, so the bait hangs at that depth (R12).
	float_row = HBoxContainer.new()
	float_row.add_theme_constant_override("separation", 8)
	float_row.add_child(_button(tr("RIG_SHALLOWER"), 22, func() -> void: scr.change_float_depth(-0.5)))
	float_label = _plain_label("", 20)
	float_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	float_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	float_row.add_child(float_label)
	float_row.add_child(_button(tr("RIG_DEEPER"), 22, func() -> void: scr.change_float_depth(0.5)))
	box.add_child(float_row)
	bait_cycle = _button("", 22, func() -> void: scr.cycle_bait())
	box.add_child(bait_cycle)
	rig_label = _plain_label("", 18)
	rig_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(rig_label)
	box.add_child(_button(tr("FISH_CLOSE"), 24, func() -> void: rig_panel.visible = false))


func _build_result() -> void:
	var box := _panel(Vector2(600, 0))
	result_panel = box.get_parent()
	result_panel.visible = false
	result_label = _plain_label("", 40)
	box.add_child(result_label)
	result_detail = _plain_label("", 22)
	result_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(result_detail)
	why_button = _button(tr("WHY_BUTTON"), 24, scr._show_why)
	box.add_child(why_button)
	var again := _button(tr("FISH_CAST_AGAIN"), 28, func() -> void:
		scr._hud = {}
		scr._set_phase(FishingScreen.Phase.READY))
	again.custom_minimum_size = Vector2(0, 110)
	again.theme_type_variation = UiTheme.PRIMARY
	box.add_child(again)


func _build_log() -> void:
	var box := _panel(Vector2(700, 0))
	log_panel = box.get_parent()
	log_panel.visible = false
	box.add_child(_plain_label(tr("LOG_TITLE"), 30))
	log_text = _plain_label("", 20)
	log_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	log_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(log_text)
	box.add_child(_button(tr("FISH_CLOSE"), 24, func() -> void: log_panel.visible = false))


func _build_why() -> void:
	var box := _panel(Vector2(780, 0))
	why_panel = box.get_parent()
	why_panel.visible = false
	box.add_child(_plain_label(tr("WHY_TITLE"), 30))
	why_text = _plain_label("", 18)
	why_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	why_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(why_text)
	box.add_child(_button(tr("FISH_CLOSE"), 24, func() -> void:
		why_panel.visible = false
		result_panel.visible = true))


func _build_settings() -> void:
	settings_button = _button(tr("SET_BUTTON"), 20, func() -> void:
		rig_panel.visible = false
		log_panel.visible = false
		settings_panel.visible = not settings_panel.visible)
	_glass_key(settings_button, "settings")
	settings_button.anchor_left = 1.0
	settings_button.anchor_right = 1.0
	settings_button.offset_left = -296.0
	settings_button.offset_right = -156.0
	settings_button.offset_top = 16.0
	settings_button.offset_bottom = 88.0
	settings_button.custom_minimum_size = Vector2(0, 72)
	add_child(settings_button)
	var box := _panel(Vector2(640, 0))
	settings_panel = box.get_parent()
	settings_panel.visible = false
	box.add_child(_plain_label(tr("SET_TITLE"), 30))
	box.add_child(_plain_label(tr("SET_VOLUME"), 20))
	vol_slider = _slider(0.0, 1.0, 0.05, func(v: float) -> void: scr._change_setting("volume", v))
	box.add_child(vol_slider)
	box.add_child(_plain_label(tr("SET_MOTION"), 20))
	sens_slider = _slider(0.5, 2.0, 0.1, func(v: float) -> void: scr._change_setting("motion_sens", v))
	box.add_child(sens_slider)
	# Live view of what the phone reports, so a wrong reading can be seen.
	mon_label = _plain_label("", 16)
	mon_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(mon_label)
	mon_pull = ProgressBar.new()
	mon_pull.max_value = 1.0
	mon_pull.show_percentage = false
	mon_pull.custom_minimum_size = Vector2(0, 16)
	box.add_child(mon_pull)
	mon_jig = ProgressBar.new()
	mon_jig.max_value = 1.0
	mon_jig.show_percentage = false
	mon_jig.custom_minimum_size = Vector2(0, 16)
	box.add_child(mon_jig)
	box.add_child(_button(tr("SET_RECENTER"), 20, func() -> void: scr._gesture.calibrated = false))
	var help := _plain_label(tr("SET_MOTION_HELP"), 15)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(help)
	flip_check = CheckButton.new()
	flip_check.text = tr("SET_INVERT")
	flip_check.add_theme_font_size_override("font_size", 22)
	flip_check.custom_minimum_size = Vector2(0, TOUCH_MIN * 0.8)
	flip_check.toggled.connect(func(on: bool) -> void:
		scr._change_setting("motion_flip", on)
		scr._store())
	box.add_child(flip_check)
	box.add_child(_button(tr("FISH_CLOSE"), 24, func() -> void: settings_panel.visible = false))


func _slider(lo: float, hi: float, step: float, on_change: Callable) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.custom_minimum_size = Vector2(0, 56)
	slider.value_changed.connect(on_change)
	slider.drag_ended.connect(func(_changed: bool) -> void: scr._store())
	return slider


func _on_reel_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		reel_pressed = event.pressed
		reel_y = event.position.y
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if reel_pressed:
			reel_y = event.position.y


func _on_drag_input(event: InputEvent) -> void:
	var down: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed)
	var moving: bool = (event is InputEventScreenDrag) or (event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	if down or moving:
		drag_ratio = clampf(1.0 - event.position.y / maxf(drag_slider.size.y, 1.0), 0.0, 1.0)


## Puts the drawn instrument over a control and hides the control's own look;
## the control keeps its input.
func _skin(control: Control, instrument_kind: Instrument.Kind, caption: String) -> Instrument:
	var empty := StyleBoxEmpty.new()
	if control is Button:
		for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
			control.add_theme_stylebox_override(state, empty)
		for c: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color", &"font_focus_color", &"font_disabled_color"]:
			control.add_theme_color_override(c, Color(0, 0, 0, 0))
	else:
		control.add_theme_stylebox_override("panel", empty)
		control.self_modulate = Color(1, 1, 1, 1)
		for child: Node in control.get_children():
			if child is Label:
				(child as Label).visible = false   # the instrument draws its caption
	var inst := Instrument.new(instrument_kind, caption)
	control.add_child(inst)
	return inst


## A secondary key: a smoked-glass pill with an engraved glyph before the word.
func _glass_key(button: Button, glyph: String) -> void:
	button.theme_type_variation = UiTheme.GLASS_KEY
	var g := Instrument.new(Instrument.Kind.GLYPH)
	g.glyph = glyph
	g.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	g.offset_left = 14.0
	g.offset_right = 58.0
	g.offset_top = -22.0
	g.offset_bottom = 22.0
	button.add_child(g)


## Feeds the instruments from the screen's state each frame.
func refresh_instruments(delta: float, power: float, striking: bool) -> void:
	cast_dial.caption = main_button.text
	cast_dial.value = power
	cast_dial.alert = striking
	cast_dial.pressed = main_button.button_pressed
	var speed := FightController.reel_from_pad(reel_pressed, reel_y, reel_pad.size.y)
	reel_gauge.value = speed
	reel_gauge.pressed = reel_pressed
	reel_gauge.thumb_y = reel_y if reel_pressed else -1.0
	reel_gauge.spin = fmod(reel_gauge.spin + delta * speed * 12.0, TAU)
	drag_lever.value = drag_ratio
	pull_well.pressed = pull_pressed
	pull_well.steer = steer if pull_pressed else 0.0
	for inst: Instrument in [cast_dial, reel_gauge, drag_lever, pull_well]:
		if inst.is_visible_in_tree():
			inst.queue_redraw()


func _place_bottom(control: Control, right_side: bool, control_size: Vector2, dx: float) -> void:
	var edge := 1.0 if right_side else 0.0
	control.anchor_left = edge
	control.anchor_right = edge
	control.anchor_top = 1.0
	control.anchor_bottom = 1.0
	if right_side:
		control.offset_right = -dx
		control.offset_left = -dx - control_size.x
	else:
		control.offset_left = dx
		control.offset_right = dx + control_size.x
	control.offset_bottom = -16.0
	control.offset_top = -16.0 - control_size.y


## A 200 px wide, 96 px high button at the top left, y px down.
func _top_left(control: Control, y: float) -> void:
	control.anchor_left = 0.0
	control.anchor_right = 0.0
	control.anchor_top = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = 16.0
	control.offset_right = 216.0
	control.offset_top = y
	control.offset_bottom = y + TOUCH_MIN


func _top_center(control: Control, y: float, height: float) -> void:
	control.anchor_left = 0.5
	control.anchor_right = 0.5
	control.offset_left = -300.0
	control.offset_right = 300.0
	control.offset_top = y
	control.offset_bottom = y + height


func _pad(caption: String) -> Control:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var label := _label(24)
	label.text = caption
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = 8.0
	label.offset_bottom = 38.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	panel.self_modulate = Color(1, 1, 1, 0.45)
	add_child(panel)
	return panel


## A centred panel; returns its VBox (the panel is the VBox's parent).
func _panel(min_size: Vector2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = min_size
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	return box


func _button(text: String, font_size: int, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.custom_minimum_size = Vector2(0, TOUCH_MIN * 0.8)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b


func _plain_label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
