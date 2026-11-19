class_name TalkPanel
extends PanelContainer
## Talking to someone in the world (roadmap R11): what they ask for, how much
## of it is in the bag, the reward, and the choice to accept or hand over.
## All rules are Quests'; this shows them and sends the player's choice.
## Reads and changes the save through Profile.

signal closed
signal completed(quest: Dictionary)

var npc := {}
var quest := {}
var quests: Array = []

var _name: Label
var _title: Label
var _text: Label
var _info: Label
var _act: Button


func _init() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(680, 0)
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_name = _label(30)
	box.add_child(_name)
	_title = _label(24)
	_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	box.add_child(_title)
	_text = _label(22)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_text)
	_info = _label(20)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	_act = _button("", 24)
	_act.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_act.pressed.connect(_on_act)
	row.add_child(_act)
	var close := _button(tr("QUEST_CLOSE"), 24)
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close.pressed.connect(func() -> void:
		visible = false
		closed.emit())
	row.add_child(close)
	visible = false


func open(npc_record: Dictionary) -> void:
	npc = npc_record
	visible = true
	_refresh()


func _refresh() -> void:
	var save := Profile.save
	_name.text = tr(npc["name_key"])
	quest = Quests.current(quests, npc["id"], save)
	if quest.is_empty():
		_title.text = ""
		_text.text = tr("QUEST_NOTHING")
		_info.text = ""
		_act.visible = false
		return
	var species := Db.record("species", quest["need"]["species"])
	_title.text = tr(quest["title_key"])
	_text.text = tr(quest["ask_key"])
	var have := Quests.matching(save, quest, species).size()
	var parts: Array[String] = ["%s × %d (%s)" % [tr(species["name_key"]), int(quest["need"]["count"]), tr("QUEST_MIN_LENGTH") % int(ceilf(Quests.min_length(quest, species)))]]
	if Quests.is_active(save, quest["id"]):
		parts.append(tr("QUEST_PROGRESS") % [mini(have, int(quest["need"]["count"])), int(quest["need"]["count"])])
	parts.append(tr("QUEST_REWARD") % reward_text(quest))
	_info.text = "\n".join(parts)
	_act.visible = true
	if Quests.is_active(save, quest["id"]):
		_act.text = tr("QUEST_HAND_OVER")
		_act.disabled = not Quests.can_complete(save, quest, species)
	else:
		_act.text = tr("QUEST_ACCEPT")
		_act.disabled = false


## The reward in words: money, items, experience.
static func reward_text(q: Dictionary) -> String:
	var r: Dictionary = q.get("reward", {})
	var parts: Array[String] = []
	if int(r.get("money", 0)) > 0:
		parts.append(TranslationServer.translate("MONEY_FMT") % int(r["money"]))
	var items: Dictionary = r.get("items", {})
	for id: String in items:
		parts.append("%d %s" % [int(items[id]), TranslationServer.translate(Db.record("lure", id)["name_key"])])
	var xp: Dictionary = r.get("xp", {})
	for skill: String in xp:
		parts.append(TranslationServer.translate("QUEST_XP") % [int(xp[skill]), TranslationServer.translate("SKILL_%s" % skill.to_upper())])
	return ", ".join(parts)


func _on_act() -> void:
	var save := Profile.save
	if quest.is_empty():
		return
	if Quests.is_active(save, quest["id"]):
		var species := Db.record("species", quest["need"]["species"])
		var done := Quests.complete(save, quest, species, Db.constants())
		if done["ok"]:
			Profile.flush()
			var finished := quest
			_refresh()
			_title.text = tr(finished["title_key"])
			_text.text = tr(finished["thanks_key"])
			_info.text = tr("QUEST_REWARD") % reward_text(finished)
			_act.visible = false
			completed.emit(finished)
	else:
		Quests.accept(save, quest)
		Profile.flush()
		_refresh()


func _label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	return l


func _button(text: String, font_size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 72)
	b.add_theme_font_size_override("font_size", font_size)
	return b
