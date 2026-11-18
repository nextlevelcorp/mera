extends "res://tests/test_base.gd"
## Roadmap R11: quests given by the people of the world.


func _quests() -> Array:
	var area: WorldArea = WorldArea.load_area("galata_bridge", Db.database())["area"]
	var npcs: Array = NpcRoster.load_roster(area)["npcs"]
	var q := Quests.load_quests(npcs, Db.database(), Db.shop())
	assert_true(q["ok"], "the quests load: %s" % str(q["errors"]))
	return q["quests"]


func _save() -> Dictionary:
	return SaveGame.fresh()


func test_quests_are_valid_labelled_and_translated() -> void:
	var quests := _quests()
	assert_true(quests.size() >= 4, "several quests")
	for q: Dictionary in quests:
		for key: String in ["title_key", "ask_key", "thanks_key"]:
			assert_true(TranslationServer.translate(q[key]) != q[key], "%s: %s is translated" % [q["id"], key])
		var species := Db.record("species", q["need"]["species"])
		assert_true(Quests.min_length(q, species) >= float(species["regulation"]["min_length_cm"]), "%s never asks for an undersize fish" % q["id"])


func test_a_giver_offers_quests_one_after_another() -> void:
	var quests := _quests()
	var save := _save()
	var first := Quests.current(quests, "hasan", save)
	assert_eq(first["id"], "hasan_supper", "Hasan starts with supper")
	assert_true(not Quests.is_active(save, first["id"]), "not taken yet")
	Quests.accept(save, first)
	Quests.accept(save, first)
	assert_eq((save["quests"]["active"] as Array).size(), 1, "accepting twice takes it once")
	assert_true(Quests.current(quests, "selma", save).is_empty(), "someone with no quests has none")


func test_handing_over_needs_enough_legal_fish_and_pays() -> void:
	var quests := _quests()
	var save := _save()
	var k := Db.constants()
	var q := Quests.current(quests, "hasan", save)
	var species := Db.record("species", "istavrit")
	Quests.accept(save, q)
	Inventory.add_fish(save, "istavrit", 18.0, 0.06, "2026-11-18")
	Inventory.add_fish(save, "istavrit", 10.0, 0.01, "2026-11-18")   # undersize: does not count
	Inventory.add_fish(save, "lufer", 30.0, 0.3, "2026-11-18")
	Inventory.add_fish(save, "istavrit", 15.0, 0.04, "2026-11-18")
	assert_true(not Quests.can_complete(save, q, species), "two legal fish are not three")
	assert_true(not Quests.complete(save, q, species, k)["ok"], "and cannot be handed over")
	Inventory.add_fish(save, "istavrit", 14.0, 0.03, "2026-11-18")
	assert_true(Quests.can_complete(save, q, species), "three legal fish are enough")
	var money := Economy.money(save)
	var lures := Inventory.count(save, "capari_rig")
	var done := Quests.complete(save, q, species, k)
	assert_true(done["ok"], "handed over")
	assert_eq(Inventory.count(save, "fish:istavrit"), 1, "the three legal fish left the bag, the undersize one stayed")
	assert_eq(Inventory.count(save, "fish:lufer"), 1, "other fish stay")
	assert_eq(Economy.money(save), money + int(q["reward"]["money"]), "the money is paid")
	assert_eq(Inventory.count(save, "capari_rig"), lures + int(q["reward"]["items"]["capari_rig"]), "the lures are given")
	assert_eq(Progress.xp(save, "cast"), int(q["reward"]["xp"]["cast"]), "the experience is given")
	assert_true(Quests.is_done(save, q["id"]) and not Quests.is_active(save, q["id"]), "the quest is done")
	assert_eq(Quests.current(quests, "hasan", save)["id"], "hasan_bluefish", "and Hasan has the next one")


func test_a_quest_minimum_above_the_legal_size_counts() -> void:
	var quests := _quests()
	var save := _save()
	var q: Dictionary = {}
	for x: Dictionary in quests:
		if x["id"] == "hasan_bluefish":
			q = x
	var species := Db.record("species", "lufer")
	Quests.accept(save, q)
	Inventory.add_fish(save, "lufer", 20.0, 0.1, "2026-11-18")
	assert_true(not Quests.can_complete(save, q, species), "a legal but small bluefish is not enough")
	Inventory.add_fish(save, "lufer", 26.0, 0.2, "2026-11-18")
	assert_true(Quests.can_complete(save, q, species), "a 26 cm one is")


func test_nearest_person_in_reach() -> void:
	var people := {"a": Vector2(1, 0), "b": Vector2(0.5, 0), "c": Vector2(5, 0)}
	assert_eq(NpcRoster.nearest(Vector2.ZERO, people, 2.0), "b", "the nearest in reach")
	assert_eq(NpcRoster.nearest(Vector2(10, 10), people, 2.0), "", "nobody far away")


func test_talking_in_the_world_takes_and_completes_a_quest() -> void:
	var world := WorldScreen.new()
	world.profile_path = ""
	world.conditions = {"slot": "day", "month": 10, "wind_dir": "NE", "wind_ms": 3}
	world.setup()
	world.settle_npcs()
	var st: Dictionary = world._npc_state["hasan"]
	world.walk.teleport((st["pos"] as Vector2) + Vector2(-1.0, 0.0))
	world._process(0.016)
	assert_eq(world.talk_target().get("id", ""), "hasan", "Hasan is in reach")
	assert_true(world._action.visible and world._action.text.contains("Hasan"), "the action button offers to talk")
	world.act()
	assert_true(world._talk.visible and world._talk.quest["id"] == "hasan_supper", "the talk panel shows his quest")
	world._talk._on_act()
	assert_true(Quests.is_active(Profile.save, "hasan_supper"), "accepted")
	world._process(0.016)
	assert_true(world._journal.text.contains(tr("QUEST_HASAN_SUPPER_TITLE")), "the HUD lists it")
	for i in 3:
		Inventory.add_fish(Profile.save, "istavrit", 16.0, 0.05, "2026-11-18")
	world._talk._refresh()
	assert_true(not world._talk._act.disabled, "hand over is possible with the fish")
	world._talk._on_act()
	assert_true(Quests.is_done(Profile.save, "hasan_supper"), "done")
	assert_true(world._toast_s > 0.0, "with a toast")
	world.free()
