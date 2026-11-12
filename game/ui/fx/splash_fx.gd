class_name SplashFx
extends RefCounted
## Splash droplets (particles under gravity) and expanding surface rings.
## Droplets live in screen space; rings live on the water in metres
## (x to the right, z away from the angler) so the scene can draw them in
## perspective. Seeded and deterministic.

var particles: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var gravity := 900.0

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 1) -> void:
	_rng.seed = seed_value


## strength 0..1: a lure landing is about 0.3, a fish thrashing 1.
func splash(screen_pos: Vector2, world: Vector2, strength: float) -> void:
	var count := int(10 + 26 * strength)
	for i in count:
		var angle := _rng.randf_range(-PI * 0.85, -PI * 0.15)
		var speed := _rng.randf_range(80.0, 260.0) * (0.5 + strength)
		var life := _rng.randf_range(0.35, 0.8)
		particles.append({
			"pos": screen_pos, "vel": Vector2(cos(angle), sin(angle)) * speed,
			"life": life, "max_life": life, "size": _rng.randf_range(1.2, 2.6) * (0.7 + strength),
		})
	add_ring(world, 0.6 + 1.2 * strength, 2.2, 0.9)
	add_ring(world, 0.3 + 0.6 * strength, 1.6, 0.6)


func add_ring(world: Vector2, speed_m_s: float, max_age_s: float, strength: float) -> void:
	rings.append({"world": world, "age": 0.0, "max_age": max_age_s, "speed": speed_m_s, "strength": strength})


func step(dt: float) -> void:
	for p: Dictionary in particles:
		p["pos"] = p["pos"] + p["vel"] * dt
		p["vel"] = p["vel"] + Vector2(0.0, gravity * dt)
		p["life"] = p["life"] - dt
	particles = particles.filter(func(p: Dictionary) -> bool: return p["life"] > 0.0)
	for r: Dictionary in rings:
		r["age"] = r["age"] + dt
	rings = rings.filter(func(r: Dictionary) -> bool: return r["age"] < r["max_age"])


static func ring_radius(ring: Dictionary) -> float:
	return 0.05 + float(ring["speed"]) * float(ring["age"])


static func ring_alpha(ring: Dictionary) -> float:
	return clampf(1.0 - float(ring["age"]) / float(ring["max_age"]), 0.0, 1.0) * float(ring["strength"])
