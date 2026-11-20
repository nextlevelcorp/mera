extends "res://tests/test_base.gd"
## Roadmap R22: fixed weekly tasks (owner decision D8; save change approved 2026-11-20).


func _k() -> Dictionary:
	return Db.constants()


func test_the_iso_week_is_right_at_the_year_ends() -> void:
	assert_eq(Weekly.week_id("2026-11-20"), "2026-W47", "a Friday in November")
	assert_eq(Weekly.week_id("2021-01-01"), "2020-W53", "a Friday on New Year's Day belongs to the old year")
	assert_eq(Weekly.week_id("2024-12-30"), "2025-W01", "a Monday at the end of December can be week 1")
	assert_eq(Weekly.week_id("2026-11-16"), Weekly.week_id("2026-11-22"), "Monday to Sunday is one week")
	assert_true(Weekly.week_id("2026-11-22") != Weekly.week_id("2026-11-23"), "and Monday starts the next")


func test_the_tasks_load_and_count_only_gains() -> void:
	var loaded := Weekly.load_tasks(Db.database())
	assert_true(loaded["ok"], "the weekly tasks load: %s" % str(loaded["errors"]))
	for t: Dictionary in Db.weekly():
		assert_true(TranslationServer.get_translation_object("en").get_message(t["title_key"]) != "", "%s has a title" % t["id"])


func test_progress_counts_from_the_week_start_and_pays_once() -> void:
	var save := SaveGame.fresh()
	save["stats"]["fish_landed"] = 30   # earlier weeks do not count
	var tasks := Db.weekly()
	assert_true(Weekly.refresh(save, tasks, _k(), "2026-11-20"), "a new week starts")
	assert_true(not Weekly.refresh(save, tasks, _k(), "2026-11-21"), "and stays for the rest of it")
	var fish: Dictionary = tasks.filter(func(t: Dictionary) -> bool: return t["id"] == "w_fish_8")[0]
	assert_eq(Weekly.progress(fish, save, _k())["value"], 0.0, "nothing this week yet")
	save["stats"]["fish_landed"] = 38
	var p := Weekly.progress(fish, save, _k())
	assert_true(p["done"] and not p["claimed"], "eight this week: done")
	var money := Economy.money(save)
	assert_true(Weekly.claim(save, fish, _k())["ok"], "claimed")
	assert_eq(Economy.money(save), money + int(fish["reward"]["money"]), "paid")
	assert_true(not Weekly.claim(save, fish, _k())["ok"], "only once")
	assert_true(Weekly.refresh(save, tasks, _k(), "2026-11-23"), "next Monday is a new week")
	var q := Weekly.progress(fish, save, _k())
	assert_true(q["value"] == 0.0 and not q["claimed"], "the task is new again and nothing was lost")


func test_the_bag_shows_this_week() -> void:
	var save := SaveGame.fresh()
	Weekly.refresh(save, Db.weekly(), _k(), "2026-11-20")
	var l := BagPanel.lines(save)
	assert_true(String(l["week_title"]).contains("2026-W47"), "the week is named: %s" % l["week_title"])
	assert_eq((l["week"] as Array).size(), Db.weekly().size(), "one line per task")
