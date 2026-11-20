extends "res://tests/test_base.gd"
## The fishing controls drawn as instruments (owner, 2026-11-20; docs/design/tide_instruments.md).


func _cond() -> Dictionary:
	return {"slot": "day", "month": 10, "wind_dir": "NE", "wind_ms": 3}


func test_the_dial_fits_its_control_and_fills_with_power() -> void:
	assert_eq(Instrument.dial_radius(220.0, 220.0), 90.0, "the face leaves room for the ring")
	assert_true(Instrument.dial_radius(220.0, 220.0) + 20.0 <= 110.0, "the ring stays inside the control")
	assert_eq(Instrument.power_sweep(0.0), 0.0, "no power, no arc")
	assert_true(is_equal_approx(Instrument.power_sweep(0.5), PI), "half power is half way round")
	assert_true(is_equal_approx(Instrument.power_sweep(2.0), TAU), "and never more than once round")


func test_every_fight_and_cast_control_wears_its_instrument() -> void:
	var scr := FishingScreen.new()
	scr.request = Game.fishing_request("", "", "lrf", _cond())
	scr.setup("")
	var ui: FishingHud = scr._ui
	assert_eq(ui.cast_dial.get_parent(), ui.main_button, "Cast is a dial")
	assert_eq(ui.reel_gauge.get_parent(), ui.reel_pad, "the reel pad is a reel")
	assert_eq(ui.drag_lever.get_parent(), ui.drag_slider, "the drag is a lever")
	assert_eq(ui.pull_well.get_parent(), ui.pull_button, "pull is a thumb well")
	for b: Button in [ui.rig_button, ui.log_button, ui.reel_in_button, ui.speed_button, ui.settings_button]:
		assert_eq(b.theme_type_variation, UiTheme.GLASS_KEY, "%s is a glass key" % b.name)
	assert_eq(ui.main_button.size.x, ui.main_button.size.y, "the dial's control is square")
	scr.free()


func test_the_instruments_follow_the_thumbs() -> void:
	var scr := FishingScreen.new()
	scr.request = Game.fishing_request("", "", "lrf", _cond())
	scr.setup("")
	var ui: FishingHud = scr._ui
	ui.reel_pad.size = Vector2(260, 300)
	scr.set_fight_input(true, 0.0, true, 0.8)
	ui.steer = 1.0
	ui.refresh_instruments(0.1, 0.6, true)
	assert_eq(ui.cast_dial.value, 0.6, "the dial shows the power")
	assert_true(ui.cast_dial.alert, "and turns to strike on a take")
	assert_eq(ui.reel_gauge.value, 1.0, "a thumb at the top reels fastest")
	assert_true(ui.reel_gauge.spin > 0.0, "and the crank turns")
	assert_eq(ui.drag_lever.value, 0.8, "the lever shows the drag")
	assert_eq(ui.pull_well.steer, 1.0, "the well leans with the thumb")
	scr.set_fight_input(false, 0.0, false, 0.8)
	var spin := ui.reel_gauge.spin
	ui.refresh_instruments(0.1, 0.0, false)
	assert_eq(ui.reel_gauge.spin, spin, "with no thumb the crank stops")
	assert_eq(ui.pull_well.steer, 0.0, "and the well is centred")
	scr.free()
