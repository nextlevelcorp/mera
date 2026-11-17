extends Control
## Debug menu of the world (CLAUDE.md: every flow reachable from the debug
## menu). Loaded only in a debug build or with the mera_debug feature tag, so
## a release export never has it. Sets the time of day and jumps to a
## fishing marker.

const SLOTS: Array[String] = ["dawn", "day", "evening", "night"]

var _world: WorldScreen
var _panel: PanelContainer
var _slot: Button
var _marker_i := 0


func _init(world: WorldScreen) -> void:
	_world = world
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var toggle := Button.new()
	toggle.text = tr("DBG_OPEN")
	toggle.add_theme_font_size_override("font_size", 20)
	toggle.anchor_left = 1.0
	toggle.anchor_right = 1.0
	toggle.offset_left = -136.0
	toggle.offset_right = -16.0
	toggle.offset_top = 16.0
	toggle.offset_bottom = 88.0
	toggle.pressed.connect(func() -> void: _panel.visible = not _panel.visible)
	add_child(toggle)
	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -400.0
	_panel.offset_right = -16.0
	_panel.offset_top = 96.0
	_panel.visible = false
	add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	_slot = Button.new()
	_slot.add_theme_font_size_override("font_size", 20)
	_slot.custom_minimum_size = Vector2(360, 64)
	_slot.pressed.connect(func() -> void:
		var c: Dictionary = _world.conditions
		c["slot"] = SLOTS[(SLOTS.find(c["slot"]) + 1) % SLOTS.size()]
		_world.apply_conditions()
		_refresh())
	box.add_child(_slot)
	var jump := Button.new()
	jump.text = tr("DBG_NEXT_MARKER")
	jump.add_theme_font_size_override("font_size", 20)
	jump.custom_minimum_size = Vector2(360, 64)
	jump.pressed.connect(func() -> void:
		var m: Dictionary = _world.area.markers[_marker_i % _world.area.markers.size()]
		_marker_i += 1
		_world.walk.teleport(m["pos"] + Vector2(0.0, 1.2))
		_panel.visible = false)
	box.add_child(jump)
	_refresh()


func _refresh() -> void:
	_slot.text = "%s: %s" % [tr("DBG_SLOT"), tr("SLOT_%s" % String(_world.conditions["slot"]).to_upper())]
