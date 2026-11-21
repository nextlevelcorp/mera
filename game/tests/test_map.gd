extends "res://tests/test_base.gd"
## The map (R17, owner decision D6): a country, then a spot; the legal size
## belongs to the place.


func test_every_spot_names_a_known_jurisdiction() -> void:
	for s: Dictionary in Db.database()["spot"]:
		assert_true(not Regulations.jurisdiction(Db.database(), String(s.get("jurisdiction", ""))).is_empty(), "%s is under known rules" % s["id"])


func test_countries_with_spots_come_first_and_the_rest_are_coming() -> void:
	var list := MapModel.countries(Db.database())
	assert_eq(list[0]["country"], "TR", "Turkey, where the spots are, first")
	assert_eq((list[0]["spots"] as Array).size(), 2, "with Galata and Sarayburnu")
	var codes: Array[String] = []
	for c: Dictionary in list:
		codes.append(String(c["country"]))
	for code: String in ["ES", "IT", "PT", "GR"]:
		assert_true(code in codes, "%s is on the map with its rules" % code)
	for c: Dictionary in list:
		if c["country"] == "GR":
			assert_true(not c["official"], "Greece's rules are marked unofficial")


func test_the_chart_keeps_north_up_and_east_right() -> void:
	var spots := MapModel.spots_in(Db.database(), "TR")
	var b := MapModel.bounds(spots, 0.01)
	var rect := Rect2(0, 0, 800, 600)
	var galata := MapModel.chart_point(41.02, 28.973056, b, rect)
	var saray := MapModel.chart_point(41.01714, 28.98605, b, rect)
	assert_true(saray.x > galata.x, "Sarayburnu lies east of the bridge")
	assert_true(saray.y > galata.y, "and a little south, lower on the chart")
	for s: Dictionary in spots:
		assert_true(rect.has_point(MapModel.chart_point(float(s["lat"]), float(s["lon"]), b, rect)), "%s is on the chart" % s["id"])


func test_an_undersize_fish_is_judged_by_the_rules_of_the_place() -> void:
	var pos: String = Db.database()["spot"][0]["positions"][0]["id"]
	var s := FishingSession.new(Db.database(), Db.constants(), "lrf", pos, {"slot": "day", "month": 10, "wind_dir": "NE", "wind_ms": 3})
	assert_eq(s.jurisdiction(), "tr_national", "Galata is under Turkish rules")
	(s.trip["catches"] as Array).append({"species_id": "istavrit", "length_cm": 13.0, "weight_kg": 0.02, "kept": true})
	assert_eq(s.undersize_count(1), 0, "a 13 cm horse mackerel is legal in Turkey (12 cm), though not in Andalusia (15 cm)")


func test_the_map_screen_goes_from_a_country_to_a_spot() -> void:
	var m := MapScreen.new()
	m.size = Vector2(1280, 720)
	m.open_countries()
	m.open_country("TR")
	assert_eq(m.country, "TR", "Turkey's chart")
	var got := [""]
	m.spot_chosen.connect(func(id: String) -> void: got[0] = id)
	m.select("sarayburnu")
	assert_true(m._info.visible, "a pin opens the spot's card")
	m._go.pressed.emit()
	assert_eq(got[0], "sarayburnu", "and Fish here goes there")
	m.back()
	m.back()
	assert_eq(m.country, "", "back to the countries")
	m.free()
