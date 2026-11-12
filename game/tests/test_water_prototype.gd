extends "res://tests/test_base.gd"
## Frame statistics and the water prototype's link to the simulation numbers.

const PROTOTYPE := preload("res://scenes/water_prototype/water_prototype.tscn")


func test_frame_stats_average_and_worst_one_percent() -> void:
	var stats := FrameStats.new(60.0)
	assert_near(stats.average_fps(), 0.0, "no frames, no fps")
	for i in 99:
		stats.add(1.0 / 60.0)
	stats.add(0.1)
	assert_eq(stats.frames(), 100, "100 frames kept")
	assert_near(stats.average_fps(), 100.0 / (99.0 / 60.0 + 0.1), "average fps")
	assert_near(stats.low_1pct_fps(), 10.0, "the worst 1% of 100 frames is the single 0.1 s frame")
	stats.add(0.0)
	stats.add(-1.0)
	assert_eq(stats.frames(), 100, "non-positive deltas are ignored")
	stats.reset()
	assert_eq(stats.frames(), 0, "reset clears the window")


func test_frame_stats_window_drops_old_frames() -> void:
	var stats := FrameStats.new(1.0)
	for i in 10:
		stats.add(0.5)
	assert_true(stats.seconds() <= 1.0 + 1e-9, "the window holds at most its length")
	assert_eq(stats.frames(), 2, "two half-second frames fit one second")
	for i in 120:
		stats.add(1.0 / 60.0)
	assert_near(stats.average_fps(), 60.0, "old slow frames have left the window", 1e-3)


func test_prototype_uses_the_simulation_environment() -> void:
	var scene = PROTOTYPE.instantiate()
	var errors: Array[String] = []
	scene._k = DataStore.load_constants(errors)
	scene.chop = 0.24
	scene.clarity = 11.0
	scene.slot_index = 2
	var env: Dictionary = scene.environment()
	# Example A of data_model.md: chop 0.24, clarity 11, evening.
	assert_near(env["clarity_eff"], 9.08, "clarity after chop")
	assert_near(env["visibility"], (9.08 - 1.0) / 19.0 * 0.6, "visibility")
	assert_near(env["visible_at_m"], 1.0 + 7.0 * (9.08 - 1.0) / 19.0 * 0.6, "visible distance matches the worked example (2.8 m)")
	scene.slot_index = 3
	assert_true(scene.environment()["visibility"] < env["visibility"], "night sees less than evening")
	scene.chop = 1.0
	assert_true(scene.environment()["clarity_eff"] < 9.08, "more chop, murkier water")
	scene.free()


func test_shading_keeps_the_breakwater_opaque() -> void:
	var scene = PROTOTYPE.instantiate()
	var c: Color = scene._shaded(Color(0.5, 0.4, 0.3), 0.25)
	assert_near(c.a, 1.0, "night shading keeps alpha at 1")
	assert_near(c.r, 0.125, "and darkens the colour")
	scene.free()


func test_projection_matches_the_shader_camera() -> void:
	var scene = PROTOTYPE.instantiate()
	scene._build_overlay()
	scene._overlay.size = Vector2(1280, 720)
	var near: Vector2 = scene.project(Vector2(0, 10))
	var far: Vector2 = scene.project(Vector2(0, 40))
	assert_near(near.x, 640.0, "straight ahead is the screen centre")
	assert_true(far.y < near.y and far.y > 720 * 0.38, "farther water is higher on screen but below the horizon")
	assert_near(near.y, (0.38 + 2.2 / (10.0 * 0.9)) * 720.0, "same formula as the shader")
	scene.free()
