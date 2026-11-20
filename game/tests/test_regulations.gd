extends "res://tests/test_base.gd"
## Roadmap R17: legal sizes by jurisdiction (owner decision D6).


func test_every_jurisdiction_is_sourced_and_names_known_species() -> void:
	var db := Db.database()
	assert_true((db.get("jurisdiction", []) as Array).size() >= 5, "Turkey, Andalusia, Italy, Portugal and Greece")
	var species := {}
	for s: Dictionary in db["species"]:
		species[s["id"]] = true
	for j: Dictionary in db["jurisdiction"]:
		assert_true(String(j["provenance"]["default"].get("source", "")) != "", "%s has a source" % j["id"])
		assert_true(TranslationServer.get_translation_object("en").get_message(j["name_key"]) != "", "%s has a name" % j["id"])
		for r: Dictionary in j["rules"]:
			assert_true(species.has(r["species_id"]), "%s: %s is a known species" % [j["id"], r["species_id"]])
			assert_true(r.has("min_length_cm") != (r.get("no_minimum") == true), "%s/%s has a size or a checked no-minimum" % [j["id"], r["species_id"]])
			if j["official"]:
				assert_true(r["status"] != "unofficial", "%s/%s comes from the official text" % [j["id"], r["species_id"]])
			else:
				assert_eq(r["status"], "unofficial", "%s/%s is marked unofficial" % [j["id"], r["species_id"]])


func test_turkey_agrees_with_the_species_records() -> void:
	var db := Db.database()
	for sp: Dictionary in db["species"]:
		var r := Regulations.rule(db, "tr_national", sp["id"])
		assert_true(not r.is_empty(), "%s has a Turkish rule" % sp["id"])
		assert_eq(r.get("min_length_cm", 0.0), (sp["regulation"] as Dictionary).get("min_length_cm", 0.0), "%s: the same size in both places" % sp["id"])


func test_the_same_fish_can_be_legal_in_one_place_and_not_in_another() -> void:
	var db := Db.database()
	assert_true(not Regulations.is_undersize(db, "tr_national", "istavrit", 13.0), "a 13 cm horse mackerel is legal in Turkey (12 cm)")
	assert_true(Regulations.is_undersize(db, "es_andalusia", "istavrit", 13.0), "but not in Andalusia (15 cm)")
	assert_true(not Regulations.is_undersize(db, "es_andalusia", "lufer", 10.0), "Andalusia sets no size for bluefish")
	assert_true(Regulations.is_undersize(db, "it_national", "palamut", 20.0), "Italy: bonito 25 cm")
	assert_eq(Regulations.rule(db, "it_national", "istavrit")["status"], "applied_by_design", "Italy's horse mackerel size is the stricter EU one, by design")
