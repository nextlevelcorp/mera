extends "res://tests/test_base.gd"
## The squid (owner decision 2026-11-21): rarer, worth more, at night in the
## cold months, caught on a squid jig's pins rather than on a hook.


func _cond(slot: String, month: int = 11) -> Dictionary:
	return {"slot": slot, "month": month, "wind_dir": "NE", "wind_ms": 3}


func _ctx(species: String, rig: String, slot: String = "night", month: int = 11) -> Dictionary:
	return FightSetup.build(Db.database(), species, rig, "karakoy_east", 0.5, _cond(slot, month))


func _hook(species: String, rig: String) -> float:
	var c := _ctx(species, rig)
	return float(CatchModel.hook(Db.constants(), c["species"], c["rod"], c["line"], c["lure"], 1.0)["H1"])


func test_a_squid_holds_on_to_a_squid_jig_and_slips_off_a_hook() -> void:
	assert_eq(_hook("kalamar", "egi"), 1.0, "the jig's pins hold it")
	assert_eq(_hook("kalamar", "lrf"), float(Db.constants()["SQUID_ON_HOOK"]), "an ordinary hook rarely does")
	assert_true(_hook("istavrit", "egi") < 0.5 * _hook("istavrit", "lrf"), "a fish's mouth rarely meets the pins (%.2f against %.2f)" % [_hook("istavrit", "egi"), _hook("istavrit", "lrf")])


func test_squid_come_at_night_in_the_cold_months() -> void:
	var k := Db.constants()
	var rate := func(slot: String, month: int) -> float:
		var w := WaitSim.new(_ctx("kalamar", "egi", slot, month), k, Db.database()["species"], 20.0, 1)
		return float(w._rates["kalamar"]["rate_interest"])
	var night_nov: float = rate.call("night", 11)
	assert_true(night_nov > 4.0 * float(rate.call("day", 11)), "far more at night than by day")
	assert_true(night_nov > 4.0 * float(rate.call("night", 6)), "and far more in November than in June")


func test_a_squid_weighs_what_the_izmir_sample_says() -> void:
	var sp: Dictionary = _ctx("kalamar", "egi")["species"]
	var w := float(sp["lw_a"]) * pow(18.2, float(sp["lw_b"]))
	assert_near(w, 166.7, "a mean 18.2 cm mantle weighs about the mean 166.7 g (Gökçe et al. 2005)", 10.0)
	assert_true(sp["regulation"]["no_minimum"], "no legal minimum size in Turkey (Çizelge 7)")


func test_a_squid_is_worth_more_than_any_fish() -> void:
	var prices: Dictionary = Db.shop()["price_per_kg"]
	for id: String in prices:
		if id != "kalamar":
			assert_true(float(prices["kalamar"]) > float(prices[id]), "squid above %s" % id)


func test_the_squid_rod_is_a_rig_with_its_own_look() -> void:
	assert_true("egi" in FightSetup.TACKLES, "a fifth rig")
	var lure: Dictionary = _ctx("kalamar", "egi")["lure"]
	assert_eq(lure["id"], "egi_jig", "it fishes the squid jig")
	assert_eq(TerminalTackle.look_of(lure, "shrimp", true), "egi", "it looks like one at the rod tip")
	assert_eq(Baiting.kind_of(lure), "egi", "and is clipped on its snap")
	assert_eq(Baiting.strokes("egi"), Baiting.strokes("minnow"), "the same strokes as a minnow's snap")


func test_the_tackle_box_names_the_squid_only_for_the_squid_jig() -> void:
	for o: Dictionary in Baiting.options(Db.database(), Profile.save):
		var names := Baiting.good_for(Db.database(), o)
		if o["item_id"] == "egi_jig":
			assert_eq(names, ["SPECIES_SQUID"] as Array[String], "the jig is for squid")
		else:
			assert_true(not "SPECIES_SQUID" in names, "%s is not offered for squid" % o["item_id"])
