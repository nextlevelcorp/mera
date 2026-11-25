extends "res://tests/test_base.gd"
## One walkable waterfront per country (owner decision 2026-11-25): Naples'
## Molo Beverello, and the world screen opening any area, not only Galata.


func _area(id: String) -> WorldArea:
	var loaded := WorldArea.load_area(id, Db.database())
	assert_true(loaded["ok"], "%s loads: %s" % [id, str(loaded["errors"])])
	return loaded["area"]


func test_naples_has_a_marker_for_every_position_of_its_spot() -> void:
	var area := _area("napoli_moli")
	var ids: Array[String] = []
	for m: Dictionary in area.markers:
		ids.append(String(m["position_id"]))
	for p: Dictionary in Db.record("spot", "napoli_moli")["positions"]:
		assert_true(ids.has(String(p["id"])), "a marker for %s" % p["id"])
	assert_true(area.road_axis == "x" and not area.trams, "a waterfront road along x, no tram")


func test_a_pier_is_open_over_the_water_but_not_its_edges() -> void:
	var area := _area("napoli_moli")
	assert_true(not area.blocked_at(Vector2(33.0, 50.0), 0.35), "the middle of the Molo San Vincenzo")
	assert_true(area.blocked_at(Vector2(37.5, 50.0), 0.35), "the water beside it")
	assert_true(area.blocked_at(Vector2(35.9, 50.0), 0.35), "too near its edge")


func test_anglers_walk_from_the_promenade_out_along_the_piers() -> void:
	var area := _area("napoli_moli")
	for m: Dictionary in area.markers:
		var target: Vector2 = m["pos"]
		var pos := NpcRoster.entry_point(target, area)
		for i in 4000:
			pos = NpcRoster.walk_step(pos, target, 0.05, area, 1.4)
			assert_true(not area.blocked_at(pos, 0.2), "never in the water (%s at %s)" % [m["position_id"], str(pos)])
			if pos.distance_to(target) < 0.01:
				break
		assert_true(pos.distance_to(target) < 0.01, "reaches %s (stopped at %s)" % [m["position_id"], str(pos)])


func test_each_place_has_its_own_people() -> void:
	var naples := NpcRoster.load_roster(_area("napoli_moli"))
	assert_true(naples["ok"], str(naples["errors"]))
	var ids: Array[String] = []
	for n: Dictionary in naples["npcs"]:
		ids.append(String(n["id"]))
	assert_true(ids.has("rosa") and ids.has("ciro") and ids.has("gennaro") and not ids.has("hasan"), "Naples' people only: %s" % str(ids))
	var galata := NpcRoster.load_roster(_area("galata_bridge"))
	assert_true(galata["ok"] and not galata["npcs"].any(func(n: Dictionary) -> bool: return n["id"] == "rosa"), "and Galata keeps its own")


func test_cars_drive_along_a_waterfront_road() -> void:
	var area := _area("napoli_moli")
	var cars := Crowd.cars(area, 12.0, "day", Db.constants())
	assert_true(not cars.is_empty(), "traffic by day")
	for c: Dictionary in cars:
		assert_true(is_equal_approx(float(c["y"]), 7.6) or is_equal_approx(float(c["y"]), 10.4), "in a lane of the road (y %.1f)" % float(c["y"]))
	assert_true(Crowd.trams(area, 12.0, Db.constants()).is_empty(), "no tram in Naples")
	var ferries := Crowd.ferries(area, 30.0, Db.constants())
	assert_true(ferries.size() == 1 and float(ferries[0]["y"]) == 72.0, "one ferry lane, beyond the piers")


func test_the_world_opens_naples_and_fishes_there() -> void:
	var world := WorldScreen.new()
	world.area_id = "napoli_moli"
	world.profile_path = ""
	world.conditions = {"slot": "evening", "month": 10, "wind_dir": "S", "wind_ms": 3}
	world.setup()
	assert_eq(world.area.id, "napoli_moli", "Naples is open")
	world.walk.teleport(world.area.markers[2]["pos"] + Vector2(-0.5, 0.0))
	var request := world.fishing_request()
	assert_eq(String(request.get("spot_id", "")), "napoli_moli", "fishing at the area's spot")
	assert_eq(String(request.get("position_id", "")), "napoli_beverello", "from the Molo Beverello")
	world.free()
