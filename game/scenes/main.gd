extends Control
## Entry scene of the empty skeleton. Shows only the title, a note and the version.

@onready var _title: Label = $Column/Title
@onready var _note: Label = $Column/Note
@onready var _version: Label = $Column/Version


func _ready() -> void:
	_title.text = tr("TITLE")
	_note.text = tr("SKELETON_NOTE")
	_version.text = "v%s · Godot %s" % [
		ProjectSettings.get_setting("application/config/version", "0.0.0"),
		Engine.get_version_info().string,
	]
