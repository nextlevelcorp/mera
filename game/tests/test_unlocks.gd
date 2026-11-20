extends "res://tests/test_base.gd"
## Roadmap R22: rigs, baits and the boat open with the angler's rank (owner decision D8).


func _k() -> Dictionary:
	return Db.constants()


func _with_badges(n: int) -> Dictionary:
	# Earn badges in the goals' order from what the save keeps.
	var save := SaveGame.fresh()
	var goals := Db.goals()
	var i := 0
	while Mastery.badges(goals, save, _k()).size() < n and i < 200:
		i += 1
		save["stats"]["fish_landed"] = int(save["stats"]["fish_landed"]) + 1
		SaveGame.record_catch(save, ["istavrit", "lufer", "palamut"][i % 3], [17.5, 36.0, 51.0][i % 3], 0.1, "2026-11-20")
		save["angler_xp"] = {"cast": Progress.xp_for_level(_k(), 2), "strike": Progress.xp_for_level(_k(), 3) if i > 5 else 0}
		save["quests"] = {"active": [], "done": ["a", "b", "c"].slice(0, mini(i / 3, 3))}
	return save


func test_the_unlocks_load_and_start_closed_for_a_newcomer() -> void:
	assert_true(Mastery.load_unlocks(_k())["ok"], "the unlocks load")
	var save := SaveGame.fresh()
	assert_true(Db.is_open(save, "rig", "lrf") and Db.is_open(save, "rig", "capari"), "the light rod and the sabiki are open from the start")
	assert_true(not Db.is_open(save, "rig", "float") and not Db.is_open(save, "rig", "spin"), "the float and spinning rods are not")
	assert_true(not Db.is_open(save, "bait", "live_istavrit"), "nor live bait")
	assert_eq(Mastery.next_unlock(Db.unlocks(), Db.goals(), save, _k())["rank"], 1, "the next opens at rank 1")


func test_rank_opens_them() -> void:
	var regular := _with_badges(3)
	assert_eq(Mastery.rank_of(Db.goals(), regular, _k()), 1, "three badges: a bridge regular")
	assert_true(Db.is_open(regular, "rig", "float") and Db.is_open(regular, "rig", "spin"), "which opens the float and spinning rods")
	assert_true(not Db.is_open(regular, "bait", "live_istavrit"), "live bait waits for rank 2")
	var shore := _with_badges(7)
	assert_true(Db.is_open(shore, "bait", "live_istavrit"), "seven badges open live bait")


func test_the_rig_panel_skips_a_locked_rig_and_says_why() -> void:
	var scr := FishingScreen.new()
	scr.request = Game.fishing_request("", "", "lrf", {"slot": "day", "month": 10, "wind_dir": "N", "wind_ms": 0})
	scr.setup("")
	scr.next_open_rig()
	assert_eq(scr.rig, "capari", "from the light rod the next open rig is the sabiki (spin is locked)")
	assert_true(scr._ui.toast_label.text.contains(tr("RANK_1")), "and the toast names the rank: %s" % scr._ui.toast_label.text)
	scr.free()


func test_a_saved_locked_rig_falls_back_to_the_light_rod() -> void:
	var save := SaveGame.fresh()
	save["last_rig"] = "float"
	assert_eq(FishingScreen.pick_rig("", save, "lrf"), "lrf", "a newcomer's saved float rig is not open yet")
	assert_eq(FishingScreen.pick_rig("float", save, "lrf"), "float", "a named request (debug, tests) is honoured")
	var regular := _with_badges(3)
	regular["last_rig"] = "float"
	assert_eq(FishingScreen.pick_rig("", regular, "lrf"), "float", "a bridge regular keeps the float rod")
