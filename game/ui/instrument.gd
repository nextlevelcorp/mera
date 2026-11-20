class_name Instrument
extends Control
## The look of a fishing control (owner, 2026-11-20: "the fishing buttons are
## still not good"; direction in docs/design/tide_instruments.md). It only
## draws: the control it sits in keeps every input and rule. Each kind has the
## shape of the motion it asks for: the cast dial fills clockwise with power,
## the reel shows its speed scale and a turning crank, the drag lever has
## detents and a red last fifth, the pull well has the steer arrows, and a
## glyph is the small engraved sign on a secondary key. State is shown by
## shape and position as well as colour (PRD F8, F18).

enum Kind { DIAL, REEL, LEVER, WELL, GLYPH }

const TICKS_DIAL := 48
const BEST_RELEASE := 0.9   ## the top band of the power swing, as in FishingScreen.power_at

var kind: Kind
var caption := ""
var value := 0.0       ## dial: cast power 0..1; reel: speed 0..1; lever: drag 0..1
var spin := 0.0        ## reel: crank angle (radians)
var steer := 0.0       ## well: -1..1 while pressed
var pressed := false
var alert := false     ## dial: a take is on, strike now
var glyph := ""        ## GLYPH: back, rig, log, reel_in, speed, settings
var thumb_y := -1.0    ## reel: where the thumb is, in the control's pixels (-1: none)
var time_s := 0.0


func _init(instrument_kind: Kind, text: String = "") -> void:
	kind = instrument_kind
	caption = text
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	match kind:
		Kind.DIAL:
			_draw_dial()
		Kind.REEL:
			_draw_reel()
		Kind.LEVER:
			_draw_lever()
		Kind.WELL:
			_draw_well()
		Kind.GLYPH:
			_draw_glyph(size * 0.5, minf(size.x, size.y) * 0.5)


## The radius of the dial's face inside a w x h control, leaving room for
## its outer ring and ticks. Pure, for the tests.
static func dial_radius(w: float, h: float) -> float:
	return maxf(minf(w, h) * 0.5 - 20.0, 8.0)


## How far round the dial the power arc reaches (radians from the top).
static func power_sweep(power: float) -> float:
	return TAU * clampf(power, 0.0, 1.0)


func _draw_dial() -> void:
	var c := size * 0.5
	var r := dial_radius(size.x, size.y)
	var face := UiTheme.SIGNAL if alert else UiTheme.BRASS
	var rim := face.darkened(0.35)
	if pressed:
		c.y += 3.0
	# Shadow, lip and face: a raised disc that sinks when pressed.
	draw_circle(c + Vector2(0, 6), r, Color(0, 0, 0, 0.35))
	draw_circle(c + Vector2(0, 0 if pressed else 4), r, rim)
	draw_circle(c, r - 2.0, face)
	draw_circle(c + Vector2(0, -r * 0.18), r * 0.72, Color(1, 0.96, 0.85, 0.10))
	# Outer ring of ticks, a major every fourth, and the best-release band.
	var ring := r + 12.0
	for i in TICKS_DIAL:
		var a := -PI * 0.5 + TAU * float(i) / TICKS_DIAL
		var inner := ring + (2.0 if i % 4 else -2.0)
		draw_line(c + Vector2.from_angle(a) * inner, c + Vector2.from_angle(a) * (ring + 8.0), Color(UiTheme.BRASS, 0.55), 1.5, true)
	draw_arc(c, ring + 4.0, -PI * 0.5 + TAU * BEST_RELEASE, PI * 1.5, 24, Color(UiTheme.ROPE, 0.35), 6.0, true)
	if value > 0.0:
		var end := -PI * 0.5 + power_sweep(value)
		draw_arc(c, ring + 4.0, -PI * 0.5, end, 64, UiTheme.ROPE, 5.0, true)
		draw_circle(c + Vector2.from_angle(end) * (ring + 4.0), 6.0, UiTheme.ROPE)
	_caption(c + Vector2(0, -4), caption, int(r * 0.34), UiTheme.SEA_DEEP)


func _draw_reel() -> void:
	var body := Rect2(Vector2(10, 10), size - Vector2(20, 20))
	_glass(body, 28.0)
	var c := Vector2(size.x * 0.56, size.y * 0.56)
	var r := minf(size.x * 0.34, size.y * 0.28)
	# Speed scale on the left: up is faster, as the thumb moves.
	var x := body.position.x + 22.0
	var top := body.position.y + 56.0
	var bottom := body.end.y - 24.0
	for i in 11:
		var y := lerpf(bottom, top, float(i) / 10.0)
		draw_line(Vector2(x, y), Vector2(x + (18.0 if i % 5 == 0 else 10.0), y), Color(UiTheme.ROPE, 0.55), 2.0, true)
	if thumb_y >= 0.0:
		var ty := clampf(thumb_y, top, bottom)
		draw_line(Vector2(x - 4, ty), Vector2(x + 30, ty), UiTheme.BRASS, 5.0, true)
	# The crank: a wheel that turns at the reel's speed.
	draw_circle(c, r, Color(UiTheme.SEA_DEEP, 0.55))
	draw_arc(c, r, 0.0, TAU, 48, Color(UiTheme.BRASS, 0.6), 2.5, true)
	for i in 16:
		var a := spin + TAU * float(i) / 16.0
		draw_line(c + Vector2.from_angle(a) * (r - 10.0), c + Vector2.from_angle(a) * (r - 3.0), Color(UiTheme.ROPE, 0.4), 1.5, true)
	var knob := c + Vector2.from_angle(spin) * (r - 26.0)
	draw_line(c, knob, UiTheme.BRASS, 8.0, true)
	draw_circle(c, 12.0, UiTheme.BRASS)
	draw_circle(c, 4.0, UiTheme.SEA_DEEP)
	draw_circle(knob + Vector2(0, 3), 17.0, Color(0, 0, 0, 0.35))
	draw_circle(knob, 17.0, UiTheme.BRASS if not pressed else UiTheme.BRASS.lightened(0.2))
	_caption(Vector2(size.x * 0.5, body.position.y + 26.0), caption, 22, UiTheme.ROPE)


func _draw_lever() -> void:
	var track := Rect2(Vector2(size.x * 0.5 - 22.0, 52.0), Vector2(44.0, size.y - 74.0))
	_glass(track, 22.0)
	var top := track.position.y + 18.0
	var bottom := track.end.y - 18.0
	draw_line(Vector2(track.get_center().x, top), Vector2(track.get_center().x, bottom), Color(UiTheme.ROPE, 0.25), 3.0)
	for i in 11:
		var y := lerpf(bottom, top, float(i) / 10.0)
		var col := Color(UiTheme.SIGNAL, 0.9) if i >= 8 else Color(UiTheme.ROPE, 0.55)
		draw_line(Vector2(track.end.x + 4.0, y), Vector2(track.end.x + (16.0 if i % 5 == 0 else 9.0), y), col, 2.0, true)
	draw_rect(Rect2(Vector2(track.end.x + 1.0, top), Vector2(3.0, (bottom - top) * 0.2)), Color(UiTheme.SIGNAL, 0.8))
	var ky := lerpf(bottom, top, clampf(value, 0.0, 1.0))
	var knob := Rect2(Vector2(track.position.x - 12.0, ky - 16.0), Vector2(track.size.x + 24.0, 32.0))
	draw_rect(Rect2(knob.position + Vector2(0, 4), knob.size), Color(0, 0, 0, 0.35))
	var box := StyleBoxFlat.new()
	box.bg_color = UiTheme.BRASS
	box.border_color = UiTheme.BRASS_DARK
	box.set_border_width_all(2)
	box.set_corner_radius_all(10)
	box.anti_aliasing = true
	draw_style_box(box, knob)
	for dy: float in [-7.0, 0.0, 7.0]:
		draw_line(Vector2(knob.position.x + 14.0, ky + dy), Vector2(knob.end.x - 14.0, ky + dy), UiTheme.BRASS_DARK, 2.0)
	_caption(Vector2(size.x * 0.5, 24.0), caption, 22, UiTheme.ROPE)


func _draw_well() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 6.0
	draw_circle(c + Vector2(0, 6), r, Color(0, 0, 0, 0.35))
	draw_circle(c, r, Color(UiTheme.SEA_MID, 0.88))
	draw_arc(c, r, 0.0, TAU, 64, Color(UiTheme.BRASS, 0.6 if not pressed else 1.0), 3.0, true)
	for k in range(1, 5):
		draw_arc(c, r - 16.0 * k, 0.0, TAU, 48, Color(UiTheme.ROPE, 0.06 + 0.03 * k), 1.5, true)
	var hub := c + Vector2(steer * r * 0.45, 0.0)
	draw_circle(hub, r * 0.26, Color(UiTheme.ROPE, 0.45 if pressed else 0.18))
	# Steer arrows at the two outer thirds (FightController.steer_from_pad).
	for side: float in [-1.0, 1.0]:
		var tip := c + Vector2(side * (r - 14.0), 0.0)
		var lit := pressed and signf(steer) == side
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-side * 20.0, -14.0), tip + Vector2(-side * 20.0, 14.0)]), UiTheme.BRASS if lit else Color(UiTheme.BRASS, 0.55))
	_caption(c + Vector2(0, r * 0.55), caption, 24, UiTheme.ROPE)


## The engraved sign of a secondary key, inside a thin ring.
func _draw_glyph(c: Vector2, r: float) -> void:
	var g := UiTheme.BRASS
	draw_arc(c, r - 2.0, 0.0, TAU, 40, Color(UiTheme.BRASS, 0.45), 2.0, true)
	var s := r * 0.42
	match glyph:
		"back":
			draw_line(c + Vector2(s, 0), c - Vector2(s, 0), g, 3.0, true)
			draw_polyline(PackedVector2Array([c + Vector2(-s * 0.2, -s * 0.8), c - Vector2(s, 0), c + Vector2(-s * 0.2, s * 0.8)]), g, 3.0, true)
		"rig":
			draw_line(c + Vector2(-s, s), c + Vector2(s, -s), g, 3.0, true)
			draw_circle(c + Vector2(-s * 0.45, s * 0.45), s * 0.38, g)
		"log":
			draw_rect(Rect2(c - Vector2(s * 0.8, s), Vector2(s * 1.6, s * 2.0)), g, false, 2.5)
			for dy: float in [-0.45, 0.0, 0.45]:
				draw_line(c + Vector2(-s * 0.45, s * dy), c + Vector2(s * 0.45, s * dy), g, 2.0)
		"reel_in":
			draw_arc(c, s, 0.0, TAU, 32, g, 3.0, true)
			draw_circle(c, s * 0.3, g)
		"speed":
			for dx: float in [-0.9, 0.1]:
				var o := c + Vector2(s * dx, 0)
				draw_colored_polygon(PackedVector2Array([o + Vector2(0, -s * 0.8), o + Vector2(s * 0.85, 0), o + Vector2(0, s * 0.8)]), g)
		"hook":
			draw_arc(c + Vector2(0, s * 0.25), s * 0.5, 0.0, PI, 16, g, 3.0, true)
			draw_line(c + Vector2(s * 0.5, s * 0.25), c + Vector2(s * 0.5, -s * 0.9), g, 3.0, true)
			draw_line(c + Vector2(-s * 0.5, s * 0.25), c + Vector2(-s * 0.5, -s * 0.15), g, 3.0, true)
		"settings":
			draw_arc(c, s * 0.55, 0.0, TAU, 24, g, 3.0, true)
			for i in 6:
				var a := TAU * float(i) / 6.0
				draw_line(c + Vector2.from_angle(a) * s * 0.7, c + Vector2.from_angle(a) * s * 1.05, g, 3.0, true)


func _glass(rect: Rect2, radius: float) -> void:
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0, 0, 0, 0.3)
	shadow.set_corner_radius_all(int(radius))
	draw_style_box(shadow, Rect2(rect.position + Vector2(0, 5), rect.size))
	var b := StyleBoxFlat.new()
	b.bg_color = Color(UiTheme.SEA_MID, 0.88)
	b.border_color = Color(UiTheme.BRASS, 0.75 if pressed else 0.45)
	b.set_border_width_all(2)
	b.set_corner_radius_all(int(radius))
	b.anti_aliasing = true
	draw_style_box(b, rect)


func _caption(centre: Vector2, text: String, font_size: int, color: Color) -> void:
	if text == "":
		return
	var font := get_theme_default_font()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, centre + Vector2(-w * 0.5, font_size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
