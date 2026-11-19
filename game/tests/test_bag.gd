extends "res://tests/test_base.gd"
## Roadmap R16: the bag screen.


func test_the_bag_lists_fish_tackle_money_and_skills() -> void:
	var save := SaveGame.fresh()
	save["money"] = 120
	Inventory.add_fish(save, "istavrit", 16.0, 0.05, "2026-11-19")
	Inventory.add_fish(save, "istavrit", 10.0, 0.01, "2026-11-19")   # undersize
	Inventory.add(save, "shrimp", 4)
	var l := BagPanel.lines(save)
	assert_true(String(l["money"]).contains("120"), "the money")
	assert_eq((l["fish"] as Array).size(), 2, "both fish")
	var undersize := 0
	for f: Dictionary in l["fish"]:
		if f["undersize"]:
			undersize += 1
			assert_true(String(f["text"]).contains(TranslationServer.translate("SHOP_UNDERSIZE")), "an undersize fish says it must go back")
	assert_eq(undersize, 1, "one is undersize")
	assert_true(int(l["fish_value"]) > 0, "the legal fish is worth something")
	var shrimp_line := ""
	for t: String in l["tackle"]:
		if t.begins_with(TranslationServer.translate("TACKLE_BAIT_SHRIMP")):
			shrimp_line = t
	assert_true(shrimp_line.ends_with("4"), "the shrimp count: %s" % shrimp_line)
	assert_true(String(l["skills"]).contains(TranslationServer.translate("SKILL_CAST")), "the skills")


func test_the_world_opens_the_bag_and_it_releases_an_undersize_fish() -> void:
	var world := WorldScreen.new()
	world.profile_path = ""
	world.conditions = {"slot": "day", "month": 10, "wind_dir": "NE", "wind_ms": 3}
	world.setup()
	Inventory.add_fish(Profile.save, "istavrit", 9.0, 0.01, "2026-11-19")
	var before := Inventory.fish_count(Profile.save)
	world._bag.open()
	assert_true(world._bag.visible, "the bag opens")
	world._process(0.016)
	assert_true(not world._action.visible, "the action button hides behind it")
	var released := false
	for f: Dictionary in BagPanel.lines(Profile.save)["fish"]:
		if f["undersize"]:
			Economy.release(Profile.save, int(f["index"]))
			released = true
			break
	assert_true(released and Inventory.fish_count(Profile.save) == before - 1, "an undersize fish goes back")
	world.free()
