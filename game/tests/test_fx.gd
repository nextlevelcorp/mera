extends "res://tests/test_base.gd"
## Visual motion helpers: the line chain and the splash effects.


func test_rope_ends_stay_pinned_and_line_sags() -> void:
	var start := Vector2(900, 200)
	var end := Vector2(500, 400)
	var rope := VerletRope.new(start, end, 16, 1.08)
	for i in 300:
		rope.step(1.0 / 60.0, start, end, Vector2(0, 300))
	assert_near(rope.points[0].distance_to(start), 0.0, "start pinned")
	assert_near(rope.points[15].distance_to(end), 0.0, "end pinned")
	var mid_straight := start.lerp(end, 0.5)
	assert_true(rope.points[8].y > mid_straight.y + 5.0, "a slack line sags below the straight line under gravity")
	var length := 0.0
	for i in 15:
		length += rope.points[i].distance_to(rope.points[i + 1])
	assert_true(absf(length - rope.total_length()) <= 0.05 * rope.total_length(), "the chain keeps its length within 5%%, got %s for %s" % [str(length), str(rope.total_length())])


func test_rope_is_stable_and_deterministic() -> void:
	var a := VerletRope.new(Vector2(0, 0), Vector2(300, 100))
	var b := VerletRope.new(Vector2(0, 0), Vector2(300, 100))
	for i in 1200:
		var end := Vector2(300, 100 + 20.0 * sin(i * 0.05))
		var wind := Vector2(60.0 * sin(i * 0.013), 300)
		a.step(1.0 / 60.0, Vector2.ZERO, end, wind)
		b.step(1.0 / 60.0, Vector2.ZERO, end, wind)
	for p in a.points:
		assert_true(is_finite(p.x) and is_finite(p.y) and absf(p.x) < 5000.0 and absf(p.y) < 5000.0, "points stay finite and bounded")
	assert_eq(a.points, b.points, "same inputs, same shape")


func test_rope_length_can_grow_while_the_lure_flies() -> void:
	var rope := VerletRope.new(Vector2(0, 0), Vector2(10, 0))
	rope.set_total_length(400.0)
	assert_near(rope.total_length(), 400.0, "total length set")
	assert_near(rope.segment_length, 400.0 / 15.0, "segments share it")


func test_splash_particles_fall_and_die() -> void:
	var fx := SplashFx.new(7)
	fx.splash(Vector2(500, 400), Vector2(0, 20), 0.3)
	var count := fx.particles.size()
	assert_true(count >= 10, "a lure splash throws droplets")
	assert_eq(fx.rings.size(), 2, "and two rings")
	var start_y: float = fx.particles[0]["pos"].y
	fx.step(0.1)
	assert_true(fx.particles[0]["pos"].y < start_y, "droplets start upwards")
	for i in 60:
		fx.step(1.0 / 60.0)
	assert_eq(fx.particles.size(), 0, "droplets are gone after a second")
	for i in 120:
		fx.step(1.0 / 60.0)
	assert_eq(fx.rings.size(), 0, "rings fade out")


func test_rings_grow_and_fade() -> void:
	var fx := SplashFx.new(1)
	fx.add_ring(Vector2(1, 20), 1.0, 2.0, 1.0)
	var ring: Dictionary = fx.rings[0]
	var r0 := SplashFx.ring_radius(ring)
	var a0 := SplashFx.ring_alpha(ring)
	fx.step(1.0)
	assert_true(SplashFx.ring_radius(ring) > r0, "rings grow")
	assert_true(SplashFx.ring_alpha(ring) < a0, "rings fade")
	assert_near(SplashFx.ring_alpha(ring), 0.5, "half way, half alpha")


func test_splash_is_deterministic() -> void:
	var a := SplashFx.new(3)
	var b := SplashFx.new(3)
	a.splash(Vector2(1, 2), Vector2(0, 10), 1.0)
	b.splash(Vector2(1, 2), Vector2(0, 10), 1.0)
	assert_eq(a.particles.size(), b.particles.size(), "same count")
	assert_eq(a.particles[5]["vel"], b.particles[5]["vel"], "same droplet")
