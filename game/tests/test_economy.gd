extends "res://tests/test_base.gd"
## Roadmap R8: fish prices, selling, the tackle shop, lure stock.


func _species() -> Array:
	return Db.database()["species"]


func _bag_with(save: Dictionary, fish: Array) -> void:
	for f: Array in fish:
		Inventory.add_fish(save, f[0], f[1], f[2], "2026-11-17")


func test_the_catalogue_loads_and_is_a_design_fill() -> void:
	var loaded := Economy.load_catalog(Db.database())
	assert_true(loaded["ok"], "the shop catalogue is valid: %s" % str(loaded["errors"]))
	assert_true(loaded["catalog"]["design_fill"] == true, "labelled design fill")
	for l: Dictionary in loaded["catalog"]["lures"]:
		assert_true(Economy.lure_price(loaded["catalog"], l["id"]) > 0, "%s is for sale" % l["id"])
	# Every rig's lure is in the shop, so a player who runs dry can buy more.
	for rig in FightSetup.TACKLES:
		assert_true(Economy.lure_price(loaded["catalog"], FightSetup.lure_id(rig)) > 0, "the %s rig's lure is sold" % rig)
	var broken := Economy.load_catalog({"lure": [], "species": []})
	assert_true(not broken["ok"], "a catalogue that names unknown lures or species is an error")


func test_a_fish_is_worth_its_weight_and_an_undersize_fish_nothing() -> void:
	var catalog := Db.shop()
	var luefer := Db.record("species", "lufer")
	var min_len := float(luefer["regulation"]["min_length_cm"])
	var v := Economy.fish_value(catalog, luefer, min_len + 5.0, 0.5)
	assert_eq(v, int(roundf(0.5 * float(catalog["price_per_kg"]["lufer"]))), "weight times the price per kg")
	assert_true(Economy.fish_value(catalog, luefer, min_len + 5.0, 1.0) > v, "a heavier fish is worth more")
	assert_eq(Economy.fish_value(catalog, luefer, min_len - 1.0, 0.3), 0, "under the legal size it cannot be sold")
	assert_true(Economy.fish_value(catalog, luefer, min_len + 1.0, 0.0001) >= 1, "a legal fish is worth at least one")


func test_selling_moves_fish_out_and_money_in() -> void:
	var catalog := Db.shop()
	var s := SaveGame.fresh()
	_bag_with(s, [["lufer", 30.0, 0.3], ["istavrit", 11.0, 0.03], ["istavrit", 17.0, 0.05]])
	Inventory.add(s, "lrf_soft", 2)
	var rows := Economy.bag_fish(s, catalog, _species())
	assert_eq(rows.size(), 3, "three fish in the bag")
	assert_true(rows[1]["undersize"] and int(rows[1]["value"]) == 0, "the small horse mackerel is under the legal size")
	assert_eq(Economy.sell(s, catalog, _species(), int(rows[1]["index"])), 0, "an undersize fish is not bought")
	assert_eq(Inventory.fish_count(s), 3, "and stays in the bag")
	var got := Economy.sell(s, catalog, _species(), int(rows[0]["index"]))
	assert_true(got > 0 and Economy.money(s) == got, "selling pays")
	assert_eq(Inventory.fish_count(s), 2, "the fish is gone")
	assert_eq(Inventory.count(s, "lrf_soft"), 2, "lures are not fish and stay")
	var all := Economy.sell_all(s, catalog, _species())
	assert_eq(int(all["count"]), 1, "sell all takes only what can be sold")
	assert_eq(Economy.money(s), got + int(all["money"]), "and adds it up")
	assert_eq(Inventory.fish_count(s), 1, "the undersize fish is left")
	Economy.release(s, int(Economy.bag_fish(s, catalog, _species())[0]["index"]))
	assert_eq(Inventory.fish_count(s), 0, "releasing it empties the bag of fish")
	assert_eq(Inventory.count(s, "lrf_soft"), 2, "without touching the lures")
	assert_true(SaveGame.is_valid(s), "the save stays valid")


func test_sell_all_from_a_big_bag_keeps_indexes_straight() -> void:
	var catalog := Db.shop()
	var s := SaveGame.fresh()
	for i in 12:
		Inventory.add_fish(s, "lufer", 20.0 + i, 0.2, "2026-11-17")
		Inventory.add(s, "lrf_soft", 1)
	var all := Economy.sell_all(s, catalog, _species())
	assert_eq(int(all["count"]), 12, "every legal fish sold exactly once")
	assert_eq(Inventory.fish_count(s), 0, "none left")
	assert_eq(Inventory.count(s, "lrf_soft"), 12, "no lure was sold by mistake")


func test_buying_needs_money_and_adds_to_the_stack() -> void:
	var catalog := Db.shop()
	var s := SaveGame.fresh() if false else SaveGame.fresh()
	var price := Economy.lure_price(catalog, "spin_minnow")
	assert_true(not Economy.buy(s, catalog, "spin_minnow"), "no money, no lure")
	assert_eq(Inventory.count(s, "spin_minnow"), 0, "nothing arrived")
	s["money"] = price * 2 + 5
	assert_true(Economy.buy(s, catalog, "spin_minnow", 2), "two lures for the price of two")
	assert_eq(Economy.money(s), 5, "the change is kept")
	assert_eq(Inventory.count(s, "spin_minnow"), 2, "and they are in the bag")
	assert_true(not Economy.buy(s, catalog, "spin_minnow", 1), "five is not enough for a third")
	assert_true(not Economy.buy(s, catalog, "harpoon", 1), "an item that is not sold cannot be bought")
	assert_true(not Economy.buy(s, catalog, "spin_minnow", 0), "and zero is not a purchase")
	assert_eq(Inventory.items(s).size(), 1, "one stack")


func test_the_welcome_stock_is_given_once() -> void:
	var catalog := Db.shop()
	var s := SaveGame.fresh()
	assert_true(Economy.give_starting_stock(s, catalog), "a new save gets its lures")
	for id: String in catalog["starting_stock"]:
		assert_eq(Inventory.count(s, id), int(catalog["starting_stock"][id]), "starting stock of %s" % id)
	Economy.lose_lure(s, "lrf_soft")
	assert_true(not Economy.give_starting_stock(s, catalog), "and not a second time")
	assert_eq(Inventory.count(s, "lrf_soft"), int(catalog["starting_stock"]["lrf_soft"]) - 1, "a lost lure is not given back")
	assert_true(SaveGame.is_valid(s), "the save stays valid")


func test_profile_open_gives_the_stock_to_an_old_save_once() -> void:
	var path := "user://test_profile_v2_shop.json"
	var old := SaveGame.fresh()
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	Profile.open(path)
	assert_true(Inventory.count(Profile.save, "lrf_soft") > 0, "a save from before the shop gets lures on the first open")
	var n := Inventory.count(Profile.save, "lrf_soft")
	Profile.open(path)
	assert_eq(Inventory.count(Profile.save, "lrf_soft"), n, "and not again on the next")
	DirAccess.remove_absolute(path)
	Profile.open("")


func test_a_broken_line_costs_a_lure_and_no_lure_means_no_cast() -> void:
	var screen: FishingScreen = load("res://scenes/fishing/fishing_screen.tscn").instantiate()
	screen.setup("")
	var id := screen.lure_id()
	var start := screen.lure_stock()
	assert_true(start > 0, "a new player has lures for the first rig (%d)" % start)
	screen.begin_charge()
	assert_eq(screen.phase, FishingScreen.Phase.CHARGE, "with a lure the cast starts")
	screen._set_phase(FishingScreen.Phase.READY)
	var species_id: String = Db.database()["spot"][0]["species"][0]["species_id"]
	screen.cast_with_power(0.8)
	screen._land_lure()
	screen._start_fight({"species_id": species_id, "u": 0.5, "timing_quality": 0.9, "hook": 0.9, "distance_m": 12.0})
	# Pull as hard as possible on a strong drag: the line goes.
	for i in 3000:
		if screen.phase != FishingScreen.Phase.FIGHT:
			break
		screen.set_fight_input(true, 0.0, true, 1.0)
		screen._step_fight(1.0 / 30.0)
	var broke: bool = screen._result["outcome"] in [FightSim.OUTCOME_LINE_BREAK, FightSim.OUTCOME_LEADER_CUT]
	if broke:
		assert_eq(screen.lure_stock(), start - 1, "a broken line takes one lure")
		assert_true(screen._result["lure_lost"], "and the result says so")
	else:
		assert_eq(screen.lure_stock(), start, "a fish that was not lost costs no lure")
	# Empty the bag of this lure: no cast.
	Inventory.remove(screen.save, id, screen.lure_stock())
	screen._hud = {}
	screen._set_phase(FishingScreen.Phase.READY)
	screen.begin_charge()
	assert_eq(screen.phase, FishingScreen.Phase.READY, "no lure, no cast")
	assert_true(screen._toast_s > 0.0, "with a toast that says why")
	screen.free()
