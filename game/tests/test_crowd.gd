extends "res://tests/test_base.gd"
## The Stardew-style world (owner, 2026-11-18): a crowded, recognisable
## Galata Bridge. Crowd is pure scenery, so the rules checked here are that
## it is deterministic, stays on open ground and on its own lanes, and that
## the pixel art is built the same way every time.


func _area() -> WorldArea:
	return WorldArea.load_area("galata_bridge", Db.database())["area"]


func test_the_area_is_closed_by_buildings_and_crossed_at_zebra_crossings() -> void:
	var a := _area()
	assert_true(a.blocked_at(Vector2(30.0, 50.0), 0.35), "the road on the bridge is blocked")
	assert_true(a.blocked_at(Vector2(30.0, 30.0), 0.35) and not a.blocked_at(Vector2(30.0, 10.0), 0.35), "but open at the crossing")
	assert_true(a.blocked_at(Vector2(30.0, 7.0), 0.35), "the road runs on through the square")
	assert_true(a.blocked_at(Vector2(8.0, 2.0), 0.35) and a.blocked_at(Vector2(50.0, 108.0), 0.35), "buildings close both ends")
	assert_true(not a.blocked_at(Vector2(17.95, 10.0), 0.35), "the crossing joins the square at its kerb")
	var npc_entry := NpcRoster.entry_point(Vector2(15.0, 32.0), a)
	assert_true(not a.blocked_at(npc_entry, 0.2), "anglers enter on open ground")


func test_passers_by_are_deterministic_and_walk_on_open_ground() -> void:
	var a := _area()
	var k := Db.constants()
	var day := Crowd.passers_by(a, "day", 11, k)
	assert_eq(day.size(), int(k["CROWD_COUNT"]["day"]), "as many as the slot asks")
	assert_true(Crowd.passers_by(a, "night", 11, k).size() < day.size(), "fewer at night")
	assert_eq(str(Crowd.passers_by(a, "day", 11, k)), str(day), "the same seed gives the same street")
	for w: Dictionary in day:
		for t in [0.0, 13.0, 77.5, 301.0]:
			var at := Crowd.walker_at(w, t)
			var p: Vector2 = at["pos"]
			if p.y > 0.5 and p.y < a.size_m.y - 0.5:
				assert_true(not a.blocked_at(p, 0.2), "a passer-by at %s stands on open ground" % str(p))
		assert_eq(str(Crowd.walker_at(w, 42.0)), str(Crowd.walker_at(w, 42.0)), "position is a function of time")


func test_a_walker_turns_back_at_the_end_of_the_line() -> void:
	var w := {"from": Vector2(0, 0), "to": Vector2(0, 10), "speed": 1.0, "offset": 0.0}
	var out := Crowd.walker_at(w, 5.0)
	var back := Crowd.walker_at(w, 15.0)
	assert_true(is_equal_approx(out["pos"].y, 5.0) and out["facing"].y > 0.0, "out along the line")
	assert_true(is_equal_approx(back["pos"].y, 5.0) and back["facing"].y < 0.0, "and back the other way")


func test_trams_cars_and_ferries_keep_to_their_lanes() -> void:
	var a := _area()
	var k := Db.constants()
	var road: Rect2
	for r: Dictionary in a.rects:
		if r["kind"] == "road":
			road = r["rect"]
	var seen_tram := false
	for t in range(0, 140, 3):
		for tram: Dictionary in Crowd.trams(a, float(t), k):
			seen_tram = true
			assert_true(road.has_point(Vector2(tram["x"], road.get_center().y)), "a tram runs on the road")
		for car: Dictionary in Crowd.cars(a, float(t), "day", k):
			assert_true(road.has_point(Vector2(car["x"], road.get_center().y)), "a car drives on the road")
			assert_true(absf(car["x"] - 30.0) > 2.6, "and not on the tram tracks")
		for f: Dictionary in Crowd.ferries(a, float(t), k):
			var y: float = f["y"]
			assert_true(y > 20.0 and y < 90.0, "a ferry stays on the water")
	assert_true(seen_tram, "a tram comes by within two minutes")


func test_pixel_people_are_deterministic_sprites_in_four_directions() -> void:
	var pal := PixelArt.palette(5)
	assert_eq(str(pal), str(PixelArt.palette(5)), "the same seed gives the same look")
	var frames := PixelArt.person(pal)
	assert_eq(frames.size(), 12, "four directions of three frames")
	assert_eq(frames[0].get_size(), Vector2(16, 24), "16 x 24 pixel sprites")
	var img := frames[0].get_image()
	assert_eq(img.get_pixel(0, 0).a, 0.0, "with a clear background")
	var eye := img.get_pixel(6, 7)
	assert_true(absf(eye.r - PixelArt.OUTLINE.r) + absf(eye.g - PixelArt.OUTLINE.g) + absf(eye.b - PixelArt.OUTLINE.b) < 0.02, "and eyes facing the camera")
	assert_true(PixelArt.person(pal) == frames, "built once and cached")
	assert_eq(PixelArt.tile("cobble").get_size(), Vector2(16, 16), "ground tiles are one metre")
