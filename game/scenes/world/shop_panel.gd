class_name ShopPanel
extends PanelContainer
## The fishmonger and the tackle shop of the world (roadmap R8) as one panel:
## the fishmonger lists the fish in the bag with what they fetch (an undersize
## fish is not bought and can be released); the tackle shop sells lures. All
## rules are Economy's; this only shows them and sends the player's choice.
## Reads and changes the save through Profile.

signal closed
signal changed   ## money or bag changed, so a HUD can refresh

var kind := ""

var _title: Label
var _money: Label
var _rows: VBoxContainer
var _note: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(640, 0)
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_title = _label(30)
	box.add_child(_title)
	_money = _label(24)
	box.add_child(_money)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 260)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 8)
	scroll.add_child(_rows)
	_note = _label(20)
	box.add_child(_note)
	var close := _button(tr("FISH_CLOSE"), 24)
	close.pressed.connect(func() -> void:
		visible = false
		closed.emit())
	box.add_child(close)
	visible = false


## kind_id: "fishmonger" or "tackle".
func open(kind_id: String) -> void:
	kind = kind_id
	_note.text = ""
	visible = true
	_refresh()


func _refresh() -> void:
	for c in _rows.get_children():
		c.queue_free()
	var save := Profile.save
	_money.text = tr("MONEY_FMT") % Economy.money(save)
	if kind == "fishmonger":
		_title.text = tr("SHOP_FISHMONGER")
		_fill_fishmonger(save)
	else:
		_title.text = tr("SHOP_TACKLE")
		_fill_tackle(save)


func _fill_fishmonger(save: Dictionary) -> void:
	var rows := Economy.bag_fish(save, Db.shop(), Db.database()["species"])
	if rows.is_empty():
		_rows.add_child(_label(22, tr("SHOP_NO_FISH")))
		return
	var sellable := 0
	for row: Dictionary in rows:
		var name_text := "%s · %.0f cm · %.2f kg" % [tr(Db.record("species", row["species_id"])["name_key"]), row["length_cm"], row["weight_kg"]]
		var line := HBoxContainer.new()
		var info := _label(20, name_text if not row["undersize"] else "%s\n%s" % [name_text, tr("SHOP_UNDERSIZE")])
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_child(info)
		var index: int = row["index"]
		if row["undersize"]:
			var release := _button(tr("SHOP_RELEASE"), 20)
			release.pressed.connect(func() -> void:
				Economy.release(Profile.save, index)
				_after())
			line.add_child(release)
		else:
			sellable += 1
			var sell := _button("%s · %s" % [tr("SHOP_SELL"), tr("MONEY_FMT") % int(row["value"])], 20)
			sell.pressed.connect(func() -> void:
				Economy.sell(Profile.save, Db.shop(), Db.database()["species"], index)
				_after())
			line.add_child(sell)
		_rows.add_child(line)
	if sellable > 1:
		var all := _button(tr("SHOP_SELL_ALL"), 24)
		all.pressed.connect(func() -> void:
			var r := Economy.sell_all(Profile.save, Db.shop(), Db.database()["species"])
			_after(tr("SHOP_SOLD") % [int(r["count"]), int(r["money"])]))
		_rows.add_child(all)


func _fill_tackle(save: Dictionary) -> void:
	for lure: Dictionary in Db.shop()["lures"]:
		var id: String = lure["id"]
		var record := Db.record("lure", id)
		if record.is_empty():
			record = Db.record("bait", id)
		var line := HBoxContainer.new()
		var info := _label(20, "%s · %s" % [tr(record["name_key"]), tr("SHOP_OWNED") % Inventory.count(save, id)])
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(info)
		var buy := _button("%s · %s" % [tr("SHOP_BUY"), tr("MONEY_FMT") % int(lure["price"])], 20)
		buy.disabled = Economy.money(save) < int(lure["price"])
		buy.pressed.connect(func() -> void:
			if not Economy.buy(Profile.save, Db.shop(), id):
				_note.text = tr("SHOP_POOR")
			_after())
		line.add_child(buy)
		_rows.add_child(line)


func _after(note: String = "") -> void:
	Profile.flush()
	if note != "":
		_note.text = note
	changed.emit()
	_refresh()


func _label(size: int, text: String = "") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if text == "" else HORIZONTAL_ALIGNMENT_LEFT
	return l


func _button(text: String, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, 64)
	return b
