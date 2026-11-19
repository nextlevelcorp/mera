extends "res://tests/test_base.gd"
## Roadmap R18: the rig in hand looks like the rig chosen.


func test_every_rod_has_its_own_colour() -> void:
	var seen := {}
	for r: Dictionary in Db.database()["rod"]:
		assert_true(r.has("blank_colour"), "%s has a blank colour" % r["id"])
		seen[r["blank_colour"]] = true
	assert_eq(seen.size(), Db.database()["rod"].size(), "no two rods look alike")


func test_changing_the_rig_changes_the_rod_in_hand() -> void:
	var scr := FishingScreen.new()
	scr.request = Game.fishing_request("", "", "lrf", {"slot": "day", "month": 10, "wind_dir": "NE", "wind_ms": 3})
	scr.setup("")
	var light_len := scr.rod_length_factor()
	var light_col: Color = scr._water.rig3d._blank_mat.albedo_color
	var light_thick: float = scr._water.rig3d._thick
	scr.set_rig("float", scr.position_id)
	assert_true(scr.rod_length_factor() > light_len, "the 4 m float rod looks longer than the light rod")
	assert_true(scr._water.rig3d._blank_mat.albedo_color != light_col, "and has another colour")
	scr.set_rig("spin", scr.position_id)
	assert_true(scr._water.rig3d._thick > light_thick, "the spinning rod is thicker than the light rod")
	assert_true(Rig3D.look_reel_scale(4000) > Rig3D.look_reel_scale(2000), "a bigger reel looks bigger")
	scr.free()
