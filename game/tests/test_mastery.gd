extends "res://tests/test_base.gd"
## Roadmap R22 part 1: goals, badges, rank and the next goal (owner decision D8).


func _k() -> Dictionary:
	return Db.constants()


func test_the_goals_load_and_stay_inside_the_sourced_lengths() -> void:
	var loaded := Mastery.load_goals(Db.database())
	assert_true(loaded["ok"], "the goals load: %s" % str(loaded["errors"]))
	assert_true((loaded["goals"] as Array).size() >= 10, "there are enough goals for a progression")
	var bad := {"design_fill": true, "goals": [{"id": "x", "title_key": "T", "kind": "record_length", "species": "istavrit", "target": 60}]}
	assert_true(not Mastery.validate(bad, Db.database())["ok"], "a record target above the species' range is refused")
	var unsourced := {"goals": []}
	assert_true(not Mastery.validate(unsourced, Db.database())["ok"], "the file must say it is a design fill")
	for g: Dictionary in Db.goals():
		assert_true(TranslationServer.get_translation_object("en").get_message(g["title_key"]) != "", "%s has a title" % g["id"])


func test_a_new_angler_has_no_badges_and_a_first_goal() -> void:
	var save := SaveGame.fresh()
	assert_eq(Mastery.badges(Db.goals(), save, _k()).size(), 0, "no badges at the start")
	assert_eq(Mastery.next_goal(Db.goals(), save, _k())["id"], "first_fish", "the first goal is the first fish")
	assert_eq(Mastery.rank(0, _k()), 0, "a newcomer")


func test_badges_come_from_what_the_save_already_keeps() -> void:
	var save := SaveGame.fresh()
	SaveGame.record_catch(save, "istavrit", 17.5, 0.05, "2026-11-20")
	save["stats"]["fish_landed"] = 1
	var got := Mastery.badges(Db.goals(), save, _k())
	assert_true(got.has("first_fish") and got.has("first_istavrit") and got.has("istavrit_17"), "first fish, first horse mackerel and the 17 cm record: %s" % str(got))
	assert_true(not got.has("first_lufer"), "no bluefish yet")
	var before := got.duplicate()
	SaveGame.record_catch(save, "lufer", 20.0, 0.1, "2026-11-20")
	save["stats"]["fish_landed"] = 2
	var earned := Mastery.earned(before, Mastery.badges(Db.goals(), save, _k()))
	assert_eq(earned, ["first_lufer"], "the new badge is announced once")
	save["quests"] = {"active": [], "done": ["a"]}
	save["angler_xp"] = {"cast": Progress.xp_for_level(_k(), 2)}
	got = Mastery.badges(Db.goals(), save, _k())
	assert_true(got.has("first_quest") and got.has("cast_2"), "quests and skills count too")
	assert_eq(Mastery.rank(got.size(), _k()), 1, "%d badges make a bridge regular" % got.size())


func test_the_next_goal_is_the_nearest_to_done() -> void:
	var save := SaveGame.fresh()
	save["stats"]["fish_landed"] = 9
	SaveGame.record_catch(save, "istavrit", 12.0, 0.02, "2026-11-20")
	var g := Mastery.next_goal(Db.goals(), save, _k())
	var p := Mastery.progress(g, save, _k())
	assert_eq(g["id"], "ten_fish", "nine of ten fish is the nearest goal")
	assert_eq([p["value"], p["target"]], [9.0, 10.0], "with its progress")
	assert_true(WorldScreen.next_goal_text(save).contains("9/10"), "the world shows it: %s" % WorldScreen.next_goal_text(save))


func test_the_bag_lists_the_rank_and_every_badge() -> void:
	var save := SaveGame.fresh()
	var l := BagPanel.lines(save)
	assert_eq((l["badges"] as Array).size(), Db.goals().size(), "one line per goal")
	assert_true(String(l["rank"]).contains("0"), "and the rank with the count: %s" % l["rank"])
