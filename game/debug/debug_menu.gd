extends Control
## Debug menu (PRD F15). Loaded by the fishing screen only in a debug build or
## with the mera_debug feature tag, so a release export never shows it. Lets
## the owner reach any flow in a few taps: time slot, wind, clarity, standing
## position, force a bite by species and size, and read the simulation's
## numbers for the last cast, take and fight ("why" view, PRD F10), plus the
## frame-rate figures used for before-and-after measurements.

const SLOTS: Array[String] = ["dawn", "day", "evening", "night"]
const WINDS: Array[int] = [0, 3, 6, 10]
const CLARITIES: Array[float] = [-1.0, 2.0, 5.0, 10.0, 20.0]
const SIZES: Array[float] = [-1.0, 0.1, 0.5, 0.95]
const SIZE_KEYS: Array[String] = ["DBG_SIZE_RANDOM", "DBG_SIZE_SMALL", "DBG_SIZE_MEDIUM", "DBG_SIZE_LARGE"]

var _screen: Control
var _panel: PanelContainer
var _info: Label
var _species_ids: Array[String] = []
var _species_i := 0
var _size_i := 0
var _clarity_i := 0
var _buttons := {}
var _info_clock := 0.0


func _init(screen: Control) -> void:
	_screen = screen
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	for entry: Dictionary in _screen._db["spot"][0]["species"]:
		_species_ids.append(entry["species_id"])
	var toggle := Button.new()
	toggle.text = tr("DBG_OPEN")
	toggle.add_theme_font_size_override("font_size", 20)
	toggle.custom_minimum_size = Vector2(120, 72)
	toggle.anchor_left = 1.0
	toggle.anchor_right = 1.0
	toggle.offset_left = -136.0
	toggle.offset_right = -16.0
	toggle.offset_top = 16.0
	toggle.offset_bottom = 88.0
	toggle.pressed.connect(func() -> void:
		_panel.visible = not _panel.visible
		_refresh())
	add_child(toggle)

	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -560.0
	_panel.offset_right = -16.0
	_panel.offset_top = 96.0
	_panel.visible = false
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	_add(grid, "slot", func() -> void:
		var c: Dictionary = _screen.conditions
		c["slot"] = SLOTS[(SLOTS.find(c["slot"]) + 1) % SLOTS.size()]
		_screen.apply_conditions())
	_add(grid, "wind", func() -> void:
		var c: Dictionary = _screen.conditions
		c["wind_ms"] = WINDS[(WINDS.find(int(c["wind_ms"])) + 1) % WINDS.size()]
		_screen.apply_conditions())
	_add(grid, "dir", func() -> void:
		var c: Dictionary = _screen.conditions
		var dirs := CatchModel.WIND_DIRECTIONS
		c["wind_dir"] = dirs[(dirs.find(c["wind_dir"]) + 1) % dirs.size()]
		_screen.apply_conditions())
	_add(grid, "clarity", func() -> void:
		_clarity_i = (_clarity_i + 1) % CLARITIES.size()
		_screen.clarity_override = CLARITIES[_clarity_i]
		_screen.apply_conditions())
	_add(grid, "position", func() -> void:
		var positions: Array = _screen._db["spot"][0]["positions"]
		var i: int = _screen._position_index(_screen.position_id)
		_screen.set_rig(_screen.rig, positions[(i + 1) % positions.size()]["id"]))
	_add(grid, "rig", func() -> void:
		var t := FightSetup.TACKLES
		_screen.set_rig(t[(t.find(_screen.rig) + 1) % t.size()], _screen.position_id))
	_add(grid, "species", func() -> void: _species_i = (_species_i + 1) % _species_ids.size())
	_add(grid, "size", func() -> void: _size_i = (_size_i + 1) % SIZES.size())
	var bite := Button.new()
	bite.text = tr("DBG_FORCE_BITE")
	bite.add_theme_font_size_override("font_size", 22)
	bite.custom_minimum_size = Vector2(0, 72)
	bite.pressed.connect(func() -> void:
		_screen.force_bite(_species_ids[_species_i], SIZES[_size_i])
		_panel.visible = false)
	box.add_child(bite)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 14)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(520, 0)
	box.add_child(_info)
	_refresh()


func _process(delta: float) -> void:
	_info_clock -= delta
	if _panel.visible and _info_clock <= 0.0:
		_info_clock = 0.5
		_refresh()


func _add(grid: GridContainer, id: String, on_press: Callable) -> void:
	var b := Button.new()
	b.add_theme_font_size_override("font_size", 18)
	b.custom_minimum_size = Vector2(260, 64)
	b.pressed.connect(func() -> void:
		on_press.call()
		_refresh())
	grid.add_child(b)
	_buttons[id] = b


func _refresh() -> void:
	if _buttons.is_empty() or _screen._ctx.is_empty():
		return
	var c: Dictionary = _screen.conditions
	_buttons["slot"].text = "%s: %s" % [tr("DBG_SLOT"), tr("SLOT_%s" % String(c["slot"]).to_upper())]
	_buttons["wind"].text = "%s: %d m/s" % [tr("DBG_WIND"), int(c["wind_ms"])]
	_buttons["dir"].text = "%s: %s" % [tr("DBG_WIND_DIR"), c["wind_dir"]]
	var clarity: float = CLARITIES[_clarity_i]
	_buttons["clarity"].text = "%s: %s" % [tr("DBG_CLARITY"), tr("DBG_AUTO") if clarity < 0.0 else str(int(clarity))]
	_buttons["position"].text = "%s: %s" % [tr("FISH_POSITION"), tr(_screen._ctx["position"]["name_key"])]
	_buttons["rig"].text = "%s: %s" % [tr("FIGHT_TACKLE"), tr(_screen._ctx["rod"]["name_key"])]
	_buttons["species"].text = "%s: %s" % [tr("FIGHT_SPECIES"), tr(_screen._species_by_id(_species_ids[_species_i])["name_key"])]
	_buttons["size"].text = "%s: %s" % [tr("DBG_SIZE"), tr(SIZE_KEYS[_size_i])]
	_info.text = _screen.debug_info()
