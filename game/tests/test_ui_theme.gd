extends "res://tests/test_base.gd"
## Roadmap R21: one theme for every control.


func test_the_theme_styles_keys_and_panels() -> void:
	var t := UiTheme.make()
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		assert_true(t.get_stylebox(state, &"Button") is StyleBoxFlat, "a button has a %s look" % state)
		assert_true(t.get_stylebox(state, UiTheme.PRIMARY) is StyleBoxFlat, "the primary key has a %s look" % state)
	var up := t.get_stylebox(&"normal", &"Button") as StyleBoxFlat
	var down := t.get_stylebox(&"pressed", &"Button") as StyleBoxFlat
	assert_true(down.border_width_bottom < up.border_width_bottom and down.content_margin_top > up.content_margin_top, "a pressed key sinks onto its lip")
	assert_eq(t.get_type_variation_base(UiTheme.PRIMARY), &"Button", "the primary key is a button")
	assert_true((t.get_stylebox(&"normal", UiTheme.PRIMARY) as StyleBoxFlat).bg_color.is_equal_approx(UiTheme.BRASS), "and brass")
	assert_true(t.get_stylebox(&"panel", &"PanelContainer") is StyleBoxFlat, "panels share one look")


func test_the_cast_key_is_the_primary_one() -> void:
	var scr := FishingScreen.new()
	scr.request = Game.fishing_request("", "", "lrf", {"slot": "day", "month": 10, "wind_dir": "NE", "wind_ms": 3})
	scr.setup("")
	assert_eq(scr._ui.main_button.theme_type_variation, UiTheme.PRIMARY, "Cast stands out")
	assert_true(scr._ui.main_button.custom_minimum_size.y >= FishingHud.TOUCH_MIN * 0.8, "and is big enough for a thumb")
	scr.free()
