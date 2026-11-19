extends "res://tests/test_base.gd"
## Roadmap R13: the world's sound layers and the mix buses.


func _area() -> WorldArea:
	return WorldArea.load_area("galata_bridge", Db.database())["area"]


func test_the_buses_come_from_the_layout_file_not_from_run_time_code() -> void:
	# Adding buses at run time silenced the web build; they must be in the layout.
	var layout := load("res://default_bus_layout.tres") as AudioBusLayout
	assert_true(layout != null, "the layout file loads")
	assert_eq(ProjectSettings.get_setting("audio/buses/default_bus_layout", "res://default_bus_layout.tres"), "res://default_bus_layout.tres", "and is the project's default")
	var before := AudioServer.bus_count
	assert_true(AudioServer.get_bus_index(AudioBuses.AMBIENCE) >= 0 or before >= 1, "the engine has its buses")
	for bus: StringName in AudioBuses.ALL:
		assert_true(AudioServer.get_bus_index(bus) >= 0, "%s exists at start-up" % bus)


func test_the_buses_exist_once() -> void:
	AudioBuses.ensure()
	var count := AudioServer.bus_count
	AudioBuses.ensure()
	assert_eq(AudioServer.bus_count, count, "ensure adds nothing the second time")
	for bus: StringName in AudioBuses.ALL:
		var i := AudioServer.get_bus_index(bus)
		assert_true(i > 0 and AudioServer.get_bus_send(i) == &"Master", "%s feeds Master" % bus)


func test_beds_follow_where_you_stand_and_the_hour() -> void:
	var a := _area()
	var rail := WorldAudio.bed_levels(Vector2(15.0, 50.0), a, "day", 3.0)
	var square := WorldAudio.bed_levels(Vector2(4.0, 12.0), a, "day", 3.0)
	assert_true(rail["sea"] > square["sea"], "the sea is louder at the rail than on the square")
	var road_side := WorldAudio.bed_levels(Vector2(17.5, 50.0), a, "day", 3.0)
	var far := WorldAudio.bed_levels(Vector2(2.0, 12.0), a, "day", 3.0)
	assert_true(road_side["city"] > far["city"], "the traffic is louder beside the road")
	assert_true(WorldAudio.bed_levels(Vector2(17.5, 50.0), a, "night", 3.0)["city"] < road_side["city"], "and quieter at night")
	assert_true(WorldAudio.bed_levels(Vector2(15.0, 50.0), a, "day", 9.0)["wind"] > rail["wind"], "the wind follows its speed")
	for v: float in rail.values():
		assert_true(v >= 0.0 and v <= 1.0, "levels stay within 0..1")


func test_steps_sound_by_the_ground() -> void:
	var a := _area()
	assert_eq(WorldAudio.step_sound(Vector2(8.0, 12.0), a), "step_stone", "cobbles on the square")
	assert_eq(WorldAudio.step_sound(Vector2(16.5, 50.0), a), "step", "paving on the walkway")


func test_the_tram_rings_only_when_near() -> void:
	var pos := Vector2(17.0, 50.0)
	assert_true(WorldAudio.tram_near({"x": 28.8, "y": 45.0, "dir": 1.0}, pos), "its front is close")
	assert_true(WorldAudio.tram_near({"x": 28.8, "y": 70.0, "dir": 1.0}, pos), "it is passing (front ahead, back behind)")
	assert_true(not WorldAudio.tram_near({"x": 28.8, "y": 0.0, "dir": 1.0}, pos), "far away it is quiet")


func test_generated_world_sounds_are_made() -> void:
	for cue: String in ["tram_bell", "ferry_horn", "gull", "step", "step_stone", "traffic"]:
		var wav := CueSynth.make(cue)
		assert_true(wav.data.size() > 1000, "%s has samples" % cue)
	assert_eq(CueSynth.make("traffic").loop_mode, AudioStreamWAV.LOOP_FORWARD, "the traffic bed loops")


func test_the_world_carries_its_audio_and_fades_it_for_fishing() -> void:
	var world := WorldScreen.new()
	world.profile_path = ""
	world.conditions = {"slot": "day", "month": 10, "wind_dir": "NE", "wind_ms": 4}
	world.setup()
	assert_true(world._audio != null, "the world has its sound")
	world.walk.teleport(Vector2(15.0, 50.0))
	world._process(0.1)
	assert_true(float(world._audio.levels["sea"]) > 0.5, "at the rail the sea is loud")
	world.pause()
	assert_eq(world._audio._fade_to, 0.0, "fishing fades the world out")
	world.resume(Game.empty_result())
	assert_eq(world._audio._fade_to, 1.0, "and back in")
	world.free()
