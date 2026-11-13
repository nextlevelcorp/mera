extends Control
## Fight screen (PRD F8, F11; data_model.md 5.5). A thin view over
## FightController: the simulation owns every rule, this scene reads its state
## and sends two-thumb input. Runs on the demo data in res://data/demo (design
## fills, not real places or fish). Reached from a temporary button on the
## title screen until the debug menu exists.
##
## Controls, landscape, thumbs on the corners (spec 6.1):
##   left pad    hold; how high the thumb sits sets the reel effort
##   right       drag slider (up = more drag) and a "pull" button that pulls the
##               rod against the fish's run

const MAIN_SCENE := "res://scenes/main.tscn"
const DEMO_DIR := "res://data/demo"
const SPECIES_IDS: Array[String] = ["istavrit", "lufer", "levrek"]
const CONDITIONS := {"slot": "evening", "month": 10, "wind_dir": "SW", "wind_ms": 3}
const SLOT := "evening"
const CHOP := 0.3
const TOUCH_MIN := 96.0
const NEAR_DRAW_M := 4.6  ## drawing depth of the angler's feet; the camera cannot see nearer

var species_index := 0
var tackle_index := 0
var running := false

var _db: Dictionary
var _k: Dictionary
var _light := 0.6
var _visibility := 0.25
var _ctx: Dictionary
var _controller: FightController
var _hud := {}
var _water: WaterView
var _overlay: Control
var _fx := SplashFx.new(9)
var _seed_counter := 1
var _time := 0.0
var _splash_clock := 0.0
var _last_state := ""

var _reel_pressed := false
var _reel_y := 0.0
var _pull_pressed := false
var _drag_ratio := 0.33

var _reel_pad: Control
var _drag_slider: Control
var _pull_button: Button
var _setup_panel: Control
var _result_panel: Control
var _result_label: Label
var _result_detail: Label
var _species_button: Button
var _tackle_button: Button
var _tension_label: Label
var _distance_label: Label
var _drag_label: Label


func _ready() -> void:
	setup()
	add_child(DeviceGuard.new())


## Everything except the portrait guard, so it can run without a viewport.
func setup() -> void:
	var errors: Array[String] = []
	var loaded := DataStore.load_all(DEMO_DIR)
	if not loaded["ok"]:
		push_error("Demo data failed to load: %s" % str(loaded["errors"]))
		return
	_db = loaded["database"]
	_k = DataStore.load_constants(errors)
	var env := CatchModel.environment(_k, _db["spot"][0], _db["spot"][0]["positions"][0], CONDITIONS)
	_light = env["light"]
	_visibility = env["visibility"]
	_water = WaterView.new()
	add_child(_water)
	_water.set_conditions(SLOT, CHOP, _visibility, _light)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_build_hud()
	_build_setup()
	_build_result()
	_prepare_context()
	_show_setup(true)


# ------------------------------------------------------------------ fight

func _prepare_context() -> void:
	var u := fmod(float(_seed_counter) * 0.6180339887, 1.0)
	_ctx = FightSetup.build(_db, SPECIES_IDS[species_index], FightSetup.TACKLES[tackle_index], "pier_end", u, CONDITIONS)
	_drag_ratio = clampf(float(_ctx["play"]["drag_kg"]) / float(_ctx["reel"]["drag_max_kg"]), 0.0, 1.0)
	_controller = FightController.new(_ctx, _k, _seed_counter)
	_hud = _controller.hud()
	_fx = SplashFx.new(_seed_counter)
	_last_state = ""
	_update_texts()


func start_fight() -> void:
	_prepare_context()
	running = true
	_show_setup(false)
	_result_panel.visible = false


func current_input() -> Dictionary:
	return {
		"reel": FightController.reel_from_pad(_reel_pressed, _reel_y, _reel_pad.size.y),
		"rod": FightController.rod_from_button(_pull_pressed),
		"drag_kg": FightController.drag_from_slider(_drag_ratio, _controller.drag_max_kg),
	}


func _process(delta: float) -> void:
	_time += delta
	if running:
		_hud = _controller.advance(delta, current_input())
		_fish_effects(delta)
		if _hud["outcome"] != "":
			running = false
			_show_result()
	_fx.step(delta)
	_update_texts()
	_overlay.queue_redraw()


func _fish_effects(delta: float) -> void:
	var pos := _fish_world()
	var screen := WaterView.project(pos, 0.0, _overlay.size)
	var state: String = _hud["fish_state"]
	if state != _last_state:
		if state == "run":
			_fx.add_ring(pos, 0.5, 1.6, 0.5)
		_last_state = state
	_splash_clock -= delta
	if _splash_clock <= 0.0 and (state == "thrash" or (_hud["in_landing"] and state != "rest")):
		_splash_clock = 0.45
		_fx.splash(screen, pos, 0.7)


## Where the fish is on the water: out along z by the line-out, drifting
## sideways with the state so the line shows what it is doing.
func _fish_world() -> Vector2:
	var d := float(_hud["distance_m"])
	var side := sin(_time * 0.7) * 0.12 * d + (0.08 * d if _hud["fish_state"] == "run" else 0.0)
	# Drawing depth only: the camera sees nothing nearer than about 3.9 m, so
	# the last metres of line are drawn from NEAR_DRAW_M outwards. The
	# simulation distance is untouched.
	return Vector2(side - 0.3, NEAR_DRAW_M + d)


# ------------------------------------------------------------------ drawing

func _draw_overlay() -> void:
	var size := _overlay.size
	var pos := _fish_world()
	var fish := WaterView.project(pos, 0.0, size)
	for ring: Dictionary in _fx.rings:
		var world: Vector2 = ring["world"]
		var r := SplashFx.ring_radius(ring)
		var centre := WaterView.project(world, 0.0, size)
		var aspect := size.x / maxf(size.y, 1.0)
		var rx := r / (maxf(world.y, 0.5) * aspect * WaterView.FOV) * size.x
		var ry := WaterView.CAM_HEIGHT * r / (world.y * world.y * WaterView.FOV) * size.y
		_ellipse(centre, rx, ry, Color(1, 1, 1, 0.55 * SplashFx.ring_alpha(ring)))
	var ratio: float = clampf(float(_hud["tension_ratio"]), 0.0, 1.2)
	var tip := _rod_tip(ratio)
	if running or _hud["outcome"] != "":
		_draw_line_to(tip, fish, ratio, size)
	if _hud["fish_visible"] and _hud["outcome"] != "line_break" and _hud["outcome"] != "leader_cut":
		var scale := clampf(150.0 / maxf(pos.y, 1.0), 5.0, 40.0)
		var length: float = float(_ctx["play"]["fish_length_cm"]) / 40.0
		_overlay.draw_set_transform(fish, 0.0, Vector2(1.0, 0.35))
		_overlay.draw_circle(Vector2.ZERO, scale * length, Color(0.05, 0.08, 0.1, 0.8))
		_overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for p: Dictionary in _fx.particles:
		_overlay.draw_circle(p["pos"], p["size"], Color(0.92, 0.96, 1.0, 0.85 * float(p["life"]) / float(p["max_life"])))
	_draw_rod(size, tip)
	_draw_tension_bar(size)


func _rod_tip(ratio: float) -> Vector2:
	var size := _overlay.size
	# The tip bends towards the fish as the tension rises.
	return Vector2(size.x * (0.74 - 0.10 * clampf(ratio, 0.0, 1.2)), size.y * (0.32 + 0.12 * clampf(ratio, 0.0, 1.2)))


func _draw_rod(size: Vector2, tip: Vector2) -> void:
	var butt := Vector2(size.x * 0.97, size.y * 1.02)
	var mid := butt.lerp(tip, 0.55) + Vector2(-0.04 * size.x * float(_hud["tension_ratio"]), 0.0)
	_overlay.draw_polyline(PackedVector2Array([butt, mid, tip]), Color(0.1, 0.1, 0.12), 7.0, true)


func _draw_line_to(tip: Vector2, fish: Vector2, ratio: float, size: Vector2) -> void:
	var points := PackedVector2Array()
	var sag := Vector2(0.0, 46.0 * clampf(1.0 - ratio * 1.6, 0.0, 1.0))
	for i in 25:
		var t := i / 24.0
		points.append(tip.lerp(fish, t) + sag * sin(t * PI))
	var strained: bool = float(_hud["strain_ratio"]) > 0.0
	_overlay.draw_polyline(points, Color(1.0, 0.85, 0.5, 0.95) if strained else Color(1, 1, 1, 0.85), 2.0 if strained else 1.5, true)


func _ellipse(centre: Vector2, rx: float, ry: float, color: Color) -> void:
	if rx < 0.5 or color.a <= 0.01:
		return
	var points := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		points.append(centre + Vector2(cos(a) * rx, sin(a) * ry))
	_overlay.draw_polyline(points, color, 1.2, true)


## Tension against the line's strength. Shape, not colour, tells the danger:
## a tick at the strain threshold, a thick block at the break point, and the
## numbers in kilograms (PRD F18).
func _draw_tension_bar(size: Vector2) -> void:
	var w := minf(size.x * 0.46, 600.0)
	var h := 40.0
	var x := (size.x - w) * 0.5
	var y := 26.0
	var ratio: float = clampf(float(_hud["tension_ratio"]), 0.0, 1.0)
	_overlay.draw_rect(Rect2(x - 3, y - 3, w + 6, h + 6), Color(0, 0, 0, 0.55))
	_overlay.draw_rect(Rect2(x, y, w, h), Color(0.12, 0.14, 0.18, 0.9))
	var fill := Color(0.55, 0.85, 0.6) if ratio < 0.6 else (Color(0.95, 0.8, 0.35) if ratio < 0.8 else Color(0.95, 0.4, 0.3))
	_overlay.draw_rect(Rect2(x, y, w * ratio, h), fill)
	var thr := float(_hud["strain_threshold_ratio"])
	_overlay.draw_line(Vector2(x + w * thr, y - 8), Vector2(x + w * thr, y + h + 8), Color(1, 1, 1), 3.0)
	_overlay.draw_rect(Rect2(x + w - 8, y - 8, 8, h + 16), Color(1, 1, 1))
	# Drag setting as a notch under the bar.
	var drag_ratio: float = clampf(float(_hud["drag_set_kg"]) / float(_hud["line_strength_kg"]), 0.0, 1.0)
	var nx := x + w * drag_ratio
	_overlay.draw_colored_polygon(PackedVector2Array([Vector2(nx, y + h + 3), Vector2(nx - 9, y + h + 18), Vector2(nx + 9, y + h + 18)]), Color(1, 1, 1))
	# Time on the strain zone fills a thin bar above.
	var strain: float = clampf(float(_hud["strain_ratio"]), 0.0, 1.0)
	if strain > 0.0:
		_overlay.draw_rect(Rect2(x, y - 14, w * strain, 6), Color(1.0, 0.35, 0.25))


# ------------------------------------------------------------------ input

func _gui_input(_event: InputEvent) -> void:
	pass


func _on_reel_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		_reel_pressed = event.pressed
		_reel_y = event.position.y
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if _reel_pressed:
			_reel_y = event.position.y


func _on_drag_input(event: InputEvent) -> void:
	var down: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed)
	var moving: bool = (event is InputEventScreenDrag) or (event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	if down or moving:
		_drag_ratio = clampf(1.0 - event.position.y / maxf(_drag_slider.size.y, 1.0), 0.0, 1.0)


# ------------------------------------------------------------------ UI

func _build_hud() -> void:
	var back := Button.new()
	back.text = tr("PROTO_BACK")
	back.custom_minimum_size = Vector2(160, TOUCH_MIN)
	back.position = Vector2(16, 16)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file.call_deferred(MAIN_SCENE))
	add_child(back)

	_tension_label = _label(24)
	add_child(_tension_label)
	_top_center(_tension_label, 98.0, 32.0)
	_tension_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_distance_label = _label(30)
	add_child(_distance_label)
	_top_center(_distance_label, 132.0, 40.0)
	_distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_reel_pad = _pad(tr("FIGHT_REEL"))
	_place_bottom(_reel_pad, false, Vector2(260, 300), 16.0)
	_reel_pad.gui_input.connect(_on_reel_input)

	_drag_slider = _pad(tr("FIGHT_DRAG"))
	_place_bottom(_drag_slider, true, Vector2(120, 300), 230.0)
	_drag_slider.gui_input.connect(_on_drag_input)
	_drag_label = _label(22)
	_drag_slider.add_child(_drag_label)
	_drag_label.set_anchors_preset(Control.PRESET_CENTER)
	_drag_label.offset_left = -60.0
	_drag_label.offset_right = 60.0
	_drag_label.offset_top = -14.0
	_drag_label.offset_bottom = 14.0
	_drag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_pull_button = Button.new()
	_pull_button.text = tr("FIGHT_PULL")
	_pull_button.add_theme_font_size_override("font_size", 28)
	_pull_button.custom_minimum_size = Vector2(200, 200)
	_place_bottom(_pull_button, true, Vector2(200, 200), 16.0)
	_pull_button.button_down.connect(func() -> void: _pull_pressed = true)
	_pull_button.button_up.connect(func() -> void: _pull_pressed = false)
	# A second finger does not emulate a mouse, so listen to raw touch as well.
	_pull_button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			_pull_pressed = event.pressed)
	add_child(_pull_button)


## Pins a control to a bottom corner: dx from the side edge, 16 px from the bottom.
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


## A 600 px wide strip centred at the top, y pixels down.
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


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _build_setup() -> void:
	_setup_panel = PanelContainer.new()
	_setup_panel.set_anchors_preset(Control.PRESET_CENTER)
	_setup_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_setup_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_setup_panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(520, 0)
	box.add_theme_constant_override("separation", 14)
	_setup_panel.add_child(box)
	var title := Label.new()
	title.text = tr("FIGHT_SETUP")
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_species_button = Button.new()
	_species_button.custom_minimum_size = Vector2(0, TOUCH_MIN)
	_species_button.pressed.connect(func() -> void:
		species_index = (species_index + 1) % SPECIES_IDS.size()
		_prepare_context())
	box.add_child(_species_button)
	_tackle_button = Button.new()
	_tackle_button.custom_minimum_size = Vector2(0, TOUCH_MIN)
	_tackle_button.pressed.connect(func() -> void:
		tackle_index = (tackle_index + 1) % FightSetup.TACKLES.size()
		_prepare_context())
	box.add_child(_tackle_button)
	var start := Button.new()
	start.text = tr("FIGHT_START")
	start.add_theme_font_size_override("font_size", 28)
	start.custom_minimum_size = Vector2(0, 110)
	start.pressed.connect(start_fight)
	box.add_child(start)
	var note := Label.new()
	note.text = tr("FIGHT_NOTE")
	note.add_theme_font_size_override("font_size", 18)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)


func _build_result() -> void:
	_result_panel = PanelContainer.new()
	_result_panel.set_anchors_preset(Control.PRESET_CENTER)
	_result_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_result_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_result_panel.visible = false
	add_child(_result_panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(560, 0)
	box.add_theme_constant_override("separation", 14)
	_result_panel.add_child(box)
	_result_label = Label.new()
	_result_label.add_theme_font_size_override("font_size", 40)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result_label)
	_result_detail = Label.new()
	_result_detail.add_theme_font_size_override("font_size", 22)
	_result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_result_detail)
	var again := Button.new()
	again.text = tr("FIGHT_AGAIN")
	again.add_theme_font_size_override("font_size", 28)
	again.custom_minimum_size = Vector2(0, 110)
	again.pressed.connect(func() -> void:
		_seed_counter += 1
		_result_panel.visible = false
		_prepare_context()
		_show_setup(true))
	box.add_child(again)


func _show_setup(visible_now: bool) -> void:
	_setup_panel.visible = visible_now
	_reel_pad.visible = not visible_now
	_drag_slider.visible = not visible_now
	_pull_button.visible = not visible_now


func _show_result() -> void:
	var outcome: String = _hud["outcome"]
	_result_label.text = tr("FIGHT_%s" % outcome.to_upper())
	_result_detail.text = tr("FIGHT_DETAIL") % [_hud["time_s"], _hud["max_tension_kg"], _hud["line_strength_kg"]]
	if _hud["cap_applied"]:
		_result_detail.text += "\n" + tr("FIGHT_CAP")
	_result_panel.visible = true
	_reel_pressed = false
	_pull_pressed = false


func _update_texts() -> void:
	if _species_button == null:
		return
	_species_button.text = "%s: %s" % [tr("FIGHT_SPECIES"), tr(_ctx["species"]["name_key"])]
	_tackle_button.text = "%s: %s" % [tr("FIGHT_TACKLE"), tr(_ctx["rod"]["name_key"])]
	_tension_label.text = "%.2f / %.2f kg" % [_hud["tension_kg"], _hud["line_strength_kg"]]
	_distance_label.text = "%.1f m" % _hud["distance_m"]
	_drag_label.text = "%.1f kg" % _hud["drag_set_kg"] if running else "%.1f kg" % (_drag_ratio * (_controller.drag_max_kg if _controller else 0.0))
