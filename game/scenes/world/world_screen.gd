class_name WorldScreen
extends Node2D
## The top-down world (architecture.md 4), first grey-box prototype: one
## area (the Galata Bridge), a player walking with the stick under the left
## thumb, and the fishing markers on the rails. At a marker the action button
## fishes: the screen emits fish_requested with a FishingRequest and the
## owner (main.gd) opens the fishing view; resume() takes the result back.
## A view over WorldWalk and WorldArea: it holds no rules. Art is grey boxes
## on purpose (owner decision D1: pick the style on a real phone later).

signal fish_requested(request: Dictionary)
signal closed

const AREA_ID := "galata_bridge"
const DEBUG_MENU := "res://debug/world_debug.gd"
const STICK_RADIUS := 110.0
## The camera is close, as in Stardew Valley: about 27 m across at 1280 px.
const CAMERA_ZOOM := 2.0
const PLAYER_DRAW_SCALE := 2.0
## Slot tint over the whole world: the same conditions that light the sea.
const TINT := {
	"dawn": Color(1.0, 0.86, 0.82), "day": Color(1.0, 1.0, 1.0),
	"evening": Color(1.0, 0.76, 0.62), "night": Color(0.36, 0.42, 0.62),
}
const GROUND := {
	"plaza": Color(0.56, 0.56, 0.55), "walkway": Color(0.72, 0.72, 0.7),
	"road": Color(0.28, 0.28, 0.3), "water": Color(0.27, 0.38, 0.5),
}

var area: WorldArea
var walk: WorldWalk
var conditions := {}
## Where the save is read from; tests set "" to keep it in memory.
var profile_path := SaveFile.DEFAULT_PATH

var _cam: Camera2D
var _hud: CanvasLayer
var _pad: Control
var _knob: Panel
var _action: Button
var _prompt: Label
var _toast: Label
var _toast_s := 0.0
var _shop: ShopPanel
var _wallet: Label
var _stick := Vector2.ZERO
var _touching := false
var _time := 0.0


func _ready() -> void:
	setup()


## Loads the area and builds the controls. conditions: set before for a fixed
## set (tests, the debug menu); empty gives the phone's clock.
func setup() -> void:
	var loaded := WorldArea.load_area(AREA_ID, Db.database())
	if not loaded["ok"]:
		push_error("World area failed to load: %s" % str(loaded["errors"]))
		return
	area = loaded["area"]
	Profile.open(profile_path)
	walk = WorldWalk.new(area, Db.constants())
	if conditions.is_empty():
		conditions = SessionConditions.from_clock(Time.get_datetime_dict_from_system())
	_build_art()
	apply_conditions()
	_cam = Camera2D.new()
	_cam.limit_left = 0
	_cam.limit_top = 0
	_cam.limit_right = int(area.size_m.x * area.px_per_m)
	_cam.limit_bottom = int(area.size_m.y * area.px_per_m)
	_cam.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	_cam.position_smoothing_enabled = true
	_cam.position_smoothing_speed = 8.0
	_cam.position = walk.pos * area.px_per_m
	add_child(_cam)
	if _cam.is_inside_tree():
		_cam.make_current()
	_build_hud()
	_build_debug()


## Relights the world for the conditions' time of day: a canvas tint, the
## sun's relief on the textures and the lamps after dark.
func apply_conditions() -> void:
	_apply_art_light()


## While the fishing view is open the world sleeps: hidden, not processed,
## and its camera off (a camera would shift every other 2D control).
func pause() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	_canvas_tint.visible = false   # it would tint the fishing view's controls too
	_hud.visible = false
	_cam.enabled = false
	_stick = Vector2.ZERO
	_touching = false


## Back from fishing: the result of the visit as a short toast.
func resume(result: Dictionary) -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	_canvas_tint.visible = true
	_hud.visible = true
	_cam.enabled = true
	if _cam.is_inside_tree():
		_cam.make_current()
		_cam.reset_smoothing()
	show_toast(tr("TRIP_SUMMARY") % [int(result["casts"]), (result["catches"] as Array).size()], 4.0)


func show_toast(text: String, seconds: float) -> void:
	_toast.text = text
	_toast_s = seconds


## The FishingRequest for the marker in reach, or an empty dictionary.
func fishing_request() -> Dictionary:
	var m := walk.nearest_marker()
	if m.is_empty():
		return {}
	return Game.fishing_request(area.spot_id, m["position_id"], "", conditions.duplicate())


func fish() -> void:
	var request := fishing_request()
	if not request.is_empty():
		fish_requested.emit(request)


## The action button: a shop in reach opens it, else a fishing marker fishes.
func act() -> void:
	var shop := walk.nearest_shop()
	if not shop.is_empty():
		_shop.open(shop["id"])
	else:
		fish()


func _process(delta: float) -> void:
	if walk == null:
		return
	_time += delta
	var keys := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	walk.step(delta, keys if keys.length() > 0.0 else _stick)
	var moved := walk.pos.distance_to(_last_pos)
	_walk_phase += moved * 4.5
	_last_pos = walk.pos
	_cam.position = walk.pos * area.px_per_m
	var m := walk.nearest_marker()
	var shop := walk.nearest_shop()
	_action.visible = (not m.is_empty() or not shop.is_empty()) and not _shop.visible
	if not shop.is_empty():
		_prompt.text = tr("SHOP_%s" % String(shop["id"]).to_upper())
		_action.text = tr("WORLD_OPEN_SHOP")
	elif m.is_empty():
		_prompt.text = tr("WORLD_WALK_HINT")
	else:
		_prompt.text = tr(_position_name_key(m["position_id"]))
		_action.text = tr("WORLD_FISH_HERE")
	_wallet.text = "%s · %s" % [tr("MONEY_FMT") % Economy.money(Profile.save), tr("WORLD_BAG") % Inventory.fish_count(Profile.save)]
	_toast_s = maxf(_toast_s - delta, 0.0)
	_toast.visible = _toast_s > 0.0
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and not _shop.visible and (not walk.nearest_marker().is_empty() or not walk.nearest_shop().is_empty()):
		act()


func _position_name_key(position_id: String) -> String:
	for p: Dictionary in Db.record("spot", area.spot_id)["positions"]:
		if p["id"] == position_id:
			return p["name_key"]
	return ""


# ------------------------------------------------------------------ drawing

## Ground of each kind: a CC0 texture set (game/assets/3d), how many metres one
## repeat covers, and a tint. Water is a shader instead (world_water.gdshader).
const SURFACES := {
	"plaza": ["cobblestone_floor_04", 2.6, Color(0.95, 0.93, 0.9)],
	"walkway": ["concrete_pavement", 3.0, Color(1.0, 1.0, 1.0)],
	"road": ["rough_concrete", 2.0, Color(0.42, 0.42, 0.44)],
}
const WATER_SHADER := preload("res://scenes/world/world_water.gdshader")
const GROUND_SHADER := preload("res://scenes/world/world_ground.gdshader")
const LAMP_LIGHT := {"dawn": 0.4, "day": 0.0, "evening": 0.9, "night": 1.4}
const SUN_LIGHT := {"dawn": 0.35, "day": 0.55, "evening": 0.35, "night": 0.05}

var _surfaces := {}
var _canvas_tint: CanvasModulate
var _sun2d: DirectionalLight2D
var _lamps: Array[PointLight2D] = []
var _water_mats: Array[ShaderMaterial] = []
var _walk_phase := 0.0
var _last_pos := Vector2.ZERO


## Textures, water, sun and lamps: built once after the area is loaded.
func _build_art() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var s := area.px_per_m
	for r: Dictionary in area.rects:
		if r["kind"] == "water":
			continue
		var rect: Rect2 = r["rect"]
		var ground := ColorRect.new()
		ground.position = rect.position * s
		ground.size = rect.size * s
		ground.show_behind_parent = true
		ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ground.color = GROUND[r["kind"]]
		var spec: Array = SURFACES.get(r["kind"], [])
		var dir := "%s/%s" % [Stage3D.ASSET_DIR, spec[0]] if not spec.is_empty() else ""
		if dir != "" and ResourceLoader.exists("%s/diff.webp" % dir):
			var mat := ShaderMaterial.new()
			mat.shader = GROUND_SHADER
			mat.set_shader_parameter("albedo_tex", load("%s/diff.webp" % dir))
			mat.set_shader_parameter("normal_tex", load("%s/nor.webp" % dir))
			mat.set_shader_parameter("noise_tex", SeaMaps.cloud())
			mat.set_shader_parameter("size_m", rect.size)
			mat.set_shader_parameter("tile_m", float(spec[1]))
			mat.set_shader_parameter("tint", spec[2])
			ground.material = mat
			_surfaces[r["kind"]] = mat
		add_child(ground)
	for r: Dictionary in area.rects:
		if r["kind"] != "water":
			continue
		var rect: Rect2 = r["rect"]
		var water := ColorRect.new()
		water.position = rect.position * s
		water.size = rect.size * s
		water.show_behind_parent = true
		water.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = WATER_SHADER
		mat.set_shader_parameter("ripple_tex", SeaMaps.ripple())
		mat.set_shader_parameter("size_m", rect.size)
		# Foam only where the water meets stone, not at the edge of the map.
		mat.set_shader_parameter("foam_edges", Vector4(
			1.0 if rect.position.x > 0.01 else 0.0, 1.0 if rect.position.y > 0.01 else 0.0,
			1.0 if rect.end.x < area.size_m.x - 0.01 else 0.0, 1.0 if rect.end.y < area.size_m.y - 0.01 else 0.0))
		water.material = mat
		add_child(water)
		_water_mats.append(mat)
	_canvas_tint = CanvasModulate.new()
	add_child(_canvas_tint)
	_sun2d = DirectionalLight2D.new()
	_sun2d.height = 0.6
	_sun2d.rotation = deg_to_rad(35.0)
	add_child(_sun2d)
	var glow := GradientTexture2D.new()
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)
	glow.width = 256
	glow.height = 256
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	glow.gradient = g
	for lamp: Vector2 in area.lamps:
		var light := PointLight2D.new()
		light.texture = glow
		light.texture_scale = 7.0 * s / 128.0
		light.color = Color(1.0, 0.8, 0.5)
		light.height = 40.0
		light.position = lamp * s
		add_child(light)
		_lamps.append(light)


func _apply_art_light() -> void:
	var slot := String(conditions.get("slot", "day"))
	if _canvas_tint:
		_canvas_tint.color = TINT.get(slot, Color.WHITE)
	if _sun2d:
		_sun2d.energy = SUN_LIGHT.get(slot, 0.5)
	for l: PointLight2D in _lamps:
		l.energy = LAMP_LIGHT.get(slot, 0.0)
		l.visible = l.energy > 0.01
	for m: ShaderMaterial in _water_mats:
		m.set_shader_parameter("light", 1.0 if slot == "day" else (0.6 if slot != "night" else 0.15))


func _draw() -> void:
	if area == null:
		return
	var s := area.px_per_m
	var shadow := Color(0.0, 0.0, 0.05, 0.28)
	var sun_off := Vector2(0.35, 0.45) * s   # shadows fall to the bottom right
	# Kerbs: a lighter stone line where a walkway meets the road.
	for r: Dictionary in area.rects:
		if r["kind"] == "road":
			var rect := Rect2((r["rect"] as Rect2).position * s, (r["rect"] as Rect2).size * s)
			draw_rect(Rect2(rect.position - Vector2(0.15 * s, 0.0), Vector2(0.3 * s, rect.size.y)), Color(0.58, 0.57, 0.55))
			draw_rect(Rect2(Vector2(rect.end.x - 0.15 * s, rect.position.y), Vector2(0.3 * s, rect.size.y)), Color(0.58, 0.57, 0.55))
	# Rails: a shadow on the water, posts every 1.5 m, then the handrail.
	for rail: Dictionary in area.rails:
		var a: Vector2 = rail["from"] * s
		var b: Vector2 = rail["to"] * s
		draw_line(a + sun_off * 0.5, b + sun_off * 0.5, shadow, 0.25 * s)
		var steps := int(a.distance_to(b) / (1.5 * s))
		for i in steps + 1:
			var at := a.lerp(b, float(i) / float(maxi(steps, 1)))
			draw_rect(Rect2(at - Vector2(0.09, 0.09) * s, Vector2(0.18, 0.18) * s), Color(0.1, 0.13, 0.13))
		draw_line(a, b, Color(0.12, 0.16, 0.16), 0.12 * s)
		draw_line(a - Vector2(0.03 * s, 0.0), b - Vector2(0.03 * s, 0.0), Color(0.35, 0.42, 0.42), 0.04 * s)
	for sh: Dictionary in area.shops:
		_draw_kiosk(sh, s, shadow, sun_off)
	for lamp: Vector2 in area.lamps:
		var at := lamp * s
		draw_line(at, at + sun_off * 2.2, shadow, 0.16 * s)   # the pole's long shadow
		draw_circle(at, 0.22 * s, Color(0.1, 0.12, 0.12))
		draw_circle(at - Vector2(0.05, 0.05) * s, 0.09 * s, Color(0.35, 0.4, 0.4))
		for side in [-1.0, 1.0]:
			draw_circle(at + Vector2(side * 0.75 * s, 0.0), 0.16 * s, Color(0.95, 0.9, 0.75))
	var near := walk.nearest_marker()
	for m: Dictionary in area.markers:
		var active: bool = not near.is_empty() and near["position_id"] == m["position_id"]
		var c := Color(1.0, 0.85, 0.3, 1.0 if active else 0.6)
		var pulse := 1.0 + 0.12 * sin(_time * 3.0)
		draw_arc(m["pos"] * s, 0.7 * s * pulse, 0.0, TAU, 32, c, 3.0, true)
		if active:
			draw_circle(m["pos"] * s, 0.45 * s, Color(c, 0.3))
		var out := Vector2(1.0 if m["facing"] == "E" else -1.0, 0.0)
		draw_line(m["pos"] * s + out * 0.7 * s, m["pos"] * s + out * 1.5 * s, c, 3.0, true)
	_draw_player(s, shadow, sun_off)


## A market kiosk: a shadow, a striped awning, a counter with goods, a sign.
func _draw_kiosk(sh: Dictionary, s: float, shadow: Color, sun_off: Vector2) -> void:
	var fish: bool = sh["id"] == "fishmonger"
	var centre: Vector2 = sh["pos"] * s
	var box := Rect2(centre - Vector2(2.4, 1.6) * s, Vector2(4.8, 2.4) * s)
	draw_rect(Rect2(box.position + sun_off, box.size), shadow)
	draw_rect(box, Color(0.36, 0.3, 0.25))
	# Awning stripes.
	var stripe := box.size.x / 8.0
	for i in 8:
		var col := (Color(0.75, 0.2, 0.18) if fish else Color(0.15, 0.38, 0.58)) if i % 2 == 0 else Color(0.93, 0.92, 0.88)
		draw_rect(Rect2(box.position + Vector2(stripe * i, 0.0), Vector2(stripe, box.size.y * 0.55)), col)
	draw_rect(Rect2(box.position + Vector2(0.0, box.size.y * 0.55), Vector2(box.size.x, box.size.y * 0.06)), Color(0.0, 0.0, 0.0, 0.25))
	# Counter with goods.
	var counter := Rect2(box.position + Vector2(0.2 * s, box.size.y * 0.62), Vector2(box.size.x - 0.4 * s, box.size.y * 0.33))
	draw_rect(counter, Color(0.55, 0.45, 0.33))
	if fish:
		draw_rect(counter.grow(-0.08 * s), Color(0.82, 0.9, 0.95))   # crushed ice
		for i in 7:
			var at := counter.position + Vector2(0.4 * s + i * 0.6 * s, counter.size.y * 0.5)
			draw_set_transform(at, 0.35 * sin(i * 1.7), Vector2(1.0, 0.35))
			draw_circle(Vector2.ZERO, 0.24 * s, Color(0.62, 0.68, 0.74))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		for i in 6:
			var x := counter.position.x + 0.4 * s + i * 0.7 * s
			draw_line(Vector2(x, counter.position.y + counter.size.y), Vector2(x + 0.6 * s, counter.position.y - 0.9 * s), Color(0.12, 0.12, 0.14), 2.0, true)
			draw_rect(Rect2(Vector2(x + 0.1 * s, counter.end.y - 0.3 * s), Vector2(0.25, 0.2) * s), [Color(0.9, 0.5, 0.1), Color(0.2, 0.6, 0.3), Color(0.8, 0.2, 0.3)][i % 3])
	var label := tr("SHOP_%s" % String(sh["id"]).to_upper())
	var font := ThemeDB.fallback_font
	var at := Vector2(box.position.x + 6.0, box.position.y + box.size.y * 0.38)
	draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 8.0, 16, 4, Color(0, 0, 0, 0.8))
	draw_string(font, at, label, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 8.0, 16, Color(1, 1, 1))


## The angler from above: a shadow, legs that step, a jacket, a cap and the
## rod carried forward over the shoulder.
func _draw_player(px_per_m: float, shadow: Color, sun_off: Vector2) -> void:
	# Drawn twice life size, like the fish in the fishing view: a person seen
	# from above at true scale is a speck on a phone.
	var s := px_per_m * PLAYER_DRAW_SCALE
	var p := walk.pos * px_per_m
	var f := walk.facing.normalized() if walk.facing.length() > 0.01 else Vector2.DOWN
	var side := Vector2(-f.y, f.x)
	var stride := sin(_walk_phase) * 0.18 * s
	draw_set_transform(p + sun_off * 0.6, f.angle(), Vector2(1.0, 0.7))
	draw_circle(Vector2.ZERO, 0.42 * s, shadow)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for sgn in [-1.0, 1.0]:
		draw_circle(p + side * sgn * 0.12 * s + f * stride * sgn, 0.1 * s, Color(0.1, 0.11, 0.14))
	# Rod: from the right hand, forward and out.
	var hand := p + side * 0.28 * s + f * 0.1 * s
	draw_line(hand, hand + (f * 0.85 + side * 0.25).normalized() * 2.6 * s, Color(0.08, 0.08, 0.09), 0.05 * s, true)
	# Shoulders and jacket.
	draw_set_transform(p, side.angle(), Vector2(1.0, 0.62))
	draw_circle(Vector2.ZERO, 0.32 * s, Color(0.13, 0.2, 0.32))
	draw_circle(Vector2(-0.04, -0.04) * s, 0.24 * s, Color(0.18, 0.27, 0.42))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(hand, 0.08 * s, Color(0.8, 0.6, 0.48))
	# Head with a cap whose brim points forward.
	draw_circle(p + f * 0.04 * s, 0.15 * s, Color(0.75, 0.55, 0.43))
	draw_circle(p - f * 0.02 * s, 0.14 * s, Color(0.12, 0.12, 0.13))
	draw_set_transform(p + f * 0.14 * s, f.angle(), Vector2(1.0, 1.6))
	draw_circle(Vector2.ZERO, 0.07 * s, Color(0.1, 0.1, 0.11))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ------------------------------------------------------------------ controls

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 5
	add_child(_hud)
	var back := _button(tr("PROTO_BACK"), 22)
	back.custom_minimum_size = Vector2(160, 96)
	back.position = Vector2(16, 16)
	back.pressed.connect(func() -> void: closed.emit())
	_hud.add_child(back)
	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 24)
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_prompt.offset_left = -300.0
	_prompt.offset_right = 300.0
	_prompt.offset_top = 24.0
	_prompt.offset_bottom = 60.0
	_hud.add_child(_prompt)
	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 28)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_toast.add_theme_constant_override("outline_size", 6)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -400.0
	_toast.offset_right = 400.0
	_toast.offset_top = 80.0
	_toast.offset_bottom = 120.0
	_toast.visible = false
	_hud.add_child(_toast)
	# The stick pad under the left thumb.
	_pad = Panel.new()
	_pad.self_modulate = Color(1, 1, 1, 0.35)
	_pad.anchor_top = 1.0
	_pad.anchor_bottom = 1.0
	_pad.offset_left = 16.0
	_pad.offset_right = 296.0
	_pad.offset_top = -296.0
	_pad.offset_bottom = -16.0
	_pad.gui_input.connect(_on_pad_input)
	_hud.add_child(_pad)
	_knob = Panel.new()
	var round := StyleBoxFlat.new()
	round.bg_color = Color(1, 1, 1, 0.7)
	round.set_corner_radius_all(40)
	_knob.add_theme_stylebox_override("panel", round)
	_knob.size = Vector2(80, 80)
	_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.add_child(_knob)
	_knob.position = _pad.size * 0.5 - _knob.size * 0.5
	_pad.resized.connect(_center_knob)
	# The action button under the right thumb, shown at a marker.
	_action = _button(tr("WORLD_FISH_HERE"), 26)
	_action.anchor_left = 1.0
	_action.anchor_right = 1.0
	_action.anchor_top = 1.0
	_action.anchor_bottom = 1.0
	_action.offset_right = -16.0
	_action.offset_left = -316.0
	_action.offset_bottom = -16.0
	_action.offset_top = -216.0
	_action.visible = false
	_action.pressed.connect(act)
	_hud.add_child(_action)
	_wallet = Label.new()
	_wallet.add_theme_font_size_override("font_size", 22)
	_wallet.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_wallet.add_theme_constant_override("outline_size", 6)
	_wallet.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_wallet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wallet.offset_left = -300.0
	_wallet.offset_right = 300.0
	_wallet.offset_top = 60.0
	_wallet.offset_bottom = 90.0
	_hud.add_child(_wallet)
	_shop = ShopPanel.new()
	_hud.add_child(_shop)


func _center_knob() -> void:
	if not _touching:
		_knob.position = _pad.size * 0.5 - _knob.size * 0.5


func _on_pad_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		_touching = event.pressed
		if not _touching:
			_stick = Vector2.ZERO
			_center_knob()
			return
	elif not (event is InputEventScreenDrag or event is InputEventMouseMotion) or not _touching:
		return
	var offset: Vector2 = event.position - _pad.size * 0.5
	_stick = (offset / STICK_RADIUS).limit_length(1.0)
	_knob.position = _pad.size * 0.5 + _stick * STICK_RADIUS * 0.7 - _knob.size * 0.5


func _button(text: String, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	return b


func _build_debug() -> void:
	if not (OS.is_debug_build() or OS.has_feature("mera_debug")):
		return
	if not ResourceLoader.exists(DEBUG_MENU):
		return
	var menu: Control = (load(DEBUG_MENU) as GDScript).new(self)
	_hud.add_child(menu)
