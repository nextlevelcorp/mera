extends "res://tests/test_base.gd"
## Gilthead sea bream, sea bass and white sea bream (owner decision
## 2026-11-22): the shore fish of every country on the map.

const NEW := ["cipura", "levrek", "sargoz"]


func _sp(id: String) -> Dictionary:
	for s: Dictionary in Db.database()["species"]:
		if s["id"] == id:
			return s
	return {}


func test_each_has_a_rule_in_every_country() -> void:
	for j: Dictionary in Db.database()["jurisdiction"]:
		for id: String in NEW:
			var r := Regulations.rule(Db.database(), String(j["id"]), id)
			assert_true(r.has("min_length_cm"), "%s has a size for %s" % [j["id"], id])
	assert_eq(Regulations.rule(Db.database(), "pt_national", "levrek")["min_length_cm"], 36.0, "Portugal's sea bass size is 36 cm (DGRM)")
	assert_eq(Regulations.rule(Db.database(), "it_national", "levrek")["min_length_cm"], 20.0, "Italy's Article 87: 20 cm")


func test_a_legal_fish_can_be_caught_everywhere() -> void:
	for j: Dictionary in Db.database()["jurisdiction"]:
		for id: String in NEW:
			var r := Regulations.rule(Db.database(), String(j["id"]), id)
			assert_true(float(_sp(id)["length_max_cm"]) > float(r["min_length_cm"]), "a %s over %s's size exists in the sourced range" % [id, j["id"]])


func test_weights_follow_their_studies() -> void:
	var w := func(id: String, l: float) -> float:
		var s := _sp(id)
		return float(s["lw_a"]) * pow(l, float(s["lw_b"]))
	assert_near(w.call("cipura", 26.5), 283.8, "the largest gilthead in Reis (2020) weighed 283.82 g", 40.0)
	assert_near(w.call("levrek", 40.8), 805.3, "the largest sea bass, 805.32 g", 120.0)
	assert_near(w.call("sargoz", 36.7), 836.5, "the largest white sea bream in Daban et al. (2024), 836.5 g", 120.0)


func test_izmir_anglers_find_their_gilthead() -> void:
	var cond := {"slot": "dawn", "month": 9, "wind_dir": "NE", "wind_ms": 3}
	var ctx := FightSetup.build(Db.database(), "cipura", "float", "izmir_konak", 0.5, cond)
	var w := WaitSim.new(ctx, Db.constants(), Db.database()["species"], 15.0, 1)
	assert_true(float(w._rates["cipura"]["rate_interest"]) > 0.0, "shrimp under a float draws gilthead at Konak (Ulaş et al. 2019: the most common catch)")
	var galata := FightSetup.build(Db.database(), "cipura", "float", "karakoy_east", 0.5, cond)
	var g := WaitSim.new(galata, Db.constants(), Db.database()["species"], 15.0, 1)
	assert_true(not g._rates.has("cipura") or float(g._rates["cipura"]["rate_interest"]) == 0.0, "none at Galata, where no source names it")
