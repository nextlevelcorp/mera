extends Control
## Entry scene: title, note, version, the fishing loop on demo data and the
## water prototype (temporary, see docs/design_direction.md section 5).

const WATER_PROTOTYPE := "res://scenes/water_prototype/water_prototype.tscn"
const FISHING_SCREEN := "res://scenes/fishing/fishing_screen.tscn"

@onready var _title: Label = $Column/Title
@onready var _note: Label = $Column/Note
@onready var _version: Label = $Column/Version
@onready var _prototype: Button = $Column/WaterPrototype
@onready var _fishing: Button = $Column/Fishing


func _ready() -> void:
	_title.text = tr("TITLE")
	_note.text = tr("SKELETON_NOTE")
	_version.text = "v%s · Godot %s" % [
		ProjectSettings.get_setting("application/config/version", "0.0.0"),
		Engine.get_version_info().string,
	]
	_prototype.text = tr("PROTO_OPEN")
	_prototype.pressed.connect(func() -> void: get_tree().change_scene_to_file.call_deferred(WATER_PROTOTYPE))
	_fishing.text = tr("FISH_OPEN")
	_fishing.pressed.connect(func() -> void: get_tree().change_scene_to_file.call_deferred(FISHING_SCREEN))
