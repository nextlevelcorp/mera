class_name BagPanel
extends PanelContainer
## The bag (roadmap R16): what the angler carries and how good they are. The
## fish with their length, weight and what the fishmonger pays (an undersize
## fish can only go back), the tackle with how many are left, the money and the
## three skills. Rules are Economy's, Progress' and Presentation's; this only
## shows them and sends the one choice it offers (release an undersize fish).

signal closed
signal changed

var _money: Label
var _skills: Label
var _rows: VBoxContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(700, 0)
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(_label(30, tr("BAG_TITLE")))
	_money = _label(24)
	box.add_child(_money)
	_skills = _label(18)
	_skills.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_skills)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 8)
	scroll.add_child(_rows)
	var close := _button(tr("FISH_CLOSE"), 24)
	close.pressed.connect(func() -> void:
		visible = false
		closed.emit())
	box.add_child(close)
	visible = false


func open() -> void:
	if Weekly.refresh(Profile.save, Db.weekly(), Db.constants(), Time.get_date_string_from_system()):
		Profile.flush()
	visible = true
	refresh()


## The rows as text, for the tests and the screen alike.
static func lines(save: Dictionary) -> Dictionary:
	var k := Db.constants()
	var skills: Array[String] = []
	for skill: String in Progress.SKILLS:
		skills.append(TranslationServer.translate("SKILL_LINE") % [TranslationServer.translate("SKILL_%s" % skill.to_upper()), Progress.level(k, Progress.xp(save, skill)), Progress.xp(save, skill)])
	var fish: Array[Dictionary] = []
	var total := 0
	for row: Dictionary in Economy.bag_fish(save, Db.shop(), Db.database()["species"]):
		var text := "%s · %.0f cm · %.2f kg" % [TranslationServer.translate(Db.record("species", row["species_id"])["name_key"]), row["length_cm"], row["weight_kg"]]
		text += " · " + (TranslationServer.translate("SHOP_UNDERSIZE") if row["undersize"] else TranslationServer.translate("MONEY_FMT") % int(row["value"]))
		total += int(row["value"])
		fish.append({"text": text, "index": row["index"], "undersize": row["undersize"]})
	var tackle: Array[String] = []
	for item: Dictionary in Db.shop()["lures"]:
		var record := Db.record("lure", item["id"])
		if record.is_empty():
			record = Db.record("bait", item["id"])
		tackle.append(TranslationServer.translate("BAG_TACKLE_LINE") % [TranslationServer.translate(record["name_key"]), Inventory.count(save, item["id"])])
	var goals := Db.goals()
	var got := Mastery.badges(goals, save, k)
	var badges: Array[String] = []
	for g: Dictionary in goals:
		var p := Mastery.progress(g, save, k)
		var title := TranslationServer.translate(g["title_key"])
		badges.append(TranslationServer.translate("GOAL_DONE") % title if p["done"] else TranslationServer.translate("GOAL_PROGRESS") % [title, int(p["value"]), int(p["target"])])
	var week: Array[Dictionary] = []
	for t: Dictionary in Db.weekly():
		var wp := Weekly.progress(t, save, k)
		week.append({"id": t["id"], "text": TranslationServer.translate("GOAL_PROGRESS") % [TranslationServer.translate(t["title_key"]), mini(int(wp["value"]), int(wp["target"])), int(wp["target"])],
			"claimable": wp["done"] and not wp["claimed"], "claimed": wp["claimed"]})
	var rank := TranslationServer.translate("RANK_LINE") % [TranslationServer.translate("RANK_%d" % Mastery.rank(got.size(), k)), got.size(), goals.size()]
	var nu := Mastery.next_unlock(Db.unlocks(), goals, save, k)
	var next_unlock := ""
	if not nu.is_empty():
		next_unlock = TranslationServer.translate("UNLOCK_NEXT") % [TranslationServer.translate(nu["name_key"]), TranslationServer.translate("RANK_%d" % int(nu["rank"])), got.size(), int((k["RANK_STEPS"] as Array)[int(nu["rank"])])]
	return {"money": TranslationServer.translate("MONEY_FMT") % Economy.money(save), "skills": " · ".join(skills),
		"fish": fish, "fish_value": total, "tackle": tackle, "rank": rank, "badges": badges, "next_unlock": next_unlock,
		"week_title": TranslationServer.translate("WEEK_TITLE") % String((save.get("weekly", {}) as Dictionary).get("week", "")), "week": week}


func refresh() -> void:
	for c in _rows.get_children():
		c.queue_free()
	var l := lines(Profile.save)
	_money.text = "%s · %s" % [l["money"], l["rank"]]
	_skills.text = l["skills"] + ("\n" + l["next_unlock"] if l["next_unlock"] != "" else "")
	_rows.add_child(_label(22, tr("BAG_FISH") % [(l["fish"] as Array).size(), tr("MONEY_FMT") % int(l["fish_value"])]))
	if (l["fish"] as Array).is_empty():
		_rows.add_child(_label(20, tr("SHOP_NO_FISH")))
	for f: Dictionary in l["fish"]:
		var line := HBoxContainer.new()
		var info := _label(20, f["text"])
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_child(info)
		if f["undersize"]:
			var index: int = f["index"]
			var release := _button(tr("SHOP_RELEASE"), 20)
			release.pressed.connect(func() -> void:
				Economy.release(Profile.save, index)
				Profile.flush()
				changed.emit()
				refresh())
			line.add_child(release)
		_rows.add_child(line)
	_rows.add_child(_label(22, tr("BAG_TACKLE")))
	for t: String in l["tackle"]:
		_rows.add_child(_label(20, t))
	_rows.add_child(_label(22, l["week_title"]))
	for w: Dictionary in l["week"]:
		var line := HBoxContainer.new()
		var info := _label(20, w["text"] + (" · " + tr("WEEK_CLAIMED") if w["claimed"] else ""))
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(info)
		if w["claimable"]:
			var id: String = w["id"]
			var claim := _button(tr("WEEK_CLAIM"), 20)
			claim.theme_type_variation = UiTheme.PRIMARY
			claim.pressed.connect(func() -> void:
				for t: Dictionary in Db.weekly():
					if t["id"] == id:
						Weekly.claim(Profile.save, t, Db.constants())
				Profile.flush()
				changed.emit()
				refresh())
			line.add_child(claim)
		_rows.add_child(line)
	_rows.add_child(_label(22, tr("BAG_BADGES")))
	for b: String in l["badges"]:
		_rows.add_child(_label(20, b))


func _label(size: int, text: String = "") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	return l


func _button(text: String, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	return b
