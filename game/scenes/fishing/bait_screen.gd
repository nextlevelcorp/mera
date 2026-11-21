class_name BaitScreen
extends Control
## The baiting screen (roadmap R20, owner 2026-11-20: "a separate screen:
## first choose the bait, then put it on by hand, with realistic mechanics
## and graphics"). Stage one lists what is in the bag for every rig; picking
## one emits chosen(option) so the fishing screen switches the rig. Stage two
## is a close-up of the hook and the bait, drawn in code: the hook's point
## follows the thumb and each stroke of Baiting is made for real (peel and
## thread a shrimp, hold a live fish and hook it behind the dorsal fin, thread
## a soft plastic straight, clip a snap to a lure's eye, unwind a sabiki and
## clip the weight). It emits done(quality). Baiting holds every rule; this
## draws and passes the thumb's positions in the work area's 0..1 units.

signal chosen(option: Dictionary)
signal done(quality: float)
signal cancelled

const HOOK_OFFSET := Vector2(0, -0.05)   ## the point sits above the thumb so the thumb does not hide it

var stage := ""          ## "choose" or "rig"
var kind := ""
var stroke := 0
var scores: Array[float] = []
var options: Array[Dictionary] = []
var _samples: Array = []
var _held := 0.0
var _touching := false
var _touch_index := -1           ## the one finger that bait; a second touch (a palm) is ignored
var _paused := false             ## a trace the thumb lifted from, to carry on
var _finger := Vector2(-1, -1)   ## thumb position in work units, -1 when none
var _t := 0.0
var _flash := ""                 ## the last stroke's rating, shown briefly
var _flash_s := 0.0
var _title: Label
var _hint: Label
var _cards: HBoxContainer
var _back: Button


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_title = _text(32)
	_title.position = Vector2(0, 18)
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 22.0
	_title.offset_bottom = 66.0
	add_child(_title)
	_hint = _text(22)
	_hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint.offset_top = 66.0
	_hint.offset_bottom = 100.0
	_hint.offset_left = 180.0
	_hint.offset_right = -180.0
	add_child(_hint)
	_back = Button.new()
	_back.text = tr("PROTO_BACK")
	_back.theme_type_variation = UiTheme.GLASS_KEY
	_back.position = Vector2(16, 16)
	_back.custom_minimum_size = Vector2(150, 80)
	_back.add_theme_font_size_override("font_size", 22)
	_back.pressed.connect(func() -> void:
		visible = false
		cancelled.emit())
	add_child(_back)
	_cards = HBoxContainer.new()
	_cards.set_anchors_preset(Control.PRESET_CENTER)
	_cards.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_cards.grow_vertical = Control.GROW_DIRECTION_BOTH
	_cards.add_theme_constant_override("separation", 14)
	add_child(_cards)


## Opens on the choosing step with these options (Baiting.options).
func open_choose(list: Array[Dictionary], current_item: String) -> void:
	options = list
	stage = "choose"
	visible = true
	_title.text = tr("BAIT_CHOOSE_TITLE")
	_hint.text = tr("BAIT_CHOOSE_HINT")
	for c in _cards.get_children():
		c.queue_free()
	for o: Dictionary in options:
		_cards.add_child(_card(o, String(o["item_id"]) == current_item))
	_cards.visible = true
	queue_redraw()


## Opens on the hook for one kind of bait.
func open_rig(bait_kind: String, title_text: String) -> void:
	kind = bait_kind
	stage = "rig"
	stroke = 0
	scores.clear()
	_samples.clear()
	_held = 0.0
	_flash_s = 0.0
	visible = true
	_cards.visible = false
	_title.text = title_text
	_show_step()
	queue_redraw()


func _show_step() -> void:
	var s: Dictionary = Baiting.strokes(kind)[stroke]
	_hint.text = "%d/%d · %s" % [stroke + 1, Baiting.strokes(kind).size(), tr(s["key"])]


## One compartment of the tackle box: the bait drawn large, its name, how
## many are in the bag, what it suits, or the rank that opens it.
func _card(o: Dictionary, current: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(206, 300)
	b.disabled = int(o["stock"]) <= 0 or o.has("locked")
	b.focus_mode = Control.FOCUS_NONE
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	b.set_meta("current", current)
	var art := _CardArt.new(String(o["kind"]), o.has("locked"))
	art.set_anchors_preset(Control.PRESET_TOP_WIDE)
	art.offset_top = 16.0
	art.offset_bottom = 126.0
	art.offset_left = 12.0
	art.offset_right = -12.0
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(art)
	var words := RichTextLabel.new()
	words.bbcode_enabled = true
	words.fit_content = true
	words.scroll_active = false
	words.add_theme_font_size_override("normal_font_size", 17)
	words.add_theme_color_override("default_color", UiTheme.ROPE)
	var names: Array[String] = []
	for key: String in Baiting.good_for(Db.database(), o):
		names.append(tr(key))
	var status := "[color=#e0b060]%s[/color]" % String(o["locked"]) if o.has("locked") else tr("BAIT_IN_BAG") % int(o["stock"])
	var suits := "" if names.is_empty() else "\n[font_size=14][color=#9fb4bd]%s[/color][/font_size]" % (tr("BAIT_GOOD_FOR") % ", ".join(names))
	words.text = "[center][b]%s[/b]\n%s%s[/center]" % [tr(o["name_key"]), status, suits]
	words.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	words.offset_left = 12.0
	words.offset_right = -12.0
	words.offset_top = -168.0
	words.offset_bottom = -12.0
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(words)
	b.pressed.connect(func() -> void: chosen.emit(o))
	b.mouse_entered.connect(queue_redraw)
	b.mouse_exited.connect(queue_redraw)
	return b


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_flash_s = maxf(_flash_s - delta, 0.0)
	if stage == "rig" and _touching:
		var s: Dictionary = Baiting.strokes(kind)[stroke]
		if s["type"] == "hold":
			_held += delta
			_samples.append(_finger)
			if Baiting.hold_score(s, _held, _samples)["finished"]:
				_end_stroke()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if stage != "rig":
		return
	# On a phone each touch also arrives as an emulated mouse event: take the
	# touch only, and only the finger that started (2026-11-21, stability).
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION:
		accept_event()
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _touch_index == -1:
			_touch_index = t.index
			press(to_work(t.position))
		elif not t.pressed and t.index == _touch_index:
			_touch_index = -1
			release()
		accept_event()
	elif event is InputEventMouseButton:
		if (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			press(to_work(event.position))
		else:
			release()
		accept_event()
	elif (event is InputEventScreenDrag and (event as InputEventScreenDrag).index == _touch_index) or (event is InputEventMouseMotion and _touching):
		move(to_work(event.position))
		accept_event()


## The thumb comes down at p (work units). A trace starts only near its start.
func press(p: Vector2) -> void:
	if not _rigging():
		return
	var s: Dictionary = Baiting.strokes(kind)[stroke]
	var point := p + (HOOK_OFFSET if s["type"] == "trace" else Vector2.ZERO)
	_finger = point
	if s["type"] == "trace":
		if _paused:
			if not Baiting.resumes_trace(s, _samples, point):
				_flash = tr("BAIT_RESUME")
				_flash_s = 1.2
				return
		elif not Baiting.starts_trace(s, point):
			_flash = tr("BAIT_START_HERE")
			_flash_s = 1.2
			return
	_touching = true
	if not _paused:
		_samples = [point]
	_paused = false
	_held = 0.0


func move(p: Vector2) -> void:
	if not _rigging():
		return
	var s: Dictionary = Baiting.strokes(kind)[stroke]
	var target := p + (HOOK_OFFSET if s["type"] == "trace" else Vector2.ZERO)
	_finger = Baiting.steady(_finger, target) if _touching else target
	if _touching and s["type"] == "trace":
		_samples.append(_finger)
		if Baiting.trace_score(s, _samples)["finished"]:
			_end_stroke()


func release() -> void:
	if not _rigging():
		return
	if not _touching:
		return
	_touching = false
	var s: Dictionary = Baiting.strokes(kind)[stroke]
	# Lifting the thumb pauses a trace: put it back where the point stopped
	# and carry on. A live fish slips and must be held again from the start.
	if s["type"] == "trace" and float(Baiting.trace_score(s, _samples)["progress"]) > 0.02:
		_paused = true
		_flash = tr("BAIT_RESUME")
		_flash_s = 1.2
	elif s["type"] == "hold":
		_held = 0.0
		_samples = []


## True while there is a stroke left to make.
func _rigging() -> bool:
	return visible and stage == "rig" and stroke < Baiting.strokes(kind).size()


func _end_stroke() -> void:
	var s: Dictionary = Baiting.strokes(kind)[stroke]
	var score: float = (Baiting.trace_score(s, _samples) if s["type"] == "trace" else Baiting.hold_score(s, _held, _samples))["score"]
	scores.append(score)
	_flash = tr(Baiting.rating_key(score))
	_flash_s = 1.0
	_touching = false
	_paused = false
	_samples = []
	_held = 0.0
	stroke += 1
	if stroke >= Baiting.strokes(kind).size():
		visible = false
		done.emit(Baiting.quality(scores))
	else:
		_show_step()


# ------------------------------------------------------------------ geometry

## The close-up's rectangle on screen: 1 unit wide, Baiting.ASPECT high.
func work_rect() -> Rect2:
	var w := minf(size.x - 80.0, (size.y - 150.0) / Baiting.ASPECT)
	w = maxf(w, 200.0)
	return Rect2(Vector2((size.x - w) * 0.5, 112.0), Vector2(w, w * Baiting.ASPECT))


func to_work(screen: Vector2) -> Vector2:
	var r := work_rect()
	return (screen - r.position) / r.size.x


func to_px(v: Vector2) -> Vector2:
	var r := work_rect()
	return r.position + v * r.size.x


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	# A wet board on the bridge rail, lit from above.
	draw_rect(Rect2(Vector2.ZERO, size), Color("0a1a24"))
	var r := work_rect()
	if stage == "choose":
		_draw_tackle_box()
		return
	var board := StyleBoxFlat.new()
	board.bg_color = Color("3a2b20")
	board.set_corner_radius_all(18)
	board.border_color = Color(UiTheme.BRASS, 0.35)
	board.set_border_width_all(2)
	board.shadow_color = Color(0, 0, 0, 0.5)
	board.shadow_size = 14
	draw_style_box(board, r.grow(14.0))
	for i in 7:
		var y := r.position.y + r.size.y * (float(i) + 0.5) / 7.0
		draw_line(Vector2(r.position.x - 10, y), Vector2(r.end.x + 10, y), Color(0, 0, 0, 0.18), 2.0)
	for i in 40:
		var x := r.position.x + r.size.x * fmod(float(i) * 0.6180339, 1.0)
		var y := r.position.y + r.size.y * fmod(float(i) * 0.7548776, 1.0)
		draw_circle(Vector2(x, y), 1.5 + fmod(float(i) * 0.37, 1.0) * 2.0, Color(0.7, 0.85, 0.95, 0.10))   # water drops
	var s := r.size.x
	match kind:
		"shrimp":
			_draw_shrimp(s)
		"live":
			_draw_fish(s)
		"soft_plastic":
			_draw_soft(s)
		"minnow":
			_draw_minnow(s)
		"sabiki":
			_draw_sabiki(s)
	_draw_guide(s)
	_draw_hook(s)
	if _flash_s > 0.0:
		var font := get_theme_default_font()
		var w := font.get_string_size(_flash, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		var at := Vector2(size.x * 0.5 - w * 0.5, r.end.y - 18.0)
		draw_string_outline(font, at, _flash, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 8, Color(0, 0, 0, 0.8))
		draw_string(font, at, _flash, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(UiTheme.ROPE, minf(_flash_s * 2.0, 1.0)))


## The choosing step: an open tackle box, its tray of compartments behind
## the cards, the chosen one lit in brass, a closed one sunk in shadow.
func _draw_tackle_box() -> void:
	if not _cards.visible or _cards.get_child_count() == 0:
		return
	var tray := Rect2(_cards.position, _cards.size).grow(26.0)
	var lid := Rect2(tray.position + Vector2(18, -64), Vector2(tray.size.x - 36, 52))
	var plastic := StyleBoxFlat.new()
	plastic.bg_color = Color("1d3b33")
	plastic.set_corner_radius_all(22)
	plastic.shadow_color = Color(0, 0, 0, 0.55)
	plastic.shadow_size = 18
	plastic.shadow_offset = Vector2(0, 8)
	draw_style_box(plastic, tray)
	# The lid stands open behind the tray, with its hinges.
	var lid_box := plastic.duplicate() as StyleBoxFlat
	lid_box.bg_color = Color("16302a")
	lid_box.shadow_size = 0
	lid_box.corner_radius_bottom_left = 4
	lid_box.corner_radius_bottom_right = 4
	draw_style_box(lid_box, lid)
	for hx: float in [0.2, 0.8]:
		var h := Vector2(lid.position.x + lid.size.x * hx, lid.end.y)
		draw_rect(Rect2(h + Vector2(-26, -6), Vector2(52, 12)), UiTheme.BRASS.darkened(0.25))
		draw_circle(h, 5.0, UiTheme.BRASS)
	draw_line(tray.position + Vector2(24, 2), Vector2(tray.end.x - 24, tray.position.y + 2), Color(1, 1, 1, 0.12), 2.0)   # the rim's light
	for c in _cards.get_children():
		var b := c as Button
		if b == null or b.is_queued_for_deletion():
			continue
		var cell := Rect2(b.position + _cards.position, b.size)
		var well := StyleBoxFlat.new()
		well.bg_color = Color("0f231e") if not b.disabled else Color("0b1916")
		well.set_corner_radius_all(14)
		well.border_color = Color(0, 0, 0, 0.6)
		well.border_width_top = 4   # the inner shadow under the rim
		well.border_width_left = 2
		if bool(b.get_meta("current", false)):
			well.border_color = UiTheme.BRASS
			well.set_border_width_all(4)
		elif b.is_hovered() and not b.disabled:
			well.border_color = Color(UiTheme.BRASS, 0.5)
			well.set_border_width_all(2)
		draw_style_box(well, cell)


## The current stroke's path as a faint dotted guide, with its start ringed.
func _draw_guide(s: float) -> void:
	if stroke >= Baiting.strokes(kind).size():
		return
	var st: Dictionary = Baiting.strokes(kind)[stroke]
	if st["type"] == "hold":
		var c := to_px(st["at"])
		var grow := clampf(_held / float(st["hold_s"]), 0.0, 1.0)
		draw_arc(c, float(st["tol"]) * s, 0.0, TAU, 40, Color(UiTheme.ROPE, 0.5), 2.0, true)
		if grow > 0.0:
			draw_arc(c, float(st["tol"]) * s, -PI * 0.5, -PI * 0.5 + TAU * grow, 40, UiTheme.BRASS, 5.0, true)
		return
	var path: Array = st["path"]
	for i in range(1, path.size()):
		var a := to_px(path[i - 1])
		var b := to_px(path[i])
		var n := int(a.distance_to(b) / 12.0) + 1
		for k in n:
			draw_circle(a.lerp(b, (float(k) + 0.5) / n), 2.0, Color(UiTheme.ROPE, 0.35))
	if not _touching:
		var pulse := 1.0 + 0.15 * sin(_t * 5.0)
		var ring: Vector2 = Baiting.resume_point(st, _samples) if _paused else path[0]
		draw_arc(to_px(ring), float(st["tol"]) * s * 1.4 * pulse, 0.0, TAU, 32, Color(UiTheme.BRASS, 0.8), 2.5, true)


## A forged J hook with its point at the thumb (or resting by the bait), the
## leader running up out of the frame. In local units the point leads along
## +x: a short arm back from the point, the round bend, and the long shank
## running forward past the point to the eye. Steel: dark rim, grey body,
## a bright edge where the sky catches it.
func _draw_hook(s: float) -> void:
	var st: Dictionary = Baiting.strokes(kind)[mini(stroke, Baiting.strokes(kind).size() - 1)]
	if st["type"] == "hold":
		return
	var path: Array = st["path"]
	var rest: Vector2 = Baiting.resume_point(st, _samples) if _paused else (path[0] as Vector2) + Vector2(-0.03, -0.04)
	var tip: Vector2 = _finger if _touching else rest
	# The point leads along the path where it is, as a hook is pushed through a bait.
	var dir := Baiting.tangent_at(path, float(Baiting.nearest_on(path, tip)["along"]))
	var pts := hook_points(to_px(tip), dir.angle(), s * 0.0026)
	var eye: Vector2 = pts[pts.size() - 1]
	draw_line(eye, Vector2(eye.x + 0.02 * s, -10.0), Color(0.85, 0.9, 0.95, 0.55), 1.5, true)   # the leader
	var w := maxf(s * 0.006, 3.0)
	draw_polyline(pts, Color(0.08, 0.09, 0.1), w + 2.5, true)
	draw_polyline(pts, Color(0.55, 0.59, 0.64), w, true)
	draw_polyline(pts, Color(0.9, 0.94, 1.0, 0.75), maxf(w * 0.3, 1.0), true)
	draw_arc(eye, w * 1.6, 0.0, TAU, 18, Color(0.08, 0.09, 0.1), 2.5, true)
	draw_arc(eye, w * 1.6, 0.0, TAU, 18, Color(0.62, 0.66, 0.72), 1.5, true)


## The hook's centreline in screen pixels, from the point to the eye.
static func hook_points(point: Vector2, angle: float, k: float) -> PackedVector2Array:
	var local := PackedVector2Array()
	local.append(Vector2(0, 0))
	local.append(Vector2(-5, 1.5))          # the barb's spine
	local.append(Vector2(-3, -4))           # the barb
	local.append(Vector2(-6, 1.5))
	for i in range(0, 11):                  # the short arm, then the round bend
		local.append(Vector2(-6 - 2.2 * i, 2.0 + 0.1 * i))
	var bend_c := Vector2(-30, 11)
	for i in range(0, 13):
		var a := -PI * 0.5 - PI * float(i) / 12.0
		local.append(bend_c + Vector2(cos(a), -sin(a)) * 9.0 * Vector2(1, -1))
	for i in range(1, 7):                   # the shank, forward past the point
		local.append(Vector2(-30 + 7.5 * i, 20))
	var out := PackedVector2Array()
	for v: Vector2 in local:
		out.append(point + (v * k).rotated(angle))
	return out


func _draw_shrimp(s: float) -> void:
	var peel := _stroke_done(0)
	var path: Array = Baiting.strokes("shrimp")[1]["path"]
	# The body: a tapered, translucent tube along the threading path, from
	# the tail (thin) to the head (thick), with a segment line every ninth.
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	var n := 24
	var centre: Array[Vector2] = []
	for i in n + 1:
		var t := float(i) / n
		var p := _along(path, t)
		var q := _along(path, minf(t + 0.02, 1.0)) if t < 1.0 else p + (p - _along(path, 0.98))
		var normal := (q - p).normalized().orthogonal()
		var rad := lerpf(0.018, 0.045, pow(t, 0.8)) * s
		top.append(p + normal * rad)
		bottom.append(p - normal * rad)
		centre.append(p)
	var outline := top.duplicate()
	for i in range(bottom.size() - 1, -1, -1):
		outline.append(bottom[i])
	var flesh := Color(0.9, 0.7, 0.64, 0.92)
	draw_colored_polygon(outline, flesh)
	draw_polyline(top, Color(0.98, 0.86, 0.8, 0.8), 2.0, true)       # light on the back
	draw_polyline(bottom, Color(0.62, 0.42, 0.38, 0.9), 2.0, true)
	for i in range(3, n, 3):                                          # the segments
		draw_line(top[i], bottom[i], Color(0.65, 0.45, 0.4, 0.6), 1.5, true)
	if not peel:                                                      # the tail's shell, until it is peeled
		var shell := PackedVector2Array()
		for i in range(0, 6):
			shell.append(top[i] + (top[i] - bottom[i]) * 0.08)
		for i in range(5, -1, -1):
			shell.append(bottom[i] - (top[i] - bottom[i]) * 0.08)
		draw_colored_polygon(shell, Color(0.78, 0.6, 0.55, 0.95))
		draw_polyline(shell, Color(0.45, 0.3, 0.28), 1.5, true)
	# Tail fan at the thin end.
	var tail: Vector2 = centre[0]
	var back := (centre[0] - centre[2]).normalized()
	for a: float in [-0.55, 0.0, 0.55]:
		var d := back.rotated(a)
		draw_colored_polygon(PackedVector2Array([tail, tail + d.rotated(-0.25) * 0.06 * s, tail + d.rotated(0.25) * 0.06 * s]), Color(0.8, 0.52, 0.46, 0.9))
	# Head: carapace, rostrum, eye, long antennae, legs under the body.
	var head: Vector2 = centre[n]
	var fwd := (centre[n] - centre[n - 2]).normalized()
	var cara := PackedVector2Array()
	for i in 14:
		var a := TAU * float(i) / 14.0
		cara.append(head + (Vector2(cos(a) * 0.055, sin(a) * 0.04) * s).rotated(fwd.angle()))
	draw_colored_polygon(cara, flesh.lightened(0.04))
	draw_line(head + fwd * 0.04 * s, head + fwd * 0.09 * s + fwd.orthogonal() * -0.01 * s, Color(0.8, 0.58, 0.52), 3.0, true)
	var eye := head + fwd * 0.03 * s + fwd.orthogonal() * -0.02 * s
	draw_circle(eye, 0.007 * s, Color(0.05, 0.05, 0.05))
	for bend: float in [-0.35, -0.15]:
		var ant := PackedVector2Array()
		for i in 8:
			ant.append(head + fwd.rotated(bend - 0.06 * i) * (0.04 + 0.03 * i) * s)
		draw_polyline(ant, Color(0.78, 0.55, 0.5, 0.75), 1.5, true)
	for i in range(6, n - 2, 3):
		var leg: Vector2 = bottom[i]
		draw_line(leg, leg + (bottom[i] - top[i]).normalized() * 0.025 * s + fwd * 0.008 * s, Color(0.75, 0.52, 0.47, 0.85), 1.5, true)
	if _stroke_done(1):
		var hp := PackedVector2Array()
		for p: Vector2 in centre:
			hp.append(p)
		draw_polyline(hp, Color(0.55, 0.6, 0.66, 0.45), 3.0, true)   # the hook shows through the shrimp


func _draw_fish(s: float) -> void:
	var calm := clampf(_held / 1.2, 0.0, 1.0) if stroke == 0 else 1.0
	var wr := sin(_t * 11.0) * 0.012 * (1.0 - calm)
	var c := Vector2(0.45, 0.33 + wr)
	var outline := PackedVector2Array()
	var colours := PackedColorArray()
	for i in 24:
		var a := TAU * float(i) / 24.0
		var v := Vector2(cos(a) * 0.25, sin(a) * 0.062 * (1.0 - 0.35 * maxf(cos(a), 0.0)))
		v.y += sin(v.x * 12.0 + _t * 9.0) * 0.006 * (1.0 - calm)
		outline.append(to_px(c + v))
		colours.append(Color(0.2, 0.38, 0.45) if v.y < 0.0 else Color(0.85, 0.88, 0.9))
	var tail := to_px(c + Vector2(0.25, 0.0))
	draw_colored_polygon(PackedVector2Array([tail, tail + Vector2(0.07, -0.06) * s, tail + Vector2(0.04, 0.0) * s, tail + Vector2(0.07, 0.06) * s]), Color(0.35, 0.45, 0.5))
	draw_polygon(outline, colours)
	var fin := to_px(c + Vector2(0.06, -0.055))
	draw_colored_polygon(PackedVector2Array([fin, fin + Vector2(0.04, -0.05) * s, fin + Vector2(0.1, 0.0) * s]), Color(0.25, 0.4, 0.48, 0.9))
	# The horse mackerel's row of scutes along the lateral line.
	for i in 14:
		var x := -0.18 + 0.03 * float(i)
		var p := to_px(c + Vector2(x, -0.005 + 0.012 * sin(x * 6.0)))
		draw_rect(Rect2(p - Vector2(3, 2), Vector2(6, 4)), Color(0.75, 0.8, 0.82, 0.8))
	var eye := to_px(c + Vector2(-0.19, -0.012))
	draw_circle(eye, 0.016 * s, Color(0.9, 0.9, 0.85))
	draw_circle(eye, 0.009 * s, Color(0.05, 0.05, 0.05))
	if stroke == 0:
		var thumb := to_px(Baiting.strokes("live")[0]["at"])
		if _touching:
			draw_circle(thumb, 0.045 * s, Color(0.93, 0.76, 0.62, 0.85))   # the thumb holding the fish
	if _stroke_done(1):
		draw_line(to_px(Vector2(0.56, 0.25)), to_px(Vector2(0.56, 0.29)), Color(0.6, 0.65, 0.7), 3.0, true)


func _draw_soft(s: float) -> void:
	var a := to_px(Vector2(0.27, 0.28))
	var b := to_px(Vector2(0.66, 0.29))
	var colour := Color(0.78, 0.92, 0.3, 0.92)
	draw_line(a, b, colour.darkened(0.25), 0.05 * s, true)
	draw_line(a, b, colour, 0.04 * s, true)
	for i in 12:
		var p := a.lerp(b, 0.35 + 0.05 * float(i))
		draw_line(p + Vector2(0, -0.02) * s, p + Vector2(0, 0.02) * s, colour.darkened(0.3), 2.0, true)   # the ribs
	draw_circle(a, 0.02 * s, colour)
	draw_colored_polygon(PackedVector2Array([b, b + Vector2(0.05, -0.04) * s, b + Vector2(0.07, 0.0) * s, b + Vector2(0.05, 0.04) * s]), colour.darkened(0.1))
	draw_line(a + Vector2(0, -0.01) * s, b + Vector2(0, -0.01) * s, Color(1, 1, 1, 0.25), 3.0, true)
	if _stroke_done(1):
		draw_line(a, to_px(Vector2(0.46, 0.28)), Color(0.55, 0.6, 0.66, 0.5), 3.0, true)


func _draw_minnow(s: float) -> void:
	var c := Vector2(0.64, 0.29)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in 20:
		var a := TAU * float(i) / 20.0
		var v := Vector2(cos(a) * 0.15, sin(a) * 0.05)
		pts.append(to_px(c + v))
		cols.append(Color(0.15, 0.35, 0.65) if v.y < 0.0 else Color(0.88, 0.9, 0.92))
	draw_polygon(pts, cols)
	var lip := to_px(c + Vector2(-0.15, 0.01))
	draw_colored_polygon(PackedVector2Array([lip, lip + Vector2(-0.05, 0.03) * s, lip + Vector2(-0.01, 0.04) * s]), Color(0.8, 0.85, 0.9, 0.6))
	draw_circle(to_px(c + Vector2(-0.1, -0.01)), 0.012 * s, Color(0.95, 0.8, 0.2))
	draw_circle(to_px(c + Vector2(-0.1, -0.01)), 0.006 * s, Color(0.05, 0.05, 0.05))
	draw_line(to_px(c + Vector2(-0.08, 0.04)), to_px(c + Vector2(-0.06, 0.045)), Color(0.85, 0.2, 0.2), 4.0, true)
	draw_arc(to_px(Vector2(0.49, 0.29)), 0.012 * s, 0.0, TAU, 16, Color(0.7, 0.72, 0.76), 3.0, true)   # the split ring
	for hx: float in [0.6, 0.72]:
		var h := to_px(Vector2(hx, 0.35))
		draw_arc(h, 0.012 * s, 0.0, PI, 10, Color(0.5, 0.52, 0.56), 2.0, true)
	# The snap: open after the first stroke, clipped after the second.
	var snap := to_px(Vector2(0.30, 0.30))
	draw_line(Vector2(snap.x, 0), snap, Color(0.85, 0.9, 0.95, 0.5), 1.5, true)
	draw_arc(snap, 0.014 * s, 0.0, TAU, 12, Color(0.7, 0.72, 0.76), 3.0, true)
	if _stroke_done(1):
		draw_line(snap, to_px(Vector2(0.49, 0.29)), Color(0.7, 0.72, 0.76), 3.0, true)


func _draw_sabiki(s: float) -> void:
	var line_end := to_px(Vector2(0.5, 0.42))
	if _stroke_done(0):
		draw_line(Vector2(line_end.x, 0), line_end, Color(0.85, 0.9, 0.95, 0.6), 1.5, true)
		for i in 5:
			var y := lerpf(0.05, 0.38, float(i) / 4.0)
			var p := to_px(Vector2(0.5, y))
			draw_line(p, p + Vector2(0.05, 0.02) * s, Color(0.85, 0.9, 0.95, 0.5), 1.0, true)
			_feather(p + Vector2(0.05, 0.02) * s, s)
	else:
		var tangle := PackedVector2Array()
		for i in 60:
			var a := float(i) * 0.53
			tangle.append(to_px(Vector2(0.5, 0.28) + Vector2(cos(a), sin(a * 1.3)) * (0.08 + 0.05 * sin(float(i)))))
		draw_polyline(tangle, Color(0.85, 0.9, 0.95, 0.55), 1.2, true)
		for i in 5:
			_feather(to_px(Vector2(0.5, 0.28) + Vector2.from_angle(float(i) * 1.3) * 0.09), s)
	var lead := to_px(Vector2(0.5, 0.52)) if _stroke_done(1) else to_px(Vector2(0.78, 0.48))
	draw_circle(lead, 0.03 * s, Color(0.35, 0.37, 0.4))
	draw_arc(lead, 0.03 * s, PI * 1.1, PI * 1.6, 10, Color(1, 1, 1, 0.3), 2.0, true)


func _feather(p: Vector2, s: float) -> void:
	draw_colored_polygon(PackedVector2Array([p, p + Vector2(0.03, -0.008) * s, p + Vector2(0.035, 0.008) * s]), Color(0.95, 0.4, 0.55, 0.9))
	draw_arc(p + Vector2(0.004, 0.006) * s, 0.008 * s, 0.0, PI, 8, Color(0.75, 0.78, 0.82), 1.5, true)


func _stroke_done(i: int) -> bool:
	return stroke > i


## The point t (0..1) along a path, in pixels.
func _along(path: Array, t: float) -> Vector2:
	var total := 0.0
	for i in range(1, path.size()):
		total += (path[i] as Vector2).distance_to(path[i - 1])
	var want := t * total
	for i in range(1, path.size()):
		var seg := (path[i] as Vector2).distance_to(path[i - 1])
		if want <= seg or i == path.size() - 1:
			return to_px((path[i - 1] as Vector2).lerp(path[i], clampf(want / maxf(seg, 1e-6), 0.0, 1.0)))
		want -= seg
	return to_px(path[0])


func _text(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", UiTheme.ROPE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A bait or lure laid in its compartment, drawn as it hangs from the rod
## (TerminalTackle), turned to lie flat; a padlock over it while closed.
class _CardArt extends Control:
	var kind := ""
	var locked := false

	func _init(bait_kind: String, is_locked: bool) -> void:
		kind = bait_kind
		locked = is_locked

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var look := kind
		var t := Time.get_ticks_msec() / 1000.0 * (0.0 if locked else 1.0)
		if look == "live":
			# The fish lies across its hook, so the hook hangs and the fish lies flat.
			TerminalTackle.draw(self, Vector2(size.x * 0.5, size.y * 0.12), look, size.y * 0.13, 0.0, t)
		else:
			var k := minf(size.x * 0.8 / TerminalTackle.extent_cm(look), size.y * 0.16)
			var right := Vector2(size.x * 0.5 + TerminalTackle.extent_cm(look) * k * 0.5, size.y * 0.5)
			TerminalTackle.draw(self, right, look, k, -PI * 0.5, t)
		if locked:
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.05, 0.06, 0.55))
			var c := size * 0.5
			draw_arc(c + Vector2(0, -10), 14.0, PI, TAU, 16, UiTheme.BRASS, 4.0, true)
			draw_rect(Rect2(c + Vector2(-20, -10), Vector2(40, 32)), UiTheme.BRASS)
			draw_circle(c + Vector2(0, 4), 4.0, Color(0.1, 0.1, 0.1))
