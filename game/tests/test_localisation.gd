extends "res://tests/test_base.gd"
## Every key in the translation table must exist in en, tr and es.

const CSV_PATH := "res://locale/translations.csv"
const LANGUAGES: Array[String] = ["en", "tr", "es"]


func test_all_keys_translated() -> void:
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	assert_true(file != null, "translation table opens")
	if file == null:
		return
	var header := file.get_csv_line()
	assert_eq(Array(header), ["keys"] + LANGUAGES, "csv header")
	var rows := 0
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 1 and row[0] == "":
			continue
		rows += 1
		assert_eq(row.size(), header.size(), "column count for key %s" % row[0])
		for i in range(1, row.size()):
			assert_true(row[i].strip_edges() != "", "key %s has %s text" % [row[0], header[i]])
	assert_true(rows > 0, "translation table has rows")


func test_translations_loaded_in_engine() -> void:
	assert_true(not TranslationServer.get_loaded_locales().is_empty(), "translations are loaded")
