class_name UiTheme
extends RefCounted
## The game's controls (roadmap R21): one Theme set on the root window, so
## every button, panel and slider shares it. The palette comes from the
## scene: night-sea blue for panels and keys, the brass of a reel's fittings
## for edges and the one primary action, rope-cream text, stone for what is
## not available, a signal red for danger. Keys look like hardware: a raised
## lower edge that sinks when pressed.

const SEA_DEEP := Color("0d2433")
const SEA_MID := Color("17384a")
const BRASS := Color("d1a957")
const BRASS_DARK := Color("8d6d2c")
const ROPE := Color("f3e9d2")
const STONE := Color("8a939a")
const SIGNAL := Color("e0604a")

## The type variation for the one main action of a screen (Cast, Fish here, Tap).
const PRIMARY := &"PrimaryButton"
const RADIUS := 16


## Merges the look into the engine's default theme, the fallback of every
## control, so it reaches controls under a CanvasLayer too (the world HUD).
static func install() -> void:
	ThemeDB.get_default_theme().merge_with(make())


static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 24
	_buttons(t, &"Button", Color(SEA_MID, 0.9), ROPE, Color(SEA_DEEP, 0.95), Color(BRASS, 0.7))
	_buttons(t, PRIMARY, BRASS, SEA_DEEP, BRASS_DARK, BRASS_DARK.darkened(0.2))
	t.set_type_variation(PRIMARY, &"Button")
	t.set_color(&"font_color", &"Label", ROPE)
	t.set_stylebox(&"panel", &"PanelContainer", panel_box())
	t.set_stylebox(&"panel", &"Panel", panel_box())
	var track := _box(Color(SEA_DEEP, 0.9), 8)
	track.content_margin_top = 6.0
	track.content_margin_bottom = 6.0
	t.set_stylebox(&"slider", &"HSlider", track)
	var fill := _box(Color(BRASS, 0.8), 8)
	t.set_stylebox(&"grabber_area", &"HSlider", fill)
	t.set_stylebox(&"grabber_area_highlight", &"HSlider", fill)
	t.set_color(&"font_color", &"CheckBox", ROPE)
	return t


## The panel behind every menu and sheet.
static func panel_box() -> StyleBoxFlat:
	var b := _box(Color(SEA_DEEP, 0.94), 20)
	b.border_color = Color(BRASS, 0.3)
	b.set_border_width_all(2)
	b.set_content_margin_all(24.0)
	b.shadow_color = Color(0, 0, 0, 0.35)
	b.shadow_size = 12
	return b


static func _buttons(t: Theme, type: StringName, fill: Color, text: Color, edge: Color, hover_edge: Color) -> void:
	var normal := _key(fill, edge, 6)
	var hover := _key(fill.lightened(0.08), hover_edge, 6)
	var pressed := _key(fill.darkened(0.18), edge, 2)
	pressed.content_margin_top += 4.0   # the face sinks onto its lower lip
	var disabled := _key(Color(fill, fill.a * 0.45), Color(edge, 0.3), 3)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = BRASS.lightened(0.3)
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(RADIUS + 2)
	focus.set_expand_margin_all(3.0)
	t.set_stylebox(&"normal", type, normal)
	t.set_stylebox(&"hover", type, hover)
	t.set_stylebox(&"pressed", type, pressed)
	t.set_stylebox(&"hover_pressed", type, pressed)
	t.set_stylebox(&"disabled", type, disabled)
	t.set_stylebox(&"focus", type, focus)
	for c: StringName in [&"font_color", &"font_hover_color", &"font_focus_color"]:
		t.set_color(c, type, text)
	t.set_color(&"font_pressed_color", type, text.darkened(0.1))
	t.set_color(&"font_hover_pressed_color", type, text.darkened(0.1))
	t.set_color(&"font_disabled_color", type, Color(STONE, 0.8))


## A key: a face with a thin outline and a thicker lower lip in the edge colour.
static func _key(fill: Color, edge: Color, lip_px: int) -> StyleBoxFlat:
	var b := _box(fill, RADIUS)
	b.border_color = edge
	b.set_border_width_all(2)
	b.border_width_bottom = lip_px
	b.content_margin_left = 18.0
	b.content_margin_right = 18.0
	b.content_margin_top = 10.0
	b.content_margin_bottom = 10.0
	b.shadow_color = Color(0, 0, 0, 0.25)
	b.shadow_size = 4
	b.shadow_offset = Vector2(0, 2)
	return b


static func _box(fill: Color, radius: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.set_corner_radius_all(radius)
	b.anti_aliasing = true
	return b
