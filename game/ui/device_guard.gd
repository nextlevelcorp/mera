class_name DeviceGuard
extends CanvasLayer
## Landscape only: covers the game with a "turn your phone" screen while the
## window is taller than it is wide.

var _overlay: ColorRect


static func is_portrait(size: Vector2) -> bool:
	return size.y > size.x


func _ready() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0.02, 0.06, 0.09, 1.0)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

	var label := Label.new()
	label.text = tr("TURN_PHONE")
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 48)
	_overlay.add_child(label)

	get_viewport().size_changed.connect(_update)
	_update()


func _update() -> void:
	_overlay.visible = is_portrait(get_viewport().get_visible_rect().size)
