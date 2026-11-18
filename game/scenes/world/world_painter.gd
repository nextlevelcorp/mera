class_name WorldPainter
extends RefCounted
## Pixel-art drawing of the top-down world's objects (owner, 2026-11-18:
## Stardew Valley style, and it must be clear this is a real place). A
## three-quarter view: things are drawn upwards from the line where they meet
## the ground, so what stands further down the screen covers what is behind
## it. All sizes are in metres, snapped to whole pixels (16 px per metre),
## so the art stays crisp when the camera scales it up. Buildings and street
## furniture are design fills placed for recognition (the Galata Tower, the
## New Mosque, the Spice Bazaar, the T1 tram, the ferries), not survey data.

const PX := 16.0
const TEXT_SCALE := 3
const INK := Color(0.16, 0.11, 0.13)
const STONE := Color(0.86, 0.82, 0.72)
const LEAD := Color(0.5, 0.55, 0.6)
const GLASS := Color(0.22, 0.3, 0.4)
const CAR_COLOURS: Array[Color] = [Color(0.85, 0.2, 0.18), Color(0.95, 0.95, 0.92), Color(0.2, 0.3, 0.55), Color(0.95, 0.78, 0.15), Color(0.3, 0.3, 0.32), Color(0.6, 0.65, 0.7)]


## A rectangle in metres, snapped to the pixel grid.
static func box(ci: CanvasItem, x: float, y: float, w: float, h: float, c: Color) -> void:
	var a := Vector2(roundf(x * PX), roundf(y * PX))
	var b := Vector2(roundf((x + w) * PX), roundf((y + h) * PX))
	ci.draw_rect(Rect2(a, b - a), c)


## A rectangle with a one-pixel outline.
static func block(ci: CanvasItem, x: float, y: float, w: float, h: float, c: Color) -> void:
	box(ci, x, y, w, h, INK)
	var a := Vector2(roundf(x * PX) + 1.0, roundf(y * PX) + 1.0)
	var b := Vector2(roundf((x + w) * PX) - 1.0, roundf((y + h) * PX) - 1.0)
	ci.draw_rect(Rect2(a, b - a), c)


static func px_line(ci: CanvasItem, a_m: Vector2, b_m: Vector2, c: Color) -> void:
	ci.draw_line((a_m * PX).round() + Vector2(0.5, 0.5), (b_m * PX).round() + Vector2(0.5, 0.5), c, 1.0)


## Text on a sign, size in art pixels. The glyphs are drawn at screen
## resolution (TEXT_SCALE times larger, then scaled down), so signs stay
## readable when the camera magnifies the art.
static func label(ci: CanvasItem, centre_m: Vector2, text: String, size: int, c: Color) -> void:
	var font := ThemeDB.fallback_font
	var big := size * TEXT_SCALE
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, big).x / TEXT_SCALE
	var at := (centre_m * PX).round() + Vector2(-roundf(w * 0.5), roundf(size * 0.35))
	ci.draw_set_transform(at, 0.0, Vector2.ONE / TEXT_SCALE)
	ci.draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, big, c)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A soft dark oval where something stands.
static func shadow(ci: CanvasItem, foot_m: Vector2, w_m: float) -> void:
	var c := Color(0.05, 0.05, 0.12, 0.3)
	box(ci, foot_m.x - w_m * 0.5, foot_m.y - 0.12, w_m, 0.2, c)
	box(ci, foot_m.x - w_m * 0.35, foot_m.y - 0.18, w_m * 0.7, 0.32, c)


# --------------------------------------------------------------- road layer

## Lane lines, the tram tracks in the middle, kerbs and zebra crossings.
static func road(ci: CanvasItem, rect: Rect2, crossings: Array[Rect2]) -> void:
	var kerb := Color(0.62, 0.6, 0.56)
	box(ci, rect.position.x, rect.position.y, 0.25, rect.size.y, kerb)
	box(ci, rect.end.x - 0.25, rect.position.y, 0.25, rect.size.y, kerb)
	# The tram's own strip, raised and set off by kerbs.
	box(ci, 27.4, rect.position.y, 5.2, rect.size.y, Color(0.36, 0.34, 0.33))
	box(ci, 27.4, rect.position.y, 0.2, rect.size.y, kerb)
	box(ci, 32.4, rect.position.y, 0.2, rect.size.y, kerb)
	for x: float in Crowd.TRAM_TRACKS_X:
		for side in [-0.72, 0.72]:
			box(ci, x + side - 0.06, rect.position.y, 0.12, rect.size.y, Color(0.66, 0.66, 0.68))
		var y := rect.position.y
		while y < rect.end.y:
			box(ci, x - 0.95, y, 1.9, 0.18, Color(0.28, 0.25, 0.23))
			y += 0.75
	# Dashed lane lines.
	for x: float in [22.05, 37.95]:
		var y := rect.position.y
		while y < rect.end.y:
			box(ci, x - 0.06, y, 0.12, 1.5, Color(0.92, 0.92, 0.88))
			y += 3.5
	for c: Rect2 in crossings:
		box(ci, c.position.x, c.position.y, c.size.x, c.size.y, Color(0.3, 0.3, 0.33))
		var x := c.position.x + 0.3
		while x < c.end.x - 0.3:
			box(ci, x, c.position.y + 0.15, 0.5, c.size.y - 0.3, Color(0.92, 0.92, 0.88))
			x += 1.0


## The railing along the water: posts every metre and a green handrail.
static func rail(ci: CanvasItem, from_m: Vector2, to_m: Vector2) -> void:
	var y := from_m.y
	while y <= to_m.y:
		box(ci, from_m.x - 0.08, y - 0.7, 0.16, 0.7, Color(0.12, 0.2, 0.18))
		y += 1.0
	box(ci, from_m.x - 0.12, from_m.y - 0.85, 0.24, to_m.y - from_m.y + 0.2, Color(0.2, 0.36, 0.3))
	box(ci, from_m.x - 0.12, from_m.y - 0.85, 0.08, to_m.y - from_m.y + 0.2, Color(0.36, 0.55, 0.46))


## A fishing marker: a rope ring on the deck and a bobbing float above.
static func marker(ci: CanvasItem, pos_m: Vector2, facing: String, active: bool, t: float) -> void:
	var c := Color(1.0, 0.85, 0.3, 1.0 if active else 0.7)
	var dx := 1.0 if facing == "E" else -1.0
	for i in 12:
		var a := TAU * i / 12.0
		box(ci, pos_m.x + cos(a) * 0.7 - 0.06, pos_m.y + sin(a) * 0.4 - 0.06, 0.12, 0.12, c)
	var bob := roundf(sin(t * 3.0) * 2.0) / PX
	var at := pos_m + Vector2(dx * 1.6, -0.6 + bob)
	box(ci, at.x - 0.19, at.y - 0.25, 0.38, 0.25, Color(0.9, 0.2, 0.15))
	box(ci, at.x - 0.19, at.y, 0.38, 0.19, Color(0.95, 0.95, 0.92))
	box(ci, at.x - 0.03, at.y - 0.5, 0.06, 0.25, INK)


# ------------------------------------------------------------------ actors

## A person sprite standing with their feet at foot_m.
static func person(ci: CanvasItem, frames: Array[ImageTexture], foot_m: Vector2, facing: Vector2, phase: float, moving: bool) -> void:
	var dir := PixelArt.Dir.DOWN
	if absf(facing.x) > absf(facing.y):
		dir = PixelArt.Dir.RIGHT if facing.x > 0.0 else PixelArt.Dir.LEFT
	elif facing.y < 0.0:
		dir = PixelArt.Dir.UP
	var frame := 0
	if moving:
		frame = [1, 0, 2, 0][int(phase) % 4]
	shadow(ci, foot_m, 0.75)
	var at := (foot_m * PX).round() - Vector2(8, 23)
	ci.draw_texture(frames[dir * 3 + frame], at)


## An angler at the rail: the rod held out over the water, the line down to
## it, and a bucket beside them.
static func rod_out(ci: CanvasItem, foot_m: Vector2, facing: String, t: float) -> void:
	var dx := 1.0 if facing == "E" else -1.0
	var hand := foot_m + Vector2(dx * 0.35, -0.75)
	var sway := sin(t * 0.9 + foot_m.y) * 0.08
	var tip := foot_m + Vector2(dx * 2.6, -2.3 + sway)
	px_line(ci, hand, tip, Color(0.1, 0.09, 0.08))
	px_line(ci, hand + Vector2(0, 1.0 / PX), hand.lerp(tip, 0.3) + Vector2(0, 1.0 / PX), Color(0.45, 0.3, 0.18))
	px_line(ci, tip, foot_m + Vector2(dx * 3.0, 0.4), Color(0.9, 0.92, 0.95, 0.55))
	block(ci, foot_m.x - dx * 0.7 - 0.22, foot_m.y - 0.4, 0.44, 0.44, Color(0.3, 0.55, 0.75))


## A shopping kiosk, back half: wall and shelves behind the vendor.
static func kiosk_back(ci: CanvasItem, pos_m: Vector2, fish: bool) -> void:
	var x := pos_m.x - 2.4
	var y := pos_m.y - 1.2
	if not fish:
		# Rods for sale leaning against the side.
		for i in 4:
			px_line(ci, Vector2(x + 4.9 + i * 0.12, y + 1.0), Vector2(x + 5.2 + i * 0.25, y - 3.2), Color(0.15, 0.13, 0.12))
	block(ci, x + 0.1, y - 2.4, 4.6, 2.5, Color(0.5, 0.38, 0.28))
	for i in 3:
		box(ci, x + 0.3, y - 2.0 + i * 0.6, 4.2, 0.1, Color(0.36, 0.26, 0.2))
		for j in 7:
			var c: Color = Color(0.75, 0.8, 0.85) if fish else [Color(0.9, 0.5, 0.1), Color(0.2, 0.6, 0.3), Color(0.8, 0.2, 0.3), Color(0.3, 0.4, 0.8)][(i + j) % 4]
			box(ci, x + 0.45 + j * 0.58, y - 2.3 + i * 0.6, 0.32, 0.28, c)


## A shopping kiosk, front half: the counter with goods, the posts, the
## striped awning and the name board.
static func kiosk_front(ci: CanvasItem, pos_m: Vector2, fish: bool, name: String) -> void:
	var x := pos_m.x - 2.4
	var front := pos_m.y + 1.2
	shadow(ci, Vector2(pos_m.x, front), 5.0)
	# Counter top and front.
	block(ci, x, front - 2.0, 4.8, 1.0, Color(0.62, 0.48, 0.34))
	block(ci, x, front - 1.05, 4.8, 1.05, Color(0.5, 0.36, 0.25))
	for i in 4:
		box(ci, x + 0.3 + i * 1.15, front - 0.85, 0.06, 0.7, Color(0.4, 0.28, 0.2))
	if fish:
		box(ci, x + 0.2, front - 1.9, 4.4, 0.75, Color(0.85, 0.92, 0.96))
		for i in 6:
			var fx := x + 0.4 + i * 0.7
			box(ci, fx, front - 1.7 + (i % 2) * 0.25, 0.5, 0.18, Color(0.55, 0.62, 0.7))
			box(ci, fx + 0.5, front - 1.72 + (i % 2) * 0.25, 0.1, 0.22, Color(0.4, 0.46, 0.52))
	else:
		for i in 5:
			box(ci, x + 0.35 + i * 0.9, front - 1.6, 0.3, 0.35, [Color(0.9, 0.5, 0.1), Color(0.2, 0.6, 0.3), Color(0.8, 0.2, 0.3)][i % 3])
	# Posts and the striped awning above the vendor.
	box(ci, x, front - 4.6, 0.18, 2.7, INK)
	box(ci, x + 4.62, front - 4.6, 0.18, 2.7, INK)
	var stripe := Color(0.78, 0.2, 0.18) if fish else Color(0.15, 0.4, 0.62)
	box(ci, x - 0.3, front - 5.3, 5.4, 0.85, INK)
	for i in 9:
		box(ci, x - 0.24 + i * 0.6, front - 5.24, 0.6, 0.73, stripe if i % 2 == 0 else Color(0.95, 0.93, 0.88))
	for i in 9:
		box(ci, x - 0.24 + i * 0.6 + 0.1, front - 4.51, 0.4, 0.14, stripe if i % 2 == 0 else Color(0.95, 0.93, 0.88))
	block(ci, x + 0.6, front - 6.1, 3.6, 0.8, Color(0.96, 0.92, 0.8))
	label(ci, Vector2(pos_m.x, front - 5.7), name, 9, INK)


## A street lamp: a dark green post with two lanterns.
static func lamp(ci: CanvasItem, base_m: Vector2, lit: bool) -> void:
	shadow(ci, base_m, 0.5)
	box(ci, base_m.x - 0.18, base_m.y - 0.3, 0.36, 0.3, Color(0.12, 0.18, 0.16))
	box(ci, base_m.x - 0.08, base_m.y - 3.6, 0.16, 3.4, Color(0.14, 0.22, 0.2))
	box(ci, base_m.x - 0.7, base_m.y - 3.65, 1.4, 0.1, Color(0.14, 0.22, 0.2))
	var glass := Color(1.0, 0.86, 0.5) if lit else Color(0.82, 0.84, 0.8)
	for side in [-0.6, 0.6]:
		block(ci, base_m.x + side - 0.2, base_m.y - 3.55, 0.4, 0.5, glass)
		box(ci, base_m.x + side - 0.25, base_m.y - 3.7, 0.5, 0.12, Color(0.14, 0.22, 0.2))


## A simit cart: red, with a glass case of sesame rings, and its seller.
static func simit_cart(ci: CanvasItem, base_m: Vector2) -> void:
	shadow(ci, base_m + Vector2(0, 0.0), 1.8)
	box(ci, base_m.x - 0.75, base_m.y - 0.35, 0.3, 0.35, INK)
	box(ci, base_m.x + 0.45, base_m.y - 0.35, 0.3, 0.35, INK)
	block(ci, base_m.x - 0.9, base_m.y - 1.2, 1.8, 0.9, Color(0.8, 0.15, 0.12))
	block(ci, base_m.x - 0.85, base_m.y - 2.1, 1.7, 0.95, Color(0.8, 0.9, 0.92))
	for i in 3:
		for j in 2:
			var at := Vector2(base_m.x - 0.6 + i * 0.5, base_m.y - 1.95 + j * 0.42)
			box(ci, at.x, at.y, 0.32, 0.28, Color(0.72, 0.45, 0.2))
			box(ci, at.x + 0.1, at.y + 0.08, 0.12, 0.12, Color(0.8, 0.9, 0.92))
	box(ci, base_m.x - 0.95, base_m.y - 2.3, 1.9, 0.22, Color(0.8, 0.15, 0.12))


## The pigeons of the Eminönü square, pecking.
static func pigeons(ci: CanvasItem, area: Rect2, t: float, count: int) -> void:
	for i in count:
		var hx := fmod(float(i) * 7.31, 1.0)
		var hy := fmod(float(i) * 3.77, 1.0)
		var at := area.position + Vector2(hx, hy) * area.size + Vector2(sin(t * 0.3 + i) * 0.4, 0.0)
		var peck := 1.0 / PX if fmod(t * 1.5 + i * 0.37, 1.0) < 0.25 else 0.0
		box(ci, at.x - 0.15, at.y - 0.18, 0.3, 0.18, Color(0.55, 0.57, 0.62))
		box(ci, at.x + (0.12 if i % 2 == 0 else -0.24), at.y - 0.26 + peck, 0.12, 0.12, Color(0.38, 0.42, 0.48))


## A gull overhead, flapping, and its shadow on the ground below.
static func gull(ci: CanvasItem, at_m: Vector2, t: float, height_m: float) -> void:
	box(ci, at_m.x - 0.3, at_m.y + height_m, 0.6, 0.12, Color(0.05, 0.05, 0.12, 0.2))
	var up := fmod(t * 2.2, 1.0) < 0.5
	var w := Color(0.97, 0.97, 0.95)
	box(ci, at_m.x - 0.18, at_m.y - 0.06, 0.36, 0.18, w)
	box(ci, at_m.x - 0.62, at_m.y - (0.18 if up else -0.06), 0.45, 0.1, w)
	box(ci, at_m.x + 0.17, at_m.y - (0.18 if up else -0.06), 0.45, 0.1, w)
	box(ci, at_m.x - 0.62, at_m.y - (0.18 if up else -0.06), 0.1, 0.1, Color(0.2, 0.2, 0.22))
	box(ci, at_m.x + 0.52, at_m.y - (0.18 if up else -0.06), 0.1, 0.1, Color(0.2, 0.2, 0.22))
	box(ci, at_m.x + 0.12, at_m.y - 0.02, 0.1, 0.06, Color(0.95, 0.75, 0.2))


# ---------------------------------------------------------------- vehicles

## A T1 tram from above: two white cars with the red band, front at y.
static func tram(ci: CanvasItem, x: float, front_y: float, dir: float) -> void:
	var length := Crowd.TRAM_LENGTH_M
	var top := front_y if dir < 0.0 else front_y - length
	block(ci, x - 1.25, top, 2.5, length, Color(0.93, 0.93, 0.92))
	box(ci, x - 1.1, top + 0.3, 0.22, length - 0.6, Color(0.82, 0.12, 0.14))
	box(ci, x + 0.88, top + 0.3, 0.22, length - 0.6, Color(0.82, 0.12, 0.14))
	var y := top + 1.2
	while y < top + length - 1.5:
		box(ci, x - 0.85, y, 1.7, 0.9, Color(0.78, 0.8, 0.82))
		y += 2.4
	box(ci, x - 1.25, top + length * 0.5 - 0.1, 2.5, 0.2, INK)
	px_line(ci, Vector2(x - 0.6, top + length * 0.25), Vector2(x + 0.5, top + length * 0.25 - 0.9), INK)
	px_line(ci, Vector2(x - 0.6, top + length * 0.75), Vector2(x + 0.5, top + length * 0.75 - 0.9), INK)
	var nose := top + length - 1.0 if dir > 0.0 else top
	box(ci, x - 1.0, nose + 0.15, 2.0, 0.7, GLASS)


static func car(ci: CanvasItem, x: float, y: float, dir: float, colour: int) -> void:
	var c := CAR_COLOURS[colour % CAR_COLOURS.size()]
	var top := y - 2.1
	shadow(ci, Vector2(x + 0.2, y + 2.1), 1.9)
	block(ci, x - 0.9, top, 1.8, 4.2, c)
	box(ci, x - 0.7, top + (2.6 if dir > 0.0 else 0.6), 1.4, 0.8, GLASS)
	box(ci, x - 0.7, top + (0.5 if dir > 0.0 else 3.0), 1.4, 0.55, GLASS.lightened(0.15))
	box(ci, x - 0.7, top + 1.4, 1.4, 1.0, c.darkened(0.12))
	var lights := Color(1.0, 0.95, 0.75) if dir > 0.0 else Color(0.9, 0.2, 0.15)
	box(ci, x - 0.75, top + 3.95, 0.3, 0.15, lights)
	box(ci, x + 0.45, top + 3.95, 0.3, 0.15, lights)


## A city ferry: white hull, cream upper deck, black funnel; foam in its wake.
static func ferry(ci: CanvasItem, x: float, y: float, dir: float, t: float) -> void:
	for i in 10:
		var wx := x - dir * (8.0 + i * 1.3)
		var spread := 0.6 + i * 0.25
		var a := 0.7 - i * 0.06
		box(ci, wx, y - spread, 0.8, 0.2, Color(0.92, 0.96, 1.0, a))
		box(ci, wx, y + spread, 0.8, 0.2, Color(0.92, 0.96, 1.0, a))
	box(ci, x - 7.5, y - 2.0, 15.0, 4.6, Color(0.0, 0.05, 0.1, 0.25))
	block(ci, x - 7.0, y - 2.2, 14.0, 4.4, Color(0.96, 0.96, 0.94))
	box(ci, x + dir * 7.0 - 0.5, y - 1.4, 1.0, 2.8, Color(0.96, 0.96, 0.94))
	block(ci, x - 5.0, y - 1.7, 10.0, 3.0, Color(0.92, 0.88, 0.76))
	var wx := x - 4.6
	while wx < x + 4.4:
		box(ci, wx, y + 1.0, 0.5, 0.25, GLASS)
		box(ci, wx, y - 1.5, 0.5, 0.25, GLASS)
		wx += 0.9
	block(ci, x - dir * 1.5 - 0.6, y - 0.9, 1.2, 1.2, Color(0.12, 0.12, 0.12))
	box(ci, x - dir * 1.5 - 0.45, y - 0.75, 0.9, 0.25, Color(0.95, 0.75, 0.2))
	var puff := fmod(t * 0.7, 1.0)
	box(ci, x - dir * (1.5 + puff * 3.0) - 0.3, y - 1.4 - puff * 1.2, 0.6, 0.5, Color(0.8, 0.8, 0.82, 0.5 * (1.0 - puff)))


# --------------------------------------------------------------- buildings

## The city beyond the end of the area: sky and the far houses on the hill,
## from the top of the drawing down to the line y_m.
static func far_city(ci: CanvasItem, x0: float, x1: float, top_m: float, y_m: float, seed_value: int) -> void:
	box(ci, x0, top_m, x1 - x0, y_m - top_m, Color(0.66, 0.82, 0.92))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var x := x0
	while x < x1:
		var w := rng.randf_range(2.0, 4.0)
		var h := rng.randf_range(2.5, 5.5)
		var c := Color(0.62, 0.66, 0.74).lerp(Color(0.74, 0.7, 0.7), rng.randf())
		box(ci, x, y_m - h, minf(w, x1 - x), h, c)
		box(ci, x, y_m - h, minf(w, x1 - x), 0.3, c.darkened(0.12))
		var wy := y_m - h + 0.8
		while wy < y_m - 0.5:
			var wx := x + 0.4
			while wx < minf(x + w, x1) - 0.4:
				box(ci, wx, wy, 0.25, 0.3, c.darkened(0.2))
				wx += 0.7
			wy += 0.9
		x += w

## A row of Karaköy waterfront houses on a footprint, facades facing the
## bridge, shops on the ground floor.
static func house_row(ci: CanvasItem, footprint: Rect2, seed_value: int, sign_text: String) -> void:
	var colours: Array[Color] = [Color(0.86, 0.72, 0.5), Color(0.9, 0.78, 0.74), Color(0.93, 0.9, 0.8), Color(0.66, 0.78, 0.82), Color(0.8, 0.6, 0.45)]
	var front := footprint.end.y
	var x := footprint.position.x
	var i := seed_value
	while x < footprint.end.x - 0.5:
		var w := minf(4.0 + float(i % 3), footprint.end.x - x)
		var h := 4.6 + float(i % 2) * 0.8
		var c := colours[i % colours.size()]
		# Roof and facade.
		block(ci, x, front - h - 1.2, w, 1.4, Color(0.62, 0.3, 0.22))
		box(ci, x + 0.06, front - h - 0.4, w - 0.12, 0.2, Color(0.5, 0.24, 0.18))
		block(ci, x, front - h, w, h, c)
		# Upper windows.
		var wx := x + 0.6
		while wx < x + w - 0.9:
			for row in 2:
				block(ci, wx, front - h + 0.5 + row * 1.2, 0.6, 0.85, GLASS)
				box(ci, wx - 0.08, front - h + 1.33 + row * 1.2, 0.76, 0.1, c.darkened(0.25))
			wx += 1.2
		# Shop front with an awning.
		block(ci, x + 0.3, front - 1.6, w - 0.6, 1.6, Color(0.3, 0.26, 0.24))
		box(ci, x + 0.45, front - 1.45, w - 0.9, 0.9, GLASS.lightened(0.2))
		var aw := Color(0.2, 0.45, 0.35) if i % 2 == 0 else Color(0.75, 0.22, 0.2)
		box(ci, x + 0.2, front - 2.0, w - 0.4, 0.45, aw)
		x += w
		i += 1
	if sign_text != "":
		var mid := Vector2(footprint.get_center().x, front - 2.6)
		block(ci, mid.x - 3.0, mid.y - 0.45, 6.0, 0.9, Color(0.1, 0.25, 0.5))
		label(ci, mid, sign_text, 9, Color(1, 1, 1))


## The Galata Tower: a round stone tower with a gallery and a conical cap.
static func galata_tower(ci: CanvasItem, base_m: Vector2) -> void:
	var w := 3.4
	var body := 6.0
	var x := base_m.x - w * 0.5
	var top := base_m.y - body
	block(ci, x, top, w, body, Color(0.78, 0.72, 0.6))
	# Rounded shading: light on the left, dark on the right.
	box(ci, x + 0.1, top + 0.1, 0.5, body - 0.2, Color(0.86, 0.8, 0.68))
	box(ci, x + w - 0.8, top + 0.1, 0.7, body - 0.2, Color(0.62, 0.56, 0.46))
	# Stone courses and small windows.
	for i in 5:
		box(ci, x + 0.1, top + 1.0 + i * 1.0, w - 0.2, 0.06, Color(0.66, 0.6, 0.5))
	for i in 2:
		block(ci, base_m.x - 0.2, top + 1.6 + i * 1.5, 0.4, 0.7, INK)
	# Gallery with arches.
	block(ci, x - 0.2, top - 0.9, w + 0.4, 1.0, Color(0.7, 0.64, 0.54))
	for i in 5:
		box(ci, x + 0.1 + i * 0.75, top - 0.7, 0.4, 0.6, INK)
	box(ci, x - 0.3, top + 0.05, w + 0.6, 0.15, Color(0.55, 0.5, 0.42))
	# The cone.
	var cone := 2.2
	for i in 12:
		var share := float(i) / 12.0
		var cw := (w + 0.3) * (1.0 - share)
		box(ci, base_m.x - cw * 0.5, top - 0.9 - (i + 1) * cone / 12.0, cw, cone / 12.0 + 0.02, Color(0.32, 0.36, 0.42).lerp(Color(0.42, 0.46, 0.52), 0.5 + 0.5 * sin(i)))
	box(ci, base_m.x - 0.05, top - 0.9 - cone - 0.6, 0.1, 0.6, Color(0.85, 0.7, 0.3))


## The New Mosque (Yeni Cami) at Eminönü: a stone hall, the great lead dome
## with half domes, and two minarets with balconies.
static func mosque(ci: CanvasItem, footprint: Rect2) -> void:
	var front := footprint.end.y
	var cx := footprint.get_center().x
	var wall := 3.6
	# Minarets behind the hall at both corners.
	for mx: float in [footprint.position.x + 0.8, footprint.end.x - 0.8]:
		block(ci, mx - 0.4, front - 13.5, 0.8, 13.5, STONE)
		box(ci, mx + 0.1, front - 13.4, 0.2, 13.3, STONE.darkened(0.12))
		for by: float in [front - 9.0, front - 11.4]:
			block(ci, mx - 0.65, by, 1.3, 0.35, STONE.darkened(0.08))
		for i in 6:
			var cw := 0.8 * (1.0 - float(i) / 6.0)
			box(ci, mx - cw * 0.5, front - 13.5 - (i + 1) * 0.3, cw, 0.32, LEAD)
		box(ci, mx - 0.04, front - 15.6, 0.08, 0.35, Color(0.85, 0.7, 0.3))
	# Domes, stepped as pixel art: two half domes, then the main one.
	for d: Array in [[cx - 4.6, 2.2], [cx + 4.6, 2.2], [cx, 4.2]]:
		var dx: float = d[0]
		var r: float = d[1]
		var base := front - wall - (0.6 if r > 3.0 else 0.0)
		box(ci, dx - r - 0.2, base - 0.5, 2.0 * r + 0.4, 0.6, STONE.darkened(0.06))
		var steps := int(r * 4.0)
		for i in steps:
			var h := float(i + 1) / steps
			var cw := 2.0 * r * sqrt(maxf(1.0 - h * h, 0.0))
			box(ci, dx - cw * 0.5, base - 0.5 - (i + 1) * r * 0.75 / steps, cw, r * 0.75 / steps + 0.03, LEAD.lightened(0.18 * (1.0 - h) if i % 3 != 0 else 0.0))
		box(ci, dx - r * 0.5, base - 0.5 - r * 0.45, r * 0.25, 0.12, LEAD.lightened(0.35))
		box(ci, dx - 0.04, base - 0.5 - r * 0.75 - 0.5, 0.08, 0.5, Color(0.85, 0.7, 0.3))
	# The hall: stone, a row of arched windows, the portico.
	block(ci, footprint.position.x + 1.4, front - wall, footprint.size.x - 2.8, wall, STONE)
	box(ci, footprint.position.x + 1.5, front - wall + 0.1, footprint.size.x - 3.0, 0.2, STONE.lightened(0.1))
	var x := footprint.position.x + 2.2
	while x < footprint.end.x - 2.4:
		block(ci, x, front - wall + 0.7, 0.6, 1.0, GLASS)
		box(ci, x + 0.1, front - wall + 0.6, 0.4, 0.12, GLASS)
		x += 1.3
	for i in 7:
		var ax := cx - 4.2 + i * 1.4
		box(ci, ax, front - 1.5, 0.25, 1.5, STONE.darkened(0.15))
	box(ci, cx - 4.4, front - 1.7, 9.0, 0.25, STONE.darkened(0.08))
	box(ci, cx - 4.2, front - 1.45, 8.6, 1.45, Color(0.4, 0.34, 0.3, 0.55))


## The Spice Bazaar beside it: a long stone hall with small domes and a gate.
static func bazaar(ci: CanvasItem, footprint: Rect2, sign_text: String) -> void:
	var front := footprint.end.y
	var wall := 3.2
	var x := footprint.position.x + 0.8
	while x < footprint.end.x - 1.2:
		var steps := 4
		for i in steps:
			var cw := 1.6 * sqrt(1.0 - pow(float(i + 1) / steps, 2.0))
			box(ci, x + 0.8 - cw * 0.5, front - wall - 0.2 - (i + 1) * 0.25, cw, 0.27, LEAD)
		x += 2.0
	block(ci, footprint.position.x, front - wall, footprint.size.x, wall, Color(0.82, 0.68, 0.52))
	for i in int(footprint.size.x / 1.6):
		var wx := footprint.position.x + 0.6 + i * 1.6
		box(ci, wx, front - wall + 0.5, 0.15, wall - 0.5, Color(0.75, 0.55, 0.42))
	var gx := footprint.get_center().x
	block(ci, gx - 1.4, front - wall - 0.8, 2.8, wall + 0.8, Color(0.86, 0.74, 0.58))
	block(ci, gx - 0.8, front - 2.4, 1.6, 2.4, Color(0.3, 0.2, 0.15))
	box(ci, gx - 0.6, front - 2.6, 1.2, 0.25, Color(0.3, 0.2, 0.15))
	for i in 6:
		box(ci, footprint.position.x + 1.0 + i * 0.5, front - 0.9, 0.4, 0.4, [Color(0.85, 0.35, 0.1), Color(0.9, 0.7, 0.2), Color(0.55, 0.25, 0.15)][i % 3])
		box(ci, footprint.end.x - 4.0 + i * 0.5, front - 0.9, 0.4, 0.4, [Color(0.6, 0.15, 0.1), Color(0.85, 0.55, 0.2), Color(0.4, 0.5, 0.2)][i % 3])
	if sign_text != "":
		block(ci, gx - 3.0, front - wall - 1.8, 6.0, 0.9, Color(0.35, 0.2, 0.12))
		label(ci, Vector2(gx, front - wall - 1.35), sign_text, 9, Color(1.0, 0.92, 0.7))


## A blue place-name sign on two posts, as the city uses.
static func place_sign(ci: CanvasItem, base_m: Vector2, text: String) -> void:
	shadow(ci, base_m, 2.4)
	box(ci, base_m.x - 1.1, base_m.y - 1.6, 0.15, 1.6, Color(0.4, 0.42, 0.45))
	box(ci, base_m.x + 0.95, base_m.y - 1.6, 0.15, 1.6, Color(0.4, 0.42, 0.45))
	block(ci, base_m.x - 1.8, base_m.y - 2.6, 3.6, 1.1, Color(0.1, 0.3, 0.62))
	box(ci, base_m.x - 1.65, base_m.y - 2.45, 3.3, 0.06, Color(1, 1, 1, 0.8))
	label(ci, base_m + Vector2(0, -2.05), text, 9, Color(1, 1, 1))
