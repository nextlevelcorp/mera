class_name BaitPanel
extends Control
## The baiting screen (roadmap R20): the steps of Baiting for one kind of bait,
## each a needle swinging over a bar with a target zone. A tap anywhere (or the
## Tap button) takes the step; after the last one the panel closes and emits
## done(quality). Owns only the timing and the drawing; Baiting scores.

signal done(quality: float)

var kind := ""
var step := 0
var accuracies: Array[float] = []
var _t := 0.0
var _title: Label
var _hint: Label
var _bar: Control
var _last := -1.0   ## the last tap's accuracy, flashed on the bar


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.05, 0.08, 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.custom_minimum_size = Vector2(760, 0)
	box.add_theme_constant_override("separation", 18)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_title = _text(34)
	box.add_child(_title)
	_hint = _text(24)
	box.add_child(_hint)
	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(760, 96)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	box.add_child(_bar)
	var tap := Button.new()
	tap.text = tr("BAIT_TAP")
	tap.theme_type_variation = UiTheme.PRIMARY
	tap.add_theme_font_size_override("font_size", 30)
	tap.custom_minimum_size = Vector2(0, 110)
	tap.pressed.connect(press)
	box.add_child(tap)


func start(bait_kind: String, title_text: String) -> void:
	kind = bait_kind
	step = 0
	accuracies.clear()
	_t = 0.0
	_last = -1.0
	_title.text = title_text
	visible = true
	_show_step()


## Takes the current step at the needle's position now.
func press() -> void:
	if not visible:
		return
	var s: Array = Baiting.steps(kind)[step]
	var a := Baiting.accuracy(needle(), Baiting.zone_centre(step), float(s[1]))
	accuracies.append(a)
	_last = a
	step += 1
	_t = 0.0
	if step >= Baiting.steps(kind).size():
		visible = false
		done.emit(Baiting.quality(accuracies))
	else:
		_show_step()


func needle() -> float:
	return Baiting.needle(_t, float(Baiting.steps(kind)[step][2]))


func _show_step() -> void:
	var s: Array = Baiting.steps(kind)[step]
	_hint.text = "%d/%d · %s" % [step + 1, Baiting.steps(kind).size(), tr(s[0])]
	_bar.queue_redraw()


func _process(delta: float) -> void:
	if visible:
		_t += delta
		_bar.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	# A tap anywhere on the shade also takes the step.
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
		press()
		accept_event()


func _draw_bar() -> void:
	if kind == "" or step >= Baiting.steps(kind).size():
		return
	var s: Array = Baiting.steps(kind)[step]
	var size := _bar.size
	var track := Rect2(Vector2(0, size.y * 0.35), Vector2(size.x, size.y * 0.3))
	_bar.draw_rect(track, Color(1, 1, 1, 0.12))
	var c := Baiting.zone_centre(step)
	var w := float(s[1])
	_bar.draw_rect(Rect2(Vector2((c - w) * size.x, track.position.y), Vector2(2.0 * w * size.x, track.size.y)), Color(0.36, 0.78, 0.5, 0.55))
	_bar.draw_rect(Rect2(Vector2((c - w * 0.35) * size.x, track.position.y), Vector2(0.7 * w * size.x, track.size.y)), Color(0.5, 0.95, 0.6, 0.7))
	var x := needle() * size.x
	_bar.draw_line(Vector2(x, 0), Vector2(x, size.y), Color(1.0, 0.84, 0.4), 6.0)


func _text(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
