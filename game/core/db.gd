class_name Db
extends RefCounted
## The game's static data, loaded and validated once (PRD F12) and shared by
## every screen (architecture.md 3). A static holder instead of an autoload
## node, so the headless test runner and the game reach it the same way.

const DATA_DIR := "res://data"

static var _database := {}
static var _constants := {}
static var errors: Array[String] = []
static var _shop := {}
static var _goals: Array = []
static var _weekly: Array = []


## The validated records by kind (species, spot, rod, ...); empty if loading failed.
static func database() -> Dictionary:
	_load()
	return _database


## Simulation constants (data_model.md 5.8).
static func constants() -> Dictionary:
	_load()
	return _constants


## The shop catalogue (Economy.load_catalog); empty if it failed to load.
static func shop() -> Dictionary:
	_load()
	if _shop.is_empty() and errors.is_empty():
		var loaded := Economy.load_catalog(_database)
		if loaded["ok"]:
			_shop = loaded["catalog"]
		else:
			for e: Variant in loaded["errors"]:
				errors.append(str(e))
	return _shop


## The mastery goals (Mastery.load_goals); empty if they failed to load.
static func goals() -> Array:
	_load()
	if _goals.is_empty() and errors.is_empty():
		var loaded := Mastery.load_goals(_database)
		if loaded["ok"]:
			_goals = loaded["goals"]
		else:
			for e: Variant in loaded["errors"]:
				errors.append(str(e))
	return _goals


## The fixed weekly tasks (Weekly.load_tasks); empty if they failed to load.
static func weekly() -> Array:
	_load()
	if _weekly.is_empty() and errors.is_empty():
		var loaded := Weekly.load_tasks(_database)
		if loaded["ok"]:
			_weekly = loaded["tasks"]
		else:
			for e: Variant in loaded["errors"]:
				errors.append(str(e))
	return _weekly


static func ok() -> bool:
	_load()
	shop()
	goals()
	weekly()
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
