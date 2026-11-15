extends "res://tests/test_base.gd"
## The other anglers along the bridge rail: they fish at the pace of the
## place, lift fish and recast, and behave the same for the same seed.


func _run(seed_value: int, mean_s: float, seconds: float) -> Dictionary:
	var n := NeighborAnglers.new(seed_value)
	n.set_pace(mean_s)
	var lifts := 0
	var states := {}
	for i in int(seconds * 30.0):
		n.update(1.0 / 30.0)
		lifts += n.take_events().size()
		for p: Dictionary in n.people:
			states[int(p["state"])] = true
	return {"lifts": lifts, "states": states}


func test_neighbours_catch_fish_over_time() -> void:
	var r := _run(5, 40.0, 600.0)
	assert_true(int(r["lifts"]) >= 8, "four anglers lift fish in ten minutes at a 40 s pace: %d" % r["lifts"])
	for st: int in [NeighborAnglers.S.IDLE, NeighborAnglers.S.NIBBLE, NeighborAnglers.S.FIGHT, NeighborAnglers.S.LIFT, NeighborAnglers.S.RECAST]:
		assert_true(r["states"].has(st), "every phase of a bite shows up (%d)" % st)


func test_a_slower_place_means_fewer_neighbour_catches() -> void:
	var fast := int(_run(3, 30.0, 900.0)["lifts"])
	var slow := int(_run(3, 240.0, 900.0)["lifts"])
	assert_true(fast > slow * 2, "the pace follows the bite rate (%d against %d)" % [fast, slow])


func test_same_seed_same_neighbours() -> void:
	assert_eq(int(_run(9, 50.0, 300.0)["lifts"]), int(_run(9, 50.0, 300.0)["lifts"]), "deterministic for a seed")


func test_a_hitch_does_not_skip_the_whole_bite() -> void:
	var n := NeighborAnglers.new(2)
	n.set_pace(15.0)
	n.update(30.0)   # a long freeze counts as at most one capped step
	var ticks := 0
	for p: Dictionary in n.people:
		ticks += 1 if float(p["t"]) <= 0.25 + 1e-6 else 0
	assert_eq(ticks, NeighborAnglers.COUNT, "one frame never advances more than 0.25 s")
