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
var _shop_i := 0
var _person_i := 0


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
	# Reach the shops and the people quickly, to check their panels.
	var to_shop := Button.new()
	to_shop.text = tr("DBG_NEXT_SHOP")
	to_shop.add_theme_font_size_override("font_size", 20)
	to_shop.custom_minimum_size = Vector2(360, 64)
	to_shop.pressed.connect(func() -> void:
		var sh: Dictionary = _world.area.shops[_shop_i % _world.area.shops.size()]
		_shop_i += 1
		_world.walk.teleport(sh["pos"])
		_panel.visible = false)
	box.add_child(to_shop)
	var to_person := Button.new()
	to_person.text = tr("DBG_NEXT_PERSON")
	to_person.add_theme_font_size_override("font_size", 20)
	to_person.custom_minimum_size = Vector2(360, 64)
	to_person.pressed.connect(func() -> void:
		var here: Array = []
		for n: Dictionary in _world._npcs:
			var st: Dictionary = _world._npc_state[n["id"]]
			if st["present"]:
				here.append(st["target"])
		if here.is_empty():
			return
		var at: Vector2 = here[_person_i % here.size()]
		_person_i += 1
		for off: Vector2 in [Vector2(0, 1.2), Vector2(0, -1.2), Vector2(1.2, 0), Vector2(-1.2, 0)]:
			if not _world.area.blocked_at(at + off, float(Db.constants()["WALK_RADIUS_M"])):
				_world.walk.teleport(at + off)
				break
		_panel.visible = false)
	box.add_child(to_person)
	for entry: Array in [["DBG_GIVE_MONEY", 0], ["DBG_GIVE_FISH", 1], ["DBG_GIVE_LURES", 2]]:
		var give := Button.new()
		give.text = tr(entry[0])
		give.add_theme_font_size_override("font_size", 20)
		give.custom_minimum_size = Vector2(360, 64)
		var which: int = entry[1]
		give.pressed.connect(func() -> void: _give(which))
		box.add_child(give)
	_refresh()


## Hands the player something to test the shops with.
func _give(which: int) -> void:
	var save := Profile.save
	match which:
		0:
			save["money"] = Economy.money(save) + 100
		1:
			for i in 3:
				var legal: String = ["istavrit", "lufer", "palamut"][i]
				var species := Db.record("species", legal)
				var length := float(species["regulation"]["min_length_cm"]) + 4.0 + 3.0 * i
				Inventory.add_fish(save, legal, length, 0.002 * pow(length, 2.2) / 4.0, Time.get_date_string_from_system())
		2:
			for id: String in Db.shop()["starting_stock"]:
				Inventory.add(save, id, 5)
	Profile.flush()


func _refresh() -> void:
	_slot.text = "%s: %s" % [tr("DBG_SLOT"), tr("SLOT_%s" % String(_world.conditions["slot"]).to_upper())]
