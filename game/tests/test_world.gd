extends "res://tests/test_base.gd"
## The top-down world: the area data, walking and the fishing markers.


func _area() -> WorldArea:
	var loaded := WorldArea.load_area("galata_bridge", Db.database())
	assert_true(loaded["ok"], "the Galata Bridge area loads: %s" % str(loaded["errors"]))
	return loaded["area"]


func test_the_area_links_to_the_spot_and_is_consistent() -> void:
	var a := _area()
	assert_eq(a.spot_id, "galata_bridge", "the spot")
	# A rented boat (R23) has no marker on the bridge.
	var positions: Array = (Db.record("spot", a.spot_id)["positions"] as Array).filter(func(p: Dictionary) -> bool: return p.get("stage", "") != "boat")
	assert_eq(a.markers.size(), positions.size(), "one marker per standing position")
	for p: Dictionary in positions:
		var found := false
		for m: Dictionary in a.markers:
			if m["position_id"] == p["id"]:
				found = true
				assert_eq(m["facing"], p["facing"], "%s: the marker faces the way the position does" % p["id"])
		assert_true(found, "%s has a marker" % p["id"])
	assert_true(not a.blocked_at(a.start_m, 0.35), "the player starts on open ground")
	assert_true(a.blocked_at(Vector2(30.0, 50.0), 0.35), "the road is blocked")
	assert_true(a.blocked_at(Vector2(5.0, 50.0), 0.35), "the water is blocked")
	assert_true(a.blocked_at(Vector2(-1.0, 5.0), 0.35), "outside the area is blocked")
	assert_true(not a.blocked_at(Vector2(30.0, 10.0), 0.35), "the plazas at the ends are open, so the road can be crossed there")


func test_a_broken_area_is_reported() -> void:
	var db := Db.database()
	assert_true(not WorldArea.load_area("nowhere", db)["ok"], "a missing file is an error")
	var wrong := db.duplicate()
	wrong["spot"] = []
	var r := WorldArea.load_area("galata_bridge", wrong)
	assert_true(not r["ok"] and str(r["errors"]).contains("unknown spot"), "an area of an unknown spot is an error")


func test_walking_is_deterministic_and_stays_on_open_ground() -> void:
	var a := _area()
	var w := WorldWalk.new(a, Db.constants())
	var w2 := WorldWalk.new(a, Db.constants())
	var start := w.pos
	for i in 300:
		var stick := Vector2.from_angle(float(i) * 0.07)
		w.step(1.0 / 30.0, stick)
		w2.step(1.0 / 30.0, stick)
		assert_true(not a.blocked_at(w.pos, float(Db.constants()["WALK_RADIUS_M"]) - 0.001), "never inside blocked ground (step %d)" % i)
	assert_eq(w.pos, w2.pos, "same input, same walk")
	assert_true(w.pos != start, "the player moved")


func test_speed_is_the_constant_and_a_wall_is_slid_along() -> void:
	var a := _area()
	var k := Db.constants()
	var w := WorldWalk.new(a, k)
	w.teleport(Vector2(44.0, 40.0))
	for i in 30:
		w.step(1.0 / 30.0, Vector2.DOWN)
	assert_near(w.pos.y, 40.0 + float(k["WALK_M_PER_S"]), "one second at full stick covers the walking speed", 0.01)
	w.step(0.5, Vector2.DOWN)
	assert_near(w.pos.y, 40.0 + float(k["WALK_M_PER_S"]) + 0.3, "a long frame is clamped to 0.1 s", 0.01)
	w.teleport(Vector2(44.0, 40.0))
	for i in 90:
		w.step(1.0 / 30.0, Vector2(1.0, 0.0))
	assert_true(w.pos.x < 45.8 - float(k["WALK_RADIUS_M"]) + 0.001, "the water's edge stops the player")
	var y := w.pos.y
	for i in 30:
		w.step(1.0 / 30.0, Vector2(1.0, 1.0))
	assert_true(w.pos.y > y + 2.0, "and moving along it slides")
	w.teleport(Vector2(44.0, 40.0))
	w.step(0.1, Vector2(0.01, 0.0))
	assert_eq(w.pos, Vector2(44.0, 40.0), "a stick below the dead zone does not move")


func test_the_nearest_marker_is_found_within_reach() -> void:
	var a := _area()
	var w := WorldWalk.new(a, Db.constants())
	assert_true(w.nearest_marker().is_empty(), "nothing near the start")
	var m: Dictionary = a.markers[0]
	w.teleport(m["pos"] + Vector2(0.0, 1.0))
	assert_eq(w.nearest_marker()["position_id"], m["position_id"], "a marker within reach")
	w.teleport(m["pos"] + Vector2(0.0, float(Db.constants()["INTERACT_M"]) + 0.5))
	assert_true(w.nearest_marker().is_empty(), "and none out of reach")
	var east := a.markers[0]
	var west := a.markers[2]
	assert_true(east["pos"].x > west["pos"].x and east["facing"] == "E" and west["facing"] == "W", "the east marker is on the east walkway")


func test_the_world_screen_hands_a_request_to_fishing_and_takes_the_result_back() -> void:
	var world := WorldScreen.new()
	world.profile_path = ""
	world.conditions = {"slot": "dawn", "month": 5, "wind_dir": "NE", "wind_ms": 4}
	world.setup()
	assert_eq(world._canvas_tint.color, WorldScreen.TINT["dawn"], "the world is tinted for the slot")
	assert_true(world._glows.size() == 2 * world.area.lamps.size() and world._glows[0].visible, "both lanterns of every lamp glow at dawn")
	assert_eq(world._water_mats.size(), 2, "both water rects have the water shader")
	assert_true(world._tiles.has("plaza") and world._tiles.has("walkway") and world._tiles.has("road"), "the ground is tiled pixel art")
	assert_eq(world.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "and stays crisp when scaled up")
	assert_true(not world._crowd.is_empty(), "passers-by are out")
	assert_true(world.fishing_request().is_empty(), "no request away from a marker")
	world.walk.teleport(world.area.markers[2]["pos"] + Vector2(0.0, 0.5))
	world._process(0.016)
	assert_true(world._action.visible, "the action button shows at a marker")
	var got := []
	world.fish_requested.connect(func(request: Dictionary) -> void: got.append(request))
	world.fish()
	assert_eq(got.size(), 1, "fishing is requested")
	var request: Dictionary = got[0]
	assert_eq(request["position_id"], "karakoy_west", "for the marker's position")
	assert_eq(request["spot_id"], "galata_bridge", "at the area's spot")
	assert_eq(request["conditions"]["slot"], "dawn", "under the world's conditions")
	request["conditions"]["slot"] = "night"
	assert_eq(world.conditions["slot"], "dawn", "the request carries a copy")
	world.pause()
	assert_true(not world.visible and not world._cam.enabled, "the world sleeps while fishing")
	assert_true(not world._canvas_tint.visible and not world._lights.visible, "and its tint and lamp glow do not cover the fishing view")
	var result := Game.empty_result()
	result["casts"] = 3
	world.resume(result)
	assert_true(world.visible and world._cam.enabled and world._canvas_tint.visible, "and wakes up")
	assert_true(world._toast_s > 0.0 and world._toast.text.contains("3"), "with the trip in a toast")
	world.free()


func test_a_world_request_sets_the_fishing_screen_up() -> void:
	var world := WorldScreen.new()
	world.profile_path = ""
	world.conditions = {"slot": "night", "month": 11, "wind_dir": "S", "wind_ms": 5}
	world.setup()
	world.walk.teleport(world.area.markers[1]["pos"] + Vector2(0.0, 0.5))
	var request := world.fishing_request()
	var screen: FishingScreen = load("res://scenes/fishing/fishing_screen.tscn").instantiate()
	screen.request = request
	screen.setup("")
	assert_eq(screen.position_id, "eminonu_east", "fishing opens at the marker's position")
	assert_eq(screen.conditions["slot"], "night", "under the world's conditions")
	screen.free()
	world.free()


func test_the_world_strings_are_translated() -> void:
	for locale: String in ["en", "tr", "es"]:
		TranslationServer.set_locale(locale)
		for key: String in ["MAIN_WALK", "WORLD_FISH_HERE", "WORLD_WALK_HINT", "DBG_NEXT_MARKER"]:
			assert_true(TranslationServer.translate(key) != key, "%s has a %s translation" % [key, locale])
	TranslationServer.set_locale("en")


func test_the_shops_stand_on_open_ground_and_are_found_within_reach() -> void:
	var a := _area()
	assert_eq(a.shops.size(), 2, "a fishmonger and a tackle shop")
	var ids := []
	for sh: Dictionary in a.shops:
		ids.append(sh["id"])
		assert_true(not a.blocked_at(sh["pos"], 0.35), "%s stands on open ground" % sh["id"])
	assert_true("fishmonger" in ids and "tackle" in ids, "both kinds")
	var w := WorldWalk.new(a, Db.constants())
	assert_true(w.nearest_shop().is_empty(), "no shop near the start")
	w.teleport(a.shops[0]["pos"] + Vector2(0.0, 1.0))
	assert_eq(w.nearest_shop()["id"], a.shops[0]["id"], "a shop within reach")
	var broken := Db.database().duplicate()
	assert_true(WorldArea.load_area("galata_bridge", broken)["ok"], "the area still loads")


func test_the_action_button_opens_a_shop_before_it_fishes() -> void:
	var world := WorldScreen.new()
	world.profile_path = ""
	world.conditions = {"slot": "day", "month": 5, "wind_dir": "NE", "wind_ms": 2}
	world.setup()
	var fish_requests := []
	world.fish_requested.connect(func(request: Dictionary) -> void: fish_requests.append(request))
	world.walk.teleport(world.area.shops[0]["pos"] + Vector2(0.0, 1.0))
	world._process(0.016)
	assert_true(world._action.visible, "the action button shows at a shop")
	world.act()
	assert_true(world._shop.visible and world._shop.kind == world.area.shops[0]["id"], "the shop panel opens")
	assert_eq(fish_requests.size(), 0, "and nothing is fished")
	world._process(0.016)
	assert_true(not world._action.visible, "the button hides while the panel is open")
	world._shop.closed.emit()
	world._shop.visible = false
	world.walk.teleport(world.area.markers[0]["pos"] + Vector2(0.0, 0.5))
	world._process(0.016)
	world.act()
	assert_eq(fish_requests.size(), 1, "at a fishing marker the same button fishes")
	assert_true(world._wallet.text.contains("TL"), "the wallet shows money")
	world.free()


func test_the_shop_panel_sells_and_buys_through_the_save() -> void:
	Profile.open("")
	var save := Profile.save
	Inventory.add_fish(save, "lufer", 30.0, 0.4, "2026-11-17")
	Inventory.add_fish(save, "istavrit", 10.0, 0.02, "2026-11-17")
	var panel := ShopPanel.new()
	var changes := []
	panel.changed.connect(func() -> void: changes.append(1))
	panel.open("fishmonger")
	assert_true(panel.visible and panel._rows.get_child_count() >= 2, "a row per fish")
	var before := Economy.money(save)
	var rows := Economy.bag_fish(save, Db.shop(), Db.database()["species"])
	Economy.sell(save, Db.shop(), Db.database()["species"], int(rows[0]["index"]))
	assert_true(Economy.money(save) > before, "selling paid")
	panel.open("tackle")
	assert_true(panel._title.text != "", "the tackle shop has a title")
	save["money"] = 500
	var stock := Inventory.count(save, "lrf_soft")
	Economy.buy(save, Db.shop(), "lrf_soft")
	assert_eq(Inventory.count(save, "lrf_soft"), stock + 1, "buying adds a lure")
	panel.free()
	Profile.open("")
