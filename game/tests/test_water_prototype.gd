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
