extends "res://tests/test_base.gd"
## Each place's own skyline (owner, 2026-11-24), from tools/map/build_horizons.py.


func test_every_position_has_a_skyline() -> void:
	for spot: Dictionary in Db.database()["spot"]:
		for pos: Dictionary in spot["positions"]:
			var prof := Horizon.profile(String(pos["id"]))
			assert_true(not prof.is_empty(), "%s has a skyline" % pos["id"])
			if not prof.is_empty():
				assert_eq((prof["elev_mrad"] as Array).size(), 360, "%s: one value per degree" % pos["id"])


func test_vesuvius_stands_east_of_the_naples_piers() -> void:
	var prof := Horizon.profile("napoli_san_vincenzo")
	assert_true(Horizon.elevation(prof, 95.0) > 0.06, "the volcano, 14 km east, stands high (%.3f rad)" % Horizon.elevation(prof, 95.0))
	assert_true(Horizon.elevation(prof, 95.0) > Horizon.elevation(prof, 125.0), "and falls away to its south")


func test_open_sea_has_no_land_on_the_horizon() -> void:
	var prof := Horizon.profile("cascais_pier")
	assert_eq(Horizon.elevation(prof, 180.0), 0.0, "Cascais looks south over the open Atlantic")


func test_the_asian_shore_faces_the_bridge() -> void:
	var prof := Horizon.profile("karakoy_east")
	assert_true(Horizon.elevation(prof, 90.0) > 0.01, "Üsküdar across the Bosphorus")
	assert_eq(int((prof["urban"] as Array)[90]), 1, "and it is town")


func test_the_texture_encodes_the_profile_by_bearing() -> void:
	var prof := Horizon.profile("napoli_san_vincenzo")
	var img := Horizon.image(prof)
	assert_eq(img.get_width(), 360, "a pixel per degree")
	assert_true(absf(img.get_pixel(95, 0).r - Horizon.elevation(prof, 95.0) / Horizon.MAX_RAD) < 0.01, "red is the height")
	assert_eq(Horizon.bearing("E"), deg_to_rad(90.0), "east is 90 degrees")
