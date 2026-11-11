extends "res://tests/test_base.gd"
## Guards the technical decisions in docs/project_spec.md section 6.1.


func test_design_space_and_stretch() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 1280, "design width")
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 720, "design height")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items", "stretch mode")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "expand", "stretch aspect")


func test_landscape_only() -> void:
	# 0 = landscape
	assert_eq(ProjectSettings.get_setting("display/window/handheld/orientation"), 0, "orientation")


func test_compatibility_renderer() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility", "renderer")


func test_main_scene_exists() -> void:
	var path: String = ProjectSettings.get_setting("application/run/main_scene")
	assert_true(ResourceLoader.exists(path), "main scene exists: %s" % path)


func test_web_preset_is_single_threaded() -> void:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK, "export_presets.cfg loads")
	var found := false
	for section in cfg.get_sections():
		if cfg.get_value(section, "platform", "") == "Web":
			found = true
			var options := section + ".options"
			assert_eq(cfg.get_value(options, "variant/thread_support"), false, "web export is single-threaded")
			assert_eq(cfg.get_value(options, "variant/extensions_support"), false, "web export has no GDExtension")
	assert_true(found, "a Web export preset exists")
