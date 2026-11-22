class_name MapScreen
extends Control
## The map (roadmap R17, owner decision D6): first the countries, as cards
## with how many spots each has and whose legal rules hold there (a country
## whose rules are read but has no spot yet says it is coming); then a
## country's chart: a graticule, a compass rose and a brass pin per spot at
## its real coordinates (MapModel.chart_point). Tapping a pin shows the
## spot: its coordinates, the kind of shore, its species and positions, and
## "Fish here". No coastline is drawn yet (a coastline needs a licensed
## data source). Emits spot_chosen(spot_id) or closed.

signal spot_chosen(spot_id: String)
signal closed

var country := ""            ## "" on the countries step
var selected := ""           ## the spot whose card is open
var _title: Label
var _hint: Label
var _cards: HBoxContainer
var _info: PanelContainer
var _info_text: RichTextLabel
var _go: Button
var _back: Button
var _t := 0.0
var _land_key := ""
var _land_polys: Array[PackedVector2Array] = []
var _land_tris: Array[PackedInt32Array] = []
var _land_lines: Array[PackedVector2Array] = []
const LAND_FILE := "res://data/map/land.json"
static var _land_cache: Array[PackedVector2Array] = []


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_title = _label(32)
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 22.0
	_title.offset_bottom = 66.0
	add_child(_title)
	_hint = _label(20)
	_hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint.offset_top = 66.0
	_hint.offset_bottom = 98.0
	add_child(_hint)
	_back = Button.new()
	_back.text = tr("PROTO_BACK")
	_back.theme_type_variation = UiTheme.GLASS_KEY
	_back.position = Vector2(16, 16)
	_back.custom_minimum_size = Vector2(150, 80)
	_back.add_theme_font_size_override("font_size", 22)
	_back.pressed.connect(back)
	add_child(_back)
	_cards = HBoxContainer.new()
	_cards.set_anchors_preset(Control.PRESET_CENTER)
	_cards.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_cards.grow_vertical = Control.GROW_DIRECTION_BOTH
	_cards.add_theme_constant_override("separation", 16)
	add_child(_cards)
	_info = PanelContainer.new()
	_info.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_info.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_info.grow_vertical = Control.GROW_DIRECTION_BOTH
	_info.offset_right = -24.0
	_info.visible = false
	add_child(_info)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(380, 0)
	box.add_theme_constant_override("separation", 12)
	_info.add_child(box)
	_info_text = RichTextLabel.new()
	_info_text.bbcode_enabled = true
	_info_text.fit_content = true
	_info_text.scroll_active = false
	_info_text.add_theme_font_size_override("normal_font_size", 19)
	_info_text.add_theme_color_override("default_color", UiTheme.ROPE)
	box.add_child(_info_text)
	_go = Button.new()
	_go.text = tr("MAP_FISH_HERE")
	_go.theme_type_variation = UiTheme.PRIMARY
	_go.custom_minimum_size = Vector2(0, 90)
	_go.add_theme_font_size_override("font_size", 26)
	_go.pressed.connect(func() -> void: spot_chosen.emit(selected))
	box.add_child(_go)


func _ready() -> void:
	open_countries()


## The first step: one card per country.
func open_countries() -> void:
	country = ""
	selected = ""
	_title.text = tr("MAP_TITLE")
	_hint.text = tr("MAP_HINT")
	_info.visible = false
	for c in _cards.get_children():
		c.queue_free()
	for c: Dictionary in MapModel.countries(Db.database()):
		_cards.add_child(_country_card(c))
	_cards.visible = true
	queue_redraw()


## The second step: a country's chart and its spots.
func open_country(code: String) -> void:
	country = code
	selected = ""
	for c: Dictionary in MapModel.countries(Db.database()):
		if c["country"] == code:
			_title.text = tr(c["name_key"])
	_hint.text = tr("MAP_PICK_SPOT")
	_cards.visible = false
	_info.visible = false
	var spots := MapModel.spots_in(Db.database(), code)
	if spots.size() == 1:
		select(String(spots[0]["id"]))
	queue_redraw()


## Opens a spot's card on the chart.
func select(spot_id: String) -> void:
	selected = spot_id
	var spot := MapModel.spot(Db.database(), spot_id)
	var names: Array[String] = []
	for e: Dictionary in spot.get("species", []):
		for sp: Dictionary in Db.database()["species"]:
			if sp["id"] == e["species_id"]:
				names.append(tr(sp["name_key"]))
	_info_text.text = "[b][font_size=26]%s[/font_size][/b]\n%s\n\n%s\n%s\n%s" % [
		tr(spot["name_key"]), "%.4f° N, %.4f° E" % [float(spot["lat"]), float(spot["lon"])],
		tr("MAP_SHORE_%s" % String(spot.get("shore_type", "pier")).to_upper()),
		tr("MAP_SPECIES") % ", ".join(names),
		tr("MAP_POSITIONS") % (spot["positions"] as Array).size()]
	_info.visible = true
	queue_redraw()


## Back: from a spot's card to the chart, from the chart to the countries,
## from the countries out of the map.
func back() -> void:
	if selected != "" and MapModel.spots_in(Db.database(), country).size() > 1:
		selected = ""
		_info.visible = false
		queue_redraw()
	elif country != "":
		open_countries()
	else:
		closed.emit()


func _country_card(c: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(200, 230)
	b.focus_mode = Control.FOCUS_NONE
	var n := (c["spots"] as Array).size()
	b.disabled = n == 0
	var words := Label.new()
	words.text = "%s\n\n%s\n%s" % [tr(c["name_key"]), tr("MAP_SPOTS") % n if n > 0 else tr("MAP_COMING"),
		tr("MAP_RULES_READ") if c["official"] else tr("MAP_RULES_UNOFFICIAL")]
	words.add_theme_font_size_override("font_size", 19)
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.set_anchors_preset(Control.PRESET_FULL_RECT)
	words.offset_left = 10.0
	words.offset_right = -10.0
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(words)
	if n > 0:
		b.theme_type_variation = UiTheme.PRIMARY if c["country"] == "TR" else &""
	var code := String(c["country"])
	b.pressed.connect(func() -> void: open_country(code))
	return b


func _process(delta: float) -> void:
	_t += delta
	if country != "":
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if country == "":
		return
	var pressed: bool = (event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	var at: Vector2 = event.position
	var best := ""
	var best_d := 44.0
	for s: Dictionary in MapModel.spots_in(Db.database(), country):
		var d := pin(s).distance_to(at)
		if d < best_d:
			best = String(s["id"])
			best_d = d
	if best != "":
		select(best)
		accept_event()


## The chart's rectangle on screen: the left part when a spot's card is open.
func chart_rect() -> Rect2:
	return Rect2(Vector2(40, 110), Vector2(size.x - 80.0 - (440.0 if _info.visible else 0.0), size.y - 150.0))


func _bounds() -> Array[float]:
	return MapModel.bounds(MapModel.spots_in(Db.database(), country), MapModel.margin_deg(MapModel.spots_in(Db.database(), country)))


## A spot's pin on screen.
func pin(spot: Dictionary) -> Vector2:
	var spots := MapModel.spots_in(Db.database(), country)
	var shown := MapModel.spread(_true_points(spots), 46.0)
	for i in spots.size():
		if spots[i]["id"] == spot["id"]:
			return shown[i]
	return true_point(spot)


## Where a spot really is on the chart (its pin may be moved aside).
func true_point(spot: Dictionary) -> Vector2:
	return MapModel.chart_point(float(spot["lat"]), float(spot["lon"]), _bounds(), chart_rect().grow(-60.0))


func _true_points(spots: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for s: Dictionary in spots:
		out.append(true_point(s))
	return out


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0a1a24"))
	if country == "":
		return
	var r := chart_rect()
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("0f2a36")
	paper.set_corner_radius_all(16)
	paper.border_color = Color(UiTheme.BRASS, 0.55)
	paper.set_border_width_all(2)
	draw_style_box(paper, r)
	var b := _bounds()
	var inner := r.grow(-60.0)
	_draw_land(b, inner, r)
	var font := get_theme_default_font()
	# Graticule: a line every hundredth of a degree, labelled on the edges.
	# A line every step, with the labels at least 90 px apart along a parallel.
	var px_per_deg := MapModel.chart_point(b[1], b[0] + 1.0, b, inner).x - MapModel.chart_point(b[1], b[0], b, inner).x
	var step := _grid_step_px(px_per_deg)
	var lat := ceilf(b[1] / step) * step
	while lat <= b[3]:
		var y := MapModel.chart_point(lat, b[0], b, inner).y
		if y > r.position.y and y < r.end.y:
			draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(UiTheme.ROPE, 0.08), 1.0)
			draw_string(font, Vector2(r.position.x + 8, y - 4), _deg(lat, step) + "° N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(UiTheme.ROPE, 0.4))
		lat += step
	var lon := ceilf(b[0] / step) * step
	while lon <= b[2]:
		var x := MapModel.chart_point(b[1], lon, b, inner).x
		if x > r.position.x and x < r.end.x:
			draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(UiTheme.ROPE, 0.08), 1.0)
			draw_string(font, Vector2(x + 4, r.end.y - 8), _deg(lon, step) + "° E", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(UiTheme.ROPE, 0.4))
		lon += step
	_draw_rose(r.end - Vector2(70, 70), 40.0)
	for s: Dictionary in MapModel.spots_in(Db.database(), country):
		var p := pin(s)
		var real := true_point(s)
		if p.distance_to(real) > 1.0:
			draw_line(real, p, Color(UiTheme.BRASS, 0.6), 1.5, true)   # moved aside: a leader to the real place
			draw_circle(real, 3.0, UiTheme.BRASS)
		var on := String(s["id"]) == selected
		var pulse := 1.0 + 0.12 * sin(_t * 3.0) if on else 1.0
		draw_circle(p, 22.0 * pulse, Color(UiTheme.BRASS, 0.18))
		draw_circle(p, 11.0, UiTheme.BRASS if on else Color(UiTheme.BRASS, 0.75))
		draw_circle(p, 4.0, Color("0a1a24"))
		draw_string_outline(font, p + Vector2(18, -14), tr(s["name_key"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, Color(0, 0, 0, 0.7))
		draw_string(font, p + Vector2(18, -14), tr(s["name_key"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiTheme.ROPE)


## Land from Natural Earth (public domain, game/data/map/land.json), filled
## and outlined, then the frame around the chart is painted over so nothing
## spills out. The triangulation is cached for the chart's current view.
func _draw_land(b: Array[float], inner: Rect2, r: Rect2) -> void:
	var key := "%s|%s|%s" % [country, str(inner), str(b)]
	if key != _land_key:
		_land_key = key
		_land_polys.clear()
		_land_tris.clear()
		# Cut each ring to the view first (Clipper gives clean, simple pieces).
		# The chart shows more than the bounds on its long side: cut wide.
		var pad := 4.0 * maxf(b[2] - b[0], b[3] - b[1]) + 0.5
		var view := PackedVector2Array([Vector2(b[0] - pad, b[1] - pad), Vector2(b[2] + pad, b[1] - pad), Vector2(b[2] + pad, b[3] + pad), Vector2(b[0] - pad, b[3] + pad)])
		_land_lines.clear()
		for ring: PackedVector2Array in MapModel.rings_in(_land(), b):
			var line := PackedVector2Array()
			for v: Vector2 in ring:
				line.append(MapModel.chart_point(v.y, v.x, b, inner))
			line.append(line[0])
			_land_lines.append(line)
			for piece: PackedVector2Array in Geometry2D.intersect_polygons(ring, view):
				var pts := PackedVector2Array()
				for v: Vector2 in piece:
					pts.append(MapModel.chart_point(v.y, v.x, b, inner))
				_land_polys.append(pts)
				_land_tris.append(Geometry2D.triangulate_polygon(pts))
	var land_c := Color("2c3a2e")
	for i in _land_polys.size():
		var pts: PackedVector2Array = _land_polys[i]
		var tris: PackedInt32Array = _land_tris[i]
		if tris.size() >= 3:
			var cols := PackedColorArray()
			cols.resize(pts.size())
			cols.fill(land_c)
			RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), tris, pts, cols)
	for line: PackedVector2Array in _land_lines:
		draw_polyline(line, Color(UiTheme.BRASS, 0.45), 1.5, true)   # the coast, not the cut
	# Paint the frame back over anything outside the chart.
	var bg := Color("0a1a24")
	draw_rect(Rect2(0, 0, size.x, r.position.y), bg)
	draw_rect(Rect2(0, r.end.y, size.x, size.y - r.end.y), bg)
	draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), bg)
	draw_rect(Rect2(r.end.x, r.position.y, size.x - r.end.x, r.size.y), bg)
	draw_rect(r, Color(UiTheme.BRASS, 0.55), false, 2.0)


## The land rings, read once.
static func _land() -> Array[PackedVector2Array]:
	if _land_cache.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAND_FILE))
		if typeof(raw) == TYPE_DICTIONARY:
			for flat: Array in raw.get("rings", []):
				var ring := PackedVector2Array()
				for i in range(0, flat.size() - 1, 2):
					ring.append(Vector2(float(flat[i]), float(flat[i + 1])))
				_land_cache.append(ring)
	return _land_cache


## A grid label with as many decimals as the step needs.
static func _deg(v: float, step: float) -> String:
	return ("%.3f" if step < 0.01 else "%.2f" if step < 0.1 else "%.1f") % v


## The smallest grid step whose lines are at least 90 px apart.
static func _grid_step_px(px_per_deg: float) -> float:
	for st: float in [0.005, 0.01, 0.05, 0.1, 0.5, 1.0, 2.0, 5.0]:
		if st * px_per_deg >= 90.0:
			return st
	return 10.0


## A compass rose: north up, as on a chart.
func _draw_rose(c: Vector2, r: float) -> void:
	draw_arc(c, r, 0.0, TAU, 40, Color(UiTheme.BRASS, 0.5), 1.5, true)
	for i in 16:
		var a := TAU * float(i) / 16.0
		var reach := r * (1.0 if i % 4 == 0 else 0.55)
		draw_line(c, c + Vector2(sin(a), -cos(a)) * reach, Color(UiTheme.BRASS, 0.6 if i % 4 == 0 else 0.3), 1.5, true)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(6, 0), c + Vector2(-6, 0)]), UiTheme.BRASS)
	draw_string(get_theme_default_font(), c + Vector2(-6, -r - 6), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UiTheme.BRASS)


func _label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", UiTheme.ROPE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
