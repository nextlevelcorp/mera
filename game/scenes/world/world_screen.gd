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
	apply_conditions()
	_cam = Camera2D.new()
	_cam.limit_left = 0
	_cam.limit_top = 0
	_cam.limit_right = int(area.size_m.x * area.px_per_m)
	_cam.limit_bottom = int(area.size_m.y * area.px_per_m)
	_cam.position_smoothing_enabled = true
	_cam.position_smoothing_speed = 8.0
	_cam.position = walk.pos * area.px_per_m
	add_child(_cam)
	if _cam.is_inside_tree():
		_cam.make_current()
	_build_hud()
	_build_debug()


## Recolours the world for the conditions' time of day.
func apply_conditions() -> void:
	modulate = TINT.get(String(conditions.get("slot", "day")), Color.WHITE)


## While the fishing view is open the world sleeps: hidden, not processed,
## and its camera off (a camera would shift every other 2D control).
func pause() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	_hud.visible = false
	_cam.enabled = false
	_stick = Vector2.ZERO
	_touching = false


## Back from fishing: the result of the visit as a short toast.
func resume(result: Dictionary) -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
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

func _draw() -> void:
	if area == null:
		return
	var s := area.px_per_m
	for r: Dictionary in area.rects:
		draw_rect(Rect2((r["rect"] as Rect2).position * s, (r["rect"] as Rect2).size * s), GROUND[r["kind"]])
	for rail: Dictionary in area.rails:
		draw_line(rail["from"] * s, rail["to"] * s, Color(0.15, 0.15, 0.17), 4.0)
	for lamp: Vector2 in area.lamps:
		draw_circle(lamp * s, 0.25 * s, Color(0.18, 0.18, 0.2))
		draw_circle(lamp * s, 0.6 * s, Color(1.0, 0.9, 0.55, 0.25))
	for sh: Dictionary in area.shops:
		var box := Rect2((sh["pos"] as Vector2 - Vector2(2.4, 1.0)) * s, Vector2(4.8, 2.0) * s)
		draw_rect(box, Color(0.45, 0.4, 0.35))
		draw_rect(Rect2(box.position, Vector2(box.size.x, 0.5 * s)), Color(0.6, 0.25, 0.2) if sh["id"] == "fishmonger" else Color(0.2, 0.4, 0.55))
		var label := tr("SHOP_%s" % String(sh["id"]).to_upper())
		draw_string(ThemeDB.fallback_font, box.position + Vector2(6.0, box.size.y - 8.0), label, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 8.0, 14, Color(1, 1, 1))
	var near := walk.nearest_marker()
	for m: Dictionary in area.markers:
		var active: bool = not near.is_empty() and near["position_id"] == m["position_id"]
		var c := Color(1.0, 0.85, 0.3, 1.0 if active else 0.7)
		var pulse := 1.0 + 0.12 * sin(_time * 3.0)
		draw_arc(m["pos"] * s, 0.7 * s * pulse, 0.0, TAU, 24, c, 3.0, true)
		if active:
			draw_circle(m["pos"] * s, 0.45 * s, Color(c, 0.35))
		# A small tick towards the water, so the facing can be read.
		var out := Vector2(1.0 if m["facing"] == "E" else -1.0, 0.0)
		draw_line(m["pos"] * s + out * 0.7 * s, m["pos"] * s + out * 1.5 * s, c, 3.0, true)
	# The player: a disc with a nose that points the way they walk.
	var p := walk.pos * s
	draw_circle(p, float(Db.constants()["WALK_RADIUS_M"]) * s, Color(0.95, 0.55, 0.15))
	draw_line(p, p + walk.facing * 0.5 * s, Color(0.2, 0.1, 0.0), 3.0, true)


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
