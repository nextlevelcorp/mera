extends "res://tests/test_base.gd"
## Roadmap R10: the people of the world and the neighbours of the fishing view.


func _area() -> WorldArea:
	return WorldArea.load_area("galata_bridge", Db.database())["area"]


func test_the_roster_is_valid_and_labelled() -> void:
	var r := NpcRoster.load_roster(_area())
	assert_true(r["ok"], "the roster loads: %s" % str(r["errors"]))
	var anglers := 0
	for n: Dictionary in r["npcs"]:
		if n["role"] == "angler":
			anglers += 1
		assert_true(TranslationServer.translate(n["name_key"]) != "", "%s has a name" % n["id"])
	assert_true(anglers >= 3, "there are anglers on the bridge")


func test_plans_follow_the_slot_and_put_anglers_at_the_rail() -> void:
	var a := _area()
	var npcs: Array = NpcRoster.load_roster(a)["npcs"]
	for n: Dictionary in npcs:
		for slot in NpcRoster.SLOTS:
			var p := NpcRoster.plan(n, slot, a)
			assert_eq(p, NpcRoster.plan(n, slot, a), "%s %s: the same plan every time" % [n["id"], slot])
			if p["present"]:
				assert_true(not a.blocked_at(p["pos"], 0.2), "%s %s stands on open ground" % [n["id"], slot])
				if p["fishing"]:
					assert_true(p["facing"] in ["E", "W"], "an angler faces the water")
	var present_at_night := 0
	var present_by_day := 0
	for n: Dictionary in npcs:
		if n["role"] == "angler":
			present_at_night += 1 if NpcRoster.plan(n, "night", a)["present"] else 0
			present_by_day += 1 if NpcRoster.plan(n, "day", a)["present"] else 0
	assert_true(present_at_night != present_by_day or present_at_night < npcs.size(), "the bridge changes with the hour")


func test_walking_goes_round_the_road_and_arrives() -> void:
	var a := _area()
	var start := Vector2(15.0, 50.0)   # the west walkway
	var target := Vector2(45.0, 40.0)  # the east walkway, across the road
	var pos := start
	var t := 0.0
	while pos.distance_to(target) > 0.01 and t < 120.0:
		pos = NpcRoster.walk_step(pos, target, 0.1, a, 1.4)
		assert_true(not a.blocked_at(pos, 0.15), "never on the road or in the water (%.1f, %.1f)" % [pos.x, pos.y])
		t += 0.1
	assert_true(pos.distance_to(target) <= 0.01, "arrives (%.1f s)" % t)
	assert_true(t < 90.0, "by the nearer plaza, not wandering")


func test_the_fishing_request_brings_the_neighbours_on_that_side() -> void:
	var world := WorldScreen.new()
	world.profile_path = ""
	world.conditions = {"slot": "evening", "month": 10, "wind_dir": "SW", "wind_ms": 3}
	world.setup()
	world.settle_npcs()
	world.walk.teleport(world.area.markers[0]["pos"] + Vector2(0.0, 0.5))   # karakoy_east
	var req := world.fishing_request()
	var ids := []
	for nb: Dictionary in req["neighbours"]:
		ids.append(nb["id"])
		assert_true((nb["jacket"] as Color).a > 0.0, "with their jacket colour")
	assert_true("hasan" in ids and "nuri" in ids, "the anglers fishing on the east walkway come along (%s)" % str(ids))
	assert_true(not ("recep" in ids), "vendors do not fish")
	world.walk.teleport(world.area.markers[3]["pos"] + Vector2(0.0, 0.5))   # eminonu_west
	assert_eq((world.fishing_request()["neighbours"] as Array).size(), 0, "nobody fishes the west side in the evening")
	world.free()


func test_the_fishing_view_shows_exactly_the_neighbours_it_was_given() -> void:
	var screen: FishingScreen = load("res://scenes/fishing/fishing_screen.tscn").instantiate()
	screen.request = Game.fishing_request("", "", "", {}, [{"id": "hasan", "jacket": Color(0.5, 0.1, 0.1)}, {"id": "nuri", "jacket": Color(0.1, 0.5, 0.1)}])
	screen.setup("")
	assert_eq(screen._neighbours.people.size(), 2, "two neighbours")
	assert_eq(screen._water.stage.visible_people(), 2, "and two figures on the bridge")
	screen.free()
	var alone: FishingScreen = load("res://scenes/fishing/fishing_screen.tscn").instantiate()
	alone.request = Game.fishing_request("", "", "", {}, [])
	alone.setup("")
	assert_eq(alone._neighbours.people.size(), 0, "nobody else: an empty rail")
	alone.free()
	var direct: FishingScreen = load("res://scenes/fishing/fishing_screen.tscn").instantiate()
	direct.setup("")
	assert_eq(direct._neighbours.people.size(), NeighborAnglers.COUNT, "opened from the title, the usual four")
	direct.free()
