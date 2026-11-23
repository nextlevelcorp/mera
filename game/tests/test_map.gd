extends "res://tests/test_base.gd"
## The map (R17, owner decision D6): a country, then a spot; the legal size
## belongs to the place.


func test_every_spot_names_a_known_jurisdiction() -> void:
	for s: Dictionary in Db.database()["spot"]:
		assert_true(not Regulations.jurisdiction(Db.database(), String(s.get("jurisdiction", ""))).is_empty(), "%s is under known rules" % s["id"])


func test_countries_with_spots_come_first_and_the_rest_are_coming() -> void:
	var list := MapModel.countries(Db.database())
	assert_eq(list[0]["country"], "TR", "Turkey, where the spots are, first")
	assert_eq((list[0]["spots"] as Array).size(), 3, "with Galata, Sarayburnu and İzmir Kordon")
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


func test_the_land_file_covers_the_countries_and_says_where_it_comes_from() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map/land.json"))
	assert_true(String(raw["source"]).contains("Natural Earth"), "Natural Earth, public domain")
	var rings: Array[PackedVector2Array] = []
	for flat: Array in raw["rings"]:
		var ring := PackedVector2Array()
		for i in range(0, flat.size() - 1, 2):
			ring.append(Vector2(float(flat[i]), float(flat[i + 1])))
		rings.append(ring)
	var b := MapModel.bounds(MapModel.spots_in(Db.database(), "TR"), 0.05)
	assert_true(not MapModel.rings_in(rings, b).is_empty(), "there is coast round Istanbul")
	var pieces := 0
	var view := PackedVector2Array([Vector2(b[0], b[1]), Vector2(b[2], b[1]), Vector2(b[2], b[3]), Vector2(b[0], b[3])])
	for ring: PackedVector2Array in MapModel.rings_in(rings, b):
		pieces += Geometry2D.intersect_polygons(ring, view).size()
	assert_true(pieces >= 2, "Europe and Asia on either side of the Strait (%d pieces)" % pieces)


func test_izmir_has_its_own_fish_and_its_own_water() -> void:
	var cond := {"slot": "night", "month": 11, "wind_dir": "NE", "wind_ms": 3}
	var ctx := FightSetup.build(Db.database(), "kalamar", "egi", "izmir_pasaport", 0.5, cond)
	assert_eq(ctx["spot"]["id"], "izmir_kordon", "Pasaport is on the Kordon")
	var w := WaitSim.new(ctx, Db.constants(), Db.database()["species"], 20.0, 1)
	assert_true(float(w._rates["kalamar"]["rate_interest"]) > 0.0, "squid in the bay (Ulaş et al. 2019)")
	assert_true(not w._rates.has("lufer") or float(w._rates["lufer"]["rate_interest"]) == 0.0, "no bluefish: the bay's shore anglers did not report it")
	var galata := FightSetup.build(Db.database(), "istavrit", "lrf", "karakoy_east", 0.5, {"slot": "day", "month": 1, "wind_dir": "NE", "wind_ms": 3})
	var izmir := FightSetup.build(Db.database(), "istavrit", "lrf", "izmir_konak", 0.5, {"slot": "day", "month": 1, "wind_dir": "NE", "wind_ms": 3})
	assert_true(float(izmir["spot"]["water_temp_by_month_c"][0]) > float(galata["spot"]["water_temp_by_month_c"][0]), "the Aegean is warmer in January than the Marmara (MGM)")


func test_close_pins_are_spread_so_each_can_be_tapped() -> void:
	var shown := MapModel.spread([Vector2(100, 100), Vector2(104, 102), Vector2(400, 300)] as Array[Vector2], 46.0)
	assert_true(shown[0].distance_to(shown[1]) >= 46.0 * 0.9 * 1.9, "the two close pins move apart (%.0f px)" % shown[0].distance_to(shown[1]))
	assert_eq(shown[2], Vector2(400, 300), "a lone pin stays put")


func test_spain_has_three_spots_with_its_own_rules_and_fish() -> void:
	var spots := MapModel.spots_in(Db.database(), "ES")
	assert_eq(spots.size(), 3, "Puerto Banús, Maro and Almería")
	var cond := {"slot": "dawn", "month": 10, "wind_dir": "W", "wind_ms": 3}
	var s := FishingSession.new(Db.database(), Db.constants(), "float", "almeria_sea", cond)
	assert_eq(s.jurisdiction(), "es_andalusia", "Andalusia's rules hold on the Almería breakwater")
	(s.trip["catches"] as Array).append({"species_id": "sargoz", "length_cm": 22.0, "weight_kg": 0.17, "kept": true})
	assert_eq(s.undersize_count(1), 1, "a 22 cm white sea bream is legal in Turkey (21 cm) but goes back in Andalusia (23 cm)")
	var ctx := FightSetup.build(Db.database(), "sargoz", "float", "maro_rocks", 0.5, cond)
	var w := WaitSim.new(ctx, Db.constants(), Db.database()["species"], 15.0, 1)
	assert_true(float(w._rates["sargoz"]["rate_interest"]) > 0.0, "white sea bream on the Maro rocks (Junta de Andalucía)")
	assert_true(not w._rates.has("istavrit") or float(w._rates["istavrit"]["rate_interest"]) == 0.0, "no horse mackerel listed there")


func test_italy_has_three_spots_under_italian_rules() -> void:
	var spots := MapModel.spots_in(Db.database(), "IT")
	assert_eq(spots.size(), 3, "Naples, Trieste and Genoa")
	var s := FishingSession.new(Db.database(), Db.constants(), "lrf", "trieste_tip", {"slot": "dawn", "month": 10, "wind_dir": "NE", "wind_ms": 3})
	(s.trip["catches"] as Array).append({"species_id": "levrek", "length_cm": 22.0, "weight_kg": 0.13, "kept": true})
	assert_eq(s.undersize_count(1), 0, "a 22 cm sea bass is legal in Italy (Article 87: 20 cm), though not in Turkey (25 cm)")
	var ctx := FightSetup.build(Db.database(), "palamut", "spin", "trieste_tip", 0.5, {"slot": "dawn", "month": 9, "wind_dir": "NE", "wind_ms": 3})
	var w := WaitSim.new(ctx, Db.constants(), Db.database()["species"], 15.0, 1)
	assert_true(not w._rates.has("lufer") or float(w._rates["lufer"]["rate_interest"]) == 0.0, "no bluefish at Trieste (no GBIF record)")


func test_greece_and_portugal_have_three_spots_each() -> void:
	assert_eq(MapModel.spots_in(Db.database(), "GR").size(), 3, "Thessaloniki, Kavala, Patras")
	assert_eq(MapModel.spots_in(Db.database(), "PT").size(), 3, "Sesimbra, Lagos, Cascais")
	var s := FishingSession.new(Db.database(), Db.constants(), "lrf", "cascais_pier", {"slot": "dawn", "month": 1, "wind_dir": "N", "wind_ms": 3})
	(s.trip["catches"] as Array).append({"species_id": "levrek", "length_cm": 30.0, "weight_kg": 0.3, "kept": true})
	assert_eq(s.undersize_count(1), 1, "a 30 cm sea bass goes back in Portugal (36 cm)")
	var lisbon := FightSetup.build(Db.database(), "levrek", "lrf", "cascais_pier", 0.5, {"slot": "day", "month": 8, "wind_dir": "N", "wind_ms": 3})
	var kavala := FightSetup.build(Db.database(), "levrek", "lrf", "kavala_quay", 0.5, {"slot": "day", "month": 8, "wind_dir": "N", "wind_ms": 3})
	assert_true(float(lisbon["spot"]["water_temp_by_month_c"][7]) < float(kavala["spot"]["water_temp_by_month_c"][7]) - 5.0, "the Atlantic at Cascais is far cooler in August than the Aegean (NOAA)")


func test_the_debug_spot_list_names_every_spot_under_its_country() -> void:
	var picked := [""]
	var menu: PopupMenu = load("res://debug/debug_menu.gd").spot_picker(func(id: String) -> void: picked[0] = id)
	var spots := 0
	for i in menu.item_count:
		if not menu.is_item_separator(i):
			spots += 1
	assert_eq(spots, Db.database()["spot"].size(), "every spot is in the list")
	assert_true(menu.is_item_separator(0), "under a country heading")
	menu.index_pressed.emit(menu.item_count - 1)
	assert_true(picked[0] != "", "picking one gives its id (%s)" % picked[0])
