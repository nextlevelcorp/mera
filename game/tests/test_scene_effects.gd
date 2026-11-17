extends "res://tests/test_base.gd"
## Roadmap R6: rings, fish and gulls in the 3D scene.


func _ring(world: Vector2, age: float, max_age: float, strength: float) -> Dictionary:
	return {"world": world, "age": age, "max_age": max_age, "speed": 1.0, "strength": strength}


func test_rings_are_packed_for_the_sea_shader() -> void:
	var rings: Array[Dictionary] = [_ring(Vector2(2.0, 12.0), 0.5, 1.0, 1.0), _ring(Vector2(-3.0, 20.0), 0.99, 1.0, 1.0)]
	var extra: Array[Vector4] = [Vector4(1.0, -9.0, 0.2, 0.3)]
	var packed := WaterView.pack_rings(rings, extra)
	assert_eq(packed.size(), 2, "a ring that has all but faded is left out")
	assert_eq(packed[0].x, 2.0, "x is kept")
	assert_eq(packed[1].y, -9.0, "an extra ring is kept as given")
	assert_eq(packed[0].y, -12.0, "z runs away as a negative number, like the sea's own coordinates")
	assert_near(packed[0].z, SplashFx.ring_radius(rings[0]), "the radius grows with age")
	assert_true(packed[0].w >= packed[1].w, "the strongest comes first")
	var many: Array[Dictionary] = []
	for i in 30:
		many.append(_ring(Vector2(float(i), 10.0), 0.1, 2.0, 0.2 + 0.02 * i))
	var capped := WaterView.pack_rings(many)
	assert_eq(capped.size(), WaterView.MAX_RINGS, "no more than the shader holds")
	assert_true(capped[0].w > capped[capped.size() - 1].w - 1e-6, "and the strongest are the ones kept")


func test_the_water_view_takes_rings_and_a_fish_shadow() -> void:
	var w := WaterView.new()
	var rings: Array[Dictionary] = [_ring(Vector2(1.0, 15.0), 0.2, 1.5, 0.9)]
	w.set_rings(rings)
	assert_eq(int(w.shader_parameter("ring_count")), 1, "one ring reaches the sea")
	w.set_rings([] as Array[Dictionary])
	assert_eq(int(w.shader_parameter("ring_count")), 0, "none clears it")
	var spine := PackedVector2Array()
	for i in 10:
		spine.append(Vector2(0.1 * i, 9.0 + 0.1 * i))
	w.set_fish_shadow(spine, 0.1, 0.8)
	assert_eq(int(w.shader_parameter("shadow_count")), WaterView.MAX_SHADOWS, "the spine becomes a chain of blobs")
	var blobs: PackedVector4Array = w.shader_parameter("fish_shadow")
	assert_eq(blobs[0].y, -spine[0].y, "head first, z negated")
	assert_true(blobs[3].z > blobs[0].z, "fatter in the middle than at the snout")
	w.set_fish_shadow(PackedVector2Array(), 0.1, 0.8)
	assert_eq(int(w.shader_parameter("shadow_count")), 0, "no spine, no shadow")
	w.set_fish_shadow(spine, 0.1, 0.0)
	assert_eq(int(w.shader_parameter("shadow_count")), 0, "a hidden fish casts none")
	w.free()


func test_a_fish_mesh_follows_its_spine() -> void:
	var fish := Fish3D.new()
	assert_true(not fish.visible, "hidden until shown")
	var spine := PackedVector3Array()
	for i in 10:
		spine.append(Vector3(0.0, 1.0, -10.0 - 0.06 * i))
	fish.show_along(spine, Vector3.UP, 0.5)
	assert_true(fish.visible, "shown along a spine")
	var mesh: ArrayMesh = fish._mesh
	assert_eq(mesh.get_surface_count(), 1, "one surface")
	var box := mesh.get_aabb()
	assert_true(box.size.z > 0.5 and box.size.z < 0.9, "about its own length with the tail fin (%.2f m)" % box.size.z)
	assert_true(box.size.y > 0.1 and box.size.y < 0.3, "and a body that is tall, not flat (%.2f m)" % box.size.y)
	assert_true(box.size.x < box.size.y, "and compressed from the sides (%.2f against %.2f)" % [box.size.x, box.size.y])
	assert_true(box.position.y > 0.7 and box.end.y < 1.4, "around the spine's height")
	fish.show_along(PackedVector3Array([Vector3.ZERO]), Vector3.UP, 0.5)
	assert_true(not fish.visible, "too short a spine hides it")
	fish.free()


func test_a_vertical_spine_does_not_break_the_mesh() -> void:
	# A fish hanging straight down while its back axis points up has no valid
	# perpendicular; the mesh falls back to the last good axis instead of NaN.
	var fish := Fish3D.new()
	var spine := PackedVector3Array()
	for i in 10:
		spine.append(Vector3(0.0, 2.0 - 0.05 * i, -3.0))
	fish.show_along(spine, Vector3.UP, 0.4)
	var box := (fish._mesh as ArrayMesh).get_aabb()
	assert_true(is_finite(box.size.x) and is_finite(box.size.y) and is_finite(box.size.z), "every vertex is a number")
	fish.free()


func test_the_gull_flock_is_written_into_a_multimesh() -> void:
	var field := ShoalField.new(Db.constants(), 5)
	var flock := GullFlock.new(field.shoals.size())
	for i in 300:
		flock.update(1.0 / 30.0, field)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = GullFlock.gull_mesh()
	flock.pose(mm)
	assert_eq(mm.instance_count, flock.gulls.size(), "one instance per gull")
	for g: Dictionary in flock.gulls:
		var t := GullFlock.gull_transform(g)
		var pos: Vector3 = g["pos"]
		assert_near(t.origin.x, pos.x, "x", 1e-4)
		assert_near(t.origin.y, pos.y, "height", 1e-4)
		assert_near(t.origin.z, -pos.z, "z (away is negative)", 1e-4)
		var dir: Vector2 = g["dir"]
		assert_true((-t.basis.z.normalized()).dot(Vector3(dir.x, 0.0, -dir.y)) > 0.99, "flies nose first")
		assert_true(t.basis.determinant() > 0.0, "and is not mirrored")
	var mesh := GullFlock.gull_mesh()
	assert_near(mesh.get_aabb().size.x, 2.0, "the mesh is two metres across before scaling", 0.01)


func test_the_screen_feeds_the_scene_effects_through_a_fight() -> void:
	var screen: FishingScreen = load("res://scenes/fishing/fishing_screen.tscn").instantiate()
	screen.setup("")
	screen._overlay.size = Vector2(1280, 720)
	var species_id: String = Db.database()["spot"][0]["species"][0]["species_id"]
	screen.cast_with_power(0.8)
	screen._land_lure()
	screen._update_scene_effects()
	assert_eq(int(screen._water.shader_parameter("ring_count")) >= 1, true, "the lure's ripple is a ring while waiting")
	screen._start_fight({"species_id": species_id, "u": 0.5, "timing_quality": 0.9, "hook": 0.9, "distance_m": 12.0})
	var saw_shadow := false
	var saw_landing_fish := false
	for i in 4000:
		if screen.phase != FishingScreen.Phase.FIGHT:
			break
		var kicking: bool = screen._hud["in_landing"] and screen._hud["kicking"]
		screen.set_fight_input(not kicking, 0.0, false, 0.4)
		screen._step_fight(1.0 / 30.0)
		screen._update_scene_effects()
		if int(screen._water.shader_parameter("shadow_count")) > 0:
			saw_shadow = true
		if screen._water.fish_hand.visible:
			saw_landing_fish = true
	assert_true(saw_shadow, "a fish near the shore is a shadow in the water")
	assert_true(saw_landing_fish, "and the landing shows the fish on the line")
	screen.free()
