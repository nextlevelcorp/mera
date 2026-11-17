class_name Db
extends RefCounted
## The game's static data, loaded and validated once (PRD F12) and shared by
## every screen (architecture.md 3). A static holder instead of an autoload
## node, so the headless test runner and the game reach it the same way.

const DATA_DIR := "res://data"

static var _database := {}
static var _constants := {}
static var errors: Array[String] = []


## The validated records by kind (species, spot, rod, ...); empty if loading failed.
static func database() -> Dictionary:
	_load()
	return _database


## Simulation constants (data_model.md 5.8).
static func constants() -> Dictionary:
	_load()
	return _constants


static func ok() -> bool:
	_load()
	return errors.is_empty()


## The record of a kind with this id, or an empty dictionary.
static func record(kind: String, id: String) -> Dictionary:
	for r: Dictionary in database().get(kind, []):
		if r["id"] == id:
			return r
	return {}


static func _load() -> void:
	if not _constants.is_empty():
		return
	errors = []
	var loaded := DataStore.load_all(DATA_DIR)
	if loaded["ok"]:
		_database = loaded["database"]
	else:
		for e: Variant in loaded["errors"]:
			errors.append(str(e))
	_constants = DataStore.load_constants(errors)
